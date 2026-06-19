import Foundation

/// P7.6 — the **depth** axis of the chat UX (CHAT_UX_MAP: Mode is orthogonal to
/// Tier). "Chat" is conversational on the selected tier (Fast/Think/Code);
/// "Act" runs the real multi-step agent loop (`operatingMode == .agent` /
/// managedAgentSession). This is a *presentation* over the existing
/// `operatingMode` — not a new engine. Pure + `nonisolated` so the gating logic
/// is unit-testable without the view.
///
/// Honest gating (CLAUDE.md): Act is only offered when an agent route actually
/// exists (cloud / Pro configured → `.agent` is in `availableOperatingModes`).
/// We never fake agent capability for a local-only setup.
nonisolated enum CoworkChatMode: String, Sendable, CaseIterable {
    case chat
    case act

    var displayName: String {
        switch self {
        case .chat: "Chat"
        case .act: "Act"
        }
    }

    var systemImage: String {
        switch self {
        case .chat: "bubble.left.and.bubble.right"
        case .act: "bolt.badge.automatic"
        }
    }

    /// Which depth the current operating mode represents.
    static func current(for operatingMode: EpistemosOperatingMode) -> CoworkChatMode {
        operatingMode == .agent ? .act : .chat
    }

    /// The operating mode to apply for this depth, preserving the user's tier
    /// pick when returning to Chat. Act always maps to `.agent`; Chat maps to the
    /// remembered tier (falling back to `.fast` if the remembered mode wasn't a
    /// tier, e.g. it was `.agent`).
    func operatingMode(rememberedTier: EpistemosOperatingMode) -> EpistemosOperatingMode {
        switch self {
        case .act:
            return .agent
        case .chat:
            return rememberedTier == .agent ? .fast : rememberedTier
        }
    }

    /// Act is available when an agent route genuinely exists — i.e. the surface's
    /// `availableOperatingModes` includes `.agent`. This is LOCAL-FIRST (owner #1,
    /// 2026-06-19): a local agent-capable model (e.g. Qwen) puts `.agent` in the
    /// available modes with ZERO cloud configured, so Act runs ON-DEVICE — cloud is
    /// NOT required. A local model that genuinely can't run the agent loop has no
    /// `.agent`, so Act is honestly disabled rather than faked (and never silently
    /// escalated to a cloud/GPT route).
    static func actAvailable(in availableModes: [EpistemosOperatingMode]) -> Bool {
        availableModes.contains(.agent)
    }

    /// One-line honest reason shown when Act can't be selected. Local-first: Act
    /// runs the agent loop on-device on a local agent-capable model — cloud is one
    /// option, NOT the requirement (the previous copy wrongly implied "connect a
    /// cloud model" was the only path).
    static var actUnavailableReason: String {
        "Act runs the multi-step agent loop. Pick a local agent-capable model (e.g. Qwen) to run it on-device with zero cloud, or connect a cloud model."
    }
}
