import Foundation
import os

// MARK: - Trace Event Schema
//
// Meta-Harness research: full traces beat summaries by 15+ accuracy points.
// Every agent interaction must be logged as structured JSONL for later
// harness evolution. Non-blocking, fire-and-forget writes.
//
// Events are appended to per-session JSONL files organized by date.
// The trace corpus is the foundation for the Harness Lab flywheel.

/// A single trace event, serialized as one line in a JSONL file.
struct TraceEvent: Sendable {
    let ts: String                  // ISO8601 timestamp
    let type: TraceEventType
    let sessionId: String
    let taskId: String?
    let harnessVersion: String
    let turn: Int?

    // Event-specific payload fields (all optional, populated per type)
    let provider: String?           // "cloud" | "local" | "foundationModels"
    let model: String?
    let tool: String?
    let toolInput: String?
    let toolOutput: String?
    let exitCode: Int?
    let durationMs: Int?
    let content: String?
    let tokensUsed: Int?
    let stopReason: String?
    let inputTokens: Int?
    let outputTokens: Int?
    let checkerType: String?
    let passed: Bool?
    let evidence: String?
    let errorMessage: String?
    let thermalState: String?
    let domain: String?
    let progressSnapshot: String?
    let bootstrapPacket: BootstrapPacket?

    enum TraceEventType: String, Codable, Sendable {
        case bootstrapPacket = "bootstrap_packet"
        case userIntent = "user_intent"
        case modelOutput = "model_output"
        case toolCall = "tool_call"
        case toolResult = "tool_result"
        case completionCheck = "completion_check"
        case sessionHandoff = "session_handoff"
        case sessionStart = "session_start"
        case sessionEnd = "session_end"
        case error = "error"
        case thermalChange = "thermal_change"
        case breakerTripped = "breaker_tripped"
        case progressUpdate = "progress_update"
    }
}

// MARK: - Trace Event Factories

extension TraceEvent {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func now() -> String { isoFormatter.string(from: Date()) }

    static func bootstrapPacketEvent(
        sessionId: String, taskId: String, harnessVersion: String, packet: BootstrapPacket
    ) -> TraceEvent {
        TraceEvent(
            ts: now(), type: .bootstrapPacket, sessionId: sessionId, taskId: taskId,
            harnessVersion: harnessVersion, turn: nil,
            provider: nil, model: nil, tool: nil, toolInput: nil, toolOutput: nil,
            exitCode: nil, durationMs: nil, content: nil, tokensUsed: nil,
            stopReason: nil, inputTokens: nil, outputTokens: nil,
            checkerType: nil, passed: nil, evidence: nil, errorMessage: nil,
            thermalState: nil, domain: nil, progressSnapshot: nil, bootstrapPacket: packet
        )
    }

    static func userIntentEvent(
        sessionId: String, taskId: String?, harnessVersion: String, content: String
    ) -> TraceEvent {
        TraceEvent(
            ts: now(), type: .userIntent, sessionId: sessionId, taskId: taskId,
            harnessVersion: harnessVersion, turn: nil,
            provider: nil, model: nil, tool: nil, toolInput: nil, toolOutput: nil,
            exitCode: nil, durationMs: nil, content: String(content.prefix(4000)),
            tokensUsed: nil, stopReason: nil, inputTokens: nil, outputTokens: nil,
            checkerType: nil, passed: nil, evidence: nil, errorMessage: nil,
            thermalState: nil, domain: nil, progressSnapshot: nil, bootstrapPacket: nil
        )
    }

    static func modelOutputEvent(
        sessionId: String, taskId: String?, harnessVersion: String,
        turn: Int, provider: String, model: String?, tokensUsed: Int, content: String
    ) -> TraceEvent {
        TraceEvent(
            ts: now(), type: .modelOutput, sessionId: sessionId, taskId: taskId,
            harnessVersion: harnessVersion, turn: turn,
            provider: provider, model: model, tool: nil, toolInput: nil, toolOutput: nil,
            exitCode: nil, durationMs: nil, content: String(content.prefix(8000)),
            tokensUsed: tokensUsed, stopReason: nil, inputTokens: nil, outputTokens: nil,
            checkerType: nil, passed: nil, evidence: nil, errorMessage: nil,
            thermalState: nil, domain: nil, progressSnapshot: nil, bootstrapPacket: nil
        )
    }

    static func toolCallEvent(
        sessionId: String, taskId: String?, harnessVersion: String,
        turn: Int, tool: String, input: String, output: String,
        exitCode: Int? = nil, durationMs: Int? = nil
    ) -> TraceEvent {
        TraceEvent(
            ts: now(), type: .toolCall, sessionId: sessionId, taskId: taskId,
            harnessVersion: harnessVersion, turn: turn,
            provider: nil, model: nil, tool: tool,
            toolInput: String(input.prefix(4000)), toolOutput: String(output.prefix(8000)),
            exitCode: exitCode, durationMs: durationMs, content: nil,
            tokensUsed: nil, stopReason: nil, inputTokens: nil, outputTokens: nil,
            checkerType: nil, passed: nil, evidence: nil, errorMessage: nil,
            thermalState: nil, domain: nil, progressSnapshot: nil, bootstrapPacket: nil
        )
    }

    static func completionCheckEvent(
        sessionId: String, taskId: String?, harnessVersion: String,
        checkerType: String, passed: Bool, evidence: String?
    ) -> TraceEvent {
        TraceEvent(
            ts: now(), type: .completionCheck, sessionId: sessionId, taskId: taskId,
            harnessVersion: harnessVersion, turn: nil,
            provider: nil, model: nil, tool: nil, toolInput: nil, toolOutput: nil,
            exitCode: nil, durationMs: nil, content: nil,
            tokensUsed: nil, stopReason: nil, inputTokens: nil, outputTokens: nil,
            checkerType: checkerType, passed: passed, evidence: evidence, errorMessage: nil,
            thermalState: nil, domain: nil, progressSnapshot: nil, bootstrapPacket: nil
        )
    }

    static func sessionEndEvent(
        sessionId: String, harnessVersion: String,
        stopReason: String, inputTokens: Int, outputTokens: Int
    ) -> TraceEvent {
        TraceEvent(
            ts: now(), type: .sessionEnd, sessionId: sessionId, taskId: nil,
            harnessVersion: harnessVersion, turn: nil,
            provider: nil, model: nil, tool: nil, toolInput: nil, toolOutput: nil,
            exitCode: nil, durationMs: nil, content: nil,
            tokensUsed: nil, stopReason: stopReason,
            inputTokens: inputTokens, outputTokens: outputTokens,
            checkerType: nil, passed: nil, evidence: nil, errorMessage: nil,
            thermalState: nil, domain: nil, progressSnapshot: nil, bootstrapPacket: nil
        )
    }

    static func errorEvent(
        sessionId: String, harnessVersion: String, message: String, domain: String? = nil
    ) -> TraceEvent {
        TraceEvent(
            ts: now(), type: .error, sessionId: sessionId, taskId: nil,
            harnessVersion: harnessVersion, turn: nil,
            provider: nil, model: nil, tool: nil, toolInput: nil, toolOutput: nil,
            exitCode: nil, durationMs: nil, content: nil,
            tokensUsed: nil, stopReason: nil, inputTokens: nil, outputTokens: nil,
            checkerType: nil, passed: nil, evidence: nil,
            errorMessage: String(message.prefix(2000)),
            thermalState: nil, domain: domain, progressSnapshot: nil, bootstrapPacket: nil
        )
    }
}

// MARK: - Trace Collector Actor

/// Non-blocking JSONL trace logger. Writes per-session trace files to disk.
/// Fire-and-forget: callers use `record()` which does not await.
///
/// Traces are stored at:
///   ~/Library/Application Support/com.epistemos.app/traces/production/YYYY-MM-DD/
///
/// File layout per session: {sessionId}.jsonl (one JSON object per line)
actor TraceCollector {
    static let shared = TraceCollector()

    private static let log = Logger(subsystem: "com.epistemos", category: "TraceCollector")

    private let baseDir: URL
    private var fileHandles: [String: FileHandle] = [:]

    init() {
        let appSupport = FoundationSafety.userApplicationSupportDirectory()
        self.baseDir = appSupport.appendingPathComponent("com.epistemos.app/traces/production")
    }

    /// For testing: create with a custom base directory.
    init(baseDir: URL) {
        self.baseDir = baseDir
    }

    // MARK: - Non-Blocking API

    /// Fire-and-forget trace recording. Does not block the caller.
    nonisolated func record(_ event: TraceEvent) {
        Task { await _record(event) }
    }

    // MARK: - Internal

    private func _record(_ event: TraceEvent) {
        guard let data = event.toJSONData() else {
            Self.log.error("Failed to serialize trace event")
            return
        }
        do {
            let handle = try fileHandle(for: event.sessionId)
            handle.write(data)
            handle.write(Data("\n".utf8))
        } catch {
            Self.log.error("Failed to write trace event: \(error.localizedDescription)")
        }
    }

    private func fileHandle(for sessionId: String) throws -> FileHandle {
        if let existing = fileHandles[sessionId] { return existing }

        let dateStr = Self.dateString()
        let dir = baseDir.appendingPathComponent(dateStr)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let sanitized = sessionId.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "..", with: "_")
        let path = dir.appendingPathComponent("\(sanitized).jsonl")

        if !FileManager.default.fileExists(atPath: path.path) {
            FileManager.default.createFile(atPath: path.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: path)
        handle.seekToEndOfFile()
        fileHandles[sessionId] = handle
        return handle
    }

    /// Close all open file handles. Call on app termination.
    func closeAll() {
        for (_, handle) in fileHandles {
            try? handle.close()
        }
        fileHandles.removeAll()
    }

    /// Close a specific session's file handle.
    func closeSession(_ sessionId: String) {
        if let handle = fileHandles.removeValue(forKey: sessionId) {
            try? handle.close()
        }
    }

    private nonisolated static func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}

// MARK: - Manual JSON Serialization
// Swift 6.2 infers MainActor isolation on auto-synthesized Codable
// conformances, which blocks use inside non-MainActor actors.
// Manual serialization avoids this entirely.

extension TraceEvent {
    /// Serialize to JSON Data without using Codable (avoids isolation issues).
    nonisolated func toJSONData() -> Data? {
        var dict: [String: Any] = [
            "ts": ts,
            "type": type.rawValue,
            "sessionId": sessionId,
            "harnessVersion": harnessVersion
        ]
        if let v = taskId { dict["taskId"] = v }
        if let v = turn { dict["turn"] = v }
        if let v = provider { dict["provider"] = v }
        if let v = model { dict["model"] = v }
        if let v = tool { dict["tool"] = v }
        if let v = toolInput { dict["toolInput"] = v }
        if let v = toolOutput { dict["toolOutput"] = v }
        if let v = exitCode { dict["exitCode"] = v }
        if let v = durationMs { dict["durationMs"] = v }
        if let v = content { dict["content"] = v }
        if let v = tokensUsed { dict["tokensUsed"] = v }
        if let v = stopReason { dict["stopReason"] = v }
        if let v = inputTokens { dict["inputTokens"] = v }
        if let v = outputTokens { dict["outputTokens"] = v }
        if let v = checkerType { dict["checkerType"] = v }
        if let v = passed { dict["passed"] = v }
        if let v = evidence { dict["evidence"] = v }
        if let v = errorMessage { dict["errorMessage"] = v }
        if let v = thermalState { dict["thermalState"] = v }
        if let v = domain { dict["domain"] = v }
        if let v = progressSnapshot { dict["progressSnapshot"] = v }
        // BootstrapPacket is omitted from trace JSON for compactness;
        // it is stored separately in bootstrap_packet.json
        return try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys])
    }
}
