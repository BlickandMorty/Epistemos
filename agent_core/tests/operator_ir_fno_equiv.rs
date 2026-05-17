//! Source:
//! - §4.I:894 of CODEX_DEEP_INVESTIGATION_PROMPT — "Property test:
//!   a small FNO matches Operator-IR forward pass."
//! - Phase B4 close-out `docs/audits/PHASE_B4_CLOSEOUT_2026_05_17.md`
//!   §6 — iter-39 plan entry.
//! - Li/FNO arXiv:2010.08895 §3.

#![cfg(feature = "research")]

use agent_core::research::operator_ir::{
    evaluate_linear, evaluate_operator_at, fno_spectral_block, KernelTransform,
    LinearNetwork, OperatorExpr,
};

/// Hand-rolled FNO forward pass. Mirrors the operator_ir
/// evaluator's logic but is reimplemented independently.
fn raw_fno_forward_at(
    branch: &LinearNetwork,
    trunk: &LinearNetwork,
    modes: usize,
    u: &[f64],
    y: &[f64],
) -> f64 {
    let b = evaluate_linear(branch, u).unwrap();
    let t = evaluate_linear(trunk, y).unwrap();
    let t_spectral = fno_spectral_block(&t, modes);
    b.iter().zip(t_spectral.iter()).map(|(bi, ti)| bi * ti).sum()
}

fn make_fixture_op(modes: usize) -> OperatorExpr {
    // 2-in × 4-out branch + trunk.
    let branch = LinearNetwork::new(
        vec![
            vec![1.0, 0.0],
            vec![0.0, 1.0],
            vec![0.5, 0.5],
            vec![1.0, 1.0],
        ],
        vec![0.0, 0.0, 0.0, 0.0],
    )
    .unwrap();
    let trunk = LinearNetwork::new(
        vec![
            vec![1.0, 0.0],
            vec![0.0, 1.0],
            vec![0.5, 0.5],
            vec![1.0, 1.0],
        ],
        vec![0.0, 0.0, 0.0, 0.0],
    )
    .unwrap();
    OperatorExpr::new(branch, trunk, KernelTransform::Fourier { modes }).unwrap()
}

#[test]
fn ir_vs_raw_fno_bit_exact_at_modes_4() {
    // Full round-trip (modes = output_dim).
    let op = make_fixture_op(4);
    let inputs = vec![
        (vec![1.0, 0.0], vec![0.0, 1.0]),
        (vec![1.0, 1.0], vec![1.0, 1.0]),
        (vec![3.0, -2.0], vec![2.0, -1.0]),
        (vec![0.5, 0.5], vec![0.5, 0.5]),
    ];
    for (u, y) in &inputs {
        let v_ir = evaluate_operator_at(&op, u, y).unwrap();
        let v_raw = raw_fno_forward_at(&op.branch, &op.trunk, 4, u, y);
        assert_eq!(v_ir.to_bits(), v_raw.to_bits(), "u={:?} y={:?}", u, y);
    }
}

#[test]
fn ir_vs_raw_fno_bit_exact_at_modes_2() {
    // Truncated to 2 modes — spectral filtering.
    let op = make_fixture_op(2);
    let inputs = vec![
        (vec![1.0, 0.0], vec![0.0, 1.0]),
        (vec![1.0, 1.0], vec![1.0, 1.0]),
        (vec![3.0, -2.0], vec![2.0, -1.0]),
    ];
    for (u, y) in &inputs {
        let v_ir = evaluate_operator_at(&op, u, y).unwrap();
        let v_raw = raw_fno_forward_at(&op.branch, &op.trunk, 2, u, y);
        assert_eq!(v_ir.to_bits(), v_raw.to_bits(), "u={:?} y={:?}", u, y);
    }
}

#[test]
fn ir_vs_raw_fno_bit_exact_at_modes_1() {
    // DC-only — output collapses to mean.
    let op = make_fixture_op(1);
    let v_ir = evaluate_operator_at(&op, &[1.0, 1.0], &[2.0, 3.0]).unwrap();
    let v_raw = raw_fno_forward_at(&op.branch, &op.trunk, 1, &[1.0, 1.0], &[2.0, 3.0]);
    assert_eq!(v_ir.to_bits(), v_raw.to_bits());
}

#[test]
fn ir_fno_at_zero_modes_is_zero() {
    let op = make_fixture_op(0);
    let v = evaluate_operator_at(&op, &[1.0, 1.0], &[1.0, 1.0]).unwrap();
    assert!(v.abs() < 1e-10);
}

#[test]
fn ir_fno_linear_in_u_at_fixed_y() {
    // For fixed y, output is linear in u (branch is linear).
    let op = make_fixture_op(4);
    let y = vec![1.0, 1.0];
    let v1 = evaluate_operator_at(&op, &[1.0, 1.0], &y).unwrap();
    let v2 = evaluate_operator_at(&op, &[2.0, 2.0], &y).unwrap();
    assert!(
        ((v2 - 2.0 * v1)).abs() < 1e-9 * v1.abs().max(1.0),
        "v1={} v2={}", v1, v2
    );
}
