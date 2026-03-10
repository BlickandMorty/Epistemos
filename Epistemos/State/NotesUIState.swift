import Foundation
import Observation

// MARK: - Notes UI State
// Ephemeral notes UI state only — NO data arrays.
// Persistent note data lives in SDPage/SDFolder via SwiftData.

@MainActor @Observable
final class NotesUIState {
    struct WorkspaceTab: Identifiable, Equatable {
        let id: String
        var pageId: String?
        var isPinned: Bool

        init(id: String = UUID().uuidString, pageId: String? = nil, isPinned: Bool = false) {
            self.id = id
            self.pageId = pageId
            self.isPinned = isPinned
        }
    }

    /// Currently open page ID — points to SDPage.id
    var activePageId: String?

    /// Open tabs in the embedded home Notes workspace.
    /// A tab with `pageId == nil` is the Lucid-style landing tab.
    var workspaceTabs: [WorkspaceTab]

    /// Currently active tab in the embedded home Notes workspace.
    var workspaceActiveTabId: String

    /// Changes panel visibility (shows dirty/unsaved pages)
    var isChangesPanelVisible = false

    /// Sidebar search query (raw keystroke)
    var searchQuery = "" {
        didSet { scheduleDebouncedSearch() }
    }

    /// Debounced search query — lags behind searchQuery by 100ms.
    /// Index lookup is instant; debounce just prevents excessive Task spawning.
    var debouncedSearchQuery = ""

    private var searchDebounceTask: Task<Void, Never>?

    private func scheduleDebouncedSearch() {
        searchDebounceTask?.cancel()
        let query = searchQuery
        if query.isEmpty {
            debouncedSearchQuery = ""
            return
        }
        searchDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            debouncedSearchQuery = query
        }
    }

    // MARK: - TextKit 2 Editor

    /// When true, uses ProseEditorRepresentable2 (TextKit 2 stack).
    /// Persisted via UserDefaults for cross-session stickiness.
    var useTK2Editor: Bool = UserDefaults.standard.bool(forKey: "epistemos.editor.useTK2") {
        didSet { UserDefaults.standard.set(useTK2Editor, forKey: "epistemos.editor.useTK2") }
    }

    // MARK: - Focus Mode

    /// When true, dims all paragraphs except the one containing the cursor.
    var isFocusMode = false

    // MARK: - Session Word Target

    /// Word count at the start of the current writing session.
    var sessionStartWordCount = 0

    /// Target word count for the session (nil = no target).
    var sessionWordTarget: Int?

    // MARK: - Folder Expansion
    /// IDs of folders currently expanded in the sidebar.
    /// Empty set = all collapsed (default on every sidebar open).
    var expandedFolderIds: Set<String> = []

    /// Journal folder expanded state (separate from regular folders)
    var isJournalExpanded = false

    /// Ideas folder expanded state
    var isIdeasExpanded = false

    init() {
        let landingTab = WorkspaceTab()
        workspaceTabs = [landingTab]
        workspaceActiveTabId = landingTab.id
    }

    /// Currently selected page in the embedded home Notes workspace.
    /// Kept separate from `activePageId` so windowed note opens do not leak into Home.
    var workspacePageId: String? {
        workspaceTabs.first(where: { $0.id == workspaceActiveTabId })?.pageId
    }

    func collapseAllFolders() {
        expandedFolderIds.removeAll()
        isJournalExpanded = false
        isIdeasExpanded = false
    }

    func toggleFolder(_ id: String) {
        if expandedFolderIds.contains(id) {
            expandedFolderIds.remove(id)
        } else {
            expandedFolderIds.insert(id)
        }
    }

    // MARK: - Navigation

    func openPage(_ pageId: String) {
        setActivePageId(pageId)
    }

    func openWorkspacePage(_ pageId: String) {
        if let existingTab = workspaceTabs.first(where: { $0.pageId == pageId }) {
            if workspaceActiveTabId != existingTab.id {
                workspaceActiveTabId = existingTab.id
            }
        } else if let activeIndex = workspaceTabs.firstIndex(where: { $0.id == workspaceActiveTabId }),
            workspaceTabs[activeIndex].pageId == nil
        {
            if workspaceTabs[activeIndex].pageId != pageId {
                workspaceTabs[activeIndex].pageId = pageId
            }
        } else {
            let tab = WorkspaceTab(pageId: pageId)
            workspaceTabs.append(tab)
            workspaceActiveTabId = tab.id
        }
        setActivePageId(pageId)
    }

    func setWorkspaceCurrentPage(_ pageId: String) {
        if let activeIndex = workspaceTabs.firstIndex(where: { $0.id == workspaceActiveTabId }) {
            guard workspaceTabs[activeIndex].pageId != pageId || activePageId != pageId else {
                return
            }
            workspaceTabs[activeIndex].pageId = pageId
        } else {
            let tab = WorkspaceTab(pageId: pageId)
            workspaceTabs.append(tab)
            workspaceActiveTabId = tab.id
        }
        setActivePageId(pageId)
    }

    func showWorkspaceLanding() {
        let previousWorkspacePageId = workspacePageId

        if let landingTab = workspaceTabs.first(where: { $0.pageId == nil }) {
            if workspaceActiveTabId != landingTab.id {
                workspaceActiveTabId = landingTab.id
            }
            if activePageId == previousWorkspacePageId {
                setActivePageId(nil)
            }
            return
        }

        if let activeIndex = workspaceTabs.firstIndex(where: { $0.id == workspaceActiveTabId }),
            !workspaceTabs[activeIndex].isPinned
        {
            workspaceTabs[activeIndex].pageId = nil
            if activePageId == previousWorkspacePageId {
                setActivePageId(nil)
            }
            return
        }

        let landingTab = WorkspaceTab()
        workspaceTabs.append(landingTab)
        workspaceActiveTabId = landingTab.id
        if activePageId == previousWorkspacePageId {
            setActivePageId(nil)
        }
    }

    func addWorkspaceTab() {
        let tab = WorkspaceTab()
        workspaceTabs.append(tab)
        workspaceActiveTabId = tab.id
    }

    func activateWorkspaceTab(_ tabId: String) {
        guard let tab = workspaceTabs.first(where: { $0.id == tabId }) else { return }
        if workspaceActiveTabId != tabId {
            workspaceActiveTabId = tabId
        }
        if let pageId = tab.pageId {
            setActivePageId(pageId)
        }
    }

    func closeWorkspaceTab(_ tabId: String) {
        guard let index = workspaceTabs.firstIndex(where: { $0.id == tabId }) else { return }
        let closingTab = workspaceTabs[index]
        workspaceTabs.remove(at: index)

        if workspaceTabs.isEmpty {
            let landingTab = WorkspaceTab()
            workspaceTabs = [landingTab]
            workspaceActiveTabId = landingTab.id
        } else if workspaceActiveTabId == tabId {
            let fallbackIndex = min(index, workspaceTabs.count - 1)
            workspaceActiveTabId = workspaceTabs[fallbackIndex].id
        }

        if activePageId == closingTab.pageId {
            activePageId = workspacePageId
        }
    }

    func toggleWorkspaceTabPinned(_ tabId: String) {
        guard let index = workspaceTabs.firstIndex(where: { $0.id == tabId }) else { return }
        workspaceTabs[index].isPinned.toggle()
        normalizeWorkspaceTabOrder()
    }

    func closeTab(_ pageId: String) {
        if activePageId == pageId {
            setActivePageId(nil)
        }
    }

    func closePage() {
        setActivePageId(nil)
    }

    func closeWorkspacePage() {
        closeWorkspaceTab(workspaceActiveTabId)
    }

    /// Full reset when switching vaults — clears all page references so
    /// stale editors from the old vault don't linger.
    func resetForVaultSwitch() {
        activePageId = nil
        let landingTab = WorkspaceTab()
        workspaceTabs = [landingTab]
        workspaceActiveTabId = landingTab.id
        searchQuery = ""
        debouncedSearchQuery = ""
        expandedFolderIds = []
        isJournalExpanded = false
        isIdeasExpanded = false
        isFocusMode = false
        sessionWordTarget = nil
    }

    private func normalizeWorkspaceTabOrder() {
        let reordered = workspaceTabs.filter(\.isPinned) + workspaceTabs.filter { !$0.isPinned }
        if reordered != workspaceTabs {
            workspaceTabs = reordered
        }
    }

    private func setActivePageId(_ pageId: String?) {
        if activePageId != pageId {
            activePageId = pageId
        }
    }
}
