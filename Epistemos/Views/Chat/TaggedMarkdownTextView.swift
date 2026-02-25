import SwiftUI

// MARK: - Epistemic Tag
// Semantic inline evidence markers matching web v2 brainiac's colored badges.
// DATA (emerald), MODEL (violet), UNCERTAIN (amber), CONFLICT (coral).

enum EpistemicTag: String, CaseIterable {
    case data = "DATA"
    case model = "MODEL"
    case uncertain = "UNCERTAIN"
    case conflict = "CONFLICT"

    var color: Color {
        switch self {
        case .data:       Color(hex: 0x34D399)
        case .model:      Color(hex: 0x9B7DB8)
        case .uncertain:  Color(hex: 0xD4A843)
        case .conflict:   Color(hex: 0xC75E5E)
        }
    }

    var icon: String {
        switch self {
        case .data:       "chart.bar.doc.horizontal"
        case .model:      "cpu"
        case .uncertain:  "questionmark.diamond"
        case .conflict:   "exclamationmark.triangle"
        }
    }

    static func from(_ name: String) -> EpistemicTag? {
        allCases.first { $0.rawValue == name }
    }

    /// Map evidence tier references to semantically meaningful colors.
    /// Tier 1-2 (strong evidence) → emerald, Tier 3 → violet, Tier 4-5 (weak) → amber.
    static func colorForTier(_ tierText: String) -> Color {
        // Extract the digit from "Tier 3", "Tier 1", etc.
        let digits = tierText.filter(\.isNumber)
        guard let tierNum = Int(digits) else { return Color(hex: 0x8899AA) }
        switch tierNum {
        case 1, 2: return Color(hex: 0x34D399) // emerald — strong evidence
        case 3:    return Color(hex: 0x9B7DB8) // violet — moderate
        case 4, 5: return Color(hex: 0xD4A843) // amber — weak
        default:   return Color(hex: 0x8899AA) // slate — unknown
        }
    }

    /// Count occurrences of each tag type in text (including extended forms like [DATA - Tier 2]).
    static func counts(in text: String) -> [(tag: EpistemicTag, count: Int)] {
        allCases.compactMap { tag in
            let pattern = "\\[\(tag.rawValue)[^\\]]*\\]"
            let regex = try? NSRegularExpression(pattern: pattern)
            let count = regex?.numberOfMatches(
                in: text,
                range: NSRange(location: 0, length: (text as NSString).length)
            ) ?? 0
            return count > 0 ? (tag, count) : nil
        }
    }
}

// MARK: - Tagged Markdown Text View
// Chat-specific markdown renderer that renders [DATA]/[MODEL]/[UNCERTAIN]/[CONFLICT]
// as colored inline markers instead of stripping them.
// Used in the Lucid Lens panel's Research Analysis section.

struct TaggedMarkdownTextView: View {
    let content: String
    let theme: EpistemosTheme

    /// Matches epistemic tags with optional qualifiers:
    /// [DATA], [DATA - Tier 2], [CONFLICT], [MODEL - Framework], [UNCERTAIN - High], etc.
    // SAFETY: Hardcoded literal pattern — `try!` only fails on invalid regex syntax.
    private static let primaryTagRegex = try! NSRegularExpression(
        pattern: "\\[(DATA|CONFLICT|UNCERTAIN|MODEL)([^\\]]*)\\]"
    )

    /// Matches standalone tier references: [Tier 1], [Tier 2], [Tier 3], [Tier 4], [Tier 5].
    /// Also matches any remaining [Capitalized Word(s)] patterns the LLM produces as markers.
    // SAFETY: Hardcoded literal pattern — `try!` only fails on invalid regex syntax.
    private static let secondaryTagRegex = try! NSRegularExpression(
        pattern: "\\[(Tier\\s*\\d+)\\]"
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
                    if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        i += 1
                        break
                    }
                    codeLines.append(lines[i])
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
                        taggedInlineMarkdown(cell)
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

    // MARK: - Block Rendering

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            renderHeading(level: level, text: text)
        case .paragraph(let text):
            taggedInlineMarkdown(text)
                .font(.system(size: 15))
                .foregroundStyle(theme.foreground)
                .padding(.vertical, 5)
        case .bulletItem(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\u{2022}")
                    .foregroundStyle(theme.accent)
                taggedInlineMarkdown(text)
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
                taggedInlineMarkdown(text)
                    .font(.system(size: 15))
                    .foregroundStyle(theme.foreground)
            }
            .padding(.leading, 16)
            .padding(.vertical, 3)
        case .blockquote(let text):
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(theme.accent.opacity(0.5))
                    .frame(width: 3)
                taggedInlineMarkdown(text)
                    .font(.system(size: 15))
                    .italic()
                    .foregroundStyle(theme.textSecondary)
                    .padding(.leading, 12)
            }
            .padding(.vertical, 6)
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
            .padding(.vertical, 8)
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
        let font: Font = switch level {
        case 1: .system(size: 26, weight: .semibold)
        case 2: .system(size: 20, weight: .semibold)
        case 3: .system(size: 16, weight: .medium)
        case 4: .system(size: 15, weight: .medium)
        default: .system(size: 14, weight: .medium)
        }
        let topPad: CGFloat = switch level {
        case 1: 16
        case 2: 12
        case 3: 8
        default: 6
        }

        taggedInlineMarkdown(text)
            .font(font)
            .foregroundStyle(theme.foreground)
            .padding(.top, topPad)
            .padding(.bottom, 2)
    }

    // MARK: - Tag-Aware Inline Renderer

    /// Internal match result for unified tag rendering across primary and secondary regexes.
    private struct TagMatch: Comparable {
        let range: NSRange
        let displayText: String
        let color: Color
        static func < (lhs: TagMatch, rhs: TagMatch) -> Bool {
            lhs.range.location < rhs.range.location
        }
    }

    /// Splits text on epistemic tag boundaries — both primary ([DATA], [CONFLICT - Tier 2])
    /// and secondary ([Tier 3]) — rendering each as a colored bold monospaced marker.
    private func taggedInlineMarkdown(_ text: String) -> Text {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        var tagMatches: [TagMatch] = []

        // Primary: [DATA], [DATA - Tier 2], [CONFLICT], [MODEL - Framework], etc.
        for match in Self.primaryTagRegex.matches(in: text, range: fullRange) {
            let baseTagName = nsText.substring(with: match.range(at: 1))
            let qualifier = match.range(at: 2).location != NSNotFound
                ? nsText.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
                : ""
            let displayText = qualifier.isEmpty ? baseTagName : "\(baseTagName) \(qualifier)"
            if let tag = EpistemicTag.from(baseTagName) {
                tagMatches.append(TagMatch(range: match.range, displayText: displayText, color: tag.color))
            }
        }

        // Secondary: [Tier 1], [Tier 2], [Tier 3], [Tier 4], [Tier 5]
        for match in Self.secondaryTagRegex.matches(in: text, range: fullRange) {
            let tierText = nsText.substring(with: match.range(at: 1))
            // Skip if overlapping a primary match (e.g. [DATA - Tier 2] already claimed this range)
            let overlaps = tagMatches.contains { existing in
                NSIntersectionRange(existing.range, match.range).length > 0
            }
            guard !overlaps else { continue }
            tagMatches.append(TagMatch(
                range: match.range,
                displayText: tierText,
                color: EpistemicTag.colorForTier(tierText)
            ))
        }

        tagMatches.sort()

        // No tags → fast-path standard markdown
        guard !tagMatches.isEmpty else {
            return inlineMarkdown(text)
        }

        var result = Text("")
        var cursor = 0

        for tagMatch in tagMatches {
            // Text segment before this tag
            if tagMatch.range.location > cursor {
                let before = nsText.substring(
                    with: NSRange(location: cursor, length: tagMatch.range.location - cursor)
                )
                result = result + inlineMarkdown(before)
            }

            // The colored tag badge
            result = result
                + Text(" ")
                + Text(tagMatch.displayText)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundColor(tagMatch.color)
                    .baselineOffset(1)
                + Text(" ")

            cursor = tagMatch.range.location + tagMatch.range.length
        }

        // Remaining text after the last tag
        if cursor < nsText.length {
            let remaining = nsText.substring(from: cursor)
            result = result + inlineMarkdown(remaining)
        }

        return result
    }

    /// Regex to strip orphan [UPPERCASE] brackets that AttributedString misinterprets as links.
    // SAFETY: Hardcoded literal pattern — `try!` only fails on invalid regex syntax.
    private static let orphanBracketRegex = try! NSRegularExpression(
        pattern: "\\[[A-Z][A-Z ]+\\](?!\\()"
    )

    /// Standard inline markdown parsing (bold, italic, code, links).
    private func inlineMarkdown(_ text: String) -> Text {
        let cleaned = Self.orphanBracketRegex.stringByReplacingMatches(
            in: text,
            range: NSRange(location: 0, length: (text as NSString).length),
            withTemplate: ""
        )
        if let attributed = try? AttributedString(
            markdown: cleaned,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(cleaned)
    }
}

// MARK: - Tag Summary Bar
// Compact row of capsule badges showing how many of each epistemic tag type appeared.

struct TagSummaryBar: View {
    let text: String
    let theme: EpistemosTheme

    private var tagCounts: [(tag: EpistemicTag, count: Int)] {
        EpistemicTag.counts(in: text)
    }

    var body: some View {
        if !tagCounts.isEmpty {
            HStack(spacing: 6) {
                ForEach(tagCounts, id: \.tag) { item in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(item.tag.color)
                            .frame(width: 6, height: 6)
                        Text(item.tag.rawValue)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(item.tag.color)
                        Text("\u{00D7}\(item.count)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(theme.mutedForeground.opacity(0.6))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(item.tag.color.opacity(0.08), in: Capsule())
                }
            }
        }
    }
}
