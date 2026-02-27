import SwiftUI

// MARK: - HologramSidebar
// Floating left panel with two tabs: Search (live node filtering) and Browse (folder tree).
// Integrated into the hologram overlay with Liquid Glass styling.

struct HologramSearchSidebar: View {
    @Environment(GraphState.self) private var graphState
    @Binding var searchText: String
    @State private var activeTab: SidebarTab = .search
    @State private var expandedFolders: Set<String> = []

    var onSearchChanged: (String) -> Void
    var onSelectNode: (String) -> Void

    enum SidebarTab { case search, browse }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabPills
            Divider().opacity(0.2)

            switch activeTab {
            case .search:
                searchContent
            case .browse:
                browseContent
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
            tabButton("Browse", icon: "folder", tab: .browse)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func tabButton(_ label: String, icon: String, tab: SidebarTab) -> some View {
        Button {
            withAnimation(.smooth(duration: 0.2)) { activeTab = tab }
            // Clear search highlighting when switching to browse.
            if tab == .browse && !searchText.isEmpty {
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

    // MARK: - Browse Content

    private var folderNodes: [GraphNodeRecord] {
        graphState.store.nodes.values
            .filter { $0.type == .folder }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private func childrenOf(_ folderId: String) -> [GraphNodeRecord] {
        let neighborIds = graphState.store.adjacency[folderId] ?? []
        return neighborIds.compactMap { graphState.store.nodes[$0] }
            .filter { $0.type != .folder } // Don't show sub-folders as children.
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    /// Top-level nodes not connected to any folder.
    private var orphanNodes: [GraphNodeRecord] {
        let folderIds = Set(folderNodes.map(\.id))
        return graphState.store.nodes.values
            .filter { node in
                node.type != .folder &&
                !(graphState.store.adjacency[node.id] ?? []).contains(where: { folderIds.contains($0) })
            }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private var browseContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(folderNodes, id: \.id) { folder in
                    folderRow(folder)
                }

                if !orphanNodes.isEmpty {
                    Divider().opacity(0.15).padding(.vertical, 4)
                    hintText("Ungrouped")
                    ForEach(orphanNodes.prefix(30), id: \.id) { node in
                        nodeRow(node)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func folderRow(_ folder: GraphNodeRecord) -> some View {
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

                    let count = childrenOf(folder.id).count
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.25))
                    }
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
                let children = childrenOf(folder.id)
                ForEach(children, id: \.id) { child in
                    nodeRow(child, indented: true)
                }
            }
        }
    }

    // MARK: - Shared Row

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

                Text(node.type.displayName)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.leading, indented ? 32 : 12)
            .padding(.trailing, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func hintText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.3))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }
}
