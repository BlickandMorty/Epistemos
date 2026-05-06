import Foundation

/// Native local-reasoning-display surface for `/think` per
/// `HERMES_CAPABILITY_PARITY_TARGET_2026_05_03.md` — Agent And Tasks row.
///
/// Wraps the user's prompt in the explicit "think step by step" cue so
/// downstream reasoning surfaces (the chat panel + Resonance Gate)
/// receive a marked-think payload. **Core-safe**: no provider call,
/// no network, no tool dispatch — just structures the prompt.
///
/// Doctrine §A.7 action class: Trivial.
nonisolated struct LocalAgentThinkCommand: Equatable, Sendable {
    /// The user's prompt to think through. Never empty (parser rejects
    /// `/think` with no argument).
    let prompt: String

    var requiresApproval: Bool { false }

    static func parse(_ rawCommand: String) -> LocalAgentThinkCommand? {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "/think" || trimmed.hasPrefix("/think ") else {
            return nil
        }
        let remainder = trimmed
            .dropFirst("/think".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remainder.isEmpty else {
            return nil
        }
        return LocalAgentThinkCommand(prompt: remainder)
    }

    /// Wrap the prompt with the canonical reasoning cue. The result is
    /// what the downstream chat layer feeds into the model. The output
    /// is deterministic given the input.
    func wrappedPrompt() -> String {
        // Newlines + explicit cue keep prompt boundaries clear for any
        // downstream parser that tags think regions in the model output.
        """
        \(prompt)

        Think step by step. Show your reasoning before the conclusion.
        """
    }

    /// Suggested model preset for this turn — the chat layer reads this
    /// as a hint, not an enforcement. Local reasoning models (Qwen3,
    /// LocalAgent-3) are the doctrine §3.1 default for `/think` in Core.
    var suggestedModelPreset: LocalAgentThinkModelPreset { .localReasoningCapable }
}

nonisolated enum LocalAgentThinkModelPreset: String, Equatable, Sendable, CaseIterable {
    /// Default — current local reasoning-capable model (e.g. Qwen3 8B,
    /// LocalAgent-3 8B).
    case localReasoningCapable
    /// User-selected cloud model — only honored in Pro tier.
    case cloudUserSelected
}
