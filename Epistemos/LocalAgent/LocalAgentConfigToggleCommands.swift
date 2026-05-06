import Foundation

// MARK: - LocalAgent Config + Toggle Commands
//
// Core-native parsers for the configuration toggles declared in
// LocalAgentCapabilityRegistry: /memory on/off, /memory clear, /tools
// on/off, /config show. Each is a parser; the dispatch site reads
// the intent and calls the matching native config service.

// MARK: - /memory

nonisolated struct LocalAgentMemoryCommand: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        case enable      // /memory on
        case disable     // /memory off
        case clear       // /memory clear (destructive)
    }

    let action: Action

    /// Both `enable`/`disable` and `clear` require approval per the
    /// registry — toggling memory has user-visible behavioral impact;
    /// clearing is destructive.
    var requiresApproval: Bool { true }

    static func parse(_ rawCommand: String) -> LocalAgentMemoryCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/memory") else { return nil }
        let arg = trimmed.dropFirst("/memory".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch arg {
        case "on":     return LocalAgentMemoryCommand(action: .enable)
        case "off":    return LocalAgentMemoryCommand(action: .disable)
        case "clear":  return LocalAgentMemoryCommand(action: .clear)
        default:       return nil
        }
    }
}

// MARK: - /tools (toggle on/off)

nonisolated struct LocalAgentToolsToggleCommand: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        case enable    // /tools on
        case disable   // /tools off
    }

    let action: Action

    /// Toggling tools changes whether destructive actions are reachable —
    /// approval-required.
    var requiresApproval: Bool { true }

    static func parse(_ rawCommand: String) -> LocalAgentToolsToggleCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/tools") else { return nil }
        let arg = trimmed.dropFirst("/tools".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch arg {
        case "on":  return LocalAgentToolsToggleCommand(action: .enable)
        case "off": return LocalAgentToolsToggleCommand(action: .disable)
        default:    return nil
        }
    }
}

// MARK: - /config show

nonisolated struct LocalAgentConfigShowCommand: Equatable, Sendable {
    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> LocalAgentConfigShowCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/config show" else { return nil }
        return LocalAgentConfigShowCommand()
    }
}
