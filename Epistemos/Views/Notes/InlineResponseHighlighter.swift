// InlineResponseHighlighter.swift
//
// Inline AI response annotations for code editor.
// Highlights relevant code sections with hoverable advice badges.
// Unlike prose editor (append mode), this overlays intelligence directly on code.
//
// 2026-04-07.

import SwiftUI

// MARK: - Inline Response Highlighter

struct InlineResponseHighlighter: View {
    let annotations: [InlineResponseAnnotation]
    let code: String
    let onHoverAnnotation: (InlineResponseAnnotation?) -> Void
    let onDismissAnnotation: (UUID) -> Void
    let onNavigateToLine: (Int) -> Void
    
    @State private var hoveredID: UUID?
    @State private var expandedAnnotation: UUID?
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Highlight overlays for each annotation
            ForEach(annotations) { annotation in
                AnnotationHighlight(
                    annotation: annotation,
                    code: code,
                    isHovered: hoveredID == annotation.id,
                    isExpanded: expandedAnnotation == annotation.id,
                    onHover: { isHovered in
                        hoveredID = isHovered ? annotation.id : nil
                        onHoverAnnotation(isHovered ? annotation : nil)
                    },
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedAnnotation == annotation.id {
                                expandedAnnotation = nil
                            } else {
                                expandedAnnotation = annotation.id
                            }
                        }
                        onNavigateToLine(annotation.lineNumber)
                    },
                    onDismiss: {
                        onDismissAnnotation(annotation.id)
                    }
                )
            }
        }
    }
}

// MARK: - Annotation Highlight

struct AnnotationHighlight: View {
    let annotation: InlineResponseAnnotation
    let code: String
    let isHovered: Bool
    let isExpanded: Bool
    let onHover: (Bool) -> Void
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    @State private var lineHeight: CGFloat = 17  // Approximate line height
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background highlight
                highlightBackground
                    .position(
                        x: geometry.size.width / 2,
                        y: calculateYPosition(in: geometry.size.height)
                    )
                
                // Badge/indicator
                annotationBadge
                    .position(
                        x: geometry.size.width - 16,
                        y: calculateYPosition(in: geometry.size.height)
                    )
            }
        }
        .onHover { hovering in
            onHover(hovering)
        }
        .onTapGesture {
            onTap()
        }
    }
    
    // MARK: - Highlight Background
    
    @ViewBuilder
    private var highlightBackground: some View {
        if isHovered || isExpanded {
            RoundedRectangle(cornerRadius: 4)
                .fill(annotation.type.color.opacity(annotation.severity.opacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(annotation.type.color.opacity(0.5), lineWidth: isHovered ? 2 : 1)
                )
                .frame(width: 200, height: max(lineHeight, 24))
                .shadow(color: annotation.type.color.opacity(0.2), radius: 4, x: 0, y: 2)
        } else {
            // Subtle indicator when not hovered
            HStack {
                Rectangle()
                    .fill(annotation.type.color)
                    .frame(width: 3)
                
                Spacer()
            }
            .frame(width: 200, height: lineHeight)
        }
    }
    
    // MARK: - Annotation Badge
    
    @ViewBuilder
    private var annotationBadge: some View {
        if isHovered || isExpanded {
            // Expanded tooltip view
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: annotation.type.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(annotation.type.color)
                    
                    Text(annotation.type.description)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                
                // Advice text
                Text(annotation.text)
                    .font(.system(size: 11))
                    .lineSpacing(1.4)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    
                // Footer
                HStack {
                    Text("Line \(annotation.lineNumber)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    
                    Spacer()
                    
                    if annotation.severity == .important {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(10)
            .frame(width: 280, alignment: .leading)
            .background(.ultraThinMaterial)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(annotation.type.color.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            .offset(x: 20, y: -10)
            .zIndex(100)
        } else {
            // Compact badge
            HStack(spacing: 4) {
                Image(systemName: annotation.type.icon)
                    .font(.system(size: 8))
                
                if annotation.severity == .important {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 7, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(annotation.type.color)
            .cornerRadius(4)
            .shadow(color: annotation.type.color.opacity(0.4), radius: 3, x: 0, y: 1)
        }
    }
    
    private func calculateYPosition(in totalHeight: CGFloat) -> CGFloat {
        // Calculate Y position based on line number
        // This is approximate - in reality would need actual text layout metrics
        let approximateLineHeight: CGFloat = 17
        let y = CGFloat(annotation.lineNumber - 1) * approximateLineHeight + (approximateLineHeight / 2)
        return min(y, totalHeight - 20)
    }
}

// MARK: - Inline Annotation Line View

/// Alternative: Shows annotations directly inline with line numbers
struct InlineAnnotationLineView: View {
    let lineNumber: Int
    let code: String
    let annotation: InlineResponseAnnotation?
    let isHovered: Bool
    let onHover: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Line number
            Text("\(lineNumber)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)
            
            // Code with potential annotation
            ZStack(alignment: .leading) {
                // Annotation background if present
                if let annotation = annotation {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(annotation.type.color.opacity(isHovered ? 0.2 : 0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(annotation.type.color.opacity(isHovered ? 0.5 : 0.2), lineWidth: 1)
                        )
                }
                
                HStack(spacing: 8) {
                    Text(code)
                        .font(.system(size: 12, design: .monospaced))
                    
                    if let annotation = annotation {
                        // Inline badge
                        HStack(spacing: 3) {
                            Image(systemName: annotation.type.icon)
                                .font(.system(size: 8))
                            
                            if isHovered {
                                Text(annotation.type.description)
                                    .font(.system(size: 9))
                            }
                        }
                        .foregroundStyle(annotation.type.color)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(annotation.type.color.opacity(0.15))
                        .cornerRadius(3)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
            }
            
            Spacer()
        }
        .background(isHovered ? Color.secondary.opacity(0.05) : Color.clear)
        .onHover { hovering in
            onHover(hovering)
        }
    }
}

// MARK: - Annotation Summary Bar

/// Bottom bar showing summary of all inline annotations
struct InlineAnnotationSummaryBar: View {
    let annotations: [InlineResponseAnnotation]
    let onClearAll: () -> Void
    let onNavigateToAnnotation: (InlineResponseAnnotation) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Icon
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.purple)
                
                // Count by type
                HStack(spacing: 8) {
                    ForEach(groupedAnnotations.sorted(by: { $0.value > $1.value }), id: \.key) { type, count in
                        HStack(spacing: 3) {
                            Image(systemName: type.icon)
                                .font(.system(size: 9))
                            Text("\(count)")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(type.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(type.color.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Total count
                Text("\(annotations.count) annotation\(annotations.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Button {
                    onClearAll()
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear all annotations")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
    
    private var groupedAnnotations: [InlineResponseAnnotation.AnnotationType: Int] {
        Dictionary(grouping: annotations, by: { $0.type })
            .mapValues { $0.count }
    }
}

// MARK: - Mode Toggle Button

/// Toggle between Focused and Inline response modes
struct CodeAskBarModeToggle: View {
    @Binding var mode: CodeAskBarResponseMode
    let availableModes: [CodeAskBarResponseMode]
    let onChange: (CodeAskBarResponseMode) -> Void
    
    var body: some View {
        Picker("", selection: $mode) {
            ForEach(availableModes, id: \.self) { m in
                Image(systemName: m.icon)
                    .tag(m)
                    .help(m.description)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 80)
        .onChange(of: mode) { _, newMode in
            onChange(newMode)
        }
    }
}

// MARK: - Ask Bar Input with Mode Toggle

struct CodeAskBarInput: View {
    @Binding var query: String
    @Binding var responseMode: CodeAskBarResponseMode
    let availableModes: [CodeAskBarResponseMode]
    let isQuerying: Bool
    let onSubmit: () -> Void
    let onModeChange: (CodeAskBarResponseMode) -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // AI Icon
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            
            // Text field
            TextField("Ask about this code...", text: $query, axis: .vertical)
                .font(.system(size: 13))
                .lineLimit(1...3)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .disabled(isQuerying)
            
            if isQuerying {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.8)
            }
            
            if availableModes.count > 1 {
                CodeAskBarModeToggle(
                    mode: $responseMode,
                    availableModes: availableModes,
                    onChange: onModeChange
                )
            }
            
            // Send button
            Button {
                onSubmit()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(query.isEmpty ? Color.secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(query.isEmpty || isQuerying)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isFocused ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview("Inline Annotations") {
    let sampleAnnotations = [
        InlineResponseAnnotation(
            text: "Consider using vDSP for vectorized operations - much faster than manual loops",
            codeRange: NSRange(location: 0, length: 50),
            lineNumber: 5,
            type: .optimization,
            severity: .suggestion,
            relatedQuery: "How can I optimize this?"
        ),
        InlineResponseAnnotation(
            text: "This variable is unused - can be removed",
            codeRange: NSRange(location: 100, length: 30),
            lineNumber: 12,
            type: .warning,
            severity: .important,
            relatedQuery: "How can I optimize this?"
        ),
        InlineResponseAnnotation(
            text: "Similar pattern found in your vault note 'Vector Operations'",
            codeRange: NSRange(location: 200, length: 40),
            lineNumber: 20,
            type: .pattern,
            severity: .info,
            relatedQuery: "How can I optimize this?"
        )
    ]
    
    InlineResponseHighlighter(
        annotations: sampleAnnotations,
        code: "Sample code here",
        onHoverAnnotation: { _ in },
        onDismissAnnotation: { _ in },
        onNavigateToLine: { _ in }
    )
    .frame(height: 400)
    .background(Color.gray.opacity(0.1))
    .padding()
}

#Preview("Inline Annotation Summary Bar") {
    let sampleAnnotations = [
        InlineResponseAnnotation(
            text: "Test",
            codeRange: NSRange(),
            lineNumber: 1,
            type: .optimization,
            severity: .suggestion,
            relatedQuery: ""
        ),
        InlineResponseAnnotation(
            text: "Test",
            codeRange: NSRange(),
            lineNumber: 2,
            type: .warning,
            severity: .important,
            relatedQuery: ""
        ),
        InlineResponseAnnotation(
            text: "Test",
            codeRange: NSRange(),
            lineNumber: 3,
            type: .pattern,
            severity: .info,
            relatedQuery: ""
        )
    ]
    
    InlineAnnotationSummaryBar(
        annotations: sampleAnnotations,
        onClearAll: {},
        onNavigateToAnnotation: { _ in }
    )
}

#Preview("Ask Bar Input") {
    @Previewable @State var query = ""
    @Previewable @State var mode: CodeAskBarResponseMode = .inline
    
    CodeAskBarInput(
        query: $query,
        responseMode: $mode,
        availableModes: CodeAskBarResponseMode.allCases,
        isQuerying: false,
        onSubmit: {},
        onModeChange: { _ in }
    )
    .padding()
}
