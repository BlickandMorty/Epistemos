import AppKit

// MARK: - MarkdownContentStorage
// NSTextContentStorageDelegate for TextKit 2 prose editor.
// Classifies each paragraph via Rust FFI markdown_parse_structure(),
// returns styled NSTextParagraph instances for the element tree.
//
// Phase 1: structural styling only (heading fonts, code monospace, list indent).
// No inline styling, no marker collapsing — those are Phases 2-3.

final class MarkdownContentStorage: NSObject, NSTextContentStorageDelegate {

    // Cached structure: one entry per line, indexed by line number.
    private var cachedTypes: [(paraType: UInt8, metadata: UInt16)] = []
    // UTF-16 offset of each line start, for O(log n) line index lookup.
    private var lineStarts: [Int] = [0]
    private var isDirty = true

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
        for i in 0..<nsString.length {
            if nsString.character(at: i) == 0x0A { // '\n'
                lineStarts.append(i + 1)
            }
        }
    }

    /// Binary search: UTF-16 offset → line index.
    private func lineIndex(at utf16Offset: Int) -> Int {
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
}
