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

    // MARK: - W7.17 inbound decode (caretChanged / requestSlashMenu / requestBubbleMenu)

    @Test("caretChanged decodes the rect + selection payload")
    func caretChangedDecodes() {
        let body: [String: Any] = [
            "type": "caretChanged",
            "rect": ["x": 12.5, "y": 34.0, "w": 1.0, "h": 18.0],
            "selection": ["from": 5, "to": 5, "empty": true],
        ]
        guard case let .caretChanged(rect, selection) = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "expected .caretChanged")
            return
        }
        #expect(rect.x == 12.5)
        #expect(rect.y == 34.0)
        #expect(rect.width == 1.0)
        #expect(rect.height == 18.0)
        #expect(selection.from == 5)
        #expect(selection.to == 5)
        #expect(selection.isEmpty == true)
    }

    @Test("requestSlashMenu decodes query + anchor")
    func requestSlashMenuDecodes() {
        let body: [String: Any] = [
            "type": "requestSlashMenu",
            "query": "head",
            "anchor": ["x": 100, "y": 200, "w": 1, "h": 18],
        ]
        guard case let .requestSlashMenu(query, anchor) = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "expected .requestSlashMenu")
            return
        }
        #expect(query == "head")
        #expect(anchor.x == 100)
        #expect(anchor.y == 200)
    }

    @Test("requestBubbleMenu decodes selection + anchor")
    func requestBubbleMenuDecodes() {
        let body: [String: Any] = [
            "type": "requestBubbleMenu",
            "selection": ["from": 10, "to": 25, "empty": false],
            "anchor": ["x": 50, "y": 60, "w": 200, "h": 18],
        ]
        guard case let .requestBubbleMenu(selection, anchor) = EpdocBridgeMessage.decode(messageBody: body) else {
            #expect(Bool(false), "expected .requestBubbleMenu")
            return
        }
        #expect(selection.from == 10)
        #expect(selection.to == 25)
        #expect(selection.isEmpty == false)
        #expect(anchor.width == 200)
    }

    @Test("malformed W7.17 payloads return nil (defensive decoder)")
    func w717MalformedReturnsNil() {
        // caretChanged missing rect
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "caretChanged",
                                                       "selection": ["from": 0, "to": 0, "empty": true]]) == nil)
        // requestSlashMenu missing query
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "requestSlashMenu",
                                                       "anchor": ["x": 0, "y": 0, "w": 0, "h": 0]]) == nil)
        // requestBubbleMenu with non-bool empty
        #expect(EpdocBridgeMessage.decode(messageBody: ["type": "requestBubbleMenu",
                                                       "selection": ["from": 0, "to": 0, "empty": "true"],
                                                       "anchor": ["x": 0, "y": 0, "w": 0, "h": 0]]) == nil)
    }

    // MARK: - Swift → JS commands (W7.17 namespaced surface)

    @Test("setContent routes through window.epistemos.setContent with stringified JSON")
    func setContentRoutesThroughEpistemosNamespace() {
        let json = #"{"type":"doc","content":[]}"#.data(using: .utf8)!
        let cmd = EpdocEditorCommand.setContent(json: json)
        let expr = cmd.javaScriptExpression()
        #expect(expr == #"window.epistemos.setContent("{\"type\":\"doc\",\"content\":[]}")"#,
                "setContent must call window.epistemos.setContent(jsonString); got: \(expr)")
    }

    @Test("focusStart + focusEnd route through window.epistemos.focus*")
    func focusCommands() {
        #expect(EpdocEditorCommand.focusStart.javaScriptExpression() == "window.epistemos.focusStart()")
        #expect(EpdocEditorCommand.focusEnd.javaScriptExpression() == "window.epistemos.focusEnd()")
    }

    @Test("dismissSlashMenu + dismissBubbleMenu emit the canonical no-arg calls")
    func dismissCommands() {
        #expect(EpdocEditorCommand.dismissSlashMenu.javaScriptExpression() == "window.epistemos.dismissSlashMenu()")
        #expect(EpdocEditorCommand.dismissBubbleMenu.javaScriptExpression() == "window.epistemos.dismissBubbleMenu()")
    }

    @Test("insertSlashChoice emits the canonical block-type call (string-literal escaped)")
    func insertSlashChoiceCommand() {
        let cmd = EpdocEditorCommand.insertSlashChoice(blockType: "heading-1")
        #expect(cmd.javaScriptExpression() == #"window.epistemos.insertSlashChoice("heading-1")"#)
    }

    @Test("runCommand spreads the JSON args array")
    func runCommandSpreadArgs() {
        let argsJSON = "[{\"level\":2}]".data(using: .utf8)!
        let cmd = EpdocEditorCommand.runCommand(name: "toggleHeading", argsJSON: argsJSON)
        #expect(cmd.javaScriptExpression() == #"window.epistemos.runCommand("toggleHeading", ...[{"level":2}])"#)
    }

    @Test("jsStringLiteral escapes the dangerous JS literal characters")
    func jsStringLiteralEscapes() {
        #expect(jsStringLiteral("plain") == "\"plain\"")
        #expect(jsStringLiteral(#"with "quote""#) == #""with \"quote\"""#)
        #expect(jsStringLiteral("with\nnewline") == "\"with\\nnewline\"")
        #expect(jsStringLiteral("with\\backslash") == "\"with\\\\backslash\"")
        // U+2028 / U+2029 are JS string-terminators inside literals — escape them
        #expect(jsStringLiteral("a\u{2028}b") == "\"a\\u2028b\"")
    }
}
