import Foundation

// MARK: - Hermes Vault File Commands
//
// Core-native parsers for the file-data row of HermesCapabilityRegistry:
// /read, /write, /append, /ls, /search, /grep. Each is a parser; the
// dispatch site validates the path is inside the active vault or an
// approved security-scoped bookmark before acting.
//
// Doctrine §A.7 action class:
//   /read, /ls, /search, /grep — Trivial (read-only).
//   /write, /append           — Sensitive (file mutation, requires approval).
//
// **Path safety.** The parser captures the raw path; vault-scope
// enforcement and bookmark check live at the dispatch site, not here.

// MARK: - /read <file>

nonisolated struct HermesReadCommand: Equatable, Sendable {
    let path: String

    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> HermesReadCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/read ") else { return nil }
        let path = trimmed.dropFirst("/read".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }
        return HermesReadCommand(path: path)
    }
}

// MARK: - /write <file> <content>

nonisolated struct HermesWriteCommand: Equatable, Sendable {
    let path: String
    let content: String

    var requiresApproval: Bool { true }

    static func parse(_ rawCommand: String) -> HermesWriteCommand? {
        return parseWriteOrAppend(rawCommand, prefix: "/write")
            .map { HermesWriteCommand(path: $0.path, content: $0.content) }
    }
}

// MARK: - /append <file> <content>

nonisolated struct HermesAppendCommand: Equatable, Sendable {
    let path: String
    let content: String

    var requiresApproval: Bool { true }

    static func parse(_ rawCommand: String) -> HermesAppendCommand? {
        return parseWriteOrAppend(rawCommand, prefix: "/append")
            .map { HermesAppendCommand(path: $0.path, content: $0.content) }
    }
}

// MARK: - /ls [path]

nonisolated struct HermesLsCommand: Equatable, Sendable {
    /// Path to list. `nil` means the active vault root.
    let path: String?

    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> HermesLsCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/ls" || trimmed.hasPrefix("/ls ") else { return nil }
        let arg = trimmed.dropFirst("/ls".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return HermesLsCommand(path: arg.isEmpty ? nil : arg)
    }
}

// MARK: - /search <query>

nonisolated struct HermesSearchCommand: Equatable, Sendable {
    let query: String

    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> HermesSearchCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/search ") else { return nil }
        let q = trimmed.dropFirst("/search".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }
        return HermesSearchCommand(query: q)
    }
}

// MARK: - /grep <pattern>

nonisolated struct HermesGrepCommand: Equatable, Sendable {
    let pattern: String

    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> HermesGrepCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/grep ") else { return nil }
        let p = trimmed.dropFirst("/grep".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty else { return nil }
        return HermesGrepCommand(pattern: p)
    }
}

// MARK: - Internal helpers

/// Parse the shared shape `<prefix> <path> <content>` where path is the
/// first whitespace-delimited token and content is everything else.
/// Returns nil if either component is empty.
private nonisolated func parseWriteOrAppend(
    _ rawCommand: String,
    prefix: String
) -> (path: String, content: String)? {
    let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("\(prefix) ") else { return nil }
    let body = trimmed.dropFirst(prefix.count)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = body.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
    guard parts.count == 2 else { return nil }
    let path = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
    let content = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !path.isEmpty, !content.isEmpty else { return nil }
    return (path, content)
}
