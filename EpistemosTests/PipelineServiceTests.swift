import Foundation
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

    @Test("Pipeline emits text deltas from stream")
    @MainActor func pipelineTextDeltas() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["Hello", " world"]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        let triage = TriageService(inference: inference, llmService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            eventBus: eventBus
        )

        var textChunks: [String] = []
        let stream = pipeline.run(
            query: "Hello",
            mode: .api,
            skipEnrichment: true
        )

        for try await event in stream {
            if case .textDelta(let text) = event {
                textChunks.append(text)
            }
        }

        let fullText = textChunks.joined()
        #expect(fullText.contains("Hello"))
        #expect(fullText.contains("world"))
    }

    @Test("Pipeline handles thinking tags as deliberation")
    @MainActor func pipelineThinkingTags() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["<thinking>", "I need to think", "</thinking>", "Final answer"]

        let pipelineState = PipelineState()
        let inference = InferenceState()
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
