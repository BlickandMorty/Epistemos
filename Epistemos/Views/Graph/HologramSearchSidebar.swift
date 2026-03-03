import SwiftUI

// MARK: - HologramSidebar
// Floating left panel for the graph overlay.
// Two tabs: Notes (folder tree — note nodes only) and Query (AI-powered graph queries).

struct HologramSearchSidebar: View {
    @Environment(GraphState.self) private var graphState
    @State private var activeTab: SidebarTab = .notes
    @State private var expandedFolders: Set<String> = []

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
        .frame(width: 280)
        .frame(maxHeight: 560)
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

    // MARK: - Notes Content (mirrors NotesSidebar: recursive folder tree)

    /// All folder nodes in the graph.
    private var allFolderNodes: [String: GraphNodeRecord] {
        Dictionary(
            graphState.store.nodes.values
                .filter { $0.type == .folder }
                .map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Children of a folder (subfolders and notes) via directed "contains" edges.
    /// Contains edges: source=parent, target=child.
    private func containsChildrenOf(_ folderId: String) -> (folders: [GraphNodeRecord], notes: [GraphNodeRecord]) {
        let edgeIds = graphState.store.edgesByNode[folderId] ?? []
        var folders: [GraphNodeRecord] = []
        var notes: [GraphNodeRecord] = []

        for edgeId in edgeIds {
            guard let edge = graphState.store.edges[edgeId],
                  edge.sourceNodeId == folderId,
                  edge.type == .contains else { continue }
            guard let child = graphState.store.nodes[edge.targetNodeId] else { continue }

            if child.type == .folder {
                folders.append(child)
            } else if child.type == .note {
                notes.append(child)
            }
        }

        folders.sort { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        notes.sort { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        return (folders, notes)
    }

    /// Root folders: folders that are NOT the target of any "contains" edge from another folder.
    private var rootFolders: [GraphNodeRecord] {
        let folderIds = allFolderNodes
        var childFolderIds = Set<String>()

        for (_, edge) in graphState.store.edges {
            guard edge.type == .contains,
                  folderIds[edge.sourceNodeId] != nil,
                  folderIds[edge.targetNodeId] != nil else { continue }
            childFolderIds.insert(edge.targetNodeId)
        }

        return folderIds.values
            .filter { !childFolderIds.contains($0.id) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    /// Notes not contained in any folder.
    private var looseNotes: [GraphNodeRecord] {
        let folderIds = Set(allFolderNodes.keys)
        return graphState.store.nodes.values
            .filter { node in
                guard node.type == .note else { return false }
                // Check if any "contains" edge from a folder targets this note
                let edgeIds = graphState.store.edgesByNode[node.id] ?? []
                for edgeId in edgeIds {
                    guard let edge = graphState.store.edges[edgeId] else { continue }
                    if edge.type == .contains && edge.targetNodeId == node.id && folderIds.contains(edge.sourceNodeId) {
                        return false
                    }
                }
                return true
            }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private var notesContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                // Recursive folder tree
                ForEach(rootFolders, id: \.id) { folder in
                    recursiveFolderRow(folder, indent: 0)
                }

                // Loose notes (not in any folder)
                if !looseNotes.isEmpty {
                    sectionHeader("Files")
                    ForEach(looseNotes.prefix(50), id: \.id) { node in
                        nodeRow(node)
                    }
                    if looseNotes.count > 50 {
                        hintText("\(looseNotes.count - 50) more…")
                    }
                }

                if rootFolders.isEmpty && looseNotes.isEmpty {
                    emptyState("No notes in graph", icon: "doc.text")
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Recursive Folder Row

    /// Recursive total count of notes in this folder and all subfolders.
    private func recursiveNoteCount(_ folderId: String, visited: Set<String> = []) -> Int {
        guard !visited.contains(folderId) else { return 0 }
        var visited = visited
        visited.insert(folderId)
        let (subfolders, notes) = containsChildrenOf(folderId)
        return notes.count + subfolders.reduce(0) { $0 + recursiveNoteCount($1.id, visited: visited) }
    }

    @ViewBuilder
    private func recursiveFolderRow(_ folder: GraphNodeRecord, indent: Int) -> some View {
        if indent >= 20 {
            EmptyView()
        } else {
            folderRowContent(folder, indent: indent)
        }
    }

    @ViewBuilder
    private func folderRowContent(_ folder: GraphNodeRecord, indent: Int) -> some View {
        let isExpanded = expandedFolders.contains(folder.id)
        let (subfolders, notes) = containsChildrenOf(folder.id)
        let count = recursiveNoteCount(folder.id)

        VStack(alignment: .leading, spacing: 0) {
            Button {
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

                    if count > 0 {
                        Text("\(count)")
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

            if isExpanded {
                ForEach(subfolders, id: \.id) { subfolder in
                    AnyView(recursiveFolderRow(subfolder, indent: indent + 1))
                }

                ForEach(notes, id: \.id) { note in
                    nodeRow(note, indent: indent + 1)
                }

                if subfolders.isEmpty && notes.isEmpty {
                    Text("Empty folder")
                        .font(.system(size: 11))
                        .foregroundStyle(.primary.opacity(0.25))
                        .padding(.leading, CGFloat(indent + 1) * 16 + 34)
                        .padding(.vertical, 4)
                }
            }
        }
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
            } else if let selectedId = graphState.selectedNodeId, let node = graphState.store.nodes[selectedId] {
                // Context: which node we're querying about
                HStack(spacing: 6) {
                    Circle().fill(node.type.swiftUIColor).frame(width: 6, height: 6)
                    Text(node.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

                Divider().opacity(0.2)

                // Quick query buttons
                ScrollView {
                    VStack(spacing: 4) {
                        sectionHeader("Semantic")

                        queryButton("Supports", icon: "checkmark.circle", color: .green) {
                            graphState.store.query(.supportsOf(nodeId: selectedId))
                        }
                        queryButton("Contradicts", icon: "xmark.circle", color: .red) {
                            graphState.store.query(.contradictsOf(nodeId: selectedId))
                        }
                        queryButton("Expands", icon: "arrow.up.left.and.arrow.down.right", color: .blue) {
                            graphState.store.query(.nodesWithEdgeType(.expands, from: selectedId))
                        }
                        queryButton("Questions", icon: "questionmark.circle", color: .orange) {
                            graphState.store.query(.nodesWithEdgeType(.questions, from: selectedId))
                        }

                        sectionHeader("Structural")

                        queryButton("Cites", icon: "quote.opening", color: .purple) {
                            graphState.store.query(.nodesWithEdgeType(.cites, from: selectedId))
                        }
                        queryButton("References", icon: "arrow.right", color: .secondary) {
                            graphState.store.query(.nodesWithEdgeType(.reference, from: selectedId))
                        }
                        queryButton("Contains", icon: "folder", color: Color(red: 0.64, green: 0.52, blue: 0.37)) {
                            graphState.store.query(.nodesWithEdgeType(.contains, from: selectedId))
                        }

                        if !queryResults.isEmpty {
                            Divider().opacity(0.2).padding(.vertical, 4)

                            if let label = activeQueryLabel {
                                Text("\(label) (\(queryResults.count))")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.primary.opacity(0.4))
                                    .textCase(.uppercase)
                                    .tracking(0.4)
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 2)
                            }

                            ForEach(queryResults, id: \.id) { node in
                                nodeRow(node)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
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
                graphState.selectNode(node.id)
                graphState.mode = .page(nodeId: node.id)
                graphState.focusOnNode(node.id, depth: 2)
                graphState.requestRecommit()
            } label: {
                Label("Focus on Node", systemImage: "scope")
            }
        }
    }
}
