import Testing

@testable import Epistemos

@Suite("WorkspaceSnapshot")
struct WorkspaceSnapshotTests {

    @Test("Round-trip encode/decode preserves all fields")
    func roundTrip() throws {
        let snapshot = WorkspaceSnapshot(
            activePanel: "notes",
            activeChatId: "chat-123",
            showChatSidebar: true,
            showLanding: false,
            openNoteTabs: [
                NoteTabSnapshot(
                    rootPageId: "page-1",
                    currentPageId: "page-3",
                    breadcrumbs: [
                        BreadcrumbSnapshot(pageId: "page-1", title: "Root Note"),
                        BreadcrumbSnapshot(pageId: "page-2", title: "Linked Note"),
                        BreadcrumbSnapshot(pageId: "page-3", title: "Deep Link"),
                    ],
                    forwardStack: [
                        BreadcrumbSnapshot(pageId: "page-4", title: "Future Note")
                    ],
                    cursorPosition: 42,
                    scrollFraction: 0.75
                ),
                NoteTabSnapshot(
                    rootPageId: "page-5",
                    currentPageId: "page-5",
                    breadcrumbs: [
                        BreadcrumbSnapshot(pageId: "page-5", title: "Simple Note")
                    ],
                    forwardStack: [],
                    cursorPosition: nil,
                    scrollFraction: nil
                ),
            ],
            activeNoteTabPageId: "page-1",
            openMiniChatIds: ["mini-1", "mini-2"],
            notesBrowserVisible: true,
            settingsVisible: false,
            graphOverlay: GraphOverlaySnapshot(
                visibility: .minimized,
                selectedNodeId: "node-xyz"
            ),
            expandedFolderIds: ["folder-a", "folder-b"],
            isJournalExpanded: true,
            isIdeasExpanded: false
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)

        #expect(decoded.activePanel == "notes")
        #expect(decoded.activeChatId == "chat-123")
        #expect(decoded.showChatSidebar == true)
        #expect(decoded.showLanding == false)
        #expect(decoded.openNoteTabs.count == 2)
        #expect(decoded.openNoteTabs[0].rootPageId == "page-1")
        #expect(decoded.openNoteTabs[0].currentPageId == "page-3")
        #expect(decoded.openNoteTabs[0].breadcrumbs.count == 3)
        #expect(decoded.openNoteTabs[0].forwardStack.count == 1)
        #expect(decoded.openNoteTabs[0].cursorPosition == 42)
        #expect(decoded.openNoteTabs[0].scrollFraction == 0.75)
        #expect(decoded.openNoteTabs[1].cursorPosition == nil)
        #expect(decoded.openNoteTabs[1].scrollFraction == nil)
        #expect(decoded.activeNoteTabPageId == "page-1")
        #expect(decoded.openMiniChatIds == ["mini-1", "mini-2"])
        #expect(decoded.notesBrowserVisible == true)
        #expect(decoded.settingsVisible == false)
        #expect(decoded.graphOverlay.visibility == .minimized)
        #expect(decoded.graphOverlay.selectedNodeId == "node-xyz")
        #expect(Set(decoded.expandedFolderIds) == Set(["folder-a", "folder-b"]))
        #expect(decoded.isJournalExpanded == true)
        #expect(decoded.isIdeasExpanded == false)
    }

    @Test("Empty workspace round-trips")
    func emptyRoundTrip() throws {
        let snapshot = WorkspaceSnapshot(
            activePanel: "home",
            activeChatId: nil,
            showChatSidebar: false,
            showLanding: true,
            openNoteTabs: [],
            activeNoteTabPageId: nil,
            openMiniChatIds: [],
            notesBrowserVisible: false,
            settingsVisible: false,
            graphOverlay: GraphOverlaySnapshot(visibility: .hidden),
            expandedFolderIds: [],
            isJournalExpanded: false,
            isIdeasExpanded: false
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)

        #expect(decoded.activePanel == "home")
        #expect(decoded.activeChatId == nil)
        #expect(decoded.openNoteTabs.isEmpty)
        #expect(decoded.openMiniChatIds.isEmpty)
        #expect(decoded.graphOverlay.visibility == .hidden)
        #expect(decoded.graphOverlay.selectedNodeId == nil)
    }

    @Test("GraphOverlaySnapshot visibility values")
    func graphVisibilityValues() throws {
        for visibility in [GraphOverlaySnapshot.Visibility.hidden, .full, .minimized] {
            let snapshot = GraphOverlaySnapshot(visibility: visibility)
            let data = try JSONEncoder().encode(snapshot)
            let decoded = try JSONDecoder().decode(GraphOverlaySnapshot.self, from: data)
            #expect(decoded.visibility == visibility)
        }
    }
}
