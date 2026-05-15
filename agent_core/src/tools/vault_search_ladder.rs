//! `vault.search` Variant Ladder — Master Fusion Plan §B.1 first slice.
//!
//! Wires `agent_core::variant_ladder::VariantLadder<I,O>` around the
//! existing `vault.search` dispatch as the proof-of-concept retrofit
//! per `COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` §5.
//!
//! Doctrine-mandated tiers for `vault.search` per §B.1 acceptance:
//!   - Tier 1 (Deterministic): Tantivy lexical BM25 only
//!   - Tier 2 (Embedding): vector / semantic only
//!   - Tier 3 (Classical): RRF k=60 hybrid fusion
//!   - Tier 4 (SmallLLM): grammar-bound clarifier (opt-in only)
//!   - Tier 5 (MidLLM): grammar-bound rerank (opt-in only)
//!   - Tier 6 (Cloud): never auto, slash-command only
//!
//! This first slice (B.1 1/N) ships ONLY the Tier 3 RRF hybrid variant
//! because `VaultBackend` today exposes a single `hybrid_search` method.
//! Adding Tier 1 (lexical-only) + Tier 2 (embedding-only) needs new
//! trait methods on every `VaultBackend` impl, which is a separate
//! slice (§B.1 2/N). Tier 4+ is gated behind `EscalationPolicy::OnEmpty`
//! per §B.3 (committed `7cb1ed426`) and stays off by default.
//!
//! Confidence floors per doctrine §4.2:
//!   - `FLOOR_T1 = 0.85`
//!   - `FLOOR_T2 = 0.75`
//!   - `FLOOR_T3 = 0.70`
//!
//! Acceptance criteria pinned by source-guard tests:
//!   - Tier 3 variant accepts when the top result's score ≥ FLOOR_T3
//!   - Tier 3 variant declines (returns `None`) when top score < FLOOR_T3
//!   - Tier 3 variant declines on empty results
//!   - The ladder's `escalation_policy` is `Never` by default so Tier 4+
//!     variants cannot fire silently
//!   - The ladder ships exactly one variant today (T3); adding more
//!     trips the source-guard expectation set so reviewers notice
//!
//! Source-guard tests live in this file; the integration with
//! `VaultSearchHandler` lives in `tools/registry.rs` and ships in the
//! same PR.

use std::sync::Arc;

use async_trait::async_trait;

use crate::storage::vault::{SearchResult, VaultBackend};
use crate::variant_ladder::{LadderTier, LadderVariant, VariantLadder};

/// Per-doctrine confidence floors. Top result's `score` must be at or
/// above the matching floor for the tier to accept.
pub const FLOOR_T1: f64 = 0.85;
pub const FLOOR_T2: f64 = 0.75;
pub const FLOOR_T3: f64 = 0.70;

/// Input to every variant in the `vault.search` ladder.
///
/// Backend is shared via `Arc<dyn VaultBackend>` so variants can do
/// their own queries (Tier 1 lexical-only, Tier 2 embedding-only,
/// Tier 3 RRF hybrid) without redundant cloning of the trait object.
#[derive(Clone)]
pub struct VaultSearchLadderInput {
    pub query: String,
    pub limit: usize,
    pub tags: Vec<String>,
    pub backend: Arc<dyn VaultBackend>,
}

/// Output of a successful ladder resolution — the search results that
/// the resolving tier produced. The caller (`VaultSearchHandler`)
/// formats these into the user-facing tool result string.
#[derive(Debug, Clone)]
pub struct VaultSearchLadderOutput {
    pub results: Vec<SearchResult>,
}

/// Tier 3 — RRF k=60 hybrid fusion via `VaultBackend::hybrid_search`.
///
/// Per the §B.1 acceptance, this tier accepts when the top result's
/// score is at or above `FLOOR_T3`. Below the floor → returns `None`
/// so the ladder can either escalate (if policy permits) or defer.
pub struct VaultSearchT3RrfHybrid;

#[async_trait]
impl LadderVariant<VaultSearchLadderInput, VaultSearchLadderOutput>
    for VaultSearchT3RrfHybrid
{
    fn tier(&self) -> LadderTier {
        LadderTier::Classical
    }

    fn name(&self) -> &str {
        "VaultSearchT3RrfHybrid"
    }

    async fn try_resolve(
        &self,
        input: &VaultSearchLadderInput,
    ) -> Option<VaultSearchLadderOutput> {
        let results = match input
            .backend
            .hybrid_search(&input.query, input.limit, &input.tags)
            .await
        {
            Ok(rs) => rs,
            Err(_) => return None,
        };
        accept_above_floor(results, FLOOR_T3)
    }
}

/// Helper: accept the results set iff non-empty AND the top result's
/// score is at or above `floor`. Used by every tier's `try_resolve`.
fn accept_above_floor(
    results: Vec<SearchResult>,
    floor: f64,
) -> Option<VaultSearchLadderOutput> {
    let top_score = results.first().map(|r| r.score).unwrap_or(0.0);
    if !results.is_empty() && top_score >= floor {
        Some(VaultSearchLadderOutput { results })
    } else {
        None
    }
}

/// Construct the canonical `vault.search` ladder. Today this is a
/// single-tier ladder (T3 RRF hybrid). Adding T1 + T2 is purely
/// additive; the consumer side (VaultSearchHandler) doesn't change
/// when new tiers land.
///
/// Default escalation policy is `Never` per §B.3 — no Tier 4+ variant
/// can fire silently. Construction sites that need LLM escalation must
/// chain `.with_escalation_policy(EscalationPolicy::OnEmpty)` AND
/// carry a `// VARIANT-LADDER-DEFER:` source marker.
pub fn build_vault_search_ladder(
) -> Result<VariantLadder<VaultSearchLadderInput, VaultSearchLadderOutput>, crate::variant_ladder::LadderError>
{
    let mut ladder = VariantLadder::new();
    ladder.push(Arc::new(VaultSearchT3RrfHybrid))?;
    Ok(ladder)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::vault::VaultError;
    use crate::variant_ladder::EscalationPolicy;

    /// In-memory `VaultBackend` test double. Returns pre-baked results
    /// for any query — lets the source-guard tests pin the ladder's
    /// floor + escalation behavior without a real Tantivy index.
    struct FakeVaultBackend {
        canned: Vec<SearchResult>,
    }

    #[async_trait]
    impl VaultBackend for FakeVaultBackend {
        async fn hybrid_search(
            &self,
            _query: &str,
            _limit: usize,
            _tag_filter: &[String],
        ) -> Result<Vec<SearchResult>, VaultError> {
            Ok(self.canned.clone())
        }

        async fn read(&self, _path: &str) -> Result<String, VaultError> {
            unreachable!("fake backend never reads")
        }

        async fn write(
            &self,
            _path: &str,
            _content: &str,
            _tags: Option<&[String]>,
            _append: bool,
        ) -> Result<(), VaultError> {
            unreachable!("fake backend never writes")
        }

        async fn list(&self, _path_prefix: &str) -> Result<Vec<String>, VaultError> {
            unreachable!("fake backend never lists")
        }

        async fn exists(&self, _path: &str) -> Result<bool, VaultError> {
            unreachable!("fake backend never checks existence")
        }

        async fn delete(&self, _path: &str) -> Result<bool, VaultError> {
            unreachable!("fake backend never deletes")
        }
    }

    fn result(path: &str, score: f64) -> SearchResult {
        SearchResult {
            path: path.to_string(),
            excerpt: "snippet".to_string(),
            score,
            tags: vec![],
        }
    }

    fn input(canned: Vec<SearchResult>) -> VaultSearchLadderInput {
        VaultSearchLadderInput {
            query: "anything".to_string(),
            limit: 5,
            tags: vec![],
            backend: Arc::new(FakeVaultBackend { canned }),
        }
    }

    #[test]
    fn doctrine_floors_match_master_fusion_plan_b_1() {
        // Acceptance anchor: floor constants MUST match §B.1 doctrine.
        assert_eq!(FLOOR_T1, 0.85);
        assert_eq!(FLOOR_T2, 0.75);
        assert_eq!(FLOOR_T3, 0.70);
    }

    #[tokio::test]
    async fn t3_variant_accepts_when_top_score_is_at_or_above_floor() {
        // Top score = 0.72 ≥ FLOOR_T3 = 0.70 → accept.
        let canned = vec![result("notes/a.md", 0.72), result("notes/b.md", 0.50)];
        let inp = input(canned);
        let resolved = VaultSearchT3RrfHybrid.try_resolve(&inp).await;
        let output = resolved.expect("T3 must accept top_score=0.72");
        assert_eq!(output.results.len(), 2);
        assert_eq!(output.results[0].path, "notes/a.md");
    }

    #[tokio::test]
    async fn t3_variant_declines_when_top_score_is_below_floor() {
        // Top score = 0.65 < FLOOR_T3 = 0.70 → decline.
        let canned = vec![result("notes/a.md", 0.65), result("notes/b.md", 0.40)];
        let inp = input(canned);
        let resolved = VaultSearchT3RrfHybrid.try_resolve(&inp).await;
        assert!(
            resolved.is_none(),
            "T3 must decline when top_score < FLOOR_T3"
        );
    }

    #[tokio::test]
    async fn t3_variant_declines_on_empty_results() {
        // Empty results → decline (no scoring possible).
        let inp = input(vec![]);
        let resolved = VaultSearchT3RrfHybrid.try_resolve(&inp).await;
        assert!(
            resolved.is_none(),
            "T3 must decline on empty backend results"
        );
    }

    #[tokio::test]
    async fn ladder_resolves_via_t3_when_score_above_floor() {
        // Integration check: ladder construction + resolve path.
        let canned = vec![result("notes/a.md", 0.80)];
        let inp = input(canned);
        let ladder = build_vault_search_ladder().expect("ladder must build");
        let resolution = ladder.resolve(&inp).await.expect("ladder must resolve");
        assert_eq!(resolution.tier, LadderTier::Classical);
        assert_eq!(resolution.variant_name, "VaultSearchT3RrfHybrid");
        assert_eq!(resolution.output.results.len(), 1);
    }

    #[tokio::test]
    async fn ladder_returns_none_when_t3_declines() {
        // No tier accepted → ladder returns None → handler should
        // surface the doctrine §6 "defer is a first-class outcome".
        let canned = vec![result("notes/a.md", 0.40)];
        let inp = input(canned);
        let ladder = build_vault_search_ladder().expect("ladder must build");
        assert!(ladder.resolve(&inp).await.is_none());
    }

    #[test]
    fn ladder_default_escalation_policy_is_never() {
        // §B.3 anchor: no Tier 4+ variant can fire silently. The
        // ladder default MUST be `Never`.
        let ladder = build_vault_search_ladder().expect("ladder must build");
        assert_eq!(ladder.escalation_policy(), EscalationPolicy::Never);
    }

    #[test]
    fn ladder_ships_exactly_one_tier_today() {
        // §B.1 1/N source-guard. This number changes when T1 + T2 land.
        // Counter-intuitively, the GUARD is the assertion — when a
        // future PR adds T1/T2, this test breaks intentionally and
        // forces the reviewer to update the count + the doctrine row.
        let ladder = build_vault_search_ladder().expect("ladder must build");
        let names_and_tiers = ladder.variant_names_and_tiers();
        assert_eq!(
            names_and_tiers.len(),
            1,
            "B.1 ships one tier today; update this count when T1+T2 land. Got: {:?}",
            names_and_tiers
        );
        assert_eq!(
            names_and_tiers[0],
            ("VaultSearchT3RrfHybrid".to_string(), LadderTier::Classical)
        );
    }
}
