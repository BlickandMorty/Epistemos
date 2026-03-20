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

    private func notification(
        name: Notification.Name,
        keys: Set<QueryDependencyKey>? = nil
    ) -> Notification {
        Notification(
            name: name,
            object: nil,
            userInfo: QueryDependencyKey.userInfo(for: keys)
        )
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

        #expect(store.nodeCount == 2)

        let basePlan = QueryPlan(
            steps: [.graphStoreFilter(NodeFilter(limit: 10))],
            combiner: .single
        )
        let descending = runtime.execute(QueryPlan(inner: basePlan, limit: nil, offset: nil, orderBy: .updated(ascending: false)))
        let ascending = runtime.execute(QueryPlan(inner: basePlan, limit: nil, offset: nil, orderBy: .updated(ascending: true)))

        #expect(descending.nodes.map(\.id) == ["alpha", "beta"])
        #expect(ascending.nodes.map(\.id) == ["beta", "alpha"])
    }

    @Test("reactive query invalidation stays within a single debounce window")
    func reactiveQueryInvalidationLatency() async throws {
        let store = GraphStore()
        let runtime = try QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let plan = QueryPlan(
            steps: [.graphStoreFilter(NodeFilter(limit: 10))],
            combiner: .single
        )
        let reactive = ReactiveQuery(runtime: runtime, plan: plan)
        var iterator = reactive.stream().makeAsyncIterator()

        let initial = await iterator.next()
        #expect(initial?.nodes.isEmpty == true)

        let clock = ContinuousClock()
        let start = clock.now
        store.addNode(
            GraphNodeRecord(
                id: "gamma",
                type: .note,
                label: "Gamma",
                sourceId: nil,
                metadata: GraphNodeMetadata(),
                weight: 1.0,
                createdAt: .now
            )
        )

        let updated = await iterator.next()
        let elapsed = clock.now - start

        #expect(updated?.nodes.map(\.id) == ["gamma"])
        #expect(
            elapsed < .milliseconds(80),
            "Reactive query update took \(elapsed), expected to stay under one debounce window"
        )
    }

    @Test("reactive query ignores irrelevant graph dependency notifications")
    func reactiveQueryIgnoresIrrelevantGraphNotifications() throws {
        let runtime = try QueryRuntime(
            graphStore: GraphStore(),
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let plan = QueryPlan(
            steps: [.graphStoreFilter(NodeFilter(limit: 10))],
            combiner: .single
        )
        let reactive = ReactiveQuery(runtime: runtime, plan: plan)

        #expect(
            reactive.shouldInvalidate(for: notification(name: .graphStoreDidChange, keys: [.graphNodes]))
        )
        #expect(
            !reactive.shouldInvalidate(for: notification(name: .graphStoreDidChange, keys: [.graphEdges]))
        )
    }

    @Test("reactive query scopes search invalidation by index domain")
    func reactiveQueryScopesSearchInvalidationByIndexDomain() throws {
        let runtime = try QueryRuntime(
            graphStore: GraphStore(),
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )

        let pageReactive = ReactiveQuery(
            runtime: runtime,
            plan: QueryPlan(
                steps: [.fts5Search(query: "graph", scope: .pages)],
                combiner: .single
            )
        )
        let blockReactive = ReactiveQuery(
            runtime: runtime,
            plan: QueryPlan(
                steps: [.fts5Search(query: "graph", scope: .blocks)],
                combiner: .single
            )
        )

        #expect(
            pageReactive.shouldInvalidate(for: notification(name: .searchIndexDidUpdate, keys: [.searchPages]))
        )
        #expect(
            !pageReactive.shouldInvalidate(for: notification(name: .searchIndexDidUpdate, keys: [.searchBlocks]))
        )
        #expect(
            blockReactive.shouldInvalidate(for: notification(name: .searchIndexDidUpdate, keys: [.searchBlocks]))
        )
    }

    @Test("reactive query conservatively invalidates unscoped notifications")
    func reactiveQueryConservativeFallback() throws {
        let runtime = try QueryRuntime(
            graphStore: GraphStore(),
            graphState: GraphState(),
            searchIndex: makeSearchIndex()
        )
        let reactive = ReactiveQuery(
            runtime: runtime,
            plan: QueryPlan(
                steps: [.fts5Search(query: "graph", scope: .pages)],
                combiner: .single
            )
        )

        #expect(reactive.shouldInvalidate(for: Notification(name: .searchIndexDidUpdate)))
    }
}
