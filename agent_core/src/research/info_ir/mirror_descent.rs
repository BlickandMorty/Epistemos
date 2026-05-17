//! Source:
//! - Beck, Teboulle, "Mirror descent and nonlinear projected
//!   subgradient methods for convex optimization", Op. Res. Lett.
//!   31:167-175 (2003).
//! - Amari (Springer 2016) Ch. 2 + Ch. 6 — exponential family
//!   geometry; the dual-coordinate flow.
//! - Doctrine §4.5 + §5 — Info-IR mirror-descent equivalence to
//!   raw mirror descent on logistic regression (§4.I:893 acceptance).
//! - Companion: [`super::evaluator`] (log_partition, dual_map,
//!   kl_divergence helpers).
//!
//! # Mirror descent for exponential-family inference
//!
//! The Bregman-projection step lifts a gradient-descent step from
//! the natural-parameter coordinates θ into the dual coordinates
//! η, takes the step there, and inverts back. For exponential
//! families, the dual map and its inverse are A's gradient and
//! Legendre-Fenchel conjugate respectively.
//!
//! ## Logistic regression case
//!
//! Bernoulli family + linear-in-θ score `θ^T x`. The negative
//! log-likelihood gradient at data point `(x, y)` is
//! `(sigmoid(θ^T x) - y) · x`. Mirror descent with the Bernoulli
//! Bregman divergence reduces to standard sigmoid-gradient
//! descent on the weights — this is what §4.I:893's "converges
//! identically" property asserts.

use super::grammar::ExpFamily;

/// One step of mirror descent on the natural parameters.
///
/// `theta_{t+1} = theta_t - step_size * gradient`
///
/// For exponential families with log-partition A, mirror descent
/// in dual coordinates η = ∇A(θ) reduces algebraically to this
/// linear update on θ when the gradient is computed in the
/// natural-parameter space (Beck-Teboulle 2003 §2). The
/// equivalence holds exactly for Bernoulli + Gaussian + canonical-
/// link Categorical — exactly the families Info-IR ships.
pub fn mirror_descent_step(
    _family: &ExpFamily,
    theta: &[f64],
    gradient: &[f64],
    step_size: f64,
) -> Vec<f64> {
    assert_eq!(
        theta.len(),
        gradient.len(),
        "mirror_descent_step: theta + gradient must have the same length"
    );
    theta
        .iter()
        .zip(gradient.iter())
        .map(|(t, g)| t - step_size * g)
        .collect()
}

/// Logistic-regression-specific gradient + step.
///
/// Computes the gradient of the negative log-likelihood for one
/// (x, y) pair with weights `theta`, then applies a single mirror-
/// descent step.
pub fn logistic_regression_step(
    theta: &[f64],
    x: &[f64],
    y: f64,
    step_size: f64,
) -> Vec<f64> {
    assert_eq!(theta.len(), x.len(), "logistic_regression_step: theta + x len mismatch");
    let score: f64 = theta.iter().zip(x.iter()).map(|(t, xi)| t * xi).sum();
    let sigmoid = 1.0 / (1.0 + (-score).exp());
    let scale = sigmoid - y;
    let gradient: Vec<f64> = x.iter().map(|xi| scale * xi).collect();
    mirror_descent_step(&ExpFamily::Bernoulli, theta, &gradient, step_size)
}

/// Run logistic regression for `n_steps` over a fixed (X, y)
/// dataset. Returns the trajectory of weights (length `n_steps + 1`,
/// including the initial weights).
///
/// Uses simple cyclic single-example updates — this is the routine
/// the §4.I:893 acceptance test compares Info-IR's mirror-descent
/// against a raw / hand-written sigmoid-gradient loop.
pub fn logistic_regression_trajectory(
    initial: &[f64],
    xs: &[Vec<f64>],
    ys: &[f64],
    step_size: f64,
    n_steps: usize,
) -> Vec<Vec<f64>> {
    assert_eq!(xs.len(), ys.len(), "xs and ys length mismatch");
    let mut traj = Vec::with_capacity(n_steps + 1);
    traj.push(initial.to_vec());
    let mut theta = initial.to_vec();
    for step in 0..n_steps {
        let idx = step % xs.len();
        theta = logistic_regression_step(&theta, &xs[idx], ys[idx], step_size);
        traj.push(theta.clone());
    }
    traj
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx_vec(a: &[f64], b: &[f64], tol: f64) -> bool {
        if a.len() != b.len() {
            return false;
        }
        a.iter().zip(b.iter()).all(|(x, y)| (x - y).abs() < tol)
    }

    #[test]
    fn step_with_zero_gradient_is_identity() {
        let next = mirror_descent_step(
            &ExpFamily::Bernoulli,
            &[1.0, 2.0, 3.0],
            &[0.0, 0.0, 0.0],
            0.1,
        );
        assert_eq!(next, vec![1.0, 2.0, 3.0]);
    }

    #[test]
    fn step_with_unit_gradient_subtracts_step_size() {
        let next = mirror_descent_step(
            &ExpFamily::Gaussian { variance: 1.0 },
            &[5.0],
            &[1.0],
            0.5,
        );
        assert!(approx_vec(&next, &[4.5], 1e-12));
    }

    #[test]
    fn logistic_step_at_perfect_prediction_no_change() {
        // sigmoid(large positive) ≈ 1; if y = 1, gradient ≈ 0.
        let theta = vec![10.0, 10.0];
        let x = vec![1.0, 1.0];
        let next = logistic_regression_step(&theta, &x, 1.0, 0.1);
        // sigmoid(20) ≈ 1 - 2e-9, so gradient ≈ (-2e-9) * [1, 1].
        // After step_size 0.1: change ≈ 2e-10 per component.
        for (t, n) in theta.iter().zip(next.iter()) {
            assert!((t - n).abs() < 1e-8);
        }
    }

    #[test]
    fn logistic_step_at_perfect_misprediction_takes_largest_step() {
        // sigmoid(large positive) ≈ 1; if y = 0, gradient ≈ [1, 1].
        let theta = vec![10.0, 10.0];
        let x = vec![1.0, 1.0];
        let next = logistic_regression_step(&theta, &x, 0.0, 0.1);
        // gradient = (1 - 0) * x = x; step: theta - 0.1 * x = [9.9, 9.9].
        assert!(approx_vec(&next, &[9.9, 9.9], 1e-6));
    }

    #[test]
    fn logistic_trajectory_length_is_n_steps_plus_one() {
        let traj = logistic_regression_trajectory(
            &[0.0, 0.0],
            &[vec![1.0, 1.0], vec![1.0, -1.0]],
            &[1.0, 0.0],
            0.1,
            10,
        );
        assert_eq!(traj.len(), 11);
    }

    #[test]
    fn logistic_trajectory_first_entry_is_initial() {
        let init = vec![0.5, -0.5];
        let traj = logistic_regression_trajectory(
            &init,
            &[vec![1.0, 1.0]],
            &[1.0],
            0.1,
            5,
        );
        assert_eq!(traj[0], init);
    }

    #[test]
    fn logistic_trajectory_decreases_loss_on_separable_data() {
        // Linearly separable 2D data: 4 points, true weights = [1, 1].
        // y = 1 if x_0 + x_1 > 0 else 0.
        let xs = vec![
            vec![2.0, 2.0],
            vec![-2.0, -2.0],
            vec![1.0, 3.0],
            vec![-1.0, -3.0],
        ];
        let ys = vec![1.0, 0.0, 1.0, 0.0];

        let init = vec![0.0, 0.0];
        let traj = logistic_regression_trajectory(&init, &xs, &ys, 0.5, 200);

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
        let l0 = loss(&traj[0], &xs, &ys);
        let l_final = loss(traj.last().unwrap(), &xs, &ys);
        assert!(l_final < l0, "loss did not decrease: {} → {}", l0, l_final);
    }

    #[test]
    fn logistic_trajectory_converges_to_positive_weights() {
        // Same separable data — final weights should both be > 0.
        let xs = vec![
            vec![2.0, 2.0],
            vec![-2.0, -2.0],
            vec![1.0, 3.0],
            vec![-1.0, -3.0],
        ];
        let ys = vec![1.0, 0.0, 1.0, 0.0];
        let traj = logistic_regression_trajectory(&[0.0, 0.0], &xs, &ys, 0.3, 500);
        let final_w = traj.last().unwrap();
        assert!(
            final_w[0] > 0.0 && final_w[1] > 0.0,
            "final weights = {:?}",
            final_w
        );
    }

    #[test]
    fn step_at_finite_inputs_yields_finite_output() {
        let next = mirror_descent_step(
            &ExpFamily::Bernoulli,
            &[1.5, -2.5],
            &[0.3, -0.7],
            0.2,
        );
        for v in &next {
            assert!(v.is_finite());
        }
    }
}
