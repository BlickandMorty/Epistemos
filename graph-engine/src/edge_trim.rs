//! Edge endpoint trimming — phase 1 of the v3 motion overlay.
//!
//! The classic `LineEdgeInstance` / `CurveEdgeInstance` upload path ships
//! raw `p0` / `p1` / control points from node transform centres, which is
//! why edges visually stab into node discs. This module owns the tiny bit
//! of geometry that recoups the disc radius plus a small gap *before* the
//! GPU ever sees the instance, so the Metal vertex/fragment pipeline stays
//! unchanged and still produces clean, designed edges.
//!
//! The helpers return `None` when the trim would collapse the edge to a
//! zero-length segment (endpoints overlap beyond the radii). Callers drop
//! those edges entirely — there is no visual case where a sub-pixel stub
//! between two overlapping nodes is worth drawing, and skipping them here
//! keeps the vertex shader from doing degenerate NDC maths downstream.
//!
//! See docs/GRAPH_WAVES_PLAN.md task 1 for the surrounding spec. The
//! follow-up commits will:
//!   * wire `gap` through the motion-config FFI so Swift can tune it,
//!   * add a fragment-shader occlusion test as belt-and-suspenders, and
//!   * expose endpoint-radius data as instance fields for shader use.

use std::ops::{Add, Mul, Sub};

/// Default gap in world-units between the node edge and the start of the
/// drawn stroke. v3 spec §6 opened at 2.0 px; 2026-04-24 user asked to
/// "close the gap as much as possible without having them over the
/// nodes" — 0.75 px is the tight-but-safe floor. Values below ~0.5 px
/// risk the anti-aliased edge pixels kissing the node disc outline and
/// producing the old "stabbing into the circle" look. Values above
/// ~1.5 px read as visible detachment.
pub const DEFAULT_EDGE_GAP_PX: f32 = 0.75;

/// Minimum handle length (in world-units) for cubic-Bezier control points
/// after trimming. Guards against ultra-short handles creating visible
/// kinks when two small nodes happen to sit close together.
pub const MIN_TRIMMED_HANDLE_PX: f32 = 8.0;

/// If the distance between the two trimmed endpoints is below this
/// threshold (world-units), the trim collapses to `None` — the edge is
/// drawn as if its endpoints had perfectly overlapped and the caller
/// skips the upload. Chosen to be smaller than a single pixel at normal
/// zoom so no visible edge is ever wrongly culled.
const COLLAPSE_EPSILON_PX: f32 = 0.5;

/// Tiny 2D vector helper — avoids pulling in `glam` just for a pair of
/// geometry ops. All math is inlined so the compiler can keep the trim
/// path in registers.
#[derive(Clone, Copy, Debug, PartialEq)]
struct V2(f32, f32);

impl V2 {
    #[inline(always)]
    fn from_arr(a: [f32; 2]) -> Self {
        Self(a[0], a[1])
    }

    #[inline(always)]
    fn to_arr(self) -> [f32; 2] {
        [self.0, self.1]
    }

    #[inline(always)]
    fn length(self) -> f32 {
        (self.0 * self.0 + self.1 * self.1).sqrt()
    }

    #[inline(always)]
    fn length_squared(self) -> f32 {
        self.0 * self.0 + self.1 * self.1
    }

    /// Normalised direction or the zero vector if the input is
    /// degenerate — returning zero is safer here than a NaN that would
    /// propagate into later trig or the vertex shader.
    #[inline(always)]
    fn normalize_or_zero(self) -> V2 {
        let len = self.length();
        if len > 1e-5 {
            V2(self.0 / len, self.1 / len)
        } else {
            V2(0.0, 0.0)
        }
    }
}

impl Sub for V2 {
    type Output = V2;
    #[inline(always)]
    fn sub(self, rhs: V2) -> V2 {
        V2(self.0 - rhs.0, self.1 - rhs.1)
    }
}

impl Add for V2 {
    type Output = V2;
    #[inline(always)]
    fn add(self, rhs: V2) -> V2 {
        V2(self.0 + rhs.0, self.1 + rhs.1)
    }
}

impl Mul<f32> for V2 {
    type Output = V2;
    #[inline(always)]
    fn mul(self, rhs: f32) -> V2 {
        V2(self.0 * rhs, self.1 * rhs)
    }
}

/// Advance both endpoints of a straight edge inward by the respective
/// node radius plus a gap. Returns `None` when the trim collapses to a
/// near-zero segment (the two nodes are effectively touching or overlap),
/// at which point the caller must skip pushing this edge entirely.
///
/// Preconditions the caller must uphold:
///   * `r0`, `r1`, `gap` must be finite and ≥ 0.
///   * `p0` and `p1` must be finite.
/// Violations yield `None` rather than NaN.
#[inline]
pub fn trim_line_endpoints(
    p0: [f32; 2],
    p1: [f32; 2],
    r0: f32,
    r1: f32,
    gap: f32,
) -> Option<([f32; 2], [f32; 2])> {
    let a = V2::from_arr(p0);
    let b = V2::from_arr(p1);
    let delta = b - a;
    let length = delta.length();
    if !length.is_finite() || length < 1e-4 {
        return None;
    }

    let inset_total = r0.max(0.0) + r1.max(0.0) + 2.0 * gap.max(0.0);
    if length <= inset_total + COLLAPSE_EPSILON_PX {
        return None;
    }

    let dir = V2(delta.0 / length, delta.1 / length);
    let trimmed_a = a + dir * (r0 + gap);
    let trimmed_b = b - dir * (r1 + gap);

    // Belt-and-suspenders — if numerical edge cases push the trimmed
    // endpoints past each other, collapse rather than emit a reversed
    // or invisible segment.
    if (trimmed_b - trimmed_a).length_squared() < COLLAPSE_EPSILON_PX.powi(2) {
        return None;
    }

    Some((trimmed_a.to_arr(), trimmed_b.to_arr()))
}

/// Advance both endpoints of a cubic Bezier edge inward while preserving
/// the tangent directions at both ends. The control points are
/// translated to start/end from the trimmed endpoints, keeping the
/// original handle length so the curvature character of the edge is
/// preserved even when the visible segment shortens.
///
/// Returns `None` under the same collapse conditions as
/// [`trim_line_endpoints`]. Specifically, when the trimmed endpoints
/// would cross or the straight-line distance between original endpoints
/// is too small to accommodate both radii plus the gap.
#[inline]
pub fn trim_curve_endpoints(
    p0: [f32; 2],
    c0: [f32; 2],
    c1: [f32; 2],
    p1: [f32; 2],
    r0: f32,
    r1: f32,
    gap: f32,
) -> Option<([f32; 2], [f32; 2], [f32; 2], [f32; 2])> {
    let p0v = V2::from_arr(p0);
    let p1v = V2::from_arr(p1);
    let c0v = V2::from_arr(c0);
    let c1v = V2::from_arr(c1);

    // Tangent at each endpoint, falling back to the straight-line
    // direction between endpoints if a handle is degenerate (Bezier
    // starts/ends tangent to its first/last control leg).
    let start_leg = c0v - p0v;
    let end_leg = p1v - c1v;

    let straight = (p1v - p0v).normalize_or_zero();
    let t_start = if start_leg.length_squared() > 1e-6 {
        start_leg.normalize_or_zero()
    } else {
        straight
    };
    let t_end = if end_leg.length_squared() > 1e-6 {
        end_leg.normalize_or_zero()
    } else {
        straight
    };

    // If either tangent collapses AND the straight-line fallback
    // collapses too, the edge has no meaningful direction — skip.
    if t_start.length_squared() < 1e-6 || t_end.length_squared() < 1e-6 {
        return None;
    }

    // Sanity-check against the straight-line trim: if even the straight
    // distance can't absorb both radii, a curve along the same endpoints
    // certainly cannot.
    let baseline = trim_line_endpoints(p0, p1, r0, r1, gap);
    if baseline.is_none() {
        return None;
    }

    let p0t = p0v + t_start * (r0 + gap);
    let p1t = p1v - t_end * (r1 + gap);

    // Keep the original handle length so curvature character survives
    // the trim. The `max(MIN_TRIMMED_HANDLE_PX)` guards against very
    // short handles producing visible kinks.
    let h0 = start_leg.length().max(MIN_TRIMMED_HANDLE_PX);
    let h1 = end_leg.length().max(MIN_TRIMMED_HANDLE_PX);

    let c0t = p0t + t_start * h0;
    let c1t = p1t - t_end * h1;

    Some((p0t.to_arr(), c0t.to_arr(), c1t.to_arr(), p1t.to_arr()))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx_eq(a: f32, b: f32, eps: f32) -> bool {
        (a - b).abs() <= eps
    }

    fn approx_eq_pt(a: [f32; 2], b: [f32; 2], eps: f32) -> bool {
        approx_eq(a[0], b[0], eps) && approx_eq(a[1], b[1], eps)
    }

    #[test]
    fn straight_trim_advances_both_endpoints_by_radius_plus_gap() {
        // 100 unit horizontal segment, radii 10 and 15, gap 2 → trimmed
        // endpoints at (12, 0) and (83, 0).
        let out = trim_line_endpoints([0.0, 0.0], [100.0, 0.0], 10.0, 15.0, 2.0)
            .expect("non-collapsing trim");
        assert!(
            approx_eq_pt(out.0, [12.0, 0.0], 1e-4),
            "start was {:?}",
            out.0
        );
        assert!(
            approx_eq_pt(out.1, [83.0, 0.0], 1e-4),
            "end was {:?}",
            out.1
        );
    }

    #[test]
    fn straight_trim_preserves_direction_for_arbitrary_angle() {
        // 45° segment length 100 → sqrt(2)/2 per axis; radii 5 + 5 + gap 1.
        let p0 = [0.0_f32, 0.0];
        let p1 = [100.0 / (2.0_f32).sqrt(), 100.0 / (2.0_f32).sqrt()];
        let (start, end) = trim_line_endpoints(p0, p1, 5.0, 5.0, 1.0).expect("non-collapsing trim");
        // Insets (5+1)=6 from start; direction is (1/sqrt2, 1/sqrt2).
        let inset = 6.0_f32 / (2.0_f32).sqrt();
        assert!(approx_eq_pt(start, [inset, inset], 1e-3));
        let remaining = 100.0_f32 - 12.0;
        let expected_end_offset = (100.0 - 6.0) / (2.0_f32).sqrt();
        assert!(approx_eq_pt(
            end,
            [expected_end_offset, expected_end_offset],
            1e-3
        ));
        // Length should be the original 100 minus two radii and two gaps.
        let len = ((end[0] - start[0]).powi(2) + (end[1] - start[1]).powi(2)).sqrt();
        assert!(approx_eq(len, remaining, 1e-2));
    }

    #[test]
    fn straight_trim_collapses_when_nodes_overlap() {
        // Two overlapping 20-radius nodes 5 units apart cannot host a
        // visible edge — trim must report `None`.
        assert!(trim_line_endpoints([0.0, 0.0], [5.0, 0.0], 20.0, 20.0, 2.0).is_none());
    }

    #[test]
    fn straight_trim_collapses_at_exactly_boundary_distance() {
        // length == 2r + 2gap → collapse threshold. COLLAPSE_EPSILON_PX
        // makes this deterministic and slightly conservative.
        assert!(trim_line_endpoints([0.0, 0.0], [24.0, 0.0], 10.0, 10.0, 2.0).is_none());
    }

    #[test]
    fn straight_trim_rejects_nonfinite_inputs() {
        assert!(trim_line_endpoints([f32::NAN, 0.0], [10.0, 0.0], 1.0, 1.0, 0.5).is_none());
        assert!(trim_line_endpoints([0.0, 0.0], [f32::INFINITY, 0.0], 1.0, 1.0, 0.5).is_none());
    }

    #[test]
    fn curve_trim_preserves_tangent_direction_at_endpoints() {
        // Cubic with a clear vertical-then-horizontal shape: tangent at
        // start points upward, at end points rightward. After trim the
        // trimmed endpoint must sit on the original tangent axis.
        let p0 = [0.0_f32, 0.0];
        let c0 = [0.0, 30.0];
        let c1 = [30.0, 60.0];
        let p1 = [60.0, 60.0];
        let trimmed =
            trim_curve_endpoints(p0, c0, c1, p1, 5.0, 5.0, 1.0).expect("non-collapsing trim");
        let (p0t, _c0t, _c1t, p1t) = trimmed;

        // Start tangent is +Y, so trimmed p0 should only move in +Y.
        assert!(approx_eq(p0t[0], 0.0, 1e-4), "p0t x = {}", p0t[0]);
        assert!(approx_eq(p0t[1], 6.0, 1e-4), "p0t y = {}", p0t[1]);

        // End tangent is +X (p1 - c1 = (30, 0) normalised), so trimmed
        // p1 should move along the -X direction.
        assert!(approx_eq(p1t[1], 60.0, 1e-4), "p1t y = {}", p1t[1]);
        assert!(approx_eq(p1t[0], 60.0 - 6.0, 1e-4), "p1t x = {}", p1t[0]);
    }

    #[test]
    fn curve_trim_recomputes_control_handles_from_trimmed_endpoints() {
        // With clean tangents and the handle length preserved, the new
        // control points should lie along the original tangents at the
        // original handle distance from the trimmed endpoints.
        let p0 = [0.0_f32, 0.0];
        let c0 = [10.0, 0.0]; // handle length 10 along +X
        let c1 = [90.0, 0.0];
        let p1 = [100.0, 0.0];
        let trimmed =
            trim_curve_endpoints(p0, c0, c1, p1, 4.0, 4.0, 1.0).expect("non-collapsing trim");
        let (p0t, c0t, c1t, p1t) = trimmed;

        // p0 trims to (5, 0); c0 must be p0t + 10 × (+X) = (15, 0).
        assert!(approx_eq_pt(p0t, [5.0, 0.0], 1e-4));
        assert!(approx_eq_pt(c0t, [15.0, 0.0], 1e-4));
        // p1 trims to (95, 0); c1 = p1t - 10 × (+X) = (85, 0).
        assert!(approx_eq_pt(p1t, [95.0, 0.0], 1e-4));
        assert!(approx_eq_pt(c1t, [85.0, 0.0], 1e-4));
    }

    #[test]
    fn curve_trim_falls_back_to_straight_line_on_degenerate_handles() {
        // Both control points coincide with their endpoints → handles
        // have zero length, so the trimmer must fall back to the
        // straight-line tangent between p0 and p1.
        let p0 = [0.0_f32, 0.0];
        let p1 = [20.0, 0.0];
        let trimmed =
            trim_curve_endpoints(p0, p0, p1, p1, 2.0, 2.0, 0.5).expect("non-collapsing trim");
        let (p0t, _c0t, _c1t, p1t) = trimmed;
        // The fallback tangent is the straight-line direction between
        // p0 and p1, so both trimmed points remain on the x-axis.
        assert!(approx_eq(p0t[1], 0.0, 1e-4));
        assert!(approx_eq(p1t[1], 0.0, 1e-4));
        assert!(approx_eq(p0t[0], 2.5, 1e-4));
        assert!(approx_eq(p1t[0], 17.5, 1e-4));
    }

    #[test]
    fn curve_trim_collapses_when_straight_line_collapses() {
        // Overlapping nodes must report collapse consistently whether
        // the edge geometry is a line or a curve.
        assert!(
            trim_curve_endpoints(
                [0.0, 0.0],
                [5.0, 5.0],
                [0.0, -5.0],
                [5.0, 0.0],
                20.0,
                20.0,
                1.0
            )
            .is_none()
        );
    }
}
