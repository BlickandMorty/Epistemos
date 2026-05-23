import Foundation
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
    enum TypographyRole: Sendable {
        case assistant
        case user

        var bodyFontSize: CGFloat {
            switch self {
            case .assistant: 15
            case .user: 15
            }
        }

        var bodyLineSpacing: CGFloat {
            switch self {
            case .assistant: 10
            case .user: 7
            }
        }

        var paragraphVerticalPadding: CGFloat {
            switch self {
            case .assistant: 5
            case .user: 4
            }
        }

        func font(size: CGFloat) -> Font {
            switch self {
            case .assistant:
                ClaudeAppTypography.assistantFont(size: size)
            case .user:
                ClaudeAppTypography.userFont(size: size)
            }
        }
    }

    let content: String
    let theme: EpistemosTheme
    var rippleStyle: MarkdownRippleStyle = .none
    var foregroundOverride: Color? = nil
    var typographyRole: TypographyRole = .assistant
    private let blocks: [MarkdownBlock]
    private static let listMarkerWidth: CGFloat = 12
    private static let numberedMarkerMinWidth: CGFloat = 24
    private static let listIndent: CGFloat = 4
    private static let nestedListIndent: CGFloat = 18
    private static let listSpacing: CGFloat = 8
    private static let listRunSpacing: CGFloat = 6
    private static let blockCacheLimit = 48
    private static let blockCacheLock = NSLock()
    private static var blockCache: [String: [MarkdownBlock]] = [:]
    private static var blockCacheOrder: [String] = []
    private static var blockCacheHits = 0
    private static var blockCacheMisses = 0

    private static func concatenate(_ lhs: Text, _ rhs: Text) -> Text {
        Text("\(lhs)\(rhs)")
    }

    /// Matches epistemic tags with optional qualifiers:
    /// [DATA], [DATA - Tier 2], [CONFLICT], [MODEL - Framework], [UNCERTAIN - High], etc.
    private static let primaryTagRegex = FoundationSafety.regularExpression(
        pattern: "\\[(DATA|CONFLICT|UNCERTAIN|MODEL)([^\\]]*)\\]"
    )

    /// Matches standalone tier references: [Tier 1], [Tier 2], [Tier 3], [Tier 4], [Tier 5].
    /// Also matches any remaining [Capitalized Word(s)] patterns the LLM produces as markers.
    private static let secondaryTagRegex = FoundationSafety.regularExpression(
        pattern: "\\[(Tier\\s*\\d+)\\]"
    )

    init(
        content: String,
        theme: EpistemosTheme,
        rippleStyle: MarkdownRippleStyle = .none,
        foregroundOverride: Color? = nil,
        typographyRole: TypographyRole = .assistant
    ) {
        self.content = content
        self.theme = theme
        self.rippleStyle = rippleStyle
        self.foregroundOverride = foregroundOverride
        self.typographyRole = typographyRole
        self.blocks = Self.cachedBlocks(for: content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(renderUnits.enumerated()), id: \.offset) { _, unit in
                renderUnit(unit)
            }
        }
        .textSelection(.enabled)
    }

    private var bodyForeground: Color {
        foregroundOverride ?? theme.assistantBubbleForeground
    }

    private var bodyFontSize: CGFloat {
        typographyRole.bodyFontSize
    }

    private var bodyLineSpacing: CGFloat {
        typographyRole.bodyLineSpacing
    }

    private var paragraphVerticalPadding: CGFloat {
        typographyRole.paragraphVerticalPadding
    }

    private var bodyFont: Font {
        typographyRole.font(size: bodyFontSize)
    }

    private var strongBodyFont: Font {
        ClaudeAppTypography.monoFont(size: bodyFontSize, weight: .semibold)
    }

    private var renderUnits: [MarkdownRenderUnit] {
        Self.renderUnits(from: blocks)
    }

    // MARK: - Block Types

    private enum MarkdownListKind: Equatable {
        case bullet
        case numbered(String)
        case check(Bool)
    }

    private struct MarkdownListItem: Equatable {
        let level: Int
        let kind: MarkdownListKind
        let text: String
    }

    private enum MarkdownBlock {
        case heading(level: Int, text: String)
        case paragraph(text: String)
        case bulletItem(level: Int, text: String)
        case numberedItem(level: Int, number: String, text: String)
        case checkItem(level: Int, checked: Bool, text: String)
        case blockquote(level: Int, text: String)
        case codeBlock(language: String, code: String)
        case horizontalRule
        case tableLine(text: String)
        case table(rows: [[String]], headerCount: Int)
    }

    private enum MarkdownRenderUnit {
        case block(MarkdownBlock)
        case list([MarkdownListItem])
    }

    struct BlockCacheStats: Equatable {
        let hits: Int
        let misses: Int
    }

    // MARK: - Block Parsing

    static func resetBlockCacheForTesting() {
        blockCacheLock.lock()
        blockCache.removeAll(keepingCapacity: false)
        blockCacheOrder.removeAll(keepingCapacity: false)
        blockCacheHits = 0
        blockCacheMisses = 0
        blockCacheLock.unlock()
    }

    static func cachedBlockCount(for text: String) -> Int {
        cachedBlocks(for: text).count
    }

    static func blockCacheStatsForTesting() -> BlockCacheStats {
        blockCacheLock.lock()
        let stats = BlockCacheStats(hits: blockCacheHits, misses: blockCacheMisses)
        blockCacheLock.unlock()
        return stats
    }

    static func debugBlockSummaries(for text: String) -> [String] {
        cachedBlocks(for: text).compactMap { block in
            switch block {
            case .heading(let level, let text):
                "heading@\(level):\(text)"
            case .paragraph(let text):
                "paragraph:\(text)"
            case .bulletItem(let level, let text):
                "bullet@\(level):\(text)"
            case .numberedItem(let level, let number, let text):
                "numbered@\(level):\(number):\(text)"
            case .checkItem(let level, let checked, let text):
                "check@\(level):\(checked):\(text)"
            case .blockquote(let level, let text):
                "blockquote@\(level):\(text)"
            case .codeBlock(let language, _):
                "code:\(language)"
            case .horizontalRule:
                "rule"
            case .table(let rows, _):
                "table:\(rows.count)"
            case .tableLine:
                nil
            }
        }
    }

    static func debugRenderUnitSummaries(for text: String) -> [String] {
        renderUnits(from: cachedBlocks(for: text)).compactMap { unit in
            switch unit {
            case .block(let block):
                switch block {
                case .paragraph:
                    "paragraph"
                case .heading:
                    "heading"
                case .blockquote:
                    "blockquote"
                case .codeBlock:
                    "code"
                case .horizontalRule:
                    "rule"
                case .table:
                    "table"
                case .tableLine:
                    nil
                case .bulletItem, .numberedItem, .checkItem:
                    "list-item"
                }
            case .list(let items):
                "list:\(items.count)"
            }
        }
    }

    private static func cachedBlocks(for text: String) -> [MarkdownBlock] {
        blockCacheLock.lock()
        if let cached = blockCache[text] {
            blockCacheHits += 1
            blockCacheLock.unlock()
            return cached
        }
        blockCacheLock.unlock()

        let parsed = mergeTableBlocks(parseBlocks(text))

        blockCacheLock.lock()
        if let cached = blockCache[text] {
            blockCacheHits += 1
            blockCacheLock.unlock()
            return cached
        }

        blockCacheMisses += 1
        blockCache[text] = parsed
        blockCacheOrder.append(text)
        if blockCacheOrder.count > blockCacheLimit {
            let overflow = blockCacheOrder.count - blockCacheLimit
            for _ in 0..<overflow {
                let evicted = blockCacheOrder.removeFirst()
                blockCache.removeValue(forKey: evicted)
            }
        }
        blockCacheLock.unlock()
        return parsed
    }

    private static func renderUnits(from blocks: [MarkdownBlock]) -> [MarkdownRenderUnit] {
        var units: [MarkdownRenderUnit] = []
        var listItems: [MarkdownListItem] = []

        func flushList() {
            guard !listItems.isEmpty else { return }
            units.append(.list(listItems))
            listItems.removeAll(keepingCapacity: true)
        }

        for block in blocks {
            if let item = listItem(from: block) {
                listItems.append(item)
            } else {
                flushList()
                units.append(.block(block))
            }
        }

        flushList()
        return units
    }

    private static func listItem(from block: MarkdownBlock) -> MarkdownListItem? {
        switch block {
        case .bulletItem(let level, let text):
            MarkdownListItem(level: level, kind: .bullet, text: text)
        case .numberedItem(let level, let number, let text):
            MarkdownListItem(level: level, kind: .numbered(number), text: text)
        case .checkItem(let level, let checked, let text):
            MarkdownListItem(level: level, kind: .check(checked), text: text)
        default:
            nil
        }
    }

    private static func parseBulletItem(from line: String) -> (level: Int, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") else { return nil }
        return (indentLevel(for: line), String(trimmed.dropFirst(2)))
    }

    private static func parseCheckItem(from line: String) -> (level: Int, checked: Bool, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard
            let match = trimmed.range(of: #"^[-*]\s\[(x|X| )\]\s"#, options: .regularExpression)
        else {
            return nil
        }

        let marker = String(trimmed[trimmed.startIndex..<match.upperBound])
        let checked = marker.localizedCaseInsensitiveContains("[x]")
        let text = String(trimmed[match.upperBound...])
        return (indentLevel(for: line), checked, text)
    }

    private static func parseNumberedItem(from line: String) -> (level: Int, number: String, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let match = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) else { return nil }
        let number = String(trimmed[trimmed.startIndex..<match.upperBound]).trimmingCharacters(in: .whitespaces)
        let text = String(trimmed[match.upperBound...])
        return (indentLevel(for: line), number, text)
    }

    private static func parseBlockquote(from trimmedLine: String) -> (level: Int, text: String)? {
        guard trimmedLine.hasPrefix(">") else { return nil }

        var level = 0
        var index = trimmedLine.startIndex
        while index < trimmedLine.endIndex, trimmedLine[index] == ">" {
            level += 1
            index = trimmedLine.index(after: index)
            if index < trimmedLine.endIndex, trimmedLine[index] == " " {
                index = trimmedLine.index(after: index)
            }
        }

        let text = trimmedLine[index...].trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (max(level, 1), text)
    }

    private static func indentLevel(for line: String) -> Int {
        let prefix = line.prefix { $0 == " " || $0 == "\t" }
        let normalized = prefix.reduce(into: 0) { total, character in
            total += character == "\t" ? 4 : 1
        }
        return normalized / 2
    }

    private static func parseBlocks(_ text: String) -> [MarkdownBlock] {
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
            else if let taskItem = parseCheckItem(from: line) {
                blocks.append(.checkItem(level: taskItem.level, checked: taskItem.checked, text: taskItem.text))
            }
            // Bullet list
            else if let bulletItem = parseBulletItem(from: line) {
                blocks.append(.bulletItem(level: bulletItem.level, text: bulletItem.text))
            }
            // Numbered list
            else if let numberedItem = parseNumberedItem(from: line) {
                blocks.append(.numberedItem(level: numberedItem.level, number: numberedItem.number, text: numberedItem.text))
            }
            // Blockquote
            else if let blockquote = parseBlockquote(from: trimmed) {
                blocks.append(.blockquote(level: blockquote.level, text: blockquote.text))
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

    private static func mergeTableBlocks(_ blocks: [MarkdownBlock]) -> [MarkdownBlock] {
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
        MarkdownTableSurfaceView(
            table: MarkdownTableModel(rows: rows, headerCount: headerCount),
            theme: theme
        ) { cell, isHeader in
            taggedInlineMarkdown(
                cell,
                baseFontSize: 13,
                strongForegroundColor: theme.chatStrongForeground,
                strongFont: ClaudeAppTypography.monoFont(size: 13, weight: .semibold)
            )
            .font(typographyRole.font(size: 13))
            .foregroundStyle(bodyForeground.opacity(isHeader ? 1.0 : 0.85))
            .fontWeight(isHeader ? .semibold : .regular)
        }
    }

    @ViewBuilder
    private func renderUnit(_ unit: MarkdownRenderUnit) -> some View {
        switch unit {
        case .block(let block):
            renderBlock(block)
        case .list(let items):
            renderList(items)
        }
    }

    // MARK: - Block Rendering

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            renderHeading(level: level, text: text)
        case .paragraph(let text):
            taggedInlineMarkdown(
                text,
                baseFontSize: bodyFontSize,
                strongForegroundColor: theme.chatStrongForeground,
                strongFont: strongBodyFont
            )
                .font(bodyFont)
                .lineSpacing(bodyLineSpacing)
                .foregroundStyle(bodyForeground)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, paragraphVerticalPadding)
                .asciiRippleOverlay(
                    text: MarkdownRippleTextExtractor.displayText(from: text),
                    font: bodyFont,
                    color: bodyForeground,
                    enabled: rippleStyle.includesBodyBlocks
                )
        case .bulletItem, .numberedItem, .checkItem:
            EmptyView()
        case .blockquote(let level, let text):
            HStack(spacing: 0) {
                HStack(spacing: 5) {
                    ForEach(0..<max(level, 1), id: \.self) { depth in
                        RoundedRectangle(cornerRadius: depth == 0 ? 1.5 : 1)
                            .fill(theme.resolved.accent.color.opacity(depth == 0 ? 0.5 : 0.24))
                            .frame(width: depth == 0 ? 3 : 2)
                    }
                }
                taggedInlineMarkdown(
                    text,
                    baseFontSize: bodyFontSize,
                    strongForegroundColor: theme.chatStrongForeground,
                    strongFont: strongBodyFont
                )
                    .font(bodyFont)
                    .lineSpacing(bodyLineSpacing)
                    .italic()
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 12)
                    .asciiRippleOverlay(
                        text: MarkdownRippleTextExtractor.displayText(from: text),
                        font: bodyFont,
                        color: theme.textSecondary,
                        enabled: rippleStyle.includesBodyBlocks
                    )
            }
            .padding(.leading, CGFloat(max(level - 1, 0)) * 6)
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
                    .fixedSize(horizontal: false, vertical: true)
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

    @ViewBuilder
    private func renderList(_ items: [MarkdownListItem]) -> some View {
        VStack(alignment: .leading, spacing: Self.listRunSpacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                renderListItem(item)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func renderListItem(_ item: MarkdownListItem) -> some View {
        HStack(alignment: .top, spacing: Self.listSpacing) {
            renderListMarker(for: item)
            renderListText(
                item.text,
                foreground: listItemForeground(for: item),
                strikethrough: isChecked(item)
            )
        }
        .padding(.leading, Self.listIndent + CGFloat(item.level) * Self.nestedListIndent)
    }

    @ViewBuilder
    private func renderListMarker(for item: MarkdownListItem) -> some View {
        switch item.kind {
        case .bullet:
            Text("\u{2022}")
                .font(ClaudeAppTypography.monoFont(size: 17, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color)
                .frame(width: Self.listMarkerWidth, alignment: .leading)
                .padding(.top, 1)
        case .numbered(let number):
            Text(number)
                .font(ClaudeAppTypography.monoFont(size: bodyFontSize, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color)
                .frame(minWidth: Self.numberedMarkerMinWidth, alignment: .trailing)
                .padding(.top, 1)
        case .check(let checked):
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .font(.system(size: 13))
                .foregroundStyle(checked ? theme.resolved.accent.color : theme.textTertiary)
                .frame(width: Self.listMarkerWidth, alignment: .leading)
                .padding(.top, 2)
        }
    }

    @ViewBuilder
    private func renderListText(
        _ text: String,
        foreground: Color,
        strikethrough: Bool
    ) -> some View {
        taggedInlineMarkdown(
            text,
            baseFontSize: bodyFontSize,
            strongForegroundColor: theme.chatStrongForeground,
            strongFont: strongBodyFont
        )
        .font(bodyFont)
        .lineSpacing(bodyLineSpacing)
        .foregroundStyle(foreground)
        .strikethrough(strikethrough)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .asciiRippleOverlay(
            text: MarkdownRippleTextExtractor.displayText(from: text),
            font: bodyFont,
            color: foreground,
            enabled: rippleStyle.includesBodyBlocks
        )
    }

    private func listItemForeground(for item: MarkdownListItem) -> Color {
        isChecked(item) ? theme.textTertiary : bodyForeground
    }

    // MARK: - Heading Rendering

    @ViewBuilder
    private func renderHeading(level: Int, text: String) -> some View {
        let headingRole = AppHeadingRole.markdownRole(level: level)
        let baseFontSize: CGFloat = headingRole?.fontSize ?? (level == 4 ? 15 : 14)
        // Notes-matching H2/H3 typography override (Ember pair, 2026-05-19):
        // chat H2/H3 mirror the Tiptap notes editor's size + weight, on
        // Ember's intrinsic heading face (ChonkyPixels).
        let notesSpec = theme.notesMatchingHeadingSpec(level: level)
        // Per-theme H1-H3 size multiplier (Classic + Platinum shrink 15 % to
        // visually match Ember; Ember stays on 1.0). Applied to both the
        // canonical AppHeadingRole sizes and the notes-spec override.
        let multiplier = (1...3).contains(level) ? theme.headingSizeMultiplier : 1.0
        let effectiveBaseSize = (notesSpec?.size ?? baseFontSize) * multiplier
        let fontSize = MarkdownHeadingDisplay.fontSize(
            for: level,
            text: text,
            baseSize: effectiveBaseSize,
            nextLevelSize: AppHeadingRole.h2.fontSize * multiplier
        )
        let font: Font = {
            if let notesSpec {
                let scaledSize = AppDisplayTypography.displayFontSize(
                    for: fontSize,
                    isDark: theme.isDark
                )
                return Font.custom(notesSpec.fontName, size: scaledSize)
            }
            let weight: Font.Weight = MarkdownHeadingDisplay.noteHeadingFontWeight(for: level)
            if (1...3).contains(level) {
                // RCA finalization 2026-05-13: route H1-H3 through
                // the theme-aware heading font so each ThemePair
                // picks its own light-mode typeface (Platinum →
                // MatrixTypeDisplay, Classic → CoralPixels, Ember →
                // DotempDemo-8bit). Dark mode unchanged (still
                // RetroGaming).
                return AppDisplayTypography.headingFont(size: fontSize, weight: weight, theme: theme)
            } else if (4...5).contains(level) {
                return AppDisplayTypography.font(size: fontSize, weight: weight, allowDisplayFont: false)
            } else {
                return ClaudeAppTypography.monoFont(size: fontSize, weight: weight)
            }
        }()
        // Match font shrink for Classic + Platinum (Ember stays on 1.0).
        let topPad = (headingRole?.topPadding ?? 6) * multiplier
        let color = MarkdownHeadingDisplay.foregroundColor(for: theme, level: level)
        // RCA finalization 2026-05-13: thread the theme through so
        // Classic uppercases H1-H3 (matches the Classic hero
        // ChonkyPixels treatment in LiquidGreeting). 2026-05-19: also
        // uppercases Ember H1 only (notes-matching H2/H3 keep mixed case).
        let displayText = MarkdownHeadingDisplay.displayText(text, level: level, theme: theme)

        taggedInlineMarkdown(
            displayText,
            baseFontSize: fontSize,
            strongFont: font
        )
            .font(font)
            // Synthetic bold for Ember H2 (heavy) / H3 (semibold) only.
            // Other themes keep the font's intrinsic weight, matching
            // pre-2026-05-19 rendering.
            .modifier(NotesMatchingWeightModifier(weight: notesSpec?.weight))
            .foregroundStyle(color)
            .asciiRippleOverlay(
                text: MarkdownRippleTextExtractor.displayText(from: displayText),
                font: font,
                color: color,
                shadowColor: MarkdownHeadingDisplay.swiftUIShadowColor(for: theme, level: level),
                shadowRadius: MarkdownHeadingDisplay.glowRadius(for: level),
                enabled: rippleStyle.ripplesHeading(level: level)
            )
            .padding(.top, topPad)
            .padding(.bottom, 2)
    }

    // MARK: - List Helpers

    private func isChecked(_ item: MarkdownListItem) -> Bool {
        if case .check(let checked) = item.kind {
            return checked
        }
        return false
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
    private func taggedInlineMarkdown(
        _ text: String,
        baseFontSize: CGFloat,
        strongForegroundColor: Color? = nil,
        strongFont: Font? = nil
    ) -> Text {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        var tagMatches: [TagMatch] = []

        // Primary: [DATA], [DATA - Tier 2], [CONFLICT], [MODEL - Framework], etc.
        if let primaryTagRegex = Self.primaryTagRegex {
            for match in primaryTagRegex.matches(in: text, range: fullRange) {
                let baseTagName = nsText.substring(with: match.range(at: 1))
                let qualifier = match.range(at: 2).location != NSNotFound
                    ? nsText.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
                    : ""
                let displayText = qualifier.isEmpty ? baseTagName : "\(baseTagName) \(qualifier)"
                if let tag = EpistemicTag.from(baseTagName) {
                    tagMatches.append(
                        TagMatch(range: match.range, displayText: displayText, color: tag.color)
                    )
                }
            }
        }

        // Secondary: [Tier 1], [Tier 2], [Tier 3], [Tier 4], [Tier 5]
        if let secondaryTagRegex = Self.secondaryTagRegex {
            for match in secondaryTagRegex.matches(in: text, range: fullRange) {
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
        }

        tagMatches.sort()

        // No tags → fast-path standard markdown
        guard !tagMatches.isEmpty else {
            return inlineMarkdown(
                text,
                baseFontSize: baseFontSize,
                strongForegroundColor: strongForegroundColor,
                strongFont: strongFont
            )
        }

        var result = Text("")
        var cursor = 0

        for tagMatch in tagMatches {
            // Text segment before this tag
            if tagMatch.range.location > cursor {
                let before = nsText.substring(
                    with: NSRange(location: cursor, length: tagMatch.range.location - cursor)
                )
                result = Self.concatenate(
                    result,
                    inlineMarkdown(
                        before,
                        baseFontSize: baseFontSize,
                        strongForegroundColor: strongForegroundColor,
                        strongFont: strongFont
                    )
                )
            }

            // The colored tag badge
            let styledTag = Text(tagMatch.displayText)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundColor(tagMatch.color)
                .baselineOffset(1)
            let badge = Text(" \(styledTag) ")
            result = Self.concatenate(result, badge)

            cursor = tagMatch.range.location + tagMatch.range.length
        }

        // Remaining text after the last tag
        if cursor < nsText.length {
            let remaining = nsText.substring(from: cursor)
            result = Self.concatenate(
                result,
                inlineMarkdown(
                    remaining,
                    baseFontSize: baseFontSize,
                    strongForegroundColor: strongForegroundColor,
                    strongFont: strongFont
                )
            )
        }

        return result
    }

    /// Standard inline markdown parsing (bold, italic, code, links).
    private func inlineMarkdown(
        _ text: String,
        baseFontSize: CGFloat,
        strongForegroundColor: Color? = nil,
        strongFont: Font? = nil
    ) -> Text {
        InlineMarkdownStyler.text(
            text,
            strongFontSize: baseFontSize,
            strongForegroundColor: strongForegroundColor,
            linkForegroundColor: theme.preferredMarkdownLinkColor,
            strongFont: strongFont
        )
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

/// Applies `.fontWeight(weight)` only when `weight` is non-nil so the
/// non-Ember heading paths render with the font's intrinsic weight
/// (matches pre-2026-05-19 behavior).
private struct NotesMatchingWeightModifier: ViewModifier {
    let weight: Font.Weight?

    func body(content: Content) -> some View {
        if let weight {
            content.fontWeight(weight)
        } else {
            content
        }
    }
}
