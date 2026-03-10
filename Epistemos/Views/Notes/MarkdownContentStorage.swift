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

    /// Visible line range, updated by ProseTextView2 on scroll/layout.
    /// Code blocks outside this range + buffer skip tokenization.
    var visibleLineRange: Range<Int> = 0..<Int.max
    private let viewportBuffer = 50

    /// Cache for tokenized code block results.
    /// Key: hash of (line_text, theme, language_id). Value: token spans in UTF-16.
    private var tokenCache: [UInt64: [CodeTokenBridge]] = [:]
    private let maxCacheEntries = 256

    /// The line index where the cursor is. Nil = no active line (all markers hidden).
    var activeLine: Int? = nil

    /// Lines currently hidden by heading folds. Recomputed on fold toggle.
    private(set) var hiddenLines: Set<Int> = []

    /// Inline style kinds from the Rust parser to apply per-paragraph.
    /// Block-level styles (headings, lists, code blocks) are handled by applyStructuralStyle.
    private static let inlineStyleKinds: Set<UInt8> = [
        4,  // Bold
        5,  // Italic
        6,  // Strikethrough
        7,  // InlineCode
        13, // Checkbox
        14, // CheckboxChecked
        15, // Wikilink
        16, // WikilinkBrackets
        17, // MarkdownLink
        19, // InlineMath
        24, // BlockReference
        25, // BlockReferenceBrackets
        26, // DisplayMath
    ]

    /// Number of classified lines after most recent reparse.
    var lineCount: Int { cachedTypes.count }

    /// Paragraph type for a given line index. Returns nil if out of bounds.
    func paragraphType(at lineIndex: Int) -> UInt8? {
        guard lineIndex >= 0, lineIndex < cachedTypes.count else { return nil }
        return cachedTypes[lineIndex].paraType
    }

    /// Paragraph metadata for a given line index. Returns nil if out of bounds.
    func paragraphMetadata(at lineIndex: Int) -> UInt16? {
        guard lineIndex >= 0, lineIndex < cachedTypes.count else { return nil }
        return cachedTypes[lineIndex].metadata
    }

    /// Test-only entry point for structural styling.
    func applyStructuralStyleForTest(
        to attrStr: NSMutableAttributedString, range: NSRange,
        paraType: UInt8, metadata: UInt16
    ) {
        applyStructuralStyle(to: attrStr, range: range, paraType: paraType, metadata: metadata)
    }

    var theme: EpistemosTheme = .light {
        didSet {
            if oldValue != theme {
                tokenCache.removeAll(keepingCapacity: true)
            }
        }
    }

    #if DEBUG
    var cachedTypesForTesting: [(paraType: UInt8, metadata: UInt16)] { cachedTypes }
    #endif

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

        tokenCache.removeAll(keepingCapacity: true)
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
        if entry.paraType == 6 {
            let languageId = UInt8(entry.metadata & 0xFF)
            if languageId > 0 {
                applyCodeTokenStyles(
                    to: styled, range: fullRange, languageId: languageId, line: line,
                    documentString: attrStr.string as NSString
                )
            }
        } else if entry.paraType != 8 && entry.paraType != 9 {
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

        case 5: // BlockQuote (plain or callout)
            let calloutTypeId = UInt8((metadata >> 8) & 0xFF)
            let quoteParagraph = NSMutableParagraphStyle()
            quoteParagraph.lineSpacing = 4
            quoteParagraph.headIndent = 20
            quoteParagraph.firstLineHeadIndent = 20
            quoteParagraph.paragraphSpacing = 4

            if let callout = theme.calloutColors(typeId: calloutTypeId) {
                attrStr.addAttributes([
                    .font: bodyFont,
                    .foregroundColor: theme.isDark ? callout.accent.withAlphaComponent(0.9) : callout.accent,
                    .paragraphStyle: quoteParagraph,
                ], range: range)
            } else {
                attrStr.addAttributes([
                    .font: bodyFont,
                    .foregroundColor: foreground.withAlphaComponent(0.8),
                    .paragraphStyle: quoteParagraph,
                ], range: range)
            }

        case 2, 3: // OrderedList, UnorderedList
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

        case 4: // TaskList
            let depth = (metadata >> 8) & 0xFF
            let checked = (metadata & 0xFF) != 0
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

            if checked {
                let text = attrStr.string
                if let closeBracket = text.range(of: "] ") {
                    let contentStart = text.distance(from: text.startIndex, to: closeBracket.upperBound)
                    if range.length > contentStart {
                        let contentRange = NSRange(
                            location: range.location + contentStart,
                            length: range.length - contentStart
                        )
                        let muted = Self.mutedColor(isDark: theme.isDark)
                        attrStr.addAttributes([
                            .foregroundColor: muted,
                            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        ], range: contentRange)
                    }
                }
            }

        case 7: // Table
            let tableFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            let tableParagraph = NSMutableParagraphStyle()
            tableParagraph.lineSpacing = 5
            tableParagraph.paragraphSpacing = 3
            attrStr.addAttributes([
                .font: tableFont,
                .foregroundColor: foreground,
                .paragraphStyle: tableParagraph,
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

        case 13: // Checkbox [ ] — accent marker, monospace
            attrStr.addAttributes([
                .foregroundColor: accent.withAlphaComponent(0.7),
                .font: NSFont.monospacedSystemFont(ofSize: max(size - 1, 11), weight: .regular)
            ], range: range)

        case 14: // CheckboxChecked [x] — muted marker, monospace
            attrStr.addAttributes([
                .foregroundColor: muted,
                .font: NSFont.monospacedSystemFont(ofSize: max(size - 1, 11), weight: .regular)
            ], range: range)

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

        case 26: // DisplayMath $$...$$ — muted delimiters, accent italic content, centered
            attrStr.addAttributes([.foregroundColor: muted], range: range)
            if range.length > 4 {
                let content = NSRange(location: range.location + 2, length: range.length - 4)
                let mathSize = max(size + 1, 13)
                let centered = NSMutableParagraphStyle()
                centered.alignment = .center
                centered.lineSpacing = 6
                centered.paragraphSpacingBefore = 8
                centered.paragraphSpacing = 8
                attrStr.addAttributes([
                    .font: NSFont(name: "NewYork-RegularItalic", size: mathSize)
                        ?? NSFontManager.shared.convert(existingFont, toHaveTrait: .italicFontMask),
                    .foregroundColor: accent.withAlphaComponent(0.85),
                    .backgroundColor: accent.withAlphaComponent(theme.isDark ? 0.06 : 0.04),
                    .paragraphStyle: centered,
                ], range: content)
            }

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

    // MARK: - Code Token Styling (Phase 6)

    private static let languageTags: [UInt8: String] = [
        1: "swift", 2: "rust", 3: "python", 4: "javascript",
        5: "typescript", 6: "json", 7: "html", 8: "css",
        9: "bash", 10: "go", 11: "c", 12: "cpp",
    ]

    /// Compute code tokens for a specific line within its fenced code block.
    /// Uses block-level cache (tokenCache). Returns empty for fence lines
    /// or lines outside a valid body range.
    /// Called by both the content storage delegate (to apply colors) and
    /// the layout manager delegate (to configure MarkdownLayoutFragment).
    func codeTokensForLine(
        _ line: Int,
        languageId: UInt8,
        documentString: NSString
    ) -> [CodeTokenBridge] {
        guard line < cachedTypes.count else { return [] }

        // Check if this line is a fence (markdown syntax, not code)
        guard let lr = lineRange(at: line) else { return [] }
        let lineText = documentString.substring(with: lr)
            .trimmingCharacters(in: .whitespaces)
        if lineText.hasPrefix("```") || lineText.hasPrefix("~~~") { return [] }

        // Find contiguous code block boundaries by walking cachedTypes
        var blockStart = line
        while blockStart > 0 && cachedTypes[blockStart - 1].paraType == 6 {
            blockStart -= 1
        }
        var blockEnd = line
        while blockEnd + 1 < cachedTypes.count && cachedTypes[blockEnd + 1].paraType == 6 {
            blockEnd += 1
        }

        // Identify body range (skip fence lines at block edges)
        var bodyStart = blockStart
        if let firstRange = lineRange(at: blockStart) {
            let firstText = documentString.substring(with: firstRange)
                .trimmingCharacters(in: .whitespaces)
            if firstText.hasPrefix("```") || firstText.hasPrefix("~~~") {
                bodyStart = blockStart + 1
            }
        }
        var bodyEnd = blockEnd
        if blockEnd > bodyStart, let lastRange = lineRange(at: blockEnd) {
            let lastText = documentString.substring(with: lastRange)
                .trimmingCharacters(in: .whitespaces)
            if lastText.hasPrefix("```") || lastText.hasPrefix("~~~") {
                bodyEnd = blockEnd - 1
            }
        }

        guard line >= bodyStart, line <= bodyEnd else { return [] }
        guard bodyStart < lineStarts.count, bodyEnd < lineStarts.count else { return [] }

        // Extract combined body text from the document in one shot.
        // lineStarts are UTF-16 offsets; lineRange excludes trailing newlines.
        // The document text between lineStarts[bodyStart] and end of lineRange(bodyEnd)
        // naturally includes \n between lines but not after the last line.
        let bodyStartOffset = lineStarts[bodyStart]
        guard let lastBodyRange = lineRange(at: bodyEnd) else { return [] }
        let bodyEndOffset = lastBodyRange.location + lastBodyRange.length
        guard bodyEndOffset > bodyStartOffset else { return [] }
        let bodyText = documentString.substring(
            with: NSRange(location: bodyStartOffset, length: bodyEndOffset - bodyStartOffset)
        )

        // Block-level cache: same block body + language + theme → same tokens
        let cacheKey = tokenCacheKey(text: bodyText, languageId: languageId)
        let allTokens: [CodeTokenBridge]
        if let cached = tokenCache[cacheKey] {
            allTokens = cached
        } else {
            allTokens = tokenizeViaFFI(text: bodyText, languageId: languageId)
            if tokenCache.count >= maxCacheEntries {
                tokenCache.removeAll(keepingCapacity: true)
            }
            tokenCache[cacheKey] = allTokens
        }
        guard !allTokens.isEmpty else { return [] }

        // Compute this line's UTF-16 range within the combined body text.
        // lineStarts[line] - bodyStartOffset gives the offset of this line within the body.
        let lineStartInBody = lineStarts[line] - bodyStartOffset
        let lineEndInBody = lineStartInBody + (lineRange(at: line)?.length ?? 0)

        // Filter to tokens overlapping this line, adjust offsets to paragraph-relative
        var lineTokens: [CodeTokenBridge] = []
        for token in allTokens {
            guard token.end > lineStartInBody && token.start < lineEndInBody else { continue }
            let localStart = max(token.start, lineStartInBody) - lineStartInBody
            let localEnd = min(token.end, lineEndInBody) - lineStartInBody
            guard localEnd > localStart else { continue }
            lineTokens.append(CodeTokenBridge(
                start: localStart, end: localEnd, tokenType: token.tokenType
            ))
        }

        return lineTokens
    }

    /// Apply code token colors for a code block line (viewport-gated).
    private func applyCodeTokenStyles(
        to attrStr: NSMutableAttributedString,
        range: NSRange,
        languageId: UInt8,
        line: Int,
        documentString: NSString
    ) {
        let bufferedRange = max(0, visibleLineRange.lowerBound - viewportBuffer)
            ..< (visibleLineRange.upperBound + viewportBuffer)
        guard bufferedRange.contains(line) else { return }
        guard !attrStr.string.isEmpty else { return }

        let lineTokens = codeTokensForLine(line, languageId: languageId, documentString: documentString)
        applyTokenColors(lineTokens, to: attrStr, range: range)
    }

    private func tokenCacheKey(text: String, languageId: UInt8) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(text)
        hasher.combine(theme.rawValue)
        hasher.combine(languageId)
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }

    private func tokenizeViaFFI(text: String, languageId: UInt8) -> [CodeTokenBridge] {
        guard let langTag = Self.languageTags[languageId] else { return [] }

        let maxTokens: UInt32 = 4096
        let buffer = UnsafeMutablePointer<CodeToken>.allocate(capacity: Int(maxTokens))
        defer { buffer.deallocate() }

        let utf8Data = Array(text.utf8)
        let count: UInt32 = utf8Data.withUnsafeBufferPointer { utf8Buf in
            langTag.withCString { langPtr in
                markdown_parse_code_tokens(
                    UnsafeRawPointer(utf8Buf.baseAddress!).assumingMemoryBound(to: CChar.self),
                    UInt32(utf8Buf.count),
                    langPtr,
                    buffer,
                    maxTokens
                )
            }
        }

        guard count > 0 else { return [] }

        let utf8ToUtf16 = Self.buildUtf8ToUtf16Map(text)
        var tokens: [CodeTokenBridge] = []
        tokens.reserveCapacity(Int(count))

        for i in 0..<Int(count) {
            let raw = buffer[i]
            let startByte = Int(raw.start)
            let endByte = Int(raw.end)
            guard startByte < utf8ToUtf16.count, endByte <= utf8ToUtf16.count else { continue }
            let utf16Start = utf8ToUtf16[startByte]
            let utf16End = endByte < utf8ToUtf16.count ? utf8ToUtf16[endByte] : utf8ToUtf16.last ?? 0
            guard utf16End > utf16Start else { continue }
            tokens.append(CodeTokenBridge(start: utf16Start, end: utf16End, tokenType: raw.token_type))
        }

        return tokens
    }

    private func applyTokenColors(
        _ tokens: [CodeTokenBridge],
        to attrStr: NSMutableAttributedString,
        range: NSRange
    ) {
        for token in tokens {
            let tokenRange = NSRange(
                location: range.location + token.start,
                length: token.end - token.start
            )
            guard NSMaxRange(tokenRange) <= NSMaxRange(range) else { continue }

            let color = theme.nsColorForTokenType(token.tokenType)
            attrStr.addAttribute(.foregroundColor, value: color, range: tokenRange)

            if token.tokenType == 3 {
                if let currentFont = attrStr.attribute(.font, at: tokenRange.location, effectiveRange: nil) as? NSFont {
                    let italic = NSFontManager.shared.convert(currentFont, toHaveTrait: .italicFontMask)
                    attrStr.addAttribute(.font, value: italic, range: tokenRange)
                }
            }
        }
    }

    // MARK: - Non-Destructive Folding

    /// Recompute hidden lines from Rust fold state.
    /// Call after any fold toggle.
    func recomputeHiddenLines(documentText: String) {
        hiddenLines.removeAll()

        documentText.withCString { cStr in
            for i in 0..<cachedTypes.count {
                guard cachedTypes[i].paraType == 1, // Heading
                      markdown_is_folded(UInt32(i)) else { continue }

                var start: UInt32 = 0
                var end: UInt32 = 0
                if markdown_fold_range(cStr, UInt32(i), &start, &end) {
                    for line in Int(start)..<Int(end) {
                        hiddenLines.insert(line)
                    }
                }
            }
        }
    }

    func isLineInFoldedRange(_ line: Int) -> Bool {
        hiddenLines.contains(line)
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

// MARK: - NSTextContentManagerDelegate (shouldEnumerate for folding)

extension MarkdownContentStorage: NSTextContentManagerDelegate {
    func textContentManager(
        _ textContentManager: NSTextContentManager,
        shouldEnumerate textElement: NSTextElement,
        options: NSTextContentManager.EnumerationOptions
    ) -> Bool {
        guard !hiddenLines.isEmpty else { return true }
        guard let contentStorage = textContentManager as? NSTextContentStorage,
              let range = textElement.elementRange else { return true }

        let offset = contentStorage.offset(
            from: contentStorage.documentRange.location,
            to: range.location
        )
        let line = lineIndex(at: offset)
        return !hiddenLines.contains(line)
    }
}
