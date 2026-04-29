//
//  PipelineArchive.swift
//  Simulation Mode S4 — pre-compiled Metal pipeline state factory.
//
//  Per DOCTRINE I-15 / IMPLEMENTATION §2.4 + S4 acceptance: NO
//  main-thread Metal pipeline compilation on the per-frame path.
//  All pipeline state is constructed in `MetalSimulationRenderer.init()`
//  via the helpers here, which load the default Metal library
//  (compiled into the app binary at build time) and synchronously
//  build pipeline state objects ONCE.
//
//  S4 ships placeholder shaders + immediate pipeline construction.
//  S14 may layer `MTLBinaryArchive` on top to cache compiled
//  pipelines across launches — the API surface here is structured
//  to make that addition non-breaking.

import Foundation
import Metal
import MetalKit

public enum MetalRendererError: Error, CustomStringConvertible {
    case deviceUnavailable
    case commandQueueFailed
    case samplerFailed
    case shaderLibraryFailed
    case missingShaderFunction(String)
    case pipelineStateFailed(String, Error)

    public var description: String {
        switch self {
        case .deviceUnavailable:
            return "Metal device unavailable"
        case .commandQueueFailed:
            return "Could not create MTLCommandQueue"
        case .samplerFailed:
            return "Could not create sampler state (DOCTRINE I-16: nearest-neighbor required)"
        case .shaderLibraryFailed:
            return "Could not load default Metal library"
        case .missingShaderFunction(let name):
            return "Shader function not found: \(name)"
        case .pipelineStateFailed(let label, let error):
            return "Pipeline state '\(label)' failed: \(error)"
        }
    }
}

/// Factory for the simulation's Metal pipeline state objects.
/// Used by `MetalSimulationRenderer.init()` to construct the body
/// + halo pipelines exactly once per app launch, off the
/// per-frame path.
public enum PipelineArchive {

    /// Load the default Metal library (compiled into the app at
    /// build time via `Tools/build_pipeline_archive.sh`). On
    /// failure surface a typed error rather than crashing.
    public static func loadLibrary(device: MTLDevice) throws -> MTLLibrary {
        guard let library = device.makeDefaultLibrary() else {
            throw MetalRendererError.shaderLibraryFailed
        }
        library.label = "Simulation.DefaultLibrary"
        return library
    }

    /// Build the **body** pipeline — alpha-blended sprite quads.
    /// Per DOCTRINE I-16 the pipeline is configured for bit-perfect
    /// rendering: `sampleCount = 1` (MSAA off), pixel format
    /// `.bgra8Unorm` (NOT `_srgb` — gamma re-encoding adds
    /// intermediate values and breaks pixel sharpness).
    ///
    /// `useRealAtlas`: if `true` (S10 default), bind the real
    /// `companion_fragment` (palette-mask sampling). If `false`,
    /// bind the S4 `companion_fragment_placeholder` (striped
    /// tint) so the synthetic harness can still run when no
    /// atlas is loaded.
    public static func makeBodyPipeline(
        device: MTLDevice,
        library: MTLLibrary,
        view: MTKView,
        useRealAtlas: Bool = true
    ) throws -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Simulation.Body"
        descriptor.vertexFunction = try requireFunction(
            named: "companion_vertex", in: library
        )
        descriptor.fragmentFunction = try requireFunction(
            named: useRealAtlas ? "companion_fragment" : "companion_fragment_placeholder",
            in: library
        )

        let attachment = descriptor.colorAttachments[0]
        attachment?.pixelFormat = view.colorPixelFormat
        attachment?.isBlendingEnabled = true
        // Standard "over" blend for the body — premultiplied alpha
        // is not used because the placeholder shader produces
        // straight-alpha output. The halo pipeline (below) uses
        // additive blending per I-16 §5.7.
        attachment?.rgbBlendOperation = .add
        attachment?.alphaBlendOperation = .add
        attachment?.sourceRGBBlendFactor = .sourceAlpha
        attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment?.sourceAlphaBlendFactor = .one
        attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        descriptor.vertexDescriptor = makeQuadVertexDescriptor()
        descriptor.rasterSampleCount = 1 // I-16: MSAA off

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw MetalRendererError.pipelineStateFailed("Simulation.Body", error)
        }
    }

    /// Build the **halo** pipeline — additive-blended quads layered
    /// behind / around active companions. Per DOCTRINE §5.7 + I-16:
    /// "halo / eye-bloom render as separate additive-blend draws"
    /// with `MTLBlendFactor.one × MTLBlendFactor.one`. The softness
    /// lives in the pre-baked PNG texture, NEVER in a runtime blur.
    public static func makeHaloPipeline(
        device: MTLDevice,
        library: MTLLibrary,
        view: MTKView,
        useRealAtlas: Bool = true
    ) throws -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Simulation.Halo"
        descriptor.vertexFunction = try requireFunction(
            named: "companion_vertex", in: library
        )
        descriptor.fragmentFunction = try requireFunction(
            named: useRealAtlas ? "halo_fragment" : "halo_fragment_placeholder",
            in: library
        )

        let attachment = descriptor.colorAttachments[0]
        attachment?.pixelFormat = view.colorPixelFormat
        attachment?.isBlendingEnabled = true
        attachment?.rgbBlendOperation = .add
        attachment?.alphaBlendOperation = .add
        // I-16 / DOCTRINE §5.7: ADDITIVE BLEND. one × one.
        attachment?.sourceRGBBlendFactor = .one
        attachment?.destinationRGBBlendFactor = .one
        attachment?.sourceAlphaBlendFactor = .one
        attachment?.destinationAlphaBlendFactor = .one

        descriptor.vertexDescriptor = makeQuadVertexDescriptor()
        descriptor.rasterSampleCount = 1 // I-16

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw MetalRendererError.pipelineStateFailed("Simulation.Halo", error)
        }
    }

    /// Sampler — `nearest` min/mag, `notMipmapped`, clamp-to-edge.
    /// The pixel-art bit-perfect contract from I-16: linear /
    /// bilinear filtering on a sprite atlas is a defect. Mipmaps
    /// are forbidden too.
    public static func makeSpriteSampler(device: MTLDevice) throws -> MTLSamplerState {
        let descriptor = MTLSamplerDescriptor()
        descriptor.label = "Simulation.SpriteSampler"
        descriptor.minFilter = .nearest // I-16
        descriptor.magFilter = .nearest // I-16
        descriptor.mipFilter = .notMipmapped // I-16
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        guard let sampler = device.makeSamplerState(descriptor: descriptor) else {
            throw MetalRendererError.samplerFailed
        }
        return sampler
    }

    // MARK: - Internals

    private static func requireFunction(
        named name: String, in library: MTLLibrary
    ) throws -> MTLFunction {
        guard let fn = library.makeFunction(name: name) else {
            throw MetalRendererError.missingShaderFunction(name)
        }
        return fn
    }

    /// Vertex descriptor for a unit quad: one float2 attribute
    /// (position), tightly packed. Used by both body + halo
    /// pipelines.
    private static func makeQuadVertexDescriptor() -> MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()
        descriptor.attributes[0].format = .float2
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].bufferIndex = 0
        descriptor.layouts[0].stride = MemoryLayout<Float>.stride * 2
        descriptor.layouts[0].stepFunction = .perVertex
        return descriptor
    }
}
