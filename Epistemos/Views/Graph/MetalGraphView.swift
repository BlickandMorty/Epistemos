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
}
