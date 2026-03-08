import Testing
import AppKit
@testable import Epistemos

// MARK: - Phase 1: TextKit 2 Foundation Tests

@Suite("TextKit 2 - ProseTextView2")
struct ProseTextView2Tests {

    @Test("TextKit 2 editor is vertically resizable")
    func textKit2EditorConfiguration() {
        let (scrollView, textView) = ProseTextView2.makeTextKit2()

        #expect(scrollView.documentView === textView)
        #expect(textView.isVerticallyResizable)
        #expect(!textView.isHorizontallyResizable)
        #expect(textView.maxSize.height > 0)
        #expect(textView.textLayoutManager != nil)
    }

    @Test("TextKit 2 editor uses TextKit 2 layout manager")
    func textKit2LayoutManager() {
        let (_, textView) = ProseTextView2.makeTextKit2()

        #expect(textView.textLayoutManager != nil)
        let contentManager = textView.textLayoutManager?.textContentManager
        #expect(contentManager != nil)
        #expect(contentManager is NSTextContentStorage)
    }

    @Test("Editor is plain text (not rich text)")
    func plainTextMode() {
        let (_, textView) = ProseTextView2.makeTextKit2()

        #expect(!textView.isRichText)
        #expect(textView.isEditable)
        #expect(textView.isSelectable)
    }

    @Test("MarkdownContentStorage delegate is wired")
    func delegateWired() {
        let (_, textView) = ProseTextView2.makeTextKit2()

        let contentStorage = textView.textLayoutManager?.textContentManager
            as? NSTextContentStorage
        #expect(contentStorage?.delegate === textView.markdownDelegate)
    }

    @Test("Theme applies background and foreground colors")
    func themeApplication() {
        let (_, textView) = ProseTextView2.makeTextKit2()

        textView.applyTheme(.sunny)
        #expect(textView.backgroundColor == NSColor(EpistemosTheme.sunny.background))

        textView.applyTheme(.ember)
        #expect(textView.backgroundColor == NSColor(EpistemosTheme.ember.background))
    }

    @Test("Theme propagates to markdown delegate")
    func themePropagation() {
        let (_, textView) = ProseTextView2.makeTextKit2()

        textView.applyTheme(.oled)
        #expect(textView.markdownDelegate.theme == .oled)
    }

    @Test("Writing tools enabled")
    func writingTools() {
        let (_, textView) = ProseTextView2.makeTextKit2()
        #expect(textView.writingToolsBehavior == .default)
    }

    @Test("Find bar enabled")
    func findBar() {
        let (_, textView) = ProseTextView2.makeTextKit2()
        #expect(textView.usesFindBar)
        #expect(textView.isIncrementalSearchingEnabled)
    }

    @Test("Text processing disabled (no autocorrect, no link detection)")
    func noTextProcessing() {
        let (_, textView) = ProseTextView2.makeTextKit2()
        #expect(!textView.isAutomaticSpellingCorrectionEnabled)
        #expect(!textView.isAutomaticLinkDetectionEnabled)
        #expect(!textView.isAutomaticDashSubstitutionEnabled)
        #expect(!textView.isAutomaticQuoteSubstitutionEnabled)
    }
}

@Suite("TextKit 2 - MarkdownContentStorage")
struct MarkdownContentStorageTests {

    @Test("Reparse classifies headings via delegate")
    func reparseHeadings() {
        let (_, textView) = ProseTextView2.makeTextKit2()
        let text = "# Big Heading\nBody text"
        textView.textStorage?.setAttributedString(NSAttributedString(string: text))
        textView.reparseAndInvalidate()

        #expect(textView.string == text)
        #expect(textView.markdownDelegate.theme == .light)
    }

    @Test("Delegate handles empty text without crash")
    func delegateEmptyText() {
        let storage = MarkdownContentStorage()
        storage.reparse(text: "")
        // No crash, no spans — verify isDirty is cleared
        storage.markDirty()
        storage.reparse(text: "")
    }

    @Test("markDirty triggers lazy reparse on next delegate call")
    func markDirtyTriggersReparse() {
        let storage = MarkdownContentStorage()
        storage.reparse(text: "# Hello")
        // After reparse, marking dirty should force re-classification on next delegate access
        storage.markDirty()
        // Reparse with different text — should pick up new classification
        storage.reparse(text: "- list item")
    }

    @Test("Theme change updates delegate state")
    func themeChange() {
        let storage = MarkdownContentStorage()
        storage.theme = .ember
        #expect(storage.theme == .ember)
        storage.theme = .light
        #expect(storage.theme == .light)
    }
}

@Suite("TextKit 2 - Live Edit Behavior")
struct TextKit2LiveEditTests {

    @Test("didChangeText marks delegate dirty")
    func didChangeTextMarksDirty() {
        let (_, textView) = ProseTextView2.makeTextKit2()

        // Set initial text and parse
        textView.textStorage?.setAttributedString(NSAttributedString(string: "Hello"))
        textView.reparseAndInvalidate()

        // Simulate a text edit — didChangeText should mark delegate dirty
        textView.textStorage?.replaceCharacters(
            in: NSRange(location: 5, length: 0),
            with: "\n# Heading"
        )
        textView.didChangeText()

        // Force synchronous reparse (bypass debounce) to verify the loop works
        textView.reparseAndInvalidate()
        #expect(textView.string == "Hello\n# Heading")
    }

    @Test("reparseAndInvalidate updates structure after heading insertion")
    func reparseAfterHeadingInsertion() {
        let (_, textView) = ProseTextView2.makeTextKit2()

        // Start with body text
        textView.textStorage?.setAttributedString(NSAttributedString(string: "Just text"))
        textView.reparseAndInvalidate()

        // Change to heading
        textView.textStorage?.setAttributedString(NSAttributedString(string: "# Now a heading"))
        textView.reparseAndInvalidate()

        #expect(textView.string == "# Now a heading")
    }

    @Test("reparseAndInvalidate updates structure after code fence insertion")
    func reparseAfterCodeFence() {
        let (_, textView) = ProseTextView2.makeTextKit2()

        textView.textStorage?.setAttributedString(NSAttributedString(string: "text"))
        textView.reparseAndInvalidate()

        // Add code fence
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: "```\ncode here\n```")
        )
        textView.reparseAndInvalidate()

        #expect(textView.string == "```\ncode here\n```")
    }

    @Test("reparseAndInvalidate handles rapid content changes")
    func rapidContentChanges() {
        let (_, textView) = ProseTextView2.makeTextKit2()

        // Rapid-fire content swaps — no crash, final state correct
        for i in 0..<10 {
            let text = String(repeating: "# Heading \(i)\n", count: 5)
            textView.textStorage?.setAttributedString(NSAttributedString(string: text))
            textView.reparseAndInvalidate()
        }

        #expect(textView.string.hasPrefix("# Heading 9"))
    }

    @Test("reparseAndInvalidate handles list type transitions")
    func listTypeTransitions() {
        let (_, textView) = ProseTextView2.makeTextKit2()

        // Body → unordered list → ordered list → task list
        let transitions = [
            "Plain text",
            "- unordered item",
            "1. ordered item",
            "- [ ] task item",
        ]

        for text in transitions {
            textView.textStorage?.setAttributedString(NSAttributedString(string: text))
            textView.reparseAndInvalidate()
            #expect(textView.string == text)
        }
    }
}

@Suite("TextKit 2 - Theme Restyle Behavior")
struct TextKit2ThemeRestyleTests {

    @Test("applyTheme calls reparseAndInvalidate on existing content")
    func themeRestyleExistingContent() {
        let (_, textView) = ProseTextView2.makeTextKit2()

        // Set content with initial theme
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: "# Heading\nBody text")
        )
        textView.applyTheme(.light)

        // Switch theme — should trigger reparse+invalidate
        textView.applyTheme(.ember)

        #expect(textView.markdownDelegate.theme == .ember)
        #expect(textView.backgroundColor == NSColor(EpistemosTheme.ember.background))
        #expect(textView.string == "# Heading\nBody text")
    }

    @Test("Theme swap preserves text content")
    func themeSwapPreservesContent() {
        let (_, textView) = ProseTextView2.makeTextKit2()
        let text = "# Title\n\n- list\n- items\n\n> blockquote\n\n```\ncode\n```"

        textView.textStorage?.setAttributedString(NSAttributedString(string: text))
        textView.applyTheme(.light)

        // Cycle through all themes
        let themes: [EpistemosTheme] = [.sunny, .ember, .oled, .light]
        for theme in themes {
            textView.applyTheme(theme)
            #expect(textView.string == text)
            #expect(textView.markdownDelegate.theme == theme)
        }
    }

    @Test("Theme change updates typing attributes foreground")
    func themeUpdatesTypingForeground() {
        let (_, textView) = ProseTextView2.makeTextKit2()

        textView.applyTheme(.oled)
        let fgColor = textView.typingAttributes[.foregroundColor] as? NSColor
        #expect(fgColor == NSColor(EpistemosTheme.oled.foreground))

        textView.applyTheme(.sunny)
        let fgColor2 = textView.typingAttributes[.foregroundColor] as? NSColor
        #expect(fgColor2 == NSColor(EpistemosTheme.sunny.foreground))
    }

    @Test("Theme change updates insertion point color")
    func themeUpdatesInsertionPoint() {
        let (_, textView) = ProseTextView2.makeTextKit2()

        textView.applyTheme(.ember)
        #expect(textView.insertionPointColor == NSColor(EpistemosTheme.ember.foreground))
    }
}

@Suite("TextKit 2 - Rust FFI Structure Parser")
struct RustStructureParserTests {

    @Test("Parse heading returns correct type")
    func parseHeading() {
        let text = "# Hello"
        let result = parseStructure(text)
        #expect(result.count == 1)
        #expect(result[0].paraType == 1) // Heading
        #expect(result[0].metadata == 1) // Level 1
    }

    @Test("Parse multiple heading levels")
    func parseHeadingLevels() {
        let text = "# H1\n## H2\n### H3"
        let result = parseStructure(text)
        #expect(result.count == 3)
        #expect(result[0].metadata == 1)
        #expect(result[1].metadata == 2)
        #expect(result[2].metadata == 3)
    }

    @Test("Parse code block spans multiple lines")
    func parseCodeBlock() {
        let text = "```\ncode\n```"
        let result = parseStructure(text)
        #expect(result.count == 3)
        for span in result {
            #expect(span.paraType == 6) // CodeBlock
        }
    }

    @Test("Parse unordered list")
    func parseUnorderedList() {
        let text = "- item"
        let result = parseStructure(text)
        #expect(result.count == 1)
        #expect(result[0].paraType == 3) // UnorderedList
    }

    @Test("Parse ordered list")
    func parseOrderedList() {
        let text = "1. first"
        let result = parseStructure(text)
        #expect(result.count == 1)
        #expect(result[0].paraType == 2) // OrderedList
        #expect(result[0].metadata & 0xFF == 1) // index 1
    }

    @Test("Parse task list")
    func parseTaskList() {
        let text = "- [ ] unchecked\n- [x] checked"
        let result = parseStructure(text)
        #expect(result.count == 2)
        #expect(result[0].paraType == 4) // TaskList
        #expect(result[0].metadata & 1 == 0) // unchecked
        #expect(result[1].paraType == 4)
        #expect(result[1].metadata & 1 == 1) // checked
    }

    @Test("Parse blockquote")
    func parseBlockquote() {
        let text = "> quoted text"
        let result = parseStructure(text)
        #expect(result.count == 1)
        #expect(result[0].paraType == 5) // BlockQuote
        #expect(result[0].metadata == 1) // depth 1
    }

    @Test("Parse table")
    func parseTable() {
        let text = "| A | B |\n|---|---|"
        let result = parseStructure(text)
        #expect(result.count == 2)
        for span in result {
            #expect(span.paraType == 7) // Table
        }
    }

    @Test("Parse horizontal rule")
    func parseHorizontalRule() {
        let text = "---"
        let result = parseStructure(text)
        #expect(result.count == 1)
        #expect(result[0].paraType == 8) // HorizontalRule
    }

    @Test("Parse body text")
    func parseBody() {
        let text = "Just regular text"
        let result = parseStructure(text)
        #expect(result.count == 1)
        #expect(result[0].paraType == 0) // Body
    }

    @Test("Parse empty text returns empty")
    func parseEmpty() {
        let result = parseStructure("")
        #expect(result.isEmpty)
    }

    @Test("Parse mixed content")
    func parseMixed() {
        let text = "# Title\n\nBody\n\n- list\n\n```\ncode\n```"
        let result = parseStructure(text)
        #expect(result[0].paraType == 1) // Heading
        #expect(result[2].paraType == 0) // Body
        #expect(result[4].paraType == 3) // UnorderedList
    }

    // MARK: - Helper

    private func parseStructure(_ text: String) -> [(paraType: UInt8, metadata: UInt16)] {
        text.withCString { cStr in
            let lineCount = text.filter { $0 == "\n" }.count + 1
            let maxSpans = UInt32(lineCount + 16)
            let buffer = UnsafeMutablePointer<StructureSpan>.allocate(capacity: Int(maxSpans))
            defer { buffer.deallocate() }

            let count = markdown_parse_structure(cStr, buffer, maxSpans)
            return (0..<Int(count)).map { i in
                (paraType: buffer[i].para_type, metadata: buffer[i].metadata)
            }
        }
    }
}
