//! Source:
//! - Doctrine `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md`
//!   §6.2 row 4 — Scan-IR → Info-IR composition arrow.
//! - Companion to iter-93 (Operator→Scan, arrow #1) and iter-94
//!   (Tropical→Scan, arrow #7).
//!
//! # Composition: streaming sufficient-statistic accumulation
//!
//! The natural composition is **Bayesian streaming**: a scan
//! accumulates natural parameters from a sequence of observations,
//! and at each step we read off information-theoretic quantities
//! (log_partition, dual_map / mean, KL between consecutive states).
//!
//! For a conjugate exp-family posterior with prior θ_0:
//!
//! ```text
//! θ_{t+1} = θ_t + sufficient_stat(x_t)
//! ```
//!
//! Once a `sequential_scan` produces the trajectory `[θ_0, θ_1, …]`,
//! `info_ir::log_partition` / `dual_map` / `kl_divergence` evaluate
//! the running statistics.
//!
//! Iter-95 — promotes lattice arrow #4 (Scan → Info) from
//! "code-pattern" to "wired with integration test".

#![cfg(feature = "research")]

use agent_core::research::info_ir::{
    dual_map, entropy, kl_divergence, log_partition, ExpFamily,
};
use agent_core::research::scan_ir::{sequential_scan, ScanProgram};

#[test]
fn scan_accumulates_natural_params_running_log_partition_grows() {
    // Bernoulli streaming: each observation is +1 if "heads", -1 if
    // "tails", added to the natural-param accumulator. With all-heads,
    // θ grows linearly and A(θ) saturates to θ.
    let prog = ScanProgram::new(0.0_f64, vec![1.0_f64; 5]);
    let theta_trajectory = sequential_scan(&prog, |state, input| state + input);
    assert_eq!(theta_trajectory.len(), 6);
    assert_eq!(theta_trajectory[0], 0.0);
    assert_eq!(theta_trajectory[5], 5.0);

    // Read log_partition at each step.
    let log_z: Vec<f64> = theta_trajectory
        .iter()
        .map(|&t| log_partition(&ExpFamily::Bernoulli, &[t]))
        .collect();
    // log_partition is monotone increasing in θ for Bernoulli (since σ > 0).
    for w in log_z.windows(2) {
        assert!(w[1] > w[0], "log_Z not monotone: {} → {}", w[0], w[1]);
    }
    // log_partition saturates to θ for θ ≫ 0.
    assert!((log_z[5] - 5.0).abs() < 0.01, "log_Z(5) ≈ 5; got {}", log_z[5]);
}

#[test]
fn scan_dual_map_mean_converges_to_one_for_all_heads() {
    // Same all-heads stream as above; mean probability → 1.
    let prog = ScanProgram::new(0.0_f64, vec![1.0_f64; 10]);
    let theta_traj = sequential_scan(&prog, |state, input| state + input);
    let mean_traj: Vec<f64> = theta_traj
        .iter()
        .map(|&t| dual_map(&ExpFamily::Bernoulli, &[t])[0])
        .collect();
    // mean_0 = 0.5 (initial flat prior).
    assert!((mean_traj[0] - 0.5).abs() < 1e-12);
    // mean_10 should be close to 1.
    assert!(mean_traj[10] > 0.9999, "mean_10 = {}", mean_traj[10]);
    // Monotone.
    for w in mean_traj.windows(2) {
        assert!(w[1] > w[0]);
    }
}

#[test]
fn scan_with_balanced_evidence_keeps_mean_at_half() {
    // Alternating +1/-1 observations: θ oscillates around 0,
    // mean stays close to 0.5.
    let prog = ScanProgram::new(0.0_f64, vec![1.0, -1.0, 1.0, -1.0, 1.0, -1.0]);
    let theta_traj = sequential_scan(&prog, |state, input| state + input);
    // Final θ should return to 0.
    assert!(theta_traj[6].abs() < 1e-12);
    // Mean at the end = 0.5 exactly.
    let mean_end = dual_map(&ExpFamily::Bernoulli, &[theta_traj[6]])[0];
    assert!((mean_end - 0.5).abs() < 1e-12);
}

#[test]
fn scan_kl_between_consecutive_distributions_is_decreasing_with_evidence() {
    // The KL between successive posteriors shrinks as more evidence
    // arrives (the posterior changes less per observation as it
    // concentrates).
    let prog = ScanProgram::new(0.0_f64, vec![1.0_f64; 8]);
    let theta_traj = sequential_scan(&prog, |state, input| state + input);

    let mut prev_kl = f64::INFINITY;
    for w in theta_traj.windows(2) {
        let kl = kl_divergence(&ExpFamily::Bernoulli, &[w[1]], &[w[0]]);
        // After the first ~3 steps, KL should be strictly decreasing.
        // (The first transition 0→1 is the largest jump.)
        if w[0] > 1.0 {
            assert!(
                kl < prev_kl,
                "KL between θ={} and θ={} is {}, not less than prev {}",
                w[0], w[1], kl, prev_kl
            );
        }
        prev_kl = kl;
    }
}

#[test]
fn scan_running_entropy_decreases_with_concentrating_evidence() {
    // Entropy is maximal at θ=0 (uniform) and approaches 0 as θ → ±∞.
    let prog = ScanProgram::new(0.0_f64, vec![0.7_f64; 8]);
    let theta_traj = sequential_scan(&prog, |state, input| state + input);
    let h_traj: Vec<f64> = theta_traj
        .iter()
        .map(|&t| entropy(&ExpFamily::Bernoulli, &[t]))
        .collect();
    // H_0 = ln 2 (uniform).
    assert!((h_traj[0] - 2.0_f64.ln()).abs() < 1e-12);
    // H decreases monotonically as evidence accumulates.
    for w in h_traj.windows(2) {
        assert!(w[1] < w[0] || (w[1] - w[0]).abs() < 1e-12);
    }
    // Final entropy ≪ ln 2.
    assert!(h_traj[8] < h_traj[0]);
}

#[test]
fn scan_categorical_streaming_natural_params_accumulate_per_dim() {
    // Categorical k=3: state is Vec<f64> of natural params (k-1 = 2 dims).
    // Each input is +1 in one of the 2 non-pinned slots.
    let prog = ScanProgram::new(
        vec![0.0_f64, 0.0],
        vec![
            vec![1.0, 0.0], // slot 0 evidence
            vec![1.0, 0.0],
            vec![0.0, 1.0], // slot 1 evidence
        ],
    );
    let traj = sequential_scan(&prog, |state, input| {
        state.iter().zip(input.iter()).map(|(s, i)| s + i).collect()
    });
    assert_eq!(traj[0], vec![0.0, 0.0]);
    assert_eq!(traj[1], vec![1.0, 0.0]);
    assert_eq!(traj[2], vec![2.0, 0.0]);
    assert_eq!(traj[3], vec![2.0, 1.0]);

    // Final mean params:
    let mean = dual_map(&ExpFamily::Categorical { k: 3 }, &traj[3]);
    // slot 0 has 2 observations, slot 1 has 1, pinned slot has 0.
    // mean_0 = e^2 / (e^2 + e^1 + 1) ≈ 7.389 / 11.107 ≈ 0.665.
    let z = 2.0_f64.exp() + 1.0_f64.exp() + 1.0;
    let expected_0 = 2.0_f64.exp() / z;
    let expected_1 = 1.0_f64.exp() / z;
    assert!((mean[0] - expected_0).abs() < 1e-12);
    assert!((mean[1] - expected_1).abs() < 1e-12);
}

#[test]
fn scan_consecutive_log_partition_differences_equal_added_evidence_amount() {
    // For Bernoulli with input δθ, A(θ + δθ) - A(θ) = softplus shift.
    // For small δθ, this is approximately σ(θ) · δθ (linearization).
    let prog = ScanProgram::new(2.0_f64, vec![0.5_f64; 4]);
    let theta_traj = sequential_scan(&prog, |state, input| state + input);
    let a_traj: Vec<f64> = theta_traj
        .iter()
        .map(|&t| log_partition(&ExpFamily::Bernoulli, &[t]))
        .collect();
    for (i, w) in theta_traj.windows(2).enumerate() {
        let delta_a = a_traj[i + 1] - a_traj[i];
        // Expected approx: σ(θ_i) · 0.5 (first-order Taylor).
        let approx = dual_map(&ExpFamily::Bernoulli, &[w[0]])[0] * 0.5;
        // Within 0.05 of the linearization for these moderate inputs.
        assert!(
            (delta_a - approx).abs() < 0.05,
            "δA = {}; first-order approx = {}", delta_a, approx
        );
    }
}
