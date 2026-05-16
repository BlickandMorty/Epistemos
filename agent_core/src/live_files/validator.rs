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
}
