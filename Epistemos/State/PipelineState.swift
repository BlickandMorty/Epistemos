import Foundation
import Observation

// MARK: - Pipeline State
// Ephemeral pipeline progress and brain signal metrics.

@MainActor @Observable
final class PipelineState {

    // MARK: - Pipeline Progress

    var pipelineStages: [StageResult] = []
    var activeStage: PipelineStage?
    var isProcessing = false
    var currentError: String?

    // MARK: - Signals (the "brain" metrics)

    var confidence: Double = 0.5
    var entropy: Double = 0
    var dissonance: Double = 0
    var healthScore: Double = 1.0
    var safetyState: SafetyState = .green
    var riskScore: Double = 0
    var focusDepth: Double = 3
    var temperatureScale: Double = 1.0

    // MARK: - Concepts

    var activeConcepts: [String] = []

    // MARK: - Tracking

    var queriesProcessed: Int = 0
    var totalTraces: Int = 0
    var skillGapsDetected: Int = 0
    var signalHistory: [SignalHistoryEntry] = []

    // MARK: - Methods

    func advanceStage(_ stage: PipelineStage, result: StageResult) {
        activeStage = stage
        if let idx = pipelineStages.firstIndex(where: { $0.stage == stage }) {
            pipelineStages[idx] = result
        } else {
            pipelineStages.append(result)
        }
    }

    func updateSignals(_ update: SignalUpdate) {
        if let v = update.confidence { confidence = v }
        if let v = update.entropy { entropy = v }
        if let v = update.dissonance { dissonance = v }
        if let v = update.healthScore { healthScore = v }
        if let v = update.safetyState { safetyState = v }
        if let v = update.riskScore { riskScore = v }
        if let v = update.focusDepth { focusDepth = v }
        if let v = update.temperatureScale { temperatureScale = v }
        if let newConcepts = update.concepts {
            // Merge new concepts into the running list (accumulates across the chat)
            let existing = Set(activeConcepts.map { $0.lowercased() })
            let unique = newConcepts.filter { !existing.contains($0.lowercased()) }
            activeConcepts.append(contentsOf: unique)
            // Cap at 16 concepts to keep the map readable
            if activeConcepts.count > 16 {
                activeConcepts = Array(activeConcepts.suffix(16))
            }
        }
        signalHistory.append(SignalHistoryEntry(
            timestamp: .now,
            confidence: confidence,
            entropy: entropy,
            dissonance: dissonance,
            healthScore: healthScore
        ))

        if signalHistory.count > 100 {
            signalHistory.removeFirst(signalHistory.count - 100)
        }
    }

    func setError(_ error: String) {
        currentError = error
    }

    func startProcessing() {
        isProcessing = true
        currentError = nil
        pipelineStages = PipelineStage.allCases.map {
            StageResult(stage: $0, status: .pending)
        }
    }

    func completeProcessing() {
        isProcessing = false
        activeStage = nil
        queriesProcessed += 1
    }

    /// Clears accumulated concepts (used by Fresh Start / chat wipe).
    func clearConcepts() {
        activeConcepts = []
    }

    // MARK: - Computed Properties

    var currentProgress: Double {
        guard !pipelineStages.isEmpty else { return 0 }
        let completed = pipelineStages.filter { $0.status == .completed }.count
        return Double(completed) / Double(PipelineStage.allCases.count)
    }
}
