import Testing
@testable import Epistemos

@Suite("Assistant Inline Transcript")
struct AssistantInlineTranscriptTests {
    @Test("function call tags become thinking then inline tool then final text")
    func functionCallTagsBecomeChronologicalSegments() {
        let raw = """
        I need to gather the notes first.

        <function_call>
        {"name":"note.research_digest","content":{"notes":["All Things Must Go"]}}
        </function_call>
        Tool
        Assistant

        Now I can write the answer.
        """

        let segments = AssistantInlineTranscriptBuilder.segments(
            rawContent: raw,
            displayContent: UserFacingModelOutput.finalVisibleText(from: raw),
            contentBlocks: nil
        )

        #expect(segments.count == 3)
        #expect(segments[0].isThinking)
        #expect(segments[0].textContent?.contains("gather the notes") == true)
        #expect(segments[1].tool?.name == "note.research_digest")
        #expect(segments[1].tool?.input["notes"] == .array([.string("All Things Must Go")]))
        #expect(segments[2].textContent == "Now I can write the answer.")
    }

    @Test("action tags parse as inline tool calls")
    func actionTagsParseAsInlineToolCalls() {
        let raw = """
        Let me create the note first.

        <action>
        {"type":"note.create","parameters":{"title":"Agent Research Inbox","body":"hello"}}
        </action>
        """

        let segments = AssistantInlineTranscriptBuilder.segments(
            rawContent: raw,
            displayContent: UserFacingModelOutput.finalVisibleText(from: raw),
            contentBlocks: nil
        )

        #expect(segments.count == 2)
        #expect(segments[0].isThinking)
        #expect(segments[1].tool?.name == "note.create")
        #expect(segments[1].tool?.input["title"] == .string("Agent Research Inbox"))
    }

    @Test("structured content blocks render in event order")
    func structuredContentBlocksRenderInEventOrder() {
        let blocks: [MessageContentBlock] = [
            .thinking("Checking the vault first."),
            .toolUse(
                id: "tool-1",
                name: "vault.search",
                input: ["query": .string("hegemony")]
            ),
            .toolResult(toolUseId: "tool-1", content: #"{"success":true}"#, isError: false),
            .text("The vault has relevant notes.")
        ]

        let segments = AssistantInlineTranscriptBuilder.segments(
            rawContent: "",
            displayContent: "The vault has relevant notes.",
            contentBlocks: blocks
        )

        #expect(segments.count == 3)
        #expect(segments[0].isThinking)
        #expect(segments[1].tool?.result == #"{"success":true}"#)
        #expect(segments[2].textContent == "The vault has relevant notes.")
    }

    @Test("message bubble uses inline transcript instead of top grouped tools")
    func messageBubbleUsesInlineTranscript() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Chat/MessageBubble.swift")

        #expect(source.contains("AssistantInlineTranscriptView("))
        #expect(!source.contains("if let contentBlocks = message.contentBlocks {\n                    ToolExecutionPreviewList(blocks: contentBlocks)\n                }"))
    }
}
