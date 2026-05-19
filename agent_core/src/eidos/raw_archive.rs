//! RawArchive retrieval mode — exact `EidosDocumentId` lookup.
//!
//! The simplest of the nine canonical retrieval modes
//! (`EidosRetrievalMode::CANON_ALL`): the query text is interpreted
//! as the **literal** document id to fetch. No fuzzy matching, no scoring,
//! no ranking — either the id is present or it is not. Useful for:
//!
//! - the "open this specific vault file" flow (Brain Panel → "Show source"),
//! - replay paths where a packet's `EidosCitation` needs to be re-resolved
//!   into the underlying body bytes,
//! - the no-result defer path in retrieval: a missing id is a deterministic
//!   empty packet, not an error, so callers can safely treat
//!   "no such document" as "do not cite."
//!
//! RawArchive's hits emit `source_id = "{document_id}::raw"` with the span
//! covering the entire body. Confidence is always `1.0` because the
//! retrieval is exact.

use super::retriever::EidosRetriever;
use super::types::{
    is_blank_query_text, EidosChunkId, EidosContextPacket, EidosDocumentId, EidosHit,
    EidosIndexManifestId, EidosProvenance, EidosQuery, EidosRetrievalMode,
    EidosScoreComponents, EidosSourceKind, EidosSpan,
};

/// One archived document in the toy raw-archive backend.
#[derive(Clone, Debug)]
struct ArchivedDocument {
    body: String,
    kind: EidosSourceKind,
}

/// In-memory exact-id archive. Production wiring will route this through the
/// vault's path / id store; the trait surface is unchanged.
#[derive(Clone, Debug)]
pub struct InMemoryRawArchive {
    manifest_id: EidosIndexManifestId,
    // BTreeMap so iteration order is deterministic (matters for any future
    // bulk-listing variant; not strictly required for exact-id lookup).
    entries: std::collections::BTreeMap<EidosDocumentId, ArchivedDocument>,
}

impl InMemoryRawArchive {
    pub fn new(manifest_id: EidosIndexManifestId) -> Self {
        Self {
            manifest_id,
            entries: std::collections::BTreeMap::new(),
        }
    }

    pub fn insert(
        &mut self,
        document_id: EidosDocumentId,
        body: impl Into<String>,
        kind: EidosSourceKind,
    ) {
        self.entries.insert(
            document_id,
            ArchivedDocument {
                body: body.into(),
                kind,
            },
        );
    }
}

impl EidosRetriever for InMemoryRawArchive {
    fn mode(&self) -> EidosRetrievalMode {
        EidosRetrievalMode::RawArchive
    }

    fn manifest_id(&self) -> &EidosIndexManifestId {
        &self.manifest_id
    }

    fn retrieve(
        &self,
        query: &EidosQuery,
        retrieved_at_unix_ms: u64,
    ) -> EidosContextPacket {
        // Empty query text is *not* a wildcard. Treat as no-result defer so
        // callers cannot accidentally bulk-fetch the archive.
        if is_blank_query_text(&query.text) {
            return empty_packet(query, &self.manifest_id);
        }
        if query.top_k == 0 {
            return empty_packet(query, &self.manifest_id);
        }

        // Build the candidate document id. Construction enforces the
        // empty-payload invariant from the type layer; an empty query text
        // is already guarded above, so this `unwrap` is unreachable.
        let needle = match EidosDocumentId::new(query.text.clone()) {
            Ok(id) => id,
            Err(_) => return empty_packet(query, &self.manifest_id),
        };

        let Some(doc) = self.entries.get(&needle) else {
            return empty_packet(query, &self.manifest_id);
        };

        let chunk_id = EidosChunkId::new(format!("{}::raw", needle.as_str()))
            .expect("document id is non-empty by construction");

        let hit = EidosHit {
            source_id: chunk_id,
            document_id: needle.clone(),
            kind: doc.kind,
            span: Some(EidosSpan {
                byte_start: 0,
                byte_end: doc.body.len() as u32,
            }),
            confidence: 1.0,
            score: EidosScoreComponents::default(),
            provenance: EidosProvenance {
                manifest_id: self.manifest_id.clone(),
                mode: EidosRetrievalMode::RawArchive,
                retrieved_at_unix_ms,
            },
        };

        EidosContextPacket {
            query: query.clone(),
            manifest_id: self.manifest_id.clone(),
            hits: vec![hit],
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
        EidosIndexManifestId::new("raw-test-manifest").unwrap()
    }

    fn doc(id: &str) -> EidosDocumentId {
        EidosDocumentId::new(id).unwrap()
    }

    fn build() -> InMemoryRawArchive {
        let mut a = InMemoryRawArchive::new(manifest());
        a.insert(doc("note-001"), "first note body", EidosSourceKind::Note);
        a.insert(doc("epdoc-tropical"), "{\"kind\":\"epdoc\"}", EidosSourceKind::Epdoc);
        a.insert(doc("chat-2024-01-01"), "chat transcript", EidosSourceKind::Chat);
        a
    }

    #[test]
    fn exact_id_hit_returns_single_chunk() {
        let archive = build();
        let q = EidosQuery::new("note-001", EidosRetrievalMode::RawArchive, 8);
        let packet = archive.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(packet.hits[0].source_id.as_str(), "note-001::raw");
        assert_eq!(packet.hits[0].document_id.as_str(), "note-001");
        assert_eq!(packet.hits[0].kind, EidosSourceKind::Note);
        let span = packet.hits[0].span.unwrap();
        assert_eq!(span.byte_start, 0);
        assert_eq!(span.byte_end, "first note body".len() as u32);
        assert_eq!(packet.hits[0].confidence, 1.0);
    }

    #[test]
    fn epdoc_projection_hit_routes_to_epdoc_kind() {
        // Acceptance bar covers ".epdoc projection hit"; raw archive is one
        // of the surfaces a chat can request a projected source through.
        let archive = build();
        let q = EidosQuery::new("epdoc-tropical", EidosRetrievalMode::RawArchive, 8);
        let packet = archive.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(packet.hits[0].kind, EidosSourceKind::Epdoc);
    }

    #[test]
    fn missing_id_returns_empty_packet() {
        let archive = build();
        let q = EidosQuery::new("does-not-exist", EidosRetrievalMode::RawArchive, 8);
        let packet = archive.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
        // Closed-citation universe is empty → every citation rejected.
        let any = EidosCitation {
            source_id: EidosChunkId::new("anything::raw").unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert!(packet.validate_citation(&any).is_err());
    }

    #[test]
    fn empty_query_text_returns_empty_packet() {
        // RawArchive must NOT treat empty text as a wildcard / list-all.
        let archive = build();
        let q = EidosQuery::new("", EidosRetrievalMode::RawArchive, 8);
        let packet = archive.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn whitespace_only_query_text_returns_empty_packet() {
        let mut archive = InMemoryRawArchive::new(manifest());
        archive.insert(doc("   "), "blank id body", EidosSourceKind::RawArchive);
        let q = EidosQuery::new("   ", EidosRetrievalMode::RawArchive, 8);
        let packet = archive.retrieve(&q, 1_700_000_000_000);
        assert!(
            packet.hits.is_empty(),
            "whitespace-only text is not a stable raw archive document id"
        );
    }

    #[test]
    fn invisible_only_query_text_returns_empty_packet() {
        let mut archive = InMemoryRawArchive::new(manifest());
        archive.insert(doc("\u{200B}"), "invisible id body", EidosSourceKind::RawArchive);
        let q = EidosQuery::new("\u{200B}", EidosRetrievalMode::RawArchive, 8);
        let packet = archive.retrieve(&q, 1_700_000_000_000);
        assert!(
            packet.hits.is_empty(),
            "invisible-only text is not a stable raw archive document id"
        );
    }

    #[test]
    fn top_k_zero_returns_empty_packet() {
        let archive = build();
        let q = EidosQuery::new("note-001", EidosRetrievalMode::RawArchive, 0);
        let packet = archive.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn unicode_id_round_trips() {
        // Acceptance bar: unicode query path. RawArchive is exact lookup, so
        // a unicode id must round-trip byte-equal.
        let mut archive = InMemoryRawArchive::new(manifest());
        archive.insert(doc("文档-Привет-école"), "body", EidosSourceKind::Note);
        let q = EidosQuery::new("文档-Привет-école", EidosRetrievalMode::RawArchive, 8);
        let packet = archive.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(
            packet.hits[0].source_id.as_str(),
            "文档-Привет-école::raw"
        );
    }

    #[test]
    fn closed_citation_contract_holds_through_raw_archive() {
        let archive = build();
        let q = EidosQuery::new("note-001", EidosRetrievalMode::RawArchive, 8);
        let packet = archive.retrieve(&q, 1_700_000_000_000);
        // Real id validates.
        let real = EidosCitation {
            source_id: packet.hits[0].source_id.clone(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert_eq!(packet.validate_citation(&real), Ok(()));
        // Anything else is rejected, including ids that LOOK plausible
        // because they share the prefix.
        let forged = EidosCitation {
            source_id: EidosChunkId::new("note-001::lex").unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert!(packet.validate_citation(&forged).is_err());
    }

    #[test]
    fn replay_byte_equal_for_pinned_clock() {
        let a = build();
        let b = build();
        let q = EidosQuery::new("note-001", EidosRetrievalMode::RawArchive, 8);
        let pa = a.retrieve(&q, 1_700_000_000_000);
        let pb = b.retrieve(&q, 1_700_000_000_000);
        assert_eq!(pa, pb);
    }

    #[test]
    fn retriever_advertises_raw_archive_mode() {
        let archive = InMemoryRawArchive::new(manifest());
        assert_eq!(archive.mode(), EidosRetrievalMode::RawArchive);
        assert_eq!(archive.manifest_id(), &manifest());
    }

    #[test]
    fn reinserting_replaces_body() {
        let mut archive = InMemoryRawArchive::new(manifest());
        archive.insert(doc("d"), "alpha", EidosSourceKind::Note);
        archive.insert(doc("d"), "beta", EidosSourceKind::Note);
        let q = EidosQuery::new("d", EidosRetrievalMode::RawArchive, 8);
        let packet = archive.retrieve(&q, 0);
        assert_eq!(packet.hits.len(), 1);
        let span = packet.hits[0].span.unwrap();
        assert_eq!(span.byte_end, "beta".len() as u32);
    }
}
