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

    @Test("epdoc chrome mounts a native bottom copilot dock")
    func chromeMountsNativeCopilotDock() throws {
        let chrome = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let dock = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocCopilotDockView.swift")
        let inbound = try loadMirroredSourceTextFile("js-editor/src/bridge/inbound.ts")

        #expect(chrome.contains("EpdocCopilotDockView("),
                "Epdoc must expose the document copilot directly in the native editor chrome.")
        #expect(chrome.contains(".overlay(alignment: .bottomTrailing)"),
                "The copilot should be a bottom chat bubble, not another top toolbar or in-document fake panel.")
        #expect(dock.contains("Visualize document"))
        #expect(dock.contains("Add frontmatter"))
        #expect(dock.contains("Scatterplot"))
        #expect(dock.contains("Study callout"))
        #expect(dock.contains(".regularMaterial"))
        #expect(!dock.contains("WKWebView"),
                "The copilot dock is native SwiftUI chrome; the document body stays the only WebKit surface.")
        #expect(inbound.contains("insertEpdocFrontmatter"))
        #expect(inbound.contains("function insertEpdocFrontmatter(editor: Editor): boolean"))
    }

    @Test("free-form copilot prompt does not overclaim an unwired agent")
    func freeformPromptDoesNotOverclaimUnwiredAgent() throws {
        let dock = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocCopilotDockView.swift")

        #expect(!dock.contains("I sent that to the document agent hook"),
                "The .epdoc document window does not yet wire a free-form agent loop, so the dock must not claim it sent the prompt.")
        #expect(dock.contains("Free-form document editing is not wired yet"),
                "Unknown prompts should honestly disclose the current bounded-transform state.")
        #expect(dock.contains("freeformAgentEnabled"),
                "Keep the future hook explicit instead of deleting the intentional scaffold.")
    }
}
