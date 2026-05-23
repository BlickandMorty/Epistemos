//! R1 (2026-05-23): integration tests for
//! `agent_core::eidos::produce_eidos_context_packet[_json]`.
//!
//! These tests live in `agent_core/tests/` rather than the inline
//! `eidos::hardening_tests` module because the lib-test build on this
//! HEAD has pre-existing breakage in unrelated modules (`tools_v2`,
//! `cache::mod`, `skill_discovery`) — those errors block the inline
//! test build but not the integration-test crate, which consumes only
//! the lib's public surface.
//!
//! Cross-ref:
//! - `agent_core/src/eidos/mod.rs::produce_eidos_context_packet_json`
//! - `agent_core/src/bridge.rs::eidos_search_lexical_json` (fixture FFI)
//! - `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` W-46

use agent_core::eidos::{
    produce_eidos_context_packet, produce_eidos_context_packet_json, EidosCitation,
    EidosContextPacket, EidosDocumentId, EidosIndexManifestId, EidosRetrievalMode,
    EidosSourceKind, EvidenceStance, InMemoryClaimEvidence, InMemoryLexicalIndex,
};

const FIXED_RETRIEVED_AT_MS: u64 = 1_700_000_000_000;

fn manifest(label: &str) -> EidosIndexManifestId {
    EidosIndexManifestId::new(label).expect("non-empty manifest label")
}

fn seeded_lexical_index() -> InMemoryLexicalIndex {
    let mut idx = InMemoryLexicalIndex::new(manifest("eidos-test-lexical-2026-05-23"));
    idx.insert(
        EidosDocumentId::new("notes/governance.md").expect("non-empty doc id"),
        "residency governance recap with two governance hits",
        EidosSourceKind::Note,
    )
    .expect("seed governance");
    idx.insert(
        EidosDocumentId::new("notes/unrelated.md").expect("non-empty doc id"),
        "completely orthogonal content",
        EidosSourceKind::Note,
    )
    .expect("seed unrelated");
    idx
}

fn seeded_claim_evidence() -> InMemoryClaimEvidence {
    let mut idx = InMemoryClaimEvidence::new(manifest("eidos-test-claim-2026-05-23"));
    idx.add_evidence(
        "claim-residency-governance",
        EidosDocumentId::new("notes/governance.md").expect("non-empty doc id"),
        EvidenceStance::Supports,
        EidosSourceKind::Note,
    );
    idx
}

/// Smoke: the typed helper returns a packet whose `hits` reflect a
/// real lexical match against the seeded corpus, with caller-supplied
/// timestamp echoed into every hit's `provenance.retrieved_at_unix_ms`.
#[test]
fn produce_eidos_context_packet_returns_real_hits_against_lexical_retriever() {
    let idx = seeded_lexical_index();
    let packet =
        produce_eidos_context_packet(&idx, "governance", 5, FIXED_RETRIEVED_AT_MS);

    assert!(
        !packet.hits.is_empty(),
        "expected at least one hit for 'governance' against seeded corpus"
    );
    assert!(
        packet
            .hits
            .iter()
            .any(|h| h.document_id.as_str() == "notes/governance.md"),
        "expected notes/governance.md to appear in hits; got {:?}",
        packet
            .hits
            .iter()
            .map(|h| h.document_id.as_str().to_string())
            .collect::<Vec<_>>()
    );
    for hit in &packet.hits {
        assert_eq!(
            hit.provenance.retrieved_at_unix_ms, FIXED_RETRIEVED_AT_MS,
            "every hit MUST carry the caller-supplied retrieved_at_unix_ms"
        );
    }
}

/// The helper builds `EidosQuery.mode` from `retriever.mode()` — callers
/// cannot accidentally pass a mode-mismatched query. Two retrievers
/// with different modes exercise this through the same helper entry.
#[test]
fn produce_eidos_context_packet_canonicalizes_mode_from_retriever() {
    let lex = seeded_lexical_index();
    let packet_lex = produce_eidos_context_packet(&lex, "governance", 3, FIXED_RETRIEVED_AT_MS);
    assert_eq!(
        packet_lex.query.mode,
        EidosRetrievalMode::Lexical,
        "lexical retriever => Lexical query mode"
    );

    let claims = seeded_claim_evidence();
    let packet_claim =
        produce_eidos_context_packet(&claims, "claim-residency-governance", 3, FIXED_RETRIEVED_AT_MS);
    assert_eq!(
        packet_claim.query.mode,
        EidosRetrievalMode::ClaimEvidence,
        "claim-evidence retriever => ClaimEvidence query mode"
    );
    // sanity: same helper, different retriever, different mode — proves
    // the helper is truly generic over `EidosRetriever`, not pinned to
    // any single index strategy.
    assert_ne!(packet_lex.query.mode, packet_claim.query.mode);
}

/// Closed-citation contract holds end-to-end through the helper:
/// every hit's `source_id` validates against the returned packet's
/// manifest. A fabricated `source_id` is refused.
#[test]
fn produce_eidos_context_packet_preserves_closed_citation_contract() {
    let idx = seeded_lexical_index();
    let packet = produce_eidos_context_packet(&idx, "governance", 5, FIXED_RETRIEVED_AT_MS);

    for hit in &packet.hits {
        let citation = EidosCitation {
            source_id: hit.source_id.clone(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert!(
            packet.validate_citation(&citation).is_ok(),
            "every hit's source_id must self-validate against the packet"
        );
    }

    let forged = EidosCitation {
        source_id: agent_core::eidos::EidosChunkId::new("forged::lex")
            .expect("non-empty fabricated id"),
        manifest_id: packet.manifest_id.clone(),
    };
    assert!(
        packet.validate_citation(&forged).is_err(),
        "fabricated source_id MUST be rejected by closed-citation contract"
    );
}

/// The JSON helper agrees with the typed helper byte-for-byte for the
/// same `(retriever, query, top_k, timestamp)` inputs. Pins the
/// invariant that the two surfaces share one canonicalization path.
#[test]
fn produce_eidos_context_packet_json_round_trips_to_typed_helper() {
    let idx = seeded_lexical_index();
    let typed = produce_eidos_context_packet(&idx, "governance", 5, FIXED_RETRIEVED_AT_MS);
    let json = produce_eidos_context_packet_json(&idx, "governance", 5, FIXED_RETRIEVED_AT_MS)
        .expect("JSON helper must serialize cleanly for a well-formed packet");
    let decoded: EidosContextPacket =
        serde_json::from_str(&json).expect("round-trip JSON deserializes to packet");
    assert_eq!(typed, decoded, "JSON helper output must round-trip to the typed packet");
}

/// Empty query text yields an empty hit list (the lexical retriever's
/// blank-query guard). The helper does not panic or fabricate hits.
#[test]
fn produce_eidos_context_packet_empty_query_yields_empty_hits() {
    let idx = seeded_lexical_index();
    let packet = produce_eidos_context_packet(&idx, "", 5, FIXED_RETRIEVED_AT_MS);
    assert!(packet.hits.is_empty(), "blank query MUST produce zero hits");
    assert_eq!(packet.query.text, "", "query text passes through unchanged");
    assert_eq!(packet.manifest_id, *idx.manifest_id());
}

/// `top_k = 0` is honored — the retriever's contract turns it into an
/// empty packet. Pins the no-fabrication invariant for the edge case.
#[test]
fn produce_eidos_context_packet_zero_top_k_yields_empty_hits() {
    let idx = seeded_lexical_index();
    let packet = produce_eidos_context_packet(&idx, "governance", 0, FIXED_RETRIEVED_AT_MS);
    assert!(packet.hits.is_empty(), "top_k=0 MUST produce zero hits");
    assert_eq!(packet.query.top_k, 0, "top_k passes through unchanged");
}

/// The helper's `<R: EidosRetriever + ?Sized>` bound must accept
/// `&dyn EidosRetriever` so a future bridge FFI can hold a single
/// `Box<dyn EidosRetriever>` registry slot and dispatch through it.
/// This test compiles only if `?Sized` is present on the bound;
/// removing it silently breaks trait-object dispatch, which would
/// force every caller back to monomorphized generics.
#[test]
fn produce_eidos_context_packet_accepts_trait_object_dispatch() {
    use agent_core::eidos::EidosRetriever;
    let owned: Box<dyn EidosRetriever> = Box::new(seeded_lexical_index());
    let dyn_ref: &dyn EidosRetriever = owned.as_ref();
    let packet = produce_eidos_context_packet(dyn_ref, "governance", 3, FIXED_RETRIEVED_AT_MS);
    assert!(
        !packet.hits.is_empty(),
        "dyn-dispatch must still produce real hits against the seeded corpus"
    );
    assert_eq!(
        packet.query.mode,
        EidosRetrievalMode::Lexical,
        "trait-object dispatch still resolves retriever.mode() correctly"
    );
}
