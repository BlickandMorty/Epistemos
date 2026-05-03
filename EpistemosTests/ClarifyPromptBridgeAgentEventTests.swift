#if !EPISTEMOS_APP_STORE
import Foundation
import Testing
@testable import Epistemos

@MainActor
@Suite("ClarifyPromptBridge AgentEvent provenance")
struct ClarifyPromptBridgeAgentEventTests {
    @Test("Clarify free-form answer records sanitized requested started and completed events")
    func clarifyFreeFormAnswerRecordsSanitizedRequestedStartedAndCompletedEvents() async throws {
        var captured: [AgentProvenanceEvent] = []
        var presentedQuestion: String?
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 886_000 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = ClarifyPromptBridge(
            presenter: { prompt in
                presentedQuestion = prompt.question
                return ClarifyPromptAnswer(
                    response: "Secret free-form answer /Users/jojo",
                    choiceIndex: nil,
                    cancelled: false
                )
            },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.ask(
            questionJson: #"{"question":"What is your private API key /Users/jojo?"}"#
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(presentedQuestion == "What is your private API key /Users/jojo?")
        #expect(responseJSON["response"] as? String == "Secret free-form answer /Users/jojo")
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallStarted, .toolCallCompleted])
        #expect(captured.map { $0.tool?.status } == [.requested, .started, .completed])
        #expect(captured.map(\.sequence) == [0, 1, 2])
        #expect(captured.allSatisfy { $0.runID == "clarify-prompt" })
        #expect(captured.allSatisfy { $0.actor == .agent(id: "clarify-prompt-bridge", modelID: nil) })
        #expect(captured.allSatisfy { $0.tool?.toolName == "clarify.ask.freeform" })
        #expect(captured.allSatisfy { $0.tool?.toolCallID == "clarify-prompt-0" })
        #expect(captured.allSatisfy { $0.metadata["source"] == "clarify_prompt_bridge" })
        #expect(captured.allSatisfy { $0.metadata["surface"] == "clarify.ask" })
        #expect(captured.allSatisfy { $0.metadata["input_mode"] == "freeform" })
        #expect(captured.last?.metadata["result_class"] == "answered")

        let arguments = try Self.jsonObject(from: try #require(captured.first?.tool?.argumentsJSON))
        #expect(arguments["input_mode"] as? String == "freeform")
        #expect(arguments["question_scope"] as? String == "provided")
        #expect(arguments["choice_count_bucket"] as? String == "0")
        #expect(arguments["payload_class"] as? String == "valid_json")

        let result = try Self.jsonObject(from: try #require(captured.last?.tool?.resultJSON))
        #expect(result["answered"] as? Bool == true)
        #expect(result["cancelled"] as? Bool == false)
        #expect(result["response_length_bucket"] as? String == "17_64")

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in [
            "Secret free-form",
            "private API key",
            "/Users/jojo",
            "What is your",
        ] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("Clarify choice answer records selected index without raw choices")
    func clarifyChoiceAnswerRecordsSelectedIndexWithoutRawChoices() async throws {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 886_500 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = ClarifyPromptBridge(
            presenter: { prompt in
                #expect(prompt.choices == ["Personal Vault", "Work Vault"])
                return ClarifyPromptAnswer(
                    response: "Work Vault",
                    choiceIndex: 1,
                    cancelled: false
                )
            },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.ask(
            questionJson: #"{"question":"Pick a vault","choices":["Personal Vault","Work Vault"]}"#
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(responseJSON["response"] as? String == "Work Vault")
        #expect(responseJSON["choice_index"] as? Int == 1)
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallStarted, .toolCallCompleted])
        #expect(captured.allSatisfy { $0.tool?.toolName == "clarify.ask.choice" })

        let arguments = try Self.jsonObject(from: try #require(captured.first?.tool?.argumentsJSON))
        #expect(arguments["input_mode"] as? String == "choice")
        #expect(arguments["choice_count_bucket"] as? String == "2_3")

        let result = try Self.jsonObject(from: try #require(captured.last?.tool?.resultJSON))
        #expect(result["answered"] as? Bool == true)
        #expect(result["choice_index"] as? Int == 1)
        #expect(result["response_length_bucket"] as? String == "6_16")

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in [
            "Personal Vault",
            "Work Vault",
            "Pick a vault",
        ] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("Clarify invalid JSON and cancelled answer remain bounded")
    func clarifyInvalidJSONAndCancelledAnswerRemainBounded() async throws {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 887_000 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = ClarifyPromptBridge(
            presenter: { _ in
                ClarifyPromptAnswer(response: "", choiceIndex: nil, cancelled: true)
            },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.ask(questionJson: "not-json /Users/jojo")
        let responseJSON = try Self.jsonObject(from: response)

        #expect(responseJSON["response"] as? String == "")
        #expect(responseJSON["cancelled"] as? Bool == true)
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallStarted, .toolCallCompleted])
        #expect(captured.last?.metadata["result_class"] == "cancelled")

        let arguments = try Self.jsonObject(from: try #require(captured.first?.tool?.argumentsJSON))
        #expect(arguments["payload_class"] as? String == "invalid_json")
        #expect(arguments["question_scope"] as? String == "empty")

        let result = try Self.jsonObject(from: try #require(captured.last?.tool?.resultJSON))
        #expect(result["answered"] as? Bool == false)
        #expect(result["cancelled"] as? Bool == true)

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in [
            "not-json",
            "/Users/jojo",
        ] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("Clarify source never stores raw question JSON answers or choices")
    func clarifySourceNeverStoresRawQuestionJSONAnswersOrChoices() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Bridge/ClarifyPromptBridge.swift")

        #expect(source.contains("recordClarifyPromptEvent"))
        #expect(source.contains(#""input_mode""#))
        #expect(source.contains(#""question_scope""#))
        #expect(source.contains(#""response_length_bucket""#))
        #expect(!source.contains("argumentsJSON: questionJson"))
        #expect(!source.contains("argumentsJSON: parsed.question"))
        #expect(!source.contains("resultJSON: response"))
        #expect(!source.contains("resultJSON: answer.response"))
        #expect(!source.contains("errorMessage: error"))
    }

    private static func jsonObject(from response: String) throws -> [String: Any] {
        let data = try #require(response.data(using: .utf8))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func encodedEvents(_ events: [AgentProvenanceEvent]) throws -> String {
        let data = try JSONEncoder().encode(events)
        return try #require(String(data: data, encoding: .utf8))
    }
}
#endif
