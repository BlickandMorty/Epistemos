import Foundation
import os

// MARK: - Main Thread Watchdog
//
// Detects UI hangs by periodically checking if the main thread is responsive.
// Uses a background GCD timer that pings the main queue — if the main queue
// doesn't respond within the threshold, logs a warning.
//
// This is the same approach used by MetricKit's MXHangDiagnostic but with
// lower-latency detection (configurable threshold, default 500ms).
//
// NOT @MainActor — this class uses raw GCD intentionally so it can detect
// main thread hangs without being blocked by them.

final class MainThreadWatchdog: Sendable {
    nonisolated private static let log = Logger(
        subsystem: "com.epistemos",
        category: "MainThreadWatchdog"
    )

    private let threshold: TimeInterval
    private let checkInterval: TimeInterval
    private let hangCoalescingDelay: TimeInterval
    private let hangEmissionQueue = DispatchQueue(
        label: "com.epistemos.watchdog.hang-emission",
        qos: .utility
    )
    private let state = OSAllocatedUnfairLock(initialState: WatchdogState())

    /// Callback fired when a hang is detected. Receives the hang duration in milliseconds.
    /// Set before calling start().
    nonisolated(unsafe) var onHangDetected: (@Sendable (_ durationMs: Int) -> Void)?

    struct HangBurstEmission: Sendable {
        let durationMs: Int
        let sampleCount: Int
    }

    struct HangBurstTracker: Sendable {
        private(set) var pendingDurationMs: Int?
        private(set) var pendingSampleCount = 0
        private(set) var sequence: UInt64 = 0

        nonisolated mutating func recordHangSample(durationMs: Int) -> UInt64 {
            pendingDurationMs = max(pendingDurationMs ?? 0, durationMs)
            pendingSampleCount += 1
            sequence &+= 1
            return sequence
        }

        nonisolated mutating func drainIfSequenceMatches(
            _ expectedSequence: UInt64
        ) -> HangBurstEmission? {
            guard sequence == expectedSequence,
                  let durationMs = pendingDurationMs else { return nil }
            let emission = HangBurstEmission(
                durationMs: durationMs,
                sampleCount: pendingSampleCount
            )
            pendingDurationMs = nil
            pendingSampleCount = 0
            return emission
        }

        nonisolated mutating func invalidate() {
            pendingDurationMs = nil
            pendingSampleCount = 0
            sequence &+= 1
        }
    }

    private struct WatchdogState {
        var timer: DispatchSourceTimer?
        var hangBurstTracker = HangBurstTracker()
    }

    /// Retained for process lifetime once installed.
    private static let shared = MainThreadWatchdog()
    nonisolated private static let sharedLogger = StructuredDiagnosticLogger()

    /// Install the watchdog. Safe to call from any isolation context.
    static func install() {
        shared.onHangDetected = { durationMs in
            sharedLogger.log(.hang(durationMs: durationMs, context: "main_thread"))
        }
        shared.start()
    }

    init(
        threshold: TimeInterval = 0.5,
        checkInterval: TimeInterval = 1.0,
        hangCoalescingDelay: TimeInterval = 0.1
    ) {
        self.threshold = threshold
        self.checkInterval = checkInterval
        self.hangCoalescingDelay = hangCoalescingDelay
    }

    func start() {
        state.withLock { s in
            guard s.timer == nil else { return }

            let source = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
            source.schedule(
                deadline: .now() + checkInterval,
                repeating: checkInterval,
                leeway: .milliseconds(100)
            )

            source.setEventHandler { [weak self] in
                self?.checkMainThread()
            }

            s.timer = source
            source.resume()
        }
        Self.log.info("Main thread watchdog started (threshold: \(self.threshold * 1000)ms)")
    }

    func stop() {
        state.withLock { s in
            s.timer?.cancel()
            s.timer = nil
            s.hangBurstTracker.invalidate()
        }
    }

    private nonisolated func checkMainThread() {
        let sendTime = DispatchTime.now().uptimeNanoseconds
        let thresholdMs = Int(threshold * 1000)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let pongTime = DispatchTime.now().uptimeNanoseconds
            let deltaMs = Int((pongTime - sendTime) / 1_000_000)

            if deltaMs > thresholdMs {
                let sequence = self.state.withLock { s in
                    s.hangBurstTracker.recordHangSample(durationMs: deltaMs)
                }
                self.scheduleHangBurstEmission(
                    expectedSequence: sequence,
                    thresholdMs: thresholdMs
                )
            } else {
                return
            }
        }
    }

    private nonisolated func scheduleHangBurstEmission(
        expectedSequence: UInt64,
        thresholdMs: Int
    ) {
        hangEmissionQueue.asyncAfter(deadline: .now() + hangCoalescingDelay) { [weak self] in
            guard let self else { return }
            guard let emission = self.state.withLock({
                $0.hangBurstTracker.drainIfSequenceMatches(expectedSequence)
            }) else { return }

            let sampleSummary = emission.sampleCount > 1
                ? ", coalesced samples: \(emission.sampleCount)"
                : ""
            Self.log.warning(
                "Main thread hang detected: \(emission.durationMs)ms (threshold: \(thresholdMs)ms\(sampleSummary))"
            )
            self.onHangDetected?(emission.durationMs)
        }
    }

    deinit {
        state.withLock { s in
            s.timer?.cancel()
            s.hangBurstTracker.invalidate()
        }
    }
}

// MARK: - Structured Diagnostic Logger
//
// Emits structured JSONL diagnostic events to a rotating log file.
// Claude and automated tools can ingest these for root cause analysis.

enum DiagnosticEvent {
    case hang(durationMs: Int, context: String)
    case toolGateFailed(toolName: String, reason: String)
    case bridgeError(line: String, error: String)
    case subprocessCrash(pid: Int32, exitCode: Int32)
    case tccDenied(service: String, bundle: String)
    case memoryPressure(
        level: String,
        usedMB: Int,
        pressureSource: String,
        memoryScope: String,
        isAppActive: Bool
    )
}

final class StructuredDiagnosticLogger: Sendable {
    nonisolated private static let log = Logger(
        subsystem: "com.epistemos",
        category: "Diagnostics"
    )

    private let logFileURL: URL
    private let maxFileSize: Int
    private let queue = DispatchQueue(label: "com.epistemos.diagnostics", qos: .utility)

    nonisolated init(
        logDirectory: URL = FoundationSafety.userApplicationSupportDirectory(fileManager: .default)
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("diagnostics", isDirectory: true),
        maxFileSize: Int = 5 * 1024 * 1024 // 5MB
    ) {
        self.logFileURL = logDirectory.appendingPathComponent("events.jsonl")
        self.maxFileSize = maxFileSize

        ensureLogDirectoryExists()
    }

    nonisolated func log(_ event: DiagnosticEvent) {
        let entry = encodeEvent(event)
        queue.async {
            self.appendLine(entry)
        }
    }

    /// Export the last N diagnostic events as a JSON array string
    /// suitable for pasting into a Claude session.
    nonisolated func exportRecent(limit: Int = 200) -> String {
        guard FileManager.default.fileExists(atPath: self.logFileURL.path) else {
            return "[]"
        }
        let text: String
        do {
            let data = try Data(contentsOf: self.logFileURL)
            guard let decoded = String(data: data, encoding: .utf8) else {
                Self.log.error("Structured diagnostics: failed to decode recent events as UTF-8 text")
                return "[]"
            }
            text = decoded
        } catch {
            Self.log.error(
                "Structured diagnostics: failed to load recent events: \(error.localizedDescription, privacy: .public)"
            )
            return "[]"
        }
        let lines = text.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .suffix(limit)
        return "[\(lines.joined(separator: ",\n"))]"
    }

    // MARK: - Private

    private nonisolated func encodeEvent(_ event: DiagnosticEvent) -> String {
        var dict: [String: Any] = [
            "ts": ISO8601DateFormatter().string(from: Date()),
            "pid": ProcessInfo.processInfo.processIdentifier,
        ]

        switch event {
        case .hang(let durationMs, let context):
            dict["event"] = "hang"
            dict["duration_ms"] = durationMs
            dict["context"] = context
        case .toolGateFailed(let toolName, let reason):
            dict["event"] = "tool_gate_failed"
            dict["tool"] = toolName
            dict["reason"] = reason
        case .bridgeError(let line, let error):
            dict["event"] = "bridge_error"
            dict["line_preview"] = String(line.prefix(200))
            dict["error"] = error
        case .subprocessCrash(let pid, let exitCode):
            dict["event"] = "subprocess_crash"
            dict["subprocess_pid"] = pid
            dict["exit_code"] = exitCode
        case .tccDenied(let service, let bundle):
            dict["event"] = "tcc_denied"
            dict["service"] = service
            dict["bundle"] = bundle
        case .memoryPressure(
            let level,
            let usedMB,
            let pressureSource,
            let memoryScope,
            let isAppActive
        ):
            dict["event"] = "memory_pressure"
            dict["level"] = level
            dict["used_mb"] = usedMB
            dict["pressure_source"] = pressureSource
            dict["memory_scope"] = memoryScope
            dict["app_active"] = isAppActive
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
            guard let json = String(data: data, encoding: .utf8) else {
                Self.log.error("Structured diagnostics: failed to encode event JSON as UTF-8 text")
                return "{\"event\":\"encode_error\"}"
            }
            return json
        } catch {
            Self.log.error("Structured diagnostics: failed to encode event: \(error.localizedDescription, privacy: .public)")
            return "{\"event\":\"encode_error\"}"
        }
    }

    private nonisolated func appendLine(_ line: String) {
        let entry = (line + "\n").data(using: .utf8) ?? Data()
        ensureLogDirectoryExists()

        do {
            if try shouldRotateLogFile() {
                try rotateLogFile()
            }

            if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                let handle = try FileHandle(forWritingTo: self.logFileURL)
                defer {
                    do {
                        try handle.close()
                    } catch {
                        Self.log.error(
                            "Structured diagnostics: failed to close log file handle: \(error.localizedDescription, privacy: .public)"
                        )
                    }
                }
                _ = try handle.seekToEnd()
                try handle.write(contentsOf: entry)
            } else {
                try entry.write(to: self.logFileURL)
            }
        } catch {
            Self.log.error("Structured diagnostics: failed to append log entry: \(error.localizedDescription, privacy: .public)")
        }
    }

    private nonisolated func ensureLogDirectoryExists() {
        do {
            try FileManager.default.createDirectory(
                at: self.logFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            Self.log.error(
                "Structured diagnostics: failed to create log directory at \(self.logFileURL.deletingLastPathComponent().path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private nonisolated func shouldRotateLogFile() throws -> Bool {
        guard FileManager.default.fileExists(atPath: self.logFileURL.path) else {
            return false
        }
        let attrs = try FileManager.default.attributesOfItem(atPath: self.logFileURL.path)
        let size = attrs[.size] as? Int ?? 0
        return size > self.maxFileSize
    }

    private nonisolated func rotateLogFile() throws {
        let rotatedURL = self.logFileURL.deletingPathExtension()
            .appendingPathExtension("prev.jsonl")
        if FileManager.default.fileExists(atPath: rotatedURL.path) {
            try FileManager.default.removeItem(at: rotatedURL)
        }
        try FileManager.default.moveItem(at: self.logFileURL, to: rotatedURL)
    }
}
