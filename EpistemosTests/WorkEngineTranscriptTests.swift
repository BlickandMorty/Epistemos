import Foundation
import Testing
@testable import Epistemos

// Proves the event→transcript reducer turns LiveSessionEvent JSON into clean native content (no raw JSON/log debris),
// accumulates by partId, separates thinking from answer, models tools as cards, tracks run status, de-dupes by seq.
@MainActor
@Suite("Work engine transcript — LiveSessionEvent → native transcript")
struct WorkEngineTranscriptTests {
    /// Build one event's raw JSON (as the sidecar forwards it).
    private func ev(_ dict: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
    }

    @Test("streamed text appends into ONE answer part keyed by partId")
    func accumulatesAnswer() {
        let t = WorkEngineTranscript()
        t.ingest(eventJSON: ev(["type": "part.text.appended", "seq": 1, "partId": "p1", "partKind": "text", "text": "Hello"]))
        t.ingest(eventJSON: ev(["type": "part.text.appended", "seq": 2, "partId": "p1", "partKind": "text", "text": " world"]))
        #expect(t.parts.filter { $0.kind == .answer }.count == 1)
        #expect(t.answerText == "Hello world")
    }

    @Test("duplicate seq is ignored (the known onEvent double-fire)")
    func dedupesBySeq() {
        let t = WorkEngineTranscript()
        t.ingest(eventJSON: ev(["type": "part.text.appended", "seq": 5, "partId": "p1", "partKind": "text", "text": "X"]))
        t.ingest(eventJSON: ev(["type": "part.text.appended", "seq": 5, "partId": "p1", "partKind": "text", "text": "X"]))
        #expect(t.answerText == "X") // not "XX"
    }

    @Test("thinking is separated from the answer (not dumped as answer prose)")
    func thinkingSeparate() {
        let t = WorkEngineTranscript()
        t.ingest(eventJSON: ev(["type": "part.text.appended", "seq": 1, "partId": "think", "partKind": "thinking", "text": "hmm"]))
        t.ingest(eventJSON: ev(["type": "part.text.appended", "seq": 2, "partId": "ans", "partKind": "text", "text": "answer"]))
        #expect(t.answerText == "answer")
        #expect(t.parts.contains { $0.kind == .thinking && $0.text == "hmm" })
    }

    @Test("run.started→running, run.finished reason idle→idle / error→error")
    func runStatus() {
        let t = WorkEngineTranscript()
        t.ingest(eventJSON: ev(["type": "run.started", "seq": 1]))
        #expect(t.status == .running)
        t.ingest(eventJSON: ev(["type": "run.finished", "seq": 2, "reason": "idle"]))
        #expect(t.status == .idle)
        t.ingest(eventJSON: ev(["type": "run.finished", "seq": 3, "reason": "error"]))
        #expect(t.status == .error)
    }

    @Test("tool lifecycle → a native tool card (name + status + output), not raw prose")
    func toolCard() {
        let t = WorkEngineTranscript()
        t.ingest(eventJSON: ev(["type": "tool.started", "seq": 1, "partId": "tA", "tool": "bash"]))
        t.ingest(eventJSON: ev(["type": "tool.output.appended", "seq": 2, "partId": "tA", "text": "ok"]))
        t.ingest(eventJSON: ev(["type": "tool.finished", "seq": 3, "partId": "tA", "status": "completed"]))
        let tool = t.parts.first { $0.kind == .tool }
        #expect(tool?.toolName == "bash")
        #expect(tool?.toolStatus == "completed")
        #expect(tool?.text == "ok")
        #expect(t.answerText.isEmpty) // tool output never leaks into the answer
    }

    @Test("post-run messages() merge attaches file diffs to the existing live tool card by partId")
    func mergesFileDiffsFromHistory() {
        let t = WorkEngineTranscript()
        t.ingest(eventJSON: ev(["type": "tool.started", "seq": 1, "partId": "tEdit", "tool": "edit"]))
        t.ingest(eventJSON: ev(["type": "tool.finished", "seq": 2, "partId": "tEdit", "status": "completed"]))

        let history = WorkSessionHistoryProjector.project(Data(#"""
        {"messages":{"messages":[{"info":{"role":"assistant"},"parts":[
          {"id":"tEdit","type":"tool","tool":"edit","state":{"status":"completed","output":"history output",
            "input":{"filePath":"/tmp/x.swift","oldString":"SECRET-OLD","newString":"SECRET-NEW"},
            "metadata":{"files":[{"diff":"--- a/x.swift\n+++ b/x.swift\n@@ -1 +1 @@\n-old\n+new"}]}}}
        ]}]}}
        """#.utf8))

        t.mergeFileDiffs(history: history)
        let tool = t.parts.first { $0.kind == .tool }
        #expect(tool?.fileDiffs.count == 1)
        #expect(tool?.fileDiffs.first?.contains("+new") == true)
        #expect(tool?.toolSummary == "/tmp/x.swift")
        #expect(tool?.text == "") // merge does not replay history output into the live card
        #expect(t.answerText.isEmpty)
    }

    @Test("post-run messages() merge ignores unrelated history tool parts")
    func ignoresUnmatchedFileDiffsFromHistory() {
        let t = WorkEngineTranscript()
        t.ingest(eventJSON: ev(["type": "tool.started", "seq": 1, "partId": "liveTool", "tool": "edit"]))

        let history = WorkSessionHistoryProjector.project(Data(#"""
        {"messages":{"messages":[{"parts":[
          {"id":"otherTool","type":"tool","tool":"edit","state":{"status":"completed",
            "metadata":{"files":[{"diff":"--- a/y.swift\n+++ b/y.swift\n@@ -1 +1 @@\n-a\n+b"}]}}}
        ]}]}}
        """#.utf8))

        t.mergeFileDiffs(history: history)
        #expect(t.parts.first { $0.id == "liveTool" }?.fileDiffs.isEmpty == true)
    }

    @Test("tool.input.updated → compact toolSummary on the card (started sets name first); content never leaks")
    func toolInputSummary() {
        let t = WorkEngineTranscript()
        t.ingest(eventJSON: ev(["type": "tool.started", "seq": 1, "partId": "tB", "tool": "bash"]))
        t.ingest(eventJSON: ev(["type": "tool.input.updated", "seq": 2, "partId": "tB", "input": ["command": "ls -la"]]))
        #expect(t.parts.first { $0.kind == .tool }?.toolSummary == "ls -la")
        // edit: only the filePath surfaces — oldString/newString (potentially huge) never reach the card
        let t2 = WorkEngineTranscript()
        t2.ingest(eventJSON: ev(["type": "tool.started", "seq": 1, "partId": "tE", "tool": "edit"]))
        t2.ingest(eventJSON: ev(["type": "tool.input.updated", "seq": 2, "partId": "tE",
                                 "input": ["filePath": "/a/b.swift", "oldString": "SEC", "newString": "RET"]]))
        let card = t2.parts.first { $0.kind == .tool }
        #expect(card?.toolSummary == "/a/b.swift")
        #expect(card?.toolSummary?.contains("SEC") == false)
    }

    @Test("out-of-order tool.input.updated stores only safe candidates and fills summary after tool.started")
    func outOfOrderToolInputSummary() {
        let t = WorkEngineTranscript()
        t.ingest(eventJSON: ev(["type": "tool.input.updated", "seq": 1, "partId": "lateTool",
                                "input": ["filePath": "/safe/file.swift", "content": "SECRET-BODY"]]))
        #expect(t.parts.first { $0.id == "lateTool" }?.toolSummary == nil)

        t.ingest(eventJSON: ev(["type": "tool.started", "seq": 2, "partId": "lateTool", "tool": "write"]))

        let card = t.parts.first { $0.id == "lateTool" }
        #expect(card?.toolSummary == "/safe/file.swift")
        #expect(card?.toolSummary?.contains("SECRET") == false)
    }

    @Test("session.error → native error part + status + lastError")
    func sessionError() {
        let t = WorkEngineTranscript()
        t.ingest(eventJSON: ev(["type": "session.error", "seq": 1, "message": "boom"]))
        #expect(t.status == .error)
        #expect(t.lastError == "boom")
        #expect(t.parts.contains { $0.kind == .error && $0.text == "boom" })
    }

    @Test("text/tool chunks without a partId or messageId are ignored instead of merging into a synthetic bucket")
    func unrouteableChunksIgnored() {
        let t = WorkEngineTranscript()
        t.ingest(eventJSON: ev(["type": "part.text.appended", "seq": 1, "partKind": "text", "text": "loose"]))
        t.ingest(eventJSON: ev(["type": "tool.started", "seq": 2, "tool": "bash"]))
        t.ingest(eventJSON: ev(["type": "tool.output.appended", "seq": 3, "text": "loose output"]))
        t.ingest(eventJSON: ev(["type": "tool.input.updated", "seq": 4, "input": ["command": "pwd"]]))
        #expect(t.parts.isEmpty)
        #expect(t.answerText.isEmpty)
    }

    @Test("huge streamed text is bounded with a visible marker and further appends do not expand it")
    func hugeStreamedTextBounded() {
        let t = WorkEngineTranscript()
        let huge = String(repeating: "x", count: WorkTranscriptBounds.maxPartCharacters + 50)
        t.ingest(eventJSON: ev(["type": "part.text.appended", "seq": 1, "partId": "pHuge",
                                "partKind": "text", "text": huge]))
        let bounded = t.parts.first?.text ?? ""
        #expect(bounded.count < huge.count)
        #expect(bounded.hasSuffix("[truncated]"))

        t.ingest(eventJSON: ev(["type": "part.text.appended", "seq": 2, "partId": "pHuge",
                                "partKind": "text", "text": "more"]))
        #expect(t.parts.first?.text == bounded)
    }

    @Test("live user message → .user part (NOT mislabeled as an assistant answer)")
    func liveUserMessageLabeled() {
        let t = WorkEngineTranscript()
        // The live stream echoes the user's own message (message.started role:user + its text part).
        t.ingest(eventJSON: ev(["type": "message.started", "seq": 1, "messageId": "mU", "role": "user"]))
        t.ingest(eventJSON: ev(["type": "part.text.appended", "seq": 2, "messageId": "mU", "partId": "pU", "partKind": "text", "text": "my prompt"]))
        // assistant reply follows
        t.ingest(eventJSON: ev(["type": "message.started", "seq": 3, "messageId": "mA", "role": "assistant"]))
        t.ingest(eventJSON: ev(["type": "part.text.appended", "seq": 4, "messageId": "mA", "partId": "pA", "partKind": "text", "text": "the answer"]))
        #expect(t.parts.contains { $0.kind == .user && $0.text == "my prompt" })
        #expect(t.answerText == "the answer")          // user prompt does NOT leak into the answer
        #expect(t.parts.filter { $0.kind == .user }.count == 1)
    }

    @Test("retro-relabel: a text part landing BEFORE its message.started(role:user) is fixed to .user")
    func liveUserMessageRetroRelabel() {
        let t = WorkEngineTranscript()
        // text part arrives first (role unknown) → provisionally .answer …
        t.ingest(eventJSON: ev(["type": "part.text.appended", "seq": 1, "messageId": "mU", "partId": "pU", "partKind": "text", "text": "hi there"]))
        #expect(t.parts.contains { $0.kind == .answer && $0.text == "hi there" })
        // … then message.started(role:user) arrives → the part is corrected to .user
        t.ingest(eventJSON: ev(["type": "message.started", "seq": 2, "messageId": "mU", "role": "user"]))
        #expect(t.parts.contains { $0.kind == .user && $0.text == "hi there" })
        #expect(t.answerText.isEmpty)
    }

    @Test("non-transcript events (part.started) produce NO parts — zero debris")
    func noDebris() {
        let t = WorkEngineTranscript()
        t.ingest(eventJSON: ev(["type": "message.started", "seq": 1, "role": "assistant"]))
        t.ingest(eventJSON: ev(["type": "part.started", "seq": 2, "partId": "p1", "partKind": "text"]))
        #expect(t.parts.isEmpty)
        t.ingest(eventJSON: ev(["type": "part.text.replaced", "seq": 3, "partId": "p1", "partKind": "text", "text": "final"]))
        #expect(t.answerText == "final")
        t.reset()
        #expect(t.parts.isEmpty && t.status == .idle && t.lastError == nil)
    }
}
