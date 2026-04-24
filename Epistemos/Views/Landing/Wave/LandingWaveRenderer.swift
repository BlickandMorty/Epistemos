import Foundation
import Metal
import MetalKit
import QuartzCore
import simd

/// GPU renderer for the landing liquid-wave surface.
///
/// Owns:
///   - The `MTLDevice` and `MTLCommandQueue`.
///   - Two ping-pong height textures (`R32Float`) for FDTD.
///   - The glyph atlas (rasterized once at init).
///   - Compute and render pipeline states (built once at init).
///   - The uniform buffer (triple-buffered per Apple best practice).
///   - A pending queue of drop events that fire at their scheduled time.
///
/// Does not own the display link — the hosting `MTKView` drives per-frame
/// updates via its delegate. See `LandingWaveMetalView`.
///
/// Thread model: this class is `@MainActor` by default (project-wide), but
/// `draw(in:)` is invoked on the Metal drawing thread. All `@MainActor`
/// state is read through stable snapshots; mutable drop/event state uses a
/// lock to cross that boundary safely.
@MainActor
final class LandingWaveRenderer: NSObject {

    // MARK: - Uniforms (must match the Metal `LandingWaveUniforms` struct)

    // NOTE: Metal expects tight alignment. We use simd_* types and explicit
    // padding so memory layout matches the MSL struct byte-for-byte. When
    // editing either side, run `LandingWaveRendererLayoutTests` to verify.
    struct Uniforms {
        var time: Float = 0
        var _pad0: Float = 0
        var resolution: SIMD2<Float> = .zero
        var gridSize: SIMD2<Int32> = .zero
        var waveSpeedSquared: Float = LandingWaveDesign.waveSpeedSquared
        var waveDamping: Float = LandingWaveDesign.waveDamping
        var ambientAmplitude: Float = LandingWaveDesign.ambientAmplitude
        var dropCount: Int32 = 0
        var drops: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>,
                    SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>) =
            (.zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero)
        var barRect: SIMD4<Float> = .zero
        var barEmergenceT: Float = 0
        var reduceMotion: Int32 = 0
        var themeBase: SIMD4<Float> = SIMD4<Float>(0.1, 0.12, 0.18, 1.0)
        var themeAccent: SIMD4<Float> = SIMD4<Float>(0.5, 0.7, 1.0, 1.0)
        var atlasGridSize: SIMD2<Int32> = .zero
        var rampIndexCount: Int32 = 0
        var rampCellIndices: (SIMD2<Int32>, SIMD2<Int32>, SIMD2<Int32>, SIMD2<Int32>,
                              SIMD2<Int32>, SIMD2<Int32>, SIMD2<Int32>, SIMD2<Int32>,
                              SIMD2<Int32>, SIMD2<Int32>, SIMD2<Int32>, SIMD2<Int32>) =
            (.zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero,
             .zero, .zero, .zero, .zero)
    }

    // MARK: - GPU objects

    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let stepPipeline: MTLComputePipelineState
    private let clearPipeline: MTLComputePipelineState
    private let renderPipeline: MTLRenderPipelineState
    private let atlasSampler: MTLSamplerState
    private let atlas: LandingWaveGlyphAtlas.Built

    // Ping-pong height field textures. `prev` and `curr` are inputs; we write
    // `next`. Each tick the tuple rotates.
    private var heightTextures: [MTLTexture] = []
    private var heightPhase = 0    // index of the OLDEST (prev) texture
    private var gridSize: SIMD2<Int32> = .zero

    // Triple-buffered uniform buffers so CPU writes never contend with an
    // in-flight GPU read. See Apple's "Triple Buffering" best-practices guide.
    private static let inFlightFrames = 3
    private var uniformBuffers: [MTLBuffer] = []
    private var frameIndex = 0
    private let inFlightSemaphore = DispatchSemaphore(value: inFlightFrames)

    // Pending drop events (impulses scheduled to fire at future times).
    private var pendingDrops: [LandingWaveDropEvent] = []
    private var startTime: CFTimeInterval = 0

    // Knob: reduce-motion state (set by the host, checked every frame).
    var reduceMotion: Bool = false

    // MARK: - Init

    init?(device: MTLDevice) {
        self.device = device
        guard
            let queue = device.makeCommandQueue(),
            let library = device.makeDefaultLibrary(),
            let stepFn = library.makeFunction(name: "landing_wave_step"),
            let clearFn = library.makeFunction(name: "landing_wave_clear"),
            let vertexFn = library.makeFunction(name: "landing_wave_vertex"),
            let fragFn = library.makeFunction(name: "landing_wave_fragment")
        else {
            return nil
        }

        do {
            self.stepPipeline = try device.makeComputePipelineState(function: stepFn)
            self.clearPipeline = try device.makeComputePipelineState(function: clearFn)

            let renderDescriptor = MTLRenderPipelineDescriptor()
            renderDescriptor.vertexFunction = vertexFn
            renderDescriptor.fragmentFunction = fragFn
            renderDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            renderDescriptor.colorAttachments[0].isBlendingEnabled = true
            renderDescriptor.colorAttachments[0].rgbBlendOperation = .add
            renderDescriptor.colorAttachments[0].alphaBlendOperation = .add
            renderDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            renderDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            renderDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            renderDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            self.renderPipeline = try device.makeRenderPipelineState(descriptor: renderDescriptor)
        } catch {
            return nil
        }

        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        samplerDesc.mipFilter = .notMipmapped
        samplerDesc.sAddressMode = .clampToEdge
        samplerDesc.tAddressMode = .clampToEdge
        guard let sampler = device.makeSamplerState(descriptor: samplerDesc) else {
            return nil
        }
        self.atlasSampler = sampler

        guard let built = LandingWaveGlyphAtlas.build(device: device) else {
            return nil
        }
        self.atlas = built

        self.commandQueue = queue
        super.init()

        for _ in 0..<Self.inFlightFrames {
            guard let buffer = device.makeBuffer(
                length: MemoryLayout<Uniforms>.stride,
                options: .storageModeShared
            ) else { return nil }
            buffer.label = "LandingWaveUniforms"
            uniformBuffers.append(buffer)
        }

        self.startTime = CACurrentMediaTime()
    }

    // MARK: - Texture lifecycle

    /// Reallocate height textures for a new grid size. Must be called on the
    /// renderer actor. Invoked when the drawable resizes.
    func resize(to size: CGSize, drawableScale: CGFloat) {
        let width = Int(size.width * drawableScale)
        let height = Int(size.height * drawableScale)

        // Compute grid dimensions from pixel size.
        let pt = SIMD2<Float>(Float(size.width), Float(size.height))
        let cellW = 100.0 / Float(LandingWaveDesign.cellsPer100ptWidth)
        let cellH = 100.0 / Float(LandingWaveDesign.cellsPer100ptHeight)
        let cellsX = Int32(max(Float(LandingWaveDesign.minGridSize.x),
                               min(Float(LandingWaveDesign.maxGridSize.x), pt.x / cellW)))
        let cellsY = Int32(max(Float(LandingWaveDesign.minGridSize.y),
                               min(Float(LandingWaveDesign.maxGridSize.y), pt.y / cellH)))

        // Skip reallocation if the grid didn't change.
        let newGrid = SIMD2<Int32>(cellsX, cellsY)
        if newGrid == gridSize, !heightTextures.isEmpty, width > 0, height > 0 {
            return
        }
        gridSize = newGrid

        // Allocate two R32Float textures for ping-pong.
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Float,
            width: Int(cellsX),
            height: Int(cellsY),
            mipmapped: false
        )
        descriptor.storageMode = .private
        descriptor.usage = [.shaderRead, .shaderWrite]

        heightTextures.removeAll(keepingCapacity: true)
        for _ in 0..<2 {
            guard let tex = device.makeTexture(descriptor: descriptor) else { continue }
            tex.label = "LandingWaveHeight"
            heightTextures.append(tex)
        }
        heightPhase = 0

        // Clear both textures.
        zeroAllHeightTextures()
    }

    private func zeroAllHeightTextures() {
        guard let cmdBuffer = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuffer.makeComputeCommandEncoder()
        else { return }
        encoder.setComputePipelineState(clearPipeline)
        let threadgroupSize = MTLSize(width: 8, height: 8, depth: 1)
        let threadgroups = MTLSize(
            width: (Int(gridSize.x) + 7) / 8,
            height: (Int(gridSize.y) + 7) / 8,
            depth: 1
        )
        for tex in heightTextures {
            encoder.setTexture(tex, index: 0)
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        }
        encoder.endEncoding()
        cmdBuffer.commit()
    }

    // MARK: - Input

    /// Schedule a full drop-impact choreography at a window-space click point.
    /// Converts the point to cell coordinates and enqueues all sub-beats.
    func scheduleDrop(at windowPoint: CGPoint, viewSize: CGSize, cursorDirection: CGVector = .zero) {
        guard gridSize.x > 0, gridSize.y > 0, viewSize.width > 0, viewSize.height > 0 else {
            return
        }
        let cellX = Float(windowPoint.x / viewSize.width) * Float(gridSize.x)
        let cellY = Float(windowPoint.y / viewSize.height) * Float(gridSize.y)
        let click = SIMD2<Float>(cellX, cellY)
        let dir = SIMD2<Float>(Float(cursorDirection.dx), Float(cursorDirection.dy))

        let now = CACurrentMediaTime() - startTime
        let events = LandingWaveChoreography.makeSequence(at: click, cursorDirection: dir)
        for event in events {
            pendingDrops.append(
                LandingWaveDropEvent(
                    timeOffset: now + event.timeOffset,
                    position: event.position,
                    radius: event.radius,
                    strength: event.strength
                )
            )
        }
    }

    // MARK: - Frame

    /// Called by `MTKView` once per vsync. Encodes: one compute pass (wave
    /// step + impulse injection) followed by one render pass (ASCII render).
    func render(in view: MTKView) {
        guard heightTextures.count == 2,
              gridSize.x > 0, gridSize.y > 0,
              let drawable = view.currentDrawable,
              let passDescriptor = view.currentRenderPassDescriptor
        else { return }

        inFlightSemaphore.wait()
        defer { /* signal inside completion handler */ }

        let now = CACurrentMediaTime() - startTime
        let (drops, count) = dequeueDropsDue(now: now)

        let currIndex = heightPhase
        let nextIndex = (currIndex + 1) % 2
        let prevIndex = (currIndex + 1) % 2  // after the rotation this frame

        var uniforms = Uniforms()
        uniforms.time = Float(now)
        uniforms.resolution = SIMD2<Float>(Float(view.drawableSize.width),
                                           Float(view.drawableSize.height))
        uniforms.gridSize = gridSize
        uniforms.dropCount = Int32(count)
        uniforms.reduceMotion = reduceMotion ? 1 : 0
        uniforms.atlasGridSize = atlas.gridSize

        // Copy up to 8 drops into the tuple field.
        withUnsafeMutableBytes(of: &uniforms.drops) { raw in
            let base = raw.baseAddress!.assumingMemoryBound(to: SIMD4<Float>.self)
            for i in 0..<count {
                base[i] = drops[i]
            }
        }

        // Copy the luminance ramp's atlas cell indices.
        let rampCount = min(LandingWaveDesign.luminanceRamp.count, 12)
        uniforms.rampIndexCount = Int32(rampCount)
        withUnsafeMutableBytes(of: &uniforms.rampCellIndices) { raw in
            let base = raw.baseAddress!.assumingMemoryBound(to: SIMD2<Int32>.self)
            for i in 0..<rampCount {
                base[i] = atlas.cellIndex[i]
            }
        }

        let uniformBuffer = uniformBuffers[frameIndex]
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.stride)

        guard let cmdBuffer = commandQueue.makeCommandBuffer() else {
            inFlightSemaphore.signal()
            return
        }
        cmdBuffer.label = "LandingWaveFrame"

        let semaphore = inFlightSemaphore
        cmdBuffer.addCompletedHandler { _ in
            semaphore.signal()
        }

        // ── Compute pass: FDTD step ──
        if let computeEncoder = cmdBuffer.makeComputeCommandEncoder() {
            computeEncoder.label = "LandingWaveStep"
            computeEncoder.setComputePipelineState(stepPipeline)
            computeEncoder.setTexture(heightTextures[prevIndex], index: 0)
            computeEncoder.setTexture(heightTextures[currIndex], index: 1)
            computeEncoder.setTexture(heightTextures[nextIndex], index: 2)
            computeEncoder.setBuffer(uniformBuffer, offset: 0, index: 0)

            let threadgroupSize = MTLSize(width: 8, height: 8, depth: 1)
            let threadgroups = MTLSize(
                width: (Int(gridSize.x) + 7) / 8,
                height: (Int(gridSize.y) + 7) / 8,
                depth: 1
            )
            computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
            computeEncoder.endEncoding()
        }

        // Rotate ping-pong so next frame's `curr` == this frame's `next`.
        heightPhase = nextIndex

        // ── Render pass: sample height, map to ASCII ──
        if let renderEncoder = cmdBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) {
            renderEncoder.label = "LandingWaveRender"
            renderEncoder.setRenderPipelineState(renderPipeline)
            renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
            renderEncoder.setFragmentTexture(heightTextures[nextIndex], index: 0)
            renderEncoder.setFragmentTexture(atlas.texture, index: 1)
            renderEncoder.setFragmentSamplerState(atlasSampler, index: 0)
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()
        }

        cmdBuffer.present(drawable)
        cmdBuffer.commit()

        frameIndex = (frameIndex + 1) % Self.inFlightFrames
    }

    private func dequeueDropsDue(now: Double) -> ([SIMD4<Float>], Int) {
        var drops: [SIMD4<Float>] = []
        drops.reserveCapacity(8)
        var remaining: [LandingWaveDropEvent] = []
        for event in pendingDrops {
            if drops.count < 8 && event.timeOffset <= now {
                drops.append(SIMD4<Float>(
                    event.position.x,
                    event.position.y,
                    event.radius,
                    event.strength
                ))
            } else {
                remaining.append(event)
            }
        }
        pendingDrops = remaining
        return (drops, drops.count)
    }
}
