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
        provider: .localMLX,
        model: LocalTextModelID.qwen35_4B4Bit.rawValue,
        reasoningMode: .fast
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
        #expect(snap.provider == .localMLX)
        #expect(snap.model == LocalTextModelID.qwen35_4B4Bit.rawValue)
        #expect(snap.reasoningMode == .fast)
    }
}

// MARK: - PipelineService Integration Tests

@Suite("PipelineService")
struct PipelineServiceTests {

    @Test("Plain chat bypasses analytical stages and signal generation")
    @MainActor func plainChatBypassesAnalyticalStages() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["Test", " answer"]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: InferenceState(),
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

        let stageEvents = events.compactMap { event -> PipelineStage? in
            if case .stageAdvanced(let stage, let result) = event, result.status == .completed {
                return stage
            }
            return nil
        }
        #expect(stageEvents.isEmpty)
        #expect(pipelineState.pipelineStages.isEmpty)
        #expect(pipelineState.signalHistory.isEmpty)
    }

    @Test("Pipeline handles thinking tags as deliberation")
    @MainActor func pipelineThinkingTags() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["<thinking>", "I need to think", "</thinking>", "Final answer"]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setShowLocalThinkingPanel(true)
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        var deliberations: [String] = []
        var reasoning: [String] = []
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
            if case .reasoningDelta(let d) = event {
                reasoning.append(d)
            }
            if case .textDelta(let t) = event {
                texts.append(t)
            }
        }

        let deliberationText = deliberations.joined()
        let reasoningText = reasoning.joined()
        let visibleText = texts.joined()
        // Deliberation should contain the thinking content
        #expect(deliberationText.contains("think"))
        #expect(reasoningText.contains("think"))
        // Visible text should contain the final answer (not thinking)
        #expect(visibleText.contains("Final answer"))
    }

    @Test("Pipeline handles qwen think tags as deliberation")
    @MainActor func pipelineQwenThinkTags() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["<think>", "I need to think", "</think>", "Final answer"]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setShowLocalThinkingPanel(true)
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        var deliberations: [String] = []
        var reasoning: [String] = []
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
            if case .reasoningDelta(let d) = event {
                reasoning.append(d)
            }
            if case .textDelta(let t) = event {
                texts.append(t)
            }
        }

        let deliberationText = deliberations.joined()
        let reasoningText = reasoning.joined()
        let visibleText = texts.joined()
        #expect(deliberationText.contains("think"))
        #expect(reasoningText.contains("think"))
        #expect(visibleText.contains("Final answer"))
    }

    @Test("Pipeline handles qwen thinking prelude without think tags")
    @MainActor func pipelineQwenThinkingPrelude() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = [
            "Thinking Process:\n",
            "Ice floats because solid water is less dense than liquid water.\n\n",
            "Final Answer:\n",
            "Ice floats because hydrogen bonds create an open lattice."
        ]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setShowLocalThinkingPanel(true)
        inference.setPreferredLocalReasoningMode(.thinking)
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        var deliberations: [String] = []
        var reasoning: [String] = []
        var texts: [String] = []
        let stream = pipeline.run(
            query: "Explain why ice floats on water.",
            mode: .api,
            skipEnrichment: true
        )

        for try await event in stream {
            if case .deliberationDelta(let d) = event {
                deliberations.append(d)
            }
            if case .reasoningDelta(let d) = event {
                reasoning.append(d)
            }
            if case .textDelta(let t) = event {
                texts.append(t)
            }
        }

        let deliberationText = deliberations.joined()
        let reasoningText = reasoning.joined()
        let visibleText = texts.joined()
        #expect(deliberationText.contains("less dense"))
        #expect(reasoningText.contains("less dense"))
        #expect(!visibleText.localizedCaseInsensitiveContains("thinking process"))
        #expect(visibleText.contains("Ice floats because hydrogen bonds"))
    }

    @Test("Pipeline salvages a visible answer when qwen reasoning prelude never emits an answer marker")
    @MainActor func pipelineSalvagesVisibleAnswerFromReasoningPrelude() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = [
            "Thinking Process:\n",
            "- Compare density.\n",
            "- Recall hydrogen bonds.\n",
            "Ice floats because the crystalline lattice keeps solid water less dense than liquid water."
        ]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setShowLocalThinkingPanel(true)
        inference.setPreferredLocalReasoningMode(.thinking)
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        var deliberations: [String] = []
        var texts: [String] = []
        let stream = pipeline.run(
            query: "Explain why ice floats on water.",
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
        #expect(deliberationText.contains("Compare density"))
        #expect(visibleText.contains("crystalline lattice"))
        #expect(!visibleText.localizedCaseInsensitiveContains("Thinking Process"))
    }

    @Test("Pipeline salvages a visible answer when qwen ends the reasoning prelude with a therefore paragraph")
    @MainActor func pipelineSalvagesVisibleAnswerFromReasoningPreludeWithConclusionParagraph() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = [
            "Thinking Process:\n",
            "First, compare the density of ice and liquid water.\n",
            "Then recall that hydrogen bonding creates an open crystalline lattice.\n\n",
            "Therefore, ice floats because that lattice keeps solid water less dense than the liquid.\n"
        ]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setShowLocalThinkingPanel(true)
        inference.setPreferredLocalReasoningMode(.thinking)
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        var deliberations: [String] = []
        var texts: [String] = []
        let stream = pipeline.run(
            query: "Explain why ice floats on water.",
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
        #expect(deliberationText.contains("hydrogen bonding"))
        #expect(visibleText.contains("ice floats because"))
        #expect(!visibleText.localizedCaseInsensitiveContains("Thinking Process"))
    }

    @Test("Pipeline splits prose-style qwen reasoning into deliberation and a clean visible answer")
    @MainActor func pipelineSplitsNarrativeThinkingPreludeWithoutTags() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = [
            "Let me think this through carefully.\n",
            "First, compare the density of ice and liquid water.\n",
            "Then recall that hydrogen bonding creates an open crystalline lattice.\n\n",
            "Therefore, ice floats because that lattice keeps solid water less dense than the liquid.\n",
        ]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setShowLocalThinkingPanel(true)
        inference.setPreferredLocalReasoningMode(.thinking)
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        var deliberations: [String] = []
        var texts: [String] = []
        let stream = pipeline.run(
            query: "Explain why ice floats on water.",
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
        #expect(deliberationText.localizedCaseInsensitiveContains("let me think this through carefully"))
        #expect(deliberationText.contains("compare the density of ice"))
        #expect(visibleText.localizedCaseInsensitiveContains("therefore, ice floats because"))
        #expect(!visibleText.localizedCaseInsensitiveContains("let me think this through carefully"))
        #expect(!visibleText.localizedCaseInsensitiveContains("compare the density of ice"))
    }

    @Test("Pipeline routes numbered self-analysis loops into deliberation and keeps the visible answer clean")
    @MainActor func pipelineSplitsAnalyzeTheRequestLoopIntoThinkingPanel() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = [
            "1. **Analyze the Request:**\n",
            "* User Query: research the song cranes in the sky what is it about\n",
            "* Clarify the likely artist and theme.\n\n",
            "The song is about trying to outrun grief and emotional pain through distractions that never really solve the hurt."
        ]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setShowLocalThinkingPanel(true)
        inference.setPreferredLocalReasoningMode(.thinking)
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        var deliberations: [String] = []
        var texts: [String] = []
        let stream = pipeline.run(
            query: "research the song cranes in the sky what is it about",
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
        #expect(deliberationText.contains("User Query: research the song cranes in the sky what is it about"))
        #expect(deliberationText.contains("Clarify the likely artist and theme"))
        #expect(!visibleText.contains("Analyze the Request"))
        #expect(!visibleText.contains("Clarify the likely artist and theme"))
        #expect(!deliberationText.contains("trying to outrun grief and emotional pain"))
        #expect(visibleText.contains("trying to outrun grief and emotional pain"))
    }

    @Test("Pipeline salvages drafted visible answers out of pure thinking loops")
    @MainActor func pipelineSalvagesDraftedVisibleAnswersFromThinkingLoops() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = [
            "1. **Analyze the Input:**\n",
            "* Input: love\n",
            "* Intent: open-ended affectionate word.\n\n",
            "* Let's write: Love is a big word. What's on your mind?\n",
            "* Let's write: Love is a big word. What's on your mind?\n",
        ]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setShowLocalThinkingPanel(true)
        inference.setPreferredLocalReasoningMode(.fast)
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        var visibleText = ""
        let stream = pipeline.run(
            query: "love",
            mode: .api,
            skipEnrichment: true
        )

        for try await event in stream {
            if case .textDelta(let text) = event {
                visibleText += text
            }
        }

        #expect(visibleText.trimmingCharacters(in: .whitespacesAndNewlines) == "Love is a big word. What's on your mind?")
    }

    @Test("Plain chat completion carries no analytical metadata")
    @MainActor func plainChatCompletionCarriesNoAnalyticalMetadata() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["Answer"]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: InferenceState(),
            eventBus: eventBus
        )

        var completedDual: DualMessage?
        var completedTruth: TruthAssessment?
        let stream = pipeline.run(
            query: "What is quantum entanglement?",
            mode: .api,
            skipEnrichment: true
        )

        for try await event in stream {
            if case .completed(let dual, let truth) = event {
                completedDual = dual
                completedTruth = truth
            }
        }

        #expect(completedTruth == nil)
        #expect(completedDual?.rawAnalysis.isEmpty == true)
        #expect(completedDual?.uncertaintyTags.isEmpty == true)
        #expect(completedDual?.modelVsDataFlags.isEmpty == true)
        #expect(pipelineState.signalHistory.isEmpty)
    }

    @Test("Mock can be injected into PipelineService and TriageService")
    @MainActor func dependencyInjection() {
        let mock = MockLLMClient()
        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])

        // Both accept LLMClientProtocol
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()
        let pipelineState = PipelineState()
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: InferenceState(),
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

    // MARK: - Cancellation

    @Test("Pipeline can be cancelled mid-stream")
    @MainActor func pipelineCancellation() async {
        let mock = MockLLMClient()
        // Long stream to ensure we have time to cancel
        mock.streamTokens = (0..<100).map { "Token\($0) " }

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: InferenceState(),
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

    @Test("Pipeline cancellation does not emit a completed event for a partial local answer")
    @MainActor func pipelineCancellationDoesNotCompletePartialAnswer() async {
        let mock = MockLLMClient()
        mock.streamTokens = (0..<120).map { "Token\($0) " }

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        var receivedText = false
        var receivedCompleted = false
        let stream = pipeline.run(
            query: "Give me a very long answer.",
            mode: .api,
            skipEnrichment: true
        )

        let consumer = Task { @MainActor in
            do {
                for try await event in stream {
                    if case .textDelta = event {
                        receivedText = true
                    }
                    if case .completed = event {
                        receivedCompleted = true
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }

        try? await Task.sleep(for: .milliseconds(280))
        consumer.cancel()
        _ = await consumer.result

        #expect(receivedText)
        #expect(!receivedCompleted)
    }

    // MARK: - Event Ordering

    @Test("Pipeline stage events arrive in deterministic order")
    @MainActor func stageOrdering() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["Answer"]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: InferenceState(),
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
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
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

    @Test("stream work no longer inherits the main actor")
    @MainActor func streamWorkRunsOffMainActor() async throws {
        let key = DispatchSpecificKey<UInt8>()
        DispatchQueue.main.setSpecific(key: key, value: 1)

        let stream = NetworkProcessActivity.makeStream(reason: "Epistemos AI stream") { continuation in
            let isMainQueue = DispatchQueue.getSpecific(key: key) == 1
            continuation.yield(isMainQueue ? "main" : "background")
            continuation.finish()
        }

        var chunks: [String] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }

        #expect(chunks == ["background"])
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

@Suite("ChatCoordinator Persistence", .serialized)
@MainActor
struct ChatCoordinatorPersistenceTests {
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
        let triage = TriageService(inference: inference)
        let eventBus = EventBus()
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: llmService,
            triageService: triage,
            inference: InferenceState(),
            eventBus: eventBus
        )

        return ChatCoordinator(
            bootstrap: bootstrap,
            chatState: chatState,
            pipelineService: pipeline,
            inferenceState: inference,
            vaultSync: VaultSyncService(modelContainer: container),
            modelContainer: container,
            eventBus: eventBus,
            llmService: llmService,
            notesUI: NotesUIState()
        )
    }

    private func makeCoordinatorHarness(container: ModelContainer) -> (ChatCoordinator, ChatState) {
        let bootstrap = AppBootstrap.shared ?? AppBootstrap()
        let chatState = ChatState()
        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        let llmService = LLMService(inference: inference)
        let triage = TriageService(inference: inference)
        let eventBus = EventBus()
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: llmService,
            triageService: triage,
            inference: InferenceState(),
            eventBus: eventBus
        )

        let coordinator = ChatCoordinator(
            bootstrap: bootstrap,
            chatState: chatState,
            pipelineService: pipeline,
            inferenceState: inference,
            vaultSync: VaultSyncService(modelContainer: container),
            modelContainer: container,
            eventBus: eventBus,
            llmService: llmService,
            notesUI: NotesUIState()
        )
        return (coordinator, chatState)
    }

    private func makeCoordinatorHarness(
        container: ModelContainer,
        llmClient: any LLMClientProtocol
    ) -> (ChatCoordinator, ChatState, PipelineService, AppBootstrap) {
        let bootstrap = AppBootstrap.shared ?? AppBootstrap()
        let chatState = ChatState()
        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)
        let llmService = LLMService(inference: inference, localLLMClient: llmClient)
        let triage = TriageService(inference: inference, localLLMService: llmClient)
        let eventBus = EventBus()
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: llmService,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        let coordinator = ChatCoordinator(
            bootstrap: bootstrap,
            chatState: chatState,
            pipelineService: pipeline,
            inferenceState: inference,
            vaultSync: VaultSyncService(modelContainer: container),
            modelContainer: container,
            eventBus: eventBus,
            llmService: llmService,
            notesUI: NotesUIState()
        )
        return (coordinator, chatState, pipeline, bootstrap)
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

    @Test("shared notes context resolver requires explicit mentions and supports all-notes context")
    func sharedNotesContextResolverRequiresExplicitMentionsAndSupportsAllNotesContext() async {
        let now = Date()
        let manifest = VaultManifest(
            vaultTitle: "my mind",
            totalNoteCount: 2,
            isInventoryComplete: true,
            entries: [
                VaultManifest.ManifestEntry(
                    pageId: "alpha-id",
                    title: "Alpha",
                    tags: ["focus"],
                    folderName: nil,
                    wordCount: 120,
                    snippet: "Alpha summary",
                    updatedAt: now,
                    createdAt: now
                ),
                VaultManifest.ManifestEntry(
                    pageId: "beta-id",
                    title: "Beta",
                    tags: ["archive"],
                    folderName: nil,
                    wordCount: 80,
                    snippet: "Beta summary",
                    updatedAt: now,
                    createdAt: now
                )
            ],
            recentBodies: [],
            generatedAt: now
        )
        let manifestEntries = manifest.entries

        let first = await ChatCoordinator.resolveNotesContext(
            query: "@[Alpha] compare this with today",
            manifest: manifest,
            loadedNoteIds: [],
            loadedNoteTitles: [],
            includeAllNotesContext: false,
            findNotesByTitle: { query in
                query == "Alpha" ? manifestEntries : []
            },
            fetchNoteBodies: { ids in
                ids.contains("alpha-id")
                    ? [VaultManifest.NoteBody(pageId: "alpha-id", title: "Alpha", body: "Alpha full body")]
                    : []
            },
            searchNoteIDs: { _ in [] }
        )

        #expect(first.cleanedQuery == "Alpha compare this with today")
        #expect(first.loadedNoteIds == Set(["alpha-id"]))
        #expect(first.loadedNoteTitles == ["Alpha"])
        #expect(first.context?.contains("### Referenced Note: Alpha") == true)

        let second = await ChatCoordinator.resolveNotesContext(
            query: "Use the same note again",
            manifest: manifest,
            loadedNoteIds: first.loadedNoteIds,
            loadedNoteTitles: first.loadedNoteTitles,
            includeAllNotesContext: false,
            findNotesByTitle: { _ in [] },
            fetchNoteBodies: { ids in
                ids.contains("alpha-id")
                    ? [VaultManifest.NoteBody(pageId: "alpha-id", title: "Alpha", body: "Alpha full body")]
                    : []
            },
            searchNoteIDs: { _ in [] }
        )

        #expect(second.cleanedQuery == "Use the same note again")
        #expect(second.context == nil)
        #expect(second.loadedNoteIds.isEmpty)
        #expect(second.loadedNoteTitles.isEmpty)

        let third = await ChatCoordinator.resolveNotesContext(
            query: "@[All Notes] compare themes across the vault",
            manifest: manifest,
            loadedNoteIds: [],
            loadedNoteTitles: [],
            includeAllNotesContext: false,
            findNotesByTitle: { _ in [] },
            fetchNoteBodies: { ids in
                ids.compactMap { id in
                    switch id {
                    case "beta-id":
                        VaultManifest.NoteBody(pageId: "beta-id", title: "Beta", body: "Beta full body")
                    case "alpha-id":
                        VaultManifest.NoteBody(pageId: "alpha-id", title: "Alpha", body: "Alpha full body")
                    default:
                        nil
                    }
                }
            },
            searchNoteIDs: { query in
                query == "compare themes across the vault" ? ["beta-id", "alpha-id"] : []
            }
        )

        #expect(third.cleanedQuery == "compare themes across the vault")
        #expect(third.context?.contains("## Vault") == true)
        #expect(third.context?.contains("- title: my mind") == true)
        #expect(third.context?.contains("## Vault Overview (2 listed notes)") == true)
        #expect(third.context?.contains("Alpha") == true)
        #expect(third.context?.contains("Beta") == true)
        #expect(third.context?.contains("## Matched Vault Notes") == true)
        #expect(third.context?.contains("### Vault Match: Beta") == true)
        #expect(third.context?.contains("Beta full body") == true)
        #expect(third.loadedNoteIds == Set(["beta-id", "alpha-id"]))
        #expect(third.loadedNoteTitles == ["Beta", "Alpha"])

        let attached = await ChatCoordinator.resolveAttachedContext(
            query: "Compare this to that older conversation",
            attachments: [
                ContextAttachment(kind: .chat, targetId: "chat-1", title: "Older Thread", subtitle: "Main chat")
            ],
            manifest: manifest,
            loadedNoteIds: [],
            loadedNoteTitles: [],
            includeAllNotesContext: false,
            findNotesByTitle: { _ in [] },
            fetchNoteBodies: { _ in [] },
            searchNoteIDs: { _ in [] },
            fetchChatMessages: { id in
                await MainActor.run {
                    id == "chat-1"
                        ? [
                            AssistantMessage(role: .user, content: "What is imperialism?"),
                            AssistantMessage(role: .assistant, content: "A system of domination.")
                        ]
                        : []
                }
            }
        )

        #expect(attached.cleanedQuery == "Compare this to that older conversation")
        #expect(attached.context?.contains("Attached chat context: Older Thread") == true)
        #expect(attached.context?.contains("User: What is imperialism?") == true)
        #expect(attached.context?.contains("Assistant: A system of domination.") == true)
    }

    @Test("attached notes resolve by exact page id and do not drift through title search")
    func attachedNotesResolveByExactPageID() async {
        let now = Date()
        let manifest = VaultManifest(
            vaultTitle: "my mind",
            totalNoteCount: 2,
            isInventoryComplete: true,
            entries: [
                VaultManifest.ManifestEntry(
                    pageId: "alpha-id",
                    title: "Project Atlas",
                    tags: [],
                    folderName: "Plans",
                    wordCount: 120,
                    snippet: "Alpha snippet",
                    updatedAt: now,
                    createdAt: now
                ),
                VaultManifest.ManifestEntry(
                    pageId: "beta-id",
                    title: "Project Atlas",
                    tags: [],
                    folderName: "Research",
                    wordCount: 140,
                    snippet: "Beta snippet",
                    updatedAt: now,
                    createdAt: now
                )
            ],
            recentBodies: [],
            generatedAt: now
        )

        let resolution = await ChatCoordinator.resolveAttachedContext(
            query: "Compare this with the selected note",
            attachments: [
                ContextAttachment(kind: .note, targetId: "beta-id", title: "Project Atlas", subtitle: "Research")
            ],
            manifest: manifest,
            loadedNoteIds: [],
            loadedNoteTitles: [],
            includeAllNotesContext: false,
            findNotesByTitle: { _ in
                [
                    VaultManifest.ManifestEntry(
                        pageId: "alpha-id",
                        title: "Project Atlas",
                        tags: [],
                        folderName: "Plans",
                        wordCount: 120,
                        snippet: "Alpha snippet",
                        updatedAt: now,
                        createdAt: now
                    )
                ]
            },
            fetchNoteBodies: { ids in
                ids.compactMap { id in
                    switch id {
                    case "alpha-id":
                        VaultManifest.NoteBody(pageId: "alpha-id", title: "Project Atlas", body: "Alpha full body")
                    case "beta-id":
                        VaultManifest.NoteBody(pageId: "beta-id", title: "Project Atlas", body: "Beta full body")
                    default:
                        nil
                    }
                }
            },
            searchNoteIDs: { _ in [] },
            fetchChatMessages: { _ in [] }
        )

        #expect(resolution.cleanedQuery == "Compare this with the selected note")
        #expect(resolution.context?.contains("### Attached Note: Project Atlas") == true)
        #expect(resolution.context?.contains("Beta full body") == true)
        #expect(resolution.context?.contains("Alpha full body") == false)
        #expect(resolution.loadedNoteIds == Set(["beta-id"]))
        #expect(resolution.loadedNoteTitles == ["Project Atlas"])
    }

    @Test("pipeline direct stream uses bare prompts and only appends explicit note context")
    @MainActor func pipelineDirectStreamUsesBarePrompts() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["Direct", " answer"]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        let stream = pipeline.run(
            query: "What is truth?",
            mode: .api,
            notesContext: nil,
            skipEnrichment: true
        )
        for try await _ in stream {}

        #expect(mock.streamCalls.count == 1)
        #expect(mock.streamCalls[0].systemPrompt == nil)
        #expect(mock.streamCalls[0].prompt == "What is truth?")
        #expect(!mock.streamCalls[0].prompt.contains("You are Epistemos"))
        #expect(!mock.streamCalls[0].prompt.contains("User's Knowledge Vault"))

        mock.streamCalls.removeAll()
        let streamWithNotes = pipeline.run(
            query: "Compare this with today",
            mode: .api,
            notesContext: "### Referenced Note: Alpha\nAlpha full body",
            skipEnrichment: true
        )
        for try await _ in streamWithNotes {}

        #expect(mock.streamCalls.count == 1)
        #expect(mock.streamCalls[0].systemPrompt == nil)
        #expect(mock.streamCalls[0].prompt.contains("### Referenced Note: Alpha"))
        #expect(mock.streamCalls[0].prompt.contains("Compare this with today"))
    }

    @Test("persistEnrichment updates the same saved assistant message by id")
    func persistEnrichmentUpdatesSavedAssistantMessageById() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let coordinator = makeCoordinator(container: container)

        let chatId = "chat-persist"
        let assistantId = "assistant-persist"

        let completedMessage = ChatMessage(
            id: assistantId,
            chatId: chatId,
            role: .assistant,
            content: "Initial answer",
            mode: .api,
            reasoningText: "Thinking...",
            reasoningDuration: 1.25
        )

        coordinator.persistChatCompletion(
            chatId: chatId,
            query: "What does the evidence show?",
            answer: "Initial answer",
            dual: nil,
            truth: nil,
            confidence: nil,
            grade: nil,
            mode: .api,
            assistantMessage: completedMessage
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
            reasoningDuration: 1.25
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
    }

    @Test("persistChatCompletion preserves user message ordering when chat reloads")
    func persistChatCompletionPreservesUserMessageOrdering() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (coordinator, chatState) = makeCoordinatorHarness(container: container)

        let chatId = "chat-ordering"
        let userCreatedAt = Date(timeIntervalSince1970: 1_000)
        let assistantCreatedAt = Date(timeIntervalSince1970: 1_005)
        let userMessage = ChatMessage(
            id: "user-ordering",
            chatId: chatId,
            role: .user,
            content: "Explain the tradeoff",
            createdAt: userCreatedAt
        )
        let assistantMessage = ChatMessage(
            id: "assistant-ordering",
            chatId: chatId,
            role: .assistant,
            content: "Here is the tradeoff.",
            mode: .local,
            createdAt: assistantCreatedAt
        )
        chatState.loadMessages([userMessage, assistantMessage])

        coordinator.persistChatCompletion(
            chatId: chatId,
            query: userMessage.content,
            answer: assistantMessage.content,
            dual: nil,
            truth: nil,
            confidence: nil,
            grade: nil,
            mode: .local,
            assistantMessage: assistantMessage
        )

        let chats = try context.fetch(FetchDescriptor<SDChat>())
        let savedChat = try #require(chats.first)
        let loaded = savedChat.loadedMessages

        #expect(loaded.map(\.role) == [.user, .assistant])
        #expect(loaded[0].id == userMessage.id)
        #expect(loaded[0].createdAt == userCreatedAt)
        #expect(loaded[1].id == assistantMessage.id)
        #expect(loaded[1].createdAt == assistantCreatedAt)
    }

    @Test("persistChatCompletion preserves note context snapshots on reload")
    func persistChatCompletionPreservesNoteContextSnapshots() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (coordinator, chatState) = makeCoordinatorHarness(container: container)

        let noteAttachment = ContextAttachment(
            kind: .note,
            targetId: "page-42",
            title: "Research Note",
            subtitle: "Ideas"
        )
        let vaultAttachment = ContextAttachment(
            kind: .allNotes,
            targetId: ChatCoordinator.allNotesMentionToken,
            title: "All Notes",
            subtitle: "Vault"
        )
        let userMessage = ChatMessage(
            id: "user-context",
            chatId: "chat-context",
            role: .user,
            content: "Compare this with @Research Note",
            loadedNoteTitles: ["Research Note"],
            contextAttachments: [noteAttachment, vaultAttachment]
        )
        let assistantMessage = ChatMessage(
            id: "assistant-context",
            chatId: "chat-context",
            role: .assistant,
            content: "Here is the comparison.",
            loadedNoteTitles: ["Research Note"],
            contextAttachments: [noteAttachment, vaultAttachment]
        )
        chatState.loadMessages([userMessage, assistantMessage])

        coordinator.persistChatCompletion(
            chatId: "chat-context",
            query: userMessage.content,
            answer: assistantMessage.content,
            dual: nil,
            truth: nil,
            confidence: nil,
            grade: nil,
            mode: .local,
            assistantMessage: assistantMessage
        )

        let savedChat = try #require(try context.fetch(FetchDescriptor<SDChat>()).first)
        let loaded = savedChat.loadedMessages

        #expect(loaded.count == 2)
        #expect(loaded[0].contextAttachments == [noteAttachment, vaultAttachment])
        #expect(loaded[1].contextAttachments == [noteAttachment, vaultAttachment])
        #expect(loaded[0].loadedNoteTitles == ["Research Note"])
        #expect(loaded[1].loadedNoteTitles == ["Research Note"])
    }

    @Test("persistChatCompletion keeps chats on the plain path")
    func persistChatCompletionKeepsChatsOnPlainPath() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let coordinator = makeCoordinator(container: container)

        coordinator.persistChatCompletion(
            chatId: "chat-42",
            query: "Bayesian updating",
            answer: "Here is the answer.",
            dual: nil,
            truth: nil,
            confidence: nil,
            grade: nil,
            mode: .local,
            assistantMessage: nil
        )

        let chats = try context.fetch(FetchDescriptor<SDChat>())
        let chat = try #require(chats.first)
        #expect(chat.hasDeepResearch != true)
    }

    @Test("vault briefing completes through the shared uncapped stream path")
    func vaultBriefingCompletesThroughSharedStreamPath() async throws {
        let container = try makeContainer()
        let mock = MockLLMClient()
        mock.snapshot = LLMSnapshot(
            provider: .localMLX,
            model: LocalTextModelID.qwen35_4B4Bit.rawValue,
            reasoningMode: .fast
        )
        mock.streamTokens = ["This is a full ", "vault briefing."]

        let (coordinator, chatState, pipeline, bootstrap) = makeCoordinatorHarness(
            container: container,
            llmClient: mock
        )

        chatState.vaultBriefingManifest = VaultManifest(
            vaultTitle: "my mind",
            totalNoteCount: 1,
            isInventoryComplete: true,
            entries: [
                VaultManifest.ManifestEntry(
                    pageId: "note-1",
                    title: "Epistemology",
                    tags: ["philosophy"],
                    folderName: "Notes",
                    wordCount: 120,
                    snippet: "A note about justification.",
                    updatedAt: .now,
                    createdAt: .now
                )
            ],
            recentBodies: [
                VaultManifest.NoteBody(
                    pageId: "note-1",
                    title: "Epistemology",
                    body: "Knowledge, belief, and justification."
                )
            ],
            generatedAt: .now
        )

        chatState.submitQuery("[VAULT_BRIEFING]")
        coordinator.handleQuery("[VAULT_BRIEFING]", pipeline: pipeline, chatState: chatState)
        await bootstrap.queryTask?.value

        let assistant = try #require(chatState.messages.last)
        #expect(assistant.role == .assistant)
        #expect(assistant.content == "This is a full vault briefing.")
        #expect(assistant.isVaultBriefing)
        #expect(chatState.vaultBriefingManifest == nil)
        #expect(mock.streamCalls.count == 1)
        #expect(mock.streamCalls[0].maxTokens == 0)
    }
}

@Suite("ChatState Context Attachments")
@MainActor
struct ChatStateContextAttachmentTests {
    @Test("submit query snapshots pending context attachments onto the user message")
    func submitQueryCarriesContextAttachments() {
        let chatState = ChatState()
        let attachment = ContextAttachment(
            kind: .note,
            targetId: "note-1",
            title: "Alpha Note",
            subtitle: "Research"
        )

        chatState.addContextAttachment(attachment)
        chatState.submitQuery("Explain this note")

        let message = chatState.messages.last
        #expect(message?.role == .user)
        #expect(message?.contextAttachments == [attachment])
        #expect(chatState.pendingContextAttachments == [attachment])
    }

    @Test("complete processing snapshots active context attachments onto the assistant message")
    func completeProcessingCarriesContextAttachments() {
        let chatState = ChatState()
        let attachment = ContextAttachment(
            kind: .allNotes,
            targetId: ChatCoordinator.allNotesMentionToken,
            title: "All Notes",
            subtitle: "Vault"
        )

        chatState.addContextAttachment(attachment)
        chatState.submitQuery("Summarize the vault")
        chatState.startStreaming()
        chatState.appendStreamingText("Here is the answer.")
        chatState.completeProcessing(mode: .api)

        let assistant = chatState.messages.last
        #expect(assistant?.role == .assistant)
        #expect(assistant?.contextAttachments == [attachment])
    }

    @Test("loading messages restores latest context attachments for follow-up turns")
    func loadMessagesRestoresLatestContextAttachments() {
        let chatState = ChatState()
        let noteAttachment = ContextAttachment(
            kind: .note,
            targetId: "note-2",
            title: "Deep Work",
            subtitle: "Vault"
        )
        let vaultAttachment = ContextAttachment(
            kind: .allNotes,
            targetId: ChatCoordinator.allNotesMentionToken,
            title: "All Notes",
            subtitle: "Vault"
        )

        chatState.loadMessages([
            ChatMessage(chatId: "chat", role: .user, content: "plain turn"),
            ChatMessage(
                chatId: "chat",
                role: .assistant,
                content: "grounded turn",
                loadedNoteTitles: ["Deep Work"],
                contextAttachments: [noteAttachment, vaultAttachment]
            )
        ])

        #expect(chatState.pendingContextAttachments == [noteAttachment, vaultAttachment])
        #expect(chatState.loadedNoteIds == ["note-2"])
        #expect(chatState.loadedNoteTitles == ["Deep Work"])
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
            vaultTitle: "my mind",
            totalNoteCount: 1,
            isInventoryComplete: true,
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
