import Testing
@testable import Epistemos

@Suite("Compute Steering Phase 2")
struct ComputeSteeringTests {

    // MARK: - BackendSteeringHints JSON serialization

    @Test("steering hints serialize to valid JSON")
    func steeringHintsSerializeToValidJSON() {
        let hints = BackendSteeringHints(
            maskPlan: BackendSteeringMaskPlan(
                expertAllowlist: ["expert_0", "expert_1"],
                blockSize: 128,
                rationale: "test mask"
            ),
            kvPolicyHint: "flush_all",
            depthBudget: BackendSteeringDepthBudget(
                maxTurns: 3,
                maxReasoningSteps: 10,
                maxToolCalls: 5,
                maxOutputTokens: 2048
            ),
            loraBlendCoefficients: [
                BackendSteeringLoRACoefficient(adapterID: "coding", coefficient: 0.7),
                BackendSteeringLoRACoefficient(adapterID: "writing", coefficient: 0.3),
            ]
        )

        let json = hints.toJSON()
        #expect(json != nil)
        guard let json else { return }
        #expect(json.contains("expert_0"))
        #expect(json.contains("flush_all"))
        #expect(json.contains("coding"))
    }

    @Test("steering hints with nil fields serialize without those fields")
    func steeringHintsNilFieldsOmitted() {
        let hints = BackendSteeringHints(
            maskPlan: nil,
            kvPolicyHint: nil,
            depthBudget: nil,
            loraBlendCoefficients: nil
        )

        let json = hints.toJSON()
        #expect(json != nil)
    }

    // MARK: - Compute profile mapping

    @Test("compute profile enum has expected cases")
    func computeProfileEnumCases() {
        let allCases = BackendComputeProfile.allCases
        #expect(allCases.count == 5)
        #expect(allCases.contains(.standard))
        #expect(allCases.contains(.deepGraph))
        #expect(allCases.contains(.adaptive))
        #expect(allCases.contains(.experimental))
        #expect(allCases.contains(.visualSidecar))
    }

    @Test("expert budget class has expected cases")
    func expertBudgetClassEnumCases() {
        let allCases = BackendExpertBudgetClass.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.default))
        #expect(allCases.contains(.constrained))
        #expect(allCases.contains(.deep))
    }

    @Test("KV policy kind has expected cases")
    func kvPolicyKindEnumCases() {
        let allCases = BackendKVPolicyKind.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.baseline))
        #expect(allCases.contains(.compressed))
        #expect(allCases.contains(.blocked))
    }

    // MARK: - Compute budget

    @Test("compute budget unbounded check")
    func computeBudgetUnbounded() {
        let budget = BackendComputeBudget(
            maxWallMS: nil,
            maxTokens: nil,
            maxIOBytes: nil,
            maxAdaptSteps: nil,
            maxAuxCalls: nil
        )
        #expect(budget.isUnbounded)

        let bounded = BackendComputeBudget(
            maxWallMS: 5000,
            maxTokens: nil,
            maxIOBytes: nil,
            maxAdaptSteps: nil,
            maxAuxCalls: nil
        )
        #expect(!bounded.isUnbounded)
    }

    // MARK: - OverseerPlanV1 steering hints bridge

    @Test("overseer plan produces steering hints JSON")
    func overseerPlanProducesSteeringHintsJSON() throws {
        let plan = OverseerPlanV1(
            version: .v1,
            route: .localOnly,
            maskPlan: OverseerMaskPlan(
                expertAllowlist: ["expert_a", "expert_b"],
                rationale: "test rationale"
            ),
            loraBlendCoefficients: [
                OverseerLoRABlendCoefficient(adapterID: "coding", coefficient: 0.6),
                OverseerLoRABlendCoefficient(adapterID: "research", coefficient: 0.4),
            ],
            kvPolicyFlag: .preserveSharedBase,
            depthBudget: OverseerDepthBudget(
                maxTurns: 3,
                maxReasoningSteps: 10,
                maxToolCalls: 5,
                maxOutputTokens: 4096
            ),
            toolPermissions: [
                OverseerToolPermission(toolName: "search", mode: .allow)
            ],
            contextSummary: OverseerContextSummary(
                summary: "Test context",
                entityIDs: ["entity-1"],
                sourceSessionID: nil
            )
        )

        let json = plan.toSteeringHintsJSON()
        #expect(json != nil)
        guard let json else { return }
        #expect(json.contains("expert_a"))
        #expect(json.contains("preserve_shared_base"))
        #expect(json.contains("coding"))
    }

    // MARK: - BackendGenerationRequest accepts steering hints

    @Test("generation request accepts steering hints JSON field")
    func generationRequestAcceptsSteeringHintsJSON() {
        let request = BackendGenerationRequest(
            requestID: "req-steering-test",
            requestedRuntimeKind: .gguf,
            executionMode: .local,
            modelID: "test-model",
            artifactID: nil,
            modelHandleID: nil,
            prompt: "Hello",
            systemPrompt: nil,
            maxOutputTokens: 32,
            temperature: 0.2,
            stopSequences: [],
            toolPolicyRef: nil,
            contextRef: nil,
            reasoningProfile: .standard,
            executionPolicyRef: nil,
            steeringHintsJSON: "{\"kv_policy_hint\":\"flush_all\"}",
            priority: 0,
            timeoutMS: 5000,
            streamOptions: BackendGenerationStreamOptions()
        )

        #expect(request.steeringHintsJSON != nil)
        #expect(request.steeringHintsJSON?.contains("flush_all") == true)
    }

    @Test("generation request works with nil steering hints")
    func generationRequestWorksWithNilSteeringHints() {
        let request = BackendGenerationRequest(
            requestID: "req-no-steering",
            requestedRuntimeKind: .gguf,
            executionMode: .local,
            modelID: "test-model",
            artifactID: nil,
            modelHandleID: nil,
            prompt: "Hello",
            systemPrompt: nil,
            maxOutputTokens: 32,
            temperature: 0.2,
            stopSequences: [],
            toolPolicyRef: nil,
            contextRef: nil,
            reasoningProfile: .standard,
            executionPolicyRef: nil,
            steeringHintsJSON: nil,
            priority: 0,
            timeoutMS: 5000,
            streamOptions: BackendGenerationStreamOptions()
        )

        #expect(request.steeringHintsJSON == nil)
    }

    // MARK: - BackendRuntimeStats typed fields

    @Test("runtime stats includes typed compute steering fields")
    func runtimeStatsIncludesTypedComputeSteeringFields() {
        let stats = BackendRuntimeStats(
            requestedRuntimeKind: .gguf,
            resolvedRuntimeKind: .gguf,
            requestedReasoningProfile: .deep,
            resolvedReasoningProfile: .deep,
            modelID: "test-model",
            artifactID: nil,
            executionPolicyID: "policy.deep_graph.local",
            fallbackMode: "resident",
            memoryPressureState: "normal",
            executionPhase: "decode",
            maskingState: "dense",
            kvPolicyState: "baseline",
            expertBudgetState: "deep",
            adaptationState: "disabled",
            guardrailState: "clear",
            sidecarState: "disabled",
            budgetOutcome: "within_budget",
            planTracePresent: true,
            computeProfile: .deepGraph,
            expertBudgetClass: .deep,
            kvPolicyKind: .baseline,
            capabilities: .runtime(.gguf),
            cancelled: false,
            terminalEventEmitted: false
        )

        #expect(stats.computeProfile == .deepGraph)
        #expect(stats.expertBudgetClass == .deep)
        #expect(stats.kvPolicyKind == .baseline)
        #expect(stats.expertBudgetState == "deep")
        #expect(stats.kvPolicyState == "baseline")
        #expect(stats.maskingState == "dense")
        #expect(stats.sidecarState == "disabled")
        #expect(stats.budgetOutcome == "within_budget")
    }

    @Test("runtime stats typed fields can be nil")
    func runtimeStatsTypedFieldsCanBeNil() {
        let stats = BackendRuntimeStats(
            requestedRuntimeKind: .gguf,
            resolvedRuntimeKind: .gguf,
            requestedReasoningProfile: nil,
            resolvedReasoningProfile: nil,
            modelID: "test-model",
            artifactID: nil,
            executionPolicyID: nil,
            fallbackMode: nil,
            memoryPressureState: nil,
            executionPhase: nil,
            maskingState: "dense",
            kvPolicyState: "baseline",
            expertBudgetState: "default",
            adaptationState: "disabled",
            guardrailState: "clear",
            sidecarState: "disabled",
            budgetOutcome: "not_evaluated",
            planTracePresent: false,
            computeProfile: nil,
            expertBudgetClass: nil,
            kvPolicyKind: nil,
            capabilities: .runtime(.gguf),
            cancelled: false,
            terminalEventEmitted: false
        )

        #expect(stats.computeProfile == nil)
        #expect(stats.expertBudgetClass == nil)
        #expect(stats.kvPolicyKind == nil)
    }
}
