import Foundation
import Testing
@testable import Epistemos

@MainActor
private final class ReasoningLoopEventSink {
    private(set) var events: [AgentProvenanceEvent] = []

    func append(_ event: AgentProvenanceEvent) -> Bool {
        events.append(event)
        return true
    }
}

@MainActor
private final class ReasoningLoopProvenanceLLMClient: LLMClientProtocol {
    private var generateResponses: [String]
    private let streamTokens: [String]

    init(generateResponses: [String], streamTokens: [String] = ["final"]) {
        self.generateResponses = generateResponses
        self.streamTokens = streamTokens
    }

    func generate(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String {
        _ = prompt
        _ = systemPrompt
        _ = maxTokens
        guard !generateResponses.isEmpty else { return "" }
        return generateResponses.removeFirst()
    }

    func stream(prompt: String, systemPrompt: String?, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        _ = prompt
        _ = systemPrompt
        _ = maxTokens
        let tokens = streamTokens
        return AsyncThrowingStream { continuation in
            for token in tokens {
                continuation.yield(token)
            }
            continuation.finish()
        }
    }

    func testConnection() async -> ConnectionTestResult {
        ConnectionTestResult(success: true, message: "Reasoning loop provenance test client connected")
    }

    func configSnapshot() -> LLMSnapshot {
        LLMSnapshot(
            provider: .localMLX,
            model: LocalTextModelID.qwen35_2B4Bit.rawValue,
            reasoningMode: .thinking
        )
    }
}

@Suite("ReasoningLoop AgentEvent Provenance")
@MainActor
struct ReasoningLoopAgentEventTests {
    @Test("reasoning loop records internal tool calls as AgentEvent provenance")
    func reasoningLoopRecordsInternalToolCallsAsAgentEvents() async throws {
        let modelID = LocalTextModelID.qwen35_2B4Bit.rawValue
        let inference = InferenceState()
        inference.routingMode = .localOnly
        inference.preferredLocalTextModelID = modelID
        inference.preferredChatModelSelection = .localMLX(modelID)
        inference.setInstalledLocalTextModelIDs([modelID])

        let llm = ReasoningLoopProvenanceLLMClient(generateResponses: [
            "Initial reasoning.",
            #"Score: 0.95 {"name":"vault_search","arguments":{"query":"provenance"}}"#,
            "Refined answer with search evidence."
        ])
        let triage = TriageService(inference: inference, localLLMService: llm)
        let sink = ReasoningLoopEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 42 },
            persist: { event in sink.append(event) }
        )
        let service = ReasoningLoopService(
            triageService: triage,
            agentProvenanceRecorder: recorder
        )
        service.config.enabled = true
        service.config.maxRounds = 1
        service.config.qualityThreshold = 0.9
        service.config.enableToolUse = true

        var finalOutput = ""
        let stream = service.streamWithReasoning(
            prompt: "Find provenance evidence",
            operation: .analyze,
            contentLength: 10_000,
            operatingMode: .thinking
        )
        for try await token in stream {
            finalOutput += token
        }

        #expect(finalOutput == "final")
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallCompleted
        ])
        #expect(Set(sink.events.map(\.runID)).count == 1)
        #expect(sink.events.first?.runID.hasPrefix("reasoning-loop-") == true)
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "vault_search" })
        #expect(sink.events.allSatisfy { $0.tool?.toolCallID == "reasoning-tool:0:1" })
        #expect(sink.events.allSatisfy { $0.tool?.argumentsJSON.contains("provenance") == true })
        #expect(sink.events.allSatisfy { $0.metadata["source"] == "omega_reasoning_loop" })
        #expect(sink.events.allSatisfy { $0.metadata["round_index"] == "0" })
        #expect(sink.events.allSatisfy { $0.metadata["tool_sequence"] == "1" })
        #expect(sink.events.last?.tool?.resultJSON?.contains("\"text\"") == true)

        if case .agent(let id, let modelID) = sink.events.first?.actor {
            #expect(id == "omega-reasoning-loop")
            #expect(modelID == nil)
        } else {
            Issue.record("Reasoning loop tool event should be attributed to omega-reasoning-loop")
        }
    }
}
