import Foundation

// Projects an OpenGUI/OpenCode session's `messages()` history (clone-map #2: reopen a recent session WITH its past
// turns) into a native, render-ready form. Runtime-verified shape (og-messages-probe.mjs): the sidecar `messages`
// reply is `{ messages: { messages: [ { info{id,role,time,agent,model}, parts:[{id,type,text,state?}] }, … ],
// nextCursor, revision } }` (note the double "messages" nesting via the sidecar envelope). `parts` mirror the live
// LiveSessionEvent shape (type "text"|"tool"|…), so reopened history renders with the SAME native rules as streaming.
// Pure + lenient (digs to the entries array wherever it sits; never throws) + testable. The view converts these to
// transcript parts on reopen (user prompts render distinctly via the transcript's user kind).

struct WorkHistoryPart: Sendable, Equatable {
    enum Kind: String, Sendable, Equatable { case text, thinking, tool, other }
    let id: String?
    let kind: Kind
    let text: String
    let toolName: String?
    let toolStatus: String?
    /// Compact, debris-safe one-line of the tool's input (from `state.input`; command/file/pattern/url, never content).
    var toolSummary: String? = nil
    /// Unified file diffs an edit/write tool produced (from `state.metadata.files[].diff`); empty for non-edit tools.
    /// Each entry is a self-describing unified diff (filename in its --- / +++ header) → native diff rendering.
    var fileDiffs: [String] = []
}

struct WorkHistoryMessage: Identifiable, Sendable, Equatable {
    let id: String
    let role: String           // "user" | "assistant" | …
    let parts: [WorkHistoryPart]
}

enum WorkSessionHistoryProjector {
    static func project(_ data: Data?) -> [WorkHistoryMessage] {
        guard let data, let root = try? JSONSerialization.jsonObject(with: data) else { return [] }
        return entriesArray(from: root).compactMap(message(from:))
    }

    /// Dig through the nested `messages` envelopes to the `[{info,parts}]` array.
    private static func entriesArray(from any: Any) -> [[String: Any]] {
        if let array = any as? [[String: Any]],
           array.first?["parts"] != nil || array.first?["info"] != nil {
            return array
        }
        if let dict = any as? [String: Any] {
            if let nested = dict["messages"] { return entriesArray(from: nested) }
        }
        return []
    }

    private static func message(from entry: [String: Any]) -> WorkHistoryMessage? {
        let info = entry["info"] as? [String: Any]
        let id = (info?["id"] as? String) ?? (entry["id"] as? String) ?? UUID().uuidString
        let role = (info?["role"] as? String) ?? "assistant"
        let parts = ((entry["parts"] as? [[String: Any]]) ?? []).compactMap(part(from:))
        guard !parts.isEmpty else { return nil }   // skip empty/system bookkeeping messages
        return WorkHistoryMessage(id: id, role: role, parts: parts)
    }

    private static func part(from raw: [String: Any]) -> WorkHistoryPart? {
        let type = (raw["type"] as? String) ?? ""
        let id = raw["id"] as? String
        let state = raw["state"] as? [String: Any]
        switch type {
        case "text":
            guard let text = raw["text"] as? String, !text.isEmpty else { return nil }
            return WorkHistoryPart(
                id: id, kind: .text, text: WorkTranscriptBounds.clampedPartText(text),
                toolName: nil, toolStatus: nil)
        case "reasoning", "thinking":
            guard let text = raw["text"] as? String, !text.isEmpty else { return nil }
            return WorkHistoryPart(
                id: id, kind: .thinking, text: WorkTranscriptBounds.clampedPartText(text),
                toolName: nil, toolStatus: nil)
        case "tool":
            let name = (raw["tool"] as? String) ?? (state?["title"] as? String)
            return WorkHistoryPart(
                id: id, kind: .tool,
                text: WorkTranscriptBounds.clampedPartText((state?["output"] as? String) ?? ""),
                toolName: name, toolStatus: state?["status"] as? String,
                toolSummary: WorkToolInputSummary.summary(toolName: name, input: state?["input"]),
                fileDiffs: fileDiffs(from: state))
        default:
            // Unknown part with text → show as text; otherwise drop (no raw debris).
            if let text = raw["text"] as? String, !text.isEmpty {
                return WorkHistoryPart(
                    id: id, kind: .other, text: WorkTranscriptBounds.clampedPartText(text),
                    toolName: nil, toolStatus: nil)
            }
            return nil
        }
    }

    /// Extract the unified file diffs an edit/write tool produced: `state.metadata.files[].diff` (the bridge keeps the
    /// `diff` string, drops before/after). Non-empty, trimmed diffs only; [] when the tool made no edits.
    private static func fileDiffs(from state: [String: Any]?) -> [String] {
        guard let files = (state?["metadata"] as? [String: Any])?["files"] as? [[String: Any]] else { return [] }
        var diffs: [String] = []
        for file in files {
            guard let diff = file["diff"] as? String,
                  !diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            diffs.append(WorkTranscriptBounds.clampedDiff(diff))
            if diffs.count >= WorkTranscriptBounds.maxDiffsPerTool { break }
        }
        return diffs
    }
}
