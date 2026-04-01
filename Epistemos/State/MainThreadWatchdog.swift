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
    static let log = Logger(subsystem: "com.epistemos", category: "MainThreadWatchdog")

    private let threshold: TimeInterval
    private let checkInterval: TimeInterval
    private let state = OSAllocatedUnfairLock(initialState: WatchdogState())

    /// Callback fired when a hang is detected. Receives the hang duration in milliseconds.
    /// Set before calling start().
    nonisolated(unsafe) var onHangDetected: (@Sendable (_ durationMs: Int) -> Void)?

    private struct WatchdogState {
        var timer: DispatchSourceTimer?
        var consecutiveHangs: Int = 0
    }

    /// Retained for process lifetime once installed.
    private static let shared = MainThreadWatchdog()
    nonisolated(unsafe) private static let sharedLogger = StructuredDiagnosticLogger()

    /// Install the watchdog. Safe to call from any isolation context.
    static func install() {
        shared.onHangDetected = { durationMs in
            sharedLogger.log(.hang(durationMs: durationMs, context: "main_thread"))
        }
        shared.start()
    }

    init(threshold: TimeInterval = 0.5, checkInterval: TimeInterval = 1.0) {
        self.threshold = threshold
        self.checkInterval = checkInterval
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
                let consecutive = self.state.withLock { s in
                    s.consecutiveHangs += 1
                    return s.consecutiveHangs
                }
                Self.log.warning(
                    "Main thread hang detected: \(deltaMs)ms (threshold: \(thresholdMs)ms, consecutive: \(consecutive))"
                )
                self.onHangDetected?(deltaMs)
            } else {
                self.state.withLock { s in
                    s.consecutiveHangs = 0
                }
            }
        }
    }

    deinit {
        state.withLock { s in
            s.timer?.cancel()
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
    case memoryPressure(level: String, usedMB: Int)
}

final class StructuredDiagnosticLogger: Sendable {
    static let log = Logger(subsystem: "com.epistemos", category: "Diagnostics")

    private let logFileURL: URL
    private let maxFileSize: Int
    private let queue = DispatchQueue(label: "com.epistemos.diagnostics", qos: .utility)

    nonisolated init(
        logDirectory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("diagnostics", isDirectory: true),
        maxFileSize: Int = 5 * 1024 * 1024 // 5MB
    ) {
        self.logFileURL = logDirectory.appendingPathComponent("events.jsonl")
        self.maxFileSize = maxFileSize

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: logDirectory, withIntermediateDirectories: true, attributes: nil
        )
    }

    nonisolated func log(_ event: DiagnosticEvent) {
        let entry = encodeEvent(event)
        queue.async { [weak self] in
            self?.appendLine(entry)
        }
    }

    /// Export the last N diagnostic events as a JSON array string
    /// suitable for pasting into a Claude session.
    nonisolated func exportRecent(limit: Int = 200) -> String {
        guard let data = try? Data(contentsOf: logFileURL),
              let text = String(data: data, encoding: .utf8) else {
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
        case .memoryPressure(let level, let usedMB):
            dict["event"] = "memory_pressure"
            dict["level"] = level
            dict["used_mb"] = usedMB
        }

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"event\":\"encode_error\"}"
        }
        return json
    }

    private nonisolated func appendLine(_ line: String) {
        let entry = (line + "\n").data(using: .utf8) ?? Data()

        // Rotate if file exceeds max size
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
           let size = attrs[.size] as? Int,
           size > maxFileSize {
            let rotatedURL = logFileURL.deletingPathExtension()
                .appendingPathExtension("prev.jsonl")
            try? FileManager.default.removeItem(at: rotatedURL)
            try? FileManager.default.moveItem(at: logFileURL, to: rotatedURL)
        }

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                handle.seekToEndOfFile()
                handle.write(entry)
                handle.closeFile()
            }
        } else {
            try? entry.write(to: logFileURL)
        }
    }
}
