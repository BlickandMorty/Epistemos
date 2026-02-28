import Foundation
import SwiftData

// MARK: - GraphMode
// Two graph views matching LogSeq: global (all nodes) and page (node + neighbors).

enum GraphMode: Sendable {
    case global
    case page(nodeId: String)
}

// MARK: - Physics Presets

enum PhysicsPreset: String, CaseIterable, Identifiable {
    case observatory = "Observatory"     // Default — spread out, calm
    case nebula = "Nebula"               // Loose, floaty, gentle drift
    case crystal = "Crystal"             // Tight, structured, snappy
    case fluid = "Fluid"                 // Bouncy, dynamic, alive
    case constellation = "Constellation" // Very spread, minimal gravity

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .observatory:   return "moonphase.waning.gibbous"
        case .nebula:        return "cloud"
        case .crystal:       return "diamond"
        case .fluid:         return "drop"
        case .constellation: return "sparkles"
        }
    }

    var description: String {
        switch self {
        case .observatory:   return "Balanced spread, calm settling"
        case .nebula:        return "Loose clusters, gentle drift"
        case .crystal:       return "Tight structure, snappy response"
        case .fluid:         return "Bouncy, dynamic, alive"
        case .constellation: return "Wide spread, minimal gravity"
        }
    }

    var linkDistance: Float {
        switch self {
        case .observatory:   return 250
        case .nebula:        return 350
        case .crystal:       return 120
        case .fluid:         return 200
        case .constellation: return 400
        }
    }
    var chargeStrength: Float {
        switch self {
        case .observatory:   return -1200
        case .nebula:        return -800
        case .crystal:       return -2000
        case .fluid:         return -1000
        case .constellation: return -600
        }
    }
    var chargeRange: Float {
        switch self {
        case .observatory:   return 2000
        case .nebula:        return 1500
        case .crystal:       return 1000
        case .fluid:         return 1200
        case .constellation: return 2000
        }
    }
    var linkStrength: Float { 0 } // Always auto

    var velocityDecay: Float {
        switch self {
        case .observatory:   return 0.70
        case .nebula:        return 0.50
        case .crystal:       return 0.80
        case .fluid:         return 0.40
        case .constellation: return 0.55
        }
    }
    var centerStrength: Float {
        switch self {
        case .observatory:   return 0.005
        case .nebula:        return 0.002
        case .crystal:       return 0.02
        case .fluid:         return 0.008
        case .constellation: return 0.001
        }
    }
    var collisionRadius: Float {
        switch self {
        case .observatory:   return 35
        case .nebula:        return 25
        case .crystal:       return 45
        case .fluid:         return 30
        case .constellation: return 20
        }
    }
}

// MARK: - GraphInteractionMode
// Tracks whether the user is idle or mid-connection-drag in the graph canvas.

enum GraphInteractionMode: Equatable {
    case idle
    case connecting(sourceNodeId: String)
}

// MARK: - GraphState
// Observable coordinator that owns the graph engine components (store, filter).
// Physics and rendering are handled by the Rust engine via Metal.
// Injected into the environment for the hologram overlay and its subviews.

@MainActor @Observable
final class GraphState {
    let store = GraphStore()
    let filter = FilterEngine()

    var isLoaded = false
    /// True after the entrance animation has played once. Prevents replay on re-open.
    var hasPlayedEntrance = false
    var isScanning = false
    var scanProgress: Double = 0  // 0.0-1.0
    var scanStatus: String = ""
    var selectedNodeId: String?
    private var isBuildingStructural = false

    /// Set to true when notes change — the graph refreshes structural data on next appear.
    var needsRefresh = false

    // MARK: - Graph Mode

    var mode: GraphMode = .global

    // MARK: - Pending Scene Actions

    /// Set to true to request the Metal canvas reset its camera view.
    var pendingResetView = false

    /// Set to a node ID to request the Metal canvas center its camera on that node.
    var pendingCenterNodeId: String?

    /// Incremented when mode/filter changes require the Rust engine to re-commit graph data.
    /// The MetalGraphNSView render loop detects this and triggers a full re-commit.
    var graphDataVersion: Int = 0

    func requestRecommit() { graphDataVersion += 1 }

    /// Incremented when filter toggles require a lightweight visibility refresh.
    /// Unlike graphDataVersion (full recommit), this only toggles node visibility in Rust.
    var filterVersion: Int = 0

    func requestFilterSync() { filterVersion += 1 }

    /// Set to true when the rebuild button is pressed while graph is visible.
    var pendingRebuild = false

    /// Set to true to request the overlay minimize to a floating window.
    var pendingMinimize = false

    /// Set to true to request the overlay close completely.
    var pendingClose = false

    // MARK: - Force Parameters
    // Core 4 params (basic panel) + 5 extended params (advanced panel).
    // The Rust engine receives core via graph_engine_set_force_params(),
    // extended via graph_engine_set_extended_force_params().

    // ── Core ──
    /// Natural resting length of edge springs.
    var linkDistance: Float = 250.0
    /// Many-body charge strength (negative = repulsion).
    var chargeStrength: Float = -1200.0
    /// Maximum range for many-body repulsion.
    var chargeRange: Float = 2000.0
    /// Link spring strength. 0 = auto (1 / min(degree)).
    var linkStrength: Float = 0.0

    // ── Extended ──
    /// Velocity damping (0 = no friction/bouncy, 0.95 = viscous).
    var velocityDecay: Float = 0.70
    /// Center gravity pull strength (0 = none, 0.2 = strong).
    var centerStrength: Float = 0.005
    /// Collision buffer zone in pixels.
    var collisionRadius: Float = 35.0

    /// Incremented whenever a force slider changes, so the Metal view can detect it.
    var forceConfigVersion: Int = 0
    /// Incremented for extended params independently.
    var extendedForceConfigVersion: Int = 0

    func pushForceChange() {
        forceConfigVersion += 1
    }

    func pushExtendedForceChange() {
        extendedForceConfigVersion += 1
    }

    // ── Cluster ──
    var clusterStrength: Float = 0.3
    var centerMode: UInt8 = 0  // 0=attract, 1=off, 2=repel

    var clusterConfigVersion: Int = 0
    func pushClusterChange() { clusterConfigVersion += 1 }

    /// Apply a named physics preset.
    func applyPreset(_ preset: PhysicsPreset) {
        linkDistance = preset.linkDistance
        chargeStrength = preset.chargeStrength
        chargeRange = preset.chargeRange
        linkStrength = preset.linkStrength
        velocityDecay = preset.velocityDecay
        centerStrength = preset.centerStrength
        collisionRadius = preset.collisionRadius
        pushForceChange()
        pushExtendedForceChange()
    }

    // MARK: - Semantic Clustering

    /// When true, uses NLEmbedding-based semantic clusters instead of Louvain topology clusters.
    var useSemanticClustering = false

    /// Cached semantic cluster IDs (nodeId → clusterId). Recomputed when graph data changes.
    private(set) var semanticClusterIds: [String: UInt32] = [:]

    /// Incremented when semantic cluster IDs change, so MetalGraphNSView can push them to Rust.
    var semanticClusterVersion: Int = 0

    /// Compute semantic clusters from the current graph store and cache the result.
    func computeSemanticClusters() {
        semanticClusterIds = SemanticClusterService.computeClusters(store: store)
        semanticClusterVersion += 1
    }

    // MARK: - Interactive Creation

    var interactionMode: GraphInteractionMode = .idle

    /// ModelContext for graph mutations. Set during AppBootstrap setup.
    var modelContext: ModelContext?

    var isConnecting: Bool {
        if case .connecting = interactionMode { return true }
        return false
    }

    func beginConnecting(from nodeId: String) {
        interactionMode = .connecting(sourceNodeId: nodeId)
    }

    func cancelConnecting() {
        interactionMode = .idle
    }

    // MARK: - Loading

    func loadGraph(context: ModelContext) {
        do {
            try store.load(context: context)
        } catch {
            Log.app.error("GraphState: failed to load graph: \(error.localizedDescription, privacy: .public)")
            return
        }

        // If empty and not already building, auto-build from structural data.
        if store.nodeCount == 0, !isBuildingStructural {
            buildStructuralGraph(context: context)
            return
        }

        isLoaded = true
    }

    // MARK: - Structural Graph

    func buildStructuralGraph(context: ModelContext) {
        guard !isBuildingStructural else { return }
        isBuildingStructural = true
        defer { isBuildingStructural = false }

        let builder = GraphBuilder()
        let result = builder.build(context: context)
        builder.persist(nodes: result.nodes, edges: result.edges, context: context)

        // Reload from SwiftData to get the actual persisted state (diff-based persist
        // keeps existing node IDs stable, so we must fetch the real persisted objects).
        do {
            try store.load(context: context)
        } catch {
            Log.app.error("GraphState: failed to reload graph after rebuild: \(error.localizedDescription, privacy: .public)")
        }
        isLoaded = true
    }

    /// Lightweight refresh: re-runs the structural graph builder to pick up new/deleted pages.
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

    // MARK: - Page Mode — Ephemeral Subgraph

    /// IDs of ephemeral nodes created for page mode (removed on mode switch).
    private(set) var ephemeralNodeIds = Set<String>()

    /// Build ephemeral quote and source nodes from the active note's markdown body.
    /// Wikilinks are resolved to existing graph nodes; blockquotes and links become new nodes.
    func buildPageSubgraph(for pageId: String, context: ModelContext) {
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == pageId }
        )
        guard let page = try? context.fetch(descriptor).first else { return }
        guard let pageNodeId = store.node(bySourceId: pageId, type: .note)?.id else { return }

        let body = page.loadBody()
        guard !body.isEmpty else { return }
        guard let cStr = body.cString(using: .utf8) else { return }

        var spansPtr: UnsafeMutablePointer<StyleSpan>?
        var count: UInt32 = 0
        let result = markdown_parse(cStr, UInt32(cStr.count - 1), &spansPtr, &count)
        guard result == 0, let spans = spansPtr, count > 0 else { return }
        defer { markdown_free_spans(spans, count) }

        // UTF-8 bytes for slicing by byte offset.
        let utf8Bytes: [UInt8] = Array(body.utf8)
        let createdAt = page.createdAt

        for i in 0..<Int(count) {
            let span = spans[i]
            let start = Int(span.start)
            let end = Int(span.end)
            guard end <= utf8Bytes.count else { continue }

            switch span.style {
            case 10: // BlockQuote — create ephemeral quote node
                let slice = Array(utf8Bytes[start..<end])
                guard let raw = String(bytes: slice, encoding: .utf8) else { continue }
                let label = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
                guard !label.isEmpty else { continue }
                addEphemeralNode(
                    id: "ephemeral-quote-\(start)", type: .quote, label: label,
                    parentId: pageNodeId, edgeType: .contains, createdAt: createdAt
                )

            case 17: // MarkdownLink — create ephemeral source node
                let slice = Array(utf8Bytes[start..<end])
                guard let linkText = String(bytes: slice, encoding: .utf8) else { continue }
                // Extract URL from [text](url).
                var label = linkText
                if let op = linkText.firstIndex(of: "("),
                   let cp = linkText.lastIndex(of: ")") {
                    label = String(linkText[linkText.index(after: op)..<cp])
                }
                guard !label.isEmpty else { continue }
                let truncated = String(label.prefix(60))
                addEphemeralNode(
                    id: "ephemeral-source-\(start)", type: .source, label: truncated,
                    parentId: pageNodeId, edgeType: .reference, createdAt: createdAt
                )

            case 15: // Wikilink — resolve to existing note node and add edge
                let slice = Array(utf8Bytes[start..<end])
                guard let raw = String(bytes: slice, encoding: .utf8) else { continue }
                let target = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !target.isEmpty else { continue }
                resolveWikilinkEdge(target: target, from: pageNodeId, byteOffset: start, createdAt: createdAt)

            default:
                break
            }
        }

        // Re-run focus to include new ephemeral nodes.
        let connected = store.connected(to: pageNodeId, maxDepth: 2)
        filter.focusOn(nodeId: pageNodeId, connectedSet: connected)
    }

    /// Add an ephemeral node connected to a parent node.
    private func addEphemeralNode(
        id: String, type: GraphNodeType, label: String,
        parentId: String, edgeType: GraphEdgeType, createdAt: Date
    ) {
        let pos = SIMD2<Float>(Float.random(in: -100...100), Float.random(in: -100...100))
        let node = GraphNodeRecord(
            id: id, type: type, label: label, sourceId: nil,
            metadata: GraphNodeMetadata(), weight: 1.0,
            createdAt: createdAt, position: pos
        )
        store.addNode(node)
        let edge = GraphEdgeRecord(
            id: "edge-\(id)", sourceNodeId: parentId, targetNodeId: id,
            type: edgeType, weight: 1.0, createdAt: createdAt
        )
        store.addEdge(edge)
        ephemeralNodeIds.insert(id)
    }

    /// Resolve a wikilink target to an existing note node and create an edge.
    private func resolveWikilinkEdge(target: String, from pageNodeId: String, byteOffset: Int, createdAt: Date) {
        // Find graph node by label (case-insensitive).
        let match = store.nodes.values.first { node in
            node.type == .note && node.label.caseInsensitiveCompare(target) == .orderedSame
        }
        guard let linkedNode = match else { return }

        // Skip if already connected.
        let existing = store.edges(for: pageNodeId)
        let alreadyLinked = existing.contains { edge in
            (edge.sourceNodeId == pageNodeId && edge.targetNodeId == linkedNode.id)
            || (edge.sourceNodeId == linkedNode.id && edge.targetNodeId == pageNodeId)
        }
        guard !alreadyLinked else { return }

        let edgeId = "ephemeral-edge-wiki-\(byteOffset)"
        let edge = GraphEdgeRecord(
            id: edgeId, sourceNodeId: pageNodeId, targetNodeId: linkedNode.id,
            type: .reference, weight: 1.0, createdAt: createdAt
        )
        store.addEdge(edge)
    }

    /// Remove all ephemeral nodes (and their edges) created for page mode.
    func cleanupEphemeralNodes() {
        for nodeId in ephemeralNodeIds {
            store.removeNode(nodeId)
        }
        ephemeralNodeIds.removeAll()
    }

    // MARK: - Node / Edge Creation

    /// Sanitize a user-provided label for safe use as a node name and C string.
    private func sanitizeLabel(_ raw: String) -> String? {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\0", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let capped = String(trimmed.prefix(200))
        return capped.isEmpty ? nil : capped
    }

    /// Create an orphan node at a world position.
    func createNode(
        type: GraphNodeType,
        label: String,
        atWorldPosition position: SIMD2<Float>,
        context: ModelContext
    ) {
        guard let safeLabel = sanitizeLabel(label) else { return }
        let sdNode = SDGraphNode(type: type, label: safeLabel)
        sdNode.isManual = true
        context.insert(sdNode)

        // Place at clicked position
        store.positionHints[sdNode.id] = position

        if type == .note {
            // Notes need a backing .md file — structural rebuild needed to pick up the new page.
            Task { @MainActor in
                if let pageId = await AppBootstrap.shared?.vaultSync.createPage(title: label) {
                    sdNode.sourceId = pageId
                    try? context.save()
                }
                buildStructuralGraph(context: context)
                requestRecommit()
            }
        } else {
            try? context.save()
            // Manual non-note nodes don't affect structural data — just add to store and recommit.
            let record = GraphNodeRecord(
                id: sdNode.id,
                type: sdNode.nodeType,
                label: sdNode.label,
                sourceId: sdNode.sourceId,
                metadata: sdNode.meta,
                weight: sdNode.weight,
                createdAt: sdNode.createdAt,
                position: position,
                velocity: .zero
            )
            store.addNode(record)
            requestRecommit()
        }
    }

    /// Create a node connected to an existing node.
    func createConnectedNode(
        type: GraphNodeType,
        label: String,
        connectedTo existingNodeId: String,
        edgeType: GraphEdgeType,
        atWorldPosition position: SIMD2<Float>,
        context: ModelContext
    ) {
        guard let safeLabel = sanitizeLabel(label) else { return }
        let sdNode = SDGraphNode(type: type, label: safeLabel)
        sdNode.isManual = true
        context.insert(sdNode)

        let sdEdge = SDGraphEdge(source: existingNodeId, target: sdNode.id, type: edgeType)
        sdEdge.isManual = true
        context.insert(sdEdge)

        store.positionHints[sdNode.id] = position

        if type == .note {
            // Notes need a backing .md file — structural rebuild needed to pick up the new page.
            Task { @MainActor in
                if let pageId = await AppBootstrap.shared?.vaultSync.createPage(title: label) {
                    sdNode.sourceId = pageId
                    try? context.save()
                }
                buildStructuralGraph(context: context)
                requestRecommit()
            }
        } else {
            try? context.save()
            // Manual non-note nodes don't affect structural data — add directly to store.
            let record = GraphNodeRecord(
                id: sdNode.id,
                type: sdNode.nodeType,
                label: sdNode.label,
                sourceId: sdNode.sourceId,
                metadata: sdNode.meta,
                weight: sdNode.weight,
                createdAt: sdNode.createdAt,
                position: position,
                velocity: .zero
            )
            store.addNode(record)
            let edgeRecord = GraphEdgeRecord(
                id: sdEdge.id,
                sourceNodeId: sdEdge.sourceNodeId,
                targetNodeId: sdEdge.targetNodeId,
                type: sdEdge.edgeType,
                weight: sdEdge.weight,
                createdAt: sdEdge.createdAt
            )
            store.addEdge(edgeRecord)
            requestRecommit()
        }
    }

    /// Connect two existing nodes with an edge.
    func connectNodes(
        sourceId: String,
        targetId: String,
        edgeType: GraphEdgeType,
        context: ModelContext
    ) {
        guard sourceId != targetId else {
            interactionMode = .idle
            return
        }
        guard store.nodes[sourceId] != nil, store.nodes[targetId] != nil else {
            interactionMode = .idle
            return
        }

        let sdEdge = SDGraphEdge(source: sourceId, target: targetId, type: edgeType)
        sdEdge.isManual = true
        context.insert(sdEdge)
        try? context.save()

        // Manual edge — add directly to store without full structural rebuild.
        let edgeRecord = GraphEdgeRecord(
            id: sdEdge.id,
            sourceNodeId: sdEdge.sourceNodeId,
            targetNodeId: sdEdge.targetNodeId,
            type: sdEdge.edgeType,
            weight: sdEdge.weight,
            createdAt: sdEdge.createdAt
        )
        store.addEdge(edgeRecord)
        requestRecommit()
        interactionMode = .idle
    }

    // MARK: - AI Entity Extraction

    func scanVault(context: ModelContext, llmService: any LLMClientProtocol) {
        Task {
            let extractor = EntityExtractor(graphState: self)
            await extractor.scanVault(context: context, llmService: llmService)
        }
    }
}
