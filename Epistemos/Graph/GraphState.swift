import Foundation
import NaturalLanguage
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
        case .observatory:   return 200
        case .nebula:        return 280
        case .crystal:       return 120
        case .fluid:         return 180
        case .constellation: return 350
        }
    }
    var chargeStrength: Float {
        switch self {
        case .observatory:   return -400
        case .nebula:        return -250
        case .crystal:       return -600
        case .fluid:         return -350
        case .constellation: return -200
        }
    }
    var chargeRange: Float {
        switch self {
        case .observatory:   return 1500
        case .nebula:        return 1200
        case .crystal:       return 800
        case .fluid:         return 1000
        case .constellation: return 1500
        }
    }
    var linkStrength: Float { 0 } // Always auto

    var velocityDecay: Float {
        switch self {
        case .observatory:   return 0.85
        case .nebula:        return 0.80
        case .crystal:       return 0.90
        case .fluid:         return 0.75
        case .constellation: return 0.82
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
        case .observatory:   return 20
        case .nebula:        return 15
        case .crystal:       return 30
        case .fluid:         return 18
        case .constellation: return 12
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

    /// Rust engine handle set by MetalGraphNSView after engine creation.
    /// Used for Rust-side search and other FFI calls from Swift.
    /// Marked nonisolated(unsafe) so MetalGraphNSView.deinit can nil it synchronously
    /// before calling graph_engine_destroy, preventing use-after-free races.
    nonisolated(unsafe) var engineHandle: OpaquePointer?

    /// True when physics is completely disabled (graph > 1500 visible nodes).
    /// Updated after each commit/refresh cycle. UI uses this to grey out physics controls.
    var isStaticLayout: Bool = false

    /// The threshold above which physics is disabled. Shown in the UI tooltip.
    static let staticLayoutThreshold = 1500

    /// Embedding service for semantic similarity (NLEmbedding → Rust SIMD).
    let embeddingService: EmbeddingService

    init() {
        let svc = EmbeddingService()
        self.embeddingService = svc
        svc.graphState = self
    }

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

    // MARK: - Quality Level

    /// Graph rendering quality: 0 = Cinematic, 1 = Balanced, 2 = Performance.
    /// Cinematic: all effects (glow, breathing, perspective, field lines).
    /// Balanced: sphere shading, no animation/glow.
    /// Performance: flat circles, minimal GPU cost.
    var qualityLevel: UInt8 = UInt8(UserDefaults.standard.integer(forKey: "epistemos.graph.qualityLevel")) {
        didSet { UserDefaults.standard.set(Int(qualityLevel), forKey: "epistemos.graph.qualityLevel"); liteModeVersion += 1 }
    }

    /// Backwards-compatible getter for code that checks liteMode.
    var liteMode: Bool { qualityLevel >= 2 }

    /// Incremented when quality changes so MetalGraphView can detect and push to Rust.
    var liteModeVersion: Int = 0

    // MARK: - Force Parameters
    // Core 4 params (basic panel) + 5 extended params (advanced panel).
    // The Rust engine receives core via graph_engine_set_force_params(),
    // extended via graph_engine_set_extended_force_params().

    // ── Core ──
    /// Natural resting length of edge springs.
    var linkDistance: Float = 200.0
    /// Many-body charge strength (negative = repulsion).
    var chargeStrength: Float = -400.0
    /// Maximum range for many-body repulsion.
    var chargeRange: Float = 1500.0
    /// Link spring strength. 0 = auto (1 / min(degree)).
    var linkStrength: Float = 0.0

    // ── Extended ──
    /// Velocity damping (0 = no friction/bouncy, 0.95 = viscous).
    var velocityDecay: Float = 0.85
    /// Center gravity pull strength (0 = none, 0.2 = strong).
    var centerStrength: Float = 0.005
    /// Collision buffer zone in pixels.
    var collisionRadius: Float = 20.0

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
    var clusterStrength: Float = 0.15
    var centerMode: UInt8 = 0  // 0=attract, 1=off, 2=repel
    var semanticStrength: Float = 0.0

    // ── Time-Travel ──
    /// Computed date range of all graph nodes. Set during commit.
    var timeRangeStart: Date = .distantPast
    var timeRangeEnd: Date = .now
    /// Whether the time slider is currently visible.
    var showTimeSlider = false
    /// Current time filter cutoff. Nodes created after this are hidden.
    var timeCutoff: Date = .distantFuture

    var clusterConfigVersion: Int = 0
    func pushClusterChange() { clusterConfigVersion += 1 }
    func pushSemanticChange() {
        guard let engine = engineHandle else { return }
        graph_engine_set_semantic_strength(engine, semanticStrength)
    }

    /// Compute the date range of all nodes in the store (for time slider bounds).
    func computeTimeRange() {
        var earliest: Date = .distantFuture
        var latest: Date = .distantPast
        for (_, node) in store.nodes {
            if node.createdAt < earliest { earliest = node.createdAt }
            if node.createdAt > latest { latest = node.createdAt }
        }
        if earliest > latest {
            earliest = .distantPast
            latest = .now
        }
        timeRangeStart = earliest
        timeRangeEnd = latest
        timeCutoff = latest
    }

    /// Apply time filter to the Rust engine. Nodes created after cutoff are hidden.
    func applyTimeFilter(_ cutoff: Date) {
        timeCutoff = cutoff
        guard let engine = engineHandle else { return }
        graph_engine_set_time_filter(engine, 0.0, cutoff.timeIntervalSince1970)
    }

    /// Clear the time filter (show all nodes).
    func clearTimeFilter() {
        timeCutoff = .distantFuture
        showTimeSlider = false
        guard let engine = engineHandle else { return }
        graph_engine_set_time_filter(engine, 0.0, 1e18)
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

    // MARK: - Rust Search

    /// Search node labels via the Rust engine's FST index (sub-1ms, typo-tolerant).
    /// Falls back to Swift-side `GraphStore.fuzzySearch()` when engine isn't available.
    func rustSearch(query: String, limit: Int = 20) -> [GraphStore.SearchHit] {
        guard !query.isEmpty else { return [] }

        // Try Rust-side search via FFI
        if let engine = engineHandle {
            var count: UInt32 = 0
            guard let cQuery = query.cString(using: .utf8) else { return store.fuzzySearch(query: query, limit: limit) }
            let results = graph_engine_search(engine, cQuery, UInt32(limit), &count)
            defer { graph_engine_free_search_results(results, count) }

            if let results, count > 0 {
                var hits: [GraphStore.SearchHit] = []
                for i in 0..<Int(count) {
                    let r = results[i]
                    let uuid = r.uuid.map { String(cString: $0) } ?? ""
                    let score = r.score

                    // Look up the GraphNodeRecord by matching sourceId or id
                    if let node = store.nodes[uuid] {
                        hits.append(GraphStore.SearchHit(id: node.id, node: node, score: score))
                    }
                }
                return hits
            }
        }

        // Fallback to Swift-side search
        return store.fuzzySearch(query: query, limit: limit)
    }

    /// Hybrid search: combines text (Rust FST) + semantic (embedding cosine) results.
    /// Semantic-only matches get 0.7× score weight (text match is stronger signal).
    func hybridSearch(query: String, limit: Int = 20) -> [GraphStore.SearchHit] {
        guard !query.isEmpty else { return [] }

        // Text search
        let textHits = rustSearch(query: query, limit: limit)
        var hitMap: [String: GraphStore.SearchHit] = [:]
        for hit in textHits {
            hitMap[hit.id] = hit
        }

        // Semantic search: embed the query text, then ask Rust for similar nodes
        if let engine = engineHandle, embeddingService.dimension > 0,
           let nlEmbedding = NLEmbedding.wordEmbedding(for: .english)
        {
            let words = query.lowercased()
                .components(separatedBy: .alphanumerics.inverted)
                .filter { $0.count > 1 }

            var queryVec = [Float](repeating: 0, count: embeddingService.dimension)
            var wordCount = 0
            for word in words {
                if let vec = nlEmbedding.vector(for: word) {
                    for (i, v) in vec.enumerated() {
                        queryVec[i] += Float(v)
                    }
                    wordCount += 1
                }
            }

            if wordCount > 0 {
                let scale = 1.0 / Float(wordCount)
                queryVec = queryVec.map { $0 * scale }

                var count: UInt32 = 0
                let results = queryVec.withUnsafeBufferPointer { buf in
                    graph_engine_semantic_search(
                        engine, buf.baseAddress!, UInt32(embeddingService.dimension),
                        UInt32(limit), &count
                    )
                }
                defer { graph_engine_free_search_results(results, count) }

                if let results, count > 0 {
                    for i in 0..<Int(count) {
                        let r = results[i]
                        let uuid = r.uuid.map { String(cString: $0) } ?? ""
                        if hitMap[uuid] == nil, let node = store.nodes[uuid] {
                            // Semantic-only match: 0.7× weight
                            hitMap[uuid] = GraphStore.SearchHit(
                                id: node.id, node: node, score: r.score * 0.7
                            )
                        }
                    }
                }
            }
        }

        // Sort by score descending, limit
        return Array(hitMap.values)
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    /// Highlight search matches in the graph — dims non-matching nodes.
    /// Pass empty string to clear highlight.
    func searchHighlight(_ query: String) {
        guard let engine = engineHandle else { return }
        if let cQuery = query.cString(using: .utf8) {
            graph_engine_search_highlight(engine, cQuery)
        }
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
                if let pageId = await AppBootstrap.shared?.vaultSync.createPage(title: safeLabel) {
                    sdNode.sourceId = pageId
                    do { try context.save() } catch { Log.db.error("GraphState: context.save() failed — \(error.localizedDescription)") }
                }
                buildStructuralGraph(context: context)
                requestRecommit()
            }
        } else {
            do { try context.save() } catch { Log.db.error("GraphState: context.save() failed — \(error.localizedDescription)") }
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
                if let pageId = await AppBootstrap.shared?.vaultSync.createPage(title: safeLabel) {
                    sdNode.sourceId = pageId
                    do { try context.save() } catch { Log.db.error("GraphState: context.save() failed — \(error.localizedDescription)") }
                }
                buildStructuralGraph(context: context)
                requestRecommit()
            }
        } else {
            do { try context.save() } catch { Log.db.error("GraphState: context.save() failed — \(error.localizedDescription)") }
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
        do { try context.save() } catch { Log.db.error("GraphState: context.save() failed — \(error.localizedDescription)") }

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

    private var scanTask: Task<Void, Never>?

    func scanVault(context: ModelContext, llmService: any LLMClientProtocol) {
        scanTask?.cancel()
        scanTask = Task {
            let extractor = EntityExtractor(graphState: self)
            await extractor.scanVault(context: context, llmService: llmService)
        }
    }
}
