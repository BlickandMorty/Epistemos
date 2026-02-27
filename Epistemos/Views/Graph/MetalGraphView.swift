import SwiftUI
import MetalKit

struct MetalGraphView: NSViewRepresentable {
    let graphState: GraphState

    func makeNSView(context: Context) -> GraphMTKView {
        let view = GraphMTKView()
        guard let device = MTLCreateSystemDefaultDevice() else { return view }
        view.device = device
        view.delegate = context.coordinator
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 60
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)

        // Create engine eagerly on main thread — avoids race between draw() and updateNSView()
        if let layer = view.layer as? CAMetalLayer {
            let devicePtr = Unmanaged.passUnretained(device).toOpaque()
            let layerPtr = Unmanaged.passUnretained(layer).toOpaque()
            context.coordinator.engine = graph_engine_create(devicePtr, layerPtr)
        }

        // Register Rust→Swift callbacks using Coordinator as context
        if let engine = context.coordinator.engine {
            let ctx = Unmanaged.passUnretained(context.coordinator).toOpaque()

            graph_engine_set_on_node_selected(engine, { (uuid: UnsafePointer<CChar>?, ctx: UnsafeMutableRawPointer?) in
                guard let ctx else { return }
                let coord = Unmanaged<MetalGraphView.Coordinator>.fromOpaque(ctx).takeUnretainedValue()
                let id: String? = uuid != nil ? String(cString: uuid!) : nil
                DispatchQueue.main.async { coord.handleNodeSelected(id) }
            }, ctx)

            graph_engine_set_on_node_right_clicked(engine, { (uuid: UnsafePointer<CChar>?, sx: Float, sy: Float, ctx: UnsafeMutableRawPointer?) in
                guard let ctx, let uuid else { return }
                let coord = Unmanaged<MetalGraphView.Coordinator>.fromOpaque(ctx).takeUnretainedValue()
                let id = String(cString: uuid)
                DispatchQueue.main.async { coord.handleRightClick(id, screenX: CGFloat(sx), screenY: CGFloat(sy)) }
            }, ctx)

            graph_engine_set_on_node_hovered(engine, { (uuid: UnsafePointer<CChar>?, ctx: UnsafeMutableRawPointer?) in
                guard let ctx else { return }
                let coord = Unmanaged<MetalGraphView.Coordinator>.fromOpaque(ctx).takeUnretainedValue()
                let id: String? = uuid != nil ? String(cString: uuid!) : nil
                DispatchQueue.main.async { coord.handleHover(id) }
            }, ctx)
        }

        return view
    }

    func updateNSView(_ nsView: GraphMTKView, context: Context) {
        let coordinator = context.coordinator

        // Resize on layout changes
        if let engine = coordinator.engine {
            let size = nsView.drawableSize
            if size.width > 0, size.height > 0 {
                graph_engine_resize(engine, UInt32(size.width), UInt32(size.height))
            }
        }

        // Push graph data to Rust engine when store is loaded and engine is ready
        if graphState.isLoaded, !coordinator.hasLoadedData, let engine = coordinator.engine {
            coordinator.loadGraphData(engine: engine, store: graphState.store)
            coordinator.wake(nsView)   // Fresh data loaded → resume rendering
        }

        // Push visibility bitmask when filter state changes
        if coordinator.hasLoadedData, let engine = coordinator.engine {
            let currentHash = graphState.filter.activeNodeTypes.hashValue
                ^ (graphState.filter.focusedNodeId?.hashValue ?? 0)
                ^ graphState.filter.hiddenNodeIds.hashValue
                ^ (graphState.filter.timelineDate?.hashValue ?? 0)
            if currentHash != coordinator.lastFilterHash {
                coordinator.lastFilterHash = currentHash
                coordinator.pushVisibility(engine: engine, filter: graphState.filter, store: graphState.store)
                coordinator.wake(nsView)   // Visibility changed → resume rendering
            }
        }

        // Push physics config when sliders change
        if coordinator.hasLoadedData, let engine = coordinator.engine {
            let version = graphState.physicsConfigVersion
            if version != coordinator.lastPhysicsConfigVersion {
                coordinator.lastPhysicsConfigVersion = version
                var cfg = CPhysicsConfig(
                    center_force: graphState.physCenterForce,
                    repel_force: graphState.physRepelForce,
                    link_force: graphState.physLinkForce,
                    link_distance: graphState.physLinkDistance,
                    velocity_decay: graphState.physVelocityDecay,
                    alpha_decay: graphState.physAlphaDecay
                )
                graph_engine_set_physics_config(engine, &cfg)
                coordinator.wake(nsView)   // Physics reheated → resume rendering
            }
        }

        // Camera commands
        if graphState.pendingResetView, let engine = coordinator.engine {
            graph_engine_reset_camera(engine)
            graphState.pendingResetView = false
            coordinator.wake(nsView)   // Camera animating → resume rendering
        }
        if let nodeId = graphState.pendingCenterNodeId, let engine = coordinator.engine {
            nodeId.withCString { ptr in
                graph_engine_center_on_node(engine, ptr)
            }
            graphState.pendingCenterNodeId = nil
            coordinator.wake(nsView)   // Camera animating → resume rendering
        }
    }

    func makeCoordinator() -> Coordinator {
        let coord = Coordinator()
        coord.graphStateRef = graphState
        return coord
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MTKViewDelegate {
        /// Raw pointer to the Rust GraphEngine.
        /// Created on main thread in makeNSView, read from display link in draw().
        /// nonisolated(unsafe) because deinit needs to free the engine.
        nonisolated(unsafe) var engine: UnsafeMutableRawPointer?
        var hasLoadedData = false
        var nodeInsertionOrder: [String] = []
        var lastFilterHash: Int = 0
        var lastPhysicsConfigVersion: Int = 0

        /// Reference to graphState for publishing selection changes.
        weak var graphStateRef: GraphState?

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            if let engine {
                graph_engine_resize(engine, UInt32(size.width), UInt32(size.height))
            }
        }

        func draw(in view: MTKView) {
            if let engine {
                let needsMore = graph_engine_render(engine)
                if needsMore == 0 {
                    // Physics settled + camera static → stop burning GPU
                    view.isPaused = true
                }
            }
        }

        /// Resume rendering — called by mouse/scroll/pinch events and config changes.
        func wake(_ view: MTKView) {
            if view.isPaused {
                view.isPaused = false
            }
        }

        // MARK: - Callback Handlers

        @MainActor
        func handleNodeSelected(_ uuid: String?) {
            graphStateRef?.selectNode(uuid)
        }

        @MainActor
        func handleRightClick(_ uuid: String, screenX: CGFloat, screenY: CGFloat) {
            // TODO: Show context menu (can be wired later)
        }

        @MainActor
        func handleHover(_ uuid: String?) {
            if uuid != nil {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }

        // MARK: - Data Loading

        /// Push graph data from the Swift GraphStore into the Rust engine via C FFI.
        /// String lifetimes are guaranteed by calling FFI inside withCString closures.
        @MainActor
        func loadGraphData(engine: UnsafeMutableRawPointer, store: GraphStore) {
            graph_engine_clear(engine)

            // Map GraphNodeType → Rust u8
            let nodeTypeToU8: [GraphNodeType: UInt8] = [
                .note: 0, .folder: 1, .idea: 2, .brainDump: 3, .chat: 4,
                .insight: 5, .thinker: 6, .paper: 7, .book: 8, .source: 9,
                .concept: 10, .tag: 11, .quote: 12,
            ]

            // Send nodes one at a time — withCString keeps pointers alive for the FFI call.
            // Capture insertion order so visibility bitmask indices match Rust's node array.
            var orderedIds: [String] = []
            for node in store.nodes.values {
                orderedIds.append(node.id)
                node.id.withCString { uuidPtr in
                    node.label.withCString { labelPtr in
                        var cNode = CNode(
                            uuid: uuidPtr,
                            x: node.position.x,
                            y: node.position.y,
                            node_type: nodeTypeToU8[node.type] ?? 0,
                            weight: Float(node.weight),
                            label: labelPtr
                        )
                        graph_engine_add_nodes(engine, &cNode, 1)
                    }
                }
            }
            nodeInsertionOrder = orderedIds

            // Send edges one at a time
            for edge in store.edges.values {
                edge.sourceNodeId.withCString { srcPtr in
                    edge.targetNodeId.withCString { tgtPtr in
                        var cEdge = CEdge(
                            source_uuid: srcPtr,
                            target_uuid: tgtPtr,
                            edge_type: 0,
                            weight: Float(edge.weight)
                        )
                        graph_engine_add_edges(engine, &cEdge, 1)
                    }
                }
            }

            // Commit — triggers circular layout + starts physics thread
            graph_engine_commit(engine)

            // Start animation to fit all nodes in view
            graph_engine_fit_all(engine)

            hasLoadedData = true

            let nc = graph_engine_node_count(engine)
            let ec = graph_engine_edge_count(engine)
            Log.app.info("MetalGraphView: loaded \(nc) nodes, \(ec) edges into Rust engine")
        }

        // MARK: - Visibility

        /// Build a uint8_t bitmask from FilterEngine state and push it to Rust.
        @MainActor
        func pushVisibility(engine: UnsafeMutableRawPointer, filter: FilterEngine, store: GraphStore) {
            guard !nodeInsertionOrder.isEmpty else { return }
            var mask = [UInt8](repeating: 0, count: nodeInsertionOrder.count)
            for (i, nodeId) in nodeInsertionOrder.enumerated() {
                if let node = store.nodes[nodeId], filter.isNodeVisible(node) {
                    mask[i] = 1
                }
            }
            mask.withUnsafeBufferPointer { ptr in
                graph_engine_set_visibility(engine, ptr.baseAddress, ptr.count)
            }
        }

        deinit {
            if let engine {
                graph_engine_destroy(engine)
            }
        }
    }
}

/// MTKView subclass that accepts first responder for trackpad/mouse events.
///
/// All coordinates sent to Rust are in **drawable pixels** (not AppKit points).
/// On retina displays, multiply point coords by `backingScaleFactor` (e.g., 2×)
/// to match the Metal shader's viewport coordinate system.
class GraphMTKView: MTKView {
    var engine: UnsafeMutableRawPointer? {
        (delegate as? MetalGraphView.Coordinator)?.engine
    }

    /// Retina scale: point × scale = drawable pixel
    private var scale: Float {
        Float(window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0)
    }

    /// Resume MTKView rendering when the user interacts.
    private func wakeRenderer() {
        if isPaused { isPaused = false }
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        window?.makeFirstResponder(self)
        wakeRenderer()
        // Force full data reload on next updateNSView (Obsidian-style fresh start)
        if let coord = delegate as? MetalGraphView.Coordinator {
            coord.hasLoadedData = false
        }
    }

    // MARK: - Tracking Areas (enables mouseMoved)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    /// Convert AppKit location (bottom-left origin, points) to Rust screen coords
    /// (top-left origin, drawable pixels). Matches Metal shader's viewport space.
    private func toDrawablePixels(_ loc: NSPoint) -> (Float, Float) {
        let s = scale
        let px = Float(loc.x) * s
        let py = Float(bounds.height - loc.y) * s  // Flip Y to top-down, then scale
        return (px, py)
    }

    // MARK: - Mouse Events

    private var isDragging = false
    /// True when the user clicked on a node → mouseDragged moves the node, not the camera.
    private var isDraggingNode = false
    private var lastDragPoint: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        guard let engine else { return }
        wakeRenderer()
        let loc = convert(event.locationInWindow, from: nil)
        let (px, py) = toDrawablePixels(loc)
        let hitNode = graph_engine_mouse_down(engine, px, py, 0)
        isDragging = false
        isDraggingNode = (hitNode != 0)
        lastDragPoint = loc
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let (px, py) = toDrawablePixels(loc)
        _ = graph_engine_mouse_down(engine, px, py, 1)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let engine else { return }
        wakeRenderer()
        let point = convert(event.locationInWindow, from: nil)
        let s = scale

        if isDraggingNode {
            // Node drag: send absolute screen position → Rust converts to world coords
            let (px, py) = toDrawablePixels(point)
            graph_engine_mouse_dragged(engine, px, py)
        } else {
            // Camera pan: delta in drawable pixels (Y flipped by negation)
            let dx = Float(point.x - lastDragPoint.x) * s
            let dy = Float(point.y - lastDragPoint.y) * s

            if !isDragging {
                if abs(dx) + abs(dy) < 3 * s { return }
                isDragging = true
            }

            graph_engine_pan(engine, dx, -dy)
        }
        lastDragPoint = point
    }

    override func mouseUp(with event: NSEvent) {
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let (px, py) = toDrawablePixels(loc)
        graph_engine_mouse_up(engine, px, py)
        isDragging = false
        isDraggingNode = false
    }

    override func mouseMoved(with event: NSEvent) {
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let (px, py) = toDrawablePixels(loc)
        graph_engine_mouse_moved(engine, px, py)
    }

    // MARK: - Scroll / Pan

    override func scrollWheel(with event: NSEvent) {
        guard let engine else { return }
        wakeRenderer()
        let s = scale
        graph_engine_pan(engine, Float(event.scrollingDeltaX) * s, Float(event.scrollingDeltaY) * s)
    }

    // MARK: - Pinch to Zoom

    override func magnify(with event: NSEvent) {
        guard let engine else { return }
        wakeRenderer()
        let loc = convert(event.locationInWindow, from: nil)
        let (px, py) = toDrawablePixels(loc)
        let factor = 1.0 + Float(event.magnification)
        graph_engine_zoom(engine, factor, px, py)
    }
}
