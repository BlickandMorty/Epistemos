import Testing
@testable import Epistemos

@Suite("Planner Overseer Refinement")
struct PlannerOverseerRefinementTests {

    private struct StubRefinementProvider: PlannerOverseerRefinement {
        let result: Result<PlannerRefinementResult, PlannerRefinementError>
        let isAvailable: Bool
        let minimumComplexityThreshold: Double

        func refine(context: PlannerRefinementContext) async -> Result<PlannerRefinementResult, PlannerRefinementError> {
            result
        }
    }

    @Test("refinement context captures query and heuristic plan")
    func refinementContextCapture() {
        let plan = OverseerPlanV1(
            version: .v1,
            route: .localOnly,
            maskPlan: OverseerMaskPlan(expertAllowlist: ["reasoning.code"], rationale: nil),
            loraBlendCoefficients: [],
            kvPolicyFlag: .preserveSharedBase,
            depthBudget: OverseerDepthBudget(maxTurns: 3, maxReasoningSteps: 10, maxToolCalls: 5, maxOutputTokens: 2048),
            toolPermissions: [],
            contextSummary: OverseerContextSummary(summary: "test", entityIDs: [], sourceSessionID: nil)
        )
        let context = PlannerRefinementContext(
            query: "Explain quantum computing",
            heuristicPlan: plan,
            heuristicSummary: "general query",
            complexity: 0.7,
            notesContext: nil,
            conversationHistory: nil
        )
        #expect(context.query == "Explain quantum computing")
        #expect(context.complexity == 0.7)
        #expect(context.heuristicPlan.route == .localOnly)
    }

    @Test("refinement result requires minimum confidence")
    func refinementResultConfidence() {
        let result = PlannerRefinementResult(
            refinedPlan: OverseerPlanV1(
                version: .v1,
                route: .localOnly,
                maskPlan: OverseerMaskPlan(expertAllowlist: ["reasoning.code"], rationale: "refined"),
                loraBlendCoefficients: [],
                kvPolicyFlag: .preserveSharedBase,
                depthBudget: OverseerDepthBudget(maxTurns: 5, maxReasoningSteps: 20, maxToolCalls: 10, maxOutputTokens: 4096),
                toolPermissions: [],
                contextSummary: OverseerContextSummary(summary: "refined context", entityIDs: [], sourceSessionID: nil)
            ),
            refinedSummary: "refined plan",
            confidence: 0.85,
            refinementDurationMS: 150.0
        )
        #expect(result.confidence > 0.6)
        #expect(result.refinedSummary == "refined plan")
    }

    @Test("refinement error descriptions are informative")
    func refinementErrors() {
        let errors: [PlannerRefinementError] = [
            .modelUnavailable,
            .refinementTimedOut,
            .invalidRefinedPlan("bad mask"),
            .refinementFailed("network error"),
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("model refined planner accepts high-confidence validated refinements")
    @MainActor
    func modelRefinedPlannerAcceptsValidatedRefinement() async {
        let plan = OverseerPlanV1(
            version: .v1,
            route: .overseerLocalExecution,
            maskPlan: OverseerMaskPlan(expertAllowlist: ["reasoning.code", "retrieval.graph"], rationale: "refined"),
            loraBlendCoefficients: [],
            kvPolicyFlag: .preserveAdapterCompatible,
            depthBudget: OverseerDepthBudget(maxTurns: 4, maxReasoningSteps: 16, maxToolCalls: 8, maxOutputTokens: 3072),
            toolPermissions: [OverseerToolPermission(toolName: "vault.read", mode: .allow)],
            contextSummary: OverseerContextSummary(summary: "refined context", entityIDs: ["entity-1"], sourceSessionID: nil)
        )
        let provider = StubRefinementProvider(
            result: .success(
                PlannerRefinementResult(
                    refinedPlan: plan,
                    refinedSummary: "refined plan",
                    confidence: 0.9,
                    refinementDurationMS: 42
                )
            ),
            isAvailable: true,
            minimumComplexityThreshold: 0
        )
        let planner = ModelRefinedPlanner(
            inference: InferenceState(),
            refinementProvider: provider,
            refinementConfidenceThreshold: 0.6
        )

        let executionPlan = await planner.planForMainChat(
            query: "Design a careful multi-step plan for graph analysis with retrieval and tool checks",
            contentLength: 400,
            operatingMode: .agent,
            hasExplicitContext: true,
            attachmentCount: 1,
            notesContext: "note context",
            conversationHistory: "history"
        )

        #expect(executionPlan.summary == "refined plan")
        #expect(executionPlan.plan.route == .overseerLocalExecution)
        #expect(executionPlan.plan.depthBudget.maxToolCalls == 8)
    }

    @Test("placeholder mask predictor fails closed")
    func placeholderMaskPredictorFailsClosed() async {
        let predictor = PlaceholderMaskPredictor()

        let result = await predictor.predict(instruction: "Apply a learned sparse mask to the reasoning layers")

        #expect(predictor.isAvailable == false)
        switch result {
        case .failure(.predictorUnavailable):
            break
        default:
            Issue.record("Expected predictorUnavailable failure, got \(result)")
        }
    }
}
