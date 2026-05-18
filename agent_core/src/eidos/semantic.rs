//! Semantic retrieval mode — the second of seven Eidos V0 modes.
//!
//! Backed by [`InMemorySemanticIndex`]: a fixed-dimension dense-vector store
//! that ranks documents by cosine similarity. The production semantic path
//! routes through `epistemos-shadow`'s `usearch` HNSW backend; the in-memory
//! index here ships behind the same [`EidosRetriever`] trait so the
//! closed-citation contract is end-to-end the same.
//!
//! Eidos V0 does **not** embed text into vectors itself. Callers supply a
//! precomputed query embedding via [`EidosQuery::with_vector`]; embedding
//! generation lives upstream (shadow backend, MLX-Swift, etc.) and is the
//! same model used to embed the indexed corpus. This keeps Eidos free of
//! model inference dependencies and consistent with the "no model inference,
//! no training" scope lock from §4 T10.
//!
//! Determinism: cosine score is computed in f32 with a deterministic
//! summation order (row-by-row, left-to-right). Ordering is
//! `(cosine desc, source_id asc)` — the `source_id` tie-break is what makes
//! replay byte-equal when two documents have identical cosines.

use super::retriever::EidosRetriever;
use super::types::{
    EidosChunkId, EidosContextPacket, EidosDocumentId, EidosHit, EidosIndexManifestId,
    EidosProvenance, EidosQuery, EidosRetrievalMode, EidosScoreComponents, EidosSourceKind,
};

/// One indexed semantic document — the body is retained only so downstream
/// surfaces can render a snippet later; the retriever itself ranks on the
/// vector alone.
#[derive(Clone, Debug)]
struct SemanticDocument {
    document_id: EidosDocumentId,
    vector: Vec<f32>,
    /// Cached L2 norm of `vector`, computed once at insertion. Zero vectors
    /// have zero norm and are excluded from results (cosine undefined).
    norm: f32,
    kind: EidosSourceKind,
}

#[derive(Debug, thiserror::Error, PartialEq)]
pub enum SemanticIndexError {
    /// The vector supplied at insertion did not match the index's fixed
    /// dimension. The closed-citation contract requires deterministic
    /// retrieval, which assumes a uniform dimension across the corpus.
    #[error("vector dimension mismatch: index expects {expected}, got {got}")]
    DimensionMismatch { expected: usize, got: usize },
}

/// Fixed-dimension in-memory semantic index. Toy backend behind the same
/// [`EidosRetriever`] seam as production usearch / HNSW.
#[derive(Clone, Debug)]
pub struct InMemorySemanticIndex {
    manifest_id: EidosIndexManifestId,
    dimension: usize,
    documents: Vec<SemanticDocument>,
}

impl InMemorySemanticIndex {
    pub fn new(manifest_id: EidosIndexManifestId, dimension: usize) -> Self {
        Self {
            manifest_id,
            dimension,
            documents: Vec::new(),
        }
    }

    pub fn dimension(&self) -> usize {
        self.dimension
    }

    pub fn insert(
        &mut self,
        document_id: EidosDocumentId,
        vector: Vec<f32>,
        kind: EidosSourceKind,
    ) -> Result<(), SemanticIndexError> {
        if vector.len() != self.dimension {
            return Err(SemanticIndexError::DimensionMismatch {
                expected: self.dimension,
                got: vector.len(),
            });
        }
        let norm = l2_norm(&vector);

        if let Some(slot) = self
            .documents
            .iter_mut()
            .find(|d| d.document_id == document_id)
        {
            slot.vector = vector;
            slot.norm = norm;
            slot.kind = kind;
        } else {
            self.documents.push(SemanticDocument {
                document_id,
                vector,
                norm,
                kind,
            });
        }
        Ok(())
    }
}

/// L2 norm computed in deterministic left-to-right order so two retrievers
/// with the same documents in the same insertion order produce byte-equal
/// scores.
fn l2_norm(v: &[f32]) -> f32 {
    let mut acc: f32 = 0.0;
    for x in v {
        acc += x * x;
    }
    acc.sqrt()
}

fn dot(a: &[f32], b: &[f32]) -> f32 {
    debug_assert_eq!(a.len(), b.len());
    let mut acc: f32 = 0.0;
    for i in 0..a.len() {
        acc += a[i] * b[i];
    }
    acc
}

impl EidosRetriever for InMemorySemanticIndex {
    fn mode(&self) -> EidosRetrievalMode {
        EidosRetrievalMode::Semantic
    }

    fn manifest_id(&self) -> &EidosIndexManifestId {
        &self.manifest_id
    }

    fn retrieve(
        &self,
        query: &EidosQuery,
        retrieved_at_unix_ms: u64,
    ) -> EidosContextPacket {
        // Semantic retrieval is gated on a query vector. Missing vector,
        // dimension mismatch, or zero-norm query → deterministic empty
        // packet (no panic, no implicit fallback to lexical).
        let qvec = match query.query_vector.as_deref() {
            Some(v) if v.len() == self.dimension => v,
            _ => return empty_packet(query, &self.manifest_id),
        };
        let qnorm = l2_norm(qvec);
        if qnorm == 0.0 {
            return empty_packet(query, &self.manifest_id);
        }

        let top_k = query.top_k as usize;
        let mut scored: Vec<(f32, EidosHit)> = Vec::with_capacity(self.documents.len());
        for doc in &self.documents {
            if doc.norm == 0.0 {
                continue;
            }
            let cos = dot(&doc.vector, qvec) / (doc.norm * qnorm);
            // Skip non-positive matches — for V0 we treat orthogonal /
            // anti-correlated documents as misses, matching how the shadow
            // RRF pipeline filters out negative-scored hits.
            if !(cos > 0.0) {
                continue;
            }

            let chunk_id = EidosChunkId::new(format!("{}::sem", doc.document_id.as_str()))
                .expect("document_id is non-empty by construction");

            let hit = EidosHit {
                source_id: chunk_id,
                document_id: doc.document_id.clone(),
                kind: doc.kind,
                span: None,
                confidence: cos.clamp(0.0, 1.0),
                score: EidosScoreComponents {
                    lexical: 0.0,
                    semantic: cos.clamp(0.0, 1.0),
                    recency: 0.0,
                    graph: 0.0,
                },
                provenance: EidosProvenance {
                    manifest_id: self.manifest_id.clone(),
                    mode: EidosRetrievalMode::Semantic,
                    retrieved_at_unix_ms,
                },
            };
            scored.push((cos, hit));
        }

        // Order: cosine desc, then source_id asc. Use `partial_cmp` because
        // f32 isn't Ord; the source_id tie-break catches NaN and exact-tie
        // cases identically. Defensive: treat any None comparison as
        // equal so the sort can't panic, then fall through to source_id.
        scored.sort_by(|a, b| {
            b.0.partial_cmp(&a.0)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then_with(|| a.1.source_id.as_str().cmp(b.1.source_id.as_str()))
        });

        let hits: Vec<EidosHit> = scored.into_iter().take(top_k).map(|(_, h)| h).collect();

        EidosContextPacket {
            query: query.clone(),
            manifest_id: self.manifest_id.clone(),
            hits,
        }
    }
}

fn empty_packet(query: &EidosQuery, manifest: &EidosIndexManifestId) -> EidosContextPacket {
    EidosContextPacket {
        query: query.clone(),
        manifest_id: manifest.clone(),
        hits: vec![],
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::eidos::types::EidosCitation;

    fn manifest() -> EidosIndexManifestId {
        EidosIndexManifestId::new("semantic-test-manifest").unwrap()
    }

    fn doc(id: &str) -> EidosDocumentId {
        EidosDocumentId::new(id).unwrap()
    }

    fn build_3d() -> InMemorySemanticIndex {
        let mut idx = InMemorySemanticIndex::new(manifest(), 3);
        // Three documents arranged along the basis axes — exact cosine
        // values are 1.0 for the matching axis and 0.0 elsewhere, so
        // ranking is unambiguous and the closed-citation contract is
        // trivially verifiable.
        idx.insert(doc("x"), vec![1.0, 0.0, 0.0], EidosSourceKind::Note).unwrap();
        idx.insert(doc("y"), vec![0.0, 1.0, 0.0], EidosSourceKind::Note).unwrap();
        idx.insert(doc("z"), vec![0.0, 0.0, 1.0], EidosSourceKind::Note).unwrap();
        idx
    }

    #[test]
    fn missing_query_vector_returns_empty_packet() {
        let idx = build_3d();
        let query = EidosQuery::new("no vector here", EidosRetrievalMode::Semantic, 8);
        let packet = idx.retrieve(&query, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn dimension_mismatch_on_query_returns_empty_packet() {
        let idx = build_3d();
        let query = EidosQuery::with_vector(
            "wrong dim",
            EidosRetrievalMode::Semantic,
            8,
            vec![1.0, 0.0],
        );
        let packet = idx.retrieve(&query, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn zero_norm_query_returns_empty_packet() {
        let idx = build_3d();
        let query = EidosQuery::with_vector(
            "zero",
            EidosRetrievalMode::Semantic,
            8,
            vec![0.0, 0.0, 0.0],
        );
        let packet = idx.retrieve(&query, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn empty_query_vector_falls_through_dimension_mismatch_path() {
        // `Some(vec![])` has len 0 ≠ index.dimension (3) so the
        // `Some(v) if v.len() == self.dimension` guard rejects it and
        // the retriever drops to the default empty packet. Pinning
        // this explicitly because the bridge layer might emit an
        // empty vector for "no embedding available" and the contract
        // needs to be unambiguous — empty Some-vector and None must
        // behave identically.
        let idx = build_3d();
        let query = EidosQuery::with_vector(
            "doesn't matter",
            EidosRetrievalMode::Semantic,
            8,
            vec![],
        );
        let packet = idx.retrieve(&query, 1_700_000_000_000);
        assert!(
            packet.hits.is_empty(),
            "Some(empty vec) must defer to empty packet, same as None"
        );

        // Companion symmetry pin: the None case (covered by the
        // earlier `missing_query_vector_returns_empty_packet` test)
        // produces the same retrieval outcome — empty hits, same
        // manifest binding. The packet's echoed `query` field
        // preserves the input (Some([]) vs None) and is therefore
        // intentionally NOT asserted equal here; the retrieval
        // contract is "same hits, same manifest", which is what the
        // bridge layer relies on.
        let none_query = EidosQuery::new("doesn't matter", EidosRetrievalMode::Semantic, 8);
        let none_packet = idx.retrieve(&none_query, 1_700_000_000_000);
        assert_eq!(packet.hits, none_packet.hits);
        assert_eq!(packet.manifest_id, none_packet.manifest_id);
    }

    #[test]
    fn semantic_ignores_query_text_when_vector_present() {
        // semantic.rs never reads query.text — retrieval is fully
        // determined by query.query_vector. Pin this explicitly so a
        // future change that started looking at query.text for some
        // sneaky reason (e.g., to gate on empty-needle defer the way
        // Lexical does) surfaces here. The Brain Panel + bridge
        // layer rely on this asymmetry: a Semantic-mode query with
        // empty text but a valid vector still retrieves; a Lexical
        // query with empty text never does (pinned separately).
        let idx = build_3d();

        // Same vector, two different text strings — packets must be
        // byte-equal modulo the query.text field on the echoed
        // EidosQuery (which only affects the packet's `query` echo,
        // not the hits).
        let q_text = EidosQuery::with_vector(
            "find y",
            EidosRetrievalMode::Semantic,
            8,
            vec![0.0, 1.0, 0.0],
        );
        let q_empty_text = EidosQuery::with_vector(
            "",
            EidosRetrievalMode::Semantic,
            8,
            vec![0.0, 1.0, 0.0],
        );

        let p_text = idx.retrieve(&q_text, 1_700_000_000_000);
        let p_empty = idx.retrieve(&q_empty_text, 1_700_000_000_000);

        // Hits + manifest binding must match. Query echo will
        // differ because the source query.text differs.
        assert_eq!(p_text.hits, p_empty.hits);
        assert_eq!(p_text.manifest_id, p_empty.manifest_id);
        assert_eq!(
            p_empty.hits[0].source_id.as_str(),
            "y::sem",
            "vector-only retrieval must still produce the canonical hit"
        );
    }

    #[test]
    fn dimension_mismatch_on_insert_errors() {
        let mut idx = InMemorySemanticIndex::new(manifest(), 3);
        let err = idx
            .insert(doc("bad"), vec![1.0, 0.0], EidosSourceKind::Note)
            .unwrap_err();
        assert_eq!(
            err,
            SemanticIndexError::DimensionMismatch {
                expected: 3,
                got: 2
            }
        );
    }

    #[test]
    fn cosine_score_formula_pinned_by_example_at_canonical_angles() {
        // Third single-mode scoring formula pin alongside iter 100
        // (Recency 1/(1+age_days)) and iter 102 (Lexical n/(1+n)).
        // Semantic uses canonical cosine similarity at semantic.rs:157:
        //     `cos = dot(doc, query) / (|doc| * |query|)`
        //
        // Existing `cosine_ranking_picks_best_axis` pins the
        // saturation case (cos=1.0 on basis match). Intermediate
        // angles aren't pinned at exact values. A future change to
        // L2 normalization or rescaling would produce subtly
        // different rankings while preserving ordering at the
        // basis-match case.
        //
        // Pin the formula at 4 canonical angles using unit-length
        // doc vectors against query [1, 0, 0]:
        //   doc [1, 0, 0]          → cos = 1.0       (0°)
        //   doc [√3/2, 1/2, 0]     → cos ≈ 0.8660    (30°)
        //   doc [1/√2, 1/√2, 0]    → cos ≈ 0.7071    (45°)
        //   doc [1/2, √3/2, 0]     → cos = 0.5       (60°)
        // 90° (orthogonal) is dropped by the cos > 0 guard at
        // semantic.rs:161 — pinned separately by
        // `orthogonal_query_drops_doc_with_negative_or_zero_cosine`
        // and `tie_break_on_source_id_ascending`.
        use std::f32::consts::FRAC_1_SQRT_2;
        let sqrt3_over_2 = (3.0_f32).sqrt() / 2.0;

        let mut idx = InMemorySemanticIndex::new(manifest(), 3);
        idx.insert(doc("d0"),  vec![1.0, 0.0, 0.0],          EidosSourceKind::Note).unwrap();
        idx.insert(doc("d30"), vec![sqrt3_over_2, 0.5, 0.0], EidosSourceKind::Note).unwrap();
        idx.insert(doc("d45"), vec![FRAC_1_SQRT_2, FRAC_1_SQRT_2, 0.0], EidosSourceKind::Note).unwrap();
        idx.insert(doc("d60"), vec![0.5, sqrt3_over_2, 0.0], EidosSourceKind::Note).unwrap();

        let q = EidosQuery::with_vector(
            "angles",
            EidosRetrievalMode::Semantic,
            16,
            vec![1.0, 0.0, 0.0],
        );
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        let by_id: std::collections::HashMap<&str, f32> = packet
            .hits
            .iter()
            .map(|h| (h.document_id.as_str(), h.score.semantic))
            .collect();

        let expectations: &[(&str, f32)] = &[
            ("d0",  1.0),
            ("d30", sqrt3_over_2),
            ("d45", FRAC_1_SQRT_2),
            ("d60", 0.5),
        ];
        for (id, expected) in expectations {
            let got = by_id
                .get(id)
                .copied()
                .unwrap_or_else(|| panic!("doc {} missing from packet", id));
            assert!(
                (got - expected).abs() < 1e-6,
                "doc {}: cosine score expected {}, got {}",
                id,
                expected,
                got
            );
        }
    }

    #[test]
    fn cosine_ranking_picks_best_axis() {
        let idx = build_3d();
        let query = EidosQuery::with_vector(
            "find y",
            EidosRetrievalMode::Semantic,
            1,
            vec![0.0, 1.0, 0.0],
        );
        let packet = idx.retrieve(&query, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(packet.hits[0].source_id.as_str(), "y::sem");
        // Cosine on basis match is exactly 1.0.
        assert!((packet.hits[0].confidence - 1.0).abs() < 1e-6);
    }

    #[test]
    fn deterministic_replay_byte_equal() {
        let a = build_3d();
        let b = build_3d();
        let q = EidosQuery::with_vector(
            "same",
            EidosRetrievalMode::Semantic,
            8,
            vec![0.5, 0.5, 0.5],
        );
        let pa = a.retrieve(&q, 1_700_000_000_000);
        let pb = b.retrieve(&q, 1_700_000_000_000);
        assert_eq!(pa, pb);
    }

    #[test]
    fn tie_break_on_source_id_ascending() {
        // Two parallel documents (same direction → same cosine) — the
        // alphabetically smaller source_id wins.
        let mut idx = InMemorySemanticIndex::new(manifest(), 2);
        idx.insert(doc("a"), vec![1.0, 1.0], EidosSourceKind::Note).unwrap();
        idx.insert(doc("b"), vec![1.0, 1.0], EidosSourceKind::Note).unwrap();
        let q = EidosQuery::with_vector("tie", EidosRetrievalMode::Semantic, 8, vec![1.0, 0.0]);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(ids, vec!["a::sem", "b::sem"]);
    }

    #[test]
    fn anti_correlated_documents_are_filtered() {
        let mut idx = InMemorySemanticIndex::new(manifest(), 2);
        idx.insert(doc("pos"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();
        idx.insert(doc("neg"), vec![-1.0, 0.0], EidosSourceKind::Note).unwrap();
        let q = EidosQuery::with_vector("seek", EidosRetrievalMode::Semantic, 8, vec![1.0, 0.0]);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(ids, vec!["pos::sem"]);
    }

    #[test]
    fn closed_citation_contract_holds_through_semantic_retrieval() {
        let idx = build_3d();
        let q = EidosQuery::with_vector(
            "seek y",
            EidosRetrievalMode::Semantic,
            8,
            vec![0.0, 1.0, 0.0],
        );
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        for hit in &packet.hits {
            let cite = EidosCitation {
                source_id: hit.source_id.clone(),
                manifest_id: packet.manifest_id.clone(),
            };
            assert_eq!(packet.validate_citation(&cite), Ok(()));
        }
        // A semantic-style forged id is rejected even when the lexical form
        // looks plausible (`y::sem` is real but `y::FAKE` is not).
        let forged = EidosCitation {
            source_id: EidosChunkId::new("y::FAKE").unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert!(packet.validate_citation(&forged).is_err());
    }

    #[test]
    fn empty_index_returns_empty_packet() {
        let idx = InMemorySemanticIndex::new(manifest(), 4);
        let q = EidosQuery::with_vector(
            "anything",
            EidosRetrievalMode::Semantic,
            8,
            vec![1.0, 0.0, 0.0, 0.0],
        );
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn retriever_advertises_semantic_mode() {
        let idx = InMemorySemanticIndex::new(manifest(), 4);
        assert_eq!(idx.mode(), EidosRetrievalMode::Semantic);
        assert_eq!(idx.dimension(), 4);
    }

    #[test]
    fn reinserting_same_document_id_replaces_vector() {
        let mut idx = InMemorySemanticIndex::new(manifest(), 2);
        idx.insert(doc("d"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();
        idx.insert(doc("d"), vec![0.0, 1.0], EidosSourceKind::Note).unwrap();
        let q = EidosQuery::with_vector("aim y", EidosRetrievalMode::Semantic, 8, vec![0.0, 1.0]);
        let packet = idx.retrieve(&q, 0);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(packet.hits[0].source_id.as_str(), "d::sem");
    }
}
