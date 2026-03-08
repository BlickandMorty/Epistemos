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
        activePageId = pageId
    }

    func closeTab(_ pageId: String) {
        if activePageId == pageId {
            activePageId = nil
        }
    }

    func closePage() {
        activePageId = nil
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
        sessionWordTarget = nil
    }
}
