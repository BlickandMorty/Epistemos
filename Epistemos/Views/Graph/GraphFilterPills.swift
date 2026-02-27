import SwiftUI

// MARK: - GraphFilterPills
// Floating overlay showing toggle capsule pills for each node type.
// Positioned at top-right of the graph canvas.

struct GraphFilterPills: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    /// The subset of node types displayed as pills (most important 12).
    private static let pillTypes: [GraphNodeType] = [
        .note, .idea, .brainDump, .chat, .insight, .thinker,
        .paper, .book, .source, .concept, .quote, .tag,
    ]

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.sm) {
            // Clear button — only when filters are active
            if graphState.filter.isFiltered {
                Button {
                    withAnimation(Motion.quick) {
                        graphState.filter.showAllTypes()
                        graphState.clearFocus()
                        graphState.filter.setTimelineDate(nil)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                        Text("Clear Filters")
                            .font(.epCaption)
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(theme.accent.opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(theme.accent.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }

            // Pill grid
            FlowLayout(spacing: 6) {
                ForEach(Self.pillTypes, id: \.rawValue) { nodeType in
                    filterPill(for: nodeType)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.glassBorder, lineWidth: 0.5)
        )
        .frame(maxWidth: 280)
    }

    // MARK: - Pill

    @ViewBuilder
    private func filterPill(for type: GraphNodeType) -> some View {
        let isActive = graphState.filter.activeNodeTypes.contains(type)
        let counts = graphState.filter.totalCount(in: graphState.store)
        let count = counts[type] ?? 0

        Button {
            withAnimation(Motion.quick) {
                graphState.filter.toggleType(type)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 10, weight: .medium))
                Text("\(count)")
                    .font(.epSmall)
            }
            .foregroundStyle(isActive ? pillColor(for: type) : theme.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isActive ? pillColor(for: type).opacity(0.12) : theme.glassTint.opacity(0.5))
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isActive ? pillColor(for: type).opacity(0.3) : theme.glassBorder,
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .help(type.displayName)
    }

    // MARK: - Colors

    private func pillColor(for type: GraphNodeType) -> Color {
        switch type {
        case .note:      return .blue
        case .idea:      return .yellow
        case .brainDump: return .purple
        case .chat:      return .green
        case .insight:   return .teal
        case .thinker:   return .orange
        case .paper:     return .red
        case .book:      return .brown
        case .source:    return .indigo
        case .concept:   return .pink
        case .quote:     return .cyan
        case .tag:       return .gray
        case .folder:    return .gray
        }
    }
}

// NOTE: FlowLayout is defined in PageShell.swift and shared across the app.
