import Foundation
import Metal
import Observation
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

    /// Poll haptic event flag: 0=None, 1=Light snap, 2=Heavy collision.
    func pollHaptic() -> UInt8 {
        guard let h = handle else { return 0 }
        return graph_engine_poll_haptic(h)
    }

    /// Enable/disable bullet-time search physics.
    func setSearchActive(_ active: Bool) {
        guard let h = handle else { return }
        graph_engine_set_search_active(h, active ? 1 : 0)
    }

    /// Update laboratory physics toggles and tuning knobs.
    func setLabParams(
        enableFluid: Bool, enableTorsion: Bool,
        enableElastic: Bool,
        fluidViscosity: Float, edgeElasticity: Float,
        torsionRigidity: Float, boidsCohesion: Float,
        windX: Float, windY: Float,
        enableOrbital: Bool, orbitalSpeed: Float
    ) {
        guard let h = handle else { return }
        graph_engine_set_lab_params(
            h,
            enableFluid ? 1 : 0,
            enableTorsion ? 1 : 0,
            enableElastic ? 1 : 0,
            0, // tension coloring removed — FFI slot kept for Rust ABI compatibility
            fluidViscosity, edgeElasticity,
            torsionRigidity, boidsCohesion,
            windX, windY,
            enableOrbital ? 1 : 0,
            orbitalSpeed
        )
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

    /// Whether physics is completely disabled (static layout for large graphs > 1500 nodes).
    var isStaticLayout: Bool {
        guard let h = handle else { return false }
        return graph_engine_is_static_layout(h) != 0
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

extension GraphEngine {
    enum BTKSubscriptionKind: UInt8, Sendable {
        case outline = 0
        case property = 1
        case links = 2
    }

    struct BTKSubscriptionRow: Equatable, Sendable {
        let pageId: String
        let blockId: String
        let parentId: String
        let targetId: String
        let content: String
        let propertyKey: String
        let propertyValue: String
        let taskMarker: String
        let orderKey: String
        let depth: UInt16
        let refType: UInt8
        let taskDone: Bool
        let hopCount: UInt8

        var identity: String {
            [
                pageId,
                blockId,
                parentId,
                targetId,
                propertyKey,
                String(hopCount),
            ].joined(separator: "|")
        }
    }

    struct BTKSubscriptionPayload: Equatable, Sendable {
        let version: UInt64
        let kind: BTKSubscriptionKind
        let added: [BTKSubscriptionRow]
        let updated: [BTKSubscriptionRow]
        let removed: [BTKSubscriptionRow]
    }

    func btkSubscribeOutline(pageId: String) -> UInt64? {
        guard let h = handle else { return nil }
        let id = pageId.withCString { graph_engine_btk_subscribe_outline(h, $0) }
        return id == 0 ? nil : id
    }

    func btkSubscribeProperty(key: String, value: String? = nil) -> UInt64? {
        guard let h = handle else { return nil }
        let id = key.withCString { keyPtr in
            if let value {
                return value.withCString { valuePtr in
                    graph_engine_btk_subscribe_property(h, keyPtr, valuePtr)
                }
            } else {
                return graph_engine_btk_subscribe_property(h, keyPtr, nil)
            }
        }
        return id == 0 ? nil : id
    }

    func btkSubscribeLinks(blockId: String, maxDepth: UInt8) -> UInt64? {
        guard let h = handle else { return nil }
        let id = blockId.withCString { graph_engine_btk_subscribe_links(h, $0, maxDepth) }
        return id == 0 ? nil : id
    }

    @discardableResult
    func btkUnsubscribe(id: UInt64) -> Bool {
        guard let h = handle else { return false }
        return graph_engine_btk_unsubscribe(h, id) != 0
    }

    func btkTakeSubscriptionUpdate(id: UInt64) -> BTKSubscriptionPayload? {
        guard let h = handle else { return nil }
        return decodeBTKPayload(buffer: graph_engine_btk_take_subscription_update(h, id))
    }

    func btkSnapshotSubscription(id: UInt64, version: UInt64) -> BTKSubscriptionPayload? {
        guard let h = handle else { return nil }
        return decodeBTKPayload(
            buffer: graph_engine_btk_snapshot_subscription(h, id, version)
        )
    }

    var btkLatestSubscriptionSeq: UInt64 {
        guard let h = handle else { return 0 }
        return graph_engine_btk_latest_subscription_seq(h)
    }

    private func decodeBTKPayload(buffer: GraphEngineByteBuffer) -> BTKSubscriptionPayload? {
        guard let data = takeBTKBuffer(buffer) else { return nil }
        return data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            let version = graph_engine_btk_payload_version(base, UInt64(bytes.count))
            let rawKind = graph_engine_btk_payload_kind(base, UInt64(bytes.count))
            guard let kind = BTKSubscriptionKind(rawValue: rawKind) else { return nil }
            let added = decodeBTKRows(section: 0, base: base, count: bytes.count)
            let updated = decodeBTKRows(section: 1, base: base, count: bytes.count)
            let removed = decodeBTKRows(section: 2, base: base, count: bytes.count)
            return BTKSubscriptionPayload(
                version: version,
                kind: kind,
                added: added,
                updated: updated,
                removed: removed
            )
        }
    }

    private func decodeBTKRows(
        section: UInt8,
        base: UnsafePointer<UInt8>,
        count: Int
    ) -> [BTKSubscriptionRow] {
        let rowCount = graph_engine_btk_payload_row_count(base, UInt64(count), section)
        guard rowCount > 0 else { return [] }

        var rows: [BTKSubscriptionRow] = []
        rows.reserveCapacity(Int(rowCount))
        for index in 0..<rowCount {
            var ffiRow = BtkSubscriptionRowFFI()
            guard graph_engine_btk_payload_row(base, UInt64(count), section, index, &ffiRow) != 0 else {
                continue
            }
            rows.append(BTKSubscriptionRow(
                pageId: decode(slice: ffiRow.page_id),
                blockId: decode(slice: ffiRow.block_id),
                parentId: decode(slice: ffiRow.parent_id),
                targetId: decode(slice: ffiRow.target_id),
                content: decode(slice: ffiRow.content),
                propertyKey: decode(slice: ffiRow.property_key),
                propertyValue: decode(slice: ffiRow.property_value),
                taskMarker: decode(slice: ffiRow.task_marker),
                orderKey: decode(slice: ffiRow.order_key),
                depth: ffiRow.depth,
                refType: ffiRow.ref_type,
                taskDone: ffiRow.task_done != 0,
                hopCount: ffiRow.hop_count
            ))
        }
        return rows
    }

    private func takeBTKBuffer(_ buffer: GraphEngineByteBuffer) -> Data? {
        guard let ptr = buffer.ptr, buffer.len > 0 else {
            if buffer.capacity > 0 {
                graph_engine_free_bytes(buffer)
            }
            return nil
        }
        return Data(
            bytesNoCopy: ptr,
            count: Int(buffer.len),
            deallocator: .custom { _, _ in
                graph_engine_free_bytes(buffer)
            }
        )
    }

    private func decode(slice: GraphEngineStringSlice) -> String {
        guard let ptr = slice.ptr, slice.len > 0 else { return "" }
        let buffer = UnsafeBufferPointer(start: ptr, count: Int(slice.len))
        return String(decoding: buffer, as: UTF8.self)
    }
}

@MainActor
@Observable
final class BTKSubscriptionState {
    private let engine: GraphEngine
    private let subscriptionId: UInt64
    private var rowMap: [String: GraphEngine.BTKSubscriptionRow]

    private(set) var version: UInt64
    private(set) var kind: GraphEngine.BTKSubscriptionKind
    private(set) var rows: [GraphEngine.BTKSubscriptionRow]

    private var pollTask: Task<Void, Never>?

    init?(engine: GraphEngine, outlinePageId: String) {
        guard let subscriptionId = engine.btkSubscribeOutline(pageId: outlinePageId),
              let initial = engine.btkTakeSubscriptionUpdate(id: subscriptionId) else {
            return nil
        }
        self.engine = engine
        self.subscriptionId = subscriptionId
        self.version = initial.version
        self.kind = initial.kind
        self.rowMap = Dictionary(uniqueKeysWithValues: initial.added.map { ($0.identity, $0) })
        self.rows = initial.added.sorted { $0.identity < $1.identity }
    }

    init?(engine: GraphEngine, propertyKey: String, propertyValue: String? = nil) {
        guard let subscriptionId = engine.btkSubscribeProperty(key: propertyKey, value: propertyValue),
              let initial = engine.btkTakeSubscriptionUpdate(id: subscriptionId) else {
            return nil
        }
        self.engine = engine
        self.subscriptionId = subscriptionId
        self.version = initial.version
        self.kind = initial.kind
        self.rowMap = Dictionary(uniqueKeysWithValues: initial.added.map { ($0.identity, $0) })
        self.rows = initial.added.sorted { $0.identity < $1.identity }
    }

    init?(engine: GraphEngine, linkedBlockId: String, maxDepth: UInt8) {
        guard let subscriptionId = engine.btkSubscribeLinks(blockId: linkedBlockId, maxDepth: maxDepth),
              let initial = engine.btkTakeSubscriptionUpdate(id: subscriptionId) else {
            return nil
        }
        self.engine = engine
        self.subscriptionId = subscriptionId
        self.version = initial.version
        self.kind = initial.kind
        self.rowMap = Dictionary(uniqueKeysWithValues: initial.added.map { ($0.identity, $0) })
        self.rows = initial.added.sorted { $0.identity < $1.identity }
    }

    func startPolling(interval: Duration = .milliseconds(150)) {
        stopPolling()
        pollTask = Task(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                self?.pollNow()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func pollNow() {
        guard let payload = engine.btkTakeSubscriptionUpdate(id: subscriptionId) else { return }
        apply(payload)
    }

    func snapshot(at version: UInt64) -> GraphEngine.BTKSubscriptionPayload? {
        engine.btkSnapshotSubscription(id: subscriptionId, version: version)
    }

    func close() {
        stopPolling()
        _ = engine.btkUnsubscribe(id: subscriptionId)
    }

    private func apply(_ payload: GraphEngine.BTKSubscriptionPayload) {
        for row in payload.removed {
            rowMap.removeValue(forKey: row.identity)
        }
        for row in payload.added {
            rowMap[row.identity] = row
        }
        for row in payload.updated {
            rowMap[row.identity] = row
        }
        version = payload.version
        kind = payload.kind
        rows = rowMap.values.sorted { $0.identity < $1.identity }
    }
}
