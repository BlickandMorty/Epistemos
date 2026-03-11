import SwiftData
import SwiftUI

// MARK: - Value Types (break @Observable tracking chain)
// SDPage/SDFolder are @Model (@Observable) — every property access in a row's
// body registers an observation tracker. The 5s save debounce writes page.body,
// invalidating all trackers → all rows re-evaluate → heavy modifiers retain old
// view graph nodes → 275 retained copies per page → 2GB memory.
//
// These Equatable structs freeze display-only properties. Rows reading them
// register ZERO @Observable observations. SwiftUI can also skip re-evaluation
// when the struct hasn't changed (same title/emoji/etc).

private struct SidebarPageItem: Identifiable, Equatable {
    let id: String
    let title: String
    let emoji: String
    let isJournal: Bool
    let isFavorite: Bool
    let isPinned: Bool
    let isArchived: Bool
    let isTemplate: Bool
    let journalDate: String?
    let tags: [String]
    let folderId: String?
    /// Denormalized subfolder path from SDPage.subfolder — always a plain String,
    /// never depends on relationship faulting. Used as fallback matching.
    let subfolder: String?
    /// FTS snippet from body/block search. Nil for title-only matches.
    var snippet: String?
    /// Category label for search results (e.g. "Body Match", "Block Match").
    var matchCategory: String?

    init(_ page: SDPage) {
        id = page.id
        title = page.title
        emoji = page.emoji
        isJournal = page.isJournal
        isFavorite = page.isFavorite
        isPinned = page.isPinned
        isArchived = page.isArchived
        isTemplate = page.isTemplate
        journalDate = page.journalDate
        tags = page.tags
        folderId = page.folder?.id
        subfolder = page.subfolder
    }
}

private struct SidebarFolderItem: Identifiable, Equatable {
    let id: String
    let name: String
    let isCollection: Bool
    let sortOrder: Int
    let parentId: String?
    let childFolderIds: [String]
    let relativePath: String
    /// Child pages — populated from folder.pages (primary) or subfolder match (fallback).
    var childPages: [SidebarPageItem]

    init(_ folder: SDFolder) {
        id = folder.id
        name = folder.name
        isCollection = folder.isCollection
        sortOrder = folder.sortOrder
        parentId = folder.parent?.id
        childFolderIds = (folder.children ?? []).sorted { $0.sortOrder < $1.sortOrder }.map(\.id)
        relativePath = folder.relativePath
        // Primary: read directly from folder.pages (v3 pattern).
        // Deduplicate by ID to prevent SwiftUI duplicate ID crashes.
        let pages = (folder.pages ?? []).filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
        var seenIds = Set<String>()
        childPages = pages.compactMap { page in
            guard !seenIds.contains(page.id) else { return nil }
            seenIds.insert(page.id)
            return SidebarPageItem(page)
        }
    }
}

private struct SidebarIdeaItem: Identifiable, Equatable {
    let id: String
    let title: String
    let type: NoteIdea.IdeaType
    let pageId: String
    let pageTitle: String
    let pageEmoji: String
    let createdAt: Date

    var icon: String { type == .idea ? "lightbulb" : "brain" }
}

// MARK: - Sidebar Action Enum
// All mutation actions are routed through this enum back to NotesSidebar,
// which holds the @Environment services (modelContext, vaultSync, notesUI).
// Rows never touch SDPage/SDFolder directly — they only display value types
// and emit actions.

private enum SidebarAction {
    // Page actions
    case openPage(String)
    case openPageInNewWindow(String)
    case renamePage(id: String, newTitle: String)
    case requestDeletePage(SidebarPageItem)
    case toggleFavorite(String)
    case togglePin(String)
    // Folder actions
    case renameFolder(id: String, newName: String)
    case requestDeleteFolder(SidebarFolderItem)
    case newPageInFolder(String)
    case newSubfolder(String)
    case toggleCollection(String)
    // Move actions
    case movePageToFolder(pageId: String, folderId: String)
    case moveFolderInto(childId: String, parentId: String)
    case movePageToRoot(String)
    case moveFolderToRoot(String)
    // Create actions
    case createNewPage
    case newJournalEntry
    // Expansion
    case toggleFolder(String)
    case toggleJournalFolder
    case toggleIdeasFolder
    case collapseAll
    // Ideas
    case openIdea(pageId: String)
    // Intelligence actions
    case summarize(id: String, title: String)
    case deepDive(id: String, title: String)
    case openInGraph(id: String)
}

private enum SidebarSpecialFolders {
    static let dailyNotes = "Daily Notes"
}

enum NotesSidebarMetrics {
    static let headerTopPadding: CGFloat = 14
    static let headerBottomPadding: CGFloat = 2
    static let searchBarTopPadding: CGFloat = 0
    static let overlapsTitlebar = false
    static let showsBottomCollectionButton = false
    static let showsBottomMiniChatButton = false
    static let changesPanelWidth: CGFloat = 320
    static let changesPanelHeight: CGFloat = 400
}

enum NotesSidebarGlyph: Sendable {
    case vaultChanges

    var symbolName: String {
        switch self {
        case .vaultChanges:
            "doc.badge.clock"
        }
    }

    var activeSymbolName: String {
        switch self {
        case .vaultChanges:
            "doc.badge.clock.fill"
        }
    }
}

// MARK: - Notes Sidebar
// Obsidian-style file tree: vault → folders (SDFolder) → pages.
// Loose pages (not in any folder) appear at root level alongside folders.
// Journal entries are grouped under a special collapsible "Journal" folder.

struct NotesSidebar: View {
    let allPages: [SDPage]
    let allFolders: [SDFolder]

    /// Injected page-select action. When non-nil, .openPage and .openIdea use this
    /// instead of opening a separate window. Allows the home workspace to select in-place.
    var onSelectPage: ((String) -> Void)? = nil
    var selectedPageId: String? = nil
    var onClearSelection: (() -> Void)? = nil

    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(ChatState.self) private var chatState
    @Environment(GraphState.self) private var graphState
    @Environment(\.modelContext) private var modelContext

    @State private var showOrganizer = false
    @State private var bodySearchResults: [SidebarPageItem] = []
    @State private var pendingDeletePage: SidebarPageItem?
    @State private var pendingDeleteFolder: SidebarFolderItem?
    @FocusState private var isSearchFocused: Bool

    // MARK: - Cached value-type mappings (breaks @Observable tracking)
    // Rebuilt on structural changes only — NOT on every body evaluation.
    // This prevents 1300+ observation registrations per eval cycle.
    @State private var cachedPageItems: [SidebarPageItem] = []
    @State private var cachedPageById: [String: SidebarPageItem] = [:]
    @State private var cachedFolderItems: [SidebarFolderItem] = []
    @State private var cachedFolderById: [String: SidebarFolderItem] = [:]
    @State private var cachedIdeaItems: [SidebarIdeaItem] = []
    @State private var rebuildTask: Task<Void, Never>?

    private var theme: EpistemosTheme { ui.theme }
    private var currentSelectedPageId: String? { selectedPageId ?? notesUI.activePageId }

    /// Coalesces multiple `setNeedsRebuild()` calls into a single `rebuildCache()`
    /// on the next run loop tick. Prevents 13+ redundant rebuilds per event cycle.
    private func setNeedsRebuild() {
        rebuildTask?.cancel()
        rebuildTask = Task { @MainActor in
            rebuildCache()
        }
    }

    private func rebuildCache() {
        // Deduplicate by ID to prevent SwiftUI FAULT-level duplicate ID errors.
        // SwiftData @Query can return the same SDPage multiple times during merges.
        var seenPageIds = Set<String>()
        cachedPageItems = allPages.compactMap { page in
            guard !seenPageIds.contains(page.id) else { return nil }
            seenPageIds.insert(page.id)
            return SidebarPageItem(page)
        }
        cachedPageById = Dictionary(
            cachedPageItems.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        cachedFolderItems = allFolders.map(SidebarFolderItem.init)

        // Fallback: if folder.pages returned [] (SwiftData inverse not merged yet),
        // match pages to folders using the denormalized subfolder path → folder.relativePath.
        // This catches the case where VaultIndexActor assigned page.folder on a background
        // actor and the relationship hasn't faulted into the main context yet.
        let anyFolderEmpty = cachedFolderItems.contains { $0.childPages.isEmpty }
        if anyFolderEmpty {
            let pagesBySubfolder = Dictionary(
                grouping: cachedPageItems.filter { $0.subfolder != nil && !$0.isArchived },
                by: { $0.subfolder ?? "" }
            )
            for i in cachedFolderItems.indices where cachedFolderItems[i].childPages.isEmpty {
                let path = cachedFolderItems[i].relativePath
                if let matched = pagesBySubfolder[path], !matched.isEmpty {
                    cachedFolderItems[i].childPages = matched
                }
            }
        }

        cachedFolderById = Dictionary(
            cachedFolderItems.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })

        // Collect ideas from all pages (JSON-decoded once per rebuild, not per render)
        var ideaItems: [SidebarIdeaItem] = []
        for page in allPages {
            for idea in page.ideas {
                ideaItems.append(
                    SidebarIdeaItem(
                        id: idea.id,
                        title: idea.title,
                        type: idea.type,
                        pageId: page.id,
                        pageTitle: page.title,
                        pageEmoji: page.emoji,
                        createdAt: idea.createdAt
                    ))
            }
        }
        cachedIdeaItems = ideaItems.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Alert bindings

    private var showPageDeleteAlert: Binding<Bool> {
        Binding(
            get: { pendingDeletePage != nil },
            set: { if !$0 { pendingDeletePage = nil } }
        )
    }

    private var showFolderDeleteAlert: Binding<Bool> {
        Binding(
            get: { pendingDeleteFolder != nil },
            set: { if !$0 { pendingDeleteFolder = nil } }
        )
    }

    // MARK: - Body

    var body: some View {
        let fById = cachedFolderById
        let onAct: (SidebarAction) -> Void = { handleAction($0) }

        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                Image(systemName: "book.pages")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.fontAccent.opacity(0.88))
                TypewriterHeading(
                    text: "Notes",
                    role: .pageTitle,
                    color: theme.fontAccent,
                    animateOnAppear: true
                )
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, NotesSidebarMetrics.headerTopPadding)
            .padding(.bottom, NotesSidebarMetrics.headerBottomPadding)
            .background(theme.background)
            .ignoresSafeArea(
                NotesSidebarMetrics.overlapsTitlebar ? .container : [],
                edges: .top
            )
            searchBar
            fileTree(folderItemById: fById, onAction: onAct)
            Divider().opacity(0.2)
            bottomBar
        }
        .background(theme.background)
        .onAppear {
            rebuildCache()
            preWarmRecentPages()
            // Deferred rebuild: VaultIndexActor may still be wiring folder relationships
            // when the sidebar first appears. Rebuild again after context merge settles.
            // 200ms is enough for SwiftData background→main context merge.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(200))
                rebuildCache()
            }
        }
        .onChange(of: allPages.count) { setNeedsRebuild() }
        .onChange(of: allFolders.count) { setNeedsRebuild() }
        .onReceive(NotificationCenter.default.publisher(for: vaultFoldersRepairedNotification)) {
            _ in
            // Delay to allow SwiftData's background-to-main context merge to complete.
            // The notification fires from VaultIndexActor (background ModelActor) — the main
            // context @Query results may not have updated yet when the notification arrives.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(200))
                rebuildCache()
            }
        }
        .alert(pageDeleteAlertTitle, isPresented: showPageDeleteAlert) {
            Button("Delete", role: .destructive) { performPageDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This page will be permanently deleted.")
        }
        .alert(folderDeleteAlertTitle, isPresented: showFolderDeleteAlert) {
            Button("Delete", role: .destructive) { performFolderDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(folderDeleteAlertMessage)
        }
        .onChange(of: notesUI.debouncedSearchQuery) { _, newValue in
            performBodySearch(query: newValue)
        }
        .onChange(of: notesUI.searchQuery) { _, newValue in
            if newValue.isEmpty { bodySearchResults = [] }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        @Bindable var notesUI = notesUI
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.epCaption)
                .foregroundStyle(theme.mutedForeground.opacity(0.4))
            TextField("Search notes...", text: $notesUI.searchQuery)
                .font(.epBody)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .accessibilityLabel("Search notes")
            if !notesUI.searchQuery.isEmpty {
                Button {
                    notesUI.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.epCaption)
                        .foregroundStyle(theme.mutedForeground.opacity(0.4))
                }
                .buttonStyle(NativeToolbarButtonStyle())
                .help("Clear search")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isSearchFocused
                        ? (theme.isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08))
                        : (theme.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                )
        )
        .padding(.horizontal, 12)
        .padding(.top, NotesSidebarMetrics.searchBarTopPadding)
        .padding(.bottom, 6)
    }

    // MARK: - File Tree / Search Results

    private func fileTree(
        folderItemById fById: [String: SidebarFolderItem],
        onAction: @escaping (SidebarAction) -> Void
    ) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if !notesUI.searchQuery.isEmpty {
                    searchResultsView(onAction: onAction)
                } else {
                    folderTreeView(
                        folderItemById: fById,
                        onAction: onAction
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Folder Tree
    // Layout: vault header → collections → folders → Journal → FILES label → loose pages

    @ViewBuilder
    private func folderTreeView(
        folderItemById fById: [String: SidebarFolderItem],
        onAction: @escaping (SidebarAction) -> Void
    ) -> some View {
        let pinned = cachedPageItems.filter { $0.isPinned && !$0.isArchived }
        if !pinned.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Pinned")
                    .font(AppHeadingRole.section.font)
                    .foregroundStyle(theme.fontAccent)
                    .textCase(.uppercase)
                    .tracking(AppHeadingRole.section.tracking)
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                    .padding(.bottom, 2)

                ForEach(pinned) { page in
                    FileRow(
                        item: page,
                        indent: 0,
                        selectedPageId: currentSelectedPageId,
                        onAction: onAction
                    )
                }
            }
        }

        // Vault header
        if let url = vaultSync.vaultURL {
            VaultHeader(
                name: url.lastPathComponent,
                hasExpandedFolders: !notesUI.expandedFolderIds.isEmpty || notesUI.isJournalExpanded
                    || notesUI.isIdeasExpanded,
                onAction: onAction
            )
        }

        // ── COLLECTIONS ── user-created organization folders
        let collections = cachedFolderItems.filter { $0.parentId == nil && $0.isCollection }
        if !collections.isEmpty {
            ForEach(collections) { folder in
                FolderRow(
                    item: folder, indent: 0,
                    folderItemById: fById, selectedPageId: currentSelectedPageId, onAction: onAction
                )
            }
        }

        // ── FOLDERS ── top-level folders (no parent, non-collection)
        let dailyNotesFolder = cachedFolderItems.first {
            $0.parentId == nil && $0.relativePath == SidebarSpecialFolders.dailyNotes
        }
        let folders = cachedFolderItems.filter {
            $0.parentId == nil
                && !$0.isCollection
                && $0.id != dailyNotesFolder?.id
        }
        if !folders.isEmpty {
            ForEach(folders) { folder in
                FolderRow(
                    item: folder, indent: 0,
                    folderItemById: fById, selectedPageId: currentSelectedPageId, onAction: onAction
                )
            }
        }

        let journals =
            dailyNotesFolder?.childPages.filter(\.isJournal)
            ?? cachedPageItems.filter { $0.isJournal && $0.folderId == nil }
        if !journals.isEmpty || dailyNotesFolder != nil {
            JournalFolderRow(
                journals: journals,
                isExpanded: notesUI.isJournalExpanded,
                selectedPageId: currentSelectedPageId,
                onAction: onAction
            )
        }

        // Ideas section — all ideas across the vault
        if !cachedIdeaItems.isEmpty {
            IdeasFolderRow(
                ideas: cachedIdeaItems,
                isExpanded: notesUI.isIdeasExpanded,
                onAction: onAction
            )
        }

        // ── FILES SECTION ── loose pages not in any folder.
        let loose = cachedPageItems.filter { !$0.isJournal && $0.folderId == nil && !$0.isTemplate }
        VStack(alignment: .leading, spacing: 0) {
            if !loose.isEmpty || !folders.isEmpty {
                Text("Files")
                    .font(AppHeadingRole.section.font)
                    .foregroundStyle(theme.fontAccent)
                    .textCase(.uppercase)
                    .tracking(AppHeadingRole.section.tracking)
                    .padding(.horizontal, 14)
                    .padding(.top, folders.isEmpty && journals.isEmpty ? 6 : 12)
                    .padding(.bottom, 2)
            }

            ForEach(loose) { page in
                FileRow(
                    item: page,
                    indent: 0,
                    selectedPageId: currentSelectedPageId,
                    onAction: onAction
                )
            }
        }
        .dropDestination(for: String.self) { items, _ in
            for droppedItem in items {
                if droppedItem.hasPrefix("page:") {
                    let pageId = String(droppedItem.dropFirst(5))
                    onAction(.movePageToRoot(pageId))
                } else if droppedItem.hasPrefix("folder:") {
                    let folderId = String(droppedItem.dropFirst(7))
                    onAction(.moveFolderToRoot(folderId))
                }
            }
            return true
        }

        if cachedPageItems.isEmpty {
            EmptyTreeState(onAction: onAction)
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private func searchResultsView(onAction: @escaping (SidebarAction) -> Void) -> some View {
        let results = filteredSearchResults
        if results.isEmpty {
            VStack(spacing: Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(theme.textTertiary)
                Text("No results")
                    .font(.epCaption)
                    .foregroundStyle(theme.mutedForeground)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            ForEach(results) { page in
                SearchResultRow(item: page, onAction: onAction)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // All actions on one row — editor + creation consolidated.
            // EditorActionsBar is isolated (has its own @Query for dirty pages).
            EditorActionsBar(
                activePageId: currentSelectedPageId,
                onNewPage: {
                    Task {
                        if let pageId = await vaultSync.createPage(title: "Untitled") {
                            openInEditor(pageId)
                        }
                    }
                },
                onNewFolder: { createFolder(title: "Untitled Folder") },
                onNewCollection: { createCollection(title: "Untitled Collection") },
                onTodayJournal: { Task { await getOrCreateTodayJournal() } },
                onOrganize: { showOrganizer = true }
            )
        }
        .sheet(isPresented: $showOrganizer) {
            VaultOrganizerView(allPages: allPages, allFolders: allFolders)
                .preferredColorScheme(ui.theme.colorScheme)
        }
    }

    // MARK: - Search

    /// Two-tier search: title/tags from in-memory pageItems (instant),
    /// body matches via pre-built trigram index (microseconds).
    private var filteredSearchResults: [SidebarPageItem] {
        let query = notesUI.searchQuery.lowercased()

        // Tier 1: title + tags — already in memory, no disk I/O
        let titleMatches = cachedPageItems.filter {
            $0.title.lowercased().contains(query)
                || $0.tags.contains(where: { $0.lowercased().contains(query) })
        }

        // Tier 2: merge body matches (populated async by onChange)
        let titleIds = Set(titleMatches.map(\.id))
        let uniqueBodyMatches = bodySearchResults.filter { !titleIds.contains($0.id) }

        let combined = titleMatches + uniqueBodyMatches
        return Array(combined.prefix(50))
    }

    /// Run body + block search via FTS5 with snippets.
    private func performBodySearch(query: String) {
        guard !query.isEmpty else {
            bodySearchResults = []
            return
        }
        Task {
            let bodyHits = await vaultSync.searchFullAsync(query: query, limit: 30)
            let blockHits = await vaultSync.searchBlocksAsync(query: query, limit: 10)

            var results: [SidebarPageItem] = []
            var seenPageIds: Set<String> = []

            // Body matches — with snippet
            for hit in bodyHits {
                let pageId = hit.pageId
                guard !seenPageIds.contains(pageId) else { continue }
                seenPageIds.insert(pageId)
                if var item = cachedPageById[pageId] {
                    let rawSnippet = hit.snippet
                        .replacingOccurrences(of: "<b>", with: "")
                        .replacingOccurrences(of: "</b>", with: "")
                    item.snippet = rawSnippet.isEmpty ? nil : rawSnippet
                    item.matchCategory = "Body Match"
                    results.append(item)
                }
            }

            // Block matches — with snippet, deduplicated against body results
            for hit in blockHits {
                let pageId = hit.pageId
                guard !seenPageIds.contains(pageId) else { continue }
                seenPageIds.insert(pageId)
                if var item = cachedPageById[pageId] {
                    let rawSnippet = hit.snippet
                        .replacingOccurrences(of: "<b>", with: "")
                        .replacingOccurrences(of: "</b>", with: "")
                    item.snippet = rawSnippet.isEmpty ? nil : rawSnippet
                    item.matchCategory = "Block Match"
                    results.append(item)
                }
            }

            bodySearchResults = results
        }
    }

    // MARK: - SwiftData Helpers

    private func fetchPage(_ id: String) -> SDPage? {
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchFolder(_ id: String) -> SDFolder? {
        let descriptor = FetchDescriptor<SDFolder>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private func saveSidebarChanges(rebuild: Bool = true) {
        try? modelContext.save()
        if rebuild {
            setNeedsRebuild()
        }
    }

    private func rootFolder(named name: String) -> SDFolder? {
        allFolders.first { $0.parent == nil && $0.relativePath == name }
    }

    private func ensureRootFolder(named name: String, isCollection: Bool = false) -> SDFolder {
        if let existing = rootFolder(named: name) {
            if isCollection && !existing.isCollection {
                existing.isCollection = true
                CollectionRegistry.shared.setCollection(existing.name, true)
                saveSidebarChanges()
            }
            return existing
        }

        let folder = SDFolder(name: name)
        folder.isCollection = isCollection
        modelContext.insert(folder)
        saveSidebarChanges()
        vaultSync.createDirectory(relativePath: folder.relativePath)
        if isCollection {
            CollectionRegistry.shared.setCollection(folder.name, true)
        }
        return folder
    }

    private func syncPagePaths(in folder: SDFolder, oldPath: String) {
        let newPath = folder.relativePath
        for page in (folder.pages ?? []) {
            page.subfolder = newPath.isEmpty ? nil : newPath
            if let vaultURL = vaultSync.vaultURL,
                let existingPath = page.filePath
            {
                let filename = URL(fileURLWithPath: existingPath).lastPathComponent
                let newParentURL =
                    page.subfolder.map { vaultURL.appendingPathComponent($0, isDirectory: true) }
                    ?? vaultURL
                page.filePath = newParentURL.appendingPathComponent(filename).path
            }
        }

        for child in (folder.children ?? []) {
            let childOldPath = oldPath.isEmpty ? child.name : "\(oldPath)/\(child.name)"
            syncPagePaths(in: child, oldPath: childOldPath)
        }
    }

    // MARK: - Open in Editor
    // KEY PATTERN: Open the editor window FIRST (instant), then defer the sidebar
    // highlight update to the next run loop tick. This mirrors the smooth pop-out
    // window which never touched notesUI.activePageId before creating the window.
    // Without this, setting activePageId triggers a synchronous sidebar re-render
    // (all rows check highlight state) that blocks the main thread before the
    // editor can appear.

    private func openInEditor(_ pageId: String) {
        if let onSelectPage {
            onSelectPage(pageId)
        } else {
            NoteWindowManager.shared.open(pageId: pageId)
        }
    }

    // MARK: - Pre-Warming (Options A + A2)

    /// On sidebar appear, pre-warm the 3 most recently updated pages.
    /// These are the notes the user is most likely to revisit.
    /// Body reads happen on VaultIndexActor (background) to avoid blocking MainActor.
    private func preWarmRecentPages() {
        let theme = ui.theme
        Task {
            // Step 1: fetch IDs only on main thread (no .body access = no disk I/O)
            var desc = FetchDescriptor<SDPage>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            desc.fetchLimit = 3
            guard let recentPages = try? modelContext.fetch(desc), !recentPages.isEmpty else {
                return
            }
            let ids = recentPages.map(\.id).filter {
                PageStoragePool.shared.bodyText(for: $0) == nil
            }
            guard !ids.isEmpty else { return }

            // Step 2: read bodies on background actor (off MainActor)
            let noteBodies = await vaultSync.fetchNoteBodies(ids: ids)
            guard !noteBodies.isEmpty else { return }

            // Step 3: feed to pool on MainActor
            let pages = noteBodies.map { (id: $0.pageId, body: $0.body) }
            PageStoragePool.shared.preWarmRecent(pages: pages, theme: theme)
        }
    }

    /// When a folder is expanded, pre-warm storages for its child pages
    /// so clicking a note opens instantly (no cold-cache styling delay).
    /// Body reads happen on VaultIndexActor (background) to avoid blocking MainActor.
    private func preWarmFolder(id: String) {
        guard let folder = cachedFolderById[id] else { return }

        // Gather page IDs from this folder and immediate subfolders
        var pageIds = Set(folder.childPages.map(\.id))
        for childFolderId in folder.childFolderIds {
            if let child = cachedFolderById[childFolderId] {
                pageIds.formUnion(child.childPages.map(\.id))
            }
        }
        guard !pageIds.isEmpty else { return }

        let theme = ui.theme
        let idArray = Array(pageIds.prefix(6)).filter {
            PageStoragePool.shared.bodyText(for: $0) == nil
        }
        guard !idArray.isEmpty else { return }
        Task {
            // Read bodies on background actor (off MainActor)
            let noteBodies = await vaultSync.fetchNoteBodies(ids: idArray)
            guard !noteBodies.isEmpty else { return }

            let pages = noteBodies.map { (id: $0.pageId, body: $0.body) }
            PageStoragePool.shared.preWarm(pages: pages, theme: theme)
        }
    }

    // MARK: - Action Handler

    private func handleAction(_ action: SidebarAction) {
        switch action {
        case .openPage(let id):
            openInEditor(id)

        case .openPageInNewWindow(let id):
            if let page = fetchPage(id) {
                NoteWindowManager.shared.openWindow(for: page)
            }

        case .renamePage(let id, let newTitle):
            if let page = fetchPage(id) {
                let sanitized = VaultIndexActor.sanitizeTitle(newTitle)
                page.title = sanitized
                page.updatedAt = .now
                page.needsVaultSync = true
                try? modelContext.save()
                // Rename the vault .md file to match the new title
                vaultSync.renamePageFile(pageId: id, newTitle: sanitized)
                setNeedsRebuild()
            }

        case .requestDeletePage(let item):
            pendingDeletePage = item

        case .toggleFavorite(let id):
            if let page = fetchPage(id) {
                page.isFavorite.toggle()
                saveSidebarChanges()
            }

        case .togglePin(let id):
            if let page = fetchPage(id) {
                page.isPinned.toggle()
                saveSidebarChanges()
            }

        case .renameFolder(let id, let newName):
            if let folder = fetchFolder(id) {
                let oldPath = folder.relativePath
                folder.name = newName
                syncPagePaths(in: folder, oldPath: oldPath)
                let newPath = folder.relativePath
                saveSidebarChanges()
                vaultSync.renameDirectory(from: oldPath, to: newPath)
            }

        case .requestDeleteFolder(let item):
            pendingDeleteFolder = item

        case .newPageInFolder(let folderId):
            Task {
                guard let folder = fetchFolder(folderId) else { return }
                let subfolder = folder.relativePath
                if let pageId = await vaultSync.createPage(title: "Untitled", subfolder: subfolder)
                {
                    if let page = fetchPage(pageId),
                        let folder = fetchFolder(folderId)
                    {
                        page.folder = folder
                        page.subfolder = subfolder
                        saveSidebarChanges()
                    }
                    openInEditor(pageId)
                }
            }

        case .newSubfolder(let parentId):
            if let parent = fetchFolder(parentId) {
                let child = SDFolder(name: "Untitled Folder")
                child.parent = parent
                modelContext.insert(child)
                saveSidebarChanges()
                vaultSync.createDirectory(relativePath: child.relativePath)
            }

        case .toggleCollection(let folderId):
            if let folder = fetchFolder(folderId) {
                folder.isCollection.toggle()
                CollectionRegistry.shared.setCollection(folder.name, folder.isCollection)
                saveSidebarChanges()
            }

        case .movePageToFolder(let pageId, let folderId):
            if let page = fetchPage(pageId),
                let folder = fetchFolder(folderId)
            {
                page.folder = folder
                page.subfolder = folder.relativePath
                saveSidebarChanges()
                vaultSync.movePage(pageId: pageId, toSubfolder: folder.relativePath)
            }

        case .moveFolderInto(let childId, let parentId):
            if let child = fetchFolder(childId),
                let parent = fetchFolder(parentId)
            {
                let oldPath = child.relativePath
                child.parent = parent
                syncPagePaths(in: child, oldPath: oldPath)
                saveSidebarChanges()
                vaultSync.renameDirectory(from: oldPath, to: child.relativePath)
            }

        case .movePageToRoot(let pageId):
            if let page = fetchPage(pageId) {
                page.folder = nil
                page.subfolder = nil
                saveSidebarChanges()
                vaultSync.movePage(pageId: pageId, toSubfolder: nil)
            }

        case .moveFolderToRoot(let folderId):
            if let folder = fetchFolder(folderId) {
                let oldPath = folder.relativePath
                folder.parent = nil
                syncPagePaths(in: folder, oldPath: oldPath)
                saveSidebarChanges()
                vaultSync.renameDirectory(from: oldPath, to: folder.relativePath)
            }

        case .createNewPage:
            Task {
                if let pageId = await vaultSync.createPage(title: "Untitled") {
                    openInEditor(pageId)
                }
            }

        case .newJournalEntry:
            Task {
                await getOrCreateTodayJournal()
            }

        case .toggleFolder(let id):
            let wasCollapsed = !notesUI.expandedFolderIds.contains(id)
            withAnimation(Motion.snap) { notesUI.toggleFolder(id) }
            // Pre-warm storages for pages in this folder when expanding
            if wasCollapsed {
                preWarmFolder(id: id)
            }

        case .toggleJournalFolder:
            withAnimation(Motion.snap) { notesUI.isJournalExpanded.toggle() }

        case .toggleIdeasFolder:
            withAnimation(Motion.snap) { notesUI.isIdeasExpanded.toggle() }

        case .openIdea(let pageId):
            openInEditor(pageId)

        case .collapseAll:
            withAnimation(Motion.snap) { notesUI.collapseAllFolders() }

        case .summarize(let id, let title):
            chatState.loadedNoteIds.insert(id)
            chatState.submitQuery(
                "Summarize @[\(title)] — give me a concise overview of the key points, themes, and structure."
            )

        case .deepDive(let id, let title):
            chatState.loadedNoteIds.insert(id)
            chatState.submitQuery(
                "Deep dive into @[\(title)] — perform a thorough analysis: identify the core arguments, evaluate the evidence, surface contradictions or gaps, and suggest areas for further exploration."
            )

        case .openInGraph(let id):
            HologramController.shared.revealPage(id)
        }
    }

    // MARK: - Delete Handlers

    private var pageDeleteAlertTitle: String {
        guard let item = pendingDeletePage else { return "" }
        let title = item.title.isEmpty ? "Untitled" : item.title
        return "Delete \"\(title)\"?"
    }

    private var folderDeleteAlertTitle: String {
        guard let item = pendingDeleteFolder else { return "" }
        let name = item.name.isEmpty ? "Untitled Folder" : item.name
        return "Delete \"\(name)\"?"
    }

    private var folderDeleteAlertMessage: String {
        guard let item = pendingDeleteFolder,
            let folder = allFolders.first(where: { $0.id == item.id })
        else { return "This folder will be permanently deleted." }

        let (pages, folders) = Self.countContents(of: folder)
        if pages == 0 && folders == 0 {
            return "This empty folder will be permanently deleted."
        }
        var parts: [String] = []
        if pages > 0 { parts.append("\(pages) page\(pages == 1 ? "" : "s")") }
        if folders > 0 { parts.append("\(folders) subfolder\(folders == 1 ? "" : "s")") }
        return
            "This folder contains \(parts.joined(separator: " and ")). All contents will be permanently deleted."
    }

    private func performPageDelete() {
        guard let item = pendingDeletePage else { return }
        clearSelectionIfNeeded(pageId: item.id)
        notesUI.closeTab(item.id)
        if let page = fetchPage(item.id) {
            vaultSync.deletePageFromDisk(filePath: page.filePath)
            SpotlightIndexer.deindex(page.id)
            // Clean up orphaned SDNoteInsight before deleting the page
            let pageId = page.id
            let insightDesc = FetchDescriptor<SDNoteInsight>(
                predicate: #Predicate { $0.pageId == pageId })
            if let insight = try? modelContext.fetch(insightDesc).first {
                modelContext.delete(insight)
            }
            modelContext.delete(page)
        }
        pendingDeletePage = nil
        saveSidebarChanges()
    }

    private func performFolderDelete() {
        guard let item = pendingDeleteFolder,
            let folder = fetchFolder(item.id)
        else {
            pendingDeleteFolder = nil
            return
        }
        closeFolderTabs(folder)
        deletePagesInFolder(folder)
        vaultSync.deleteDirectory(relativePath: folder.relativePath)
        modelContext.delete(folder)
        pendingDeleteFolder = nil
        saveSidebarChanges()
    }

    private func closeFolderTabs(_ folder: SDFolder) {
        for page in (folder.pages ?? []) {
            clearSelectionIfNeeded(pageId: page.id)
            notesUI.closeTab(page.id)
        }
        for child in (folder.children ?? []) {
            closeFolderTabs(child)
        }
    }

    private func clearSelectionIfNeeded(pageId: String) {
        guard currentSelectedPageId == pageId else { return }
        if let onClearSelection {
            onClearSelection()
        } else {
            notesUI.closePage()
        }
    }

    private func deletePagesInFolder(_ folder: SDFolder) {
        for page in (folder.pages ?? []) {
            SpotlightIndexer.deindex(page.id)
            modelContext.delete(page)
        }
        for child in (folder.children ?? []) {
            deletePagesInFolder(child)
        }
    }

    private static func countContents(of folder: SDFolder) -> (pages: Int, folders: Int) {
        let directPages = (folder.pages ?? []).count
        let subFolders = folder.children ?? []
        var totalPages = directPages
        var totalFolders = subFolders.count
        for child in subFolders {
            let (cp, cf) = countContents(of: child)
            totalPages += cp
            totalFolders += cf
        }
        return (totalPages, totalFolders)
    }

    // MARK: - Create Actions

    private func createFolder(title: String) {
        let folder = SDFolder(name: title)
        modelContext.insert(folder)
        saveSidebarChanges()
        vaultSync.createDirectory(relativePath: folder.relativePath)
    }

    private func createCollection(title: String) {
        _ = ensureRootFolder(named: title, isCollection: true)
    }

    private func getOrCreateTodayJournal() async {
        let today = Date.now
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: today)
        let dailyFolder = ensureRootFolder(named: SidebarSpecialFolders.dailyNotes)

        if let existing = allPages.first(where: { $0.isJournal && $0.journalDate == dateString }) {
            if existing.subfolder != dailyFolder.relativePath {
                existing.folder = dailyFolder
                existing.subfolder = dailyFolder.relativePath
                saveSidebarChanges()
                vaultSync.movePage(pageId: existing.id, toSubfolder: dailyFolder.relativePath)
            }
            openInEditor(existing.id)
            return
        }

        let title = today.formatted(date: .complete, time: .omitted)
        if let pageId = await vaultSync.createPage(
            title: title,
            emoji: "📓",
            subfolder: dailyFolder.relativePath
        ) {
            if let page = fetchPage(pageId) {
                page.isJournal = true
                page.journalDate = dateString
                page.folder = dailyFolder
                page.subfolder = dailyFolder.relativePath
                saveSidebarChanges()
            }
            openInEditor(pageId)
        }
    }
}

// MARK: - Vault Header

private struct VaultHeader: View {
    let name: String
    let hasExpandedFolders: Bool
    let onAction: (SidebarAction) -> Void

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "archivebox")
                .font(.epSmall)
                .foregroundStyle(theme.accent.opacity(0.7))
            Text(name)
                .font(AppHeadingRole.section.font)
                .foregroundStyle(theme.fontAccent.opacity(0.78))
                .textCase(.uppercase)
                .tracking(AppHeadingRole.section.tracking)
                .lineLimit(1)
            Spacer()
            if hasExpandedFolders {
                Button {
                    onAction(.collapseAll)
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.mutedForeground.opacity(0.4))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(NativeToolbarButtonStyle())
                .help("Collapse all folders")
                .accessibilityLabel("Collapse all folders")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

// MARK: - Folder Row (SidebarFolderItem)
// Recursive — renders child folders (nesting) and child pages.
// Supports drag-and-drop: accepts pages and sub-folders.
// No @Environment for VaultSyncService or modelContext — all mutations
// go through onAction callback to NotesSidebar.

private struct FolderRow: View {
    let item: SidebarFolderItem
    let indent: Int
    let folderItemById: [String: SidebarFolderItem]
    let selectedPageId: String?
    let onAction: (SidebarAction) -> Void

    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @State private var isDropTarget = false
    @State private var isRenaming = false
    @State private var renameValue = ""

    private var theme: EpistemosTheme { ui.theme }
    private var isExpanded: Bool { notesUI.expandedFolderIds.contains(item.id) }

    /// Recursive page count — includes pages in all nested subfolders.
    private var totalPageCount: Int {
        var count = item.childPages.count
        for childId in item.childFolderIds {
            if let child = folderItemById[childId] {
                count += recursivePageCount(for: child)
            }
        }
        return count
    }

    private func recursivePageCount(for folder: SidebarFolderItem) -> Int {
        var count = folder.childPages.count
        for childId in folder.childFolderIds {
            if let child = folderItemById[childId] {
                count += recursivePageCount(for: child)
            }
        }
        return count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Folder header row
            Button {
                onAction(.toggleFolder(item.id))
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.right")
                        .font(.epSmall).fontWeight(.semibold)
                        .foregroundStyle(theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(Motion.sharp, value: isExpanded)
                        .frame(width: 10)

                    Image(
                        systemName: item.isCollection
                            ? (isExpanded ? "tray.full.fill" : "tray.full")
                            : (isExpanded ? "folder.fill" : "folder")
                    )
                    .font(.epCaption)
                    .foregroundStyle(
                        item.isCollection ? theme.accent : theme.accent.opacity(0.75)
                    )
                    .frame(width: 14)

                    if isRenaming {
                        TextField("", text: $renameValue)
                            .font(.epBody).fontWeight(.medium)
                            .textFieldStyle(.plain)
                            .onSubmit { commitRename() }
                            .onAppear { renameValue = item.name }
                    } else {
                        Text(item.name.isEmpty ? "Untitled Folder" : item.name)
                            .font(.epBody).fontWeight(.medium)
                            .foregroundStyle(theme.foreground.opacity(0.9))
                            .lineLimit(1)
                    }

                    Spacer()

                    let count = totalPageCount
                    if count > 0 {
                        Text("\(count)")
                            .font(.epSmall)
                            .foregroundStyle(theme.textTertiary)
                            .monospacedDigit()
                    }
                }
                .padding(.leading, CGFloat(indent) * 16 + 10)
                .padding(.trailing, 10)
                .padding(.vertical, 4)
                .background {
                    if isDropTarget {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(theme.accent.opacity(0.15))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(
                            isDropTarget ? theme.accent.opacity(0.4) : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            .draggable("folder:\(item.id)")
            .dropDestination(for: String.self) { droppedItems, _ in
                for droppedItem in droppedItems {
                    if droppedItem.hasPrefix("page:") {
                        let pageId = String(droppedItem.dropFirst(5))
                        onAction(.movePageToFolder(pageId: pageId, folderId: item.id))
                    } else if droppedItem.hasPrefix("folder:") {
                        let folderId = String(droppedItem.dropFirst(7))
                        guard folderId != item.id else { continue }
                        onAction(.moveFolderInto(childId: folderId, parentId: item.id))
                    }
                }
                return true
            } isTargeted: { targeted in
                withAnimation(Motion.quick) { isDropTarget = targeted }
            }
            .contextMenu {
                Button {
                    onAction(.summarize(id: item.id, title: item.name))
                } label: {
                    Label("Summary", systemImage: "text.alignleft")
                }
                Button {
                    onAction(.deepDive(id: item.id, title: item.name))
                } label: {
                    Label("Deep Dive", systemImage: "magnifyingglass.circle")
                }
                Button {
                    onAction(.openInGraph(id: item.id))
                } label: {
                    Label("Open in Graph", systemImage: "point.3.connected.trianglepath.dotted")
                }
                Divider()
                Button("Rename Folder") {
                    isRenaming = true
                    renameValue = item.name
                }
                Button("New Page in Folder") {
                    onAction(.newPageInFolder(item.id))
                }
                Button("New Subfolder") {
                    onAction(.newSubfolder(item.id))
                }
                Divider()
                Button(item.isCollection ? "Remove from Collections" : "Make Collection") {
                    onAction(.toggleCollection(item.id))
                }
                Divider()
                Button("Delete Folder", role: .destructive) {
                    onAction(.requestDeleteFolder(item))
                }
            }
            .physicsHover(.subtle)

            // Expanded: child folders + child pages
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(item.childFolderIds, id: \.self) { childId in
                        if let child = folderItemById[childId] {
                            FolderRow(
                                item: child, indent: indent + 1,
                                folderItemById: folderItemById,
                                selectedPageId: selectedPageId,
                                onAction: onAction
                            )
                        }
                    }

                    ForEach(item.childPages) { page in
                        FileRow(
                            item: page,
                            indent: indent + 1,
                            selectedPageId: selectedPageId,
                            onAction: onAction
                        )
                    }

                    if item.childPages.isEmpty && item.childFolderIds.isEmpty {
                        Text("Empty folder")
                            .font(.epSmall)
                            .foregroundStyle(theme.textTertiary)
                            .padding(.leading, CGFloat(indent + 1) * 16 + 24)
                            .padding(.vertical, 4)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func commitRename() {
        let trimmed = renameValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != item.name {
            onAction(.renameFolder(id: item.id, newName: trimmed))
        }
        isRenaming = false
    }
}

// MARK: - Journal Folder Row

private struct JournalFolderRow: View {
    let journals: [SidebarPageItem]
    let isExpanded: Bool
    let selectedPageId: String?
    let onAction: (SidebarAction) -> Void

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                onAction(.toggleJournalFolder)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.right")
                        .font(.epSmall).fontWeight(.semibold)
                        .foregroundStyle(theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 10)

                    Image(systemName: "calendar")
                        .font(.epCaption)
                        .foregroundStyle(theme.accent.opacity(0.65))
                        .frame(width: 14)

                    Text("Daily Notes")
                        .font(.epBody).fontWeight(.medium)
                        .foregroundStyle(theme.foreground.opacity(0.9))

                    Spacer()

                    Text("\(journals.count)")
                        .font(.epSmall)
                        .foregroundStyle(theme.textTertiary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            .contextMenu {
                Button("New Daily Note") {
                    onAction(.newJournalEntry)
                }
            }

            if isExpanded {
                ForEach(journals) { page in
                    FileRow(
                        item: page,
                        indent: 1,
                        selectedPageId: selectedPageId,
                        onAction: onAction
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Ideas Folder Row

private struct IdeasFolderRow: View {
    let ideas: [SidebarIdeaItem]
    let isExpanded: Bool
    let onAction: (SidebarAction) -> Void

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                onAction(.toggleIdeasFolder)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.right")
                        .font(.epSmall).fontWeight(.semibold)
                        .foregroundStyle(theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 10)

                    Image(systemName: "lightbulb")
                        .font(.epCaption)
                        .foregroundStyle(.yellow.opacity(0.8))
                        .frame(width: 14)

                    Text("Ideas")
                        .font(.epBody).fontWeight(.medium)
                        .foregroundStyle(theme.foreground.opacity(0.9))

                    Spacer()

                    Text("\(ideas.count)")
                        .font(.epSmall)
                        .foregroundStyle(theme.textTertiary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)

            if isExpanded {
                ForEach(ideas.prefix(20)) { idea in
                    IdeaRow(item: idea, onAction: onAction)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

private struct IdeaRow: View {
    let item: SidebarIdeaItem
    let onAction: (SidebarAction) -> Void

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Button {
            onAction(.openIdea(pageId: item.pageId))
        } label: {
            HStack(spacing: 6) {
                Image(systemName: item.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(item.type == .idea ? .yellow : .purple)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title.isEmpty ? "Untitled" : item.title)
                        .font(.epBody)
                        .foregroundStyle(theme.foreground.opacity(0.8))
                        .lineLimit(1)

                    let source =
                        item.pageEmoji.isEmpty
                        ? item.pageTitle : "\(item.pageEmoji) \(item.pageTitle)"
                    Text(source)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.leading, 30)
            .padding(.trailing, 10)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - File Row (SidebarPageItem)
// Takes a value-type item — no @Observable tracking, no heavy @Environment.
// All mutations go through onAction callback to NotesSidebar.

private struct FileRow: View {
    let item: SidebarPageItem
    let indent: Int
    let selectedPageId: String?
    let onAction: (SidebarAction) -> Void

    @Environment(UIState.self) private var ui
    @State private var isRenaming = false
    @State private var renameValue = ""

    private var theme: EpistemosTheme { ui.theme }
    // Computed from @Environment — only THIS row re-evaluates when activePageId changes,
    // not the entire NotesSidebar body. This is the structural fix for the cascade.
    private var isActive: Bool { selectedPageId == item.id }
    private var favoriteHighlight: Color { theme.fontAccent }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main page row
            Button {
                onAction(.openPage(item.id))
            } label: {
                HStack(spacing: 6) {
                    if !item.emoji.isEmpty {
                        Text(item.emoji)
                            .font(.epCaption)
                            .frame(width: 14)
                    } else {
                        Image(
                            systemName: item.isJournal ? "calendar" : "doc.text"
                        )
                        .font(.epCaption)
                        .foregroundStyle(
                            isActive ? theme.accent : theme.mutedForeground.opacity(0.4)
                        )
                        .frame(width: 14)
                    }

                    if isRenaming {
                        TextField("", text: $renameValue)
                            .font(.epBody).fontWeight(.medium)
                            .textFieldStyle(.plain)
                            .onSubmit { commitRename() }
                            .onAppear { renameValue = item.title }
                    } else {
                        Text(item.title.isEmpty ? "Untitled" : item.title)
                            .font(.epBody).fontWeight(isActive ? .semibold : .regular)
                            .foregroundStyle(
                                isActive
                                    ? theme.foreground
                                    : (item.isFavorite
                                        ? favoriteHighlight
                                        : theme.foreground.opacity(0.8))
                            )
                            .lineLimit(1)
                    }

                    Spacer()

                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(favoriteHighlight)
                    }

                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(theme.accent.opacity(0.8))
                    }

                    if isActive {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.leading, CGFloat(indent) * 16 + 10)
                .padding(.trailing, 10)
                .padding(.vertical, 4)
                .background {
                    if isActive {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(theme.accent.opacity(0.1))
                    } else if item.isFavorite {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(favoriteHighlight.opacity(theme.isDark ? 0.10 : 0.08))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .draggable("page:\(item.id)")
            .accessibilityLabel(item.title.isEmpty ? "Untitled" : item.title)
            .accessibilityHint("Open note — drag to move into folder")
            .accessibilityAddTraits(isActive ? .isSelected : [])
            .contextMenu {
                Button("Open in New Window") {
                    onAction(.openPageInNewWindow(item.id))
                }
                Divider()
                Button {
                    onAction(.summarize(id: item.id, title: item.title))
                } label: {
                    Label("Summary", systemImage: "text.alignleft")
                }
                Button {
                    onAction(.deepDive(id: item.id, title: item.title))
                } label: {
                    Label("Deep Dive", systemImage: "magnifyingglass.circle")
                }
                Button {
                    onAction(.openInGraph(id: item.id))
                } label: {
                    Label("Open in Graph", systemImage: "point.3.connected.trianglepath.dotted")
                }
                Divider()
                Button("Rename") {
                    isRenaming = true
                    renameValue = item.title
                }
                Divider()
                Button(item.isFavorite ? "Unfavorite" : "Favorite") {
                    onAction(.toggleFavorite(item.id))
                }
                Button(item.isPinned ? "Unpin" : "Pin") {
                    onAction(.togglePin(item.id))
                }
                Divider()
                Button("Delete", role: .destructive) {
                    onAction(.requestDeletePage(item))
                }
            }
            .physicsHover(.subtle)
            .graphReactive(nodeId: item.id)
        }
    }

    private func commitRename() {
        let trimmed = renameValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onAction(.renamePage(id: item.id, newTitle: trimmed))
        }
        isRenaming = false
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let item: SidebarPageItem
    let onAction: (SidebarAction) -> Void

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Button {
            onAction(.openPage(item.id))
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if !item.emoji.isEmpty {
                        Text(item.emoji)
                            .font(.epSmall)
                    } else {
                        Image(
                            systemName: item.matchCategory == "Block Match"
                                ? "cube.transparent" : "doc.text"
                        )
                        .font(.epSmall)
                        .foregroundStyle(theme.accent.opacity(0.6))
                    }
                    Text(item.title.isEmpty ? "Untitled" : item.title)
                        .font(.epBody).fontWeight(.medium)
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)

                    if let category = item.matchCategory {
                        Text(category)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(theme.textTertiary.opacity(0.6))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                theme.muted.opacity(0.5),
                                in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                }
                if let snippet = item.snippet {
                    Text(snippet)
                        .font(.epCaption)
                        .foregroundStyle(theme.textSecondary.opacity(0.7))
                        .lineLimit(2)
                }
                if !item.tags.isEmpty && item.snippet == nil {
                    Text(item.tags.joined(separator: ", "))
                        .font(.epCaption)
                        .foregroundStyle(theme.mutedForeground)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(NativeCardButtonStyle())
    }
}

// MARK: - Empty Tree State

private struct EmptyTreeState: View {
    let onAction: (SidebarAction) -> Void

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(theme.accent.opacity(0.4))
            Text("No notes yet")
                .font(.epCaption)
                .foregroundStyle(theme.mutedForeground)
            Button("Create a page") {
                onAction(.createNewPage)
            }
            .font(.epCaption).fontWeight(.medium)
            .foregroundStyle(theme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - Editor Actions Bar
// ISOLATED View struct — uses @Query for dirty pages instead of reading
// vaultSync.dirtyPageCount. SwiftData only re-evaluates when the filtered
// result set changes, not on every VaultSyncService property mutation.

private struct EditorActionsBar: View {
    let activePageId: String?
    let onNewPage: () -> Void
    let onNewFolder: () -> Void
    let onNewCollection: () -> Void
    let onTodayJournal: () -> Void
    let onOrganize: () -> Void

    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(UIState.self) private var ui
    @State private var showChangesPopover = false

    // PERF: Filtered @Query — SwiftData only notifies when this result set changes.
    // Replaces vaultSync.dirtyPageCount which fetched ALL pages every evaluation.
    @Query(filter: #Predicate<SDPage> { $0.needsVaultSync == true })
    private var dirtyPages: [SDPage]

    var body: some View {
        HStack(spacing: 2) {
            SidebarIconButton(icon: "square.and.pencil", tooltip: "New Page") {
                onNewPage()
            }
            SidebarIconButton(icon: "folder.badge.plus", tooltip: "New Folder") {
                onNewFolder()
            }
            if NotesSidebarMetrics.showsBottomCollectionButton {
                SidebarIconButton(icon: "tray.full", tooltip: "New Collection") {
                    onNewCollection()
                }
            }
            SidebarIconButton(icon: "calendar.badge.plus", tooltip: "New Daily Note") {
                onTodayJournal()
            }

            Spacer()

            Divider()
                .frame(height: 14)
                .padding(.horizontal, 2)

            SidebarIconButton(icon: "square.and.arrow.down", tooltip: "Save (⌘S)") {
                if let pageId = activePageId {
                    vaultSync.savePage(pageId: pageId)
                }
            }

            SidebarIconButton(icon: "arrow.down.doc", tooltip: "Save All (⇧⌘S)") {
                vaultSync.saveAllDirtyPages()
            }
            .overlay(alignment: .topTrailing) {
                if dirtyPages.count > 0 {
                    Text("\(dirtyPages.count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.red))
                        .offset(x: 4, y: -4)
                }
            }

            SidebarIconButton(
                icon: showChangesPopover
                    ? NotesSidebarGlyph.vaultChanges.activeSymbolName
                    : NotesSidebarGlyph.vaultChanges.symbolName,
                tooltip: "Vault Changes"
            ) {
                showChangesPopover.toggle()
            }
            .popover(isPresented: $showChangesPopover) {
                VaultChangesPanel(dirtyPages: dirtyPages)
                    .frame(
                        width: NotesSidebarMetrics.changesPanelWidth,
                        height: NotesSidebarMetrics.changesPanelHeight
                    )
                    .preferredColorScheme(ui.theme.colorScheme)
            }

            VaultConnectionButton()

            Divider()
                .frame(height: 14)
                .padding(.horizontal, 2)

            SidebarIconButton(icon: "wand.and.stars", tooltip: "AI Organize") {
                onOrganize()
            }

            if NotesSidebarMetrics.showsBottomMiniChatButton {
                SidebarIconButton(icon: "bubble.left.and.bubble.right", tooltip: "Mini Chat") {
                    CommandPaletteWindowController.shared.toggleChatMode()
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

private struct VaultConnectionButton: View {
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync

    var body: some View {
        Menu {
            if let vaultURL = vaultSync.vaultURL {
                Text(vaultURL.lastPathComponent)
                Divider()
                Button("Change Vault") {
                    VaultConnectionActions.selectVaultFolder(notesUI: notesUI, vaultSync: vaultSync)
                }
                Button("Sync from Vault") {
                    Task { _ = await vaultSync.syncFromVault() }
                }
                Divider()
                Button("Disconnect Vault", role: .destructive) {
                    VaultConnectionActions.disconnect(notesUI: notesUI, vaultSync: vaultSync)
                }
            } else {
                Button("Select Vault Folder") {
                    VaultConnectionActions.selectVaultFolder(notesUI: notesUI, vaultSync: vaultSync)
                }
            }
        } label: {
            Image(systemName: vaultSync.vaultURL == nil ? "externaldrive.badge.plus" : "externaldrive")
                .font(.epBody)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(NativeToolbarButtonStyle())
        .help(vaultSync.vaultURL == nil ? "Select Vault" : "Vault Connection")
        .accessibilityLabel(vaultSync.vaultURL == nil ? "Select Vault" : "Vault Connection")
    }
}

// MARK: - Sidebar Icon Button
// Obsidian-style: icon-only with native macOS tooltip on hover.

private struct SidebarIconButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.epBody)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(NativeToolbarButtonStyle())
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }
}
