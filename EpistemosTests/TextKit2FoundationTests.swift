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

    @Test("Selection change updates active line on delegate")
    func selectionUpdatesActiveLine() {
        let (_, textView) = ProseTextView2.makeTextKit2()
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: "Line 0\nLine 1\nLine 2")
        )
        textView.reparseAndInvalidate()

        // Move cursor to line 1 (position 7 = start of "Line 1")
        textView.setSelectedRange(NSRange(location: 7, length: 0))
        #expect(textView.markdownDelegate.activeLine == 1)

        // Move cursor to line 0
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        #expect(textView.markdownDelegate.activeLine == 0)
    }

    @Test("Initial state has no active line")
    func initialNoActiveLine() {
        let (_, textView) = ProseTextView2.makeTextKit2()
        #expect(textView.markdownDelegate.activeLine == nil)
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

// MARK: - Phase 2: Inline Style Tests

@Suite("TextKit 2 - Inline Styling")
struct TextKit2InlineStyleTests {

    /// Helper: create a storage delegate, apply inline styles, return the styled string.
    private func styledString(_ text: String, theme: EpistemosTheme = .light) -> NSMutableAttributedString {
        let storage = MarkdownContentStorage()
        storage.theme = theme
        let attrStr = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attrStr.length)
        storage.applyInlineStyles(to: attrStr, fullRange: range)
        return attrStr
    }

    @Test("Bold text gets bold font on content")
    func boldContent() {
        let result = styledString("Hello **bold** world")
        // "bold" is at UTF-16 positions 8..12 (after "Hello **")
        let boldRange = NSRange(location: 8, length: 4)
        let font = result.attribute(.font, at: boldRange.location, effectiveRange: nil) as? NSFont
        #expect(font != nil)
        let traits = font.flatMap { NSFontManager.shared.traits(of: $0) } ?? []
        #expect(traits.contains(.boldFontMask))
    }

    @Test("Bold markers are ghosted with low alpha")
    func boldGhostedMarkers() {
        let result = styledString("Hello **bold** world")
        // First "**" starts at position 6
        let markerColor = result.attribute(.foregroundColor, at: 6, effectiveRange: nil) as? NSColor
        #expect(markerColor != nil)
        // Ghost marker alpha is 0.12 for light mode
        #expect(markerColor!.alphaComponent < 0.2)
    }

    @Test("Italic text gets italic font on content")
    func italicContent() {
        let result = styledString("Hello *italic* world")
        // "italic" is at UTF-16 positions 7..13 (after "Hello *")
        let italicRange = NSRange(location: 7, length: 6)
        let font = result.attribute(.font, at: italicRange.location, effectiveRange: nil) as? NSFont
        #expect(font != nil)
        let traits = font.flatMap { NSFontManager.shared.traits(of: $0) } ?? []
        #expect(traits.contains(.italicFontMask))
    }

    @Test("InlineCode gets monospace font and accent background")
    func inlineCode() {
        let result = styledString("Use `code` here")
        // "code" is at UTF-16 positions 5..9 (after "Use `")
        let codePos = 5
        let font = result.attribute(.font, at: codePos, effectiveRange: nil) as? NSFont
        #expect(font != nil)
        #expect(font!.isFixedPitch || font!.fontName.lowercased().contains("mono"))
        let bg = result.attribute(.backgroundColor, at: codePos, effectiveRange: nil) as? NSColor
        #expect(bg != nil)
    }

    @Test("InlineCode backticks are ghosted")
    func inlineCodeGhostedBackticks() {
        let result = styledString("Use `code` here")
        // First backtick at position 4
        let markerColor = result.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? NSColor
        #expect(markerColor != nil)
        #expect(markerColor!.alphaComponent < 0.2)
    }

    @Test("Wikilink gets accent foreground and link attribute")
    func wikilinkStyling() {
        let result = styledString("See [[My Note]] here")
        // Rust parser emits WikilinkBrackets for [[ and ]], Wikilink for content.
        // "My Note" content — find it by scanning for link attribute
        var foundLink = false
        result.enumerateAttribute(.link, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if let link = value as? NSString, link.hasPrefix("wikilink://") {
                foundLink = true
                #expect(link == "wikilink://My Note")
            }
        }
        #expect(foundLink)
    }

    @Test("Wikilink brackets are ghosted")
    func wikilinkBracketsGhosted() {
        let result = styledString("See [[My Note]] here")
        // [[ starts at position 4
        let markerColor = result.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? NSColor
        #expect(markerColor != nil)
        #expect(markerColor!.alphaComponent < 0.2)
    }

    @Test("Mixed bold and italic in one paragraph")
    func mixedBoldItalic() {
        let result = styledString("**bold** and *italic*")
        // "bold" content at position 2..6
        let boldFont = result.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        let boldTraits = boldFont.flatMap { NSFontManager.shared.traits(of: $0) } ?? []
        #expect(boldTraits.contains(.boldFontMask))

        // "italic" content at position 14..20
        let italicFont = result.attribute(.font, at: 14, effectiveRange: nil) as? NSFont
        let italicTraits = italicFont.flatMap { NSFontManager.shared.traits(of: $0) } ?? []
        #expect(italicTraits.contains(.italicFontMask))
    }

    @Test("Strikethrough gets strikethrough attribute on content")
    func strikethroughContent() {
        let result = styledString("Hello ~~struck~~ world")
        // "struck" content at position 8..14 (after "Hello ~~")
        let strikeValue = result.attribute(.strikethroughStyle, at: 8, effectiveRange: nil) as? Int
        #expect(strikeValue == NSUnderlineStyle.single.rawValue)
    }

    @Test("Empty text doesn't crash")
    func emptyText() {
        let result = styledString("")
        #expect(result.length == 0)
    }

    @Test("Plain text with no inline markers is unchanged")
    func plainTextUnchanged() {
        let result = styledString("Just plain text here")
        // No special attributes should be added beyond what was there
        let bg = result.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(bg == nil)
        let link = result.attribute(.link, at: 0, effectiveRange: nil)
        #expect(link == nil)
    }

    @Test("Unicode text with emoji preserves correct ranges")
    func unicodeEmoji() {
        // 🎉 is 4 bytes UTF-8, 2 code units UTF-16
        let result = styledString("🎉 **bold** end")
        // "🎉 " = 2 UTF-16 code units + 1 space = 3
        // "**" = 2, so "bold" starts at 3+2 = 5
        let font = result.attribute(.font, at: 5, effectiveRange: nil) as? NSFont
        let traits = font.flatMap { NSFontManager.shared.traits(of: $0) } ?? []
        #expect(traits.contains(.boldFontMask))
    }

    @Test("Dark theme uses correct ghost marker alpha")
    func darkThemeGhostMarkers() {
        let result = styledString("**bold**", theme: .oled)
        // Ghost marker for dark mode: white with alpha 0.15
        let markerColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(markerColor != nil)
        #expect(markerColor!.alphaComponent < 0.2)
    }

    @Test("Bold inside heading preserves heading font size")
    func boldInHeadingPreservesSize() {
        // Simulate the delegate pipeline: structural styling sets 28pt bold,
        // then inline styling should preserve 28pt (not downgrade to 15pt).
        let storage = MarkdownContentStorage()
        storage.theme = .light
        let text = "# **Title**"
        let attrStr = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attrStr.length)

        // Step 1: structural heading style (28pt bold)
        attrStr.addAttributes([
            .font: NSFont.systemFont(ofSize: 28, weight: .bold)
        ], range: range)

        // Step 2: inline styles should derive from 28pt, not hardcoded 15pt
        storage.applyInlineStyles(to: attrStr, fullRange: range)

        // "Title" content starts after "# **" = position 4, length 5
        let titleFont = attrStr.attribute(.font, at: 4, effectiveRange: nil) as? NSFont
        #expect(titleFont != nil)
        #expect(titleFont!.pointSize == 28)
    }

    @Test("Italic inside H2 preserves heading font size")
    func italicInH2PreservesSize() {
        let storage = MarkdownContentStorage()
        storage.theme = .light
        let text = "## *emphasis*"
        let attrStr = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attrStr.length)

        // Structural: H2 at 22pt semibold
        attrStr.addAttributes([
            .font: NSFont.systemFont(ofSize: 22, weight: .semibold)
        ], range: range)

        storage.applyInlineStyles(to: attrStr, fullRange: range)

        // "emphasis" content at position 4..12 (after "## *")
        let font = attrStr.attribute(.font, at: 4, effectiveRange: nil) as? NSFont
        #expect(font != nil)
        #expect(font!.pointSize == 22)
        let traits = NSFontManager.shared.traits(of: font!)
        #expect(traits.contains(.italicFontMask))
    }

    @Test("Inline code inside heading uses heading-relative size")
    func inlineCodeInHeadingRelativeSize() {
        let storage = MarkdownContentStorage()
        storage.theme = .light
        let text = "# Use `func`"
        let attrStr = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attrStr.length)

        // Structural: H1 at 28pt
        attrStr.addAttributes([
            .font: NSFont.systemFont(ofSize: 28, weight: .bold)
        ], range: range)

        storage.applyInlineStyles(to: attrStr, fullRange: range)

        // "func" content at position 7..11 (after "# Use `")
        let font = attrStr.attribute(.font, at: 7, effectiveRange: nil) as? NSFont
        #expect(font != nil)
        // Code should be heading size - 1 = 27, not baseFontSize - 1 = 14
        #expect(font!.pointSize == 27)
    }

    @Test("Bold content preserves structural foreground color")
    func boldContentForeground() {
        let storage = MarkdownContentStorage()
        storage.theme = .light
        let text = "**bold**"
        let attrStr = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attrStr.length)
        let structuralFg = NSColor(EpistemosTheme.light.foreground)
        attrStr.addAttributes([
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: structuralFg
        ], range: range)
        storage.applyInlineStyles(to: attrStr, fullRange: range)
        // "bold" content at positions 2..6 should have structural foreground, NOT ghost
        let contentFg = attrStr.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor
        #expect(contentFg != nil)
        #expect(contentFg!.alphaComponent > 0.9)
    }

    @Test("Italic content preserves structural foreground color")
    func italicContentForeground() {
        let storage = MarkdownContentStorage()
        storage.theme = .light
        let text = "*italic*"
        let attrStr = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attrStr.length)
        let structuralFg = NSColor(EpistemosTheme.light.foreground)
        attrStr.addAttributes([
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: structuralFg
        ], range: range)
        storage.applyInlineStyles(to: attrStr, fullRange: range)
        // "italic" content at positions 1..7 should have structural foreground
        let contentFg = attrStr.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? NSColor
        #expect(contentFg != nil)
        #expect(contentFg!.alphaComponent > 0.9)
    }

    @Test("Theme switch changes wikilink accent color")
    func themeAffectsAccent() {
        let lightResult = styledString("[[note]]", theme: .light)
        let darkResult = styledString("[[note]]", theme: .oled)

        // Both should have link attributes but different accent colors
        var lightAccent: NSColor?
        var darkAccent: NSColor?

        lightResult.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: lightResult.length)) { value, range, _ in
            if let color = value as? NSColor, lightResult.attribute(.link, at: range.location, effectiveRange: nil) != nil {
                lightAccent = color
            }
        }
        darkResult.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: darkResult.length)) { value, range, _ in
            if let color = value as? NSColor, darkResult.attribute(.link, at: range.location, effectiveRange: nil) != nil {
                darkAccent = color
            }
        }

        #expect(lightAccent != nil)
        #expect(darkAccent != nil)
        #expect(lightAccent != darkAccent)
    }
}

@Suite("TextKit 2 - UTF-8 to UTF-16 Map")
struct Utf8ToUtf16MapTests {

    @Test("ASCII text maps 1:1")
    func asciiMap() {
        let map = MarkdownContentStorage.buildUtf8ToUtf16Map("Hello")
        // "Hello" = 5 bytes UTF-8, 5 code units UTF-16
        #expect(map.count == 6) // 5 + 1 sentinel
        for i in 0...5 {
            #expect(map[i] == i)
        }
    }

    @Test("Emoji maps 4 UTF-8 bytes to 2 UTF-16 code units")
    func emojiMap() {
        let map = MarkdownContentStorage.buildUtf8ToUtf16Map("🎉")
        // 🎉 = U+1F389 = 4 bytes UTF-8, 2 code units UTF-16 (surrogate pair)
        #expect(map.count == 5) // 4 + 1 sentinel
        #expect(map[0] == 0) // byte 0 → UTF-16 offset 0
        #expect(map[4] == 2) // sentinel: after 4 bytes → offset 2
    }

    @Test("CJK character maps 3 UTF-8 bytes to 1 UTF-16 code unit")
    func cjkMap() {
        let map = MarkdownContentStorage.buildUtf8ToUtf16Map("中")
        // 中 = U+4E2D = 3 bytes UTF-8, 1 code unit UTF-16
        #expect(map.count == 4) // 3 + 1 sentinel
        #expect(map[0] == 0)
        #expect(map[3] == 1) // sentinel
    }

    @Test("Mixed ASCII and emoji")
    func mixedAsciiEmoji() {
        let map = MarkdownContentStorage.buildUtf8ToUtf16Map("A🎉B")
        // A = 1 byte, 🎉 = 4 bytes, B = 1 byte → total 6 bytes
        // A = 1 code unit, 🎉 = 2 code units, B = 1 code unit → total 4 code units
        #expect(map.count == 7) // 6 + 1 sentinel
        #expect(map[0] == 0) // A
        #expect(map[1] == 1) // start of 🎉
        #expect(map[5] == 3) // B
        #expect(map[6] == 4) // sentinel
    }

    @Test("Empty string returns single sentinel")
    func emptyString() {
        let map = MarkdownContentStorage.buildUtf8ToUtf16Map("")
        #expect(map.count == 1)
        #expect(map[0] == 0)
    }
}

// MARK: - Phase 3: Marker Collapsing Tests

@Suite("TextKit 2 - Marker Collapsing")
struct TextKit2MarkerCollapsingTests {

    /// Helper: style text with active/inactive line awareness.
    private func styledString(
        _ text: String,
        isActive: Bool,
        theme: EpistemosTheme = .light
    ) -> NSMutableAttributedString {
        let storage = MarkdownContentStorage()
        storage.theme = theme
        let attrStr = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attrStr.length)
        let fg = NSColor(theme.foreground)
        attrStr.addAttributes([
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: fg
        ], range: range)
        storage.applyInlineStyles(to: attrStr, fullRange: range, isActive: isActive)
        return attrStr
    }

    @Test("Inactive line: bold markers are hidden (clear foreground)")
    func inactiveBoldMarkersHidden() {
        let result = styledString("**bold**", isActive: false)
        let markerColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(markerColor != nil)
        #expect(markerColor!.alphaComponent < 0.01)
    }

    @Test("Active line: bold markers are ghosted (low alpha)")
    func activeBoldMarkersGhosted() {
        let result = styledString("**bold**", isActive: true)
        let markerColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(markerColor != nil)
        #expect(markerColor!.alphaComponent > 0.05)
        #expect(markerColor!.alphaComponent < 0.2)
    }

    @Test("Inactive line: bold content still visible with structural foreground")
    func inactiveBoldContentVisible() {
        let result = styledString("**bold**", isActive: false)
        let contentFg = result.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor
        #expect(contentFg != nil)
        #expect(contentFg!.alphaComponent > 0.9)
    }

    @Test("Inactive line: italic markers hidden")
    func inactiveItalicMarkersHidden() {
        let result = styledString("*italic*", isActive: false)
        let markerColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(markerColor != nil)
        #expect(markerColor!.alphaComponent < 0.01)
    }

    @Test("Inactive line: inline code backticks hidden")
    func inactiveCodeBackticksHidden() {
        let result = styledString("`code`", isActive: false)
        let markerColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(markerColor != nil)
        #expect(markerColor!.alphaComponent < 0.01)
    }

    @Test("Inactive line: wikilink brackets hidden")
    func inactiveWikilinkBracketsHidden() {
        let result = styledString("[[note]]", isActive: false)
        let markerColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(markerColor != nil)
        #expect(markerColor!.alphaComponent < 0.01)
    }

    @Test("Inactive line: strikethrough tildes hidden")
    func inactiveStrikethroughHidden() {
        let result = styledString("~~struck~~", isActive: false)
        let markerColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(markerColor != nil)
        #expect(markerColor!.alphaComponent < 0.01)
    }

    @Test("Inactive line: inline code content still has accent pill")
    func inactiveCodeContentHasPill() {
        let result = styledString("`code`", isActive: false)
        let bg = result.attribute(.backgroundColor, at: 1, effectiveRange: nil) as? NSColor
        #expect(bg != nil)
    }

    @Test("Inactive line: wikilink content still has accent and link")
    func inactiveWikilinkContentVisible() {
        let result = styledString("[[note]]", isActive: false)
        var foundLink = false
        result.enumerateAttribute(.link, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if let link = value as? NSString, link.hasPrefix("wikilink://") {
                foundLink = true
            }
        }
        #expect(foundLink)
    }

    @Test("Active line preserves Phase 2 ghost behavior")
    func activeLinePhase2Compat() {
        let result = styledString("`code`", isActive: true)
        // Backtick at position 0 should be ghosted (low alpha), not hidden
        let markerColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(markerColor != nil)
        #expect(markerColor!.alphaComponent > 0.05)
        #expect(markerColor!.alphaComponent < 0.2)
    }

    @Test("Empty text with active line doesn't crash")
    func emptyTextActiveLine() {
        let storage = MarkdownContentStorage()
        storage.activeLine = 0
        let attrStr = NSMutableAttributedString(string: "")
        let range = NSRange(location: 0, length: 0)
        storage.applyInlineStyles(to: attrStr, fullRange: range, isActive: true)
        #expect(attrStr.length == 0)
    }

    @Test("Unicode text with marker collapsing")
    func unicodeMarkerCollapsing() {
        let storage = MarkdownContentStorage()
        storage.theme = .light
        let text = "🎉 **bold** end"
        let attrStr = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attrStr.length)
        attrStr.addAttributes([
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor(EpistemosTheme.light.foreground)
        ], range: range)
        storage.applyInlineStyles(to: attrStr, fullRange: range, isActive: false)
        // "**" after 🎉(2 UTF-16) + space(1) = position 3
        let markerColor = attrStr.attribute(.foregroundColor, at: 3, effectiveRange: nil) as? NSColor
        #expect(markerColor != nil)
        #expect(markerColor!.alphaComponent < 0.01)
    }

    @Test("Markdown link on inactive line hides syntax, shows text")
    func inactiveMarkdownLinkShowsText() {
        let storage = MarkdownContentStorage()
        storage.theme = .light
        let text = "[link text](https://example.com)"
        let attrStr = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attrStr.length)
        attrStr.addAttributes([
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor(EpistemosTheme.light.foreground)
        ], range: range)
        storage.applyInlineStyles(to: attrStr, fullRange: range, isActive: false)
        // "[" at position 0 should be hidden
        let bracketColor = attrStr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(bracketColor != nil)
        #expect(bracketColor!.alphaComponent < 0.01)
        // "link text" at position 1 should be visible with accent
        let textColor = attrStr.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? NSColor
        #expect(textColor != nil)
        #expect(textColor!.alphaComponent > 0.5)
    }

    @Test("lineRange returns non-zero length for last line")
    func lastLineRangeNonZero() {
        let storage = MarkdownContentStorage()
        storage.reparse(text: "Line 0\nLine 1")
        // Last line "Line 1" starts at offset 7, length 6
        let range = storage.lineRange(at: 1)
        #expect(range != nil)
        #expect(range!.length == 6)
    }

    @Test("lineRange returns correct length for single-line document")
    func singleLineRange() {
        let storage = MarkdownContentStorage()
        storage.reparse(text: "Hello world")
        let range = storage.lineRange(at: 0)
        #expect(range != nil)
        #expect(range!.length == 11)
    }

    @Test("Selection on last line updates active line")
    func selectionOnLastLine() {
        let (_, textView) = ProseTextView2.makeTextKit2()
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: "Line 0\nLine 1")
        )
        textView.reparseAndInvalidate()
        // Move cursor to last line (position 7)
        textView.setSelectedRange(NSRange(location: 7, length: 0))
        #expect(textView.markdownDelegate.activeLine == 1)
    }

    @Test("Dark theme inactive markers still hidden")
    func darkThemeInactiveMarkersHidden() {
        let storage = MarkdownContentStorage()
        storage.theme = .oled
        let text = "**bold**"
        let attrStr = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attrStr.length)
        attrStr.addAttributes([
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor(EpistemosTheme.oled.foreground)
        ], range: range)
        storage.applyInlineStyles(to: attrStr, fullRange: range, isActive: false)
        let markerColor = attrStr.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(markerColor != nil)
        #expect(markerColor!.alphaComponent < 0.01)
    }

    // MARK: - True Width Collapsing

    @Test("Inactive markers get near-zero font for width collapse")
    func inactiveMarkersZeroWidthFont() {
        let result = styledString("**bold**", isActive: false)
        // "**" at position 0 should have 0.01pt font (near-zero width)
        let markerFont = result.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(markerFont != nil)
        #expect(markerFont!.pointSize < 0.1)
    }

    @Test("Active markers keep normal-size font")
    func activeMarkersNormalFont() {
        let result = styledString("**bold**", isActive: true)
        // "**" at position 0 should NOT have tiny font (active line shows ghost)
        let markerFont = result.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(markerFont != nil)
        #expect(markerFont!.pointSize >= 14)
    }

    @Test("Inactive bold content keeps normal font size despite marker collapse")
    func inactiveBoldContentNormalFont() {
        let result = styledString("**bold**", isActive: false)
        // "bold" content at position 2 should be full-size bold
        let contentFont = result.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        #expect(contentFont != nil)
        #expect(contentFont!.pointSize >= 14)
    }

    @Test("Inactive strikethrough content keeps normal font despite marker collapse")
    func inactiveStrikethroughContentNormalFont() {
        let result = styledString("~~struck~~", isActive: false)
        // "struck" at position 2 should have normal font, not 0.01pt
        let contentFont = result.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        #expect(contentFont != nil)
        #expect(contentFont!.pointSize >= 14)
    }

    @Test("Inactive markdown link text keeps normal font despite marker collapse")
    func inactiveMarkdownLinkTextNormalFont() {
        let result = styledString("[link text](https://example.com)", isActive: false)
        // "link text" at position 1 should have normal font
        let contentFont = result.attribute(.font, at: 1, effectiveRange: nil) as? NSFont
        #expect(contentFont != nil)
        #expect(contentFont!.pointSize >= 14)
    }
}

// MARK: - Phase 4: Paragraph Type Query Tests

@Suite("TextKit 2 - Paragraph Type Query")
struct TextKit2ParagraphTypeTests {

    @Test("paragraphType returns heading for heading lines")
    func headingType() {
        let storage = MarkdownContentStorage()
        storage.reparse(text: "# Hello\nBody")
        #expect(storage.paragraphType(at: 0) == 1)
        #expect(storage.paragraphType(at: 1) == 0)
    }

    @Test("paragraphType returns table for table lines")
    func tableType() {
        let storage = MarkdownContentStorage()
        storage.reparse(text: "| A | B |\n|---|---|\n| x | y |")
        #expect(storage.paragraphType(at: 0) == 7)
        #expect(storage.paragraphType(at: 1) == 7)
        #expect(storage.paragraphType(at: 2) == 7)
    }

    @Test("paragraphType returns nil for out-of-bounds")
    func outOfBounds() {
        let storage = MarkdownContentStorage()
        storage.reparse(text: "Hello")
        #expect(storage.paragraphType(at: 5) == nil)
        #expect(storage.paragraphType(at: -1) == nil)
    }

    @Test("paragraphType returns nil before reparse")
    func beforeReparse() {
        let storage = MarkdownContentStorage()
        #expect(storage.paragraphType(at: 0) == nil)
    }

    @Test("lineCount returns correct count")
    func lineCount() {
        let storage = MarkdownContentStorage()
        storage.reparse(text: "A\nB\nC")
        #expect(storage.lineCount == 3)
    }
}

// MARK: - Phase 4: Table Detection Helper Tests

@Suite("TextKit 2 - Table Detection Helpers")
struct TextKit2TableDetectionTests {

    @Test("isTableLine detects valid table lines")
    func validTableLines() {
        #expect(ProseTextView2.isTableLine("| A | B |"))
        #expect(ProseTextView2.isTableLine("|---|---|"))
        #expect(ProseTextView2.isTableLine("| x |"))
    }

    @Test("isTableLine rejects non-table lines")
    func invalidTableLines() {
        #expect(!ProseTextView2.isTableLine("Hello world"))
        #expect(!ProseTextView2.isTableLine("| x"))
        #expect(!ProseTextView2.isTableLine("x |"))
        #expect(!ProseTextView2.isTableLine(""))
        #expect(!ProseTextView2.isTableLine("||"))
    }

    @Test("isSeparatorLine detects separator rows")
    func separators() {
        #expect(ProseTextView2.isSeparatorLine("|---|---|"))
        #expect(ProseTextView2.isSeparatorLine("|:---|---:|"))
        #expect(ProseTextView2.isSeparatorLine("| --- | --- |"))
    }

    @Test("isSeparatorLine rejects data rows")
    func nonSeparators() {
        #expect(!ProseTextView2.isSeparatorLine("| A | B |"))
        #expect(!ProseTextView2.isSeparatorLine("| foo | bar |"))
    }

    @Test("pipeCharIndices finds all pipe offsets")
    func pipeIndices() {
        let indices = ProseTextView2.pipeCharIndices(in: "| A | B | C |")
        #expect(indices.count == 4)
        #expect(indices[0] == 0)
    }
}

// MARK: - Phase 4: Table Drawing Tests

@Suite("TextKit 2 - Table Drawing")
struct TextKit2TableDrawingTests {

    @Test("drawBackground does not crash on empty text")
    func emptyText() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.textStorage?.setAttributedString(NSAttributedString(string: ""))
        tv.reparseAndInvalidate()
        tv.drawBackground(in: tv.bounds)
    }

    @Test("drawBackground does not crash on table content")
    func tableContent() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.textStorage?.setAttributedString(
            NSAttributedString(string: "| A | B |\n|---|---|\n| x | y |")
        )
        tv.reparseAndInvalidate()
        tv.drawBackground(in: tv.bounds)
    }

    @Test("drawBackground does not crash on multiple tables")
    func multipleTables() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.textStorage?.setAttributedString(
            NSAttributedString(string: "| A | B |\n|---|---|\n| x | y |\n\nBody\n\n| C | D |\n|---|---|\n| z | w |")
        )
        tv.reparseAndInvalidate()
        tv.drawBackground(in: tv.bounds)
    }

    @Test("drawBackground does not crash on single-column table")
    func singleColumnTable() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.textStorage?.setAttributedString(
            NSAttributedString(string: "| A |\n|---|\n| x |")
        )
        tv.reparseAndInvalidate()
        tv.drawBackground(in: tv.bounds)
    }

    @Test("drawBackground does not crash on unicode table")
    func unicodeTable() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.textStorage?.setAttributedString(
            NSAttributedString(string: "| 你好 | 世界 |\n|------|------|\n| 🎉 | Test |")
        )
        tv.reparseAndInvalidate()
        tv.drawBackground(in: tv.bounds)
    }

    @Test("drawBackground does not crash on body-only text")
    func bodyOnly() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.textStorage?.setAttributedString(
            NSAttributedString(string: "Just some body text\nAnother line")
        )
        tv.reparseAndInvalidate()
        tv.drawBackground(in: tv.bounds)
    }
}

// MARK: - Phase 4: Fold Indicator Tests

@Suite("TextKit 2 - Fold Indicators")
struct TextKit2FoldIndicatorTests {

    @Test("drawBackground does not crash with headings")
    func headings() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.textStorage?.setAttributedString(
            NSAttributedString(string: "# H1\n## H2\n### H3\nBody")
        )
        tv.reparseAndInvalidate()
        tv.drawBackground(in: tv.bounds)
    }

    @Test("drawBackground does not crash with folded heading")
    func foldedHeading() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.textStorage?.setAttributedString(
            NSAttributedString(string: "# Folded\n\u{2026}\n## Next")
        )
        tv.reparseAndInvalidate()
        tv.drawBackground(in: tv.bounds)
    }

    @Test("drawBackground does not crash with heading at document end")
    func headingAtEnd() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.textStorage?.setAttributedString(
            NSAttributedString(string: "Body\n# Last Heading")
        )
        tv.reparseAndInvalidate()
        tv.drawBackground(in: tv.bounds)
    }

    @Test("drawBackground does not crash with heading + table combo")
    func headingAndTable() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.textStorage?.setAttributedString(
            NSAttributedString(string: "# Data\n| A | B |\n|---|---|\n| x | y |")
        )
        tv.reparseAndInvalidate()
        tv.drawBackground(in: tv.bounds)
    }
}
