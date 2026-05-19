//! ProvenanceVerified retrieval mode — fail-closed verified-only wrapper.
//!
//! This retriever **wraps** another `EidosRetriever` and filters its hits
//! to those whose `source_id` has been explicitly admitted to a verified
//! set. The verified set is the closed universe of "this chunk has been
//! provenance-checked" — by claim-ledger backing, signed source attestation,
//! or witness attachment.
//!
//! Fail-closed semantics: if a hit's `source_id` is **not** in the verified
//! set, the hit is dropped from the packet entirely. The chat layer never
//! sees unverified hits through this mode, so the closed-citation contract
//! on a ProvenanceVerified packet implies provenance verification.
//!
//! ## Why a wrapper instead of a standalone retriever
//!
//! Verification is orthogonal to retrieval: any of the nine canonical
//! modes (`EidosRetrievalMode::CANON_ALL`) can be verified. Hybrid +
//! Verified, Lexical + Verified, Semantic + Verified are all useful
//! compositions. A wrapper avoids re-implementing
//! retrieval for each mode and keeps the verified-set logic in one place.
//!
//! ## Source id preservation
//!
//! `ProvenanceVerifiedRetriever` preserves the inner retriever's chunk id
//! (`{doc_id}::lex`, `{doc_id}::sem`, etc.). The wrapped packet's
//! `provenance.mode` is rewritten to `EidosRetrievalMode::ProvenanceVerified`
//! so the chat layer can tell verification ran, but the citable token stays
//! the inner one — two retrievers (Lexical and Lexical+Verified) bound to
//! the same manifest can cite the same `doc::lex` id, and validation
//! succeeds in either packet (independently).

use std::collections::BTreeSet;

use super::retriever::EidosRetriever;
use super::types::{
    EidosChunkId, EidosContextPacket, EidosIndexManifestId, EidosQuery, EidosRetrievalMode,
};

/// Wraps any [`EidosRetriever`] and filters its output to chunk ids that
/// appear in the `verified` set. Hits whose source_id is missing from the
/// set are dropped fail-closed (no panic, no warning — the closed-citation
/// universe of the wrapped packet simply does not include them).
pub struct ProvenanceVerifiedRetriever<R: EidosRetriever> {
    inner: R,
    verified: BTreeSet<EidosChunkId>,
}

impl<R: EidosRetriever> ProvenanceVerifiedRetriever<R> {
    pub fn new(inner: R) -> Self {
        Self {
            inner,
            verified: BTreeSet::new(),
        }
    }

    /// Admit one chunk id to the verified set. Idempotent.
    pub fn admit(&mut self, source_id: EidosChunkId) {
        self.verified.insert(source_id);
    }

    /// Returns the number of verified chunk ids. Useful for diagnostics
    /// surfaces ("X / Y chunks are provenance-verified").
    pub fn verified_count(&self) -> usize {
        self.verified.len()
    }
}

impl<R: EidosRetriever> EidosRetriever for ProvenanceVerifiedRetriever<R> {
    fn mode(&self) -> EidosRetrievalMode {
        EidosRetrievalMode::ProvenanceVerified
    }

    fn manifest_id(&self) -> &EidosIndexManifestId {
        self.inner.manifest_id()
    }

    fn retrieve(
        &self,
        query: &EidosQuery,
        retrieved_at_unix_ms: u64,
    ) -> EidosContextPacket {
        if query.text.trim().is_empty() || query.top_k == 0 {
            return EidosContextPacket {
                query: query.clone(),
                manifest_id: self.manifest_id().clone(),
                hits: vec![],
            };
        }

        let inner_packet = self.inner.retrieve(query, retrieved_at_unix_ms);
        let verified = &self.verified;

        let hits = inner_packet
            .hits
            .into_iter()
            .filter(|h| verified.contains(&h.source_id))
            .map(|mut h| {
                // Mark the hit as having passed verification. The source_id
                // and document_id remain the inner retriever's so a chat
                // layer can resolve back to the underlying content; only
                // provenance.mode shifts to ProvenanceVerified.
                h.provenance.mode = EidosRetrievalMode::ProvenanceVerified;
                h
            })
            .collect();

        EidosContextPacket {
            query: query.clone(),
            manifest_id: self.manifest_id().clone(),
            hits,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::eidos::lexical::InMemoryLexicalIndex;
    use crate::eidos::types::{
        EidosCitation, EidosDocumentId, EidosHit, EidosIndexManifestId, EidosProvenance,
        EidosScoreComponents, EidosSourceKind,
    };

    fn manifest() -> EidosIndexManifestId {
        EidosIndexManifestId::new("pv-test-manifest").unwrap()
    }

    fn doc(id: &str) -> EidosDocumentId {
        EidosDocumentId::new(id).unwrap()
    }

    fn chunk(id: &str) -> EidosChunkId {
        EidosChunkId::new(id).unwrap()
    }

    fn build_inner() -> InMemoryLexicalIndex {
        let mut lex = InMemoryLexicalIndex::new(manifest());
        lex.insert(doc("a"), "alpha tropical", EidosSourceKind::Note).unwrap();
        lex.insert(doc("b"), "beta tropical", EidosSourceKind::Note).unwrap();
        lex.insert(doc("c"), "gamma tropical", EidosSourceKind::Note).unwrap();
        lex
    }

    #[test]
    fn empty_verified_set_drops_every_hit() {
        // Fail-closed: an unconfigured ProvenanceVerifiedRetriever returns
        // empty packets, even when the inner retriever has matches.
        let pv = ProvenanceVerifiedRetriever::new(build_inner());
        let q = EidosQuery::new("tropical", EidosRetrievalMode::ProvenanceVerified, 16);
        let packet = pv.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[derive(Clone)]
    struct BlankLeakingRetriever {
        manifest_id: EidosIndexManifestId,
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
                    source_id: chunk("leak::lex"),
                    document_id: doc("leak"),
                    kind: EidosSourceKind::Note,
                    span: None,
                    confidence: 1.0,
                    score: EidosScoreComponents::default(),
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
    fn blank_query_defers_before_verified_filter_even_if_inner_leaks() {
        let mut pv = ProvenanceVerifiedRetriever::new(BlankLeakingRetriever {
            manifest_id: manifest(),
        });
        pv.admit(chunk("leak::lex"));
        let q = EidosQuery::new("   ", EidosRetrievalMode::ProvenanceVerified, 16);
        let packet = pv.retrieve(&q, 1_700_000_000_000);
        assert!(
            packet.hits.is_empty(),
            "PV must fail closed on blank query before trusting inner hits"
        );
    }

    #[test]
    fn admitted_ids_pass_through_unverified_ids_dropped() {
        let mut pv = ProvenanceVerifiedRetriever::new(build_inner());
        pv.admit(chunk("a::lex"));
        pv.admit(chunk("c::lex"));
        // b::lex is intentionally NOT admitted.

        let q = EidosQuery::new("tropical", EidosRetrievalMode::ProvenanceVerified, 16);
        let packet = pv.retrieve(&q, 1_700_000_000_000);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert!(ids.contains(&"a::lex"));
        assert!(ids.contains(&"c::lex"));
        assert!(!ids.contains(&"b::lex"));
        // Every emitted hit advertises ProvenanceVerified mode.
        for hit in &packet.hits {
            assert_eq!(hit.provenance.mode, EidosRetrievalMode::ProvenanceVerified);
        }
    }

    #[test]
    fn provenance_mode_rewrites_but_source_id_preserved() {
        let mut pv = ProvenanceVerifiedRetriever::new(build_inner());
        pv.admit(chunk("a::lex"));
        let q = EidosQuery::new("tropical", EidosRetrievalMode::ProvenanceVerified, 16);
        let packet = pv.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 1);
        // Source id stays the inner retriever's — Lexical's "a::lex".
        assert_eq!(packet.hits[0].source_id.as_str(), "a::lex");
        // Document id likewise.
        assert_eq!(packet.hits[0].document_id.as_str(), "a");
        // Only provenance.mode shifts.
        assert_eq!(
            packet.hits[0].provenance.mode,
            EidosRetrievalMode::ProvenanceVerified
        );
    }

    #[test]
    fn pv_preserves_inner_hit_score_confidence_span_kind() {
        // Audit per "audit existing claims first":
        // `provenance_mode_rewrites_but_source_id_preserved` covers
        // source_id + document_id + provenance.mode. It does NOT pin
        // that the OTHER fields on EidosHit (score components,
        // confidence, span, kind) survive the mode rewrite.
        //
        // The PV impl at provenance_verified.rs:88 uses `.map(|mut h|
        // { h.provenance.mode = ...; h })` — selective mutation, so
        // every other field is implicitly preserved. A future change
        // to "normalize confidence after admission" or "strip span
        // because PV doesn't need it" would break the bridge contract
        // and only surface here.
        //
        // Build the inner Lexical, capture its direct hit's fields,
        // then run PV-wrapped retrieval and assert each non-rewritten
        // field is byte-equal.
        let inner = build_inner();
        let q = EidosQuery::new("tropical", EidosRetrievalMode::Lexical, 16);
        let inner_packet = inner.retrieve(&q, 1_700_000_000_000);
        let inner_a = inner_packet
            .hits
            .iter()
            .find(|h| h.source_id.as_str() == "a::lex")
            .expect("inner Lex must surface a::lex");

        let mut pv = ProvenanceVerifiedRetriever::new(build_inner());
        pv.admit(chunk("a::lex"));
        let pv_q = EidosQuery::new("tropical", EidosRetrievalMode::ProvenanceVerified, 16);
        let pv_packet = pv.retrieve(&pv_q, 1_700_000_000_000);
        assert_eq!(pv_packet.hits.len(), 1);
        let pv_a = &pv_packet.hits[0];

        // The rewritten field — only this one changes.
        assert_eq!(pv_a.provenance.mode, EidosRetrievalMode::ProvenanceVerified);
        assert_eq!(inner_a.provenance.mode, EidosRetrievalMode::Lexical);

        // Everything else must match the inner hit byte-for-byte.
        assert_eq!(pv_a.source_id, inner_a.source_id);
        assert_eq!(pv_a.document_id, inner_a.document_id);
        assert_eq!(pv_a.kind, inner_a.kind);
        assert_eq!(pv_a.span, inner_a.span);
        assert_eq!(pv_a.confidence, inner_a.confidence);
        assert_eq!(pv_a.score.lexical, inner_a.score.lexical);
        assert_eq!(pv_a.score.semantic, inner_a.score.semantic);
        assert_eq!(pv_a.score.recency, inner_a.score.recency);
        assert_eq!(pv_a.score.graph, inner_a.score.graph);
        // provenance.manifest_id + retrieved_at_unix_ms unchanged.
        assert_eq!(pv_a.provenance.manifest_id, inner_a.provenance.manifest_id);
        assert_eq!(
            pv_a.provenance.retrieved_at_unix_ms,
            inner_a.provenance.retrieved_at_unix_ms
        );
    }

    #[test]
    fn closed_citation_contract_holds_through_provenance_verified() {
        let mut pv = ProvenanceVerifiedRetriever::new(build_inner());
        pv.admit(chunk("a::lex"));
        let q = EidosQuery::new("tropical", EidosRetrievalMode::ProvenanceVerified, 16);
        let packet = pv.retrieve(&q, 1_700_000_000_000);

        // Real admitted id validates.
        let real = EidosCitation {
            source_id: chunk("a::lex"),
            manifest_id: packet.manifest_id.clone(),
        };
        assert_eq!(packet.validate_citation(&real), Ok(()));

        // An id that exists in the corpus (b would match "tropical" via the
        // inner lexical retriever) but is NOT in the verified set is
        // rejected by the wrapped packet — fail-closed.
        let unverified = EidosCitation {
            source_id: chunk("b::lex"),
            manifest_id: packet.manifest_id.clone(),
        };
        assert!(packet.validate_citation(&unverified).is_err());
    }

    #[test]
    fn admitting_id_that_does_not_match_query_is_a_noop() {
        // Admitting "z::lex" when the inner retriever has no doc "z" is
        // harmless — the inner retriever returns no z hit, so the wrapper
        // never sees it.
        let mut pv = ProvenanceVerifiedRetriever::new(build_inner());
        pv.admit(chunk("z::lex"));
        let q = EidosQuery::new("tropical", EidosRetrievalMode::ProvenanceVerified, 16);
        let packet = pv.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn manifest_id_is_inherited_from_inner() {
        let pv = ProvenanceVerifiedRetriever::new(build_inner());
        assert_eq!(pv.manifest_id(), &manifest());
    }

    #[test]
    fn retriever_advertises_provenance_verified_mode() {
        let pv = ProvenanceVerifiedRetriever::new(build_inner());
        assert_eq!(pv.mode(), EidosRetrievalMode::ProvenanceVerified);
    }

    #[test]
    fn replay_byte_equal_for_pinned_clock() {
        let mut a = ProvenanceVerifiedRetriever::new(build_inner());
        a.admit(chunk("a::lex"));
        let mut b = ProvenanceVerifiedRetriever::new(build_inner());
        b.admit(chunk("a::lex"));
        let q = EidosQuery::new("tropical", EidosRetrievalMode::ProvenanceVerified, 16);
        assert_eq!(
            a.retrieve(&q, 1_700_000_000_000),
            b.retrieve(&q, 1_700_000_000_000)
        );
    }

    #[test]
    fn idempotent_admission() {
        let mut pv = ProvenanceVerifiedRetriever::new(build_inner());
        pv.admit(chunk("a::lex"));
        pv.admit(chunk("a::lex"));
        pv.admit(chunk("a::lex"));
        assert_eq!(pv.verified_count(), 1);
    }

    #[test]
    fn multi_admit_same_id_yields_byte_equal_packet_to_single_admit() {
        // Stronger contract than the count-level idempotency above: a
        // retriever with admit(x) admit(x) admit(x) must produce a
        // retrieval packet byte-equal to admit(x) alone. Catches a
        // future swap of `verified: BTreeSet<EidosChunkId>` to a
        // `Vec<EidosChunkId>` (or any change that would let admit-twice
        // emit duplicate hits or perturb sort order).
        let mut single = ProvenanceVerifiedRetriever::new(build_inner());
        single.admit(chunk("a::lex"));

        let mut multi = ProvenanceVerifiedRetriever::new(build_inner());
        multi.admit(chunk("a::lex"));
        multi.admit(chunk("a::lex"));
        multi.admit(chunk("a::lex"));

        let q = EidosQuery::new("tropical", EidosRetrievalMode::ProvenanceVerified, 16);
        let p_single = single.retrieve(&q, 1_700_000_000_000);
        let p_multi = multi.retrieve(&q, 1_700_000_000_000);

        // Byte-equal packet — not just the same ids, but identical
        // hit-by-hit including provenance + spans + scores.
        assert_eq!(p_single, p_multi);
        // Sanity: exactly one hit (a::lex), not three.
        assert_eq!(p_multi.hits.len(), 1);
    }

    #[test]
    fn verified_count_tracks_admissions() {
        let mut pv = ProvenanceVerifiedRetriever::new(build_inner());
        assert_eq!(pv.verified_count(), 0);
        pv.admit(chunk("a::lex"));
        assert_eq!(pv.verified_count(), 1);
        pv.admit(chunk("b::lex"));
        assert_eq!(pv.verified_count(), 2);
    }
}
