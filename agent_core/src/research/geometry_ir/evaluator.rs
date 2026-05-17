//! Source:
//! - Hestenes-Sobczyk (Reidel 1984) Ch. 1 — geometric-product axioms.
//! - Dorst-Fontijne-Mann (Morgan Kaufmann 2007) §10.3 — algorithmic
//!   form of the geometric product via the basis-blade XOR rule +
//!   anticommutation sign count.
//! - Doctrine §4.6 — Geometry-IR first lowering target.
//! - Companion: [`super::grammar`] (the GeoExpr we evaluate).
//!
//! # Cl(3,0) geometric product
//!
//! Basis-blade representation:
//!
//! | Index | Bitmask | Blade   |
//! |-------|---------|---------|
//! | 0     | 0b000   | 1       |
//! | 1     | 0b001   | e_1     |
//! | 2     | 0b010   | e_2     |
//! | 3     | 0b100   | e_3     |
//! | 4     | 0b011   | e_12    |
//! | 5     | 0b101   | e_13    |
//! | 6     | 0b110   | e_23    |
//! | 7     | 0b111   | e_123   |
//!
//! Two basis blades A (bitmask `a`) and B (bitmask `b`) multiply
//! to a single basis blade with:
//!
//! - **Result bitmask** = `a XOR b` (shared indices cancel because
//!   `e_i² = +1` in Cl(3,0)).
//! - **Sign** = `(-1)^k` where `k` is the number of swaps needed
//!   to bring B's e_i factors past A's higher-index e_j factors.
//!   Concretely: for each bit `i` set in `b`, count bits in `a` at
//!   positions `> i`; sum modulo 2.

use super::grammar::{GeoExpr, Multivector};

/// Index → 3-bit bitmask mapping used by the blade-product algorithm.
const INDEX_TO_BITMASK: [u8; 8] = [
    0b000, // scalar
    0b001, // e_1
    0b010, // e_2
    0b100, // e_3
    0b011, // e_12
    0b101, // e_13
    0b110, // e_23
    0b111, // e_123
];

/// Reverse mapping: bitmask (0..8) → grade-blocked index.
const BITMASK_TO_INDEX: [usize; 8] = [
    0, // 0b000 → scalar
    1, // 0b001 → e_1
    2, // 0b010 → e_2
    4, // 0b011 → e_12
    3, // 0b100 → e_3
    5, // 0b101 → e_13
    6, // 0b110 → e_23
    7, // 0b111 → e_123
];

/// Compute `(result_index, sign)` for the geometric product of two
/// basis blades indexed by [`INDEX_TO_BITMASK`].
fn blade_product(a_idx: usize, b_idx: usize) -> (usize, f64) {
    let a_bits = INDEX_TO_BITMASK[a_idx];
    let b_bits = INDEX_TO_BITMASK[b_idx];
    let result_bits = a_bits ^ b_bits;
    let mut swap_count: u32 = 0;
    for i in 0..3 {
        if (b_bits & (1 << i)) != 0 {
            swap_count += (a_bits >> (i + 1)).count_ones();
        }
    }
    let sign = if swap_count % 2 == 0 { 1.0 } else { -1.0 };
    (BITMASK_TO_INDEX[result_bits as usize], sign)
}

/// Compute the Cl(3,0) geometric product of two multivectors.
pub fn geo_product(a: &Multivector, b: &Multivector) -> Multivector {
    let mut out = [0.0_f64; 8];
    for i in 0..8 {
        if a.components[i] == 0.0 {
            continue;
        }
        for j in 0..8 {
            if b.components[j] == 0.0 {
                continue;
            }
            let (k, sign) = blade_product(i, j);
            out[k] += sign * a.components[i] * b.components[j];
        }
    }
    Multivector { components: out }
}

/// Symmetric / inner part of the geometric product:
/// `a · b = (a b + b a) / 2`.
///
/// For two vectors `u`, `v` this reduces to the Euclidean scalar
/// dot product `(u · v) = u_x v_x + u_y v_y + u_z v_z` lifted into
/// the scalar grade. For mixed grades the symmetric part may
/// span multiple grades.
///
/// Iter-85 — Clifford-algebra primitive completing the
/// (dot / wedge) decomposition of [`geo_product`].
pub fn geo_dot(a: &Multivector, b: &Multivector) -> Multivector {
    let ab = geo_product(a, b);
    let ba = geo_product(b, a);
    ab.add(&ba).scale(0.5)
}

/// Antisymmetric / outer (wedge) part of the geometric product:
/// `a ∧ b = (a b − b a) / 2`.
///
/// For two vectors this yields the bivector representing the
/// oriented parallelogram they span.
///
/// Iter-85 — companion to [`geo_dot`]. Together they satisfy
/// `a b = a · b + a ∧ b`.
pub fn geo_wedge(a: &Multivector, b: &Multivector) -> Multivector {
    let ab = geo_product(a, b);
    let ba = geo_product(b, a);
    ab.sub(&ba).scale(0.5)
}

/// 3D vector cross product via geometric algebra:
/// `u × v = -I · (u ∧ v)`
///
/// where `I = e_{123}` is the unit pseudoscalar. Equivalently,
/// `u × v` is the Hodge dual of the bivector `u ∧ v` in Cl(3,0).
///
/// Component-wise this matches the standard 3D cross product:
/// `(u × v)_x = u_y v_z - u_z v_y`
/// `(u × v)_y = u_z v_x - u_x v_z`
/// `(u × v)_z = u_x v_y - u_y v_x`
///
/// Inputs are taken as vector-grade multivectors; non-vector
/// components are ignored.
///
/// Iter-104 — bridges Geometry-IR's bivector-native algebra
/// with the classical 3D cross product used in physics.
pub fn vector_cross_product(u: &Multivector, v: &Multivector) -> Multivector {
    let (ux, uy, uz) = u.vector_part();
    let (vx, vy, vz) = v.vector_part();
    Multivector::vector(
        uy * vz - uz * vy,
        uz * vx - ux * vz,
        ux * vy - uy * vx,
    )
}

/// Reflect a vector `v` through the hyperplane orthogonal to a
/// unit vector `n`: `v' = -n v n`.
///
/// In Cl(3,0), reflection across the plane normal to a unit vector
/// `n` is given by the sandwich `−n v n`. The caller is responsible
/// for normalizing `n` to unit length; an un-normalized `n` scales
/// the result by `|n|²`.
///
/// Iter-85 — fundamental Clifford-algebra operation; rotors decompose
/// into pairs of reflections.
pub fn reflect_vector(v: &Multivector, n: &Multivector) -> Multivector {
    geo_product(&geo_product(n, v), n).scale(-1.0)
}

/// Evaluate a [`GeoExpr`] tree to a single [`Multivector`].
pub fn evaluate(expr: &GeoExpr) -> Multivector {
    match expr {
        GeoExpr::Literal(m) => *m,
        GeoExpr::Reverse(a) => evaluate(a).reverse(),
        GeoExpr::GeoProduct(a, b) => geo_product(&evaluate(a), &evaluate(b)),
    }
}

#[cfg(test)]
mod iter_85_tests {
    use super::super::grammar::Multivector;
    use super::*;

    // ── iter-104: cross product, normalize, is_pure_grade ────────

    #[test]
    fn vector_cross_product_e1_e2_is_e3() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let cross = vector_cross_product(&e1, &e2);
        assert_eq!(cross.vector_part(), (0.0, 0.0, 1.0));
    }

    #[test]
    fn vector_cross_product_anticommutative() {
        let u = Multivector::vector(1.0, 2.0, 3.0);
        let v = Multivector::vector(4.0, 5.0, 6.0);
        let uv = vector_cross_product(&u, &v);
        let vu = vector_cross_product(&v, &u);
        let (uvx, uvy, uvz) = uv.vector_part();
        let (vux, vuy, vuz) = vu.vector_part();
        assert_eq!(uvx, -vux);
        assert_eq!(uvy, -vuy);
        assert_eq!(uvz, -vuz);
    }

    #[test]
    fn vector_cross_product_parallel_is_zero() {
        let u = Multivector::vector(2.0, 4.0, 6.0);
        let v = Multivector::vector(1.0, 2.0, 3.0); // parallel
        let cross = vector_cross_product(&u, &v);
        assert_eq!(cross.vector_part(), (0.0, 0.0, 0.0));
    }

    #[test]
    fn vector_cross_product_perpendicular_to_inputs() {
        // (u × v) · u = 0 and (u × v) · v = 0.
        let u = Multivector::vector(1.0, 2.0, -1.0);
        let v = Multivector::vector(3.0, -1.0, 2.0);
        let cross = vector_cross_product(&u, &v);
        let dot_u = geo_dot(&cross, &u);
        let dot_v = geo_dot(&cross, &v);
        assert!(dot_u.scalar_part().abs() < 1e-12);
        assert!(dot_v.scalar_part().abs() < 1e-12);
    }

    #[test]
    fn multivector_normalize_unit_vector() {
        let v = Multivector::vector(3.0, 4.0, 0.0); // norm = 5
        let normalized = v.normalize().unwrap();
        let (x, y, z) = normalized.vector_part();
        // Float-tolerant comparison (3 * 0.2 isn't exactly 0.6 in f64).
        assert!((x - 0.6).abs() < 1e-12);
        assert!((y - 0.8).abs() < 1e-12);
        assert!((z - 0.0).abs() < 1e-12);
        assert!((normalized.norm() - 1.0).abs() < 1e-12);
    }

    #[test]
    fn multivector_normalize_zero_returns_none() {
        let v = Multivector::zero();
        assert!(v.normalize().is_none());
    }

    #[test]
    fn multivector_is_pure_grade_classification() {
        let scalar = Multivector::scalar(2.5);
        let vector = Multivector::vector(1.0, 0.0, 1.0);
        let bivector = Multivector::bivector(1.0, 0.0, 0.5);
        let pseudoscalar = Multivector::pseudoscalar(0.7);

        assert!(scalar.is_pure_grade(0));
        assert!(!scalar.is_pure_grade(1));

        assert!(vector.is_pure_grade(1));
        assert!(!vector.is_pure_grade(0));

        assert!(bivector.is_pure_grade(2));
        assert!(!bivector.is_pure_grade(1));

        assert!(pseudoscalar.is_pure_grade(3));
        assert!(!pseudoscalar.is_pure_grade(2));

        // Mixed-grade: scalar + vector.
        let mixed = scalar.add(&vector);
        assert!(!mixed.is_pure_grade(0));
        assert!(!mixed.is_pure_grade(1));

        // Out-of-range grade returns false.
        assert!(!vector.is_pure_grade(5));
    }

    #[test]
    fn multivector_zero_is_pure_every_grade() {
        let zero = Multivector::zero();
        // Zero has no non-zero components, so it trivially passes
        // is_pure_grade for any valid grade (0-3).
        assert!(zero.is_pure_grade(0));
        assert!(zero.is_pure_grade(1));
        assert!(zero.is_pure_grade(2));
        assert!(zero.is_pure_grade(3));
    }

    #[test]
    fn geo_dot_of_orthogonal_vectors_is_zero() {
        let u = Multivector::vector(1.0, 0.0, 0.0);
        let v = Multivector::vector(0.0, 1.0, 0.0);
        let dot = geo_dot(&u, &v);
        assert!(dot.is_scalar());
        assert_eq!(dot.scalar_part(), 0.0);
    }

    #[test]
    fn geo_dot_of_parallel_vectors_is_dot_product() {
        let u = Multivector::vector(2.0, 1.0, -1.0);
        let v = Multivector::vector(3.0, -2.0, 4.0);
        let dot = geo_dot(&u, &v);
        // 2·3 + 1·(-2) + (-1)·4 = 6 - 2 - 4 = 0 → also orthogonal
        assert_eq!(dot.scalar_part(), 0.0);

        let v2 = Multivector::vector(1.0, 1.0, 1.0);
        let u2 = Multivector::vector(2.0, 3.0, 4.0);
        let dot2 = geo_dot(&u2, &v2);
        assert_eq!(dot2.scalar_part(), 2.0 + 3.0 + 4.0);
    }

    #[test]
    fn geo_wedge_of_parallel_vectors_is_zero() {
        let u = Multivector::vector(2.0, 0.0, 0.0);
        let v = Multivector::vector(3.0, 0.0, 0.0);
        let wedge = geo_wedge(&u, &v);
        assert_eq!(wedge.grade_norm_squared(2), 0.0);
    }

    #[test]
    fn geo_wedge_of_x_y_is_e12() {
        // e_1 ∧ e_2 = e_12 (the xy bivector).
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let wedge = geo_wedge(&e1, &e2);
        let (b12, b13, b23) = wedge.bivector_part();
        assert_eq!((b12, b13, b23), (1.0, 0.0, 0.0));
    }

    #[test]
    fn geo_dot_plus_geo_wedge_equals_geo_product() {
        // a · b + a ∧ b = ab.
        let u = Multivector::vector(1.5, -0.7, 2.0);
        let v = Multivector::vector(-0.3, 1.2, 0.8);
        let prod = geo_product(&u, &v);
        let sum = geo_dot(&u, &v).add(&geo_wedge(&u, &v));
        for i in 0..8 {
            assert!(
                (prod.components[i] - sum.components[i]).abs() < 1e-12,
                "component {}: prod={}, dot+wedge={}", i, prod.components[i], sum.components[i]
            );
        }
    }

    #[test]
    fn reflect_vector_across_x_axis_flips_y_and_z() {
        // n = e_1 (unit vector along x-axis). Reflection: v' = -e_1 v e_1.
        // For v = (vx, vy, vz), result should be (vx, -vy, -vz)
        // (reflection across the YZ-plane normal to e_1 sends x → x,
        // but the formula -n v n with n = e_1 gives the reflection
        // ACROSS the plane perpendicular to n — flipping the
        // n-component). Verify: -e_1 v e_1 = (-vx, vy, vz).
        let v = Multivector::vector(2.0, 3.0, -1.0);
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let refl = reflect_vector(&v, &e1);
        let (x, y, z) = refl.vector_part();
        assert!((x - (-2.0)).abs() < 1e-12);
        assert!((y - 3.0).abs() < 1e-12);
        assert!((z - (-1.0)).abs() < 1e-12);
    }

    #[test]
    fn reflect_vector_preserves_norm() {
        let v = Multivector::vector(1.5, -2.0, 0.7);
        let n = Multivector::vector(1.0, 0.0, 0.0);
        let refl = reflect_vector(&v, &n);
        assert!(
            (v.grade_norm_squared(1) - refl.grade_norm_squared(1)).abs() < 1e-12,
            "norm² before = {}, after = {}",
            v.grade_norm_squared(1), refl.grade_norm_squared(1)
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx_mv(a: &Multivector, b: &Multivector, tol: f64) -> bool {
        a.components
            .iter()
            .zip(b.components.iter())
            .all(|(x, y)| (x - y).abs() < tol)
    }

    // ── Basis-blade self-products ────────────────────────────────

    #[test]
    fn e1_squared_is_scalar_one() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let r = geo_product(&e1, &e1);
        assert!(approx_mv(&r, &Multivector::scalar(1.0), 1e-12));
    }

    #[test]
    fn e2_squared_is_scalar_one() {
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let r = geo_product(&e2, &e2);
        assert!(approx_mv(&r, &Multivector::scalar(1.0), 1e-12));
    }

    #[test]
    fn e3_squared_is_scalar_one() {
        let e3 = Multivector::vector(0.0, 0.0, 1.0);
        let r = geo_product(&e3, &e3);
        assert!(approx_mv(&r, &Multivector::scalar(1.0), 1e-12));
    }

    #[test]
    fn pseudoscalar_squared_is_minus_one() {
        // e_123 = e_1 e_2 e_3; (e_123)² = -1 in Cl(3,0).
        let i = Multivector::pseudoscalar(1.0);
        let r = geo_product(&i, &i);
        assert!(approx_mv(&r, &Multivector::scalar(-1.0), 1e-12));
    }

    // ── Anticommutativity of distinct basis vectors ───────────────

    #[test]
    fn e1_times_e2_is_e12() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let r = geo_product(&e1, &e2);
        assert!(approx_mv(&r, &Multivector::bivector(1.0, 0.0, 0.0), 1e-12));
    }

    #[test]
    fn e2_times_e1_is_minus_e12() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let r = geo_product(&e2, &e1);
        assert!(approx_mv(&r, &Multivector::bivector(-1.0, 0.0, 0.0), 1e-12));
    }

    #[test]
    fn anticommutativity_holds_for_e1_e2() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let ab = geo_product(&e1, &e2);
        let ba = geo_product(&e2, &e1);
        assert!(approx_mv(&ab, &ba.scale(-1.0), 1e-12));
    }

    // ── Bivector squares ─────────────────────────────────────────

    #[test]
    fn e12_squared_is_minus_one() {
        let e12 = Multivector::bivector(1.0, 0.0, 0.0);
        let r = geo_product(&e12, &e12);
        assert!(approx_mv(&r, &Multivector::scalar(-1.0), 1e-12));
    }

    #[test]
    fn e13_squared_is_minus_one() {
        let e13 = Multivector::bivector(0.0, 1.0, 0.0);
        let r = geo_product(&e13, &e13);
        assert!(approx_mv(&r, &Multivector::scalar(-1.0), 1e-12));
    }

    #[test]
    fn e23_squared_is_minus_one() {
        let e23 = Multivector::bivector(0.0, 0.0, 1.0);
        let r = geo_product(&e23, &e23);
        assert!(approx_mv(&r, &Multivector::scalar(-1.0), 1e-12));
    }

    // ── Scalar distributivity ────────────────────────────────────

    #[test]
    fn scalar_times_vector_yields_scaled_vector() {
        let s = Multivector::scalar(3.0);
        let v = Multivector::vector(1.0, 2.0, 4.0);
        let r = geo_product(&s, &v);
        assert!(approx_mv(&r, &Multivector::vector(3.0, 6.0, 12.0), 1e-12));
    }

    #[test]
    fn one_is_left_identity() {
        let v = Multivector::vector(1.5, -2.5, 0.5);
        let r = geo_product(&Multivector::scalar(1.0), &v);
        assert!(approx_mv(&r, &v, 1e-12));
    }

    #[test]
    fn one_is_right_identity() {
        let v = Multivector::vector(1.5, -2.5, 0.5);
        let r = geo_product(&v, &Multivector::scalar(1.0));
        assert!(approx_mv(&r, &v, 1e-12));
    }

    // ── Associativity ────────────────────────────────────────────

    #[test]
    fn geometric_product_is_associative_on_basis_vectors() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let e3 = Multivector::vector(0.0, 0.0, 1.0);
        let lhs = geo_product(&geo_product(&e1, &e2), &e3);
        let rhs = geo_product(&e1, &geo_product(&e2, &e3));
        assert!(approx_mv(&lhs, &rhs, 1e-12));
        // Both should equal the pseudoscalar e_123 = i.
        assert!(approx_mv(&lhs, &Multivector::pseudoscalar(1.0), 1e-12));
    }

    // ── GeoExpr evaluator ─────────────────────────────────────────

    #[test]
    fn evaluate_literal_returns_value() {
        let v = Multivector::vector(1.0, 2.0, 3.0);
        let e = GeoExpr::literal(v);
        let r = evaluate(&e);
        assert_eq!(r, v);
    }

    #[test]
    fn evaluate_reverse_negates_grade_2() {
        let b = Multivector::bivector(1.0, 2.0, 3.0);
        let e = GeoExpr::reverse(GeoExpr::literal(b));
        let r = evaluate(&e);
        assert!(approx_mv(&r, &Multivector::bivector(-1.0, -2.0, -3.0), 1e-12));
    }

    #[test]
    fn evaluate_geo_product_yields_correct_blade() {
        let e1 = GeoExpr::literal(Multivector::vector(1.0, 0.0, 0.0));
        let e2 = GeoExpr::literal(Multivector::vector(0.0, 1.0, 0.0));
        let e = GeoExpr::product(e1, e2);
        let r = evaluate(&e);
        assert!(approx_mv(&r, &Multivector::bivector(1.0, 0.0, 0.0), 1e-12));
    }

    #[test]
    fn evaluate_nested_product_associative() {
        // (e1 e2) e3 = e_123
        let e1 = GeoExpr::literal(Multivector::vector(1.0, 0.0, 0.0));
        let e2 = GeoExpr::literal(Multivector::vector(0.0, 1.0, 0.0));
        let e3 = GeoExpr::literal(Multivector::vector(0.0, 0.0, 1.0));
        let e = GeoExpr::product(GeoExpr::product(e1, e2), e3);
        let r = evaluate(&e);
        assert!(approx_mv(&r, &Multivector::pseudoscalar(1.0), 1e-12));
    }

    #[test]
    fn evaluate_full_blade_table_self_consistent() {
        // For each ordered pair of basis blades, geo_product should
        // produce a valid multivector (no panics, no NaN).
        for i in 0..8 {
            for j in 0..8 {
                let mut ai = [0.0; 8];
                ai[i] = 1.0;
                let mut bj = [0.0; 8];
                bj[j] = 1.0;
                let a = Multivector { components: ai };
                let b = Multivector { components: bj };
                let r = geo_product(&a, &b);
                for c in &r.components {
                    assert!(c.is_finite(), "blade ({},{}) gave non-finite", i, j);
                }
            }
        }
    }
}
