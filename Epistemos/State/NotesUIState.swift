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

    // MARK: - Outline Fold Mode

    /// Controls how headers are collapsed when opening a note.
    /// - `auto`: Collapse all headers if the document has more than 2 headings.
    /// - `collapsed`: Always collapse all headers.
    /// - `expanded`: Never collapse headers (all expanded).
    var outlineFoldMode: OutlineFoldMode = .auto

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

    /// Cycle through outline fold modes: auto → collapsed → expanded → auto
    func cycleOutlineFoldMode() {
        outlineFoldMode = outlineFoldMode.next
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
        outlineFoldMode = .auto
    }

    private func setActivePageId(_ pageId: String?) {
        if activePageId != pageId {
            activePageId = pageId
        }
    }
}

// MARK: - Outline Fold Mode

enum OutlineFoldMode: String, Sendable {
    case auto
    case collapsed
    case expanded

    var next: OutlineFoldMode {
        switch self {
        case .auto: .collapsed
        case .collapsed: .expanded
        case .expanded: .auto
        }
    }

    var label: String {
        switch self {
        case .auto: "Auto"
        case .collapsed: "Collapsed"
        case .expanded: "Expanded"
        }
    }

    var symbolName: String {
        switch self {
        case .auto: "list.bullet.indent"
        case .collapsed: "list.bullet"
        case .expanded: "list.dash"
        }
    }

    /// Returns true if headers should be folded for a document with the given heading count.
    func shouldCollapse(headingCount: Int) -> Bool {
        switch self {
        case .auto: headingCount > 2
        case .collapsed: true
        case .expanded: false
        }
    }
}
