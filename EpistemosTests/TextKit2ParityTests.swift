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
        #expect(!(tk1Font.map { AppDisplayTypography.isDisplayFont($0) } ?? true))
        #expect(!(tk2Font.map { AppDisplayTypography.isDisplayFont($0) } ?? true))
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
        #expect(!(tk1Font.map { AppDisplayTypography.isDisplayFont($0) } ?? true))
        #expect(!(tk2Font.map { AppDisplayTypography.isDisplayFont($0) } ?? true))
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
            if !(font.map { AppDisplayTypography.isDisplayFont($0) } ?? true) {
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

    @Test("H1 heading in light notes uses Coral Pixels display font in both stacks")
    func h1UsesDisplayFont() {
        let md = "# Big Heading"
        let tk1 = ParityHelpers.tk1Styled(md, theme: .platinumViolet)
        let tk2 = ParityHelpers.tk2Styled(md, theme: .platinumViolet)

        let tk1Font = tk1.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        #expect(tk1Font.map { AppDisplayTypography.isPrimaryDisplayFont($0) } ?? false)
        #expect(tk2Font.map { AppDisplayTypography.isPrimaryDisplayFont($0) } ?? false)

        let expectedColor = NSColor(EpistemosTheme.platinumViolet.fontAccent)
        let tk1Color = tk1.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor
        let tk2Color = tk2.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor
        #expect(ParityHelpers.colorsMatch(tk1Color, expectedColor))
        #expect(ParityHelpers.colorsMatch(tk2Color, expectedColor))
    }

    @Test("H1 heading in dark notes uses the primary display font in both stacks")
    func h1UsesDarkDisplayFont() {
        let md = "# Big Heading"
        let tk1 = ParityHelpers.tk1Styled(md, theme: .platinumVioletDark)
        let tk2 = ParityHelpers.tk2Styled(md, theme: .platinumVioletDark)

        let tk1Font = tk1.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        let tk2Font = tk2.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        #expect(tk1Font.map { AppDisplayTypography.isPrimaryDisplayFont($0) } ?? false)
        #expect(tk2Font.map { AppDisplayTypography.isPrimaryDisplayFont($0) } ?? false)
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
        #expect(shortTK1Size - longTK1Size >= 4)
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
        let tk1 = ParityHelpers.tk1Styled(markdown, theme: .platinumViolet)
        let tk2 = try! #require(ParityHelpers.tk2DisplayParagraphs(markdown, theme: .platinumViolet).first)

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
        let tk1List = ParityHelpers.tk1Styled(listMarkdown, theme: .platinumViolet)
        let tk2List = try! #require(ParityHelpers.tk2DisplayParagraphs(listMarkdown, theme: .platinumViolet).first)
        let tk1ListColor = tk1List.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        let tk2ListColor = tk2List.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(ParityHelpers.colorsMatch(tk1ListColor, tk2ListColor))

        let quoteMarkdown = "> quoted text"
        let tk1Quote = ParityHelpers.tk1Styled(quoteMarkdown, theme: .platinumViolet)
        let tk2Quote = try! #require(ParityHelpers.tk2DisplayParagraphs(quoteMarkdown, theme: .platinumViolet).first)
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

@Suite("TK2 Parity - Centering")
@MainActor
struct TK2CenteringTests {

    @Test("TK2 horizontal inset is centered, mode-driven, and content-independent")
    func horizontalInsetRecentersWideProse() {
        #expect(ProseEditorRepresentable2.horizontalInset(for: 900, mode: .normal) == 90)
        #expect(ProseEditorRepresentable2.horizontalInset(for: 1000, mode: .normal) == 140)
        #expect(ProseEditorRepresentable2.horizontalInset(for: 1200, mode: .normal) == 240)
        #expect(ProseEditorRepresentable2.horizontalInset(for: 1000, mode: .wide) == 60)
    }
}

} // end TextKit2ParityTests
