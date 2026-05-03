import Foundation
import Testing
@testable import Epistemos

@MainActor
private final class AppleIntelligenceAgentEventSink {
    private(set) var events: [AgentProvenanceEvent] = []

    func append(_ event: AgentProvenanceEvent) -> Bool {
        events.append(event)
        return true
    }
}

private enum AppleIntelligenceAgentEventTestError: Error {
    case backendSecret
}

@MainActor
@Suite("Apple Intelligence AgentEvent Provenance")
struct AppleIntelligenceServiceAgentEventTests {
    @Test("Apple Intelligence generate records sanitized AgentEvents")
    func generateRecordsSanitizedAgentEvents() async throws {
        let sink = AppleIntelligenceAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 456 },
            persist: { event in sink.append(event) }
        )
        let service = AppleIntelligenceService(
            agentProvenanceRecorder: recorder,
            systemPromptResolver: { systemPrompt in
                [systemPrompt, "secret augmented vault context"]
                    .compactMap { $0 }
                    .joined(separator: "\n")
            },
            thermalClearance: {},
            thermalPauseRecorder: {},
            breakerExecutor: { work in try await work() },
            foundationModelsGenerate: { prompt, systemPrompt in
                #expect(prompt == "secret apple prompt")
                #expect(systemPrompt?.contains("secret augmented vault context") == true)
                return "Secret Apple output"
            }
        )

        let output = try await service.generate(
            prompt: "secret apple prompt",
            systemPrompt: "secret apple system"
        )

        #expect(output == "Secret Apple output")
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallCompleted
        ])
        #expect(Set(sink.events.map(\.runID)).count == 1)
        #expect(sink.events.first?.runID.hasPrefix("apple-intelligence-generate-") == true)
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "apple_intelligence.generate" })
        #expect(sink.events.allSatisfy { $0.tool?.toolCallID == "apple-intelligence-generate:1" })
        #expect(sink.events.allSatisfy { $0.metadata["source"] == "apple_intelligence_service" })
        #expect(sink.events.allSatisfy { $0.metadata["surface"] == "generate" })
        #expect(sink.events.allSatisfy { $0.metadata["provider"] == "apple_intelligence" })
        #expect(sink.events.allSatisfy { $0.metadata["prompt_char_count"] == "19" })
        #expect(sink.events.allSatisfy { $0.metadata["system_prompt_char_count"] == "19" })
        #expect(sink.events.allSatisfy { $0.metadata["resolved_system_prompt_char_count"] == "50" })
        #expect(sink.events.allSatisfy { $0.metadata["augmented_system_prompt_present"] == "true" })
        #expect(sink.events.last?.tool?.status == .completed)
        #expect(sink.events.last?.tool?.errorMessage == nil)

        let argumentsPayload = try payload(from: sink.events.first?.tool?.argumentsJSON)
        #expect(Set(argumentsPayload.keys) == [
            "augmented_system_prompt_present",
            "prompt_char_count",
            "provider",
            "resolved_system_prompt_char_count",
            "system_prompt_char_count"
        ])
        #expect(argumentsPayload["provider"] as? String == "apple_intelligence")
        #expect(argumentsPayload["prompt_char_count"] as? Int == 19)
        #expect(argumentsPayload["system_prompt_char_count"] as? Int == 19)
        #expect(argumentsPayload["resolved_system_prompt_char_count"] as? Int == 50)
        #expect(argumentsPayload["augmented_system_prompt_present"] as? Bool == true)

        let resultPayload = try payload(from: sink.events.last?.tool?.resultJSON)
        #expect(Set(resultPayload.keys) == ["elapsed_ms", "output_char_count", "success"])
        #expect(resultPayload["success"] as? Bool == true)
        #expect(resultPayload["output_char_count"] as? Int == 19)

        try assertNoAppleIntelligenceSecretLeak(
            in: sink.events,
            forbidden: [
                "secret apple prompt",
                "secret apple system",
                "secret augmented vault context",
                "Secret Apple output"
            ]
        )
    }

    @Test("Apple Intelligence generate records sanitized failed AgentEvent")
    func generateRecordsSanitizedFailedAgentEvent() async throws {
        let sink = AppleIntelligenceAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 457 },
            persist: { event in sink.append(event) }
        )
        let service = AppleIntelligenceService(
            agentProvenanceRecorder: recorder,
            systemPromptResolver: { systemPrompt in
                [systemPrompt, "secret augmented vault context"]
                    .compactMap { $0 }
                    .joined(separator: "\n")
            },
            thermalClearance: {},
            thermalPauseRecorder: {},
            breakerExecutor: { work in try await work() },
            foundationModelsGenerate: { _, _ in
                throw AppleIntelligenceAgentEventTestError.backendSecret
            }
        )

        do {
            _ = try await service.generate(
                prompt: "secret apple prompt",
                systemPrompt: "secret apple system"
            )
            Issue.record("Expected Apple Intelligence generation to fail.")
        } catch AppleIntelligenceAgentEventTestError.backendSecret {
        } catch {
            Issue.record("Expected backendSecret failure, got \(error).")
        }

        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallFailed
        ])
        #expect(sink.events.last?.tool?.status == .failed)
        #expect(sink.events.last?.tool?.errorMessage == "generation_failed")
        #expect(sink.events.last?.metadata["failure_class"] == "generation_failed")

        let resultPayload = try payload(from: sink.events.last?.tool?.resultJSON)
        #expect(Set(resultPayload.keys) == ["elapsed_ms", "output_char_count", "success"])
        #expect(resultPayload["success"] as? Bool == false)
        #expect(resultPayload["output_char_count"] as? Int == 0)

        try assertNoAppleIntelligenceSecretLeak(
            in: sink.events,
            forbidden: [
                "secret apple prompt",
                "secret apple system",
                "secret augmented vault context",
                "backendSecret"
            ]
        )
    }

    private func payload(from json: String?) throws -> [String: Any] {
        let json = try #require(json)
        let data = try #require(json.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }

    private func assertNoAppleIntelligenceSecretLeak(
        in events: [AgentProvenanceEvent],
        forbidden: [String],
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        for event in events {
            let haystack = [
                event.runID,
                event.traceID,
                event.tool?.toolCallID,
                event.tool?.toolName,
                event.tool?.argumentsJSON,
                event.tool?.resultJSON,
                event.tool?.errorMessage,
                event.metadata.description,
            ]
                .compactMap { $0 }
                .joined(separator: "\n")

            for secret in forbidden {
                #expect(!haystack.contains(secret), sourceLocation: sourceLocation)
            }
        }
    }
}
