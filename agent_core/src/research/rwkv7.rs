//! Source:
//! - Peng et al., "RWKV-7: Goose with Expressive Dynamic State
//!   Evolution", arXiv:2503.14456, March 2025 — receptance-weighted
//!   key-value RNN with per-channel decay and a per-token receptance
//!   gate. Vault candidate per V6.1 integration §1.4 + §"Terminal B"
//!   Phase B.1 J12.
//! - Peng et al., "RWKV: Reinventing RNNs for the Transformer Era",
//!   arXiv:2305.13048, 2023 — RWKV v4 origin.
//!
//! # Wave J12 — RWKV-7 time-mixing substrate (scalar reference)
//!
//! Per-step time-mixing recurrence (scalar single-channel):
//!
//! ```text
//! state[t] = w[t] * state[t-1] + k[t] * v[t]    (real, decay-weighted)
//! gate[t]  = sigmoid(r[t])                       (receptance, per-token)
//! y[t]     = gate[t] * (alpha * state[t] + beta * v[t])
//! ```
//!
//! Where:
//! - `w[t]` is the per-token decay weight (typically `exp(-decay)` in
//!   `[0, 1]` for stability; substrate accepts any f32).
//! - `r[t]` is the per-token receptance pre-activation.
//! - `alpha` / `beta` are mixing coefficients between the running state
//!   and the bare value (substrate floor: caller-supplied scalars).
//!
//! Substrate floor scope: scalar single-channel + per-step recurrence
//! + scan over a sequence. Multi-channel + Metal port are NOT-STARTED.
//! The sigmoid is the standard 1 / (1 + exp(-x)).

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Rwkv7ScanResult {
    pub y: Vec<f32>,
    pub final_state: f32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Rwkv7Error {
    LengthMismatch { w: usize, k: usize, v: usize, r: usize },
    NonFiniteInput { which: &'static str, index: usize, value: f32 },
}

pub fn sigmoid(x: f32) -> f32 {
    1.0 / (1.0 + (-x).exp())
}

fn validate_finite(slice: &[f32], which: &'static str) -> Result<(), Rwkv7Error> {
    for (i, &v) in slice.iter().enumerate() {
        if !v.is_finite() {
            return Err(Rwkv7Error::NonFiniteInput { which, index: i, value: v });
        }
    }
    Ok(())
}

/// Verify the per-step decay-stability invariant for an RWKV-7 scan:
/// `|w[t]| < 1` for every t. Returns Ok(true) iff every decay weight
/// has magnitude strictly less than `1.0 - tol`. The doctrine pin is
/// the strict `< 1`; `tol` enforces a safety margin so values within
/// tol of the boundary are also rejected (fp32 boundary fuzz). A
/// scan with `|w[t]| ≥ 1` lets the state grow unboundedly.
///
/// Returns `Err(NonFiniteInput)` if any `w[t]` is NaN/inf; otherwise
/// returns `Ok(bool)`.
pub fn verify_decay_stability(w: &[f32], tol: f32) -> Result<bool, Rwkv7Error> {
    validate_finite(w, "w")?;
    let bound = 1.0 - tol;
    for &wt in w {
        if wt.abs() >= bound {
            return Ok(false);
        }
    }
    Ok(true)
}

/// Closed-form steady-state of the RWKV-7 recurrence under
/// constant `w_const` and constant `k_v` (= k[t] * v[t]):
///
/// ```text
/// state* = k_v / (1 - w_const)
/// ```
///
/// Requires `|w_const| < 1`; otherwise no finite steady state exists.
/// Returns `None` if the recurrence diverges.
pub fn steady_state(w_const: f32, k_v: f32) -> Option<f32> {
    if !w_const.is_finite() || !k_v.is_finite() {
        return None;
    }
    if w_const.abs() >= 1.0 {
        return None;
    }
    Some(k_v / (1.0 - w_const))
}

/// Per-step RWKV-7 time-mixing scan. `alpha` and `beta` are caller-
/// supplied mixing coefficients between the running state and the
/// bare value.
pub fn rwkv7_scan_scalar(
    w: &[f32],
    k: &[f32],
    v: &[f32],
    r: &[f32],
    alpha: f32,
    beta: f32,
    initial_state: f32,
) -> Result<Rwkv7ScanResult, Rwkv7Error> {
    if w.len() != k.len() || k.len() != v.len() || v.len() != r.len() {
        return Err(Rwkv7Error::LengthMismatch {
            w: w.len(),
            k: k.len(),
            v: v.len(),
            r: r.len(),
        });
    }
    validate_finite(w, "w")?;
    validate_finite(k, "k")?;
    validate_finite(v, "v")?;
    validate_finite(r, "r")?;
    let mut state = initial_state;
    let mut y = Vec::with_capacity(w.len());
    for i in 0..w.len() {
        state = w[i] * state + k[i] * v[i];
        let gate = sigmoid(r[i]);
        y.push(gate * (alpha * state + beta * v[i]));
    }
    Ok(Rwkv7ScanResult { y, final_state: state })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx(a: f32, b: f32, tol: f32) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn sigmoid_at_zero_is_half() {
        assert!(approx(sigmoid(0.0), 0.5, 1e-6));
    }

    #[test]
    fn sigmoid_large_positive_near_one() {
        assert!(approx(sigmoid(10.0), 1.0, 1e-3));
    }

    #[test]
    fn sigmoid_large_negative_near_zero() {
        assert!(approx(sigmoid(-10.0), 0.0, 1e-3));
    }

    #[test]
    fn length_mismatch_errors() {
        let err = rwkv7_scan_scalar(&[1.0], &[1.0, 2.0], &[1.0], &[1.0], 1.0, 0.0, 0.0)
            .unwrap_err();
        assert!(matches!(err, Rwkv7Error::LengthMismatch { .. }));
    }

    #[test]
    fn non_finite_w_rejected() {
        let err = rwkv7_scan_scalar(
            &[f32::NAN],
            &[1.0],
            &[1.0],
            &[1.0],
            1.0,
            0.0,
            0.0,
        )
        .unwrap_err();
        match err {
            Rwkv7Error::NonFiniteInput { which, .. } => assert_eq!(which, "w"),
            other => panic!("expected NonFiniteInput w, got {:?}", other),
        }
    }

    #[test]
    fn unit_decay_zero_r_gate_is_half() {
        // w=1, k=1, v=1, r=0 (gate=0.5), alpha=1, beta=0
        // state[t] = state + 1
        // y[t] = 0.5 * state[t]
        let result = rwkv7_scan_scalar(
            &[1.0; 3],
            &[1.0; 3],
            &[1.0; 3],
            &[0.0; 3],
            1.0,
            0.0,
            0.0,
        )
        .unwrap();
        // states: 1, 2, 3 → y: 0.5, 1.0, 1.5
        assert!(approx(result.y[0], 0.5, 1e-6));
        assert!(approx(result.y[1], 1.0, 1e-6));
        assert!(approx(result.y[2], 1.5, 1e-6));
        assert_eq!(result.final_state, 3.0);
    }

    #[test]
    fn zero_decay_drops_prior_state() {
        let result = rwkv7_scan_scalar(
            &[0.0, 0.0, 0.0],
            &[1.0; 3],
            &[2.0, 3.0, 4.0],
            &[100.0; 3],
            1.0,
            0.0,
            999.0,
        )
        .unwrap();
        // state[t] = 0 * prior + 1 * v[t] = v[t]
        // y[t] = sigmoid(100) * v[t] ≈ v[t]
        assert!(approx(result.y[0], 2.0, 1e-3));
        assert!(approx(result.y[1], 3.0, 1e-3));
        assert!(approx(result.y[2], 4.0, 1e-3));
    }

    #[test]
    fn negative_r_gate_near_zero_suppresses_output() {
        let result = rwkv7_scan_scalar(
            &[1.0],
            &[1.0],
            &[10.0],
            &[-20.0],
            1.0,
            0.0,
            0.0,
        )
        .unwrap();
        assert!(result.y[0].abs() < 1e-6);
    }

    #[test]
    fn beta_term_adds_bare_value_contribution() {
        let result = rwkv7_scan_scalar(
            &[0.0],
            &[0.0],
            &[5.0],
            &[100.0],
            0.0,
            1.0,
            0.0,
        )
        .unwrap();
        // gate ≈ 1, alpha=0, beta=1 → y = 1.0 * (0 + 1.0 * 5.0) = 5.0
        assert!(approx(result.y[0], 5.0, 1e-3));
    }

    #[test]
    fn empty_scan_returns_initial_state() {
        let result = rwkv7_scan_scalar(&[], &[], &[], &[], 1.0, 0.0, 7.5).unwrap();
        assert!(result.y.is_empty());
        assert_eq!(result.final_state, 7.5);
    }

    #[test]
    fn decay_half_carries_state_with_geometric_falloff() {
        // w = 0.5 each step, k = 1, v = 0, alpha = 1, beta = 0
        // state[t] = 0.5 * state[t-1]
        let result = rwkv7_scan_scalar(
            &[0.5, 0.5, 0.5],
            &[1.0; 3],
            &[0.0; 3],
            &[100.0; 3],
            1.0,
            0.0,
            8.0,
        )
        .unwrap();
        // states: 4, 2, 1; gates ≈ 1; y ≈ states
        assert!(approx(result.y[0], 4.0, 1e-3));
        assert!(approx(result.y[1], 2.0, 1e-3));
        assert!(approx(result.y[2], 1.0, 1e-3));
    }

    #[test]
    fn result_roundtrips_through_serde_json() {
        let r = Rwkv7ScanResult { y: vec![1.0, 2.0], final_state: 3.0 };
        let json = serde_json::to_string(&r).unwrap();
        let back: Rwkv7ScanResult = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn initial_state_carries_to_first_output() {
        // w=1, k=0, v=0, alpha=1, beta=0, initial=5, r=0 (gate=0.5)
        // state[0] = 1 * 5 + 0 * 0 = 5; y[0] = 0.5 * 5 = 2.5
        let result = rwkv7_scan_scalar(&[1.0], &[0.0], &[0.0], &[0.0], 1.0, 0.0, 5.0).unwrap();
        assert!(approx(result.y[0], 2.5, 1e-6));
    }

    // ── verify_decay_stability + steady_state tests (iter 101) ──────────────

    #[test]
    fn stability_all_decay_below_one_passes() {
        let w = vec![0.5, 0.9, 0.99, -0.5, 0.0];
        assert!(verify_decay_stability(&w, 1e-6).unwrap());
    }

    #[test]
    fn stability_decay_equal_one_rejected() {
        let w = vec![0.5, 1.0, 0.5];
        assert!(!verify_decay_stability(&w, 1e-6).unwrap());
    }

    #[test]
    fn stability_decay_above_one_rejected() {
        let w = vec![0.5, 1.5, 0.5];
        assert!(!verify_decay_stability(&w, 1e-6).unwrap());
    }

    #[test]
    fn stability_negative_decay_above_one_in_magnitude_rejected() {
        let w = vec![-1.5];
        assert!(!verify_decay_stability(&w, 1e-6).unwrap());
    }

    #[test]
    fn stability_nan_rejected() {
        let w = vec![0.5, f32::NAN];
        assert!(matches!(
            verify_decay_stability(&w, 1e-6).unwrap_err(),
            Rwkv7Error::NonFiniteInput { which: "w", .. }
        ));
    }

    #[test]
    fn stability_empty_passes_vacuously() {
        assert!(verify_decay_stability(&[], 1e-6).unwrap());
    }

    #[test]
    fn steady_state_zero_decay_returns_kv() {
        // state* = k_v / (1 - 0) = k_v
        assert!(approx(steady_state(0.0, 3.0).unwrap(), 3.0, 1e-6));
    }

    #[test]
    fn steady_state_half_decay_doubles_kv() {
        // state* = k_v / (1 - 0.5) = 2 * k_v
        assert!(approx(steady_state(0.5, 2.0).unwrap(), 4.0, 1e-6));
    }

    #[test]
    fn steady_state_negative_decay_correct() {
        // state* = 1.0 / (1 - (-0.5)) = 1.0 / 1.5
        assert!(approx(
            steady_state(-0.5, 1.0).unwrap(),
            1.0 / 1.5,
            1e-6
        ));
    }

    #[test]
    fn steady_state_unit_decay_diverges_returns_none() {
        assert!(steady_state(1.0, 1.0).is_none());
        assert!(steady_state(-1.0, 1.0).is_none());
    }

    #[test]
    fn steady_state_nan_rejected() {
        assert!(steady_state(f32::NAN, 1.0).is_none());
        assert!(steady_state(0.5, f32::NAN).is_none());
    }

    #[test]
    fn steady_state_matches_long_run_scan() {
        // For w=0.5 constant + k=1, v=1 constant, the scan should
        // converge to steady_state(0.5, 1.0) = 2.0 over a long run.
        let n = 50;
        let w = vec![0.5_f32; n];
        let k = vec![1.0_f32; n];
        let v = vec![1.0_f32; n];
        let r = vec![100.0_f32; n]; // gate ≈ 1.0
        let result = rwkv7_scan_scalar(&w, &k, &v, &r, 1.0, 0.0, 0.0).unwrap();
        let expected_steady = steady_state(0.5, 1.0).unwrap();
        // After 50 steps with decay 0.5, the state should be within
        // 1e-12 of the steady value.
        assert!((result.final_state - expected_steady).abs() < 1e-12);
    }
}
