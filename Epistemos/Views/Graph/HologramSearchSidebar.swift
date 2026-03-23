import SwiftUI

struct HologramSidebarNotesTreeSnapshot {
    let folderById: [String: GraphNodeRecord]
    let noteById: [String: GraphNodeRecord]
    let rootFolderIds: [String]
    let childFolderIdsById: [String: [String]]
    let noteIdsByFolderId: [String: [String]]
    let looseNoteIds: [String]
    let noteCountByFolderId: [String: Int]

    static let empty = HologramSidebarNotesTreeSnapshot(
        folderById: [:],
        noteById: [:],
        rootFolderIds: [],
        childFolderIdsById: [:],
        noteIdsByFolderId: [:],
        looseNoteIds: [],
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
                let lhsLabel = folderById[lhs]?.label ?? ""
                let rhsLabel = folderById[rhs]?.label ?? ""
                return lhsLabel.localizedCaseInsensitiveCompare(rhsLabel) == .orderedAscending
            }
            noteIdsByFolderId[folderId]?.sort { lhs, rhs in
                let lhsLabel = noteById[lhs]?.label ?? ""
                let rhsLabel = noteById[rhs]?.label ?? ""
                return lhsLabel.localizedCaseInsensitiveCompare(rhsLabel) == .orderedAscending
            }
        }

        let rootFolderIds = folderById.keys.sorted { lhs, rhs in
            let lhsLabel = folderById[lhs]?.label ?? ""
            let rhsLabel = folderById[rhs]?.label ?? ""
            return lhsLabel.localizedCaseInsensitiveCompare(rhsLabel) == .orderedAscending
        }.filter { !childFolderIds.contains($0) }

        let looseNoteIds = noteById.keys.sorted { lhs, rhs in
            let lhsLabel = noteById[lhs]?.label ?? ""
            let rhsLabel = noteById[rhs]?.label ?? ""
            return lhsLabel.localizedCaseInsensitiveCompare(rhsLabel) == .orderedAscending
        }.filter { !containedNoteIds.contains($0) }

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
            rootFolderIds: rootFolderIds,
            childFolderIdsById: childFolderIdsById,
            noteIdsByFolderId: noteIdsByFolderId,
            looseNoteIds: looseNoteIds,
            noteCountByFolderId: noteCountByFolderId
        )
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

// MARK: - HologramSidebar
// Floating left panel for the graph overlay.
// Two tabs: Notes (folder tree — note nodes only) and Query (AI-powered graph queries).

struct HologramSearchSidebar: View {
    @Environment(GraphState.self) private var graphState
    @State private var activeTab: SidebarTab = .notes
    @State private var expandedFolders: Set<String> = []
    @State private var cachedNotesTreeSnapshot = HologramSidebarNotesTreeSnapshot.empty
    @State private var cachedNotesTreeTopologyVersion = -1

    var onSelectNode: (String) -> Void

    enum SidebarTab { case notes, query }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabPills
            Divider().opacity(0.2)

            switch activeTab {
            case .notes:
                notesContent
            case .query:
                queryContent
            }
        }
        .frame(width: 400)
        .frame(maxHeight: 700)
        .onAppear {
            refreshNotesTreeSnapshotIfNeeded()
        }
        .onChange(of: graphState.graphDataVersion) { _, _ in
            refreshNotesTreeSnapshotIfNeeded()
        }
        .onChange(of: queryEngine.currentResult?.nodes.count) { _, newCount in
            if let newCount, newCount > 0 {
                withAnimation(.smooth(duration: 0.2)) { activeTab = .query }
            }
        }
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Tab Pills

    private var tabPills: some View {
        HStack(spacing: 4) {
            tabButton("Notes", icon: "doc.text", tab: .notes)
            tabButton("Query", icon: "point.3.connected.trianglepath.dotted", tab: .query)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func tabButton(_ label: String, icon: String, tab: SidebarTab) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.2)) { activeTab = tab }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(activeTab == tab ? Color.primary.opacity(0.15) : Color.clear, in: Capsule())
            .foregroundStyle(Color.primary.opacity(activeTab == tab ? 1.0 : 0.45))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notes Content (flat visible rows for lazy rendering)

    private func refreshNotesTreeSnapshotIfNeeded() {
        let topologyVersion = graphState.store.topologyVersion
        guard cachedNotesTreeTopologyVersion != topologyVersion else { return }
        cachedNotesTreeSnapshot = HologramSidebarNotesTreeBuilder.build(store: graphState.store)
        cachedNotesTreeTopologyVersion = topologyVersion
    }

    private var notesContent: some View {
        let snapshot = cachedNotesTreeSnapshot
        let visibleRows = NotesSidebarVisibleTreeBuilder.build(
            rootFolderIds: snapshot.rootFolderIds,
            expandedFolderIds: expandedFolders,
            childFolderIdsById: snapshot.childFolderIdsById,
            pageIdsByFolderId: snapshot.noteIdsByFolderId
        )
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(visibleRows, id: \.self) { row in
                    notesTreeRow(row, snapshot: snapshot)
                }

                // Loose notes (not in any folder)
                if !snapshot.looseNoteIds.isEmpty {
                    sectionHeader("Files")
                    ForEach(Array(snapshot.looseNoteIds.prefix(50)), id: \.self) { noteId in
                        if let node = snapshot.noteById[noteId] {
                            nodeRow(node)
                        }
                    }
                    if snapshot.looseNoteIds.count > 50 {
                        hintText("\(snapshot.looseNoteIds.count - 50) more…")
                    }
                }

                if snapshot.rootFolderIds.isEmpty && snapshot.looseNoteIds.isEmpty {
                    emptyState("No notes in graph", icon: "doc.text")
                }
            }
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func notesTreeRow(
        _ row: NotesSidebarVisibleTreeEntry,
        snapshot: HologramSidebarNotesTreeSnapshot
    ) -> some View {
        switch row {
        case let .folder(id, indent):
            if let folder = snapshot.folderById[id] {
                folderRow(
                    folder,
                    indent: indent,
                    noteCount: snapshot.noteCountByFolderId[id] ?? 0
                )
            }
        case let .page(id, indent):
            if let note = snapshot.noteById[id] {
                nodeRow(note, indent: indent)
            }
        case let .emptyFolder(_, indent):
            Text("Empty folder")
                .font(.system(size: 11))
                .foregroundStyle(.primary.opacity(0.25))
                .padding(.leading, CGFloat(indent) * 16 + 34)
                .padding(.vertical, 4)
        }
    }

    private func folderRow(_ folder: GraphNodeRecord, indent: Int, noteCount: Int) -> some View {
        let isExpanded = expandedFolders.contains(folder.id)
        return Button {
            withAnimation(.smooth(duration: 0.2)) {
                if expandedFolders.contains(folder.id) {
                    expandedFolders.remove(folder.id)
                } else {
                    expandedFolders.insert(folder.id)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.35))
                    .frame(width: 12)

                Image(systemName: isExpanded ? "folder.fill" : "folder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(GraphNodeType.folder.swiftUIColor)
                    .frame(width: 14)

                Text(folder.label.isEmpty ? "Untitled Folder" : folder.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(1)

                Spacer()

                if noteCount > 0 {
                    Text("\(noteCount)")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.25))
                }
            }
            .padding(.leading, CGFloat(indent) * 16 + 12)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            onSelectNode(folder.id)
        })
    }

    // MARK: - Query Content

    @Environment(QueryEngine.self) private var queryEngine
    @State private var queryText: String = ""
    @State private var queryResults: [GraphNodeRecord] = []
    @State private var activeQueryLabel: String?

    private var queryContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // NL query field
            nlQueryField
            Divider().opacity(0.2)

            // Show NL results if available
            if let result = queryEngine.currentResult {
                QueryResultsView(result: result, onSelectNode: onSelectNode)
            } else if let _ = graphState.selectedNodeId, let node = graphState.store.nodes[graphState.selectedNodeId!] {
                // Context: show which node is selected
                HStack(spacing: 6) {
                    Circle().fill(node.type.swiftUIColor).frame(width: 6, height: 6)
                    Text(node.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
                // No node selected — show quick presets
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        sectionHeader("Quick Queries")
                        presetButton("Show all tags")
                        presetButton("Most connected nodes")
                        presetButton("Orphan nodes")
                        presetButton("Recently created notes")
                        presetButton("Notes from last week")
                    }
                    .padding(.vertical, 6)
                }
            }

            if let error = queryEngine.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
            }
        }
    }

    private var nlQueryField: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(0.4))

            TextField("Ask your graph…", text: $queryText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .onSubmit {
                    queryEngine.execute(query: queryText)
                }

            if queryEngine.isProcessing {
                ProgressView()
                    .controlSize(.small)
            } else if !queryText.isEmpty {
                Button {
                    queryText = ""
                    queryEngine.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func presetButton(_ label: String) -> some View {
        Button {
            queryText = label.lowercased()
            queryEngine.execute(query: queryText)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.3))
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func queryButton(_ label: String, icon: String, color: Color, query: @escaping () -> [GraphNodeRecord]) -> some View {
        Button {
            queryResults = query()
            activeQueryLabel = label
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.8))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.primary.opacity(0.2))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                activeQueryLabel == label ? color.opacity(0.12) : .clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared Components

    private func nodeRow(_ node: GraphNodeRecord, indent: Int = 0) -> some View {
        NodeRowButton(node: node, indent: indent, onSelect: onSelectNode)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.3))
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }

    private func hintText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.primary.opacity(0.3))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }

    private func emptyState(_ message: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.primary.opacity(0.15))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - NodeRowButton (hover-aware)

private struct NodeRowButton: View {
    let node: GraphNodeRecord
    let indent: Int
    let onSelect: (String) -> Void
    @State private var isHovered = false
    @Environment(GraphState.self) private var graphState

    var body: some View {
        Button {
            onSelect(node.id)
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(node.type.swiftUIColor)
                    .frame(width: 7, height: 7)

                Text(node.label)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(1)

                Spacer()

                if indent == 0 {
                    Text(node.type.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.3))
                }
            }
            .padding(.leading, CGFloat(indent) * 16 + 12)
            .padding(.trailing, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.primary.opacity(isHovered ? 0.06 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            if node.type == .note, let pageId = node.sourceId {
                Button {
                    NoteWindowManager.shared.open(pageId: pageId)
                } label: {
                    Label("Open in Notes", systemImage: "doc.text")
                }
            }
            Button {
                graphState.cleanupEphemeralNodes()
                graphState.selectNode(node.id)
                graphState.pendingCenterNodeId = node.id
                graphState.mode = .global
                graphState.clearFocus()
                graphState.focusOnNode(node.id, depth: GraphOverlayModePolicy.focusDepth)
                graphState.requestModeSync()
                graphState.requestFilterSync()
            } label: {
                Label("Focus on Node", systemImage: "scope")
            }
        }
    }
}
