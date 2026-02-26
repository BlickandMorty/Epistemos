import SwiftUI
import MetalKit

struct MetalGraphView: NSViewRepresentable {
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

    func updateNSView(_ nsView: GraphMTKView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MTKViewDelegate {
        /// Raw pointer to the Rust GraphEngine. C FFI uses void* (UnsafeMutableRawPointer).
        /// nonisolated(unsafe) because deinit needs to access this to free the engine.
        nonisolated(unsafe) var engine: UnsafeMutableRawPointer?

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

        if event.modifierFlags.contains(.option) || event.momentumPhase != [] {
            // Option+scroll or momentum = pan
            graph_engine_pan(engine, Float(event.scrollingDeltaX), Float(event.scrollingDeltaY))
        } else {
            // Regular scroll = pan
            graph_engine_pan(engine, Float(event.scrollingDeltaX), Float(event.scrollingDeltaY))
        }
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
