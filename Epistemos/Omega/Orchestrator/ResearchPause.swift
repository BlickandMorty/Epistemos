import Foundation

// MARK: - Research Pause Handler

/// Pauses execution when an agent needs information it cannot resolve locally.
/// Surfaces questions to the UI and accepts user-provided research input.
@MainActor @Observable
final class ResearchPauseHandler {
    init(timeout: Duration = .seconds(120)) {
        self.timeout = timeout
    }

    /// Active research request (shown in UI when non-nil).
    var activeRequest: ResearchRequest?

    /// Whether the system is currently paused for research.
    var isPaused: Bool { activeRequest != nil }

    /// Request research from the user. Suspends until user responds or skips.
    func requestResearch(questions: [String], context: String) async -> String {
        resolvePendingResearch(with: "")

        let requestID = UUID()
        pendingRequestID = requestID

        activeRequest = ResearchRequest(
            questions: questions,
            context: context
        )

        let response: String = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                pendingContinuation = continuation

                Task { @MainActor [weak self, requestID] in
                    try? await Task.sleep(for: self?.timeout ?? .seconds(120))
                    self?.skip(requestID: requestID)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self, requestID] in
                self?.skip(requestID: requestID)
            }
        }

        return response
    }

    /// Called by UI when user provides research results.
    func provideResponse(_ response: String) {
        resolvePendingResearch(with: response)
    }

    /// Called by UI when user skips research.
    func skip() {
        resolvePendingResearch(with: "")
    }

    private var pendingContinuation: CheckedContinuation<String, Never>?
    private var pendingRequestID: UUID?
    private let timeout: Duration

    private func skip(requestID: UUID) {
        resolvePendingResearch(with: "", requestID: requestID)
    }

    private func resolvePendingResearch(with response: String, requestID: UUID? = nil) {
        if let requestID, let pendingRequestID, pendingRequestID != requestID { return }
        let continuation = pendingContinuation
        pendingContinuation = nil
        pendingRequestID = nil
        activeRequest = nil
        continuation?.resume(returning: response)
    }
}

// MARK: - Types

struct ResearchRequest: Identifiable, Sendable {
    let id = UUID()
    let questions: [String]
    let context: String
    let timestamp = Date()
}
