//! Deterministic implementations of the Variant C provider traits
//! (`ConceptExtractor`, `EntityResolver`, `NeighbourFinder`). Same
//! No-LLM-First discipline as `variant_b_classifiers` — every variant
//! ladder must start with a deterministic predecessor before escalating
//! to an LLM. Without these, Variant C has no host wiring and the
//! production code path is unreachable.
//!
//! Three implementations:
//!
//! 1. `KeywordConceptExtractor` — pure deterministic. Tokenises the
//!    capture text + emits the most frequent stems as concepts. Reuses
//!    the same tokeniser shape as Variant B for behavioural consistency.
//!
//! 2. `InMemoryEntityResolver` — pure deterministic. Resolves against
//!    a `Vec<String>` of known canonical concept names. Returns
//!    `Found{...}` if the canonical name is in the set, else `New`.
//!
//! 3. `InMemoryNeighbourFinder` — pure deterministic. Holds a
//!    pre-indexed `Vec<NeighbourHit>` and ranks by `cosine` (descending)
//!    against the supplied query. Real cosine similarity is not
//!    computed — the index is treated as already-scored. This is the
//!    bridge surface a future HNSW-backed implementation slots in
//!    behind without changing the trait contract.
//!
//! Determinism contract: all three implementations are pure functions
//! of their input. The `InMemoryEntityResolver` and `InMemoryNeighbourFinder`
//! use sorted internal storage so iteration order is replayable.

use std::collections::BTreeMap;

use async_trait::async_trait;

use super::variant_c::{
    Concept, ConceptExtractor, EntityResolver, ExtractorError, NeighbourFinder, NeighbourHit,
    Resolution,
};
use crate::canon;

// ── KeywordConceptExtractor ───────────────────────────────────────────────

/// Extracts up to `max_concepts` deterministic concepts from the capture
/// text. Each concept is the canonicalised form of a high-frequency
/// stem from the input. The output is sorted by descending frequency
/// then ascending canonical name so ties resolve deterministically.
#[derive(Debug, Clone)]
pub struct KeywordConceptExtractor {
    pub max_concepts: usize,
    pub min_token_length: usize,
}

impl Default for KeywordConceptExtractor {
    fn default() -> Self {
        Self {
            max_concepts: 5,
            min_token_length: 4,
        }
    }
}

#[async_trait]
impl ConceptExtractor for KeywordConceptExtractor {
    async fn extract(&self, text: &str) -> Result<Vec<Concept>, ExtractorError> {
        if text.trim().is_empty() {
            return Ok(Vec::new());
        }
        let mut counts: BTreeMap<String, usize> = BTreeMap::new();
        for token in text
            .to_lowercase()
            .split(|c: char| !c.is_alphanumeric())
            .filter(|t| t.len() >= self.min_token_length)
        {
            *counts.entry(token.to_string()).or_insert(0) += 1;
        }
        // Sort by (count desc, canonical name asc) for deterministic
        // tie-breaking. BTreeMap iteration is already alphabetical.
        let mut entries: Vec<(String, usize)> = counts.into_iter().collect();
        entries.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
        Ok(entries
            .into_iter()
            .take(self.max_concepts)
            .map(|(stem, _count)| {
                let canonical = canon::canonicalize(&stem);
                Concept {
                    canonical_name: if canonical.is_empty() { stem.clone() } else { canonical },
                    surface_form: stem,
                }
            })
            .collect())
    }
}

// ── InMemoryEntityResolver ────────────────────────────────────────────────

/// Resolves canonical concept names against a sorted internal set.
/// `Found { concept_id: name }` if the name is present, else `New`.
/// Storage is `Vec<String>` (sorted + deduped at construction) so
/// `binary_search` keeps lookup O(log n) without any iteration order
/// drift.
#[derive(Debug, Clone, Default)]
pub struct InMemoryEntityResolver {
    known: Vec<String>,
}

impl InMemoryEntityResolver {
    pub fn new<I, S>(names: I) -> Self
    where
        I: IntoIterator<Item = S>,
        S: Into<String>,
    {
        let mut known: Vec<String> = names.into_iter().map(Into::into).collect();
        known.sort();
        known.dedup();
        Self { known }
    }

    /// Add a canonical concept name. Idempotent — re-adding is a no-op.
    pub fn upsert(&mut self, name: impl Into<String>) {
        let name = name.into();
        if let Err(insert_at) = self.known.binary_search(&name) {
            self.known.insert(insert_at, name);
        }
    }

    pub fn known_count(&self) -> usize {
        self.known.len()
    }
}

#[async_trait]
impl EntityResolver for InMemoryEntityResolver {
    async fn resolve(&self, canonical_name: &str) -> Resolution {
        match self.known.binary_search(&canonical_name.to_string()) {
            Ok(_) => Resolution::Found {
                concept_id: canonical_name.to_string(),
            },
            Err(_) => Resolution::New,
        }
    }
}

// ── InMemoryNeighbourFinder ──────────────────────────────────────────────

/// Holds a pre-indexed `Vec<NeighbourHit>` (already-scored) and ranks
/// by descending `cosine` against the supplied query. This is the
/// scaffold a future HNSW-backed `NeighbourFinder` (Tantivy + usearch
/// per `epistemos-shadow`) plugs in behind without changing the trait
/// surface.
///
/// Why no real cosine compute: the trait's `query: &str` parameter
/// implies the implementation embeds the query against the same vector
/// space as the index. That requires the embedding service which lives
/// in the Swift host (MLX / Core ML). Until the host wiring lands,
/// callers feed pre-scored hits to this provider so the route pipeline
/// has a deterministic backstop.
#[derive(Debug, Clone, Default)]
pub struct InMemoryNeighbourFinder {
    hits: Vec<NeighbourHit>,
}

impl InMemoryNeighbourFinder {
    pub fn new(hits: impl IntoIterator<Item = NeighbourHit>) -> Self {
        let mut hits: Vec<NeighbourHit> = hits.into_iter().collect();
        hits.sort_by(|a, b| {
            b.cosine
                .partial_cmp(&a.cosine)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then_with(|| a.path.cmp(&b.path))
        });
        Self { hits }
    }

    pub fn replace(&mut self, hits: impl IntoIterator<Item = NeighbourHit>) {
        *self = Self::new(hits);
    }
}

#[async_trait]
impl NeighbourFinder for InMemoryNeighbourFinder {
    async fn find(&self, _query: &str, k: usize) -> Vec<NeighbourHit> {
        self.hits.iter().take(k).cloned().collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn keyword_concept_extractor_returns_top_stems_in_deterministic_order() {
        let extractor = KeywordConceptExtractor::default();
        let concepts = extractor
            .extract("rust rust agent loop loop loop refactor refactor")
            .await
            .expect("ok");
        assert!(!concepts.is_empty());
        // "loop" appears 3 times so it must be first by frequency
        assert_eq!(concepts[0].surface_form, "loop");
        // re-running is byte-identical
        let again = extractor
            .extract("rust rust agent loop loop loop refactor refactor")
            .await
            .expect("ok");
        assert_eq!(concepts, again);
    }

    #[tokio::test]
    async fn keyword_concept_extractor_returns_empty_for_blank_input() {
        let extractor = KeywordConceptExtractor::default();
        let concepts = extractor.extract("   ").await.expect("ok");
        assert!(concepts.is_empty());
    }

    #[tokio::test]
    async fn in_memory_entity_resolver_finds_known_names() {
        let resolver = InMemoryEntityResolver::new(vec!["rust", "agent", "loop"]);
        match resolver.resolve("agent").await {
            Resolution::Found { concept_id } => assert_eq!(concept_id, "agent"),
            Resolution::New => panic!("expected Found"),
        }
    }

    #[tokio::test]
    async fn in_memory_entity_resolver_returns_new_for_unknown() {
        let resolver = InMemoryEntityResolver::new(vec!["rust"]);
        match resolver.resolve("python").await {
            Resolution::Found { .. } => panic!("expected New"),
            Resolution::New => {}
        }
    }

    #[tokio::test]
    async fn in_memory_entity_resolver_upsert_is_idempotent() {
        let mut resolver = InMemoryEntityResolver::new(vec!["rust"]);
        let before = resolver.known_count();
        resolver.upsert("rust");
        resolver.upsert("rust");
        assert_eq!(resolver.known_count(), before);
        resolver.upsert("python");
        assert_eq!(resolver.known_count(), before + 1);
    }

    #[tokio::test]
    async fn in_memory_neighbour_finder_ranks_by_descending_cosine() {
        let finder = InMemoryNeighbourFinder::new(vec![
            NeighbourHit {
                path: "research/a.md".into(),
                folder: "research".into(),
                cosine: 0.6,
                last_edited_hours_ago: 5,
            },
            NeighbourHit {
                path: "research/b.md".into(),
                folder: "research".into(),
                cosine: 0.9,
                last_edited_hours_ago: 5,
            },
            NeighbourHit {
                path: "code/c.md".into(),
                folder: "code".into(),
                cosine: 0.7,
                last_edited_hours_ago: 5,
            },
        ]);
        let top3 = finder.find("anything", 3).await;
        assert_eq!(top3.len(), 3);
        assert_eq!(top3[0].cosine, 0.9);
        assert_eq!(top3[1].cosine, 0.7);
        assert_eq!(top3[2].cosine, 0.6);
    }

    #[tokio::test]
    async fn in_memory_neighbour_finder_clamps_k_to_available_hits() {
        let finder = InMemoryNeighbourFinder::new(vec![NeighbourHit {
            path: "a.md".into(),
            folder: "x".into(),
            cosine: 0.5,
            last_edited_hours_ago: 1,
        }]);
        let hits = finder.find("anything", 99).await;
        assert_eq!(hits.len(), 1);
    }

    #[tokio::test]
    async fn in_memory_neighbour_finder_iterates_deterministically_on_cosine_ties() {
        let finder = InMemoryNeighbourFinder::new(vec![
            NeighbourHit {
                path: "z.md".into(),
                folder: "y".into(),
                cosine: 0.5,
                last_edited_hours_ago: 1,
            },
            NeighbourHit {
                path: "a.md".into(),
                folder: "x".into(),
                cosine: 0.5,
                last_edited_hours_ago: 1,
            },
        ]);
        let hits = finder.find("q", 2).await;
        // tie-broken by path ascending
        assert_eq!(hits[0].path, "a.md");
        assert_eq!(hits[1].path, "z.md");
    }
}
