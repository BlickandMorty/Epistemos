import Foundation

/// Canonical 13-state animation machine per Simulation v1.6 character-DNA.
/// Plus `gate` (the 2-frame "awaiting permission" pose used when a Sovereign
/// gate intercepts a tool call). Frame counts are authoritative — pixel-art
/// atlases must hold exactly this many key frames per body family.
nonisolated enum CompanionAnimationState: String, Codable, Sendable, CaseIterable, Hashable {
    case idle
    case walk
    case think
    case speak
    case tool
    case spawn
    case handoffGive = "handoff_give"
    case handoffReceive = "handoff_receive"
    case retrieve
    case error
    case recover
    case success
    case sleep
    case gate

    /// Frame count from the canonical character-DNA tables. The Landing Farm
    /// only drives `idle` + `walk` today; the remaining states are scaffold for
    /// the future Hermes-driven companion state machine.
    var frameCount: Int {
        switch self {
        case .idle: return 4
        case .walk: return 8
        case .think: return 6
        case .speak: return 4
        case .tool: return 6
        case .spawn: return 5
        case .handoffGive: return 8
        case .handoffReceive: return 6
        case .retrieve: return 6
        case .error: return 4
        case .recover: return 6
        case .success: return 4
        case .sleep: return 4
        case .gate: return 2
        }
    }

    /// Resolve the current frame index from a continuous 0…1 phase. The Farm
    /// uses the phase that `CompanionView.breathePhase` produces (deterministic
    /// per identityHash), so callers stay replayable per Invariant I-13.
    func frameIndex(forPhase phase: Double) -> Int {
        let count = frameCount
        guard count > 0 else { return 0 }
        let normalized = max(0.0, min(0.9999, phase))
        return Int(normalized * Double(count))
    }
}
