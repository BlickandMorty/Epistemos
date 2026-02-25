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

nonisolated(unsafe) final class MarkdownTextStorage: NSTextStorage {
    private let backing = NSMutableAttributedString()
    var isDark: Bool = true

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
        let paraRange = str.paragraphRange(for: editedRange)

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

    // MARK: - Pre-Styled Content Loading

    /// Loads pre-styled attributed content, bypassing all custom styling.
    /// The cached NSAttributedString already has correct fonts, colors, and paragraph styles.
    /// Only notifies the layout manager of the change (via super.processEditing).
    func loadPreStyledContent(_ attrString: NSAttributedString) {
        let oldLen = backing.length
        skipAllStyling = true
        beginEditing()
        backing.setAttributedString(attrString)
        edited([.editedCharacters, .editedAttributes],
               range: NSRange(location: 0, length: oldLen),
               changeInLength: attrString.length - oldLen)
        endEditing()
        skipAllStyling = false
    }

    // MARK: - Base Style

    func applyBaseStyle(range: NSRange) {
        guard range.location + range.length <= backing.length else { return }
        let baseFont = NSFont.systemFont(ofSize: baseFontSize)
        let baseColor: NSColor = isDark ? .white.withAlphaComponent(0.88) : NSColor(white: 0.1, alpha: 1)
        backing.setAttributes([
            .font: baseFont,
            .foregroundColor: baseColor,
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
                    let codeBg: NSColor = isDark
                        ? NSColor.white.withAlphaComponent(0.04)
                        : NSColor.black.withAlphaComponent(0.03)
                    backing.addAttributes([
                        .foregroundColor: codeColor,
                        .backgroundColor: codeBg,
                        .paragraphStyle: Self.codeBlockStyle
                    ], range: styleRange)
                }
            } else {
                applyLineStyle(line: line, range: styleRange)
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
        let accentColor = Self.accentColor(isDark: isDark)
        let mutedColor = Self.mutedColor(isDark: isDark)

        if t.hasPrefix("# ") && !t.hasPrefix("## ") {
            backing.addAttributes([
                .font: NSFont.systemFont(ofSize: baseFontSize + 31, weight: .bold),
                .foregroundColor: isDark ? NSColor.white : NSColor(white: 0.05, alpha: 1),
                .paragraphStyle: Self.h1Style
            ], range: range)
            // Ulysses-style: override # prefix with tiny font + muted color
            dimH1Prefix(in: line, lineStart: range.location)

        } else if t.hasPrefix("## ") && !t.hasPrefix("### ") {
            backing.addAttributes([
                .font: NSFont.systemFont(ofSize: baseFontSize + 5, weight: .bold),
                .foregroundColor: isDark ? NSColor.white : NSColor(white: 0.08, alpha: 1),
                .paragraphStyle: Self.h2Style
            ], range: range)
            dimPrefix(in: line, prefix: "## ", lineStart: range.location, color: mutedColor)

        } else if t.hasPrefix("### ") && !t.hasPrefix("#### ") {
            backing.addAttributes([
                .font: NSFont.systemFont(ofSize: baseFontSize + 1, weight: .semibold),
                .foregroundColor: isDark ? NSColor.white : NSColor(white: 0.1, alpha: 1),
                .paragraphStyle: Self.h3Style
            ], range: range)
            dimPrefix(in: line, prefix: "### ", lineStart: range.location, color: mutedColor)

        } else if t.hasPrefix("#### ") && !t.hasPrefix("##### ") {
            backing.addAttributes([
                .font: NSFont.systemFont(ofSize: baseFontSize, weight: .semibold),
                .foregroundColor: isDark ? NSColor.white : NSColor(white: 0.12, alpha: 1),
                .paragraphStyle: Self.h4Style
            ], range: range)
            dimPrefix(in: line, prefix: "#### ", lineStart: range.location, color: mutedColor)

        } else if t.hasPrefix("##### ") {
            backing.addAttributes([
                .font: NSFont.systemFont(ofSize: smallSize, weight: .medium),
                .foregroundColor: isDark ? NSColor.white.withAlphaComponent(0.9) : NSColor(white: 0.15, alpha: 1),
                .paragraphStyle: Self.h5Style
            ], range: range)
            dimPrefix(in: line, prefix: "##### ", lineStart: range.location, color: mutedColor)

        } else if t.hasPrefix("```") {
            // Fenced code block delimiter — dimmed, body font (no monospaced change)
            backing.addAttributes([
                .foregroundColor: mutedColor
            ], range: range)

        } else if t.hasPrefix("- [x] ") || t.hasPrefix("- [ ] ") {
            let checked = t.hasPrefix("- [x] ")
            var attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: baseFontSize),
                .foregroundColor: checked ? mutedColor : (isDark ? NSColor.white.withAlphaComponent(0.88) : NSColor(white: 0.1, alpha: 1))
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

        } else if t.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
            backing.addAttributes([
                .font: NSFont.systemFont(ofSize: baseFontSize),
                .paragraphStyle: Self.listStyle
            ], range: range)
            if let numRange = t.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let offset = t.distance(from: t.startIndex, to: numRange.upperBound)
                let prefixOffset = line.distance(from: line.startIndex,
                    to: line.firstIndex(where: { !$0.isWhitespace }) ?? line.startIndex)
                let dimRange = NSRange(location: range.location + prefixOffset, length: offset)
                if dimRange.location + dimRange.length <= backing.length {
                    backing.addAttributes([.foregroundColor: accentColor], range: dimRange)
                }
            }

        } else if t.hasPrefix("> [!") {
            backing.addAttributes([
                .font: NSFont.systemFont(ofSize: baseFontSize),
                .foregroundColor: isDark ? accentColor.withAlphaComponent(0.9) : accentColor
            ], range: range)
            let calloutPrefix: String
            if let bracketEnd = t.range(of: "] ") {
                calloutPrefix = String(t[t.startIndex..<bracketEnd.upperBound])
            } else {
                calloutPrefix = "> "
            }
            dimPrefix(in: line, prefix: calloutPrefix, lineStart: range.location, color: mutedColor)

        } else if t.hasPrefix("> ") {
            backing.addAttributes([
                .font: NSFont.systemFont(ofSize: baseFontSize).italic,
                .foregroundColor: isDark ? NSColor.white.withAlphaComponent(0.55) : NSColor(white: 0.4, alpha: 1)
            ], range: range)
            dimPrefix(in: line, prefix: "> ", lineStart: range.location, color: mutedColor)

        } else if t == "---" || t == "***" {
            backing.addAttributes([
                .foregroundColor: mutedColor,
                .font: NSFont.systemFont(ofSize: codeSize)
            ], range: range)

        } else if t.hasPrefix("$$") || (t.hasPrefix("$") && t.hasSuffix("$") && t.count > 2
                && !t.dropFirst().dropLast().allSatisfy({ $0.isNumber || $0 == "," || $0 == "." })) {
            backing.addAttributes([
                .font: NSFont(name: "NewYork-RegularItalic", size: baseFontSize) ?? NSFont.systemFont(ofSize: baseFontSize).italic,
                .foregroundColor: isDark ? accentColor.withAlphaComponent(0.85) : accentColor.withAlphaComponent(0.9)
            ], range: range)
            let lineStr = (backing.string as NSString).substring(with: range)
            for (offset, ch) in lineStr.utf16.enumerated() where ch == 0x24 /* $ */ {
                let dollarRange = NSRange(location: range.location + offset, length: 1)
                if dollarRange.location + dollarRange.length <= backing.length {
                    backing.addAttributes([.foregroundColor: mutedColor], range: dollarRange)
                }
            }

        } else if t.hasPrefix("|") && t.hasSuffix("|") {
            // Table row — styled with background colors instead of custom draw().
            // Monospaced font kept for pipe alignment; backgrounds replace grid borders.
            let lineStr = (backing.string as NSString).substring(with: range)
            let isSepRow = lineStr.trimmingCharacters(in: .whitespaces)
                .dropFirst().dropLast()
                .split(separator: "|", omittingEmptySubsequences: false)
                .allSatisfy { $0.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" } }

            let headerBg: NSColor = isDark
                ? NSColor.white.withAlphaComponent(0.07)
                : NSColor.black.withAlphaComponent(0.05)
            let dataBg: NSColor = isDark
                ? NSColor.white.withAlphaComponent(0.03)
                : NSColor.black.withAlphaComponent(0.02)

            if isSepRow {
                // Separator row (| --- | --- |): fully muted, tight spacing
                backing.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: codeSize, weight: .regular),
                    .foregroundColor: mutedColor,
                    .paragraphStyle: Self.tableStyle
                ], range: range)
            } else {
                let str = backing.string as NSString
                let isHeader = Self.isTableHeader(at: range, in: str)

                if isHeader {
                    backing.addAttributes([
                        .font: NSFont.monospacedSystemFont(ofSize: codeSize, weight: .bold),
                        .foregroundColor: isDark ? NSColor.white : NSColor(white: 0.05, alpha: 1),
                        .backgroundColor: headerBg,
                        .paragraphStyle: Self.tableStyle
                    ], range: range)
                } else {
                    backing.addAttributes([
                        .font: NSFont.monospacedSystemFont(ofSize: codeSize, weight: .regular),
                        .foregroundColor: isDark ? NSColor.white.withAlphaComponent(0.85) : NSColor(white: 0.15, alpha: 1),
                        .backgroundColor: dataBg,
                        .paragraphStyle: Self.tableStyle
                    ], range: range)
                }

                // Dim pipe characters in header and data rows
                for (offset, ch) in lineStr.utf16.enumerated() where ch == 0x7C /* | */ {
                    let pipeRange = NSRange(location: range.location + offset, length: 1)
                    if pipeRange.location + pipeRange.length <= backing.length {
                        backing.addAttributes([.foregroundColor: mutedColor], range: pipeRange)
                    }
                }
            }
        }
        // Empty lines: no special styling. They inherit base font/style from applyBaseStyle().
        // Setting a different font size on empty lines triggers NSLayoutManager to re-flow
        // the entire document (line height changed) on every keystroke.
    }

    // MARK: - Inline Styles (bold, italic, code, [[links]], inline math)

    // Pre-compiled regexes — static constants avoid re-compiling on every keystroke.
    // SAFETY: All `try!` below use hardcoded literal patterns validated at development time.
    // NSRegularExpression.init only throws for invalid regex syntax, never for valid literals.
    private static let boldRegex = try! NSRegularExpression(pattern: #"\*\*(.+?)\*\*|__(.+?)__"#)
    private static let italicRegex = try! NSRegularExpression(pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)|(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#)
    private static let strikethroughRegex = try! NSRegularExpression(pattern: #"~~(.+?)~~"#)
    private static let codeRegex = try! NSRegularExpression(pattern: #"`([^`]+)`"#)
    private static let linkRegex = try! NSRegularExpression(pattern: #"\[\[([^\]]+)\]\]"#)
    private static let mdLinkRegex = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#)
    private static let inlineMathRegex = try! NSRegularExpression(pattern: #"(?<!\$)\$(?!\$)(.+?)(?<!\$)\$(?!\$)"#)

    func applyInlineStyles(fullRange: NSRange) {
        let str = backing.string
        let accentColor = Self.accentColor(isDark: isDark)
        let mutedColor = Self.mutedColor(isDark: isDark)

        // Bold: **text** or __text__ — markers nearly invisible
        let ghostMarker: [NSAttributedString.Key: Any] = [
            .foregroundColor: isDark
                ? NSColor.white.withAlphaComponent(0.15)
                : NSColor.black.withAlphaComponent(0.12)
        ]
        applyRegexStyle(
            regex: Self.boldRegex, in: str, range: fullRange,
            markerAttrs: ghostMarker,
            contentAttrs: [.font: NSFont.systemFont(ofSize: baseFontSize, weight: .bold)]
        )

        // Italic: *text* or _text_ — markers nearly invisible
        applyRegexStyle(
            regex: Self.italicRegex, in: str, range: fullRange,
            markerAttrs: ghostMarker,
            contentAttrs: [.font: NSFont.systemFont(ofSize: baseFontSize).italic]
        )

        // Strikethrough: ~~text~~ — markers ghost, content softly faded
        let strikeMatches = Self.strikethroughRegex.matches(in: str, range: fullRange)
        for match in strikeMatches {
            let full = match.range
            guard full.location + full.length <= backing.length else { continue }
            backing.addAttributes(ghostMarker, range: full)
            let content = match.range(at: 1)
            if content.location != NSNotFound {
                backing.addAttributes([
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: mutedColor
                ], range: content)
            }
        }

        // Inline highlight: `text` — warm accent pill, body font.
        // Feels like a highlighted keyword/concept, not a code snippet.
        let highlightColor: NSColor = isDark
            ? NSColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1)
            : NSColor(red: 0.62, green: 0.40, blue: 0.10, alpha: 1)
        let highlightBg: NSColor = isDark
            ? NSColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 0.08)
            : NSColor(red: 0.90, green: 0.72, blue: 0.30, alpha: 0.12)
        applyRegexStyle(
            regex: Self.codeRegex, in: str, range: fullRange,
            markerAttrs: [
                .foregroundColor: isDark
                    ? NSColor.white.withAlphaComponent(0.15)
                    : NSColor.black.withAlphaComponent(0.12)
            ],
            contentAttrs: [
                .font: NSFont.systemFont(ofSize: baseFontSize, weight: .medium),
                .foregroundColor: highlightColor,
                .backgroundColor: highlightBg
            ]
        )

        // [[wikilinks]] — brackets ghosted, content is a clean clickable link
        let linkMatches = Self.linkRegex.matches(in: str, range: fullRange)
        for match in linkMatches {
            let fullMatchRange = match.range
            guard fullMatchRange.location + fullMatchRange.length <= backing.length else { continue }

            backing.addAttributes(ghostMarker, range: fullMatchRange)

            let contentRange = match.range(at: 1)
            if contentRange.location != NSNotFound {
                let linkTitle = (str as NSString).substring(with: contentRange)
                backing.addAttributes([
                    .foregroundColor: accentColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .cursor: NSCursor.pointingHand,
                    .init("EpistemosWikilink"): linkTitle
                ], range: contentRange)
            }
        }

        // Markdown links: [text](url) — syntax ghosted, link text stands out
        let mdLinkMatches = Self.mdLinkRegex.matches(in: str, range: fullRange)
        for match in mdLinkMatches {
            let full = match.range
            guard full.location + full.length <= backing.length else { continue }
            backing.addAttributes(ghostMarker, range: full)
            // Highlight link text
            let textRange = match.range(at: 1)
            if textRange.location != NSNotFound {
                backing.addAttributes([
                    .foregroundColor: accentColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ], range: textRange)
            }
        }

        // Inline math: $expr$
        applyRegexStyle(
            regex: Self.inlineMathRegex, in: str, range: fullRange,
            markerAttrs: [.foregroundColor: mutedColor],
            contentAttrs: [
                .font: NSFont(name: "NewYork-RegularItalic", size: smallSize) ?? NSFont.systemFont(ofSize: smallSize).italic,
                .foregroundColor: accentColor
            ]
        )
    }

    private func applyRegexStyle(
        regex: NSRegularExpression,
        in str: String,
        range: NSRange,
        markerAttrs: [NSAttributedString.Key: Any],
        contentAttrs: [NSAttributedString.Key: Any]
    ) {
        let matches = regex.matches(in: str, range: range)
        for match in matches {
            let fullRange = match.range
            guard fullRange.location + fullRange.length <= backing.length else { continue }

            var contentRange: NSRange?
            for g in 1..<match.numberOfRanges {
                let r = match.range(at: g)
                if r.location != NSNotFound { contentRange = r; break }
            }

            backing.addAttributes(markerAttrs, range: fullRange)
            if let cr = contentRange {
                backing.addAttributes(contentAttrs, range: cr)
            }
        }
    }

    // MARK: - Helpers

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
            .foregroundColor: Self.mutedColor(isDark: isDark).withAlphaComponent(0.5),
            .font: NSFont.systemFont(ofSize: max(baseFontSize - 5, 9), weight: .regular)
        ], range: dimRange)
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
    private nonisolated(unsafe) static let codeBlockStyle: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 3
        ps.paragraphSpacing = 0
        ps.paragraphSpacingBefore = 0
        ps.headIndent = 16
        ps.firstLineHeadIndent = 16
        return ps.copy() as! NSParagraphStyle
    }()

    private nonisolated(unsafe) static let bodyStyle: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 5
        ps.paragraphSpacing = 2
        ps.paragraphSpacingBefore = 0
        return ps.copy() as! NSParagraphStyle
    }()

    private nonisolated(unsafe) static let h1Style: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.paragraphSpacingBefore = 30   // Balanced with textContainerInset (54pt top)
        ps.paragraphSpacing = 4          // Tight gap below title to body text
        ps.lineSpacing = 0
        return ps.copy() as! NSParagraphStyle
    }()

    private nonisolated(unsafe) static let h2Style: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.paragraphSpacingBefore = 12
        ps.paragraphSpacing = 2
        ps.lineSpacing = 2
        return ps.copy() as! NSParagraphStyle
    }()

    private nonisolated(unsafe) static let h3Style: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.paragraphSpacingBefore = 8
        ps.paragraphSpacing = 2
        ps.lineSpacing = 2
        return ps.copy() as! NSParagraphStyle
    }()

    private nonisolated(unsafe) static let h4Style: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.paragraphSpacingBefore = 6
        ps.paragraphSpacing = 2
        ps.lineSpacing = 2
        return ps.copy() as! NSParagraphStyle
    }()

    private nonisolated(unsafe) static let h5Style: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.paragraphSpacingBefore = 4
        ps.paragraphSpacing = 2
        ps.lineSpacing = 2
        return ps.copy() as! NSParagraphStyle
    }()

    private nonisolated(unsafe) static let listStyle: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 3
        ps.paragraphSpacing = 1
        ps.headIndent = 16
        return ps.copy() as! NSParagraphStyle
    }()

    /// Tight vertical spacing for table rows — keeps rows visually grouped.
    private nonisolated(unsafe) static let tableStyle: NSParagraphStyle = {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 2
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
