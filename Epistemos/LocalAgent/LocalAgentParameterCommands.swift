import Foundation

// MARK: - LocalAgent Parameter-Setter Commands
//
// Core-native parsers for the per-session model-config commands declared
// in LocalAgentCapabilityRegistry: /temperature, /max-tokens, /top-p, /top-k.
// Each is a single-value setter with explicit numeric bounds — invalid
// arguments return nil from parse so the chat surface can render a
// clear error rather than silently apply a bogus value.
//
// All Core-safe. Doctrine §A.7 action class: Trivial. Apply directly
// to per-session config without prompting.

nonisolated enum LocalAgentParameter: String, Equatable, Sendable, CaseIterable {
    case temperature
    case maxTokens
    case topP
    case topK

    /// Command token as the user types it (without the leading slash).
    nonisolated var commandToken: String {
        switch self {
        case .temperature: "temperature"
        case .maxTokens:   "max-tokens"
        case .topP:        "top-p"
        case .topK:        "top-k"
        }
    }
}

/// A typed, validated parameter set request. The dispatch site applies
/// the value to the active session config.
nonisolated enum LocalAgentParameterValue: Equatable, Sendable {
    case temperature(Double)   // [0.0, 2.0]
    case maxTokens(Int)        // > 0
    case topP(Double)          // (0.0, 1.0]
    case topK(Int)             // > 0
}

nonisolated struct LocalAgentParameterCommand: Equatable, Sendable {
    let value: LocalAgentParameterValue

    var requiresApproval: Bool { false }

    nonisolated var parameter: LocalAgentParameter {
        switch value {
        case .temperature: .temperature
        case .maxTokens:   .maxTokens
        case .topP:        .topP
        case .topK:        .topK
        }
    }

    static func parse(_ rawCommand: String) -> LocalAgentParameterCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }
        let cmd = String(parts[0]).dropFirst() // strip leading slash
        let arg = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

        switch cmd {
        case LocalAgentParameter.temperature.commandToken:
            return parseTemperature(arg)
        case LocalAgentParameter.maxTokens.commandToken:
            return parseMaxTokens(arg)
        case LocalAgentParameter.topP.commandToken:
            return parseTopP(arg)
        case LocalAgentParameter.topK.commandToken:
            return parseTopK(arg)
        default:
            return nil
        }
    }

    private static func parseTemperature(_ arg: String) -> LocalAgentParameterCommand? {
        guard let d = Double(arg), d.isFinite, (0.0...2.0).contains(d) else {
            return nil
        }
        return LocalAgentParameterCommand(value: .temperature(d))
    }

    private static func parseMaxTokens(_ arg: String) -> LocalAgentParameterCommand? {
        guard let n = Int(arg), n > 0 else { return nil }
        return LocalAgentParameterCommand(value: .maxTokens(n))
    }

    private static func parseTopP(_ arg: String) -> LocalAgentParameterCommand? {
        guard let d = Double(arg), d.isFinite, d > 0.0, d <= 1.0 else {
            return nil
        }
        return LocalAgentParameterCommand(value: .topP(d))
    }

    private static func parseTopK(_ arg: String) -> LocalAgentParameterCommand? {
        guard let n = Int(arg), n > 0 else { return nil }
        return LocalAgentParameterCommand(value: .topK(n))
    }
}
