import Testing
@testable import Epistemos

@Suite("TriageService")
struct TriageServiceTests {

    @Test("empty string is a refusal")
    func emptyRefusal() {
        #expect(TriageService.isRefusalResponse(""))
    }

    @Test("whitespace-only string is a refusal")
    func whitespaceRefusal() {
        #expect(TriageService.isRefusalResponse("   \n  "))
    }

    @Test("generic and Apple refusals are detected")
    func refusalDetection() {
        #expect(TriageService.isRefusalResponse("I can't help with that request."))
        #expect(TriageService.isRefusalResponse("As a language model created by Apple, I am unable to assist with that."))
        #expect(!TriageService.isRefusalResponse("Bayesian updating revises beliefs in proportion to evidence."))
    }

    @Test("truncation detection catches short and abrupt responses")
    func truncationDetection() {
        #expect(TriageService.isTruncatedResponse("Yes"))
        #expect(TriageService.isTruncatedResponse("This response ends abruptly without punctuation"))
        #expect(!TriageService.isTruncatedResponse("This response is complete."))
        #expect(!TriageService.isTruncatedResponse("Here are the key points:\n- First item"))
    }

    @Test("fallback heuristic combines refusal and truncation checks")
    func fallbackHeuristic() {
        #expect(TriageService.shouldRetryWithLocalModel(""))
        #expect(TriageService.shouldRetryWithLocalModel("I cannot assist with that."))
        #expect(TriageService.shouldRetryWithLocalModel("Short"))
        #expect(!TriageService.shouldRetryWithLocalModel("This answer is complete, substantive, and properly finished."))
    }

    @Test("operation complexity ordering stays coherent")
    func complexityOrdering() {
        #expect(NotesOperation.grammarFix.baseComplexity < NotesOperation.summarize.baseComplexity)
        #expect(NotesOperation.summarize.baseComplexity <= NotesOperation.ask(query: "test").baseComplexity)
        #expect(NotesOperation.ask(query: "test").baseComplexity < NotesOperation.outline.baseComplexity)
        #expect(NotesOperation.outline.baseComplexity < NotesOperation.expand.baseComplexity)
        #expect(NotesOperation.expand.baseComplexity < NotesOperation.analyze.baseComplexity)
        #expect(NotesOperation.analyze.baseComplexity < NotesOperation.learn.baseComplexity)
    }

    @Test("triage decisions expose labels and icons")
    func decisionPresentation() {
        #expect(!TriageDecision.appleIntelligence.label.isEmpty)
        #expect(!TriageDecision.localMLX.label.isEmpty)
        #expect(!TriageDecision.appleIntelligence.icon.isEmpty)
        #expect(!TriageDecision.localMLX.icon.isEmpty)
        #expect(TriageDecision.appleIntelligence.isOnDevice)
        #expect(TriageDecision.localMLX.isOnDevice)
    }

    @Test("routing stays Apple plus local without stale cloud modes or providers")
    func routingSurfaceRemainsTwoState() {
        #expect(LocalRoutingMode.allCases == [.auto, .localOnly])
        #expect(LLMProviderType.allCases == [.appleIntelligence, .localMLX])
    }
}

@Suite("InferencePolicyEngine")
struct InferencePolicyEngineTests {

    @Test("auto mode uses Apple Intelligence for lightweight rewrite work")
    func autoUsesAppleForLightRewrite() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .noteChat,
                intent: .rewrite,
                contentLength: 240,
                promptLength: 180,
                contextBlockCount: 1,
                estimatedTokenLoad: 120,
                baseComplexity: 0.25,
                queryComplexity: 0.05,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(appleAvailable: true)
        )

        #expect(decision.selectedRoute == .appleIntelligence)
        #expect(decision.localSelection == nil)
        #expect(decision.reasonCodes.contains(.simpleTaskAppleEligible))
    }

    @Test("heavier local work keeps the selected local tier")
    func heavierLocalWorkPicksBalancedTier() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .coding,
                contentLength: 2_400,
                promptLength: 2_200,
                contextBlockCount: 3,
                estimatedTokenLoad: 900,
                baseComplexity: 0.35,
                queryComplexity: 0.40,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: true,
                installed: [
                    .qwen35_2B4Bit,
                    .qwen35_4B4Bit,
                ]
            )
        )

        #expect(decision.selectedRoute == .localQwen)
        #expect(decision.localSelection?.modelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
        #expect(decision.localSelection?.reasoningMode == .fast)
    }

    @Test("explicit deep reasoning request no longer changes local response mode")
    func explicitThinkingDoesNotChangeLocalMode() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .graph,
                intent: .graphAnalysis,
                contentLength: 6_000,
                promptLength: 5_500,
                contextBlockCount: 6,
                estimatedTokenLoad: 2_400,
                baseComplexity: 0.60,
                queryComplexity: 0.55,
                requestedReasoningMode: .thinking,
                explicitThinkingRequested: true,
                explicitFastRequested: false,
                visibleThinkingRequested: true
            ),
            context: makeContext(
                appleAvailable: true,
                installed: [
                    .qwen35_2B4Bit,
                    .qwen35_4B4Bit,
                ]
            )
        )

        #expect(decision.selectedRoute == .localQwen)
        #expect(decision.localSelection?.reasoningMode == .fast)
        #expect(!decision.reasonCodes.contains(.explicitThinkingRequested))
    }

    @Test("structured analysis keeps local mode fast even when thinking is requested")
    func structuredAnalysisKeepsFastMode() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .structuredAnalysis,
                contentLength: 6_800,
                promptLength: 6_200,
                contextBlockCount: 4,
                estimatedTokenLoad: 1_900,
                baseComplexity: 0.65,
                queryComplexity: 0.42,
                requestedReasoningMode: .thinking,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: true
            ),
            context: makeContext(
                appleAvailable: true,
                installed: [
                    .qwen35_2B4Bit,
                    .qwen35_4B4Bit,
                ]
            )
        )

        #expect(decision.selectedRoute == .localQwen)
        #expect(decision.localSelection?.modelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
        #expect(decision.localSelection?.reasoningMode == .fast)
    }

    @Test("thinking panel visibility does not force trivial prompts into thinking mode")
    func thinkingPanelVisibilityDoesNotForceThinkingMode() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .simpleAsk,
                contentLength: 32,
                promptLength: 16,
                contextBlockCount: 0,
                estimatedTokenLoad: 8,
                baseComplexity: 0.10,
                queryComplexity: 0.01,
                requestedReasoningMode: .thinking,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: true
            ),
            context: makeContext(
                appleAvailable: false,
                installed: [.qwen35_2B4Bit, .qwen35_4B4Bit]
            )
        )

        #expect(decision.selectedRoute == .localQwen)
        #expect(decision.localSelection?.reasoningMode == .fast)
    }

    @Test("thinking panel visibility does not block Apple for trivial prompts")
    func thinkingPanelVisibilityDoesNotBlockApple() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .simpleAsk,
                contentLength: 24,
                promptLength: 24,
                contextBlockCount: 0,
                estimatedTokenLoad: 12,
                baseComplexity: 0.10,
                queryComplexity: 0.01,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: true
            ),
            context: makeContext(appleAvailable: true)
        )

        #expect(decision.selectedRoute == .appleIntelligence)
    }

    @Test("freeform chat keeps the selected local tier for trivial local asks")
    func freeformChatKeepsSelectedLocalTierForTrivialLocalAsks() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .simpleAsk,
                contentLength: 32,
                promptLength: 32,
                contextBlockCount: 0,
                estimatedTokenLoad: 16,
                baseComplexity: 0.10,
                queryComplexity: 0.01,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: false,
                installed: [.qwen35_0_8B4Bit, .qwen35_2B4Bit, .qwen35_4B4Bit]
            )
        )

        #expect(decision.selectedRoute == .localQwen)
        #expect(decision.localSelection?.modelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
    }

    @Test("preferred local model stays fixed for lightweight local work")
    func preferredLocalModelStaysFixedForLightweightWork() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .summarize,
                contentLength: 480,
                promptLength: 440,
                contextBlockCount: 1,
                estimatedTokenLoad: 180,
                baseComplexity: 0.20,
                queryComplexity: 0.08,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: true,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: false,
                installed: [
                    .qwen35_2B4Bit,
                    .qwen35_4B4Bit,
                ]
            )
        )

        #expect(decision.selectedRoute == .localQwen)
        #expect(decision.localSelection?.modelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
        #expect(!decision.reuseWarmModel)
    }

    @Test("local only bypasses Apple Intelligence even for trivial work")
    func localOnlyBypassesApple() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .noteChat,
                intent: .rewrite,
                contentLength: 200,
                promptLength: 140,
                contextBlockCount: 1,
                estimatedTokenLoad: 100,
                baseComplexity: 0.25,
                queryComplexity: 0.05,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                routingMode: .localOnly,
                appleAvailable: true,
                installed: [.qwen35_2B4Bit]
            )
        )

        #expect(decision.selectedRoute == .localQwen)
        #expect(decision.reasonCodes.contains(.localModeForced))
    }

    @Test("constrained runtime keeps the selected local tier")
    func constrainedRuntimeDownshiftsTier() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .coding,
                contentLength: 2_000,
                promptLength: 1_900,
                contextBlockCount: 2,
                estimatedTokenLoad: 700,
                baseComplexity: 0.35,
                queryComplexity: 0.35,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: false,
                installed: [
                    .qwen35_2B4Bit,
                    .qwen35_4B4Bit,
                ],
                runtimeConditions: LocalRuntimeConditions(
                    lowPowerModeEnabled: true,
                    appActive: false,
                    thermalState: .serious
                )
            )
        )

        #expect(decision.selectedRoute == .localQwen)
        #expect(decision.localSelection?.modelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
        #expect(decision.reasonCodes.contains(.preferredLocalModelUsed))
    }

    private func makeContext(
        routingMode: LocalRoutingMode = .auto,
        appleAvailable: Bool,
        installed: [LocalTextModelID] = [.qwen35_2B4Bit, .qwen35_4B4Bit],
        runtimeConditions: LocalRuntimeConditions = LocalRuntimeConditions(
            lowPowerModeEnabled: false,
            appActive: true,
            thermalState: .nominal
        )
    ) -> InferencePolicyContext {
        InferencePolicyContext(
            routingMode: routingMode,
            appleIntelligenceAvailable: appleAvailable,
            preferredLocalTextModelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            installedLocalTextModelIDs: Set(installed.map(\.rawValue)),
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 18_000_000_000,
                roundedMemoryGB: 18,
                maxRecommendedLocalContentLength: 8_000
            ),
            runtimeConditions: runtimeConditions
        )
    }
}

@MainActor
final class TriageIntegrationMockLLMClient: LLMClientProtocol {
    var generateCalls: [(prompt: String, systemPrompt: String?, maxTokens: Int)] = []
    var streamCalls: [(prompt: String, systemPrompt: String?, maxTokens: Int)] = []

    var generateResult: Result<String, Error> = .success("mock-generate")
    var streamTokens: [String] = ["mock-stream"]
    var streamError: (any Error)?

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        generateCalls.append((prompt, systemPrompt, maxTokens))
        switch generateResult {
        case .success(let output):
            return output
        case .failure(let error):
            throw error
        }
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        streamCalls.append((prompt, systemPrompt, maxTokens))
        let tokens = streamTokens
        let error = streamError

        return AsyncThrowingStream { continuation in
            Task {
                for token in tokens {
                    continuation.yield(token)
                }
                if let error {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish()
                }
            }
        }
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(
            provider: .localMLX,
            model: LocalTextModelID.qwen35_4B4Bit.rawValue,
            reasoningMode: .fast
        )
    }

    func enrichmentSnapshot() -> LLMSnapshot { configSnapshot() }
}

@Suite("TriageService Integration")
struct TriageServiceIntegrationTests {

    @Test("notes triage uses Apple Intelligence for simple transforms in Auto mode")
    @MainActor func notesSimpleOperationsUseAppleIntelligence() {
        let triage = makeService(appleAvailable: true)

        #expect(triage.triage(operation: .grammarFix, contentLength: 240) == .appleIntelligence)
        #expect(triage.triage(operation: .summarize, contentLength: 240) == .appleIntelligence)
        #expect(triage.triage(operation: .rewrite, contentLength: 240) == .appleIntelligence)
        #expect(triage.triage(operation: .ask(query: "What is the core point of this note?"), contentLength: 240) == .appleIntelligence)
    }

    @Test("notes triage uses local qwen for deeper work")
    @MainActor func notesComplexOperationsUseLocal() {
        let triage = makeService(
            appleAvailable: true,
            localInstalled: [LocalTextModelID.qwen35_4B4Bit.rawValue]
        )

        #expect(triage.triage(operation: .continueWriting, contentLength: 1_000) == .localMLX)
        #expect(triage.triage(operation: .analyze, contentLength: 2_000) == .localMLX)
        #expect(triage.triage(operation: .learn, contentLength: 4_000) == .localMLX)
    }

    @Test("Apple unavailable routes notes work to local qwen")
    @MainActor func notesAppleUnavailableUsesLocal() {
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [LocalTextModelID.qwen35_4B4Bit.rawValue]
        )

        #expect(triage.triage(operation: .grammarFix, contentLength: 100) == .localMLX)
    }

    @Test("general brainstorm uses Apple Intelligence for lightweight work")
    @MainActor func generalBrainstormUsesAppleIntelligence() {
        let triage = makeService(appleAvailable: true)
        #expect(triage.triageGeneral(operation: .brainstorm, contentLength: 500) == .appleIntelligence)
    }

    @Test("general higher-complexity work uses local qwen")
    @MainActor func generalComplexUsesLocal() {
        let triage = makeService(
            appleAvailable: true,
            localInstalled: [LocalTextModelID.qwen35_4B4Bit.rawValue]
        )

        #expect(
            triage.triageGeneral(
                operation: .chatResponse(query: "Compare Bayesian and evidential decision theory."),
                contentLength: 5_000
            ) == .localMLX
        )
        #expect(triage.triageGeneral(operation: .epistemicLens, contentLength: 500) == .localMLX)
        #expect(triage.triageGeneral(operation: .structuredAnalysis, contentLength: 10_000) == .localMLX)
    }

    @Test("local only bypasses Apple Intelligence")
    @MainActor func localOnlyForcesLocalQwen() {
        let triage = makeService(
            appleAvailable: true,
            localInstalled: [LocalTextModelID.qwen35_4B4Bit.rawValue],
            routingMode: .localOnly
        )

        #expect(triage.triage(operation: .grammarFix, contentLength: 100) == .localMLX)
        #expect(
            triage.triageGeneral(
                operation: .chatResponse(query: "Explain coherentism."),
                contentLength: 400
            ) == .localMLX
        )
    }

    @Test("direct triage calls do not mutate lastDecision")
    @MainActor func triageCallsDoNotMutateLastDecision() {
        let triage = makeService(appleAvailable: true)

        _ = triage.triage(operation: .grammarFix, contentLength: 50)
        _ = triage.triageGeneral(operation: .brainstorm, contentLength: 50)
        #expect(triage.lastDecision == nil)
    }

    @Test("notes generate uses local path and records maxTokens default")
    @MainActor func notesGenerateUsesLocalPath() async throws {
        let llm = TriageIntegrationMockLLMClient()
        llm.generateResult = .success("local-response")
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [LocalTextModelID.qwen35_4B4Bit.rawValue],
            localLLMService: llm
        )

        let output = try await triage.generate(
            prompt: "Prompt A",
            systemPrompt: "System A",
            operation: .analyze,
            contentLength: 1_800
        )

        #expect(output == "local-response")
        #expect(triage.lastDecision == .localMLX)
        #expect(llm.generateCalls.count == 1)
        #expect(llm.generateCalls[0].prompt == "Prompt A")
        #expect(llm.generateCalls[0].systemPrompt == "System A")
        #expect(llm.generateCalls[0].maxTokens == 4096)
    }

    @Test("notes stream uses local path and yields all chunks")
    @MainActor func notesStreamUsesLocalPath() async {
        let llm = TriageIntegrationMockLLMClient()
        llm.streamTokens = ["alpha", " ", "beta"]
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [LocalTextModelID.qwen35_4B4Bit.rawValue],
            localLLMService: llm
        )

        let stream = triage.stream(
            prompt: "Prompt C",
            systemPrompt: "System C",
            operation: .expand,
            contentLength: 900
        )
        let outcome = await LocalRuntimeSmokeSupport.collect(stream)

        #expect(outcome.tokens == ["alpha", " ", "beta"])
        #expect(outcome.error == nil)
        #expect(triage.lastDecision == .localMLX)
        #expect(llm.streamCalls.count == 1)
        #expect(llm.streamCalls[0].maxTokens == 0)
    }

    @Test("missing local model throws in local only mode")
    @MainActor func missingModelThrowsWhenLocalIsRequired() async {
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [],
            routingMode: .localOnly
        )

        await #expect(throws: LocalInferenceRoutingError.modelRequired) {
            try await triage.generateGeneral(
                prompt: "Explain coherentism.",
                operation: .chatResponse(query: "Explain coherentism."),
                contentLength: 200
            )
        }
    }

    @Test("refusal detection is case-insensitive and prefix-bounded")
    func refusalCaseInsensitivityAndPrefixWindow() {
        #expect(TriageService.isRefusalResponse("I CANNOT ASSIST WITH THIS REQUEST."))

        let longPrefix = String(repeating: "valid-content ", count: 45)
        let buried = longPrefix + "I cannot assist with this request."
        #expect(!TriageService.isRefusalResponse(buried))
    }

    @Test("truncation detection accepts terminal bracket and quote")
    func truncationTerminalCharactersAccepted() {
        #expect(!TriageService.isTruncatedResponse("The quoted sentence is complete.'"))
        #expect(!TriageService.isTruncatedResponse("The bracketed citation is complete.]"))
    }

    @Test("live smoke verifies installed 4B qwen, auto/local routing, thinking stream, and notes plus graph memory")
    @MainActor func liveQwen35Smoke() async throws {
        guard FileManager.default.fileExists(atPath: "/tmp/epi-live-local-qwen35-smoke") else { return }
        try await LocalRuntimeSmokeSupport.runLiveQwen35Smoke()
    }

    @MainActor
    @Test("local runtime tuning unloads faster and uses lower cache budgets on low power")
    func lowPowerRuntimeTuningIsMoreAggressive() {
        let snapshot = LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: 18_000_000_000,
            roundedMemoryGB: 18,
            maxRecommendedLocalContentLength: 8_000
        )

        let normal = LocalMLXRuntimeTuning.runtimePolicy(
            snapshot: snapshot,
            conditions: LocalRuntimeConditions(
                lowPowerModeEnabled: false,
                appActive: true,
                thermalState: .nominal
            )
        )
        let lowPower = LocalMLXRuntimeTuning.runtimePolicy(
            snapshot: snapshot,
            conditions: LocalRuntimeConditions(
                lowPowerModeEnabled: true,
                appActive: true,
                thermalState: .nominal
            )
        )

        #expect(lowPower.idleUnloadDelay < normal.idleUnloadDelay)
        #expect(lowPower.memoryPolicy.cacheLimitBytes < normal.memoryPolicy.cacheLimitBytes)
        #expect(lowPower.memoryPolicy.memoryLimitBytes <= normal.memoryPolicy.memoryLimitBytes)
    }

    @MainActor
    @Test("background thermal pressure tightens local runtime budgets on 18GB machines")
    func backgroundThermalPressureTightensRuntimeBudgets() {
        let snapshot = LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: 18_000_000_000,
            roundedMemoryGB: 18,
            maxRecommendedLocalContentLength: 8_000
        )

        let normalConditions = LocalRuntimeConditions(
            lowPowerModeEnabled: false,
            appActive: true,
            thermalState: .nominal
        )
        let constrainedConditions = LocalRuntimeConditions(
            lowPowerModeEnabled: true,
            appActive: false,
            thermalState: .serious
        )

        let normalPolicy = LocalMLXRuntimeTuning.runtimePolicy(
            snapshot: snapshot,
            conditions: normalConditions
        )
        let constrainedPolicy = LocalMLXRuntimeTuning.runtimePolicy(
            snapshot: snapshot,
            conditions: constrainedConditions
        )
        let normalBudget = LocalMLXRuntimeTuning.contentBudget(
            snapshot: snapshot,
            conditions: normalConditions,
            reasoningMode: .fast
        )
        let constrainedBudget = LocalMLXRuntimeTuning.contentBudget(
            snapshot: snapshot,
            conditions: constrainedConditions,
            reasoningMode: .fast
        )

        #expect(constrainedPolicy.idleUnloadDelay < normalPolicy.idleUnloadDelay)
        #expect(constrainedPolicy.memoryPolicy.cacheLimitBytes < normalPolicy.memoryPolicy.cacheLimitBytes)
        #expect(constrainedPolicy.memoryPolicy.memoryLimitBytes < normalPolicy.memoryPolicy.memoryLimitBytes)
        #expect(constrainedBudget.totalBudget < normalBudget.totalBudget)
        #expect(constrainedBudget.promptBudget < normalBudget.promptBudget)
    }

    @MainActor
    @Test("constrained runtime keeps the chosen local model but disables automatic local routing")
    func constrainedRuntimeKeepsChosenModel() {
        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([
            LocalTextModelID.qwen35_2B4Bit.rawValue,
            LocalTextModelID.qwen35_4B4Bit.rawValue,
        ])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)
        inference.setLocalRuntimeConditions(
            LocalRuntimeConditions(
                lowPowerModeEnabled: false,
                appActive: true,
                thermalState: .nominal
            )
        )

        #expect(inference.effectiveLocalTextModelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
        #expect(inference.canRouteToLocalMLX(contentLength: 4_000))

        inference.setLocalRuntimeConditions(
            LocalRuntimeConditions(
                lowPowerModeEnabled: true,
                appActive: false,
                thermalState: .serious
            )
        )

        #expect(inference.effectiveLocalTextModelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
        #expect(!inference.canRouteToLocalMLX(contentLength: 4_000))
    }

    @MainActor
    @Test("preferred local tier is used for simple local work")
    func preferredTierIsUsedForSimpleLocalWork() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let small = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_2B4Bit.rawValue))
        let balanced = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        for descriptor in [small, balanced] {
            try FileManager.default.createDirectory(
                at: paths.activeDirectory(for: descriptor),
                withIntermediateDirectories: true
            )
        }

        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .auto
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)
        inference.setInstalledLocalTextModelIDs([small.id, balanced.id])

        let runtime = RecordingLocalMLXRuntime()
        let localClient = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)
        let triage = TriageService(inference: inference, localLLMService: localClient)

        _ = try await triage.generateGeneral(
            prompt: "Summarize this in two sentences.",
            systemPrompt: "Be concise.",
            operation: .chatResponse(query: "Summarize this in two sentences."),
            contentLength: 31
        )

        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.modelID == inference.effectiveLocalTextModelID)
    }

    @MainActor
    @Test("plain debugging phrasing does not force local thinking mode")
    func debuggingCueDoesNotForceThinkingMode() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .auto
        inference.setInstalledLocalTextModelIDs([descriptor.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)
        let triage = TriageService(inference: inference, localLLMService: client)

        _ = try await triage.generateGeneral(
            prompt: "Debug this query path and tell me the most likely bug.",
            systemPrompt: "Be direct.",
            operation: .chatResponse(query: "Debug this query path and tell me the most likely bug."),
            contentLength: 54
        )

        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.reasoningMode == .fast)
    }

    @MainActor
    @Test("step by step phrasing alone does not force local thinking mode")
    func stepByStepCueDoesNotForceThinkingMode() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .auto
        inference.setInstalledLocalTextModelIDs([descriptor.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)
        let triage = TriageService(inference: inference, localLLMService: client)

        _ = try await triage.generateGeneral(
            prompt: "Explain step by step how this parser works.",
            systemPrompt: "Be clear.",
            operation: .chatResponse(query: "Explain step by step how this parser works."),
            contentLength: 43
        )

        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.reasoningMode == .fast)
    }

    @MainActor
    @Test("explicit reasoning request no longer opts the local runtime into thinking mode")
    func explicitReasoningCueStaysFast() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .auto
        inference.setInstalledLocalTextModelIDs([descriptor.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)
        let triage = TriageService(inference: inference, localLLMService: client)

        _ = try await triage.generateGeneral(
            prompt: "Show your reasoning and compare both implementations.",
            systemPrompt: "Be thorough.",
            operation: .chatResponse(query: "Show your reasoning and compare both implementations."),
            contentLength: 53
        )

        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.reasoningMode == .fast)
    }

    @MainActor
    @Test("configured thinking mode no longer rewrites local prompts or runtime mode")
    func configuredThinkingModeDoesNotRewriteLocalRequests() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .localOnly
        inference.setPreferredLocalTextModelID(descriptor.id)
        inference.setInstalledLocalTextModelIDs([descriptor.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)
        let triage = TriageService(inference: inference, localLLMService: client)

        _ = try await triage.generateGeneral(
            prompt: "Compare these two parser implementations and recommend one.",
            systemPrompt: "Be helpful.",
            operation: .chatResponse(query: "Compare these two parser implementations and recommend one."),
            contentLength: 58
        )

        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.reasoningMode == .fast)
        #expect(request.systemPrompt == "Be helpful.")
    }

    @MainActor
    @Test("preferred local tier stays stable across hard and short requests")
    func preferredTierStaysStableAcrossRequests() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let small = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_2B4Bit.rawValue))
        let balanced = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        let strong = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_9B4Bit.rawValue))
        for descriptor in [small, balanced, strong] {
            try FileManager.default.createDirectory(
                at: paths.activeDirectory(for: descriptor),
                withIntermediateDirectories: true
            )
        }

        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .auto
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_2B4Bit.rawValue)
        inference.setInstalledLocalTextModelIDs([small.id, balanced.id, strong.id])

        let runtime = RecordingLocalMLXRuntime()
        let localClient = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)
        let triage = TriageService(inference: inference, localLLMService: localClient)

        let hardPrompt = String(repeating: "Compare competing interpretations of this code path and identify failure modes. ", count: 80)
        _ = try await triage.generateGeneral(
            prompt: hardPrompt,
            systemPrompt: "Think through the tradeoffs before answering.",
            operation: .chatResponse(query: "Think step by step about competing code paths and failure modes."),
            contentLength: hardPrompt.count,
            localReasoningMode: .thinking
        )

        let firstRequest = try #require(await runtime.lastGenerateRequest)
        #expect(firstRequest.reasoningMode == .fast)

        _ = try await triage.generateGeneral(
            prompt: "Give me the short practical takeaway.",
            systemPrompt: "Be direct.",
            operation: .chatResponse(query: "Give me the short practical takeaway."),
            contentLength: 36
        )

        let secondRequest = try #require(await runtime.lastGenerateRequest)
        #expect(secondRequest.modelID == firstRequest.modelID)
    }

    @MainActor
    @Test("preferred installed tier stays active for local requests")
    func preferredInstalledTierStaysActive() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let small = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_2B4Bit.rawValue))
        let balanced = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        for descriptor in [small, balanced] {
            try FileManager.default.createDirectory(
                at: paths.activeDirectory(for: descriptor),
                withIntermediateDirectories: true
            )
        }

        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .auto
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)
        inference.setInstalledLocalTextModelIDs([small.id, balanced.id])

        let runtime = RecordingLocalMLXRuntime()
        let localClient = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)
        let triage = TriageService(inference: inference, localLLMService: localClient)

        _ = try await triage.generateGeneral(
            prompt: "Summarize this in two sentences.",
            systemPrompt: "Be concise.",
            operation: .chatResponse(query: "Summarize this in two sentences."),
            contentLength: 31
        )

        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.modelID == inference.effectiveLocalTextModelID)
    }

    @MainActor
    @Test("local client uses installed preferred local model")
    func usesInstalledPreferredModel() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = InferenceState()
        inference.setPreferredLocalTextModelID(descriptor.id)
        inference.setInstalledLocalTextModelIDs([descriptor.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)

        let output = try await client.generate(prompt: "Hello", systemPrompt: "System", maxTokens: 123)

        #expect(output == "local-generate")
        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.modelID == descriptor.id)
        #expect(request.modelDirectory == paths.activeDirectory(for: descriptor))
        #expect(request.prompt == "Hello")
        let systemPrompt = try #require(request.systemPrompt)
        #expect(systemPrompt == "System")
        #expect(request.maxTokens == 123)
    }

    @Test("local request preserves uncapped output when the caller leaves maxTokens at zero")
    func localRequestPreservesUncappedOutput() {
        let request = LocalMLXRequest(
            modelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/qwen"),
            prompt: "Explain the tradeoffs in detail.",
            systemPrompt: "Be thorough.",
            maxTokens: 0,
            reasoningMode: .fast
        )

        #expect(request.resolvedMaxTokens == nil)
    }

    @Test("thinking mode does not hard-cap long-form local output to 1024 tokens")
    func thinkingModeDoesNotHardCapLongFormOutput() {
        let request = LocalMLXRequest(
            modelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/qwen"),
            prompt: "Produce a detailed research analysis.",
            systemPrompt: "Think deeply and be comprehensive.",
            maxTokens: 6000,
            reasoningMode: .thinking
        )

        #expect(request.resolvedMaxTokens == 6000)
    }

    @MainActor
    @Test("local client requires the exact selected model instead of silently choosing another tier")
    func requiresExactSelectedModel() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let installed = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_2B4Bit.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: installed),
            withIntermediateDirectories: true
        )

        let inference = InferenceState()
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)
        inference.setInstalledLocalTextModelIDs([installed.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)

        await #expect(throws: LocalInferenceRoutingError.modelRequired) {
            _ = try await client.generate(prompt: "Hello", systemPrompt: nil, maxTokens: 64)
        }
        #expect(await runtime.lastGenerateRequest == nil)
    }

    @MainActor
    @Test("manual local selection does not silently fall back to a different installed tier")
    func manualSelectionRequiresExactInstalledTier() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let smallest = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_0_8B4Bit.rawValue))
        let smaller = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_2B4Bit.rawValue))
        for descriptor in [smallest, smaller] {
            try FileManager.default.createDirectory(
                at: paths.activeDirectory(for: descriptor),
                withIntermediateDirectories: true
            )
        }

        let inference = InferenceState()
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)
        inference.setInstalledLocalTextModelIDs([smallest.id, smaller.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)

        await #expect(throws: LocalInferenceRoutingError.modelRequired) {
            _ = try await client.generate(prompt: "Hello", systemPrompt: nil, maxTokens: 64)
        }
        #expect(await runtime.lastGenerateRequest == nil)
    }

    @MainActor
    @Test("local stream preserves the caller system prompt and keeps the runtime in fast mode")
    func streamPreservesSystemPromptAndKeepsFastMode() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([descriptor.id])

        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)

        let stream = client.stream(
            prompt: "Explain tides.",
            systemPrompt: "Think first, then answer.",
            maxTokens: 256,
            reasoningMode: .thinking
        )
        for try await _ in stream {
            break
        }

        let request = try #require(await runtime.lastStreamRequest)
        let systemPrompt = try #require(request.systemPrompt)
        #expect(systemPrompt == "Think first, then answer.")
        #expect(request.reasoningMode == .fast)
    }

    @MainActor
    @Test("local client errors when no usable local model is installed")
    func errorsWithoutInstalledModel() async {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let inference = InferenceState()
        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)

        await #expect(throws: LocalInferenceRoutingError.modelRequired) {
            try await client.generate(prompt: "Hello", systemPrompt: nil, maxTokens: 32)
        }
    }

    @MainActor
    @Test("local client snapshot uses the distinct local provider identity")
    func snapshotUsesDistinctLocalIdentity() {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let inference = InferenceState()
        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)

        #expect(client.configSnapshot().provider == .localMLX)
    }

    @MainActor
    private func makeService(
        appleAvailable: Bool,
        localInstalled: [String] = [],
        routingMode: LocalRoutingMode = .auto,
        localLLMService: (any LLMClientProtocol)? = nil
    ) -> TriageService {
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = appleAvailable
        inference.routingMode = routingMode
        inference.setInstalledLocalTextModelIDs(Set(localInstalled))
        if let firstInstalled = localInstalled.first {
            inference.setPreferredLocalTextModelID(firstInstalled)
        }

        return TriageService(
            inference: inference,
            localLLMService: localLLMService
        )
    }

    private func temporaryLocalModelPaths() -> LocalModelPaths {
        LocalModelPaths(
            rootDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
        )
    }
}

@Suite("LLMService Local Snapshots")
struct LLMServiceLocalSnapshotTests {
    @Test("enrichment snapshot keeps local mode fast")
    @MainActor func enrichmentSnapshotKeepsFastMode() {
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = true
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        let llm = LLMService(inference: inference)
        let snapshot = llm.enrichmentSnapshot()

        #expect(snapshot.provider == .localMLX)
        #expect(snapshot.model == LocalTextModelID.qwen35_4B4Bit.rawValue)
        #expect(snapshot.reasoningMode == .fast)
    }

    @Test("local snapshots use the selected tier instead of the last routed tier")
    @MainActor func localSnapshotsUseSelectedTier() {
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = true
        inference.setInstalledLocalTextModelIDs([
            LocalTextModelID.qwen35_2B4Bit.rawValue,
            LocalTextModelID.qwen35_4B4Bit.rawValue,
        ])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        let llm = LLMService(inference: inference)
        let snapshot = llm.configSnapshot()

        #expect(snapshot.provider == .localMLX)
        #expect(snapshot.model == LocalTextModelID.qwen35_4B4Bit.rawValue)
    }

    @Test("local snapshots stay in fast mode")
    @MainActor func localSnapshotsStayFast() {
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = true
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        let llm = LLMService(inference: inference)
        let snapshot = llm.configSnapshot()

        #expect(snapshot.provider == .localMLX)
        #expect(snapshot.reasoningMode == .fast)
    }
}

private actor RecordingLocalMLXRuntime: LocalMLXRuntime {
    var lastGenerateRequest: LocalMLXRequest?
    var lastStreamRequest: LocalMLXRequest?

    func generate(request: LocalMLXRequest) async throws -> String {
        lastGenerateRequest = request
        return "local-generate"
    }

    func stream(request: LocalMLXRequest) async -> AsyncThrowingStream<String, Error> {
        lastStreamRequest = request
        return AsyncThrowingStream { continuation in
            continuation.yield("local")
            continuation.finish()
        }
    }

    func unload() async {}
}
