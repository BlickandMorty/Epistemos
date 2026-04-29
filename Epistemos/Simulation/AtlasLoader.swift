//
//  AtlasLoader.swift
//  Simulation Mode S10 — load the V1 atlas PNGs into a single
//  `texture2d_array<float>` (one slice per head shape) + parse
//  the matching JSON manifests into a Swift-typed lookup.
//
//  Per DOCTRINE §10.4 the atlas directory is
//  `Resources/CompanionAssets/atlas/`. Each PNG is a
//  states-rows × max-frames-columns grid (per
//  `procedural_atlas_v1.py` + `auto_slice.py`). The fragment
//  shader (Companion.metal §S10) recolors the atlas pixels at
//  draw time using the palette uniform.
//

import Foundation
import Metal
import MetalKit
import OSLog

/// Canonical head-shape ordering — matches the
/// `agent_core::ffi::PerInstanceData.atlas_index` field, which
/// the reducer sets per companion based on its head_shape. Add
/// a head shape only by appending here AND adding a row in the
/// loader below; the texture-array slice index is the rawValue.
public enum AtlasHeadShape: Int, CaseIterable, Sendable {
    case blockCompact = 0
    case blockWide    = 1
    case orb          = 2
    case sage         = 3
    case hermesSnake  = 4

    public var slug: String {
        switch self {
        case .blockCompact: return "block_compact"
        case .blockWide:    return "block_wide"
        case .orb:          return "orb"
        case .sage:         return "sage"
        case .hermesSnake:  return "hermes_snake"
        }
    }
}

/// Per-state UV manifest entry. One per §5.3 animation state.
public struct AtlasState: Sendable {
    public let row: Int
    public let frameCount: Int
    public let frameSize: (width: Int, height: Int)
}

/// Per-head manifest — what the fragment shader needs to
/// compute UVs at draw time.
public struct AtlasManifest: Sendable {
    public let headShape: AtlasHeadShape
    public let atlasSize: (width: Int, height: Int)
    public let cellSize: (width: Int, height: Int)
    public let maxFrames: Int
    public let states: [String: AtlasState]
}

public enum AtlasLoaderError: Error, CustomStringConvertible {
    case bundleResourceMissing(String)
    case manifestParse(String)
    case textureCreationFailed(String)

    public var description: String {
        switch self {
        case .bundleResourceMissing(let s): return "atlas resource missing: \(s)"
        case .manifestParse(let s):         return "atlas manifest parse: \(s)"
        case .textureCreationFailed(let s): return "atlas texture create: \(s)"
        }
    }
}

public final class AtlasLoader {

    /// Load all 5 V1 atlases into a single
    /// `texture2d_array<float>` keyed by `AtlasHeadShape.rawValue`
    /// as the slice index. Returns the texture + per-head
    /// manifests so the renderer can build the
    /// `(cell_w/atlas_w, cell_h/atlas_h, max_cols, _pad)` uniform
    /// the §S10 fragment shader consumes.
    public static func loadV1Atlases(
        device: MTLDevice
    ) throws -> (texture: MTLTexture, manifests: [AtlasHeadShape: AtlasManifest]) {
        let bundle = Bundle.main

        // Decode each PNG via MTKTextureLoader so we get the same
        // bit-perfect pixel data the file was written with. We
        // load each into a temporary 2D texture, then blit into
        // the texture array's slice.
        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            // I-16: nearest filtering everywhere; mipmaps off.
            .generateMipmaps: NSNumber(value: false),
            .SRGB: NSNumber(value: false),
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
        ]

        var perHead: [(AtlasHeadShape, MTLTexture, AtlasManifest)] = []
        for head in AtlasHeadShape.allCases {
            let png = try locate(slug: head.slug, ext: "png", bundle: bundle)
            let json = try locate(slug: head.slug, ext: "json", bundle: bundle)
            let manifest = try parseManifest(jsonURL: json, head: head)
            let tex = try loader.newTexture(URL: png, options: options)
            perHead.append((head, tex, manifest))
        }

        // Sanity: every head's atlas dimensions match its manifest.
        for (head, tex, manifest) in perHead {
            guard tex.width == manifest.atlasSize.width,
                  tex.height == manifest.atlasSize.height else {
                throw AtlasLoaderError.textureCreationFailed(
                    "\(head.slug): texture \(tex.width)×\(tex.height) ≠ manifest \(manifest.atlasSize.width)×\(manifest.atlasSize.height)"
                )
            }
        }

        // Build the texture-array. The V1 atlases have differing
        // (cell_w, cell_h) per head — but they all share the same
        // grid shape (8 frames × 14 states). The texture-array
        // slices need a uniform `arrayLength` × `width` × `height`.
        // We pick the largest atlas dimensions (block_wide /
        // hermes_snake / sage) as the slice size and pad smaller
        // atlases with transparent.
        let maxW = perHead.map { $0.1.width }.max() ?? 0
        let maxH = perHead.map { $0.1.height }.max() ?? 0
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2DArray
        descriptor.pixelFormat = .rgba8Unorm
        descriptor.width = maxW
        descriptor.height = maxH
        descriptor.arrayLength = AtlasHeadShape.allCases.count
        descriptor.mipmapLevelCount = 1
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .private
        guard let arrayTex = device.makeTexture(descriptor: descriptor) else {
            throw AtlasLoaderError.textureCreationFailed(
                "couldn't allocate \(maxW)×\(maxH)×\(AtlasHeadShape.allCases.count)"
            )
        }
        arrayTex.label = "Simulation.AtlasArray"

        // Blit per-head 2D textures into their slices. Smaller
        // atlases (block_compact, orb) sit anchored at (0, 0) of
        // the slice; the unused area stays transparent.
        guard let cmdQueue = device.makeCommandQueue(),
              let cmdBuf = cmdQueue.makeCommandBuffer(),
              let blit = cmdBuf.makeBlitCommandEncoder() else {
            throw AtlasLoaderError.textureCreationFailed(
                "couldn't allocate blit command buffer"
            )
        }
        blit.label = "Simulation.AtlasArrayBlit"
        for (head, tex, _) in perHead {
            blit.copy(
                from: tex,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: tex.width, height: tex.height, depth: 1),
                to: arrayTex,
                destinationSlice: head.rawValue,
                destinationLevel: 0,
                destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
            )
        }
        blit.endEncoding()
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()

        var manifestMap: [AtlasHeadShape: AtlasManifest] = [:]
        for (head, _, manifest) in perHead {
            manifestMap[head] = manifest
        }
        return (arrayTex, manifestMap)
    }

    // MARK: - Helpers

    private static func locate(
        slug: String, ext: String, bundle: Bundle
    ) throws -> URL {
        // Resolve via the bundle (xcodegen places
        // `Resources/CompanionAssets/atlas/<slug>.<ext>` into
        // the resource subdirectory at build time).
        if let url = bundle.url(
            forResource: slug,
            withExtension: ext,
            subdirectory: "atlas"
        ) {
            return url
        }
        if let url = bundle.url(forResource: slug, withExtension: ext) {
            return url
        }
        throw AtlasLoaderError.bundleResourceMissing("\(slug).\(ext)")
    }

    private static func parseManifest(
        jsonURL: URL, head: AtlasHeadShape
    ) throws -> AtlasManifest {
        let data = try Data(contentsOf: jsonURL)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AtlasLoaderError.manifestParse("\(head.slug): top-level not object")
        }
        guard let atlasSize = dict["atlas_size"] as? [Int], atlasSize.count == 2,
              let cellSize = dict["cell_size"] as? [Int], cellSize.count == 2,
              let maxFrames = dict["max_frames"] as? Int,
              let states = dict["states"] as? [String: [String: Any]]
        else {
            throw AtlasLoaderError.manifestParse(
                "\(head.slug): missing atlas_size / cell_size / max_frames / states"
            )
        }
        var stateMap: [String: AtlasState] = [:]
        for (name, blob) in states {
            guard let row = blob["row"] as? Int,
                  let count = blob["frame_count"] as? Int,
                  let frameSize = blob["frame_size"] as? [Int],
                  frameSize.count == 2
            else {
                throw AtlasLoaderError.manifestParse(
                    "\(head.slug).states.\(name): missing fields"
                )
            }
            stateMap[name] = AtlasState(
                row: row,
                frameCount: count,
                frameSize: (width: frameSize[0], height: frameSize[1])
            )
        }
        return AtlasManifest(
            headShape: head,
            atlasSize: (width: atlasSize[0], height: atlasSize[1]),
            cellSize: (width: cellSize[0], height: cellSize[1]),
            maxFrames: maxFrames,
            states: stateMap
        )
    }
}
