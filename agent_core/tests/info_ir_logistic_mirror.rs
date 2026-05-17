//! Source:
//! - §4.I:893 of CODEX_DEEP_INVESTIGATION_PROMPT — "logistic
//!   regression converges identically through Info-IR mirror
//!   descent vs raw mirror descent."
//! - Phase B3 close-out `docs/audits/PHASE_B3_CLOSEOUT_2026_05_17.md`
//!   §6 — iter-33 plan entry.
//! - Beck-Teboulle Op. Res. Lett. 31:167-175 (2003) §2 — the
//!   mirror-descent step that this test verifies as identical
//!   between two code paths.
//! - Companion: agent_core/src/research/info_ir/mirror_descent.rs
//!
//! # §4.I:893 acceptance — Info-IR vs raw logistic regression
//!
//! Both paths share the same mathematical content (sigmoid
//! gradient on weights). Info-IR's path goes through the
//! `logistic_regression_trajectory` API; the "raw" path is
//! reimplemented locally in this test. Both must produce
//! **bit-exact** weight trajectories at every step.

#![cfg(feature = "research")]

use agent_core::research::info_ir::{
    logistic_regression_step, logistic_regression_trajectory,
};

/// Raw / hand-rolled logistic-regression step. Mirrors
/// agent_core::research::info_ir::mirror_descent::logistic_regression_step
/// but does not go through the Info-IR module — exists to be the
/// independent reference path for the §4.I:893 cross-check.
///
/// IEEE 754 associativity caveat: `a * b * c` is left-associative
/// in Rust (`(a * b) * c`), while Info-IR's two-step compute
/// (gradient = scale * xi, then theta - step_size * gradient)
/// effectively does `step_size * (scale * xi)`. Those two parens
/// differ in the last bit for many inputs. The raw path here
/// **matches Info-IR's parenthesization exactly**, materializing
/// the gradient first so the bit-exact §4.I:893 acceptance holds.
fn raw_logistic_step(theta: &[f64], x: &[f64], y: f64, step_size: f64) -> Vec<f64> {
    let score: f64 = theta.iter().zip(x.iter()).map(|(t, xi)| t * xi).sum();
    let sigmoid = 1.0 / (1.0 + (-score).exp());
    let scale = sigmoid - y;
    let gradient: Vec<f64> = x.iter().map(|xi| scale * xi).collect();
    theta
        .iter()
        .zip(gradient.iter())
        .map(|(t, g)| t - step_size * g)
        .collect()
}

/// Raw trajectory generator — cyclic single-example updates,
/// identical algorithm to Info-IR's trajectory generator.
fn raw_logistic_trajectory(
    initial: &[f64],
    xs: &[Vec<f64>],
    ys: &[f64],
    step_size: f64,
    n_steps: usize,
) -> Vec<Vec<f64>> {
    let mut traj = Vec::with_capacity(n_steps + 1);
    traj.push(initial.to_vec());
    let mut theta = initial.to_vec();
    for step in 0..n_steps {
        let idx = step % xs.len();
        theta = raw_logistic_step(&theta, &xs[idx], ys[idx], step_size);
        traj.push(theta.clone());
    }
    traj
}

fn xy_fixture() -> (Vec<Vec<f64>>, Vec<f64>) {
    // Linearly-separable 2D fixture; true weights = [1, 1] approximately.
    let xs = vec![
        vec![2.0, 2.0],
        vec![-2.0, -2.0],
        vec![1.0, 3.0],
        vec![-1.0, -3.0],
        vec![3.0, 1.0],
        vec![-3.0, -1.0],
    ];
    let ys = vec![1.0, 0.0, 1.0, 0.0, 1.0, 0.0];
    (xs, ys)
}

#[test]
fn single_step_matches_raw_bit_exact() {
    let theta = vec![0.5, -0.3];
    let x = vec![1.0, 2.0];
    let y = 1.0;
    let step = 0.1;
    let info_next = logistic_regression_step(&theta, &x, y, step);
    let raw_next = raw_logistic_step(&theta, &x, y, step);
    for (a, b) in info_next.iter().zip(&raw_next) {
        assert_eq!(a.to_bits(), b.to_bits(), "info={} raw={}", a, b);
    }
}

#[test]
fn ten_step_trajectory_matches_raw_bit_exact() {
    let (xs, ys) = xy_fixture();
    let initial = vec![0.0, 0.0];
    let info = logistic_regression_trajectory(&initial, &xs, &ys, 0.2, 10);
    let raw = raw_logistic_trajectory(&initial, &xs, &ys, 0.2, 10);
    assert_eq!(info.len(), raw.len());
    for (step, (a, b)) in info.iter().zip(&raw).enumerate() {
        assert_eq!(a.len(), b.len(), "step {} len mismatch", step);
        for (ai, bi) in a.iter().zip(b.iter()) {
            assert_eq!(
                ai.to_bits(),
                bi.to_bits(),
                "step {} info={} raw={}",
                step,
                ai,
                bi
            );
        }
    }
}

#[test]
fn long_trajectory_500_steps_matches_raw_bit_exact() {
    // §4.I:893 binding: identical trajectories over a substantial
    // step budget. 500 steps × 6 samples per cycle = 83+ epochs.
    let (xs, ys) = xy_fixture();
    let initial = vec![0.5, -0.5];
    let info = logistic_regression_trajectory(&initial, &xs, &ys, 0.1, 500);
    let raw = raw_logistic_trajectory(&initial, &xs, &ys, 0.1, 500);
    assert_eq!(info.len(), 501);
    for (step, (a, b)) in info.iter().zip(&raw).enumerate() {
        for (ai, bi) in a.iter().zip(b.iter()) {
            assert_eq!(
                ai.to_bits(),
                bi.to_bits(),
                "step {} info={} raw={}",
                step,
                ai,
                bi
            );
        }
    }
}

#[test]
fn convergence_reaches_low_loss_under_500_steps() {
    let (xs, ys) = xy_fixture();
    let initial = vec![0.0, 0.0];
    let traj = logistic_regression_trajectory(&initial, &xs, &ys, 0.3, 500);

    fn loss(theta: &[f64], xs: &[Vec<f64>], ys: &[f64]) -> f64 {
        xs.iter()
            .zip(ys.iter())
            .map(|(x, &y)| {
                let s: f64 = theta.iter().zip(x.iter()).map(|(t, xi)| t * xi).sum();
                let sigmoid = 1.0 / (1.0 + (-s).exp());
                -(y * sigmoid.ln() + (1.0 - y) * (1.0 - sigmoid).ln())
            })
            .sum::<f64>()
    }
    let initial_loss = loss(&traj[0], &xs, &ys);
    let final_loss = loss(traj.last().unwrap(), &xs, &ys);
    assert!(final_loss < initial_loss * 0.5,
        "loss did not decrease by 50%: {} → {}", initial_loss, final_loss);
}

#[test]
fn varying_step_sizes_all_match_raw() {
    let (xs, ys) = xy_fixture();
    let initial = vec![0.1, -0.1];
    for &step_size in &[0.01_f64, 0.05, 0.1, 0.2, 0.5] {
        let info = logistic_regression_trajectory(&initial, &xs, &ys, step_size, 50);
        let raw = raw_logistic_trajectory(&initial, &xs, &ys, step_size, 50);
        for (step, (a, b)) in info.iter().zip(&raw).enumerate() {
            for (ai, bi) in a.iter().zip(b.iter()) {
                assert_eq!(
                    ai.to_bits(),
                    bi.to_bits(),
                    "step_size={} step={} info={} raw={}",
                    step_size, step, ai, bi
                );
            }
        }
    }
}
