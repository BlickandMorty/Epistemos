import Foundation
import Testing
@testable import Epistemos

// Verifies the history projector against the runtime-verified messages() shape (og-messages-probe.mjs):
// nested {messages:{messages:[{info{role}, parts:[{type,text}]}], …}} → [WorkHistoryMessage].
@Suite("Work session history projector — messages() → native history")
struct WorkSessionHistoryProjectorTests {
    private let sample = Data(#"""
    {"messages":{"messages":[
      {"info":{"id":"m1","role":"user","time":1},"parts":[{"id":"p1","type":"text","text":"hello"}]},
      {"info":{"id":"m2","role":"assistant","time":2},"parts":[
        {"id":"p2","type":"text","text":"hi there"},
        {"id":"p3","type":"tool","tool":"bash","state":{"status":"completed","output":"ok"}},
        {"id":"p4","type":"reasoning","text":"thinking…"}
      ]}
    ],"nextCursor":null,"revision":7}}
    """#.utf8)

    @Test("projects user + assistant messages with role + parts (nested envelope)")
    func projectsConversation() {
        let history = WorkSessionHistoryProjector.project(sample)
        #expect(history.count == 2)
        #expect(history.first?.role == "user")
        #expect(history.first?.parts.first?.id == "p1")
        #expect(history.first?.parts.first?.text == "hello")
        let assistant = history.last
        #expect(assistant?.role == "assistant")
        #expect(assistant?.parts.contains { $0.kind == .text && $0.text == "hi there" } == true)
    }

    @Test("tool part carries name + status + output; reasoning → thinking")
    func toolAndThinking() {
        let history = WorkSessionHistoryProjector.project(sample)
        let parts = history.last?.parts ?? []
        let tool = parts.first { $0.kind == .tool }
        #expect(tool?.id == "p3")
        #expect(tool?.toolName == "bash")
        #expect(tool?.toolStatus == "completed")
        #expect(tool?.text == "ok")
        #expect(parts.contains { $0.kind == .thinking && $0.text == "thinking…" })
    }

    @Test("tool part surfaces edit/write file diffs from state.metadata.files[].diff (native diff cards)")
    func toolFileDiffs() {
        let data = Data(#"""
        {"messages":{"messages":[{"info":{"role":"assistant"},"parts":[
          {"type":"tool","tool":"edit","state":{"status":"completed","output":"done","metadata":{"files":[
            {"diff":"--- a/x.swift\n+++ b/x.swift\n@@ -1 +1 @@\n-old\n+new"},
            {"diff":"   "},
            {"diff":"--- a/y.swift\n+++ b/y.swift\n@@ -1 +1 @@\n-a\n+b"}]}}}]}]}}
        """#.utf8)
        let tool = (WorkSessionHistoryProjector.project(data).last?.parts ?? []).first { $0.kind == .tool }
        #expect(tool?.fileDiffs.count == 2)   // blank diff dropped
        #expect(tool?.fileDiffs.first?.contains("x.swift") == true)
        #expect(tool?.fileDiffs.first?.contains("+new") == true)
        // a tool with no edits → no diffs (non-edit tools stay clean)
        let plain = WorkSessionHistoryProjector.project(Data(
            #"{"messages":{"messages":[{"parts":[{"type":"tool","tool":"bash","state":{"status":"completed","output":"ls"}}]}]}}"#.utf8))
        #expect((plain.last?.parts.first { $0.kind == .tool })?.fileDiffs.isEmpty == true)
    }

    @Test("tool part surfaces a compact toolSummary from state.input (command/file); content never leaks (replay)")
    func toolInputSummary() {
        let data = Data(#"""
        {"messages":{"messages":[{"info":{"role":"assistant"},"parts":[
          {"type":"tool","tool":"write","state":{"status":"completed","output":"done",
            "input":{"filePath":"/x/y.swift","content":"SECRET-FILE-BODY"}}}]}]}}
        """#.utf8)
        let tool = (WorkSessionHistoryProjector.project(data).last?.parts ?? []).first { $0.kind == .tool }
        #expect(tool?.toolSummary == "/x/y.swift")        // only filePath
        #expect(tool?.toolSummary?.contains("SECRET") == false)   // content never surfaces
        // a bash tool → its command
        let bash = WorkSessionHistoryProjector.project(Data(
            #"{"messages":{"messages":[{"parts":[{"type":"tool","tool":"bash","state":{"status":"completed","output":"","input":{"command":"git log"}}}]}]}}"#.utf8))
        #expect((bash.last?.parts.first { $0.kind == .tool })?.toolSummary == "git log")
    }

    @Test("lenient: nil / malformed / empty → []")
    func lenient() {
        #expect(WorkSessionHistoryProjector.project(nil).isEmpty)
        #expect(WorkSessionHistoryProjector.project(Data("nope".utf8)).isEmpty)
        #expect(WorkSessionHistoryProjector.project(Data("{}".utf8)).isEmpty)
        // bare array (no envelope) also works
        let bare = Data(#"[{"info":{"id":"x","role":"assistant"},"parts":[{"type":"text","text":"y"}]}]"#.utf8)
        #expect(WorkSessionHistoryProjector.project(bare).first?.parts.first?.text == "y")
    }

    @Test("history replay bounds huge text and huge/many diffs before native rendering")
    func boundsHugeReplayPayloads() throws {
        let hugeText = String(repeating: "x", count: WorkTranscriptBounds.maxPartCharacters + 50)
        let hugeDiff = "--- a/x.swift\n+++ b/x.swift\n" +
            String(repeating: "+", count: WorkTranscriptBounds.maxDiffCharacters + 50)
        let files = (0..<(WorkTranscriptBounds.maxDiffsPerTool + 2)).map { _ in ["diff": hugeDiff] }
        let payload: [String: Any] = [
            "messages": [
                "messages": [[
                    "info": ["role": "assistant"],
                    "parts": [
                        ["type": "text", "text": hugeText],
                        ["type": "tool", "tool": "edit", "state": [
                            "status": "completed",
                            "output": hugeText,
                            "metadata": ["files": files],
                        ]],
                    ],
                ]],
            ],
        ]
        let history = WorkSessionHistoryProjector.project(try JSONSerialization.data(withJSONObject: payload))
        let parts = history.first?.parts ?? []
        #expect(parts.first { $0.kind == .text }?.text.hasSuffix("[truncated]") == true)
        let tool = parts.first { $0.kind == .tool }
        #expect(tool?.text.hasSuffix("[truncated]") == true)
        #expect(tool?.fileDiffs.count == WorkTranscriptBounds.maxDiffsPerTool)
        #expect(tool?.fileDiffs.first?.hasSuffix("[truncated]") == true)
    }
}
