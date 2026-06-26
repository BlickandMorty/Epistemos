import Foundation
import Observation

// Decodes WorkOpenGUISupervisor.onEvent LiveSessionEvent JSON → a render-ready NATIVE transcript. This is the layer
// that guarantees the Work visual target "NO raw JSON / log / terminal debris in assistant prose": it accumulates
// assistant text by partId, keeps THINKING separate from the ANSWER, models tool calls as native cards (name +
// status, never raw tool I/O dumped as prose), tracks run status, and de-dupes by `seq` (the known onEvent
// double-fire). Pure deterministic reduce + @Observable so the native Work view binds to it. The event schema mirrors
// `@opengui/runtime` live-session-event.ts EXACTLY (base: version/id/seq/type/scope/runId?/messageId?/partId?).

struct WorkTranscriptPart: Identifiable, Sendable, Equatable {
    enum Kind: String, Sendable, Equatable {
        case user       // a user prompt (live message.role=="user" OR history replay) — shown distinctly from prose
        case answer     // assistant answer text (partKind "text")
        case thinking   // assistant reasoning (partKind "thinking") — shown collapsed/dim, not as answer prose
        case tool       // a native tool card (name + status + optional output)
        case error      // a session error surfaced natively
    }
    let id: String
    var kind: Kind
    var text: String
    var toolName: String?
    var toolStatus: String?   // "running" until tool.finished supplies the harness status
    var toolSummary: String?  // compact, debris-safe one-line of the tool's input (command/file/pattern/url; never content)
    var messageID: String?    // owning live messageId → role lookup (live user-vs-assistant labeling). nil for replay.
    var fileDiffs: [String] = []   // unified file diffs for an edit/write tool card (history replay; see projector)
}

enum WorkTranscriptBounds {
    nonisolated static let maxPartCharacters = 200_000
    nonisolated static let maxDiffCharacters = 120_000
    nonisolated static let maxDiffsPerTool = 32
    nonisolated private static let marker = "\n[truncated]"

    nonisolated static func clampedPartText(_ text: String) -> String {
        clamped(text, maxCharacters: maxPartCharacters)
    }

    nonisolated static func appendingPartText(_ existing: String, _ addition: String) -> String {
        guard !existing.hasSuffix(marker) else { return existing }
        return clamped(existing + addition, maxCharacters: maxPartCharacters)
    }

    nonisolated static func clampedDiff(_ diff: String) -> String {
        clamped(diff, maxCharacters: maxDiffCharacters)
    }

    nonisolated static func clampedDiffs(_ diffs: [String]) -> [String] {
        Array(diffs.prefix(maxDiffsPerTool)).map(clampedDiff)
    }

    private nonisolated static func clamped(_ text: String, maxCharacters: Int) -> String {
        guard text.count > maxCharacters else { return text }
        return String(text.prefix(maxCharacters)) + marker
    }
}

enum WorkRunStatus: String, Sendable, Equatable {
    case idle, running, error
}

@MainActor
@Observable
final class WorkEngineTranscript {
    private(set) var parts: [WorkTranscriptPart] = []
    private(set) var status: WorkRunStatus = .idle
    private(set) var lastError: String?

    private var seenSeq = Set<Int>()
    private var partIndex: [String: Int] = [:]   // partId → index in `parts` (accumulation target)
    private var messageRole: [String: String] = [:]   // messageId → role (live user-vs-assistant labeling)
    private var pendingToolInputCandidates: [String: [String: String]] = [:]

    /// Clear for a new session (switching the active session in the rail).
    func reset() {
        parts = []
        status = .idle
        lastError = nil
        seenSeq = []
        partIndex = [:]
        messageRole = [:]
        pendingToolInputCandidates = [:]
    }

    /// Replay a reopened session's history (from WorkSessionHistoryProjector) into the transcript. Replayed parts get
    /// fresh ids so they never collide with live seq/partId accumulation that follows.
    func replay(history: [WorkHistoryMessage]) {
        reset()
        var n = 0
        for message in history {
            let isUser = message.role == "user"
            for part in message.parts {
                n += 1
                let kind: WorkTranscriptPart.Kind
                switch part.kind {
                case .text: kind = isUser ? .user : .answer
                case .thinking: kind = .thinking
                case .tool: kind = .tool
                case .other: kind = .answer
                }
                parts.append(WorkTranscriptPart(
                    id: "h\(n)", kind: kind, text: WorkTranscriptBounds.clampedPartText(part.text),
                    toolName: part.toolName, toolStatus: part.toolStatus, toolSummary: part.toolSummary,
                    fileDiffs: WorkTranscriptBounds.clampedDiffs(part.fileDiffs)))
            }
        }
    }

    /// The accumulated assistant ANSWER text (excludes thinking/tool/error) — what a plain transcript shows.
    var answerText: String {
        parts.filter { $0.kind == .answer }.map(\.text).joined()
    }

    /// Merge post-run `messages()` metadata back into live-streamed tool cards. LiveSessionEvent never carries edit
    /// diffs, but `messages()` does after the tool settles; matching by the OpenGUI part id keeps this bounded and avoids
    /// replacing streamed prose/output with replay content.
    func mergeFileDiffs(history: [WorkHistoryMessage]) {
        for message in history {
            for part in message.parts where part.kind == .tool && !part.fileDiffs.isEmpty {
                guard let id = part.id, let idx = partIndex[id] else { continue }
                parts[idx].fileDiffs = WorkTranscriptBounds.clampedDiffs(part.fileDiffs)
                if parts[idx].toolName == nil { parts[idx].toolName = part.toolName }
                if parts[idx].toolSummary == nil { parts[idx].toolSummary = part.toolSummary }
                if let status = part.toolStatus { parts[idx].toolStatus = status }
            }
        }
    }

    /// Ingest one LiveSessionEvent (raw JSON from the sidecar). Unknown / duplicate / non-transcript events are no-ops.
    func ingest(eventJSON: Data) {
        guard let obj = (try? JSONSerialization.jsonObject(with: eventJSON)) as? [String: Any],
              let type = obj["type"] as? String else { return }
        if let seq = obj["seq"] as? Int {
            if seenSeq.contains(seq) { return } // de-dupe the known onEvent double-fire
            seenSeq.insert(seq)
        }
        switch type {
        case "run.started":
            status = .running
        case "run.finished":
            status = (obj["reason"] as? String == "error") ? .error : .idle
        case "message.started":
            recordRole(obj)
        case "part.text.appended":
            applyText(obj, replace: false)
        case "part.text.replaced":
            applyText(obj, replace: true)
        case "tool.started":
            upsertTool(obj, name: obj["tool"] as? String, status: "running")
        case "tool.input.updated":
            applyToolInput(obj)
        case "tool.output.appended":
            applyToolOutput(obj, replace: false)
        case "tool.output.replaced":
            applyToolOutput(obj, replace: true)
        case "tool.finished":
            upsertTool(obj, name: nil, status: obj["status"] as? String ?? "finished")
        case "session.error":
            status = .error
            let message = obj["message"] as? String ?? "session error"
            lastError = WorkTranscriptBounds.clampedPartText(message)
            parts.append(WorkTranscriptPart(
                id: "err_\(parts.count)", kind: .error, text: lastError ?? "session error",
                toolName: nil, toolStatus: nil))
        default:
            break // message.finished, part.started, part.state.changed, transcript.rebased
        }
    }

    // MARK: reduce helpers

    /// Stable accumulation key — partId when present (the canonical case), else messageId; unrouteable chunks drop.
    private func partKey(_ obj: [String: Any]) -> String? {
        if let partID = obj["partId"] as? String, !partID.isEmpty { return partID }
        if let messageID = obj["messageId"] as? String, !messageID.isEmpty { return messageID }
        return nil
    }

    /// Record a message's role (from message.started) + retro-relabel any text parts already created for it. The live
    /// stream carries the USER message too (mirrors OpenGUI live-session-projection.ts: message-centric, role per
    /// message) — without this a user prompt streams in styled as an assistant ANSWER (live ≠ history replay). Set once
    /// per message (first non-nil role wins), mirroring the projection's `role && !message.role` guard.
    private func recordRole(_ obj: [String: Any]) {
        guard let messageID = obj["messageId"] as? String, let role = obj["role"] as? String,
              messageRole[messageID] == nil else { return }
        messageRole[messageID] = role
        guard role == "user" else { return }
        for i in parts.indices where parts[i].messageID == messageID && parts[i].kind == .answer {
            parts[i].kind = .user   // a text part landed before its message.started → fix its labeling now
        }
    }

    private func applyText(_ obj: [String: Any], replace: Bool) {
        guard let text = obj["text"] as? String, let key = partKey(obj) else { return }
        let messageID = obj["messageId"] as? String
        let role = messageID.flatMap { messageRole[$0] }
        let kind: WorkTranscriptPart.Kind
        if obj["partKind"] as? String == "thinking" {
            kind = .thinking
        } else if role == "user" {
            kind = .user        // the live stream echoes the user's own message — label it, don't show it as an answer
        } else {
            kind = .answer
        }
        if let idx = partIndex[key] {
            parts[idx].text = replace ? WorkTranscriptBounds.clampedPartText(text) :
                WorkTranscriptBounds.appendingPartText(parts[idx].text, text)
            parts[idx].kind = kind
        } else {
            partIndex[key] = parts.count
            parts.append(WorkTranscriptPart(
                id: key, kind: kind, text: WorkTranscriptBounds.clampedPartText(text),
                toolName: nil, toolStatus: nil, messageID: messageID))
        }
    }

    private func upsertTool(_ obj: [String: Any], name: String?, status: String?) {
        guard let key = partKey(obj) else { return }
        if let idx = partIndex[key] {
            if let name { parts[idx].toolName = name }
            if let status { parts[idx].toolStatus = status }
            if parts[idx].toolSummary == nil,
               let summary = WorkToolInputSummary.summary(
                toolName: parts[idx].toolName,
                candidates: pendingToolInputCandidates[key] ?? [:]) {
                parts[idx].toolSummary = summary
                pendingToolInputCandidates[key] = nil
            }
            parts[idx].kind = .tool
        } else {
            partIndex[key] = parts.count
            let summary = WorkToolInputSummary.summary(
                toolName: name,
                candidates: pendingToolInputCandidates[key] ?? [:])
            if summary != nil { pendingToolInputCandidates[key] = nil }
            parts.append(WorkTranscriptPart(
                id: key, kind: .tool, text: "", toolName: name, toolStatus: status, toolSummary: summary))
        }
    }

    /// `tool.input.updated` (live) → a compact debris-safe summary of the tool's input on the existing tool card. The
    /// normalizer emits tool.started (sets toolName) BEFORE tool.input.updated, so the part exists with its name; the
    /// extractor reads ONLY an allowlisted salient key (command/file/pattern/url) — raw input (write.content etc.) is
    /// never stored. nil summary (unknown tool / no salient key) leaves the card unchanged.
    private func applyToolInput(_ obj: [String: Any]) {
        guard let key = partKey(obj) else { return }
        let candidates = WorkToolInputSummary.safeCandidates(input: obj["input"])
        if let idx = partIndex[key] {
            if let summary = WorkToolInputSummary.summary(toolName: parts[idx].toolName, candidates: candidates) {
                parts[idx].toolSummary = summary
            } else if parts[idx].toolName == nil && !candidates.isEmpty {
                pendingToolInputCandidates[key] = candidates
            }
            parts[idx].kind = .tool
        } else {
            // input arrived before tool.started (out of order) → create the shell; the summary fills once a name is known.
            partIndex[key] = parts.count
            if !candidates.isEmpty { pendingToolInputCandidates[key] = candidates }
            parts.append(WorkTranscriptPart(id: key, kind: .tool, text: "", toolName: nil, toolStatus: "running"))
        }
    }

    private func applyToolOutput(_ obj: [String: Any], replace: Bool) {
        guard let text = obj["text"] as? String, let key = partKey(obj) else { return }
        if let idx = partIndex[key] {
            parts[idx].text = replace ? WorkTranscriptBounds.clampedPartText(text) :
                WorkTranscriptBounds.appendingPartText(parts[idx].text, text)
            parts[idx].kind = .tool
        } else {
            partIndex[key] = parts.count
            parts.append(WorkTranscriptPart(
                id: key, kind: .tool, text: WorkTranscriptBounds.clampedPartText(text),
                toolName: nil, toolStatus: "running"))
        }
    }
}
