//! ClaimEvidence retrieval mode — claim-id → evidence chunks.
//!
//! Given a claim id (the query text), return the evidence chunks that the
//! retriever knows about for that claim. Each link records its **stance**
//! (`Supports` / `Contradicts`) so the chat layer can render the evidence
//! in two columns and so the chunk id reflects the stance — making
//! stance-spoofing a closed-citation violation.
//!
//! ## Why stance is part of the chunk id
//!
//! The closed-citation contract is "you can only cite ids Eidos returned."
//! If stance were *metadata only*, a chat layer could cite a real evidence
//! document under the wrong stance ("the user's own note CONTRADICTS X"
//! when in fact it SUPPORTS X). Encoding stance into the chunk id —
//! `"{evidence_doc}::claim::{claim_id}::{stance}"` — makes stance-spoofing
//! a citation forgery that [`EidosContextPacket::validate_citation`] catches.
//!
//! ## Relationship to the existing claim ledger
//!
//! `agent_core::provenance::ledger::ClaimLedger` already tracks claims +
//! retraction propagation. Eidos V0's `ClaimEvidence` retriever is the
//! **read-only retrieval surface** that sits in front of it; the production
//! wiring (ledger → eidos) lands under a later W-row. For V0 we expose a
//! standalone in-memory backend so the closed-citation seam is fully
//! testable without dragging the ledger's persistence concerns in.

use std::collections::BTreeMap;

use super::retriever::EidosRetriever;
use super::types::{
    is_blank_query_text, EidosChunkId, EidosContextPacket, EidosDocumentId, EidosHit,
    EidosIndexManifestId, EidosProvenance, EidosQuery, EidosRetrievalMode,
    EidosScoreComponents, EidosSourceKind,
};

/// Whether a piece of evidence supports or contradicts a claim. Mirrors the
/// existing `provenance::ledger::ClaimStatus` semantics at the retrieval
/// layer; the ledger keeps the ground truth, Eidos surfaces it.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum EvidenceStance {
    Supports,
    Contradicts,
}

impl EvidenceStance {
    fn token(self) -> &'static str {
        match self {
            EvidenceStance::Supports => "supports",
            EvidenceStance::Contradicts => "contradicts",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct EvidenceLink {
    evidence_document: EidosDocumentId,
    stance: EvidenceStance,
    source_kind: EidosSourceKind,
}

/// In-memory claim → evidence retriever. Keyed on opaque string claim ids
/// because Eidos V0 does not own the claim taxonomy (that lives in the
/// ledger / T10B form layer).
#[derive(Clone, Debug)]
pub struct InMemoryClaimEvidence {
    manifest_id: EidosIndexManifestId,
    links: BTreeMap<String, Vec<EvidenceLink>>,
}

impl InMemoryClaimEvidence {
    pub fn new(manifest_id: EidosIndexManifestId) -> Self {
        Self {
            manifest_id,
            links: BTreeMap::new(),
        }
    }

    /// Register that `evidence_document` is evidence for `claim_id` with the
    /// given stance. Idempotent on `(claim_id, evidence_document, stance)`.
    pub fn add_evidence(
        &mut self,
        claim_id: impl Into<String>,
        evidence_document: EidosDocumentId,
        stance: EvidenceStance,
        source_kind: EidosSourceKind,
    ) {
        let claim = claim_id.into();
        let bucket = self.links.entry(claim).or_default();
        let new_link = EvidenceLink {
            evidence_document,
            stance,
            source_kind,
        };
        if !bucket.iter().any(|l| {
            l.evidence_document == new_link.evidence_document && l.stance == new_link.stance
        }) {
            bucket.push(new_link);
        }
    }
}

impl EidosRetriever for InMemoryClaimEvidence {
    fn mode(&self) -> EidosRetrievalMode {
        EidosRetrievalMode::ClaimEvidence
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
            return empty_packet(query, &self.manifest_id);
        }

        let Some(bucket) = self.links.get(&query.text) else {
            return empty_packet(query, &self.manifest_id);
        };

        // Deterministic order: (evidence_document asc, stance ascending —
        // alphabetical order of the stance token, so "contradicts" < "supports").
        let mut sorted: Vec<&EvidenceLink> = bucket.iter().collect();
        sorted.sort_by(|a, b| {
            a.evidence_document
                .as_str()
                .cmp(b.evidence_document.as_str())
                .then_with(|| a.stance.token().cmp(b.stance.token()))
        });

        let top_k = query.top_k as usize;
        let hits: Vec<EidosHit> = sorted
            .into_iter()
            .take(top_k)
            .map(|link| {
                let chunk_id = EidosChunkId::new(format!(
                    "{}::claim::{}::{}",
                    link.evidence_document.as_str(),
                    query.text,
                    link.stance.token(),
                ))
                .expect("non-empty document id and non-empty claim id");
                EidosHit {
                    source_id: chunk_id,
                    document_id: link.evidence_document.clone(),
                    kind: link.source_kind,
                    span: None,
                    confidence: 1.0,
                    score: EidosScoreComponents::default(),
                    provenance: EidosProvenance {
                        manifest_id: self.manifest_id.clone(),
                        mode: EidosRetrievalMode::ClaimEvidence,
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
        EidosIndexManifestId::new("claim-test-manifest").unwrap()
    }

    fn doc(id: &str) -> EidosDocumentId {
        EidosDocumentId::new(id).unwrap()
    }

    fn build() -> InMemoryClaimEvidence {
        let mut idx = InMemoryClaimEvidence::new(manifest());
        idx.add_evidence(
            "claim:tropical-is-convex",
            doc("note-001"),
            EvidenceStance::Supports,
            EidosSourceKind::Note,
        );
        idx.add_evidence(
            "claim:tropical-is-convex",
            doc("note-002"),
            EvidenceStance::Supports,
            EidosSourceKind::Note,
        );
        idx.add_evidence(
            "claim:tropical-is-convex",
            doc("note-003"),
            EvidenceStance::Contradicts,
            EidosSourceKind::Note,
        );
        idx.add_evidence(
            "claim:other",
            doc("note-009"),
            EvidenceStance::Supports,
            EidosSourceKind::Note,
        );
        idx
    }

    #[test]
    fn claim_with_supporting_evidence_returned() {
        let idx = build();
        let q = EidosQuery::new("claim:tropical-is-convex", EidosRetrievalMode::ClaimEvidence, 16);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 3);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(
            ids,
            vec![
                "note-001::claim::claim:tropical-is-convex::supports",
                "note-002::claim::claim:tropical-is-convex::supports",
                "note-003::claim::claim:tropical-is-convex::contradicts",
            ]
        );
    }

    #[test]
    fn missing_claim_returns_empty_packet() {
        let idx = build();
        let q = EidosQuery::new("claim:never-registered", EidosRetrievalMode::ClaimEvidence, 8);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn closed_citation_contract_holds_and_rejects_stance_spoofing() {
        let idx = build();
        let q = EidosQuery::new("claim:tropical-is-convex", EidosRetrievalMode::ClaimEvidence, 16);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        for hit in &packet.hits {
            let cite = EidosCitation {
                source_id: hit.source_id.clone(),
                manifest_id: packet.manifest_id.clone(),
            };
            assert_eq!(packet.validate_citation(&cite), Ok(()));
        }
        // note-001 supports the claim. A citation claiming it CONTRADICTS
        // is a forged stance and is rejected by the closed-citation contract.
        let stance_spoofed = EidosCitation {
            source_id: EidosChunkId::new(
                "note-001::claim::claim:tropical-is-convex::contradicts",
            )
            .unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert!(packet.validate_citation(&stance_spoofed).is_err());
    }

    #[test]
    fn empty_query_returns_empty_packet() {
        let idx = build();
        let q = EidosQuery::new("", EidosRetrievalMode::ClaimEvidence, 8);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn whitespace_only_query_returns_empty_packet() {
        let mut idx = InMemoryClaimEvidence::new(manifest());
        idx.add_evidence(
            "   ",
            doc("note-blank"),
            EvidenceStance::Supports,
            EidosSourceKind::Note,
        );
        let q = EidosQuery::new("   ", EidosRetrievalMode::ClaimEvidence, 8);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert!(
            packet.hits.is_empty(),
            "whitespace-only text is not a stable claim id"
        );
    }

    #[test]
    fn invisible_only_query_returns_empty_packet() {
        let mut idx = InMemoryClaimEvidence::new(manifest());
        idx.add_evidence(
            "\u{200B}",
            doc("note-invisible"),
            EvidenceStance::Supports,
            EidosSourceKind::Note,
        );
        let q = EidosQuery::new("\u{200B}", EidosRetrievalMode::ClaimEvidence, 8);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert!(
            packet.hits.is_empty(),
            "invisible-only text is not a stable claim id"
        );
    }

    #[test]
    fn top_k_zero_returns_empty_packet() {
        let idx = build();
        let q = EidosQuery::new("claim:tropical-is-convex", EidosRetrievalMode::ClaimEvidence, 0);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn top_k_truncates_evidence() {
        let idx = build();
        let q = EidosQuery::new("claim:tropical-is-convex", EidosRetrievalMode::ClaimEvidence, 2);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 2);
        // Truncation preserves document_id-ascending order.
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(
            ids,
            vec![
                "note-001::claim::claim:tropical-is-convex::supports",
                "note-002::claim::claim:tropical-is-convex::supports",
            ]
        );
    }

    #[test]
    fn replay_byte_equal_for_pinned_clock() {
        let a = build();
        let b = build();
        let q = EidosQuery::new("claim:tropical-is-convex", EidosRetrievalMode::ClaimEvidence, 8);
        let pa = a.retrieve(&q, 1_700_000_000_000);
        let pb = b.retrieve(&q, 1_700_000_000_000);
        assert_eq!(pa, pb);
    }

    #[test]
    fn retriever_advertises_claim_evidence_mode() {
        let idx = InMemoryClaimEvidence::new(manifest());
        assert_eq!(idx.mode(), EidosRetrievalMode::ClaimEvidence);
        assert_eq!(idx.manifest_id(), &manifest());
    }

    #[test]
    fn unicode_claim_id_round_trips() {
        let mut idx = InMemoryClaimEvidence::new(manifest());
        idx.add_evidence(
            "主张:有效性",
            doc("证据-001"),
            EvidenceStance::Supports,
            EidosSourceKind::Note,
        );
        let q = EidosQuery::new("主张:有效性", EidosRetrievalMode::ClaimEvidence, 8);
        let packet = idx.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(
            packet.hits[0].source_id.as_str(),
            "证据-001::claim::主张:有效性::supports"
        );
    }

    #[test]
    fn idempotent_evidence_insertion() {
        let mut idx = InMemoryClaimEvidence::new(manifest());
        idx.add_evidence(
            "c",
            doc("d"),
            EvidenceStance::Supports,
            EidosSourceKind::Note,
        );
        idx.add_evidence(
            "c",
            doc("d"),
            EvidenceStance::Supports,
            EidosSourceKind::Note,
        );
        let q = EidosQuery::new("c", EidosRetrievalMode::ClaimEvidence, 8);
        let packet = idx.retrieve(&q, 0);
        assert_eq!(packet.hits.len(), 1);
    }

    #[test]
    fn same_document_can_provide_both_stances() {
        // Real world: a long note might support one part of a claim and
        // contradict another. Both links coexist.
        let mut idx = InMemoryClaimEvidence::new(manifest());
        idx.add_evidence(
            "c",
            doc("doc"),
            EvidenceStance::Supports,
            EidosSourceKind::Note,
        );
        idx.add_evidence(
            "c",
            doc("doc"),
            EvidenceStance::Contradicts,
            EidosSourceKind::Note,
        );
        let q = EidosQuery::new("c", EidosRetrievalMode::ClaimEvidence, 8);
        let packet = idx.retrieve(&q, 0);
        assert_eq!(packet.hits.len(), 2);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        // "contradicts" < "supports" lexicographically.
        assert_eq!(
            ids,
            vec![
                "doc::claim::c::contradicts",
                "doc::claim::c::supports",
            ]
        );
    }
}
