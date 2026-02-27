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
        case .observatory:   return 0.55
        case .nebula:        return 0.35
        case .crystal:       return 0.75
        case .fluid:         return 0.30
        case .constellation: return 0.45
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
    var warmth: Float {
        switch self {
        case .observatory:   return 0
        case .nebula:        return 0.4
        case .crystal:       return 0
        case .fluid:         return 0.6
        case .constellation: return 0.2
        }
    }
    var orbital: Float {
        switch self {
        case .observatory:   return 0
        case .nebula:        return 0.3
        case .crystal:       return 0
        case .fluid:         return 0.15
        case .constellation: return 0.1
        }
    }
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

    /// Set to true to request the overlay minimize to a floating window.
    var pendingMinimize = false

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
    var velocityDecay: Float = 0.55
    /// Center gravity pull strength (0 = none, 0.2 = strong).
    var centerStrength: Float = 0.005
    /// Collision buffer zone in pixels.
    var collisionRadius: Float = 35.0
    /// Warmth: subtle perturbation keeping settled graphs alive (0 = still, 1 = gentle drift).
    var warmth: Float = 0.0
    /// Orbital: rotational micro-force for breathing effect (0 = off, 1 = gentle spin).
    var orbital: Float = 0.0

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

    // ── Labels ──
    var labelsEnabled: Bool = true
    var labelFadeStart: Float = 6.0
    var labelFadeEnd: Float = 18.0
    var labelFontSize: Float = 12.0

    var labelConfigVersion: Int = 0

    func pushLabelChange() {
        labelConfigVersion += 1
    }

    /// Apply a named physics preset.
    func applyPreset(_ preset: PhysicsPreset) {
        linkDistance = preset.linkDistance
        chargeStrength = preset.chargeStrength
        chargeRange = preset.chargeRange
        linkStrength = preset.linkStrength
        velocityDecay = preset.velocityDecay
        centerStrength = preset.centerStrength
        collisionRadius = preset.collisionRadius
        warmth = preset.warmth
        orbital = preset.orbital
        pushForceChange()
        pushExtendedForceChange()
    }

    // MARK: - Neighbor Highlight

    /// UUID of the node whose neighbors are highlighted (shift+click).
    var highlightedNodeId: String?

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
        loadGraph(context: context)
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

        let body = page.body
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

    // MARK: - AI Entity Extraction

    func scanVault(context: ModelContext, llmService: LLMService) {
        Task {
            let extractor = EntityExtractor(graphState: self)
            await extractor.scanVault(context: context, llmService: llmService)
        }
    }
}
