// DiffPreviewView.swift
//
// Interactive diff card for AI file edit operations. Shows green/red
// line-by-line preview with Apply/Reject buttons. Renders inside
// MessageBubble when a response contains file-edit tool_use blocks.
//
// 2026-04-06.

import SwiftUI

// MARK: - Diff Line Model

enum EditDiffKind {
    case context
    case removed
    case added
}

struct EditDiffLine: Identifiable {
    let id = UUID()
    let kind: EditDiffKind
    let text: String
    let lineNumber: Int?
}

// MARK: - Diff Preview View

struct DiffPreviewView: View {
    let fileName: String
    let operations: [FileEditOperation]
    let originalLines: [String]
    let onApply: () -> Void
    let onReject: () -> Void

    @State private var applied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill.viewfinder")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(fileName)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(operations.count) edit\(operations.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            Divider().opacity(0.15)

            // Diff lines
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(diffLines.enumerated()), id: \.offset) { _, line in
                        diffLineRow(line)
                    }
                }
            }
            .frame(maxHeight: 400)

            Divider().opacity(0.15)

            // Action buttons
            HStack(spacing: 8) {
                if applied {
                    Label("Applied", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button {
                        onApply()
                        withAnimation(.spring(response: 0.3)) { applied = true }
                    } label: {
                        Label("Apply", systemImage: "checkmark")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.small)

                    Button {
                        onReject()
                    } label: {
                        Label("Reject", systemImage: "xmark")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                // Operation explanations
                ForEach(operations.indices, id: \.self) { i in
                    if let explanation = operations[i].explanation {
                        Text(explanation)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Diff Computation

    private var diffLines: [EditDiffLine] {
        var lines: [EditDiffLine] = []
        for op in operations {
            let startIdx = max(0, op.startLine - 1)
            let endIdx = min(op.endLine, originalLines.count)

            // Context before (1 line)
            if startIdx > 0 {
                lines.append(EditDiffLine(kind: .context, text: originalLines[startIdx - 1], lineNumber: op.startLine - 1))
            }

            // Removed lines
            for i in startIdx..<endIdx {
                lines.append(EditDiffLine(kind: .removed, text: originalLines[i], lineNumber: i + 1))
            }

            // Added lines
            let replacementLines = op.replacement.components(separatedBy: "\n")
            for (i, line) in replacementLines.enumerated() {
                lines.append(EditDiffLine(kind: .added, text: line, lineNumber: op.startLine + i))
            }

            // Context after (1 line)
            if endIdx < originalLines.count {
                lines.append(EditDiffLine(kind: .context, text: originalLines[endIdx], lineNumber: endIdx + 1))
            }
        }
        return lines
    }

    @ViewBuilder
    private func diffLineRow(_ line: EditDiffLine) -> some View {
        HStack(spacing: 0) {
            // Line number
            Text(line.lineNumber.map { String($0) } ?? "")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 32, alignment: .trailing)
                .padding(.trailing, 6)

            // Prefix
            Text(prefix(for: line.kind))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(color(for: line.kind))
                .frame(width: 14)

            // Content
            Text(line.text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(color(for: line.kind).opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(background(for: line.kind))
    }

    private func prefix(for kind: EditDiffKind) -> String {
        switch kind {
        case .context: " "
        case .removed: "-"
        case .added: "+"
        }
    }

    private func color(for kind: EditDiffKind) -> Color {
        switch kind {
        case .context: .secondary
        case .removed: .red
        case .added: .green
        }
    }

    private func background(for kind: EditDiffKind) -> Color {
        switch kind {
        case .context: .clear
        case .removed: .red.opacity(0.08)
        case .added: .green.opacity(0.08)
        }
    }
}
