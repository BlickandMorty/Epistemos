import Testing
import AppKit
import SwiftUI
import SwiftData
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

// MARK: - Parent Suite (enables -only-testing:EpistemosTests/TextKit2ParityTests)

@Suite("TextKit 2 Parity Tests")
enum TextKit2ParityTests {

// MARK: - Suite 1: Inline Styling Parity (TK1 vs TK2)

@Suite("TK2 Parity - Inline Styling")
struct InlineTests {

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
struct ParagraphTests {

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
struct AIStreamingTests {

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
struct EdgeCaseTests {

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

// MARK: - Suite 5: Block Reference Parity (P1 regression coverage)

@Suite("TK2 Parity - Block References")
struct BlockRefTests {

    // MARK: - .link attribute with blockref:// prefix

    @Test("Block ref — both stacks set .link attribute with blockref:// prefix")
    func blockRefLinkAttributeParity() {
        let md = "See ((my-block-id)) here"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        #expect(tk1.string == tk2.string)

        let range = NSRange(location: 0, length: tk1.length)

        var tk1HasBlockRef = false
        tk1.enumerateAttribute(.link, in: range) { val, _, _ in
            if let link = val as? NSString, link.hasPrefix("blockref://") {
                tk1HasBlockRef = true
            }
        }

        var tk2HasBlockRef = false
        tk2.enumerateAttribute(.link, in: range) { val, _, _ in
            if let link = val as? NSString, link.hasPrefix("blockref://") {
                tk2HasBlockRef = true
            }
        }

        #expect(tk1HasBlockRef, "TK1 should set .link with blockref:// on block references")
        #expect(tk2HasBlockRef, "TK2 should set .link with blockref:// on block references")
    }

    @Test("Block ref — extracted ID matches original")
    func blockRefIdExtraction() {
        let md = "((test-block-42))"
        let tk2 = ParityHelpers.tk2Styled(md)

        let range = NSRange(location: 0, length: tk2.length)
        var extractedId: String?
        tk2.enumerateAttribute(.link, in: range) { val, _, _ in
            if let link = val as? NSString, link.hasPrefix("blockref://") {
                extractedId = String(link.substring(from: "blockref://".count))
            }
        }

        #expect(extractedId == "test-block-42")
    }

    @Test("Empty block ref (( )) — no .link attribute produced")
    func emptyBlockRefNoLink() {
        let md = "Before (( )) after"
        let tk2 = ParityHelpers.tk2Styled(md)

        let range = NSRange(location: 0, length: tk2.length)
        var hasBlockRef = false
        tk2.enumerateAttribute(.link, in: range) { val, _, _ in
            if let link = val as? NSString, link.hasPrefix("blockref://") {
                hasBlockRef = true
            }
        }
        #expect(!hasBlockRef, "Empty (( )) should not produce a blockref link")
    }

    // MARK: - Block Ref Autocomplete Insertion Format

    @Test("Block ref autocomplete — produces valid ((id)) syntax")
    func blockRefAutocompleteFormat() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        let initialText = "Some text (("
        tv.textStorage?.setAttributedString(NSAttributedString(string: initialText))
        tv.setSelectedRange(NSRange(location: (initialText as NSString).length, length: 0))

        // Simulate the insertBlockRef logic (private method — replicate here):
        let str = tv.textStorage!.string as NSString
        let cursor = tv.selectedRange().location
        guard cursor >= 2,
              str.substring(with: NSRange(location: cursor - 2, length: 2)) == "((" else {
            Issue.record("Precondition failed: cursor not after ((")
            return
        }

        let blockId = "test-block-uuid"
        let fullRef = "((" + blockId + "))"
        let replaceRange = NSRange(location: cursor - 2, length: 2)
        tv.textStorage?.replaceCharacters(in: replaceRange, with: fullRef)
        tv.didChangeText()

        #expect(tv.string == "Some text ((" + blockId + "))")
    }

    @Test("Block ref autocomplete — replaces partial query between (( and cursor")
    func blockRefAutocompleteReplacesQuery() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        // Simulate user typed "((partial" then selected from popover
        let initialText = "Note text ((partial"
        tv.textStorage?.setAttributedString(NSAttributedString(string: initialText))
        tv.setSelectedRange(NSRange(location: (initialText as NSString).length, length: 0))

        let str = tv.textStorage!.string as NSString
        let cursor = tv.selectedRange().location

        // Scan backwards for ((
        var openParenLoc = NSNotFound
        var i = min(cursor, str.length) - 1
        while i >= 1 {
            if str.character(at: i - 1) == 0x28 && str.character(at: i) == 0x28 {
                openParenLoc = i - 1
                break
            }
            i -= 1
        }
        #expect(openParenLoc != NSNotFound, "Should find (( by scanning backwards")

        let replaceRange = NSRange(location: openParenLoc, length: cursor - openParenLoc)
        let blockId = "real-block-id"
        let fullRef = "((" + blockId + "))"
        tv.textStorage?.replaceCharacters(in: replaceRange, with: fullRef)
        tv.didChangeText()

        #expect(tv.string == "Note text ((" + blockId + "))")
        #expect(!tv.string.contains("partial"), "Partial query text should be replaced")
    }
}

// MARK: - Suite 6: Transclusion Body Rewrite

@Suite("TK2 Parity - Transclusion Body Rewrite")
struct TransclusionRewriteTests {

    private func reconstructRaw(match: BlockParser.ParsedBlock, oldContent: String, newContent: String) -> String {
        let rawFirstLine = match.rawContent.prefix(while: { $0 != "\n" })
        let contentFirstLine = oldContent.prefix(while: { $0 != "\n" })
        let prefix: String
        if rawFirstLine.hasSuffix(contentFirstLine) {
            prefix = String(rawFirstLine.dropLast(contentFirstLine.count))
        } else {
            prefix = ""
        }
        if prefix.isEmpty || !newContent.contains("\n") {
            return prefix + newContent
        }
        let continuationIndent = String(repeating: " ", count: prefix.count)
        let lines = newContent.split(separator: "\n", omittingEmptySubsequences: false)
        var parts = [prefix + lines[0]]
        for line in lines.dropFirst() {
            parts.append(continuationIndent + line)
        }
        return parts.joined(separator: "\n")
    }

    private func applyRewrite(markdown: String, match: BlockParser.ParsedBlock, newRaw: String) -> String? {
        let utf16View = markdown.utf16
        let safeStart = min(match.utf16Range.lowerBound, utf16View.count)
        let safeEnd = min(match.utf16Range.upperBound, utf16View.count)
        let startIdx = utf16View.index(utf16View.startIndex, offsetBy: safeStart)
        let endIdx = utf16View.index(utf16View.startIndex, offsetBy: safeEnd)
        guard let strStart = startIdx.samePosition(in: markdown),
              let strEnd = endIdx.samePosition(in: markdown) else { return nil }
        var result = markdown
        result.replaceSubrange(strStart..<strEnd, with: newRaw)
        return result
    }

    // MARK: - List item preserves marker

    @Test("List item edit preserves '- ' marker")
    func listItemRewrite() {
        let markdown = "# Heading\n- First item\n- Target item\n- Third item"
        let parsed = BlockParser.parse(markdown)
        guard let match = parsed.first(where: { $0.content == "Target item" }) else {
            Issue.record("Block not found"); return
        }
        #expect(match.order == 2)

        let newRaw = reconstructRaw(match: match, oldContent: "Target item", newContent: "Edited item")
        #expect(newRaw == "- Edited item")

        let result = applyRewrite(markdown: markdown, match: match, newRaw: newRaw)
        #expect(result == "# Heading\n- First item\n- Edited item\n- Third item")
    }

    // MARK: - Indented list item preserves indent + marker

    @Test("Indented list item preserves indent and marker")
    func indentedListItemRewrite() {
        let markdown = "- Parent\n  - Nested child\n  - Another child"
        let parsed = BlockParser.parse(markdown)
        guard let match = parsed.first(where: { $0.content == "Nested child" }) else {
            Issue.record("Nested block not found"); return
        }
        #expect(match.depth == 1)

        let newRaw = reconstructRaw(match: match, oldContent: "Nested child", newContent: "Edited child")
        #expect(newRaw == "  - Edited child", "Indent + marker must be preserved")

        let result = applyRewrite(markdown: markdown, match: match, newRaw: newRaw)
        #expect(result == "- Parent\n  - Edited child\n  - Another child")
    }

    // MARK: - Ordered list preserves "1. " marker

    @Test("Ordered list item preserves '1. ' marker")
    func orderedListRewrite() {
        let markdown = "1. First\n2. Second\n3. Third"
        let parsed = BlockParser.parse(markdown)
        guard let match = parsed.first(where: { $0.content == "Second" }) else {
            Issue.record("Block not found"); return
        }

        let newRaw = reconstructRaw(match: match, oldContent: "Second", newContent: "Replaced")
        #expect(newRaw == "2. Replaced")

        let result = applyRewrite(markdown: markdown, match: match, newRaw: newRaw)
        #expect(result == "1. First\n2. Replaced\n3. Third")
    }

    // MARK: - Multi-line list item with continuation

    @Test("Multi-line list item — continuation indentation handled")
    func multiLineListRewrite() {
        let markdown = "- Item one\n    continuation line\n- Item two"
        let parsed = BlockParser.parse(markdown)
        guard let match = parsed.first(where: { $0.content.hasPrefix("Item one") }) else {
            Issue.record("Multi-line block not found"); return
        }
        // BlockParser strips continuation indent from content but keeps it in rawContent
        #expect(match.rawContent.contains("    continuation"))
        #expect(!match.content.contains("    continuation"))

        let newRaw = reconstructRaw(match: match, oldContent: match.content, newContent: "Replaced entirely")
        #expect(newRaw == "- Replaced entirely", "Prefix preserved, old continuation dropped")

        let result = applyRewrite(markdown: markdown, match: match, newRaw: newRaw)
        #expect(result == "- Replaced entirely\n- Item two")
    }

    // MARK: - Multiline newContent gets continuation indent

    @Test("Multiline newContent — continuation lines get marker-width indent")
    func multilineNewContent() {
        let markdown = "- Original item\n- Other item"
        let parsed = BlockParser.parse(markdown)
        guard let match = parsed.first(where: { $0.content == "Original item" }) else {
            Issue.record("Block not found"); return
        }

        let newRaw = reconstructRaw(
            match: match,
            oldContent: "Original item",
            newContent: "Edited line\nmore detail\nthird line"
        )
        // "- " is 2 chars, so continuation gets 2-space indent
        #expect(newRaw == "- Edited line\n  more detail\n  third line")

        let result = applyRewrite(markdown: markdown, match: match, newRaw: newRaw)
        #expect(result == "- Edited line\n  more detail\n  third line\n- Other item")
    }

    @Test("Nested multiline newContent — deeper indent preserved")
    func nestedMultilineNewContent() {
        let markdown = "- Parent\n  - Child item\n  - Other"
        let parsed = BlockParser.parse(markdown)
        guard let match = parsed.first(where: { $0.content == "Child item" }) else {
            Issue.record("Block not found"); return
        }

        let newRaw = reconstructRaw(
            match: match,
            oldContent: "Child item",
            newContent: "Edited\nextra line"
        )
        // "  - " is 4 chars, so continuation gets 4-space indent
        #expect(newRaw == "  - Edited\n    extra line")
    }

    // MARK: - Duplicate content by order

    @Test("Duplicate content — order tiebreaker picks correct occurrence")
    func duplicateContentOrder() {
        let markdown = "- Same text\n- Different\n- Same text"
        let parsed = BlockParser.parse(markdown)
        #expect(parsed.filter({ $0.content == "Same text" }).count == 2)

        let match = parsed.first(where: { $0.content == "Same text" && $0.order == 2 })
        guard let match else { Issue.record("Second occurrence not found"); return }

        let newRaw = reconstructRaw(match: match, oldContent: "Same text", newContent: "Replaced")
        let result = applyRewrite(markdown: markdown, match: match, newRaw: newRaw)
        #expect(result == "- Same text\n- Different\n- Replaced")
    }

    // MARK: - Heading

    @Test("Heading preserves # markers through rewrite")
    func headingRewrite() {
        let markdown = "# Title\nParagraph text"
        let parsed = BlockParser.parse(markdown)
        guard let match = parsed.first(where: { $0.content.hasPrefix("#") }) else {
            Issue.record("Heading not found"); return
        }

        // For headings, content == rawContent (no stripping), so prefix is ""
        let newRaw = reconstructRaw(match: match, oldContent: match.content, newContent: "# New Title")
        let result = applyRewrite(markdown: markdown, match: match, newRaw: newRaw)
        #expect(result == "# New Title\nParagraph text")
    }

    // MARK: - Unicode with emoji

    @Test("Unicode content with emoji survives utf16 offset mapping")
    func unicodeRewrite() {
        let markdown = "- First\n- Hello 🌍 world\n- Last"
        let parsed = BlockParser.parse(markdown)
        guard let match = parsed.first(where: { $0.content.contains("🌍") }) else {
            Issue.record("Emoji block not found"); return
        }

        let newRaw = reconstructRaw(match: match, oldContent: match.content, newContent: "Goodbye 🌎 earth")
        #expect(newRaw == "- Goodbye 🌎 earth")

        let result = applyRewrite(markdown: markdown, match: match, newRaw: newRaw)
        #expect(result == "- First\n- Goodbye 🌎 earth\n- Last")
    }

    // MARK: - Task item preserves "- [ ] " marker

    @Test("Task item preserves checkbox marker")
    func taskItemRewrite() {
        let markdown = "- [ ] Unchecked task\n- [x] Done task"
        let parsed = BlockParser.parse(markdown)
        guard let match = parsed.first(where: { $0.content.contains("Unchecked") }) else {
            Issue.record("Task block not found"); return
        }

        let newRaw = reconstructRaw(match: match, oldContent: match.content, newContent: "[ ] Updated task")
        // The "- " prefix is preserved; "[ ] " is part of the content
        #expect(newRaw == "- [ ] Updated task")
    }
}

// MARK: - Suite 7: Block Mirror Sync

@Suite("TK2 Parity - Block Mirror")
struct BlockMirrorTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SDBlock.self, configurations: config)
        return ModelContext(container)
    }

    @Test("Block mirror preserves edited block ID across insertions")
    @MainActor
    func preservesBlockIdentityAcrossInsertions() throws {
        let context = try makeContext()
        let pageId = "page-1"

        BlockMirror.sync(
            pageId: pageId,
            body: "- Alpha block\n- Beta block",
            modelContext: context
        )

        let descriptor = FetchDescriptor<SDBlock>(
            predicate: #Predicate<SDBlock> { $0.pageId == pageId },
            sortBy: [SortDescriptor(\.order)]
        )
        let originalBlocks = try context.fetch(descriptor)
        #expect(originalBlocks.count == 2)

        let alphaId = originalBlocks[0].id

        BlockMirror.sync(
            pageId: pageId,
            body: "- New opening\n- Alpha block expanded\n- Beta block",
            modelContext: context
        )

        let syncedBlocks = try context.fetch(descriptor)
        #expect(syncedBlocks.count == 3)
        #expect(syncedBlocks[1].id == alphaId)
        #expect(syncedBlocks[1].content == "Alpha block expanded")

        let parsed = BlockParser.parse("- New opening\n- Alpha block expanded\n- Beta block")
        #expect(syncedBlocks[1].sourceStartUTF16 == parsed[1].utf16Range.lowerBound)
        #expect(syncedBlocks[1].sourceEndUTF16 == parsed[1].utf16Range.upperBound)
    }

    @Test("Transclusion rewrite uses stored source range instead of stale content and order")
    @MainActor
    func rewriteUsesStoredRange() {
        let body = "- Current body text\n- Other block"
        let parsed = BlockParser.parse(body)
        let target = parsed[0]

        let block = SDBlock(pageId: "page-2", content: "Old stale snapshot", depth: 0, order: 99_000)
        block.sourceStartUTF16 = target.utf16Range.lowerBound
        block.sourceEndUTF16 = target.utf16Range.upperBound

        let rewritten = BlockMirror.rewrittenBody(
            body: body,
            block: block,
            newContent: "Edited through transclusion"
        )

        #expect(rewritten == "- Edited through transclusion\n- Other block")
    }
}

// MARK: - Wikilink Storage Attributes

@Suite("TK2 Parity - Wikilink Click Navigation")
struct TK2WikilinkStorageTests {

    @Test("Wikilink .link attribute applied to textStorage after reparse")
    func wikilinkLinkInStorage() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.applyTheme(.sunny)
        let md = "see [[MyPage]] here"
        let ts = tv.textStorage!
        tv.markdownDelegate.reparse(text: "")
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: md)
        ts.endEditing()
        tv.didChangeText()

        // After didChangeText, applyLinkAttributesToStorage should have run
        let innerOffset = (md as NSString).range(of: "MyPage").location
        guard innerOffset < ts.length else {
            #expect(Bool(false), "MyPage not found in storage")
            return
        }
        let linkAttr = ts.attribute(.link, at: innerOffset, effectiveRange: nil)
        #expect(linkAttr != nil, "Expected .link attribute on wikilink inner text")
        if let linkStr = linkAttr as? String {
            #expect(linkStr == "wikilink://MyPage")
        }
    }

    @Test("Block ref .link attribute applied to textStorage after reparse")
    func blockRefLinkInStorage() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.applyTheme(.sunny)
        let md = "see ((block-123)) here"
        let ts = tv.textStorage!
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: md)
        ts.endEditing()
        tv.didChangeText()

        let innerOffset = (md as NSString).range(of: "block-123").location
        guard innerOffset < ts.length else {
            #expect(Bool(false), "block-123 not found in storage")
            return
        }
        let linkAttr = ts.attribute(.link, at: innerOffset, effectiveRange: nil)
        #expect(linkAttr != nil, "Expected .link attribute on block ref inner text")
        if let linkStr = linkAttr as? String {
            #expect(linkStr == "blockref://block-123")
        }
    }
}

// MARK: - Block Move

@Suite("TK2 Parity - Block Move")
struct TK2BlockMoveTests {

    @Test("Move block down swaps current and next line")
    func moveBlockDown() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        let md = "line1\nline2\nline3\n"
        let ts = tv.textStorage!
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: md)
        ts.endEditing()
        tv.setSelectedRange(NSRange(location: 2, length: 0)) // cursor in "line1"
        tv.moveBlockDown()
        #expect(tv.string.hasPrefix("line2\nline1\n"))
    }

    @Test("Move block up swaps current and previous line")
    func moveBlockUp() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        let md = "line1\nline2\nline3\n"
        let ts = tv.textStorage!
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: md)
        ts.endEditing()
        tv.setSelectedRange(NSRange(location: 8, length: 0)) // cursor in "line2"
        tv.moveBlockUp()
        #expect(tv.string.hasPrefix("line2\nline1\n"))
    }
}

// MARK: - Heading Insertion

@Suite("TK2 Parity - Heading Insertion")
struct TK2HeadingInsertionTests {

    @Test("insertHeading replaces existing heading prefix")
    func insertHeadingReplace() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        let md = "## Old Heading\n"
        let ts = tv.textStorage!
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: md)
        ts.endEditing()
        tv.setSelectedRange(NSRange(location: 5, length: 0))
        tv.insertHeading(level: 1)
        #expect(tv.string.hasPrefix("# Old Heading"))
    }

    @Test("insertHeading adds prefix to plain line")
    func insertHeadingPlain() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        let md = "Plain text\n"
        let ts = tv.textStorage!
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: md)
        ts.endEditing()
        tv.setSelectedRange(NSRange(location: 3, length: 0))
        tv.insertHeading(level: 3)
        #expect(tv.string.hasPrefix("### Plain text"))
    }
}

// MARK: - Formatting Actions

@Suite("TK2 Parity - Formatting Actions")
struct TK2FormattingTests {

    @Test("toggleLinePrefix adds bullet prefix to plain line")
    func toggleBulletAdd() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        let ts = tv.textStorage!
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: "Some text\n")
        ts.endEditing()
        tv.setSelectedRange(NSRange(location: 3, length: 0))
        tv.toggleLinePrefix("- ")
        #expect(tv.string.hasPrefix("- Some text"))
    }

    @Test("toggleLinePrefix removes existing bullet prefix")
    func toggleBulletRemove() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        let ts = tv.textStorage!
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: "- Some text\n")
        ts.endEditing()
        tv.setSelectedRange(NSRange(location: 5, length: 0))
        tv.toggleLinePrefix("- ")
        #expect(tv.string.hasPrefix("Some text"))
    }

    @Test("wrapSelection wraps selected text with markers")
    func wrapBold() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        let ts = tv.textStorage!
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: "Hello world")
        ts.endEditing()
        tv.setSelectedRange(NSRange(location: 6, length: 5)) // "world"
        tv.wrapSelection("**", "**")
        #expect(tv.string == "Hello **world**")
    }

    @Test("Table insertion creates valid markdown table")
    func insertTable() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        let ts = tv.textStorage!
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: "")
        ts.endEditing()
        tv.setSelectedRange(NSRange(location: 0, length: 0))
        tv.insertMarkdownTable(NSMenuItem())
        let result = tv.string
        #expect(result.contains("| Column 1 |"))
        #expect(result.contains("| --- |"))
    }
}

} // end TextKit2ParityTests
