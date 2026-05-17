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

/// `-slot[i]` encoded as `Minus(Zero, Slot(i))`. Iter-67 helper —
/// negation primitive built from Minus + closure_zero. Used to
/// express `exp(-θ)` for the sigmoid identity.
pub fn closure_neg_slot(slot_idx: u32) -> EmlClosureExpr {
    EmlClosureExpr::minus(closure_zero(), EmlClosureExpr::slot(slot_idx))
}

/// `exp(-slot[i])` encoded as `eml(Minus(Zero, Slot(i)), One)`.
/// Companion to [`closure_exp`] for negated argument.
pub fn closure_neg_exp(slot_idx: u32) -> EmlClosureExpr {
    EmlClosureExpr::eml(closure_neg_slot(slot_idx), EmlClosureExpr::one())
}

/// `sigmoid(slot[i])` = `1 / (1 + exp(-slot[i]))`.
///
/// Builds `Divide(One, Plus(One, closure_neg_exp(i)))`. Iter-67 — the
/// first cross-IR sigmoid demo using the Divide primitive
/// (iter-66 extension).
pub fn closure_sigmoid(slot_idx: u32) -> EmlClosureExpr {
    let denom = EmlClosureExpr::plus(EmlClosureExpr::one(), closure_neg_exp(slot_idx));
    EmlClosureExpr::divide(EmlClosureExpr::one(), denom)
}

/// `tanh(slot[i])` = `(exp(slot[i]) − exp(-slot[i])) / (exp(slot[i]) + exp(-slot[i]))`.
///
/// Builds `Divide(Minus(closure_exp(i), closure_neg_exp(i)),
///                Plus(closure_exp(i), closure_neg_exp(i)))`.
/// Iter-68 — completes the canonical-activation family alongside
/// `closure_sigmoid` (iter-67).
pub fn closure_tanh(slot_idx: u32) -> EmlClosureExpr {
    let e_pos = closure_exp(slot_idx);
    let e_neg = closure_neg_exp(slot_idx);
    let num = EmlClosureExpr::minus(e_pos.clone(), e_neg.clone());
    let den = EmlClosureExpr::plus(e_pos, e_neg);
    EmlClosureExpr::divide(num, den)
}

/// `a * b` via the identity `a * b = a / (1 / b)`. Iter-70 helper
/// — multiplication isn't a primitive on EmlClosureExpr but can be
/// expressed using two Divide nodes.
///
/// Caveat: this round-trips through `1/b`, so any `b == 0` causes
/// a runtime divide-by-zero error (parallel to direct division).
pub fn closure_mul(a: EmlClosureExpr, b: EmlClosureExpr) -> EmlClosureExpr {
    EmlClosureExpr::divide(a, EmlClosureExpr::divide(EmlClosureExpr::one(), b))
}

/// KL(P || Q) for Bernoulli on natural-parameter coordinates p, q.
///
/// `KL(p, q) = A(p) − A(q) − ∇A(q) · (p − q)`
///         `= softplus(p) − softplus(q) − sigmoid(q) · (p − q)`
///
/// Builds the closure-form expression entirely through helpers:
/// `Minus(Minus(softplus(p), softplus(q)), mul(sigmoid(q), Minus(Slot(p), Slot(q))))`.
///
/// Iter-70 — third Info-IR → EML-IR composition wiring after
/// softplus (iter-59) and sigmoid (iter-67).
pub fn closure_kl_bernoulli(p_slot: u32, q_slot: u32) -> EmlClosureExpr {
    let p_minus_q = EmlClosureExpr::minus(
        EmlClosureExpr::slot(p_slot),
        EmlClosureExpr::slot(q_slot),
    );
    let sig_q = closure_sigmoid(q_slot);
    let product = closure_mul(sig_q, p_minus_q);
    let a_diff = EmlClosureExpr::minus(closure_softplus(p_slot), closure_softplus(q_slot));
    EmlClosureExpr::minus(a_diff, product)
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

    // ── Sigmoid via EML (iter-67) ─────────────────────────────────

    fn rust_sigmoid(theta: f64) -> f64 {
        1.0 / (1.0 + (-theta).exp())
    }

    #[test]
    fn closure_neg_slot_evaluates_to_negation() {
        let v = eval_with_slots(closure_neg_slot(0), vec![3.5]);
        assert_eq!(v, -3.5);
    }

    #[test]
    fn closure_neg_exp_matches_rust() {
        for theta in [-2.0_f64, -0.5, 0.0, 0.5, 2.0] {
            let v = eval_with_slots(closure_neg_exp(0), vec![theta]);
            let expected = (-theta).exp();
            assert!(
                (v - expected).abs() < 1e-12,
                "neg_exp({}) = {}; expected {}", theta, v, expected
            );
        }
    }

    #[test]
    fn closure_sigmoid_at_zero_is_half() {
        let v = eval_with_slots(closure_sigmoid(0), vec![0.0]);
        assert!((v - 0.5).abs() < 1e-12);
    }

    #[test]
    fn closure_sigmoid_at_large_positive_is_near_one() {
        let v = eval_with_slots(closure_sigmoid(0), vec![20.0]);
        assert!((v - 1.0).abs() < 1e-8);
    }

    #[test]
    fn closure_sigmoid_at_large_negative_is_near_zero() {
        let v = eval_with_slots(closure_sigmoid(0), vec![-20.0]);
        assert!(v.abs() < 1e-8);
    }

    #[test]
    fn closure_sigmoid_matches_rust_across_grid() {
        for theta in [-3.0_f64, -1.0, -0.5, 0.0, 0.5, 1.0, 3.0] {
            let v = eval_with_slots(closure_sigmoid(0), vec![theta]);
            let expected = rust_sigmoid(theta);
            assert!(
                (v - expected).abs() < 1e-12,
                "sigmoid({}) = {}; expected {}", theta, v, expected
            );
        }
    }

    #[test]
    fn closure_sigmoid_is_monotone() {
        let thetas = [-3.0_f64, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0];
        let values: Vec<f64> = thetas
            .iter()
            .map(|&t| eval_with_slots(closure_sigmoid(0), vec![t]))
            .collect();
        for w in values.windows(2) {
            assert!(w[0] < w[1], "sigmoid not monotone: {:?}", values);
        }
    }

    #[test]
    fn closure_sigmoid_matches_info_ir_bernoulli_dual_map() {
        // Bernoulli's η = ∇A(θ) = sigmoid(θ). Verify the closure
        // sigmoid matches Info-IR's dual_map(Bernoulli, [θ]).
        use super::super::super::info_ir::{dual_map, ExpFamily};
        for theta in [-2.0_f64, -1.0, -0.5, 0.0, 0.5, 1.0, 2.0] {
            let via_eml = eval_with_slots(closure_sigmoid(0), vec![theta]);
            let via_info = dual_map(&ExpFamily::Bernoulli, &[theta])[0];
            assert!(
                (via_eml - via_info).abs() < 1e-12,
                "sigmoid({}): eml={} info={}", theta, via_eml, via_info
            );
        }
    }

    // ── tanh via EML (iter-68) ────────────────────────────────────

    #[test]
    fn closure_tanh_at_zero_is_zero() {
        let v = eval_with_slots(closure_tanh(0), vec![0.0]);
        assert!(v.abs() < 1e-12);
    }

    #[test]
    fn closure_tanh_at_one_matches_rust() {
        let v = eval_with_slots(closure_tanh(0), vec![1.0]);
        assert!((v - 1.0_f64.tanh()).abs() < 1e-12);
    }

    #[test]
    fn closure_tanh_at_negative_matches_rust() {
        let v = eval_with_slots(closure_tanh(0), vec![-1.5]);
        assert!((v - (-1.5_f64).tanh()).abs() < 1e-12);
    }

    #[test]
    fn closure_tanh_at_large_positive_approaches_one() {
        let v = eval_with_slots(closure_tanh(0), vec![10.0]);
        assert!((v - 1.0).abs() < 1e-8);
    }

    #[test]
    fn closure_tanh_at_large_negative_approaches_minus_one() {
        let v = eval_with_slots(closure_tanh(0), vec![-10.0]);
        assert!((v - (-1.0)).abs() < 1e-8);
    }

    #[test]
    fn closure_tanh_matches_rust_across_grid() {
        for theta in [-3.0_f64, -1.0, -0.5, 0.0, 0.5, 1.0, 3.0] {
            let v = eval_with_slots(closure_tanh(0), vec![theta]);
            let expected = theta.tanh();
            assert!(
                (v - expected).abs() < 1e-12,
                "tanh({}) = {}; expected {}", theta, v, expected
            );
        }
    }

    #[test]
    fn closure_tanh_is_odd() {
        // tanh(-x) = -tanh(x).
        for theta in [0.5_f64, 1.0, 2.0, 5.0] {
            let pos = eval_with_slots(closure_tanh(0), vec![theta]);
            let neg = eval_with_slots(closure_tanh(0), vec![-theta]);
            assert!(
                (pos + neg).abs() < 1e-12,
                "tanh oddness fail: tanh({})={} tanh({})={}", theta, pos, -theta, neg
            );
        }
    }

    #[test]
    fn closure_tanh_is_sigmoid_2x_minus_1_shifted_identity() {
        // Classical identity: tanh(x) = 2*sigmoid(2x) - 1.
        // Verify the two closure_builders families agree on this
        // identity within numerical tolerance.
        for theta in [-1.5_f64, -0.5, 0.0, 0.5, 1.5] {
            let direct = eval_with_slots(closure_tanh(0), vec![theta]);
            let via_sigmoid = 2.0 * eval_with_slots(closure_sigmoid(0), vec![2.0 * theta]) - 1.0;
            assert!(
                (direct - via_sigmoid).abs() < 1e-12,
                "tanh({}) = {}; via sigmoid identity = {}", theta, direct, via_sigmoid
            );
        }
    }

    // ── closure_mul + closure_kl_bernoulli (iter-70) ──────────────

    #[test]
    fn closure_mul_simple() {
        // 3 * 4 = 12. Use closure_zero for slot-less constants? No —
        // build literal trees: 3 = Plus(Plus(One,One), One), 4 = Plus(3, One).
        // Simpler: use slots.
        let mul = closure_mul(EmlClosureExpr::slot(0), EmlClosureExpr::slot(1));
        let v = eval_with_slots(mul, vec![3.0, 4.0]);
        assert!((v - 12.0).abs() < 1e-12);
    }

    #[test]
    fn closure_mul_with_negative() {
        let mul = closure_mul(EmlClosureExpr::slot(0), EmlClosureExpr::slot(1));
        let v = eval_with_slots(mul, vec![-2.5, 4.0]);
        assert!((v - (-10.0)).abs() < 1e-12);
    }

    #[test]
    fn closure_mul_by_one_is_identity() {
        let mul = closure_mul(EmlClosureExpr::slot(0), EmlClosureExpr::one());
        let v = eval_with_slots(mul, vec![7.5]);
        assert!((v - 7.5).abs() < 1e-12);
    }

    #[test]
    fn closure_kl_bernoulli_zero_when_p_equals_q() {
        // KL(p, p) = 0.
        for theta in [-1.0_f64, 0.0, 1.0] {
            let v = eval_with_slots(closure_kl_bernoulli(0, 1), vec![theta, theta]);
            assert!(v.abs() < 1e-12, "KL({}, {}) = {} ≠ 0", theta, theta, v);
        }
    }

    #[test]
    fn closure_kl_bernoulli_nonnegative() {
        // KL ≥ 0 always.
        let pairs = [
            (1.0_f64, 0.0),
            (0.0, 1.0),
            (-1.0, 2.0),
            (-0.5, 0.5),
            (2.0, -2.0),
        ];
        for (p, q) in pairs {
            let v = eval_with_slots(closure_kl_bernoulli(0, 1), vec![p, q]);
            assert!(v >= -1e-12, "KL({}, {}) = {} < 0", p, q, v);
        }
    }

    #[test]
    fn closure_kl_bernoulli_matches_info_ir() {
        use super::super::super::info_ir::{kl_divergence, ExpFamily};
        let pairs = [
            (1.0_f64, 0.0),
            (0.0, 1.0),
            (-1.0, 2.0),
            (-0.5, 0.5),
            (2.0, -2.0),
            (0.5, 0.5),
        ];
        for (p, q) in pairs {
            let via_eml = eval_with_slots(closure_kl_bernoulli(0, 1), vec![p, q]);
            let via_info = kl_divergence(&ExpFamily::Bernoulli, &[p], &[q]);
            assert!(
                (via_eml - via_info).abs() < 1e-10,
                "KL({}, {}): eml={} info={}", p, q, via_eml, via_info
            );
        }
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
