import Foundation

// MARK: - Research Complexity Gate

/// Determines whether a query warrants a multi-step research plan
/// or can be answered by normal chat. Advisory gate used by chat/minichat
/// routing to suggest Omega research mode.
///
/// Preserves the old SOARDetector's "edge of learnability" concept
/// as a clean 3-check gate with no LLM dependency.
enum ResearchComplexityGate {

    private static let composerPrefix = "/research "

    private static let researchPrefixes = [
        "research ",
        "research: ",
        "/research ",
        "please research ",
        "can you research ",
        "could you research ",
        "help me research ",
        "find evidence ",
        "investigate ",
        "what does the literature say",
        "what do studies say",
    ]

    private static let researchKeywords = [
        "sources", "contradicts", "evidence", "peer-reviewed",
        "studies show", "according to", "citation", "citations",
        "paper", "papers", "literature", "scholarly",
        "preprint", "arxiv", "meta-analysis", "systematic review",
    ]

    /// Returns true if this query warrants a multi-step research plan.
    /// Simple factual queries go directly to chat.
    /// Research queries route through OrchestratorState.
    static func requiresResearch(_ query: String) -> Bool {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check 1: Explicit prefix
        for prefix in researchPrefixes {
            if lowered.hasPrefix(prefix) { return true }
        }

        // Check 2: Research-intent keywords (need 2+ matches)
        let keywordHits = researchKeywords.filter { lowered.contains($0) }.count
        if keywordHits >= 2 { return true }

        return false
    }

    /// Strips the "/research " or "research: " prefix if present,
    /// returning the clean query for task submission.
    static func stripPrefix(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()

        for prefix in researchPrefixes {
            if lowered.hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return trimmed
    }

    static func hasExplicitResearchPrefix(_ query: String) -> Bool {
        let lowered = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lowered == "/research"
            || lowered.hasPrefix(composerPrefix)
            || lowered == "research"
            || lowered == "research:"
            || lowered.hasPrefix("research ")
            || lowered.hasPrefix("research: ")
    }

    static func toggledComposerDraft(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hasExplicitResearchPrefix(trimmed) else {
            return stripPrefix(trimmed)
        }
        guard !trimmed.isEmpty else {
            return composerPrefix
        }
        return composerPrefix + trimmed
    }

    static func handoffMessage(for query: String) -> String {
        let cleaned = stripPrefix(query)
        guard !cleaned.isEmpty else {
            return "Add a research question after `/research` to send it to the agent runtime."
        }
        return "The agent runtime is handling this research task in the Agent Runtime panel."
    }
}
