import AppKit

// MARK: - MarkdownContentStorage
// NSTextContentStorageDelegate for TextKit 2 prose editor.
// Classifies each paragraph via Rust FFI markdown_parse_structure(),
// returns styled NSTextParagraph instances for the element tree.
// Phase 1: structural paragraph styling (heading fonts, code monospace, list indent).
// Phase 2: inline styling via Rust markdown_parse() FFI (bold, italic, code, wikilinks).

final class MarkdownContentStorage: NSObject, NSTextContentStorageDelegate {

    // Cached structure: one entry per line, indexed by line number.
    private var cachedTypes: [(paraType: UInt8, metadata: UInt16)] = []
    // UTF-16 offset of each line start, for O(log n) line index lookup.
    private var lineStarts: [Int] = [0]
    private var documentLength: Int = 0
    private var isDirty = true
    private let baseFontSize: CGFloat = 15

    /// The line index where the cursor is. Nil = no active line (all markers hidden).
    var activeLine: Int? = nil

    /// Inline style kinds from the Rust parser to apply per-paragraph.
    /// Block-level styles (headings, lists, code blocks) are handled by applyStructuralStyle.
    private static let inlineStyleKinds: Set<UInt8> = [
        4,  // Bold
        5,  // Italic
        6,  // Strikethrough
        7,  // InlineCode
        15, // Wikilink
        16, // WikilinkBrackets
        17, // MarkdownLink
        19, // InlineMath
        24, // BlockReference
        25, // BlockReferenceBrackets
    ]

    /// Number of classified lines after most recent reparse.
    var lineCount: Int { cachedTypes.count }

    /// Paragraph type for a given line index. Returns nil if out of bounds.
    func paragraphType(at lineIndex: Int) -> UInt8? {
        guard lineIndex >= 0, lineIndex < cachedTypes.count else { return nil }
        return cachedTypes[lineIndex].paraType
    }

    var theme: EpistemosTheme = .light

    // MARK: - Reparse

    /// Full document reparse. Call on load and after text changes.
    func reparse(text: String) {
        buildLineStarts(from: text)

        text.withCString { cStr in
            let maxSpans = UInt32(lineStarts.count + 16)
            let buffer = UnsafeMutablePointer<StructureSpan>.allocate(capacity: Int(maxSpans))
            defer { buffer.deallocate() }

            let count = markdown_parse_structure(cStr, buffer, maxSpans)
            cachedTypes = (0..<Int(count)).map { i in
                (paraType: buffer[i].para_type, metadata: buffer[i].metadata)
            }
        }

        isDirty = false
    }

    func markDirty() {
        isDirty = true
    }

    // MARK: - Line Index Mapping

    private func buildLineStarts(from text: String) {
        lineStarts = [0]
        let nsString = text as NSString
        documentLength = nsString.length
        for i in 0..<documentLength {
            if nsString.character(at: i) == 0x0A { // '\n'
                lineStarts.append(i + 1)
            }
        }
    }

    /// Binary search: UTF-16 offset → line index.
    func lineIndex(at utf16Offset: Int) -> Int {
        var lo = 0
        var hi = lineStarts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if lineStarts[mid] <= utf16Offset {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        return lo
    }

    /// UTF-16 range for a line (excluding trailing newline). Returns nil if out of bounds.
    func lineRange(at lineIndex: Int) -> NSRange? {
        guard lineIndex >= 0, lineIndex < lineStarts.count else { return nil }
        let start = lineStarts[lineIndex]
        let end = (lineIndex + 1 < lineStarts.count)
            ? lineStarts[lineIndex + 1] - 1
            : documentLength
        return NSRange(location: start, length: max(end - start, 0))
    }

    // MARK: - NSTextContentStorageDelegate

    func textContentStorage(
        _ textContentStorage: NSTextContentStorage,
        textParagraphWith range: NSRange
    ) -> NSTextParagraph? {
        guard let attrStr = textContentStorage.attributedString else { return nil }

        // Lazy reparse if dirty
        if isDirty {
            reparse(text: attrStr.string)
        }

        let line = lineIndex(at: range.location)
        guard line < cachedTypes.count else { return nil }

        let entry = cachedTypes[line]
        let paraText = (attrStr.string as NSString).substring(with: range)

        let styled = NSMutableAttributedString(string: paraText)
        let fullRange = NSRange(location: 0, length: styled.length)
        guard fullRange.length > 0 else { return nil }

        applyStructuralStyle(to: styled, range: fullRange, paraType: entry.paraType, metadata: entry.metadata)

        // Phase 2+3: inline styles with active line awareness (skip block-level-only types)
        let isActive = (activeLine == line)
        if entry.paraType != 6 && entry.paraType != 8 && entry.paraType != 9 {
            applyInlineStyles(to: styled, fullRange: fullRange, isActive: isActive)
        }

        return NSTextParagraph(attributedString: styled)
    }

    // MARK: - Structural Styling

    private func applyStructuralStyle(
        to attrStr: NSMutableAttributedString,
        range: NSRange,
        paraType: UInt8,
        metadata: UInt16
    ) {
        let foreground = NSColor(theme.foreground)
        let bodyFont = NSFont(name: "New York", size: 15) ?? .systemFont(ofSize: 15)

        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = 4
        bodyParagraph.paragraphSpacing = 6

        switch paraType {
        case 1: // Heading
            let level = metadata & 0xFF
            let (fontSize, weight): (CGFloat, NSFont.Weight) = switch level {
            case 1: (28, .bold)
            case 2: (22, .semibold)
            case 3: (18, .medium)
            case 4: (16, .medium)
            case 5: (15, .medium)
            default: (15, .medium)
            }
            let headingParagraph = NSMutableParagraphStyle()
            headingParagraph.lineSpacing = 2
            headingParagraph.paragraphSpacingBefore = level == 1 ? 24 : 16
            headingParagraph.paragraphSpacing = 8
            attrStr.addAttributes([
                .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
                .foregroundColor: foreground,
                .paragraphStyle: headingParagraph,
            ], range: range)

        case 6: // CodeBlock
            let codeFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let codeParagraph = NSMutableParagraphStyle()
            codeParagraph.lineSpacing = 2
            codeParagraph.headIndent = 12
            codeParagraph.firstLineHeadIndent = 12
            attrStr.addAttributes([
                .font: codeFont,
                .foregroundColor: foreground,
                .paragraphStyle: codeParagraph,
            ], range: range)

        case 5: // BlockQuote
            let quoteParagraph = NSMutableParagraphStyle()
            quoteParagraph.lineSpacing = 4
            quoteParagraph.headIndent = 20
            quoteParagraph.firstLineHeadIndent = 20
            quoteParagraph.paragraphSpacing = 4
            attrStr.addAttributes([
                .font: bodyFont,
                .foregroundColor: foreground.withAlphaComponent(0.8),
                .paragraphStyle: quoteParagraph,
            ], range: range)

        case 2, 3, 4: // OrderedList, UnorderedList, TaskList
            let depth = (metadata >> 8) & 0xFF
            let indent = CGFloat(depth + 1) * 20
            let listParagraph = NSMutableParagraphStyle()
            listParagraph.lineSpacing = 4
            listParagraph.headIndent = indent
            listParagraph.firstLineHeadIndent = max(indent - 16, 0)
            listParagraph.paragraphSpacing = 2
            attrStr.addAttributes([
                .font: bodyFont,
                .foregroundColor: foreground,
                .paragraphStyle: listParagraph,
            ], range: range)

        case 7: // Table
            let tableFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            attrStr.addAttributes([
                .font: tableFont,
                .foregroundColor: foreground,
                .paragraphStyle: bodyParagraph,
            ], range: range)

        case 8: // HorizontalRule
            attrStr.addAttributes([
                .font: bodyFont,
                .foregroundColor: NSColor.tertiaryLabelColor,
                .paragraphStyle: bodyParagraph,
            ], range: range)

        case 9: // HtmlComment
            let commentFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            attrStr.addAttributes([
                .font: commentFont,
                .foregroundColor: foreground.withAlphaComponent(0.3),
                .paragraphStyle: bodyParagraph,
            ], range: range)

        default: // Body
            attrStr.addAttributes([
                .font: bodyFont,
                .foregroundColor: foreground,
                .paragraphStyle: bodyParagraph,
            ], range: range)
        }
    }

    // MARK: - Inline Styling (Phase 2)

    /// Parse paragraph text through Rust markdown_parse FFI, apply inline styles.
    /// Called per-paragraph after structural styling. Testable in isolation.
    /// - Parameter isActive: true = active line (ghost markers), false = inactive (hidden markers).
    func applyInlineStyles(to attrStr: NSMutableAttributedString, fullRange: NSRange, isActive: Bool = true) {
        let text = attrStr.string
        guard !text.isEmpty, let cStr = text.cString(using: .utf8) else { return }

        var spansPtr: UnsafeMutablePointer<StyleSpan>?
        var count: UInt32 = 0
        let result = markdown_parse(cStr, UInt32(cStr.count - 1), &spansPtr, &count)
        guard result == 0, let spans = spansPtr, count > 0 else { return }
        defer { markdown_free_spans(spans, count) }

        let utf8ToUtf16 = Self.buildUtf8ToUtf16Map(text)
        let isDark = theme.isDark
        let accent = Self.accentColor(isDark: isDark)
        let muted = Self.mutedColor(isDark: isDark)
        let ghostMarker: [NSAttributedString.Key: Any]
        if isActive {
            ghostMarker = [
                .foregroundColor: isDark
                    ? NSColor.white.withAlphaComponent(0.15)
                    : NSColor.black.withAlphaComponent(0.12)
            ]
        } else {
            ghostMarker = [
                .foregroundColor: NSColor.clear,
                .font: NSFont.systemFont(ofSize: 0.01)
            ]
        }

        // Sort largest-first: inner (smaller) spans override outer attribute ranges.
        let sorted = (0..<Int(count)).sorted {
            let a = spans[$0], b = spans[$1]
            return (a.end &- a.start) > (b.end &- b.start)
        }

        for idx in sorted {
            let span = spans[idx]
            guard Self.inlineStyleKinds.contains(span.style) else { continue }
            let startByte = Int(span.start)
            let endByte = Int(span.end)
            guard startByte < utf8ToUtf16.count, endByte < utf8ToUtf16.count else { continue }

            let utf16Start = utf8ToUtf16[startByte]
            let utf16End = utf8ToUtf16[endByte]
            let spanRange = NSRange(
                location: fullRange.location + utf16Start,
                length: utf16End - utf16Start
            )
            guard spanRange.length > 0,
                  spanRange.location + spanRange.length <= attrStr.length else { continue }

            applySpanStyle(
                to: attrStr, span.style, group: span.group, range: spanRange,
                ghost: ghostMarker, accent: accent, muted: muted
            )
        }
    }

    /// Apply visual attributes for a single Rust-parsed inline style span.
    /// Derives font size from the paragraph's existing structural font to preserve
    /// heading/quote/list typography when inline markdown is present.
    private func applySpanStyle(
        to attrStr: NSMutableAttributedString,
        _ style: UInt8, group: UInt8, range: NSRange,
        ghost: [NSAttributedString.Key: Any],
        accent: NSColor, muted: NSColor
    ) {
        // Read the structural font and foreground already applied to this range.
        // Inline styles derive from them so headings keep their size and color.
        let existingFont = attrStr.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            ?? NSFont.systemFont(ofSize: baseFontSize)
        let existingForeground = attrStr.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
            ?? NSColor(theme.foreground)
        let size = existingFont.pointSize

        switch style {
        case 4: // Bold — ghost markers, bold content (preserves structural size + foreground)
            attrStr.addAttributes(ghost, range: range)
            if range.length > 4 {
                let content = NSRange(location: range.location + 2, length: range.length - 4)
                attrStr.addAttributes([
                    .font: NSFont.systemFont(ofSize: size, weight: .bold),
                    .foregroundColor: existingForeground
                ], range: content)
            }

        case 5: // Italic — ghost markers, italic content (preserves structural size + foreground)
            attrStr.addAttributes(ghost, range: range)
            if range.length > 2 {
                let content = NSRange(location: range.location + 1, length: range.length - 2)
                attrStr.addAttributes([
                    .font: NSFontManager.shared.convert(existingFont, toHaveTrait: .italicFontMask),
                    .foregroundColor: existingForeground
                ], range: content)
            }

        case 6: // Strikethrough — ghost markers, strikethrough + muted content
            attrStr.addAttributes(ghost, range: range)
            if range.length > 4 {
                let content = NSRange(location: range.location + 2, length: range.length - 4)
                attrStr.addAttributes([
                    .font: existingFont,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: muted
                ], range: content)
            }

        case 7: // InlineCode — ghost backticks, monospace + accent pill (size - 1, floor 11)
            attrStr.addAttributes(ghost, range: range)
            if range.length > 2 {
                let content = NSRange(location: range.location + 1, length: range.length - 2)
                attrStr.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: max(size - 1, 11), weight: .medium),
                    .foregroundColor: accent.withAlphaComponent(0.90),
                    .backgroundColor: accent.withAlphaComponent(0.10)
                ], range: content)
            }

        case 15: // Wikilink content — accent pill with native link
            let linkTitle = (attrStr.string as NSString).substring(with: range)
            attrStr.addAttributes([
                .foregroundColor: accent,
                .backgroundColor: accent.withAlphaComponent(theme.isDark ? 0.10 : 0.08),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: accent.withAlphaComponent(0.35),
                .link: "wikilink://\(linkTitle)" as NSString,
                .cursor: NSCursor.pointingHand
            ], range: range)

        case 16: // WikilinkBrackets [[ or ]] — ghosted
            attrStr.addAttributes(ghost, range: range)

        case 17: // MarkdownLink [text](url) — ghost all, accent pill the text part
            attrStr.addAttributes(ghost, range: range)
            if range.length > 4 {
                let linkStr = (attrStr.string as NSString).substring(with: range)
                if let closeBracket = linkStr.firstIndex(of: "]") {
                    let textLen = linkStr.distance(
                        from: linkStr.index(after: linkStr.startIndex),
                        to: closeBracket
                    )
                    if textLen > 0 {
                        let textRange = NSRange(location: range.location + 1, length: textLen)
                        attrStr.addAttributes([
                            .font: existingFont,
                            .foregroundColor: accent,
                            .backgroundColor: accent.withAlphaComponent(theme.isDark ? 0.08 : 0.06),
                            .underlineStyle: NSUnderlineStyle.single.rawValue,
                            .underlineColor: accent.withAlphaComponent(0.30)
                        ], range: textRange)
                    }
                }
            }

        case 19: // InlineMath $expr$ — muted dollars, accent italic content with pill
            attrStr.addAttributes([.foregroundColor: muted], range: range)
            if range.length > 2 {
                let content = NSRange(location: range.location + 1, length: range.length - 2)
                let mathSize = max(size - 1, 11)
                attrStr.addAttributes([
                    .font: NSFont(name: "NewYork-RegularItalic", size: mathSize)
                        ?? NSFontManager.shared.convert(existingFont, toHaveTrait: .italicFontMask),
                    .foregroundColor: accent,
                    .backgroundColor: accent.withAlphaComponent(theme.isDark ? 0.06 : 0.04)
                ], range: content)
            }

        case 24: // BlockReference content — accent + tinted background + native link
            let blockId = (attrStr.string as NSString).substring(with: range)
            attrStr.addAttributes([
                .foregroundColor: accent,
                .backgroundColor: accent.withAlphaComponent(theme.isDark ? 0.10 : 0.08),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: accent.withAlphaComponent(0.35),
                .link: "blockref://\(blockId)" as NSString,
                .cursor: NSCursor.pointingHand
            ], range: range)

        case 25: // BlockReferenceBrackets (( or )) — ghosted
            attrStr.addAttributes(ghost, range: range)

        default:
            break
        }
    }

    // MARK: - UTF-8 → UTF-16 Offset Map

    /// Build a lookup table from UTF-8 byte offsets to UTF-16 code unit offsets.
    /// Index = byte position in UTF-8, value = corresponding UTF-16 offset.
    /// Size is utf8Count + 1 (sentinel for end-of-string positions).
    static func buildUtf8ToUtf16Map(_ str: String) -> [Int] {
        let utf8Count = str.utf8.count
        var map = [Int](repeating: 0, count: utf8Count + 1)
        var utf8Pos = 0
        var utf16Pos = 0

        for scalar in str.unicodeScalars {
            let value = scalar.value
            let u8Len: Int
            if value <= 0x7F { u8Len = 1 }
            else if value <= 0x7FF { u8Len = 2 }
            else if value <= 0xFFFF { u8Len = 3 }
            else { u8Len = 4 }

            for j in 0..<u8Len {
                if utf8Pos + j < map.count {
                    map[utf8Pos + j] = utf16Pos
                }
            }

            utf8Pos += u8Len
            utf16Pos += (value > 0xFFFF) ? 2 : 1
        }

        if utf8Pos < map.count {
            map[utf8Pos] = utf16Pos
        }
        return map
    }

    // MARK: - Theme Colors

    static func accentColor(isDark: Bool) -> NSColor {
        isDark
            ? NSColor(red: 0.40, green: 0.65, blue: 1.0, alpha: 1)
            : NSColor(red: 0.15, green: 0.45, blue: 0.85, alpha: 1)
    }

    static func mutedColor(isDark: Bool) -> NSColor {
        isDark
            ? .white.withAlphaComponent(0.35)
            : NSColor(white: 0.5, alpha: 1)
    }
}
