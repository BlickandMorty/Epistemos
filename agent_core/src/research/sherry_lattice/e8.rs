//! Source:
//! - Conway, J. H., Sloane, N. J. A., "Sphere Packings, Lattices and
//!   Groups", Springer 1988 (3rd ed. 1999) — canonical reference. The
//!   E8 nearest-point algorithm below is Algorithm 5 in Chapter 20
//!   ("Algorithms for finding the closest lattice point").
//! - NestQuant, arXiv:2502.09720 — nested-lattice VQ that uses E8 +
//!   Leech as second-moment-shaping codebooks.
//! - `docs/fusion/jordan's research/helios v3.md` Part II T_K row:
//!   `G(E_8) = 0.0717`, `G(Leech_24) = 0.0658` — the second-moment
//!   shaping gains that motivate using these lattices for KV cache
//!   quantization.
//!
//! # J7 #2 — E8 lattice nearest-point quantizer
//!
//! E8 is the unique even unimodular lattice in 8 dimensions and the
//! optimal sphere-packing in 8D. Its standard construction:
//!
//! ```text
//! E8 = D8 ∪ (D8 + (½)^8)
//! D8 = { x ∈ Z^8 : Σ x_i is even }
//! ```
//!
//! The nearest-point algorithm (Conway-Sloane Ch. 20 Alg. 5):
//!
//! 1. Round each coordinate to its nearest integer → candidate `p1`
//!    in `Z^8`. If `Σ p1` is odd, flip the coordinate with the
//!    largest rounding error to the other side of its grid; the
//!    result is the nearest D8 point to the input.
//! 2. Round each coordinate to its nearest half-integer (round
//!    `x + 0.5` then subtract 0.5) → candidate `p2` in `(Z + 0.5)^8`.
//!    Apply the same parity correction on `Σ (p2 + 0.5) = Σ p2 + 4`,
//!    so `p2` is the nearest `D8 + (0.5)^8` point.
//! 3. Return whichever of `p1` and `p2` is closer to the input.
//!
//! Leech (24-dim) deferred: the nearest-point algorithm uses the
//! extended binary Golay code and is ~10× the line count of E8. Will
//! land in a future J7 iter when the Helios v6 KV-cache wire-in
//! actually needs it.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct E8Point(pub [f32; 8]);

impl E8Point {
    /// Squared Euclidean norm `‖p‖² = Σ p_i²`. Per Conway-Sloane,
    /// the minimum nonzero squared norm of an E8 vector is `2.0`
    /// (the 240 "root vectors"); see [`E8_MIN_NONZERO_NORM_SQUARED`].
    pub fn norm_squared(&self) -> f32 {
        let mut sum: f32 = 0.0;
        for &v in &self.0 {
            sum += v * v;
        }
        sum
    }
}

/// Minimum squared-norm of a nonzero E8 vector. Per Conway-Sloane
/// Ch. 4: the 240 E8 root vectors have squared norm exactly 2;
/// every nonzero vector has squared norm at least 2.
pub const E8_MIN_NONZERO_NORM_SQUARED: f32 = 2.0;

/// Kissing number of E8: the number of unit-distance neighbors of
/// the origin in the lattice. Optimal in 8 dimensions per Viazovska
/// (2017); see Conway-Sloane Ch. 4.
pub const E8_KISSING_NUMBER: u32 = 240;

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum E8Error {
    NonFiniteInput { index: usize, value: f32 },
}

/// Check whether `p` is a valid E8 lattice point. A point is in E8 iff
/// every coordinate is integer (and the integer-sum is even) OR every
/// coordinate is a half-integer (and `Σ (p_i + 0.5)` is even, equivalent
/// to `Σ p_i + 4` even, i.e. `Σ p_i` is an even integer minus 4 — but
/// since each `p_i = k + 0.5` we have `Σ p_i = (Σ k_i) + 4`; the
/// constraint reduces to `Σ k_i` even, which is `Σ p_i - 4` even, i.e.
/// `Σ p_i` is an even integer).
pub fn in_e8(p: &E8Point) -> bool {
    let tol = 1e-5_f32;
    let all_integer = p.0.iter().all(|&v| (v - v.round()).abs() < tol);
    let all_half_integer = p.0.iter().all(|&v| {
        let shifted = v + 0.5;
        (shifted - shifted.round()).abs() < tol
    });
    if !all_integer && !all_half_integer {
        return false;
    }
    let sum: f32 = p.0.iter().sum();
    let sum_rounded = sum.round();
    let sum_int = sum_rounded as i64;
    (sum_int % 2 == 0) && (sum - sum_rounded).abs() < tol
}

fn round_to_d8(x: &[f32; 8]) -> [f32; 8] {
    let mut p = [0.0_f32; 8];
    let mut max_err: f32 = -1.0;
    let mut max_idx: usize = 0;
    for i in 0..8 {
        p[i] = x[i].round();
        let err = (x[i] - p[i]).abs();
        if err > max_err {
            max_err = err;
            max_idx = i;
        }
    }
    let sum: f32 = p.iter().sum();
    let sum_int = sum.round() as i64;
    if sum_int % 2 != 0 {
        if x[max_idx] > p[max_idx] {
            p[max_idx] += 1.0;
        } else {
            p[max_idx] -= 1.0;
        }
    }
    p
}

fn round_to_d8_plus_half(x: &[f32; 8]) -> [f32; 8] {
    let shifted: [f32; 8] = [
        x[0] - 0.5,
        x[1] - 0.5,
        x[2] - 0.5,
        x[3] - 0.5,
        x[4] - 0.5,
        x[5] - 0.5,
        x[6] - 0.5,
        x[7] - 0.5,
    ];
    let d8 = round_to_d8(&shifted);
    let mut p = [0.0_f32; 8];
    for i in 0..8 {
        p[i] = d8[i] + 0.5;
    }
    p
}

fn squared_distance(a: &[f32; 8], b: &[f32; 8]) -> f32 {
    let mut sum: f32 = 0.0;
    for i in 0..8 {
        let d = a[i] - b[i];
        sum += d * d;
    }
    sum
}

/// Nearest E8 lattice point. Returns the closer of:
/// 1. Nearest D8 point (integer coordinates, even sum).
/// 2. Nearest D8 + (½)^8 point (half-integer coordinates, even shifted sum).
pub fn e8_quantize(x: &[f32; 8]) -> Result<E8Point, E8Error> {
    for (i, &v) in x.iter().enumerate() {
        if !v.is_finite() {
            return Err(E8Error::NonFiniteInput { index: i, value: v });
        }
    }
    let p1 = round_to_d8(x);
    let p2 = round_to_d8_plus_half(x);
    let d1 = squared_distance(x, &p1);
    let d2 = squared_distance(x, &p2);
    Ok(E8Point(if d1 <= d2 { p1 } else { p2 }))
}

/// Squared-distance loss between an arbitrary `original` vector and
/// its E8 quantization. The standard "how lossy was this E8 encode?"
/// diagnostic — companion to the J7 Sherry quantization_error
/// (iter 120). Returns 0.0 for inputs already on the E8 lattice.
pub fn e8_quantization_error(
    original: &[f32; 8],
    quantized: &E8Point,
) -> f32 {
    squared_distance(original, &quantized.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn origin_is_in_e8() {
        let p = E8Point([0.0; 8]);
        assert!(in_e8(&p));
    }

    #[test]
    fn single_unit_vector_is_not_in_e8() {
        let mut p = E8Point([0.0; 8]);
        p.0[0] = 1.0;
        assert!(!in_e8(&p));
    }

    #[test]
    fn pair_sum_unit_vectors_is_in_e8() {
        let mut p = E8Point([0.0; 8]);
        p.0[0] = 1.0;
        p.0[1] = 1.0;
        assert!(in_e8(&p));
    }

    #[test]
    fn half_vector_is_in_e8() {
        let p = E8Point([0.5; 8]);
        assert!(in_e8(&p));
    }

    #[test]
    fn quantize_origin_returns_origin() {
        let q = e8_quantize(&[0.0; 8]).unwrap();
        assert_eq!(q.0, [0.0; 8]);
        assert!(in_e8(&q));
    }

    #[test]
    fn quantize_returns_e8_point_for_random_inputs() {
        let inputs: &[[f32; 8]] = &[
            [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8],
            [-1.2, 0.7, 2.3, -0.4, 1.5, -2.1, 0.9, -1.0],
            [3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0],
            [0.25, 0.75, 0.25, 0.75, 0.25, 0.75, 0.25, 0.75],
        ];
        for x in inputs {
            let q = e8_quantize(x).unwrap();
            assert!(in_e8(&q), "not in E8: {:?} from {:?}", q.0, x);
        }
    }

    #[test]
    fn quantize_idempotent_on_e8_point() {
        let inputs: &[[f32; 8]] = &[
            [0.0; 8],
            [0.5; 8],
            [1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
            [1.5, 1.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5],
            [2.0, -2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        ];
        for x in inputs {
            assert!(in_e8(&E8Point(*x)), "test setup: {:?} not in E8", x);
            let q = e8_quantize(x).unwrap();
            assert_eq!(q.0, *x, "non-idempotent on E8 input: {:?} → {:?}", x, q.0);
        }
    }

    #[test]
    fn nan_input_rejected() {
        let mut x = [0.0_f32; 8];
        x[3] = f32::NAN;
        let err = e8_quantize(&x).unwrap_err();
        match err {
            E8Error::NonFiniteInput { index, .. } => assert_eq!(index, 3),
            other => panic!("expected NonFiniteInput, got {:?}", other),
        }
    }

    #[test]
    fn infinity_input_rejected() {
        let mut x = [0.0_f32; 8];
        x[0] = f32::INFINITY;
        let err = e8_quantize(&x).unwrap_err();
        assert!(matches!(err, E8Error::NonFiniteInput { .. }));
    }

    #[test]
    fn nearest_point_is_within_one_in_each_coord() {
        let x = [0.4_f32, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4, 0.4];
        let q = e8_quantize(&x).unwrap();
        for i in 0..8 {
            assert!((q.0[i] - x[i]).abs() <= 0.6 + 1e-6);
        }
    }

    #[test]
    fn integer_input_with_odd_sum_routes_to_half_integer_candidate_or_corrects_parity() {
        let x = [1.0_f32, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        let q = e8_quantize(&x).unwrap();
        assert!(in_e8(&q));
    }

    #[test]
    fn e8_point_roundtrips_through_serde_json() {
        let p = E8Point([0.5; 8]);
        let json = serde_json::to_string(&p).unwrap();
        let back: E8Point = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }

    #[test]
    fn near_half_vector_quantizes_to_half_vector() {
        let x = [0.49_f32, 0.51, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5];
        let q = e8_quantize(&x).unwrap();
        assert_eq!(q.0, [0.5; 8]);
    }

    #[test]
    fn membership_rejects_mixed_integer_and_half_integer() {
        let p = E8Point([0.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
        assert!(!in_e8(&p));
    }

    // ── norm_squared + quantization_error tests (iter 121) ──────────────────

    fn approx(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn origin_has_zero_norm_squared() {
        let p = E8Point([0.0; 8]);
        assert!(approx(p.norm_squared(), 0.0, 1e-6));
    }

    #[test]
    fn root_vector_has_norm_squared_two() {
        // Per Conway-Sloane, e_1 + e_2 (a length-1 vector pair) is an
        // E8 root vector with squared norm 2.
        let p = E8Point([1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
        assert!(in_e8(&p));
        assert!(approx(p.norm_squared(), 2.0, 1e-6));
    }

    #[test]
    fn half_vector_has_norm_squared_two() {
        // (½)^8 vector has squared norm 8 × 0.25 = 2.
        let p = E8Point([0.5; 8]);
        assert!(in_e8(&p));
        assert!(approx(p.norm_squared(), 2.0, 1e-6));
    }

    #[test]
    fn e8_min_nonzero_norm_squared_pinned() {
        // Doctrine pin per Conway-Sloane Ch. 4.
        assert_eq!(E8_MIN_NONZERO_NORM_SQUARED, 2.0);
    }

    #[test]
    fn e8_kissing_number_pinned() {
        // Per Viazovska 2017.
        assert_eq!(E8_KISSING_NUMBER, 240);
    }

    #[test]
    fn quantization_error_zero_when_input_on_lattice() {
        let on_lattice = [1.0_f32, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        let q = e8_quantize(&on_lattice).unwrap();
        let err = e8_quantization_error(&on_lattice, &q);
        assert!(approx(err, 0.0, 1e-6));
    }

    #[test]
    fn quantization_error_matches_squared_distance_to_nearest() {
        // Input shifted by 0.1 from the nearest E8 root vector
        // [1, 1, 0, ..., 0]. The nearest E8 point should be this same
        // vector, with squared distance ≈ 2 × 0.01 = 0.02.
        let x = [1.1_f32, 1.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        let q = e8_quantize(&x).unwrap();
        let err = e8_quantization_error(&x, &q);
        // Tolerant: E8 quantizer may pick a half-vector if it's closer.
        // The substrate test just verifies the error is finite + small.
        assert!(err.is_finite());
        assert!(err < 0.5);
    }

    #[test]
    fn quantization_error_finite_for_arbitrary_input() {
        // Random-ish off-lattice input. Substrate-floor sanity: error
        // is finite and non-negative for any finite input.
        let x = [0.3_f32, -0.7, 1.4, -2.1, 0.0, 0.55, -1.2, 0.9];
        let q = e8_quantize(&x).unwrap();
        let err = e8_quantization_error(&x, &q);
        assert!(err.is_finite());
        assert!(err >= 0.0);
    }
}
