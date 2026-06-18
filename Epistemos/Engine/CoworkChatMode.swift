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

    /// Act is available only when an agent route genuinely exists — i.e. the
    /// surface's `availableOperatingModes` includes `.agent`. On a local-only
    /// setup this is false and the toggle's Act side is disabled with an honest
    /// reason rather than faking agent capability.
    static func actAvailable(in availableModes: [EpistemosOperatingMode]) -> Bool {
        availableModes.contains(.agent)
    }

    /// One-line honest reason shown when Act can't be selected.
    static var actUnavailableReason: String {
        "Act runs the multi-step agent loop — connect a cloud model (or use the Pro build) to enable it."
    }
}
