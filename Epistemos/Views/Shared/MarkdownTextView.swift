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
    nonisolated static func foregroundHex(for theme: EpistemosTheme, level: Int) -> UInt32 {
        guard (1...3).contains(level) else { return theme.foregroundHex }
        if theme == .platinum && level == 1 {
            return theme.headingAccentHex
        }
        return theme.markdownHeadingAccentHex
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

struct MarkdownTextView: View {
    let content: String
    let theme: EpistemosTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code block
            if trimmed.hasPrefix("```") {
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
                blocks.append(.heading(level: 5, text: String(trimmed.dropFirst(6))))
            } else if trimmed.hasPrefix("#### ") && !trimmed.hasPrefix("##### ") {
                blocks.append(.heading(level: 4, text: String(trimmed.dropFirst(5))))
            } else if trimmed.hasPrefix("### ") && !trimmed.hasPrefix("#### ") {
                blocks.append(.heading(level: 3, text: String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("## ") && !trimmed.hasPrefix("### ") {
                blocks.append(.heading(level: 2, text: String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
                blocks.append(.heading(level: 1, text: String(trimmed.dropFirst(2))))
            }
            // Horizontal rule
            else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.horizontalRule)
            }
            // Checkbox
            else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [ ] ") {
                let checked = trimmed.hasPrefix("- [x] ")
                blocks.append(.checkItem(checked: checked, text: String(trimmed.dropFirst(6))))
            }
            // Bullet list
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                blocks.append(.bulletItem(text: String(trimmed.dropFirst(2))))
            }
            // Numbered list
            else if let match = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                let number = String(trimmed[trimmed.startIndex..<match.upperBound]).trimmingCharacters(in: .whitespaces)
                let rest = String(trimmed[match.upperBound...])
                blocks.append(.numberedItem(number: number, text: rest))
            }
            // Blockquote
            else if trimmed.hasPrefix("> ") {
                blocks.append(.blockquote(text: String(trimmed.dropFirst(2))))
            }
            // Table
            else if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                blocks.append(.tableLine(text: trimmed))
            }
            // Paragraph (skip empty lines)
            else if !trimmed.isEmpty {
                blocks.append(.paragraph(text: line))
            }

            i += 1
        }

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
            inlineMarkdown(text, baseFontSize: 15)
                .font(.system(size: 15))
                .foregroundStyle(theme.foreground)
                .padding(.vertical, 2)
        case .bulletItem(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\u{2022}")
                    .foregroundStyle(theme.accent)
                inlineMarkdown(text, baseFontSize: 15)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.foreground)
            }
            .padding(.leading, 16)
            .padding(.vertical, 3)
        case .numberedItem(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(number)
                    .font(.system(size: 15).monospacedDigit())
                    .foregroundStyle(theme.accent)
                inlineMarkdown(text, baseFontSize: 15)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.foreground)
            }
            .padding(.leading, 16)
            .padding(.vertical, 3)
        case .checkItem(let checked, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13))
                    .foregroundStyle(checked ? theme.accent : theme.textTertiary)
                inlineMarkdown(text, baseFontSize: 15)
                    .font(.system(size: 15))
                    .foregroundStyle(checked ? theme.textTertiary : theme.foreground)
                    .strikethrough(checked)
            }
            .padding(.leading, 16)
            .padding(.vertical, 3)
        case .blockquote(let text):
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(theme.accent.opacity(0.5))
                    .frame(width: 3)
                inlineMarkdown(text, baseFontSize: 15)
                    .font(.system(size: 15))
                    .italic()
                    .foregroundStyle(theme.textSecondary)
                    .padding(.leading, 12)
            }
            .padding(.vertical, 4)
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
            .padding(.vertical, 4)
        case .horizontalRule:
            Divider()
                .padding(.vertical, 8)
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
        let font: Font = retroRole?.font ?? {
            switch level {
            case 4: .system(size: 15, weight: .medium)
            default: .system(size: 14, weight: .medium)
            }
        }()
        let fontSize: CGFloat = retroRole?.fontSize ?? (level == 4 ? 15 : 14)
        let topPad = retroRole?.topPadding ?? 6
        let color = MarkdownHeadingDisplay.foregroundColor(for: theme, level: level)
        let displayText = MarkdownHeadingDisplay.displayText(text, level: level)

        inlineMarkdown(displayText, baseFontSize: fontSize)
            .font(font)
            .foregroundStyle(color)
            .shadow(
                color: MarkdownHeadingDisplay.swiftUIShadowColor(for: theme, level: level),
                radius: MarkdownHeadingDisplay.glowRadius(for: level)
            )
            .padding(.top, topPad)
            .padding(.bottom, 2)
    }

    // MARK: - Table Rendering

    @ViewBuilder
    private func renderTable(rows: [[String]], headerCount: Int) -> some View {
        let borderColor = theme.isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.12)
        let headerBg = theme.isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
        let altRowBg = theme.isDark ? Color.white.opacity(0.02) : Color.black.opacity(0.02)
        let colCount = rows.map(\.count).max() ?? 1

        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, cells in
                HStack(spacing: 0) {
                    ForEach(0..<colCount, id: \.self) { colIdx in
                        let cell = colIdx < cells.count ? cells[colIdx] : ""
                        inlineMarkdown(cell, baseFontSize: 13)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.foreground.opacity(rowIdx < headerCount ? 1.0 : 0.85))
                            .fontWeight(rowIdx < headerCount ? .semibold : .regular)
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
                    rowIdx < headerCount ? headerBg :
                    rowIdx % 2 != 0 ? altRowBg : Color.clear
                )

                if rowIdx < rows.count - 1 {
                    Rectangle()
                        .fill(borderColor)
                        .frame(height: rowIdx < headerCount ? 1.5 : 0.5)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .padding(.vertical, 6)
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
