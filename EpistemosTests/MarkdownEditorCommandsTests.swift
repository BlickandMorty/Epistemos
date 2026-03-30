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

    @Test("Wrap selection keeps the original text selected inside markdown markers")
    func wrapSelectionKeepsSelectionInsideMarkers() {
        let text = "Alpha Beta"
        let selection = NSRange(location: 6, length: 4)

        let edit = MarkdownEditorCommands.wrapSelection(
            in: text,
            selection: selection,
            prefix: "**",
            suffix: "**"
        )

        #expect(edit.replacementText == "**Beta**")
        #expect(edit.selectedRange == NSRange(location: 8, length: 4))
    }

    @Test("Wrap selection inserts paired markers and leaves the cursor inside when nothing is selected")
    func wrapSelectionLeavesCursorInsideMarkers() {
        let text = "Alpha"
        let selection = NSRange(location: 2, length: 0)

        let edit = MarkdownEditorCommands.wrapSelection(
            in: text,
            selection: selection,
            prefix: "`",
            suffix: "`"
        )

        #expect(edit.replacementText == "``")
        #expect(edit.selectedRange == NSRange(location: 3, length: 0))
    }

    @Test("Setting a heading replaces the existing heading marker instead of stacking hashes")
    func setHeadingReplacesExistingMarker() {
        let text = "## Existing Heading\n"
        let selection = NSRange(location: 4, length: 0)

        let edit = MarkdownEditorCommands.setHeading(in: text, selection: selection, level: 1)

        #expect(edit?.replacementText == "# Existing Heading\n")
    }

    @Test("Setting the same heading level removes the heading marker")
    func setHeadingSameLevelRemovesMarker() {
        let text = "## Existing Heading\n"
        let selection = NSRange(location: 4, length: 0)

        let edit = MarkdownEditorCommands.setHeading(in: text, selection: selection, level: 2)

        #expect(edit?.replacementText == "Existing Heading\n")
        #expect(edit?.selectedRange == NSRange(location: 0, length: 0))
    }

    @Test("Toggling a markdown prefix swaps the existing line marker instead of stacking markers")
    func togglePrefixSwapsExistingMarker() {
        let text = "- task item\n"
        let selection = NSRange(location: 3, length: 0)

        let edit = MarkdownEditorCommands.toggleLinePrefix(
            in: text,
            selection: selection,
            prefix: "- [ ] "
        )

        #expect(edit?.replacementText == "- [ ] task item\n")
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

    @Test("Table read-only detection matches markdown table rows")
    func detectsReadOnlyTableSelection() {
        let text = """
        Before

        | Name | Score |
        | ---- | ----- |
        | Ada  | 10    |

        After
        """
        let cell = NSRange(location: (text as NSString).range(of: "Ada").location, length: 0)
        let outside = NSRange(location: (text as NSString).range(of: "After").location, length: 0)

        #expect(MarkdownEditorCommands.isSelectionInsideTable(in: text, selection: cell))
        #expect(!MarkdownEditorCommands.isSelectionInsideTable(in: text, selection: outside))
    }

    @Test("Callout insertion preserves the selected text instead of replacing it with an empty template")
    func insertCalloutWrapsSelectedText() {
        let text = "Alpha\nBeta"
        let selection = NSRange(location: 0, length: (text as NSString).length)

        let edit = MarkdownEditorCommands.insertCallout(
            in: text,
            selection: selection,
            kind: .note
        )

        #expect(edit.replacementText == "> [!note] Note\n> Alpha\n> Beta")
    }

    @Test("Code fence insertion wraps the current selection instead of deleting it")
    func insertCodeFenceWrapsSelectedText() {
        let text = "let value = 1"
        let selection = NSRange(location: 0, length: (text as NSString).length)

        let edit = MarkdownEditorCommands.insertCodeFence(in: text, selection: selection)

        #expect(edit.replacementText == "```\nlet value = 1\n```")
        #expect(edit.selectedRange == NSRange(location: 4, length: (text as NSString).length))
    }

    @Test("Divider insertion does not delete the selected text")
    func insertDividerKeepsSelectedText() {
        let text = "Alpha Beta"
        let selection = NSRange(location: 0, length: 5)

        let edit = MarkdownEditorCommands.insertDivider(in: text, selection: selection)

        #expect(edit.replacementRange == NSRange(location: 0, length: 0))
        #expect(edit.replacementText == "\n---\n")
    }

    @Test("Table insertion does not replace the selected text block")
    func insertTableKeepsSelectedText() {
        let text = "Alpha Beta"
        let selection = NSRange(location: 0, length: 5)

        let edit = MarkdownEditorCommands.insertMarkdownTable(in: text, selection: selection)

        #expect(edit.replacementRange == NSRange(location: 0, length: 0))
        #expect(edit.replacementText.contains("| Column 1 | Column 2 | Column 3 |"))
    }

    @Test("Quote and list toggles apply to every selected line")
    func togglePrefixAppliesAcrossSelectedLines() {
        let text = "Alpha\nBeta\nGamma"
        let selection = NSRange(location: 0, length: (text as NSString).length)

        let edit = MarkdownEditorCommands.toggleLinePrefix(
            in: text,
            selection: selection,
            prefix: "> "
        )

        #expect(edit?.replacementText == "> Alpha\n> Beta\n> Gamma")
    }

    @Test("Replace helper clamps ranges and leaves the cursor after the replacement")
    func replaceHelperBuildsEdit() {
        let edit = MarkdownEditorCommands.replace(
            in: "Alpha",
            range: NSRange(location: 1, length: 2),
            replacement: "Z"
        )

        #expect(edit?.replacementRange == NSRange(location: 1, length: 2))
        #expect(edit?.replacementText == "Z")
        #expect(edit?.selectedRange == NSRange(location: 2, length: 0))
    }
}
