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
    var isExpanded: Bool = true
    var children: [OutlineItem] = []
    
    static func == (lhs: OutlineItem, rhs: OutlineItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.lineNumber == rhs.lineNumber &&
        lhs.isExpanded == rhs.isExpanded
    }
}

enum OutlineItemType: Sendable {
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
}

enum SymbolKind: Sendable {
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

        return items
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

        for regex in markCommentRegexes {
            if let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               let titleRange = Range(match.range(at: 1), in: trimmed) {
                let title = String(trimmed[titleRange]).trimmingCharacters(in: .whitespaces)
                return OutlineItem(title: title, type: .markComment, lineNumber: lineNumber, level: 0)
            }
        }

        return nil
    }

    private static func parseSymbol(line: String, lineNumber: Int, language: String) -> OutlineItem? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        switch language {
        case "swift":
            return parseSwiftSymbol(line: trimmed, lineNumber: lineNumber)
        case "rust":
            return parseRustSymbol(line: trimmed, lineNumber: lineNumber)
        case "python":
            return parsePythonSymbol(line: trimmed, lineNumber: lineNumber)
        default:
            return nil
        }
    }

    private static func parseSwiftSymbol(line: String, lineNumber: Int) -> OutlineItem? {
        if line.starts(with: "func ") || line.contains(" func ") {
            return OutlineItem(
                title: extractSymbolName(line: line, keyword: "func") ?? "function",
                type: .symbol(kind: .function), lineNumber: lineNumber, level: 1
            )
        }
        if line.starts(with: "class ") || line.contains(" class ") {
            return OutlineItem(
                title: extractSymbolName(line: line, keyword: "class") ?? "Class",
                type: .symbol(kind: .classType), lineNumber: lineNumber, level: 0
            )
        }
        if line.starts(with: "struct ") || line.contains(" struct ") {
            return OutlineItem(
                title: extractSymbolName(line: line, keyword: "struct") ?? "Struct",
                type: .symbol(kind: .structType), lineNumber: lineNumber, level: 0
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
        return String(line[nameRange]).trimmingCharacters(in: .whitespaces)
    }

    private static func parseRustSymbol(line: String, lineNumber: Int) -> OutlineItem? {
        guard line.starts(with: "fn ") || line.starts(with: "pub fn ") ||
              line.starts(with: "struct ") || line.starts(with: "pub struct ") else { return nil }

        guard let match = rustSymbolRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let keywordRange = Range(match.range(at: 1), in: line),
              let nameRange = Range(match.range(at: 2), in: line) else { return nil }

        let keyword = String(line[keywordRange])
        let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
        let kind: SymbolKind = keyword == "fn" ? .function : .structType

        return OutlineItem(title: name, type: .symbol(kind: kind), lineNumber: lineNumber, level: kind == .function ? 1 : 0)
    }

    private static func parsePythonSymbol(line: String, lineNumber: Int) -> OutlineItem? {
        guard line.starts(with: "def ") || line.starts(with: "class ") else { return nil }

        guard let match = pythonSymbolRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let keywordRange = Range(match.range(at: 1), in: line),
              let nameRange = Range(match.range(at: 2), in: line) else { return nil }

        let keyword = String(line[keywordRange])
        let name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
        let kind: SymbolKind = keyword == "def" ? .function : .classType

        return OutlineItem(title: name, type: .symbol(kind: kind), lineNumber: lineNumber, level: kind == .function ? 1 : 0)
    }
    
    private static func appendItem(
        _ item: OutlineItem,
        to items: inout [OutlineItem],
        using stack: inout [OutlineItem]
    ) -> [OutlineItem] {
        if item.level == 0 || stack.isEmpty {
            items.append(item)
            stack = [item]
        } else {
            // Find the appropriate parent
            while !stack.isEmpty && stack.last!.level >= item.level {
                stack.removeLast()
            }
            
            if stack.last != nil {
                if var lastItem = items.last {
                    var newChildren = lastItem.children
                    newChildren.append(item)
                    lastItem.children = newChildren
                    items[items.count - 1] = lastItem
                }
            } else {
                items.append(item)
            }
            
            stack.append(item)
        }
        
        return items
    }
}

// MARK: - Outline Navigator View

/// Xcode-style outline navigator sidebar
struct OutlineNavigatorView: View {
    let items: [OutlineItem]
    let currentLine: Int
    let onSelect: (OutlineItem) -> Void
    
    @State private var expandedItems: Set<UUID> = []
    @State private var hoveredItem: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
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
            .padding(.vertical, 8)
            
            Divider()
            
            // Outline list
            ScrollViewReader { proxy in
                List {
                    ForEach(items) { item in
                        OutlineItemRow(
                            item: item,
                            currentLine: currentLine,
                            isExpanded: expandedItems.contains(item.id),
                            isHovered: hoveredItem == item.id,
                            onToggle: { toggleItem(item.id) },
                            onSelect: { onSelect(item) },
                            onHover: { isHovered in
                                hoveredItem = isHovered ? item.id : nil
                            }
                        )
                        .id(item.id)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .onChange(of: currentLine) { _, newLine in
                    scrollToCurrentLine(proxy: proxy, line: newLine)
                }
            }
        }
        .frame(width: 220)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func toggleItem(_ id: UUID) {
        if expandedItems.contains(id) {
            expandedItems.remove(id)
        } else {
            expandedItems.insert(id)
        }
    }
    
    private func expandAll() {
        let allIds = Set(items.map { $0.id })
        if expandedItems.count == allIds.count {
            expandedItems.removeAll()
        } else {
            expandedItems = allIds
        }
    }
    
    private func scrollToCurrentLine(proxy: ScrollViewProxy, line: Int) {
        // Find the item closest to current line
        if let nearestItem = items.min(by: {
            abs($0.lineNumber - line) < abs($1.lineNumber - line)
        }) {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(nearestItem.id, anchor: .center)
            }
        }
    }
}

// MARK: - Outline Item Row

struct OutlineItemRow: View {
    let item: OutlineItem
    let currentLine: Int
    let isExpanded: Bool
    let isHovered: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    let onHover: (Bool) -> Void
    
    private var isActive: Bool {
        currentLine >= item.lineNumber &&
        (item.children.isEmpty || currentLine < (item.children.first?.lineNumber ?? Int.max))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                // Expand/collapse button (if has children)
                if !item.children.isEmpty {
                    Button {
                        onToggle()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 14)
                } else {
                    Color.clear
                        .frame(width: 14)
                }
                
                // Icon
                Image(systemName: item.type.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(item.type.color)
                    .frame(width: 16, alignment: .center)
                
                // Title
                Text(item.title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(isActive ? .primary : .secondary)
                
                Spacer()
                
                // Line number
                Text("\(item.lineNumber)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isActive ? Color.accentColor.opacity(0.15) : (isHovered ? Color.secondary.opacity(0.08) : Color.clear))
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }
            .onHover { hovering in
                onHover(hovering)
            }
            
            // Children — each gets its own expand/hover state
            if isExpanded && !item.children.isEmpty {
                ForEach(item.children) { child in
                    OutlineItemRow(
                        item: child,
                        currentLine: currentLine,
                        isExpanded: false,
                        isHovered: false,
                        onToggle: {},
                        onSelect: { onSelect() },
                        onHover: { _ in }
                    )
                    .padding(.leading, 16)
                }
            }
        }
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
        onSelect: { item in
            print("Selected: \(item.title) at line \(item.lineNumber)")
        }
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
