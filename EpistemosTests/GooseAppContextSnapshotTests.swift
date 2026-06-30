import Foundation
import Testing
@testable import Epistemos

@Suite("Goose app context snapshot")
struct GooseAppContextSnapshotTests {
    @Test("snapshot fields are bounded and JSON-safe for the WebView bridge")
    func snapshotBoundsAndDictionary() throws {
        let longPath = "/" + String(repeating: "vault/", count: 300)
        let longTitle = String(repeating: "note-title-", count: 40)
        let longPreview = String(repeating: "preview ", count: 140)
        let longPrompt = String(repeating: "prompt ", count: 500)

        let snapshot = GooseAppContextSnapshot(
            available: true,
            vaultPath: longPath,
            activeNote: GooseAppContextSnapshot.Note(
                id: "note-1",
                title: longTitle,
                path: longPath,
                vaultRelativePath: "Notes/Today.md",
                preview: longPreview,
                wordCount: 12
            ),
            graph: GooseAppContextSnapshot.Graph(
                route: "note:note-1",
                sourceId: "note-1",
                selectedNodeId: "node-1",
                selectedNodeTitle: longTitle,
                selectedNodeType: "note",
                selectedNodeSourceId: "note-1"
            ),
            attachments: (0..<12).map { index in
                GooseAppContextSnapshot.Attachment(
                    kind: "note",
                    title: "Attachment \(index)",
                    path: "/tmp/attachment-\(index).md",
                    targetId: "attachment-\(index)",
                    summary: longPreview
                )
            },
            promptContext: longPrompt
        )

        #expect(snapshot.vaultPath?.count == GooseAppContextSnapshot.maxPathCharacters)
        #expect(snapshot.activeNote?.title.count == GooseAppContextSnapshot.maxTitleCharacters)
        #expect(snapshot.activeNote?.path?.count == GooseAppContextSnapshot.maxPathCharacters)
        #expect(snapshot.graph?.selectedNodeTitle?.count == GooseAppContextSnapshot.maxTitleCharacters)
        #expect(snapshot.attachments.count == 8)
        #expect(snapshot.promptContext?.count == GooseAppContextSnapshot.maxPromptContextCharacters)

        let dictionary = snapshot.dictionary
        #expect(dictionary["available"] as? Bool == true)
        #expect(dictionary["source"] as? String == "epistemos")
        #expect(dictionary["appMode"] as? String == "goose")
        #expect((dictionary["attachments"] as? [[String: Any]])?.count == 8)

        let data = try JSONSerialization.data(withJSONObject: dictionary)
        let decoded = try JSONDecoder().decode(GooseAppContextSnapshot.self, from: data)
        #expect(decoded == snapshot)
    }

    @MainActor
    @Test("missing app bootstrap reports unavailable context")
    func missingBootstrapReportsUnavailable() {
        let snapshot = GooseAppContextSnapshot.current(bootstrap: nil)
        #expect(snapshot.available == false)
        #expect(snapshot.activeNote == nil)
        #expect(snapshot.graph == nil)
        #expect(snapshot.attachments.isEmpty)
    }

    @Test("Goose WebView exposes context snapshot through the narrow native bridge")
    func bridgeSourceGuards() throws {
        let bootShim = try loadMirroredSourceTextFile("Epistemos/Goose/GooseWebBootShim.swift")
        #expect(bootShim.contains(#""epistemos.context.snapshot": .implementedNative"#))
        #expect(bootShim.contains("const epistemosContextSnapshot = () => postNativeAffordance('epistemos.context.snapshot');"))
        #expect(bootShim.contains("context: Object.freeze({"))
        #expect(bootShim.contains("snapshot: epistemosContextSnapshot"))

        let bridge = try loadMirroredSourceTextFile("Epistemos/Goose/GooseWebNativeAffordanceBridge.swift")
        #expect(bridge.contains(#"case "epistemos.context.snapshot":"#))
        #expect(bridge.contains("return GooseAppContextSnapshot.current().dictionary"))

        let staging = try loadMirroredSourceTextFile("stage-goose-web-ui.sh")
        #expect(staging.contains("src/epistemos/contextBridge.ts"))
        #expect(staging.contains("Epistemos context bridge unavailable"))
        #expect(staging.contains("if (snapshot.available === false) return '';"))
        #expect(staging.contains("getEpistemosContextSnapshot"))
        #expect(staging.contains("formatEpistemosContextForPrompt"))
        #expect(staging.contains("handleAttachEpistemosContext"))
        #expect(staging.contains("Attach Epistemos context"))
        #expect(staging.contains("BookOpen"))
    }
}
