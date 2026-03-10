import Testing
@testable import Epistemos

@Suite("Markdown Editor Commands")
struct MarkdownEditorCommandsTests {

    @Test("Bullet list continues on newline")
    func bulletContinuation() {
        let continuation = MarkdownEditorCommands.continuedInsertion(for: "- item")
        #expect(continuation?.insertedText == "\n- ")
    }

    @Test("Task list continues on newline as unchecked")
    func taskContinuation() {
        let continuation = MarkdownEditorCommands.continuedInsertion(for: "  - [x] done")
        #expect(continuation?.insertedText == "\n  - [ ] ")
    }

    @Test("Numbered list increments on newline")
    func orderedContinuation() {
        let continuation = MarkdownEditorCommands.continuedInsertion(for: "9. item")
        #expect(continuation?.insertedText == "\n10. ")
    }

    @Test("Block quote continues on newline")
    func quoteContinuation() {
        let continuation = MarkdownEditorCommands.continuedInsertion(for: "> quoted text")
        #expect(continuation?.insertedText == "\n> ")
    }

    @Test("Callout header continues as block quote body")
    func calloutContinuation() {
        let continuation = MarkdownEditorCommands.continuedInsertion(for: "> [!note] Note")
        #expect(continuation?.insertedText == "\n> ")
    }

    @Test("Non-markdown line does not auto-continue")
    func plainTextDoesNotContinue() {
        #expect(MarkdownEditorCommands.continuedInsertion(for: "plain text") == nil)
    }

    @Test("Line marker stripping removes ordered and unordered markers")
    func lineMarkerStripping() {
        #expect(MarkdownEditorCommands.strippedLineMarker(from: "- task") == "task")
        #expect(MarkdownEditorCommands.strippedLineMarker(from: "12. item") == "item")
        #expect(MarkdownEditorCommands.strippedLineMarker(from: "> quote") == "quote")
    }

    @Test("Callout template matches markdown callout syntax")
    func calloutTemplate() {
        #expect(MarkdownEditorCommands.calloutTemplate(for: .warning) == "> [!warning] Warning\n> ")
    }
}
