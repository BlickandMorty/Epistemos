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
//! - [`MemoryTier`] — 5-arm tier hierarchy (L0/L1/L2/L3/L4) per the
//!   compass artifact reconciliation §B.1 + canonical codec
//!   per-tier (`tier_codec()`)
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

/// 5-tier memory hierarchy per the compass-artifact reconciliation
/// (`source_docs/compass_artifact_wf-...md` §B.1, "canonical:
/// 5-tier"). Supersedes the earlier 4-tier sketch which collapsed
/// L4 (cloud) into the escalation policy.
///
/// Tiers ordered from hottest (L0) to coldest (L4):
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MemoryTier {
    /// L0 Exact Hot — last `W` tokens, full K/V, attention sinks.
    /// Substrate: unified RAM. Codec: bf16 / fp16.
    L0ExactHot,
    /// L1 Compressed Residual — mid-window tokens. Substrate: unified
    /// RAM. Codec: Sherry 1.25-bit on the residual stream
    /// (Qasim arXiv:2603.19664: K, V are bit-identical projections of
    /// residual) + per-channel scales.
    L1CompressedResidual,
    /// L2 Shadow Sketch — pages older than `W·k` tokens; queryable.
    /// Substrate: unified RAM (or IOSurface-backed Metal heap).
    /// Codec: sparse JL (Kane-Nelson 2014) over an FRP basis
    /// (Hayase-Collins-Inoue arXiv:2504.06983); CountSketch
    /// (Charikar 2002) over page IDs for top-k routing.
    L2ShadowSketch,
    /// L3 SSD Oracle — cold pages; episode log. Substrate: NVMe via
    /// IOSurface + mmap. Codec: NF4 / 3-bit groupwise (KVQuant-style)
    /// residual checkpoints.
    L3SsdOracle,
    /// L4 Hermes Cascade — reasoning escalations when L0-L3 confidence
    /// < τ. Substrate: network → Hermes-4-405B (or other frontier
    /// model). Codec: none — raw prompt.
    L4HermesCascade,
}

/// Canonical codec name per memory tier. Returned values are stable
/// strings suitable for telemetry, manifests, and replay-bundle
/// metadata. Changing them is a canon violation.
pub fn tier_codec(tier: MemoryTier) -> &'static str {
    match tier {
        MemoryTier::L0ExactHot => "bf16_fp16",
        MemoryTier::L1CompressedResidual => "sherry_1_25bit_on_residual",
        MemoryTier::L2ShadowSketch => "sparse_jl_over_frp_plus_countsketch",
        MemoryTier::L3SsdOracle => "nf4_or_3bit_groupwise",
        MemoryTier::L4HermesCascade => "raw_prompt",
    }
}

/// All 5 memory tiers in canonical hot-to-cold order.
pub const ALL_TIERS: [MemoryTier; 5] = [
    MemoryTier::L0ExactHot,
    MemoryTier::L1CompressedResidual,
    MemoryTier::L2ShadowSketch,
    MemoryTier::L3SsdOracle,
    MemoryTier::L4HermesCascade,
];

impl MemoryTier {
    /// Returns the tier's depth index (0 = hottest, 4 = coldest).
    pub fn depth(self) -> usize {
        match self {
            MemoryTier::L0ExactHot => 0,
            MemoryTier::L1CompressedResidual => 1,
            MemoryTier::L2ShadowSketch => 2,
            MemoryTier::L3SsdOracle => 3,
            MemoryTier::L4HermesCascade => 4,
        }
    }

    /// True when this tier crosses the network boundary (L4 only).
    /// Per compass artifact §B.1: "L4 (cloud fallback) ... hides a
    /// real architectural seam (network boundary, billing boundary,
    /// privacy boundary)."
    pub fn crosses_network_boundary(self) -> bool {
        matches!(self, MemoryTier::L4HermesCascade)
    }

    /// True when the tier resides in unified RAM (L0/L1/L2). L3 is
    /// SSD-backed; L4 is network.
    pub fn resident_in_uma(self) -> bool {
        matches!(
            self,
            MemoryTier::L0ExactHot | MemoryTier::L1CompressedResidual | MemoryTier::L2ShadowSketch
        )
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

    // -- 5-tier hierarchy tests ----------------------------------------

    #[test]
    fn five_tiers_listed_in_canonical_hot_to_cold_order() {
        assert_eq!(ALL_TIERS.len(), 5);
        assert_eq!(ALL_TIERS[0], MemoryTier::L0ExactHot);
        assert_eq!(ALL_TIERS[4], MemoryTier::L4HermesCascade);
        // Depth must equal index in canonical order.
        for (i, tier) in ALL_TIERS.iter().enumerate() {
            assert_eq!(tier.depth(), i);
        }
    }

    #[test]
    fn five_tiers_are_distinct() {
        let set: std::collections::HashSet<MemoryTier> =
            ALL_TIERS.iter().copied().collect();
        assert_eq!(set.len(), 5);
    }

    #[test]
    fn only_l4_crosses_network_boundary() {
        for tier in ALL_TIERS {
            if tier == MemoryTier::L4HermesCascade {
                assert!(tier.crosses_network_boundary());
            } else {
                assert!(!tier.crosses_network_boundary());
            }
        }
    }

    #[test]
    fn l0_l1_l2_resident_in_uma_l3_l4_not() {
        assert!(MemoryTier::L0ExactHot.resident_in_uma());
        assert!(MemoryTier::L1CompressedResidual.resident_in_uma());
        assert!(MemoryTier::L2ShadowSketch.resident_in_uma());
        assert!(!MemoryTier::L3SsdOracle.resident_in_uma());
        assert!(!MemoryTier::L4HermesCascade.resident_in_uma());
    }

    #[test]
    fn tier_codec_returns_canonical_string_per_tier() {
        // Pin the canonical codec strings — changes are canon violations.
        assert_eq!(tier_codec(MemoryTier::L0ExactHot), "bf16_fp16");
        assert_eq!(
            tier_codec(MemoryTier::L1CompressedResidual),
            "sherry_1_25bit_on_residual"
        );
        assert_eq!(
            tier_codec(MemoryTier::L2ShadowSketch),
            "sparse_jl_over_frp_plus_countsketch"
        );
        assert_eq!(
            tier_codec(MemoryTier::L3SsdOracle),
            "nf4_or_3bit_groupwise"
        );
        assert_eq!(tier_codec(MemoryTier::L4HermesCascade), "raw_prompt");
    }

    #[test]
    fn memory_tier_serializes_in_snake_case() {
        for (tier, expected) in [
            (MemoryTier::L0ExactHot, "\"l0_exact_hot\""),
            (MemoryTier::L1CompressedResidual, "\"l1_compressed_residual\""),
            (MemoryTier::L2ShadowSketch, "\"l2_shadow_sketch\""),
            (MemoryTier::L3SsdOracle, "\"l3_ssd_oracle\""),
            (MemoryTier::L4HermesCascade, "\"l4_hermes_cascade\""),
        ] {
            assert_eq!(serde_json::to_string(&tier).unwrap(), expected);
        }
    }

    #[test]
    fn memory_tier_round_trips_through_json() {
        for tier in ALL_TIERS {
            let json = serde_json::to_string(&tier).unwrap();
            let parsed: MemoryTier = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, tier);
        }
    }
}
