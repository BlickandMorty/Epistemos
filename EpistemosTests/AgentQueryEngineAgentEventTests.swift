import Foundation
import Testing
@testable import Epistemos

@MainActor
private final class AgentQueryEngineAgentEventSink {
    private(set) var events: [AgentProvenanceEvent] = []

    func append(_ event: AgentProvenanceEvent) -> Bool {
        events.append(event)
        return true
    }
}

@MainActor
@Suite("AgentQueryEngine AgentEvent provenance")
struct AgentQueryEngineAgentEventTests {
    @Test("AgentQueryEngine records sanitized backend tool AgentEvents")
    func recordsSanitizedBackendToolAgentEvents() async throws {
        let identifier = "test.agent-query-engine-provenance.\(UUID().uuidString)"
        let backend = AgentQueryEngineToolStreamBackend(
            identifier: identifier,
            events: [
                .toolUse(
                    id: "tool-secret-1",
                    name: "vault_read",
                    input: Data(#"{"path":"/private/vault/secret.md","prompt":"hidden"}"#.utf8)
                ),
                .toolResult(
                    id: "tool-secret-1",
                    output: "secret output text from /private/vault/secret.md",
                    isError: false
                ),
                .complete(sessionID: "session-secret", stopReason: "stop")
            ]
        )
        BackendRegistry.shared.register(backend)

        let sink = AgentQueryEngineAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 1_515 },
            persist: { event in sink.append(event) }
        )
        let engine = AgentQueryEngine(config: AgentQueryEngineConfig(
            backendIdentifier: identifier,
            systemPrompt: "secret system prompt",
            cwd: "/private/vault",
            model: "model-secret",
            agentProvenanceRecorder: recorder
        ))

        var streamEvents: [AgentQueryEngineEvent] = []
        for try await event in await engine.submitMessage("secret user prompt") {
            streamEvents.append(event)
        }

        #expect(streamEvents.contains { if case .toolStarted("tool-secret-1", "vault_read") = $0 { true } else { false } })
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallCompleted
        ])
        #expect(Set(sink.events.map(\.runID)).count == 1)
        #expect(sink.events.first?.runID.hasPrefix("agent-query-engine-") == true)
        #expect(sink.events.allSatisfy { $0.tool?.toolCallID == "tool-secret-1" })
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "vault_read" })
        #expect(sink.events.allSatisfy { $0.metadata["source"] == "agent_query_engine" })
        #expect(sink.events.allSatisfy { $0.metadata["surface"] == "agent_harness" })
        #expect(sink.events.allSatisfy { $0.metadata["backend"] == identifier })
        #expect(sink.events.allSatisfy { $0.metadata["model"] == "model-secret" })
        #expect(sink.events.last?.tool?.durationMs != nil)
        #expect(sink.events.last?.tool?.resultJSON?.contains("output_byte_count") == true)
        #expect(sink.events.last?.tool?.resultJSON?.contains("is_error") == true)

        for event in sink.events {
            let tool = try #require(event.tool)
            #expect(!tool.argumentsJSON.contains("secret user prompt"))
            #expect(!tool.argumentsJSON.contains("secret system prompt"))
            #expect(!tool.argumentsJSON.contains("/private/vault"))
            #expect(!tool.argumentsJSON.contains("hidden"))
            #expect(!(tool.resultJSON ?? "").contains("secret output text"))
            #expect(!(tool.resultJSON ?? "").contains("/private/vault"))
            #expect(!(tool.resultJSON ?? "").contains("session-secret"))
        }

        if case .agent(let id, let modelID) = sink.events.first?.actor {
            #expect(id == "agent-query-engine")
            #expect(modelID == "model-secret")
        } else {
            Issue.record("AgentQueryEngine events should be attributed to agent-query-engine.")
        }
    }

    @Test("AgentQueryEngine records sanitized failed backend tool AgentEvents")
    func recordsSanitizedFailedBackendToolAgentEvents() async throws {
        let identifier = "test.agent-query-engine-failed-provenance.\(UUID().uuidString)"
        let backend = AgentQueryEngineToolStreamBackend(
            identifier: identifier,
            events: [
                .toolUse(
                    id: "tool-secret-2",
                    name: "vault_write",
                    input: Data(#"{"body":"secret body","path":"/private/vault/write.md"}"#.utf8)
                ),
                .toolResult(
                    id: "tool-secret-2",
                    output: "failed with secret body at /private/vault/write.md",
                    isError: true
                ),
                .complete(sessionID: nil, stopReason: "stop")
            ]
        )
        BackendRegistry.shared.register(backend)

        let sink = AgentQueryEngineAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 1_616 },
            persist: { event in sink.append(event) }
        )
        let engine = AgentQueryEngine(config: AgentQueryEngineConfig(
            backendIdentifier: identifier,
            cwd: "/private/vault",
            agentProvenanceRecorder: recorder
        ))

        for try await _ in await engine.submitMessage("secret failed prompt") {}

        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallFailed
        ])
        #expect(sink.events.last?.tool?.status == .failed)
        #expect(sink.events.last?.tool?.errorMessage == "tool_result_error")

        for event in sink.events {
            let tool = try #require(event.tool)
            #expect(!tool.argumentsJSON.contains("secret failed prompt"))
            #expect(!tool.argumentsJSON.contains("secret body"))
            #expect(!tool.argumentsJSON.contains("/private/vault"))
            #expect(!(tool.resultJSON ?? "").contains("failed with secret body"))
            #expect(!(tool.resultJSON ?? "").contains("write.md"))
        }
    }
}

private struct AgentQueryEngineToolStreamBackend: AgentBackend {
    let identifier: String
    let displayName = "AgentQueryEngine tool stream test backend"
    let events: [AgentBackendEvent]

    func execute(
        prompt: String,
        history: [String],
        options: AgentExecOptions
    ) async throws -> AsyncThrowingStream<AgentBackendEvent, Error> {
        AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}
