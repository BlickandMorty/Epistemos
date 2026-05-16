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
    /// which variant resolved. The `attempts` field on the returned
    /// resolution carries the full audit trail (every variant tried
    /// including the winning one as the last entry).
    ///
    /// Convenience wrapper over [`resolve_walk`] for callers that only
    /// care about the resolution. For full audit-trail-when-the-ladder-
    /// declined behavior, use `resolve_walk` directly.
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
        self.resolve_walk(input).await.resolution
    }

    /// Walk the ladder and return the full audit trail. The
    /// [`LadderWalk`] result carries the resolution (Some / None) AND
    /// the per-variant `attempts` list — every variant the ladder
    /// tried, including the declined / skipped-by-policy ones. Used by
    /// downstream audit surfaces (Provenance Console / LadderLog /
    /// replay) that want to show "tried T1 (declined), tried T3
    /// (accepted)" even when the ladder ultimately defers.
    pub async fn resolve_walk(&self, input: &Input) -> LadderWalk<Output> {
        let mut attempts: Vec<LadderAttempt> = Vec::with_capacity(self.variants.len());
        for variant in &self.variants {
            // Gate: if Never, refuse to walk into the generative tier.
            if matches!(self.escalation_policy, EscalationPolicy::Never)
                && !variant.tier().allowed_without_opt_in()
            {
                attempts.push(LadderAttempt {
                    tier: variant.tier(),
                    variant_name: variant.name().to_string(),
                    outcome: LadderAttemptOutcome::SkippedByPolicy,
                });
                continue;
            }
            if let Some(output) = variant.try_resolve(input).await {
                attempts.push(LadderAttempt {
                    tier: variant.tier(),
                    variant_name: variant.name().to_string(),
                    outcome: LadderAttemptOutcome::Accepted,
                });
                let resolution = LadderResolution {
                    tier: variant.tier(),
                    variant_name: variant.name().to_string(),
                    output,
                    attempts: attempts.clone(),
                };
                return LadderWalk {
                    resolution: Some(resolution),
                    attempts,
                };
            } else {
                attempts.push(LadderAttempt {
                    tier: variant.tier(),
                    variant_name: variant.name().to_string(),
                    outcome: LadderAttemptOutcome::Declined,
                });
            }
        }
        LadderWalk {
            resolution: None,
            attempts,
        }
    }

    /// Snapshot for diagnostic surfaces.
    pub fn variant_names_and_tiers(&self) -> Vec<(String, LadderTier)> {
        self.variants
            .iter()
            .map(|v| (v.name().to_string(), v.tier()))
            .collect()
    }
}

/// Outcome of a single variant attempt during a ladder walk. Recorded
/// in `LadderResolution.attempts` + `LadderWalk.attempts` so audit
/// surfaces (Provenance Console / future LadderLog rows / replay)
/// can show the full ladder trace, not just the winning variant.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LadderAttemptOutcome {
    /// Variant returned `Some(output)`; this attempt is the
    /// resolving one. There is at most one `Accepted` outcome per
    /// walk and (when present) it is always the LAST entry in the
    /// attempts list.
    Accepted,
    /// Variant returned `None`; the ladder fell through to the next.
    Declined,
    /// Variant was skipped by the escalation policy (Tier 4+ under
    /// `EscalationPolicy::Never`). No `try_resolve` call was made.
    SkippedByPolicy,
}

/// One audit-trail row recording a variant attempt during
/// [`VariantLadder::resolve_walk`].
///
/// Implements `Serialize` + `Deserialize` so the audit trail can flow
/// into a Provenance Console replay bundle (`ReplayBundle` in
/// `agent_core::provenance::replay`) without a remap layer. The
/// `tier` field reuses `LadderTier`'s existing snake_case serde
/// shape; `outcome` uses `LadderAttemptOutcome`'s shape.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct LadderAttempt {
    pub tier: LadderTier,
    pub variant_name: String,
    pub outcome: LadderAttemptOutcome,
}

/// Result of a full ladder walk including the audit trail.
///
/// The `resolution` field carries the winning variant's output (or
/// `None` if the ladder deferred). The `attempts` field carries the
/// full per-variant audit trail — every variant the ladder TRIED,
/// including the declined / skipped-by-policy ones. When `resolution`
/// is `Some`, the last entry of `attempts` is the same variant +
/// `LadderAttemptOutcome::Accepted`. When `resolution` is `None`,
/// every entry in `attempts` is `Declined` or `SkippedByPolicy`.
///
/// Implements `Serialize` + `Deserialize` when `Output` does — lets
/// the full walk serialize into a Provenance Console replay bundle
/// when the ladder's output type is itself serializable.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(bound = "Output: Serialize + serde::de::DeserializeOwned")]
pub struct LadderWalk<Output> {
    pub resolution: Option<LadderResolution<Output>>,
    pub attempts: Vec<LadderAttempt>,
}

/// Result of a successful ladder resolution. Implements `Serialize`
/// + `Deserialize` when `Output` does.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(bound = "Output: Serialize + serde::de::DeserializeOwned")]
pub struct LadderResolution<Output> {
    pub tier: LadderTier,
    pub variant_name: String,
    pub output: Output,
    /// Full audit trail: every variant the ladder tried before (and
    /// including) the resolving one. The resolving entry is the LAST
    /// element. Use [`VariantLadder::resolve_walk`] when you need the
    /// attempts even on a deferred (`None`) outcome.
    pub attempts: Vec<LadderAttempt>,
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

    #[test]
    fn ladder_tier_serializes_to_snake_case_for_audit_logs() {
        // `LadderTier` is named in `LadderAttempt` audit-trail
        // records, which cross into `.epbundle` archives via
        // `ReplayBundle.ladder_walks`. Pinning the wire format here
        // means audits stay parseable across releases.
        //
        // Note the LLM-variant casing: serde's `rename_all =
        // "snake_case"` splits between every capital letter, so
        // `SmallLLM` becomes `small_l_l_m` rather than the more
        // readable `small_llm`. That's not pretty but it's the
        // canonical wire format and any audit log on disk already
        // matches it. A future PR that wants `small_llm` MUST add an
        // explicit `#[serde(rename = "small_llm")]` to that variant
        // AND ship a migration; this test fails if either side drifts.
        use serde_json::to_string;
        assert_eq!(to_string(&LadderTier::Deterministic).unwrap(), "\"deterministic\"");
        assert_eq!(to_string(&LadderTier::Embedding).unwrap(), "\"embedding\"");
        assert_eq!(to_string(&LadderTier::Classical).unwrap(), "\"classical\"");
        assert_eq!(to_string(&LadderTier::SmallLLM).unwrap(), "\"small_l_l_m\"");
        assert_eq!(to_string(&LadderTier::MidLLM).unwrap(), "\"mid_l_l_m\"");
        assert_eq!(to_string(&LadderTier::Cloud).unwrap(), "\"cloud\"");

        // Round-trip in: a historical audit log decodes cleanly.
        let decoded: LadderTier = serde_json::from_str("\"small_l_l_m\"").unwrap();
        assert_eq!(decoded, LadderTier::SmallLLM);
        let decoded: LadderTier = serde_json::from_str("\"mid_l_l_m\"").unwrap();
        assert_eq!(decoded, LadderTier::MidLLM);
    }

    #[test]
    fn ladder_tier_numeric_values_match_doctrine_assignments() {
        // `tier_ordering_matches_doctrine` (above) pins relative
        // numeric order. This test pins the EXACT integer values from
        // doctrine §2's tier table.
        //
        // Load-bearing for two reasons beyond the relative ordering:
        //   (a) `allowed_without_opt_in` compares against
        //       `Classical as u8` literally — adding a new variant
        //       between Classical and SmallLLM would silently shift
        //       SmallLLM to u8=4 → 5 and either widen or narrow the
        //       opt-in gate without anyone noticing.
        //   (b) Any future downstream consumer that persists or
        //       transmits the numeric tier (analytics dashboards,
        //       debug logs, FFI surfaces) would silently corrupt
        //       audit history across a renumber.
        //
        // Adding a new tier requires explicit consideration of where
        // it falls relative to the opt-in line — this test forces
        // that conversation by failing on any unintended renumber.
        assert_eq!(LadderTier::Deterministic as u8, 1);
        assert_eq!(LadderTier::Embedding as u8, 2);
        assert_eq!(LadderTier::Classical as u8, 3);
        assert_eq!(LadderTier::SmallLLM as u8, 4);
        assert_eq!(LadderTier::MidLLM as u8, 5);
        assert_eq!(LadderTier::Cloud as u8, 6);
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
        // VARIANT-LADDER-DEFER: test-only opt-in to Tier 4+ Always policy
        // for the b3 audit; production routes default to `Never`.
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
        // VARIANT-LADDER-DEFER: test-only opt-in to OnEmpty policy that
        // unlocks Tier 4+ when lower tiers all return None. Production
        // routes default to `Never`.
        let ladder = ladder.with_escalation_policy(EscalationPolicy::OnEmpty);

        // Embedding tier produces a value first; cloud never runs.
        let res = ladder.resolve(&3).await.expect("emb resolved");
        assert_eq!(res.tier, LadderTier::Embedding);
        assert_eq!(res.output, 103);
        assert_ne!(res.variant_name, "cloud", "Cloud must not run when emb resolved");
    }

    #[test]
    fn b3_escalation_policy_serializes_to_snake_case_for_audit_logs() {
        // Encode direction.
        let json = serde_json::to_string(&EscalationPolicy::Never).unwrap();
        assert_eq!(json, "\"never\"");
        let json = serde_json::to_string(&EscalationPolicy::OnEmpty).unwrap();
        assert_eq!(json, "\"on_empty\"");
        let json = serde_json::to_string(&EscalationPolicy::Always).unwrap();
        assert_eq!(json, "\"always\"");

        // Decode direction — historical audit logs / replay bundles
        // produced before any code change must continue to deserialize
        // to the canonical variants. The `on_empty` form is the load-
        // bearing compound: a serde quirk that turned `OnEmpty` into
        // `onempty` or `on-empty` would orphan every persisted record
        // that used the documented snake_case form.
        let decoded: EscalationPolicy = serde_json::from_str("\"never\"").unwrap();
        assert_eq!(decoded, EscalationPolicy::Never);
        let decoded: EscalationPolicy = serde_json::from_str("\"on_empty\"").unwrap();
        assert_eq!(decoded, EscalationPolicy::OnEmpty);
        let decoded: EscalationPolicy = serde_json::from_str("\"always\"").unwrap();
        assert_eq!(decoded, EscalationPolicy::Always);
    }


    // -----------------------------------------------------------------
    // Master Fusion Plan §B.1 — LadderAttempt audit trail
    // -----------------------------------------------------------------

    #[tokio::test]
    async fn resolve_walk_records_declined_then_accepted_attempts_in_order() {
        // Pre-condition: a 2-tier ladder where T1 (Deterministic)
        // declines and T2 (Embedding) accepts. The audit trail must
        // record BOTH attempts, with the declined one first.
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

        let walk = ladder.resolve_walk(&5).await;
        assert_eq!(walk.attempts.len(), 2);
        assert_eq!(walk.attempts[0].variant_name, "det");
        assert_eq!(walk.attempts[0].outcome, LadderAttemptOutcome::Declined);
        assert_eq!(walk.attempts[1].variant_name, "emb");
        assert_eq!(walk.attempts[1].outcome, LadderAttemptOutcome::Accepted);

        // Resolution echoes the same attempts in its embedded field.
        let resolution = walk.resolution.expect("must resolve");
        assert_eq!(resolution.attempts, walk.attempts);
        assert_eq!(
            resolution.attempts.last().unwrap().outcome,
            LadderAttemptOutcome::Accepted,
            "the resolving attempt MUST be the last entry in attempts"
        );
    }

    #[tokio::test]
    async fn resolve_walk_records_all_declines_when_ladder_defers() {
        // When every variant declines, resolution is None but
        // attempts still capture the full audit trail. This is the
        // value of resolve_walk over resolve: callers can see
        // "tried T1 (declined), tried T2 (declined)" even when the
        // ladder defers.
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

        let walk = ladder.resolve_walk(&42).await;
        assert!(walk.resolution.is_none(), "no variant accepted → resolution=None");
        assert_eq!(walk.attempts.len(), 2);
        assert!(walk.attempts.iter().all(|a| a.outcome == LadderAttemptOutcome::Declined));
    }

    #[tokio::test]
    async fn resolve_walk_records_skipped_by_policy_for_tier_4_under_never() {
        // EscalationPolicy::Never gates Tier 4+. The walk must
        // record the SkippedByPolicy outcome so audit surfaces can
        // show "we would have tried T4 but policy forbade it".
        let mut ladder: VariantLadder<u32, u32> = VariantLadder::new();
        ladder
            .push(Arc::new(AlwaysNoneVariant {
                tier: LadderTier::Classical,
                name: "cls",
            }))
            .unwrap();
        ladder
            .push(Arc::new(AlwaysSomeVariant {
                tier: LadderTier::SmallLLM,
                name: "small_llm",
                return_value: 999,
            }))
            .unwrap();
        // Default escalation policy = Never.

        let walk = ladder.resolve_walk(&7).await;
        assert!(walk.resolution.is_none(),
                "Never policy must NOT let T4 fire even though it would accept");
        assert_eq!(walk.attempts.len(), 2);
        assert_eq!(walk.attempts[0].variant_name, "cls");
        assert_eq!(walk.attempts[0].outcome, LadderAttemptOutcome::Declined);
        assert_eq!(walk.attempts[1].variant_name, "small_llm");
        assert_eq!(walk.attempts[1].outcome, LadderAttemptOutcome::SkippedByPolicy);
    }

    #[tokio::test]
    async fn resolve_wrapper_returns_same_resolution_as_resolve_walk() {
        // resolve() is the thin wrapper. Pin that it returns the
        // SAME resolution as resolve_walk().resolution so callers
        // that don't need the full walk don't get a different code
        // path.
        let mut ladder: VariantLadder<u32, u32> = VariantLadder::new();
        ladder
            .push(Arc::new(AlwaysSomeVariant {
                tier: LadderTier::Deterministic,
                name: "det",
                return_value: 11,
            }))
            .unwrap();

        let via_resolve = ladder.resolve(&5).await.expect("must resolve");
        let walk = ladder.resolve_walk(&5).await;
        let via_walk = walk.resolution.expect("walk must resolve");
        assert_eq!(via_resolve.tier, via_walk.tier);
        assert_eq!(via_resolve.variant_name, via_walk.variant_name);
        assert_eq!(via_resolve.output, via_walk.output);
        assert_eq!(via_resolve.attempts, via_walk.attempts);
    }

    #[test]
    fn ladder_attempt_outcome_serializes_to_snake_case_for_audit_logs() {
        // Wire format anchor for downstream Provenance Console row.
        // `SkippedByPolicy` is the load-bearing one — recorded when
        // the §6 EscalationPolicy::Never gate skips a Tier 4+ variant
        // without opt-in. A camelCase or PascalCase form would orphan
        // every prior `.epbundle` audit log.
        let json = serde_json::to_string(&LadderAttemptOutcome::Accepted).unwrap();
        assert_eq!(json, "\"accepted\"");
        let json = serde_json::to_string(&LadderAttemptOutcome::Declined).unwrap();
        assert_eq!(json, "\"declined\"");
        let json = serde_json::to_string(&LadderAttemptOutcome::SkippedByPolicy).unwrap();
        assert_eq!(json, "\"skipped_by_policy\"");

        // Round-trip IN: a hand-written audit log produced before
        // any code change must decode cleanly — proving the wire
        // format is anchored both directions.
        let decoded: LadderAttemptOutcome =
            serde_json::from_str("\"skipped_by_policy\"").unwrap();
        assert_eq!(decoded, LadderAttemptOutcome::SkippedByPolicy);
        let decoded: LadderAttemptOutcome =
            serde_json::from_str("\"accepted\"").unwrap();
        assert_eq!(decoded, LadderAttemptOutcome::Accepted);
    }

    // -----------------------------------------------------------------
    // Master Fusion Plan §B.1 5/N — serde derives on the audit trail
    // -----------------------------------------------------------------

    #[test]
    fn ladder_attempt_round_trips_through_json() {
        let attempt = LadderAttempt {
            tier: LadderTier::Classical,
            variant_name: "VaultSearchT3RrfHybrid".to_string(),
            outcome: LadderAttemptOutcome::Accepted,
        };
        let json = serde_json::to_string(&attempt).expect("serialize");
        // Wire-format pin — the registry.rs tracing emission relies on
        // these exact key names and snake_case enum values.
        assert!(json.contains("\"tier\":\"classical\""),
                "tier must serialize as snake_case `classical`; got {json}");
        assert!(json.contains("\"variant_name\":\"VaultSearchT3RrfHybrid\""),
                "variant_name must be the canonical key; got {json}");
        assert!(json.contains("\"outcome\":\"accepted\""),
                "outcome must serialize as snake_case `accepted`; got {json}");

        let decoded: LadderAttempt = serde_json::from_str(&json).expect("deserialize");
        assert_eq!(decoded, attempt);
    }

    #[tokio::test]
    async fn ladder_walk_round_trips_through_json_when_output_is_serializable() {
        // Prove the LadderWalk<Output> serde derive works end-to-end
        // when Output: Serialize + DeserializeOwned. This is the
        // architectural anchor: future ReplayBundle integration can
        // serialize an entire walk + resolution into the replay JSON.
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

        let walk = ladder.resolve_walk(&5).await;
        let json = serde_json::to_string(&walk).expect("walk serialize");
        let decoded: LadderWalk<u32> = serde_json::from_str(&json).expect("walk deserialize");

        let resolved = decoded.resolution.expect("must round-trip with resolution");
        assert_eq!(resolved.tier, LadderTier::Embedding);
        assert_eq!(resolved.variant_name, "emb");
        assert_eq!(resolved.output, 105);
        assert_eq!(resolved.attempts.len(), 2);
        assert_eq!(decoded.attempts.len(), 2);
        assert_eq!(decoded.attempts[0].outcome, LadderAttemptOutcome::Declined);
        assert_eq!(decoded.attempts[1].outcome, LadderAttemptOutcome::Accepted);
    }

    #[tokio::test]
    async fn ladder_walk_round_trips_when_resolution_is_none() {
        // Defer case: resolution is None but attempts still flow
        // through the serde derive intact.
        let mut ladder: VariantLadder<u32, u32> = VariantLadder::new();
        ladder
            .push(Arc::new(AlwaysNoneVariant {
                tier: LadderTier::Deterministic,
                name: "det",
            }))
            .unwrap();

        let walk = ladder.resolve_walk(&42).await;
        let json = serde_json::to_string(&walk).expect("walk serialize");
        let decoded: LadderWalk<u32> = serde_json::from_str(&json).expect("walk deserialize");
        assert!(decoded.resolution.is_none());
        assert_eq!(decoded.attempts.len(), 1);
        assert_eq!(decoded.attempts[0].outcome, LadderAttemptOutcome::Declined);
    }
}
