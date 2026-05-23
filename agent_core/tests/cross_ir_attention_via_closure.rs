//! Source:
//! - Vaswani et al. 2017 "Attention Is All You Need" §3.2.1 —
//!   scaled-dot-product attention:
//!     attention(Q, K, V) = softmax(QK^T / √d_k) · V
//! - Doctrine `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md`
//!   §6 — primitive-stack composition.
//! - Companion to iters 93-96 cross-IR arrow integration tests.
//!
//! # Composition: full attention head from closure-form primitives
//!
//! Demonstrates that a complete scaled-dot-product attention head
//! can be expressed by composing:
//!
//! - `closure_attention_score(q, k, 1/√d)` (iter-98) → per-key
//!   pre-softmax scores.
//! - `closure_categorical_softmax_slot/pinned` (iter-73) →
//!   attention weights (one per key position).
//! - Weighted sum of value vectors via the softmax weights.
//!
//! Iter-100 milestone — celebrates the EML-IR closure-form
//! Primitive Stack reaching the composition depth where modern
//! transformer attention is a single algebraic expression.

#![cfg(feature = "research")]

use agent_core::research::eml::{
    closure_attention_score, closure_categorical_softmax_pinned,
    closure_categorical_softmax_slot, evaluate_closure, EmlClosure,
};

/// Evaluate a closure tree against a flat slot vector.
fn eval(tree: agent_core::research::eml::EmlClosureExpr, slots: Vec<f64>) -> f64 {
    let c = EmlClosure::new(tree, slots).unwrap();
    evaluate_closure(&c).unwrap()
}

/// Build slot vector layout for a 3-key attention head with d_k = 2:
/// [
///   q_0, q_1,                        // 0, 1: query (2 dims)
///   k_0a, k_0b, k_1a, k_1b, k_2a, k_2b,  // 2-7: 3 keys (2 dims each)
///   inv_sqrt_d,                      // 8
///   score_0, score_1, score_2,       // 9, 10, 11: pre-stored scores
/// ]
struct AttnLayout;
impl AttnLayout {
    const Q_SLOTS: [u32; 2] = [0, 1];
    const K_SLOTS_PER_KEY: [[u32; 2]; 3] = [[2, 3], [4, 5], [6, 7]];
    const INV_SQRT_D: u32 = 8;
    const SCORE_SLOTS: [u32; 3] = [9, 10, 11];
}

#[test]
fn attention_score_composes_per_key() {
    // Single attention-score evaluation, key-by-key.
    let q = vec![1.0_f64, 0.0];
    let keys = [
        vec![1.0_f64, 0.0],  // aligned with q
        vec![0.0, 1.0],      // orthogonal
        vec![-1.0, 0.0],     // anti-aligned
    ];
    let inv_sqrt_d = 1.0 / 2.0_f64.sqrt();

    let mut slot_vec = q.clone();
    for k in &keys {
        slot_vec.extend_from_slice(k);
    }
    slot_vec.push(inv_sqrt_d);

    for (i, k_slots) in AttnLayout::K_SLOTS_PER_KEY.iter().enumerate() {
        let tree = closure_attention_score(&AttnLayout::Q_SLOTS, k_slots, AttnLayout::INV_SQRT_D);
        let score = eval(tree, slot_vec.clone());
        // q·k_i / √d.
        let expected_dot: f64 = q.iter().zip(keys[i].iter()).map(|(a, b)| a * b).sum();
        let expected_score = expected_dot * inv_sqrt_d;
        assert!(
            (score - expected_score).abs() < 1e-12,
            "key {}: score = {}; expected {}", i, score, expected_score
        );
    }
}

#[test]
fn attention_weights_from_softmax_sum_to_one() {
    // Compute 3 attention scores, feed them into the temperature
    // softmax with β=1 (Categorical k=3 with the first 2 scores
    // treated as natural-param slots; the 3rd is the pinned class).
    //
    // Note: Categorical softmax with k=3 takes only 2 natural-param
    // slots; the 3rd class is pinned at θ=0. To express a true
    // 3-key softmax, we treat one of the scores as the "reference"
    // and subtract it from the other two (effectively re-pinning).
    //
    // For this test we'll directly verify the softmax-over-2-slots
    // simplex closure (the 3rd "score" becomes the pinned class).

    let scores = vec![1.0_f64, 0.5];
    let p0 = eval(
        closure_categorical_softmax_slot(0, &[0, 1]),
        scores.clone(),
    );
    let p1 = eval(
        closure_categorical_softmax_slot(1, &[0, 1]),
        scores.clone(),
    );
    let pp = eval(
        closure_categorical_softmax_pinned(&[0, 1]),
        scores.clone(),
    );

    let sum = p0 + p1 + pp;
    assert!((sum - 1.0).abs() < 1e-12, "softmax probs sum = {}", sum);
}

#[test]
fn attention_weights_concentrate_on_aligned_key() {
    // q · k_0 is large; q · k_1 small; q · k_2 negative.
    // Softmax concentrates probability on the aligned key.
    let scores = vec![3.0_f64, 0.0]; // slot 0 wins
    let p0 = eval(
        closure_categorical_softmax_slot(0, &[0, 1]),
        scores.clone(),
    );
    let pinned = eval(closure_categorical_softmax_pinned(&[0, 1]), scores);
    assert!(p0 > pinned);
    assert!(p0 > 0.6);
}

#[test]
fn attention_head_end_to_end_3_keys_2_values_2_dims() {
    // Realistic mini attention head:
    // - 3 key/value positions (one is the pinned reference).
    // - 2-dim keys/values.
    // - d_k = 2 → 1/√d = 1/√2.
    //
    // Compute scores, softmax probs, then weighted sum of values.
    let q = vec![1.0_f64, 0.0];
    let keys = [
        vec![1.0_f64, 0.0], // slot 0
        vec![0.0, 1.0],     // slot 1
        vec![0.0, 0.0],     // pinned (q·k = 0 baseline)
    ];
    let values = [
        vec![1.0_f64, 0.0],
        vec![0.0, 1.0],
        vec![0.5, 0.5],
    ];
    let inv_sqrt_d = 1.0 / 2.0_f64.sqrt();

    // Compute scores.
    let mut slot_vec_score = q.clone();
    slot_vec_score.extend_from_slice(&keys[0]);
    slot_vec_score.extend_from_slice(&keys[1]);
    slot_vec_score.extend_from_slice(&keys[2]);
    slot_vec_score.push(inv_sqrt_d);

    let score_0 = eval(
        closure_attention_score(&[0, 1], &[2, 3], 8),
        slot_vec_score.clone(),
    );
    let score_1 = eval(
        closure_attention_score(&[0, 1], &[4, 5], 8),
        slot_vec_score.clone(),
    );
    // score_2 is the pinned-key score (q · 0 = 0, so this is 0 by construction).

    // Now softmax over [score_0, score_1] with pinned=score_2=0.
    let p0 = eval(
        closure_categorical_softmax_slot(0, &[0, 1]),
        vec![score_0, score_1],
    );
    let p1 = eval(
        closure_categorical_softmax_slot(1, &[0, 1]),
        vec![score_0, score_1],
    );
    let pp = eval(
        closure_categorical_softmax_pinned(&[0, 1]),
        vec![score_0, score_1],
    );

    // Weighted sum: y = p_0 · v_0 + p_1 · v_1 + p_pinned · v_pinned.
    let y_a = p0 * values[0][0] + p1 * values[1][0] + pp * values[2][0];
    let y_b = p0 * values[0][1] + p1 * values[1][1] + pp * values[2][1];

    // Sanity invariants:
    // 1. y is a convex combination of the value vectors.
    // 2. y_a + y_b = p0·1 + p1·1 + pp·1 = 1 (since each value sums to 1).
    let sum_components = y_a + y_b;
    assert!(
        (sum_components - 1.0).abs() < 1e-10,
        "Σ y = {} ≠ 1 — softmax weights don't sum correctly", sum_components
    );

    // 3. y_a is dominated by the aligned key/value pair.
    // q=(1,0) aligns with k_0=(1,0); v_0=(1,0). Score 0 is highest.
    // So y should be biased toward v_0, meaning y_a > y_b.
    assert!(y_a > y_b, "y_a = {}, y_b = {}: aligned key should win", y_a, y_b);
}

#[test]
fn attention_weights_uniform_at_zero_scores() {
    // All scores = 0 → uniform attention.
    let p0 = eval(
        closure_categorical_softmax_slot(0, &[0, 1]),
        vec![0.0, 0.0],
    );
    let p1 = eval(
        closure_categorical_softmax_slot(1, &[0, 1]),
        vec![0.0, 0.0],
    );
    let pp = eval(
        closure_categorical_softmax_pinned(&[0, 1]),
        vec![0.0, 0.0],
    );
    // Each probability = 1/3.
    for p in [p0, p1, pp] {
        assert!((p - 1.0 / 3.0).abs() < 1e-12);
    }
}

#[test]
fn attention_temperature_high_inv_sqrt_d_sharpens() {
    // Larger inv_sqrt_d (smaller d_k, equivalently higher β) →
    // sharper attention. Compare with inv_sqrt_d = 2 (sharp) vs
    // inv_sqrt_d = 0.1 (soft).
    let q = vec![1.0_f64, 0.0];
    let keys = [
        vec![2.0_f64, 0.0],
        vec![0.0, 2.0],
    ];

    // Sharp: scale = 2.0.
    let slot_sharp = vec![q[0], q[1], keys[0][0], keys[0][1], keys[1][0], keys[1][1], 2.0];
    let s0_sharp = eval(closure_attention_score(&[0, 1], &[2, 3], 6), slot_sharp.clone());
    let s1_sharp = eval(closure_attention_score(&[0, 1], &[4, 5], 6), slot_sharp);
    let p0_sharp = eval(
        closure_categorical_softmax_slot(0, &[0, 1]),
        vec![s0_sharp, s1_sharp],
    );

    // Soft: scale = 0.1.
    let slot_soft = vec![q[0], q[1], keys[0][0], keys[0][1], keys[1][0], keys[1][1], 0.1];
    let s0_soft = eval(closure_attention_score(&[0, 1], &[2, 3], 6), slot_soft.clone());
    let s1_soft = eval(closure_attention_score(&[0, 1], &[4, 5], 6), slot_soft);
    let p0_soft = eval(
        closure_categorical_softmax_slot(0, &[0, 1]),
        vec![s0_soft, s1_soft],
    );

    // Sharp gets more probability mass on key 0 (the aligned one).
    assert!(
        p0_sharp > p0_soft,
        "sharp p0 = {} should > soft p0 = {}", p0_sharp, p0_soft
    );
}
