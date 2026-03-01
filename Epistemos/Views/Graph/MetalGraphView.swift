import SwiftUI
import MetalKit
import Synchronization

// MARK: - MetalGraphView
// NSViewRepresentable wrapping a CAMetalLayer for the Rust graph engine.
// Bridges SwiftUI ↔ Metal ↔ Rust FFI. The engine owns the render loop;
// this view just provides the surface and forwards input events.

struct MetalGraphView: NSViewRepresentable {
    @Environment(GraphState.self) private var graphState

    func makeNSView(context: Context) -> MetalGraphNSView {
        let view = MetalGraphNSView()
        view.graphState = graphState
        return view
    }

    func updateNSView(_ nsView: MetalGraphNSView, context: Context) {
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
    var lastForceConfigVersion = 0
    var lastGraphDataVersion = 0
    var lastLiteModeVersion = -1
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
        if entrance == 1 { graphState.hasPlayedEntrance = true }

        // Update static layout flag — physics controls grey out when true.
        graphState.isStaticLayout = graph_engine_is_static_layout(engine) != 0

        pushForceParams()

        // Push quality level to Rust and sync version tracker.
        graph_engine_set_quality_level(engine, graphState.qualityLevel)
        lastLiteModeVersion = graphState.liteModeVersion

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

    func pushClusterParams() {
        guard let engine, let graphState else { return }
        graph_engine_set_cluster_params(engine, graphState.clusterStrength)
        graph_engine_set_center_mode(engine, graphState.centerMode)
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

        // Sync cluster params (cluster strength, center mode).
        if let graphState, lastClusterConfigVersion != graphState.clusterConfigVersion {
            lastClusterConfigVersion = graphState.clusterConfigVersion
            pushClusterParams()
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
        needsRender = result != 0
    }

    // MARK: - Input Events

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
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
            // In mini mode, background drag moves the window.
            if isMiniMode {
                isDraggingWindow = true
                windowDragOrigin = NSEvent.mouseLocation
                windowFrameOrigin = window?.frame.origin
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

            // Notify in-note graph mode about the tap (if callback is set).
            if let onNodeTap, let sourceId = graphState?.store.nodes[uuid]?.sourceId {
                onNodeTap(sourceId)
            }
        } else {
            graphState?.selectNode(nil)

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

        // Update cursor based on hover state (only when not dragging).
        if !isDraggingNode && !isPanning {
            if graph_engine_hovered_node_uuid(engine) != nil {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
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
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
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

    // MARK: - Cleanup

    deinit {
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
