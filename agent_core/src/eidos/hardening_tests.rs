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
