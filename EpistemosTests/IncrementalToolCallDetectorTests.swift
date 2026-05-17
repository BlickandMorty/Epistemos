import Testing
@testable import Epistemos

@Suite("IncrementalToolCallDetector")
struct IncrementalToolCallDetectorTests {

    // MARK: - Single Chunk

    @Test("Detects complete tool call in a single chunk")
    func singleChunk() {
        let detector = IncrementalToolCallDetector()
        let input = """
        <tool_call>
        {"name": "click", "arguments": {"element": "Submit"}}
        </tool_call>
        """
        let detection = detector.feed(input)
        #expect(detection != nil)
        #expect(detection?.toolCall.name == "click")
    }

    @Test("Detects Phi native tool-call tags")
    func singleChunkPhiNativeToolCall() {
        let detector = IncrementalToolCallDetector()
        let input = #"<|tool_call|>{"name":"vault.search","arguments":{"query":"local agents"}}</|tool_call|>"#

        let detection = detector.feed(input)

        #expect(detection != nil)
        #expect(detection?.toolCall.name == "vault.search")
        #expect(detection?.toolCall.argumentsJson.contains("local agents") == true)
    }

    @Test("Detects Mistral TOOL_CALLS JSON once balanced")
    func mistralToolCallsBalancedJson() {
        let detector = IncrementalToolCallDetector()

        #expect(detector.feed(#"[TOOL_CALLS]vault.search[CALL_ID]call-1[ARGS]{"query":"#) == nil)
        let detection = detector.feed(#"constellation"}"#)

        #expect(detection != nil)
        #expect(detection?.toolCall.name == "vault.search")
        #expect(detection?.toolCall.argumentsJson.contains("constellation") == true)
    }

    @Test("Detects Mistral TOOL_CALLS array form once balanced")
    func mistralToolCallsArrayForm() {
        let detector = IncrementalToolCallDetector()

        #expect(detector.feed(#"[TOOL_CALLS][{"name":"vault.search","arguments":{"query":"#) == nil)
        let detection = detector.feed(#"array form"}}]"#)

        #expect(detection != nil)
        #expect(detection?.toolCall.name == "vault.search")
        #expect(detection?.toolCall.argumentsJson.contains("array form") == true)
    }

    @Test("Detects legacy Qwen XML function bodies inside tool_call tags")
    func singleChunkLegacyQwenXmlBody() {
        let detector = IncrementalToolCallDetector()
        let input = """
        <tool_call><function=read_file><parameter=path>/tmp/test.txt</parameter></function></tool_call>
        """
        let detection = detector.feed(input)
        #expect(detection != nil)
        #expect(detection?.toolCall.name == "read_file")
        #expect(
            detection?.toolCall.argumentsJson.replacingOccurrences(of: "\\/", with: "/")
                .contains("\"path\":\"/tmp/test.txt\"") == true
        )
    }

    @Test("Returns nil when no tool call present")
    func noToolCall() {
        let detector = IncrementalToolCallDetector()
        let result = detector.feed("Just some regular text from the model.")
        #expect(result == nil)
    }

    // MARK: - Multi-Chunk Splits

    @Test("Detects tool call split across two chunks — mid JSON")
    func splitMidJson() {
        let detector = IncrementalToolCallDetector()
        #expect(detector.feed("<tool_call>{\"name\": \"click\", ") == nil)
        let detection = detector.feed("\"arguments\": {\"id\": 49}}</tool_call>")
        #expect(detection != nil)
        #expect(detection?.toolCall.name == "click")
    }

    @Test("Detects tool call split across chunks — mid close tag")
    func splitMidCloseTag() {
        let detector = IncrementalToolCallDetector()
        #expect(detector.feed("<tool_call>{\"name\": \"type\", \"arguments\": {\"text\": \"hello\"}}") == nil)
        #expect(detector.feed("</tool") == nil)
        let detection = detector.feed("_call>")
        #expect(detection != nil)
        #expect(detection?.toolCall.name == "type")
    }

    @Test("Detects tool call split across chunks — mid open tag")
    func splitMidOpenTag() {
        let detector = IncrementalToolCallDetector()
        #expect(detector.feed("<tool") == nil)
        #expect(detector.feed("_call>") == nil)
        let detection = detector.feed("{\"name\": \"scroll\", \"arguments\": {\"dir\": \"down\"}}</tool_call>")
        #expect(detection != nil)
        #expect(detection?.toolCall.name == "scroll")
    }

    @Test("Handles character-by-character streaming")
    func characterByCharacter() {
        let detector = IncrementalToolCallDetector()
        let full = "<tool_call>{\"name\": \"keys\", \"arguments\": {\"key\": \"return\"}}</tool_call>"
        var detection: IncrementalToolCallDetector.Detection?
        for char in full {
            detection = detector.feed(String(char))
            if detection != nil { break }
        }
        #expect(detection != nil)
        #expect(detection?.toolCall.name == "keys")
    }

    // MARK: - Scratch Pad / Think Tags

    @Test("Ignores scratch_pad content before tool call")
    func scratchPadIgnored() {
        let detector = IncrementalToolCallDetector()
        #expect(detector.feed("<scratch_pad>I should click the submit button.</scratch_pad>") == nil)
        #expect(detector.pendingText.isEmpty)
        let detection = detector.feed("<tool_call>{\"name\": \"click\", \"arguments\": {\"element\": \"Submit\"}}</tool_call>")
        #expect(detection != nil)
        #expect(detection?.toolCall.name == "click")
    }

    @Test("Ignores think content before tool call")
    func thinkIgnored() {
        let detector = IncrementalToolCallDetector()
        #expect(detector.feed("<think>Let me reason about this.</think>") == nil)
        let detection = detector.feed("<tool_call>{\"name\": \"see\", \"arguments\": {\"app\": \"Notes\"}}</tool_call>")
        #expect(detection != nil)
        #expect(detection?.toolCall.name == "see")
    }

    // MARK: - Error Handling

    @Test("Returns nil for malformed JSON inside tool_call tags")
    func malformedJson() {
        let detector = IncrementalToolCallDetector()
        let result = detector.feed("<tool_call>this is not json at all</tool_call>")
        #expect(result == nil)
    }

    @Test("Empty chunk is a no-op")
    func emptyChunk() {
        let detector = IncrementalToolCallDetector()
        #expect(detector.feed("") == nil)
    }

    // MARK: - Multiple Tool Calls

    @Test("Detects two sequential tool calls")
    func twoSequentialCalls() {
        let detector = IncrementalToolCallDetector()
        let first = detector.feed("<tool_call>{\"name\": \"click\", \"arguments\": {\"id\": 1}}</tool_call>")
        #expect(first != nil)
        #expect(first?.toolCall.name == "click")

        let second = detector.feed("<tool_call>{\"name\": \"type\", \"arguments\": {\"text\": \"hi\"}}</tool_call>")
        #expect(second != nil)
        #expect(second?.toolCall.name == "type")
    }

    // MARK: - Pending Text

    @Test("Accumulates non-tool-call text in pendingText")
    func pendingTextAccumulation() {
        let detector = IncrementalToolCallDetector()
        _ = detector.feed("Some reasoning text before the action.")
        #expect(detector.pendingText == "Some reasoning text before the action.")
    }

    @Test("Flushes trailing tag-prefix plaintext at stream end")
    func flushesTrailingTagPrefixPlaintextAtStreamEnd() {
        let detector = IncrementalToolCallDetector()
        _ = detector.feed("Use A <")

        #expect(detector.pendingText == "Use A ")
        #expect(detector.flushOnStreamEnd() == "<")
        #expect(detector.pendingText == "Use A <")
        #expect(detector.flushOnStreamEnd().isEmpty)
    }

    @Test("Drops unterminated hidden and tool buffers at stream end")
    func dropsUnterminatedHiddenAndToolBuffersAtStreamEnd() {
        let hiddenDetector = IncrementalToolCallDetector()
        _ = hiddenDetector.feed("<think>private reasoning")
        #expect(hiddenDetector.pendingText.isEmpty)
        #expect(hiddenDetector.flushOnStreamEnd().isEmpty)
        #expect(hiddenDetector.pendingText.isEmpty)

        let toolDetector = IncrementalToolCallDetector()
        _ = toolDetector.feed("<tool_call>{\"name\":\"read_file\"")
        #expect(toolDetector.pendingText.isEmpty)
        #expect(toolDetector.flushOnStreamEnd().isEmpty)
        #expect(toolDetector.pendingText.isEmpty)

        let phiDetector = IncrementalToolCallDetector()
        _ = phiDetector.feed(#"<|tool_call|>{"name":"read_file""#)
        #expect(phiDetector.pendingText.isEmpty)
        #expect(phiDetector.flushOnStreamEnd().isEmpty)
        #expect(phiDetector.pendingText.isEmpty)

        let mistralDetector = IncrementalToolCallDetector()
        _ = mistralDetector.feed(#"[TOOL_CALLS] [{"name":"read_file""#)
        #expect(mistralDetector.pendingText.isEmpty)
        #expect(mistralDetector.flushOnStreamEnd().isEmpty)
        #expect(mistralDetector.pendingText.isEmpty)
    }

    // MARK: - Reset

    @Test("Reset clears state for new generation")
    func resetState() {
        let detector = IncrementalToolCallDetector()
        _ = detector.feed("<tool_call>{\"name\": \"click\", \"arguments\": {}}</tool_call>")
        detector.reset()

        #expect(detector.pendingText.isEmpty)
        // Should be able to detect a new tool call after reset
        let detection = detector.feed("<tool_call>{\"name\": \"see\", \"arguments\": {}}</tool_call>")
        #expect(detection != nil)
        #expect(detection?.toolCall.name == "see")
    }

    // MARK: - Partial Open Tag That Never Completes

    @Test("Partial open tag followed by different text does not crash")
    func partialOpenTagAbandoned() {
        let detector = IncrementalToolCallDetector()
        // Start matching <tool_call> but then get different characters
        let result = detector.feed("<tool_xyz some other text")
        #expect(result == nil)
        // The partial match characters should be in pendingText
        #expect(detector.pendingText.contains("<tool_xyz"))
    }

    // MARK: - Close Tag False Alarm Inside Body

    @Test("Handles partial close tag match inside body content")
    func partialCloseTagInBody() {
        let detector = IncrementalToolCallDetector()
        // The body contains "</tool" which partially matches the close tag
        let detection = detector.feed("<tool_call>{\"name\": \"type\", \"arguments\": {\"text\": \"</tool is tricky\"}}</tool_call>")
        #expect(detection != nil)
        #expect(detection?.toolCall.name == "type")
    }

    @Test("Repairs malformed XML-like tool call openings without leaking markup")
    func malformedXmlLikeToolCallOpening() {
        let detector = IncrementalToolCallDetector()
        let detection = detector.feed(
            "<tool_call<name>read_file</name<arguments><path>/tmp/test.txt</path></arguments></tool_call>"
        )
        #expect(detection != nil)
        #expect(detection?.toolCall.name == "read_file")
        let argumentData = detection?.toolCall.argumentsJson.data(using: .utf8)
        let arguments = argumentData.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] }
        #expect(arguments?["path"] == "/tmp/test.txt")
        #expect(detector.pendingText.isEmpty)
    }
}
