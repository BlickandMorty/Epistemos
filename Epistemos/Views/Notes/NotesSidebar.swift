import AppKit
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
    let normalizedTitle: String
    let emoji: String
    let isJournal: Bool
    let isFavorite: Bool
    let isPinned: Bool
    let isArchived: Bool
    let isTemplate: Bool
    let journalDate: String?
    let tags: [String]
    let normalizedTags: [String]
    let folderId: String?
    /// Denormalized subfolder path from SDPage.subfolder — always a plain String,
    /// never depends on relationship faulting. Used as fallback matching.
    let subfolder: String?
    /// Detected code language from filePath (e.g. "swift", "python"), nil for prose.
    let codeLanguage: String?
    /// FTS snippet from body/block search. Nil for title-only matches.
    var snippet: String?
    /// Category label for search results (e.g. "Body Match", "Block Match").
    var matchCategory: String?

    init(_ page: SDPage) {
        id = page.id
        title = page.title
        normalizedTitle = page.title.lowercased()
        emoji = page.emoji
        isJournal = page.isJournal
        isFavorite = page.isFavorite
        isPinned = page.isPinned
        isArchived = page.isArchived
        isTemplate = page.isTemplate
        journalDate = page.journalDate
        tags = page.tags
        normalizedTags = page.tags.map { $0.lowercased() }
        folderId = page.folder?.id
        subfolder = page.subfolder
        if let path = page.filePath {
            codeLanguage = CodeLanguage.detect(from: path)
        } else {
            codeLanguage = nil
        }
    }
}

private struct SidebarDocumentItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let url: URL
    let updatedAt: Date

    nonisolated init(id: String, title: String, url: URL, updatedAt: Date) {
        self.id = id
        self.title = title
        self.url = url
        self.updatedAt = updatedAt
    }
}

private struct SidebarFolderItem: Identifiable, Equatable {
    let id: String
    let name: String
    let isCollection: Bool
    let sortOrder: Int
    let parentId: String?
    var childFolderIds: [String]
    let relativePath: String
    /// Child pages from the active page query, with subfolder matching as fallback.
    var childPages: [SidebarPageItem]
    var descendantPageCount: Int

    init(_ folder: SDFolder, childPages: [SidebarPageItem] = []) {
        id = folder.id
        name = folder.name
        isCollection = folder.isCollection
        sortOrder = folder.sortOrder
        parentId = folder.parent?.id
        childFolderIds = (folder.children ?? []).sorted { $0.sortOrder < $1.sortOrder }.map(\.id)
        relativePath = folder.relativePath
        var seenIds = Set<String>()
        self.childPages = childPages.filter { page in
            guard !seenIds.contains(page.id) else { return false }
            seenIds.insert(page.id)
            return true
        }
        descendantPageCount = self.childPages.count
    }
}

private struct NotesSidebarFolderCacheSignature: Equatable {
    let id: String
    let name: String
    let isCollection: Bool
    let sortOrder: Int
    let parentId: String?
    let childFolderIds: [String]
    let childPageIds: [String]
    let relativePath: String

    init(_ folder: SDFolder, childPageIds: [String]) {
        id = folder.id
        name = folder.name
        isCollection = folder.isCollection
        sortOrder = folder.sortOrder
        parentId = folder.parent?.id
        childFolderIds = (folder.children ?? []).sorted { $0.sortOrder < $1.sortOrder }.map(\.id)
        self.childPageIds = childPageIds.sorted()
        relativePath = folder.relativePath
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

private struct SidebarPageSearchCatalogEntry: Equatable {
    let pageId: String
    let haystack: String
}

enum NotesSidebarSearchCachePolicy {
    static let maxCachedQueries = 12

    static func store<Value>(
        query: String,
        value: Value,
        order: inout [String],
        cache: inout [String: Value]
    ) {
        cache[query] = value
        order.removeAll { $0 == query }
        order.append(query)

        while order.count > maxCachedQueries {
            let evictedQuery = order.removeFirst()
            cache.removeValue(forKey: evictedQuery)
        }
    }
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
    case openDocument(URL)
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

struct NotesSidebarDeletePlan: Equatable {
    let pageIds: Set<String>
    let folderIds: Set<String>
}

private struct NotesSidebarPageDeletion {
    let page: SDPage
    let pageId: String
    let filePath: String?
    let deletedInsight: SDNoteInsight?
}

private struct NotesSidebarPageLocationSnapshot {
    let folder: SDFolder?
    let subfolder: String?
    let filePath: String?
    let updatedAt: Date

    init(_ page: SDPage) {
        folder = page.folder
        subfolder = page.subfolder
        filePath = page.filePath
        updatedAt = page.updatedAt
    }

    func restore(on page: SDPage) {
        page.folder = folder
        page.subfolder = subfolder
        page.filePath = filePath
        page.updatedAt = updatedAt
    }
}

private struct NotesSidebarTrackedPageMutation {
    let page: SDPage
    let snapshot: NotesSidebarPageLocationSnapshot
}

private struct NotesSidebarFolderMutationSnapshot {
    let folder: SDFolder
    let name: String
    let parent: SDFolder?
    let trackedPages: [NotesSidebarTrackedPageMutation]
}

enum NotesSidebarDeletePlanner {
    static func pageDeletion(pageId: String) -> NotesSidebarDeletePlan {
        NotesSidebarDeletePlan(pageIds: [pageId], folderIds: [])
    }

    static func folderTreeDeletion(
        rootId: String,
        childFolderIdsById: [String: [String]],
        pageIdsByFolderId: [String: [String]]
    ) -> NotesSidebarDeletePlan {
        var folderIds: Set<String> = []
        var stack = [rootId]

        while let folderId = stack.popLast() {
            guard folderIds.insert(folderId).inserted else { continue }
            stack.append(contentsOf: childFolderIdsById[folderId] ?? [])
        }

        var pageIds: Set<String> = []
        for folderId in folderIds {
            pageIds.formUnion(pageIdsByFolderId[folderId] ?? [])
        }

        return NotesSidebarDeletePlan(pageIds: pageIds, folderIds: folderIds)
    }
}

enum NotesSidebarDeletionSovereignGate {
    enum Target: Equatable {
        case page(title: String)
        case folder(name: String)
        case vaultDisconnect(name: String)
    }

    static func requirement(for target: Target) -> SovereignGateRequirement {
        .deviceOwnerAuthentication
    }

    static func reason(for target: Target) -> String {
        switch target {
        case let .page(title):
            return "Permanently delete page \"\(safeName(title))\"."
        case let .folder(name):
            return "Permanently delete folder \"\(safeName(name))\" and its contents."
        case let .vaultDisconnect(name):
            return "Disconnect vault \"\(safeName(name))\" and clear local vault state."
        }
    }

    private static func safeName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }
}

enum NotesSidebarVisibleTreeEntry: Equatable, Hashable {
    case folder(id: String, indent: Int)
    case page(id: String, indent: Int)
    case emptyFolder(id: String, indent: Int)
}

enum NotesSidebarVisibleTreeBuilder {
    static func build(
        rootFolderIds: [String],
        expandedFolderIds: Set<String>,
        childFolderIdsById: [String: [String]],
        pageIdsByFolderId: [String: [String]]
    ) -> [NotesSidebarVisibleTreeEntry] {
        var rows: [NotesSidebarVisibleTreeEntry] = []
        rows.reserveCapacity(rootFolderIds.count)

        for folderId in rootFolderIds {
            appendFolder(
                id: folderId,
                indent: 0,
                expandedFolderIds: expandedFolderIds,
                childFolderIdsById: childFolderIdsById,
                pageIdsByFolderId: pageIdsByFolderId,
                rows: &rows
            )
        }

        return rows
    }

    private static func appendFolder(
        id folderId: String,
        indent: Int,
        expandedFolderIds: Set<String>,
        childFolderIdsById: [String: [String]],
        pageIdsByFolderId: [String: [String]],
        rows: inout [NotesSidebarVisibleTreeEntry]
    ) {
        rows.append(.folder(id: folderId, indent: indent))

        guard expandedFolderIds.contains(folderId) else { return }

        let childFolderIds = childFolderIdsById[folderId] ?? []
        let pageIds = pageIdsByFolderId[folderId] ?? []

        if childFolderIds.isEmpty && pageIds.isEmpty {
            rows.append(.emptyFolder(id: folderId, indent: indent + 1))
            return
        }

        for childId in childFolderIds {
            appendFolder(
                id: childId,
                indent: indent + 1,
                expandedFolderIds: expandedFolderIds,
                childFolderIdsById: childFolderIdsById,
                pageIdsByFolderId: pageIdsByFolderId,
                rows: &rows
            )
        }

        for pageId in pageIds {
            rows.append(.page(id: pageId, indent: indent + 1))
        }
    }
}

enum NotesSidebarFolderMetrics {
    static func descendantPageCounts(
        folderIds: [String],
        childFolderIdsById: [String: [String]],
        pageIdsByFolderId: [String: [String]]
    ) -> [String: Int] {
        var memo: [String: Int] = [:]
        memo.reserveCapacity(folderIds.count)

        for folderId in folderIds {
            _ = descendantPageCount(
                folderId: folderId,
                childFolderIdsById: childFolderIdsById,
                pageIdsByFolderId: pageIdsByFolderId,
                memo: &memo
            )
        }

        return memo
    }

    private static func descendantPageCount(
        folderId: String,
        childFolderIdsById: [String: [String]],
        pageIdsByFolderId: [String: [String]],
        memo: inout [String: Int]
    ) -> Int {
        if let cached = memo[folderId] {
            return cached
        }

        var count = pageIdsByFolderId[folderId]?.count ?? 0
        for childFolderId in childFolderIdsById[folderId] ?? [] {
            count += descendantPageCount(
                folderId: childFolderId,
                childFolderIdsById: childFolderIdsById,
                pageIdsByFolderId: pageIdsByFolderId,
                memo: &memo
            )
        }

        memo[folderId] = count
        return count
    }
}

enum NotesSidebarMetrics {
    static let headerTopPadding: CGFloat = 14
    static let headerBottomPadding: CGFloat = 2
    static let searchBarTopPadding: CGFloat = 0
    static let overlapsTitlebar = false
    static let showsBottomCollectionButton = false
    static let showsBottomOrganizerButton = false
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

struct NotesSidebarHoverTickState {
    private(set) var isHovering = false
    private var lastTickTime: Date = .distantPast
    private let minimumInterval: TimeInterval = 0.08

    mutating func update(hovering: Bool) -> Bool {
        guard hovering != isHovering else { return false }
        isHovering = hovering
        guard hovering else { return false }
        let now = Date()
        guard now.timeIntervalSince(lastTickTime) >= minimumInterval else { return false }
        lastTickTime = now
        return true
    }
}

enum NotesSidebarHoverHapticPattern: String, Equatable, Sendable {
    case generic
    case levelChange
}

struct NotesSidebarHoverHapticRecipe: Equatable, Sendable {
    let pattern: NotesSidebarHoverHapticPattern
}

enum NotesSidebarHoverHapticStyle: Sendable {
    case file
    case folder

    var recipe: NotesSidebarHoverHapticRecipe {
        switch self {
        case .file:
            NotesSidebarHoverHapticRecipe(pattern: .generic)
        case .folder:
            NotesSidebarHoverHapticRecipe(pattern: .levelChange)
        }
    }

    @MainActor
    func perform() {
        switch recipe.pattern {
        case .generic:
            HapticHelper.sidebarHoverTick()
        case .levelChange:
            HapticHelper.softPump()
        }
    }
}

private struct NotesSidebarGlassBackdrop: View {
    let theme: EpistemosTheme

    var body: some View {
        ZStack {
            Color.clear
            Rectangle()
                .fill(.ultraThinMaterial)
            Rectangle()
                .fill(theme.isDark ? Color.black.opacity(0.32) : Color.white.opacity(0.55))
            NotesSidebarPixelDither(theme: theme)
                .opacity(theme.isDark ? 0.14 : 0.08)
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(theme.glassBorder.opacity(theme.isDark ? 0.46 : 0.34))
                .frame(width: 0.5)
        }
    }
}

private struct NotesSidebarPixelDither: View {
    let theme: EpistemosTheme

    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 7
            let pixel: CGFloat = 1.5
            let columns = max(Int(size.width / step), 1)
            let rows = max(Int(size.height / step), 1)
            let accent = theme.resolved.accent.color.opacity(theme.isDark ? 0.16 : 0.11)
            let highlight = Color.white.opacity(theme.isDark ? 0.05 : 0.22)

            for row in 0...rows {
                for column in 0...columns {
                    let key = (column * 31 + row * 17) % 19
                    guard key == 0 || key == 7 else { continue }
                    let rect = CGRect(
                        x: CGFloat(column) * step,
                        y: CGFloat(row) * step,
                        width: key == 0 ? pixel : 1,
                        height: key == 0 ? pixel : 1
                    )
                    context.fill(Path(rect), with: .color(key == 0 ? accent : highlight))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct NotesSidebarHeaderChrome: View {
    let theme: EpistemosTheme

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(theme.isDark ? 0.28 : 0.18)
            NotesSidebarPixelDither(theme: theme)
                .opacity(theme.isDark ? 0.18 : 0.12)
            Rectangle()
                .fill(theme.glassBorder.opacity(theme.isDark ? 0.44 : 0.30))
                .frame(height: 0.5)
        }
    }
}

private struct NotesSidebarSearchChrome: View {
    let theme: EpistemosTheme
    let isFocused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        shape
            .fill(.ultraThinMaterial)
            .overlay {
                shape.fill(
                    theme.isDark
                        ? Color.black.opacity(isFocused ? 0.22 : 0.16)
                        : Color.white.opacity(isFocused ? 0.46 : 0.34)
                )
            }
            .overlay {
                NotesSidebarPixelDither(theme: theme)
                    .clipShape(shape)
                    .opacity(isFocused ? 0.20 : 0.12)
            }
            .overlay {
                shape.strokeBorder(
                    isFocused
                        ? theme.resolved.accent.color.opacity(0.36)
                        : theme.glassBorder.opacity(theme.isDark ? 0.48 : 0.36),
                    lineWidth: 0.65
                )
            }
    }
}

private struct NotesSidebarRowChrome: View {
    let theme: EpistemosTheme
    var isActive = false
    var isDropTarget = false
    var isFavorite = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        if isActive || isDropTarget || isFavorite {
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.fill(tint)
                }
                .overlay {
                    NotesSidebarPixelDither(theme: theme)
                        .clipShape(shape)
                        .opacity(isActive || isDropTarget ? 0.24 : 0.12)
                }
                .overlay {
                    shape.strokeBorder(border, lineWidth: isDropTarget ? 0.9 : 0.55)
                }
        }
    }

    private var tint: Color {
        if isDropTarget {
            return theme.resolved.accent.color.opacity(theme.isDark ? 0.20 : 0.14)
        }
        if isActive {
            return theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.11)
        }
        return theme.fontAccent.opacity(theme.isDark ? 0.12 : 0.08)
    }

    private var border: Color {
        if isDropTarget {
            return theme.resolved.accent.color.opacity(0.46)
        }
        if isActive {
            return theme.resolved.accent.color.opacity(theme.isDark ? 0.36 : 0.28)
        }
        return theme.glassBorder.opacity(theme.isDark ? 0.44 : 0.30)
    }
}

// MARK: - Notes Sidebar
// Obsidian-style file tree: vault → folders (SDFolder) → pages.
// Loose pages (not in any folder) appear at root level alongside folders.
// Journal entries are grouped under a special collapsible "Journal" folder.

struct NotesSidebar: View {
    let allPages: [SDPage]
    let allFolders: [SDFolder]
    var showsModelVaultsSection = true

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var bodySearchResults: [SidebarPageItem] = []
    @State private var pendingDeletePage: SidebarPageItem?
    @State private var pendingDeleteFolder: SidebarFolderItem?
    // W9.13 — daily-note quick-glance sheet. Toggled by the "Today"
    // button in the bottom bar. Shows DailyNoteView with the
    // currently selected day plus the FSRS due-review section.
    @State private var dailyNoteSheetDate: Date? = nil

    /// W9.13 — Identifiable Date wrapper so SwiftUI's `.sheet(item:)`
    /// can drive presentation off the optional date binding.
    private struct SheetDateBox: Identifiable {
        let date: Date
        var id: TimeInterval { date.timeIntervalSince1970 }
    }
    @FocusState private var isSearchFocused: Bool

    // MARK: - Cached value-type mappings (breaks @Observable tracking)
    // Rebuilt on structural changes only — NOT on every body evaluation.
    // This prevents 1300+ observation registrations per eval cycle.
    @State private var cachedPageItems: [SidebarPageItem] = []
    @State private var cachedPageById: [String: SidebarPageItem] = [:]
    @State private var cachedFolderItems: [SidebarFolderItem] = []
    @State private var cachedFolderCacheSignature: [NotesSidebarFolderCacheSignature] = []
    @State private var cachedFolderById: [String: SidebarFolderItem] = [:]
    @State private var cachedChildFolderIdsById: [String: [String]] = [:]
    @State private var cachedPageIdsByFolderId: [String: [String]] = [:]
    @State private var cachedIdeaItems: [SidebarIdeaItem] = []
    @State private var cachedDocumentItems: [SidebarDocumentItem] = []
    @State private var cachedPinnedPageItems: [SidebarPageItem] = []
    @State private var cachedLoosePageItems: [SidebarPageItem] = []
    @State private var cachedCollectionFolderItems: [SidebarFolderItem] = []
    @State private var cachedRootFolderItems: [SidebarFolderItem] = []
    @State private var cachedJournalPageItems: [SidebarPageItem] = []
    @State private var cachedPageSearchCatalog: [SidebarPageSearchCatalogEntry] = []
    @State private var cachedPageSearchCatalogById: [String: SidebarPageSearchCatalogEntry] = [:]
    @State private var cachedPageSearchTrigramIndex = TrigramSearchIndex<String>()
    @State private var cachedTitleSearchResultIDsByQuery: [String: [String]] = [:]
    @State private var cachedBodySearchResultsByQuery: [String: [SidebarPageItem]] = [:]
    @State private var cachedTitleSearchQueryOrder: [String] = []
    @State private var cachedBodySearchQueryOrder: [String] = []
    @State private var epdocDocumentScanTask: Task<Void, Never>?
    @State private var epdocDocumentScanVaultURL: URL?
    @State private var hasDailyNotesFolder = false
    @State private var rebuildTask: Task<Void, Never>?
    @State private var bodySearchTask: Task<Void, Never>?
    @State private var titleSearchResults: [SidebarPageItem] = []

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }
    private var currentSelectedPageId: String? { selectedPageId ?? notesUI.activePageId }
    private var hasDisconnectedCachedContent: Bool {
        vaultSync.vaultURL == nil && (!cachedPageItems.isEmpty || !cachedFolderItems.isEmpty)
    }

    nonisolated static func shouldDisplayInPrimaryTree(
        _ page: SDPage,
        modelVaultRootURL: URL = ModelVaultsSidebarSection.modelVaultsRootURL()
    ) -> Bool {
        guard let filePath = page.filePath else { return true }
        return !ModelVaultBrowserStore.isModelVaultPath(filePath, rootURL: modelVaultRootURL)
    }


    /// Coalesces multiple `setNeedsRebuild()` calls into a single `rebuildCache()`
    /// on the next run loop tick. Prevents 13+ redundant rebuilds per event cycle.
    private func setNeedsRebuild() {
        rebuildTask?.cancel()
        rebuildTask = Task { @MainActor in
            rebuildCache()
        }
    }

    private func rebuildCache() {
        refreshEpdocDocuments(in: vaultSync.vaultURL)

        let primaryPages = allPages.filter { page in
            Self.shouldDisplayInPrimaryTree(page)
        }

        // Early exit: if sidebar-relevant properties haven't changed, skip the
        // expensive rebuild. This prevents the 5s prose editor save cycle from
        // triggering full cache reconstruction when only body/updatedAt changed.
        let newItems = primaryPages.map { SidebarPageItem($0) }
        let newPageItemsByFolderId = Dictionary(
            grouping: newItems.filter { !$0.isArchived && $0.folderId != nil },
            by: { $0.folderId ?? "" }
        )
        let newPageIdsByFolderId = newPageItemsByFolderId.mapValues { pages in
            pages.map(\.id)
        }
        let newFolderSignature = allFolders.map { folder in
            NotesSidebarFolderCacheSignature(
                folder,
                childPageIds: newPageIdsByFolderId[folder.id] ?? []
            )
        }
        if newItems == cachedPageItems && newFolderSignature == cachedFolderCacheSignature {
            return
        }

        // Deduplicate by ID to prevent SwiftUI FAULT-level duplicate ID errors.
        // SwiftData @Query can return the same SDPage multiple times during merges.
        var seenPageIds = Set<String>()
        cachedPageItems = newItems.filter { item in
            guard !seenPageIds.contains(item.id) else { return false }
            seenPageIds.insert(item.id)
            return true
        }
        cachedPageById = Dictionary(
            cachedPageItems.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        cachedPageSearchCatalog = cachedPageItems.map { item in
            SidebarPageSearchCatalogEntry(
                pageId: item.id,
                haystack: ([item.normalizedTitle] + item.normalizedTags).joined(separator: "\n")
            )
        }
        cachedPageSearchCatalogById = Dictionary(
            cachedPageSearchCatalog.map { ($0.pageId, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        cachedTitleSearchResultIDsByQuery.removeAll(keepingCapacity: true)
        cachedBodySearchResultsByQuery.removeAll(keepingCapacity: true)
        cachedTitleSearchQueryOrder.removeAll(keepingCapacity: true)
        cachedBodySearchQueryOrder.removeAll(keepingCapacity: true)

        cachedPageSearchTrigramIndex.rebuild(
            cachedPageSearchCatalog.map { (key: $0.pageId, text: $0.haystack) }
        )
        cachedFolderItems = allFolders.map { folder in
            SidebarFolderItem(
                folder,
                childPages: newPageItemsByFolderId[folder.id] ?? []
            )
        }
        cachedFolderCacheSignature = newFolderSignature

        // Fallback: if the active page query has not resolved a folder relationship,
        // match pages to folders using the denormalized subfolder path -> folder.relativePath.
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

        cachedChildFolderIdsById = Dictionary(
            cachedFolderItems.map { ($0.id, $0.childFolderIds) },
            uniquingKeysWith: { _, latest in latest }
        )
        cachedPageIdsByFolderId = Dictionary(
            cachedFolderItems.map { ($0.id, $0.childPages.map(\.id)) },
            uniquingKeysWith: { _, latest in latest }
        )

        let descendantCounts = NotesSidebarFolderMetrics.descendantPageCounts(
            folderIds: cachedFolderItems.map(\.id),
            childFolderIdsById: cachedChildFolderIdsById,
            pageIdsByFolderId: cachedPageIdsByFolderId
        )
        for index in cachedFolderItems.indices {
            let folderId = cachedFolderItems[index].id
            cachedFolderItems[index].descendantPageCount =
                descendantCounts[folderId] ?? cachedFolderItems[index].childPages.count
        }

        cachedFolderById = Dictionary(
            cachedFolderItems.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })

        cachedPinnedPageItems = cachedPageItems.filter { $0.isPinned && !$0.isArchived }
        let dailyNotesFolder = cachedFolderItems.first {
            $0.parentId == nil && $0.relativePath == SidebarSpecialFolders.dailyNotes
        }
        hasDailyNotesFolder = dailyNotesFolder != nil
        cachedCollectionFolderItems = cachedFolderItems.filter {
            $0.parentId == nil && $0.isCollection
        }
        cachedRootFolderItems = cachedFolderItems.filter {
            $0.parentId == nil
                && !$0.isCollection
                && $0.id != dailyNotesFolder?.id
        }
        cachedJournalPageItems =
            dailyNotesFolder?.childPages.filter(\.isJournal)
            ?? cachedPageItems.filter { $0.isJournal && $0.folderId == nil }
        cachedLoosePageItems = cachedPageItems.filter {
            !$0.isJournal && $0.folderId == nil && !$0.isTemplate
        }
        refreshTitleSearchResults(query: notesUI.searchQuery)

        // Collect ideas from all pages (JSON-decoded once per rebuild, not per render)
        var ideaItems: [SidebarIdeaItem] = []
        for page in primaryPages {
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

    private func refreshEpdocDocuments(in vaultURL: URL?, force: Bool = false) {
        guard let vaultURL else {
            epdocDocumentScanTask?.cancel()
            epdocDocumentScanTask = nil
            epdocDocumentScanVaultURL = nil
            cachedDocumentItems = []
            return
        }

        guard force || epdocDocumentScanVaultURL != vaultURL else { return }

        epdocDocumentScanTask?.cancel()
        epdocDocumentScanVaultURL = vaultURL
        epdocDocumentScanTask = Task { @MainActor in
            let documents = await Task.detached(priority: .utility) {
                Self.scanEpdocDocuments(in: vaultURL)
            }.value

            guard !Task.isCancelled,
                  epdocDocumentScanVaultURL == vaultURL,
                  vaultSync.vaultURL == vaultURL else {
                return
            }
            cachedDocumentItems = documents
        }
    }

    private nonisolated static func scanEpdocDocuments(in vaultURL: URL?) -> [SidebarDocumentItem] {
        guard let vaultURL else { return [] }
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var documents: [SidebarDocumentItem] = []
        for case let url as URL in enumerator where url.pathExtension == "epdoc" {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let updatedAt = values?.contentModificationDate ?? .distantPast
            let title = epdocTitle(at: url) ?? url.deletingPathExtension().lastPathComponent
            documents.append(
                SidebarDocumentItem(
                    id: url.path,
                    title: title.isEmpty ? "Untitled" : title,
                    url: url,
                    updatedAt: updatedAt
                )
            )
        }
        return documents.sorted {
            if $0.updatedAt == $1.updatedAt { return $0.title < $1.title }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private nonisolated static func epdocTitle(at url: URL) -> String? {
        let manifestURL = url.appendingPathComponent(EpdocPackageEntry.manifest)
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder.epdocCanonical.decode(EpdocManifest.self, from: data) else {
            return nil
        }
        let title = manifest.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
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

        // 2026-05-19: removed the "Notes" title HStack + NotesSidebarHeaderChrome
        // per user direction. The header was duplicating the SidebarShell's
        // ModeSwitcherControl ("Vault / Models / System") above it, and its
        // chrome blur (opacity 0.28/0.18) didn't match the body (0.32/0.55).
        // Letting the sidebar start at the search bar unifies the surface.
        VStack(spacing: 0) {
            searchBar
            // ISSUE-2026-05-12-001 — Fresh-user no-vault banner.
            // Fires when no vault is connected AND there is no cached
            // local content to fall back on. `DisconnectedCachedVaultNotice`
            // below handles the cached-rows-but-no-vault case; this one
            // handles the truly-empty first-launch state so users learn
            // they need to pick a folder before Halo / Shadow / search
            // can do anything useful.
            if vaultSync.vaultURL == nil && !hasDisconnectedCachedContent {
                NoVaultConnectedBanner {
                    VaultConnectionActions.selectVaultFolder(
                        notesUI: notesUI,
                        vaultSync: vaultSync
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
            if hasDisconnectedCachedContent {
                DisconnectedCachedVaultNotice()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }
            fileTree(folderItemById: fById, onAction: onAct)
            // Pass 10 — per-model vaults + involvement view. Collapsed
            // by default (@AppStorage-backed) so it never disrupts the
            // sidebar's default layout, and never loads the model-vault
            // directory until the user expands it. Kept here rather
            // than inside `fileTree` because it's a parallel top-level
            // surface, not part of the vault's note hierarchy.
            // 2026-05-19: removed the W9.7 single-row VaultSelectorView
            // ("Vaults · Current vault") per user direction. Multi-vault
            // support is not wired (selectionEnabled was permanently false),
            // so the row was dead chrome. When real known-vault switching
            // lands, restore the section here with the new picker.
            if showsModelVaultsSection {
                ModelVaultsSidebarSection(onSelectPage: onSelectPage)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                Divider().opacity(0.2)
            }
            bottomBar
        }
        .background {
            NotesSidebarGlassBackdrop(theme: theme)
                .ignoresSafeArea()
        }
        .onAppear {
            rebuildCache()
            // Deferred rebuild: VaultIndexActor may still be wiring folder relationships
            // when the sidebar first appears. Rebuild again after context merge settles.
            // 200ms is enough for SwiftData background→main context merge.
            scheduleDeferredRebuild(after: .milliseconds(200), source: "sidebar appear")
        }
        .onChange(of: allPages.count) { setNeedsRebuild() }
        .onChange(of: allFolders.count) { setNeedsRebuild() }
        .onReceive(NotificationCenter.default.publisher(for: vaultFoldersRepairedNotification)) {
            _ in
            // Delay to allow SwiftData's background-to-main context merge to complete.
            // The notification fires from VaultIndexActor (background ModelActor) — the main
            // context @Query results may not have updated yet when the notification arrives.
            scheduleDeferredRebuild(after: .milliseconds(200), source: "vault folder repair")
        }
        .alert(pageDeleteAlertTitle, isPresented: showPageDeleteAlert) {
            Button("Delete", role: .destructive) { requestPageDeleteAuthorization() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This page will be permanently deleted.")
        }
        .alert(folderDeleteAlertTitle, isPresented: showFolderDeleteAlert) {
            Button("Delete", role: .destructive) { requestFolderDeleteAuthorization() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(folderDeleteAlertMessage)
        }
        .onChange(of: notesUI.debouncedSearchQuery) { _, newValue in
            performBodySearch(query: newValue)
        }
        .onChange(of: notesUI.searchQuery) { _, newValue in
            refreshTitleSearchResults(query: newValue)
            if newValue.isEmpty { bodySearchResults = [] }
        }
        .onDisappear {
            rebuildTask?.cancel()
            bodySearchTask?.cancel()
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
        .background {
            NotesSidebarSearchChrome(theme: theme, isFocused: isSearchFocused)
        }
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
        let pinned = cachedPinnedPageItems
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
        let collections = cachedCollectionFolderItems
        if !collections.isEmpty {
            ForEach(
                visibleFolderRows(
                    rootFolders: collections
                ),
                id: \.self
            ) { row in
                folderTreeRow(
                    row,
                    folderItemById: fById,
                    onAction: onAction
                )
            }
        }

        // ── FOLDERS ── top-level folders (no parent, non-collection)
        let folders = cachedRootFolderItems
        if !folders.isEmpty {
            ForEach(
                visibleFolderRows(
                    rootFolders: folders
                ),
                id: \.self
            ) { row in
                folderTreeRow(
                    row,
                    folderItemById: fById,
                    onAction: onAction
                )
            }
        }

        // 2026-05-19: removed the "Daily" / JournalFolderRow section per
        // user direction. The journal/daily-notes surface was part of the
        // same simplification as removing the "Today's brief" button below.
        let _ = cachedJournalPageItems  // keep the cache binding alive for
                                        // sibling code that still reads it

        // Ideas section — all ideas across the vault
        if !cachedIdeaItems.isEmpty {
            IdeasFolderRow(
                ideas: cachedIdeaItems,
                isExpanded: notesUI.isIdeasExpanded,
                onAction: onAction,
                renderChildren: false
            )
            if notesUI.isIdeasExpanded {
                ForEach(cachedIdeaItems.prefix(20)) { idea in
                    IdeaRow(item: idea, onAction: onAction)
                }
            }
        }

        if !cachedDocumentItems.isEmpty {
            DocumentsSection(
                documents: cachedDocumentItems,
                onAction: onAction
            )
        }

        // ── FILES SECTION ── loose pages not in any folder.
        let loose = cachedLoosePageItems
        VStack(alignment: .leading, spacing: 0) {
            if !loose.isEmpty || !folders.isEmpty {
                Text("Files")
                    .font(AppHeadingRole.section.font)
                    .foregroundStyle(theme.fontAccent)
                    .textCase(.uppercase)
                    .tracking(AppHeadingRole.section.tracking)
                    .padding(.horizontal, 14)
                    .padding(.top, folders.isEmpty ? 6 : 12)
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
                Text("Try fewer keywords.")
                    .font(.epSmall)
                    .foregroundStyle(theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            ForEach(results) { page in
                SearchResultRow(item: page, onAction: onAction)
            }
        }
    }

    private func visibleFolderRows(
        rootFolders: [SidebarFolderItem]
    ) -> [NotesSidebarVisibleTreeEntry] {
        NotesSidebarVisibleTreeBuilder.build(
            rootFolderIds: rootFolders.map(\.id),
            expandedFolderIds: notesUI.expandedFolderIds,
            childFolderIdsById: cachedChildFolderIdsById,
            pageIdsByFolderId: cachedPageIdsByFolderId
        )
    }

    @ViewBuilder
    private func folderTreeRow(
        _ row: NotesSidebarVisibleTreeEntry,
        folderItemById: [String: SidebarFolderItem],
        onAction: @escaping (SidebarAction) -> Void
    ) -> some View {
        switch row {
        case let .folder(id, indent):
            if let folder = folderItemById[id] {
                FolderRow(
                    item: folder,
                    indent: indent,
                    folderItemById: folderItemById,
                    selectedPageId: currentSelectedPageId,
                    onAction: onAction,
                    renderChildren: false
                )
            }
        case let .page(id, indent):
            if let page = cachedPageById[id] {
                FileRow(
                    item: page,
                    indent: indent,
                    selectedPageId: currentSelectedPageId,
                    onAction: onAction
                )
            }
        case let .emptyFolder(_, indent):
            Text("Empty folder")
                .font(.epSmall)
                .foregroundStyle(theme.textTertiary)
                .padding(.leading, CGFloat(indent) * 16 + 24)
                .padding(.vertical, 4)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // All actions on one row — editor + creation consolidated.
            // EditorActionsBar is isolated (has its own @Query for dirty pages).
            EditorActionsBar(
                activePageId: currentSelectedPageId,
                onNewDocument: { openNewEpdocDocument() },
                onNewPage: {
                    Task {
                        if let pageId = await vaultSync.createPage(title: "Untitled", allowVaultSelectionPrompt: true) {
                            openInEditor(pageId)
                        }
                    }
                },
                onNewFolder: { createFolder(title: "Untitled Folder") },
                onNewCollection: { createCollection(title: "Untitled Collection") },
                onTodayJournal: { Task { await getOrCreateTodayJournal() } }
            )
            // 2026-05-19: removed the W9.13 "Today's brief" button and its
            // DailyNoteView sheet per user direction. The daily-note quick
            // glance + FSRS due-for-review surface didn't fit the simplified
            // sidebar; the journal folder section was also removed.
        }
    }

    // MARK: - Search

    /// Two-tier search: title/tags from in-memory pageItems (instant),
    /// body matches via pre-built trigram index (microseconds).
    private var filteredSearchResults: [SidebarPageItem] {
        // Tier 2: merge body matches (populated async by onChange)
        let titleIds = Set(titleSearchResults.map(\.id))
        let uniqueBodyMatches = bodySearchResults.filter { !titleIds.contains($0.id) }

        let combined = titleSearchResults + uniqueBodyMatches
        return Array(combined.prefix(50))
    }

    private func refreshTitleSearchResults(query: String) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else {
            titleSearchResults = []
            return
        }

        let matchedIDs = cachedTitleSearchResultIDsByQuery[normalizedQuery] ?? {
            let candidateIDs = longestCachedTitleSearchPrefixIDs(for: normalizedQuery)
                ?? cachedPageSearchTrigramIndex.orderedCandidates(for: normalizedQuery)
                ?? cachedPageSearchCatalog.map(\.pageId)
            let filtered = candidateIDs.filter { pageId in
                cachedPageSearchCatalogById[pageId]?.haystack.contains(normalizedQuery) == true
            }
            NotesSidebarSearchCachePolicy.store(
                query: normalizedQuery,
                value: filtered,
                order: &cachedTitleSearchQueryOrder,
                cache: &cachedTitleSearchResultIDsByQuery
            )
            return filtered
        }()
        NotesSidebarSearchCachePolicy.store(
            query: normalizedQuery,
            value: matchedIDs,
            order: &cachedTitleSearchQueryOrder,
            cache: &cachedTitleSearchResultIDsByQuery
        )
        titleSearchResults = matchedIDs.compactMap { cachedPageById[$0] }
    }

    private func longestCachedTitleSearchPrefixIDs(for query: String) -> [String]? {
        guard query.count > 1 else { return nil }

        var prefix = query
        while prefix.count > 1 {
            prefix.removeLast()
            if let cached = cachedTitleSearchResultIDsByQuery[prefix] {
                return cached
            }
        }
        return nil
    }

    /// Run body + block search via FTS5 with snippets.
    private func performBodySearch(query: String) {
        bodySearchTask?.cancel()
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            bodySearchResults = []
            return
        }
        guard normalizedQuery.count >= 3 else {
            bodySearchResults = []
            return
        }
        if let cached = cachedBodySearchResultsByQuery[normalizedQuery] {
            bodySearchResults = cached
            return
        }
        let pageById = cachedPageById
        bodySearchTask = Task(priority: .userInitiated) {
            async let bodyHits = vaultSync.searchFullAsync(query: normalizedQuery, limit: 30)
            async let blockHits = vaultSync.searchBlocksAsync(query: normalizedQuery, limit: 10)
            let (resolvedBodyHits, resolvedBlockHits) = await (bodyHits, blockHits)
            guard !Task.isCancelled else { return }

            var results: [SidebarPageItem] = []
            var seenPageIds: Set<String> = []

            // Body matches — with snippet
            for hit in resolvedBodyHits {
                let pageId = hit.pageId
                guard !seenPageIds.contains(pageId) else { continue }
                seenPageIds.insert(pageId)
                if var item = pageById[pageId] {
                    let rawSnippet = hit.snippet
                        .replacingOccurrences(of: "<b>", with: "")
                        .replacingOccurrences(of: "</b>", with: "")
                    item.snippet = rawSnippet.isEmpty ? nil : rawSnippet
                    item.matchCategory = "Body Match"
                    results.append(item)
                }
            }

            // Block matches — with snippet, deduplicated against body results
            for hit in resolvedBlockHits {
                let pageId = hit.pageId
                guard !seenPageIds.contains(pageId) else { continue }
                seenPageIds.insert(pageId)
                if var item = pageById[pageId] {
                    let rawSnippet = hit.snippet
                        .replacingOccurrences(of: "<b>", with: "")
                        .replacingOccurrences(of: "</b>", with: "")
                    item.snippet = rawSnippet.isEmpty ? nil : rawSnippet
                    item.matchCategory = "Block Match"
                    results.append(item)
                }
            }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                guard notesUI.debouncedSearchQuery == normalizedQuery || notesUI.searchQuery == normalizedQuery else {
                    return
                }
                NotesSidebarSearchCachePolicy.store(
                    query: normalizedQuery,
                    value: results,
                    order: &cachedBodySearchQueryOrder,
                    cache: &cachedBodySearchResultsByQuery
                )
                bodySearchResults = results
            }
        }
    }

    // MARK: - SwiftData Helpers

    private func scheduleDeferredRebuild(after delay: Duration, source: String) {
        Task { @MainActor in
            do {
                try await Task.sleep(for: delay)
            } catch is CancellationError {
                return
            } catch {
                Log.notes.error(
                    "NotesSidebar: deferred rebuild delay failed for \(source, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                return
            }
            rebuildCache()
        }
    }

    private func fetchPage(_ id: String) -> SDPage? {
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == id })
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            Log.notes.error(
                "NotesSidebar: failed to fetch page \(String(id.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func fetchFolder(_ id: String) -> SDFolder? {
        let descriptor = FetchDescriptor<SDFolder>(predicate: #Predicate { $0.id == id })
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            Log.notes.error(
                "NotesSidebar: failed to fetch folder \(String(id.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    @discardableResult
    private func saveSidebarChanges(rebuild: Bool = true, reason: String = "sidebar changes") -> Bool {
        persistSidebarMutation(rebuild: rebuild, reason: reason) {}
    }

    @discardableResult
    private func persistSidebarMutation(
        rebuild: Bool = true,
        reason: String = "sidebar changes",
        restoreState: () -> Void
    ) -> Bool {
        do {
            try modelContext.save()
        } catch {
            restoreState()
            Log.notes.error(
                "NotesSidebar: failed to save \(reason, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            if rebuild {
                setNeedsRebuild()
            }
            return false
        }
        if rebuild {
            setNeedsRebuild()
        }
        return true
    }

    private func applyDeletePlan(_ plan: NotesSidebarDeletePlan) {
        guard !plan.pageIds.isEmpty || !plan.folderIds.isEmpty else { return }

        cachedPageItems.removeAll { plan.pageIds.contains($0.id) }
        cachedPageById = Dictionary(
            cachedPageItems.map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )

        cachedFolderItems = cachedFolderItems.compactMap { folder in
            guard !plan.folderIds.contains(folder.id) else { return nil }
            var folder = folder
            folder.childFolderIds.removeAll { plan.folderIds.contains($0) }
            folder.childPages.removeAll { plan.pageIds.contains($0.id) }
            return folder
        }
        cachedFolderById = Dictionary(
            cachedFolderItems.map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        cachedChildFolderIdsById = cachedFolderById.mapValues(\.childFolderIds)
        cachedPageIdsByFolderId = cachedFolderById.mapValues { $0.childPages.map(\.id) }
    }

    private func rootFolder(named name: String) -> SDFolder? {
        allFolders.first { $0.parent == nil && $0.relativePath == name }
    }

    private func ensureRootFolder(named name: String, isCollection: Bool = false) -> SDFolder? {
        if let existing = rootFolder(named: name) {
            if isCollection && !existing.isCollection {
                let originalIsCollection = existing.isCollection
                existing.isCollection = true
                guard persistSidebarMutation(reason: "collection root enable", restoreState: {
                    existing.isCollection = originalIsCollection
                }) else {
                    return existing
                }
                CollectionRegistry.shared.setCollection(existing.name, true)
            }
            return existing
        }

        let folder = SDFolder(name: name)
        folder.isCollection = isCollection
        modelContext.insert(folder)
        let restoreModel: () -> Void = {
            modelContext.delete(folder)
        }
        guard persistSidebarMutation(reason: "root folder create", restoreState: restoreModel) else {
            return nil
        }
        // RCA13: rollback the SDFolder insertion if mkdir fails so the
        // model can't claim a folder exists with no disk backing.
        if !vaultSync.createDirectory(relativePath: folder.relativePath) {
            restoreModel()
            _ = persistSidebarMutation(
                reason: "root folder create rollback after FS failure",
                restoreState: {}
            )
            return nil
        }
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

    private func captureFolderMutationSnapshot(_ folder: SDFolder) -> NotesSidebarFolderMutationSnapshot {
        let trackedPages = pagesInFolderTree(folder).map { page in
            NotesSidebarTrackedPageMutation(
                page: page,
                snapshot: NotesSidebarPageLocationSnapshot(page)
            )
        }
        return NotesSidebarFolderMutationSnapshot(
            folder: folder,
            name: folder.name,
            parent: folder.parent,
            trackedPages: trackedPages
        )
    }

    private func restoreFolderMutationSnapshot(_ snapshot: NotesSidebarFolderMutationSnapshot) {
        snapshot.folder.name = snapshot.name
        snapshot.folder.parent = snapshot.parent
        for trackedPage in snapshot.trackedPages {
            trackedPage.snapshot.restore(on: trackedPage.page)
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
                let originalTitle = page.title
                let originalUpdatedAt = page.updatedAt
                let originalNeedsVaultSync = page.needsVaultSync
                page.title = sanitized
                page.updatedAt = .now
                page.needsVaultSync = true
                guard persistSidebarMutation(rebuild: false, reason: "page rename", restoreState: {
                    page.title = originalTitle
                    page.updatedAt = originalUpdatedAt
                    page.needsVaultSync = originalNeedsVaultSync
                }) else {
                    return
                }
                // Rename the vault .md file to match the new title
                vaultSync.renamePageFile(pageId: id, newTitle: sanitized)
                setNeedsRebuild()
            }

        case .requestDeletePage(let item):
            pendingDeletePage = item

        case .toggleFavorite(let id):
            if let page = fetchPage(id) {
                let originalIsFavorite = page.isFavorite
                page.isFavorite.toggle()
                _ = persistSidebarMutation(reason: "favorite toggle") {
                    page.isFavorite = originalIsFavorite
                }
            }

        case .togglePin(let id):
            if let page = fetchPage(id) {
                let originalIsPinned = page.isPinned
                page.isPinned.toggle()
                _ = persistSidebarMutation(reason: "pin toggle") {
                    page.isPinned = originalIsPinned
                }
            }

        case .renameFolder(let id, let newName):
            if let folder = fetchFolder(id) {
                let oldName = folder.name
                let wasCollection = folder.isCollection
                let oldPath = folder.relativePath
                let snapshot = captureFolderMutationSnapshot(folder)
                folder.name = newName
                syncPagePaths(in: folder, oldPath: oldPath)
                let newPath = folder.relativePath
                guard persistSidebarMutation(reason: "folder rename", restoreState: {
                    restoreFolderMutationSnapshot(snapshot)
                }) else {
                    return
                }
                if wasCollection {
                    CollectionRegistry.shared.setCollection(oldName, false)
                    CollectionRegistry.shared.setCollection(newName, true)
                }
                vaultSync.renameDirectory(from: oldPath, to: newPath)
            }

        case .requestDeleteFolder(let item):
            pendingDeleteFolder = item

        case .newPageInFolder(let folderId):
            Task {
                guard let folder = fetchFolder(folderId) else { return }
                let subfolder = folder.relativePath
                if let pageId = await vaultSync.createPage(
                    title: "Untitled",
                    subfolder: subfolder,
                    allowVaultSelectionPrompt: true
                )
                {
                    if let page = fetchPage(pageId),
                        let folder = fetchFolder(folderId)
                    {
                        let snapshot = NotesSidebarPageLocationSnapshot(page)
                        page.folder = folder
                        page.subfolder = subfolder
                        _ = persistSidebarMutation(reason: "folder page create attach") {
                            snapshot.restore(on: page)
                        }
                    }
                    openInEditor(pageId)
                }
            }

        case .newSubfolder(let parentId):
            if let parent = fetchFolder(parentId) {
                let child = SDFolder(name: "Untitled Folder")
                child.parent = parent
                modelContext.insert(child)
                let restoreModel: () -> Void = {
                    modelContext.delete(child)
                }
                guard persistSidebarMutation(reason: "subfolder create", restoreState: restoreModel) else {
                    return
                }
                // RCA13: rollback the SDFolder insert if mkdir fails.
                if !vaultSync.createDirectory(relativePath: child.relativePath) {
                    restoreModel()
                    _ = persistSidebarMutation(
                        reason: "subfolder create rollback after FS failure",
                        restoreState: {}
                    )
                    return
                }
            }

        case .toggleCollection(let folderId):
            if let folder = fetchFolder(folderId) {
                let originalIsCollection = folder.isCollection
                folder.isCollection.toggle()
                guard persistSidebarMutation(reason: "collection toggle", restoreState: {
                    folder.isCollection = originalIsCollection
                }) else {
                    return
                }
                CollectionRegistry.shared.setCollection(folder.name, folder.isCollection)
            }

        case .movePageToFolder(let pageId, let folderId):
            if let page = fetchPage(pageId),
                let folder = fetchFolder(folderId)
            {
                let snapshot = NotesSidebarPageLocationSnapshot(page)
                page.folder = folder
                page.subfolder = folder.relativePath
                let restoreModel: () -> Void = {
                    snapshot.restore(on: page)
                }
                guard persistSidebarMutation(reason: "page move to folder", restoreState: restoreModel) else {
                    return
                }
                // RCA13: rollback the model so SwiftData + disk stay in lockstep.
                if !vaultSync.movePage(pageId: pageId, toSubfolder: folder.relativePath) {
                    restoreModel()
                    _ = persistSidebarMutation(
                        reason: "page move to folder rollback after FS failure",
                        restoreState: {}
                    )
                    return
                }
            }

        case .moveFolderInto(let childId, let parentId):
            if let child = fetchFolder(childId),
                let parent = fetchFolder(parentId)
            {
                let oldPath = child.relativePath
                let snapshot = captureFolderMutationSnapshot(child)
                child.parent = parent
                syncPagePaths(in: child, oldPath: oldPath)
                let restoreModel: () -> Void = {
                    restoreFolderMutationSnapshot(snapshot)
                }
                guard persistSidebarMutation(reason: "folder move into folder", restoreState: restoreModel) else {
                    return
                }
                // RCA13: rollback if the directory rename fails.
                if !vaultSync.renameDirectory(from: oldPath, to: child.relativePath) {
                    restoreModel()
                    _ = persistSidebarMutation(
                        reason: "folder move into folder rollback after FS failure",
                        restoreState: {}
                    )
                    return
                }
            }

        case .movePageToRoot(let pageId):
            if let page = fetchPage(pageId) {
                let snapshot = NotesSidebarPageLocationSnapshot(page)
                page.folder = nil
                page.subfolder = nil
                let restoreModel: () -> Void = {
                    snapshot.restore(on: page)
                }
                guard persistSidebarMutation(reason: "page move to root", restoreState: restoreModel) else {
                    return
                }
                // RCA13: rollback if the file move fails.
                if !vaultSync.movePage(pageId: pageId, toSubfolder: nil) {
                    restoreModel()
                    _ = persistSidebarMutation(
                        reason: "page move to root rollback after FS failure",
                        restoreState: {}
                    )
                    return
                }
            }

        case .moveFolderToRoot(let folderId):
            if let folder = fetchFolder(folderId) {
                let oldPath = folder.relativePath
                let snapshot = captureFolderMutationSnapshot(folder)
                folder.parent = nil
                syncPagePaths(in: folder, oldPath: oldPath)
                let restoreModel: () -> Void = {
                    restoreFolderMutationSnapshot(snapshot)
                }
                guard persistSidebarMutation(reason: "folder move to root", restoreState: restoreModel) else {
                    return
                }
                // RCA13: rollback if the directory rename fails.
                if !vaultSync.renameDirectory(from: oldPath, to: folder.relativePath) {
                    restoreModel()
                    _ = persistSidebarMutation(
                        reason: "folder move to root rollback after FS failure",
                        restoreState: {}
                    )
                    return
                }
            }

        case .createNewPage:
            Task {
                if let pageId = await vaultSync.createPage(title: "Untitled", allowVaultSelectionPrompt: true) {
                    openInEditor(pageId)
                }
            }

        case .newJournalEntry:
            Task {
                await getOrCreateTodayJournal()
            }

        case .openDocument(let url):
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
                if let error {
                    NSApplication.shared.presentError(error)
                }
            }

        case .toggleFolder(let id):
            withAnimation(reduceMotion ? nil : Motion.snap) { notesUI.toggleFolder(id) }

        case .toggleJournalFolder:
            withAnimation(reduceMotion ? nil : Motion.snap) { notesUI.isJournalExpanded.toggle() }

        case .toggleIdeasFolder:
            withAnimation(reduceMotion ? nil : Motion.snap) { notesUI.isIdeasExpanded.toggle() }

        case .openIdea(let pageId):
            openInEditor(pageId)

        case .collapseAll:
            withAnimation(reduceMotion ? nil : Motion.snap) { notesUI.collapseAllFolders() }

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

    private func preparePageDeletion(_ page: SDPage) -> NotesSidebarPageDeletion {
        let pageId = page.id
        let filePath = page.filePath
        let insightDesc = FetchDescriptor<SDNoteInsight>(
            predicate: #Predicate { $0.pageId == pageId })
        var deletedInsight: SDNoteInsight?
        do {
            if let insight = try modelContext.fetch(insightDesc).first {
                deletedInsight = insight
                modelContext.delete(insight)
            }
        } catch {
            Log.notes.error(
                "NotesSidebar: failed to fetch note insight for deleted page \(String(pageId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
        modelContext.delete(page)
        return NotesSidebarPageDeletion(
            page: page,
            pageId: pageId,
            filePath: filePath,
            deletedInsight: deletedInsight
        )
    }

    private func restorePageDeletion(_ deletion: NotesSidebarPageDeletion) {
        if let deletedInsight = deletion.deletedInsight {
            modelContext.insert(deletedInsight)
        }
        modelContext.insert(deletion.page)
    }

    private func finalizePageDeletion(_ deletion: NotesSidebarPageDeletion, removeVaultFile: Bool) {
        clearSelectionIfNeeded(pageId: deletion.pageId)
        notesUI.closeTab(deletion.pageId)
        NoteWindowManager.shared.closeWindowDisplaying(pageId: deletion.pageId)
        AppBootstrap.shared?.instantRecallService.removeNote(noteId: deletion.pageId)
        if removeVaultFile {
            vaultSync.deletePageFromDisk(filePath: deletion.filePath)
        }
        NoteFileStorage.deleteBody(pageId: deletion.pageId)
        SpotlightIndexer.deindex(deletion.pageId)
    }

    private func folderSubtreeIds(_ folder: SDFolder) -> Set<String> {
        var ids: Set<String> = [folder.id]
        for child in folder.children ?? [] {
            ids.formUnion(folderSubtreeIds(child))
        }
        return ids
    }

    private func pagesInFolderTree(_ folder: SDFolder) -> [SDPage] {
        let subtreeIds = folderSubtreeIds(folder)
        let relativePath = folder.relativePath
        let nestedPrefix = relativePath + "/"
        return allPages.filter { page in
            if let folderId = page.folder?.id, subtreeIds.contains(folderId) {
                return true
            }
            guard let subfolder = page.subfolder else { return false }
            return subfolder == relativePath || subfolder.hasPrefix(nestedPrefix)
        }
    }

    private func requestPageDeleteAuthorization() {
        guard let item = pendingDeletePage else { return }
        let target = NotesSidebarDeletionSovereignGate.Target.page(title: item.title)

        Task { @MainActor in
            let outcome = await AppBootstrap.shared?.sovereignGate.confirm(
                NotesSidebarDeletionSovereignGate.requirement(for: target),
                reason: NotesSidebarDeletionSovereignGate.reason(for: target)
            ) ?? .denied(.authenticationFailed)

            guard outcome == .allowed else {
                pendingDeletePage = nil
                return
            }

            performPageDelete(item)
        }
    }

    private func requestFolderDeleteAuthorization() {
        guard let item = pendingDeleteFolder else { return }
        let target = NotesSidebarDeletionSovereignGate.Target.folder(name: item.name)

        Task { @MainActor in
            let outcome = await AppBootstrap.shared?.sovereignGate.confirm(
                NotesSidebarDeletionSovereignGate.requirement(for: target),
                reason: NotesSidebarDeletionSovereignGate.reason(for: target)
            ) ?? .denied(.authenticationFailed)

            guard outcome == .allowed else {
                pendingDeleteFolder = nil
                return
            }

            performFolderDelete(item)
        }
    }

    private func performPageDelete() {
        guard let item = pendingDeletePage else { return }
        performPageDelete(item)
    }

    private func performPageDelete(_ item: SidebarPageItem) {
        defer { pendingDeletePage = nil }
        let deletePlan = NotesSidebarDeletePlanner.pageDeletion(pageId: item.id)
        guard let page = fetchPage(item.id) else { return }
        let pageDeletion = preparePageDeletion(page)
        guard saveSidebarChanges(rebuild: false, reason: "page delete") else {
            restorePageDeletion(pageDeletion)
            return
        }
        applyDeletePlan(deletePlan)
        finalizePageDeletion(pageDeletion, removeVaultFile: true)
    }

    private func performFolderDelete() {
        guard let item = pendingDeleteFolder else { return }
        performFolderDelete(item)
    }

    private func performFolderDelete(_ item: SidebarFolderItem) {
        defer { pendingDeleteFolder = nil }
        guard let folder = fetchFolder(item.id) else { return }
        let deletePlan = NotesSidebarDeletePlanner.folderTreeDeletion(
            rootId: item.id,
            childFolderIdsById: cachedChildFolderIdsById,
            pageIdsByFolderId: cachedPageIdsByFolderId
        )
        let relativePath = folder.relativePath
        let pageDeletions = preparePageDeletions(in: folder)
        modelContext.delete(folder)
        guard saveSidebarChanges(rebuild: false, reason: "folder delete") else {
            modelContext.insert(folder)
            for pageDeletion in pageDeletions {
                restorePageDeletion(pageDeletion)
            }
            return
        }
        applyDeletePlan(deletePlan)
        for pageDeletion in pageDeletions {
            finalizePageDeletion(pageDeletion, removeVaultFile: false)
        }
        vaultSync.deleteDirectory(relativePath: relativePath)
    }

    private func clearSelectionIfNeeded(pageId: String) {
        guard currentSelectedPageId == pageId else { return }
        if let onClearSelection {
            onClearSelection()
        } else {
            notesUI.closePage()
        }
    }

    private func preparePageDeletions(in folder: SDFolder) -> [NotesSidebarPageDeletion] {
        let pages = pagesInFolderTree(folder)
        return pages.map { preparePageDeletion($0) }
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
        let restoreModel: () -> Void = {
            modelContext.delete(folder)
        }
        guard persistSidebarMutation(reason: "folder create", restoreState: restoreModel) else {
            return
        }
        // RCA13: rollback the SDFolder insertion if mkdir fails.
        if !vaultSync.createDirectory(relativePath: folder.relativePath) {
            restoreModel()
            _ = persistSidebarMutation(
                reason: "folder create rollback after FS failure",
                restoreState: {}
            )
        }
    }

    private func createCollection(title: String) {
        _ = ensureRootFolder(named: title, isCollection: true)
    }

    private func openNewEpdocDocument() {
        do {
            try NSDocumentController.shared.createUntitledEpdocDocument(in: vaultSync.vaultURL)
            refreshEpdocDocuments(in: vaultSync.vaultURL, force: true)
            scheduleDeferredRebuild(after: .milliseconds(250), source: "epdoc create")
        } catch {
            NSApplication.shared.presentError(error)
        }
    }

    private func getOrCreateTodayJournal() async {
        let today = Date.now
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: today)
        guard let dailyFolder = ensureRootFolder(named: SidebarSpecialFolders.dailyNotes) else {
            return
        }

        if let existing = allPages.first(where: { $0.isJournal && $0.journalDate == dateString }) {
            if existing.subfolder != dailyFolder.relativePath {
                let locationSnapshot = NotesSidebarPageLocationSnapshot(existing)
                existing.folder = dailyFolder
                existing.subfolder = dailyFolder.relativePath
                let restoreModel: () -> Void = {
                    locationSnapshot.restore(on: existing)
                }
                if persistSidebarMutation(reason: "journal move to daily folder", restoreState: restoreModel) {
                    // RCA13: rollback if the file move fails.
                    if !vaultSync.movePage(pageId: existing.id, toSubfolder: dailyFolder.relativePath) {
                        restoreModel()
                        _ = persistSidebarMutation(
                            reason: "journal move rollback after FS failure",
                            restoreState: {}
                        )
                    }
                }
            }
            openInEditor(existing.id)
            return
        }

        let title = today.formatted(date: .complete, time: .omitted)
        if let pageId = await vaultSync.createPage(
            title: title,
            emoji: "📓",
            subfolder: dailyFolder.relativePath,
            allowVaultSelectionPrompt: true
        ) {
            if let page = fetchPage(pageId) {
                let originalIsJournal = page.isJournal
                let originalJournalDate = page.journalDate
                let locationSnapshot = NotesSidebarPageLocationSnapshot(page)
                page.isJournal = true
                page.journalDate = dateString
                page.folder = dailyFolder
                page.subfolder = dailyFolder.relativePath
                _ = persistSidebarMutation(reason: "journal create metadata") {
                    page.isJournal = originalIsJournal
                    page.journalDate = originalJournalDate
                    locationSnapshot.restore(on: page)
                }
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
    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "archivebox")
                .font(.epSmall)
                .foregroundStyle(theme.resolved.accent.color.opacity(0.7))
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
    var renderChildren = true

    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDropTarget = false
    @State private var isRenaming = false
    @State private var renameValue = ""

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }
    private var isExpanded: Bool { notesUI.expandedFolderIds.contains(item.id) }

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
                        .animation(reduceMotion ? nil : Motion.sharp, value: isExpanded)
                        .frame(width: 10)

                    Image(
                        systemName: item.isCollection
                            ? (isExpanded ? "tray.full.fill" : "tray.full")
                            : (isExpanded ? "folder.fill" : "folder")
                    )
                    .font(.epCaption)
                    .foregroundStyle(
                        item.isCollection ? theme.resolved.accent.color : theme.resolved.accent.color.opacity(0.75)
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
                            .foregroundStyle(theme.resolved.foreground.color.opacity(0.9))
                            .lineLimit(1)
                    }

                    Spacer()

                    let count = item.descendantPageCount
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
                    NotesSidebarRowChrome(
                        theme: theme,
                        isDropTarget: isDropTarget,
                        isFavorite: item.isCollection
                    )
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            isDropTarget ? theme.resolved.accent.color.opacity(0.4) : Color.clear,
                            lineWidth: 1
                        )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            .notesSidebarHoverTick(style: .folder)
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
                withAnimation(reduceMotion ? nil : Motion.quick) { isDropTarget = targeted }
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
            if renderChildren && isExpanded {
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
    var renderChildren = true

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

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
                        .foregroundStyle(theme.resolved.accent.color.opacity(0.65))
                        .frame(width: 14)

                    Text("Daily Notes")
                        .font(.epBody).fontWeight(.medium)
                        .foregroundStyle(theme.resolved.foreground.color.opacity(0.9))

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
            .notesSidebarHoverTick(style: .folder)

            if renderChildren && isExpanded {
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
    var renderChildren = true

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

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
                        .foregroundStyle(theme.resolved.foreground.color.opacity(0.9))

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
            .notesSidebarHoverTick(style: .folder)

            if renderChildren && isExpanded {
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

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

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
                        .foregroundStyle(theme.resolved.foreground.color.opacity(0.8))
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

private struct DocumentsSection: View {
    let documents: [SidebarDocumentItem]
    let onAction: (SidebarAction) -> Void

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Documents")
                .font(AppHeadingRole.section.font)
                .foregroundStyle(theme.fontAccent)
                .textCase(.uppercase)
                .tracking(AppHeadingRole.section.tracking)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 2)

            ForEach(documents) { document in
                DocumentRow(item: document, onAction: onAction)
            }
        }
    }
}

private struct DocumentRow: View {
    let item: SidebarDocumentItem
    let onAction: (SidebarAction) -> Void

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    var body: some View {
        Button {
            onAction(.openDocument(item.url))
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.richtext")
                    .font(.epCaption)
                    .foregroundStyle(theme.mutedForeground.opacity(0.55))
                    .frame(width: 14)
                Text(item.title)
                    .font(.epBody)
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.82))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.leading, 14)
            .padding(.trailing, 10)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .notesSidebarHoverTick(style: .file)
        .contextMenu {
            Button("Open Document") {
                onAction(.openDocument(item.url))
            }
        }
        .help(item.url.lastPathComponent)
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

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }
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
                    } else if let lang = item.codeLanguage {
                        Image(systemName: Self.sfSymbolForLanguage(lang))
                            .font(.epCaption)
                            .foregroundStyle(
                                isActive ? theme.resolved.accent.color : Self.colorForLanguage(lang)
                            )
                            .frame(width: 14)
                    } else {
                        Image(
                            systemName: item.isJournal ? "calendar" : "doc.text"
                        )
                        .font(.epCaption)
                        .foregroundStyle(
                            isActive ? theme.resolved.accent.color : theme.mutedForeground.opacity(0.4)
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
                                    ? theme.resolved.foreground.color
                                    : (item.isFavorite
                                        ? favoriteHighlight
                                        : theme.resolved.foreground.color.opacity(0.8))
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
                            .foregroundStyle(theme.resolved.accent.color.opacity(0.8))
                    }

                    if isActive {
                        Circle()
                            .fill(theme.resolved.accent.color)
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.leading, CGFloat(indent) * 16 + 10)
                .padding(.trailing, 10)
                .padding(.vertical, 4)
                .background {
                    NotesSidebarRowChrome(
                        theme: theme,
                        isActive: isActive,
                        isFavorite: item.isFavorite
                    )
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
            .notesSidebarHoverTick()
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

    static func sfSymbolForLanguage(_ lang: String) -> String {
        switch lang {
        case "swift":       return "swift"
        case "python":      return "p.circle.fill"
        case "rust":        return "r.square.fill"
        case "javascript":  return "j.circle.fill"
        case "typescript":  return "t.circle.fill"
        case "html":        return "chevron.left.forwardslash.chevron.right"
        case "css":         return "paintbrush"
        case "go":          return "g.circle.fill"
        case "c":           return "c.circle.fill"
        case "cpp":         return "c.square.fill"
        case "java":        return "j.square.fill"
        case "ruby":        return "r.circle.fill"
        case "bash", "zsh": return "terminal"
        case "json":        return "curlybraces"
        case "yaml", "toml": return "list.bullet.indent"
        case "sql":         return "cylinder"
        case "markdown":    return "doc.text"
        default:            return "\(lang.prefix(1).lowercased()).circle.fill"
        }
    }

    static func colorForLanguage(_ lang: String) -> Color {
        switch lang {
        case "swift":       Color.orange
        case "python":      Color(red: 0.24, green: 0.52, blue: 0.80)
        case "rust":        Color(red: 0.73, green: 0.34, blue: 0.16)
        case "javascript":  Color.yellow
        case "typescript":  Color(red: 0.19, green: 0.47, blue: 0.80)
        case "html":        Color(red: 0.89, green: 0.35, blue: 0.21)
        case "css":         Color(red: 0.15, green: 0.44, blue: 0.74)
        case "go":          Color(red: 0.0, green: 0.67, blue: 0.84)
        case "ruby":        Color.red
        default:            Color.secondary
        }
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let item: SidebarPageItem
    let onAction: (SidebarAction) -> Void

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

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
                        .foregroundStyle(theme.resolved.accent.color.opacity(0.6))
                    }
                    Text(item.title.isEmpty ? "Untitled" : item.title)
                        .font(.epBody).fontWeight(.medium)
                        .foregroundStyle(theme.resolved.foreground.color)
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
        .notesSidebarHoverTick()
    }
}

// MARK: - Empty Tree State

private struct EmptyTreeState: View {
    let onAction: (SidebarAction) -> Void

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(theme.resolved.accent.color.opacity(0.4))
            Text("No notes yet")
                .font(.epCaption)
                .foregroundStyle(theme.mutedForeground)
            Button("Create a page") {
                onAction(.createNewPage)
            }
            .font(.epCaption).fontWeight(.medium)
            .foregroundStyle(theme.resolved.accent.color)
            Text("Press ⌘N to create your first note.")
                .font(.epSmall)
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

private struct DisconnectedCachedVaultNotice: View {
    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color)
            VStack(alignment: .leading, spacing: 2) {
                Text("Disconnected Local Cache")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.resolved.foreground.color)
                Text("Rows below are cached local note/graph data. Select a vault before creating, syncing, or trusting disk freshness.")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(theme.resolved.accent.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.resolved.accent.color.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Disconnected Local Cache")
        .accessibilityHint("Cached local note and graph rows are visible, but no vault is connected.")
    }
}

// MARK: - No-Vault Connected Banner (ISSUE-2026-05-12-001)

/// Surfaces the silent vault-not-connected state to fresh users.
///
/// Without a filesystem vault selected (`vaultSync.vaultURL`), Halo,
/// Shadow indexing, and vault-backed search all silently degrade.
/// Internal SwiftData notes still work, which is why the failure is
/// invisible — users edit notes happily, then are confused when Halo
/// reports "No active vault selected" in Diagnostics. The banner
/// closes that gap with a one-click action to open the folder picker.
private struct NoVaultConnectedBanner: View {
    let onSelectFolder: () -> Void

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "externaldrive.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text("No Vault Connected")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.resolved.foreground.color)
                    Text("Notes won't appear in search and Halo recall is off until you pick a folder on disk.")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            Button(action: onSelectFolder) {
                Text("Select Vault Folder")
                    .font(.system(size: 11, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.resolved.accent.color)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(theme.resolved.accent.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.resolved.accent.color.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No Vault Connected")
        .accessibilityHint("Tap Select Vault Folder to choose a folder for your Markdown notes; Halo and Shadow indexing will start once a folder is selected.")
    }
}

// MARK: - Editor Actions Bar
// ISOLATED View struct — uses @Query for dirty pages instead of reading
// vaultSync.dirtyPageCount. SwiftData only re-evaluates when the filtered
// result set changes, not on every VaultSyncService property mutation.

private struct EditorActionsBar: View {
    let activePageId: String?
    let onNewDocument: () -> Void
    let onNewPage: () -> Void
    let onNewFolder: () -> Void
    let onNewCollection: () -> Void
    let onTodayJournal: () -> Void

    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(UIState.self) private var ui
    @State private var showChangesPopover = false

    // PERF: Filtered @Query — SwiftData only notifies when this result set changes.
    // Replaces vaultSync.dirtyPageCount which fetched ALL pages every evaluation.
    @Query(filter: #Predicate<SDPage> { $0.needsVaultSync == true })
    private var dirtyPages: [SDPage]

    var body: some View {
        HStack(spacing: 2) {
            SidebarIconButton(
                icon: "square.and.pencil",
                tooltip: vaultSync.vaultURL == nil ? "Select Vault to Create Page" : "New Page"
            ) {
                onNewPage()
            }
            SidebarIconButton(
                icon: "doc.badge.plus",
                tooltip: vaultSync.vaultURL == nil ? "Select Vault to Create Document" : "New Document (.epdoc)"
            ) {
                onNewDocument()
            }
            SidebarIconButton(
                icon: "folder.badge.plus",
                tooltip: vaultSync.vaultURL == nil ? "Select Vault to Create Folder" : "New Folder"
            ) {
                onNewFolder()
            }
            if NotesSidebarMetrics.showsBottomCollectionButton {
                SidebarIconButton(icon: "tray.full", tooltip: "New Collection") {
                    onNewCollection()
                }
            }
            SidebarIconButton(
                icon: "calendar.badge.plus",
                tooltip: vaultSync.vaultURL == nil ? "Select Vault to Create Daily Note" : "New Daily Note"
            ) {
                onTodayJournal()
            }

            Spacer()

            Divider()
                .frame(height: 14)
                .padding(.horizontal, 2)

            SidebarIconButton(
                icon: "square.and.arrow.down",
                tooltip: vaultSync.vaultURL == nil ? "No Vault Connected" : "Save (⌘S)"
            ) {
                if let pageId = activePageId {
                    vaultSync.savePage(pageId: pageId)
                }
            }

            SidebarIconButton(
                icon: "arrow.down.doc",
                tooltip: vaultSync.vaultURL == nil ? "No Vault Connected" : "Save All (⇧⌘S)"
            ) {
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
                    .preferredColorScheme(ui.preferredColorScheme)
            }

            VaultConnectionButton()

            Divider()
                .frame(height: 14)
                .padding(.horizontal, 2)

            if NotesSidebarMetrics.showsBottomMiniChatButton {
                SidebarIconButton(icon: "bubble.left.and.bubble.right", tooltip: "Mini Chat") {
                    MiniChatWindowController.shared.openNewChat()
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
    @State private var isVaultDisconnectAuthorizationInFlight = false

    var body: some View {
        Menu {
            if let message = vaultSync.vaultActivityMessage {
                Text(message)
                Divider()
            }
            if let details = vaultSync.visibleVaultImportDetails {
                Text(details.inventorySummary)
                Text("Result: \(details.mutationSummary)")
                Text("Diagnostics: \(details.issueSummary)")
                Divider()
            }
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
                    Task { @MainActor in
                        await requestVaultDisconnectAuthorization(vaultURL: vaultURL)
                    }
                }
                .disabled(isVaultDisconnectAuthorizationInFlight)
            } else {
                Text("Disconnected Local Cache")
                Text("Rows in Notes/Graph may be cached local data until a vault is selected.")
                Divider()
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

    @MainActor
    private func requestVaultDisconnectAuthorization(vaultURL: URL) async {
        guard !isVaultDisconnectAuthorizationInFlight else { return }
        isVaultDisconnectAuthorizationInFlight = true
        defer { isVaultDisconnectAuthorizationInFlight = false }

        let target = NotesSidebarDeletionSovereignGate.Target.vaultDisconnect(name: vaultURL.lastPathComponent)
        let outcome = await AppBootstrap.shared?.sovereignGate.confirm(
            NotesSidebarDeletionSovereignGate.requirement(for: target),
            reason: NotesSidebarDeletionSovereignGate.reason(for: target)
        ) ?? .denied(.authenticationFailed)

        guard outcome == .allowed else { return }
        guard vaultSync.vaultURL?.standardizedFileURL == vaultURL.standardizedFileURL else { return }

        VaultConnectionActions.disconnect(notesUI: notesUI, vaultSync: vaultSync)
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

private struct NotesSidebarHoverTickModifier: ViewModifier {
    let style: NotesSidebarHoverHapticStyle
    @State private var tickState = NotesSidebarHoverTickState()

    func body(content: Content) -> some View {
        content.onHover { hovering in
            var nextState = tickState
            let shouldTick = nextState.update(hovering: hovering)
            tickState = nextState
            guard shouldTick else { return }
            style.perform()
        }
    }
}

private extension View {
    func notesSidebarHoverTick(style: NotesSidebarHoverHapticStyle = .file) -> some View {
        modifier(NotesSidebarHoverTickModifier(style: style))
    }
}
