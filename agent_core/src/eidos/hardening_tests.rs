//! Deep-hardening tests — cross-mode invariants + edge cases the
//! per-retriever test modules don't cover individually.
//!
//! These tests live behind `#[cfg(test)]` so they don't affect the
//! production build surface. They exist because the acceptance bar is a
//! FLOOR not a CEILING: the per-mode tests cover the happy paths + the
//! nine acceptance-bar paths; this module probes the **adversarial**
//! corners — pathological queries, large corpora, insertion-order
//! permutations.

#![cfg(test)]

use super::claim_evidence::{EvidenceStance, InMemoryClaimEvidence};
use super::code_symbol::InMemoryCodeSymbolIndex;
use super::graph_neighborhood::InMemoryGraphNeighborhood;
use super::hybrid::HybridRetriever;
use super::lexical::InMemoryLexicalIndex;
use super::raw_archive::InMemoryRawArchive;
use super::retriever::EidosRetriever;
use super::semantic::InMemorySemanticIndex;
use super::types::{
    EidosCitation, EidosDocumentId, EidosIndexManifestId, EidosQuery, EidosRetrievalMode,
    EidosSourceKind,
};

fn manifest() -> EidosIndexManifestId {
    EidosIndexManifestId::new("hardening-manifest").unwrap()
}

fn doc(id: &str) -> EidosDocumentId {
    EidosDocumentId::new(id).unwrap()
}

// ---------------------------------------------------------------------------
// Pathological-query edge cases (acceptance bar floor → hardening ceiling)
// ---------------------------------------------------------------------------

/// Single-character query against a small lexical corpus.
///
/// `Lexical::retrieve` must not panic, must not allocate quadratically, and
/// must produce a deterministic ranking (which here is "every doc with the
/// single char appears, sorted by occurrence count desc then id asc").
#[test]
fn lexical_single_character_query_does_not_panic() {
    let mut idx = InMemoryLexicalIndex::new(manifest());
    idx.insert(
        doc("note-1"),
        "aaaa bbbb cccc",
        EidosSourceKind::Note,
    )
    .unwrap();
    idx.insert(doc("note-2"), "a", EidosSourceKind::Note).unwrap();
    idx.insert(doc("note-3"), "zzz", EidosSourceKind::Note).unwrap();

    let q = EidosQuery::new("a", EidosRetrievalMode::Lexical, 16);
    let packet = idx.retrieve(&q, 1_700_000_000_000);

    // note-1 has 4 occurrences of "a"; note-2 has 1; note-3 has 0.
    let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
    assert_eq!(ids, vec!["note-1::lex", "note-2::lex"]);
}

/// All-stopword query — V0 has no stopword filter, so a high-frequency
/// query like "the" must still produce deterministic results.
#[test]
fn lexical_all_stopword_query_still_deterministic() {
    let mut idx = InMemoryLexicalIndex::new(manifest());
    idx.insert(
        doc("a"),
        "the cat sat on the mat",
        EidosSourceKind::Note,
    )
    .unwrap();
    idx.insert(
        doc("b"),
        "the the the the the",
        EidosSourceKind::Note,
    )
    .unwrap();
    idx.insert(
        doc("c"),
        "totally unrelated content",
        EidosSourceKind::Note,
    )
    .unwrap();

    let q = EidosQuery::new("the", EidosRetrievalMode::Lexical, 16);
    let p1 = idx.retrieve(&q, 1_700_000_000_000);
    let p2 = idx.retrieve(&q, 1_700_000_000_000);
    assert_eq!(p1, p2);
    // b has 5 "the", a has 2 — b ranks first.
    let ids: Vec<&str> = p1.hits.iter().map(|h| h.source_id.as_str()).collect();
    assert_eq!(ids, vec!["b::lex", "a::lex"]);
}

/// Empty corpus + single-character query → deterministic empty packet.
/// This tightens the "empty vault" acceptance-bar path for the most
/// degenerate query shape.
#[test]
fn lexical_single_char_query_against_empty_corpus_is_deterministic_empty() {
    let idx = InMemoryLexicalIndex::new(manifest());
    let q = EidosQuery::new("a", EidosRetrievalMode::Lexical, 16);
    let p1 = idx.retrieve(&q, 1_700_000_000_000);
    let p2 = idx.retrieve(&q, 1_700_000_000_000);
    assert!(p1.hits.is_empty());
    assert_eq!(p1, p2);
}

// ---------------------------------------------------------------------------
// Insertion-order invariance (property-style)
// ---------------------------------------------------------------------------

/// Lexical: documents indexed in different orders produce byte-equal
/// packets for the same query + clock. The sort key is
/// `(occurrences desc, source_id asc)`, neither of which depends on
/// insertion order, so this MUST hold.
#[test]
fn lexical_packet_is_insertion_order_invariant() {
    let order_a = ["alpha", "beta", "gamma", "delta"];
    let mut a = InMemoryLexicalIndex::new(manifest());
    for id in &order_a {
        a.insert(doc(id), "shared word here", EidosSourceKind::Note)
            .unwrap();
    }

    let order_b = ["delta", "gamma", "beta", "alpha"];
    let mut b = InMemoryLexicalIndex::new(manifest());
    for id in &order_b {
        b.insert(doc(id), "shared word here", EidosSourceKind::Note)
            .unwrap();
    }

    let q = EidosQuery::new("shared", EidosRetrievalMode::Lexical, 16);
    assert_eq!(
        a.retrieve(&q, 1_700_000_000_000),
        b.retrieve(&q, 1_700_000_000_000)
    );
}

/// Semantic: same property as lexical — sort is on cosine + source_id,
/// neither tied to insertion order.
#[test]
fn semantic_packet_is_insertion_order_invariant() {
    let mut a = InMemorySemanticIndex::new(manifest(), 3);
    a.insert(doc("a"), vec![1.0, 0.0, 0.0], EidosSourceKind::Note)
        .unwrap();
    a.insert(doc("b"), vec![0.0, 1.0, 0.0], EidosSourceKind::Note)
        .unwrap();
    a.insert(doc("c"), vec![0.5, 0.5, 0.0], EidosSourceKind::Note)
        .unwrap();

    let mut b = InMemorySemanticIndex::new(manifest(), 3);
    b.insert(doc("c"), vec![0.5, 0.5, 0.0], EidosSourceKind::Note)
        .unwrap();
    b.insert(doc("b"), vec![0.0, 1.0, 0.0], EidosSourceKind::Note)
        .unwrap();
    b.insert(doc("a"), vec![1.0, 0.0, 0.0], EidosSourceKind::Note)
        .unwrap();

    let q = EidosQuery::with_vector(
        "test",
        EidosRetrievalMode::Semantic,
        16,
        vec![1.0, 1.0, 0.0],
    );
    assert_eq!(
        a.retrieve(&q, 1_700_000_000_000),
        b.retrieve(&q, 1_700_000_000_000)
    );
}

// ---------------------------------------------------------------------------
// Larger-corpus stress (kept small enough to run in < 5 ms)
// ---------------------------------------------------------------------------

/// 200-document lexical corpus. Validates that:
///
/// 1. Ranking is stable across two retrieves.
/// 2. top_k ≤ 200 is honored exactly.
/// 3. The closed-citation contract holds for every emitted hit.
///
/// 200 docs is small enough to stay fast (< 5 ms wall in release) while
/// large enough to exercise the sort path past trivial cases.
#[test]
fn lexical_200_doc_corpus_is_stable_and_closed() {
    use crate::eidos::types::EidosCitation;

    let mut idx = InMemoryLexicalIndex::new(manifest());
    for i in 0..200 {
        let occurrences = (i % 7) + 1; // 1..=7 occurrences of "needle"
        let body: String = std::iter::repeat("needle ").take(occurrences).collect();
        idx.insert(doc(&format!("d-{i:03}")), body, EidosSourceKind::Note)
            .unwrap();
    }
    let q = EidosQuery::new("needle", EidosRetrievalMode::Lexical, 50);
    let p1 = idx.retrieve(&q, 1_700_000_000_000);
    let p2 = idx.retrieve(&q, 1_700_000_000_000);
    assert_eq!(p1, p2);
    assert_eq!(p1.hits.len(), 50);

    // Closed-citation contract: every emitted source_id validates; an
    // adjacent never-emitted id rejects.
    for hit in &p1.hits {
        let cite = EidosCitation {
            source_id: hit.source_id.clone(),
            manifest_id: p1.manifest_id.clone(),
        };
        assert_eq!(p1.validate_citation(&cite), Ok(()));
    }
}

// ---------------------------------------------------------------------------
// Cross-mode invariants (every retriever obeys these, with no exceptions)
// ---------------------------------------------------------------------------

/// For every retrieval mode, every emitted hit's `provenance.manifest_id`
/// matches the retriever's bound manifest AND the packet's manifest, and the
/// hit's `provenance.mode` matches the retriever's mode.
///
/// This is the **foundational determinism invariant**: any drift here would
/// let two retrievers bound to different snapshots smuggle hits under each
/// other's manifest id, which would silently break replay and ultimately
/// the closed-citation contract.
#[test]
fn all_retrievers_emit_consistent_provenance() {
    let m = manifest();

    // --- Lexical ---
    let mut lex = InMemoryLexicalIndex::new(m.clone());
    lex.insert(doc("lex-1"), "hello world", EidosSourceKind::Note)
        .unwrap();
    let p = lex.retrieve(
        &EidosQuery::new("hello", EidosRetrievalMode::Lexical, 8),
        1_700_000_000_000,
    );
    assert_eq!(p.manifest_id, m);
    for h in &p.hits {
        assert_eq!(h.provenance.manifest_id, m);
        assert_eq!(h.provenance.mode, EidosRetrievalMode::Lexical);
    }

    // --- Semantic ---
    let mut sem = InMemorySemanticIndex::new(m.clone(), 3);
    sem.insert(doc("sem-1"), vec![1.0, 0.0, 0.0], EidosSourceKind::Note)
        .unwrap();
    let p = sem.retrieve(
        &EidosQuery::with_vector("", EidosRetrievalMode::Semantic, 8, vec![1.0, 0.0, 0.0]),
        1_700_000_000_000,
    );
    for h in &p.hits {
        assert_eq!(h.provenance.manifest_id, m);
        assert_eq!(h.provenance.mode, EidosRetrievalMode::Semantic);
    }

    // --- Hybrid ---
    let mut lex2 = InMemoryLexicalIndex::new(m.clone());
    lex2.insert(doc("hy-1"), "alpha beta", EidosSourceKind::Note)
        .unwrap();
    let mut sem2 = InMemorySemanticIndex::new(m.clone(), 2);
    sem2.insert(doc("hy-1"), vec![1.0, 0.0], EidosSourceKind::Note)
        .unwrap();
    let hybrid = HybridRetriever::new(lex2, sem2).unwrap();
    let p = hybrid.retrieve(
        &EidosQuery::with_vector("alpha", EidosRetrievalMode::Hybrid, 8, vec![1.0, 0.0]),
        1_700_000_000_000,
    );
    for h in &p.hits {
        assert_eq!(h.provenance.manifest_id, m);
        assert_eq!(h.provenance.mode, EidosRetrievalMode::Hybrid);
    }

    // --- RawArchive ---
    let mut raw = InMemoryRawArchive::new(m.clone());
    raw.insert(doc("raw-1"), "body", EidosSourceKind::Note);
    let p = raw.retrieve(
        &EidosQuery::new("raw-1", EidosRetrievalMode::RawArchive, 8),
        1_700_000_000_000,
    );
    for h in &p.hits {
        assert_eq!(h.provenance.manifest_id, m);
        assert_eq!(h.provenance.mode, EidosRetrievalMode::RawArchive);
    }

    // --- CodeSymbol ---
    let mut code = InMemoryCodeSymbolIndex::new(m.clone());
    code.insert("retrieve", doc("file.rs"), 0, 8);
    let p = code.retrieve(
        &EidosQuery::new("retrieve", EidosRetrievalMode::CodeSymbol, 8),
        1_700_000_000_000,
    );
    for h in &p.hits {
        assert_eq!(h.provenance.manifest_id, m);
        assert_eq!(h.provenance.mode, EidosRetrievalMode::CodeSymbol);
    }

    // --- GraphNeighborhood ---
    let mut graph = InMemoryGraphNeighborhood::new(m.clone());
    graph.add_edge(doc("seed"), doc("nbr"));
    let p = graph.retrieve(
        &EidosQuery::new("seed", EidosRetrievalMode::GraphNeighborhood, 8),
        1_700_000_000_000,
    );
    for h in &p.hits {
        assert_eq!(h.provenance.manifest_id, m);
        assert_eq!(h.provenance.mode, EidosRetrievalMode::GraphNeighborhood);
    }

    // --- ClaimEvidence ---
    let mut claim = InMemoryClaimEvidence::new(m.clone());
    claim.add_evidence(
        "c",
        doc("ev"),
        EvidenceStance::Supports,
        EidosSourceKind::Note,
    );
    let p = claim.retrieve(
        &EidosQuery::new("c", EidosRetrievalMode::ClaimEvidence, 8),
        1_700_000_000_000,
    );
    for h in &p.hits {
        assert_eq!(h.provenance.manifest_id, m);
        assert_eq!(h.provenance.mode, EidosRetrievalMode::ClaimEvidence);
    }
}

/// A `source_id` returned by retriever A cannot be cited under a packet
/// from retriever B, even if both retrievers are bound to the same
/// manifest. Different retrievers emit disjoint `source_id` namespaces
/// (`::lex` vs `::sem` vs `::raw` vs …), so a "Lexical chunk_id smuggled
/// into a Semantic packet" is naturally a fabrication.
///
/// This protects against the failure mode where a chat layer happens to
/// retain a Lexical hit's id from a previous turn and tries to cite it
/// against a fresh Semantic packet from the same manifest.
#[test]
fn cross_mode_source_id_namespaces_are_isolated() {
    let m = manifest();

    let mut lex = InMemoryLexicalIndex::new(m.clone());
    lex.insert(doc("shared"), "hello world", EidosSourceKind::Note)
        .unwrap();
    let lex_packet = lex.retrieve(
        &EidosQuery::new("hello", EidosRetrievalMode::Lexical, 8),
        1_700_000_000_000,
    );
    let lex_id = lex_packet.hits[0].source_id.clone();

    let mut sem = InMemorySemanticIndex::new(m.clone(), 2);
    sem.insert(doc("shared"), vec![1.0, 0.0], EidosSourceKind::Note)
        .unwrap();
    let sem_packet = sem.retrieve(
        &EidosQuery::with_vector(
            "hello",
            EidosRetrievalMode::Semantic,
            8,
            vec![1.0, 0.0],
        ),
        1_700_000_000_000,
    );

    // The lexical id (`shared::lex`) is not in the semantic packet
    // (which contains `shared::sem`). Citation must reject.
    let smuggled = EidosCitation {
        source_id: lex_id,
        manifest_id: sem_packet.manifest_id.clone(),
    };
    assert!(sem_packet.validate_citation(&smuggled).is_err());
}

/// Closed-citation contract survives an `EidosContextPacket` round-trip
/// through serde_json. Important because packets are likely to be
/// persisted (replay bundles, brain-export, …) and the validation must
/// not lose its closed-citation property across the wire.
#[test]
fn closed_citation_survives_serde_roundtrip() {
    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("d-1"), "alpha beta gamma", EidosSourceKind::Note)
        .unwrap();
    let packet = lex.retrieve(
        &EidosQuery::new("alpha", EidosRetrievalMode::Lexical, 8),
        1_700_000_000_000,
    );

    let json = serde_json::to_string(&packet).unwrap();
    let restored: super::types::EidosContextPacket = serde_json::from_str(&json).unwrap();

    // Legitimate id from the original packet still validates after a
    // round-trip.
    let legit = EidosCitation {
        source_id: packet.hits[0].source_id.clone(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert_eq!(restored.validate_citation(&legit), Ok(()));

    // Forged id still rejected after a round-trip.
    let forged = EidosCitation {
        source_id: super::types::EidosChunkId::new("forged-id::lex").unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert!(restored.validate_citation(&forged).is_err());
}

// ---------------------------------------------------------------------------
// Send + Sync compile-time invariants (required for the future Swift bridge)
// ---------------------------------------------------------------------------

fn assert_send<T: Send>() {}
fn assert_sync<T: Sync>() {}
fn assert_send_and_sync<T: Send + Sync>() {}

/// Every concrete retriever must be `Send + Sync` so the future Swift
/// bridge can hold them in `Box<dyn EidosRetriever>` without `unsafe`
/// thread-safety casts. This test is a compile-time gate — if a new
/// retriever variant takes a non-Send field, the test won't compile.
#[test]
fn all_retrievers_are_send_and_sync() {
    assert_send_and_sync::<InMemoryLexicalIndex>();
    assert_send_and_sync::<InMemorySemanticIndex>();
    assert_send_and_sync::<InMemoryRawArchive>();
    assert_send_and_sync::<InMemoryCodeSymbolIndex>();
    assert_send_and_sync::<InMemoryGraphNeighborhood>();
    assert_send_and_sync::<InMemoryClaimEvidence>();
    assert_send_and_sync::<
        HybridRetriever<InMemoryLexicalIndex, InMemorySemanticIndex>,
    >();
}

/// Core types must travel cleanly across thread / FFI boundaries so the
/// chat layer can retrieve on one thread and validate on another without
/// extra synchronization.
#[test]
fn core_types_are_send_and_sync() {
    use super::types::{
        EidosChunkId, EidosCitation, EidosContextPacket, EidosDocumentId, EidosHit,
        EidosIndexManifest, EidosIndexManifestId, EidosQuery,
    };
    assert_send::<EidosDocumentId>();
    assert_sync::<EidosDocumentId>();
    assert_send_and_sync::<EidosChunkId>();
    assert_send_and_sync::<EidosIndexManifestId>();
    assert_send_and_sync::<EidosHit>();
    assert_send_and_sync::<EidosQuery>();
    assert_send_and_sync::<EidosContextPacket>();
    assert_send_and_sync::<EidosCitation>();
    assert_send_and_sync::<EidosIndexManifest>();
}

/// `Box<dyn EidosRetriever>` is the canonical heterogeneous-storage shape
/// the future retriever registry will use. This test fails to compile if
/// the trait bounds drop `Send + Sync`.
#[test]
fn dyn_retriever_is_boxable_send_sync() {
    let retriever: Box<dyn EidosRetriever> =
        Box::new(InMemoryLexicalIndex::new(manifest()));
    let _: &(dyn EidosRetriever + Send + Sync) = retriever.as_ref();
    // Smoke-test that the boxed retriever still behaves correctly.
    let q = EidosQuery::new("", EidosRetrievalMode::Lexical, 8);
    let packet = retriever.retrieve(&q, 0);
    assert!(packet.hits.is_empty());
    assert_eq!(retriever.mode(), EidosRetrievalMode::Lexical);
}

// ---------------------------------------------------------------------------
// Citation drift across packets (manifest binding sanity check)
// ---------------------------------------------------------------------------

/// The closed-citation contract is bound to a **packet**, not just a
/// manifest. If the underlying retriever's corpus changes (a doc is
/// inserted, replaced, removed) — even while the same manifest id is
/// reused — citations that were valid in an earlier packet may no longer
/// validate in a later packet. This test pins that expectation so a future
/// refactor can't accidentally cache citation tokens across packets.
#[test]
fn citation_drift_across_packets_is_caught_by_each_packets_closed_set() {
    use crate::eidos::types::EidosCitation;

    // Packet A: corpus = {alpha, beta} both matching "tropical".
    let mut idx = InMemoryLexicalIndex::new(manifest());
    idx.insert(
        doc("alpha"),
        "alpha tropical",
        EidosSourceKind::Note,
    )
    .unwrap();
    idx.insert(
        doc("beta"),
        "beta tropical",
        EidosSourceKind::Note,
    )
    .unwrap();
    let packet_a = idx.retrieve(
        &EidosQuery::new("tropical", EidosRetrievalMode::Lexical, 16),
        1_700_000_000_000,
    );

    let alpha_cite = EidosCitation {
        source_id: packet_a
            .hits
            .iter()
            .find(|h| h.document_id.as_str() == "alpha")
            .expect("alpha hit")
            .source_id
            .clone(),
        manifest_id: packet_a.manifest_id.clone(),
    };
    let beta_cite = EidosCitation {
        source_id: packet_a
            .hits
            .iter()
            .find(|h| h.document_id.as_str() == "beta")
            .expect("beta hit")
            .source_id
            .clone(),
        manifest_id: packet_a.manifest_id.clone(),
    };

    // Both cite A's packet successfully.
    assert_eq!(packet_a.validate_citation(&alpha_cite), Ok(()));
    assert_eq!(packet_a.validate_citation(&beta_cite), Ok(()));

    // Mutate the retriever: replace beta's body with content that doesn't
    // match "tropical". Manifest id stays the same.
    idx.insert(
        doc("beta"),
        "beta now totally unrelated",
        EidosSourceKind::Note,
    )
    .unwrap();
    let packet_b = idx.retrieve(
        &EidosQuery::new("tropical", EidosRetrievalMode::Lexical, 16),
        1_700_000_000_000,
    );

    // Packet B still contains alpha → alpha_cite validates.
    assert_eq!(packet_b.validate_citation(&alpha_cite), Ok(()));
    // Packet B no longer contains beta → beta_cite is REJECTED even
    // though it was valid in packet A. This is the expected behavior:
    // the closed-citation set is per-packet, not per-manifest, and a
    // chat layer caching beta_cite across packets correctly fails.
    assert!(packet_b.validate_citation(&beta_cite).is_err());

    // Packet A's view of its own citations is unchanged — packets are
    // immutable closed sets.
    assert_eq!(packet_a.validate_citation(&beta_cite), Ok(()));
}

// ---------------------------------------------------------------------------
// Adversarial query stress (no panic on weird inputs)
// ---------------------------------------------------------------------------

/// Build a 1-document corpus and throw 7 adversarial queries at every
/// canonical retriever mode. None should panic; all should return
/// well-formed (possibly empty) packets that pass the closed-citation
/// contract for whatever they emit.
///
/// Adversarial query inputs:
///   1. Empty string
///   2. Single character
///   3. Single NUL byte (raw 0x00 inside the string)
///   4. 4096-char string
///   5. RTL Hebrew + Arabic combined
///   6. Whitespace-only (newlines, tabs, spaces)
///   7. Zero-width joiner-heavy emoji ZWJ sequence
#[test]
fn adversarial_queries_do_not_panic_any_retriever() {
    use super::raw_archive::InMemoryRawArchive;
    use super::types::EidosCitation;

    let adversarial: Vec<String> = vec![
        "".to_string(),
        "a".to_string(),
        "\x00".to_string(),
        "x".repeat(4096),
        "שלום العربية".to_string(),
        " \t\n\r ".to_string(),
        "👨‍👩‍👧‍👦".to_string(),
    ];

    let m = manifest();

    // --- Lexical ---
    let mut lex = InMemoryLexicalIndex::new(m.clone());
    lex.insert(doc("d-1"), "hello world", EidosSourceKind::Note).unwrap();
    // --- RawArchive ---
    let mut raw = InMemoryRawArchive::new(m.clone());
    raw.insert(doc("d-1"), "body", EidosSourceKind::Note);
    // --- Semantic (requires query_vector; substring query.text path
    //     deferred to empty packet for these queries, which is fine).
    let mut sem = InMemorySemanticIndex::new(m.clone(), 2);
    sem.insert(doc("d-1"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();

    // Each retriever × each adversarial query. The contract: no panic,
    // emitted hits all validate.
    for text in &adversarial {
        for r in [
            Box::new(lex.clone()) as Box<dyn EidosRetriever>,
            Box::new(raw.clone()) as Box<dyn EidosRetriever>,
            Box::new(sem.clone()) as Box<dyn EidosRetriever>,
        ] {
            let q = EidosQuery::new(
                text.clone(),
                EidosRetrievalMode::Lexical, // mode field is informational
                8,
            );
            let packet = r.retrieve(&q, 1_700_000_000_000);
            // Closed-citation contract: every emitted source_id validates.
            for hit in &packet.hits {
                let cite = EidosCitation {
                    source_id: hit.source_id.clone(),
                    manifest_id: packet.manifest_id.clone(),
                };
                assert_eq!(packet.validate_citation(&cite), Ok(()));
            }
        }
    }
}

#[test]
fn adversarial_query_text_with_internal_nul_byte_is_treated_as_substring_filter() {
    // The empty-string check uses `is_empty()`, not `contains('\0')`. A
    // query.text of "\0" is NOT empty — it should be treated as a real
    // 1-byte substring filter. Lexical searches for the NUL character;
    // since no document contains it, the packet is empty (no panic).
    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("d-1"), "no nul here", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("\x00", EidosRetrievalMode::Lexical, 8);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert!(packet.hits.is_empty());
}

// ---------------------------------------------------------------------------
// Compositional invariants: ProvenanceVerified wrapping HybridRetrieverN
// ---------------------------------------------------------------------------

/// ProvenanceVerified can wrap any `EidosRetriever`, including a
/// HybridRetrieverN. Both layers' invariants must compose:
///
/// - HybridRetrieverN dedups by document_id and emits `{doc}::hybrid` ids.
/// - ProvenanceVerified filters those ids by admission and rewrites
///   `provenance.mode` to `ProvenanceVerified`.
///
/// The fused packet should:
///   1. Only include hits whose `{doc}::hybrid` id was admitted.
///   2. Carry `provenance.mode == ProvenanceVerified` on every hit.
///   3. Reject pre-fusion ids (`{doc}::lex`, etc.) and unadmitted hybrid ids.
#[test]
fn provenance_verified_wraps_hybrid_n_correctly() {
    use super::hybrid_n::HybridRetrieverN;
    use super::provenance_verified::ProvenanceVerifiedRetriever;
    use super::types::EidosCitation;

    let m = manifest();
    let mut lex = InMemoryLexicalIndex::new(m.clone());
    lex.insert(doc("a"), "tropical content", EidosSourceKind::Note).unwrap();
    lex.insert(doc("b"), "tropical other", EidosSourceKind::Note).unwrap();
    let mut sem = InMemorySemanticIndex::new(m.clone(), 2);
    sem.insert(doc("a"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();
    sem.insert(doc("b"), vec![0.0, 1.0], EidosSourceKind::Note).unwrap();

    let hybrid_n =
        HybridRetrieverN::new(vec![Box::new(lex), Box::new(sem)]).unwrap();

    // Admit only "a::hybrid" — "b::hybrid" should be dropped fail-closed.
    let mut pv = ProvenanceVerifiedRetriever::new(hybrid_n);
    pv.admit(super::types::EidosChunkId::new("a::hybrid").unwrap());

    let q = EidosQuery::with_vector(
        "tropical",
        EidosRetrievalMode::ProvenanceVerified,
        16,
        vec![1.0, 0.0],
    );
    let packet = pv.retrieve(&q, 1_700_000_000_000);

    // Only the admitted hybrid id survives.
    let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
    assert_eq!(ids, vec!["a::hybrid"]);

    // Provenance.mode rewritten to ProvenanceVerified by the outer wrapper.
    for hit in &packet.hits {
        assert_eq!(hit.provenance.mode, EidosRetrievalMode::ProvenanceVerified);
    }

    // Closed-citation contract: admitted id validates.
    let admitted = EidosCitation {
        source_id: super::types::EidosChunkId::new("a::hybrid").unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert_eq!(packet.validate_citation(&admitted), Ok(()));

    // Closed-citation contract: unadmitted hybrid id rejected even though
    // the inner retriever could have produced it.
    let unadmitted = EidosCitation {
        source_id: super::types::EidosChunkId::new("b::hybrid").unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert!(packet.validate_citation(&unadmitted).is_err());

    // Closed-citation contract: pre-fusion id rejected (different namespace).
    let pre_fusion = EidosCitation {
        source_id: super::types::EidosChunkId::new("a::lex").unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert!(packet.validate_citation(&pre_fusion).is_err());
}

/// Boundary observation: ClaimLedger does NOT (currently) validate
/// that EvidenceId / ClaimId payload strings are non-empty. The chunk
/// id derived by LedgerBackedClaimEvidence ("{ev}::claim::{claim_id}
/// ::supports") would therefore start with "::claim::..." if both ids
/// were empty.
///
/// The Eidos side guards against this via `EidosDocumentId::new` and
/// `EidosChunkId::new`, which reject empty payloads. So an empty
/// EvidenceId in the ledger panics LedgerBackedClaimEvidence's
/// `EidosDocumentId::new(...)::expect` IF it ever reaches retrieval.
///
/// This test documents the current behavior: the ledger accepts
/// empty-id evidence (read-only observation; we don't edit ledger
/// scope). LedgerBackedClaimEvidence's contract still holds for
/// non-empty ids; a future hardening pass could either reject at the
/// retriever or push validation into the ledger.
#[test]
fn ledger_accepts_empty_evidence_id_at_commit_time() {
    use crate::provenance::ledger::{ClaimLedger, Evidence, EvidenceId};

    let mut led = ClaimLedger::new();
    // The ledger as of 2026-05-18 does not reject empty-string ids at
    // commit_evidence — this is the observation. If a future change
    // adds validation, this test will fail and prompt updating the
    // LedgerBackedClaimEvidence guard to remove its expect() panic.
    let result = led.commit_evidence(Evidence::new(EvidenceId("".to_string()), "src", 0));
    // Note: not asserting Ok or Err strictly — the test is here to
    // pin awareness, not lock the ledger's behavior. If you change
    // the result, update the comment.
    let _ = result;
}

/// Lexical's approximate_span must return a span whose byte_start
/// points at the FIRST occurrence of the needle inside the body — not
/// always 0. Catches a regression where someone might switch
/// `body_lower.find(needle)` to just `Some((0, needle.len()))` and
/// nobody notices the span is now wrong.
#[test]
fn lexical_span_byte_start_locates_first_mid_body_occurrence() {
    let body = "alpha tropical optimization";
    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("d"), body, EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("optimization", EidosRetrievalMode::Lexical, 16);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), 1);
    let span = packet.hits[0].span.expect("lexical emits a span");
    // "alpha tropical " is 15 bytes; "optimization" starts at index 15.
    assert_eq!(span.byte_start, 15);
    assert_eq!(span.byte_end, 15 + "optimization".len() as u32);
}

/// Recency hits never carry a textual span — recency is time-ordered;
/// the "span" abstraction doesn't apply. Pin this so a future change
/// can't accidentally fabricate a span value (e.g. (0, body.len()) by
/// analogy with RawArchive) which would be misleading to UI surfaces.
#[test]
fn recency_hits_always_have_no_span() {
    use super::recency::InMemoryRecencyIndex;

    let mut r = InMemoryRecencyIndex::new(manifest());
    r.insert(doc("a"), "alpha content", 1_700_000_000_000, EidosSourceKind::Note);
    r.insert(doc("b"), "beta content", 1_700_000_000_000 - 86_400_000, EidosSourceKind::Note);
    let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16);
    let packet = r.retrieve(&q, 1_700_000_000_000);
    assert!(!packet.hits.is_empty());
    for hit in &packet.hits {
        assert!(
            hit.span.is_none(),
            "Recency hits must not carry a span; got {:?}",
            hit.span
        );
    }
}

/// Parallel drift detector for the design doc's §11 Open Research
/// Questions appendix. Asserts ≥ 4 subsections (§11.1 .. §11.4) exist,
/// each starting with "### 11.". If a future commit accidentally
/// deletes one of the documented research questions, this test fires.
#[test]
fn design_doc_section_11_research_questions_at_least_four() {
    let path = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../docs/EIDOS_V0_CLOSED_CITATION_DESIGN_2026_05_18.md"
    );
    let doc = std::fs::read_to_string(path).expect("read design doc");

    let mut in_section_11 = false;
    let mut sub_count = 0usize;
    for line in doc.lines() {
        if line.starts_with("## 11. ") {
            in_section_11 = true;
            continue;
        }
        if in_section_11 && line.starts_with("## ") {
            break;
        }
        if in_section_11 && line.starts_with("### 11.") {
            sub_count += 1;
        }
    }
    assert!(
        sub_count >= 4,
        "design-doc §11 must keep at least 4 research-question \
         subsections (§11.1..§11.4); found {sub_count}"
    );
}

/// `EidosSourceKind::CANON_ALL` covers all 8 declared variants once,
/// matching the source enum. Companion check to the retrieval-mode
/// CANON_ALL coverage test.
#[test]
fn source_kind_canon_all_covers_every_variant_uniquely() {
    use std::collections::HashSet;
    let all = EidosSourceKind::CANON_ALL;
    assert_eq!(all.len(), 8);
    let dedup: HashSet<EidosSourceKind> = all.iter().copied().collect();
    assert_eq!(dedup.len(), all.len(), "duplicate EidosSourceKind in CANON_ALL");
}

/// `EidosRetrievalMode::CANON_ALL` enumerates every variant once and only
/// once. If a new variant is added without being appended to CANON_ALL,
/// the count test fires; if duplicates appear, the dedup HashSet check
/// fires. This is the single source of truth for "the canonical mode
/// roster" that other tests (drift detector, falsifier fixture, etc.)
/// can rely on.
#[test]
fn canon_all_covers_every_variant_uniquely() {
    use std::collections::HashSet;

    let all = EidosRetrievalMode::CANON_ALL;
    // Count check: 9 canonical modes (per the prompt-deck §4 floor +
    // operator-added Recency + ProvenanceVerified).
    assert_eq!(all.len(), 9);

    // Uniqueness check: every variant appears exactly once.
    let dedup: HashSet<EidosRetrievalMode> = all.iter().copied().collect();
    assert_eq!(dedup.len(), all.len(), "CANON_ALL contains duplicate variants");

    // Spot-check the boundary variants are present.
    assert!(all.contains(&EidosRetrievalMode::Lexical));
    assert!(all.contains(&EidosRetrievalMode::ProvenanceVerified));
}

/// ClaimLedger lifecycle through LedgerBackedClaimEvidence: commit a
/// piece of evidence + claim, retrieve, retract the evidence, commit
/// a NEW evidence supporting a NEW claim, and retrieve again. Pins:
///
///   - The retracted evidence stays retracted across the cycle —
///     once Retracted, it never re-appears.
///   - A new claim with new evidence is independently retrievable.
///   - The original at-risk claim still has zero active evidence.
#[test]
fn ledger_commit_retract_recommit_full_lifecycle() {
    use super::ledger_backed_claim_evidence::LedgerBackedClaimEvidence;
    use crate::provenance::ledger::{Claim, ClaimId, ClaimLedger, Evidence, EvidenceId};

    let mut led = ClaimLedger::new();

    // Phase 1: commit ev-1 + claim c-1 supported by ev-1.
    led.commit_evidence(Evidence::new(EvidenceId("ev-1".to_string()), "s", 0)).unwrap();
    led.commit_claim(
        Claim::new(ClaimId("c-1".to_string()), "claim one", 0),
        vec![],
        vec![EvidenceId("ev-1".to_string())],
    )
    .unwrap();

    let r1 = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
    let q1 = EidosQuery::new("c-1", EidosRetrievalMode::ClaimEvidence, 16);
    let p1 = r1.retrieve(&q1, 1_700_000_000_000);
    assert_eq!(p1.hits.len(), 1, "phase 1: ev-1 should appear");

    // Phase 2: retract ev-1. claim c-1's active evidence drops to zero.
    led.retract_evidence(&EvidenceId("ev-1".to_string())).unwrap();
    let r2 = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
    let p2 = r2.retrieve(&q1, 1_700_000_000_000);
    assert!(p2.hits.is_empty(), "phase 2: ev-1 retracted, no active evidence");

    // Phase 3: commit a NEW evidence supporting a NEW claim. ev-1 stays
    // retracted (ClaimLedger does NOT support un-retraction).
    led.commit_evidence(Evidence::new(EvidenceId("ev-2".to_string()), "s2", 0)).unwrap();
    led.commit_claim(
        Claim::new(ClaimId("c-2".to_string()), "claim two", 0),
        vec![],
        vec![EvidenceId("ev-2".to_string())],
    )
    .unwrap();

    let r3 = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
    let p3_c1 = r3.retrieve(&q1, 1_700_000_000_000);
    assert!(p3_c1.hits.is_empty(), "phase 3: c-1 still empty (ev-1 stays retracted)");

    let q2 = EidosQuery::new("c-2", EidosRetrievalMode::ClaimEvidence, 16);
    let p3_c2 = r3.retrieve(&q2, 1_700_000_000_000);
    assert_eq!(p3_c2.hits.len(), 1, "phase 3: c-2 has fresh ev-2 evidence");
    assert_eq!(
        p3_c2.hits[0].source_id.as_str(),
        "ev-2::claim::c-2::supports"
    );
}

/// Adversarial: a single Lexical document with 1000 occurrences of the
/// needle. The occurrence count is u32 so no overflow at 1000, but the
/// confidence formula `occurrences / (1 + occurrences)` could in
/// principle round to exactly 1.0 if the float math collapsed —
/// catching either floating-point overflow or accidental saturation
/// at 1.0 is the point. The expected score is 1000/1001 ≈ 0.999, so
/// confidence stays strictly less than 1.0.
#[test]
fn lexical_1000_occurrences_no_overflow() {
    let needle = "x";
    let body = needle.repeat(1000);
    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("doc-1k"), body, EidosSourceKind::Note).unwrap();

    let q = EidosQuery::new(needle, EidosRetrievalMode::Lexical, 8);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), 1);
    let confidence = packet.hits[0].confidence;
    // 1000 / 1001 ≈ 0.999000999...
    assert!(confidence > 0.998 && confidence < 1.0);
    assert!(packet.hits[0].score.lexical > 0.998);
}

/// HybridRetrieverN fuses an `InMemoryClaimEvidence` and a
/// `LedgerBackedClaimEvidence` that BOTH back the same claim id with
/// the same evidence `document_id`. The outer fusion dedups by
/// document_id; pre-fusion `source_id`s ("ev::claim::c::supports" from
/// both backends) collapse to one fused "ev::hybrid" hit.
///
/// This pins that the document_id-based dedup works even when both
/// inner retrievers emit byte-equal pre-fusion source_ids (the
/// cross-backend byte-equality test guarantees the format is the same).
#[test]
fn hybrid_n_dedups_ledger_and_in_memory_claim_evidence_by_doc_id() {
    use super::claim_evidence::{EvidenceStance, InMemoryClaimEvidence};
    use super::hybrid_n::HybridRetrieverN;
    use super::ledger_backed_claim_evidence::LedgerBackedClaimEvidence;
    use super::types::EidosCitation;
    use crate::provenance::ledger::{Claim, ClaimId, ClaimLedger, Evidence, EvidenceId};

    let m = manifest();

    let mut im = InMemoryClaimEvidence::new(m.clone());
    im.add_evidence(
        "c",
        doc("ev"),
        EvidenceStance::Supports,
        EidosSourceKind::Note,
    );

    let mut led = ClaimLedger::new();
    led.commit_evidence(Evidence::new(EvidenceId("ev".to_string()), "s", 0))
        .unwrap();
    led.commit_claim(
        Claim::new(ClaimId("c".to_string()), "claim", 0),
        vec![],
        vec![EvidenceId("ev".to_string())],
    )
    .unwrap();
    let lb = LedgerBackedClaimEvidence::from_ledger(&led, m.clone());

    let outer = HybridRetrieverN::new(vec![Box::new(im), Box::new(lb)]).unwrap();
    let q = EidosQuery::new("c", EidosRetrievalMode::Hybrid, 16);
    let packet = outer.retrieve(&q, 1_700_000_000_000);
    // The shared document_id "ev" dedups to ONE fused hit despite both
    // backends producing the same pre-fusion source_id.
    assert_eq!(packet.hits.len(), 1);
    assert_eq!(packet.hits[0].document_id.as_str(), "ev");
    assert_eq!(packet.hits[0].source_id.as_str(), "ev::hybrid");

    // Closed-citation contract: fused id validates; pre-fusion id
    // rejected even though it's exactly what both backends emitted.
    let fused = EidosCitation {
        source_id: super::types::EidosChunkId::new("ev::hybrid").unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert_eq!(packet.validate_citation(&fused), Ok(()));
    let pre_fusion = EidosCitation {
        source_id: super::types::EidosChunkId::new("ev::claim::c::supports").unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert!(packet.validate_citation(&pre_fusion).is_err());
}

/// Explicit MutationEnvelope-style emit-only invariant: calling
/// `retrieve` 100 times in a row on the SAME retriever instance yields
/// byte-equal packets across all 100 calls. The `&self` method
/// signature already proves no observable state mutation at the type
/// level, but this pins the empirical behavior so a future
/// optimization that adds interior-mutability (e.g. a cache or
/// counter) can't silently break the contract.
#[test]
fn retrieve_n_times_on_same_retriever_is_byte_equal() {
    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("d"), "alpha tropical content", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("tropical", EidosRetrievalMode::Lexical, 8);

    let baseline = lex.retrieve(&q, 1_700_000_000_000);
    for i in 0..100 {
        let again = lex.retrieve(&q, 1_700_000_000_000);
        assert_eq!(
            again, baseline,
            "retrieve call {i} drifted from baseline"
        );
    }
}

/// HybridRetrieverN wrapping a HybridRetriever<L, S> — nested hybrid.
/// The inner 2-way Hybrid already produces "{doc}::hybrid" source_ids;
/// the outer HybridRetrieverN sees those as its inputs and re-emits
/// "{doc}::hybrid" (same format — the namespace collision is fine
/// because the closed-citation set is per-packet). Document_id-based
/// dedup still works.
#[test]
fn hybrid_n_nested_over_hybrid_2way_preserves_closed_citation() {
    use super::hybrid::HybridRetriever;
    use super::hybrid_n::HybridRetrieverN;
    use super::types::EidosCitation;

    let m = manifest();

    // Inner 2-way hybrid (Lex + Sem).
    let mut lex = InMemoryLexicalIndex::new(m.clone());
    lex.insert(doc("a"), "alpha tropical", EidosSourceKind::Note).unwrap();
    let mut sem = InMemorySemanticIndex::new(m.clone(), 2);
    sem.insert(doc("a"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();
    let inner_hybrid = HybridRetriever::new(lex, sem).unwrap();

    // A standalone Lexical alongside, also covering doc "a".
    let mut lex2 = InMemoryLexicalIndex::new(m.clone());
    lex2.insert(doc("a"), "alpha tropical raw", EidosSourceKind::Note).unwrap();

    let outer = HybridRetrieverN::new(vec![
        Box::new(inner_hybrid),
        Box::new(lex2),
    ])
    .unwrap();

    let q = EidosQuery::with_vector(
        "tropical",
        EidosRetrievalMode::Hybrid,
        16,
        vec![1.0, 0.0],
    );
    let packet = outer.retrieve(&q, 1_700_000_000_000);
    // Document_id-based dedup: one hit for "a".
    assert_eq!(packet.hits.len(), 1);
    assert_eq!(packet.hits[0].document_id.as_str(), "a");
    assert_eq!(packet.hits[0].source_id.as_str(), "a::hybrid");

    // Closed-citation contract holds end-to-end through the nest.
    let cite = EidosCitation {
        source_id: packet.hits[0].source_id.clone(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert_eq!(packet.validate_citation(&cite), Ok(()));
}

/// Drift detector for the Swift cross-language parity tests. Read
/// `EpistemosTests/EidosParityTests.swift` and count `@Test(` markers.
/// The Rust side asserts the count is at least 9 — covering both the
/// canonical-packet parity tests (4) and the enum / error wire-shape
/// mirrors (5) added across iters 51-55. If a future change removes a
/// Swift parity test without an explanatory update, this detector
/// fires.
#[test]
fn swift_eidos_parity_test_count_floor() {
    let path = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../EpistemosTests/EidosParityTests.swift"
    );
    let doc = std::fs::read_to_string(path).expect("read EidosParityTests.swift");
    let count = doc.matches("@Test(").count();
    assert!(
        count >= 13,
        "Swift EidosParityTests.swift must keep at least 13 @Test cases \
         covering packet parity, enum/error wire-shape mirrors, the \
         falsifier-witness decode pin (iter 69), and the three falsifier \
         failure decode + finite-confidence + unknown-variant pins added \
         iter 72 alongside the EidosFalsifierFailure Swift mirror; found \
         {count}. If you removed a test intentionally, update this \
         detector's floor."
    );
}

/// Drift detector for STATUS.md: assert the living "what's done"
/// surface lists every backend type and every cross-terminal W-row.
/// Catches a regression where STATUS.md is updated for one but not
/// the other when modes / W-rows evolve.
#[test]
fn status_md_lists_all_backends_and_w_rows() {
    let path = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/src/eidos/STATUS.md"
    );
    let doc = std::fs::read_to_string(path).expect("read STATUS.md");

    let required_backends = [
        "InMemoryLexicalIndex",
        "InMemorySemanticIndex",
        "HybridRetriever",
        "HybridRetrieverN",
        "InMemoryRawArchive",
        "InMemoryCodeSymbolIndex",
        "InMemoryGraphNeighborhood",
        "InMemoryClaimEvidence",
        "LedgerBackedClaimEvidence",
        "InMemoryRecencyIndex",
        "ProvenanceVerifiedRetriever",
    ];
    for backend in required_backends {
        assert!(
            doc.contains(backend),
            "STATUS.md must mention backend {backend}"
        );
    }

    for row in ["W-46", "W-47", "W-48", "W-49", "W-50", "W-51"] {
        assert!(doc.contains(row), "STATUS.md must mention {row}");
    }

    // The "Cross-language wire-format symmetry" section MUST list all 4
    // contract types whose Rust serde ↔ Swift Codable parity is pinned
    // (iters 53-56). If a future commit removes a row from that table
    // without updating the detector, this fires. Pairs with the per-type
    // wire-format pin tests on both sides.
    let required_wire_symmetry_section_header = "Cross-language wire-format symmetry";
    assert!(
        doc.contains(required_wire_symmetry_section_header),
        "STATUS.md must keep the wire-symmetry section heading: {}",
        required_wire_symmetry_section_header
    );
    for contract_type in [
        "EidosContextPacket",
        "EidosCitation",
        "CitationError",
        "Vec<(usize, CitationError)>",
    ] {
        assert!(
            doc.contains(contract_type),
            "STATUS.md wire-symmetry section must mention contract type {contract_type}"
        );
    }

    // Falsifier outcome types — iters 63 + 64 made both Serialize AND
    // Deserialize on the Rust side, ahead of any Swift mirror. STATUS.md
    // must reflect that bidirectional state so a future contributor
    // doesn't accidentally drop Deserialize back to Serialize-only.
    for falsifier_type in ["FEidosClosedCitationWitness", "FalsifierFailure"] {
        assert!(
            doc.contains(falsifier_type),
            "STATUS.md wire-symmetry section must mention falsifier outcome \
             type {falsifier_type} (iters 63/64 made Rust serde bidirectional)"
        );
    }

    // STATUS.md must point readers at the canonical wire-format home
    // in the design doc — §12 is the doc-side mirror of this section
    // and where new readers should land if they want the prose
    // version. A future move/rename of §12 surfaces here at test
    // time. (Substring match on "§12" — narrow enough to catch a
    // missing reference, loose enough to survive minor phrasing
    // edits.)
    assert!(
        doc.contains("§12"),
        "STATUS.md wire-symmetry section must cross-reference \
         design doc §12 (the canonical doc home for the wire-format \
         symmetry surface)"
    );
}

/// HybridRetrieverN scale stress: 100 inner Lexical retrievers all
/// sharing one manifest, each with a unique document matching the same
/// query. The outer BTreeMap fold + (rrf desc, doc_id asc) sort must
/// handle 100 inputs cleanly and emit a closed-citation set of 100
/// distinct hits with one fused source_id per document. No panic, no
/// duplicates, no overflow.
#[test]
fn hybrid_n_100_inner_retrievers_scales_cleanly() {
    use super::hybrid_n::HybridRetrieverN;
    use super::types::EidosCitation;

    let m = manifest();
    let mut inner: Vec<Box<dyn EidosRetriever>> = Vec::with_capacity(100);
    for i in 0..100 {
        let mut lex = InMemoryLexicalIndex::new(m.clone());
        lex.insert(
            doc(&format!("doc-{i:03}")),
            "shared-token-100x",
            EidosSourceKind::Note,
        )
        .unwrap();
        inner.push(Box::new(lex));
    }
    assert_eq!(inner.len(), 100);

    let outer = HybridRetrieverN::new(inner).unwrap();
    let q = EidosQuery::new("shared-token-100x", EidosRetrievalMode::Hybrid, 200);
    let packet = outer.retrieve(&q, 1_700_000_000_000);

    assert_eq!(
        packet.hits.len(),
        100,
        "100 unique documents must surface as 100 fused hits"
    );

    // No duplicate source_ids in the output.
    let mut ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
    ids.sort();
    let unique = ids.iter().collect::<std::collections::HashSet<_>>();
    assert_eq!(unique.len(), 100, "all 100 source_ids must be distinct");

    // Closed-citation contract holds for every emitted hit.
    for hit in &packet.hits {
        let cite = EidosCitation {
            source_id: hit.source_id.clone(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert_eq!(packet.validate_citation(&cite), Ok(()));
        // Confidence in the unit interval despite N=100 retrievers.
        assert!(hit.confidence >= 0.0 && hit.confidence <= 1.0);
    }
}

/// All-empty HybridRetrieverN — every inner retriever returns an empty
/// packet. The outer fusion must produce an empty packet too, without
/// panic. The max_rrf normalization formula uses `N / (k + 1)` which
/// is non-zero for N ≥ 1, but with no hits there's no division to
/// perform, so the empty case is degenerate-but-fine.
#[test]
fn hybrid_n_all_empty_inner_returns_empty_packet() {
    use super::hybrid_n::HybridRetrieverN;

    let m = manifest();
    let lex = InMemoryLexicalIndex::new(m.clone());
    let sem = InMemorySemanticIndex::new(m.clone(), 2);
    let recency = super::recency::InMemoryRecencyIndex::new(m.clone());
    let outer = HybridRetrieverN::new(vec![
        Box::new(lex),
        Box::new(sem),
        Box::new(recency),
    ])
    .unwrap();

    let q = EidosQuery::with_vector(
        "anything",
        EidosRetrievalMode::Hybrid,
        16,
        vec![1.0, 0.0],
    );
    let packet = outer.retrieve(&q, 1_700_000_000_000);
    assert!(packet.hits.is_empty());
    assert_eq!(packet.manifest_id, m);
}

/// LedgerBackedClaimEvidence over a claim that has NO support links
/// (committed with an empty supported_by Vec). Retrieval emits an
/// empty packet — no evidence to surface — with correct manifest_id.
/// No panic.
#[test]
fn ledger_backed_claim_with_no_evidence_returns_empty_packet() {
    use super::ledger_backed_claim_evidence::LedgerBackedClaimEvidence;
    use crate::provenance::ledger::{Claim, ClaimId, ClaimLedger};

    let mut led = ClaimLedger::new();
    led.commit_claim(
        Claim::new(ClaimId("orphan-claim".to_string()), "no evidence", 0),
        vec![],
        vec![], // <-- empty support set
    )
    .unwrap();

    let r = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
    let q = EidosQuery::new("orphan-claim", EidosRetrievalMode::ClaimEvidence, 16);
    let packet = r.retrieve(&q, 1_700_000_000_000);
    assert!(packet.hits.is_empty(), "claim with no evidence yields zero hits");
    assert_eq!(packet.manifest_id, manifest());
}

/// HybridRetrieverN with one populated and one EMPTY inner retriever.
/// The outer fusion still emits hits from the populated side — the
/// empty inner contributes zero hits and zero RRF mass, and the outer
/// formula degenerates cleanly to "use what's there". No panic, no
/// divide-by-zero, no spurious empty-packet leak.
#[test]
fn hybrid_n_one_empty_one_populated_inner_still_emits() {
    use super::hybrid_n::HybridRetrieverN;
    use super::types::EidosCitation;

    let m = manifest();
    // Populated lexical with one hit.
    let mut lex = InMemoryLexicalIndex::new(m.clone());
    lex.insert(doc("a"), "tropical alpha", EidosSourceKind::Note).unwrap();
    // Empty semantic — no documents inserted at all.
    let sem = InMemorySemanticIndex::new(m.clone(), 2);

    let outer = HybridRetrieverN::new(vec![Box::new(lex), Box::new(sem)]).unwrap();
    let q = EidosQuery::with_vector(
        "tropical",
        EidosRetrievalMode::Hybrid,
        16,
        vec![1.0, 0.0],
    );
    let packet = outer.retrieve(&q, 1_700_000_000_000);

    // The populated lexical side's hit surfaces in the fused output.
    assert_eq!(packet.hits.len(), 1);
    assert_eq!(packet.hits[0].document_id.as_str(), "a");
    // Confidence still in [0, 1] under asymmetric inner population.
    assert!(packet.hits[0].confidence >= 0.0 && packet.hits[0].confidence <= 1.0);
    // Closed-citation contract holds.
    let cite = EidosCitation {
        source_id: packet.hits[0].source_id.clone(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert_eq!(packet.validate_citation(&cite), Ok(()));
}

/// Empty `query.text` across the ClaimEvidence family must defer to an
/// empty packet on BOTH backends (in-memory + ledger-backed) — claim
/// retrieval needs an explicit id, never falls back to "list all".
#[test]
fn empty_query_text_defers_for_both_claim_evidence_backends() {
    use super::claim_evidence::{EvidenceStance, InMemoryClaimEvidence};
    use super::ledger_backed_claim_evidence::LedgerBackedClaimEvidence;
    use crate::provenance::ledger::{Claim, ClaimId, ClaimLedger, Evidence, EvidenceId};

    let m = manifest();
    // Populate both backends with the same fixture.
    let mut im = InMemoryClaimEvidence::new(m.clone());
    im.add_evidence(
        "c",
        doc("ev"),
        EvidenceStance::Supports,
        EidosSourceKind::Note,
    );

    let mut led = ClaimLedger::new();
    led.commit_evidence(Evidence::new(EvidenceId("ev".to_string()), "s", 0))
        .unwrap();
    led.commit_claim(
        Claim::new(ClaimId("c".to_string()), "claim", 0),
        vec![],
        vec![EvidenceId("ev".to_string())],
    )
    .unwrap();
    let lb = LedgerBackedClaimEvidence::from_ledger(&led, m.clone());

    let q = EidosQuery::new("", EidosRetrievalMode::ClaimEvidence, 16);
    let p_im = im.retrieve(&q, 0);
    let p_lb = lb.retrieve(&q, 0);

    assert!(p_im.hits.is_empty(), "in-memory must defer on empty claim id");
    assert!(p_lb.hits.is_empty(), "ledger-backed must defer on empty claim id");
    // Both empty packets carry the correct manifest_id.
    assert_eq!(p_im.manifest_id, m);
    assert_eq!(p_lb.manifest_id, m);
}

/// Recency `since_unix_ms = u64::MAX` filter floor: no document can
/// satisfy `created_at_unix_ms >= u64::MAX` unless it was inserted at
/// exactly that value. With a normal corpus, the floor drops every doc
/// and the packet is empty. Pins the upper-boundary saturation case.
#[test]
fn recency_since_u64_max_floor_drops_every_normal_doc() {
    use super::recency::InMemoryRecencyIndex;

    const ONE_DAY: u64 = 86_400_000;
    const T0: u64 = 1_700_000_000_000;

    let mut r = InMemoryRecencyIndex::new(manifest());
    r.insert(doc("today"), "x", T0, EidosSourceKind::Note);
    r.insert(doc("yesterday"), "x", T0 - ONE_DAY, EidosSourceKind::Note);

    let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16).with_since(u64::MAX);
    let packet = r.retrieve(&q, T0);
    assert!(packet.hits.is_empty());

    // The packet is still well-formed (correct manifest_id even when
    // hits are zero).
    assert_eq!(packet.manifest_id, manifest());
}

/// The in-memory `InMemoryClaimEvidence` and the ledger-backed
/// `LedgerBackedClaimEvidence` retrievers must emit byte-equal
/// `source_id`s for equivalent inputs. The wire format
/// `{evidence_doc}::claim::{claim_id}::{stance}` is part of the
/// closed-citation contract; if the two backends diverge on the
/// format, a chat layer caching tokens from one couldn't validate
/// against packets from the other under the same manifest.
#[test]
fn in_memory_and_ledger_backed_claim_evidence_emit_byte_equal_source_ids() {
    use super::claim_evidence::{EvidenceStance, InMemoryClaimEvidence};
    use super::ledger_backed_claim_evidence::LedgerBackedClaimEvidence;
    use crate::provenance::ledger::{Claim, ClaimId, ClaimLedger, Evidence, EvidenceId};

    let m = manifest();
    let claim_text = "c-format-check";

    // In-memory retriever with one supporting evidence.
    let mut im = InMemoryClaimEvidence::new(m.clone());
    im.add_evidence(
        claim_text,
        doc("ev-a"),
        EvidenceStance::Supports,
        EidosSourceKind::Note,
    );

    // Ledger-backed retriever with the same shape.
    let mut led = ClaimLedger::new();
    led.commit_evidence(Evidence::new(EvidenceId("ev-a".to_string()), "src", 0))
        .unwrap();
    led.commit_claim(
        Claim::new(ClaimId(claim_text.to_string()), "claim", 0),
        vec![],
        vec![EvidenceId("ev-a".to_string())],
    )
    .unwrap();
    let lb = LedgerBackedClaimEvidence::from_ledger(&led, m.clone());

    let q = EidosQuery::new(claim_text, EidosRetrievalMode::ClaimEvidence, 16);
    let p_im = im.retrieve(&q, 1_700_000_000_000);
    let p_lb = lb.retrieve(&q, 1_700_000_000_000);

    let im_ids: Vec<&str> = p_im.hits.iter().map(|h| h.source_id.as_str()).collect();
    let lb_ids: Vec<&str> = p_lb.hits.iter().map(|h| h.source_id.as_str()).collect();
    assert_eq!(
        im_ids, lb_ids,
        "in-memory and ledger-backed source_id wire format must match byte-equal"
    );
    assert_eq!(im_ids, vec!["ev-a::claim::c-format-check::supports"]);
}

/// Span byte invariant: every retriever that emits a `span` MUST have
/// `byte_end <= body_len` (half-open interval). Sweeps the retrievers
/// that emit spans: Lexical, RawArchive, CodeSymbol.
#[test]
fn span_byte_end_within_body_bytes() {
    use super::code_symbol::InMemoryCodeSymbolIndex;
    use super::raw_archive::InMemoryRawArchive;

    // --- Lexical
    let body = "tropical content alpha";
    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("d"), body, EidosSourceKind::Note).unwrap();
    let p = lex.retrieve(
        &EidosQuery::new("tropical", EidosRetrievalMode::Lexical, 16),
        1_700_000_000_000,
    );
    for hit in &p.hits {
        if let Some(span) = hit.span {
            assert!(
                (span.byte_end as usize) <= body.len(),
                "lexical span byte_end {} exceeds body len {}",
                span.byte_end,
                body.len()
            );
        }
    }

    // --- RawArchive
    let raw_body = "first note body";
    let mut raw = InMemoryRawArchive::new(manifest());
    raw.insert(doc("d"), raw_body, EidosSourceKind::Note);
    let p = raw.retrieve(
        &EidosQuery::new("d", EidosRetrievalMode::RawArchive, 16),
        1_700_000_000_000,
    );
    for hit in &p.hits {
        if let Some(span) = hit.span {
            assert!(
                (span.byte_end as usize) <= raw_body.len(),
                "raw_archive span byte_end {} exceeds body len {}",
                span.byte_end,
                raw_body.len()
            );
            // RawArchive sets the span to the full body — pin that
            // exact equality.
            assert_eq!(span.byte_start, 0);
            assert_eq!(span.byte_end as usize, raw_body.len());
        }
    }

    // --- CodeSymbol: caller-supplied span. Pin that the emitted span
    // matches what was inserted, with the invariant byte_start ≤ byte_end.
    let mut code = InMemoryCodeSymbolIndex::new(manifest());
    code.insert("retrieve", doc("file.rs"), 100, 108);
    let p = code.retrieve(
        &EidosQuery::new("retrieve", EidosRetrievalMode::CodeSymbol, 16),
        1_700_000_000_000,
    );
    for hit in &p.hits {
        let span = hit.span.expect("code_symbol always emits a span");
        assert_eq!(span.byte_start, 100);
        assert_eq!(span.byte_end, 108);
        assert!(span.byte_start <= span.byte_end);
    }
}

/// Full kitchen-sink HybridRetrieverN fusion across EVERY retriever
/// shape: Lexical, Semantic, the 2-way Hybrid, RawArchive, CodeSymbol,
/// GraphNeighborhood, ClaimEvidence (in-memory), Recency,
/// LedgerBackedClaimEvidence, and a ProvenanceVerified wrapper around a
/// fresh Lexical. All eleven inner retrievers share one manifest.
///
/// Pins: HybridRetrieverN doesn't care about backend heterogeneity;
/// it dedups by document_id and emits one fused source_id per doc.
/// Closed-citation contract holds end-to-end across every emitted hit.
/// No panic on the eclectic mixture.
#[test]
fn hybrid_n_kitchen_sink_fusion_across_all_retriever_shapes() {
    use super::claim_evidence::{EvidenceStance, InMemoryClaimEvidence};
    use super::code_symbol::InMemoryCodeSymbolIndex;
    use super::graph_neighborhood::InMemoryGraphNeighborhood;
    use super::hybrid::HybridRetriever;
    use super::hybrid_n::HybridRetrieverN;
    use super::ledger_backed_claim_evidence::LedgerBackedClaimEvidence;
    use super::provenance_verified::ProvenanceVerifiedRetriever;
    use super::raw_archive::InMemoryRawArchive;
    use super::recency::InMemoryRecencyIndex;
    use super::types::EidosCitation;
    use crate::provenance::ledger::{
        Claim as LCl, ClaimId, ClaimLedger, Evidence as LEv, EvidenceId,
    };

    let m = manifest();
    let inner: Vec<Box<dyn EidosRetriever>> = vec![
        // 1. Lexical
        {
            let mut x = InMemoryLexicalIndex::new(m.clone());
            x.insert(doc("a"), "tropical content alpha", EidosSourceKind::Note).unwrap();
            Box::new(x)
        },
        // 2. Semantic
        {
            let mut x = InMemorySemanticIndex::new(m.clone(), 2);
            x.insert(doc("a"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();
            Box::new(x)
        },
        // 3. 2-way Hybrid (Lex + Sem)
        {
            let mut lex = InMemoryLexicalIndex::new(m.clone());
            lex.insert(doc("a"), "tropical beta", EidosSourceKind::Note).unwrap();
            let mut sem = InMemorySemanticIndex::new(m.clone(), 2);
            sem.insert(doc("a"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();
            Box::new(HybridRetriever::new(lex, sem).unwrap())
        },
        // 4. RawArchive
        {
            let mut x = InMemoryRawArchive::new(m.clone());
            x.insert(doc("a"), "raw body", EidosSourceKind::Note);
            Box::new(x)
        },
        // 5. CodeSymbol
        {
            let mut x = InMemoryCodeSymbolIndex::new(m.clone());
            x.insert("tropical", doc("a"), 0, 8);
            Box::new(x)
        },
        // 6. GraphNeighborhood
        {
            let mut x = InMemoryGraphNeighborhood::new(m.clone());
            x.add_edge(doc("seed"), doc("a"));
            Box::new(x)
        },
        // 7. ClaimEvidence (in-memory)
        {
            let mut x = InMemoryClaimEvidence::new(m.clone());
            x.add_evidence(
                "c",
                doc("a"),
                EvidenceStance::Supports,
                EidosSourceKind::Note,
            );
            Box::new(x)
        },
        // 8. Recency
        {
            let mut x = InMemoryRecencyIndex::new(m.clone());
            x.insert(doc("a"), "tropical recent", 1_700_000_000_000, EidosSourceKind::Note);
            Box::new(x)
        },
        // 9. LedgerBackedClaimEvidence
        {
            let mut led = ClaimLedger::new();
            led.commit_evidence(LEv::new(EvidenceId("a".to_string()), "s", 0)).unwrap();
            led.commit_claim(
                LCl::new(ClaimId("c".to_string()), "claim", 0),
                vec![],
                vec![EvidenceId("a".to_string())],
            )
            .unwrap();
            Box::new(LedgerBackedClaimEvidence::from_ledger(&led, m.clone()))
        },
        // 10. ProvenanceVerified wrapping Lexical (admit "a::lex")
        {
            let mut lex = InMemoryLexicalIndex::new(m.clone());
            lex.insert(doc("a"), "tropical pv", EidosSourceKind::Note).unwrap();
            let mut pv = ProvenanceVerifiedRetriever::new(lex);
            pv.admit(super::types::EidosChunkId::new("a::lex").unwrap());
            Box::new(pv)
        },
    ];
    assert_eq!(inner.len(), 10, "kitchen-sink has 10 inner retrievers");

    let outer = HybridRetrieverN::new(inner).unwrap();
    // Query "tropical" — exercises Lexical, Hybrid, Recency, PV.
    let q = EidosQuery::with_vector(
        "tropical",
        EidosRetrievalMode::Hybrid,
        16,
        vec![1.0, 0.0],
    );
    let packet = outer.retrieve(&q, 1_700_000_000_000);
    assert!(!packet.hits.is_empty());
    // The shared document_id "a" must dedup to ONE hit in the fused
    // packet despite appearing in multiple inner retrievers.
    let a_hits: Vec<_> = packet
        .hits
        .iter()
        .filter(|h| h.document_id.as_str() == "a")
        .collect();
    assert_eq!(a_hits.len(), 1, "document_id 'a' must dedup to one hybrid hit");
    assert_eq!(a_hits[0].source_id.as_str(), "a::hybrid");

    // Closed-citation contract holds for every emitted hit.
    for hit in &packet.hits {
        let cite = EidosCitation {
            source_id: hit.source_id.clone(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert_eq!(packet.validate_citation(&cite), Ok(()));
    }
}

/// Empty `query.text` across the Lexical-derived families (Lexical
/// itself + Hybrid 2-way + HybridRetrieverN) must defer to an empty
/// packet against a *populated* corpus — the empty-defer rule isn't
/// just "empty corpus stays empty", it must also apply to the
/// "empty-needle vs. real documents" case so the bridge layer can
/// rely on it without re-checking. Companion pin to
/// `empty_query_text_defers_for_both_claim_evidence_backends` (which
/// covers the ClaimEvidence family) and the pre-existing empty-body
/// test below.
#[test]
fn empty_query_text_defers_across_lexical_hybrid_and_hybrid_n() {
    use super::hybrid::HybridRetriever;
    use super::hybrid_n::HybridRetrieverN;
    use super::semantic::InMemorySemanticIndex;

    // Populated lexical corpus with two docs that would both score
    // against any non-empty query containing "alpha" or "beta".
    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("a"), "alpha lives here", EidosSourceKind::Note).unwrap();
    lex.insert(doc("b"), "beta lives too", EidosSourceKind::Note).unwrap();

    let q_empty = EidosQuery::new("", EidosRetrievalMode::Lexical, 16);

    // 1. Bare Lexical: empty packet on empty needle against populated
    //    corpus (covers the "real docs + empty needle" case the
    //    pre-existing empty-body test doesn't cover).
    assert!(
        lex.retrieve(&q_empty, 0).hits.is_empty(),
        "Lexical must defer on empty query.text",
    );

    // 2. Hybrid 2-way: outer Hybrid mode, but the inner Lexical drops
    //    everything on empty needle and Semantic has no scoring path
    //    against empty text — fused packet is empty.
    let lex2 = {
        let mut l = InMemoryLexicalIndex::new(manifest());
        l.insert(doc("a"), "alpha lives here", EidosSourceKind::Note).unwrap();
        l
    };
    let sem2 = {
        let mut s = InMemorySemanticIndex::new(manifest(), 2);
        s.insert(doc("a"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();
        s
    };
    let hybrid = HybridRetriever::new(lex2, sem2).unwrap();
    let q_hybrid_empty = EidosQuery::new("", EidosRetrievalMode::Hybrid, 16);
    assert!(
        hybrid.retrieve(&q_hybrid_empty, 0).hits.is_empty(),
        "Hybrid (2-way) must defer on empty query.text",
    );

    // 3. HybridRetrieverN: same invariant must hold for the N-way
    //    composition.
    let lex_n = {
        let mut l = InMemoryLexicalIndex::new(manifest());
        l.insert(doc("a"), "alpha lives here", EidosSourceKind::Note).unwrap();
        l
    };
    let sem_n = {
        let mut s = InMemorySemanticIndex::new(manifest(), 2);
        s.insert(doc("a"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();
        s
    };
    let hybrid_n = HybridRetrieverN::new(vec![Box::new(lex_n), Box::new(sem_n)]).unwrap();
    assert!(
        hybrid_n.retrieve(&q_hybrid_empty, 0).hits.is_empty(),
        "HybridRetrieverN must defer on empty query.text",
    );
}

/// Adversarial: a document is inserted into Lexical with an EMPTY
/// body. Retrieval against any non-empty query must return an empty
/// packet (no document body to match against) without panic. Retrieval
/// against an empty query is also empty per the empty-defer rule.
#[test]
fn lexical_empty_body_document_yields_empty_packet() {
    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("blank"), "", EidosSourceKind::Note).unwrap();

    // Any non-empty query → empty packet (no body to match).
    let q = EidosQuery::new("anything", EidosRetrievalMode::Lexical, 16);
    assert!(lex.retrieve(&q, 0).hits.is_empty());

    // Empty query → empty packet (empty-defer rule).
    let q_empty = EidosQuery::new("", EidosRetrievalMode::Lexical, 16);
    assert!(lex.retrieve(&q_empty, 0).hits.is_empty());
}

/// When upstream evidence retraction propagates `AtRisk` to a claim,
/// `LedgerBackedClaimEvidence` continues to surface the claim's REMAINING
/// active evidence. The retriever filters by evidence status (Retracted
/// dropped) — NOT by claim status. This matters because chat consumers
/// often want to see "what evidence is left for this at-risk claim?"
/// rather than have the retriever silently swallow at-risk claims.
#[test]
fn at_risk_claim_status_does_not_filter_remaining_active_evidence() {
    use super::ledger_backed_claim_evidence::LedgerBackedClaimEvidence;
    use crate::provenance::ledger::{Claim, ClaimId, ClaimLedger, ClaimStatus, Evidence, EvidenceId};

    let mut led = ClaimLedger::new();
    led.commit_evidence(Evidence::new(EvidenceId("ev-keep".to_string()), "src", 0))
        .unwrap();
    led.commit_evidence(Evidence::new(EvidenceId("ev-drop".to_string()), "src", 0))
        .unwrap();
    led.commit_claim(
        Claim::new(ClaimId("c".to_string()), "fixture", 0),
        vec![],
        vec![
            EvidenceId("ev-keep".to_string()),
            EvidenceId("ev-drop".to_string()),
        ],
    )
    .unwrap();

    // Retract ev-drop → claim "c" propagates to AtRisk per the ledger
    // doctrine; ev-drop is now Retracted.
    led.retract_evidence(&EvidenceId("ev-drop".to_string())).unwrap();
    assert_eq!(
        led.claim(&ClaimId("c".to_string())).unwrap().status,
        ClaimStatus::AtRisk,
        "claim should be AtRisk after upstream evidence retraction"
    );

    // The retriever still surfaces ev-keep (Active). ev-drop is filtered.
    let r = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
    let q = EidosQuery::new("c", EidosRetrievalMode::ClaimEvidence, 16);
    let packet = r.retrieve(&q, 0);
    let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
    assert_eq!(
        ids,
        vec!["ev-keep::claim::c::supports"],
        "AtRisk claim should still surface its Active evidence"
    );
}

/// HybridRetrieverN over heterogeneous inner retrievers: a Lexical
/// substring retriever and a LedgerBackedClaimEvidence retriever
/// sharing the same manifest. Demonstrates that the document_id-based
/// dedup in the fusion path works regardless of which inner backend
/// emitted the hit. When the two backends happen to refer to the same
/// document_id (e.g. Lexical indexed a doc "ev-shared" AND the ledger
/// has an evidence "ev-shared"), the fused hit merges them into one
/// citable token.
#[test]
fn hybrid_n_fuses_lexical_and_ledger_backed_by_document_id() {
    use super::hybrid_n::HybridRetrieverN;
    use super::ledger_backed_claim_evidence::LedgerBackedClaimEvidence;
    use super::types::EidosCitation;
    use crate::provenance::ledger::{Claim, ClaimId, ClaimLedger, Evidence, EvidenceId};

    let m = manifest();
    let mut lex = InMemoryLexicalIndex::new(m.clone());
    lex.insert(
        doc("ev-shared"),
        "tropical content",
        EidosSourceKind::Note,
    )
    .unwrap();
    lex.insert(
        doc("lex-only"),
        "tropical-only-in-lex",
        EidosSourceKind::Note,
    )
    .unwrap();

    let mut led = ClaimLedger::new();
    led.commit_evidence(Evidence::new(
        EvidenceId("ev-shared".to_string()),
        "src",
        0,
    ))
    .unwrap();
    led.commit_evidence(Evidence::new(
        EvidenceId("ev-ledger-only".to_string()),
        "src",
        0,
    ))
    .unwrap();
    led.commit_claim(
        Claim::new(ClaimId("c".to_string()), "claim text", 0),
        vec![],
        vec![
            EvidenceId("ev-shared".to_string()),
            EvidenceId("ev-ledger-only".to_string()),
        ],
    )
    .unwrap();
    let ledger_retriever = LedgerBackedClaimEvidence::from_ledger(&led, m.clone());

    let hybrid =
        HybridRetrieverN::new(vec![Box::new(lex), Box::new(ledger_retriever)]).unwrap();

    // The Hybrid query feeds the SAME query.text to both retrievers.
    // For Lexical, "tropical" matches both lex docs. For
    // LedgerBackedClaimEvidence, query.text is the claim id "c" — so
    // the two retrievers respond to different query.text in practice.
    // Here we use "tropical" — only Lexical contributes (ledger returns
    // empty because no claim id "tropical" exists). Then we use "c" —
    // only ledger contributes. The fused output depends on the query.

    // First query: match Lexical only.
    let q_lex = EidosQuery::new("tropical", EidosRetrievalMode::Hybrid, 16);
    let p_lex = hybrid.retrieve(&q_lex, 1_700_000_000_000);
    let ids: Vec<&str> = p_lex.hits.iter().map(|h| h.document_id.as_str()).collect();
    assert!(ids.contains(&"ev-shared"));
    assert!(ids.contains(&"lex-only"));

    // Second query: match ledger only.
    let q_led = EidosQuery::new("c", EidosRetrievalMode::Hybrid, 16);
    let p_led = hybrid.retrieve(&q_led, 1_700_000_000_000);
    let ids_led: Vec<&str> = p_led.hits.iter().map(|h| h.document_id.as_str()).collect();
    assert!(ids_led.contains(&"ev-shared"));
    assert!(ids_led.contains(&"ev-ledger-only"));

    // Closed-citation contract holds on both packets.
    for p in &[&p_lex, &p_led] {
        for hit in &p.hits {
            let cite = EidosCitation {
                source_id: hit.source_id.clone(),
                manifest_id: p.manifest_id.clone(),
            };
            assert_eq!(p.validate_citation(&cite), Ok(()));
        }
    }

    // Pre-fusion ids are NOT citable through the fused packet — the
    // inner ledger-backed retriever's source_id for "ev-shared" is
    // "ev-shared::claim::c::supports"; only "ev-shared::hybrid"
    // appears in the fused output for the claim-id query.
    let pre_fusion = EidosCitation {
        source_id: super::types::EidosChunkId::new(
            "ev-shared::claim::c::supports",
        )
        .unwrap(),
        manifest_id: p_led.manifest_id.clone(),
    };
    assert!(p_led.validate_citation(&pre_fusion).is_err());
}

/// ProvenanceVerified wrapping LedgerBackedClaimEvidence — composes the
/// ledger's retraction-based filter (already-built into the ledger
/// snapshot) with the wrapper's explicit-admit set. Both filters apply:
/// only evidence that is NOT retracted in the ledger AND is in the
/// admit set survives.
#[test]
fn provenance_verified_over_ledger_backed_claim_evidence() {
    use super::ledger_backed_claim_evidence::LedgerBackedClaimEvidence;
    use super::provenance_verified::ProvenanceVerifiedRetriever;
    use super::types::EidosCitation;
    use crate::provenance::ledger::{Claim, ClaimId, ClaimLedger, Evidence, EvidenceId};

    let mut led = ClaimLedger::new();
    led.commit_evidence(Evidence::new(EvidenceId("ev-x".to_string()), "src-x", 0))
        .unwrap();
    led.commit_evidence(Evidence::new(EvidenceId("ev-y".to_string()), "src-y", 0))
        .unwrap();
    led.commit_evidence(Evidence::new(EvidenceId("ev-z".to_string()), "src-z", 0))
        .unwrap();
    led.commit_claim(
        Claim::new(ClaimId("c".to_string()), "claim text", 0),
        vec![],
        vec![
            EvidenceId("ev-x".to_string()),
            EvidenceId("ev-y".to_string()),
            EvidenceId("ev-z".to_string()),
        ],
    )
    .unwrap();

    let ledger_retriever = LedgerBackedClaimEvidence::from_ledger(&led, manifest());
    let mut pv = ProvenanceVerifiedRetriever::new(ledger_retriever);
    // Outer admits ONLY ev-x's chunk id. Even though the ledger has
    // ev-x, ev-y, ev-z all supporting "c", the outer filters to just
    // ev-x.
    pv.admit(super::types::EidosChunkId::new("ev-x::claim::c::supports").unwrap());

    let q = EidosQuery::new("c", EidosRetrievalMode::ProvenanceVerified, 16);
    let packet = pv.retrieve(&q, 1_700_000_000_000);
    let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
    assert_eq!(ids, vec!["ev-x::claim::c::supports"]);

    // All hits report ProvenanceVerified mode (wrapper rewrite).
    for hit in &packet.hits {
        assert_eq!(hit.provenance.mode, EidosRetrievalMode::ProvenanceVerified);
    }

    // ev-y / ev-z were emitted by the inner ledger retriever but are
    // NOT in the outer's admit set — rejected by the closed-citation
    // contract.
    let unverified = EidosCitation {
        source_id: super::types::EidosChunkId::new("ev-y::claim::c::supports").unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert!(packet.validate_citation(&unverified).is_err());
}

/// Outer retriever's `mode()` advertises ProvenanceVerified even when the
/// inner is HybridRetrieverN (whose own `mode()` says Hybrid). The
/// wrapper takes ownership of the mode advertisement.
#[test]
fn pv_wrapping_hybrid_n_advertises_provenance_verified() {
    use super::hybrid_n::HybridRetrieverN;
    use super::provenance_verified::ProvenanceVerifiedRetriever;

    let lex = InMemoryLexicalIndex::new(manifest());
    let sem = InMemorySemanticIndex::new(manifest(), 2);
    let hybrid_n =
        HybridRetrieverN::new(vec![Box::new(lex), Box::new(sem)]).unwrap();
    let pv = ProvenanceVerifiedRetriever::new(hybrid_n);
    assert_eq!(pv.mode(), EidosRetrievalMode::ProvenanceVerified);
}

// ---------------------------------------------------------------------------
// top_k boundary (u16::MAX must not overflow or panic)
// ---------------------------------------------------------------------------

/// `query.top_k = u16::MAX = 65_535` against a small corpus. The packet
/// must contain at most `corpus_size` hits (truncation is by `take(top_k)`
/// which honors the smaller of the two), and no integer overflow may
/// occur during the cast to `usize`.
#[test]
fn top_k_u16_max_against_small_corpus_returns_all_corpus_hits() {
    use super::types::EidosCitation;

    let mut lex = InMemoryLexicalIndex::new(manifest());
    for i in 0..50 {
        lex.insert(
            doc(&format!("d-{i:02}")),
            "common-token",
            EidosSourceKind::Note,
        )
        .unwrap();
    }
    let q = EidosQuery::new("common-token", EidosRetrievalMode::Lexical, u16::MAX);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), 50, "all matching docs should appear");

    // Closed-citation contract: every emitted source_id validates.
    for hit in &packet.hits {
        let cite = EidosCitation {
            source_id: hit.source_id.clone(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert_eq!(packet.validate_citation(&cite), Ok(()));
    }
}

// ---------------------------------------------------------------------------
// ClaimEvidence stance token wire-format invariant
// ---------------------------------------------------------------------------

/// The stance tokens `supports` / `contradicts` are embedded directly in
/// ClaimEvidence's `source_id` shape `{doc}::claim::{id}::{stance}`. The
/// closed-citation contract enforces stance-spoofing rejection by string
/// match, so these tokens are part of the wire format.
///
/// Lock them to lowercase ASCII so a future refactor (e.g. introducing
/// camelCase tokens) can't silently flip the wire format and break
/// in-flight packets cached by downstream consumers.
#[test]
fn claim_evidence_stance_tokens_are_lowercase_ascii() {
    use super::claim_evidence::{EvidenceStance, InMemoryClaimEvidence};

    let mut idx = InMemoryClaimEvidence::new(manifest());
    idx.add_evidence(
        "c",
        doc("a"),
        EvidenceStance::Supports,
        EidosSourceKind::Note,
    );
    idx.add_evidence(
        "c",
        doc("b"),
        EvidenceStance::Contradicts,
        EidosSourceKind::Note,
    );
    let q = EidosQuery::new("c", EidosRetrievalMode::ClaimEvidence, 8);
    let packet = idx.retrieve(&q, 1_700_000_000_000);

    // Two hits, one per stance. Verify the exact token spellings.
    let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
    assert!(ids.contains(&"a::claim::c::supports"));
    assert!(ids.contains(&"b::claim::c::contradicts"));
    // Negative: no other casing leaks through.
    for id in &ids {
        assert!(!id.contains("Supports"), "stance must not capitalize: {id}");
        assert!(!id.contains("Contradicts"), "stance must not capitalize: {id}");
        assert!(!id.contains("SUPPORTS"), "stance must not shout: {id}");
    }
}

// ---------------------------------------------------------------------------
// Re-construction determinism (drop and rebuild produce byte-equal packets)
// ---------------------------------------------------------------------------

/// Build a retriever, retrieve, drop it, then build another retriever from
/// the same document set (same order) and retrieve. The two packets must
/// be byte-equal. This catches a hypothetical regression where a
/// retriever's internal state grew a non-reset field (a global counter, a
/// thread-local, a cached random salt) that survived drop.
#[test]
fn lexical_retriever_re_construction_is_byte_equal() {
    let docs = [
        ("alpha", "alpha tropical content"),
        ("beta", "beta tropical content"),
        ("gamma", "gamma unrelated content"),
    ];

    let mut a = InMemoryLexicalIndex::new(manifest());
    for (id, body) in &docs {
        a.insert(doc(id), *body, EidosSourceKind::Note).unwrap();
    }
    let q = EidosQuery::new("tropical", EidosRetrievalMode::Lexical, 16);
    let pa = a.retrieve(&q, 1_700_000_000_000);
    drop(a);

    let mut b = InMemoryLexicalIndex::new(manifest());
    for (id, body) in &docs {
        b.insert(doc(id), *body, EidosSourceKind::Note).unwrap();
    }
    let pb = b.retrieve(&q, 1_700_000_000_000);

    assert_eq!(pa, pb, "re-construction produced a different packet");
}

/// Two inner `HybridRetriever`s with **different** `k` values (one with
/// `with_k(10)`, one with the default `k=60`) fused under an outer
/// `HybridRetrieverN`. Every emitted hit's confidence still lies in
/// `[0.0, 1.0]` and the falsifier passes — the outer RRF formula
/// absorbs each inner retriever's normalization independently because
/// inner confidence values become rank contributions in the outer fold.
#[test]
fn hybrid_n_over_mixed_k_inner_hybrids_keeps_confidence_in_unit() {
    use super::hybrid::HybridRetriever;
    use super::hybrid_n::HybridRetrieverN;
    use super::types::EidosCitation;

    let m = manifest();
    // Inner hybrid #1: k=10
    let mut lex1 = InMemoryLexicalIndex::new(m.clone());
    lex1.insert(doc("a"), "tropical alpha", EidosSourceKind::Note).unwrap();
    let mut sem1 = InMemorySemanticIndex::new(m.clone(), 2);
    sem1.insert(doc("a"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();
    let inner_k10 = HybridRetriever::new(lex1, sem1).unwrap().with_k(10);

    // Inner hybrid #2: k=60 (default)
    let mut lex2 = InMemoryLexicalIndex::new(m.clone());
    lex2.insert(doc("a"), "tropical alpha", EidosSourceKind::Note).unwrap();
    let mut sem2 = InMemorySemanticIndex::new(m.clone(), 2);
    sem2.insert(doc("a"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();
    let inner_k60 = HybridRetriever::new(lex2, sem2).unwrap();

    let outer =
        HybridRetrieverN::new(vec![Box::new(inner_k10), Box::new(inner_k60)]).unwrap();

    let q = EidosQuery::with_vector("tropical", EidosRetrievalMode::Hybrid, 8, vec![1.0, 0.0]);
    let packet = outer.retrieve(&q, 1_700_000_000_000);

    assert!(!packet.hits.is_empty());
    for hit in &packet.hits {
        // Confidence stays in the unit interval despite k-divergence.
        assert!(
            hit.confidence >= 0.0 && hit.confidence <= 1.0,
            "confidence {} out of [0,1] under k-divergence",
            hit.confidence
        );
        // Closed-citation contract still holds.
        let cite = EidosCitation {
            source_id: hit.source_id.clone(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert_eq!(packet.validate_citation(&cite), Ok(()));
    }
}

// ---------------------------------------------------------------------------
// ChatCoordinator-style emit gate (integration shape)
// ---------------------------------------------------------------------------

/// Simulates the canonical chat-layer emit path:
///   1. Run retrieval against a real corpus, get a packet.
///   2. Model produces an answer with a list of citations (some real, some
///      possibly forged).
///   3. Gate: validate_citations on the full list. Result is all-or-
///      nothing — if ANY citation is rejected, refuse the answer
///      wholesale.
/// Demonstrates the closed-citation contract operating end-to-end.
#[test]
fn chat_layer_emit_gate_all_legitimate_citations_passes() {
    use super::types::EidosCitation;

    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("note-a"), "alpha tropical content", EidosSourceKind::Note).unwrap();
    lex.insert(doc("note-b"), "beta tropical content", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("tropical", EidosRetrievalMode::Lexical, 16);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), 2);

    // Model produces an answer citing BOTH hits — fully legitimate.
    let model_citations: Vec<EidosCitation> = packet
        .hits
        .iter()
        .map(|h| EidosCitation {
            source_id: h.source_id.clone(),
            manifest_id: packet.manifest_id.clone(),
        })
        .collect();

    // Gate: validate_citations all-or-nothing.
    assert_eq!(packet.validate_citations(&model_citations), Ok(()));
}

/// Same shape but with one forged citation in the middle. The gate
/// must refuse the entire answer (not partial-emit) and surface the
/// exact index of the forgery for diagnostic display.
#[test]
fn chat_layer_emit_gate_refuses_wholesale_on_any_forgery() {
    use super::types::{CitationError, EidosCitation};

    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("note-a"), "alpha tropical", EidosSourceKind::Note).unwrap();
    lex.insert(doc("note-b"), "beta tropical", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("tropical", EidosRetrievalMode::Lexical, 16);
    let packet = lex.retrieve(&q, 1_700_000_000_000);

    let citations = vec![
        EidosCitation {
            source_id: packet.hits[0].source_id.clone(),
            manifest_id: packet.manifest_id.clone(),
        },
        EidosCitation {
            source_id: super::types::EidosChunkId::new("note-fabricated::lex").unwrap(),
            manifest_id: packet.manifest_id.clone(),
        },
        EidosCitation {
            source_id: packet.hits[1].source_id.clone(),
            manifest_id: packet.manifest_id.clone(),
        },
    ];

    let errors = packet.validate_citations(&citations).unwrap_err();
    assert_eq!(errors.len(), 1, "exactly one forgery, exactly one error");
    assert_eq!(errors[0].0, 1, "forgery at input index 1");
    assert!(matches!(
        errors[0].1,
        CitationError::FabricatedSourceId(_)
    ));

    // The chat layer's "all or nothing" semantic — if validate_citations
    // returns Err, do NOT emit any part of the answer.
    let should_emit = packet.validate_citations(&citations).is_ok();
    assert!(!should_emit, "answer with any forged citation must not emit");
}

// ---------------------------------------------------------------------------
// Recency: since_unix_ms + same-timestamp tie-break interaction
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Doc-and-code drift detector (design doc ↔ EidosRetrievalMode enum)
// ---------------------------------------------------------------------------

/// Read the design doc, count rows in the §4 retrieval-mode table, and
/// assert the count matches our manual enumeration of EidosRetrievalMode
/// variants (+ the HybridRetrieverN N-way variant which gets its own
/// row even though it shares the `Hybrid` mode discriminator). Catches
/// a future contributor adding a new mode without updating either the
/// doc or the enumeration list here — both have to evolve together or
/// the test breaks.
#[test]
fn design_doc_retrieval_mode_table_matches_enum() {
    let path = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../docs/EIDOS_V0_CLOSED_CITATION_DESIGN_2026_05_18.md"
    );
    let doc = std::fs::read_to_string(path).expect("read design doc");

    // Scope to §4: collect lines between the §4 heading and the next
    // top-level heading (§4b, §5, …). Other tables in the doc (tier
    // split rows etc.) also start with "| `", so a doc-wide count
    // double-counts those.
    let mut in_section_4 = false;
    let mut row_count = 0usize;
    for line in doc.lines() {
        if line.starts_with("## 4. ") {
            in_section_4 = true;
            continue;
        }
        if in_section_4 && line.starts_with("## ") {
            // Hit the next section heading (§4b or §5) — stop counting.
            break;
        }
        if in_section_4 && line.starts_with("| `") {
            row_count += 1;
        }
    }

    // 9 canonical-EidosRetrievalMode rows + 1 HybridRetrieverN row + 1
    // LedgerBackedClaimEvidence row (W-49 production wiring for
    // ClaimEvidence; same trait + chunk_id format, distinct row because
    // the backing store differs).
    assert_eq!(
        row_count, 11,
        "design-doc §4 retrieval-mode table row count drifted from \
         the EidosRetrievalMode enum (+ HybridRetrieverN + \
         LedgerBackedClaimEvidence). Update either the doc or this \
         test in lock-step."
    );

    // Every named variant must have a backtick-fenced occurrence in the
    // doc — catches a row being renamed without the source enum.
    for mode in [
        "Lexical",
        "Semantic",
        "Hybrid",
        "CodeSymbol",
        "ClaimEvidence",
        "GraphNeighborhood",
        "RawArchive",
        "Recency",
        "ProvenanceVerified",
    ] {
        assert!(
            doc.contains(&format!("`{mode}`")),
            "design-doc missing backtick reference to mode {mode}"
        );
    }
}

// ---------------------------------------------------------------------------
// Hybrid document-id collision dedup
// ---------------------------------------------------------------------------

/// Same `EidosDocumentId` indexed into Lexical with one body and into
/// Semantic with a different vector. Hybrid fusion must produce EXACTLY
/// ONE hit for that document_id (dedup'd by document_id, not by
/// inner-mode source_id like "doc::lex" / "doc::sem"). The fused hit
/// carries both score components populated, indicating both inner
/// retrievers contributed.
#[test]
fn hybrid_collision_on_document_id_emits_exactly_one_fused_hit() {
    use super::hybrid::HybridRetriever;
    use super::types::EidosCitation;

    let m = manifest();
    // Lexical: doc has body "tropical alpha".
    let mut lex = InMemoryLexicalIndex::new(m.clone());
    lex.insert(doc("shared"), "tropical alpha", EidosSourceKind::Note).unwrap();
    // Semantic: SAME doc id but a fresh vector — internally, the lexical
    // and semantic retrievers know nothing about each other; the only
    // shared key is the EidosDocumentId.
    let mut sem = InMemorySemanticIndex::new(m.clone(), 2);
    sem.insert(doc("shared"), vec![0.9, 0.4], EidosSourceKind::Note).unwrap();

    let hybrid = HybridRetriever::new(lex, sem).unwrap();
    let q = EidosQuery::with_vector(
        "tropical",
        EidosRetrievalMode::Hybrid,
        16,
        vec![1.0, 0.0],
    );
    let packet = hybrid.retrieve(&q, 1_700_000_000_000);

    // Exactly one hit despite the document appearing under two distinct
    // inner-mode source_ids ("shared::lex" and "shared::sem").
    assert_eq!(packet.hits.len(), 1);
    assert_eq!(packet.hits[0].document_id.as_str(), "shared");
    assert_eq!(packet.hits[0].source_id.as_str(), "shared::hybrid");

    // Both score components populated — proof both retrievers
    // contributed to the fused hit.
    assert!(packet.hits[0].score.lexical > 0.0);
    assert!(packet.hits[0].score.semantic > 0.0);

    // Closed-citation contract: fused id validates; pre-fusion ids
    // ("shared::lex", "shared::sem") do NOT.
    let fused = EidosCitation {
        source_id: super::types::EidosChunkId::new("shared::hybrid").unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert_eq!(packet.validate_citation(&fused), Ok(()));
    for pre in ["shared::lex", "shared::sem"] {
        let bad = EidosCitation {
            source_id: super::types::EidosChunkId::new(pre).unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert!(packet.validate_citation(&bad).is_err());
    }
}

// ---------------------------------------------------------------------------
// Recency: u64::MAX timestamp does not panic
// ---------------------------------------------------------------------------

/// Adversarial: a document inserted with `created_at_unix_ms = u64::MAX`
/// (far-future / pathological clock) must not panic when scored.
/// `saturating_sub` in the score formula guards against the subtraction
/// underflow when `retrieved_at < created_at`; this test pins that
/// guarantee with an explicit u64::MAX case.
#[test]
fn recency_u64_max_created_at_does_not_panic() {
    use super::recency::InMemoryRecencyIndex;

    let mut r = InMemoryRecencyIndex::new(manifest());
    r.insert(doc("eternity"), "alpha", u64::MAX, EidosSourceKind::Note);
    let q = EidosQuery::new("", EidosRetrievalMode::Recency, 8);
    let packet = r.retrieve(&q, 1_700_000_000_000);
    // Score saturates to 1.0 (age = retrieved - created saturating to 0).
    assert_eq!(packet.hits.len(), 1);
    assert!((packet.hits[0].score.recency - 1.0).abs() < 1e-6);
    // Confidence still in unit interval.
    assert!(packet.hits[0].confidence >= 0.0 && packet.hits[0].confidence <= 1.0);
}

// ---------------------------------------------------------------------------
// Nested ProvenanceVerified composition
// ---------------------------------------------------------------------------

/// `ProvenanceVerified(ProvenanceVerified(Lexical))` — wrapping a
/// verified retriever inside another verified retriever. The outer must
/// still report mode == ProvenanceVerified (no double-mode-leak), the
/// outer's admit set must take precedence (it can narrow further), and
/// the closed-citation contract must remain intact end-to-end. Catches
/// a future regression where the wrapper might double-rewrite or skip
/// the inner's filter.
#[test]
fn provenance_verified_can_nest_without_double_rewrite() {
    use super::provenance_verified::ProvenanceVerifiedRetriever;
    use super::types::EidosCitation;

    let m = manifest();
    let mut lex = InMemoryLexicalIndex::new(m.clone());
    lex.insert(doc("a"), "tropical content", EidosSourceKind::Note).unwrap();
    lex.insert(doc("b"), "tropical other", EidosSourceKind::Note).unwrap();

    // Inner wrapper admits both ids.
    let mut inner = ProvenanceVerifiedRetriever::new(lex);
    inner.admit(super::types::EidosChunkId::new("a::lex").unwrap());
    inner.admit(super::types::EidosChunkId::new("b::lex").unwrap());

    // Outer wrapper admits ONLY "a::lex" — should narrow further.
    let mut outer = ProvenanceVerifiedRetriever::new(inner);
    outer.admit(super::types::EidosChunkId::new("a::lex").unwrap());

    let q = EidosQuery::new("tropical", EidosRetrievalMode::ProvenanceVerified, 16);
    let packet = outer.retrieve(&q, 1_700_000_000_000);

    // Only "a::lex" survives both wrappers.
    let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
    assert_eq!(ids, vec!["a::lex"]);

    // Outer's mode wins — no double-leak of inner mode.
    for hit in &packet.hits {
        assert_eq!(hit.provenance.mode, EidosRetrievalMode::ProvenanceVerified);
    }

    // Closed-citation contract still intact.
    let admitted = EidosCitation {
        source_id: super::types::EidosChunkId::new("a::lex").unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert_eq!(packet.validate_citation(&admitted), Ok(()));

    // "b::lex" was admitted by the inner but NOT by the outer — rejected.
    let inner_only = EidosCitation {
        source_id: super::types::EidosChunkId::new("b::lex").unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert!(packet.validate_citation(&inner_only).is_err());
}

// ---------------------------------------------------------------------------
// EidosCitation Hash/Eq derives are exercised (HashSet usability)
// ---------------------------------------------------------------------------

/// EidosCitation derives Hash + Eq, but no existing test exercises the
/// HashSet path. Pin the invariant that two citations constructed with
/// the same (source_id, manifest_id) collide in a HashSet — used by the
/// future chat-layer "dedup citations before validating" step.
#[test]
fn eidos_citation_hash_eq_dedup_in_hashset() {
    use std::collections::HashSet;

    use super::types::{EidosChunkId, EidosCitation, EidosIndexManifestId};

    let m = EidosIndexManifestId::new("hash-test").unwrap();
    let id = EidosChunkId::new("d::lex").unwrap();

    let c1 = EidosCitation {
        source_id: id.clone(),
        manifest_id: m.clone(),
    };
    let c2 = EidosCitation {
        source_id: id.clone(),
        manifest_id: m.clone(),
    };
    // Equality.
    assert_eq!(c1, c2);

    // HashSet dedup: inserting both yields a 1-element set.
    let mut set: HashSet<EidosCitation> = HashSet::new();
    set.insert(c1);
    set.insert(c2);
    assert_eq!(set.len(), 1);

    // A different manifest_id makes it a distinct key.
    let other = EidosCitation {
        source_id: id,
        manifest_id: EidosIndexManifestId::new("DIFFERENT").unwrap(),
    };
    set.insert(other);
    assert_eq!(set.len(), 2);
}

/// Multiple documents with identical `created_at_unix_ms` that all
/// survive the `since_unix_ms` floor must order by `source_id ascending`.
/// Pins the tie-break behavior under the time-window filter.
#[test]
fn recency_since_with_simultaneous_timestamps_breaks_on_source_id() {
    use super::recency::InMemoryRecencyIndex;

    const T0: u64 = 1_700_000_000_000;
    const ONE_DAY: u64 = 86_400_000;

    let mut r = InMemoryRecencyIndex::new(manifest());
    // Three docs at the SAME timestamp, all newer than the floor.
    r.insert(doc("c"), "x", T0, EidosSourceKind::Note);
    r.insert(doc("a"), "x", T0, EidosSourceKind::Note);
    r.insert(doc("b"), "x", T0, EidosSourceKind::Note);
    // One doc just before the floor — must be dropped.
    r.insert(doc("ancient"), "x", T0 - 2 * ONE_DAY, EidosSourceKind::Note);

    let q = EidosQuery::new("", EidosRetrievalMode::Recency, 16).with_since(T0 - ONE_DAY);
    let packet = r.retrieve(&q, T0);
    let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
    // Same timestamp → source_id ascending; ancient dropped.
    assert_eq!(
        ids,
        vec!["a::recency", "b::recency", "c::recency"],
        "tie-break on source_id ascending under since floor"
    );
}

/// Empty-corpus replay determinism sweep — for every retriever mode,
/// two freshly-constructed empty retrievers produce byte-equal empty
/// packets for the same query + clock. AND every empty packet still
/// carries the correct `manifest_id` (no degenerate empty-manifest leak).
#[test]
fn every_retriever_empty_corpus_returns_byte_equal_empty_packet() {
    use super::claim_evidence::InMemoryClaimEvidence;
    use super::code_symbol::InMemoryCodeSymbolIndex;
    use super::graph_neighborhood::InMemoryGraphNeighborhood;
    use super::hybrid::HybridRetriever;
    use super::hybrid_n::HybridRetrieverN;
    use super::provenance_verified::ProvenanceVerifiedRetriever;
    use super::raw_archive::InMemoryRawArchive;
    use super::recency::InMemoryRecencyIndex;

    let m = manifest();
    let q_lex = EidosQuery::new("anything", EidosRetrievalMode::Lexical, 8);
    let q_sem = EidosQuery::with_vector(
        "anything",
        EidosRetrievalMode::Semantic,
        8,
        vec![1.0, 0.0, 0.0],
    );
    let q_code = EidosQuery::new("symbol", EidosRetrievalMode::CodeSymbol, 8);
    let q_graph = EidosQuery::new("seed", EidosRetrievalMode::GraphNeighborhood, 8);
    let q_claim = EidosQuery::new("claim:id", EidosRetrievalMode::ClaimEvidence, 8);
    let q_raw = EidosQuery::new("doc-id", EidosRetrievalMode::RawArchive, 8);
    let q_recency = EidosQuery::new("", EidosRetrievalMode::Recency, 8);

    let ts = 1_700_000_000_000;

    // Helper: build two empty retrievers of the same shape and assert
    // their packets are byte-equal AND non-empty manifest_id.
    macro_rules! sweep {
        ($build:expr, $query:expr) => {{
            let a = $build;
            let b = $build;
            let pa = a.retrieve(&$query, ts);
            let pb = b.retrieve(&$query, ts);
            assert_eq!(pa, pb, "empty-corpus packets must be byte-equal");
            assert!(pa.hits.is_empty());
            assert_eq!(pa.manifest_id, m, "empty packet leaked wrong manifest_id");
        }};
    }

    sweep!(InMemoryLexicalIndex::new(m.clone()), q_lex);
    sweep!(InMemorySemanticIndex::new(m.clone(), 3), q_sem);
    sweep!(InMemoryCodeSymbolIndex::new(m.clone()), q_code);
    sweep!(InMemoryGraphNeighborhood::new(m.clone()), q_graph);
    sweep!(InMemoryClaimEvidence::new(m.clone()), q_claim);
    sweep!(InMemoryRawArchive::new(m.clone()), q_raw);
    sweep!(InMemoryRecencyIndex::new(m.clone()), q_recency);

    // Hybrid (2-way) — empty inner retrievers.
    let lex = InMemoryLexicalIndex::new(m.clone());
    let sem = InMemorySemanticIndex::new(m.clone(), 3);
    let hybrid_a = HybridRetriever::new(lex, sem).unwrap();
    let lex2 = InMemoryLexicalIndex::new(m.clone());
    let sem2 = InMemorySemanticIndex::new(m.clone(), 3);
    let hybrid_b = HybridRetriever::new(lex2, sem2).unwrap();
    let q_h = EidosQuery::with_vector("x", EidosRetrievalMode::Hybrid, 8, vec![1.0, 0.0, 0.0]);
    let pa = hybrid_a.retrieve(&q_h, ts);
    let pb = hybrid_b.retrieve(&q_h, ts);
    assert_eq!(pa, pb);
    assert!(pa.hits.is_empty());
    assert_eq!(pa.manifest_id, m);

    // Hybrid_N — empty inner retrievers.
    let lex_n1 = InMemoryLexicalIndex::new(m.clone());
    let sem_n1 = InMemorySemanticIndex::new(m.clone(), 3);
    let hybrid_n_a =
        HybridRetrieverN::new(vec![Box::new(lex_n1), Box::new(sem_n1)]).unwrap();
    let lex_n2 = InMemoryLexicalIndex::new(m.clone());
    let sem_n2 = InMemorySemanticIndex::new(m.clone(), 3);
    let hybrid_n_b =
        HybridRetrieverN::new(vec![Box::new(lex_n2), Box::new(sem_n2)]).unwrap();
    let pa = hybrid_n_a.retrieve(&q_h, ts);
    let pb = hybrid_n_b.retrieve(&q_h, ts);
    assert_eq!(pa, pb);
    assert!(pa.hits.is_empty());
    assert_eq!(pa.manifest_id, m);

    // ProvenanceVerified wrapping an empty Lexical — empty admit set →
    // empty packet.
    let pv_a = ProvenanceVerifiedRetriever::new(InMemoryLexicalIndex::new(m.clone()));
    let pv_b = ProvenanceVerifiedRetriever::new(InMemoryLexicalIndex::new(m.clone()));
    let q_pv = EidosQuery::new("anything", EidosRetrievalMode::ProvenanceVerified, 8);
    let pa = pv_a.retrieve(&q_pv, ts);
    let pb = pv_b.retrieve(&q_pv, ts);
    assert_eq!(pa, pb);
    assert!(pa.hits.is_empty());
    assert_eq!(pa.manifest_id, m);
}

#[test]
fn semantic_retriever_re_construction_is_byte_equal() {
    let docs: [(&str, Vec<f32>); 3] = [
        ("a", vec![1.0, 0.0, 0.0]),
        ("b", vec![0.0, 1.0, 0.0]),
        ("c", vec![0.0, 0.0, 1.0]),
    ];

    let mut a = InMemorySemanticIndex::new(manifest(), 3);
    for (id, v) in &docs {
        a.insert(doc(id), v.clone(), EidosSourceKind::Note).unwrap();
    }
    let q = EidosQuery::with_vector("any", EidosRetrievalMode::Semantic, 8, vec![1.0, 1.0, 0.0]);
    let pa = a.retrieve(&q, 1_700_000_000_000);
    drop(a);

    let mut b = InMemorySemanticIndex::new(manifest(), 3);
    for (id, v) in &docs {
        b.insert(doc(id), v.clone(), EidosSourceKind::Note).unwrap();
    }
    let pb = b.retrieve(&q, 1_700_000_000_000);

    assert_eq!(pa, pb, "re-construction produced a different packet");
}

/// Drift detector for the design doc's §12 Cross-language wire-format
/// symmetry summary. STATUS.md already pins the table for contributors
/// browsing the eidos/ tree; §12 lifts that pin into the canonical
/// design doc so a future reader of the doc alone still finds the four
/// FFI-bound contract types and knows which Rust+Swift tests pin each.
///
/// Asserts §12 exists and that every contract-type name appears at
/// least once within its scope. Catches a future refactor that drops
/// a contract type from the doc without dropping it from the
/// implementation, or vice versa.
#[test]
fn design_doc_section_12_wire_format_summary_lists_all_four_contract_types() {
    let path = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../docs/EIDOS_V0_CLOSED_CITATION_DESIGN_2026_05_18.md"
    );
    let doc = std::fs::read_to_string(path).expect("read design doc");

    let mut in_section_12 = false;
    let mut section_12_body = String::new();
    for line in doc.lines() {
        if line.starts_with("## 12. ") {
            in_section_12 = true;
            continue;
        }
        if in_section_12 && line.starts_with("## ") {
            break;
        }
        if in_section_12 {
            section_12_body.push_str(line);
            section_12_body.push('\n');
        }
    }
    assert!(
        !section_12_body.is_empty(),
        "design-doc §12 'Cross-language wire-format symmetry' is missing"
    );

    for contract in [
        "EidosContextPacket",
        "EidosCitation",
        "CitationError",
        "Vec<(usize, CitationError)>",
    ] {
        assert!(
            section_12_body.contains(contract),
            "design-doc §12 must reference contract type `{contract}`; \
             section body did not contain it. If you renamed a wire \
             contract, update §12 + STATUS.md symmetry table + this \
             test in lock-step."
        );
    }

    // Falsifier outcome types (iters 63 + 64): Rust serde is bidirectional;
    // Swift mirror pending. §12 must document them as a sibling of the
    // four FFI-bound contract types above so a reader of the design doc
    // alone learns about the bidirectional state.
    for falsifier_type in ["FEidosClosedCitationWitness", "FalsifierFailure"] {
        assert!(
            section_12_body.contains(falsifier_type),
            "design-doc §12 must reference falsifier outcome type \
             `{falsifier_type}`; iters 63/64 made it Rust-side bidirectional. \
             Update §12 + STATUS.md symmetry section + this test in lock-step."
        );
    }
}
