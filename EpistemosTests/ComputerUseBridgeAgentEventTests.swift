#if !EPISTEMOS_APP_STORE
import Foundation
import Testing
@testable import Epistemos

@MainActor
@Suite("ComputerUseBridge AgentEvent provenance")
struct ComputerUseBridgeAgentEventTests {
    @Test("Trusted computer actions record sanitized requested started and completed events")
    func trustedComputerActionsRecordSanitizedRequestedStartedAndCompletedEvents() async throws {
        var captured: [AgentProvenanceEvent] = []
        var executedAction: String?
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 777_000 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = ComputerUseBridge(
            accessibilityPermissionProvider: { true },
            trustedActionExecutor: { action, _ in
                executedAction = action
                return #"{"success":true,"message":"Typed 31 characters"}"#
            },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.execute(
            actionJSON: #"{"action":"type_text","text":"secret /Users/jojo/PrivateVault.md","x":1234,"y":987}"#
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(responseJSON["success"] as? Bool == true)
        #expect(executedAction == "type_text")
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallStarted, .toolCallCompleted])
        #expect(captured.map { $0.tool?.status } == [.requested, .started, .completed])
        #expect(captured.map(\.sequence) == [0, 1, 2])
        #expect(captured.allSatisfy { $0.runID == "computer-use-bridge" })
        #expect(captured.allSatisfy { $0.actor == .agent(id: "computer-use-bridge", modelID: nil) })
        #expect(captured.allSatisfy { $0.tool?.toolName == "computer.type" })
        #expect(captured.allSatisfy { $0.tool?.toolCallID == "computer-use-bridge-0" })
        #expect(captured.allSatisfy { $0.metadata["source"] == "computer_use_bridge" })
        #expect(captured.allSatisfy { $0.metadata["surface"] == "computer_use" })
        #expect(captured.allSatisfy { $0.metadata["action_class"] == "type" })
        #expect(captured.last?.metadata["result_class"] == "input_action")

        let arguments = try Self.jsonObject(from: try #require(captured.first?.tool?.argumentsJSON))
        #expect(arguments["action_class"] as? String == "type")
        #expect(arguments["text_length_bucket"] as? String == "17_64")
        #expect(arguments["coordinate_bucket"] as? String == "1200-900")

        let result = try Self.jsonObject(from: try #require(captured.last?.tool?.resultJSON))
        #expect(result["success"] as? Bool == true)
        #expect(result["result_class"] as? String == "input_action")
        #expect(result["screenshot_included"] as? Bool == false)

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in [
            "secret",
            "/Users/jojo",
            "PrivateVault.md",
            "Typed 31 characters",
        ] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("Accessibility denial records sanitized requested and failed events before action execution")
    func accessibilityDenialRecordsSanitizedRequestedAndFailedEventsBeforeActionExecution() async throws {
        var captured: [AgentProvenanceEvent] = []
        var actionExecuted = false
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 777_500 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = ComputerUseBridge(
            accessibilityPermissionProvider: { false },
            trustedActionExecutor: { _, _ in
                actionExecuted = true
                return #"{"success":true}"#
            },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.execute(
            actionJSON: #"{"action":"screenshot","text":"should-not-execute","app_name":"SecretApp"}"#
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(responseJSON["success"] as? Bool == false)
        #expect(actionExecuted == false)
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallFailed])
        #expect(captured.map { $0.tool?.status } == [.requested, .failed])
        #expect(captured.allSatisfy { $0.tool?.toolName == "computer.screenshot" })
        #expect(captured.last?.metadata["failure_class"] == "accessibility_permission_denied")
        #expect(captured.last?.tool?.errorMessage == "Computer action requires Accessibility permission.")

        let arguments = try Self.jsonObject(from: try #require(captured.first?.tool?.argumentsJSON))
        #expect(arguments["action_class"] as? String == "screenshot")
        #expect(arguments["app_scope"] as? String == "specific")

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in [
            "should-not-execute",
            "SecretApp",
            "Accessibility permission not granted",
        ] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("Invalid computer action JSON records bounded failed events")
    func invalidComputerActionJSONRecordsBoundedFailedEvents() async throws {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 778_000 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = ComputerUseBridge(
            accessibilityPermissionProvider: { true },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.execute(
            actionJSON: #"{"action":"type_text","text":"/Users/jojo/Secret""#
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(responseJSON["success"] as? Bool == false)
        #expect(responseJSON["error"] as? String == "Invalid action JSON")
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallFailed])
        #expect(captured.allSatisfy { $0.tool?.toolName == "computer.invalid_json" })
        #expect(captured.allSatisfy { $0.metadata["action_class"] == "invalid_json" })
        #expect(captured.last?.metadata["failure_class"] == "invalid_action_json")

        let encodedEvents = try Self.encodedEvents(captured)
        #expect(!encodedEvents.contains("/Users/jojo"))
        #expect(!encodedEvents.contains("Secret"))
    }

    @Test("Unknown computer actions do not persist raw action names")
    func unknownComputerActionsDoNotPersistRawActionNames() async throws {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 778_500 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = ComputerUseBridge(
            accessibilityPermissionProvider: { true },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.execute(
            actionJSON: #"{"action":"steal_private_screen_/Users/jojo","text":"raw key sequence"}"#
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(responseJSON["success"] as? Bool == false)
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallStarted, .toolCallFailed])
        #expect(captured.allSatisfy { $0.tool?.toolName == "computer.unknown" })
        #expect(captured.last?.metadata["failure_class"] == "unsupported_action")

        let arguments = try Self.jsonObject(from: try #require(captured.first?.tool?.argumentsJSON))
        #expect(arguments["action_class"] as? String == "unknown")
        #expect(arguments["text_length_bucket"] as? String == "1_16")

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in [
            "steal_private_screen",
            "/Users/jojo",
            "raw key sequence",
        ] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("ComputerUseBridge provenance source never stores raw action payloads or raw results")
    func computerUseBridgeProvenanceSourceNeverStoresRawActionPayloadsOrRawResults() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Bridge/ComputerUseBridge.swift")

        #expect(source.contains("recordComputerActionEvent"))
        #expect(source.contains(#""action_class""#))
        #expect(source.contains(#""coordinate_bucket""#))
        #expect(source.contains(#""text_length_bucket""#))
        #expect(source.contains("parseComputerActionResult"))
        #expect(!source.contains("argumentsJSON: actionJSON"))
        #expect(!source.contains("argumentsJSON: input"))
        #expect(!source.contains("resultJSON: result,"))
        #expect(!source.contains("errorMessage: errorResult"))
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
