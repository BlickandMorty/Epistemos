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

@Suite("Graph Workspace Route — Change Notification")
@MainActor
struct GraphWorkspaceRouteNotificationTests {

    @Test("Notification posts on push")
    func notificationOnPush() async {
        let gs = GraphState()
        var receivedObject: AnyObject?
        let token = NotificationCenter.default.addObserver(
            forName: .graphRouteDidChange,
            object: gs,
            queue: .main
        ) { note in
            receivedObject = note.object as AnyObject?
        }
        defer { NotificationCenter.default.removeObserver(token) }

        gs.openNote("note-1")
        // Allow the main queue to drain the delivery.
        await Task.yield()
        #expect(receivedObject === gs)
    }

    @Test("Notification posts on goBack")
    func notificationOnGoBack() async {
        let gs = GraphState()
        gs.openNote("note-1")

        var count = 0
        let token = NotificationCenter.default.addObserver(
            forName: .graphRouteDidChange,
            object: gs,
            queue: .main
        ) { _ in
            count += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        gs.goBack()
        await Task.yield()
        #expect(count == 1)
    }

    @Test("No notification when duplicate route is pushed")
    func noNotificationOnDuplicatePush() async {
        let gs = GraphState()
        gs.openNote("note-1")

        var count = 0
        let token = NotificationCenter.default.addObserver(
            forName: .graphRouteDidChange,
            object: gs,
            queue: .main
        ) { _ in
            count += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        gs.openNote("note-1") // same route
        await Task.yield()
        #expect(count == 0)
    }
}
