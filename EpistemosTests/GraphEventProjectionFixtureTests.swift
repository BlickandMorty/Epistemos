import Foundation
import Testing
@testable import Epistemos

/// Pure value-level fixtures for `DurableGraphEventProjection.snapshot(from:)`.
/// No EventStore, no DB, no FFI — just the in-memory fold semantics.
///
/// Doctrine §7 lane: Core open — live GraphEvent consumer projection
/// preparation. Sister suite: `GraphEventAuditProjectionTests` (DB-backed
/// audit report path). This suite is the **fold-semantics floor** — any new
/// consumer of the projection (graph, retrieval, Halo, Theater, audit) can
/// rely on these invariants holding.
@Suite("GraphEvent Projection Fixtures")
nonisolated struct GraphEventProjectionFixtureTests {

    // MARK: - Empty / no-op input

    @Test("empty input yields empty snapshot with zero counts")
    func emptyInputYieldsEmptySnapshot() {
        let snapshot = DurableGraphEventProjection.snapshot(from: [])

        #expect(snapshot.nodes.isEmpty)
        #expect(snapshot.edges.isEmpty)
        #expect(snapshot.eventCount == 0)
        #expect(snapshot.latestEventID == nil)
    }

    @Test("graphMutation events are no-ops but still counted")
    func graphMutationEventsAreNoOps() {
        let events = [
            graphEvent(seq: 0, kind: .graphMutation, eventID: "g-1"),
            graphEvent(seq: 1, kind: .graphMutation, eventID: "g-2"),
        ]
        let snapshot = DurableGraphEventProjection.snapshot(from: events)

        #expect(snapshot.nodes.isEmpty,
                "graphMutation must not create nodes")
        #expect(snapshot.edges.isEmpty,
                "graphMutation must not create edges")
        #expect(snapshot.eventCount == 2,
                "eventCount counts every input event, including no-ops")
        #expect(snapshot.latestEventID == "g-2",
                "latestEventID tracks the last input event regardless of whether it folded")
    }

    @Test("events with whitespace-only entityID are skipped")
    func eventsWithWhitespaceEntityIDAreSkipped() {
        let events = [
            graphEvent(seq: 0, kind: .nodeCreated, entityID: "   ", entityKind: "note"),
            graphEvent(seq: 1, kind: .nodeCreated, entityID: "", entityKind: "note"),
            graphEvent(seq: 2, kind: .nodeCreated, entityID: "real-node", entityKind: "note"),
        ]
        let snapshot = DurableGraphEventProjection.snapshot(from: events)

        #expect(snapshot.nodes.count == 1,
                "Only the well-formed entityID should fold into a node")
        #expect(snapshot.nodes.first?.id == "real-node")
        #expect(snapshot.eventCount == 3,
                "eventCount counts every input event, including ones the fold skipped")
    }

    // MARK: - Node lifecycle

    @Test("single nodeCreated yields one node with the input metadata")
    func singleNodeCreatedYieldsOneNode() {
        let event = graphEvent(
            seq: 0,
            kind: .nodeCreated,
            entityID: "note-A",
            entityKind: "prose_note",
            eventID: "evt-A",
            mutationID: "mut-A",
            occurredAtMs: 1_000
        )
        let snapshot = DurableGraphEventProjection.snapshot(from: [event])

        try? #require(snapshot.nodes.count == 1)
        let node = snapshot.nodes[0]
        #expect(node.id == "note-A")
        #expect(node.kind == "prose_note")
        #expect(node.lastEventID == "evt-A")
        #expect(node.lastMutationID == "mut-A")
        #expect(node.lastEventKind == .nodeCreated)
        #expect(node.lastOccurredAtMs == 1_000)
        #expect(snapshot.latestEventID == "evt-A")
    }

    @Test("nodeUpdated overwrites prior nodeCreated metadata")
    func nodeUpdatedOverwritesPriorNodeCreated() {
        let events = [
            graphEvent(seq: 0, kind: .nodeCreated, entityID: "note-A", entityKind: "prose_note",
                       eventID: "evt-create", mutationID: "mut-create", occurredAtMs: 1_000),
            graphEvent(seq: 1, kind: .nodeUpdated, entityID: "note-A", entityKind: "prose_note",
                       eventID: "evt-update", mutationID: "mut-update", occurredAtMs: 2_000),
        ]
        let snapshot = DurableGraphEventProjection.snapshot(from: events)

        try? #require(snapshot.nodes.count == 1)
        let node = snapshot.nodes[0]
        #expect(node.lastEventKind == .nodeUpdated,
                "Update event must replace the node's lastEventKind")
        #expect(node.lastEventID == "evt-update")
        #expect(node.lastMutationID == "mut-update")
        #expect(node.lastOccurredAtMs == 2_000)
        #expect(snapshot.latestEventID == "evt-update")
    }

    @Test("nodeDeleted removes the node and cascades to incident edges")
    func nodeDeletedCascadesToIncidentEdges() {
        let events = [
            graphEvent(seq: 0, kind: .nodeCreated, entityID: "node-A", entityKind: "note"),
            graphEvent(seq: 1, kind: .nodeCreated, entityID: "node-B", entityKind: "note"),
            graphEvent(seq: 2, kind: .nodeCreated, entityID: "node-C", entityKind: "note"),
            graphEvent(seq: 3, kind: .edgeCreated,
                       relation: .init(fromID: "node-A", toID: "node-B", label: "mentions")),
            graphEvent(seq: 4, kind: .edgeCreated,
                       relation: .init(fromID: "node-A", toID: "node-C", label: "links")),
            graphEvent(seq: 5, kind: .edgeCreated,
                       relation: .init(fromID: "node-B", toID: "node-C", label: "follows")),
            graphEvent(seq: 6, kind: .nodeDeleted, entityID: "node-A"),
        ]
        let snapshot = DurableGraphEventProjection.snapshot(from: events)

        let nodeIDs = snapshot.nodes.map(\.id)
        #expect(nodeIDs == ["node-B", "node-C"],
                "Deleted node must be gone; surviving nodes must be sorted by id")

        let edgeFromTo = snapshot.edges.map { ($0.fromID, $0.toID) }
        #expect(edgeFromTo.count == 1,
                "Edges incident to the deleted node must cascade away; only B->C remains")
        #expect(edgeFromTo.first?.0 == "node-B")
        #expect(edgeFromTo.first?.1 == "node-C")
    }

    @Test("re-creating a deleted node restores it without edge resurrection")
    func recreatingDeletedNodeDoesNotResurrectEdges() {
        let events = [
            graphEvent(seq: 0, kind: .nodeCreated, entityID: "node-A", entityKind: "note"),
            graphEvent(seq: 1, kind: .nodeCreated, entityID: "node-B", entityKind: "note"),
            graphEvent(seq: 2, kind: .edgeCreated,
                       relation: .init(fromID: "node-A", toID: "node-B", label: "mentions")),
            graphEvent(seq: 3, kind: .nodeDeleted, entityID: "node-A"),
            graphEvent(seq: 4, kind: .nodeCreated, entityID: "node-A", entityKind: "note"),
        ]
        let snapshot = DurableGraphEventProjection.snapshot(from: events)

        #expect(snapshot.nodes.map(\.id) == ["node-A", "node-B"],
                "Re-created node must reappear in sorted order")
        #expect(snapshot.edges.isEmpty,
                "Cascade-deleted edges must NOT resurrect just because the node returned — the edgeCreated event would need to replay too")
    }

    // MARK: - Edge lifecycle

    @Test("edgeCreated deterministic id is fromID->toID:label")
    func edgeCreatedDeterministicID() {
        let events = [
            graphEvent(seq: 0, kind: .edgeCreated,
                       relation: .init(fromID: "alpha", toID: "beta", label: "mentions"),
                       eventID: "evt-edge", mutationID: "mut-edge", occurredAtMs: 5_000),
        ]
        let snapshot = DurableGraphEventProjection.snapshot(from: events)

        try? #require(snapshot.edges.count == 1)
        let edge = snapshot.edges[0]
        #expect(edge.id == "alpha->beta:mentions",
                "Edge id must be the canonical fromID->toID:label")
        #expect(edge.fromID == "alpha")
        #expect(edge.toID == "beta")
        #expect(edge.label == "mentions")
        #expect(edge.lastEventID == "evt-edge")
        #expect(edge.lastMutationID == "mut-edge")
        #expect(edge.lastEventKind == .edgeCreated)
        #expect(edge.lastOccurredAtMs == 5_000)
    }

    @Test("edgeUpdated with same label upserts in place")
    func edgeUpdatedWithSameLabelUpsertsInPlace() {
        let events = [
            graphEvent(seq: 0, kind: .edgeCreated,
                       relation: .init(fromID: "a", toID: "b", label: "mentions"),
                       eventID: "evt-1", occurredAtMs: 1_000),
            graphEvent(seq: 1, kind: .edgeUpdated,
                       relation: .init(fromID: "a", toID: "b", label: "mentions"),
                       eventID: "evt-2", occurredAtMs: 2_000),
        ]
        let snapshot = DurableGraphEventProjection.snapshot(from: events)

        try? #require(snapshot.edges.count == 1)
        let edge = snapshot.edges[0]
        #expect(edge.id == "a->b:mentions")
        #expect(edge.lastEventID == "evt-2",
                "Update must overwrite lastEventID")
        #expect(edge.lastEventKind == .edgeUpdated)
        #expect(edge.lastOccurredAtMs == 2_000)
    }

    @Test("edgeUpdated with new label removes old edge and inserts new")
    func edgeUpdatedWithNewLabelRemovesOldAndInsertsNew() {
        let events = [
            graphEvent(seq: 0, kind: .edgeCreated,
                       relation: .init(fromID: "a", toID: "b", label: "mentions")),
            graphEvent(seq: 1, kind: .edgeUpdated,
                       relation: .init(fromID: "a", toID: "b",
                                       label: "cites",
                                       oldLabel: "mentions")),
        ]
        let snapshot = DurableGraphEventProjection.snapshot(from: events)

        let edgeIDs = snapshot.edges.map(\.id)
        #expect(edgeIDs == ["a->b:cites"],
                "Old label edge must be removed; new label edge must be inserted")
        #expect(!edgeIDs.contains("a->b:mentions"))
    }

    @Test("edgeDeleted removes the matching edge by id")
    func edgeDeletedRemovesMatchingEdgeByID() {
        let events = [
            graphEvent(seq: 0, kind: .edgeCreated,
                       relation: .init(fromID: "a", toID: "b", label: "mentions")),
            graphEvent(seq: 1, kind: .edgeCreated,
                       relation: .init(fromID: "a", toID: "c", label: "mentions")),
            graphEvent(seq: 2, kind: .edgeDeleted,
                       relation: .init(fromID: "a", toID: "b", label: "mentions")),
        ]
        let snapshot = DurableGraphEventProjection.snapshot(from: events)

        #expect(snapshot.edges.map(\.id) == ["a->c:mentions"],
                "Only the matching from->to:label tuple should be removed")
    }

    @Test("edge events with whitespace relation fields are skipped")
    func edgeEventsWithWhitespaceRelationFieldsAreSkipped() {
        let events = [
            graphEvent(seq: 0, kind: .edgeCreated,
                       relation: .init(fromID: "  ", toID: "b", label: "mentions")),
            graphEvent(seq: 1, kind: .edgeCreated,
                       relation: .init(fromID: "a", toID: "", label: "mentions")),
            graphEvent(seq: 2, kind: .edgeCreated,
                       relation: .init(fromID: "a", toID: "b", label: "")),
            graphEvent(seq: 3, kind: .edgeCreated,
                       relation: .init(fromID: "a", toID: "b", label: "valid")),
        ]
        let snapshot = DurableGraphEventProjection.snapshot(from: events)

        #expect(snapshot.edges.map(\.id) == ["a->b:valid"],
                "Only the well-formed relation should fold; whitespace-only fields skip")
        #expect(snapshot.eventCount == 4,
                "eventCount counts every input event, including ones the fold skipped")
    }

    // MARK: - Determinism + sorting

    @Test("nodes and edges are returned sorted by id for deterministic snapshots")
    func nodesAndEdgesAreReturnedSortedByID() {
        let events = [
            graphEvent(seq: 0, kind: .nodeCreated, entityID: "z-node", entityKind: "note"),
            graphEvent(seq: 1, kind: .nodeCreated, entityID: "a-node", entityKind: "note"),
            graphEvent(seq: 2, kind: .nodeCreated, entityID: "m-node", entityKind: "note"),
            graphEvent(seq: 3, kind: .edgeCreated,
                       relation: .init(fromID: "z-node", toID: "a-node", label: "rel")),
            graphEvent(seq: 4, kind: .edgeCreated,
                       relation: .init(fromID: "a-node", toID: "m-node", label: "rel")),
        ]
        let snapshot = DurableGraphEventProjection.snapshot(from: events)

        #expect(snapshot.nodes.map(\.id) == ["a-node", "m-node", "z-node"],
                "Nodes must be sorted by id for deterministic projection consumers")
        #expect(snapshot.edges.map(\.id) == ["a-node->m-node:rel", "z-node->a-node:rel"],
                "Edges must be sorted by id for deterministic projection consumers")
    }

    @Test("the same input always produces the same snapshot")
    func sameInputAlwaysProducesSameSnapshot() {
        let events = [
            graphEvent(seq: 0, kind: .nodeCreated, entityID: "n1", entityKind: "note"),
            graphEvent(seq: 1, kind: .nodeCreated, entityID: "n2", entityKind: "note"),
            graphEvent(seq: 2, kind: .edgeCreated,
                       relation: .init(fromID: "n1", toID: "n2", label: "rel")),
            graphEvent(seq: 3, kind: .edgeUpdated,
                       relation: .init(fromID: "n1", toID: "n2",
                                       label: "rel-2",
                                       oldLabel: "rel")),
        ]
        let snapshot1 = DurableGraphEventProjection.snapshot(from: events)
        let snapshot2 = DurableGraphEventProjection.snapshot(from: events)

        #expect(snapshot1 == snapshot2,
                "Projection must be a pure function — identical input must yield identical snapshot (Hashable conformance)")
    }

    @Test("input order matters — replay drives the fold")
    func inputOrderDrivesTheFold() {
        let createThenDelete = [
            graphEvent(seq: 0, kind: .nodeCreated, entityID: "n", entityKind: "note", eventID: "create"),
            graphEvent(seq: 1, kind: .nodeDeleted, entityID: "n", eventID: "delete"),
        ]
        let deleteThenCreate = [
            graphEvent(seq: 0, kind: .nodeDeleted, entityID: "n", eventID: "delete"),
            graphEvent(seq: 1, kind: .nodeCreated, entityID: "n", entityKind: "note", eventID: "create"),
        ]

        let s1 = DurableGraphEventProjection.snapshot(from: createThenDelete)
        let s2 = DurableGraphEventProjection.snapshot(from: deleteThenCreate)

        #expect(s1.nodes.isEmpty,
                "Create-then-delete must end with no node")
        #expect(s2.nodes.count == 1,
                "Delete-then-create (delete is no-op on missing node) must end with the node present")
        #expect(s1 != s2,
                "Different replay orders must yield different snapshots — fold is order-sensitive")
    }

    // MARK: - eventCount + latestEventID semantics

    @Test("eventCount equals input length regardless of how many events folded")
    func eventCountEqualsInputLengthRegardlessOfFold() {
        // Mix of foldable + skipped events. eventCount must report the input
        // length, not the number of mutations applied — this lets a consumer
        // compare against the input slice length to detect partial fold bugs.
        let events = [
            graphEvent(seq: 0, kind: .graphMutation),
            graphEvent(seq: 1, kind: .nodeCreated, entityID: "  "),
            graphEvent(seq: 2, kind: .nodeCreated, entityID: "real", entityKind: "note"),
            graphEvent(seq: 3, kind: .edgeCreated,
                       relation: .init(fromID: "", toID: "real", label: "x")),
            graphEvent(seq: 4, kind: .edgeDeleted,
                       relation: .init(fromID: "ghost", toID: "ghost", label: "ghost")),
        ]
        let snapshot = DurableGraphEventProjection.snapshot(from: events)

        #expect(snapshot.eventCount == 5,
                "eventCount must equal input length (5), not the number of effective applies (1)")
        #expect(snapshot.nodes.count == 1)
        #expect(snapshot.edges.isEmpty)
    }

    @Test("latestEventID tracks the trailing input event even when its fold was a no-op")
    func latestEventIDTracksTrailingInputEvent() {
        let events = [
            graphEvent(seq: 0, kind: .nodeCreated, entityID: "n", entityKind: "note", eventID: "first"),
            graphEvent(seq: 1, kind: .graphMutation, eventID: "trailing-noop"),
        ]
        let snapshot = DurableGraphEventProjection.snapshot(from: events)

        #expect(snapshot.latestEventID == "trailing-noop",
                "latestEventID must be the LAST input eventID, not the last applied event — consumers use it as a watermark")
    }

    // MARK: - Helpers

    private func graphEvent(
        seq: UInt64,
        kind: DurableGraphEventKind,
        entityID: String? = nil,
        entityKind: String? = nil,
        relation: DurableGraphEventRelation? = nil,
        eventID: String? = nil,
        mutationID: String? = nil,
        occurredAtMs: Int64 = 0
    ) -> DurableGraphEvent {
        DurableGraphEvent(
            eventID: eventID ?? "evt-\(seq)",
            mutationID: mutationID ?? "mut-\(seq)",
            runID: "run-fixture",
            traceID: "trace-fixture",
            sequence: seq,
            kind: kind,
            entityID: entityID,
            entityKind: entityKind,
            occurredAtMs: occurredAtMs == 0 ? Int64(1_000 + seq) : occurredAtMs,
            relation: relation
        )
    }
}
