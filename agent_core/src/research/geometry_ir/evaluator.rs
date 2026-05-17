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

/// Angle between two non-zero vectors `u, v`, returned in `[0, π]`.
///
/// `θ = arccos(u · v / (|u| · |v|))`.
///
/// Returns 0 if either vector is zero (degenerate case; caller
/// should guard against this).
///
/// Iter-123 — composes geo_dot + vector_part().
pub fn angle_between_vectors(u: &Multivector, v: &Multivector) -> f64 {
    let nu = u.grade_norm_squared(1).sqrt();
    let nv = v.grade_norm_squared(1).sqrt();
    if nu == 0.0 || nv == 0.0 {
        return 0.0;
    }
    let dot = geo_dot(u, v).scalar_part();
    let ratio = (dot / (nu * nv)).clamp(-1.0, 1.0);
    ratio.acos()
}

/// Scalar triple product `u · (v × w)` — the signed volume of the
/// parallelepiped spanned by `u, v, w`.
///
/// Iter-123 — classical 3D primitive useful for orientation checks
/// (positive = right-handed coordinate frame).
pub fn scalar_triple_product(u: &Multivector, v: &Multivector, w: &Multivector) -> f64 {
    let cross_vw = vector_cross_product(v, w);
    geo_dot(u, &cross_vw).scalar_part()
}

/// Project a vector `v` onto the plane spanned by a unit bivector
/// `B`: `proj_B(v) = (v ∧ B) · B^{-1}`.
///
/// For a unit bivector with `B² = -1` in Cl(3, 0), `B^{-1} = -B`,
/// so `proj_B(v) = -(v ∧ B) · B`. The wedge captures the
/// antisymmetric part of `vB` (the component of v inside the
/// plane); multiplying by `B^{-1}` rotates back into vector grade.
///
/// Iter-162 — geometric primitive for projection onto a 2D plane
/// embedded in 3D.
pub fn project_onto_bivector_plane(v: &Multivector, b: &Multivector) -> Multivector {
    let wedge = geo_wedge(v, b);
    // For unit B with B² = -1, B^{-1} = -B.
    geo_product(&wedge, b).scale(-1.0)
}

/// Reject a vector from a bivector plane (complementary to
/// [`project_onto_bivector_plane`]): `v − proj_B(v)`.
///
/// The result is the component of `v` perpendicular to the plane
/// of `B`.
///
/// Iter-162.
pub fn reject_from_bivector_plane(v: &Multivector, b: &Multivector) -> Multivector {
    let proj = project_onto_bivector_plane(v, b);
    v.sub(&proj)
}

/// Project vector `v` onto vector `n`:
/// `proj_n(v) = ((v · n) / (n · n)) · n`.
///
/// Returns the zero vector if `n` is zero (degenerate).
///
/// Iter-130 — standard vector decomposition primitive.
pub fn vector_projection(v: &Multivector, n: &Multivector) -> Multivector {
    let nn = geo_dot(n, n).scalar_part();
    if nn == 0.0 {
        return Multivector::zero();
    }
    let vn = geo_dot(v, n).scalar_part();
    n.scale(vn / nn)
}

/// Reject `v` from `n` (component of `v` perpendicular to `n`):
/// `rej_n(v) = v − proj_n(v)`.
///
/// Iter-130 — companion to [`vector_projection`]. Together they
/// decompose `v = proj_n(v) + rej_n(v)`.
pub fn vector_rejection(v: &Multivector, n: &Multivector) -> Multivector {
    let proj = vector_projection(v, n);
    v.sub(&proj)
}

/// Geometric inverse of a non-zero vector: `v^{-1} = v / (v · v)`.
///
/// Since `v · v = ||v||²` for a pure vector, the inverse points
/// in the same direction with magnitude `1/||v||`. Verified by
/// `v · v^{-1} = 1` in Cl(3, 0).
///
/// Returns `None` if `v` is the zero vector (non-invertible).
///
/// Iter-167 — Clifford-algebra division primitive.
pub fn vector_inverse(v: &Multivector) -> Option<Multivector> {
    let v2 = v.grade_norm_squared(1);
    if v2 == 0.0 {
        return None;
    }
    Some(v.scale(1.0 / v2))
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

    // ── iter-167: vector_inverse ──────────────────────────────────

    #[test]
    fn vector_inverse_unit_vector_is_self() {
        let e1 = Multivector::e1();
        let inv = vector_inverse(&e1).unwrap();
        assert_eq!(inv.vector_part(), (1.0, 0.0, 0.0));
    }

    #[test]
    fn vector_inverse_scales_correctly() {
        // v = (2, 0, 0); v·v = 4; v^{-1} = (0.5, 0, 0).
        let v = Multivector::vector(2.0, 0.0, 0.0);
        let inv = vector_inverse(&v).unwrap();
        assert_eq!(inv.vector_part(), (0.5, 0.0, 0.0));
    }

    #[test]
    fn vector_inverse_zero_returns_none() {
        let z = Multivector::zero();
        assert!(vector_inverse(&z).is_none());
    }

    #[test]
    fn vector_times_inverse_is_one() {
        // v · v^{-1} = 1 (scalar).
        let v = Multivector::vector(3.0, 4.0, 0.0); // |v|² = 25.
        let inv = vector_inverse(&v).unwrap();
        let product = geo_product(&v, &inv);
        assert!((product.scalar_part() - 1.0).abs() < 1e-12);
    }

    // ── iter-162: project_onto_bivector_plane ─────────────────────

    #[test]
    fn project_e3_onto_e12_plane_is_zero() {
        // e_3 is perpendicular to the xy-plane (e_12). Projection = 0.
        let e3 = Multivector::e3();
        let e12 = Multivector::e12();
        let proj = project_onto_bivector_plane(&e3, &e12);
        assert!((proj.vector_part().0).abs() < 1e-12);
        assert!((proj.vector_part().1).abs() < 1e-12);
        assert!((proj.vector_part().2).abs() < 1e-12);
    }

    #[test]
    fn reject_e3_from_e12_plane_is_e3() {
        // e_3 has no xy-component, so rejection = e_3.
        let e3 = Multivector::e3();
        let e12 = Multivector::e12();
        let rej = reject_from_bivector_plane(&e3, &e12);
        let (x, y, z) = rej.vector_part();
        assert!(x.abs() < 1e-12);
        assert!(y.abs() < 1e-12);
        assert!((z - 1.0).abs() < 1e-12);
    }

    #[test]
    fn project_plus_reject_equals_v() {
        // v = proj_B(v) + rej_B(v).
        let v = Multivector::vector(1.0, 2.0, 3.0);
        let b = Multivector::e12();
        let proj = project_onto_bivector_plane(&v, &b);
        let rej = reject_from_bivector_plane(&v, &b);
        let sum = proj.add(&rej);
        let (sx, sy, sz) = sum.vector_part();
        let (vx, vy, vz) = v.vector_part();
        assert!((sx - vx).abs() < 1e-12);
        assert!((sy - vy).abs() < 1e-12);
        assert!((sz - vz).abs() < 1e-12);
    }

    // ── iter-130: vector_projection + vector_rejection ────────────

    #[test]
    fn vector_projection_onto_axis_aligned() {
        // v = (3, 4, 0), n = e_1. proj = (3, 0, 0).
        let v = Multivector::vector(3.0, 4.0, 0.0);
        let n = Multivector::vector(1.0, 0.0, 0.0);
        let proj = vector_projection(&v, &n);
        assert_eq!(proj.vector_part(), (3.0, 0.0, 0.0));
    }

    #[test]
    fn vector_projection_onto_zero_returns_zero() {
        let v = Multivector::vector(1.0, 2.0, 3.0);
        let n = Multivector::zero();
        let proj = vector_projection(&v, &n);
        assert_eq!(proj.vector_part(), (0.0, 0.0, 0.0));
    }

    #[test]
    fn vector_projection_self_is_self() {
        // proj_v(v) = v.
        let v = Multivector::vector(1.0, 2.0, 3.0);
        let proj = vector_projection(&v, &v);
        assert!((proj.vector_part().0 - 1.0).abs() < 1e-12);
        assert!((proj.vector_part().1 - 2.0).abs() < 1e-12);
        assert!((proj.vector_part().2 - 3.0).abs() < 1e-12);
    }

    #[test]
    fn vector_rejection_orthogonal_to_n() {
        // rej_n(v) should be perpendicular to n.
        let v = Multivector::vector(3.0, 4.0, 5.0);
        let n = Multivector::vector(1.0, 0.0, 0.0);
        let rej = vector_rejection(&v, &n);
        let dot = geo_dot(&rej, &n).scalar_part();
        assert!(dot.abs() < 1e-12, "rej · n = {}", dot);
    }

    #[test]
    fn projection_plus_rejection_recovers_v() {
        // v = proj_n(v) + rej_n(v).
        let v = Multivector::vector(2.0, 3.0, -1.0);
        let n = Multivector::vector(1.0, 1.0, 0.0);
        let proj = vector_projection(&v, &n);
        let rej = vector_rejection(&v, &n);
        let sum = proj.add(&rej);
        let (sx, sy, sz) = sum.vector_part();
        let (vx, vy, vz) = v.vector_part();
        assert!((sx - vx).abs() < 1e-12);
        assert!((sy - vy).abs() < 1e-12);
        assert!((sz - vz).abs() < 1e-12);
    }

    // ── iter-123: angle_between + scalar_triple_product ───────────

    #[test]
    fn angle_orthogonal_is_pi_over_2() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let theta = angle_between_vectors(&e1, &e2);
        assert!((theta - std::f64::consts::FRAC_PI_2).abs() < 1e-12);
    }

    #[test]
    fn angle_parallel_is_zero() {
        let u = Multivector::vector(2.0, 0.0, 0.0);
        let v = Multivector::vector(3.0, 0.0, 0.0);
        let theta = angle_between_vectors(&u, &v);
        assert!(theta.abs() < 1e-12);
    }

    #[test]
    fn angle_anti_parallel_is_pi() {
        let u = Multivector::vector(1.0, 0.0, 0.0);
        let v = Multivector::vector(-2.0, 0.0, 0.0);
        let theta = angle_between_vectors(&u, &v);
        assert!((theta - std::f64::consts::PI).abs() < 1e-12);
    }

    #[test]
    fn angle_symmetric() {
        let u = Multivector::vector(1.0, 2.0, 0.0);
        let v = Multivector::vector(0.5, 1.5, 1.0);
        let a = angle_between_vectors(&u, &v);
        let b = angle_between_vectors(&v, &u);
        assert!((a - b).abs() < 1e-12);
    }

    #[test]
    fn angle_zero_vector_returns_zero_no_panic() {
        let u = Multivector::zero();
        let v = Multivector::vector(1.0, 2.0, 3.0);
        assert_eq!(angle_between_vectors(&u, &v), 0.0);
    }

    #[test]
    fn scalar_triple_product_basis_is_one() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let e3 = Multivector::vector(0.0, 0.0, 1.0);
        let v = scalar_triple_product(&e1, &e2, &e3);
        assert!((v - 1.0).abs() < 1e-12);
    }

    #[test]
    fn scalar_triple_product_left_handed_is_negative() {
        let e1 = Multivector::vector(1.0, 0.0, 0.0);
        let e2 = Multivector::vector(0.0, 1.0, 0.0);
        let e3 = Multivector::vector(0.0, 0.0, -1.0);
        let v = scalar_triple_product(&e1, &e2, &e3);
        assert!(v < 0.0);
    }

    #[test]
    fn scalar_triple_product_cyclic_invariant() {
        // u·(v×w) = v·(w×u) = w·(u×v).
        let u = Multivector::vector(1.0, 2.0, 3.0);
        let v = Multivector::vector(0.5, -0.7, 1.2);
        let w = Multivector::vector(-1.0, 0.4, 0.8);
        let uvw = scalar_triple_product(&u, &v, &w);
        let vwu = scalar_triple_product(&v, &w, &u);
        let wuv = scalar_triple_product(&w, &u, &v);
        assert!((uvw - vwu).abs() < 1e-12);
        assert!((vwu - wuv).abs() < 1e-12);
    }

    #[test]
    fn scalar_triple_product_coplanar_is_zero() {
        // If three vectors lie in the same plane (e.g. all in xy):
        // scalar triple product = 0.
        let u = Multivector::vector(1.0, 0.0, 0.0);
        let v = Multivector::vector(0.0, 1.0, 0.0);
        let w = Multivector::vector(2.0, 3.0, 0.0); // linear combo of u, v
        let v_triple = scalar_triple_product(&u, &v, &w);
        assert!(v_triple.abs() < 1e-12);
    }

    // ── iter-111: grade_projection ────────────────────────────────

    #[test]
    fn grade_projection_extracts_pure_grade() {
        // Build a mixed multivector: scalar + vector + bivector.
        let m = Multivector::scalar(2.0)
            .add(&Multivector::vector(1.0, 2.0, 3.0))
            .add(&Multivector::bivector(4.0, 5.0, 6.0));

        let scalar_only = m.grade_projection(0);
        assert_eq!(scalar_only.scalar_part(), 2.0);
        assert_eq!(scalar_only.vector_part(), (0.0, 0.0, 0.0));
        assert_eq!(scalar_only.bivector_part(), (0.0, 0.0, 0.0));

        let vector_only = m.grade_projection(1);
        assert_eq!(vector_only.scalar_part(), 0.0);
        assert_eq!(vector_only.vector_part(), (1.0, 2.0, 3.0));
        assert_eq!(vector_only.bivector_part(), (0.0, 0.0, 0.0));

        let bivector_only = m.grade_projection(2);
        assert_eq!(bivector_only.scalar_part(), 0.0);
        assert_eq!(bivector_only.vector_part(), (0.0, 0.0, 0.0));
        assert_eq!(bivector_only.bivector_part(), (4.0, 5.0, 6.0));
    }

    #[test]
    fn grade_projection_above_three_is_zero() {
        let m = Multivector::pseudoscalar(7.0);
        let zero = m.grade_projection(4);
        assert_eq!(zero.norm_squared(), 0.0);
    }

    #[test]
    fn grade_projection_idempotent() {
        // P_k(P_k(m)) = P_k(m).
        let m = Multivector::scalar(1.0)
            .add(&Multivector::vector(2.0, 0.0, 1.0))
            .add(&Multivector::pseudoscalar(3.0));
        for grade in 0..4 {
            let once = m.grade_projection(grade);
            let twice = once.grade_projection(grade);
            for (a, b) in once.components.iter().zip(twice.components.iter()) {
                assert_eq!(a, b);
            }
        }
    }

    #[test]
    fn grade_projection_sum_recovers_full_multivector() {
        // m = Σ_k P_k(m) — the multivector decomposes into its grade parts.
        let m = Multivector::scalar(1.0)
            .add(&Multivector::vector(2.0, 3.0, 4.0))
            .add(&Multivector::bivector(5.0, 6.0, 7.0))
            .add(&Multivector::pseudoscalar(8.0));
        let mut reconstructed = Multivector::zero();
        for grade in 0..4 {
            reconstructed = reconstructed.add(&m.grade_projection(grade));
        }
        for (a, b) in m.components.iter().zip(reconstructed.components.iter()) {
            assert_eq!(a, b);
        }
    }

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
