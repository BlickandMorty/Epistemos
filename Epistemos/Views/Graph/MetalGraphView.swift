import SwiftUI
import MetalKit

struct MetalGraphView: NSViewRepresentable {
    let graphState: GraphState

    func makeNSView(context: Context) -> GraphMTKView {
        let view = GraphMTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 60
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
        return view
    }

    func updateNSView(_ nsView: GraphMTKView, context: Context) {
        // Push graph data to Rust engine when store is loaded and engine is ready
        let coordinator = context.coordinator
        if graphState.isLoaded, !coordinator.hasLoadedData, let engine = coordinator.engine {
            coordinator.loadGraphData(engine: engine, store: graphState.store)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MTKViewDelegate {
        /// Raw pointer to the Rust GraphEngine. C FFI uses void* (UnsafeMutableRawPointer).
        /// nonisolated(unsafe) because deinit needs to access this to free the engine.
        nonisolated(unsafe) var engine: UnsafeMutableRawPointer?
        var hasLoadedData = false

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            if let engine {
                graph_engine_resize(engine, UInt32(size.width), UInt32(size.height))
            }
        }

        func draw(in view: MTKView) {
            // Create engine lazily on first draw when Metal device is guaranteed available
            if engine == nil, let device = view.device,
               let layer = view.layer as? CAMetalLayer {
                let devicePtr = Unmanaged.passUnretained(device).toOpaque()
                let layerPtr = Unmanaged.passUnretained(layer).toOpaque()
                engine = graph_engine_create(devicePtr, layerPtr)

                let size = view.drawableSize
                graph_engine_resize(engine, UInt32(size.width), UInt32(size.height))
            }

            if let engine {
                graph_engine_render(engine)
            }
        }

        // MARK: - Data Loading

        /// Push graph data from the Swift GraphStore into the Rust engine via C FFI.
        @MainActor
        func loadGraphData(engine: UnsafeMutableRawPointer, store: GraphStore) {
            graph_engine_clear(engine)

            // Map GraphNodeType → Rust u8
            let nodeTypeToU8: [GraphNodeType: UInt8] = [
                .note: 0, .folder: 1, .idea: 2, .brainDump: 3, .chat: 4,
                .insight: 5, .thinker: 6, .paper: 7, .book: 8, .source: 9,
                .concept: 10, .tag: 11, .quote: 12,
            ]

            // Build CNode array
            let nodes = Array(store.nodes.values)
            var cNodes: [CNode] = []
            // Keep string buffers alive until after the FFI call
            var nodeStrings: [(uuid: [CChar], label: [CChar])] = []

            for node in nodes {
                let uuidChars = Array(node.id.utf8CString)
                let labelChars = Array(node.label.utf8CString)
                nodeStrings.append((uuid: uuidChars, label: labelChars))
            }

            for i in 0..<nodes.count {
                let node = nodes[i]
                let cNode = nodeStrings[i].uuid.withUnsafeBufferPointer { uuidBuf in
                    nodeStrings[i].label.withUnsafeBufferPointer { labelBuf in
                        CNode(
                            uuid: uuidBuf.baseAddress,
                            x: node.position.x,
                            y: node.position.y,
                            node_type: nodeTypeToU8[node.type] ?? 0,
                            weight: Float(node.weight),
                            label: labelBuf.baseAddress
                        )
                    }
                }
                cNodes.append(cNode)
            }

            // Send nodes to Rust
            cNodes.withUnsafeBufferPointer { buf in
                if let ptr = buf.baseAddress {
                    graph_engine_add_nodes(engine, ptr, buf.count)
                }
            }

            // Build CEdge array
            let edges = Array(store.edges.values)
            var cEdges: [CEdge] = []
            var edgeStrings: [(source: [CChar], target: [CChar])] = []

            for edge in edges {
                let sourceChars = Array(edge.sourceNodeId.utf8CString)
                let targetChars = Array(edge.targetNodeId.utf8CString)
                edgeStrings.append((source: sourceChars, target: targetChars))
            }

            for i in 0..<edges.count {
                let edge = edges[i]
                let cEdge = edgeStrings[i].source.withUnsafeBufferPointer { srcBuf in
                    edgeStrings[i].target.withUnsafeBufferPointer { tgtBuf in
                        CEdge(
                            source_uuid: srcBuf.baseAddress,
                            target_uuid: tgtBuf.baseAddress,
                            edge_type: 0, // Edge type not critical for rendering
                            weight: Float(edge.weight)
                        )
                    }
                }
                cEdges.append(cEdge)
            }

            // Send edges to Rust
            cEdges.withUnsafeBufferPointer { buf in
                if let ptr = buf.baseAddress {
                    graph_engine_add_edges(engine, ptr, buf.count)
                }
            }

            // Commit — triggers circular layout + starts physics thread
            graph_engine_commit(engine)
            hasLoadedData = true

            let nc = graph_engine_node_count(engine)
            let ec = graph_engine_edge_count(engine)
            Log.app.info("MetalGraphView: loaded \(nc) nodes, \(ec) edges into Rust engine")
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

    // MARK: - Mouse drag to pan

    private var isDragging = false
    private var lastDragPoint: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        lastDragPoint = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let engine else { return }
        let point = convert(event.locationInWindow, from: nil)
        let dx = Float(point.x - lastDragPoint.x)
        let dy = Float(point.y - lastDragPoint.y)
        graph_engine_pan(engine, dx, -dy) // Flip Y: AppKit Y is up, our viewport Y is down
        lastDragPoint = point
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
    }
}
