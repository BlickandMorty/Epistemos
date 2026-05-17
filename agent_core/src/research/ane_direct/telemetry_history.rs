//! Source:
//! - `docs/fusion/jordan's research/kimis deep research/EPISTEMOS_ANE_GLASS_BALL_ASSESSMENT.md`
//!   — "Aggregate power via SMC PSTR family; sampling cadence is the
//!   IOKit reporting interval (~100 Hz on M2 Pro). Instantaneous
//!   values are noisy; a rolling window is the honest signal."
//! - Companion to [`super::client::AneTelemetry`] (one instantaneous
//!   sample) + [`super::client::AneClient`] (the trait that produces
//!   samples).
//!
//! # Wave J8 — ANE telemetry rolling history
//!
//! Stores a fixed-capacity ring buffer of `AneTelemetry` samples and
//! exposes rolling-window statistics (mean, max, p95) over the
//! current contents. The "ANE busy" UI surface should consume the
//! rolling stats — never an instantaneous reading — to avoid the
//! single-sample flicker that SMC's ~100 Hz noise produces.
//!
//! ## Capacity choice
//!
//! Default capacity is 60 samples ≈ 0.6 seconds at 100 Hz. That window
//! smooths past SMC's reporting jitter while still reacting within
//! human-perceptible UI timescales. Callers may construct with a
//! different capacity; substrate floor uses `try_with_capacity` so a
//! zero capacity is a typed error rather than a panic.

use super::client::AneTelemetry;
use serde::{Deserialize, Serialize};
use std::collections::VecDeque;

pub const DEFAULT_HISTORY_CAPACITY: usize = 60;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AneTelemetryHistory {
    capacity: usize,
    samples: VecDeque<AneTelemetry>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum HistoryError {
    ZeroCapacity,
    EmptyHistory,
}

impl HistoryError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            HistoryError::ZeroCapacity => "zero_capacity",
            HistoryError::EmptyHistory => "empty_history",
        }
    }

    pub const fn is_zero_capacity(&self) -> bool {
        matches!(self, HistoryError::ZeroCapacity)
    }

    /// Cross-surface invariant: `is_zero_capacity XOR is_empty_history`
    /// partitions all variants.
    pub const fn is_empty_history(&self) -> bool {
        matches!(self, HistoryError::EmptyHistory)
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct WindowStats {
    pub mean_utilization: f32,
    pub max_utilization: f32,
    pub p95_utilization: f32,
    pub mean_power_watts: f32,
    pub sample_count: usize,
}

impl WindowStats {
    /// Predicate: rolling-mean utilization above the busy threshold.
    /// The "should we wait before scheduling another ANE op?" check.
    pub fn is_busy_above(&self, threshold: f32) -> bool {
        self.mean_utilization >= threshold
    }

    /// Predicate: p95 utilization below the headroom threshold.
    /// Cross-surface invariant: a window where `p95_below(t)` is true
    /// indicates at least 95% of samples were under `t` — strong
    /// signal of sustained idle.
    pub fn p95_below(&self, threshold: f32) -> bool {
        self.p95_utilization < threshold
    }
}

impl AneTelemetryHistory {
    pub fn try_with_capacity(capacity: usize) -> Result<Self, HistoryError> {
        if capacity == 0 {
            return Err(HistoryError::ZeroCapacity);
        }
        Ok(Self {
            capacity,
            samples: VecDeque::with_capacity(capacity),
        })
    }

    pub fn default_capacity() -> Self {
        Self::try_with_capacity(DEFAULT_HISTORY_CAPACITY)
            .expect("DEFAULT_HISTORY_CAPACITY is non-zero")
    }

    pub fn capacity(&self) -> usize {
        self.capacity
    }

    pub fn len(&self) -> usize {
        self.samples.len()
    }

    pub fn is_empty(&self) -> bool {
        self.samples.is_empty()
    }

    /// Predicate: the ring buffer is at capacity (next push evicts).
    /// Cross-surface invariant: `is_full() iff headroom() == 0`.
    pub fn is_full(&self) -> bool {
        self.samples.len() == self.capacity
    }

    /// Remaining space before the next push starts evicting.
    /// Cross-surface invariant: `len() + headroom() == capacity()`.
    pub fn headroom(&self) -> usize {
        self.capacity - self.samples.len()
    }

    /// Fraction `len / capacity ∈ [0.0, 1.0]`. Always defined since
    /// capacity > 0 by construction.
    pub fn occupancy(&self) -> f32 {
        self.samples.len() as f32 / self.capacity as f32
    }

    pub fn push(&mut self, sample: AneTelemetry) {
        if self.samples.len() == self.capacity {
            self.samples.pop_front();
        }
        self.samples.push_back(sample);
    }

    pub fn clear(&mut self) {
        self.samples.clear();
    }

    pub fn stats(&self) -> Result<WindowStats, HistoryError> {
        if self.samples.is_empty() {
            return Err(HistoryError::EmptyHistory);
        }
        let n = self.samples.len();

        let mut util_sum = 0.0f32;
        let mut power_sum = 0.0f32;
        let mut max_util = f32::NEG_INFINITY;
        let mut utils: Vec<f32> = Vec::with_capacity(n);
        for s in &self.samples {
            util_sum += s.derived_utilization;
            power_sum += s.power_watts;
            if s.derived_utilization > max_util {
                max_util = s.derived_utilization;
            }
            utils.push(s.derived_utilization);
        }
        utils.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
        let p95_idx = ((n as f32 * 0.95).ceil() as usize).saturating_sub(1).min(n - 1);
        let p95 = utils[p95_idx];

        Ok(WindowStats {
            mean_utilization: util_sum / n as f32,
            max_utilization: max_util,
            p95_utilization: p95,
            mean_power_watts: power_sum / n as f32,
            sample_count: n,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample(util: f32, watts: f32) -> AneTelemetry {
        AneTelemetry {
            power_watts: watts,
            frequency_hz: 1_000_000_000,
            derived_utilization: util,
        }
    }

    #[test]
    fn default_capacity_is_60() {
        assert_eq!(DEFAULT_HISTORY_CAPACITY, 60);
        let h = AneTelemetryHistory::default_capacity();
        assert_eq!(h.capacity(), 60);
    }

    #[test]
    fn zero_capacity_rejected() {
        assert_eq!(
            AneTelemetryHistory::try_with_capacity(0).unwrap_err(),
            HistoryError::ZeroCapacity
        );
    }

    #[test]
    fn fresh_history_is_empty() {
        let h = AneTelemetryHistory::try_with_capacity(10).unwrap();
        assert!(h.is_empty());
        assert_eq!(h.len(), 0);
        assert_eq!(h.stats().unwrap_err(), HistoryError::EmptyHistory);
    }

    #[test]
    fn push_appends_until_capacity() {
        let mut h = AneTelemetryHistory::try_with_capacity(3).unwrap();
        h.push(sample(0.1, 1.0));
        h.push(sample(0.2, 2.0));
        h.push(sample(0.3, 3.0));
        assert_eq!(h.len(), 3);
    }

    #[test]
    fn push_past_capacity_evicts_oldest() {
        let mut h = AneTelemetryHistory::try_with_capacity(3).unwrap();
        for i in 0..5 {
            h.push(sample((i as f32) * 0.1, i as f32));
        }
        assert_eq!(h.len(), 3);
        // First two (0.0 / 0.1) should be gone; samples should be 0.2/0.3/0.4
        let stats = h.stats().unwrap();
        let expected_mean = (0.2 + 0.3 + 0.4) / 3.0;
        assert!((stats.mean_utilization - expected_mean).abs() < 1e-5);
    }

    #[test]
    fn mean_max_correct_on_known_samples() {
        let mut h = AneTelemetryHistory::try_with_capacity(4).unwrap();
        h.push(sample(0.0, 0.5));
        h.push(sample(0.5, 1.0));
        h.push(sample(0.25, 0.75));
        h.push(sample(1.0, 2.0));
        let s = h.stats().unwrap();
        assert!((s.mean_utilization - 0.4375).abs() < 1e-5);
        assert!((s.max_utilization - 1.0).abs() < 1e-5);
        assert!((s.mean_power_watts - 1.0625).abs() < 1e-5);
        assert_eq!(s.sample_count, 4);
    }

    #[test]
    fn p95_of_100_uniform_samples_near_top() {
        let mut h = AneTelemetryHistory::try_with_capacity(100).unwrap();
        for i in 0..100 {
            h.push(sample(i as f32 / 100.0, 0.0));
        }
        let s = h.stats().unwrap();
        // p95 of 0.00, 0.01, ..., 0.99 should be 0.94 (ceil(100*0.95)-1 = 94)
        assert!((s.p95_utilization - 0.94).abs() < 1e-5);
        assert!((s.max_utilization - 0.99).abs() < 1e-5);
    }

    #[test]
    fn p95_of_single_sample_equals_that_sample() {
        let mut h = AneTelemetryHistory::try_with_capacity(10).unwrap();
        h.push(sample(0.42, 0.0));
        let s = h.stats().unwrap();
        assert!((s.p95_utilization - 0.42).abs() < 1e-5);
    }

    #[test]
    fn clear_empties_history() {
        let mut h = AneTelemetryHistory::try_with_capacity(5).unwrap();
        h.push(sample(0.5, 1.0));
        h.push(sample(0.5, 1.0));
        h.clear();
        assert!(h.is_empty());
    }

    #[test]
    fn capacity_preserved_after_eviction() {
        let mut h = AneTelemetryHistory::try_with_capacity(2).unwrap();
        for _ in 0..10 {
            h.push(sample(0.5, 1.0));
        }
        assert_eq!(h.capacity(), 2);
        assert_eq!(h.len(), 2);
    }

    #[test]
    fn idle_sustained_samples_yield_low_p95() {
        // 60 idle samples (utilization ~0.05) should produce p95 ≤ 0.06.
        let mut h = AneTelemetryHistory::default_capacity();
        for _ in 0..60 {
            h.push(sample(0.05, 0.5));
        }
        let s = h.stats().unwrap();
        assert!(s.p95_utilization <= 0.06);
        assert!(s.mean_utilization <= 0.06);
    }

    #[test]
    fn single_burst_among_idle_smoothed_by_mean_but_visible_in_max() {
        // 59 idle samples + 1 burst → mean stays low but max reflects burst.
        let mut h = AneTelemetryHistory::default_capacity();
        for _ in 0..59 {
            h.push(sample(0.05, 0.5));
        }
        h.push(sample(0.95, 5.0));
        let s = h.stats().unwrap();
        assert!(s.mean_utilization < 0.10, "mean was {}", s.mean_utilization);
        assert!((s.max_utilization - 0.95).abs() < 1e-5);
    }

    #[test]
    fn history_roundtrips_through_serde_json() {
        let mut h = AneTelemetryHistory::try_with_capacity(4).unwrap();
        h.push(sample(0.1, 1.0));
        h.push(sample(0.2, 2.0));
        let json = serde_json::to_string(&h).unwrap();
        let back: AneTelemetryHistory = serde_json::from_str(&json).unwrap();
        assert_eq!(h, back);
    }

    // ── diagnostic surface (iter 195) ────────────────────────────────────────

    #[test]
    fn history_error_classifiers_partition() {
        let variants = [HistoryError::ZeroCapacity, HistoryError::EmptyHistory];
        // Cross-surface invariant: is_zero_capacity XOR is_empty_history.
        for e in variants {
            assert_ne!(e.is_zero_capacity(), e.is_empty_history());
        }
        assert_eq!(variants[0].cause(), "zero_capacity");
        assert_eq!(variants[1].cause(), "empty_history");
    }

    #[test]
    fn is_full_aligned_with_zero_headroom() {
        // Cross-surface invariant: is_full iff headroom == 0.
        let mut h = AneTelemetryHistory::try_with_capacity(3).unwrap();
        assert_eq!(h.is_full(), h.headroom() == 0);
        for _ in 0..3 {
            h.push(sample(0.5, 1.0));
        }
        assert!(h.is_full());
        assert_eq!(h.headroom(), 0);
    }

    #[test]
    fn len_plus_headroom_equals_capacity() {
        // Cross-surface invariant.
        let mut h = AneTelemetryHistory::try_with_capacity(5).unwrap();
        assert_eq!(h.len() + h.headroom(), h.capacity());
        h.push(sample(0.5, 1.0));
        assert_eq!(h.len() + h.headroom(), h.capacity());
        h.push(sample(0.5, 1.0));
        assert_eq!(h.len() + h.headroom(), h.capacity());
    }

    #[test]
    fn occupancy_zero_to_one() {
        let mut h = AneTelemetryHistory::try_with_capacity(4).unwrap();
        assert!((h.occupancy() - 0.0).abs() < 1e-9);
        h.push(sample(0.5, 1.0));
        assert!((h.occupancy() - 0.25).abs() < 1e-6);
        for _ in 0..3 {
            h.push(sample(0.5, 1.0));
        }
        assert!((h.occupancy() - 1.0).abs() < 1e-6);
    }

    #[test]
    fn window_stats_is_busy_above_threshold() {
        let mut h = AneTelemetryHistory::try_with_capacity(4).unwrap();
        for _ in 0..4 {
            h.push(sample(0.6, 1.0));
        }
        let s = h.stats().unwrap();
        assert!(s.is_busy_above(0.5));
        assert!(s.is_busy_above(0.6));
        assert!(!s.is_busy_above(0.7));
    }

    #[test]
    fn window_stats_p95_below_threshold() {
        let mut h = AneTelemetryHistory::try_with_capacity(60).unwrap();
        for _ in 0..60 {
            h.push(sample(0.05, 0.5));
        }
        let s = h.stats().unwrap();
        assert!(s.p95_below(0.1));
        assert!(!s.p95_below(0.04));
    }

    #[test]
    fn p95_leq_max_invariant() {
        // Cross-surface invariant: p95 ≤ max within any window.
        let mut h = AneTelemetryHistory::try_with_capacity(20).unwrap();
        for i in 0..20 {
            h.push(sample(i as f32 / 20.0, 0.0));
        }
        let s = h.stats().unwrap();
        assert!(s.p95_utilization <= s.max_utilization);
    }

    #[test]
    fn mean_leq_max_invariant() {
        // Cross-surface invariant: mean ≤ max for any non-empty window.
        let mut h = AneTelemetryHistory::try_with_capacity(10).unwrap();
        for v in [0.1_f32, 0.3, 0.8, 0.5, 0.2] {
            h.push(sample(v, 0.0));
        }
        let s = h.stats().unwrap();
        assert!(s.mean_utilization <= s.max_utilization);
    }
}
