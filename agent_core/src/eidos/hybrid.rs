//! Hybrid retrieval mode — Reciprocal Rank Fusion of Lexical + Semantic.
//!
//! Hybrid is the **default** retrieval mode for Eidos chat queries because
//! BM25-style lexical and HNSW-style dense retrieval miss different things:
//! lexical catches exact terminology / code symbols, semantic catches
//! paraphrases / cross-lingual / conceptual matches. RRF fuses their
//! rankings without needing score normalization between the two
//! incompatible scales.
//!
//! ## RRF formula
//!
//! For each candidate document `d`, the fused score is
//!
//! ```text
//!     RRF(d) = Σ_{ranking r}  1 / (k + rank_r(d))
//! ```
//!
//! where `rank_r(d)` is `d`'s 1-based position in ranking `r` (lexical or
//! semantic) and `k = 60`. Documents absent from a ranking contribute 0
//! from that ranking.
//!
//! `k = 60` is the constant used by the production `epistemos-shadow`
//! pipeline (`epistemos-shadow/src/backend/rrf.rs:22` `RRF_K_DEFAULT`) and
//! mirrored on the Swift side as
//! `Phase3FusionConsts.K_RRF` in `Epistemos/Sync/RRFFusionQuery.swift`. Eidos
//! uses the same constant so cross-component diagnostic readouts can compare
//! fusion behavior directly.
//!
//! ## Cross-mode dedup
//!
//! The acceptance bar requires "duplicate merge": a document that appears in
//! both lexical and semantic results must collapse into **one** citable hit.
//! Hybrid dedups by [`EidosDocumentId`] and emits a single
//! `EidosChunkId` of the form `"{document_id}::hybrid"`, distinct from the
//! per-mode `::lex` / `::sem` ids so a chat layer can't accidentally cite
//! the unmerged form.
//!
//! ## Closed-citation contract
//!
//! Hybrid is a retriever like any other — the packet it returns is the
//! closed citation universe for any answer that uses it. The per-mode hits
//! the lexical/semantic retrievers internally generated are **not** citable;
//! only the fused `::hybrid` ids are.

use std::collections::BTreeMap;

use super::retriever::EidosRetriever;
use super::types::{
    is_blank_query_text, EidosChunkId, EidosContextPacket, EidosDocumentId, EidosHit,
    EidosIndexManifestId, EidosProvenance, EidosQuery, EidosRetrievalMode,
    EidosScoreComponents, EidosSourceKind, EidosSpan,
};

/// RRF constant. Matches `epistemos-shadow/src/backend/rrf.rs:22`
/// `RRF_K_DEFAULT` and Swift `Phase3FusionConsts.K_RRF`.
pub const RRF_K_DEFAULT: u32 = 60;

#[derive(Debug, thiserror::Error, PartialEq)]
pub enum HybridConstructionError {
    /// The lexical and semantic retrievers were bound to different index
    /// snapshots. Hybrid fusion requires a shared manifest because the
    /// fused packet must declare a single `EidosIndexManifestId` and the
    /// closed-citation contract checks citations against it.
    #[error(
        "hybrid retriever requires a shared manifest_id: lexical={lexical:?}, semantic={semantic:?}"
    )]
    ManifestMismatch {
        lexical: EidosIndexManifestId,
        semantic: EidosIndexManifestId,
    },
}

/// RRF fusion of one lexical retriever + one semantic retriever, both bound
/// to the same index snapshot.
#[derive(Clone, Debug)]
pub struct HybridRetriever<L: EidosRetriever, S: EidosRetriever> {
    lexical: L,
    semantic: S,
    /// Cached shared manifest_id, validated at construction.
    manifest_id: EidosIndexManifestId,
    /// RRF constant. Defaults to [`RRF_K_DEFAULT`] = 60 to match the
    /// epistemos-shadow + Swift fusion stack.
    k: u32,
}

impl<L: EidosRetriever, S: EidosRetriever> HybridRetriever<L, S> {
    /// Construct a hybrid retriever from a lexical and a semantic retriever.
    /// Both must share the same `manifest_id` — otherwise the fused packet
    /// would carry an ambiguous snapshot and break the closed-citation
    /// contract.
    pub fn new(lexical: L, semantic: S) -> Result<Self, HybridConstructionError> {
        if lexical.manifest_id() != semantic.manifest_id() {
            return Err(HybridConstructionError::ManifestMismatch {
                lexical: lexical.manifest_id().clone(),
                semantic: semantic.manifest_id().clone(),
            });
        }
        let manifest_id = lexical.manifest_id().clone();
        Ok(Self {
            lexical,
            semantic,
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
}

/// Per-document accumulator collected while walking the lexical + semantic
/// rankings.
struct HybridAccumulator {
    document_id: EidosDocumentId,
    kind: EidosSourceKind,
    /// Lexical span if the lexical pass found one. Preferred over None
    /// because spans give the Brain Panel a literal snippet anchor.
    span: Option<EidosSpan>,
    lexical_score: f32,
    semantic_score: f32,
    rrf: f32,
}

impl<L: EidosRetriever, S: EidosRetriever> EidosRetriever for HybridRetriever<L, S> {
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

        let lexical_packet = self.lexical.retrieve(query, retrieved_at_unix_ms);
        let semantic_packet = self.semantic.retrieve(query, retrieved_at_unix_ms);
        let k = self.k as f32;

        // BTreeMap keyed on document_id keeps fold order deterministic, which
        // is required for byte-equal replay.
        let mut acc: BTreeMap<EidosDocumentId, HybridAccumulator> = BTreeMap::new();

        for (rank, hit) in lexical_packet.hits.iter().enumerate() {
            let rank_1based = (rank + 1) as f32;
            let contribution = 1.0 / (k + rank_1based);
            acc.entry(hit.document_id.clone())
                .and_modify(|a| {
                    a.lexical_score = a.lexical_score.max(hit.score.lexical);
                    a.rrf += contribution;
                    if a.span.is_none() {
                        a.span = hit.span;
                    }
                })
                .or_insert(HybridAccumulator {
                    document_id: hit.document_id.clone(),
                    kind: hit.kind,
                    span: hit.span,
                    lexical_score: hit.score.lexical,
                    semantic_score: 0.0,
                    rrf: contribution,
                });
        }

        for (rank, hit) in semantic_packet.hits.iter().enumerate() {
            let rank_1based = (rank + 1) as f32;
            let contribution = 1.0 / (k + rank_1based);
            acc.entry(hit.document_id.clone())
                .and_modify(|a| {
                    a.semantic_score = a.semantic_score.max(hit.score.semantic);
                    a.rrf += contribution;
                })
                .or_insert(HybridAccumulator {
                    document_id: hit.document_id.clone(),
                    kind: hit.kind,
                    span: hit.span,
                    lexical_score: 0.0,
                    semantic_score: hit.score.semantic,
                    rrf: contribution,
                });
        }

        // Normalize confidence into [0, 1]. The maximum RRF for two rankings
        // both putting the doc at rank 1 is `2 / (k + 1)`; dividing by that
        // produces a clean upper bound users can compare against scores from
        // the other retrievers.
        let max_rrf = 2.0 / (k + 1.0);

        let mut scored: Vec<HybridAccumulator> = acc.into_values().collect();
        // (rrf desc, source_id asc). source_id of a hybrid hit is
        // "{doc_id}::hybrid" which preserves the lex/sem ordering convention
        // when scores collide.
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
                    .expect("document_id is non-empty by construction");
                let confidence = (a.rrf / max_rrf).clamp(0.0, 1.0);
                EidosHit {
                    source_id: chunk_id,
                    document_id: a.document_id,
                    kind: a.kind,
                    span: a.span,
                    confidence,
                    score: EidosScoreComponents {
                        lexical: a.lexical_score,
                        semantic: a.semantic_score,
                        recency: 0.0,
                        graph: 0.0,
                    },
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
    use crate::eidos::semantic::InMemorySemanticIndex;
    use crate::eidos::types::EidosCitation;

    fn manifest() -> EidosIndexManifestId {
        EidosIndexManifestId::new("hybrid-test-manifest").unwrap()
    }

    fn other_manifest() -> EidosIndexManifestId {
        EidosIndexManifestId::new("OTHER-manifest").unwrap()
    }

    fn doc(id: &str) -> EidosDocumentId {
        EidosDocumentId::new(id).unwrap()
    }

    #[derive(Clone, Debug)]
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
    fn blank_query_defers_before_inner_fusion_even_if_inner_leaks() {
        let lexical = BlankLeakingRetriever {
            manifest_id: manifest(),
            document_id: doc("lex-leak"),
        };
        let semantic = BlankLeakingRetriever {
            manifest_id: manifest(),
            document_id: doc("sem-leak"),
        };
        let hybrid = HybridRetriever::new(lexical, semantic).unwrap();
        let q = EidosQuery::new("   ", EidosRetrievalMode::Hybrid, 16);
        let packet = hybrid.retrieve(&q, 1_700_000_000_000);
        assert!(
            packet.hits.is_empty(),
            "Hybrid must fail closed on blank query before fusing inner hits"
        );
    }

    #[test]
    fn invisible_only_query_defers_before_inner_fusion_even_if_inner_leaks() {
        let lexical = BlankLeakingRetriever {
            manifest_id: manifest(),
            document_id: doc("lex-leak"),
        };
        let semantic = BlankLeakingRetriever {
            manifest_id: manifest(),
            document_id: doc("sem-leak"),
        };
        let hybrid = HybridRetriever::new(lexical, semantic).unwrap();
        let q = EidosQuery::new("\u{200B}", EidosRetrievalMode::Hybrid, 16);
        let packet = hybrid.retrieve(&q, 1_700_000_000_000);
        assert!(
            packet.hits.is_empty(),
            "Hybrid must fail closed on invisible-only query before fusing inner hits"
        );
    }

    fn build_pair() -> HybridRetriever<InMemoryLexicalIndex, InMemorySemanticIndex> {
        let mut lex = InMemoryLexicalIndex::new(manifest());
        lex.insert(
            doc("alpha"),
            "alpha tropical optimization",
            EidosSourceKind::Note,
        )
        .unwrap();
        lex.insert(
            doc("beta"),
            "beta convex tropical optimization geometry",
            EidosSourceKind::Note,
        )
        .unwrap();
        lex.insert(
            doc("gamma"),
            "gamma unrelated content",
            EidosSourceKind::Note,
        )
        .unwrap();

        let mut sem = InMemorySemanticIndex::new(manifest(), 3);
        // alpha and gamma are aligned with the query direction (1,0,0).
        sem.insert(doc("alpha"), vec![1.0, 0.0, 0.0], EidosSourceKind::Note)
            .unwrap();
        sem.insert(doc("gamma"), vec![0.7, 0.7, 0.0], EidosSourceKind::Note)
            .unwrap();
        // delta only appears in semantic — should still surface in hybrid.
        sem.insert(doc("delta"), vec![0.9, 0.1, 0.0], EidosSourceKind::Note)
            .unwrap();

        HybridRetriever::new(lex, sem).unwrap()
    }

    #[test]
    fn hybrid_2way_score_components_match_inner_retriever_exact_values() {
        // Audit per "audit existing claims first":
        //   - `same_doc_in_both_modes_merges_to_single_hybrid_hit` pins
        //     `score.lexical > 0` AND `score.semantic > 0` for alpha
        //     (shape check, not value check).
        //   - `lexical_only_doc_appears_in_hybrid_packet` pins
        //     score.semantic == 0 for beta (lex-only doc).
        //   - `semantic_only_doc_appears_in_hybrid_packet` pins
        //     score.lexical == 0 for delta (sem-only doc).
        //
        // Gap: none of these pin EXACT-VALUE pass-through. The fused
        // hit's score.lexical should equal the inner Lex's
        // score.lexical for that doc (within f32 epsilon), and same
        // for score.semantic. A future fold change that introduced
        // *= 0.5 or += 0.0001 normalization would silently break the
        // bridge contract (Brain Panel displays per-mode scores
        // verbatim) and only the shape-check tests would still pass.
        //
        // Capture per-doc inner scores directly, then assert the
        // fused Hybrid 2-way hits carry the same values. This is the
        // 2-way counterpart to iter 82's N=1 Hybrid_N pass-through
        // pin and iter 95's PV preservation pin.
        let mut inner_lex = InMemoryLexicalIndex::new(manifest());
        inner_lex.insert(doc("alpha"), "alpha tropical optimization", EidosSourceKind::Note).unwrap();
        let mut inner_sem = InMemorySemanticIndex::new(manifest(), 3);
        inner_sem.insert(doc("alpha"), vec![1.0, 0.0, 0.0], EidosSourceKind::Note).unwrap();

        let q = EidosQuery::with_vector(
            "tropical",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0, 0.0, 0.0],
        );
        let inner_lex_pkt = inner_lex.retrieve(&q, 1_700_000_000_000);
        let inner_sem_pkt = inner_sem.retrieve(&q, 1_700_000_000_000);
        let alpha_lex_score = inner_lex_pkt
            .hits
            .iter()
            .find(|h| h.document_id.as_str() == "alpha")
            .expect("inner Lex must score alpha")
            .score
            .lexical;
        let alpha_sem_score = inner_sem_pkt
            .hits
            .iter()
            .find(|h| h.document_id.as_str() == "alpha")
            .expect("inner Sem must score alpha")
            .score
            .semantic;

        let mut h_lex = InMemoryLexicalIndex::new(manifest());
        h_lex.insert(doc("alpha"), "alpha tropical optimization", EidosSourceKind::Note).unwrap();
        let mut h_sem = InMemorySemanticIndex::new(manifest(), 3);
        h_sem.insert(doc("alpha"), vec![1.0, 0.0, 0.0], EidosSourceKind::Note).unwrap();
        let hybrid = HybridRetriever::new(h_lex, h_sem).unwrap();
        let fused = hybrid.retrieve(&q, 1_700_000_000_000);
        let alpha_fused = fused
            .hits
            .iter()
            .find(|h| h.document_id.as_str() == "alpha")
            .expect("fused packet must contain alpha");

        // Exact-value pass-through (f32 epsilon for floating safety).
        assert!(
            (alpha_fused.score.lexical - alpha_lex_score).abs() < 1e-6,
            "fused score.lexical ({}) must equal inner Lex score.lexical ({})",
            alpha_fused.score.lexical,
            alpha_lex_score,
        );
        assert!(
            (alpha_fused.score.semantic - alpha_sem_score).abs() < 1e-6,
            "fused score.semantic ({}) must equal inner Sem score.semantic ({})",
            alpha_fused.score.semantic,
            alpha_sem_score,
        );
        // Sanity-pin: both inner scores are strictly > 0 so the
        // assertion above isn't trivially satisfied by 0 == 0.
        assert!(alpha_lex_score > 0.0 && alpha_sem_score > 0.0);
    }

    #[test]
    fn same_doc_in_both_modes_merges_to_single_hybrid_hit() {
        let hybrid = build_pair();
        let q = EidosQuery::with_vector(
            "tropical",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0, 0.0, 0.0],
        );
        let packet = hybrid.retrieve(&q, 1_700_000_000_000);

        // alpha is in BOTH lexical (matches "tropical") and semantic
        // (perfect cosine on x-axis). It must appear exactly once.
        let alpha_hits: Vec<_> = packet
            .hits
            .iter()
            .filter(|h| h.document_id.as_str() == "alpha")
            .collect();
        assert_eq!(alpha_hits.len(), 1, "duplicate merge violated");
        assert_eq!(alpha_hits[0].source_id.as_str(), "alpha::hybrid");
        // Merged hit carries BOTH score components from the source modes.
        assert!(alpha_hits[0].score.lexical > 0.0);
        assert!(alpha_hits[0].score.semantic > 0.0);
    }

    #[test]
    fn lexical_only_doc_appears_in_hybrid_packet() {
        let hybrid = build_pair();
        let q = EidosQuery::with_vector(
            "tropical",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0, 0.0, 0.0],
        );
        let packet = hybrid.retrieve(&q, 1_700_000_000_000);

        // beta matches lexically ("tropical") but is not in the semantic
        // index. It must still appear in the hybrid output with semantic
        // score 0.
        let beta_hits: Vec<_> = packet
            .hits
            .iter()
            .filter(|h| h.document_id.as_str() == "beta")
            .collect();
        assert_eq!(beta_hits.len(), 1);
        assert!(beta_hits[0].score.lexical > 0.0);
        assert_eq!(beta_hits[0].score.semantic, 0.0);
    }

    #[test]
    fn semantic_only_doc_appears_in_hybrid_packet() {
        let hybrid = build_pair();
        let q = EidosQuery::with_vector(
            "unmatched",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0, 0.0, 0.0],
        );
        let packet = hybrid.retrieve(&q, 1_700_000_000_000);

        // delta only exists in the semantic index. It must appear.
        let delta_hits: Vec<_> = packet
            .hits
            .iter()
            .filter(|h| h.document_id.as_str() == "delta")
            .collect();
        assert_eq!(delta_hits.len(), 1);
        assert_eq!(delta_hits[0].score.lexical, 0.0);
        assert!(delta_hits[0].score.semantic > 0.0);
    }

    #[test]
    fn rrf_ordering_is_deterministic() {
        let a = build_pair();
        let b = build_pair();
        let q = EidosQuery::with_vector(
            "tropical",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0, 0.0, 0.0],
        );
        let pa = a.retrieve(&q, 1_700_000_000_000);
        let pb = b.retrieve(&q, 1_700_000_000_000);
        assert_eq!(pa, pb);
    }

    #[test]
    fn rrf_tie_break_is_document_id_ascending() {
        // Sort key is `(rrf desc, document_id asc)`. Existing tests pin
        // strict-inequality cases (a-doc-in-both outranks a-doc-in-one);
        // this one nails the *tie* path. Build a corpus where two docs
        // appear at rank 1 in different SINGLE backends — each accumulates
        // rrf = 1/(k+1) once, tying exactly. The fused packet must then
        // sort them alphabetically asc by document_id, so a future tie
        // ordering change (descending, insertion-order, etc.) fires here.
        let mut lex = InMemoryLexicalIndex::new(manifest());
        // Lexical-only: "z-doc" matches at rank 1 in lexical.
        lex.insert(doc("z-doc"), "needle", EidosSourceKind::Note).unwrap();
        let mut sem = InMemorySemanticIndex::new(manifest(), 3);
        // Semantic-only: "a-doc" matches at rank 1 in semantic.
        sem.insert(doc("a-doc"), vec![1.0, 0.0, 0.0], EidosSourceKind::Note)
            .unwrap();

        let hybrid = HybridRetriever::new(lex, sem).unwrap();
        let q = EidosQuery::with_vector(
            "needle",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0, 0.0, 0.0],
        );
        let packet = hybrid.retrieve(&q, 1_700_000_000_000);

        let order: Vec<&str> = packet
            .hits
            .iter()
            .map(|h| h.document_id.as_str())
            .collect();
        assert_eq!(
            order,
            vec!["a-doc", "z-doc"],
            "tied RRF must break by document_id ascending",
        );

        // Sanity: the two hits really do carry identical RRF-derived
        // confidence (within f32 epsilon — the impl is deterministic so
        // they should be bit-equal, but the test is robust to floating
        // semantics).
        let a_pos = order.iter().position(|s| *s == "a-doc").unwrap();
        let z_pos = order.iter().position(|s| *s == "z-doc").unwrap();
        let delta = (packet.hits[a_pos].confidence - packet.hits[z_pos].confidence).abs();
        assert!(
            delta < 1e-6,
            "tie-break implies near-equal confidence; got delta = {delta}"
        );
    }

    #[test]
    fn doc_in_both_outranks_doc_in_one() {
        let hybrid = build_pair();
        let q = EidosQuery::with_vector(
            "tropical",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0, 0.0, 0.0],
        );
        let packet = hybrid.retrieve(&q, 1_700_000_000_000);

        // alpha is in both lexical and semantic top results, so its RRF must
        // exceed beta's (lexical only) and delta's (semantic only).
        let order: Vec<&str> = packet
            .hits
            .iter()
            .map(|h| h.document_id.as_str())
            .collect();
        let alpha_pos = order.iter().position(|s| *s == "alpha").unwrap();
        let beta_pos = order.iter().position(|s| *s == "beta").unwrap();
        assert!(
            alpha_pos < beta_pos,
            "alpha (in both) should rank above beta (lexical only)"
        );
    }

    #[test]
    fn closed_citation_contract_holds_through_hybrid_retrieval() {
        let hybrid = build_pair();
        let q = EidosQuery::with_vector(
            "tropical",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0, 0.0, 0.0],
        );
        let packet = hybrid.retrieve(&q, 1_700_000_000_000);
        assert!(!packet.hits.is_empty());
        for hit in &packet.hits {
            let cite = EidosCitation {
                source_id: hit.source_id.clone(),
                manifest_id: packet.manifest_id.clone(),
            };
            assert_eq!(packet.validate_citation(&cite), Ok(()));
        }
        // The un-fused per-mode form `alpha::lex` is NOT citable through
        // the hybrid packet — only `alpha::hybrid` is.
        let pre_fusion_id = EidosCitation {
            source_id: EidosChunkId::new("alpha::lex").unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert!(packet.validate_citation(&pre_fusion_id).is_err());
    }

    #[test]
    fn manifest_mismatch_at_construction_errors() {
        let lex = InMemoryLexicalIndex::new(manifest());
        let sem = InMemorySemanticIndex::new(other_manifest(), 3);
        let err = HybridRetriever::new(lex, sem).unwrap_err();
        assert_eq!(
            err,
            HybridConstructionError::ManifestMismatch {
                lexical: manifest(),
                semantic: other_manifest(),
            }
        );
    }

    #[test]
    fn retriever_advertises_hybrid_mode_and_default_k() {
        let hybrid = build_pair();
        assert_eq!(hybrid.mode(), EidosRetrievalMode::Hybrid);
        assert_eq!(hybrid.manifest_id(), &manifest());
        assert_eq!(hybrid.k(), 60);
        // k=60 matches shadow + Swift fusion stack — protect the cross-
        // component invariant from accidental drift.
        assert_eq!(RRF_K_DEFAULT, 60);
    }

    #[test]
    fn empty_inner_retrievers_return_empty_hybrid_packet() {
        let lex = InMemoryLexicalIndex::new(manifest());
        let sem = InMemorySemanticIndex::new(manifest(), 3);
        let hybrid = HybridRetriever::new(lex, sem).unwrap();
        let q = EidosQuery::with_vector(
            "no data",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0, 0.0, 0.0],
        );
        let packet = hybrid.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn top_k_truncates_hybrid_output() {
        let hybrid = build_pair();
        let q = EidosQuery::with_vector(
            "tropical",
            EidosRetrievalMode::Hybrid,
            1,
            vec![1.0, 0.0, 0.0],
        );
        let packet = hybrid.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 1);
    }

    #[test]
    fn confidence_is_normalized_into_unit_interval() {
        let hybrid = build_pair();
        let q = EidosQuery::with_vector(
            "tropical",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0, 0.0, 0.0],
        );
        let packet = hybrid.retrieve(&q, 1_700_000_000_000);
        for hit in &packet.hits {
            assert!(
                hit.confidence >= 0.0 && hit.confidence <= 1.0,
                "confidence {} out of [0,1]",
                hit.confidence
            );
        }
    }

    #[test]
    fn rank_one_in_both_normalizes_to_confidence_one() {
        // The acceptance bar says hybrid confidence is normalized so that a
        // document at rank 1 in BOTH inner rankings achieves the maximum.
        // The normalization formula divides raw RRF by 2/(k+1), so a doc at
        // rank 1 in both gets raw RRF = 1/61 + 1/61 = 2/61, normalized to
        // exactly 1.0.
        let mut lex = InMemoryLexicalIndex::new(manifest());
        lex.insert(doc("only"), "tropical", EidosSourceKind::Note).unwrap();
        let mut sem = InMemorySemanticIndex::new(manifest(), 1);
        sem.insert(doc("only"), vec![1.0], EidosSourceKind::Note).unwrap();
        let hybrid = HybridRetriever::new(lex, sem).unwrap();
        let q = EidosQuery::with_vector(
            "tropical",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0],
        );
        let packet = hybrid.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 1);
        assert!(
            (packet.hits[0].confidence - 1.0).abs() < 1e-6,
            "rank-1-in-both should normalize to 1.0, got {}",
            packet.hits[0].confidence
        );
    }

    #[test]
    fn hybrid_2way_confidence_at_single_mode_rank_one_is_exactly_one_half() {
        // Sibling formula-by-example pin alongside:
        //   iter 100 — Recency 1/(1+age_days) at 5 ages
        //   iter 102 — Lexical n/(1+n) at 4 counts
        //   iter 104 — Semantic cosine at 4 angles
        //
        // Hybrid 2-way at hybrid.rs:215 normalizes:
        //   confidence = (rrf_sum / max_rrf).clamp(0, 1)
        //   max_rrf    = 2/(k+1)    (rank-1 in both modes → max)
        //
        // Existing tests:
        //   `rank_one_in_both_normalizes_to_confidence_one` — saturation
        //   (both rank 1, confidence = 1.0)
        //   `confidence_is_normalized_into_unit_interval` — range only
        //
        // Gap: the algebraic identity at the SINGLE-MODE rank-1 case
        // is not pinned. A doc that appears at rank 1 in lex but is
        // absent from sem contributes rrf = 1/(k+1) and the
        // normalization yields confidence = (1/(k+1)) / (2/(k+1)) =
        // 0.5 EXACTLY — clean half-saturation.
        //
        // Pin this so a future change to max_rrf (e.g., switching from
        // "max-of-both-modes" to "max-of-N-modes" wouldn't accidentally
        // shift the single-mode half-point) surfaces here.
        let mut lex = InMemoryLexicalIndex::new(manifest());
        lex.insert(doc("only-lex"), "tropical", EidosSourceKind::Note).unwrap();
        // Empty semantic — "only-lex" won't appear in sem ranking.
        let sem = InMemorySemanticIndex::new(manifest(), 1);
        let hybrid = HybridRetriever::new(lex, sem).unwrap();
        let q = EidosQuery::with_vector(
            "tropical",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0],
        );
        let packet = hybrid.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 1);
        // (1/(k+1)) / (2/(k+1)) = 0.5, independent of k.
        assert!(
            (packet.hits[0].confidence - 0.5).abs() < 1e-6,
            "single-mode rank-1 fused confidence expected 0.5, got {}",
            packet.hits[0].confidence
        );
    }

    #[test]
    fn only_lexical_populated_still_emits_hits_for_those() {
        // Asymmetric inner retrievers: lexical has docs, semantic is empty.
        // Hybrid output mimics the populated side (lexical-only ranks).
        let mut lex = InMemoryLexicalIndex::new(manifest());
        lex.insert(doc("solo"), "tropical alpha", EidosSourceKind::Note).unwrap();
        let sem = InMemorySemanticIndex::new(manifest(), 2);
        let hybrid = HybridRetriever::new(lex, sem).unwrap();
        let q = EidosQuery::with_vector(
            "tropical",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0, 0.0],
        );
        let packet = hybrid.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(packet.hits[0].document_id.as_str(), "solo");
        // Semantic side empty → semantic score 0.
        assert_eq!(packet.hits[0].score.semantic, 0.0);
        assert!(packet.hits[0].score.lexical > 0.0);
    }

    #[test]
    fn only_semantic_populated_still_emits_hits_for_those() {
        let lex = InMemoryLexicalIndex::new(manifest());
        let mut sem = InMemorySemanticIndex::new(manifest(), 2);
        sem.insert(doc("solo"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();
        let hybrid = HybridRetriever::new(lex, sem).unwrap();
        let q = EidosQuery::with_vector(
            "tropical",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0, 0.0],
        );
        let packet = hybrid.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(packet.hits[0].document_id.as_str(), "solo");
        assert_eq!(packet.hits[0].score.lexical, 0.0);
        assert!(packet.hits[0].score.semantic > 0.0);
    }

    #[test]
    fn with_k_overrides_default() {
        // Setting k=10 must produce a higher raw RRF for the same rank
        // than k=60 — but the normalization divides by `2/(k+1)`, so the
        // *normalized* confidence is k-independent for rank-1-in-both.
        // The behavioral signal we can observe externally: hybrid.k() ==
        // configured value.
        let mut lex = InMemoryLexicalIndex::new(manifest());
        lex.insert(doc("only"), "tropical", EidosSourceKind::Note).unwrap();
        let mut sem = InMemorySemanticIndex::new(manifest(), 1);
        sem.insert(doc("only"), vec![1.0], EidosSourceKind::Note).unwrap();
        let hybrid = HybridRetriever::new(lex, sem).unwrap().with_k(10);
        assert_eq!(hybrid.k(), 10);

        let q = EidosQuery::with_vector("tropical", EidosRetrievalMode::Hybrid, 8, vec![1.0]);
        let packet = hybrid.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 1);
        // Confidence still normalizes to 1.0 for rank-1-in-both regardless
        // of k — normalization absorbs k. This is the invariant.
        assert!((packet.hits[0].confidence - 1.0).abs() < 1e-6);
    }

    #[test]
    fn with_k_actually_changes_2way_scoring_for_mixed_rank_case() {
        // Symmetric to iter 108's Hybrid_N pin. `with_k_overrides_default`
        // above pins the GETTER (hybrid.k() == 10) — but explicitly
        // notes that rank-1-in-both is k-independent (normalization
        // absorbs k there). A future with_k() that stored k without
        // using it in retrieve() would pass both the getter test and
        // the rank-1-in-both confidence == 1.0 check.
        //
        // The missing pin: a case where k DOES affect the normalized
        // confidence. For a doc at rank-1 lex AND rank-2 sem:
        //   rrf      = 1/(k+1) + 1/(k+2)
        //   max_rrf  = 2/(k+1)
        //   confidence = (2k+3) / (2k+4)
        // With k=60: 123/124 ≈ 0.99194
        // With k=10:  23/24  ≈ 0.95833
        // Difference ≈ 0.034 — far above f32 epsilon.
        //
        // Setup: doc-X is rank-1 in lex (only doc that matches
        // "match") and rank-2 in sem (cos = 0.5 at 60°; doc-Y at
        // 0° is rank-1).
        let mut lex_a = InMemoryLexicalIndex::new(manifest());
        lex_a.insert(doc("doc-x"), "match here", EidosSourceKind::Note).unwrap();
        let mut sem_a = InMemorySemanticIndex::new(manifest(), 3);
        sem_a.insert(doc("doc-y"), vec![1.0, 0.0, 0.0], EidosSourceKind::Note).unwrap();
        sem_a.insert(doc("doc-x"), vec![0.5, (3.0_f32).sqrt() / 2.0, 0.0], EidosSourceKind::Note).unwrap();
        let h_default = HybridRetriever::new(lex_a, sem_a).unwrap();

        let mut lex_b = InMemoryLexicalIndex::new(manifest());
        lex_b.insert(doc("doc-x"), "match here", EidosSourceKind::Note).unwrap();
        let mut sem_b = InMemorySemanticIndex::new(manifest(), 3);
        sem_b.insert(doc("doc-y"), vec![1.0, 0.0, 0.0], EidosSourceKind::Note).unwrap();
        sem_b.insert(doc("doc-x"), vec![0.5, (3.0_f32).sqrt() / 2.0, 0.0], EidosSourceKind::Note).unwrap();
        let h_small_k = HybridRetriever::new(lex_b, sem_b).unwrap().with_k(10);

        let q = EidosQuery::with_vector(
            "match",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0, 0.0, 0.0],
        );
        let p_default = h_default.retrieve(&q, 1_700_000_000_000);
        let p_small_k = h_small_k.retrieve(&q, 1_700_000_000_000);

        // doc-x is rank-1 in lex (only lex match) and rank-2 in sem
        // (60° cosine, below doc-y's 0°).
        let x_default = p_default.hits.iter().find(|h| h.document_id.as_str() == "doc-x")
            .expect("doc-x must appear in default-k packet");
        let x_small_k = p_small_k.hits.iter().find(|h| h.document_id.as_str() == "doc-x")
            .expect("doc-x must appear in small-k packet");

        let expected_default = 123.0_f32 / 124.0;
        let expected_small_k = 23.0_f32 / 24.0;
        assert!(
            (x_default.confidence - expected_default).abs() < 1e-6,
            "default-k doc-x confidence expected {}, got {}",
            expected_default,
            x_default.confidence,
        );
        assert!(
            (x_small_k.confidence - expected_small_k).abs() < 1e-6,
            "small-k doc-x confidence expected {}, got {}",
            expected_small_k,
            x_small_k.confidence,
        );
        // Sanity-pin the inequality so a no-op with_k that returned
        // identical confidences at coincidental values would still
        // surface.
        assert!(
            (x_default.confidence - x_small_k.confidence).abs() > 0.02,
            "with_k(10) must produce confidence measurably different from default k=60",
        );
    }
}
