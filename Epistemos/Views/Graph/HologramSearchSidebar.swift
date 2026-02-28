import SwiftUI

// MARK: - HologramSidebar
// Floating left panel mirroring NotesSidebar structure for the graph overlay.
// Three tabs: Search (live node filtering), Notes (folder tree — note nodes only),
// and Knowledge (non-note types grouped by category: tags, ideas, sources, quotes, chats).

struct HologramSearchSidebar: View {
    @Environment(GraphState.self) private var graphState
    @Binding var searchText: String
    @State private var activeTab: SidebarTab = .notes
    @State private var expandedFolders: Set<String> = []
    @State private var expandedTypes: Set<GraphNodeType> = [.tag]

    var onSearchChanged: (String) -> Void
    var onSelectNode: (String) -> Void

    enum SidebarTab { case search, notes, knowledge, query }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabPills
            Divider().opacity(0.2)

            switch activeTab {
            case .search:
                searchContent
            case .notes:
                notesContent
            case .knowledge:
                knowledgeContent
            case .query:
                queryContent
            }
        }
        .frame(width: 280)
        .frame(maxHeight: 560)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Tab Pills

    private var tabPills: some View {
        HStack(spacing: 4) {
            tabButton("Search", icon: "magnifyingglass", tab: .search)
            tabButton("Notes", icon: "doc.text", tab: .notes)
            tabButton("Knowledge", icon: "brain.head.profile", tab: .knowledge)
            tabButton("Query", icon: "point.3.connected.trianglepath.dotted", tab: .query)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func tabButton(_ label: String, icon: String, tab: SidebarTab) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.2)) { activeTab = tab }
            if tab != .search && !searchText.isEmpty {
                searchText = ""
                onSearchChanged("")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(activeTab == tab ? .white.opacity(0.15) : .clear, in: Capsule())
            .foregroundStyle(activeTab == tab ? .white : .white.opacity(0.45))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Content

    private var searchContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
            Divider().opacity(0.2)
            searchResultsList
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))

            TextField("Search nodes…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .onChange(of: searchText) { _, newValue in
                    onSearchChanged(newValue)
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    onSearchChanged("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var searchResults: [GraphStore.SearchHit] {
        guard !searchText.isEmpty else { return [] }
        return graphState.rustSearch(query: searchText, limit: 50)
    }

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if searchText.isEmpty {
                    hintText("Type to search notes, ideas, tags…")
                } else if searchResults.isEmpty {
                    hintText("No matching nodes")
                } else {
                    ForEach(searchResults, id: \.id) { hit in
                        nodeRow(hit.node)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Notes Content (mirrors NotesSidebar: recursive folder tree)

    /// All folder nodes in the graph.
    private var allFolderNodes: [String: GraphNodeRecord] {
        Dictionary(
            uniqueKeysWithValues: graphState.store.nodes.values
                .filter { $0.type == .folder }
                .map { ($0.id, $0) }
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
            LazyVStack(alignment: .leading, spacing: 2) {
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

    // MARK: - Knowledge Content (non-note types grouped by category)

    private static let knowledgeTypes: [GraphNodeType] = [.tag, .idea, .source, .quote, .chat]

    private func nodesOfType(_ type: GraphNodeType) -> [GraphNodeRecord] {
        graphState.store.nodes.values
            .filter { $0.type == type }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private var knowledgeContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(Self.knowledgeTypes, id: \.self) { type in
                    let nodes = nodesOfType(type)
                    if !nodes.isEmpty {
                        typeSection(type, nodes: nodes)
                    }
                }

                let totalKnowledge = Self.knowledgeTypes.reduce(0) { $0 + nodesOfType($1).count }
                if totalKnowledge == 0 {
                    emptyState("No knowledge nodes yet", icon: "brain.head.profile")
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func typeSection(_ type: GraphNodeType, nodes: [GraphNodeRecord]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.smooth(duration: 0.2)) {
                    if expandedTypes.contains(type) {
                        expandedTypes.remove(type)
                    } else {
                        expandedTypes.insert(type)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: expandedTypes.contains(type) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(width: 12)

                    Image(systemName: type.icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(type.swiftUIColor)

                    Text(type.displayName + "s")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .textCase(.uppercase)
                        .tracking(0.4)

                    Spacer()

                    Text("\(nodes.count)")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expandedTypes.contains(type) {
                ForEach(nodes.prefix(30), id: \.id) { node in
                    nodeRow(node, indent: 1)
                }
                if nodes.count > 30 {
                    hintText("\(nodes.count - 30) more…")
                        .padding(.leading, 20)
                }
            }
        }
    }

    // MARK: - Recursive Folder Row

    /// Recursive total count of notes in this folder and all subfolders.
    private func recursiveNoteCount(_ folderId: String) -> Int {
        let (subfolders, notes) = containsChildrenOf(folderId)
        return notes.count + subfolders.reduce(0) { $0 + recursiveNoteCount($1.id) }
    }

    @ViewBuilder
    private func recursiveFolderRow(_ folder: GraphNodeRecord, indent: Int) -> some View {
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
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(width: 12)

                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(GraphNodeType.folder.swiftUIColor)
                        .frame(width: 14)

                    Text(folder.label.isEmpty ? "Untitled Folder" : folder.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)

                    Spacer()

                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                }
                .padding(.leading, CGFloat(indent) * 16 + 12)
                .padding(.trailing, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture(count: 2).onEnded {
                onSelectNode(folder.id)
            })

            if isExpanded {
                // Child subfolders first (recursive — use AnyView to break self-referential type)
                ForEach(subfolders, id: \.id) { subfolder in
                    AnyView(recursiveFolderRow(subfolder, indent: indent + 1))
                }

                // Child notes
                ForEach(notes, id: \.id) { note in
                    nodeRow(note, indent: indent + 1)
                }

                if subfolders.isEmpty && notes.isEmpty {
                    Text("Empty folder")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.25))
                        .padding(.leading, CGFloat(indent + 1) * 16 + 34)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Query Content

    @State private var queryResults: [GraphNodeRecord] = []
    @State private var activeQueryLabel: String?

    private var queryContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let selectedId = graphState.selectedNodeId, let node = graphState.store.nodes[selectedId] {
                // Context: which node we're querying about
                HStack(spacing: 6) {
                    Circle().fill(node.type.swiftUIColor).frame(width: 6, height: 6)
                    Text(node.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

                Divider().opacity(0.2)

                // Query buttons
                ScrollView {
                    VStack(spacing: 4) {
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
                                    .foregroundStyle(.white.opacity(0.4))
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
                emptyState("Select a node to query its relationships", icon: "point.3.connected.trianglepath.dotted")
            }
        }
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
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.2))
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
        Button {
            onSelectNode(node.id)
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(node.type.swiftUIColor)
                    .frame(width: 7, height: 7)

                Text(node.label)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                Spacer()

                if indent == 0 {
                    Text(node.type.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.leading, CGFloat(indent) * 16 + 12)
            .padding(.trailing, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.3))
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }

    private func hintText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.3))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }

    private func emptyState(_ message: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.15))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
