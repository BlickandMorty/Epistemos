import Foundation
import SwiftData

// MARK: - GraphState
// Observable coordinator that owns the graph engine components (store, filter, simulation).
// Injected into the environment for the graph window and its subviews.

@MainActor @Observable
final class GraphState {
    let store = GraphStore()
    let filter = FilterEngine()
    let simulation = ForceSimulation()

    var isLoaded = false
    var isScanning = false
    var scanProgress: Double = 0  // 0.0-1.0
    var scanStatus: String = ""
    var selectedNodeId: String?

    // MARK: - Loading

    func loadGraph(context: ModelContext) {
        do {
            try store.load(context: context)
        } catch {
            Log.app.error("GraphState: failed to load graph: \(error.localizedDescription, privacy: .public)")
            return
        }

        // If empty, auto-build from structural data (notes, folders, ideas, chats, tags)
        if store.nodeCount == 0 {
            buildStructuralGraph(context: context)
            return  // buildStructuralGraph calls loadGraph again
        }

        // Feed topology into simulation
        let simNodes = store.nodes.values.map { (id: $0.id, position: $0.position, weight: Float($0.weight)) }
        let simEdges = store.edges.values.map { (source: $0.sourceNodeId, target: $0.targetNodeId, weight: Float($0.weight)) }
        Task { await simulation.load(nodes: simNodes, edges: simEdges) }
        isLoaded = true
    }

    // MARK: - Structural Graph

    /// Build the graph skeleton from existing structured data (no AI needed).
    func buildStructuralGraph(context: ModelContext) {
        let builder = StructuralGraphBuilder()
        let result = builder.build(context: context)
        builder.persist(nodes: result.nodes, edges: result.edges, context: context)
        loadGraph(context: context)
    }

    // MARK: - Selection

    func selectNode(_ id: String?) { selectedNodeId = id }

    var selectedNode: GraphNodeRecord? {
        guard let id = selectedNodeId else { return nil }
        return store.nodes[id]
    }

    // MARK: - Focus

    func focusOnNode(_ nodeId: String, depth: Int = 3) {
        let connected = store.connected(to: nodeId, maxDepth: depth)
        filter.focusOn(nodeId: nodeId, connectedSet: connected)
    }

    func clearFocus() { filter.clearFocus() }
}
