//! N-way Hybrid retrieval via RRF fusion.
//!
//! [`HybridRetriever`](super::hybrid::HybridRetriever) fuses exactly two
//! inner retrievers (the canonical Lexical + Semantic shape). For
//! Lexical + Semantic + Recency triple-fusion (and beyond), this module
//! ships [`HybridRetrieverN`] — a homogeneous-typed wrapper around an
//! arbitrary `Vec<Box<dyn EidosRetriever>>` that RRF-fuses every inner
//! retriever's ranking under the same manifest.
//!
//! All design properties of the 2-way Hybrid hold here:
//!
//! - Every inner retriever **must** share `manifest_id`. Mismatch =
//!   construction error.
//! - Documents present in multiple inner rankings dedup to ONE hit; the
//!   fused source_id is `{doc_id}::hybrid` (same chunk-id shape as
//!   2-way Hybrid — the closed-citation set is per-packet so collisions
//!   across retrievers of different arities are irrelevant).
//! - RRF uses `k = RRF_K_DEFAULT = 60` by default, matching the
//!   epistemos-shadow + Swift mirror constant. `with_k` overrides.
//! - Confidence is normalized to `[0, 1]` so the chat layer can compare
//!   hybrid_n confidences against other modes' confidences directly.
//!   For N inner rankings, the rank-1-in-every-ranking ceiling is
//!   `N / (k + 1)`.

use std::collections::BTreeMap;

use super::hybrid::RRF_K_DEFAULT;
use super::retriever::EidosRetriever;
use super::types::{
    EidosChunkId, EidosContextPacket, EidosDocumentId, EidosHit, EidosIndexManifestId,
    EidosProvenance, EidosQuery, EidosRetrievalMode, EidosScoreComponents, EidosSourceKind,
    EidosSpan,
};

#[derive(Debug, thiserror::Error, PartialEq)]
pub enum HybridNConstructionError {
    /// HybridRetrieverN with zero inner retrievers makes no sense — the
    /// fused packet would always be empty regardless of query.
    #[error("HybridRetrieverN requires at least one inner retriever; got empty list")]
    EmptyRetrievers,

    /// All inner retrievers must share the same manifest snapshot. The
    /// error names which position in the input slice deviated.
    #[error(
        "HybridRetrieverN requires all retrievers to share manifest_id; \
         retriever at index {index} has manifest {got:?}, expected {expected:?}"
    )]
    ManifestMismatch {
        index: usize,
        expected: EidosIndexManifestId,
        got: EidosIndexManifestId,
    },
}

/// Holds the per-document accumulator while walking each inner ranking.
struct NAccumulator {
    document_id: EidosDocumentId,
    kind: EidosSourceKind,
    span: Option<EidosSpan>,
    score: EidosScoreComponents,
    rrf: f32,
}

/// N-way RRF Hybrid retriever. Holds a list of inner retrievers (any
/// implementation of `EidosRetriever`) and fuses their rankings by
/// reciprocal rank.
pub struct HybridRetrieverN {
    inner: Vec<Box<dyn EidosRetriever>>,
    manifest_id: EidosIndexManifestId,
    k: u32,
}

impl std::fmt::Debug for HybridRetrieverN {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        // `dyn EidosRetriever` isn't Debug, so render the per-retriever mode
        // + manifest summary instead of the full struct.
        f.debug_struct("HybridRetrieverN")
            .field("manifest_id", &self.manifest_id)
            .field("k", &self.k)
            .field(
                "inner_modes",
                &self.inner.iter().map(|r| r.mode()).collect::<Vec<_>>(),
            )
            .finish()
    }
}

impl HybridRetrieverN {
    /// Construct from a `Vec` of boxed retrievers. Returns
    /// [`HybridNConstructionError::EmptyRetrievers`] if the list is empty
    /// or [`HybridNConstructionError::ManifestMismatch`] on the first
    /// retriever whose manifest_id differs from index 0's.
    pub fn new(
        inner: Vec<Box<dyn EidosRetriever>>,
    ) -> Result<Self, HybridNConstructionError> {
        let first = inner
            .first()
            .ok_or(HybridNConstructionError::EmptyRetrievers)?;
        let manifest_id = first.manifest_id().clone();
        for (index, r) in inner.iter().enumerate().skip(1) {
            if r.manifest_id() != &manifest_id {
                return Err(HybridNConstructionError::ManifestMismatch {
                    index,
                    expected: manifest_id,
                    got: r.manifest_id().clone(),
                });
            }
        }
        Ok(Self {
            inner,
            manifest_id,
            k: RRF_K_DEFAULT,
        })
    }

    pub fn with_k(mut self, k: u32) -> Self {
        self.k = k;
        self
    }

    pub fn k(&self) -> u32 {
        self.k
    }

    /// Number of inner retrievers being fused.
    pub fn inner_len(&self) -> usize {
        self.inner.len()
    }
}

impl EidosRetriever for HybridRetrieverN {
    fn mode(&self) -> EidosRetrievalMode {
        EidosRetrievalMode::Hybrid
    }

    fn manifest_id(&self) -> &EidosIndexManifestId {
        &self.manifest_id
    }

    fn retrieve(
        &self,
        query: &EidosQuery,
        retrieved_at_unix_ms: u64,
    ) -> EidosContextPacket {
        let k = self.k as f32;
        let n = self.inner.len() as f32;
        let mut acc: BTreeMap<EidosDocumentId, NAccumulator> = BTreeMap::new();

        for inner in &self.inner {
            let packet = inner.retrieve(query, retrieved_at_unix_ms);
            for (rank, hit) in packet.hits.iter().enumerate() {
                let rrf_contribution = 1.0 / (k + (rank + 1) as f32);
                let entry = acc.entry(hit.document_id.clone()).or_insert_with(|| {
                    NAccumulator {
                        document_id: hit.document_id.clone(),
                        kind: hit.kind,
                        span: hit.span,
                        score: EidosScoreComponents::default(),
                        rrf: 0.0,
                    }
                });
                entry.rrf += rrf_contribution;
                if entry.span.is_none() {
                    entry.span = hit.span;
                }
                // Max-merge per-component scores from whatever the inner
                // retriever populated. Lexical retrievers leave semantic=0
                // etc., so max-merge accumulates each signal without
                // double-counting.
                entry.score.lexical = entry.score.lexical.max(hit.score.lexical);
                entry.score.semantic = entry.score.semantic.max(hit.score.semantic);
                entry.score.recency = entry.score.recency.max(hit.score.recency);
                entry.score.graph = entry.score.graph.max(hit.score.graph);
            }
        }

        // Normalize confidence to [0, 1]: rank-1 in every ranking gives
        // raw RRF = N / (k + 1).
        let max_rrf = n / (k + 1.0);

        let mut scored: Vec<NAccumulator> = acc.into_values().collect();
        scored.sort_by(|a, b| {
            b.rrf
                .partial_cmp(&a.rrf)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then_with(|| a.document_id.as_str().cmp(b.document_id.as_str()))
        });

        let top_k = query.top_k as usize;
        let hits: Vec<EidosHit> = scored
            .into_iter()
            .take(top_k)
            .map(|a| {
                let chunk_id = EidosChunkId::new(format!("{}::hybrid", a.document_id.as_str()))
                    .expect("document_id non-empty by construction");
                let confidence = if max_rrf > 0.0 {
                    (a.rrf / max_rrf).clamp(0.0, 1.0)
                } else {
                    0.0
                };
                EidosHit {
                    source_id: chunk_id,
                    document_id: a.document_id,
                    kind: a.kind,
                    span: a.span,
                    confidence,
                    score: a.score,
                    provenance: EidosProvenance {
                        manifest_id: self.manifest_id.clone(),
                        mode: EidosRetrievalMode::Hybrid,
                        retrieved_at_unix_ms,
                    },
                }
            })
            .collect();

        EidosContextPacket {
            query: query.clone(),
            manifest_id: self.manifest_id.clone(),
            hits,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::eidos::lexical::InMemoryLexicalIndex;
    use crate::eidos::recency::InMemoryRecencyIndex;
    use crate::eidos::semantic::InMemorySemanticIndex;
    use crate::eidos::types::EidosCitation;

    fn manifest() -> EidosIndexManifestId {
        EidosIndexManifestId::new("hybrid-n-manifest").unwrap()
    }

    fn other_manifest() -> EidosIndexManifestId {
        EidosIndexManifestId::new("OTHER").unwrap()
    }

    fn doc(id: &str) -> EidosDocumentId {
        EidosDocumentId::new(id).unwrap()
    }

    const T0: u64 = 1_700_000_000_000;
    const ONE_DAY: u64 = 86_400_000;

    fn build_lex() -> InMemoryLexicalIndex {
        let mut lex = InMemoryLexicalIndex::new(manifest());
        lex.insert(doc("trio"), "alpha tropical", EidosSourceKind::Note).unwrap();
        lex.insert(doc("lex-only"), "tropical", EidosSourceKind::Note).unwrap();
        lex
    }

    fn build_sem() -> InMemorySemanticIndex {
        let mut sem = InMemorySemanticIndex::new(manifest(), 2);
        sem.insert(doc("trio"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();
        sem.insert(doc("sem-only"), vec![0.9, 0.1], EidosSourceKind::Note).unwrap();
        sem
    }

    fn build_recency() -> InMemoryRecencyIndex {
        // Both docs contain "tropical" so the substring filter doesn't drop
        // recency-only; the recency retriever's value-add over lexical here
        // is the time-ordering, not the filtering.
        let mut r = InMemoryRecencyIndex::new(manifest());
        r.insert(doc("trio"), "alpha tropical", T0, EidosSourceKind::Note);
        r.insert(
            doc("recency-only"),
            "fresh tropical content",
            T0 - ONE_DAY,
            EidosSourceKind::Note,
        );
        r
    }

    #[test]
    fn three_way_fusion_surfaces_all_unique_documents() {
        let h = HybridRetrieverN::new(vec![
            Box::new(build_lex()),
            Box::new(build_sem()),
            Box::new(build_recency()),
        ])
        .unwrap();
        assert_eq!(h.inner_len(), 3);

        let q = EidosQuery::with_vector("tropical", EidosRetrievalMode::Hybrid, 16, vec![1.0, 0.0]);
        let packet = h.retrieve(&q, T0);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.document_id.as_str()).collect();
        // All four unique documents surface (trio is shared across all three).
        assert!(ids.contains(&"trio"));
        assert!(ids.contains(&"lex-only"));
        assert!(ids.contains(&"sem-only"));
        assert!(ids.contains(&"recency-only"));
    }

    #[test]
    fn doc_in_all_three_outranks_doc_in_only_one() {
        let h = HybridRetrieverN::new(vec![
            Box::new(build_lex()),
            Box::new(build_sem()),
            Box::new(build_recency()),
        ])
        .unwrap();
        let q = EidosQuery::with_vector("tropical", EidosRetrievalMode::Hybrid, 16, vec![1.0, 0.0]);
        let packet = h.retrieve(&q, T0);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.document_id.as_str()).collect();
        let trio_pos = ids.iter().position(|s| *s == "trio").unwrap();
        let lex_only_pos = ids.iter().position(|s| *s == "lex-only").unwrap();
        assert!(
            trio_pos < lex_only_pos,
            "trio (in all 3) should outrank lex-only (in 1)"
        );
    }

    #[test]
    fn three_way_fusion_aggregates_score_components_per_mode() {
        let h = HybridRetrieverN::new(vec![
            Box::new(build_lex()),
            Box::new(build_sem()),
            Box::new(build_recency()),
        ])
        .unwrap();
        let q = EidosQuery::with_vector("tropical", EidosRetrievalMode::Hybrid, 16, vec![1.0, 0.0]);
        let packet = h.retrieve(&q, T0);
        let trio_hit = packet
            .hits
            .iter()
            .find(|h| h.document_id.as_str() == "trio")
            .expect("trio in fusion output");
        // trio is in all three inner rankings; its component scores all
        // populate from the respective sources.
        assert!(trio_hit.score.lexical > 0.0);
        assert!(trio_hit.score.semantic > 0.0);
        assert!(trio_hit.score.recency > 0.0);
    }

    #[test]
    fn empty_retriever_list_errors_at_construction() {
        let err = HybridRetrieverN::new(vec![]).unwrap_err();
        assert_eq!(err, HybridNConstructionError::EmptyRetrievers);
    }

    #[test]
    fn manifest_mismatch_errors_with_offending_index() {
        let lex = InMemoryLexicalIndex::new(manifest());
        // Index 0 has manifest=manifest()
        // Index 1 has manifest=other_manifest() — should trigger error.
        let sem = InMemorySemanticIndex::new(other_manifest(), 2);
        let err = HybridRetrieverN::new(vec![Box::new(lex), Box::new(sem)]).unwrap_err();
        match err {
            HybridNConstructionError::ManifestMismatch {
                index,
                expected,
                got,
            } => {
                assert_eq!(index, 1);
                assert_eq!(expected, manifest());
                assert_eq!(got, other_manifest());
            }
            _ => panic!("expected ManifestMismatch, got {err:?}"),
        }
    }

    #[test]
    fn single_inner_retriever_passes_through() {
        // N=1 is degenerate but valid. The fused output should mirror the
        // inner retriever's hits (with chunk_id rewritten to ::hybrid and
        // RRF normalized).
        let h = HybridRetrieverN::new(vec![Box::new(build_lex())]).unwrap();
        let q = EidosQuery::new("tropical", EidosRetrievalMode::Hybrid, 16);
        let packet = h.retrieve(&q, T0);
        assert!(!packet.hits.is_empty());
        // Every hit's chunk_id is "{doc_id}::hybrid" not "::lex".
        for hit in &packet.hits {
            assert!(hit.source_id.as_str().ends_with("::hybrid"));
        }
    }

    #[test]
    fn single_inner_retriever_preserves_count_score_and_saturates_top_confidence() {
        // Tightens `single_inner_retriever_passes_through` with three
        // additional invariants the existing pin doesn't reach:
        //
        //   1. Hit-count parity: fused-packet.hits.len() equals the
        //      inner Lex's direct .hits.len() (no docs dropped through
        //      the N=1 fold).
        //   2. score.lexical pass-through: every fused hit carries the
        //      inner Lex's lexical score exactly (no normalization
        //      side-effect on the per-mode score component).
        //   3. Top-1 confidence saturates to 1.0 at N=1: `max_rrf =
        //      N / (k+1) = 1/(k+1)` and the top hit's contribution is
        //      also `1/(k+1)`, so `confidence = 1.0` exactly. A future
        //      change that altered the max_rrf normalization formula
        //      surfaces here.
        let inner = build_lex();
        let q = EidosQuery::new("tropical", EidosRetrievalMode::Hybrid, 16);

        // Direct retrieval against the inner backend (Lexical mode is
        // accepted because Lex.retrieve doesn't inspect query.mode).
        let inner_packet = inner.retrieve(&q, T0);

        // Hybrid_N N=1 fold.
        let h = HybridRetrieverN::new(vec![Box::new(build_lex())]).unwrap();
        let fused = h.retrieve(&q, T0);

        assert_eq!(
            fused.hits.len(),
            inner_packet.hits.len(),
            "N=1 fold must preserve hit count",
        );

        // Build a doc_id → lexical_score map from the inner packet so
        // we can cross-check per-doc score pass-through regardless of
        // fold reordering.
        let inner_scores: std::collections::HashMap<&str, f32> = inner_packet
            .hits
            .iter()
            .map(|h| (h.document_id.as_str(), h.score.lexical))
            .collect();

        for hit in &fused.hits {
            let inner_lex = inner_scores
                .get(hit.document_id.as_str())
                .copied()
                .unwrap_or_else(|| panic!("fused doc {} not in inner packet", hit.document_id.as_str()));
            assert!(
                (hit.score.lexical - inner_lex).abs() < 1e-6,
                "score.lexical pass-through drift on {}: fused {} vs inner {}",
                hit.document_id.as_str(),
                hit.score.lexical,
                inner_lex,
            );
        }

        // Top-1 confidence saturates at 1.0 because max_rrf = N/(k+1)
        // and top contribution = 1/(k+1) → ratio = 1.0 exactly.
        let top = &fused.hits[0];
        assert!(
            (top.confidence - 1.0).abs() < 1e-6,
            "N=1 top hit confidence should saturate to 1.0; got {}",
            top.confidence
        );
    }

    #[test]
    fn closed_citation_contract_holds_through_hybrid_n() {
        let h = HybridRetrieverN::new(vec![
            Box::new(build_lex()),
            Box::new(build_sem()),
            Box::new(build_recency()),
        ])
        .unwrap();
        let q = EidosQuery::with_vector("tropical", EidosRetrievalMode::Hybrid, 16, vec![1.0, 0.0]);
        let packet = h.retrieve(&q, T0);
        for hit in &packet.hits {
            let cite = EidosCitation {
                source_id: hit.source_id.clone(),
                manifest_id: packet.manifest_id.clone(),
            };
            assert_eq!(packet.validate_citation(&cite), Ok(()));
        }
        // A pre-fusion id ("trio::lex") is NOT citable through the
        // hybrid_n packet — only "trio::hybrid" is.
        let pre_fusion = EidosCitation {
            source_id: EidosChunkId::new("trio::lex").unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert!(packet.validate_citation(&pre_fusion).is_err());
    }

    #[test]
    fn retriever_advertises_hybrid_mode_and_default_k() {
        let h = HybridRetrieverN::new(vec![Box::new(build_lex())]).unwrap();
        assert_eq!(h.mode(), EidosRetrievalMode::Hybrid);
        assert_eq!(h.k(), 60);
        assert_eq!(h.manifest_id(), &manifest());
    }

    #[test]
    fn with_k_overrides_default() {
        let h = HybridRetrieverN::new(vec![Box::new(build_lex())])
            .unwrap()
            .with_k(10);
        assert_eq!(h.k(), 10);
    }

    #[test]
    fn confidence_is_normalized_into_unit_interval() {
        let h = HybridRetrieverN::new(vec![
            Box::new(build_lex()),
            Box::new(build_sem()),
            Box::new(build_recency()),
        ])
        .unwrap();
        let q = EidosQuery::with_vector("tropical", EidosRetrievalMode::Hybrid, 16, vec![1.0, 0.0]);
        let packet = h.retrieve(&q, T0);
        for hit in &packet.hits {
            assert!(hit.confidence >= 0.0 && hit.confidence <= 1.0);
        }
    }

    #[test]
    fn top_k_truncates_hybrid_n_output() {
        let h = HybridRetrieverN::new(vec![
            Box::new(build_lex()),
            Box::new(build_sem()),
            Box::new(build_recency()),
        ])
        .unwrap();
        let q = EidosQuery::with_vector("tropical", EidosRetrievalMode::Hybrid, 1, vec![1.0, 0.0]);
        let packet = h.retrieve(&q, T0);
        assert_eq!(packet.hits.len(), 1);
        // top-1 must be "trio" since it appears in all three inner
        // rankings (highest RRF).
        assert_eq!(packet.hits[0].document_id.as_str(), "trio");
    }

    #[test]
    fn rrf_tie_break_is_document_id_ascending() {
        // Symmetric to hybrid.rs's `rrf_tie_break_is_document_id_ascending`
        // (iter 77) for the N-way fusion path. The hybrid_n sort key is
        // identical — `(rrf desc, document_id asc)` — but the N-way
        // fold goes through a different code path. Pin the tie-break
        // directly so a future descending-tie or insertion-order
        // regression in the N-way fold fires here.
        //
        // Build inner retrievers where two docs each land at rank 1 in
        // exactly one different backend:
        //   - "z-doc" matches the lexical needle "needle".
        //   - "a-doc" matches the semantic vector.
        // Each accumulates rrf = 1/(k+1) from exactly one inner — tied
        // RRF, distinct doc_ids. Alphabetic asc must order ["a-doc",
        // "z-doc"].
        let mut lex = InMemoryLexicalIndex::new(manifest());
        lex.insert(doc("z-doc"), "needle", EidosSourceKind::Note).unwrap();
        let mut sem = InMemorySemanticIndex::new(manifest(), 2);
        sem.insert(doc("a-doc"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();

        let h = HybridRetrieverN::new(vec![Box::new(lex), Box::new(sem)]).unwrap();
        let q = EidosQuery::with_vector(
            "needle",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0, 0.0],
        );
        let packet = h.retrieve(&q, T0);

        let order: Vec<&str> = packet
            .hits
            .iter()
            .map(|h| h.document_id.as_str())
            .collect();
        assert_eq!(
            order,
            vec!["a-doc", "z-doc"],
            "N-way tied RRF must break by document_id ascending"
        );

        // Sanity-pin the tie scenario actually occurred: confidence
        // values within f32 epsilon. The N-way path's `max_rrf =
        // N / (k + 1)` (where N is inner_len) gives the same ratio
        // for both single-contributor docs, so they should be near-
        // identical.
        let delta = (packet.hits[0].confidence - packet.hits[1].confidence).abs();
        assert!(
            delta < 1e-6,
            "tie-break implies near-equal confidence; got delta = {delta}"
        );
    }
}
