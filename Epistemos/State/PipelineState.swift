import Observation

// MARK: - Pipeline State
// Minimal runtime state for the plain local AI shell.

@MainActor @Observable
final class PipelineState {
    var isProcessing = false
    var currentError: String?

    func setError(_ error: String) {
        currentError = error
    }

    func startProcessing() {
        isProcessing = true
        currentError = nil
    }

    func completeProcessing() {
        isProcessing = false
    }

    func reset() {
        isProcessing = false
        currentError = nil
    }
}
