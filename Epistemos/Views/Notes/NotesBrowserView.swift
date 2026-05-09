import SwiftData
import SwiftUI

// MARK: - Notes Browser View
// Sidebar popover — pure file browser, nothing else.
// Note editor windows (NoteWindowManager) are completely separate.
// This view MUST NOT read notesUI.activePageId — doing so registers
// the entire 5000+ page sidebar as an observer, causing a full
// re-evaluation cascade on every page switch.

struct NotesBrowserView: View {
    @Query(SDPage.activePagesDescriptor) private var allPages: [SDPage]
    @Query(sort: \SDFolder.sortOrder) private var allFolders: [SDFolder]

    var body: some View {
        SidebarShell(allPages: allPages, allFolders: allFolders)
    }
}
