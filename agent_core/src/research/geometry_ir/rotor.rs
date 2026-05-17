//! Source:
//! - Dorst-Fontijne-Mann (Morgan Kaufmann 2007) §10.3 — rotor
//!   sandwich `v' = R v R̃` for 3D rotations. Rotor for angle θ
//!   around unit bivector B: R = exp(-θB/2) = cos(θ/2) − sin(θ/2)·B
//!   (the sign depends on chirality convention; we use the form
//!   that produces a positive rotation around B's plane normal).
//! - Hestenes-Sobczyk (Reidel 1984) Ch. 1 — geometric-product
//!   axioms the rotor sandwich rests on.
//! - Doctrine §4.6 + §5 row Geometry-IR — rotor sandwich as the
//!   §4.I:895 lowering target.
//! - Companion: [`super::evaluator::geo_product`] and
//!   [`super::grammar::Multivector::reverse`].
//!
//! # Rotor convention
//!
//! For a unit bivector B in 3D and rotation angle θ, the rotor:
//!
//! ```text
//! R = cos(θ/2) + sin(θ/2) · B
//! ```
//!
//! rotates a vector `v` by `θ` in the plane of `B`:
//!
//! ```text
//! v' = R̃ v R   (right-acting convention)
//! ```
//!
//! Equivalently `v' = R v R̃` reverses the rotation direction.
//! This module uses the **right-acting** convention so that
//! `R = exp(-θB/2)` with B = e_12 sends e_1 → e_2 for θ = π/2.

use super::evaluator::geo_product;
use super::grammar::Multivector;

/// Construct a rotor from a rotation angle (radians) and a unit
/// bivector specified by its (b12, b13, b23) components. The
/// caller is responsible for ensuring the bivector is unit-norm
/// for a clean rotor; non-unit input still produces a valid
/// multivector but it will not be a pure rotation.
pub fn rotor_from_angle_and_bivector(
    angle: f64,
    b12: f64,
    b13: f64,
    b23: f64,
) -> Multivector {
    let half = angle * 0.5;
    let c = half.cos();
    let s = half.sin();
    let mut comp = [0.0_f64; 8];
    comp[0] = c;
    comp[4] = s * b12;
    comp[5] = s * b13;
    comp[6] = s * b23;
    Multivector { components: comp }
}

/// Identity rotor (R = 1; angle = 0).
pub fn rotor_identity() -> Multivector {
    Multivector::scalar(1.0)
}

/// Compose two rotors so the result applies `r1` first, then `r2`.
///
/// For the right-acting sandwich `v' = R̃ v R`, two rotations
/// stacked give:
///
/// ```text
/// v_2 = R̃_2 (R̃_1 v R_1) R_2 = (R̃_2 R̃_1) v (R_1 R_2)
///     = (R_1 R_2)~ v (R_1 R_2)
/// ```
///
/// so the equivalent combined rotor is `R_combined = R_1 R_2` —
/// **not** `R_2 R_1`. This function returns `geo_product(r1, r2)`.
pub fn rotor_compose(r1: &Multivector, r2: &Multivector) -> Multivector {
    geo_product(r1, r2)
}

/// Decompose a unit rotor into its rotation angle and unit bivector.
///
/// For a rotor `R = cos(θ/2) + sin(θ/2)·B̂` (per
/// [`rotor_from_angle_and_bivector`] convention):
/// - scalar part `c = cos(θ/2)`
/// - bivector part `sin(θ/2)·B̂` (3 components in 3D)
///
/// Returns `Some((θ, (b12, b13, b23)))` where the bivector
/// components form the unit bivector `B̂`. Returns `None` if the
/// rotor is degenerate (zero bivector part — i.e. rotation by 0).
///
/// The recovered angle is in `[0, 2π)`.
///
/// Iter-131 — inverse of [`rotor_from_angle_and_bivector`].
pub fn rotor_to_angle_and_bivector(rotor: &Multivector) -> Option<(f64, (f64, f64, f64))> {
    let c = rotor.scalar_part();
    let (b12, b13, b23) = rotor.bivector_part();
    let sin_half_sq = b12 * b12 + b13 * b13 + b23 * b23;
    if sin_half_sq < 1e-24 {
        return None;
    }
    let sin_half = sin_half_sq.sqrt();
    let angle = 2.0 * sin_half.atan2(c);
    let inv = 1.0 / sin_half;
    Some((angle, (b12 * inv, b13 * inv, b23 * inv)))
}

/// Compute a rotor that takes unit vector `u` to unit vector `v`.
///
/// Uses the standard GA construction: `R = (1 + u v) / |1 + u v|`.
/// Under this crate's right-acting sandwich `v' = R̃ u R` (see
/// [`rotate`]), this rotor satisfies `R̃ u R = v` exactly when
/// `u`, `v` are unit and `1 + uv ≠ 0`.
///
/// Returns `None` if `u` and `v` are anti-parallel (`u = -v`),
/// in which case `1 + uv = 0` and the rotor is undefined — the
/// caller must supply an arbitrary perpendicular bivector for
/// the 180° rotation.
///
/// Iter-117 — Dorst-Fontijne-Mann §13.2; useful for "align this
/// to that" computations in graphics, robotics, and physics.
pub fn rotor_from_two_vectors(u: &Multivector, v: &Multivector) -> Option<Multivector> {
    // Right-acting convention: R = (1 + u v) / |1 + u v|.
    let uv = geo_product(u, v);
    let unnormalized = Multivector::scalar(1.0).add(&uv);
    let n2 = unnormalized.norm_squared();
    if n2 < 1e-24 {
        return None;
    }
    let n = n2.sqrt();
    Some(unnormalized.scale(1.0 / n))
}

/// Rotor inverse: `R^{-1} = R̃ / ||R||²`.
///
/// For a unit rotor (||R|| = 1) this equals `R.reverse()` directly.
/// For non-unit rotors, the reverse must be scaled by `1 / ||R||²`
/// to satisfy `R · R^{-1} = 1`.
///
/// Returns `None` if `R` has zero norm (non-invertible).
///
/// Iter-111 — convenience wrapper around `reverse()` + `scale()`
/// + `norm_squared()` for clarity in inverse-rotation calls.
pub fn rotor_inverse(r: &Multivector) -> Option<Multivector> {
    let n2 = r.norm_squared();
    if n2 == 0.0 || !n2.is_finite() {
        None
    } else {
        Some(r.reverse().scale(1.0 / n2))
    }
}

/// Apply the rotor sandwich `v' = R̃ v R` to an arbitrary multivector
/// (not just vectors).
///
/// Bivectors transform the same way as vectors under rotation;
/// scalars and pseudoscalars are invariant. This function is an
/// alias for [`rotate`] but named to clarify that mixed-grade
/// inputs are supported.
///
/// Iter-180.
pub fn apply_rotor(m: &Multivector, r: &Multivector) -> Multivector {
    rotate(m, r)
}

/// Rotate a multivector by a rotor: `v' = R̃ v R` (right-acting).
/// Returns the same-grade multivector for grade-1 (vector) inputs;
/// general multivectors map through unchanged in grade structure.
pub fn rotate(v: &Multivector, r: &Multivector) -> Multivector {
    let r_rev = r.reverse();
    geo_product(&geo_product(&r_rev, v), r)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::f64::consts::PI;

    fn approx_mv(a: &Multivector, b: &Multivector, tol: f64) -> bool {
        a.components
            .iter()
            .zip(b.components.iter())
            .all(|(x, y)| (x - y).abs() < tol)
    }

    // ── iter-180: apply_rotor ─────────────────────────────────────

    #[test]
    fn apply_rotor_to_scalar_is_invariant() {
        let s = Multivector::scalar(3.5);
        let r = rotor_from_angle_and_bivector(0.7, 1.0, 0.0, 0.0);
        let out = apply_rotor(&s, &r);
        assert!(approx_mv(&out, &s, 1e-12));
    }

    #[test]
    fn apply_rotor_to_pseudoscalar_is_invariant() {
        // Use a unit bivector (1/√3 each) for a unit rotor; otherwise
        // R̃ I R = I · R̃R scales with |R|².
        let p = Multivector::pseudoscalar(2.0);
        let inv_sqrt_3 = 1.0 / 3.0_f64.sqrt();
        let r = rotor_from_angle_and_bivector(0.7, inv_sqrt_3, inv_sqrt_3, inv_sqrt_3);
        let out = apply_rotor(&p, &r);
        assert!(approx_mv(&out, &p, 1e-12));
    }

    #[test]
    fn apply_rotor_to_bivector_rotates_within_grade() {
        let b = Multivector::e12();
        let r = rotor_from_angle_and_bivector(PI / 4.0, 0.0, 0.0, 1.0);
        let out = apply_rotor(&b, &r);
        // Output should remain a bivector (no scalar/vector/pseudo components).
        assert_eq!(out.scalar_part(), 0.0);
        assert_eq!(out.vector_part(), (0.0, 0.0, 0.0));
        assert_eq!(out.pseudoscalar_part(), 0.0);
    }

    #[test]
    fn apply_rotor_matches_rotate_for_vector_input() {
        let v = Multivector::vector(1.0, 2.0, 3.0);
        let r = rotor_from_angle_and_bivector(0.5, 1.0, 0.0, 0.0);
        let a = apply_rotor(&v, &r);
        let b = rotate(&v, &r);
        assert!(approx_mv(&a, &b, 1e-12));
    }

    // ── iter-131: rotor_to_angle_and_bivector ─────────────────────

    #[test]
    fn rotor_to_angle_recovers_input_angle() {
        for theta in [0.3_f64, 1.0, std::f64::consts::FRAC_PI_2, 2.0, 3.0] {
            let r = rotor_from_angle_and_bivector(theta, 1.0, 0.0, 0.0);
            let (theta_back, _) = rotor_to_angle_and_bivector(&r).unwrap();
            assert!(
                (theta_back - theta).abs() < 1e-10,
                "θ={} → θ_back={}", theta, theta_back
            );
        }
    }

    #[test]
    fn rotor_to_angle_recovers_input_bivector_axis() {
        let r = rotor_from_angle_and_bivector(0.5, 1.0, 0.0, 0.0);
        let (_, axis) = rotor_to_angle_and_bivector(&r).unwrap();
        // Axis should be (1, 0, 0).
        assert!((axis.0 - 1.0).abs() < 1e-10);
        assert!(axis.1.abs() < 1e-10);
        assert!(axis.2.abs() < 1e-10);
    }

    #[test]
    fn rotor_to_angle_identity_returns_none() {
        let id = rotor_identity();
        assert!(rotor_to_angle_and_bivector(&id).is_none());
    }

    #[test]
    fn rotor_to_angle_diagonal_bivector_recovers() {
        // Use a UNIT bivector (1, 1, 1) / √3 so the rotor is
        // a clean rotation by angle 1.0.
        let inv_sqrt_3 = 1.0 / 3.0_f64.sqrt();
        let r = rotor_from_angle_and_bivector(1.0, inv_sqrt_3, inv_sqrt_3, inv_sqrt_3);
        let (theta_back, (b12, b13, b23)) = rotor_to_angle_and_bivector(&r).unwrap();
        assert!((theta_back - 1.0).abs() < 1e-10);
        assert!((b12 - inv_sqrt_3).abs() < 1e-10);
        assert!((b13 - inv_sqrt_3).abs() < 1e-10);
        assert!((b23 - inv_sqrt_3).abs() < 1e-10);
    }

    // ── iter-117: rotor_from_two_vectors ──────────────────────────

    #[test]
    fn rotor_from_same_vector_is_identity() {
        // R(u, u) = identity.
        let u = Multivector::vector(1.0, 0.0, 0.0);
        let r = rotor_from_two_vectors(&u, &u).unwrap();
        assert!(approx_mv(&r, &Multivector::scalar(1.0), 1e-12));
    }

    #[test]
    fn rotor_from_e1_to_e2_quarter_turn_in_xy_plane() {
        // R(e_1, e_2) should be a π/2 rotation in the xy-plane.
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let r = rotor_from_two_vectors(&e1, &e2).unwrap();
        // Apply to e_1: should give e_2.
        let rotated = rotate(&e1, &r);
        let (x, y, z) = rotated.vector_part();
        assert!((x - 0.0).abs() < 1e-12);
        assert!((y - 1.0).abs() < 1e-12);
        assert!((z - 0.0).abs() < 1e-12);
    }

    #[test]
    fn rotor_from_unit_to_unit_is_unit_rotor() {
        // The rotor returned should always be unit-norm.
        let u = Multivector::vector(0.6, 0.8, 0.0); // unit vector
        let v = Multivector::vector(0.0, 0.0, 1.0); // unit vector
        let r = rotor_from_two_vectors(&u, &v).unwrap();
        assert!(r.is_approximately_unit_rotor(1e-12), "norm² = {}", r.norm_squared());
    }

    #[test]
    fn rotor_from_two_vectors_actually_aligns() {
        // R(u, v) applied to u should produce v.
        let u = Multivector::vector(0.6, 0.8, 0.0);
        let v = Multivector::vector(0.0, 0.6, 0.8);
        let r = rotor_from_two_vectors(&u, &v).unwrap();
        let rotated = rotate(&u, &r);
        let (rx, ry, rz) = rotated.vector_part();
        let (vx, vy, vz) = v.vector_part();
        assert!((rx - vx).abs() < 1e-10);
        assert!((ry - vy).abs() < 1e-10);
        assert!((rz - vz).abs() < 1e-10);
    }

    #[test]
    fn rotor_from_anti_parallel_returns_none() {
        // R(u, -u) is undefined.
        let u = Multivector::vector(1.0, 0.0, 0.0);
        let neg_u = Multivector::vector(-1.0, 0.0, 0.0);
        assert!(rotor_from_two_vectors(&u, &neg_u).is_none());
    }

    // ── iter-111: rotor_inverse ───────────────────────────────────

    #[test]
    fn rotor_inverse_of_identity_is_identity() {
        let id = rotor_identity();
        let inv = rotor_inverse(&id).unwrap();
        assert!(approx_mv(&inv, &id, 1e-12));
    }

    #[test]
    fn rotor_inverse_of_unit_rotor_equals_reverse() {
        // Build a unit rotor (angle = π/3 around e_12).
        let r = rotor_from_angle_and_bivector(PI / 3.0, 1.0, 0.0, 0.0);
        let inv = rotor_inverse(&r).unwrap();
        let rev = r.reverse();
        assert!(approx_mv(&inv, &rev, 1e-12));
    }

    #[test]
    fn rotor_inverse_composes_to_identity() {
        // R · R^{-1} = 1.
        let r = rotor_from_angle_and_bivector(0.7, 0.0, 1.0, 0.0);
        let inv = rotor_inverse(&r).unwrap();
        let product = geo_product(&r, &inv);
        assert!(approx_mv(&product, &Multivector::scalar(1.0), 1e-12));
    }

    #[test]
    fn rotor_inverse_of_zero_returns_none() {
        let zero = Multivector::zero();
        assert!(rotor_inverse(&zero).is_none());
    }

    #[test]
    fn rotor_inverse_rotates_back() {
        // Applying R then R^{-1} to a vector returns it unchanged.
        let r = rotor_from_angle_and_bivector(PI / 4.0, 0.0, 0.0, 1.0);
        let inv = rotor_inverse(&r).unwrap();
        let v = Multivector::vector(1.0, 2.0, 3.0);
        let rotated = rotate(&v, &r);
        let back = rotate(&rotated, &inv);
        assert!(approx_mv(&back, &v, 1e-12));
    }

    // ── Identity rotation ────────────────────────────────────────

    #[test]
    fn identity_rotor_is_one() {
        let r = rotor_identity();
        assert!(approx_mv(&r, &Multivector::scalar(1.0), 1e-12));
    }

    #[test]
    fn identity_rotation_returns_input_unchanged() {
        // §4.I:895 acceptance: identity rotation `R = 1` returns the
        // input unchanged.
        let v = Multivector::vector(1.5, -2.5, 0.5);
        let r = rotor_identity();
        let v_rotated = rotate(&v, &r);
        assert!(approx_mv(&v_rotated, &v, 1e-12));
    }

    #[test]
    fn zero_angle_rotor_is_identity() {
        let r = rotor_from_angle_and_bivector(0.0, 1.0, 0.0, 0.0);
        assert!(approx_mv(&r, &Multivector::scalar(1.0), 1e-12));
    }

    #[test]
    fn zero_angle_rotation_returns_input_unchanged() {
        let v = Multivector::vector(3.0, 4.0, 5.0);
        let r = rotor_from_angle_and_bivector(0.0, 0.0, 0.0, 1.0);
        assert!(approx_mv(&rotate(&v, &r), &v, 1e-12));
    }

    // ── π/2 rotation around e_12 ────────────────────────────────

    #[test]
    fn quarter_turn_around_e12_sends_e1_to_e2() {
        // R = cos(π/4) + sin(π/4) e_12; rotates by π/2 in e_12 plane.
        // Right-acting: e_1 → e_2.
        let r = rotor_from_angle_and_bivector(PI / 2.0, 1.0, 0.0, 0.0);
        let v = Multivector::vector(1.0, 0.0, 0.0);
        let rotated = rotate(&v, &r);
        assert!(
            approx_mv(&rotated, &Multivector::vector(0.0, 1.0, 0.0), 1e-9),
            "got {:?}", rotated.vector_part()
        );
    }

    #[test]
    fn quarter_turn_around_e12_sends_e2_to_minus_e1() {
        let r = rotor_from_angle_and_bivector(PI / 2.0, 1.0, 0.0, 0.0);
        let v = Multivector::vector(0.0, 1.0, 0.0);
        let rotated = rotate(&v, &r);
        assert!(
            approx_mv(&rotated, &Multivector::vector(-1.0, 0.0, 0.0), 1e-9),
            "got {:?}", rotated.vector_part()
        );
    }

    #[test]
    fn quarter_turn_around_e12_leaves_e3_unchanged() {
        // e_3 is orthogonal to the e_12 plane → unaffected.
        let r = rotor_from_angle_and_bivector(PI / 2.0, 1.0, 0.0, 0.0);
        let v = Multivector::vector(0.0, 0.0, 1.0);
        let rotated = rotate(&v, &r);
        assert!(approx_mv(&rotated, &v, 1e-9));
    }

    // ── π rotation cycles ───────────────────────────────────────

    #[test]
    fn half_turn_around_e12_sends_e1_to_minus_e1() {
        let r = rotor_from_angle_and_bivector(PI, 1.0, 0.0, 0.0);
        let v = Multivector::vector(1.0, 0.0, 0.0);
        let rotated = rotate(&v, &r);
        assert!(
            approx_mv(&rotated, &Multivector::vector(-1.0, 0.0, 0.0), 1e-9),
            "got {:?}", rotated.vector_part()
        );
    }

    #[test]
    fn full_turn_is_identity() {
        // 2π rotation → identity (vectorwise).
        let r = rotor_from_angle_and_bivector(2.0 * PI, 1.0, 0.0, 0.0);
        let v = Multivector::vector(1.0, 0.5, -0.5);
        let rotated = rotate(&v, &r);
        assert!(approx_mv(&rotated, &v, 1e-9));
    }

    // ── Composition law ─────────────────────────────────────────

    #[test]
    fn composition_law_two_quarter_turns_equals_half_turn() {
        // §4.I:895 acceptance: composition law for rotor sandwich.
        // R₁ = R₂ = quarter turn around e_12. R₁ then R₂ = half turn.
        let r_quarter = rotor_from_angle_and_bivector(PI / 2.0, 1.0, 0.0, 0.0);
        let r_combined = rotor_compose(&r_quarter, &r_quarter);
        let v = Multivector::vector(1.0, 0.0, 0.0);
        let r_half = rotor_from_angle_and_bivector(PI, 1.0, 0.0, 0.0);
        let by_compose = rotate(&v, &r_combined);
        let by_direct = rotate(&v, &r_half);
        assert!(
            approx_mv(&by_compose, &by_direct, 1e-9),
            "compose: {:?}; direct: {:?}", by_compose.vector_part(), by_direct.vector_part()
        );
    }

    #[test]
    fn composition_associative() {
        // (R₃ R₂) R₁ = R₃ (R₂ R₁) — geometric product is associative
        // (already established in evaluator.rs); this test exercises
        // the rotor-specific composition path.
        let r1 = rotor_from_angle_and_bivector(PI / 4.0, 1.0, 0.0, 0.0);
        let r2 = rotor_from_angle_and_bivector(PI / 3.0, 0.0, 1.0, 0.0);
        let r3 = rotor_from_angle_and_bivector(PI / 5.0, 0.0, 0.0, 1.0);
        let lhs = rotor_compose(&rotor_compose(&r1, &r2), &r3);
        let rhs = rotor_compose(&r1, &rotor_compose(&r2, &r3));
        assert!(approx_mv(&lhs, &rhs, 1e-9));
    }

    #[test]
    fn rotation_preserves_vector_norm() {
        // Rotation is an isometry: |v'| = |v| for a vector.
        let v = Multivector::vector(2.0, -3.0, 1.0);
        let v_norm_sq = v.grade_norm_squared(1);
        let r = rotor_from_angle_and_bivector(PI / 3.0, 0.5_f64.sqrt(), 0.0, 0.5_f64.sqrt());
        let v_rot = rotate(&v, &r);
        let v_rot_norm_sq = v_rot.grade_norm_squared(1);
        assert!(
            (v_norm_sq - v_rot_norm_sq).abs() < 1e-9,
            "norm² before {} vs after {}", v_norm_sq, v_rot_norm_sq
        );
    }

    #[test]
    fn rotor_norm_is_one_for_unit_bivector() {
        // |R|² = cos²(θ/2) + sin²(θ/2)·|B|² = 1 when |B| = 1.
        let r = rotor_from_angle_and_bivector(1.234, 1.0, 0.0, 0.0);
        let r_norm_sq = r.grade_norm_squared(0) + r.grade_norm_squared(2);
        assert!((r_norm_sq - 1.0).abs() < 1e-12);
    }
}
