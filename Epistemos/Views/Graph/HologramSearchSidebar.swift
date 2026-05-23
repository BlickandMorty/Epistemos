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
            let lhsLabel = nodesById[lhs]?.label ?? ""
            let rhsLabel = nodesById[rhs]?.label ?? ""
            return lhsLabel.localizedCaseInsensitiveCompare(rhsLabel) == .orderedAscending
        }
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
// Three tabs: Notes, Query, and Chat for the currently selected node.

struct HologramSearchSidebar: View {
    @Environment(GraphState.self) private var graphState
    @Environment(InferenceState.self) private var inference
    @Environment(UIState.self) private var ui
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("epistemos.graphChatOperatingMode")
    private var graphChatOperatingModeRaw = EpistemosOperatingMode.fast.rawValue
    /// Persisted collapse state. Survives editor↔graph navigation and app
    /// restarts. When true the sidebar shrinks to a single expand-affordance
    /// button; when false the full Notes/Query/Chat tabs are visible.
    /// Per user 2026-05-10: defaults to TRUE (collapsed) on first launch.
    /// Storage key was rotated to `.v2` so the new default applies even for
    /// users who had previously persisted `false` under the old key.
    @AppStorage("epistemos.graphSidebarCollapsed.v2")
    private var isCollapsed: Bool = true
    @AppStorage("epistemos.graphSidebarWidth.v1")
    private var sidebarWidthStorage: Double = 400
    @AppStorage("epistemos.graphSidebarHeight.v1")
    private var sidebarHeightStorage: Double = 420
    @State private var activeTab: SidebarTab = .notes
    @State private var expandedFolders: Set<String> = []
    @State private var cachedNotesTreeSnapshot = HologramSidebarNotesTreeSnapshot.empty
    @State private var cachedNotesTreeTopologyVersion = -1
    @State private var graphChatLastScrollTime: ContinuousClock.Instant = .now
    @State private var resizeStartSize = CGSize(width: 400, height: 420)

    let inspectorState: NodeInspectorState
    let modelContext: ModelContext?
    var onSelectNode: (String) -> Void

    enum SidebarTab { case notes, query, chat }

    private var theme: EpistemosTheme { ui.theme }
    private var graphChatAccentColor: Color { theme.resolved.accent.color }
    private var boundedSidebarWidth: CGFloat {
        CGFloat(min(max(sidebarWidthStorage, 300), 560))
    }
    private var boundedSidebarHeight: CGFloat {
        CGFloat(min(max(sidebarHeightStorage, 260), 760))
    }
    private var graphChatStreamingText: String {
        guard inspectorState.chatMessages.last?.role == .assistant else { return "" }
        return inspectorState.chatMessages.last?.text ?? ""
    }
    private var graphChatStatusPhase: AssistantComposerStatusPhase {
        AssistantComposerStatusPhase.resolve(
            isActive: inspectorState.isChatStreaming,
            streamingText: graphChatStreamingText
        )
    }
    private var supportedGraphChatOperatingModes: [EpistemosOperatingMode] {
        let modes = inference.availableOperatingModes.filter { $0 != .agent }
        return modes.isEmpty ? [.fast] : modes
    }
    private var selectedGraphChatOperatingMode: EpistemosOperatingMode {
        get {
            MainChatOperatingModePreference.sanitize(
                EpistemosOperatingMode(rawValue: graphChatOperatingModeRaw) ?? .fast,
                for: inference,
                availableModes: supportedGraphChatOperatingModes
            )
        }
        nonmutating set {
            graphChatOperatingModeRaw = MainChatOperatingModePreference.sanitize(
                newValue,
                for: inference,
                availableModes: supportedGraphChatOperatingModes
            ).rawValue
        }
    }
    private var graphChatOperatingModeBinding: Binding<EpistemosOperatingMode> {
        Binding(
            get: { selectedGraphChatOperatingMode },
            set: { selectedGraphChatOperatingMode = $0 }
        )
    }

    var body: some View {
        Group {
            if isCollapsed {
                collapsedAffordance
            } else {
                expandedSidebar
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: isCollapsed)
    }

    /// Tiny button shown when the sidebar is collapsed — restores the
    /// full panel when pressed. Persists via `@AppStorage` so it survives
    /// editor↔graph navigation.
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
        .help("Show sidebar")
        .unifiedFrostedGlass(theme: theme, in: RoundedRectangle(cornerRadius: 10, style: .continuous), interactive: true)
    }

    private var expandedSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabPills
            Divider().opacity(0.2)

            switch activeTab {
            case .notes:
                notesContent
            case .query:
                queryContent
            case .chat:
                chatContent
            }
        }
        .frame(width: boundedSidebarWidth, height: boundedSidebarHeight)
        .overlay(alignment: .bottomTrailing) {
            resizeHandle
        }
        .onAppear {
            refreshNotesTreeSnapshotIfNeeded()
        }
        .onChange(of: graphState.graphDataVersion) { _, _ in
            refreshNotesTreeSnapshotIfNeeded()
        }
        .onChange(of: queryEngine.currentResult?.nodes.count) { _, newCount in
            if let newCount, newCount > 0 {
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { activeTab = .query }
            }
        }
        .onChange(of: inspectorState.isChatStreaming) { _, isStreaming in
            guard isStreaming else { return }
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { activeTab = .chat }
        }
        .unifiedFrostedGlass(theme: theme, in: RoundedRectangle(cornerRadius: 14, style: .continuous), interactive: true)
    }

    private var resizeHandle: some View {
        Image(systemName: "arrow.down.right.and.arrow.up.left")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(theme.textSecondary.opacity(0.72))
            .frame(width: 28, height: 28)
            .background(theme.card.opacity(theme.isDark ? 0.74 : 0.88), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(theme.border.opacity(0.55), lineWidth: 0.75)
            )
            .padding(8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        sidebarWidthStorage = Double(min(max(resizeStartSize.width + value.translation.width, 300), 560))
                        sidebarHeightStorage = Double(min(max(resizeStartSize.height + value.translation.height, 260), 760))
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

    // MARK: - Tab Pills

    private var tabPills: some View {
        HStack(spacing: 4) {
            tabButton("Notes", icon: "doc.text", tab: .notes)
            tabButton("Query", icon: "point.3.connected.trianglepath.dotted", tab: .query)
            tabButton("Chat", icon: "bubble.left.and.bubble.right", tab: .chat)
            Spacer()
            // Collapse button — shrinks the sidebar to a single restore
            // affordance. State is persisted via `@AppStorage` so it
            // survives going into the editor and back.
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
            .help("Hide sidebar")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func tabButton(_ label: String, icon: String, tab: SidebarTab) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { activeTab = tab }
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

                if !snapshot.looseArtifactIds.isEmpty {
                    sectionHeader("Artifacts")
                    ForEach(Array(snapshot.looseArtifactIds.prefix(50)), id: \.self) { artifactId in
                        if let node = snapshot.artifactById[artifactId] {
                            nodeRow(node)
                        }
                    }
                    if snapshot.looseArtifactIds.count > 50 {
                        hintText("\(snapshot.looseArtifactIds.count - 50) more…")
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

    @State private var debouncedFilterTask: Task<Void, Never>?
    @State private var graphSearchResults: [GraphNodeRecord] = []

    private var queryContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Live search field — filters nodes as you type
            nlQueryField
            Divider().opacity(0.2)

            if !queryText.isEmpty {
                // Show matching nodes from live filter
                if graphSearchResults.isEmpty {
                    Text("No matching nodes")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            sectionHeader("\(graphSearchResults.count) match\(graphSearchResults.count == 1 ? "" : "es")")
                            ForEach(Array(graphSearchResults.prefix(100)), id: \.id) { node in
                                nodeRow(node)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else if let result = queryEngine.currentResult {
                QueryResultsView(result: result, onSelectNode: onSelectNode)
            } else if let selectedNodeId = graphState.selectedNodeId,
                      let node = graphState.store.nodes[selectedNodeId] {
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
            Image(systemName: queryText.isEmpty ? "magnifyingglass" : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(queryText.isEmpty ? 0.4 : 0.7))

            TextField("Filter nodes…", text: $queryText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .onChange(of: queryText) { _, newValue in
                    // Debounce: update sidebar results after 100ms of no typing
                    debouncedFilterTask?.cancel()
                    debouncedFilterTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        guard !Task.isCancelled else { return }

                        let query = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        if query.isEmpty {
                            graphSearchResults = []
                        } else {
                            graphSearchResults = graphState.store.nodes.values
                                .filter { $0.label.lowercased().contains(query) }
                                .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
                        }
                    }
                }
                .onSubmit {
                    // Also support Enter to run NL query engine for advanced queries
                    if !queryText.isEmpty {
                        queryEngine.execute(query: queryText)
                    }
                }

            if !queryText.isEmpty {
                Button {
                    queryText = ""
                    graphSearchResults = []
                    queryEngine.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.3))
                }
                .buttonStyle(.plain)
            }

            if queryEngine.isProcessing {
                ProgressView()
                    .controlSize(.small)
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

    // MARK: - Chat Content

    private var chatContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let node = inspectorState.selectedNode {
                chatNodeHeader(node)
                Divider().opacity(0.2)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if inspectorState.chatMessages.isEmpty && !inspectorState.isChatStreaming {
                                emptyState("Ask about this node", icon: "bubble.left.and.bubble.right")
                            } else {
                                ForEach(inspectorState.chatMessages) { message in
                                    graphChatRow(message)
                                        .id(message.id)
                                }
                            }

                            Color.clear
                                .frame(height: 1)
                                .id("graph-chat-bottom")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .onChange(of: inspectorState.chatMessages.count) { _, _ in
                        Task { @MainActor in
                            proxy.scrollTo("graph-chat-bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: graphChatStreamingText) { _, _ in
                        let now = ContinuousClock.now
                        guard now - graphChatLastScrollTime > ChatScrollFollowPolicy.streamingThrottle
                        else { return }
                        graphChatLastScrollTime = now
                        Task { @MainActor in
                            proxy.scrollTo("graph-chat-bottom", anchor: .bottom)
                        }
                    }
                    .onAppear {
                        Task { @MainActor in
                            proxy.scrollTo("graph-chat-bottom", anchor: .bottom)
                        }
                    }
                }

                Divider().opacity(0.2)
                graphChatComposer
            } else {
                emptyState("Select a node to start chatting", icon: "bubble.left.and.bubble.right")
                    .frame(maxHeight: .infinity)
            }
        }
    }

    private func chatNodeHeader(_ node: GraphNodeRecord) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(node.type.swiftUIColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.label.isEmpty ? "Untitled Node" : node.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.92))
                    .lineLimit(1)

                Text(node.type.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.38))
                    .textCase(.uppercase)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var graphChatComposer: some View {
        @Bindable var inspectorState = inspectorState
        let trimmedInput = inspectorState.chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let canSubmit = !trimmedInput.isEmpty && !inspectorState.isChatStreaming

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                LocalModelToolbarMenu(
                    variant: .toolbar,
                    operatingMode: graphChatOperatingModeBinding,
                    availableOperatingModes: supportedGraphChatOperatingModes
                )
                .controlSize(.small)

                Spacer(minLength: 8)

                Text(graphChatStatusText)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(graphChatStatusPhase == .idle ? theme.textTertiary : graphChatAccentColor)
                    .textCase(.uppercase)
            }

            HStack(spacing: 8) {
                TextField("Ask this node", text: $inspectorState.chatInput, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.94))
                    .tint(graphChatAccentColor)
                    .onSubmit {
                        guard canSubmit else { return }
                        sendGraphChatMessage()
                    }

                Button {
                    if inspectorState.isChatStreaming {
                        inspectorState.stopChat()
                    } else if canSubmit {
                        sendGraphChatMessage()
                    }
                } label: {
                    Image(systemName: inspectorState.isChatStreaming ? "stop.fill" : "arrow.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(
                            canSubmit || inspectorState.isChatStreaming
                                ? graphChatAccentColor
                                : theme.textTertiary.opacity(0.5)
                        )
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(theme.resolved.background.color.opacity(theme.isDark ? 0.58 : 0.82))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(theme.border.opacity(0.55), lineWidth: 0.75)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit && !inspectorState.isChatStreaming)
                .help(inspectorState.isChatStreaming ? "Stop response" : "Ask this node")
                .accessibilityLabel(inspectorState.isChatStreaming ? "Stop response" : "Ask this node")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(theme.resolved.foreground.color.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(theme.border.opacity(0.7), lineWidth: 0.8)
            )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(theme.card.opacity(theme.isDark ? 0.60 : 0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(theme.border.opacity(0.48), lineWidth: 0.75)
        )
        .padding(10)
    }

    private var graphChatStatusText: String {
        switch graphChatStatusPhase {
        case .idle:
            "ready"
        case .analyzing:
            "thinking"
        case .typing:
            "typing"
        }
    }

    @ViewBuilder
    private func graphChatRow(_ message: InspectorChatMessage) -> some View {
        let displayText = message.role == .assistant
            ? UserFacingModelOutput.finalVisibleText(from: message.text)
            : message.text
        let thinkingTrace = graphChatThinkingTrace(for: message)

        if message.role == .user {
            TaggedMarkdownTextView(
                content: displayText,
                theme: theme,
                rippleStyle: .none,
                foregroundOverride: theme.userBubbleText
            )
            .textSelection(.enabled)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.userBubbleBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: 320, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            AssistantTranscriptChrome {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if displayText.isEmpty {
                        if inspectorState.isChatStreaming {
                            LiveActivityStrip(
                                toolName: nil,
                                toolInputJson: nil,
                                isThinkingActive: !inspectorState.currentChatStreamingThinking
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                    .isEmpty,
                                thinkingStartedAt: nil,
                                isStreaming: true
                            )
                        } else {
                            Text("No response received.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                        }
                    } else {
                        TaggedMarkdownTextView(content: displayText, theme: theme)
                            .textSelection(.enabled)
                    }

                    if let thinkingTrace {
                        ThinkingTrailView(
                            content: thinkingTrace.content,
                            durationSeconds: thinkingTrace.duration
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func graphChatThinkingTrace(for message: InspectorChatMessage) -> (content: String, duration: Double?)? {
        let persistedTrace = message.thinkingTrace?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !persistedTrace.isEmpty {
            return (persistedTrace, message.thinkingDurationSeconds)
        }

        let isActiveStreamingAssistant = inspectorState.isChatStreaming
            && message.role == .assistant
            && message.id == inspectorState.chatMessages.last?.id
        guard isActiveStreamingAssistant else { return nil }

        let streamingTrace = inspectorState.currentChatStreamingThinking
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !streamingTrace.isEmpty else { return nil }
        return (streamingTrace, nil)
    }

    private func sendGraphChatMessage() {
        guard let modelContext else { return }

        // USABILITY-001 follow-up (graph chat, 2026-05-13): the inline
        // graph-inspector chat routes through `triageService.streamGeneral`
        // which delivers native cloud tools (web_search / web_fetch /
        // google_search / code_execution) automatically — but cannot
        // dispatch app tools (vault.search, vault.read, file.*) because
        // those only live in the Rust agent_core + LocalAgentLoop paths.
        //
        // When the user's query reads as agent-tier work ("find related
        // notes", "edit my essay on Y", etc.), the inline turn was
        // structurally guaranteed to hallucinate or refuse. So we
        // transparently re-route through main chat with the selected
        // graph node attached as a `ContextAttachment` so the full
        // app-tool surface dispatches correctly (vault.search, etc.).
        //
        // Per user directive 2026-05-13: graph rendering must NOT be
        // disrupted — only the chat behavior changes. The Metal graph
        // view + node layout + edges stay untouched; only the panel
        // switches to home (the user can navigate back via the graph
        // button in the sidebar; graph state is preserved).
        //
        // Non-agent intents (summarize/explain/expand) stay on the
        // existing inline path so the in-graph inspection UX is
        // unchanged.
        let trimmed = inspectorState.chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !inspectorState.isChatStreaming {
            let isCloudProvider: Bool = {
                switch inference.effectiveChatSurfaceSelection(for: selectedGraphChatOperatingMode) {
                case .cloud: return true
                case .localMLX, .appleIntelligence: return false
                }
            }()
            let prediction = ChatCapability.predictIntent(
                text: trimmed,
                isCloudProvider: isCloudProvider
            )
            if (prediction.predicted == .agent || prediction.predicted == .research),
               let bootstrap = AppBootstrap.shared {
                inspectorState.chatInput = ""
                bootstrap.chatState.startNewChat()
                if let nodeAttachment = graphNodeContextAttachment {
                    bootstrap.chatState.addContextAttachment(nodeAttachment)
                }
                ui.setActivePanel(.home)
                MainChatSubmissionRouter.submit(
                    trimmed,
                    operatingMode: selectedGraphChatOperatingMode,
                    chat: bootstrap.chatState,
                    orchestrator: bootstrap.orchestratorState,
                    inference: inference
                )
                return
            }
        }

        inspectorState.sendMessage(
            store: graphState.store,
            modelContext: modelContext,
            operatingMode: selectedGraphChatOperatingMode
        )
    }

    /// Wraps the currently-selected graph node as a main-chat
    /// `ContextAttachment` so the auto-escalated tool-enabled turn has
    /// the node body inlined + can dispatch vault tools against it.
    /// Returns nil when there's no selected node OR the node isn't a
    /// note (we only have a stable page targetId for note-typed nodes
    /// today). For non-note nodes the escalation still proceeds — the
    /// model gets the user's query without node context.
    private var graphNodeContextAttachment: ContextAttachment? {
        guard let node = inspectorState.selectedNode,
              node.type == .note,
              let sourceId = node.sourceId else {
            return nil
        }
        return ContextAttachment(
            kind: .note,
            targetId: sourceId,
            title: node.label.isEmpty ? "Untitled" : node.label
        )
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
