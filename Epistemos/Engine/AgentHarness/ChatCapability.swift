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

/// Classify a ChatCapability from the runtime signals a chat session has at
/// its disposal. Call this on every turn start so the pill updates live as
/// the user switches provider, toggles thinking mode, or the agent loop
/// takes over.
///
/// Precedence (highest wins): agent → research → thinking → cloud → local.
/// This matches user intuition: an active tool-using turn should dominate
/// a "thinking on" flag, which should dominate the plain cloud/local axis.
extension ChatCapability {
    static func classify(
        isCloudProvider: Bool,
        isAgentExecuting: Bool,
        isResearchMode: Bool,
        isThinkingMode: Bool
    ) -> ChatCapability {
        if isAgentExecuting && isCloudProvider {
            return .agent
        }
        if isResearchMode {
            return .research
        }
        if isThinkingMode && !isCloudProvider {
            return .thinking
        }
        return isCloudProvider ? .cloud : .local
    }

    /// Pre-submission intent classification: heuristically scan the user's
    /// draft text to predict which capability the turn WILL need, so the
    /// pill can light up the moment the user's intent is obvious — before
    /// they hit send. This is the "smart indicator" half of the fused chat:
    /// the chat feels like one surface because the pill tells the user
    /// what's about to happen, not just what's happening.
    ///
    /// Honest gating: if the heuristic predicts `.agent` but the user is on
    /// a local model, we return `.cloud` as the BEST AVAILABLE prediction
    /// and let the UI layer surface a "needs cloud" affordance separately.
    /// We never pretend `.agent` is running on a local model.
    static func predictIntent(
        text: String,
        isCloudProvider: Bool
    ) -> IntentPrediction {
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.isEmpty {
            return IntentPrediction(
                predicted: isCloudProvider ? .cloud : .local,
                needsCloud: false
            )
        }

        // Agent-tier signals: create/read/write/delete operations, git /
        // filesystem / install / web-fetch verbs. These demand the tool
        // loop, which is cloud-only.
        let agentSignals = [
            "create a note", "create note", "save a note", "save to",
            "delete a note", "delete note", "remove a note",
            "update my note", "update the note", "edit the note",
            "clone", "git pull", "git push",
            "install ", "brew install", "pip install", "cargo install",
            "npm install",
            "download ", "fetch the ",
            "run the command", "execute ", "automate ",
            "organize my files", "move the file",
            "send a message", "open the app",
        ]

        for signal in agentSignals {
            if normalized.contains(signal) {
                return IntentPrediction(
                    predicted: isCloudProvider ? .agent : .cloud,
                    needsCloud: !isCloudProvider
                )
            }
        }

        // Research signals: anything pointing at external / current info.
        let researchSignals = [
            "research", "latest", "current ", "cite ", "citations",
            "find information", "what is the latest", "recent news",
            "compare ", "sources for", "references for", "look up ",
        ]
        for signal in researchSignals {
            if normalized.contains(signal) {
                return IntentPrediction(predicted: .research, needsCloud: false)
            }
        }

        // Thinking signals: deep reasoning cues.
        let thinkingSignals = [
            "think step by step", "reason through", "analyze deeply",
            "walk through the logic", "prove that ", "derive ",
        ]
        for signal in thinkingSignals {
            if normalized.contains(signal) {
                return IntentPrediction(
                    predicted: .thinking,
                    needsCloud: false
                )
            }
        }

        return IntentPrediction(
            predicted: isCloudProvider ? .cloud : .local,
            needsCloud: false
        )
    }
}

/// Output of the pre-submission intent classifier. `predicted` is the
/// capability the turn should run at; `needsCloud` is true only when the
/// heuristic wanted `.agent` but the user is on a local model — a cue the
/// UI uses to surface a "switch to cloud to run this as an agent" banner
/// instead of silently downgrading the user's intent.
nonisolated struct IntentPrediction: Equatable, Sendable {
    public let predicted: ChatCapability
    public let needsCloud: Bool
}
