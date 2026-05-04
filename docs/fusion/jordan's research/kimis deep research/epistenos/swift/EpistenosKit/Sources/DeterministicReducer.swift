import Foundation

// ---------------------------------------------------------------------------
// MARK: - DeterministicReducer
// ---------------------------------------------------------------------------

/// Deterministic state reducer — all state changes go through here.
///
/// Invariant I-13: This is a pure function. No side effects. No randomness
/// from the system. No `Date.now()`. All cosmetic variation is drawn from the
/// injected `DeterministicPRNG`.
///
/// Because `CompanionState` is an `@Observable` class (required for SwiftUI
/// observation), callers should pass a cloned snapshot when true purity is
/// required (e.g. unit tests, replay). When used inline the reference semantics
/// are acceptable because the caller controls the lifecycle.
@MainActor
public struct DeterministicReducer {

    /// Reduces a `CompanionState` snapshot through a single `ReplayEvent`.
    ///
    /// - Parameters:
    ///   - state: The current simulation state. Since `CompanionState` is a class,
    ///     mutations will reflect on the referenced instance. For replay or tests,
    ///     deep-clone first.
    ///   - event: The incoming event describing what happened.
    ///   - prng: The seeded PRNG for any cosmetic variation required by this event.
    /// - Returns: The updated state (same reference when `CompanionState` is a class).
    public static func reduce(
        state: CompanionState,
        event: ReplayEvent,
        prng: inout DeterministicPRNG
    ) -> CompanionState {
        var newState = state

        switch event.action {
        case "companion_created":
            // Deterministic creation — no randomness, no clock
            break

        case "companion_deleted":
            newState.companions.removeAll { $0.id.uuidString == event.agentId }

        case "event_reaction":
            // Reaction uses PRNG for cosmetic variation (idle breathing rate jitter)
            if let idx = newState.companions.firstIndex(where: { $0.id.uuidString == event.agentId }) {
                let jitter = prng.nextFloat() * 0.2 - 0.1 // [-0.1, +0.1]
                newState.companions[idx].cosmeticConfig.idleBreathingRate += Double(jitter)
            }

        default:
            break
        }

        return newState
    }
}
