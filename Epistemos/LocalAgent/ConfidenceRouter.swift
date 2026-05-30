import Foundation

nonisolated struct LocalAgentOutputVerificationError: Error, Equatable, LocalizedError, Sendable {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}

nonisolated protocol LocalAgentOutputVerifying: Sendable {
    func verify(
        output: String,
        schemaJson: String?
    ) -> Result<Void, LocalAgentOutputVerificationError>
}

nonisolated struct ConfidenceRouter {
    // T2 salvage 2026-05-23: TaskClass + RouteProfile + 3 static items.
    // PURE-ADDITIVE: no fields added to existing structs (Request /
    // Classification / Decision) and no existing initializers touched. The
    // production policy table now lives in RuntimeRouter; this legacy
    // surface adapts it for LocalAgentDiagnostics and older call sites.
    nonisolated enum TaskClass: String, Sendable, Equatable, CaseIterable {
        case fastChat = "fast_chat"
        case coding
        case debugging
        case structuredOutput = "structured_output"
        case localResearch = "local_research"
        case reasoning
        case synthesis
        case toolUse = "tool_use"
        case general
        case vision

        var displayName: String {
            rawValue
                .split(separator: "_")
                .map { $0.capitalized }
                .joined(separator: " ")
        }
    }

    nonisolated struct RouteProfile: Sendable, Equatable, Identifiable {
        let taskClass: TaskClass
        let preferredModelIDs: [String]
        let primaryModelID: String?
        let primaryModelName: String
        let nativeGrammar: LocalToolGrammar.NativeToolGrammar
        let minimumConfidence: Double
        let maximumComplexity: Double
        let maximumToolCount: Int
        let idleUnloadDelaySeconds: Int
        let idleUnloadMode: String

        var id: String { taskClass.rawValue }

        var displayName: String {
            taskClass.displayName
        }

        var fallbackCount: Int {
            max(0, preferredModelIDs.count - 1)
        }

        var policySummary: String {
            "conf \(formatted(minimumConfidence)) · complexity \(formatted(maximumComplexity)) · tools \(maximumToolCount)"
        }

        var idleUnloadSummary: String {
            "idle \(idleUnloadDelaySeconds)s \(idleUnloadMode)"
        }

        private func formatted(_ value: Double) -> String {
            String(format: "%.2f", value)
        }
    }

    nonisolated static let localAgentIdleUnloadDelaySeconds = 30
    nonisolated static let localAgentIdleUnloadMode = "deep"

    nonisolated static var localAgentIdleUnloadPolicySummary: String {
        "idle unload \(localAgentIdleUnloadDelaySeconds)s/\(localAgentIdleUnloadMode)"
    }

    /// Returns the production per-task routing profiles by adapting
    /// RuntimeRouter's role table into the older TaskClass shape.
    nonisolated static func routeProfiles() -> [RouteProfile] {
        RuntimeRouter.defaultRouteProfiles().map { profile in
            RouteProfile(
                taskClass: taskClass(for: profile.role),
                preferredModelIDs: profile.preferredModelIDs,
                primaryModelID: profile.primaryModelID,
                primaryModelName: profile.primaryModelName,
                nativeGrammar: profile.nativeGrammar,
                minimumConfidence: profile.minimumConfidence,
                maximumComplexity: profile.maximumComplexity,
                maximumToolCount: profile.maximumToolCount,
                idleUnloadDelaySeconds: profile.idleUnloadDelaySeconds,
                idleUnloadMode: profile.idleUnloadMode
            )
        }
    }

    nonisolated private static func taskClass(for role: RuntimeRole) -> TaskClass {
        switch role {
        case .code:
            .coding
        case .reasoning:
            .reasoning
        case .quick:
            .fastChat
        case .toolCaller:
            .toolUse
        case .trivial:
            .general
        case .vision:
            .vision
        }
    }

    nonisolated struct Request: Sendable, Equatable {
        let objective: String
        let selectedLocalModelID: String?
        let requiresStructuredOutput: Bool
        let schemaJson: String?
    }

    nonisolated struct Classification: Sendable, Equatable {
        let complexity: Double
        let toolCountEstimate: Int
        let requiresCurrentInfo: Bool
        let requiresCodeExecution: Bool
        let privacySensitive: Bool
        let confidence: Double
    }

    nonisolated enum Route: String, Sendable, Equatable {
        case local
        case cloudFallback
    }

    nonisolated enum Reason: String, Sendable, Equatable {
        case localAgentApproved
        case privacySensitive
        case classificationUncertain
        case requiresCurrentInfo
        case requiresCodeExecution
        case taskTooComplex
        case tooManyToolCalls
        case localModelCannotActAsAgent
        case structuredOutputInvalid
        case structuredOutputUnverifiable
    }

    nonisolated struct Decision: Sendable, Equatable {
        let route: Route
        let reason: Reason
        let usesLocalAgentLoop: Bool
        let selectedLocalModelID: String?
    }

    let uncertaintyThreshold: Double
    let maxLocalComplexity: Double
    let maxLocalToolCount: Int

    init(
        uncertaintyThreshold: Double = 0.60,
        maxLocalComplexity: Double = 0.40,
        maxLocalToolCount: Int = 2
    ) {
        self.uncertaintyThreshold = uncertaintyThreshold
        self.maxLocalComplexity = maxLocalComplexity
        self.maxLocalToolCount = maxLocalToolCount
    }

    func route(
        request: Request,
        classification: Classification
    ) -> Decision {
        let canUseLocalAgentLoop = isEligibleForLocalAgentLoop(
            request: request,
            classification: classification
        )

        if classification.privacySensitive {
            return Decision(
                route: .local,
                reason: .privacySensitive,
                usesLocalAgentLoop: canUseLocalAgentLoop,
                selectedLocalModelID: canUseLocalAgentLoop ? request.selectedLocalModelID : nil
            )
        }

        guard hasCapableLocalAgentModel(request.selectedLocalModelID) else {
            return Decision(
                route: .cloudFallback,
                reason: .localModelCannotActAsAgent,
                usesLocalAgentLoop: false,
                selectedLocalModelID: nil
            )
        }

        guard classification.confidence >= uncertaintyThreshold else {
            return Decision(
                route: .cloudFallback,
                reason: .classificationUncertain,
                usesLocalAgentLoop: false,
                selectedLocalModelID: nil
            )
        }

        guard !classification.requiresCurrentInfo else {
            return Decision(
                route: .cloudFallback,
                reason: .requiresCurrentInfo,
                usesLocalAgentLoop: false,
                selectedLocalModelID: nil
            )
        }

        guard !classification.requiresCodeExecution else {
            return Decision(
                route: .cloudFallback,
                reason: .requiresCodeExecution,
                usesLocalAgentLoop: false,
                selectedLocalModelID: nil
            )
        }

        guard classification.complexity <= maxLocalComplexity else {
            return Decision(
                route: .cloudFallback,
                reason: .taskTooComplex,
                usesLocalAgentLoop: false,
                selectedLocalModelID: nil
            )
        }

        guard classification.toolCountEstimate <= maxLocalToolCount else {
            return Decision(
                route: .cloudFallback,
                reason: .tooManyToolCalls,
                usesLocalAgentLoop: false,
                selectedLocalModelID: nil
            )
        }

        return Decision(
            route: .local,
            reason: .localAgentApproved,
            usesLocalAgentLoop: true,
            selectedLocalModelID: request.selectedLocalModelID
        )
    }

    func validateLocalOutput(
        _ output: String,
        request: Request,
        priorDecision: Decision,
        verifier: (any LocalAgentOutputVerifying)?
    ) -> Decision {
        guard priorDecision.route == .local,
              priorDecision.usesLocalAgentLoop else {
            return priorDecision
        }

        guard request.requiresStructuredOutput || request.schemaJson != nil else {
            return priorDecision
        }

        guard let verifier else {
            return Decision(
                route: .cloudFallback,
                reason: .structuredOutputUnverifiable,
                usesLocalAgentLoop: false,
                selectedLocalModelID: nil
            )
        }

        switch verifier.verify(output: output, schemaJson: request.schemaJson) {
        case .success:
            return priorDecision
        case .failure:
            return Decision(
                route: .cloudFallback,
                reason: .structuredOutputInvalid,
                usesLocalAgentLoop: false,
                selectedLocalModelID: nil
            )
        }
    }

    private func isEligibleForLocalAgentLoop(
        request: Request,
        classification: Classification
    ) -> Bool {
        guard hasCapableLocalAgentModel(request.selectedLocalModelID) else {
            return false
        }

        guard classification.confidence >= uncertaintyThreshold else {
            return false
        }

        guard !classification.requiresCurrentInfo,
              !classification.requiresCodeExecution else {
            return false
        }

        guard classification.complexity <= maxLocalComplexity else {
            return false
        }

        return classification.toolCountEstimate <= maxLocalToolCount
    }

    private func hasCapableLocalAgentModel(_ modelID: String?) -> Bool {
        guard let modelID,
              let model = LocalTextModelID(rawValue: modelID) else {
            return false
        }

        return model.canActAsAgent
    }
}
