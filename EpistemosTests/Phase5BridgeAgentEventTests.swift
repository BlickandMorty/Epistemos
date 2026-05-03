import Foundation
import Testing
@testable import Epistemos

@MainActor
@Suite("Phase5Bridge AgentEvent provenance")
struct Phase5BridgeAgentEventTests {
    @Test("Phase5 SSM total size records sanitized requested started and completed events")
    func phase5SsmTotalSizeRecordsSanitizedRequestedStartedAndCompletedEvents() async throws {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 512_000 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let service = SSMStateService(stateRoot: Self.tempStateRoot())
        let bridge = Phase5Bridge(
            ssmStateServiceProvider: { service },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.manageSsmState(
            actionJson: #"{"action":"total_size","model_id":"/Users/jojo/PrivateModel"}"#
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(responseJSON["success"] as? Bool == true)
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallStarted, .toolCallCompleted])
        #expect(captured.map { $0.tool?.status } == [.requested, .started, .completed])
        #expect(captured.allSatisfy { $0.runID == "phase5-ssm-state" })
        #expect(captured.allSatisfy { $0.actor == .agent(id: "phase5-bridge", modelID: nil) })
        #expect(captured.allSatisfy { $0.tool?.toolName == "ssm_state_manage" })
        #expect(captured.allSatisfy { $0.tool?.toolCallID == "phase5-ssm-state-0" })
        #expect(captured.allSatisfy { $0.metadata["action_class"] == "total_size" })
        #expect(captured.allSatisfy { $0.metadata["model_scope"] == "specific" })
        #expect(captured.last?.metadata["result"] == "completed")

        let arguments = try Self.jsonObject(from: try #require(captured.first?.tool?.argumentsJSON))
        #expect(arguments["action_class"] as? String == "total_size")
        #expect(arguments["model_scope"] as? String == "specific")

        let result = try Self.jsonObject(from: try #require(captured.last?.tool?.resultJSON))
        #expect(result["action_class"] as? String == "total_size")
        #expect(result["success"] as? Bool == true)
        #expect(result["bytes"] as? Int == 0)

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in ["/Users/jojo", "PrivateModel"] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("Phase5 SSM unsupported actions record sanitized failed events")
    func phase5SsmUnsupportedActionsRecordSanitizedFailedEvents() async throws {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 512_500 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let service = SSMStateService(stateRoot: Self.tempStateRoot())
        let bridge = Phase5Bridge(
            ssmStateServiceProvider: { service },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.manageSsmState(
            actionJson: #"{"action":"save","model_id":"/Users/jojo/PrivateModel","state_path":"/Users/jojo/cache.safetensors"}"#
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(responseJSON["success"] as? Bool == false)
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallFailed])
        #expect(captured.map { $0.tool?.status } == [.requested, .failed])
        #expect(captured.allSatisfy { $0.metadata["action_class"] == "save" })
        #expect(captured.last?.metadata["failure_class"] == "live_cache_action_unavailable")
        #expect(captured.last?.tool?.errorMessage == "SSM action was not accepted.")

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in ["/Users/jojo", "PrivateModel", "cache.safetensors", "state_path"] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("Phase5 SSM service unavailable records bounded bootstrap failure")
    func phase5SsmServiceUnavailableRecordsBoundedBootstrapFailure() async throws {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 513_000 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = Phase5Bridge(
            ssmStateServiceProvider: { nil },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.manageSsmState(
            actionJson: #"{"action":"list","model_id":"/Users/jojo/PrivateModel"}"#
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(responseJSON["success"] as? Bool == false)
        #expect(responseJSON["error"] as? String == "AppBootstrap is not initialised")
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallFailed])
        #expect(captured.last?.metadata["failure_class"] == "bootstrap_unavailable")
        #expect(captured.last?.tool?.errorMessage == "SSM action could not be started.")

        let encodedEvents = try Self.encodedEvents(captured)
        #expect(!encodedEvents.contains("AppBootstrap is not initialised"))
        #expect(!encodedEvents.contains("/Users/jojo"))
        #expect(!encodedEvents.contains("PrivateModel"))
    }

    @Test("Phase5 SSM invalid JSON records bounded failed events")
    func phase5SsmInvalidJSONRecordsBoundedFailedEvents() async throws {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 513_500 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let service = SSMStateService(stateRoot: Self.tempStateRoot())
        let bridge = Phase5Bridge(
            ssmStateServiceProvider: { service },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.manageSsmState(
            actionJson: #"{"action":"list","model_id":"/Users/jojo/PrivateModel""#
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(responseJSON["success"] as? Bool == false)
        #expect(responseJSON["error"] as? String == "invalid SSM action JSON")
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallFailed])
        #expect(captured.allSatisfy { $0.metadata["action_class"] == "invalid_json" })
        #expect(captured.last?.metadata["failure_class"] == "invalid_action_json")

        let encodedEvents = try Self.encodedEvents(captured)
        #expect(!encodedEvents.contains("/Users/jojo"))
        #expect(!encodedEvents.contains("PrivateModel"))
    }

    private static func tempStateRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-phase5-ssm-\(UUID().uuidString)", isDirectory: true)
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
