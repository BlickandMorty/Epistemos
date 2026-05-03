#if !EPISTEMOS_APP_STORE
import AXorcist
import Foundation
import Testing
@testable import Epistemos

@MainActor
@Suite("Phase4Bridge interact AgentEvent provenance")
struct Phase4BridgeInteractAgentEventTests {
    @Test("Phase4 interact computer route records sanitized requested started and completed events")
    func phase4InteractComputerRouteRecordsSanitizedRequestedStartedAndCompletedEvents() async throws {
        var captured: [AgentProvenanceEvent] = []
        var forwardedActionJSON: String?
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 882_000 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = Phase4Bridge(
            computerActionExecutor: { actionJSON in
                forwardedActionJSON = actionJSON
                return #"{"success":true,"message":"Typed Secret typed /Users/jojo"}"#
            },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.interact(
            actionJson: #"{"action":"type_text","text":"Secret typed /Users/jojo","app_name":"SecretApp","x":246,"y":864}"#
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(forwardedActionJSON?.contains("Secret typed") == true)
        #expect(responseJSON["success"] as? Bool == true)
        #expect((responseJSON["message"] as? String)?.contains("Secret typed") == true)
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallStarted, .toolCallCompleted])
        #expect(captured.map { $0.tool?.status } == [.requested, .started, .completed])
        #expect(captured.map(\.sequence) == [0, 1, 2])
        #expect(captured.allSatisfy { $0.runID == "phase4-interact" })
        #expect(captured.allSatisfy { $0.actor == .agent(id: "phase4-bridge", modelID: nil) })
        #expect(captured.allSatisfy { $0.tool?.toolName == "phase4.interact.type" })
        #expect(captured.allSatisfy { $0.tool?.toolCallID == "phase4-interact-0" })
        #expect(captured.allSatisfy { $0.metadata["source"] == "phase4_bridge" })
        #expect(captured.allSatisfy { $0.metadata["surface"] == "interact" })
        #expect(captured.allSatisfy { $0.metadata["action_class"] == "type" })
        #expect(captured.allSatisfy { $0.metadata["route_class"] == "computer_use" })
        #expect(captured.last?.metadata["result_class"] == "computer_input")

        let arguments = try Self.jsonObject(from: try #require(captured.first?.tool?.argumentsJSON))
        #expect(arguments["action_class"] as? String == "type")
        #expect(arguments["route_class"] as? String == "computer_use")
        #expect(arguments["text_length_bucket"] as? String == nil)
        #expect(arguments["value_length_bucket"] as? String == "17_64")
        #expect(arguments["coordinate_bucket"] as? String == "200-800")
        #expect(arguments["app_scope"] as? String == "specific")

        let result = try Self.jsonObject(from: try #require(captured.last?.tool?.resultJSON))
        #expect(result["success"] as? Bool == true)
        #expect(result["result_class"] as? String == "computer_input")

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in [
            "Secret typed",
            "SecretApp",
            "/Users/jojo",
            "type_text",
            "Typed Secret",
        ] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("Phase4 interact AX press records sanitized completed events")
    func phase4InteractAXPressRecordsSanitizedCompletedEvents() async throws {
        var captured: [AgentProvenanceEvent] = []
        var pressedBundleID: String?
        var pressedTarget: String?
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 882_500 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = Phase4Bridge(
            pressElementExecutor: { bundleID, target in
                pressedBundleID = bundleID
                pressedTarget = target
                return .success(payload: nil, logs: nil)
            },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.interact(
            actionJson: #"{"action":"press","bundle_id":"com.secret.private","target":"Destroy /Users/jojo"}"#
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(pressedBundleID == "com.secret.private")
        #expect(pressedTarget == "Destroy /Users/jojo")
        #expect(responseJSON["success"] as? Bool == true)
        #expect(responseJSON["target"] as? String == "Destroy /Users/jojo")
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallStarted, .toolCallCompleted])
        #expect(captured.allSatisfy { $0.tool?.toolName == "phase4.interact.press" })
        #expect(captured.allSatisfy { $0.metadata["route_class"] == "axorcist" })
        #expect(captured.last?.metadata["result_class"] == "ax_press")

        let arguments = try Self.jsonObject(from: try #require(captured.first?.tool?.argumentsJSON))
        #expect(arguments["action_class"] as? String == "press")
        #expect(arguments["route_class"] as? String == "axorcist")
        #expect(arguments["app_scope"] as? String == "specific")
        #expect(arguments["target_scope"] as? String == "specified")

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in [
            "com.secret.private",
            "Destroy",
            "/Users/jojo",
        ] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("Phase4 interact invalid and unsupported actions record bounded failed events")
    func phase4InteractInvalidAndUnsupportedActionsRecordBoundedFailedEvents() async throws {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 883_000 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = Phase4Bridge(agentProvenanceRecorder: recorder)

        let invalidResponse = await bridge.interact(actionJson: "not-json /Users/jojo")
        let unsupportedResponse = await bridge.interact(
            actionJson: #"{"action":"delete_everything /Users/jojo","bundle_id":"com.secret"}"#
        )

        #expect(try Self.jsonObject(from: invalidResponse)["error"] as? String == "invalid action JSON")
        #expect((try Self.jsonObject(from: unsupportedResponse)["error"] as? String)?
            .contains("unknown interact action") == true)
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallFailed, .toolCallRequested, .toolCallFailed])
        #expect(captured.map { $0.tool?.status } == [.requested, .failed, .requested, .failed])
        #expect(captured[0].tool?.toolName == "phase4.interact.invalid_json")
        #expect(captured[1].metadata["failure_class"] == "invalid_action_json")
        #expect(captured[2].tool?.toolName == "phase4.interact.unknown")
        #expect(captured[3].metadata["failure_class"] == "unsupported_action")

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in [
            "not-json",
            "delete_everything",
            "com.secret",
            "/Users/jojo",
            "unknown interact action",
        ] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("Phase4 interact source never stores raw action JSON target values or raw results")
    func phase4InteractSourceNeverStoresRawActionJSONTargetValuesOrRawResults() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Bridge/Phase4Bridge.swift")

        #expect(source.contains("recordPhase4InteractEvent"))
        #expect(source.contains(#""action_class""#))
        #expect(source.contains(#""route_class""#))
        #expect(source.contains(#""target_scope""#))
        #expect(source.contains(#""value_length_bucket""#))
        #expect(!source.contains("argumentsJSON: actionJson"))
        #expect(!source.contains("argumentsJSON: payload"))
        #expect(!source.contains("resultJSON: response"))
        #expect(!source.contains("resultJSON: jsonString"))
        #expect(!source.contains("errorMessage: errorJson"))
        #expect(!source.contains("errorMessage: errorMessage as? String"))
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
