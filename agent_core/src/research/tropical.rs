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

impl TropicalError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            TropicalError::DimMismatch { .. } => "dim_mismatch",
            TropicalError::EmptyPolynomial => "empty_polynomial",
            TropicalError::NonFiniteInput { .. } => "non_finite_input",
        }
    }

    pub const fn is_dim_mismatch(&self) -> bool {
        matches!(self, TropicalError::DimMismatch { .. })
    }

    pub const fn is_empty_polynomial(&self) -> bool {
        matches!(self, TropicalError::EmptyPolynomial)
    }

    pub const fn is_non_finite_input(&self) -> bool {
        matches!(self, TropicalError::NonFiniteInput { .. })
    }
}

impl TropicalMonomial {
    /// Predicate: this monomial is the constant-zero monomial
    /// (`0 + 0·x` in any dimension). The "absorbing element" of
    /// tropical addition when other monomials carry positive bias.
    pub fn is_zero_monomial(&self) -> bool {
        self.bias == 0.0 && self.coeffs.iter().all(|&c| c == 0.0)
    }

    /// Evaluate this monomial alone (no max-fold). Used by callers
    /// that want per-monomial witnesses for which one dominates a
    /// max-fold. Cross-surface invariant: for any input,
    /// `TropicalPolynomial::evaluate(x) == max_i monomials[i].evaluate(x)`.
    pub fn evaluate(&self, x: &[f32]) -> Result<f32, TropicalError> {
        if x.len() != self.coeffs.len() {
            return Err(TropicalError::DimMismatch {
                expected: self.coeffs.len(),
                actual: x.len(),
            });
        }
        for (i, &v) in x.iter().enumerate() {
            if !v.is_finite() {
                return Err(TropicalError::NonFiniteInput { index: i, value: v });
            }
        }
        let mut s = self.bias;
        for (c, xv) in self.coeffs.iter().zip(x.iter()) {
            s += c * xv;
        }
        Ok(s)
    }
}

/// Tropical addition: `max(a, b)`. The canonical (max, +) semiring's
/// ⊕ operator. Distinct from the polynomial-evaluate fold;
/// exposed as a top-level function so callers can build expressions
/// without constructing intermediate TropicalPolynomial values.
pub fn tropical_add(a: f32, b: f32) -> f32 {
    a.max(b)
}

/// Tropical multiplication: `a + b`. The canonical (max, +) semiring's
/// ⊗ operator. Commutative + associative + identity-0 (additive ID
/// in standard semantics).
pub const fn tropical_mul(a: f32, b: f32) -> f32 {
    a + b
}

impl TropicalPolynomial {
    /// Number of monomials in the max-fold.
    pub fn monomial_count(&self) -> usize {
        self.monomials.len()
    }

    /// Predicate: this polynomial has no monomials. Evaluating an
    /// empty polynomial returns `TropicalError::EmptyPolynomial`.
    pub fn is_empty(&self) -> bool {
        self.monomials.is_empty()
    }

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

/// Lift a single dense + ReLU layer (`relu(W·x + b)`) into the
/// equivalent vector of tropical polynomials. Each output unit `i`
/// produces a polynomial `max(0, w_i · x + b_i)` — two monomials per
/// unit. Returns a `Vec<TropicalPolynomial>` with one polynomial per
/// output unit (length `weights.len()`).
///
/// Per Zhang-Naitzat-Lim 2018, this is the per-layer half of the
/// "feedforward ReLU = tropical rational function" theorem. Stacking
/// layers composes polynomials; the F-Tropical-Side-Quest falsifier
/// verifies that the trained MLP's f64 output matches the tropical
/// lift on a held-out point set (still NOT-STARTED — needs the
/// training pipeline from J3).
///
/// `weights[i][j]` is the weight from input `j` to output `i`. All
/// rows of `weights` must have the same length, which must equal
/// `biases.len()` is not the constraint (biases.len() must equal
/// `weights.len()`). Returns `DimMismatch` if shapes disagree.
pub fn relu_layer_as_tropical(
    weights: &[Vec<f32>],
    biases: &[f32],
) -> Result<Vec<TropicalPolynomial>, TropicalError> {
    if weights.is_empty() {
        return Err(TropicalError::EmptyPolynomial);
    }
    if weights.len() != biases.len() {
        return Err(TropicalError::DimMismatch {
            expected: weights.len(),
            actual: biases.len(),
        });
    }
    let input_dim = weights[0].len();
    for row in weights {
        if row.len() != input_dim {
            return Err(TropicalError::DimMismatch {
                expected: input_dim,
                actual: row.len(),
            });
        }
    }
    let mut polys = Vec::with_capacity(weights.len());
    for (i, row) in weights.iter().enumerate() {
        let zero_monomial = TropicalMonomial {
            coeffs: vec![0.0; input_dim],
            bias: 0.0,
        };
        let affine_monomial = TropicalMonomial {
            coeffs: row.clone(),
            bias: biases[i],
        };
        polys.push(TropicalPolynomial {
            dim: input_dim,
            monomials: vec![zero_monomial, affine_monomial],
        });
    }
    Ok(polys)
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

    // ── relu_layer_as_tropical tests (iter 89) ──────────────────────────────

    fn relu_dense(weights: &[Vec<f32>], biases: &[f32], x: &[f32]) -> Vec<f32> {
        // Reference forward pass: relu(W·x + b) per output unit.
        weights
            .iter()
            .zip(biases.iter())
            .map(|(w, b)| {
                let s: f32 = w.iter().zip(x.iter()).map(|(wi, xi)| wi * xi).sum::<f32>() + b;
                s.max(0.0)
            })
            .collect()
    }

    #[test]
    fn relu_layer_lift_matches_dense_forward_pass() {
        let weights = vec![vec![1.0, -2.0], vec![0.5, 0.5]];
        let biases = vec![0.1, -0.3];
        let polys = relu_layer_as_tropical(&weights, &biases).unwrap();
        assert_eq!(polys.len(), 2);

        for x in &[vec![0.0, 0.0], vec![1.0, 1.0], vec![-1.0, 2.0], vec![3.5, -0.7]] {
            let expected = relu_dense(&weights, &biases, x);
            let got: Vec<f32> = polys.iter().map(|p| p.evaluate(x).unwrap()).collect();
            for i in 0..expected.len() {
                assert!(
                    approx(expected[i], got[i], 1e-5),
                    "unit {} differs at x={:?}: expected {}, got {}",
                    i,
                    x,
                    expected[i],
                    got[i]
                );
            }
        }
    }

    #[test]
    fn relu_layer_lift_empty_weights_rejected() {
        let weights: Vec<Vec<f32>> = vec![];
        let biases: Vec<f32> = vec![];
        let err = relu_layer_as_tropical(&weights, &biases).unwrap_err();
        assert_eq!(err, TropicalError::EmptyPolynomial);
    }

    #[test]
    fn relu_layer_lift_weights_biases_length_mismatch_rejected() {
        let weights = vec![vec![1.0], vec![2.0]];
        let biases = vec![0.0]; // length 1, not 2
        assert!(matches!(
            relu_layer_as_tropical(&weights, &biases).unwrap_err(),
            TropicalError::DimMismatch { .. }
        ));
    }

    #[test]
    fn relu_layer_lift_inconsistent_row_lengths_rejected() {
        let weights = vec![vec![1.0, 2.0], vec![3.0]]; // row 1 dim 2, row 2 dim 1
        let biases = vec![0.0, 0.0];
        assert!(matches!(
            relu_layer_as_tropical(&weights, &biases).unwrap_err(),
            TropicalError::DimMismatch { .. }
        ));
    }

    #[test]
    fn relu_layer_lift_single_unit_matches_relu_lift() {
        // 1-unit layer with weights=[1], bias=0 should reduce to the
        // relu_as_tropical_polynomial base case (modulo input dim).
        let polys = relu_layer_as_tropical(&[vec![1.0]], &[0.0]).unwrap();
        assert_eq!(polys.len(), 1);
        let ref_poly = relu_as_tropical_polynomial();
        // Same outputs on a fixed sweep.
        for x in &[-3.0_f32, -0.5, 0.0, 0.5, 3.0] {
            let a = polys[0].evaluate(&[*x]).unwrap();
            let b = ref_poly.evaluate(&[*x]).unwrap();
            assert!(approx(a, b, 1e-6), "x={}, layer={}, ref={}", x, a, b);
        }
    }

    #[test]
    fn relu_layer_lift_negative_input_clamps_to_zero() {
        // weights all positive but very negative input → relu clamps to 0.
        let weights = vec![vec![1.0, 1.0]];
        let biases = vec![0.0];
        let polys = relu_layer_as_tropical(&weights, &biases).unwrap();
        let out = polys[0].evaluate(&[-100.0, -100.0]).unwrap();
        assert!(approx(out, 0.0, 1e-6));
    }

    // ── diagnostic surface (iter 158) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct_per_variant() {
        let variants = [
            TropicalError::DimMismatch { expected: 1, actual: 2 },
            TropicalError::EmptyPolynomial,
            TropicalError::NonFiniteInput { index: 0, value: f32::NAN },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 3);
    }

    #[test]
    fn error_classifiers_partition_variants() {
        let variants = [
            TropicalError::DimMismatch { expected: 1, actual: 2 },
            TropicalError::EmptyPolynomial,
            TropicalError::NonFiniteInput { index: 0, value: f32::NAN },
        ];
        // Cross-surface invariant: exactly one of the three predicates is true.
        for e in variants {
            let trio = [e.is_dim_mismatch(), e.is_empty_polynomial(), e.is_non_finite_input()];
            assert_eq!(trio.iter().filter(|t| **t).count(), 1, "{:?}", e);
        }
    }

    #[test]
    fn monomial_is_zero_monomial_identifies_constant_zero() {
        let zero1 = TropicalMonomial { coeffs: vec![0.0], bias: 0.0 };
        let zero3 = TropicalMonomial { coeffs: vec![0.0, 0.0, 0.0], bias: 0.0 };
        assert!(zero1.is_zero_monomial());
        assert!(zero3.is_zero_monomial());
        let nonzero_bias = TropicalMonomial { coeffs: vec![0.0], bias: 0.1 };
        let nonzero_coeff = TropicalMonomial { coeffs: vec![1.0], bias: 0.0 };
        assert!(!nonzero_bias.is_zero_monomial());
        assert!(!nonzero_coeff.is_zero_monomial());
    }

    #[test]
    fn polynomial_evaluate_matches_monomial_max_fold() {
        // Cross-surface invariant: TropicalPolynomial::evaluate(x) =
        // max_i monomials[i].evaluate(x).
        let p = TropicalPolynomial::new(
            2,
            vec![
                TropicalMonomial { coeffs: vec![1.0, 0.0], bias: 0.0 },
                TropicalMonomial { coeffs: vec![0.0, 1.0], bias: 0.0 },
                TropicalMonomial { coeffs: vec![0.5, 0.5], bias: -2.0 },
            ],
        )
        .unwrap();
        for x in &[vec![1.0_f32, 2.0], vec![3.0, -1.0], vec![0.0, 0.0]] {
            let p_val = p.evaluate(x).unwrap();
            let m_max = p.monomials.iter()
                .map(|m| m.evaluate(x).unwrap())
                .fold(f32::NEG_INFINITY, f32::max);
            assert!(approx(p_val, m_max, 1e-6));
        }
    }

    #[test]
    fn polynomial_monomial_count_and_is_empty_consistent() {
        // Cross-surface: is_empty iff monomial_count == 0.
        let empty = TropicalPolynomial { dim: 2, monomials: vec![] };
        assert!(empty.is_empty());
        assert_eq!(empty.monomial_count(), 0);

        let one = TropicalPolynomial::new(
            1,
            vec![TropicalMonomial { coeffs: vec![1.0], bias: 0.0 }],
        )
        .unwrap();
        assert!(!one.is_empty());
        assert_eq!(one.monomial_count(), 1);
    }

    #[test]
    fn tropical_add_is_commutative() {
        // Cross-surface invariant: tropical_add(a, b) == tropical_add(b, a).
        for (a, b) in [(-2.0_f32, 5.0), (1.0, 1.0), (-3.5, -7.1), (0.0, 100.0)] {
            assert_eq!(tropical_add(a, b), tropical_add(b, a));
        }
    }

    #[test]
    fn tropical_mul_is_commutative_and_associative() {
        // Cross-surface invariant: tropical_mul = standard +, so
        // commutative + associative.
        for (a, b, c) in [(1.0_f32, 2.0, 3.0), (-1.0, 0.0, 5.0)] {
            assert_eq!(tropical_mul(a, b), tropical_mul(b, a));
            assert!(approx(
                tropical_mul(tropical_mul(a, b), c),
                tropical_mul(a, tropical_mul(b, c)),
                1e-6,
            ));
        }
    }

    #[test]
    fn tropical_add_max_identity() {
        // Cross-surface invariant: NEG_INFINITY is the identity for max.
        for a in [-5.0_f32, 0.0, 3.5] {
            assert_eq!(tropical_add(a, f32::NEG_INFINITY), a);
            assert_eq!(tropical_add(f32::NEG_INFINITY, a), a);
        }
    }

    #[test]
    fn tropical_mul_zero_identity() {
        // Cross-surface invariant: 0.0 is the identity for + (and thus ⊗).
        for a in [-5.0_f32, 0.0, 3.5] {
            assert_eq!(tropical_mul(a, 0.0), a);
            assert_eq!(tropical_mul(0.0, a), a);
        }
    }
}
