//! Variant Ladder — typed seam for the No-LLM-First discipline.
//!
//! SCAFFOLD ONLY — RCA-P2-010 classification 2026-05-14.
//! Typed contract exported via `agent_core::variant_ladder::*` but
//! consumed by 0 production tool routes today. The reference variants
//! in `agent_core/src/route/variant_b_classifiers.rs` and
//! `agent_core/src/route/variant_c_providers.rs` implement the same
//! tier-1→tier-4 discipline by hand without going through this
//! generic seam. Re-promote when `agent_core/src/tools/registry.rs`
//! dispatch for `vault.search` (Master Fusion Plan §B.1) walks this
//! `VariantLadder<I,O>` instead of inline tier code — that's the
//! highest-ROI no-compromise win in the V1 ship plan.
//!
//! Doctrine: `docs/fusion/COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md`
//! Source: `docs/fusion/research/PLAN_V2.md` §1.4 +
//! `docs/fusion/salvage/from-vigorous-goldberg/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md`
//! §1.4.
//!
//! Codifies the contract every tool-route variant ladder honors:
//! Tier 1 (Deterministic Rust) → Tier 2 (Embedding) → Tier 3
//! (Classical) → Tier 4 (Small LLM) → Tier 5 (Mid LLM) → Tier 6
//! (Cloud). Every tier above Tier 1 is OPTIONAL — many tools skip
//! directly from Tier 1 to Tier 4. The constraint is on ORDER, not on
//! every tier being populated.
//!
//! The reference implementations are the route-capture variants at
//! `agent_core/src/route/variant_b_classifiers.rs` (Tier 1
//! KeywordOverlap → Tier 4 GBNF) and
//! `agent_core/src/route/variant_c_providers.rs` (Tier 1+2 keyword +
//! in-memory neighbour). Future tool-route work uses this typed
//! `VariantLadder` to plug in behind the same contract.

use std::sync::Arc;

use async_trait::async_trait;
use serde::{Deserialize, Serialize};

/// Canonical 6 tiers from doctrine §2. The numeric `as u8` values
/// reflect strict escalation order — a lower number is preferred.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[repr(u8)]
#[serde(rename_all = "snake_case")]
pub enum LadderTier {
    /// Tier 1: pure Rust function or table lookup; no model.
    Deterministic = 1,
    /// Tier 2: embedding lookup / centroid match. Deterministic given
    /// the index but uses a real model behind the scenes.
    Embedding = 2,
    /// Tier 3: small classical model (NLI / BERT / distilled). Not
    /// generative.
    Classical = 3,
    /// Tier 4: small local LLM (1.5B–3B). Generative; grammar-bound
    /// output required.
    SmallLLM = 4,
    /// Tier 5: mid local LLM (7B–8B). Generative; grammar-bound.
    MidLLM = 5,
    /// Tier 6: cloud. Last resort. Requires §1.3 explicit opt-in
    /// (slash command, ⌥-submit, etc).
    Cloud = 6,
}

impl LadderTier {
    /// Whether this tier is allowed without explicit user opt-in.
    /// Tiers 1-3 are deterministic-or-classical and always allowed;
    /// Tiers 4+ require either a slash command, the `escalate_on_empty`
    /// flag, or Settings opt-in.
    pub fn allowed_without_opt_in(self) -> bool {
        (self as u8) <= (LadderTier::Classical as u8)
    }
}

/// One variant in a ladder. Returns `Some(output)` when this variant
/// resolves the input above its confidence floor; `None` to fall
/// through to the next tier.
///
/// Implementations are pure functions of their input (deterministic);
/// implementations that wrap a generative LLM (Tier 4-6) must use
/// grammar-bound decoding so the output is structurally guaranteed.
#[async_trait]
pub trait LadderVariant<Input, Output>: Send + Sync
where
    Input: Send + Sync + 'static,
    Output: Send + Sync + 'static,
{
    /// The tier this variant occupies. Used by the ladder to enforce
    /// strict escalation order + by the ladder log to attribute
    /// outcomes.
    fn tier(&self) -> LadderTier;

    /// One-line name used in audit logs ("KeywordOverlapClassifier",
    /// "GbnfClassifier", "EmbeddingNearestNeighbour", etc).
    fn name(&self) -> &str;

    /// Try to resolve. None = fell through.
    async fn try_resolve(&self, input: &Input) -> Option<Output>;
}

/// Whether and when this ladder is allowed to escalate to Tier 4+
/// (a generative LLM tier). Per doctrine §6 / Master Fusion Plan
/// §B.3: default is `Never` — no ladder may silently invoke a Tier 4+
/// variant. The agent must either:
/// - Use a `/cloud` slash command (signals user intent),
/// - ⌥-submit (signals user intent),
/// - Toggle Settings → "Escalate to LLM on empty result", or
/// - Construct the ladder with an explicit `EscalationPolicy::OnEmpty`
///   AND carry a `// VARIANT-LADDER-DEFER:` source marker that the
///   audit register records.
///
/// The default is intentionally restrictive because Tier 4+ variants
/// are the ones that cost user budget (cloud tokens) and erode
/// determinism (LLM output drift). Tiers 1-3 stay always-on (per
/// `LadderTier::allowed_without_opt_in()`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EscalationPolicy {
    /// Never escalate beyond `LadderTier::Classical` (Tier 3). Default.
    /// If all 1-3 variants fall through, resolve returns `None`.
    #[default]
    Never,
    /// Escalate to Tier 4+ ONLY when every lower tier returned `None`.
    /// Requires an audit marker per doctrine §6.
    OnEmpty,
    /// Always allow ladder to walk through all variants including
    /// Tier 4+. Reserved for user-opt-in paths (slash command, etc.)
    /// where the explicit intent has already been recorded.
    Always,
}

/// Ordered ladder of variants. `resolve(input)` walks them in tier
/// order; first to return `Some` wins. The ladder enforces strict
/// escalation: variants must be sorted by tier ascending. Adding a
/// Tier 4 variant before all Tier 1-3 variants are placed first
/// fails construction.
pub struct VariantLadder<Input, Output>
where
    Input: Send + Sync + 'static,
    Output: Send + Sync + 'static,
{
    variants: Vec<Arc<dyn LadderVariant<Input, Output>>>,
    /// Default: `EscalationPolicy::Never`. Per Master Fusion Plan §B.3,
    /// the registry never auto-escalates to a generative tier without
    /// explicit user opt-in.
    escalation_policy: EscalationPolicy,
}

impl<Input, Output> Default for VariantLadder<Input, Output>
where
    Input: Send + Sync + 'static,
    Output: Send + Sync + 'static,
{
    fn default() -> Self {
        Self {
            variants: Vec::new(),
            escalation_policy: EscalationPolicy::default(),
        }
    }
}

#[derive(Debug, thiserror::Error)]
pub enum LadderError {
    #[error("variant added at tier {added:?} would violate strict escalation order; last tier was {last:?}")]
    OutOfOrder { added: LadderTier, last: LadderTier },
}

impl<Input, Output> VariantLadder<Input, Output>
where
    Input: Send + Sync + 'static,
    Output: Send + Sync + 'static,
{
    pub fn new() -> Self {
        Self::default()
    }

    /// Append a variant. Enforces strict tier-ascending order — once
    /// a Tier N variant is placed, only Tiers ≥ N may follow.
    pub fn push(
        &mut self,
        variant: Arc<dyn LadderVariant<Input, Output>>,
    ) -> Result<(), LadderError> {
        if let Some(last) = self.variants.last() {
            if (variant.tier() as u8) < (last.tier() as u8) {
                return Err(LadderError::OutOfOrder {
                    added: variant.tier(),
                    last: last.tier(),
                });
            }
        }
        self.variants.push(variant);
        Ok(())
    }

    /// Set the escalation policy. Default is `Never`. Setting this to
    /// `OnEmpty` or `Always` requires a `// VARIANT-LADDER-DEFER:`
    /// source marker per doctrine §6 + Master Fusion Plan §B.3, and
    /// the construction site must be audit-registered.
    ///
    /// Returns `self` for builder chaining: `ladder.with_escalation_policy(p)`.
    pub fn with_escalation_policy(mut self, policy: EscalationPolicy) -> Self {
        self.escalation_policy = policy;
        self
    }

    /// Read the current escalation policy. Used by `resolve()` to gate
    /// Tier 4+ variants and by audit surfaces to enumerate what each
    /// ladder is allowed to do.
    pub fn escalation_policy(&self) -> EscalationPolicy {
        self.escalation_policy
    }

    /// Walk the ladder; first variant to return `Some` wins. Returns
    /// the (resolved-by tier, name, output) so audit logs can record
    /// which variant resolved.
    ///
    /// Honors `escalation_policy`:
    /// - `Never` (default): skip any variant whose tier is > Tier 3.
    ///   If all 1-3 variants return `None`, the ladder returns `None`
    ///   instead of escalating to Tier 4+.
    /// - `OnEmpty`: walk Tier 4+ only after every 1-3 variant returned
    ///   `None`. (This is equivalent to the natural walk order because
    ///   `push()` enforces ascending tier; this variant is for
    ///   readability + symmetry.)
    /// - `Always`: walk all tiers in order.
    pub async fn resolve(&self, input: &Input) -> Option<LadderResolution<Output>> {
        for variant in &self.variants {
            // Gate: if Never, refuse to walk into the generative tier.
            if matches!(self.escalation_policy, EscalationPolicy::Never)
                && !variant.tier().allowed_without_opt_in()
            {
                continue;
            }
            if let Some(output) = variant.try_resolve(input).await {
                return Some(LadderResolution {
                    tier: variant.tier(),
                    variant_name: variant.name().to_string(),
                    output,
                });
            }
        }
        None
    }

    /// Snapshot for diagnostic surfaces.
    pub fn variant_names_and_tiers(&self) -> Vec<(String, LadderTier)> {
        self.variants
            .iter()
            .map(|v| (v.name().to_string(), v.tier()))
            .collect()
    }
}

#[derive(Debug, Clone)]
pub struct LadderResolution<Output> {
    pub tier: LadderTier,
    pub variant_name: String,
    pub output: Output,
}

#[cfg(test)]
mod tests {
    use super::*;

    struct AlwaysSomeVariant {
        tier: LadderTier,
        name: &'static str,
        return_value: u32,
    }

    #[async_trait]
    impl LadderVariant<u32, u32> for AlwaysSomeVariant {
        fn tier(&self) -> LadderTier {
            self.tier
        }
        fn name(&self) -> &str {
            self.name
        }
        async fn try_resolve(&self, input: &u32) -> Option<u32> {
            Some(self.return_value + input)
        }
    }

    struct AlwaysNoneVariant {
        tier: LadderTier,
        name: &'static str,
    }

    #[async_trait]
    impl LadderVariant<u32, u32> for AlwaysNoneVariant {
        fn tier(&self) -> LadderTier {
            self.tier
        }
        fn name(&self) -> &str {
            self.name
        }
        async fn try_resolve(&self, _input: &u32) -> Option<u32> {
            None
        }
    }

    #[tokio::test]
    async fn ladder_walks_in_tier_order_and_first_some_wins() {
        let mut ladder: VariantLadder<u32, u32> = VariantLadder::new();
        ladder
            .push(Arc::new(AlwaysNoneVariant {
                tier: LadderTier::Deterministic,
                name: "det",
            }))
            .unwrap();
        ladder
            .push(Arc::new(AlwaysSomeVariant {
                tier: LadderTier::Embedding,
                name: "emb",
                return_value: 100,
            }))
            .unwrap();
        ladder
            .push(Arc::new(AlwaysSomeVariant {
                tier: LadderTier::SmallLLM,
                name: "llm",
                return_value: 1000,
            }))
            .unwrap();

        let res = ladder.resolve(&5).await.expect("some");
        assert_eq!(res.tier, LadderTier::Embedding);
        assert_eq!(res.variant_name, "emb");
        assert_eq!(res.output, 105, "embedding tier wins, LLM never runs");
    }

    #[tokio::test]
    async fn ladder_returns_none_when_every_variant_falls_through() {
        let mut ladder: VariantLadder<u32, u32> = VariantLadder::new();
        ladder
            .push(Arc::new(AlwaysNoneVariant {
                tier: LadderTier::Deterministic,
                name: "det",
            }))
            .unwrap();
        ladder
            .push(Arc::new(AlwaysNoneVariant {
                tier: LadderTier::Embedding,
                name: "emb",
            }))
            .unwrap();
        assert!(ladder.resolve(&42).await.is_none());
    }

    #[tokio::test]
    async fn ladder_rejects_out_of_order_addition() {
        let mut ladder: VariantLadder<u32, u32> = VariantLadder::new();
        ladder
            .push(Arc::new(AlwaysNoneVariant {
                tier: LadderTier::SmallLLM,
                name: "llm",
            }))
            .unwrap();
        let err = ladder.push(Arc::new(AlwaysNoneVariant {
            tier: LadderTier::Deterministic,
            name: "det",
        }));
        assert!(matches!(err, Err(LadderError::OutOfOrder { .. })));
    }

    #[test]
    fn tier_ordering_matches_doctrine() {
        // doctrine §2 strict escalation order
        assert!((LadderTier::Deterministic as u8) < (LadderTier::Embedding as u8));
        assert!((LadderTier::Embedding as u8) < (LadderTier::Classical as u8));
        assert!((LadderTier::Classical as u8) < (LadderTier::SmallLLM as u8));
        assert!((LadderTier::SmallLLM as u8) < (LadderTier::MidLLM as u8));
        assert!((LadderTier::MidLLM as u8) < (LadderTier::Cloud as u8));
    }

    #[test]
    fn opt_in_gate_separates_deterministic_from_generative() {
        // §6 escalation gate — Tiers 1-3 are always allowed; Tiers
        // 4+ require explicit opt-in.
        assert!(LadderTier::Deterministic.allowed_without_opt_in());
        assert!(LadderTier::Embedding.allowed_without_opt_in());
        assert!(LadderTier::Classical.allowed_without_opt_in());
        assert!(!LadderTier::SmallLLM.allowed_without_opt_in());
        assert!(!LadderTier::MidLLM.allowed_without_opt_in());
        assert!(!LadderTier::Cloud.allowed_without_opt_in());
    }

    // -----------------------------------------------------------------
    // Master Fusion Plan §B.3 — escalate_on_empty default + opt-in gate
    // -----------------------------------------------------------------

    #[test]
    fn b3_default_escalation_policy_is_never() {
        // The doctrine default: a freshly constructed VariantLadder
        // MUST NOT escalate to a generative tier. Any change here
        // requires a corresponding doctrine update + audit row per
        // Master Fusion Plan §B.3.
        let ladder: VariantLadder<u32, u32> = VariantLadder::new();
        assert_eq!(ladder.escalation_policy(), EscalationPolicy::Never);

        let default_ladder: VariantLadder<u32, u32> = VariantLadder::default();
        assert_eq!(default_ladder.escalation_policy(), EscalationPolicy::Never);
    }

    #[tokio::test]
    async fn b3_never_policy_skips_generative_tiers_even_when_only_path() {
        // With EscalationPolicy::Never, the ladder MUST refuse to walk
        // into Tier 4+ even if every Tier 1-3 variant returned None
        // and only a Tier 4+ variant remains.
        let mut ladder: VariantLadder<u32, u32> = VariantLadder::new();
        ladder
            .push(Arc::new(AlwaysNoneVariant {
                tier: LadderTier::Deterministic,
                name: "det",
            }))
            .unwrap();
        ladder
            .push(Arc::new(AlwaysSomeVariant {
                tier: LadderTier::SmallLLM,
                name: "llm",
                return_value: 1000,
            }))
            .unwrap();
        // Default policy is Never — the LLM never runs.
        let res = ladder.resolve(&5).await;
        assert!(
            res.is_none(),
            "Never policy must refuse to invoke a generative tier; got {res:?}"
        );
    }

    #[tokio::test]
    async fn b3_always_policy_unlocks_generative_tiers_when_lower_tiers_fall_through() {
        // VARIANT-LADDER-DEFER: this exercises EscalationPolicy::Always
        // which is reserved for user-opt-in callers — the audit row
        // for the construction site is required by doctrine §6.
        let mut ladder = VariantLadder::<u32, u32>::new();
        ladder
            .push(Arc::new(AlwaysNoneVariant {
                tier: LadderTier::Deterministic,
                name: "det",
            }))
            .unwrap();
        ladder
            .push(Arc::new(AlwaysSomeVariant {
                tier: LadderTier::SmallLLM,
                name: "llm",
                return_value: 1000,
            }))
            .unwrap();
        let ladder = ladder.with_escalation_policy(EscalationPolicy::Always);
        let res = ladder.resolve(&7).await.expect("Always policy escalates");
        assert_eq!(res.tier, LadderTier::SmallLLM);
        assert_eq!(res.output, 1007);
    }

    #[tokio::test]
    async fn b3_on_empty_policy_escalates_only_after_all_lower_tiers_fall_through() {
        // VARIANT-LADDER-DEFER: this exercises EscalationPolicy::OnEmpty.
        let mut ladder = VariantLadder::<u32, u32>::new();
        ladder
            .push(Arc::new(AlwaysSomeVariant {
                tier: LadderTier::Embedding,
                name: "emb",
                return_value: 100,
            }))
            .unwrap();
        ladder
            .push(Arc::new(AlwaysSomeVariant {
                tier: LadderTier::Cloud,
                name: "cloud",
                return_value: 9999,
            }))
            .unwrap();
        let ladder = ladder.with_escalation_policy(EscalationPolicy::OnEmpty);

        // Embedding tier produces a value first; cloud never runs.
        let res = ladder.resolve(&3).await.expect("emb resolved");
        assert_eq!(res.tier, LadderTier::Embedding);
        assert_eq!(res.output, 103);
        assert_ne!(res.variant_name, "cloud", "Cloud must not run when emb resolved");
    }

    #[test]
    fn b3_escalation_policy_serializes_to_snake_case_for_audit_logs() {
        let json = serde_json::to_string(&EscalationPolicy::Never).unwrap();
        assert_eq!(json, "\"never\"");
        let json = serde_json::to_string(&EscalationPolicy::OnEmpty).unwrap();
        assert_eq!(json, "\"on_empty\"");
        let json = serde_json::to_string(&EscalationPolicy::Always).unwrap();
        assert_eq!(json, "\"always\"");
    }
}
