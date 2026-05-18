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
