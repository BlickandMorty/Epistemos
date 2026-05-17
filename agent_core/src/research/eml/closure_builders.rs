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

/// Bernoulli log-probability of the `X=1` outcome,
/// `log P(X=1) = log σ(θ) = -softplus(-θ)`.
///
/// Encoding via the closure-form negation trick:
/// `Minus(Zero, closure_softplus(neg_θ_slot))` — but here we save
/// the round-trip by going through closure_softplus on a negated
/// slot: `Minus(zero, closure_softplus_of(-θ))`.
///
/// Iter-78 — log-probability primitive for cross-entropy /
/// likelihood under Bernoulli.
pub fn closure_bernoulli_log_prob_one(theta_slot: u32) -> EmlClosureExpr {
    // -softplus(-θ): negation of softplus applied to the negated slot.
    // closure_neg_slot returns Minus(zero, Slot(idx)) — we cannot
    // directly pass it as the argument to closure_softplus (which
    // takes a slot index). Build the softplus manually with the
    // negated slot as the argument to closure_ln(Plus(One, exp_neg)).
    let exp_neg = EmlClosureExpr::eml(closure_neg_slot(theta_slot), EmlClosureExpr::one());
    let one_plus_exp_neg = EmlClosureExpr::plus(EmlClosureExpr::one(), exp_neg);
    let log_one_plus_exp_neg = closure_ln(one_plus_exp_neg);
    EmlClosureExpr::minus(closure_zero(), log_one_plus_exp_neg)
}

/// Bernoulli log-probability of the `X=0` outcome,
/// `log P(X=0) = log(1 − σ(θ)) = -softplus(θ)`.
///
/// Encoding: `Minus(Zero, closure_softplus(θ))`.
///
/// Iter-78 — companion to `closure_bernoulli_log_prob_one`.
pub fn closure_bernoulli_log_prob_zero(theta_slot: u32) -> EmlClosureExpr {
    EmlClosureExpr::minus(closure_zero(), closure_softplus(theta_slot))
}

/// Categorical log-probability of a specific non-pinned slot,
/// `log P(X=i) = θ_i − A(θ)` where `A(θ) = log(1 + Σ_j exp(θ_j))`.
///
/// Encoding:
/// `Minus(Slot(target_slot), closure_categorical_log_partition(slots))`.
///
/// Iter-78 — Categorical log-prob; pairs with
/// `closure_categorical_softmax_slot` (exp gives back the prob).
pub fn closure_categorical_log_prob_slot(
    target_slot: u32,
    slot_indices: &[u32],
) -> EmlClosureExpr {
    EmlClosureExpr::minus(
        EmlClosureExpr::slot(target_slot),
        closure_categorical_log_partition(slot_indices),
    )
}

/// Categorical log-probability of the pinned reference class,
/// `log P(X=k-1) = 0 − A(θ) = -A(θ)`.
///
/// Iter-78 — companion to `closure_categorical_log_prob_slot`.
pub fn closure_categorical_log_prob_pinned(slot_indices: &[u32]) -> EmlClosureExpr {
    EmlClosureExpr::minus(
        closure_zero(),
        closure_categorical_log_partition(slot_indices),
    )
}

/// Build `exp(<arg>)` in closure form for an ARBITRARY closure
/// expression (not just a single slot).
///
/// Useful for composing exp on top of arbitrary sub-trees:
/// `closure_exp_of(closure_mul(neg_scale, distance_squared))` for
/// RBF kernels, `closure_exp_of(closure_softplus(theta))` for
/// double-exp transforms, etc.
///
/// Promoted to public in iter-99 (was a private helper in iter-83).
pub fn closure_exp_of(arg: EmlClosureExpr) -> EmlClosureExpr {
    EmlClosureExpr::eml(arg, EmlClosureExpr::one())
}

/// Horner-style polynomial evaluation:
/// `p(x) = a_0 + a_1·x + a_2·x² + … + a_n·x^n`
/// evaluated as `((a_n·x + a_{n-1})·x + … + a_1)·x + a_0`.
///
/// Both the variable `x` and the coefficients `a_i` are slot
/// inputs, so the same closure form evaluates against any
/// (x, coefficient) tuple at runtime.
///
/// Empty coefficient list returns the zero polynomial `0`.
///
/// Iter-118 — companion to [`closure_l2_penalty`] / [`closure_dot_product`]
/// for vector-of-slots aggregation in polynomial form.
pub fn closure_polynomial(x_slot: u32, coeff_slots: &[u32]) -> EmlClosureExpr {
    let mut iter = coeff_slots.iter().rev();
    let mut acc = match iter.next() {
        Some(&first) => EmlClosureExpr::slot(first),
        None => return closure_zero(),
    };
    for &c in iter {
        acc = EmlClosureExpr::plus(
            closure_mul(acc, EmlClosureExpr::slot(x_slot)),
            EmlClosureExpr::slot(c),
        );
    }
    acc
}

/// Cosine similarity `cos(x, y) = (x · y) / (||x|| · ||y||)`.
///
/// The Euclidean norms `||x||` and `||y||` are NOT EML-expressible
/// (square root isn't in the elementary closure), so the caller
/// supplies them as pre-computed slot inputs.
///
/// To get a self-contained closure-form similarity that doesn't
/// require external sqrt, use [`closure_squared_cosine_similarity`]
/// (returns cos²).
///
/// Iter-112 — staple of similarity-based retrieval (cosine LSH,
/// embedding retrieval, attention key-value matching when scaling
/// isn't a single 1/√d_k constant).
pub fn closure_cosine_similarity(
    x_slots: &[u32],
    y_slots: &[u32],
    x_norm_slot: u32,
    y_norm_slot: u32,
) -> EmlClosureExpr {
    let dot = closure_dot_product(x_slots, y_slots);
    let denom = closure_mul(
        EmlClosureExpr::slot(x_norm_slot),
        EmlClosureExpr::slot(y_norm_slot),
    );
    EmlClosureExpr::divide(dot, denom)
}

/// Squared cosine similarity `cos²(x, y) = (x · y)² / (||x||² · ||y||²)`.
///
/// Fully self-contained: no sqrt needed. Loses the sign of the
/// dot product but is sufficient for similarity-ranking tasks
/// where only magnitude matters. Equivalent to the cosine
/// similarity squared.
///
/// Iter-112 — pure-EML alternative to [`closure_cosine_similarity`].
pub fn closure_squared_cosine_similarity(
    x_slots: &[u32],
    y_slots: &[u32],
) -> EmlClosureExpr {
    let dot = closure_dot_product(x_slots, y_slots);
    let dot_squared = closure_mul(dot.clone(), dot);

    let xx = closure_dot_product(x_slots, x_slots);
    let yy = closure_dot_product(y_slots, y_slots);
    let denom = closure_mul(xx, yy);

    EmlClosureExpr::divide(dot_squared, denom)
}

/// Gaussian Radial Basis Function (RBF) kernel:
/// `k(x, y) = exp(-scale · ||x - y||²)`
///
/// where `scale = 1 / (2 · σ²)` is a slot input controlling the
/// kernel bandwidth. Setting `scale = 0.5` recovers the standard
/// `exp(-||x-y||² / 2)` (unit-σ) Gaussian kernel.
///
/// Properties: `k(x, x) = 1`; `k(x, y) ∈ (0, 1]`; symmetric;
/// approaches 0 as `||x - y|| → ∞`. Used in:
/// - SVMs / kernel methods (Schölkopf-Smola 2002).
/// - Gaussian process regression (Rasmussen-Williams 2006).
/// - Neural-tangent-kernel limits (Jacot-Gabriel-Hongler 2018).
///
/// Iter-99 — composes [`closure_squared_distance`] +
/// [`closure_exp_of`] + a negated scale slot.
pub fn closure_rbf_kernel(
    x_slots: &[u32],
    y_slots: &[u32],
    scale_slot: u32,
) -> EmlClosureExpr {
    let neg_scale = EmlClosureExpr::minus(
        closure_zero(),
        EmlClosureExpr::slot(scale_slot),
    );
    let neg_scaled_dist = closure_mul(
        neg_scale,
        closure_squared_distance(x_slots, y_slots),
    );
    closure_exp_of(neg_scaled_dist)
}

/// Scaled squared distance `scale · Σ_i (p_i - q_i)²`.
///
/// Composes [`closure_squared_distance`] (iter-98) with a slot
/// multiplier. Used for:
/// - KL between diagonal Gaussians (same variance): scale = σ²/2.
/// - Scaled MSE losses where the scaling factor varies per task.
/// - Per-example weighted distances.
///
/// Iter-128 — common composition pattern surfaced as a primitive.
pub fn closure_scaled_squared_distance(
    p_slots: &[u32],
    q_slots: &[u32],
    scale_slot: u32,
) -> EmlClosureExpr {
    closure_mul(
        EmlClosureExpr::slot(scale_slot),
        closure_squared_distance(p_slots, q_slots),
    )
}

/// Weighted MSE: `Σ_i w_i · (pred_i - target_i)² / n` where each
/// example carries its own weight.
///
/// Used in:
/// - Importance-weighted regression.
/// - Heteroscedastic regression (weight by inverse variance).
/// - Class-weighted training.
///
/// Iter-128 — `pred_slots`, `target_slots`, `weight_slots` must
/// have equal length; `n_slot` provides the count for normalization.
pub fn closure_weighted_mse_loss(
    pred_slots: &[u32],
    target_slots: &[u32],
    weight_slots: &[u32],
    n_slot: u32,
) -> EmlClosureExpr {
    assert_eq!(pred_slots.len(), target_slots.len());
    assert_eq!(pred_slots.len(), weight_slots.len());
    assert!(!pred_slots.is_empty());

    let mut terms = pred_slots.iter().zip(target_slots.iter()).zip(weight_slots.iter()).map(
        |((&p, &t), &w)| {
            closure_mul(EmlClosureExpr::slot(w), closure_squared_error(p, t))
        },
    );
    let first = terms.next().unwrap();
    let sum = terms.fold(first, |acc, term| EmlClosureExpr::plus(acc, term));

    EmlClosureExpr::divide(sum, EmlClosureExpr::slot(n_slot))
}

/// Sum of slot values `Σ_i Slot(i)`.
///
/// Plus-chain across all given slots. Empty input returns the zero
/// expression.
///
/// Iter-133 — aggregate primitive.
pub fn closure_sum_slots(slot_indices: &[u32]) -> EmlClosureExpr {
    if slot_indices.is_empty() {
        return closure_zero();
    }
    let mut iter = slot_indices.iter().map(|&i| EmlClosureExpr::slot(i));
    let first = iter.next().unwrap();
    iter.fold(first, |acc, term| EmlClosureExpr::plus(acc, term))
}

/// Product of slot values `Π_i Slot(i)`.
///
/// Mul-chain across all given slots. Empty input returns
/// [`EmlClosureExpr::One`] (the multiplicative identity).
///
/// Iter-133 — aggregate primitive.
pub fn closure_product_slots(slot_indices: &[u32]) -> EmlClosureExpr {
    if slot_indices.is_empty() {
        return EmlClosureExpr::one();
    }
    let mut iter = slot_indices.iter().map(|&i| EmlClosureExpr::slot(i));
    let first = iter.next().unwrap();
    iter.fold(first, |acc, term| closure_mul(acc, term))
}

/// Arithmetic mean of slot values: `(1/n) · Σ_i Slot(i)`.
///
/// `n_slot` provides the count `n` at evaluation time. Caller must
/// ensure `n` matches `slot_indices.len()` for the standard
/// arithmetic mean; alternatively `n_slot` can hold any divisor for
/// generalized weighted aggregation.
///
/// Iter-133 — companion to closure_sum_slots / closure_product_slots.
pub fn closure_arithmetic_mean(slot_indices: &[u32], n_slot: u32) -> EmlClosureExpr {
    EmlClosureExpr::divide(closure_sum_slots(slot_indices), EmlClosureExpr::slot(n_slot))
}

/// Squared L2 norm `||x||² = Σ_i x_i²`.
///
/// Alias for [`closure_l2_penalty`] with a clearer name when used
/// in a norm context (as opposed to regularization context).
///
/// Iter-124 — vector-norm primitive.
pub fn closure_l2_norm_squared(slot_indices: &[u32]) -> EmlClosureExpr {
    closure_l2_penalty(slot_indices)
}

/// Linear form `y = Σ_i w_i · x_i + b` — a single-neuron output.
///
/// Composes [`closure_dot_product`] + [`EmlClosureExpr::plus`].
/// The classical perceptron's pre-activation; combine with any
/// closure-form activation (sigmoid, swish, mish, etc.) to get a
/// full neuron.
///
/// Iter-124 — primitive for single-neuron / linear-regression
/// closure-form composition.
pub fn closure_linear_form(
    x_slots: &[u32],
    weight_slots: &[u32],
    bias_slot: u32,
) -> EmlClosureExpr {
    let dot = closure_dot_product(weight_slots, x_slots);
    EmlClosureExpr::plus(dot, EmlClosureExpr::slot(bias_slot))
}

/// Squared error `(pred - target)²` for a scalar prediction and
/// target. Used as the per-example MSE building block.
///
/// Iter-106 — scalar MSE primitive; vectorize via Plus chain.
pub fn closure_squared_error(pred_slot: u32, target_slot: u32) -> EmlClosureExpr {
    let diff = EmlClosureExpr::minus(
        EmlClosureExpr::slot(pred_slot),
        EmlClosureExpr::slot(target_slot),
    );
    closure_mul(diff.clone(), diff)
}

/// Mean squared error over a batch of (prediction, target) pairs:
/// `MSE = (1/n) · Σ_i (pred_i - target_i)²`.
///
/// Caller provides `n_slot` holding the count `n` at evaluation
/// time (to avoid hard-coding a constant in the closure form).
///
/// Iter-106 — composes squared_error + division by count. The
/// canonical regression loss.
pub fn closure_mse_loss(
    pred_slots: &[u32],
    target_slots: &[u32],
    n_slot: u32,
) -> EmlClosureExpr {
    assert_eq!(
        pred_slots.len(),
        target_slots.len(),
        "MSE requires equal-length pred and target slot vectors",
    );
    assert!(!pred_slots.is_empty(), "MSE requires ≥ 1 example");

    let mut terms = pred_slots.iter().zip(target_slots.iter()).map(|(&p, &t)| {
        closure_squared_error(p, t)
    });
    let first = terms.next().unwrap();
    let sum = terms.fold(first, |acc, term| EmlClosureExpr::plus(acc, term));

    EmlClosureExpr::divide(sum, EmlClosureExpr::slot(n_slot))
}

/// L2 regularization penalty `Σ_i w_i²` over a slot vector.
///
/// Standard "weight decay" / Tikhonov regularizer. Scale by
/// regularization strength λ at the caller's site (closure_mul
/// against a λ slot if needed).
///
/// Iter-106 — composes squared_error pattern with self-comparison
/// (subtracting zero implicitly via Mul(slot, slot)).
pub fn closure_l2_penalty(slot_indices: &[u32]) -> EmlClosureExpr {
    assert!(!slot_indices.is_empty(), "L2 penalty requires ≥ 1 weight slot");

    let mut terms = slot_indices.iter().map(|&i| {
        closure_mul(EmlClosureExpr::slot(i), EmlClosureExpr::slot(i))
    });
    let first = terms.next().unwrap();
    terms.fold(first, |acc, term| EmlClosureExpr::plus(acc, term))
}

/// Vector dot product `Σ_i x_i · y_i` over equal-length slot vectors.
///
/// Encoded as a `Plus` chain of `Mul(Slot(x_i), Slot(y_i))` terms.
///
/// Panics if `left_slots` and `right_slots` have different lengths
/// or are both empty.
///
/// Iter-98 — multi-slot vector primitive. Building block for
/// attention scores, kernel evaluations, and inner-product
/// quadratic forms.
pub fn closure_dot_product(left_slots: &[u32], right_slots: &[u32]) -> EmlClosureExpr {
    assert_eq!(
        left_slots.len(),
        right_slots.len(),
        "dot_product requires equal-length slot vectors",
    );
    assert!(!left_slots.is_empty(), "dot_product requires ≥ 1 dim");

    let mut terms = left_slots.iter().zip(right_slots.iter()).map(|(&l, &r)| {
        closure_mul(EmlClosureExpr::slot(l), EmlClosureExpr::slot(r))
    });
    let first = terms.next().unwrap();
    terms.fold(first, |acc, term| EmlClosureExpr::plus(acc, term))
}

/// Squared Euclidean distance `Σ_i (x_i - y_i)²` between two
/// slot vectors of equal length.
///
/// Iter-98 — pairs with [`closure_dot_product`] for kernel /
/// distance-based attention variants (e.g. RBF kernels).
pub fn closure_squared_distance(left_slots: &[u32], right_slots: &[u32]) -> EmlClosureExpr {
    assert_eq!(
        left_slots.len(),
        right_slots.len(),
        "squared_distance requires equal-length slot vectors",
    );
    assert!(!left_slots.is_empty(), "squared_distance requires ≥ 1 dim");

    let mut terms = left_slots.iter().zip(right_slots.iter()).map(|(&l, &r)| {
        let diff = EmlClosureExpr::minus(
            EmlClosureExpr::slot(l),
            EmlClosureExpr::slot(r),
        );
        closure_mul(diff.clone(), diff)
    });
    let first = terms.next().unwrap();
    terms.fold(first, |acc, term| EmlClosureExpr::plus(acc, term))
}

/// Scaled-dot-product attention score `(q · k) / sqrt(d_k)`.
///
/// `q_slots` and `k_slots` must have equal length (the
/// dimensionality `d_k` of the key/query space). `inv_sqrt_d_slot`
/// holds `1 / √d_k` — the caller pre-computes this constant.
///
/// Returns the unnormalized score; standard transformer attention
/// then softmaxes a row of these scores over the key positions.
///
/// Iter-98 — Vaswani et al. 2017 §3.2.1 ("Scaled Dot-Product
/// Attention"). Combined with [`closure_softmax_temperature_slot`]
/// or [`closure_categorical_softmax_slot`], this expresses a full
/// attention head's score computation in EML closure form.
pub fn closure_attention_score(
    q_slots: &[u32],
    k_slots: &[u32],
    inv_sqrt_d_slot: u32,
) -> EmlClosureExpr {
    closure_mul(
        closure_dot_product(q_slots, k_slots),
        EmlClosureExpr::slot(inv_sqrt_d_slot),
    )
}

/// Residual / skip connection: `y = x + r`.
///
/// Encoded as `Plus(Slot(x), Slot(r))`. Trivial structurally,
/// but named as a primitive to document the residual-connection
/// pattern in transformer / ResNet blocks.
///
/// Iter-88 — LayerNorm decomposition helper #1.
pub fn closure_residual_add(x_slot: u32, residual_slot: u32) -> EmlClosureExpr {
    EmlClosureExpr::plus(
        EmlClosureExpr::slot(x_slot),
        EmlClosureExpr::slot(residual_slot),
    )
}

/// Centering: `y = x − μ`.
///
/// First half of LayerNorm / BatchNorm: subtract the mean before
/// dividing by the standard deviation. Caller supplies the
/// pre-computed mean `μ` as a slot.
///
/// Iter-88 — LayerNorm decomposition helper #2.
pub fn closure_center(x_slot: u32, mean_slot: u32) -> EmlClosureExpr {
    EmlClosureExpr::minus(
        EmlClosureExpr::slot(x_slot),
        EmlClosureExpr::slot(mean_slot),
    )
}

/// Standardization: `y = (x − μ) / σ`.
///
/// Standard z-score: subtract mean, divide by standard deviation.
/// Composes [`closure_center`] with [`EmlClosureExpr::divide`].
/// Caller supplies pre-computed `μ` and `σ` as slots; `σ` must
/// be > 0.
///
/// Iter-88 — LayerNorm decomposition helper #3.
pub fn closure_standardize(
    x_slot: u32,
    mean_slot: u32,
    sigma_slot: u32,
) -> EmlClosureExpr {
    EmlClosureExpr::divide(
        closure_center(x_slot, mean_slot),
        EmlClosureExpr::slot(sigma_slot),
    )
}

/// Affine transform: `y = γ · x + β` (learned LayerNorm scale + shift).
///
/// Standard "rescale and re-bias" applied AFTER standardization
/// in LayerNorm. `γ` and `β` are typically learned parameters
/// supplied as slots.
///
/// Iter-88 — LayerNorm decomposition helper #4.
pub fn closure_affine(x_slot: u32, gain_slot: u32, bias_slot: u32) -> EmlClosureExpr {
    EmlClosureExpr::plus(
        closure_mul(
            EmlClosureExpr::slot(gain_slot),
            EmlClosureExpr::slot(x_slot),
        ),
        EmlClosureExpr::slot(bias_slot),
    )
}

/// Full LayerNorm: `y = γ · (x − μ) / σ + β`.
///
/// Composes [`closure_standardize`] with [`closure_affine`]. All
/// statistics (`μ`, `σ`) and learned parameters (`γ`, `β`) enter
/// as slots; the caller is responsible for computing `μ` and `σ`
/// over the appropriate axis at evaluation time.
///
/// Iter-88 — top-level LayerNorm helper. Composes 4 primitives:
/// Slot · Minus · Divide · Mul · Plus.
pub fn closure_layer_norm(
    x_slot: u32,
    mean_slot: u32,
    sigma_slot: u32,
    gain_slot: u32,
    bias_slot: u32,
) -> EmlClosureExpr {
    let standardized = closure_standardize(x_slot, mean_slot, sigma_slot);
    EmlClosureExpr::plus(
        closure_mul(EmlClosureExpr::slot(gain_slot), standardized),
        EmlClosureExpr::slot(bias_slot),
    )
}

/// Logit (inverse sigmoid): `logit(p) = log(p / (1-p))`.
///
/// Maps a probability `p ∈ (0, 1)` to its natural-parameter coordinate
/// in the Bernoulli family. Caller is responsible for keeping `p`
/// strictly in (0, 1); `p = 0` or `p = 1` produces `±∞`.
///
/// Encoding: `Minus(closure_ln(Slot(p)), closure_ln(Minus(One, Slot(p))))`.
///
/// Iter-86 — inverse of [`closure_sigmoid`]; pairs with logit to
/// move between probability and natural-param spaces.
pub fn closure_logit(p_slot: u32) -> EmlClosureExpr {
    let ln_p = closure_ln(EmlClosureExpr::slot(p_slot));
    let one_minus_p = EmlClosureExpr::minus(
        EmlClosureExpr::one(),
        EmlClosureExpr::slot(p_slot),
    );
    let ln_one_minus_p = closure_ln(one_minus_p);
    EmlClosureExpr::minus(ln_p, ln_one_minus_p)
}

/// Temperature-scaled Categorical softmax probability for a
/// non-pinned slot:
///
/// `softmax_T(i; θ) = exp(θ_i / T) / Σ_j exp(θ_j / T)`
///
/// where `T` is a temperature slot (T > 0). High T → uniform
/// distribution; T → 0 → argmax distribution. Standard in
/// knowledge distillation (Hinton et al. 2015) and softmax
/// annealing.
///
/// This helper takes `inv_temp_slot` (β = 1/T) rather than T itself
/// to avoid Divide-by-T at every exponent; the caller provides β
/// at evaluation. β = 1 recovers `closure_categorical_softmax_slot`.
///
/// Iter-86 — generalizes Categorical softmax with explicit
/// temperature/sharpness parameter.
pub fn closure_softmax_temperature_slot(
    target_slot: u32,
    slot_indices: &[u32],
    inv_temp_slot: u32,
) -> EmlClosureExpr {
    let beta = EmlClosureExpr::slot(inv_temp_slot);

    let exp_beta_target = EmlClosureExpr::eml(
        closure_mul(beta.clone(), EmlClosureExpr::slot(target_slot)),
        EmlClosureExpr::one(),
    );

    // Denominator: exp(β·0) + Σ exp(β·θ_i) = 1 + Σ exp(β·θ_i).
    let mut denom = EmlClosureExpr::one();
    for &idx in slot_indices {
        let exp_term = EmlClosureExpr::eml(
            closure_mul(beta.clone(), EmlClosureExpr::slot(idx)),
            EmlClosureExpr::one(),
        );
        denom = EmlClosureExpr::plus(denom, exp_term);
    }

    EmlClosureExpr::divide(exp_beta_target, denom)
}

/// Temperature-scaled Categorical softmax for the pinned reference
/// class: `1 / Σ_j exp(β · θ_j)` (note the pinned class contributes
/// `exp(β · 0) = 1` to the denominator).
///
/// Iter-86 — companion to `closure_softmax_temperature_slot`.
pub fn closure_softmax_temperature_pinned(
    slot_indices: &[u32],
    inv_temp_slot: u32,
) -> EmlClosureExpr {
    let beta = EmlClosureExpr::slot(inv_temp_slot);

    let mut denom = EmlClosureExpr::one();
    for &idx in slot_indices {
        let exp_term = EmlClosureExpr::eml(
            closure_mul(beta.clone(), EmlClosureExpr::slot(idx)),
            EmlClosureExpr::one(),
        );
        denom = EmlClosureExpr::plus(denom, exp_term);
    }

    EmlClosureExpr::divide(EmlClosureExpr::one(), denom)
}

/// Smooth maximum (a.k.a. softmax-with-temperature on raw inputs)
/// `SmoothMax(x; β) = (1/β) · log Σ_i exp(β · x_i)`.
///
/// Converges to `max(x)` as `β → ∞`, and to the arithmetic mean
/// as `β → 0⁺` (limit). At `β = 1`, equals `closure_lse(exp(x_i))`.
///
/// Used as a differentiable / smooth approximation to `max` in
/// continuous optimization, attention temperature controls, and
/// tropical-IR ↔ EML composition.
///
/// Iter-84 — temperature-controlled aggregation primitive.
/// Caller must supply `β > 0` at evaluation; β = 0 produces a
/// 0/0 NaN.
pub fn closure_smooth_max(slot_indices: &[u32], beta_slot: u32) -> EmlClosureExpr {
    assert!(!slot_indices.is_empty(), "SmoothMax requires ≥ 1 input slot");
    let beta = EmlClosureExpr::slot(beta_slot);

    let scaled_exps: Vec<EmlClosureExpr> = slot_indices
        .iter()
        .map(|&idx| {
            let beta_x = closure_mul(beta.clone(), EmlClosureExpr::slot(idx));
            EmlClosureExpr::eml(beta_x, EmlClosureExpr::one())
        })
        .collect();

    let log_sum = closure_lse(scaled_exps);
    EmlClosureExpr::divide(log_sum, beta)
}

/// Smooth minimum `SmoothMin(x; β) = -(1/β) · log Σ_i exp(-β · x_i)`.
///
/// Identity: `SmoothMin(x; β) = -SmoothMax(-x; β)`.
///
/// Converges to `min(x)` as `β → ∞`. Useful for tropical-IR's
/// `(min, +)` semiring counterpart to SmoothMax.
///
/// Iter-84 — companion to SmoothMax via the negation duality.
pub fn closure_smooth_min(slot_indices: &[u32], beta_slot: u32) -> EmlClosureExpr {
    assert!(!slot_indices.is_empty(), "SmoothMin requires ≥ 1 input slot");
    let beta = EmlClosureExpr::slot(beta_slot);

    // Build the inner LSE over -β · x_i (note the sign).
    let neg_beta = EmlClosureExpr::minus(closure_zero(), beta.clone());
    let scaled_exps: Vec<EmlClosureExpr> = slot_indices
        .iter()
        .map(|&idx| {
            let neg_beta_x = closure_mul(neg_beta.clone(), EmlClosureExpr::slot(idx));
            EmlClosureExpr::eml(neg_beta_x, EmlClosureExpr::one())
        })
        .collect();

    let log_sum = closure_lse(scaled_exps);
    // -(1/β) · log_sum = -log_sum / β.
    let neg_log_sum = EmlClosureExpr::minus(closure_zero(), log_sum);
    EmlClosureExpr::divide(neg_log_sum, beta)
}

/// Scaled sigmoid `σ_β(x) = 1 / (1 + exp(-β · x))`.
///
/// Equivalent to `closure_sigmoid` but with β as a slot input so
/// callers can implement temperature-sharpened or temperature-relaxed
/// sigmoids without rewriting the closure form.
///
/// `β = 1` recovers the standard sigmoid; `β → ∞` approaches the
/// step function; `β → 0⁺` approaches the constant 0.5.
///
/// Iter-83 — temperature-controlled sigmoid; building block for
/// β-Swish and the sigmoid GELU approximation.
pub fn closure_sigmoid_scaled(x_slot: u32, beta_slot: u32) -> EmlClosureExpr {
    let neg_beta = EmlClosureExpr::minus(
        closure_zero(),
        EmlClosureExpr::slot(beta_slot),
    );
    let neg_beta_x = closure_mul(neg_beta, EmlClosureExpr::slot(x_slot));
    let exp_neg = closure_exp_of(neg_beta_x);
    EmlClosureExpr::divide(
        EmlClosureExpr::one(),
        EmlClosureExpr::plus(EmlClosureExpr::one(), exp_neg),
    )
}

/// β-Swish (also called E-Swish): `swish_β(x) = x · σ(β · x)`.
///
/// Generalizes [`closure_swish`] with a learnable / configurable
/// gating sharpness. The original Swish paper found β = 1 optimal
/// in most experiments; later work (e.g. Mish, EfficientNet's
/// β-Swish variants) varies β per layer or makes it trainable.
///
/// Iter-83 — extends the swish family.
pub fn closure_swish_scaled(x_slot: u32, beta_slot: u32) -> EmlClosureExpr {
    closure_mul(
        EmlClosureExpr::slot(x_slot),
        closure_sigmoid_scaled(x_slot, beta_slot),
    )
}

/// Sigmoid GELU approximation: `GELU(x) ≈ x · σ(c · x)`
/// where the canonical scale constant is `c ≈ 1.702` (Hendrycks
/// & Gimpel 2016, "Bridging Nonlinearities and Stochastic
/// Regularizers with Gaussian Error Linear Units").
///
/// `c` is passed as a slot to keep the closure form independent
/// of compile-time constants. Caller supplies 1.702 at evaluation.
///
/// Iter-83 — sigmoid GELU; structurally identical to β-Swish but
/// distinguished by its semantic role (smooth-ReLU approximation
/// to true GELU = x · Φ(x), which involves erf and is NOT
/// EML-expressible).
pub fn closure_gelu_sigmoid_approx(x_slot: u32, c_slot: u32) -> EmlClosureExpr {
    closure_swish_scaled(x_slot, c_slot)
}

/// Shannon entropy of a Bernoulli distribution parameterized by
/// natural parameter θ:
///
/// `H(P_θ) = -p·log p - (1-p)·log(1-p)`  where `p = σ(θ)`.
///
/// Via Fenchel duality between entropy and the log-partition,
/// this simplifies to:
///
/// `H(P_θ) = A(θ) − θ·∇A(θ) = softplus(θ) − θ·σ(θ)`.
///
/// Iter-82 — entropy primitive; pairs with cross-entropy (iter-79)
/// to enable KL = CE − H.
pub fn closure_entropy_bernoulli(theta_slot: u32) -> EmlClosureExpr {
    EmlClosureExpr::minus(
        closure_softplus(theta_slot),
        closure_mul(
            EmlClosureExpr::slot(theta_slot),
            closure_sigmoid(theta_slot),
        ),
    )
}

/// Shannon entropy of a Categorical distribution parameterized by
/// natural parameters θ ∈ ℝ^{k-1}:
///
/// `H(P_θ) = -Σ_i p_i log p_i`  where `p = softmax([0, θ])`.
///
/// Via Fenchel duality:
///
/// `H(P_θ) = A(θ) − ⟨∇A(θ), θ⟩ = A(θ) − Σ_i softmax_slot_i(θ) · θ_i`
///
/// (The pinned class contributes 0 to the inner product since
///  its natural parameter is pinned to 0.)
///
/// Iter-82 — extends entropy wiring to Categorical for cross-entropy
/// and information-theoretic loss decomposition.
pub fn closure_entropy_categorical(slot_indices: &[u32]) -> EmlClosureExpr {
    let a = closure_categorical_log_partition(slot_indices);

    let mut terms = slot_indices.iter().map(|&slot| {
        closure_mul(
            closure_categorical_softmax_slot(slot, slot_indices),
            EmlClosureExpr::slot(slot),
        )
    });
    let first = terms
        .next()
        .expect("entropy needs at least one slot (k ≥ 2)");
    let inner = terms.fold(first, |acc, term| EmlClosureExpr::plus(acc, term));

    EmlClosureExpr::minus(a, inner)
}

/// Gated Linear Unit `GLU(x, g) = x · σ(g)`.
///
/// Two-slot multiplicative gating. Dauphin et al. 2017 — the
/// original GLU formulation, now standard in transformer FFN
/// blocks (e.g. T5 / PaLM / LLaMA variants).
///
/// Iter-81 — gated activation primitive.
pub fn closure_glu(x_slot: u32, gate_slot: u32) -> EmlClosureExpr {
    closure_mul(EmlClosureExpr::slot(x_slot), closure_sigmoid(gate_slot))
}

/// SwiGLU activation `SwiGLU(x, g) = x · swish(g) = x · g · σ(g)`.
///
/// Shazeer 2020 ("GLU Variants Improve Transformer"). The default
/// gated FFN in PaLM, LLaMA, T5.1.1, Gemma.
///
/// Iter-81 — gated swish; composes [`closure_swish`] with [`closure_mul`].
pub fn closure_swiglu(x_slot: u32, gate_slot: u32) -> EmlClosureExpr {
    closure_mul(EmlClosureExpr::slot(x_slot), closure_swish(gate_slot))
}

/// ReGLU activation `ReGLU(x, g) = x · softplus(g)`.
///
/// Smooth-ReLU-gated variant from Shazeer 2020. True ReLU is not
/// expressible in EML (piecewise linear, non-smooth); softplus
/// is the canonical smooth approximation: `softplus(g) ≈ max(0, g)`
/// for |g| ≫ 0.
///
/// Iter-81 — gated softplus.
pub fn closure_reglu(x_slot: u32, gate_slot: u32) -> EmlClosureExpr {
    closure_mul(EmlClosureExpr::slot(x_slot), closure_softplus(gate_slot))
}

/// Swish activation `swish(x) = x · σ(x)`.
///
/// Encoded as `Mul(Slot(x), closure_sigmoid(x))`.
///
/// Note: also called SiLU (Sigmoid Linear Unit). The Swish/SiLU
/// names are interchangeable; we expose both for ergonomics.
///
/// Iter-80 — modern transformer activation. Used in many
/// post-2019 architectures (e.g. GLU variants in T5 MLP blocks).
pub fn closure_swish(theta_slot: u32) -> EmlClosureExpr {
    closure_mul(EmlClosureExpr::slot(theta_slot), closure_sigmoid(theta_slot))
}

/// SiLU activation — alias for [`closure_swish`].
///
/// `SiLU(x) = x · σ(x) ≡ swish(x)`.
pub fn closure_silu(theta_slot: u32) -> EmlClosureExpr {
    closure_swish(theta_slot)
}

/// Mish activation `mish(x) = x · tanh(softplus(x))`.
///
/// Encoded by composing closure_mul + closure_tanh evaluated on a
/// softplus-shifted slot. Since closure_tanh takes a SLOT (not an
/// arbitrary expression), we cannot directly nest softplus inside
/// it; instead we manually build the tanh-of-softplus formula:
///
/// `tanh(s) = (exp(s) − exp(-s)) / (exp(s) + exp(-s))`
///
/// with `s = softplus(x) = log(1 + exp(x))`. Then `exp(s) = 1 + exp(x)`
/// and `exp(-s) = 1 / (1 + exp(x))`. So:
///
/// `tanh(softplus(x)) = ((1 + exp(x))² − 1) / ((1 + exp(x))² + 1)`
///
/// Final form: `mish(x) = x · ((1+e^x)² − 1) / ((1+e^x)² + 1)`.
///
/// Iter-80 — transformer activation; outperforms swish on some
/// vision tasks (Misra 2019).
pub fn closure_mish(theta_slot: u32) -> EmlClosureExpr {
    // u = 1 + exp(x).
    let exp_x = closure_exp(theta_slot);
    let u = EmlClosureExpr::plus(EmlClosureExpr::one(), exp_x);
    let u_squared = closure_mul(u.clone(), u);
    let numer = EmlClosureExpr::minus(u_squared.clone(), EmlClosureExpr::one());
    let denom = EmlClosureExpr::plus(u_squared, EmlClosureExpr::one());
    let tanh_softplus = EmlClosureExpr::divide(numer, denom);
    closure_mul(EmlClosureExpr::slot(theta_slot), tanh_softplus)
}

/// Smooth-ReLU alias for [`closure_softplus`], named for clarity
/// when used as an activation rather than as a log-partition.
///
/// `softplus(x) = log(1 + exp(x))` is a smooth approximation to
/// `relu(x) = max(0, x)`.
pub fn closure_smooth_relu(theta_slot: u32) -> EmlClosureExpr {
    closure_softplus(theta_slot)
}

/// Bernoulli cross-entropy loss
/// `CE(y, θ) = -y · log σ(θ) - (1-y) · log(1-σ(θ))`
///         `= y · softplus(-θ) + (1-y) · softplus(θ)`
/// for a soft target `y ∈ [0, 1]` and a natural-parameter prediction `θ`.
///
/// Used as the canonical loss function for binary logistic
/// regression / Bernoulli classification.
///
/// Iter-79 — loss-function primitive in EML closure form,
/// composing softplus + Slot + Mul + Plus.
pub fn closure_cross_entropy_bernoulli(target_slot: u32, theta_slot: u32) -> EmlClosureExpr {
    let target = EmlClosureExpr::slot(target_slot);
    let one_minus_target = EmlClosureExpr::minus(
        EmlClosureExpr::one(),
        EmlClosureExpr::slot(target_slot),
    );

    // softplus(-θ) — uses the negated slot.
    let exp_neg_theta = EmlClosureExpr::eml(
        closure_neg_slot(theta_slot),
        EmlClosureExpr::one(),
    );
    let softplus_neg = closure_ln(EmlClosureExpr::plus(
        EmlClosureExpr::one(),
        exp_neg_theta,
    ));

    let softplus_pos = closure_softplus(theta_slot);

    EmlClosureExpr::plus(
        closure_mul(target, softplus_neg),
        closure_mul(one_minus_target, softplus_pos),
    )
}

/// Negative log-likelihood for a Categorical observation of a
/// specific non-pinned class slot:
/// `NLL(target, θ) = -log P(X=target) = A(θ) - θ_target`.
///
/// Iter-79 — companion to `closure_cross_entropy_bernoulli`. For
/// soft / one-hot Categorical targets, the user composes
/// `Σ y_i · -log P_i` with closure_mul.
pub fn closure_neg_log_likelihood_categorical_slot(
    target_slot: u32,
    slot_indices: &[u32],
) -> EmlClosureExpr {
    EmlClosureExpr::minus(
        closure_categorical_log_partition(slot_indices),
        EmlClosureExpr::slot(target_slot),
    )
}

/// Negative log-likelihood for a Categorical observation of the
/// pinned reference class:
/// `NLL(pinned, θ) = -log P(X=k-1) = A(θ)`.
///
/// Iter-79 — used together with `closure_neg_log_likelihood_categorical_slot`
/// to cover the full simplex.
pub fn closure_neg_log_likelihood_categorical_pinned(
    slot_indices: &[u32],
) -> EmlClosureExpr {
    closure_categorical_log_partition(slot_indices)
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

    // ── Log-probability helpers (iter-78) ─────────────────────────

    #[test]
    fn closure_bernoulli_log_prob_one_matches_log_sigmoid() {
        // log P(X=1) = log σ(θ). Compare to log of closure_sigmoid.
        for theta in [-3.0_f64, -0.5, 0.0, 0.7, 3.0] {
            let lp = eval_with_slots(
                closure_bernoulli_log_prob_one(0),
                vec![theta],
            );
            let sig = eval_with_slots(closure_sigmoid(0), vec![theta]);
            let expected = sig.ln();
            assert!(
                (lp - expected).abs() < 1e-12,
                "log P(X=1; θ={}) = {}; log σ = {}", theta, lp, expected
            );
        }
    }

    #[test]
    fn closure_bernoulli_log_prob_zero_matches_log_one_minus_sigmoid() {
        // log P(X=0) = log(1 − σ(θ)).
        for theta in [-3.0_f64, -0.5, 0.0, 0.7, 3.0] {
            let lp = eval_with_slots(
                closure_bernoulli_log_prob_zero(0),
                vec![theta],
            );
            let sig = eval_with_slots(closure_sigmoid(0), vec![theta]);
            let expected = (1.0 - sig).ln();
            assert!(
                (lp - expected).abs() < 1e-12,
                "log P(X=0; θ={}) = {}; log(1-σ) = {}", theta, lp, expected
            );
        }
    }

    #[test]
    fn closure_bernoulli_log_probs_exp_sum_to_one() {
        // exp(log P(X=1)) + exp(log P(X=0)) = 1.
        for theta in [-2.0_f64, -0.5, 0.0, 1.0, 4.0] {
            let lp1 = eval_with_slots(closure_bernoulli_log_prob_one(0), vec![theta]);
            let lp0 = eval_with_slots(closure_bernoulli_log_prob_zero(0), vec![theta]);
            let s = lp1.exp() + lp0.exp();
            assert!((s - 1.0).abs() < 1e-12, "sum = {} at θ={}", s, theta);
        }
    }

    #[test]
    fn closure_categorical_log_prob_slot_matches_log_softmax() {
        // log P(X=i) should equal log of softmax_slot(i, slots).
        let slots = [0_u32, 1];
        let theta_cases = [
            vec![0.0_f64, 0.0],
            vec![1.0, -1.0],
            vec![-0.5, 0.5],
            vec![2.0, 1.0],
        ];
        for theta in &theta_cases {
            for (i, &slot) in slots.iter().enumerate() {
                let lp = eval_with_slots(
                    closure_categorical_log_prob_slot(slot, &slots),
                    theta.clone(),
                );
                let prob = eval_with_slots(
                    closure_categorical_softmax_slot(slot, &slots),
                    theta.clone(),
                );
                assert!(
                    (lp - prob.ln()).abs() < 1e-10,
                    "slot {} at {:?}: log P = {}, log softmax = {}",
                    i, theta, lp, prob.ln()
                );
            }
        }
    }

    #[test]
    fn closure_categorical_log_prob_pinned_matches_log_softmax_pinned() {
        let slots = [0_u32, 1];
        for theta in [
            vec![0.0_f64, 0.0],
            vec![1.0, -1.0],
            vec![-0.5, 0.5],
        ] {
            let lp = eval_with_slots(
                closure_categorical_log_prob_pinned(&slots),
                theta.clone(),
            );
            let prob = eval_with_slots(
                closure_categorical_softmax_pinned(&slots),
                theta.clone(),
            );
            assert!(
                (lp - prob.ln()).abs() < 1e-10,
                "pinned at {:?}: log P = {}, log softmax = {}",
                theta, lp, prob.ln()
            );
        }
    }

    #[test]
    fn closure_categorical_log_probs_exp_sum_to_one() {
        // For k=3, exp(log P_0) + exp(log P_1) + exp(log P_pinned) = 1.
        let slots = [0_u32, 1];
        for theta in [
            vec![0.0_f64, 0.0],
            vec![1.0, -1.0],
            vec![-2.0, 3.0],
            vec![0.5, 0.5],
        ] {
            let lp0 = eval_with_slots(
                closure_categorical_log_prob_slot(0, &slots),
                theta.clone(),
            );
            let lp1 = eval_with_slots(
                closure_categorical_log_prob_slot(1, &slots),
                theta.clone(),
            );
            let lpp = eval_with_slots(
                closure_categorical_log_prob_pinned(&slots),
                theta.clone(),
            );
            let s = lp0.exp() + lp1.exp() + lpp.exp();
            assert!((s - 1.0).abs() < 1e-12, "sum = {} at {:?}", s, theta);
        }
    }

    #[test]
    fn closure_categorical_log_prob_k2_matches_bernoulli_log_prob() {
        // For k=2, closure_categorical_log_prob_slot(0, [0]) === log σ(θ_0).
        for theta in [-2.0_f64, -0.5, 0.0, 0.7, 3.0] {
            let cat = eval_with_slots(
                closure_categorical_log_prob_slot(0, &[0]),
                vec![theta],
            );
            let bern = eval_with_slots(
                closure_bernoulli_log_prob_one(0),
                vec![theta],
            );
            assert!(
                (cat - bern).abs() < 1e-12,
                "k=2 log P(slot=0; θ={}) = {}; bern log σ = {}", theta, cat, bern
            );
        }
    }

    // ── closure_polynomial (iter-118) ─────────────────────────────

    #[test]
    fn closure_polynomial_empty_is_zero() {
        let v = eval_with_slots(closure_polynomial(0, &[]), vec![5.0]);
        assert_eq!(v, 0.0);
    }

    #[test]
    fn closure_polynomial_constant_returns_coefficient() {
        // p(x) = a_0 = slot[1].
        for c in [3.5_f64, -2.0, 0.0, 100.0] {
            let v = eval_with_slots(closure_polynomial(0, &[1]), vec![999.0, c]);
            assert_eq!(v, c);
        }
    }

    #[test]
    fn closure_polynomial_linear_at_zero_returns_a0() {
        // p(0) = a_0 regardless of higher coefficients.
        let slots = vec![0.0, 5.0, 7.0]; // x=0, a_0=5, a_1=7
        let v = eval_with_slots(closure_polynomial(0, &[1, 2]), slots);
        assert_eq!(v, 5.0);
    }

    #[test]
    fn closure_polynomial_linear_at_one_sums_coefficients() {
        // p(1) = Σ a_i.
        let slots = vec![1.0, 3.0, 4.0, 5.0]; // x=1, a_0=3, a_1=4, a_2=5
        let v = eval_with_slots(closure_polynomial(0, &[1, 2, 3]), slots);
        assert_eq!(v, 12.0);
    }

    #[test]
    fn closure_polynomial_quadratic_matches_direct() {
        // p(x) = 1 + 2x + 3x² at x = 4:
        // = 1 + 8 + 48 = 57.
        let slots = vec![4.0, 1.0, 2.0, 3.0];
        let v = eval_with_slots(closure_polynomial(0, &[1, 2, 3]), slots);
        assert_eq!(v, 57.0);
    }

    #[test]
    fn closure_polynomial_cubic_matches_direct() {
        // p(x) = 1 + 2x + 3x² + x³ at x = 2:
        // = 1 + 4 + 12 + 8 = 25.
        let slots = vec![2.0, 1.0, 2.0, 3.0, 1.0];
        let v = eval_with_slots(closure_polynomial(0, &[1, 2, 3, 4]), slots);
        assert_eq!(v, 25.0);
    }

    // ── Cosine similarity (iter-112) ──────────────────────────────

    #[test]
    fn closure_cosine_similarity_aligned_vectors_is_one() {
        // x = y = (1, 0): cos = 1 / (1·1) = 1.
        let v = eval_with_slots(
            closure_cosine_similarity(&[0, 1], &[2, 3], 4, 5),
            vec![1.0, 0.0, 1.0, 0.0, 1.0, 1.0],
        );
        assert!((v - 1.0).abs() < 1e-12);
    }

    #[test]
    fn closure_cosine_similarity_orthogonal_is_zero() {
        let v = eval_with_slots(
            closure_cosine_similarity(&[0, 1], &[2, 3], 4, 5),
            vec![1.0, 0.0, 0.0, 1.0, 1.0, 1.0],
        );
        assert_eq!(v, 0.0);
    }

    #[test]
    fn closure_cosine_similarity_anti_aligned_is_neg_one() {
        // x = (1, 0), y = (-1, 0); norms = 1, 1; cos = -1.
        let v = eval_with_slots(
            closure_cosine_similarity(&[0, 1], &[2, 3], 4, 5),
            vec![1.0, 0.0, -1.0, 0.0, 1.0, 1.0],
        );
        assert!((v - (-1.0)).abs() < 1e-12);
    }

    #[test]
    fn closure_squared_cosine_similarity_self_is_one() {
        // cos²(x, x) = (x·x)² / (x·x)·(x·x) = 1.
        let v = eval_with_slots(
            closure_squared_cosine_similarity(&[0, 1], &[2, 3]),
            vec![1.0, 2.0, 1.0, 2.0],
        );
        assert!((v - 1.0).abs() < 1e-12);
    }

    #[test]
    fn closure_squared_cosine_similarity_orthogonal_is_zero() {
        let v = eval_with_slots(
            closure_squared_cosine_similarity(&[0, 1], &[2, 3]),
            vec![1.0, 0.0, 0.0, 1.0],
        );
        assert_eq!(v, 0.0);
    }

    #[test]
    fn closure_squared_cosine_similarity_bounded_by_one() {
        for slots in [
            vec![1.0_f64, 2.0, 3.0, 4.0],
            vec![1.5, -0.5, 2.0, 1.0],
            vec![1.0, 1.0, -1.0, -1.0],
        ] {
            let v = eval_with_slots(
                closure_squared_cosine_similarity(&[0, 1], &[2, 3]),
                slots,
            );
            assert!(v >= -1e-12 && v <= 1.0 + 1e-12);
        }
    }

    #[test]
    fn closure_squared_cosine_similarity_anti_aligned_is_one() {
        // x = (1, 0), y = (-1, 0): cos² = 1 (sign lost in squaring).
        let v = eval_with_slots(
            closure_squared_cosine_similarity(&[0, 1], &[2, 3]),
            vec![1.0, 0.0, -1.0, 0.0],
        );
        assert!((v - 1.0).abs() < 1e-12);
    }

    // ── RBF kernel (iter-99) ──────────────────────────────────────

    #[test]
    fn closure_rbf_kernel_self_is_one() {
        // k(x, x) = exp(0) = 1.
        let v = eval_with_slots(
            closure_rbf_kernel(&[0, 1], &[2, 3], 4),
            vec![1.5, -2.0, 1.5, -2.0, 0.5],
        );
        assert!((v - 1.0).abs() < 1e-12);
    }

    #[test]
    fn closure_rbf_kernel_bounded_by_one() {
        // k(x, y) ≤ 1 for all x, y (and any positive scale).
        for slots in [
            vec![1.0_f64, 2.0, 3.0, 4.0, 0.5], // scale=0.5
            vec![1.5, -0.5, 0.7, 2.1, 1.0],
            vec![0.0, 0.0, 1.0, 1.0, 2.0],
        ] {
            let v = eval_with_slots(
                closure_rbf_kernel(&[0, 1], &[2, 3], 4),
                slots,
            );
            assert!(v > 0.0 && v <= 1.0 + 1e-12);
        }
    }

    #[test]
    fn closure_rbf_kernel_symmetric() {
        let xy = eval_with_slots(
            closure_rbf_kernel(&[0, 1], &[2, 3], 4),
            vec![1.0, 0.5, -0.5, 1.5, 0.7],
        );
        let yx = eval_with_slots(
            closure_rbf_kernel(&[2, 3], &[0, 1], 4),
            vec![1.0, 0.5, -0.5, 1.5, 0.7],
        );
        assert!((xy - yx).abs() < 1e-12);
    }

    #[test]
    fn closure_rbf_kernel_decays_with_distance() {
        // k(x, y) decreases as ||x - y|| grows.
        let close = eval_with_slots(
            closure_rbf_kernel(&[0, 1], &[2, 3], 4),
            vec![0.0, 0.0, 0.1, 0.1, 1.0],
        );
        let far = eval_with_slots(
            closure_rbf_kernel(&[0, 1], &[2, 3], 4),
            vec![0.0, 0.0, 3.0, 3.0, 1.0],
        );
        assert!(close > far, "k(close) = {} should > k(far) = {}", close, far);
        assert!(far < 1e-4, "k(far=√18, scale=1) = {} should be near 0", far);
    }

    #[test]
    fn closure_rbf_kernel_unit_sigma_known_value() {
        // x=(0,0), y=(1,0), σ²=1 → scale=0.5, dist²=1 → k=exp(-0.5).
        let v = eval_with_slots(
            closure_rbf_kernel(&[0, 1], &[2, 3], 4),
            vec![0.0, 0.0, 1.0, 0.0, 0.5],
        );
        let expected = (-0.5_f64).exp();
        assert!((v - expected).abs() < 1e-12, "k = {}, expected {}", v, expected);
    }

    #[test]
    fn closure_exp_of_arbitrary_expression() {
        // exp_of(slot(0)) ≡ closure_exp(0).
        let direct = eval_with_slots(closure_exp(0), vec![1.5]);
        let arg = EmlClosureExpr::slot(0);
        let via_helper = eval_with_slots(closure_exp_of(arg), vec![1.5]);
        assert!((direct - via_helper).abs() < 1e-12);

        // exp_of(Plus(slot(0), One)) = e^(x+1).
        let arg = EmlClosureExpr::plus(EmlClosureExpr::slot(0), EmlClosureExpr::one());
        let v = eval_with_slots(closure_exp_of(arg), vec![2.0]);
        let expected = (2.0_f64 + 1.0).exp();
        assert!((v - expected).abs() < 1e-12);
    }

    // ── sum / product / mean aggregators (iter-133) ───────────────

    #[test]
    fn closure_sum_slots_2d_known() {
        let v = eval_with_slots(closure_sum_slots(&[0, 1, 2]), vec![1.0, 2.0, 3.0]);
        assert_eq!(v, 6.0);
    }

    #[test]
    fn closure_sum_slots_empty_returns_zero() {
        let v = eval_with_slots(closure_sum_slots(&[]), vec![5.0, 5.0]);
        assert_eq!(v, 0.0);
    }

    #[test]
    fn closure_product_slots_2d_known() {
        let v = eval_with_slots(closure_product_slots(&[0, 1, 2]), vec![2.0, 3.0, 4.0]);
        assert_eq!(v, 24.0);
    }

    #[test]
    fn closure_product_slots_empty_returns_one() {
        let v = eval_with_slots(closure_product_slots(&[]), vec![5.0, 5.0]);
        assert_eq!(v, 1.0);
    }

    #[test]
    fn closure_arithmetic_mean_2d_known() {
        // mean of (1, 2, 3, 4) = 2.5; n=4.
        let v = eval_with_slots(
            closure_arithmetic_mean(&[0, 1, 2, 3], 4),
            vec![1.0, 2.0, 3.0, 4.0, 4.0],
        );
        assert_eq!(v, 2.5);
    }

    #[test]
    fn closure_arithmetic_mean_with_zero_in_slots() {
        // (0, 4, 8) / 3 = 4.
        let v = eval_with_slots(
            closure_arithmetic_mean(&[0, 1, 2], 3),
            vec![0.0, 4.0, 8.0, 3.0],
        );
        assert_eq!(v, 4.0);
    }

    // ── scaled_squared_distance + weighted_mse (iter-128) ─────────

    #[test]
    fn closure_scaled_squared_distance_matches_factored_form() {
        // scale=2, p=(1,2), q=(0,0): ||p-q||²=5; scaled=10.
        let v = eval_with_slots(
            closure_scaled_squared_distance(&[0, 1], &[2, 3], 4),
            vec![1.0, 2.0, 0.0, 0.0, 2.0],
        );
        assert_eq!(v, 10.0);
    }

    #[test]
    fn closure_scaled_squared_distance_zero_scale_returns_zero() {
        let v = eval_with_slots(
            closure_scaled_squared_distance(&[0, 1], &[2, 3], 4),
            vec![1.0, 2.0, 3.0, 4.0, 0.0],
        );
        assert_eq!(v, 0.0);
    }

    #[test]
    fn closure_weighted_mse_uniform_weights_matches_mse() {
        // All weights = 1 → weighted_mse ≡ mse.
        let v_w = eval_with_slots(
            closure_weighted_mse_loss(&[0, 1, 2], &[3, 4, 5], &[6, 7, 8], 9),
            vec![1.0, 2.0, 3.0, 1.5, 2.5, 4.0, 1.0, 1.0, 1.0, 3.0],
        );
        let v_m = eval_with_slots(
            closure_mse_loss(&[0, 1, 2], &[3, 4, 5], 9),
            vec![1.0, 2.0, 3.0, 1.5, 2.5, 4.0, 1.0, 1.0, 1.0, 3.0],
        );
        assert!((v_w - v_m).abs() < 1e-12);
    }

    #[test]
    fn closure_weighted_mse_zero_weights_returns_zero() {
        let v = eval_with_slots(
            closure_weighted_mse_loss(&[0, 1], &[2, 3], &[4, 5], 6),
            vec![1.0, 2.0, 0.0, 0.0, 0.0, 0.0, 2.0],
        );
        assert_eq!(v, 0.0);
    }

    #[test]
    fn closure_weighted_mse_emphasizes_heavy_weight() {
        // Weights (10, 0): only first example contributes.
        // pred=(1, 100), target=(0, 0), n=2: weighted_sum = 10·1² + 0·100² = 10.
        // weighted_mse = 10 / 2 = 5.
        let v = eval_with_slots(
            closure_weighted_mse_loss(&[0, 1], &[2, 3], &[4, 5], 6),
            vec![1.0, 100.0, 0.0, 0.0, 10.0, 0.0, 2.0],
        );
        assert_eq!(v, 5.0);
    }

    // ── L2 norm + linear form (iter-124) ──────────────────────────

    #[test]
    fn closure_l2_norm_squared_is_alias_for_l2_penalty() {
        let v_norm = eval_with_slots(
            closure_l2_norm_squared(&[0, 1, 2]),
            vec![1.0, 2.0, 3.0],
        );
        let v_penalty = eval_with_slots(
            closure_l2_penalty(&[0, 1, 2]),
            vec![1.0, 2.0, 3.0],
        );
        assert_eq!(v_norm, v_penalty);
    }

    #[test]
    fn closure_linear_form_classical_single_neuron() {
        // y = w·x + b, w = (2, 3), x = (1, 4), b = 0.5.
        // = 2·1 + 3·4 + 0.5 = 14.5.
        let v = eval_with_slots(
            closure_linear_form(&[0, 1], &[2, 3], 4),
            vec![1.0, 4.0, 2.0, 3.0, 0.5],
        );
        assert!((v - 14.5).abs() < 1e-12);
    }

    #[test]
    fn closure_linear_form_zero_weights_returns_bias() {
        let v = eval_with_slots(
            closure_linear_form(&[0, 1], &[2, 3], 4),
            vec![10.0, -10.0, 0.0, 0.0, 7.0],
        );
        assert_eq!(v, 7.0);
    }

    #[test]
    fn closure_linear_form_zero_bias_returns_dot_product() {
        let v = eval_with_slots(
            closure_linear_form(&[0, 1], &[2, 3], 4),
            vec![3.0, 4.0, 5.0, 6.0, 0.0],
        );
        // 3·5 + 4·6 + 0 = 39.
        assert_eq!(v, 39.0);
    }

    // ── Loss primitives — MSE / L2 (iter-106) ────────────────────

    #[test]
    fn closure_squared_error_zero_at_match() {
        let v = eval_with_slots(closure_squared_error(0, 1), vec![3.0, 3.0]);
        assert!(v.abs() < 1e-12);
    }

    #[test]
    fn closure_squared_error_is_non_negative() {
        for (p, t) in [(1.0_f64, 0.0), (-2.0, 3.0), (5.0, -5.0)] {
            let v = eval_with_slots(closure_squared_error(0, 1), vec![p, t]);
            assert!(v >= 0.0);
            // (pred - target)² = (target - pred)² (symmetry).
            let v_rev = eval_with_slots(closure_squared_error(1, 0), vec![p, t]);
            assert_eq!(v, v_rev);
        }
    }

    #[test]
    fn closure_squared_error_quadratic() {
        // For pred = 0, target = c: error = c².
        for c in [1.0_f64, 2.0, -3.0, 5.0] {
            let v = eval_with_slots(closure_squared_error(0, 1), vec![0.0, c]);
            assert_eq!(v, c * c);
        }
    }

    #[test]
    fn closure_mse_loss_at_perfect_prediction_is_zero() {
        // pred ≡ target → MSE = 0.
        let v = eval_with_slots(
            closure_mse_loss(&[0, 1, 2], &[3, 4, 5], 6),
            vec![1.0, 2.0, 3.0, 1.0, 2.0, 3.0, 3.0],
        );
        assert!(v.abs() < 1e-12);
    }

    #[test]
    fn closure_mse_loss_known_value() {
        // pred = (1, 2, 3), target = (1.5, 2.5, 4), n = 3.
        // errors: 0.25, 0.25, 1.0; sum = 1.5; MSE = 0.5.
        let v = eval_with_slots(
            closure_mse_loss(&[0, 1, 2], &[3, 4, 5], 6),
            vec![1.0, 2.0, 3.0, 1.5, 2.5, 4.0, 3.0],
        );
        assert!((v - 0.5).abs() < 1e-12);
    }

    #[test]
    fn closure_l2_penalty_zero_at_zero_weights() {
        let v = eval_with_slots(
            closure_l2_penalty(&[0, 1, 2]),
            vec![0.0, 0.0, 0.0],
        );
        assert_eq!(v, 0.0);
    }

    #[test]
    fn closure_l2_penalty_sum_of_squares() {
        // (3, 4, 5) → 9 + 16 + 25 = 50.
        let v = eval_with_slots(
            closure_l2_penalty(&[0, 1, 2]),
            vec![3.0, 4.0, 5.0],
        );
        assert_eq!(v, 50.0);
    }

    #[test]
    fn closure_l2_penalty_non_negative_always() {
        for slots in [
            vec![1.0_f64, -2.0, 3.0],
            vec![-5.0_f64, 0.0, 0.5],
            vec![0.1_f64, 0.1, 0.1],
        ] {
            let v = eval_with_slots(closure_l2_penalty(&[0, 1, 2]), slots);
            assert!(v >= 0.0);
        }
    }

    // ── Vector primitives (iter-98) ───────────────────────────────

    #[test]
    fn closure_dot_product_2d() {
        // (1,2) · (3,4) = 1·3 + 2·4 = 11.
        let v = eval_with_slots(
            closure_dot_product(&[0, 1], &[2, 3]),
            vec![1.0, 2.0, 3.0, 4.0],
        );
        assert_eq!(v, 11.0);
    }

    #[test]
    fn closure_dot_product_orthogonal_is_zero() {
        // (1,0,0) · (0,1,0) = 0.
        let v = eval_with_slots(
            closure_dot_product(&[0, 1, 2], &[3, 4, 5]),
            vec![1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
        );
        assert_eq!(v, 0.0);
    }

    #[test]
    fn closure_dot_product_symmetric() {
        // x · y = y · x.
        let xy = eval_with_slots(
            closure_dot_product(&[0, 1, 2], &[3, 4, 5]),
            vec![1.5, -0.7, 2.0, -0.3, 1.2, 0.8],
        );
        let yx = eval_with_slots(
            closure_dot_product(&[3, 4, 5], &[0, 1, 2]),
            vec![1.5, -0.7, 2.0, -0.3, 1.2, 0.8],
        );
        assert!((xy - yx).abs() < 1e-12);
    }

    #[test]
    fn closure_squared_distance_zero_for_identical_vectors() {
        // Same slot indices → squared distance = 0.
        let v = eval_with_slots(
            closure_squared_distance(&[0, 1], &[2, 3]),
            vec![1.5, -2.0, 1.5, -2.0],
        );
        assert!(v.abs() < 1e-12);
    }

    #[test]
    fn closure_squared_distance_equals_sum_of_squared_diffs() {
        // (1,2,3) - (4,5,6) = (-3,-3,-3); squared = 27.
        let v = eval_with_slots(
            closure_squared_distance(&[0, 1, 2], &[3, 4, 5]),
            vec![1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        );
        assert_eq!(v, 27.0);
    }

    #[test]
    fn closure_squared_distance_expands_via_dot_product() {
        // ||x - y||² = ||x||² - 2·x·y + ||y||².
        // Property test across 3 (x, y) pairs.
        for slots in [
            vec![1.0_f64, 2.0, 0.5, 1.5],
            vec![-1.0, 3.0, 2.0, -0.5],
            vec![0.0, 0.0, 1.0, 1.0],
        ] {
            let dist_sq = eval_with_slots(
                closure_squared_distance(&[0, 1], &[2, 3]),
                slots.clone(),
            );
            let x_dot_x = eval_with_slots(
                closure_dot_product(&[0, 1], &[0, 1]),
                slots.clone(),
            );
            let x_dot_y = eval_with_slots(
                closure_dot_product(&[0, 1], &[2, 3]),
                slots.clone(),
            );
            let y_dot_y = eval_with_slots(
                closure_dot_product(&[2, 3], &[2, 3]),
                slots.clone(),
            );
            let expected = x_dot_x - 2.0 * x_dot_y + y_dot_y;
            assert!(
                (dist_sq - expected).abs() < 1e-12,
                "{:?}: ||x-y||² = {}; expansion = {}", slots, dist_sq, expected
            );
        }
    }

    #[test]
    fn closure_attention_score_unit_query_key() {
        // q = (1, 0), k = (1, 0), 1/sqrt(d) = 1/sqrt(2).
        // score = 1·1 + 0·0 = 1; scaled = 1 / sqrt(2).
        let v = eval_with_slots(
            closure_attention_score(&[0, 1], &[2, 3], 4),
            vec![1.0, 0.0, 1.0, 0.0, 1.0 / 2.0_f64.sqrt()],
        );
        let expected = 1.0 / 2.0_f64.sqrt();
        assert!((v - expected).abs() < 1e-12);
    }

    #[test]
    fn closure_attention_score_orthogonal_is_zero() {
        let v = eval_with_slots(
            closure_attention_score(&[0, 1, 2], &[3, 4, 5], 6),
            vec![1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.5],
        );
        assert_eq!(v, 0.0);
    }

    #[test]
    fn closure_attention_score_anti_aligned_is_negative() {
        // q = (1, 0), k = (-1, 0) → score = -1 · (1/√d) < 0.
        let v = eval_with_slots(
            closure_attention_score(&[0, 1], &[2, 3], 4),
            vec![1.0, 0.0, -1.0, 0.0, 0.5],
        );
        assert!(v < 0.0);
        assert!((v + 0.5).abs() < 1e-12);
    }

    // ── LayerNorm decomposition (iter-88) ─────────────────────────

    #[test]
    fn closure_residual_add_is_simple_sum() {
        // residual_add(x, r) = x + r.
        for (x, r) in [(1.0_f64, 2.0), (-1.0, 3.5), (0.0, 0.0)] {
            let v = eval_with_slots(closure_residual_add(0, 1), vec![x, r]);
            assert_eq!(v, x + r);
        }
    }

    #[test]
    fn closure_center_subtracts_mean() {
        // center(x, μ) = x - μ.
        for (x, mu) in [(5.0_f64, 3.0), (-2.0, -2.0), (1.0, 4.0)] {
            let v = eval_with_slots(closure_center(0, 1), vec![x, mu]);
            assert_eq!(v, x - mu);
        }
    }

    #[test]
    fn closure_standardize_z_score() {
        // standardize(x, μ, σ) = (x - μ) / σ.
        let v = eval_with_slots(
            closure_standardize(0, 1, 2),
            vec![6.0, 4.0, 2.0],
        );
        assert!((v - 1.0).abs() < 1e-12);

        // Sign and magnitude check.
        let v2 = eval_with_slots(
            closure_standardize(0, 1, 2),
            vec![3.0, 5.0, 0.5],
        );
        assert!((v2 - (-4.0)).abs() < 1e-12);
    }

    #[test]
    fn closure_affine_gain_bias() {
        // affine(x, γ, β) = γx + β.
        let v = eval_with_slots(
            closure_affine(0, 1, 2),
            vec![2.0, 3.0, 1.0],
        );
        assert_eq!(v, 7.0);

        // γ=0: y = β only.
        let v0 = eval_with_slots(
            closure_affine(0, 1, 2),
            vec![5.0, 0.0, 10.0],
        );
        assert_eq!(v0, 10.0);
    }

    #[test]
    fn closure_layer_norm_full_pipeline() {
        // layer_norm(x, μ, σ, γ, β) = γ·(x-μ)/σ + β.
        let v = eval_with_slots(
            closure_layer_norm(0, 1, 2, 3, 4),
            vec![6.0, 4.0, 2.0, 0.5, 1.0],
        );
        // (6-4)/2 = 1; 0.5·1 + 1 = 1.5.
        assert!((v - 1.5).abs() < 1e-12);
    }

    #[test]
    fn closure_layer_norm_identity_with_gain_one_bias_zero() {
        // With γ=1, β=0, layer_norm reduces to standardization.
        for (x, mu, sigma) in [
            (10.0_f64, 5.0, 2.5),
            (-3.0, -1.0, 1.5),
            (0.0, 0.0, 1.0),
        ] {
            let ln = eval_with_slots(
                closure_layer_norm(0, 1, 2, 3, 4),
                vec![x, mu, sigma, 1.0, 0.0],
            );
            let std = eval_with_slots(
                closure_standardize(0, 1, 2),
                vec![x, mu, sigma],
            );
            assert!(
                (ln - std).abs() < 1e-12,
                "ln = {}; std = {}", ln, std
            );
        }
    }

    #[test]
    fn closure_layer_norm_centered_input_at_zero_output() {
        // x = μ → (x - μ) = 0 → output = β.
        let v = eval_with_slots(
            closure_layer_norm(0, 1, 2, 3, 4),
            vec![4.0, 4.0, 2.0, 0.5, 3.7],
        );
        assert!((v - 3.7).abs() < 1e-12);
    }

    // ── Logit + temperature softmax (iter-86) ─────────────────────

    #[test]
    fn closure_logit_at_half_is_zero() {
        let v = eval_with_slots(closure_logit(0), vec![0.5]);
        assert!(v.abs() < 1e-12, "logit(0.5) = {}", v);
    }

    #[test]
    fn closure_logit_inverts_sigmoid() {
        // logit(σ(θ)) = θ for any θ.
        for theta in [-3.0_f64, -1.0, -0.3, 0.0, 0.3, 1.0, 3.0] {
            let p = eval_with_slots(closure_sigmoid(0), vec![theta]);
            let recovered = eval_with_slots(closure_logit(0), vec![p]);
            assert!(
                (recovered - theta).abs() < 1e-10,
                "logit(σ({})) = {}", theta, recovered
            );
        }
    }

    #[test]
    fn closure_logit_matches_log_p_over_one_minus_p() {
        for p in [0.1_f64, 0.3, 0.5, 0.7, 0.9, 0.99] {
            let v = eval_with_slots(closure_logit(0), vec![p]);
            let expected = (p / (1.0 - p)).ln();
            assert!(
                (v - expected).abs() < 1e-12,
                "logit({}) = {}, expected {}", p, v, expected
            );
        }
    }

    #[test]
    fn closure_softmax_temperature_at_beta_one_matches_unscaled() {
        // β=1 recovers closure_categorical_softmax_slot.
        let slots = [0_u32, 1];
        for theta in [vec![1.0_f64, -1.0], vec![0.0, 0.0], vec![-2.0, 3.0]] {
            for &target in &slots {
                let mut slots_plus_beta = theta.clone();
                slots_plus_beta.push(1.0); // β = 1

                let scaled = eval_with_slots(
                    closure_softmax_temperature_slot(target, &slots, 2),
                    slots_plus_beta,
                );
                let plain = eval_with_slots(
                    closure_categorical_softmax_slot(target, &slots),
                    theta.clone(),
                );
                assert!(
                    (scaled - plain).abs() < 1e-12,
                    "target={} θ={:?}: β=1 scaled = {}, plain = {}",
                    target, theta, scaled, plain
                );
            }
        }
    }

    #[test]
    fn closure_softmax_temperature_high_beta_concentrates_on_argmax() {
        // At β=20, the largest θ wins.
        let slots = [0_u32, 1];
        let v_top = eval_with_slots(
            closure_softmax_temperature_slot(1, &slots, 2),
            vec![0.0, 5.0, 20.0],
        );
        assert!(v_top > 1.0 - 1e-6, "high-β softmax top = {}", v_top);
    }

    #[test]
    fn closure_softmax_temperature_at_low_beta_is_uniform() {
        // β=0: all exp(β·θ_i) = 1, so softmax_T(i) = 1/k.
        let slots = [0_u32, 1];
        let v = eval_with_slots(
            closure_softmax_temperature_slot(0, &slots, 2),
            vec![3.0, 7.0, 0.0],
        );
        assert!((v - 1.0 / 3.0).abs() < 1e-12, "softmax_T at β=0: {}", v);
    }

    #[test]
    fn closure_softmax_temperature_probs_sum_to_one() {
        let slots = [0_u32, 1];
        for beta in [0.5_f64, 1.0, 2.5, 10.0] {
            for theta in [vec![1.0_f64, -1.0], vec![-2.0, 3.0]] {
                let mut slots_plus_beta = theta.clone();
                slots_plus_beta.push(beta);
                let p0 = eval_with_slots(
                    closure_softmax_temperature_slot(0, &slots, 2),
                    slots_plus_beta.clone(),
                );
                let p1 = eval_with_slots(
                    closure_softmax_temperature_slot(1, &slots, 2),
                    slots_plus_beta.clone(),
                );
                let pp = eval_with_slots(
                    closure_softmax_temperature_pinned(&slots, 2),
                    slots_plus_beta,
                );
                let sum = p0 + p1 + pp;
                assert!(
                    (sum - 1.0).abs() < 1e-12,
                    "β={} θ={:?}: sum = {}", beta, theta, sum
                );
            }
        }
    }

    // ── Smooth max / smooth min (iter-84) ─────────────────────────

    #[test]
    fn closure_smooth_max_at_beta_one_matches_lse() {
        // β=1: SmoothMax(x; 1) = log Σ exp(x_i).
        let v = eval_with_slots(
            closure_smooth_max(&[0, 1], 2),
            vec![1.0, 2.0, 1.0],
        );
        let expected = (1.0_f64.exp() + 2.0_f64.exp()).ln();
        assert!((v - expected).abs() < 1e-12, "smooth_max = {}", v);
    }

    #[test]
    fn closure_smooth_max_at_large_beta_approaches_max() {
        // β=50: SmoothMax(x; 50) ≈ max(x).
        let v = eval_with_slots(
            closure_smooth_max(&[0, 1, 2], 3),
            vec![1.0, 3.7, -2.0, 50.0],
        );
        assert!(
            (v - 3.7).abs() < 1e-2,
            "SmoothMax({{1, 3.7, -2}}; 50) = {} should ≈ max = 3.7", v
        );
    }

    #[test]
    fn closure_smooth_max_single_element_is_that_element() {
        // SmoothMax([x]; β) = (1/β) · log exp(β·x) = x for any β > 0.
        let v = eval_with_slots(
            closure_smooth_max(&[0], 1),
            vec![2.5, 3.0],
        );
        assert!((v - 2.5).abs() < 1e-12, "single-element SmoothMax = {}", v);
    }

    #[test]
    fn closure_smooth_max_is_translation_equivariant() {
        // SmoothMax(x + c; β) = SmoothMax(x; β) + c (use slot for c offset).
        let base = eval_with_slots(
            closure_smooth_max(&[0, 1], 2),
            vec![1.0, 2.0, 1.0],
        );
        let shifted = eval_with_slots(
            closure_smooth_max(&[0, 1], 2),
            vec![6.0, 7.0, 1.0],
        );
        assert!((shifted - base - 5.0).abs() < 1e-12, "shift = {}", shifted - base);
    }

    #[test]
    fn closure_smooth_min_at_beta_one_matches_neg_lse_of_neg() {
        // β=1: SmoothMin(x; 1) = -log Σ exp(-x_i).
        let v = eval_with_slots(
            closure_smooth_min(&[0, 1], 2),
            vec![1.0, 2.0, 1.0],
        );
        let expected = -((-1.0_f64).exp() + (-2.0_f64).exp()).ln();
        assert!((v - expected).abs() < 1e-12, "smooth_min = {}", v);
    }

    #[test]
    fn closure_smooth_min_at_large_beta_approaches_min() {
        // β=50: SmoothMin(x; 50) ≈ min(x).
        let v = eval_with_slots(
            closure_smooth_min(&[0, 1, 2], 3),
            vec![1.0, 3.7, -2.0, 50.0],
        );
        assert!(
            (v - (-2.0)).abs() < 1e-2,
            "SmoothMin({{1, 3.7, -2}}; 50) = {} should ≈ min = -2", v
        );
    }

    #[test]
    fn closure_smooth_min_negates_smooth_max_of_negated() {
        // Algebraic identity: SmoothMin(x; β) = -SmoothMax(-x; β).
        // Verify by constructing both via different slot vectors.
        for beta in [1.0_f64, 2.5, 10.0] {
            let smax = eval_with_slots(
                closure_smooth_max(&[0, 1], 2),
                vec![-1.5, 0.7, beta],
            );
            let smin_of_neg = eval_with_slots(
                closure_smooth_min(&[0, 1], 2),
                vec![1.5, -0.7, beta],
            );
            assert!(
                (smin_of_neg + smax).abs() < 1e-12,
                "β={}: SmoothMin(-x) = {}; -SmoothMax(x) = {}",
                beta, smin_of_neg, -smax
            );
        }
    }

    #[test]
    fn closure_smooth_max_is_upper_bound_on_inputs() {
        // SmoothMax(x; β) ≥ max(x_i) - log(k)/β (lower bound on overshoot).
        // Test the weaker: SmoothMax(x; β) ≥ each x_i / k upper for k=2.
        // Tighter: SmoothMax ≥ max(x) - ln(k)/β.
        let v = eval_with_slots(
            closure_smooth_max(&[0, 1, 2], 3),
            vec![0.0, 1.0, 2.0, 5.0],
        );
        let max_inp = 2.0_f64;
        let bound_low = max_inp;
        let bound_high = max_inp + (3.0_f64.ln()) / 5.0;
        assert!(
            v >= bound_low - 1e-9 && v <= bound_high + 1e-9,
            "SmoothMax = {} should be in [{}, {}]", v, bound_low, bound_high
        );
    }

    // ── Scaled sigmoid / β-Swish / GELU (iter-83) ─────────────────

    #[test]
    fn closure_sigmoid_scaled_at_beta_one_matches_sigmoid() {
        for x in [-3.0_f64, -0.5, 0.0, 0.5, 3.0] {
            let scaled = eval_with_slots(
                closure_sigmoid_scaled(0, 1),
                vec![x, 1.0],
            );
            let plain = eval_with_slots(closure_sigmoid(0), vec![x]);
            assert!(
                (scaled - plain).abs() < 1e-12,
                "σ_1({}) = {}; σ = {}", x, scaled, plain
            );
        }
    }

    #[test]
    fn closure_sigmoid_scaled_at_beta_zero_is_half() {
        // σ_0(x) = 1 / (1 + exp(0)) = 0.5 for any x.
        for x in [-5.0_f64, 0.0, 5.0] {
            let v = eval_with_slots(
                closure_sigmoid_scaled(0, 1),
                vec![x, 0.0],
            );
            assert!((v - 0.5).abs() < 1e-12, "σ_0({}) = {}", x, v);
        }
    }

    #[test]
    fn closure_sigmoid_scaled_large_beta_sharpens() {
        // At β=10, σ_β(x) is much sharper around 0.
        let v_pos = eval_with_slots(
            closure_sigmoid_scaled(0, 1),
            vec![0.5, 10.0],
        );
        let v_neg = eval_with_slots(
            closure_sigmoid_scaled(0, 1),
            vec![-0.5, 10.0],
        );
        assert!(v_pos > 0.99, "σ_10(0.5) = {} should be ≈ 1", v_pos);
        assert!(v_neg < 0.01, "σ_10(-0.5) = {} should be ≈ 0", v_neg);
    }

    #[test]
    fn closure_swish_scaled_at_beta_one_matches_swish() {
        for x in [-2.0_f64, -0.5, 0.0, 0.5, 2.0] {
            let scaled = eval_with_slots(
                closure_swish_scaled(0, 1),
                vec![x, 1.0],
            );
            let plain = eval_with_slots(closure_swish(0), vec![x]);
            assert!(
                (scaled - plain).abs() < 1e-12,
                "swish_1({}) = {}; swish = {}", x, scaled, plain
            );
        }
    }

    #[test]
    fn closure_swish_scaled_beta_two_is_double_input_swish() {
        // swish_2(x) = x · σ(2x).
        for x in [-1.5_f64, 0.5, 2.0] {
            let v = eval_with_slots(
                closure_swish_scaled(0, 1),
                vec![x, 2.0],
            );
            let expected = x / (1.0 + (-2.0 * x).exp());
            assert!(
                (v - expected).abs() < 1e-12,
                "swish_2({}) = {}; expected {}", x, v, expected
            );
        }
    }

    #[test]
    fn closure_gelu_sigmoid_approx_matches_hendrycks_form() {
        // GELU(x) ≈ x · σ(1.702 · x). Hendrycks & Gimpel 2016.
        for x in [-3.0_f64, -1.0, -0.5, 0.0, 0.5, 1.0, 3.0] {
            let v = eval_with_slots(
                closure_gelu_sigmoid_approx(0, 1),
                vec![x, 1.702],
            );
            let expected = x / (1.0 + (-1.702 * x).exp());
            assert!(
                (v - expected).abs() < 1e-12,
                "GELU_approx({}) = {}; expected {}", x, v, expected
            );
        }
    }

    #[test]
    fn closure_gelu_sigmoid_approx_at_zero_is_zero() {
        let v = eval_with_slots(
            closure_gelu_sigmoid_approx(0, 1),
            vec![0.0, 1.702],
        );
        assert!(v.abs() < 1e-12);
    }

    #[test]
    fn closure_gelu_sigmoid_approx_close_to_true_gelu_for_large_inputs() {
        // For |x| large, both GELU forms saturate (GELU(x) → x for
        // x ≫ 0, GELU(x) → 0 for x ≪ 0). At x=±10 with c=1.702,
        // σ(±17) is within 1e-7 of {1, 0}, well under the asymptote.
        let v_pos = eval_with_slots(
            closure_gelu_sigmoid_approx(0, 1),
            vec![10.0, 1.702],
        );
        let v_neg = eval_with_slots(
            closure_gelu_sigmoid_approx(0, 1),
            vec![-10.0, 1.702],
        );
        assert!((v_pos - 10.0).abs() < 1e-5, "GELU(10) ≈ {}", v_pos);
        assert!(v_neg.abs() < 1e-5, "GELU(-10) ≈ {}", v_neg);
    }

    // ── Entropy primitives (iter-82) ──────────────────────────────

    #[test]
    fn closure_entropy_bernoulli_at_zero_is_ln_2() {
        // At θ=0, σ=0.5, so H = -0.5·log 0.5 - 0.5·log 0.5 = ln 2.
        let h = eval_with_slots(closure_entropy_bernoulli(0), vec![0.0]);
        assert!((h - 2.0_f64.ln()).abs() < 1e-12, "H(B(0.5)) = {}", h);
    }

    #[test]
    fn closure_entropy_bernoulli_is_non_negative() {
        for theta in [-5.0_f64, -1.0, -0.3, 0.0, 0.3, 1.0, 5.0] {
            let h = eval_with_slots(closure_entropy_bernoulli(0), vec![theta]);
            assert!(h >= -1e-12, "H({}) = {} (must be ≥ 0)", theta, h);
        }
    }

    #[test]
    fn closure_entropy_bernoulli_max_at_zero() {
        // Concave with maximum at θ=0 (where p=0.5).
        let h_neg2 = eval_with_slots(closure_entropy_bernoulli(0), vec![-2.0]);
        let h_zero = eval_with_slots(closure_entropy_bernoulli(0), vec![0.0]);
        let h_pos2 = eval_with_slots(closure_entropy_bernoulli(0), vec![2.0]);
        assert!(h_zero > h_neg2);
        assert!(h_zero > h_pos2);
    }

    #[test]
    fn closure_entropy_bernoulli_saturates_to_zero() {
        // H → 0 as θ → ±∞ (one outcome becomes certain).
        let h_large = eval_with_slots(closure_entropy_bernoulli(0), vec![10.0]);
        let h_small = eval_with_slots(closure_entropy_bernoulli(0), vec![-10.0]);
        assert!(h_large < 1e-3, "H(10) = {} should be near 0", h_large);
        assert!(h_small < 1e-3, "H(-10) = {} should be near 0", h_small);
    }

    #[test]
    fn closure_entropy_bernoulli_matches_direct_computation() {
        // H = -p log p - (1-p) log(1-p).
        for theta in [-2.0_f64, -0.5, 0.5, 2.0] {
            let h = eval_with_slots(closure_entropy_bernoulli(0), vec![theta]);
            let p = 1.0 / (1.0 + (-theta).exp());
            let expected = -p * p.ln() - (1.0 - p) * (1.0 - p).ln();
            assert!(
                (h - expected).abs() < 1e-12,
                "H({}) = {}; expected {}", theta, h, expected
            );
        }
    }

    #[test]
    fn closure_entropy_categorical_at_zero_is_ln_k() {
        // Uniform distribution: H = ln k.
        let h_k3 = eval_with_slots(
            closure_entropy_categorical(&[0, 1]),
            vec![0.0, 0.0],
        );
        assert!((h_k3 - 3.0_f64.ln()).abs() < 1e-12, "H_uniform(k=3) = {}", h_k3);

        let h_k4 = eval_with_slots(
            closure_entropy_categorical(&[0, 1, 2]),
            vec![0.0, 0.0, 0.0],
        );
        assert!((h_k4 - 4.0_f64.ln()).abs() < 1e-12, "H_uniform(k=4) = {}", h_k4);
    }

    #[test]
    fn closure_entropy_categorical_is_non_negative() {
        for theta in [
            vec![0.0_f64, 0.0],
            vec![1.0, -1.0],
            vec![-2.0, 3.0],
            vec![5.0, 5.0],
        ] {
            let h = eval_with_slots(closure_entropy_categorical(&[0, 1]), theta.clone());
            assert!(h >= -1e-12, "H({:?}) = {} (must be ≥ 0)", theta, h);
        }
    }

    #[test]
    fn closure_entropy_categorical_k2_matches_bernoulli() {
        // For k=2, Categorical entropy ≡ Bernoulli entropy.
        for theta in [-2.0_f64, -0.5, 0.0, 0.7, 3.0] {
            let h_cat = eval_with_slots(
                closure_entropy_categorical(&[0]),
                vec![theta],
            );
            let h_bern = eval_with_slots(
                closure_entropy_bernoulli(0),
                vec![theta],
            );
            assert!(
                (h_cat - h_bern).abs() < 1e-12,
                "Cat_k=2({}) = {}; Bern = {}", theta, h_cat, h_bern
            );
        }
    }

    #[test]
    fn closure_entropy_categorical_matches_direct_computation() {
        // H = -Σ p_i log p_i over the full simplex (including pinned).
        let slots = [0_u32, 1];
        let cases = [
            vec![0.0_f64, 0.0],
            vec![1.0, -1.0],
            vec![-0.5, 0.5],
            vec![2.0, 1.0],
        ];
        for theta in &cases {
            let h_eml = eval_with_slots(
                closure_entropy_categorical(&slots),
                theta.clone(),
            );

            // Compute softmax probabilities directly.
            let logits = std::iter::once(0.0_f64).chain(theta.iter().copied());
            let max_logit = logits.clone().fold(f64::NEG_INFINITY, f64::max);
            let exp_shifted: Vec<f64> = logits.map(|l| (l - max_logit).exp()).collect();
            let z: f64 = exp_shifted.iter().sum();
            let probs: Vec<f64> = exp_shifted.iter().map(|e| e / z).collect();
            let h_direct: f64 = probs.iter().map(|p| -p * p.ln()).sum();

            assert!(
                (h_eml - h_direct).abs() < 1e-10,
                "H({:?}) eml={} direct={}", theta, h_eml, h_direct
            );
        }
    }

    // ── Gated Linear Units (iter-81) ──────────────────────────────

    #[test]
    fn closure_glu_at_zero_gate_is_half_x() {
        // GLU(x, 0) = x · σ(0) = x · 0.5 = x/2.
        for x in [-3.0_f64, -0.5, 1.0, 4.0] {
            let v = eval_with_slots(closure_glu(0, 1), vec![x, 0.0]);
            assert!((v - 0.5 * x).abs() < 1e-12, "GLU({}, 0) = {}", x, v);
        }
    }

    #[test]
    fn closure_glu_with_large_positive_gate_passes_through() {
        // GLU(x, g→∞) → x.
        for x in [-2.0_f64, 0.5, 3.0] {
            let v = eval_with_slots(closure_glu(0, 1), vec![x, 20.0]);
            assert!((v - x).abs() < 1e-6, "GLU({}, 20) = {}", x, v);
        }
    }

    #[test]
    fn closure_glu_with_large_negative_gate_zeros_out() {
        // GLU(x, g→-∞) → 0.
        for x in [-2.0_f64, 0.5, 3.0] {
            let v = eval_with_slots(closure_glu(0, 1), vec![x, -20.0]);
            assert!(v.abs() < 1e-6, "GLU({}, -20) = {}", x, v);
        }
    }

    #[test]
    fn closure_swiglu_matches_x_times_swish_gate() {
        // SwiGLU(x, g) ≡ x · swish(g).
        for x in [-2.0_f64, 0.0, 1.0, 3.0] {
            for g in [-3.0_f64, 0.0, 1.0, 3.0] {
                let v = eval_with_slots(closure_swiglu(0, 1), vec![x, g]);
                let swish_g = eval_with_slots(closure_swish(0), vec![g]);
                let expected = x * swish_g;
                assert!(
                    (v - expected).abs() < 1e-12,
                    "SwiGLU({}, {}) = {}; x·swish(g) = {}", x, g, v, expected
                );
            }
        }
    }

    #[test]
    fn closure_swiglu_at_zero_gate_is_zero() {
        // swish(0) = 0, so SwiGLU(x, 0) = 0 for any x.
        for x in [-2.0_f64, 1.0, 4.0] {
            let v = eval_with_slots(closure_swiglu(0, 1), vec![x, 0.0]);
            assert!(v.abs() < 1e-12, "SwiGLU({}, 0) = {}", x, v);
        }
    }

    #[test]
    fn closure_reglu_matches_x_times_softplus_gate() {
        // ReGLU(x, g) ≡ x · softplus(g).
        for x in [-2.0_f64, 0.0, 1.0, 3.0] {
            for g in [-3.0_f64, 0.0, 1.0, 3.0] {
                let v = eval_with_slots(closure_reglu(0, 1), vec![x, g]);
                let sp_g = (1.0_f64 + g.exp()).ln();
                let expected = x * sp_g;
                assert!(
                    (v - expected).abs() < 1e-12,
                    "ReGLU({}, {}) = {}; x·softplus(g) = {}", x, g, v, expected
                );
            }
        }
    }

    #[test]
    fn closure_reglu_with_large_negative_gate_zeros_out() {
        // softplus(-∞) → 0, so ReGLU(x, -∞) → 0.
        for x in [-2.0_f64, 1.0, 4.0] {
            let v = eval_with_slots(closure_reglu(0, 1), vec![x, -20.0]);
            assert!(v.abs() < 1e-6, "ReGLU({}, -20) = {}", x, v);
        }
    }

    #[test]
    fn closure_glu_swiglu_reglu_distinguish_on_unit_input() {
        // x=1, g=1: each gate produces a different value.
        let glu = eval_with_slots(closure_glu(0, 1), vec![1.0, 1.0]);
        let swiglu = eval_with_slots(closure_swiglu(0, 1), vec![1.0, 1.0]);
        let reglu = eval_with_slots(closure_reglu(0, 1), vec![1.0, 1.0]);

        // GLU(1, 1) = σ(1) ≈ 0.731
        // SwiGLU(1, 1) = 1 · swish(1) = 1·σ(1) ≈ 0.731
        // ReGLU(1, 1) = softplus(1) ≈ 1.313
        assert!((glu - 0.7310585786300049).abs() < 1e-10);
        assert!((swiglu - 0.7310585786300049).abs() < 1e-10);
        assert!((reglu - 1.3132616875182228).abs() < 1e-10);

        // GLU ≡ SwiGLU only when x=1 (since swish(g) = σ(g) · g, and
        // at x=1 the equality fails for g ≠ 1, but at x=g=1 the
        // values happen to coincide because swish(1) = σ(1)·1 = σ(1)).
        assert!((glu - swiglu).abs() < 1e-10);
        // ReGLU diverges from both.
        assert!(reglu > glu);
    }

    // ── Modern transformer activations (iter-80) ──────────────────

    #[test]
    fn closure_swish_at_zero_is_zero() {
        let v = eval_with_slots(closure_swish(0), vec![0.0]);
        assert!(v.abs() < 1e-12);
    }

    #[test]
    fn closure_swish_matches_x_times_sigmoid() {
        // swish(x) = x · σ(x) — compare against numerical sigmoid.
        for x in [-3.0_f64, -1.0, -0.5, 0.0, 0.5, 1.0, 3.0] {
            let v = eval_with_slots(closure_swish(0), vec![x]);
            let expected = x / (1.0 + (-x).exp());
            assert!(
                (v - expected).abs() < 1e-12,
                "swish({}) = {}; expected {}", x, v, expected
            );
        }
    }

    #[test]
    fn closure_swish_saturates_to_x_for_large_positive() {
        // swish(x) → x as x → ∞.
        let v = eval_with_slots(closure_swish(0), vec![20.0]);
        assert!((v - 20.0).abs() < 1e-6);
    }

    #[test]
    fn closure_swish_saturates_to_zero_for_large_negative() {
        // swish(x) → 0 as x → -∞.
        let v = eval_with_slots(closure_swish(0), vec![-20.0]);
        assert!(v.abs() < 1e-6);
    }

    #[test]
    fn closure_silu_is_swish_alias() {
        // Numerical equality across a grid.
        for x in [-2.0_f64, -0.3, 0.0, 0.3, 2.0] {
            let s = eval_with_slots(closure_swish(0), vec![x]);
            let u = eval_with_slots(closure_silu(0), vec![x]);
            assert!((s - u).abs() < 1e-12);
        }
    }

    #[test]
    fn closure_mish_at_zero_is_zero() {
        let v = eval_with_slots(closure_mish(0), vec![0.0]);
        assert!(v.abs() < 1e-12);
    }

    #[test]
    fn closure_mish_matches_x_tanh_softplus_grid() {
        // Reference computation: mish(x) = x · tanh(softplus(x))
        // with softplus and tanh from std.
        let softplus = |x: f64| (1.0 + x.exp()).ln();
        let tanh = |x: f64| x.tanh();
        for x in [-3.0_f64, -1.0, -0.25, 0.0, 0.25, 1.0, 3.0] {
            let v = eval_with_slots(closure_mish(0), vec![x]);
            let expected = x * tanh(softplus(x));
            assert!(
                (v - expected).abs() < 1e-10,
                "mish({}) = {}; expected {}", x, v, expected
            );
        }
    }

    #[test]
    fn closure_mish_saturates_to_x_for_large_positive() {
        let v = eval_with_slots(closure_mish(0), vec![10.0]);
        assert!((v - 10.0).abs() < 1e-3);
    }

    #[test]
    fn closure_smooth_relu_is_softplus_alias() {
        for x in [-2.0_f64, 0.0, 1.0, 3.0] {
            let s = eval_with_slots(closure_softplus(0), vec![x]);
            let r = eval_with_slots(closure_smooth_relu(0), vec![x]);
            assert!((s - r).abs() < 1e-12);
        }
    }

    // ── Cross-entropy / NLL primitives (iter-79) ──────────────────

    #[test]
    fn closure_cross_entropy_bernoulli_at_target_1_is_softplus_neg() {
        // y=1 → CE = softplus(-θ).
        for theta in [-3.0_f64, -0.5, 0.0, 0.7, 3.0] {
            let ce = eval_with_slots(
                closure_cross_entropy_bernoulli(0, 1),
                vec![1.0, theta],
            );
            // softplus(-θ) computed directly:
            let sp_neg = (1.0_f64 + (-theta).exp()).ln();
            assert!(
                (ce - sp_neg).abs() < 1e-12,
                "CE(y=1, θ={}) = {}; softplus(-θ) = {}", theta, ce, sp_neg
            );
        }
    }

    #[test]
    fn closure_cross_entropy_bernoulli_at_target_0_is_softplus_pos() {
        // y=0 → CE = softplus(θ).
        for theta in [-3.0_f64, -0.5, 0.0, 0.7, 3.0] {
            let ce = eval_with_slots(
                closure_cross_entropy_bernoulli(0, 1),
                vec![0.0, theta],
            );
            let sp_pos = (1.0_f64 + theta.exp()).ln();
            assert!(
                (ce - sp_pos).abs() < 1e-12,
                "CE(y=0, θ={}) = {}; softplus(θ) = {}", theta, ce, sp_pos
            );
        }
    }

    #[test]
    fn closure_cross_entropy_bernoulli_is_non_negative() {
        // CE ≥ 0 for any y ∈ [0,1] and θ ∈ ℝ.
        let cases = [
            (1.0_f64, 0.0),
            (0.0, 1.0),
            (0.5, 0.0),
            (0.7, 2.0),
            (0.3, -2.0),
            (1.0, 10.0), // confident-correct: CE ≈ 0
            (0.0, -10.0),
        ];
        for (y, theta) in cases {
            let ce = eval_with_slots(
                closure_cross_entropy_bernoulli(0, 1),
                vec![y, theta],
            );
            assert!(
                ce >= -1e-12,
                "CE(y={}, θ={}) = {} (must be ≥ 0)", y, theta, ce
            );
        }
    }

    #[test]
    fn closure_cross_entropy_bernoulli_matches_log_prob_decomposition() {
        // CE(y, θ) = -y·log P(X=1; θ) - (1-y)·log P(X=0; θ).
        for y in [0.0_f64, 0.3, 0.5, 0.7, 1.0] {
            for theta in [-2.0_f64, 0.0, 1.0] {
                let ce = eval_with_slots(
                    closure_cross_entropy_bernoulli(0, 1),
                    vec![y, theta],
                );
                let lp1 = eval_with_slots(
                    closure_bernoulli_log_prob_one(0),
                    vec![theta],
                );
                let lp0 = eval_with_slots(
                    closure_bernoulli_log_prob_zero(0),
                    vec![theta],
                );
                let expected = -y * lp1 - (1.0 - y) * lp0;
                assert!(
                    (ce - expected).abs() < 1e-12,
                    "CE(y={}, θ={}) = {}; -y·logP1 - (1-y)·logP0 = {}",
                    y, theta, ce, expected
                );
            }
        }
    }

    #[test]
    fn closure_nll_categorical_slot_at_uniform_is_ln_k() {
        // At θ=0, NLL for any class = -log(1/k) = ln(k).
        let slots = [0_u32, 1];
        let nll = eval_with_slots(
            closure_neg_log_likelihood_categorical_slot(0, &slots),
            vec![0.0, 0.0],
        );
        assert!((nll - 3.0_f64.ln()).abs() < 1e-12, "NLL = {} for k=3 uniform", nll);
    }

    #[test]
    fn closure_nll_categorical_pinned_at_uniform_is_ln_k() {
        let slots = [0_u32, 1];
        let nll = eval_with_slots(
            closure_neg_log_likelihood_categorical_pinned(&slots),
            vec![0.0, 0.0],
        );
        assert!((nll - 3.0_f64.ln()).abs() < 1e-12, "pinned NLL = {} at uniform", nll);
    }

    #[test]
    fn closure_nll_categorical_decreases_with_target_logit() {
        // NLL(target, θ) decreases monotonically as θ_target increases.
        let slots = [0_u32, 1];
        let nll_low = eval_with_slots(
            closure_neg_log_likelihood_categorical_slot(0, &slots),
            vec![-2.0, 0.0],
        );
        let nll_mid = eval_with_slots(
            closure_neg_log_likelihood_categorical_slot(0, &slots),
            vec![0.0, 0.0],
        );
        let nll_high = eval_with_slots(
            closure_neg_log_likelihood_categorical_slot(0, &slots),
            vec![3.0, 0.0],
        );
        assert!(nll_low > nll_mid);
        assert!(nll_mid > nll_high);
        assert!(nll_high > 0.0);
    }

    #[test]
    fn closure_nll_categorical_matches_neg_log_prob() {
        // NLL ≡ -log P for each class slot.
        let slots = [0_u32, 1];
        for theta in [vec![1.0_f64, -1.0], vec![0.0, 0.0], vec![-2.0, 3.0]] {
            for &slot in &slots {
                let nll = eval_with_slots(
                    closure_neg_log_likelihood_categorical_slot(slot, &slots),
                    theta.clone(),
                );
                let lp = eval_with_slots(
                    closure_categorical_log_prob_slot(slot, &slots),
                    theta.clone(),
                );
                assert!(
                    (nll + lp).abs() < 1e-12,
                    "slot {} at {:?}: NLL = {}, -log P = {}", slot, theta, nll, -lp
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
