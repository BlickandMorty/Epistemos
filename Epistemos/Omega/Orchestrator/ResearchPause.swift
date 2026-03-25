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

    /// Request research from the user. Suspends until user responds or skips.
    func requestResearch(questions: [String], context: String) async -> String {
        activeRequest = ResearchRequest(
            questions: questions,
            context: context
        )

        let response: String = await withCheckedContinuation { continuation in
            pendingContinuation = continuation
        }

        return response
    }

    /// Called by UI when user provides research results.
    func provideResponse(_ response: String) {
        activeRequest = nil
        pendingContinuation?.resume(returning: response)
        pendingContinuation = nil
    }

    /// Called by UI when user skips research.
    func skip() {
        activeRequest = nil
        pendingContinuation?.resume(returning: "")
        pendingContinuation = nil
    }

    private var pendingContinuation: CheckedContinuation<String, Never>?
}

// MARK: - Types

struct ResearchRequest: Identifiable, Sendable {
    let id = UUID()
    let questions: [String]
    let context: String
    let timestamp = Date()
}
