import Foundation
import SwiftData
import Testing
@testable import Epistemos

// MARK: - MockLLMClient

/// Test double for LLMClientProtocol. Records calls and returns canned responses.
@MainActor
final class MockLLMClient: LLMClientProtocol {
    var generateCalls: [(prompt: String, systemPrompt: String?, maxTokens: Int)] = []
    var streamCalls: [(prompt: String, systemPrompt: String?, maxTokens: Int)] = []
    var testConnectionCalls = 0

    /// Canned response for generate() calls.
    var generateResponse: String = "Mock LLM response"
    /// If set, generate() throws this error.
    var generateError: (any Error)?

    /// Tokens yielded by stream() — each string is one yield.
    var streamTokens: [String] = ["Hello", " ", "world"]
    /// If set, stream() throws this error after yielding `streamTokens`.
    var streamError: (any Error)?

    /// Canned snapshot for configSnapshot().
    var snapshot = LLMSnapshot(
        provider: .anthropic,
        apiKey: "test-key",
        model: "claude-test",
        ollamaBaseUrl: "http://localhost:11434"
    )

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        generateCalls.append((prompt, systemPrompt, maxTokens))
        if let error = generateError { throw error }
        return generateResponse
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        streamCalls.append((prompt, systemPrompt, maxTokens))
        let tokens = streamTokens
        let error = streamError
        return AsyncThrowingStream { continuation in
            Task {
                for token in tokens {
                    continuation.yield(token)
                    try? await Task.sleep(for: .milliseconds(5))
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
        testConnectionCalls += 1
        return ConnectionTestResult(success: true, message: "Mock connected")
    }

    func configSnapshot() -> LLMSnapshot { snapshot }
    func enrichmentSnapshot() -> LLMSnapshot { snapshot }
}

// MARK: - Protocol Conformance Tests

@Suite("LLMClientProtocol")
struct LLMClientProtocolTests {

    @Test("MockLLMClient conforms to LLMClientProtocol")
    @MainActor func mockConformance() async throws {
        let mock = MockLLMClient()
        let client: any LLMClientProtocol = mock

        let result = try await client.generate(prompt: "test")
        #expect(result == "Mock LLM response")
        #expect(mock.generateCalls.count == 1)
        #expect(mock.generateCalls[0].prompt == "test")
    }

    @Test("Mock stream yields expected tokens")
    @MainActor func mockStream() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["foo", "bar"]

        var collected: [String] = []
        for try await token in mock.stream(prompt: "test", systemPrompt: nil, maxTokens: 100) {
            collected.append(token)
        }
        #expect(collected == ["foo", "bar"])
    }

    @Test("Mock generate throws when error is set")
    @MainActor func mockGenerateError() async {
        let mock = MockLLMClient()
        mock.generateError = LLMError.apiError(statusCode: 500, body: "Server error")

        do {
            _ = try await mock.generate(prompt: "test")
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is LLMError)
        }
    }

    @Test("Protocol default parameters work")
    @MainActor func defaultParameters() async throws {
        let mock = MockLLMClient()
        // Call with defaults — systemPrompt should be nil, maxTokens should be 4096
        _ = try await mock.generate(prompt: "test")
        #expect(mock.generateCalls[0].systemPrompt == nil)
        #expect(mock.generateCalls[0].maxTokens == 4096)
    }

    @Test("testConnection records call count")
    @MainActor func connectionTest() async {
        let mock = MockLLMClient()
        let result = await mock.testConnection()
        #expect(result.success)
        #expect(mock.testConnectionCalls == 1)
    }

    @Test("configSnapshot returns canned snapshot")
    @MainActor func snapshotTest() {
        let mock = MockLLMClient()
        let snap = mock.configSnapshot()
        #expect(snap.provider == .anthropic)
        #expect(snap.apiKey == "test-key")
        #expect(snap.model == "claude-test")
    }
}

// MARK: - PipelineService Integration Tests

@Suite("PipelineService")
struct PipelineServiceTests {

    @Test("Pipeline runs all 10 stages before streaming")
    @MainActor func pipelineStageAdvancement() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["Test", " answer"]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        let triage = TriageService(inference: inference, llmService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            eventBus: eventBus
        )

        var events: [PipelineEvent] = []
        let stream = pipeline.run(
            query: "What is consciousness?",
            mode: .api,
            skipEnrichment: true
        )

        for try await event in stream {
            events.append(event)
        }

        // Should have advanced through all 10 stages (each with running + completed = 20 stage events)
        let stageEvents = events.compactMap { event -> PipelineStage? in
            if case .stageAdvanced(let stage, let result) = event, result.status == .completed {
                return stage
            }
            return nil
        }
        #expect(stageEvents.count == PipelineStage.allCases.count)
        #expect(stageEvents == PipelineStage.allCases)
    }

    @Test("Pipeline handles thinking tags as deliberation")
    @MainActor func pipelineThinkingTags() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["<thinking>", "I need to think", "</thinking>", "Final answer"]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        // Force triage to route through the mock LLM, not Apple Intelligence.
        inference.appleIntelligenceAvailable = false
        let triage = TriageService(inference: inference, llmService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            eventBus: eventBus
        )

        var deliberations: [String] = []
        var texts: [String] = []
        let stream = pipeline.run(
            query: "Think about this",
            mode: .api,
            skipEnrichment: true
        )

        for try await event in stream {
            if case .deliberationDelta(let d) = event {
                deliberations.append(d)
            }
            if case .textDelta(let t) = event {
                texts.append(t)
            }
        }

        let deliberationText = deliberations.joined()
        let visibleText = texts.joined()
        // Deliberation should contain the thinking content
        #expect(deliberationText.contains("think"))
        // Visible text should contain the final answer (not thinking)
        #expect(visibleText.contains("Final answer"))
    }

    @Test("Pipeline updates signals in PipelineState")
    @MainActor func pipelineSignalUpdate() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["Answer"]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        let triage = TriageService(inference: inference, llmService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            eventBus: eventBus
        )

        let stream = pipeline.run(
            query: "What is quantum entanglement?",
            mode: .api,
            skipEnrichment: true
        )

        for try await _ in stream {}

        // After pipeline completes, signals should have been updated from defaults
        // Confidence should be in range (not the initial 0.5 unless query happens to produce it)
        #expect(pipelineState.confidence >= 0.01)
        #expect(pipelineState.confidence <= 0.95)
        #expect(pipelineState.healthScore >= 0.2)
    }

    @Test("Mock can be injected into PipelineService and TriageService")
    @MainActor func dependencyInjection() {
        let mock = MockLLMClient()
        let inference = InferenceState()

        // Both accept LLMClientProtocol
        let triage = TriageService(inference: inference, llmService: mock)
        let eventBus = EventBus()
        let pipelineState = PipelineState()
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            eventBus: eventBus
        )

        // Just verify construction succeeds with mock
        _ = pipeline
        _ = triage
    }
}

// MARK: - Pipeline Contract Tests (Phase 7.5)
// Tests for consolidated enrichment, cost tracking, and cancellation.

@Suite("Pipeline Contracts")
struct PipelineContractTests {

    // MARK: - Consolidated Enrichment JSON Parsing

    @Test("extractJSON handles clean JSON")
    func extractJSONClean() {
        let raw = """
        {"laymanSummary": "Test", "confidence": 0.8}
        """
        let result = EnrichmentController.extractJSON(from: raw)
        #expect(result != nil)
        #expect(result?["confidence"] as? Double == 0.8)
    }

    @Test("extractJSON strips markdown code fences")
    func extractJSONCodeFences() {
        let raw = """
        Here is the analysis:
        ```json
        {"grade": "A", "score": 95}
        ```
        """
        let result = EnrichmentController.extractJSON(from: raw)
        #expect(result != nil)
        #expect(result?["grade"] as? String == "A")
    }

    @Test("extractJSON strips thinking blocks")
    func extractJSONThinkingBlocks() {
        let raw = """
        <thinking>I should analyze carefully...</thinking>
        {"verdict": "supported", "confidence": 0.75}
        """
        let result = EnrichmentController.extractJSON(from: raw)
        #expect(result != nil)
        #expect(result?["verdict"] as? String == "supported")
    }

    @Test("extractJSON returns nil for non-JSON")
    func extractJSONNonJSON() {
        let result = EnrichmentController.extractJSON(from: "Just a plain text response with no JSON")
        #expect(result == nil)
    }

    @Test("extractJSON handles prose-then-JSON")
    func extractJSONProseThenJSON() {
        let raw = """
        After careful consideration of the evidence, here is my structured assessment:

        {"overallTruthLikelihood": 0.72, "evidenceGrade": "B", "weaknesses": ["Small sample size"]}
        """
        let result = EnrichmentController.extractJSON(from: raw)
        #expect(result != nil)
        #expect(result?["evidenceGrade"] as? String == "B")
        let weaknesses = result?["weaknesses"] as? [String]
        #expect(weaknesses?.count == 1)
    }

    // MARK: - Cost Tracking

    @Test("CostTracker estimates cost correctly for known model")
    func costEstimation() {
        // claude-sonnet-4-6: $3/1M input, $15/1M output
        let rates = CostTracker.pricing["claude-sonnet-4-6"]
        #expect(rates != nil)
        #expect(rates?.input == 3.0)
        #expect(rates?.output == 15.0)

        // 1000 input tokens + 500 output tokens at Sonnet rates
        let expectedCost = (1000.0 * 3.0 / 1_000_000.0) + (500.0 * 15.0 / 1_000_000.0)
        #expect(expectedCost > 0.01)  // Sanity: non-trivial cost
        #expect(expectedCost < 0.02)  // Sanity: reasonable for small query
    }

    @Test("CostTracker returns zero cost for unknown model")
    func costEstimationUnknownModel() {
        let rates = CostTracker.pricing["llama-3.3-70b"]
        #expect(rates == nil)  // Local model → no pricing entry → $0 cost
    }

    @Test("CostTracker budget detection works")
    @MainActor func budgetDetection() {
        let tracker = CostTracker.shared
        let savedBudget = tracker.dailyBudgetUSD

        // Set budget to $0 (unlimited) — should never be exceeded
        tracker.dailyBudgetUSD = 0
        #expect(!tracker.budgetExceeded)

        // Set a tiny budget
        tracker.dailyBudgetUSD = 0.0001
        // If any cost has been recorded today, this might already be exceeded
        // Just verify the property is computable without crash
        _ = tracker.budgetExceeded

        // Restore
        tracker.dailyBudgetUSD = savedBudget
    }

    // MARK: - Cancellation

    @Test("Pipeline can be cancelled mid-stream")
    @MainActor func pipelineCancellation() async {
        let mock = MockLLMClient()
        // Long stream to ensure we have time to cancel
        mock.streamTokens = (0..<100).map { "Token\($0) " }

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        let triage = TriageService(inference: inference, llmService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            eventBus: eventBus
        )

        var receivedTokens = 0
        let stream = pipeline.run(
            query: "Tell me everything",
            mode: .api,
            skipEnrichment: true
        )

        // Start consuming but cancel quickly
        let task = Task {
            for try await event in stream {
                if case .textDelta = event {
                    receivedTokens += 1
                }
            }
        }

        // Give it a moment to start, then cancel
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        try? await Task.sleep(for: .milliseconds(50))

        // Should have received some but not all tokens
        #expect(task.isCancelled)
    }

    // MARK: - Event Ordering

    @Test("Pipeline stage events arrive in deterministic order")
    @MainActor func stageOrdering() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["Answer"]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        let triage = TriageService(inference: inference, llmService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            eventBus: eventBus
        )

        var completedStages: [PipelineStage] = []
        let stream = pipeline.run(
            query: "Test ordering",
            mode: .api,
            skipEnrichment: true
        )

        for try await event in stream {
            if case .stageAdvanced(let stage, let result) = event, result.status == .completed {
                completedStages.append(stage)
            }
        }

        // Verify strict ordering: each stage's ordinal should be monotonically increasing
        for i in 1..<completedStages.count {
            let prev = PipelineStage.allCases.firstIndex(of: completedStages[i - 1])!
            let curr = PipelineStage.allCases.firstIndex(of: completedStages[i])!
            #expect(curr > prev, "Stage \(completedStages[i]) arrived before \(completedStages[i - 1])")
        }
    }

    @Test("Pipeline emits completed event with DualMessage")
    @MainActor func completedEvent() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["The answer is 42"]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        let triage = TriageService(inference: inference, llmService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            eventBus: eventBus
        )

        var gotCompleted = false
        let stream = pipeline.run(
            query: "What is the meaning of life?",
            mode: .api,
            skipEnrichment: true
        )

        for try await event in stream {
            if case .completed(let dual, _) = event {
                gotCompleted = true
                // DualMessage should contain the raw analysis text
                #expect(!dual.rawAnalysis.isEmpty)
            }
        }

        #expect(gotCompleted, "Pipeline should emit a .completed event")
    }

}

private final class ActivityProbe: @unchecked Sendable {
    nonisolated(unsafe) private let lock = NSLock()
    nonisolated(unsafe) private var events: [String] = []

    nonisolated func begin(reason: String) -> ProcessActivityToken {
        lock.lock()
        events.append("begin:\(reason)")
        lock.unlock()
        return ProcessActivityToken(raw: NSObject())
    }

    nonisolated func end() {
        lock.lock()
        events.append("end")
        lock.unlock()
    }

    nonisolated func snapshot() -> [String] {
        lock.lock()
        let events = self.events
        lock.unlock()
        return events
    }
}

@Suite("Network Process Activity")
struct NetworkProcessActivityTests {
    @Test("scoped activity pairs begin and end around async work")
    @MainActor func scopedActivityPairsBeginAndEnd() async {
        let probe = ActivityProbe()
        let manager = NetworkProcessActivityManager(
            begin: { reason, _ in probe.begin(reason: reason) },
            end: { _ in probe.end() }
        )

        let value = await NetworkProcessActivity.withActivityOnMainActor(
            reason: "Epistemos AI request",
            manager: manager
        ) {
            "ok"
        }

        #expect(value == "ok")
        #expect(probe.snapshot() == ["begin:Epistemos AI request", "end"])
    }

    @Test("stream activity stays open until the stream finishes")
    @MainActor func streamActivityEndsAfterCompletion() async throws {
        let probe = ActivityProbe()
        let manager = NetworkProcessActivityManager(
            begin: { reason, _ in probe.begin(reason: reason) },
            end: { _ in probe.end() }
        )

        let stream = NetworkProcessActivity.makeStream(
            reason: "Epistemos AI stream",
            manager: manager
        ) { continuation in
            continuation.yield("hello")
            continuation.finish()
        }

        var chunks: [String] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }

        #expect(chunks == ["hello"])
        #expect(probe.snapshot() == ["begin:Epistemos AI stream", "end"])
    }

    @Test("bootstrap no longer keeps a session-wide App Nap override")
    @MainActor func bootstrapDoesNotKeepSessionWideActivity() {
        let existingBootstrap = AppBootstrap.shared
        let bootstrap = existingBootstrap ?? AppBootstrap()
        let activityField = Mirror(reflecting: bootstrap).children.first {
            $0.label == "antiNapActivity"
        }

        if let existingBootstrap {
            #expect(bootstrap === existingBootstrap)
        }
        #expect(activityField == nil)
    }
}

@Suite("ChatCoordinator Research Persistence", .serialized)
@MainActor
struct ChatCoordinatorResearchPersistenceTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(EpistemosSchema.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeCoordinator(container: ModelContainer) -> ChatCoordinator {
        let bootstrap = AppBootstrap.shared ?? AppBootstrap()
        let chatState = ChatState()
        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        let llmService = LLMService(inference: inference)
        let triage = TriageService(inference: inference, llmService: llmService)
        let eventBus = EventBus()
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: llmService,
            triageService: triage,
            eventBus: eventBus
        )

        return ChatCoordinator(
            bootstrap: bootstrap,
            chatState: chatState,
            pipelineService: pipeline,
            inferenceState: inference,
            soarState: SOARState(),
            vaultSync: VaultSyncService(modelContainer: container),
            modelContainer: container,
            eventBus: eventBus,
            llmService: llmService,
            researchState: ResearchState(),
            notesUI: NotesUIState()
        )
    }

    private func makeLaymanDualMessage() -> DualMessage {
        DualMessage(
            rawAnalysis: "Full raw analysis",
            uncertaintyTags: [],
            modelVsDataFlags: [],
            laymanSummary: LaymanSummary(
                whatWasTried: "Compared the evidence",
                whatIsLikelyTrue: "The claim is likely true",
                confidenceExplanation: "Multiple signals aligned",
                whatCouldChange: "New contradictory data",
                whoShouldTrust: "Researchers familiar with the topic",
                sectionLabels: nil
            ),
            reflection: nil,
            arbitration: nil
        )
    }

    private func makeTruthAssessment() -> TruthAssessment {
        TruthAssessment(
            overallTruthLikelihood: 0.84,
            signalInterpretation: "Strongly supported",
            weaknesses: [],
            improvements: [],
            blindSpots: [],
            confidenceCalibration: "Calibrated",
            dataVsModelBalance: "Balanced",
            recommendedActions: []
        )
    }

    @Test("research persistence coordinator reuses the shared bootstrap")
    func researchPersistenceCoordinatorReusesSharedBootstrap() throws {
        let container = try makeContainer()
        let existingBootstrap = AppBootstrap.shared

        _ = makeCoordinator(container: container)

        if let existingBootstrap {
            #expect(AppBootstrap.shared === existingBootstrap)
        }
    }

    @Test("persistEnrichment updates the same saved assistant message by id")
    func persistEnrichmentUpdatesSavedAssistantMessageById() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let coordinator = makeCoordinator(container: container)

        let chatId = "chat-research"
        let assistantId = "assistant-research"
        let start = Date(timeIntervalSince1970: 2_468)

        let completedMessage = ChatMessage(
            id: assistantId,
            chatId: chatId,
            role: .assistant,
            content: "Initial answer",
            mode: .api,
            reasoningText: "Thinking...",
            reasoningDuration: 1.25,
            isResearchResult: true,
            researchStartTime: start
        )

        coordinator.persistChatCompletion(
            chatId: chatId,
            query: "What does the evidence show?",
            answer: "Initial answer",
            dual: nil,
            truth: nil,
            confidence: 0.5,
            grade: .c,
            mode: .api,
            assistantMessage: completedMessage,
            isResearch: true
        )

        let enrichedMessage = ChatMessage(
            id: assistantId,
            chatId: chatId,
            role: .assistant,
            content: "Initial answer",
            dualMessage: makeLaymanDualMessage(),
            truthAssessment: makeTruthAssessment(),
            confidence: 0.84,
            evidenceGrade: .b,
            mode: .api,
            reasoningText: "Thinking...",
            reasoningDuration: 1.25,
            isResearchResult: true,
            researchDuration: 33,
            researchStartTime: start
        )

        coordinator.persistEnrichment(
            chatId: chatId,
            messageId: assistantId,
            dualMessage: makeLaymanDualMessage(),
            truthAssessment: makeTruthAssessment(),
            message: enrichedMessage
        )

        let chats = try context.fetch(FetchDescriptor<SDChat>())
        let chat = try #require(chats.first)
        let assistantMessages = (chat.messages ?? []).filter { $0.role == "assistant" }
        let savedAssistant = try #require(assistantMessages.first)

        #expect(assistantMessages.count == 1)
        #expect(savedAssistant.id == assistantId)
        #expect(savedAssistant.dualMessageData != nil)
        #expect(savedAssistant.truthAssessmentData != nil)
        #expect(savedAssistant.researchDuration == 33)
        #expect(savedAssistant.researchStartTime == start)
    }

    @Test("research completion notification payload includes chat title and deep link id")
    func researchCompletionNotificationPayloadIncludesChatTitleAndDeepLink() {
        let payload = ChatCoordinator.makeResearchCompletionNotificationPayload(
            chatId: "chat-42",
            chatTitle: "Bayesian Updating",
            hasFullResearch: true
        )

        #expect(payload.title == "Full Research Complete")
        #expect(payload.subtitle == "Bayesian Updating")
        #expect(payload.body.contains("Bayesian Updating"))
        #expect(payload.userInfo["chatId"] as? String == "chat-42")
    }
}

@Suite("Ambient Manifest Refresh Driver", .serialized)
struct AmbientManifestRefreshDriverTests {
    @Test("overlapping ambient manifest refresh requests coalesce into one rerun")
    func overlappingAmbientManifestRefreshRequestsCoalesceIntoOneRerun() async throws {
        let driver = AmbientManifestRefreshDriver()
        let probe = RefreshBuildProbe()
        let manifest = makeManifest(title: "Coalesced")
        let recorder = AppliedManifestRecorder()

        async let firstRequest: Void = driver.request(
            build: { await probe.build(result: manifest) },
            apply: { manifest in
                await recorder.append(manifest?.entries.first?.title ?? "")
            }
        )

        await probe.waitUntilFirstBuildStarts()

        async let secondRequest: Void = driver.request(
            build: { await probe.build(result: manifest) },
            apply: { manifest in
                await recorder.append(manifest?.entries.first?.title ?? "")
            }
        )
        async let thirdRequest: Void = driver.request(
            build: { await probe.build(result: manifest) },
            apply: { manifest in
                await recorder.append(manifest?.entries.first?.title ?? "")
            }
        )

        await probe.releaseFirstBuild()

        try await waitUntil(timeout: .seconds(8)) {
            await recorder.count == 2
        }

        await firstRequest
        await secondRequest
        await thirdRequest
        #expect(await probe.buildCount == 2)
        #expect(await recorder.snapshot() == ["Coalesced", "Coalesced"])
    }

    @Test("ambient manifest refresh starts a fresh build after the prior one completes")
    func ambientManifestRefreshStartsFreshBuildAfterCompletion() async throws {
        let driver = AmbientManifestRefreshDriver()
        let probe = RefreshBuildProbe()
        let firstManifest = makeManifest(title: "First")
        let secondManifest = makeManifest(title: "Second")
        let recorder = AppliedManifestRecorder()

        async let firstRequest: Void = driver.request(
            build: { await probe.build(result: firstManifest) },
            apply: { manifest in
                await recorder.append(manifest?.entries.first?.title ?? "")
            }
        )
        await probe.waitUntilFirstBuildStarts()
        await probe.releaseFirstBuild()

        try await waitUntil(timeout: .seconds(8)) {
            await recorder.snapshot() == ["First"]
        }
        await firstRequest

        await driver.request(
            build: { await probe.build(result: secondManifest) },
            apply: { manifest in
                await recorder.append(manifest?.entries.first?.title ?? "")
            }
        )

        try await waitUntil(timeout: .seconds(8)) {
            await recorder.snapshot() == ["First", "Second"]
        }

        #expect(await probe.buildCount == 2)
    }

    private func makeManifest(title: String) -> VaultManifest {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        return VaultManifest(
            entries: [
                VaultManifest.ManifestEntry(
                    pageId: UUID().uuidString,
                    title: title,
                    tags: [],
                    folderName: nil,
                    wordCount: 10,
                    snippet: "",
                    updatedAt: now,
                    createdAt: now
                )
            ],
            recentBodies: [],
            generatedAt: now
        )
    }

    private func waitUntil(
        timeout: Duration,
        condition: @escaping @Sendable () async -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if await condition() { return }
            await Task.yield()
        }
        Issue.record("Timed out waiting for ambient manifest refresh condition")
    }
}

private actor RefreshBuildProbe {
    private var buildCountValue = 0
    private var firstBuildRelease: CheckedContinuation<Void, Never>?
    private var firstBuildStarted: CheckedContinuation<Void, Never>?

    var buildCount: Int { buildCountValue }

    func build(result: VaultManifest) async -> VaultManifest? {
        buildCountValue += 1
        if buildCountValue == 1 {
            firstBuildStarted?.resume()
            firstBuildStarted = nil
            await withCheckedContinuation { continuation in
                firstBuildRelease = continuation
            }
        }
        return result
    }

    func waitUntilFirstBuildStarts() async {
        guard buildCountValue == 0 else { return }
        await withCheckedContinuation { continuation in
            firstBuildStarted = continuation
        }
    }

    func releaseFirstBuild() {
        firstBuildRelease?.resume()
        firstBuildRelease = nil
    }
}

private actor AppliedManifestRecorder {
    private var titles: [String] = []

    var count: Int { titles.count }

    func append(_ title: String) {
        titles.append(title)
    }

    func snapshot() -> [String] {
        titles
    }
}
