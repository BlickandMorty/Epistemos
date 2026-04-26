import Foundation

// MARK: - EpdocGraphRenderingMapper
//
// Wave 7.16 of the Extended Program Plan
// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.16).
//
// Translates an `EpdocGraphProjection` (W7.14) into the per-node /
// per-edge scalar multipliers the Metal renderer
// (`graph-engine/src/renderer.rs`) needs to make complexity-weighted
// rendering happen.
//
// Why a Swift mapping layer instead of editing `renderer.rs` directly:
//   - The Metal renderer is large (~3000 LOC) with tight perf invariants
//     + an existing `bench_tests.rs` 60Hz/10K-node budget gate.
//   - Multiplier values (radius 0.5×–1.5×, label-font 1.0×–1.4×, halo
//     alpha 0–0.4) are V1 design choices that may iterate. Putting them
//     in Swift keeps the iteration loop cheap (no Rust rebuild).
//   - The Rust renderer already accepts `radius` + `alpha` per node
//     instance (cross-ref `NodeInstance` struct in renderer.rs); the
//     consumer just multiplies the base shape by what this mapper
//     returns and the renderer is none the wiser.
//
// Per the user's 2026-04-26 direction:
//
//     "the graph reflects the complexity of the documents"
//
// Mapping curves (linear interpolation against the W7.12 complexity
// scalar `c ∈ [0, 1]`):
//
//     radiusMultiplier = lerp(0.7, 1.6, c)   simple notes feel small;
//                                            complex docs hub the layout
//     labelFontScale   = lerp(1.0, 1.4, c)   small docs keep stock font;
//                                            complex docs read clearly
//     haloAlpha        = lerp(0.0, 0.40, c)  simple = no halo; complex
//                                            = luminous (caps at 40%
//                                            so we don't blow out blend)
//     edgeWeightMultiplier = per-kind table, decoupled from complexity:
//        .derivedFrom = 1.6  (provenance edges read as load-bearing)
//        .reference   = 1.0  (wikilinks / outputs sit at the visual base)
//        .contains    = 1.4
//        .tagged      = 0.7
//        every other GraphEdgeType inherits 1.0 (graceful fallback)

nonisolated struct EpdocGraphRenderAttributes: Sendable, Hashable {
    /// Multiplier applied to the renderer's base node radius. 1.0 = no
    /// change; 1.5 = 150% of base.
    let radiusMultiplier: Double
    /// Multiplier applied to the SDF label-atlas font scale.
    let labelFontScale: Double
    /// Halo alpha in [0, 0.4]. The renderer's halo pass takes alpha
    /// directly; 0 = no halo (skip the pass for that node).
    let haloAlpha: Double
}

nonisolated enum EpdocGraphRenderingMapper {

    /// Map a projection's complexity scalar to per-node render
    /// attributes. Pure function; no allocations.
    static func attributes(for projection: EpdocGraphProjection) -> EpdocGraphRenderAttributes {
        let c = clampUnit(projection.nodeWeight)
        return EpdocGraphRenderAttributes(
            radiusMultiplier: lerp(0.7, 1.6, t: c),
            labelFontScale:   lerp(1.0, 1.4, t: c),
            haloAlpha:        lerp(0.0, 0.40, t: c)
        )
    }

    /// Per-edge thickness multiplier for the Metal stroke pass.
    /// Decoupled from node complexity — provenance edges always read
    /// as load-bearing; tag edges always sit visually quieter.
    static func edgeWeightMultiplier(for kind: GraphEdgeType) -> Double {
        switch kind {
        case .derivedFrom:      return 1.6
        case .reference:        return 1.0
        case .contains:         return 1.4
        case .tagged:           return 0.7
        default:                return 1.0
        }
    }

    // MARK: - Helpers

    private static func lerp(_ a: Double, _ b: Double, t: Double) -> Double {
        a + (b - a) * t
    }

    private static func clampUnit(_ value: Double) -> Double {
        max(0.0, min(1.0, value))
    }
}
