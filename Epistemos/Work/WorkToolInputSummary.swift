import Foundation

// Compact, debris-safe summary of an opencode tool call's INPUT for the native tool card. OpenCode-TUI minimalism:
// show WHAT a tool is doing — the command / file / pattern / url — not the raw input object. The tool input can carry
// huge fields (write.content, edit.oldString/newString); this extracts ONLY a small per-tool ALLOWLIST of salient
// string keys, collapses newlines, and truncates, so no file content / log / JSON debris ever reaches the transcript.
// Pure + testable; nil when there is nothing safe/salient to show (never a raw dump).
//
// Input keys verified against the opencode clone tool schemas (.research-clones/work/opencode):
//   shell.command (bash alias) · edit/write/read.filePath · glob/grep.pattern · webfetch.url · list.path · task.description
//
// Feeds both paths: the live `tool.input.updated` LiveSessionEvent (`input: unknown`) and the messages() replay shape
// (`part.state.input`). UI render + wiring land in follow-on slices; this is the pure foundation that de-risks debris.
enum WorkToolInputSummary {
    // nonisolated: the module defaults to @MainActor isolation; these immutable Sendable constants must be reachable
    // from the nonisolated `summary` (called off the main actor by the history projector).
    nonisolated static let maxLength = 120

    // The single salient input key per tool (lowercased tool name). A tool not listed → no summary (never a raw dump).
    nonisolated private static let salientKey: [String: String] = [
        "bash": "command", "shell": "command",
        "edit": "filePath", "write": "filePath", "read": "filePath",
        "glob": "pattern", "grep": "pattern",
        "webfetch": "url", "list": "path", "task": "description",
    ]

    /// A one-line summary of the tool's input, or nil when there's nothing safe/salient to show.
    nonisolated static func summary(toolName: String?, input: Any?) -> String? {
        guard let toolName,
              let key = salientKey[toolName.lowercased()],
              let value = safeCandidates(input: input)[key] else { return nil }
        return value
    }

    /// Sanitized allowlisted input values keyed by original input key. This lets the transcript handle
    /// `tool.input.updated` before `tool.started` without retaining the raw input object.
    nonisolated static func safeCandidates(input: Any?) -> [String: String] {
        guard let dict = input as? [String: Any] else { return [:] }
        var output: [String: String] = [:]
        for key in Set(salientKey.values) {
            guard let raw = dict[key] as? String,
                  let value = sanitized(raw) else { continue }
            output[key] = value
        }
        return output
    }

    /// A one-line summary from already-sanitized candidates.
    nonisolated static func summary(toolName: String?, candidates: [String: String]) -> String? {
        guard let toolName,
              let key = salientKey[toolName.lowercased()] else { return nil }
        return candidates[key]
    }

    private nonisolated static func sanitized(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Collapse internal newlines (a multi-line command stays a single card line) then truncate.
        let oneLine = trimmed.split(whereSeparator: \.isNewline).map(String.init).joined(separator: " ")
        return oneLine.count > maxLength ? String(oneLine.prefix(maxLength)) + "…" : oneLine
    }
}
