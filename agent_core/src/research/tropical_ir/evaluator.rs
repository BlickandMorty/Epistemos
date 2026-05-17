//! Source:
//! - Zhang/Naitzat/Lim arXiv:1805.07091 §2 — tropical-semiring
//!   semantics on the AST (max for ⊕, + for ⊗).
//! - Charisopoulos/Maragos arXiv:1805.08749 §3 — the tropical
//!   rational form's f64 evaluation.
//! - Doctrine §2.2 + §4.2 — Tropical-IR first lowering target.
//! - Companion: [`super::grammar`] (the AST this module evaluates);
//!   [`super::super::tropical`] (the substrate-floor module whose
//!   `tropical_add` / `tropical_mul` operators we delegate to for
//!   the binary operations).
//!
//! # Tropical (max, +) evaluator
//!
//! Given an [`super::grammar::TropicalExpr`] and a valuation vector
//! `valuation: &[f64]`, [`evaluate`] computes the tree's f64 value
//! using:
//!
//! - `Const(v)` → `v`.
//! - `Var(i)` → `valuation[i]` (out-of-range index → error).
//! - `Max([])` → `f64::NEG_INFINITY` (the tropical additive identity).
//! - `Max([a, …, z])` → `max(eval(a), …, eval(z))`.
//! - `Plus(a, b)` → `eval(a) + eval(b)` (standard real addition;
//!   tropical multiplication).
//!
//! Non-finite intermediates (e.g. NaN) propagate. The evaluator
//! rejects out-of-range `Var` indices but otherwise lets the
//! tropical semantics carry through.

use super::grammar::{TropicalExpr, TropicalRational};

/// Evaluation error for tropical-IR trees.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum TropicalEvalError {
    /// `Var(idx)` referenced an index that exceeds the valuation
    /// vector's length.
    VarOutOfRange { idx: usize, valuation_len: usize },
    /// A computed intermediate was NaN. The evaluator surfaces this
    /// rather than propagating silently — most consumers want
    /// determinism, not IEEE NaN drift.
    NonFiniteIntermediate { value: f64 },
}

/// Evaluate a tropical expression against a valuation vector.
///
/// Returns the f64 value or a [`TropicalEvalError`] on out-of-range
/// `Var` or NaN propagation. Infinities (positive and negative) are
/// permitted intermediates and outputs — tropical semantics use
/// `f64::NEG_INFINITY` as the additive identity, and overflow to
/// `f64::INFINITY` is a valid tropical-multiplication result.
pub fn evaluate(
    expr: &TropicalExpr,
    valuation: &[f64],
) -> Result<f64, TropicalEvalError> {
    let v = match expr {
        TropicalExpr::Const(c) => *c,
        TropicalExpr::Var(i) => {
            if *i >= valuation.len() {
                return Err(TropicalEvalError::VarOutOfRange {
                    idx: *i,
                    valuation_len: valuation.len(),
                });
            }
            valuation[*i]
        }
        TropicalExpr::Max(args) => {
            if args.is_empty() {
                return Ok(f64::NEG_INFINITY);
            }
            let mut best = f64::NEG_INFINITY;
            for a in args {
                let av = evaluate(a, valuation)?;
                if av > best {
                    best = av;
                }
            }
            best
        }
        TropicalExpr::Plus(l, r) => evaluate(l, valuation)? + evaluate(r, valuation)?,
        TropicalExpr::Scale(s, e) => s * evaluate(e, valuation)?,
    };
    if v.is_nan() {
        return Err(TropicalEvalError::NonFiniteIntermediate { value: v });
    }
    Ok(v)
}

/// Compile a tropical-polynomial coefficient vector into a
/// TropicalExpr tree.
///
/// Produces `Max([Plus(Const(a_k), Scale(k, Var(0)))])` for each
/// degree `k`. Variable slot 0 represents `x`.
///
/// Iter-113 — companion to [`tropical_polynomial`] that lifts the
/// numerical evaluation into an AST so it can pass through
/// optimizer passes, Lean certificate generators, or fusion
/// with other TropicalExpr trees.
pub fn compile_tropical_polynomial(coeffs: &[f64]) -> TropicalExpr {
    let terms: Vec<TropicalExpr> = coeffs
        .iter()
        .enumerate()
        .map(|(k, &a)| {
            let kx = TropicalExpr::scale(k as f64, TropicalExpr::var(0));
            TropicalExpr::plus(TropicalExpr::constant(a), kx)
        })
        .collect();
    TropicalExpr::max(terms)
}

/// Evaluate a tropical (max, +) polynomial:
///
/// `p(x) = max_k (a_k + k · x)` for coefficients `a = (a_0, a_1, …, a_n)`.
///
/// This is the (max, +) analog of ordinary polynomial evaluation
/// `Σ_k a_k · x^k`. The max-plus polynomial defines a piecewise-
/// linear convex function whose graph is the upper envelope of
/// affine lines `y = a_k + k·x`.
///
/// Special cases:
/// - Empty coefficients: returns `f64::NEG_INFINITY` (the tropical
///   additive identity).
/// - Single coefficient `[a]`: returns `a` (constant function).
///
/// Iter-108 — tropical polynomial primitive. Companion to
/// [`tropical_convolution`] (which IS tropical polynomial
/// multiplication).
pub fn tropical_polynomial(coeffs: &[f64], x: f64) -> f64 {
    coeffs
        .iter()
        .enumerate()
        .map(|(k, &a)| a + (k as f64) * x)
        .fold(f64::NEG_INFINITY, f64::max)
}

/// Discrete tropical (max, +) convolution of two sequences:
///
/// `(a ⊛ b)_k = max_{i+j=k} (a_i + b_j)`
///
/// where addition replaces ordinary multiplication (tropical
/// multiplication = real +), and `max` replaces ordinary summation
/// (tropical addition = max). The result has length `a.len() + b.len() - 1`.
///
/// Equivalent to:
/// - Longest-path computation on a DAG with edge weights.
/// - Viterbi recurrence inner loop (max-product → tropical max-sum
///   under log transform).
/// - Polynomial-product analogue in the tropical semiring.
///
/// Iter-103 — Cuninghame-Green tropical algebra primitive
/// (Cuninghame-Green 1979 "Minimax Algebra"). Inputs of length 0
/// yield an empty output.
pub fn tropical_convolution(a: &[f64], b: &[f64]) -> Vec<f64> {
    if a.is_empty() || b.is_empty() {
        return Vec::new();
    }
    let n = a.len() + b.len() - 1;
    let mut out = vec![f64::NEG_INFINITY; n];
    for (i, &ai) in a.iter().enumerate() {
        for (j, &bj) in b.iter().enumerate() {
            let v = ai + bj;
            if v > out[i + j] {
                out[i + j] = v;
            }
        }
    }
    out
}

/// Tropical (min, +) convolution — companion of [`tropical_convolution`]
/// for shortest-path / minimization semantics.
///
/// `(a ⊛_min b)_k = min_{i+j=k} (a_i + b_j)`
///
/// Iter-103 — anti-tropical analogue (min, +) of the standard
/// (max, +) operation.
pub fn min_plus_convolution(a: &[f64], b: &[f64]) -> Vec<f64> {
    if a.is_empty() || b.is_empty() {
        return Vec::new();
    }
    let n = a.len() + b.len() - 1;
    let mut out = vec![f64::INFINITY; n];
    for (i, &ai) in a.iter().enumerate() {
        for (j, &bj) in b.iter().enumerate() {
            let v = ai + bj;
            if v < out[i + j] {
                out[i + j] = v;
            }
        }
    }
    out
}

/// Evaluate a [`TropicalRational`] = `numerator ⊘ denominator`.
/// Tropical division is standard subtraction (because tropical
/// multiplication is `+`, the tropical inverse is `−`).
pub fn evaluate_rational(
    rational: &TropicalRational,
    valuation: &[f64],
) -> Result<f64, TropicalEvalError> {
    let n = evaluate(&rational.numerator, valuation)?;
    let d = evaluate(&rational.denominator, valuation)?;
    Ok(n - d)
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── iter-113: compile_tropical_polynomial ─────────────────────

    #[test]
    fn compile_tropical_polynomial_constant_matches_direct() {
        let tree = compile_tropical_polynomial(&[3.5]);
        let v = evaluate(&tree, &[100.0]).unwrap();
        let direct = tropical_polynomial(&[3.5], 100.0);
        assert_eq!(v, direct);
        assert_eq!(v, 3.5);
    }

    #[test]
    fn compile_tropical_polynomial_linear_matches_direct() {
        // p(x) = max(a_0, a_1 + x).
        let coeffs = [5.0_f64, 0.0];
        let tree = compile_tropical_polynomial(&coeffs);
        for x in [-3.0_f64, 3.0, 5.0, 10.0] {
            let tree_v = evaluate(&tree, &[x]).unwrap();
            let direct_v = tropical_polynomial(&coeffs, x);
            assert_eq!(tree_v, direct_v);
        }
    }

    #[test]
    fn compile_tropical_polynomial_cubic_matches_direct() {
        // p(x) = max(1, 2 + x, 0 + 2x, -1 + 3x).
        let coeffs = [1.0_f64, 2.0, 0.0, -1.0];
        let tree = compile_tropical_polynomial(&coeffs);
        for x in [-2.0_f64, 0.0, 1.0, 5.0] {
            let tree_v = evaluate(&tree, &[x]).unwrap();
            let direct_v = tropical_polynomial(&coeffs, x);
            assert_eq!(tree_v, direct_v);
        }
    }

    #[test]
    fn compile_tropical_polynomial_has_correct_max_var_index() {
        let tree = compile_tropical_polynomial(&[1.0, 2.0, 3.0]);
        assert_eq!(tree.max_var_index(), Some(0));
    }

    // ── iter-108: tropical_polynomial ─────────────────────────────

    #[test]
    fn tropical_polynomial_empty_coeffs_is_neg_infinity() {
        assert_eq!(tropical_polynomial(&[], 1.0), f64::NEG_INFINITY);
    }

    #[test]
    fn tropical_polynomial_constant_returns_constant() {
        assert_eq!(tropical_polynomial(&[3.5], 100.0), 3.5);
        assert_eq!(tropical_polynomial(&[-2.0], -100.0), -2.0);
    }

    #[test]
    fn tropical_polynomial_linear_two_coeffs() {
        // p(x) = max(a_0, a_1 + x).
        // a = (5, 0): max(5, x) — switches at x = 5.
        assert_eq!(tropical_polynomial(&[5.0, 0.0], 3.0), 5.0); // x < 5
        assert_eq!(tropical_polynomial(&[5.0, 0.0], 5.0), 5.0); // x = 5
        assert_eq!(tropical_polynomial(&[5.0, 0.0], 10.0), 10.0); // x > 5
    }

    #[test]
    fn tropical_polynomial_quadratic_three_coeffs() {
        // p(x) = max(0, 1 + x, 0 + 2x).
        // At x = -5: max(0, -4, -10) = 0.
        // At x = 0:  max(0, 1, 0) = 1.
        // At x = 5:  max(0, 6, 10) = 10.
        let coeffs = [0.0, 1.0, 0.0];
        assert_eq!(tropical_polynomial(&coeffs, -5.0), 0.0);
        assert_eq!(tropical_polynomial(&coeffs, 0.0), 1.0);
        assert_eq!(tropical_polynomial(&coeffs, 5.0), 10.0);
    }

    #[test]
    fn tropical_polynomial_is_convex_via_3_point_check() {
        // Tropical polynomials are convex piecewise-linear functions.
        // Verify: p((x+y)/2) ≤ (p(x) + p(y)) / 2 — but tropical
        // max IS convex by definition. Check at random points.
        let coeffs = [0.0, 0.5, -1.0, 2.0];
        let x = 1.0_f64;
        let y = 5.0;
        let mid = (x + y) / 2.0;
        let p_x = tropical_polynomial(&coeffs, x);
        let p_y = tropical_polynomial(&coeffs, y);
        let p_mid = tropical_polynomial(&coeffs, mid);
        // Convexity: p(mid) ≤ (p_x + p_y) / 2.
        assert!(
            p_mid <= (p_x + p_y) / 2.0 + 1e-12,
            "convexity fails: p({}) = {}, average = {}",
            mid, p_mid, (p_x + p_y) / 2.0
        );
    }

    #[test]
    fn tropical_polynomial_dominant_coefficient_wins_at_extreme_x() {
        // As x → +∞, the term a_n + n·x dominates (highest degree).
        // a = (10, 0, 0, 1) at x = 100: max(10, 100, 200, 301) = 301.
        let v = tropical_polynomial(&[10.0, 0.0, 0.0, 1.0], 100.0);
        assert_eq!(v, 301.0);
    }

    #[test]
    fn tropical_polynomial_negative_x_favors_low_degree() {
        // a = (5, 0, 0) at x = -100: max(5, -100, -200) = 5.
        let v = tropical_polynomial(&[5.0, 0.0, 0.0], -100.0);
        assert_eq!(v, 5.0);
    }

    // ── iter-103: tropical_convolution + min_plus_convolution ─────

    #[test]
    fn tropical_convolution_single_element_left() {
        // a = [3], b = [1, 2, 4] → output_k = 3 + b_k.
        let out = tropical_convolution(&[3.0], &[1.0, 2.0, 4.0]);
        assert_eq!(out, vec![4.0, 5.0, 7.0]);
    }

    #[test]
    fn tropical_convolution_2x2_known() {
        // a = [1, 2], b = [3, 4].
        // (a ⊛ b)_0 = max(1+3) = 4
        // (a ⊛ b)_1 = max(1+4, 2+3) = 5
        // (a ⊛ b)_2 = max(2+4) = 6
        let out = tropical_convolution(&[1.0, 2.0], &[3.0, 4.0]);
        assert_eq!(out, vec![4.0, 5.0, 6.0]);
    }

    #[test]
    fn tropical_convolution_zero_padding_concept() {
        // a = [0, 0, 0], b = [1, 2, 3]. Each output is max of
        // 0+b_k where i+j=k. Since 0+b_k = b_k for any i:
        // out_0 = max(b_0) = 1
        // out_1 = max(b_0, b_1) = 2
        // out_2 = max(b_0, b_1, b_2) = 3
        // out_3 = max(b_1, b_2) = 3
        // out_4 = max(b_2) = 3
        let out = tropical_convolution(&[0.0, 0.0, 0.0], &[1.0, 2.0, 3.0]);
        assert_eq!(out, vec![1.0, 2.0, 3.0, 3.0, 3.0]);
    }

    #[test]
    fn tropical_convolution_commutative() {
        let a = vec![1.5_f64, -0.5, 2.0];
        let b = vec![0.7_f64, 1.3];
        let ab = tropical_convolution(&a, &b);
        let ba = tropical_convolution(&b, &a);
        assert_eq!(ab, ba);
    }

    #[test]
    fn tropical_convolution_empty_input_yields_empty_output() {
        assert!(tropical_convolution(&[], &[1.0, 2.0]).is_empty());
        assert!(tropical_convolution(&[1.0, 2.0], &[]).is_empty());
    }

    #[test]
    fn min_plus_convolution_2x2_known() {
        // a = [1, 2], b = [3, 4].
        // (a ⊛_min b)_0 = min(1+3) = 4
        // (a ⊛_min b)_1 = min(1+4, 2+3) = 5
        // (a ⊛_min b)_2 = min(2+4) = 6
        let out = min_plus_convolution(&[1.0, 2.0], &[3.0, 4.0]);
        assert_eq!(out, vec![4.0, 5.0, 6.0]);
    }

    #[test]
    fn min_plus_convolution_picks_smaller_path() {
        // a = [0, 5], b = [0, 3].
        // (a ⊛_min b)_1 = min(0+3, 5+0) = 3.
        let out = min_plus_convolution(&[0.0, 5.0], &[0.0, 3.0]);
        assert_eq!(out, vec![0.0, 3.0, 8.0]);
    }

    #[test]
    fn tropical_min_plus_negation_duality() {
        // min(a) = -max(-a). Verify on convolution:
        //   min_plus_conv(a, b) = -max_plus_conv(-a, -b)? NO — the
        //   duality is on the result not the operation. Let's check
        //   that max_plus_conv(-a, -b) = -min_plus_conv(a, b)
        //   ELEMENTWISE.
        let a = vec![1.0_f64, -2.0, 3.0];
        let b = vec![0.5_f64, 1.5];
        let max_conv: Vec<f64> = tropical_convolution(
            &a.iter().map(|x| -x).collect::<Vec<_>>(),
            &b.iter().map(|x| -x).collect::<Vec<_>>(),
        );
        let min_conv = min_plus_convolution(&a, &b);
        for (m, n) in max_conv.iter().zip(min_conv.iter()) {
            assert!((m + n).abs() < 1e-12, "duality fails: max={} + min={}", m, n);
        }
    }

    #[test]
    fn const_evaluates_to_its_value() {
        assert_eq!(evaluate(&TropicalExpr::constant(3.5), &[]).unwrap(), 3.5);
    }

    #[test]
    fn var_evaluates_to_valuation_slot() {
        let v = evaluate(&TropicalExpr::var(2), &[10.0, 20.0, 30.0]).unwrap();
        assert_eq!(v, 30.0);
    }

    #[test]
    fn var_out_of_range_is_rejected() {
        let err = evaluate(&TropicalExpr::var(5), &[10.0]).unwrap_err();
        assert_eq!(
            err,
            TropicalEvalError::VarOutOfRange {
                idx: 5,
                valuation_len: 1,
            }
        );
    }

    #[test]
    fn empty_max_is_neg_infinity() {
        let v = evaluate(&TropicalExpr::max(vec![]), &[]).unwrap();
        assert_eq!(v, f64::NEG_INFINITY);
    }

    #[test]
    fn nonempty_max_picks_largest_argument() {
        let e = TropicalExpr::max(vec![
            TropicalExpr::constant(1.0),
            TropicalExpr::constant(5.0),
            TropicalExpr::constant(3.0),
        ]);
        assert_eq!(evaluate(&e, &[]).unwrap(), 5.0);
    }

    #[test]
    fn plus_is_standard_real_addition() {
        // Tropical multiplication: 2 ⊗ 3 = 2 + 3 = 5.
        let e = TropicalExpr::plus(
            TropicalExpr::constant(2.0),
            TropicalExpr::constant(3.0),
        );
        assert_eq!(evaluate(&e, &[]).unwrap(), 5.0);
    }

    #[test]
    fn nested_max_plus_evaluates_correctly() {
        // max(x + 1, x + 2) where x = 10 → max(11, 12) = 12.
        let e = TropicalExpr::max(vec![
            TropicalExpr::plus(TropicalExpr::var(0), TropicalExpr::constant(1.0)),
            TropicalExpr::plus(TropicalExpr::var(0), TropicalExpr::constant(2.0)),
        ]);
        assert_eq!(evaluate(&e, &[10.0]).unwrap(), 12.0);
    }

    #[test]
    fn max_propagates_var_out_of_range_error() {
        let e = TropicalExpr::max(vec![
            TropicalExpr::constant(1.0),
            TropicalExpr::var(9),
        ]);
        let err = evaluate(&e, &[3.0]).unwrap_err();
        assert!(matches!(err, TropicalEvalError::VarOutOfRange { .. }));
    }

    #[test]
    fn plus_propagates_var_out_of_range_error() {
        let e = TropicalExpr::plus(
            TropicalExpr::constant(1.0),
            TropicalExpr::var(9),
        );
        let err = evaluate(&e, &[3.0]).unwrap_err();
        assert!(matches!(err, TropicalEvalError::VarOutOfRange { .. }));
    }

    #[test]
    fn nan_intermediate_is_rejected() {
        // Plus(NaN, 0.0) — direct construction.
        let e = TropicalExpr::plus(
            TropicalExpr::constant(f64::NAN),
            TropicalExpr::constant(0.0),
        );
        let err = evaluate(&e, &[]).unwrap_err();
        assert!(matches!(err, TropicalEvalError::NonFiniteIntermediate { .. }));
    }

    #[test]
    fn infinity_is_permitted_intermediate() {
        // Max([+inf, 1.0]) → +inf.
        let e = TropicalExpr::max(vec![
            TropicalExpr::constant(f64::INFINITY),
            TropicalExpr::constant(1.0),
        ]);
        assert_eq!(evaluate(&e, &[]).unwrap(), f64::INFINITY);
    }

    #[test]
    fn rational_evaluates_as_numerator_minus_denominator() {
        let r = TropicalRational::new(
            TropicalExpr::constant(7.0),
            TropicalExpr::constant(3.0),
        );
        assert_eq!(evaluate_rational(&r, &[]).unwrap(), 4.0);
    }

    #[test]
    fn rational_with_vars_evaluates_correctly() {
        // numerator: max(x + 1, x + 2) at x=10 → 12
        // denominator: x at x=10 → 10
        // result: 12 - 10 = 2
        let r = TropicalRational::new(
            TropicalExpr::max(vec![
                TropicalExpr::plus(TropicalExpr::var(0), TropicalExpr::constant(1.0)),
                TropicalExpr::plus(TropicalExpr::var(0), TropicalExpr::constant(2.0)),
            ]),
            TropicalExpr::var(0),
        );
        assert_eq!(evaluate_rational(&r, &[10.0]).unwrap(), 2.0);
    }

    #[test]
    fn empty_max_in_rational_yields_neg_infinity_or_finite_diff() {
        // numerator empty Max → -inf; denominator 0 → -inf - 0 = -inf
        let r = TropicalRational::new(
            TropicalExpr::max(vec![]),
            TropicalExpr::constant(0.0),
        );
        assert_eq!(evaluate_rational(&r, &[]).unwrap(), f64::NEG_INFINITY);
    }

    // ── Scale variant evaluation (iter-61) ────────────────────────

    #[test]
    fn scale_const_evaluates_to_product() {
        let e = TropicalExpr::scale(3.0, TropicalExpr::constant(4.0));
        assert_eq!(evaluate(&e, &[]).unwrap(), 12.0);
    }

    #[test]
    fn scale_var_evaluates_to_real_multiplication() {
        // Scale(2.5, Var(0)) at x=4 → 2.5 * 4 = 10.
        let e = TropicalExpr::scale(2.5, TropicalExpr::var(0));
        assert_eq!(evaluate(&e, &[4.0]).unwrap(), 10.0);
    }

    #[test]
    fn scale_with_negative_weight() {
        let e = TropicalExpr::scale(-2.0, TropicalExpr::var(0));
        assert_eq!(evaluate(&e, &[3.0]).unwrap(), -6.0);
    }

    #[test]
    fn scale_inside_plus_for_real_linear_combination() {
        // 2*x_0 + 3*x_1 + 5 — typical ReLU pre-activation form.
        let e = TropicalExpr::plus(
            TropicalExpr::plus(
                TropicalExpr::scale(2.0, TropicalExpr::var(0)),
                TropicalExpr::scale(3.0, TropicalExpr::var(1)),
            ),
            TropicalExpr::constant(5.0),
        );
        // x = (1, 2) → 2 + 6 + 5 = 13.
        assert_eq!(evaluate(&e, &[1.0, 2.0]).unwrap(), 13.0);
    }

    #[test]
    fn scale_inside_max_for_general_relu_layer() {
        // max(0, 2*x_0 + 3*x_1 - 1) — a single ReLU neuron with
        // arbitrary real weights.
        let pre_activation = TropicalExpr::plus(
            TropicalExpr::plus(
                TropicalExpr::scale(2.0, TropicalExpr::var(0)),
                TropicalExpr::scale(3.0, TropicalExpr::var(1)),
            ),
            TropicalExpr::constant(-1.0),
        );
        let relu = TropicalExpr::max(vec![
            TropicalExpr::constant(0.0),
            pre_activation,
        ]);
        // x = (1, 1) → max(0, 2+3-1) = max(0, 4) = 4.
        assert_eq!(evaluate(&relu, &[1.0, 1.0]).unwrap(), 4.0);
        // x = (-1, 0) → max(0, -2 + 0 - 1) = max(0, -3) = 0.
        assert_eq!(evaluate(&relu, &[-1.0, 0.0]).unwrap(), 0.0);
    }

    #[test]
    fn scale_by_zero_yields_zero() {
        let e = TropicalExpr::scale(0.0, TropicalExpr::var(0));
        assert_eq!(evaluate(&e, &[100.0]).unwrap(), 0.0);
    }

    #[test]
    fn scale_propagates_var_out_of_range_error() {
        let e = TropicalExpr::scale(2.0, TropicalExpr::var(9));
        let err = evaluate(&e, &[1.0]).unwrap_err();
        assert!(matches!(err, TropicalEvalError::VarOutOfRange { .. }));
    }
}
