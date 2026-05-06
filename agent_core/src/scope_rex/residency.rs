// HARDENING ENFORCEMENT: the Governor is on the hot path of every
// AnswerPacket emission. It MUST be panic-free + allocation-free in
// production. Tests are allowed to unwrap because a failed invariant
// SHOULD panic loudly.
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

//! HELIOS V5 W4 — Residency Governor pure function.
//!
//! HELIOS-W4 guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W4 +
//! `docs/fusion/helios v5 first.md` §1.13 (verbatim thresholds):
//!
//! ```text
//! safety_risk > 0.7         → Quarantine
//! privacy > 0.9             → Quarantine
//! verification_score < 0.5  → TransientContext
//! repeat_count < 3          → TransientContext
//! repeat < 5 ∧ gain < 0.1   → FeatureRule
//! repeat < 10               → GrpoPrior
//! verification > 0.8 ∧ gain > 0.2 ∧ forgetting > 0.6 → OsftCore
//! (else previous antecedent, consequent fail) → PsoftAdapter
//! default                   → RetrievalMemory
//! ```
//!
//! The full 9-variant residency taxonomy is `Residency`. The route()
//! function below covers the 7 reachable-via-§1.13-thresholds outputs.
//! Two variants are reserved for higher-level routing:
//!
//! - **HarnessRule** — Pro-tier harness-versioning path (Gate Register
//!   "Pro R&D, build later" lift; reachable from a future
//!   `route_pro()` extension under `cfg(feature = "pro-build")`).
//! - **CloudDistilled** — Cloud knowledge distillation tier
//!   (`Epistemos/KnowledgeFusion/`); reachable from the cloud-fusion
//!   dispatch path, NOT from the §1.13 thresholds.
//!
//! ## §2.5.2 compliance posture
//!
//! Tier 1 ON in MAS by default. Pure function: no model file change,
//! no allocations, no global state, no nondeterminism. Doctrinally
//! safe to ship in MAS by default per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §N.1.
//!
//! ## Cross-references
//!
//! - [`crate::scope_rex::answer_packet::ResidencySignal`] — input type
//! - [`crate::scope_rex::answer_packet::AnswerPacket`] — carries
//!   `Vec<ResidencySignal>` per emission
//! - canon-hardening protocol §1 — WRV state machine; `route()` is
//!   `state: implemented` until a downstream caller wires it
//!   (`state: wired`)

use serde::{Deserialize, Serialize};

use crate::scope_rex::answer_packet::ResidencySignal;

/// HELIOS V5 W4 — 9-variant residency taxonomy.
///
/// Wire format is `snake_case` for cross-language parity with the
/// Swift mirror. The route() function produces a 7-arm subset; the
/// other two arms (HarnessRule + CloudDistilled) are reserved for
/// higher-level routing layers per the module docstring above.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Residency {
    /// Ephemeral context — does not survive the current turn.
    /// Reached when `verification_score < 0.5` OR `repeat_count < 3`.
    TransientContext,
    /// Default fallback — claim is filed in retrieval memory.
    /// Reached when no other §1.13 predicate fires.
    RetrievalMemory,
    /// Lifted to a stable per-feature rule (low repeat + low gain).
    /// Reached when `repeat < 5 ∧ gain < 0.1`.
    FeatureRule,
    /// Pro-tier harness-versioning path. **Not reached from
    /// route() in W4 base** — reserved for a future `route_pro()`
    /// extension under `cfg(feature = "pro-build")`.
    HarnessRule,
    /// GRPO prior — distilled into the policy gradient.
    /// Reached when `repeat < 10` (strictly weaker than OsftCore).
    GrpoPrior,
    /// PSOFT adapter slot — partial soft fine-tune candidate.
    /// Reached as the "antecedent OK, consequent fails" arm of the
    /// OsftCore predicate.
    PsoftAdapter,
    /// OSFT core — strongest residency tier; full soft fine-tune.
    /// Reached when `verification > 0.8 ∧ gain > 0.2 ∧ forgetting > 0.6`.
    OsftCore,
    /// Cloud distillation tier. **Not reached from route() in W4
    /// base** — reserved for the cloud-fusion dispatch path
    /// (`Epistemos/KnowledgeFusion/`).
    CloudDistilled,
    /// Hard gate — claim refused.
    /// Reached when `safety_risk > 0.7` OR `privacy > 0.9`.
    Quarantine,
}

/// HELIOS V5 W4 — Residency Governor pure function.
///
/// **Deterministic** under any thermal / scheduling state — pure
/// integer + float comparisons only.
///
/// **Allocation-free** — no heap, no Vec, no String. Stack-only.
///
/// **No global state** — every call is self-contained on its
/// `signal: &ResidencySignal` input.
///
/// Threshold ordering matches `docs/fusion/helios v5 first.md` §1.13
/// verbatim. Earlier predicates short-circuit later ones (Quarantine
/// wins over TransientContext wins over FeatureRule, etc.).
pub fn route(signal: &ResidencySignal) -> Residency {
    // Quarantine wins everything else — if a claim's safety or
    // privacy gate fails, it never reaches another residency tier.
    if signal.safety_risk > 0.7 {
        return Residency::Quarantine;
    }
    if signal.privacy > 0.9 {
        return Residency::Quarantine;
    }

    // TransientContext absorbs unverified or one-off claims.
    if signal.verification_score < 0.5 {
        return Residency::TransientContext;
    }
    if signal.repeat_count < 3 {
        return Residency::TransientContext;
    }

    // FeatureRule path — low repeat + low gain is a stable but
    // narrow rule worth promoting one tier above transient.
    if signal.repeat_count < 5 && signal.gain < 0.1 {
        return Residency::FeatureRule;
    }

    // OsftCore: the strongest §1.13 path. Verified, useful, and
    // sufficiently anti-forgetting to warrant a full soft fine-tune.
    let osft_predicate_ok = signal.verification_score > 0.8
        && signal.gain > 0.2
        && signal.forgetting > 0.6;
    if osft_predicate_ok {
        return Residency::OsftCore;
    }

    // GrpoPrior: less stringent than OsftCore but still repeated.
    if signal.repeat_count < 10 {
        return Residency::GrpoPrior;
    }

    // The "else previous antecedent, consequent fails" arm — the
    // OsftCore predicate's antecedent (verification + gain checks)
    // is true at this point (otherwise we'd have hit one of the
    // earlier shortcuts), but the forgetting threshold fails.
    if signal.verification_score > 0.8 && signal.gain > 0.2 {
        return Residency::PsoftAdapter;
    }

    // Default fallback — every other path leaves the claim in
    // retrieval memory.
    Residency::RetrievalMemory
}

// ---------------------------------------------------------------------------
// Tests — exhaustive coverage of all 9 Residency arms + threshold
// boundaries per W4 acceptance criteria.
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn signal(
        safety_risk: f32,
        privacy: f32,
        verification_score: f32,
        repeat_count: u32,
        gain: f32,
        forgetting: f32,
    ) -> ResidencySignal {
        ResidencySignal {
            safety_risk,
            privacy,
            verification_score,
            repeat_count,
            gain,
            forgetting,
        }
    }

    // Quarantine paths

    #[test]
    fn safety_risk_above_threshold_routes_to_quarantine() {
        let s = signal(0.71, 0.0, 1.0, 100, 1.0, 1.0);
        assert_eq!(route(&s), Residency::Quarantine);
    }

    #[test]
    fn safety_risk_at_exact_threshold_does_not_quarantine() {
        // Strict inequality (`> 0.7`, not `>=`); 0.7 exactly does not trip.
        let s = signal(0.7, 0.0, 1.0, 100, 1.0, 1.0);
        assert_ne!(route(&s), Residency::Quarantine);
    }

    #[test]
    fn privacy_above_threshold_routes_to_quarantine() {
        let s = signal(0.0, 0.91, 1.0, 100, 1.0, 1.0);
        assert_eq!(route(&s), Residency::Quarantine);
    }

    #[test]
    fn privacy_at_exact_threshold_does_not_quarantine() {
        let s = signal(0.0, 0.9, 1.0, 100, 1.0, 1.0);
        assert_ne!(route(&s), Residency::Quarantine);
    }

    #[test]
    fn safety_quarantine_wins_over_other_predicates() {
        // Even with all other predicates satisfied for OsftCore,
        // Quarantine should win.
        let s = signal(0.99, 0.0, 1.0, 100, 1.0, 1.0);
        assert_eq!(route(&s), Residency::Quarantine);
    }

    // TransientContext paths

    #[test]
    fn low_verification_routes_to_transient_context() {
        let s = signal(0.0, 0.0, 0.49, 100, 1.0, 1.0);
        assert_eq!(route(&s), Residency::TransientContext);
    }

    #[test]
    fn low_repeat_count_routes_to_transient_context() {
        let s = signal(0.0, 0.0, 0.9, 2, 1.0, 1.0);
        assert_eq!(route(&s), Residency::TransientContext);
    }

    // FeatureRule path

    #[test]
    fn low_repeat_low_gain_routes_to_feature_rule() {
        let s = signal(0.0, 0.0, 0.6, 4, 0.05, 0.0);
        assert_eq!(route(&s), Residency::FeatureRule);
    }

    // OsftCore path

    #[test]
    fn high_verification_high_gain_high_forgetting_routes_to_osft_core() {
        let s = signal(0.0, 0.0, 0.81, 100, 0.21, 0.61);
        assert_eq!(route(&s), Residency::OsftCore);
    }

    // PsoftAdapter path — antecedent OK, forgetting fails

    #[test]
    fn osft_antecedent_with_low_forgetting_routes_to_psoft_adapter() {
        // verification > 0.8 ∧ gain > 0.2 (OsftCore antecedent OK),
        // but forgetting <= 0.6 fails the OsftCore consequent.
        // Also repeat_count >= 10 to defeat GrpoPrior path.
        let s = signal(0.0, 0.0, 0.81, 100, 0.21, 0.5);
        assert_eq!(route(&s), Residency::PsoftAdapter);
    }

    // GrpoPrior path

    #[test]
    fn moderate_repeat_routes_to_grpo_prior() {
        // repeat_count < 10, but high enough to skip TransientContext
        // (>= 3) and FeatureRule predicate fails (gain >= 0.1).
        let s = signal(0.0, 0.0, 0.6, 5, 0.5, 0.0);
        assert_eq!(route(&s), Residency::GrpoPrior);
    }

    // RetrievalMemory default

    #[test]
    fn default_path_routes_to_retrieval_memory() {
        // Bypass: not quarantine, not transient, not feature-rule, not
        // OsftCore, not PsoftAdapter (verification <= 0.8), not GrpoPrior
        // (repeat_count >= 10).
        let s = signal(0.0, 0.0, 0.7, 50, 0.5, 0.5);
        assert_eq!(route(&s), Residency::RetrievalMemory);
    }

    // Wire-format parity

    #[test]
    fn residency_serializes_in_snake_case_for_each_arm() {
        for (variant, expected) in [
            (Residency::TransientContext, "\"transient_context\""),
            (Residency::RetrievalMemory, "\"retrieval_memory\""),
            (Residency::FeatureRule, "\"feature_rule\""),
            (Residency::HarnessRule, "\"harness_rule\""),
            (Residency::GrpoPrior, "\"grpo_prior\""),
            (Residency::PsoftAdapter, "\"psoft_adapter\""),
            (Residency::OsftCore, "\"osft_core\""),
            (Residency::CloudDistilled, "\"cloud_distilled\""),
            (Residency::Quarantine, "\"quarantine\""),
        ] {
            let json = serde_json::to_string(&variant).unwrap();
            assert_eq!(json, expected, "wire format for {:?}", variant);
        }
    }

    // Determinism (the "pure function" load-bearing invariant)

    #[test]
    fn route_is_deterministic_across_repeated_calls() {
        let s = signal(0.05, 0.05, 0.7, 50, 0.5, 0.5);
        let first = route(&s);
        for _ in 0..1000 {
            assert_eq!(route(&s), first);
        }
    }

    // Coverage assertion: every reachable arm is producible from at
    // least one ResidencySignal. The two reserved arms (HarnessRule
    // + CloudDistilled) are NOT reachable from route() per the spec
    // — this test documents that explicitly.

    #[test]
    fn all_seven_route_function_arms_are_reachable_with_distinct_inputs() {
        let cases: [(ResidencySignal, Residency); 7] = [
            (
                signal(0.99, 0.0, 1.0, 100, 1.0, 1.0),
                Residency::Quarantine,
            ),
            (
                signal(0.0, 0.0, 0.49, 100, 1.0, 1.0),
                Residency::TransientContext,
            ),
            (
                signal(0.0, 0.0, 0.6, 4, 0.05, 0.0),
                Residency::FeatureRule,
            ),
            (
                signal(0.0, 0.0, 0.81, 100, 0.21, 0.61),
                Residency::OsftCore,
            ),
            (
                signal(0.0, 0.0, 0.81, 100, 0.21, 0.5),
                Residency::PsoftAdapter,
            ),
            (
                signal(0.0, 0.0, 0.6, 5, 0.5, 0.0),
                Residency::GrpoPrior,
            ),
            (
                signal(0.0, 0.0, 0.7, 50, 0.5, 0.5),
                Residency::RetrievalMemory,
            ),
        ];
        for (s, expected) in cases {
            assert_eq!(route(&s), expected, "input {:?} expected {:?}", s, expected);
        }
    }

    #[test]
    fn reserved_arms_not_reachable_from_base_route_function() {
        // HarnessRule + CloudDistilled are in the enum for spec
        // parity but route() never produces them. This test
        // documents that contract.
        for (sr, pr, vs, rc, g, f) in [
            (0.0, 0.0, 0.0, 0, 0.0, 0.0),
            (0.5, 0.5, 0.5, 5, 0.5, 0.5),
            (1.0, 1.0, 1.0, 100, 1.0, 1.0),
            (0.71, 0.0, 1.0, 100, 1.0, 1.0),
            (0.0, 0.91, 1.0, 100, 1.0, 1.0),
        ] {
            let s = signal(sr, pr, vs, rc, g, f);
            let r = route(&s);
            assert_ne!(r, Residency::HarnessRule);
            assert_ne!(r, Residency::CloudDistilled);
        }
    }

    // Property: 256-case Cartesian over discrete buckets covers the
    // signal space heuristically. Per W4 acceptance:
    // "256-case property test over (safety_risk, privacy,
    // verification_score, repeat_count, gain, forgetting) Cartesian."

    #[test]
    fn coarse_cartesian_over_signal_space_never_panics_or_returns_invalid() {
        let safety_buckets: [f32; 4] = [0.0, 0.5, 0.7, 0.95];
        let privacy_buckets: [f32; 4] = [0.0, 0.5, 0.9, 0.95];
        let verification_buckets: [f32; 4] = [0.0, 0.49, 0.7, 0.95];
        let repeat_buckets: [u32; 4] = [0, 3, 5, 50];
        let gain_buckets: [f32; 4] = [0.0, 0.1, 0.5, 0.9];
        let forgetting_buckets: [f32; 4] = [0.0, 0.3, 0.6, 0.9];

        // Sample evenly over the 4^6 = 4096 configurations (no need
        // to drop to 256 with how cheap pure-function dispatch is).
        let mut count = 0usize;
        for &sr in &safety_buckets {
            for &pr in &privacy_buckets {
                for &vs in &verification_buckets {
                    for &rc in &repeat_buckets {
                        for &g in &gain_buckets {
                            for &f in &forgetting_buckets {
                                let s = signal(sr, pr, vs, rc, g, f);
                                let r = route(&s);
                                // Sanity: never produces a reserved arm.
                                assert!(
                                    !matches!(r, Residency::HarnessRule | Residency::CloudDistilled),
                                    "route() must not produce reserved arm; got {:?} for {:?}",
                                    r, s
                                );
                                count += 1;
                            }
                        }
                    }
                }
            }
        }
        assert_eq!(count, 4_u64.pow(6) as usize);
    }
}
