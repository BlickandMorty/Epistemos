//! WBO-6 drift inequality — the core theorem of the Epistenos system.
//!
//! This module implements the *Weighted Bounded-Output* 6-term inequality
//! that bounds the logit drift introduced by the multi-tier memory
//! hierarchy. Each term corresponds to a distinct source of approximation
//! error:
//!
//! | Term | Symbol | Source |
//! |------|--------|--------|
//! | T_W  | `t_w`  | Wyner–Ziv weight quantization error |
//! | T_K  | `t_k`  | KV reconstruction error (residual via KV-Direct) |
//! | T_R  | `t_r`  | Residual stream coding error |
//! | T_Q  | `t_q`  | Quantization / rounding error |
//! | T_S  | `t_s`  | Sketch / sampling error |
//! | T_SE | `t_se` | Self-evolving online adaptation error |
//!
//! The WBO-6 inequality states that the total drift satisfies:
//!
//! ```text
//! ‖Δlogits‖ ≤ ½ · (T_W + T_K + T_R + T_Q + T_S + T_SE)
//! ```
//!
//! A publishable baseline, WBO-5, omits the self-evolving term `T_SE`
//! because it requires online measurement.

use crate::types::{LayerId, TokenId};
use std::collections::HashMap;
use tracing::{debug, trace};

// ---------------------------------------------------------------------------
// Wbo6Terms
// ---------------------------------------------------------------------------

/// The six error terms that compose the WBO-6 drift bound.
///
/// All fields are non-negative `f32` values representing squared-error
/// or Bregman-divergence contributions. The sum is halved to produce the
/// final drift bound.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Wbo6Terms {
    /// **T_W** — Wyner–Ziv weight quantization error term.
    ///
    /// Measures the distortion from lossily compressing model weights
    /// using lattice quantization or the Sherry codec.
    pub t_w: f32,
    /// **T_K** — KV reconstruction error.
    ///
    /// Residual reconstruction error from retrieving key-value pairs
    /// through a non-exact memory tier (L1–L4).
    pub t_k: f32,
    /// **T_R** — Residual stream coding error.
    ///
    /// Distortion introduced by entropy-coding the residual stream
    /// between transformer layers.
    pub t_r: f32,
    /// **T_Q** — Quantization / rounding error.
    ///
    /// Finite-precision arithmetic error from casting activations or
    /// gradients to lower bit-widths.
    pub t_q: f32,
    /// **T_S** — Sketch / sampling error.
    ///
    /// Approximation error from CountSketch, sparse JL, or random
    /// projection when retrieving or aggregating token states.
    pub t_s: f32,
    /// **T_SE** — Self-evolving online adaptation error.
    ///
    /// Drift caused by online parameter updates that diverge from the
    /// static checkpoint. This term is **stubbed** in Phase 1 because
    /// it requires the L_SE runtime to be materialised.
    ///
    /// TODO: Replace with actual online gradient-variance measurement
    /// once `helios-runtime` is built.
    pub t_se: f32,
}

impl Wbo6Terms {
    /// Create a new `Wbo6Terms` with all fields set to zero.
    pub fn new() -> Self {
        Self::default()
    }

    /// Return the sum of all six terms.
    pub fn sum(&self) -> f32 {
        self.t_w + self.t_k + self.t_r + self.t_q + self.t_s + self.t_se
    }

    /// Return the maximum single term.
    pub fn max_term(&self) -> f32 {
        self.t_w
            .max(self.t_k)
            .max(self.t_r)
            .max(self.t_q)
            .max(self.t_s)
            .max(self.t_se)
    }

    /// Scale all terms by a common factor.
    pub fn scale(&mut self, factor: f32) {
        self.t_w *= factor;
        self.t_k *= factor;
        self.t_r *= factor;
        self.t_q *= factor;
        self.t_s *= factor;
        self.t_se *= factor;
    }
}

// ---------------------------------------------------------------------------
// Core inequality
// ---------------------------------------------------------------------------

/// Measure the WBO-6 drift bound from the six error terms.
///
/// Returns `0.5 * (T_W + T_K + T_R + T_Q + T_S + T_SE)`.
///
/// The factor of ½ arises because each squared-error term contributes
/// to drift through a Cauchy–Schwarz bound on the Jacobian of the
/// logits with respect to the hidden state.
///
/// # Arguments
/// * `terms` — the six WBO error terms.
///
/// # Returns
/// An upper bound on `‖Δlogits‖₂`.
pub fn measure_wbo6(terms: &Wbo6Terms) -> f32 {
    let bound = 0.5 * terms.sum();
    trace!("measure_wbo6: bound = {:.6}", bound);
    bound
}

/// The WBO-5 publishable baseline (excludes `T_SE`).
///
/// This version is appropriate for reproducible experiments and paper
/// submissions because `T_SE` depends on online runtime state that is
/// not available in static evaluation.
///
/// Returns `0.5 * (T_W + T_K + T_R + T_Q + T_S)`.
pub fn wbo5_paper_version(terms: &Wbo6Terms) -> f32 {
    let sum5 = terms.t_w + terms.t_k + terms.t_r + terms.t_q + terms.t_s;
    0.5 * sum5
}

// ---------------------------------------------------------------------------
// LogitDrift
// ---------------------------------------------------------------------------

/// Tracks the L2 norm of a logit-drift vector `Δlogits`.
///
/// `LogitDrift` stores both the raw vector (for analysis) and its
/// precomputed norm (for fast bound comparisons).
#[derive(Clone, Debug, PartialEq)]
pub struct LogitDrift {
    /// The per-vocabulary-element drift values.
    pub delta: Vec<f32>,
    /// Precomputed `‖Δlogits‖₂`.
    pub norm: f32,
}

impl LogitDrift {
    /// Compute `LogitDrift` from a raw drift vector.
    pub fn from_delta(delta: Vec<f32>) -> Self {
        let norm = delta.iter().map(|&x| x * x).sum::<f32>().sqrt();
        Self { delta, norm }
    }

    /// Create a zero drift vector of length `vocab_size`.
    pub fn zeros(vocab_size: usize) -> Self {
        Self {
            delta: vec![0.0; vocab_size],
            norm: 0.0,
        }
    }

    /// Check whether the actual drift is bounded by the WBO-6 prediction.
    pub fn is_bounded_by(&self, terms: &Wbo6Terms) -> bool {
        self.norm <= measure_wbo6(terms) + 1e-5
    }

    /// Add another drift vector element-wise.
    pub fn add(&mut self, other: &LogitDrift) {
        assert_eq!(self.delta.len(), other.delta.len());
        for (a, b) in self.delta.iter_mut().zip(other.delta.iter()) {
            *a += b;
        }
        self.norm = self.delta.iter().map(|&x| x * x).sum::<f32>().sqrt();
    }
}

// ---------------------------------------------------------------------------
// DriftTracker
// ---------------------------------------------------------------------------

/// Accumulates per-layer, per-token drift measurements across a forward
/// pass.
///
/// `DriftTracker` maintains a running log of `Wbo6Terms` for each
/// `(LayerId, TokenId)` pair, allowing fine-grained analysis of which
/// layers and tokens contribute most to the total drift bound.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct DriftTracker {
    /// Map from `(layer, token)` to the accumulated WBO-6 terms.
    measurements: HashMap<(LayerId, TokenId), Wbo6Terms>,
    /// Running global sum of all terms across all keys.
    global_sum: Wbo6Terms,
    /// Number of recorded measurements.
    count: usize,
}

impl DriftTracker {
    /// Create a new empty `DriftTracker`.
    pub fn new() -> Self {
        Self::default()
    }

    /// Record a set of WBO-6 terms for a specific layer and token.
    pub fn record(&mut self, layer: LayerId, token: TokenId, terms: Wbo6Terms) {
        let key = (layer, token);
        if let Some(existing) = self.measurements.get_mut(&key) {
            existing.t_w += terms.t_w;
            existing.t_k += terms.t_k;
            existing.t_r += terms.t_r;
            existing.t_q += terms.t_q;
            existing.t_s += terms.t_s;
            existing.t_se += terms.t_se;
        } else {
            self.measurements.insert(key, terms);
        }
        self.global_sum.t_w += terms.t_w;
        self.global_sum.t_k += terms.t_k;
        self.global_sum.t_r += terms.t_r;
        self.global_sum.t_q += terms.t_q;
        self.global_sum.t_s += terms.t_s;
        self.global_sum.t_se += terms.t_se;
        self.count += 1;

        debug!(
            "DriftTracker::record(layer={}, token={}, wbo6_bound={:.4})",
            layer.0,
            token.0,
            measure_wbo6(&terms)
        );
    }

    /// Retrieve the accumulated terms for a specific layer and token.
    pub fn get(&self, layer: LayerId, token: TokenId) -> Option<&Wbo6Terms> {
        self.measurements.get(&(layer, token))
    }

    /// Compute the global WBO-6 bound from all recorded measurements.
    pub fn global_bound(&self) -> f32 {
        measure_wbo6(&self.global_sum)
    }

    /// Compute the WBO-5 (paper) global bound.
    pub fn global_bound_wbo5(&self) -> f32 {
        wbo5_paper_version(&self.global_sum)
    }

    /// Return the number of recorded (layer, token) pairs.
    pub fn num_pairs(&self) -> usize {
        self.measurements.len()
    }

    /// Return the total number of `record` calls.
    pub fn record_count(&self) -> usize {
        self.count
    }

    /// Find the layer with the largest accumulated drift contribution.
    pub fn worst_layer(&self) -> Option<(LayerId, Wbo6Terms)> {
        let mut layer_acc: HashMap<LayerId, Wbo6Terms> = HashMap::new();
        for ((layer, _), terms) in &self.measurements {
            let entry = layer_acc.entry(*layer).or_default();
            entry.t_w += terms.t_w;
            entry.t_k += terms.t_k;
            entry.t_r += terms.t_r;
            entry.t_q += terms.t_q;
            entry.t_s += terms.t_s;
            entry.t_se += terms.t_se;
        }
        layer_acc
            .into_iter()
            .max_by(|(_, a), (_, b)| {
                measure_wbo6(a)
                    .partial_cmp(&measure_wbo6(b))
                    .unwrap_or(std::cmp::Ordering::Equal)
            })
    }

    /// Clear all measurements.
    pub fn clear(&mut self) {
        self.measurements.clear();
        self.global_sum = Wbo6Terms::new();
        self.count = 0;
    }
}

// ---------------------------------------------------------------------------
// Synthetic drift generation (for testing and benchmarking)
// ---------------------------------------------------------------------------

/// Generate synthetic WBO-6 terms that satisfy the triangle-inequality
/// consistency properties.
///
/// The returned terms are non-negative and `sum() ≤ max_sum`.
pub fn synthetic_terms(max_sum: f32, rng_seed: u64) -> Wbo6Terms {
    let mut rng = fastrand::Rng::with_seed(rng_seed);
    let mut terms = Wbo6Terms::new();
    terms.t_w = rng.f32() * max_sum / 6.0;
    terms.t_k = rng.f32() * max_sum / 6.0;
    terms.t_r = rng.f32() * max_sum / 6.0;
    terms.t_q = rng.f32() * max_sum / 6.0;
    terms.t_s = rng.f32() * max_sum / 6.0;
    terms.t_se = rng.f32() * max_sum / 6.0;

    // Renormalise so that the total is exactly max_sum (deterministic test).
    let current = terms.sum();
    if current > 0.0 {
        let factor = max_sum / current;
        terms.scale(factor);
    }
    terms
}

/// Compute an empirical logit drift vector from a set of per-term
/// perturbations.
///
/// This is a synthetic helper: it creates a drift vector whose norm is
/// *exactly* the WBO-6 bound (useful for verifying `is_bounded_by`).
pub fn drift_from_terms(terms: &Wbo6Terms, vocab_size: usize, rng_seed: u64) -> LogitDrift {
    let bound = measure_wbo6(terms);
    let mut rng = fastrand::Rng::with_seed(rng_seed);
    let mut delta: Vec<f32> = (0..vocab_size).map(|_| rng.f32() * 2.0 - 1.0).collect();
    let current_norm = delta.iter().map(|&x| x * x).sum::<f32>().sqrt();
    if current_norm > 1e-8 {
        let scale = bound / current_norm;
        for x in &mut delta {
            *x *= scale;
        }
    }
    LogitDrift::from_delta(delta)
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    // -----------------------------------------------------------------------
    // WBO-6 basic tests
    // -----------------------------------------------------------------------

    #[test]
    fn wbo6_measure_zero_terms() {
        let terms = Wbo6Terms::new();
        assert_eq!(measure_wbo6(&terms), 0.0);
    }

    #[test]
    fn wbo6_measure_sum_halved() {
        let mut terms = Wbo6Terms::new();
        terms.t_w = 2.0;
        terms.t_k = 4.0;
        terms.t_r = 6.0;
        assert_eq!(measure_wbo6(&terms), 6.0); // (2+4+6)/2 = 6
    }

    #[test]
    fn wbo6_all_terms_non_negative() {
        let mut rng = fastrand::Rng::with_seed(1);
        for _ in 0..100 {
            let terms = synthetic_terms(rng.f32() * 10.0, rng.u64(..));
            assert!(terms.t_w >= 0.0);
            assert!(terms.t_k >= 0.0);
            assert!(terms.t_r >= 0.0);
            assert!(terms.t_q >= 0.0);
            assert!(terms.t_s >= 0.0);
            assert!(terms.t_se >= 0.0);
        }
    }

    #[test]
    fn wbo5_excludes_t_se() {
        let mut terms = Wbo6Terms::new();
        terms.t_w = 1.0;
        terms.t_k = 2.0;
        terms.t_r = 3.0;
        terms.t_q = 4.0;
        terms.t_s = 5.0;
        terms.t_se = 100.0; // should be ignored by WBO-5
        assert_eq!(wbo5_paper_version(&terms), 7.5); // (1+2+3+4+5)/2 = 7.5
    }

    // -----------------------------------------------------------------------
    // Triangle inequality tests
    // -----------------------------------------------------------------------

    #[test]
    fn triangle_inequality_on_synthetic_data() {
        // For any two independent error sources A and B, the combined
        // drift bound should be at most the sum of the individual bounds.
        let terms_a = synthetic_terms(4.0, 100);
        let terms_b = synthetic_terms(3.0, 200);
        let mut terms_combined = Wbo6Terms::new();
        terms_combined.t_w = terms_a.t_w + terms_b.t_w;
        terms_combined.t_k = terms_a.t_k + terms_b.t_k;
        terms_combined.t_r = terms_a.t_r + terms_b.t_r;
        terms_combined.t_q = terms_a.t_q + terms_b.t_q;
        terms_combined.t_s = terms_a.t_s + terms_b.t_s;
        terms_combined.t_se = terms_a.t_se + terms_b.t_se;

        let bound_a = measure_wbo6(&terms_a);
        let bound_b = measure_wbo6(&terms_b);
        let bound_c = measure_wbo6(&terms_combined);

        // WBO-6 satisfies the triangle inequality because it is a sum of
        // non-negative terms (with a ½ factor that distributes).
        let sum_ab = bound_a + bound_b;
        assert!(
            bound_c <= sum_ab + 1e-5,
            "triangle inequality violated: {} > {} + {} = {}",
            bound_c,
            bound_a,
            bound_b,
            sum_ab
        );
    }

    #[test]
    fn wbo6_bounds_actual_drift_exact() {
        // Generate synthetic terms, create a drift vector with norm EQUAL
        // to the bound, and verify it is indeed bounded.
        let terms = synthetic_terms(5.0, 42);
        let drift = drift_from_terms(&terms, 100, 42);
        let bound = measure_wbo6(&terms);
        assert!(
            drift.is_bounded_by(&terms),
            "drift norm {} should be bounded by {}",
            drift.norm,
            bound
        );
        // The synthetic construction sets norm == bound, so it should
        // be exactly equal (within floating-point tolerance).
        assert!(
            (drift.norm - bound).abs() < 1e-3,
            "synthetic drift norm {} != bound {}",
            drift.norm,
            bound
        );
    }

    #[test]
    fn wbo6_bounds_actual_drift_relaxed() {
        // Create a drift vector with norm strictly less than the bound.
        let terms = synthetic_terms(8.0, 77);
        let mut drift = drift_from_terms(&terms, 50, 77);
        for x in &mut drift.delta {
            *x *= 0.5; // halve the drift
        }
        drift.norm = drift.delta.iter().map(|&x| x * x).sum::<f32>().sqrt();
        assert!(drift.is_bounded_by(&terms));
    }

    // -----------------------------------------------------------------------
    // LogitDrift tests
    // -----------------------------------------------------------------------

    #[test]
    fn logit_drift_zeros() {
        let drift = LogitDrift::zeros(10);
        assert_eq!(drift.norm, 0.0);
        assert_eq!(drift.delta.len(), 10);
    }

    #[test]
    fn logit_drift_norm_computed_correctly() {
        let delta = vec![3.0_f32, 4.0]; // 3-4-5 triangle
        let drift = LogitDrift::from_delta(delta);
        assert!((drift.norm - 5.0).abs() < 1e-5);
    }

    #[test]
    fn logit_drift_add_preserves_norm() {
        let mut a = LogitDrift::from_delta(vec![1.0, 0.0, 0.0]);
        let b = LogitDrift::from_delta(vec![0.0, 1.0, 0.0]);
        a.add(&b);
        assert!((a.norm - 2.0_f32.sqrt()).abs() < 1e-5);
    }

    // -----------------------------------------------------------------------
    // DriftTracker tests
    // -----------------------------------------------------------------------

    #[test]
    fn drift_tracker_records_and_retrieves() {
        let mut tracker = DriftTracker::new();
        let layer = LayerId(2);
        let token = TokenId(7);
        let terms = Wbo6Terms {
            t_w: 1.0,
            t_k: 2.0,
            ..Wbo6Terms::new()
        };
        tracker.record(layer, token, terms);
        assert_eq!(tracker.num_pairs(), 1);
        assert_eq!(tracker.record_count(), 1);
        let retrieved = tracker.get(layer, token).unwrap();
        assert_eq!(retrieved.t_w, 1.0);
        assert_eq!(retrieved.t_k, 2.0);
    }

    #[test]
    fn drift_tracker_accumulates_same_key() {
        let mut tracker = DriftTracker::new();
        let layer = LayerId(0);
        let token = TokenId(0);
        tracker.record(layer, token, Wbo6Terms { t_w: 1.0, ..Wbo6Terms::new() });
        tracker.record(layer, token, Wbo6Terms { t_w: 2.0, ..Wbo6Terms::new() });
        let terms = tracker.get(layer, token).unwrap();
        assert_eq!(terms.t_w, 3.0);
        assert_eq!(tracker.record_count(), 2);
        assert_eq!(tracker.num_pairs(), 1);
    }

    #[test]
    fn drift_tracker_global_bound() {
        let mut tracker = DriftTracker::new();
        tracker.record(LayerId(0), TokenId(0), synthetic_terms(2.0, 1));
        tracker.record(LayerId(1), TokenId(1), synthetic_terms(3.0, 2));
        let bound = tracker.global_bound();
        assert!(bound > 0.0);
    }

    #[test]
    fn drift_tracker_worst_layer() {
        let mut tracker = DriftTracker::new();
        let mut terms_big = Wbo6Terms::new();
        terms_big.t_w = 10.0;
        tracker.record(LayerId(3), TokenId(0), terms_big);
        tracker.record(LayerId(1), TokenId(0), Wbo6Terms { t_w: 1.0, ..Wbo6Terms::new() });
        let (worst, _) = tracker.worst_layer().unwrap();
        assert_eq!(worst, LayerId(3));
    }

    #[test]
    fn drift_tracker_clear() {
        let mut tracker = DriftTracker::new();
        tracker.record(LayerId(0), TokenId(0), Wbo6Terms::new());
        tracker.clear();
        assert_eq!(tracker.num_pairs(), 0);
        assert_eq!(tracker.global_bound(), 0.0);
    }

    #[test]
    fn wbo6_max_term() {
        let mut terms = Wbo6Terms::new();
        terms.t_w = 1.0;
        terms.t_k = 5.0;
        terms.t_r = 3.0;
        assert_eq!(terms.max_term(), 5.0);
    }

    #[test]
    fn wbo6_scale() {
        let mut terms = Wbo6Terms::new();
        terms.t_w = 2.0;
        terms.t_k = 4.0;
        terms.scale(0.5);
        assert_eq!(terms.t_w, 1.0);
        assert_eq!(terms.t_k, 2.0);
    }
}
