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

    /// Display-friendly tier name for log lines / UI labels. Distinct
    /// from `code()` which is the snake_case persistence string —
    /// this is the PascalCase form a user might see in a debug
    /// dashboard.
    #[must_use]
    pub const fn display_name(self) -> &'static str {
        match self {
            Self::T1Deterministic => "T1Deterministic",
            Self::T2Heuristic => "T2Heuristic",
            Self::T3LlmBound => "T3LlmBound",
        }
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

impl std::fmt::Display for VariantTier {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.display_name())
    }
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
    fn variant_tier_helpers_are_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — runtime determinism pin (companion to
        // iter-103 const-fn compile pin). code / debits_tokens /
        // display_name / next_higher are all pure matches; calling
        // them many times must produce identical results.
        for tier in [
            VariantTier::T1Deterministic,
            VariantTier::T2Heuristic,
            VariantTier::T3LlmBound,
        ] {
            for _ in 0..3 {
                assert_eq!(tier.code(), tier.code());
                assert_eq!(tier.debits_tokens(), tier.debits_tokens());
                assert_eq!(tier.display_name(), tier.display_name());
                assert_eq!(tier.next_higher(), tier.next_higher());
            }
        }
    }

    #[test]
    fn variant_tier_const_fn_annotations_compile_in_const_context() {
        // Phase 1 hardening — compile-time pin for the const fn
        // annotations on VariantTier (companion to iter-100 through
        // iter-102 const-context pins). A future refactor that
        // dropped `const` from any of these signatures surfaces as
        // a compile failure here.
        //
        // Pinned signatures: VariantTier::{code, debits_tokens,
        // display_name, next_higher}.
        const T1_CODE: &str = VariantTier::T1Deterministic.code();
        const T2_CODE: &str = VariantTier::T2Heuristic.code();
        const T3_CODE: &str = VariantTier::T3LlmBound.code();
        const T1_DEBITS: bool = VariantTier::T1Deterministic.debits_tokens();
        const T3_DEBITS: bool = VariantTier::T3LlmBound.debits_tokens();
        const T1_DISPLAY: &str = VariantTier::T1Deterministic.display_name();
        const T3_DISPLAY: &str = VariantTier::T3LlmBound.display_name();
        const T1_NEXT: Option<VariantTier> = VariantTier::T1Deterministic.next_higher();
        const T2_NEXT: Option<VariantTier> = VariantTier::T2Heuristic.next_higher();
        const T3_NEXT: Option<VariantTier> = VariantTier::T3LlmBound.next_higher();

        // Runtime asserts keep the const items live.
        assert_eq!(T1_CODE, "t1_deterministic");
        assert_eq!(T2_CODE, "t2_heuristic");
        assert_eq!(T3_CODE, "t3_llm_bound");
        assert!(!T1_DEBITS);
        assert!(T3_DEBITS);
        assert_eq!(T1_DISPLAY, "T1Deterministic");
        assert_eq!(T3_DISPLAY, "T3LlmBound");
        assert_eq!(T1_NEXT, Some(VariantTier::T2Heuristic));
        assert_eq!(T2_NEXT, Some(VariantTier::T3LlmBound));
        assert_eq!(T3_NEXT, None);
    }

    #[test]
    fn variant_tier_variant_count_is_three() {
        // Phase 1 hardening — cardinality pin continuing the
        // count-pin series (BudgetTerm 5, AgentEventErrorKind 4
        // iter-139, AgentRuntimeV2Mode 3 iter-140, CliAdapter 6
        // iter-141). VariantTier has 3 variants (T1Deterministic,
        // T2Heuristic, T3LlmBound) — the dispatch cost ladder.
        // A future addition (e.g., T0Cached, T4MultiModel) would
        // need:
        //   - debits_tokens() / required_mode() update
        //   - next_higher() chain update
        //   - serde discriminator + negative-serde pin update
        //   - dispatcher's auto-promotion logic update
        // Pin cardinality + pairwise distinctness so the addition
        // surfaces at PR review across all sites.
        let variants = [
            VariantTier::T1Deterministic,
            VariantTier::T2Heuristic,
            VariantTier::T3LlmBound,
        ];
        assert_eq!(variants.len(), 3);
        for i in 0..variants.len() {
            for j in (i + 1)..variants.len() {
                assert_ne!(
                    variants[i], variants[j],
                    "tiers[{i}] and tiers[{j}] must be distinct"
                );
            }
        }
    }

    #[test]
    fn tier_codes_are_stable() {
        assert_eq!(VariantTier::T1Deterministic.code(), "t1_deterministic");
        assert_eq!(VariantTier::T2Heuristic.code(), "t2_heuristic");
        assert_eq!(VariantTier::T3LlmBound.code(), "t3_llm_bound");
    }

    #[test]
    fn variant_tier_all_three_codes_are_distinct_and_lowercase_snake_case() {
        // Phase 1 hardening — symmetric companion to
        // budget_term_all_five_codes_are_distinct_and_lowercase_snake_case
        // and agent_event_error_kind_all_four_codes_are_distinct... (iter-362).
        // VariantTier has 3 variants with code() returning the canonical
        // snake_case persistence key.
        //
        // All 3 must be:
        //   - pairwise distinct (collisions silently merge audit counters)
        //   - lowercase snake_case (only [a-z0-9_], non-empty — note the
        //     0-9 is allowed because codes are "t1_deterministic" etc.)
        //
        // Defends against a future rename that, e.g., dropped the
        // numeric prefix or hyphenated ("t1-deterministic") — would
        // silently break audit pipelines keyed on the t1/t2/t3 lookup.
        let codes = [
            VariantTier::T1Deterministic.code(),
            VariantTier::T2Heuristic.code(),
            VariantTier::T3LlmBound.code(),
        ];
        // Pairwise distinct.
        for i in 0..codes.len() {
            for j in (i + 1)..codes.len() {
                assert_ne!(codes[i], codes[j], "codes[{i}] == codes[{j}]");
            }
        }
        // Snake_case lowercase rule: only [a-z0-9_].
        for c in codes {
            assert!(
                c.chars()
                    .all(|ch| ch.is_ascii_lowercase() || ch.is_ascii_digit() || ch == '_'),
                "code {c:?} must be lowercase snake_case (with digits allowed)"
            );
            assert!(!c.is_empty(), "code must be non-empty");
        }
    }

    #[test]
    fn variant_tier_display_uses_pascal_case_distinct_from_code() {
        // Phase 1 hardening — display_name is the human-facing
        // PascalCase form; code() is the snake_case persistence
        // string. They MUST stay distinct so log dashboards and
        // RunEventLog rows can't collide.
        assert_eq!(format!("{}", VariantTier::T1Deterministic), "T1Deterministic");
        assert_eq!(format!("{}", VariantTier::T2Heuristic), "T2Heuristic");
        assert_eq!(format!("{}", VariantTier::T3LlmBound), "T3LlmBound");
        // Distinctness invariant — display_name and code() must
        // never collide.
        for tier in [
            VariantTier::T1Deterministic,
            VariantTier::T2Heuristic,
            VariantTier::T3LlmBound,
        ] {
            assert_ne!(tier.display_name(), tier.code());
        }
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
    fn variant_ladder_spec_default_tier_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — runtime determinism pin (companion to
        // the purity series). default_tier returns
        // tiers.first().copied(); pure over immutable &self.
        let spec = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![VariantTier::T1Deterministic, VariantTier::T3LlmBound],
            auto_promote: false,
        };
        for _ in 0..3 {
            assert_eq!(spec.default_tier(), spec.default_tier());
        }
        assert_eq!(spec.default_tier(), Some(VariantTier::T1Deterministic));
        // Empty case is also deterministic.
        let empty = VariantLadderSpec {
            tool_name: "x".into(),
            tiers: vec![],
            auto_promote: false,
        };
        for _ in 0..3 {
            assert_eq!(empty.default_tier(), None);
        }
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
    fn ladder_validate_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series iter-220-231). validate
        // walks self.tiers, comparing each to the previous cost.
        // Pure function over immutable data.
        let ok = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![VariantTier::T1Deterministic, VariantTier::T2Heuristic],
            auto_promote: true,
        };
        let r1 = ok.validate();
        let r2 = ok.validate();
        let r3 = ok.validate();
        assert_eq!(r1, r2);
        assert_eq!(r2, r3);
        assert!(r1.is_ok());

        // Rejection path: empty tiers.
        let bad = VariantLadderSpec {
            tool_name: "x".into(),
            tiers: vec![],
            auto_promote: false,
        };
        let e1 = bad.validate();
        let e2 = bad.validate();
        assert_eq!(e1, e2);
        assert_eq!(e1, Err(VariantLadderError::EmptyTiers));
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
    fn ladder_with_skipped_tiers_validates_per_ascending_only_doctrine() {
        // Phase 1 hardening — doctrine pin. The validator enforces
        // "ascending cost" (T1 < T2 < T3) but does NOT require dense
        // coverage (every adjacent tier must appear). A ladder may
        // legitimately SKIP tiers when a tool has no implementation
        // at an intermediate level:
        //
        //   [T1, T3]      — deterministic + LLM, no heuristic middle
        //   [T2, T3]      — no deterministic shortcut, heuristic + LLM
        //   [T3]          — LLM-only tool (already pinned by ladder_with_t1_only)
        //
        // Existing pins cover [T1], [T1,T2,T3], and reject [T3,T1] +
        // [T1,T3,T2]. The sparse-ascending cases above are unpinned.
        // A future "let me require T1 to always appear first" rule
        // would silently break tools that have no deterministic
        // shortcut.
        for tiers in [
            vec![VariantTier::T1Deterministic, VariantTier::T3LlmBound],
            vec![VariantTier::T2Heuristic, VariantTier::T3LlmBound],
            vec![VariantTier::T1Deterministic, VariantTier::T2Heuristic], // no T3
        ] {
            let spec = VariantLadderSpec {
                tool_name: format!("vault.tool-{}", tiers.len()),
                tiers: tiers.clone(),
                auto_promote: false,
            };
            spec.validate().unwrap_or_else(|e| {
                panic!("sparse-ascending ladder {tiers:?} must validate: {e:?}")
            });
            // default_tier surfaces the first entry — proves the
            // ladder is usable for dispatch even when tiers are sparse.
            assert_eq!(spec.default_tier(), Some(tiers[0]));
        }
    }

    #[test]
    fn variant_ladder_spec_is_clone_send_sync_but_not_copy() {
        // Phase 1 hardening — trait-bound pin for the
        // String + Vec<VariantTier> bearing struct. Companion to the
        // Clone + Send + Sync (not Copy) pin family (AgentBlueprintId
        // iter-375 → AnswerPacket + Citation iter-377 → AgentBlueprint
        // + ProviderPolicy iter-378 → LocalAgentCapability iter-379).
        //
        // VariantLadderSpec: 3 fields (tool_name: String + tiers: Vec
        // + auto_promote: bool). Clone by derive but NOT Copy
        // (String + Vec both allocate).
        //
        // Send + Sync are load-bearing — VariantLadderSpec rides
        // inside per-tool configuration that the dispatcher reads
        // across thread boundaries during ladder dispatch.
        fn assert_clone_send_sync<T: Clone + Send + Sync>() {}
        assert_clone_send_sync::<VariantLadderSpec>();

        let spec = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![VariantTier::T1Deterministic, VariantTier::T3LlmBound],
            auto_promote: true,
        };
        assert_eq!(spec.clone(), spec);
    }

    #[test]
    fn variant_tier_is_copy_clone_send_sync_for_propagation_safety() {
        // Phase 1 hardening — trait-bound pin (companion to
        // budget_gate, mode (iter-366), StopReason (iter-367)).
        // VariantTier is a 3-variant unit enum marked Copy via derive
        // (variant_ladder.rs §21). No interior mutability, no heap,
        // no Drop.
        //
        // The Copy + Clone + Send + Sync bounds are load-bearing for:
        //   - Dispatcher hot-path: the variant-ladder dispatcher copies
        //     tier values to switch executor branches without owning
        //     the spec.
        //   - VariantLadderSpec::tiers: Vec<VariantTier> requires Copy
        //     to support the cost-ladder walk + retry-on-failure
        //     promotion path.
        //   - HashMap dispatch caches (iter-328 already pins HashMap
        //     usability).
        //
        // A future "let me make VariantTier carry an Option<f64>
        // confidence threshold" refactor that introduced a non-Copy
        // field would silently break the freely-copied-through-the-
        // dispatcher assumption — surface here.
        fn assert_copy_clone_send_sync<T: Copy + Clone + Send + Sync>() {}
        assert_copy_clone_send_sync::<VariantTier>();

        // Runtime sanity: copy + use both bindings.
        let t = VariantTier::T3LlmBound;
        let copy_a = t;
        let copy_b = t;
        assert_eq!(copy_a, copy_b);
        assert_eq!(copy_a, t);
    }

    #[test]
    fn variant_tier_hash_consistent_with_eq_usable_as_hashmap_key() {
        // Phase 1 hardening — Hash-derive consistency pin (companion
        // to mode iter-321 + stop_reason iter-326 + LocalAgent
        // Tier/Owner/Surface iter-327). VariantTier carries Hash in
        // its derive list (variant_ladder.rs line 21).
        //
        // Pin that the 3 variants are usable as HashMap keys, equal
        // tiers hash to the same bucket, distinct tiers occupy
        // distinct slots. This is load-bearing for the future
        // dispatcher confidence-cache that may key by VariantTier.
        //
        // Defends against a future "let me drop Hash to simplify the
        // VariantTier derive" refactor that would break per-tier
        // metric aggregators a dispatch path would build.
        use std::collections::{HashMap, HashSet};

        let all = [
            VariantTier::T1Deterministic,
            VariantTier::T2Heuristic,
            VariantTier::T3LlmBound,
        ];
        // HashSet of all 3 → 3 distinct slots.
        let set: HashSet<VariantTier> = all.iter().copied().collect();
        assert_eq!(set.len(), 3, "all 3 tiers must occupy distinct hash slots");
        // Duplicate insert no-op.
        let mut dup = HashSet::new();
        dup.insert(VariantTier::T1Deterministic);
        dup.insert(VariantTier::T1Deterministic);
        dup.insert(VariantTier::T2Heuristic);
        assert_eq!(dup.len(), 2);

        // HashMap with VariantTier keys.
        let mut map: HashMap<VariantTier, &'static str> = HashMap::new();
        for &t in &all {
            map.insert(t, t.code());
        }
        assert_eq!(map.len(), 3);
        for &t in &all {
            assert_eq!(map.get(&t), Some(&t.code()));
        }
    }

    #[test]
    fn ladder_with_t3_only_validates_and_defaults_to_t3_per_token_debit_doctrine() {
        // Phase 1 hardening MILESTONE iter-430 — completeness companion
        // to ladder_with_t1_only_validates. A single-tier ladder with
        // ONLY T3LlmBound is valid (3 single-tier ladders × 3 tiers =
        // 9 combinations; T1, T2, T3 each). T3 is the only token-debiting
        // tier — a tool with NO deterministic / heuristic shortcut goes
        // straight to LLM.
        //
        // Doctrine-pin extension: default_tier == Some(T3LlmBound),
        // and debits_tokens() == true for the default tier (proves
        // T3-only ladders are correctly classified as token-debiting
        // by the dispatcher).
        //
        // Closes the 3-axis single-tier ladder coverage:
        //   - [T1]: iter-? ladder_with_t1_only_validates
        //   - [T2]: iter-? sparse-ladder pin includes [T2,T3] but no [T2]-only
        //   - [T3]: this commit (T3-only single-tier)
        let spec = VariantLadderSpec {
            tool_name: "vault.semantic_search".into(),
            tiers: vec![VariantTier::T3LlmBound],
            auto_promote: false,
        };
        spec.validate().expect("single-T3 ladder valid");
        assert_eq!(spec.default_tier(), Some(VariantTier::T3LlmBound));
        assert!(
            spec.default_tier().unwrap().debits_tokens(),
            "T3-only default must be token-debiting"
        );

        // Also pin T2-only single-tier ladder.
        let spec_t2 = VariantLadderSpec {
            tool_name: "vault.bm25".into(),
            tiers: vec![VariantTier::T2Heuristic],
            auto_promote: false,
        };
        spec_t2.validate().expect("single-T2 ladder valid");
        assert_eq!(spec_t2.default_tier(), Some(VariantTier::T2Heuristic));
        assert!(
            !spec_t2.default_tier().unwrap().debits_tokens(),
            "T2-only default must NOT be token-debiting"
        );
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
    fn variant_ladder_error_is_copy_clone_send_sync_for_propagation_safety() {
        // Phase 1 hardening — trait-bound pin (companion to the
        // Copy + Clone + Send + Sync sweep started at budget_gate and
        // extended through mode iter-366 / StopReason iter-367 /
        // VariantTier iter-368 / LocalAgent enums iter-369 / budget
        // closed-taxonomy iter-370 / CliAdapter + BlueprintModeError
        // iter-371 / LogValidationError iter-372).
        //
        // VariantLadderError: 2-variant unit enum marked Copy via
        // derive (variant_ladder.rs §98). Returned by
        // VariantLadderSpec::validate; Copy lets dispatcher startup +
        // CI gates propagate the error without owning.
        //
        // A future addition like DuplicateTiers(Vec<VariantTier>)
        // would break Copy — surface here.
        fn assert_copy_clone_send_sync<T: Copy + Clone + Send + Sync>() {}
        assert_copy_clone_send_sync::<VariantLadderError>();

        // Runtime sanity for both variants.
        let e1 = VariantLadderError::EmptyTiers;
        let _a = e1; let _b = e1; assert_eq!(e1, e1);
        let e2 = VariantLadderError::NonAscendingTiers;
        let _a = e2; let _b = e2; assert_eq!(e2, e2);
    }

    #[test]
    fn variant_ladder_error_variants_field_shapes_pinned_via_destructure() {
        // Phase 1 hardening — field-shape pin for VariantLadderError's
        // 2 unit variants (companion to the destructure pin family
        // iter-454..iter-460).
        //
        // Variants: EmptyTiers, NonAscendingTiers (both unit).
        //
        // A future "let me add a context payload like {EmptyTiers,
        // tool_name}" would silently break the unit-variant assumption.
        let cases = [
            VariantLadderError::EmptyTiers,
            VariantLadderError::NonAscendingTiers,
        ];
        for case in cases {
            match case {
                VariantLadderError::EmptyTiers
                | VariantLadderError::NonAscendingTiers => {}
            }
        }
    }

    #[test]
    fn variant_ladder_error_variant_count_is_two() {
        // Phase 1 hardening — cardinality pin. VariantLadderError
        // has 2 variants (EmptyTiers, NonAscendingTiers) covering
        // the two ladder-validation rejections.
        //
        // A future addition (e.g., DuplicateTiers if strict-
        // ascending validation tightens, per the doctrine note in
        // ladder_validate_accepts_duplicate_adjacent_tiers test)
        // requires Debug-repr pin update + validate() branch update.
        let variants = [
            VariantLadderError::EmptyTiers,
            VariantLadderError::NonAscendingTiers,
        ];
        assert_eq!(variants.len(), 2);
        assert_ne!(variants[0], variants[1]);
    }

    #[test]
    fn variant_ladder_error_debug_repr_is_stable_for_audit_persistence() {
        // Phase 1 hardening — audit-log surface. VariantLadderError
        // is the only failure mode of VariantLadderSpec::validate();
        // its Debug repr lands in incident reports + CI failure
        // output. Companion pin to:
        //   - budget_error_exhausted_debug_repr_is_stable
        //   - log_validation_error_ordinal_mismatch_debug_repr_is_stable
        //   - tool_call_error_debug_repr_is_stable
        //   - mission_prompt_error_oversize_debug_repr_is_stable
        //   - para_error_debug_repr_is_stable
        //
        // A maintainer rename (EmptyTiers → Empty, NonAscendingTiers
        // → OutOfOrder, etc.) would silently change the printed form
        // and break grep-based audit dashboards. Pin both variants
        // exactly.
        assert_eq!(format!("{:?}", VariantLadderError::EmptyTiers), "EmptyTiers");
        assert_eq!(
            format!("{:?}", VariantLadderError::NonAscendingTiers),
            "NonAscendingTiers"
        );
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
    fn non_ascending_ladder_with_mid_ladder_descent_rejected() {
        // Phase 1 hardening — boundary completeness. The existing
        // non_ascending_ladder_rejected covers a strictly-descending
        // pair [T3, T1]. The mid-ladder descent case [T1, T3, T2]
        // (ascends then descends) was unpinned. A future refactor
        // that only checked the FIRST descent (e.g., a buggy
        // partial check) would silently let this through.
        let spec = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![
                VariantTier::T1Deterministic,
                VariantTier::T3LlmBound,
                VariantTier::T2Heuristic, // descent vs T3
            ],
            auto_promote: true,
        };
        assert_eq!(
            spec.validate(),
            Err(VariantLadderError::NonAscendingTiers),
            "mid-ladder descent must reject"
        );
        // Even one trailing descent at the tail is rejected.
        let trailing = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![
                VariantTier::T1Deterministic,
                VariantTier::T2Heuristic,
                VariantTier::T3LlmBound,
                VariantTier::T2Heuristic, // descent vs T3
            ],
            auto_promote: true,
        };
        assert_eq!(
            trailing.validate(),
            Err(VariantLadderError::NonAscendingTiers)
        );
    }

    #[test]
    fn ladder_validate_accepts_duplicate_adjacent_tiers_under_non_strict_ascending_rule() {
        // Phase 1 hardening — pin current "non-strict ascending"
        // semantics. validate uses `c < last` (not `c <= last`),
        // so a ladder with adjacent equal tiers (T1, T1, T2) is
        // accepted. This is intentional: a tool author may want
        // multiple T1 variants per tier (e.g., two distinct
        // deterministic implementations to A/B test). If a future
        // iter switches to strict ascending (rejecting duplicates),
        // this test surfaces the behaviour change at PR review
        // rather than silently breaking ladder configs already in
        // the field.
        let spec = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![
                VariantTier::T1Deterministic,
                VariantTier::T1Deterministic,
                VariantTier::T2Heuristic,
                VariantTier::T2Heuristic,
                VariantTier::T3LlmBound,
            ],
            auto_promote: true,
        };
        spec.validate()
            .expect("duplicates with non-strict-ascending current behavior");
    }

    #[test]
    fn variant_tier_serde_forms_are_pairwise_distinct_across_all_three_variants() {
        // Phase 1 hardening — pairwise-distinct serde-form pin for
        // VariantTier (extends the serde-pairwise-distinct guardrail
        // family closed at iter-542 to also cover the variant-ladder
        // enum). VariantTier has 3 snake_case variants
        // (t1_deterministic, t2_heuristic, t3_llm_bound) persisted into
        // VariantLadderSpec rows. A 4th variant added with
        // #[serde(rename = "t3_llm_bound")] would silently collide and
        // misroute ladder-tier decisions on replay — a dispatcher
        // could pick the wrong tier (and thus wrong cost class) for a
        // tool. Pin asserts all 3 serialized forms are
        // pairwise-distinct.
        let variants = [
            VariantTier::T1Deterministic,
            VariantTier::T2Heuristic,
            VariantTier::T3LlmBound,
        ];
        let serde_forms: Vec<String> = variants
            .iter()
            .map(|v| serde_json::to_string(v).expect("serialize"))
            .collect();
        for i in 0..serde_forms.len() {
            for j in (i + 1)..serde_forms.len() {
                assert_ne!(
                    serde_forms[i], serde_forms[j],
                    "VariantTier serde forms collide at [{i}] = {:?} and [{j}] = {:?}",
                    serde_forms[i], serde_forms[j]
                );
            }
        }
    }

    #[test]
    fn variant_tier_code_matches_serde_tag_byte_for_byte() {
        // Phase 1 hardening — cross-consistency pin between
        // VariantTier::code() (returns &'static str) and the
        // #[serde(rename_all = "snake_case")] tag. Two existing pin
        // families lock each separately:
        //   - tier_codes_are_stable (per-variant code())
        //   - variant_tier_serde_values_are_stable (per-variant serde)
        // BUT neither pin asserts the two stay aligned. A future
        // refactor that switched `rename_all` to `camelCase` would
        // silently break the alignment without flagging the code()
        // helper, and the FFI bridge that consumes either surface
        // would silently miswire. Pin asserts the two helpers agree
        // for all 3 variants.
        for tier in [
            VariantTier::T1Deterministic,
            VariantTier::T2Heuristic,
            VariantTier::T3LlmBound,
        ] {
            let serde_form = serde_json::to_string(&tier).expect("serialize");
            let expected = format!("\"{}\"", tier.code());
            assert_eq!(
                serde_form, expected,
                "tier {tier:?}: code() {:?} must byte-equal serde tag {serde_form:?}",
                tier.code()
            );
        }
    }

    #[test]
    fn variant_tier_serde_values_are_stable() {
        // Phase 1 hardening — cross-version replay parity guardrail.
        // VariantTier carries #[serde(rename_all = "snake_case")];
        // every variant string is load-bearing for replay of older
        // VariantLadderSpec JSONs.
        //
        // Companion to:
        //   - mode_serde_discriminator_values_are_stable (3 modes)
        //   - agent_event_error_kind_serde_values_are_stable (4 kinds)
        //   - cli_adapter_serde_snake_case_pins_all_six_adapter_strings (6)
        //   - agent_event_serde_tag_values_are_stable (6 event types)
        //   - stop_reason_serde_values_are_stable (7 stop reasons)
        for (variant, expected) in [
            (VariantTier::T1Deterministic, "\"t1_deterministic\""),
            (VariantTier::T2Heuristic, "\"t2_heuristic\""),
            (VariantTier::T3LlmBound, "\"t3_llm_bound\""),
        ] {
            let s = serde_json::to_string(&variant).expect("serialise");
            assert_eq!(s, expected, "variant_tier {variant:?} drifted serde form");
            let back: VariantTier = serde_json::from_str(&s).expect("round-trip");
            assert_eq!(back, variant);
        }
    }

    #[test]
    fn variant_tier_unknown_serde_string_fails_to_deserialise() {
        // Phase 1 hardening — fifth leg of the closed-taxonomy
        // guardrail (mode iter-71, AgentEvent event_type iter-73,
        // StopReason iter-74, AgentEventErrorKind iter-75). VariantTier
        // is persisted inside VariantLadderSpec rows that ride into
        // RunEventLog when a tool registration captures its dispatch
        // ladder. A future #[serde(other)] catch-all or case shim
        // would silently route stray strings to a default tier
        // (most dangerously to the cheapest tier, masking budget
        // accounting drift).
        for bad in [
            // Unknown vocabulary (adjacent dispatch terms)
            "\"deterministic\"",
            "\"heuristic\"",
            "\"llm\"",
            "\"t4_quantum\"",
            "\"t0_skipped\"",
            // Case variants of valid strings
            "\"T1Deterministic\"",
            "\"T1_DETERMINISTIC\"",
            "\"T1_deterministic\"",
            "\"t1Deterministic\"",
            // Kebab-case drift
            "\"t1-deterministic\"",
            "\"t2-heuristic\"",
            "\"t3-llm-bound\"",
            // Empty
            "\"\"",
        ] {
            let r: Result<VariantTier, _> = serde_json::from_str(bad);
            assert!(
                r.is_err(),
                "unknown VariantTier string {bad} must fail to deserialise"
            );
        }
        // Sanity: every valid variant still round-trips byte-equal.
        for (variant, expected) in [
            (VariantTier::T1Deterministic, "\"t1_deterministic\""),
            (VariantTier::T2Heuristic, "\"t2_heuristic\""),
            (VariantTier::T3LlmBound, "\"t3_llm_bound\""),
        ] {
            let s = serde_json::to_string(&variant).unwrap();
            assert_eq!(s, expected, "variant {variant:?} drifted serde form");
            let back: VariantTier = serde_json::from_str(&s).unwrap();
            assert_eq!(back, variant);
        }
    }

    #[test]
    fn variant_ladder_spec_fields_are_pub_per_field_visibility_doctrine() {
        // Phase 1 hardening — field-visibility pin for
        // VariantLadderSpec (companion to the field-visibility pin
        // family iter-505..iter-511).
        //
        // 3 pub fields: tool_name, tiers, auto_promote.
        let spec = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![VariantTier::T1Deterministic],
            auto_promote: true,
        };
        // Direct field reads on all 3 fields.
        assert_eq!(spec.tool_name, "vault.read");
        assert_eq!(spec.tiers.len(), 1);
        assert!(spec.auto_promote);
    }

    #[test]
    fn variant_ladder_spec_struct_field_shape_pinned_to_exactly_three_typed_fields() {
        // Phase 1 hardening — struct-field-shape pin for
        // VariantLadderSpec (companion to the struct destructure pin
        // family iter-464..iter-468).
        //
        // VariantLadderSpec: EXACTLY 3 fields
        //   - tool_name: String
        //   - tiers: Vec<VariantTier>
        //   - auto_promote: bool
        //
        // A future "let me add a `confidence_threshold: f64`" extension
        // would silently change the on-disk JSON shape.
        let spec = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![VariantTier::T1Deterministic],
            auto_promote: false,
        };
        let VariantLadderSpec {
            tool_name,
            tiers,
            auto_promote,
        } = spec;
        let _: String = tool_name;
        let _: Vec<VariantTier> = tiers;
        let _: bool = auto_promote;
    }

    #[test]
    fn every_variant_ladder_spec_field_is_identity_load_bearing() {
        // Phase 1 hardening — eighth leg of the identity-pin pattern
        // (AgentBlueprint 5, AnswerPacket 7, MissionPacket 3,
        // ToolCall 2, MutationEnvelope 3, LocalAgentCapability 10,
        // ParaOutput 5, VariantLadderSpec 3 here). The 3 fields are
        // tool_name, tiers, auto_promote. A silent #[serde(skip)]
        // or PartialEq override dropping any field would let
        // distinct ladder configs collapse — the dispatcher
        // would think two tools with different auto-promote
        // policies are the same.
        let base = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![VariantTier::T1Deterministic, VariantTier::T2Heuristic],
            auto_promote: true,
        };

        let mut diff_name = base.clone();
        diff_name.tool_name = "vault.write".into();
        assert_ne!(diff_name, base, "tool_name must participate in PartialEq");

        let mut diff_tiers = base.clone();
        diff_tiers.tiers.push(VariantTier::T3LlmBound);
        assert_ne!(diff_tiers, base, "tiers must participate in PartialEq");

        let mut diff_promote = base.clone();
        diff_promote.auto_promote = false;
        assert_ne!(diff_promote, base, "auto_promote must participate in PartialEq");

        // Sanity preserved.
        assert_eq!(base.clone(), base);
    }

    #[test]
    fn variant_ladder_spec_serde_json_preserves_struct_field_declaration_order() {
        // Phase 1 hardening — wire-shape pin extending iter-161
        // (presence + count) with field-order. VariantLadderSpec
        // declares: tool_name, tiers, auto_promote. A future
        // reorder breaks dispatcher tool-registry byte-equal
        // cache keys.
        let spec = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![VariantTier::T1Deterministic],
            auto_promote: true,
        };
        let s = serde_json::to_string(&spec).expect("serialise");
        let expected_keys_in_order = [
            "\"tool_name\":",
            "\"tiers\":",
            "\"auto_promote\":",
        ];
        let mut last_idx: Option<usize> = None;
        for key in expected_keys_in_order {
            let pos = s.find(key).unwrap_or_else(|| panic!("key {key} not found in {s}"));
            if let Some(prev) = last_idx {
                assert!(
                    pos > prev,
                    "field {key} at byte {pos} must appear after previous field at {prev}"
                );
            }
            last_idx = Some(pos);
        }
    }

    #[test]
    fn variant_ladder_spec_serde_json_contains_all_three_canonical_top_level_keys() {
        // Phase 1 hardening — wire-shape pin matching the established
        // pattern. VariantLadderSpec has 3 top-level fields
        // (tool_name, tiers, auto_promote); a silent rename would
        // round-trip but break dispatcher tool-registry readers
        // that look up ladder configs by field name.
        let spec = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![VariantTier::T1Deterministic],
            auto_promote: true,
        };
        let json = serde_json::to_value(&spec).expect("serialise");
        let obj = json.as_object().expect("VariantLadderSpec serialises as JSON object");
        for key in ["tool_name", "tiers", "auto_promote"] {
            assert!(
                obj.contains_key(key),
                "missing top-level key {key:?} in {json:?}"
            );
        }
        assert_eq!(
            obj.len(),
            3,
            "expected exactly 3 top-level keys, got {} ({:?})",
            obj.len(),
            obj.keys().collect::<Vec<_>>()
        );
    }

    #[test]
    fn variant_ladder_spec_missing_required_fields_fail_to_deserialise() {
        let spec = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![VariantTier::T1Deterministic],
            auto_promote: true,
        };
        let value = serde_json::to_value(&spec).expect("serialise");
        let obj = value.as_object().expect("VariantLadderSpec object");
        for missing in ["tool_name", "tiers", "auto_promote"] {
            let mut tampered = obj.clone();
            tampered.remove(missing);
            let parsed: Result<VariantLadderSpec, _> =
                serde_json::from_value(serde_json::Value::Object(tampered));
            assert!(
                parsed.is_err(),
                "VariantLadderSpec missing required field {missing:?} must fail"
            );
        }
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

    #[test]
    fn variant_ladder_spec_tool_name_preserves_json_special_chars_through_serde() {
        // Phase 1 hardening — adversarial JSON pin for
        // VariantLadderSpec.tool_name (companion to the iter-413..
        // iter-420 JSON-special-char pin family).
        //
        // tool_name is the canonical tool identifier (e.g.,
        // "vault.read"). While ToolCall.name has strict validation
        // (alnum + . _ -), VariantLadderSpec.tool_name does NOT have
        // a validate() function — it's just a String. Serde must
        // preserve JSON-special chars through round-trip in case a
        // future external configuration source provides one.
        //
        // A future #[serde(serialize_with = ...)] that applied lossy
        // sanitisation would silently change persisted ladder specs.
        let adversarial = [
            r#"vault.read.with."quotes""#,
            "vault\\windows\\style",
            "vault\nwith\nnewlines",
            r#"{"json": "shaped"}"#,
        ];
        for name in adversarial {
            let spec = VariantLadderSpec {
                tool_name: name.to_string(),
                tiers: vec![VariantTier::T1Deterministic],
                auto_promote: false,
            };
            let s = serde_json::to_string(&spec).expect("serialise");
            let back: VariantLadderSpec =
                serde_json::from_str(&s).expect("deserialise");
            assert_eq!(back.tool_name, name, "tool_name must round-trip byte-equal");
            assert_eq!(back, spec);
        }
    }

    #[test]
    fn variant_ladder_spec_serde_tolerates_unknown_extra_fields_per_current_doctrine() {
        // Phase 1 hardening — DOCTRINE PIN with forward-compat teeth.
        // Completes the serde-tolerance pin family across the
        // agent_runtime_v2 user-facing structs (MissionPacket,
        // AnswerPacket, AgentBlueprint, MutationEnvelope, ToolCall,
        // Citation, LocalAgentCapability).
        //
        // VariantLadderSpec does NOT carry #[serde(deny_unknown_fields)].
        // A future field (e.g., `confidence_threshold` for auto-promote
        // tuning) might be added then reverted; logs that captured the
        // extra must still deserialise — extras silently drop.
        //
        // Pin the lenient behaviour so a future
        // #[serde(deny_unknown_fields)] addition surfaces at PR review
        // as a deliberate doctrine change.
        let spec = VariantLadderSpec {
            tool_name: "vault.read".into(),
            tiers: vec![VariantTier::T1Deterministic],
            auto_promote: false,
        };
        let s = serde_json::to_string(&spec).expect("serialise");
        let last_brace = s.rfind('}').expect("trailing brace");
        let mut augmented = String::with_capacity(s.len() + 50);
        augmented.push_str(&s[..last_brace]);
        augmented.push_str(r#","confidence_threshold":0.7}"#);
        let parsed: VariantLadderSpec =
            serde_json::from_str(&augmented).expect("unknown field tolerated");
        assert_eq!(parsed, spec);
    }
}
