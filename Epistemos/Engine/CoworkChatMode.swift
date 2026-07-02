import Foundation

/// P7.6 — the **depth** axis of the chat UX (CHAT_UX_MAP: Mode is orthogonal to
/// Tier). "Chat" is conversational on the selected tier (Fast/Think/Code);
/// "Act" runs the real multi-step agent loop (`operatingMode == .agent` /
/// managedAgentSession). This is a *presentation* over the existing
/// `operatingMode` — not a new engine. Pure + `nonisolated` so the gating logic
/// is unit-testable without the view.
///
/// Honest gating (CLAUDE.md): Act is only offered when an agent route is
/// surfaced by the current runtime capabilities. Native local chat/agent
/// surfaces were pruned on 2026-06-26, so local model IDs must not be described
/// as a runnable Act route.
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

    /// Act is available when an agent route is exposed by the resolved surface
    /// capabilities. Runtime readiness is checked by `InferenceState`; this pure
    /// helper only maps the capability list into the Chat/Act depth toggle.
    static func actAvailable(in availableModes: [EpistemosOperatingMode]) -> Bool {
        availableModes.contains(.agent)
    }

    /// One-line honest reason shown when Act can't be selected.
    static var actUnavailableReason: String {
        "Act runs the multi-step agent loop through a configured agent-capable cloud route. Connect a supported cloud model before choosing Act."
    }
}
