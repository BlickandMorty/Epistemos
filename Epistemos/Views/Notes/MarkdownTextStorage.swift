import AppKit

// MARK: - MarkdownTextStorage
// NSTextStorage subclass that applies live markdown formatting.
// Styling is purely visual — the underlying string is plain markdown text.
//
// Performance contract:
// - processEditing() is O(paragraph) per keystroke, not O(document).
// - reapplyAllStyles() is O(document) — called only on load and theme change.
// - Paragraph styles are static constants (zero allocation per keystroke).
// - Regexes are pre-compiled static constants (zero compilation per keystroke).

// SAFETY: nonisolated(unsafe) is required because NSTextStorage is not Sendable,
// but is always accessed on the main thread via NSLayoutManager / NSTextView.
// All mutable state (isDark, skipInlineStyles, etc.) is only mutated from MainActor contexts.
nonisolated(unsafe) final class MarkdownTextStorage: NSTextStorage {
    private let backing = NSMutableAttributedString()
    var isDark: Bool = true
    var theme: EpistemosTheme?

    /// Base font size for the editor (15pt).
    /// All element sizes (headings, code, etc.) scale relative to this.
    let baseFontSize: CGFloat = 15

    /// When true, processEditing skips inline styles (7 regex passes).
    /// Used during bulk text replacement — line-level styles render first,
    /// inline formatting (bold/italic/code/links) fills in one frame later.
    var skipInlineStyles = false

    /// When true, processEditing skips ALL custom styling (base, line-level, inline, paper).
    /// Used when loading pre-styled content — attributes are already correct.
    var skipAllStyling = false

    /// True while reapplyAllStyles() is running — processEditing skips its
    /// own styling pass to avoid redundant O(document) work.
    private var isRestyling = false

    /// True during processEditing — used by ClickableTextView to gate
    /// the setNeedsDisplay rect expansion (only expand during edits, not scroll).
    private(set) var isProcessingEdits = false

    /// Derived sizes — computed from baseFontSize for consistent scaling.
    private var codeSize: CGFloat { max(baseFontSize - 2, 9) }
    private var smallSize: CGFloat { max(baseFontSize - 1, 9) }
    private var resolvedForegroundColor: NSColor {
        if let theme { return Self.nsColor(hex: theme.foregroundHex) }
        return isDark ? .white.withAlphaComponent(0.88) : NSColor(white: 0.1, alpha: 1)
    }
    private var resolvedAccentColor: NSColor {
        if let theme { return Self.nsColor(hex: theme.headingAccentHex) }
        return Self.accentColor(isDark: isDark)
    }
    private var resolvedMutedColor: NSColor {
        if let theme { return Self.nsColor(hex: theme.mutedForegroundHex) }
        return Self.mutedColor(isDark: isDark)
    }

    /// Leading document title spacing.
    static let leadingH1SpacingBefore: CGFloat = 36
    /// Mid-document H1 spacing.
    static let sectionH1SpacingBefore: CGFloat = 30
    /// Body indent — all non-H1 content is indented so H1 extends beyond (Notion-style).
    static let bodyIndent: CGFloat = 28

    // MARK: - NSTextStorage Overrides

    override var string: String { backing.string }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        guard location < backing.length else {
            range?.pointee = NSRange(location: location, length: 0)
            return [:]
        }
        return backing.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backing.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range,
               changeInLength: str.utf16.count - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        guard range.location + range.length <= backing.length else { return }
        beginEditing()
        backing.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    // MARK: - Incremental Styling (O(paragraph) per keystroke)

    override func processEditing() {
        isProcessingEdits = true
        defer { isProcessingEdits = false }

        // Fast path: loading pre-styled content from cache — skip all custom styling.
        guard !skipAllStyling else {
            super.processEditing()
            return
        }

        // Fast path: reapplyAllStyles already styled everything — just notify layout.
        guard !isRestyling else {
            super.processEditing()
            return
        }

        guard backing.length > 0 else {
            super.processEditing()
            return
        }

        let editedRange = self.editedRange
        guard editedRange.location != NSNotFound else {
            super.processEditing()
            return
        }

        let str = backing.string as NSString
        var paraRange = str.paragraphRange(for: editedRange)

        // Fenced code blocks span multiple paragraphs. When editing near
        // a ``` fence or inside a code block, expand the restyle range
        // forward to the next fence (or end of document) so newly created
        // lines (e.g. pressing Enter) get proper code block styling.
        let trimmedPara = str.substring(with: paraRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .whitespaces)
        if trimmedPara.hasPrefix("```") || isInsideCodeBlock(at: paraRange.location, in: str) {
            var endLoc = paraRange.location + paraRange.length
            while endLoc < str.length {
                let nextLineRange = str.lineRange(for: NSRange(location: endLoc, length: 0))
                let newEnd = nextLineRange.location + nextLineRange.length
                guard newEnd > endLoc, newEnd <= str.length else { break }
                endLoc = newEnd
                // Bounds-check before extracting substring
                guard nextLineRange.location + nextLineRange.length <= str.length else { break }
                let nextLine = str.substring(with: nextLineRange)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: .whitespaces)
                if nextLine.hasPrefix("```") { break }
            }
            let safeEnd = min(endLoc, str.length)
            let safeLen = max(0, safeEnd - paraRange.location)
            paraRange = NSRange(location: paraRange.location, length: safeLen)
        }

        applyBaseStyle(range: paraRange)
        restyleLines(in: paraRange)

        if !skipInlineStyles {
            applyInlineStyles(fullRange: paraRange)
        }

        super.processEditing()
    }

    // MARK: - Full Restyle (Load + Theme Change Only)

    func reapplyAllStyles() {
        guard backing.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: backing.length)

        // isRestyling tells processEditing to skip its own styling pass —
        // we do it all here, avoiding redundant O(document) work.
        isRestyling = true
        beginEditing()
        applyBaseStyle(range: fullRange)
        restyleLines(in: fullRange)
        applyInlineStyles(fullRange: fullRange)

        edited(.editedAttributes, range: fullRange, changeInLength: 0)
        endEditing()
        isRestyling = false
    }

    /// Progressive restyle phase 1: base + line-level styles only.
    /// Call this synchronously, then defer `applyInlineStyles` from the MainActor
    /// call site. Skips the 7-regex inline pass — headings/lists/quotes render
    /// correctly, bold/italic/code fill in one frame later.
    func reapplyLineStyles() {
        guard backing.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: backing.length)

        isRestyling = true
        beginEditing()
        applyBaseStyle(range: fullRange)
        restyleLines(in: fullRange)

        edited(.editedAttributes, range: fullRange, changeInLength: 0)
        endEditing()
        isRestyling = false
    }

    /// Restyle a specific range (e.g. after hover clear).
    /// Reapplies base + line + inline styles for just this range.
    func reapplyStyles(in range: NSRange) {
        guard range.location + range.length <= backing.length else { return }
        // Expand to full line boundaries for correct line-level styling
        let str = backing.string as NSString
        let lineRange = str.lineRange(for: range)
        isRestyling = true
        beginEditing()
        applyBaseStyle(range: lineRange)
        restyleLines(in: lineRange)
        applyInlineStyles(fullRange: lineRange)
        edited(.editedAttributes, range: lineRange, changeInLength: 0)
        endEditing()
        isRestyling = false
    }

    // MARK: - Pre-Styled Content Loading

    /// Loads pre-styled attributed content, bypassing all custom styling.
    // MARK: - Base Style

    func applyBaseStyle(range: NSRange) {
        guard range.location + range.length <= backing.length else { return }
        let baseFont = NSFont.systemFont(ofSize: baseFontSize)
        backing.setAttributes([
            .font: baseFont,
            .foregroundColor: resolvedForegroundColor,
            .paragraphStyle: Self.bodyStyle
        ], range: range)
    }

    // MARK: - Line-Level Styling

    func restyleLines(in range: NSRange) {
        guard range.location + range.length <= backing.length else { return }
        let str = backing.string as NSString

        // Detect if we're starting inside a code block by counting ``` fences
        // before `range.location`. Uses NSString.range(of:) backward search —
        // native CFString search, much faster than substring+split.
        var inCodeBlock = isInsideCodeBlock(at: range.location, in: str)

        var loc = range.location
        let end = range.location + range.length
        while loc < end {
            let lineRange = str.lineRange(for: NSRange(location: loc, length: 0))
            let line = str.substring(with: lineRange).trimmingCharacters(in: .newlines)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Subtract 1 for trailing newline — but only if the line actually
            // ends with \n. The final line of the document has no trailing newline,
            // so subtracting 1 would clip the last character (e.g. an emoji).
            let lineEnd = lineRange.location + lineRange.length
            let hasTrailingNewline = lineEnd > 0 && lineEnd <= str.length
                && str.character(at: lineEnd - 1) == 0x0A /* \n */
            let styleLen = hasTrailingNewline ? lineRange.length - 1 : lineRange.length
            let styleRange = NSRange(location: lineRange.location,
                                     length: max(0, styleLen))

            if trimmed.hasPrefix("```") {
                // Fence delimiter — toggle state, style as delimiter
                applyLineStyle(line: line, range: styleRange)
                inCodeBlock.toggle()
            } else if inCodeBlock {
                // Code block content — iA Writer style: body font with subtle background
                // + indent. No monospaced font change = no glyph metric recalculation.
                if styleRange.location + styleRange.length <= backing.length {
                    let codeColor: NSColor = isDark
                        ? NSColor.white.withAlphaComponent(0.72)
                        : NSColor(white: 0.2, alpha: 1)
                    let accent = resolvedAccentColor
                    let codeBg: NSColor = isDark
                        ? accent.withAlphaComponent(0.05)
                        : accent.withAlphaComponent(0.04)
                    backing.addAttributes([
                        .foregroundColor: codeColor,
                        .backgroundColor: codeBg,
                        .paragraphStyle: Self.codeBlockStyle
                    ], range: styleRange)
                }
            } else {
                applyLineStyle(line: line, range: styleRange)
                styleBlockPropertyChips(in: line, lineStart: lineRange.location, styleRange: styleRange)
            }

            loc = lineRange.location + lineRange.length
            if loc == lineRange.location { break }
        }
    }

    /// Check if `location` is inside a fenced code block.
    /// Counts ``` fence lines before `location` — odd count = inside.
    /// Uses NSString.range(of:options:.backwards) for native-speed search,
    /// visiting only fence lines rather than allocating a full prefix substring.
    private func isInsideCodeBlock(at location: Int, in str: NSString) -> Bool {
        guard location > 0 else { return false }
        var fenceCount = 0
        var cursor = location
        // Walk backward finding each "\n```" occurrence
        while cursor > 0 {
            let r = str.range(of: "\n```", options: .backwards, range: NSRange(location: 0, length: cursor))
            if r.location == NSNotFound { break }
            fenceCount += 1
            cursor = r.location
        }
        // Also check if the very first line is a fence (no preceding \n)
        if str.length >= 3 {
            let firstLineEnd = str.range(of: "\n", range: NSRange(location: 0, length: min(str.length, 200)))
            let firstLen = firstLineEnd.location == NSNotFound ? min(str.length, 200) : firstLineEnd.location
            if firstLen >= 3 {
                let first = str.substring(with: NSRange(location: 0, length: firstLen))
                if first.trimmingCharacters(in: .whitespaces).hasPrefix("```") && location > firstLen {
                    fenceCount += 1
                }
            }
        }
        return fenceCount % 2 != 0
    }

    private func applyLineStyle(line: String, range: NSRange) {
        guard range.location + range.length <= backing.length else { return }
        let t = line.trimmingCharacters(in: .whitespaces)
        let accentColor = resolvedAccentColor
        let mutedColor = resolvedMutedColor
        let foregroundColor = resolvedForegroundColor

        if t.hasPrefix("# ") && !t.hasPrefix("## ") {
            backing.addAttributes([
                .font: displayFont(size: baseFontSize + 31, weight: .bold),
                .foregroundColor: accentColor,
                .paragraphStyle: leadingDocumentContentIsEmpty(before: range.location)
                    ? Self.leadingH1Style
                    : Self.h1Style
            ], range: range)
            // Ulysses-style: override # prefix with tiny font + muted color
            dimH1Prefix(in: line, lineStart: range.location)

        } else if t.hasPrefix("## ") && !t.hasPrefix("### ") {
            backing.addAttributes([
                .font: displayFont(size: baseFontSize + 5, weight: .bold),
                .foregroundColor: accentColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: accentColor.withAlphaComponent(0.18),
                .paragraphStyle: Self.h2Style
            ], range: range)
            dimPrefix(in: line, prefix: "## ", lineStart: range.location, color: accentColor.withAlphaComponent(0.5))

        } else if t.hasPrefix("### ") && !t.hasPrefix("#### ") {
            backing.addAttributes([
                .font: displayFont(size: baseFontSize + 1, weight: .semibold),
                .foregroundColor: accentColor,
                .paragraphStyle: Self.h3Style
            ], range: range)
            dimPrefix(in: line, prefix: "### ", lineStart: range.location, color: accentColor.withAlphaComponent(0.45))

        } else if t.hasPrefix("#### ") && !t.hasPrefix("##### ") {
            backing.addAttributes([
                .font: NSFont.systemFont(ofSize: baseFontSize, weight: .semibold),
                .foregroundColor: foregroundColor.withAlphaComponent(isDark ? 0.92 : 0.95),
                .paragraphStyle: Self.h4Style
            ], range: range)
            dimPrefix(in: line, prefix: "#### ", lineStart: range.location, color: accentColor.withAlphaComponent(0.40))

        } else if t.hasPrefix("##### ") {
            backing.addAttributes([
                .font: NSFont.systemFont(ofSize: smallSize, weight: .medium),
                .foregroundColor: foregroundColor.withAlphaComponent(isDark ? 0.9 : 0.92),
                .paragraphStyle: Self.h5Style
            ], range: range)
            dimPrefix(in: line, prefix: "##### ", lineStart: range.location, color: accentColor.withAlphaComponent(0.35))

        } else if t.hasPrefix("```") {
            // Fenced code block delimiter — dimmed, body font (no monospaced change)
            backing.addAttributes([
                .foregroundColor: mutedColor
            ], range: range)

        } else if t.hasPrefix("- [x] ") || t.hasPrefix("- [ ] ") {
            let checked = t.hasPrefix("- [x] ")
            var attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: baseFontSize),
                .foregroundColor: checked ? mutedColor : foregroundColor
            ]
            if checked { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            backing.addAttributes(attrs, range: range)
            let pfx = checked ? "- [x] " : "- [ ] "
            dimPrefix(in: line, prefix: pfx, lineStart: range.location, color: accentColor)

        } else if t.hasPrefix("- ") || t.hasPrefix("* ") {
            backing.addAttributes([
                .font: NSFont.systemFont(ofSize: baseFontSize),
                .paragraphStyle: Self.listStyle
            ], range: range)
            let pfx = t.hasPrefix("- ") ? "- " : "* "
            dimPrefix(in: line, prefix: pfx, lineStart: range.location, color: accentColor)

        } else if Self.numberedListRegex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil {
            backing.addAttributes([
                .font: NSFont.systemFont(ofSize: baseFontSize),
                .paragraphStyle: Self.listStyle
            ], range: range)
            if let numMatch = Self.numberedListRegex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) {
                let offset = numMatch.range.length
                let prefixOffset = line.distance(from: line.startIndex,
                    to: line.firstIndex(where: { !$0.isWhitespace }) ?? line.startIndex)
                let dimRange = NSRange(location: range.location + prefixOffset, length: offset)
                if dimRange.location + dimRange.length <= backing.length {
                    backing.addAttributes([.foregroundColor: accentColor], range: dimRange)
                }
            }

        } else if t.hasPrefix("> [!") {
            let calloutType = Self.parseCalloutType(t)
            let colors = Self.calloutColors(for: calloutType, isDark: isDark)
            backing.addAttributes([
                .font: NSFont.systemFont(ofSize: baseFontSize, weight: .medium),
                .foregroundColor: colors.text,
                .backgroundColor: colors.bg,
                .paragraphStyle: Self.calloutStyle
            ], range: range)
            // Dim the > [!type] prefix, show the icon + title portion brighter
            let calloutPrefix: String
            if let bracketEnd = t.range(of: "] ") {
                calloutPrefix = String(t[t.startIndex..<bracketEnd.upperBound])
            } else if let bracketEnd = t.range(of: "]") {
                calloutPrefix = String(t[t.startIndex..<bracketEnd.upperBound])
            } else {
                calloutPrefix = "> "
            }
            dimPrefix(in: line, prefix: calloutPrefix, lineStart: range.location, color: colors.accent.withAlphaComponent(0.5))

        } else if t.hasPrefix("> ") {
            // Check if this is a callout continuation line
            let calloutCtx = calloutContext(at: range.location, in: backing.string as NSString)
            if let calloutType = calloutCtx {
                let colors = Self.calloutColors(for: calloutType, isDark: isDark)
                backing.addAttributes([
                    .font: NSFont.systemFont(ofSize: baseFontSize),
                    .foregroundColor: colors.text,
                    .backgroundColor: colors.bg,
                    .paragraphStyle: Self.calloutStyle
                ], range: range)
                dimPrefix(in: line, prefix: "> ", lineStart: range.location, color: colors.accent.withAlphaComponent(0.35))
            } else {
                let quoteBg: NSColor = isDark
                    ? accentColor.withAlphaComponent(0.04)
                    : accentColor.withAlphaComponent(0.03)
                backing.addAttributes([
                    .font: NSFont.systemFont(ofSize: baseFontSize).italic,
                    .foregroundColor: foregroundColor.withAlphaComponent(isDark ? 0.60 : 0.72),
                    .backgroundColor: quoteBg
                ], range: range)
                dimPrefix(in: line, prefix: "> ", lineStart: range.location, color: accentColor.withAlphaComponent(0.40))
            }

        } else if t == "---" || t == "***" {
            backing.addAttributes([
                .foregroundColor: accentColor.withAlphaComponent(0.25),
                .font: NSFont.systemFont(ofSize: codeSize)
            ], range: range)

        } else if t.hasPrefix("<!-- ") && t.hasSuffix(" -->") {
            // HTML comment markers (e.g. <!-- ai-chat -->) — nearly invisible
            backing.addAttributes([
                .foregroundColor: isDark ? NSColor.white.withAlphaComponent(0.15) : NSColor(white: 0.7, alpha: 1),
                .font: NSFont.systemFont(ofSize: codeSize)
            ], range: range)

        } else if t.hasPrefix("$$") || (t.hasPrefix("$") && t.hasSuffix("$") && t.count > 2
                && !t.dropFirst().dropLast().allSatisfy({ $0.isNumber || $0 == "," || $0 == "." })) {
            let isBlock = t.hasPrefix("$$")
            let mathFont = NSFont(name: "NewYork-RegularItalic", size: isBlock ? baseFontSize + 2 : baseFontSize)
                ?? NSFont.systemFont(ofSize: isBlock ? baseFontSize + 2 : baseFontSize).italic
            let mathColor = isDark ? accentColor.withAlphaComponent(0.85) : accentColor.withAlphaComponent(0.9)
            let mathBg = isDark ? accentColor.withAlphaComponent(0.05) : accentColor.withAlphaComponent(0.04)
            var attrs: [NSAttributedString.Key: Any] = [
                .font: mathFont,
                .foregroundColor: mathColor,
                .backgroundColor: mathBg
            ]
            backing.addAttributes(attrs, range: range)
            let lineStr = (backing.string as NSString).substring(with: range)
            for (offset, ch) in lineStr.utf16.enumerated() where ch == 0x24 /* $ */ {
                let dollarRange = NSRange(location: range.location + offset, length: 1)
                if dollarRange.location + dollarRange.length <= backing.length {
                    backing.addAttributes([.foregroundColor: mutedColor], range: dollarRange)
                }
            }

        } else if t.hasPrefix("|") && t.hasSuffix("|") {
            // Table row — liquid glass styling. Grid lines drawn in drawBackground()
            // via NSBezierPath (rounded border, dividers). Text styling here handles:
            // - Monospace font for column alignment
            // - Header bold weight
            // - Muted pipe characters (grid lines replace them visually)
            // - Alternating row tint for depth
            let lineStr = (backing.string as NSString).substring(with: range)
            let isSepRow = lineStr.trimmingCharacters(in: .whitespaces)
                .dropFirst().dropLast()
                .split(separator: "|", omittingEmptySubsequences: false)
                .allSatisfy { $0.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" } }

            if isSepRow {
                // Separator row — collapsed to near-zero height
                backing.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: 1, weight: .regular),
                    .foregroundColor: NSColor.clear,
                    .paragraphStyle: Self.tableSepStyle
                ], range: range)
            } else {
                let str = backing.string as NSString
                let isHeader = Self.isTableHeader(at: range, in: str)

                // Apple Notes style: system font, standard label colors
                backing.addAttributes([
                    .font: NSFont.systemFont(ofSize: isHeader ? baseFontSize : baseFontSize - 1,
                                             weight: isHeader ? .semibold : .regular),
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: Self.tableStyle
                ], range: range)

                // Hide pipes — grid lines drawn in drawBackground()
                for (offset, ch) in lineStr.utf16.enumerated() where ch == 0x7C {
                    let pipeRange = NSRange(location: range.location + offset, length: 1)
                    if pipeRange.location + pipeRange.length <= backing.length {
                        backing.addAttributes([
                            .foregroundColor: NSColor.clear
                        ], range: pipeRange)
                    }
                }
            }
        }
        // Empty lines: no special styling. They inherit base font/style from applyBaseStyle().
        // Setting a different font size on empty lines triggers NSLayoutManager to re-flow
        // the entire document (line height changed) on every keystroke.
    }

    // MARK: - Block Property Chips (@key=value)

    private static let blockPropertyRegex = try! NSRegularExpression(pattern: #"@(\w+)=([^\s@]+)"#)

    /// Style trailing @key=value tokens as inline chips: smaller font, secondary color,
    /// subtle background. Adds a custom attribute for click handling.
    private func styleBlockPropertyChips(in line: String, lineStart: Int, styleRange: NSRange) {
        guard styleRange.location + styleRange.length <= backing.length else { return }
        let nsLine = line as NSString
        let lineLen = nsLine.length
        let matches = Self.blockPropertyRegex.matches(in: line, range: NSRange(location: 0, length: lineLen))
        guard !matches.isEmpty else { return }

        // Only style trailing properties (contiguous block at end of line, ignoring trailing whitespace)
        let trimmedEnd = lineLen - line.reversed().prefix(while: { $0.isWhitespace }).count
        var trailingStart = trimmedEnd
        for match in matches.reversed() {
            let matchEnd = match.range.location + match.range.length
            if matchEnd == trailingStart || (matchEnd < trailingStart &&
                nsLine.substring(with: NSRange(location: matchEnd, length: trailingStart - matchEnd))
                    .allSatisfy({ $0.isWhitespace })) {
                trailingStart = match.range.location
            } else {
                break
            }
        }

        let chipFont = NSFont.systemFont(ofSize: max(baseFontSize - 3, 9), weight: .medium)
        let chipColor: NSColor = isDark
            ? .white.withAlphaComponent(0.50)
            : NSColor(white: 0.40, alpha: 1)
        let chipBg: NSColor = isDark
            ? .white.withAlphaComponent(0.06)
            : NSColor(white: 0.0, alpha: 0.06)

        for match in matches where match.range.location >= trailingStart {
            let chipRange = NSRange(location: lineStart + match.range.location,
                                    length: match.range.length)
            guard chipRange.location + chipRange.length <= backing.length else { continue }
            let kvString = nsLine.substring(with: match.range)
            backing.addAttributes([
                .font: chipFont,
                .foregroundColor: chipColor,
                .backgroundColor: chipBg,
                .init("EpistemosBlockProperty"): kvString
            ], range: chipRange)
        }
    }

    // MARK: - Inline Styles (Rust pulldown-cmark parser via FFI)
    //
    // Replaces 7 regex passes with a single Rust parse call. The Rust parser
    // (pulldown-cmark) handles bold, italic, strikethrough, inline code,
    // [[wikilinks]], [links](url), and $inline math$ with correct nesting
    // and CommonMark compliance.

    private static let numberedListRegex = try! NSRegularExpression(pattern: #"^\d+\.\s"#)

    /// Inline style kinds from the Rust parser that we apply here.
    /// Line-level styles (headings, lists, quotes, code blocks, tables) are
    /// handled by restyleLines() and skipped from the Rust output.
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

    func applyInlineStyles(fullRange: NSRange) {
        let nsStr = backing.string as NSString
        guard fullRange.location + fullRange.length <= nsStr.length else { return }
        let substring = nsStr.substring(with: fullRange)
        guard !substring.isEmpty else { return }
        guard let cStr = substring.cString(using: .utf8) else { return }

        var spansPtr: UnsafeMutablePointer<StyleSpan>?
        var count: UInt32 = 0
        let result = markdown_parse(cStr, UInt32(cStr.count - 1), &spansPtr, &count)
        guard result == 0 else { return }
        guard let spans = spansPtr, count > 0 else { return }
        defer { markdown_free_spans(spans, count) }

        // Build UTF-8 byte → UTF-16 code unit offset map (O(paragraph)).
        let utf8ToUtf16 = Self.buildUtf8ToUtf16Map(substring)

        let accentColor = resolvedAccentColor
        let mutedColor = resolvedMutedColor
        let ghostMarker: [NSAttributedString.Key: Any] = [
            .foregroundColor: isDark
                ? NSColor.white.withAlphaComponent(0.15)
                : NSColor.black.withAlphaComponent(0.12)
        ]

        // Sort spans largest-first so inner (smaller) spans override outer ones.
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
                  spanRange.location + spanRange.length <= backing.length else { continue }

            applySpanStyle(
                span.style, group: span.group, range: spanRange,
                ghost: ghostMarker, accent: accentColor, muted: mutedColor
            )
        }
    }

    /// Apply visual attributes for a single Rust-parsed style span.
    private func applySpanStyle(
        _ style: UInt8, group: UInt8, range: NSRange,
        ghost: [NSAttributedString.Key: Any],
        accent: NSColor, muted: NSColor
    ) {
        let existingFont = backing.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            ?? NSFont.systemFont(ofSize: baseFontSize)
        let size = existingFont.pointSize

        switch style {
        case 4: // Bold — ghost markers, bold content
            backing.addAttributes(ghost, range: range)
            if range.length > 4 {
                let content = NSRange(location: range.location + 2, length: range.length - 4)
                backing.addAttributes([
                    .font: displayFont(size: size, weight: .bold)
                ], range: content)
            }

        case 5: // Italic — ghost markers, italic content
            backing.addAttributes(ghost, range: range)
            if range.length > 2 {
                let content = NSRange(location: range.location + 1, length: range.length - 2)
                backing.addAttributes([
                    .font: NSFontManager.shared.convert(existingFont, toHaveTrait: .italicFontMask)
                ], range: content)
            }

        case 6: // Strikethrough — ghost markers, strikethrough + muted content
            backing.addAttributes(ghost, range: range)
            if range.length > 4 {
                let content = NSRange(location: range.location + 2, length: range.length - 4)
                backing.addAttributes([
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: muted
                ], range: content)
            }

        case 7: // InlineCode — ghost backticks, accent pill for content
            backing.addAttributes(ghost, range: range)
            if range.length > 2 {
                let content = NSRange(location: range.location + 1, length: range.length - 2)
                backing.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: baseFontSize - 1, weight: .medium),
                    .foregroundColor: accent.withAlphaComponent(0.90),
                    .backgroundColor: accent.withAlphaComponent(0.10)
                ], range: content)
            }

        case 15: // Wikilink content — accent pill with native link handling
            let linkTitle = (backing.string as NSString).substring(with: range)
            let linkBg: NSColor = isDark
                ? accent.withAlphaComponent(0.10)
                : accent.withAlphaComponent(0.08)
            backing.addAttributes([
                .foregroundColor: accent,
                .backgroundColor: linkBg,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: accent.withAlphaComponent(0.35),
                .link: "wikilink://\(linkTitle)" as NSString,
                .cursor: NSCursor.pointingHand
            ], range: range)

        case 16: // WikilinkBrackets [[ or ]] — ghosted
            backing.addAttributes(ghost, range: range)

        case 17: // MarkdownLink [text](url) — ghost all, accent pill the text part
            backing.addAttributes(ghost, range: range)
            if range.length > 4 {
                let linkStr = (backing.string as NSString).substring(with: range)
                if let closeBracket = linkStr.firstIndex(of: "]") {
                    let textLen = linkStr.distance(
                        from: linkStr.index(after: linkStr.startIndex),
                        to: closeBracket
                    )
                    if textLen > 0 {
                        let textRange = NSRange(location: range.location + 1, length: textLen)
                        let linkBg: NSColor = isDark
                            ? accent.withAlphaComponent(0.08)
                            : accent.withAlphaComponent(0.06)
                        backing.addAttributes([
                            .foregroundColor: accent,
                            .backgroundColor: linkBg,
                            .underlineStyle: NSUnderlineStyle.single.rawValue,
                            .underlineColor: accent.withAlphaComponent(0.30)
                        ], range: textRange)
                    }
                }
            }

        case 19: // InlineMath $expr$ — muted dollars, accent italic content with pill
            backing.addAttributes([.foregroundColor: muted], range: range)
            if range.length > 2 {
                let content = NSRange(location: range.location + 1, length: range.length - 2)
                backing.addAttributes([
                    .font: NSFont(name: "NewYork-RegularItalic", size: smallSize)
                        ?? NSFont.systemFont(ofSize: smallSize).italic,
                    .foregroundColor: accent,
                    .backgroundColor: accent.withAlphaComponent(isDark ? 0.06 : 0.04)
                ], range: content)
            }

        case 24: // BlockReference content — accent + tinted background + native link
            let blockId = (backing.string as NSString).substring(with: range)
            backing.addAttributes([
                .foregroundColor: accent,
                .backgroundColor: accent.withAlphaComponent(isDark ? 0.10 : 0.08),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: accent.withAlphaComponent(0.35),
                .link: "blockref://\(blockId)" as NSString,
                .cursor: NSCursor.pointingHand
            ], range: range)

        case 25: // BlockReferenceBrackets (( or )) — ghosted
            backing.addAttributes(ghost, range: range)

        default:
            break
        }
    }

    /// Build a lookup table from UTF-8 byte offsets to UTF-16 code unit offsets.
    /// Index = byte position in UTF-8, value = corresponding UTF-16 offset.
    /// Size is utf8Count + 1 (sentinel for end-of-string positions).
    private static func buildUtf8ToUtf16Map(_ str: String) -> [Int] {
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

    // MARK: - Helpers

    /// Count the 0-based data row index for a table data line.
    /// Walks backward from the current line through consecutive table lines,
    /// skipping the separator row and header row, counting only data rows.
    private static func tableDataRowIndex(at range: NSRange, in str: NSString) -> Int {
        var index = 0
        var searchLoc = range.location
        while searchLoc > 0 {
            // Move to previous line
            let prevEnd = searchLoc - 1  // skip newline
            guard prevEnd > 0 else { break }
            let prevLineRange = str.lineRange(for: NSRange(location: prevEnd, length: 0))
            let prevLine = str.substring(with: prevLineRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard prevLine.hasPrefix("|") && prevLine.hasSuffix("|") else { break }

            // Check if separator row
            let isSep = prevLine.dropFirst().dropLast()
                .split(separator: "|", omittingEmptySubsequences: false)
                .allSatisfy { $0.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" } }
            if isSep {
                break  // separator row — stop counting, data rows are below it
            }
            index += 1
            searchLoc = prevLineRange.location
        }
        return index
    }

    /// Check if a table line is the header row by peeking at the next line.
    /// A line is a header if the immediately following line is a separator row (| --- | --- |).
    private static func isTableHeader(at range: NSRange, in str: NSString) -> Bool {
        let lineEnd = range.location + range.length
        // Skip the newline character(s) after the current line
        var nextStart = lineEnd
        while nextStart < str.length {
            let ch = str.character(at: nextStart)
            if ch == 0x0A || ch == 0x0D { // \n or \r
                nextStart += 1
            } else {
                break
            }
        }
        guard nextStart < str.length else { return false }

        let nextLineRange = str.lineRange(for: NSRange(location: nextStart, length: 0))
        let nextLine = str.substring(with: nextLineRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard nextLine.hasPrefix("|") && nextLine.hasSuffix("|") else { return false }

        return nextLine.dropFirst().dropLast()
            .split(separator: "|", omittingEmptySubsequences: false)
            .allSatisfy { $0.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" } }
    }

    private func dimPrefix(in line: String, prefix: String, lineStart: Int, color: NSColor) {
        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        let prefixLen = prefix.utf16.count
        let dimRange = NSRange(location: lineStart + leadingSpaces, length: prefixLen)
        guard dimRange.location + dimRange.length <= backing.length else { return }
        backing.addAttributes([.foregroundColor: color], range: dimRange)
    }

    /// Ulysses-style H1 prefix: renders the `# ` marker as tiny + muted alongside the large title.
    /// Applied after the full-line H1 style so it overrides font size on just those 2 chars.
    private func dimH1Prefix(in line: String, lineStart: Int) {
        let leadingSpaces = line.prefix(while: { $0 == " " }).count
        let dimRange = NSRange(location: lineStart + leadingSpaces, length: 2) // "# "
        guard dimRange.location + dimRange.length <= backing.length else { return }
        backing.addAttributes([
            .foregroundColor: resolvedAccentColor.withAlphaComponent(0.55),
            .font: NSFont.systemFont(ofSize: max(baseFontSize - 5, 9), weight: .regular)
        ], range: dimRange)
    }

    private func displayFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        AppDisplayTypography.nsFont(size: size, weight: weight)
    }

    private static func nsColor(hex: UInt32) -> NSColor {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }

    private func leadingDocumentContentIsEmpty(before location: Int) -> Bool {
        guard location > 0 else { return true }
        let prefix = (backing.string as NSString).substring(to: location)
        return prefix.allSatisfy(\.isWhitespace)
    }

    // MARK: - Callout Support

    enum CalloutType: String {
        case note, info, tip, hint, important
        case warning, caution, attention
        case danger, error, bug, fail, failure
        case success, check, done
        case question, help, faq
        case quote, cite
        case example
        case abstract, summary, tldr
    }

    struct CalloutColors {
        let accent: NSColor
        let text: NSColor
        let bg: NSColor
    }

    static func parseCalloutType(_ line: String) -> CalloutType {
        // Extract type from > [!type] or > [!type] Title
        guard let start = line.range(of: "[!")?.upperBound,
              let end = line[start...].firstIndex(of: "]") else { return .note }
        let raw = String(line[start..<end]).lowercased().trimmingCharacters(in: .whitespaces)
        return CalloutType(rawValue: raw) ?? .note
    }

    static func calloutColors(for type: CalloutType, isDark: Bool) -> CalloutColors {
        let base: NSColor
        switch type {
        case .note, .info:
            base = NSColor(red: 0.35, green: 0.55, blue: 0.95, alpha: 1) // blue
        case .tip, .hint, .important:
            base = NSColor(red: 0.25, green: 0.75, blue: 0.55, alpha: 1) // teal
        case .warning, .caution, .attention:
            base = NSColor(red: 0.90, green: 0.70, blue: 0.20, alpha: 1) // amber
        case .danger, .error, .bug, .fail, .failure:
            base = NSColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 1) // red
        case .success, .check, .done:
            base = NSColor(red: 0.25, green: 0.75, blue: 0.35, alpha: 1) // green
        case .question, .help, .faq:
            base = NSColor(red: 0.65, green: 0.50, blue: 0.90, alpha: 1) // purple
        case .quote, .cite:
            base = NSColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 1) // gray
        case .example:
            base = NSColor(red: 0.60, green: 0.45, blue: 0.85, alpha: 1) // indigo
        case .abstract, .summary, .tldr:
            base = NSColor(red: 0.30, green: 0.70, blue: 0.85, alpha: 1) // cyan
        }

        let text = isDark ? base.withAlphaComponent(0.9) : base
        let bg = isDark ? base.withAlphaComponent(0.07) : base.withAlphaComponent(0.05)
        return CalloutColors(accent: base, text: text, bg: bg)
    }

    /// Walk backward from `location` to find if this `> ` line is a callout continuation.
    /// Returns the callout type if the preceding `> ` chain leads to a `> [!type]` header.
    private func calloutContext(at location: Int, in str: NSString) -> CalloutType? {
        guard location > 0 else { return nil }
        var cursor = location
        while cursor > 0 {
            // Find previous line
            let prevEnd = cursor - 1
            guard prevEnd >= 0 else { return nil }
            let prevLineRange = str.lineRange(for: NSRange(location: max(0, prevEnd), length: 0))
            let prevLine = str.substring(with: prevLineRange).trimmingCharacters(in: .whitespacesAndNewlines)

            if prevLine.hasPrefix("> [!") {
                return Self.parseCalloutType(prevLine)
            } else if prevLine.hasPrefix("> ") {
                cursor = prevLineRange.location
            } else {
                return nil
            }
        }
        return nil
    }

    // MARK: - Theme Colors (Static Helpers)

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

    // MARK: - Cached Paragraph Styles
    // Static constants — created once per process lifetime, zero allocation per keystroke.
    // SAFETY: All `ps.copy() as! NSParagraphStyle` casts below are guaranteed safe by Foundation.
    // NSMutableParagraphStyle.copy() always returns NSParagraphStyle (immutable copy pattern).

    /// Code block content: indented with tight line spacing.
    /// No monospaced font — visual block via background color + indent (iA Writer style).
    private nonisolated(unsafe) static let calloutStyle: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 3
        ps.paragraphSpacing = 1
        ps.paragraphSpacingBefore = 1
        ps.headIndent = bodyIndent + 20
        ps.firstLineHeadIndent = bodyIndent + 20
        return ps.copy() as! NSParagraphStyle
    }()

    private nonisolated(unsafe) static let codeBlockStyle: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 3
        ps.paragraphSpacing = 0
        ps.paragraphSpacingBefore = 0
        ps.headIndent = bodyIndent + 16
        ps.firstLineHeadIndent = bodyIndent + 16
        return ps.copy() as! NSParagraphStyle
    }()

    private nonisolated(unsafe) static let bodyStyle: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 5
        ps.paragraphSpacing = 8
        ps.paragraphSpacingBefore = 0
        ps.firstLineHeadIndent = bodyIndent
        ps.headIndent = bodyIndent
        return ps.copy() as! NSParagraphStyle
    }()

    private nonisolated(unsafe) static let h1Style: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.paragraphSpacingBefore = sectionH1SpacingBefore
        ps.paragraphSpacing = 6
        ps.lineSpacing = 0
        // No indent — H1 bleeds past indented body text (Notion-style)
        return ps.copy() as! NSParagraphStyle
    }()

    private nonisolated(unsafe) static let leadingH1Style: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.paragraphSpacingBefore = leadingH1SpacingBefore
        ps.paragraphSpacing = 6
        ps.lineSpacing = 0
        return ps.copy() as! NSParagraphStyle
    }()

    private nonisolated(unsafe) static let h2Style: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.paragraphSpacingBefore = 12
        ps.paragraphSpacing = 2
        ps.lineSpacing = 2
        ps.firstLineHeadIndent = bodyIndent
        ps.headIndent = bodyIndent
        return ps.copy() as! NSParagraphStyle
    }()

    private nonisolated(unsafe) static let h3Style: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.paragraphSpacingBefore = 8
        ps.paragraphSpacing = 2
        ps.lineSpacing = 2
        ps.firstLineHeadIndent = bodyIndent
        ps.headIndent = bodyIndent
        return ps.copy() as! NSParagraphStyle
    }()

    private nonisolated(unsafe) static let h4Style: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.paragraphSpacingBefore = 6
        ps.paragraphSpacing = 2
        ps.lineSpacing = 2
        ps.firstLineHeadIndent = bodyIndent
        ps.headIndent = bodyIndent
        return ps.copy() as! NSParagraphStyle
    }()

    private nonisolated(unsafe) static let h5Style: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.paragraphSpacingBefore = 4
        ps.paragraphSpacing = 2
        ps.lineSpacing = 2
        ps.firstLineHeadIndent = bodyIndent
        ps.headIndent = bodyIndent
        return ps.copy() as! NSParagraphStyle
    }()

    private nonisolated(unsafe) static let listStyle: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 3
        ps.paragraphSpacing = 1
        ps.firstLineHeadIndent = bodyIndent
        ps.headIndent = bodyIndent + 16
        return ps.copy() as! NSParagraphStyle
    }()

    /// Table row spacing — enough padding for a clean rendered look.
    private nonisolated(unsafe) static let tableStyle: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 4
        ps.paragraphSpacing = 1
        ps.paragraphSpacingBefore = 1
        ps.firstLineHeadIndent = bodyIndent
        ps.headIndent = bodyIndent
        return ps.copy() as! NSParagraphStyle
    }()

    /// Separator row — collapsed to near-zero height so it's invisible.
    private nonisolated(unsafe) static let tableSepStyle: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.minimumLineHeight = 1
        ps.maximumLineHeight = 1
        ps.lineSpacing = 0
        ps.paragraphSpacing = 0
        ps.paragraphSpacingBefore = 0
        return ps.copy() as! NSParagraphStyle
    }()

}

// MARK: - NSFont Italic Helper

extension NSFont {
    nonisolated var italic: NSFont {
        NSFontManager.shared.convert(self, toHaveTrait: .italicFontMask)
    }
}
