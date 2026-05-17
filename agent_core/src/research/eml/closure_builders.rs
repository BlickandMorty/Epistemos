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

/// `a * b` — proper multiplication primitive. Iter-70 follow-up
/// to the original Divide-trick implementation, which broke when
/// `b == 0`. Now uses [`EmlClosureExpr::Mul`] directly.
pub fn closure_mul(a: EmlClosureExpr, b: EmlClosureExpr) -> EmlClosureExpr {
    EmlClosureExpr::mul(a, b)
}

/// Categorical log-partition `A(θ) = ln(1 + Σ_i exp(θ_i))` for a
/// `k`-class distribution with natural parameters `θ ∈ ℝ^{k-1}`.
///
/// Builds the closure form using closure_lse over the slot indices
/// together with a "One" term for the implicit zero-pinned class:
/// `closure_lse([One, exp(θ_0), exp(θ_1), …, exp(θ_{k-2})])`.
///
/// Iter-72 — extends Info → EML cross-wiring from Bernoulli
/// (closure_softplus) to general Categorical.
pub fn closure_categorical_log_partition(slot_indices: &[u32]) -> EmlClosureExpr {
    let mut args = Vec::with_capacity(slot_indices.len() + 1);
    args.push(EmlClosureExpr::one()); // exp(0) = 1, the pinned class
    for &idx in slot_indices {
        args.push(closure_exp(idx));
    }
    closure_lse(args)
}

/// Raw Categorical normalizer `Z(θ) = 1 + Σ_i exp(θ_i)`, the
/// non-log denominator of the softmax. Used internally by the
/// softmax helpers below.
fn categorical_partition_inner(slot_indices: &[u32]) -> EmlClosureExpr {
    let mut acc = EmlClosureExpr::one(); // exp(0) for the pinned class
    for &idx in slot_indices {
        acc = EmlClosureExpr::plus(acc, closure_exp(idx));
    }
    acc
}

/// Softmax slot probability `η_i = exp(θ_{target}) / (1 + Σ_j exp(θ_j))`.
///
/// This is one component of `info_ir::dual_map(Categorical{k}, θ)`,
/// the dual / mean-parameter map for the Categorical family. The
/// `target_slot` must be one of the slot indices listed in
/// `slot_indices` (the full set of k-1 non-pinned slots).
///
/// Encoding:
/// `Divide(closure_exp(target_slot),
///         Plus(One, closure_exp(slot_indices[0]), …))`.
///
/// Iter-73 — extends Info → EML Categorical wiring from
/// log_partition (iter-72) to dual_map / softmax.
pub fn closure_categorical_softmax_slot(
    target_slot: u32,
    slot_indices: &[u32],
) -> EmlClosureExpr {
    EmlClosureExpr::divide(
        closure_exp(target_slot),
        categorical_partition_inner(slot_indices),
    )
}

/// Softmax probability for the pinned reference class
/// `η_{k-1} = 1 / (1 + Σ_j exp(θ_j))`.
///
/// Iter-73 — companion to `closure_categorical_softmax_slot`. The
/// pinned class is the implicit one with `θ = 0`; it isn't returned
/// by `info_ir::dual_map`, but `1 − Σ slot_probs` equals this
/// quantity and we expose it as a first-class helper.
pub fn closure_categorical_softmax_pinned(slot_indices: &[u32]) -> EmlClosureExpr {
    EmlClosureExpr::divide(
        EmlClosureExpr::one(),
        categorical_partition_inner(slot_indices),
    )
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

/// Gaussian log-partition `A(θ; σ²) = (σ² · θ²) / 2` for a single
/// scalar natural parameter `θ` with variance `σ²` provided as a
/// slot value.
///
/// The closure form has no constant variant, so `σ²` is encoded
/// as a slot input rather than a compile-time literal — the caller
/// supplies the variance at evaluation time alongside `θ`.
///
/// Encoding:
/// `Divide(Mul(Slot(σ²), Mul(Slot(θ), Slot(θ))), Plus(One, One))`.
///
/// Iter-75 — extends Info → EML cross-wiring from Categorical
/// (iters 72-74) to the Gaussian exp-family.
pub fn closure_gaussian_log_partition(theta_slot: u32, sigma2_slot: u32) -> EmlClosureExpr {
    let theta_sq = closure_mul(
        EmlClosureExpr::slot(theta_slot),
        EmlClosureExpr::slot(theta_slot),
    );
    let scaled = closure_mul(EmlClosureExpr::slot(sigma2_slot), theta_sq);
    let two = EmlClosureExpr::plus(EmlClosureExpr::one(), EmlClosureExpr::one());
    EmlClosureExpr::divide(scaled, two)
}

/// Gaussian dual / mean parameter `η = ∇A(θ; σ²) = σ² · θ`.
///
/// Single-term linear map; encoded as `Mul(Slot(σ²), Slot(θ))`.
///
/// Iter-76 — completes Gaussian's A + ∇A pair after iter-75
/// log_partition. KL (iter-77) closes the Gaussian Bregman trio.
pub fn closure_gaussian_dual_map(theta_slot: u32, sigma2_slot: u32) -> EmlClosureExpr {
    closure_mul(
        EmlClosureExpr::slot(sigma2_slot),
        EmlClosureExpr::slot(theta_slot),
    )
}

/// KL(P || Q) for the Gaussian{σ²} exp-family on natural-parameter
/// coordinates `p, q`. Both distributions share the same variance.
///
/// `KL(p, q) = A(p) − A(q) − ∇A(q) · (p − q)`
///         `= (σ²/2) · (p − q)²`
///
/// The closure form mirrors the Bregman composition exactly (not
/// the simplified squared-distance form), to stay structurally
/// parallel with [`closure_kl_bernoulli`] and [`closure_kl_categorical`].
///
/// Iter-77 — completes the third Info-IR Bregman trio. After this,
/// every (A, ∇A, KL) triple from `info_ir` is wired to EML closure
/// form for Bernoulli, Categorical, AND Gaussian.
pub fn closure_kl_gaussian(p_slot: u32, q_slot: u32, sigma2_slot: u32) -> EmlClosureExpr {
    let a_p = closure_gaussian_log_partition(p_slot, sigma2_slot);
    let a_q = closure_gaussian_log_partition(q_slot, sigma2_slot);
    let eta_q = closure_gaussian_dual_map(q_slot, sigma2_slot);
    let p_minus_q = EmlClosureExpr::minus(
        EmlClosureExpr::slot(p_slot),
        EmlClosureExpr::slot(q_slot),
    );
    let inner = closure_mul(eta_q, p_minus_q);
    EmlClosureExpr::minus(EmlClosureExpr::minus(a_p, a_q), inner)
}

/// KL(P || Q) for a Categorical{k} distribution on natural-parameter
/// coordinates `p, q ∈ ℝ^{k-1}`.
///
/// `KL(p, q) = A(p) − A(q) − ⟨∇A(q), p − q⟩`
///         `= categorical_log_partition(p)`
///         `- categorical_log_partition(q)`
///         `- Σ_i softmax_slot_i(q) · (p_i − q_i)`
///
/// `p_slots` and `q_slots` are the slot-index vectors for the two
/// distributions and must have equal length (the family's k-1).
/// The function panics if they differ in length or are empty.
///
/// Iter-74 — completes the Categorical Bregman trio (after iter-72
/// log_partition and iter-73 softmax/dual_map).
pub fn closure_kl_categorical(p_slots: &[u32], q_slots: &[u32]) -> EmlClosureExpr {
    assert_eq!(
        p_slots.len(),
        q_slots.len(),
        "p_slots and q_slots must share dimensionality (k-1)",
    );
    assert!(!p_slots.is_empty(), "Categorical requires k ≥ 2 → at least 1 slot");

    let a_p = closure_categorical_log_partition(p_slots);
    let a_q = closure_categorical_log_partition(q_slots);

    let mut terms = p_slots.iter().zip(q_slots.iter()).map(|(p, q)| {
        let eta_i = closure_categorical_softmax_slot(*q, q_slots);
        let diff = EmlClosureExpr::minus(
            EmlClosureExpr::slot(*p),
            EmlClosureExpr::slot(*q),
        );
        closure_mul(eta_i, diff)
    });
    let first = terms.next().unwrap();
    let inner = terms.fold(first, |acc, term| EmlClosureExpr::plus(acc, term));

    EmlClosureExpr::minus(EmlClosureExpr::minus(a_p, a_q), inner)
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

    // ── Categorical log_partition via EML (iter-72) ───────────────

    #[test]
    fn closure_categorical_log_partition_k2_matches_bernoulli() {
        // For k=2, Categorical with 1 natural parameter should
        // produce the same A(θ) as Bernoulli.
        for theta in [-1.0_f64, 0.0, 1.0] {
            let cat = eval_with_slots(
                closure_categorical_log_partition(&[0]),
                vec![theta],
            );
            let bern = eval_with_slots(closure_softplus(0), vec![theta]);
            assert!(
                (cat - bern).abs() < 1e-12,
                "Categorical_k=2({}) = {}; Bernoulli softplus = {}", theta, cat, bern
            );
        }
    }

    #[test]
    fn closure_categorical_log_partition_k3_at_zeros() {
        // A([0, 0]) = ln(1 + 1 + 1) = ln 3 for Categorical{k=3}.
        let v = eval_with_slots(
            closure_categorical_log_partition(&[0, 1]),
            vec![0.0, 0.0],
        );
        assert!((v - 3.0_f64.ln()).abs() < 1e-12);
    }

    #[test]
    fn closure_categorical_log_partition_matches_info_ir() {
        use super::super::super::info_ir::{log_partition, ExpFamily};

        // k=3 cases.
        let cases = [
            (vec![0.0_f64, 0.0]),
            (vec![1.0, -1.0]),
            (vec![-0.5, 0.5]),
            (vec![2.0, 1.0]),
        ];
        for theta in &cases {
            let via_eml = eval_with_slots(
                closure_categorical_log_partition(&[0, 1]),
                theta.clone(),
            );
            let via_info = log_partition(&ExpFamily::Categorical { k: 3 }, theta);
            assert!(
                (via_eml - via_info).abs() < 1e-12,
                "Categorical_k=3({:?}): eml={} info={}", theta, via_eml, via_info
            );
        }

        // k=4 case.
        let theta_k4 = vec![0.5_f64, -0.3, 1.0];
        let via_eml = eval_with_slots(
            closure_categorical_log_partition(&[0, 1, 2]),
            theta_k4.clone(),
        );
        let via_info = log_partition(&ExpFamily::Categorical { k: 4 }, &theta_k4);
        assert!(
            (via_eml - via_info).abs() < 1e-12,
            "Categorical_k=4({:?}): eml={} info={}", theta_k4, via_eml, via_info
        );
    }

    #[test]
    fn closure_categorical_log_partition_grows_with_k() {
        // A_k(all zeros) = ln(k). Verify monotone growth.
        let a_k2 = eval_with_slots(closure_categorical_log_partition(&[0]), vec![0.0]);
        let a_k3 = eval_with_slots(
            closure_categorical_log_partition(&[0, 1]),
            vec![0.0, 0.0],
        );
        let a_k4 = eval_with_slots(
            closure_categorical_log_partition(&[0, 1, 2]),
            vec![0.0, 0.0, 0.0],
        );
        assert!(a_k2 < a_k3);
        assert!(a_k3 < a_k4);
        assert!((a_k2 - 2.0_f64.ln()).abs() < 1e-12);
        assert!((a_k3 - 3.0_f64.ln()).abs() < 1e-12);
        assert!((a_k4 - 4.0_f64.ln()).abs() < 1e-12);
    }

    // ── Categorical softmax / dual_map via EML (iter-73) ──────────

    #[test]
    fn closure_categorical_softmax_slot_k2_matches_sigmoid() {
        // For k=2 (1 slot), softmax_slot(0, [0]) === sigmoid(θ_0).
        for theta in [-2.0_f64, -0.5, 0.0, 0.7, 3.0] {
            let cat = eval_with_slots(
                closure_categorical_softmax_slot(0, &[0]),
                vec![theta],
            );
            let sig = eval_with_slots(closure_sigmoid(0), vec![theta]);
            assert!(
                (cat - sig).abs() < 1e-12,
                "softmax_slot(k=2, {}) = {}; sigmoid = {}", theta, cat, sig
            );
        }
    }

    #[test]
    fn closure_categorical_softmax_at_zero_is_uniform() {
        // For k=3 at θ=(0,0), each slot probability = 1/3, and the
        // pinned class also = 1/3.
        let slots = [0_u32, 1];
        let p0 = eval_with_slots(
            closure_categorical_softmax_slot(0, &slots),
            vec![0.0, 0.0],
        );
        let p1 = eval_with_slots(
            closure_categorical_softmax_slot(1, &slots),
            vec![0.0, 0.0],
        );
        let pp = eval_with_slots(
            closure_categorical_softmax_pinned(&slots),
            vec![0.0, 0.0],
        );
        for p in [p0, p1, pp] {
            assert!((p - 1.0 / 3.0).abs() < 1e-12, "p={}", p);
        }
    }

    #[test]
    fn closure_categorical_softmax_probabilities_sum_to_one() {
        // p_0 + p_1 + p_pinned = 1 for k=3 over a grid of θ.
        let cases = [
            (0.0_f64, 0.0),
            (1.0, -1.0),
            (-2.0, 3.0),
            (0.5, 0.5),
            (-0.7, 0.2),
        ];
        let slots = [0_u32, 1];
        for (a, b) in cases {
            let p0 = eval_with_slots(
                closure_categorical_softmax_slot(0, &slots),
                vec![a, b],
            );
            let p1 = eval_with_slots(
                closure_categorical_softmax_slot(1, &slots),
                vec![a, b],
            );
            let pp = eval_with_slots(
                closure_categorical_softmax_pinned(&slots),
                vec![a, b],
            );
            let s = p0 + p1 + pp;
            assert!((s - 1.0).abs() < 1e-12, "sum at ({}, {}) = {}", a, b, s);
        }
    }

    #[test]
    fn closure_categorical_softmax_matches_info_ir_dual_map() {
        use super::super::super::info_ir::{dual_map, ExpFamily};

        let cases_k3 = [
            vec![0.0_f64, 0.0],
            vec![1.0, -1.0],
            vec![-0.5, 0.5],
            vec![2.0, 1.0],
            vec![-3.0, 2.5],
        ];
        let slots_k3 = [0_u32, 1];
        for theta in &cases_k3 {
            let via_info = dual_map(&ExpFamily::Categorical { k: 3 }, theta);
            for (i, &slot) in slots_k3.iter().enumerate() {
                let via_eml = eval_with_slots(
                    closure_categorical_softmax_slot(slot, &slots_k3),
                    theta.clone(),
                );
                assert!(
                    (via_eml - via_info[i]).abs() < 1e-12,
                    "k=3 slot {} at {:?}: eml={} info={}",
                    slot, theta, via_eml, via_info[i]
                );
            }
        }

        // k=4 case.
        let theta_k4 = vec![0.5_f64, -0.3, 1.0];
        let slots_k4 = [0_u32, 1, 2];
        let via_info = dual_map(&ExpFamily::Categorical { k: 4 }, &theta_k4);
        for (i, &slot) in slots_k4.iter().enumerate() {
            let via_eml = eval_with_slots(
                closure_categorical_softmax_slot(slot, &slots_k4),
                theta_k4.clone(),
            );
            assert!(
                (via_eml - via_info[i]).abs() < 1e-12,
                "k=4 slot {}: eml={} info={}", slot, via_eml, via_info[i]
            );
        }
    }

    // ── Categorical KL via EML (iter-74) ──────────────────────────

    #[test]
    fn closure_kl_categorical_reflexivity_distinct_slots() {
        // KL(p, p) = 0 when p_slots and q_slots are *different* slot
        // indices that happen to hold identical values. Verifies the
        // closure form genuinely encodes the math, not slot identity.
        let kl = eval_with_slots(
            closure_kl_categorical(&[0, 1], &[2, 3]),
            vec![1.0, -0.5, 1.0, -0.5],
        );
        assert!(kl.abs() < 1e-12, "KL(p, p) = {} (should be 0)", kl);
    }

    #[test]
    fn closure_kl_categorical_non_negative() {
        // Gibbs' inequality: KL ≥ 0 for all p, q.
        let cases = [
            (vec![1.0_f64, 0.5], vec![0.0, 0.0]),
            (vec![0.0, 0.0], vec![1.0, 0.5]),
            (vec![-2.0, 3.0], vec![0.5, -0.5]),
            (vec![1.0, -1.0], vec![-1.0, 1.0]),
        ];
        for (p, q) in cases {
            let mut slots = p.clone();
            slots.extend(q.clone());
            let kl = eval_with_slots(
                closure_kl_categorical(&[0, 1], &[2, 3]),
                slots,
            );
            assert!(
                kl >= -1e-12,
                "KL(p={:?}, q={:?}) = {} (must be ≥ 0)", p, q, kl
            );
        }
    }

    #[test]
    fn closure_kl_categorical_k2_matches_kl_bernoulli() {
        // For k=2, Categorical KL must equal Bernoulli KL on the
        // single slot of natural parameters.
        let cases = [
            (1.0_f64, 0.0),
            (0.0, 1.0),
            (-1.0, 2.0),
            (0.5, -0.5),
            (2.0, -2.0),
        ];
        for (p, q) in cases {
            let cat = eval_with_slots(
                closure_kl_categorical(&[0], &[1]),
                vec![p, q],
            );
            let bern = eval_with_slots(closure_kl_bernoulli(0, 1), vec![p, q]);
            assert!(
                (cat - bern).abs() < 1e-10,
                "k=2 cat KL({}, {}) = {}; bern KL = {}", p, q, cat, bern
            );
        }
    }

    #[test]
    fn closure_kl_categorical_matches_info_ir() {
        use super::super::super::info_ir::{kl_divergence, ExpFamily};

        // k=3 cases.
        let cases_k3: &[(Vec<f64>, Vec<f64>)] = &[
            (vec![1.0, -1.0], vec![0.0, 0.0]),
            (vec![0.0, 0.0], vec![1.0, -1.0]),
            (vec![-0.5, 0.5], vec![2.0, 1.0]),
            (vec![2.0, 1.0], vec![-0.5, 0.5]),
            (vec![-2.0, 3.0], vec![0.5, -0.7]),
        ];
        for (p, q) in cases_k3 {
            let mut slots = p.clone();
            slots.extend(q.clone());
            let via_eml = eval_with_slots(
                closure_kl_categorical(&[0, 1], &[2, 3]),
                slots,
            );
            let via_info = kl_divergence(&ExpFamily::Categorical { k: 3 }, p, q);
            assert!(
                (via_eml - via_info).abs() < 1e-10,
                "k=3 KL(p={:?}, q={:?}): eml={} info={}",
                p, q, via_eml, via_info
            );
        }

        // k=4 case.
        let p_k4 = vec![0.5_f64, -0.3, 1.0];
        let q_k4 = vec![0.0_f64, 0.5, -0.5];
        let mut slots_k4 = p_k4.clone();
        slots_k4.extend(q_k4.clone());
        let via_eml = eval_with_slots(
            closure_kl_categorical(&[0, 1, 2], &[3, 4, 5]),
            slots_k4,
        );
        let via_info = kl_divergence(&ExpFamily::Categorical { k: 4 }, &p_k4, &q_k4);
        assert!(
            (via_eml - via_info).abs() < 1e-10,
            "k=4 KL: eml={} info={}", via_eml, via_info
        );
    }

    // ── Gaussian log_partition via EML (iter-75) ──────────────────

    #[test]
    fn closure_gaussian_log_partition_at_theta_zero_is_zero() {
        // A(0; σ²) = 0 for any σ².
        for sigma2 in [0.5_f64, 1.0, 2.0, 4.0] {
            let v = eval_with_slots(
                closure_gaussian_log_partition(0, 1),
                vec![0.0, sigma2],
            );
            assert_eq!(v, 0.0);
        }
    }

    #[test]
    fn closure_gaussian_log_partition_unit_variance_known_values() {
        // σ² = 1: A(θ) = θ²/2.
        // θ=2  → 2.0
        // θ=√2 → 1.0
        let v = eval_with_slots(
            closure_gaussian_log_partition(0, 1),
            vec![2.0, 1.0],
        );
        assert!((v - 2.0).abs() < 1e-12, "A(2; 1) = {}", v);

        let v2 = eval_with_slots(
            closure_gaussian_log_partition(0, 1),
            vec![std::f64::consts::SQRT_2, 1.0],
        );
        assert!((v2 - 1.0).abs() < 1e-12, "A(√2; 1) = {}", v2);
    }

    #[test]
    fn closure_gaussian_log_partition_is_even_in_theta() {
        // A(-θ; σ²) = A(θ; σ²) — quadratic symmetry.
        for theta in [-3.0_f64, -1.0, -0.25, 0.25, 1.0, 3.0] {
            for sigma2 in [0.5_f64, 1.0, 2.0] {
                let v_pos = eval_with_slots(
                    closure_gaussian_log_partition(0, 1),
                    vec![theta.abs(), sigma2],
                );
                let v_neg = eval_with_slots(
                    closure_gaussian_log_partition(0, 1),
                    vec![-theta.abs(), sigma2],
                );
                assert!(
                    (v_pos - v_neg).abs() < 1e-12,
                    "A({}, {}) = {}; A({}, {}) = {}",
                    theta.abs(), sigma2, v_pos, -theta.abs(), sigma2, v_neg
                );
            }
        }
    }

    // ── Gaussian KL via EML (iter-77) ─────────────────────────────

    #[test]
    fn closure_kl_gaussian_reflexivity_distinct_slots() {
        // KL(p, p) = 0 with p_slot and q_slot distinct but holding
        // the same value.
        let kl = eval_with_slots(
            closure_kl_gaussian(0, 1, 2),
            vec![1.5, 1.5, 2.0],
        );
        assert!(kl.abs() < 1e-12, "KL(p, p) = {} (should be 0)", kl);
    }

    #[test]
    fn closure_kl_gaussian_non_negative() {
        // Gibbs' inequality.
        let cases = [
            (0.0_f64, 1.0, 1.0),
            (1.0, 0.0, 1.0),
            (-1.0, 2.0, 0.5),
            (2.0, -2.0, 2.0),
            (0.3, -0.7, 4.0),
        ];
        for (p, q, sigma2) in cases {
            let kl = eval_with_slots(
                closure_kl_gaussian(0, 1, 2),
                vec![p, q, sigma2],
            );
            assert!(
                kl >= -1e-12,
                "KL(p={}, q={}, σ²={}) = {} (must be ≥ 0)", p, q, sigma2, kl
            );
        }
    }

    #[test]
    fn closure_kl_gaussian_closed_form_squared_distance() {
        // Gaussian Bregman simplifies to (σ²/2)·(p-q)².
        for sigma2 in [0.5_f64, 1.0, 2.0] {
            for (p, q) in [(1.0_f64, 0.0), (-1.0, 2.0), (3.0, 0.5), (-0.5, -1.5)] {
                let via_eml = eval_with_slots(
                    closure_kl_gaussian(0, 1, 2),
                    vec![p, q, sigma2],
                );
                let expected = 0.5 * sigma2 * (p - q).powi(2);
                assert!(
                    (via_eml - expected).abs() < 1e-12,
                    "KL(p={}, q={}, σ²={}) = {}; expected (σ²/2)(p-q)² = {}",
                    p, q, sigma2, via_eml, expected
                );
            }
        }
    }

    #[test]
    fn closure_kl_gaussian_matches_info_ir() {
        use super::super::super::info_ir::{kl_divergence, ExpFamily};

        for variance in [0.5_f64, 1.0, 1.5, 2.0, 4.0] {
            let cases = [
                (1.0_f64, 0.0),
                (0.0, 1.0),
                (-1.0, 2.0),
                (2.0, -2.0),
                (0.5, -0.5),
                (3.0, 1.0),
            ];
            for (p, q) in cases {
                let via_eml = eval_with_slots(
                    closure_kl_gaussian(0, 1, 2),
                    vec![p, q, variance],
                );
                let via_info = kl_divergence(
                    &ExpFamily::Gaussian { variance },
                    &[p],
                    &[q],
                );
                assert!(
                    (via_eml - via_info).abs() < 1e-10,
                    "KL(p={}, q={}, σ²={}): eml={} info={}",
                    p, q, variance, via_eml, via_info
                );
            }
        }
    }

    // ── Gaussian dual_map via EML (iter-76) ───────────────────────

    #[test]
    fn closure_gaussian_dual_map_at_theta_zero_is_zero() {
        for sigma2 in [0.5_f64, 1.0, 2.0] {
            let v = eval_with_slots(
                closure_gaussian_dual_map(0, 1),
                vec![0.0, sigma2],
            );
            assert_eq!(v, 0.0);
        }
    }

    #[test]
    fn closure_gaussian_dual_map_unit_variance_is_identity() {
        // σ² = 1: η = θ.
        for theta in [-3.0_f64, -1.0, 0.0, 0.5, 2.0] {
            let v = eval_with_slots(
                closure_gaussian_dual_map(0, 1),
                vec![theta, 1.0],
            );
            assert!((v - theta).abs() < 1e-12, "η = {} for θ = {}", v, theta);
        }
    }

    #[test]
    fn closure_gaussian_dual_map_is_linear_in_theta() {
        // η(αθ; σ²) = α · η(θ; σ²). Linearity follows from η = σ²θ.
        let sigma2 = 1.5_f64;
        let theta = 0.7_f64;
        let base = eval_with_slots(
            closure_gaussian_dual_map(0, 1),
            vec![theta, sigma2],
        );
        for alpha in [0.0_f64, 0.5, 2.0, -3.0] {
            let scaled = eval_with_slots(
                closure_gaussian_dual_map(0, 1),
                vec![alpha * theta, sigma2],
            );
            assert!(
                (scaled - alpha * base).abs() < 1e-12,
                "η({}·θ) = {}; α·η(θ) = {}", alpha, scaled, alpha * base
            );
        }
    }

    #[test]
    fn closure_gaussian_dual_map_matches_info_ir() {
        use super::super::super::info_ir::{dual_map, ExpFamily};

        for variance in [0.5_f64, 1.0, 2.0, 4.0] {
            for theta in [-3.0_f64, -1.0, 0.0, 0.5, 2.0, 3.0] {
                let via_eml = eval_with_slots(
                    closure_gaussian_dual_map(0, 1),
                    vec![theta, variance],
                );
                let via_info = dual_map(
                    &ExpFamily::Gaussian { variance },
                    &[theta],
                );
                assert!(
                    (via_eml - via_info[0]).abs() < 1e-12,
                    "η(θ={}, σ²={}): eml={} info={}",
                    theta, variance, via_eml, via_info[0]
                );
            }
        }
    }

    #[test]
    fn closure_gaussian_log_partition_matches_info_ir() {
        use super::super::super::info_ir::{log_partition, ExpFamily};

        for variance in [0.5_f64, 1.0, 1.5, 2.0, 4.0] {
            for theta in [-3.0_f64, -1.0, -0.5, 0.0, 0.25, 1.0, 3.0] {
                let via_eml = eval_with_slots(
                    closure_gaussian_log_partition(0, 1),
                    vec![theta, variance],
                );
                let via_info = log_partition(
                    &ExpFamily::Gaussian { variance },
                    &[theta],
                );
                assert!(
                    (via_eml - via_info).abs() < 1e-12,
                    "A(θ={}, σ²={}): eml={} info={}",
                    theta, variance, via_eml, via_info
                );
            }
        }
    }

    #[test]
    fn closure_categorical_softmax_saturates() {
        // At large positive θ_0 only, slot 0 → 1 and pinned → 0.
        let p0 = eval_with_slots(
            closure_categorical_softmax_slot(0, &[0]),
            vec![20.0],
        );
        let pp = eval_with_slots(
            closure_categorical_softmax_pinned(&[0]),
            vec![20.0],
        );
        assert!(p0 > 1.0 - 1e-8);
        assert!(pp < 1e-8);
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
