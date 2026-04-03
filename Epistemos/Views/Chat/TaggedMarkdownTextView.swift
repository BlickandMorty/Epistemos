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
    let content: String
    let theme: EpistemosTheme
    var rippleStyle: MarkdownRippleStyle = .none
    var foregroundOverride: Color? = nil
    private let blocks: [MarkdownBlock]
    private static let bodyFontSize: CGFloat = 15
    private static let bodyLineSpacing: CGFloat = 5
    private static let listMarkerWidth: CGFloat = 11
    private static let numberedMarkerMinWidth: CGFloat = 24
    private static let listIndent: CGFloat = 4
    private static let nestedListIndent: CGFloat = 18
    private static let listSpacing: CGFloat = 6
    private static let listRunSpacing: CGFloat = 4
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
        foregroundOverride: Color? = nil
    ) {
        self.content = content
        self.theme = theme
        self.rippleStyle = rippleStyle
        self.foregroundOverride = foregroundOverride
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
                strongForegroundColor: theme.chatStrongForeground
            )
            .font(.system(size: 13))
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
                baseFontSize: Self.bodyFontSize,
                strongForegroundColor: theme.chatStrongForeground
            )
                .font(.system(size: Self.bodyFontSize))
                .lineSpacing(Self.bodyLineSpacing)
                .foregroundStyle(bodyForeground)
                .padding(.vertical, 3)
                .asciiRippleOverlay(
                    text: MarkdownRippleTextExtractor.displayText(from: text),
                    font: .system(size: Self.bodyFontSize),
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
                    baseFontSize: Self.bodyFontSize,
                    strongForegroundColor: theme.chatStrongForeground
                )
                    .font(.system(size: Self.bodyFontSize))
                    .lineSpacing(Self.bodyLineSpacing)
                    .italic()
                    .foregroundStyle(theme.textSecondary)
                    .padding(.leading, 12)
                    .asciiRippleOverlay(
                        text: MarkdownRippleTextExtractor.displayText(from: text),
                        font: .system(size: Self.bodyFontSize),
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
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color)
                .frame(width: Self.listMarkerWidth, alignment: .leading)
                .padding(.top, 1)
        case .numbered(let number):
            Text(number)
                .font(.system(size: Self.bodyFontSize, weight: .semibold).monospacedDigit())
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
            baseFontSize: Self.bodyFontSize,
            strongForegroundColor: theme.chatStrongForeground
        )
        .font(.system(size: Self.bodyFontSize))
        .lineSpacing(Self.bodyLineSpacing)
        .foregroundStyle(foreground)
        .strikethrough(strikethrough)
        .frame(maxWidth: .infinity, alignment: .leading)
        .asciiRippleOverlay(
            text: MarkdownRippleTextExtractor.displayText(from: text),
            font: .system(size: Self.bodyFontSize),
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
        let retroRole = AppHeadingRole.markdownRole(level: level)
        let baseFontSize: CGFloat = retroRole?.fontSize ?? (level == 4 ? 15 : 14)
        let fontSize = MarkdownHeadingDisplay.fontSize(
            for: level,
            text: text,
            baseSize: baseFontSize,
            nextLevelSize: AppHeadingRole.h2.fontSize
        )
        let font: Font = {
            if level == 1 {
                return AppDisplayTypography.font(size: fontSize)
            } else {
                let weight: Font.Weight = MarkdownHeadingDisplay.noteHeadingFontWeight(for: level)
                return .system(size: fontSize, weight: weight)
            }
        }()
        let topPad = retroRole?.topPadding ?? 6
        let color = MarkdownHeadingDisplay.foregroundColor(for: theme, level: level)
        let displayText = MarkdownHeadingDisplay.displayText(text, level: level)

        taggedInlineMarkdown(displayText, baseFontSize: fontSize)
            .font(font)
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
        strongForegroundColor: Color? = nil
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
                strongForegroundColor: strongForegroundColor
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
                        strongForegroundColor: strongForegroundColor
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
                    strongForegroundColor: strongForegroundColor
                )
            )
        }

        return result
    }

    /// Standard inline markdown parsing (bold, italic, code, links).
    private func inlineMarkdown(
        _ text: String,
        baseFontSize: CGFloat,
        strongForegroundColor: Color? = nil
    ) -> Text {
        InlineMarkdownStyler.text(
            text,
            strongFontSize: baseFontSize,
            strongForegroundColor: strongForegroundColor,
            linkForegroundColor: theme.preferredMarkdownLinkColor
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
