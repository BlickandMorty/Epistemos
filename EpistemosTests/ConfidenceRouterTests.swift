import Foundation
import Testing
@testable import Epistemos

@Suite("Confidence Router")
struct ConfidenceRouterTests {
    @Test("simple high-confidence work stays on the capable local path")
    func simpleHighConfidenceWorkStaysOnTheCapableLocalPath() {
        let router = ConfidenceRouter()
        let request = ConfidenceRouter.Request(
            objective: "Summarize my local note highlights.",
            selectedLocalModelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            requiresStructuredOutput: false,
            schemaJson: nil
        )
        let classification = ConfidenceRouter.Classification(
            complexity: 0.24,
            toolCountEstimate: 1,
            requiresCurrentInfo: false,
            requiresCodeExecution: false,
            privacySensitive: false,
            confidence: 0.91
        )

        let decision = router.route(request: request, classification: classification)

        #expect(decision.route == .local)
        #expect(decision.usesLocalAgentLoop)
        #expect(decision.selectedLocalModelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
        #expect(decision.reason == .localAgentApproved)
    }

    @Test("privacy-sensitive work stays local even when the selected tier cannot act as an agent")
    func privacySensitiveWorkStaysLocalEvenWhenTheSelectedTierCannotActAsAnAgent() {
        let router = ConfidenceRouter()
        let request = ConfidenceRouter.Request(
            objective: "Classify these private medical notes.",
            selectedLocalModelID: LocalTextModelID.qwen35_2B4Bit.rawValue,
            requiresStructuredOutput: true,
            schemaJson: #"{"type":"object"}"#
        )
        let classification = ConfidenceRouter.Classification(
            complexity: 0.72,
            toolCountEstimate: 4,
            requiresCurrentInfo: false,
            requiresCodeExecution: false,
            privacySensitive: true,
            confidence: 0.34
        )

        let decision = router.route(request: request, classification: classification)

        #expect(decision.route == .local)
        #expect(!decision.usesLocalAgentLoop)
        #expect(decision.reason == .privacySensitive)
    }

    @Test("low classifier confidence escalates to cloud fallback")
    func lowClassifierConfidenceEscalatesToCloudFallback() {
        let router = ConfidenceRouter()
        let request = ConfidenceRouter.Request(
            objective: "Refactor this async parser and explain each change.",
            selectedLocalModelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            requiresStructuredOutput: false,
            schemaJson: nil
        )
        let classification = ConfidenceRouter.Classification(
            complexity: 0.35,
            toolCountEstimate: 2,
            requiresCurrentInfo: false,
            requiresCodeExecution: false,
            privacySensitive: false,
            confidence: 0.42
        )

        let decision = router.route(request: request, classification: classification)

        #expect(decision.route == .cloudFallback)
        #expect(!decision.usesLocalAgentLoop)
        #expect(decision.reason == .classificationUncertain)
    }

    @Test("invalid structured output escalates after a local attempt")
    func invalidStructuredOutputEscalatesAfterALocalAttempt() {
        let router = ConfidenceRouter()
        let request = ConfidenceRouter.Request(
            objective: "Return a valid JSON plan.",
            selectedLocalModelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            requiresStructuredOutput: true,
            schemaJson: #"{"type":"object","required":["plan"]}"#
        )
        let classification = ConfidenceRouter.Classification(
            complexity: 0.22,
            toolCountEstimate: 1,
            requiresCurrentInfo: false,
            requiresCodeExecution: false,
            privacySensitive: false,
            confidence: 0.87
        )

        let initial = router.route(request: request, classification: classification)
        let decision = router.validateLocalOutput(
            #"{"oops":true}"#,
            request: request,
            priorDecision: initial,
            verifier: RejectingVerifier()
        )

        #expect(initial.route == .local)
        #expect(initial.usesLocalAgentLoop)
        #expect(decision.route == .cloudFallback)
        #expect(!decision.usesLocalAgentLoop)
        #expect(decision.reason == .structuredOutputInvalid)
    }

    @Test("agent capability remains limited to validated local tiers")
    func agentCapabilityRemainsLimitedToValidatedLocalTiers() {
        #expect(!LocalTextModelID.qwen35_2B4Bit.canActAsAgent)
        #expect(LocalTextModelID.qwen35_4B4Bit.canActAsAgent)
        #expect(!LocalTextModelID.smolLM3_3B4Bit.canActAsAgent)
    }

    @MainActor
    @Test("inference state sanitizes hidden local agent tiers before exposing agent loop gating")
    func inferenceStateSanitizesHiddenLocalAgentTiersBeforeExposingAgentLoopGating() async {
        await withResetInferenceDefaults {
            let inference = InferenceState()
            inference.setInstalledLocalTextModelIDs([
                LocalTextModelID.qwen35_2B4Bit.rawValue,
                LocalTextModelID.qwen35_4B4Bit.rawValue,
            ])

            let profile = Self.agentProfile(contentLength: 480)

            inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_2B4Bit.rawValue)
            #expect(!inference.supportsLocalAgentLoop)
            #expect(!inference.canRouteToLocalAgentLoop(for: profile))

            inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)
            #expect(inference.preferredLocalTextModelID == LocalTextModelID.qwen35_2B4Bit.rawValue)
            #expect(inference.effectiveLocalTextModelID == LocalTextModelID.qwen35_2B4Bit.rawValue)
            #expect(!inference.supportsLocalAgentLoop)
            #expect(!inference.canRouteToLocalAgentLoop(for: profile))
        }
    }

    @MainActor
    @Test("policy context excludes hidden local models from automatic routing")
    func policyContextExcludesHiddenLocalModelsFromAutomaticRouting() async {
        await withResetInferenceDefaults {
            let inference = InferenceState()
            inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
            inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

            let profile = Self.agentProfile(contentLength: 480)

            #expect(inference.effectiveLocalTextModelID == nil)
            #expect(inference.localModelSelection(for: profile) == nil)
            #expect(!inference.canRouteToLocalAgentLoop(for: profile))
        }
    }

    @MainActor
    private func withResetInferenceDefaults(
        _ operation: @MainActor () async -> Void
    ) async {
        let defaults = UserDefaults.standard
        let keys = [
            "epistemos.localRoutingMode",
            "epistemos.preferredLocalTextModelID",
            "epistemos.preferredChatModelSelection",
        ]
        let savedValues = keys.reduce(into: [String: Any?]()) { result, key in
            result[key] = defaults.object(forKey: key)
            defaults.removeObject(forKey: key)
        }
        defer {
            for key in keys {
                if let value = savedValues[key] ?? nil {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        await operation()
    }

    private static func agentProfile(contentLength: Int) -> InferenceRequestProfile {
        InferenceRequestProfile(
            surface: .mainChat,
            intent: .synthesis,
            contentLength: contentLength,
            promptLength: contentLength,
            contextBlockCount: 1,
            estimatedTokenLoad: max(1, contentLength / 4),
            baseComplexity: 0.28,
            queryComplexity: 0.18,
            requestedReasoningMode: .fast,
            explicitThinkingRequested: false,
            explicitFastRequested: false,
            visibleThinkingRequested: false
        )
    }
}

private struct RejectingVerifier: LocalAgentOutputVerifying {
    func verify(output: String, schemaJson: String?) -> Result<Void, LocalAgentOutputVerificationError> {
        .failure(LocalAgentOutputVerificationError("Schema mismatch"))
    }
}
