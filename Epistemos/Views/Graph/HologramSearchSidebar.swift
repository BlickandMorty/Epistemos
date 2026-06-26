import SwiftData
import SwiftUI

struct HologramSidebarNotesTreeSnapshot {
    let folderById: [String: GraphNodeRecord]
    let noteById: [String: GraphNodeRecord]
    let artifactById: [String: GraphNodeRecord]
    let rootFolderIds: [String]
    let childFolderIdsById: [String: [String]]
    let noteIdsByFolderId: [String: [String]]
    let looseNoteIds: [String]
    let looseArtifactIds: [String]
    let noteCountByFolderId: [String: Int]

    static let empty = HologramSidebarNotesTreeSnapshot(
        folderById: [:],
        noteById: [:],
        artifactById: [:],
        rootFolderIds: [],
        childFolderIdsById: [:],
        noteIdsByFolderId: [:],
        looseNoteIds: [],
        looseArtifactIds: [],
        noteCountByFolderId: [:]
    )
}

enum HologramSidebarNotesTreeBuilder {
    static func build(store: GraphStore) -> HologramSidebarNotesTreeSnapshot {
        let folderById = Dictionary(
            uniqueKeysWithValues: store.nodes.values
                .filter { $0.type == .folder }
                .map { ($0.id, $0) }
        )
        let noteById = Dictionary(
            uniqueKeysWithValues: store.nodes.values
                .filter { $0.type == .note }
                .map { ($0.id, $0) }
        )
        let artifactTypes = Set(GraphNodeType.appLevelCases)
        let artifactById = Dictionary(
            uniqueKeysWithValues: store.nodes.values
                .filter { artifactTypes.contains($0.type) }
                .map { ($0.id, $0) }
        )

        var childFolderIdsById: [String: [String]] = [:]
        var noteIdsByFolderId: [String: [String]] = [:]
        for folderId in folderById.keys {
            childFolderIdsById[folderId] = []
            noteIdsByFolderId[folderId] = []
        }

        var childFolderIds = Set<String>()
        var containedNoteIds = Set<String>()

        for edge in store.edges.values where edge.type == .contains {
            guard folderById[edge.sourceNodeId] != nil else { continue }

            if folderById[edge.targetNodeId] != nil {
                childFolderIdsById[edge.sourceNodeId, default: []].append(edge.targetNodeId)
                childFolderIds.insert(edge.targetNodeId)
            } else if noteById[edge.targetNodeId] != nil {
                noteIdsByFolderId[edge.sourceNodeId, default: []].append(edge.targetNodeId)
                containedNoteIds.insert(edge.targetNodeId)
            }
        }

        for folderId in folderById.keys {
            childFolderIdsById[folderId]?.sort { lhs, rhs in
                compareNodeLabels(lhs, rhs, in: folderById)
            }
            noteIdsByFolderId[folderId]?.sort { lhs, rhs in
                compareNodeLabels(lhs, rhs, in: noteById)
            }
        }

        let rootFolderIds = sortedNodeIds(folderById.keys, in: folderById)
            .filter { !childFolderIds.contains($0) }
        let looseNoteIds = sortedNodeIds(noteById.keys, in: noteById)
            .filter { !containedNoteIds.contains($0) }
        let looseArtifactIds = sortedNodeIds(artifactById.keys, in: artifactById)

        var noteCountByFolderId: [String: Int] = [:]
        for folderId in folderById.keys {
            noteCountByFolderId[folderId] = recursiveNoteCount(
                folderId: folderId,
                childFolderIdsById: childFolderIdsById,
                noteIdsByFolderId: noteIdsByFolderId,
                cache: &noteCountByFolderId
            )
        }

        return HologramSidebarNotesTreeSnapshot(
            folderById: folderById,
            noteById: noteById,
            artifactById: artifactById,
            rootFolderIds: rootFolderIds,
            childFolderIdsById: childFolderIdsById,
            noteIdsByFolderId: noteIdsByFolderId,
            looseNoteIds: looseNoteIds,
            looseArtifactIds: looseArtifactIds,
            noteCountByFolderId: noteCountByFolderId
        )
    }

    private static func sortedNodeIds<S: Sequence>(
        _ ids: S,
        in nodesById: [String: GraphNodeRecord]
    ) -> [String] where S.Element == String {
        ids.sorted { lhs, rhs in
            compareNodeLabels(lhs, rhs, in: nodesById)
        }
    }

    private static func compareNodeLabels(
        _ lhs: String,
        _ rhs: String,
        in nodesById: [String: GraphNodeRecord]
    ) -> Bool {
        let lhsLabel = nodesById[lhs]?.label ?? ""
        let rhsLabel = nodesById[rhs]?.label ?? ""
        let labelOrder = lhsLabel.localizedCaseInsensitiveCompare(rhsLabel)
        if labelOrder == .orderedSame {
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
        return labelOrder == .orderedAscending
    }

    private static func recursiveNoteCount(
        folderId: String,
        childFolderIdsById: [String: [String]],
        noteIdsByFolderId: [String: [String]],
        cache: inout [String: Int],
        visiting: Set<String> = []
    ) -> Int {
        if let cached = cache[folderId] {
            return cached
        }

        var visiting = visiting
        guard visiting.insert(folderId).inserted else {
            return noteIdsByFolderId[folderId]?.count ?? 0
        }

        let localCount = noteIdsByFolderId[folderId]?.count ?? 0
        let nestedCount = (childFolderIdsById[folderId] ?? []).reduce(0) { partial, childId in
            partial + recursiveNoteCount(
                folderId: childId,
                childFolderIdsById: childFolderIdsById,
                noteIdsByFolderId: noteIdsByFolderId,
                cache: &cache,
                visiting: visiting
            )
        }
        let totalCount = localCount + nestedCount
        cache[folderId] = totalCount
        return totalCount
    }
}

// Graph sidebar shell retained for graph navigation while the old graph-chat
// surface is removed. It intentionally has no composer, runtime picker, or
// chat submission path.
struct HologramSearchSidebar: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui

    let inspectorState: NodeInspectorState
    let modelContext: ModelContext?
    let onRevealNode: (String) -> Void

    init(
        inspectorState: NodeInspectorState,
        modelContext: ModelContext?,
        onRevealNode: @escaping (String) -> Void
    ) {
        self.inspectorState = inspectorState
        self.modelContext = modelContext
        self.onRevealNode = onRevealNode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                Text("Graph")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                Spacer(minLength: 0)
            }

            if let selected = graphState.selectedNodeId.flatMap({ graphState.store.nodes[$0] }) {
                Button {
                    onRevealNode(selected.id)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selected.label.isEmpty ? "Selected Node" : selected.label)
                            .lineLimit(1)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                        Text(selected.type.rawValue)
                            .lineLimit(1)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                Text("Select a node to inspect it.")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 300, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(ui.theme.border.opacity(0.5), lineWidth: 1)
        )
    }
}
