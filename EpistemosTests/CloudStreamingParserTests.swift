import Testing
import Foundation
@testable import Epistemos

@Suite("Cloud Streaming Parsers")
struct CloudStreamingParserTests {
    @Test("OpenAI responses streaming extracts output text deltas")
    func openAIStreamingDelta() {
        let json: [String: Any] = [
            "type": "response.output_text.delta",
            "delta": "hello"
        ]

        #expect(CloudStreamingParser.openAITextDelta(from: json) == "hello")
    }

    @Test("Anthropic streaming extracts text delta payloads")
    func anthropicStreamingDelta() {
        let json: [String: Any] = [
            "type": "content_block_delta",
            "delta": [
                "type": "text_delta",
                "text": "world"
            ]
        ]

        #expect(CloudStreamingParser.anthropicTextDelta(from: json) == "world")
    }

    @Test("Google streaming extracts candidate text payloads")
    func googleStreamingDelta() {
        let json: [String: Any] = [
            "candidates": [
                [
                    "content": [
                        "parts": [
                            ["text": "chunk"]
                        ]
                    ]
                ]
            ]
        ]

        #expect(CloudStreamingParser.googleTextDelta(from: json) == "chunk")
    }

    @Test("OpenAI-compatible streaming never leaks reasoning_content as the text delta")
    func openAIReasoningNeverLeaksIntoText() {
        // When the model emits only reasoning tokens (no final content),
        // the text parser MUST return nil. Falling through to
        // reasoning_content made the chat render the model's private
        // monologue as the answer — the black-box bug reported on
        // 2026-04-19. Reasoning flows through its own parser below.
        let reasoningOnly: [String: Any] = [
            "choices": [[
                "delta": [
                    "reasoning_content": "Okay, the user is asking…"
                ]
            ]]
        ]
        #expect(CloudStreamingParser.openAICompatibleTextDelta(from: reasoningOnly) == nil)
        #expect(
            CloudStreamingParser.openAICompatibleReasoningDelta(from: reasoningOnly)
                == "Okay, the user is asking…"
        )
    }

    @Test("OpenAI-compatible streaming still yields content deltas unchanged")
    func openAIContentStillYields() {
        let contentOnly: [String: Any] = [
            "choices": [[
                "delta": ["content": "hello"]
            ]]
        ]
        #expect(CloudStreamingParser.openAICompatibleTextDelta(from: contentOnly) == "hello")
        #expect(CloudStreamingParser.openAICompatibleReasoningDelta(from: contentOnly) == nil)
    }

    @Test("OpenAI-compatible content wins when both channels are present")
    func openAIContentWinsOverReasoning() {
        let both: [String: Any] = [
            "choices": [[
                "delta": [
                    "content": "final answer",
                    "reasoning_content": "internal thought"
                ]
            ]]
        ]
        #expect(CloudStreamingParser.openAICompatibleTextDelta(from: both) == "final answer")
        #expect(
            CloudStreamingParser.openAICompatibleReasoningDelta(from: both) == "internal thought"
        )
    }

    @Test("stream parser surfaces top level and nested provider errors")
    func streamErrorParsing() {
        let nested: [String: Any] = [
            "error": [
                "code": 429,
                "message": "rate limited"
            ]
        ]
        let topLevel: [String: Any] = [
            "type": "error",
            "code": 401,
            "message": "bad key"
        ]

        #expect(CloudStreamingParser.streamError(from: nested, eventName: nil)?.isTransient == true)
        #expect(CloudStreamingParser.streamError(from: topLevel, eventName: "error")?.isAuthError == true)
    }

    @Test("SSE transport flushes events when URLSession line iteration omits blank separators")
    func sseTransportFlushesOnNewEventHeader() async throws {
        let payload = """
        event: response.output_text.delta
        data: {"type":"response.output_text.delta","delta":"Hello"}

        event: response.output_text.delta
        data: {"type":"response.output_text.delta","delta":" there"}

        event: response.completed
        data: {"type":"response.completed"}

        """

        let session = makeStreamingSession(payload: payload)
        var request = URLRequest(url: URL(string: "https://example.com/responses")!)
        request.httpMethod = "POST"

        var collected = ""
        for try await chunk in URLSessionTransportSupport.streamSSE(
            using: session,
            request: request,
            invalidResponse: { CloudLLMError.invalidResponse },
            chunkExtractor: { CloudStreamingParser.openAITextDelta(from: $0) }
        ) {
            collected += chunk
        }

        #expect(collected == "Hello there")
    }

    private func makeStreamingSession(payload: String) -> URLSession {
        StreamingTestURLProtocol.handler = { request in
            let response = try #require(
                HTTPURLResponse(
                    url: request.url ?? URL(string: "https://example.com/responses")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, Data(payload.utf8))
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StreamingTestURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private nonisolated final class StreamingTestURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
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
