import Foundation
import NaturalLanguage
import SwiftData

// MARK: - UInt8 Clamped Helper

private extension UInt8 {
    func clamped(to range: ClosedRange<UInt8>, default defaultValue: UInt8) -> UInt8 {
        self == 0 ? defaultValue : Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - GraphVisualTheme

enum GraphVisualTheme: UInt8, CaseIterable, Codable {
    case pixel = 0
    case classic = 1

    var displayName: String {
        switch self {
        case .pixel:   "Pixel Blocks"
        case .classic: "Classic"
        }
    }
}

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
    case deepSea = "Deep Sea"            // Heavy viscosity, slow currents
    case solarSystem = "Solar System"    // Orbital hierarchies, wide spacing
    case windTunnel = "Wind Tunnel"      // Lateral wind, low friction
    case snowflake = "Snowflake"         // Max torsion, crystalline
    case rubberBand = "Rubber Band"      // Elastic edges, bouncy
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
        case .rubberBand:    return 0
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

    /// Lab params that differ from defaults. nil = keep current user setting.
    struct LabOverrides {
        var enableFluid: Bool?
        var enableTorsion: Bool?
        var enableElastic: Bool?
        var enableTension: Bool?
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
                              enableTension: true, windX: 0, windY: 0, enableOrbital: false)
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
            return LabOverrides(enableElastic: true, enableTension: true,
                              edgeElasticity: 1.0, windX: 0, windY: 0)
        case .zenGarden:
            return LabOverrides(enableFluid: false, enableTorsion: false, enableElastic: false,
                              windX: 0, windY: 0, enableOrbital: false)
        case .chaos:
            return LabOverrides(enableFluid: true, enableTorsion: true, enableElastic: true,
                              enableTension: true, fluidViscosity: 0.1, edgeElasticity: 0.9,
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

    init() {
        let svc = EmbeddingService()
        self.embeddingService = svc
        svc.graphState = self
        restorePhysicsSettings()
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

    // MARK: - Visual Theme

    /// Pixel art vs Classic SDF renderer. Persisted via UserDefaults.
    var visualTheme: GraphVisualTheme = {
        let raw = UserDefaults.standard.integer(forKey: "graphVisualTheme")
        guard (0...255).contains(raw) else { return .pixel }
        return GraphVisualTheme(rawValue: UInt8(raw)) ?? .pixel
    }() {
        didSet {
            UserDefaults.standard.set(Int(visualTheme.rawValue), forKey: "graphVisualTheme")
            visualThemeVersion += 1
        }
    }
    var visualThemeVersion: Int = 0

    /// Pixel art upscale factor (2-16, default 4). Persisted via UserDefaults.
    var pixelScale: UInt8 = {
        let raw = UserDefaults.standard.integer(forKey: "graphPixelScale")
        guard (0...255).contains(raw) else { return 4 }
        return UInt8(raw).clamped(to: 2...16, default: 4)
    }() {
        didSet {
            UserDefaults.standard.set(Int(pixelScale), forKey: "graphPixelScale")
            visualThemeVersion += 1
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

    /// Incremented whenever a force slider changes, so the Metal view can detect it.
    var forceConfigVersion: Int = 0
    /// Incremented for extended params independently.
    var extendedForceConfigVersion: Int = 0

    func pushForceChange() {
        forceConfigVersion += 1
        savePhysicsSettings()
    }

    func pushExtendedForceChange() {
        extendedForceConfigVersion += 1
        savePhysicsSettings()
    }

    // ── Laboratory (advanced physics toggles + knobs) ──
    var enableFluidDynamics: Bool = false
    var enableTorsionalSprings: Bool = false
    var enableElasticEdges: Bool = true
    var enableTensionColoring: Bool = true
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
        d.set(enableTensionColoring, forKey: "epistemos.physics.enableTension")
        d.set(fluidViscosity, forKey: "epistemos.physics.fluidViscosity")
        d.set(edgeElasticity, forKey: "epistemos.physics.edgeElasticity")
        d.set(torsionRigidity, forKey: "epistemos.physics.torsionRigidity")
        d.set(boidsCohesion, forKey: "epistemos.physics.boidsCohesion")
        d.set(windX, forKey: "epistemos.physics.windX")
        d.set(windY, forKey: "epistemos.physics.windY")
        d.set(enableOrbital, forKey: "epistemos.physics.enableOrbital")
        d.set(orbitalSpeed, forKey: "epistemos.physics.orbitalSpeed")
        d.set(true, forKey: "epistemos.physics.hasSavedSettings")
        d.set(Self.physicsVersion, forKey: "epistemos.physics.version")
    }

    /// Restore force parameters from UserDefaults. No-op if never saved.
    /// Uses a version key to force reset when defaults change across app updates.
    private static let physicsVersion = 10  // Bump to force reset: tighter layout (linkDist 80, charge -300, range 400)
    private func restorePhysicsSettings() {
        let d = UserDefaults.standard
        guard d.bool(forKey: "epistemos.physics.hasSavedSettings") else { return }
        // Force reset if stored version doesn't match current defaults.
        if d.integer(forKey: "epistemos.physics.version") != Self.physicsVersion {
            d.removeObject(forKey: "epistemos.physics.hasSavedSettings")
            d.set(Self.physicsVersion, forKey: "epistemos.physics.version")
            return  // Use hardcoded defaults instead
        }
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
            enableTensionColoring = d.bool(forKey: "epistemos.physics.enableTension")
            fluidViscosity = d.float(forKey: "epistemos.physics.fluidViscosity")
            edgeElasticity = d.float(forKey: "epistemos.physics.edgeElasticity")
            torsionRigidity = d.float(forKey: "epistemos.physics.torsionRigidity")
            boidsCohesion = d.float(forKey: "epistemos.physics.boidsCohesion")
            windX = d.float(forKey: "epistemos.physics.windX")
            windY = d.float(forKey: "epistemos.physics.windY")
            enableOrbital = d.bool(forKey: "epistemos.physics.enableOrbital")
            orbitalSpeed = d.float(forKey: "epistemos.physics.orbitalSpeed")
        }
        if isPhysicsFrozen { physicsFrozenVersion += 1 }
    }

    // ── Cluster ──
    var clusterStrength: Float = 0.0
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
    func pushClusterChange() { clusterConfigVersion += 1; savePhysicsSettings() }
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

        // Apply lab overrides from preset (nil = keep current value).
        let lab = preset.labOverrides
        if let v = lab.enableFluid    { enableFluidDynamics = v }
        if let v = lab.enableTorsion  { enableTorsionalSprings = v }
        if let v = lab.enableElastic  { enableElasticEdges = v }
        if let v = lab.enableTension  { enableTensionColoring = v }
        if let v = lab.fluidViscosity { fluidViscosity = v }
        if let v = lab.edgeElasticity { edgeElasticity = v }
        if let v = lab.torsionRigidity { torsionRigidity = v }
        if let v = lab.boidsCohesion  { boidsCohesion = v }
        if let v = lab.windX          { windX = v }
        if let v = lab.windY          { windY = v }
        if let v = lab.enableOrbital  { enableOrbital = v }
        if let v = lab.orbitalSpeed   { orbitalSpeed = v }

        forceConfigVersion += 1
        extendedForceConfigVersion += 1
        labConfigVersion += 1
        savePhysicsSettings()
    }

    // MARK: - Semantic Clustering

    /// When true, uses NLEmbedding-based semantic clusters instead of Louvain topology clusters.
    var useSemanticClustering = true

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

    /// Load the graph from SwiftData on a background thread to avoid blocking the UI.
    /// Uses BackgroundGraphActor (@ModelActor) for Swift 6 safe background SwiftData access.
    func loadGraph(container: ModelContainer) async {
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

        // If empty and not already building, auto-build from structural data.
        // Building stays on @MainActor since GraphBuilder uses @Model types.
        if store.nodeCount == 0, !isBuildingStructural {
            buildStructuralGraph(context: container.mainContext)
            return
        }

        isLoaded = true
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

        let builder = GraphBuilder()
        let result = builder.build(context: context)
        builder.persist(nodes: result.nodes, edges: result.edges, context: context)

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

    /// Enable/disable bullet-time search physics (slow-motion drift during search).
    func setSearchActive(_ active: Bool) {
        guard let engine = engineHandle else { return }
        graph_engine_set_search_active(engine, active ? 1 : 0)
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
    /// IDs of ephemeral wikilink edges (between permanent nodes, not cleaned by removeNode).
    private(set) var ephemeralEdgeIds = Set<String>()

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
        ephemeralEdgeIds.insert(edgeId)
    }

    /// Remove all ephemeral nodes (and their edges) created for page mode.
    func cleanupEphemeralNodes() {
        for nodeId in ephemeralNodeIds {
            store.removeNode(nodeId)
        }
        ephemeralNodeIds.removeAll()

        // Remove ephemeral wikilink edges (between permanent nodes, not cleaned by removeNode).
        for edgeId in ephemeralEdgeIds {
            store.removeEdge(edgeId)
        }
        ephemeralEdgeIds.removeAll()
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
