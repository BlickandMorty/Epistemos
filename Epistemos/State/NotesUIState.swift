import Foundation
import Observation

// MARK: - Notes UI State
// Ephemeral notes UI state only — NO data arrays.
// Persistent note data lives in SDPage/SDFolder via SwiftData.

@MainActor @Observable
final class NotesUIState {
    /// Currently open page ID — points to SDPage.id
    var activePageId: String?

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

    // MARK: - Focus Mode

    /// When true, dims all paragraphs except the one containing the cursor.
    var isFocusMode = false

    // MARK: - Folder Expansion
    /// IDs of folders currently expanded in the sidebar.
    /// Empty set = all collapsed (default on every sidebar open).
    var expandedFolderIds: Set<String> = []

    /// Journal folder expanded state (separate from regular folders)
    var isJournalExpanded = false

    /// Ideas folder expanded state
    var isIdeasExpanded = false

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

    func closeTab(_ pageId: String) {
        if activePageId == pageId {
            setActivePageId(nil)
        }
    }

    func closePage() {
        setActivePageId(nil)
    }

    /// Full reset when switching vaults — clears all page references so
    /// stale editors from the old vault don't linger.
    func resetForVaultSwitch() {
        activePageId = nil
        searchQuery = ""
        debouncedSearchQuery = ""
        expandedFolderIds = []
        isJournalExpanded = false
        isIdeasExpanded = false
        isFocusMode = false
    }

    private func setActivePageId(_ pageId: String?) {
        if activePageId != pageId {
            activePageId = pageId
        }
    }
}
