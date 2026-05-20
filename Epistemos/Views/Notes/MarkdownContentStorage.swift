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
    private let baseFontSize: CGFloat = MarkdownEditorStyle.noteBaseFontSize

    private static let numberedListRegex = FoundationSafety.regularExpression(#"^\d+\.\s"#)

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
        13,  // Checkbox
        14,  // CheckboxChecked
        15,  // Wikilink
        16,  // WikilinkBrackets
        17,  // MarkdownLink
        19,  // InlineMath
        24,  // BlockReference
        25,  // BlockReferenceBrackets
        26,  // DisplayMath
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
        paraType: UInt8, metadata: UInt16,
        isLeadingDocumentHeading: Bool = false
    ) {
        applyStructuralStyle(
            to: attrStr,
            range: range,
            paraType: paraType,
            metadata: metadata,
            isLeadingDocumentHeading: isLeadingDocumentHeading
        )
    }

    var theme: EpistemosTheme = .nativeDefault {
        didSet {
            if oldValue != theme {
                tokenCache.removeAll(keepingCapacity: true)
            }
        }
    }
    var usesRenderedTableOverlays = false

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
            if nsString.character(at: i) == 0x0A {  // '\n'
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
        let end =
            (lineIndex + 1 < lineStarts.count)
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
        let displayText = displayText(
            for: paraText, paraType: entry.paraType, metadata: entry.metadata)
        let isLeadingDocumentHeading =
            entry.paraType == 1
            && (entry.metadata & 0xFF) == 1
            && leadingDocumentContentIsEmpty(before: range.location, in: attrStr.string as NSString)
        let tableLineRole =
            entry.paraType == 7
            ? MarkdownEditorStyle.tableLineRole(at: range, in: attrStr.string as NSString)
            : nil

        let styled = NSMutableAttributedString(string: displayText)
        let fullRange = NSRange(location: 0, length: styled.length)
        guard fullRange.length > 0 else { return nil }

        applyStructuralStyle(
            to: styled,
            range: fullRange,
            paraType: entry.paraType,
            metadata: entry.metadata,
            isLeadingDocumentHeading: isLeadingDocumentHeading,
            tableLineRole: tableLineRole
        )

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
            applyInlineStyles(
                to: styled, fullRange: fullRange, sourceText: paraText, isActive: isActive)
        }

        if usesRenderedTableOverlays, entry.paraType == 7 {
            hideRenderedTableSourceText(in: styled, range: fullRange)
        }

        return NSTextParagraph(attributedString: styled)
    }

    // MARK: - Structural Styling

    private func applyStructuralStyle(
        to attrStr: NSMutableAttributedString,
        range: NSRange,
        paraType: UInt8,
        metadata: UInt16,
        isLeadingDocumentHeading: Bool = false,
        tableLineRole: MarkdownEditorStyle.TableLineRole? = nil
    ) {
        let line = attrStr.string
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let resolved = theme.resolved
        let foreground = resolved.foreground.nsColor
        let bodyFont = NSFont.systemFont(ofSize: baseFontSize)
        let accent = resolved.headingAccent.nsColor
        let headingAccent = resolved.markdownHeadingAccent.nsColor
        let muted = Self.mutedColor(isDark: theme.isDark)
        let bodyParagraph = MarkdownEditorStyle.bodyParagraphStyle()

        switch paraType {
        case 1:  // Heading
            let level = Int(metadata & 0xFF)
            let weight = MarkdownHeadingDisplay.noteHeadingWeight(for: level)
            let rawFontSize = MarkdownHeadingDisplay.noteHeadingFontSize(
                for: level,
                text: line,
                baseFontSize: baseFontSize
            )
            // 2026-05-19: shrink H1-H3 by theme.headingSizeMultiplier so
            // Classic (RetroGaming) and Platinum (MatrixTypeDisplay) land
            // near visual parity with Ember (ChonkyPixels). Ember stays at
            // multiplier 1.0. Levels 4+ are not display-font headings; leave
            // them at their canonical sizes.
            let fontSize: CGFloat = (1...3).contains(level)
                ? rawFontSize * theme.headingSizeMultiplier
                : rawFontSize
            let headingParagraph = MarkdownEditorStyle.headingParagraphStyle(
                level: level,
                isLeadingDocumentHeading: isLeadingDocumentHeading
            )
            let usesDisplayFont = (1...3).contains(level)
            let headingFont =
                if usesDisplayFont {
                    // 2026-05-13 follow-up: route live-editor H1-H3
                    // through `theme.headingFontName` (Ember →
                    // ChonkyPixels, Classic → Coral/RetroGaming,
                    // Platinum → MatrixTypeDisplay) instead of the
                    // hero face. Matches the SwiftUI MarkdownTextView
                    // + chat TaggedMarkdownTextView heading paths so
                    // editing a note shows the same H1-H3 font that
                    // its preview / chat reply would render.
                    AppDisplayTypography.nsHeadingFont(
                        size: fontSize,
                        weight: weight,
                        theme: theme
                    )
                } else {
                    AppDisplayTypography.regularUIFont(size: fontSize, weight: weight)
                }
            let headingColor = usesDisplayFont
                ? NSColor(MarkdownHeadingDisplay.foregroundColor(for: theme, level: level))
                : foreground
            var headingAttributes: [NSAttributedString.Key: Any] = [
                .font: headingFont,
                .foregroundColor: headingColor,
                .paragraphStyle: headingParagraph,
            ]
            if let shadow = MarkdownHeadingDisplay.nsShadow(for: theme, level: level) {
                headingAttributes[.shadow] = shadow
            }
            if level == 2 {
                // Remove underline for Level 2
            }
            if level == 4 {
                headingAttributes[.foregroundColor] = foreground.withAlphaComponent(
                    theme.isDark ? 0.92 : 0.95)
            } else if level >= 5 {
                headingAttributes[.foregroundColor] = foreground.withAlphaComponent(
                    theme.isDark ? 0.9 : 0.92)
            }
            attrStr.addAttributes(headingAttributes, range: range)

            switch level {
            case 1:
                applyH1PrefixStyle(
                    to: attrStr,
                    line: line,
                    color: headingColor.withAlphaComponent(0.55)
                )
            case 2:
                applyPrefixColor(
                    to: attrStr,
                    line: line,
                    prefix: "## ",
                    color: headingAccent.withAlphaComponent(0.50),
                    bold: true
                )
            case 3:
                applyPrefixColor(
                    to: attrStr,
                    line: line,
                    prefix: "### ",
                    color: headingAccent.withAlphaComponent(0.45),
                    bold: true
                )
            case 4:
                applyPrefixColor(to: attrStr, line: line, prefix: "#### ", color: accent.withAlphaComponent(0.40), bold: true)
            case 5:
                applyPrefixColor(to: attrStr, line: line, prefix: "##### ", color: accent.withAlphaComponent(0.35), bold: true)
            default:
                applyPrefixColor(to: attrStr, line: line, prefix: "###### ", color: accent.withAlphaComponent(0.35), bold: true)
            }

        case 6:  // CodeBlock
            let codeColor: NSColor = theme.isDark
                ? NSColor.white.withAlphaComponent(0.72)
                : NSColor(white: 0.2, alpha: 1)
            let codeBackground: NSColor = theme.isDark
                ? accent.withAlphaComponent(0.05)
                : accent.withAlphaComponent(0.04)
            attrStr.addAttributes(
                [
                    .font: bodyFont,
                    .foregroundColor: codeColor,
                    .paragraphStyle: MarkdownEditorStyle.codeBlockParagraphStyle(),
                    MarkdownEditorStyle.blockChromeKindAttribute: MarkdownBlockChromeKind.codeBlock.rawValue,
                    MarkdownEditorStyle.blockChromeAccentAttribute: accent,
                    MarkdownEditorStyle.blockChromeFillAttribute: codeBackground,
                ], range: range)

        case 5:  // BlockQuote (plain or callout)
            let calloutTypeId = UInt8((metadata >> 8) & 0xFF)
            if let callout = theme.calloutColors(typeId: calloutTypeId) {
                attrStr.addAttributes(
                    [
                        .font: NSFont.systemFont(ofSize: baseFontSize, weight: .semibold),
                        .foregroundColor: theme.isDark
                            ? callout.accent.withAlphaComponent(0.9) : callout.accent,
                        .paragraphStyle: MarkdownEditorStyle.calloutParagraphStyle(),
                        MarkdownEditorStyle.blockChromeKindAttribute: MarkdownBlockChromeKind.callout.rawValue,
                        MarkdownEditorStyle.blockChromeAccentAttribute: callout.accent,
                        MarkdownEditorStyle.blockChromeFillAttribute: callout.background,
                    ], range: range)
                let calloutPrefix: String
                if let bracketEnd = trimmed.range(of: "] ") {
                    calloutPrefix = String(trimmed[trimmed.startIndex..<bracketEnd.upperBound])
                } else if let bracketEnd = trimmed.range(of: "]") {
                    calloutPrefix = String(trimmed[trimmed.startIndex..<bracketEnd.upperBound])
                } else {
                    calloutPrefix = "> "
                }
                applyPrefixColor(
                    to: attrStr,
                    line: line,
                    prefix: calloutPrefix,
                    color: callout.accent.withAlphaComponent(0.5)
                )
            } else {
                let quoteBackground: NSColor = theme.isDark
                    ? accent.withAlphaComponent(0.04)
                    : accent.withAlphaComponent(0.03)
                attrStr.addAttributes(
                    [
                        .font: NSFont.systemFont(ofSize: baseFontSize, weight: .medium).italic,
                        .foregroundColor: foreground.withAlphaComponent(theme.isDark ? 0.60 : 0.72),
                        .paragraphStyle: MarkdownEditorStyle.quoteParagraphStyle(),
                        MarkdownEditorStyle.blockChromeKindAttribute: MarkdownBlockChromeKind.quote.rawValue,
                        MarkdownEditorStyle.blockChromeAccentAttribute: accent,
                        MarkdownEditorStyle.blockChromeFillAttribute: quoteBackground,
                    ], range: range)
                applyPrefixColor(
                    to: attrStr,
                    line: line,
                    prefix: "> ",
                    color: accent.withAlphaComponent(0.40)
                )
            }

        case 2, 3:  // OrderedList, UnorderedList
            attrStr.addAttributes(
                [
                    .font: bodyFont,
                    .foregroundColor: foreground,
                    .paragraphStyle: MarkdownEditorStyle.listParagraphStyle(),
                ], range: range)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                applyPrefixColor(
                    to: attrStr,
                    line: line,
                    prefix: trimmed.hasPrefix("- ") ? "- " : "* ",
                    color: accent
                )
            } else if let match = Self.numberedListRegex?.firstMatch(
                in: trimmed,
                range: NSRange(trimmed.startIndex..., in: trimmed)
            ) {
                let offset = match.range.length
                let prefixOffset = line.distance(
                    from: line.startIndex,
                    to: line.firstIndex(where: { !$0.isWhitespace }) ?? line.startIndex
                )
                let dimRange = NSRange(location: prefixOffset, length: offset)
                guard dimRange.location + dimRange.length <= attrStr.length else { return }
                attrStr.addAttributes([.foregroundColor: accent], range: dimRange)
            }

        case 4:  // TaskList
            let checked = (metadata & 0xFF) != 0
            let prefix = checked ? "- [x] " : "- [ ] "
            let taskAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: checked ? muted : foreground,
                .paragraphStyle: bodyParagraph,
            ]
            attrStr.addAttributes(
                taskAttributes,
                range: range
            )
            applyPrefixColor(to: attrStr, line: line, prefix: prefix, color: accent)
            if checked, let prefixRange = line.range(of: prefix) {
                let contentStart = line.distance(from: line.startIndex, to: prefixRange.upperBound)
                let contentRange = NSRange(location: contentStart, length: max(attrStr.length - contentStart, 0))
                if contentRange.length > 0 {
                    attrStr.addAttribute(
                        .strikethroughStyle,
                        value: NSUnderlineStyle.single.rawValue,
                        range: contentRange
                    )
                }
            }

        case 7:  // Table
            if usesRenderedTableOverlays {
                let role = tableLineRole ?? .continuation
                let paragraphStyle: NSParagraphStyle
                let font: NSFont
                switch role {
                case .first:
                    paragraphStyle = MarkdownEditorStyle.tablePlaceholderParagraphStyle()
                    font = NSFont.systemFont(ofSize: baseFontSize - 1, weight: .medium)
                case .continuation, .separator:
                    paragraphStyle = MarkdownEditorStyle.tableCollapsedParagraphStyle()
                    font = NSFont.monospacedSystemFont(ofSize: 1, weight: .regular)
                }
                attrStr.addAttributes(
                    [
                        .font: font,
                        .foregroundColor: NSColor.clear,
                        .paragraphStyle: paragraphStyle,
                    ], range: range)
            } else {
                attrStr.addAttributes(
                    [
                        .font: NSFont.systemFont(ofSize: baseFontSize - 1, weight: .regular),
                        .foregroundColor: foreground,
                        .paragraphStyle: MarkdownEditorStyle.tableParagraphStyle(),
                    ], range: range)
            }

        case 8:  // HorizontalRule
            attrStr.addAttributes(
                [
                    .font: NSFont.systemFont(ofSize: max(baseFontSize - 2, 9)),
                    .foregroundColor: accent.withAlphaComponent(0.25),
                    .paragraphStyle: bodyParagraph
                ], range: range)

        case 9:  // HtmlComment
            attrStr.addAttributes(
                [
                    .font: NSFont.systemFont(ofSize: max(baseFontSize - 2, 9)),
                    .foregroundColor: theme.isDark
                        ? NSColor.white.withAlphaComponent(0.15)
                        : NSColor(white: 0.7, alpha: 1),
                    .paragraphStyle: bodyParagraph
                ], range: range)

        default:  // Body
            attrStr.addAttributes(
                [
                    .font: bodyFont,
                    .foregroundColor: foreground,
                    .paragraphStyle: bodyParagraph,
                ], range: range)
        }
    }

    private func hideRenderedTableSourceText(
        in attrStr: NSMutableAttributedString,
        range: NSRange
    ) {
        guard range.location + range.length <= attrStr.length else { return }
        attrStr.addAttribute(.foregroundColor, value: NSColor.clear, range: range)
    }

    // MARK: - Inline Styling (Phase 2)

    /// Parse paragraph text through Rust markdown_parse FFI, apply inline styles.
    /// Called per-paragraph after structural styling. Testable in isolation.
    /// - Parameter isActive: true = active line (ghost markers), false = inactive (hidden markers).
    func applyInlineStyles(
        to attrStr: NSMutableAttributedString,
        fullRange: NSRange,
        sourceText: String? = nil,
        isActive: Bool = true
    ) {
        let text = sourceText ?? attrStr.string
        guard !text.isEmpty, let cStr = text.cString(using: .utf8) else { return }

        var spansPtr: UnsafeMutablePointer<StyleSpan>?
        var count: UInt32 = 0
        let result = markdown_parse(cStr, UInt32(cStr.count - 1), &spansPtr, &count)
        guard result == 0, let spans = spansPtr, count > 0 else { return }
        defer { markdown_free_spans(spans, count) }

        let utf8ToUtf16 = Self.buildUtf8ToUtf16Map(text)
        let sourceNSString = text as NSString
        let isDark = theme.isDark
        let accent = theme.resolved.headingAccent.nsColor
        let linkAccent = theme.preferredMarkdownLinkNSColor ?? accent
        let muted = NSColor(theme.mutedForeground)
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
                .font: NSFont.systemFont(ofSize: 0.01),
            ]
        }

        // Sort largest-first: inner (smaller) spans override outer attribute ranges.
        let sorted = (0..<Int(count)).sorted {
            let a = spans[$0]
            let b = spans[$1]
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
            let sourceRange = NSRange(location: utf16Start, length: utf16End - utf16Start)
            let spanRange = NSRange(
                location: fullRange.location + utf16Start,
                length: utf16End - utf16Start
            )
            guard spanRange.length > 0,
                spanRange.location + spanRange.length <= attrStr.length
            else { continue }

            applySpanStyle(
                to: attrStr, span.style, group: span.group, range: spanRange,
                sourceText: sourceNSString, sourceRange: sourceRange,
                ghost: ghostMarker, accent: accent, linkAccent: linkAccent, muted: muted
            )
        }
    }

    /// Apply visual attributes for a single Rust-parsed inline style span.
    /// Derives font size from the paragraph's existing structural font to preserve
    /// heading/quote/list typography when inline markdown is present.
    private func applySpanStyle(
        to attrStr: NSMutableAttributedString,
        _ style: UInt8, group: UInt8, range: NSRange,
        sourceText: NSString, sourceRange: NSRange,
        ghost: [NSAttributedString.Key: Any],
        accent: NSColor, linkAccent: NSColor, muted: NSColor
    ) {
        // Read the structural font and foreground already applied to this range.
        // Inline styles derive from them so headings keep their size and color.
        let existingFont =
            attrStr.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            ?? NSFont.systemFont(ofSize: baseFontSize)
        let existingForeground =
            attrStr.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
            ?? theme.resolved.foreground.nsColor
        let size = existingFont.pointSize

        switch style {
        case 4:  // Bold — ghost markers, bold content (preserves structural size + foreground)
            attrStr.addAttributes(ghost, range: range)
            if range.length > 4 {
                let content = NSRange(location: range.location + 2, length: range.length - 4)
                attrStr.addAttributes(
                    [
                        .font: AppDisplayTypography.preservingFamilyFont(
                            from: existingFont,
                            size: size,
                            bold: true
                        ),
                        .foregroundColor: existingForeground,
                    ], range: content)
            }

        case 5:  // Italic — ghost markers, italic content (preserves structural size + foreground)
            attrStr.addAttributes(ghost, range: range)
            if range.length > 2 {
                let content = NSRange(location: range.location + 1, length: range.length - 2)
                attrStr.addAttributes(
                    [
                        .font: AppDisplayTypography.preservingFamilyFont(
                            from: existingFont,
                            size: size,
                            italic: true
                        ),
                        .foregroundColor: existingForeground,
                    ], range: content)
            }

        case 6:  // Strikethrough — ghost markers, strikethrough + muted content
            attrStr.addAttributes(ghost, range: range)
            if range.length > 4 {
                let content = NSRange(location: range.location + 2, length: range.length - 4)
                attrStr.addAttributes(
                    [
                        .font: existingFont,
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .foregroundColor: muted,
                    ], range: content)
            }

        case 7:  // InlineCode — ghost backticks, monospace + accent pill (size - 1, floor 11)
            attrStr.addAttributes(ghost, range: range)
            if range.length > 2 {
                let content = NSRange(location: range.location + 1, length: range.length - 2)
                attrStr.addAttributes(
                    [
                        .font: NSFont.monospacedSystemFont(
                            ofSize: max(size - 1, 11), weight: .medium),
                        .foregroundColor: accent.withAlphaComponent(0.90),
                        .backgroundColor: accent.withAlphaComponent(0.10),
                    ], range: content)
            }

        case 13:  // Checkbox [ ] — accent marker, monospace
            attrStr.addAttributes(
                [
                    .foregroundColor: accent.withAlphaComponent(0.7),
                    .font: NSFont.monospacedSystemFont(ofSize: max(size - 1, 11), weight: .regular),
                ], range: range)

        case 14:  // CheckboxChecked [x] — muted marker, monospace
            attrStr.addAttributes(
                [
                    .foregroundColor: muted,
                    .font: NSFont.monospacedSystemFont(ofSize: max(size - 1, 11), weight: .regular),
                ], range: range)

        case 15:  // Wikilink content — accent pill with native link
            let linkTitle = sourceText.substring(with: sourceRange)
            let existingTraits = NSFontManager.shared.traits(of: existingFont)
            let wikilinkFont = AppDisplayTypography.preservingFamilyFont(
                from: existingFont,
                size: size,
                bold: existingTraits.contains(.boldFontMask),
                italic: existingTraits.contains(.italicFontMask)
            )
            attrStr.addAttributes(
                [
                    .font: wikilinkFont,
                    .foregroundColor: linkAccent,
                    .backgroundColor: linkAccent.withAlphaComponent(theme.isDark ? 0.10 : 0.08),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: linkAccent.withAlphaComponent(0.35),
                    .link: "wikilink://\(linkTitle)" as NSString,
                    .cursor: NSCursor.pointingHand,
                ], range: range)

        case 16:  // WikilinkBrackets [[ or ]] — ghosted
            attrStr.addAttributes(ghost, range: range)

        case 17:  // MarkdownLink [text](url) — ghost all, accent pill the text part
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
                        attrStr.addAttributes(
                            [
                                .font: existingFont,
                                .foregroundColor: linkAccent,
                                .backgroundColor: linkAccent.withAlphaComponent(
                                    theme.isDark ? 0.08 : 0.06),
                                .underlineStyle: NSUnderlineStyle.single.rawValue,
                                .underlineColor: linkAccent.withAlphaComponent(0.30),
                            ], range: textRange)
                    }
                }
            }

        case 19:  // InlineMath $expr$ — muted dollars, accent italic content with pill
            attrStr.addAttributes([.foregroundColor: muted], range: range)
            if range.length > 2 {
                let content = NSRange(location: range.location + 1, length: range.length - 2)
                let mathSize = max(size - 1, 11)
                attrStr.addAttributes(
                    [
                        .font: NSFont(name: "NewYork-RegularItalic", size: mathSize)
                            ?? NSFontManager.shared.convert(
                                existingFont, toHaveTrait: .italicFontMask),
                        .foregroundColor: accent,
                        .backgroundColor: accent.withAlphaComponent(theme.isDark ? 0.06 : 0.04),
                    ], range: content)
            }

        case 24:  // BlockReference content — accent + tinted background + native link
            let blockId = sourceText.substring(with: sourceRange)
            attrStr.addAttributes(
                [
                    .foregroundColor: linkAccent,
                    .backgroundColor: linkAccent.withAlphaComponent(theme.isDark ? 0.10 : 0.08),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: linkAccent.withAlphaComponent(0.35),
                    .link: "blockref://\(blockId)" as NSString,
                    .cursor: NSCursor.pointingHand,
                ], range: range)

        case 25:  // BlockReferenceBrackets (( or )) — ghosted
            attrStr.addAttributes(ghost, range: range)

        case 26:  // DisplayMath $$...$$ — muted delimiters, accent italic content, centered
            attrStr.addAttributes([.foregroundColor: muted], range: range)
            if range.length > 4 {
                let content = NSRange(location: range.location + 2, length: range.length - 4)
                let mathSize = max(size + 1, 13)
                let centered = NSMutableParagraphStyle()
                centered.alignment = .center
                centered.lineSpacing = 6
                centered.paragraphSpacingBefore = 8
                centered.paragraphSpacing = 8
                attrStr.addAttributes(
                    [
                        .font: NSFont(name: "NewYork-RegularItalic", size: mathSize)
                            ?? NSFontManager.shared.convert(
                                existingFont, toHaveTrait: .italicFontMask),
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
            if value <= 0x7F {
                u8Len = 1
            } else if value <= 0x7FF {
                u8Len = 2
            } else if value <= 0xFFFF {
                u8Len = 3
            } else {
                u8Len = 4
            }

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

    private func displayText(for paragraphText: String, paraType _: UInt8, metadata _: UInt16) -> String
    {
        paragraphText
    }

    private func leadingDocumentContentIsEmpty(before location: Int, in documentString: NSString)
        -> Bool
    {
        guard location > 0 else { return true }
        let safeLocation = min(location, documentString.length)
        let prefix = documentString.substring(with: NSRange(location: 0, length: safeLocation))
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func applyPrefixColor(
        to attrStr: NSMutableAttributedString,
        line: String,
        prefix: String,
        color: NSColor,
        bold: Bool = false
    ) {
        let leadingIndent = leadingIndentLength(in: line)
        let dimRange = NSRange(location: leadingIndent, length: prefix.utf16.count)
        guard dimRange.location + dimRange.length <= attrStr.length else { return }
        
        var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color]
        if bold {
            attributes[.font] = NSFont.systemFont(ofSize: MarkdownHeadingDisplay.noteHeadingBaseSize(for: 3) - 2, weight: .bold)
        }
        
        attrStr.addAttributes(attributes, range: dimRange)
    }

    private func applyH1PrefixStyle(
        to attrStr: NSMutableAttributedString,
        line: String,
        color: NSColor
    ) {
        let leadingIndent = leadingIndentLength(in: line)
        let dimRange = NSRange(location: leadingIndent, length: 2)
        guard dimRange.location + dimRange.length <= attrStr.length else { return }
        attrStr.addAttributes(
            [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: max(baseFontSize - 5, 9), weight: .regular),
            ],
            range: dimRange
        )
    }

    private func leadingIndentLength(in line: String) -> Int {
        line.prefix { $0 == " " || $0 == "\t" }.utf16.count
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
            lineTokens.append(
                CodeTokenBridge(
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
        let bufferedRange =
            max(
                0, visibleLineRange.lowerBound - viewportBuffer)..<(visibleLineRange.upperBound
            + viewportBuffer)
        guard bufferedRange.contains(line) else { return }
        guard !attrStr.string.isEmpty else { return }

        let lineTokens = codeTokensForLine(
            line, languageId: languageId, documentString: documentString)
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
        guard !utf8Data.isEmpty else { return [] }
        let count: UInt32 = utf8Data.withUnsafeBufferPointer { utf8Buf in
            guard let baseAddress = utf8Buf.baseAddress else { return 0 }
            return langTag.withCString { langPtr in
                markdown_parse_code_tokens(
                    UnsafeRawPointer(baseAddress).assumingMemoryBound(to: CChar.self),
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
            let utf16End =
                endByte < utf8ToUtf16.count ? utf8ToUtf16[endByte] : utf8ToUtf16.last ?? 0
            guard utf16End > utf16Start else { continue }
            tokens.append(
                CodeTokenBridge(start: utf16Start, end: utf16End, tokenType: raw.token_type))
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
                if let currentFont = attrStr.attribute(
                    .font, at: tokenRange.location, effectiveRange: nil) as? NSFont
                {
                    let italic = NSFontManager.shared.convert(
                        currentFont, toHaveTrait: .italicFontMask)
                    attrStr.addAttribute(.font, value: italic, range: tokenRange)
                }
            }
        }
    }

    // MARK: - Non-Destructive Folding

    /// Recompute hidden lines from Rust fold state.
    /// Call after any fold toggle.
    func recomputeHiddenLines(documentText _: String? = nil) {
        hiddenLines.removeAll()

        var activeFoldLevels: [Int] = []
        for lineIndex in cachedTypes.indices {
            if cachedTypes[lineIndex].paraType == 1 {
                let level = headingLevel(at: lineIndex) ?? 1
                activeFoldLevels.removeAll { $0 >= level }
            }

            if !activeFoldLevels.isEmpty {
                hiddenLines.insert(lineIndex)
            }

            if cachedTypes[lineIndex].paraType == 1,
               markdown_is_folded(UInt32(lineIndex)) {
                activeFoldLevels.append(headingLevel(at: lineIndex) ?? 1)
            }
        }
    }

    func foldedContentLineRange(forHeadingAt lineIndex: Int) -> Range<Int>? {
        guard let level = headingLevel(at: lineIndex) else { return nil }
        let start = lineIndex + 1
        guard start < cachedTypes.count else { return nil }

        var end = cachedTypes.count
        var cursor = start
        while cursor < cachedTypes.count {
            if cachedTypes[cursor].paraType == 1,
               (headingLevel(at: cursor) ?? 1) <= level {
                end = cursor
                break
            }
            cursor += 1
        }

        guard start < end else { return nil }
        return start..<end
    }

    func textRange(
        forLines lines: Range<Int>,
        in contentStorage: NSTextContentStorage
    ) -> NSTextRange? {
        guard let range = utf16Range(forLines: lines) else { return nil }
        let docRange = contentStorage.documentRange
        guard
            let start = contentStorage.location(docRange.location, offsetBy: range.location),
            let end = contentStorage.location(start, offsetBy: range.length)
        else {
            return nil
        }
        return NSTextRange(location: start, end: end)
    }

    private func utf16Range(forLines lines: Range<Int>) -> NSRange? {
        guard !lines.isEmpty else { return nil }
        let startLine = max(lines.lowerBound, 0)
        let endLine = min(lines.upperBound, lineStarts.count)
        guard startLine < endLine, startLine < lineStarts.count else { return nil }

        let start = lineStarts[startLine]
        let end = endLine < lineStarts.count ? lineStarts[endLine] : documentLength
        return NSRange(location: start, length: max(end - start, 0))
    }

    func isLineInFoldedRange(_ line: Int) -> Bool {
        hiddenLines.contains(line)
    }

    func hasActiveFolds() -> Bool {
        if !hiddenLines.isEmpty {
            return true
        }

        for lineIndex in cachedTypes.indices where cachedTypes[lineIndex].paraType == 1 {
            if markdown_is_folded(UInt32(lineIndex)) {
                return true
            }
        }

        return false
    }

    /// Number of heading lines in the document.
    var headingCount: Int {
        cachedTypes.count(where: { $0.paraType == 1 })
    }

    /// Whether the line at the given index is a heading.
    func isHeading(at lineIndex: Int) -> Bool {
        guard lineIndex >= 0, lineIndex < cachedTypes.count else { return false }
        return cachedTypes[lineIndex].paraType == 1
    }

    /// Heading level (1-6) at the given line index, or nil if not a heading.
    func headingLevel(at lineIndex: Int) -> Int? {
        guard lineIndex >= 0, lineIndex < cachedTypes.count,
              cachedTypes[lineIndex].paraType == 1 else { return nil }
        return Int(cachedTypes[lineIndex].metadata & 0xFF)
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
            let range = textElement.elementRange
        else { return true }

        let offset = contentStorage.offset(
            from: contentStorage.documentRange.location,
            to: range.location
        )
        let line = lineIndex(at: offset)
        return !hiddenLines.contains(line)
    }
}
