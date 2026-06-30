import Testing
import Foundation

@testable import Epistemos

// SS-HW seam upgrade — the JS console / error-capture bridge that was a deferred empty stub. The
// document's console pipeline (HTMLWorkspaceConsoleError + .recordConsoleError + the console panel)
// already existed; only the JS→Swift capture was missing. These pin the capture script + its
// default-on behavior + the wiring into the existing pipeline + the honest capability-ledger note.
@Suite("SS-HW — JS console capture bridge")
struct HTMLWorkspaceConsoleBridgeTests {

    @Test("the console-capture bridge defaults ON with an env opt-out")
    func flagDefaultsOnWithOptOut() {
        if ProcessInfo.processInfo.environment["EPISTEMOS_HTML_WORKSPACE_CONSOLE_V0"] == nil {
            #expect(HTMLWorkspaceConsoleBridge.enabled == true)
        }
        #expect(!HTMLWorkspaceConsoleCapturePolicy.isEnabled(environment: ["EPISTEMOS_HTML_WORKSPACE_CONSOLE_V0": "0"]))
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

    @Test("console payloads are bounded before entering the editor pipeline")
    func diagnosticPayloadBoundsWebKitMessages() throws {
        let diagnostic = try #require(HTMLWorkspaceConsoleBridge.DiagnosticPayload.fromMessageBody([
            "message": String(repeating: "m", count: HTMLWorkspacePackageLimits.maxConsoleErrorMessageCharacters + 100),
            "source": String(repeating: "s", count: HTMLWorkspacePackageLimits.maxConsoleErrorSourceCharacters + 100),
            "line": NSNumber(value: -4),
            "column": NSNumber(value: UInt64(UInt32.max) + 99),
        ]))

        #expect(diagnostic.message.count == HTMLWorkspacePackageLimits.maxConsoleErrorMessageCharacters)
        #expect(diagnostic.message.hasSuffix("... [truncated]"))
        #expect(diagnostic.source?.count == HTMLWorkspacePackageLimits.maxConsoleErrorSourceCharacters)
        #expect(diagnostic.source?.hasSuffix("... [truncated]") == true)
        #expect(diagnostic.line == 0)
        #expect(diagnostic.column == UInt32.max)
    }

    @Test("the editor records captured errors through the existing .recordConsoleError pipeline")
    func editorWiresCaptureToPipeline() throws {
        let editor = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceEditorView.swift")
        #expect(editor.contains("onConsoleError:"))
        #expect(editor.contains(".recordConsoleError(error)"))
        let preview = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspacePreviewView.swift")
        #expect(preview.contains("HTMLWorkspaceConsoleBridge.messageHandlerName"))
        #expect(preview.contains("HTMLWorkspaceConsoleBridge.DiagnosticPayload.fromMessageBody"))
        #expect(preview.contains("onConsoleError?(error.boundedForPackage())"))
        // The console handler is cleaned up on detach (no leaked WKScriptMessageHandler).
        #expect(preview.contains("consoleHandlerInstalled = false"))
    }

    @Test("the capability ledger honestly notes the bridge is live")
    func ledgerNotesWiredBridge() {
        let console = HTMLWorkspaceCapabilityStatus.capabilities.first { $0.name.contains("JS console") }
        #expect(console != nil)
        #expect(console?.isLive == true)
        #expect(console?.note.contains("Proven in-app") == true)
    }
}
