import Testing
@testable import Epistemos
import Foundation

// MARK: - Graph Workspace Route Tests (Phase 7 Step 2a)
//
// Covers the Finder-style navigation history on `GraphState`:
//   - initial state
//   - openNote / openFolder / returnToCanvas push semantics
//   - goBack / goForward cursor semantics
//   - truncation of forward history on new push
//   - duplicate push is a no-op
//   - graphRouteDidChange notification fires on mutation
//
// The 3D FFI engine is never created in these tests — we exercise pure Swift
// route bookkeeping on a fresh `GraphState` instance.

@Suite("Graph Workspace Route — Initial State")
@MainActor
struct GraphWorkspaceRouteInitialStateTests {

    @Test("Fresh state starts at .canvas")
    func freshStateStartsAtCanvas() {
        let gs = GraphState()
        #expect(gs.currentRoute == .canvas)
        #expect(gs.routeHistory == [.canvas])
        #expect(gs.routeCursor == 0)
        #expect(!gs.canGoBack)
        #expect(!gs.canGoForward)
    }

    @Test("isCanvas helper on GraphWorkspaceRoute")
    func isCanvasHelper() {
        #expect(GraphWorkspaceRoute.canvas.isCanvas)
        #expect(!GraphWorkspaceRoute.note(id: "n1").isCanvas)
        #expect(!GraphWorkspaceRoute.folder(id: "f1").isCanvas)
    }
}

@Suite("Graph Workspace Route — Push / Pop")
@MainActor
struct GraphWorkspaceRoutePushTests {

    @Test("openNote pushes a note route and enables back")
    func openNotePushes() {
        let gs = GraphState()
        gs.openNote("note-1")
        #expect(gs.currentRoute == .note(id: "note-1"))
        #expect(gs.canGoBack)
        #expect(!gs.canGoForward)
        #expect(gs.routeHistory.count == 2)
    }

    @Test("openFolder pushes a folder route")
    func openFolderPushes() {
        let gs = GraphState()
        gs.openFolder("folder-1")
        #expect(gs.currentRoute == .folder(id: "folder-1"))
        #expect(gs.canGoBack)
    }

    @Test("returnToCanvas from a note pushes canvas, preserving back history")
    func returnToCanvasPushesCanvas() {
        let gs = GraphState()
        gs.openNote("note-1")
        gs.returnToCanvas()
        #expect(gs.currentRoute == .canvas)
        #expect(gs.canGoBack) // can back to note-1
        #expect(gs.routeHistory == [.canvas, .note(id: "note-1"), .canvas])
    }

    @Test("Pushing the same route twice is a no-op")
    func duplicatePushIsNoop() {
        let gs = GraphState()
        gs.openNote("note-1")
        let historyAfterFirst = gs.routeHistory
        gs.openNote("note-1")
        #expect(gs.routeHistory == historyAfterFirst)
        #expect(gs.routeCursor == 1)
    }

    @Test("Pushing different note ids does not dedupe")
    func differentNotesBothPush() {
        let gs = GraphState()
        gs.openNote("note-1")
        gs.openNote("note-2")
        #expect(gs.currentRoute == .note(id: "note-2"))
        #expect(gs.routeHistory.count == 3)
    }
}

@Suite("Graph Workspace Route — Back / Forward")
@MainActor
struct GraphWorkspaceRouteBackForwardTests {

    @Test("goBack restores the prior route and enables forward")
    func goBackRestoresPrior() {
        let gs = GraphState()
        gs.openNote("note-1")
        gs.openFolder("folder-1")
        gs.goBack()
        #expect(gs.currentRoute == .note(id: "note-1"))
        #expect(gs.canGoBack)
        #expect(gs.canGoForward)
    }

    @Test("goBack from cursor 0 is a no-op")
    func goBackAtStartIsNoop() {
        let gs = GraphState()
        gs.goBack()
        #expect(gs.currentRoute == .canvas)
        #expect(gs.routeCursor == 0)
    }

    @Test("goForward after goBack restores the advanced route")
    func goForwardAfterGoBack() {
        let gs = GraphState()
        gs.openNote("note-1")
        gs.openFolder("folder-1")
        gs.goBack()
        gs.goForward()
        #expect(gs.currentRoute == .folder(id: "folder-1"))
        #expect(!gs.canGoForward)
        #expect(gs.canGoBack)
    }

    @Test("goForward at tail is a no-op")
    func goForwardAtTailIsNoop() {
        let gs = GraphState()
        gs.openNote("note-1")
        gs.goForward()
        #expect(gs.currentRoute == .note(id: "note-1"))
    }

    @Test("Pushing a new route truncates forward history")
    func pushTruncatesForwardHistory() {
        let gs = GraphState()
        gs.openNote("note-1")
        gs.openFolder("folder-1")
        gs.goBack() // cursor at note-1
        #expect(gs.canGoForward)

        gs.openNote("note-2") // should drop folder-1
        #expect(gs.currentRoute == .note(id: "note-2"))
        #expect(!gs.canGoForward)
        #expect(gs.routeHistory == [
            .canvas,
            .note(id: "note-1"),
            .note(id: "note-2")
        ])
    }

    @Test("Full back walk reaches canvas")
    func fullBackWalkReachesCanvas() {
        let gs = GraphState()
        gs.openNote("note-1")
        gs.openNote("note-2")
        gs.openFolder("folder-1")
        gs.goBack()
        gs.goBack()
        gs.goBack()
        #expect(gs.currentRoute == .canvas)
        #expect(!gs.canGoBack)
        #expect(gs.canGoForward)
    }
}

@Suite("Graph Workspace — Folder Page Composition")
@MainActor
struct GraphWorkspaceFolderPageCompositionTests {
    // Source-mirror assertions for the folder surface. Runtime tests would
    // require constructing a ModelContainer with a seeded SDFolder tree; the
    // assertions below catch structural regressions.

    @Test("GraphFolderPage is a list surface reusing SDFolder / SDPage with nested-folder push")
    func graphFolderPageStructure() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Views/Graph/GraphFolderPage.swift"
        )

        #expect(source.contains("struct GraphFolderPage: View"))
        #expect(source.contains("@Query private var folders: [SDFolder]"))
        #expect(source.contains("#Predicate<SDFolder> { $0.id == folderId }"))
        // Subfolder click pushes a new folder route onto the back stack,
        // so nested folder navigation reuses the Finder-style history.
        #expect(source.contains("graphState.openFolder(child.id)"))
        // Clicking a note jumps to the note page via the same back stack.
        #expect(source.contains("graphState.openNote(page.id)"))
        // Archived pages are filtered out of the listing.
        #expect(source.contains("!$0.isArchived"))
    }

    @Test("GraphWorkspaceContainer routes .folder to GraphFolderPage, not a placeholder")
    func containerRoutesFolderCaseToGraphFolderPage() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Views/Graph/GraphWorkspaceContainer.swift"
        )

        #expect(source.contains("case .folder(let id):"))
        #expect(source.contains("GraphFolderPage(folderId: id)"))
        #expect(!source.contains("Graph Folder Page Placeholder"))
    }
}

@Suite("Graph Workspace — Note Page Composition")
@MainActor
struct GraphWorkspaceNotePageCompositionTests {
    // Source-mirror assertions verify that the graph note page reuses the
    // canonical TextKit 2 editor stack instead of forking it. Runtime tests
    // for graph-page editing would require constructing a full ModelContainer
    // with a real SDPage; these assertions catch regressions where a
    // placeholder replaces ProseEditorView or where a second editor store
    // is introduced.

    @Test("GraphNotePage embeds the real ProseEditorView with per-page NoteChatState")
    func graphNotePageEmbedsRealProseEditor() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Views/Graph/GraphNotePage.swift"
        )

        #expect(source.contains("struct GraphNotePage: View"))
        #expect(source.contains("@Query private var pages: [SDPage]"))
        #expect(source.contains("#Predicate<SDPage> { $0.id == sourceId }"))
        #expect(source.contains("@State private var noteChatState: NoteChatState"))
        #expect(source.contains("NoteChatState(pageId: sourceId)"))
        #expect(source.contains("ProseEditorView(page: page)"))
        #expect(source.contains(".environment(noteChatState)"))
    }

    @Test("GraphWorkspaceContainer routes .note to GraphNotePage, not a placeholder")
    func containerRoutesNoteCaseToGraphNotePage() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Views/Graph/GraphWorkspaceContainer.swift"
        )

        #expect(source.contains("case .note(let id):"))
        #expect(source.contains("GraphNotePage(sourceId: id)"))
        // Identity modifier forces a fresh init when the id changes so each
        // note gets its own NoteChatState.
        #expect(source.contains(".id(id)"))
        // Placeholder text from Step 2 must be gone.
        #expect(!source.contains("Graph Note Page Placeholder"))
    }
}

@Suite("Graph Workspace Route — openNode dispatch")
@MainActor
struct GraphWorkspaceRouteOpenNodeDispatchTests {
    // `openNode(id:)` looks up the graph node, reads its type, and routes
    // to `openNote(sourceId)` or `openFolder(sourceId)`. When the node has
    // a non-empty `sourceId` (which GraphBuilder always sets for real
    // SDPage/SDFolder-backed nodes), the route *must* carry the sourceId,
    // not the graph node id, so the downstream page can @Query the right
    // SwiftData entity.

    private func makeNode(
        id: String,
        type: GraphNodeType,
        sourceId: String?
    ) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id,
            type: type,
            label: "",
            sourceId: sourceId,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: .now,
            position: .zero,
            velocity: .zero
        )
    }

    @Test("openNode on a folder node dispatches openFolder with sourceId, not graph node id")
    func folderBranchUsesSourceId() {
        let gs = GraphState()
        gs.store.addNode(makeNode(
            id: "graph-node-uuid-1",
            type: .folder,
            sourceId: "sdfolder-id-1"
        ))

        gs.openNode("graph-node-uuid-1")

        #expect(gs.currentRoute == .folder(id: "sdfolder-id-1"))
    }

    @Test("openNode on a note node dispatches openNote with sourceId")
    func noteBranchUsesSourceId() {
        let gs = GraphState()
        gs.store.addNode(makeNode(
            id: "graph-node-uuid-2",
            type: .note,
            sourceId: "sdpage-id-2"
        ))

        gs.openNode("graph-node-uuid-2")

        #expect(gs.currentRoute == .note(id: "sdpage-id-2"))
    }

    @Test("openNode falls back to graph node id when sourceId is missing")
    func missingSourceIdFallsBackToNodeId() {
        let gs = GraphState()
        gs.store.addNode(makeNode(
            id: "graph-node-uuid-3",
            type: .note,
            sourceId: nil
        ))

        gs.openNode("graph-node-uuid-3")

        #expect(gs.currentRoute == .note(id: "graph-node-uuid-3"))
    }

    @Test("openNode on an empty sourceId also falls back to graph node id")
    func emptySourceIdFallsBackToNodeId() {
        let gs = GraphState()
        gs.store.addNode(makeNode(
            id: "graph-node-uuid-4",
            type: .folder,
            sourceId: ""
        ))

        gs.openNode("graph-node-uuid-4")

        #expect(gs.currentRoute == .folder(id: "graph-node-uuid-4"))
    }

    @Test("openNode on a missing node is a no-op")
    func missingNodeIsNoop() {
        let gs = GraphState()
        gs.openNode("does-not-exist")
        #expect(gs.currentRoute == .canvas)
    }

    @Test("openNode on an idea node selects instead of routing to note")
    func ideaNodeDoesNotRouteToNote() {
        let gs = GraphState()
        gs.store.addNode(makeNode(
            id: "graph-idea-1",
            type: .idea,
            sourceId: nil
        ))

        gs.openNode("graph-idea-1")

        #expect(gs.currentRoute == .canvas)
        #expect(gs.selectedNodeId == "graph-idea-1")
    }

    @Test("openNode on a chat node selects instead of routing to note")
    func chatNodeDoesNotRouteToNote() {
        let gs = GraphState()
        gs.store.addNode(makeNode(
            id: "graph-chat-1",
            type: .chat,
            sourceId: nil
        ))

        gs.openNode("graph-chat-1")

        #expect(gs.currentRoute == .canvas)
        #expect(gs.selectedNodeId == "graph-chat-1")
    }
}

@Suite("Graph Workspace Route — Change Notification")
@MainActor
struct GraphWorkspaceRouteNotificationTests {
    actor NotificationProbe {
        private var didMatch = false
        private var count = 0

        func recordMatch(_ matched: Bool) {
            didMatch = matched
        }

        func increment() {
            count += 1
        }

        func matched() -> Bool {
            didMatch
        }

        func value() -> Int {
            count
        }
    }

    @Test("Notification posts on push")
    func notificationOnPush() async {
        let gs = GraphState()
        let probe = NotificationProbe()
        let token = NotificationCenter.default.addObserver(
            forName: .graphRouteDidChange,
            object: gs,
            queue: .main
        ) { note in
            let matched = note.object as AnyObject? === gs
            Task {
                await probe.recordMatch(matched)
            }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        gs.openNote("note-1")
        // Allow the main queue to drain the delivery.
        await Task.yield()
        #expect(await probe.matched())
    }

    @Test("Notification posts on goBack")
    func notificationOnGoBack() async {
        let gs = GraphState()
        gs.openNote("note-1")

        let probe = NotificationProbe()
        let token = NotificationCenter.default.addObserver(
            forName: .graphRouteDidChange,
            object: gs,
            queue: .main
        ) { _ in
            Task {
                await probe.increment()
            }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        gs.goBack()
        await Task.yield()
        #expect(await probe.value() == 1)
    }

    @Test("No notification when duplicate route is pushed")
    func noNotificationOnDuplicatePush() async {
        let gs = GraphState()
        gs.openNote("note-1")

        let probe = NotificationProbe()
        let token = NotificationCenter.default.addObserver(
            forName: .graphRouteDidChange,
            object: gs,
            queue: .main
        ) { _ in
            Task {
                await probe.increment()
            }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        gs.openNote("note-1") // same route
        await Task.yield()
        #expect(await probe.value() == 0)
    }
}

@Suite("Graph Workspace Route — Serialization Key")
struct GraphWorkspaceRouteSerializationTests {

    @Test("canvas serializes to 'canvas'")
    func canvasSerialization() {
        #expect(GraphWorkspaceRoute.canvas.serializationKey == "canvas")
    }

    @Test("note route serializes to 'note:id'")
    func noteSerialization() {
        #expect(GraphWorkspaceRoute.note(id: "abc").serializationKey == "note:abc")
    }

    @Test("folder route serializes to 'folder:id'")
    func folderSerialization() {
        #expect(GraphWorkspaceRoute.folder(id: "f1").serializationKey == "folder:f1")
    }
}
