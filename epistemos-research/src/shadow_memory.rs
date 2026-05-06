//! HELIOS V5 — Helios Shadow Memory (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-SHADOW-MEMORY guard
//!
//! Per HELIOS v4 preservation `source_docs/helios_shadow_memory.md` —
//! classical-shadow-style sketch substrate inspired by Huang-Kueng-
//! Preskill 2020 "Predicting Many Properties of a Quantum System
//! From Very Few Measurements" + Zhao-Zlokapa-Neven-Babbush-
//! Preskill-McClean-Huang arXiv:2604.07639 "Exponential quantum
//! advantage in processing massive classical data" (April 2026).
//!
//! This module exposes the **classical analogue** of quantum oracle
//! sketching — the key principle: do not store the world; store a
//! sketch of the world that is sufficient for the questions you need
//! to ask. The transferable design principle, NOT the quantum
//! advantage (a 16 GB MacBook does not inherit polylogarithmic
//! qubit scaling).
//!
//! ## Substrate types
//!
//! - [`EscalationLevel`] — 3-arm escalation policy
//!   (StayShadow / DecodeResidual / LoadExact)
//! - [`UncertaintyThresholds`] — `(τ_low, τ_high)` policy parameters
//!   per shadow-memory §6 escalation table
//! - [`KlBound`] — Theorem 2.4 (Shadowed Associative State, Conditional)
//!   `D_KL(P_exact || P_shadow) ≤ ε_sketch² + δ_fallback · D_max`
//!
//! Lane 3 RESEARCH-ONLY. NEVER in MAS — gated behind `research`
//! feature. Real backends (CountSketch + FWHT Metal kernel + page
//! oracle) live behind a Lane 5 Vault follow-up (W17/W18/W19 sub-
//! sequencing per integration plan v2 §1).

use serde::{Deserialize, Serialize};

/// Escalation level for a single page query — how the shadow-first
/// retrieval pipeline decided to materialize the page contents.
///
/// Ordered from cheapest (StayShadow, INT8 sketch only) to most
/// expensive (LoadExact, full-precision SSD load).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EscalationLevel {
    /// Use INT8 sketch only (~128 dims). High-confidence shadow.
    StayShadow,
    /// Use Sherry 1.25-bit residual reconstruction. Moderate confidence.
    DecodeResidual,
    /// Load full-precision exact state from SSD. Low confidence /
    /// hot window / attention sink / KL drift detected.
    LoadExact,
}

/// `(τ_low, τ_high)` thresholds for the escalation policy. Both must
/// satisfy `0 <= τ_low <= τ_high <= 1`. Values outside this range
/// are clamped on construction.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct UncertaintyThresholds {
    pub tau_low: f32,
    pub tau_high: f32,
}

impl UncertaintyThresholds {
    /// Default policy from shadow-memory §6 table.
    pub const DEFAULT: UncertaintyThresholds = UncertaintyThresholds {
        tau_low: 0.05,
        tau_high: 0.20,
    };

    /// Construct a thresholds pair, clamping into `[0, 1]` and
    /// enforcing `tau_low <= tau_high`.
    pub fn new(tau_low: f32, tau_high: f32) -> Self {
        let tau_low = tau_low.clamp(0.0, 1.0);
        let tau_high = tau_high.clamp(0.0, 1.0);
        let tau_low = tau_low.min(tau_high);
        Self { tau_low, tau_high }
    }
}

impl Default for UncertaintyThresholds {
    fn default() -> Self {
        Self::DEFAULT
    }
}

/// Per-page query context for the escalation decision. `is_hot` and
/// `is_attention_sink` force `LoadExact`; `accumulated_kl` triggers
/// global escalation when it exceeds `max_kl`.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct PageQueryContext {
    pub uncertainty: f32,
    pub is_hot: bool,
    pub is_attention_sink: bool,
    pub accumulated_kl: f32,
    pub max_kl: f32,
}

/// Decide the escalation level for a single page given its query
/// context and the policy thresholds.
///
/// Pure function of inputs — no I/O, no allocation, deterministic.
/// Mirrors `EscalationPolicy::decide` from shadow-memory §6.
pub fn escalate(
    ctx: &PageQueryContext,
    thresholds: UncertaintyThresholds,
) -> EscalationLevel {
    if ctx.is_hot || ctx.is_attention_sink {
        return EscalationLevel::LoadExact;
    }
    if ctx.accumulated_kl > ctx.max_kl {
        return EscalationLevel::LoadExact;
    }
    if !ctx.uncertainty.is_finite() || ctx.uncertainty.is_nan() {
        return EscalationLevel::LoadExact;
    }
    if ctx.uncertainty < thresholds.tau_low {
        EscalationLevel::StayShadow
    } else if ctx.uncertainty < thresholds.tau_high {
        EscalationLevel::DecodeResidual
    } else {
        EscalationLevel::LoadExact
    }
}

/// Theorem 2.4 (Shadowed Associative State, Conditional) KL bound
/// witness:
///
/// ```text
/// D_KL(P_exact || P_shadow) ≤ ε_sketch² + δ_fallback · D_max
/// ```
///
/// Carries the three quantities so consumers can record the bound
/// and the achieved measurement separately for replay-bundle export.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct KlBound {
    pub eps_sketch: f32,
    pub delta_fallback: f32,
    pub d_max: f32,
}

impl KlBound {
    /// Compute the upper-bound side of the inequality.
    pub fn upper_bound(&self) -> f32 {
        self.eps_sketch * self.eps_sketch + self.delta_fallback * self.d_max
    }

    /// Returns true when the observed KL divergence respects the bound.
    pub fn respects(&self, observed_kl: f32) -> bool {
        observed_kl.is_finite() && observed_kl <= self.upper_bound()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_thresholds_match_shadow_memory_section_6() {
        let t = UncertaintyThresholds::default();
        assert!((t.tau_low - 0.05).abs() < 1e-9);
        assert!((t.tau_high - 0.20).abs() < 1e-9);
    }

    #[test]
    fn thresholds_constructor_clamps_into_unit_interval() {
        let t = UncertaintyThresholds::new(-0.5, 1.5);
        assert!((0.0..=1.0).contains(&t.tau_low));
        assert!((0.0..=1.0).contains(&t.tau_high));
    }

    #[test]
    fn thresholds_constructor_orders_low_below_high() {
        let t = UncertaintyThresholds::new(0.8, 0.2);
        assert!(t.tau_low <= t.tau_high);
    }

    #[test]
    fn hot_window_pages_always_load_exact() {
        let t = UncertaintyThresholds::default();
        let ctx = PageQueryContext {
            uncertainty: 0.0,
            is_hot: true,
            is_attention_sink: false,
            accumulated_kl: 0.0,
            max_kl: 1.0,
        };
        assert_eq!(escalate(&ctx, t), EscalationLevel::LoadExact);
    }

    #[test]
    fn attention_sinks_always_load_exact() {
        let t = UncertaintyThresholds::default();
        let ctx = PageQueryContext {
            uncertainty: 0.0,
            is_hot: false,
            is_attention_sink: true,
            accumulated_kl: 0.0,
            max_kl: 1.0,
        };
        assert_eq!(escalate(&ctx, t), EscalationLevel::LoadExact);
    }

    #[test]
    fn kl_drift_above_max_forces_load_exact() {
        let t = UncertaintyThresholds::default();
        let ctx = PageQueryContext {
            uncertainty: 0.0,
            is_hot: false,
            is_attention_sink: false,
            accumulated_kl: 0.5,
            max_kl: 0.1,
        };
        assert_eq!(escalate(&ctx, t), EscalationLevel::LoadExact);
    }

    #[test]
    fn low_uncertainty_stays_shadow() {
        let t = UncertaintyThresholds::default();
        let ctx = PageQueryContext {
            uncertainty: 0.01,
            is_hot: false,
            is_attention_sink: false,
            accumulated_kl: 0.0,
            max_kl: 1.0,
        };
        assert_eq!(escalate(&ctx, t), EscalationLevel::StayShadow);
    }

    #[test]
    fn moderate_uncertainty_decodes_residual() {
        let t = UncertaintyThresholds::default();
        let ctx = PageQueryContext {
            uncertainty: 0.10,
            is_hot: false,
            is_attention_sink: false,
            accumulated_kl: 0.0,
            max_kl: 1.0,
        };
        assert_eq!(escalate(&ctx, t), EscalationLevel::DecodeResidual);
    }

    #[test]
    fn high_uncertainty_loads_exact() {
        let t = UncertaintyThresholds::default();
        let ctx = PageQueryContext {
            uncertainty: 0.50,
            is_hot: false,
            is_attention_sink: false,
            accumulated_kl: 0.0,
            max_kl: 1.0,
        };
        assert_eq!(escalate(&ctx, t), EscalationLevel::LoadExact);
    }

    #[test]
    fn nan_uncertainty_falls_through_to_load_exact() {
        let t = UncertaintyThresholds::default();
        let ctx = PageQueryContext {
            uncertainty: f32::NAN,
            is_hot: false,
            is_attention_sink: false,
            accumulated_kl: 0.0,
            max_kl: 1.0,
        };
        assert_eq!(escalate(&ctx, t), EscalationLevel::LoadExact);
    }

    #[test]
    fn kl_bound_upper_bound_matches_theorem_2_4() {
        let b = KlBound { eps_sketch: 0.1, delta_fallback: 0.01, d_max: 2.0 };
        // 0.1² + 0.01 · 2.0 = 0.01 + 0.02 = 0.03
        assert!((b.upper_bound() - 0.03).abs() < 1e-6);
    }

    #[test]
    fn kl_bound_respects_observed_at_or_below_bound() {
        let b = KlBound { eps_sketch: 0.1, delta_fallback: 0.01, d_max: 2.0 };
        assert!(b.respects(0.0));
        assert!(b.respects(b.upper_bound()));
        assert!(!b.respects(b.upper_bound() + 1e-3));
        assert!(!b.respects(f32::INFINITY));
        assert!(!b.respects(f32::NAN));
    }

    #[test]
    fn escalation_level_serializes_in_snake_case() {
        for (level, expected) in [
            (EscalationLevel::StayShadow, "\"stay_shadow\""),
            (EscalationLevel::DecodeResidual, "\"decode_residual\""),
            (EscalationLevel::LoadExact, "\"load_exact\""),
        ] {
            assert_eq!(serde_json::to_string(&level).unwrap(), expected);
        }
    }

    #[test]
    fn uncertainty_thresholds_round_trip_through_json() {
        let t = UncertaintyThresholds::DEFAULT;
        let json = serde_json::to_string(&t).unwrap();
        let parsed: UncertaintyThresholds = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, t);
    }

    #[test]
    fn boundary_uncertainty_at_tau_low_decodes_residual() {
        // tau_low itself is the boundary: < tau_low means stay_shadow,
        // == tau_low means decode_residual (consistent with the < tau_high check).
        let t = UncertaintyThresholds::default();
        let ctx = PageQueryContext {
            uncertainty: t.tau_low,
            is_hot: false,
            is_attention_sink: false,
            accumulated_kl: 0.0,
            max_kl: 1.0,
        };
        assert_eq!(escalate(&ctx, t), EscalationLevel::DecodeResidual);
    }

    #[test]
    fn boundary_uncertainty_at_tau_high_loads_exact() {
        // tau_high is the upper boundary: >= tau_high means load_exact.
        let t = UncertaintyThresholds::default();
        let ctx = PageQueryContext {
            uncertainty: t.tau_high,
            is_hot: false,
            is_attention_sink: false,
            accumulated_kl: 0.0,
            max_kl: 1.0,
        };
        assert_eq!(escalate(&ctx, t), EscalationLevel::LoadExact);
    }
}
