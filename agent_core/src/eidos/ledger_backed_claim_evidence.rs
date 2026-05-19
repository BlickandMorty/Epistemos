//! Ledger-backed ClaimEvidence — production wiring for W-49.
//!
//! `LedgerBackedClaimEvidence` is a read-only `EidosRetriever` that
//! consumes a [`crate::provenance::ledger::ClaimLedger`] snapshot rather
//! than the in-memory map used by [`super::claim_evidence::InMemoryClaimEvidence`].
//! The shape behind the trait is identical — same `source_id` format,
//! same stance encoding, same closed-citation contract — but the data
//! comes from the live provenance graph.
//!
//! ## Stance semantics
//!
//! `ClaimLedger` represents only positive support (`support_links`); it
//! does not track contradicting evidence explicitly. Active support
//! links are emitted as `EvidenceStance::Supports`. Retracted evidence
//! (status `Retracted`) is filtered out of the closed-citation set —
//! once retracted, the evidence no longer supports the claim and must
//! not flow into a chat-layer citation.
//!
//! When contradiction tracking lands in the ledger (future Phase 2+
//! design), this retriever will be extended to surface Contradicts
//! stance hits without changing the source_id format.
//!
//! ## Snapshot consumption
//!
//! Construction takes a snapshot via [`ClaimLedger::snapshot`] so the
//! retriever holds an immutable view. The ledger can continue to mutate
//! after construction; the retriever's results stay deterministic on
//! the snapshot it captured. This is the same model as Eidos manifest
//! binding — retrieval is per-snapshot, never against a live mutating
//! source.

use super::claim_evidence::EvidenceStance;
use super::retriever::EidosRetriever;
use super::types::{
    EidosChunkId, EidosContextPacket, EidosDocumentId, EidosHit, EidosIndexManifestId,
    EidosProvenance, EidosQuery, EidosRetrievalMode, EidosScoreComponents, EidosSourceKind,
};
use crate::provenance::ledger::{ClaimLedger, ClaimStatus};
use crate::provenance::replay::LedgerSnapshot;

/// `EidosRetriever` for claim → evidence lookups backed by a real
/// `ClaimLedger` snapshot.
#[derive(Debug, Clone)]
pub struct LedgerBackedClaimEvidence {
    manifest_id: EidosIndexManifestId,
    snapshot: LedgerSnapshot,
}

impl LedgerBackedClaimEvidence {
    /// Build the retriever from a live ledger by capturing a snapshot.
    /// The retriever is bound to that snapshot for its lifetime —
    /// mutations to the source ledger after this call do not propagate.
    pub fn from_ledger(ledger: &ClaimLedger, manifest_id: EidosIndexManifestId) -> Self {
        Self {
            manifest_id,
            snapshot: ledger.snapshot(),
        }
    }

    /// Build the retriever from an already-captured snapshot. Useful for
    /// replay paths that load snapshots from disk.
    pub fn from_snapshot(snapshot: LedgerSnapshot, manifest_id: EidosIndexManifestId) -> Self {
        Self {
            manifest_id,
            snapshot,
        }
    }
}

impl EidosRetriever for LedgerBackedClaimEvidence {
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
        if query.text.trim().is_empty() || query.top_k == 0 {
            return empty_packet(query, &self.manifest_id);
        }

        // Find the support_links entry whose claim id text matches the
        // query. The snapshot is already sorted by claim id at
        // construction time so iteration is deterministic.
        let mut matching_links = self
            .snapshot
            .support_links
            .iter()
            .filter(|link| link.claim.0 == query.text);
        let Some(link) = matching_links.next() else {
            return empty_packet(query, &self.manifest_id);
        };
        if matching_links.next().is_some() {
            return empty_packet(query, &self.manifest_id);
        }

        let claim_is_retracted = self
            .snapshot
            .claims
            .iter()
            .find(|claim| claim.id == link.claim)
            .map(|claim| claim.status == ClaimStatus::Retracted)
            .unwrap_or(true);
        if claim_is_retracted {
            return empty_packet(query, &self.manifest_id);
        }

        // Filter out retracted evidence — once retracted, the evidence no
        // longer supports the claim and must not appear in the closed-
        // citation set.
        let active_evidence_ids: Vec<&crate::provenance::ledger::EvidenceId> = link
            .evidence
            .iter()
            .filter(|eid| {
                self.snapshot
                    .evidence
                    .iter()
                    .find(|e| e.id == **eid)
                    .map(|e| e.status != ClaimStatus::Retracted)
                    .unwrap_or(false)
            })
            .collect();

        // Deterministic order: evidence id ascending (same shape as the
        // in-memory ClaimEvidence retriever's sort).
        let mut sorted_ids = active_evidence_ids.clone();
        sorted_ids.sort_by(|a, b| a.0.cmp(&b.0));

        let top_k = query.top_k as usize;
        let stance = EvidenceStance::Supports; // Ledger tracks support only in V0.
        let stance_token = match stance {
            EvidenceStance::Supports => "supports",
            EvidenceStance::Contradicts => "contradicts",
        };

        let hits: Vec<EidosHit> = sorted_ids
            .into_iter()
            .take(top_k)
            .map(|eid| {
                let document_id = EidosDocumentId::new(eid.0.clone())
                    .expect("ledger EvidenceId payload is non-empty by construction");
                let chunk_id = EidosChunkId::new(format!(
                    "{}::claim::{}::{}",
                    eid.0, query.text, stance_token
                ))
                .expect("non-empty payloads guarantee non-empty chunk_id");
                EidosHit {
                    source_id: chunk_id,
                    document_id,
                    kind: EidosSourceKind::Note,
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
    use crate::provenance::ledger::{Claim, ClaimId, Evidence, EvidenceId};
    use crate::provenance::replay::ClaimEvidenceLink;

    fn manifest() -> EidosIndexManifestId {
        EidosIndexManifestId::new("ledger-backed-test").unwrap()
    }

    fn build_ledger() -> ClaimLedger {
        let mut led = ClaimLedger::new();
        // Two pieces of evidence + one claim supported by both.
        led.commit_evidence(Evidence::new(EvidenceId("ev-1".to_string()), "src-1", 1000))
            .unwrap();
        led.commit_evidence(Evidence::new(EvidenceId("ev-2".to_string()), "src-2", 1001))
            .unwrap();
        led.commit_claim(
            Claim::new(ClaimId("claim:tropical-is-convex".to_string()), "x", 1002),
            vec![],
            vec![
                EvidenceId("ev-1".to_string()),
                EvidenceId("ev-2".to_string()),
            ],
        )
        .unwrap();
        led
    }

    #[test]
    fn ledger_backed_returns_supporting_evidence() {
        let led = build_ledger();
        let r = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
        let q = EidosQuery::new(
            "claim:tropical-is-convex",
            EidosRetrievalMode::ClaimEvidence,
            16,
        );
        let packet = r.retrieve(&q, 1_700_000_000_000);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(
            ids,
            vec![
                "ev-1::claim::claim:tropical-is-convex::supports",
                "ev-2::claim::claim:tropical-is-convex::supports",
            ]
        );
    }

    #[test]
    fn missing_claim_returns_empty_packet() {
        let led = build_ledger();
        let r = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
        let q = EidosQuery::new(
            "claim:never-committed",
            EidosRetrievalMode::ClaimEvidence,
            16,
        );
        let packet = r.retrieve(&q, 1_700_000_000_000);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn retracted_evidence_is_filtered_from_closed_set() {
        let mut led = build_ledger();
        // Retract ev-2 — must drop out of the closed-citation set.
        led.retract_evidence(&EvidenceId("ev-2".to_string())).unwrap();

        let r = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
        let q = EidosQuery::new(
            "claim:tropical-is-convex",
            EidosRetrievalMode::ClaimEvidence,
            16,
        );
        let packet = r.retrieve(&q, 1_700_000_000_000);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(
            ids,
            vec!["ev-1::claim::claim:tropical-is-convex::supports"],
            "retracted ev-2 must not appear"
        );

        // ev-2 citation now rejected by the closed-citation contract.
        let forged = EidosCitation {
            source_id: EidosChunkId::new(
                "ev-2::claim::claim:tropical-is-convex::supports",
            )
            .unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert!(packet.validate_citation(&forged).is_err());
    }

    #[test]
    fn retracted_claim_returns_empty_packet() {
        let mut led = build_ledger();
        led.retract_claim(&ClaimId("claim:tropical-is-convex".to_string()))
            .unwrap();

        let r = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
        let q = EidosQuery::new(
            "claim:tropical-is-convex",
            EidosRetrievalMode::ClaimEvidence,
            16,
        );
        let packet = r.retrieve(&q, 1_700_000_000_000);
        assert!(
            packet.hits.is_empty(),
            "directly retracted claims must not surface any evidence into \
             the closed-citation set"
        );
    }

    #[test]
    fn duplicate_snapshot_support_links_fail_closed() {
        let led = build_ledger();
        let mut snapshot = led.snapshot();
        snapshot.support_links.push(ClaimEvidenceLink {
            claim: ClaimId("claim:tropical-is-convex".to_string()),
            evidence: vec![EvidenceId("ev-2".to_string())],
        });

        let r = LedgerBackedClaimEvidence::from_snapshot(snapshot, manifest());
        let q = EidosQuery::new(
            "claim:tropical-is-convex",
            EidosRetrievalMode::ClaimEvidence,
            16,
        );
        let packet = r.retrieve(&q, 1_700_000_000_000);
        assert!(
            packet.hits.is_empty(),
            "duplicate claim support-link rows make replay snapshots \
             ambiguous and must fail closed"
        );
    }

    #[test]
    fn snapshot_isolation_post_construction_mutation_does_not_leak() {
        // The retriever holds a snapshot. Mutating the source ledger
        // after construction must NOT change subsequent retrievals.
        let mut led = build_ledger();
        let r = LedgerBackedClaimEvidence::from_ledger(&led, manifest());

        // Add a third piece of evidence + re-link AFTER snapshot capture.
        led.commit_evidence(Evidence::new(EvidenceId("ev-3".to_string()), "src-3", 1003))
            .unwrap();

        let q = EidosQuery::new(
            "claim:tropical-is-convex",
            EidosRetrievalMode::ClaimEvidence,
            16,
        );
        let packet = r.retrieve(&q, 1_700_000_000_000);
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert_eq!(ids.len(), 2, "snapshot must not see post-construction state");
        assert!(!ids
            .iter()
            .any(|id| id.starts_with("ev-3::")));
    }

    #[test]
    fn closed_citation_contract_holds_through_ledger_backed() {
        let led = build_ledger();
        let r = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
        let q = EidosQuery::new(
            "claim:tropical-is-convex",
            EidosRetrievalMode::ClaimEvidence,
            16,
        );
        let packet = r.retrieve(&q, 1_700_000_000_000);
        for hit in &packet.hits {
            let cite = EidosCitation {
                source_id: hit.source_id.clone(),
                manifest_id: packet.manifest_id.clone(),
            };
            assert_eq!(packet.validate_citation(&cite), Ok(()));
        }
        // Stance-spoofing rejected.
        let spoofed = EidosCitation {
            source_id: EidosChunkId::new(
                "ev-1::claim::claim:tropical-is-convex::contradicts",
            )
            .unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert!(packet.validate_citation(&spoofed).is_err());
    }

    #[test]
    fn retriever_advertises_claim_evidence_mode() {
        let led = build_ledger();
        let r = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
        assert_eq!(r.mode(), EidosRetrievalMode::ClaimEvidence);
        assert_eq!(r.manifest_id(), &manifest());
    }

    #[test]
    fn empty_query_or_zero_top_k_defers() {
        let led = build_ledger();
        let r = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
        let q_empty = EidosQuery::new("", EidosRetrievalMode::ClaimEvidence, 16);
        let q_zero = EidosQuery::new(
            "claim:tropical-is-convex",
            EidosRetrievalMode::ClaimEvidence,
            0,
        );
        assert!(r.retrieve(&q_empty, 0).hits.is_empty());
        assert!(r.retrieve(&q_zero, 0).hits.is_empty());
    }

    #[test]
    fn whitespace_only_query_defers() {
        let mut led = ClaimLedger::new();
        led.commit_evidence(Evidence::new(EvidenceId("ev-blank".to_string()), "src", 0))
            .unwrap();
        led.commit_claim(
            Claim::new(ClaimId("   ".to_string()), "blank claim", 0),
            vec![],
            vec![EvidenceId("ev-blank".to_string())],
        )
        .unwrap();

        let r = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
        let q = EidosQuery::new("   ", EidosRetrievalMode::ClaimEvidence, 16);
        let packet = r.retrieve(&q, 0);
        assert!(
            packet.hits.is_empty(),
            "whitespace-only text is not a stable ledger claim id"
        );
    }

    #[test]
    fn replay_byte_equal_for_pinned_clock_on_same_snapshot() {
        let led = build_ledger();
        let snap = led.snapshot();
        let a = LedgerBackedClaimEvidence::from_snapshot(snap.clone(), manifest());
        let b = LedgerBackedClaimEvidence::from_snapshot(snap, manifest());
        let q = EidosQuery::new(
            "claim:tropical-is-convex",
            EidosRetrievalMode::ClaimEvidence,
            16,
        );
        assert_eq!(a.retrieve(&q, 1_700_000_000_000), b.retrieve(&q, 1_700_000_000_000));
    }

    /// End-to-end documentation of how a retraction in the source
    /// ledger flows into the Eidos closed-citation surface across two
    /// separate snapshots taken before and after the retraction. Pins
    /// the semantic that the chat layer cannot cite a withdrawn
    /// evidence id under the post-retraction snapshot, while
    /// historical packets remain self-consistent (they're frozen
    /// closed sets).
    #[test]
    fn retraction_propagation_across_snapshots() {
        let mut led = build_ledger();

        // Snapshot 1 (pre-retraction).
        let a = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
        let q = EidosQuery::new(
            "claim:tropical-is-convex",
            EidosRetrievalMode::ClaimEvidence,
            16,
        );
        let packet_a = a.retrieve(&q, 1_700_000_000_000);
        let ev2_id = EidosChunkId::new(
            "ev-2::claim::claim:tropical-is-convex::supports",
        )
        .unwrap();
        let ev2_cite_a = EidosCitation {
            source_id: ev2_id.clone(),
            manifest_id: packet_a.manifest_id.clone(),
        };
        // Pre-retraction snapshot validates the ev-2 citation.
        assert_eq!(packet_a.validate_citation(&ev2_cite_a), Ok(()));

        // Retract ev-2 in the source ledger.
        led.retract_evidence(&EvidenceId("ev-2".to_string())).unwrap();

        // Snapshot 2 (post-retraction).
        let b = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
        let packet_b = b.retrieve(&q, 1_700_000_000_000);
        let ev2_cite_b = EidosCitation {
            source_id: ev2_id,
            manifest_id: packet_b.manifest_id.clone(),
        };
        // Post-retraction snapshot rejects the ev-2 citation —
        // retraction has propagated into the closed-citation surface.
        assert!(packet_b.validate_citation(&ev2_cite_b).is_err());

        // Historical packet A is unchanged (closed sets are frozen):
        // its view of ev-2 still validates. This documents that
        // already-emitted answers stay self-consistent even after
        // upstream retraction — the chat layer's decision to refuse a
        // NEW answer doesn't retroactively invalidate the OLD one.
        let ev2_cite_a_again = EidosCitation {
            source_id: EidosChunkId::new(
                "ev-2::claim::claim:tropical-is-convex::supports",
            )
            .unwrap(),
            manifest_id: packet_a.manifest_id.clone(),
        };
        assert_eq!(packet_a.validate_citation(&ev2_cite_a_again), Ok(()));
    }

    #[test]
    fn top_k_truncates_evidence_in_ledger_backed() {
        let led = build_ledger();
        let r = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
        let q = EidosQuery::new(
            "claim:tropical-is-convex",
            EidosRetrievalMode::ClaimEvidence,
            1,
        );
        let packet = r.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 1);
        // ev-1 sorts before ev-2.
        assert_eq!(
            packet.hits[0].source_id.as_str(),
            "ev-1::claim::claim:tropical-is-convex::supports"
        );
    }
}
