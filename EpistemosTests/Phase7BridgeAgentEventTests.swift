import Foundation
import Testing
@testable import Epistemos

@MainActor
@Suite("Phase7Bridge AgentEvent provenance")
struct Phase7BridgeAgentEventTests {
    @Test("Unsupported NightBrain jobs record sanitized requested and failed events before bootstrap lookup")
    func unsupportedNightBrainJobsRecordSanitizedRequestedAndFailedEventsBeforeBootstrapLookup() async throws {
        var captured: [AgentProvenanceEvent] = []
        var bootstrapRequested = false
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 456_000 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = Phase7Bridge(
            bootstrapProvider: {
                bootstrapRequested = true
                return nil
            },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.triggerNightbrainJob(
            jobType: "vault_integrity_check",
            priority: "urgent /Users/jojo/PrivateVault.md"
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(responseJSON["success"] as? Bool == false)
        #expect(responseJSON["error"] as? String == "job_type vault_integrity_check is not implemented by NightBrainService")
        #expect(!bootstrapRequested)
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallFailed])
        #expect(captured.map { $0.tool?.status } == [.requested, .failed])
        #expect(captured.map(\.sequence) == [0, 1])
        #expect(captured.allSatisfy { $0.runID == "phase7-nightbrain-trigger" })
        #expect(captured.allSatisfy { $0.actor == .agent(id: "phase7-bridge", modelID: nil) })
        #expect(captured.allSatisfy { $0.tool?.toolName == "nightbrain_trigger" })
        #expect(captured.allSatisfy { $0.tool?.toolCallID == "phase7-nightbrain-trigger-0" })
        #expect(captured.allSatisfy { $0.tool?.resultJSON == nil })
        #expect(captured.last?.tool?.errorMessage == "NightBrain job was not accepted.")
        #expect(captured.allSatisfy { $0.metadata["source"] == "phase7_bridge" })
        #expect(captured.allSatisfy { $0.metadata["surface"] == "nightbrain_trigger" })
        #expect(captured.allSatisfy { $0.metadata["requested_job_supported"] == "false" })
        #expect(captured.last?.metadata["failure_class"] == "unsupported_job_type")

        let arguments = try Self.jsonObject(from: try #require(captured.first?.tool?.argumentsJSON))
        #expect(arguments["priority_class"] as? String == "unknown")
        #expect(arguments["requested_job_supported"] as? Bool == false)
        #expect(arguments["job"] == nil)

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in [
            "vault_integrity_check",
            "/Users/jojo",
            "PrivateVault.md",
        ] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("Supported NightBrain job without AppBootstrap records bounded bootstrap failure")
    func supportedNightBrainJobWithoutAppBootstrapRecordsBoundedBootstrapFailure() async throws {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 456_500 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = Phase7Bridge(
            bootstrapProvider: { nil },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.triggerNightbrainJob(
            jobType: "maintenance_log",
            priority: "normal"
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(responseJSON["success"] as? Bool == false)
        #expect(responseJSON["error"] as? String == "AppBootstrap is not initialised")
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallFailed])
        #expect(captured.map { $0.tool?.status } == [.requested, .failed])
        #expect(captured.allSatisfy { $0.tool?.toolCallID == "phase7-nightbrain-trigger-0" })
        #expect(captured.allSatisfy { $0.metadata["job"] == "maintenance_log" })
        #expect(captured.allSatisfy { $0.metadata["priority_class"] == "normal" })
        #expect(captured.allSatisfy { $0.metadata["requested_job_supported"] == "true" })
        #expect(captured.last?.metadata["failure_class"] == "bootstrap_unavailable")
        #expect(captured.last?.tool?.errorMessage == "NightBrain job could not be started.")

        let arguments = try Self.jsonObject(from: try #require(captured.first?.tool?.argumentsJSON))
        #expect(arguments["job"] as? String == "maintenance_log")
        #expect(arguments["priority_class"] as? String == "normal")
        #expect(arguments["requested_job_supported"] as? Bool == true)

        let encodedEvents = try Self.encodedEvents(captured)
        #expect(!encodedEvents.contains("AppBootstrap is not initialised"))
    }

    @Test("Phase7Bridge provenance source does not persist raw NightBrain request strings")
    func phase7BridgeProvenanceSourceDoesNotPersistRawNightBrainRequestStrings() async throws {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 457_000 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = Phase7Bridge(
            bootstrapProvider: { nil },
            agentProvenanceRecorder: recorder
        )

        _ = await bridge.triggerNightbrainJob(
            jobType: "unknown_job_/Users/jojo/SecretPlan.md",
            priority: "run-now /Users/jojo/PrivateVault.md"
        )

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in [
            "unknown_job_",
            "run-now",
            "/Users/jojo",
            "SecretPlan.md",
            "PrivateVault.md",
        ] {
            #expect(!encodedEvents.contains(forbidden))
        }
        #expect(captured.last?.metadata["failure_class"] == "unsupported_job_type")
    }

    @Test("Existing Phase7 job aliases stay intact")
    func existingPhase7JobAliasesStayIntact() {
        #expect(Phase7Bridge.supportedJobAliases["vault_integrity_check"] == nil)
        #expect(Phase7Bridge.supportedJobAliases["maintenance_log"] == .maintenanceLog)
        #expect(Phase7Bridge.supportedJobAliases["event_checkpoint"] == .eventStoreCheckpointVacuum)
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
