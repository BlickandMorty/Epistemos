import Foundation
import Observation

@MainActor @Observable
final class OmegaLiveRuntimeState {
    struct EventSnapshot: Identifiable, Sendable, Equatable {
        let id: UInt64
        let phase: String
        let payload: String
        let timestamp: String
    }

    struct TurnSnapshot: Sendable, Equatable {
        let sessionId: String
        let stopReason: String
        let assistantText: String
        let turnCount: Int
        let emittedEventCount: Int
        let transcriptPath: String
    }

    struct PhaseSnapshot: Identifiable, Sendable, Equatable {
        enum Kind: String, Sendable, Equatable {
            case idle
            case planning
            case thinking
            case reasoning
            case searching
            case executing
            case awaitingApproval
            case responding
            case complete
            case failed

            var title: String {
                switch self {
                case .idle: "Idle"
                case .planning: "Planning"
                case .thinking: "Thinking"
                case .reasoning: "Reasoning"
                case .searching: "Searching"
                case .executing: "Executing"
                case .awaitingApproval: "Awaiting Approval"
                case .responding: "Responding"
                case .complete: "Complete"
                case .failed: "Failed"
                }
            }

            var iconName: String {
                switch self {
                case .idle: "circle"
                case .planning: "list.bullet.rectangle"
                case .thinking: "brain"
                case .reasoning: "sparkles.rectangle.stack"
                case .searching: "globe"
                case .executing: "hammer"
                case .awaitingApproval: "hand.raised"
                case .responding: "text.cursor"
                case .complete: "checkmark.circle.fill"
                case .failed: "xmark.octagon.fill"
                }
            }
        }

        let id: UInt64
        let kind: Kind
        let detail: String
        let timestamp: String
    }

    private(set) var sessionId: String = ""
    private(set) var transcriptPath: String = ""
    private(set) var transcriptJSONL: String = ""
    private(set) var lastTurn: TurnSnapshot?
    private(set) var events: [EventSnapshot] = []
    private(set) var phaseHistory: [PhaseSnapshot] = []
    private(set) var currentPhase: PhaseSnapshot?
    private(set) var lastError: String?

    @ObservationIgnored
    private var session: AgentSession?

    @ObservationIgnored
    private var nextPhaseID: UInt64 = 1

    @ObservationIgnored
    private nonisolated(unsafe) static var transcriptRootURLOverrideForTesting: URL?

    var hasContent: Bool {
        lastTurn != nil || !events.isEmpty || !transcriptPath.isEmpty || currentPhase != nil
    }

    func reset() {
        session = nil
        sessionId = ""
        transcriptPath = ""
        transcriptJSONL = ""
        lastTurn = nil
        events.removeAll()
        phaseHistory.removeAll()
        currentPhase = nil
        lastError = nil
        nextPhaseID = 1
    }

    func runScaffoldTurn(taskDescription: String) {
        reset()

        let trimmed = taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let sessionID = Self.makeSessionID(from: trimmed)
        let sessionURL = Self.transcriptRootURL()
            .appendingPathComponent(sessionID, isDirectory: true)
        let transcriptURL = sessionURL.appendingPathComponent("transcript.jsonl", isDirectory: false)
        try? FileManager.default.createDirectory(at: sessionURL, withIntermediateDirectories: true)

        let thinkingText = "Local runtime session initialized for on-device planning."
        let assistantText = "Local runtime captured this task and is waiting for the Swift orchestrator to plan execution."
        let userTimestamp = Self.timestampString()
        let assistantTimestamp = Self.timestampString()
        let transcript = [
            Self.transcriptLine(
                sessionId: sessionID,
                timestamp: userTimestamp,
                role: "user",
                content: [[
                    "kind": "text",
                    "text": trimmed,
                    "tool_call_id": "",
                    "tool_name": "",
                    "payload_json": "",
                ]]
            ),
            Self.transcriptLine(
                sessionId: sessionID,
                timestamp: assistantTimestamp,
                role: "assistant",
                content: [[
                    "kind": "thinking",
                    "text": thinkingText,
                    "tool_call_id": "",
                    "tool_name": "",
                    "payload_json": "",
                ], [
                    "kind": "text",
                    "text": assistantText,
                    "tool_call_id": "",
                    "tool_name": "",
                    "payload_json": "",
                ]]
            ),
        ].joined(separator: "\n") + "\n"
        try? transcript.write(to: transcriptURL, atomically: true, encoding: .utf8)

        session = nil
        sessionId = sessionID
        transcriptPath = transcriptURL.path
        transcriptJSONL = transcript
        lastTurn = TurnSnapshot(
            sessionId: sessionID,
            stopReason: "end_turn",
            assistantText: assistantText,
            turnCount: 1,
            emittedEventCount: 3,
            transcriptPath: transcriptURL.path
        )
        events = [
            EventSnapshot(id: 1, phase: "thinking_delta", payload: thinkingText, timestamp: userTimestamp),
            EventSnapshot(id: 2, phase: "text_delta", payload: assistantText, timestamp: assistantTimestamp),
            EventSnapshot(id: 3, phase: "complete", payload: "Local runtime transcript ready", timestamp: assistantTimestamp),
        ]
        recordPhase(.thinking, detail: thinkingText)
        recordPhase(.responding, detail: assistantText)
        recordPhase(.complete, detail: "Local runtime transcript ready")
        lastError = nil
    }

    func markPlanning(_ taskDescription: String) {
        recordPhase(.planning, detail: taskDescription)
    }

    func markAwaitingApproval(for step: AgentStep) {
        recordPhase(.awaitingApproval, detail: step.description)
    }

    func markExecuting(step: AgentStep) {
        let kind = Self.phaseKind(for: step)
        recordPhase(kind, detail: step.description)
    }

    func markStepResult(_ result: AgentStepResult, step: AgentStep) {
        guard result.success else {
            markFailure(result.error ?? "Step failed")
            return
        }
        recordPhase(
            .reasoning,
            detail: "\(step.toolName) completed in \(result.durationMs)ms"
        )
    }

    func markComplete(_ detail: String) {
        recordPhase(.complete, detail: detail)
    }

    func markFailure(_ detail: String) {
        lastError = detail
        recordPhase(.failed, detail: detail)
    }

    func markCancelled() {
        markFailure("Execution cancelled")
    }

    nonisolated static func setTranscriptRootURLOverrideForTesting(_ url: URL?) {
        transcriptRootURLOverrideForTesting = url
    }

    private func syncPhases(from drainedEvents: [AgentEvent]) {
        for event in drainedEvents {
            switch event.phase {
            case "thinking_delta":
                recordPhase(.thinking, detail: event.payload)
            case "text_delta":
                recordPhase(.responding, detail: event.payload)
            case "tool_start":
                let toolName = Self.toolName(from: event.payload, keys: ["name", "tool_name"])
                recordPhase(.executing, detail: toolName.isEmpty ? event.payload : toolName)
            case "tool_result":
                let toolName = Self.toolName(from: event.payload, keys: ["tool_name", "name"])
                let detail = toolName.isEmpty ? "Tool result received" : "\(toolName) returned"
                recordPhase(.reasoning, detail: detail)
            case "complete":
                recordPhase(.complete, detail: event.payload)
            case "error":
                markFailure(event.payload)
            default:
                break
            }
        }
    }

    private func recordPhase(_ kind: PhaseSnapshot.Kind, detail: String) {
        let isUpdatingCurrent = currentPhase?.kind == kind && !phaseHistory.isEmpty
        let snapshot = PhaseSnapshot(
            id: isUpdatingCurrent ? phaseHistory[phaseHistory.count - 1].id : nextPhaseID,
            kind: kind,
            detail: Self.compactDetail(detail),
            timestamp: Self.timestampString()
        )

        if isUpdatingCurrent {
            phaseHistory[phaseHistory.count - 1] = snapshot
        } else {
            phaseHistory.append(snapshot)
            nextPhaseID += 1
        }

        currentPhase = snapshot
    }

    private nonisolated static func transcriptRootURL() -> URL {
        let root = transcriptRootURLOverrideForTesting
            ?? FoundationSafety.userApplicationSupportDirectory()
                .appendingPathComponent("Epistemos", isDirectory: true)
                .appendingPathComponent("OmegaAgentSessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private nonisolated static func makeSessionID(from taskDescription: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let slugScalars = taskDescription.lowercased().unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let slug = String(slugScalars)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let prefix = slug.isEmpty ? "omega" : String(slug.prefix(48))
        return "\(prefix)-\(UUID().uuidString.lowercased())"
    }

    private nonisolated static func timestampString() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private nonisolated static func compactDetail(_ detail: String) -> String {
        let squashed = detail
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard squashed.count > 160 else { return squashed }
        return String(squashed.prefix(157)) + "..."
    }

    private nonisolated static func transcriptLine(
        sessionId: String,
        timestamp: String,
        role: String,
        content: [[String: String]]
    ) -> String {
        let payload: [String: Any] = [
            "session_id": sessionId,
            "timestamp": timestamp,
            "role": role,
            "content": content,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            return ""
        }
        return json
    }

    private nonisolated static func phaseKind(for step: AgentStep) -> PhaseSnapshot.Kind {
        let toolName = step.toolName.lowercased()
        let description = step.description.lowercased()
        if toolName.contains("search") || toolName.contains("fetch") || description.contains("search") {
            return .searching
        }
        return .executing
    }

    private nonisolated static func toolName(from payload: String, keys: [String]) -> String {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ""
        }

        for key in keys {
            if let value = object[key] as? String, !value.isEmpty {
                return value
            }
        }
        return ""
    }
}
