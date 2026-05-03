#if !EPISTEMOS_APP_STORE
import Foundation
import Testing
@testable import Epistemos

@MainActor
@Suite("Phase4Bridge screen_watch AgentEvent provenance")
struct Phase4BridgeScreenWatchAgentEventTests {
    @Test("Phase4 screen watch timeout records sanitized requested started and completed events")
    func phase4ScreenWatchTimeoutRecordsSanitizedRequestedStartedAndCompletedEvents() async throws {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 884_000 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = Phase4Bridge(
            watchSleeper: { _ in },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.startScreenWatch(
            watchJson: #"{"mode":"timeout_ms","timeout_secs":0,"poll_interval_ms":1}"#
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(responseJSON["triggered"] as? Bool == true)
        #expect(responseJSON["mode"] as? String == "timeout_ms")
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallStarted, .toolCallCompleted])
        #expect(captured.map { $0.tool?.status } == [.requested, .started, .completed])
        #expect(captured.allSatisfy { $0.runID == "phase4-screen-watch" })
        #expect(captured.allSatisfy { $0.actor == .agent(id: "phase4-bridge", modelID: nil) })
        #expect(captured.allSatisfy { $0.tool?.toolName == "phase4.screen_watch.timeout" })
        #expect(captured.allSatisfy { $0.tool?.toolCallID == "phase4-screen-watch-0" })
        #expect(captured.allSatisfy { $0.metadata["source"] == "phase4_bridge" })
        #expect(captured.allSatisfy { $0.metadata["surface"] == "screen_watch" })
        #expect(captured.allSatisfy { $0.metadata["mode_class"] == "timeout" })
        #expect(captured.last?.metadata["reason_class"] == "elapsed")

        let arguments = try Self.jsonObject(from: try #require(captured.first?.tool?.argumentsJSON))
        #expect(arguments["mode_class"] as? String == "timeout")
        #expect(arguments["timeout_bucket"] as? String == "0")
        #expect(arguments["poll_interval_bucket"] as? String == "1_100")

        let result = try Self.jsonObject(from: try #require(captured.last?.tool?.resultJSON))
        #expect(result["triggered"] as? Bool == true)
        #expect(result["reason_class"] as? String == "elapsed")
    }

    @Test("Phase4 screen watch file exists records target-scope without path")
    func phase4ScreenWatchFileExistsRecordsTargetScopeWithoutPath() async throws {
        var captured: [AgentProvenanceEvent] = []
        var checkedPath: String?
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 884_500 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = Phase4Bridge(
            fileExistsProvider: { path in
                checkedPath = path
                return true
            },
            watchSleeper: { _ in },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.startScreenWatch(
            watchJson: #"{"mode":"file_exists","target":"/Users/jojo/PrivateVault.md","timeout_secs":5,"poll_interval_ms":250}"#
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(checkedPath == "/Users/jojo/PrivateVault.md")
        #expect(responseJSON["triggered"] as? Bool == true)
        #expect(responseJSON["mode"] as? String == "file_exists")
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallStarted, .toolCallCompleted])
        #expect(captured.allSatisfy { $0.tool?.toolName == "phase4.screen_watch.file_exists" })
        #expect(captured.allSatisfy { $0.metadata["mode_class"] == "file_exists" })
        #expect(captured.last?.metadata["reason_class"] == "condition_met")

        let arguments = try Self.jsonObject(from: try #require(captured.first?.tool?.argumentsJSON))
        #expect(arguments["mode_class"] as? String == "file_exists")
        #expect(arguments["target_scope"] as? String == "specified")
        #expect(arguments["timeout_bucket"] as? String == "1_5")
        #expect(arguments["poll_interval_bucket"] as? String == "101_500")

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in [
            "/Users/jojo",
            "PrivateVault.md",
        ] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("Phase4 screen watch invalid JSON records bounded failed event")
    func phase4ScreenWatchInvalidJSONRecordsBoundedFailedEvent() async throws {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 885_000 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = Phase4Bridge(agentProvenanceRecorder: recorder)

        let response = await bridge.startScreenWatch(watchJson: "not-json /Users/jojo")
        let responseJSON = try Self.jsonObject(from: response)

        #expect(responseJSON["success"] as? Bool == false)
        #expect(responseJSON["error"] as? String == "invalid watch JSON")
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallFailed])
        #expect(captured.map { $0.tool?.status } == [.requested, .failed])
        #expect(captured.allSatisfy { $0.tool?.toolName == "phase4.screen_watch.invalid_json" })
        #expect(captured.last?.metadata["failure_class"] == "invalid_watch_json")

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in [
            "not-json",
            "/Users/jojo",
            "invalid watch JSON",
        ] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("Phase4 screen watch source never stores raw watch JSON paths")
    func phase4ScreenWatchSourceNeverStoresRawWatchJSONPaths() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Bridge/Phase4Bridge.swift")

        #expect(source.contains("recordPhase4ScreenWatchEvent"))
        #expect(source.contains(#""mode_class""#))
        #expect(source.contains(#""timeout_bucket""#))
        #expect(source.contains(#""poll_interval_bucket""#))
        #expect(source.contains(#""target_scope""#))
        #expect(!source.contains("argumentsJSON: watchJson"))
        #expect(!source.contains("argumentsJSON: payload"))
        #expect(!source.contains("resultJSON: response"))
        #expect(!source.contains("resultJSON: jsonString"))
        #expect(!source.contains("errorMessage: errorJson"))
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
