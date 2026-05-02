import Foundation

nonisolated struct GraphEventAuditProjectionReport: Equatable, Sendable {
    let generatedAtMs: Int64
    let eventCount: Int
    let nodeCount: Int
    let edgeCount: Int
    let latestEventID: String?
    let nodeIDs: [String]
    let edgeIDs: [String]

    var isEmpty: Bool {
        eventCount == 0 && nodeCount == 0 && edgeCount == 0
    }

    static let empty = GraphEventAuditProjectionReport(
        generatedAtMs: 0,
        eventCount: 0,
        nodeCount: 0,
        edgeCount: 0,
        latestEventID: nil,
        nodeIDs: [],
        edgeIDs: []
    )
}

final class GraphEventAuditProjectionService {
    typealias SnapshotProvider = @Sendable (Int) -> DurableGraphProjectionSnapshot
    typealias EventStoreProvider = @Sendable () -> EventStore?
    typealias Clock = @Sendable () -> Int64

    private let snapshotProvider: SnapshotProvider
    private let nowMilliseconds: Clock

    init(
        eventStoreProvider: @escaping EventStoreProvider = { EventStore.shared },
        nowMilliseconds: @escaping Clock = {
            let milliseconds = Date().timeIntervalSince1970 * 1_000
            guard milliseconds.isFinite else { return 0 }
            return Int64(milliseconds.rounded())
        }
    ) {
        self.snapshotProvider = { limit in
            eventStoreProvider()?.graphEventProjectionSnapshot(limit: limit)
                ?? DurableGraphEventProjection.snapshot(from: [])
        }
        self.nowMilliseconds = nowMilliseconds
    }

    init(
        snapshotProvider: @escaping SnapshotProvider,
        nowMilliseconds: @escaping Clock
    ) {
        self.snapshotProvider = snapshotProvider
        self.nowMilliseconds = nowMilliseconds
    }

    func auditReport(limit: Int = 100) -> GraphEventAuditProjectionReport {
        let snapshot = snapshotProvider(limit)
        return GraphEventAuditProjectionReport(
            generatedAtMs: nowMilliseconds(),
            eventCount: snapshot.eventCount,
            nodeCount: snapshot.nodes.count,
            edgeCount: snapshot.edges.count,
            latestEventID: snapshot.latestEventID,
            nodeIDs: snapshot.nodes.map(\.id),
            edgeIDs: snapshot.edges.map(\.id)
        )
    }
}
