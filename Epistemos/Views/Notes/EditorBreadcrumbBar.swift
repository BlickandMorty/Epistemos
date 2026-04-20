// EditorBreadcrumbBar.swift
//
// Xcode-style breadcrumb navigation bar for code editor.
// Shows file path and symbol hierarchy: File > Class > Method
//
// 2026-04-07.

import SwiftUI

// MARK: - Breadcrumb Item

struct EditorBreadcrumbItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let lineNumber: Int
    let type: BreadcrumbType
    
    enum BreadcrumbType {
        case file
        case folder
        case symbol(OutlineItemType)
        case section
    }
}

// MARK: - Breadcrumb Bar

struct EditorBreadcrumbBar: View {
    let items: [EditorBreadcrumbItem]
    let currentLine: Int
    let onSelect: (EditorBreadcrumbItem) -> Void
    
    @State private var hoveredItem: UUID?
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                BreadcrumbButton(
                    item: item,
                    isHovered: hoveredItem == item.id,
                    isLast: index == items.count - 1,
                    onHover: { isHovered in
                        hoveredItem = isHovered ? item.id : nil
                    },
                    onSelect: {
                        onSelect(item)
                    }
                )
                
                if index < items.count - 1 {
                    BreadcrumbSeparator()
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(.separator)
                .opacity(0.5),
            alignment: .bottom
        )
    }
}

// MARK: - Breadcrumb Button

struct BreadcrumbButton: View {
    let item: EditorBreadcrumbItem
    let isHovered: Bool
    let isLast: Bool
    let onHover: (Bool) -> Void
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(iconColor)
                
                Text(item.title)
                    .font(.system(size: 12))
                    .foregroundStyle(textColor)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            onHover(hovering)
        }
    }
    
    private var iconColor: Color {
        switch item.type {
        case .file:
            return .accentColor
        case .folder:
            return .secondary
        case .symbol(let type):
            return type.color
        case .section:
            return .secondary
        }
    }
    
    private var textColor: Color {
        isLast ? .primary : .secondary
    }
    
    private var backgroundColor: Color {
        if isHovered {
            return Color.secondary.opacity(0.15)
        }
        return Color.clear
    }
}

// MARK: - Breadcrumb Separator

struct BreadcrumbSeparator: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 4)
    }
}

// MARK: - Smart Breadcrumb Builder

struct BreadcrumbBuilder {
    
    static func buildBreadcrumbs(
        filePath: String?,
        outlineItems: [OutlineItem],
        currentLine: Int
    ) -> [EditorBreadcrumbItem] {
        var breadcrumbs: [EditorBreadcrumbItem] = []
        
        // Add file breadcrumb
        if let path = filePath {
            let fileName = URL(fileURLWithPath: path).lastPathComponent
            breadcrumbs.append(EditorBreadcrumbItem(
                title: fileName,
                icon: iconForFile(path: path),
                lineNumber: 1,
                type: .file
            ))
        } else {
            breadcrumbs.append(EditorBreadcrumbItem(
                title: "Untitled",
                icon: "doc.text",
                lineNumber: 1,
                type: .file
            ))
        }
        
        // Find the most specific outline item containing current line
        let containingItems = findContainingItems(outlineItems, currentLine: currentLine)
        
        for item in containingItems {
            let breadcrumb = EditorBreadcrumbItem(
                title: item.title,
                icon: item.type.icon,
                lineNumber: item.lineNumber,
                type: .symbol(item.type)
            )
            breadcrumbs.append(breadcrumb)
        }
        
        return breadcrumbs
    }
    
    private static func findContainingItems(
        _ items: [OutlineItem],
        currentLine: Int
    ) -> [OutlineItem] {
        var result: [OutlineItem] = []
        
        for item in items {
            if item.lineNumber <= currentLine {
                // Check if this is the most specific item
                if item.children.isEmpty {
                    result.append(item)
                } else {
                    // Check children
                    let childResults = findContainingItems(item.children, currentLine: currentLine)
                    if childResults.isEmpty {
                        result.append(item)
                    } else {
                        result.append(contentsOf: childResults)
                    }
                }
            }
        }
        
        // Return only the most specific item (last in hierarchy)
        return Array(result.prefix(2))
    }
    
    private static func iconForFile(path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        
        switch ext {
        case "swift": return "swift"
        case "rs": return "r.square"
        case "py": return "p.square"
        case "js", "ts", "jsx", "tsx": return "j.square"
        case "md", "markdown": return "doc.text"
        case "json": return "curlybraces"
        case "html", "htm": return "h.square"
        case "css", "scss", "less": return "c.square"
        default: return "doc.plaintext"
        }
    }
}

// MARK: - Preview

#Preview("Breadcrumb Bar") {
    let sampleItems = [
        EditorBreadcrumbItem(
            title: "README.md",
            icon: "doc.text",
            lineNumber: 1,
            type: .file
        ),
        EditorBreadcrumbItem(
            title: "Jinja",
            icon: "text.formatting.header.1",
            lineNumber: 1,
            type: .symbol(.markdownHeader(level: 1))
        ),
        EditorBreadcrumbItem(
            title: "Features",
            icon: "text.formatting.header.2",
            lineNumber: 36,
            type: .symbol(.markdownHeader(level: 2))
        ),
        EditorBreadcrumbItem(
            title: "Not Supported Features",
            icon: "text.formatting.header.3",
            lineNumber: 198,
            type: .symbol(.markdownHeader(level: 3))
        )
    ]
    
    EditorBreadcrumbBar(
        items: sampleItems,
        currentLine: 200,
        onSelect: { _ in }
    )
}

#Preview("Breadcrumb Builder") {
    EditorBreadcrumbBar(
        items: BreadcrumbBuilder.buildBreadcrumbs(
            filePath: FileManager.default.temporaryDirectory
                .appendingPathComponent("README.md")
                .path,
            outlineItems: [
                OutlineItem(
                    title: "Jinja",
                    type: .markdownHeader(level: 1),
                    lineNumber: 1,
                    level: 0,
                    children: [
                        OutlineItem(
                            title: "Features",
                            type: .markdownHeader(level: 2),
                            lineNumber: 36,
                            level: 1,
                            children: [
                                OutlineItem(
                                    title: "Supported Features",
                                    type: .markdownHeader(level: 3),
                                    lineNumber: 41,
                                    level: 2
                                ),
                                OutlineItem(
                                    title: "Not Supported Features",
                                    type: .markdownHeader(level: 3),
                                    lineNumber: 198,
                                    level: 2
                                )
                            ]
                        )
                    ]
                )
            ],
            currentLine: 200
        ),
        currentLine: 200,
        onSelect: { _ in }
    )
}
