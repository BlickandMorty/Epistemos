// OutlineNavigatorView.swift
//
// Xcode-style document outline navigator for code and markdown files.
// Provides a hierarchical view of headers, sections, and symbols.
// Auto-collapses MARK comments and markdown headers for quick navigation.
//
// 2026-04-07.

import SwiftUI

// MARK: - Document Outline Model

/// Represents a navigable item in the document outline
struct OutlineItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let type: OutlineItemType
    let lineNumber: Int
    let level: Int  // Hierarchy level (0 = root, 1 = first level, etc.)
    var stableID: String = ""
    var isExpanded: Bool = true
    var children: [OutlineItem] = []

    var outlineIdentity: String {
        if !stableID.isEmpty {
            return stableID
        }
        return "\(type.stableKey)-\(level)-\(lineNumber)-\(title)"
    }
    
    static func == (lhs: OutlineItem, rhs: OutlineItem) -> Bool {
        lhs.outlineIdentity == rhs.outlineIdentity &&
        lhs.title == rhs.title &&
        lhs.type == rhs.type &&
        lhs.lineNumber == rhs.lineNumber &&
        lhs.level == rhs.level &&
        lhs.isExpanded == rhs.isExpanded &&
        lhs.children == rhs.children
    }
}

enum OutlineItemType: Sendable, Equatable {
    case markdownHeader(level: Int)  // #, ##, ###
    case markComment                 // MARK: -
    case symbol(kind: SymbolKind)    // Functions, classes, etc.
    case section(title: String)      // Generic section
    
    var icon: String {
        switch self {
        case .markdownHeader(let level):
            switch level {
            case 1: return "text.formatting.header.1"
            case 2: return "text.formatting.header.2"
            case 3: return "text.formatting.header.3"
            default: return "text.alignleft"
            }
        case .markComment:
            return "bookmark"
        case .symbol(let kind):
            return kind.icon
        case .section:
            return "doc.text"
        }
    }
    
    var color: Color {
        switch self {
        case .markdownHeader(let level):
            switch level {
            case 1: return .primary
            case 2: return .secondary
            case 3: return .gray
            default: return .secondary
            }
        case .markComment:
            return .orange
        case .symbol(let kind):
            return kind.color
        case .section:
            return .secondary
        }
    }

    var stableKey: String {
        switch self {
        case .markdownHeader(let level):
            "markdown-\(level)"
        case .markComment:
            "mark"
        case .symbol(let kind):
            "symbol-\(kind.stableKey)"
        case .section(let title):
            "section-\(title.lowercased())"
        }
    }
}

enum SymbolKind: Sendable, Equatable {
    case function
    case method
    case property
    case classType
    case structType
    case enumType
    case protocolType
    case extensionType
    case variable
    case constant
    
    var icon: String {
        switch self {
        case .function: return "f.cursive"
        case .method: return "m.square"
        case .property: return "p.square"
        case .classType: return "c.square"
        case .structType: return "s.square"
        case .enumType: return "e.square"
        case .protocolType: return "p.circle"
        case .extensionType: return "e.circle"
        case .variable: return "v.square"
        case .constant: return "let"
        }
    }
    
    var color: Color {
        switch self {
        case .function, .method: return .blue
        case .property, .variable: return .green
        case .classType: return .orange
        case .structType: return .purple
        case .enumType: return .red
        case .protocolType: return .pink
        case .extensionType: return .gray
        case .constant: return .cyan
        }
    }

    var stableKey: String {
        switch self {
        case .function: "function"
        case .method: "method"
        case .property: "property"
        case .classType: "class"
        case .structType: "struct"
        case .enumType: "enum"
        case .protocolType: "protocol"
        case .extensionType: "extension"
        case .variable: "variable"
        case .constant: "constant"
        }
    }
}

// MARK: - Outline Parser

/// Parses document content to extract outline structure.
/// All regex patterns are compiled once as static properties.
struct OutlineParser {
    private static func makeRegex(_ pattern: String) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            preconditionFailure("Invalid outline regex: \(pattern)")
        }
    }

    // Pre-compiled regex — compiled once, reused on every parse call
    private static let markdownHeaderRegex = makeRegex("^(#{1,6})\\s+(.+)$")
    private static let markCommentRegexes: [NSRegularExpression] = [
        makeRegex("^//\\s*MARK:\\s*-?\\s*(.+)$"),
        makeRegex("^#\\s*MARK:\\s*-?\\s*(.+)$"),
        makeRegex("^///\\s*#\\s*MARK:\\s*-?\\s*(.+)$")
    ]
    private static let rustSymbolRegex = makeRegex("\\b(fn|struct|enum|impl)\\s+([^(<{]+)")
    private static let pythonSymbolRegex = makeRegex("^\\s*(def|class)\\s+([^(]+)")

    static func parse(content: String, language: String) -> [OutlineItem] {
        let lines = content.components(separatedBy: .newlines)
        var items: [OutlineItem] = []
        var stack: [OutlineItem] = []

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1

            if let item = parseMarkdownHeader(line: line, lineNumber: lineNumber) {
                items = appendItem(item, to: &items, using: &stack)
                continue
            }

            if let item = parseMarkComment(line: line, lineNumber: lineNumber) {
                items = appendItem(item, to: &items, using: &stack)
                continue
            }

            if let item = parseSymbol(line: line, lineNumber: lineNumber, language: language) {
                items = appendItem(item, to: &items, using: &stack)
            }
        }

        return assignStableIDs(to: items, parentPath: "root")
    }

    private static func parseMarkdownHeader(line: String, lineNumber: Int) -> OutlineItem? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let match = markdownHeaderRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let levelSwiftRange = Range(match.range(at: 1), in: trimmed),
              let titleSwiftRange = Range(match.range(at: 2), in: trimmed) else {
            return nil
        }

        let level = trimmed[levelSwiftRange].count
        let title = String(trimmed[titleSwiftRange]).trimmingCharacters(in: .whitespaces)

        return OutlineItem(
            title: title,
            type: .markdownHeader(level: level),
            lineNumber: lineNumber,
            level: level - 1
        )
    }

    private static func parseMarkComment(line: String, lineNumber: Int) -> OutlineItem? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let indentLevel = indentationLevel(for: line)

        for regex in markCommentRegexes {
            if let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               let titleRange = Range(match.range(at: 1), in: trimmed) {
                let title = String(trimmed[titleRange]).trimmingCharacters(in: .whitespaces)
                return OutlineItem(title: title, type: .markComment, lineNumber: lineNumber, level: indentLevel)
            }
        }

        return nil
    }

    private static func parseSymbol(line: String, lineNumber: Int, language: String) -> OutlineItem? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let indentLevel = indentationLevel(for: line)

        switch language {
        case "swift":
            return parseSwiftSymbol(line: trimmed, lineNumber: lineNumber, indentLevel: indentLevel)
        case "rust":
            return parseRustSymbol(line: trimmed, lineNumber: lineNumber, indentLevel: indentLevel)
        case "python":
            return parsePythonSymbol(line: trimmed, lineNumber: lineNumber, indentLevel: indentLevel)
        default:
            return nil
        }
    }

    private static func parseSwiftSymbol(line: String, lineNumber: Int, indentLevel: Int) -> OutlineItem? {
        if line.starts(with: "func ") || line.contains(" func ") {
            return OutlineItem(
                title: extractSymbolName(line: line, keyword: "func") ?? "function",
                type: .symbol(kind: .function), lineNumber: lineNumber, level: max(1, indentLevel)
            )
        }
        if line.starts(with: "class ") || line.contains(" class ") {
            return OutlineItem(
                title: extractSymbolName(line: line, keyword: "class") ?? "Class",
                type: .symbol(kind: .classType), lineNumber: lineNumber, level: indentLevel
            )
        }
        if line.starts(with: "struct ") || line.contains(" struct ") {
            return OutlineItem(
                title: extractSymbolName(line: line, keyword: "struct") ?? "Struct",
                type: .symbol(kind: .structType), lineNumber: lineNumber, level: indentLevel
            )
        }
        return nil
    }

    private static func extractSymbolName(line: String, keyword: String) -> String? {
        let pattern = "\\b\(keyword)\\s+([^(<:]+)"
        // keyword-specific regex cannot be pre-compiled since the keyword varies
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let nameRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        let rawName = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
        let cleanedName = rawName
            .replacingOccurrences(of: #"\s*\{\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        return cleanedName.isEmpty ? nil : cleanedName
    }

    private static func parseRustSymbol(line: String, lineNumber: Int, indentLevel: Int) -> OutlineItem? {
        guard line.starts(with: "fn ") || line.starts(with: "pub fn ") ||
              line.starts(with: "struct ") || line.starts(with: "pub struct ") else { return nil }

        guard let match = rustSymbolRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let keywordRange = Range(match.range(at: 1), in: line),
              let nameRange = Range(match.range(at: 2), in: line) else { return nil }

        let keyword = String(line[keywordRange])
        let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
        let kind: SymbolKind = keyword == "fn" ? .function : .structType

        let level = kind == .function ? max(1, indentLevel) : indentLevel
        return OutlineItem(title: name, type: .symbol(kind: kind), lineNumber: lineNumber, level: level)
    }

    private static func parsePythonSymbol(line: String, lineNumber: Int, indentLevel: Int) -> OutlineItem? {
        guard line.starts(with: "def ") || line.starts(with: "class ") else { return nil }

        guard let match = pythonSymbolRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let keywordRange = Range(match.range(at: 1), in: line),
              let nameRange = Range(match.range(at: 2), in: line) else { return nil }

        let keyword = String(line[keywordRange])
        let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
        let kind: SymbolKind = keyword == "def" ? .function : .classType

        let level = kind == .function ? max(1, indentLevel) : indentLevel
        return OutlineItem(title: name, type: .symbol(kind: kind), lineNumber: lineNumber, level: level)
    }

    private static func indentationLevel(for line: String) -> Int {
        var width = 0

        for character in line {
            if character == " " {
                width += 1
            } else if character == "\t" {
                width += 4
            } else {
                break
            }
        }

        return width / 4
    }
    
    private static func appendItem(
        _ item: OutlineItem,
        to items: inout [OutlineItem],
        using stack: inout [OutlineItem]
    ) -> [OutlineItem] {
        while let last = stack.last, last.level >= item.level {
            stack.removeLast()
        }

        if let parent = stack.last {
            if !insertChild(item, into: &items, parentID: parent.id) {
                items.append(item)
            }
        } else {
            items.append(item)
        }

        stack.append(item)
        return items
    }

    private static func insertChild(
        _ child: OutlineItem,
        into items: inout [OutlineItem],
        parentID: UUID
    ) -> Bool {
        for index in items.indices {
            if items[index].id == parentID {
                items[index].children.append(child)
                return true
            }
            if insertChild(child, into: &items[index].children, parentID: parentID) {
                return true
            }
        }
        return false
    }

    private static func assignStableIDs(to items: [OutlineItem], parentPath: String) -> [OutlineItem] {
        var siblingOccurrences: [String: Int] = [:]

        return items.map { item in
            var item = item
            let component = stableComponent(for: item)
            let occurrence = siblingOccurrences[component, default: 0]
            siblingOccurrences[component] = occurrence + 1
            let path = "\(parentPath)/\(component)#\(occurrence)"
            item.stableID = path
            item.children = assignStableIDs(to: item.children, parentPath: path)
            return item
        }
    }

    private static func stableComponent(for item: OutlineItem) -> String {
        let sanitizedTitle = item.title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let titleComponent = sanitizedTitle.isEmpty ? "item" : sanitizedTitle
        return "\(item.type.stableKey)-\(item.level)-\(titleComponent)"
    }
}

// MARK: - Outline Navigator View

private struct FlattenedOutlineItem: Identifiable {
    let item: OutlineItem
    let depth: Int

    var id: String { item.outlineIdentity }
}

/// Xcode-style outline navigator sidebar
struct OutlineNavigatorView: View {
    @Environment(UIState.self) private var ui

    let items: [OutlineItem]
    let currentLine: Int
    let onSelect: (OutlineItem) -> Void
    
    @State private var expandedItems: Set<String> = []
    @State private var flattenedItems: [FlattenedOutlineItem] = []
    @State private var allFlattenedItems: [FlattenedOutlineItem] = []
    @State private var hasInitializedExpandedItems = false

    private var activeItemID: String? {
        allFlattenedItems
            .last(where: { $0.item.lineNumber <= currentLine })?
            .item.outlineIdentity
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Outline")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    expandAll()
                } label: {
                    Image(systemName: "arrow.down.forward.and.arrow.up.backward")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("Expand All")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
            
            Divider()
            
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(flattenedItems) { entry in
                            OutlineNavigatorRow(
                                entry: entry,
                                isExpanded: expandedItems.contains(entry.item.outlineIdentity),
                                isActive: entry.item.outlineIdentity == activeItemID,
                                onToggle: { toggleItem(entry.item.outlineIdentity) },
                                onSelect: { onSelect(entry.item) }
                            )
                            .id(entry.id)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                }
                .onChange(of: activeItemID) { _, newActiveItemID in
                    scrollToActiveItem(proxy: proxy, activeItemID: newActiveItemID)
                }
                .onAppear {
                    if !hasInitializedExpandedItems {
                        let initialExpandedItems = expandableItemIDs(in: items)
                        expandedItems = initialExpandedItems
                        hasInitializedExpandedItems = true
                        refreshFlattenedItems(expandedIDs: initialExpandedItems)
                    } else {
                        refreshFlattenedItems()
                    }
                }
                .onChange(of: items) { _, newItems in
                    let nextExpandableItems = expandableItemIDs(in: newItems)
                    let preservedExpandedItems = expandedItems.intersection(nextExpandableItems)

                    if preservedExpandedItems.isEmpty, !hasInitializedExpandedItems {
                        expandedItems = nextExpandableItems
                        hasInitializedExpandedItems = true
                        refreshFlattenedItems(expandedIDs: nextExpandableItems)
                    } else {
                        expandedItems = preservedExpandedItems
                        refreshFlattenedItems(expandedIDs: preservedExpandedItems)
                    }
                }
                .onChange(of: expandedItems) { _, _ in
                    refreshFlattenedItems()
                }
            }
        }
        .frame(width: 232)
        .background(NoteWorkspaceSurfaceStyle.canvasBackground(for: ui.theme))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(.separator)
                .frame(width: 0.5)
                .opacity(0.35)
        }
    }
    
    private func toggleItem(_ id: String) {
        if expandedItems.contains(id) {
            expandedItems.remove(id)
        } else {
            expandedItems.insert(id)
        }
    }
    
    private func expandAll() {
        let allIds = expandableItemIDs(in: items)
        if expandedItems.count == allIds.count {
            expandedItems.removeAll()
        } else {
            expandedItems = allIds
        }
    }
    
    private func scrollToActiveItem(proxy: ScrollViewProxy, activeItemID: String?) {
        guard let activeItemID else {
            return
        }
        proxy.scrollTo(activeItemID, anchor: .center)
    }

    private func refreshFlattenedItems(expandedIDs: Set<String>? = nil) {
        allFlattenedItems = flattenAll(items, depth: 0)
        flattenedItems = flatten(items, depth: 0, expandedIDs: expandedIDs ?? expandedItems)
    }

    private func flatten(_ items: [OutlineItem], depth: Int, expandedIDs: Set<String>) -> [FlattenedOutlineItem] {
        var result: [FlattenedOutlineItem] = []
        result.reserveCapacity(items.count)

        for item in items {
            result.append(FlattenedOutlineItem(item: item, depth: depth))
            if !item.children.isEmpty, expandedIDs.contains(item.outlineIdentity) {
                result.append(contentsOf: flatten(item.children, depth: depth + 1, expandedIDs: expandedIDs))
            }
        }

        return result
    }

    private func flattenAll(_ items: [OutlineItem], depth: Int) -> [FlattenedOutlineItem] {
        var result: [FlattenedOutlineItem] = []
        result.reserveCapacity(items.count)

        for item in items {
            result.append(FlattenedOutlineItem(item: item, depth: depth))
            if !item.children.isEmpty {
                result.append(contentsOf: flattenAll(item.children, depth: depth + 1))
            }
        }

        return result
    }

    private func expandableItemIDs(in items: [OutlineItem]) -> Set<String> {
        var ids: Set<String> = []
        for item in items where !item.children.isEmpty {
            ids.insert(item.outlineIdentity)
            ids.formUnion(expandableItemIDs(in: item.children))
        }
        return ids
    }
}

// MARK: - Outline Row

private struct OutlineNavigatorRow: View {
    let entry: FlattenedOutlineItem
    let isExpanded: Bool
    let isActive: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    
    var body: some View {
        rowContent
            .onTapGesture {
                onSelect()
            }
    }

    private var rowContent: some View {
        let item = entry.item

        return HStack(spacing: 0) {
            Color.clear
                .frame(width: CGFloat(entry.depth) * 12)

            if !item.children.isEmpty {
                Button {
                    onToggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(width: 12, height: 12)
            }

            Image(systemName: item.type.icon)
                .font(.system(size: 11))
                .foregroundStyle(item.type.color)
                .frame(width: 14, alignment: .center)

            HStack(spacing: 6) {
                Text(item.title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(item.lineNumber)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, 8)
            .padding(.trailing, 10)
            .padding(.vertical, 6)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 2)
        .background(selectionBackground)
    }

    private var selectionBackground: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(isActive ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.68) : .clear)
    }
}

// MARK: - Collapsible Outline Header

/// Inline collapsible header for use in the editor (like Xcode's source editor)
struct CollapsibleOutlineHeader: View {
    let item: OutlineItem
    let isExpanded: Bool
    let isActive: Bool
    let onToggle: () -> Void
    let onNavigate: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Disclosure triangle
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    onToggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isHovered || isActive ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 14, height: 14)
            
            // Header marker or icon
            switch item.type {
            case .markdownHeader(let level):
                Image(systemName: "text.formatting.header.\(min(level, 3))")
                    .font(.system(size: 12))
                    .foregroundStyle(headerColor(for: level))
            case .markComment:
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            default:
                Image(systemName: item.type.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(item.type.color)
            }
            
            // Title
            Text(item.title)
                .font(.system(size: 13 - CGFloat(item.level), weight: headerWeight))
                .foregroundStyle(isActive ? .primary : .secondary)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(backgroundStyle)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onNavigate()
        }
    }
    
    private var headerWeight: Font.Weight {
        switch item.level {
        case 0: return .bold
        case 1: return .semibold
        default: return .medium
        }
    }
    
    private func headerColor(for level: Int) -> Color {
        switch level {
        case 1: return .primary
        case 2: return .secondary
        case 3: return .gray
        default: return .secondary
        }
    }
    
    private var backgroundStyle: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isActive ? Color.accentColor.opacity(0.1) : (isHovered ? Color.secondary.opacity(0.05) : Color.clear))
    }
}

// MARK: - Preview

#Preview("Outline Navigator") {
    let sampleItems = [
        OutlineItem(
            title: "Jinja",
            type: .markdownHeader(level: 1),
            lineNumber: 1,
            level: 0,
            children: [
                OutlineItem(
                    title: "Requirements",
                    type: .markdownHeader(level: 2),
                    lineNumber: 9,
                    level: 1
                ),
                OutlineItem(
                    title: "Installation",
                    type: .markdownHeader(level: 2),
                    lineNumber: 13,
                    level: 1,
                    children: [
                        OutlineItem(
                            title: "Swift Package Manager",
                            type: .markdownHeader(level: 3),
                            lineNumber: 15,
                            level: 2
                        )
                    ]
                ),
                OutlineItem(
                    title: "Features",
                    type: .markdownHeader(level: 2),
                    lineNumber: 36,
                    level: 1
                ),
                OutlineItem(
                    title: "Not Supported Features",
                    type: .markdownHeader(level: 2),
                    lineNumber: 198,
                    level: 1
                ),
                OutlineItem(
                    title: "Usage",
                    type: .markdownHeader(level: 2),
                    lineNumber: 228,
                    level: 1,
                    children: [
                        OutlineItem(
                            title: "Basic Template Rendering",
                            type: .markdownHeader(level: 3),
                            lineNumber: 230,
                            level: 2
                        ),
                        OutlineItem(
                            title: "Template with Context Variables",
                            type: .markdownHeader(level: 3),
                            lineNumber: 247,
                            level: 2
                        )
                    ]
                )
            ]
        )
    ]
    
    OutlineNavigatorView(
        items: sampleItems,
        currentLine: 230,
        onSelect: { _ in }
    )
    .frame(height: 600)
}

#Preview("Collapsible Header") {
    VStack(spacing: 16) {
        CollapsibleOutlineHeader(
            item: OutlineItem(
                title: "Features",
                type: .markdownHeader(level: 2),
                lineNumber: 36,
                level: 1
            ),
            isExpanded: true,
            isActive: false,
            onToggle: {},
            onNavigate: {}
        )
        
        CollapsibleOutlineHeader(
            item: OutlineItem(
                title: "Basic Template Rendering",
                type: .markdownHeader(level: 3),
                lineNumber: 230,
                level: 2
            ),
            isExpanded: false,
            isActive: true,
            onToggle: {},
            onNavigate: {}
        )
        
        CollapsibleOutlineHeader(
            item: OutlineItem(
                title: "MARK: Private Methods",
                type: .markComment,
                lineNumber: 150,
                level: 0
            ),
            isExpanded: true,
            isActive: false,
            onToggle: {},
            onNavigate: {}
        )
    }
    .padding()
    .frame(width: 300)
}
