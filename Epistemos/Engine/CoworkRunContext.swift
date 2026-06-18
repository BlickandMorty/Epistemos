import Foundation

/// P7.6 — the cowork CONTEXT panel's data, derived from REAL runtime state (the
/// agent's actual tool-use content blocks + the notes loaded this turn), never a
/// mockup. Pure + `nonisolated` so the extraction is unit-testable without the
/// view.
nonisolated enum CoworkRunContext {
    /// Distinct tool names the agent actually invoked in a message's content
    /// blocks, in first-use order. Reads the `.toolUse` blocks the runtime
    /// records via `ChatState.recordToolUse`, so it reflects what really ran.
    static func toolNamesUsed(in blocks: [MessageContentBlock]?) -> [String] {
        guard let blocks else { return [] }
        var seen: Set<String> = []
        var result: [String] = []
        for case let .toolUse(_, name, _) in blocks {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }

    /// A one-line honest summary of what this run used: tools invoked + notes/
    /// files referenced. Returns nil when nothing was used (so the panel can hide
    /// rather than show an empty box).
    static func summary(toolNames: [String], noteTitles: [String]) -> String? {
        var parts: [String] = []
        if !toolNames.isEmpty {
            parts.append("Tools: " + toolNames.joined(separator: ", "))
        }
        if !noteTitles.isEmpty {
            let count = noteTitles.count
            parts.append("\(count) note\(count == 1 ? "" : "s")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
