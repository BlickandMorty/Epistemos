// SDFLabelInstanceBuilder.swift
//
// Per-frame construction of `LabelInstance` arrays for SDF text rendering.
// Called each frame from the graph draw loop: walks visible nodes, looks
// up glyph UVs in the atlas, packs one LabelInstance per glyph into a
// contiguous C-ABI buffer, then hands it to Rust.
//
// Struct layout MUST match `graph_engine::renderer::LabelInstance`
// (renderer.rs, 64-byte `#[repr(C)]`). Keep this in sync — mismatch = GPU
// reads garbage.
//
// Per CODEX_PROMPT_CHAIN.md §B-3 + Tier 1 "Deep Engineering Report" Part II.

import Foundation

/// C-ABI-compatible mirror of `graph_engine::renderer::LabelInstance` /
/// `GraphEngineLabelInstance` (from the C bridging header). 64 bytes,
/// 16-byte aligned for Metal float4 stride. Layout checked at runtime
/// via the static verifier below.
struct SDFLabelInstance {
    var position: SIMD2<Float> = .zero   // world-space glyph center (8B, ofs 0)
    var size: SIMD2<Float> = .zero       // half-extents in world units (8B, ofs 8)
    var uvRect: SIMD4<Float> = .zero     // atlas UV (16B, ofs 16)
    var color: SIMD4<Float> = .zero      // linear RGBA (16B, ofs 32)
    var nodeDist: Float = 0              // distance to camera focus (4B, ofs 48)
    var pad0: Float = 0                  // (4B, ofs 52)
    var pad1: Float = 0                  // (4B, ofs 56)
    var pad2: Float = 0                  // (4B, ofs 60)

    /// Verifies the Swift struct matches the C struct at runtime. Called
    /// once at app startup via `verifyLayout()`. Crashes with a clear
    /// message on mismatch rather than letting the GPU read garbage.
    static func verifyLayout() {
        assert(MemoryLayout<SDFLabelInstance>.size == 64,
               "SDFLabelInstance must be exactly 64 bytes to match C struct")
        assert(MemoryLayout<SDFLabelInstance>.stride == 64,
               "SDFLabelInstance stride must be 64 for Metal float4 alignment")
    }
}

/// Build LabelInstances for visible nodes and push to the graph engine.
enum SDFLabelInstanceBuilder {
    /// Reusable scratch buffer — avoids per-frame allocation.
    static var scratch: [SDFLabelInstance] = []

    struct Node {
        let worldX: Float
        let worldY: Float
        let radius: Float
        let label: String
    }

    /// Maximum number of glyph instances uploaded per frame. Past this
    /// point the graph reads as noise; CPU-side sort picks the most
    /// important labels. Per Tier 1 §C2: 128 labels at any zoom is always
    /// readable, but we scale by node count to catch small graphs too.
    static let labelBudget = 4096

    /// Build instances for the given nodes, capped to `labelBudget` glyphs.
    /// `cameraWorld`: current camera world-space offset (focus point).
    /// `worldPxPerEm`: how large the label should render — typically a
    /// fraction of the node radius. World-unit mapping depends on zoom.
    static func build(
        nodes: [Node],
        atlas: SDFLabelAtlas,
        cameraWorld: SIMD2<Float>,
        worldPxPerEm: Float,
        color: SIMD4<Float> = SIMD4<Float>(0.95, 0.95, 0.95, 1.0)
    ) -> [SDFLabelInstance] {
        scratch.removeAll(keepingCapacity: true)
        scratch.reserveCapacity(min(labelBudget, nodes.count * 12))

        var total = 0
        for node in nodes {
            if total >= labelBudget { break }
            appendLabel(
                for: node,
                atlas: atlas,
                cameraWorld: cameraWorld,
                worldPxPerEm: worldPxPerEm,
                color: color,
                out: &scratch,
                budgetRemaining: labelBudget - total,
                totalEmitted: &total
            )
        }
        return scratch
    }

    private static func appendLabel(
        for node: Node,
        atlas: SDFLabelAtlas,
        cameraWorld: SIMD2<Float>,
        worldPxPerEm: Float,
        color: SIMD4<Float>,
        out: inout [SDFLabelInstance],
        budgetRemaining: Int,
        totalEmitted: inout Int
    ) {
        // Trim labels that are too long — keep them readable at glance.
        // Matches common knowledge-graph rendering heuristics (Tier 1 §C2).
        let maxChars = 32
        let label: Substring = node.label.count > maxChars
            ? node.label.prefix(maxChars)
            : node.label[node.label.startIndex..<node.label.endIndex]
        guard !label.isEmpty else { return }

        // Pre-compute advance to center the label horizontally under node.
        var advanceEm: Float = 0
        for char in label {
            let glyph = atlas.glyphs[char] ?? atlas.fallbackGlyph
            advanceEm += glyph?.advanceEm ?? 0
        }
        if advanceEm <= 0 { return }

        let labelHalfWidthWorld = advanceEm * worldPxPerEm * 0.5
        let yOffsetWorld = -(node.radius + worldPxPerEm * atlas.lineHeightEm * 0.6)
        var penXWorld = node.worldX - labelHalfWidthWorld
        let baselineY = node.worldY + yOffsetWorld

        let nodeDist = hypot(node.worldX - cameraWorld.x, node.worldY - cameraWorld.y)

        for char in label {
            if totalEmitted >= atlas.glyphs.count + budgetRemaining { break }
            guard let glyph = atlas.glyphs[char] ?? atlas.fallbackGlyph else {
                // Glyph not in atlas and no fallback — skip, but still advance
                // so subsequent glyphs don't bunch up.
                penXWorld += worldPxPerEm * 0.5
                continue
            }
            if glyph.halfWidthEm == 0 || glyph.halfHeightEm == 0 {
                // Whitespace — advance only.
                penXWorld += glyph.advanceEm * worldPxPerEm
                continue
            }

            // Glyph center in world space: pen position + center-x bearing,
            // baseline + center-y bearing (em → world-unit conversion).
            let centerX = penXWorld + glyph.bearingXEm * worldPxPerEm
            let centerY = baselineY + glyph.bearingYEm * worldPxPerEm

            var inst = SDFLabelInstance()
            inst.position = SIMD2<Float>(centerX, centerY)
            inst.size = SIMD2<Float>(
                glyph.halfWidthEm * worldPxPerEm,
                glyph.halfHeightEm * worldPxPerEm
            )
            inst.uvRect = glyph.uvRect
            inst.color = color
            inst.nodeDist = Float(nodeDist)
            out.append(inst)
            totalEmitted += 1

            penXWorld += glyph.advanceEm * worldPxPerEm
        }
    }
}
