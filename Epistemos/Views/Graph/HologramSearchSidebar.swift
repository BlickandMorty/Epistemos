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

    enum SidebarTab { case search, notes, knowledge }

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

    private var searchResults: [GraphNodeRecord] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return graphState.store.nodes.values
            .filter { $0.label.lowercased().contains(query) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if searchText.isEmpty {
                    hintText("Type to search notes, ideas, tags…")
                } else if searchResults.isEmpty {
                    hintText("No matching nodes")
                } else {
                    ForEach(searchResults.prefix(50), id: \.id) { node in
                        nodeRow(node)
                    }
                    if searchResults.count > 50 {
                        hintText("\(searchResults.count - 50) more…")
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Notes Content (mirrors NotesSidebar: folders → loose files)

    private var folderNodes: [GraphNodeRecord] {
        graphState.store.nodes.values
            .filter { $0.type == .folder }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private func noteChildrenOf(_ folderId: String) -> [GraphNodeRecord] {
        let neighborIds = graphState.store.adjacency[folderId] ?? []
        return neighborIds.compactMap { graphState.store.nodes[$0] }
            .filter { $0.type == .note }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private var looseNotes: [GraphNodeRecord] {
        let folderIds = Set(folderNodes.map(\.id))
        return graphState.store.nodes.values
            .filter { node in
                node.type == .note &&
                !(graphState.store.adjacency[node.id] ?? []).contains(where: { folderIds.contains($0) })
            }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private var notesContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                // Folders with note children
                ForEach(folderNodes, id: \.id) { folder in
                    let noteChildren = noteChildrenOf(folder.id)
                    if !noteChildren.isEmpty {
                        folderRow(folder, children: noteChildren)
                    }
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

                if folderNodes.isEmpty && looseNotes.isEmpty {
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
                    nodeRow(node, indented: true)
                }
                if nodes.count > 30 {
                    hintText("\(nodes.count - 30) more…")
                        .padding(.leading, 20)
                }
            }
        }
    }

    // MARK: - Folder Row

    private func folderRow(_ folder: GraphNodeRecord, children: [GraphNodeRecord]) -> some View {
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
                    Image(systemName: expandedFolders.contains(folder.id) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(width: 12)

                    Circle()
                        .fill(GraphNodeType.folder.swiftUIColor)
                        .frame(width: 7, height: 7)

                    Text(folder.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)

                    Spacer()

                    Text("\(children.count)")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture(count: 2).onEnded {
                onSelectNode(folder.id)
            })

            if expandedFolders.contains(folder.id) {
                ForEach(children, id: \.id) { child in
                    nodeRow(child, indented: true)
                }
            }
        }
    }

    // MARK: - Shared Components

    private func nodeRow(_ node: GraphNodeRecord, indented: Bool = false) -> some View {
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

                if !indented {
                    Text(node.type.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.leading, indented ? 32 : 12)
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
