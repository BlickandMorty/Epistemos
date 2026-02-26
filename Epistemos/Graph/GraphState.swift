import Foundation
import SwiftData

// MARK: - GraphState
// Observable coordinator that owns the graph engine components (store, filter).
// Physics and rendering are handled by the Rust engine via Metal.
// Injected into the environment for the graph window and its subviews.

@MainActor @Observable
final class GraphState {
    let store = GraphStore()
    let filter = FilterEngine()

    var isLoaded = false
    var isScanning = false
    var scanProgress: Double = 0  // 0.0-1.0
    var scanStatus: String = ""
    var selectedNodeId: String?
    private var isBuildingStructural = false

    /// Set to true when notes change — the graph window checks this on appear and refreshes structural data.
    var needsRefresh = false

    // MARK: - Pending Scene Actions

    /// Set to true to request the Metal canvas reset its camera view.
    var pendingResetView = false

    /// Set to a node ID to request the Metal canvas center its camera on that node.
    var pendingCenterNodeId: String?

    // MARK: - Loading

    func loadGraph(context: ModelContext) {
        do {
            try store.load(context: context)
        } catch {
            Log.app.error("GraphState: failed to load graph: \(error.localizedDescription, privacy: .public)")
            return
        }

        // If empty and not already building, auto-build from structural data.
        // The guard prevents infinite recursion: buildStructuralGraph → loadGraph → buildStructuralGraph...
        if store.nodeCount == 0, !isBuildingStructural {
            buildStructuralGraph(context: context)
            return
        }

        // Physics and rendering are driven by the Rust engine.
        // Data is pushed to the engine via GraphBridge when the MetalGraphView appears.
        isLoaded = true
    }

    // MARK: - Structural Graph

    /// Build the graph skeleton from existing structured data (no AI needed).
    func buildStructuralGraph(context: ModelContext) {
        guard !isBuildingStructural else { return }
        isBuildingStructural = true
        defer { isBuildingStructural = false }

        let builder = StructuralGraphBuilder()
        let result = builder.build(context: context)
        builder.persist(nodes: result.nodes, edges: result.edges, context: context)
        loadGraph(context: context)
    }

    // MARK: - Structural Refresh

    /// Lightweight refresh: re-runs the structural graph builder to pick up new/deleted pages,
    /// ideas, tags, etc. Does NOT run AI extraction — just deterministic edges.
    func refreshStructuralData(context: ModelContext) {
        needsRefresh = false
        buildStructuralGraph(context: context)
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

    // MARK: - AI Entity Extraction

    /// Scan the vault using AI to extract thinkers, concepts, quotes, sources, and insights.
    func scanVault(context: ModelContext, llmService: LLMService) {
        Task {
            let extractor = EntityExtractor(graphState: self)
            await extractor.scanVault(context: context, llmService: llmService)
        }
    }
}
