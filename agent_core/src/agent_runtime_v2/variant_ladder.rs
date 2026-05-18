//! Variant Ladder — per-tool dispatch ladder (cheap-deterministic →
//! heuristic → LLM-bound).
//!
//! Prior design: `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md`
//! §10. The Variant Ladder generalises the `list_notes → vault.search`
//! auto-route (commit `41be78202`) so every tool can advertise a
//! ladder of progressively-more-expensive resolution tiers.
//!
//! **Status (T11 iter-10): scaffold-only.** This module fixes the
//! type shape so executors and tools can advertise their ladder
//! configuration; the runtime dispatch logic (auto-promotion on
//! intent signal, escalation on low-confidence) lands in a later
//! iteration when the dispatcher is wired through `Para` /
//! `MissionPacket`.

use serde::{Deserialize, Serialize};

/// Tiers along the Variant Ladder for a given tool. Ordered from
/// cheapest to most expensive. The dispatcher tries `T1` first and
/// falls through on confidence below a threshold (defined later).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VariantTier {
    /// Path-list / direct-key lookup / pure-Rust deterministic.
    /// O(log n) or better; no model inference.
    T1Deterministic,
    /// Heuristic / inverted-index / BM25 / trigram. May call into
    /// `epistemos-shadow` but no LLM.
    T2Heuristic,
    /// LLM-bound relevance / re-ranking. Requires inference budget +
    /// macaroon capability check (so the v2 envelope path stays
    /// non-bypassable).
    T3LlmBound,
}

impl VariantTier {
    /// Stable string code for `RunEventLog` persistence.
    #[must_use]
    pub const fn code(self) -> &'static str {
        match self {
            Self::T1Deterministic => "t1_deterministic",
            Self::T2Heuristic => "t2_heuristic",
            Self::T3LlmBound => "t3_llm_bound",
        }
    }

    /// True for tiers that may consume a v2 `BudgetDebit::tokens` line
    /// item (i.e. tiers that drive a model). Used by the dispatcher to
    /// decide whether to push a debit through `BudgetGate` before
    /// invoking the tier.
    #[must_use]
    pub const fn debits_tokens(self) -> bool {
        matches!(self, Self::T3LlmBound)
    }

    /// Return the next-higher tier on the cost ladder, or `None` if
    /// this is already the highest. Used by the dispatcher's
    /// auto-promotion path when a lower tier returns low-confidence
    /// results.
    #[must_use]
    pub const fn next_higher(self) -> Option<VariantTier> {
        match self {
            Self::T1Deterministic => Some(Self::T2Heuristic),
            Self::T2Heuristic => Some(Self::T3LlmBound),
            Self::T3LlmBound => None,
        }
    }
}

/// Per-tool ladder configuration. Lives alongside the tool definition
/// so the dispatcher can read it without reflection.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VariantLadderSpec {
    /// Canonical tool name this ladder applies to (e.g. `vault.read`).
    pub tool_name: String,
    /// Tiers in ascending cost order. Must be non-empty; first tier is
    /// the default entry point.
    pub tiers: Vec<VariantTier>,
    /// True when the dispatcher may auto-promote `T1 → T2 → T3` on
    /// low-confidence return from a lower tier. False forces the
    /// caller to pick the tier explicitly.
    pub auto_promote: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VariantLadderError {
    EmptyTiers,
    NonAscendingTiers,
}

impl VariantLadderSpec {
    /// Return the default entry-point tier — the first element of
    /// `tiers`. Returns `None` if the ladder is empty (which
    /// `validate()` rejects, but the getter shouldn't panic).
    #[must_use]
    pub fn default_tier(&self) -> Option<VariantTier> {
        self.tiers.first().copied()
    }

    /// Validate that the ladder is non-empty and that tiers appear in
    /// ascending cost order (T1 < T2 < T3 per `VariantTier` ordering).
    pub fn validate(&self) -> Result<(), VariantLadderError> {
        if self.tiers.is_empty() {
            return Err(VariantLadderError::EmptyTiers);
        }
        let cost = |t: VariantTier| match t {
            VariantTier::T1Deterministic => 0u8,
            VariantTier::T2Heuristic => 1,
            VariantTier::T3LlmBound => 2,
        };
        let mut last = 0u8;
        for &t in &self.tiers {
            let c = cost(t);
            if c < last {
                return Err(VariantLadderError::NonAscendingTiers);
            }
            last = c;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tier_codes_are_stable() {
        assert_eq!(VariantTier::T1Deterministic.code(), "t1_deterministic");
        assert_eq!(VariantTier::T2Heuristic.code(), "t2_heuristic");
        assert_eq!(VariantTier::T3LlmBound.code(), "t3_llm_bound");
    }

    #[test]
    fn next_higher_walks_the_cost_ladder() {
        // Phase 1 hardening — pin the auto-promotion edges.
        assert_eq!(
            VariantTier::T1Deterministic.next_higher(),
            Some(VariantTier::T2Heuristic)
        );
        assert_eq!(
            VariantTier::T2Heuristic.next_higher(),
            Some(VariantTier::T3LlmBound)
        );
        assert_eq!(VariantTier::T3LlmBound.next_higher(), None);
    }

    #[test]
    fn llm_tier_debit_tokens_must_be_nonzero_when_routed_through_gate() {
        // Phase 1 hardening — cross-check between VariantLadder
        // and BudgetGate: when the dispatcher routes a tier whose
        // debits_tokens() == true, the corresponding BudgetDebit
        // it constructs MUST carry tokens > 0. Otherwise the gate
        // accepts a zero-cost LLM call which violates the budget
        // accounting contract. This integration-style test pins
        // the invariant for any future ladder-aware dispatcher.
        use crate::agent_runtime_v2::{BudgetDebit, BudgetGate, BudgetSpec};
        let tier = VariantTier::T3LlmBound;
        assert!(tier.debits_tokens());
        // Simulate the dispatcher's debit construction for an LLM
        // call: prompt + completion tokens.
        let debit = BudgetDebit::for_tool_call(100, 50);
        assert!(
            debit.tokens > 0,
            "tier {:?} requires tokens > 0 in the gate debit",
            tier
        );
        // And the gate accepts it under a generous cap.
        let gate = BudgetGate::new(BudgetSpec::new(1_000, 0, 5, 0));
        let advanced = gate
            .check_and_debit(Default::default(), debit)
            .expect("LLM-tier debit must pass gate");
        assert_eq!(advanced.tokens_used, 150);
        assert_eq!(advanced.tool_calls_used, 1);
    }

    #[test]
    fn non_llm_tiers_may_emit_zero_token_debits() {
        // Symmetric: T1/T2 tiers may legitimately produce a debit
        // with tokens == 0 (they're deterministic / heuristic, no
        // model inference). The gate accepts these.
        use crate::agent_runtime_v2::{BudgetDebit, BudgetGate, BudgetSpec};
        for tier in [VariantTier::T1Deterministic, VariantTier::T2Heuristic] {
            assert!(!tier.debits_tokens());
        }
        let debit = BudgetDebit {
            tokens: 0,
            tool_calls: 1,
            ..Default::default()
        };
        let gate = BudgetGate::new(BudgetSpec::new(0, 0, 5, 0));
        gate.check_and_debit(Default::default(), debit)
            .expect("zero-token debit must pass when only tool_calls is capped");
    }

    #[test]
    fn only_llm_tier_debits_tokens() {
        assert!(!VariantTier::T1Deterministic.debits_tokens());
        assert!(!VariantTier::T2Heuristic.debits_tokens());
        assert!(VariantTier::T3LlmBound.debits_tokens());
    }

    #[test]
    fn default_tier_returns_first_element() {
        let multi = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![
                VariantTier::T1Deterministic,
                VariantTier::T2Heuristic,
                VariantTier::T3LlmBound,
            ],
            auto_promote: true,
        };
        assert_eq!(multi.default_tier(), Some(VariantTier::T1Deterministic));
        let single = VariantLadderSpec {
            tool_name: "x".into(),
            tiers: vec![VariantTier::T2Heuristic],
            auto_promote: false,
        };
        assert_eq!(single.default_tier(), Some(VariantTier::T2Heuristic));
        // Empty ladder gracefully returns None (no panic).
        let empty = VariantLadderSpec {
            tool_name: "x".into(),
            tiers: vec![],
            auto_promote: false,
        };
        assert_eq!(empty.default_tier(), None);
    }

    #[test]
    fn ladder_with_ascending_tiers_validates() {
        let spec = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![
                VariantTier::T1Deterministic,
                VariantTier::T2Heuristic,
                VariantTier::T3LlmBound,
            ],
            auto_promote: true,
        };
        spec.validate().expect("ascending ladder valid");
    }

    #[test]
    fn ladder_with_t1_only_validates() {
        let spec = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![VariantTier::T1Deterministic],
            auto_promote: false,
        };
        spec.validate().expect("single-tier ladder valid");
    }

    #[test]
    fn empty_ladder_rejected() {
        let spec = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![],
            auto_promote: false,
        };
        assert_eq!(spec.validate(), Err(VariantLadderError::EmptyTiers));
    }

    #[test]
    fn non_ascending_ladder_rejected() {
        let spec = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![VariantTier::T3LlmBound, VariantTier::T1Deterministic],
            auto_promote: true,
        };
        assert_eq!(
            spec.validate(),
            Err(VariantLadderError::NonAscendingTiers)
        );
    }

    #[test]
    fn ladder_round_trips_through_json() {
        let spec = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![VariantTier::T1Deterministic, VariantTier::T2Heuristic],
            auto_promote: true,
        };
        let s = serde_json::to_string(&spec).expect("serialize");
        let back: VariantLadderSpec = serde_json::from_str(&s).expect("deserialize");
        assert_eq!(back, spec);
    }
}
