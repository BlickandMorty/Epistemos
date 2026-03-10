import Testing
@testable import Epistemos

@Suite("NotesUIState")
struct NotesUIStateTests {

    @MainActor
    @Test("workspace selection stays independent from windowed note selection")
    func workspaceSelectionIsIndependent() {
        let state = NotesUIState()

        state.openWorkspacePage("home-note")
        #expect(state.workspacePageId == "home-note")
        #expect(state.activePageId == "home-note")

        state.openPage("window-note")
        #expect(state.workspacePageId == "home-note")
        #expect(state.activePageId == "window-note")
    }

    @MainActor
    @Test("selecting another workspace note opens a second embedded tab")
    func selectingAnotherWorkspaceNoteOpensSecondTab() {
        let state = NotesUIState()

        state.openWorkspacePage("first-note")
        state.openWorkspacePage("second-note")

        #expect(state.workspaceTabs.count == 2)
        #expect(state.workspaceTabs.map(\.pageId) == ["first-note", "second-note"])
        #expect(state.workspacePageId == "second-note")
    }

    @MainActor
    @Test("reopening an existing workspace note reuses its tab")
    func reopeningExistingWorkspaceNoteReusesTab() {
        let state = NotesUIState()

        state.openWorkspacePage("first-note")
        let firstTabId = state.workspaceActiveTabId
        state.openWorkspacePage("second-note")

        state.openWorkspacePage("first-note")

        #expect(state.workspaceTabs.count == 2)
        #expect(state.workspaceActiveTabId == firstTabId)
        #expect(state.workspacePageId == "first-note")
    }

    @MainActor
    @Test("closing workspace selection does not clear an unrelated active window note")
    func closingWorkspaceKeepsSeparateActiveWindowNote() {
        let state = NotesUIState()

        state.openWorkspacePage("home-note")
        state.openPage("window-note")
        state.closeWorkspacePage()

        #expect(state.workspacePageId == nil)
        #expect(state.activePageId == "window-note")
    }

    @MainActor
    @Test("showing workspace landing keeps the active window note")
    func showingWorkspaceLandingKeepsActiveWindowNote() {
        let state = NotesUIState()

        state.openWorkspacePage("home-note")
        state.openPage("window-note")
        state.showWorkspaceLanding()

        #expect(state.workspacePageId == nil)
        #expect(state.activePageId == "window-note")
    }

    @MainActor
    @Test("showing workspace landing reuses the existing landing tab")
    func showingWorkspaceLandingReusesExistingLandingTab() {
        let state = NotesUIState()

        let landingTabId = state.workspaceActiveTabId
        state.openWorkspacePage("home-note")
        state.showWorkspaceLanding()

        #expect(state.workspaceTabs.count == 1)
        #expect(state.workspaceActiveTabId == landingTabId)
        #expect(state.workspacePageId == nil)
    }

    @MainActor
    @Test("adding a workspace tab creates a new landing tab")
    func addingWorkspaceTabCreatesLandingTab() {
        let state = NotesUIState()

        state.openWorkspacePage("home-note")
        state.addWorkspaceTab()

        #expect(state.workspaceTabs.count == 2)
        #expect(state.workspacePageId == nil)
        #expect(state.workspaceTabs.last?.pageId == nil)
    }

    @MainActor
    @Test("pinning a workspace tab marks it pinned and moves it ahead of unpinned tabs")
    func pinningWorkspaceTabPromotesIt() {
        let state = NotesUIState()

        state.openWorkspacePage("first-note")
        state.openWorkspacePage("second-note")
        let secondTabId = state.workspaceActiveTabId

        state.toggleWorkspaceTabPinned(secondTabId)

        #expect(state.workspaceTabs.first?.id == secondTabId)
        #expect(state.workspaceTabs.first?.isPinned == true)
    }

    @MainActor
    @Test("closing the active workspace tab activates a neighboring tab")
    func closingActiveWorkspaceTabActivatesNeighbor() {
        let state = NotesUIState()

        state.openWorkspacePage("first-note")
        state.openWorkspacePage("second-note")
        let firstTabId = state.workspaceTabs.first?.id
        let secondTabId = state.workspaceActiveTabId

        state.closeWorkspaceTab(secondTabId)

        #expect(state.workspaceTabs.count == 1)
        #expect(state.workspaceActiveTabId == firstTabId)
        #expect(state.workspacePageId == "first-note")
    }

    @MainActor
    @Test("pinned workspace tabs ignore normal close requests")
    func pinnedWorkspaceTabsIgnoreNormalCloseRequests() {
        let state = NotesUIState()

        state.openWorkspacePage("first-note")
        let pinnedTabId = state.workspaceActiveTabId
        state.toggleWorkspaceTabPinned(pinnedTabId)

        state.closeWorkspaceTab(pinnedTabId)

        #expect(state.workspaceTabs.count == 1)
        #expect(state.workspaceActiveTabId == pinnedTabId)
        #expect(state.workspacePageId == "first-note")
    }

    @MainActor
    @Test("pinned workspace tabs can still be force-closed")
    func pinnedWorkspaceTabsCanBeForceClosed() {
        let state = NotesUIState()

        state.openWorkspacePage("first-note")
        let pinnedTabId = state.workspaceActiveTabId
        state.toggleWorkspaceTabPinned(pinnedTabId)

        state.closeWorkspaceTab(pinnedTabId, allowPinned: true)

        #expect(state.workspaceTabs.count == 1)
        #expect(state.workspacePageId == nil)
    }

    @MainActor
    @Test("updating the embedded current page keeps workspace selection in sync")
    func updatingEmbeddedCurrentPageSyncsWorkspaceSelection() {
        let state = NotesUIState()

        state.openWorkspacePage("root-note")
        state.setWorkspaceCurrentPage("linked-note")

        #expect(state.workspacePageId == "linked-note")
        #expect(state.activePageId == "linked-note")
    }
}
