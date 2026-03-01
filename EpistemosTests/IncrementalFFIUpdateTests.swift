import Testing
import SwiftData
@testable import Epistemos

// MARK: - Audit W1.12: Incremental FFI Graph Updates

@Suite("Audit W1.12 — Incremental FFI Graph Updates")
@MainActor
struct IncrementalFFIUpdateTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: SDPage.self, SDFolder.self, SDBlock.self, SDPageVersion.self,
            SDChat.self, SDMessage.self, SDGraphNode.self, SDGraphEdge.self,
            configurations: config
        )
    }

    private func makeNode(id: String = "node-1", type: GraphNodeType = .tag, label: String = "Test") -> GraphNodeRecord {
        GraphNodeRecord(
            id: id,
            type: type,
            label: label,
            sourceId: nil,
            metadata: .init(),
            weight: 1.0,
            createdAt: Date(),
            position: SIMD2<Float>(100, 200),
            velocity: .zero
        )
    }

    private func makeEdge(id: String = "edge-1", source: String = "a", target: String = "b") -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: id,
            sourceNodeId: source,
            targetNodeId: target,
            type: .related,
            weight: 1.0,
            createdAt: Date()
        )
    }

    // MARK: - Queue Mechanics

    @Test("requestIncrementalAdd queues a node")
    func queueNode() {
        let state = GraphState()
        let node = makeNode()
        #expect(state.pendingNodeAdds.isEmpty)

        state.requestIncrementalAdd(node: node)

        #expect(state.pendingNodeAdds.count == 1)
        #expect(state.pendingNodeAdds.first?.id == "node-1")
    }

    @Test("requestIncrementalAddEdge queues an edge")
    func queueEdge() {
        let state = GraphState()
        let edge = makeEdge()
        #expect(state.pendingEdgeAdds.isEmpty)

        state.requestIncrementalAddEdge(edge)

        #expect(state.pendingEdgeAdds.count == 1)
        #expect(state.pendingEdgeAdds.first?.sourceNodeId == "a")
        #expect(state.pendingEdgeAdds.first?.targetNodeId == "b")
    }

    @Test("multiple incremental adds accumulate")
    func multipleAdds() {
        let state = GraphState()
        state.requestIncrementalAdd(node: makeNode(id: "n1"))
        state.requestIncrementalAdd(node: makeNode(id: "n2"))
        state.requestIncrementalAdd(node: makeNode(id: "n3"))
        state.requestIncrementalAddEdge(makeEdge(id: "e1", source: "n1", target: "n2"))
        state.requestIncrementalAddEdge(makeEdge(id: "e2", source: "n2", target: "n3"))

        #expect(state.pendingNodeAdds.count == 3)
        #expect(state.pendingEdgeAdds.count == 2)
    }

    @Test("pendingNodeAdds starts empty")
    func startsEmpty() {
        let state = GraphState()
        #expect(state.pendingNodeAdds.isEmpty)
        #expect(state.pendingEdgeAdds.isEmpty)
    }

    // MARK: - createNode uses incremental path for non-note types

    @Test("createNode for tag uses incremental add instead of recommit")
    func createNodeIncrementalPath() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let state = GraphState()

        let versionBefore = state.graphDataVersion

        state.createNode(
            type: .tag,
            label: "Test Tag",
            atWorldPosition: SIMD2<Float>(50, 50),
            context: context
        )

        // Incremental path: pendingNodeAdds should have the new node
        #expect(state.pendingNodeAdds.count == 1)
        #expect(state.pendingNodeAdds.first?.label == "Test Tag")
        #expect(state.pendingNodeAdds.first?.type == .tag)

        // graphDataVersion should NOT increment (no full recommit)
        #expect(state.graphDataVersion == versionBefore)

        // Node should also be in the store already
        #expect(state.store.nodeCount == 1)
    }

    // MARK: - connectNodes uses incremental path

    @Test("connectNodes uses incremental edge add")
    func connectNodesIncrementalPath() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let state = GraphState()

        // Pre-populate two nodes in the store
        let nodeA = makeNode(id: "a", label: "Node A")
        let nodeB = makeNode(id: "b", label: "Node B")
        state.store.addNode(nodeA)
        state.store.addNode(nodeB)

        // Also insert SDGraphNodes for the database side
        let sdA = SDGraphNode(type: .tag, label: "Node A")
        let sdB = SDGraphNode(type: .tag, label: "Node B")
        // Override the IDs to match
        context.insert(sdA)
        context.insert(sdB)

        let versionBefore = state.graphDataVersion

        state.connectNodes(
            sourceId: "a",
            targetId: "b",
            edgeType: .related,
            context: context
        )

        // Incremental path: pendingEdgeAdds should have the new edge
        #expect(state.pendingEdgeAdds.count == 1)
        #expect(state.pendingEdgeAdds.first?.sourceNodeId == "a")
        #expect(state.pendingEdgeAdds.first?.targetNodeId == "b")

        // graphDataVersion should NOT increment (no full recommit)
        #expect(state.graphDataVersion == versionBefore)
    }

    // MARK: - createConnectedNode uses incremental path for non-note types

    @Test("createConnectedNode for non-note uses incremental add")
    func createConnectedNodeIncrementalPath() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let state = GraphState()

        // Pre-populate an existing node
        let existing = makeNode(id: "existing", label: "Existing")
        state.store.addNode(existing)

        state.createConnectedNode(
            type: .idea,
            label: "New Idea",
            connectedTo: "existing",
            edgeType: .related,
            atWorldPosition: SIMD2<Float>(100, 100),
            context: context
        )

        // Both node and edge should be in pending queues
        #expect(state.pendingNodeAdds.count == 1)
        #expect(state.pendingNodeAdds.first?.label == "New Idea")
        #expect(state.pendingNodeAdds.first?.type == .idea)
        #expect(state.pendingEdgeAdds.count == 1)
    }

    // MARK: - Edge Cases (Gate 4)

    @Test("Unicode labels in incremental adds")
    func unicodeLabels() {
        let state = GraphState()
        let node = makeNode(id: "emoji", label: "🧠 Knowledge Graph 日本語")
        state.requestIncrementalAdd(node: node)

        #expect(state.pendingNodeAdds.count == 1)
        #expect(state.pendingNodeAdds.first?.label == "🧠 Knowledge Graph 日本語")
    }

    @Test("self-loop edge rejected by connectNodes")
    func selfLoopRejected() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let state = GraphState()

        let node = makeNode(id: "same", label: "Same Node")
        state.store.addNode(node)

        state.connectNodes(
            sourceId: "same",
            targetId: "same",
            edgeType: .related,
            context: context
        )

        // Self-loop should be rejected — no edge added
        #expect(state.pendingEdgeAdds.isEmpty)
    }

    @Test("empty label rejected by createNode")
    func emptyLabelRejected() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let state = GraphState()

        state.createNode(
            type: .tag,
            label: "   ",
            atWorldPosition: .zero,
            context: context
        )

        // Sanitized empty label should be rejected
        #expect(state.pendingNodeAdds.isEmpty)
        #expect(state.store.nodeCount == 0)
    }

    @Test("large batch of incremental adds accumulates correctly")
    func largeBatch() {
        let state = GraphState()

        for i in 0..<500 {
            state.requestIncrementalAdd(node: makeNode(id: "n\(i)", label: "Node \(i)"))
        }
        for i in 0..<499 {
            state.requestIncrementalAddEdge(makeEdge(id: "e\(i)", source: "n\(i)", target: "n\(i + 1)"))
        }

        #expect(state.pendingNodeAdds.count == 500)
        #expect(state.pendingEdgeAdds.count == 499)
    }

    @Test("removeAll clears pending queues")
    func removeAllClears() {
        let state = GraphState()
        state.requestIncrementalAdd(node: makeNode(id: "a"))
        state.requestIncrementalAdd(node: makeNode(id: "b"))
        state.requestIncrementalAddEdge(makeEdge())

        state.pendingNodeAdds.removeAll()
        state.pendingEdgeAdds.removeAll()

        #expect(state.pendingNodeAdds.isEmpty)
        #expect(state.pendingEdgeAdds.isEmpty)
    }

    @Test("all node types work with incremental add")
    func allNodeTypes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let state = GraphState()

        let nonNoteTypes: [GraphNodeType] = [.tag, .idea, .source, .folder, .quote, .block, .chat]
        for (i, nodeType) in nonNoteTypes.enumerated() {
            state.createNode(
                type: nodeType,
                label: "Node \(i)",
                atWorldPosition: SIMD2<Float>(Float(i) * 10, 0),
                context: context
            )
        }

        // All non-note types should use incremental path
        #expect(state.pendingNodeAdds.count == nonNoteTypes.count)
        for (i, nodeType) in nonNoteTypes.enumerated() {
            #expect(state.pendingNodeAdds[i].type == nodeType)
        }
    }
}
