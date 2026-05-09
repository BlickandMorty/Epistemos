import Foundation
import Testing

@testable import Epistemos

@Suite("Epdoc Copilot surface")
nonisolated struct EpdocCopilotSurfaceTests {
    @Test("prompt router maps doc requests to bounded transforms")
    func promptRouterMapsRequestsToTransforms() {
        #expect(EpdocCopilotTransform.resolve(prompt: "make this into a graph") == .visualMap)
        #expect(EpdocCopilotTransform.resolve(prompt: "add YAML front matter") == .frontmatter)
        #expect(EpdocCopilotTransform.resolve(prompt: "make a scatterplot of the evidence") == .scatterplot)
        #expect(EpdocCopilotTransform.resolve(prompt: "turn this into a study callout") == .studyCallout)
        #expect(EpdocCopilotTransform.resolve(prompt: "what is the argument?") == nil)
    }

    @Test("transform commands use concrete epdoc editor actions")
    func transformCommandsAreConcrete() {
        #expect(EpdocCopilotTransform.visualMap.command == .runCommand(
            name: "insertEpdocGraphFromDocument",
            argsJSON: Data("[]".utf8)
        ))
        #expect(EpdocCopilotTransform.scatterplot.command == .insertSlashChoice(blockType: "chart-scatter"))
        #expect(EpdocCopilotTransform.studyCallout.command == .insertSlashChoice(blockType: "callout-tip"))

        guard case let .runCommand(name, argsJSON) = EpdocCopilotTransform.frontmatter.command else {
            Issue.record("Frontmatter must be a concrete JS command so the dock does not insert inert UI chrome.")
            return
        }
        #expect(name == "insertEpdocFrontmatter")
        #expect(argsJSON == Data("[]".utf8))
    }

    @Test("epdoc chrome mounts native bottom document actions")
    func chromeMountsNativeCopilotDock() throws {
        let chrome = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let dock = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocCopilotDockView.swift")
        let inbound = try loadMirroredSourceTextFile("js-editor/src/bridge/inbound.ts")

        #expect(chrome.contains("EpdocCopilotDockView("),
                "Epdoc must expose the document actions directly in the native editor chrome.")
        #expect(chrome.contains(".overlay(alignment: .bottomTrailing)"),
                "The document actions should stay in bottom native chrome, not inside the WebKit document body.")
        #expect(dock.contains("Visualize document"))
        #expect(dock.contains("Add frontmatter"))
        #expect(!dock.contains("Ask Epdoc"))
        #expect(!dock.contains("TextField("))
        #expect(!dock.contains("EpdocCopilotMessageBubble"))
        #expect(dock.contains(".regularMaterial"))
        #expect(!dock.contains("WKWebView"),
                "The document action dock is native SwiftUI chrome; the document body stays the only WebKit surface.")
        #expect(inbound.contains("insertEpdocFrontmatter"))
        #expect(inbound.contains("function insertEpdocFrontmatter(editor: Editor): boolean"))
    }

    @Test("epdoc dock does not expose a free-form chat prompt")
    func freeformPromptDoesNotOverclaimUnwiredAgent() throws {
        let dock = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocCopilotDockView.swift")

        #expect(!dock.contains("I sent that to the document agent hook"),
                "The .epdoc document window does not yet wire a free-form agent loop, so the dock must not claim it sent the prompt.")
        #expect(!dock.contains("Free-form document editing is not wired yet"),
                "The Epdoc window should not show a chat surface; Mini Chat owns free-form document conversation.")
        #expect(!dock.contains("submitPrompt()"))
        #expect(!dock.contains("@FocusState"))
    }
}
