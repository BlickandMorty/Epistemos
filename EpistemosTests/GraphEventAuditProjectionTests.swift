import Foundation
import Testing
@testable import Epistemos

@Suite("GraphEvent Audit Projection")
struct GraphEventAuditProjectionTests {
    @Test("audit report consumes EventStore graph projection snapshot")
    func auditReportConsumesEventStoreGraphProjectionSnapshot() throws {
        let store = try #require(makeTestStore())
        let nodeID = "note-audit-\(UUID().uuidString)"
        let targetID = "note-audit-target-\(UUID().uuidString)"
        let node = DurableGraphEvent(
            eventID: "graph-event-audit-node-\(UUID().uuidString)",
            mutationID: "mutation-audit-node",
            runID: "run-audit",
            traceID: "trace-audit",
            sequence: 0,
            kind: .nodeCreated,
            entityID: nodeID,
            entityKind: ArtifactKind.proseNote.snakeCaseString,
            occurredAtMs: 1_000
        )
        let edge = DurableGraphEvent(
            eventID: "graph-event-audit-edge-\(UUID().uuidString)",
            mutationID: "mutation-audit-edge",
            runID: "run-audit",
            traceID: "trace-audit",
            sequence: 1,
            kind: .edgeCreated,
            occurredAtMs: 2_000,
            relation: DurableGraphEventRelation(fromID: nodeID, toID: targetID, label: "mentions")
        )

        #expect(store.saveGraphEvent(edge))
        #expect(store.saveGraphEvent(node))

        let service = GraphEventAuditProjectionService(
            eventStoreProvider: { store },
            nowMilliseconds: { 123_456 }
        )
        let report = service.auditReport(limit: 10)

        #expect(report.generatedAtMs == 123_456)
        #expect(report.eventCount == 2)
        #expect(report.nodeCount == 1)
        #expect(report.edgeCount == 1)
        #expect(report.latestEventID == edge.eventID)
        #expect(report.nodeIDs == [nodeID])
        #expect(report.edgeIDs == ["\(nodeID)->\(targetID):mentions"])
        #expect(report.isEmpty == false)
    }

    @Test("audit report is empty when EventStore is unavailable")
    func auditReportIsEmptyWhenEventStoreIsUnavailable() {
        let service = GraphEventAuditProjectionService(
            eventStoreProvider: { () -> EventStore? in nil },
            nowMilliseconds: { 7 }
        )
        let report = service.auditReport(limit: 10)

        #expect(report.generatedAtMs == 7)
        #expect(report.eventCount == 0)
        #expect(report.nodeCount == 0)
        #expect(report.edgeCount == 0)
        #expect(report.latestEventID == nil)
        #expect(report.nodeIDs.isEmpty)
        #expect(report.edgeIDs.isEmpty)
        #expect(report.isEmpty)
    }

    @Test("audit report forwards requested limit to injected snapshot provider")
    func auditReportForwardsRequestedLimitToInjectedSnapshotProvider() {
        let service = GraphEventAuditProjectionService(
            snapshotProvider: { limit in
                #expect(limit == 37)
                return DurableGraphEventProjection.snapshot(from: [])
            },
            nowMilliseconds: { 42 }
        )

        let report = service.auditReport(limit: 37)

        #expect(report.generatedAtMs == 42)
        #expect(report.isEmpty)
    }

    @Test("trace inspector exposes read-only GraphEvent projection summary")
    func traceInspectorExposesReadOnlyGraphEventProjectionSummary() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Capture/TraceInspectorView.swift")
        let serviceSource = try loadMirroredSourceTextFile("Epistemos/Engine/GraphEventAuditProjectionService.swift")
        try #require(!source.isEmpty)
        try #require(!serviceSource.isEmpty)

        #expect(source.contains("graphProjectionReport"))
        #expect(source.contains("loadTask?.cancel()"))
        #expect(source.contains("Task.detached(priority: .utility)"))
        #expect(source.contains("refreshGraphProjectionReport("))
        #expect(source.contains("GraphEventAuditProjectionService().auditReport(limit: 100)"))
        #expect(source.contains("Graph projection"))
        #expect(source.contains("graphProjectionDetail"))
        #expect(source.contains("onAppear"))

        #expect(!source.contains("saveGraphEvent"))
        #expect(!source.contains("saveMutationEnvelope"))
        #expect(!source.contains("graphEvents("))
        #expect(!source.contains("MutationOpLog"))
        #expect(!source.contains("OpLog"))
        #expect(!source.contains("HaloController"))
        #expect(!source.contains("GraphEventVisibilityRow"))
        #expect(!source.contains("Timer"))
        #expect(!source.contains("DispatchSourceTimer"))
        #expect(!source.contains("repeatForever"))
        #expect(!source.contains("while !Task.isCancelled"))
        #expect(serviceSource.contains("nonisolated final class GraphEventAuditProjectionService: @unchecked Sendable"))
    }

    private func makeTestStore() -> EventStore? {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("graph-event-audit-\(UUID().uuidString).sqlite")
        return EventStore(databaseURL: dbURL)
    }
}
