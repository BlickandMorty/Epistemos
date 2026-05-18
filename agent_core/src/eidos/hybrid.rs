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
    EidosChunkId, EidosContextPacket, EidosDocumentId, EidosHit, EidosIndexManifestId,
    EidosProvenance, EidosQuery, EidosRetrievalMode, EidosScoreComponents, EidosSourceKind,
    EidosSpan,
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
}
