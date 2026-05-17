//! Source:
//! - Doctrine `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md`
//!   §6.2 row 1 — Operator-IR → Scan-IR composition arrow.
//! - Companion to `tests/cross_ir_info_to_eml.rs` (iter-59) and
//!   `tests/cross_ir_tropical_to_eml.rs` (iter-63).
//!
//! # Composition: recurrent linear transform via Scan
//!
//! Given a `LinearNetwork` L : ℝ^n → ℝ^n and a sequence of input
//! vectors `x_0, x_1, …, x_{T-1}`, the Operator → Scan composition
//! defines a stateful update:
//!
//! ```text
//! state_{t+1} = L(state_t + x_t)
//! ```
//!
//! which is the canonical 1-layer RNN cell: `s' = W(s + x) + b`.
//! `sequential_scan` provides the loop driver; `evaluate_linear`
//! provides the per-step operator.
//!
//! This wires the Operator → Scan lattice arrow (doctrine §6.2
//! row 1) from "code-pattern" status to "wired with integration
//! test" — closing iter-93's Phase C extension.
//!
//! Iter-93 — first cross-IR integration test that doesn't
//! involve EML on either side.

#![cfg(feature = "research")]

use agent_core::research::operator_ir::{evaluate_linear, LinearNetwork};
use agent_core::research::scan_ir::{sequential_scan, ScanProgram};

/// Build a square 2×2 LinearNetwork: `y = W·x + b`.
fn linear_2x2(weights: Vec<Vec<f64>>, biases: Vec<f64>) -> LinearNetwork {
    LinearNetwork::new(weights, biases).expect("valid 2×2 linear layer")
}

/// Build an n×n LinearNetwork.
fn linear_nxn(n: usize, weights: Vec<Vec<f64>>, biases: Vec<f64>) -> LinearNetwork {
    assert_eq!(weights.len(), n);
    for row in &weights {
        assert_eq!(row.len(), n);
    }
    assert_eq!(biases.len(), n);
    LinearNetwork::new(weights, biases).expect("valid n×n linear layer")
}

#[test]
fn recurrent_linear_scan_first_output_is_initial_state() {
    // Initial state propagates as the first scan output.
    let layer = linear_2x2(
        vec![vec![1.0, 0.0], vec![0.0, 1.0]], // identity
        vec![0.0, 0.0],
    );
    let prog = ScanProgram::new(vec![3.0, 5.0], vec![vec![0.0, 0.0]]);
    let out = sequential_scan(&prog, |state, input| {
        let combined: Vec<f64> = state.iter().zip(input.iter()).map(|(s, i)| s + i).collect();
        evaluate_linear(&layer, &combined).unwrap()
    });
    assert_eq!(out[0], vec![3.0, 5.0]);
}

#[test]
fn recurrent_linear_scan_identity_layer_accumulates_inputs() {
    // L = I, b = 0 → state_{t+1} = state_t + x_t (pure accumulation).
    let layer = linear_2x2(
        vec![vec![1.0, 0.0], vec![0.0, 1.0]],
        vec![0.0, 0.0],
    );
    let prog = ScanProgram::new(
        vec![0.0, 0.0],
        vec![
            vec![1.0, 2.0],
            vec![3.0, 4.0],
            vec![5.0, 6.0],
        ],
    );
    let out = sequential_scan(&prog, |state, input| {
        let combined: Vec<f64> = state.iter().zip(input.iter()).map(|(s, i)| s + i).collect();
        evaluate_linear(&layer, &combined).unwrap()
    });
    // step 0: state = [0, 0]
    // step 1: L([0+1, 0+2]) = [1, 2]
    // step 2: L([1+3, 2+4]) = [4, 6]
    // step 3: L([4+5, 6+6]) = [9, 12]
    assert_eq!(out.len(), 4);
    assert_eq!(out[0], vec![0.0, 0.0]);
    assert_eq!(out[1], vec![1.0, 2.0]);
    assert_eq!(out[2], vec![4.0, 6.0]);
    assert_eq!(out[3], vec![9.0, 12.0]);
}

#[test]
fn recurrent_linear_scan_with_nontrivial_weights() {
    // L = [[2, 0], [0, 0.5]], b = [1, -1].
    // Update: state_{t+1} = 2·(state_t[0] + x_t[0]) + 1, 0.5·(state_t[1] + x_t[1]) - 1.
    let layer = linear_2x2(
        vec![vec![2.0, 0.0], vec![0.0, 0.5]],
        vec![1.0, -1.0],
    );
    let prog = ScanProgram::new(
        vec![0.0, 0.0],
        vec![vec![1.0, 2.0], vec![0.5, 4.0]],
    );
    let out = sequential_scan(&prog, |state, input| {
        let combined: Vec<f64> = state.iter().zip(input.iter()).map(|(s, i)| s + i).collect();
        evaluate_linear(&layer, &combined).unwrap()
    });
    // step 0: [0, 0]
    // step 1: L([0+1, 0+2]) = [2*1+1, 0.5*2-1] = [3, 0]
    // step 2: L([3+0.5, 0+4]) = [2*3.5+1, 0.5*4-1] = [8, 1]
    assert_eq!(out[0], vec![0.0, 0.0]);
    assert_eq!(out[1], vec![3.0, 0.0]);
    assert_eq!(out[2], vec![8.0, 1.0]);
}

#[test]
fn recurrent_linear_scan_matches_unrolled_chain() {
    // Property test: scan output ≡ manually-unrolled application of
    // the layer across the input sequence.
    let layer = linear_2x2(
        vec![vec![0.5, 0.3], vec![-0.1, 0.7]],
        vec![0.2, -0.4],
    );
    let initial = vec![1.5, -0.5];
    let inputs = vec![
        vec![0.5, 1.0],
        vec![-0.3, 0.7],
        vec![2.0, -1.0],
        vec![0.1, 0.1],
    ];

    let prog = ScanProgram::new(initial.clone(), inputs.clone());
    let scan_out = sequential_scan(&prog, |state, input| {
        let combined: Vec<f64> = state.iter().zip(input.iter()).map(|(s, i)| s + i).collect();
        evaluate_linear(&layer, &combined).unwrap()
    });

    // Manual chain.
    let mut state = initial.clone();
    let mut expected = vec![state.clone()];
    for input in &inputs {
        let combined: Vec<f64> = state.iter().zip(input.iter()).map(|(s, i)| s + i).collect();
        state = evaluate_linear(&layer, &combined).unwrap();
        expected.push(state.clone());
    }

    assert_eq!(scan_out.len(), expected.len());
    for (s, e) in scan_out.iter().zip(expected.iter()) {
        for (a, b) in s.iter().zip(e.iter()) {
            assert!((a - b).abs() < 1e-12, "scan = {:?}, expected = {:?}", s, e);
        }
    }
}

#[test]
fn recurrent_linear_scan_zero_layer_collapses_to_bias() {
    // W = 0 → state_{t+1} = b always (the bias).
    let layer = linear_2x2(
        vec![vec![0.0, 0.0], vec![0.0, 0.0]],
        vec![1.0, -1.0],
    );
    let prog = ScanProgram::new(
        vec![5.0, 5.0],
        vec![vec![10.0, 10.0], vec![100.0, 100.0]],
    );
    let out = sequential_scan(&prog, |state, input| {
        let combined: Vec<f64> = state.iter().zip(input.iter()).map(|(s, i)| s + i).collect();
        evaluate_linear(&layer, &combined).unwrap()
    });
    // step 0: initial = [5, 5]
    // step 1: 0·anything + b = [1, -1]
    // step 2: 0·anything + b = [1, -1]
    assert_eq!(out[0], vec![5.0, 5.0]);
    assert_eq!(out[1], vec![1.0, -1.0]);
    assert_eq!(out[2], vec![1.0, -1.0]);
}

#[test]
fn recurrent_linear_scan_3x3_dimension_check() {
    // Verify the composition works at a non-trivial dim.
    let layer = linear_nxn(
        3,
        vec![
            vec![0.5, 0.0, 0.0],
            vec![0.0, 0.5, 0.0],
            vec![0.0, 0.0, 0.5],
        ],
        vec![0.0, 0.0, 0.0],
    );
    // 0.5·I, no bias → state_{t+1} = 0.5·(state_t + x_t).
    let prog = ScanProgram::new(
        vec![0.0, 0.0, 0.0],
        vec![vec![2.0, 4.0, 8.0], vec![1.0, 1.0, 1.0]],
    );
    let out = sequential_scan(&prog, |state, input| {
        let combined: Vec<f64> = state.iter().zip(input.iter()).map(|(s, i)| s + i).collect();
        evaluate_linear(&layer, &combined).unwrap()
    });
    // step 0: [0, 0, 0]
    // step 1: 0.5·[2, 4, 8] = [1, 2, 4]
    // step 2: 0.5·[1+1, 2+1, 4+1] = [1, 1.5, 2.5]
    assert_eq!(out[0], vec![0.0, 0.0, 0.0]);
    assert_eq!(out[1], vec![1.0, 2.0, 4.0]);
    assert_eq!(out[2], vec![1.0, 1.5, 2.5]);
}
