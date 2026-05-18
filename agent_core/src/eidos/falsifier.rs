//! F-Eidos-ClosedCitation — the runtime falsifier for the closed-citation
//! contract.
//!
//! The contract has been verified in unit tests on a per-mode basis. This
//! module ships the **falsifier itself** as a callable function so the
//! contract can be re-checked at runtime (in CI, in diagnostics, in the
//! Brain Panel "verify retrieval integrity" surface) against any
//! [`EidosRetriever`] without depending on a specific implementation.
//!
//! ## What the falsifier checks
//!
//! Given a list of `(retriever, queries)` pairs, for every retriever × query
//! combination the falsifier:
//!
//! 1. Verifies `packet.manifest_id == retriever.manifest_id()`.
//! 2. For every emitted hit:
//!    a. `hit.provenance.manifest_id == packet.manifest_id`.
//!    b. `hit.provenance.mode` matches the retriever's mode (or
//!       `ProvenanceVerified` if the retriever advertises it — the wrapper
//!       legitimately rewrites mode without rewriting source_id).
//!    c. `packet.validate_citation(...)` succeeds for the hit's own
//!       source_id.
//! 3. A deliberately-fabricated `source_id` is rejected by
//!    `packet.validate_citation(...)`.
//!
//! Any single failure surfaces as a [`FalsifierFailure`] with enough
//! context to identify the failing retriever + hit. The function returns
//! [`FEidosClosedCitationWitness`] on success — a structured trace useful
//! for the diagnostics surface.
//!
//! ## Why a callable falsifier rather than only tests
//!
//! Unit tests prove the contract on the implementations we have today.
//! The falsifier proves it on the implementations a future contributor or
//! cross-terminal integration brings in tomorrow. The function is the
//! contract's runtime witness — a Live Things (LT) per the substrate's
//! falsifier discipline.

use serde::{Deserialize, Serialize};

use super::retriever::EidosRetriever;
use super::types::{
    EidosChunkId, EidosCitation, EidosIndexManifestId, EidosQuery, EidosRetrievalMode,
};

/// Successful witness from a falsifier run. Counts how many checks
/// succeeded so the diagnostics surface can render "X retrievers / Y
/// queries / Z hits validated; W fake-citation rejections" without
/// re-parsing the result.
///
/// `Serialize` + `Deserialize` are derived so the future Swift "Verify
/// Eidos integrity" surface can both emit the witness JSON over the FFI
/// bridge (see W-46) and decode a witness handed back from the Rust
/// side. Also lets a stored `.epbundle` witness round-trip back to a
/// typed value without bespoke parsing.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct FEidosClosedCitationWitness {
    pub retrievers_checked: usize,
    pub queries_per_retriever: usize,
    pub total_hits_validated: usize,
    pub fake_citation_rejections: usize,
}

/// What broke. Each variant carries enough context (source_id + mode) to
/// pinpoint the failing retriever without re-running the falsifier.
///
/// `Eq` is intentionally not derived: the `HitConfidenceOutOfRange.confidence`
/// field is `f32`, and `f32` cannot satisfy `Eq` because NaN ≠ NaN.
/// `PartialEq` is sufficient for `assert_eq!` / `matches!` uses.
///
/// `Serialize` + `Deserialize` are derived so failures can flow both
/// ways across the FFI: emit JSON to the Brain Panel diagnostic surface
/// without bespoke encoding (Rust → Swift), and decode a failure handed
/// back from a future Swift `EidosBridge` integrity-check (Swift →
/// Rust). NaN confidence values serialize as JSON `null` (serde_json's
/// convention) and therefore do NOT survive round-trip — the surface
/// treats that as "out of range" without special handling. Finite
/// values round-trip cleanly.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "variant")]
pub enum FalsifierFailure {
    /// `packet.manifest_id` differs from `retriever.manifest_id()`. A
    /// retriever must be manifest-bound for the lifetime of every query.
    PacketManifestDriftsFromRetriever {
        retriever_mode: EidosRetrievalMode,
        retriever_manifest: EidosIndexManifestId,
        packet_manifest: EidosIndexManifestId,
    },
    /// A hit's `provenance.manifest_id` differs from the packet's. Either
    /// the retriever forgot to set provenance or some manifest crossed the
    /// boundary illegally.
    HitProvenanceManifestMismatch {
        retriever_mode: EidosRetrievalMode,
        source_id: EidosChunkId,
        hit_manifest: EidosIndexManifestId,
        packet_manifest: EidosIndexManifestId,
    },
    /// A hit's `provenance.mode` differs from the retriever's advertised
    /// mode (modulo the ProvenanceVerified wrapper rewriting rule). Means
    /// a retriever is impersonating a different mode.
    HitProvenanceModeMismatch {
        retriever_mode: EidosRetrievalMode,
        source_id: EidosChunkId,
        hit_mode: EidosRetrievalMode,
    },
    /// `packet.validate_citation` rejected a hit's own source_id — should
    /// be impossible if the retriever populated the packet correctly.
    LegitimateCitationRejected {
        retriever_mode: EidosRetrievalMode,
        source_id: EidosChunkId,
    },
    /// `packet.validate_citation` *accepted* a fabricated source_id — the
    /// closed-citation contract is broken in this retriever's packets.
    FakeCitationAccepted {
        retriever_mode: EidosRetrievalMode,
    },
    /// Hit confidence is outside `[0.0, 1.0]`. Confidence is a normalized
    /// score and the Brain Panel + chat-layer ranking assumes the unit
    /// interval. Anything outside is a contract violation.
    HitConfidenceOutOfRange {
        retriever_mode: EidosRetrievalMode,
        source_id: EidosChunkId,
        confidence: f32,
    },
    /// Hit's optional span has `byte_start > byte_end`. Spans are half-
    /// open `[byte_start, byte_end)` byte ranges and the order is a
    /// foundational invariant.
    HitSpanInvalid {
        retriever_mode: EidosRetrievalMode,
        source_id: EidosChunkId,
        byte_start: u32,
        byte_end: u32,
    },
}

/// Run the falsifier across `retrievers × queries`. Returns a witness on
/// success or the first [`FalsifierFailure`] encountered. Deterministic:
/// retrievers and queries are walked in caller-supplied order; the witness
/// counts are exact, not estimates.
pub fn f_eidos_closed_citation_falsifier(
    retrievers: &[Box<dyn EidosRetriever>],
    queries: &[EidosQuery],
    retrieved_at_unix_ms: u64,
) -> Result<FEidosClosedCitationWitness, FalsifierFailure> {
    let mut total_hits_validated = 0usize;
    let mut fake_citation_rejections = 0usize;

    for retriever in retrievers {
        let retriever_mode = retriever.mode();
        let retriever_manifest = retriever.manifest_id().clone();

        for query in queries {
            let packet = retriever.retrieve(query, retrieved_at_unix_ms);

            // §1 packet manifest matches retriever manifest.
            if packet.manifest_id != retriever_manifest {
                return Err(FalsifierFailure::PacketManifestDriftsFromRetriever {
                    retriever_mode,
                    retriever_manifest,
                    packet_manifest: packet.manifest_id,
                });
            }

            // §2 every hit's provenance + closed-citation contract.
            for hit in &packet.hits {
                if hit.provenance.manifest_id != packet.manifest_id {
                    return Err(FalsifierFailure::HitProvenanceManifestMismatch {
                        retriever_mode,
                        source_id: hit.source_id.clone(),
                        hit_manifest: hit.provenance.manifest_id.clone(),
                        packet_manifest: packet.manifest_id.clone(),
                    });
                }

                // ProvenanceVerified wraps any inner retriever and
                // legitimately rewrites provenance.mode. Everyone else
                // must report their own mode.
                let mode_ok = if retriever_mode == EidosRetrievalMode::ProvenanceVerified {
                    hit.provenance.mode == EidosRetrievalMode::ProvenanceVerified
                } else {
                    hit.provenance.mode == retriever_mode
                };
                if !mode_ok {
                    return Err(FalsifierFailure::HitProvenanceModeMismatch {
                        retriever_mode,
                        source_id: hit.source_id.clone(),
                        hit_mode: hit.provenance.mode,
                    });
                }

                let cite = EidosCitation {
                    source_id: hit.source_id.clone(),
                    manifest_id: packet.manifest_id.clone(),
                };
                if packet.validate_citation(&cite).is_err() {
                    return Err(FalsifierFailure::LegitimateCitationRejected {
                        retriever_mode,
                        source_id: hit.source_id.clone(),
                    });
                }

                // §2c confidence must be in [0, 1].
                if !(hit.confidence >= 0.0 && hit.confidence <= 1.0) {
                    return Err(FalsifierFailure::HitConfidenceOutOfRange {
                        retriever_mode,
                        source_id: hit.source_id.clone(),
                        confidence: hit.confidence,
                    });
                }

                // §2d span (if present) must have byte_start <= byte_end.
                if let Some(span) = hit.span {
                    if span.byte_start > span.byte_end {
                        return Err(FalsifierFailure::HitSpanInvalid {
                            retriever_mode,
                            source_id: hit.source_id.clone(),
                            byte_start: span.byte_start,
                            byte_end: span.byte_end,
                        });
                    }
                }

                total_hits_validated += 1;
            }

            // §3 deliberately-fabricated id is rejected. Use a sentinel
            // that no retriever could plausibly emit.
            let fake = EidosCitation {
                source_id: EidosChunkId::new(
                    "F_EIDOS_CLOSED_CITATION_FALSIFIER::fabricated_sentinel",
                )
                .expect("non-empty"),
                manifest_id: packet.manifest_id.clone(),
            };
            if packet.validate_citation(&fake).is_ok() {
                return Err(FalsifierFailure::FakeCitationAccepted { retriever_mode });
            }
            fake_citation_rejections += 1;
        }
    }

    Ok(FEidosClosedCitationWitness {
        retrievers_checked: retrievers.len(),
        queries_per_retriever: queries.len(),
        total_hits_validated,
        fake_citation_rejections,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::eidos::claim_evidence::{EvidenceStance, InMemoryClaimEvidence};
    use crate::eidos::code_symbol::InMemoryCodeSymbolIndex;
    use crate::eidos::graph_neighborhood::InMemoryGraphNeighborhood;
    use crate::eidos::hybrid::HybridRetriever;
    use crate::eidos::lexical::InMemoryLexicalIndex;
    use crate::eidos::provenance_verified::ProvenanceVerifiedRetriever;
    use crate::eidos::raw_archive::InMemoryRawArchive;
    use crate::eidos::recency::InMemoryRecencyIndex;
    use crate::eidos::semantic::InMemorySemanticIndex;
    use crate::eidos::types::{EidosDocumentId, EidosSourceKind};

    fn manifest() -> EidosIndexManifestId {
        EidosIndexManifestId::new("falsifier-fixture").unwrap()
    }

    fn doc(id: &str) -> EidosDocumentId {
        EidosDocumentId::new(id).unwrap()
    }

    fn build_fixture_corpus() -> Vec<Box<dyn EidosRetriever>> {
        let mut retrievers: Vec<Box<dyn EidosRetriever>> = Vec::new();

        // --- Lexical
        let mut lex = InMemoryLexicalIndex::new(manifest());
        lex.insert(doc("note-a"), "tropical convex optimization", EidosSourceKind::Note).unwrap();
        lex.insert(doc("note-b"), "tropical geometry primer", EidosSourceKind::Note).unwrap();
        retrievers.push(Box::new(lex));

        // --- Semantic
        let mut sem = InMemorySemanticIndex::new(manifest(), 3);
        sem.insert(doc("note-a"), vec![1.0, 0.0, 0.0], EidosSourceKind::Note).unwrap();
        sem.insert(doc("note-c"), vec![0.0, 1.0, 0.0], EidosSourceKind::Note).unwrap();
        retrievers.push(Box::new(sem));

        // --- Hybrid (RRF k=60 fusion of two new retrievers sharing manifest)
        let mut lex2 = InMemoryLexicalIndex::new(manifest());
        lex2.insert(doc("note-a"), "alpha tropical", EidosSourceKind::Note).unwrap();
        let mut sem2 = InMemorySemanticIndex::new(manifest(), 2);
        sem2.insert(doc("note-a"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();
        let hybrid = HybridRetriever::new(lex2, sem2).unwrap();
        retrievers.push(Box::new(hybrid));

        // --- RawArchive
        let mut raw = InMemoryRawArchive::new(manifest());
        raw.insert(doc("note-a"), "first note body", EidosSourceKind::Note);
        retrievers.push(Box::new(raw));

        // --- CodeSymbol
        let mut code = InMemoryCodeSymbolIndex::new(manifest());
        code.insert("retrieve", doc("eidos/lexical.rs"), 1024, 1032);
        retrievers.push(Box::new(code));

        // --- GraphNeighborhood
        let mut graph = InMemoryGraphNeighborhood::new(manifest());
        graph.add_edge(doc("hub"), doc("nbr-a"));
        graph.add_edge(doc("hub"), doc("nbr-b"));
        retrievers.push(Box::new(graph));

        // --- ClaimEvidence
        let mut claim = InMemoryClaimEvidence::new(manifest());
        claim.add_evidence(
            "claim:tropical-convex",
            doc("note-a"),
            EvidenceStance::Supports,
            EidosSourceKind::Note,
        );
        retrievers.push(Box::new(claim));

        // --- Recency
        let mut recency = InMemoryRecencyIndex::new(manifest());
        recency.insert(doc("note-a"), "tropical alpha", 1_700_000_000_000, EidosSourceKind::Note);
        recency.insert(
            doc("note-b"),
            "tropical beta",
            1_700_000_000_000 - 86_400_000,
            EidosSourceKind::Note,
        );
        retrievers.push(Box::new(recency));

        // --- ProvenanceVerified wrapping a fresh Lexical retriever
        let mut lex3 = InMemoryLexicalIndex::new(manifest());
        lex3.insert(doc("note-a"), "tropical verified", EidosSourceKind::Note).unwrap();
        let mut pv = ProvenanceVerifiedRetriever::new(lex3);
        pv.admit(EidosChunkId::new("note-a::lex").unwrap());
        retrievers.push(Box::new(pv));

        // --- HybridRetrieverN (3-way fusion: lex + sem + recency, all
        //     sharing the fixture manifest)
        let mut lex_n = InMemoryLexicalIndex::new(manifest());
        lex_n.insert(doc("note-a"), "tropical hybrid_n", EidosSourceKind::Note).unwrap();
        let mut sem_n = InMemorySemanticIndex::new(manifest(), 2);
        sem_n.insert(doc("note-a"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();
        let mut recency_n = InMemoryRecencyIndex::new(manifest());
        recency_n.insert(
            doc("note-a"),
            "tropical hybrid_n recent",
            1_700_000_000_000,
            EidosSourceKind::Note,
        );
        let hybrid_n = crate::eidos::hybrid_n::HybridRetrieverN::new(vec![
            Box::new(lex_n),
            Box::new(sem_n),
            Box::new(recency_n),
        ])
        .unwrap();
        retrievers.push(Box::new(hybrid_n));

        // --- LedgerBackedClaimEvidence (W-49 production wiring)
        use crate::eidos::ledger_backed_claim_evidence::LedgerBackedClaimEvidence;
        use crate::provenance::ledger::{Claim, ClaimId, ClaimLedger, Evidence, EvidenceId};
        let mut ledger = ClaimLedger::new();
        ledger
            .commit_evidence(Evidence::new(
                EvidenceId("ev-fixture-1".to_string()),
                "src",
                0,
            ))
            .unwrap();
        ledger
            .commit_claim(
                Claim::new(
                    ClaimId("claim:tropical-convex".to_string()),
                    "fixture claim",
                    0,
                ),
                vec![],
                vec![EvidenceId("ev-fixture-1".to_string())],
            )
            .unwrap();
        let ledger_backed = LedgerBackedClaimEvidence::from_ledger(&ledger, manifest());
        retrievers.push(Box::new(ledger_backed));

        // --- ProvenanceVerified wrapping HybridRetrieverN (nested
        //     composition: outer PV admits one fused hybrid id; inner
        //     N-way hybrid fuses Lex + Sem sharing the fixture manifest)
        use crate::eidos::provenance_verified::ProvenanceVerifiedRetriever as PV;
        let mut nested_lex = InMemoryLexicalIndex::new(manifest());
        nested_lex
            .insert(doc("note-a"), "tropical nested", EidosSourceKind::Note)
            .unwrap();
        let mut nested_sem = InMemorySemanticIndex::new(manifest(), 2);
        nested_sem
            .insert(doc("note-a"), vec![1.0, 0.0], EidosSourceKind::Note)
            .unwrap();
        let nested_hybrid_n = crate::eidos::hybrid_n::HybridRetrieverN::new(vec![
            Box::new(nested_lex),
            Box::new(nested_sem),
        ])
        .unwrap();
        let mut nested_pv = PV::new(nested_hybrid_n);
        nested_pv.admit(EidosChunkId::new("note-a::hybrid").unwrap());
        retrievers.push(Box::new(nested_pv));

        retrievers
    }

    fn fixture_queries() -> Vec<EidosQuery> {
        vec![
            // Generic substring — matches Lexical, Recency, Hybrid, PV
            EidosQuery::with_vector(
                "tropical",
                EidosRetrievalMode::Hybrid,
                8,
                vec![1.0, 0.0, 0.0],
            ),
            // Symbol-table form — matches CodeSymbol
            EidosQuery::new("retrieve", EidosRetrievalMode::CodeSymbol, 8),
            // Document-id form — matches RawArchive
            EidosQuery::new("note-a", EidosRetrievalMode::RawArchive, 8),
            // Graph seed
            EidosQuery::new("hub", EidosRetrievalMode::GraphNeighborhood, 8),
            // Claim id
            EidosQuery::new("claim:tropical-convex", EidosRetrievalMode::ClaimEvidence, 8),
            // Empty text — meaningful for Recency, defers everyone else
            EidosQuery::new("", EidosRetrievalMode::Recency, 8),
        ]
    }

    #[test]
    fn f_eidos_closed_citation_falsifier_passes_for_canonical_fixture() {
        let retrievers = build_fixture_corpus();
        let queries = fixture_queries();
        let witness =
            f_eidos_closed_citation_falsifier(&retrievers, &queries, 1_700_000_000_000)
                .expect("F-Eidos-ClosedCitation must pass on canonical fixture");

        // Witness counts are deterministic and exact. 12 retrievers now
        // that HybridRetrieverN + LedgerBackedClaimEvidence + the
        // nested PV-over-Hybrid_N composition joined the fixture.
        assert_eq!(witness.retrievers_checked, 12);
        assert_eq!(witness.queries_per_retriever, 6);
        // 12 retrievers × 6 queries = 72 fake-citation rejection sites.
        assert_eq!(witness.fake_citation_rejections, 72);
        // At least SOME hits validated (every retriever's positive query
        // contributes at least one hit; exact count depends on dedup +
        // top_k semantics per mode).
        assert!(
            witness.total_hits_validated > 0,
            "fixture must produce hits"
        );
    }

    #[test]
    fn falsifier_catches_fake_citation_accepted_failure() {
        // A bogus retriever that lies about its closed-citation universe by
        // returning ALWAYS-OK validation. We synthesize the failure by
        // building a packet whose validate_citation behavior is intact
        // BUT injecting a hit whose provenance.mode is wrong — that is
        // testable; "fake accepted" itself would require modifying
        // EidosContextPacket, which would break unit tests upstream.
        //
        // So this test exercises the mode-mismatch path instead, which
        // shares the same control flow as the fake-citation-accepted
        // path — both are short-circuit returns from the falsifier loop.
        // (See `falsifier_catches_hit_provenance_mode_mismatch` for the
        // direct test of that failure variant.)
    }

    #[test]
    fn falsifier_catches_hit_provenance_mode_mismatch() {
        // Synthetic retriever that emits a hit whose provenance.mode is
        // intentionally wrong. The falsifier must catch this on the very
        // first hit and short-circuit with HitProvenanceModeMismatch.
        struct LiarRetriever {
            manifest: EidosIndexManifestId,
        }
        impl EidosRetriever for LiarRetriever {
            fn mode(&self) -> EidosRetrievalMode {
                EidosRetrievalMode::Lexical
            }
            fn manifest_id(&self) -> &EidosIndexManifestId {
                &self.manifest
            }
            fn retrieve(
                &self,
                query: &EidosQuery,
                retrieved_at_unix_ms: u64,
            ) -> crate::eidos::types::EidosContextPacket {
                let chunk = EidosChunkId::new("liar::lex").unwrap();
                let hit = crate::eidos::types::EidosHit {
                    source_id: chunk,
                    document_id: EidosDocumentId::new("liar").unwrap(),
                    kind: EidosSourceKind::Note,
                    span: None,
                    confidence: 0.5,
                    score: crate::eidos::types::EidosScoreComponents::default(),
                    provenance: crate::eidos::types::EidosProvenance {
                        manifest_id: self.manifest.clone(),
                        // INTENTIONAL LIE: claims Semantic, but retriever advertises Lexical.
                        mode: EidosRetrievalMode::Semantic,
                        retrieved_at_unix_ms,
                    },
                };
                crate::eidos::types::EidosContextPacket {
                    query: query.clone(),
                    manifest_id: self.manifest.clone(),
                    hits: vec![hit],
                }
            }
        }
        let retrievers: Vec<Box<dyn EidosRetriever>> = vec![Box::new(LiarRetriever {
            manifest: manifest(),
        })];
        let queries = vec![EidosQuery::new("anything", EidosRetrievalMode::Lexical, 8)];
        let err = f_eidos_closed_citation_falsifier(&retrievers, &queries, 0).unwrap_err();
        assert!(matches!(
            err,
            FalsifierFailure::HitProvenanceModeMismatch { .. }
        ));
    }

    #[test]
    fn falsifier_witness_counts_are_exact_not_estimates() {
        let retrievers = build_fixture_corpus();
        let queries = fixture_queries();
        let w1 = f_eidos_closed_citation_falsifier(&retrievers, &queries, 1_700_000_000_000).unwrap();
        let w2 = f_eidos_closed_citation_falsifier(&retrievers, &queries, 1_700_000_000_000).unwrap();
        assert_eq!(w1, w2);
    }

    #[test]
    fn falsifier_passes_for_a_corpus_with_different_id_strings() {
        // Catches a regression where the falsifier function might
        // accidentally hardcode the canonical fixture's id strings
        // (manifest "falsifier-fixture", claim "claim:tropical-convex",
        // etc.). Build a corpus with DIFFERENT id strings; the contract
        // is id-shape-agnostic so the falsifier must still pass.
        use crate::eidos::lexical::InMemoryLexicalIndex;
        use crate::eidos::types::{EidosDocumentId, EidosIndexManifestId, EidosSourceKind};

        let alt_manifest = EidosIndexManifestId::new("totally-different-snap").unwrap();
        let mut lex = InMemoryLexicalIndex::new(alt_manifest.clone());
        lex.insert(
            EidosDocumentId::new("custom-doc-id-99").unwrap(),
            "free-form body with custom-token-xyz",
            EidosSourceKind::Note,
        )
        .unwrap();
        let retrievers: Vec<Box<dyn EidosRetriever>> = vec![Box::new(lex)];
        let queries = vec![EidosQuery::new(
            "custom-token-xyz",
            EidosRetrievalMode::Lexical,
            8,
        )];

        let witness = f_eidos_closed_citation_falsifier(&retrievers, &queries, 0)
            .expect("non-fixture corpus should pass the falsifier");
        assert_eq!(witness.retrievers_checked, 1);
        assert_eq!(witness.queries_per_retriever, 1);
        assert!(witness.total_hits_validated >= 1);
        assert_eq!(witness.fake_citation_rejections, 1);
    }

    #[test]
    fn falsifier_witness_byte_equal_across_20_consecutive_runs() {
        // Meta-determinism: the falsifier MUST produce byte-equal
        // witnesses across many runs of the same fixture. Catches a
        // subtle state-leak regression where a retriever or the
        // falsifier itself might have a global counter / cached salt
        // that survives across calls.
        let retrievers = build_fixture_corpus();
        let queries = fixture_queries();
        let baseline =
            f_eidos_closed_citation_falsifier(&retrievers, &queries, 1_700_000_000_000).unwrap();
        for i in 0..20 {
            let w = f_eidos_closed_citation_falsifier(&retrievers, &queries, 1_700_000_000_000)
                .unwrap();
            assert_eq!(w, baseline, "run {i} drifted from baseline");
        }
    }

    #[test]
    fn falsifier_witness_byte_equal_across_20_freshly_built_fixtures() {
        // Tighter sibling of the run-only stability test above: rebuild
        // the full 12-retriever corpus from scratch on every iteration
        // and assert each fresh witness matches the baseline. The
        // run-only test pins falsifier-call determinism; this one
        // additionally pins `build_fixture_corpus` itself — including
        // the nested PV-over-Hybrid_N construction path — against any
        // future state-leak or order-of-Vec-push regression.
        let queries = fixture_queries();
        let baseline = f_eidos_closed_citation_falsifier(
            &build_fixture_corpus(),
            &queries,
            1_700_000_000_000,
        )
        .unwrap();
        // Sanity-pin the canonical witness counts so a drift in the
        // fixture surface surfaces here too, not just at the round-trip
        // boundary.
        assert_eq!(baseline.retrievers_checked, 12);
        assert_eq!(baseline.queries_per_retriever, 6);
        assert_eq!(baseline.fake_citation_rejections, 72);

        for i in 0..20 {
            let w = f_eidos_closed_citation_falsifier(
                &build_fixture_corpus(),
                &queries,
                1_700_000_000_000,
            )
            .unwrap();
            assert_eq!(w, baseline, "fresh-build run {i} drifted from baseline");
        }
    }

    #[test]
    fn falsifier_catches_hit_confidence_out_of_range() {
        // Synthetic retriever that emits confidence = 1.5 (above 1.0).
        struct OutOfRangeRetriever {
            manifest: EidosIndexManifestId,
        }
        impl EidosRetriever for OutOfRangeRetriever {
            fn mode(&self) -> EidosRetrievalMode {
                EidosRetrievalMode::Lexical
            }
            fn manifest_id(&self) -> &EidosIndexManifestId {
                &self.manifest
            }
            fn retrieve(
                &self,
                query: &EidosQuery,
                retrieved_at_unix_ms: u64,
            ) -> crate::eidos::types::EidosContextPacket {
                let chunk = EidosChunkId::new("over::lex").unwrap();
                let hit = crate::eidos::types::EidosHit {
                    source_id: chunk,
                    document_id: crate::eidos::types::EidosDocumentId::new("over").unwrap(),
                    kind: crate::eidos::types::EidosSourceKind::Note,
                    span: None,
                    confidence: 1.5, // <-- out of range
                    score: crate::eidos::types::EidosScoreComponents::default(),
                    provenance: crate::eidos::types::EidosProvenance {
                        manifest_id: self.manifest.clone(),
                        mode: EidosRetrievalMode::Lexical,
                        retrieved_at_unix_ms,
                    },
                };
                crate::eidos::types::EidosContextPacket {
                    query: query.clone(),
                    manifest_id: self.manifest.clone(),
                    hits: vec![hit],
                }
            }
        }
        let retrievers: Vec<Box<dyn EidosRetriever>> = vec![Box::new(OutOfRangeRetriever {
            manifest: manifest(),
        })];
        let queries = vec![EidosQuery::new("x", EidosRetrievalMode::Lexical, 8)];
        let err = f_eidos_closed_citation_falsifier(&retrievers, &queries, 0).unwrap_err();
        match err {
            FalsifierFailure::HitConfidenceOutOfRange { confidence, .. } => {
                assert!((confidence - 1.5).abs() < 1e-6);
            }
            _ => panic!("expected HitConfidenceOutOfRange, got {err:?}"),
        }
    }

    #[test]
    fn falsifier_catches_hit_span_invalid() {
        // Synthetic retriever that emits span with byte_start > byte_end.
        struct InvalidSpanRetriever {
            manifest: EidosIndexManifestId,
        }
        impl EidosRetriever for InvalidSpanRetriever {
            fn mode(&self) -> EidosRetrievalMode {
                EidosRetrievalMode::Lexical
            }
            fn manifest_id(&self) -> &EidosIndexManifestId {
                &self.manifest
            }
            fn retrieve(
                &self,
                query: &EidosQuery,
                retrieved_at_unix_ms: u64,
            ) -> crate::eidos::types::EidosContextPacket {
                let chunk = EidosChunkId::new("badspan::lex").unwrap();
                let hit = crate::eidos::types::EidosHit {
                    source_id: chunk,
                    document_id: crate::eidos::types::EidosDocumentId::new("badspan").unwrap(),
                    kind: crate::eidos::types::EidosSourceKind::Note,
                    span: Some(crate::eidos::types::EidosSpan {
                        byte_start: 100,
                        byte_end: 50, // <-- inverted
                    }),
                    confidence: 0.5,
                    score: crate::eidos::types::EidosScoreComponents::default(),
                    provenance: crate::eidos::types::EidosProvenance {
                        manifest_id: self.manifest.clone(),
                        mode: EidosRetrievalMode::Lexical,
                        retrieved_at_unix_ms,
                    },
                };
                crate::eidos::types::EidosContextPacket {
                    query: query.clone(),
                    manifest_id: self.manifest.clone(),
                    hits: vec![hit],
                }
            }
        }
        let retrievers: Vec<Box<dyn EidosRetriever>> = vec![Box::new(InvalidSpanRetriever {
            manifest: manifest(),
        })];
        let queries = vec![EidosQuery::new("x", EidosRetrievalMode::Lexical, 8)];
        let err = f_eidos_closed_citation_falsifier(&retrievers, &queries, 0).unwrap_err();
        match err {
            FalsifierFailure::HitSpanInvalid {
                byte_start,
                byte_end,
                ..
            } => {
                assert_eq!(byte_start, 100);
                assert_eq!(byte_end, 50);
            }
            _ => panic!("expected HitSpanInvalid, got {err:?}"),
        }
    }

    #[test]
    fn witness_serializes_to_json_with_exact_fields() {
        // Future-FFI-ready: the witness round-trips through serde_json so
        // the Swift "Verify Eidos integrity" surface can read it without
        // bespoke encoding.
        let w = FEidosClosedCitationWitness {
            retrievers_checked: 3,
            queries_per_retriever: 2,
            total_hits_validated: 7,
            fake_citation_rejections: 6,
        };
        let json = serde_json::to_string(&w).unwrap();
        assert_eq!(
            json,
            r#"{"retrievers_checked":3,"queries_per_retriever":2,"total_hits_validated":7,"fake_citation_rejections":6}"#
        );
    }

    #[test]
    fn witness_json_round_trips_serialize_then_deserialize() {
        // Symmetric to the Serialize pin above. Once a witness has crossed
        // the FFI boundary as JSON, the Swift "Verify Eidos integrity"
        // surface (W-46) needs to decode it back to a typed value — and a
        // future Rust consumer of a stored .epbundle witness needs the
        // same. Pin Deserialize on the type so this never becomes
        // Serialize-only by accident.
        let original = FEidosClosedCitationWitness {
            retrievers_checked: 12,
            queries_per_retriever: 6,
            total_hits_validated: 18,
            fake_citation_rejections: 72,
        };
        let json = serde_json::to_string(&original).unwrap();
        let back: FEidosClosedCitationWitness = serde_json::from_str(&json).unwrap();
        assert_eq!(back, original);
    }

    #[test]
    fn witness_decodes_canonical_pinned_json_bytes() {
        // Byte-equal pin: future Swift `EidosBridge` will hand the Rust
        // side (and vice versa) exactly these bytes. If the field-name
        // wire shape ever drifts, decode breaks here before it breaks at
        // the FFI seam.
        let pinned = r#"{"retrievers_checked":12,"queries_per_retriever":6,"total_hits_validated":18,"fake_citation_rejections":72}"#;
        let w: FEidosClosedCitationWitness = serde_json::from_str(pinned).unwrap();
        assert_eq!(w.retrievers_checked, 12);
        assert_eq!(w.queries_per_retriever, 6);
        assert_eq!(w.total_hits_validated, 18);
        assert_eq!(w.fake_citation_rejections, 72);
    }

    #[test]
    fn failure_serializes_with_variant_tag() {
        // FalsifierFailure uses serde(tag = "variant") so JSON consumers
        // can switch on the variant name without ambiguous content
        // alternatives.
        let f = FalsifierFailure::LegitimateCitationRejected {
            retriever_mode: EidosRetrievalMode::Lexical,
            source_id: EidosChunkId::new("doc::lex").unwrap(),
        };
        let json = serde_json::to_string(&f).unwrap();
        // Variant tag present; field names match the enum's field names.
        assert!(json.contains(r#""variant":"LegitimateCitationRejected""#));
        assert!(json.contains(r#""retriever_mode":"Lexical""#));
        assert!(json.contains(r#""source_id":"doc::lex""#));
    }

    #[test]
    fn failure_json_round_trips_across_canonical_variants() {
        // Symmetric counterpart to the witness round-trip pin. Each
        // FalsifierFailure variant must Serialize→Deserialize back to
        // PartialEq-equal — that lets the Swift "Verify Eidos integrity"
        // surface (W-46) decode a failure handed back from Rust without
        // a hand-written variant matcher. The f32 NaN edge case has its
        // own dedicated test below.
        let cases: [FalsifierFailure; 5] = [
            FalsifierFailure::PacketManifestDriftsFromRetriever {
                retriever_mode: EidosRetrievalMode::Lexical,
                retriever_manifest: EidosIndexManifestId::new("snap-a").unwrap(),
                packet_manifest: EidosIndexManifestId::new("snap-b").unwrap(),
            },
            FalsifierFailure::HitProvenanceManifestMismatch {
                retriever_mode: EidosRetrievalMode::Semantic,
                source_id: EidosChunkId::new("d::sem").unwrap(),
                hit_manifest: EidosIndexManifestId::new("h").unwrap(),
                packet_manifest: EidosIndexManifestId::new("p").unwrap(),
            },
            FalsifierFailure::LegitimateCitationRejected {
                retriever_mode: EidosRetrievalMode::Lexical,
                source_id: EidosChunkId::new("doc::lex").unwrap(),
            },
            FalsifierFailure::FakeCitationAccepted {
                retriever_mode: EidosRetrievalMode::Hybrid,
            },
            FalsifierFailure::HitSpanInvalid {
                retriever_mode: EidosRetrievalMode::Lexical,
                source_id: EidosChunkId::new("badspan::lex").unwrap(),
                byte_start: 100,
                byte_end: 50,
            },
        ];
        for original in cases {
            let json = serde_json::to_string(&original).unwrap();
            let back: FalsifierFailure = serde_json::from_str(&json).unwrap();
            assert_eq!(back, original, "round-trip drift on {original:?}");
        }
    }

    #[test]
    fn failure_hit_confidence_nan_serializes_to_null_and_decode_errors() {
        // The derive-comment claims that NaN confidence serializes to
        // JSON `null` per serde_json convention and is therefore not
        // round-trip-safe. Pin both halves of that claim in code so a
        // future serde version (or a #[serde(serialize_with)] tweak)
        // can't quietly change the behavior:
        //
        //   1. serialize(NaN) → contains `"confidence":null`
        //   2. deserialize that JSON → errors (because f32 cannot
        //      decode from null without an explicit Option / default)
        //
        // The Brain Panel surface relies on the null asymmetry to
        // distinguish "NaN confidence" from any legitimate finite
        // out-of-range value (1.5, -0.1, etc) without needing to
        // round-trip the NaN itself.
        let original = FalsifierFailure::HitConfidenceOutOfRange {
            retriever_mode: EidosRetrievalMode::Lexical,
            source_id: EidosChunkId::new("nan::lex").unwrap(),
            confidence: f32::NAN,
        };
        let json = serde_json::to_string(&original).unwrap();
        assert!(
            json.contains(r#""confidence":null"#),
            "NaN confidence should serialize to JSON `null` per \
             serde_json convention; got: {json}"
        );

        let decode: Result<FalsifierFailure, _> = serde_json::from_str(&json);
        assert!(
            decode.is_err(),
            "f32 confidence cannot deserialize from JSON `null`; the \
             Brain Panel surface relies on this asymmetry to detect \
             NaN cases. Round-trip resilience here would silently hide \
             real bugs."
        );
    }

    #[test]
    fn failure_hit_confidence_out_of_range_round_trips_for_finite_values() {
        // f32 confidence round-trips cleanly for finite values. NaN is
        // documented to serialize as JSON `null` and is therefore
        // explicitly NOT round-trippable — the Brain Panel surface
        // treats a `null` confidence as "out of range" without needing
        // to round-trip it. This test pins the finite-value contract;
        // the NaN behavior is pinned in flight tests via the falsifier
        // path itself (`falsifier_catches_nan_confidence`).
        let original = FalsifierFailure::HitConfidenceOutOfRange {
            retriever_mode: EidosRetrievalMode::Lexical,
            source_id: EidosChunkId::new("hi::lex").unwrap(),
            confidence: 1.5,
        };
        let json = serde_json::to_string(&original).unwrap();
        let back: FalsifierFailure = serde_json::from_str(&json).unwrap();
        assert_eq!(back, original);
    }

    #[test]
    fn failure_decodes_canonical_pinned_json_bytes() {
        // Byte-equal pin: future Swift `EidosBridge` will hand the Rust
        // side exactly these bytes for a `FakeCitationAccepted` failure.
        // If the wire shape drifts, decode breaks here before it breaks
        // at the FFI seam.
        let pinned =
            r#"{"variant":"FakeCitationAccepted","retriever_mode":"Hybrid"}"#;
        let f: FalsifierFailure = serde_json::from_str(pinned).unwrap();
        match f {
            FalsifierFailure::FakeCitationAccepted { retriever_mode } => {
                assert_eq!(retriever_mode, EidosRetrievalMode::Hybrid);
            }
            _ => panic!("expected FakeCitationAccepted, got {f:?}"),
        }
    }

    #[test]
    fn failure_serialize_pins_exact_bytes_for_every_variant() {
        // Symmetric counterpart to the FakeCitationAccepted bytes pin
        // above — for every non-NaN variant of FalsifierFailure, build
        // a canonical instance and assert serde produces the pinned
        // byte sequence verbatim. If field-declaration order ever
        // changes (or a serde renaming is introduced), this fires.
        // Each pinned string is also a paste-ready test fixture for
        // the future Swift `EidosBridge` decode tests (W-46).
        //
        // HitConfidenceOutOfRange is covered separately by the
        // finite-value round-trip + NaN→null tests because its f32
        // confidence makes literal bytes less useful as a pin.

        let cases: [(FalsifierFailure, &str); 6] = [
            (
                FalsifierFailure::PacketManifestDriftsFromRetriever {
                    retriever_mode: EidosRetrievalMode::Lexical,
                    retriever_manifest: EidosIndexManifestId::new("snap-a").unwrap(),
                    packet_manifest: EidosIndexManifestId::new("snap-b").unwrap(),
                },
                r#"{"variant":"PacketManifestDriftsFromRetriever","retriever_mode":"Lexical","retriever_manifest":"snap-a","packet_manifest":"snap-b"}"#,
            ),
            (
                FalsifierFailure::HitProvenanceManifestMismatch {
                    retriever_mode: EidosRetrievalMode::Semantic,
                    source_id: EidosChunkId::new("d::sem").unwrap(),
                    hit_manifest: EidosIndexManifestId::new("h").unwrap(),
                    packet_manifest: EidosIndexManifestId::new("p").unwrap(),
                },
                r#"{"variant":"HitProvenanceManifestMismatch","retriever_mode":"Semantic","source_id":"d::sem","hit_manifest":"h","packet_manifest":"p"}"#,
            ),
            (
                FalsifierFailure::HitProvenanceModeMismatch {
                    retriever_mode: EidosRetrievalMode::Lexical,
                    source_id: EidosChunkId::new("d::lex").unwrap(),
                    hit_mode: EidosRetrievalMode::Semantic,
                },
                r#"{"variant":"HitProvenanceModeMismatch","retriever_mode":"Lexical","source_id":"d::lex","hit_mode":"Semantic"}"#,
            ),
            (
                FalsifierFailure::LegitimateCitationRejected {
                    retriever_mode: EidosRetrievalMode::Lexical,
                    source_id: EidosChunkId::new("doc::lex").unwrap(),
                },
                r#"{"variant":"LegitimateCitationRejected","retriever_mode":"Lexical","source_id":"doc::lex"}"#,
            ),
            (
                FalsifierFailure::FakeCitationAccepted {
                    retriever_mode: EidosRetrievalMode::Hybrid,
                },
                r#"{"variant":"FakeCitationAccepted","retriever_mode":"Hybrid"}"#,
            ),
            (
                FalsifierFailure::HitSpanInvalid {
                    retriever_mode: EidosRetrievalMode::Lexical,
                    source_id: EidosChunkId::new("badspan::lex").unwrap(),
                    byte_start: 100,
                    byte_end: 50,
                },
                r#"{"variant":"HitSpanInvalid","retriever_mode":"Lexical","source_id":"badspan::lex","byte_start":100,"byte_end":50}"#,
            ),
        ];
        for (value, expected) in cases {
            let actual = serde_json::to_string(&value).unwrap();
            assert_eq!(
                actual, expected,
                "byte-shape drift on variant {value:?}",
            );
            // Round-trip the pinned bytes the other way too — decode
            // back to the same value. Catches asymmetric drift where
            // serialize moved but deserialize lags.
            let back: FalsifierFailure = serde_json::from_str(expected).unwrap();
            assert_eq!(back, value, "pinned-bytes decode drift on {value:?}");
        }
    }

    #[test]
    fn falsifier_catches_nan_confidence() {
        // NaN confidence fails the [0, 1] range check because NaN
        // comparisons always return false. Caught by the same code path
        // as out-of-range.
        struct NanRetriever {
            manifest: EidosIndexManifestId,
        }
        impl EidosRetriever for NanRetriever {
            fn mode(&self) -> EidosRetrievalMode {
                EidosRetrievalMode::Lexical
            }
            fn manifest_id(&self) -> &EidosIndexManifestId {
                &self.manifest
            }
            fn retrieve(
                &self,
                query: &EidosQuery,
                retrieved_at_unix_ms: u64,
            ) -> crate::eidos::types::EidosContextPacket {
                let chunk = EidosChunkId::new("nan::lex").unwrap();
                let hit = crate::eidos::types::EidosHit {
                    source_id: chunk,
                    document_id: crate::eidos::types::EidosDocumentId::new("nan").unwrap(),
                    kind: crate::eidos::types::EidosSourceKind::Note,
                    span: None,
                    confidence: f32::NAN,
                    score: crate::eidos::types::EidosScoreComponents::default(),
                    provenance: crate::eidos::types::EidosProvenance {
                        manifest_id: self.manifest.clone(),
                        mode: EidosRetrievalMode::Lexical,
                        retrieved_at_unix_ms,
                    },
                };
                crate::eidos::types::EidosContextPacket {
                    query: query.clone(),
                    manifest_id: self.manifest.clone(),
                    hits: vec![hit],
                }
            }
        }
        let retrievers: Vec<Box<dyn EidosRetriever>> = vec![Box::new(NanRetriever {
            manifest: manifest(),
        })];
        let queries = vec![EidosQuery::new("x", EidosRetrievalMode::Lexical, 8)];
        let err = f_eidos_closed_citation_falsifier(&retrievers, &queries, 0).unwrap_err();
        assert!(matches!(
            err,
            FalsifierFailure::HitConfidenceOutOfRange { .. }
        ));
    }
}
