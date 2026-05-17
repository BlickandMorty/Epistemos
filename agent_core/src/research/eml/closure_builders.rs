//! Source:
//! - iter-59 `tests/cross_ir_info_to_eml.rs` — softplus via EML.
//! - iter-63 `tests/cross_ir_tropical_to_eml.rs` — log-sum-exp via EML.
//! - iter-64 `docs/fusion/CROSS_IR_LATTICE_STATUS_2026_05_17.md` §5 —
//!   the "closure-form reusability pattern": same ln-via-eml +
//!   exp-via-eml idioms used by both cross-IR arrows.
//!
//! # Closure-form builder helpers
//!
//! Reusable EmlClosureExpr-construction helpers for the common
//! "real-valued" function patterns that Phase C cross-IR composition
//! arrows need. Each helper returns a closure-form expression tree
//! that, when paired with the right constants, evaluates to the
//! named function.
//!
//! ## Idioms
//!
//! - **Zero leaf**: `closure_zero()` = `Minus(One, One)` = 0.
//! - **exp(slot_i)**: `closure_exp(i)` = `eml(Slot(i), One)` =
//!   `exp(slot[i]) − ln(1)` = `exp(slot[i])`.
//! - **ln(y)**: `closure_ln(y)` = `Minus(One, eml(zero, y))` =
//!   `1 − (exp(0) − ln(y))` = `1 − (1 − ln(y))` = `ln(y)`.
//! - **lse(args)**: `closure_lse(args)` = `closure_ln(fold_plus(args))`.
//! - **softplus(slot_i)**: `closure_softplus(i)` = `closure_ln(Plus(One,
//!   closure_exp(i)))` = `ln(1 + exp(slot[i]))`.

use super::closure::EmlClosureExpr;

/// Closure-form encoding of the constant `0` as
/// `Minus(One, One)`. Used as the left argument to
/// [`closure_ln`].
pub fn closure_zero() -> EmlClosureExpr {
    EmlClosureExpr::minus(EmlClosureExpr::one(), EmlClosureExpr::one())
}

/// `exp(slot[i])` encoded as `eml(Slot(i), One)`.
///
/// The identity used: `eml(x, 1) = exp(x) − ln(1) = exp(x)`.
pub fn closure_exp(slot_idx: u32) -> EmlClosureExpr {
    EmlClosureExpr::eml(EmlClosureExpr::slot(slot_idx), EmlClosureExpr::one())
}

/// `ln(y)` encoded as `Minus(One, eml(zero, y))`.
///
/// The identity used: `eml(0, y) = exp(0) − ln(y) = 1 − ln(y)`,
/// so `ln(y) = 1 − eml(0, y) = Minus(One, eml(0, y))`.
pub fn closure_ln(y: EmlClosureExpr) -> EmlClosureExpr {
    EmlClosureExpr::minus(EmlClosureExpr::one(), EmlClosureExpr::eml(closure_zero(), y))
}

/// `lse(args)` = log-sum-exp = `ln(Σ exp(arg_i))`.
///
/// Builds `closure_ln(Plus(arg_0, Plus(arg_1, … Plus(arg_{n-1}, arg_n))))`.
/// Each `arg_i` is expected to already be in "exp-form" (e.g. from
/// [`closure_exp`]).
///
/// `args.len() == 0` returns `closure_ln(One)` = `Minus(One, eml(0, One))`
/// = `1 − (1 − 0)` = `0` (the additive identity for the empty sum;
/// equivalently `ln(1) = 0`).
///
/// `args.len() == 1` returns `closure_ln(args[0])`.
pub fn closure_lse(args: Vec<EmlClosureExpr>) -> EmlClosureExpr {
    let sum = fold_plus_left(args);
    closure_ln(sum)
}

/// `softplus(slot[i])` = `ln(1 + exp(slot[i]))`.
///
/// Builds `closure_ln(Plus(One, closure_exp(i)))`.
pub fn closure_softplus(slot_idx: u32) -> EmlClosureExpr {
    let one_plus_exp = EmlClosureExpr::plus(EmlClosureExpr::one(), closure_exp(slot_idx));
    closure_ln(one_plus_exp)
}

/// Left-fold a vector of [`EmlClosureExpr`] under [`EmlClosureExpr::plus`].
/// Empty → [`EmlClosureExpr::One`] (the additive-but-encoded-as-multiplicative
/// identity in this context — sum is 1 when there's nothing else, matching
/// the `lse(0 args) = 0 = ln(1)` convention).
fn fold_plus_left(parts: Vec<EmlClosureExpr>) -> EmlClosureExpr {
    let mut iter = parts.into_iter();
    let mut acc = match iter.next() {
        Some(first) => first,
        None => return EmlClosureExpr::One,
    };
    for next in iter {
        acc = EmlClosureExpr::plus(acc, next);
    }
    acc
}

#[cfg(test)]
mod tests {
    use super::super::closure::EmlClosure;
    use super::super::normalize::evaluate_closure;
    use super::*;

    fn eval_with_slots(tree: EmlClosureExpr, slots: Vec<f64>) -> f64 {
        let c = EmlClosure::new(tree, slots).unwrap();
        evaluate_closure(&c).unwrap()
    }

    #[test]
    fn closure_zero_evaluates_to_zero() {
        let v = eval_with_slots(closure_zero(), vec![]);
        assert_eq!(v, 0.0);
    }

    #[test]
    fn closure_exp_at_zero_is_one() {
        // exp(0) = 1.
        let v = eval_with_slots(closure_exp(0), vec![0.0]);
        assert!((v - 1.0).abs() < 1e-12);
    }

    #[test]
    fn closure_exp_at_one_is_e() {
        let v = eval_with_slots(closure_exp(0), vec![1.0]);
        assert!((v - std::f64::consts::E).abs() < 1e-12);
    }

    #[test]
    fn closure_exp_at_negative() {
        let v = eval_with_slots(closure_exp(0), vec![-1.0]);
        assert!((v - (-1.0_f64).exp()).abs() < 1e-12);
    }

    #[test]
    fn closure_ln_of_one_is_zero() {
        // ln(1) = 0.
        let v = eval_with_slots(closure_ln(EmlClosureExpr::one()), vec![]);
        assert!(v.abs() < 1e-12);
    }

    #[test]
    fn closure_ln_of_e_is_one() {
        // ln(e) = 1. Use closure_exp(0) with slot=1 to make e.
        let inner = closure_exp(0);
        let v = eval_with_slots(closure_ln(inner), vec![1.0]);
        assert!((v - 1.0).abs() < 1e-12);
    }

    #[test]
    fn closure_softplus_at_zero_is_ln_two() {
        let v = eval_with_slots(closure_softplus(0), vec![0.0]);
        assert!((v - 2.0_f64.ln()).abs() < 1e-12);
    }

    #[test]
    fn closure_softplus_at_one() {
        let v = eval_with_slots(closure_softplus(0), vec![1.0]);
        let expected = (1.0_f64 + 1.0_f64.exp()).ln();
        assert!((v - expected).abs() < 1e-12);
    }

    #[test]
    fn closure_softplus_at_grid() {
        // Match against Rust's reference across a θ grid.
        for theta in [-3.0_f64, -1.0, 0.0, 1.0, 3.0] {
            let v = eval_with_slots(closure_softplus(0), vec![theta]);
            let expected = (1.0_f64 + theta.exp()).ln();
            assert!(
                (v - expected).abs() < 1e-12,
                "softplus({}) = {}; expected {}",
                theta, v, expected
            );
        }
    }

    #[test]
    fn closure_lse_two_args_matches_log_sum_exp() {
        // lse(a, b) = ln(exp(a) + exp(b)) with closure_exp helpers.
        let args = vec![closure_exp(0), closure_exp(1)];
        let v = eval_with_slots(closure_lse(args), vec![1.0, 2.0]);
        let expected = (1.0_f64.exp() + 2.0_f64.exp()).ln();
        assert!((v - expected).abs() < 1e-12);
    }

    #[test]
    fn closure_lse_three_args() {
        let args = vec![closure_exp(0), closure_exp(1), closure_exp(2)];
        let v = eval_with_slots(closure_lse(args), vec![0.0, 0.5, 1.0]);
        let expected = (1.0_f64 + 0.5_f64.exp() + 1.0_f64.exp()).ln();
        assert!((v - expected).abs() < 1e-12);
    }

    #[test]
    fn closure_lse_one_arg_is_ln() {
        // lse([x]) = ln(x). For x = closure_exp(0) at slot=2:
        //   x evaluates to e^2; ln(e^2) = 2.
        let v = eval_with_slots(closure_lse(vec![closure_exp(0)]), vec![2.0]);
        assert!((v - 2.0).abs() < 1e-12);
    }

    #[test]
    fn closure_lse_empty_is_zero() {
        // lse([]) = ln(1) = 0 by our convention.
        let v = eval_with_slots(closure_lse(vec![]), vec![]);
        assert!(v.abs() < 1e-12);
    }

    // ── Cross-check vs hand-built constructions ────────────────────

    #[test]
    fn closure_softplus_matches_hand_built_from_iter_59() {
        // Iter-59 built softplus manually; this helper should match.
        // Hand-built:
        //   zero = Minus(One, One)
        //   exp_theta = eml(Slot(0), One)
        //   one_plus_exp = Plus(One, exp_theta)
        //   eml_zero_x = eml(zero, one_plus_exp)
        //   tree = Minus(One, eml_zero_x)
        let hand = {
            let zero = EmlClosureExpr::minus(EmlClosureExpr::one(), EmlClosureExpr::one());
            let exp_theta =
                EmlClosureExpr::eml(EmlClosureExpr::slot(0), EmlClosureExpr::one());
            let one_plus_exp = EmlClosureExpr::plus(EmlClosureExpr::one(), exp_theta);
            let eml_zero_x = EmlClosureExpr::eml(zero, one_plus_exp);
            EmlClosureExpr::minus(EmlClosureExpr::one(), eml_zero_x)
        };
        let helper = closure_softplus(0);
        assert_eq!(hand, helper);
    }

    #[test]
    fn closure_lse_matches_hand_built_from_iter_63() {
        // Iter-63 built lse(a, b) manually; the helper with two
        // closure_exp args should produce the same tree.
        let hand = {
            let zero = EmlClosureExpr::minus(EmlClosureExpr::one(), EmlClosureExpr::one());
            let exp_a =
                EmlClosureExpr::eml(EmlClosureExpr::slot(0), EmlClosureExpr::one());
            let exp_b =
                EmlClosureExpr::eml(EmlClosureExpr::slot(1), EmlClosureExpr::one());
            let sum = EmlClosureExpr::plus(exp_a, exp_b);
            let eml_zero_sum = EmlClosureExpr::eml(zero, sum);
            EmlClosureExpr::minus(EmlClosureExpr::one(), eml_zero_sum)
        };
        let helper = closure_lse(vec![closure_exp(0), closure_exp(1)]);
        assert_eq!(hand, helper);
    }
}
