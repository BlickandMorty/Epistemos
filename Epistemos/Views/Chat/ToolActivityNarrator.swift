import Foundation

/// Turns a bare tool name + its JSON input into a short user-facing
/// phrase so the chat composer pill reads as real activity ("Searching
/// the web for "quantum decoherence"…") instead of a raw identifier
/// ("web.search"). Scoped to tools the app actually emits today —
/// unknown tool names fall back to a humanized form of the identifier
/// so the pill is never blank.
///
/// Keep this file allocation-light: the pill updates every time a new
/// tool call starts and we don't want a stream of transient JSON
/// allocations. All helpers are `nonisolated` so the narrator can be
/// called from any actor — including background stream handlers.
enum ToolActivityNarrator {
    /// Max characters of a quoted argument we inline into the narration.
    /// Anything longer gets ellipsized so the pill doesn't blow out the
    /// composer layout with a 200-char query. `nonisolated` because the
    /// narrator is called from background stream handlers and Swift 6
    /// otherwise treats module-level static state as main-actor-isolated.
    nonisolated private static let inlineArgumentBudget: Int = 48

    /// Primary entry point. Returns a short phrase suitable for the
    /// composer pill's detail slot. Returns nil only when `toolName` is
    /// empty — in every other case we fall back to a humanized version
    /// so the pill always renders *something* during tool use.
    nonisolated static func phrase(name toolName: String, inputJson: String?) -> String? {
        let trimmed = toolName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let input = inputJson.flatMap { decode($0) } ?? [:]

        switch AgentToolNameAliases.canonical(trimmed) {
        case "web.search", "browser_search", "safari_search":
            if let query = firstString(in: input, keys: ["query", "q", "search"]) {
                return "Searching the web for \(quote(query))"
            }
            return "Searching the web"

        case "web.fetch", "web_fetch", "web-fetch", "browser_navigate", "browser_open":
            if let url = firstString(in: input, keys: ["url", "href", "target"]) {
                return "Fetching \(trimmedHost(url))"
            }
            return "Fetching a web page"

        case "file.read", "read-file", "file_read":
            if let path = firstString(in: input, keys: ["path", "file", "file_path"]) {
                return "Reading \(displayName(for: path))"
            }
            return "Reading a file"

        case "file.write", "write-file", "file_write":
            if let path = firstString(in: input, keys: ["path", "file", "file_path"]) {
                return "Writing \(displayName(for: path))"
            }
            return "Writing a file"

        case "file.patch", "edit", "apply_patch":
            if let path = firstString(in: input, keys: ["path", "file", "file_path"]) {
                return "Editing \(displayName(for: path))"
            }
            return "Editing a file"

        case "list_directory", "list-directory", "ls", "glob":
            if let path = firstString(in: input, keys: ["path", "directory", "pattern"]) {
                return "Listing \(displayName(for: path))"
            }
            return "Listing files"

        case "grep", "search", "code_search", "ripgrep":
            if let pattern = firstString(in: input, keys: ["pattern", "query", "regex"]) {
                return "Searching for \(quote(pattern))"
            }
            return "Searching the workspace"

        case "vault.read":
            if let title = firstString(in: input, keys: ["title", "path", "note"]) {
                return "Reading note \(quote(title))"
            }
            return "Reading a note"

        case "vault.write":
            if let title = firstString(in: input, keys: ["title", "path", "note"]) {
                return "Writing note \(quote(title))"
            }
            return "Writing a note"

        case "vault.search", "memory_search", "knowledge_search":
            if let query = firstString(in: input, keys: ["query", "q"]) {
                return "Searching memory for \(quote(query))"
            }
            return "Searching memory"

        case "action.terminal", "action.bash", "terminal_run", "bash", "shell", "exec":
            if let command = firstString(in: input, keys: ["command", "cmd", "script"]) {
                return "Running \(quote(command))"
            }
            return "Running a command"

        case "think":
            return "Thinking through the plan"

        case "system.todo", "todo_write", "todo_update":
            return "Updating the plan"

        default:
            return humanize(trimmed)
        }
    }

    // MARK: - Decoding helpers

    nonisolated private static func decode(_ json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    nonisolated private static func firstString(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    // MARK: - Formatting helpers

    /// Quote + truncate an argument so the pill stays readable.
    nonisolated private static func quote(_ value: String) -> String {
        let trimmed = value.replacingOccurrences(of: "\n", with: " ")
        if trimmed.count <= inlineArgumentBudget {
            return "\u{201C}\(trimmed)\u{201D}"
        }
        let head = trimmed.prefix(inlineArgumentBudget)
        return "\u{201C}\(head)…\u{201D}"
    }

    /// Display the filename for a path (or the path itself if it's already short).
    nonisolated private static func displayName(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        if name.isEmpty {
            return quote(path)
        }
        return quote(name)
    }

    /// Pull the host out of a URL for fetch narration. Falls back to the
    /// raw value if URL parsing fails.
    nonisolated private static func trimmedHost(_ urlString: String) -> String {
        if let url = URL(string: urlString), let host = url.host, !host.isEmpty {
            return host
        }
        return quote(urlString)
    }

    /// Turn `vault.search` → "Vault search" for unknown tools so the pill
    /// at least reads like English rather than showing a snake_case id.
    nonisolated private static func humanize(_ identifier: String) -> String {
        let cleaned = identifier
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        guard !cleaned.isEmpty else { return identifier }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }
}
