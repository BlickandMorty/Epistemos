//! Phase 3D-3 — Variant C: concept-anchored placement.
//!
//! Plan §4.5 verbatim — the most semantically-grounded variant in the
//! ladder. Threshold 0.70. Variant C is the ONLY variant that can emit
//! `merge_into_existing_note` or `create_folder` actions per §4.1.
//!
//! Pipeline:
//! 1. Extract primary concept from capture (LLM-bearing tool —
//!    abstracted behind `ConceptExtractor` trait so Phase 6 wires the
//!    real impl).
//! 2. Resolve to existing concept node (`EntityResolver::resolve`).
//! 3. Find neighbours via vault.search (`NeighbourFinder::find`, k=12).
//! 4. Group neighbours by folder; identify top folder by count.
//! 5. Apply §4.5 decision tree:
//!    - (Found, tight cluster, n≥3) → consider merge gated by §4.5
//!      (confidence ≥0.90 AND target staleness >24h); else place at 0.72.
//!    - (New, tight cluster, n≥3, parent unfit) → create_folder at 0.71.
//!    - (otherwise, n≥3) → place by neighbour majority at 0.70 (safe
//!      default).
//!    - (otherwise) → None (orchestrator advances to Variant D).
//!
//! Per plan §1.4 No-LLM-First mandate: most of Variant C is
//! deterministic (graph traversal + folder grouping + cosine tightness
//! check); only the concept extraction step uses an LLM, and even that
//! step (§3.7) prefers the deterministic canonicalizer when surface
//! vocabulary already maps cleanly.

use std::collections::HashMap;

use async_trait::async_trait;

use crate::canon;

use super::{
    RouteDecision, CREATE_FOLDER_CLUSTER_COSINE, CREATE_FOLDER_CLUSTER_MIN_COUNT,
    MERGE_CONFIDENCE_GATE, MERGE_STALENESS_HOURS, VARIANT_C_CREATE_FOLDER_CONFIDENCE,
    VARIANT_C_PLACE_VIA_FOUND_CONFIDENCE, VARIANT_C_PLACE_VIA_MAJORITY_CONFIDENCE,
};

/// One concept extracted from capture text. `canonical_name` is the
/// canonicalized form (post canon::canonicalize); `surface_form`
/// preserves what the user actually wrote for the trace UI.
#[derive(Debug, Clone, PartialEq)]
pub struct Concept {
    pub canonical_name: String,
    pub surface_form: String,
}

/// LLM-bearing concept extraction. Phase 6 wires the real
/// MLX-Structured-backed impl that uses the closed-vocab grammar
/// per §6.6.5 (Phi-3.5-mini for closed-vocab classification).
#[async_trait]
pub trait ConceptExtractor: Send + Sync {
    async fn extract(&self, text: &str) -> Result<Vec<Concept>, ExtractorError>;
}

#[derive(Debug, thiserror::Error)]
pub enum ExtractorError {
    #[error("extraction failed: {0}")]
    Inference(String),
}

/// Plan §4.5: knowledge.entity_resolve — does this canonical name
/// match an existing concept node in the vault?
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Resolution {
    /// Existing concept node found at this id.
    Found { concept_id: String },
    /// Genuinely new concept (no existing node within cosine 0.92 per §4.5).
    New,
}

#[async_trait]
pub trait EntityResolver: Send + Sync {
    async fn resolve(&self, canonical_name: &str) -> Resolution;
}

/// One vault.search hit. The clustering logic uses `cosine` for the
/// tightness check; `last_edited_hours_ago` gates the merge path per
/// §4.5; `folder` is the parent folder for grouping.
#[derive(Debug, Clone, PartialEq)]
pub struct NeighbourHit {
    pub path: String,
    pub folder: String,
    pub cosine: f64,
    pub last_edited_hours_ago: u64,
}

#[async_trait]
pub trait NeighbourFinder: Send + Sync {
    async fn find(&self, query: &str, k: usize) -> Vec<NeighbourHit>;
}

/// Plan §4.5 Variant C — verbatim decision tree.
///
/// Returns `Some(RouteDecision)` when one of the three matched
/// branches fires (merge / create_folder / place-via-majority).
/// Returns `None` otherwise so the orchestrator advances to Variant D.
///
/// `parent_unfit` is a callback the orchestrator supplies — true iff
/// no existing parent folder is a better fit than creating a new one
/// under `top_folder`. Phase 3 ships a deterministic stub that returns
/// true when no centroid above 0.85 exists; richer policy comes later.
pub async fn try_concept_anchored(
    capture_text: &str,
    extractor: &dyn ConceptExtractor,
    resolver: &dyn EntityResolver,
    neighbours: &dyn NeighbourFinder,
    parent_unfit: impl Fn(&str) -> bool,
) -> Option<RouteDecision> {
    if capture_text.is_empty() {
        return None;
    }

    let concepts = extractor.extract(capture_text).await.ok()?;
    let primary = concepts.first()?;
    // Re-canonicalize defensively — concept_extract should already do
    // this, but the canonicalizer is idempotent and the canonical-name
    // invariant is load-bearing for resolution + neighbour search.
    let canonical = canon::canonicalize(&primary.canonical_name);
    if canonical.is_empty() {
        return None;
    }

    let resolution = resolver.resolve(&canonical).await;

    // Plan §4.5 verbatim: vault.search with k=12.
    let hits = neighbours.find(&canonical, 12).await;
    if hits.is_empty() {
        return None;
    }

    let folder_counts = group_by_folder(&hits);
    let (top_folder, count) = folder_counts.into_iter().max_by_key(|(_, c)| *c)?;
    if count < CREATE_FOLDER_CLUSTER_MIN_COUNT {
        return None;
    }

    let tight = cluster_tight(&hits, &top_folder);

    match (&resolution, count, tight) {
        // §4.5 branch 1 — Concept exists; many neighbours in one folder;
        // consider merging into the strongest neighbour gated by §4.5
        // (confidence ≥ 0.90 AND target's last-edited > 24h).
        (Resolution::Found { .. }, n, true) if n >= CREATE_FOLDER_CLUSTER_MIN_COUNT => {
            let folder_hits: Vec<&NeighbourHit> =
                hits.iter().filter(|h| h.folder == top_folder).collect();
            // Strongest neighbour = max cosine within the top folder.
            let strongest = folder_hits.iter().max_by(|a, b| {
                a.cosine
                    .partial_cmp(&b.cosine)
                    .unwrap_or(std::cmp::Ordering::Equal)
            });
            if let Some(s) = strongest {
                if s.cosine >= MERGE_CONFIDENCE_GATE
                    && s.last_edited_hours_ago > MERGE_STALENESS_HOURS
                {
                    return Some(RouteDecision::merge(
                        s.path.clone(),
                        s.cosine,
                        format!(
                            "variant_c merge: cos {:.3} >= {:.2}, staleness {}h > {}h",
                            s.cosine,
                            MERGE_CONFIDENCE_GATE,
                            s.last_edited_hours_ago,
                            MERGE_STALENESS_HOURS
                        ),
                    ));
                }
            }
            Some(RouteDecision::place(
                top_folder,
                VARIANT_C_PLACE_VIA_FOUND_CONFIDENCE,
                "variant_c place via found concept; merge gate not satisfied",
            ))
        }
        // §4.5 branch 2 — New concept; tight cluster of neighbours all
        // in one folder; no existing parent fits → propose create_folder.
        (Resolution::New, n, true)
            if n >= CREATE_FOLDER_CLUSTER_MIN_COUNT && parent_unfit(&top_folder) =>
        {
            // Plan §4.5: `let new_name = canonical.replace('_', "-");`
            // The canonicalizer already emits kebab-case, so this is a
            // defensive safety net for any '_' that snuck through (e.g.,
            // a manual_seed alias the user added).
            let new_name = canonical.replace('_', "-");
            Some(RouteDecision::create_folder(
                top_folder,
                new_name,
                VARIANT_C_CREATE_FOLDER_CONFIDENCE,
                "variant_c create_folder: new concept, tight cluster, no parent fits",
            ))
        }
        // §4.5 branch 3 — Otherwise place by neighbour majority (the
        // safe default). Floor confidence VARIANT_C_PLACE_VIA_MAJORITY.
        (_, n, _) if n >= CREATE_FOLDER_CLUSTER_MIN_COUNT => Some(RouteDecision::place(
            top_folder,
            VARIANT_C_PLACE_VIA_MAJORITY_CONFIDENCE,
            "variant_c place by neighbour majority",
        )),
        // No qualifying outcome — orchestrator advances to Variant D.
        _ => None,
    }
}

/// Group neighbour hits by folder, returning (folder_path, count) pairs.
fn group_by_folder(hits: &[NeighbourHit]) -> Vec<(String, usize)> {
    let mut counts: HashMap<String, usize> = HashMap::new();
    for h in hits {
        *counts.entry(h.folder.clone()).or_insert(0) += 1;
    }
    counts.into_iter().collect()
}

/// Plan §4.5 cluster-tight check: ≥CREATE_FOLDER_CLUSTER_MIN_COUNT
/// notes in `top_folder` AND every one has cosine
/// ≥CREATE_FOLDER_CLUSTER_COSINE.
fn cluster_tight(hits: &[NeighbourHit], top_folder: &str) -> bool {
    let folder_hits: Vec<&NeighbourHit> =
        hits.iter().filter(|h| h.folder == top_folder).collect();
    if folder_hits.len() < CREATE_FOLDER_CLUSTER_MIN_COUNT {
        return false;
    }
    folder_hits
        .iter()
        .all(|h| h.cosine >= CREATE_FOLDER_CLUSTER_COSINE)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::route::Action;
    use std::sync::Mutex;

    struct StubExtractor {
        result: Mutex<Result<Vec<Concept>, ExtractorError>>,
    }
    impl StubExtractor {
        fn returning(concepts: Vec<Concept>) -> Self {
            Self {
                result: Mutex::new(Ok(concepts)),
            }
        }
        fn failing() -> Self {
            Self {
                result: Mutex::new(Err(ExtractorError::Inference("stub".into()))),
            }
        }
    }
    #[async_trait]
    impl ConceptExtractor for StubExtractor {
        async fn extract(&self, _: &str) -> Result<Vec<Concept>, ExtractorError> {
            let g = self.result.lock().unwrap();
            match &*g {
                Ok(c) => Ok(c.clone()),
                Err(_) => Err(ExtractorError::Inference("stub".into())),
            }
        }
    }

    struct StubResolver(Resolution);
    #[async_trait]
    impl EntityResolver for StubResolver {
        async fn resolve(&self, _: &str) -> Resolution {
            self.0.clone()
        }
    }

    struct StubNeighbours(Vec<NeighbourHit>);
    #[async_trait]
    impl NeighbourFinder for StubNeighbours {
        async fn find(&self, _: &str, _: usize) -> Vec<NeighbourHit> {
            self.0.clone()
        }
    }

    fn hit(path: &str, folder: &str, cosine: f64, age_hours: u64) -> NeighbourHit {
        NeighbourHit {
            path: path.to_string(),
            folder: folder.to_string(),
            cosine,
            last_edited_hours_ago: age_hours,
        }
    }

    fn primary_concept(canonical: &str) -> Vec<Concept> {
        vec![Concept {
            canonical_name: canonical.to_string(),
            surface_form: canonical.to_string(),
        }]
    }

    #[tokio::test]
    async fn merge_when_found_tight_n3_and_strongest_satisfies_gate() {
        // §4.5 branch 1: Found + tight + n≥3 + strongest passes
        // (cos ≥0.90 AND age >24h).
        let extractor = StubExtractor::returning(primary_concept("checkpoint-gradient"));
        let resolver = StubResolver(Resolution::Found {
            concept_id: "c_4f2a".to_string(),
        });
        let neighbours = StubNeighbours(vec![
            hit("research/ml/a.md", "research/ml", 0.95, 48),
            hit("research/ml/b.md", "research/ml", 0.85, 100),
            hit("research/ml/c.md", "research/ml", 0.82, 72),
        ]);
        let r = try_concept_anchored(
            "rematerialization talk",
            &extractor,
            &resolver,
            &neighbours,
            |_| false,
        )
        .await;
        let d = r.expect("must merge");
        assert_eq!(d.action, Action::MergeIntoExistingNote);
        assert_eq!(d.target_note_path.as_deref(), Some("research/ml/a.md"));
        assert!(d.confidence >= MERGE_CONFIDENCE_GATE);
    }

    #[tokio::test]
    async fn place_via_found_when_merge_gate_staleness_fails() {
        // §4.5 branch 1 fallback: Found + tight + n≥3 but staleness
        // < 24h → place at 0.72 (not merge).
        let extractor = StubExtractor::returning(primary_concept("checkpoint-gradient"));
        let resolver = StubResolver(Resolution::Found {
            concept_id: "c_4f2a".to_string(),
        });
        let neighbours = StubNeighbours(vec![
            // Strongest is 0.95 cos but only 5h old — staleness gate fails.
            hit("research/ml/a.md", "research/ml", 0.95, 5),
            hit("research/ml/b.md", "research/ml", 0.85, 100),
            hit("research/ml/c.md", "research/ml", 0.82, 72),
        ]);
        let r = try_concept_anchored("x", &extractor, &resolver, &neighbours, |_| false).await;
        let d = r.expect("must place via found");
        assert_eq!(d.action, Action::Place);
        assert_eq!(d.folder_path.as_deref(), Some("research/ml"));
        assert_eq!(d.confidence, VARIANT_C_PLACE_VIA_FOUND_CONFIDENCE);
    }

    #[tokio::test]
    async fn place_via_found_when_merge_gate_confidence_fails() {
        // §4.5 branch 1 fallback: cos < 0.90 even though staleness > 24h.
        let extractor = StubExtractor::returning(primary_concept("checkpoint-gradient"));
        let resolver = StubResolver(Resolution::Found {
            concept_id: "c_4f2a".to_string(),
        });
        let neighbours = StubNeighbours(vec![
            // Strongest is only 0.85 cos — below 0.90 merge gate.
            hit("research/ml/a.md", "research/ml", 0.85, 100),
            hit("research/ml/b.md", "research/ml", 0.83, 72),
            hit("research/ml/c.md", "research/ml", 0.81, 200),
        ]);
        let r = try_concept_anchored("x", &extractor, &resolver, &neighbours, |_| false).await;
        let d = r.expect("must place via found");
        assert_eq!(d.action, Action::Place);
        assert_eq!(d.confidence, VARIANT_C_PLACE_VIA_FOUND_CONFIDENCE);
    }

    #[tokio::test]
    async fn create_folder_when_new_tight_n3_and_parent_unfit() {
        // §4.5 branch 2: New + tight + n≥3 + parent_unfit.
        // Note: canonicalizer alphabetically sorts tokens per §3.7
        // (canonical-name invariant), so "novel-concept" becomes
        // "concept-novel" — both surface forms map to the same key.
        let extractor = StubExtractor::returning(primary_concept("novel-concept"));
        let resolver = StubResolver(Resolution::New);
        let neighbours = StubNeighbours(vec![
            hit("research/ml/a.md", "research/ml", 0.85, 200),
            hit("research/ml/b.md", "research/ml", 0.82, 200),
            hit("research/ml/c.md", "research/ml", 0.80, 200),
        ]);
        let r = try_concept_anchored("x", &extractor, &resolver, &neighbours, |_| true).await;
        let d = r.expect("must create_folder");
        assert_eq!(d.action, Action::CreateFolder);
        assert_eq!(d.folder_path.as_deref(), Some("research/ml"));
        // Alphabetically sorted: "concept" < "novel".
        assert_eq!(d.new_folder_name.as_deref(), Some("concept-novel"));
        assert_eq!(d.confidence, VARIANT_C_CREATE_FOLDER_CONFIDENCE);
    }

    #[tokio::test]
    async fn place_majority_when_new_but_parent_fits() {
        // §4.5 branch 3 (safe default): New + n≥3 but parent fits →
        // place at 0.70.
        let extractor = StubExtractor::returning(primary_concept("novel-concept"));
        let resolver = StubResolver(Resolution::New);
        let neighbours = StubNeighbours(vec![
            hit("research/ml/a.md", "research/ml", 0.85, 200),
            hit("research/ml/b.md", "research/ml", 0.82, 200),
            hit("research/ml/c.md", "research/ml", 0.80, 200),
        ]);
        let r = try_concept_anchored("x", &extractor, &resolver, &neighbours, |_| false).await;
        let d = r.expect("must place by majority");
        assert_eq!(d.action, Action::Place);
        assert_eq!(d.folder_path.as_deref(), Some("research/ml"));
        assert_eq!(d.confidence, VARIANT_C_PLACE_VIA_MAJORITY_CONFIDENCE);
    }

    #[tokio::test]
    async fn place_majority_when_cluster_not_tight() {
        // §4.5 branch 3: tight=false but n≥3 → place by majority.
        let extractor = StubExtractor::returning(primary_concept("x"));
        let resolver = StubResolver(Resolution::Found {
            concept_id: "c".into(),
        });
        let neighbours = StubNeighbours(vec![
            // Cosines below 0.80 — cluster_tight returns false.
            hit("research/ml/a.md", "research/ml", 0.65, 200),
            hit("research/ml/b.md", "research/ml", 0.60, 200),
            hit("research/ml/c.md", "research/ml", 0.55, 200),
        ]);
        let r = try_concept_anchored("x", &extractor, &resolver, &neighbours, |_| false).await;
        let d = r.expect("must place by majority even when cluster not tight");
        assert_eq!(d.action, Action::Place);
        assert_eq!(d.confidence, VARIANT_C_PLACE_VIA_MAJORITY_CONFIDENCE);
    }

    #[tokio::test]
    async fn returns_none_when_count_below_threshold() {
        // n < 3 → None across all branches.
        let extractor = StubExtractor::returning(primary_concept("x"));
        let resolver = StubResolver(Resolution::Found {
            concept_id: "c".into(),
        });
        let neighbours = StubNeighbours(vec![
            hit("research/ml/a.md", "research/ml", 0.95, 100),
            hit("research/ml/b.md", "research/ml", 0.90, 100),
            // Only 2 hits in same folder.
        ]);
        let r = try_concept_anchored("x", &extractor, &resolver, &neighbours, |_| true).await;
        assert!(r.is_none());
    }

    #[tokio::test]
    async fn returns_none_when_no_neighbours() {
        let extractor = StubExtractor::returning(primary_concept("x"));
        let resolver = StubResolver(Resolution::New);
        let neighbours = StubNeighbours(vec![]);
        let r = try_concept_anchored("x", &extractor, &resolver, &neighbours, |_| true).await;
        assert!(r.is_none());
    }

    #[tokio::test]
    async fn returns_none_on_extractor_failure() {
        let extractor = StubExtractor::failing();
        let resolver = StubResolver(Resolution::New);
        let neighbours = StubNeighbours(vec![]);
        let r = try_concept_anchored("x", &extractor, &resolver, &neighbours, |_| true).await;
        assert!(r.is_none());
    }

    #[tokio::test]
    async fn returns_none_on_empty_capture_text() {
        let extractor = StubExtractor::returning(primary_concept("x"));
        let resolver = StubResolver(Resolution::New);
        let neighbours = StubNeighbours(vec![]);
        let r = try_concept_anchored("", &extractor, &resolver, &neighbours, |_| true).await;
        assert!(r.is_none());
    }

    #[tokio::test]
    async fn returns_none_when_extractor_returns_no_concepts() {
        let extractor = StubExtractor::returning(vec![]);
        let resolver = StubResolver(Resolution::New);
        let neighbours = StubNeighbours(vec![]);
        let r = try_concept_anchored("x", &extractor, &resolver, &neighbours, |_| true).await;
        assert!(r.is_none());
    }

    #[tokio::test]
    async fn returns_none_when_canonicalized_concept_is_empty() {
        // Concept with only stopwords canonicalizes to empty — Variant
        // C should None out.
        let extractor = StubExtractor::returning(vec![Concept {
            canonical_name: "the and or but".to_string(),
            surface_form: "the and or but".to_string(),
        }]);
        let resolver = StubResolver(Resolution::New);
        let neighbours = StubNeighbours(vec![hit("x", "x", 0.99, 200)]);
        let r = try_concept_anchored("x", &extractor, &resolver, &neighbours, |_| true).await;
        assert!(r.is_none());
    }

    #[tokio::test]
    async fn merge_does_not_fire_when_n_below_3_even_if_tight() {
        // n < CREATE_FOLDER_CLUSTER_MIN_COUNT → branch 1 doesn't match
        // → returns None (since branch 3 also requires n≥3).
        let extractor = StubExtractor::returning(primary_concept("x"));
        let resolver = StubResolver(Resolution::Found {
            concept_id: "c".into(),
        });
        let neighbours = StubNeighbours(vec![
            hit("research/ml/a.md", "research/ml", 0.95, 100),
            hit("research/ml/b.md", "research/ml", 0.92, 100),
        ]);
        let r = try_concept_anchored("x", &extractor, &resolver, &neighbours, |_| false).await;
        assert!(r.is_none());
    }

    #[test]
    fn cluster_tight_requires_min_count_and_all_above_threshold() {
        let hits = vec![
            hit("a", "f", 0.85, 1),
            hit("b", "f", 0.82, 1),
            hit("c", "f", 0.80, 1),
        ];
        assert!(cluster_tight(&hits, "f"));

        // One below threshold breaks tightness.
        let hits2 = vec![
            hit("a", "f", 0.85, 1),
            hit("b", "f", 0.82, 1),
            hit("c", "f", 0.79, 1),
        ];
        assert!(!cluster_tight(&hits2, "f"));

        // Below min count.
        let hits3 = vec![hit("a", "f", 0.95, 1), hit("b", "f", 0.92, 1)];
        assert!(!cluster_tight(&hits3, "f"));
    }

    #[test]
    fn group_by_folder_counts_correctly() {
        let hits = vec![
            hit("a", "research/ml", 0.9, 1),
            hit("b", "research/ml", 0.8, 1),
            hit("c", "engineering", 0.7, 1),
        ];
        let grouped = group_by_folder(&hits);
        let map: HashMap<_, _> = grouped.into_iter().collect();
        assert_eq!(map.get("research/ml"), Some(&2));
        assert_eq!(map.get("engineering"), Some(&1));
    }

    #[test]
    fn variant_c_branch_confidence_constants_match_plan_4_5_literal() {
        // Plan §4.5: place via found = 0.72, create_folder = 0.71,
        // place by majority = 0.70.
        assert_eq!(VARIANT_C_PLACE_VIA_FOUND_CONFIDENCE, 0.72);
        assert_eq!(VARIANT_C_CREATE_FOLDER_CONFIDENCE, 0.71);
        assert_eq!(VARIANT_C_PLACE_VIA_MAJORITY_CONFIDENCE, 0.70);
        // All three above the floor (which is also 0.70).
        assert!(VARIANT_C_PLACE_VIA_FOUND_CONFIDENCE >= super::super::VARIANT_C_FLOOR);
        assert!(VARIANT_C_CREATE_FOLDER_CONFIDENCE >= super::super::VARIANT_C_FLOOR);
        assert!(VARIANT_C_PLACE_VIA_MAJORITY_CONFIDENCE >= super::super::VARIANT_C_FLOOR);
    }
}
