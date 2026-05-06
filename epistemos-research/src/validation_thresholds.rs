//! HELIOS V5 — Seven canonical validation thresholds (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-VALIDATION-THRESHOLDS guard
//!
//! Per HELIOS v4 preservation `source_docs/epistemos_definitive_master.md`
//! §"PART VI: VALIDATION, FALSIFIERS, SHARPEST NEXT MOVE" §1.
//!
//! Seven canonical thresholds any Helios deployment must clear before
//! claiming readiness:
//!
//!   1. KL divergence < 0.05 at 128k context (oracle vs Helios)
//!   2. Compression ratio > 10× vs bf16 baseline
//!   3. Top-k recall > 0.95 at k=10 across needle-in-haystack
//!   4. L4 escalation < 5% of decode steps
//!   5. Peak RAM ≤ 12 GB on M3 Max 64 GB
//!   6. Decode ≥ 20 tok/s
//!   7. SSM-Tx gap ≤ 5 pp on every metric
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

// -- Per-threshold canonical bounds (PINNED) --------------------------------

/// Threshold 1 — KL divergence ceiling at 128k context.
pub const KL_DIVERGENCE_MAX: f32 = 0.05;

/// Threshold 2 — Minimum compression ratio vs bf16 baseline.
pub const COMPRESSION_RATIO_MIN: f32 = 10.0;

/// Threshold 3 — Top-k recall floor at k=10.
pub const TOP_K_RECALL_MIN: f32 = 0.95;

/// Threshold 4 — L4 escalation rate ceiling (fraction of decode steps).
pub const L4_ESCALATION_RATE_MAX: f32 = 0.05;

/// Threshold 5 — Peak RAM ceiling in gigabytes (M3 Max 64 GB profile).
pub const PEAK_RAM_GB_MAX: f32 = 12.0;

/// Threshold 6 — Minimum decode throughput in tokens per second.
pub const DECODE_TOK_PER_SEC_MIN: f32 = 20.0;

/// Threshold 7 — Maximum SSM-Tx (state-space vs transformer) gap in
/// percentage points across any metric.
pub const SSM_TX_GAP_PP_MAX: f32 = 5.0;

/// One of seven canonical validation thresholds.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ValidationThreshold {
    KlDivergence,
    CompressionRatio,
    TopKRecall,
    L4EscalationRate,
    PeakRamGb,
    DecodeThroughput,
    SsmTxGap,
}

impl ValidationThreshold {
    /// Numeric bound per the canonical doctrine. Direction (≤ vs ≥)
    /// is given by [`is_ceiling`] / [`is_floor`].
    pub fn bound(self) -> f32 {
        match self {
            ValidationThreshold::KlDivergence => KL_DIVERGENCE_MAX,
            ValidationThreshold::CompressionRatio => COMPRESSION_RATIO_MIN,
            ValidationThreshold::TopKRecall => TOP_K_RECALL_MIN,
            ValidationThreshold::L4EscalationRate => L4_ESCALATION_RATE_MAX,
            ValidationThreshold::PeakRamGb => PEAK_RAM_GB_MAX,
            ValidationThreshold::DecodeThroughput => DECODE_TOK_PER_SEC_MIN,
            ValidationThreshold::SsmTxGap => SSM_TX_GAP_PP_MAX,
        }
    }

    /// True when the bound is a CEILING (observation must be ≤ bound).
    pub fn is_ceiling(self) -> bool {
        matches!(
            self,
            ValidationThreshold::KlDivergence
                | ValidationThreshold::L4EscalationRate
                | ValidationThreshold::PeakRamGb
                | ValidationThreshold::SsmTxGap
        )
    }

    /// True when the bound is a FLOOR (observation must be ≥ bound).
    pub fn is_floor(self) -> bool {
        !self.is_ceiling()
    }

    /// Verify an observation against this threshold. Returns true
    /// when the observation respects the bound.
    pub fn passes(self, observation: f32) -> bool {
        if !observation.is_finite() {
            return false;
        }
        if self.is_ceiling() {
            observation <= self.bound()
        } else {
            observation >= self.bound()
        }
    }

    /// Short canonical name for telemetry / dashboards.
    pub fn canonical_name(self) -> &'static str {
        match self {
            ValidationThreshold::KlDivergence => "kl_divergence",
            ValidationThreshold::CompressionRatio => "compression_ratio",
            ValidationThreshold::TopKRecall => "top_k_recall",
            ValidationThreshold::L4EscalationRate => "l4_escalation_rate",
            ValidationThreshold::PeakRamGb => "peak_ram_gb",
            ValidationThreshold::DecodeThroughput => "decode_tok_per_sec",
            ValidationThreshold::SsmTxGap => "ssm_tx_gap_pp",
        }
    }
}

/// All seven thresholds in canonical doctrine order.
pub const SEVEN_THRESHOLDS: [ValidationThreshold; 7] = [
    ValidationThreshold::KlDivergence,
    ValidationThreshold::CompressionRatio,
    ValidationThreshold::TopKRecall,
    ValidationThreshold::L4EscalationRate,
    ValidationThreshold::PeakRamGb,
    ValidationThreshold::DecodeThroughput,
    ValidationThreshold::SsmTxGap,
];

/// Run all seven thresholds against a parallel observation array.
/// Returns the indices of any failing thresholds.
pub fn check_all(observations: [f32; 7]) -> Vec<ValidationThreshold> {
    SEVEN_THRESHOLDS
        .iter()
        .zip(observations.iter())
        .filter_map(|(threshold, &obs)| {
            if !threshold.passes(obs) {
                Some(*threshold)
            } else {
                None
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn seven_thresholds_in_canonical_order() {
        assert_eq!(SEVEN_THRESHOLDS.len(), 7);
        assert_eq!(SEVEN_THRESHOLDS[0], ValidationThreshold::KlDivergence);
        assert_eq!(SEVEN_THRESHOLDS[6], ValidationThreshold::SsmTxGap);
    }

    #[test]
    fn seven_thresholds_are_distinct() {
        let set: std::collections::HashSet<ValidationThreshold> =
            SEVEN_THRESHOLDS.iter().copied().collect();
        assert_eq!(set.len(), 7);
    }

    #[test]
    fn ceiling_thresholds_are_kl_l4_ram_gap() {
        assert!(ValidationThreshold::KlDivergence.is_ceiling());
        assert!(ValidationThreshold::L4EscalationRate.is_ceiling());
        assert!(ValidationThreshold::PeakRamGb.is_ceiling());
        assert!(ValidationThreshold::SsmTxGap.is_ceiling());
    }

    #[test]
    fn floor_thresholds_are_compression_recall_throughput() {
        assert!(ValidationThreshold::CompressionRatio.is_floor());
        assert!(ValidationThreshold::TopKRecall.is_floor());
        assert!(ValidationThreshold::DecodeThroughput.is_floor());
    }

    #[test]
    fn ceiling_and_floor_are_disjoint() {
        for t in SEVEN_THRESHOLDS {
            assert_ne!(t.is_ceiling(), t.is_floor());
        }
    }

    #[test]
    fn canonical_bounds_match_doctrine() {
        // Pin every bound — changes are canon violations.
        assert_eq!(KL_DIVERGENCE_MAX, 0.05);
        assert_eq!(COMPRESSION_RATIO_MIN, 10.0);
        assert_eq!(TOP_K_RECALL_MIN, 0.95);
        assert_eq!(L4_ESCALATION_RATE_MAX, 0.05);
        assert_eq!(PEAK_RAM_GB_MAX, 12.0);
        assert_eq!(DECODE_TOK_PER_SEC_MIN, 20.0);
        assert_eq!(SSM_TX_GAP_PP_MAX, 5.0);
    }

    #[test]
    fn passes_for_in_bound_observations() {
        assert!(ValidationThreshold::KlDivergence.passes(0.04));
        assert!(ValidationThreshold::CompressionRatio.passes(11.0));
        assert!(ValidationThreshold::TopKRecall.passes(0.96));
        assert!(ValidationThreshold::L4EscalationRate.passes(0.04));
        assert!(ValidationThreshold::PeakRamGb.passes(11.5));
        assert!(ValidationThreshold::DecodeThroughput.passes(25.0));
        assert!(ValidationThreshold::SsmTxGap.passes(4.0));
    }

    #[test]
    fn passes_for_exact_bound_values() {
        // Boundary semantics: exact bound is acceptable for both
        // ceilings (≤) and floors (≥).
        assert!(ValidationThreshold::KlDivergence.passes(KL_DIVERGENCE_MAX));
        assert!(ValidationThreshold::CompressionRatio.passes(COMPRESSION_RATIO_MIN));
    }

    #[test]
    fn fails_for_out_of_bound_observations() {
        assert!(!ValidationThreshold::KlDivergence.passes(0.06));
        assert!(!ValidationThreshold::CompressionRatio.passes(9.0));
        assert!(!ValidationThreshold::TopKRecall.passes(0.94));
        assert!(!ValidationThreshold::DecodeThroughput.passes(19.0));
    }

    #[test]
    fn nan_and_infinity_observations_always_fail() {
        for t in SEVEN_THRESHOLDS {
            assert!(!t.passes(f32::NAN));
            assert!(!t.passes(f32::INFINITY));
            assert!(!t.passes(f32::NEG_INFINITY));
        }
    }

    #[test]
    fn check_all_returns_empty_when_all_thresholds_pass() {
        // Observations within bounds for all seven.
        let obs = [0.04_f32, 11.0, 0.96, 0.04, 11.5, 25.0, 4.0];
        assert!(check_all(obs).is_empty());
    }

    #[test]
    fn check_all_flags_failing_thresholds() {
        // KL too high; throughput too low.
        let obs = [0.06_f32, 11.0, 0.96, 0.04, 11.5, 19.0, 4.0];
        let failures = check_all(obs);
        assert_eq!(failures.len(), 2);
        assert!(failures.contains(&ValidationThreshold::KlDivergence));
        assert!(failures.contains(&ValidationThreshold::DecodeThroughput));
    }

    #[test]
    fn canonical_name_is_snake_case() {
        for t in SEVEN_THRESHOLDS {
            let name = t.canonical_name();
            assert!(!name.is_empty());
            assert_eq!(name, name.to_lowercase());
            assert!(!name.contains(' '));
        }
    }

    #[test]
    fn validation_threshold_serializes_in_snake_case() {
        for (t, expected) in [
            (ValidationThreshold::KlDivergence, "\"kl_divergence\""),
            (ValidationThreshold::CompressionRatio, "\"compression_ratio\""),
            (ValidationThreshold::TopKRecall, "\"top_k_recall\""),
            (ValidationThreshold::L4EscalationRate, "\"l4_escalation_rate\""),
            (ValidationThreshold::PeakRamGb, "\"peak_ram_gb\""),
            (ValidationThreshold::DecodeThroughput, "\"decode_throughput\""),
            (ValidationThreshold::SsmTxGap, "\"ssm_tx_gap\""),
        ] {
            assert_eq!(serde_json::to_string(&t).unwrap(), expected);
        }
    }

    #[test]
    fn validation_threshold_round_trips_through_json() {
        for t in SEVEN_THRESHOLDS {
            let json = serde_json::to_string(&t).unwrap();
            let parsed: ValidationThreshold = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, t);
        }
    }
}
