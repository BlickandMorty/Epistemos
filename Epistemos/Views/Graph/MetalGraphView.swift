import SwiftUI
import MetalKit
import QuartzCore
import os
import Synchronization
import SwiftData

nonisolated private let metalGraphLog = Logger(subsystem: "com.epistemos", category: "MetalGraph")

enum GraphThemeNodePalette {
    typealias RGBA = (r: Float, g: Float, b: Float, a: Float)

    static func color(for type: GraphNodeType, theme: EpistemosTheme) -> RGBA {
        if type == .folder {
            return theme.isDark ? (1.0, 1.0, 1.0, 1.0) : (0.0, 0.0, 0.0, 1.0)
        }

        let base = baseColor(for: type)
        let tint = tintColor(for: theme)
        let amount = tintAmount(for: type, theme: theme)
        return mix(base, tint, amount)
    }

    private static func tintAmount(for type: GraphNodeType, theme: EpistemosTheme) -> Float {
        switch theme {
        case .systemLight, .systemDark, .light, .oled:
            return 0.0
        default:
            switch type {
            case .note, .proseNote, .document:
                return 0.05
            case .idea:
                return 0.14
            default:
                return 0.10
            }
        }
    }

    private static func baseColor(for type: GraphNodeType) -> RGBA {
        switch type {
        case .note:       return (0.94, 0.08, 0.07, 1.0)
        case .chat:       return (1.00, 0.62, 0.04, 1.0)
        case .idea:       return (1.00, 0.84, 0.04, 1.0)
        case .source:     return (0.20, 0.78, 0.35, 1.0)
        case .folder:     return (0.0, 0.0, 0.0, 1.0)
        case .quote:      return (0.69, 0.32, 0.87, 1.0)
        case .tag:        return (0.46, 0.46, 0.50, 1.0)
        case .block:      return (0.55, 0.78, 0.90, 1.0)
        case .person:     return (0.83, 0.35, 0.58, 1.0)
        case .project:    return (0.89, 0.42, 0.16, 1.0)
        case .topic:      return (0.20, 0.56, 0.95, 1.0)
        case .decision:   return (0.83, 0.20, 0.18, 1.0)
        case .event:      return (0.98, 0.56, 0.27, 1.0)
        case .resource:   return (0.14, 0.55, 0.52, 1.0)
        case .run:        return (0.42, 0.42, 0.78, 1.0)
        case .rawThought: return (0.74, 0.58, 0.92, 1.0)
        case .toolTrace:  return (0.46, 0.50, 0.55, 1.0)
        case .proseNote:  return (0.92, 0.11, 0.09, 1.0)
        case .document:   return (0.88, 0.14, 0.12, 1.0)
        case .code:       return (0.85, 0.55, 0.18, 1.0)
        case .output:     return (0.40, 0.44, 0.50, 1.0)
        }
    }

    private static func tintColor(for theme: EpistemosTheme) -> RGBA {
        let hex = theme.resolved.headingAccentHex
        return (
            Float((hex >> 16) & 0xFF) / 255.0,
            Float((hex >> 8) & 0xFF) / 255.0,
            Float(hex & 0xFF) / 255.0,
            1.0
        )
    }

    private static func mix(_ base: RGBA, _ tint: RGBA, _ amount: Float) -> RGBA {
        let t = min(max(amount, 0.0), 1.0)
        return (
            base.r + (tint.r - base.r) * t,
            base.g + (tint.g - base.g) * t,
            base.b + (tint.b - base.b) * t,
            1.0
        )
    }
}

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
    let userForceOverlayVersion: Int
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
        self.userForceOverlayVersion = graphState.userForceOverlayVersion
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

nonisolated enum GraphInteractionRenderPolicy {
    static func inFlightWaitMilliseconds(
        isInteracting: Bool,
        lowPowerMode: Bool
    ) -> Int {
        // 2026-05-20: bumped non-low-power timeouts (interacting 4→6, idle 2→4)
        // to give the GPU more headroom at 120Hz before dropping a frame.
        // With native `.glassEffect()` on chrome (toolbar / sidebar / inspector /
        // controls) layered on top of the wallpaper NSVisualEffectView blur,
        // total compositor work is ~5 shader passes per frame. The 2ms idle
        // timeout dropped real 120Hz-eligible frames whenever the GPU spiked
        // even slightly. 4ms idle still keeps the CPU/GPU paced (semaphore
        // value=2 caps in-flight frames) but no longer drops frames that
        // just need a millisecond longer.
        switch (isInteracting, lowPowerMode) {
        case (true, false):
            6
        case (true, true):
            2
        case (false, false):
            4
        case (false, true):
            1
        }
    }

    static func selectedNodePublishDistance(isInteracting: Bool) -> CGFloat {
        isInteracting ? 8 : 2
    }

    static func selectedNodeSampleIntervalFrames(isInteracting: Bool) -> Int {
        isInteracting ? 4 : 1
    }
}

nonisolated enum GraphDrawableResolutionPolicy {
    private static let performanceFullOverlayPixelBudget: CGFloat = 3_000_000
    private static let lowPowerPixelBudget: CGFloat = 1_200_000
    static let pausedDrawableSize = CGSize(width: 1, height: 1)

    /// Cinematic mode always renders at full native Retina regardless of node count.
    /// Per user 2026-05-12: pixel-art identity is the canonical look on every vault
    /// size; do NOT trade resolution for fps. Performance / low-power modes still
    /// cap because they're explicit fast paths the user opts into.
    static func pixelBudget(qualityLevel: UInt8, lowPowerMode: Bool) -> CGFloat {
        if lowPowerMode { return lowPowerPixelBudget }
        return qualityLevel >= 2 ? performanceFullOverlayPixelBudget : CGFloat.greatestFiniteMagnitude
    }

    static func effectiveScale(
        boundsSize: CGSize,
        backingScale: CGFloat,
        isMiniMode: Bool,
        lowPowerMode: Bool,
        qualityLevel: UInt8
    ) -> CGFloat {
        guard boundsSize.width.isFinite,
              boundsSize.height.isFinite,
              backingScale.isFinite,
              boundsSize.width > 0,
              boundsSize.height > 0,
              backingScale > 0
        else {
            return 1.0
        }

        if isMiniMode {
            return backingScale
        }

        let nativePixels = boundsSize.width * backingScale * boundsSize.height * backingScale
        let budget = pixelBudget(qualityLevel: qualityLevel, lowPowerMode: lowPowerMode)
        guard nativePixels > budget else {
            return backingScale
        }

        let cappedScale = backingScale * sqrt(budget / nativePixels)
        return min(backingScale, max(1.0, cappedScale))
    }

    static func layerContentsScale(backingScale: CGFloat) -> CGFloat {
        guard backingScale.isFinite, backingScale > 0 else { return 1.0 }
        return backingScale
    }

    static func drawableSize(
        boundsSize: CGSize,
        scale: CGFloat
    ) -> CGSize {
        CGSize(
            width: max(1, (boundsSize.width * scale).rounded(.down)),
            height: max(1, (boundsSize.height * scale).rounded(.down))
        )
    }
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
                    // Yield once so queued requests can coalesce without stalling
                    // the rerun behind a long idle backoff.
                    await Task.yield()
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
        let degreeCount = store.linkCount(for: node.id)
        let semanticFolderCount: UInt32 = if node.type == .folder {
            UInt32(max(1, min(Double(UInt32.max), node.weight.rounded(.up))))
        } else {
            degreeCount
        }
        payload.linkCounts.append(max(degreeCount, semanticFolderCount))
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
    let interval = Log.ffiPerf.beginInterval("graph_engine_add_nodes_batch")
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
    Log.ffiPerf.endInterval("graph_engine_add_nodes_batch", interval)
}

func sendNodeMetadataBatch(_ payload: GraphNodeMetadataBatchPayload, to engine: OpaquePointer) {
    guard !payload.isEmpty else { return }
    let interval = Log.ffiPerf.beginInterval("graph_engine_set_node_metadata_batch")
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
    Log.ffiPerf.endInterval("graph_engine_set_node_metadata_batch", interval)
}

func sendEdgeBatch(_ payload: GraphEdgeBatchPayload, to engine: OpaquePointer) {
    guard !payload.isEmpty else { return }
    let interval = Log.ffiPerf.beginInterval("graph_engine_add_edges_batch")
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
    Log.ffiPerf.endInterval("graph_engine_add_edges_batch", interval)
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
        let appearanceSyncKey = uiState.appearanceSyncKey
        nsView.syncThemeIfNeeded(appearanceSyncKey: appearanceSyncKey)
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

    nonisolated(unsafe) private var engine: OpaquePointer?
    nonisolated(unsafe) private var activeDisplayLink: CADisplayLink?
    private var metalLayer: CAMetalLayer?
    private var graphDrawableScale: CGFloat = 2.0
    private nonisolated(unsafe) var backingPropertiesObserver: (any NSObjectProtocol)?
    private nonisolated(unsafe) var occlusionObserver: (any NSObjectProtocol)?
    private nonisolated(unsafe) var powerModeObserver: (any NSObjectProtocol)?
    private nonisolated(unsafe) var graphRenderSettingsObserver: (any NSObjectProtocol)?

    /// Frame coalescing: prevents queuing multiple render dispatches.
    /// Atomic to avoid data race between CVDisplayLink (background) and main thread.
    private let framePending = Atomic<Bool>(false)

    /// Double-buffer in-flight semaphore: allows up to 2 frames queued
    /// between CPU and GPU, below maximumDrawableCount=3. Without
    /// this, the atomic bool drops frames instead of pipelining them.
    private let inFlightSemaphore = DispatchSemaphore(value: 2)

    /// Atomic render-needed flag. CVDisplayLink (background thread) reads this
    /// to skip dispatches when settled. Main thread writes it on user events
    /// and after graph_engine_render() returns.
    private let renderNeeded = Atomic<Bool>(true)

    /// Set during deinit to prevent queued render callbacks from accessing
    /// a destroyed engine. Checked in renderFrame() before any FFI call.
    private let isInvalidated = Atomic<Bool>(false)

    // MARK: - FPS Sampling (2026-05-20)
    //
    // Tiny ring buffer of frame intervals (CFAbsoluteTime deltas). Updated
    // at the top of every renderFrame(). Drives the in-app FPS HUD and
    // the GraphState.graphMeasuredFPS / graphMeasuredP99Ms surface.
    private static let fpsSampleCount = 120
    private var fpsSampleIntervals = ContiguousArray<Double>(
        repeating: 1.0 / 120.0, count: MetalGraphNSView.fpsSampleCount
    )
    private var fpsSampleCursor: Int = 0
    private var lastFrameAbsoluteTime: CFAbsoluteTime = 0
    /// Throttles graphState writeback to ~5 Hz so SwiftUI doesn't redraw
    /// the HUD label every single frame (which would itself burn budget).
    private var lastFPSPublishTime: CFAbsoluteTime = 0
    /// Cached cap version so we re-apply the CADisplayLink frame-rate
    /// range only when the user changes the setting.
    private var lastAppliedFPSConfigVersion: Int = -1

    private var isEnginePaused = false

    // MARK: - Shared Position Buffers
    //
    // Canonical graph plan Phase A Week 1 (2026-05-12): flipped from
    // env-var-opt-in to default-on. The Metal-allocated .storageModeShared
    // ring buffer + 3-slot semaphore is now the production path; the
    // legacy graph_engine_read_positions ferry is retained only as a
    // debug fallback while the rest of Phase A wires through.
    //
    // To opt out (e.g., for A/B perf testing against the old ferry path),
    // set EPISTEMOS_USE_SHARED_GRAPH_BUFFERS=0 in the launch environment.
    //
    // Source: docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md §"Phase A —
    // CPU foundation + zero-copy" → "Week 1: Shared-buffer foundation".
    private static let useSharedGraphBuffers: Bool = {
        // Honor an explicit "0" env-var override (for benchmarking or
        // bisecting regressions against the legacy ferry path); default
        // to true otherwise.
        if let raw = ProcessInfo.processInfo.environment["EPISTEMOS_USE_SHARED_GRAPH_BUFFERS"] {
            return raw != "0"
        }
        return true
    }()

    private var sharedPositionBuffers: [MTLBuffer] = []
    private let sharedBufferSemaphore = DispatchSemaphore(value: 3)
    private var sharedBufferWriteIndex: UInt32 = 0
    private static let sharedBufferMaxNodes = 10_000
    private static let sharedBufferFloatsPerNode = 2
    private static let sharedBufferByteSize = sharedBufferMaxNodes * sharedBufferFloatsPerNode * MemoryLayout<Float>.size

    private func setupSharedPositionBuffers() {
        guard Self.useSharedGraphBuffers, let device = metalLayer?.device, let engine else { return }

        for i in 0..<3 {
            guard let buffer = device.makeBuffer(length: Self.sharedBufferByteSize, options: .storageModeShared) else {
                continue
            }
            buffer.label = "SharedPositionBuffer[\(i)]"
            sharedPositionBuffers.append(buffer)

            let ptr = buffer.contents().bindMemory(to: Float.self, capacity: Self.sharedBufferMaxNodes * Self.sharedBufferFloatsPerNode)
            graph_engine_set_shared_position_buffer(
                engine,
                UInt32(i),
                ptr,
                UInt32(Self.sharedBufferMaxNodes * Self.sharedBufferFloatsPerNode)
            )
        }
    }

    private func teardownSharedPositionBuffers() {
        guard let engine else { return }
        for i in 0..<sharedPositionBuffers.count {
            graph_engine_unset_shared_position_buffer(engine, UInt32(i))
        }
        sharedPositionBuffers.removeAll()
    }

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
                graphState?.embeddingService.prepareForEngineUse()
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
    var lastAppearanceSyncKey = ""
    var lastSemanticForceConfigVersion: Int = -1
    /// Current search query text (bound by the search sidebar).
    var searchQuery: String = ""

    // MARK: - Depth-Color Cache
    // Caches the dialogue depth palette computation to avoid O(N) BFS + N FFI calls
    // on every commitGraphData(). Only recomputed when store topology or theme changes.
    private var cachedColorTopologyVersion: Int = -1
    private var cachedColorTheme: GraphVisualTheme = .dialogue
    private var cachedColorResolvedTheme: EpistemosTheme?
    private var cachedDepthColors: [String: DialogueDepthColor] = [:]

    // AR6 (master plan Phase 8 / Wave 13 §"Phase 8") — caches the
    // CognitiveDepthOverlay lookup per node so the visualization
    // contract (altitude / radiusScale / colorTint) is paid once per
    // commit rather than per render frame. Mirrors the dialogue
    // depth-color cache shape so future renderers (label haloing,
    // insight bubbles) can read the same map without re-hitting the
    // sidecar.
    private var cachedCognitiveDepthMarkers: [String: DepthMarker] = [:]
    private var cachedCognitiveDepthAltitudes: [String: Float] = [:]
    private var cachedCognitiveDepthRadiusScales: [String: Float] = [:]
    private var cachedCognitiveDepthTopologyVersion: Int = -1
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
    private var selectedNodeScreenPointSampleFrame = 0
    private var pendingPointerUpdate: SIMD2<Float>?
    private var pendingScrollPanDelta = SIMD2<Float>(repeating: 0)
    private var pendingScrollZoomAnchor: SIMD2<Float>?
    private var pendingScrollZoomDelta: Float = 0
    private var pendingPinchZoomAnchor: SIMD2<Float>?
    private var pendingPinchZoomDelta: Float = 0
    private var currentLightMode = false

    // Track whether graph data has been committed.
    private(set) var isCommitted = false

    var currentEngineHandle: OpaquePointer? { engine }

    private var currentGraphDrawableScale: CGFloat {
        graphDrawableScale.isFinite && graphDrawableScale > 0 ? graphDrawableScale : 1.0
    }

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
        let changed = currentLightMode != enabled
        currentLightMode = enabled
        graph_engine_set_light_mode(engine, enabled ? 1 : 0)
        if changed {
            applyDialogueDepthPalette()
        }
        needsRender = true
    }

    func syncThemeIfNeeded(appearanceSyncKey: String) {
        guard lastAppearanceSyncKey != appearanceSyncKey else { return }
        guard engine != nil else { return }
        lastAppearanceSyncKey = appearanceSyncKey
        guard let uiState else { return }
        let theme = uiState.graphOverlayTheme
        setLightMode(!theme.isDark)
        loadSDFLabelAtlasIfAvailable()
        applyDialogueDepthPalette()
        needsRender = true
    }

    /// When true, the view is in the mini floating panel. Background taps are disabled
    /// and Option+drag moves the parent window (holographic drag).
    var isMiniMode = false {
        didSet {
            guard isMiniMode != oldValue else { return }
            updateMetalLayerBackingProperties()
            needsRender = true
        }
    }

    private func resetSelectedNodeScreenPointTracking(for graphState: GraphState?) {
        sampledSelectedNodeId = nil
        lastPublishedSelectedNodeScreenPoint = nil
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
        layer.maximumDrawableCount = 3     // Fullscreen cinematic graph shading needs a spare drawable to avoid visible hitching.
        // 2026-05-20: explicit displaySyncEnabled = true. The default is also
        // true on macOS but we set it explicitly to document the contract:
        // the layer presents at vsync intervals (every 8.33ms on a 120Hz
        // ProMotion display). Without vsync we'd tear; with it we hit the
        // display's native refresh rate when the CADisplayLink + GPU keep up.
        layer.displaySyncEnabled = true
        // NOTE: presentsWithTransaction intentionally left at default (false). Enabling
        // it would require coordinating commit+waitUntilScheduled+present on the Rust
        // renderer side (graph-engine/src/renderer.rs) — see Phase H follow-up.
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
        graphState?.embeddingService.prepareForEngineUse()
        graphState?.engineHandle = engine
        graphState?.isWarmed = true

        // Load the SDF label atlas once at engine init. Failure is non-fatal
        // — labels just stay hidden until the atlas is regenerated + rebuilt.
        loadSDFLabelAtlasIfAvailable()

        refreshGraphRenderSettingsObserver()
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

    private func currentLabelAtlasResourceName() -> String {
        let isDark = uiState?.graphOverlayTheme.isDark ?? SystemAppearanceState.isDark()
        return graphState?.labelFontFamily.atlasResourceName(isDark: isDark)
            ?? AppDisplayTypography.graphLabelAtlasResourceName(isDark: isDark)
    }

    private func loadSDFLabelAtlasIfAvailable(force: Bool = false) {
        guard let engineHandle = engine else { return }
        let interval = Log.ffiPerf.beginInterval("loadSDFLabelAtlas")
        let resourceName = currentLabelAtlasResourceName()
        guard force || loadedLabelAtlasResourceName != resourceName else {
            Log.ffiPerf.endInterval("loadSDFLabelAtlas", interval)
            return
        }
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
            loadedLabelAtlasResourceName = resourceName
        } catch {
            let errorDescription = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            let labelMaxNodes = graphState?.labelMaxNodes ?? 0
            let labelZoomBias = graphState?.labelZoomBias ?? 0
            let labelZoomPivot = graphState?.labelZoomPivot ?? 0
            let labelFontSizePx = graphState?.labelFontSizePx ?? 0
            metalGraphLog.error(
                """
                MetalGraphNSView: failed to load label atlas \(resourceName, privacy: .public); disabling labels. \
                labelMaxNodes=\(labelMaxNodes) labelZoomBias=\(labelZoomBias) \
                labelZoomPivot=\(labelZoomPivot) labelFontSizePx=\(labelFontSizePx) \
                error=\(errorDescription, privacy: .public)
                """
            )
            graph_engine_set_labels_enabled(engineHandle, 0)
            loadedLabelAtlasResourceName = resourceName
        }
        Log.ffiPerf.endInterval("loadSDFLabelAtlas", interval)
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
            MainActor.assumeIsolated {
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

    private func refreshGraphRenderSettingsObserver() {
        if let graphRenderSettingsObserver {
            NotificationCenter.default.removeObserver(graphRenderSettingsObserver)
            self.graphRenderSettingsObserver = nil
        }

        graphRenderSettingsObserver = NotificationCenter.default.addObserver(
            forName: .graphRenderSettingsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.needsRender = true
            }
        }
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        stopDisplayLink()
        let link = self.displayLink(target: self, selector: #selector(handleDisplayLinkTick(_:)))
        // 2026-05-20: respect the user's `graphMaxFPS` setting if set.
        // 0 = Unlimited → ProMotion adaptive 60-120. Otherwise clamp to
        // the chosen cap. Defaults to 0 (Unlimited) on first launch.
        link.preferredFrameRateRange = framePolicyRange()
        if let graphState {
            lastAppliedFPSConfigVersion = graphState.graphFPSConfigVersion
        }
        link.add(to: .main, forMode: .common)
        activeDisplayLink = link
    }

    /// Pure mapping from `graphState.graphMaxFPS` to `CAFrameRateRange`.
    /// Lives at instance scope so the live-reconfig path in renderFrame()
    /// can call it without restarting the display link.
    private func framePolicyRange() -> CAFrameRateRange {
        // MASTER OVERRIDE — when `graphForceMaximumFPS` is on, ignore
        // the cap picker, ignore PowerGuard, ignore thermal state, and
        // pin to ProMotion's top rate. The 120/120/120 tight range
        // tells the OS to NEVER drop below 120; the display link will
        // skip rather than slow.
        if graphState?.graphForceMaximumFPS == true {
            return CAFrameRateRange(minimum: 120, maximum: 120, preferred: 120)
        }
        let cap = graphState?.graphMaxFPS ?? 0
        switch cap {
        case 30:
            return CAFrameRateRange(minimum: 24, maximum: 30, preferred: 30)
        case 60:
            return CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        case 120:
            // Tight 120/120/120 range — tells the OS we explicitly want
            // ProMotion's top rate. Min stays 120 so a frame that takes
            // 9ms doesn't pull the display rate down to 60 mid-session.
            return CAFrameRateRange(minimum: 120, maximum: 120, preferred: 120)
        default:
            // 0 = Unlimited / adaptive — original wide range.
            return CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        }
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

        framePending.store(true, ordering: .relaxed)
        defer { framePending.store(false, ordering: .relaxed) }
        renderFrame()
    }

    /// Pause rendering and physics. Call when overlay is hidden.
    func pauseEngine() {
        isEnginePaused = true
        stopDisplayLink()
        if let engine { graph_engine_pause(engine) }
        metalLayer?.drawableSize = GraphDrawableResolutionPolicy.pausedDrawableSize
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

        // Entrance animation: play for small graphs only. Very large vaults keep
        // their precomputed spiral positions so the Rust entrance layout cannot
        // stretch disconnected components into the sanitizer clamp square.
        let isSmallGraph = graphState.store.nodeCount <= GraphState.largeGraphEntranceThreshold
        let entrance: UInt8 = (!isCommitted && isSmallGraph) ? 1 : 0
        let shouldSnapInitialGlobalCamera = isCommitted == false && {
            if case .global = graphState.mode { return true }
            return false
        }()
        let commitInterval = Log.ffiPerf.beginInterval("graph_engine_commit")
        graph_engine_commit(engine, entrance)
        Log.ffiPerf.endInterval("graph_engine_commit", commitInterval)
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
            applyDefaultGlobalCameraFrame(animated: false)
        }

        // Update user-freeze/static flag — physics controls grey out when true.
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
        applyCognitiveDepthOverlay()
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
        lastCameraConfigVersion = graphState.cameraConfigVersion
        pushCameraSettings()
        lastClusterConfigVersion = graphState.clusterConfigVersion
        lastSemanticForceConfigVersion = graphState.semanticForceConfigVersion
        lastLabConfigVersion = graphState.labConfigVersion
        // Seed user-directed force overlays so persisted cursor/shape
        // state survives a fresh graph commit.
        pushUserForceOverlays()
        lastUserForceOverlayVersion = graphState.userForceOverlayVersion
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
                applyCognitiveDepthOverlay(for: nodePayload.ids)
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

        // Re-check user-freeze/static flag after visibility refresh.
        graphState.isStaticLayout = graph_engine_is_static_layout(engine) != 0

        needsRender = true
    }

    // MARK: - Force Params

    var lastUserForceOverlayVersion: Int = -1
    var lastExtendedForceConfigVersion: Int = -1
    var lastCameraConfigVersion: Int = -1
    var lastClusterConfigVersion: Int = -1
    var lastSemanticClusterVersion: Int = -1
    var lastFilterVersion: Int = 0
    var lastModeVersion: Int = 0
    var lastPhysicsFrozenVersion: Int = 0
    var lastLabConfigVersion: Int = -1
    var lastLabelPolicyVersion: Int = -1
    var lastWaterNodesVersion: Int = -1
    var lastLabelFontVersion: Int = -1
    private var loadedLabelAtlasResourceName: String?

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

    /// Push the user-directed cursor force + shape-bound state to the
    /// Rust simulation. Called from updateNSView and the render loop
    /// when `graphState.userForceOverlayVersion` changes.
    func pushUserForceOverlays() {
        guard let engine, let graphState else { return }
        graph_engine_set_cursor_force(
            engine,
            graphState.cursorForceMode.ffiValue,
            graphState.cursorForceStrength
        )
        graph_engine_set_shape_bound(
            engine,
            graphState.shapeBoundKind.ffiValue,
            graphState.shapeBoundRadius
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

    func pushCameraSettings() {
        guard let engine, let graphState else { return }
        graph_engine_set_camera_settings(
            engine,
            graphState.cameraDeselectZoomMultiplier,
            graphState.cameraSpeedLambda
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

    private func applyDefaultGlobalCameraFrame(animated: Bool) {
        guard let engine else { return }
        if animated {
            graph_engine_zoom_to_fit(engine)
        } else {
            graph_engine_snap_camera_to_fit(engine)
        }
        // Pad the default global frame so the graph doesn't fill the viewport
        // edge-to-edge when the user opens or resets the full canvas.
        let scale = currentGraphDrawableScale
        let cx = Float(bounds.width * 0.5 * scale)
        let cy = Float(bounds.height * 0.5 * scale)
        graph_engine_magnify(engine, cx, cy, GraphOverlayPhysicsPolicy.defaultGlobalCameraMagnification)
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
        let scale = currentGraphDrawableScale
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
        let scale = currentGraphDrawableScale
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
        let isInteracting = isDraggingNode || isPanning
        let waitTimeoutMS = GraphInteractionRenderPolicy.inFlightWaitMilliseconds(
            isInteracting: isInteracting,
            lowPowerMode: PowerGuard.shared.shouldThrottleRendering
        )

        // FPS sampling. Sample at the TOP of renderFrame (not the bottom)
        // so we capture the actual inter-tick interval the CADisplayLink
        // is firing at. Updates a ring buffer that the HUD reads via the
        // ~5Hz publish path further down.
        let nowAbsolute = CFAbsoluteTimeGetCurrent()
        if lastFrameAbsoluteTime > 0 {
            let interval = nowAbsolute - lastFrameAbsoluteTime
            fpsSampleIntervals[fpsSampleCursor] = max(interval, 0.0001)
            fpsSampleCursor = (fpsSampleCursor + 1) % Self.fpsSampleCount
        }
        lastFrameAbsoluteTime = nowAbsolute

        // Live-reconfig the display link if the user changed the FPS cap.
        // Cheap version-gated check — no FFI, just an int compare.
        if let graphState,
           lastAppliedFPSConfigVersion != graphState.graphFPSConfigVersion,
           let link = activeDisplayLink {
            lastAppliedFPSConfigVersion = graphState.graphFPSConfigVersion
            link.preferredFrameRateRange = framePolicyRange()
        }

        // In-flight tracking: acquire a slot. The semaphore allows up to
        // 2 frames in the GPU pipeline, leaving one spare drawable.
        // Use a short timeout instead of .now() to avoid dropping frames
        // that just need one more millisecond to finish presenting.
        guard inFlightSemaphore.wait(timeout: .now() + .milliseconds(waitTimeoutMS)) == .success else { return }
        defer { inFlightSemaphore.signal() }

        // Per-frame signpost — feeds Phase 0 perf budget (graph.frame.ms).
        // Master plan target: <12 ms p99 @ 60 Hz, <6 ms @ 120 Hz.
        let frameSignpostInterval = Log.graphPerf.beginInterval("graph.frame.ms")
        defer { Log.graphPerf.endInterval("graph.frame.ms", frameSignpostInterval) }

        // Wave 2.1 canonical perf signpost (subsystem io.epistemos.core / render).
        // Coexists with the legacy graphPerf signpost above; Instruments can
        // filter on either subsystem. Per dpp §1.1 Task 0.1.
        // begin/defer-end pattern (not closure wrapper) for TSAN safety —
        // closure wrapping non-Sendable engine pointer trips strict-concurrency.
        let renderSignpostId = Sig.render.makeSignpostID()
        let renderState = Sig.render.beginInterval("frame", id: renderSignpostId)
        defer { Sig.render.endInterval("frame", renderState) }

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

        // Sync camera settings (deselect zoom multiplier + lerp speed).
        // Pushed every frame instead of version-gated — the function is two
        // f32 field writes on the Rust side, cheaper than the cost of a
        // missed slider update. The version-check path was unreliable for
        // this surface (notification observer + render-loop wake) and the
        // user reported the sliders had no visible effect; this guarantees
        // current slider values reach the engine on the very next render.
        if let graphState {
            graph_engine_set_camera_settings(
                engine,
                graphState.cameraDeselectZoomMultiplier,
                graphState.cameraSpeedLambda
            )
            lastCameraConfigVersion = graphState.cameraConfigVersion
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
            applyCognitiveDepthOverlay()
        }

        // Sync laboratory params (toggles + knobs for advanced physics).
        if let graphState, lastLabConfigVersion != graphState.labConfigVersion {
            lastLabConfigVersion = graphState.labConfigVersion
            pushLabParams()
        }

        // Sync user-directed force overlays (V6.2 toolbar 2026-05-12).
        // Cursor force (suck/repel/vortex) + shape bound (5 shapes).
        if let graphState, lastUserForceOverlayVersion != graphState.userForceOverlayVersion {
            lastUserForceOverlayVersion = graphState.userForceOverlayVersion
            pushUserForceOverlays()
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

        if let graphState, lastLabelFontVersion != graphState.labelFontVersion {
            lastLabelFontVersion = graphState.labelFontVersion
            loadSDFLabelAtlasIfAvailable(force: true)
            needsRender = true
        }

        // Sync the legacy cinematic-node style flag.
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
                applyDefaultGlobalCameraFrame(animated: true)
            }
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
            if let modelContainer = AppBootstrap.shared?.modelContainer {
                Task(priority: .utility) { [weak graphState] in
                    guard let graphState else { return }
                    let refreshedIncrementally = await graphState.refreshStructuralDataAsync(container: modelContainer)
                    if !refreshedIncrementally {
                        graphState.shouldSnapNextGlobalRecommitCamera = true
                        graphState.requestRecommit()
                    }
                }
            } else {
                metalGraphLog.error("Graph rebuild requested without a model container; dropping pending rebuild")
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
                applyDefaultGlobalCameraFrame(animated: true)
            case .snapGlobalFit:
                applyDefaultGlobalCameraFrame(animated: false)
            }
        }

        flushPendingInteractionInputs(engine: engine)

        let size = layer.drawableSize
        let w = UInt32(size.width)
        let h = UInt32(size.height)
        guard w > 0, h > 0 else { return }

        let renderInterval = Log.ffiPerf.beginInterval("graph_engine_render")
        let result = graph_engine_render(engine, w, h)
        Log.ffiPerf.endInterval("graph_engine_render", renderInterval)

        // Update selected node screen position for inspector tracking.
        // Only write when value actually changes to avoid triggering observation every frame.
        if let nodeId = graphState?.selectedNodeId {
            if sampledSelectedNodeId != nodeId {
                sampledSelectedNodeId = nodeId
                lastPublishedSelectedNodeScreenPoint = nil
                selectedNodeScreenPointSampleFrame = 0
            }

            let selectedNodeSampleIntervalFrames = GraphInteractionRenderPolicy.selectedNodeSampleIntervalFrames(
                isInteracting: isInteracting
            )
            selectedNodeScreenPointSampleFrame &+= 1
            let shouldSampleSelectedNodeScreenPoint =
                graphState?.selectedNodeScreenPoint == nil
                || lastPublishedSelectedNodeScreenPoint == nil
                || selectedNodeScreenPointSampleFrame % selectedNodeSampleIntervalFrames == 0

            if shouldSampleSelectedNodeScreenPoint {
                var posBuf: [Float] = [0, 0]
                let found = nodeId.withCString { ptr in
                    graph_engine_node_screen_pos(engine, ptr, &posBuf)
                }
                if found != 0 {
                    let scale = currentGraphDrawableScale
                    let pt = CGPoint(
                        x: CGFloat(posBuf[0]) / scale,
                        y: bounds.height - CGFloat(posBuf[1]) / scale
                    )
                    // Throttle @Observable writes: only publish when the point
                    // moved >2px. Writing every frame at 120Hz causes an
                    // observation storm that starves the main thread.
                    let publishDistance = GraphInteractionRenderPolicy.selectedNodePublishDistance(
                        isInteracting: isInteracting
                    )
                    let delta: CGFloat
                    if let last = lastPublishedSelectedNodeScreenPoint {
                        let dx = pt.x - last.x
                        let dy = pt.y - last.y
                        delta = (dx * dx + dy * dy).squareRoot()
                    } else {
                        delta = .greatestFiniteMagnitude
                    }
                    if delta > publishDistance {
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

        // Keep rendering only while physics is genuinely active. The prior
        // `|| hasPinnedPanels` short-circuit kept the Metal render loop
        // ticking at display-refresh rate whenever a pinned inspector
        // existed — even after physics fully settled — which read to the
        // user as continuous canvas stutter.
        //
        // Pinned-panel coordinate freshness is already handled by the
        // 30fps pinnedPanelTimer in HologramOverlay (which reads
        // graph_engine_node_screen_pos directly) plus the Rust engine's
        // force_alive flag (d20f416b) that bypasses its own idle skip so
        // update_camera / node_screen_pos return accurate values even
        // when no render is in flight. User interactions (pan / zoom /
        // new physics) set needsRender through other paths, so there is
        // no staleness window that this line needs to cover.
        needsRender = result != 0

        // ~5 Hz FPS publish — only when the HUD is on. Computes mean
        // interval + p99 over the ring buffer. Skipping when HUD is
        // off keeps the @Observable write storm off the main thread
        // for users who don't care about the meter.
        if let graphState, graphState.graphFPSHUDEnabled,
           nowAbsolute - lastFPSPublishTime > 0.2 {
            lastFPSPublishTime = nowAbsolute
            publishFPSMetrics(to: graphState)
        }

        // Release the in-flight semaphore slot so the next frame can queue.
        // graph_engine_render() calls commandBuffer.commit() + present()
        // internally, so GPU work is submitted at this point.
    }

    /// Computes rolling mean FPS + p99 frame-interval from the ring
    /// buffer and writes to GraphState. Called at most ~5 Hz from the
    /// render loop when the HUD is enabled. Allocations are bounded
    /// by `fpsSampleCount` (120).
    private func publishFPSMetrics(to graphState: GraphState) {
        var sorted = Array(fpsSampleIntervals)
        sorted.sort()
        let n = sorted.count
        let p99Index = max(0, min(n - 1, Int(Double(n) * 0.99)))
        let p99Interval = sorted[p99Index]
        var sum = 0.0
        for interval in sorted { sum += interval }
        let mean = sum / Double(n)
        let fps = mean > 0 ? 1.0 / mean : 0
        graphState.graphMeasuredFPS = fps
        graphState.graphMeasuredP99Ms = p99Interval * 1000.0
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
            let scale = currentGraphDrawableScale
            graph_engine_mouse_moved(engine, Float(loc.x * scale), Float((bounds.height - loc.y) * scale))
            return
        }

        let loc = convert(event.locationInWindow, from: nil)
        mouseDownLocation = loc
        let scale = currentGraphDrawableScale
        let shift: UInt8 = event.modifierFlags.contains(.shift) ? 1 : 0
        pendingPointerUpdate = nil
        graph_engine_mouse_down(engine, Float(loc.x * scale), Float((bounds.height - loc.y) * scale), shift)

        // Phase 7: Local Route Navigation via Double-Click
        if event.clickCount == 2 {
            if let uuidPtr = graph_engine_hovered_node_uuid(engine) {
                let uuid = String(cString: uuidPtr)
                graphState?.openNode(uuid)
                return
            }
        }

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

    // MARK: - Phase 7 Context Menus (Right Click)

    override func rightMouseDown(with event: NSEvent) {
        guard let engine else {
            super.rightMouseDown(with: event)
            return
        }

        let loc = convert(event.locationInWindow, from: nil)
        let scale = currentGraphDrawableScale
        // Ensure the engine knows the mouse locus so we can grab the accurate hovered node
        graph_engine_mouse_moved(engine, Float(loc.x * scale), Float((bounds.height - loc.y) * scale))

        if let uuidPtr = graph_engine_hovered_node_uuid(engine) {
            let uuid = String(cString: uuidPtr)

            let menu = NSMenu()

            let goItem = NSMenuItem(title: "Go to Node", action: #selector(contextMenuGoToNode(_:)), keyEquivalent: "")
            goItem.representedObject = uuid
            goItem.target = self
            menu.addItem(goItem)

            let revealItem = NSMenuItem(title: "Reveal in Graph", action: #selector(contextMenuRevealInGraph(_:)), keyEquivalent: "")
            revealItem.representedObject = uuid
            revealItem.target = self
            menu.addItem(revealItem)

            let chatItem = NSMenuItem(title: "Ask Graph Chat", action: #selector(contextMenuAskGraphChat(_:)), keyEquivalent: "")
            chatItem.representedObject = uuid
            chatItem.target = self
            menu.addItem(chatItem)

            NSMenu.popUpContextMenu(menu, with: event, for: self)
        } else {
            super.rightMouseDown(with: event)
        }
    }

    @objc private func contextMenuGoToNode(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        graphState?.openNode(id)
    }

    @objc private func contextMenuRevealInGraph(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        graphState?.pendingCenterNodeId = id
    }

    @objc private func contextMenuAskGraphChat(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        // Posts a typed GraphChatRequest on `.graphChatRequested`. The
        // Agent Command Center (or a future dedicated GraphChatState)
        // listens and prefills its composer with the node context. No
        // second chat session is created here — this is an intent event,
        // not a control-plane mutation.
        guard let request = graphState?.askGraphChat(nodeId: id) else {
            metalGraphLog.info(
                "Ask Graph Chat no-op: missing state or node \(id, privacy: .public)"
            )
            return
        }
        metalGraphLog.info(
            "Ask Graph Chat dispatched for node \(request.graphNodeId, privacy: .public) type=\(request.nodeType, privacy: .public)"
        )
    }

    override func mouseDragged(with event: NSEvent) {
        guard engine != nil else { return }

        // In mini mode, background drag moves the floating window.
        if isMiniMode && isDraggingWindow, let origin = windowDragOrigin, let frameOrigin = windowFrameOrigin {
            let current = NSEvent.mouseLocation
            let dx = current.x - origin.x
            let dy = current.y - origin.y
            window?.setFrameOrigin(NSPoint(x: frameOrigin.x + dx, y: frameOrigin.y + dy))
            return
        }

        let loc = convert(event.locationInWindow, from: nil)
        let scale = currentGraphDrawableScale
        let screenX = Float(loc.x * scale)
        let screenY = Float((bounds.height - loc.y) * scale)
        pendingPointerUpdate = SIMD2<Float>(screenX, screenY)
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
        let scale = currentGraphDrawableScale
        pendingPointerUpdate = nil
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
        let scale = currentGraphDrawableScale
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
        // Focus the graph on this node, then route to the graph-native note page.
        isolateNode(nodeId)
        graphState?.selectNode(nodeId)
        graphState?.openNote(pageId)
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
        let scale = currentGraphDrawableScale
        let screenX = Float(loc.x * scale)
        let screenY = Float((bounds.height - loc.y) * scale)
        graph_engine_mouse_moved(engine, screenX, screenY)
        var shouldRender = false

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
                    shouldRender = true
                }
                if physicsCoordinator?.graphHoveredNodeId != hoveredId {
                    physicsCoordinator?.graphHoveredNodeId = hoveredId
                    shouldRender = true
                }
            } else {
                NSCursor.arrow.set()
                if hoverHapticState.update(hoveredNodeId: nil, now: event.timestamp) {
                    shouldRender = true
                }
                if physicsCoordinator?.graphHoveredNodeId != nil {
                    physicsCoordinator?.graphHoveredNodeId = nil
                    shouldRender = true
                }
            }
        }
        if shouldRender {
            needsRender = true
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard engine != nil else { return }
        let scale = currentGraphDrawableScale
        let loc = convert(event.locationInWindow, from: nil)
        let sx = Float(loc.x * scale)
        let sy = Float((bounds.height - loc.y) * scale)

        // Default scroll → zoom (game-like). Option+scroll → pan.
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods.contains(.option) {
            // Option+scroll → pan (standard 2D mode).
            let dx = Float(event.scrollingDeltaX * scale)
            let dy = Float(event.scrollingDeltaY * scale)
            pendingScrollPanDelta.x += dx
            pendingScrollPanDelta.y += dy
        } else {
            // Zoom toward cursor (default for both trackpad and mouse wheel).
            let sensitivity: Float = event.hasPreciseScrollingDeltas ? 0.005 : 0.06
            let magnification = Float(event.scrollingDeltaY) * sensitivity
            pendingScrollZoomAnchor = SIMD2<Float>(sx, sy)
            pendingScrollZoomDelta += magnification
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
                let scale = currentGraphDrawableScale
                let cx = Float(bounds.width * 0.5 * scale)
                let cy = Float(bounds.height * 0.5 * scale)
                graph_engine_magnify(engine, cx, cy, 0.15)
                needsRender = true
                return
            case "-":
                // Cmd+- → zoom out from center.
                let scale = currentGraphDrawableScale
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
        guard engine != nil else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let scale = currentGraphDrawableScale
        pendingPinchZoomAnchor = SIMD2<Float>(
            Float(loc.x * scale),
            Float((bounds.height - loc.y) * scale)
        )
        pendingPinchZoomDelta += Float(event.magnification)
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
            MainActor.assumeIsolated {
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
            MainActor.assumeIsolated {
                guard let self,
                      let window = self.window else { return }
                let visible = window.occlusionState.contains(.visible)
                metalGraphLog.debug("Window occlusion changed: visible=\(visible, privacy: .public)")
                self.needsRender = visible
            }
        }
    }

    private func updateMetalLayerBackingProperties() {
        let backingScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let effectiveScale = GraphDrawableResolutionPolicy.effectiveScale(
            boundsSize: bounds.size,
            backingScale: backingScale,
            isMiniMode: isMiniMode,
            lowPowerMode: PowerGuard.shared.shouldThrottleRendering,
            qualityLevel: graphState?.qualityLevel ?? 0
        )
        graphDrawableScale = effectiveScale
        metalLayer?.contentsScale = GraphDrawableResolutionPolicy.layerContentsScale(backingScale: backingScale)
        metalLayer?.drawableSize = GraphDrawableResolutionPolicy.drawableSize(
            boundsSize: bounds.size,
            scale: effectiveScale
        )
    }

    private func flushPendingInteractionInputs(engine: OpaquePointer) {
        if let pointer = pendingPointerUpdate {
            graph_engine_mouse_moved(engine, pointer.x, pointer.y)
            pendingPointerUpdate = nil
        }

        if pendingScrollPanDelta != .zero {
            graph_engine_scroll(engine, pendingScrollPanDelta.x, pendingScrollPanDelta.y)
            pendingScrollPanDelta = .zero
        }

        if let anchor = pendingScrollZoomAnchor, pendingScrollZoomDelta != 0 {
            graph_engine_magnify(engine, anchor.x, anchor.y, pendingScrollZoomDelta)
            pendingScrollZoomAnchor = nil
            pendingScrollZoomDelta = 0
        }

        if let anchor = pendingPinchZoomAnchor, pendingPinchZoomDelta != 0 {
            graph_engine_magnify(engine, anchor.x, anchor.y, pendingPinchZoomDelta)
            pendingPinchZoomAnchor = nil
            pendingPinchZoomDelta = 0
        }
    }

    private func graphBaseDepth(for type: GraphNodeType) -> Int {
        switch type {
        case .folder: 0
        case .note, .chat: 2
        case .idea, .source, .quote, .person, .project, .topic, .decision, .event, .resource: 3
        case .tag, .block: 4
        case .run, .rawThought, .toolTrace: 3  // Patch 5: Raw Thoughts artifacts at idea/source depth
        case .proseNote, .document: 2          // Wave 3.3: typed cognitive artifacts at note depth
        case .code, .output: 3                 // Wave 3.3: code/output at source depth
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

    private func dialogueDepthColor(
        for node: GraphNodeRecord,
        depth _: Int,
        maxDepth _: Int,
        theme: EpistemosTheme
    ) -> DialogueDepthColor {
        GraphThemeNodePalette.color(for: node.type, theme: theme)
    }

    private func applyDialogueDepthPalette(for nodeIds: [String]? = nil) {
        guard let graphState else { return }
        let store = graphState.store
        let resolvedTheme = uiState?.graphOverlayTheme ?? (currentLightMode ? .systemLight : .systemDark)
        let usesDialogueDepth = graphState.visualTheme == .dialogue
        let currentTopology = store.topologyVersion

        // Recompute depth-color map only when topology or theme has changed.
        let themeChanged = cachedColorTheme != graphState.visualTheme
            || cachedColorResolvedTheme != resolvedTheme
        if cachedColorTopologyVersion != currentTopology || themeChanged || cachedDepthColors.isEmpty {
            cachedColorTheme = graphState.visualTheme
            cachedColorResolvedTheme = resolvedTheme
            let interval = Log.graphPerf.beginInterval("recomputeDepthColors")
            let depths = graphDepthLevels(store: store)
            let maxDepth = depths.values.max() ?? 0
            cachedDepthColors.removeAll(keepingCapacity: true)
            for (nodeId, node) in store.nodes {
                if usesDialogueDepth {
                    cachedDepthColors[nodeId] = dialogueDepthColor(
                        for: node,
                        depth: depths[nodeId] ?? graphBaseDepth(for: node.type),
                        maxDepth: maxDepth,
                        theme: resolvedTheme
                    )
                } else {
                    cachedDepthColors[nodeId] = GraphThemeNodePalette.color(for: node.type, theme: resolvedTheme)
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

    // MARK: - Cognitive Depth Overlay (AR6 / master-plan Phase 8)

    /// Resolve the on-disk source URL backing a graph note node by
    /// fetching the SDPage's `filePath` via the GraphState model
    /// context. Returns nil for nodes that don't map to a file
    /// (folder/tag/source/quote/block) or for notes whose SDPage has
    /// no persisted `filePath` yet (in-memory-only drafts). Run on
    /// the @MainActor since SwiftData fetches are MainActor-isolated.
    private func cognitiveDepthSourceURL(for node: GraphNodeRecord) -> URL? {
        guard node.type == .note,
              let pageId = node.sourceId, !pageId.isEmpty,
              let context = graphState?.modelContext else {
            return nil
        }
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == pageId }
        )
        guard let page = (try? context.fetch(descriptor))?.first,
              let raw = page.filePath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: raw)
    }

    /// AR6 (master-plan Phase 8 / Wave 13 §"Phase 8") — for every
    /// visible note node, look up its `DepthMarker` via
    /// `CognitiveDepthOverlay.shared.depth(for:)` then read the
    /// overlay's non-color visualization helpers. The base graph body
    /// palette is owned by the Rust renderer so light-mode nodes stay
    /// solid OLED black and dark-mode nodes stay pitch white. Altitude
    /// + radiusScale are cached on the Swift side so the label / halo
    /// overlay path can read them without re-hitting the sidecar.
    ///
    /// Targeted recomputation: when `nodeIds` is non-nil only those
    /// nodes are re-paid (used by `commitIncrementalAdds`); when nil
    /// the entire visible set is repainted (used by `commitGraphData`
    /// + topology change).
    private func applyCognitiveDepthOverlay(for nodeIds: [String]? = nil) {
        guard let graphState else { return }
        let store = graphState.store
        let currentTopology = store.topologyVersion

        let interval = Log.graphPerf.beginInterval("applyCognitiveDepthOverlay")
        defer { Log.graphPerf.endInterval("applyCognitiveDepthOverlay", interval) }

        let isFullRepaint = nodeIds == nil
        if isFullRepaint && cachedCognitiveDepthTopologyVersion != currentTopology {
            cachedCognitiveDepthMarkers.removeAll(keepingCapacity: true)
            cachedCognitiveDepthAltitudes.removeAll(keepingCapacity: true)
            cachedCognitiveDepthRadiusScales.removeAll(keepingCapacity: true)
        }

        let overlay = CognitiveDepthOverlay.shared
        let targetIds = nodeIds ?? Array(store.nodes.keys)
        for nodeId in targetIds {
            guard let node = store.nodes[nodeId],
                  graphState.filter.isNodeVisible(node),
                  let sourceURL = cognitiveDepthSourceURL(for: node) else { continue }

            let marker = overlay.depth(for: sourceURL)
            cachedCognitiveDepthMarkers[nodeId] = marker
            cachedCognitiveDepthAltitudes[nodeId] = overlay.altitude(for: marker)
            cachedCognitiveDepthRadiusScales[nodeId] = overlay.radiusScale(for: marker)
        }

        if isFullRepaint {
            cachedCognitiveDepthTopologyVersion = currentTopology
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
        // Drain semaphore to its initial value (2) so deallocation doesn't
        // hit the "BUG IN CLIENT OF LIBDISPATCH" trap.
        for _ in 0..<2 {
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
        if let graphRenderSettingsObserver {
            NotificationCenter.default.removeObserver(graphRenderSettingsObserver)
        }
        // Inline display-link stop — can't call @MainActor stopDisplayLink() from nonisolated deinit.
        // Safe: no other references exist during deallocation.
        if let link = activeDisplayLink {
            link.invalidate()
        }
        // Cancel embedding work and drain detached engine users BEFORE destroying the engine.
        graphState?.embeddingService.prepareForEngineDestroy()
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
    static let graphRenderSettingsChanged = Notification.Name("EpistemosGraphRenderSettingsChanged")
}
