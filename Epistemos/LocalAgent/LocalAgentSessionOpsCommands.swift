import Foundation

// MARK: - LocalAgent Session-Ops Commands
//
// Core-native parsers + intent structures for the session-row commands
// declared in LocalAgentCapabilityRegistry but not yet implemented:
// /new, /clear, /save, /load, /export, /compact, /summary, /model,
// /model list, /system <prompt>.
//
// Each command is a parser + intent — the dispatch site (chat UI)
// reads the intent and calls the matching native service. Doctrine
// §A.7 action class noted per command (Trivial unless flagged).
// All Core-safe: no network, no subprocess, no provider call.

// MARK: - /new — start a new session

nonisolated struct LocalAgentNewSessionCommand: Equatable, Sendable {
    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> LocalAgentNewSessionCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/new" else { return nil }
        return LocalAgentNewSessionCommand()
    }
}

// MARK: - /clear — clear current screen / session

nonisolated struct LocalAgentClearCommand: Equatable, Sendable {
    enum Scope: Equatable, Sendable {
        case screen      // wipe visible transcript only
        case session     // also drop server-side session state
    }

    let scope: Scope

    /// `/clear session` is destructive (drops persistent state) →
    /// requires approval per the registry. `/clear` defaults to screen
    /// scope and is Trivial.
    var requiresApproval: Bool { scope == .session }

    static func parse(_ rawCommand: String) -> LocalAgentClearCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/clear" || trimmed.hasPrefix("/clear ") else {
            return nil
        }
        let arg = trimmed.dropFirst("/clear".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch arg {
        case "":         return LocalAgentClearCommand(scope: .screen)
        case "session":  return LocalAgentClearCommand(scope: .session)
        case "screen":   return LocalAgentClearCommand(scope: .screen)
        default:         return nil
        }
    }
}

// MARK: - /save — persist the current session

nonisolated struct LocalAgentSaveCommand: Equatable, Sendable {
    /// Optional human-readable label. `nil` → auto-generated from timestamp.
    let label: String?

    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> LocalAgentSaveCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/save" || trimmed.hasPrefix("/save ") else {
            return nil
        }
        let label = trimmed.dropFirst("/save".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return LocalAgentSaveCommand(label: label.isEmpty ? nil : label)
    }
}

// MARK: - /load — load a prior session

nonisolated struct LocalAgentLoadCommand: Equatable, Sendable {
    /// Optional session id / search query. `nil` → open the picker.
    let query: String?

    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> LocalAgentLoadCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/load" || trimmed.hasPrefix("/load ") else {
            return nil
        }
        let q = trimmed.dropFirst("/load".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return LocalAgentLoadCommand(query: q.isEmpty ? nil : q)
    }
}

// MARK: - /export — user-approved file export

nonisolated struct LocalAgentExportCommand: Equatable, Sendable {
    enum Format: String, Equatable, Sendable, CaseIterable {
        case markdown = "md"
        case json
        case text = "txt"
    }

    let format: Format

    /// File export is approval-required per the registry — user must
    /// see the file picker and confirm.
    var requiresApproval: Bool { true }

    static func parse(_ rawCommand: String) -> LocalAgentExportCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/export" || trimmed.hasPrefix("/export ") else {
            return nil
        }
        let arg = trimmed.dropFirst("/export".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if arg.isEmpty {
            return LocalAgentExportCommand(format: .markdown)
        }
        guard let fmt = Format(rawValue: arg) else { return nil }
        return LocalAgentExportCommand(format: fmt)
    }
}

// MARK: - /compact — context compaction

nonisolated struct LocalAgentCompactCommand: Equatable, Sendable {
    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> LocalAgentCompactCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/compact" else { return nil }
        return LocalAgentCompactCommand()
    }
}

// MARK: - /summary — summarize current conversation

nonisolated struct LocalAgentSummaryCommand: Equatable, Sendable {
    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> LocalAgentSummaryCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/summary" else { return nil }
        return LocalAgentSummaryCommand()
    }
}

// MARK: - /model and /model list — model picker

nonisolated struct LocalAgentModelCommand: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        case showCurrent              // /model
        case list                     // /model list
        case switchTo(name: String)   // /model gpt-5.5
    }

    let action: Action

    /// Switching models may have cost/billing implications → mark approval-required
    /// for Pro provider switches at the dispatch site. Bare /model + /model list
    /// are read-only.
    var requiresApproval: Bool {
        if case .switchTo = action { return true }
        return false
    }

    static func parse(_ rawCommand: String) -> LocalAgentModelCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/model" || trimmed.hasPrefix("/model ") else {
            return nil
        }
        let arg = trimmed.dropFirst("/model".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if arg.isEmpty {
            return LocalAgentModelCommand(action: .showCurrent)
        }
        if arg.lowercased() == "list" {
            return LocalAgentModelCommand(action: .list)
        }
        return LocalAgentModelCommand(action: .switchTo(name: arg))
    }
}

// MARK: - /system <prompt> — set the system prompt

nonisolated struct LocalAgentSystemPromptCommand: Equatable, Sendable {
    let prompt: String

    /// Changing the system prompt mid-session is a meaningful behavioral
    /// override → mark requiresApproval = true so the user is shown the
    /// new prompt before it takes effect.
    var requiresApproval: Bool { true }

    static func parse(_ rawCommand: String) -> LocalAgentSystemPromptCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/system" || trimmed.hasPrefix("/system ") else {
            return nil
        }
        let body = trimmed.dropFirst("/system".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return nil }
        return LocalAgentSystemPromptCommand(prompt: body)
    }
}
