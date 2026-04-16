import Foundation
import NaturalLanguage
import os
import SwiftData

// MARK: - GraphVisualTheme

enum GraphVisualTheme: UInt8, CaseIterable, Codable {
    case dialogue = 0
    case classic = 1

    var displayName: String {
        switch self {
        case .dialogue: "Dialogue"
        case .classic:  "Classic"
        }
    }
}

// MARK: - GraphMode
// Two graph views matching LogSeq: global (all nodes) and page (node + neighbors).

enum GraphMode: Sendable {
    case global
    case page(nodeId: String)
}

enum GraphOverlayPhysicsPolicy {
    static let openingPreset: PhysicsPreset = .deepSea
    static let restingPreset: PhysicsPreset = .chaos
    static let chaosDelaySeconds: TimeInterval = 4
    static let interactionMotionHoldSeconds: TimeInterval = 30
    static let interactionMotionAlphaTarget: Float = 0.015

    static func preset(afterElapsedSeconds elapsed: TimeInterval) -> PhysicsPreset {
        elapsed >= chaosDelaySeconds ? restingPreset : openingPreset
    }
}

private final class EngineHandleState: Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var handle: OpaquePointer?

    nonisolated init() {}

    nonisolated func load() -> OpaquePointer? {
        lock.lock()
        defer { lock.unlock() }
        return handle
    }

    nonisolated func store(_ handle: OpaquePointer?) {
        lock.lock()
        defer { lock.unlock() }
        self.handle = handle
    }
}

// MARK: - Physics Presets

enum PhysicsPreset: String, CaseIterable, Identifiable {
    case observatory = "Observatory"     // Default — spread out, calm
    case nebula = "Nebula"               // Loose, floaty, gentle drift
    case crystal = "Crystal"             // Tight, structured, snappy
    case fluid = "Fluid"                 // Bouncy, dynamic, alive
    case constellation = "Constellation" // Very spread, minimal gravity
    case deepSea = "Deep Sea"            // Heavy viscosity, slow currents
    case solarSystem = "Solar System"    // Orbital hierarchies, wide spacing
    case windTunnel = "Wind Tunnel"      // Lateral wind, low friction
    case snowflake = "Snowflake"         // Max torsion, crystalline
    case rubberBand = "Rubber Band"      // Strong springs, bouncy
    case zenGarden = "Zen Garden"        // Minimal forces, peaceful drift
    case chaos = "Chaos"                 // Everything cranked, wild

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .observatory:   return "moonphase.waning.gibbous"
        case .nebula:        return "cloud"
        case .crystal:       return "diamond"
        case .fluid:         return "drop"
        case .constellation: return "sparkles"
        case .deepSea:       return "water.waves"
        case .solarSystem:   return "sun.max"
        case .windTunnel:    return "wind"
        case .snowflake:     return "snowflake"
        case .rubberBand:    return "lasso"
        case .zenGarden:     return "leaf"
        case .chaos:         return "bolt.fill"
        }
    }

    var linkDistance: Float {
        switch self {
        case .observatory:   return 80
        case .nebula:        return 280
        case .crystal:       return 80
        case .fluid:         return 180
        case .constellation: return 350
        case .deepSea:       return 200
        case .solarSystem:   return 300
        case .windTunnel:    return 200
        case .snowflake:     return 100
        case .rubberBand:    return 220
        case .zenGarden:     return 300
        case .chaos:         return 150
        }
    }
    var chargeStrength: Float {
        switch self {
        case .observatory:   return -300
        case .nebula:        return -250
        case .crystal:       return -300
        case .fluid:         return -350
        case .constellation: return -200
        case .deepSea:       return -300
        case .solarSystem:   return -400
        case .windTunnel:    return -300
        case .snowflake:     return -800
        case .rubberBand:    return -400
        case .zenGarden:     return -150
        case .chaos:         return -1000
        }
    }
    var chargeRange: Float {
        switch self {
        case .observatory:   return 400
        case .nebula:        return 1200
        case .crystal:       return 400
        case .fluid:         return 1000
        case .constellation: return 1500
        case .deepSea:       return 800
        case .solarSystem:   return 1500
        case .windTunnel:    return 1000
        case .snowflake:     return 600
        case .rubberBand:    return 900
        case .zenGarden:     return 1200
        case .chaos:         return 2000
        }
    }
    var linkStrength: Float {
        switch self {
        case .observatory:   return 0
        case .nebula:        return 0
        case .crystal:       return 0
        case .fluid:         return 0
        case .constellation: return 0
        case .deepSea:       return 0
        case .solarSystem:   return 0.3
        case .windTunnel:    return 0
        case .snowflake:     return 0.8
        case .rubberBand:    return 1.1
        case .zenGarden:     return 0
        case .chaos:         return 0
        }
    }

    var velocityDecay: Float {
        switch self {
        case .observatory:   return 0.6
        case .nebula:        return 0.10
        case .crystal:       return 0.90
        case .fluid:         return 0.20
        case .constellation: return 0.08
        case .deepSea:       return 0.50
        case .solarSystem:   return 0.08
        case .windTunnel:    return 0.05
        case .snowflake:     return 0.85
        case .rubberBand:    return 0.10
        case .zenGarden:     return 0.15
        case .chaos:         return 0.05
        }
    }
    var centerStrength: Float {
        switch self {
        case .observatory:   return 0.03
        case .nebula:        return 0.005
        case .crystal:       return 0.03
        case .fluid:         return 0.008
        case .constellation: return 0.002
        case .deepSea:       return 0.005
        case .solarSystem:   return 0.003
        case .windTunnel:    return 0.002
        case .snowflake:     return 0.015
        case .rubberBand:    return 0.005
        case .zenGarden:     return 0.001
        case .chaos:         return 0.001
        }
    }
    var collisionRadius: Float {
        switch self {
        case .observatory:   return 26
        case .nebula:        return 40
        case .crystal:       return 30
        case .fluid:         return 45
        case .constellation: return 35
        case .deepSea:       return 50
        case .solarSystem:   return 40
        case .windTunnel:    return 30
        case .snowflake:     return 25
        case .rubberBand:    return 45
        case .zenGarden:     return 60
        case .chaos:         return 20
        }
    }

    // MARK: - Laboratory Overrides

    /// Lab params that differ from defaults. nil = use the baseline preset default.
    struct LabOverrides {
        var enableFluid: Bool?
        var enableTorsion: Bool?
        var enableElastic: Bool?
        var fluidViscosity: Float?
        var edgeElasticity: Float?
        var torsionRigidity: Float?
        var boidsCohesion: Float?
        var windX: Float?
        var windY: Float?
        var enableOrbital: Bool?
        var orbitalSpeed: Float?
    }

    var labOverrides: LabOverrides {
        switch self {
        case .observatory:
            return LabOverrides(enableFluid: true, enableTorsion: true, enableElastic: true,
                              windX: 0, windY: 0, enableOrbital: false)
        case .deepSea:
            return LabOverrides(enableFluid: true, enableElastic: true,
                              fluidViscosity: 0.9, edgeElasticity: 0.7, windX: 0, windY: 0)
        case .solarSystem:
            return LabOverrides(enableTorsion: false, windX: 0, windY: 0,
                              enableOrbital: true, orbitalSpeed: 0.6)
        case .windTunnel:
            return LabOverrides(enableFluid: true, fluidViscosity: 0.2, windX: 30, windY: 5)
        case .snowflake:
            return LabOverrides(enableTorsion: true, enableElastic: false,
                              torsionRigidity: 1.0, windX: 0, windY: 0)
        case .rubberBand:
            return LabOverrides(windX: 0, windY: 0)
        case .zenGarden:
            return LabOverrides(enableFluid: false, enableTorsion: false, enableElastic: false,
                              windX: 0, windY: 0, enableOrbital: false)
        case .chaos:
            return LabOverrides(enableFluid: true, enableTorsion: true, enableElastic: true,
                              fluidViscosity: 0.1, edgeElasticity: 0.9,
                              torsionRigidity: 0.8, windX: 20, windY: -15,
                              enableOrbital: true, orbitalSpeed: 0.8)
        default:
            return LabOverrides()
        }
    }
}

// MARK: - GraphInteractionMode
// Tracks whether the user is idle or mid-connection-drag in the graph canvas.

enum GraphInteractionMode: Equatable {
    case idle
    case connecting(sourceNodeId: String)
}

// MARK: - Label Font Family

enum LabelFontFamily: String, CaseIterable, Identifiable, Codable {
    case retro
    var id: String { rawValue }
    var displayName: String { "Retro" }
    var atlasResourceName: String { "sdf_labels" }
}

// MARK: - Graph Title Mode

enum GraphTitleMode: String, Codable, CaseIterable, Identifiable {
    case off, firstOpen, everyOpen
    var id: String { rawValue }
    var displayName: String {
        switch self { case .off: return "Off"; case .firstOpen: return "First open"; case .everyOpen: return "Every open" }
    }
}

// MARK: - Graph Startup View Mode

/// Which graph view opens when the user presses Cmd+G.
enum GraphStartupViewMode: String, Codable, CaseIterable, Identifiable {
    case fullOverlay  // full-screen hologram overlay
    case minimized    // small floating mini-graph panel

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullOverlay: return "Full Overlay"
        case .minimized:   return "Minimized"
        }
    }
}

// MARK: - Physics Scheduler Types

enum PhysicsSchedulerMode: String, Codable {
    case simple   // classic 2-stage: opening → delay → resting
    case timeline // sequence of N steps, each with its own delay + preset
}

struct PhysicsScheduleStep: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var delaySeconds: Double    // relative delay from previous step
    var presetKey: String       // built-in preset rawValue or "custom:<UUID>"
}

// MARK: - Custom Physics Preset Snapshot

/// Full snapshot of every user-editable physics setting — saved as a named custom preset.
/// Version-independent persistence (kept across physicsVersion bumps).
struct CustomPhysicsPresetSnapshot: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date

    // Core 7
    var linkDistance: Float
    var chargeStrength: Float
    var chargeRange: Float
    var linkStrength: Float
    var velocityDecay: Float
    var centerStrength: Float
    var collisionRadius: Float

    // Clustering + semantics
    var clusterStrength: Float
    var semanticStrength: Float
    var centerMode: UInt8
    var useSemanticClustering: Bool
    var disableClusteringAndSemantics: Bool
    var savedClusterStrength: Float
    var savedSemanticStrength: Float

    // Laboratory (11)
    var enableFluidDynamics: Bool
    var enableTorsionalSprings: Bool
    var enableElasticEdges: Bool
    var fluidViscosity: Float
    var edgeElasticity: Float
    var torsionRigidity: Float
    var boidsCohesion: Float
    var windX: Float
    var windY: Float
    var enableOrbital: Bool
    var orbitalSpeed: Float

    // Scheduler
    var schedulerMode: PhysicsSchedulerMode
    var simpleOpeningPresetKey: String
    var simpleOpeningDelaySeconds: Double
    var simpleRestingPresetKey: String
    var timelineSteps: [PhysicsScheduleStep]
    var interactionMotionHoldSeconds: Double
    var interactionMotionAlphaTarget: Float
    // Optional for forward compat: older snapshots won't have this field.
    var startupViewMode: GraphStartupViewMode?
}

// MARK: - Graph Vault Mode

/// Multi-tenant vault mode for the knowledge graph.
/// Switches between the user's human vault and the agent's internal memory vault.
enum GraphVaultMode: String, CaseIterable, Sendable {
    /// Human vault — the user's notes, folders, chats, ideas, and tags.
    case humanVault
    /// Agent vault — the model's internal live execution memory nodes.
    case agentVault
}

// MARK: - GraphState
// Observable coordinator that owns the graph engine components (store, filter).
// Physics and rendering are handled by the Rust engine via Metal.
// Injected into the environment for the hologram overlay and its subviews.

@MainActor @Observable
final class GraphState {
    let store = GraphStore()
    let filter = FilterEngine()

    /// Current vault mode — determines which nodes are visible in the Hologram.
    /// `.humanVault` shows the user's notes; `.agentVault` shows agent-generated
    /// live execution-memory nodes without re-enabling disabled source/quote types.
    var vaultMode: GraphVaultMode = .humanVault

    // MARK: - Local Workspace Routing (Phase 7)
    //
    // The graph workspace uses a Finder-style navigation history: `routeHistory`
    // records every route the user has visited, and `routeCursor` indexes the
    // currently-displayed one. Pushing a new route truncates any forward history
    // past the cursor (browser semantics). `goBack` / `goForward` move the
    // cursor without mutating the history. A `.graphRouteDidChange` notification
    // is posted on every mutation so non-SwiftUI observers (HologramOverlay) can
    // toggle hit-testing on the page-host NSHostingView.

    private(set) var routeHistory: [GraphWorkspaceRoute] = [.canvas]
    private(set) var routeCursor: Int = 0

    /// The route currently displayed by the graph workspace.
    var currentRoute: GraphWorkspaceRoute {
        routeHistory[routeCursor]
    }

    var canGoBack: Bool { routeCursor > 0 }
    var canGoForward: Bool { routeCursor < routeHistory.count - 1 }

    /// Called when a node is requested to be opened (e.g. via double tap or context menu).
    func openNode(_ id: String) {
        guard let node = store.nodes[id] else { return }

        // GraphBuilder sets `sourceId` to the backing SwiftData entity id
        // (SDPage.id for notes, SDFolder.id for folders). Fall back to the
        // graph node id only when no sourceId is recorded.
        let resolvedId: String
        if let sid = node.sourceId, !sid.isEmpty {
            resolvedId = sid
        } else {
            resolvedId = id
        }

        switch node.type {
        case .note:
            openNote(resolvedId)
        case .folder:
            openFolder(resolvedId)
        default:
            selectNode(id)
        }
    }

    func openNote(_ sourceId: String) {
        pushRoute(.note(id: sourceId))
    }

    func openFolder(_ id: String) {
        pushRoute(.folder(id: id))
    }

    func returnToCanvas() {
        pushRoute(.canvas)
    }

    func goBack() {
        guard canGoBack else { return }
        routeCursor -= 1
        NotificationCenter.default.post(name: .graphRouteDidChange, object: self)
    }

    func goForward() {
        guard canGoForward else { return }
        routeCursor += 1
        NotificationCenter.default.post(name: .graphRouteDidChange, object: self)
    }

    private func pushRoute(_ route: GraphWorkspaceRoute) {
        if routeHistory[routeCursor] == route { return }
        if routeCursor < routeHistory.count - 1 {
            routeHistory.removeSubrange((routeCursor + 1)...)
        }
        routeHistory.append(route)
        routeCursor = routeHistory.count - 1
        NotificationCenter.default.post(name: .graphRouteDidChange, object: self)
    }

    /// Constructs a `GraphChatRequest` describing the user's "Ask Graph Chat"
    /// intent and posts it on `.graphChatRequested`. This is an intent event,
    /// not a second chat session — receivers (Agent Command Center, a future
    /// GraphChatState) open their own UI and prefill from the payload.
    /// Returns the dispatched request so call sites can inspect it in tests.
    @discardableResult
    func askGraphChat(nodeId: String) -> GraphChatRequest? {
        guard let node = store.nodes[nodeId] else { return nil }
        let request = GraphChatRequest(
            graphNodeId: node.id,
            sourceId: node.sourceId,
            nodeType: node.type.rawValue,
            nodeLabel: node.label,
            route: currentRoute
        )
        NotificationCenter.default.post(
            name: .graphChatRequested,
            object: self,
            userInfo: [GraphChatRequest.userInfoKey: request]
        )
        return request
    }

    private static let visualThemeDefaultsKey = "graphVisualTheme"
    private static let visualThemeMigrationDefaultsKey =
        "epistemos.graph.visualTheme.migratedClassicDefault"

    private static func persistVisualThemeMigration(
        _ theme: GraphVisualTheme,
        defaults: UserDefaults
    ) {
        defaults.set(Int(theme.rawValue), forKey: visualThemeDefaultsKey)
        defaults.set(true, forKey: visualThemeMigrationDefaultsKey)
    }

    private static func restoredVisualTheme(defaults: UserDefaults = .standard) -> GraphVisualTheme {
        guard let storedValue = defaults.object(forKey: visualThemeDefaultsKey) as? NSNumber else {
            return .classic
        }
        let rawValue = storedValue.intValue
        guard (0...Int(UInt8.max)).contains(rawValue) else {
            persistVisualThemeMigration(.classic, defaults: defaults)
            return .classic
        }
        let migrated = defaults.bool(forKey: visualThemeMigrationDefaultsKey)
        if !migrated && rawValue == Int(GraphVisualTheme.dialogue.rawValue) {
            persistVisualThemeMigration(.classic, defaults: defaults)
            return .classic
        }
        guard let theme = GraphVisualTheme(rawValue: UInt8(rawValue)) else {
            persistVisualThemeMigration(.classic, defaults: defaults)
            return .classic
        }
        defaults.set(true, forKey: visualThemeMigrationDefaultsKey)
        return theme
    }

    nonisolated private let engineHandleState = EngineHandleState()
    /// Rust engine handle set by MetalGraphNSView after engine creation.
    /// Used for Rust-side search and other FFI calls from Swift.
    /// Backed by a tiny lock so teardown can nil it synchronously before engine destruction.
    nonisolated var engineHandle: OpaquePointer? {
        get { engineHandleState.load() }
        set { engineHandleState.store(newValue) }
    }
    private var loadedPreparedRetrievalIndexEngine: OpaquePointer?
    private var loadedPreparedRetrievalIndexManifestPath: String?

    /// True when physics is completely disabled (graph > threshold visible nodes).
    /// Updated after each commit/refresh cycle. UI uses this to grey out physics controls.
    var isStaticLayout: Bool = false

    /// The threshold above which physics is disabled. Shown in the UI tooltip.
    static let staticLayoutThreshold = 9000

    /// User-controlled physics freeze (persisted across launches).
    var isPhysicsFrozen: Bool = false
    /// Change tracker so MetalGraphView render loop can detect toggle.
    var physicsFrozenVersion: Int = 0

    /// Embedding service for semantic similarity (NLEmbedding → Rust SIMD).
    let embeddingService: EmbeddingService
    var preparedRetrievalRuntimeConfiguration: PreparedRetrievalRuntimeConfiguration? {
        embeddingService.preparedRetrievalRuntimeConfiguration
    }
    var preparedRetrievalExecutionMode: PreparedRetrievalExecutionMode {
        embeddingService.preparedRetrievalExecutionMode
    }
    var semanticClusteringAvailable: Bool {
        preparedRetrievalExecutionMode.usesSwiftEmbeddingFallback
    }
    private var isRestoringPhysicsSettings = false
    private var overlayPhysicsTask: Task<Void, Never>?

    init() {
        let svc = EmbeddingService()
        self.embeddingService = svc
        svc.graphState = self
        // Load custom presets FIRST (outside version gate) so they survive
        // any core-physics-settings reset triggered by a physicsVersion bump.
        loadCustomPresetsFromDefaults()
        restorePhysicsSettings()
        restoreLabelPolicy()
    }

    func applyPreparedRetrievalRuntimeConfiguration(_ configuration: PreparedRetrievalRuntimeConfiguration?) {
        embeddingService.applyPreparedRetrievalRuntimeConfiguration(configuration)
        loadedPreparedRetrievalIndexEngine = nil
        loadedPreparedRetrievalIndexManifestPath = nil
        guard !semanticClusteringAvailable else { return }
        if useSemanticClustering {
            useSemanticClustering = false
        }
        if !semanticClusterIds.isEmpty {
            semanticClusterIds.removeAll(keepingCapacity: true)
            semanticClusterVersion += 1
        }
    }

    func incomingEdges(forPageId pageId: String) async -> [(sourcePageId: String, sourceTitle: String, edgeType: String)] {
        let semanticEdgeTypes: Set<GraphEdgeType> = [.supports, .contradicts, .expands, .questions]
        let targetNodeIDs = Set(
            store.nodes.values.compactMap { node in
                node.sourceId == pageId ? node.id : nil
            }
        )
        guard !targetNodeIDs.isEmpty else { return [] }

        var seen = Set<String>()
        var results: [(sourcePageId: String, sourceTitle: String, edgeType: String)] = []

        for targetNodeID in targetNodeIDs {
            for edge in store.edges(for: targetNodeID) {
                guard semanticEdgeTypes.contains(edge.type) else { continue }
                guard edge.targetNodeId == targetNodeID else { continue }
                guard let sourceNode = store.nodes[edge.sourceNodeId],
                      let sourcePageId = sourceNode.sourceId,
                      sourcePageId != pageId else {
                    continue
                }

                let dedupeKey = "\(sourcePageId)|\(edge.type.rawValue)"
                guard seen.insert(dedupeKey).inserted else { continue }
                results.append(
                    (
                        sourcePageId: sourcePageId,
                        sourceTitle: sourceNode.label,
                        edgeType: edge.type.rawValue
                    )
                )
            }
        }

        results.sort { lhs, rhs in
            let titleOrder = lhs.sourceTitle.localizedCaseInsensitiveCompare(rhs.sourceTitle)
            if titleOrder == .orderedSame {
                return lhs.edgeType < rhs.edgeType
            }
            return titleOrder == .orderedAscending
        }
        return results
    }

    var isLoaded = false
    var isWarmed = false
    /// True after the entrance animation has played once. Prevents replay on re-open.
    var hasPlayedEntrance = false
    var isScanning = false
    var scanProgress: Double = 0  // 0.0-1.0
    var scanStatus: String = ""
    var selectedNodeId: String?
    /// When true, the inspector should switch to editor mode on the next selection update.
    var requestEditorMode = false

    // MARK: - Node Pinning

    /// Set of node IDs pinned at their current positions via d3-style fx/fy constraint.
    var pinnedNodeIds: Set<String> = []

    /// Pin a node at its current position. Uses Rust engine's fix_node.
    func pinNode(_ nodeId: String) {
        pinnedNodeIds.insert(nodeId)
        guard let engine = engineHandle else { return }
        nodeId.withCString { graph_engine_pin_node(engine, $0) }
    }

    /// Unpin a node, releasing its position constraint.
    func unpinNode(_ nodeId: String) {
        pinnedNodeIds.remove(nodeId)
        guard let engine = engineHandle else { return }
        nodeId.withCString { graph_engine_unpin_node(engine, $0) }
    }

    /// Pin all nodes in the graph at their current positions.
    func freezeAllNodes() {
        for nodeId in store.nodes.keys {
            pinNode(nodeId)
        }
    }

    /// Unpin all pinned nodes.
    func unfreezeAllNodes() {
        let pinned = pinnedNodeIds
        for nodeId in pinned {
            unpinNode(nodeId)
        }
    }

    /// Restore pinned nodes after engine reload (e.g. workspace restore).
    func restorePinnedNodes(_ nodeIds: Set<String>) {
        for nodeId in nodeIds {
            pinNode(nodeId)
        }
    }
    /// Screen-space position of the selected node (in points, origin top-left).
    /// Updated each render frame by MetalGraphNSView so the inspector can track the node.
    var selectedNodeScreenPoint: CGPoint?
    private var isBuildingStructural = false

    /// Set to true when notes change — the graph refreshes structural data on next appear.
    var needsRefresh = false

    // MARK: - Graph Mode

    var mode: GraphMode = .global
    var modeVersion: Int = 0

    func requestModeSync() { modeVersion += 1 }

    // MARK: - Pending Scene Actions

    /// Set to a node ID to request the Metal canvas center its camera on that node.
    var pendingCenterNodeId: String?

    /// Incremented when mode/filter changes require the Rust engine to re-commit graph data.
    /// The MetalGraphNSView render loop detects this and triggers a full re-commit.
    var graphDataVersion: Int = 0

    func requestRecommit() { graphDataVersion += 1 }

    /// One-shot startup/deferred-refresh hint: the next global recommit should snap the
    /// camera immediately instead of animating from stale bounds.
    var shouldSnapNextGlobalRecommitCamera = false

    // MARK: - Incremental FFI Updates

    /// Nodes added since the last engine commit. MetalGraphView drains these
    /// with individual `graph_engine_add_node` calls instead of a full recommit.
    var pendingNodeAdds: [GraphNodeRecord] = []

    /// Edges added since the last engine commit.
    var pendingEdgeAdds: [GraphEdgeRecord] = []

    /// Queue a single node for incremental FFI commit (avoids O(N) full recommit).
    func requestIncrementalAdd(node: GraphNodeRecord) {
        pendingNodeAdds.append(node)
    }

    /// Queue a single edge for incremental FFI commit.
    func requestIncrementalAddEdge(_ edge: GraphEdgeRecord) {
        pendingEdgeAdds.append(edge)
    }

    /// Node UUIDs pending removal from Rust engine.
    var pendingNodeRemovals: [String] = []

    /// Edge pairs pending removal from Rust engine (source UUID, target UUID).
    var pendingEdgeRemovals: [(String, String)] = []

    /// Queue a node for incremental FFI removal.
    func requestIncrementalRemove(nodeId: String) {
        pendingNodeRemovals.append(nodeId)
    }

    /// Queue an edge for incremental FFI removal.
    func requestIncrementalRemoveEdge(sourceId: String, targetId: String) {
        pendingEdgeRemovals.append((sourceId, targetId))
    }

    /// Incremented when filter toggles require a lightweight visibility refresh.
    /// Unlike graphDataVersion (full recommit), this only toggles node visibility in Rust.
    var filterVersion: Int = 0

    func requestFilterSync() { filterVersion += 1 }

    /// Set to true when the rebuild button is pressed while graph is visible.
    var pendingRebuild = false

    func beginGraphResetCycle() {
        startOverlayPhysicsCycle()
    }

    func requestGraphRebuild() {
        beginGraphResetCycle()
        pendingRebuild = true
    }

    // MARK: - Quality Level

    private static let performanceModeDefaultsKey = "epistemos.graph.performanceMode"

    /// Graph-only runtime render mode. Default remains the polished cinematic path.
    var performanceModeEnabled: Bool = {
        // Default to performance mode on first launch.
        if UserDefaults.standard.object(forKey: "epistemos.graph.performanceMode") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "epistemos.graph.performanceMode")
    }() {
        didSet {
            guard performanceModeEnabled != oldValue else { return }
            UserDefaults.standard.set(performanceModeEnabled, forKey: Self.performanceModeDefaultsKey)
            liteModeVersion += 1
        }
    }

    /// Incremented when the graph render quality mode changes, so MetalGraphView can
    /// re-sync the renderer without a full recommit.
    var liteModeVersion: Int = 0

    /// Runtime quality level forwarded to Rust.
    /// 0 = cinematic default, 2 = performance mode.
    /// Forced to 2 (performance) in eco/lowPower mode regardless of user preference.
    var qualityLevel: UInt8 {
        get {
            if PowerGuard.shared.shouldDisableBackground { return 2 }
            return performanceModeEnabled ? 2 : 0
        }
        set { performanceModeEnabled = newValue >= 2 }
    }

    // MARK: - Visual Theme

    /// Dialogue vs Classic SDF renderer. Persisted via UserDefaults.
    var visualTheme: GraphVisualTheme = GraphState.restoredVisualTheme() {
        didSet {
            UserDefaults.standard.set(Int(visualTheme.rawValue), forKey: Self.visualThemeDefaultsKey)
            visualThemeVersion += 1
        }
    }
    var visualThemeVersion: Int = 0

    // MARK: - Label Policy

    var labelMaxNodes: UInt32 = 6 {
        didSet { if labelMaxNodes != oldValue { labelPolicyVersion += 1; saveLabelPolicy() } }
    }
    var labelZoomBias: Float = 0.4 {
        didSet { if labelZoomBias != oldValue { labelPolicyVersion += 1; saveLabelPolicy() } }
    }
    var labelZoomPivot: Float = 2.5 {
        didSet { if labelZoomPivot != oldValue { labelPolicyVersion += 1; saveLabelPolicy() } }
    }
    var labelFontSizePx: Float = 28.0 {
        didSet { if labelFontSizePx != oldValue { labelPolicyVersion += 1; saveLabelPolicy() } }
    }
    var labelFocusShrink: Float = 0.4 {
        didSet { if labelFocusShrink != oldValue { labelPolicyVersion += 1; saveLabelPolicy() } }
    }
    var labelFolderThreshold: Float = 1.0 {
        didSet { if labelFolderThreshold != oldValue { labelPolicyVersion += 1; saveLabelPolicy() } }
    }
    var labelNoteThreshold: Float = 1.0 {
        didSet { if labelNoteThreshold != oldValue { labelPolicyVersion += 1; saveLabelPolicy() } }
    }
    var labelChatThreshold: Float = 1.0 {
        didSet { if labelChatThreshold != oldValue { labelPolicyVersion += 1; saveLabelPolicy() } }
    }
    var labelInnerOffset: Float = 0.6 {
        didSet { if labelInnerOffset != oldValue { labelPolicyVersion += 1; saveLabelPolicy() } }
    }
    var labelMaxInnerNodes: UInt32 = 4 {
        didSet { if labelMaxInnerNodes != oldValue { labelPolicyVersion += 1; saveLabelPolicy() } }
    }
    var labelFontFamily: LabelFontFamily = .retro {
        didSet { labelFontVersion += 1 }
    }
    var labelFontVersion: Int = 0
    var labelPolicyVersion: Int = 0

    // MARK: - Water Nodes

    var waterNodesEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(waterNodesEnabled, forKey: "epistemos.waterNodes.enabled")
            waterNodesVersion += 1
        }
    }
    var waterNodesWobble: Float = 0.0 {
        didSet {
            UserDefaults.standard.set(waterNodesWobble, forKey: "epistemos.waterNodes.wobble")
            waterNodesVersion += 1
        }
    }
    var waterNodesVersion: Int = 0

    // MARK: - Graph Title

    var graphTitleMode: GraphTitleMode = .firstOpen {
        didSet {
            UserDefaults.standard.set(graphTitleMode.rawValue, forKey: "epistemos.graph.titleMode")
        }
    }

    // MARK: - Label Policy Persistence

    private static let labelPolicyVersion = 6

    func saveLabelPolicy() {
        let d = UserDefaults.standard
        d.set(Int(labelMaxNodes), forKey: "epistemos.label.maxNodes")
        d.set(labelZoomBias, forKey: "epistemos.label.zoomBias")
        d.set(labelZoomPivot, forKey: "epistemos.label.zoomPivot")
        d.set(labelFontSizePx, forKey: "epistemos.label.fontSizePx")
        d.set(labelFocusShrink, forKey: "epistemos.label.focusShrink")
        d.set(labelFolderThreshold, forKey: "epistemos.label.folderThreshold")
        d.set(labelNoteThreshold, forKey: "epistemos.label.noteThreshold")
        d.set(labelChatThreshold, forKey: "epistemos.label.chatThreshold")
        d.set(labelInnerOffset, forKey: "epistemos.label.innerOffset")
        d.set(Int(labelMaxInnerNodes), forKey: "epistemos.label.maxInnerNodes")
        d.set(labelFontFamily.rawValue, forKey: "epistemos.label.fontFamily")
        d.set(Self.labelPolicyVersion, forKey: "epistemos.label.version")
    }

    func restoreLabelPolicy() {
        let d = UserDefaults.standard
        guard d.integer(forKey: "epistemos.label.version") == Self.labelPolicyVersion else { return }
        if d.object(forKey: "epistemos.label.maxNodes") != nil {
            labelMaxNodes = UInt32(d.integer(forKey: "epistemos.label.maxNodes"))
        }
        if d.object(forKey: "epistemos.label.zoomBias") != nil {
            labelZoomBias = d.float(forKey: "epistemos.label.zoomBias")
        }
        if d.object(forKey: "epistemos.label.zoomPivot") != nil {
            labelZoomPivot = d.float(forKey: "epistemos.label.zoomPivot")
        }
        if d.object(forKey: "epistemos.label.fontSizePx") != nil {
            labelFontSizePx = d.float(forKey: "epistemos.label.fontSizePx")
        }
        if d.object(forKey: "epistemos.label.focusShrink") != nil {
            labelFocusShrink = d.float(forKey: "epistemos.label.focusShrink")
        }
        if d.object(forKey: "epistemos.label.folderThreshold") != nil {
            labelFolderThreshold = d.float(forKey: "epistemos.label.folderThreshold")
        }
        if d.object(forKey: "epistemos.label.noteThreshold") != nil {
            labelNoteThreshold = d.float(forKey: "epistemos.label.noteThreshold")
        }
        if d.object(forKey: "epistemos.label.chatThreshold") != nil {
            labelChatThreshold = d.float(forKey: "epistemos.label.chatThreshold")
        }
        if d.object(forKey: "epistemos.label.innerOffset") != nil {
            labelInnerOffset = d.float(forKey: "epistemos.label.innerOffset")
        }
        if d.object(forKey: "epistemos.label.maxInnerNodes") != nil {
            labelMaxInnerNodes = UInt32(d.integer(forKey: "epistemos.label.maxInnerNodes"))
        }
        if let raw = d.string(forKey: "epistemos.label.fontFamily"),
           let family = LabelFontFamily(rawValue: raw) {
            labelFontFamily = family
        }
        // Restore water nodes
        if d.object(forKey: "epistemos.waterNodes.enabled") != nil {
            waterNodesEnabled = d.bool(forKey: "epistemos.waterNodes.enabled")
        }
        if d.object(forKey: "epistemos.waterNodes.wobble") != nil {
            waterNodesWobble = d.float(forKey: "epistemos.waterNodes.wobble")
        }
        // Restore graph title mode
        if let raw = d.string(forKey: "epistemos.graph.titleMode"),
           let mode = GraphTitleMode(rawValue: raw) {
            graphTitleMode = mode
        }
    }

    // MARK: - Force Parameters
    // Core 4 params (basic panel) + 5 extended params (advanced panel).
    // The Rust engine receives core via graph_engine_set_force_params(),
    // extended via graph_engine_set_extended_force_params().

    // ── Core ──
    // Tuned for dense knowledge-graph layout.
    /// Natural resting length of edge springs.
    var linkDistance: Float = 80.0
    /// Many-body charge strength (negative = repulsion).
    var chargeStrength: Float = -300.0
    /// Maximum range for many-body repulsion.
    var chargeRange: Float = 400.0
    /// Link spring strength. 0 = auto (d3: 1 / min(degree)).
    var linkStrength: Float = 0.0

    // ── Extended ──
    /// Velocity retain multiplier (d3: 0.6 = retain 60% per tick).
    var velocityDecay: Float = 0.6
    /// Center gravity pull strength.
    var centerStrength: Float = 0.03
    /// Collision buffer zone in pixels. Logseq: 26.
    var collisionRadius: Float = 26.0
    private(set) var selectedPhysicsPreset: PhysicsPreset?

    /// Incremented whenever a force slider changes, so the Metal view can detect it.
    var forceConfigVersion: Int = 0
    /// Incremented for extended params independently.
    var extendedForceConfigVersion: Int = 0

    func pushForceChange() {
        selectedPhysicsPreset = nil
        forceConfigVersion += 1
        savePhysicsSettings()
    }

    func pushExtendedForceChange() {
        selectedPhysicsPreset = nil
        extendedForceConfigVersion += 1
        savePhysicsSettings()
    }

    // ── Laboratory (advanced physics toggles + knobs) ──
    var enableFluidDynamics: Bool = false
    var enableTorsionalSprings: Bool = false
    var enableElasticEdges: Bool = true
    var fluidViscosity: Float = 0.5
    var edgeElasticity: Float = 0.5
    var torsionRigidity: Float = 0.5
    var boidsCohesion: Float = 0.0
    var windX: Float = 0.0
    var windY: Float = 0.0
    var enableOrbital: Bool = false
    var orbitalSpeed: Float = 0.3

    var labConfigVersion: Int = 0

    func pushLabChange() {
        selectedPhysicsPreset = nil
        labConfigVersion += 1
        savePhysicsSettings()
    }

    // MARK: - Physics Persistence

    /// Save all force parameters to UserDefaults so they survive app restarts.
    func savePhysicsSettings() {
        let d = UserDefaults.standard
        d.set(linkDistance, forKey: "epistemos.physics.linkDistance")
        d.set(chargeStrength, forKey: "epistemos.physics.chargeStrength")
        d.set(chargeRange, forKey: "epistemos.physics.chargeRange")
        d.set(linkStrength, forKey: "epistemos.physics.linkStrength")
        d.set(velocityDecay, forKey: "epistemos.physics.velocityDecay")
        d.set(centerStrength, forKey: "epistemos.physics.centerStrength")
        d.set(collisionRadius, forKey: "epistemos.physics.collisionRadius")
        d.set(clusterStrength, forKey: "epistemos.physics.clusterStrength")
        d.set(Int(centerMode), forKey: "epistemos.physics.centerMode")
        d.set(semanticStrength, forKey: "epistemos.physics.semanticStrength")
        d.set(useSemanticClustering, forKey: "epistemos.physics.useSemanticClustering")
        d.set(isPhysicsFrozen, forKey: "epistemos.physics.userFrozen")
        d.set(enableFluidDynamics, forKey: "epistemos.physics.enableFluid")
        d.set(enableTorsionalSprings, forKey: "epistemos.physics.enableTorsion")
        d.set(enableElasticEdges, forKey: "epistemos.physics.enableElastic")
        d.set(fluidViscosity, forKey: "epistemos.physics.fluidViscosity")
        d.set(edgeElasticity, forKey: "epistemos.physics.edgeElasticity")
        d.set(torsionRigidity, forKey: "epistemos.physics.torsionRigidity")
        d.set(boidsCohesion, forKey: "epistemos.physics.boidsCohesion")
        d.set(windX, forKey: "epistemos.physics.windX")
        d.set(windY, forKey: "epistemos.physics.windY")
        d.set(enableOrbital, forKey: "epistemos.physics.enableOrbital")
        d.set(orbitalSpeed, forKey: "epistemos.physics.orbitalSpeed")
        // Master toggle + saved strengths
        d.set(disableClusteringAndSemantics, forKey: "epistemos.physics.disableClusteringAndSemantics")
        d.set(savedClusterStrength, forKey: "epistemos.physics.savedClusterStrength")
        d.set(savedSemanticStrength, forKey: "epistemos.physics.savedSemanticStrength")
        // Scheduler
        d.set(schedulerMode.rawValue, forKey: "epistemos.physics.schedulerMode")
        d.set(simpleOpeningPresetKey, forKey: "epistemos.physics.simpleOpeningPresetKey")
        d.set(simpleOpeningDelaySeconds, forKey: "epistemos.physics.simpleOpeningDelaySeconds")
        d.set(simpleRestingPresetKey, forKey: "epistemos.physics.simpleRestingPresetKey")
        d.set(interactionMotionHoldSeconds, forKey: "epistemos.physics.interactionMotionHoldSeconds")
        d.set(interactionMotionAlphaTarget, forKey: "epistemos.physics.interactionMotionAlphaTarget")
        d.set(startupViewMode.rawValue, forKey: "epistemos.physics.startupViewMode")
        // Timeline steps as JSON
        if let stepsData = try? JSONEncoder().encode(timelineSteps) {
            d.set(stepsData, forKey: "epistemos.physics.timelineSteps")
        }
        if let selectedPhysicsPreset {
            d.set(selectedPhysicsPreset.rawValue, forKey: "epistemos.physics.selectedPreset")
        } else {
            d.removeObject(forKey: "epistemos.physics.selectedPreset")
        }
        d.set(true, forKey: "epistemos.physics.hasSavedSettings")
        d.set(Self.physicsVersion, forKey: "epistemos.physics.version")
    }

    /// Restore force parameters from UserDefaults. No-op if never saved.
    /// Uses a version key to force reset when defaults change across app updates.
    private static let physicsVersion = 11  // Bump: added master clustering toggle + scheduler
    private func restorePhysicsSettings() {
        let d = UserDefaults.standard
        guard d.bool(forKey: "epistemos.physics.hasSavedSettings") else { return }
        // Force reset if stored version doesn't match current defaults.
        if d.integer(forKey: "epistemos.physics.version") != Self.physicsVersion {
            d.removeObject(forKey: "epistemos.physics.hasSavedSettings")
            d.set(Self.physicsVersion, forKey: "epistemos.physics.version")
            return  // Use hardcoded defaults instead
        }
        isRestoringPhysicsSettings = true
        defer { isRestoringPhysicsSettings = false }
        linkDistance = d.float(forKey: "epistemos.physics.linkDistance")
        chargeStrength = d.float(forKey: "epistemos.physics.chargeStrength")
        chargeRange = d.float(forKey: "epistemos.physics.chargeRange")
        linkStrength = d.float(forKey: "epistemos.physics.linkStrength")
        velocityDecay = d.float(forKey: "epistemos.physics.velocityDecay")
        centerStrength = d.float(forKey: "epistemos.physics.centerStrength")
        collisionRadius = d.float(forKey: "epistemos.physics.collisionRadius")
        clusterStrength = d.float(forKey: "epistemos.physics.clusterStrength")
        centerMode = UInt8(d.integer(forKey: "epistemos.physics.centerMode"))
        semanticStrength = d.float(forKey: "epistemos.physics.semanticStrength")
        useSemanticClustering = d.bool(forKey: "epistemos.physics.useSemanticClustering")
        isPhysicsFrozen = d.bool(forKey: "epistemos.physics.userFrozen")
        // Lab params: only restore if key exists (otherwise keep defaults = true/0.5).
        if d.object(forKey: "epistemos.physics.enableFluid") != nil {
            enableFluidDynamics = d.bool(forKey: "epistemos.physics.enableFluid")
            enableTorsionalSprings = d.bool(forKey: "epistemos.physics.enableTorsion")
            enableElasticEdges = d.bool(forKey: "epistemos.physics.enableElastic")
            fluidViscosity = d.float(forKey: "epistemos.physics.fluidViscosity")
            edgeElasticity = d.float(forKey: "epistemos.physics.edgeElasticity")
            torsionRigidity = d.float(forKey: "epistemos.physics.torsionRigidity")
            boidsCohesion = d.float(forKey: "epistemos.physics.boidsCohesion")
            windX = d.float(forKey: "epistemos.physics.windX")
            windY = d.float(forKey: "epistemos.physics.windY")
            enableOrbital = d.bool(forKey: "epistemos.physics.enableOrbital")
            orbitalSpeed = d.float(forKey: "epistemos.physics.orbitalSpeed")
        }
        if let raw = d.string(forKey: "epistemos.physics.selectedPreset") {
            selectedPhysicsPreset = PhysicsPreset(rawValue: raw)
        } else {
            selectedPhysicsPreset = nil
        }
        // Master toggle + saved strengths
        if d.object(forKey: "epistemos.physics.savedClusterStrength") != nil {
            savedClusterStrength = d.float(forKey: "epistemos.physics.savedClusterStrength")
            savedSemanticStrength = d.float(forKey: "epistemos.physics.savedSemanticStrength")
            disableClusteringAndSemantics = d.bool(forKey: "epistemos.physics.disableClusteringAndSemantics")
        }
        // Scheduler
        if let modeRaw = d.string(forKey: "epistemos.physics.schedulerMode"),
           let mode = PhysicsSchedulerMode(rawValue: modeRaw) {
            schedulerMode = mode
        }
        if let key = d.string(forKey: "epistemos.physics.simpleOpeningPresetKey") {
            simpleOpeningPresetKey = key
        }
        if d.object(forKey: "epistemos.physics.simpleOpeningDelaySeconds") != nil {
            simpleOpeningDelaySeconds = d.double(forKey: "epistemos.physics.simpleOpeningDelaySeconds")
        }
        if let key = d.string(forKey: "epistemos.physics.simpleRestingPresetKey") {
            simpleRestingPresetKey = key
        }
        if d.object(forKey: "epistemos.physics.interactionMotionHoldSeconds") != nil {
            interactionMotionHoldSeconds = d.double(forKey: "epistemos.physics.interactionMotionHoldSeconds")
        }
        if d.object(forKey: "epistemos.physics.interactionMotionAlphaTarget") != nil {
            interactionMotionAlphaTarget = d.float(forKey: "epistemos.physics.interactionMotionAlphaTarget")
        }
        if let raw = d.string(forKey: "epistemos.physics.startupViewMode"),
           let mode = GraphStartupViewMode(rawValue: raw) {
            startupViewMode = mode
        }
        if let stepsData = d.data(forKey: "epistemos.physics.timelineSteps"),
           let steps = try? JSONDecoder().decode([PhysicsScheduleStep].self, from: stepsData) {
            timelineSteps = steps
        }
        if isPhysicsFrozen { physicsFrozenVersion += 1 }
    }

    // ── Cluster ──
    var clusterStrength: Float = 0.0
    var centerMode: UInt8 = 0  // 0=attract, 1=off, 2=repel
    var semanticStrength: Float = 0.0
    var semanticForceConfigVersion: Int = 0

    var clusterConfigVersion: Int = 0
    func pushClusterChange() {
        selectedPhysicsPreset = nil
        // If user manually dragged the slider while the master toggle was ON,
        // auto-flip the toggle OFF for consistency (toggle ON means "forced 0").
        if disableClusteringAndSemantics && clusterStrength > 0.001 {
            isRestoringPhysicsSettings = true  // prevent the toggle's didSet from zeroing us out
            disableClusteringAndSemantics = false
            isRestoringPhysicsSettings = false
        }
        clusterConfigVersion += 1
        savePhysicsSettings()
    }
    func pushSemanticChange() {
        selectedPhysicsPreset = nil
        if disableClusteringAndSemantics && semanticStrength > 0.001 {
            isRestoringPhysicsSettings = true
            disableClusteringAndSemantics = false
            isRestoringPhysicsSettings = false
        }
        semanticForceConfigVersion += 1
        savePhysicsSettings()
    }

    private func resetPresetSensitiveSettings() {
        clusterStrength = 0.0
        centerMode = 0
        semanticStrength = 0.0
        enableFluidDynamics = false
        enableTorsionalSprings = false
        enableElasticEdges = true
        fluidViscosity = 0.5
        edgeElasticity = 0.5
        torsionRigidity = 0.5
        boidsCohesion = 0.0
        windX = 0.0
        windY = 0.0
        enableOrbital = false
        orbitalSpeed = 0.3
    }

    /// Apply a named physics preset.
    func applyPreset(
        _ preset: PhysicsPreset,
        persist: Bool = true,
        applyLabOverrides: Bool = true
    ) {
        cancelOverlayPhysicsCycle()
        selectedPhysicsPreset = preset
        linkDistance = preset.linkDistance
        chargeStrength = preset.chargeStrength
        chargeRange = preset.chargeRange
        linkStrength = preset.linkStrength
        velocityDecay = preset.velocityDecay
        centerStrength = preset.centerStrength
        collisionRadius = preset.collisionRadius

        resetPresetSensitiveSettings()

        if applyLabOverrides {
            let lab = preset.labOverrides
            if let v = lab.enableFluid    { enableFluidDynamics = v }
            if let v = lab.enableTorsion  { enableTorsionalSprings = v }
            if let v = lab.enableElastic  { enableElasticEdges = v }
            if let v = lab.fluidViscosity { fluidViscosity = v }
            if let v = lab.edgeElasticity { edgeElasticity = v }
            if let v = lab.torsionRigidity { torsionRigidity = v }
            if let v = lab.boidsCohesion  { boidsCohesion = v }
            if let v = lab.windX          { windX = v }
            if let v = lab.windY          { windY = v }
            if let v = lab.enableOrbital  { enableOrbital = v }
            if let v = lab.orbitalSpeed   { orbitalSpeed = v }
        }

        forceConfigVersion += 1
        extendedForceConfigVersion += 1
        clusterConfigVersion += 1
        semanticForceConfigVersion += 1
        labConfigVersion += 1
        if persist {
            savePhysicsSettings()
        }
    }

    private func applyOverlayPreset(_ preset: PhysicsPreset) {
        applyPreset(preset, persist: false, applyLabOverrides: false)
    }

    /// Apply a scheduler step non-persistently, resolving its presetKey to a preset.
    /// Built-in keys match `PhysicsPreset.rawValue` (case-insensitive kebab/camel attempt).
    /// Custom keys are "custom:<UUID>" and look up into `customPhysicsPresets`.
    private func applyOverlayPresetByKey(_ key: String) {
        if key.hasPrefix("custom:") {
            let uuidStr = String(key.dropFirst("custom:".count))
            if let uuid = UUID(uuidString: uuidStr),
               let custom = customPhysicsPresets.first(where: { $0.id == uuid }) {
                // Custom presets are applied by copying their core physics fields only during
                // the overlay cycle (not persisted, no lab override). We reuse applyOverlayPreset
                // by constructing a hypothetical PhysicsPreset-like application.
                applyCustomPresetAsOverlay(custom)
                return
            }
        }
        // Try matching a built-in PhysicsPreset by rawValue or camelCase enum name.
        if let builtin = PhysicsPreset.allCases.first(where: {
            $0.rawValue == key || caseKey($0) == key
        }) {
            applyOverlayPreset(builtin)
            return
        }
        // Fallback: chaos.
        applyOverlayPreset(.chaos)
    }

    /// Apply a custom preset during the overlay cycle: copy core force params only,
    /// skip persistence, skip lab overrides (same semantics as applyOverlayPreset).
    private func applyCustomPresetAsOverlay(_ preset: CustomPhysicsPresetSnapshot) {
        selectedPhysicsPreset = nil
        linkDistance = preset.linkDistance
        chargeStrength = preset.chargeStrength
        chargeRange = preset.chargeRange
        linkStrength = preset.linkStrength
        velocityDecay = preset.velocityDecay
        centerStrength = preset.centerStrength
        collisionRadius = preset.collisionRadius
        forceConfigVersion += 1
        extendedForceConfigVersion += 1
    }

    /// Lowercase camelCase enum name for a preset (stable key format).
    /// e.g. `.deepSea` → "deepSea", `.solarSystem` → "solarSystem".
    private func caseKey(_ preset: PhysicsPreset) -> String {
        String(describing: preset)
    }

    func startOverlayPhysicsCycle() {
        cancelOverlayPhysicsCycle()
        switch schedulerMode {
        case .simple:
            runSimpleScheduler()
        case .timeline:
            runTimelineScheduler()
        }
    }

    private func runSimpleScheduler() {
        applyOverlayPresetByKey(simpleOpeningPresetKey)
        let delayNs = UInt64(max(0.0, simpleOpeningDelaySeconds) * 1_000_000_000)
        let restingKey = simpleRestingPresetKey
        overlayPhysicsTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(nanoseconds: delayNs)
            guard !Task.isCancelled else { return }
            await self?.applyOverlayPresetByKey(restingKey)
        }
    }

    private func runTimelineScheduler() {
        guard !timelineSteps.isEmpty else {
            // Empty timeline falls back to the simple opening → chaos cycle.
            runSimpleScheduler()
            return
        }
        let steps = timelineSteps
        overlayPhysicsTask = Task.detached(priority: .utility) { [weak self] in
            for step in steps {
                let delayNs = UInt64(max(0.0, step.delaySeconds) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delayNs)
                if Task.isCancelled { return }
                await self?.applyOverlayPresetByKey(step.presetKey)
            }
        }
    }

    func cancelOverlayPhysicsCycle() {
        overlayPhysicsTask?.cancel()
        overlayPhysicsTask = nil
    }

    // MARK: - Clustering + Semantics Master Toggle

    /// When true, BOTH clusterStrength and semanticStrength are forced to 0, disabling both forces.
    /// Toggling off restores the previously saved values.
    var disableClusteringAndSemantics: Bool = false {
        didSet {
            guard !isRestoringPhysicsSettings, disableClusteringAndSemantics != oldValue else { return }
            if disableClusteringAndSemantics {
                // Snapshot previous values before zeroing (only if non-zero, so we don't overwrite
                // a saved value with 0 when toggling repeatedly).
                if clusterStrength > 0.001 { savedClusterStrength = clusterStrength }
                if semanticStrength > 0.001 { savedSemanticStrength = semanticStrength }
                clusterStrength = 0.0
                semanticStrength = 0.0
            } else {
                // Restore previous values. Fallback to sensible defaults if none saved.
                clusterStrength = savedClusterStrength > 0.001 ? savedClusterStrength : 0.3
                semanticStrength = savedSemanticStrength > 0.001 ? savedSemanticStrength : 0.3
            }
            clusterConfigVersion += 1
            semanticForceConfigVersion += 1
            savePhysicsSettings()
        }
    }

    /// Snapshot of clusterStrength captured when `disableClusteringAndSemantics` was flipped ON.
    var savedClusterStrength: Float = 0.0
    /// Snapshot of semanticStrength captured when `disableClusteringAndSemantics` was flipped ON.
    var savedSemanticStrength: Float = 0.0

    // MARK: - Physics Scheduler

    /// Scheduler mode. `.simple` is the classic opening→resting 2-stage cycle.
    /// `.timeline` plays an arbitrary sequence of preset changes.
    var schedulerMode: PhysicsSchedulerMode = .simple
    /// Opening preset key (built-in name like "deepSea" or "custom:<UUID>").
    var simpleOpeningPresetKey: String = "deepSea"
    /// Delay in seconds before switching from opening → resting in simple mode.
    var simpleOpeningDelaySeconds: Double = 4.0
    /// Resting preset key.
    var simpleRestingPresetKey: String = "chaos"
    /// Timeline mode: ordered steps to play when the overlay opens.
    var timelineSteps: [PhysicsScheduleStep] = []
    /// How long user-interaction-triggered motion is sustained (seconds).
    var interactionMotionHoldSeconds: Double = 30.0
    /// Alpha target during interaction-sustained motion (0.001-0.1).
    var interactionMotionAlphaTarget: Float = 0.015
    /// Which graph view appears when the user presses Cmd+G.
    var startupViewMode: GraphStartupViewMode = .fullOverlay {
        didSet {
            if !isRestoringPhysicsSettings, startupViewMode != oldValue {
                savePhysicsSettings()
            }
        }
    }
    var schedulerConfigVersion: Int = 0

    func pushSchedulerChange() {
        schedulerConfigVersion += 1
        savePhysicsSettings()
    }

    // MARK: - Custom Physics Presets

    /// User-saved named physics configurations. Persisted as JSON under its own key,
    /// independent of the core physics version gate.
    private(set) var customPhysicsPresets: [CustomPhysicsPresetSnapshot] = []

    private static let customPresetsKey = "epistemos.physics.customPresets"
    private static let maxCustomPresets = 32

    /// Snapshot the current physics state as a new named custom preset.
    /// Returns the newly created snapshot, or nil if at the 32-preset limit.
    @discardableResult
    func saveCurrentAsCustomPreset(name: String) -> CustomPhysicsPresetSnapshot? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard customPhysicsPresets.count < Self.maxCustomPresets else { return nil }

        let snapshot = CustomPhysicsPresetSnapshot(
            id: UUID(),
            name: String(trimmed.prefix(40)),
            createdAt: Date(),
            linkDistance: linkDistance,
            chargeStrength: chargeStrength,
            chargeRange: chargeRange,
            linkStrength: linkStrength,
            velocityDecay: velocityDecay,
            centerStrength: centerStrength,
            collisionRadius: collisionRadius,
            clusterStrength: clusterStrength,
            semanticStrength: semanticStrength,
            centerMode: centerMode,
            useSemanticClustering: useSemanticClustering,
            disableClusteringAndSemantics: disableClusteringAndSemantics,
            savedClusterStrength: savedClusterStrength,
            savedSemanticStrength: savedSemanticStrength,
            enableFluidDynamics: enableFluidDynamics,
            enableTorsionalSprings: enableTorsionalSprings,
            enableElasticEdges: enableElasticEdges,
            fluidViscosity: fluidViscosity,
            edgeElasticity: edgeElasticity,
            torsionRigidity: torsionRigidity,
            boidsCohesion: boidsCohesion,
            windX: windX,
            windY: windY,
            enableOrbital: enableOrbital,
            orbitalSpeed: orbitalSpeed,
            schedulerMode: schedulerMode,
            simpleOpeningPresetKey: simpleOpeningPresetKey,
            simpleOpeningDelaySeconds: simpleOpeningDelaySeconds,
            simpleRestingPresetKey: simpleRestingPresetKey,
            timelineSteps: timelineSteps,
            interactionMotionHoldSeconds: interactionMotionHoldSeconds,
            interactionMotionAlphaTarget: interactionMotionAlphaTarget,
            startupViewMode: startupViewMode
        )
        customPhysicsPresets.insert(snapshot, at: 0)
        saveCustomPresetsToDefaults()
        return snapshot
    }

    /// Apply a saved custom preset to every matching GraphState field, then persist.
    func applyCustomPreset(_ preset: CustomPhysicsPresetSnapshot) {
        cancelOverlayPhysicsCycle()
        isRestoringPhysicsSettings = true
        defer { isRestoringPhysicsSettings = false }

        selectedPhysicsPreset = nil
        linkDistance = preset.linkDistance
        chargeStrength = preset.chargeStrength
        chargeRange = preset.chargeRange
        linkStrength = preset.linkStrength
        velocityDecay = preset.velocityDecay
        centerStrength = preset.centerStrength
        collisionRadius = preset.collisionRadius
        clusterStrength = preset.clusterStrength
        semanticStrength = preset.semanticStrength
        centerMode = preset.centerMode
        useSemanticClustering = preset.useSemanticClustering
        disableClusteringAndSemantics = preset.disableClusteringAndSemantics
        savedClusterStrength = preset.savedClusterStrength
        savedSemanticStrength = preset.savedSemanticStrength
        enableFluidDynamics = preset.enableFluidDynamics
        enableTorsionalSprings = preset.enableTorsionalSprings
        enableElasticEdges = preset.enableElasticEdges
        fluidViscosity = preset.fluidViscosity
        edgeElasticity = preset.edgeElasticity
        torsionRigidity = preset.torsionRigidity
        boidsCohesion = preset.boidsCohesion
        windX = preset.windX
        windY = preset.windY
        enableOrbital = preset.enableOrbital
        orbitalSpeed = preset.orbitalSpeed
        schedulerMode = preset.schedulerMode
        simpleOpeningPresetKey = preset.simpleOpeningPresetKey
        simpleOpeningDelaySeconds = preset.simpleOpeningDelaySeconds
        simpleRestingPresetKey = preset.simpleRestingPresetKey
        timelineSteps = preset.timelineSteps
        interactionMotionHoldSeconds = preset.interactionMotionHoldSeconds
        interactionMotionAlphaTarget = preset.interactionMotionAlphaTarget
        if let mode = preset.startupViewMode {
            startupViewMode = mode
        }

        forceConfigVersion += 1
        extendedForceConfigVersion += 1
        clusterConfigVersion += 1
        semanticForceConfigVersion += 1
        labConfigVersion += 1
        schedulerConfigVersion += 1
        savePhysicsSettings()
    }

    func deleteCustomPreset(id: UUID) {
        customPhysicsPresets.removeAll { $0.id == id }
        saveCustomPresetsToDefaults()
    }

    func renameCustomPreset(id: UUID, newName: String) {
        guard let idx = customPhysicsPresets.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        customPhysicsPresets[idx].name = String(trimmed.prefix(40))
        saveCustomPresetsToDefaults()
    }

    private func saveCustomPresetsToDefaults() {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(customPhysicsPresets)
            UserDefaults.standard.set(data, forKey: Self.customPresetsKey)
        } catch {
            NSLog("[GraphState] Failed to encode custom presets: \(error)")
        }
    }

    private func loadCustomPresetsFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: Self.customPresetsKey) else { return }
        let decoder = JSONDecoder()
        do {
            customPhysicsPresets = try decoder.decode([CustomPhysicsPresetSnapshot].self, from: data)
        } catch {
            NSLog("[GraphState] Failed to decode custom presets: \(error)")
        }
    }

    // MARK: - Semantic Clustering

    /// When true, uses NLEmbedding-based semantic clusters instead of Louvain topology clusters.
    var useSemanticClustering = false {
        didSet {
            if !isRestoringPhysicsSettings, useSemanticClustering != oldValue {
                savePhysicsSettings()
            }
        }
    }

    /// Cached semantic cluster IDs (nodeId → clusterId). Recomputed when graph data changes.
    private(set) var semanticClusterIds: [String: UInt32] = [:]

    /// Incremented when semantic cluster IDs change, so MetalGraphNSView can push them to Rust.
    var semanticClusterVersion: Int = 0

    /// Compute semantic clusters from the current graph store and cache the result.
    /// This remains a legacy Apple-fallback path only and is disabled once the
    /// prepared retrieval runtime leaves fallback mode.
    func computeSemanticClusters() {
        guard semanticClusteringAvailable else {
            semanticClusterIds.removeAll(keepingCapacity: true)
            semanticClusterVersion += 1
            return
        }
        semanticClusterIds = embeddingService.computeFallbackSemanticClusters(store: store)
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

    private var isLoadingGraph = false

    /// Load the graph from SwiftData on a background thread to avoid blocking the UI.
    /// Uses BackgroundGraphActor (@ModelActor) for Swift 6 safe background SwiftData access.
    func loadGraph(container: ModelContainer) async {
        guard !isLoaded, !isLoadingGraph else { return }
        isLoadingGraph = true
        defer { isLoadingGraph = false }
        let interval = Log.graphPerf.beginInterval("loadGraphAsync")
        defer { Log.graphPerf.endInterval("loadGraphAsync", interval) }

        let hints = store.positionHints
        let actor = BackgroundGraphActor(modelContainer: container)
        let records: (nodes: [GraphNodeRecord], edges: [GraphEdgeRecord])
        do {
            records = try await actor.loadRecords(positionHints: hints)
        } catch {
            Log.app.error("GraphState: failed to load graph: \(error.localizedDescription, privacy: .public)")
            return
        }

        store.loadFromRecords(nodeRecords: records.nodes, edgeRecords: records.edges)

        // If empty, rebuild structural data through the background actor path too.
        if store.nodeCount == 0, !isBuildingStructural {
            _ = await refreshStructuralDataAsync(container: container)
        } else {
            isLoaded = true
        }

        if isLoaded {
            requestRecommit()
        }
    }

    /// Synchronous load for callers that already have a main-thread ModelContext.
    /// Prefer the async variant for large vaults.
    func loadGraph(context: ModelContext) {
        do {
            try store.load(context: context)
        } catch {
            Log.app.error("GraphState: failed to load graph: \(error.localizedDescription, privacy: .public)")
            return
        }
        if store.nodeCount == 0, !isBuildingStructural {
            buildStructuralGraph(context: context)
            return
        }
        isLoaded = true
    }

    // MARK: - Structural Graph

    /// Build the structural graph from SwiftData entities (notes, folders, chats, tags).
    func buildStructuralGraph(context: ModelContext) {
        guard !isBuildingStructural else { return }
        isBuildingStructural = true
        defer { isBuildingStructural = false }

        let interval = Log.graphPerf.beginInterval("buildStructuralGraph")
        let builder = GraphBuilder()
        let result = builder.build(context: context)
        builder.persist(nodes: result.nodes, edges: result.edges, context: context)

        // Use loadDirect() to populate the store from the already-in-memory arrays.
        // This skips the redundant SwiftData re-fetch that store.load(context:) would do.
        store.loadDirect(nodes: result.nodes, edges: result.edges)
        isLoaded = true
        Log.graphPerf.endInterval("buildStructuralGraph", interval)
    }

    /// Lightweight refresh: re-runs the structural graph builder to pick up new/deleted pages.
    func refreshStructuralData(context: ModelContext) {
        needsRefresh = false
        buildStructuralGraph(context: context)
    }

    /// Async refresh: runs full GraphBuilder build + persist on a background actor,
    /// then loads the resulting Sendable records into the store on main.
    @discardableResult
    func refreshStructuralDataAsync(container: ModelContainer) async -> Bool {
        guard !isBuildingStructural else { return false }
        isBuildingStructural = true
        needsRefresh = false
        let interval = Log.graphPerf.beginInterval("refreshStructuralDataAsync")
        defer { Log.graphPerf.endInterval("refreshStructuralDataAsync", interval) }

        let hints = store.positionHints
        let actor = BackgroundGraphActor(modelContainer: container)
        do {
            let records = try await actor.rebuildStructural(positionHints: hints)
            if !applyIncrementalStructuralRefresh(nodeRecords: records.nodes, edgeRecords: records.edges) {
                store.loadFromRecords(nodeRecords: records.nodes, edgeRecords: records.edges)
                isLoaded = true
                isBuildingStructural = false
                return false
            }
            isLoaded = true
        } catch {
            Log.app.error("GraphState: background structural refresh failed: \(error.localizedDescription, privacy: .public)")
            isBuildingStructural = false
            return false
        }

        isBuildingStructural = false
        return true
    }

    private func applyIncrementalStructuralRefresh(
        nodeRecords: [GraphNodeRecord],
        edgeRecords: [GraphEdgeRecord]
    ) -> Bool {
        guard isLoaded, !store.nodes.isEmpty else { return false }

        let nextNodesById = Dictionary(uniqueKeysWithValues: nodeRecords.map { ($0.id, $0) })
        let nextEdgesById = Dictionary(uniqueKeysWithValues: edgeRecords.map { ($0.id, $0) })

        if structuralRefreshRequiresFullReload(
            nextNodesById: nextNodesById,
            nextEdgesById: nextEdgesById
        ) {
            return false
        }

        let currentNodeIds = Set(store.nodes.keys)
        let currentEdgeIds = Set(store.edges.keys)
        let nextNodeIds = Set(nextNodesById.keys)
        let nextEdgeIds = Set(nextEdgesById.keys)
        let removedNodeIds = currentNodeIds.subtracting(nextNodeIds)

        let removedEdgeIds = currentEdgeIds.subtracting(nextEdgeIds).filter { edgeId in
            guard let edge = store.edges[edgeId] else { return false }
            return !removedNodeIds.contains(edge.sourceNodeId) && !removedNodeIds.contains(edge.targetNodeId)
        }

        for edgeId in removedEdgeIds {
            guard let edge = store.edges[edgeId] else { continue }
            requestIncrementalRemoveEdge(sourceId: edge.sourceNodeId, targetId: edge.targetNodeId)
            store.removeEdge(edgeId)
        }

        for nodeId in removedNodeIds {
            requestIncrementalRemove(nodeId: nodeId)
            store.removeNode(nodeId)
        }

        for node in nodeRecords where !currentNodeIds.contains(node.id) {
            store.addNode(node)
            requestIncrementalAdd(node: node)
        }

        for edge in edgeRecords where !currentEdgeIds.contains(edge.id) {
            store.addEdge(edge)
            requestIncrementalAddEdge(edge)
        }

        for node in nodeRecords {
            guard let existing = store.nodes[node.id] else { continue }
            guard existing.sourceId != node.sourceId
                || existing.metadata != node.metadata
                || existing.weight != node.weight
                || existing.createdAt != node.createdAt
                || existing.updatedAt != node.updatedAt
            else {
                continue
            }
            store.updateNode(node)
            syncNodeMetadataToEngine(node)
        }

        refreshFocusedFilterIfNeeded()
        if filter.isFiltered {
            requestFilterSync()
        }
        return true
    }

    private func structuralRefreshRequiresFullReload(
        nextNodesById: [String: GraphNodeRecord],
        nextEdgesById: [String: GraphEdgeRecord]
    ) -> Bool {
        for (nodeId, existing) in store.nodes {
            guard let next = nextNodesById[nodeId] else { continue }
            if existing.type != next.type || existing.label != next.label {
                return true
            }
        }

        for (edgeId, existing) in store.edges {
            guard let next = nextEdgesById[edgeId] else { continue }
            if existing.sourceNodeId != next.sourceNodeId
                || existing.targetNodeId != next.targetNodeId
                || existing.type != next.type
                || existing.weight != next.weight
            {
                return true
            }
        }

        return false
    }

    private func refreshFocusedFilterIfNeeded() {
        guard let focusedNodeId = filter.focusedNodeId else { return }
        guard store.nodes[focusedNodeId] != nil else {
            clearFocus()
            return
        }
        let depth: Int
        if case .page = mode {
            depth = 2
        } else {
            depth = 3
        }
        focusOnNode(focusedNodeId, depth: depth)
    }

    private func syncNodeMetadataToEngine(_ node: GraphNodeRecord) {
        guard let engine = engineHandle else { return }
        let createdAt = node.createdAt.timeIntervalSince1970
        let updatedAt = node.updatedAt.timeIntervalSince1970
        let confidence: Float = switch node.metadata.evidenceGrade?.uppercased() {
        case "A": 1.0
        case "B": 0.8
        case "C": 0.6
        case "D": 0.4
        case "F": 0.2
        default: 0.0
        }
        node.id.withCString { uuidPtr in
            graph_engine_set_node_time(engine, uuidPtr, createdAt, updatedAt)
            graph_engine_set_node_confidence(engine, uuidPtr, confidence)
        }
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
                // Fall through to Swift fuzzy search if FFI returned results
                // but none mapped to store nodes (UUID mismatch after rebuild).
                if !hits.isEmpty { return hits }
            }
        }

        // Fallback to Swift-side search
        return store.fuzzySearch(query: query, limit: limit)
    }

    /// Hybrid search: combines text (Rust FST) + semantic (embedding cosine) results.
    /// Semantic-only matches get 0.7× score weight (text match is stronger signal).
    func canRunFallbackSemanticSearch() -> Bool {
        guard semanticClusteringAvailable,
              let engine = engineHandle,
              embeddingService.dimension > 0,
              graph_engine_embedding_count(engine) > 0,
              Int(graph_engine_embedding_dimension(engine)) == embeddingService.dimension else {
            return false
        }

        return true
    }

    func semanticSearch(query: String, limit: Int = 20) -> [GraphStore.SearchHit] {
        guard !query.isEmpty else { return [] }
        if let preparedHits = preparedSemanticSearch(query: query, limit: limit) {
            return preparedHits
        }
        guard canRunFallbackSemanticSearch(),
              let engine = engineHandle,
              embeddingService.dimension > 0,
              let queryVec = embeddingService.queryEmbedding(
                for: query,
                expectedDimension: embeddingService.dimension
              ) else {
            return []
        }

        return queryVec.withUnsafeBufferPointer { buf in
            guard let baseAddress = buf.baseAddress else { return [] }
            var count: UInt32 = 0
            let results = graph_engine_semantic_search(
                engine,
                baseAddress,
                UInt32(embeddingService.dimension),
                UInt32(limit),
                &count
            )
            return collectSemanticHits(
                results: results,
                count: &count,
                resolveNode: { [store] nodeID in store.nodes[nodeID] }
            )
        }
    }

    private func preparedSemanticSearch(query: String, limit: Int) -> [GraphStore.SearchHit]? {
        guard preparedRetrievalExecutionMode.hasPreparedIndexRuntime,
              ensurePreparedRetrievalIndexLoaded(),
              let engine = engineHandle else {
            return nil
        }

        let dimension = Int(graph_engine_prepared_retrieval_dimension(engine))
        guard dimension > 0,
              let queryVec = embeddingService.queryEmbedding(for: query, expectedDimension: dimension) else {
            return []
        }

        return queryVec.withUnsafeBufferPointer { buf in
            guard let baseAddress = buf.baseAddress else { return [] }
            var count: UInt32 = 0
            let results = graph_engine_prepared_retrieval_search(
                engine,
                baseAddress,
                UInt32(dimension),
                UInt32(limit),
                &count
            )
            return collectSemanticHits(
                results: results,
                count: &count,
                resolveNode: { [store] pageID in store.node(bySourceId: pageID, type: .note) }
            )
        }
    }

    private func collectSemanticHits(
        results: UnsafeMutablePointer<GraphSearchResult>?,
        count: inout UInt32,
        resolveNode: (String) -> GraphNodeRecord?
    ) -> [GraphStore.SearchHit] {
        defer { graph_engine_free_search_results(results, count) }
        guard let results, count > 0 else { return [] }

        var hits: [GraphStore.SearchHit] = []
        hits.reserveCapacity(Int(count))

        for i in 0..<Int(count) {
            let result = results[i]
            let identifier = result.uuid.map { String(cString: $0) } ?? ""
            guard let node = resolveNode(identifier) else { continue }
            hits.append(
                GraphStore.SearchHit(
                    id: node.id,
                    node: node,
                    score: result.score
                )
            )
        }

        return hits
    }

    func ensurePreparedRetrievalIndexLoaded() -> Bool {
        guard preparedRetrievalExecutionMode.hasPreparedIndexRuntime,
              let engine = engineHandle,
              let manifestPath = embeddingService.preparedRetrievalIndexManifestPath else {
            return false
        }

        if loadedPreparedRetrievalIndexEngine == engine,
           loadedPreparedRetrievalIndexManifestPath == manifestPath {
            return true
        }

        let loaded = manifestPath.withCString { graph_engine_load_prepared_retrieval_index(engine, $0) != 0 }
        if loaded {
            loadedPreparedRetrievalIndexEngine = engine
            loadedPreparedRetrievalIndexManifestPath = manifestPath
            return true
        }

        loadedPreparedRetrievalIndexEngine = nil
        loadedPreparedRetrievalIndexManifestPath = nil
        return false
    }

    func hybridSearch(query: String, limit: Int = 20) -> [GraphStore.SearchHit] {
        guard !query.isEmpty else { return [] }

        // Text search
        let textHits = rustSearch(query: query, limit: limit)
        var hitMap: [String: GraphStore.SearchHit] = [:]
        for hit in textHits {
            hitMap[hit.id] = hit
        }

        for hit in semanticSearch(query: query, limit: limit) {
            guard hitMap[hit.id] == nil else { continue }
            hitMap[hit.id] = GraphStore.SearchHit(
                id: hit.id,
                node: hit.node,
                score: hit.score * 0.7
            )
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

    /// Enable/disable bullet-time search physics (slow-motion drift during search).
    func setSearchActive(_ active: Bool) {
        guard let engine = engineHandle else { return }
        graph_engine_set_search_active(engine, active ? 1 : 0)
    }

    // MARK: - Selection

    func selectNode(_ id: String?) {
        guard selectedNodeId != id else { return }
        selectedNodeId = id
    }

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
    /// IDs of ephemeral wikilink edges (between permanent nodes, not cleaned by removeNode).
    private(set) var ephemeralEdgeIds = Set<String>()
    /// Lowercased label → note node lookup table, built once per buildPageSubgraph call.
    /// Replaces O(N) linear scan per wikilink with O(1) dictionary lookup.
    private var wikilinkLookup: [String: GraphNodeRecord] = [:]

    /// Build the page subgraph from the active note's markdown body.
    /// Wikilinks are resolved to existing graph nodes.
    func buildPageSubgraph(for pageId: String, context: ModelContext) {
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == pageId }
        )
        guard let page = try? context.fetch(descriptor).first else { return }
        guard let pageNodeId = store.node(bySourceId: pageId, type: .note)?.id else { return }

        let body = page.loadBody(mapped: true)
        guard !body.isEmpty else { return }
        guard let cStr = body.cString(using: .utf8) else { return }

        // Build wikilink lookup table once (O(N)) instead of O(N) per wikilink.
        wikilinkLookup.removeAll(keepingCapacity: true)
        for node in store.nodes.values where node.type == .note {
            wikilinkLookup[node.label.lowercased()] = node
        }

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
            createdAt: createdAt, updatedAt: createdAt, position: pos
        )
        store.addNode(node)
        requestIncrementalAdd(node: node)
        let edge = GraphEdgeRecord(
            id: "edge-\(id)", sourceNodeId: parentId, targetNodeId: id,
            type: edgeType, weight: 1.0, createdAt: createdAt
        )
        store.addEdge(edge)
        requestIncrementalAddEdge(edge)
        ephemeralNodeIds.insert(id)
    }

    /// Resolve a wikilink target to an existing note node and create an edge.
    private func resolveWikilinkEdge(target: String, from pageNodeId: String, byteOffset: Int, createdAt: Date) {
        // Use pre-built lookup table if available (built once per buildPageSubgraph call).
        guard let linkedNode = wikilinkLookup[target.lowercased()] else { return }

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
        requestIncrementalAddEdge(edge)
        ephemeralEdgeIds.insert(edgeId)
    }

    /// Remove all ephemeral nodes (and their edges) created for page mode.
    /// Enqueues FFI removals so Rust engine updates incrementally in the next render frame.
    func cleanupEphemeralNodes() {
        // Enqueue FFI removals BEFORE Swift-side store removal (which deletes edge records).
        for nodeId in ephemeralNodeIds {
            requestIncrementalRemove(nodeId: nodeId)
        }
        for edgeId in ephemeralEdgeIds {
            if let edge = store.edges[edgeId] {
                requestIncrementalRemoveEdge(sourceId: edge.sourceNodeId, targetId: edge.targetNodeId)
            }
        }

        // Swift-side cleanup
        for nodeId in ephemeralNodeIds {
            store.removeNode(nodeId)
        }
        ephemeralNodeIds.removeAll()

        for edgeId in ephemeralEdgeIds {
            store.removeEdge(edgeId)
        }
        ephemeralEdgeIds.removeAll()
        wikilinkLookup.removeAll()
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
                updatedAt: sdNode.updatedAt,
                position: position,
                velocity: .zero
            )
            store.addNode(record)
            requestIncrementalAdd(node: record)
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
                updatedAt: sdNode.updatedAt,
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
            requestIncrementalAdd(node: record)
            requestIncrementalAddEdge(edgeRecord)
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
        requestIncrementalAddEdge(edgeRecord)
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
