//
//  MetalSimulationRenderer.swift
//  Simulation Mode S4 — MTKView delegate driving the bit-perfect
//  companion render pipeline.
//
//  Per DOCTRINE I-15:
//   - Pre-compiled pipeline state (no main-thread compile per-frame)
//   - No `AnyView` / `[String: Any]` / string-keyed dispatch
//   - No allocation in `draw(in:)` — buffers are persistent
//
//  Per DOCTRINE I-16 (bit-perfect for pixel-art categories):
//   - Sampler is `.nearest` min/mag, `.notMipmapped`
//   - View `sampleCount = 1` (MSAA off)
//   - Pixel format `.bgra8Unorm` (NOT `_srgb`)
//   - Halo / eye-bloom are SEPARATE additive-blend draws
//   - Vertex shader snaps positions to physical pixels
//
//  Per DOCTRINE §12 budgets:
//   - `theater.frame` interval ≤ 5ms p99
//   - Idle: zero draws when ring drained 0 entries
//

import AppKit
import Foundation
import Metal
import MetalKit
import OSLog

public final class MetalSimulationRenderer: NSObject, MTKViewDelegate {

    // MARK: - Configuration

    /// Physical scene-space size of one unit at 1× scale. The
    /// placeholder companions are 64-pixel quads so they're
    /// visible at default sizing; S10 replaces this with the
    /// real atlas's per-head-shape pixel dimensions.
    private static let baseQuadSize: Float = 64.0

    // MARK: - Persistent GPU state

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let bodyPipelineState: MTLRenderPipelineState
    private let haloPipelineState: MTLRenderPipelineState
    private let spriteSampler: MTLSamplerState
    private let bridge: DeltaRingBridge

    /// Quad geometry — 4 vertices, 6 indices. Persistent for
    /// the renderer's lifetime; never reallocated.
    private let quadVertices: MTLBuffer
    private let quadIndices: MTLBuffer

    /// Per-frame Camera uniforms. Allocated once; updated in
    /// `mtkView(_:drawableSizeWillChange:)`.
    private let cameraBuffer: MTLBuffer

    private weak var view: MTKView?

    // MARK: - Init

    public init(view: MTKView, bridge: DeltaRingBridge) throws {
        guard let device = view.device else {
            throw MetalRendererError.deviceUnavailable
        }
        guard let queue = device.makeCommandQueue() else {
            throw MetalRendererError.commandQueueFailed
        }
        queue.label = "Simulation.CommandQueue"

        // I-16 view configuration. Configure BEFORE building
        // pipelines so `view.colorPixelFormat` is bound to the
        // pipeline state correctly.
        view.colorPixelFormat = .bgra8Unorm        // I-16 (no _srgb)
        view.framebufferOnly = true
        view.sampleCount = 1                       // I-16 (MSAA off)
        view.preferredFramesPerSecond = 120
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        // Theater stage background — deep indigo per the Hermes
        // landing-ritual base layer (DOCTRINE §8.2.2 Phase 0).
        // S4 reuses it as the default theater backdrop; S5+
        // overrides per placement.
        view.clearColor = MTLClearColor(red: 0.04, green: 0.04, blue: 0.12, alpha: 1.0)

        self.device = device
        self.commandQueue = queue
        self.bridge = bridge

        // Sampler — bit-perfect.
        self.spriteSampler = try PipelineArchive.makeSpriteSampler(device: device)

        // Pipelines — pre-compiled in init, never on the
        // per-frame path.
        let library = try PipelineArchive.loadLibrary(device: device)
        self.bodyPipelineState = try PipelineArchive.makeBodyPipeline(
            device: device, library: library, view: view
        )
        self.haloPipelineState = try PipelineArchive.makeHaloPipeline(
            device: device, library: library, view: view
        )

        // Persistent quad geometry.
        let verts: [Float] = [
            -0.5, -0.5,
             0.5, -0.5,
             0.5,  0.5,
            -0.5,  0.5,
        ]
        let idx: [UInt16] = [0, 1, 2, 0, 2, 3]
        guard let v = device.makeBuffer(
            bytes: verts,
            length: MemoryLayout<Float>.stride * verts.count,
            options: []
        ) else { throw MetalRendererError.pipelineStateFailed("Simulation.QuadVertices",
            NSError(domain: "Sim", code: -1)) }
        guard let i = device.makeBuffer(
            bytes: idx,
            length: MemoryLayout<UInt16>.stride * idx.count,
            options: []
        ) else { throw MetalRendererError.pipelineStateFailed("Simulation.QuadIndices",
            NSError(domain: "Sim", code: -1)) }
        v.label = "Simulation.QuadVertices"
        i.label = "Simulation.QuadIndices"
        self.quadVertices = v
        self.quadIndices = i

        // Persistent Camera uniform — 32-byte buffer (24 bytes
        // used + 8 padding for 16-byte align).
        let cameraSize = MemoryLayout<CameraUniforms>.stride
        guard let camera = device.makeBuffer(
            length: cameraSize, options: [.storageModeShared]
        ) else { throw MetalRendererError.pipelineStateFailed("Simulation.Camera",
            NSError(domain: "Sim", code: -1)) }
        camera.label = "Simulation.Camera"
        self.cameraBuffer = camera

        super.init()
        self.view = view
        view.delegate = self
        // Initialise camera with the current drawable size so
        // the very first frame has a valid viewport.
        self.updateCamera(size: view.drawableSize, density: Self.backingScale(of: view))
    }

    /// macOS pixel density. NSView / MTKView don't have a
    /// `contentScaleFactor` (that's a UIKit-only property).
    /// Prefer the hosting window's backing scale, falling back
    /// to the layer's contents scale, then NSScreen, then 1.0.
    private static func backingScale(of view: MTKView) -> Float {
        if let window = view.window {
            return Float(window.backingScaleFactor)
        }
        if let layerScale = view.layer?.contentsScale {
            return Float(layerScale)
        }
        if let screenScale = NSScreen.main?.backingScaleFactor {
            return Float(screenScale)
        }
        return 1.0
    }

    // MARK: - MTKViewDelegate

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let density = Self.backingScale(of: view)
        self.updateCamera(size: size, density: density)
    }

    public func draw(in view: MTKView) {
        let count = bridge.drain()
        // DOCTRINE §12 idle: zero draws when no events queued.
        guard count > 0 else { return }

        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else { return }
        commandBuffer.label = "Simulation.Frame"

        signpostInterval(SimSignpost.theater, "frame") {
            guard let encoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: descriptor
            ) else { return }
            encoder.label = "Simulation.Encoder"

            // Body pass.
            encoder.setRenderPipelineState(bodyPipelineState)
            encoder.setVertexBuffer(quadVertices, offset: 0, index: 0)
            encoder.setVertexBuffer(bridge.instanceBuffer, offset: 0, index: 1)
            encoder.setVertexBuffer(cameraBuffer, offset: 0, index: 2)
            encoder.setFragmentSamplerState(spriteSampler, index: 0)
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: 6,
                indexType: .uint16,
                indexBuffer: quadIndices,
                indexBufferOffset: 0,
                instanceCount: count
            )

            // Halo pass — separate additive-blend draw per
            // DOCTRINE §5.7 + I-16. The halo fragment gates
            // visibility on the `STATE_FLAG_ACTIVE_HALO` bit,
            // so emitting one halo per instance is correct
            // even for inactive companions (they output
            // alpha 0 → additive contributes nothing).
            encoder.setRenderPipelineState(haloPipelineState)
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: 6,
                indexType: .uint16,
                indexBuffer: quadIndices,
                indexBufferOffset: 0,
                instanceCount: count
            )

            encoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Camera

    /// Camera uniform buffer layout. Mirrors `Companion.metal`'s
    /// `Camera` struct exactly:
    ///
    ///   float2 viewport_size  (offset 0,  size 8, align 8)
    ///   float  pixel_density  (offset 8,  size 4)
    ///   float  _pad           (offset 12, size 4)
    ///   float2 view_offset    (offset 16, size 8, align 8)
    ///
    /// Total: 24 bytes. Stride rounds up to 32 for 16-byte
    /// alignment of any subsequent constant slot.
    private struct CameraUniforms {
        var viewportSize: (Float, Float)
        var pixelDensity: Float
        var pad: Float
        var viewOffset: (Float, Float)
    }

    private func updateCamera(size: CGSize, density: Float) {
        var u = CameraUniforms(
            viewportSize: (Float(size.width), Float(size.height)),
            pixelDensity: density > 0 ? density : 1.0,
            pad: 0,
            viewOffset: (0, 0)
        )
        let length = MemoryLayout<CameraUniforms>.size
        memcpy(cameraBuffer.contents(), &u, length)
    }
}
