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

    // MARK: - WORKING-FOLDER (P7.6)

    /// A file the agent actually mutated this run, derived from a real `file_ops`
    /// (or aliased file-write) tool-use block. Read-only ops are excluded — this
    /// is "what changed", not "what was looked at". Because file mutation is
    /// MAS-forbidden, this list is naturally empty outside the Pro build.
    struct TouchedFile: Equatable, Sendable, Identifiable {
        let path: String
        let action: FileAction
        var id: String { path }

        /// The last path component (filename), for compact display.
        var fileName: String {
            (path as NSString).lastPathComponent
        }
    }

    enum FileAction: String, Sendable, Equatable {
        case write
        case patch
        case delete
        case move

        var verb: String {
            switch self {
            case .write: "wrote"
            case .patch: "edited"
            case .delete: "deleted"
            case .move: "moved"
            }
        }
    }

    /// The set of files this run actually mutated, in first-touch order, deduped
    /// by path (the latest action on a path wins). Recognizes both the canonical
    /// action-based `file_ops` tool (action + path) and the legacy/dotted aliases
    /// (`file.write`/`write_file`, `file.patch`/`edit_file`/`patch`,
    /// `file.delete`/`delete_file`, `file.move`/`move_file`). Honest: only real
    /// `.toolUse` blocks, only mutating actions.
    static func filesTouched(in blocks: [MessageContentBlock]?) -> [TouchedFile] {
        guard let blocks else { return [] }
        var order: [String] = []
        var actionByPath: [String: FileAction] = [:]
        for case let .toolUse(_, name, input) in blocks {
            guard let action = mutatingAction(toolName: name, input: input) else { continue }
            guard let path = pathField(input), !path.isEmpty else { continue }
            if actionByPath[path] == nil { order.append(path) }
            actionByPath[path] = action  // latest action on a path wins
        }
        return order.compactMap { path in
            actionByPath[path].map { TouchedFile(path: path, action: $0) }
        }
    }

    /// The common parent directory of the touched files — the run's "working
    /// folder". Returns nil when there are no touched files or they share no
    /// common directory (e.g. a single file at the filesystem root).
    static func workingFolder(for files: [TouchedFile]) -> String? {
        let dirs = files.map { ($0.path as NSString).deletingLastPathComponent }
            .filter { !$0.isEmpty }
        guard let first = dirs.first else { return nil }
        var common = first.components(separatedBy: "/")
        for dir in dirs.dropFirst() {
            let parts = dir.components(separatedBy: "/")
            var shared: [String] = []
            for (a, b) in zip(common, parts) {
                if a == b { shared.append(a) } else { break }  // common PREFIX only
            }
            common = shared
            if common.isEmpty { break }
        }
        let joined = common.joined(separator: "/")
        return joined.isEmpty ? nil : joined
    }

    // MARK: - Private

    /// Maps a tool name (+ its `action` field for the unified `file_ops` tool) to
    /// a mutating FileAction, or nil for read-only / non-file tools.
    private static func mutatingAction(toolName: String, input: [String: JSONValue]) -> FileAction? {
        let name = toolName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch name {
        case "file_ops":
            // Unified tool: the verb lives in the `action` field.
            guard case let .string(raw)? = input["action"] else { return nil }
            switch raw.lowercased() {
            case "write", "create": return .write
            case "patch", "edit": return .patch
            case "delete": return .delete
            case "move", "rename": return .move
            default: return nil  // read / list / search are not mutations
            }
        case "file.write", "write_file":
            return .write
        case "file.patch", "edit_file", "patch":
            return .patch
        case "file.delete", "delete_file":
            return .delete
        case "file.move", "move_file":
            return .move
        default:
            return nil
        }
    }

    /// The target path for a file tool, tolerant of the common key spellings.
    private static func pathField(_ input: [String: JSONValue]) -> String? {
        for key in ["path", "file_path", "target", "filename"] {
            if case let .string(value)? = input[key] {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }
}
