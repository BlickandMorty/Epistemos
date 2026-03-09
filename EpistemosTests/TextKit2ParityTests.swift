import Testing
import AppKit
@testable import Epistemos

// MARK: - Suite 1: Inline Styling Parity (TK1 vs TK2)

@Suite("TK2 Parity - Inline Styling")
struct TK2ParityInlineTests {

    // MARK: - Helpers

    /// Style text through TK1 (MarkdownTextStorage).
    /// Returns the styled NSAttributedString after full restyle.
    private func tk1Styled(_ markdown: String, isDark: Bool = false) -> NSAttributedString {
        let storage = MarkdownTextStorage()
        storage.isDark = isDark
        storage.beginEditing()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: markdown)
        storage.endEditing()
        storage.reapplyAllStyles()
        return storage
    }

    /// Style text through TK2 (MarkdownContentStorage delegate).
    /// Applies structural + inline styles using the same Rust FFI parser.
    private func tk2Styled(_ markdown: String, theme: EpistemosTheme = .sunny) -> NSMutableAttributedString {
        let delegate = MarkdownContentStorage()
        delegate.theme = theme
        delegate.reparse(text: markdown)

        let attrStr = NSMutableAttributedString(string: markdown)
        let fullRange = NSRange(location: 0, length: attrStr.length)
        guard fullRange.length > 0 else { return attrStr }

        // Structural style for the first line (body by default)
        let paraType = delegate.paragraphType(at: 0) ?? 0
        let metadata = delegate.paragraphMetadata(at: 0) ?? 0
        delegate.applyStructuralStyleForTest(to: attrStr, range: fullRange, paraType: paraType, metadata: metadata)

        // Inline styles
        delegate.applyInlineStyles(to: attrStr, fullRange: fullRange)
        return attrStr
    }

    // MARK: - Bold

    @Test("Bold text — both stacks apply bold font trait")
    func boldParity() {
        let md = "Hello **bold** world"
        let tk1 = tk1Styled(md)
        let tk2 = tk2Styled(md)

        // Both should have identical raw text
        #expect(tk1.string == tk2.string)

        // "bold" content at UTF-16 offset 8, length 4 (after "Hello **")
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
        let tk1 = tk1Styled(md)
        let tk2 = tk2Styled(md)

        // Opening ** at position 0
        let tk1Color = tk1.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        let tk2Color = tk2.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(tk1Color != nil)
        #expect(tk2Color != nil)
        #expect(tk1Color!.alphaComponent < 0.2)
        #expect(tk2Color!.alphaComponent < 0.2)
    }

    // MARK: - Italic

    @Test("Italic text — both stacks apply italic font trait")
    func italicParity() {
        let md = "Hello *italic* world"
        let tk1 = tk1Styled(md)
        let tk2 = tk2Styled(md)

        #expect(tk1.string == tk2.string)

        // "italic" content at UTF-16 offset 7, length 6 (after "Hello *")
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
        let tk1 = tk1Styled(md)
        let tk2 = tk2Styled(md)

        #expect(tk1.string == tk2.string)

        // "code" content at offset 5 (after "Use `")
        let offset = 5
        let tk1Font = tk1.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        #expect(tk1Font != nil)
        #expect(tk2Font != nil)
        #expect(tk1Font!.isFixedPitch || tk1Font!.fontName.lowercased().contains("mono"))
        #expect(tk2Font!.isFixedPitch || tk2Font!.fontName.lowercased().contains("mono"))

        // Both should have accent background
        let tk1Bg = tk1.attribute(.backgroundColor, at: offset, effectiveRange: nil) as? NSColor
        let tk2Bg = tk2.attribute(.backgroundColor, at: offset, effectiveRange: nil) as? NSColor
        #expect(tk1Bg != nil)
        #expect(tk2Bg != nil)
    }

    // MARK: - Wikilinks

    @Test("Wikilink — both stacks apply .link attribute")
    func wikilinkParity() {
        let md = "See [[My Note]] here"
        let tk1 = tk1Styled(md)
        let tk2 = tk2Styled(md)

        #expect(tk1.string == tk2.string)

        // Find .link attribute in both
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
        let tk1 = tk1Styled(md)
        let tk2 = tk2Styled(md)

        #expect(tk1.string == tk2.string)

        // "struck" content at offset 8 (after "Hello ~~")
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
        let tk1 = tk1Styled(md)
        let tk2 = tk2Styled(md)

        #expect(tk1.string == tk2.string)

        // Content starts after "***" = offset 3, length 10
        // The Rust parser emits nested bold + italic spans.
        // Both stacks should produce a bold font on the content.
        // (Italic may or may not layer on depending on span ordering.)
        let offset = 3
        let tk1Font = tk1.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        let tk1Traits = tk1Font.flatMap { NSFontManager.shared.traits(of: $0) } ?? []
        let tk2Traits = tk2Font.flatMap { NSFontManager.shared.traits(of: $0) } ?? []

        // At minimum, bold should be present in both
        #expect(tk1Traits.contains(.boldFontMask))
        #expect(tk2Traits.contains(.boldFontMask))
    }
}

// MARK: - Suite 2: Paragraph Classification Parity

@Suite("TK2 Parity - Paragraph Classification")
struct TK2ParityParagraphTests {

    // MARK: - Helpers

    /// TK1: load markdown, run full restyle, return styled storage.
    private func tk1Styled(_ markdown: String, isDark: Bool = false) -> NSAttributedString {
        let storage = MarkdownTextStorage()
        storage.isDark = isDark
        storage.beginEditing()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: markdown)
        storage.endEditing()
        storage.reapplyAllStyles()
        return storage
    }

    /// TK2: reparse + apply structural/inline styles via MarkdownContentStorage.
    /// Applies per-line structural styles, then inline styles over the full range.
    /// Reliable in headless tests (no NSTextContentStorageDelegate required).
    private func tk2Styled(_ markdown: String, theme: EpistemosTheme = .sunny) -> NSMutableAttributedString {
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

    // MARK: - H1

    @Test("H1 heading — both stacks preserve text and apply font larger than body (15pt)")
    func h1Parity() {
        let md = "# Big Heading"
        let tk1 = tk1Styled(md)
        let tk2 = tk2Styled(md)

        #expect(tk1.string == tk2.string)

        // Content starts at offset 2 (after "# ")
        let tk1Font = tk1.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        #expect(tk1Font != nil)
        #expect(tk2Font != nil)
        #expect(tk1Font!.pointSize > 15)
        #expect(tk2Font!.pointSize > 15)
    }

    // MARK: - H2

    @Test("H2 heading — both stacks preserve text and apply font larger than body")
    func h2Parity() {
        let md = "## Sub Heading"
        let tk1 = tk1Styled(md)
        let tk2 = tk2Styled(md)

        #expect(tk1.string == tk2.string)

        // Content starts at offset 3 (after "## ")
        let tk1Font = tk1.attribute(.font, at: 3, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: 3, effectiveRange: nil) as? NSFont
        #expect(tk1Font != nil)
        #expect(tk2Font != nil)
        #expect(tk1Font!.pointSize > 15)
        #expect(tk2Font!.pointSize > 15)
    }

    // MARK: - Blockquote

    @Test("Blockquote — both stacks preserve text and apply foreground color")
    func blockquoteParity() {
        let md = "> quoted text"
        let tk1 = tk1Styled(md)
        let tk2 = tk2Styled(md)

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
        let tk1 = tk1Styled(md)
        let tk2 = tk2Styled(md)

        #expect(tk1.string == tk2.string)

        // "code here" starts at offset 4 (after "```\n")
        let tk1Fg = tk1.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? NSColor
        let tk2Fg = tk2.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? NSColor
        #expect(tk1Fg != nil)
        #expect(tk2Fg != nil)

        // TK2 code block applies monospace font
        let tk2Font = tk2.attribute(.font, at: 5, effectiveRange: nil) as? NSFont
        #expect(tk2Font != nil)
        #expect(tk2Font!.isFixedPitch || tk2Font!.fontName.lowercased().contains("mono"))
    }

    // MARK: - Text Preservation

    @Test("Multi-element document — both stacks preserve identical text")
    func multiElementTextParity() {
        let md = "# Title\n\nBody text\n\n- list item\n\n> blockquote\n\n```\ncode\n```"
        let tk1 = tk1Styled(md)
        let tk2 = tk2Styled(md)

        #expect(tk1.string == md)
        #expect(tk2.string == md)
        #expect(tk1.string == tk2.string)
    }
}

// MARK: - Suite 3: AI Streaming Parity

@Suite("TK2 Parity - AI Streaming")
struct TK2ParityAIStreamingTests {

    private let divider = "\n\n<!-- ai-response -->\n\n"
    private let initialBody = "User's note content here."

    // MARK: - Helpers

    private func tk1Storage(with text: String) -> MarkdownTextStorage {
        let storage = MarkdownTextStorage()
        storage.beginEditing()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: text)
        storage.endEditing()
        return storage
    }

    private func tk2View(with text: String) -> ProseTextView2 {
        let (_, tv) = ProseTextView2.makeTextKit2()
        tv.textStorage?.setAttributedString(NSAttributedString(string: text))
        tv.reparseAndInvalidate()
        return tv
    }

    // MARK: - Divider Insertion

    @Test("Divider insertion — both stacks produce same text after appending divider")
    func dividerInsertion() {
        let expected = initialBody + divider
        let tk1 = tk1Storage(with: initialBody)
        tk1.beginEditing()
        tk1.replaceCharacters(
            in: NSRange(location: tk1.length, length: 0),
            with: divider
        )
        tk1.endEditing()

        let tk2 = tk2View(with: initialBody)
        tk2.textStorage?.replaceCharacters(
            in: NSRange(location: (tk2.string as NSString).length, length: 0),
            with: divider
        )

        #expect(tk1.string == expected)
        #expect(tk2.string == expected)
    }

    // MARK: - Token Append

    @Test("Token append — streaming tokens produce same string in both stacks")
    func tokenAppend() {
        let tokens = ["Here ", "is ", "the ", "AI ", "response."]
        let fullText = initialBody + divider + tokens.joined()

        let tk1 = tk1Storage(with: initialBody + divider)
        for token in tokens {
            tk1.beginEditing()
            tk1.replaceCharacters(
                in: NSRange(location: tk1.length, length: 0),
                with: token
            )
            tk1.endEditing()
        }

        let tk2 = tk2View(with: initialBody + divider)
        for token in tokens {
            let ts = tk2.textStorage!
            ts.replaceCharacters(
                in: NSRange(location: ts.length, length: 0),
                with: token
            )
        }

        #expect(tk1.string == fullText)
        #expect(tk2.string == fullText)
        #expect(tk1.string == tk2.string)
    }

    // MARK: - Accept (replace divider with newlines)

    @Test("Accept — replacing divider with double newline produces same text")
    func acceptOperation() {
        let streamed = initialBody + divider + "AI response text."
        let expected = initialBody + "\n\n" + "AI response text."

        let tk1 = tk1Storage(with: streamed)
        let tk1DividerRange = (tk1.string as NSString).range(of: divider)
        #expect(tk1DividerRange.location != NSNotFound)
        tk1.beginEditing()
        tk1.replaceCharacters(in: tk1DividerRange, with: "\n\n")
        tk1.endEditing()

        let tk2 = tk2View(with: streamed)
        let tk2DividerRange = (tk2.string as NSString).range(of: divider)
        #expect(tk2DividerRange.location != NSNotFound)
        tk2.textStorage?.replaceCharacters(in: tk2DividerRange, with: "\n\n")

        #expect(tk1.string == expected)
        #expect(tk2.string == expected)
        #expect(tk1.string == tk2.string)
    }

    // MARK: - Discard (delete from divider to end)

    @Test("Discard — deleting from divider to end produces same text")
    func discardOperation() {
        let streamed = initialBody + divider + "AI response text."

        let tk1 = tk1Storage(with: streamed)
        let tk1DividerLoc = (tk1.string as NSString).range(of: divider).location
        #expect(tk1DividerLoc != NSNotFound)
        let tk1DeleteRange = NSRange(location: tk1DividerLoc, length: tk1.length - tk1DividerLoc)
        tk1.beginEditing()
        tk1.replaceCharacters(in: tk1DeleteRange, with: "")
        tk1.endEditing()

        let tk2 = tk2View(with: streamed)
        let tk2DividerLoc = (tk2.string as NSString).range(of: divider).location
        #expect(tk2DividerLoc != NSNotFound)
        let tk2Len = (tk2.string as NSString).length
        let tk2DeleteRange = NSRange(location: tk2DividerLoc, length: tk2Len - tk2DividerLoc)
        tk2.textStorage?.replaceCharacters(in: tk2DeleteRange, with: "")

        #expect(tk1.string == initialBody)
        #expect(tk2.string == initialBody)
        #expect(tk1.string == tk2.string)
    }

    // MARK: - Divider Format

    @Test("AI divider — both stacks locate divider at same offset in document")
    func dividerFormat() {
        let doc = initialBody + divider + "AI response."
        let tk1 = tk1Storage(with: doc)
        let tk2 = tk2View(with: doc)

        let tk1Loc = (tk1.string as NSString).range(of: "<!-- ai-response -->").location
        let tk2Loc = (tk2.string as NSString).range(of: "<!-- ai-response -->").location
        #expect(tk1Loc != NSNotFound)
        #expect(tk2Loc != NSNotFound)
        #expect(tk1Loc == tk2Loc)
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

    /// TK1: load markdown, run full restyle, return styled storage.
    private func tk1Styled(_ markdown: String) -> NSAttributedString {
        let storage = MarkdownTextStorage()
        guard !markdown.isEmpty else { return storage }
        storage.beginEditing()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: markdown)
        storage.endEditing()
        storage.reapplyAllStyles()
        return storage
    }

    /// TK2: reparse + apply structural/inline styles via MarkdownContentStorage.
    private func tk2Styled(_ markdown: String, theme: EpistemosTheme = .sunny) -> NSMutableAttributedString {
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
        let tk1 = tk1Styled(md)
        let tk2 = tk2Styled(md)

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
