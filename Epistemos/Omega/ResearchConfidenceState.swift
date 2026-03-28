import Foundation

// MARK: - Research Confidence State

/// Accumulates evidence quality and contradiction data during a research session.
/// Determines when to pause for user input based on confidence thresholds.
///
/// Preserves the old SOARRewardCalculator's confidence/dissonance tracking
/// in a simplified form suitable for deterministic tool-based research.
struct ResearchConfidenceState {

    struct Snippet {
        let text: String
        let url: String
        let confidence: Double
    }

    struct Contradiction {
        let snippetA: String
        let snippetB: String
        let verdict: String
    }

    private(set) var snippets: [Snippet] = []
    private(set) var contradictions: [Contradiction] = []
    private(set) var sessionNoteId: String?

    /// Average confidence across all collected snippets.
    var overallConfidence: Double {
        guard !snippets.isEmpty else { return 0 }
        return snippets.map(\.confidence).reduce(0, +) / Double(snippets.count)
    }

    /// True when any contradictions have been detected.
    var hasDissonance: Bool { !contradictions.isEmpty }

    /// True when evidence is insufficient and a ResearchPause should fire.
    /// Triggers when: confidence too low (with at least 1 snippet), or too few sources with contradictions.
    var requiresPause: Bool {
        guard !snippets.isEmpty else { return false }
        return overallConfidence < 0.45 || (snippets.count < 2 && hasDissonance)
    }

    // MARK: - Mutations

    mutating func addSnippet(text: String, url: String, confidence: Double) {
        snippets.append(Snippet(text: text, url: url, confidence: confidence))
    }

    mutating func addContradiction(snippetA: String, snippetB: String, verdict: String) {
        contradictions.append(Contradiction(snippetA: snippetA, snippetB: snippetB, verdict: verdict))
    }

    mutating func setSessionNoteId(_ id: String) {
        sessionNoteId = id
    }

    mutating func reset() {
        snippets.removeAll()
        contradictions.removeAll()
        sessionNoteId = nil
    }
}
