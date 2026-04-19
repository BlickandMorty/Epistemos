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
