//! Wave 7.16 — complexity-weight render attribute helpers (Rust).
//!
//! Mirrors the Swift `EpdocGraphRenderingMapper` curves at
//! `Epistemos/Engine/EpdocGraphRenderingMapper.swift` so both the
//! Swift consumer (which builds NodeInstance buffers) and any
//! future Rust-side renderer pass apply the SAME multipliers
//! when rendering complexity-weighted .epdoc nodes.
//!
//! Why both sides need the curve: today the Swift host pre-multiplies
//! the radius before constructing the Metal NodeInstance. A future
//! commit may move the multiplication into a Rust shader uniform
//! pre-pass — when that happens, the canonical curve has to live
//! on both sides of the FFI so a renderer regression can't drift
//! one off the other. This file is the Rust source of truth; the
//! Swift mapper at `Epistemos/Engine/EpdocGraphRenderingMapper.swift`
//! mirrors it exactly. A cross-language fixture test pins them to
//! the same outputs at three boundary points (0.0, 0.5, 1.0).
//!
//! ## Curve definitions (linear interpolation against complexity ∈ [0, 1])
//!
//!   radius_multiplier  = lerp(0.7, 1.6, c)   simple notes feel small;
//!                                            complex docs hub the layout
//!   label_font_scale   = lerp(1.0, 1.4, c)
//!   halo_alpha         = lerp(0.0, 0.40, c)  caps at 40% so we don't
//!                                            blow out blend
//!
//! Edge weight by GraphEdgeType is a per-kind table, decoupled from
//! node complexity:
//!   .derivedFrom = 1.6   provenance reads load-bearing
//!   .reference   = 1.0   wikilinks / outputs at visual base
//!   .contains    = 1.4
//!   .tagged      = 0.7
//!   anything else = 1.0  graceful default

/// Per-node Metal render attributes derived from the complexity scalar.
/// Values are dimensionless multipliers consumers apply against their
/// renderer-specific base values.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ComplexityRenderAttributes {
    pub radius_multiplier: f32,
    pub label_font_scale: f32,
    pub halo_alpha: f32,
}

/// Compute the per-node render attributes for a given complexity
/// scalar. Pure function; clamps the input to `[0, 1]` defensively.
pub fn render_attributes(complexity: f32) -> ComplexityRenderAttributes {
    let c = clamp_unit(complexity);
    ComplexityRenderAttributes {
        radius_multiplier: lerp(0.7, 1.6, c),
        label_font_scale:  lerp(1.0, 1.4, c),
        halo_alpha:        lerp(0.0, 0.40, c),
    }
}

/// Per-edge thickness multiplier indexed by the edge kind name. Names
/// mirror Swift's `GraphEdgeType` raw values exactly. Unknown edge
/// kinds receive the canonical 1.0 default.
pub fn edge_weight_multiplier(edge_kind: &str) -> f32 {
    match edge_kind {
        "derivedFrom" => 1.6,
        "reference"   => 1.0,
        "contains"    => 1.4,
        "tagged"      => 0.7,
        _             => 1.0,
    }
}

#[inline]
fn lerp(a: f32, b: f32, t: f32) -> f32 {
    a + (b - a) * t
}

#[inline]
fn clamp_unit(value: f32) -> f32 {
    value.clamp(0.0, 1.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Float-equal helper — float32 lerp can drift by ~1 ulp.
    fn approx_eq(a: f32, b: f32, eps: f32) -> bool {
        (a - b).abs() < eps
    }

    #[test]
    fn complexity_zero_yields_baseline() {
        let attrs = render_attributes(0.0);
        assert!(approx_eq(attrs.radius_multiplier, 0.7, 1e-5));
        assert!(approx_eq(attrs.label_font_scale, 1.0, 1e-5));
        assert!(approx_eq(attrs.halo_alpha, 0.0, 1e-5),
                "complexity 0 docs MUST disable halo (alpha 0)");
    }

    #[test]
    fn complexity_one_yields_ceiling() {
        let attrs = render_attributes(1.0);
        assert!(approx_eq(attrs.radius_multiplier, 1.6, 1e-5));
        assert!(approx_eq(attrs.label_font_scale, 1.4, 1e-5));
        assert!(approx_eq(attrs.halo_alpha, 0.40, 1e-5),
                "complexity 1 docs MUST cap halo at 0.40 (no blend blow-out)");
    }

    #[test]
    fn complexity_half_is_linear_midpoint() {
        let attrs = render_attributes(0.5);
        assert!(approx_eq(attrs.radius_multiplier, 1.15, 1e-5));
        assert!(approx_eq(attrs.label_font_scale, 1.20, 1e-5));
        assert!(approx_eq(attrs.halo_alpha, 0.20, 1e-5));
    }

    #[test]
    fn out_of_range_clamps_defensively() {
        let above = render_attributes(5.0);
        assert!(approx_eq(above.radius_multiplier, 1.6, 1e-5));
        let below = render_attributes(-2.0);
        assert!(approx_eq(below.radius_multiplier, 0.7, 1e-5));
    }

    #[test]
    fn mapping_is_monotonic() {
        let weights: [f32; 7] = [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0];
        let mut prev = render_attributes(weights[0]);
        for &w in &weights[1..] {
            let next = render_attributes(w);
            assert!(next.radius_multiplier >= prev.radius_multiplier);
            assert!(next.label_font_scale  >= prev.label_font_scale);
            assert!(next.halo_alpha        >= prev.halo_alpha);
            prev = next;
        }
    }

    // MARK: - edge weight table

    #[test]
    fn edge_weight_table_matches_swift_mapper() {
        assert_eq!(edge_weight_multiplier("derivedFrom"), 1.6);
        assert_eq!(edge_weight_multiplier("reference"),   1.0);
        assert_eq!(edge_weight_multiplier("contains"),    1.4);
        assert_eq!(edge_weight_multiplier("tagged"),      0.7);
    }

    #[test]
    fn edge_weight_unknown_falls_back_to_one() {
        assert_eq!(edge_weight_multiplier(""),               1.0);
        assert_eq!(edge_weight_multiplier("never-defined"),  1.0);
        assert_eq!(edge_weight_multiplier("related"),        1.0,
                   "unmapped GraphEdgeType cases MUST inherit 1.0 (graceful default)");
    }

    /// Cross-language fixture: the three boundary points (0.0, 0.5,
    /// 1.0) MUST match Swift `EpdocGraphRenderingMapper.attributes`
    /// byte-for-byte. The Swift test at
    /// `EpistemosTests/EpdocGraphRenderingMapperTests.swift` pins
    /// the same expected values; if either drifts, both fixtures
    /// fail simultaneously.
    #[test]
    fn cross_language_fixture_matches_swift() {
        let fixtures: [(f32, f32, f32, f32); 3] = [
            (0.0, 0.7,  1.0, 0.0),
            (0.5, 1.15, 1.20, 0.20),
            (1.0, 1.6,  1.4, 0.40),
        ];
        for (c, expected_radius, expected_font, expected_halo) in fixtures {
            let attrs = render_attributes(c);
            assert!(approx_eq(attrs.radius_multiplier, expected_radius, 1e-4),
                    "complexity {c} radius drifted from Swift fixture");
            assert!(approx_eq(attrs.label_font_scale, expected_font, 1e-4),
                    "complexity {c} font drifted from Swift fixture");
            assert!(approx_eq(attrs.halo_alpha, expected_halo, 1e-4),
                    "complexity {c} halo drifted from Swift fixture");
        }
    }
}
