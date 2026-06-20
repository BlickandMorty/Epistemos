//! M0 falsifier harness scaffold — `F-Interrupt-Moves-Loss`.
//!
//! Source:
//! - `docs/fusion/RESEARCH_LOOP_LEDGER_2026_06_20.md` PASS-6 (M0 spec) + PASS-15
//!   (M0 backbone LOCKED = a vanilla state-tracking-weak linear SSM, NOT Mamba-3,
//!   so the interrupt is the single new variable) + PASS-21/22 (falsifier index).
//!
//! # Scope (intentionally minimal — schema + pass/fail logic ONLY)
//!
//! This is the **compiling skeleton** for the M0 gate ("does the interrupt move
//! the loss at toy scale?"). It owns:
//!   - the typed result/measurement/axes schema (serde-serializable for the
//!     `result.json` artifact, mirroring the `falsifier_artifacts` shape), and
//!   - the **pure, tested** pass/fail evaluation ([`evaluate_axes`] / [`overall_pass`]).
//!
//! It deliberately does **NOT** run the experiment: there is no toy-SSM forward
//! pass, no interrupt gate, no token generation here. Those land later, behind an
//! owner green-light, in an `src/bin/falsify_interrupt_moves_loss.rs` driver that
//! fills a [`M0Measurements`] and calls [`evaluate_axes`]. Keeping the experiment
//! out means this module is dependency-light, panic-free, and isolated.
//!
//! No `unwrap`/`expect`/`panic` in non-test code; no `unsafe`; no FFI (so no
//! `#[repr(C)]`). Gated behind `feature = "research"` like the rest of this tree.

use serde::{Deserialize, Serialize};

/// Acceptance thresholds for the four M0 axes (PASS-6/15/22).
/// These are the pinned *criteria*; the absolute calibration constants
/// (e.g. the loss-delta epsilon) are tuned during the build of the driver.
pub mod thresholds {
    /// `axis_calibrated`: interrupt-score AUROC bar (Youden-J), from
    /// `interrupt_calibration::INTERRUPT_DOCTRINE_AUROC_BAR`.
    pub const AUROC_BAR: f64 = 0.85;
    /// `axis_efficient`: minimum fraction of the SSM→attention quality gap the
    /// gated arm must recover.
    pub const RECOVERY_MIN: f64 = 0.5;
    /// `axis_efficient`: maximum fraction of tokens that may trigger attention.
    pub const FIRE_RATE_MAX: f64 = 0.25;
    /// `axis_moves_loss`: minimum *relative* loss reduction vs the always-SSM
    /// floor for the interrupt to count as "moving the loss" (build-calibratable).
    pub const LOSS_DELTA_MIN_REL: f64 = 0.02;
}

/// The three held-identical arms plus the ablation control (PASS-6).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum M0Arm {
    /// Baseline floor: never interrupts (cheap).
    AlwaysSsm,
    /// Baseline ceiling: full attention every token (expensive; quality upper bound).
    AlwaysAttention,
    /// Candidate: SSM default + full attention only when `interrupt_score > tau`.
    InterruptGated,
    /// Ablation: same fire-rate as gated, but fires at RANDOM positions.
    RandomGate,
}

/// Held-out measurements produced by the (future) experiment driver.
/// All losses are held-out NLL; rates are fractions in `[0, 1]`.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct M0Measurements {
    pub loss_always_ssm: f64,
    pub loss_always_attention: f64,
    pub loss_interrupt_gated: f64,
    /// Same fire-rate as the gated arm but random firing positions (ablation).
    pub loss_random_gate: f64,
    /// Interrupt-score vs ground-truth `interrupt_needed` label.
    pub interrupt_auroc: f64,
    /// Fraction of tokens that triggered attention in the gated arm.
    pub attention_fire_rate: f64,
}

impl M0Measurements {
    /// `loss_always_ssm - loss_interrupt_gated` (must be > 0 for the interrupt to help).
    pub fn loss_delta_vs_ssm(&self) -> f64 {
        self.loss_always_ssm - self.loss_interrupt_gated
    }

    /// Fraction of the SSM→attention quality gap the gated arm recovers.
    /// Returns `0.0` when the gap is non-positive (degenerate: attention did not help).
    pub fn loss_recovery_fraction(&self) -> f64 {
        let gap = self.loss_always_ssm - self.loss_always_attention;
        if gap <= 0.0 {
            0.0
        } else {
            (self.loss_always_ssm - self.loss_interrupt_gated) / gap
        }
    }

    /// Relative loss reduction vs the always-SSM floor.
    /// Returns `0.0` when the floor loss is non-positive (degenerate).
    pub fn loss_delta_rel(&self) -> f64 {
        if self.loss_always_ssm <= 0.0 {
            0.0
        } else {
            self.loss_delta_vs_ssm() / self.loss_always_ssm
        }
    }
}

/// The four M0 pass/fail axes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct M0Axes {
    /// Interrupt moves the loss vs the always-SSM floor.
    pub axis_moves_loss: bool,
    /// Gated beats the equal-fire-rate random ablation (locates, not just spends).
    pub axis_beats_random: bool,
    /// Interrupt fires at the right tokens (AUROC >= bar).
    pub axis_calibrated: bool,
    /// Recovers >= RECOVERY_MIN of the gap at <= FIRE_RATE_MAX fire-rate.
    pub axis_efficient: bool,
}

impl M0Axes {
    /// `overall_pass` = all four axes true.
    pub fn overall_pass(&self) -> bool {
        self.axis_moves_loss
            && self.axis_beats_random
            && self.axis_calibrated
            && self.axis_efficient
    }
}

/// Pure pass/fail evaluation of the four M0 axes from measurements.
/// This is the load-bearing, test-backed logic of the M0 gate.
pub fn evaluate_axes(m: &M0Measurements) -> M0Axes {
    M0Axes {
        axis_moves_loss: m.loss_delta_rel() >= thresholds::LOSS_DELTA_MIN_REL,
        axis_beats_random: m.loss_interrupt_gated < m.loss_random_gate,
        axis_calibrated: m.interrupt_auroc >= thresholds::AUROC_BAR,
        axis_efficient: m.loss_recovery_fraction() >= thresholds::RECOVERY_MIN
            && m.attention_fire_rate <= thresholds::FIRE_RATE_MAX,
    }
}

/// The `result.json` artifact shape for the M0 falsifier (mirrors the
/// `falsifier_artifacts` convention: id + fixture + axes + measurements + pass).
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct M0Result {
    pub falsifier_id: String,
    pub fixture_id: String,
    pub overall_pass: bool,
    pub axes: M0Axes,
    pub measurements: M0Measurements,
    pub notes: String,
}

impl M0Result {
    pub const FALSIFIER_ID: &'static str = "F-Interrupt-Moves-Loss";
    pub const FIXTURE_ID: &'static str = "interrupt_moves_loss_toy_v1";

    /// Build a result from measurements by evaluating the axes.
    pub fn from_measurements(measurements: M0Measurements, notes: impl Into<String>) -> Self {
        let axes = evaluate_axes(&measurements);
        Self {
            falsifier_id: Self::FALSIFIER_ID.to_string(),
            fixture_id: Self::FIXTURE_ID.to_string(),
            overall_pass: axes.overall_pass(),
            axes,
            measurements,
            notes: notes.into(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn passing() -> M0Measurements {
        M0Measurements {
            loss_always_ssm: 2.00,
            loss_always_attention: 1.00,
            loss_interrupt_gated: 1.40, // recovers (2.0-1.4)/(2.0-1.0)=0.6 of the gap
            loss_random_gate: 1.80,     // gated (1.40) beats random (1.80)
            interrupt_auroc: 0.90,      // >= 0.85
            attention_fire_rate: 0.20,  // <= 0.25
        }
    }

    #[test]
    fn passing_measurements_pass_all_axes() {
        let axes = evaluate_axes(&passing());
        assert!(axes.axis_moves_loss);
        assert!(axes.axis_beats_random);
        assert!(axes.axis_calibrated);
        assert!(axes.axis_efficient);
        assert!(axes.overall_pass());
    }

    #[test]
    fn failing_beats_random_fails_overall() {
        // Gated no better than random firing => locating, not just spending, FAILS.
        let mut m = passing();
        m.loss_random_gate = 1.30; // random (1.30) now beats gated (1.40)
        let axes = evaluate_axes(&m);
        assert!(!axes.axis_beats_random);
        assert!(!axes.overall_pass());
    }

    #[test]
    fn low_auroc_fails_calibration() {
        let mut m = passing();
        m.interrupt_auroc = 0.70; // below the 0.85 doctrine bar
        let axes = evaluate_axes(&m);
        assert!(!axes.axis_calibrated);
        assert!(!axes.overall_pass());
    }

    #[test]
    fn over_budget_fire_rate_fails_efficiency() {
        let mut m = passing();
        m.attention_fire_rate = 0.40; // above the 0.25 cap
        let axes = evaluate_axes(&m);
        assert!(!axes.axis_efficient);
    }

    #[test]
    fn degenerate_gap_recovery_is_zero_not_nan() {
        let mut m = passing();
        m.loss_always_attention = m.loss_always_ssm; // zero gap
        assert_eq!(m.loss_recovery_fraction(), 0.0);
    }

    #[test]
    fn result_round_trips_through_json() {
        let r = M0Result::from_measurements(passing(), "smoke");
        let json = serde_json::to_string(&r).expect("serialize");
        let back: M0Result = serde_json::from_str(&json).expect("deserialize");
        assert_eq!(r, back);
        assert!(back.overall_pass);
        assert_eq!(back.falsifier_id, M0Result::FALSIFIER_ID);
    }
}
