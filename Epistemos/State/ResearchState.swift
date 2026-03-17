import Foundation
import Observation

// MARK: - Research State
// Ephemeral paper cache for App Intents entity resolution.

@MainActor @Observable
final class ResearchState {
    var researchPapers: [ResearchPaper] = []

    func replaceResearchPapers(_ papers: [ResearchPaper]) {
        researchPapers = papers
    }

    func reset() {
        researchPapers = []
    }
}
