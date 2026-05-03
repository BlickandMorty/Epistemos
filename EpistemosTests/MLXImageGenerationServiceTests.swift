import Foundation
import Testing
@testable import Epistemos

@MainActor
private final class MLXImageGenerationAgentEventSink {
    private(set) var events: [AgentProvenanceEvent] = []

    func append(_ event: AgentProvenanceEvent) -> Bool {
        events.append(event)
        return true
    }
}

private struct StubMLXImagePipeline: MLXImageGenerationPipeline {
    let modelID: String
    let generatedPath: String

    func generate(prompt _: String, aspectRatio _: String) async throws -> String {
        generatedPath
    }
}

@Suite("MLX image generation AgentEvent provenance")
struct MLXImageGenerationServiceTests {
    @MainActor
    @Test("successful MLX image generation records sanitized AgentEvents")
    func successfulGenerationRecordsSanitizedAgentEvents() async throws {
        let sink = MLXImageGenerationAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(persist: { event in
            sink.append(event)
        })
        let service = MLXImageGenerationService(
            agentProvenanceRecorder: recorder,
            pipelineResolver: {
                StubMLXImagePipeline(
                    modelID: "mlx-flux-secret-model",
                    generatedPath: "/Users/jojo/private/generated/secret-image.png"
                )
            }
        )

        let response = await service.generate(
            prompt: "private cathedral diagram with vault names",
            aspectRatio: "16:9"
        )
        let responsePayload = try payload(from: response)

        #expect(responsePayload["image_path"] as? String == "/Users/jojo/private/generated/secret-image.png")
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallCompleted
        ])
        #expect(Set(sink.events.map(\.runID)).count == 1)
        #expect(sink.events.first?.runID.hasPrefix("mlx-image-generation-") == true)
        #expect(sink.events.allSatisfy { event in
            if case .agent(let id, _) = event.actor {
                return id == "mlx-image-generation-service"
            }
            return false
        })
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "image_generate.mlx" })
        #expect(sink.events.allSatisfy { $0.tool?.toolCallID == "mlx-image-generation:1" })
        #expect(sink.events.allSatisfy { $0.metadata["source"] == "mlx_image_generation_service" })
        #expect(sink.events.allSatisfy { $0.metadata["surface"] == "image_generate" })
        #expect(sink.events.allSatisfy { $0.metadata["provider"] == "mlx" })
        #expect(sink.events.allSatisfy { $0.metadata["aspect_ratio"] == "16:9" })
        #expect(sink.events.allSatisfy { $0.metadata["prompt_char_count"] == "42" })

        let argumentsPayload = try payload(from: sink.events.first?.tool?.argumentsJSON)
        #expect(Set(argumentsPayload.keys) == ["aspect_ratio", "prompt_char_count", "provider"])
        #expect(argumentsPayload["prompt_char_count"] as? Int == 42)
        #expect(argumentsPayload["aspect_ratio"] as? String == "16:9")
        #expect(argumentsPayload["provider"] as? String == "mlx")

        let resultPayload = try payload(from: sink.events.last?.tool?.resultJSON)
        #expect(Set(resultPayload.keys) == ["elapsed_ms", "success"])
        #expect(resultPayload["success"] as? Bool == true)
        #expect(sink.events.last?.tool?.status == .completed)
        #expect(sink.events.last?.tool?.errorMessage == nil)

        try assertNoImageGenerationSecretLeak(
            in: sink.events,
            forbidden: [
                "private cathedral",
                "vault names",
                "/Users/jojo/private/generated/secret-image.png",
                "mlx-flux-secret-model",
                "provider: \\\"fal\\\"",
                "provider='fal'"
            ]
        )
    }

    @MainActor
    @Test("unavailable MLX pipeline records terminal failed AgentEvent")
    func unavailablePipelineRecordsTerminalFailedAgentEvent() async throws {
        let sink = MLXImageGenerationAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(persist: { event in
            sink.append(event)
        })
        let service = MLXImageGenerationService(
            agentProvenanceRecorder: recorder,
            pipelineResolver: {
                throw MLXImageGenerationError.fluxPipelineUnavailable
            }
        )

        let response = await service.generate(
            prompt: "private image prompt that must not persist",
            aspectRatio: "1:1"
        )

        #expect(response.contains("\"provider\":\"mlx\""))
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallFailed
        ])
        #expect(sink.events.last?.tool?.status == .failed)
        #expect(sink.events.last?.tool?.errorMessage == "flux_pipeline_unavailable")
        #expect(sink.events.last?.metadata["failure_class"] == "flux_pipeline_unavailable")

        let resultPayload = try payload(from: sink.events.last?.tool?.resultJSON)
        #expect(Set(resultPayload.keys) == ["elapsed_ms", "success"])
        #expect(resultPayload["success"] as? Bool == false)

        try assertNoImageGenerationSecretLeak(
            in: sink.events,
            forbidden: [
                "private image prompt",
                "must not persist",
                "Flux image generation is not yet wired",
                "provider: \"fal\"",
                "provider: \\\"fal\\\"",
                "provider='fal'"
            ]
        )
    }

    private func payload(from json: String?) throws -> [String: Any] {
        let json = try #require(json)
        let data = try #require(json.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data)
        return try #require(object as? [String: Any])
    }

    private func assertNoImageGenerationSecretLeak(
        in events: [AgentProvenanceEvent],
        forbidden: [String],
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let persisted = try events.map { event -> String in
            let data = try JSONEncoder().encode(event)
            return try #require(String(data: data, encoding: .utf8))
        }.joined(separator: "\n")

        for value in forbidden {
            #expect(!persisted.contains(value), "AgentEvent persisted forbidden value: \(value)", sourceLocation: sourceLocation)
        }
    }
}
