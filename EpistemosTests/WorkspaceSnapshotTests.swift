import Foundation
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

@Suite("EventStore")
struct EventStoreTests {
    @Test("reads reflect queued snapshot and event writes")
    func readsReflectQueuedWrites() async throws {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("event-store-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("events.sqlite")
        let store = try #require(EventStore(databaseURL: dbURL))

        store.saveSnapshot(
            sessionId: "session-1",
            snapshotJSON: #"{"activePanel":"home"}"#,
            summary: "Saved",
            userNote: "Note"
        )
        store.appendEvent(sessionId: "session-1", kind: .chatMessageSent(chatId: "chat-1", snippet: "hello"))

        for _ in 0..<20 {
            if store.allSnapshots().count == 1, store.events(from: .distantPast, to: .now).count == 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        let snapshot = try #require(store.nearestSnapshot(before: .now))
        #expect(snapshot.summary == "Saved")
        #expect(snapshot.userNote == "Note")

        let events = store.events(from: .distantPast, to: .now)
        #expect(events.map(\.kind) == ["chat_message"])

        let snapshots = store.allSnapshots()
        #expect(snapshots.count == 1)

        let density = store.eventDensityByDay(days: 1)
        #expect(!density.isEmpty)
    }
}
