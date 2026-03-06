import Foundation
import Testing
@testable import Epistemos

@Suite("QueryRuntime")
@MainActor
struct QueryRuntimeTests {
    private func makeSearchIndex() throws -> SearchIndexService {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("query-runtime-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("search.sqlite")
        return try SearchIndexService(databaseURL: dbURL)
    }

    @Test("updated ordering uses updatedAt instead of createdAt")
    func updatedOrderingUsesUpdatedAt() throws {
        let store = GraphStore()
        let olderCreatedNewerUpdated = GraphNodeRecord(
            id: "alpha",
            type: .note,
            label: "Alpha",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 400)
        )
        let newerCreatedOlderUpdated = GraphNodeRecord(
            id: "beta",
            type: .note,
            label: "Beta",
            sourceId: nil,
            metadata: GraphNodeMetadata(),
            weight: 1.0,
            createdAt: Date(timeIntervalSince1970: 300),
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        store.addNode(olderCreatedNewerUpdated)
        store.addNode(newerCreatedOlderUpdated)

        let runtime = try QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let basePlan = QueryPlan(steps: [.inMemoryLabelFilter("")], combiner: .single)
        let descending = runtime.execute(QueryPlan(inner: basePlan, limit: nil, offset: nil, orderBy: .updated(ascending: false)))
        let ascending = runtime.execute(QueryPlan(inner: basePlan, limit: nil, offset: nil, orderBy: .updated(ascending: true)))

        #expect(descending.nodes.map(\.id) == ["alpha", "beta"])
        #expect(ascending.nodes.map(\.id) == ["beta", "alpha"])
    }
}
