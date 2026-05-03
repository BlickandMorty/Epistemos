import Foundation
import Testing
@testable import Epistemos

@Suite("MCPBridge AgentEvent provenance")
@MainActor
struct MCPBridgeAgentEventTests {
    @Test("Core policy denied tools call records sanitized requested and denied events")
    func corePolicyDeniedToolsCallRecordsSanitizedRequestedAndDeniedEvents() throws {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 123_456 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = MCPBridge(agentProvenanceRecorder: recorder)
        let request = """
        {"jsonrpc":"2.0","method":"tools/call","params":{"name":"run_command","arguments":{"command":"rm -rf /Users/jojo/secret","path":"/Users/jojo/PrivateVault.md","prompt":"leak-me"}},"id":"secret-request-id"}
        """

        let response = bridge.dispatch(request, distribution: .coreAppStore)
        let responseJSON = try Self.jsonObject(from: response)
        let error = try #require(responseJSON["error"] as? [String: Any])

        #expect(error["code"] as? Int == -32601)
        #expect(error["message"] as? String == "Tool not found: run_command")
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallDenied])
        #expect(captured.map { $0.tool?.status } == [.requested, .denied])
        #expect(captured.map(\.sequence) == [0, 1])
        #expect(captured.allSatisfy { $0.runID == "mcp-bridge-policy-gate" })
        #expect(captured.allSatisfy { $0.actor == .system })
        #expect(captured.allSatisfy { $0.tool?.toolName == "run_command" })
        #expect(captured.allSatisfy { $0.tool?.toolCallID == "mcp-policy-denial-0" })
        #expect(captured.allSatisfy { $0.tool?.argumentsJSON == #"{"method":"tools/call","policy_gate":"tool_surface"}"# })
        #expect(captured.allSatisfy { $0.tool?.resultJSON == nil })
        #expect(captured.last?.tool?.errorMessage == "Tool is not surfaced for this distribution.")
        #expect(captured.allSatisfy { $0.metadata["source"] == "mcp_bridge_policy_gate" })
        #expect(captured.allSatisfy { $0.metadata["distribution"] == "core_app_store" })
        #expect(captured.allSatisfy { $0.metadata["method"] == "tools/call" })

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in [
            "rm -rf",
            "/Users/jojo",
            "PrivateVault.md",
            "leak-me",
            "secret-request-id",
        ] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("Core safe and Pro tool calls do not emit policy denial provenance")
    func coreSafeAndProToolCallsDoNotEmitPolicyDenialProvenance() {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 123_456 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = MCPBridge(agentProvenanceRecorder: recorder)

        _ = bridge.dispatch(
            #"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"read_file","arguments":{"path":"/tmp/test"}},"id":1}"#,
            distribution: .coreAppStore
        )
        _ = bridge.dispatch(
            #"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"run_command","arguments":{"command":"echo ok"}},"id":2}"#,
            distribution: .proResearch
        )

        #expect(captured.isEmpty)
    }

    @Test("MCPBridge policy provenance source avoids raw JSON RPC payload persistence")
    func mcpBridgePolicyProvenanceSourceAvoidsRawJSONRPCPayloadPersistence() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Omega/MCPBridge.swift")

        #expect(source.contains("recordToolCallPolicyDenial"))
        #expect(source.contains(#""policy_gate":"tool_surface""#))
        #expect(!source.contains("argumentsJSON: requestJson"))
        #expect(!source.contains("resultJSON: gateResponse"))
        #expect(!source.contains(#"params["arguments"]"#))
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
