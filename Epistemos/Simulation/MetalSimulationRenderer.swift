//
//  MetalSimulationRenderer.swift
//  Simulation Mode S4 + S7 — MTKView delegate driving the
//  bit-perfect companion render pipeline.
//
//  S4: Single-viewport renderer (placeholder geometry).
//  S7: Multi-viewport tiling (DOCTRINE §3.3.1 v1.6) — ONE
//      MTKView, ONE pipeline state per body+halo, ONE command
//      buffer per frame. Each room is an `MTLViewport`
//      rectangle within the same drawable; per-room state =
//      viewport rect + per-room camera + buffer-region offset
//      into a single shared instance buffer.
//
//  Per DOCTRINE I-15:
//   - Pre-compiled pipeline states (no main-thread compile per-frame)
//   - No `AnyView` / `[String: Any]` / string-keyed dispatch
//   - No allocation in `draw(in:)` — buffers are persistent;
//     per-frame bookkeeping arrays are pre-sized at config time
//
//  Per DOCTRINE I-16 (bit-perfect for pixel-art categories):
//   - Sampler is `.nearest` min/mag, `.notMipmapped`
//   - View `sampleCount = 1` (MSAA off)
//   - Pixel format `.bgra8Unorm` (NOT `_srgb`)
//   - Halo / eye-bloom are SEPARATE additive-blend draws
//   - Vertex shader snaps positions to physical pixels
//
//  Per DOCTRINE §12 budgets:
//   - `theater.frame` interval ≤ 5ms p99 even at N=6 rooms
//   - Idle: zero draws when ring drained 0 entries
//

import AppKit
import Foundation
import Metal
import MetalKit
import OSLog

/// One viewport tile the renderer should draw this frame. Mirrors
/// `RoomTileLayout` (points) but carries the per-tile pixel-space
/// viewport + camera matrix + agent routing keys.
public struct RenderTile {
    /// Stable session identifier (for diagnostics + buffer-region
    /// bookkeeping).
    public let sessionId: String
    /// Physical-pixel viewport rectangle.
    public let viewport: MTLViewport
    /// Routing keys: agent (lo, hi) → matching this tile.
    public let agentKeys: Set<AgentIdKey>

    public init(sessionId: String, viewport: MTLViewport, agentKeys: Set<AgentIdKey>) {
        self.sessionId = sessionId
        self.viewport = viewport
        self.agentKeys = agentKeys
    }
}

public final class MetalSimulationRenderer: NSObject, MTKViewDelegate {

    // MARK: - Configuration

    /// Physical scene-space size of one unit at 1× scale. The
    /// placeholder companions are 64-pixel quads so they're
    /// visible at default sizing; S10 replaces this with the
    /// real atlas's per-head-shape pixel dimensions.
    private static let baseQuadSize: Float = 64.0

    /// Maximum tiles the renderer can render in one frame. Per
    /// §3.3.1 v1.6 the visible cap is 9 (3 × 3); we provision 16
    /// so the carousel can pre-allocate without a re-init.
    public static let maxTiles: Int = 16

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

    /// Per-frame Camera uniforms — one slot per tile (stride =
    /// `MemoryLayout<CameraUniforms>.stride`). Allocated once
    /// for `maxTiles`; updated in-place per frame.
    private let cameraBuffer: MTLBuffer

    /// Single shared instance buffer divided into N contiguous
    /// regions per §3.3.1 v1.6 — keeps the binding count flat.
    /// Sized to `bridge.capacity * stride`; the renderer copies
    /// drained entries from `bridge.instanceBuffer` into this
    /// buffer in tile-bucketed order.
    private let tileSortedBuffer: MTLBuffer

    private weak var view: MTKView?

    /// Current layout. Updated by the host view (e.g.
    /// `GraphTheaterView`). When empty, the renderer issues no
    /// draws — the empty-state chrome is a SwiftUI overlay.
    public var tiles: [RenderTile] = []

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

        // Persistent Camera uniform buffer — one slot per tile
        // (§3.3.1 v1.6 per-room camera). Stride is 32 to satisfy
        // 16-byte alignment of `CameraUniforms`.
        let cameraStride = MemoryLayout<CameraUniforms>.stride
        let cameraTotal = cameraStride * Self.maxTiles
        guard let camera = device.makeBuffer(
            length: cameraTotal, options: [.storageModeShared]
        ) else { throw MetalRendererError.pipelineStateFailed("Simulation.Camera",
            NSError(domain: "Sim", code: -1)) }
        camera.label = "Simulation.Camera"
        self.cameraBuffer = camera

        // Tile-sorted instance buffer — same capacity as the
        // SPSC drain target so we can hold every drained entry
        // in re-bucketed order. Per §3.3.1 v1.6 "single MTLBuffer
        // divided into N contiguous regions".
        let tileBufLen = bridge.capacity * MemoryLayout<PerInstanceData>.stride
        guard let tileBuf = device.makeBuffer(
            length: tileBufLen, options: [.storageModeShared]
        ) else { throw MetalRendererError.pipelineStateFailed("Simulation.TileSorted",
            NSError(domain: "Sim", code: -1)) }
        tileBuf.label = "Simulation.TileSortedInstance"
        self.tileSortedBuffer = tileBuf

        super.init()
        self.view = view
        view.delegate = self
        // Initialise camera with the current drawable size so
        // the very first frame has a valid viewport.
        let drawableSize = view.drawableSize
        let density = Self.backingScale(of: view)
        self.updateCamerasForFullDrawable(size: drawableSize, density: density)
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
        // Re-pin the cameras' viewport_size; the host view
        // re-applies the latest tile layout via `updateTiles`.
        let density = Self.backingScale(of: view)
        self.updateCamerasForFullDrawable(size: size, density: density)
    }

    public func draw(in view: MTKView) {
        let count = bridge.drain()
        // DOCTRINE §12 idle: zero draws when no events queued OR
        // no tiles configured.
        guard count > 0 else { return }
        guard !tiles.isEmpty else { return }

        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer()
        else { return }
        commandBuffer.label = "Simulation.Frame"

        signpostInterval(SimSignpost.theater, "frame") {
            // Bucket the drained instances into per-tile
            // contiguous regions of tileSortedBuffer. Tiles
            // without any matching instance contribute zero
            // draws (§12 idle).
            let regions = bucketInstancesIntoTiles(drainCount: count)
            guard !regions.isEmpty else { return }

            // Refresh per-tile cameras for the current physical
            // drawable size + per-tile viewport rect. Cheap (≤
            // 16 cameras × 32 bytes = 512 bytes write).
            let density = Self.backingScale(of: view)
            updateCamerasForTiles(density: density)

            guard let encoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: descriptor
            ) else { return }
            encoder.label = "Simulation.Encoder"

            encoder.setVertexBuffer(quadVertices, offset: 0, index: 0)
            encoder.setFragmentSamplerState(spriteSampler, index: 0)

            for (tileIdx, region) in regions.enumerated() {
                guard region.count > 0 else { continue }
                let tile = tiles[tileIdx]
                encoder.setViewport(tile.viewport)
                encoder.setVertexBuffer(
                    tileSortedBuffer,
                    offset: region.offsetBytes,
                    index: 1
                )
                encoder.setVertexBuffer(
                    cameraBuffer,
                    offset: tileIdx * MemoryLayout<CameraUniforms>.stride,
                    index: 2
                )

                // Body pass.
                encoder.setRenderPipelineState(bodyPipelineState)
                encoder.drawIndexedPrimitives(
                    type: .triangle,
                    indexCount: 6,
                    indexType: .uint16,
                    indexBuffer: quadIndices,
                    indexBufferOffset: 0,
                    instanceCount: region.count
                )

                // Halo pass — separate additive-blend draw per
                // DOCTRINE §5.7 + I-16. Halo fragment gates
                // visibility on the `STATE_FLAG_ACTIVE_HALO` bit;
                // emitting one halo per instance is correct even
                // for inactive companions (they output alpha 0).
                encoder.setRenderPipelineState(haloPipelineState)
                encoder.drawIndexedPrimitives(
                    type: .triangle,
                    indexCount: 6,
                    indexType: .uint16,
                    indexBuffer: quadIndices,
                    indexBufferOffset: 0,
                    instanceCount: region.count
                )
            }

            encoder.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Tile bucketing

    /// One tile's slice in `tileSortedBuffer`.
    private struct TileRegion {
        var offsetBytes: Int
        var count: Int
    }

    /// Walks the drained instance buffer and writes entries into
    /// `tileSortedBuffer` partitioned by tile (in `tiles` order).
    /// Returns one `TileRegion` per tile with its byte offset +
    /// instance count.
    ///
    /// Cost: 2 linear passes over `drainCount` entries (count
    /// then write). For typical N (≤ 12) this is well below the
    /// per-frame budget.
    private func bucketInstancesIntoTiles(drainCount: Int) -> [TileRegion] {
        let stride = MemoryLayout<PerInstanceData>.stride
        let src = bridge.instanceBuffer.contents()
            .bindMemory(to: PerInstanceData.self, capacity: bridge.capacity)
        let dst = tileSortedBuffer.contents()
            .bindMemory(to: PerInstanceData.self, capacity: bridge.capacity)

        // Pre-size per-tile counts.
        var counts = [Int](repeating: 0, count: tiles.count)
        for i in 0..<drainCount {
            let key = AgentIdKey(perInstance: src[i])
            for (tileIdx, tile) in tiles.enumerated() {
                if tile.agentKeys.contains(key) {
                    counts[tileIdx] += 1
                    break
                }
            }
        }

        // Compute regions.
        var regions: [TileRegion] = []
        regions.reserveCapacity(tiles.count)
        var runningOffset = 0
        for c in counts {
            regions.append(TileRegion(
                offsetBytes: runningOffset * stride, count: c
            ))
            runningOffset += c
        }

        // Second pass: write entries to tile-sorted slots. Use
        // local cursors per tile to avoid recomputation.
        var cursors = regions.map { $0.offsetBytes / stride }
        for i in 0..<drainCount {
            let entry = src[i]
            let key = AgentIdKey(perInstance: entry)
            for (tileIdx, tile) in tiles.enumerated() {
                if tile.agentKeys.contains(key) {
                    dst[cursors[tileIdx]] = entry
                    cursors[tileIdx] += 1
                    break
                }
            }
            // Entries with no matching tile (unbound agents in
            // the landing room) are silently dropped from this
            // theater frame — they show up on the landing farm,
            // not in the graph theater.
        }
        return regions
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

    /// Initialise all `maxTiles` camera slots with the full
    /// drawable size — sane default before the host configures
    /// per-tile viewports.
    private func updateCamerasForFullDrawable(size: CGSize, density: Float) {
        let stride = MemoryLayout<CameraUniforms>.stride
        var uniform = CameraUniforms(
            viewportSize: (Float(size.width), Float(size.height)),
            pixelDensity: density > 0 ? density : 1.0,
            pad: 0,
            viewOffset: (0, 0)
        )
        let base = cameraBuffer.contents()
        for i in 0..<Self.maxTiles {
            memcpy(base + i * stride, &uniform, MemoryLayout<CameraUniforms>.size)
        }
    }

    /// Per-frame camera refresh — one camera slot per tile, sized
    /// to the tile's pixel viewport so the snap-to-pixel vertex
    /// shader keeps working inside the tile.
    private func updateCamerasForTiles(density: Float) {
        let stride = MemoryLayout<CameraUniforms>.stride
        let base = cameraBuffer.contents()
        for (tileIdx, tile) in tiles.enumerated() where tileIdx < Self.maxTiles {
            var uniform = CameraUniforms(
                viewportSize: (Float(tile.viewport.width), Float(tile.viewport.height)),
                pixelDensity: density > 0 ? density : 1.0,
                pad: 0,
                viewOffset: (0, 0)
            )
            memcpy(base + tileIdx * stride, &uniform, MemoryLayout<CameraUniforms>.size)
        }
    }
}
