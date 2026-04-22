import Foundation

/// The capability tier the chat is currently operating in. This is the
/// user-facing "what can this chat actually do right now" badge — distinct
/// from the Rust-side ProviderRuntime (Cloud vs Local) and the tool-registry
/// ToolTier (ChatLite/ChatPro/Agent/Full). ChatCapability picks which of
/// those signals to surface in the UI so the user never has to reason about
/// backend machinery.
///
/// The cardinal rule: honest capability gating. `.agent` is the user-facing
/// "tools are active" surface whether the hidden runtime is cloud-managed or
/// the local overseer/tool loop. The badge should describe what the turn can
/// do, not leak backend distinctions the user can't act on.
nonisolated enum ChatCapability: String, Codable, Hashable, Sendable, CaseIterable {
    /// Local model, everyday chat. Fast, no external calls.
    case local
    /// Local model, extended thinking mode on. Longer latency, deeper reasoning.
    case thinking
    /// Research mode: local or cloud, with web fetch available.
    case research
    /// Cloud model, plain chat. No tools active.
    case cloud
    /// Tools are active: long-running turns, file/note/web access, and
    /// permission-gated operations may all be in play.
    case agent
}

extension ChatCapability {
    var displayName: String {
        switch self {
        case .local: "Local"
        case .thinking: "Thinking"
        case .research: "Research"
        case .cloud: "Cloud"
        case .agent: "Tools"
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
            "Tools are active: web, files, long runs, and approval-gated actions may be in play."
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
        case .local, .thinking, .agent: false
        case .research, .cloud: true
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
    static func requiresResearchTools(text: String) -> Bool {
        requiresResearchTools(in: normalizedIntentText(text))
    }

    static func requiresManagedResearchTools(text: String) -> Bool {
        requiresManagedResearchTools(in: normalizedIntentText(text))
    }

    static func classify(
        isCloudProvider: Bool,
        isAgentExecuting: Bool,
        isResearchMode: Bool,
        isThinkingMode: Bool
    ) -> ChatCapability {
        if isAgentExecuting {
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
    /// Honest gating: local users can still preview `.agent` when the hidden
    /// local overseer/tool loop is what will handle the turn. The visible
    /// badge stays focused on capability, not the backend implementation.
    static func predictIntent(
        text: String,
        isCloudProvider: Bool
    ) -> IntentPrediction {
        let normalized = normalizedIntentText(text)

        if normalized.isEmpty {
            return IntentPrediction(
                predicted: isCloudProvider ? .cloud : .local,
                needsCloud: false
            )
        }

        if looksLikeExplicitFileOperation(in: normalized) {
            return IntentPrediction(
                predicted: .agent,
                needsCloud: false
            )
        }

        if requiresManagedResearchTools(in: normalized) {
            return IntentPrediction(
                predicted: .agent,
                needsCloud: false
            )
        }

        if requiresResearchTools(in: normalized) {
            return IntentPrediction(
                predicted: .research,
                needsCloud: false
            )
        }

        // Agent-tier signals: create/read/write/delete operations, git /
        // filesystem / install / web-fetch verbs, AND lookup verbs that
        // require a real vault_search/vault_read tool call instead of a
        // hallucinated answer. Research 3 (2026-04-19 tool-surface audit)
        // flagged that "find / look up / summarize my note X" was missing
        // here — the user would land in cloud chat with no tools and the
        // model would hallucinate instead of calling a tool.
        let agentSignals = [
            "create a note", "create note", "save a note", "save to",
            "delete a note", "delete note", "remove a note",
            "update my note", "update the note", "edit the note",
            "write this to a file", "write that to a file", "write to a file",
            "write a file", "save this as a file", "save it as a file",
            "save to a file", "save it to a file", "save this to a file",
            "create a file", "make a file", "new file called",
            "edit the file", "edit file", "update the file", "patch the file",
            "modify the file",
            "read the file", "read file", "open the file", "open file",
            "show me the file", "what's in the file", "what is in the file",
            "clone", "git pull", "git push",
            "install ", "brew install", "pip install", "cargo install",
            "npm install",
            "download ", "fetch the ",
            "run the command", "execute ", "automate ",
            "organize my files", "move the file",
            "send a message", "open the app",
            // Vault lookup verbs — require a real tool call, not a guess.
            "find the note", "find a note", "find my note",
            "look up ", "search for ", "locate ", "show me the note",
            "open the note", "which note", "which of my notes",
            "summarize my note", "summarize the note",
            "what am i working on", "what am i currently working on",
            "what's in my note", "what is in my note", "read my note",
        ]

        for signal in agentSignals {
            if normalized.contains(signal) {
                return IntentPrediction(
                    predicted: .agent,
                    needsCloud: false
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

    private static func normalizedIntentText(_ text: String) -> String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func looksLikeExplicitFileOperation(in normalized: String) -> Bool {
        guard !normalized.contains("http://"), !normalized.contains("https://") else {
            return false
        }

        let fileLocationSignals = [
            "/tmp/",
            "/users/",
            "/var/",
            "/etc/",
            "/applications/",
            ".md",
            ".txt",
            ".pdf",
            ".json",
            ".csv",
            ".swift",
            ".rs",
            ".py",
            ".js",
        ]
        let fileVerbSignals = [
            "read ",
            "open ",
            "show ",
            "write ",
            "save ",
            "create ",
            "edit ",
            "patch ",
            "modify ",
            "move ",
            "rename ",
            "delete ",
            "copy ",
        ]

        let mentionsFileLocation = normalized.contains(" local file ")
            || normalized.contains(" file ")
            || fileLocationSignals.contains { normalized.contains($0) }
        guard mentionsFileLocation else { return false }

        return fileVerbSignals.contains { normalized.contains($0) }
    }

    private static func requiresResearchTools(in normalized: String) -> Bool {
        if requiresManagedResearchTools(in: normalized) {
            return true
        }

        let liveInfoSignals = [
            "what's the weather",
            "what is the weather",
            "weather in ",
            "weather for ",
            "forecast for ",
            "forecast in ",
            "temperature in ",
            "temperature for ",
            "is it raining",
            "will it rain",
            "headlines",
            "breaking news",
            "latest on ",
            "today's weather",
            "today weather",
        ]
        return liveInfoSignals.contains { normalized.contains($0) }
    }

    private static func requiresManagedResearchTools(in normalized: String) -> Bool {
        let signals = [
            "search up ",
            "search the web",
            "search online",
            "browse the web",
            "browse for ",
            "look online",
            "find information on",
            "find info on",
            "find sources for",
            "find references for",
            "latest news",
            "recent news",
            "what's the latest",
            "what is the latest",
        ]
        return signals.contains { normalized.contains($0) }
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
