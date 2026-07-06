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

    static func ledgerURL(
        appSupport: URL? = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    ) -> URL? {
        appSupport?
            .appendingPathComponent("Epistemos", isDirectory: true)
            // Keep the legacy filename so already-recorded children are swept.
            .appendingPathComponent("pro-agent-children.json")
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

    private static func load() -> [AgentSurfaceChildRecord] {
        guard let url = ledgerURL(),
              let data = try? Data(contentsOf: url),
              data.count <= maxLedgerBytes,
              let records = try? JSONDecoder().decode([AgentSurfaceChildRecord].self, from: data) else {
            return []
        }
        return records
    }

    private static func save(_ records: [AgentSurfaceChildRecord]) {
        guard let url = ledgerURL() else { return }
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

    static func record(pid: pid_t, name: String) {
        guard pid > 0, let startTime = processStartTime(pid: pid) else { return }
        var records = load().filter { $0.pid != pid }
        records.append(AgentSurfaceChildRecord(
            pid: pid,
            startTimeSec: startTime.sec,
            startTimeUsec: startTime.usec,
            name: name
        ))
        save(records)
    }

    static func forget(pid: pid_t) {
        let records = load().filter { $0.pid != pid }
        save(records)
    }

    static func clear() {
        save([])
    }

    /// Reap children recorded by a previous instance. Signals only processes
    /// whose kernel start time still matches the record.
    static func sweepStaleChildren(
        graceNanoseconds: UInt64 = 1_500_000_000,
        diagnostics: (String) -> Void = { _ in }
    ) async {
        let records = load()
        guard !records.isEmpty else { return }

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

        clear()
    }
}
#endif
