import Foundation
import Testing
@testable import Epistemos

@Suite("Work session ontology — main / mini / parentage invariants")
struct WorkSessionTests {
    @Test("main() is a valid root with no parent")
    func mainSession() {
        let m = WorkSession.main(id: "s1", workspaceID: "ws_a", title: "Root")
        #expect(m.kind == .main)
        #expect(m.parentSessionID == nil)
        #expect(m.workspaceID == "ws_a")
        #expect(m.isValid)
    }

    @Test("mini() references its parent + inherits the parent's workspace")
    func miniSession() {
        let parent = WorkSession.main(id: "s1", workspaceID: "ws_a")
        let child = WorkSession.mini(id: "s2", parent: parent, title: "Mini")
        #expect(child.kind == .mini)
        #expect(child.parentSessionID == "s1")
        #expect(child.workspaceID == "ws_a") // inherited
        #expect(child.presentation == .attached)
        #expect(child.isValid)
    }

    @Test("session titles are compact, single-line, and bounded")
    func sessionTitlesAreNormalized() {
        let raw = "  Build\nnative\tWork   surface  " + String(repeating: "x", count: 100)
        let main = WorkSession.main(id: "s1", workspaceID: "ws", title: raw)
        #expect(main.title?.contains("\n") == false)
        #expect(main.title?.contains("\t") == false)
        #expect(main.title?.contains("  ") == false)
        #expect(main.title?.hasPrefix("Build native Work surface") == true)
        #expect((main.title?.count ?? 0) <= 80)
        #expect(WorkSession.main(id: "empty", workspaceID: "ws", title: " \n\t ").title == nil)
    }

    @Test("invariants reject a parentless mini and a self-parented mini, and a main with a parent")
    func invariants() {
        let parentlessMini = WorkSession(
            id: "x", kind: .mini, parentSessionID: nil, presentation: .attached, workspaceID: "ws")
        #expect(!parentlessMini.isValid)
        let selfParent = WorkSession(
            id: "x", kind: .mini, parentSessionID: "x", presentation: .attached, workspaceID: "ws")
        #expect(!selfParent.isValid)
        let mainWithParent = WorkSession(
            id: "m", kind: .main, parentSessionID: "p", presentation: .attached, workspaceID: "ws")
        #expect(!mainWithParent.isValid)
    }

    @Test("presented(as:) changes presentation only — identity is unchanged (detach ≠ new session)")
    func detachKeepsIdentity() {
        let parent = WorkSession.main(id: "s1", workspaceID: "ws_a")
        let attached = WorkSession.mini(id: "s2", parent: parent)
        let detached = attached.presented(as: .detached)
        #expect(detached.presentation == .detached)
        #expect(detached.id == attached.id)
        #expect(detached.kind == attached.kind)
        #expect(detached.parentSessionID == attached.parentSessionID)
        #expect(detached.workspaceID == attached.workspaceID)
        // round-trips back
        #expect(detached.presented(as: .attached) == attached)
    }

    @Test("Codable round-trips a mini session")
    func codableRoundTrip() throws {
        let parent = WorkSession.main(id: "s1", workspaceID: "ws_a")
        let child = WorkSession.mini(id: "s2", parent: parent, openCodeSessionID: "oc_9", title: "Mini")
        let data = try JSONEncoder().encode(child)
        let decoded = try JSONDecoder().decode(WorkSession.self, from: data)
        #expect(decoded == child)
    }
}
