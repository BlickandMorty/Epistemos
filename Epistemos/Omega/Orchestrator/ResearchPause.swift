import Foundation

// MARK: - Research Pause Handler

/// Pauses execution when an agent needs information it cannot resolve locally.
/// Surfaces questions to the UI and accepts user-provided research input.
@MainActor @Observable
final class ResearchPauseHandler {

    /// Active research request (shown in UI when non-nil).
    var activeRequest: ResearchRequest?

    /// Whether the system is currently paused for research.
    var isPaused: Bool { activeRequest != nil }

    /// Request research from the user. Returns the user's response.
    func requestResearch(questions: [String], context: String) async -> String {
        activeRequest = ResearchRequest(
            questions: questions,
            context: context
        )

        // Wait for user to provide response
        while activeRequest != nil {
            try? await Task.sleep(for: .milliseconds(100))
        }

        return lastResearchResponse
    }

    /// Called by UI when user provides research results.
    func provideResponse(_ response: String) {
        lastResearchResponse = response
        activeRequest = nil
    }

    /// Called by UI when user skips research.
    func skip() {
        lastResearchResponse = ""
        activeRequest = nil
    }

    private var lastResearchResponse = ""
}

// MARK: - Types

struct ResearchRequest: Identifiable, Sendable {
    let id = UUID()
    let questions: [String]
    let context: String
    let timestamp = Date()
}
