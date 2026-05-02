import Foundation
import Testing
@testable import Epistemos

@MainActor
private final class CloudLLMAgentEventSink {
    private(set) var events: [AgentProvenanceEvent] = []

    func append(_ event: AgentProvenanceEvent) -> Bool {
        events.append(event)
        return true
    }
}

@MainActor
private func makeCloudLLMInferenceState(keychainValues: [String: String]) -> InferenceState {
    let store = TestKeychainStore(values: keychainValues)
    return InferenceState(
        keychainLoad: store.load(_:),
        keychainSave: store.save(_:_:),
        keychainDelete: store.delete(_:)
    )
}

@MainActor
@Suite("CloudLLM AgentEvent Provenance")
struct CloudLLMAgentEventTests {
    @Test("cloud generate records sanitized AgentEvents")
    func cloudGenerateRecordsSanitizedAgentEvents() async throws {
        let inference = makeCloudLLMInferenceState(keychainValues: [
            CloudModelProvider.openAI.apiKeyKeychainKey: "sk-openai-test"
        ])
        let session = makeCloudLLMAgentEventURLSession { request in
            let url = try #require(request.url)
            #expect(url.path == "/v1/responses")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-openai-test")

            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = """
            {
              "output_text": "done"
            }
            """.data(using: .utf8) ?? Data()
            return (response, data)
        }
        let sink = CloudLLMAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 123 },
            persist: { event in sink.append(event) }
        )
        let client = CloudLLMClient(
            inference: inference,
            urlSession: session,
            agentProvenanceRecorder: recorder
        )

        let output = try await client.generate(
            prompt: "secret prompt",
            systemPrompt: "secret system",
            maxTokens: 64,
            model: .openAIGPT54,
            operatingMode: .pro
        )

        #expect(output == "done")
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallCompleted
        ])
        #expect(Set(sink.events.map(\.runID)).count == 1)
        #expect(sink.events.first?.runID.hasPrefix("cloud-llm-") == true)
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "cloud_model.generate" })
        #expect(sink.events.allSatisfy { $0.tool?.toolCallID == "cloud-llm-generate:1" })
        #expect(sink.events.allSatisfy { $0.metadata["source"] == "cloud_llm_client" })
        #expect(sink.events.allSatisfy { $0.metadata["provider"] == CloudModelProvider.openAI.rawValue })
        #expect(sink.events.allSatisfy { $0.metadata["model"] == CloudTextModelID.openAIGPT54.vendorModelID })
        #expect(sink.events.allSatisfy { $0.metadata["operating_mode"] == EpistemosOperatingMode.pro.rawValue })
        #expect(sink.events.allSatisfy { $0.metadata["route"] == HermesGatewayRoute.hermesGateway.rawValue })
        #expect(sink.events.last?.tool?.durationMs != nil)
        #expect(sink.events.last?.tool?.resultJSON?.contains("output_length") == true)

        for event in sink.events {
            let argumentsJSON = event.tool?.argumentsJSON ?? ""
            let resultJSON = event.tool?.resultJSON ?? ""
            #expect(!argumentsJSON.contains("secret prompt"))
            #expect(!argumentsJSON.contains("secret system"))
            #expect(!argumentsJSON.contains("sk-openai-test"))
            #expect(!resultJSON.contains("done"))
        }

        if case .agent(let id, let modelID) = sink.events.first?.actor {
            #expect(id == "cloud-llm-client")
            #expect(modelID == CloudTextModelID.openAIGPT54.vendorModelID)
        } else {
            Issue.record("Cloud generation events should be attributed to cloud-llm-client.")
        }
    }

    @Test("cloud generate records sanitized failure before provider request")
    func cloudGenerateRecordsSanitizedFailureBeforeProviderRequest() async throws {
        let inference = makeCloudLLMInferenceState(keychainValues: [:])
        let sink = CloudLLMAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 456 },
            persist: { event in sink.append(event) }
        )
        let client = CloudLLMClient(
            inference: inference,
            agentProvenanceRecorder: recorder
        )

        do {
            _ = try await client.generate(
                prompt: "secret prompt",
                systemPrompt: "secret system",
                maxTokens: 64,
                model: .openAIGPT54,
                operatingMode: .pro
            )
            Issue.record("Expected missing OpenAI access to fail generation.")
        } catch let error as CloudLLMError {
            switch error {
            case .missingAccess("OpenAI"):
                break
            default:
                Issue.record("Expected missing OpenAI access, got \(error).")
            }
        } catch {
            Issue.record("Expected CloudLLMError.missingAccess, got \(error).")
        }

        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallFailed
        ])
        #expect(sink.events.last?.tool?.status == .failed)
        #expect(sink.events.last?.tool?.durationMs != nil)
        #expect(sink.events.allSatisfy { $0.metadata["route"] == HermesGatewayRoute.hermesGateway.rawValue })

        for event in sink.events {
            let tool = try #require(event.tool)
            #expect(!tool.argumentsJSON.contains("secret prompt"))
            #expect(!tool.argumentsJSON.contains("secret system"))
            #expect(tool.resultJSON == nil)
        }
    }

    @Test("cloud stream records sanitized AgentEvents")
    func cloudStreamRecordsSanitizedAgentEvents() async throws {
        let inference = makeCloudLLMInferenceState(keychainValues: [
            CloudModelProvider.openAI.apiKeyKeychainKey: "sk-openai-test"
        ])
        let session = makeCloudLLMAgentEventURLSession { request in
            let url = try #require(request.url)
            #expect(url.path == "/v1/responses")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-openai-test")

            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = """
            event: response.output_text.delta
            data: {"type":"response.output_text.delta","delta":"Hello"}

            event: response.output_text.delta
            data: {"type":"response.output_text.delta","delta":" there"}

            event: response.completed
            data: {"type":"response.completed"}

            """.data(using: .utf8) ?? Data()
            return (response, data)
        }
        let sink = CloudLLMAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 789 },
            persist: { event in sink.append(event) }
        )
        let client = CloudLLMClient(
            inference: inference,
            urlSession: session,
            agentProvenanceRecorder: recorder
        )

        var output = ""
        let stream = client.stream(
            prompt: "secret prompt",
            systemPrompt: "secret system",
            maxTokens: 64,
            model: .openAIGPT41Mini,
            operatingMode: .fast
        )
        for try await token in stream {
            output += token
        }

        #expect(output == "Hello there")
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallCompleted
        ])
        #expect(Set(sink.events.map(\.runID)).count == 1)
        #expect(sink.events.first?.runID.hasPrefix("cloud-llm-") == true)
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "cloud_model.stream" })
        #expect(sink.events.allSatisfy { $0.tool?.toolCallID == "cloud-llm-stream:1" })
        #expect(sink.events.allSatisfy { $0.metadata["route"] == HermesGatewayRoute.hermesGateway.rawValue })
        #expect(sink.events.last?.tool?.resultJSON?.contains("chunk_count") == true)

        for event in sink.events {
            let argumentsJSON = event.tool?.argumentsJSON ?? ""
            let resultJSON = event.tool?.resultJSON ?? ""
            #expect(!argumentsJSON.contains("secret prompt"))
            #expect(!argumentsJSON.contains("secret system"))
            #expect(!argumentsJSON.contains("sk-openai-test"))
            #expect(!resultJSON.contains("Hello"))
            #expect(!resultJSON.contains("there"))
        }
    }

    @Test("cloud stream records sanitized failure before provider request")
    func cloudStreamRecordsSanitizedFailureBeforeProviderRequest() async throws {
        let inference = makeCloudLLMInferenceState(keychainValues: [:])
        let sink = CloudLLMAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 987 },
            persist: { event in sink.append(event) }
        )
        let client = CloudLLMClient(
            inference: inference,
            agentProvenanceRecorder: recorder
        )

        do {
            let stream = client.stream(
                prompt: "secret prompt",
                systemPrompt: "secret system",
                maxTokens: 64,
                model: .openAIGPT54,
                operatingMode: .pro
            )
            for try await _ in stream {}
            Issue.record("Expected missing OpenAI access to fail streaming.")
        } catch let error as CloudLLMError {
            switch error {
            case .missingAccess("OpenAI"):
                break
            default:
                Issue.record("Expected missing OpenAI access, got \(error).")
            }
        } catch {
            Issue.record("Expected CloudLLMError.missingAccess, got \(error).")
        }

        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallFailed
        ])
        #expect(sink.events.last?.tool?.status == .failed)
        #expect(sink.events.last?.tool?.durationMs != nil)
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "cloud_model.stream" })

        for event in sink.events {
            let tool = try #require(event.tool)
            #expect(!tool.argumentsJSON.contains("secret prompt"))
            #expect(!tool.argumentsJSON.contains("secret system"))
            #expect(tool.resultJSON == nil)
        }
    }

    @Test("cloud structured generation records sanitized AgentEvents")
    func cloudStructuredGenerationRecordsSanitizedAgentEvents() async throws {
        let inference = makeCloudLLMInferenceState(keychainValues: [
            CloudModelProvider.openAI.apiKeyKeychainKey: "sk-openai-test"
        ])
        let session = makeCloudLLMAgentEventURLSession { request in
            let url = try #require(request.url)
            #expect(url.path == "/v1/responses")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-openai-test")

            let response = try #require(
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
            )
            let data = """
            {
              "output_text": "{\\"answer\\":\\"structured-secret\\"}"
            }
            """.data(using: .utf8) ?? Data()
            return (response, data)
        }
        let sink = CloudLLMAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 654 },
            persist: { event in sink.append(event) }
        )
        let client = CloudLLMClient(
            inference: inference,
            urlSession: session,
            agentProvenanceRecorder: recorder
        )

        let result = try await client.generateStructured(
            prompt: "secret prompt",
            systemPrompt: "secret system",
            maxTokens: 64,
            model: .openAIGPT54Mini,
            operatingMode: .pro,
            schema: cloudLLMAgentEventSchema,
            type: [String: String].self
        )

        #expect(result.value == ["answer": "structured-secret"])
        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallCompleted
        ])
        #expect(Set(sink.events.map(\.runID)).count == 1)
        #expect(sink.events.first?.runID.hasPrefix("cloud-llm-") == true)
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "cloud_model.generate_structured" })
        #expect(sink.events.allSatisfy { $0.tool?.toolCallID == "cloud-llm-generate-structured:1" })
        #expect(sink.events.allSatisfy { $0.metadata["route"] == HermesGatewayRoute.hermesGateway.rawValue })
        #expect(sink.events.allSatisfy { $0.metadata["schema_name"] == "agent_event_payload" })
        #expect(sink.events.last?.tool?.durationMs != nil)
        #expect(sink.events.last?.tool?.resultJSON?.contains("raw_json_utf8_bytes") == true)

        for event in sink.events {
            let argumentsJSON = event.tool?.argumentsJSON ?? ""
            let resultJSON = event.tool?.resultJSON ?? ""
            #expect(!argumentsJSON.contains("secret prompt"))
            #expect(!argumentsJSON.contains("secret system"))
            #expect(!argumentsJSON.contains("sk-openai-test"))
            #expect(!resultJSON.contains("structured-secret"))
        }
    }

    @Test("cloud structured generation records sanitized failure before provider request")
    func cloudStructuredGenerationRecordsSanitizedFailureBeforeProviderRequest() async throws {
        let inference = makeCloudLLMInferenceState(keychainValues: [:])
        let sink = CloudLLMAgentEventSink()
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 321 },
            persist: { event in sink.append(event) }
        )
        let client = CloudLLMClient(
            inference: inference,
            agentProvenanceRecorder: recorder
        )

        do {
            _ = try await client.generateStructured(
                prompt: "secret prompt",
                systemPrompt: "secret system",
                maxTokens: 64,
                model: .openAIGPT54Mini,
                operatingMode: .pro,
                schema: cloudLLMAgentEventSchema,
                type: [String: String].self
            )
            Issue.record("Expected missing OpenAI access to fail structured generation.")
        } catch let error as CloudLLMError {
            switch error {
            case .missingAccess("OpenAI"):
                break
            default:
                Issue.record("Expected missing OpenAI access, got \(error).")
            }
        } catch {
            Issue.record("Expected CloudLLMError.missingAccess, got \(error).")
        }

        #expect(sink.events.map(\.kind) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallFailed
        ])
        #expect(sink.events.last?.tool?.status == .failed)
        #expect(sink.events.last?.tool?.durationMs != nil)
        #expect(sink.events.allSatisfy { $0.tool?.toolName == "cloud_model.generate_structured" })

        for event in sink.events {
            let tool = try #require(event.tool)
            #expect(!tool.argumentsJSON.contains("secret prompt"))
            #expect(!tool.argumentsJSON.contains("secret system"))
            #expect(tool.resultJSON == nil)
        }
    }
}

private func makeCloudLLMAgentEventURLSession(
    handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
) -> URLSession {
    CloudLLMAgentEventURLProtocol.handler = handler
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CloudLLMAgentEventURLProtocol.self]
    return URLSession(configuration: configuration)
}

private nonisolated final class CloudLLMAgentEventURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        _ = request
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private let cloudLLMAgentEventSchema = CloudJSONSchema(
    name: "agent_event_payload",
    description: nil,
    schema: [
        "type": "object",
        "properties": [
            "answer": ["type": "string"]
        ],
        "required": ["answer"],
        "additionalProperties": false,
    ],
    strict: true
)
