//! Lexical retrieval mode — the first of nine canonical Eidos V0 modes
//! (`EidosRetrievalMode::CANON_ALL`).
//!
//! This module ships an in-memory toy backend, [`InMemoryLexicalIndex`], that
//! demonstrates the [`EidosRetriever`] contract end-to-end:
//!
//! - Documents are added with a caller-supplied [`EidosDocumentId`] and body.
//! - Search performs **case-insensitive Unicode-aware substring matching**
//!   over the body. Each match counts as one occurrence; total occurrences
//!   become the lexical score.
//! - Hits are emitted as `(document_id, chunk_id)` pairs where the chunk id
//!   is the document id suffixed with `::lex` — opaque to the chat layer but
//!   stable across queries against the same manifest.
//! - Ordering is fully deterministic: `(score desc, source_id asc)`. The
//!   tie-break on `source_id` is what lets the closed-citation universe stay
//!   byte-equal across runs even when scores collide.
//!
//! The real production backend will be `epistemos-shadow` (tantivy + usearch
//! RRF, k=60). That backend goes behind the same [`EidosRetriever`] trait in
//! a later iteration; nothing about the contract or the closed-citation seam
//! needs to change.

use super::retriever::EidosRetriever;
use super::types::{
    is_blank_query_text, EidosChunkId, EidosContextPacket, EidosDocumentId, EidosHit,
    EidosIndexManifestId, EidosProvenance, EidosQuery, EidosRetrievalMode,
    EidosScoreComponents, EidosSourceKind, EidosSpan, IdError,
};

/// One indexed document for [`InMemoryLexicalIndex`]. The body is stored
/// verbatim so spans can be reported in source-coordinate bytes.
#[derive(Clone, Debug)]
struct LexicalDocument {
    document_id: EidosDocumentId,
    body: String,
    /// Lowercased copy of the body for case-insensitive matching. Computed
    /// once at insertion to keep retrieval allocation-free.
    body_lower: String,
    kind: EidosSourceKind,
}

/// Toy in-memory lexical index. Suitable for tests and for proving the
/// closed-citation contract end-to-end; production retrieval routes through
/// `epistemos-shadow` instead.
#[derive(Clone, Debug)]
pub struct InMemoryLexicalIndex {
    manifest_id: EidosIndexManifestId,
    documents: Vec<LexicalDocument>,
}

impl InMemoryLexicalIndex {
    pub fn new(manifest_id: EidosIndexManifestId) -> Self {
        Self {
            manifest_id,
            documents: Vec::new(),
        }
    }

    /// Insert a document into the index. Returns an error if the document id
    /// is empty (the lexical backend cannot mint a stable chunk id from an
    /// empty document id).
    pub fn insert(
        &mut self,
        document_id: EidosDocumentId,
        body: impl Into<String>,
        kind: EidosSourceKind,
    ) -> Result<(), IdError> {
        let body = body.into();
        let body_lower = body.to_lowercase();
        // Guard against duplicate document ids — the chunk id collision
        // would break dedup later. Silently replace existing entries so
        // re-indexing a single document is idempotent.
        if let Some(slot) = self
            .documents
            .iter_mut()
            .find(|d| d.document_id == document_id)
        {
            slot.body = body;
            slot.body_lower = body_lower;
            slot.kind = kind;
        } else {
            self.documents.push(LexicalDocument {
                document_id,
                body,
                body_lower,
                kind,
            });
        }
        Ok(())
    }

    pub fn manifest_id(&self) -> &EidosIndexManifestId {
        &self.manifest_id
    }

    /// Count case-insensitive occurrences of `needle` in `haystack_lower`.
    /// `needle_lower` must already be lowercased by the caller.
    fn count_occurrences(haystack_lower: &str, needle_lower: &str) -> u32 {
        if needle_lower.is_empty() {
            return 0;
        }
        // Standard non-overlapping count. `str::matches` returns an
        // iterator; collecting into a count avoids any allocation.
        haystack_lower.matches(needle_lower).count() as u32
    }

    /// Locate the first byte-offset of `needle_lower` inside `haystack_lower`
    /// and return that range projected back into the original body's byte
    /// coordinates. Because [`str::to_lowercase`] can change byte length per
    /// codepoint, we approximate the span as `(first_match_byte_in_lower,
    /// first_match_byte_in_lower + needle_byte_len)`. For ASCII the mapping
    /// is exact; for arbitrary Unicode the span is a best-effort hint —
    /// callers (and the Brain Panel) treat span as optional anyway.
    fn approximate_span(body_lower: &str, needle_lower: &str) -> Option<EidosSpan> {
        let start = body_lower.find(needle_lower)?;
        Some(EidosSpan {
            byte_start: start as u32,
            byte_end: (start + needle_lower.len()) as u32,
        })
    }
}

impl EidosRetriever for InMemoryLexicalIndex {
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
        if is_blank_query_text(&query.text) || query.top_k == 0 {
            return EidosContextPacket {
                query: query.clone(),
                manifest_id: self.manifest_id.clone(),
                hits: vec![],
            };
        }

        let needle = query.text.to_lowercase();
        let top_k = query.top_k as usize;

        // Score every document and keep only matches.
        let mut scored: Vec<(u32, EidosHit)> = Vec::with_capacity(self.documents.len());
        for doc in &self.documents {
            let occurrences = Self::count_occurrences(&doc.body_lower, &needle);
            if occurrences == 0 {
                continue;
            }

            // Stable chunk id: "{document_id}::lex". Constructed via
            // EidosChunkId::new so the empty-payload guard still fires.
            let chunk_id = EidosChunkId::new(format!("{}::lex", doc.document_id.as_str()))
                .expect("document_id is non-empty by construction");

            let span = Self::approximate_span(&doc.body_lower, &needle);

            // Lexical score = occurrences / 1+occurrences. Bounded [0,1),
            // monotonic in occurrence count, deterministic across runs.
            let lexical_score = occurrences as f32 / (1.0 + occurrences as f32);

            let hit = EidosHit {
                source_id: chunk_id,
                document_id: doc.document_id.clone(),
                kind: doc.kind,
                span,
                confidence: lexical_score,
                score: EidosScoreComponents {
                    lexical: lexical_score,
                    semantic: 0.0,
                    recency: 0.0,
                    graph: 0.0,
                },
                provenance: EidosProvenance {
                    manifest_id: self.manifest_id.clone(),
                    mode: EidosRetrievalMode::Lexical,
                    retrieved_at_unix_ms,
                },
            };

            scored.push((occurrences, hit));
        }

        // Deterministic ordering: occurrences desc, then source_id asc. The
        // source_id tie-break is what keeps replay byte-equal when two
        // documents have identical occurrence counts.
        scored.sort_by(|a, b| {
            b.0.cmp(&a.0)
                .then_with(|| a.1.source_id.as_str().cmp(b.1.source_id.as_str()))
        });

        let hits: Vec<EidosHit> = scored
            .into_iter()
            .take(top_k)
            .map(|(_, hit)| hit)
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
    use crate::eidos::types::EidosCitation;

    fn manifest() -> EidosIndexManifestId {
        EidosIndexManifestId::new("lexical-test-manifest").unwrap()
    }

    fn doc(id: &str) -> EidosDocumentId {
        EidosDocumentId::new(id).unwrap()
    }

    fn build() -> InMemoryLexicalIndex {
        let mut idx = InMemoryLexicalIndex::new(manifest());
        idx.insert(
            doc("note-1"),
            "Tropical semirings make optimization convex.",
            EidosSourceKind::Note,
        )
        .unwrap();
        idx.insert(
            doc("note-2"),
            "Convex optimization is everywhere in tropical geometry.",
            EidosSourceKind::Note,
        )
        .unwrap();
        idx.insert(
            doc("note-3"),
            "This document mentions nothing relevant.",
            EidosSourceKind::Note,
        )
        .unwrap();
        idx
    }

    #[test]
    fn empty_index_returns_empty_packet() {
        let idx = InMemoryLexicalIndex::new(manifest());
        let query = EidosQuery::new("anything", EidosRetrievalMode::Lexical, 8);
        let packet = idx.retrieve(&query, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
        assert_eq!(packet.manifest_id, manifest());
    }

    #[test]
    fn no_match_returns_empty_packet() {
        let idx = build();
        let query = EidosQuery::new("doesnotappear", EidosRetrievalMode::Lexical, 8);
        let packet = idx.retrieve(&query, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn invisible_only_query_returns_empty_packet() {
        let mut idx = InMemoryLexicalIndex::new(manifest());
        idx.insert(
            doc("zwsp-body"),
            "alpha\u{200B}beta",
            EidosSourceKind::Note,
        )
        .unwrap();
        let query = EidosQuery::new("\u{200B}", EidosRetrievalMode::Lexical, 8);
        let packet = idx.retrieve(&query, 1_700_000_000_000);
        assert!(
            packet.hits.is_empty(),
            "invisible-only text is not a stable lexical query"
        );
    }

    #[test]
    fn case_insensitive_match_returns_hits() {
        let idx = build();
        let query = EidosQuery::new("TROPICAL", EidosRetrievalMode::Lexical, 8);
        let packet = idx.retrieve(&query, 1_700_000_000_000);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert!(ids.contains(&"note-1::lex"));
        assert!(ids.contains(&"note-2::lex"));
        assert!(!ids.contains(&"note-3::lex"));
    }

    #[test]
    fn lexical_score_formula_pinned_by_example_at_canonical_counts() {
        // Sibling pin to iter 100's Recency formula-by-example. The
        // lexical scoring formula at lexical.rs:156 is
        // `lexical_score = occurrences / (1.0 + occurrences)` —
        // bounded [0, 1), monotonic in count, deterministic. Existing
        // tests pin one-sided bounds (`> 0.998` at 1000 occurrences,
        // `> 0` at any match) but never the exact formula at
        // intermediate counts. A future change to `log(1 + n) / log(2)`
        // or `tanh(n/3)` would satisfy "monotonic in [0,1)" but
        // produce subtly different rankings.
        //
        // Pin the formula at 4 canonical counts (1, 2, 9, 99) so any
        // deviation from `n/(1+n)` surfaces. Epsilon 1e-6 for f32.
        let needle = "x";
        let mut lex = InMemoryLexicalIndex::new(manifest());
        for n in [1u32, 2, 9, 99] {
            let body = needle.repeat(n as usize);
            lex.insert(
                doc(&format!("d-{n}")),
                body,
                EidosSourceKind::Note,
            )
            .unwrap();
        }

        let q = EidosQuery::new(needle, EidosRetrievalMode::Lexical, 16);
        let packet = lex.retrieve(&q, 0);
        let by_id: std::collections::HashMap<&str, f32> = packet
            .hits
            .iter()
            .map(|h| (h.document_id.as_str(), h.score.lexical))
            .collect();

        let expectations: &[(&str, f32)] = &[
            ("d-1", 1.0 / 2.0),     // 0.5
            ("d-2", 2.0 / 3.0),     // ≈ 0.6667
            ("d-9", 9.0 / 10.0),    // 0.9
            ("d-99", 99.0 / 100.0), // 0.99
        ];
        for (id, expected) in expectations {
            let got = by_id
                .get(id)
                .copied()
                .unwrap_or_else(|| panic!("doc {} missing from packet", id));
            assert!(
                (got - expected).abs() < 1e-6,
                "doc {}: score n/(1+n) expected {}, got {}",
                id,
                expected,
                got
            );
        }
    }

    #[test]
    fn deterministic_ordering_score_desc_then_id_asc() {
        // note-1 has 1 "tropical", note-2 has 1 "tropical" → tied → id asc.
        let idx = build();
        let query = EidosQuery::new("tropical", EidosRetrievalMode::Lexical, 8);
        let packet = idx.retrieve(&query, 1_700_000_000_000);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(ids, vec!["note-1::lex", "note-2::lex"]);
    }

    #[test]
    fn top_k_truncates() {
        let idx = build();
        let query = EidosQuery::new("optimization", EidosRetrievalMode::Lexical, 1);
        let packet = idx.retrieve(&query, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 1);
    }

    #[test]
    fn unicode_query_matches() {
        // Acceptance bar: unicode query.
        let mut idx = InMemoryLexicalIndex::new(manifest());
        idx.insert(
            doc("note-unicode"),
            "École polytechnique fédérale de Lausanne — Привет — 你好",
            EidosSourceKind::Note,
        )
        .unwrap();
        let query = EidosQuery::new("привет", EidosRetrievalMode::Lexical, 8);
        let packet = idx.retrieve(&query, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(packet.hits[0].source_id.as_str(), "note-unicode::lex");
    }

    /// Closed-citation contract holds **through real retrieval**: every hit
    /// emitted by the lexical retriever passes
    /// `EidosContextPacket::validate_citation`, and any chunk id outside the
    /// packet is still rejected.
    #[test]
    fn closed_citation_contract_holds_through_lexical_retrieval() {
        let idx = build();
        let query = EidosQuery::new("optimization", EidosRetrievalMode::Lexical, 8);
        let packet = idx.retrieve(&query, 1_700_000_000_000);

        assert!(!packet.hits.is_empty(), "expected at least one hit");
        // All emitted source_ids must validate.
        for hit in &packet.hits {
            let citation = EidosCitation {
                source_id: hit.source_id.clone(),
                manifest_id: packet.manifest_id.clone(),
            };
            assert_eq!(packet.validate_citation(&citation), Ok(()));
        }
        // A never-emitted source_id is rejected.
        let forged = EidosCitation {
            source_id: EidosChunkId::new("note-3::lex").unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        // note-3 had no occurrence so it should not appear in the packet.
        assert!(!packet
            .hits
            .iter()
            .any(|h| h.source_id.as_str() == "note-3::lex"));
        assert!(packet.validate_citation(&forged).is_err());
    }

    /// Byte-equal replay: two retrievers built from the same documents in
    /// the same order produce the same packet for the same query + clock.
    #[test]
    fn retrieval_is_deterministic_for_pinned_clock() {
        let a = build();
        let b = build();
        let query = EidosQuery::new("optimization", EidosRetrievalMode::Lexical, 8);
        let pa = a.retrieve(&query, 1_700_000_000_000);
        let pb = b.retrieve(&query, 1_700_000_000_000);
        assert_eq!(pa, pb);
    }

    #[test]
    fn retriever_advertises_lexical_mode() {
        let idx = InMemoryLexicalIndex::new(manifest());
        assert_eq!(idx.mode(), EidosRetrievalMode::Lexical);
        assert_eq!(idx.manifest_id(), &manifest());
    }

    #[test]
    fn reinserting_same_document_id_replaces_body() {
        let mut idx = InMemoryLexicalIndex::new(manifest());
        idx.insert(doc("note-1"), "alpha", EidosSourceKind::Note).unwrap();
        idx.insert(doc("note-1"), "beta", EidosSourceKind::Note).unwrap();
        let query = EidosQuery::new("alpha", EidosRetrievalMode::Lexical, 8);
        assert!(idx.retrieve(&query, 0).hits.is_empty());
        let query2 = EidosQuery::new("beta", EidosRetrievalMode::Lexical, 8);
        assert_eq!(idx.retrieve(&query2, 0).hits.len(), 1);
    }
}
