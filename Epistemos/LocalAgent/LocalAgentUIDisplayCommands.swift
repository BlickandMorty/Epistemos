import Foundation

// MARK: - LocalAgent UI Display Commands
//
// Core-native parsers for the UI-display row of LocalAgentCapabilityRegistry:
// /theme, /theme list, /mode, /markdown, /image, /pager, /width, /font,
// /fontsize, /colors. Each is a parser + intent — the dispatch site
// applies to the active session UI config without prompting.
//
// Doctrine §A.7 action class: Trivial. All Core-safe.

// MARK: - On/off helper

nonisolated enum LocalAgentToggleState: String, Equatable, Sendable, CaseIterable {
    case on
    case off
}

extension LocalAgentToggleState {
    nonisolated static func parse(_ raw: String) -> LocalAgentToggleState? {
        switch raw.lowercased() {
        case "on": return .on
        case "off": return .off
        default: return nil
        }
    }
}

// MARK: - /theme

nonisolated struct LocalAgentThemeCommand: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        case showCurrent       // /theme
        case list              // /theme list
        case set(name: String) // /theme <name>
    }

    let action: Action
    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> LocalAgentThemeCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/theme" || trimmed.hasPrefix("/theme ") else { return nil }
        let arg = trimmed.dropFirst("/theme".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if arg.isEmpty { return LocalAgentThemeCommand(action: .showCurrent) }
        if arg.lowercased() == "list" { return LocalAgentThemeCommand(action: .list) }
        return LocalAgentThemeCommand(action: .set(name: arg))
    }
}

// MARK: - /mode <simple|rich>

nonisolated struct LocalAgentModeCommand: Equatable, Sendable {
    enum Mode: String, Equatable, Sendable, CaseIterable {
        case simple
        case rich
    }

    let mode: Mode
    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> LocalAgentModeCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/mode") else { return nil }
        let arg = trimmed.dropFirst("/mode".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let mode = Mode(rawValue: arg) else { return nil }
        return LocalAgentModeCommand(mode: mode)
    }
}

// MARK: - /markdown, /image, /pager — three on/off toggles share one shape

nonisolated struct LocalAgentUIToggleCommand: Equatable, Sendable {
    enum Surface: String, Equatable, Sendable, CaseIterable {
        case markdown
        case image
        case pager
    }

    let surface: Surface
    let state: LocalAgentToggleState

    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> LocalAgentUIToggleCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }
        let cmd = String(parts[0]).dropFirst()
        let arg = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let surface = Surface(rawValue: String(cmd)) else { return nil }
        guard let state = LocalAgentToggleState.parse(arg) else { return nil }
        return LocalAgentUIToggleCommand(surface: surface, state: state)
    }
}

// MARK: - /width <num>

nonisolated struct LocalAgentWidthCommand: Equatable, Sendable {
    let width: Int

    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> LocalAgentWidthCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/width") else { return nil }
        let arg = trimmed.dropFirst("/width".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let n = Int(arg), (40...500).contains(n) else { return nil }
        return LocalAgentWidthCommand(width: n)
    }
}

// MARK: - /font <name> and /fontsize <size>

nonisolated struct LocalAgentFontCommand: Equatable, Sendable {
    let name: String

    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> LocalAgentFontCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/font ") else { return nil }
        let name = trimmed.dropFirst("/font".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return LocalAgentFontCommand(name: name)
    }
}

nonisolated struct LocalAgentFontSizeCommand: Equatable, Sendable {
    let size: Int

    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> LocalAgentFontSizeCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/fontsize") else { return nil }
        let arg = trimmed.dropFirst("/fontsize".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let n = Int(arg), (8...72).contains(n) else { return nil }
        return LocalAgentFontSizeCommand(size: n)
    }
}

// MARK: - /colors — read-only theme diagnostics

nonisolated struct LocalAgentColorsCommand: Equatable, Sendable {
    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> LocalAgentColorsCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/colors" else { return nil }
        return LocalAgentColorsCommand()
    }
}
