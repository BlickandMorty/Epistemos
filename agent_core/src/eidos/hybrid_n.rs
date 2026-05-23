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
    is_blank_query_text, EidosChunkId, EidosContextPacket, EidosDocumentId, EidosHit,
    EidosIndexManifestId, EidosProvenance, EidosQuery, EidosRetrievalMode,
    EidosScoreComponents, EidosSourceKind, EidosSpan,
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
        if is_blank_query_text(&query.text) || query.top_k == 0 {
            return EidosContextPacket {
                query: query.clone(),
                manifest_id: self.manifest_id.clone(),
                hits: vec![],
            };
        }

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

    struct BlankLeakingRetriever {
        manifest_id: EidosIndexManifestId,
        document_id: EidosDocumentId,
    }

    impl EidosRetriever for BlankLeakingRetriever {
        fn mode(&self) -> EidosRetrievalMode {
            EidosRetrievalMode::Lexical
        }

        fn manifest_id(&self) -> &EidosIndexManifestId {
            &self.manifest_id
        }

        fn retrieve(
            &self,
            query: &EidosQuery,
            retrieved_at_unix_ms: u64,
        ) -> EidosContextPacket {
            EidosContextPacket {
                query: query.clone(),
                manifest_id: self.manifest_id.clone(),
                hits: vec![EidosHit {
                    source_id: EidosChunkId::new(format!("{}::lex", self.document_id.as_str()))
                        .unwrap(),
                    document_id: self.document_id.clone(),
                    kind: EidosSourceKind::Note,
                    span: None,
                    confidence: 1.0,
                    score: EidosScoreComponents {
                        lexical: 1.0,
                        semantic: 0.0,
                        recency: 0.0,
                        graph: 0.0,
                    },
                    provenance: EidosProvenance {
                        manifest_id: self.manifest_id.clone(),
                        mode: EidosRetrievalMode::Lexical,
                        retrieved_at_unix_ms,
                    },
                }],
            }
        }
    }

    #[test]
    fn blank_query_defers_before_n_way_fusion_even_if_inner_leaks() {
        let h = HybridRetrieverN::new(vec![
            Box::new(BlankLeakingRetriever {
                manifest_id: manifest(),
                document_id: doc("a-leak"),
            }),
            Box::new(BlankLeakingRetriever {
                manifest_id: manifest(),
                document_id: doc("b-leak"),
            }),
        ])
        .unwrap();
        let q = EidosQuery::new("   ", EidosRetrievalMode::Hybrid, 16);
        let packet = h.retrieve(&q, T0);
        assert!(
            packet.hits.is_empty(),
            "Hybrid_N must fail closed on blank query before fusing inner hits"
        );
    }

    #[test]
    fn invisible_only_query_defers_before_n_way_fusion_even_if_inner_leaks() {
        let h = HybridRetrieverN::new(vec![
            Box::new(BlankLeakingRetriever {
                manifest_id: manifest(),
                document_id: doc("a-leak"),
            }),
            Box::new(BlankLeakingRetriever {
                manifest_id: manifest(),
                document_id: doc("b-leak"),
            }),
        ])
        .unwrap();
        let q = EidosQuery::new("\u{200B}", EidosRetrievalMode::Hybrid, 16);
        let packet = h.retrieve(&q, T0);
        assert!(
            packet.hits.is_empty(),
            "Hybrid_N must fail closed on invisible-only query before fusing inner hits"
        );
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
    fn hybrid_n_n4_saturation_doc_rank_1_in_all_inners_yields_confidence_one() {
        // Extends iter 116's N=3 saturation to N=4. With N=4 inner
        // retrievers each placing the same doc at rank 1:
        //   rrf      = 4 * 1/(k+1) = 4/(k+1)
        //   max_rrf  = 4/(k+1)
        //   confidence = 1.0 EXACTLY (k-independent)
        //
        // The saturation pin family now spans N=1 (iter 82), N=2
        // (iter 105 in hybrid.rs), N=3 (iter 116), N=4 (this). Any
        // future change to max_rrf or the rrf accumulator that broke
        // the saturation identity at any specific N would surface
        // here.
        //
        // Use 4 focused Lex inners each holding only the same single
        // doc — guaranteeing rank-1 in all four.
        let mut build = || -> Box<dyn EidosRetriever> {
            let mut lex = InMemoryLexicalIndex::new(manifest());
            lex.insert(doc("trio"), "tropical", EidosSourceKind::Note).unwrap();
            Box::new(lex)
        };
        let h = HybridRetrieverN::new(vec![build(), build(), build(), build()]).unwrap();
        assert_eq!(h.inner_len(), 4);

        let q = EidosQuery::new("tropical", EidosRetrievalMode::Hybrid, 16);
        let packet = h.retrieve(&q, T0);
        assert_eq!(packet.hits.len(), 1);
        assert!(
            (packet.hits[0].confidence - 1.0).abs() < 1e-6,
            "N=4 saturation (rank-1 in all 4 inners) expected confidence 1.0, got {}",
            packet.hits[0].confidence
        );
    }

    #[test]
    fn hybrid_n_n3_saturation_doc_rank_1_in_all_inners_yields_confidence_one() {
        // Companion to the 1/N curve pins at N=1/2/3/4 (iters 82, 105,
        // 107, 112 — single-mode rank-1 cases). The saturation
        // direction for N>1 was implicitly pinned only at N=2
        // (iter 105's `rank_one_in_both_normalizes_to_confidence_one`
        // in hybrid.rs). At N=3:
        //   rrf      = 3 * 1/(k+1)
        //   max_rrf  = 3/(k+1)
        //   confidence = 1.0 EXACTLY (k-independent)
        //
        // Existing `doc_in_all_three_outranks_doc_in_only_one` pins
        // rank ordering but not the confidence value. A future
        // change to max_rrf or to the rrf accumulator could leave
        // ordering correct while pushing the saturation point off 1.0.
        //
        // Build focused inner retrievers where "trio" is the SOLE doc
        // in each — guaranteeing rank-1 in all three. (The shared
        // build_lex/sem/recency fixtures put trio at rank-2 in Lex
        // because "lex-only" sorts ahead of "trio" alphabetically on
        // a tied lexical score, which exposed an important subtlety:
        // saturation requires rank-1 in EVERY inner, not just
        // presence.)
        let mut lex = InMemoryLexicalIndex::new(manifest());
        lex.insert(doc("trio"), "tropical", EidosSourceKind::Note).unwrap();
        let mut sem = InMemorySemanticIndex::new(manifest(), 2);
        sem.insert(doc("trio"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();
        let mut recency = InMemoryRecencyIndex::new(manifest());
        recency.insert(doc("trio"), "tropical", T0, EidosSourceKind::Note);

        let h = HybridRetrieverN::new(vec![
            Box::new(lex),
            Box::new(sem),
            Box::new(recency),
        ])
        .unwrap();
        assert_eq!(h.inner_len(), 3);

        let q = EidosQuery::with_vector(
            "tropical",
            EidosRetrievalMode::Hybrid,
            16,
            vec![1.0, 0.0],
        );
        let packet = h.retrieve(&q, T0);
        assert_eq!(packet.hits.len(), 1, "exactly one doc (trio) survived");
        let trio_hit = &packet.hits[0];
        assert_eq!(trio_hit.document_id.as_str(), "trio");

        // The N=3 saturation point: rrf_sum = 3/(k+1) = max_rrf,
        // so confidence = 1.0 exactly (k-independent).
        assert!(
            (trio_hit.confidence - 1.0).abs() < 1e-6,
            "N=3 saturation (rank-1 in all 3 inners) expected confidence 1.0, got {}",
            trio_hit.confidence
        );
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
    fn three_way_fusion_passes_through_each_inner_score_component_exactly() {
        // Strengthens `three_way_fusion_aggregates_score_components_per_mode`
        // from shape-only (`> 0.0`) to exact-value pass-through.
        // Fourth pin in the score-pass-through family alongside:
        //   iter 82  — Hybrid_N N=1 (single inner Lex preserves
        //              score.lexical exact value).
        //   iter 95  — PV preserves every inner field byte-equal.
        //   iter 97  — Hybrid 2-way Lex+Sem exact-value pass-through.
        //   iter 110 — this: Hybrid_N N=3 Lex+Sem+Recency exact-value
        //              pass-through under max-merge fold.
        //
        // The Hybrid_N fold at hybrid_n.rs:170-173 max-merges each
        // score component across inners. For the canonical
        // Lex+Sem+Recency case, each retriever populates exactly one
        // component (Lex→lexical, Sem→semantic, Recency→recency), so
        // max-merge effectively pass-through. A future change that
        // averaged instead of max-merged, or that scaled components by
        // 1/N, would silently shift the fused values. The chat layer
        // + Brain Panel display these components verbatim.
        //
        // Capture per-doc inner scores directly, then run the fused
        // Hybrid_N, assert each component matches.
        let inner_lex = build_lex();
        let inner_sem = build_sem();
        let inner_recency = build_recency();
        let q = EidosQuery::with_vector(
            "tropical",
            EidosRetrievalMode::Hybrid,
            16,
            vec![1.0, 0.0],
        );

        let lex_pkt = inner_lex.retrieve(&q, T0);
        let sem_pkt = inner_sem.retrieve(&q, T0);
        let recency_pkt = inner_recency.retrieve(&q, T0);
        let inner_lex_score = lex_pkt
            .hits
            .iter()
            .find(|h| h.document_id.as_str() == "trio")
            .expect("trio in Lex packet")
            .score
            .lexical;
        let inner_sem_score = sem_pkt
            .hits
            .iter()
            .find(|h| h.document_id.as_str() == "trio")
            .expect("trio in Sem packet")
            .score
            .semantic;
        let inner_recency_score = recency_pkt
            .hits
            .iter()
            .find(|h| h.document_id.as_str() == "trio")
            .expect("trio in Recency packet")
            .score
            .recency;

        // Fresh inner instances for the Hybrid_N (consumed by Box).
        let h = HybridRetrieverN::new(vec![
            Box::new(build_lex()),
            Box::new(build_sem()),
            Box::new(build_recency()),
        ])
        .unwrap();
        let fused = h.retrieve(&q, T0);
        let trio_fused = fused
            .hits
            .iter()
            .find(|h| h.document_id.as_str() == "trio")
            .expect("trio in fusion output");

        assert!(
            (trio_fused.score.lexical - inner_lex_score).abs() < 1e-6,
            "fused score.lexical {} != inner Lex score {}",
            trio_fused.score.lexical,
            inner_lex_score,
        );
        assert!(
            (trio_fused.score.semantic - inner_sem_score).abs() < 1e-6,
            "fused score.semantic {} != inner Sem score {}",
            trio_fused.score.semantic,
            inner_sem_score,
        );
        assert!(
            (trio_fused.score.recency - inner_recency_score).abs() < 1e-6,
            "fused score.recency {} != inner Recency score {}",
            trio_fused.score.recency,
            inner_recency_score,
        );
        // Sanity-pin all three inner values are non-zero so the
        // equalities aren't trivially satisfied by 0==0.
        assert!(inner_lex_score > 0.0);
        assert!(inner_sem_score > 0.0);
        assert!(inner_recency_score > 0.0);
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
    fn manifest_mismatch_reports_first_offending_index_in_4_retriever_list() {
        // Companion to the 2-retriever pin above. The constructor walks
        // retrievers left-to-right and returns ManifestMismatch on the
        // FIRST one whose manifest_id differs from index 0's. With a
        // single mismatching retriever in the middle of a longer list,
        // the reported index must be exactly that position — not the
        // last mismatch, not zero, not the length.
        //
        // Build [Lex(m), Sem(m), Lex(other), Sem(m)]:
        //   indices 0, 1, 3 all share `m`; index 2 alone is `other`.
        //   The error must report index = 2 (NOT 3, NOT 1, NOT 0).
        let lex0 = InMemoryLexicalIndex::new(manifest());
        let sem1 = InMemorySemanticIndex::new(manifest(), 2);
        let lex2_bad = InMemoryLexicalIndex::new(other_manifest());
        let sem3 = InMemorySemanticIndex::new(manifest(), 2);
        let err = HybridRetrieverN::new(vec![
            Box::new(lex0),
            Box::new(sem1),
            Box::new(lex2_bad),
            Box::new(sem3),
        ])
        .unwrap_err();
        match err {
            HybridNConstructionError::ManifestMismatch {
                index,
                expected,
                got,
            } => {
                assert_eq!(
                    index, 2,
                    "first-offending-index contract must report position 2, not last or zero",
                );
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
    fn default_k_after_new_is_rrf_k_default_60() {
        // Audit per "audit existing claims first":
        //   - `with_k_overrides_default` pins k() AFTER with_k(10) → 10.
        //
        // Gap: the DEFAULT k value after plain `new()` (no with_k) was
        // not explicitly pinned. The default is `RRF_K_DEFAULT = 60`
        // (mirrors epsilon-shadow's RRF k convention per hybrid_n.rs:18).
        // A future change to the default (e.g., to RRF_K_DEFAULT = 30
        // for "tighter discrimination" or 100 for "more forgiveness")
        // would silently shift every Hybrid_N's scoring without any
        // existing test firing.
        let h = HybridRetrieverN::new(vec![Box::new(build_lex())]).unwrap();
        assert_eq!(
            h.k(),
            60,
            "default k() after new() must be RRF_K_DEFAULT (60)"
        );
    }

    #[test]
    fn with_k_actually_changes_scoring_not_just_getter() {
        // The `with_k_overrides_default` test pins that h.k() reads
        // back what was set — but a future `with_k` that stored k
        // without USING it in retrieve() would pass that test while
        // silently breaking the substrate.
        //
        // Pin that with_k(small_k) produces measurably different
        // confidence values from with_k(large_k). Math: for a doc
        // at rank-2 in a single inner retriever (N=1):
        //   rrf      = 1/(k+2)
        //   max_rrf  = 1/(k+1)
        //   confidence = (k+1)/(k+2)
        // With k=10: 11/12 ≈ 0.9167
        // With k=60: 61/62 ≈ 0.9839
        // Different by ~0.067 — far exceeding f32 epsilon.
        let mut lex_a = InMemoryLexicalIndex::new(manifest());
        lex_a.insert(doc("rank-1"), "x", EidosSourceKind::Note).unwrap();
        lex_a.insert(doc("rank-2"), "x", EidosSourceKind::Note).unwrap();
        // Lex sort is `(score desc, source_id asc)`; both docs have
        // identical lex_score (1/(1+1)=0.5), so order is by source_id.
        // "rank-1" sorts before "rank-2" alphabetically (per source_id).

        let h_default =
            HybridRetrieverN::new(vec![Box::new(lex_a)]).unwrap();
        let q = EidosQuery::new("x", EidosRetrievalMode::Hybrid, 8);
        let p_default = h_default.retrieve(&q, T0);

        let mut lex_b = InMemoryLexicalIndex::new(manifest());
        lex_b.insert(doc("rank-1"), "x", EidosSourceKind::Note).unwrap();
        lex_b.insert(doc("rank-2"), "x", EidosSourceKind::Note).unwrap();
        let h_small_k =
            HybridRetrieverN::new(vec![Box::new(lex_b)]).unwrap().with_k(10);
        let p_small_k = h_small_k.retrieve(&q, T0);

        // Top hit (rank-1 in both retrievers) saturates to 1.0
        // regardless of k.
        assert!((p_default.hits[0].confidence - 1.0).abs() < 1e-6);
        assert!((p_small_k.hits[0].confidence - 1.0).abs() < 1e-6);

        // Second hit confidence differs by k. Compute the expected
        // values from the formula.
        let expected_default = 61.0_f32 / 62.0; // k=60
        let expected_small_k = 11.0_f32 / 12.0; // k=10
        assert!(
            (p_default.hits[1].confidence - expected_default).abs() < 1e-6,
            "default-k rank-2 confidence expected {}, got {}",
            expected_default,
            p_default.hits[1].confidence,
        );
        assert!(
            (p_small_k.hits[1].confidence - expected_small_k).abs() < 1e-6,
            "small-k rank-2 confidence expected {}, got {}",
            expected_small_k,
            p_small_k.hits[1].confidence,
        );
        // Sanity-pin that the two are NOT equal (catches a future
        // with_k that's a no-op even if both happen to land at some
        // shared value).
        assert!(
            (p_default.hits[1].confidence - p_small_k.hits[1].confidence).abs() > 0.05,
            "with_k(10) must produce confidence measurably different from default k=60",
        );
    }

    #[test]
    fn hybrid_n_confidence_at_single_mode_rank_one_with_n4_is_exactly_one_quarter() {
        // Extends the 1/N curve pin family to N=4.
        // Existing points: N=1 saturation (iter 82), N=2 (iter 105 in
        // hybrid.rs), N=3 (iter 107). For N=4 with a doc at rank-1 in
        // exactly one inner retriever:
        //   rrf = 1/(k+1)
        //   max_rrf = 4/(k+1)
        //   confidence = 1/4 exactly (k-independent)
        //
        // Build N=4 inner retrievers where only the first holds the
        // doc (3 empty Lex stand-ins). Single-mode rank-1 case.
        let mut lex_a = InMemoryLexicalIndex::new(manifest());
        lex_a.insert(doc("only-lex"), "match", EidosSourceKind::Note).unwrap();
        let lex_empty_1 = InMemoryLexicalIndex::new(manifest());
        let lex_empty_2 = InMemoryLexicalIndex::new(manifest());
        let lex_empty_3 = InMemoryLexicalIndex::new(manifest());
        let h = HybridRetrieverN::new(vec![
            Box::new(lex_a),
            Box::new(lex_empty_1),
            Box::new(lex_empty_2),
            Box::new(lex_empty_3),
        ])
        .unwrap();
        assert_eq!(h.inner_len(), 4);

        let q = EidosQuery::new("match", EidosRetrievalMode::Hybrid, 8);
        let packet = h.retrieve(&q, T0);
        assert_eq!(packet.hits.len(), 1);
        let confidence = packet.hits[0].confidence;
        let expected = 0.25_f32;
        assert!(
            (confidence - expected).abs() < 1e-6,
            "N=4 single-mode rank-1 fused confidence expected 0.25, got {}",
            confidence
        );
    }

    #[test]
    fn hybrid_n_confidence_at_single_mode_rank_one_with_n3_is_exactly_one_third() {
        // Symmetric counterpart to iter 105's Hybrid 2-way single-mode
        // rank-1 = 0.5 pin. Hybrid_N at hybrid_n.rs:179 normalizes:
        //   max_rrf = N / (k+1)
        //   confidence = (rrf / max_rrf).clamp(0, 1)
        //
        // For N=3 with a doc at rank-1 in EXACTLY ONE inner retriever:
        //   rrf = 1/(k+1)
        //   confidence = (1/(k+1)) / (3/(k+1)) = 1/3   (independent of k)
        //
        // Existing pins:
        //   - iter 82 (`single_inner_retriever_preserves_count_score_and_saturates_top_confidence`)
        //     covers N=1 saturation (1/1 = 1.0).
        //   - `confidence_is_normalized_into_unit_interval` covers
        //     range only.
        //
        // The 1/N intermediate value at single-mode rank-1 — the
        // canonical algebraic identity for the N-way fold — is not
        // pinned. A future change to max_rrf (e.g., "max-of-actually-
        // present-modes" rather than "fixed N") would silently shift
        // this point.
        let mut lex = InMemoryLexicalIndex::new(manifest());
        lex.insert(doc("only-lex"), "tropical", EidosSourceKind::Note).unwrap();
        // Empty Sem + Recency — "only-lex" appears in Lex only.
        let sem = InMemorySemanticIndex::new(manifest(), 1);
        let recency = InMemoryRecencyIndex::new(manifest());

        let h = HybridRetrieverN::new(vec![
            Box::new(lex),
            Box::new(sem),
            Box::new(recency),
        ])
        .unwrap();
        assert_eq!(h.inner_len(), 3);

        let q = EidosQuery::with_vector(
            "tropical",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0],
        );
        let packet = h.retrieve(&q, T0);
        assert_eq!(packet.hits.len(), 1);
        let confidence = packet.hits[0].confidence;
        let expected = 1.0_f32 / 3.0;
        assert!(
            (confidence - expected).abs() < 1e-6,
            "N=3 single-mode rank-1 fused confidence expected 1/3 ≈ {}, got {}",
            expected,
            confidence
        );
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
