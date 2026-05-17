//! Source:
//! - `docs/fusion/LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md` §4 —
//!   "Compiled state requires a signed plan; the runner refuses to
//!   admit a plan with missing required fields or zero budget."
//! - `docs/fusion/research/FINAL_SYNTHESIS.md` §1.2 — LivePlanV1
//!   shape contract.
//! - Companion to [`super::LivePlanV1`] (the struct this module
//!   validates) and [`super::transitions`] (the state-machine that
//!   gates Compiled → Eligible on this validator passing).
//!
//! # Wave J B.6.11 — LivePlanV1 structural validator
//!
//! `LivePlanV1` carries enough fields that a hand-constructed or
//! corrupted plan can pass the type system while still being
//! unrunnable (empty hash, zero budget, expires_at < compiled_at,
//! empty intent summary). This module is the structural gate that
//! the runner MUST call before transitioning a plan from
//! `Compiled → Eligible`.
//!
//! ## What this catches (structural)
//!
//! - Empty `livefile_id` / `source_uri` / `plan_version` / `plan_hash`
//!   / `compiled_at`.
//! - Empty `intent.summary` (a plan must declare what it does).
//! - `LivePlanBudget` with zero tokens AND zero ms AND zero usd (a
//!   plan must commit some resource).
//! - `expires_at` lexicographically before `compiled_at` (when both
//!   are present as ISO-8601 strings, lex compare matches temporal
//!   order — that's the whole point of ISO-8601).
//! - Empty `triggers` vec (a plan with no triggers is unreachable
//!   from Compiled forward).
//!
//! ## What this does NOT catch (deferred)
//!
//! - Signature verification (handled by the transitions G1 guard).
//! - Cron-expression parsing (substrate floor — production gates
//!   via `cron` crate dependency).
//! - JSON-Schema check on `intent.steps` / `eligibility.capabilities`
//!   (those land with the runtime that actually dispatches).

use super::LivePlanV1;

#[derive(Clone, Debug, PartialEq)]
pub enum LivePlanValidationError {
    EmptyLivefileId,
    EmptySourceUri,
    EmptyPlanVersion,
    EmptyPlanHash,
    EmptyCompiledAt,
    EmptyIntentSummary,
    NoTriggers,
    ZeroBudget,
    ExpiresBeforeCompiled { compiled_at: String, expires_at: String },
}

impl LivePlanValidationError {
    /// Stable identifier for the field/cause the validation failed on.
    /// Used by the control-room "fix this plan" UI to highlight the
    /// exact LivePlanV1 field that's broken.
    pub const fn field(&self) -> &'static str {
        match self {
            LivePlanValidationError::EmptyLivefileId => "livefile_id",
            LivePlanValidationError::EmptySourceUri => "source_uri",
            LivePlanValidationError::EmptyPlanVersion => "plan_version",
            LivePlanValidationError::EmptyPlanHash => "plan_hash",
            LivePlanValidationError::EmptyCompiledAt => "compiled_at",
            LivePlanValidationError::EmptyIntentSummary => "intent.summary",
            LivePlanValidationError::NoTriggers => "triggers",
            LivePlanValidationError::ZeroBudget => "eligibility.budget",
            LivePlanValidationError::ExpiresBeforeCompiled { .. } => "expires_at",
        }
    }

    /// Predicate: this error is an "empty required string" failure.
    /// Covers livefile_id / source_uri / plan_version / plan_hash /
    /// compiled_at / intent.summary.
    pub const fn is_empty_field(&self) -> bool {
        matches!(
            self,
            LivePlanValidationError::EmptyLivefileId
                | LivePlanValidationError::EmptySourceUri
                | LivePlanValidationError::EmptyPlanVersion
                | LivePlanValidationError::EmptyPlanHash
                | LivePlanValidationError::EmptyCompiledAt
                | LivePlanValidationError::EmptyIntentSummary
        )
    }

    /// Predicate: this error is the empty-triggers failure.
    pub const fn is_no_triggers(&self) -> bool {
        matches!(self, LivePlanValidationError::NoTriggers)
    }

    /// Predicate: this error is the all-zero budget failure.
    pub const fn is_zero_budget(&self) -> bool {
        matches!(self, LivePlanValidationError::ZeroBudget)
    }

    /// Predicate: this error is the temporal-ordering failure.
    pub const fn is_temporal(&self) -> bool {
        matches!(self, LivePlanValidationError::ExpiresBeforeCompiled { .. })
    }
}

/// Predicate: this plan passes the structural validator. Alias for
/// `validate_plan(plan).is_ok()`. The "is the runner safe to admit
/// this plan?" check that does not surface the failure reason.
pub fn is_valid_plan(plan: &LivePlanV1) -> bool {
    validate_plan(plan).is_ok()
}

pub fn validate_plan(plan: &LivePlanV1) -> Result<(), LivePlanValidationError> {
    if plan.livefile_id.is_empty() {
        return Err(LivePlanValidationError::EmptyLivefileId);
    }
    if plan.source_uri.is_empty() {
        return Err(LivePlanValidationError::EmptySourceUri);
    }
    if plan.plan_version.is_empty() {
        return Err(LivePlanValidationError::EmptyPlanVersion);
    }
    if plan.plan_hash.is_empty() {
        return Err(LivePlanValidationError::EmptyPlanHash);
    }
    if plan.compiled_at.is_empty() {
        return Err(LivePlanValidationError::EmptyCompiledAt);
    }
    if plan.intent.summary.is_empty() {
        return Err(LivePlanValidationError::EmptyIntentSummary);
    }
    if plan.triggers.is_empty() {
        return Err(LivePlanValidationError::NoTriggers);
    }
    let b = &plan.eligibility.budget;
    if b.tokens == 0 && b.ms == 0 && b.usd == 0.0 {
        return Err(LivePlanValidationError::ZeroBudget);
    }
    if let Some(ref exp) = plan.expires_at {
        if !exp.is_empty() && exp.as_str() < plan.compiled_at.as_str() {
            return Err(LivePlanValidationError::ExpiresBeforeCompiled {
                compiled_at: plan.compiled_at.clone(),
                expires_at: exp.clone(),
            });
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use super::super::{
        BatteryRequirement, LivePlanBudget, LivePlanEligibility, LivePlanIntent,
        LivePlanTrigger, ThermalRequirement,
    };
    use crate::cognitive_weight::CognitiveWeight;

    fn ok_plan() -> LivePlanV1 {
        LivePlanV1 {
            livefile_id: "abc123".into(),
            source_uri: "vault://test.md".into(),
            plan_version: "1.0.0".into(),
            plan_hash: "deadbeef".into(),
            compiled_at: "2026-05-16T00:00:00Z".into(),
            expires_at: Some("2026-05-23T00:00:00Z".into()),
            cognitive_weight: CognitiveWeight::default(),
            triggers: vec![LivePlanTrigger::Manual],
            eligibility: LivePlanEligibility {
                thermal: ThermalRequirement::NominalRequired,
                battery: BatteryRequirement::AcOrAbove30,
                budget: LivePlanBudget {
                    tokens: 1000,
                    ms: 30_000,
                    usd: 0.05,
                },
                capabilities: serde_json::json!({}),
            },
            intent: LivePlanIntent {
                summary: "test intent".into(),
                steps: vec![],
            },
            prompt_for_changes: vec![],
        }
    }

    #[test]
    fn well_formed_plan_passes() {
        assert!(validate_plan(&ok_plan()).is_ok());
    }

    #[test]
    fn empty_livefile_id_rejected() {
        let mut p = ok_plan();
        p.livefile_id = String::new();
        assert_eq!(validate_plan(&p).unwrap_err(), LivePlanValidationError::EmptyLivefileId);
    }

    #[test]
    fn empty_source_uri_rejected() {
        let mut p = ok_plan();
        p.source_uri = String::new();
        assert_eq!(validate_plan(&p).unwrap_err(), LivePlanValidationError::EmptySourceUri);
    }

    #[test]
    fn empty_plan_version_rejected() {
        let mut p = ok_plan();
        p.plan_version = String::new();
        assert_eq!(validate_plan(&p).unwrap_err(), LivePlanValidationError::EmptyPlanVersion);
    }

    #[test]
    fn empty_plan_hash_rejected() {
        let mut p = ok_plan();
        p.plan_hash = String::new();
        assert_eq!(validate_plan(&p).unwrap_err(), LivePlanValidationError::EmptyPlanHash);
    }

    #[test]
    fn empty_compiled_at_rejected() {
        let mut p = ok_plan();
        p.compiled_at = String::new();
        assert_eq!(validate_plan(&p).unwrap_err(), LivePlanValidationError::EmptyCompiledAt);
    }

    #[test]
    fn empty_intent_summary_rejected() {
        let mut p = ok_plan();
        p.intent.summary = String::new();
        assert_eq!(validate_plan(&p).unwrap_err(), LivePlanValidationError::EmptyIntentSummary);
    }

    #[test]
    fn empty_triggers_rejected() {
        let mut p = ok_plan();
        p.triggers.clear();
        assert_eq!(validate_plan(&p).unwrap_err(), LivePlanValidationError::NoTriggers);
    }

    #[test]
    fn zero_budget_rejected() {
        let mut p = ok_plan();
        p.eligibility.budget = LivePlanBudget {
            tokens: 0,
            ms: 0,
            usd: 0.0,
        };
        assert_eq!(validate_plan(&p).unwrap_err(), LivePlanValidationError::ZeroBudget);
    }

    #[test]
    fn non_zero_token_budget_alone_passes() {
        let mut p = ok_plan();
        p.eligibility.budget = LivePlanBudget {
            tokens: 1,
            ms: 0,
            usd: 0.0,
        };
        assert!(validate_plan(&p).is_ok());
    }

    #[test]
    fn non_zero_ms_alone_passes() {
        let mut p = ok_plan();
        p.eligibility.budget = LivePlanBudget {
            tokens: 0,
            ms: 1,
            usd: 0.0,
        };
        assert!(validate_plan(&p).is_ok());
    }

    #[test]
    fn non_zero_usd_alone_passes() {
        let mut p = ok_plan();
        p.eligibility.budget = LivePlanBudget {
            tokens: 0,
            ms: 0,
            usd: 0.01,
        };
        assert!(validate_plan(&p).is_ok());
    }

    #[test]
    fn expires_before_compiled_rejected() {
        let mut p = ok_plan();
        p.expires_at = Some("2026-05-01T00:00:00Z".into()); // before compiled_at 2026-05-16
        let err = validate_plan(&p).unwrap_err();
        assert!(matches!(err, LivePlanValidationError::ExpiresBeforeCompiled { .. }));
    }

    #[test]
    fn no_expires_at_passes() {
        let mut p = ok_plan();
        p.expires_at = None;
        assert!(validate_plan(&p).is_ok());
    }

    #[test]
    fn empty_expires_at_treated_as_none() {
        let mut p = ok_plan();
        p.expires_at = Some(String::new());
        assert!(validate_plan(&p).is_ok());
    }

    #[test]
    fn validator_short_circuits_on_first_error() {
        // Construct a plan with multiple errors; only the FIRST should
        // be returned. The check order in `validate_plan` is the
        // contract — empty_livefile_id wins.
        let mut p = ok_plan();
        p.livefile_id = String::new();
        p.source_uri = String::new();
        p.intent.summary = String::new();
        assert_eq!(validate_plan(&p).unwrap_err(), LivePlanValidationError::EmptyLivefileId);
    }

    // ── diagnostic surface (iter 147) ────────────────────────────────────────

    #[test]
    fn is_valid_plan_matches_validate_plan() {
        // Cross-surface invariant: is_valid_plan(p) iff validate_plan(p).is_ok().
        assert!(is_valid_plan(&ok_plan()));
        let mut bad = ok_plan();
        bad.livefile_id = String::new();
        assert!(!is_valid_plan(&bad));
        assert_eq!(is_valid_plan(&bad), validate_plan(&bad).is_ok());
    }

    #[test]
    fn field_returns_unique_identifier_per_variant() {
        // Cross-surface: each variant has a distinct field() identifier.
        let variants = [
            LivePlanValidationError::EmptyLivefileId,
            LivePlanValidationError::EmptySourceUri,
            LivePlanValidationError::EmptyPlanVersion,
            LivePlanValidationError::EmptyPlanHash,
            LivePlanValidationError::EmptyCompiledAt,
            LivePlanValidationError::EmptyIntentSummary,
            LivePlanValidationError::NoTriggers,
            LivePlanValidationError::ZeroBudget,
            LivePlanValidationError::ExpiresBeforeCompiled {
                compiled_at: "a".into(),
                expires_at: "b".into(),
            },
        ];
        let fields: std::collections::HashSet<_> = variants.iter().map(|v| v.field()).collect();
        assert_eq!(fields.len(), 9, "fields={:?}", fields);
    }

    #[test]
    fn classifier_predicates_partition_all_variants() {
        // Cross-surface invariant: exactly one of is_empty_field /
        // is_no_triggers / is_zero_budget / is_temporal is true for
        // every variant.
        let variants = [
            LivePlanValidationError::EmptyLivefileId,
            LivePlanValidationError::EmptySourceUri,
            LivePlanValidationError::EmptyPlanVersion,
            LivePlanValidationError::EmptyPlanHash,
            LivePlanValidationError::EmptyCompiledAt,
            LivePlanValidationError::EmptyIntentSummary,
            LivePlanValidationError::NoTriggers,
            LivePlanValidationError::ZeroBudget,
            LivePlanValidationError::ExpiresBeforeCompiled {
                compiled_at: "a".into(),
                expires_at: "b".into(),
            },
        ];
        for v in &variants {
            let quad = [
                v.is_empty_field(),
                v.is_no_triggers(),
                v.is_zero_budget(),
                v.is_temporal(),
            ];
            assert_eq!(quad.iter().filter(|t| **t).count(), 1, "{:?}", v);
        }
    }

    #[test]
    fn empty_field_classifier_covers_six_variants() {
        // The six "empty required string" variants.
        let empties = [
            LivePlanValidationError::EmptyLivefileId,
            LivePlanValidationError::EmptySourceUri,
            LivePlanValidationError::EmptyPlanVersion,
            LivePlanValidationError::EmptyPlanHash,
            LivePlanValidationError::EmptyCompiledAt,
            LivePlanValidationError::EmptyIntentSummary,
        ];
        for v in &empties {
            assert!(v.is_empty_field(), "expected is_empty_field for {:?}", v);
        }
    }

    #[test]
    fn error_from_real_validation_carries_correct_field() {
        // Cross-surface: validate_plan returns an error whose field()
        // identifies the actual offending fixture field.
        let mut p = ok_plan();
        p.plan_hash = String::new();
        let err = validate_plan(&p).unwrap_err();
        assert_eq!(err.field(), "plan_hash");
        assert!(err.is_empty_field());

        let mut p = ok_plan();
        p.eligibility.budget = LivePlanBudget { tokens: 0, ms: 0, usd: 0.0 };
        let err = validate_plan(&p).unwrap_err();
        assert_eq!(err.field(), "eligibility.budget");
        assert!(err.is_zero_budget());

        let mut p = ok_plan();
        p.expires_at = Some("2026-05-01T00:00:00Z".into());
        let err = validate_plan(&p).unwrap_err();
        assert_eq!(err.field(), "expires_at");
        assert!(err.is_temporal());
    }
}
