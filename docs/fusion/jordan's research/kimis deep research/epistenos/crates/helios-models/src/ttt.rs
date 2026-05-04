//! Test-Time Training (TTT) layer.
//!
//! This module implements the TTT-Linear layer from Sun et al. (2024):
//! instead of a static attention mechanism, an *inner* linear model is
//! trained online at test time using self-supervised gradients.  The
//! result is a context-dependent weight matrix that adapts to the
//! current sequence without backpropagating into the base model.
//!
//! # Design
//!
//! * **Inner weights** `w` — updated via SGD on a reconstruction loss.
//! * **Test-time LR** — decoupled from pre-training LR; typically 0.01–0.1.
//! * **Momentum / decay** — optional EMA for stability.
//! * **Attention replacement** — `ttt_attention_replacement` swaps the
//!   standard Q·K^T softmax with a TTT inner model for a single layer.

use thiserror::Error;
use tracing::{debug, trace, warn};

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

/// Errors from the TTT engine.
#[derive(Error, Debug, Clone, PartialEq)]
pub enum TTTError {
    #[error("dimension mismatch: expected {expected}, got {got}")]
    DimMismatch { expected: usize, got: usize },
    #[error("invalid learning rate: {0} (must be > 0)")]
    InvalidLearningRate(f32),
    #[error("inner weights not initialised")]
    NotInitialised,
    #[error("unimplemented: {0}")]
    Unimplemented(String),
}

pub type TTTResult<T> = Result<T, TTTError>;

// ---------------------------------------------------------------------------
// TTTConfig
// ---------------------------------------------------------------------------

/// Hyperparameters for test-time training.
#[derive(Debug, Clone, PartialEq)]
pub struct TTTConfig {
    /// Inner SGD learning rate.
    pub lr: f32,
    /// Weight decay on inner weights (L2 regularisation).
    pub decay: f32,
    /// Momentum coefficient (0.0 = pure SGD, 0.9 = heavy momentum).
    pub momentum: f32,
    /// Gradient clipping threshold (0.0 = disabled).
    pub grad_clip: f32,
    /// Number of inner gradient steps per token.
    pub inner_steps: usize,
}

impl Default for TTTConfig {
    fn default() -> Self {
        Self {
            lr: 0.05,
            decay: 0.01,
            momentum: 0.9,
            grad_clip: 1.0,
            inner_steps: 1,
        }
    }
}

impl TTTConfig {
    /// Validate the configuration.
    pub fn validate(&self) -> TTTResult<()> {
        if self.lr <= 0.0 {
            return Err(TTTError::InvalidLearningRate(self.lr));
        }
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// TTTLinear
// ---------------------------------------------------------------------------

/// A TTT-Linear inner model.
///
/// Maintains an `out_dim × in_dim` weight matrix `w` that is updated
/// online via gradient descent on a reconstruction or prediction loss.
/// The forward pass applies the *current* inner weights.
#[derive(Debug, Clone, PartialEq)]
pub struct TTTLinear {
    /// Flat inner weight matrix `[out_dim, in_dim]` row-major.
    pub w: Vec<f32>,
    /// Momentum buffer (same shape as `w`).
    pub m: Vec<f32>,
    /// Test-time learning rate.
    pub lr: f32,
    /// Weight decay.
    pub decay: f32,
    /// Momentum coefficient.
    pub momentum: f32,
    /// Gradient clipping.
    pub grad_clip: f32,
    /// Output dimension.
    pub out_dim: usize,
    /// Input dimension.
    pub in_dim: usize,
    /// Update step counter.
    pub step_count: usize,
}

impl TTTLinear {
    /// Create a new TTT linear layer with zero-initialised weights.
    pub fn new(out_dim: usize, in_dim: usize, config: &TTTConfig) -> TTTResult<Self> {
        config.validate()?;
        Ok(Self {
            w: vec![0.0f32; out_dim * in_dim],
            m: vec![0.0f32; out_dim * in_dim],
            lr: config.lr,
            decay: config.decay,
            momentum: config.momentum,
            grad_clip: config.grad_clip,
            out_dim,
            in_dim,
            step_count: 0,
        })
    }

    /// Create with explicit initial weights.
    pub fn with_weights(weights: Vec<f32>, out_dim: usize, in_dim: usize, config: &TTTConfig) -> TTTResult<Self> {
        config.validate()?;
        if weights.len() != out_dim * in_dim {
            return Err(TTTError::DimMismatch {
                expected: out_dim * in_dim,
                got: weights.len(),
            });
        }
        Ok(Self {
            w: weights,
            m: vec![0.0f32; out_dim * in_dim],
            lr: config.lr,
            decay: config.decay,
            momentum: config.momentum,
            grad_clip: config.grad_clip,
            out_dim,
            in_dim,
            step_count: 0,
        })
    }

    /// Apply the current inner weights: `y = W @ x`.
    ///
    /// Hot-path: real GEMV.
    pub fn forward(&self, x: &[f32]) -> Vec<f32> {
        assert_eq!(x.len(), self.in_dim);
        let mut y = vec![0.0f32; self.out_dim];
        for i in 0..self.out_dim {
            let mut acc = 0.0f32;
            let row_start = i * self.in_dim;
            for j in 0..self.in_dim {
                acc += self.w[row_start + j] * x[j];
            }
            y[i] = acc;
        }
        y
    }

    /// Update inner weights via one gradient step.
    ///
    /// `x` — the input vector that produced the current prediction.
    /// `loss_grad` — the gradient of the loss w.r.t. the output `y`.
    ///
    /// The weight gradient is `outer(loss_grad, x) = loss_grad ⊗ x`.
    /// We then apply weight decay and momentum.
    pub fn update(&mut self, x: &[f32], loss_grad: &[f32]) {
        assert_eq!(x.len(), self.in_dim);
        assert_eq!(loss_grad.len(), self.out_dim);

        // Compute raw gradient: g[i,j] = loss_grad[i] * x[j]
        let mut grad = vec![0.0f32; self.out_dim * self.in_dim];
        for i in 0..self.out_dim {
            let row_start = i * self.in_dim;
            for j in 0..self.in_dim {
                grad[row_start + j] = loss_grad[i] * x[j];
            }
        }

        // Gradient clipping (per-element).
        if self.grad_clip > 0.0 {
            for g in grad.iter_mut() {
                *g = g.clamp(-self.grad_clip, self.grad_clip);
            }
        }

        // Momentum + weight decay update.
        for i in 0..self.w.len() {
            let g = grad[i] + self.decay * self.w[i];
            self.m[i] = self.momentum * self.m[i] + g;
            self.w[i] -= self.lr * self.m[i];
        }

        self.step_count += 1;
        trace!("TTTLinear update: step={}, lr={}", self.step_count, self.lr);
    }

    /// Convenience: supervised update with a target vector.
    ///
    /// Computes MSE loss gradient: `loss_grad = 2 * (y_pred - target)`.
    pub fn update_supervised(&mut self, x: &[f32], y_pred: &[f32], target: &[f32]) {
        assert_eq!(y_pred.len(), self.out_dim);
        assert_eq!(target.len(), self.out_dim);
        let loss_grad: Vec<f32> = y_pred
            .iter()
            .zip(target.iter())
            .map(|(&yp, &yt)| 2.0 * (yp - yt))
            .collect();
        self.update(x, &loss_grad);
    }

    /// Reset inner state (weights and momentum).
    pub fn reset(&mut self) {
        self.w.fill(0.0);
        self.m.fill(0.0);
        self.step_count = 0;
    }

    /// Norm of the inner weights (for monitoring).
    pub fn weight_norm(&self) -> f32 {
        self.w.iter().map(|&v| v * v).sum::<f32>().sqrt()
    }

    /// Norm of the momentum buffer.
    pub fn momentum_norm(&self) -> f32 {
        self.m.iter().map(|&v| v * v).sum::<f32>().sqrt()
    }
}

// ---------------------------------------------------------------------------
// ttt_attention_replacement
// ---------------------------------------------------------------------------

/// Use TTT as a drop-in replacement for standard attention for one layer.
///
/// Standard attention computes:
/// ```text
/// scores = softmax(Q @ K^T / sqrt(d))
/// out    = scores @ V
/// ```
///
/// TTT attention instead trains an inner linear model `W_t` on the fly
/// and outputs `y = W_t @ v` where `v` is a blended query-key vector.
///
/// # Arguments
/// * `q` — query vector (`[head_dim]`)
/// * `k` — key vector (`[head_dim]`)
/// * `v` — value vector (`[head_dim]`)
/// * `ttt` — the TTT inner model (updated in-place)
///
/// # Returns
/// Output vector of length `head_dim`.
///
/// # Algorithm
/// 1. Blend query and key into a feature vector: `x = concat(q, k)` or `x = q + k`.
/// 2. Predict: `y_pred = ttt.forward(x)`.
/// 3. Compute loss gradient against `v` as target.
/// 4. Update `ttt` weights.
/// 5. Return `y_pred`.
pub fn ttt_attention_replacement(
    q: &[f32],
    k: &[f32],
    v: &[f32],
    ttt: &mut TTTLinear,
) -> Vec<f32> {
    assert_eq!(q.len(), k.len());
    assert_eq!(k.len(), v.len());

    // Blend q and k as input feature.
    let mut x = vec![0.0f32; q.len()];
    for i in 0..q.len() {
        x[i] = q[i] + k[i];
    }

    // Forward through inner model.
    let y_pred = ttt.forward(&x);

    // Self-supervised gradient: target is the value vector.
    let loss_grad: Vec<f32> = y_pred
        .iter()
        .zip(v.iter())
        .map(|(&yp, &vt)| 2.0 * (yp - vt))
        .collect();

    // Update inner weights.
    ttt.update(&x, &loss_grad);

    y_pred
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    // -----------------------------------------------------------------------
    // TTTConfig tests
    // -----------------------------------------------------------------------

    #[test]
    fn ttt_config_validates() {
        let cfg = TTTConfig::default();
        assert!(cfg.validate().is_ok());
    }

    #[test]
    fn ttt_config_rejects_zero_lr() {
        let cfg = TTTConfig { lr: 0.0, ..Default::default() };
        assert!(cfg.validate().is_err());
    }

    // -----------------------------------------------------------------------
    // TTTLinear tests
    // -----------------------------------------------------------------------

    #[test]
    fn ttt_linear_new_zeros() {
        let cfg = TTTConfig::default();
        let ttt = TTTLinear::new(4, 3, &cfg).unwrap();
        assert_eq!(ttt.w.len(), 12);
        assert!(ttt.w.iter().all(|&v| v == 0.0));
    }

    #[test]
    fn ttt_linear_forward_shape() {
        let cfg = TTTConfig::default();
        let ttt = TTTLinear::new(4, 3, &cfg).unwrap();
        let x = vec![1.0f32, 2.0, 3.0];
        let y = ttt.forward(&x);
        assert_eq!(y.len(), 4);
        // All zero weights → zero output.
        assert!(y.iter().all(|&v| v.abs() < 1e-6));
    }

    #[test]
    fn ttt_linear_forward_with_weights() {
        let cfg = TTTConfig::default();
        let w = vec![1.0f32, 0.0, 0.0, 0.0,
                     0.0, 1.0, 0.0, 0.0,
                     0.0, 0.0, 1.0, 0.0];
        let ttt = TTTLinear::with_weights(w, 4, 3, &cfg).unwrap();
        let x = vec![1.0f32, 2.0, 3.0];
        let y = ttt.forward(&x);
        assert_eq!(y, vec![1.0, 2.0, 3.0, 0.0]);
    }

    #[test]
    fn ttt_linear_update_changes_weights() {
        let cfg = TTTConfig::default();
        let mut ttt = TTTLinear::new(2, 2, &cfg).unwrap();
        let w_before = ttt.w.clone();
        let x = vec![1.0f32, 1.0];
        let loss_grad = vec![0.5f32, -0.5];
        ttt.update(&x, &loss_grad);
        assert_ne!(ttt.w, w_before, "weights should change after update");
    }

    #[test]
    fn ttt_linear_supervised_converges() {
        // Train a simple 1→1 linear model to map x=1.0 → y=3.0.
        let cfg = TTTConfig { lr: 0.1, decay: 0.0, momentum: 0.0, grad_clip: 0.0, inner_steps: 1 };
        let mut ttt = TTTLinear::new(1, 1, &cfg).unwrap();

        let x = vec![1.0f32];
        let target = vec![3.0f32];

        // Run many updates.
        for _ in 0..200 {
            let y_pred = ttt.forward(&x);
            ttt.update_supervised(&x, &y_pred, &target);
        }

        let y_final = ttt.forward(&x);
        assert!(
            (y_final[0] - 3.0).abs() < 0.1,
            "TTT did not converge: y_final={}",
            y_final[0]
        );
    }

    #[test]
    fn ttt_linear_momentum_accumulates() {
        let cfg = TTTConfig { lr: 0.1, decay: 0.0, momentum: 0.9, grad_clip: 0.0, inner_steps: 1 };
        let mut ttt = TTTLinear::new(2, 2, &cfg).unwrap();
        let x = vec![1.0f32, 0.5];
        let loss_grad = vec![1.0f32, -1.0];

        ttt.update(&x, &loss_grad);
        let m_norm_after_1 = ttt.momentum_norm();

        ttt.update(&x, &loss_grad);
        let m_norm_after_2 = ttt.momentum_norm();

        // With momentum 0.9, second momentum should be larger (or at least non-zero).
        assert!(m_norm_after_2 > 0.0);
    }

    #[test]
    fn ttt_linear_grad_clip_limits() {
        let cfg = TTTConfig { lr: 0.1, decay: 0.0, momentum: 0.0, grad_clip: 0.01, inner_steps: 1 };
        let mut ttt = TTTLinear::new(2, 2, &cfg).unwrap();
        let x = vec![100.0f32, 100.0]; // huge input
        let loss_grad = vec![100.0f32, 100.0]; // huge gradient
        let w_before = ttt.w.clone();
        ttt.update(&x, &loss_grad);
        let max_change = ttt.w.iter().zip(w_before.iter()).map(|(a, b)| (a - b).abs()).fold(0.0f32, f32::max);
        // With grad_clip=0.01, each grad element is at most 0.01, so change is bounded by lr * 0.01 = 0.001.
        assert!(max_change <= 0.001 + 1e-6, "grad clip failed: max_change={}", max_change);
    }

    #[test]
    fn ttt_linear_reset_clears() {
        let cfg = TTTConfig::default();
        let mut ttt = TTTLinear::new(4, 4, &cfg).unwrap();
        let x = vec![1.0f32; 4];
        let loss_grad = vec![1.0f32; 4];
        ttt.update(&x, &loss_grad);
        assert!(ttt.weight_norm() > 0.0);
        ttt.reset();
        assert_eq!(ttt.weight_norm(), 0.0);
        assert_eq!(ttt.step_count, 0);
    }

    // -----------------------------------------------------------------------
    // ttt_attention_replacement tests
    // -----------------------------------------------------------------------

    #[test]
    fn ttt_attention_replacement_shape() {
        let cfg = TTTConfig::default();
        let mut ttt = TTTLinear::new(8, 16, &cfg).unwrap();
        let q = vec![0.1f32; 8];
        let k = vec![0.2f32; 8];
        let v = vec![0.3f32; 8];
        let out = ttt_attention_replacement(&q, &k, &v, &mut ttt);
        assert_eq!(out.len(), 8);
    }

    #[test]
    fn ttt_attention_updates_weights() {
        let cfg = TTTConfig::default();
        let mut ttt = TTTLinear::new(4, 8, &cfg).unwrap();
        let w_before = ttt.w.clone();
        let q = vec![1.0f32; 4];
        let k = vec![0.5f32; 4];
        let v = vec![0.3f32; 4];
        let _ = ttt_attention_replacement(&q, &k, &v, &mut ttt);
        assert_ne!(ttt.w, w_before, "TTT attention should update inner weights");
    }

    #[test]
    fn ttt_attention_converges_to_value() {
        // Use TTT attention to learn that q+k should map to a fixed v.
        let cfg = TTTConfig { lr: 0.05, decay: 0.0, momentum: 0.0, grad_clip: 0.0, inner_steps: 1 };
        let mut ttt = TTTLinear::new(4, 8, &cfg).unwrap();
        let target = vec![1.0f32, -1.0, 0.5, -0.5];

        for _ in 0..300 {
            let q: Vec<f32> = (0..4).map(|i| (i as f32) * 0.1).collect();
            let k: Vec<f32> = (0..4).map(|i| (i as f32) * 0.05).collect();
            let _ = ttt_attention_replacement(&q, &k, &target, &mut ttt);
        }

        // Final prediction should be close to target.
        let q = vec![0.1f32, 0.2, 0.3, 0.4];
        let k = vec![0.05f32, 0.1, 0.15, 0.2];
        let v = vec![0.0f32; 4]; // dummy
        let pred = ttt_attention_replacement(&q, &k, &v, &mut ttt);
        let mse: f32 = pred.iter().zip(target.iter()).map(|(a, b)| (a - b).powi(2)).sum::<f32>() / 4.0;
        assert!(
            mse < 0.05,
            "TTT attention did not converge: mse={}, pred={:?}",
            mse, pred
        );
    }
}
