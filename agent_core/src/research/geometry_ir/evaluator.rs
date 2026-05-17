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

/// Evaluate a [`GeoExpr`] tree to a single [`Multivector`].
pub fn evaluate(expr: &GeoExpr) -> Multivector {
    match expr {
        GeoExpr::Literal(m) => *m,
        GeoExpr::Reverse(a) => evaluate(a).reverse(),
        GeoExpr::GeoProduct(a, b) => geo_product(&evaluate(a), &evaluate(b)),
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
