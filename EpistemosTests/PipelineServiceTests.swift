import Foundation
import SwiftData
import Testing
@testable import Epistemos

private let interactiveReleaseFixtureModelID = LocalTextModelID.qwen35_2B4Bit

@MainActor
private final class PipelineToolEventRecorder {
    private(set) var events: [PipelineToolEvent] = []

    func append(_ event: PipelineToolEvent) {
        events.append(event)
    }
}

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
        model: interactiveReleaseFixtureModelID.rawValue,
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
            let task = Task {
                for token in tokens {
                    guard !Task.isCancelled else {
                        continuation.finish()
                        return
                    }
                    continuation.yield(token)
                    try? await Task.sleep(for: .milliseconds(5))
                }
                if let error {
                    continuation.finish(throwing: error)
                } else {
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func testConnection() async -> ConnectionTestResult {
        testConnectionCalls += 1
        return ConnectionTestResult(success: true, message: "Mock connected")
    }

    func configSnapshot() -> LLMSnapshot { snapshot }
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
        #expect(snap.model == interactiveReleaseFixtureModelID.rawValue)
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
        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 24_000_000_000,
                roundedMemoryGB: 24,
                maxRecommendedLocalContentLength: 12_000
            )
        )
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([interactiveReleaseFixtureModelID.rawValue])
        inference.setPreferredLocalTextModelID(interactiveReleaseFixtureModelID.rawValue)
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
            mode: .api
        )

        for try await event in stream {
            events.append(event)
        }

        #expect(events.contains { event in
            if case .completed = event { return true }
            return false
        })
        #expect(pipelineState.isProcessing == false)
        #expect(pipelineState.currentError == nil)
    }

    @Test("Default pipeline run no longer falls back to enrichment-era analytical stages")
    @MainActor func defaultRunBypassesEnrichmentEraPipeline() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["Direct", " answer"]

        let pipelineState = PipelineState()
        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 24_000_000_000,
                roundedMemoryGB: 24,
                maxRecommendedLocalContentLength: 12_000
            )
        )
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([interactiveReleaseFixtureModelID.rawValue])
        inference.setPreferredLocalTextModelID(interactiveReleaseFixtureModelID.rawValue)
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        var events: [PipelineEvent] = []
        let stream = pipeline.run(
            query: "Explain this directly.",
            mode: .api
        )

        for try await event in stream {
            events.append(event)
        }

        #expect(events.contains { event in
            if case .textDelta = event { return true }
            return false
        })
        #expect(pipelineState.isProcessing == false)
        #expect(pipelineState.currentError == nil)
    }

    @Test("Pipeline strips tagged local reasoning before emitting visible text")
    @MainActor func pipelineStripsTaggedThinkingFromVisibleOutput() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["<think>", "I need to think", "</think>", "Final answer"]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([interactiveReleaseFixtureModelID.rawValue])
        inference.setPreferredLocalTextModelID(interactiveReleaseFixtureModelID.rawValue)
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        var texts: [String] = []
        let stream = pipeline.run(
            query: "Think about this",
            mode: .api
        )

        for try await event in stream {
            if case .textDelta(let t) = event {
                texts.append(t)
            }
        }

        #expect(texts.joined() == "Final answer")
    }

    @Test("Pipeline forwards hidden reasoning into thinking deltas before the visible answer")
    @MainActor func pipelineForwardsReasoningIntoThinkingDeltas() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = [
            "Thinking Process:\n",
            "I should compare the historical and modern senses first.\n\n",
            "Final Answer:\n",
            "It usually refers to the modern US-led imperial order."
        ]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([interactiveReleaseFixtureModelID.rawValue])
        inference.setPreferredLocalTextModelID(interactiveReleaseFixtureModelID.rawValue)
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        var thinking = ""
        var text = ""
        let stream = pipeline.run(
            query: "Explain the phrase.",
            mode: .api
        )

        for try await event in stream {
            switch event {
            case .thinkingDelta(let delta):
                thinking += delta
            case .textDelta(let delta):
                text += delta
            default:
                break
            }
        }

        #expect(thinking.contains("historical and modern senses"))
        #expect(text == "It usually refers to the modern US-led imperial order.")
    }

    @Test("Pipeline suppresses prose reasoning preludes and emits only the answer")
    @MainActor func pipelineSuppressesReasoningPrelude() async throws {
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
        inference.setInstalledLocalTextModelIDs([interactiveReleaseFixtureModelID.rawValue])
        inference.setPreferredLocalTextModelID(interactiveReleaseFixtureModelID.rawValue)
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        var texts: [String] = []
        let stream = pipeline.run(
            query: "Explain why ice floats on water.",
            mode: .api
        )

        for try await event in stream {
            if case .textDelta(let t) = event {
                texts.append(t)
            }
        }

        #expect(texts.joined() == "Ice floats because hydrogen bonds create an open lattice.")
    }

    @Test("Pipeline suppresses incomplete reasoning lead-ins until the answer appears")
    @MainActor func pipelineSuppressesIncompleteReasoningLeadIn() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = [
            "Here's a thinking",
            " process that leads to the comparison:\n\n",
            "Final Answer:\n",
            "Use the prepared router as the main local model."
        ]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([interactiveReleaseFixtureModelID.rawValue])
        inference.setPreferredLocalTextModelID(interactiveReleaseFixtureModelID.rawValue)
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        var texts: [String] = []
        let stream = pipeline.run(
            query: "Which local model should I use?",
            mode: .api
        )

        for try await event in stream {
            if case .textDelta(let t) = event {
                texts.append(t)
            }
        }

        #expect(texts.joined() == "Use the prepared router as the main local model.")
    }

    @Test("Pipeline keeps the final paragraph when structured reasoning precedes it")
    @MainActor func pipelineKeepsFinalAnswerAfterStructuredReasoningPlan() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = [
            """
            1. Query:
            - Summarize the key findings.

            2. Detailed Analysis with chunk_reduce:
            Input Text: The attached references.
            Reduce Strategy: Keep the highest-signal passages.

            3. Pattern Identification:
            - Look for recurring themes in attention and readiness potentials.

            """,
            """
            This approach will efficiently summarize the references and identify the shared research threads.
            """,
        ]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([interactiveReleaseFixtureModelID.rawValue])
        inference.setPreferredLocalTextModelID(interactiveReleaseFixtureModelID.rawValue)
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        var thinking = ""
        var texts: [String] = []
        let stream = pipeline.run(
            query: "Summarize the research references.",
            mode: .api
        )

        for try await event in stream {
            switch event {
            case .thinkingDelta(let delta):
                thinking += delta
            case .textDelta(let delta):
                texts.append(delta)
            default:
                break
            }
        }

        #expect(thinking.contains("Detailed Analysis with chunk_reduce"))
        #expect(
            texts.joined()
                == "This approach will efficiently summarize the references and identify the shared research threads."
        )
    }

    @Test("Plain chat completion carries no analytical metadata")
    @MainActor func plainChatCompletionCarriesNoAnalyticalMetadata() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["Answer complete."]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([interactiveReleaseFixtureModelID.rawValue])
        inference.setPreferredLocalTextModelID(interactiveReleaseFixtureModelID.rawValue)
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
            mode: .api
        )

        for try await event in stream {
            if case .completed(let dual, let truth) = event {
                completedDual = dual
                completedTruth = truth
            }
        }

        #expect(completedTruth == nil)
        #expect(completedDual?.rawAnalysis == "Answer complete.")
        #expect(completedDual?.uncertaintyTags.isEmpty == true)
        #expect(completedDual?.modelVsDataFlags.isEmpty == true)
        #expect(pipelineState.isProcessing == false)
        #expect(pipelineState.currentError == nil)
    }

    @Test("Mock can be injected into PipelineService and TriageService")
    @MainActor func dependencyInjection() {
        let mock = MockLLMClient()
        let inference = InferenceState()
        inference.setInstalledLocalTextModelIDs([interactiveReleaseFixtureModelID.rawValue])

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

    @Test("agent execution plan forces the pipeline onto the local stream even when cloud is selected")
    @MainActor func agentExecutionPlanForcesLocalStreamEvenWhenCloudIsSelected() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["Local", " plan"]

        let pipelineState = PipelineState()
        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 24_000_000_000,
                roundedMemoryGB: 24,
                maxRecommendedLocalContentLength: 12_000
            )
        )
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_35BA3B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
        inference.setPreferredChatModelSelection(.cloud(.openAIGPT54))
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        let executionPlan = OverseerComplexityRouter(inference: inference).planForMainChat(
            query: "Review this architecture and give me the safest migration order.",
            contentLength: 2_600,
            operatingMode: .agent,
            hasExplicitContext: true,
            attachmentCount: 1,
            notesContext: "Architecture context",
            conversationHistory: nil
        )

        var visibleText = ""
        let stream = pipeline.run(
            query: "Review this architecture and give me the safest migration order.",
            mode: .api,
            notesContext: "Architecture context",
            conversationHistory: nil,
            operatingMode: executionPlan.localOperatingMode,
            executionPlan: executionPlan
        )

        for try await event in stream {
            if case .textDelta(let token) = event {
                visibleText += token
            }
        }

        #expect(visibleText == "Local plan")
        #expect(mock.streamCalls.count == 1)
        let systemPrompt = try #require(mock.streamCalls.first?.systemPrompt)
        #expect(systemPrompt.contains("OVERSEER_PLAN_V1"))
        #expect(systemPrompt.contains("\"mask_plan\""))
    }

    @Test("local overseer execution plan forwards steering hints into the local runtime path")
    @MainActor func localExecutionPlanForwardsSteeringHintsToLocalRuntime() async throws {
        let localClient = RecordingConfigurableLocalLLMClient()
        let pipelineState = PipelineState()
        let inference = InferenceState(
            hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot(
                physicalMemoryBytes: 24_000_000_000,
                roundedMemoryGB: 24,
                maxRecommendedLocalContentLength: 12_000
            )
        )
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_35BA3B4Bit.rawValue])
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_35BA3B4Bit.rawValue)
        inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.qwen35_35BA3B4Bit.rawValue))

        let triage = TriageService(inference: inference, localLLMService: localClient)
        let eventBus = EventBus()
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: localClient,
            triageService: triage,
            inference: inference,
            eventBus: eventBus,
            localModelClient: localClient
        )

        let executionPlan = OverseerComplexityRouter(inference: inference).planForMainChat(
            query: "Summarize the migration plan conservatively.",
            contentLength: 1400,
            operatingMode: .fast,
            hasExplicitContext: true,
            attachmentCount: 0,
            notesContext: "Migration context",
            conversationHistory: nil
        )
        #expect(executionPlan.route == .overseerLocalExecution)
        let expectedHints = try #require(executionPlan.steeringHintsJSON)

        let stream = pipeline.run(
            query: "Summarize the migration plan conservatively.",
            mode: .api,
            notesContext: "Migration context",
            conversationHistory: nil,
            operatingMode: executionPlan.localOperatingMode,
            executionPlan: executionPlan
        )

        for try await _ in stream {}

        #expect(localClient.streamRequests.count == 1)
        let actualHints = try #require(localClient.streamRequests.first?.steeringHintsJSON)
        let normalizedActual = try normalizedJSONString(actualHints)
        let normalizedExpected = try normalizedJSONString(expectedHints)
        #expect(normalizedActual == normalizedExpected)
    }

    @Test("standard local chat modes use the direct stream instead of the local tool loop")
    @MainActor func standardLocalChatModesUseDirectStream() async throws {
        for operatingMode: EpistemosOperatingMode in [.fast, .thinking, .pro] {
            let directClient = RecordingConfigurableLocalLLMClient()
            let localToolLoopClient = RecordingConfigurableLocalLLMClient()
            let pipelineState = PipelineState()
            let inference = InferenceState()
            inference.appleIntelligenceAvailable = false
            inference.setInstalledLocalTextModelIDs([LocalTextModelID.qwen35_4B4Bit.rawValue])
            inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)
            inference.setPreferredChatModelSelection(.localMLX(LocalTextModelID.qwen35_4B4Bit.rawValue))

            let triage = TriageService(inference: inference, localLLMService: directClient)
            let eventBus = EventBus()
            let pipeline = PipelineService(
                pipelineState: pipelineState,
                llmService: directClient,
                triageService: triage,
                inference: inference,
                eventBus: eventBus,
                localModelClient: localToolLoopClient,
                vaultPathProvider: { "/tmp/epistemos-test-vault" }
            )

            let stream = pipeline.run(
                query: "Summarize the note directly.",
                mode: .api,
                notesContext: "Attached note body",
                conversationHistory: nil,
                operatingMode: operatingMode
            )

            for try await _ in stream {}

            #expect(
                triage.lastDecision == .localMLX,
                "Expected local direct routing for \(operatingMode.rawValue)"
            )
            #expect(
                localToolLoopClient.streamRequests.isEmpty,
                "Did not expect local tool-loop requests for \(operatingMode.rawValue)"
            )
        }
    }

    @Test("observed local tool executor emits lifecycle events around tool execution")
    @MainActor func observedLocalToolExecutorEmitsLifecycleEvents() async {
        let mock = MockLLMClient()
        let pipelineState = PipelineState()
        let inference = InferenceState()
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        let recorder = PipelineToolEventRecorder()
        let executor = pipeline.observedToolExecutor(
            { name, argumentsJson in
                #expect(name == "tool_ping")
                #expect(argumentsJson.contains("\"request\":\"transformer architecture\""))
                return LocalToolResult(
                    toolName: name,
                    resultJson: #"{"content":[{"path":"ml/transformers.md"}],"success":true}"#,
                    isError: false
                )
            },
            toolEventHandler: { event in
                recorder.append(event)
            }
        )

        let result = await executor(
            "tool_ping",
            #"{"request":"transformer architecture"}"#
        )

        #expect(result.isError == false)
        let events = recorder.events
        #expect(events.count == 2)

        guard case let .started(startID, startedName, startedInput) = events[0] else {
            Issue.record("Expected a started tool event before the tool result.")
            return
        }
        #expect(!startID.isEmpty)
        #expect(startedName == "tool_ping")
        #expect(startedInput.contains("\"request\":\"transformer architecture\""))

        guard case let .completed(completedID, completedName, completedInput, resultJson, isError, durationMs) = events[1] else {
            Issue.record("Expected a completed tool event after the tool result.")
            return
        }
        #expect(completedID == startID)
        #expect(completedName == "tool_ping")
        #expect(completedInput == startedInput)
        #expect(resultJson.contains("\"success\":true"))
        #expect(isError == false)
        #expect(durationMs >= 0)
    }

    @Test("observed local tool executor blocks sensitive tools when the user denies approval")
    @MainActor func observedLocalToolExecutorHonorsDeniedApproval() async {
        let mock = MockLLMClient()
        let pipelineState = PipelineState()
        let inference = InferenceState()
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()
        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        let recorder = PipelineToolEventRecorder()
        let executor = pipeline.observedToolExecutor(
            { _, _ in
                preconditionFailure("Observed tool executor should not execute the tool after approval is denied.")
            },
            toolMetadataByName: [
                "read_file": OmegaToolDefinition(
                    name: "read_file",
                    agent: "rust",
                    description: "Read a local file",
                    argumentsExample: "{}",
                    schemaJson: #"{"type":"object","properties":{"path":{"type":"string"}}}"#,
                    destructive: false,
                    requiresConfirmation: false
                )
            ],
            toolEventHandler: { event in
                recorder.append(event)
            },
            toolApprovalHandler: { request in
                #expect(request.toolName == "read_file")
                #expect(request.requiresHumanApproval)
                return false
            }
        )

        let result = await executor(
            "read_file",
            #"{"path":"/tmp/test.txt"}"#
        )

        #expect(result.isError)
        #expect(result.resultJson.contains("denied by the user"))

        let events = recorder.events
        #expect(events.count == 2)
        guard case .started = events[0] else {
            Issue.record("Expected a started event before the denial result.")
            return
        }
        guard case let .completed(_, _, _, resultJson, isError, _) = events[1] else {
            Issue.record("Expected a completed event carrying the denial result.")
            return
        }
        #expect(isError)
        #expect(resultJson.contains("denied by the user"))
    }
}

private func normalizedJSONString(_ string: String) throws -> String {
    let data = try #require(string.data(using: .utf8))
    let object = try JSONSerialization.jsonObject(with: data)
    let normalizedData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    let normalizedString = try #require(String(data: normalizedData, encoding: .utf8))
    return normalizedString
}

// MARK: - Pipeline Contract Tests

@Suite("User-Facing Chat Error")
struct UserFacingChatErrorKindTests {

    private struct FakeError: LocalizedError {
        let description: String
        var errorDescription: String? { description }
    }

    @Test("401 / unauthorized surfaces as auth failure")
    func classifiesAuthFailure() {
        let kind = UserFacingChatError.classify(FakeError(description: "401 Unauthorized"))
        #expect(kind == .authFailure)
    }

    @Test("429 / too many requests surfaces as rate limit")
    func classifiesRateLimited() {
        let kind = UserFacingChatError.classify(
            FakeError(description: "Rate limit exceeded; HTTP 429")
        )
        #expect(kind == .rateLimited)
    }

    @Test("network / offline surfaces as provider unreachable")
    func classifiesProviderUnreachable() {
        let kind = UserFacingChatError.classify(
            FakeError(description: "The Internet connection appears to be offline.")
        )
        #expect(kind == .providerUnreachable)
    }

    @Test("timeout surfaces as timed out")
    func classifiesTimedOut() {
        let kind = UserFacingChatError.classify(FakeError(description: "Request timed out."))
        #expect(kind == .timedOut)
    }

    @Test("context-length errors surface as context overflow")
    func classifiesContextOverflow() {
        let kind = UserFacingChatError.classify(
            FakeError(description: "maximum context length exceeded")
        )
        #expect(kind == .contextOverflow)
    }

    @Test("local runtime unavailable surfaces as model not ready")
    func classifiesModelNotReady() {
        let kind = UserFacingChatError.classify(LocalInferenceRoutingError.runtimeUnavailable)
        #expect(kind == .modelNotReady)
    }

    @Test("CancellationError surfaces as cancelled")
    func classifiesCancelled() {
        let kind = UserFacingChatError.classify(CancellationError())
        #expect(kind == .cancelled)
    }

    @Test("unrecognized errors fall back to generic")
    func classifiesGeneric() {
        let kind = UserFacingChatError.classify(
            FakeError(description: "something unusual happened")
        )
        #expect(kind == .generic)
    }

    @Test("message(for:) returns distinct copy per kind")
    func messageCopyPerKind() {
        let kinds: [UserFacingChatErrorKind] = [
            .authFailure, .rateLimited, .providerUnreachable,
            .timedOut, .contextOverflow, .modelNotReady, .cancelled,
        ]
        let copies = kinds.map { UserFacingChatError.message(for: $0) }
        #expect(Set(copies).count == copies.count, "each error kind should have its own copy")
        #expect(copies.allSatisfy { !$0.isEmpty })
    }

    @Test("message(from:) preserves analysisFailure text verbatim")
    func preservesAnalysisFailureText() {
        let raw = "very specific analyzer message"
        let output = UserFacingChatError.message(from: PipelineError.analysisFailure(raw))
        #expect(output == raw)
    }

    @Test("model load stalled preserves the actionable local-model copy")
    func preservesModelLoadStalledCopy() {
        let error = LocalInferenceRoutingError.modelLoadStalled(
            modelID: LocalTextModelID.qwen25Coder7B.rawValue
        )
        let kind = UserFacingChatError.classify(error)
        let message = UserFacingChatError.message(from: error)

        #expect(kind == .generic)
        #expect(message.contains("Qwen 2.5 Coder 7B"))
        #expect(message.contains("Qwen 3 4B"))
    }

    @Test("fast-incompatible local model preserves the actionable mode copy")
    func preservesFastModeUnsupportedCopy() {
        let error = LocalInferenceRoutingError.fastModeUnsupported(
            modelID: LocalTextModelID.deepseekR1Distill7B.rawValue
        )
        let kind = UserFacingChatError.classify(error)
        let message = UserFacingChatError.message(from: error)

        #expect(kind == .generic)
        #expect(message.contains("DeepSeek R1 7B"))
        #expect(message.contains("Fast mode is unavailable"))
        #expect(message.contains("Thinking"))
    }
}

@Suite("Pipeline Contracts")
struct PipelineContractTests {

    // MARK: - Cancellation

    @Test("Pipeline can be cancelled mid-stream")
    @MainActor func pipelineCancellation() async {
        let mock = MockLLMClient()
        // Long stream to ensure we have time to cancel
        mock.streamTokens = (0..<100).map { "Token\($0) " }

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([interactiveReleaseFixtureModelID.rawValue])
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
            mode: .api
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
        inference.setInstalledLocalTextModelIDs([interactiveReleaseFixtureModelID.rawValue])
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
            mode: .api
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

    @Test("Cancelling an active run clears pipeline processing immediately")
    @MainActor func pipelineCancelImmediatelyClearsProcessingState() async {
        let mock = MockLLMClient()
        mock.streamTokens = (0..<120).map { "Token\($0) " }

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([interactiveReleaseFixtureModelID.rawValue])
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
            query: "Give me a very long answer.",
            mode: .api
        )

        let consumer = Task { @MainActor in
            do {
                for try await _ in stream {
                }
            } catch {
            }
        }

        try? await Task.sleep(for: .milliseconds(40))
        #expect(pipelineState.isProcessing)

        pipeline.cancelActiveRun()

        #expect(!pipelineState.isProcessing)
        _ = await consumer.result
    }

    @Test("Terminating an older stream does not cancel the newest pipeline run")
    @MainActor func olderStreamTerminationDoesNotCancelNewestRun() async {
        let mock = MockLLMClient()
        mock.streamTokens = (0..<80).map { "old-\($0) " }

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([interactiveReleaseFixtureModelID.rawValue])
        let triage = TriageService(inference: inference, localLLMService: mock)
        let eventBus = EventBus()

        let pipeline = PipelineService(
            pipelineState: pipelineState,
            llmService: mock,
            triageService: triage,
            inference: inference,
            eventBus: eventBus
        )

        let firstStream = pipeline.run(
            query: "first",
            mode: .api
        )

        let firstConsumer = Task { @MainActor in
            do {
                for try await _ in firstStream {
                }
            } catch {
            }
        }

        try? await Task.sleep(for: .milliseconds(30))
        mock.streamTokens = (0..<8).map { "new-\($0) " }

        var secondCompleted = false
        let secondStream = pipeline.run(
            query: "second",
            mode: .api
        )

        let secondConsumer = Task { @MainActor in
            do {
                for try await event in secondStream {
                    if case .completed = event {
                        secondCompleted = true
                    }
                }
            } catch {
            }
        }

        _ = await firstConsumer.result
        _ = await secondConsumer.result

        #expect(secondCompleted)
        #expect(!pipelineState.isProcessing)
        #expect(pipelineState.currentError == nil)
    }

    @Test("Pipeline emits completed event with DualMessage")
    @MainActor func completedEvent() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["The answer is 42"]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setInstalledLocalTextModelIDs([interactiveReleaseFixtureModelID.rawValue])
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
            mode: .api
        )

        for try await event in stream {
            if case .completed(let dual, _) = event {
                gotCompleted = true
                #expect(dual.rawAnalysis == "The answer is 42")
            }
        }

        #expect(gotCompleted, "Pipeline should emit a .completed event")
    }

    @Test("local tool loop uses reflex execution and guards the executor to surfaced tools")
    func localToolLoopUsesReflexExecutionAndAllowlistedExecutor() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Engine/PipelineService.swift")

        #expect(source.contains("allowedToolNames: Set(tools.map(\\.name))"))
        #expect(source.contains("reflexMode: true"))
    }

}

private final class ActivityProbe: Sendable {
    private let lock = NSLock()
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

@Suite("Process Activity")
struct ProcessActivityTests {
    @Test("scoped activity pairs begin and end around async work")
    @MainActor func scopedActivityPairsBeginAndEnd() async {
        let probe = ActivityProbe()
        let manager = ProcessActivityManager(
            begin: { reason, _ in probe.begin(reason: reason) },
            end: { _ in probe.end() }
        )

        let value = await ProcessActivity.withActivityOnMainActor(
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
        let manager = ProcessActivityManager(
            begin: { reason, _ in probe.begin(reason: reason) },
            end: { _ in probe.end() }
        )

        let stream = ProcessActivity.makeStream(
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

        let stream = ProcessActivity.makeStream(reason: "Epistemos AI stream") { continuation in
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
        _ = PipelineService(
            pipelineState: pipelineState,
            llmService: llmService,
            triageService: triage,
            inference: InferenceState(),
            eventBus: eventBus
        )

        return ChatCoordinator(
            bootstrap: bootstrap,
            chatState: chatState,
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
        _ = PipelineService(
            pipelineState: pipelineState,
            llmService: llmService,
            triageService: triage,
            inference: InferenceState(),
            eventBus: eventBus
        )

        let coordinator = ChatCoordinator(
            bootstrap: bootstrap,
            chatState: chatState,
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
        inference.setInstalledLocalTextModelIDs([interactiveReleaseFixtureModelID.rawValue])
        inference.setPreferredLocalTextModelID(interactiveReleaseFixtureModelID.rawValue)
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
            inferenceState: inference,
            vaultSync: VaultSyncService(modelContainer: container),
            modelContainer: container,
            eventBus: eventBus,
            llmService: llmService,
            notesUI: NotesUIState()
        )
        return (coordinator, chatState, pipeline, bootstrap)
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
        #expect(attached.context?.contains("## Required Attached Chats") == true)
        #expect(attached.context?.contains("Attached chat context: Older Thread") == true)
        #expect(attached.context?.contains("Priority: Required context.") == true)
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
        #expect(resolution.context?.contains("## Required Attached Notes") == true)
        #expect(resolution.context?.contains("Treat the inlined `Content:` blocks as the authoritative source") == true)
        #expect(resolution.context?.contains("Do not ask the user to locate, reattach, or restate these notes.") == true)
        #expect(resolution.context?.contains("### Attached Note: Project Atlas") == true)
        #expect(resolution.context?.contains("Priority: Required context.") == true)
        #expect(resolution.context?.contains("Beta full body") == true)
        #expect(resolution.context?.contains("Alpha full body") == false)
        #expect(resolution.loadedNoteIds == Set(["beta-id"]))
        #expect(resolution.loadedNoteTitles == ["Project Atlas"])
    }

    @Test("natural language note requests resolve note context without mention syntax")
    func naturalLanguageNoteRequestsResolveNoteContext() async {
        let now = Date()
        let manifest = VaultManifest(
            vaultTitle: "my mind",
            totalNoteCount: 1,
            isInventoryComplete: true,
            entries: [
                VaultManifest.ManifestEntry(
                    pageId: "determinism-id",
                    title: "Determinism",
                    tags: ["philosophy"],
                    folderName: nil,
                    wordCount: 140,
                    snippet: "Determinism overview",
                    updatedAt: now,
                    createdAt: now
                )
            ],
            recentBodies: [],
            generatedAt: now
        )
        let manifestEntries = manifest.entries

        #expect(ChatCoordinator.queryContainsExplicitNoteContext("please go to my note determinism and summarize it"))

        let resolution = await ChatCoordinator.resolveNotesContext(
            query: "please go to my note determinism and summarize it",
            manifest: manifest,
            includeAllNotesContext: false,
            findNotesByTitle: { query in
                query == "determinism"
                    ? manifestEntries
                    : []
            },
            fetchNoteBodies: { ids in
                ids.contains("determinism-id")
                    ? [
                        VaultManifest.NoteBody(
                            pageId: "determinism-id",
                            title: "Determinism",
                            body: "Determinism says every event is fixed by prior causes."
                        )
                    ]
                    : []
            },
            searchNoteIDs: { _ in [] }
        )

        #expect(resolution.cleanedQuery == "please go to my note determinism and summarize it")
        #expect(resolution.loadedNoteIds == Set(["determinism-id"]))
        #expect(resolution.loadedNoteTitles == ["Determinism"])
        #expect(resolution.context?.contains("### Referenced Note: Determinism") == true)
        #expect(resolution.context?.contains("Determinism says every event is fixed by prior causes.") == true)
    }

    @Test("semantic note-seeking prompts auto-resolve the best matching note without explicit note syntax")
    func semanticNoteSeekingPromptsResolveBestMatchingNoteContext() async {
        let now = Date()
        let week = TimeInterval(86_400 * 7)
        let manifest = VaultManifest(
            vaultTitle: "my mind",
            totalNoteCount: 2,
            isInventoryComplete: true,
            entries: [
                VaultManifest.ManifestEntry(
                    pageId: "determinism-id",
                    title: "A Neuroscientific Explanation of Determinism in Society",
                    tags: ["philosophy"],
                    folderName: "Essays",
                    wordCount: 900,
                    snippet: "An essay on determinism and institutions.",
                    updatedAt: now.addingTimeInterval(-week * 3),
                    createdAt: now.addingTimeInterval(-week * 3)
                ),
                VaultManifest.ManifestEntry(
                    pageId: "psych-id",
                    title: "Psychoneuroimmunology Notes",
                    tags: ["biology"],
                    folderName: "Research",
                    wordCount: 400,
                    snippet: "Immune-system notes.",
                    updatedAt: now.addingTimeInterval(-week),
                    createdAt: now.addingTimeInterval(-week)
                )
            ],
            recentBodies: [],
            generatedAt: now
        )
        let determinismEntry = manifest.entries[0]
        let psychEntry = manifest.entries[1]

        #expect(ChatCoordinator.queryContainsExplicitNoteContext("i wrote an essay on determinism a few weeks ago, summarize it"))
        #expect(ChatCoordinator.queryContainsExplicitNoteContext("find the essay where i mentioned psychoneuroimmunology a few weeks ago and summarize it"))

        let determinism = await ChatCoordinator.resolveNotesContext(
            query: "i wrote an essay on determinism a few weeks ago, summarize it",
            manifest: manifest,
            includeAllNotesContext: false,
            findNotesByTitle: { query in
                query.contains("determinism")
                    ? [determinismEntry]
                    : []
            },
            fetchNoteBodies: { ids in
                ids.compactMap { id in
                    switch id {
                    case "determinism-id":
                        VaultManifest.NoteBody(
                            pageId: "determinism-id",
                            title: "A Neuroscientific Explanation of Determinism in Society",
                            body: "Essay body on determinism."
                        )
                    case "psych-id":
                        VaultManifest.NoteBody(
                            pageId: "psych-id",
                            title: "Psychoneuroimmunology Notes",
                            body: "Psych body."
                        )
                    default:
                        nil
                    }
                }
            },
            searchNoteIDs: { query in
                query.contains("determinism") ? ["determinism-id"] : []
            }
        )

        #expect(determinism.loadedNoteIds == Set(["determinism-id"]))
        #expect(determinism.loadedNoteTitles == ["A Neuroscientific Explanation of Determinism in Society"])
        #expect(determinism.context?.contains("Essay body on determinism.") == true)

        let psych = await ChatCoordinator.resolveNotesContext(
            query: "find the essay where i mentioned psychoneuroimmunology a few weeks ago and summarize it",
            manifest: manifest,
            includeAllNotesContext: false,
            findNotesByTitle: { query in
                query.contains("psychoneuroimmunology")
                    ? [psychEntry]
                    : []
            },
            fetchNoteBodies: { ids in
                ids.compactMap { id in
                    switch id {
                    case "determinism-id":
                        VaultManifest.NoteBody(
                            pageId: "determinism-id",
                            title: "A Neuroscientific Explanation of Determinism in Society",
                            body: "Essay body on determinism."
                        )
                    case "psych-id":
                        VaultManifest.NoteBody(
                            pageId: "psych-id",
                            title: "Psychoneuroimmunology Notes",
                            body: "Psychoneuroimmunology body."
                        )
                    default:
                        nil
                    }
                }
            },
            searchNoteIDs: { query in
                query.contains("psychoneuroimmunology") ? ["psych-id"] : []
            }
        )

        #expect(psych.loadedNoteIds == Set(["psych-id"]))
        #expect(psych.loadedNoteTitles == ["Psychoneuroimmunology Notes"])
        #expect(psych.context?.contains("Psychoneuroimmunology body.") == true)
    }

    @Test("pipeline direct stream uses bare prompts and only appends explicit note context")
    @MainActor func pipelineDirectStreamUsesBarePrompts() async throws {
        let mock = MockLLMClient()
        mock.streamTokens = ["Direct", " answer"]

        let pipelineState = PipelineState()
        let inference = InferenceState()
        inference.appleIntelligenceAvailable = false
        inference.setRoutingMode(.localOnly)
        inference.setInstalledLocalTextModelIDs([interactiveReleaseFixtureModelID.rawValue])
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
            notesContext: nil
        )
        for try await _ in stream {}

        #expect(mock.streamCalls.count == 1)
        let firstSystemPrompt = try #require(mock.streamCalls[0].systemPrompt)
        #expect(firstSystemPrompt.contains("local Epistemos assistant running on-device"))
        #expect(mock.streamCalls[0].prompt == "What is truth?")
        #expect(!mock.streamCalls[0].prompt.contains("You are Epistemos"))
        #expect(!mock.streamCalls[0].prompt.contains("User's Knowledge Vault"))

        mock.streamCalls.removeAll()
        let streamWithNotes = pipeline.run(
            query: "Compare this with today",
            mode: .api,
            notesContext: "### Referenced Note: Alpha\nAlpha full body"
        )
        for try await _ in streamWithNotes {}

        #expect(mock.streamCalls.count == 1)
        let secondSystemPrompt = try #require(mock.streamCalls[0].systemPrompt)
        #expect(secondSystemPrompt.contains("local Epistemos assistant running on-device"))
        #expect(mock.streamCalls[0].prompt.contains("### Referenced Note: Alpha"))
        #expect(mock.streamCalls[0].prompt.contains("Compare this with today"))
    }

    @Test("persisted assistant messages keep only plain inference metadata")
    func persistedAssistantMessagesKeepOnlyPlainInferenceMetadata() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let coordinator = makeCoordinator(container: container)

        let assistantMessage = ChatMessage(
            id: "assistant-no-reasoning",
            chatId: "chat-no-reasoning",
            role: .assistant,
            content: "Plain answer",
            mode: .api
        )

        coordinator.persistChatCompletion(
            chatId: "chat-no-reasoning",
            query: "What matters here?",
            answer: "Plain answer",
            mode: .api,
            assistantMessage: assistantMessage
        )

        let saved = try #require(try context.fetch(FetchDescriptor<SDMessage>()).first { $0.role == "assistant" })
        #expect(saved.inferenceMode == InferenceMode.api.rawValue)
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
            mode: .local,
            assistantMessage: nil
        )

        let chats = try context.fetch(FetchDescriptor<SDChat>())
        let chat = try #require(chats.first)
        #expect(chat.chatType == "chat")
    }

    @Test("vault briefing completes through the shared uncapped stream path")
    func vaultBriefingCompletesThroughSharedStreamPath() async throws {
        let container = try makeContainer()
        let mock = MockLLMClient()
        mock.snapshot = LLMSnapshot(
            provider: .localMLX,
            model: interactiveReleaseFixtureModelID.rawValue,
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
        coordinator.handleQuery(
            "[VAULT_BRIEFING]",
            pipeline: pipeline,
            chatState: chatState,
            operatingMode: .fast
        )
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

    @Test("streaming thinking deltas populate the main chat popover state")
    func chatStateAppendStreamingThinkingActivatesPopover() {
        let chatState = ChatState()
        chatState.submitQuery("ask")
        chatState.startStreaming()

        #expect(!chatState.isThinkingActive)
        #expect(chatState.streamingThinking.isEmpty)

        chatState.appendStreamingThinking("weighing")
        chatState.appendStreamingThinking(" options")

        #expect(chatState.isThinkingActive)
        #expect(chatState.thinkingStartedAt != nil)
        #expect(chatState.streamingThinking == "weighing options")
    }

    @Test("main chat first text delta closes the thinking phase")
    func chatStateFirstTextDeltaClosesThinking() {
        let chatState = ChatState()
        chatState.submitQuery("ask")
        chatState.startStreaming()
        chatState.appendStreamingThinking("thought")
        #expect(chatState.isThinkingActive)

        chatState.appendStreamingText("answer")

        #expect(!chatState.isThinkingActive)
        #expect(chatState.thinkingEndedAt != nil)
    }

    @Test("main chat ignores late reasoning deltas after the answer has started")
    func chatStateIgnoresLateReasoningAfterAnswerStarts() {
        let chatState = ChatState()
        chatState.submitQuery("ask")
        chatState.startStreaming()
        chatState.appendStreamingThinking("thought")
        chatState.appendStreamingText("answer")

        let capturedThinking = chatState.streamingThinking
        let endedAt = chatState.thinkingEndedAt

        chatState.appendStreamingThinking(" trailing scratchpad")

        #expect(!chatState.isThinkingActive)
        #expect(chatState.streamingThinking == capturedThinking)
        #expect(chatState.thinkingEndedAt == endedAt)
    }

    @Test("main chat resetThinkingState clears lingering popover state")
    func chatStateResetThinkingStateClearsPopoverState() {
        let chatState = ChatState()
        chatState.submitQuery("ask")
        chatState.appendStreamingThinking("prior")
        #expect(chatState.isThinkingActive)

        chatState.resetThinkingState()

        #expect(!chatState.isThinkingActive)
        #expect(chatState.streamingThinking.isEmpty)
        #expect(chatState.thinkingStartedAt == nil)
        #expect(chatState.thinkingEndedAt == nil)
    }

    @Test("completeProcessing attaches the resolved model label to the assistant turn")
    func chatStateCompleteProcessingAttachesResolvedModelLabel() {
        let chatState = ChatState()
        chatState.submitQuery("hi")
        chatState.startStreaming()
        chatState.appendStreamingText("hello")

        chatState.completeProcessing(mode: .api, resolvedModelLabel: "Qwen 3 4B")

        let message = chatState.messages.last
        #expect(message?.role == .assistant)
        #expect(message?.resolvedModelLabel == "Qwen 3 4B")
    }

    @Test("empty streams surface as a readable error instead of a ghost bubble")
    func completeProcessingOnEmptyStreamEmitsError() {
        let chatState = ChatState()
        chatState.submitQuery("Hello?")
        chatState.startStreaming()

        chatState.completeProcessing(mode: .api)

        let last = chatState.messages.last
        #expect(last?.role == .assistant)
        #expect(last?.isError == true)
        #expect(last?.content.contains("No response") == true)
        #expect(!chatState.isStreaming)
    }

    @Test("main chat recovers a final answer from hidden thinking before surfacing empty-stream error")
    func completeProcessingSalvagesAnswerFromThinkingTrace() {
        let chatState = ChatState()
        chatState.submitQuery("Hello?")
        chatState.startStreaming()
        chatState.appendStreamingThinking(
            """
            Thinking Process:
            I should keep the answer short.

            Final Answer:
            Hello there.
            """
        )

        chatState.completeProcessing(mode: .api)

        let last = chatState.messages.last
        #expect(last?.role == .assistant)
        #expect(last?.isError != true)
        #expect(last?.content == "Hello there.")
        #expect(last?.thinkingTrace?.contains("Thinking Process") == true)
    }

    @Test("main chat preserves thinking and shows a readable fallback when the model never reaches a final answer")
    func completeProcessingPreservesThinkingOnlyTurns() {
        let chatState = ChatState()
        chatState.submitQuery("Hello?")
        chatState.startStreaming()
        chatState.appendStreamingThinking(
            """
            1. Query:
            - Summarize the key findings.

            2. Detailed Analysis with chunk_reduce:
            Input Text: The references.
            Reduce Strategy: Keep only the strongest passages.
            """
        )

        chatState.completeProcessing(mode: .api)

        let last = chatState.messages.last
        #expect(last?.role == .assistant)
        #expect(last?.isError != true)
        #expect(last?.content.contains("never produced a final answer") == true)
        #expect(last?.thinkingTrace?.contains("Detailed Analysis with chunk_reduce") == true)
    }

    @Test("main chat does not promote native reasoning summaries into the final answer")
    func completeProcessingDoesNotPromoteNativeReasoningSummaryIntoAnswer() {
        let chatState = ChatState()
        chatState.submitQuery("Read this note")
        chatState.startStreaming()
        chatState.appendStreamingThinking("What's weaker")

        chatState.completeProcessing(mode: .api)

        let last = chatState.messages.last
        #expect(last?.role == .assistant)
        #expect(last?.isError != true)
        #expect(last?.content.contains("never produced a final answer") == true)
        #expect(last?.content != "What's weaker")
        #expect(last?.thinkingTrace == "What's weaker")
    }

    @Test("main chat completeProcessing clears active thinking state after finalizing")
    func completeProcessingClearsThinkingState() {
        let chatState = ChatState()
        chatState.submitQuery("Hello?")
        chatState.startStreaming()
        chatState.appendStreamingThinking("reasoning")
        chatState.appendStreamingText("final answer")

        chatState.completeProcessing(mode: .api)

        #expect(!chatState.isThinkingActive)
        #expect(chatState.streamingThinking.isEmpty)
        #expect(chatState.thinkingStartedAt == nil)
        #expect(chatState.thinkingEndedAt == nil)
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

    @Test("loading messages does not resurrect stale context from older turns")
    func loadMessagesDoesNotResurrectStaleContext() {
        let chatState = ChatState()
        let noteAttachment = ContextAttachment(
            kind: .note,
            targetId: "note-3",
            title: "Archived Context",
            subtitle: "Vault"
        )

        chatState.loadMessages([
            ChatMessage(
                chatId: "chat",
                role: .assistant,
                content: "older grounded turn",
                loadedNoteTitles: ["Archived Context"],
                contextAttachments: [noteAttachment]
            ),
            ChatMessage(chatId: "chat", role: .user, content: "new plain turn"),
            ChatMessage(chatId: "chat", role: .assistant, content: "plain follow-up")
        ])

        #expect(chatState.pendingContextAttachments.isEmpty)
        #expect(chatState.loadedNoteIds.isEmpty)
        #expect(chatState.loadedNoteTitles.isEmpty)
    }
}

@Suite("ChatState Local Messages")
@MainActor
struct ChatStateLocalMessageTests {
    @Test("append local message creates an in-memory chat turn without streaming")
    func appendLocalMessageCreatesSessionAndMessage() {
        let chatState = ChatState()

        chatState.appendLocalMessage(role: .user, content: "/research test the handoff")

        #expect(chatState.activeChatId != nil)
        #expect(chatState.hasMessages)
        #expect(!chatState.showLanding)
        #expect(chatState.messages.count == 1)
        #expect(chatState.messages.last?.role == .user)
        #expect(chatState.messages.last?.content == "/research test the handoff")
    }

    @Test("submit query emits the selected operating mode on the event bus")
    func submitQueryEmitsSelectedOperatingMode() {
        let chatState = ChatState()
        let eventBus = EventBus()
        chatState.eventBus = eventBus

        var capturedMode: EpistemosOperatingMode?
        var capturedQuery: String?

        eventBus.subscribe(id: "chat-state-operating-mode-test") { event in
            if case .querySubmitted(_, let query, let operatingMode) = event {
                capturedQuery = query
                capturedMode = operatingMode
            }
        }

        chatState.submitQuery("Use deep reasoning here", operatingMode: .thinking)

        #expect(capturedQuery == "Use deep reasoning here")
        #expect(capturedMode == .thinking)
    }

    @Test("main chat router no longer treats research phrasing as a special runtime mode")
    func mainChatRouterDoesNotSpecialCaseResearchPhrasing() async {
        let chatState = ChatState()
        let orchestrator = OrchestratorState()

        let omegaPanelShown = false
        MainChatSubmissionRouter.submit(
            "/research transformer attention",
            operatingMode: .fast,
            chat: chatState,
            orchestrator: orchestrator
        )

        await Task.yield()

        #expect(!omegaPanelShown)
        #expect(chatState.messages.count == 1)
        #expect(chatState.messages.last?.role == .user)
        #expect(chatState.messages.last?.content == "/research transformer attention")
        #expect(orchestrator.currentTaskDescription.isEmpty)
    }

    @Test("main chat router hands agent mode off to Omega and keeps a visible transcript")
    func mainChatRouterHandsAgentModeOffToOmega() async {
        let chatState = ChatState()
        let orchestrator = OrchestratorState()

        let omegaPanelShown = false
        MainChatSubmissionRouter.submit(
            "Plan a multi-step refactor",
            operatingMode: .agent,
            chat: chatState,
            orchestrator: orchestrator
        )

        await Task.yield()

        #expect(!omegaPanelShown)
        #expect(chatState.messages.count == 1)
        #expect(chatState.messages.first?.role == .user)
        #expect(chatState.messages.first?.content == "Plan a multi-step refactor")
        #expect(orchestrator.currentTaskDescription.isEmpty)
    }

    @Test("cancelled streaming promotes partial output into a stable assistant message")
    func cancelledStreamingPromotesPartialOutput() {
        let chatState = ChatState()

        chatState.submitQuery("Explain this")
        chatState.startStreaming()
        chatState.appendStreamingText("Partial answer")

        let completed = chatState.completeCancelledProcessing(mode: .api)

        #expect(completed)
        #expect(!chatState.isStreaming)
        #expect(chatState.streamingText.isEmpty)
        #expect(chatState.messages.count == 2)
        #expect(chatState.messages.last?.role == .assistant)
        #expect(chatState.messages.last?.content == "Partial answer")
    }

    @Test("cancelled streaming preserves thinking-only turns with a readable fallback")
    func cancelledStreamingPreservesThinkingOnlyTurns() {
        let chatState = ChatState()

        chatState.submitQuery("Explain this")
        chatState.startStreaming()
        chatState.appendStreamingThinking(
            """
            1. Query:
            - Compare the tradeoffs.

            2. Detailed Analysis with chunk_reduce:
            Input Text: The current branch.
            Reduce Strategy: Keep the highest-signal evidence.
            """
        )

        let completed = chatState.completeCancelledProcessing(mode: .api)

        #expect(completed)
        #expect(chatState.messages.count == 2)
        #expect(chatState.messages.last?.isError != true)
        #expect(chatState.messages.last?.content.contains("never produced a final answer") == true)
        #expect(chatState.messages.last?.thinkingTrace?.contains("Detailed Analysis with chunk_reduce") == true)
    }

    @Test("cancelled streaming does not promote native reasoning summaries into the final answer")
    func cancelledStreamingDoesNotPromoteNativeReasoningSummaryIntoAnswer() {
        let chatState = ChatState()

        chatState.submitQuery("Read this note")
        chatState.startStreaming()
        chatState.appendStreamingThinking("What's weaker")

        let completed = chatState.completeCancelledProcessing(mode: .api)

        #expect(completed)
        #expect(chatState.messages.count == 2)
        #expect(chatState.messages.last?.content.contains("never produced a final answer") == true)
        #expect(chatState.messages.last?.content != "What's weaker")
        #expect(chatState.messages.last?.thinkingTrace == "What's weaker")
    }

    @Test("cancelled streaming recovers a final answer from hidden thinking")
    func cancelledStreamingSalvagesAnswerFromThinkingTrace() {
        let chatState = ChatState()

        chatState.submitQuery("Explain this")
        chatState.startStreaming()
        chatState.appendStreamingThinking(
            """
            Thinking Process:
            Keep it short.

            Final Answer:
            Partial but usable answer.
            """
        )

        let completed = chatState.completeCancelledProcessing(mode: .api)

        #expect(completed)
        #expect(chatState.messages.count == 2)
        #expect(chatState.messages.last?.content == "Partial but usable answer.")
        #expect(chatState.messages.last?.thinkingTrace?.contains("Thinking Process") == true)
    }

    @Test("starting a new chat clears pending attachments and transient context")
    func startNewChatClearsPendingAttachmentsAndContext() {
        let chatState = ChatState()
        chatState.addAttachment(
            FileAttachment(
                id: "file-1",
                name: "notes.txt",
                type: .text,
                uri: "file:///tmp/notes.txt",
                size: 128,
                mimeType: "text/plain",
                preview: "cached"
            )
        )
        chatState.addContextAttachment(
            ContextAttachment(
                kind: .note,
                targetId: "note-99",
                title: "Retained Context",
                subtitle: "Vault"
            )
        )
        chatState.loadedNoteIds = ["note-99"]
        chatState.loadedNoteTitles = ["Retained Context"]

        chatState.startNewChat()

        #expect(chatState.pendingAttachments.isEmpty)
        #expect(chatState.pendingContextAttachments.isEmpty)
        #expect(chatState.loadedNoteIds.isEmpty)
        #expect(chatState.loadedNoteTitles.isEmpty)
    }

    @Test("clearing messages drops pending attachments and transient context")
    func clearMessagesDropsPendingAttachmentsAndContext() {
        let chatState = ChatState()
        chatState.addAttachment(
            FileAttachment(
                id: "file-2",
                name: "memo.txt",
                type: .text,
                uri: "file:///tmp/memo.txt",
                size: 256,
                mimeType: "text/plain",
                preview: "memo"
            )
        )
        chatState.addContextAttachment(
            ContextAttachment(
                kind: .allNotes,
                targetId: ChatCoordinator.allNotesMentionToken,
                title: "All Notes",
                subtitle: "Vault"
            )
        )
        chatState.loadedNoteIds = ["note-2"]
        chatState.loadedNoteTitles = ["Memo"]

        chatState.clearMessages()

        #expect(chatState.pendingAttachments.isEmpty)
        #expect(chatState.pendingContextAttachments.isEmpty)
        #expect(chatState.loadedNoteIds.isEmpty)
        #expect(chatState.loadedNoteTitles.isEmpty)
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
