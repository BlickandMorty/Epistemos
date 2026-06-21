import Testing
import Foundation

@testable import Epistemos

// SS-HW seam upgrade — the JS console / error-capture bridge that was a deferred empty stub. The
// document's console pipeline (HTMLWorkspaceConsoleError + .recordConsoleError + the console panel)
// already existed; only the JS→Swift capture was missing. These pin the capture script + its
// flag-gating + the wiring into the existing pipeline + the honest capability-ledger note.
@Suite("SS-HW — JS console capture bridge")
struct HTMLWorkspaceConsoleBridgeTests {

    @Test("the console-capture flag defaults OFF (bridge not installed → byte-identical preview)")
    func flagDefaultsOff() {
        if ProcessInfo.processInfo.environment["EPISTEMOS_HTML_WORKSPACE_CONSOLE_V0"] == nil {
            #expect(HTMLWorkspaceConsoleBridge.enabled == false)
        }
    }

    @Test("the injection script captures window errors + console.error/warn and posts to the handler")
    func injectionScriptCapturesErrors() {
        let js = HTMLWorkspaceConsoleBridge.injectionScript
        #expect(js.contains("addEventListener('error'"))
        #expect(js.contains("unhandledrejection"))
        #expect(js.contains("console.error"))
        #expect(js.contains("console.warn"))
        #expect(js.contains("messageHandlers.epistemosWorkspaceConsole.postMessage"))
        #expect(HTMLWorkspaceConsoleBridge.messageHandlerName == "epistemosWorkspaceConsole")
    }

    @Test("the editor records captured errors through the existing .recordConsoleError pipeline")
    func editorWiresCaptureToPipeline() throws {
        let editor = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        #expect(editor.contains("onConsoleError:"))
        #expect(editor.contains(".recordConsoleError(error)"))
        let preview = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspacePreviewView.swift")
        #expect(preview.contains("HTMLWorkspaceConsoleBridge.messageHandlerName"))
        #expect(preview.contains("onConsoleError?(error)"))
        // The console handler is cleaned up on detach (no leaked WKScriptMessageHandler).
        #expect(preview.contains("consoleHandlerInstalled = false"))
    }

    @Test("the capability ledger honestly notes the bridge is now wired (behind the flag)")
    func ledgerNotesWiredBridge() {
        let console = HTMLWorkspaceCapabilityStatus.capabilities.first { $0.name.contains("JS console") }
        #expect(console != nil)
        #expect(console?.note.contains("EPISTEMOS_HTML_WORKSPACE_CONSOLE_V0") == true)
    }
}
