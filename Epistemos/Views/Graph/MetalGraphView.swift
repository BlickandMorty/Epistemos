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
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
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

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            if let engine {
                graph_engine_resize(engine, UInt32(size.width), UInt32(size.height))
            }
        }

        func draw(in view: MTKView) {
            if let engine {
                graph_engine_render(engine)
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
class GraphMTKView: MTKView {
    var engine: UnsafeMutableRawPointer? {
        (delegate as? MetalGraphView.Coordinator)?.engine
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
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

    // MARK: - Mouse Events

    private var isDragging = false
    private var lastDragPoint: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        graph_engine_mouse_down(engine, Float(loc.x), Float(bounds.height - loc.y), 0)
        isDragging = false
        lastDragPoint = loc
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        graph_engine_mouse_down(engine, Float(loc.x), Float(bounds.height - loc.y), 1)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let engine else { return }
        let point = convert(event.locationInWindow, from: nil)
        let dx = Float(point.x - lastDragPoint.x)
        let dy = Float(point.y - lastDragPoint.y)

        if !isDragging {
            if abs(dx) + abs(dy) < 3 { return }
            isDragging = true
        }

        graph_engine_pan(engine, dx, -dy)
        lastDragPoint = point
    }

    override func mouseUp(with event: NSEvent) {
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        graph_engine_mouse_up(engine, Float(loc.x), Float(bounds.height - loc.y))
        isDragging = false
    }

    override func mouseMoved(with event: NSEvent) {
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        graph_engine_mouse_moved(engine, Float(loc.x), Float(bounds.height - loc.y))
    }

    // MARK: - Scroll / Pan

    override func scrollWheel(with event: NSEvent) {
        guard let engine else { return }
        graph_engine_pan(engine, Float(event.scrollingDeltaX), Float(event.scrollingDeltaY))
    }

    // MARK: - Pinch to Zoom

    override func magnify(with event: NSEvent) {
        guard let engine else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let factor = 1.0 + Float(event.magnification)
        graph_engine_zoom(engine, factor, Float(loc.x), Float(loc.y))
    }
}
