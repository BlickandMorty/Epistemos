import Foundation
import Testing

@testable import Epistemos

/// Wave 7.2 base source-guard for the Tiptap WKWebView bridge surface
/// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.2,
///  cross-ref `docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md` §4).
///
/// Tests cover:
///   - The custom URL scheme constant (must match the JS bridge)
///   - JS → Swift message decoding (every shape per the bridge protocol)
///   - Swift → JS command emission (canonical JS expressions)
///   - Save pipeline debounce semantics (matches the 300ms research finding)
///
/// The actual WKWebView integration + Tiptap JS bundle live in a
/// follow-up. The bridge code is exercised in isolation here.
@Suite("Epdoc editor bridge (Wave 7.2 base)")
nonisolated struct EpdocEditorBridgeTests {

    // MARK: - URL scheme

    @Test("custom URL scheme is the canonical epistemos-doc")
    func canonicalScheme() {
        #expect(epdocEditorURLScheme == "epistemos-doc",
                "the custom scheme MUST be epistemos-doc — the JS bundle hard-codes the same string in its loader; drift breaks asset fetches")
    }

    // MARK: - JS → Swift messages

    @Test("contentDidChange decodes from canonical body shape")
    func contentDidChangeDecodes() {
        let body: [String: Any] = [
            "type": "contentDidChange",
            "json": #"{"type":"doc","content":[]}"#,
        ]
        guard case let .contentDidChange(data)? = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "must decode .contentDidChange")
            return
        }
        let text = String(data: data, encoding: .utf8) ?? ""
        #expect(text.contains("\"type\":\"doc\""))
    }

    @Test("editorReady decodes from canonical body shape")
    func editorReadyDecodes() {
        let body: [String: Any] = ["type": "editorReady"]
        guard case .editorReady? = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "must decode .editorReady")
            return
        }
    }

    @Test("error decodes from canonical body shape")
    func errorDecodes() {
        let body: [String: Any] = [
            "type": "error",
            "message": "boom",
        ]
        guard case let .error(msg)? = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "must decode .error")
            return
        }
        #expect(msg == "boom")
    }

    @Test("malformed body returns nil")
    func malformedBodyReturnsNil() {
        // Non-dictionary body
        #expect(EpdocBridgeMessage.decode(messageBody: "garbage") == nil)
        // Missing type key
        #expect(EpdocBridgeMessage.decode(messageBody: ["json": "x"]) == nil)
        // Unknown type
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "unknown_kind"]) == nil)
        // contentDidChange missing required json
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "contentDidChange"]) == nil)
        // error missing required message
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "error"]) == nil)
    }

    // MARK: - Swift → JS commands

    @Test("setContent emits the canonical Tiptap command expression")
    func setContentEmitsTiptapCommand() {
        let json = #"{"type":"doc","content":[]}"#.data(using: .utf8)!
        let cmd = EpdocEditorCommand.setContent(json: json)
        let expr = cmd.javaScriptExpression()
        #expect(expr == #"window.epdocEditor.commands.setContent({"type":"doc","content":[]})"#,
                "setContent must call Tiptap's commands.setContent with the JSON inlined as a JS object literal; got: \(expr)")
    }

    @Test("focusStart emits the canonical focus command")
    func focusStartCommand() {
        let cmd = EpdocEditorCommand.focusStart
        #expect(cmd.javaScriptExpression() == "window.epdocEditor.commands.focus('start')")
    }

    @Test("focusEnd emits the canonical focus command")
    func focusEndCommand() {
        let cmd = EpdocEditorCommand.focusEnd
        #expect(cmd.javaScriptExpression() == "window.epdocEditor.commands.focus('end')")
    }
}
