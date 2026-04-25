// LineBreakdownPanel.swift
//
// Per-line AI response breakdown for the code editor.
// Replaces the overlay-based InlineResponseHighlighter with a flat panel
// at the top of the editor showing per-line advice with navigation.
//
// Two response modes for Code Ask Bar:
// 1. Direct answer: flat "Epistemos" labeled answer box
// 2. Line analysis: per-line breakdown with navigation + action buttons

import SwiftUI

// MARK: - Direct Answer Box

/// Flat answer box for direct AI responses in the code editor.
/// Labeled "Epistemos" — not a modal overlay, sits inline in the editor layout.
struct EpistemosAnswerBox: View {
    let response: FocusedCodeResponse
    let onDismiss: () -> Void
    let onApplyCode: (String) -> Void
    let onNavigateToLine: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12))
                    .foregroundStyle(.purple)

                Text("Epistemos")
                    .font(.system(size: 12, weight: .semibold))

                Spacer()

                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.purple.opacity(0.05))

            if isExpanded {
                Divider()

                // Summary
                Text(response.summary)
                    .font(.system(size: 12))
                    .lineSpacing(1.4)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Code blocks (if any)
                ForEach(response.sections) { section in
                    ForEach(section.codeBlocks) { block in
                        VStack(alignment: .leading, spacing: 0) {
                            Divider()
                            HStack {
                                Text(block.language.uppercased())
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(block.code, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 9))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)

                                Button { onApplyCode(block.code) } label: {
                                    Text("Apply")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.05))

                            Text(block.code)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.textBackgroundColor))
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.purple.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Line Breakdown Panel

/// Per-line AI response breakdown panel.
/// Shows sorted annotations with line numbers; clicking navigates to that line.
struct LineBreakdownPanel: View {
    let annotations: [InlineResponseAnnotation]
    let onNavigateToLine: (Int) -> Void
    let onExplainFurther: (InlineResponseAnnotation) -> Void
    let onDismiss: (UUID) -> Void
    let onClearAll: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedAnnotation: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "list.number")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)

                Text("Line Analysis")
                    .font(.system(size: 12, weight: .semibold))

                Text("\(annotations.count) \(annotations.count == 1 ? "item" : "items")")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)

                Spacer()

                Button { onClearAll() } label: {
                    Text("Clear")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.03))

            Divider()

            // Annotation rows
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sortedAnnotations) { annotation in
                        LineBreakdownRow(
                            annotation: annotation,
                            isSelected: selectedAnnotation == annotation.id,
                            onTap: {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                                    selectedAnnotation = selectedAnnotation == annotation.id ? nil : annotation.id
                                }
                                onNavigateToLine(annotation.lineNumber)
                            },
                            onExplainFurther: { onExplainFurther(annotation) },
                            onDismiss: { onDismiss(annotation.id) }
                        )

                        if annotation.id != sortedAnnotations.last?.id {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var sortedAnnotations: [InlineResponseAnnotation] {
        annotations.sorted { $0.lineNumber < $1.lineNumber }
    }
}

// MARK: - Line Breakdown Row

struct LineBreakdownRow: View {
    let annotation: InlineResponseAnnotation
    let isSelected: Bool
    let onTap: () -> Void
    let onExplainFurther: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            Button { onTap() } label: {
                HStack(spacing: 8) {
                    // Line number badge
                    Text("L\(annotation.lineNumber)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(annotation.type.color.opacity(0.8))
                        .cornerRadius(4)
                        .frame(width: 42)

                    // Type icon
                    Image(systemName: annotation.type.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(annotation.type.color)

                    // Description
                    Text(annotation.text)
                        .font(.system(size: 11))
                        .lineLimit(isSelected ? nil : 1)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)

                    Spacer()

                    // Severity indicator
                    if annotation.severity == .important {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? annotation.type.color.opacity(0.08) : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Action buttons (shown when selected)
            if isSelected {
                HStack(spacing: 8) {
                    Spacer().frame(width: 52)

                    Button { onExplainFurther() } label: {
                        Label("Explain", systemImage: "text.bubble")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button { onDismiss() } label: {
                        Label("Dismiss", systemImage: "xmark")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Preview

#Preview("Epistemos Answer Box") {
    EpistemosAnswerBox(
        response: FocusedCodeResponse(
            query: "How to optimize this?",
            summary: "Use Accelerate framework's vDSP functions for vectorized operations instead of manual loops.",
            sections: [
                .init(
                    title: "Suggestion",
                    content: "Replace the manual loop with vDSP_sve.",
                    type: .suggestion,
                    codeBlocks: [
                        .init(language: "swift", code: "vDSP_sve(array, 1, &result, vDSP_Length(n))", explanation: nil)
                    ]
                )
            ],
            relatedCodeRanges: []
        ),
        onDismiss: {},
        onApplyCode: { _ in },
        onNavigateToLine: { _ in }
    )
    .frame(width: 500)
    .padding()
}

#Preview("Line Breakdown Panel") {
    LineBreakdownPanel(
        annotations: [
            InlineResponseAnnotation(
                text: "Refactor: extract duplicated logic into shared helper",
                codeRange: NSRange(), lineNumber: 3,
                type: .suggestion, severity: .suggestion, relatedQuery: ""
            ),
            InlineResponseAnnotation(
                text: "Delete unused function oldHelper()",
                codeRange: NSRange(), lineNumber: 80,
                type: .warning, severity: .important, relatedQuery: ""
            ),
            InlineResponseAnnotation(
                text: "Performance: use vDSP instead of manual loop",
                codeRange: NSRange(), lineNumber: 1458,
                type: .optimization, severity: .suggestion, relatedQuery: ""
            ),
        ],
        onNavigateToLine: { _ in },
        onExplainFurther: { _ in },
        onDismiss: { _ in },
        onClearAll: {}
    )
    .frame(width: 500)
    .padding()
}
