//! Source:
//! - `docs/fusion/EML_INTEGRATION_DOCTRINE_2026_05_17.md` §3.4 — the
//!   diagnostic surface for Settings → Diagnostics "EML energy live
//!   readout" row.
//! - T7 prompt acceptance bar: "Diagnostic row visible." This module
//!   owns the Rust-side payload struct + computation; a Swift
//!   `EmlEnergyHealthRow` mirror is the Phase-C land-after (mirroring
//!   `EditorBundleHealthRow` / `SearchFusionHealthRow` per CLAUDE.md
//!   "Wave 2026-04-29 perf additions" section).
//! - Companions: [`super::potential::EmlPotential`] (sentinel value),
//!   [`super::super::eml::ulp_oracle::run_smoke_oracle`] (1024-sample
//!   smoke fixture), [`super::super::eml::gate::check_answer_packet_freeze_allowed`].
//!
//! # EML energy live readout — Settings → Diagnostics payload
//!
//! Bundles the in-process EML primitive's health into one
//! serde-serializable struct that Swift can deserialize once per
//! refresh tick. Three concerns:
//!
//! 1. **ULP oracle health** — runs the 1024-sample fp16-ULP smoke
//!    fixture (`run_smoke_oracle(SHIPPING_BAR)`) and reports max +
//!    mean ULP error + within-bar fraction.
//! 2. **AnswerPacket freeze gate** — surfaces whether the schema
//!    freeze gate is currently allowed or blocked, with the block
//!    reason if any.
//! 3. **Potential sentinel** — fixes a single canonical input
//!    (`EmlPotential::from_score(1.0)`) and reports its value as a
//!    forward-stable witness that the potential primitive is
//!    behaving (value should equal `(1+1) − ln(1+1) = 2 − ln(2)
//!    ≈ 1.306852819`).
//!
//! Hard-fence text is included so the user-visible row carries the
//! Smith-quintic universality caveat verbatim from
//! `eml/mod.rs:42-45`. No floating EML claims even at the UI surface.

use serde::{Deserialize, Serialize};

use super::super::cognition_observatory::sae::LabeledScore;
use super::super::eml::gate::{check_answer_packet_freeze_allowed, GateStatus};
use super::super::eml::ulp_oracle::UlpToleranceFp16;
use super::observatory::{summarize, AugmentError, AugmentedSummary};
use super::potential::{EmlPotential, EmlPotentialError};

/// Settings → Diagnostics "EML energy live readout" payload.
///
/// Computed by [`compute_live_readout`] for the substrate-only view,
/// or by [`compute_live_readout_with_observations`] to attach a
/// summary of recent SAE observations. Sendable + serde-roundtrip
/// safe so Swift can deserialize via the FFI bridge.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct EmlEnergyDiagnostic {
    /// fp16-ULP smoke oracle max-error from the most recent run.
    pub ulp_smoke_max_error: f32,
    /// fp16-ULP smoke oracle mean-error from the most recent run.
    pub ulp_smoke_mean_error: f32,
    /// Number of samples (out of 1024) within the shipping bar.
    pub ulp_smoke_samples_within_bar: usize,
    /// Total samples evaluated in the smoke run.
    pub ulp_smoke_samples_total: usize,
    /// Fraction of smoke samples within bar (0.0-1.0). `None` only
    /// if the smoke fixture ran with zero samples (impossible at the
    /// substrate floor; carried as Option for forward compat).
    pub ulp_smoke_fraction_within_bar: Option<f32>,
    /// The shipping ULP tolerance bar (2.0 per V6.1).
    pub ulp_shipping_bar: f32,
    /// AnswerPacket schema-freeze gate verdict — true iff allowed.
    pub schema_freeze_allowed: bool,
    /// Block reason string when the gate is blocked; `None` when
    /// allowed.
    pub schema_freeze_block_reason: Option<String>,
    /// `EmlPotential::from_score(1.0).value()`. Expected
    /// `2 − ln(2) ≈ 1.3068528...`. Forward-stable canary against
    /// accidental encoding-change regressions.
    pub potential_sentinel_at_one: f64,
    /// Universality hard-fence text — surfaced verbatim from
    /// `eml/mod.rs:42-45` so the Settings row never silently floats
    /// the universality claim past its Smith-quintic boundary.
    pub universality_fence_text: String,
    /// Optional summary of recent SAE-observation augmentations.
    /// Populated by [`compute_live_readout_with_observations`];
    /// always `None` from the substrate-only [`compute_live_readout`].
    /// Attaching this lets the Settings row surface aggregate
    /// EML-potential stats next to the substrate health.
    pub observation_summary: Option<AugmentedSummary>,
}

/// Errors produced while computing the diagnostic readout.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum DiagnosticError {
    /// The ULP smoke oracle failed to run. Substrate-floor smoke
    /// fixture is in-process and deterministic; this should be
    /// unreachable but is plumbed for completeness.
    OracleFailed,
    /// The potential sentinel failed to construct. Should also be
    /// unreachable (input is 1.0); plumbed for completeness.
    PotentialFailed(EmlPotentialError),
    /// The observation-summary path (used by
    /// [`compute_live_readout_with_observations`]) rejected one of
    /// the supplied observations. Carries the inner AugmentError.
    AugmentFailed(AugmentError),
}

impl From<EmlPotentialError> for DiagnosticError {
    fn from(e: EmlPotentialError) -> Self {
        DiagnosticError::PotentialFailed(e)
    }
}

impl From<AugmentError> for DiagnosticError {
    fn from(e: AugmentError) -> Self {
        DiagnosticError::AugmentFailed(e)
    }
}

/// Verbatim universality-fence text from `eml/mod.rs:42-45`. Held
/// as a const so the live readout cannot drift from the substrate
/// floor's documented caveat.
pub const UNIVERSALITY_FENCE_TEXT: &str =
    "EML universality is over the Liouvillian-solvable subdomain ONLY. \
     Smith's quintic counter-construction bounds every \"EML for everything\" \
     claim. Every EML publication MUST state this.";

/// Compute the diagnostic payload. Synchronous; uses the in-process
/// 1024-sample smoke oracle. Wall-clock budget per V6.1 §B.0.4 is
/// < 90s for the full 412k fixture; the smoke fixture is < 50 ms on
/// M2 Pro.
pub fn compute_live_readout() -> Result<EmlEnergyDiagnostic, DiagnosticError> {
    compute_live_readout_inner(None)
}

/// Variant of [`compute_live_readout`] that additionally summarizes a
/// slice of recent SAE observations and attaches the summary to the
/// payload. Useful when the Settings row wants to show the substrate
/// health + the aggregate behavior of the recent augmentation pass
/// in one fetch. Returns the augment-error path if any observation
/// fails the EML potential encoding.
pub fn compute_live_readout_with_observations(
    observations: &[LabeledScore],
) -> Result<EmlEnergyDiagnostic, DiagnosticError> {
    let summary = summarize(observations)?;
    compute_live_readout_inner(Some(summary))
}

fn compute_live_readout_inner(
    observation_summary: Option<AugmentedSummary>,
) -> Result<EmlEnergyDiagnostic, DiagnosticError> {
    let gate = check_answer_packet_freeze_allowed()
        .map_err(|_| DiagnosticError::OracleFailed)?;
    let report = gate.report().clone();
    let (allowed, reason) = match &gate {
        GateStatus::Allowed { .. } => (true, None),
        GateStatus::Blocked { reason, .. } => (false, Some((*reason).to_string())),
    };

    let sentinel = EmlPotential::from_score(1.0)?;

    Ok(EmlEnergyDiagnostic {
        ulp_smoke_max_error: report.max_ulp_error,
        ulp_smoke_mean_error: report.mean_ulp_error,
        ulp_smoke_samples_within_bar: report.samples_within_bar,
        ulp_smoke_samples_total: report.samples_evaluated,
        ulp_smoke_fraction_within_bar: report.fraction_within_bar(),
        ulp_shipping_bar: UlpToleranceFp16::SHIPPING_BAR.bar,
        schema_freeze_allowed: allowed,
        schema_freeze_block_reason: reason,
        potential_sentinel_at_one: sentinel.value(),
        universality_fence_text: UNIVERSALITY_FENCE_TEXT.to_string(),
        observation_summary,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx(a: f64, b: f64, tol: f64) -> bool {
        (a - b).abs() < tol
    }

    #[test]
    fn live_readout_runs_and_returns_filled_payload() {
        let d = compute_live_readout().unwrap();
        // Smoke oracle ran; non-zero sample count.
        assert!(d.ulp_smoke_samples_total > 0);
        // Shipping bar is 2.0.
        assert!(approx(d.ulp_shipping_bar as f64, 2.0, 1e-6));
    }

    #[test]
    fn potential_sentinel_at_one_matches_closed_form() {
        // For s = 1: value = (1+1) − ln(1+1) = 2 − ln(2) ≈ 1.3068528...
        let d = compute_live_readout().unwrap();
        let expected = 2.0_f64 - 2.0_f64.ln();
        assert!(approx(d.potential_sentinel_at_one, expected, 1e-12),
            "sentinel was {}, expected {}", d.potential_sentinel_at_one, expected);
    }

    #[test]
    fn universality_fence_text_present_and_mentions_smith() {
        let d = compute_live_readout().unwrap();
        assert!(d.universality_fence_text.contains("Smith"),
            "fence text missing Smith reference: {:?}", d.universality_fence_text);
        assert!(d.universality_fence_text.contains("Liouvillian"),
            "fence text missing Liouvillian reference: {:?}", d.universality_fence_text);
    }

    #[test]
    fn schema_freeze_gate_passes_at_substrate_floor() {
        // The 1024-sample smoke run is well within the 2-ULP shipping
        // bar at substrate floor — gate must be Allowed.
        let d = compute_live_readout().unwrap();
        assert!(d.schema_freeze_allowed);
        assert!(d.schema_freeze_block_reason.is_none());
    }

    #[test]
    fn ulp_smoke_fraction_within_bar_above_99_percent() {
        let d = compute_live_readout().unwrap();
        let f = d.ulp_smoke_fraction_within_bar.unwrap();
        assert!(f > 0.99, "fraction within bar was {}", f);
    }

    #[test]
    fn ulp_smoke_samples_within_bar_does_not_exceed_total() {
        // Cross-surface invariant.
        let d = compute_live_readout().unwrap();
        assert!(d.ulp_smoke_samples_within_bar <= d.ulp_smoke_samples_total);
    }

    #[test]
    fn ulp_max_and_mean_errors_non_negative() {
        let d = compute_live_readout().unwrap();
        assert!(d.ulp_smoke_max_error >= 0.0);
        assert!(d.ulp_smoke_mean_error >= 0.0);
    }

    #[test]
    fn diagnostic_roundtrips_through_serde_json() {
        let d = compute_live_readout().unwrap();
        let json = serde_json::to_string(&d).unwrap();
        let back: EmlEnergyDiagnostic = serde_json::from_str(&json).unwrap();
        assert_eq!(d, back);
    }

    #[test]
    fn diagnostic_deterministic_across_calls() {
        // Substrate-floor smoke oracle is deterministic (no RNG); two
        // calls should return identical payloads.
        let a = compute_live_readout().unwrap();
        let b = compute_live_readout().unwrap();
        assert_eq!(a, b);
    }

    #[test]
    fn universality_fence_text_const_matches_payload() {
        let d = compute_live_readout().unwrap();
        assert_eq!(d.universality_fence_text, UNIVERSALITY_FENCE_TEXT);
    }

    // ── compute_live_readout_with_observations tests (iter 16) ──────────────

    fn obs(score: f32, is_hallucination: bool) -> LabeledScore {
        LabeledScore { score, is_hallucination }
    }

    #[test]
    fn substrate_only_readout_has_no_observation_summary() {
        let d = compute_live_readout().unwrap();
        assert!(d.observation_summary.is_none());
    }

    #[test]
    fn with_observations_attaches_summary_with_correct_count() {
        let observations = vec![
            obs(0.1, false), obs(0.3, true), obs(0.5, false), obs(0.7, true),
        ];
        let d = compute_live_readout_with_observations(&observations).unwrap();
        let s = d.observation_summary.unwrap();
        assert_eq!(s.count, 4);
        assert_eq!(s.positives, 2);
        assert_eq!(s.negatives, 2);
    }

    #[test]
    fn with_observations_summary_matches_direct_summarize_call() {
        let observations = vec![obs(0.2, true), obs(0.6, false), obs(0.9, true)];
        let d = compute_live_readout_with_observations(&observations).unwrap();
        let direct = super::summarize(&observations).unwrap();
        assert_eq!(d.observation_summary.unwrap(), direct);
    }

    #[test]
    fn with_empty_observations_produces_some_with_zero_count() {
        // summarize() returns an Ok(AugmentedSummary{count: 0, ...}) for
        // empty input — NOT an error. So the diagnostic's
        // observation_summary is Some(empty), not None.
        let d = compute_live_readout_with_observations(&[]).unwrap();
        let s = d.observation_summary.unwrap();
        assert_eq!(s.count, 0);
        assert!(s.min_potential.is_none());
    }

    #[test]
    fn with_observations_propagates_negative_score_error() {
        let observations = vec![obs(0.5, true), obs(-0.1, false)];
        let err = compute_live_readout_with_observations(&observations).unwrap_err();
        assert!(matches!(err, DiagnosticError::AugmentFailed(_)));
    }

    #[test]
    fn with_observations_substrate_fields_match_default_readout() {
        // The substrate-floor fields (ULP, gate, sentinel, fence) should
        // be the same regardless of which entry the caller uses; only
        // the observation_summary differs.
        let base = compute_live_readout().unwrap();
        let observations = vec![obs(0.4, true), obs(0.6, false)];
        let with_obs = compute_live_readout_with_observations(&observations).unwrap();
        assert_eq!(base.ulp_smoke_max_error, with_obs.ulp_smoke_max_error);
        assert_eq!(base.ulp_smoke_samples_total, with_obs.ulp_smoke_samples_total);
        assert_eq!(base.schema_freeze_allowed, with_obs.schema_freeze_allowed);
        assert_eq!(base.potential_sentinel_at_one, with_obs.potential_sentinel_at_one);
        assert_eq!(base.universality_fence_text, with_obs.universality_fence_text);
    }

    #[test]
    fn with_observations_serde_json_roundtrip() {
        let observations = vec![obs(0.2, false), obs(0.8, true)];
        let d = compute_live_readout_with_observations(&observations).unwrap();
        let json = serde_json::to_string(&d).unwrap();
        let back: EmlEnergyDiagnostic = serde_json::from_str(&json).unwrap();
        assert_eq!(d, back);
        assert!(json.contains("\"observation_summary\""),
            "json was {}", json);
    }
}
