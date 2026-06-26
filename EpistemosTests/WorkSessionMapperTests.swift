import Foundation
import Testing
@testable import Epistemos

@Suite("Work session mapper — OpenWork sessions → WorkSession ontology")
struct WorkSessionMapperTests {
    @Test("a parentless session maps to a main (root) bound to its OpenCode id")
    func mainSession() {
        let json = Data(#"{"items":[{"id":"s1","title":"Root"}]}"#.utf8)
        let result = WorkSessionMapper.workSessions(fromSessionsJSON: json, workspaceID: "ws_a")
        #expect(result.count == 1)
        #expect(result[0].kind == .main)
        #expect(result[0].id == "s1")
        #expect(result[0].openCodeSessionID == "s1")
        #expect(result[0].workspaceID == "ws_a")
        #expect(result[0].title == "Root")
    }

    @Test("a session whose parentID is a known session maps to a mini")
    func miniSession() {
        let json = Data(#"{"items":[{"id":"s1"},{"id":"s2","parentID":"s1","title":"Mini"}]}"#.utf8)
        let result = WorkSessionMapper.workSessions(fromSessionsJSON: json, workspaceID: "ws_a")
        let mini = result.first { $0.id == "s2" }
        #expect(mini?.kind == .mini)
        #expect(mini?.parentSessionID == "s1")
        #expect(mini?.workspaceID == "ws_a")
        #expect(result.first { $0.id == "s1" }?.kind == .main)
    }

    @Test("an orphan/self parentID is treated as a root (matches getRootSessions)")
    func orphanAndSelfParentAreRoots() {
        let json = Data(#"{"items":[{"id":"s2","parentID":"ghost"},{"id":"s3","parentID":"s3"}]}"#.utf8)
        let result = WorkSessionMapper.workSessions(fromSessionsJSON: json, workspaceID: "ws")
        #expect(result.allSatisfy { $0.kind == .main })
        #expect(result.count == 2)
    }

    @Test("malformed / missing items → empty")
    func malformed() {
        #expect(WorkSessionMapper.workSessions(fromSessionsJSON: Data("nope".utf8), workspaceID: "ws").isEmpty)
        #expect(WorkSessionMapper.workSessions(fromSessionsJSON: Data("{}".utf8), workspaceID: "ws").isEmpty)
    }

    // MARK: OpenGUI sidecar path (flat array, no parentID → all main; id is engine-namespaced + stable)

    @Test("OpenGUI sidecar list maps every session to a MAIN bound to its (namespaced, stable) id")
    func sidecarListAllMain() {
        let json = Data(#"[{"id":"opencode:ses_a","title":"One"},{"id":"opencode:ses_b"}]"#.utf8)
        let result = WorkSessionMapper.workSessions(fromSidecarListJSON: json, workspaceID: "ws_og")
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.kind == .main }) // OpenGUI SessionSummary has no parentID → no minis from list
        let a = result.first { $0.id == "opencode:ses_a" }
        #expect(a?.openCodeSessionID == "opencode:ses_a") // id doubles as the bound OpenCode session (identity preserved)
        #expect(a?.workspaceID == "ws_og")
        #expect(a?.title == "One")
        #expect(result.first { $0.id == "opencode:ses_b" }?.title == nil) // title optional
    }

    @Test("OpenGUI sidecar titles are normalized before reaching the native rail")
    func sidecarTitlesAreNormalized() {
        let json = Data(#"[{"id":"opencode:ses_title","title":"  One\nTwo\tThree  "}]"#.utf8)
        let result = WorkSessionMapper.workSessions(fromSidecarListJSON: json, workspaceID: "ws_og")
        #expect(result.first?.title == "One Two Three")
    }

    @Test("OpenGUI sidecar list: malformed / non-array / empty-id entries are skipped")
    func sidecarListMalformed() {
        #expect(WorkSessionMapper.workSessions(fromSidecarListJSON: Data("nope".utf8), workspaceID: "ws").isEmpty)
        // worker-shaped `{items:[…]}` is NOT the sidecar shape → not an array → empty (the two paths don't cross-parse)
        #expect(WorkSessionMapper.workSessions(
            fromSidecarListJSON: Data(#"{"items":[{"id":"x"}]}"#.utf8), workspaceID: "ws").isEmpty)
        // empty-id entries skipped
        #expect(WorkSessionMapper.workSessions(
            fromSidecarListJSON: Data(#"[{"id":""},{"title":"noid"}]"#.utf8), workspaceID: "ws").isEmpty)
    }
}
