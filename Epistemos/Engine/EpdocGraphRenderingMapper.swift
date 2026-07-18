import Foundation

// MARK: - EpdocGraphRenderingMapper
//
// Wave 7.16 of the Extended Program Plan
// (`docs/audits/EXTENDED_PROGRAM_PLAN_2026_04_25.md` Wave 7.16).
//
// Translates an `EpdocGraphProjection` (W7.14) into renderer scalars.
// Document nodes stay visually neutral; semantic graph structure and edge
// kinds carry the hierarchy without rescanning the live editor document.
//
//     edgeWeightMultiplier = per-kind table:
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

    /// Epdoc nodes use neutral render attributes. The projection argument is
    /// intentionally retained so callers keep one stable mapping contract.
    static func attributes(for projection: EpdocGraphProjection) -> EpdocGraphRenderAttributes {
        _ = projection
        return EpdocGraphRenderAttributes(
            radiusMultiplier: 1.0,
            labelFontScale: 1.0,
            haloAlpha: 0.0
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
}
