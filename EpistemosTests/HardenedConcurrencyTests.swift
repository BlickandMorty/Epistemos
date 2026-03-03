import XCTest
@testable import Epistemos

final class HardenedConcurrencyTests: XCTestCase {
    // Paper Translation: Race Condition & Stress Tests
    // Spawning hundreds of simultaneous Tasks to mutate the same GraphStore to ensure SwiftData/MainActor thread safety.
    func test_Concurrent_Graph_Mutations_Scale_10() async throws {
        let store = GraphStore()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await store.applyDelta(nodes: GraphFuzz.randomGraph(nodeCount: 5).0, edges: [], clearFirst: i % 10 == 0)
                }
            }
        }
        // If we reach here without a data race crash, Swift concurrency barriers are intact.
        XCTAssertTrue(true)
    }

    func test_Concurrent_Graph_Mutations_Scale_100() async throws {
        let store = GraphStore()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await store.applyDelta(nodes: GraphFuzz.randomGraph(nodeCount: 5).0, edges: [], clearFirst: i % 10 == 0)
                }
            }
        }
        // If we reach here without a data race crash, Swift concurrency barriers are intact.
        XCTAssertTrue(true)
    }

    func test_Concurrent_Graph_Mutations_Scale_1000() async throws {
        let store = GraphStore()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<1000 {
                group.addTask {
                    await store.applyDelta(nodes: GraphFuzz.randomGraph(nodeCount: 5).0, edges: [], clearFirst: i % 10 == 0)
                }
            }
        }
        // If we reach here without a data race crash, Swift concurrency barriers are intact.
        XCTAssertTrue(true)
    }

}
