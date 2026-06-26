import Foundation
import Testing
@testable import Epistemos

@MainActor
@Suite("Work session store — active selection + registry delegation")
struct WorkSessionStoreTests {
    @Test("init focuses the first main session if present")
    func initFocus() {
        let store = WorkSessionStore(WorkSessionRegistry([WorkSession.main(id: "m1", workspaceID: "ws")]))
        #expect(store.activeSessionID == "m1")
        #expect(store.activeSession?.id == "m1")
    }

    @Test("upsert focuses the first session; a second main does not steal focus")
    func upsertFocus() {
        let store = WorkSessionStore()
        #expect(store.activeSessionID == nil)
        store.upsert(WorkSession.main(id: "m1", workspaceID: "ws"))
        #expect(store.activeSessionID == "m1")
        store.upsert(WorkSession.main(id: "m2", workspaceID: "ws"))
        #expect(store.activeSessionID == "m1")
    }

    @Test("focus only accepts known ids (no ghost focus)")
    func focusGuard() {
        let store = WorkSessionStore(WorkSessionRegistry([WorkSession.main(id: "m1", workspaceID: "ws")]))
        store.focus(id: "nope")
        #expect(store.activeSessionID == "m1")
        let main = store.registry.session(id: "m1")!
        store.upsert(WorkSession.mini(id: "c1", parent: main))
        store.focus(id: "c1")
        #expect(store.activeSessionID == "c1")
    }

    @Test("removing the active session falls back to a main tab, then nil")
    func removeFallback() {
        let main = WorkSession.main(id: "m1", workspaceID: "ws")
        let store = WorkSessionStore(WorkSessionRegistry([main]))
        store.upsert(WorkSession.mini(id: "c1", parent: main))
        store.focus(id: "c1")
        #expect(store.activeSessionID == "c1")
        store.remove(id: "c1")
        #expect(store.activeSessionID == "m1")
        store.remove(id: "m1")
        #expect(store.activeSessionID == nil)
    }

    @Test("promoting a mini to a tab focuses the promoted session")
    func promoteFocusesPromotedMini() {
        let main = WorkSession.main(id: "m1", workspaceID: "ws")
        let store = WorkSessionStore(WorkSessionRegistry([main]))
        store.upsert(WorkSession.mini(id: "c1", parent: main))
        #expect(store.activeSessionID == "m1")

        store.promote(id: "c1")

        #expect(store.registry.session(id: "c1")?.kind == .main)
        #expect(store.activeSessionID == "c1")
    }

    @Test("promote ignores existing main or unknown ids without stealing focus")
    func promoteNoopDoesNotStealFocus() {
        let main = WorkSession.main(id: "m1", workspaceID: "ws")
        let store = WorkSessionStore(WorkSessionRegistry([main]))
        store.promote(id: "m1")
        store.promote(id: "ghost")
        #expect(store.activeSessionID == "m1")
    }
}
