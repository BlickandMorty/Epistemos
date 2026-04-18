import Foundation

/// The capability tier the chat is currently operating in. This is the
/// user-facing "what can this chat actually do right now" badge — distinct
/// from the Rust-side ProviderRuntime (Cloud vs Local) and the tool-registry
/// ToolTier (ChatLite/ChatPro/Agent/Full). ChatCapability picks which of
/// those signals to surface in the UI so the user never has to reason about
/// backend machinery.
///
/// The cardinal rule (from CLAUDE.md): honest capability gating. Local
/// models get `.local`, `.thinking`, `.research`. Cloud models get
/// `.cloud`, `.research`, `.agent`. There is no `.agent` for local — that's
/// enforced in Rust (`AgentError::LocalProviderNotAllowed`) and mirrored
/// here so the pill never lies.
nonisolated enum ChatCapability: String, Codable, Hashable, Sendable, CaseIterable {
    /// Local model, everyday chat. Fast, no external calls.
    case local
    /// Local model, extended thinking mode on. Longer latency, deeper reasoning.
    case thinking
    /// Research mode: local or cloud, with web fetch available.
    case research
    /// Cloud model, plain chat. No tools active.
    case cloud
    /// Cloud model running the agent loop: tools, long-running turns, and
    /// permission-gated operations are all live. Cloud-only by contract.
    case agent
}

extension ChatCapability {
    var displayName: String {
        switch self {
        case .local: "Local"
        case .thinking: "Thinking"
        case .research: "Research"
        case .cloud: "Cloud"
        case .agent: "Agent"
        }
    }

    var iconSystemName: String {
        switch self {
        case .local: "bolt.fill"
        case .thinking: "brain"
        case .research: "magnifyingglass"
        case .cloud: "cloud.fill"
        case .agent: "sparkles"
        }
    }

    /// One-line "what does this mean right now" — shown on hover / long-press
    /// so the user doesn't have to guess what each tier grants.
    var shortExplanation: String {
        switch self {
        case .local:
            "Running on-device. Fast replies, no tools, no network."
        case .thinking:
            "On-device with extended thinking. Longer latency, deeper answers."
        case .research:
            "Web fetch and citations enabled. May be slower."
        case .cloud:
            "Cloud model. No tools active — plain chat."
        case .agent:
            "Cloud agent: tools, long runs, and permission-gated operations."
        }
    }

    /// Whether this capability implies the agent loop is running (and so
    /// authority-category prompts may appear mid-turn). Used by the pill
    /// to add a subtle pulsing animation while agent work is in flight.
    var isAgentActive: Bool {
        self == .agent
    }

    /// Whether the active model is cloud-hosted in this capability. Drives
    /// privacy-sensitive affordances like the "your text is leaving the
    /// device" tooltip and metered-cost summaries.
    var usesCloud: Bool {
        switch self {
        case .local, .thinking: false
        case .research, .cloud, .agent: true
        }
    }
}
