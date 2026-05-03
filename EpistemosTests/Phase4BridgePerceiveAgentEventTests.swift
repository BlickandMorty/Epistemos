#if !EPISTEMOS_APP_STORE
import Foundation
import Testing
@testable import Epistemos

@MainActor
@Suite("Phase4Bridge perceive AgentEvent provenance")
struct Phase4BridgePerceiveAgentEventTests {
    @Test("Phase4 perceive records sanitized requested started and completed events")
    func phase4PerceiveRecordsSanitizedRequestedStartedAndCompletedEvents() async throws {
        var captured: [AgentProvenanceEvent] = []
        var perceivedAppName: String?
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 881_000 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = Phase4Bridge(
            perceptionProvider: { appName in
                perceivedAppName = appName
                return PerceptionResult(
                    axTreeJson: #"{"role":"window","text":"Secret AX /Users/jojo"}"#,
                    interactiveCount: 7,
                    method: .axPlusVisionOCR,
                    latencyMs: 12.4,
                    ocrTexts: [
                        OCRTextRegion(
                            text: "Secret OCR /Users/jojo/PrivateVault.md",
                            confidence: 0.98,
                            normalizedBounds: NormalizedRect(
                                x: 0.1,
                                y: 0.2,
                                width: 0.3,
                                height: 0.4
                            )
                        ),
                    ]
                )
            },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.perceive(
            appName: "SecretApp /Users/jojo",
            depth: "full"
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(perceivedAppName == "SecretApp /Users/jojo")
        #expect(responseJSON["interactive_count"] as? Int == 7)
        #expect(responseJSON["ocr_count"] as? Int == 1)
        #expect((responseJSON["ax_tree_json"] as? String)?.contains("Secret AX") == true)
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallStarted, .toolCallCompleted])
        #expect(captured.map { $0.tool?.status } == [.requested, .started, .completed])
        #expect(captured.map(\.sequence) == [0, 1, 2])
        #expect(captured.allSatisfy { $0.runID == "phase4-perceive" })
        #expect(captured.allSatisfy { $0.actor == .agent(id: "phase4-bridge", modelID: nil) })
        #expect(captured.allSatisfy { $0.tool?.toolName == "phase4.perceive" })
        #expect(captured.allSatisfy { $0.tool?.toolCallID == "phase4-perceive-0" })
        #expect(captured.allSatisfy { $0.metadata["source"] == "phase4_bridge" })
        #expect(captured.allSatisfy { $0.metadata["surface"] == "perceive" })
        #expect(captured.allSatisfy { $0.metadata["depth_class"] == "full" })
        #expect(captured.allSatisfy { $0.metadata["app_scope"] == "specific" })
        #expect(captured.last?.metadata["method"] == "AX+VisionOCR")

        let arguments = try Self.jsonObject(from: try #require(captured.first?.tool?.argumentsJSON))
        #expect(arguments["depth_class"] as? String == "full")
        #expect(arguments["app_scope"] as? String == "specific")

        let result = try Self.jsonObject(from: try #require(captured.last?.tool?.resultJSON))
        #expect(result["success"] as? Bool == true)
        #expect(result["method"] as? String == "AX+VisionOCR")
        #expect(result["interactive_count"] as? Int == 7)
        #expect(result["ocr_count"] as? Int == 1)
        #expect(result["latency_ms"] as? Int == 12)

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in [
            "SecretApp",
            "Secret AX",
            "Secret OCR",
            "/Users/jojo",
            "PrivateVault.md",
            "ax_tree_json",
        ] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("Phase4 perceive unavailable records bounded failed events")
    func phase4PerceiveUnavailableRecordsBoundedFailedEvents() async throws {
        var captured: [AgentProvenanceEvent] = []
        let recorder = AgentToolProvenanceRecorder(
            nowMilliseconds: { 881_500 },
            persist: { event in
                captured.append(event)
                return true
            }
        )
        let bridge = Phase4Bridge(
            perceptionProvider: { _ in nil },
            agentProvenanceRecorder: recorder
        )

        let response = await bridge.perceive(
            appName: "MissingApp /Users/jojo",
            depth: "full /Users/jojo"
        )
        let responseJSON = try Self.jsonObject(from: response)

        #expect(responseJSON["success"] as? Bool == false)
        #expect(responseJSON["error"] as? String == "Screen2AXFusion is not initialised")
        #expect(captured.map(\.kind) == [.toolCallRequested, .toolCallStarted, .toolCallFailed])
        #expect(captured.map { $0.tool?.status } == [.requested, .started, .failed])
        #expect(captured.allSatisfy { $0.tool?.toolName == "phase4.perceive" })
        #expect(captured.allSatisfy { $0.metadata["depth_class"] == "unknown" })
        #expect(captured.last?.metadata["failure_class"] == "perception_unavailable")
        #expect(captured.last?.tool?.errorMessage == "Phase4 perceive could not start.")

        let arguments = try Self.jsonObject(from: try #require(captured.first?.tool?.argumentsJSON))
        #expect(arguments["depth_class"] as? String == "unknown")
        #expect(arguments["app_scope"] as? String == "specific")

        let encodedEvents = try Self.encodedEvents(captured)
        for forbidden in [
            "MissingApp",
            "/Users/jojo",
            "Screen2AXFusion is not initialised",
        ] {
            #expect(!encodedEvents.contains(forbidden))
        }
    }

    @Test("Phase4 perceive source never stores AX tree OCR text app names or raw results")
    func phase4PerceiveSourceNeverStoresAXTreeOCRTextAppNamesOrRawResults() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Bridge/Phase4Bridge.swift")

        #expect(source.contains("recordPhase4PerceiveEvent"))
        #expect(source.contains(#""depth_class""#))
        #expect(source.contains(#""app_scope""#))
        #expect(source.contains(#""interactive_count""#))
        #expect(source.contains(#""ocr_count""#))
        #expect(!source.contains("argumentsJSON: appName"))
        #expect(!source.contains("argumentsJSON: depth"))
        #expect(!source.contains("resultJSON: payload"))
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
