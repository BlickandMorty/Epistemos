import Foundation
import Testing
@testable import Epistemos

@Suite("Work session registry — dedup / children / cascade / promote / detach")
struct WorkSessionRegistryTests {
    private func seeded() -> (WorkSessionRegistry, WorkSession) {
        var reg = WorkSessionRegistry()
        let main = WorkSession.main(id: "m1", workspaceID: "ws_a", title: "Root")
        reg.upsert(main)
        reg.upsert(WorkSession.mini(id: "c1", parent: main, title: "Mini A"))
        reg.upsert(WorkSession.mini(id: "c2", parent: main, title: "Mini B"))
        return (reg, main)
    }

    @Test("upsert dedups by id and ignores invalid sessions")
    func upsertDedup() {
        var (reg, main) = seeded()
        #expect(reg.sessions.count == 3)
        // re-upsert c1 with a new title → replaces, not appends
        reg.upsert(WorkSession.mini(id: "c1", parent: main, title: "Renamed"))
        #expect(reg.sessions.count == 3)
        #expect(reg.session(id: "c1")?.title == "Renamed")
        // invalid (parentless mini) is ignored
        reg.upsert(WorkSession(id: "bad", kind: .mini, parentSessionID: nil,
                               presentation: .attached, workspaceID: "ws_a"))
        #expect(reg.session(id: "bad") == nil)
        // orphaned mini (parent id not present as a main) is ignored
        reg.upsert(WorkSession(id: "orphan", kind: .mini, parentSessionID: "missing",
                               presentation: .attached, workspaceID: "ws_a"))
        #expect(reg.session(id: "orphan") == nil)
    }

    @Test("init accepts persisted minis after their main parent even if input order is mixed")
    func initReordersForParentValidation() {
        let main = WorkSession.main(id: "m1", workspaceID: "ws_a", title: "Root")
        let mini = WorkSession.mini(id: "c1", parent: main, title: "Mini A")

        let reg = WorkSessionRegistry([mini, main])

        #expect(reg.mainSessions.map(\.id) == ["m1"])
        #expect(reg.children(of: "m1").map(\.id) == ["c1"])
    }

    @Test("upsert cannot implicitly promote, demote, or reparent existing sessions")
    func upsertPreservesStructure() {
        var (reg, main) = seeded()
        let secondMain = WorkSession.main(id: "m2", workspaceID: "ws_b", title: "Other")
        reg.upsert(secondMain)

        reg.upsert(WorkSession.main(id: "c1", workspaceID: "ws_a", title: "Implicit promote"))
        #expect(reg.session(id: "c1")?.kind == .mini)
        #expect(reg.session(id: "c1")?.parentSessionID == main.id)

        reg.upsert(WorkSession.mini(id: "m1", parent: secondMain, title: "Implicit demote"))
        #expect(reg.session(id: "m1")?.kind == .main)
        #expect(reg.session(id: "m1")?.parentSessionID == nil)

        reg.upsert(WorkSession.mini(id: "c1", parent: secondMain, title: "Implicit reparent"))
        #expect(reg.session(id: "c1")?.parentSessionID == main.id)
        #expect(reg.session(id: "c1")?.title == "Mini A")
    }

    @Test("mainSessions + children(of:) reflect the tree")
    func tree() {
        let (reg, _) = seeded()
        #expect(reg.mainSessions.map(\.id) == ["m1"])
        #expect(reg.children(of: "m1").map(\.id) == ["c1", "c2"])
        #expect(reg.children(of: "nope").isEmpty)
    }

    @Test("removing a main cascades its mini children (no orphans); removing a mini removes only it")
    func cascadeRemove() {
        var (reg, _) = seeded()
        reg.remove(id: "c1")
        #expect(reg.session(id: "c1") == nil)
        #expect(reg.children(of: "m1").map(\.id) == ["c2"])
        reg.remove(id: "m1")
        #expect(reg.sessions.isEmpty) // main + remaining child both gone
    }

    @Test("promote turns a mini into a main (drops parentage); no-op for a main")
    func promote() {
        var (reg, _) = seeded()
        reg.promote(id: "c1")
        let promoted = reg.session(id: "c1")
        #expect(promoted?.kind == .main)
        #expect(promoted?.parentSessionID == nil)
        #expect(reg.mainSessions.map(\.id).sorted() == ["c1", "m1"])
        // promoting a main is a no-op
        reg.promote(id: "m1")
        #expect(reg.session(id: "m1")?.kind == .main)
    }

    @Test("setPresentation flips a mini's presentation (identity unchanged)")
    func detach() {
        var (reg, _) = seeded()
        reg.setPresentation(id: "c1", .detached)
        #expect(reg.session(id: "c1")?.presentation == .detached)
        #expect(reg.session(id: "c1")?.parentSessionID == "m1") // identity intact
        reg.setPresentation(id: "c1", .attached)
        #expect(reg.session(id: "c1")?.presentation == .attached)
    }
}
