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

/// Compose two rotors: `R_combined = R_2 R_1`. The combined rotor
/// applies R_1 first, then R_2 (right-acting convention).
pub fn rotor_compose(r1: &Multivector, r2: &Multivector) -> Multivector {
    geo_product(r2, r1)
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
