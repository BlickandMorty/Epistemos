import Testing
import AppKit
import SwiftUI
@testable import Epistemos

// MARK: - Shared Parity Helpers

private enum ParityHelpers {

    /// Style text through TK1 (MarkdownTextStorage).
    /// Returns the styled NSAttributedString after full restyle.
    static func tk1Styled(_ markdown: String, isDark: Bool = false) -> NSAttributedString {
        let storage = MarkdownTextStorage()
        storage.isDark = isDark
        guard !markdown.isEmpty else { return storage }
        storage.beginEditing()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: markdown)
        storage.endEditing()
        storage.reapplyAllStyles()
        return storage
    }

    /// Style text through TK2 (MarkdownContentStorage delegate).
    /// Applies per-line structural styles, then inline styles over the full range.
    static func tk2Styled(_ markdown: String, theme: EpistemosTheme = .sunny) -> NSMutableAttributedString {
        let delegate = MarkdownContentStorage()
        delegate.theme = theme
        delegate.reparse(text: markdown)

        let attrStr = NSMutableAttributedString(string: markdown)
        guard attrStr.length > 0 else { return attrStr }

        let nsStr = markdown as NSString
        var loc = 0
        var lineIdx = 0
        while loc < nsStr.length {
            let lineRange = nsStr.lineRange(for: NSRange(location: loc, length: 0))
            let hasTrailingNewline = lineRange.length > 0
                && lineRange.location + lineRange.length <= nsStr.length
                && nsStr.character(at: lineRange.location + lineRange.length - 1) == 0x0A
            let styleLen = hasTrailingNewline ? lineRange.length - 1 : lineRange.length
            let styleRange = NSRange(location: lineRange.location, length: max(0, styleLen))

            if styleRange.length > 0 {
                let paraType = delegate.paragraphType(at: lineIdx) ?? 0
                let metadata = delegate.paragraphMetadata(at: lineIdx) ?? 0
                delegate.applyStructuralStyleForTest(to: attrStr, range: styleRange, paraType: paraType, metadata: metadata)
            }

            loc = lineRange.location + lineRange.length
            if loc == lineRange.location { break }
            lineIdx += 1
        }

        let fullRange = NSRange(location: 0, length: attrStr.length)
        delegate.applyInlineStyles(to: attrStr, fullRange: fullRange)
        return attrStr
    }
}

// MARK: - Suite 1: Inline Styling Parity (TK1 vs TK2)

@Suite("TK2 Parity - Inline Styling")
struct TK2ParityInlineTests {

    // MARK: - Bold

    @Test("Bold text — both stacks apply bold font trait")
    func boldParity() {
        let md = "Hello **bold** world"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        #expect(tk1.string == tk2.string)

        let offset = 8
        let tk1Font = tk1.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        #expect(tk1Font != nil)
        #expect(tk2Font != nil)

        let tk1Traits = tk1Font.flatMap { NSFontManager.shared.traits(of: $0) } ?? []
        let tk2Traits = tk2Font.flatMap { NSFontManager.shared.traits(of: $0) } ?? []
        #expect(tk1Traits.contains(.boldFontMask))
        #expect(tk2Traits.contains(.boldFontMask))
    }

    @Test("Bold markers — both stacks ghost the ** delimiters")
    func boldMarkerGhosting() {
        let md = "**bold**"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        let tk1Color = tk1.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        let tk2Color = tk2.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect((tk1Color?.alphaComponent ?? 1.0) < 0.2)
        #expect((tk2Color?.alphaComponent ?? 1.0) < 0.2)
    }

    // MARK: - Italic

    @Test("Italic text — both stacks apply italic font trait")
    func italicParity() {
        let md = "Hello *italic* world"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        #expect(tk1.string == tk2.string)

        let offset = 7
        let tk1Font = tk1.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        let tk1Traits = tk1Font.flatMap { NSFontManager.shared.traits(of: $0) } ?? []
        let tk2Traits = tk2Font.flatMap { NSFontManager.shared.traits(of: $0) } ?? []
        #expect(tk1Traits.contains(.italicFontMask))
        #expect(tk2Traits.contains(.italicFontMask))
    }

    // MARK: - Inline Code

    @Test("Inline code — both stacks apply monospace font")
    func inlineCodeParity() {
        let md = "Use `code` here"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        #expect(tk1.string == tk2.string)

        let offset = 5
        let tk1Font = tk1.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        #expect(tk1Font != nil)
        #expect(tk2Font != nil)

        let tk1IsMono = tk1Font?.isFixedPitch == true || tk1Font?.fontName.lowercased().contains("mono") == true
        let tk2IsMono = tk2Font?.isFixedPitch == true || tk2Font?.fontName.lowercased().contains("mono") == true
        #expect(tk1IsMono)
        #expect(tk2IsMono)

        let tk1Bg = tk1.attribute(.backgroundColor, at: offset, effectiveRange: nil) as? NSColor
        let tk2Bg = tk2.attribute(.backgroundColor, at: offset, effectiveRange: nil) as? NSColor
        #expect(tk1Bg != nil)
        #expect(tk2Bg != nil)
    }

    // MARK: - Wikilinks

    @Test("Wikilink — both stacks apply .link attribute")
    func wikilinkParity() {
        let md = "See [[My Note]] here"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        #expect(tk1.string == tk2.string)

        var tk1HasLink = false
        var tk2HasLink = false
        let fullRange = NSRange(location: 0, length: tk1.length)

        tk1.enumerateAttribute(.link, in: fullRange) { val, _, _ in
            if let link = val as? NSString, link.hasPrefix("wikilink://") {
                tk1HasLink = true
            }
        }
        tk2.enumerateAttribute(.link, in: fullRange) { val, _, _ in
            if let link = val as? NSString, link.hasPrefix("wikilink://") {
                tk2HasLink = true
            }
        }
        #expect(tk1HasLink)
        #expect(tk2HasLink)
    }

    // MARK: - Strikethrough

    @Test("Strikethrough — both stacks apply strikethrough attribute")
    func strikethroughParity() {
        let md = "Hello ~~struck~~ world"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        #expect(tk1.string == tk2.string)

        let offset = 8
        let tk1Strike = tk1.attribute(.strikethroughStyle, at: offset, effectiveRange: nil) as? Int
        let tk2Strike = tk2.attribute(.strikethroughStyle, at: offset, effectiveRange: nil) as? Int
        #expect(tk1Strike == NSUnderlineStyle.single.rawValue)
        #expect(tk2Strike == NSUnderlineStyle.single.rawValue)
    }

    // MARK: - Nested bold+italic

    @Test("Bold-italic (***) — both stacks apply bold trait on content")
    func boldItalicParity() {
        let md = "***bolditalic***"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        #expect(tk1.string == tk2.string)

        let offset = 3
        let tk1Font = tk1.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        let tk1Traits = tk1Font.flatMap { NSFontManager.shared.traits(of: $0) } ?? []
        let tk2Traits = tk2Font.flatMap { NSFontManager.shared.traits(of: $0) } ?? []

        #expect(tk1Traits.contains(.boldFontMask))
        #expect(tk2Traits.contains(.boldFontMask))
    }

    // MARK: - Full-Stack Integration (ProseTextView2 delegate pipeline)

    @Test("Full-stack bold — ProseTextView2 delegate produces bold in text element")
    func tk2FullStackBoldStyling() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        let md = "Hello **bold** world"
        tv.textStorage?.setAttributedString(NSAttributedString(string: md))
        tv.reparseAndInvalidate()

        guard let tlm = tv.textLayoutManager,
              let contentStorage = tlm.textContentManager as? NSTextContentStorage else {
            Issue.record("TK2 stack not configured")
            return
        }

        // Force layout so delegate provides styled paragraphs
        tlm.ensureLayout(for: contentStorage.documentRange)

        var foundBold = false
        contentStorage.enumerateTextElements(from: contentStorage.documentRange.location) { element in
            guard let para = element as? NSTextParagraph else { return true }
            let attrStr = para.attributedString
            // "bold" content starts at offset 8 in "Hello **bold** world"
            guard attrStr.length > 8 else { return true }
            let font = attrStr.attribute(.font, at: 8, effectiveRange: nil) as? NSFont
            if let font, NSFontManager.shared.traits(of: font).contains(.boldFontMask) {
                foundBold = true
            }
            return false
        }
        #expect(foundBold)
    }

    @Test("Full-stack wikilink — ProseTextView2 delegate produces .link attribute")
    func tk2FullStackWikilinkAttribute() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        let md = "see [[MyPage]] here"
        tv.textStorage?.setAttributedString(NSAttributedString(string: md))
        tv.reparseAndInvalidate()

        guard let tlm = tv.textLayoutManager,
              let contentStorage = tlm.textContentManager as? NSTextContentStorage else {
            Issue.record("TK2 stack not configured")
            return
        }

        tlm.ensureLayout(for: contentStorage.documentRange)

        var foundWikilink = false
        contentStorage.enumerateTextElements(from: contentStorage.documentRange.location) { element in
            guard let para = element as? NSTextParagraph else { return true }
            let attrStr = para.attributedString
            let range = NSRange(location: 0, length: attrStr.length)
            attrStr.enumerateAttribute(.link, in: range) { val, _, _ in
                if let link = val as? NSString, link.hasPrefix("wikilink://") {
                    foundWikilink = true
                }
            }
            return false
        }
        #expect(foundWikilink)
    }
}

// MARK: - Suite 2: Paragraph Classification Parity

@Suite("TK2 Parity - Paragraph Classification")
struct TK2ParityParagraphTests {

    // MARK: - H1

    @Test("H1 heading — both stacks preserve text and apply font larger than body (15pt)")
    func h1Parity() {
        let md = "# Big Heading"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        #expect(tk1.string == tk2.string)

        let tk1Font = tk1.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        #expect((tk1Font?.pointSize ?? 0) > 15)
        #expect((tk2Font?.pointSize ?? 0) > 15)
    }

    // MARK: - H2

    @Test("H2 heading — both stacks preserve text and apply font larger than body")
    func h2Parity() {
        let md = "## Sub Heading"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        #expect(tk1.string == tk2.string)

        let tk1Font = tk1.attribute(.font, at: 3, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: 3, effectiveRange: nil) as? NSFont
        #expect((tk1Font?.pointSize ?? 0) > 15)
        #expect((tk2Font?.pointSize ?? 0) > 15)
    }

    // MARK: - Blockquote

    @Test("Blockquote — both stacks preserve text and apply foreground color")
    func blockquoteParity() {
        let md = "> quoted text"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        #expect(tk1.string == tk2.string)

        let tk1Fg = tk1.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor
        let tk2Fg = tk2.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor
        #expect(tk1Fg != nil)
        #expect(tk2Fg != nil)
    }

    // MARK: - Code Block

    @Test("Code block — both stacks preserve text and apply foreground color to content")
    func codeBlockParity() {
        let md = "```\ncode here\n```"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        #expect(tk1.string == tk2.string)

        let tk1Fg = tk1.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? NSColor
        let tk2Fg = tk2.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? NSColor
        #expect(tk1Fg != nil)
        #expect(tk2Fg != nil)

        let tk2Font = tk2.attribute(.font, at: 5, effectiveRange: nil) as? NSFont
        let tk2IsMono = tk2Font?.isFixedPitch == true || tk2Font?.fontName.lowercased().contains("mono") == true
        #expect(tk2IsMono)
    }

    // MARK: - Text Preservation

    @Test("Multi-element document — both stacks preserve identical text")
    func multiElementTextParity() {
        let md = "# Title\n\nBody text\n\n- list item\n\n> blockquote\n\n```\ncode\n```"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        #expect(tk1.string == md)
        #expect(tk2.string == md)
        #expect(tk1.string == tk2.string)
    }
}

// MARK: - Suite 3: AI Streaming Integration (Coordinator2 + NoteChatState)

@Suite("TK2 Parity - AI Streaming")
struct TK2ParityAIStreamingTests {

    // MARK: - Helper

    @MainActor
    private static func makeCoordinator2Stack(body: String = "Hello world.")
        -> (coord: ProseEditorRepresentable2.Coordinator2,
            tv: ProseTextView2,
            chat: NoteChatState,
            getText: () -> String)
    {
        var text = body
        let binding = Binding<String>(get: { text }, set: { text = $0 })

        var repr = ProseEditorRepresentable2(
            text: binding,
            pageId: "test-page",
            pageBody: body,
            isFocused: false,
            theme: .light,
            isEditable: true,
            isFocusMode: false
        )
        let chat = NoteChatState(pageId: "test-page")
        repr.noteChatState = chat

        let coord = ProseEditorRepresentable2.Coordinator2(repr)
        let (scrollView, tv) = ProseTextView2.makeTextKit2()

        tv.delegate = coord
        coord.textView = tv
        coord.scrollView = scrollView
        coord.currentPageId = "test-page"
        coord.lastSyncedText = body
        coord.lastTheme = .light

        // Load initial content (minimal setup — skips reparse, not needed for AI tests)
        coord.isFlushingTokens = true
        let ts = tv.textStorage!
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: body)
        ts.endEditing()
        tv.didChangeText()
        coord.isFlushingTokens = false

        // Wire real AI callbacks
        coord.wireNoteChatCallbacks()

        return (coord, tv, chat, { text })
    }

    // MARK: - Stream Start

    @Test("Stream start — inserts AI divider at end of document")
    func streamStartInsertsDivider() {
        let (_, tv, chat, _) = Self.makeCoordinator2Stack()
        chat.onStreamStart?("test query")
        let expected = "Hello world.\n\n<!-- ai-response -->\n\n"
        #expect(tv.string == expected)
    }

    // MARK: - Token Flush

    @Test("Token flush — appends tokens after divider")
    func tokenFlushAppends() {
        let (_, tv, chat, _) = Self.makeCoordinator2Stack()
        chat.onStreamStart?("q")
        chat.onTokenFlush?("Hello ")
        chat.onTokenFlush?("world.")
        #expect(tv.string.hasSuffix("Hello world."))
        #expect(tv.string.contains("<!-- ai-response -->"))
    }

    // MARK: - Accept

    @Test("Accept — strips divider, keeps response, updates binding")
    func acceptStripsDividerUpdatesBinding() {
        let (_, tv, chat, getText) = Self.makeCoordinator2Stack()
        chat.onStreamStart?("q")
        chat.onTokenFlush?("AI response.")
        chat.onAccept?()

        #expect(!tv.string.contains("<!-- ai-response -->"))
        #expect(tv.string.contains("AI response."))
        #expect(tv.string.hasPrefix("Hello world."))
        #expect(getText() == tv.string)
    }

    // MARK: - Discard

    @Test("Discard — removes everything from divider onward")
    func discardRemovesFromDivider() {
        let (_, tv, chat, getText) = Self.makeCoordinator2Stack()
        chat.onStreamStart?("q")
        chat.onTokenFlush?("Unwanted response.")
        chat.onDiscard?()

        #expect(tv.string == "Hello world.")
        #expect(getText() == "Hello world.")
    }

    // MARK: - isFlushingTokens Flag

    @Test("isFlushingTokens — clears after each AI operation")
    func isFlushingTokensClearsAfterEachOp() {
        let (coord, _, chat, _) = Self.makeCoordinator2Stack()
        #expect(!coord.isFlushingTokens)

        chat.onStreamStart?("q")
        #expect(!coord.isFlushingTokens)

        chat.onTokenFlush?("tok")
        #expect(!coord.isFlushingTokens)

        chat.onAccept?()
        #expect(!coord.isFlushingTokens)
    }

    // MARK: - Divider Offset Shift

    @Test("Divider offset — shifts after pre-divider insertion")
    func dividerOffsetShiftsAfterPreInsert() {
        let (coord, tv, chat, _) = Self.makeCoordinator2Stack()
        chat.onStreamStart?("q")
        chat.onTokenFlush?("AI response.")

        let originalLoc = (tv.string as NSString).range(of: "<!-- ai-response -->").location
        #expect(originalLoc != NSNotFound)

        let insertion = "Extra paragraph.\n\n"
        coord.isFlushingTokens = true
        tv.textStorage?.replaceCharacters(
            in: NSRange(location: 0, length: 0),
            with: insertion
        )
        tv.didChangeText()
        coord.isFlushingTokens = false

        let newLoc = (tv.string as NSString).range(of: "<!-- ai-response -->").location
        #expect(newLoc != NSNotFound)
        #expect(newLoc == originalLoc + (insertion as NSString).length)
    }
}

// MARK: - Suite 4: Edge Cases

@Suite("TK2 Parity - Edge Cases")
struct TK2ParityEdgeCaseTests {

    // MARK: - Helpers

    private func tk1String(_ text: String) -> String {
        let storage = MarkdownTextStorage()
        guard !text.isEmpty else { return storage.string }
        storage.beginEditing()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: text)
        storage.endEditing()
        return storage.string
    }

    private func tk2String(_ text: String) -> String {
        let (_, tv) = ProseTextView2.makeTextKit2()
        if !text.isEmpty {
            tv.textStorage?.setAttributedString(NSAttributedString(string: text))
            tv.reparseAndInvalidate()
        }
        return tv.string
    }

    // MARK: - Empty Document

    @Test("Empty document — both produce empty string")
    func emptyDocument() {
        let tk1 = tk1String("")
        let tk2 = tk2String("")
        #expect(tk1 == "")
        #expect(tk2 == "")
        #expect(tk1 == tk2)
    }

    // MARK: - Single Character

    @Test("Single character — identical in both")
    func singleChar() {
        let tk1 = tk1String("a")
        let tk2 = tk2String("a")
        #expect(tk1 == "a")
        #expect(tk2 == "a")
    }

    // MARK: - Unicode

    @Test("Emoji preserved in both stacks")
    func emojiPreserved() {
        let text = "Hello 🎉🌍🚀 world"
        #expect(tk1String(text) == text)
        #expect(tk2String(text) == text)
    }

    @Test("CJK characters preserved in both stacks")
    func cjkPreserved() {
        let text = "中文测试 日本語テスト 한국어시험"
        #expect(tk1String(text) == text)
        #expect(tk2String(text) == text)
    }

    @Test("RTL text preserved in both stacks")
    func rtlPreserved() {
        let text = "مرحبا بالعالم"
        #expect(tk1String(text) == text)
        #expect(tk2String(text) == text)
    }

    @Test("Combined unicode: emoji + bold markdown produces bold trait in both stacks")
    func unicodeBoldParity() {
        let md = "🎉 **bold** end"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        #expect(tk1.string == md)
        #expect(tk2.string == md)

        // "bold" content: "🎉 " = 3 UTF-16 units (🎉=2 + space=1), then "**" = 2, so offset 5
        let offset = 5
        let tk1Font = tk1.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        let tk1Traits = tk1Font.flatMap { NSFontManager.shared.traits(of: $0) } ?? []
        let tk2Traits = tk2Font.flatMap { NSFontManager.shared.traits(of: $0) } ?? []
        #expect(tk1Traits.contains(.boldFontMask))
        #expect(tk2Traits.contains(.boldFontMask))
    }

    // MARK: - Long Single Line

    @Test("Long single line (10K chars) — handled by both stacks")
    func longLine() {
        let text = String(repeating: "A", count: 10_000)
        let tk1 = tk1String(text)
        let tk2 = tk2String(text)
        #expect(tk1.count == 10_000)
        #expect(tk2.count == 10_000)
        #expect(tk1 == tk2)
    }

    // MARK: - Rapid Text Replacement

    @Test("Rapid text replacement — converges to same final state")
    func rapidReplacement() {
        let storage = MarkdownTextStorage()
        let (_, tv) = ProseTextView2.makeTextKit2()

        var finalText = ""
        for i in 0..<20 {
            let text = "# Heading \(i)\nParagraph \(i)"
            // TK1
            storage.beginEditing()
            storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: text)
            storage.endEditing()
            // TK2
            tv.textStorage?.setAttributedString(NSAttributedString(string: text))
            tv.reparseAndInvalidate()
            finalText = text
        }

        #expect(storage.string == finalText)
        #expect(tv.string == finalText)
        #expect(storage.string == tv.string)
    }

    // MARK: - Mixed Formatting Document

    @Test("Complex document with all element types — text identical")
    func mixedFormattingDocument() {
        let md = """
        # Title

        Body with **bold** and *italic* and `code`.

        ## Subheading

        > Blockquote with [[wikilink]]

        - List item 1
        - List item 2

        1. Ordered item
        2. Another item

        - [ ] Task unchecked
        - [x] Task checked

        ```swift
        let x = 42
        ```

        ---

        ~~strikethrough~~ and normal text.

        | Col A | Col B |
        |-------|-------|
        | val1  | val2  |
        """

        let tk1 = tk1String(md)
        let tk2 = tk2String(md)
        #expect(tk1 == md)
        #expect(tk2 == md)
        #expect(tk1 == tk2)
    }

    // MARK: - Newline-Only Document

    @Test("Newline-only document preserved in both")
    func newlineOnly() {
        let text = "\n\n\n"
        #expect(tk1String(text) == text)
        #expect(tk2String(text) == text)
    }

    // MARK: - Inline Markers Without Content

    @Test("Incomplete markers (single *) — both stacks preserve raw text")
    func incompleteMarkers() {
        let text = "Hello * world"
        #expect(tk1String(text) == text)
        #expect(tk2String(text) == text)
    }
}
