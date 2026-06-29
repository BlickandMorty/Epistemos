import Foundation

// Phase 1 (Step 2) — native Agent transcript reducer.
//
// Pure, UI-free reduction of the Goose ACP `session/update` stream into ordered render parts.
// This is the single source of truth the native chat canvas (AgentSessionCanvasView, Step 3) renders;
// it deliberately has NO WebKit / SwiftUI dependency so it is unit-testable against the F1–F5 golden
// fixtures (AgentTranscriptTests).
//
// Charter invariants honored here:
// - Thinking is NEVER merged into the answer stream (separate `.thinking` parts) — preserves thinking.
// - Tool cards carry only {id, title, kind, status} — NO unified-diff assumption (Round 2 §4).
// - Streamed chunks of the same kind coalesce into one part; a different kind (or a tool) starts a new
//   part, so `answer → tool → answer` yields three parts in order.
// - Part text is capped (`maxPartChars`) to bound memory on long streams.
// - Tool updates are applied idempotently by `toolCallId` (repeated `tool_call_update` is safe).

nonisolated enum AgentPartKind: String, Equatable, Sendable {
    case user
    case answer
    case thinking
    case tool
    case error
}

nonisolated struct AgentToolPart: Equatable, Sendable {
    let toolCallId: String
    var title: String
    var kind: GooseACPToolKind?
    var status: GooseACPToolCallStatus?
}

nonisolated struct AgentPart: Identifiable, Equatable, Sendable {
    /// Stable, monotonically-increasing id (insertion order) — safe as a SwiftUI `ForEach` identity.
    let id: Int
    let kind: AgentPartKind
    /// Display text for `.user`/`.answer`/`.thinking`/`.error`. Empty for `.tool`.
    var text: String
    /// Populated only for `.tool`.
    var tool: AgentToolPart?
}

nonisolated struct AgentTranscript: Equatable, Sendable {
    /// Per-part text cap (chars). Long streams keep the most recent content rather than growing without
    /// bound (matches the bounded-buffering rule used elsewhere in the codebase).
    static let maxPartChars = 200_000

    private(set) var parts: [AgentPart] = []
    private var nextID = 0
    /// toolCallId → index into `parts`. `parts` is append-only, so indices stay valid.
    private var toolIndexByCallId: [String: Int] = [:]

    init() {}

    mutating func apply(_ notification: GooseACPSessionNotification) {
        apply(notification.update)
    }

    mutating func apply(_ update: GooseACPSessionUpdate) {
        switch update {
        case .userMessageChunk(let chunk):
            appendText(displayText(of: chunk.content), kind: .user)
        case .agentMessageChunk(let chunk):
            appendText(displayText(of: chunk.content), kind: .answer)
        case .agentThoughtChunk(let chunk):
            appendText(displayText(of: chunk.content), kind: .thinking)
        case .toolCall(let call):
            upsertTool(id: call.toolCallId, title: call.title, kind: call.kind, status: call.status)
        case .toolCallUpdate(let update):
            upsertTool(id: update.toolCallId, title: update.title, kind: update.kind, status: update.status)
        case .sessionInfoUpdate, .usageUpdate, .unknown:
            // Session metadata / usage / forward-compat unknowns are NOT transcript content. They are
            // surfaced via the session header + diagnostics (Step 3/4), not silently dropped here.
            break
        }
    }

    /// Convenience for tests / batch replay.
    mutating func apply<S: Sequence>(_ updates: S) where S.Element == GooseACPSessionUpdate {
        for update in updates { apply(update) }
    }

    /// Surface a client/transport error as a visible `.error` part (charter: errors are visible in the
    /// transcript, never silently dropped). Used by the session controller for prompt/stream failures.
    mutating func applyErrorText(_ message: String) {
        appendText(message, kind: .error)
    }

    private func displayText(of block: GooseACPContentBlock) -> String? {
        switch block {
        case .text(let text):
            return text
        case .image:
            return "[image]"
        case .unknown:
            return nil
        }
    }

    private mutating func appendText(_ text: String?, kind: AgentPartKind) {
        guard let text, !text.isEmpty else { return }
        if let lastIndex = parts.indices.last,
           parts[lastIndex].kind == kind,
           parts[lastIndex].tool == nil {
            var merged = parts[lastIndex].text + text
            if merged.count > Self.maxPartChars {
                merged = String(merged.suffix(Self.maxPartChars))
            }
            parts[lastIndex].text = merged
        } else {
            parts.append(AgentPart(
                id: nextID,
                kind: kind,
                text: String(text.prefix(Self.maxPartChars)),
                tool: nil
            ))
            nextID += 1
        }
    }

    private mutating func upsertTool(
        id: String,
        title: String?,
        kind: GooseACPToolKind?,
        status: GooseACPToolCallStatus?
    ) {
        if let index = toolIndexByCallId[id] {
            // Idempotent merge — a `tool_call_update` only carries the fields it changes.
            if let title { parts[index].tool?.title = title }
            if let kind { parts[index].tool?.kind = kind }
            if let status { parts[index].tool?.status = status }
        } else {
            let tool = AgentToolPart(toolCallId: id, title: title ?? id, kind: kind, status: status)
            parts.append(AgentPart(id: nextID, kind: .tool, text: "", tool: tool))
            toolIndexByCallId[id] = parts.count - 1
            nextID += 1
        }
    }
}
