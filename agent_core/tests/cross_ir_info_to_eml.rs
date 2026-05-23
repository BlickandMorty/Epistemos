//! Source:
//! - Doctrine `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md`
//!   §6.2 row 5 — Info-IR → EML-IR composition arrow. Bernoulli's
//!   log-partition `A(θ) = ln(1 + exp(θ))` decomposes through EML's
//!   `eml(x, y) = exp(x) − ln(y)` primitive plus the closure-form
//!   Plus + Minus extensions (iter-57 + iter-58).
//! - `docs/fusion/CROSS_IR_COMPOSITION_EXAMPLES_2026_05_17.md`
//!   §5 — sketch for this arrow; this test makes the realization
//!   concrete.
//! - Amari (Springer 2016) Ch. 2 — log-partition definition.
//!
//! # Composition: softplus(θ) via EML closure-form
//!
//! The identity used:
//!
//! ```text
//! eml(0, y)              = exp(0) − ln(y)        = 1 − ln(y)
//! ⇒  ln(y)               = 1 − eml(0, y)         = Minus(One, eml(0, y))
//!
//! exp(θ)                 = exp(θ) − ln(1)        = eml(θ, 1)
//! 1 + exp(θ)             = Plus(One, eml(θ, 1))
//!
//! ⇒  softplus(θ) = ln(1 + exp(θ))
//!                = 1 − eml(0, 1 + exp(θ))
//!                = Minus(One, eml(0, Plus(One, eml(θ, One))))
//! ```
//!
//! The 0 leaf is encoded as `Minus(One, One)`. The full closure-form
//! expression evaluates to the same `f64` as Info-IR's direct
//! `log_partition(Bernoulli, [θ])`.

#![cfg(feature = "research")]

use agent_core::research::eml::{evaluate_closure, EmlClosure, EmlClosureExpr};
use agent_core::research::info_ir::{log_partition, ExpFamily};

/// Build the EmlClosureExpr for `softplus(Slot(0))`.
fn softplus_closure_tree() -> EmlClosureExpr {
    // 0 = 1 - 1
    let zero = EmlClosureExpr::minus(EmlClosureExpr::one(), EmlClosureExpr::one());
    // exp(θ) = eml(Slot(0), 1)
    let exp_theta =
        EmlClosureExpr::eml(EmlClosureExpr::slot(0), EmlClosureExpr::one());
    // 1 + exp(θ)
    let one_plus_exp = EmlClosureExpr::plus(EmlClosureExpr::one(), exp_theta);
    // eml(0, 1 + exp(θ)) = 1 - ln(1 + exp(θ))
    let eml_zero_x = EmlClosureExpr::eml(zero, one_plus_exp);
    // softplus = 1 - eml(0, 1 + exp(θ)) = ln(1 + exp(θ))
    EmlClosureExpr::minus(EmlClosureExpr::one(), eml_zero_x)
}

fn softplus_via_eml(theta: f64) -> f64 {
    let c = EmlClosure::new(softplus_closure_tree(), vec![theta]).unwrap();
    evaluate_closure(&c).unwrap()
}

#[test]
fn softplus_via_eml_matches_info_ir_at_zero() {
    // softplus(0) = ln 2 ≈ 0.6931.
    let via_eml = softplus_via_eml(0.0);
    let via_info = log_partition(&ExpFamily::Bernoulli, &[0.0]);
    assert!(
        (via_eml - via_info).abs() < 1e-12,
        "softplus(0): eml={} info_ir={}", via_eml, via_info
    );
}

#[test]
fn softplus_via_eml_matches_info_ir_at_one() {
    // softplus(1) = ln(1 + e) ≈ 1.3133.
    let via_eml = softplus_via_eml(1.0);
    let via_info = log_partition(&ExpFamily::Bernoulli, &[1.0]);
    assert!(
        (via_eml - via_info).abs() < 1e-12,
        "softplus(1): eml={} info_ir={}", via_eml, via_info
    );
}

#[test]
fn softplus_via_eml_matches_info_ir_at_negative() {
    // softplus(-1) = ln(1 + e^-1) ≈ 0.3133.
    let via_eml = softplus_via_eml(-1.0);
    let via_info = log_partition(&ExpFamily::Bernoulli, &[-1.0]);
    assert!(
        (via_eml - via_info).abs() < 1e-12,
        "softplus(-1): eml={} info_ir={}", via_eml, via_info
    );
}

#[test]
fn softplus_via_eml_matches_info_ir_across_grid() {
    // Cross-IR composition acceptance: bit-equality across a grid
    // of θ values demonstrates that doctrine §6.2 arrow #5 is
    // wired correctly through the closure-form Plus/Minus extensions.
    let thetas = [-3.0, -1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5, 3.0];
    for theta in thetas {
        let via_eml = softplus_via_eml(theta);
        let via_info = log_partition(&ExpFamily::Bernoulli, &[theta]);
        assert!(
            (via_eml - via_info).abs() < 1e-12,
            "softplus({}): eml={} info_ir={}", theta, via_eml, via_info
        );
    }
}

#[test]
fn softplus_closure_tree_has_expected_shape() {
    let tree = softplus_closure_tree();
    // Outer: Minus(One, Eml(Minus(One, One), Plus(One, Eml(Slot(0), One))))
    match tree {
        EmlClosureExpr::Minus(l, r) => {
            assert_eq!(*l, EmlClosureExpr::One);
            match *r {
                EmlClosureExpr::Eml(zl, zr) => {
                    // Inner left = Minus(One, One) [the encoded 0]
                    match *zl {
                        EmlClosureExpr::Minus(ll, lr) => {
                            assert_eq!(*ll, EmlClosureExpr::One);
                            assert_eq!(*lr, EmlClosureExpr::One);
                        }
                        other => panic!("expected Minus(One, One) for zero, got {:?}", other),
                    }
                    // Inner right = Plus(One, Eml(Slot(0), One))
                    match *zr {
                        EmlClosureExpr::Plus(pl, pr) => {
                            assert_eq!(*pl, EmlClosureExpr::One);
                            match *pr {
                                EmlClosureExpr::Eml(el, er) => {
                                    assert_eq!(*el, EmlClosureExpr::Slot(0));
                                    assert_eq!(*er, EmlClosureExpr::One);
                                }
                                other => panic!("expected eml(Slot, One), got {:?}", other),
                            }
                        }
                        other => panic!("expected Plus(One, ...), got {:?}", other),
                    }
                }
                other => panic!("expected Eml(0, 1+exp), got {:?}", other),
            }
        }
        other => panic!("expected Minus(One, ...) outer, got {:?}", other),
    }
}

#[test]
fn softplus_via_eml_preserves_monotonicity() {
    // softplus is monotone increasing.
    let thetas = [-3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0];
    let values: Vec<f64> = thetas.iter().map(|&t| softplus_via_eml(t)).collect();
    for w in values.windows(2) {
        assert!(w[0] < w[1], "softplus monotonicity broken: {:?}", values);
    }
}

#[test]
fn softplus_via_eml_at_large_negative_is_near_zero() {
    // softplus(θ) → 0 as θ → -∞.
    let v = softplus_via_eml(-20.0);
    assert!(v.abs() < 1e-8, "softplus(-20) = {}", v);
}

#[test]
fn softplus_via_eml_at_large_positive_is_near_theta() {
    // softplus(θ) ≈ θ for large positive θ.
    let theta = 20.0_f64;
    let v = softplus_via_eml(theta);
    assert!(
        (v - theta).abs() < 1e-8,
        "softplus(20) = {}; should be ≈ 20", v
    );
}
