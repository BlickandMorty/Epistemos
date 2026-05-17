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

        var displayName: String {
            rawValue
                .split(separator: "_")
                .map { $0.capitalized }
                .joined(separator: " ")
        }
    }

    nonisolated struct Request: Sendable, Equatable {
        let objective: String
        let selectedLocalModelID: String?
        let availableLocalModelIDs: [String]
        let requiresStructuredOutput: Bool
        let schemaJson: String?

        init(
            objective: String,
            selectedLocalModelID: String?,
            availableLocalModelIDs: [String] = [],
            requiresStructuredOutput: Bool,
            schemaJson: String?
        ) {
            self.objective = objective
            self.selectedLocalModelID = selectedLocalModelID
            self.availableLocalModelIDs = availableLocalModelIDs
            self.requiresStructuredOutput = requiresStructuredOutput
            self.schemaJson = schemaJson
        }
    }

    nonisolated struct Classification: Sendable, Equatable {
        let complexity: Double
        let toolCountEstimate: Int
        let requiresCurrentInfo: Bool
        let requiresCodeExecution: Bool
        let privacySensitive: Bool
        let confidence: Double
        let taskClass: TaskClass?

        init(
            complexity: Double,
            toolCountEstimate: Int,
            requiresCurrentInfo: Bool,
            requiresCodeExecution: Bool,
            privacySensitive: Bool,
            confidence: Double,
            taskClass: TaskClass? = nil
        ) {
            self.complexity = complexity
            self.toolCountEstimate = toolCountEstimate
            self.requiresCurrentInfo = requiresCurrentInfo
            self.requiresCodeExecution = requiresCodeExecution
            self.privacySensitive = privacySensitive
            self.confidence = confidence
            self.taskClass = taskClass
        }
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
        let taskClass: TaskClass
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
        let taskClass = classification.taskClass ?? Self.inferTaskClass(
            objective: request.objective,
            request: request,
            classification: classification
        )
        let policy = localPolicy(for: taskClass)
        let selectedLocalAgentModelID = selectLocalAgentModel(
            for: taskClass,
            request: request
        )
        let canUseLocalAgentLoop = isEligibleForLocalAgentLoop(
            modelID: selectedLocalAgentModelID,
            classification: classification,
            policy: policy
        )

        if classification.privacySensitive {
            return Decision(
                route: .local,
                reason: .privacySensitive,
                usesLocalAgentLoop: canUseLocalAgentLoop,
                selectedLocalModelID: canUseLocalAgentLoop ? selectedLocalAgentModelID : nil,
                taskClass: taskClass
            )
        }

        guard selectedLocalAgentModelID != nil else {
            return Decision(
                route: .cloudFallback,
                reason: .localModelCannotActAsAgent,
                usesLocalAgentLoop: false,
                selectedLocalModelID: nil,
                taskClass: taskClass
            )
        }

        guard classification.confidence >= policy.minimumConfidence else {
            return Decision(
                route: .cloudFallback,
                reason: .classificationUncertain,
                usesLocalAgentLoop: false,
                selectedLocalModelID: nil,
                taskClass: taskClass
            )
        }

        guard !classification.requiresCurrentInfo else {
            return Decision(
                route: .cloudFallback,
                reason: .requiresCurrentInfo,
                usesLocalAgentLoop: false,
                selectedLocalModelID: nil,
                taskClass: taskClass
            )
        }

        guard !classification.requiresCodeExecution else {
            return Decision(
                route: .cloudFallback,
                reason: .requiresCodeExecution,
                usesLocalAgentLoop: false,
                selectedLocalModelID: nil,
                taskClass: taskClass
            )
        }

        guard classification.complexity <= policy.maximumComplexity else {
            return Decision(
                route: .cloudFallback,
                reason: .taskTooComplex,
                usesLocalAgentLoop: false,
                selectedLocalModelID: nil,
                taskClass: taskClass
            )
        }

        guard classification.toolCountEstimate <= policy.maximumToolCount else {
            return Decision(
                route: .cloudFallback,
                reason: .tooManyToolCalls,
                usesLocalAgentLoop: false,
                selectedLocalModelID: nil,
                taskClass: taskClass
            )
        }

        return Decision(
            route: .local,
            reason: .localAgentApproved,
            usesLocalAgentLoop: true,
            selectedLocalModelID: selectedLocalAgentModelID,
            taskClass: taskClass
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
                selectedLocalModelID: nil,
                taskClass: priorDecision.taskClass
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
                selectedLocalModelID: nil,
                taskClass: priorDecision.taskClass
            )
        }
    }

    nonisolated static func preferredModelIDs(for taskClass: TaskClass) -> [String] {
        modelPreferenceTable[taskClass, default: modelPreferenceTable[.general] ?? []].map(\.rawValue)
    }

    nonisolated static func routeProfiles() -> [RouteProfile] {
        TaskClass.allCases.map(routeProfile(for:))
    }

    nonisolated static func routeProfile(for taskClass: TaskClass) -> RouteProfile {
        let preferredModels = modelPreferenceTable[
            taskClass,
            default: modelPreferenceTable[.general] ?? []
        ]
        let policy = localPolicyTable[taskClass] ?? localPolicyTable[.general] ?? LocalPolicy(
            minimumConfidence: 0.60,
            maximumComplexity: 0.50,
            maximumToolCount: 2
        )
        let primaryModel = preferredModels.first
        let primaryModelID = primaryModel?.rawValue
        return RouteProfile(
            taskClass: taskClass,
            preferredModelIDs: preferredModels.map(\.rawValue),
            primaryModelID: primaryModelID,
            primaryModelName: primaryModel?.displayName ?? primaryModelID ?? "No local model",
            nativeGrammar: LocalToolGrammar.nativeGrammar(forModelID: primaryModelID),
            minimumConfidence: policy.minimumConfidence,
            maximumComplexity: policy.maximumComplexity,
            maximumToolCount: policy.maximumToolCount,
            idleUnloadDelaySeconds: localAgentIdleUnloadDelaySeconds,
            idleUnloadMode: localAgentIdleUnloadMode
        )
    }

    nonisolated static let localAgentIdleUnloadDelaySeconds = 30
    nonisolated static let localAgentIdleUnloadMode = "deep"

    nonisolated static var localAgentIdleUnloadPolicySummary: String {
        "idle unload \(localAgentIdleUnloadDelaySeconds)s/\(localAgentIdleUnloadMode)"
    }

    nonisolated static func inferTaskClass(
        objective: String,
        request: Request,
        classification: Classification
    ) -> TaskClass {
        if request.requiresStructuredOutput || request.schemaJson != nil {
            return .structuredOutput
        }

        let normalized = objective.lowercased()
        if containsAny(normalized, [
            "debug", "trace", "stack trace", "crash", "failing test", "regression",
        ]) {
            return .debugging
        }
        if containsAny(normalized, [
            "code", "refactor", "compile", "function", "class", "swift", "rust",
            "typescript", "python", "xcode", "cargo", "test",
        ]) {
            return .coding
        }
        if containsAny(normalized, [
            "prove", "reason", "logic", "math", "derive", "deduce", "theorem",
        ]) {
            return .reasoning
        }
        if containsAny(normalized, [
            "research", "sources", "citation", "compare", "fact check",
        ]) && !classification.requiresCurrentInfo {
            return .localResearch
        }
        if containsAny(normalized, [
            "synthesize", "summarize", "summary", "analyze", "compare",
        ]) {
            return .synthesis
        }
        if containsAny(normalized, [
            "vault", "note", "notes", "open", "find", "read", "write", "edit",
            "artifact", "tool",
        ]) || classification.toolCountEstimate > 1 {
            return .toolUse
        }
        if classification.complexity <= 0.40,
           classification.toolCountEstimate <= 2 {
            return .fastChat
        }
        return .general
    }

    private func isEligibleForLocalAgentLoop(
        modelID: String?,
        classification: Classification,
        policy: LocalPolicy
    ) -> Bool {
        guard hasCapableLocalAgentModel(modelID) else {
            return false
        }

        guard classification.confidence >= policy.minimumConfidence else {
            return false
        }

        guard !classification.requiresCurrentInfo,
              !classification.requiresCodeExecution else {
            return false
        }

        guard classification.complexity <= policy.maximumComplexity else {
            return false
        }

        return classification.toolCountEstimate <= policy.maximumToolCount
    }

    private func hasCapableLocalAgentModel(_ modelID: String?) -> Bool {
        guard let modelID,
              let model = LocalTextModelID(rawValue: modelID) else {
            return false
        }

        return model.canRunLocalAgentLoop
    }

    private func selectLocalAgentModel(
        for taskClass: TaskClass,
        request: Request
    ) -> String? {
        let candidateModels = localCandidateModels(from: request)
        guard !candidateModels.isEmpty else { return nil }

        let preferredOrder = Self.modelPreferenceTable[
            taskClass,
            default: Self.modelPreferenceTable[.general] ?? []
        ]
        for preferredModel in preferredOrder where candidateModels.contains(preferredModel) {
            return preferredModel.rawValue
        }

        return candidateModels
            .sorted { lhs, rhs in
                if lhs.minimumRecommendedMemoryGB == rhs.minimumRecommendedMemoryGB {
                    return lhs.displayName < rhs.displayName
                }
                return lhs.minimumRecommendedMemoryGB > rhs.minimumRecommendedMemoryGB
            }
            .first?
            .rawValue
    }

    private func localCandidateModels(from request: Request) -> [LocalTextModelID] {
        var seen = Set<String>()
        var ids = request.availableLocalModelIDs
        if let selectedLocalModelID = request.selectedLocalModelID {
            ids.insert(selectedLocalModelID, at: 0)
        }
        return ids.compactMap { id in
            guard seen.insert(id).inserted,
                  let model = LocalTextModelID(rawValue: id),
                  model.canRunLocalAgentLoop else {
                return nil
            }
            return model
        }
    }

    private func localPolicy(for taskClass: TaskClass) -> LocalPolicy {
        let taskPolicy = Self.localPolicyTable[taskClass] ?? Self.localPolicyTable[.general]
        return taskPolicy ?? LocalPolicy(
            minimumConfidence: uncertaintyThreshold,
            maximumComplexity: maxLocalComplexity,
            maximumToolCount: maxLocalToolCount
        )
    }

    private static func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }
}

private extension ConfidenceRouter {
    struct LocalPolicy: Sendable, Equatable {
        let minimumConfidence: Double
        let maximumComplexity: Double
        let maximumToolCount: Int
    }

    nonisolated static let localPolicyTable: [TaskClass: LocalPolicy] = [
        .fastChat: LocalPolicy(minimumConfidence: 0.55, maximumComplexity: 0.40, maximumToolCount: 2),
        .coding: LocalPolicy(minimumConfidence: 0.56, maximumComplexity: 0.68, maximumToolCount: 4),
        .debugging: LocalPolicy(minimumConfidence: 0.58, maximumComplexity: 0.72, maximumToolCount: 5),
        .structuredOutput: LocalPolicy(minimumConfidence: 0.60, maximumComplexity: 0.55, maximumToolCount: 3),
        .localResearch: LocalPolicy(minimumConfidence: 0.58, maximumComplexity: 0.65, maximumToolCount: 4),
        .reasoning: LocalPolicy(minimumConfidence: 0.58, maximumComplexity: 0.72, maximumToolCount: 3),
        .synthesis: LocalPolicy(minimumConfidence: 0.58, maximumComplexity: 0.65, maximumToolCount: 4),
        .toolUse: LocalPolicy(minimumConfidence: 0.58, maximumComplexity: 0.58, maximumToolCount: 5),
        .general: LocalPolicy(minimumConfidence: 0.60, maximumComplexity: 0.50, maximumToolCount: 2),
    ]

    nonisolated static let modelPreferenceTable: [TaskClass: [LocalTextModelID]] = [
        .fastChat: [
            .qwen3_4B4Bit, .qwen35_4B4Bit, .qwen3_8B4Bit,
            .deepseekR1Distill7B, .localAgent43_36B3Bit,
        ],
        .coding: [
            .qwen3Coder30BA3B4Bit, .qwen3CoderNext4Bit,
            .localAgent43_36B4Bit, .localAgent43_36B3Bit,
            .qwen3_8B4Bit, .deepseekR1Distill7B,
        ],
        .debugging: [
            .qwen3Coder30BA3B4Bit, .qwen3CoderNext4Bit,
            .deepseekR1Distill7B, .localAgent43_36B4Bit,
            .localAgent43_36B3Bit, .qwen3_8B4Bit,
        ],
        .structuredOutput: [
            .localAgent43_36B4Bit, .localAgent43_36B3Bit,
            .qwen3Coder30BA3B4Bit, .qwen3CoderNext4Bit,
            .qwen3_8B4Bit, .qwen3_4B4Bit,
        ],
        .localResearch: [
            .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
            .qwen3_8B4Bit, .deepseekR1Distill7B,
            .localAgent43_36B4Bit, .localAgent43_36B3Bit,
        ],
        .reasoning: [
            .qwqFlagship32B4Bit, .deepseekR1Distill7B,
            .qwen3_8B4Bit, .qwen36_35BA3B_Unsloth4Bit,
            .qwen36_35BA3B_DWQ4Bit, .localAgent43_36B4Bit,
        ],
        .synthesis: [
            .qwen36_35BA3B_Unsloth4Bit, .qwen36_35BA3B_DWQ4Bit,
            .qwen3_8B4Bit, .deepseekR1Distill7B,
            .localAgent43_36B4Bit, .localAgent43_36B3Bit,
        ],
        .toolUse: [
            .localAgent43_36B4Bit, .localAgent43_36B3Bit,
            .qwen3Coder30BA3B4Bit, .qwen3CoderNext4Bit,
            .qwen3_8B4Bit, .qwen3_4B4Bit,
        ],
        .general: [
            .qwen3_8B4Bit, .qwen3_4B4Bit,
            .localAgent43_36B3Bit, .deepseekR1Distill7B,
        ],
    ]
}
