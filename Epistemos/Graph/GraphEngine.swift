import Metal
import QuartzCore

/// Type-safe Swift wrapper around the Rust graph engine FFI.
///
/// Owns the opaque `Engine*` pointer and provides typed Swift methods,
/// eliminating raw `withCString` / pointer / `UInt8` boilerplate at
/// every call site. Matches the C header `graph_engine.h` 1:1.
///
/// Usage:
///   let engine = GraphEngine(device: mtlDevice, layer: metalLayer)
///   engine?.addNode(uuid: id, x: 0, y: 0, nodeType: .note, linkCount: 3, label: "Title")
///   engine?.commit(entrance: true)
///   engine?.render(width: w, height: h)
///
/// Wave 2.4 – Epistemos v2 roadmap.
@MainActor
final class GraphEngine {

    // MARK: - Node Type Enum

    /// Mirrors the Rust `NodeType` enum values from graph_engine.h.
    /// 0=Note, 1=Chat, 2=Idea, 3=Source, 4=Folder, 5=Quote, 6=Tag.
    enum NodeType: UInt8 {
        case note   = 0
        case chat   = 1
        case idea   = 2
        case source = 3
        case folder = 4
        case quote  = 5
        case tag    = 6
    }

    /// Graph display mode.
    enum Mode: UInt8 {
        case global = 0
        case page   = 1
    }

    /// Center force mode.
    enum CenterMode: UInt8 {
        case attract = 0
        case off     = 1
        case repel   = 2
    }

    // MARK: - Properties

    nonisolated(unsafe) private var handle: OpaquePointer?

    /// Direct access to the opaque handle for any uncovered FFI calls.
    /// Prefer adding typed methods instead of using this directly.
    var rawHandle: OpaquePointer? { handle }

    // MARK: - Lifecycle

    /// Initialize with Metal device and layer pointers.
    /// Returns `nil` if the Rust engine fails to create.
    init?(device: MTLDevice, layer: CAMetalLayer) {
        let devicePtr = Unmanaged.passUnretained(device).toOpaque()
        let layerPtr = Unmanaged.passUnretained(layer).toOpaque()
        handle = graph_engine_create(devicePtr, layerPtr)
        guard handle != nil else { return nil }
    }

    deinit {
        if let h = handle {
            graph_engine_destroy(h)
            handle = nil
        }
    }

    // MARK: - Graph Data Loading

    /// Clear all nodes and edges. Call before re-populating.
    func clear() {
        guard let h = handle else { return }
        graph_engine_clear(h)
    }

    /// Add a node to the graph.
    /// - Parameters:
    ///   - uuid: Unique identifier string.
    ///   - x: Initial X position.
    ///   - y: Initial Y position.
    ///   - nodeType: Node type (raw UInt8 matching Rust enum).
    ///   - linkCount: Number of edges (used for radius sizing).
    ///   - label: Display label.
    func addNode(uuid: String, x: Float, y: Float, nodeType: UInt8, linkCount: UInt32, label: String) {
        guard let h = handle else { return }
        uuid.withCString { uuidPtr in
            label.withCString { labelPtr in
                graph_engine_add_node(h, uuidPtr, x, y, nodeType, linkCount, labelPtr)
            }
        }
    }

    /// Add a node using the typed `NodeType` enum.
    func addNode(uuid: String, x: Float, y: Float, nodeType: NodeType, linkCount: UInt32, label: String) {
        addNode(uuid: uuid, x: x, y: y, nodeType: nodeType.rawValue, linkCount: linkCount, label: label)
    }

    /// Add an edge between two nodes by UUID.
    /// - Parameters:
    ///   - sourceUUID: Source node UUID.
    ///   - targetUUID: Target node UUID.
    ///   - weight: Edge weight (affects force strength).
    ///   - edgeType: Edge type index (0-11, matching `GraphEdgeType.rustIndex`).
    func addEdge(sourceUUID: String, targetUUID: String, weight: Float, edgeType: UInt8 = 0) {
        guard let h = handle else { return }
        sourceUUID.withCString { srcPtr in
            targetUUID.withCString { tgtPtr in
                graph_engine_add_edge(h, srcPtr, tgtPtr, weight, edgeType)
            }
        }
    }

    /// Commit the graph: loads data into simulation, starts physics.
    /// Call after `clear()` + `addNode`/`addEdge` sequence.
    /// - Parameter entrance: When `true`, plays Obsidian-style entrance animation
    ///   (nodes start clustered at center).
    func commit(entrance: Bool) {
        guard let h = handle else { return }
        graph_engine_commit(h, entrance ? 1 : 0)
    }

    // MARK: - Rendering

    /// Render one frame.
    /// - Returns: `true` if another frame is needed, `false` if GPU can idle.
    @discardableResult
    func render(width: UInt32, height: UInt32) -> Bool {
        guard let h = handle else { return false }
        return graph_engine_render(h, width, height) != 0
    }

    // MARK: - Input Events

    /// Mouse/trackpad button pressed.
    /// - Parameters:
    ///   - x: Screen X in pixels (backing-scaled).
    ///   - y: Screen Y in pixels (backing-scaled).
    ///   - shiftHeld: When `true`, enables neighbor highlighting.
    func mouseDown(x: Float, y: Float, shiftHeld: Bool) {
        guard let h = handle else { return }
        graph_engine_mouse_down(h, x, y, shiftHeld ? 1 : 0)
    }

    /// Mouse/trackpad moved.
    func mouseMoved(x: Float, y: Float) {
        guard let h = handle else { return }
        graph_engine_mouse_moved(h, x, y)
    }

    /// Mouse/trackpad button released.
    func mouseUp() {
        guard let h = handle else { return }
        graph_engine_mouse_up(h)
    }

    /// Two-finger scroll: pan the camera.
    func scroll(deltaX: Float, deltaY: Float) {
        guard let h = handle else { return }
        graph_engine_scroll(h, deltaX, deltaY)
    }

    /// Pinch-to-zoom toward cursor position.
    func magnify(screenX: Float, screenY: Float, magnification: Float) {
        guard let h = handle else { return }
        graph_engine_magnify(h, screenX, screenY, magnification)
    }

    // MARK: - Force Parameters

    /// Update the 4 user-adjustable force parameters and reheat.
    func setForceParams(
        linkDistance: Float,
        chargeStrength: Float,
        chargeRange: Float,
        linkStrength: Float
    ) {
        guard let h = handle else { return }
        graph_engine_set_force_params(h, linkDistance, chargeStrength, chargeRange, linkStrength)
    }

    /// Update extended physics parameters (velocity decay, center gravity, collision).
    func setExtendedForceParams(
        velocityDecay: Float,
        centerStrength: Float,
        collisionRadius: Float
    ) {
        guard let h = handle else { return }
        graph_engine_set_extended_force_params(h, velocityDecay, centerStrength, collisionRadius)
    }

    // MARK: - Highlighting

    /// Highlight a node and its neighbors (shift+click behavior).
    func highlightNeighbors(uuid: String) {
        guard let h = handle else { return }
        uuid.withCString { graph_engine_highlight_neighbors(h, $0) }
    }

    /// Clear neighbor highlighting.
    func clearHighlight() {
        guard let h = handle else { return }
        graph_engine_clear_highlight(h)
    }

    /// Highlight nodes matching a search query (case-insensitive label match).
    /// Pass an empty string to clear the search highlight.
    func searchHighlight(query: String) {
        guard let h = handle else { return }
        query.withCString { graph_engine_search_highlight(h, $0) }
    }

    // MARK: - Camera

    /// Animate camera to center on all visible nodes.
    func centerCamera() {
        guard let h = handle else { return }
        graph_engine_center_camera(h)
    }

    /// Center camera on a specific node by UUID (zooms in moderately).
    func centerOnNode(uuid: String) {
        guard let h = handle else { return }
        uuid.withCString { graph_engine_center_on_node(h, $0) }
    }

    /// Zoom to fit all visible nodes.
    func zoomToFit() {
        guard let h = handle else { return }
        graph_engine_zoom_to_fit(h)
    }

    // MARK: - Lifecycle Control

    /// Pause the engine: stop physics thread to free CPU.
    func pause() {
        guard let h = handle else { return }
        graph_engine_pause(h)
    }

    /// Resume the engine: restart physics thread.
    func resume() {
        guard let h = handle else { return }
        graph_engine_resume(h)
    }

    // MARK: - Cluster Parameters

    /// Set cluster cohesion strength (0 = off, 1 = strong bubbles).
    func setClusterParams(clusterStrength: Float) {
        guard let h = handle else { return }
        graph_engine_set_cluster_params(h, clusterStrength)
    }

    /// Set center force mode.
    func setCenterMode(_ mode: CenterMode) {
        guard let h = handle else { return }
        graph_engine_set_center_mode(h, mode.rawValue)
    }

    /// Set center force mode using a raw UInt8 value.
    func setCenterMode(_ mode: UInt8) {
        guard let h = handle else { return }
        graph_engine_set_center_mode(h, mode)
    }

    // MARK: - Coordinate Conversion

    /// Convert screen pixel coordinates to world coordinates.
    func screenToWorld(screenX: Float, screenY: Float) -> SIMD2<Float> {
        guard let h = handle else { return .zero }
        var wx: Float = 0, wy: Float = 0
        graph_engine_screen_to_world(h, screenX, screenY, &wx, &wy)
        return SIMD2(wx, wy)
    }

    // MARK: - Visibility (Lightweight Filtering)

    /// Toggle a node's visibility by UUID.
    /// Call `refreshVisibility()` once after all toggles.
    func setNodeVisible(uuid: String, visible: Bool) {
        guard let h = handle else { return }
        uuid.withCString { graph_engine_set_node_visible(h, $0, visible ? 1 : 0) }
    }

    /// Apply visibility changes: re-upload renderer + reload simulation.
    func refreshVisibility() {
        guard let h = handle else { return }
        graph_engine_refresh_visibility(h)
    }

    // MARK: - Display Settings

    /// Set the clear color (use transparent `(0,0,0,0)` for hologram overlay).
    func setClearColor(r: Double, g: Double, b: Double, a: Double) {
        guard let h = handle else { return }
        graph_engine_set_clear_color(h, r, g, b, a)
    }

    /// Set light mode (darker node colors for light backgrounds).
    func setLightMode(_ enabled: Bool) {
        guard let h = handle else { return }
        graph_engine_set_light_mode(h, enabled ? 1 : 0)
    }

    /// Set graph display mode (global or page).
    func setMode(_ mode: Mode) {
        guard let h = handle else { return }
        graph_engine_set_mode(h, mode.rawValue)
    }

    /// Set graph display mode using a raw UInt8 value.
    func setMode(_ mode: UInt8) {
        guard let h = handle else { return }
        graph_engine_set_mode(h, mode)
    }

    /// Set the note window rect in screen pixels for page mode anchor positioning.
    func setAnchorRect(x: Float, y: Float, width: Float, height: Float) {
        guard let h = handle else { return }
        graph_engine_set_anchor_rect(h, x, y, width, height)
    }

    // MARK: - Queries

    /// UUID of the currently hovered node, or `nil` if none.
    var hoveredNodeUUID: String? {
        guard let h = handle else { return nil }
        guard let ptr = graph_engine_hovered_node_uuid(h) else { return nil }
        return String(cString: ptr)
    }

    /// UUID of the currently selected node, or `nil` if none.
    var selectedNodeUUID: String? {
        guard let h = handle else { return nil }
        guard let ptr = graph_engine_selected_node_uuid(h) else { return nil }
        return String(cString: ptr)
    }

    /// Whether the simulation has settled (no movement).
    var isSettled: Bool {
        guard let h = handle else { return true }
        return graph_engine_is_settled(h) != 0
    }

    // MARK: - Search

    /// A search result from the Rust FST fuzzy matcher.
    struct SearchResult {
        let uuid: String
        let label: String
        let nodeType: UInt8
        let score: Float
    }

    /// Fuzzy search node labels via the Rust FST index.
    /// The index is built during `commit()`, so results reflect the last committed graph.
    func search(query: String, limit: UInt32 = 20) -> [SearchResult] {
        guard let h = handle else { return [] }
        var count: UInt32 = 0
        let resultsPtr = query.withCString { qPtr in
            graph_engine_search(h, qPtr, limit, &count)
        }
        guard let ptr = resultsPtr, count > 0 else { return [] }
        defer { graph_engine_free_search_results(ptr, count) }

        var results: [SearchResult] = []
        for i in 0..<Int(count) {
            let r = ptr[i]
            let uuid = r.uuid.map { String(cString: $0) } ?? ""
            let label = r.label.map { String(cString: $0) } ?? ""
            results.append(SearchResult(uuid: uuid, label: label, nodeType: r.node_type, score: r.score))
        }
        return results
    }

    // MARK: - Semantic Clustering

    /// Override Louvain-detected cluster IDs with semantic cluster IDs from Swift.
    /// The existing force_cluster() will use these IDs to pull similar nodes together.
    func setClusterIds(_ clusterMap: [String: UInt32]) {
        guard let h = handle, !clusterMap.isEmpty else { return }

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
            ids.withUnsafeBufferPointer { idsBuf in
                graph_engine_set_cluster_ids(h, uuidBuf.baseAddress, idsBuf.baseAddress!, UInt32(uuids.count))
            }
        }
    }
}
