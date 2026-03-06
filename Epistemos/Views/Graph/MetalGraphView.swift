import SwiftUI
import MetalKit
import Synchronization
import SwiftData

// MARK: - MetalGraphView
// NSViewRepresentable wrapping a CAMetalLayer for the Rust graph engine.
// Bridges SwiftUI ↔ Metal ↔ Rust FFI. The engine owns the render loop;
// this view just provides the surface and forwards input events.

struct MetalGraphView: NSViewRepresentable {
    @Environment(GraphState.self) private var graphState
    @Environment(PhysicsCoordinator.self) private var physicsCoordinator
    @Environment(DialogueChatState.self) private var dialogueChatState
    @Environment(UIState.self) private var uiState

    func makeNSView(context: Context) -> MetalGraphNSView {
        let view = MetalGraphNSView()
        view.graphState = graphState
        view.physicsCoordinator = physicsCoordinator
        view.dialogueChatState = dialogueChatState
        view.uiState = uiState
        return view
    }

    func updateNSView(_ nsView: MetalGraphNSView, context: Context) {
        nsView.graphState = graphState
        nsView.physicsCoordinator = physicsCoordinator
        nsView.dialogueChatState = dialogueChatState
        nsView.uiState = uiState
        // Wake the render loop whenever SwiftUI detects a GraphState change.
        // This ensures version-based syncs in renderFrame() (lite mode, force params,
        // cluster params, etc.) fire even when physics is settled and renderNeeded=false.
        // Cost: one atomic store + at most one extra render frame per SwiftUI update.
        nsView.needsRender = true
    }
}

// MARK: - MetalGraphNSView
// NSView subclass that owns the CAMetalLayer and Rust engine pointer.
// Uses CVDisplayLink for frame pacing (only renders when the engine requests it).

final class MetalGraphNSView: NSView {
    private typealias DialogueDepthColor = (r: Float, g: Float, b: Float, a: Float)

    private struct DialogueContextSnapshot {
        let node: GraphNodeRecord?
        let noteBody: String
        let linkedLabels: [String]
        let insight: DialogueNodeInsight
    }

    private static let dialogueDepthPalette: [DialogueDepthColor] = [
        (0.98, 0.96, 0.90, 1.0),
        (0.95, 0.82, 0.34, 1.0),
        (0.90, 0.66, 0.27, 1.0),
        (0.58, 0.76, 0.43, 1.0),
        (0.34, 0.70, 0.70, 1.0),
        (0.42, 0.56, 0.88, 1.0),
    ]

    nonisolated(unsafe) private var engine: OpaquePointer?
    nonisolated(unsafe) private var displayLink: CVDisplayLink?
    private var metalLayer: CAMetalLayer?

    /// Frame coalescing: prevents queuing multiple render dispatches.
    /// Atomic to avoid data race between CVDisplayLink (background) and main thread.
    nonisolated(unsafe) private let framePending = Atomic<Bool>(false)

    /// Atomic render-needed flag. CVDisplayLink (background thread) reads this
    /// to skip dispatches when settled. Main thread writes it on user events
    /// and after graph_engine_render() returns.
    nonisolated(unsafe) private let renderNeeded = Atomic<Bool>(true)

    /// Set during deinit to prevent queued render callbacks from accessing
    /// a destroyed engine. Checked in renderFrame() before any FFI call.
    nonisolated(unsafe) private let isInvalidated = Atomic<Bool>(false)

    /// Convenience wrapper for main-thread code. Background thread should
    /// use renderNeeded directly for thread safety.
    fileprivate var needsRender: Bool {
        get { renderNeeded.load(ordering: .relaxed) }
        set { renderNeeded.store(newValue, ordering: .relaxed) }
    }

    var graphState: GraphState? {
        didSet {
            // Share engine handle with GraphState for Rust-side search/queries.
            // graphState is nil during setupMetal() and set later in makeNSView(),
            // so this didSet is the first point where both engine and graphState exist.
            if graphState?.engineHandle == nil, let engine {
                graphState?.engineHandle = engine
            }
        }
    }
    /// Cross-view physics signal bus. Fed from mouseMoved hover detection.
    /// nonisolated(unsafe): written from AppKit event handlers (main thread)
    /// but compiler can't prove @MainActor isolation on NSView subclass.
    nonisolated(unsafe) var physicsCoordinator: PhysicsCoordinator?
    nonisolated(unsafe) var dialogueChatState: DialogueChatState?
    nonisolated(unsafe) var uiState: UIState?
    private var dialogueHostingView: NSHostingView<AnyView>?
    /// Reused buffer for reading dialogue screen rect from Rust (zero per-frame allocation).
    private var dialogueRectBuf: [Float] = [0, 0, 0, 0]
    var lastForceConfigVersion = 0
    var lastGraphDataVersion = 0
    var lastLiteModeVersion = -1
    var lastVisualThemeVersion: Int = -1
    var lastSemanticForceConfigVersion: Int = -1
    /// Current search query text (bound by the search sidebar).
    var searchQuery: String = ""

    /// Callback for background tap (click without drag). Used for click-outside dismiss.
    var onBackgroundTap: (() -> Void)?
    /// Optional callback for when a node is tapped. Receives the node's sourceId.
    /// Used by in-note graph mode to navigate to the tapped note.
    var onNodeTap: ((String) -> Void)?
    private var mouseDownLocation: CGPoint?
    private var isDraggingNode = false
    private var isPanning = false
    /// Mini mode window drag tracking.
    private var isDraggingWindow = false
    private var windowDragOrigin: NSPoint?
    private var windowFrameOrigin: NSPoint?

    // Track whether graph data has been committed.
    private(set) var isCommitted = false

    /// When true, uses transparent clear color so blur shows through (hologram overlay mode).
    /// Setting this automatically applies the transparent clear color to the Rust engine.
    var isOverlayMode = false {
        didSet {
            guard isOverlayMode != oldValue, isOverlayMode, let engine else { return }
            graph_engine_set_clear_color(engine, 0, 0, 0, 0)
        }
    }

    /// Switch the Rust engine between light and dark color palettes.
    func setLightMode(_ enabled: Bool) {
        guard let engine else { return }
        graph_engine_set_light_mode(engine, enabled ? 1 : 0)
        needsRender = true
    }

    /// When true, the view is in the mini floating panel. Background taps are disabled
    /// and Option+drag moves the parent window (holographic drag).
    var isMiniMode = false

    // MARK: - Setup

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupMetal()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupMetal()
    }

    override func makeBackingLayer() -> CALayer {
        let layer = CAMetalLayer()
        layer.pixelFormat = .bgra8Unorm
        layer.framebufferOnly = false      // Required for transparent compositing.
        layer.isOpaque = false             // Allow blur to show through.
        layer.maximumDrawableCount = 3     // Triple buffer for smooth 120Hz ProMotion.
        layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        self.metalLayer = layer
        return layer
    }

    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let layer = self.layer as? CAMetalLayer else { return }

        layer.device = device
        metalLayer = layer

        // Create the Rust engine.
        let devicePtr = Unmanaged.passUnretained(device).toOpaque()
        let layerPtr = Unmanaged.passUnretained(layer).toOpaque()
        engine = graph_engine_create(devicePtr, layerPtr)

        // Share the engine handle with GraphState for Rust-side search/queries.
        graphState?.engineHandle = engine

        startDisplayLink()
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let link = displayLink else { return }

        // The Rust engine is NOT thread-safe — render must happen on the main thread.
        // CVDisplayLink fires on a background thread, so dispatch to main with coalescing:
        // if a frame is already pending dispatch, skip to avoid queuing backup at 120Hz.
        // Also skip entirely when simulation is settled (renderNeeded = false) to save CPU.
        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            let view = Unmanaged<MetalGraphNSView>.fromOpaque(userInfo!).takeUnretainedValue()
            guard !view.isInvalidated.load(ordering: .relaxed) else { return kCVReturnSuccess }
            if view.renderNeeded.load(ordering: .relaxed) && !view.framePending.load(ordering: .relaxed) {
                view.framePending.store(true, ordering: .relaxed)
                DispatchQueue.main.async { [weak view] in
                    guard let view, !view.isInvalidated.load(ordering: .relaxed) else { return }
                    view.framePending.store(false, ordering: .relaxed)
                    view.renderFrame()
                }
            }
            return kCVReturnSuccess
        }

        CVDisplayLinkSetOutputCallback(link, callback, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(link)
    }

    private func stopDisplayLink() {
        guard let link = displayLink else { return }
        CVDisplayLinkStop(link)
        displayLink = nil
    }

    /// Pause rendering and physics. Call when overlay is hidden.
    func pauseEngine() {
        stopDisplayLink()
        if let engine { graph_engine_pause(engine) }
    }

    /// Resume rendering and physics. Call when overlay is shown.
    func resumeEngine() {
        if let engine { graph_engine_resume(engine) }
        if displayLink == nil { startDisplayLink() }
        needsRender = true
    }


    // MARK: - Graph Data Commit

    /// Load all visible nodes and edges from the GraphStore into the Rust engine.
    /// Uses batch FFI to send all nodes/edges in a single call each instead of
    /// N individual calls (critical for 10K+ node performance).
    func commitGraphData() {
        guard let engine, let graphState else { return }
        let store = graphState.store
        let filter = graphState.filter

        graph_engine_clear(engine)

        // Collect visible nodes into batch arrays.
        var nodeIds: [String] = []
        var nodeXs: [Float] = []
        var nodeYs: [Float] = []
        var nodeTypes: [UInt8] = []
        var nodeLinkCounts: [UInt32] = []
        var nodeLabels: [String] = []

        for (_, node) in store.nodes {
            guard filter.isNodeVisible(node) else { continue }
            nodeIds.append(node.id)
            nodeXs.append(node.position.x)
            nodeYs.append(node.position.y)
            nodeTypes.append(node.type.rustIndex)
            nodeLinkCounts.append(store.linkCount(for: node.id))
            nodeLabels.append(node.label)
        }

        // Batch-add all nodes in a single FFI call.
        if !nodeIds.isEmpty {
            // strdup keeps C strings alive until free() — safe across FFI boundary.
            let uuidCPtrs: [UnsafeMutablePointer<CChar>] = nodeIds.compactMap { strdup($0) }
            let labelCPtrs: [UnsafeMutablePointer<CChar>] = nodeLabels.compactMap { strdup($0) }
            guard uuidCPtrs.count == nodeIds.count, labelCPtrs.count == nodeLabels.count else {
                uuidCPtrs.forEach { free($0) }
                labelCPtrs.forEach { free($0) }
                return
            }
            defer {
                uuidCPtrs.forEach { free($0) }
                labelCPtrs.forEach { free($0) }
            }
            var uuidPtrs: [UnsafePointer<CChar>?] = uuidCPtrs.map { UnsafePointer($0) }
            var labelPtrs: [UnsafePointer<CChar>?] = labelCPtrs.map { UnsafePointer($0) }
            uuidPtrs.withUnsafeMutableBufferPointer { uPtrs in
                labelPtrs.withUnsafeMutableBufferPointer { lPtrs in
                    nodeXs.withUnsafeBufferPointer { xs in
                        nodeYs.withUnsafeBufferPointer { ys in
                            nodeTypes.withUnsafeBufferPointer { types in
                                nodeLinkCounts.withUnsafeBufferPointer { links in
                                    graph_engine_add_nodes_batch(
                                        engine,
                                        uPtrs.baseAddress,
                                        xs.baseAddress,
                                        ys.baseAddress,
                                        types.baseAddress,
                                        links.baseAddress,
                                        lPtrs.baseAddress,
                                        UInt32(nodeIds.count)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        // Collect visible edges into batch arrays.
        var edgeSrcs: [String] = []
        var edgeTgts: [String] = []
        var edgeWeights: [Float] = []
        var edgeTypes: [UInt8] = []

        for (_, edge) in store.edges {
            let srcVisible = store.nodes[edge.sourceNodeId].map { filter.isNodeVisible($0) } ?? false
            let tgtVisible = store.nodes[edge.targetNodeId].map { filter.isNodeVisible($0) } ?? false
            guard filter.isEdgeVisible(edge, sourceVisible: srcVisible, targetVisible: tgtVisible) else { continue }
            edgeSrcs.append(edge.sourceNodeId)
            edgeTgts.append(edge.targetNodeId)
            edgeWeights.append(Float(edge.weight))
            edgeTypes.append(edge.type.rustIndex)
        }

        // Batch-add all edges in a single FFI call.
        if !edgeSrcs.isEmpty {
            let srcCPtrs: [UnsafeMutablePointer<CChar>] = edgeSrcs.compactMap { strdup($0) }
            let tgtCPtrs: [UnsafeMutablePointer<CChar>] = edgeTgts.compactMap { strdup($0) }
            guard srcCPtrs.count == edgeSrcs.count, tgtCPtrs.count == edgeTgts.count else {
                srcCPtrs.forEach { free($0) }
                tgtCPtrs.forEach { free($0) }
                return
            }
            defer {
                srcCPtrs.forEach { free($0) }
                tgtCPtrs.forEach { free($0) }
            }
            var srcPtrs: [UnsafePointer<CChar>?] = srcCPtrs.map { UnsafePointer($0) }
            var tgtPtrs: [UnsafePointer<CChar>?] = tgtCPtrs.map { UnsafePointer($0) }
            srcPtrs.withUnsafeMutableBufferPointer { sPtrs in
                tgtPtrs.withUnsafeMutableBufferPointer { tPtrs in
                    edgeWeights.withUnsafeBufferPointer { wts in
                        edgeTypes.withUnsafeBufferPointer { types in
                            graph_engine_add_edges_batch(
                                engine,
                                sPtrs.baseAddress,
                                tPtrs.baseAddress,
                                wts.baseAddress,
                                types.baseAddress,
                                UInt32(edgeSrcs.count)
                            )
                        }
                    }
                }
            }
        }

        // Entrance animation: always play for small graphs (under static threshold),
        // skip for large graphs or when already committed (mid-session recommit).
        let isSmallGraph = graphState.store.nodeCount <= GraphState.staticLayoutThreshold
        let entrance: UInt8 = (isCommitted || (!isSmallGraph && graphState.hasPlayedEntrance)) ? 0 : 1
        graph_engine_commit(engine, entrance)
        if entrance == 1 {
            graphState.hasPlayedEntrance = true
            // Rust clears user_frozen on entrance — sync Swift side so the
            // freeze toggle reflects the actual engine state.
            if graphState.isPhysicsFrozen {
                graphState.isPhysicsFrozen = false
                graphState.physicsFrozenVersion += 1
                graphState.savePhysicsSettings()
            }
        }

        // Update static layout flag — physics controls grey out when true.
        graphState.isStaticLayout = graph_engine_is_static_layout(engine) != 0

        pushForceParams()
        pushExtendedForceParams()
        pushClusterParams()
        pushSemanticForce()
        pushLabParams()

        // Push quality level to Rust and sync version tracker.
        graph_engine_set_quality_level(engine, graphState.qualityLevel)
        lastLiteModeVersion = graphState.liteModeVersion

        // Push visual theme to Rust.
        graph_engine_set_visual_theme(engine, graphState.visualTheme.rawValue)
        applyDialogueDepthPalette()
        lastVisualThemeVersion = graphState.visualThemeVersion

        if graphState.useSemanticClustering, !graphState.semanticClusterIds.isEmpty {
            pushSemanticClusters()
            lastSemanticClusterVersion = graphState.semanticClusterVersion
        } else {
            lastSemanticClusterVersion = -1
        }

        graph_engine_set_user_frozen(engine, graphState.isPhysicsFrozen ? 1 : 0)
        lastForceConfigVersion = graphState.forceConfigVersion
        lastExtendedForceConfigVersion = graphState.extendedForceConfigVersion
        lastClusterConfigVersion = graphState.clusterConfigVersion
        lastSemanticForceConfigVersion = graphState.semanticForceConfigVersion
        lastLabConfigVersion = graphState.labConfigVersion
        lastPhysicsFrozenVersion = graphState.physicsFrozenVersion

        isCommitted = true
        needsRender = true

        // Push node timestamps and confidence to Rust (batch via individual calls —
        // these are lightweight per-node metadata, not the expensive graph data).
        for (_, node) in store.nodes {
            guard filter.isNodeVisible(node) else { continue }
            let createdAt = node.createdAt.timeIntervalSince1970
            let confidence: Float = switch node.metadata.evidenceGrade?.uppercased() {
            case "A": 1.0
            case "B": 0.8
            case "C": 0.6
            case "D": 0.4
            case "F": 0.2
            default: 0.0
            }
            node.id.withCString { uuidPtr in
                graph_engine_set_node_time(engine, uuidPtr, createdAt, createdAt)
                if confidence > 0.0 {
                    graph_engine_set_node_confidence(engine, uuidPtr, confidence)
                }
            }
        }

        // Pre-compute time range for time-travel slider.
        graphState.computeTimeRange()

        // Compute embeddings and push to Rust for semantic force + search.
        graphState.embeddingService.computeAndPush(store: graphState.store)
    }

    // MARK: - Incremental FFI Adds

    /// Send pending node/edge additions to the Rust engine individually.
    /// O(k) where k = pending items, vs O(N) for a full recommit.
    private func commitIncrementalAdds(graphState: GraphState) {
        guard let engine else { return }
        let store = graphState.store
        let filter = graphState.filter

        for node in graphState.pendingNodeAdds {
            guard filter.isNodeVisible(node) else { continue }
            let linkCount = store.linkCount(for: node.id)
            node.id.withCString { uuidPtr in
                node.label.withCString { labelPtr in
                    graph_engine_add_node(
                        engine, uuidPtr,
                        node.position.x, node.position.y,
                        node.type.rustIndex, linkCount,
                        labelPtr
                    )
                }
            }
        }

        for edge in graphState.pendingEdgeAdds {
            let srcVisible = store.nodes[edge.sourceNodeId].map { filter.isNodeVisible($0) } ?? false
            let tgtVisible = store.nodes[edge.targetNodeId].map { filter.isNodeVisible($0) } ?? false
            guard filter.isEdgeVisible(edge, sourceVisible: srcVisible, targetVisible: tgtVisible) else { continue }
            edge.sourceNodeId.withCString { srcPtr in
                edge.targetNodeId.withCString { tgtPtr in
                    graph_engine_add_edge(engine, srcPtr, tgtPtr, Float(edge.weight), edge.type.rustIndex)
                }
            }
        }

        if !graphState.pendingNodeAdds.isEmpty || !graphState.pendingEdgeAdds.isEmpty {
            graph_engine_commit(engine, 0)
            let pendingIds = graphState.pendingNodeAdds.map(\.id)
            if !pendingIds.isEmpty {
                applyDialogueDepthPalette(for: pendingIds)
            }
        }

        graphState.pendingNodeAdds.removeAll()
        graphState.pendingEdgeAdds.removeAll()
    }

    // MARK: - Lightweight Filter Sync

    /// Toggle node visibility in Rust to match the current filter state.
    /// Much cheaper than commitGraphData() — no clear/re-add/commit cycle.
    func applyFilterState() {
        guard let engine, let graphState, isCommitted else { return }
        let store = graphState.store
        let filter = graphState.filter

        for (_, node) in store.nodes {
            let visible: UInt8 = filter.isNodeVisible(node) ? 1 : 0
            node.id.withCString { uuid in
                graph_engine_set_node_visible(engine, uuid, visible)
            }
        }
        graph_engine_refresh_visibility(engine)

        // Re-check static layout — focusing on a subset may re-enable physics.
        graphState.isStaticLayout = graph_engine_is_static_layout(engine) != 0

        needsRender = true
    }

    // MARK: - Force Params

    var lastExtendedForceConfigVersion: Int = -1
    var lastClusterConfigVersion: Int = -1
    var lastSemanticClusterVersion: Int = -1
    var lastFilterVersion: Int = 0
    var lastPhysicsFrozenVersion: Int = 0
    var lastLabConfigVersion: Int = -1

    func pushForceParams() {
        guard let engine, let graphState else { return }
        graph_engine_set_force_params(
            engine,
            graphState.linkDistance,
            graphState.chargeStrength,
            graphState.chargeRange,
            graphState.linkStrength
        )
        needsRender = true
    }

    func pushExtendedForceParams() {
        guard let engine, let graphState else { return }
        graph_engine_set_extended_force_params(
            engine,
            graphState.velocityDecay,
            graphState.centerStrength,
            graphState.collisionRadius
        )
        needsRender = true
    }

    func pushLabParams() {
        guard let engine, let graphState else { return }
        graph_engine_set_lab_params(
            engine,
            graphState.enableFluidDynamics ? 1 : 0,
            graphState.enableTorsionalSprings ? 1 : 0,
            graphState.enableElasticEdges ? 1 : 0,
            graphState.enableTensionColoring ? 1 : 0,
            graphState.fluidViscosity,
            graphState.edgeElasticity,
            graphState.torsionRigidity,
            graphState.boidsCohesion,
            graphState.windX,
            graphState.windY,
            graphState.enableOrbital ? 1 : 0,
            graphState.orbitalSpeed
        )
        needsRender = true
    }

    func pushClusterParams() {
        guard let engine, let graphState else { return }
        graph_engine_set_cluster_params(engine, graphState.clusterStrength)
        graph_engine_set_center_mode(engine, graphState.centerMode)
        needsRender = true
    }

    func pushSemanticForce() {
        guard let engine, let graphState else { return }
        graph_engine_set_semantic_strength(engine, graphState.semanticStrength)
        needsRender = true
    }

    func pushSemanticClusters() {
        guard let engine, let graphState else { return }
        let clusterMap = graphState.semanticClusterIds
        guard !clusterMap.isEmpty else { return }

        let uuids = Array(clusterMap.keys)
        let ids = uuids.map { clusterMap[$0]! }

        let cPtrs: [UnsafeMutablePointer<CChar>] = uuids.compactMap { strdup($0) }
        guard cPtrs.count == uuids.count else {
            cPtrs.forEach { free($0) }
            return
        }
        defer { cPtrs.forEach { free($0) } }
        var optPtrs: [UnsafePointer<CChar>?] = cPtrs.map { UnsafePointer($0) }

        optPtrs.withUnsafeMutableBufferPointer { uuidBuf in
            ids.withUnsafeBufferPointer { idsBuffer in
                graph_engine_set_cluster_ids(
                    engine, uuidBuf.baseAddress, idsBuffer.baseAddress!, UInt32(uuids.count)
                )
            }
        }
        needsRender = true
    }

    // MARK: - Camera

    func resetCamera() {
        guard let engine else { return }
        graph_engine_zoom_to_fit(engine)
        needsRender = true
    }

    func zoomToFit() {
        guard let engine else { return }
        graph_engine_zoom_to_fit(engine)
        needsRender = true
    }

    /// Zoom to fit, then magnify extra to get close on a small cluster (page mode).
    func zoomInClose() {
        guard let engine else { return }
        graph_engine_zoom_to_fit(engine)
        let scale = metalLayer?.contentsScale ?? 2.0
        let cx = Float(bounds.width * 0.5 * scale)
        let cy = Float(bounds.height * 0.5 * scale)
        graph_engine_magnify(engine, cx, cy, 1.5)
        needsRender = true
    }

    func centerOnNode(_ nodeId: String) {
        guard let engine else { return }
        nodeId.withCString { ptr in
            graph_engine_center_on_node(engine, ptr)
        }
        needsRender = true
    }

    // MARK: - Graph Mode

    /// Set graph mode on the Rust engine: 0 = global, 1 = page.
    func setGraphMode(_ mode: UInt8) {
        guard let engine else { return }
        graph_engine_set_mode(engine, mode)
    }

    /// Pass the note window's screen rect to the Rust engine for anchor-based positioning.
    func setAnchorRect(_ rect: NSRect) {
        guard let engine else { return }
        let scale = metalLayer?.contentsScale ?? 2.0
        graph_engine_set_anchor_rect(
            engine,
            Float(rect.origin.x * scale),
            Float(rect.origin.y * scale),
            Float(rect.width * scale),
            Float(rect.height * scale)
        )
    }

    /// Highlight nodes matching a search query. Empty string clears.
    func searchHighlight(_ query: String) {
        guard let engine else { return }
        query.withCString { ptr in
            graph_engine_search_highlight(engine, ptr)
        }
        needsRender = true
    }

    /// Isolate a node by UUID (highlight + center camera on it).
    func isolateNode(_ uuid: String) {
        guard let engine else { return }
        uuid.withCString { ptr in
            graph_engine_highlight_neighbors(engine, ptr)
            graph_engine_center_on_node(engine, ptr)
        }
        needsRender = true
    }

    // MARK: - Render Loop

    /// Render one frame. Must be called on the main thread.
    private func renderFrame() {
        guard !isInvalidated.load(ordering: .relaxed),
              let engine, isCommitted else { return }
        guard let layer = metalLayer else { return }

        // Sync force params if GraphState changed (handles hologram overlay mode
        // where there's no SwiftUI update cycle to trigger updateNSView).
        if let graphState, lastForceConfigVersion != graphState.forceConfigVersion {
            lastForceConfigVersion = graphState.forceConfigVersion
            pushForceParams()
        }

        // Sync extended force params (velocity decay, warmth, orbital, etc.).
        if let graphState, lastExtendedForceConfigVersion != graphState.extendedForceConfigVersion {
            lastExtendedForceConfigVersion = graphState.extendedForceConfigVersion
            pushExtendedForceParams()
        }

        // Sync quality level when changed.
        if let graphState, engine != nil, lastLiteModeVersion != graphState.liteModeVersion {
            lastLiteModeVersion = graphState.liteModeVersion
            graph_engine_set_quality_level(engine, graphState.qualityLevel)
        }

        // Sync visual theme when changed.
        if let graphState, engine != nil, lastVisualThemeVersion != graphState.visualThemeVersion {
            lastVisualThemeVersion = graphState.visualThemeVersion
            graph_engine_set_visual_theme(engine, graphState.visualTheme.rawValue)
            applyDialogueDepthPalette()
        }

        // Sync laboratory params (toggles + knobs for advanced physics).
        if let graphState, lastLabConfigVersion != graphState.labConfigVersion {
            lastLabConfigVersion = graphState.labConfigVersion
            pushLabParams()
        }

        // Sync cluster params (cluster strength, center mode).
        if let graphState, lastClusterConfigVersion != graphState.clusterConfigVersion {
            lastClusterConfigVersion = graphState.clusterConfigVersion
            pushClusterParams()
        }

        // Sync semantic attraction force independently from semantic cluster IDs.
        if let graphState, lastSemanticForceConfigVersion != graphState.semanticForceConfigVersion {
            lastSemanticForceConfigVersion = graphState.semanticForceConfigVersion
            pushSemanticForce()
        }

        // Sync semantic cluster IDs when they change.
        if let graphState, lastSemanticClusterVersion != graphState.semanticClusterVersion,
           graphState.useSemanticClustering, !graphState.semanticClusterIds.isEmpty {
            lastSemanticClusterVersion = graphState.semanticClusterVersion
            pushSemanticClusters()
        }

        // Minimize request: post notification for the overlay to handle.
        if let graphState, graphState.pendingMinimize {
            graphState.pendingMinimize = false
            NotificationCenter.default.post(name: .graphMinimizeRequested, object: nil)
        }

        // Close request: post notification for the overlay to handle.
        if let graphState, graphState.pendingClose {
            graphState.pendingClose = false
            NotificationCenter.default.post(name: .graphCloseRequested, object: nil)
        }

        // Lightweight filter sync: toggle node visibility in Rust without full recommit.
        if let graphState, lastFilterVersion != graphState.filterVersion {
            lastFilterVersion = graphState.filterVersion
            applyFilterState()
        }

        // Sync user-controlled physics freeze.
        if let graphState, lastPhysicsFrozenVersion != graphState.physicsFrozenVersion {
            lastPhysicsFrozenVersion = graphState.physicsFrozenVersion
            graph_engine_set_user_frozen(engine, graphState.isPhysicsFrozen ? 1 : 0)
            needsRender = true
        }

        // Reset view: zoom to fit all visible nodes.
        if let graphState, graphState.pendingResetView {
            graphState.pendingResetView = false
            graph_engine_zoom_to_fit(engine)
            needsRender = true
        }

        // Center on a specific node (e.g. from command palette selection).
        if let graphState, let nodeId = graphState.pendingCenterNodeId {
            graphState.pendingCenterNodeId = nil
            centerOnNode(nodeId)
            needsRender = true
        }

        // Rebuild: re-run structural graph builder and full recommit.
        if let graphState, graphState.pendingRebuild {
            graphState.pendingRebuild = false
            if let context = graphState.modelContext {
                graphState.refreshStructuralData(context: context)
                graphState.requestRecommit()
            }
        }

        // Drain incremental node/edge additions (avoids full O(N) recommit).
        if let graphState,
           !graphState.pendingNodeAdds.isEmpty || !graphState.pendingEdgeAdds.isEmpty {
            commitIncrementalAdds(graphState: graphState)
        }

        // Re-commit graph data when mode/filter changes (e.g. Global↔Page toggle).
        if let graphState, lastGraphDataVersion != graphState.graphDataVersion {
            lastGraphDataVersion = graphState.graphDataVersion
            let isPageMode: Bool = {
                if case .page = graphState.mode { return true }
                return false
            }()
            setGraphMode(isPageMode ? 1 : 0)
            commitGraphData()
            if isPageMode {
                zoomInClose()
            } else {
                graph_engine_zoom_to_fit(engine)
            }
        }

        let size = layer.drawableSize
        let w = UInt32(size.width)
        let h = UInt32(size.height)
        guard w > 0, h > 0 else { return }

        let result = graph_engine_render(engine, w, h)

        // Update dialogue overlay position from Rust screen rect.
        if graph_engine_dialogue_is_active(engine) != 0 {
            graph_engine_dialogue_screen_rect(engine, &dialogueRectBuf)
            let scale = metalLayer?.contentsScale ?? 2.0
            let pointRect = CGRect(
                x: CGFloat(dialogueRectBuf[0]) / scale,
                y: bounds.height - CGFloat(dialogueRectBuf[1] + dialogueRectBuf[3]) / scale,
                width: CGFloat(dialogueRectBuf[2]) / scale,
                height: CGFloat(dialogueRectBuf[3]) / scale
            )
            updateDialogueOverlay(rect: pointRect)
        } else {
            hideDialogueOverlay()
        }

        needsRender = result != 0
    }

    // MARK: - Input Events

    override var acceptsFirstResponder: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let hosting = dialogueHostingView {
            let local = convert(point, to: hosting)
            if hosting.bounds.contains(local) {
                return hosting.hitTest(local)
            }
        }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        // Let the dialogue overlay handle its own clicks.
        if let hosting = dialogueHostingView {
            let loc = convert(event.locationInWindow, from: nil)
            if hosting.frame.contains(loc) { return }
        }

        // Claim first responder on click so subsequent gestures (magnify, scroll) route here.
        if window?.firstResponder !== self {
            window?.makeFirstResponder(self)
        }

        guard let engine else { return }

        // In connection mode, don't start drag/pan — handle in mouseUp.
        if let graphState, graphState.isConnecting {
            let loc = convert(event.locationInWindow, from: nil)
            let scale = metalLayer?.contentsScale ?? 2.0
            graph_engine_mouse_moved(engine, Float(loc.x * scale), Float((bounds.height - loc.y) * scale))
            return
        }

        let loc = convert(event.locationInWindow, from: nil)
        mouseDownLocation = loc
        let scale = metalLayer?.contentsScale ?? 2.0
        let shift: UInt8 = event.modifierFlags.contains(.shift) ? 1 : 0
        graph_engine_mouse_down(engine, Float(loc.x * scale), Float((bounds.height - loc.y) * scale), shift)

        // Cursor feedback: closedHand for both node drag and pan.
        if graph_engine_hovered_node_uuid(engine) != nil {
            isDraggingNode = true
        } else {
            isPanning = true
            // In mini mode, only the top 40px is a drag handle — rest pans the graph.
            if isMiniMode {
                let viewHeight = bounds.height
                if loc.y > viewHeight - 40 {
                    isDraggingWindow = true
                    windowDragOrigin = NSEvent.mouseLocation
                    windowFrameOrigin = window?.frame.origin
                }
            }
        }
        NSCursor.closedHand.set()
        needsRender = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let engine else { return }

        // In mini mode, background drag moves the floating window.
        if isMiniMode && isDraggingWindow, let origin = windowDragOrigin, let frameOrigin = windowFrameOrigin {
            let current = NSEvent.mouseLocation
            let dx = current.x - origin.x
            let dy = current.y - origin.y
            window?.setFrameOrigin(NSPoint(x: frameOrigin.x + dx, y: frameOrigin.y + dy))
            return
        }

        let loc = convert(event.locationInWindow, from: nil)
        let scale = metalLayer?.contentsScale ?? 2.0
        let screenX = Float(loc.x * scale)
        let screenY = Float((bounds.height - loc.y) * scale)
        graph_engine_mouse_moved(engine, screenX, screenY)
        needsRender = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let engine else { return }

        // Connection mode: complete or cancel the connection.
        if let graphState, case .connecting(let sourceNodeId) = graphState.interactionMode {
            if let uuidPtr = graph_engine_hovered_node_uuid(engine) {
                let targetUuid = String(cString: uuidPtr)
                if targetUuid != sourceNodeId {
                    promptForEdgeType { [weak self] edgeType in
                        guard let self, let edgeType,
                              let context = graphState.modelContext else {
                            self?.graphState?.cancelConnecting()
                            return
                        }
                        graphState.connectNodes(
                            sourceId: sourceNodeId, targetId: targetUuid,
                            edgeType: edgeType, context: context
                        )
                    }
                }
            }
            graphState.cancelConnecting()
            graph_engine_clear_highlight(engine)
            NSCursor.arrow.set()
            isDraggingNode = false; isPanning = false; mouseDownLocation = nil
            needsRender = true
            return
        }

        graph_engine_mouse_up(engine)

        // Sync selection state: node click → select, background click → deselect.
        let uuidPtr = graph_engine_selected_node_uuid(engine)
        if let uuidPtr {
            let uuid = String(cString: uuidPtr)
            graphState?.selectNode(uuid)

            // Dialogue theme: open dialogue on selected node.
            if graphState?.visualTheme == .dialogue, let dialogueChatState {
                uuid.withCString { cstr in
                    graph_engine_dialogue_open(engine, cstr)
                }
                let dialogueContext = graphState.map { buildDialogueContextSnapshot(for: uuid, graphState: $0) }
                let nodeRecord = dialogueContext?.node
                let label = nodeRecord?.label ?? "Unknown"
                let isNewNode = dialogueChatState.activeNodeId != uuid
                dialogueChatState.open(
                    nodeId: uuid,
                    label: label,
                    nodeType: nodeRecord?.type ?? .note,
                    noteBody: dialogueContext?.noteBody ?? "",
                    linkedNodeLabels: dialogueContext?.linkedLabels ?? [],
                    insight: dialogueContext?.insight
                )
                if isNewNode {
                    dialogueChatState.onStreamingChanged = { [weak self] streaming in
                        guard let engine = self?.engine else { return }
                        graph_engine_dialogue_set_streaming(engine, streaming ? 1 : 0)
                        self?.needsRender = true
                    }
                }
                needsRender = true
            }

            // Notify in-note graph mode about the tap (if callback is set).
            if let onNodeTap, let sourceId = graphState?.store.nodes[uuid]?.sourceId {
                onNodeTap(sourceId)
            }
        } else {
            graphState?.selectNode(nil)

            // Dialogue theme: close dialogue on background click (not inside overlay).
            if graphState?.visualTheme == .dialogue {
                let clickInOverlay = dialogueHostingView.map { hosting in
                    hosting.frame.contains(convert(event.locationInWindow, from: nil))
                } ?? false
                if !clickInOverlay {
                    graph_engine_dialogue_close(engine)
                    dialogueChatState?.close()
                    hideDialogueOverlay()
                    needsRender = true
                }
            }

            // Background tap: if mouse barely moved, treat as click-outside dismiss.
            // Disabled in mini mode — mini graph stays open.
            if !isMiniMode, let down = mouseDownLocation {
                let up = convert(event.locationInWindow, from: nil)
                let dx = up.x - down.x, dy = up.y - down.y
                if dx * dx + dy * dy < 25 { // 5px threshold
                    onBackgroundTap?()
                }
            }
        }

        // Reset cursor based on hover state.
        if graph_engine_hovered_node_uuid(engine) != nil {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
        isDraggingNode = false
        isPanning = false
        isDraggingWindow = false
        windowDragOrigin = nil
        windowFrameOrigin = nil
        mouseDownLocation = nil
        needsRender = true
    }

    // MARK: - Context Menu (Right-Click)

    /// Data carrier for node creation menu items.
    private final class NodeCreationInfo: NSObject {
        let type: GraphNodeType
        let worldPos: SIMD2<Float>
        let connectedTo: String?  // existing node UUID, nil for orphan
        init(type: GraphNodeType, worldPos: SIMD2<Float>, connectedTo: String?) {
            self.type = type; self.worldPos = worldPos; self.connectedTo = connectedTo
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let engine, isCommitted else { return nil }

        // Move hover to click location so Rust knows which node is under the cursor.
        let loc = convert(event.locationInWindow, from: nil)
        let scale = metalLayer?.contentsScale ?? 2.0
        let screenX = Float(loc.x * scale)
        let screenY = Float((bounds.height - loc.y) * scale)
        graph_engine_mouse_moved(engine, screenX, screenY)

        // Convert click position to world coordinates for node placement.
        var worldX: Float = 0, worldY: Float = 0
        graph_engine_screen_to_world(engine, screenX, screenY, &worldX, &worldY)
        let clickPos = SIMD2<Float>(worldX, worldY)

        if let uuidPtr = graph_engine_hovered_node_uuid(engine) {
            let uuid = String(cString: uuidPtr)
            return buildNodeContextMenu(uuid: uuid, clickWorldPos: clickPos)
        } else {
            return buildEmptySpaceContextMenu(clickWorldPos: clickPos)
        }
    }

    // MARK: Empty Space Menu

    private func buildEmptySpaceContextMenu(clickWorldPos: SIMD2<Float>) -> NSMenu {
        let menu = NSMenu()
        let types: [(GraphNodeType, String, String)] = [
            (.note, "Create Note", "doc.text"),
            (.idea, "Create Idea", "lightbulb"),
            (.tag,  "Create Tag",  "number"),
        ]
        for (type, title, icon) in types {
            let item = NSMenuItem(title: title, action: #selector(contextCreateNode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NodeCreationInfo(type: type, worldPos: clickWorldPos, connectedTo: nil)
            item.image = NSImage(systemSymbolName: icon, accessibilityDescription: title)
            menu.addItem(item)
        }
        return menu
    }

    // MARK: Node Menu

    private func buildNodeContextMenu(uuid: String, clickWorldPos: SIMD2<Float>) -> NSMenu? {
        guard let node = graphState?.store.nodes[uuid] else { return nil }
        let menu = NSMenu()

        // "Open Note" — only for note-type nodes that have a sourceId.
        if node.type == .note, node.sourceId != nil {
            let openItem = NSMenuItem(title: "Open Note", action: #selector(contextOpenNote(_:)), keyEquivalent: "")
            openItem.target = self
            openItem.representedObject = node.sourceId
            openItem.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Open Note")
            menu.addItem(openItem)
        }

        // "Focus" — zoom into this node's neighborhood.
        let focusItem = NSMenuItem(title: "Focus on Node", action: #selector(contextFocusNode(_:)), keyEquivalent: "")
        focusItem.target = self
        focusItem.representedObject = uuid
        focusItem.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "Focus")
        menu.addItem(focusItem)

        // "Highlight Neighbors"
        let highlightItem = NSMenuItem(title: "Highlight Neighbors", action: #selector(contextHighlightNeighbors(_:)), keyEquivalent: "")
        highlightItem.target = self
        highlightItem.representedObject = uuid
        highlightItem.image = NSImage(systemSymbolName: "circle.hexagongrid", accessibilityDescription: "Neighbors")
        menu.addItem(highlightItem)

        menu.addItem(.separator())

        // "Create Connected Note"
        let connectedItem = NSMenuItem(title: "Create Connected Note", action: #selector(contextCreateNode(_:)), keyEquivalent: "")
        connectedItem.target = self
        connectedItem.representedObject = NodeCreationInfo(type: .note, worldPos: clickWorldPos, connectedTo: uuid)
        connectedItem.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
        menu.addItem(connectedItem)

        // "Connect to…"
        let connectItem = NSMenuItem(title: "Connect to\u{2026}", action: #selector(contextBeginConnect(_:)), keyEquivalent: "")
        connectItem.target = self
        connectItem.representedObject = uuid
        connectItem.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: nil)
        menu.addItem(connectItem)

        return menu
    }

    // MARK: Context Menu Actions

    @objc private func contextOpenNote(_ sender: NSMenuItem) {
        guard let pageId = sender.representedObject as? String else { return }
        NoteWindowManager.shared.open(pageId: pageId)
    }

    @objc private func contextFocusNode(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String else { return }
        isolateNode(uuid)
        graphState?.selectNode(uuid)
    }

    @objc private func contextHighlightNeighbors(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String, let engine else { return }
        uuid.withCString { ptr in
            graph_engine_highlight_neighbors(engine, ptr)
        }
        needsRender = true
    }

    @objc private func contextCreateNode(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? NodeCreationInfo,
              let graphState,
              let context = graphState.modelContext else { return }

        promptForNodeName(type: info.type) { [weak self] name in
            guard let self, let name, !name.isEmpty else { return }

            if let connectedTo = info.connectedTo {
                let edgeType: GraphEdgeType = info.type == .tag ? .tagged : .reference
                graphState.createConnectedNode(
                    type: info.type, label: name,
                    connectedTo: connectedTo, edgeType: edgeType,
                    atWorldPosition: info.worldPos, context: context
                )
            } else {
                graphState.createNode(
                    type: info.type, label: name,
                    atWorldPosition: info.worldPos, context: context
                )
            }
        }
    }

    @objc private func contextBeginConnect(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String else { return }
        graphState?.beginConnecting(from: uuid)
        // Visual feedback: highlight source node.
        if let engine {
            uuid.withCString { graph_engine_highlight_neighbors(engine, $0) }
        }
        NSCursor.crosshair.set()
        needsRender = true
    }

    // MARK: Prompts

    private func promptForNodeName(type: GraphNodeType, completion: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Create \(type.displayName)"
        alert.informativeText = "Enter a name:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        textField.placeholderString = "\(type.displayName) name"
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField
        completion(alert.runModal() == .alertFirstButtonReturn ? textField.stringValue : nil)
    }

    private func promptForEdgeType(completion: @escaping (GraphEdgeType?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Connection Type"
        alert.informativeText = "Select the relationship:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 26))
        let types: [(GraphEdgeType, String)] = [
            (.reference, "Reference"), (.related, "Related"),
            (.contains, "Contains"), (.tagged, "Tagged"),
            (.mentions, "Mentions"), (.cites, "Cites"),
            (.supports, "Supports"), (.contradicts, "Contradicts"),
            (.expands, "Expands"), (.questions, "Questions"),
        ]
        for (_, label) in types { popup.addItem(withTitle: label) }
        alert.accessoryView = popup
        let idx = popup.indexOfSelectedItem
        if alert.runModal() == .alertFirstButtonReturn, idx >= 0, idx < types.count {
            completion(types[idx].0)
        } else { completion(nil) }
    }

    override func mouseMoved(with event: NSEvent) {
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let scale = metalLayer?.contentsScale ?? 2.0
        let screenX = Float(loc.x * scale)
        let screenY = Float((bounds.height - loc.y) * scale)
        graph_engine_mouse_moved(engine, screenX, screenY)

        // Connection mode: override cursor to crosshair.
        if let graphState, graphState.isConnecting {
            NSCursor.crosshair.set()
            needsRender = true
            return
        }

        // Update cursor and physics coordinator based on hover state.
        if !isDraggingNode && !isPanning {
            if let uuidPtr = graph_engine_hovered_node_uuid(engine) {
                NSCursor.pointingHand.set()
                physicsCoordinator?.graphHoveredNodeId = String(cString: uuidPtr)
            } else {
                NSCursor.arrow.set()
                physicsCoordinator?.graphHoveredNodeId = nil
            }
        }
        needsRender = true
    }

    override func scrollWheel(with event: NSEvent) {
        guard let engine else { return }
        let scale = metalLayer?.contentsScale ?? 2.0
        let loc = convert(event.locationInWindow, from: nil)
        let sx = Float(loc.x * scale)
        let sy = Float((bounds.height - loc.y) * scale)

        // Default scroll → zoom (game-like). Option+scroll → pan.
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods.contains(.option) {
            // Option+scroll → pan (standard 2D mode).
            let dx = Float(event.scrollingDeltaX * scale)
            let dy = Float(event.scrollingDeltaY * scale)
            graph_engine_scroll(engine, dx, dy)
        } else {
            // Zoom toward cursor (default for both trackpad and mouse wheel).
            let sensitivity: Float = event.hasPreciseScrollingDeltas ? 0.005 : 0.06
            let magnification = Float(event.scrollingDeltaY) * sensitivity
            graph_engine_magnify(engine, sx, sy, magnification)
        }
        needsRender = true
    }

    override func keyDown(with event: NSEvent) {
        guard let engine else { super.keyDown(with: event); return }

        // Escape cancels connection mode.
        if event.keyCode == 53, let graphState, graphState.isConnecting {
            graphState.cancelConnecting()
            graph_engine_clear_highlight(engine)
            NSCursor.arrow.set()
            needsRender = true
            return
        }

        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])

        if mods == .command {
            switch event.charactersIgnoringModifiers {
            case "=", "+":
                // Cmd+= → zoom in toward center.
                let scale = metalLayer?.contentsScale ?? 2.0
                let cx = Float(bounds.width * 0.5 * scale)
                let cy = Float(bounds.height * 0.5 * scale)
                graph_engine_magnify(engine, cx, cy, 0.15)
                needsRender = true
                return
            case "-":
                // Cmd+- → zoom out from center.
                let scale = metalLayer?.contentsScale ?? 2.0
                let cx = Float(bounds.width * 0.5 * scale)
                let cy = Float(bounds.height * 0.5 * scale)
                graph_engine_magnify(engine, cx, cy, -0.15)
                needsRender = true
                return
            case "0":
                // Cmd+0 → zoom to fit.
                graph_engine_zoom_to_fit(engine)
                needsRender = true
                return
            default:
                break
            }
        }
        super.keyDown(with: event)
    }

    override func magnify(with event: NSEvent) {
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let scale = metalLayer?.contentsScale ?? 2.0
        graph_engine_magnify(
            engine,
            Float(loc.x * scale),
            Float((bounds.height - loc.y) * scale),
            Float(event.magnification)
        )
        needsRender = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseExited(with event: NSEvent) {
        physicsCoordinator?.graphHoveredNodeId = nil
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        metalLayer?.contentsScale = scale
        metalLayer?.drawableSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )
        needsRender = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, !isCommitted, graphState?.isLoaded == true {
            commitGraphData()
        }
    }

    private func buildDialogueContextSnapshot(for nodeId: String, graphState: GraphState) -> DialogueContextSnapshot {
        let node = graphState.store.nodes[nodeId]
        let noteBody: String
        if node?.type == .note, let sourceId = node?.sourceId {
            noteBody = NoteFileStorage.readBody(pageId: sourceId)
        } else {
            noteBody = ""
        }
        let linkedLabels = graphState.store.neighbors(of: nodeId).map(\.label)
        let insight = dialogueInsight(
            for: node,
            noteBody: noteBody,
            linkedNodeLabels: linkedLabels,
            graphState: graphState
        )
        return DialogueContextSnapshot(node: node, noteBody: noteBody, linkedLabels: linkedLabels, insight: insight)
    }

    private func dialogueInsight(
        for node: GraphNodeRecord?,
        noteBody: String,
        linkedNodeLabels: [String],
        graphState: GraphState
    ) -> DialogueNodeInsight {
        guard let node else {
            return DialogueNodeInsight.fallback(nodeType: .note, noteBody: noteBody, linkedNodeCount: linkedNodeLabels.count)
        }

        if node.type == .folder,
           let sourceId = node.sourceId,
           let context = graphState.modelContext,
           let folder = fetchFolder(id: sourceId, context: context) {
            let stats = folderAggregateStats(folder)
            let depth = folderDepth(folder)
            let contentWords = max(stats.words, Int(node.weight * 90.0))
            let childCount = stats.pageCount + stats.childFolders
            let prominence = min(
                1.0,
                Double(contentWords) / 3200.0 +
                Double(childCount) * 0.025 +
                min(0.20, node.weight / 24.0) +
                (depth == 0 ? 0.16 : 0.0)
            )
            return DialogueNodeInsight(
                structureDepth: depth,
                contentWords: contentWords,
                childCount: childCount,
                tier: DialogueNodeInsight.tier(for: depth),
                prominence: prominence
            )
        }

        if node.type == .note,
           let sourceId = node.sourceId,
           let context = graphState.modelContext,
           let page = fetchPage(id: sourceId, context: context) {
            let depth = pageDepth(page)
            let bodyWords = noteBody.split { !$0.isLetter && !$0.isNumber }.count
            let childCount = linkedNodeLabels.count + (page.childPages?.count ?? 0)
            let contentWords = max(page.wordCount, bodyWords)
            let prominence = min(
                1.0,
                Double(contentWords) / 2200.0 +
                Double(childCount) * 0.024 +
                min(0.18, node.weight / 16.0)
            )
            return DialogueNodeInsight(
                structureDepth: depth,
                contentWords: contentWords,
                childCount: childCount,
                tier: DialogueNodeInsight.tier(for: depth),
                prominence: prominence
            )
        }

        let fallback = DialogueNodeInsight.fallback(
            nodeType: node.type,
            noteBody: noteBody,
            linkedNodeCount: linkedNodeLabels.count
        )
        let depth = graphDepthLevels(store: graphState.store)[node.id] ?? fallback.structureDepth
        return DialogueNodeInsight(
            structureDepth: depth,
            contentWords: fallback.contentWords,
            childCount: max(fallback.childCount, linkedNodeLabels.count),
            tier: DialogueNodeInsight.tier(for: depth),
            prominence: min(1.0, fallback.prominence + min(0.12, node.weight / 20.0))
        )
    }

    private func fetchPage(id: String, context: ModelContext) -> SDPage? {
        let descriptor = FetchDescriptor<SDPage>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func fetchFolder(id: String, context: ModelContext) -> SDFolder? {
        let descriptor = FetchDescriptor<SDFolder>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    private func folderDepth(_ folder: SDFolder) -> Int {
        var depth = 0
        var current = folder.parent
        var visited = Set<String>([folder.id])
        while let parent = current, visited.insert(parent.id).inserted {
            depth += 1
            current = parent.parent
        }
        return depth
    }

    private func pageDepth(_ page: SDPage) -> Int {
        var depth = page.folder.map { folderDepth($0) + 1 } ?? 1
        var current = page.parentPage
        var visited = Set<String>([page.id])
        while let parent = current, visited.insert(parent.id).inserted {
            depth += 1
            current = parent.parentPage
        }
        return depth
    }

    private func folderAggregateStats(_ folder: SDFolder) -> (pageCount: Int, childFolders: Int, words: Int) {
        var visited = Set<String>()

        func walk(_ current: SDFolder) -> (pageCount: Int, childFolders: Int, words: Int) {
            guard visited.insert(current.id).inserted else { return (0, 0, 0) }
            let pages = (current.pages ?? []).filter { !$0.isArchived }
            var totals = (
                pageCount: pages.count,
                childFolders: 0,
                words: pages.reduce(0) { $0 + max(0, $1.wordCount) }
            )
            for child in current.children ?? [] {
                totals.childFolders += 1
                let childTotals = walk(child)
                totals.pageCount += childTotals.pageCount
                totals.childFolders += childTotals.childFolders
                totals.words += childTotals.words
            }
            return totals
        }

        return walk(folder)
    }

    private func graphBaseDepth(for type: GraphNodeType) -> Int {
        switch type {
        case .folder: 0
        case .note, .chat: 2
        case .idea, .source, .quote: 3
        case .tag, .block: 4
        }
    }

    private func graphDepthLevels(store: GraphStore) -> [String: Int] {
        var depths: [String: Int] = [:]
        var childFolderIds = Set<String>()
        var folderChildren: [String: [String]] = [:]

        for edge in store.edges.values {
            guard edge.type == .contains,
                  let source = store.nodes[edge.sourceNodeId],
                  let target = store.nodes[edge.targetNodeId],
                  source.type == .folder else { continue }
            if target.type == .folder {
                folderChildren[source.id, default: []].append(target.id)
                childFolderIds.insert(target.id)
            }
        }

        var queue = store.nodes.values
            .filter { $0.type == .folder && !childFolderIds.contains($0.id) }
            .map(\.id)
        for nodeId in queue {
            depths[nodeId] = 0
        }

        var index = 0
        while index < queue.count {
            let folderId = queue[index]
            index += 1
            let nextDepth = (depths[folderId] ?? 0) + 1
            for childId in folderChildren[folderId] ?? [] {
                if let existing = depths[childId], existing <= nextDepth { continue }
                depths[childId] = nextDepth
                queue.append(childId)
            }
        }

        for node in store.nodes.values where node.type == .folder && depths[node.id] == nil {
            depths[node.id] = 0
        }

        for edge in store.edges.values {
            guard edge.type == .contains,
                  let source = store.nodes[edge.sourceNodeId],
                  let target = store.nodes[edge.targetNodeId],
                  source.type == .folder else { continue }
            guard target.type == .note || target.type == .chat else { continue }
            let nextDepth = (depths[source.id] ?? 0) + 1
            if let existing = depths[target.id], existing <= nextDepth { continue }
            depths[target.id] = nextDepth
        }

        for node in store.nodes.values where depths[node.id] == nil {
            let linkedDepth = store.neighbors(of: node.id).compactMap { depths[$0.id] }.min()
            let baseDepth = graphBaseDepth(for: node.type)
            depths[node.id] = linkedDepth.map { max(baseDepth, $0 + 1) } ?? baseDepth
        }

        return depths
    }

    private func dialogueDepthColor(for node: GraphNodeRecord, depth: Int, maxDepth: Int) -> DialogueDepthColor {
        let paletteIndex = min(depth, Self.dialogueDepthPalette.count - 1)
        let base = Self.dialogueDepthPalette[paletteIndex]
        let folderBoost: Float = node.type == .folder ? 0.06 : 0.0
        let sourceBoost: Float = node.type == .source ? 0.02 : 0.0
        let slimPenalty: Float = node.type == .tag || node.type == .block ? -0.08 : 0.0
        let weightBoost = min(0.10, Float(node.weight) * 0.015)
        let prominence = min(1.0, Float(node.weight) * 0.035 + Float(depth) * 0.05)
        func channel(_ value: Float) -> Float {
            min(1.0, max(0.0, value + folderBoost + sourceBoost + slimPenalty + weightBoost))
        }

        return (
            channel(base.r),
            channel(base.g),
            channel(base.b),
            1.0 + min(0.22, prominence * 0.12 + Float(max(0, depth - 1)) * 0.015)
        )
    }

    private func applyDialogueDepthPalette(for nodeIds: [String]? = nil) {
        guard let engine, let graphState else { return }
        let depths = graphDepthLevels(store: graphState.store)
        let maxDepth = depths.values.max() ?? 0
        let targetIds = nodeIds ?? Array(graphState.store.nodes.keys)
        let shouldColorize = graphState.visualTheme == .dialogue

        for nodeId in targetIds {
            guard let node = graphState.store.nodes[nodeId],
                  graphState.filter.isNodeVisible(node) else { continue }
            let color: DialogueDepthColor
            if shouldColorize {
                color = dialogueDepthColor(
                    for: node,
                    depth: depths[nodeId] ?? graphBaseDepth(for: node.type),
                    maxDepth: maxDepth
                )
            } else {
                color = (0.0, 0.0, 0.0, 0.0)
            }
            node.id.withCString { uuidPtr in
                graph_engine_set_node_color_override(engine, uuidPtr, color.r, color.g, color.b, color.a)
            }
        }

        needsRender = true
    }

    // MARK: - Dialogue Overlay

    private func updateDialogueOverlay(rect: CGRect) {
        guard let dialogueChatState,
              dialogueChatState.activeNodeId != nil,
              let graphState else {
            hideDialogueOverlay()
            return
        }

        if dialogueHostingView == nil {
            let overlay = DialogueOverlayView(
                chatState: dialogueChatState,
                onSubmit: { [weak self] query in
                    self?.submitDialogueQuery(query)
                },
                onDismiss: { [weak self] in
                    self?.dismissDialogue()
                }
            )
            guard let uiState else { return }
            let root = AnyView(
                overlay
                    .environment(graphState)
                    .environment(uiState)
            )
            let hosting = NSHostingView(rootView: root)
            hosting.frame = rect
            addSubview(hosting)
            dialogueHostingView = hosting
            return
        }

        // Only update frame; @Observable on DialogueChatState drives content updates.
        dialogueHostingView?.frame = rect
    }

    private func hideDialogueOverlay() {
        dialogueHostingView?.removeFromSuperview()
        dialogueHostingView = nil
    }

    private func dismissDialogue() {
        guard let engine else { return }
        graph_engine_dialogue_close(engine)
        dialogueChatState?.close()
        hideDialogueOverlay()
        needsRender = true
    }

    private func submitDialogueQuery(_ queryOverride: String? = nil) {
        guard let dialogueChatState,
              let nodeId = dialogueChatState.activeNodeId,
              let graphState else { return }
        if let queryOverride {
            dialogueChatState.inputText = queryOverride
        }
        let dialogueContext = buildDialogueContextSnapshot(for: nodeId, graphState: graphState)
        let nodeType = dialogueContext.node?.type ?? .note

        guard let triageService = AppBootstrap.shared?.triageService else { return }

        dialogueChatState.submitQuery(
            noteBody: dialogueContext.noteBody,
            linkedNodeLabels: dialogueContext.linkedLabels,
            nodeType: nodeType,
            insight: dialogueContext.insight,
            triageService: triageService
        )
    }

    // MARK: - Cleanup

    deinit {
        dialogueHostingView?.removeFromSuperview()
        dialogueHostingView = nil
        // Mark invalidated FIRST so any in-flight DispatchQueue.main.async from
        // the CVDisplayLink callback will skip renderFrame() and avoid
        // accessing the destroyed engine pointer.
        isInvalidated.store(true, ordering: .relaxed)
        // Inline CVDisplayLink stop — can't call @MainActor stopDisplayLink() from nonisolated deinit.
        // Safe: no other references exist during deallocation.
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
        // Cancel embedding task synchronously BEFORE destroying the engine.
        // cancelPendingTask() is nonisolated — safe to call from deinit.
        graphState?.embeddingService.cancelPendingTask()
        // Nil out engineHandle synchronously so any already-enqueued MainActor.run block
        // sees nil and skips FFI calls. engineHandle is nonisolated(unsafe) for this reason.
        graphState?.engineHandle = nil
        if let engine {
            graph_engine_destroy(engine)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let graphMinimizeRequested = Notification.Name("EpistemosGraphMinimizeRequested")
    static let graphRestoreRequested = Notification.Name("EpistemosGraphRestoreRequested")
    static let graphCloseRequested = Notification.Name("EpistemosGraphCloseRequested")
}
