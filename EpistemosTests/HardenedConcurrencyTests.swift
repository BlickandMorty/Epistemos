import Testing
@testable import Epistemos

@Suite("Hardened Concurrency")
@MainActor
struct HardenedConcurrencyTests {
    @Test("concurrent graph reloads scale across small batches", arguments: [10, 100, 1000])
    func concurrentGraphReloads(_ iterations: Int) async {
        let store = GraphStore()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask { @MainActor in
                    let graph = GraphFuzz.randomGraph(nodeCount: 5)
                    store.loadFromRecords(nodeRecords: graph.nodes, edgeRecords: [])
                }
            }
        }

        #expect(store.nodeCount <= 5)
    }
}
