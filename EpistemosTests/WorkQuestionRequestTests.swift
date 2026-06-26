import Foundation
import Testing
@testable import Epistemos

// Verifies WorkQuestionRequestDecoder against the OpenGUI HarnessEvent question shape ({type:"question.requested",
// request:{id,sessionID,questions:[{question,header,options:[{label,description?}],multiple?,custom?}],tool?}}) — the
// foundation of the native question-card feature. Pure + lenient: digs to the request; nil on missing id / no prompts.
@Suite("Work question request — decode (native question card)")
struct WorkQuestionRequestTests {
    private func data(_ s: String) -> Data { Data(s.utf8) }

    @Test("decodes the envelope: prompts, options+descriptions, multiple/custom flags, tool.callID")
    func decodesEnvelope() {
        let r = WorkQuestionRequestDecoder.decode(data(#"""
        {"type":"question.requested","request":{
          "id":"q1","harnessId":"codex","sessionID":"s","tool":{"messageID":"m","callID":"c1"},
          "questions":[{"question":"Pick a framework","header":"Framework","multiple":false,"custom":true,
            "options":[{"label":"SwiftUI","description":"native"},{"label":"AppKit"}]}]}}
        """#))
        #expect(r?.id == "q1")
        #expect(r?.harnessID == "codex")
        #expect(r?.toolCallID == "c1")
        #expect(r?.prompts.count == 1)
        let prompt = r?.prompts.first
        #expect(prompt?.question == "Pick a framework")
        #expect(prompt?.header == "Framework")
        #expect(prompt?.custom == true)
        #expect(prompt?.multiple == false)
        #expect(prompt?.options.map(\.label) == ["SwiftUI", "AppKit"])
        #expect(prompt?.options.first?.description == "native")
        #expect(prompt?.id == 0)   // index within the request (answer ordering)
    }

    @Test("decodes an {event:{request}} wrapper; prompt index increments")
    func decodesNested() {
        let r = WorkQuestionRequestDecoder.decode(data(
            #"{"event":{"type":"question.requested","request":{"id":"q2","harnessId":"claude-code","sessionID":"s","questions":[{"question":"a"},{"question":"b"}]}}}"#))
        #expect(r?.id == "q2")
        #expect(r?.harnessID == "claude-code")
        #expect(r?.sessionID == "s")
        #expect(r?.prompts.map(\.id) == [0, 1])
        #expect(r?.prompts.map(\.question) == ["a", "b"])
    }

    @Test("lenient: nil / malformed / missing id/session / empty prompts → nil")
    func lenient() {
        #expect(WorkQuestionRequestDecoder.decode(nil) == nil)
        #expect(WorkQuestionRequestDecoder.decode(data("nope")) == nil)
        #expect(WorkQuestionRequestDecoder.decode(data(#"{"request":{"sessionID":"s","questions":[{"question":"q"}]}}"#)) == nil) // no id
        #expect(WorkQuestionRequestDecoder.decode(data(#"{"request":{"id":"x","questions":[{"question":"q"}]}}"#)) == nil) // no session
        #expect(WorkQuestionRequestDecoder.decode(data(#"{"request":{"id":"x","sessionID":"","questions":[{"question":"q"}]}}"#)) == nil)
        #expect(WorkQuestionRequestDecoder.decode(data(#"{"request":{"id":"x","sessionID":"s","questions":[]}}"#)) == nil) // no prompts
    }

    @Test("source documents the live harness event bridge, not the dead per-session API")
    func documentsLiveHarnessEventBridge() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Work/WorkQuestionRequest.swift")
        #expect(src.contains(#"harness.on("event")"#))
        #expect(!src.contains("subscribeHarnessEvents"))
    }

    @Test("question card assembles multi-select answers in displayed option order")
    func questionCardPreservesDisplayedAnswerOrder() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Work/WorkQuestionCardView.swift")
        #expect(src.contains("let selected = selections[prompt.id] ?? []"))
        #expect(src.contains("prompt.options.map(\\.label).filter { selected.contains($0) }"))
        #expect(!src.contains("var answer = Array(selections[prompt.id] ?? [])"))
    }

    @Test("question card keeps compact stable ask controls")
    func questionCardControlsStayCompact() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Work/WorkQuestionCardView.swift")
        #expect(src.contains(#"Image(systemName: "questionmark.bubble")"#))
        #expect(src.contains(#"Image(systemName: "xmark")"#))
        #expect(src.contains(#".help("Skip question")"#))
        #expect(src.contains(".frame(width: 18, height: 18)"))
        #expect(src.contains(".frame(width: 14, height: 14)"))
        #expect(src.contains(".truncationMode(.tail)"))
    }
}
