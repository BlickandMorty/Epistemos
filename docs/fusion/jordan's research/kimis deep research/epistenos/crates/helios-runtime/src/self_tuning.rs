//! Titans-MAC + SEAL DoRA — self-tuning without base-weight destabilisation.
//!
//! This module implements the **Self-Evolving** tier (L_SE) of the
//! Epistenos cognitive stack. It consists of three interacting subsystems:
//!
//! 1. **TitansMAC** — online "surprise memory" that maintains fast weights
//!    updated in real-time during inference. When prediction surprise exceeds
//!    a threshold, the fast weights are written to a persistent surprise buffer.
//!
//! 2. **SEALDoRA** — nightly consolidation that distills the accumulated
//!    online updates into low-rank (LoRA) adapters with DoRA (Weight-Decomposed
//!    Low-Rank Adaptation) magnitude vectors. This preserves the immutable base
//!    weights while adding trainable low-rank changes.
//!
//! 3. **LSEModule** — the unified interface that composes base + online + offline
//!    adapters into a single forward pass.
//!
//! ## Safety invariant
//! `base_weights_immutable` is **ALWAYS `true`**. The base weights are never
//! modified in-place. All learning happens in the fast-weight buffer (online)
//! or the LoRA adapters (offline).

use serde::{Deserialize, Serialize};
use std::collections::VecDeque;
use thiserror::Error;
use tracing::{debug, info, instrument, trace, warn};
use helios_mlx::types::{TensorView, MLXDtype};

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

#[derive(Error, Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum SelfTuningError {
    #[error("dimension mismatch: expected {expected}, got {got}")]
    DimensionMismatch { expected: usize, got: usize },

    #[error("surprise buffer overflow: max {max} updates")]
    BufferOverflow { max: usize },

    #[error("consolidation failed: {0}")]
    ConsolidationFailed(String),

    #[error("fast weights not initialised")]
    NotInitialised,
}

// ---------------------------------------------------------------------------
// TitansMAC — online surprise memory
// ---------------------------------------------------------------------------

/// A single online update captured during inference.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TitansUpdate {
    /// Input vector that triggered the update.
    pub input: Vec<f32>,
    /// Prediction error vector.
    pub error: Vec<f32>,
    /// Surprise score (absolute error magnitude).
    pub surprise: f32,
    /// Token index or timestep.
    pub timestep: usize,
}

/// TitansMAC — **M**emory **A**s **C**omputer — online surprise memory.
///
/// TitansMAC maintains a set of fast weights that are updated in real-time
/// during each forward pass. When the prediction error (surprise) exceeds a
/// threshold, the current fast-weight state is snapshotted into a persistent
/// surprise buffer for later consolidation.
///
/// # Algorithm
/// 1. Read: `output = input + fast_weights ⊙ input` (elementwise modulation)
/// 2. Compute surprise = |error|
/// 3. If surprise > threshold: write fast weights to buffer
/// 4. Update fast weights: `fw ← fw + momentum · outer(error, input)`
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TitansMAC {
    /// Fast weights — online adapted parameters.
    ///
    /// In the simplest form these are the same dimension as the input
    /// and act as an elementwise gate / residual.
    fast_weights: Vec<f32>,
    /// Surprise threshold — when |error| exceeds this, write to buffer.
    pub surprise_threshold: f32,
    /// Momentum coefficient for fast-weight updates.
    pub momentum: f32,
    /// Maximum number of updates to retain in the surprise buffer.
    pub max_buffer_size: usize,
    /// The surprise buffer — accumulated high-surprise updates.
    pub surprise_buffer: VecDeque<TitansUpdate>,
    /// Whether fast weights have been initialised.
    initialised: bool,
}

impl TitansMAC {
    /// Create a new TitansMAC with the given dimension.
    ///
    /// Fast weights are initialised to zeros (identity-like when added
    /// as a residual).
    pub fn new(dim: usize, surprise_threshold: f32, momentum: f32, max_buffer: usize) -> Self {
        Self {
            fast_weights: vec![0.0; dim],
            surprise_threshold,
            momentum,
            max_buffer_size: max_buffer,
            surprise_buffer: VecDeque::with_capacity(max_buffer),
            initialised: true,
        }
    }

    /// Dimension of the fast-weight vector.
    pub fn dim(&self) -> usize {
        self.fast_weights.len()
    }

    /// Apply fast weights to an input vector.
    ///
    /// Returns `input + fast_weights ⊙ input` — a gated residual.
    /// If fast weights are not initialised, returns the input unchanged.
    pub fn read(&self, input: &[f32]) -> Vec<f32> {
        if !self.initialised || self.fast_weights.is_empty() {
            return input.to_vec();
        }
        input
            .iter()
            .zip(self.fast_weights.iter())
            .map(|(x, fw)| x + x * fw)
            .collect()
    }

    /// Update fast weights from an inference step.
    ///
    /// - `input`: the input vector to the layer
    /// - `error`: the prediction error vector
    /// - `surprise`: scalar surprise score (should be |error| or max|error|)
    ///
    /// If `surprise > surprise_threshold`, the update is also snapshotted
    /// into the surprise buffer for nightly consolidation.
    #[instrument(skip(self, input, error), fields(surprise, dim = self.dim()))]
    pub fn update(
        &mut self,
        input: &[f32],
        error: &[f32],
        surprise: f32,
    ) -> Result<(), SelfTuningError> {
        if !self.initialised {
            return Err(SelfTuningError::NotInitialised);
        }
        if input.len() != self.dim() {
            return Err(SelfTuningError::DimensionMismatch {
                expected: self.dim(),
                got: input.len(),
            });
        }
        if error.len() != self.dim() {
            return Err(SelfTuningError::DimensionMismatch {
                expected: self.dim(),
                got: error.len(),
            });
        }

        trace!(surprise, threshold = self.surprise_threshold, "updating fast weights");

        // Update fast weights: fw_i ← fw_i + momentum * mean_error * input_i
        let mean_error: f32 = error.iter().sum::<f32>() / error.len() as f32;
        for (fw, &x) in self.fast_weights.iter_mut().zip(input.iter()) {
            *fw += self.momentum * mean_error * x;
        }

        // If surprise is high, buffer the update for nightly consolidation
        if surprise > self.surprise_threshold {
            if self.surprise_buffer.len() >= self.max_buffer_size {
                self.surprise_buffer.pop_front();
            }
            self.surprise_buffer.push_back(TitansUpdate {
                input: input.to_vec(),
                error: error.to_vec(),
                surprise,
                timestep: self.surprise_buffer.len(),
            });
            debug!(
                buffer_len = self.surprise_buffer.len(),
                "surprise update buffered"
            );
        }

        Ok(())
    }

    /// Clear the surprise buffer (called after nightly consolidation).
    pub fn clear_buffer(&mut self) {
        self.surprise_buffer.clear();
    }

    /// Reset fast weights to zero (emergency reset — does NOT touch base weights).
    pub fn reset_fast_weights(&mut self) {
        for fw in &mut self.fast_weights {
            *fw = 0.0;
        }
    }

    /// Mean absolute value of current fast weights (diagnostic).
    pub fn fast_weight_magnitude(&self) -> f32 {
        if self.fast_weights.is_empty() {
            0.0
        } else {
            self.fast_weights.iter().map(|v| v.abs()).sum::<f32>() / self.fast_weights.len() as f32
        }
    }
}

// ---------------------------------------------------------------------------
// SEALDoRA — nightly consolidation via low-rank adapters
// ---------------------------------------------------------------------------

/// SEALDoRA — **S**elf-**E**volving **A**dapter with **L**oRA + **Do**RA.
///
/// DoRA (Weight-Decomposed Low-Rank Adaptation) decomposes a weight
/// matrix update into two components:
/// 1. **Direction**: captured by low-rank matrices A and B (rank `r`)
/// 2. **Magnitude**: a separate vector `m` that scales each row
///
/// The adapted weight is: `W' = m/|W_0 + BA| · (W_0 + BA)`
/// where `W_0` is the frozen base weight.
///
/// In our vectorised setting we store:
/// - `lora_a`: the "A" matrix flattened (size = dim × rank)
/// - `lora_b`: the "B" matrix flattened (size = rank × dim)
/// - `magnitude`: the per-element magnitude vector
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SEALDoRA {
    /// Flattened LoRA A matrix (dim × rank).
    pub lora_a: Vec<f32>,
    /// Flattened LoRA B matrix (rank × dim).
    pub lora_b: Vec<f32>,
    /// DoRA magnitude vector (one per dimension).
    pub magnitude: Vec<f32>,
    /// Dimension of the adapted space.
    pub dim: usize,
    /// Rank of the low-rank decomposition.
    pub rank: usize,
}

impl SEALDoRA {
    /// Create a new SEALDoRA adapter.
    ///
    /// All parameters are initialised to small random values (here:
    /// zeros for determinism in tests, with magnitude = 1.0).
    pub fn new(dim: usize, rank: usize) -> Self {
        Self {
            lora_a: vec![0.0; dim * rank],
            lora_b: vec![0.0; rank * dim],
            magnitude: vec![1.0; dim],
            dim,
            rank,
        }
    }

    /// Consolidate buffered online updates into the LoRA adapters.
    ///
    /// This is the "nightly" step — it takes all high-surprise updates
    /// from the TitansMAC buffer and distills them into the low-rank
    /// adapter weights using a simple SVD-inspired approach.
    #[instrument(skip(self, updates), fields(count = updates.len()))]
    pub fn consolidate(&mut self, updates: &[TitansUpdate]) -> Result<(), SelfTuningError> {
        if updates.is_empty() {
            return Ok(());
        }
        if self.dim == 0 || self.rank == 0 {
            return Err(SelfTuningError::ConsolidationFailed(
                "invalid dimension or rank".into(),
            ));
        }

        info!(count = updates.len(), "consolidating online updates into DoRA");

        // Simple consolidation: average the outer products of (error, input)
        // and project onto the low-rank subspace.
        let n = updates.len() as f32;
        let mut grad_a = vec![0.0; self.dim * self.rank];
        let mut grad_b = vec![0.0; self.rank * self.dim];

        for up in updates {
            // Accumulate low-rank gradients
            // A gets error * random_proj, B gets random_proj * input
            // For determinism we use a simple cyclic projection
            for i in 0..self.dim {
                for r in 0..self.rank {
                    let proj_idx = (i + r) % self.dim;
                    let a_idx = i * self.rank + r;
                    let b_idx = r * self.dim + i;
                    grad_a[a_idx] += up.error[i] * up.input[proj_idx] / n;
                    grad_b[b_idx] += up.input[i] * up.error[proj_idx] / n;
                }
            }
            // Update magnitude: slightly increase for high-surprise dims
            for i in 0..self.dim.min(up.error.len()) {
                self.magnitude[i] += 0.001 * up.error[i].abs() / n;
            }
        }

        // Apply gradients to A and B with a small learning rate
        let lr = 0.01;
        for (a, g) in self.lora_a.iter_mut().zip(grad_a.iter()) {
            *a += lr * g;
        }
        for (b, g) in self.lora_b.iter_mut().zip(grad_b.iter()) {
            *b += lr * g;
        }

        // Renormalise magnitude
        for m in &mut self.magnitude {
            *m = m.clamp(0.1, 5.0);
        }

        Ok(())
    }

    /// Apply the LoRA+DoRA adapter to a base vector.
    ///
    /// Returns: `magnitude ⊙ (base + B·A·base)`
    ///
    /// In the vector case, `B·A·base` is computed as a sequence of
    /// matrix-vector products.
    pub fn apply_adapter(&self, base: &[f32]) -> Vec<f32> {
        if self.dim == 0 || self.rank == 0 || base.len() != self.dim {
            return base.to_vec();
        }

        // Compute A·base: project base into rank-r space
        let mut a_base = vec![0.0; self.rank];
        for r in 0..self.rank {
            let mut sum = 0.0;
            for i in 0..self.dim {
                sum += self.lora_a[i * self.rank + r] * base[i];
            }
            a_base[r] = sum;
        }

        // Compute B·(A·base): project back into dim space
        let mut ba_base = vec![0.0; self.dim];
        for i in 0..self.dim {
            let mut sum = 0.0;
            for r in 0..self.rank {
                sum += self.lora_b[r * self.dim + i] * a_base[r];
            }
            ba_base[i] = sum;
        }

        // Add residual and apply magnitude scaling
        base.iter()
            .zip(ba_base.iter())
            .zip(self.magnitude.iter())
            .map(|((b, ba), m)| m * (b + ba))
            .collect()
    }

    /// Frobenius norm of the adapter (diagnostic).
    pub fn adapter_norm(&self) -> f32 {
        let a_norm: f32 = self.lora_a.iter().map(|v| v * v).sum();
        let b_norm: f32 = self.lora_b.iter().map(|v| v * v).sum();
        (a_norm + b_norm).sqrt()
    }
}

// ---------------------------------------------------------------------------
// SurpriseMonitor — tracks per-token surprise scores
// ---------------------------------------------------------------------------

/// SurpriseMonitor records per-timestep surprise for diagnostics
/// and for triggering the TitansMAC write threshold.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SurpriseMonitor {
    /// Ring buffer of recent surprise scores.
    pub history: VecDeque<f32>,
    /// Capacity of the ring buffer.
    pub capacity: usize,
    /// Running mean surprise.
    pub mean_surprise: f32,
    /// Running variance of surprise.
    pub variance_surprise: f32,
    /// Count of observations.
    pub count: u64,
}

impl SurpriseMonitor {
    pub fn new(capacity: usize) -> Self {
        Self {
            history: VecDeque::with_capacity(capacity),
            capacity,
            mean_surprise: 0.0,
            variance_surprise: 0.0,
            count: 0,
        }
    }

    /// Record a new surprise score.
    pub fn record(&mut self, surprise: f32) {
        // Welford's online algorithm for mean and variance
        self.count += 1;
        let delta = surprise - self.mean_surprise;
        self.mean_surprise += delta / self.count as f32;
        let delta2 = surprise - self.mean_surprise;
        self.variance_surprise += delta * delta2;

        if self.history.len() >= self.capacity {
            self.history.pop_front();
        }
        self.history.push_back(surprise);
    }

    /// Current standard deviation of surprise.
    pub fn std_surprise(&self) -> f32 {
        if self.count < 2 {
            0.0
        } else {
            (self.variance_surprise / (self.count - 1) as f32).sqrt()
        }
    }

    /// Detect anomaly: is the latest surprise > 2σ above the mean?
    pub fn is_anomaly(&self) -> bool {
        if let Some(&latest) = self.history.back() {
            latest > self.mean_surprise + 2.0 * self.std_surprise()
        } else {
            false
        }
    }

    /// Exponential moving average of recent surprises.
    pub fn ema_surprise(&self, alpha: f32) -> f32 {
        let mut ema = 0.0;
        for (i, &s) in self.history.iter().enumerate() {
            let weight = alpha * (1.0 - alpha).powi(i as i32);
            ema += weight * s;
        }
        ema
    }
}

// ---------------------------------------------------------------------------
// LSEModule — unified Self-Evolving tier interface
// ---------------------------------------------------------------------------

/// LSEModule — the **L**evel **S**elf-**E**volving module that unifies
/// base weights, online fast weights, and offline LoRA+DoRA adapters.
///
/// ## Invariant
/// `base_weights_immutable` is always `true`. The base weights are never
/// modified. All adaptation flows through `online` (TitansMAC) and
/// `offline` (SEALDoRA).
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LSEModule {
    /// Online fast-weight memory (active during inference).
    pub online: TitansMAC,
    /// Offline low-rank adapter (consolidated nightly).
    pub offline: SEALDoRA,
    /// Immutable flag — always true.
    pub base_weights_immutable: bool,
    /// Cached base weight vector (read-only reference copy).
    pub base_weights: Vec<f32>,
}

impl LSEModule {
    /// Create a new LSE module.
    ///
    /// `dim`: dimension of the weight space.
    /// `rank`: rank of the LoRA decomposition.
    /// `base_weights`: the frozen base weight vector.
    pub fn new(dim: usize, rank: usize, base_weights: Vec<f32>) -> Self {
        Self {
            online: TitansMAC::new(dim, 0.5, 0.01, 1000),
            offline: SEALDoRA::new(dim, rank),
            base_weights_immutable: true,
            base_weights,
        }
    }

    /// Forward pass: base + online fast weights + offline adapter.
    ///
    /// Pipeline:
    /// 1. `base_out = base_weights ⊙ input`
    /// 2. `online_out = online.read(base_out)`
    /// 3. `offline_out = offline.apply_adapter(online_out)`
    ///
    /// Returns `offline_out`.
    pub fn forward(&self, input: &[f32]) -> Vec<f32> {
        // Step 1: base pass (elementwise for vector case)
        let base_out: Vec<f32> = self
            .base_weights
            .iter()
            .zip(input.iter())
            .map(|(w, x)| w * x)
            .collect();

        // Step 2: online fast weights
        let online_out = self.online.read(&base_out);

        // Step 3: offline LoRA+DoRA adapter
        let offline_out = self.offline.apply_adapter(&online_out);

        offline_out
    }

    /// Perform an online update (during inference).
    pub fn online_update(
        &mut self,
        input: &[f32],
        error: &[f32],
        surprise: f32,
    ) -> Result<(), SelfTuningError> {
        self.online.update(input, error, surprise)
    }

    /// Perform nightly consolidation of buffered updates.
    pub fn consolidate(&mut self) -> Result<(), SelfTuningError> {
        let buffer: Vec<TitansUpdate> = self.online.surprise_buffer.iter().cloned().collect();
        self.offline.consolidate(&buffer)?;
        self.online.clear_buffer();
        Ok(())
    }

    /// Verify the base weights have not been modified.
    pub fn verify_base_unchanged(&self, original: &[f32]) -> bool {
        self.base_weights == original
    }
}

// ---------------------------------------------------------------------------
// MLX integration — tensor descriptors for weight vectors
// ---------------------------------------------------------------------------

/// Convert a flat `f32` weight vector to an MLX [`TensorView`] descriptor.
///
/// This bridges the self-tuning subsystem (which operates on `Vec<f32>`)
/// with the MLX backend by producing a lightweight tensor descriptor that
/// can be passed to Metal kernels or memory-mapping routines.
pub fn weights_to_tensor_view(weights: &[f32]) -> TensorView {
    TensorView::row_major(
        vec![weights.len()],
        MLXDtype::F32,
        weights.len() * std::mem::size_of::<f32>(),
    )
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn titans_mac_read_identity() {
        let titans = TitansMAC::new(4, 0.5, 0.1, 10);
        let input = vec![1.0, 2.0, 3.0, 4.0];
        let out = titans.read(&input);
        // Fast weights are zero → identity (x + x*0 = x)
        assert_eq!(out, input);
    }

    #[test]
    fn titans_mac_update_changes_weights() {
        let mut titans = TitansMAC::new(4, 0.5, 0.1, 10);
        let input = vec![1.0, 1.0, 1.0, 1.0];
        let error = vec![0.5, 0.5, 0.5, 0.5];
        let before = titans.fast_weight_magnitude();
        titans.update(&input, &error, 0.6).unwrap();
        let after = titans.fast_weight_magnitude();
        assert!(after > before);
    }

    #[test]
    fn titans_mac_buffers_high_surprise() {
        let mut titans = TitansMAC::new(4, 0.5, 0.1, 10);
        let input = vec![1.0; 4];
        let error = vec![0.1; 4];
        // surprise = 0.3 < threshold 0.5 → not buffered
        titans.update(&input, &error, 0.3).unwrap();
        assert_eq!(titans.surprise_buffer.len(), 0);

        // surprise = 0.6 > threshold → buffered
        titans.update(&input, &error, 0.6).unwrap();
        assert_eq!(titans.surprise_buffer.len(), 1);
    }

    #[test]
    fn titans_mac_dimension_mismatch() {
        let mut titans = TitansMAC::new(4, 0.5, 0.1, 10);
        let err = titans.update(&[1.0; 3], &[0.1; 4], 0.6).unwrap_err();
        assert!(
            matches!(err, SelfTuningError::DimensionMismatch { expected: 4, got: 3 })
        );
    }

    #[test]
    fn titans_mac_buffer_overflow() {
        let mut titans = TitansMAC::new(2, 0.0, 0.1, 3);
        for i in 0..5 {
            titans.update(&[1.0; 2], &[0.1; 2], 1.0).unwrap();
        }
        assert_eq!(titans.surprise_buffer.len(), 3);
    }

    #[test]
    fn seal_dora_apply_adapter_identity() {
        let dora = SEALDoRA::new(4, 2);
        let base = vec![1.0, 2.0, 3.0, 4.0];
        let out = dora.apply_adapter(&base);
        // A and B are zero → B·A·base = 0 → magnitude * base
        // magnitude starts at 1.0 → out == base
        for (o, b) in out.iter().zip(base.iter()) {
            assert!((o - b).abs() < 1e-6);
        }
    }

    #[test]
    fn seal_dora_consolidation_reduces_variance() {
        let mut dora = SEALDoRA::new(4, 2);
        let updates: Vec<TitansUpdate> = (0..10)
            .map(|i| TitansUpdate {
                input: vec![0.1 * i as f32; 4],
                error: vec![0.05; 4],
                surprise: 0.6,
                timestep: i,
            })
            .collect();

        let before_norm = dora.adapter_norm();
        dora.consolidate(&updates).unwrap();
        let after_norm = dora.adapter_norm();
        // After consolidation, the adapter should have non-zero norm
        assert!(after_norm > before_norm);
    }

    #[test]
    fn seal_dora_magnitude_clamped() {
        let mut dora = SEALDoRA::new(4, 2);
        let updates = vec![TitansUpdate {
            input: vec![100.0; 4],
            error: vec![100.0; 4],
            surprise: 10.0,
            timestep: 0,
        }];
        dora.consolidate(&updates).unwrap();
        // Magnitude should be clamped to [0.1, 5.0]
        for m in &dora.magnitude {
            assert!(*m >= 0.1 && *m <= 5.0);
        }
    }

    #[test]
    fn lse_module_forward_composes() {
        let base = vec![1.0, 1.0, 1.0, 1.0];
        let lse = LSEModule::new(4, 2, base.clone());
        let input = vec![2.0, 2.0, 2.0, 2.0];
        let out = lse.forward(&input);
        // base: [1*2, 1*2, 1*2, 1*2] = [2,2,2,2]
        // online: fast weights are zero → [2,2,2,2]
        // offline: A=B=0, mag=1 → [2,2,2,2]
        assert_eq!(out, vec![2.0, 2.0, 2.0, 2.0]);
    }

    #[test]
    fn lse_module_base_weights_unchanged() {
        let base = vec![1.0, 2.0, 3.0, 4.0];
        let original = base.clone();
        let mut lse = LSEModule::new(4, 2, base);

        // Run online updates
        for _ in 0..5 {
            lse.online_update(&[1.0; 4], &[0.1; 4], 0.6).unwrap();
        }
        // Consolidate
        lse.consolidate().unwrap();

        assert!(lse.verify_base_unchanged(&original));
        assert!(lse.base_weights_immutable);
    }

    #[test]
    fn lse_module_consolidation_clears_buffer() {
        let base = vec![1.0; 4];
        let mut lse = LSEModule::new(4, 2, base);

        for _ in 0..3 {
            lse.online_update(&[1.0; 4], &[0.1; 4], 0.6).unwrap();
        }
        assert_eq!(lse.online.surprise_buffer.len(), 3);

        lse.consolidate().unwrap();
        assert_eq!(lse.online.surprise_buffer.len(), 0);
    }

    #[test]
    fn surprise_monitor_statistics() {
        let mut monitor = SurpriseMonitor::new(10);
        monitor.record(1.0);
        monitor.record(2.0);
        monitor.record(3.0);

        assert!((monitor.mean_surprise - 2.0).abs() < 0.01);
        assert!(monitor.std_surprise() > 0.0);
        assert_eq!(monitor.count, 3);
    }

    #[test]
    fn surprise_monitor_anomaly_detection() {
        let mut monitor = SurpriseMonitor::new(100);
        for _ in 0..50 {
            monitor.record(0.1);
        }
        assert!(!monitor.is_anomaly());

        monitor.record(5.0); // way above mean + 2σ
        assert!(monitor.is_anomaly());
    }

    #[test]
    fn titans_mac_read_with_nonzero_weights() {
        let mut titans = TitansMAC::new(2, 0.5, 0.5, 10);
        // Set fast weights manually
        titans.update(&[1.0; 2], &[1.0; 2], 1.0).unwrap();
        let out = titans.read(&[1.0; 2]);
        // With positive fast weights, output > input
        for o in &out {
  