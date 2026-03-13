import AppKit
import SwiftUI

// MARK: - MarkdownTextView
// Renders markdown content as formatted SwiftUI Text for chat messages.
// Uses SwiftUI's native AttributedString markdown parsing for inline styles
// (bold, italic, code, links, strikethrough) and custom line-level parsing
// for headings, lists, code blocks, blockquotes, and tables.
//
// Read-only — no editing. Used for AI assistant responses in chat bubbles.
// For the editable notes editor, see MarkdownTextStorage + ProseEditorRepresentable.

enum MarkdownHeadingDisplay {
    private static let h1FullSizeCharacterLimit = 28
    private static let h1MediumSizeCharacterLimit = 60
    private static let h1LongSizeCharacterLimit = 90

    nonisolated static func foregroundHex(for theme: EpistemosTheme, level: Int) -> UInt32 {
        guard (1...3).contains(level) else { return theme.foregroundHex }
        if theme == .platinum && level == 1 {
            return theme.headingAccentHex
        }
        return theme.markdownHeadingAccentHex
    }

    nonisolated static func fontSize(
        for level: Int,
        text: String,
        baseSize: CGFloat,
        nextLevelSize: CGFloat
    ) -> CGFloat {
        guard level == 1 else { return baseSize }

        let minimumSize = min(baseSize, max(baseSize - 3, nextLevelSize + 2))
        let characterCount = normalizedHeadingText(text, level: level).count

        switch characterCount {
        case ...h1FullSizeCharacterLimit:
            return baseSize
        case ...h1MediumSizeCharacterLimit:
            return max(baseSize - 1, minimumSize)
        case ...h1LongSizeCharacterLimit:
            return max(baseSize - 2, minimumSize)
        default:
            return minimumSize
        }
    }

    static func displayText(_ text: String, level: Int) -> String {
        guard (1...3).contains(level) else { return text }
        return sameLengthUppercase(text)
    }

    static func foregroundColor(for theme: EpistemosTheme, level: Int) -> Color {
        Color(hex: foregroundHex(for: theme, level: level))
    }

    static func glowRadius(for level: Int) -> CGFloat {
        level == 1 ? 8 : 0
    }

    static func swiftUIShadowColor(for theme: EpistemosTheme, level: Int) -> Color {
        guard level == 1 else { return .clear }
        return foregroundColor(for: theme, level: level).opacity(theme.isDark ? 0.18 : 0.10)
    }

    static func nsShadow(for theme: EpistemosTheme, level: Int) -> NSShadow? {
        guard level == 1 else { return nil }
        let shadow = NSShadow()
        shadow.shadowBlurRadius = glowRadius(for: level)
        shadow.shadowOffset = .zero
        shadow.shadowColor = NSColor(foregroundColor(for: theme, level: level)).withAlphaComponent(
            theme.isDark ? 0.18 : 0.10
        )
        return shadow
    }

    private nonisolated static func normalizedHeadingText(_ text: String, level: Int) -> Substring {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = String(repeating: "#", count: level) + " "
        guard trimmed.hasPrefix(prefix) else { return Substring(trimmed) }
        return trimmed.dropFirst(prefix.count)
    }

    private static func sameLengthUppercase(_ text: String) -> String {
        var transformed = String()
        transformed.reserveCapacity(text.count)

        for character in text {
            let original = String(character)
            let uppercased = original.uppercased()
            if uppercased.utf16.count == original.utf16.count {
                transformed.append(contentsOf: uppercased)
            } else {
                transformed.append(character)
            }
        }

        return transformed
    }
}

struct MarkdownTableModel: Equatable {
    let rows: [[String]]
    let headerCount: Int

    static func parse(_ block: String) -> Self? {
        let lines = block
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !lines.isEmpty else { return nil }

        var rows: [[String]] = []
        var headerCount = 0
        var foundSeparator = false

        for line in lines {
            guard line.hasPrefix("|"), line.hasSuffix("|"), line.count >= 3 else {
                return nil
            }

            let cells = line
                .dropFirst()
                .dropLast()
                .split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            let isSeparator = cells.allSatisfy { cell in
                cell.allSatisfy { $0 == "-" || $0 == ":" }
            }
            if isSeparator {
                if !foundSeparator {
                    headerCount = rows.count
                }
                foundSeparator = true
                continue
            }

            rows.append(cells)
        }

        guard !rows.isEmpty else { return nil }
        return Self(rows: rows, headerCount: max(headerCount, 1))
    }
}

enum MarkdownTableBlockRanges {
    static func ranges(in text: NSString, intersecting visibleRange: NSRange? = nil) -> [NSRange] {
        guard text.length > 0 else { return [] }

        let fullRange = NSRange(location: 0, length: text.length)
        let scanRange = visibleRange.map { NSIntersectionRange(fullRange, $0) } ?? fullRange
        guard scanRange.length > 0 else { return [] }

        let firstLocation = min(scanRange.location, max(0, text.length - 1))
        var cursor = text.lineRange(for: NSRange(location: firstLocation, length: 0)).location
        let scanEnd = min(text.length, NSMaxRange(scanRange))
        var tableRanges: [NSRange] = []

        while cursor < scanEnd {
            let lineRange = text.lineRange(for: NSRange(location: cursor, length: 0))
            let trimmedLine = text.substring(with: lineRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard isTableLine(trimmedLine) else {
                cursor = NSMaxRange(lineRange)
                continue
            }

            let tableRange = expandedRange(in: text, from: lineRange)
            if tableRanges.last != tableRange {
                tableRanges.append(tableRange)
            }
            cursor = NSMaxRange(tableRange)
        }

        return tableRanges
    }

    private static func expandedRange(in text: NSString, from seedRange: NSRange) -> NSRange {
        var start = seedRange.location
        var end = NSMaxRange(seedRange)

        while start > 0 {
            let previousRange = text.lineRange(for: NSRange(location: start - 1, length: 0))
            let previousLine = text.substring(with: previousRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard isTableLine(previousLine) else { break }
            start = previousRange.location
        }

        while end < text.length {
            let nextRange = text.lineRange(for: NSRange(location: end, length: 0))
            let nextLine = text.substring(with: nextRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard isTableLine(nextLine) else { break }
            end = NSMaxRange(nextRange)
        }

        return NSRange(location: start, length: end - start)
    }

    private static func isTableLine(_ line: String) -> Bool {
        line.hasPrefix("|") && line.hasSuffix("|") && line.count >= 3
    }
}

@MainActor
final class NoteEditorRenderedTableHostingView: NSHostingView<NoteEditorRenderedTableView> {
    init(table: MarkdownTableModel, theme: EpistemosTheme) {
        super.init(rootView: NoteEditorRenderedTableView(table: table, theme: theme))
        translatesAutoresizingMaskIntoConstraints = true
    }

    required init(rootView: NoteEditorRenderedTableView) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override var acceptsFirstResponder: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? { self }

    override func mouseDown(with event: NSEvent) {}

    override func mouseDragged(with event: NSEvent) {}

    override func rightMouseDown(with event: NSEvent) {}

    override func otherMouseDown(with event: NSEvent) {}

    override func scrollWheel(with event: NSEvent) {
        if let scrollView = enclosingScrollView {
            scrollView.scrollWheel(with: event)
            return
        }
        super.scrollWheel(with: event)
    }

    func update(table: MarkdownTableModel, theme: EpistemosTheme, frame: NSRect) {
        rootView = NoteEditorRenderedTableView(table: table, theme: theme)
        self.frame = frame
    }
}

struct MarkdownTableSurfaceView<CellContent: View>: View {
    let table: MarkdownTableModel
    let theme: EpistemosTheme
    var verticalPadding: CGFloat = 6
    var containerFill: Color = .clear
    var bodyRowBackground: Color = .clear
    let cellContent: (String, Bool) -> CellContent

    var body: some View {
        let borderColor = theme.isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.12)
        let headerBg = theme.isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
        let altRowBg = theme.isDark ? Color.white.opacity(0.02) : Color.black.opacity(0.02)
        let colCount = table.rows.map(\.count).max() ?? 1

        VStack(spacing: 0) {
            ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIdx, cells in
                let isHeader = rowIdx < table.headerCount
                HStack(spacing: 0) {
                    ForEach(0..<colCount, id: \.self) { colIdx in
                        let cell = colIdx < cells.count ? cells[colIdx] : ""
                        cellContent(cell, isHeader)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(alignment: .trailing) {
                                if colIdx < colCount - 1 {
                                    Rectangle().fill(borderColor).frame(width: 1)
                                }
                            }
                    }
                }
                .background(
                    isHeader ? headerBg :
                    rowIdx % 2 != 0 ? altRowBg : bodyRowBackground
                )

                if rowIdx < table.rows.count - 1 {
                    Rectangle()
                        .fill(borderColor)
                        .frame(height: isHeader ? 1.5 : 0.5)
                }
            }
        }
        .background(
            containerFill,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .padding(.vertical, verticalPadding)
    }
}

struct NoteEditorRenderedTableView: View {
    let table: MarkdownTableModel
    let theme: EpistemosTheme

    private var containerFill: Color {
        theme.background.opacity(theme.isDark ? 0.96 : 0.98)
    }

    var body: some View {
        GeometryReader { proxy in
            MarkdownTableSurfaceView(
                table: table,
                theme: theme,
                verticalPadding: 0,
                containerFill: containerFill,
                bodyRowBackground: containerFill
            ) { cell, isHeader in
                InlineMarkdownStyler.text(
                    cell,
                    strongFontSize: 13,
                    strongForegroundColor: nil,
                    linkForegroundColor: theme.preferredMarkdownLinkColor
                )
                .font(.system(size: 13))
                .foregroundStyle(isHeader ? theme.foreground : theme.foreground.opacity(0.9))
                .fontWeight(isHeader ? .semibold : .regular)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }
}

struct MarkdownTextView: View {
    let content: String
    let theme: EpistemosTheme

    private enum PreviewTypography {
        static let bodyFontSize: CGFloat = 16
        static let bodyLineSpacing: CGFloat = 6
        static let blockSpacing: CGFloat = 14
        static let listIndent: CGFloat = 18
        static let markerTopPadding: CGFloat = 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PreviewTypography.blockSpacing) {
            let blocks = mergeTableBlocks(parseBlocks(content))
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
        .textSelection(.enabled)
    }

    // MARK: - Block Types

    private enum MarkdownBlock {
        case heading(level: Int, text: String)
        case paragraph(text: String)
        case bulletItem(text: String)
        case numberedItem(number: String, text: String)
        case checkItem(checked: Bool, text: String)
        case blockquote(text: String)
        case codeBlock(language: String, code: String)
        case horizontalRule
        case tableLine(text: String)
        case table(rows: [[String]], headerCount: Int)
    }

    // MARK: - Block Parsing

    private func parseBlocks(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        var paragraphLines: [String] = []

        func flushParagraph() {
            let paragraph = paragraphLines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !paragraph.isEmpty {
                blocks.append(.paragraph(text: paragraph))
            }
            paragraphLines.removeAll(keepingCapacity: true)
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flushParagraph()
                i += 1
                continue
            }

            // Fenced code block
            if trimmed.hasPrefix("```") {
                flushParagraph()
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count {
                    let codeLine = lines[i]
                    if codeLine.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        i += 1
                        break
                    }
                    codeLines.append(codeLine)
                    i += 1
                }
                blocks.append(.codeBlock(language: lang, code: codeLines.joined(separator: "\n")))
                continue
            }

            // Headings
            if trimmed.hasPrefix("##### ") {
                flushParagraph()
                blocks.append(.heading(level: 5, text: String(trimmed.dropFirst(6))))
            } else if trimmed.hasPrefix("#### ") && !trimmed.hasPrefix("##### ") {
                flushParagraph()
                blocks.append(.heading(level: 4, text: String(trimmed.dropFirst(5))))
            } else if trimmed.hasPrefix("### ") && !trimmed.hasPrefix("#### ") {
                flushParagraph()
                blocks.append(.heading(level: 3, text: String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("## ") && !trimmed.hasPrefix("### ") {
                flushParagraph()
                blocks.append(.heading(level: 2, text: String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
                flushParagraph()
                blocks.append(.heading(level: 1, text: String(trimmed.dropFirst(2))))
            }
            // Horizontal rule
            else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                blocks.append(.horizontalRule)
            }
            // Checkbox
            else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [ ] ") {
                flushParagraph()
                let checked = trimmed.hasPrefix("- [x] ")
                blocks.append(.checkItem(checked: checked, text: String(trimmed.dropFirst(6))))
            }
            // Bullet list
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushParagraph()
                blocks.append(.bulletItem(text: String(trimmed.dropFirst(2))))
            }
            // Numbered list
            else if let match = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                flushParagraph()
                let number = String(trimmed[trimmed.startIndex..<match.upperBound]).trimmingCharacters(in: .whitespaces)
                let rest = String(trimmed[match.upperBound...])
                blocks.append(.numberedItem(number: number, text: rest))
            }
            // Blockquote
            else if trimmed.hasPrefix("> ") {
                flushParagraph()
                blocks.append(.blockquote(text: String(trimmed.dropFirst(2))))
            }
            // Table
            else if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                flushParagraph()
                blocks.append(.tableLine(text: trimmed))
            }
            // Paragraph
            else {
                paragraphLines.append(line)
            }

            i += 1
        }

        flushParagraph()
        return blocks
    }

    // MARK: - Table Merging

    /// Post-processes parsed blocks to merge consecutive `.tableLine` entries
    /// into a single `.table` block with structured rows and header detection.
    private func mergeTableBlocks(_ blocks: [MarkdownBlock]) -> [MarkdownBlock] {
        var result: [MarkdownBlock] = []
        var tableLines: [String] = []

        func flushTable() {
            guard !tableLines.isEmpty else { return }
            var rows: [[String]] = []
            var headerCount = 0
            var foundSeparator = false

            for line in tableLines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let cells = trimmed.dropFirst().dropLast()
                    .split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }

                let isSep = cells.allSatisfy { $0.allSatisfy { $0 == "-" || $0 == ":" } }
                if isSep {
                    if !foundSeparator { headerCount = rows.count }
                    foundSeparator = true
                    continue
                }
                rows.append(cells)
            }

            if !rows.isEmpty {
                result.append(.table(rows: rows, headerCount: max(headerCount, 1)))
            }
            tableLines = []
        }

        for block in blocks {
            if case .tableLine(let text) = block {
                tableLines.append(text)
            } else {
                flushTable()
                result.append(block)
            }
        }
        flushTable()
        return result
    }

    // MARK: - Block Rendering

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            renderHeading(level: level, text: text)
        case .paragraph(let text):
            inlineMarkdown(text, baseFontSize: PreviewTypography.bodyFontSize)
                .font(.system(size: PreviewTypography.bodyFontSize))
                .lineSpacing(PreviewTypography.bodyLineSpacing)
                .foregroundStyle(theme.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        case .bulletItem(let text):
            HStack(alignment: .top, spacing: 10) {
                Text("\u{2022}")
                    .padding(.top, PreviewTypography.markerTopPadding)
                    .foregroundStyle(theme.accent)
                inlineMarkdown(text, baseFontSize: PreviewTypography.bodyFontSize)
                    .font(.system(size: PreviewTypography.bodyFontSize))
                    .lineSpacing(PreviewTypography.bodyLineSpacing)
                    .foregroundStyle(theme.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, PreviewTypography.listIndent)
        case .numberedItem(let number, let text):
            HStack(alignment: .top, spacing: 10) {
                Text(number)
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .padding(.top, PreviewTypography.markerTopPadding)
                    .foregroundStyle(theme.accent)
                inlineMarkdown(text, baseFontSize: PreviewTypography.bodyFontSize)
                    .font(.system(size: PreviewTypography.bodyFontSize))
                    .lineSpacing(PreviewTypography.bodyLineSpacing)
                    .foregroundStyle(theme.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, PreviewTypography.listIndent)
        case .checkItem(let checked, let text):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13))
                    .padding(.top, PreviewTypography.markerTopPadding)
                    .foregroundStyle(checked ? theme.accent : theme.textTertiary)
                inlineMarkdown(text, baseFontSize: PreviewTypography.bodyFontSize)
                    .font(.system(size: PreviewTypography.bodyFontSize))
                    .lineSpacing(PreviewTypography.bodyLineSpacing)
                    .foregroundStyle(checked ? theme.textTertiary : theme.foreground)
                    .strikethrough(checked)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, PreviewTypography.listIndent)
        case .blockquote(let text):
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(theme.accent.opacity(0.5))
                    .frame(width: 3)
                inlineMarkdown(text, baseFontSize: PreviewTypography.bodyFontSize)
                    .font(.system(size: PreviewTypography.bodyFontSize))
                    .lineSpacing(PreviewTypography.bodyLineSpacing)
                    .italic()
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        case .codeBlock(let language, let code):
            VStack(alignment: .leading, spacing: 4) {
                if !language.isEmpty {
                    Text(language)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                }
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(theme.isDark
                        ? Color.white.opacity(0.75)
                        : Color(red: 0.2, green: 0.2, blue: 0.2))
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, language.isEmpty ? 10 : 4)
                    .padding(.bottom, language.isEmpty ? 0 : 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                theme.isDark
                    ? Color.white.opacity(0.05)
                    : Color.black.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        case .horizontalRule:
            Divider()
                .padding(.vertical, 2)
        case .table(let rows, let headerCount):
            renderTable(rows: rows, headerCount: headerCount)
        case .tableLine:
            EmptyView()
        }
    }

    // MARK: - Heading Rendering

    @ViewBuilder
    private func renderHeading(level: Int, text: String) -> some View {
        let retroRole = AppHeadingRole.markdownRole(level: level)
        let baseFontSize: CGFloat = retroRole?.fontSize ?? (level == 4 ? 15 : 14)
        let fontSize = MarkdownHeadingDisplay.fontSize(
            for: level,
            text: text,
            baseSize: baseFontSize,
            nextLevelSize: AppHeadingRole.h2.fontSize
        )
        let font: Font = retroRole.map { _ in
            AppDisplayTypography.font(size: fontSize)
        } ?? {
            switch level {
            case 4: .system(size: 15, weight: .medium)
            default: .system(size: 14, weight: .medium)
            }
        }()
        let topPad = retroRole?.topPadding ?? 6
        let color = MarkdownHeadingDisplay.foregroundColor(for: theme, level: level)
        let displayText = MarkdownHeadingDisplay.displayText(text, level: level)

        inlineMarkdown(displayText, baseFontSize: fontSize)
            .font(font)
            .foregroundStyle(color)
            .lineSpacing(level == 1 ? 4 : 2)
            .shadow(
                color: MarkdownHeadingDisplay.swiftUIShadowColor(for: theme, level: level),
                radius: MarkdownHeadingDisplay.glowRadius(for: level)
            )
            .padding(.top, topPad)
            .padding(.bottom, level == 1 ? 8 : 4)
    }

    // MARK: - Table Rendering

    @ViewBuilder
    private func renderTable(rows: [[String]], headerCount: Int) -> some View {
        MarkdownTableSurfaceView(
            table: MarkdownTableModel(rows: rows, headerCount: headerCount),
            theme: theme
        ) { cell, isHeader in
            inlineMarkdown(cell, baseFontSize: 13)
                .font(.system(size: 13))
                .foregroundStyle(theme.foreground.opacity(isHeader ? 1.0 : 0.85))
                .fontWeight(isHeader ? .semibold : .regular)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Inline Markdown -> SwiftUI Text

    private func inlineMarkdown(_ text: String, baseFontSize: CGFloat) -> Text {
        InlineMarkdownStyler.text(
            text,
            strongFontSize: baseFontSize,
            strongForegroundColor: nil,
            linkForegroundColor: theme.preferredMarkdownLinkColor
        )
    }
}
