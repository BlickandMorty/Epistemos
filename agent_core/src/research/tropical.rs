//! Source:
//! - `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md`
//!   §"Terminal B" Phase B.6.15 — T-Tropical-Affine completeness for
//!   ReLU + F-Tropical-Side-Quest falsifier.
//! - Zhang, Naitzat, Lim, "Tropical Geometry of Deep Neural Networks",
//!   ICML 2018, arXiv:1805.07091 — the canonical result: feedforward
//!   ReLU networks with rational weights compute exactly the family
//!   of tropical (max-plus) rational functions.
//! - Maclagan & Sturmfels, "Introduction to Tropical Geometry", AMS
//!   GSM 161, 2015 — the algebra background.
//!
//! # Wave J B.6.15 — Tropical-Affine completeness substrate
//!
//! The tropical (min-plus / max-plus) semiring:
//!
//! ```text
//! a ⊕ b = max(a, b)         (tropical addition)
//! a ⊗ b = a + b             (tropical multiplication)
//! ```
//!
//! A **tropical polynomial** is a finite max of affine functions:
//!
//! ```text
//! p(x) = max_i ( bias_i + Σ_j coeff_{i,j} · x_j )
//! ```
//!
//! Per Zhang-Naitzat-Lim 2018: every feedforward ReLU network with
//! rational weights computes a tropical rational function (ratio of
//! two tropical polynomials). The "completeness" half is the converse
//! — every tropical polynomial is computable by some ReLU network.
//!
//! Substrate floor here ships the tropical-polynomial type +
//! evaluator + a `relu`-via-tropical proof helper. The full F-Tropical-
//! Side-Quest falsifier (verify a trained ReLU MLP equals its tropical
//! lift on a 1k-point random fixture) is NOT-STARTED — requires the
//! ReLU MLP training pipeline (Wave J3 SEAL-DoRA upstream).

use serde::{Deserialize, Serialize};

/// One affine summand of a tropical polynomial:
/// `coeffs · x + bias` (standard linear, evaluated then max-folded
/// across all monomials in the parent polynomial).
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TropicalMonomial {
    pub coeffs: Vec<f32>,
    pub bias: f32,
}

/// Tropical polynomial as `max_i(monomial_i(x))`.
/// `dim` is the input dimensionality; every monomial's `coeffs` must
/// have length `dim`.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TropicalPolynomial {
    pub dim: usize,
    pub monomials: Vec<TropicalMonomial>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum TropicalError {
    DimMismatch { expected: usize, actual: usize },
    EmptyPolynomial,
    NonFiniteInput { index: usize, value: f32 },
}

impl TropicalPolynomial {
    pub fn new(dim: usize, monomials: Vec<TropicalMonomial>) -> Result<Self, TropicalError> {
        for m in &monomials {
            if m.coeffs.len() != dim {
                return Err(TropicalError::DimMismatch {
                    expected: dim,
                    actual: m.coeffs.len(),
                });
            }
        }
        Ok(Self { dim, monomials })
    }

    pub fn evaluate(&self, x: &[f32]) -> Result<f32, TropicalError> {
        if x.len() != self.dim {
            return Err(TropicalError::DimMismatch {
                expected: self.dim,
                actual: x.len(),
            });
        }
        if self.monomials.is_empty() {
            return Err(TropicalError::EmptyPolynomial);
        }
        for (i, &v) in x.iter().enumerate() {
            if !v.is_finite() {
                return Err(TropicalError::NonFiniteInput { index: i, value: v });
            }
        }
        let mut best = f32::NEG_INFINITY;
        for m in &self.monomials {
            let mut s = m.bias;
            for (c, xv) in m.coeffs.iter().zip(x.iter()) {
                s += c * xv;
            }
            if s > best {
                best = s;
            }
        }
        Ok(best)
    }
}

/// `relu(x) = max(0, x)` expressed as a 1-D tropical polynomial:
/// `max(0 + 0·x, 0 + 1·x) = max(0, x)`. The canonical "ReLU is a
/// tropical polynomial" proof.
pub fn relu_as_tropical_polynomial() -> TropicalPolynomial {
    TropicalPolynomial {
        dim: 1,
        monomials: vec![
            TropicalMonomial { coeffs: vec![0.0], bias: 0.0 },
            TropicalMonomial { coeffs: vec![1.0], bias: 0.0 },
        ],
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn new_rejects_dim_mismatch_in_monomial() {
        let m = TropicalMonomial { coeffs: vec![1.0, 2.0], bias: 0.0 };
        let err = TropicalPolynomial::new(3, vec![m]).unwrap_err();
        assert!(matches!(err, TropicalError::DimMismatch { expected: 3, actual: 2 }));
    }

    #[test]
    fn evaluate_picks_max_monomial() {
        let p = TropicalPolynomial::new(
            1,
            vec![
                TropicalMonomial { coeffs: vec![0.0], bias: 3.0 },
                TropicalMonomial { coeffs: vec![0.0], bias: 5.0 },
                TropicalMonomial { coeffs: vec![0.0], bias: 1.0 },
            ],
        )
        .unwrap();
        assert!(approx(p.evaluate(&[0.0]).unwrap(), 5.0, 1e-6));
    }

    #[test]
    fn evaluate_with_input_dim_mismatch_errors() {
        let p = relu_as_tropical_polynomial();
        let err = p.evaluate(&[1.0, 2.0]).unwrap_err();
        assert!(matches!(err, TropicalError::DimMismatch { expected: 1, actual: 2 }));
    }

    #[test]
    fn evaluate_empty_polynomial_errors() {
        let p = TropicalPolynomial { dim: 1, monomials: vec![] };
        let err = p.evaluate(&[0.0]).unwrap_err();
        assert_eq!(err, TropicalError::EmptyPolynomial);
    }

    #[test]
    fn evaluate_non_finite_input_errors() {
        let p = relu_as_tropical_polynomial();
        let err = p.evaluate(&[f32::NAN]).unwrap_err();
        assert!(matches!(err, TropicalError::NonFiniteInput { .. }));
    }

    #[test]
    fn relu_as_tropical_polynomial_matches_relu_on_negative() {
        let p = relu_as_tropical_polynomial();
        assert!(approx(p.evaluate(&[-5.0]).unwrap(), 0.0, 1e-6));
        assert!(approx(p.evaluate(&[-0.1]).unwrap(), 0.0, 1e-6));
    }

    #[test]
    fn relu_as_tropical_polynomial_matches_relu_on_positive() {
        let p = relu_as_tropical_polynomial();
        assert!(approx(p.evaluate(&[5.0]).unwrap(), 5.0, 1e-6));
        assert!(approx(p.evaluate(&[0.1]).unwrap(), 0.1, 1e-6));
    }

    #[test]
    fn relu_as_tropical_polynomial_at_zero() {
        let p = relu_as_tropical_polynomial();
        assert!(approx(p.evaluate(&[0.0]).unwrap(), 0.0, 1e-6));
    }

    #[test]
    fn two_dim_tropical_picks_max_inner_product() {
        let p = TropicalPolynomial::new(
            2,
            vec![
                TropicalMonomial { coeffs: vec![1.0, 0.0], bias: 0.0 },
                TropicalMonomial { coeffs: vec![0.0, 1.0], bias: 0.0 },
            ],
        )
        .unwrap();
        assert!(approx(p.evaluate(&[3.0, 5.0]).unwrap(), 5.0, 1e-6));
        assert!(approx(p.evaluate(&[5.0, 3.0]).unwrap(), 5.0, 1e-6));
    }

    #[test]
    fn relu_matches_naive_max_zero_x_for_random_inputs() {
        let p = relu_as_tropical_polynomial();
        for x in &[-3.5_f32, -0.7, 0.0, 0.5, 2.5, 100.0] {
            let tropical = p.evaluate(&[*x]).unwrap();
            let naive = x.max(0.0);
            assert!(approx(tropical, naive, 1e-6), "x={} tropical={} naive={}", x, tropical, naive);
        }
    }

    #[test]
    fn polynomial_roundtrips_through_serde_json() {
        let p = relu_as_tropical_polynomial();
        let json = serde_json::to_string(&p).unwrap();
        let back: TropicalPolynomial = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }

    #[test]
    fn single_monomial_polynomial_is_pure_affine() {
        let p = TropicalPolynomial::new(
            2,
            vec![TropicalMonomial { coeffs: vec![2.0, -1.0], bias: 5.0 }],
        )
        .unwrap();
        // 2·x + (-1)·y + 5
        assert!(approx(p.evaluate(&[1.0, 1.0]).unwrap(), 6.0, 1e-6));
        assert!(approx(p.evaluate(&[0.0, 0.0]).unwrap(), 5.0, 1e-6));
        assert!(approx(p.evaluate(&[-1.0, 2.0]).unwrap(), 1.0, 1e-6));
    }

    #[test]
    fn evaluate_returns_neg_infinity_proxy_when_only_negative_monomials() {
        // All monomials negative; pick highest (least negative).
        let p = TropicalPolynomial::new(
            1,
            vec![
                TropicalMonomial { coeffs: vec![0.0], bias: -10.0 },
                TropicalMonomial { coeffs: vec![0.0], bias: -3.0 },
                TropicalMonomial { coeffs: vec![0.0], bias: -7.0 },
            ],
        )
        .unwrap();
        assert!(approx(p.evaluate(&[0.0]).unwrap(), -3.0, 1e-6));
    }
}
