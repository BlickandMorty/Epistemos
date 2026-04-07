// MinimapAnnotationsView.swift
//
// Overlay for code editor minimap showing section labels.
// Provides inline explanations of minimap regions (headers, MARKs, symbols).
//
// 2026-04-07.

import SwiftUI

// MARK: - Minimap Annotation

struct MinimapAnnotation: Identifiable {
    let id = UUID()
    let title: String
    let type: OutlineItemType
    let yPosition: CGFloat  // 0.0 to 1.0 (relative position in document)
    let height: CGFloat     // Relative height of the section
}

// MARK: - Minimap Annotations View

struct MinimapAnnotationsView: View {
    let annotations: [MinimapAnnotation]
    let minimapHeight: CGFloat
    let onSelect: (MinimapAnnotation) -> Void
    
    @State private var hoveredAnnotation: UUID?
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            Color.clear
            
            // Annotation labels
            ForEach(annotations) { annotation in
                MinimapAnnotationLabel(
                    annotation: annotation,
                    isHovered: hoveredAnnotation == annotation.id,
                    onHover: { isHovered in
                        hoveredAnnotation = isHovered ? annotation.id : nil
                    },
                    onSelect: {
                        onSelect(annotation)
                    }
                )
                .position(
                    x: 60, // Position on the left side of minimap
                    y: annotation.yPosition * minimapHeight
                )
            }
        }
        .frame(width: 120)
    }
}

// MARK: - Minimap Annotation Label

struct MinimapAnnotationLabel: View {
    let annotation: MinimapAnnotation
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onSelect: () -> Void
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: annotation.type.icon)
                    .font(.system(size: 8))
                    .foregroundStyle(annotation.type.color)
                
                Text(annotation.title)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(isHovered ? .primary : .secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundStyle)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(annotation.type.color.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            onHover(hovering)
        }
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var backgroundStyle: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isHovered ? Color(NSColor.controlBackgroundColor) : Color(NSColor.controlBackgroundColor).opacity(0.9))
    }
}

// MARK: - Annotation Builder

struct MinimapAnnotationBuilder {
    
    static func buildAnnotations(
        from outlineItems: [OutlineItem],
        totalLines: Int
    ) -> [MinimapAnnotation] {
        var annotations: [MinimapAnnotation] = []
        
        for item in outlineItems {
            addAnnotations(for: item, totalLines: totalLines, into: &annotations)
        }
        
        return annotations.sorted { $0.yPosition < $1.yPosition }
    }
    
    private static func addAnnotations(
        for item: OutlineItem,
        totalLines: Int,
        into annotations: inout [MinimapAnnotation]
    ) {
        let yPosition = CGFloat(item.lineNumber - 1) / CGFloat(max(totalLines - 1, 1))
        
        // Calculate section height based on children
        let endLine: Int
        if let lastChild = item.children.last {
            endLine = lastChild.lineNumber
        } else {
            endLine = item.lineNumber + 20 // Default section size
        }
        let height = CGFloat(endLine - item.lineNumber) / CGFloat(max(totalLines, 1))
        
        let annotation = MinimapAnnotation(
            title: truncateTitle(item.title),
            type: item.type,
            yPosition: yPosition,
            height: max(height, 0.02) // Minimum height for visibility
        )
        
        annotations.append(annotation)
        
        // Recursively add children
        for child in item.children {
            addAnnotations(for: child, totalLines: totalLines, into: &annotations)
        }
    }
    
    private static func truncateTitle(_ title: String) -> String {
        let maxLength = 20
        if title.count > maxLength {
            return String(title.prefix(maxLength - 3)) + "..."
        }
        return title
    }
}

// MARK: - Minimap Container View

/// Combines the minimap with annotations overlay
struct MinimapWithAnnotations: View {
    let content: String
    let outlineItems: [OutlineItem]
    let totalLines: Int
    let onNavigateToLine: (Int) -> Void
    
    @State private var minimapHeight: CGFloat = 0
    
    private var annotations: [MinimapAnnotation] {
        MinimapAnnotationBuilder.buildAnnotations(
            from: outlineItems,
            totalLines: max(totalLines, 1)
        )
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // The actual minimap is rendered by CodeEditSourceEditor
            // We overlay annotations on top
            
            MinimapAnnotationsView(
                annotations: annotations,
                minimapHeight: minimapHeight,
                onSelect: { annotation in
                    let line = Int(annotation.yPosition * CGFloat(totalLines)) + 1
                    onNavigateToLine(line)
                }
            )
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        minimapHeight = geometry.size.height
                    }
                    .onChange(of: geometry.size.height) { _, newHeight in
                        minimapHeight = newHeight
                    }
            }
        )
    }
}

// MARK: - Preview

#Preview("Minimap Annotations") {
    let sampleAnnotations = [
        MinimapAnnotation(
            title: "Jinja",
            type: .markdownHeader(level: 1),
            yPosition: 0.02,
            height: 0.1
        ),
        MinimapAnnotation(
            title: "Requirements",
            type: .markdownHeader(level: 2),
            yPosition: 0.15,
            height: 0.05
        ),
        MinimapAnnotation(
            title: "Installation",
            type: .markdownHeader(level: 2),
            yPosition: 0.25,
            height: 0.08
        ),
        MinimapAnnotation(
            title: "Features",
            type: .markdownHeader(level: 2),
            yPosition: 0.45,
            height: 0.2
        ),
        MinimapAnnotation(
            title: "Supported Features",
            type: .markdownHeader(level: 3),
            yPosition: 0.5,
            height: 0.15
        ),
        MinimapAnnotation(
            title: "Not Supported Features",
            type: .markdownHeader(level: 3),
            yPosition: 0.7,
            height: 0.1
        ),
        MinimapAnnotation(
            title: "Usage",
            type: .markdownHeader(level: 2),
            yPosition: 0.85,
            height: 0.1
        )
    ]
    
    MinimapAnnotationsView(
        annotations: sampleAnnotations,
        minimapHeight: 600,
        onSelect: { annotation in
            print("Selected: \(annotation.title)")
        }
    )
    .frame(height: 600)
    .background(Color.gray.opacity(0.1))
}

#Preview("Annotation Builder") {
    let outlineItems = [
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
                    level: 1
                ),
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
                ),
                OutlineItem(
                    title: "Usage",
                    type: .markdownHeader(level: 2),
                    lineNumber: 228,
                    level: 1
                )
            ]
        )
    ]
    
    let annotations = MinimapAnnotationBuilder.buildAnnotations(
        from: outlineItems,
        totalLines: 250
    )
    
    return MinimapAnnotationsView(
        annotations: annotations,
        minimapHeight: 400,
        onSelect: { _ in }
    )
    .frame(height: 400)
    .background(Color.gray.opacity(0.1))
}
