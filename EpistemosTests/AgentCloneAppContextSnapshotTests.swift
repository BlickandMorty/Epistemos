import Foundation
import Testing
@testable import Epistemos

@Suite("AgentClone app context snapshot")
struct AgentCloneAppContextSnapshotTests {
    @Test("normalizes blanks and keeps model-visible summary bounded to app context")
    func normalizationAndSummary() {
        let snapshot = AgentCloneAppContextSnapshot(
            appName: "  ",
            workspacePath: "  ",
            vaultPath: "\n",
            appSupportPath: "\t",
            modeLabel: "",
            presentation: " "
        )

        #expect(snapshot.appName == "Epistemos")
        #expect(snapshot.workspacePath == nil)
        #expect(snapshot.vaultPath == nil)
        #expect(snapshot.appSupportPath == nil)
        #expect(snapshot.modeLabel == "Act")
        #expect(snapshot.presentation == "main")
        #expect(snapshot.portalContext.portal == .main)
        #expect(snapshot.modelVisibleSummary.contains("Epistemos | Act | surface: main"))
        #expect(snapshot.modelVisibleSummary.contains("portal: main"))
    }

    @Test("model visible JSON is deterministic and does not expose app support storage")
    func modelVisibleJSON() {
        let snapshot = AgentCloneAppContextSnapshot(
            appName: "Epistemos",
            workspacePath: "/Users/example",
            vaultPath: "/Users/example/Vault",
            appSupportPath: "/Users/example/Library/Application Support/Epistemos/AgentClone",
            modeLabel: "Act",
            presentation: "main"
        )

        let json = snapshot.modelVisibleJSON
        #expect(json.contains(#""appName":"Epistemos""#))
        #expect(json.contains(#""modeLabel":"Act""#))
        #expect(json.contains(#""presentation":"main""#))
        #expect(json.contains(#""portal":"main""#))
        #expect(json.contains(#""vaultPath":"\/Users\/example\/Vault""#) || json.contains(#""vaultPath":"/Users/example/Vault""#))
        #expect(json.contains(#""workspacePath":"\/Users\/example""#) || json.contains(#""workspacePath":"/Users/example""#))
        #expect(!json.contains("appSupport"))
        #expect(!json.contains("Application Support"))

        #expect(snapshot.modelVisibleSummary.contains("portal: main"))
        #expect(snapshot.modelVisibleSummary.contains("vault: /Users/example/Vault"))
        #expect(snapshot.modelVisibleSummary.contains("workspace: /Users/example"))
        #expect(snapshot.bridgePresentation.contains("main | Main"))
    }

    @Test("context seam stays app-owned and does not import deleted surface state")
    func sourceStaysPlainAppModel() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/AgentFusion/AgentCloneAppContextSnapshot.swift")
        #expect(source.contains("struct AgentCloneAppContextSnapshot: Codable, Equatable, Sendable"))
        #expect(!source.contains("import AgentClone"))
        #expect(!source.contains("ChatState"))
        #expect(!source.contains("GraphState"))
        #expect(!source.contains("NoteChat"))
        #expect(!source.contains("MiniChat"))
        #expect(!source.contains("AppBootstrap.shared"))
    }
}
