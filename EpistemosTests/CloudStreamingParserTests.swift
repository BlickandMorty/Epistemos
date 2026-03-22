import Testing
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
}
