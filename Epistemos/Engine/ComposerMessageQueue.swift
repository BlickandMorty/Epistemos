import Foundation

/// P7.6 — the cowork QUEUE: lets the user stage ONE follow-up message while the
/// agent is mid-run, auto-submitted the moment the run finishes. Pure value type
/// + `nonisolated` so the queue/auto-submit transition is unit-testable without
/// the view. (One pending message, not a backlog — keeps the UX honest and the
/// run order obvious.)
nonisolated struct ComposerMessageQueue: Equatable, Sendable {
    private(set) var pending: String?

    var hasPending: Bool { pending != nil }

    /// Queue a message (trimmed; empty is ignored, replacing any existing one).
    mutating func enqueue(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        pending = trimmed.isEmpty ? nil : trimmed
    }

    mutating func clear() {
        pending = nil
    }

    /// On a run completion (processing true → false) with a pending message,
    /// returns it to auto-submit and clears the queue; otherwise nil. Only fires
    /// on the genuine true→false edge so it never double-sends.
    mutating func dequeueOnCompletion(wasProcessing: Bool, isProcessing: Bool) -> String? {
        guard wasProcessing, !isProcessing, let message = pending else { return nil }
        pending = nil
        return message
    }
}
