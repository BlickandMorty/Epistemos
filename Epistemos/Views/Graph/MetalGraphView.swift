import SwiftUI
import MetalKit
import QuartzCore
import os
import Synchronization
import SwiftData

nonisolated private let metalGraphLog = Logger(subsystem: "com.epistemos", category: "MetalGraph")

struct GraphNodeBatchPayload {
    var ids: [String] = []
    var xs: [Float] = []
    var ys: [Float] = []
    var types: [UInt8] = []
    var linkCounts: [UInt32] = []
    var labels: [String] = []

    var isEmpty: Bool { ids.isEmpty }
}

struct GraphEdgeBatchPayload {
    var sourceIds: [String] = []
    var targetIds: [String] = []
    var weights: [Float] = []
    var types: [UInt8] = []

    var isEmpty: Bool { sourceIds.isEmpty }
}

nonisolated struct GraphNodeMetadataBatchPayload: Sendable {
    var ids: [String] = []
    var createdAts: [Double] = []
    var updatedAts: [Double] = []
    var confidences: [Float] = []

    var isEmpty: Bool { ids.isEmpty }
}

struct GraphRenderWakeSignature: Equatable {
    let graphStateIdentity: ObjectIdentifier
    let graphDataVersion: Int
    let filterVersion: Int
    let modeVersion: Int
    let liteModeVersion: Int
    let visualThemeVersion: Int
    let forceConfigVersion: Int
    let extendedForceConfigVersion: Int
    let clusterConfigVersion: Int
    let semanticForceConfigVersion: Int
    let semanticClusterVersion: Int
    let labConfigVersion: Int
    let physicsFrozenVersion: Int
    let labelPolicyVersion: Int
    let waterNodesVersion: Int
    let pendingCenterNodeId: String?
    let pendingRebuild: Bool
    let selectedNodeId: String?

    @MainActor
    init(graphState: GraphState) {
        self.graphStateIdentity = ObjectIdentifier(graphState)
        self.graphDataVersion = graphState.graphDataVersion
        self.filterVersion = graphState.filterVersion
        self.modeVersion = graphState.modeVersion
        self.liteModeVersion = graphState.liteModeVersion
        self.visualThemeVersion = graphState.visualThemeVersion
        self.forceConfigVersion = graphState.forceConfigVersion
        self.extendedForceConfigVersion = graphState.extendedForceConfigVersion
        self.clusterConfigVersion = graphState.clusterConfigVersion
        self.semanticForceConfigVersion = graphState.semanticForceConfigVersion
        self.semanticClusterVersion = graphState.semanticClusterVersion
        self.labConfigVersion = graphState.labConfigVersion
        self.physicsFrozenVersion = graphState.physicsFrozenVersion
        self.labelPolicyVersion = graphState.labelPolicyVersion
        self.waterNodesVersion = graphState.waterNodesVersion
        self.pendingCenterNodeId = graphState.pendingCenterNodeId
        self.pendingRebuild = graphState.pendingRebuild
        self.selectedNodeId = graphState.selectedNodeId
    }
}

enum GraphDisplayLinkTransition: Equatable {
    case none
    case start
    case stop
}

nonisolated enum GraphInitialRenderBootstrapState: Equatable {
    case awaitingData
    case bootstrapCommit
    case renderCommittedGraph
}

nonisolated enum GraphRecommitCameraAction: Equatable {
    case pageModeCloseIn
    case animateGlobalFit
    case snapGlobalFit
}

nonisolated func graphInitialRenderBootstrapState(
    isCommitted: Bool,
    isGraphLoaded: Bool
) -> GraphInitialRenderBootstrapState {
    if isCommitted {
        return .renderCommittedGraph
    }
    return isGraphLoaded ? .bootstrapCommit : .awaitingData
}

nonisolated func graphRecommitCameraAction(
    isPageMode: Bool,
    shouldSnapGlobalCamera: Bool
) -> GraphRecommitCameraAction {
    if isPageMode {
        return .pageModeCloseIn
    }
    return shouldSnapGlobalCamera ? .snapGlobalFit : .animateGlobalFit
}

struct GraphNodeHoverHapticState {
    private(set) var hoveredNodeId: String?
    private(set) var lastTickAt: TimeInterval?
    let minimumInterval: TimeInterval

    init(minimumInterval: TimeInterval = 0.08) {
        self.minimumInterval = minimumInterval
    }

    mutating func update(hoveredNodeId: String?, now: TimeInterval) -> Bool {
        guard hoveredNodeId != self.hoveredNodeId else { return false }
        self.hoveredNodeId = hoveredNodeId
        guard hoveredNodeId != nil else { return false }
        guard lastTickAt.map({ now - $0 >= minimumInterval }) ?? true else { return false }
        lastTickAt = now
        return true
    }

    mutating func reset() {
        hoveredNodeId = nil
    }
}

@MainActor
final class GraphDeferredMetadataDriver {
    private enum Phase {
        case idle
        case scheduled
        case running
    }

    private var phase: Phase = .idle
    private var rerunRequested = false
    private var task: Task<Void, Never>?

    func request(run: @escaping @MainActor @Sendable () async -> Void) {
        switch phase {
        case .idle:
            phase = .scheduled
            task = Task { @MainActor [weak self] in
                guard let self else { return }
                // Fix: [Issue 2 - CPU Spin-loops] — sleep when idle instead of
                // hot-looping with Task.yield() (was causing 247 wakeups/sec).
                while true {
                    guard !Task.isCancelled else {
                        self.phase = .idle
                        self.rerunRequested = false
                        self.task = nil
                        return
                    }

                    self.phase = .running
                    await run()

                    guard !Task.isCancelled else {
                        self.phase = .idle
                        self.rerunRequested = false
                        self.task = nil
                        return
                    }

                    guard self.rerunRequested else {
                        self.phase = .idle
                        self.task = nil
                        return
                    }

                    self.rerunRequested = false
                    self.phase = .scheduled
                    // Back off when graph is idle — 30s sleep prevents CPU saturation.
                    try? await Task.sleep(for: .seconds(30))
                }
            }
        case .scheduled:
            return
        case .running:
            rerunRequested = true
        }
    }
}

func graphDisplayLinkTransition(
    needsRender: Bool,
    hasDisplayLink: Bool,
    isPaused: Bool
) -> GraphDisplayLinkTransition {
    guard !isPaused else { return .none }
    if needsRender {
        return hasDisplayLink ? .none : .start
    }
    return hasDisplayLink ? .stop : .none
}

@MainActor
func makeVisibleNodeBatchPayload<Nodes: Collection>(
    from nodes: Nodes,
    store: GraphStore,
    filter: FilterEngine
) -> GraphNodeBatchPayload where Nodes.Element == GraphNodeRecord {
    var payload = GraphNodeBatchPayload()
    payload.ids.reserveCapacity(nodes.count)
    payload.xs.reserveCapacity(nodes.count)
    payload.ys.reserveCapacity(nodes.count)
    payload.types.reserveCapacity(nodes.count)
    payload.linkCounts.reserveCapacity(nodes.count)
    payload.labels.reserveCapacity(nodes.count)

    for node in nodes {
        guard filter.isNodeVisible(node) else { continue }
        payload.ids.append(node.id)
        payload.xs.append(node.position.x)
        payload.ys.append(node.position.y)
        payload.types.append(node.type.rustIndex)
        payload.linkCounts.append(store.linkCount(for: node.id))
        payload.labels.append(node.label)
    }
    return payload
}

@MainActor
func makeVisibleEdgeBatchPayload<Edges: Collection>(
    from edges: Edges,
    store: GraphStore,
    filter: FilterEngine
) -> GraphEdgeBatchPayload where Edges.Element == GraphEdgeRecord {
    var payload = GraphEdgeBatchPayload()
    payload.sourceIds.reserveCapacity(edges.count)
    payload.targetIds.reserveCapacity(edges.count)
    payload.weights.reserveCapacity(edges.count)
    payload.types.reserveCapacity(edges.count)

    for edge in edges {
        let srcVisible = store.nodes[edge.sourceNodeId].map { filter.isNodeVisible($0) } ?? false
        let tgtVisible = store.nodes[edge.targetNodeId].map { filter.isNodeVisible($0) } ?? false
        guard filter.isEdgeVisible(edge, sourceVisible: srcVisible, targetVisible: tgtVisible) else { continue }
        payload.sourceIds.append(edge.sourceNodeId)
        payload.targetIds.append(edge.targetNodeId)
        payload.weights.append(Float(edge.weight))
        payload.types.append(edge.type.rustIndex)
    }
    return payload
}

nonisolated func graphEvidenceConfidence(_ evidenceGrade: String?) -> Float {
    switch evidenceGrade?.uppercased() {
    case "A":
        return 1.0
    case "B":
        return 0.8
    case "C":
        return 0.6
    case "D":
        return 0.4
    case "F":
        return 0.2
    default:
        return 0.0
    }
}

nonisolated func makeVisibleNodeMetadataBatchPayload<Nodes: Collection>(
    from nodes: Nodes,
    filter: GraphFilterSnapshot
) -> GraphNodeMetadataBatchPayload where Nodes.Element == GraphNodeRecord {
    var payload = GraphNodeMetadataBatchPayload()
    payload.ids.reserveCapacity(nodes.count)
    payload.createdAts.reserveCapacity(nodes.count)
    payload.updatedAts.reserveCapacity(nodes.count)
    payload.confidences.reserveCapacity(nodes.count)

    for node in nodes {
        guard filter.isNodeVisible(node) else { continue }
        payload.ids.append(node.id)
        payload.createdAts.append(node.createdAt.timeIntervalSince1970)
        payload.updatedAts.append(node.updatedAt.timeIntervalSince1970)
        payload.confidences.append(graphEvidenceConfidence(node.metadata.evidenceGrade))
    }

    return payload
}

func sendNodeBatch(_ payload: GraphNodeBatchPayload, to engine: OpaquePointer) {
    guard !payload.isEmpty else { return }
    withStableCStringArray(payload.ids) { uuidPtrs in
        withStableCStringArray(payload.labels) { labelPtrs in
            payload.xs.withUnsafeBufferPointer { xs in
                payload.ys.withUnsafeBufferPointer { ys in
                    payload.types.withUnsafeBufferPointer { types in
                        payload.linkCounts.withUnsafeBufferPointer { linkCounts in
                            graph_engine_add_nodes_batch(
                                engine,
                                uuidPtrs.baseAddress,
                                xs.baseAddress,
                                ys.baseAddress,
                                types.baseAddress,
                                linkCounts.baseAddress,
                                labelPtrs.baseAddress,
                                UInt32(payload.ids.count)
                            )
                        }
                    }
                }
            }
        }
    }
}

func sendNodeMetadataBatch(_ payload: GraphNodeMetadataBatchPayload, to engine: OpaquePointer) {
    guard !payload.isEmpty else { return }
    withStableCStringArray(payload.ids) { uuidPtrs in
        payload.createdAts.withUnsafeBufferPointer { createdAts in
            payload.updatedAts.withUnsafeBufferPointer { updatedAts in
                payload.confidences.withUnsafeBufferPointer { confidences in
                    graph_engine_set_node_metadata_batch(
                        engine,
                        uuidPtrs.baseAddress,
                        createdAts.baseAddress,
                        updatedAts.baseAddress,
                        confidences.baseAddress,
                        UInt32(payload.ids.count)
                    )
                }
            }
        }
    }
}

func sendEdgeBatch(_ payload: GraphEdgeBatchPayload, to engine: OpaquePointer) {
    guard !payload.isEmpty else { return }
    withStableCStringArray(payload.sourceIds) { sourcePtrs in
        withStableCStringArray(payload.targetIds) { targetPtrs in
            payload.weights.withUnsafeBufferPointer { weights in
                payload.types.withUnsafeBufferPointer { types in
                    graph_engine_add_edges_batch(
                        engine,
                        sourcePtrs.baseAddress,
                        targetPtrs.baseAddress,
                        weights.baseAddress,
                        types.baseAddress,
                        UInt32(payload.sourceIds.count)
                    )
                }
            }
        }
    }
}

func sendNodeRemovalBatch(_ nodeIds: [String], to engine: OpaquePointer) {
    guard !nodeIds.isEmpty else { return }
    withStableCStringArray(nodeIds) { uuidPtrs in
        graph_engine_remove_nodes_batch(engine, uuidPtrs.baseAddress, UInt32(nodeIds.count))
    }
}

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
        let signature = GraphRenderWakeSignature(graphState: graphState)
        guard nsView.lastRenderWakeSignature != signature else { return }
        nsView.lastRenderWakeSignature = signature
        nsView.needsRender = true
    }
}

// MARK: - MetalGraphNSView
// NSView subclass that owns the CAMetalLayer and Rust engine pointer.
// Uses CVDisplayLink for frame pacing (only renders when the engine requests it).

final class MetalGraphNSView: NSView {
    private typealias DialogueDepthColor = (r: Float, g: Float, b: Float, a: Float)

    private static let dialogueDepthPalette: [DialogueDepthColor] = [
        (0.98, 0.96, 0.90, 1.0),
        (0.95, 0.82, 0.34, 1.0),
        (0.90, 0.66, 0.27, 1.0),
        (0.58, 0.76, 0.43, 1.0),
        (0.34, 0.70, 0.70, 1.0),
        (0.42, 0.56, 0.88, 1.0),
    ]

    nonisolated(unsafe) private var engine: OpaquePointer?
    nonisolated(unsafe) private var activeDisplayLink: CADisplayLink?
    private var metalLayer: CAMetalLayer?
    private nonisolated(unsafe) var backingPropertiesObserver: (any NSObjectProtocol)?
    private nonisolated(unsafe) var occlusionObserver: (any NSObjectProtocol)?
    private nonisolated(unsafe) var powerModeObserver: (any NSObjectProtocol)?

    /// Frame coalescing: prevents queuing multiple render dispatches.
    /// Atomic to avoid data race between CVDisplayLink (background) and main thread.
    private let framePending = Atomic<Bool>(false)

    /// Triple-buffer in-flight semaphore: allows up to 3 frames queued
    /// between CPU and GPU, matching maximumDrawableCount=3. Without
    /// this, the atomic bool drops frames instead of pipelining them.
    private let inFlightSemaphore = DispatchSemaphore(value: 2)

    /// Atomic render-needed flag. CVDisplayLink (background thread) reads this
    /// to skip dispatches when settled. Main thread writes it on user events
    /// and after graph_engine_render() returns.
    private let renderNeeded = Atomic<Bool>(true)

    /// Set during deinit to prevent queued render callbacks from accessing
    /// a destroyed engine. Checked in renderFrame() before any FFI call.
    private let isInvalidated = Atomic<Bool>(false)

    private var isEnginePaused = false

    /// Frame skip counter for 60fps cap in low-power mode on ProMotion displays.
    private var frameSkipCounter: UInt64 = 0

    private var isGraphVisible: Bool {
        !isHidden && alphaValue > 0.001 && bounds.width > 0 && bounds.height > 0
    }

    /// Convenience wrapper for main-thread code. Background thread should
    /// use renderNeeded directly for thread safety.
    fileprivate var needsRender: Bool {
        get { renderNeeded.load(ordering: .relaxed) }
        set {
            renderNeeded.store(newValue, ordering: .relaxed)
            switch graphDisplayLinkTransition(
                needsRender: newValue,
                hasDisplayLink: activeDisplayLink != nil,
                isPaused: isEnginePaused
            ) {
            case .none:
                break
            case .start:
                startDisplayLink()
            case .stop:
                stopDisplayLink()
            }
        }
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
    var lastRenderWakeSignature: GraphRenderWakeSignature?
    var lastForceConfigVersion = 0
    var lastGraphDataVersion = 0
    var lastLiteModeVersion: Int = -1
    var lastPushedQualityLevel: UInt8 = 255
    var lastVisualThemeVersion: Int = -1
    var lastSemanticForceConfigVersion: Int = -1
    /// Current search query text (bound by the search sidebar).
    var searchQuery: String = ""

    // MARK: - Depth-Color Cache
    // Caches the dialogue depth palette computation to avoid O(N) BFS + N FFI calls
    // on every commitGraphData(). Only recomputed when store topology or theme changes.
    private var cachedColorTopologyVersion: Int = -1
    private var cachedColorTheme: GraphVisualTheme = .dialogue
    private var cachedDepthColors: [String: DialogueDepthColor] = [:]
    private let deferredMetadataDriver = GraphDeferredMetadataDriver()

    private var mouseDownLocation: CGPoint?
    private var isDraggingNode = false
    private var isPanning = false
    private var hoverHapticState = GraphNodeHoverHapticState()
    /// Mini mode window drag tracking.
    private var isDraggingWindow = false
    private var windowDragOrigin: NSPoint?
    private var windowFrameOrigin: NSPoint?
    private var sampledSelectedNodeId: String?
    private var lastPublishedSelectedNodeScreenPoint: CGPoint?
    private var pendingSelectedNodeScreenPoint: CGPoint?
    private var selectedNodeScreenPointStableFrames = 0
    private var selectedNodeScreenPointSampleFrame = 0
    private let selectedNodeScreenPointSampleIntervalFrames = 1

    // Track whether graph data has been committed.
    private(set) var isCommitted = false

    var currentEngineHandle: OpaquePointer? { engine }

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

    private func resetSelectedNodeScreenPointTracking(for graphState: GraphState?) {
        sampledSelectedNodeId = nil
        lastPublishedSelectedNodeScreenPoint = nil
        pendingSelectedNodeScreenPoint = nil
        selectedNodeScreenPointStableFrames = 0
        selectedNodeScreenPointSampleFrame = 0
        graphState?.selectedNodeScreenPoint = nil
    }

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
        layer.pixelFormat = .bgra8Unorm_srgb  // MUST match Rust renderer pipeline (BGRA8Unorm_sRGB)
        layer.framebufferOnly = false      // Required for transparent compositing.
        layer.isOpaque = false             // Allow blur to show through.
        layer.maximumDrawableCount = 2     // Double buffer: lower latency, matches standard Metal pipeline.
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
        graphState?.engineHandle = engine
        graphState?.isWarmed = true

        // Load the SDF label atlas once at engine init. Failure is non-fatal
        // — labels just stay hidden until the atlas is regenerated + rebuilt.
        loadSDFLabelAtlasIfAvailable()

        refreshPowerModeObserver()
        startDisplayLink()
    }

    // MARK: - SDF Label Atlas

    private func pushSDFGlyphTable(atlas: SDFLabelAtlas, engineHandle: OpaquePointer) {
        var metrics: [GraphEngineGlyphMetric] = []
        metrics.reserveCapacity(atlas.glyphs.count)
        for (char, glyph) in atlas.glyphs {
            guard let scalar = char.unicodeScalars.first else { continue }
            var m = GraphEngineGlyphMetric()
            m.codepoint = scalar.value
            m.uv_x = glyph.uvRect.x
            m.uv_y = glyph.uvRect.y
            m.uv_w = glyph.uvRect.z
            m.uv_h = glyph.uvRect.w
            m.half_w_em = glyph.halfWidthEm
            m.half_h_em = glyph.halfHeightEm
            m.bearing_x_em = glyph.bearingXEm
            m.bearing_y_em = glyph.bearingYEm
            m.advance_em = glyph.advanceEm
            metrics.append(m)
        }
        metrics.withUnsafeBufferPointer { buf in
            graph_engine_set_label_glyph_table(
                engineHandle,
                buf.baseAddress,
                UInt32(buf.count),
                atlas.lineHeightEm,
                atlas.pxRange
            )
        }
    }

    private func loadSDFLabelAtlasIfAvailable() {
        guard let engineHandle = engine else { return }
        let resourceName = graphState?.labelFontFamily.atlasResourceName ?? "sdf_labels"
        do {
            let atlas = try SDFLabelAtlasLoader.load(
                resourceName: resourceName,
                pushPixels: { width, height, ptr, byteCount in
                    graph_engine_load_label_atlas(
                        engineHandle,
                        UInt32(width),
                        UInt32(height),
                        ptr,
                        UInt64(byteCount)
                    ) != 0
                }
            )
            pushSDFGlyphTable(atlas: atlas, engineHandle: engineHandle)
            graph_engine_set_labels_enabled(engineHandle, 1)
        } catch {
            graph_engine_set_labels_enabled(engineHandle, 0)
        }
    }

    private func refreshPowerModeObserver() {
        if let powerModeObserver {
            NotificationCenter.default.removeObserver(powerModeObserver)
            self.powerModeObserver = nil
        }

        powerModeObserver = NotificationCenter.default.addObserver(
            forName: PowerGuard.modeDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyPowerModeGraphOverrides()
            }
        }
    }

    private func applyPowerModeGraphOverrides() {
        guard let engine, let graphState else { return }
        lastLiteModeVersion = graphState.liteModeVersion
        lastPushedQualityLevel = graphState.qualityLevel
        graph_engine_set_quality_level(engine, graphState.qualityLevel)
        pushForceParams()
        pushExtendedForceParams()
        needsRender = true
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        stopDisplayLink()
        let link = self.displayLink(target: self, selector: #selector(handleDisplayLinkTick(_:)))
        link.add(to: .main, forMode: .common)
        activeDisplayLink = link
    }

    private func stopDisplayLink() {
        guard let link = activeDisplayLink else { return }
        link.invalidate()
        activeDisplayLink = nil
    }

    @objc
    private func handleDisplayLinkTick(_ link: CADisplayLink) {
        guard !isInvalidated.load(ordering: .relaxed) else { return }
        guard renderNeeded.load(ordering: .relaxed) else { return }
        guard !framePending.load(ordering: .relaxed) else { return }

        // 60fps cap in low-power mode: skip every other frame on ProMotion (120Hz).
        frameSkipCounter &+= 1
        if PowerGuard.shared.shouldThrottleRendering && frameSkipCounter % 2 != 0 {
            return
        }

        framePending.store(true, ordering: .relaxed)
        defer { framePending.store(false, ordering: .relaxed) }
        renderFrame()
    }

    /// Pause rendering and physics. Call when overlay is hidden.
    func pauseEngine() {
        isEnginePaused = true
        stopDisplayLink()
        if let engine { graph_engine_pause(engine) }
        metalLayer?.drawableSize = .zero
    }

    /// Resume rendering and physics. Call when overlay is shown.
    func resumeEngine() {
        isEnginePaused = false
        updateMetalLayerBackingProperties()
        if let engine { graph_engine_resume(engine) }
        needsRender = true
    }


    // MARK: - Graph Data Commit

    /// Load all visible nodes and edges from the GraphStore into the Rust engine.
    /// Uses batch FFI to send all nodes/edges in a single call each instead of
    /// N individual calls (critical for 10K+ node performance).
    func commitGraphData() {
        let interval = Log.graphPerf.beginInterval("commitGraphData")
        defer { Log.graphPerf.endInterval("commitGraphData", interval) }
        guard let engine, let graphState else { return }
        let store = graphState.store
        let filter = graphState.filter
        let isPageMode: Bool = {
            if case .page = graphState.mode { return true }
            return false
        }()

        setGraphMode(isPageMode ? 1 : 0)

        graph_engine_clear(engine)

        let nodePayload = makeVisibleNodeBatchPayload(
            from: store.nodes.values,
            store: store,
            filter: filter
        )
        sendNodeBatch(nodePayload, to: engine)

        let edgePayload = makeVisibleEdgeBatchPayload(
            from: store.edges.values,
            store: store,
            filter: filter
        )
        sendEdgeBatch(edgePayload, to: engine)

        // Entrance animation: always play for small graphs (under static threshold),
        // skip for large graphs or when already committed (mid-session recommit).
        let isSmallGraph = graphState.store.nodeCount <= GraphState.staticLayoutThreshold
        let entrance: UInt8 = (isCommitted || (!isSmallGraph && graphState.hasPlayedEntrance)) ? 0 : 1
        let shouldSnapInitialGlobalCamera = isCommitted == false && {
            if case .global = graphState.mode { return true }
            return false
        }()
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
        if shouldSnapInitialGlobalCamera {
            graph_engine_snap_camera_to_fit(engine)
        }

        // Update static layout flag — physics controls grey out when true.
        graphState.isStaticLayout = graph_engine_is_static_layout(engine) != 0

        pushForceParams()
        pushExtendedForceParams()
        pushClusterParams()
        pushSemanticForce()
        pushLabParams()

        // Push graph render mode to Rust.
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
        lastModeVersion = graphState.modeVersion
        lastGraphDataVersion = graphState.graphDataVersion

        isCommitted = true
        needsRender = true

        scheduleDeferredNodeMetadataPush()
    }

    @MainActor
    private func scheduleDeferredNodeMetadataPush() {
        deferredMetadataDriver.request { [weak self] in
            await self?.pushDeferredNodeMetadata()
        }
    }

    @MainActor
    private func pushDeferredNodeMetadata() async {
        guard let engine, let graphState else { return }
        let store = graphState.store
        let filterSnapshot = GraphFilterSnapshot(filter: graphState.filter)
        let interval = Log.graphPerf.beginInterval("pushNodeMetadataBatch")

        let nodes = Array(store.nodes.values)
        let payload = await Task.detached(priority: .utility) {
            makeVisibleNodeMetadataBatchPayload(
                from: nodes,
                filter: filterSnapshot
            )
        }.value
        sendNodeMetadataBatch(payload, to: engine)

        graphState.embeddingService.computeAndPush(store: store)
        Log.graphPerf.endInterval("pushNodeMetadataBatch", interval)
    }

    // MARK: - Incremental FFI Adds

    /// Send pending node/edge additions to the Rust engine individually.
    /// O(k) where k = pending items, vs O(N) for a full recommit.
    private func commitIncrementalAdds(graphState: GraphState) {
        guard let engine else { return }
        let store = graphState.store
        let filter = graphState.filter

        let nodePayload = makeVisibleNodeBatchPayload(
            from: graphState.pendingNodeAdds,
            store: store,
            filter: filter
        )
        sendNodeBatch(nodePayload, to: engine)

        let edgePayload = makeVisibleEdgeBatchPayload(
            from: graphState.pendingEdgeAdds,
            store: store,
            filter: filter
        )
        sendEdgeBatch(edgePayload, to: engine)

        if !nodePayload.isEmpty || !edgePayload.isEmpty {
            graph_engine_commit_incremental(engine)
            if !nodePayload.ids.isEmpty {
                applyDialogueDepthPalette(for: nodePayload.ids)
            }
        }

        graphState.pendingNodeAdds.removeAll()
        graphState.pendingEdgeAdds.removeAll()
    }

    /// Send pending node/edge removals to the Rust engine.
    /// O(k) where k = pending items, vs O(N) for a full recommit.
    private func commitIncrementalRemovals(graphState: GraphState) {
        guard let engine else { return }

        sendNodeRemovalBatch(graphState.pendingNodeRemovals, to: engine)

        for (srcId, tgtId) in graphState.pendingEdgeRemovals {
            _ = srcId.withCString { srcPtr in
                tgtId.withCString { tgtPtr in
                    graph_engine_remove_edge(engine, srcPtr, tgtPtr)
                }
            }
        }

        if !graphState.pendingNodeRemovals.isEmpty || !graphState.pendingEdgeRemovals.isEmpty {
            graph_engine_commit_incremental(engine)
        }

        graphState.pendingNodeRemovals.removeAll()
        graphState.pendingEdgeRemovals.removeAll()
    }

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
    var lastModeVersion: Int = 0
    var lastPhysicsFrozenVersion: Int = 0
    var lastLabConfigVersion: Int = -1
    var lastLabelPolicyVersion: Int = -1
    var lastWaterNodesVersion: Int = -1
    var lastLabelFontVersion: Int = -1

    func pushForceParams() {
        guard let engine, let graphState else { return }

        // In low-power mode: halve charge strength (less N-body compute) and
        // shrink charge range so the simulation settles faster and calmer.
        let throttle = PowerGuard.shared.shouldThrottleRendering
        let chargeScale: Float = throttle ? 0.5 : 1.0
        let rangeScale: Float = throttle ? 0.7 : 1.0

        graph_engine_set_force_params(
            engine,
            graphState.linkDistance,
            graphState.chargeStrength * chargeScale,
            graphState.chargeRange * rangeScale,
            graphState.linkStrength
        )
        needsRender = true
    }

    func pushExtendedForceParams() {
        guard let engine, let graphState else { return }

        // In low-power mode: increase velocity decay so nodes lose energy faster
        // and the simulation reaches equilibrium with fewer ticks.
        let throttle = PowerGuard.shared.shouldThrottleRendering
        let decay = throttle
            ? min(graphState.velocityDecay * 2.0, 0.5)
            : graphState.velocityDecay

        graph_engine_set_extended_force_params(
            engine,
            decay,
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
            0, // tension coloring removed
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
        let ids = uuids.compactMap { clusterMap[$0] }
        guard ids.count == uuids.count else { return }

        withStableCStringArray(uuids) { uuidBuf in
            ids.withUnsafeBufferPointer { idsBuffer in
                guard let idsBaseAddress = idsBuffer.baseAddress else { return }
                graph_engine_set_cluster_ids(
                    engine, uuidBuf.baseAddress, idsBaseAddress, UInt32(uuids.count)
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
              let engine else { return }
        guard let window = window,
              window.occlusionState.contains(.visible) else {
            needsRender = false
            return
        }
        guard isGraphVisible else {
            needsRender = false
            return
        }
        guard let layer = metalLayer else { return }

        // In-flight tracking: acquire a slot. The semaphore allows up to
        // 2 frames in the GPU pipeline (matching maximumDrawableCount=2).
        // Use a short timeout instead of .now() to avoid dropping frames
        // that just need one more millisecond to finish presenting.
        guard inFlightSemaphore.wait(timeout: .now() + .milliseconds(2)) == .success else { return }

        switch graphInitialRenderBootstrapState(
            isCommitted: isCommitted,
            isGraphLoaded: graphState?.isLoaded == true
        ) {
        case .awaitingData:
            return
        case .bootstrapCommit:
            guard let graphState else { return }
            let isPageMode: Bool = {
                if case .page = graphState.mode { return true }
                return false
            }()
            metalGraphLog.debug("Bootstrapping initial graph commit after async load")
            lastModeVersion = graphState.modeVersion
            setGraphMode(isPageMode ? 1 : 0)
            commitGraphData()
            lastGraphDataVersion = graphState.graphDataVersion
        case .renderCommittedGraph:
            break
        }

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

        // Sync quality level when user toggles or PowerGuard forces performance mode.
        if let graphState {
            let currentQL = graphState.qualityLevel
            if lastLiteModeVersion != graphState.liteModeVersion || lastPushedQualityLevel != currentQL {
                lastLiteModeVersion = graphState.liteModeVersion
                lastPushedQualityLevel = currentQL
                graph_engine_set_quality_level(engine, currentQL)
                needsRender = true
            }
        }

        // Sync visual theme when changed.
        if let graphState, lastVisualThemeVersion != graphState.visualThemeVersion {
            lastVisualThemeVersion = graphState.visualThemeVersion
            graph_engine_set_visual_theme(engine, graphState.visualTheme.rawValue)
            applyDialogueDepthPalette()
        }

        // Sync laboratory params (toggles + knobs for advanced physics).
        if let graphState, lastLabConfigVersion != graphState.labConfigVersion {
            lastLabConfigVersion = graphState.labConfigVersion
            pushLabParams()
        }

        // Sync SDF label policy (density + layer transition + focus shrink + font size).
        if let graphState, lastLabelPolicyVersion != graphState.labelPolicyVersion {
            lastLabelPolicyVersion = graphState.labelPolicyVersion
            graph_engine_set_label_policy(
                engine,
                graphState.labelMaxNodes,
                graphState.labelZoomBias,
                graphState.labelZoomPivot,
                graphState.labelFocusShrink,
                graphState.labelFolderThreshold,
                graphState.labelNoteThreshold,
                graphState.labelChatThreshold
            )
            graph_engine_set_label_extras(engine, graphState.labelMaxInnerNodes, graphState.labelInnerOffset)
            graph_engine_set_label_world_px_per_em(engine, graphState.labelFontSizePx)
        }

        // Sync water nodes style.
        if let graphState, lastWaterNodesVersion != graphState.waterNodesVersion {
            lastWaterNodesVersion = graphState.waterNodesVersion
            graph_engine_set_water_nodes(engine, graphState.waterNodesEnabled ? 1.0 : 0.0, graphState.waterNodesWobble)
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

        if let graphState, lastModeVersion != graphState.modeVersion {
            lastModeVersion = graphState.modeVersion
            let isPageMode: Bool = {
                if case .page = graphState.mode { return true }
                return false
            }()
            setGraphMode(isPageMode ? 1 : 0)
            if isPageMode {
                zoomInClose()
            } else {
                graph_engine_zoom_to_fit(engine)
            }
            needsRender = true
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

        // Drain incremental removals (before adds, in case a remove+add cycle happens).
        if let graphState,
           !graphState.pendingNodeRemovals.isEmpty || !graphState.pendingEdgeRemovals.isEmpty {
            commitIncrementalRemovals(graphState: graphState)
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
            lastModeVersion = graphState.modeVersion
            setGraphMode(isPageMode ? 1 : 0)
            commitGraphData()
            let cameraAction = graphRecommitCameraAction(
                isPageMode: isPageMode,
                shouldSnapGlobalCamera: graphState.shouldSnapNextGlobalRecommitCamera
            )
            graphState.shouldSnapNextGlobalRecommitCamera = false
            switch cameraAction {
            case .pageModeCloseIn:
                zoomInClose()
            case .animateGlobalFit:
                graph_engine_zoom_to_fit(engine)
                graph_engine_center_camera(engine)
            case .snapGlobalFit:
                graph_engine_snap_camera_to_fit(engine)
            }
        }

        let size = layer.drawableSize
        let w = UInt32(size.width)
        let h = UInt32(size.height)
        guard w > 0, h > 0 else { return }

        let result = graph_engine_render(engine, w, h)

        // Update selected node screen position for inspector tracking.
        // Only write when value actually changes to avoid triggering observation every frame.
        if let nodeId = graphState?.selectedNodeId {
            if sampledSelectedNodeId != nodeId {
                sampledSelectedNodeId = nodeId
                lastPublishedSelectedNodeScreenPoint = nil
                pendingSelectedNodeScreenPoint = nil
                selectedNodeScreenPointStableFrames = 0
                selectedNodeScreenPointSampleFrame = 0
            }

            selectedNodeScreenPointSampleFrame &+= 1
            let shouldSampleSelectedNodeScreenPoint =
                graphState?.selectedNodeScreenPoint == nil
                || lastPublishedSelectedNodeScreenPoint == nil
                || pendingSelectedNodeScreenPoint == nil
                || selectedNodeScreenPointStableFrames < 1
                || isDraggingNode
                || isPanning
                || selectedNodeScreenPointSampleFrame % selectedNodeScreenPointSampleIntervalFrames == 0

            if shouldSampleSelectedNodeScreenPoint {
                var posBuf: [Float] = [0, 0]
                let found = nodeId.withCString { ptr in
                    graph_engine_node_screen_pos(engine, ptr, &posBuf)
                }
                if found != 0 {
                    let scale = metalLayer?.contentsScale ?? 2.0
                    let pt = CGPoint(
                        x: CGFloat(posBuf[0]) / scale,
                        y: bounds.height - CGFloat(posBuf[1]) / scale
                    )
                    // Throttle @Observable writes: only publish when the point
                    // moved >2px. Writing every frame at 120Hz causes an
                    // observation storm that starves the main thread.
                    let delta: CGFloat
                    if let last = lastPublishedSelectedNodeScreenPoint {
                        let dx = pt.x - last.x
                        let dy = pt.y - last.y
                        delta = (dx * dx + dy * dy).squareRoot()
                    } else {
                        delta = .greatestFiniteMagnitude
                    }
                    if delta > 2.0 {
                        lastPublishedSelectedNodeScreenPoint = pt
                        graphState?.selectedNodeScreenPoint = pt
                    }
                } else if graphState?.selectedNodeScreenPoint != nil || sampledSelectedNodeId != nil {
                    resetSelectedNodeScreenPointTracking(for: graphState)
                }
            }
        } else if graphState?.selectedNodeScreenPoint != nil || sampledSelectedNodeId != nil {
            resetSelectedNodeScreenPointTracking(for: graphState)
        }

        // Keep rendering while physics is active (result != 0) or while
        // pinned panels exist AND the graph hasn't fully settled yet.
        // Once physics settles (result == 0 for consecutive frames), stop
        // rendering even with pinned panels — they don't need updates when
        // nodes aren't moving. Any new interaction will restart the loop.
        needsRender = result != 0

        // Release the in-flight semaphore slot so the next frame can queue.
        // graph_engine_render() calls commandBuffer.commit() + present()
        // internally, so GPU work is submitted at this point.
        inFlightSemaphore.signal()
    }

    // MARK: - Input Events

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
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
                        guard let edgeType,
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

        let loc = convert(event.locationInWindow, from: nil)
        let scale = metalLayer?.contentsScale ?? 2.0
        graph_engine_mouse_up(engine, Float(loc.x * scale), Float((bounds.height - loc.y) * scale))

        // Sync selection state: node click → select, background click → deselect.
        // Rust mouse_up already highlights neighbors on click and clears on background.
        let uuidPtr = graph_engine_selected_node_uuid(engine)
        if let uuidPtr {
            let uuid = String(cString: uuidPtr)
            graphState?.selectNode(uuid)

            // In freeze mode, animate camera to focus on the selected node.
            // centerOnNode sets target_offset + target_zoom and triggers the
            // Rust renderer's smooth camera lerp animation.
            if graphState?.isPhysicsFrozen == true {
                centerOnNode(uuid)
            }
        } else {
            graphState?.selectNode(nil)
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
            return nil
        }
    }

    // MARK: Node Menu

    private func buildNodeContextMenu(uuid: String, clickWorldPos: SIMD2<Float>) -> NSMenu? {
        guard let node = graphState?.store.nodes[uuid] else { return nil }
        let menu = NSMenu()

        // "Open Note" — only for note-type nodes that have a sourceId.
        if node.type == .note, let sourceId = node.sourceId {
            let openItem = NSMenuItem(title: "Open Note", action: #selector(contextOpenNote(_:)), keyEquivalent: "")
            openItem.target = self
            openItem.representedObject = ["pageId": sourceId, "nodeId": uuid]
            openItem.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Open Note")
            menu.addItem(openItem)
        }

        // "Focus" — zoom into this node's neighborhood.
        let focusItem = NSMenuItem(title: "Focus on Node", action: #selector(contextFocusNode(_:)), keyEquivalent: "")
        focusItem.target = self
        focusItem.representedObject = uuid
        focusItem.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "Focus")
        menu.addItem(focusItem)

        return menu
    }

    // MARK: Context Menu Actions

    @objc private func contextOpenNote(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String],
              let pageId = info["pageId"],
              let nodeId = info["nodeId"] else { return }
        // Focus the graph on this node, minimize to mini mode, then open the note.
        isolateNode(nodeId)
        graphState?.selectNode(nodeId)
        HologramController.shared.minimize()
        NoteWindowManager.shared.open(pageId: pageId)
    }

    @objc private func contextFocusNode(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String else { return }
        isolateNode(uuid)
        graphState?.selectNode(uuid)
    }

    @objc private func contextEditNote(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String else { return }
        graphState?.requestEditorMode = true
        graphState?.selectNode(uuid)
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
        // Only write graphHoveredNodeId when it actually changes to avoid
        // re-evaluating every .graphReactive() sidebar row on each mouse move.
        if !isDraggingNode && !isPanning {
            if let uuidPtr = graph_engine_hovered_node_uuid(engine) {
                NSCursor.pointingHand.set()
                let hoveredId = String(cString: uuidPtr)
                if hoverHapticState.update(hoveredNodeId: hoveredId, now: event.timestamp) {
                    MainActor.assumeIsolated {
                        HapticHelper.sidebarHoverTick()
                    }
                }
                if physicsCoordinator?.graphHoveredNodeId != hoveredId {
                    physicsCoordinator?.graphHoveredNodeId = hoveredId
                }
            } else {
                NSCursor.arrow.set()
                _ = hoverHapticState.update(hoveredNodeId: nil, now: event.timestamp)
                if physicsCoordinator?.graphHoveredNodeId != nil {
                    physicsCoordinator?.graphHoveredNodeId = nil
                }
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
        hoverHapticState.reset()
        physicsCoordinator?.graphHoveredNodeId = nil
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        updateMetalLayerBackingProperties()
        needsRender = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshWindowObservers()
        updateMetalLayerBackingProperties()
        if window != nil, !isCommitted, graphState?.isLoaded == true {
            commitGraphData()
        }
    }

    private func refreshWindowObservers() {
        if let backingPropertiesObserver {
            NotificationCenter.default.removeObserver(backingPropertiesObserver)
            self.backingPropertiesObserver = nil
        }
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
            self.occlusionObserver = nil
        }
        guard let window else { return }

        backingPropertiesObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeBackingPropertiesNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateMetalLayerBackingProperties()
                self.needsRender = true
            }
        }

        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      let window = self.window else { return }
                let visible = window.occlusionState.contains(.visible)
                metalGraphLog.debug("Window occlusion changed: visible=\(visible, privacy: .public)")
                self.needsRender = visible
            }
        }
    }

    private func updateMetalLayerBackingProperties() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        metalLayer?.contentsScale = scale
        metalLayer?.drawableSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )
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
        let store = graphState.store
        let shouldColorize = graphState.visualTheme == .dialogue
        let currentTopology = store.topologyVersion

        // Recompute depth-color map only when topology or theme has changed.
        let themeChanged = cachedColorTheme != graphState.visualTheme
        if cachedColorTopologyVersion != currentTopology || themeChanged || cachedDepthColors.isEmpty {
            cachedColorTheme = graphState.visualTheme
            let interval = Log.graphPerf.beginInterval("recomputeDepthColors")
            let depths = graphDepthLevels(store: store)
            let maxDepth = depths.values.max() ?? 0
            cachedDepthColors.removeAll(keepingCapacity: true)
            for (nodeId, node) in store.nodes {
                if shouldColorize {
                    cachedDepthColors[nodeId] = dialogueDepthColor(
                        for: node,
                        depth: depths[nodeId] ?? graphBaseDepth(for: node.type),
                        maxDepth: maxDepth
                    )
                } else {
                    cachedDepthColors[nodeId] = (0.0, 0.0, 0.0, 0.0)
                }
            }
            cachedColorTopologyVersion = currentTopology
            Log.graphPerf.endInterval("recomputeDepthColors", interval)
        }

        // Push colors to Rust — either targeted subset or all visible nodes.
        let targetIds = nodeIds ?? Array(store.nodes.keys)
        for nodeId in targetIds {
            guard let node = store.nodes[nodeId],
                  graphState.filter.isNodeVisible(node) else { continue }
            let color = cachedDepthColors[nodeId] ?? (0.0, 0.0, 0.0, 0.0)
            node.id.withCString { uuidPtr in
                graph_engine_set_node_color_override(engine, uuidPtr, color.r, color.g, color.b, color.a)
            }
        }

        needsRender = true
    }

    // MARK: - Cleanup

    deinit {
        // Mark invalidated FIRST so any in-flight DispatchQueue.main.async from
        // the CVDisplayLink callback will skip renderFrame() and avoid
        // accessing the destroyed engine pointer.
        isInvalidated.store(true, ordering: .relaxed)

        // Drain the in-flight semaphore: signal it back to its initial
        // value (3) so deallocation doesn't hit the "BUG IN CLIENT OF
        // LIBDISPATCH: semaphore object deallocated while in use" trap.
        // Any in-flight frames will see isInvalidated=true and bail.
        for _ in 0..<3 {
            inFlightSemaphore.signal()
        }
        if let backingPropertiesObserver {
            NotificationCenter.default.removeObserver(backingPropertiesObserver)
        }
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
        }
        if let powerModeObserver {
            NotificationCenter.default.removeObserver(powerModeObserver)
        }
        // Inline display-link stop — can't call @MainActor stopDisplayLink() from nonisolated deinit.
        // Safe: no other references exist during deallocation.
        if let link = activeDisplayLink {
            link.invalidate()
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
    static let graphResetRequested = Notification.Name("EpistemosGraphResetRequested")
    static let graphRestoreRequested = Notification.Name("EpistemosGraphRestoreRequested")
    static let graphCloseRequested = Notification.Name("EpistemosGraphCloseRequested")
}
