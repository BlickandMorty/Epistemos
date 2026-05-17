//! Source:
//! - Doctrine `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md`
//!   §6.2 row 7 — Tropical-IR → Scan-IR composition arrow.
//! - Companion to `tests/cross_ir_operator_to_scan.rs` (iter-93,
//!   arrow #1) and earlier EML cross-IR tests.
//!
//! # Composition: TropicalExpr trees as scan step combinators
//!
//! Given a `TropicalExpr` tree T with 2 variables (var(0) = state,
//! var(1) = input), composing with `sequential_scan` produces a
//! running tropical-semiring reduction:
//!
//! ```text
//! state_{t+1} = evaluate(T, &[state_t, input_t])
//! ```
//!
//! When T = `max(var(0), var(1))`, this is a running tropical-max.
//! When T = `var(0) + var(1)` (Plus, the tropical multiplication),
//! this is a running tropical-product.
//! When T is more complex (e.g. a compiled ReLU-layer tree), the
//! scan applies that entire network at each step.
//!
//! Iter-94 — promotes lattice arrow #7 (Tropical → Scan) from
//! "code-pattern composable" to "wired with integration test".

#![cfg(feature = "research")]

use agent_core::research::scan_ir::{sequential_scan, ScanProgram};
use agent_core::research::tropical_ir::{evaluate, TropicalExpr};

#[test]
fn tropical_scan_running_max_via_tree() {
    // T = max(var(0), var(1)) → running max.
    let tree = TropicalExpr::max(vec![TropicalExpr::var(0), TropicalExpr::var(1)]);
    let prog = ScanProgram::new(0.0_f64, vec![3.0, 1.5, 5.0, 2.0, 4.0]);
    let out = sequential_scan(&prog, |state, input| {
        evaluate(&tree, &[*state, *input]).unwrap()
    });
    assert_eq!(out, vec![0.0, 3.0, 3.0, 5.0, 5.0, 5.0]);
}

#[test]
fn tropical_scan_running_plus_via_tree() {
    // T = Plus(var(0), var(1)) is tropical multiplication = ordinary +.
    // → running cumulative sum.
    let tree = TropicalExpr::plus(TropicalExpr::var(0), TropicalExpr::var(1));
    let prog = ScanProgram::new(0.0_f64, vec![1.0, 2.0, 3.0, 4.0]);
    let out = sequential_scan(&prog, |state, input| {
        evaluate(&tree, &[*state, *input]).unwrap()
    });
    assert_eq!(out, vec![0.0, 1.0, 3.0, 6.0, 10.0]);
}

#[test]
fn tropical_scan_compound_tree_max_plus_constant() {
    // T = max(var(0), Plus(var(1), Const(0.5)))
    // i.e. running max of (state, input + 0.5).
    let tree = TropicalExpr::max(vec![
        TropicalExpr::var(0),
        TropicalExpr::plus(TropicalExpr::var(1), TropicalExpr::constant(0.5)),
    ]);
    let prog = ScanProgram::new(0.0_f64, vec![1.0, -0.7, 3.0, 0.0]);
    let out = sequential_scan(&prog, |state, input| {
        evaluate(&tree, &[*state, *input]).unwrap()
    });
    // step 0: 0.0
    // step 1: max(0.0, 1.0 + 0.5) = 1.5
    // step 2: max(1.5, -0.7 + 0.5) = 1.5
    // step 3: max(1.5, 3.0 + 0.5) = 3.5
    // step 4: max(3.5, 0.0 + 0.5) = 3.5
    assert_eq!(out, vec![0.0, 1.5, 1.5, 3.5, 3.5]);
}

#[test]
fn tropical_scan_matches_running_max_helper() {
    // Cross-validate: tropical-tree scan ≡ scan_ir::running_max
    // when the tree is max(var(0), var(1)).
    use agent_core::research::scan_ir::running_max;

    let inputs = vec![1.5_f64, 3.0, 0.5, 2.0, 4.5];
    let prog = ScanProgram::new(0.0_f64, inputs.clone());

    let tree = TropicalExpr::max(vec![TropicalExpr::var(0), TropicalExpr::var(1)]);
    let tropical_out = sequential_scan(&prog, |state, input| {
        evaluate(&tree, &[*state, *input]).unwrap()
    });

    let helper_out = running_max(&prog);
    assert_eq!(tropical_out, helper_out);
}

#[test]
fn tropical_scan_scale_in_tree() {
    // T = Scale(2.0, var(1)) — double the input ignoring state.
    // (Scale is iter-61 Phase C extension.)
    let tree = TropicalExpr::scale(2.0, TropicalExpr::var(1));
    let prog = ScanProgram::new(0.0_f64, vec![1.5, 2.5, -1.0]);
    let out = sequential_scan(&prog, |state, input| {
        evaluate(&tree, &[*state, *input]).unwrap()
    });
    // step 0: 0.0
    // step 1: 2·1.5 = 3.0
    // step 2: 2·2.5 = 5.0
    // step 3: 2·(-1) = -2.0
    assert_eq!(out, vec![0.0, 3.0, 5.0, -2.0]);
}

#[test]
fn tropical_scan_running_relu_max_plus_zero() {
    // Tropical max(var(0), Const(0)) ≡ ReLU on state.
    // Combined with an additive input update: state' = max(state + x, 0).
    let tree = TropicalExpr::max(vec![
        TropicalExpr::plus(TropicalExpr::var(0), TropicalExpr::var(1)),
        TropicalExpr::constant(0.0),
    ]);
    let prog = ScanProgram::new(0.0_f64, vec![2.0, -3.0, 1.0, -5.0, 4.0]);
    let out = sequential_scan(&prog, |state, input| {
        evaluate(&tree, &[*state, *input]).unwrap()
    });
    // step 0: 0
    // step 1: max(0 + 2, 0) = 2
    // step 2: max(2 + (-3), 0) = 0  (ReLU clips negative)
    // step 3: max(0 + 1, 0) = 1
    // step 4: max(1 + (-5), 0) = 0  (clip again)
    // step 5: max(0 + 4, 0) = 4
    assert_eq!(out, vec![0.0, 2.0, 0.0, 1.0, 0.0, 4.0]);
}

#[test]
fn tropical_scan_min_via_tree_iter_87() {
    // T = min(var(0), var(1)) — uses iter-87's TropicalExpr::min
    // (which encodes min as -max(-x)).
    let tree = TropicalExpr::min(vec![TropicalExpr::var(0), TropicalExpr::var(1)]);
    let prog = ScanProgram::new(10.0_f64, vec![5.0, 7.0, 3.0, 8.0]);
    let out = sequential_scan(&prog, |state, input| {
        evaluate(&tree, &[*state, *input]).unwrap()
    });
    // Running min from initial=10.
    // step 0: 10
    // step 1: min(10, 5) = 5
    // step 2: min(5, 7) = 5
    // step 3: min(5, 3) = 3
    // step 4: min(3, 8) = 3
    assert_eq!(out, vec![10.0, 5.0, 5.0, 3.0, 3.0]);
}
