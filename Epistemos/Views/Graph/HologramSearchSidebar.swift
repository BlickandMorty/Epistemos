import SwiftData
import SwiftUI

struct HologramSidebarNotesTreeSnapshot: Sendable {
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

struct HologramSidebarCacheSnapshot: Sendable {
    let notesTree: HologramSidebarNotesTreeSnapshot
    let sortedSearchNodes: [GraphNodeRecord]
}

enum HologramSidebarNotesTreeBuilder {
    @MainActor
    static func build(store: GraphStore) -> HologramSidebarNotesTreeSnapshot {
        build(nodes: Array(store.nodes.values), edges: Array(store.edges.values))
    }

    nonisolated static func buildCache(
        nodes: [GraphNodeRecord],
        edges: [GraphEdgeRecord]
    ) -> HologramSidebarCacheSnapshot {
        HologramSidebarCacheSnapshot(
            notesTree: build(nodes: nodes, edges: edges),
            sortedSearchNodes: sortedNodeRecords(nodes)
        )
    }

    nonisolated static func build(
        nodes: [GraphNodeRecord],
        edges: [GraphEdgeRecord]
    ) -> HologramSidebarNotesTreeSnapshot {
        let folderById = Dictionary(
            uniqueKeysWithValues: nodes
                .filter { $0.type == .folder }
                .map { ($0.id, $0) }
        )
        let noteById = Dictionary(
            uniqueKeysWithValues: nodes
                .filter { $0.type == .note }
                .map { ($0.id, $0) }
        )
        let artifactTypes = Set(GraphNodeType.appLevelCases)
        let artifactById = Dictionary(
            uniqueKeysWithValues: nodes
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

        for edge in edges where edge.type == .contains {
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

    nonisolated private static func sortedNodeRecords(_ nodes: [GraphNodeRecord]) -> [GraphNodeRecord] {
        nodes.sorted { lhs, rhs in
            let labelOrder = lhs.label.localizedCaseInsensitiveCompare(rhs.label)
            if labelOrder == .orderedSame {
                return lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending
            }
            return labelOrder == .orderedAscending
        }
    }

    nonisolated private static func sortedNodeIds<S: Sequence>(
        _ ids: S,
        in nodesById: [String: GraphNodeRecord]
    ) -> [String] where S.Element == String {
        ids.sorted { lhs, rhs in
            compareNodeLabels(lhs, rhs, in: nodesById)
        }
    }

    nonisolated private static func compareNodeLabels(
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

    nonisolated private static func recursiveNoteCount(
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

enum GraphSidebarLayout {
    static let defaultWidth: Double = 400
    static let defaultHeight: Double = 420
    static let minWidth: CGFloat = 300
    static let maxWidth: CGFloat = 560
    static let minHeight: CGFloat = 260
    static let maxHeight: CGFloat = 760

    static func boundedWidth(_ storedWidth: Double) -> CGFloat {
        CGFloat(min(max(storedWidth, Double(minWidth)), Double(maxWidth)))
    }

    static func boundedHeight(_ storedHeight: Double) -> CGFloat {
        CGFloat(min(max(storedHeight, Double(minHeight)), Double(maxHeight)))
    }
}

struct HologramSearchSidebar: View {
    @Environment(GraphState.self) private var graphState
    @Environment(QueryEngine.self) private var queryEngine
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("epistemos.graphSidebarCollapsed.notesQuery.v1")
    private var isCollapsed = false
    @AppStorage("epistemos.graphSidebarWidth.v1")
    private var sidebarWidthStorage = GraphSidebarLayout.defaultWidth
    @AppStorage("epistemos.graphSidebarHeight.v1")
    private var sidebarHeightStorage = GraphSidebarLayout.defaultHeight

    @State private var activeTab: SidebarTab = .notes
    @State private var expandedFolders: Set<String> = []
    @State private var cachedNotesTreeSnapshot = HologramSidebarNotesTreeSnapshot.empty
    @State private var cachedNotesTreeTopologyVersion = -1
    @State private var resizeStartSize = CGSize(width: 400, height: 420)
    @State private var queryText = ""
    @State private var debouncedFilterTask: Task<Void, Never>?
    @State private var cacheBuildTask: Task<Void, Never>?
    @State private var graphSearchResults: [GraphNodeRecord] = []
    @State private var graphSearchMatchCount = 0
    @State private var sortedGraphSearchNodes: [GraphNodeRecord] = []

    let inspectorState: NodeInspectorState
    let modelContext: ModelContext?
    let onRevealNode: (String) -> Void

    private static let graphSearchResultLimit = 100

    private enum SidebarTab {
        case notes
        case query
    }

    private var theme: EpistemosTheme { ui.theme }
    private var boundedSidebarWidth: CGFloat {
        GraphSidebarLayout.boundedWidth(sidebarWidthStorage)
    }
    private var boundedSidebarHeight: CGFloat {
        GraphSidebarLayout.boundedHeight(sidebarHeightStorage)
    }
    private var normalizedQueryText: String {
        queryText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
        Group {
            if graphState.currentRoute.isCanvas {
                if isCollapsed {
                    collapsedAffordance
                } else {
                    expandedSidebar
                }
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: isCollapsed)
        .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: graphState.currentRoute)
    }

    private var collapsedAffordance: some View {
        Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.22)) {
                isCollapsed = false
            }
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .help("Show graph sidebar")
        .unifiedFrostedGlass(
            theme: theme,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous),
            interactive: true
        )
    }

    private var expandedSidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            tabPills
            Divider().opacity(0.2)

            switch activeTab {
            case .notes:
                notesContent
            case .query:
                queryContent
            }
        }
        .frame(width: boundedSidebarWidth, height: boundedSidebarHeight)
        .overlay(alignment: .bottomTrailing) {
            resizeHandle
        }
        .onAppear {
            refreshGraphSidebarCachesIfNeeded()
            updateGraphSearchResultsIfNeeded(for: queryText)
        }
        .onChange(of: graphState.graphDataVersion) { _, _ in
            guard graphState.currentRoute.isCanvas else { return }
            refreshGraphSidebarCachesIfNeeded()
            updateGraphSearchResultsIfNeeded(for: queryText)
        }
        .onChange(of: graphState.currentRoute) { _, route in
            guard route.isCanvas else {
                cacheBuildTask?.cancel()
                cacheBuildTask = nil
                return
            }
            refreshGraphSidebarCachesIfNeeded()
            updateGraphSearchResultsIfNeeded(for: queryText)
        }
        .onChange(of: queryEngine.resultVersion) { _, _ in
            guard !normalizedQueryText.isEmpty else { return }
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) {
                activeTab = .query
            }
        }
        .onDisappear {
            debouncedFilterTask?.cancel()
            debouncedFilterTask = nil
            cacheBuildTask?.cancel()
            cacheBuildTask = nil
        }
        .unifiedFrostedGlass(
            theme: theme,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous),
            interactive: true
        )
    }

    private var resizeHandle: some View {
        Image(systemName: "arrow.down.right.and.arrow.up.left")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(theme.textSecondary.opacity(0.72))
            .frame(width: 28, height: 28)
            .background(
                theme.card.opacity(theme.isDark ? 0.74 : 0.88),
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(theme.border.opacity(0.55), lineWidth: 0.75)
            )
            .padding(8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        sidebarWidthStorage = Double(GraphSidebarLayout.boundedWidth(
                            Double(resizeStartSize.width + value.translation.width)
                        ))
                        sidebarHeightStorage = Double(GraphSidebarLayout.boundedHeight(
                            Double(resizeStartSize.height + value.translation.height)
                        ))
                    }
                    .onEnded { _ in
                        resizeStartSize = CGSize(width: boundedSidebarWidth, height: boundedSidebarHeight)
                    }
            )
            .onAppear {
                resizeStartSize = CGSize(width: boundedSidebarWidth, height: boundedSidebarHeight)
            }
            .help("Resize sidebar")
            .accessibilityLabel("Resize sidebar")
    }

    private var tabPills: some View {
        HStack(spacing: 4) {
            tabButton("Notes", icon: "doc.text", tab: .notes)
            tabButton("Query", icon: "point.3.connected.trianglepath.dotted", tab: .query)

            Spacer(minLength: 0)

            Button {
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.22)) {
                    isCollapsed = true
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .help("Hide graph sidebar")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func tabButton(_ label: String, icon: String, tab: SidebarTab) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) {
                activeTab = tab
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
            .background(activeTab == tab ? Color.primary.opacity(0.15) : Color.clear, in: Capsule())
            .foregroundStyle(Color.primary.opacity(activeTab == tab ? 1.0 : 0.45))
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func refreshGraphSidebarCachesIfNeeded() {
        guard graphState.currentRoute.isCanvas else { return }
        let topologyVersion = graphState.store.topologyVersion
        guard cachedNotesTreeTopologyVersion != topologyVersion else { return }

        cacheBuildTask?.cancel()
        cacheBuildTask = Task(priority: .utility) { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            let topologyVersion = graphState.store.topologyVersion
            guard cachedNotesTreeTopologyVersion != topologyVersion else { return }
            let nodeRecords = Array(graphState.store.nodes.values)
            let edgeRecords = Array(graphState.store.edges.values)

            let snapshot = await Task.detached(priority: .utility) {
                HologramSidebarNotesTreeBuilder.buildCache(
                    nodes: nodeRecords,
                    edges: edgeRecords
                )
            }.value

            guard !Task.isCancelled else { return }
            guard cachedNotesTreeTopologyVersion != topologyVersion else { return }

            cachedNotesTreeSnapshot = snapshot.notesTree
            sortedGraphSearchNodes = snapshot.sortedSearchNodes
            cachedNotesTreeTopologyVersion = topologyVersion
            updateGraphSearchResultsIfNeeded(for: queryText)
        }
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

                if !snapshot.looseNoteIds.isEmpty {
                    sectionHeader("Files")
                    ForEach(Array(snapshot.looseNoteIds.prefix(50)), id: \.self) { noteId in
                        if let node = snapshot.noteById[noteId] {
                            nodeRow(node)
                        }
                    }
                    if snapshot.looseNoteIds.count > 50 {
                        hintText("\(snapshot.looseNoteIds.count - 50) more...")
                    }
                }

                if !snapshot.looseArtifactIds.isEmpty {
                    sectionHeader("Artifacts")
                    ForEach(Array(snapshot.looseArtifactIds.prefix(50)), id: \.self) { artifactId in
                        if let node = snapshot.artifactById[artifactId] {
                            nodeRow(node)
                        }
                    }
                    if snapshot.looseArtifactIds.count > 50 {
                        hintText("\(snapshot.looseArtifactIds.count - 50) more...")
                    }
                }

                if snapshot.rootFolderIds.isEmpty
                    && snapshot.looseNoteIds.isEmpty
                    && snapshot.looseArtifactIds.isEmpty {
                    emptyState("No files in graph", icon: "doc.text.magnifyingglass")
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
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) {
                if isExpanded {
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

                Spacer(minLength: 0)

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
            onRevealNode(folder.id)
        })
    }

    private var queryContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            nlQueryField
            Divider().opacity(0.2)

            if queryEngine.isProcessing {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Searching graph")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let result = queryEngine.currentResult,
                      !normalizedQueryText.isEmpty,
                      queryEngine.currentQuery == normalizedQueryText {
                QueryResultsView(result: result, onSelectNode: onRevealNode)
            } else if !normalizedQueryText.isEmpty {
                liveFilterResults
            } else if let result = queryEngine.currentResult {
                QueryResultsView(result: result, onSelectNode: onRevealNode)
            } else if let selectedNodeId = graphState.selectedNodeId,
                      let node = graphState.store.nodes[selectedNodeId] {
                selectedNodeSummary(node)
            } else {
                quickQueries
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
            Image(systemName: normalizedQueryText.isEmpty ? "magnifyingglass" : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(normalizedQueryText.isEmpty ? 0.4 : 0.7))

            TextField("Filter nodes or run graph query...", text: $queryText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .onChange(of: queryText) { _, newValue in
                    debouncedFilterTask?.cancel()
                    debouncedFilterTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        guard !Task.isCancelled else { return }
                        updateGraphSearchResults(for: newValue)
                        if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            queryEngine.clear()
                        }
                    }
                }
                .onSubmit {
                    runGraphQuery()
                }

            if !normalizedQueryText.isEmpty {
                Button {
                    queryText = ""
                    graphSearchResults = []
                    graphSearchMatchCount = 0
                    queryEngine.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.3))
                }
                .buttonStyle(.plain)
                .help("Clear")

                Button {
                    runGraphQuery()
                } label: {
                    Image(systemName: "return")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.55))
                }
                .buttonStyle(.plain)
                .help("Run graph query")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var liveFilterResults: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if graphSearchMatchCount == 0 {
                    emptyState("No matching nodes", icon: "magnifyingglass")
                } else {
                    sectionHeader("\(graphSearchMatchCount) match\(graphSearchMatchCount == 1 ? "" : "es")")
                    ForEach(graphSearchResults, id: \.id) { node in
                        nodeRow(node)
                    }
                    if graphSearchMatchCount > Self.graphSearchResultLimit {
                        hintText("\(graphSearchMatchCount - Self.graphSearchResultLimit) more...")
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func selectedNodeSummary(_ node: GraphNodeRecord) -> some View {
        Button {
            onRevealNode(node.id)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(node.type.swiftUIColor)
                    .frame(width: 6, height: 6)
                Text(node.label.isEmpty ? "Selected Node" : node.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(node.type.displayName)
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.35))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var quickQueries: some View {
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

    private func presetButton(_ label: String) -> some View {
        Button {
            queryText = label.lowercased()
            updateGraphSearchResults(for: queryText)
            runGraphQuery()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.3))
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.7))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func runGraphQuery() {
        let trimmed = normalizedQueryText
        guard !trimmed.isEmpty else { return }
        queryEngine.execute(query: trimmed)
    }

    private func updateGraphSearchResults(for text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            graphSearchResults = []
            graphSearchMatchCount = 0
            return
        }

        if sortedGraphSearchNodes.isEmpty, !graphState.store.nodes.isEmpty {
            refreshGraphSidebarCachesIfNeeded()
            graphSearchResults = []
            graphSearchMatchCount = 0
            return
        }

        var matches: [GraphNodeRecord] = []
        matches.reserveCapacity(Self.graphSearchResultLimit)
        var count = 0
        for node in sortedGraphSearchNodes where node.label.localizedCaseInsensitiveContains(query) {
            count += 1
            if matches.count < Self.graphSearchResultLimit {
                matches.append(node)
            }
        }
        graphSearchMatchCount = count
        graphSearchResults = matches
    }

    private func updateGraphSearchResultsIfNeeded(for text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            graphSearchResults = []
            graphSearchMatchCount = 0
            return
        }
        updateGraphSearchResults(for: text)
    }

    private func nodeRow(_ node: GraphNodeRecord, indent: Int = 0) -> some View {
        NodeRowButton(node: node, indent: indent, onSelect: onRevealNode)
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

private struct NodeRowButton: View {
    let node: GraphNodeRecord
    let indent: Int
    let onSelect: (String) -> Void

    @State private var isHovered = false
    @State private var showInlinePreview = false
    @State private var showInlineEpdocPreview = false
    @Environment(GraphState.self) private var graphState

    var body: some View {
        VStack(spacing: 4) {
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

                    Spacer(minLength: 0)

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
                    if GraphInlineDocPreviewFlag.enabled {
                        Button {
                            showInlinePreview = true
                        } label: {
                            Label("Preview Inline", systemImage: "doc.text.magnifyingglass")
                        }
                    }
                }
                if node.type == .document {
                    Button {
                        let manifestID = node.sourceId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                            ? node.sourceId ?? node.id
                            : node.id
                        EpdocDocumentOpening.openDocument(
                            withManifestID: manifestID,
                            vaultURL: AppBootstrap.shared?.vaultSync.vaultURL
                        )
                    } label: {
                        Label(
                            GraphSurfaceInlineEditability.fallsThroughToUtility(node.type)
                                ? "Open Document in a Window"
                                : "Open Document",
                            systemImage: "doc.richtext"
                        )
                    }
                    if GraphInlineDocPreviewFlag.enabled {
                        Button {
                            showInlineEpdocPreview = true
                        } label: {
                            Label("Preview Inline", systemImage: "doc.richtext.fill")
                        }
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

            if showInlinePreview, node.type == .note, let pageId = node.sourceId {
                GraphInlineDocPreviewCard(pageId: pageId, onClose: { showInlinePreview = false })
                    .padding(.leading, CGFloat(indent) * 16 + 12)
                    .padding(.trailing, 12)
                    .padding(.bottom, 2)
            }
            if showInlineEpdocPreview, node.type == .document {
                GraphEpdocDocPreviewCard(
                    manifestID: node.sourceId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                        ? (node.sourceId ?? node.id)
                        : node.id,
                    vaultURL: AppBootstrap.shared?.vaultSync.vaultURL,
                    onClose: { showInlineEpdocPreview = false }
                )
                .padding(.leading, CGFloat(indent) * 16 + 12)
                .padding(.trailing, 12)
                .padding(.bottom, 2)
            }
        }
    }
}
