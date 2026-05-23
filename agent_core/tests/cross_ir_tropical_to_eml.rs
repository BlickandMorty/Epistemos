//! Source:
//! - Doctrine `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md`
//!   §6.2 row 6 — Tropical-IR → EML-IR composition arrow.
//! - `docs/fusion/CROSS_IR_COMPOSITION_EXAMPLES_2026_05_17.md` §6 —
//!   sketch for this arrow ("Smoothmax `softmax_β(x) = (1/β)·log(Σ
//!   exp(β·x))` — direct EML composition. As `β → ∞` it converges
//!   to the tropical `max`.").
//! - Companion to `tests/cross_ir_info_to_eml.rs` (iter-59) which
//!   wires the Info → EML arrow with the same Plus/Minus/Eml
//!   closure-form pattern.
//!
//! # Composition: softmax via EML closure-form
//!
//! For two-argument log-sum-exp at β = 1:
//!
//! ```text
//! lse(a, b) = ln(exp(a) + exp(b))
//!
//! exp(a)   = eml(Slot(0), One)            [eml(x, 1) = exp(x) - 0]
//! exp(b)   = eml(Slot(1), One)
//! sum      = Plus(eml(0, One), eml(1, One))
//! ln(y)    = Minus(One, eml(0, y))        [eml(0, y) = 1 - ln(y)]
//! lse(a,b) = Minus(One, eml(Minus(One, One),
//!                           Plus(eml(Slot(0), One), eml(Slot(1), One))))
//! ```
//!
//! Numerical agreement test: this lse-via-EML matches Rust's
//! `(a.exp() + b.exp()).ln()` to 1e-12.
//!
//! Tropical-limit test: log-sum-exp at large β (scaling: lse(βa, βb)/β)
//! converges to Tropical-IR's max(a, b).

#![cfg(feature = "research")]

use agent_core::research::eml::{evaluate_closure, EmlClosure, EmlClosureExpr};
use agent_core::research::tropical_ir::{evaluate as tropical_evaluate, TropicalExpr};

/// Build EmlClosureExpr computing `lse(Slot(0), Slot(1))` = ln(exp(Slot(0)) + exp(Slot(1))).
fn lse_closure_tree() -> EmlClosureExpr {
    let zero = EmlClosureExpr::minus(EmlClosureExpr::one(), EmlClosureExpr::one());
    let exp_a = EmlClosureExpr::eml(EmlClosureExpr::slot(0), EmlClosureExpr::one());
    let exp_b = EmlClosureExpr::eml(EmlClosureExpr::slot(1), EmlClosureExpr::one());
    let sum = EmlClosureExpr::plus(exp_a, exp_b);
    let eml_zero_sum = EmlClosureExpr::eml(zero, sum);
    EmlClosureExpr::minus(EmlClosureExpr::one(), eml_zero_sum)
}

fn lse_via_eml(a: f64, b: f64) -> f64 {
    let c = EmlClosure::new(lse_closure_tree(), vec![a, b]).unwrap();
    evaluate_closure(&c).unwrap()
}

fn lse_reference(a: f64, b: f64) -> f64 {
    (a.exp() + b.exp()).ln()
}

#[test]
fn lse_via_eml_matches_reference_at_zero_zero() {
    // lse(0, 0) = ln(2).
    let v = lse_via_eml(0.0, 0.0);
    assert!((v - 2.0_f64.ln()).abs() < 1e-12);
}

#[test]
fn lse_via_eml_matches_reference_symmetric() {
    let v = lse_via_eml(1.0, 1.0);
    let r = lse_reference(1.0, 1.0);
    assert!((v - r).abs() < 1e-12);
}

#[test]
fn lse_via_eml_matches_reference_at_signed_grid() {
    let pairs = [
        (1.0_f64, 0.0),
        (0.0, 1.0),
        (-1.0, 2.0),
        (2.0, -1.0),
        (-3.0, -2.0),
        (0.5, 0.5),
    ];
    for &(a, b) in &pairs {
        let v = lse_via_eml(a, b);
        let r = lse_reference(a, b);
        assert!(
            (v - r).abs() < 1e-12,
            "lse({}, {}): eml={} ref={}", a, b, v, r
        );
    }
}

#[test]
fn lse_via_eml_is_ge_max() {
    // log-sum-exp(a, b) ≥ max(a, b) (it adds a positive correction).
    let pairs = [
        (1.0_f64, 0.0),
        (-1.0, 2.0),
        (3.0, -3.0),
    ];
    for &(a, b) in &pairs {
        let lse = lse_via_eml(a, b);
        let m = a.max(b);
        assert!(lse >= m - 1e-12, "lse {} should be ≥ max {}", lse, m);
    }
}

#[test]
fn scaled_lse_converges_to_tropical_max_at_large_beta() {
    // lse(βa, βb)/β → max(a, b) as β → ∞.
    let pairs: Vec<(f64, f64)> = vec![
        (1.0_f64, 0.0),
        (0.5, 0.5),
        (-1.0, 2.0),
        (3.0, -3.0),
    ];
    let betas = [1.0_f64, 10.0, 100.0];
    for &(a, b) in &pairs {
        // Tropical-IR computes max(a, b) exactly.
        let tropical_max = tropical_evaluate(
            &TropicalExpr::max(vec![
                TropicalExpr::constant(a),
                TropicalExpr::constant(b),
            ]),
            &[],
        )
        .unwrap();

        // Track that the residual |scaled_lse - max| shrinks
        // monotonically as β increases.
        let mut prev_residual = f64::INFINITY;
        for &beta in &betas {
            let scaled = lse_via_eml(beta * a, beta * b) / beta;
            let residual = (scaled - tropical_max).abs();
            assert!(
                residual <= prev_residual + 1e-12,
                "non-monotone β={} (a,b)=({},{}): residual {} > prev {}",
                beta, a, b, residual, prev_residual
            );
            prev_residual = residual;
        }
        // At β=100 the residual should already be very small unless a=b.
        let scaled_100 = lse_via_eml(100.0 * a, 100.0 * b) / 100.0;
        let residual_100 = (scaled_100 - tropical_max).abs();
        if (a - b).abs() > 1e-3 {
            assert!(
                residual_100 < 0.1,
                "β=100 residual too large for distinct args (a,b)=({},{}): {}", a, b, residual_100
            );
        }
    }
}

#[test]
fn lse_via_eml_handles_large_negative_inputs() {
    // lse(-20, -20) = ln(2 * exp(-20)) = ln 2 - 20.
    let v = lse_via_eml(-20.0, -20.0);
    let expected = 2.0_f64.ln() - 20.0;
    assert!(
        (v - expected).abs() < 1e-9,
        "lse(-20, -20) = {}; expected {}", v, expected
    );
}

#[test]
fn lse_closure_tree_uses_two_slots() {
    let tree = lse_closure_tree();
    assert_eq!(tree.max_slot(), Some(1));
}

#[test]
fn lse_closure_tree_has_expected_depth() {
    // outer Minus
    //  ├ One
    //  └ Eml
    //     ├ Minus(One, One) [zero]
    //     └ Plus
    //        ├ Eml(Slot(0), One)
    //        └ Eml(Slot(1), One)
    // depth = 4 (outer Minus + Eml + Plus + inner Eml leaves)
    let tree = lse_closure_tree();
    assert_eq!(tree.depth(), 4);
}
