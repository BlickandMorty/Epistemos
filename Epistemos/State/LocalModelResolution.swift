import Foundation

// Owner #1 (no hidden GPT route, 2026-06-19): the "deeper local-resolve trace".
// When a picked local model can't be used as-selected, the app must say WHY —
// honestly, visibly — and NEVER silently substitute a different model or a cloud/
// GPT route. These pure types are the trace; InferenceState computes the state from
// its existing resolution predicates, and a visible health row surfaces it.

/// Why a picked local model can't be used as-selected.
enum LocalModelUnavailableReason: Equatable, Sendable {
    /// The pick isn't installed / selectable on this Mac.
    case notInstalled
    /// The pick is too large for this Mac's memory budget.
    case exceedsMemory
    /// Weights are installable but the on-device Swift decoder isn't ported yet
    /// (e.g. the MLX `gemma4` family → "Unsupported model type: gemma4").
    case awaitingSwiftLoader
    /// The pick's runtime kind (e.g. GGUF) isn't available on this build/Mac.
    case runtimeUnavailable

    var honestReason: String {
        switch self {
        case .notInstalled: "not installed on this Mac"
        case .exceedsMemory: "too large for this Mac's memory"
        case .awaitingSwiftLoader: "its on-device loader isn't available yet"
        case .runtimeUnavailable: "its runtime isn't available on this build"
        }
    }
}

/// The honest state of the local chat-model selection — is the user's PICK what
/// actually resolves, was it substituted for a different installed model, or is
/// nothing runnable? The producer (InferenceState) passes DISPLAY NAMES so the
/// summary reads naturally.
enum LocalModelResolutionState: Equatable, Sendable {
    /// The user's pick resolves and will be used. Nothing to warn about.
    case usingPick(displayName: String)
    /// The pick can't be used; a DIFFERENT installed local model serves instead.
    /// Honest: the owner sees they picked X but Y runs, and why — not a silent swap.
    case substituted(pick: String, using: String, reason: LocalModelUnavailableReason)
    /// No local model resolves at all — the surface is honestly "not ready"
    /// (install a model / Send disabled), NEVER a silent cloud/GPT fallback.
    case noLocalModel(reason: LocalModelUnavailableReason)

    /// One-line honest summary for the UI — nil when the pick is used as-is.
    var summary: String? {
        switch self {
        case .usingPick:
            return nil
        case let .substituted(pick, using, reason):
            return "You picked \(pick), but it's \(reason.honestReason) — running \(using) instead."
        case let .noLocalModel(reason):
            return "No local model is ready (\(reason.honestReason)). Install one — local won't silently use a cloud model."
        }
    }

    /// True when the local pick is honored exactly (the good state).
    var isHonoringPick: Bool {
        if case .usingPick = self { return true }
        return false
    }
}
