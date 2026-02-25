import Foundation

// MARK: - SOAR Service
// Main service interface for SOAR operations

@MainActor
final class SOARService {

    // MARK: - Dependencies

    private let soarState: SOARState
    private let llmService: LLMService?
    private let eventBus: EventBus
    private let engine: SOAREngine

    init(soarState: SOARState, llmService: LLMService?, eventBus: EventBus) {
        self.soarState = soarState
        self.llmService = llmService
        self.eventBus = eventBus
        self.engine = SOAREngine(llmService: llmService)
    }

    // MARK: - Configuration

    func updateConfig(_ config: SOARConfig) {
        soarState.updateConfig(config)
    }

    // MARK: - Run SOAR Session

    /// Run the full SOAR reasoning loop for a query
    func runSOAR(
        query: String,
        queryAnalysis: QueryAnalysis,
        baselineSignals: BaselineSignals,
        inferenceMode: InferenceMode
    ) async throws -> SOARSession {
        guard soarState.soarConfig.enabled else {
            throw SOARError.disabled
        }

        // Create event handler that bridges from actor → MainActor
        let eventHandler: @Sendable (SOAREvent) -> Void = { [weak self] event in
            Task { @MainActor in
                self?.handleEvent(event)
            }
        }

        // Run the SOAR engine
        let session = await engine.runSOAR(
            query: query,
            queryAnalysis: queryAnalysis,
            baselineSignals: baselineSignals,
            inferenceMode: inferenceMode,
            config: soarState.soarConfig,
            onEvent: eventHandler
        )

        // Update state
        soarState.setSession(session)

        return session
    }

    // MARK: - Quick Probe

    /// Quick probe to check if SOAR would engage
    func probeLearnability(
        queryAnalysis: QueryAnalysis,
        priorSignals: BaselineSignals? = nil
    ) -> LearnabilityProbe {
        SOARDetector.probeLearnability(
            queryAnalysis: queryAnalysis,
            priorSignals: priorSignals,
            thresholds: soarState.soarConfig.thresholds
        )
    }

    // MARK: - Contradiction Scan

    /// Scan for contradictions in analysis text
    func scanContradictions(
        analysis: String,
        maxClaims: Int = 20
    ) async -> ContradictionScan {
        await ContradictionDetector.scanForContradictions(
            analysis: analysis,
            maxClaims: maxClaims,
            llmService: llmService
        )
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: SOAREvent) {
        // Broadcast to event bus
        eventBus.emit(.soarEvent(event))

        // Update state based on event type
        switch event.type {
        case .probeComplete:
            if let atEdge = event.data["atEdge"]?.boolValue {
                soarState.setAtEdge(atEdge)
            }
        case .teachingStart:
            soarState.setStatus(.teaching)
        case .stoneStart:
            soarState.setStatus(.learning)
        case .finalAttemptStart:
            soarState.setStatus(.evaluating)
        case .iterationComplete:
            if let completed = event.data["iterationsCompleted"]?.intValue {
                soarState.setIterationsCompleted(completed)
            }
        case .sessionComplete:
            soarState.setStatus(.complete)
        case .sessionAborted:
            soarState.setStatus(.aborted)
        default:
            break
        }
    }

}

// MARK: - SOAR Errors

nonisolated enum SOARError: Error, LocalizedError {
    case disabled
    case engineNotInitialized
    case sessionFailed(String)

    var errorDescription: String? {
        switch self {
        case .disabled:
            "SOAR engine is disabled"
        case .engineNotInitialized:
            "SOAR engine not initialized"
        case .sessionFailed(let reason):
            "SOAR session failed: \(reason)"
        }
    }
}

// MARK: - AnySendable Helpers

extension AnySendable {
    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
}
