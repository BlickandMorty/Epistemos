#if !EPISTEMOS_APP_STORE
import Darwin
import Foundation

/// Crash-orphan sweep ledger for embedded agent surface children.
///
/// Identity = (pid, process start time). PIDs get reused; the kernel start
/// time does not, so a recorded pid whose current start time differs is never
/// signaled.
struct AgentSurfaceChildRecord: Codable, Equatable {
    let pid: Int32
    let startTimeSec: Int64
    // Microsecond component of the kernel start time. Optional so ledgers
    // written before this field decode cleanly.
    var startTimeUsec: Int64?
    let name: String
}

enum AgentSurfaceChildLedger {
    private static let maxLedgerBytes = 64 * 1024
    private static let currentLedgerFilename = "agent-surface-children.json"
    private static var legacyLedgerFilename: String {
        ["pro", "-agent-children", ".json"].joined()
    }

    static func ledgerURL(
        appSupport: URL? = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    ) -> URL? {
        ledgerURL(filename: currentLedgerFilename, appSupport: appSupport)
    }

    private static func legacyLedgerURL(appSupport: URL?) -> URL? {
        ledgerURL(filename: legacyLedgerFilename, appSupport: appSupport)
    }

    private static func ledgerURL(filename: String, appSupport: URL?) -> URL? {
        appSupport?
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent(filename)
    }

    static func processStartTimeSeconds(pid: pid_t) -> Int64? {
        processStartTime(pid: pid)?.sec
    }

    /// Kernel process start time at microsecond resolution.
    static func processStartTime(pid: pid_t) -> (sec: Int64, usec: Int64)? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
        guard result == size else { return nil }
        return (Int64(info.pbi_start_tvsec), Int64(info.pbi_start_tvusec))
    }

    private static func isSameProcess(_ record: AgentSurfaceChildRecord, pid: pid_t) -> Bool {
        guard let current = processStartTime(pid: pid) else { return false }
        if current.sec != record.startTimeSec { return false }
        if let recordedUsec = record.startTimeUsec { return current.usec == recordedUsec }
        return true
    }

    private static func loadRecords(from url: URL) -> [AgentSurfaceChildRecord] {
        guard let data = try? Data(contentsOf: url),
              data.count <= maxLedgerBytes,
              let records = try? JSONDecoder().decode([AgentSurfaceChildRecord].self, from: data) else {
            return []
        }
        return records
    }

    private static func load(
        appSupport: URL? = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    ) -> [AgentSurfaceChildRecord] {
        let urls = [
            ledgerURL(appSupport: appSupport),
            legacyLedgerURL(appSupport: appSupport),
        ].compactMap { $0 }

        var merged: [AgentSurfaceChildRecord] = []
        var seen = Set<String>()
        for url in urls {
            for record in loadRecords(from: url) {
                let key = "\(record.pid):\(record.startTimeSec):\(record.startTimeUsec ?? -1)"
                if seen.insert(key).inserted {
                    merged.append(record)
                }
            }
        }
        return merged
    }

    private static func save(
        _ records: [AgentSurfaceChildRecord],
        appSupport: URL? = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    ) {
        guard let url = ledgerURL(appSupport: appSupport) else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(records)
            try data.write(to: url, options: .atomic)
        } catch {
            // Ledger persistence is best-effort; normal termination still reaps in-memory children.
        }
    }

    private static func removeLegacyLedger(appSupport: URL?) {
        guard let url = legacyLedgerURL(appSupport: appSupport),
              let data = try? Data(contentsOf: url),
              data.count <= maxLedgerBytes else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    static func record(
        pid: pid_t,
        name: String,
        appSupport: URL? = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    ) {
        guard pid > 0, let startTime = processStartTime(pid: pid) else { return }
        var records = load(appSupport: appSupport).filter { $0.pid != pid }
        records.append(AgentSurfaceChildRecord(
            pid: pid,
            startTimeSec: startTime.sec,
            startTimeUsec: startTime.usec,
            name: name
        ))
        save(records, appSupport: appSupport)
        removeLegacyLedger(appSupport: appSupport)
    }

    static func forget(
        pid: pid_t,
        appSupport: URL? = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    ) {
        let records = load(appSupport: appSupport).filter { $0.pid != pid }
        save(records, appSupport: appSupport)
        removeLegacyLedger(appSupport: appSupport)
    }

    static func clear(
        appSupport: URL? = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    ) {
        save([], appSupport: appSupport)
        removeLegacyLedger(appSupport: appSupport)
    }

    /// Reap children recorded by a previous instance. Signals only processes
    /// whose kernel start time still matches the record.
    static func sweepStaleChildren(
        graceNanoseconds: UInt64 = 1_500_000_000,
        appSupport: URL? = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ),
        diagnostics: (String) -> Void = { _ in }
    ) async {
        let records = load(appSupport: appSupport)
        guard !records.isEmpty else {
            removeLegacyLedger(appSupport: appSupport)
            return
        }

        var terminated: [AgentSurfaceChildRecord] = []
        for recordEntry in records {
            let pid = pid_t(recordEntry.pid)
            guard processStartTime(pid: pid) != nil else { continue }
            guard isSameProcess(recordEntry, pid: pid) else {
                diagnostics("[sweep] pid \(recordEntry.pid) (\(recordEntry.name)) was reused - skipping")
                continue
            }
            diagnostics("[sweep] terminating stale \(recordEntry.name) (pid \(recordEntry.pid)) from a previous instance")
            kill(pid, SIGTERM)
            terminated.append(recordEntry)
        }

        if !terminated.isEmpty {
            try? await Task.sleep(nanoseconds: graceNanoseconds)
            for recordEntry in terminated {
                let pid = pid_t(recordEntry.pid)
                if isSameProcess(recordEntry, pid: pid) {
                    diagnostics("[sweep] \(recordEntry.name) (pid \(recordEntry.pid)) survived SIGTERM - sending SIGKILL")
                    kill(pid, SIGKILL)
                }
            }
        }

        clear(appSupport: appSupport)
    }
}
#endif
