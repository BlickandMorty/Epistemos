import Foundation

// MARK: - Hermes Parameter-Setter Commands
//
// Core-native parsers for the per-session model-config commands declared
// in HermesCapabilityRegistry: /temperature, /max-tokens, /top-p, /top-k.
// Each is a single-value setter with explicit numeric bounds — invalid
// arguments return nil from parse so the chat surface can render a
// clear error rather than silently apply a bogus value.
//
// All Core-safe. Doctrine §A.7 action class: Trivial. Apply directly
// to per-session config without prompting.

nonisolated enum HermesParameter: String, Equatable, Sendable, CaseIterable {
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
nonisolated enum HermesParameterValue: Equatable, Sendable {
    case temperature(Double)   // [0.0, 2.0]
    case maxTokens(Int)        // > 0
    case topP(Double)          // (0.0, 1.0]
    case topK(Int)             // > 0
}

nonisolated struct HermesParameterCommand: Equatable, Sendable {
    let value: HermesParameterValue

    var requiresApproval: Bool { false }

    nonisolated var parameter: HermesParameter {
        switch value {
        case .temperature: .temperature
        case .maxTokens:   .maxTokens
        case .topP:        .topP
        case .topK:        .topK
        }
    }

    static func parse(_ rawCommand: String) -> HermesParameterCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }
        let cmd = String(parts[0]).dropFirst() // strip leading slash
        let arg = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

        switch cmd {
        case HermesParameter.temperature.commandToken:
            return parseTemperature(arg)
        case HermesParameter.maxTokens.commandToken:
            return parseMaxTokens(arg)
        case HermesParameter.topP.commandToken:
            return parseTopP(arg)
        case HermesParameter.topK.commandToken:
            return parseTopK(arg)
        default:
            return nil
        }
    }

    private static func parseTemperature(_ arg: String) -> HermesParameterCommand? {
        guard let d = Double(arg), d.isFinite, (0.0...2.0).contains(d) else {
            return nil
        }
        return HermesParameterCommand(value: .temperature(d))
    }

    private static func parseMaxTokens(_ arg: String) -> HermesParameterCommand? {
        guard let n = Int(arg), n > 0 else { return nil }
        return HermesParameterCommand(value: .maxTokens(n))
    }

    private static func parseTopP(_ arg: String) -> HermesParameterCommand? {
        guard let d = Double(arg), d.isFinite, d > 0.0, d <= 1.0 else {
            return nil
        }
        return HermesParameterCommand(value: .topP(d))
    }

    private static func parseTopK(_ arg: String) -> HermesParameterCommand? {
        guard let n = Int(arg), n > 0 else { return nil }
        return HermesParameterCommand(value: .topK(n))
    }
}
