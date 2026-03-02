import SwiftUI

// MARK: - RelationshipBrowser
// Expandable sections showing typed relationship groups for a selected graph node.
// Grouped by GraphEdgeType with clickable rows that navigate to the linked node.

struct RelationshipBrowser: View {
    let nodeId: String
    let store: GraphStore
    let onNavigate: (String) -> Void

    private var groups: [RelationshipGroup] {
        let edges = store.edges(for: nodeId)
        var grouped: [GraphEdgeType: [RelationshipEntry]] = [:]

        for edge in edges {
            let isSource = edge.sourceNodeId == nodeId
            let otherId = isSource ? edge.targetNodeId : edge.sourceNodeId
            guard let otherNode = store.nodes[otherId] else { continue }

            let entry = RelationshipEntry(
                nodeId: otherId,
                label: otherNode.label,
                nodeType: otherNode.type,
                isOutgoing: isSource
            )
            grouped[edge.type, default: []].append(entry)
        }

        return grouped.map { RelationshipGroup(edgeType: $0.key, entries: $0.value) }
            .sorted { $0.entries.count > $1.entries.count }
    }

    @ViewBuilder
    var body: some View {
        let groups = self.groups
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Label("Relationships", systemImage: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(groups) { group in
                            RelationshipSection(group: group, onNavigate: onNavigate)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }
}

// MARK: - Data Types

private struct RelationshipEntry: Identifiable {
    let nodeId: String
    let label: String
    let nodeType: GraphNodeType
    let isOutgoing: Bool
    var id: String { nodeId }
}

private struct RelationshipGroup: Identifiable {
    let edgeType: GraphEdgeType
    let entries: [RelationshipEntry]
    var id: String { edgeType.rawValue }
}

// MARK: - Section View

private struct RelationshipSection: View {
    let group: RelationshipGroup
    let onNavigate: (String) -> Void
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.smooth(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: group.edgeType.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(group.edgeType.color)
                        .frame(width: 14)

                    Text(group.edgeType.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.8))

                    Text("(\(group.entries.count))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(group.entries) { entry in
                        RelationshipRow(entry: entry, edgeType: group.edgeType, onNavigate: onNavigate)
                    }
                }
                .padding(.leading, 22)
            }
        }
    }
}

// MARK: - Row View

private struct RelationshipRow: View {
    let entry: RelationshipEntry
    let edgeType: GraphEdgeType
    let onNavigate: (String) -> Void

    var body: some View {
        Button { onNavigate(entry.nodeId) } label: {
            HStack(spacing: 6) {
                // Direction arrow for semantic edge types
                if edgeType.isDirectional {
                    Image(systemName: entry.isOutgoing ? "arrow.right" : "arrow.left")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }

                Circle()
                    .fill(entry.nodeType.swiftUIColor)
                    .frame(width: 6, height: 6)

                Text(entry.label)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.75))
                    .lineLimit(1)

                Spacer()

                Text(entry.nodeType.displayName)
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - GraphEdgeType UI Extensions

extension GraphEdgeType {
    var displayName: String {
        switch self {
        case .reference:   return "References"
        case .contains:    return "Contains"
        case .tagged:      return "Tagged"
        case .mentions:    return "Mentions"
        case .cites:       return "Cites"
        case .authored:    return "Authored"
        case .related:     return "Related"
        case .quotes:      return "Quotes"
        case .supports:    return "Supports"
        case .contradicts: return "Contradicts"
        case .expands:     return "Expands"
        case .questions:   return "Questions"
        }
    }

    var icon: String {
        switch self {
        case .reference:   return "arrow.right"
        case .contains:    return "folder"
        case .tagged:      return "number"
        case .mentions:    return "at"
        case .cites:       return "quote.opening"
        case .authored:    return "person"
        case .related:     return "link"
        case .quotes:      return "text.quote"
        case .supports:    return "checkmark.circle"
        case .contradicts: return "xmark.circle"
        case .expands:     return "arrow.up.left.and.arrow.down.right"
        case .questions:   return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .supports:    return .green
        case .contradicts: return .red
        case .expands:     return .blue
        case .questions:   return .orange
        case .cites:       return Color(red: 0.69, green: 0.32, blue: 0.87) // purple
        case .quotes:      return Color(red: 0.69, green: 0.32, blue: 0.87) // purple
        default:           return .secondary
        }
    }

    /// Whether this edge type has meaningful direction (source → target).
    var isDirectional: Bool {
        switch self {
        case .supports, .contradicts, .expands, .questions, .cites, .contains:
            return true
        default:
            return false
        }
    }
}
