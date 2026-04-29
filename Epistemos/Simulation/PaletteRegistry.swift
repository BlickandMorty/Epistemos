//
//  PaletteRegistry.swift
//  Simulation Mode S10 — load the V1 palette JSONs into a
//  `[Palette]` uniform buffer indexed by `PerInstanceData.palette_id`.
//
//  Per DOCTRINE §10.5 the fragment shader receives a constant
//  `Palette[N]` array — one entry per known palette. The reducer
//  encodes each companion's `palette_id` into PerInstanceData;
//  the shader looks it up at draw time and recolors mask pixels.
//

import Foundation
import Metal

/// One palette entry mirroring `Palette` in Companion.metal.
public struct PaletteEntry: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let body: SIMD4<Float>
    public let accent: SIMD4<Float>
    public let eye: SIMD4<Float>
}

/// Order of palettes in the uniform buffer. The `palette_id`
/// field on PerInstanceData indexes into this list. The reducer
/// resolves a companion's `palette_ref` string to this index.
public enum PaletteOrder: String, CaseIterable, Sendable {
    case claudeWarm    = "claude_warm_v1"
    case kimiIndigo    = "kimi_indigo_v1"
    case codexNeutral  = "codex_neutral_v1"
    case gptNeutral    = "gpt_neutral_v1"
    case hermesGold    = "hermes_gold_v1"
    case localTeal     = "local_teal_v1"

    public var index: UInt32 { UInt32(Self.allCases.firstIndex(of: self)!) }
}

public enum PaletteLoaderError: Error, CustomStringConvertible {
    case bundleResourceMissing(String)
    case parseError(String)

    public var description: String {
        switch self {
        case .bundleResourceMissing(let s): return "palette resource missing: \(s)"
        case .parseError(let s):            return "palette parse: \(s)"
        }
    }
}

public final class PaletteRegistry {

    public private(set) var entries: [PaletteEntry]
    public let buffer: MTLBuffer

    public init(device: MTLDevice) throws {
        let bundle = Bundle.main
        var loaded: [PaletteEntry] = []
        for slot in PaletteOrder.allCases {
            let entry = try Self.load(slot: slot, bundle: bundle)
            loaded.append(entry)
        }
        self.entries = loaded

        // Build the uniform buffer — `Palette` in Metal is 3 ×
        // float4 = 48 bytes. We stride at 64 bytes so the
        // hardware's natural alignment for buffer indexing
        // stays comfortable even with future fields.
        let stride = 64
        let totalBytes = stride * loaded.count
        guard let buf = device.makeBuffer(
            length: totalBytes, options: [.storageModeShared]
        ) else {
            throw PaletteLoaderError.parseError(
                "couldn't allocate palette uniform buffer"
            )
        }
        buf.label = "Simulation.PaletteUniform"
        let base = buf.contents()
        for (idx, entry) in loaded.enumerated() {
            var body = entry.body
            var accent = entry.accent
            var eye = entry.eye
            // Lay out as { float4 body, float4 accent, float4 eye }.
            memcpy(base + idx * stride + 0,  &body,   16)
            memcpy(base + idx * stride + 16, &accent, 16)
            memcpy(base + idx * stride + 32, &eye,    16)
        }
        self.buffer = buf
    }

    /// Resolve a `palette_ref` string (e.g. `claude_warm_v1`) to
    /// the integer `palette_id` Metal expects. Returns `0` (the
    /// default Claude palette) on miss — never crashes.
    public func index(for ref: String) -> UInt32 {
        if let slot = PaletteOrder(rawValue: ref) {
            return slot.index
        }
        return 0
    }

    // MARK: - JSON parser

    private static func load(
        slot: PaletteOrder, bundle: Bundle
    ) throws -> PaletteEntry {
        let url = try locate(slug: slot.rawValue, bundle: bundle)
        let data = try Data(contentsOf: url)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PaletteLoaderError.parseError("\(slot.rawValue): not an object")
        }
        guard let id = dict["id"] as? String,
              let display = dict["display_name"] as? String,
              let body = dict["body"] as? [String: Any],
              let accent = dict["accent"] as? [String: Any],
              let eye = dict["eye"] as? [String: Any]
        else {
            throw PaletteLoaderError.parseError(
                "\(slot.rawValue): missing id / display_name / body / accent / eye"
            )
        }
        return PaletteEntry(
            id: id,
            displayName: display,
            body: try parseRGBA(body, key: "body", slot: slot),
            accent: try parseRGBA(accent, key: "accent", slot: slot),
            eye: try parseRGBA(eye, key: "eye", slot: slot)
        )
    }

    private static func parseRGBA(
        _ blob: [String: Any], key: String, slot: PaletteOrder
    ) throws -> SIMD4<Float> {
        guard let rgba = blob["rgba"] as? [Int], rgba.count == 4 else {
            throw PaletteLoaderError.parseError(
                "\(slot.rawValue).\(key).rgba: expected [r, g, b, a]"
            )
        }
        return SIMD4<Float>(
            Float(rgba[0]) / 255.0,
            Float(rgba[1]) / 255.0,
            Float(rgba[2]) / 255.0,
            Float(rgba[3]) / 255.0
        )
    }

    private static func locate(slug: String, bundle: Bundle) throws -> URL {
        if let url = bundle.url(
            forResource: slug,
            withExtension: "json",
            subdirectory: "palettes"
        ) {
            return url
        }
        if let url = bundle.url(forResource: slug, withExtension: "json") {
            return url
        }
        throw PaletteLoaderError.bundleResourceMissing("\(slug).json")
    }
}
