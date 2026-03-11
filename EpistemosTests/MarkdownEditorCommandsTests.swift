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

    @Test("Table row insertion adds a new editable row below the current row")
    func insertTableRowBelow() {
        let text = """
        | Name | Score |
        | ---- | ----- |
        | Ada  | 10    |
        """
        let selection = NSRange(location: (text as NSString).range(of: "Ada").location, length: 0)

        let edit = MarkdownEditorCommands.insertTableRowBelow(in: text, selection: selection)

        #expect(edit != nil)
        #expect(edit?.replacementText.contains("|        |        |") == true)
        #expect(edit?.replacementText.components(separatedBy: "\n").count == 4)
    }

    @Test("Table column insertion adds a new header and data column to the right")
    func insertTableColumnRight() {
        let text = """
        | Name | Score |
        | ---- | ----- |
        | Ada  | 10    |
        """
        let selection = NSRange(location: (text as NSString).range(of: "Name").location, length: 0)

        let edit = MarkdownEditorCommands.insertTableColumnRight(in: text, selection: selection)

        #expect(edit != nil)
        #expect(edit?.replacementText.contains("Column 2") == true)
        #expect(edit?.replacementText.components(separatedBy: "|").count == 13)
    }

    @Test("Table column deletion removes the selected column across the table")
    func deleteTableColumn() {
        let text = """
        | Name | Score | Status |
        | ---- | ----- | ------ |
        | Ada  | 10    | Done   |
        """
        let selection = NSRange(location: (text as NSString).range(of: "Score").location, length: 0)

        let edit = MarkdownEditorCommands.deleteTableColumn(in: text, selection: selection)

        #expect(edit != nil)
        #expect(edit?.replacementText.contains("Score") == false)
        #expect(edit?.replacementText.contains("Status") == true)
    }

    @Test("Table alignment expands cramped markdown into a readable grid")
    func alignTable() {
        let text = """
        | A | BBB |
        | - | --- |
        | xx | y |
        """
        let selection = NSRange(location: (text as NSString).range(of: "xx").location, length: 0)

        let edit = MarkdownEditorCommands.alignTable(in: text, selection: selection)

        #expect(edit != nil)
        #expect(edit?.replacementText.contains("| A      | BBB") == true)
        #expect(edit?.replacementText.contains("| xx     | y") == true)
    }
}
