import Testing
@testable import Epistemos

private let isolatedInferenceDefaultsKeys = [
    "epistemos.localRoutingMode",
    "epistemos.preferredLocalTextModelID",
]

@MainActor
private func makeIsolatedInferenceState() -> InferenceState {
    let defaults = UserDefaults.standard
    let savedValues = isolatedInferenceDefaultsKeys.reduce(into: [String: Any?]()) { partialResult, key in
        partialResult[key] = defaults.object(forKey: key)
        defaults.removeObject(forKey: key)
    }
    defer {
        for key in isolatedInferenceDefaultsKeys {
            if let value = savedValues[key] ?? nil {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
    return InferenceState()
}

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
        #expect(LLMProviderType.allCases == [.appleIntelligence, .localMLX, .openAI, .anthropic, .google])
    }

    @Test("local routing errors no longer mention switch routing modes")
    func localRoutingErrorsUseCurrentArchitectureCopy() {
        #expect(LocalInferenceRoutingError.modelRequired.errorDescription?.contains("switch routing modes") == false)
        #expect(LocalInferenceRoutingError.modelRequired.errorDescription?.contains("installed local model") == false)
    }

    @Test("chat model selection preserves cloud model raw values")
    func chatModelSelectionPreservesCloudModelRawValues() {
        let selection = ChatModelSelection(rawValue: "cloud:openai:gpt-5.4")
        #expect(selection == .cloud(.openAIGPT54))
        #expect(selection?.rawValue == "cloud:openai:gpt-5.4")
    }

    @Test("legacy cloud model selections migrate to supported cloud models")
    func legacyCloudModelSelectionsMigrateForward() {
        #expect(ChatModelSelection(rawValue: "cloud:openai:gpt-5.3") == .cloud(.openAIGPT54))
        #expect(ChatModelSelection(rawValue: "cloud:anthropic:claude-sonnet-4-6") == .cloud(.anthropicClaudeSonnet4))
        #expect(ChatModelSelection(rawValue: "cloud:google:gemini-1.5-pro") == .cloud(.googleGemini25Pro))
    }

    @Test("cloud catalog still covers the flagship provider families")
    func cloudCatalogStillCoversFlagshipFamilies() {
        #expect(CloudTextModelID.models(for: .openAI).contains(.openAIGPT54))
        #expect(CloudTextModelID.models(for: .anthropic).contains(.anthropicClaudeOpus41))
        #expect(CloudTextModelID.models(for: .anthropic).contains(.anthropicClaudeSonnet4))
        #expect(CloudTextModelID.models(for: .anthropic).contains(.anthropicClaudeHaiku35))
        #expect(CloudTextModelID.models(for: .google).contains(.googleGemini31ProPreview))
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
            context: makeContext(
                appleAvailable: true,
                preferredChatModelSelection: .appleIntelligence
            )
        )

        #expect(decision.selectedRoute == .appleIntelligence)
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

    @Test("explicit deep reasoning request keeps the local response mode in thinking")
    func explicitThinkingKeepsLocalThinkingMode() {
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
        #expect(decision.localSelection?.reasoningMode == .thinking)
        #expect(!decision.reasonCodes.contains(.explicitThinkingRequested))
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
            context: makeContext(
                appleAvailable: true,
                preferredChatModelSelection: .appleIntelligence
            )
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

    @Test("light Apple requests are not kicked local solely for crossing the old content cliff")
    func lightAppleRequestsDoNotTripOldContentCliff() {
        let engine = InferencePolicyEngine()
        let decision = engine.decide(
            profile: InferenceRequestProfile(
                surface: .mainChat,
                intent: .simpleAsk,
                contentLength: 6_100,
                promptLength: 48,
                contextBlockCount: 1,
                estimatedTokenLoad: 180,
                baseComplexity: 0.10,
                queryComplexity: 0.02,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            ),
            context: makeContext(
                appleAvailable: true,
                preferredChatModelSelection: .appleIntelligence
            )
        )

        #expect(decision.selectedRoute == .appleIntelligence)
    }

    private func makeContext(
        routingMode: LocalRoutingMode = .auto,
        appleAvailable: Bool,
        preferredChatModelSelection: ChatModelSelection = .localQwen(LocalTextModelID.qwen35_4B4Bit.rawValue),
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
            preferredChatModelSelection: preferredChatModelSelection,
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

}

@MainActor
final class TriageIntegrationMockCloudLLMClient: LLMClientProtocol {
    var generateCalls: [(prompt: String, systemPrompt: String?, maxTokens: Int)] = []
    var streamCalls: [(prompt: String, systemPrompt: String?, maxTokens: Int)] = []

    var generateResult: Result<String, Error> = .success("mock-cloud-generate")
    var streamTokens: [String] = ["mock-cloud-stream"]

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
        return AsyncThrowingStream { continuation in
            Task {
                for token in tokens {
                    continuation.yield(token)
                }
                continuation.finish()
            }
        }
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(provider: .openAI, model: CloudTextModelID.openAIGPT54.vendorModelID, reasoningMode: .fast)
    }
}

@MainActor
final class RecordingConfigurableLocalLLMClient: LocalConfigurableLLMClient {
    struct GenerateRequest: Equatable {
        let prompt: String
        let systemPrompt: String?
        let maxTokens: Int
        let reasoningMode: LocalReasoningMode
        let modelID: String?
    }

    var generateRequests: [GenerateRequest] = []
    var generateResult = "mock-generate"

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        try await generate(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: .fast,
            modelID: nil
        )
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        stream(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: maxTokens,
            reasoningMode: .fast,
            modelID: nil
        )
    }

    func generate(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?
    ) async throws -> String {
        generateRequests.append(
            GenerateRequest(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens,
                reasoningMode: reasoningMode,
                modelID: modelID
            )
        )
        return generateResult
    }

    func stream(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int,
        reasoningMode: LocalReasoningMode,
        modelID: String?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "ok")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(provider: .localMLX, model: "", reasoningMode: .fast)
    }
}

@Suite("TriageService Integration", .serialized)
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
        #expect(triage.triage(operation: .expand, contentLength: 4_000) == .localMLX)
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
        let systemPrompt = try #require(llm.generateCalls[0].systemPrompt)
        #expect(systemPrompt.contains("local Epistemos assistant running on-device"))
        #expect(systemPrompt.contains("System A"))
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

    @Test("local generate strips reasoning artifacts before returning assistant text")
    @MainActor func localGenerateStripsReasoningArtifacts() async throws {
        let llm = TriageIntegrationMockLLMClient()
        llm.generateResult = .success("""
        <think>I should inspect the framing.</think>

        Final Answer:
        Use the more constrained interpretation unless the note context defines the term explicitly.
        """)
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [LocalTextModelID.qwen35_4B4Bit.rawValue],
            routingMode: .localOnly,
            localLLMService: llm
        )

        let output = try await triage.generateGeneral(
            prompt: "Explain the phrase.",
            systemPrompt: nil,
            operation: .chatResponse(query: "Explain the phrase."),
            contentLength: 19
        )

        #expect(
            output == "Use the more constrained interpretation unless the note context defines the term explicitly."
        )
    }

    @Test("local stream suppresses thinking prelude and emits the final answer only")
    @MainActor func localStreamSuppressesThinkingPrelude() async {
        let llm = TriageIntegrationMockLLMClient()
        llm.streamTokens = [
            "Thinking Process:\n",
            "I should compare the historical and modern senses first.\n\n",
            "Final Answer:\n",
            "It usually refers to the modern US-led imperial order rather than the British Empire itself.",
        ]
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [LocalTextModelID.qwen35_4B4Bit.rawValue],
            routingMode: .localOnly,
            localLLMService: llm
        )

        let stream = triage.streamGeneral(
            prompt: "Explain the phrase.",
            systemPrompt: nil,
            operation: .chatResponse(query: "Explain the phrase."),
            contentLength: 19
        )
        let outcome = await LocalRuntimeSmokeSupport.collect(stream)

        #expect(
            outcome.tokens.joined()
                == "It usually refers to the modern US-led imperial order rather than the British Empire itself."
        )
        #expect(outcome.error == nil)
        let systemPrompt = try? #require(llm.streamCalls.first?.systemPrompt)
        #expect(systemPrompt?.contains("local Epistemos assistant running on-device") == true)
    }

    @Test("local path injects a baseline qwen system prompt when none is provided")
    @MainActor func localPathInjectsBaselineQwenSystemPrompt() async throws {
        let llm = TriageIntegrationMockLLMClient()
        llm.generateResult = .success("local-response")
        let triage = makeService(
            appleAvailable: false,
            localInstalled: [LocalTextModelID.qwen35_4B4Bit.rawValue],
            routingMode: .localOnly,
            localLLMService: llm
        )

        _ = try await triage.generateGeneral(
            prompt: "What tools do you have?",
            systemPrompt: nil,
            operation: .chatResponse(query: "What tools do you have?"),
            contentLength: 24
        )

        let systemPrompt = try #require(llm.generateCalls.first?.systemPrompt)
        #expect(
            systemPrompt.localizedCaseInsensitiveContains(
                "do not claim to have browsing, external tool use, research mode"
            )
        )
        #expect(systemPrompt.contains("local Epistemos assistant running on-device"))
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

    @Test("triage refreshes local model state before local-only requests")
    @MainActor func triageRefreshesLocalModelStateBeforeLocalOnlyRequests() async throws {
        let llm = TriageIntegrationMockLLMClient()
        llm.generateResult = .success("local-response")
        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        let triage = TriageService(
            inference: inference,
            localLLMService: llm,
            prepareForRouting: {
                inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
            }
        )

        let result = try await triage.generateGeneral(
            prompt: "Summarize this note.",
            operation: .chatResponse(query: "Summarize this note."),
            contentLength: 64
        )

        #expect(result == "local-response")
        #expect(llm.generateCalls.count == 1)
    }

    @Test("explicit cloud selection bypasses Apple and local triage for general generation")
    @MainActor func explicitCloudSelectionBypassesAppleAndLocal() async throws {
        let cloud = TriageIntegrationMockCloudLLMClient()
        cloud.generateResult = .success("cloud answer")

        let triage = makeService(
            appleAvailable: true,
            localInstalled: [LocalTextModelID.qwen35_4B4Bit.rawValue],
            selectedChatModel: .cloud(.openAIGPT54),
            cloudLLMService: cloud
        )

        let result = try await triage.generateGeneral(
            prompt: "Use the cloud model",
            systemPrompt: "System",
            operation: .chatResponse(query: "Use the cloud model"),
            contentLength: 19
        )

        #expect(result == "cloud answer")
        #expect(cloud.generateCalls.count == 1)
        #expect(triage.lastDecision == .cloud)
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
        let inference = makeIsolatedInferenceState()
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

    @Test("preferred local tier is used for simple local work")
    @MainActor func preferredTierIsUsedForSimpleLocalWork() async throws {
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

        let inference = makeIsolatedInferenceState()
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

        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .auto
        inference.setPreferredLocalTextModelID(descriptor.id)
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

        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .auto
        inference.setPreferredLocalTextModelID(descriptor.id)
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
    @Test("explicit reasoning phrasing alone does not force local thinking mode")
    func explicitReasoningCueStaysFast() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = false
        inference.routingMode = .auto
        inference.setPreferredLocalTextModelID(descriptor.id)
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
    @Test("configured thinking mode preserves the caller system prompt and runtime mode")
    func configuredThinkingModePreservesLocalThinkingRequests() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = makeIsolatedInferenceState()
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
            contentLength: 58,
            localReasoningMode: .thinking
        )

        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.reasoningMode == .thinking)
        let systemPrompt = try #require(request.systemPrompt)
        #expect(systemPrompt.contains("local Epistemos assistant running on-device"))
        #expect(systemPrompt.contains("Be helpful."))
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

        let inference = makeIsolatedInferenceState()
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
        #expect(firstRequest.reasoningMode == .thinking)

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

        let inference = makeIsolatedInferenceState()
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

        let inference = makeIsolatedInferenceState()
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

    @MainActor
    @Test("local client prepares residency before generating with MLX")
    func localClientPreparesResidencyBeforeGenerating() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = makeIsolatedInferenceState()
        inference.setPreferredLocalTextModelID(descriptor.id)
        inference.setInstalledLocalTextModelIDs([descriptor.id])

        let runtime = RecordingLocalMLXRuntime()
        let events = LocalRuntimeEventRecorder()
        let client = LocalMLXClient(
            runtime: runtime,
            inference: inference,
            paths: paths,
            prepareForRequest: {
                await events.record("prepare-local")
            }
        )

        _ = try await client.generate(prompt: "Hello", systemPrompt: nil, maxTokens: 64)

        let request = try #require(await runtime.lastGenerateRequest)
        #expect(request.modelID == descriptor.id)
        #expect(await events.snapshot() == ["prepare-local"])
    }

    @Test("local mlx request gate serializes overlapping turns")
    func localMLXRequestGateSerializesOverlappingTurns() async {
        let gate = LocalMLXRequestGate()
        let events = LocalRuntimeEventRecorder()

        async let first: Void = {
            await gate.acquire()
            await events.record("first-acquired")
            try? await Task.sleep(for: .milliseconds(40))
            await events.record("first-releasing")
            await gate.release()
        }()

        async let second: Void = {
            try? await Task.sleep(for: .milliseconds(5))
            await gate.acquire()
            await events.record("second-acquired")
            await gate.release()
        }()

        _ = await (first, second)
        #expect(await events.snapshot() == [
            "first-acquired",
            "first-releasing",
            "second-acquired",
        ])
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

    @Test("local qwen requests map template thinking mode from the request reasoning mode")
    func localQwenRequestsMapTemplateThinkingMode() {
        let request = LocalMLXRequest(
            modelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/qwen"),
            prompt: "Answer directly.",
            systemPrompt: nil,
            maxTokens: 256,
            reasoningMode: .thinking
        )

        #expect(request.chatTemplateContext?["enable_thinking"] == true)
    }

    @Test("non-qwen local requests do not inject template thinking flags")
    func nonQwenLocalRequestsDoNotInjectTemplateThinkingFlags() {
        let request = LocalMLXRequest(
            modelID: LocalTextModelID.smolLM3_3B4Bit.rawValue,
            modelDirectory: URL(fileURLWithPath: "/tmp/smollm3"),
            prompt: "Answer directly.",
            systemPrompt: nil,
            maxTokens: 256,
            reasoningMode: .thinking
        )

        #expect(request.chatTemplateContext == nil)
    }

    @Test("cancelled local stream stop keeps completed output when text was produced")
    func cancelledLocalStreamStopKeepsCompletedOutput() {
        #expect(
            MLXInferenceService.shouldTreatCancelledStopAsCompletion(
                outputCharacterCount: 128,
                chunkCount: 6
            )
        )
    }

    @Test("cancelled local stream stop still cancels when no output was produced")
    func cancelledLocalStreamStopWithoutOutputStillCancels() {
        #expect(
            !MLXInferenceService.shouldTreatCancelledStopAsCompletion(
                outputCharacterCount: 0,
                chunkCount: 0
            )
        )
    }

    @Test("cancelled completed local runs profile as stop")
    func cancelledCompletedLocalRunsProfileAsStop() {
        #expect(
            MLXInferenceService.normalizedStopReason(
                .cancelled,
                outputCharacterCount: 128,
                chunkCount: 6
            ) == .stop
        )
    }

    @Test("empty cancelled local runs remain cancelled")
    func emptyCancelledLocalRunsRemainCancelled() {
        #expect(
            MLXInferenceService.normalizedStopReason(
                .cancelled,
                outputCharacterCount: 0,
                chunkCount: 0
            ) == .cancelled
        )
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

        let inference = makeIsolatedInferenceState()
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

        let inference = makeIsolatedInferenceState()
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
    @Test("local stream preserves the caller system prompt and keeps the requested runtime mode")
    func streamPreservesSystemPromptAndReasoningMode() async throws {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let descriptor = try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        try FileManager.default.createDirectory(
            at: paths.activeDirectory(for: descriptor),
            withIntermediateDirectories: true
        )

        let inference = makeIsolatedInferenceState()
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
        #expect(request.reasoningMode == .thinking)
    }

    @MainActor
    @Test("local client errors when no usable local model is installed")
    func errorsWithoutInstalledModel() async {
        let paths = temporaryLocalModelPaths()
        defer { try? FileManager.default.removeItem(at: paths.rootDirectory) }

        let inference = makeIsolatedInferenceState()
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

        let inference = makeIsolatedInferenceState()
        let runtime = RecordingLocalMLXRuntime()
        let client = LocalMLXClient(runtime: runtime, inference: inference, paths: paths)

        #expect(client.configSnapshot().provider == .localMLX)
    }

    @MainActor
    private func makeService(
        appleAvailable: Bool,
        localInstalled: [String] = [],
        routingMode: LocalRoutingMode = .auto,
        localLLMService: (any LLMClientProtocol)? = nil,
        selectedChatModel: ChatModelSelection? = nil,
        cloudLLMService: (any LLMClientProtocol)? = nil
    ) -> TriageService {
        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = appleAvailable
        inference.routingMode = routingMode
        inference.setInstalledLocalTextModelIDs(Set(localInstalled))
        if let firstInstalled = localInstalled.first {
            inference.setPreferredLocalTextModelID(firstInstalled)
        }
        if let selectedChatModel {
            inference.setPreferredChatModelSelection(selectedChatModel)
        }

        return TriageService(
            inference: inference,
            localLLMService: localLLMService,
            cloudLLMService: cloudLLMService
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
    @Test("config snapshot keeps local mode fast")
    @MainActor func configSnapshotKeepsFastMode() {
        let inference = makeIsolatedInferenceState()
        inference.appleIntelligenceAvailable = true
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        let llm = LLMService(inference: inference)
        let snapshot = llm.configSnapshot()

        #expect(snapshot.provider == .localMLX)
        #expect(snapshot.model == LocalTextModelID.qwen35_4B4Bit.rawValue)
        #expect(snapshot.reasoningMode == .fast)
    }

    @Test("local snapshots use the selected tier instead of the last routed tier")
    @MainActor func localSnapshotsUseSelectedTier() {
        let inference = makeIsolatedInferenceState()
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
        let inference = makeIsolatedInferenceState()
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
    var unloadCount = 0

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

    func unload() async {
        unloadCount += 1
    }
}

private actor LocalRuntimeEventRecorder {
    private var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }

    func snapshot() -> [String] {
        events
    }
}
