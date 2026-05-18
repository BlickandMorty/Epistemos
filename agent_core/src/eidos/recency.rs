//! Recency retrieval mode — time-ordered retrieval.
//!
//! Unlike the other retrievers, Recency treats an **empty** `query.text` as
//! a meaningful query ("no substring filter, give me top_k most recent
//! documents") rather than the empty-defer convention used elsewhere. The
//! reason: "what did I most recently capture?" is a real closed-citation
//! query, and forcing the chat layer to invent a substring just to use the
//! mode would make Recency hostile to use.
//!
//! Non-empty `query.text` is a case-insensitive Unicode-aware substring
//! filter (same shape as Lexical) — documents whose body does not contain
//! the substring are dropped before recency sort.
//!
//! Deterministic ordering: `(created_at_unix_ms desc, source_id asc)`. The
//! source_id tie-break is what keeps replay byte-equal when two documents
//! share an exact timestamp.
//!
//! Recency score is `1.0 / (1.0 + age_days)` where `age_days =
//! (retrieved_at - created_at).saturating_sub(0) / 86_400_000`. A document
//! created exactly at `retrieved_at` scores 1.0; one day old scores 0.5; one
//! week old scores ~0.125. Saturating subtraction guards against clock
//! skew (created_at > retrieved_at): the score in that case is 1.0, which
//! is safe because Recency never claims to verify timestamps — that's
//! Provenance's job.

use super::retriever::EidosRetriever;
use super::types::{
    EidosChunkId, EidosContextPacket, EidosDocumentId, EidosHit, EidosIndexManifestId,
    EidosProvenance, EidosQuery, EidosRetrievalMode, EidosScoreComponents, EidosSourceKind,
};

const ONE_DAY_MS: u64 = 86_400_000;

#[derive(Clone, Debug)]
struct RecencyDocument {
    document_id: EidosDocumentId,
    body: String,
    body_lower: String,
    created_at_unix_ms: u64,
    kind: EidosSourceKind,
}

#[derive(Clone, Debug)]
pub struct InMemoryRecencyIndex {
    manifest_id: EidosIndexManifestId,
    documents: Vec<RecencyDocument>,
}

impl InMemoryRecencyIndex {
    pub fn new(manifest_id: EidosIndexManifestId) -> Self {
        Self {
            manifest_id,
            documents: Vec::new(),
        }
    }

    pub fn insert(
        &mut self,
        document_id: EidosDocumentId,
        body: impl Into<String>,
        created_at_unix_ms: u64,
        kind: EidosSourceKind,
    ) {
        let body = body.into();
        let body_lower = body.to_lowercase();
        if let Some(slot) = self
            .documents
            .iter_mut()
            .find(|d| d.document_id == document_id)
        {
            slot.body = body;
            slot.body_lower = body_lower;
            slot.created_at_unix_ms = created_at_unix_ms;
            slot.kind = kind;
        } else {
            self.documents.push(RecencyDocument {
                document_id,
                body,
                body_lower,
                created_at_unix_ms,
                kind,
            });
        }
    }

    fn score(retrieved_at_unix_ms: u64, created_at_unix_ms: u64) -> f32 {
        let age_ms = retrieved_at_unix_ms.saturating_sub(created_at_unix_ms);
        let age_days = age_ms as f32 / ONE_DAY_MS as f32;
        1.0 / (1.0 + age_days)
    }
}

impl EidosRetriever for InMemoryRecencyIndex {
    fn mode(&self) -> EidosRetrievalMode {
        EidosRetrievalMode::Recency
    }

    fn manifest_id(&self) -> &EidosIndexManifestId {
        &self.manifest_id
    }

    fn retrieve(
        &self,
        query: &EidosQuery,
        retrieved_at_unix_ms: u64,
    ) -> EidosContextPacket {
        if query.top_k == 0 {
            return empty_packet(query, &self.manifest_id);
        }

        // Empty filter text is meaningful — "no substring filter, give me
        // top_k most recent". Non-empty filters as case-insensitive
        // substring (matching Lexical's semantics).
        let filter: Option<String> = if query.text.is_empty() {
            None
        } else {
            Some(query.text.to_lowercase())
        };

        let mut sorted: Vec<&RecencyDocument> = self
            .documents
            .iter()
            .filter(|d| match &filter {
                None => true,
                Some(needle) => d.body_lower.contains(needle),
            })
            .collect();

        sorted.sort_by(|a, b| {
            b.created_at_unix_ms
                .cmp(&a.created_at_unix_ms)
                .then_with(|| a.document_id.as_str().cmp(b.document_id.as_str()))
        });

        let top_k = query.top_k as usize;
        let hits: Vec<EidosHit> = sorted
            .into_iter()
            .take(top_k)
            .map(|doc| {
                let chunk_id =
                    EidosChunkId::new(format!("{}::recency", doc.document_id.as_str()))
                        .expect("document_id non-empty by construction");
                let recency_score = Self::score(retrieved_at_unix_ms, doc.created_at_unix_ms);
                EidosHit {
                    source_id: chunk_id,
                    document_id: doc.document_id.clone(),
                    kind: doc.kind,
                    span: None,
                    confidence: recency_score.clamp(0.0, 1.0),
                    score: EidosScoreComponents {
                        lexical: 0.0,
                        semantic: 0.0,
                        recency: recency_score.clamp(0.0, 1.0),
                        graph: 0.0,
                    },
                    provenance: EidosProvenance {
                        manifest_id: self.manifest_id.clone(),
                        mode: EidosRetrievalMode::Recency,
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
        EidosIndexManifestId::new("recency-test-manifest").unwrap()
    }

    fn doc(id: &str) -> EidosDocumentId {
        EidosDocumentId::new(id).unwrap()
    }

    const T0: u64 = 1_700_000_000_000;

    fn build() -> InMemoryRecencyIndex {
        let mut idx = InMemoryRecencyIndex::new(manifest());
        idx.insert(doc("week-old"), "alpha content", T0 - 7 * ONE_DAY_MS, EidosSourceKind::Note);
        idx.insert(doc("yesterday"), "alpha gamma", T0 - ONE_DAY_MS, EidosSourceKind::Note);
        idx.insert(doc("today"), "alpha beta", T0, EidosSourceKind::Note);
        idx
    }

    #[test]
    fn recency_returns_top_k_most_recent_ordering() {
        let idx = build();
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        // Today first, then yesterday, then week-old. Source_id is suffixed
        // ::recency, so the ordering tie-break doesn't change the headline.
        assert_eq!(
            ids,
            vec![
                "today::recency",
                "yesterday::recency",
                "week-old::recency",
            ]
        );
    }

    #[test]
    fn recency_with_substring_filter_narrows_then_orders() {
        let idx = build();
        // "gamma" only matches yesterday's body. Today + week-old drop.
        let q = EidosQuery::new("gamma", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(ids, vec!["yesterday::recency"]);
    }

    #[test]
    fn recency_substring_filter_is_case_insensitive() {
        let idx = build();
        let q = EidosQuery::new("ALPHA", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        // All three contain "alpha"; ordering by recency.
        assert_eq!(packet.hits.len(), 3);
        assert_eq!(packet.hits[0].source_id.as_str(), "today::recency");
    }

    #[test]
    fn recency_score_decreases_with_age() {
        let idx = build();
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        // 3 hits: today (age 0d → 1.0), yesterday (age 1d → 0.5),
        // week-old (age 7d → 0.125).
        assert!((packet.hits[0].score.recency - 1.0).abs() < 1e-6);
        assert!((packet.hits[1].score.recency - 0.5).abs() < 1e-6);
        assert!((packet.hits[2].score.recency - 0.125).abs() < 1e-6);
    }

    #[test]
    fn empty_index_returns_empty_packet() {
        let idx = InMemoryRecencyIndex::new(manifest());
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn top_k_zero_returns_empty_packet() {
        let idx = build();
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 0);
        let packet = idx.retrieve(&q, T0);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn top_k_truncates_to_most_recent() {
        let idx = build();
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 1);
        let packet = idx.retrieve(&q, T0);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(packet.hits[0].source_id.as_str(), "today::recency");
    }

    #[test]
    fn tie_break_on_source_id_when_timestamps_match() {
        let mut idx = InMemoryRecencyIndex::new(manifest());
        idx.insert(doc("b"), "x", T0, EidosSourceKind::Note);
        idx.insert(doc("a"), "x", T0, EidosSourceKind::Note);
        idx.insert(doc("c"), "x", T0, EidosSourceKind::Note);
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        // Same timestamp → source_id ascending.
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(ids, vec!["a::recency", "b::recency", "c::recency"]);
    }

    #[test]
    fn closed_citation_contract_holds_through_recency() {
        let idx = build();
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        for hit in &packet.hits {
            let cite = EidosCitation {
                source_id: hit.source_id.clone(),
                manifest_id: packet.manifest_id.clone(),
            };
            assert_eq!(packet.validate_citation(&cite), Ok(()));
        }
        // A doc that exists in the index but didn't pass the substring
        // filter is NOT citable through the filtered packet.
        let filtered_q = EidosQuery::new("gamma", EidosRetrievalMode::Recency, 16);
        let filtered_packet = idx.retrieve(&filtered_q, T0);
        let dropped = EidosCitation {
            source_id: EidosChunkId::new("today::recency").unwrap(),
            manifest_id: filtered_packet.manifest_id.clone(),
        };
        assert!(filtered_packet.validate_citation(&dropped).is_err());
    }

    #[test]
    fn replay_byte_equal_for_pinned_clock() {
        let a = build();
        let b = build();
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
        assert_eq!(a.retrieve(&q, T0), b.retrieve(&q, T0));
    }

    #[test]
    fn retriever_advertises_recency_mode() {
        let idx = InMemoryRecencyIndex::new(manifest());
        assert_eq!(idx.mode(), EidosRetrievalMode::Recency);
        assert_eq!(idx.manifest_id(), &manifest());
    }

    #[test]
    fn clock_skew_doc_in_the_future_scores_one_no_panic() {
        // saturating_sub guards against created_at > retrieved_at. The doc
        // appears at recency 1.0 (we don't try to verify timestamps — that
        // is Provenance's job).
        let mut idx = InMemoryRecencyIndex::new(manifest());
        idx.insert(doc("future"), "x", T0 + 10 * ONE_DAY_MS, EidosSourceKind::Note);
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        assert_eq!(packet.hits.len(), 1);
        assert!((packet.hits[0].score.recency - 1.0).abs() < 1e-6);
    }

    #[test]
    fn unicode_filter_text_works() {
        let mut idx = InMemoryRecencyIndex::new(manifest());
        idx.insert(doc("note-1"), "École polytechnique", T0, EidosSourceKind::Note);
        idx.insert(
            doc("note-2"),
            "Привет world",
            T0 - ONE_DAY_MS,
            EidosSourceKind::Note,
        );
        let q = EidosQuery::new("привет", EidosRetrievalMode::Recency, 16);
        let packet = idx.retrieve(&q, T0);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(packet.hits[0].source_id.as_str(), "note-2::recency");
    }
}
