import Testing
import Foundation

@testable import Epistemos

// SS-LT local multi-tool reliability (owner 2026-06-20: "harden it — worked one time and never
// again"; the plan explicitly includes "harden ... the parse"). The local grammar (LocalToolGrammar,
// Mistral profile) tells a Mistral Small model its native `[TOOL_CALLS]tool.name[ARGS]{...}` output
// "is accepted", but ToolCallParser had no strategy for it — so a Mistral tool call SILENTLY DROPPED
// (the args JSON has no "name" key, so even the generic embedded-JSON scan loses the tool name).
// Mistral Small is a supported local model, so this was a real claim-vs-capability gap on the live
// local tool path. These pin the new Strategy 1e (classic + newer JSON-array forms) and confirm no
// regression to the canonical <tool_call> path.
@Suite("ToolCallParser — Mistral native [TOOL_CALLS] format")
struct ToolCallParserMistralTests {

    @Test("classic [TOOL_CALLS]name[ARGS]{json} parses the name + arguments")
    func classicMistralForm() {
        let calls = ToolCallParser.parse(#"[TOOL_CALLS]vault.search[ARGS]{"query": "hegemony"}"#)
        #expect(calls.count == 1)
        #expect(calls.first?.name == "vault.search")
        #expect(calls.first?.argumentsJson.contains("hegemony") == true)
    }

    @Test("classic form with trailing prose still extracts the leading args object")
    func classicWithTrailingProse() {
        let calls = ToolCallParser.parse(#"[TOOL_CALLS]file.read[ARGS]{"path": "/notes/x.md"} I will read it now."#)
        #expect(calls.first?.name == "file.read")
        #expect(calls.first?.argumentsJson.contains("/notes/x.md") == true)
    }

    @Test("newer [TOOL_CALLS][{...}] JSON-array form parses")
    func newerMistralArrayForm() {
        let calls = ToolCallParser.parse(#"[TOOL_CALLS][{"name": "eidos.recall", "arguments": {"q": "x"}}]"#)
        #expect(calls.count == 1)
        #expect(calls.first?.name == "eidos.recall")
    }

    @Test("a [TOOL_CALLS] marker with no usable payload yields no call (no false positive)")
    func emptyMarkerNoCall() {
        #expect(ToolCallParser.parse("[TOOL_CALLS]").isEmpty)
        #expect(ToolCallParser.parse("[TOOL_CALLS]some prose with no args").isEmpty)
    }

    @Test("the canonical <tool_call> path still wins (no regression to existing formats)")
    func canonicalStillWorks() {
        let calls = ToolCallParser.parse(#"<tool_call>{"name": "eidos.recall", "arguments": {"q": "x"}}</tool_call>"#)
        #expect(calls.first?.name == "eidos.recall")
    }
}
