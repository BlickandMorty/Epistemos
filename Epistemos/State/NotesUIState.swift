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

    // MARK: - Outline Fold Mode (always expanded — auto-collapse removed)

    var outlineFoldMode: OutlineFoldMode = .expanded

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

    /// Outline fold mode is always expanded. Cycling is a no-op.
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
        outlineFoldMode = .expanded
    }

    private func setActivePageId(_ pageId: String?) {
        if activePageId != pageId {
            activePageId = pageId
        }
    }
}

// MARK: - Outline Fold Mode

enum OutlineFoldMode: String, Sendable, CaseIterable {
    /// Expanded: everything open, like a regular document.
    case expanded
    /// Fold level 1: only H1 sections visible, H2+ folded.
    case foldToH1
    /// Fold level 2: H1 and H2 sections visible, H3+ folded.
    case foldToH2
    /// Fold level 3: H1, H2, and H3 visible, H4+ folded.
    case foldToH3

    var label: String {
        switch self {
        case .expanded: return "Expanded"
        case .foldToH1: return "Fold to H1"
        case .foldToH2: return "Fold to H2"
        case .foldToH3: return "Fold to H3"
        }
    }

    var symbolName: String {
        switch self {
        case .expanded: return "list.dash"
        case .foldToH1: return "list.bullet.indent"
        case .foldToH2: return "list.bullet"
        case .foldToH3: return "list.number"
        }
    }

    /// Maximum heading level to keep visible. Headings deeper than this fold.
    var maxVisibleLevel: Int {
        switch self {
        case .expanded: return 6  // show all levels
        case .foldToH1: return 1
        case .foldToH2: return 2
        case .foldToH3: return 3
        }
    }

    /// Cycle to next mode.
    var next: OutlineFoldMode {
        let all = Self.allCases
        guard let idx = all.firstIndex(of: self) else { return .expanded }
        let nextIdx = (all.distance(from: all.startIndex, to: idx) + 1) % all.count
        return all[all.index(all.startIndex, offsetBy: nextIdx)]
    }
}
