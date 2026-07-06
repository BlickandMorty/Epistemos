// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// DELTA over the LIVE Epistemos/Models/Companion/CompanionAnimationState.swift — extend the
// existing enum/type in place (do not create a duplicate). The Rive input mapping added here is
// the new contract; every case maps 1:1 to a real backend event (no synthetic emotes).
// ════════════════════════════════════════════════════════════════════════════════════════════════
//  CompanionAnimationState.swift
//  EPI-RP-05-KINDRED · D4 emote binding (BINDING: skin over real state)
//
//  Each case MUST correspond to a real RunState streamed from agent_core. Setting an
//  animation state with no backing RunState is FORBIDDEN — that is the fake-animation
//  failure mode the whole design rejects.

#if KINDRED_ENABLED
import Foundation

enum CompanionAnimationState: String, CaseIterable {
    case idle, thinking, reading, searching, editing
    case toolRunning, awaitingApproval, done, blocked, error

    /// The Rive state-machine input name this emote drives. Native (rive-ios) and WebView
    /// (@rive-app/canvas) use the SAME .riv, so these names must match the rig exactly.
    var riveInput: String {
        switch self {
        case .idle:             return "isIdle"
        case .thinking:         return "isThinking"
        case .reading:          return "isReading"
        case .searching:        return "isReading"     // same read-ish pose
        case .editing:          return "isWriting"     // + embodied word-follow
        case .toolRunning:      return "isWorking"
        case .awaitingApproval: return "needsApproval"
        case .done:             return "trigDone"      // a trigger, not a bool
        case .blocked:          return "hasError"
        case .error:            return "hasError"
        }
    }

    /// Maps the wire emote string (from CompanionPresence.emote) to a state, or nil if the
    /// string has no backing case — which we DROP rather than animate.
    static func from(wire: String) -> CompanionAnimationState? {
        CompanionAnimationState(rawValue: wire)
    }
}
#endif
