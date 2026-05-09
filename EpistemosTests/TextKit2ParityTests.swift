import Testing
import AppKit
import SwiftUI
import SwiftData
@testable import Epistemos

// MARK: - Shared Parity Helpers

@MainActor
private enum ParityHelpers {

    /// Style text through the legacy compatibility MarkdownTextStorage shim.
    /// Returns the styled NSAttributedString after full restyle.
    static func tk1Styled(_ markdown: String, theme: EpistemosTheme = .light) -> NSAttributedString {
        EpistemosFont.registerFonts()
        let storage = MarkdownTextStorage()
        storage.isDark = theme.isDark
        storage.theme = theme
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
        EpistemosFont.registerFonts()
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

    @MainActor
    static func tk2DisplayParagraphs(
        _ markdown: String,
        theme: EpistemosTheme = .sunny
    ) -> [NSAttributedString] {
        EpistemosFont.registerFonts()
        let (_, textView) = ProseTextView2.makeTextKit2()
        textView.applyTheme(theme)
        textView.textStorage?.setAttributedString(NSAttributedString(string: markdown))
        textView.reparseAndInvalidate()

        guard let textLayoutManager = textView.textLayoutManager,
              let contentStorage = textLayoutManager.textContentManager as? NSTextContentStorage else {
            return []
        }

        textLayoutManager.ensureLayout(for: contentStorage.documentRange)

        var paragraphs: [NSAttributedString] = []
        contentStorage.enumerateTextElements(from: contentStorage.documentRange.location) { element in
            if let paragraph = element as? NSTextParagraph {
                paragraphs.append(paragraph.attributedString)
            }
            return true
        }
        return paragraphs
    }

    static func colorsMatch(_ lhs: NSColor?, _ rhs: NSColor?) -> Bool {
        guard let lhsChannels = colorChannels(lhs), let rhsChannels = colorChannels(rhs) else {
            return false
        }
        let lhsValues = [lhsChannels.0, lhsChannels.1, lhsChannels.2, lhsChannels.3]
        let rhsValues = [rhsChannels.0, rhsChannels.1, rhsChannels.2, rhsChannels.3]
        return zip(lhsValues, rhsValues).allSatisfy { abs($0 - $1) <= 2 }
    }

    static func paragraphStylesMatch(_ lhs: NSParagraphStyle?, _ rhs: NSParagraphStyle?) -> Bool {
        guard let lhs, let rhs else { return false }
        let deltas = [
            abs(lhs.firstLineHeadIndent - rhs.firstLineHeadIndent),
            abs(lhs.headIndent - rhs.headIndent),
            abs(lhs.paragraphSpacing - rhs.paragraphSpacing),
            abs(lhs.paragraphSpacingBefore - rhs.paragraphSpacingBefore),
            abs(lhs.lineSpacing - rhs.lineSpacing),
            abs(lhs.minimumLineHeight - rhs.minimumLineHeight),
            abs(lhs.maximumLineHeight - rhs.maximumLineHeight),
        ]
        return deltas.allSatisfy { $0 <= 0.01 } && lhs.alignment == rhs.alignment
    }

    static func fontsMatch(_ lhs: NSFont?, _ rhs: NSFont?) -> Bool {
        guard let lhs, let rhs else { return false }

        let manager = NSFontManager.shared
        let lhsTraits = manager.traits(of: lhs)
        let rhsTraits = manager.traits(of: rhs)
        let lhsIsMonospaced = isMonospaced(lhs)
        let rhsIsMonospaced = isMonospaced(rhs)
        let lhsIsRegularUIFont = AppDisplayTypography.isRegularUIFont(lhs)
        let rhsIsRegularUIFont = AppDisplayTypography.isRegularUIFont(rhs)

        guard abs(lhs.pointSize - rhs.pointSize) <= 0.01,
              lhsIsMonospaced == rhsIsMonospaced,
              lhsTraits.contains(.boldFontMask) == rhsTraits.contains(.boldFontMask),
              lhsTraits.contains(.italicFontMask) == rhsTraits.contains(.italicFontMask) else {
            return false
        }

        if lhsIsRegularUIFont && rhsIsRegularUIFont {
            return true
        }

        return lhs.fontName == rhs.fontName
    }

    static func isMonospaced(_ font: NSFont?) -> Bool {
        guard let font else { return false }
        return font.isFixedPitch
            || font.fontDescriptor.symbolicTraits.contains(.monoSpace)
            || font.fontName.lowercased().contains("mono")
    }

    private static func colorChannels(_ color: NSColor?) -> (Int, Int, Int, Int)? {
        guard
            let cgColor = color?.cgColor,
            let components = cgColor.components
        else { return nil }
        func channel(_ value: CGFloat) -> Int { Int((value * 255).rounded()) }
        switch components.count {
        case 4...:
            return (
                channel(components[0]),
                channel(components[1]),
                channel(components[2]),
                channel(components[3])
            )
        case 2:
            let gray = channel(components[0])
            let alpha = channel(components[1])
            return (gray, gray, gray, alpha)
        default:
            return nil
        }
    }
}

// MARK: - Parent Suite (enables -only-testing:EpistemosTests/TextKit2ParityTests)

@Suite("TextKit 2 Parity Tests")
enum TextKit2ParityTests {

@Suite("TK2 Parity - Editor Shell")
@MainActor
struct EditorShellTests {

    @MainActor
    @Test("TK2 editor headings preserve the original heading text casing")
    func tk2EditorHeadingsPreserveOriginalCasing() throws {
        let paragraphs = ParityHelpers.tk2DisplayParagraphs("# Mixed Case Heading")
        let heading = try #require(paragraphs.first)

        #expect(heading.string == "# Mixed Case Heading")
    }

    @Test("code blocks, quotes, and callouts carry block chrome markers")
    func blockChromeMarkersApplyAcrossEditorStacks() {
        let tk1Code = ParityHelpers.tk1Styled("```\nlet value = 1\n```")
        let tk1Quote = ParityHelpers.tk1Styled("> quoted")
        let tk2Callout = ParityHelpers.tk2Styled("> [!note] Title")

        let codeKind = tk1Code.attribute(
            MarkdownTextStorage.blockChromeKindAttribute,
            at: 0,
            effectiveRange: nil
        ) as? String
        let quoteKind = tk1Quote.attribute(
            MarkdownTextStorage.blockChromeKindAttribute,
            at: 0,
            effectiveRange: nil
        ) as? String
        let calloutKind = tk2Callout.attribute(
            MarkdownTextStorage.blockChromeKindAttribute,
            at: 0,
            effectiveRange: nil
        ) as? String

        #expect(codeKind == MarkdownBlockChromeKind.codeBlock.rawValue)
        #expect(quoteKind == MarkdownBlockChromeKind.quote.rawValue)
        #expect(calloutKind == MarkdownBlockChromeKind.callout.rawValue)
    }

    @Test("block chrome paragraphs do not rely on per-line background fills")
    func blockChromeParagraphsDoNotUseBackgroundColor() {
        let tk1Code = ParityHelpers.tk1Styled("```\nlet value = 1\n```")
        let tk1Quote = ParityHelpers.tk1Styled("> quoted")
        let tk2Callout = ParityHelpers.tk2Styled("> [!note] Title")

        let tk1CodeBackground = tk1Code.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor
        let tk1QuoteBackground = tk1Quote.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor
        let tk2CalloutBackground = tk2Callout.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor

        #expect(tk1CodeBackground == nil)
        #expect(tk1QuoteBackground == nil)
        #expect(tk2CalloutBackground == nil)
    }

    @Test("block chrome spans resolve across the full multi-line block in both editor stacks")
    func blockChromeSpansResolveAcrossFullBlock() throws {
        let markdown = """
        Before

        ```swift
        let value = 1
        let value = 2
        ```

        > [!note] Title
        > Continuation

        After
        """
        let text = markdown as NSString
        let tk1 = ParityHelpers.tk1Styled(markdown)
        let tk2 = ParityHelpers.tk2Styled(markdown)

        let codeProbe = text.lineRange(for: text.range(of: "let value = 2"))
        let calloutProbe = text.lineRange(for: text.range(of: "> Continuation"))
        let codeStart = text.lineRange(for: text.range(of: "```swift"))
        let codeEnd = text.lineRange(for: text.range(of: "```", options: .backwards))
        let calloutStart = text.lineRange(for: text.range(of: "> [!note] Title"))
        let calloutEnd = text.lineRange(for: text.range(of: "> Continuation"))

        let tk1CodeSpan = try #require(
            MarkdownTextStorage.blockChromeSpan(in: tk1, text: text, aroundLineRange: codeProbe)
        )
        let tk2CodeSpan = try #require(
            MarkdownTextStorage.blockChromeSpan(in: tk2, text: text, aroundLineRange: codeProbe)
        )
        let tk1CalloutSpan = try #require(
            MarkdownTextStorage.blockChromeSpan(in: tk1, text: text, aroundLineRange: calloutProbe)
        )
        let tk2CalloutSpan = try #require(
            MarkdownTextStorage.blockChromeSpan(in: tk2, text: text, aroundLineRange: calloutProbe)
        )

        let expectedCodeRange = NSRange(
            location: codeStart.location,
            length: NSMaxRange(codeEnd) - codeStart.location
        )
        let expectedCalloutRange = NSRange(
            location: calloutStart.location,
            length: NSMaxRange(calloutEnd) - calloutStart.location
        )

        #expect(tk1CodeSpan.kind == .codeBlock)
        #expect(tk2CodeSpan.kind == .codeBlock)
        #expect(tk1CodeSpan.lineRange == expectedCodeRange)
        #expect(tk2CodeSpan.lineRange == expectedCodeRange)

        #expect(tk1CalloutSpan.kind == .callout)
        #expect(tk2CalloutSpan.kind == .callout)
        #expect(tk1CalloutSpan.lineRange == expectedCalloutRange)
        #expect(tk2CalloutSpan.lineRange == expectedCalloutRange)
    }
}

// MARK: - Suite 1: Inline Styling Parity (legacy compatibility vs TK2)

@Suite("TK2 Parity - Inline Styling")
@MainActor
struct InlineTests {

    // MARK: - Bold

    @Test("Bold text in notes stays on the body font family in both stacks")
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
        #expect(tk1Font?.fontName.contains("RetroGaming") == false)
        #expect(tk2Font?.fontName.contains("RetroGaming") == false)
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

    @Test("Bold content stays readable in the legacy stack and the TK2 stack")
    func boldContentPreservesReadableForeground() {
        let md = "**bold**"
        let tk1 = ParityHelpers.tk1Styled(md, theme: .oled)
        let tk2 = ParityHelpers.tk2Styled(md, theme: .oled)

        let expected = EpistemosTheme.oled.resolved.foreground.nsColor
        let tk1Color = tk1.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor
        let tk2Color = tk2.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor

        #expect(ParityHelpers.colorsMatch(tk1Color, expected))
        #expect(ParityHelpers.colorsMatch(tk2Color, expected))
    }

    // MARK: - Italic

    @Test("Italic text preserves emphasis in both legacy-compatible and TK2 display paths")
    func italicParity() {
        let md = "Hello *italic* world"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        #expect(tk1.string == tk2.string)

        let offset = 7
        let tk2Font = tk2.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        let tk2Traits = tk2Font.flatMap { NSFontManager.shared.traits(of: $0) } ?? []
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

        let tk1IsMono = ParityHelpers.isMonospaced(tk1Font)
        let tk2IsMono = ParityHelpers.isMonospaced(tk2Font)
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

    @Test("Bold-italic (***) stays on the body font family in both stacks")
    func boldItalicParity() {
        let md = "***bolditalic***"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        #expect(tk1.string == tk2.string)

        let offset = 3
        let tk1Font = tk1.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
        #expect(tk1Font?.fontName.contains("RetroGaming") == false)
        #expect(tk2Font?.fontName.contains("RetroGaming") == false)
    }

    // MARK: - Full-Stack Integration (ProseTextView2 delegate pipeline)

    @Test("Full-stack bold — ProseTextView2 delegate keeps inline content out of the display font")
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

        var foundNonDisplayFont = false
        contentStorage.enumerateTextElements(from: contentStorage.documentRange.location) { element in
            guard let para = element as? NSTextParagraph else { return true }
            let attrStr = para.attributedString
            // "bold" content starts at offset 8 in "Hello **bold** world"
            guard attrStr.length > 8 else { return true }
            let font = attrStr.attribute(.font, at: 8, effectiveRange: nil) as? NSFont
            if font?.fontName.contains("RetroGaming") != true {
                foundNonDisplayFont = true
            }
            return false
        }
        #expect(foundNonDisplayFont)
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
@MainActor
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

    @Test("H1 heading in notes uses RetroGaming display font in both stacks")
    func h1UsesDisplayFont() {
        let md = "# Big Heading"
        let tk1 = ParityHelpers.tk1Styled(md, theme: .magnolia)
        let tk2 = ParityHelpers.tk2Styled(md, theme: .magnolia)

        let tk1Font = tk1.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        #expect(tk1Font?.fontName.contains("RetroGaming") == true)
        #expect(tk2Font?.fontName.contains("RetroGaming") == true)

        let expectedColor = NSColor(EpistemosTheme.magnolia.fontAccent)
        let tk1Color = tk1.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor
        let tk2Color = tk2.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor
        #expect(ParityHelpers.colorsMatch(tk1Color, expectedColor))
        #expect(ParityHelpers.colorsMatch(tk2Color, expectedColor))
    }

    @MainActor
    @Test("TK2 display H1 matches the legacy note heading size")
    func tk2DisplayH1MatchesLegacySize() {
        let markdown = "# Big Heading"
        let tk1 = ParityHelpers.tk1Styled(markdown)
        let paragraphs = ParityHelpers.tk2DisplayParagraphs(markdown)
        let tk2 = try! #require(paragraphs.first)

        let tk1Font = tk1.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        #expect(tk1Font?.pointSize == tk2Font?.pointSize)
    }

    @MainActor
    @Test("H1 note headings scale down for longer titles but stay above H2")
    func h1AdaptiveSizingMatchesAcrossStacks() {
        let shortMarkdown = "# All Things Must Go"
        let mediumMarkdown = "# A Neuroscientific explanation of determinism in society"
        let longMarkdown = "# A Neuroscientific explanation of determinism in society across institutions, incentives, and collective mythmaking"

        let shortTK1 = ParityHelpers.tk1Styled(shortMarkdown)
        let mediumTK1 = ParityHelpers.tk1Styled(mediumMarkdown)
        let longTK1 = ParityHelpers.tk1Styled(longMarkdown)
        let h2TK1 = ParityHelpers.tk1Styled("## Sub Heading")

        let shortTK2 = try! #require(ParityHelpers.tk2DisplayParagraphs(shortMarkdown).first)
        let mediumTK2 = try! #require(ParityHelpers.tk2DisplayParagraphs(mediumMarkdown).first)
        let longTK2 = try! #require(ParityHelpers.tk2DisplayParagraphs(longMarkdown).first)

        let shortTK1Size = (shortTK1.attribute(.font, at: 2, effectiveRange: nil) as? NSFont)?.pointSize ?? 0
        let mediumTK1Size = (mediumTK1.attribute(.font, at: 2, effectiveRange: nil) as? NSFont)?.pointSize ?? 0
        let longTK1Size = (longTK1.attribute(.font, at: 2, effectiveRange: nil) as? NSFont)?.pointSize ?? 0
        let h2TK1Size = (h2TK1.attribute(.font, at: 3, effectiveRange: nil) as? NSFont)?.pointSize ?? 0

        let shortTK2Size = (shortTK2.attribute(.font, at: 2, effectiveRange: nil) as? NSFont)?.pointSize ?? 0
        let mediumTK2Size = (mediumTK2.attribute(.font, at: 2, effectiveRange: nil) as? NSFont)?.pointSize ?? 0
        let longTK2Size = (longTK2.attribute(.font, at: 2, effectiveRange: nil) as? NSFont)?.pointSize ?? 0

        #expect(shortTK1Size > mediumTK1Size)
        #expect(mediumTK1Size > longTK1Size)
        #expect(shortTK1Size - mediumTK1Size >= 4)
        #expect(shortTK1Size - longTK1Size >= 8)
        #expect(longTK1Size > h2TK1Size)

        #expect(shortTK1Size == shortTK2Size)
        #expect(mediumTK1Size == mediumTK2Size)
        #expect(longTK1Size == longTK2Size)
    }

    @MainActor
    @Test("TK2 display headings preserve source casing through H3")
    func tk2DisplayHeadingsPreserveSourceCasing() {
        let markdown = "# Big Heading\n## Sub Heading\n### Third Level"
        let (_, textView) = ProseTextView2.makeTextKit2()
        textView.textStorage?.setAttributedString(NSAttributedString(string: markdown))
        textView.reparseAndInvalidate()

        #expect(textView.string == markdown)

        let paragraphs = ParityHelpers.tk2DisplayParagraphs(markdown)
        #expect(paragraphs.count >= 3)
        #expect(paragraphs[0].string == "# Big Heading\n")
        #expect(paragraphs[1].string == "## Sub Heading\n")
        #expect(paragraphs[2].string == "### Third Level")
    }

    @MainActor
    @Test("TK2 display paragraph styles keep heading spacing distinct from body copy")
    func tk2ParagraphStylesMatchLegacy() {
        let headingMarkdown = "# Title"
        let tk2Heading = try! #require(ParityHelpers.tk2DisplayParagraphs(headingMarkdown).first)

        let tk2HeadingStyle = try! #require(
            tk2Heading.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        )

        let bodyMarkdown = "Body text"
        let tk2Body = try! #require(ParityHelpers.tk2DisplayParagraphs(bodyMarkdown).first)

        let tk2BodyStyle = try! #require(
            tk2Body.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        )
        #expect(tk2HeadingStyle.paragraphSpacingBefore > tk2BodyStyle.paragraphSpacingBefore)
        #expect(tk2HeadingStyle != tk2BodyStyle)
    }

    @MainActor
    @Test("TK2 heading styling stays scoped to the selected paragraph")
    func tk2HeadingStyleDoesNotBleedIntoFollowingParagraph() {
        let markdown = "## Start:\nRead these files in order"
        let paragraphs = ParityHelpers.tk2DisplayParagraphs(markdown)
        #expect(paragraphs.count >= 2)

        let headingFont = paragraphs[0].attribute(.font, at: 3, effectiveRange: nil) as? NSFont
        let bodyFont = paragraphs[1].attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let headingStyle = paragraphs[0].attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        let bodyStyle = paragraphs[1].attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle

        #expect((headingFont?.pointSize ?? 0) > (bodyFont?.pointSize ?? 0))
        #expect((headingStyle?.paragraphSpacingBefore ?? 0) > (bodyStyle?.paragraphSpacingBefore ?? 0))
        #expect(abs((bodyStyle?.headIndent ?? 0) - MarkdownEditorStyle.bodyParagraphStyle().headIndent) < 0.01)
    }

    @MainActor
    @Test("TK2 display heading markers inherit TK1 font and color treatment")
    func tk2HeadingMarkerStyleMatchesLegacy() {
        let markdown = "# Big Heading"
        let tk1 = ParityHelpers.tk1Styled(markdown, theme: .magnolia)
        let tk2 = try! #require(ParityHelpers.tk2DisplayParagraphs(markdown, theme: .magnolia).first)

        let tk1Font = tk1.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(ParityHelpers.fontsMatch(tk1Font, tk2Font))

        let tk1Color = tk1.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        let tk2Color = tk2.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(ParityHelpers.colorsMatch(tk1Color, tk2Color))
    }

    @MainActor
    @Test("TK2 display list and quote markers inherit TK1 syntax colors")
    func tk2DisplaySyntaxMarkerColorsMatchLegacy() {
        let listMarkdown = "- list item"
        let tk1List = ParityHelpers.tk1Styled(listMarkdown, theme: .magnolia)
        let tk2List = try! #require(ParityHelpers.tk2DisplayParagraphs(listMarkdown, theme: .magnolia).first)
        let tk1ListColor = tk1List.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        let tk2ListColor = tk2List.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(ParityHelpers.colorsMatch(tk1ListColor, tk2ListColor))

        let quoteMarkdown = "> quoted text"
        let tk1Quote = ParityHelpers.tk1Styled(quoteMarkdown, theme: .magnolia)
        let tk2Quote = try! #require(ParityHelpers.tk2DisplayParagraphs(quoteMarkdown, theme: .magnolia).first)
        let tk1QuoteColor = tk1Quote.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        let tk2QuoteColor = tk2Quote.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(ParityHelpers.colorsMatch(tk1QuoteColor, tk2QuoteColor))
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

    @MainActor
    @Test("TK2 display heading scale keeps a clear H1 > H2 > H3 hierarchy")
    func tk2DisplayHeadingScale() {
        let markdown = "# Title\n## Sub Heading\n### Third Level"
        let paragraphs = ParityHelpers.tk2DisplayParagraphs(markdown)
        #expect(paragraphs.count >= 3)

        let h1Font = paragraphs[0].attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        let h2Font = paragraphs[1].attribute(.font, at: 3, effectiveRange: nil) as? NSFont
        let h3Font = paragraphs[2].attribute(.font, at: 4, effectiveRange: nil) as? NSFont

        #expect(h1Font != nil)
        #expect(h2Font != nil)
        #expect(h3Font != nil)
        #expect((h1Font?.pointSize ?? 0) > (h2Font?.pointSize ?? 0))
        #expect((h2Font?.pointSize ?? 0) >= (h3Font?.pointSize ?? 0))
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

        let tk1Font = tk1.attribute(.font, at: 5, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: 5, effectiveRange: nil) as? NSFont
        #expect(ParityHelpers.fontsMatch(tk1Font, tk2Font))
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
@MainActor
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

    @Test("Inline finalization replaces the streamed draft before commit")
    func inlineFinalizationReplacesStreamedDraftBeforeCommit() {
        let (_, tv, chat, getText) = Self.makeCoordinator2Stack()
        chat.onStreamStart?("q")
        chat.onTokenFlush?("Draft response")
        chat.onReplaceInlineResponse?("Final response")
        chat.onAccept?()

        #expect(!tv.string.contains("<!-- ai-response -->"))
        #expect(tv.string.contains("Final response"))
        #expect(!tv.string.contains("Draft response"))
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

    @Test("Divider protection blocks structural edits but keeps AI text editable")
    func dividerProtectionKeepsResponseEditable() {
        let (_, tv, chat, _) = Self.makeCoordinator2Stack()
        chat.onStreamStart?("q")
        chat.onTokenFlush?("AI response.")

        let dividerRange = (tv.string as NSString).range(of: "\n\n<!-- ai-response -->\n\n")
        #expect(dividerRange.location != NSNotFound)

        let blocked = tv.shouldChangeText(
            in: NSRange(location: dividerRange.location + 1, length: 1),
            replacementString: ""
        )
        #expect(!blocked)

        let responseRange = (tv.string as NSString).range(of: "AI response.")
        #expect(responseRange.location != NSNotFound)

        let allowed = tv.shouldChangeText(
            in: responseRange,
            replacementString: "Edited response."
        )
        #expect(allowed)

        if allowed {
            tv.textStorage?.replaceCharacters(in: responseRange, with: "Edited response.")
            tv.didChangeText()
        }

        #expect(tv.string.contains("<!-- ai-response -->"))
        #expect(tv.string.contains("Edited response."))
    }
}

// MARK: - Suite 4: Edge Cases

@Suite("TK2 Parity - Edge Cases")
@MainActor
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

    @Test("Combined unicode: emoji + bold markdown stays out of the display font in both stacks")
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
        #expect(tk1Font?.fontName.contains("RetroGaming") == false)
        #expect(tk2Font?.fontName.contains("RetroGaming") == false)
    }

    @Test("Bold blockquote content stays out of the display font in both stacks")
    func quoteBoldParity() {
        let md = "> **Quoted** text"
        let tk1 = ParityHelpers.tk1Styled(md)
        let tk2 = ParityHelpers.tk2Styled(md)

        let quotedRange = (md as NSString).range(of: "Quoted")
        let tk1Font = tk1.attribute(.font, at: quotedRange.location, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: quotedRange.location, effectiveRange: nil) as? NSFont
        #expect(tk1Font?.fontName.contains("RetroGaming") == false)
        #expect(tk2Font?.fontName.contains("RetroGaming") == false)
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
@MainActor
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
@MainActor
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
@MainActor
struct BlockMirrorTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SDBlock.self, configurations: config)
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try makeContainer())
    }

    private func fetchBlocks(pageId: String, from container: ModelContainer) throws -> [SDBlock] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDBlock>(
            predicate: #Predicate<SDBlock> { $0.pageId == pageId },
            sortBy: [SortDescriptor(\.order)]
        )
        return try context.fetch(descriptor)
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

    @Test("Unrelated content gets new block ID instead of reusing old one")
    @MainActor
    func unrelatedContentGetsNewId() throws {
        let context = try makeContext()
        let pageId = "page-id-test"

        BlockMirror.sync(
            pageId: pageId,
            body: "- First block about apples\n- Second block about oranges",
            modelContext: context
        )

        let descriptor = FetchDescriptor<SDBlock>(
            predicate: #Predicate<SDBlock> { $0.pageId == pageId },
            sortBy: [SortDescriptor(\.order)]
        )
        let originalBlocks = try context.fetch(descriptor)
        #expect(originalBlocks.count == 2)
        let oldFirstId = originalBlocks[0].id
        let oldSecondId = originalBlocks[1].id

        // Wholesale rewrite — completely unrelated content
        BlockMirror.sync(
            pageId: pageId,
            body: "- Quantum mechanics overview\n- Database schema migration",
            modelContext: context
        )

        let newBlocks = try context.fetch(descriptor)
        #expect(newBlocks.count == 2)
        let newIds = Set(newBlocks.map(\.id))
        // Old IDs must NOT be reused for unrelated content
        #expect(!newIds.contains(oldFirstId))
        #expect(!newIds.contains(oldSecondId))
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

    @Test("Transclusion rewrite reconciles stale stored ranges against current page blocks")
    @MainActor
    func rewriteReconcilesStaleStoredRanges() throws {
        let context = try makeContext()
        let pageId = "page-3"

        BlockMirror.sync(
            pageId: pageId,
            body: "- Alpha\n- Beta\n- Gamma",
            modelContext: context
        )

        let descriptor = FetchDescriptor<SDBlock>(
            predicate: #Predicate<SDBlock> { $0.pageId == pageId },
            sortBy: [SortDescriptor(\.order)]
        )
        let existingBlocks = try context.fetch(descriptor)
        #expect(existingBlocks.count == 3)

        let rewritten = BlockMirror.rewrittenBody(
            body: "- New opening\n- Alpha revised\n- Beta\n- Gamma",
            block: existingBlocks[1],
            existingBlocks: existingBlocks,
            newContent: "Beta edited"
        )

        #expect(rewritten == "- New opening\n- Alpha revised\n- Beta edited\n- Gamma")
    }

    @Test("Background coordinator persists blocks through a separate model context")
    func backgroundCoordinatorPersistsBlocks() async throws {
        let container = try makeContainer()
        let coordinator = BlockMirrorSyncCoordinator()
        let pageId = "page-\(UUID().uuidString)"

        await coordinator.syncNow(
            pageId: pageId,
            body: "- Alpha\n- Beta",
            modelContainer: container
        )

        let blocks = try fetchBlocks(pageId: pageId, from: container)
        #expect(blocks.map(\.content) == ["Alpha", "Beta"])
    }

    @Test("Background coordinator keeps only the latest rescheduled body")
    func backgroundCoordinatorKeepsLatestRescheduledBody() async throws {
        let container = try makeContainer()
        let coordinator = BlockMirrorSyncCoordinator()
        let pageId = "page-\(UUID().uuidString)"

        await coordinator.scheduleSync(
            pageId: pageId,
            body: "- Old opening",
            modelContainer: container
        )
        await coordinator.scheduleSync(
            pageId: pageId,
            body: "- New opening\n- New followup",
            modelContainer: container
        )
        await coordinator.waitForSync(pageId: pageId)

        let blocks = try fetchBlocks(pageId: pageId, from: container)
        #expect(blocks.map(\.content) == ["New opening", "New followup"])
    }
}

// MARK: - Wikilink Storage Attributes

@Suite("TK2 Parity - Wikilink Click Navigation")
@MainActor
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
@MainActor
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

    @Test("Move block down carries nested children with parent")
    func moveBlockDownNested() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        let md = "- parent A\n  - child A1\n  - child A2\n- parent B\n"
        let ts = tv.textStorage!
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: md)
        ts.endEditing()
        tv.setSelectedRange(NSRange(location: 2, length: 0)) // cursor in "parent A"
        tv.moveBlockDown()
        #expect(tv.string == "- parent B\n- parent A\n  - child A1\n  - child A2\n")
    }

    @Test("Move block up carries nested children with parent")
    func moveBlockUpNested() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        let md = "- parent A\n- parent B\n  - child B1\n  - child B2\n"
        let ts = tv.textStorage!
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: md)
        ts.endEditing()
        // cursor in "parent B"
        tv.setSelectedRange(NSRange(location: 13, length: 0))
        tv.moveBlockUp()
        #expect(tv.string == "- parent B\n  - child B1\n  - child B2\n- parent A\n")
    }
}

// MARK: - Heading Insertion

@Suite("TK2 Parity - Heading Insertion")
@MainActor
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

    @Test("insertHeading removes the marker when the matching heading level is applied again")
    func insertHeadingRemovesMatchingLevel() {
        let (_, tv) = ProseTextView2.makeTextKit2()
        let md = "## Existing Heading\n"
        let ts = tv.textStorage!
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: md)
        ts.endEditing()
        tv.setSelectedRange(NSRange(location: 4, length: 0))
        tv.insertHeading(level: 2)
        #expect(tv.string == "Existing Heading\n")
        #expect(tv.selectedRange() == NSRange(location: 0, length: 0))
    }
}

// MARK: - Formatting Actions

@Suite("TK2 Parity - Formatting Actions")
@MainActor
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
        #expect(result.contains("| --- |") || result.contains("| -------- |"))
    }
}

// MARK: - Scroll Performance Guards

@Suite("TK2 Parity - Scroll Performance Guards")
@MainActor
struct TK2ScrollPerformanceTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SDBlock.self, configurations: config)
        return ModelContext(container)
    }

    @Test("Transclusion scroll refreshes are coalesced")
    @MainActor
    func transclusionScrollRefreshesCoalesce() async throws {
        let context = try makeContext()

        for i in 0..<6 {
            let block = SDBlock(pageId: "", content: "Block \(i)", depth: 0, order: i * 1000)
            block.id = "bench-block-\(i)"
            context.insert(block)
        }
        try context.save()

        let markdown = (0..<80).map { i in
            "((bench-block-\(i % 6))) transclusion row \(i)"
        }.joined(separator: "\n")

        let (scrollView, tv) = ProseTextView2.makeTextKit2()
        scrollView.frame = NSRect(x: 0, y: 0, width: 860, height: 420)
        tv.frame = NSRect(x: 0, y: 0, width: 860, height: 3600)

        let ts = tv.textStorage!
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: markdown)
        ts.endEditing()
        tv.reparseAndInvalidate()

        if let contentStorage = tv.textLayoutManager?.textContentManager as? NSTextContentStorage {
            tv.textLayoutManager?.ensureLayout(for: contentStorage.documentRange)
        }

        let manager = TransclusionOverlayManager2(textView: tv)
        manager.configure(modelContext: context)
        manager.refreshAfterTextChange()

        var refreshCount = 0
        manager.onDidRefresh = { refreshCount += 1 }

        for step in 0..<12 {
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: CGFloat(step * 24)))
            manager.refreshForScroll()
        }

        // The coalesced task uses Task.yield(), which needs MainActor run loop
        // iterations to complete. Give it enough time in the test environment.
        try await Task.sleep(for: .milliseconds(100))

        #expect(refreshCount <= 1)
    }
}

// MARK: - Suite: Page Swap Persistence

@Suite("TK2 Parity - Page Swap Persistence")
@MainActor
struct TK2PageSwapPersistenceTests {

    /// Build a minimal Coordinator2 stack wired with onPageFlush tracking.
    @MainActor
    private static func makeStack(
        pageId: String = "old-page",
        body: String = "Hello world."
    ) -> (
        coord: ProseEditorRepresentable2.Coordinator2,
        tv: ProseTextView2,
        getFlushCalls: () -> [(String, String)],
        setNewPage: (String, String) -> Void
    ) {
        var text = body
        let binding = Binding<String>(get: { text }, set: { text = $0 })
        var flushCalls: [(String, String)] = []

        var repr = ProseEditorRepresentable2(
            text: binding,
            pageId: pageId,
            pageBody: body,
            isFocused: false,
            theme: .light,
            isEditable: true,
            isFocusMode: false
        )
        repr.onPageFlush = { pid, txt in
            flushCalls.append((pid, txt))
        }

        let coord = ProseEditorRepresentable2.Coordinator2(repr)
        let (scrollView, tv) = ProseTextView2.makeTextKit2()

        tv.delegate = coord
        coord.textView = tv
        coord.scrollView = scrollView
        coord.currentPageId = pageId
        coord.lastSyncedText = body
        coord.lastPersistedText = body
        coord.lastTheme = .light

        // Load initial content
        coord.isFlushingTokens = true
        let ts = tv.textStorage!
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: body)
        ts.endEditing()
        tv.didChangeText()
        coord.isFlushingTokens = false

        // Closure to update parent to a new page (triggers swap on next handleUpdate)
        let setNewPage: (String, String) -> Void = { newPageId, newBody in
            var updated = repr
            updated = ProseEditorRepresentable2(
                text: binding,
                pageId: newPageId,
                pageBody: newBody,
                isFocused: false,
                theme: .light,
                isEditable: true,
                isFocusMode: false
            )
            updated.onPageFlush = { pid, txt in
                flushCalls.append((pid, txt))
            }
            coord.parent = updated
            coord.textBinding = binding
        }

        return (coord, tv, { flushCalls }, setNewPage)
    }

    /// Simulate a user edit by replacing storage content without the isFlushingTokens guard.
    @MainActor
    private static func simulateUserEdit(_ tv: ProseTextView2, newText: String) {
        let ts = tv.textStorage!
        ts.beginEditing()
        ts.replaceCharacters(in: NSRange(location: 0, length: ts.length), with: newText)
        ts.endEditing()
        tv.didChangeText()
    }

    @Test("Page swap after binding sync still flushes edits to disk")
    @MainActor
    func pageSwapAfterBindingSyncFlushes() {
        let (coord, tv, getFlushCalls, setNewPage) = Self.makeStack()

        // 1. User edits the note
        Self.simulateUserEdit(tv, newText: "Hello world. Extra edits")

        // 2. 300ms binding sync fires — updates lastSyncedText but NOT lastPersistedText
        coord.flushBindingSync(force: true)
        #expect(coord.lastSyncedText == "Hello world. Extra edits")
        #expect(coord.lastPersistedText == "Hello world.")

        // 3. User switches to a different page (before 3s/5s save fires)
        setNewPage("new-page", "New page body")
        coord.handlePageSwap()

        // 4. onPageFlush must have been called with the old page's edited text
        let calls = getFlushCalls()
        #expect(calls.count == 1)
        #expect(calls[0].0 == "old-page")
        #expect(calls[0].1 == "Hello world. Extra edits")

        // 5. lastPersistedText should now reflect the flushed text
        #expect(coord.lastPersistedText == "New page body")
    }

    @Test("Page swap with no edits since persist skips flush")
    @MainActor
    func pageSwapNoEditsSkipsFlush() {
        let (coord, _, getFlushCalls, setNewPage) = Self.makeStack()

        // No edits — lastPersistedText == current text
        setNewPage("new-page", "New page body")
        coord.handlePageSwap()

        // No flush call expected — text unchanged since persist
        let calls = getFlushCalls()
        #expect(calls.isEmpty)
    }

    @Test("Dismantle after binding sync still persists to disk")
    @MainActor
    func dismantleAfterBindingSyncPersists() {
        let (coord, tv, getFlushCalls, _) = Self.makeStack()

        // 1. User edits
        Self.simulateUserEdit(tv, newText: "Edited before teardown")

        // 2. Binding sync fires
        coord.flushBindingSync(force: true)
        #expect(coord.lastSyncedText == "Edited before teardown")
        #expect(coord.lastPersistedText == "Hello world.")

        // 3. View dismantles (tab close, window close, etc.)
        coord.handleDismantle()

        // 4. onPageFlush must have fired during dismantle
        let calls = getFlushCalls()
        #expect(calls.count == 1)
        #expect(calls[0].0 == "old-page")
        #expect(calls[0].1 == "Edited before teardown")
    }

    @Test("Multiple rapid edits — only unpersisted delta flushed on swap")
    @MainActor
    func multipleEditsOnlyUnpersistedDeltaFlushed() {
        let (coord, tv, getFlushCalls, setNewPage) = Self.makeStack()

        // 1. First edit + binding sync
        Self.simulateUserEdit(tv, newText: "First edit")
        coord.flushBindingSync(force: true)

        // 2. Swap pages — should flush "First edit"
        setNewPage("page-2", "Page 2 body")
        coord.handlePageSwap()
        #expect(getFlushCalls().count == 1)
        #expect(getFlushCalls()[0].1 == "First edit")

        // 3. Edit the new page
        Self.simulateUserEdit(tv, newText: "Page 2 edited")
        coord.flushBindingSync(force: true)

        // 4. Swap again — should flush "Page 2 edited"
        setNewPage("page-3", "Page 3 body")
        coord.handlePageSwap()
        #expect(getFlushCalls().count == 2)
        #expect(getFlushCalls()[1].0 == "page-2")
        #expect(getFlushCalls()[1].1 == "Page 2 edited")
    }
}

@Suite("TK2 Parity - Centering")
@MainActor
struct TK2CenteringTests {

    @Test("TK2 horizontal inset recenters wide prose while keeping compact and table notes stable")
    func horizontalInsetRecentersWideProse() {
        #expect(ProseEditorRepresentable2.horizontalInset(for: 900, markdown: "Body") == 60)
        #expect(ProseEditorRepresentable2.horizontalInset(for: 1000, markdown: "Body") == 60)
        #expect(ProseEditorRepresentable2.horizontalInset(for: 1200, markdown: "Body") == 120)
        #expect(
            ProseEditorRepresentable2.horizontalInset(
                for: 1000,
                markdown: """
                    | Name | Count |
                    | --- | --- |
                    | Pens | 12 |
                    """
            ) == 60
        )
    }
}

} // end TextKit2ParityTests
