import Testing
@testable import Epistemos

/// P2.2 / owner hotfix d — locks the route planner + tool-selection path for
/// vault-lookup queries. The acceptance prompt "please tell me the best essay I
/// have in my vault" MUST be detected as an explicit vault lookup and routed to a
/// tool-using local-execution plan (so the turn actively searches the vault /
/// memory / Knowledge Core), never silently degraded to a tool-less direct
/// stream that answers from priors.
///
/// These exercise the real `OverseerComplexityRouter.planForMainChat` against a
/// real `InferenceState` with a usable local runtime — an integration guard, not
/// a mock — so a regression in the detection cues, the explicit-context gate, or
/// the route selection is caught at compile/test time.
@Suite("Chat vault-lookup routing")
@MainActor
struct ChatVaultLookupRoutingTests {

    private static let e2b = "google/gemma-4-E2B-it-qat-q4_0-gguf"
    private static let e4b = "google/gemma-4-E4B-it-qat-q4_0-gguf"
    private static let b12 = "google/gemma-4-12B-it-qat-q4_0-gguf"

    private static let acceptanceQuery = "please tell me the best essay I have in my vault"

    private static func inferenceWithUsableLocalRuntime() -> InferenceState {
        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 64_000_000_000,
                roundedMemoryGB: 64,
                maxRecommendedLocalContentLength: 28_000
            )
        )
        inference.setAvailableLocalGenerationRuntimeKinds([.mlx, .gguf])
        inference.setInstalledLocalTextModelIDs([e2b, e4b, b12])
        // Pin a Fast Gemma so `effectiveLocalTextModelID` is non-nil →
        // `selectedRoute` sees a usable local runtime (not the no-runtime
        // managed-agent escape hatch).
        inference.setPreferredLocalTextModelID(b12)
        return inference
    }

    @Test("the acceptance query is detected as an explicit vault lookup")
    func acceptanceQueryIsExplicitVaultLookup() {
        #expect(ChatCoordinator.queryContainsExplicitNoteContext(Self.acceptanceQuery))
        // The detection is keyed on the "essay" cue + vault noun, not on an
        // @-mention, so a bare superlative vault question still triggers search.
        #expect(ChatCoordinator.queryContainsExplicitNoteContext("what's my best essay?"))
    }

    @Test("the acceptance query routes to a tool-using local-execution plan with vault tools")
    func acceptanceQueryRoutesToTools() {
        let inference = Self.inferenceWithUsableLocalRuntime()
        let router = OverseerComplexityRouter(inference: inference)

        let plan = router.planForMainChat(
            query: Self.acceptanceQuery,
            contentLength: Self.acceptanceQuery.count,
            operatingMode: .fast,
            // ChatCoordinator passes `hasRequestedVaultLookup` into this flag for
            // exactly this query (queryContainsExplicitNoteContext == true).
            hasExplicitContext: true,
            attachmentCount: 0,
            notesContext: nil,
            conversationHistory: nil
        )

        // Tool path — NOT localOnly (which is the tool-less direct stream that
        // would answer from priors).
        #expect(plan.route == .overseerLocalExecution)
        // The plan actually grants tools to run the search.
        #expect(!plan.allowedToolNames.isEmpty)
        #expect(plan.allowsToolExecution)
    }

    @Test("a generic non-vault question stays on the tool-less localOnly fast path")
    func genericQueryStaysLocalOnly() {
        let inference = Self.inferenceWithUsableLocalRuntime()
        let router = OverseerComplexityRouter(inference: inference)

        let generic = "what is the capital of France"
        #expect(!ChatCoordinator.queryContainsExplicitNoteContext(generic))

        let plan = router.planForMainChat(
            query: generic,
            contentLength: generic.count,
            operatingMode: .fast,
            hasExplicitContext: false,
            attachmentCount: 0,
            notesContext: nil,
            conversationHistory: nil
        )

        // No vault lookup, no attachments, short, Fast → direct local stream.
        #expect(plan.route == .localOnly)
    }

    // MARK: - P2.1 user tool toggles really gate the main-chat tool set

    private func toolGrantingPlan() -> OverseerComplexityRouter.ExecutionPlan {
        let inference = Self.inferenceWithUsableLocalRuntime()
        let router = OverseerComplexityRouter(inference: inference)
        return router.planForMainChat(
            query: Self.acceptanceQuery,
            contentLength: Self.acceptanceQuery.count,
            operatingMode: .fast,
            hasExplicitContext: true,
            attachmentCount: 0,
            notesContext: nil,
            conversationHistory: nil
        )
    }

    @Test("no disabled tools → plan is unchanged (default all-on, no behavior change)")
    func toolGatingDefaultAllOn() {
        let plan = toolGrantingPlan()
        let before = plan.allowedToolNames
        #expect(!before.isEmpty)

        let gated = ChatCoordinator.executionPlanGatedByUserToolToggles(
            plan,
            disabledToolNames: []
        )
        #expect(gated?.allowedToolNames == before)
    }

    @Test("an explicitly-disabled tool is removed from the plan's granted tools")
    func toolGatingRemovesDisabledTool() throws {
        let plan = toolGrantingPlan()
        let before = plan.allowedToolNames
        let target = try #require(before.first)

        let gated = try #require(
            ChatCoordinator.executionPlanGatedByUserToolToggles(
                plan,
                disabledToolNames: [target]
            )
        )
        #expect(!gated.allowedToolNames.contains(target))
        #expect(gated.allowedToolNames.count == before.count - 1)
        // Every surviving tool is one the user did NOT disable.
        #expect(gated.allowedToolNames.allSatisfy { before.contains($0) })
    }

    @Test("disabling a tool the plan never granted is a no-op")
    func toolGatingUnknownToolNoop() {
        let plan = toolGrantingPlan()
        let before = plan.allowedToolNames
        let gated = ChatCoordinator.executionPlanGatedByUserToolToggles(
            plan,
            disabledToolNames: ["definitely.not.a.real.tool.name"]
        )
        #expect(gated?.allowedToolNames == before)
    }
}
