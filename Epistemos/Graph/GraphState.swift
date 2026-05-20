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
    /// Per user 2026-05-12 (refined): Gravity Well is the canonical
    /// default at both the opening and resting phase. The boot-default
    /// UserDefaults state additionally overrides three of Gravity Well's
    /// stock values (linkDistance → 500 max, centerStrength → 0,
    /// enableFluidDynamics → false) — see the first-launch branch in
    /// `restorePhysicsSettings()` for the override application. The
    /// previous Observatory + fluid-wake default is preserved as
    /// `legacyDefaultTimelineSignature` only as a historical reference.
    static let openingPreset: PhysicsPreset = .gravityWell
    static let restingPreset: PhysicsPreset = .gravityWell
    static let chaosDelaySeconds: TimeInterval = 4
    static let interactionMotionHoldSeconds: TimeInterval = 30
    static let interactionMotionAlphaTarget: Float = 0.015
    static let defaultGlobalCameraMagnification: Float = -0.08
    static let legacyDefaultTimelineSignature: [(Double, String)] = [
        (0.0, "crystal"),
        (3.0, "constellation"),
        (4.0, "chaos"),
    ]

    static var openingPresetKey: String { String(describing: openingPreset) }
    static var restingPresetKey: String { String(describing: restingPreset) }
    static var defaultTimelineSignature: [(Double, String)] {
        [
            (0.0, openingPresetKey),
            (chaosDelaySeconds, restingPresetKey),
        ]
    }

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

// MARK: - User-directed force overlays (V6.2 toolbar — added 2026-05-12)

/// Cursor-force overlay mode. While active, the graph engine reads the
/// live cursor position from `graph_engine_mouse_moved` and applies a
/// radial / tangential force to every node within ~2500 world units of
/// the cursor.
///
/// - `.off`: no cursor force.
/// - `.suck`: nodes accelerate toward the cursor (inverse-square pull).
/// - `.repel`: nodes accelerate away from the cursor (inverse-square push).
/// - `.vortex`: nodes orbit the cursor tangentially with a small inward
///   bias so the orbit converges into a galaxy-like swirl.
enum CursorForceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case off
    case suck
    case repel
    case vortex

    var id: String { rawValue }

    /// Wire value passed to `graph_engine_set_cursor_force`.
    /// 0 = off, 1 = suck, 2 = repel, 3 = vortex.
    var ffiValue: UInt8 {
        switch self {
        case .off: return 0
        case .suck: return 1
        case .repel: return 2
        case .vortex: return 3
        }
    }

    var systemImage: String {
        switch self {
        case .off: return "circle.dashed"
        case .suck: return "scope"
        case .repel: return "circle.dotted.and.circle"
        case .vortex: return "tornado"
        }
    }

    var shortLabel: String {
        switch self {
        case .off: return "Off"
        case .suck: return "Suck"
        case .repel: return "Repel"
        case .vortex: return "Vortex"
        }
    }
}

/// Shape-bound overlay kind. While active, the graph engine pushes
/// every node toward the interior of an invisible bounding shape
/// centered on origin with `shapeBoundRadius` half-extent.
enum ShapeBoundKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case off
    case circle
    case square
    case triangle
    case hexagon
    case star

    var id: String { rawValue }

    /// Wire value passed to `graph_engine_set_shape_bound`.
    /// 0 = off, 1 = circle, 2 = square, 3 = triangle, 4 = hexagon, 5 = star.
    var ffiValue: UInt8 {
        switch self {
        case .off: return 0
        case .circle: return 1
        case .square: return 2
        case .triangle: return 3
        case .hexagon: return 4
        case .star: return 5
        }
    }

    var systemImage: String {
        switch self {
        case .off: return "circle.dashed"
        case .circle: return "circle"
        case .square: return "square"
        case .triangle: return "triangle"
        case .hexagon: return "hexagon"
        case .star: return "star"
        }
    }

    var shortLabel: String {
        switch self {
        case .off: return "Off"
        case .circle: return "○"
        case .square: return "▢"
        case .triangle: return "△"
        case .hexagon: return "⬡"
        case .star: return "★"
        }
    }
}

// MARK: - Physics Presets

enum PhysicsPreset: String, CaseIterable, Identifiable {
    case observatory = "Observatory"     // Default — spread out, calm
    case nebula = "Nebula"               // Loose, floaty, gentle drift
    case crystal = "Crystal"             // Tight, structured, snappy
    case gravityWell = "Gravity Well"     // Compact center cluster
    case halo = "Halo"                    // Rounded middle cloud
    case nucleus = "Nucleus"              // Densest centered preset
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
        case .gravityWell:   return "smallcircle.filled.circle"
        case .halo:          return "circle.dotted"
        case .nucleus:       return "circle.hexagongrid.fill"
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
        case .gravityWell:   return 72
        case .halo:          return 120
        case .nucleus:       return 58
        case .fluid:         return 180
        case .constellation: return 350
        case .deepSea:       return 200
        case .solarSystem:   return 300
        case .windTunnel:    return 200
        case .snowflake:     return 100
        case .rubberBand:    return 220
        case .zenGarden:     return 300
        case .chaos:         return 180
        }
    }
    var chargeStrength: Float {
        switch self {
        case .observatory:   return -300
        case .nebula:        return -250
        case .crystal:       return -300
        case .gravityWell:   return -180
        case .halo:          return -260
        case .nucleus:       return -120
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
        case .gravityWell:   return 320
        case .halo:          return 520
        case .nucleus:       return 240
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
        case .gravityWell:   return 0
        case .halo:          return 0
        case .nucleus:       return 0.12
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
        case .gravityWell:   return 0.78
        case .halo:          return 0.55
        case .nucleus:       return 0.86
        case .fluid:         return 0.20
        case .constellation: return 0.08
        case .deepSea:       return 0.50
        case .solarSystem:   return 0.08
        case .windTunnel:    return 0.05
        case .snowflake:     return 0.85
        case .rubberBand:    return 0.10
        case .zenGarden:     return 0.15
        case .chaos:         return 0.07
        }
    }
    var centerStrength: Float {
        switch self {
        case .observatory:   return 0.03
        case .nebula:        return 0.005
        case .crystal:       return 0.03
        case .gravityWell:   return 0.085
        case .halo:          return 0.055
        case .nucleus:       return 0.12
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
        case .gravityWell:   return 18
        case .halo:          return 34
        case .nucleus:       return 16
        case .fluid:         return 45
        case .constellation: return 35
        case .deepSea:       return 50
        case .solarSystem:   return 40
        case .windTunnel:    return 30
        case .snowflake:     return 25
        case .rubberBand:    return 45
        case .zenGarden:     return 60
        case .chaos:         return 26
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
        case .crystal,
             .gravityWell,
             .halo,
             .nucleus,
             .nebula,
             .fluid,
             .constellation:
            return LabOverrides()
        }
    }

    // MARK: - Motion Vocabulary (v3 motion spec §3.4 / canonical commit 9)
    //
    // Synthesis explicitly rejected a giant flat preset dump. Every
    // preset carries a `MotionCategory` tag and an `isFeatured` flag so
    // the picker UI can show a short, intentional set while saved
    // scheduler steps and hidden built-ins keep resolving by name.
    //
    // No physics values change here — this is pure metadata. Presets
    // that enable experimental forces (orbital / torsion / wind) are
    // marked `.experimental` so the user can tell at a glance before
    // picking.

    var motionCategory: GraphMotionCategory {
        switch self {
        // Calm — spread, minimal forces, quiet layout
        case .observatory:   return .calm
        case .constellation: return .calm
        case .zenGarden:     return .calm
        case .gravityWell:   return .calm
        case .halo:          return .calm
        case .nucleus:       return .calm
        // Fluid — water-like, springy, flow
        case .nebula:        return .fluid
        case .fluid:         return .fluid
        case .deepSea:       return .fluid
        // Playful — bouncy, snappy, dynamic
        case .crystal:       return .playful
        case .rubberBand:    return .playful
        case .chaos:         return .playful
        // Experimental — enable orbital / torsion / wind so feel
        // differs sharply from classical graph layout
        case .solarSystem:   return .experimental
        case .windTunnel:    return .experimental
        case .snowflake:     return .experimental
        }
    }

    /// Whether this preset should appear in the default picker list.
    /// The picker intentionally stays short, but includes the centered
    /// layouts the user asked for after the graph motion pass: Crystal
    /// plus a few middle-congregating options that reuse the existing
    /// physics parameters without changing the Rust engine.
    var isFeatured: Bool {
        switch self {
        case .observatory,
             .crystal,
             .gravityWell,
             .halo,
             .nucleus,
             .constellation,
             .chaos:
            return true
        default:
            return false
        }
    }
}

/// Vocabulary for grouping physics presets by perceptual feel
/// (v3 motion spec §3.4). Used by the picker UI to organise the
/// 12-preset list into meaningful sections rather than a flat dump.
enum GraphMotionCategory: String, CaseIterable, Identifiable, Codable {
    case calm
    case fluid
    case playful
    case experimental

    var id: String { rawValue }

    /// Human-readable header for a section in the picker UI.
    var displayName: String {
        switch self {
        case .calm:         return "Calm"
        case .fluid:        return "Fluid"
        case .playful:      return "Playful"
        case .experimental: return "Experimental"
        }
    }

    /// Short description shown under the section header so users know
    /// what to expect before expanding.
    var tagline: String {
        switch self {
        case .calm:         return "Spread and quiet — hubs anchor, leaves drift"
        case .fluid:        return "Flowing and springy — drag leaves a wake"
        case .playful:      return "Bouncy and dynamic — crisp overshoot on release"
        case .experimental: return "Orbital, torsion, wind — the lab drawer"
        }
    }

    /// Stable display order in the picker UI.
    var sortOrder: Int {
        switch self {
        case .calm:         return 0
        case .fluid:        return 1
        case .playful:      return 2
        case .experimental: return 3
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
    // Raw value is preserved for old UserDefaults; the actual atlas follows
    // the active light/dark typography pair.
    case retro
    var id: String { rawValue }
    var displayName: String { "Theme" }
    func atlasResourceName(isDark: Bool) -> String {
        AppDisplayTypography.graphLabelAtlasResourceName(isDark: isDark)
    }
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
    // Per user 2026-05-12: bump to version 3 to migrate Observatory-era
    // boot defaults (selectedPreset=observatory, linkDistance=80,
    // centerStrength=0.03) to the new Gravity Well variant
    // (selectedPreset=gravityWell, linkDistance=500, centerStrength=0,
    // enableFluidDynamics=false). Without this migration, users who
    // picked up Observatory as the default during the earlier 2026-05-12
    // session don't see the new Gravity-Well + 3-override boot state
    // because the first-launch branch in restorePhysicsSettings skips
    // when any selectedPreset key is already stored.
    private static let schedulerDefaultsVersion = 3
    private static let schedulerDefaultsVersionKey = "epistemos.physics.schedulerDefaultsVersion"
    private static let nodeVisibilityDefaultsKey = "epistemos.graph.visibleNodeTypes"

    static let userFilterableNodeTypes: [GraphNodeType] = GraphNodeType.visibleCases

    static let contentFocusedNodeTypes: Set<GraphNodeType> = Set(userFilterableNodeTypes)
        .subtracting([.folder])

    private static func defaultTimelineSteps() -> [PhysicsScheduleStep] {
        GraphOverlayPhysicsPolicy.defaultTimelineSignature.map { step in
            PhysicsScheduleStep(delaySeconds: step.0, presetKey: step.1)
        }
    }

    private static func timelineSignature(_ steps: [PhysicsScheduleStep]) -> [(Double, String)] {
        steps.map { ($0.delaySeconds, $0.presetKey) }
    }

    private static func timelineSignatureMatches(
        _ steps: [PhysicsScheduleStep],
        expected signature: [(Double, String)]
    ) -> Bool {
        let actual = timelineSignature(steps)
        guard actual.count == signature.count else { return false }
        return zip(actual, signature).allSatisfy { lhs, rhs in
            lhs.0 == rhs.0 && lhs.1 == rhs.1
        }
    }

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

    /// True when physics is explicitly frozen by the user.
    /// Updated after each commit/refresh cycle. UI uses this to grey out physics controls.
    var isStaticLayout: Bool = false

    /// Large graph threshold where entrance animation is skipped so initial
    /// load stays snappy. Physics remains active above this threshold.
    static let largeGraphEntranceThreshold = 9000

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
        let svc = EmbeddingService(
            embeddingLookup: DeferredTextEmbeddingLookup {
                AppleHybridEmbeddingLookup()
            }
        )
        self.embeddingService = svc
        self.performanceModeEnabled = Self.restoredPerformanceModeEnabled()
        self.visualTheme = Self.restoredVisualTheme()
        svc.graphState = self
        // Load custom presets FIRST (outside version gate) so they survive
        // any core-physics-settings reset triggered by a physicsVersion bump.
        loadCustomPresetsFromDefaults()
        restorePhysicsSettings()
        restoreLabelPolicy()
        restoreGraphNodeVisibility()
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
        let interval = Log.ffiPerf.beginInterval("graph_engine_pin_node")
        nodeId.withCString { graph_engine_pin_node(engine, $0) }
        Log.ffiPerf.endInterval("graph_engine_pin_node", interval)
    }

    /// Unpin a node, releasing its position constraint.
    func unpinNode(_ nodeId: String) {
        pinnedNodeIds.remove(nodeId)
        guard let engine = engineHandle else { return }
        let interval = Log.ffiPerf.beginInterval("graph_engine_unpin_node")
        nodeId.withCString { graph_engine_unpin_node(engine, $0) }
        Log.ffiPerf.endInterval("graph_engine_unpin_node", interval)
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

    func isNodeTypeVisible(_ type: GraphNodeType) -> Bool {
        filter.activeNodeTypes.contains(type)
    }

    func setNodeTypeVisibility(_ type: GraphNodeType, isVisible: Bool) {
        guard filter.setType(type, isVisible: isVisible) else { return }
        persistGraphNodeVisibility()
        sanitizeSelectionAfterFilterChange()
        requestFilterSync()
    }

    func applyContentFocusedNodeVisibility() {
        applyNodeVisibilityPreset(Self.contentFocusedNodeTypes)
    }

    func showAllUserFilterableNodeTypes() {
        applyNodeVisibilityPreset(Set(Self.userFilterableNodeTypes))
    }

    private func applyNodeVisibilityPreset(_ visibleTypes: Set<GraphNodeType>) {
        var nextTypes = filter.activeNodeTypes
        for type in Self.userFilterableNodeTypes {
            if visibleTypes.contains(type) {
                nextTypes.insert(type)
            } else {
                nextTypes.remove(type)
            }
        }
        guard filter.setActiveNodeTypes(nextTypes) else { return }
        persistGraphNodeVisibility()
        sanitizeSelectionAfterFilterChange()
        requestFilterSync()
    }

    private func persistGraphNodeVisibility() {
        let visibleRawValues = Self.userFilterableNodeTypes
            .filter { filter.activeNodeTypes.contains($0) }
            .map(\.rawValue)
        UserDefaults.standard.set(visibleRawValues, forKey: Self.nodeVisibilityDefaultsKey)
    }

    private func restoreGraphNodeVisibility() {
        guard let visibleRawValues = UserDefaults.standard.array(forKey: Self.nodeVisibilityDefaultsKey) as? [String] else {
            return
        }
        let allowedTypes = Set(Self.userFilterableNodeTypes)
        var nextTypes = filter.activeNodeTypes.subtracting(allowedTypes)
        for rawValue in visibleRawValues {
            guard let type = GraphNodeType(rawValue: rawValue),
                  allowedTypes.contains(type) else {
                continue
            }
            nextTypes.insert(type)
        }
        _ = filter.setActiveNodeTypes(nextTypes)
    }

    private func sanitizeSelectionAfterFilterChange() {
        if let selectedNodeId,
           let node = store.nodes[selectedNodeId],
           !filter.isNodeVisible(node) {
            selectNode(nil)
            selectedNodeScreenPoint = nil
        }
        if let focusedNodeId = filter.focusedNodeId,
           let node = store.nodes[focusedNodeId],
           !filter.isNodeVisible(node) {
            clearFocus()
        }
    }

    /// Set to true when the rebuild button is pressed while graph is visible.
    var pendingRebuild = false

    /// Clear every visible and engine-backed graph surface when the active vault changes.
    func resetForVaultLifecycle() {
        store.clear()
        filter.resetForVaultLifecycle()
        restoreGraphNodeVisibility()

        vaultMode = .humanVault
        routeHistory = [.canvas]
        routeCursor = 0
        NotificationCenter.default.post(name: .graphRouteDidChange, object: self)

        selectedNodeId = nil
        selectedNodeScreenPoint = nil
        requestEditorMode = false
        pinnedNodeIds.removeAll(keepingCapacity: false)

        isLoaded = false
        isWarmed = false
        hasPlayedEntrance = false
        isScanning = false
        scanProgress = 0
        scanStatus = ""
        needsRefresh = false
        mode = .global
        modeVersion += 1
        pendingCenterNodeId = nil
        shouldSnapNextGlobalRecommitCamera = false

        pendingNodeAdds.removeAll(keepingCapacity: false)
        pendingEdgeAdds.removeAll(keepingCapacity: false)
        pendingNodeRemovals.removeAll(keepingCapacity: false)
        pendingEdgeRemovals.removeAll(keepingCapacity: false)
        pendingRebuild = false
        filterVersion += 1

        isStaticLayout = false
        isBuildingStructural = false
        semanticClusterIds.removeAll(keepingCapacity: false)
        semanticClusterVersion += 1
        ephemeralNodeIds.removeAll(keepingCapacity: false)
        ephemeralEdgeIds.removeAll(keepingCapacity: false)
        wikilinkLookup.removeAll(keepingCapacity: false)

        if let engine = engineHandle {
            graph_engine_clear(engine)
            graph_engine_clear_highlight(engine)
            graph_engine_clear_embeddings(engine)
            graph_engine_clear_prepared_retrieval_index(engine)
        }
        loadedPreparedRetrievalIndexEngine = nil
        loadedPreparedRetrievalIndexManifestPath = nil
        requestRecommit()
    }

    func beginGraphResetCycle() {
        startOverlayPhysicsCycle()
    }

    func requestGraphRebuild() {
        beginGraphResetCycle()
        pendingRebuild = true
    }

    private func notifyGraphRenderSettingsChanged() {
        NotificationCenter.default.post(name: .graphRenderSettingsChanged, object: self)
    }

    // MARK: - Quality Level

    private static let performanceModeDefaultsKey = "epistemos.graph.performanceMode"

    private static func restoredPerformanceModeEnabled(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: performanceModeDefaultsKey) != nil else {
            return false
        }
        return defaults.bool(forKey: performanceModeDefaultsKey)
    }

    /// Graph-only runtime render mode. Default remains the polished cinematic path.
    var performanceModeEnabled: Bool = false {
        didSet {
            guard performanceModeEnabled != oldValue else { return }
            UserDefaults.standard.set(performanceModeEnabled, forKey: Self.performanceModeDefaultsKey)
            liteModeVersion += 1
            waterNodesVersion += 1
            notifyGraphRenderSettingsChanged()
        }
    }

    /// Incremented when the graph render quality mode changes, so MetalGraphView can
    /// re-sync the renderer without a full recommit.
    var liteModeVersion: Int = 0

    /// Runtime quality level forwarded to Rust.
    /// 0 = cinematic pixel default, 2 = performance mode.
    ///
    /// PowerGuard may throttle frame pacing/resolution, but it must not silently
    /// change the graph's visual identity. If the toolbar says Pixel, Rust must
    /// receive the cinematic pixel shader path.
    var qualityLevel: UInt8 {
        get {
            return performanceModeEnabled ? 2 : 0
        }
        set { performanceModeEnabled = newValue >= 2 }
    }

    // MARK: - Frame Rate Cap (2026-05-20)
    //
    // Lets the user trade FPS for battery. 0 = "Unlimited" — the
    // CADisplayLink keeps preferredFrameRateRange at 60-120 (ProMotion
    // adaptive). Otherwise we clamp the link to the chosen value.
    //
    // Read in MetalGraphView.startDisplayLink. Changes take effect on
    // the next graph-overlay show / display-link restart (cheap;
    // happens whenever needsRender flips back to true).

    static let graphMaxFPSDefaultsKey = "epistemos.graph.maxFPS"
    static let graphFPSHUDDefaultsKey = "epistemos.graph.showFPSHUD"
    static let graphForceMaximumFPSDefaultsKey = "epistemos.graph.forceMaximumFPS"

    /// 0 = Unlimited (ProMotion adaptive 60-120). Other accepted values: 30, 60, 120.
    /// Stored-property initializer references the type by full name
    /// (`GraphState.`) not `Self.` because Swift forbids `Self` in stored
    /// property initializers on classes (covariant `Self`).
    var graphMaxFPS: Int = GraphState.restoredGraphMaxFPS() {
        didSet {
            guard graphMaxFPS != oldValue else { return }
            UserDefaults.standard.set(graphMaxFPS, forKey: Self.graphMaxFPSDefaultsKey)
            graphFPSConfigVersion &+= 1
            notifyGraphRenderSettingsChanged()
        }
    }

    /// Toggles the live FPS overlay shown in the graph chrome.
    var graphFPSHUDEnabled: Bool = GraphState.restoredGraphFPSHUDEnabled() {
        didSet {
            guard graphFPSHUDEnabled != oldValue else { return }
            UserDefaults.standard.set(graphFPSHUDEnabled, forKey: Self.graphFPSHUDDefaultsKey)
        }
    }

    /// MASTER 120Hz OVERRIDE. When true, every display link the app
    /// owns (graph + landing wave + any future Metal surface) clamps
    /// to `CAFrameRateRange(120, 120, 120)` — ProMotion's top rate,
    /// ignoring the `graphMaxFPS` cap, ignoring PowerGuard, ignoring
    /// thermal state. Intentionally aggressive: users opt in explicitly
    /// when they want max smoothness and accept the battery cost.
    ///
    /// Off by default. Toggling this BUMPS `graphFPSConfigVersion`
    /// so MetalGraphView's renderFrame() picks up the new policy on
    /// the very next frame without an overlay restart.
    var graphForceMaximumFPS: Bool = GraphState.restoredGraphForceMaximumFPS() {
        didSet {
            guard graphForceMaximumFPS != oldValue else { return }
            UserDefaults.standard.set(graphForceMaximumFPS, forKey: Self.graphForceMaximumFPSDefaultsKey)
            graphFPSConfigVersion &+= 1
            notifyGraphRenderSettingsChanged()
        }
    }

    /// Live FPS (rolling 60-frame average). Written by MetalGraphView's
    /// renderFrame() hot path. Reading this is observation-safe because
    /// writes happen at most once per frame and only when the HUD is on.
    var graphMeasuredFPS: Double = 0

    /// Live p99 frame interval in ms (over the last ~120 samples).
    /// Surfaces the worst-case 1% jank — what determines whether you
    /// hit the framePending guard and drop to 60Hz.
    var graphMeasuredP99Ms: Double = 0

    /// Incremented when graphMaxFPS changes so MetalGraphView's display
    /// link config picks up the new cap without a full overlay restart.
    var graphFPSConfigVersion: Int = 0

    private static func restoredGraphMaxFPS() -> Int {
        let defaults = UserDefaults.standard
        // First launch: 0 (Unlimited / ProMotion adaptive).
        guard defaults.object(forKey: graphMaxFPSDefaultsKey) != nil else {
            return 0
        }
        let raw = defaults.integer(forKey: graphMaxFPSDefaultsKey)
        // Validate to known buckets; fall back to Unlimited on garbage.
        switch raw {
        case 0, 30, 60, 120: return raw
        default: return 0
        }
    }

    private static func restoredGraphFPSHUDEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: graphFPSHUDDefaultsKey)
    }

    private static func restoredGraphForceMaximumFPS() -> Bool {
        // 2026-05-20 user direction: default ON. Most users on M-series
        // MacBook Pro have ProMotion-capable displays and want max
        // smoothness. They opt OUT via the Settings toggle if they
        // want to save battery; opting IN by default beats hiding the
        // best experience behind a discoverable toggle.
        let defaults = UserDefaults.standard
        if defaults.object(forKey: graphForceMaximumFPSDefaultsKey) == nil {
            return true
        }
        return defaults.bool(forKey: graphForceMaximumFPSDefaultsKey)
    }

    // MARK: - Visual Theme

    /// Dialogue vs Classic SDF renderer. Persisted via UserDefaults.
    var visualTheme: GraphVisualTheme = .classic {
        didSet {
            UserDefaults.standard.set(Int(visualTheme.rawValue), forKey: Self.visualThemeDefaultsKey)
            visualThemeVersion += 1
            notifyGraphRenderSettingsChanged()
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

    // MARK: - Cinematic Pixel Nodes

    /// Legacy FFI flag retained for renderer compatibility. The v1 cinematic
    /// identity is hard stepped pixel nodes; performance mode switches to the
    /// simpler existing fast shader as one coherent mode.
    var waterNodesEnabled: Bool {
        !performanceModeEnabled
    }
    var waterNodesWobble: Float = 0.0 {
        didSet {
            UserDefaults.standard.set(waterNodesWobble, forKey: "epistemos.waterNodes.wobble")
            waterNodesVersion += 1
            notifyGraphRenderSettingsChanged()
        }
    }
    var waterNodesVersion: Int = 0

    // MARK: - Camera

    /// How close the camera stays to the previous selection when the user
    /// deselects (clicks empty space). Higher = tighter / less zoom-out;
    /// 1.0 = full fit-all (the old default), 1.7 = canonical default.
    /// Range: 1.0 ... 3.0.
    var cameraDeselectZoomMultiplier: Float = GraphCameraDefaults.load(
        key: "epistemos.camera.deselectZoomMultiplier",
        defaultValue: 1.7
    ) {
        didSet {
            UserDefaults.standard.set(
                Double(cameraDeselectZoomMultiplier),
                forKey: "epistemos.camera.deselectZoomMultiplier"
            )
            cameraConfigVersion += 1
            notifyGraphRenderSettingsChanged()
        }
    }
    /// Camera lerp lambda. Higher = snappier transitions (zoom/pan/center).
    /// Range: 4.0 (silky slow) ... 22.0 (instant snap). Default 11.0.
    var cameraSpeedLambda: Float = GraphCameraDefaults.load(
        key: "epistemos.camera.speedLambda",
        defaultValue: 11.0
    ) {
        didSet {
            UserDefaults.standard.set(
                Double(cameraSpeedLambda),
                forKey: "epistemos.camera.speedLambda"
            )
            cameraConfigVersion += 1
            notifyGraphRenderSettingsChanged()
        }
    }
    /// Bumped whenever a camera setting changes so `MetalGraphNSView`
    /// detects the delta and pushes new values to the Rust engine.
    var cameraConfigVersion: Int = 0

    // MARK: - Graph Title

    var graphTitleMode: GraphTitleMode = .firstOpen {
        didSet {
            UserDefaults.standard.set(graphTitleMode.rawValue, forKey: "epistemos.graph.titleMode")
            notifyGraphRenderSettingsChanged()
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
        notifyGraphRenderSettingsChanged()
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
    // 2026-05-19 user-spec defaults (replaced the legacy dense-graph
    // tuning): spacious link distance, strong long-range repulsion,
    // 0-auto link strength, no center pull, no collision buffer, high
    // friction.
    /// Natural resting length of edge springs.
    var linkDistance: Float = 250.0
    /// Many-body charge strength (negative = repulsion).
    var chargeStrength: Float = -3000.0
    /// Maximum range for many-body repulsion.
    var chargeRange: Float = 100.0
    /// Link spring strength. 0 = auto (d3: 1 / min(degree)).
    var linkStrength: Float = 0.0

    // ── Extended ──
    /// Velocity retain multiplier (d3: 0.6 = retain 60% per tick).
    /// 2026-05-19 user spec: friction 0.80.
    var velocityDecay: Float = 0.80
    /// Center gravity pull strength. 2026-05-19 user spec: 0 (off).
    var centerStrength: Float = 0.0
    /// Collision buffer zone in pixels. 2026-05-19 user spec: 0 (no
    /// extra node spacing — relies on charge repulsion to keep nodes
    /// apart).
    var collisionRadius: Float = 0.0
    private(set) var selectedPhysicsPreset: PhysicsPreset?

    /// Incremented whenever a force slider changes, so the Metal view can detect it.
    var forceConfigVersion: Int = 0
    /// Incremented for extended params independently.
    var extendedForceConfigVersion: Int = 0

    func pushForceChange() {
        selectedPhysicsPreset = nil
        forceConfigVersion += 1
        savePhysicsSettings()
        notifyGraphRenderSettingsChanged()
    }

    func pushExtendedForceChange() {
        selectedPhysicsPreset = nil
        extendedForceConfigVersion += 1
        savePhysicsSettings()
        notifyGraphRenderSettingsChanged()
    }

    // ── User-directed force overlays (V6.2 toolbar 2026-05-12) ──
    // Cursor force: follows the live cursor; suck/repel/vortex.
    // Mutations push immediately to Rust via FFI from MetalGraphView's
    // `pushUserForceOverlaysIfChanged()`.
    var cursorForceMode: CursorForceMode = .off {
        didSet {
            guard cursorForceMode != oldValue else { return }
            userForceOverlayVersion &+= 1
            saveUserForceOverlays()
        }
    }
    /// 0..1 strength multiplier for the cursor force. Default 0.5 =
    /// noticeable; 1.0 = overwhelm equilibrium.
    var cursorForceStrength: Float = 0.5 {
        didSet {
            guard cursorForceStrength != oldValue else { return }
            userForceOverlayVersion &+= 1
            saveUserForceOverlays()
        }
    }
    /// Shape-bound: pushes nodes into a named formation.
    /// 2026-05-19 — default changed from `.off` → `.square` per user
    /// direction: the graph should always open inside a shape. Square
    /// reads cleanly against any window size. Existing users with a
    /// saved preference still keep it (restored from UserDefaults), and
    /// anyone with a previously-saved `.off` is migrated to `.square` in
    /// the restore path below.
    var shapeBoundKind: ShapeBoundKind = .square {
        didSet {
            guard shapeBoundKind != oldValue else { return }
            userForceOverlayVersion &+= 1
            saveUserForceOverlays()
        }
    }
    /// World-unit radius of the shape-bound formation. Default 800.
    var shapeBoundRadius: Float = 800.0 {
        didSet {
            guard shapeBoundRadius != oldValue else { return }
            userForceOverlayVersion &+= 1
            saveUserForceOverlays()
        }
    }
    /// Monotonic version counter — MetalGraphView watches this to know
    /// when to re-push the cursor + shape state to Rust via FFI.
    var userForceOverlayVersion: Int = 0

    private func saveUserForceOverlays() {
        let d = UserDefaults.standard
        d.set(cursorForceMode.rawValue, forKey: "epistemos.physics.cursorForceMode")
        d.set(cursorForceStrength, forKey: "epistemos.physics.cursorForceStrength")
        d.set(shapeBoundKind.rawValue, forKey: "epistemos.physics.shapeBoundKind")
        d.set(shapeBoundRadius, forKey: "epistemos.physics.shapeBoundRadius")
    }

    // ── Laboratory (advanced physics toggles + knobs) ──
    // 2026-05-19 user-spec defaults: experimental fluid wake physics ON
    // with viscosity 0.30.
    var enableFluidDynamics: Bool = true
    var enableTorsionalSprings: Bool = false
    var enableElasticEdges: Bool = true
    var fluidViscosity: Float = 0.30
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
        notifyGraphRenderSettingsChanged()
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
        d.set(Self.schedulerDefaultsVersion, forKey: Self.schedulerDefaultsVersionKey)
        // Timeline steps as JSON
        if let stepsData = try? JSONEncoder().encode(timelineSteps) {
            d.set(stepsData, forKey: "epistemos.physics.timelineSteps")
        } else {
            Log.app.error("GraphState: failed to encode timelineSteps; preserving existing stored schedule")
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
        // User-directed force overlays (V6.2 toolbar 2026-05-12). Each
        // key falls back to the type's default when absent so first-
        // launch users get a clean off state.
        if let raw = d.string(forKey: "epistemos.physics.cursorForceMode"),
           let mode = CursorForceMode(rawValue: raw) {
            cursorForceMode = mode
        }
        if d.object(forKey: "epistemos.physics.cursorForceStrength") != nil {
            let s = d.float(forKey: "epistemos.physics.cursorForceStrength")
            if s.isFinite, s > 0 {
                cursorForceStrength = max(0.0, min(1.0, s))
            }
        }
        if let raw = d.string(forKey: "epistemos.physics.shapeBoundKind"),
           let kind = ShapeBoundKind(rawValue: raw) {
            // 2026-05-19: migrate any previously-saved `.off` → `.square`
            // so existing users also land on the new default. They can
            // still pick a different shape via the floating Shape control.
            shapeBoundKind = (kind == .off) ? .square : kind
        }
        if d.object(forKey: "epistemos.physics.shapeBoundRadius") != nil {
            let r = d.float(forKey: "epistemos.physics.shapeBoundRadius")
            if r.isFinite, r > 1 {
                shapeBoundRadius = max(1.0, min(5000.0, r))
            }
        }
        if let raw = d.string(forKey: "epistemos.physics.selectedPreset") {
            selectedPhysicsPreset = PhysicsPreset(rawValue: raw)
        } else {
            // 2026-05-19 — per user direction, boot defaults are the
            // inline values declared above (NOT a preset). Presets only
            // become active when the user explicitly picks one in the
            // floating-toolbar Shape settings. We persist the inline
            // values so first launch matches subsequent launches
            // byte-identically.
            //   linkDistance      = 250, chargeStrength = -3000,
            //   chargeRange       = 100, linkStrength   = 0 (auto),
            //   velocityDecay     = 0.80 (friction),
            //   centerStrength    = 0 (center force off),
            //   collisionRadius   = 0 (no spacing),
            //   enableFluidDynamics = true, fluidViscosity = 0.30,
            //   useSemanticClustering = false.
            d.set(linkDistance, forKey: "epistemos.physics.linkDistance")
            d.set(chargeStrength, forKey: "epistemos.physics.chargeStrength")
            d.set(chargeRange, forKey: "epistemos.physics.chargeRange")
            d.set(linkStrength, forKey: "epistemos.physics.linkStrength")
            d.set(velocityDecay, forKey: "epistemos.physics.velocityDecay")
            d.set(centerStrength, forKey: "epistemos.physics.centerStrength")
            d.set(collisionRadius, forKey: "epistemos.physics.collisionRadius")
            d.set(enableFluidDynamics, forKey: "epistemos.physics.enableFluid")
            d.set(fluidViscosity, forKey: "epistemos.physics.fluidViscosity")
        }
        // Master toggle + saved strengths
        if d.object(forKey: "epistemos.physics.savedClusterStrength") != nil {
            savedClusterStrength = d.float(forKey: "epistemos.physics.savedClusterStrength")
            savedSemanticStrength = d.float(forKey: "epistemos.physics.savedSemanticStrength")
            disableClusteringAndSemantics = d.bool(forKey: "epistemos.physics.disableClusteringAndSemantics")
        }
        // Scheduler enabled toggle — 2026-05-19. Default false (off) so
        // the user's saved physics state isn't auto-overridden by the
        // opening preset on every reopen.
        if d.object(forKey: "epistemos.physics.schedulerEnabled") != nil {
            schedulerEnabled = d.bool(forKey: "epistemos.physics.schedulerEnabled")
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
        if let stepsData = d.data(forKey: "epistemos.physics.timelineSteps") {
            if let steps = try? JSONDecoder().decode([PhysicsScheduleStep].self, from: stepsData) {
                timelineSteps = steps
            } else {
                Log.app.error("GraphState: failed to decode timelineSteps; keeping in-memory schedule unchanged")
            }
        }
        migrateLegacySchedulerDefaultsIfNeeded(defaults: d)
        if isPhysicsFrozen { physicsFrozenVersion += 1 }
    }

    private func migrateLegacySchedulerDefaultsIfNeeded(defaults: UserDefaults) {
        let storedVersion = defaults.integer(forKey: Self.schedulerDefaultsVersionKey)
        guard storedVersion < Self.schedulerDefaultsVersion else { return }

        var didMigrate = false
        if simpleOpeningPresetKey == "crystal",
           abs(simpleOpeningDelaySeconds - 3.0) < 0.0001,
           simpleRestingPresetKey == "chaos" {
            simpleOpeningPresetKey = GraphOverlayPhysicsPolicy.openingPresetKey
            simpleOpeningDelaySeconds = GraphOverlayPhysicsPolicy.chaosDelaySeconds
            simpleRestingPresetKey = GraphOverlayPhysicsPolicy.restingPresetKey
            didMigrate = true
        }

        if schedulerMode == .timeline,
           Self.timelineSignatureMatches(
                timelineSteps,
                expected: GraphOverlayPhysicsPolicy.legacyDefaultTimelineSignature
           ) {
            timelineSteps = Self.defaultTimelineSteps()
            didMigrate = true
        }

        // Version-3 migration (per user 2026-05-12): bring users on the
        // Observatory-era boot defaults onto the new Gravity Well +
        // 3-override boot state. We only touch users who look like
        // they're on the OLD default state — anyone who's customized
        // their physics settings is left alone.
        //
        // OLD-defaults signature:
        //   selectedPreset == .observatory
        //   linkDistance ≈ 80 (Observatory stock)
        //   centerStrength ≈ 0.03 (Observatory stock)
        //   chargeStrength ≈ -300 (Observatory stock)
        //
        // If any of those four are different, the user has customized;
        // we skip the migration and just bump the version key.
        if storedVersion < 3,
           selectedPhysicsPreset == .observatory,
           abs(linkDistance - 80.0) < 0.5,
           abs(centerStrength - 0.03) < 0.005,
           abs(chargeStrength - (-300.0)) < 1.0 {
            // Detected Observatory boot state — apply Gravity Well +
            // 3 overrides without going through applyPreset (which
            // would cancel the overlay cycle and persist via
            // savePhysicsSettings; we want to be more surgical here).
            selectedPhysicsPreset = .gravityWell
            linkDistance = 500.0
            chargeStrength = PhysicsPreset.gravityWell.chargeStrength
            chargeRange = PhysicsPreset.gravityWell.chargeRange
            linkStrength = PhysicsPreset.gravityWell.linkStrength
            velocityDecay = PhysicsPreset.gravityWell.velocityDecay
            centerStrength = 0.0
            collisionRadius = PhysicsPreset.gravityWell.collisionRadius
            enableFluidDynamics = false
            didMigrate = true
        }

        defaults.set(Self.schedulerDefaultsVersion, forKey: Self.schedulerDefaultsVersionKey)
        if didMigrate {
            savePhysicsSettings()
        }
    }

    // ── Cluster ──
    var clusterStrength: Float = 0.0
    // 2026-05-19 user spec: center force off by default.
    var centerMode: UInt8 = 1  // 0=attract, 1=off, 2=repel
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
        notifyGraphRenderSettingsChanged()
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
        notifyGraphRenderSettingsChanged()
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
        applyLabOverrides: Bool = true,
        cancelOverlayCycle: Bool = true
    ) {
        if cancelOverlayCycle {
            cancelOverlayPhysicsCycle()
        }
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
            notifyGraphRenderSettingsChanged()
        }
    }

    private func applyOverlayPreset(_ preset: PhysicsPreset) {
        applyPreset(
            preset,
            persist: false,
            applyLabOverrides: false,
            cancelOverlayCycle: false
        )
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

    /// User-controlled toggle (Settings → Graph). When `false` the startup
    /// scheduler is a no-op so the graph opens with whatever physics state
    /// the user has saved — no preset is auto-applied. Per user direction
    /// 2026-05-19: the scheduler was overriding their custom defaults.
    /// Default is `false` (off) — explicit opt-in to bring it back.
    var schedulerEnabled: Bool = false {
        didSet {
            guard !isRestoringPhysicsSettings, schedulerEnabled != oldValue else { return }
            UserDefaults.standard.set(
                schedulerEnabled,
                forKey: "epistemos.physics.schedulerEnabled"
            )
        }
    }

    func startOverlayPhysicsCycle() {
        cancelOverlayPhysicsCycle()
        // 2026-05-19: skip the scheduler entirely when the user has it
        // toggled off so their saved physics settings are not overridden
        // by the opening / resting preset application.
        guard schedulerEnabled else { return }
        switch schedulerMode {
        case .simple:
            runSimpleScheduler()
        case .timeline:
            runTimelineScheduler()
        }
    }

    /// Restore every user-tunable physics setting to the canonical V3
    /// boot defaults (Gravity Well preset + 3 overrides: linkDistance
    /// 500, centerStrength 0, enableFluidDynamics off). Mirrors the
    /// signature applied by `migrateLegacySchedulerDefaultsIfNeeded`
    /// but without the "looks like old defaults" gating, so the user
    /// can always recover from any customization. Also clears the
    /// cursor force + shape bound overlays + the lab tunables, restores
    /// the default scheduler timeline, and unfreezes physics.
    ///
    /// Per user 2026-05-12: there was no "go back to defaults" path —
    /// once the user touched any force value, they were stuck with
    /// their custom state. This method is the single source of truth
    /// the Reset-to-defaults button calls. After resetting the values,
    /// it persists them and restarts the overlay cycle so the graph
    /// snaps to the new state without a relaunch.
    func resetPhysicsToCanonicalDefaults() {
        // Suppress the per-property `didSet` saves while we cascade
        // through dozens of assignments. We save once at the end.
        isRestoringPhysicsSettings = true
        defer { isRestoringPhysicsSettings = false }

        // Core preset values — Gravity Well as the canonical resting
        // shape, with three overrides per V3 doctrine.
        selectedPhysicsPreset = .gravityWell
        linkDistance = 500.0
        chargeStrength = PhysicsPreset.gravityWell.chargeStrength
        chargeRange = PhysicsPreset.gravityWell.chargeRange
        linkStrength = PhysicsPreset.gravityWell.linkStrength
        velocityDecay = PhysicsPreset.gravityWell.velocityDecay
        centerStrength = 0.0
        collisionRadius = PhysicsPreset.gravityWell.collisionRadius

        // Laboratory tunables — V3 doctrine wants fluid OFF; the rest
        // restore to their canonical "neutral" defaults.
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

        // Cluster + semantic — neutral.
        clusterStrength = 0.0
        centerMode = 0
        semanticStrength = 0.0
        useSemanticClustering = false
        disableClusteringAndSemantics = false

        // User-directed force overlays — off.
        cursorForceMode = .off
        cursorForceStrength = 0.5
        shapeBoundKind = .off
        shapeBoundRadius = 800.0

        // Scheduler — V3 defaults (opening → resting, then default timeline).
        schedulerMode = .simple
        simpleOpeningPresetKey = GraphOverlayPhysicsPolicy.openingPresetKey
        simpleOpeningDelaySeconds = GraphOverlayPhysicsPolicy.chaosDelaySeconds
        simpleRestingPresetKey = GraphOverlayPhysicsPolicy.restingPresetKey
        timelineSteps = Self.defaultTimelineSteps()
        interactionMotionHoldSeconds = GraphOverlayPhysicsPolicy.interactionMotionHoldSeconds
        interactionMotionAlphaTarget = GraphOverlayPhysicsPolicy.interactionMotionAlphaTarget
        startupViewMode = .fullOverlay

        // Camera knobs back to defaults.
        cameraDeselectZoomMultiplier = 1.0
        cameraSpeedLambda = 6.0

        // Unfreeze physics.
        if isPhysicsFrozen {
            isPhysicsFrozen = false
            physicsFrozenVersion += 1
        }

        // Bump every version counter that the render loop watches so
        // MetalGraphView re-pushes the cleaned state to Rust on the
        // next tick.
        forceConfigVersion += 1
        extendedForceConfigVersion += 1
        clusterConfigVersion += 1
        semanticForceConfigVersion += 1
        labConfigVersion += 1
        userForceOverlayVersion &+= 1
        cameraConfigVersion += 1

        savePhysicsSettings()
        notifyGraphRenderSettingsChanged()
        // Restart the overlay cycle so opening → resting fires again.
        startOverlayPhysicsCycle()
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
            notifyGraphRenderSettingsChanged()
        }
    }

    /// Snapshot of clusterStrength captured when `disableClusteringAndSemantics` was flipped ON.
    var savedClusterStrength: Float = 0.0
    /// Snapshot of semanticStrength captured when `disableClusteringAndSemantics` was flipped ON.
    var savedSemanticStrength: Float = 0.0

    // MARK: - Physics Scheduler

    /// Scheduler mode. `.simple` is the classic opening→resting 2-stage cycle.
    /// `.timeline` plays an arbitrary sequence of preset changes.
    /// Default is `.timeline` with an airy opening that settles into
    /// a slightly roomier chaos resting state.
    var schedulerMode: PhysicsSchedulerMode = .timeline
    /// Opening preset key (built-in name like "deepSea" or "custom:<UUID>").
    var simpleOpeningPresetKey: String = GraphOverlayPhysicsPolicy.openingPresetKey
    /// Delay in seconds before switching from opening → resting in simple mode.
    var simpleOpeningDelaySeconds: Double = GraphOverlayPhysicsPolicy.chaosDelaySeconds
    /// Resting preset key.
    var simpleRestingPresetKey: String = GraphOverlayPhysicsPolicy.restingPresetKey
    /// Timeline mode: ordered steps to play when the overlay opens.
    /// Default is a 2-stage constellation → chaos cycle so the
    /// graph reads as:
    /// 1. constellation (wide spacing, minimal gravity) for ~4s — lets
    ///    the topology breathe on open instead of crowding the viewport
    /// 2. chaos (still lively, but with more breathing room) — resting
    ///    state with everything visible and interactive
    var timelineSteps: [PhysicsScheduleStep] = GraphState.defaultTimelineSteps()
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
        notifyGraphRenderSettingsChanged()
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
        notifyGraphRenderSettingsChanged()
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
            Log.app.error("GraphState: failed to encode custom presets: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadCustomPresetsFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: Self.customPresetsKey) else { return }
        let decoder = JSONDecoder()
        do {
            customPhysicsPresets = try decoder.decode([CustomPhysicsPresetSnapshot].self, from: data)
        } catch {
            Log.app.error("GraphState: failed to decode custom presets: \(error.localizedDescription, privacy: .public)")
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

    // MARK: - Off-main semantic clustering (RCA-P1-012, 2026-05-13)

    /// Task handle for an in-flight async semantic-clustering compute.
    /// Used to cancel a stale compute when the user toggles or the
    /// graph topology version moves before the previous compute
    /// publishes. Owned by MainActor — never accessed from the
    /// detached compute itself.
    private var semanticClusterComputeTask: Task<Void, Never>?

    /// Async, cancellable, version-keyed entry point for the fallback
    /// semantic-clustering pipeline (RCA-P1-012 acceptance: "clustering
    /// can be toggled without beachballing or blocking graph interaction").
    ///
    /// Pipeline:
    ///   1. On MainActor — snapshot `store.nodes.values` to a Sendable
    ///      array and capture the current `graphDataVersion` as the
    ///      topology key. Capture the (Sendable) `fallbackEmbeddingLookup`.
    ///   2. Cancel any in-flight compute task (older topology — discard).
    ///   3. Spawn `Task.detached` for the heavy embedding + k-means work.
    ///   4. On detached side, run `SemanticClusterService.computeClustersFromNodes`.
    ///      Honor cooperative cancellation between embedding and k-means.
    ///   5. MainActor-hop with the result. Check the topology key again:
    ///      if `graphDataVersion` has advanced past the captured value,
    ///      discard the result silently (a newer compute is already
    ///      running). Otherwise publish: write `semanticClusterIds` and
    ///      bump `semanticClusterVersion` so MetalGraphView's pollster
    ///      picks up the new mapping.
    ///
    /// Doctrine: the topology-version discard makes concurrent calls
    /// deterministic — if the user toggles the clustering setting
    /// rapidly, only the last compute publishes its result. Beats both
    /// "drop the result of the slower compute" (timing-dependent) and
    /// "queue forever" (unbounded latency).
    func recomputeSemanticClustersAsync() {
        // Cancel any pending task so the next compute starts from a
        // clean state. Cancellation is cooperative — the detached
        // compute checks `Task.isCancelled` at the embedding /
        // k-means boundary.
        semanticClusterComputeTask?.cancel()
        semanticClusterComputeTask = nil

        // Early-out: if clustering isn't available, clear immediately
        // on MainActor — no need to leave the actor. The fast path
        // matches the legacy synchronous `computeSemanticClusters`.
        guard semanticClusteringAvailable else {
            if !semanticClusterIds.isEmpty {
                semanticClusterIds.removeAll(keepingCapacity: true)
                semanticClusterVersion += 1
            }
            return
        }

        // 1. Snapshot inputs on MainActor.
        let nodesSnapshot = Array(store.nodes.values)
        let topologyKey = graphDataVersion
        let embeddingService = self.embeddingService

        // 2 + 3. Spawn detached compute. `Task.detached` escapes the
        // MainActor isolation so the heavy embedding + k-means runs
        // on a background-priority worker thread.
        let task = Task.detached(priority: .userInitiated) { [weak self] in
            // Pull the lookup back to a Sendable local via MainActor
            // (the EmbeddingService instance is MainActor-bound).
            let lookup: any TextEmbeddingLookup = await MainActor.run {
                embeddingService.swiftFallbackEmbeddingLookupForBackground()
            }

            // Honor cancellation before the heavy work — if the user
            // already toggled off or a newer compute fired, bail.
            if Task.isCancelled { return }

            // 4. Heavy compute off-MainActor.
            let result = SemanticClusterService.computeClustersFromNodes(
                nodes: nodesSnapshot,
                embeddingLookup: lookup
            )

            // Cancellation check between heavy work and publish — if
            // we got cancelled during the long k-means iteration,
            // throw away the result.
            if Task.isCancelled { return }

            // 5. Publish on MainActor with topology-key check.
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard self.graphDataVersion == topologyKey else {
                    // Stale: a newer compute is already in flight or
                    // the topology moved. Discard this result.
                    return
                }
                self.semanticClusterIds = result
                self.semanticClusterVersion += 1
            }
        }

        semanticClusterComputeTask = task
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

        // If empty or explicitly dirty, rebuild structural data through
        // the background actor path too.
        if (needsRefresh || store.nodeCount == 0), !isBuildingStructural {
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
        if (needsRefresh || store.nodeCount == 0), !isBuildingStructural {
            buildStructuralGraph(context: context)
            return
        }
        isLoaded = true
        requestRecommit()
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
        requestRecommit()
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
        let interval = Log.ffiPerf.beginInterval("syncNodeMetadataToEngine")
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
        Log.ffiPerf.endInterval("syncNodeMetadataToEngine", interval)
    }

    // MARK: - Rust Search

    /// Search node labels via the Rust engine's FST index (sub-1ms, typo-tolerant).
    /// Falls back to Swift-side `GraphStore.fuzzySearch()` when engine isn't available.
    func rustSearch(query: String, limit: Int = 20) -> [GraphStore.SearchHit] {
        guard !query.isEmpty else { return [] }

        // Try Rust-side search via FFI
        if let engine = engineHandle {
            let interval = Log.ffiPerf.beginInterval("graph_engine_search")
            var count: UInt32 = 0
            guard let cQuery = query.cString(using: .utf8) else {
                Log.ffiPerf.endInterval("graph_engine_search", interval)
                return store.fuzzySearch(query: query, limit: limit)
            }
            let results = graph_engine_search(engine, cQuery, UInt32(limit), &count)
            Log.ffiPerf.endInterval("graph_engine_search", interval)
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
        let interval = Log.ffiPerf.beginInterval("graph_engine_search_highlight")
        if let cQuery = query.cString(using: .utf8) {
            graph_engine_search_highlight(engine, cQuery)
        }
        Log.ffiPerf.endInterval("graph_engine_search_highlight", interval)
    }

    /// Enable/disable bullet-time search physics (slow-motion drift during search).
    func setSearchActive(_ active: Bool) {
        guard let engine = engineHandle else { return }
        let interval = Log.ffiPerf.beginInterval("graph_engine_set_search_active")
        graph_engine_set_search_active(engine, active ? 1 : 0)
        Log.ffiPerf.endInterval("graph_engine_set_search_active", interval)
    }

    // MARK: - Selection

    func selectNode(_ id: String?) {
        guard selectedNodeId != id else { return }
        selectedNodeId = id
        guard let engine = engineHandle else { return }
        if let id {
            id.withCString { graph_engine_select_node(engine, $0) }
        } else {
            graph_engine_clear_selected_node(engine)
        }
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

    /// SCAFFOLD ONLY — RCA-P2-011 classification 2026-05-13.
    ///
    /// Build the page subgraph from the active note's markdown body.
    /// Wikilinks are resolved to existing graph nodes.
    ///
    /// **No production Swift caller reaches this method today.** It
    /// is reserved for future page-mode subgraph wiring (Wave 7
    /// follow-up). Lifecycle (`ephemeralNodeIds` / `ephemeralEdgeIds`
    /// cleanup on mode switch + `wikilinkLookup` rebuild per call)
    /// stays correct so the moment a UI path wires this in, the
    /// existing ephemeral-tracking + R.3 cascade behave as documented.
    ///
    /// Phase R.3 async cascade: the body read goes through the
    /// Sendable-primitive strangler-fig helper
    /// `SDPage.loadBodyAsyncFromPrimitives` so the managed sidecar
    /// remains authoritative, then the R.3 gateway is consulted before
    /// inline/raw vault-file fallback. The function is `async` to
    /// accommodate the await — no existing Swift call sites reach this
    /// method (it's reserved for future page-mode subgraph wiring), so
    /// making it async today has zero blast radius.
    func buildPageSubgraph(for pageId: String, context: ModelContext) async {
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == pageId }
        )
        let stagedFilePath: String?
        let createdAt: Date
        do {
            guard let fetchedPage = try context.fetch(descriptor).first else { return }
            stagedFilePath = fetchedPage.filePath
            createdAt = fetchedPage.createdAt
        } catch {
            Log.graph.error(
                "GraphState: failed to fetch page for page-mode subgraph \(String(pageId.prefix(8)), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return
        }
        guard let pageNodeId = store.node(bySourceId: pageId, type: .note)?.id else { return }

        let body = await SDPage.loadBodyAsyncFromPrimitives(
            pageId: pageId,
            filePath: stagedFilePath,
            mapped: true
        )
        guard !body.isEmpty else { return }
        guard let cStr = body.cString(using: .utf8) else { return }

        // Build wikilink lookup table once (O(N)) instead of O(N) per wikilink.
        wikilinkLookup.removeAll(keepingCapacity: true)
        for node in store.nodes.values where node.type == .note {
            for key in WikilinkResolver.lookupKeysForPage(
                title: node.label,
                filePath: nil
            ) {
                wikilinkLookup[key] = node
            }
        }

        var spansPtr: UnsafeMutablePointer<StyleSpan>?
        var count: UInt32 = 0
        let result = markdown_parse(cStr, UInt32(cStr.count - 1), &spansPtr, &count)
        guard result == 0, let spans = spansPtr, count > 0 else { return }
        defer { markdown_free_spans(spans, count) }

        // UTF-8 bytes for slicing by byte offset. `createdAt` was
        // staged at the top of this function so we don't need a live
        // SDPage reference here — Phase R.3 primitives-only pattern.
        let utf8Bytes: [UInt8] = Array(body.utf8)

        for i in 0..<Int(count) {
            let span = spans[i]
            let start = Int(span.start)
            let end = Int(span.end)
            guard end <= utf8Bytes.count else { continue }

            switch span.style {
            case 15: // Wikilink — resolve to existing note node and add edge
                let slice = Array(utf8Bytes[start..<end])
                guard let raw = String(bytes: slice, encoding: .utf8) else { continue }
                guard let target = WikilinkResolver.canonicalDestination(raw) else { continue }
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
        let linkedNode = WikilinkResolver.lookupKeys(forDestination: target)
            .lazy
            .compactMap { self.wikilinkLookup[$0] }
            .first
        guard let linkedNode else { return }

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

    private func persistManualGraphMutation(
        context: ModelContext,
        rollback: () -> Void
    ) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            rollback()
            Log.db.error("GraphState: context.save() failed — \(error.localizedDescription)")
            return false
        }
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
            //
            // RCA-P1-009 (2026-05-13): the placeholder SDGraphNode is
            // dropped after the page exists and `buildStructuralGraph`
            // rebuilds the canonical note-node from the SDPage. Without
            // this swap, two SDGraphNodes ended up with the same
            // `sourceId == pageId` (one manual, one structural) — the
            // duplicate the audit register flagged.
            Task { @MainActor in
                let placeholderId = sdNode.id
                guard let pageId = await AppBootstrap.shared?.vaultSync.createPage(
                    title: safeLabel,
                    allowVaultSelectionPrompt: true
                ) else {
                    context.delete(sdNode)
                    store.positionHints.removeValue(forKey: placeholderId)
                    return
                }

                swapManualPlaceholderForStructuralNoteNode(
                    placeholder: sdNode,
                    placeholderId: placeholderId,
                    placeholderPosition: position,
                    pageId: pageId,
                    danglingManualEdge: nil,
                    context: context
                )
            }
        } else {
            guard persistManualGraphMutation(
                context: context,
                rollback: {
                    context.delete(sdNode)
                    store.positionHints.removeValue(forKey: sdNode.id)
                }
            ) else {
                return
            }
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
            //
            // RCA-P1-009 (2026-05-13): swap the placeholder for the
            // structural-rebuild's canonical node and rewrite the
            // manual edge to target the canonical id. Without this,
            // the edge silently dangles to the deleted placeholder
            // ID while the user sees the structural note alongside
            // — the "stale manual edges" the audit register flagged.
            Task { @MainActor in
                let placeholderId = sdNode.id
                let danglingEdge = DanglingManualEdge(
                    sourceId: sdEdge.sourceNodeId,
                    placeholderTargetId: sdEdge.targetNodeId,
                    edge: sdEdge,
                    type: sdEdge.edgeType,
                    weight: sdEdge.weight
                )
                guard let pageId = await AppBootstrap.shared?.vaultSync.createPage(
                    title: safeLabel,
                    allowVaultSelectionPrompt: true
                ) else {
                    context.delete(sdNode)
                    context.delete(sdEdge)
                    store.positionHints.removeValue(forKey: placeholderId)
                    return
                }

                swapManualPlaceholderForStructuralNoteNode(
                    placeholder: sdNode,
                    placeholderId: placeholderId,
                    placeholderPosition: position,
                    pageId: pageId,
                    danglingManualEdge: danglingEdge,
                    context: context
                )
            }
        } else {
            guard persistManualGraphMutation(
                context: context,
                rollback: {
                    context.delete(sdNode)
                    context.delete(sdEdge)
                    store.positionHints.removeValue(forKey: sdNode.id)
                }
            ) else {
                return
            }
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

    // MARK: - RCA-P1-009 placeholder ↔ structural-node swap (2026-05-13)

    /// Pre-computed manual-edge state captured BEFORE the placeholder
    /// is deleted. The structural rebuild will mint a new SDGraphNode
    /// with a different id, so the original `SDGraphEdge` is
    /// re-created against the new node id.
    ///
    /// Not Sendable on purpose — `SDGraphEdge` is a `@Model` and
    /// can't cross actor boundaries safely. The entire swap path
    /// stays on MainActor (it's invoked inside `Task { @MainActor in
    /// … }` from the create-node paths), so the struct never leaves
    /// the actor.
    private struct DanglingManualEdge {
        let sourceId: String
        let placeholderTargetId: String
        let edge: SDGraphEdge
        let type: GraphEdgeType
        let weight: Double
    }

    /// Drop the manual placeholder SDGraphNode (and any dangling
    /// manual edge that pointed to it), rebuild the structural graph
    /// so the canonical note-node for the SDPage exists, then
    /// re-attach the position hint + manual edge against the canonical
    /// node id.
    ///
    /// Before this helper:
    ///   - Two SDGraphNodes shared the same `sourceId == pageId` —
    ///     the manual placeholder (created at click time) and the
    ///     structural rebuild's auto-generated entry.
    ///   - The manual SDGraphEdge pointed at the placeholder's UUID,
    ///     which the user couldn't see (the renderer shows the
    ///     structural node), so the edge was silently dangling.
    ///
    /// After this helper:
    ///   - One SDGraphNode per page (the structural one).
    ///   - The manual edge points at the structural node id.
    ///   - The position hint follows the structural id.
    private func swapManualPlaceholderForStructuralNoteNode(
        placeholder: SDGraphNode,
        placeholderId: String,
        placeholderPosition: SIMD2<Float>,
        pageId: String,
        danglingManualEdge: DanglingManualEdge?,
        context: ModelContext
    ) {
        // Step 1: detach the placeholder + dangling manual edge.
        context.delete(placeholder)
        if let dangling = danglingManualEdge {
            context.delete(dangling.edge)
        }
        store.positionHints.removeValue(forKey: placeholderId)

        // Step 2: rebuild structural graph so the canonical SDGraphNode
        // for the new page appears in the SwiftData store.
        buildStructuralGraph(context: context)

        // Step 3: resolve the canonical node id (the structural rebuild's
        // entry for this page) so we can re-key the position hint and
        // edge.
        let typeRaw = GraphNodeType.note.rawValue
        let descriptor = FetchDescriptor<SDGraphNode>(
            predicate: #Predicate<SDGraphNode> {
                $0.type == typeRaw && $0.sourceId == pageId && !$0.isManual
            }
        )
        let canonical: SDGraphNode?
        do {
            canonical = try context.fetch(descriptor).first
        } catch {
            Log.app.error("RCA-P1-009: failed to fetch structural node for page \(pageId): \(error.localizedDescription)")
            canonical = nil
        }
        guard let canonical else {
            // Structural rebuild didn't produce a node for this page —
            // the SDPage may have been deleted by a race, or the
            // GraphBuilder failed. Either way, nothing left to wire.
            Log.app.error("RCA-P1-009: structural rebuild did not produce a note-node for page \(pageId)")
            return
        }

        // Step 4: re-key the position hint onto the canonical id so
        // the user's click position is preserved through the swap.
        store.positionHints[canonical.id] = placeholderPosition

        // Step 5: re-create the manual edge against the canonical id
        // (if one existed).
        if let dangling = danglingManualEdge {
            let replacement = SDGraphEdge(
                source: dangling.sourceId,
                target: canonical.id,
                type: dangling.type,
                weight: dangling.weight
            )
            replacement.isManual = true
            context.insert(replacement)
        }

        // Step 6: persist the manual mutation (the new edge, if any).
        // If persist fails the rollback won't re-create the placeholder
        // (the structural node is now the canonical truth); the
        // manual edge is simply absent, which is the safe degradation.
        _ = persistManualGraphMutation(context: context, rollback: {})
        requestRecommit()
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
        guard persistManualGraphMutation(
            context: context,
            rollback: {
                context.delete(sdEdge)
            }
        ) else {
            interactionMode = .idle
            return
        }

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

/// Helper for the camera UserDefaults bootstrap. Float-valued defaults
/// where 0 isn't a sensible value: returns the configured default when
/// the key isn't present (UserDefaults.double returns 0 for missing keys,
/// which would collapse the slider to its lower bound).
nonisolated enum GraphCameraDefaults {
    static func load(key: String, defaultValue: Float) -> Float {
        let stored = UserDefaults.standard.double(forKey: key)
        if stored == 0 {
            return defaultValue
        }
        return Float(stored)
    }
}
