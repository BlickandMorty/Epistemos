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
    };
    if v.is_nan() {
        return Err(TropicalEvalError::NonFiniteIntermediate { value: v });
    }
    Ok(v)
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
}
