import Foundation
import Testing
@testable import Epistemos

@Suite("AgentEvent v1.6 forward variants")
struct AgentEventV16ForwardVariantTests {
    private let forwardVariantRawValues: [String] = [
        "steer_requested",
        "summary_started",
        "summary_delta",
        "summary_completed",
        "vault_created",
        "vault_archived",
    ]

    private let forwardVariantKinds: [AgentProvenanceEventKind] = [
        .steerRequested,
        .summaryStarted,
        .summaryDelta,
        .summaryCompleted,
        .vaultCreated,
        .vaultArchived,
    ]

    @Test("AgentEvent kind vocabulary includes simulation v1.6 forward variants")
    func agentEventKindVocabularyIncludesSimulationV16ForwardVariants() {
        let allRawValues = Set(AgentProvenanceEventKind.allCases.map(\.rawValue))

        for rawValue in forwardVariantRawValues {
            #expect(allRawValues.contains(rawValue))
        }
    }

    @Test("simulation v1.6 forward variants round-trip through Codable")
    func simulationV16ForwardVariantsRoundTripThroughCodable() throws {
        for kind in forwardVariantKinds {
            let data = try JSONEncoder().encode(kind)
            let json = try #require(String(data: data, encoding: .utf8))
            #expect(json == "\"\(kind.rawValue)\"")

            let decoded = try JSONDecoder().decode(AgentProvenanceEventKind.self, from: data)
            #expect(decoded == kind)
        }
    }

    @Test("EventStore persists simulation v1.6 forward variant events")
    func eventStorePersistsSimulationV16ForwardVariantEvents() throws {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-event-v16-forward-\(UUID().uuidString).sqlite")
        let store = try #require(EventStore(databaseURL: dbURL))
        let runID = "run-v16-forward-\(UUID().uuidString)"

        for (index, kind) in forwardVariantKinds.enumerated() {
            let event = AgentProvenanceEvent(
                eventID: "agent-event-v16-forward-\(index)-\(UUID().uuidString)",
                runID: runID,
                traceID: "trace-\(runID)",
                sequence: UInt64(index),
                kind: kind,
                actor: .system,
                occurredAtMs: Int64(index + 1) * 1_000,
                tool: nil,
                metadata: [
                    "canon": "simulation_doctrine_v1_6",
                    "status": "forward_variant_only",
                ]
            )

            #expect(store.saveAgentEvent(event))
            #expect(store.loadAgentEvent(eventID: event.eventID) == event)
        }

        let events = store.agentEvents(runID: runID, limit: 10)
        #expect(events.map(\.kind) == forwardVariantKinds)
        #expect(events.allSatisfy { $0.tool == nil })
        #expect(events.allSatisfy { $0.metadata["status"] == "forward_variant_only" })
        #expect(store.agentEventDiagnostics().lastKind == .vaultArchived)
    }
}
