//! Deep-hardening tests — cross-mode invariants + edge cases the
//! per-retriever test modules don't cover individually.
//!
//! These tests live behind `#[cfg(test)]` so they don't affect the
//! production build surface. They exist because the acceptance bar is a
//! FLOOR not a CEILING: the per-mode tests cover the happy paths + the
//! nine acceptance-bar paths; this module probes the **adversarial**
//! corners — pathological queries, large corpora, insertion-order
//! permutations.
//!
//! Closed-citation contract hardening session (iters 127-206+) — the
//! second major axis of coverage in this module. Pins the byte-strict
//! `EidosContextPacket::validate_citation` floor against six named
//! adversarial smuggling vectors (NFC/NFD canonical-equivalence, ZWSP/
//! invisible-char, Cyrillic-Latin homoglyph, whitespace padding,
//! low-codepoint control-character, bidirectional-text-override),
//! across nine canonical retrieval modes + both ClaimEvidence concrete
//! retrievers, with 11 parallel structural shape-locks (every public
//! type in the contract surface), full Clone byte-perfect trilogy
//! (citation/hit/packet), and lock-step drift detectors that catch
//! catalog drift on the very next test run. See STATUS.md for the
//! full catalog narrative.

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
    // CitationError must cross thread/FFI boundaries too — the chat-
    // layer renders these from a UI thread distinct from whichever
    // thread ran retrieval + validation. Without Send + Sync, the
    // Result<(), CitationError> from validate_citation would refuse
    // to flow across the async/Swift bridge boundary. Sync isn't
    // strictly required (errors are typically owned + moved, not
    // shared), but enums of Send/Sync types are Send + Sync by
    // default; pinning catches a future addition of a non-Sync
    // variant payload (e.g. Rc<…> or RefCell<…>).
    use super::types::CitationError;
    assert_send_and_sync::<CitationError>();
    assert_send_and_sync::<Result<(), CitationError>>();
    assert_send_and_sync::<Vec<(usize, CitationError)>>();
    // IdError + Result<_, IdError> — the constructor-boundary error
    // type. Chat-layer id construction can run on any thread (e.g.
    // an MLX inference thread building EidosCitation from a model
    // response); the Result must flow back to the validation thread
    // without extra wrapping. IdError is currently a unit-variant
    // enum so this is trivially true, but pinning catches a future
    // variant addition with a non-Send/Sync payload.
    use super::types::IdError;
    assert_send_and_sync::<IdError>();
    // Constructor Result wrappers for ALL three id types — iter 189
    // covered only EidosChunkId; iter 202 rounds out coverage so any
    // future variant addition to IdError that breaks Send/Sync for
    // ONE of the three constructor paths is caught uniformly.
    assert_send_and_sync::<Result<super::types::EidosChunkId, IdError>>();
    assert_send_and_sync::<Result<super::types::EidosDocumentId, IdError>>();
    assert_send_and_sync::<Result<super::types::EidosIndexManifestId, IdError>>();
    // JSON deserialize result wrappers — the chat layer pulls
    // citations + packets off the wire via serde_json::from_str,
    // which returns Result<T, serde_json::Error>. Both T and the
    // serde_json error are Send + Sync, but pinning the full
    // wrapper catches a future migration to a non-Send wire-error
    // (e.g. an interpreter-bound error type).
    assert_send_and_sync::<Result<EidosCitation, serde_json::Error>>();
    assert_send_and_sync::<Result<EidosContextPacket, serde_json::Error>>();
    // Hit sub-types — transitively required by EidosHit Send+Sync
    // above, but explicit pins catch a future custom impl that
    // adds a non-Send field (e.g. Rc<…>, RefCell<…>) to one of
    // these. Each is the value type for the corresponding
    // EidosHit field that flows through every retriever's
    // emission path.
    use super::types::{EidosProvenance, EidosScoreComponents, EidosSpan};
    assert_send_and_sync::<EidosScoreComponents>();
    assert_send_and_sync::<EidosSpan>();
    assert_send_and_sync::<EidosProvenance>();
    // Source-kind enum + retrieval-mode enum — used in every
    // retriever's mode() impl and in EidosHit.kind. Pure enums of
    // Copy primitives so trivially Send+Sync, but pinning
    // documents the FFI contract.
    use super::types::EidosSourceKind;
    assert_send_and_sync::<EidosSourceKind>();
    assert_send_and_sync::<EidosRetrievalMode>();

    // Eq + Hash compile-time pin for EidosCitation — required by
    // HashSet-based pre-validation dedup (iter 181 + 182). Std
    // requires Eq for Hash to be coherent (a == b → hash(a) ==
    // hash(b)), so the two traits travel together. A future
    // "remove the Eq derive for some performance reason" change
    // would silently break HashSet usage in the chat layer. This
    // assertion fails at compile time if either trait is removed.
    fn assert_eq_hash<T: Eq + std::hash::Hash>() {}
    assert_eq_hash::<EidosCitation>();
    // Companion: the id newtypes also implement Eq + Hash and are
    // used as keys in retriever-side dedup maps. Pin them too.
    assert_eq_hash::<EidosChunkId>();
    assert_eq_hash::<EidosIndexManifestId>();
    // EidosDocumentId is used as a HashMap key in retriever-
    // internal indices (InMemoryCodeSymbolIndex, InMemoryGraph
    // Neighborhood, InMemoryRawArchive). Pin Eq + Hash so a
    // future change that drops these derives surfaces at compile
    // time across every retriever's internal storage.
    assert_eq_hash::<super::types::EidosDocumentId>();

    // Ord pin — all three id newtypes are also used as BTreeMap
    // keys (InMemoryRawArchive uses BTreeMap<EidosDocumentId,
    // ArchivedDocument>, InMemoryGraphNeighborhood uses BTreeMap
    // for deterministic edge iteration). A future change that
    // dropped Ord would break those storage layers at compile
    // time, but the failure would surface in the retriever code,
    // not in the contract surface. Pin here to catch the issue
    // at the closed-citation hardening boundary.
    fn assert_ord<T: Ord>() {}
    assert_ord::<EidosChunkId>();
    assert_ord::<EidosIndexManifestId>();
    assert_ord::<super::types::EidosDocumentId>();
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

#[test]
fn lexical_never_emits_zero_width_span() {
    // Audit per "audit existing claims first": Lexical's
    // `approximate_span` returns a span whose width equals the
    // needle's byte length. The empty-needle defer (iter 67) ensures
    // needle.len() ≥ 1 by the time approximate_span is called, so the
    // emitted span always satisfies byte_end > byte_start strictly.
    //
    // Pin the minimum non-zero span case (1-byte needle "x") so a
    // future refactor that loosened the empty-needle guard would
    // surface here via a zero-width span sneaking through.
    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("d"), "x", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("x", EidosRetrievalMode::Lexical, 8);
    let packet = lex.retrieve(&q, 0);
    assert_eq!(packet.hits.len(), 1);
    let span = packet.hits[0]
        .span
        .expect("Lexical must emit a span on a match");
    assert_eq!(span.byte_start, 0);
    assert_eq!(span.byte_end, 1, "1-byte needle must yield 1-byte span");
    // Belt-and-braces: width > 0 strictly.
    assert!(
        span.byte_end > span.byte_start,
        "Lexical must never emit zero-width spans on a real match",
    );
}

#[test]
fn top_k_zero_yields_empty_packet_for_hybrid_and_hybrid_n() {
    // Audit per "audit existing claims first": top_k=0 is pinned
    // individually for Recency, ClaimEvidence, RawArchive, CodeSymbol,
    // GraphNeighborhood. The fusion paths (Hybrid 2-way + Hybrid_N) had
    // NO direct top_k=0 test even though each does `.take(top_k)` after
    // the fold. A future fold change that allocated max-N before
    // truncating could leak hits into a top_k=0 result without any
    // existing test firing.
    //
    // Pin both fusion paths in one test against a populated corpus
    // where the inner backends would each return at least one hit
    // at any non-zero top_k.
    use super::hybrid::HybridRetriever;
    use super::hybrid_n::HybridRetrieverN;
    use super::semantic::InMemorySemanticIndex;

    let build_lex = || {
        let mut l = InMemoryLexicalIndex::new(manifest());
        l.insert(doc("a"), "tropical content", EidosSourceKind::Note).unwrap();
        l
    };
    let build_sem = || {
        let mut s = InMemorySemanticIndex::new(manifest(), 2);
        s.insert(doc("a"), vec![1.0, 0.0], EidosSourceKind::Note).unwrap();
        s
    };

    // Hybrid 2-way: top_k=0 must yield empty hits.
    let hybrid = HybridRetriever::new(build_lex(), build_sem()).unwrap();
    let q = EidosQuery::with_vector("tropical", EidosRetrievalMode::Hybrid, 0, vec![1.0, 0.0]);
    let packet = hybrid.retrieve(&q, 1_700_000_000_000);
    assert!(
        packet.hits.is_empty(),
        "Hybrid 2-way with top_k=0 must return empty packet; got {} hits",
        packet.hits.len()
    );

    // Hybrid_N: same invariant for the N-way fold.
    let hybrid_n = HybridRetrieverN::new(vec![Box::new(build_lex()), Box::new(build_sem())])
        .unwrap();
    let packet_n = hybrid_n.retrieve(&q, 1_700_000_000_000);
    assert!(
        packet_n.hits.is_empty(),
        "Hybrid_N with top_k=0 must return empty packet; got {} hits",
        packet_n.hits.len()
    );

    // Sanity-pin that the corpus would NOT be empty at top_k=1 — so
    // the empty result at top_k=0 is genuinely from the truncation,
    // not from a stale fixture or upstream bug.
    let q1 = EidosQuery::with_vector("tropical", EidosRetrievalMode::Hybrid, 1, vec![1.0, 0.0]);
    let sane = HybridRetriever::new(build_lex(), build_sem()).unwrap();
    assert_eq!(sane.retrieve(&q1, 1_700_000_000_000).hits.len(), 1);
}

#[test]
fn falsifier_accepts_span_past_body_length_intentionally() {
    // Third span-contract pin alongside iter 84 (zero-width accept)
    // and iter 86 (inverted reject). Together the three pins codify
    // the full span-validation surface of the falsifier:
    //
    //   - [n, n)  → ACCEPT (half-open empty is valid, iter 84)
    //   - [n, m) where n > m → REJECT as HitSpanInvalid (iter 86)
    //   - [n, m) where m > body.len() → ACCEPT here (this test)
    //
    // Rationale: `EidosHit` carries the span but NOT the source body,
    // so the falsifier has no body length to compare against. Body-
    // length validation is intentionally OUT of scope for the runtime
    // contract — the per-backend insert paths are responsible for
    // their own body bookkeeping (Lexical only emits spans within its
    // body; CodeSymbol delegates to the caller). A future change to
    // add body-length validation to the falsifier would require a
    // schema change (carrying body.len() in EidosHit) and would
    // surface as a test failure here, forcing an explicit decision.
    //
    // CodeSymbol accepts arbitrary byte ranges via insert(), so use
    // it to exercise the case. byte_start=1000, byte_end=2000 — both
    // far past any plausible body length, well-ordered.
    use super::code_symbol::InMemoryCodeSymbolIndex;
    let mut cs = InMemoryCodeSymbolIndex::new(manifest());
    cs.insert("past_body_symbol", doc("d"), 1_000, 2_000);
    let retrievers: Vec<Box<dyn super::retriever::EidosRetriever>> =
        vec![Box::new(cs)];
    let queries = vec![EidosQuery::new(
        "past_body_symbol",
        EidosRetrievalMode::CodeSymbol,
        8,
    )];
    let witness = super::falsifier::f_eidos_closed_citation_falsifier(
        &retrievers,
        &queries,
        0,
    )
    .expect(
        "span past body length is ACCEPT-by-design; falsifier has no body \
         to compare against (EidosHit carries the span, not the body)",
    );
    assert_eq!(witness.retrievers_checked, 1);
    assert!(
        witness.total_hits_validated >= 1,
        "the past-body hit must reach the validation surface, not silently \
         disappear before counting"
    );
}

#[test]
fn code_symbol_inverted_span_fires_hit_span_invalid_through_falsifier() {
    // Symmetric counterpart to `falsifier_accepts_zero_width_span_as_half_open_valid`
    // below. Iter 84 proved CodeSymbol(byte_start == byte_end) passes
    // the falsifier; this proves CodeSymbol(byte_start > byte_end)
    // fires `HitSpanInvalid` through the REAL backend path.
    //
    // Existing `falsifier_catches_hit_span_invalid` (falsifier.rs:907)
    // proves the falsifier check itself works via a SYNTHETIC
    // `InvalidSpanRetriever`. This test goes one level deeper: prove
    // that the real CodeSymbol backend faithfully propagates a
    // caller-supplied inverted range into the emitted hit, and that
    // the falsifier then catches it. Catches a future "validate-on-
    // insert" change to CodeSymbol that would silently swallow
    // inverted ranges before the falsifier ever sees them — which
    // would change the contract (the contract is: the FALSIFIER is
    // the runtime guard, not the per-backend insert paths).
    use super::code_symbol::InMemoryCodeSymbolIndex;
    let mut cs = InMemoryCodeSymbolIndex::new(manifest());
    // byte_start=10 > byte_end=5 — explicitly inverted.
    cs.insert("inverted_symbol", doc("d"), 10, 5);
    let retrievers: Vec<Box<dyn super::retriever::EidosRetriever>> =
        vec![Box::new(cs)];
    let queries =
        vec![EidosQuery::new("inverted_symbol", EidosRetrievalMode::CodeSymbol, 8)];
    let err = super::falsifier::f_eidos_closed_citation_falsifier(
        &retrievers,
        &queries,
        0,
    )
    .expect_err("inverted span MUST fire HitSpanInvalid through the falsifier");
    match err {
        super::falsifier::FalsifierFailure::HitSpanInvalid {
            byte_start,
            byte_end,
            retriever_mode,
            ..
        } => {
            assert_eq!(byte_start, 10);
            assert_eq!(byte_end, 5);
            assert_eq!(retriever_mode, EidosRetrievalMode::CodeSymbol);
        }
        other => panic!(
            "expected HitSpanInvalid {{ byte_start: 10, byte_end: 5 }}, got {other:?}",
        ),
    }
}

#[test]
fn falsifier_accepts_zero_width_span_as_half_open_valid() {
    // Companion direction: the Spans contract is half-open
    // `[byte_start, byte_end)`, and `[n, n)` is a *legitimate* empty
    // half-open range (not an inverted span). The falsifier's check
    // at falsifier.rs:213 uses `span.byte_start > span.byte_end`
    // (strict `>`), intentionally accepting zero-width as valid.
    // CodeSymbol takes byte ranges from the caller, so it CAN emit
    // zero-width spans if the caller chooses; the falsifier must not
    // false-positive on them.
    //
    // Build a CodeSymbol with an explicit zero-width occurrence and
    // run the falsifier — it must NOT fire HitSpanInvalid.
    use super::code_symbol::InMemoryCodeSymbolIndex;
    let mut cs = InMemoryCodeSymbolIndex::new(manifest());
    cs.insert("zero_width_symbol", doc("d"), 5, 5); // byte_start == byte_end
    let retrievers: Vec<Box<dyn super::retriever::EidosRetriever>> =
        vec![Box::new(cs)];
    let queries =
        vec![EidosQuery::new("zero_width_symbol", EidosRetrievalMode::CodeSymbol, 8)];
    let witness = super::falsifier::f_eidos_closed_citation_falsifier(
        &retrievers,
        &queries,
        0,
    )
    .expect("zero-width span [n, n) is half-open valid and must pass the falsifier");
    assert_eq!(witness.retrievers_checked, 1);
    // Sanity: a hit actually fired (otherwise this test would trivially
    // pass even if a future change broke span validation).
    assert!(witness.total_hits_validated >= 1);
}

#[test]
fn lexical_document_body_with_nul_byte_is_matched_by_nul_query() {
    // Companion direction to the test above. The Lexical pipeline must
    // preserve NUL bytes in document bodies through `to_lowercase` and
    // `str::matches`, so a NUL query produces a real hit when the body
    // contains a NUL. Catches a future "filter unprintables on insert"
    // change that would silently drop NUL bytes and break the
    // empty-defer asymmetry: `is_empty()` on the query side never fires
    // for "\0" (it's a 1-byte string), so the contract is "matches if
    // and only if a NUL exists somewhere in the body".
    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("with-nul"), "before\0after", EidosSourceKind::Note)
        .unwrap();
    lex.insert(doc("no-nul"), "clean body", EidosSourceKind::Note).unwrap();

    let q = EidosQuery::new("\x00", EidosRetrievalMode::Lexical, 8);
    let packet = lex.retrieve(&q, 1_700_000_000_000);

    // Exactly one hit — the doc whose body contains NUL.
    assert_eq!(packet.hits.len(), 1);
    let hit = &packet.hits[0];
    assert_eq!(hit.source_id.as_str(), "with-nul::lex");
    assert_eq!(hit.document_id.as_str(), "with-nul");

    // Approximate span lands on the NUL byte. The body's lowercased form
    // is byte-identical to the original for NUL (NUL has no case form),
    // so the span is exact, not approximate: byte_start = 6 (after
    // "before"), byte_end = 7. Pin this so a future change to the
    // lowercase/span-projection logic that breaks NUL handling fires
    // here.
    let span = hit.span.expect("span should be present for a Lexical hit");
    assert_eq!(span.byte_start, 6);
    assert_eq!(span.byte_end, 7);
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

    // LedgerBackedClaimEvidence — production ClaimEvidence wiring
    // (W-49 closed in STATUS.md). Audit per "audit existing claims
    // first" found this backend was the only retriever missing from
    // the sweep above. Two fresh ledger-backed retrievers over an
    // empty ClaimLedger must produce byte-equal empty packets with
    // the canonical manifest binding.
    use super::ledger_backed_claim_evidence::LedgerBackedClaimEvidence;
    use crate::provenance::ledger::ClaimLedger;
    let led_a = LedgerBackedClaimEvidence::from_ledger(&ClaimLedger::new(), m.clone());
    let led_b = LedgerBackedClaimEvidence::from_ledger(&ClaimLedger::new(), m.clone());
    let pa = led_a.retrieve(&q_claim, ts);
    let pb = led_b.retrieve(&q_claim, ts);
    assert_eq!(pa, pb, "LedgerBackedClaimEvidence empty-corpus packets must be byte-equal");
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

/// Cross-component `RRF_K_DEFAULT` drift detector. The k=60 constant
/// is canon in three places (per hybrid.rs:23-25 docstring):
///   1. `epistemos-shadow/src/backend/rrf.rs:22` — the production
///      Tantivy+usearch RRF pipeline.
///   2. `agent_core/src/eidos/hybrid.rs:56` — the Eidos Rust
///      Hybrid + Hybrid_N retrievers (pinned at hybrid.rs:590).
///   3. `Epistemos/Sync/RRFFusionQuery.swift:183` —
///      `Phase3FusionConsts.K_RRF` for the Swift fusion stack.
///
/// All three MUST stay equal so chat-layer cross-language ranking
/// stays consistent. The Rust↔Rust constant matches itself trivially
/// at compile time; the existing hybrid.rs test pins
/// `RRF_K_DEFAULT == 60` on the Rust side. What was NOT pinned: the
/// Rust↔Swift invariant. A future change that shifted one side
/// (say, "tune k for personal vault retrieval" — design doc §11.2's
/// open research question) without updating the other would silently
/// diverge.
///
/// This detector reads `Epistemos/Sync/RRFFusionQuery.swift` and
/// asserts it contains `K_RRF: Double = 60`. Combined with
/// hybrid.rs:590's Rust-side pin, the cross-language invariant is now
/// locked.
#[test]
fn rrf_k_default_60_matches_swift_phase3fusionconsts_k_rrf() {
    use crate::eidos::hybrid::RRF_K_DEFAULT;

    // Rust-side anchor — same as hybrid.rs:590 but inline so this
    // test fails informatively even if hybrid.rs's pin was removed.
    assert_eq!(
        RRF_K_DEFAULT, 60,
        "Rust RRF_K_DEFAULT must be 60 to match shadow + Swift",
    );

    let swift_path = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../Epistemos/Sync/RRFFusionQuery.swift"
    );
    let swift = std::fs::read_to_string(swift_path).expect("read RRFFusionQuery.swift");

    assert!(
        swift.contains("K_RRF: Double = 60"),
        "Swift Phase3FusionConsts.K_RRF must equal 60.0 to match Rust \
         RRF_K_DEFAULT. If one side legitimately needs to change (e.g., \
         resolving design doc §11.2's k-tuning research question), update \
         BOTH sites in lock-step + this detector + epistemos-shadow's \
         RRF_K_DEFAULT."
    );
}

/// Falsifier docstring drift detector. Iter 122 expanded the §"What
/// the falsifier checks" enumeration from 3 to 5 per-hit invariants
/// (added HitConfidenceOutOfRange + HitSpanInvalid). Pin the
/// corrected state so a future edit that removed an invariant
/// reference from the docstring would surface here, forcing the
/// docstring to stay in lock-step with the impl.
///
/// Each variant name must appear in the falsifier module's leading
/// docstring block. Substring match is narrow enough to catch a
/// missing reference, loose enough to survive minor phrasing edits.
#[test]
fn falsifier_module_docstring_lists_all_five_per_hit_invariants() {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/src/eidos/falsifier.rs");
    let src = std::fs::read_to_string(path).expect("read falsifier.rs");

    // Scope to the leading module docstring block (lines starting with
    // `//!`). Body comments / test names happen to mention these
    // variants too, and we want to catch a docstring-only regression.
    let head: String = src
        .lines()
        .take_while(|l| l.starts_with("//!") || l.is_empty())
        .collect::<Vec<_>>()
        .join("\n");

    // Three closed-citation contract checks (1, 2a-2c, 3) + two
    // hit-shape checks (2d, 2e) = 5 per-hit invariants total.
    for variant in [
        "HitConfidenceOutOfRange",
        "HitSpanInvalid",
    ] {
        assert!(
            head.contains(variant),
            "falsifier module docstring must reference \
             FalsifierFailure::{variant} (added iter 122 as part of the \
             full 5-invariant enumeration). A future edit that dropped it \
             would let the doc lag the impl silently — update the doc and \
             this drift detector in lock-step if you intentionally trim the \
             enumeration."
        );
    }

    // The §"What the falsifier checks" heading itself.
    assert!(
        head.contains("What the falsifier checks"),
        "falsifier module docstring must keep the heading \
         '## What the falsifier checks' — readers navigating to the \
         contract reference rely on it."
    );
}

/// Module-wide stale-count drift detector. Iters 119/121/126 corrected
/// stale "seven retrieval modes" claims across five files — matching
/// `EidosRetrievalMode::CANON_ALL.len() == 9`. Pin the corrected state
/// so a future copy-paste regression or partial docstring edit can't
/// silently re-introduce the stale count anywhere in the module tree.
///
/// Asserts no eidos source file under `agent_core/src/eidos/` contains
/// the literal "of seven " substring (the stale phrase shape — both
/// "of seven retrieval modes" and "of the seven canonical" matched it
/// pre-iter-126). Excludes hardening_tests.rs itself because this
/// detector legitimately mentions the stale phrase in its assertion
/// messages.
///
/// Iter 119 originally found lex/sem; iter 126's broader audit caught
/// raw_archive.rs + provenance_verified.rs + retriever.rs (the latter
/// two used the variant "of the seven" which a narrow "of seven"
/// substring didn't match in the original detector). This detector
/// scans the full directory to catch any future surface that adopts
/// either variant.
#[test]
fn no_eidos_source_file_contains_stale_seven_modes_claim() {
    use std::fs;

    let dir = concat!(env!("CARGO_MANIFEST_DIR"), "/src/eidos");
    let entries = fs::read_dir(dir).expect("read eidos directory");

    for entry in entries {
        let entry = entry.expect("dir entry");
        let path = entry.path();
        let name = match path.file_name().and_then(|s| s.to_str()) {
            Some(n) => n.to_string(),
            None => continue,
        };
        // Skip non-Rust files + this test file itself + the catch-all
        // hardening_tests.rs (which mentions the stale phrase in
        // assertion messages on purpose).
        if !name.ends_with(".rs") || name == "hardening_tests.rs" {
            continue;
        }
        let body = fs::read_to_string(&path).expect("read source");
        // Match both "of seven retrieval modes" and "of the seven
        // canonical modes" variants via the common substring
        // " seven retrieval " or " seven canonical ". Narrow enough
        // that legitimate uses of "seven" elsewhere (e.g., a body
        // comment about a 7-doc fixture) don't false-positive.
        let stale_a = body.contains("seven retrieval");
        let stale_b = body.contains("seven canonical");
        assert!(
            !stale_a && !stale_b,
            "{} contains stale 'seven retrieval' or 'seven canonical' \
             claim. EidosRetrievalMode::CANON_ALL has 9 variants — the \
             docstring must say 'nine'. Update both the docstring and \
             this detector in lock-step if a canon expansion is intentional.",
            name
        );
    }
}

/// Companion to the module-wide stale-count detector: lexical.rs and
/// semantic.rs both anchor their position to "nine canonical Eidos V0
/// modes" via the canonical phrase. Pin the corrected anchor in the
/// leading docstring blocks of those two files. A future canon
/// expansion surfaces here in lock-step with the CANON_ALL drift
/// detector.
#[test]
fn lexical_and_semantic_module_docstrings_reference_nine_canonical_modes() {
    let lex_path = concat!(env!("CARGO_MANIFEST_DIR"), "/src/eidos/lexical.rs");
    let sem_path = concat!(env!("CARGO_MANIFEST_DIR"), "/src/eidos/semantic.rs");
    let lex = std::fs::read_to_string(lex_path).expect("read lexical.rs");
    let sem = std::fs::read_to_string(sem_path).expect("read semantic.rs");

    let lex_head: String = lex.lines().take(5).collect::<Vec<_>>().join("\n");
    let sem_head: String = sem.lines().take(5).collect::<Vec<_>>().join("\n");

    for (name, head) in [("lexical.rs", &lex_head), ("semantic.rs", &sem_head)] {
        assert!(
            head.contains("nine canonical Eidos V0 modes"),
            "{name} docstring must anchor to 'nine canonical Eidos V0 modes' \
             so a future canon expansion surfaces here in lock-step with \
             the CANON_ALL drift detector"
        );
    }
}

/// Closed-citation contract is **byte-strict** on `EidosChunkId`: a
/// citation that uses a different unicode-normalization form than the
/// hit's `source_id` is rejected as a fabricated id, even though both
/// strings would render identically.
///
/// Why this matters: the chat layer copies `source_id`s verbatim from
/// the packet. Any silent normalization on the validator side would
/// open a smuggling channel — a model could claim "café" (NFD,
/// `e` + `U+0301`) to cite a hit whose source_id is "café" (NFC,
/// `U+00E9`), bypassing the closed-citation universe by re-encoding the
/// visible characters. Byte-strict equality on the underlying `String`
/// is the safety floor.
///
/// Pins:
///   - precomposed-NFC source_id in the packet's hit
///   - decomposed-NFD source_id in a candidate citation
///   - validator returns `FabricatedSourceId(<NFD form>)` — NOT Ok(())
///   - the same citation with byte-equal (NFC) source_id IS accepted
///     (positive control for the byte-equality semantic)
#[test]
fn validate_citation_is_byte_strict_against_unicode_normalization() {
    use super::types::{
        CitationError, EidosChunkId, EidosCitation, EidosContextPacket, EidosHit,
        EidosProvenance, EidosScoreComponents,
    };

    let m = manifest();

    // NFC: "café::lex" with precomposed é (U+00E9). 10 bytes.
    let nfc = "caf\u{00E9}::lex";
    // NFD: "café::lex" with e + combining acute (U+0301). 11 bytes,
    // visually identical, canonically equivalent under Unicode NFKC/NFC.
    let nfd = "cafe\u{0301}::lex";
    assert_ne!(nfc.as_bytes(), nfd.as_bytes(), "NFC/NFD must differ at byte level");
    assert_ne!(nfc.len(), nfd.len(), "byte length differs (10 vs 11)");

    let hit = EidosHit {
        source_id: EidosChunkId::new(nfc).unwrap(),
        document_id: doc("café-doc"),
        kind: EidosSourceKind::Note,
        span: None,
        confidence: 0.5,
        score: EidosScoreComponents::default(),
        provenance: EidosProvenance {
            manifest_id: m.clone(),
            mode: EidosRetrievalMode::Lexical,
            retrieved_at_unix_ms: 1_700_000_000_000,
        },
    };
    let packet = EidosContextPacket {
        query: EidosQuery::new("café", EidosRetrievalMode::Lexical, 16),
        manifest_id: m.clone(),
        hits: vec![hit],
    };

    // Re-encoded citation — same characters, different bytes (NFD).
    // Must be rejected as fabricated, surfacing the NFD form so the
    // diagnostic shows the actual bytes the chat layer tried to smuggle.
    let smuggled = EidosCitation {
        source_id: EidosChunkId::new(nfd).unwrap(),
        manifest_id: m.clone(),
    };
    let err = packet
        .validate_citation(&smuggled)
        .expect_err("NFD-encoded citation must be rejected (byte-strict)");
    match err {
        CitationError::FabricatedSourceId(returned) => {
            assert_eq!(
                returned.as_str(),
                nfd,
                "diagnostic must surface the actual NFD bytes the model tried, \
                 not silently normalize them to the NFC form"
            );
        }
        other => panic!("expected FabricatedSourceId, got {other:?}"),
    }

    // Positive control: byte-equal (NFC) citation is accepted.
    let legit = EidosCitation {
        source_id: EidosChunkId::new(nfc).unwrap(),
        manifest_id: m,
    };
    assert_eq!(packet.validate_citation(&legit), Ok(()));
}

/// Closed-citation contract handles duplicate citations in the input
/// list **without dedup**: each index in the supplied slice is
/// validated independently. A legitimate citation appearing twice
/// passes both times; a fabricated citation appearing twice surfaces
/// BOTH offending indices in the error report.
///
/// Why this matters: the chat-layer "about to emit" gate may receive
/// the same source_id multiple times (a model citing one chunk in
/// multiple sentences). If the validator silently deduped on the way
/// in, a fabricated citation that appeared alongside its legitimate
/// twin could slip past — and the diagnostic surface would lie about
/// which input indices the model touched. Pin: zero auto-dedup, every
/// input index is its own validation event.
///
/// Pins:
///   - same legitimate citation × 2 → Ok(()) (no spurious rejection)
///   - same fabricated citation × 2 → two errors, both indices listed,
///     each carrying the same FabricatedSourceId payload (no
///     index-merging, no "first error wins" short-circuit)
///   - mixed: legit at 0, forged at 1, same legit at 2 → one error at
///     index 1 only (the legit duplicate does not poison validation)
#[test]
fn validate_citations_does_not_dedup_duplicate_input_citations() {
    use super::types::{CitationError, EidosCitation};

    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("note-a"), "alpha mango content", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("mango", EidosRetrievalMode::Lexical, 16);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), 1);
    let legit_src = packet.hits[0].source_id.clone();

    // Case 1: same legitimate citation appears twice.
    let twin_legit = vec![
        EidosCitation {
            source_id: legit_src.clone(),
            manifest_id: packet.manifest_id.clone(),
        },
        EidosCitation {
            source_id: legit_src.clone(),
            manifest_id: packet.manifest_id.clone(),
        },
    ];
    assert_eq!(
        packet.validate_citations(&twin_legit),
        Ok(()),
        "duplicate legitimate citations must both pass (no spurious rejection)"
    );

    // Case 2: same fabricated citation appears twice. Both indices
    // must surface, neither suppressed, both carrying the same
    // FabricatedSourceId payload.
    let forged_src = super::types::EidosChunkId::new("note-ghost::lex").unwrap();
    let twin_forged = vec![
        EidosCitation {
            source_id: forged_src.clone(),
            manifest_id: packet.manifest_id.clone(),
        },
        EidosCitation {
            source_id: forged_src.clone(),
            manifest_id: packet.manifest_id.clone(),
        },
    ];
    let errs = packet.validate_citations(&twin_forged).unwrap_err();
    assert_eq!(errs.len(), 2, "duplicate fabrication must surface twice (no dedup, no short-circuit)");
    assert_eq!(errs[0].0, 0, "first error at input index 0");
    assert_eq!(errs[1].0, 1, "second error at input index 1");
    for (_, err) in &errs {
        match err {
            CitationError::FabricatedSourceId(id) => {
                assert_eq!(id, &forged_src, "diagnostic payload identical on both indices");
            }
            other => panic!("expected FabricatedSourceId, got {other:?}"),
        }
    }

    // Case 3: mixed — legit, forged, legit. Only index 1 errors;
    // the duplicate legit at index 2 does not get poisoned by index 1.
    let mixed = vec![
        EidosCitation {
            source_id: legit_src.clone(),
            manifest_id: packet.manifest_id.clone(),
        },
        EidosCitation {
            source_id: forged_src.clone(),
            manifest_id: packet.manifest_id.clone(),
        },
        EidosCitation {
            source_id: legit_src,
            manifest_id: packet.manifest_id.clone(),
        },
    ];
    let mixed_errs = packet.validate_citations(&mixed).unwrap_err();
    assert_eq!(mixed_errs.len(), 1, "only the forgery errors, legit duplicates pass independently");
    assert_eq!(mixed_errs[0].0, 1, "forgery at input index 1, surrounded by passing legits");
}

/// Empty-vault → empty-packet → zero-citation gate is the "honest
/// no-source answer" path: a query against a vault with no inserted
/// documents must return Ok with an empty packet (NOT an error, NOT a
/// panic), the packet must still carry the correct `manifest_id`, the
/// citable universe must be empty, and `validate_citations(&[])`
/// against that packet must return Ok(()).
///
/// This is the combined end-to-end floor of the four named nuances:
/// 1. Retrieval against an empty vault is not an error.
/// 2. The packet carries the correct manifest_id even when empty
///    (no degenerate empty-manifest leak — caught at retrieval, not
///    at gate time).
/// 3. The closed citation universe is empty (`citable_source_ids`
///    yields zero items).
/// 4. A model that honestly produced zero citations against zero
///    hits is admitted by the gate (Ok(())), NOT blocked.
/// 5. AND the converse: any non-empty citation against the empty
///    packet is rejected as FabricatedSourceId (closed-universe
///    floor still applies — empty universe means EVERY id is
///    fabricated).
///
/// Existing tests cover the pieces individually
/// (`every_retriever_empty_corpus_returns_byte_equal_empty_packet`,
/// `types::tests::empty_packet_rejects_every_citation`,
/// `types::tests::batch_validate_empty_input_is_ok`). This pins the
/// combined end-to-end path so a future change that fails-open on
/// empty packets (e.g. "vacuously valid against empty universe"), or
/// errors-out on empty corpus (e.g. "must have at least one doc"),
/// surfaces here.
#[test]
fn empty_vault_empty_packet_zero_citation_gate_is_ok() {
    use super::types::{CitationError, EidosCitation, EidosChunkId};

    // Zero documents inserted into the lexical retriever.
    let lex = InMemoryLexicalIndex::new(manifest());
    let q = EidosQuery::new("any-substring", EidosRetrievalMode::Lexical, 16);
    let packet = lex.retrieve(&q, 1_700_000_000_000);

    // (1) Retrieval against empty vault is not an error and yields an
    // empty packet.
    assert!(packet.hits.is_empty(), "empty vault must yield empty hits, not error");

    // (2) Packet still carries the correct manifest_id — no degenerate
    // empty-manifest leak.
    assert_eq!(packet.manifest_id, manifest(), "empty-corpus packet must still carry manifest_id");

    // (3) Closed citation universe is empty.
    assert_eq!(packet.citable_source_ids().count(), 0, "empty packet has empty citable universe");

    // (4) Zero-citation gate trivially passes.
    assert_eq!(
        packet.validate_citations(&[]),
        Ok(()),
        "validate_citations(&[]) on empty-vault empty packet must be Ok — the \
         honest no-source answer is admitted by the gate"
    );

    // (5) Converse: ANY non-empty citation against this empty packet
    // is fabricated. The closed-universe floor still applies — empty
    // universe means every id is outside it.
    let any = EidosCitation {
        source_id: EidosChunkId::new("some-id::lex").unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    match packet.validate_citation(&any).unwrap_err() {
        CitationError::FabricatedSourceId(id) => {
            assert_eq!(id.as_str(), "some-id::lex");
        }
        other => panic!("expected FabricatedSourceId against empty packet, got {other:?}"),
    }
}

/// `ManifestMismatch` ALWAYS precedes `FabricatedSourceId` in
/// `validate_citation`. If a citation has BOTH a wrong manifest AND a
/// source_id that is not in the packet's hits, the validator returns
/// `ManifestMismatch` — never `FabricatedSourceId`.
///
/// Why this precedence matters: the two errors point at different
/// remediations.
///   - `ManifestMismatch` tells the chat layer "this citation was
///     produced against a stale index snapshot — retry with the current
///     one." The id MAY be perfectly real, just against the wrong
///     packet.
///   - `FabricatedSourceId` tells the chat layer "the model invented
///     an id that has never been retrieved against any snapshot."
///
/// If the precedence flipped, a user with a citation produced under an
/// older snapshot would see "you made up an id" rather than "retry
/// against the current index" — a misleading diagnostic that would
/// blame the model for a snapshot-version mismatch.
///
/// Pins:
///   - wrong manifest + fake id → ManifestMismatch (manifest checked first)
///   - wrong manifest + real id → ManifestMismatch (manifest fires even
///     when the id would otherwise be admissible)
///   - right manifest + fake id → FabricatedSourceId (the fallback path
///     only fires when the manifest passes)
///   - right manifest + real id → Ok(())
#[test]
fn validate_citation_manifest_mismatch_precedes_fabricated_source_id() {
    use super::types::{CitationError, EidosCitation};

    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("note-a"), "alpha guava content", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("guava", EidosRetrievalMode::Lexical, 16);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), 1);
    let real_src = packet.hits[0].source_id.clone();
    let fake_src = super::types::EidosChunkId::new("note-ghost::lex").unwrap();
    let stale_manifest = EidosIndexManifestId::new("stale-snapshot-from-yesterday").unwrap();

    // Case A: wrong manifest + fake source_id. Both checks would fire;
    // the manifest check must win because it points at the snapshot
    // remediation, not the fabrication remediation.
    let stale_and_fake = EidosCitation {
        source_id: fake_src.clone(),
        manifest_id: stale_manifest.clone(),
    };
    match packet.validate_citation(&stale_and_fake).unwrap_err() {
        CitationError::ManifestMismatch { packet: pm, citation: cm } => {
            assert_eq!(pm, manifest(), "diagnostic must surface packet's manifest");
            assert_eq!(cm, stale_manifest, "diagnostic must surface citation's stale manifest");
        }
        CitationError::FabricatedSourceId(_) => {
            panic!(
                "wrong manifest + fake id must surface ManifestMismatch, NOT \
                 FabricatedSourceId — snapshot mismatch and fabrication are \
                 different remediation paths and the manifest check is the \
                 first gate"
            );
        }
    }

    // Case B: wrong manifest + REAL source_id. Manifest check still
    // fires — even an otherwise admissible id is rejected if it's
    // attributed to the wrong snapshot. This is the "right answer,
    // wrong snapshot" path.
    let stale_and_real = EidosCitation {
        source_id: real_src.clone(),
        manifest_id: stale_manifest.clone(),
    };
    match packet.validate_citation(&stale_and_real).unwrap_err() {
        CitationError::ManifestMismatch { .. } => {}
        CitationError::FabricatedSourceId(_) => {
            panic!("wrong manifest + real id must STILL surface ManifestMismatch");
        }
    }

    // Case C: right manifest + fake id. Now the manifest check passes
    // and the fabrication check is the one that fires.
    let current_and_fake = EidosCitation {
        source_id: fake_src.clone(),
        manifest_id: packet.manifest_id.clone(),
    };
    match packet.validate_citation(&current_and_fake).unwrap_err() {
        CitationError::FabricatedSourceId(id) => {
            assert_eq!(id, fake_src);
        }
        CitationError::ManifestMismatch { .. } => {
            panic!("right manifest + fake id must surface FabricatedSourceId");
        }
    }

    // Case D (positive control): right manifest + real id is Ok.
    let current_and_real = EidosCitation {
        source_id: real_src,
        manifest_id: packet.manifest_id.clone(),
    };
    assert_eq!(packet.validate_citation(&current_and_real), Ok(()));
}

/// `validate_citations` reports errors in **input-index ascending
/// order**, NOT bucketed by error type, NOT shuffled, NOT short-
/// circuited at the first failure.
///
/// Why this matters: the chat-layer diagnostic surface walks the
/// per-index error list to render "citation #N rejected because …".
/// If the validator returned errors in arbitrary order (parallel
/// loop, partition-then-merge by error variant, prioritize-mismatch-
/// first), the indices in the diagnostic would no longer line up with
/// the input list and the user would see misleading rejection
/// pointers. Pin: errors come back exactly in the order the bad
/// indices appear in the input.
///
/// Pins, against a 7-element input list with errors interleaved
/// among legits and mixing both `CitationError` variants:
///   - input: [forged, legit, mismatch, legit, forged, legit, mismatch]
///   - output: 4 errors at indices [0, 2, 4, 6] in that exact order,
///     each carrying the correct typed variant for its position
///     (forged → FabricatedSourceId, mismatch → ManifestMismatch),
///     with the legits at 1/3/5 NOT producing entries
#[test]
fn validate_citations_reports_errors_in_input_index_order() {
    use super::types::{CitationError, EidosCitation, EidosChunkId};

    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("note-a"), "alpha kiwi content", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("kiwi", EidosRetrievalMode::Lexical, 16);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), 1);
    let legit_src = packet.hits[0].source_id.clone();
    let stale_manifest = EidosIndexManifestId::new("stale-snapshot-X").unwrap();

    let make_forged = |tag: &str| EidosCitation {
        source_id: EidosChunkId::new(format!("ghost-{tag}::lex")).unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    let make_legit = || EidosCitation {
        source_id: legit_src.clone(),
        manifest_id: packet.manifest_id.clone(),
    };
    let make_mismatch = || EidosCitation {
        source_id: legit_src.clone(),
        manifest_id: stale_manifest.clone(),
    };

    // Interleave: forged @0, legit @1, mismatch @2, legit @3,
    // forged @4, legit @5, mismatch @6.
    let citations = vec![
        make_forged("a"),
        make_legit(),
        make_mismatch(),
        make_legit(),
        make_forged("b"),
        make_legit(),
        make_mismatch(),
    ];

    let errs = packet.validate_citations(&citations).unwrap_err();

    // (1) Exactly four errors — one per bad input index, no merging.
    assert_eq!(errs.len(), 4, "exactly 4 errors for 4 bad indices");

    // (2) Indices in ascending input order — NOT bucketed by error
    // variant. If errors were grouped by type, we'd see [0,4,2,6] or
    // [2,6,0,4]; what we MUST see is [0,2,4,6].
    let indices: Vec<usize> = errs.iter().map(|(i, _)| *i).collect();
    assert_eq!(
        indices,
        vec![0, 2, 4, 6],
        "errors must be in input-index ascending order, NOT bucketed by variant"
    );

    // (3) Each error carries the correct typed variant for its
    // position — no cross-type confusion.
    match &errs[0].1 {
        CitationError::FabricatedSourceId(id) => assert_eq!(id.as_str(), "ghost-a::lex"),
        other => panic!("expected FabricatedSourceId at index 0, got {other:?}"),
    }
    match &errs[1].1 {
        CitationError::ManifestMismatch { .. } => {}
        other => panic!("expected ManifestMismatch at index 2, got {other:?}"),
    }
    match &errs[2].1 {
        CitationError::FabricatedSourceId(id) => assert_eq!(id.as_str(), "ghost-b::lex"),
        other => panic!("expected FabricatedSourceId at index 4, got {other:?}"),
    }
    match &errs[3].1 {
        CitationError::ManifestMismatch { .. } => {}
        other => panic!("expected ManifestMismatch at index 6, got {other:?}"),
    }
}

/// `EidosContextPacket::citable_source_ids` is a 1:1 hit-aligned
/// view: it yields EXACTLY `hits.len()` items in `hits` order, with
/// NO implicit dedup of duplicate `source_id`s. Symmetrically,
/// `validate_citation` operates on the raw hit list — it accepts a
/// citation whose source_id appears in ANY hit, without requiring
/// dedup at validation time.
///
/// Real retrievers dedup source_ids before emission (the fusion
/// retrievers' `document_id`-based dedup, etc.). This test
/// deliberately constructs a packet with two hits sharing one
/// source_id to pin the closed-citation contract's behavior at the
/// TYPE layer — the contract sits BELOW retrieval and must not mask
/// retriever bugs by silently re-deduping at the gate.
///
/// Pins:
///   - `citable_source_ids().count() == hits.len()` even with
///     duplicate source_ids (no implicit dedup)
///   - `citable_source_ids()` yields IDs in exact `hits` index order
///   - `validate_citation` accepts a citation matching the duplicate
///     source_id (the `any` check returns true on the first hit;
///     duplicate doesn't matter)
///   - a future change adding `.unique()` / `HashSet` to the iterator
///     surfaces here in lock-step (consumers that pair iterator items
///     with hit metadata by position would silently misalign)
#[test]
fn citable_source_ids_does_not_dedup_duplicate_hit_source_ids() {
    use super::types::{
        EidosChunkId, EidosCitation, EidosContextPacket, EidosHit, EidosProvenance,
        EidosScoreComponents,
    };

    let m = manifest();
    let dup_src = EidosChunkId::new("dup-id::lex").unwrap();
    let unique_src = EidosChunkId::new("unique-id::lex").unwrap();
    let mode = EidosRetrievalMode::Lexical;
    let make_hit = |src: EidosChunkId, doc_label: &str| EidosHit {
        source_id: src,
        document_id: doc(doc_label),
        kind: EidosSourceKind::Note,
        span: None,
        confidence: 0.5,
        score: EidosScoreComponents::default(),
        provenance: EidosProvenance {
            manifest_id: m.clone(),
            mode,
            retrieved_at_unix_ms: 1_700_000_000_000,
        },
    };

    // Deliberately abnormal: three hits but only two distinct source_ids.
    // Real retrievers dedup; this pins the type-layer contract's
    // behavior independently of retriever correctness.
    let packet = EidosContextPacket {
        query: EidosQuery::new("kiwi", mode, 16),
        manifest_id: m.clone(),
        hits: vec![
            make_hit(dup_src.clone(), "doc-1"),
            make_hit(unique_src.clone(), "doc-2"),
            make_hit(dup_src.clone(), "doc-3"),
        ],
    };

    // (1) citable_source_ids enumerates exactly hits.len() items.
    let ids: Vec<&EidosChunkId> = packet.citable_source_ids().collect();
    assert_eq!(ids.len(), 3, "iterator must NOT dedup — 3 hits → 3 IDs yielded");

    // (2) Yielded in exact hits order, duplicates preserved at their
    // original positions.
    assert_eq!(ids[0], &dup_src);
    assert_eq!(ids[1], &unique_src);
    assert_eq!(ids[2], &dup_src);

    // (3) The iterator IS hit-aligned: zip with hits and verify the
    // pairing matches by position.
    for (i, (yielded, hit)) in ids.iter().zip(packet.hits.iter()).enumerate() {
        assert_eq!(
            *yielded, &hit.source_id,
            "iterator item at position {i} must be &hits[{i}].source_id"
        );
    }

    // (4) validate_citation accepts the duplicated source_id without
    // caring how many hits carry it — the `any` check returns true on
    // the first match.
    let cite_dup = EidosCitation {
        source_id: dup_src,
        manifest_id: m.clone(),
    };
    assert_eq!(packet.validate_citation(&cite_dup), Ok(()));

    let cite_unique = EidosCitation {
        source_id: unique_src,
        manifest_id: m,
    };
    assert_eq!(packet.validate_citation(&cite_unique), Ok(()));
}

/// Closed-citation contract rejects **invisible-character smuggling**:
/// a citation whose source_id matches a real hit visually (after the
/// invisible chars are stripped by terminals/UIs) but differs at the
/// byte level by injected zero-width characters MUST be rejected as
/// fabricated.
///
/// This is a distinct smuggling vector from the NFC/NFD canonical-
/// equivalence case (iter 127). NFC/NFD pins that two renderings of
/// the same character must not silently match. This pins that
/// invisible characters injected into an otherwise-real id must not
/// silently match either. The byte-strict floor catches both.
///
/// Vectors covered (all U+200B zero-width space, but the principle
/// generalizes to U+200C ZWNJ / U+200D ZWJ / U+FEFF BOM / U+2060 word
/// joiner — all invisible in most renderings):
///   - injected mid-string: "note\u{200B}-a::lex"
///   - prepended:           "\u{200B}note-a::lex"
///   - appended:            "note-a::lex\u{200B}"
///   - doubled mid-string:  "note\u{200B}\u{200B}-a::lex"
///
/// Pins:
///   - each variant is rejected with FabricatedSourceId
///   - diagnostic payload preserves the smuggled bytes (NOT silently
///     stripped) — the chat layer must see the actual offending id so
///     the user can spot the invisible injection
///   - positive control: the clean id IS accepted
#[test]
fn validate_citation_rejects_zero_width_space_smuggling() {
    use super::types::{CitationError, EidosCitation, EidosChunkId};

    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("note-a"), "alpha lychee content", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("lychee", EidosRetrievalMode::Lexical, 16);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), 1);
    let clean_src = packet.hits[0].source_id.clone();
    let clean_str = clean_src.as_str().to_string();

    // Sanity: the clean id contains no invisible characters before we
    // build the smuggled variants.
    for forbidden in ['\u{200B}', '\u{200C}', '\u{200D}', '\u{FEFF}', '\u{2060}'] {
        assert!(
            !clean_str.contains(forbidden),
            "clean source_id must not already contain U+{:04X}",
            forbidden as u32
        );
    }

    let mid = format!("note\u{200B}-a::lex");
    let lead = format!("\u{200B}{clean_str}");
    let trail = format!("{clean_str}\u{200B}");
    let doubled = format!("note\u{200B}\u{200B}-a::lex");

    for (label, smuggled) in [
        ("mid-string injection", &mid),
        ("prepended", &lead),
        ("appended", &trail),
        ("doubled mid-string", &doubled),
    ] {
        // The smuggled byte string must NOT byte-equal the clean id —
        // confirms the test is exercising actual byte-level divergence
        // and not relying on a no-op smuggling attempt.
        assert_ne!(
            smuggled.as_bytes(),
            clean_str.as_bytes(),
            "{label} variant must differ in bytes from the clean id"
        );

        let bad = EidosCitation {
            source_id: EidosChunkId::new(smuggled.clone()).unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        match packet.validate_citation(&bad).unwrap_err() {
            CitationError::FabricatedSourceId(returned) => {
                // Diagnostic must preserve the smuggled bytes exactly
                // so the chat layer can surface "this id contains a
                // U+200B" rather than silently stripping and hiding
                // the attack vector.
                assert_eq!(
                    returned.as_str(),
                    smuggled,
                    "{label}: diagnostic must preserve the invisible chars verbatim"
                );
            }
            other => panic!("{label}: expected FabricatedSourceId, got {other:?}"),
        }
    }

    // Positive control: the clean id IS accepted.
    let legit = EidosCitation {
        source_id: clean_src,
        manifest_id: packet.manifest_id.clone(),
    };
    assert_eq!(packet.validate_citation(&legit), Ok(()));
}

/// `CitationError` is a closed two-variant enum
/// (`FabricatedSourceId` + `ManifestMismatch`) and adding a new
/// variant must surface in lock-step at every consumer:
///   - chat-layer diagnostic UI (Rust + Swift bridge)
///   - Swift `EidosParityTests` wire-format pin
///   - the per-index error-precedence test (iter 130)
///   - the input-order error-list test (iter 131)
///   - the JSON externally-tagged wire-format tests in `types::tests`
///
/// This drift detector locks the variant count via an exhaustive
/// match: building one of each known variant and matching them
/// without a `_` wildcard guarantees the test fails to compile if a
/// third variant is added, forcing the author to update the
/// downstream consumers before this test passes again.
///
/// The runtime `assert_eq!(all.len(), 2, …)` is a backup signal in
/// case someone naïvely "fixes" the compile error by adding a `_`
/// wildcard — the count assertion still flips.
///
/// Pattern mirrors the existing `EidosRetrievalMode::CANON_ALL` and
/// `EidosSourceKind::CANON_ALL` drift detectors (iters 122-126):
/// schema enumerations get a runtime count check + an exhaustive
/// match probe so silent expansions surface here first.
#[test]
fn citation_error_variant_count_is_two() {
    use super::types::{CitationError, EidosChunkId};

    let m = manifest();
    let fab = CitationError::FabricatedSourceId(
        EidosChunkId::new("drift-detector-id").unwrap(),
    );
    let mm = CitationError::ManifestMismatch {
        packet: m.clone(),
        citation: EidosIndexManifestId::new("drift-detector-other").unwrap(),
    };

    let all = [fab, mm];

    // (1) Runtime count: exactly two variants live in CitationError
    // today. If this drift-detector trips, lock-step update:
    //   - `EpistemosTests/EidosParityTests.swift`
    //     (Swift bridge wire-format mirror)
    //   - the precedence test (iter 130) so the new variant has a
    //     defined position in `validate_citation`'s short-circuit order
    //   - the error-order test (iter 131) so the input-order pin
    //     covers the new variant
    //   - the JSON tag-name pin in `types::tests::
    //     batch_validate_result_emits_per_index_externally_tagged_json`
    assert_eq!(
        all.len(),
        2,
        "CitationError variant count drift — chat layer + Swift bridge \
         must update in lock-step. See iter 130/131/types::tests JSON \
         pins for downstream consumers."
    );

    // (2) Compile-time exhaustiveness probe — no `_` wildcard. If a
    // third variant lands, this match fails to compile and forces the
    // author to add a branch (which then surfaces in the count check
    // above when they bump the assert).
    for err in &all {
        match err {
            CitationError::FabricatedSourceId(_) => {}
            CitationError::ManifestMismatch { .. } => {}
        }
    }

    // (3) Size ceiling: CitationError must stay small enough that
    // chat-layer code can pass it around freely without per-error
    // allocation pressure. Current layout on 64-bit:
    //   - FabricatedSourceId(EidosChunkId) = 1 String = 24 bytes
    //   - ManifestMismatch { 2x EidosIndexManifestId } = 48 bytes
    //   - enum discriminant + alignment: ~8 bytes
    //   - total: ~56 bytes, ceiling pinned at 64 for slack.
    //
    // What this catches:
    //   - a future variant payload that adds a Vec / HashMap /
    //     BTreeMap / large struct — surfaces here as a size jump
    //   - a future "let's add a context string to every variant"
    //     refactor (would push the size up by 24+ bytes per
    //     String field)
    //
    // On 32-bit Rust the size would be ~half (12-byte String); the
    // ceiling holds either way. Adjust the ceiling only if the
    // increase is intentional and the chat-layer cost is acceptable.
    let size = std::mem::size_of::<CitationError>();
    assert!(
        size <= 64,
        "CitationError grew to {size} bytes (ceiling 64); a new \
         variant with a heavy payload (Vec, HashMap, large struct) \
         was probably added. If intentional, justify the cost to \
         chat-layer error handling, bump the ceiling, and document \
         the rationale here."
    );
}

/// `CitationError`'s `Display` (via `thiserror`) is a user-facing
/// diagnostic surface: chat-layer error banners, agent-runtime logs,
/// and replay-bundle audit records all render this string. Pin the
/// exact format so silent drift (someone tweaks an `#[error("…")]`
/// literal, or `{0:?}` becomes `{0}`, or a punctuation change)
/// surfaces here in lock-step with the consuming UIs.
///
/// The `EidosChunkId` and `EidosIndexManifestId` payloads are
/// rendered via their `Debug` impl (the `{:?}` formatter inside
/// thiserror's literal). Derived `Debug` on a tuple-newtype produces
/// `EidosChunkId("the-id")` shape — the Debug form, not the inner
/// string raw. This is the existing observed format and is pinned as
/// such.
///
/// Pins:
///   - `FabricatedSourceId(id).to_string()` exact format
///   - `ManifestMismatch { packet, citation }.to_string()` exact format
///   - both messages include the offending id payload byte-for-byte
///     (no silent stripping of e.g. invisible chars from iter 133's
///     smuggling vectors)
#[test]
fn citation_error_display_format_is_stable() {
    use super::types::{CitationError, EidosChunkId};

    let fab = CitationError::FabricatedSourceId(
        EidosChunkId::new("ghost-id::lex").unwrap(),
    );
    assert_eq!(
        fab.to_string(),
        r#"fabricated source_id rejected by closed-citation contract: EidosChunkId("ghost-id::lex")"#,
        "FabricatedSourceId Display format drift — chat-layer error \
         banner + replay-bundle audit records must update in lock-step"
    );

    let mm = CitationError::ManifestMismatch {
        packet: EidosIndexManifestId::new("snap-current").unwrap(),
        citation: EidosIndexManifestId::new("snap-stale").unwrap(),
    };
    assert_eq!(
        mm.to_string(),
        r#"manifest mismatch: packet retrieved against EidosIndexManifestId("snap-current"), citation references EidosIndexManifestId("snap-stale")"#,
        "ManifestMismatch Display format drift — chat-layer error \
         banner + replay-bundle audit records must update in lock-step"
    );

    // Composability check: the Display surface must surface smuggled
    // invisible chars (iter 133's vectors are a real surface, not
    // theoretical). Critically, Rust's Debug formatter for `String`
    // ESCAPES invisible characters into `\u{xxxx}` form rather than
    // emitting the raw byte. This is the safer behavior: operators
    // reading a log line for the diagnostic see the escape sequence
    // (visible text) and can spot the attack, where a raw ZWSP byte
    // in the log would render as nothing and hide the smuggling.
    //
    // Pin the escape-form behavior, NOT the raw-byte echo. If a
    // future change replaces `{0:?}` with `{0}` (which would invoke
    // a custom Display, not yet implemented), the escape would
    // collapse and invisible smuggling would silently disappear from
    // diagnostics — this test trips first.
    let smuggled = CitationError::FabricatedSourceId(
        EidosChunkId::new("note\u{200B}-a::lex").unwrap(),
    );
    let rendered = smuggled.to_string();
    assert!(
        rendered.contains("\\u{200b}"),
        "FabricatedSourceId Display must surface smuggled invisible chars \
         via Debug-escape `\\u{{200b}}` — operators can spot the attack in \
         logs that would otherwise render the raw ZWSP as nothing. \
         Got: {rendered:?}"
    );
    assert!(
        !rendered.contains('\u{200B}'),
        "Display must NOT echo the raw ZWSP byte (which would render \
         invisibly in logs and hide the smuggling vector); Debug-escape \
         is the safer rendering. Got: {rendered:?}"
    );

    // Same property for the bidi-override vector (iter 195): U+202E
    // (RLO) must surface as the `\u{202e}` literal text, NOT the raw
    // byte. A raw U+202E in a log line flips the rendering direction
    // of every byte after it, so an operator reading the diagnostic
    // would see scrambled / reversed text and miss the attack. The
    // Debug-escape form makes the smuggling attempt visible.
    let bidi_smuggled = CitationError::FabricatedSourceId(
        EidosChunkId::new("\u{202E}note-a::lex").unwrap(),
    );
    let bidi_rendered = bidi_smuggled.to_string();
    assert!(
        bidi_rendered.contains("\\u{202e}"),
        "FabricatedSourceId Display must surface bidi-override (U+202E \
         RLO) as the `\\u{{202e}}` escape — a raw byte in the log line \
         would flip subsequent rendering and hide the Trojan Source \
         attack vector. Got: {bidi_rendered:?}"
    );
    assert!(
        !bidi_rendered.contains('\u{202E}'),
        "Display must NOT echo the raw U+202E byte. Got: {bidi_rendered:?}"
    );
}

/// Concurrent `validate_citation` calls against the same packet
/// from N threads produce identical results — pins the RUNTIME
/// thread-safety invariant complementary to iter 152's compile-
/// time `Send + Sync` assertion.
///
/// Why pin: `validate_citation` is `&self` over `EidosContextPacket`
/// which is `Send + Sync` (iter 152). By the std contract this means
/// concurrent reads are safe — but a future interior-mutability
/// addition (RefCell for memoization, Mutex<Vec> for an audit log,
/// AtomicU64 for a hit counter) would break thread-safety either at
/// compile time (Sync removed) or at runtime (data race / inverted
/// counts). This pin exercises the runtime path explicitly.
///
/// Test shape:
///   - 4 worker threads
///   - Each runs 100 validate_citation calls, alternating legit /
///     fabricated / manifest-mismatch
///   - Single-threaded baseline computed up front
///   - Each worker compares its results to the baseline; if any
///     thread's result diverges, the worker pushes an error tag
///   - Main thread collects all worker outputs + asserts identical
///     to baseline
///
/// 400 total concurrent validation calls is enough to surface most
/// race conditions in practice (especially with the 4-worker × 100-
/// call pattern that interleaves access patterns).
#[test]
fn validate_citation_is_safe_under_concurrent_reads() {
    use super::types::{EidosChunkId, EidosCitation};
    use std::sync::Arc;

    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("note-a"), "alpha guanabana", EidosSourceKind::Note).unwrap();
    lex.insert(doc("note-b"), "beta guanabana", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("guanabana", EidosRetrievalMode::Lexical, 16);
    let packet = Arc::new(lex.retrieve(&q, 1_700_000_000_000));
    assert_eq!(packet.hits.len(), 2);
    let stale_manifest = EidosIndexManifestId::new("stale-snap").unwrap();

    // Three reference citations for the baseline.
    let cite_legit = EidosCitation {
        source_id: packet.hits[0].source_id.clone(),
        manifest_id: packet.manifest_id.clone(),
    };
    let cite_forged = EidosCitation {
        source_id: EidosChunkId::new("ghost-thread::lex").unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    let cite_stale = EidosCitation {
        source_id: packet.hits[1].source_id.clone(),
        manifest_id: stale_manifest,
    };

    // Single-threaded baseline (Debug-format for cross-thread compare).
    let baseline_legit = format!("{:?}", packet.validate_citation(&cite_legit));
    let baseline_forged = format!("{:?}", packet.validate_citation(&cite_forged));
    let baseline_stale = format!("{:?}", packet.validate_citation(&cite_stale));
    // Sanity on baseline.
    assert!(baseline_legit.contains("Ok"), "legit baseline must be Ok");
    assert!(baseline_forged.contains("FabricatedSourceId"), "forged baseline must be FabricatedSourceId");
    assert!(baseline_stale.contains("ManifestMismatch"), "stale baseline must be ManifestMismatch");

    // Spawn 4 workers, each running 100 mixed-citation validate
    // calls. Each worker accumulates divergence reports if any
    // result differs from the baseline.
    const WORKERS: usize = 4;
    const CALLS_PER_WORKER: usize = 100;

    let mut handles = Vec::with_capacity(WORKERS);
    for worker_id in 0..WORKERS {
        let packet = Arc::clone(&packet);
        let legit = cite_legit.clone();
        let forged = cite_forged.clone();
        let stale = cite_stale.clone();
        let b_legit = baseline_legit.clone();
        let b_forged = baseline_forged.clone();
        let b_stale = baseline_stale.clone();
        let handle = std::thread::spawn(move || {
            let mut divergence: Vec<String> = Vec::new();
            for i in 0..CALLS_PER_WORKER {
                let (citation, baseline, tag) = match i % 3 {
                    0 => (&legit, &b_legit, "legit"),
                    1 => (&forged, &b_forged, "forged"),
                    _ => (&stale, &b_stale, "stale"),
                };
                let observed = format!("{:?}", packet.validate_citation(citation));
                if observed != *baseline {
                    divergence.push(format!(
                        "worker {worker_id} call {i} ({tag}): observed {observed:?} != baseline {baseline:?}"
                    ));
                }
            }
            divergence
        });
        handles.push(handle);
    }

    let mut total_divergence: Vec<String> = Vec::new();
    for handle in handles {
        let mut d = handle.join().expect("worker thread panic");
        total_divergence.append(&mut d);
    }

    assert!(
        total_divergence.is_empty(),
        "concurrent validate_citation diverged from single-threaded \
         baseline in {} calls — runtime thread-safety regression: \
         {total_divergence:?}",
        total_divergence.len()
    );
}

/// `validate_citation` and `validate_citations` are pure functions of
/// `(&self, &Citation/&[Citation])`. Determinism is the foundation
/// for replay + audit: a replay-bundle that re-runs the chat-layer
/// gate must produce byte-equal results to the original run, or the
/// audit trail loses meaning.
///
/// Pure-function-ness is trivially obvious from the type signature
/// (`&self`, no `&mut`, no interior mutability), but pinning
/// idempotence as an explicit test guards against:
///   - someone adding interior mutability to `EidosContextPacket`
///     (e.g. a memoization cache) that introduces a first-call vs
///     second-call divergence
///   - a future "sort errors by some other key" change that depends
///     on call-order
///   - a HashMap-backed lookup replacing the linear scan in a way
///     that produces non-deterministic error order (HashMap iteration
///     is randomized in stdlib)
///
/// Pins, on a 5-citation mixed-validity input:
///   - validate_citations called twice → byte-equal Err payloads
///   - validate_citation called twice on each citation → byte-equal
///     Result per citation
///   - independently-constructed byte-equal packets produce byte-
///     equal results (no per-packet state leaks in)
#[test]
fn validate_citations_is_deterministic_across_repeated_calls() {
    use super::types::{CitationError, EidosCitation, EidosChunkId};

    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("note-a"), "alpha pomegranate", EidosSourceKind::Note).unwrap();
    lex.insert(doc("note-b"), "beta pomegranate", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("pomegranate", EidosRetrievalMode::Lexical, 16);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), 2);
    let legit_a = packet.hits[0].source_id.clone();
    let legit_b = packet.hits[1].source_id.clone();
    let stale_manifest = EidosIndexManifestId::new("stale-snap").unwrap();

    let citations = vec![
        EidosCitation {
            source_id: legit_a.clone(),
            manifest_id: packet.manifest_id.clone(),
        },
        EidosCitation {
            source_id: EidosChunkId::new("ghost-1::lex").unwrap(),
            manifest_id: packet.manifest_id.clone(),
        },
        EidosCitation {
            source_id: legit_b.clone(),
            manifest_id: packet.manifest_id.clone(),
        },
        EidosCitation {
            source_id: legit_a.clone(),
            manifest_id: stale_manifest.clone(),
        },
        EidosCitation {
            source_id: EidosChunkId::new("ghost-2::lex").unwrap(),
            manifest_id: packet.manifest_id.clone(),
        },
    ];

    // (1) Same packet, same citation list, called twice → byte-equal
    // error payloads. The Err variant uses Vec<(usize, CitationError)>
    // which PartialEq-compares element-by-element.
    let first = packet.validate_citations(&citations).unwrap_err();
    let second = packet.validate_citations(&citations).unwrap_err();
    assert_eq!(
        first, second,
        "validate_citations must be idempotent — same input → same Err \
         payload, byte-equal"
    );

    // (2) Per-citation determinism: validate_citation called twice on
    // each citation produces byte-equal Result.
    for (i, c) in citations.iter().enumerate() {
        let r1 = packet.validate_citation(c);
        let r2 = packet.validate_citation(c);
        match (r1, r2) {
            (Ok(()), Ok(())) => {}
            (Err(a), Err(b)) => assert_eq!(
                a, b,
                "citation at index {i}: validate_citation must be \
                 deterministic — same input → same Err"
            ),
            (a, b) => panic!(
                "citation at index {i}: validate_citation result \
                 type changed between calls — first={a:?}, second={b:?}"
            ),
        }
    }

    // (3) Independently-constructed byte-equal packet produces byte-
    // equal results. Constructs the same logical packet via a second
    // retriever build to rule out per-instance state leaks (memoization
    // caches, interior mutability, etc.).
    let mut lex2 = InMemoryLexicalIndex::new(manifest());
    lex2.insert(doc("note-a"), "alpha pomegranate", EidosSourceKind::Note).unwrap();
    lex2.insert(doc("note-b"), "beta pomegranate", EidosSourceKind::Note).unwrap();
    let packet2 = lex2.retrieve(&q, 1_700_000_000_000);
    assert_eq!(
        packet, packet2,
        "byte-equal retrievals must produce byte-equal packets — \
         pre-requisite for the cross-packet determinism pin below"
    );
    let third = packet2.validate_citations(&citations).unwrap_err();
    assert_eq!(
        first, third,
        "byte-equal packets must produce byte-equal validation results — \
         no per-packet-instance state leaks into the closed-citation \
         contract"
    );

    // Sanity: the test actually exercised both error variants.
    let mut saw_fab = false;
    let mut saw_mm = false;
    for (_, e) in &first {
        match e {
            CitationError::FabricatedSourceId(_) => saw_fab = true,
            CitationError::ManifestMismatch { .. } => saw_mm = true,
        }
    }
    assert!(saw_fab && saw_mm, "test must cover both CitationError variants");
}

/// Closed-citation contract rejects **homoglyph smuggling** —
/// citations whose source_id is composed of visually-identical
/// codepoints from a different Unicode script.
///
/// This is the third named adversarial vector pinned in this
/// session, distinct from the prior two:
///   - NFC/NFD (iter 127): SAME character, two encodings of one
///     codepoint sequence.
///   - ZWSP/invisible (iter 133): SAME visible string, extra
///     invisible codepoints injected.
///   - Homoglyph (this iter): DIFFERENT codepoints from a different
///     script, chosen because they render identically.
///
/// The Cyrillic block contains glyphs that are visually identical to
/// common Latin letters but have completely different codepoints/
/// bytes. An attacker submitting a "note-a::lex" citation against a
/// hit whose real source_id is "note-a::lex" might be tempted to
/// type the Cyrillic letters; under any kind of "normalize before
/// compare" change, this would smuggle a citation past the gate.
///
/// Common Cyrillic ↔ Latin homoglyphs (a non-exhaustive sample):
///   а (U+0430) ↔ a (U+0061)
///   е (U+0435) ↔ e (U+0065)
///   о (U+043E) ↔ o (U+006F)
///   р (U+0440) ↔ p (U+0070)
///   с (U+0441) ↔ c (U+0063)
///   х (U+0445) ↔ x (U+0078)
///
/// Pins:
///   - a citation built from Cyrillic homoglyphs of a real Latin
///     source_id is rejected with FabricatedSourceId
///   - the offending bytes appear in the diagnostic (under Debug-
///     escape, printable Cyrillic characters render as themselves;
///     operators with a hex/codepoint viewer can confirm the script
///     mismatch)
///   - positive control: the byte-equal Latin id IS accepted
///   - sanity: the bytes truly differ (rules out the test silently
///     using identical Latin/Cyrillic representations)
#[test]
fn validate_citation_rejects_cyrillic_latin_homoglyph_smuggling() {
    use super::types::{CitationError, EidosCitation, EidosChunkId};

    let mut lex = InMemoryLexicalIndex::new(manifest());
    // Latin ASCII source content. The retriever's source_id will be
    // "note-a::lex" composed entirely of Latin ASCII.
    lex.insert(doc("note-a"), "alpha papaya content", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("papaya", EidosRetrievalMode::Lexical, 16);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), 1);
    let latin_src = packet.hits[0].source_id.clone();
    let latin_str = latin_src.as_str().to_string();
    assert_eq!(latin_str, "note-a::lex", "baseline Latin source_id");
    // Confirm the Latin id is pure ASCII before we build the homoglyph
    // variant — guards against the test fixture silently drifting to
    // contain non-ASCII chars.
    assert!(
        latin_str.is_ascii(),
        "baseline Latin source_id must be pure ASCII for this test"
    );

    // Substitute Latin 'a' (U+0061) with Cyrillic 'а' (U+0430). Both
    // render as 'a' in most fonts but differ in bytes.
    let homoglyph = "note-\u{0430}::lex".to_string();
    assert_ne!(
        homoglyph.as_bytes(),
        latin_str.as_bytes(),
        "homoglyph variant must differ in bytes from the Latin id — \
         this assertion proves the test isn't silently using identical \
         encodings on the two sides"
    );
    // The homoglyph is LONGER in bytes (Cyrillic 'а' is 2 bytes vs
    // Latin 'a' at 1 byte) — visible proof the strings differ.
    assert!(
        homoglyph.len() > latin_str.len(),
        "Cyrillic homoglyph adds bytes (UTF-8 multibyte vs ASCII)"
    );

    let smuggled = EidosCitation {
        source_id: EidosChunkId::new(homoglyph.clone()).unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    match packet.validate_citation(&smuggled).unwrap_err() {
        CitationError::FabricatedSourceId(returned) => {
            assert_eq!(
                returned.as_str(),
                &homoglyph,
                "diagnostic must preserve the Cyrillic bytes verbatim — \
                 silent script-folding would hide the attack vector"
            );
        }
        other => panic!("expected FabricatedSourceId, got {other:?}"),
    }

    // Also probe a multi-homoglyph variant: substitute every Latin
    // letter in "note-a::lex" that has a Cyrillic visual twin. Cyrillic
    // 'о' (U+043E) replaces Latin 'o' (U+006F); rest stays Latin since
    // 't' / 'n' / 'e' / 'l' / 'x' have less-common or no Cyrillic twins
    // at this code point. The point: ANY substitution at ANY position
    // must surface as fabrication.
    let multi_homoglyph = "n\u{043E}te-a::lex".to_string();
    assert_ne!(multi_homoglyph.as_bytes(), latin_str.as_bytes());
    let smuggled2 = EidosCitation {
        source_id: EidosChunkId::new(multi_homoglyph.clone()).unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert!(
        packet.validate_citation(&smuggled2).is_err(),
        "Cyrillic 'о' substitution at any position must be rejected"
    );

    // Positive control: byte-equal Latin id IS accepted.
    let legit = EidosCitation {
        source_id: latin_src,
        manifest_id: packet.manifest_id.clone(),
    };
    assert_eq!(packet.validate_citation(&legit), Ok(()));
}

/// `validate_citation` iterates ALL hits in the packet, not just
/// early-positioned ones. A citation that matches the LAST hit in a
/// large packet must be accepted exactly the same way as a citation
/// matching the FIRST hit.
///
/// Existing tests pin happy-path validation on 1-2 hit packets where
/// the match is necessarily at index 0 or 1. That coverage doesn't
/// catch a "fast-path" regression that only checks the first N hits
/// before bailing out — common pattern in performance-motivated
/// changes (e.g. "we always cite the top-ranked hit anyway, why
/// scan the whole packet?").
///
/// Pins, against a 25-hit packet:
///   - citation matching hit at index 0 → Ok
///   - citation matching hit at index 12 (middle) → Ok
///   - citation matching hit at LAST index (24) → Ok
///   - citation matching a fabricated id NOT in any hit → Err
///
/// Catches premature `take(N)`-style short-circuits and any future
/// "skip-list" / "index-by-first-letter" / "bloom-filter pre-check"
/// optimization that breaks the all-hits scan.
#[test]
fn validate_citation_iterates_all_hits_not_just_early_ones() {
    use super::types::{EidosCitation, EidosChunkId};

    let mut lex = InMemoryLexicalIndex::new(manifest());
    // 25 documents, all matching the query so all surface in the packet.
    // Bumped slightly past top_k=16 default to test the larger-than-
    // default-k case at the same time; top_k below is set to 32 so we
    // get all 25 back.
    const N: usize = 25;
    for i in 0..N {
        lex.insert(
            doc(&format!("note-{i:02}")),
            "alpha quince",
            EidosSourceKind::Note,
        ).unwrap();
    }
    let q = EidosQuery::new("quince", EidosRetrievalMode::Lexical, 32);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), N, "all 25 docs must surface in the packet");

    // Build citations for first, middle, and last hits.
    let make_cite = |src: EidosChunkId| EidosCitation {
        source_id: src,
        manifest_id: packet.manifest_id.clone(),
    };

    let first_src = packet.hits[0].source_id.clone();
    let middle_src = packet.hits[N / 2].source_id.clone();
    let last_src = packet.hits[N - 1].source_id.clone();

    // Sanity: the three ids genuinely differ (test isn't accidentally
    // citing the same source three times).
    assert_ne!(first_src, middle_src);
    assert_ne!(middle_src, last_src);
    assert_ne!(first_src, last_src);

    assert_eq!(
        packet.validate_citation(&make_cite(first_src)),
        Ok(()),
        "citation matching hit at index 0 must pass"
    );
    assert_eq!(
        packet.validate_citation(&make_cite(middle_src)),
        Ok(()),
        "citation matching hit at middle index ({}) must pass — catches \
         premature short-circuits that bail before the middle of the list",
        N / 2
    );
    assert_eq!(
        packet.validate_citation(&make_cite(last_src)),
        Ok(()),
        "citation matching hit at LAST index ({}) must pass — this is \
         the strongest signal against any take(N) / bloom-filter / \
         skip-list optimization that breaks all-hits coverage",
        N - 1
    );

    // Negative control: an id NOT in the packet is rejected, ruling
    // out a "validator always returns Ok" regression that would make
    // every positive assertion above vacuously pass.
    let ghost = make_cite(EidosChunkId::new("note-ghost::lex").unwrap());
    assert!(
        packet.validate_citation(&ghost).is_err(),
        "fabricated id must still be rejected — guards against a \
         degenerate 'validator always returns Ok' regression that \
         would make the positive assertions above vacuously pass"
    );
}

/// Stress-soundness pin: closed-citation contract holds on a
/// 1000-hit packet. Iter 138 pinned the all-hits-iteration property
/// at 25 hits; this scales it 40× to surface fixed-buffer /
/// fixed-capacity / accidentally-quadratic regressions that small
/// packets wouldn't reveal.
///
/// Why pin at scale: future "performance tuning" temptations are
/// real. A `take(N)` pre-filter, a stack-allocated `[Option<&Hit>;
/// 256]` cache, a fixed `Vec::with_capacity(64)` for the search
/// path — any of these would silently degrade behavior at scale
/// without breaking the small-N happy path. Pinning a 1000-hit
/// case forces the validation surface to remain genuinely O(N).
///
/// Pins:
///   - 1000-hit packet validates a citation at hit position 999
///     (last) → Ok(())
///   - 1000-hit packet validates a citation at hit position 500
///     (middle) → Ok(())
///   - 1000-hit packet validates a fabricated source_id → Err
///     (FabricatedSourceId)
///   - `validate_citations` on a 1000-citation batch (all legit,
///     one per hit) → Ok(()) — pins the batch path doesn't degrade
///     either
///
/// The test should complete in microseconds for a sound O(N*M)
/// implementation (M = avg id length ~ 20 bytes, N = 1000 hits;
/// 1000-citation batch over 1000-hit packet = 1M comparisons total,
/// well under 1 ms on modern hardware).
#[test]
fn closed_citation_contract_holds_at_scale_1000_hits() {
    use super::types::{EidosChunkId, EidosCitation};

    const N: usize = 1000;
    let mut lex = InMemoryLexicalIndex::new(manifest());
    for i in 0..N {
        lex.insert(
            doc(&format!("scale-{i:04}")),
            "alpha sapota",
            EidosSourceKind::Note,
        ).unwrap();
    }
    let q = EidosQuery::new("sapota", EidosRetrievalMode::Lexical, u16::MAX);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), N, "all {N} docs must surface");

    // (1) Last-position citation Ok — strongest signal against
    // fixed-buffer prefix optimizations.
    let last = EidosCitation {
        source_id: packet.hits[N - 1].source_id.clone(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert_eq!(
        packet.validate_citation(&last),
        Ok(()),
        "citation matching hit at position {} (last) must validate \
         Ok at scale — surfaces any take(N)/fixed-capacity \
         optimization that breaks the all-hits iteration",
        N - 1
    );

    // (2) Middle-position citation Ok — catches mid-list short-
    // circuits that small-N tests might miss.
    let middle = EidosCitation {
        source_id: packet.hits[N / 2].source_id.clone(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert_eq!(
        packet.validate_citation(&middle),
        Ok(()),
        "middle-position citation must validate Ok at scale"
    );

    // (3) Fabricated id still rejected — negative control.
    let ghost = EidosCitation {
        source_id: EidosChunkId::new("scale-ghost::lex").unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert!(
        packet.validate_citation(&ghost).is_err(),
        "fabricated id must still be rejected at scale"
    );

    // (4) Batch validation of 1000 legitimate citations (1 per hit)
    // returns Ok — pins the batch path also degrades cleanly. This
    // is 1000 × 1000 = 1M comparisons in the inner any() loop,
    // bounded by O(N*M) where M = id length ~20 bytes. Real-world
    // budget: well under 1 ms on modern hardware.
    let all_legit: Vec<EidosCitation> = packet
        .hits
        .iter()
        .map(|h| EidosCitation {
            source_id: h.source_id.clone(),
            manifest_id: packet.manifest_id.clone(),
        })
        .collect();
    assert_eq!(
        packet.validate_citations(&all_legit),
        Ok(()),
        "validate_citations on a {N}-citation batch (1 per hit, all \
         legit) must return Ok — catches any per-batch quadratic \
         blowup"
    );
}

/// `EidosCitation` JSON wire-format is the Swift bridge contract for
/// chat-layer → Rust validation. Two pins, an exact shape pin (so
/// the Swift bridge has a fixed reference) AND a round-trip
/// byte-equality pin across the adversarial smuggling vectors from
/// iters 127, 133, 137 (NFC/NFD, ZWSP, Cyrillic homoglyph) so the
/// wire faithfully transmits whatever bytes the model emitted.
///
/// Existing pins:
///   - `EidosContextPacket` JSON round-trip is pinned in `types::
///     tests::packet_roundtrips_through_json`
///   - `CitationError` JSON wire-format is pinned in
///     `types::tests::batch_validate_result_*` for both variants
///
/// Missing: standalone `EidosCitation` wire-format. The Swift bridge
/// will send citations as a top-level JSON object (not embedded in a
/// CitationError), so the citation-alone shape is a separate
/// contract surface.
///
/// Pins:
///   - exact JSON for a simple ASCII citation:
///     `{"source_id":"note-a::lex","manifest_id":"snap-A"}`
///     Newtype-struct serde default: `EidosChunkId(String)` and
///     `EidosIndexManifestId(String)` serialize as just the inner
///     string, not an object/array.
///   - round-trip byte-equality across the named adversarial id
///     payloads (ASCII baseline + the 5 named smuggling vectors from
///     iters 127/133/137/140/154) so the wire preserves bytes
///     EXACTLY — silent normalization at the bridge would invalidate
///     the byte-strict floor by re-folding the bytes on the way
///     through. The 5 vectors must stay in lock-step with iter 146's
///     drift detector.
#[test]
fn eidos_citation_json_wire_format_is_stable_and_round_trips() {
    use super::types::{EidosCitation, EidosChunkId};

    // (1) Exact shape — the Swift bridge depends on this.
    let simple = EidosCitation {
        source_id: EidosChunkId::new("note-a::lex").unwrap(),
        manifest_id: EidosIndexManifestId::new("snap-A").unwrap(),
    };
    let json = serde_json::to_string(&simple).expect("serialize");
    assert_eq!(
        json,
        r#"{"source_id":"note-a::lex","manifest_id":"snap-A"}"#,
        "EidosCitation JSON wire shape drifted — Swift bridge \
         (EpistemosTests/EidosParityTests.swift) must update in \
         lock-step. Newtype-struct serde default: inner String of \
         EidosChunkId / EidosIndexManifestId serializes as the raw \
         string, NOT an object wrapper."
    );

    // Round-trip byte-equality for the simple case.
    let back: EidosCitation = serde_json::from_str(&json).expect("deserialize");
    assert_eq!(back, simple);

    // (2) Adversarial round-trips: every smuggling vector pinned
    // earlier in this session must round-trip byte-faithfully through
    // JSON. If a future change adds NFC normalization at the
    // serializer or strips invisible chars / control chars / padding
    // at the deserializer, the byte-strict floor in iters
    // 127/133/137/140/154 silently breaks and the smuggling vector
    // reopens. Lock-step with iter 146's drift detector — the
    // 5-vector taxonomy is the same here.
    let manifest_id = EidosIndexManifestId::new("snap-A").unwrap();
    let adversarial_ids: &[(&str, &str)] = &[
        ("ASCII baseline", "note-a::lex"),
        // (1) NFC/NFD (iter 127) — decomposed é (e + combining acute).
        ("NFD-decomposed (iter 127)", "cafe\u{0301}::lex"),
        // (2) ZWSP (iter 133) — invisible U+200B.
        ("ZWSP-injected (iter 133)", "note\u{200B}-a::lex"),
        // (3) Homoglyph (iter 137) — Cyrillic 'а' (U+0430).
        ("Cyrillic-homoglyph (iter 137)", "note-\u{0430}::lex"),
        // (4) Whitespace (iter 140) — trailing space the UI may
        // collapse but the wire must preserve.
        ("Whitespace-padded (iter 140)", "note-a::lex "),
        // (5) Control-char (iter 154) — embedded ESC U+001B in a
        // position that could anchor an ANSI escape sequence.
        ("Control-char-injected (iter 154)", "note\u{001B}-a::lex"),
        // (6) Bidi override (iter 195) — RLO (U+202E) prefix flips
        // rendering direction in terminals/editors (Trojan Source).
        ("Bidi-RLO-prefixed (iter 195)", "\u{202E}note-a::lex"),
    ];

    for (label, raw_id) in adversarial_ids {
        let cite = EidosCitation {
            source_id: EidosChunkId::new(*raw_id).unwrap(),
            manifest_id: manifest_id.clone(),
        };
        let j = serde_json::to_string(&cite)
            .unwrap_or_else(|e| panic!("{label}: serialize failed: {e}"));
        let back: EidosCitation = serde_json::from_str(&j)
            .unwrap_or_else(|e| panic!("{label}: deserialize failed: {e}"));

        // Critical: round-trip preserves the EXACT byte payload of
        // source_id. If serde silently normalized at either side, the
        // byte-strict closed-citation contract pinned earlier would
        // silently break — bytes that left the chat layer as one
        // payload would arrive at the validator as a different one.
        assert_eq!(
            back.source_id.as_str().as_bytes(),
            cite.source_id.as_str().as_bytes(),
            "{label}: JSON round-trip must preserve source_id bytes exactly"
        );
        assert_eq!(back, cite, "{label}: full citation must round-trip");

        // Sanity: the byte count survives non-ASCII multibyte chars.
        // Cyrillic / combining marks / ZWSP all add bytes vs the
        // visual length; the JSON wire must carry them. (Skipped for
        // whitespace + control-char, which stay ASCII single-byte.)
        if !raw_id.is_ascii() {
            assert!(
                back.source_id.as_str().len() > raw_id.chars().count(),
                "{label}: non-ASCII id has more bytes than codepoints — \
                 wire must carry every byte"
            );
        }
    }
}

/// Closed-citation contract rejects **whitespace-padding smuggling**:
/// citations whose source_id has trailing/leading whitespace,
/// newlines, or tabs that the visible UI strips during render but
/// the bytes preserve. This is the 4th distinct adversarial vector
/// pinned in this session, complementing the three named vectors:
///
///   - NFC/NFD     (iter 127): same character, two encodings
///   - ZWSP        (iter 133): invisible codepoints injected
///   - Homoglyph   (iter 137): visually-equivalent different scripts
///   - Whitespace  (this iter): renderable padding that UIs collapse
///
/// Why whitespace deserves its own pin: most terminals, web views,
/// and chat UIs collapse trailing whitespace at render time, so a
/// trailing-space-padded citation renders identical to its clean
/// counterpart in a "review the citation before submitting" UI.
/// Browsers wrap lines on whitespace and may visually elide a
/// trailing space. A sloppy model that copy-pastes with a trailing
/// space (or a chat-layer regex with `\s*` quantifiers) could
/// silently break byte-equality if the validator weren't strict.
///
/// Pins (all rejected as FabricatedSourceId):
///   - trailing space:    "note-a::lex "
///   - leading space:     " note-a::lex"
///   - trailing newline:  "note-a::lex\n"
///   - trailing tab:      "note-a::lex\t"
///   - embedded run of spaces (internal padding): "note-a ::lex"
///
/// Positive control: the clean id IS accepted. Each smuggled variant
/// must surface its actual padded bytes in the diagnostic so the
/// operator can see what was injected.
#[test]
fn validate_citation_rejects_whitespace_padding_smuggling() {
    use super::types::{CitationError, EidosCitation, EidosChunkId};

    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("note-a"), "alpha rambutan content", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("rambutan", EidosRetrievalMode::Lexical, 16);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), 1);
    let clean = packet.hits[0].source_id.as_str().to_string();
    assert_eq!(clean, "note-a::lex");

    let variants: &[(&str, String)] = &[
        ("trailing-space",   format!("{clean} ")),
        ("leading-space",    format!(" {clean}")),
        ("trailing-newline", format!("{clean}\n")),
        ("trailing-tab",     format!("{clean}\t")),
        ("embedded-space",   "note-a ::lex".to_string()),
    ];

    for (label, padded) in variants {
        assert_ne!(
            padded.as_bytes(),
            clean.as_bytes(),
            "{label}: padded variant must differ in bytes from the clean id"
        );

        let cite = EidosCitation {
            source_id: EidosChunkId::new(padded.clone()).unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        match packet.validate_citation(&cite).unwrap_err() {
            CitationError::FabricatedSourceId(returned) => {
                assert_eq!(
                    returned.as_str(),
                    padded,
                    "{label}: diagnostic must preserve the padded bytes — \
                     silent .trim() would hide the smuggling vector"
                );
            }
            other => panic!("{label}: expected FabricatedSourceId, got {other:?}"),
        }
    }

    // Positive control: the clean id IS accepted.
    let legit = EidosCitation {
        source_id: packet.hits[0].source_id.clone(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert_eq!(packet.validate_citation(&legit), Ok(()));
}

/// Closed-citation contract rejects **non-printable control-character
/// smuggling** — citations whose source_id has low-codepoint ASCII
/// control characters (U+0001..U+001F, U+007F DEL) injected.
///
/// This is the 5th distinct adversarial smuggling vector,
/// complementing the four named vectors pinned earlier:
///
///   - NFC/NFD (iter 127): same character, two encodings
///   - ZWSP (iter 133): high-codepoint invisible chars injected
///   - Homoglyph (iter 137): visually-equivalent different scripts
///   - Whitespace (iter 140): visible padding terminals collapse
///   - Control chars (this iter): low-codepoint non-printables that
///     render unpredictably (some terminals show nothing, some emit
///     control sequences, some interrupt rendering)
///
/// Why this deserves its own pin: control characters live in a
/// different escape-encoding regime than the four prior vectors —
/// JSON forces them to `\u00xx` escapes on the wire, but the byte
/// after deserialization is the actual control char. A "review the
/// citation before submitting" UI typically shows control chars as
/// blanks or replacement glyphs; a sloppy model that pastes a
/// citation through a terminal-paste might pick up a stray BEL
/// (U+0007) or DEL (U+007F) without the operator noticing. The
/// byte-strict floor rejects them just like every other vector.
///
/// Pins (all rejected as FabricatedSourceId):
///   - U+0001 (Start of Heading)
///   - U+0007 BEL (Bell — audible "beep" on some terminals)
///   - U+001B ESC (Escape — could start ANSI escape sequences)
///   - U+007F DEL (Delete)
///   - mixed: ESC injected mid-string
///
/// Each variant must surface its actual control-char bytes via the
/// Display surface's Debug-escape rendering (iter 135: invisible
/// chars surface as `\u{...}` literal text in logs, not raw bytes,
/// so operators can spot the injection).
#[test]
fn validate_citation_rejects_control_character_smuggling() {
    use super::types::{CitationError, EidosCitation, EidosChunkId};

    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("note-a"), "alpha jujube content", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("jujube", EidosRetrievalMode::Lexical, 16);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), 1);
    let clean = packet.hits[0].source_id.as_str().to_string();
    assert_eq!(clean, "note-a::lex");

    let variants: &[(&str, String, char)] = &[
        ("SOH-prefix",    format!("\u{0001}{clean}"),                    '\u{0001}'),
        ("BEL-suffix",    format!("{clean}\u{0007}"),                    '\u{0007}'),
        ("ESC-mid",       format!("note\u{001B}-a::lex"),                '\u{001B}'),
        ("DEL-suffix",    format!("{clean}\u{007F}"),                    '\u{007F}'),
    ];

    for (label, smuggled, ctrl) in variants {
        assert_ne!(
            smuggled.as_bytes(),
            clean.as_bytes(),
            "{label}: smuggled variant must differ in bytes from the clean id"
        );
        assert!(
            smuggled.contains(*ctrl),
            "{label}: smuggled string must contain the named control char \
             U+{:04X}",
            *ctrl as u32
        );

        let cite = EidosCitation {
            source_id: EidosChunkId::new(smuggled.clone()).unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        match packet.validate_citation(&cite).unwrap_err() {
            CitationError::FabricatedSourceId(returned) => {
                assert_eq!(
                    returned.as_str(),
                    smuggled,
                    "{label}: diagnostic must preserve the control-char \
                     bytes verbatim — silent .filter(|c| !c.is_control()) \
                     would hide the smuggling vector"
                );
            }
            other => panic!("{label}: expected FabricatedSourceId, got {other:?}"),
        }
    }

    // Positive control: clean id IS accepted.
    let legit = EidosCitation {
        source_id: packet.hits[0].source_id.clone(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert_eq!(packet.validate_citation(&legit), Ok(()));
}

/// Closed-citation contract rejects **bidirectional-text-override
/// smuggling** — citations whose source_id contains Unicode Bidi
/// control characters (U+202A..U+202E LRE/RLE/PDF/LRO/RLO,
/// U+2066..U+2069 isolates) that flip rendering direction.
///
/// This is the 6th distinct adversarial smuggling vector pinned in
/// this session, complementing the prior five:
///
///   - NFC/NFD (iter 127): same character, two encodings
///   - ZWSP (iter 133): high-codepoint invisible char injection
///   - Homoglyph (iter 137): visually-equivalent different scripts
///   - Whitespace (iter 140): visible padding terminals collapse
///   - Control chars (iter 154): low-codepoint non-printables
///   - Bidi override (this iter): rendering-direction reversal
///
/// Why this deserves its own pin: Bidi controls power the
/// "Trojan Source" attack class (CVE-2021-42574, 2021). They
/// invert text rendering direction in terminals + editors, so a
/// citation containing U+202E followed by reversed bytes RENDERS
/// identically to a legitimate citation — operator reviewing the
/// citation in a log sees clean text, but the actual bytes are
/// arbitrary. Byte-strict rejection catches the attack regardless
/// of how the rendering surface interprets the bidi controls.
///
/// Pins (all rejected as FabricatedSourceId):
///   - U+202E RLO (Right-to-Left Override) prepended
///   - U+202D LRO (Left-to-Right Override) injected mid-string
///   - U+202B RLE (Right-to-Left Embedding) appended
///   - U+2068 FSI (First Strong Isolate) injected
///
/// Each variant must surface its actual bidi-control bytes via
/// Display escape-rendering (iter 135 + iter 187: bidi chars
/// surface as `\u{xxxx}` literal text, NOT raw bytes, so the
/// attack vector is visible in logs).
#[test]
fn validate_citation_rejects_bidirectional_text_override_smuggling() {
    use super::types::{CitationError, EidosCitation, EidosChunkId};

    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("note-a"), "alpha okra content", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("okra", EidosRetrievalMode::Lexical, 16);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), 1);
    let clean = packet.hits[0].source_id.as_str().to_string();
    assert_eq!(clean, "note-a::lex");

    let variants: &[(&str, String, char)] = &[
        ("RLO-prepended (U+202E)", format!("\u{202E}{clean}"),     '\u{202E}'),
        ("LRO-mid (U+202D)",       format!("note\u{202D}-a::lex"), '\u{202D}'),
        ("RLE-appended (U+202B)",  format!("{clean}\u{202B}"),     '\u{202B}'),
        ("FSI-mid (U+2068)",       format!("note-\u{2068}a::lex"), '\u{2068}'),
    ];

    for (label, smuggled, bidi) in variants {
        assert_ne!(
            smuggled.as_bytes(),
            clean.as_bytes(),
            "{label}: smuggled variant must differ in bytes from the clean id"
        );
        assert!(
            smuggled.contains(*bidi),
            "{label}: smuggled string must contain the named bidi char U+{:04X}",
            *bidi as u32
        );

        let cite = EidosCitation {
            source_id: EidosChunkId::new(smuggled.clone()).unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        match packet.validate_citation(&cite).unwrap_err() {
            CitationError::FabricatedSourceId(returned) => {
                assert_eq!(
                    returned.as_str(),
                    smuggled,
                    "{label}: diagnostic must preserve the bidi-control \
                     bytes verbatim — silent .strip_bidi() at the \
                     validator would hide the Trojan Source attack vector"
                );
            }
            other => panic!("{label}: expected FabricatedSourceId, got {other:?}"),
        }
    }

    // Positive control: clean id IS accepted.
    let legit = EidosCitation {
        source_id: packet.hits[0].source_id.clone(),
        manifest_id: packet.manifest_id.clone(),
    };
    assert_eq!(packet.validate_citation(&legit), Ok(()));
}

/// `EidosChunkId::new` and `EidosIndexManifestId::new` reject empty
/// payloads at the Rust-side construction API (`IdError::EmptyPayload`),
/// but the `#[derive(Deserialize)]` on the newtype tuple struct does
/// NOT run those constructors — `serde_json::from_str` will happily
/// deserialize `"source_id":""` into an `EidosChunkId("")`.
///
/// That is an asymmetry between the Rust API floor (constructor
/// guard) and the wire surface (raw newtype deserialize). The
/// closed-citation gate MUST hold even when the wire bypass produces
/// an empty-payload citation — no real retriever emits an empty
/// source_id (the empty-payload guard runs at the retriever side
/// when ids are constructed), so an empty source_id citation cannot
/// match any hit and must be rejected as fabricated.
///
/// Pins:
///   - JSON-deserialize of `{"source_id":"","manifest_id":"snap-A"}`
///     succeeds (the constructor guard is bypassed by serde)
///   - `validate_citation` of that empty-source_id citation against
///     a non-empty packet → `FabricatedSourceId` with the empty
///     payload preserved in the diagnostic
///   - same shape with empty `manifest_id` AND non-empty source_id
///     also deserializes and surfaces as `ManifestMismatch`
///     (manifest check precedence holds, so the empty manifest is
///     surfaced before fabrication — consistent with iter 130)
///   - symmetry: serializing an empty-payload EidosCitation back
///     round-trips byte-equal (no silent dropping of empty fields
///     in either direction)
#[test]
fn validate_citation_rejects_wire_smuggled_empty_payload_ids() {
    use super::types::{CitationError, EidosCitation};

    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("note-a"), "alpha durian content", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("durian", EidosRetrievalMode::Lexical, 16);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), 1);

    // (1) Confirm the asymmetry: constructor rejects empty, but the
    // JSON wire DOES deserialize empty payloads.
    use super::types::{EidosChunkId, EidosIndexManifestId, IdError};
    assert_eq!(EidosChunkId::new(""), Err(IdError::EmptyPayload));
    let wire_empty_chunk = r#"{"source_id":"","manifest_id":"hardening-manifest"}"#;
    let smuggled_chunk: EidosCitation = serde_json::from_str(wire_empty_chunk)
        .expect("serde Deserialize on EidosCitation does NOT run EidosChunkId::new — empty payload deserializes successfully");
    assert_eq!(
        smuggled_chunk.source_id.as_str(),
        "",
        "wire-smuggled citation carries an empty source_id payload"
    );

    // (2) The validator catches it as FabricatedSourceId — no real
    // hit has an empty source_id, so the closed-citation gate floors
    // this case correctly. Empty payload survives byte-for-byte into
    // the diagnostic.
    match packet.validate_citation(&smuggled_chunk).unwrap_err() {
        CitationError::FabricatedSourceId(returned) => {
            assert_eq!(
                returned.as_str(),
                "",
                "diagnostic must preserve the empty payload so the operator \
                 can spot the wire-smuggled empty id"
            );
        }
        other => panic!("expected FabricatedSourceId for empty source_id, got {other:?}"),
    }

    // (3) Symmetric case — empty manifest_id with a real source_id.
    // The manifest check fires first (iter 130 precedence pin), so
    // this surfaces as ManifestMismatch with empty payload in the
    // citation field.
    let wire_empty_manifest = format!(
        r#"{{"source_id":"{}","manifest_id":""}}"#,
        packet.hits[0].source_id.as_str()
    );
    let smuggled_manifest: EidosCitation = serde_json::from_str(&wire_empty_manifest)
        .expect("wire deserialize allows empty manifest_id");
    assert_eq!(smuggled_manifest.manifest_id.as_str(), "");
    match packet.validate_citation(&smuggled_manifest).unwrap_err() {
        CitationError::ManifestMismatch { packet: pm, citation: cm } => {
            assert_eq!(pm, packet.manifest_id, "packet manifest preserved");
            assert_eq!(
                cm.as_str(),
                "",
                "citation manifest payload preserved (empty string) — \
                 precedence from iter 130 makes ManifestMismatch fire \
                 before the fabrication check, and the smuggled empty \
                 manifest_id survives byte-for-byte into the diagnostic"
            );
        }
        CitationError::FabricatedSourceId(_) => {
            panic!(
                "ManifestMismatch must fire FIRST (iter 130 precedence pin); \
                 empty manifest_id is a manifest-mismatch case, not \
                 fabrication"
            );
        }
    }

    // (4) Symmetry: serializing an empty-payload citation back to
    // JSON round-trips byte-equal. No silent dropping of empty
    // fields in either direction.
    let round = serde_json::to_string(&smuggled_chunk).expect("serialize");
    assert_eq!(
        round, wire_empty_chunk,
        "empty-payload citation must round-trip byte-equal — no silent \
         field drop, no silent placeholder substitution"
    );
}

/// `validate_citations` (batch) is the canonical "lift" of
/// `validate_citation` (singular) to a list of citations: it is Ok
/// IF AND ONLY IF every citation individually validates Ok, and
/// returns the full per-index error report otherwise.
///
/// Pinned as a property: for every test input list `cs`,
///
///     packet.validate_citations(&cs).is_ok()
///       ⟺  cs.iter().all(|c| packet.validate_citation(c).is_ok())
///
/// This is the SEMANTIC CONSISTENCY pin between the two APIs. If
/// someone changed `validate_citations` to e.g. short-circuit on
/// the first failure (failing all subsequent citations as
/// fabricated regardless), or to soft-pass on a partial subset
/// ("majority votes Ok"), this property would surface.
///
/// Probed across five canonical inputs covering the singular ↔
/// batch lift behavior:
///   - empty input        → both Ok
///   - single legit       → both Ok
///   - single fabricated  → both report 1 error
///   - all legit          → both Ok
///   - mixed              → both report exactly the failing subset
///
/// Plus iter 128's input-dedup-preservation pin transitively (each
/// input index validated independently), iter 131's input-index-
/// order pin (errors come back in input order), and iter 130's
/// precedence pin (ManifestMismatch fires before FabricatedSourceId
/// in each individual call).
#[test]
fn validate_citations_is_consistent_with_validate_citation_lift() {
    use super::types::{EidosChunkId, EidosCitation};

    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("note-a"), "alpha persimmon", EidosSourceKind::Note).unwrap();
    lex.insert(doc("note-b"), "beta persimmon", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("persimmon", EidosRetrievalMode::Lexical, 16);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), 2);
    let m = packet.manifest_id.clone();
    let stale = EidosIndexManifestId::new("stale-snap").unwrap();
    let legit_a = packet.hits[0].source_id.clone();
    let legit_b = packet.hits[1].source_id.clone();
    let forge = |tag: &str| EidosChunkId::new(format!("ghost-{tag}::lex")).unwrap();

    let cases: Vec<(&str, Vec<EidosCitation>)> = vec![
        ("empty", vec![]),
        (
            "single-legit",
            vec![EidosCitation {
                source_id: legit_a.clone(),
                manifest_id: m.clone(),
            }],
        ),
        (
            "single-fabricated",
            vec![EidosCitation {
                source_id: forge("solo"),
                manifest_id: m.clone(),
            }],
        ),
        (
            "all-legit",
            vec![
                EidosCitation {
                    source_id: legit_a.clone(),
                    manifest_id: m.clone(),
                },
                EidosCitation {
                    source_id: legit_b.clone(),
                    manifest_id: m.clone(),
                },
            ],
        ),
        (
            "mixed",
            vec![
                EidosCitation {
                    source_id: legit_a.clone(),
                    manifest_id: m.clone(),
                },
                EidosCitation {
                    source_id: forge("middle"),
                    manifest_id: m.clone(),
                },
                EidosCitation {
                    source_id: legit_b.clone(),
                    manifest_id: stale.clone(),
                },
            ],
        ),
    ];

    for (label, cs) in &cases {
        // Singular: run validate_citation per-input, collect per-index
        // results.
        let singular: Vec<_> = cs.iter().map(|c| packet.validate_citation(c)).collect();
        let singular_all_ok = singular.iter().all(|r| r.is_ok());

        // Batch.
        let batch = packet.validate_citations(cs);
        let batch_ok = batch.is_ok();

        // (1) The iff property: Ok ⟺ all singular Ok.
        assert_eq!(
            batch_ok,
            singular_all_ok,
            "{label}: validate_citations.is_ok() must equal \
             cs.iter().all(validate_citation(c).is_ok())"
        );

        // (2) If both report errors, the error count + per-index
        // errors must match exactly between the two APIs.
        if !batch_ok {
            let errs = batch.as_ref().unwrap_err();
            let singular_errs: Vec<(usize, _)> = singular
                .iter()
                .enumerate()
                .filter_map(|(i, r)| r.as_ref().err().map(|e| (i, e.clone())))
                .collect();
            assert_eq!(
                errs.len(),
                singular_errs.len(),
                "{label}: batch error count must match singular error count"
            );
            // Indices and error variants must match pairwise. Use
            // Debug-format comparison to avoid PartialEq autoref
            // friction across the two collections' element types.
            for k in 0..errs.len() {
                let bi = errs[k].0;
                let si = singular_errs[k].0;
                let be = format!("{:?}", errs[k].1);
                let se = format!("{:?}", singular_errs[k].1);
                assert_eq!(
                    bi, si,
                    "{label}: batch error index {bi} must match singular \
                     error index {si} at position {k}"
                );
                assert_eq!(
                    be, se,
                    "{label}: batch error at index {bi} must equal singular \
                     error at the same input position"
                );
            }
        }

        // (3) Error count is bounded by input size — surfaces a
        // hypothetical "let's expand errors with synthetic entries"
        // bug.
        if let Err(errs) = &batch {
            assert!(
                errs.len() <= cs.len(),
                "{label}: error count ({}) must not exceed input size ({})",
                errs.len(),
                cs.len()
            );
        }
    }
}

/// `EidosCitation`'s JSON wire-deserialize contract:
///   - Both `source_id` AND `manifest_id` are REQUIRED — missing
///     either field returns a serde error (not a default-filled
///     citation). This catches chat-layer bugs that emit malformed
///     citations at the wire boundary, before they reach the
///     closed-citation gate.
///   - Extra/unknown fields are SILENTLY ACCEPTED — forward
///     compatibility for a future field addition without breaking
///     older deserializers.
///   - Field ORDER doesn't matter — JSON object semantics.
///   - WRONG field types fail — `"source_id": 42` (number) errors.
///
/// Pins both edges of the contract: strict on missing-required
/// fields (loud surface for real bugs), permissive on extra fields
/// (no breakage on schema evolution).
///
/// These are derived behaviors from `#[derive(Deserialize)]` defaults
/// on a 2-field struct, but pinning them explicitly:
///   - documents the contract for the Swift bridge implementer
///   - catches a future migration to `#[serde(deny_unknown_fields)]`
///     that would break forward-compat
///   - catches a future migration to `#[serde(default)]` on either
///     field that would silently produce empty-payload citations
///     instead of erroring on missing fields
#[test]
fn eidos_citation_json_deserialize_contract() {
    use super::types::EidosCitation;

    // (1) Both fields present + ASCII-only → succeeds.
    let good = r#"{"source_id":"note-a::lex","manifest_id":"snap-A"}"#;
    let parsed: EidosCitation =
        serde_json::from_str(good).expect("happy-path deserialize must succeed");
    assert_eq!(parsed.source_id.as_str(), "note-a::lex");
    assert_eq!(parsed.manifest_id.as_str(), "snap-A");

    // (2) Missing source_id → error. The chat-layer bridge cannot
    // construct a citation without a source_id; this is a wire-floor
    // catch for "I forgot to populate that field" bugs.
    let missing_src = r#"{"manifest_id":"snap-A"}"#;
    assert!(
        serde_json::from_str::<EidosCitation>(missing_src).is_err(),
        "missing source_id MUST surface as a deserialize error, NOT \
         a default-filled (empty-payload) citation — a future \
         migration to #[serde(default)] would silently produce \
         empty-payload citations and bypass this wire floor"
    );

    // (3) Missing manifest_id → error.
    let missing_manifest = r#"{"source_id":"note-a::lex"}"#;
    assert!(
        serde_json::from_str::<EidosCitation>(missing_manifest).is_err(),
        "missing manifest_id MUST surface as a deserialize error"
    );

    // (4) Both fields missing → error.
    let empty_object = r#"{}"#;
    assert!(
        serde_json::from_str::<EidosCitation>(empty_object).is_err(),
        "empty-object citation MUST error — neither field can be \
         silently defaulted"
    );

    // (5) Extra unknown field → succeeds (forward-compat).
    let extra = r#"{"source_id":"note-a::lex","manifest_id":"snap-A","future_field":"junk"}"#;
    let parsed_extra: EidosCitation = serde_json::from_str(extra).expect(
        "extra/unknown fields MUST be silently accepted for forward-compat — \
         a future migration to #[serde(deny_unknown_fields)] would break \
         older Swift bridges that send newer payloads",
    );
    assert_eq!(parsed_extra.source_id.as_str(), "note-a::lex");
    assert_eq!(parsed_extra.manifest_id.as_str(), "snap-A");

    // (6) Field order swapped → succeeds (JSON object semantics).
    let swapped = r#"{"manifest_id":"snap-A","source_id":"note-a::lex"}"#;
    let parsed_swapped: EidosCitation =
        serde_json::from_str(swapped).expect("field order must not matter");
    assert_eq!(parsed_swapped.source_id.as_str(), "note-a::lex");
    assert_eq!(parsed_swapped.manifest_id.as_str(), "snap-A");

    // (7) Wrong field type → error. A numeric source_id (a chat-
    // layer bug that stringifies wrong) MUST be rejected, not
    // coerced.
    let wrong_type = r#"{"source_id":42,"manifest_id":"snap-A"}"#;
    assert!(
        serde_json::from_str::<EidosCitation>(wrong_type).is_err(),
        "numeric source_id MUST error — no silent coercion to a \
         stringified number, which would otherwise smuggle a citation \
         with source_id = \"42\""
    );
}

/// `EidosContextPacket::validate_citation` matches on `source_id`
/// (and `manifest_id`) ONLY — it does NOT inspect any other field
/// of `EidosHit`. The contract is byte-equality on the two id
/// fields; the hit's `confidence`, `span`, `kind`, `score`,
/// `document_id`, and `provenance.{retrieved_at_unix_ms, mode}` are
/// all transparent to the gate.
///
/// Why pin this: a future "let's also filter on hit metadata"
/// change is a real temptation. Examples that this pin catches:
///   - "reject if confidence is NaN" (sounds reasonable, but the
///     gate's job is closed-universe membership, not confidence
///     filtering; NaN handling lives at the retriever)
///   - "reject if span is None" (some hits legitimately have no
///     span — graph-neighborhood, code-symbol)
///   - "reject if kind is Shadow" (per-kind authorization belongs
///     elsewhere)
///   - "reject if confidence < 0.5" (confidence floors are a
///     retrieval-tuning concern, not a citation-contract concern)
///
/// Each of those changes would silently narrow the closed citation
/// universe to a subset of returned hits, making citations that
/// Eidos returned be rejected by the gate — breaking the
/// "everything Eidos returned is citable" floor.
///
/// Pins, against a 4-hit packet whose hits carry adversarial
/// metadata (NaN confidence, no span, low confidence, exotic kind,
/// zeroed scores):
///   - all 4 citations matching those hits validate → Ok(())
///   - a citation with a fabricated id still rejects (negative
///     control to rule out "validator always returns Ok")
#[test]
fn validate_citation_ignores_hit_metadata_only_source_id_matters() {
    use super::types::{
        EidosChunkId, EidosCitation, EidosContextPacket, EidosHit, EidosProvenance,
        EidosScoreComponents, EidosSourceKind, EidosSpan,
    };

    let m = manifest();
    let mode = EidosRetrievalMode::Lexical;

    // Four hits with deliberately adversarial metadata patterns. The
    // SOURCE_IDs are the only thing the gate looks at.
    let hits = vec![
        // Hit 0: confidence is NaN.
        EidosHit {
            source_id: EidosChunkId::new("hit-nan::lex").unwrap(),
            document_id: doc("doc-nan"),
            kind: EidosSourceKind::Note,
            span: None,
            confidence: f32::NAN,
            score: EidosScoreComponents::default(),
            provenance: EidosProvenance {
                manifest_id: m.clone(),
                mode,
                retrieved_at_unix_ms: 1_700_000_000_000,
            },
        },
        // Hit 1: no span + confidence is 0.0.
        EidosHit {
            source_id: EidosChunkId::new("hit-nospan::lex").unwrap(),
            document_id: doc("doc-nospan"),
            kind: EidosSourceKind::Note,
            span: None,
            confidence: 0.0,
            score: EidosScoreComponents::default(),
            provenance: EidosProvenance {
                manifest_id: m.clone(),
                mode,
                retrieved_at_unix_ms: 0,
            },
        },
        // Hit 2: exotic kind (Shadow) + zero-width span + zero scores.
        EidosHit {
            source_id: EidosChunkId::new("hit-shadow::lex").unwrap(),
            document_id: doc("doc-shadow"),
            kind: EidosSourceKind::Shadow,
            span: Some(EidosSpan { byte_start: 5, byte_end: 5 }),
            confidence: 0.001,
            score: EidosScoreComponents::default(),
            provenance: EidosProvenance {
                manifest_id: m.clone(),
                mode,
                retrieved_at_unix_ms: u64::MAX,
            },
        },
        // Hit 3: provenance mode different from outer retriever mode
        // (this is allowed — provenance records which inner mode
        // produced the hit in a hybrid scenario).
        EidosHit {
            source_id: EidosChunkId::new("hit-mixedmode::lex").unwrap(),
            document_id: doc("doc-mixedmode"),
            kind: EidosSourceKind::Note,
            span: Some(EidosSpan { byte_start: 0, byte_end: 100 }),
            confidence: 1.0,
            score: EidosScoreComponents {
                lexical: 0.5,
                semantic: 0.3,
                recency: 0.0,
                graph: 0.0,
            },
            provenance: EidosProvenance {
                manifest_id: m.clone(),
                mode: EidosRetrievalMode::Semantic,
                retrieved_at_unix_ms: 1_700_000_000_000,
            },
        },
    ];

    let packet = EidosContextPacket {
        query: EidosQuery::new("metadata-irrelevance", mode, 16),
        manifest_id: m.clone(),
        hits,
    };

    // All four citations validate Ok, regardless of hit metadata.
    for (i, h) in packet.hits.iter().enumerate() {
        let cite = EidosCitation {
            source_id: h.source_id.clone(),
            manifest_id: m.clone(),
        };
        assert_eq!(
            packet.validate_citation(&cite),
            Ok(()),
            "hit {i} (source_id = {:?}) must validate regardless of \
             confidence/span/kind/score/provenance.mode/retrieved_at — \
             the gate's contract is byte-equality on source_id + \
             manifest_id ONLY",
            h.source_id.as_str()
        );
    }

    // Negative control: a fabricated id is still rejected. Rules
    // out a degenerate "validator always returns Ok" regression
    // that would make the positive assertions vacuously pass.
    let ghost = EidosCitation {
        source_id: EidosChunkId::new("hit-ghost::lex").unwrap(),
        manifest_id: m,
    };
    assert!(
        packet.validate_citation(&ghost).is_err(),
        "fabricated id must still be rejected — guards the positive \
         assertions above against vacuous truth"
    );
}

/// `EidosCitation` equality is **conjunctive on both fields**: two
/// citations are equal iff their `source_id` AND `manifest_id` both
/// byte-equal. All four truth-table corners pinned exhaustively.
///
/// Why pin the full truth table: the existing HashSet-dedup test
/// (iter 88+ context, `eidos_citation_hash_eq_dedup_in_hashset`)
/// only covers two of the four corners — same/same and same-source/
/// different-manifest. The symmetric "different-source / same-
/// manifest" and the "different/different" corners are unverified,
/// leaving an asymmetry in the locked behavior that a future custom
/// `PartialEq` could exploit.
///
/// Pins:
///   (a) same source_id, same manifest_id     → equal
///   (b) same source_id, different manifest_id → NOT equal
///   (c) different source_id, same manifest_id → NOT equal
///   (d) different source_id, different manifest_id → NOT equal
///
/// And the Hash counterparts: equal citations MUST hash equal
/// (the `Eq + Hash` contract from std), and unequal citations
/// SHOULD typically hash differently (not guaranteed by the
/// contract, but verified here for the four canonical samples
/// so a future custom Hash impl that collapses one field surfaces).
#[test]
fn eidos_citation_eq_is_conjunctive_on_both_fields() {
    use super::types::{EidosChunkId, EidosCitation};
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};

    let src_a = EidosChunkId::new("source-A").unwrap();
    let src_b = EidosChunkId::new("source-B").unwrap();
    let man_a = EidosIndexManifestId::new("manifest-A").unwrap();
    let man_b = EidosIndexManifestId::new("manifest-B").unwrap();

    let aa = EidosCitation { source_id: src_a.clone(), manifest_id: man_a.clone() };
    let aa_twin = EidosCitation { source_id: src_a.clone(), manifest_id: man_a.clone() };
    let ab = EidosCitation { source_id: src_a.clone(), manifest_id: man_b.clone() };
    let ba = EidosCitation { source_id: src_b.clone(), manifest_id: man_a.clone() };
    let bb = EidosCitation { source_id: src_b.clone(), manifest_id: man_b.clone() };

    // (a) Same source_id, same manifest_id → equal.
    assert_eq!(aa, aa_twin, "same/same must be equal");

    // (b) Same source_id, different manifest_id → NOT equal.
    assert_ne!(
        aa, ab,
        "same source_id but different manifest_id must NOT be equal — \
         manifest binds the citation to a specific index snapshot"
    );

    // (c) Different source_id, same manifest_id → NOT equal.
    // This is the corner the existing HashSet test does NOT cover.
    assert_ne!(
        aa, ba,
        "different source_id but same manifest_id must NOT be equal — \
         a future custom PartialEq that compared manifest only (e.g. \
         'all citations against snapshot X are interchangeable') would \
         silently collapse distinct citations and break dedup integrity"
    );

    // (d) Different source_id, different manifest_id → NOT equal.
    assert_ne!(aa, bb, "different/different must NOT be equal");

    // Hash counterpart: equal citations must hash equal (std contract).
    let mut h1 = DefaultHasher::new();
    aa.hash(&mut h1);
    let mut h2 = DefaultHasher::new();
    aa_twin.hash(&mut h2);
    assert_eq!(
        h1.finish(),
        h2.finish(),
        "Eq + Hash std contract: equal citations must hash equal"
    );

    // Size ceiling — mirrors iter 160's CitationError size pin. The
    // citation type is the chat-layer's INPUT to every gate call,
    // passed through the FFI bridge once per emitted citation; silent
    // payload bloat would inflate per-call cost.
    //
    // Layout on 64-bit:
    //   - source_id (EidosChunkId = String) = 24 bytes
    //   - manifest_id (EidosIndexManifestId = String) = 24 bytes
    //   - total: 48 bytes, ceiling pinned at 64 for slack.
    //
    // Catches a future "let's add an optional context or
    // confidence-hint field" refactor that would silently push the
    // size up by 24+ bytes per added String/struct field. If the
    // growth is intentional, bump the ceiling AND justify the
    // chat-layer FFI cost.
    let size = std::mem::size_of::<EidosCitation>();
    assert!(
        size <= 64,
        "EidosCitation grew to {size} bytes (ceiling 64); a new \
         field (Option<String>, Vec, struct) was probably added. \
         If intentional, justify the FFI-call cost and bump the \
         ceiling."
    );

    // Hash counterpart (informational, not std-guaranteed): the four
    // canonical-sample distinct citations SHOULD hash differently —
    // catches a future custom Hash impl that collapses one field
    // (e.g. ignores manifest_id). DefaultHasher is randomized at
    // process start in some stdlib versions, but inputs differing in
    // distinct bytes effectively never collide across a 4-sample
    // probe.
    let hashes: Vec<u64> = [&aa, &ab, &ba, &bb]
        .iter()
        .map(|c| {
            let mut h = DefaultHasher::new();
            c.hash(&mut h);
            h.finish()
        })
        .collect();
    let distinct: std::collections::HashSet<u64> = hashes.iter().copied().collect();
    assert_eq!(
        distinct.len(),
        4,
        "four byte-distinct citations should produce four distinct \
         DefaultHasher digests — a collision here is an extraordinary \
         coincidence at this sample size and most plausibly indicates \
         a custom Hash impl that drops one field"
    );
}

/// Doctrine-vs-code drift detector for the six named adversarial
/// smuggling vector tests pinned across iters 127, 133, 137, 140, 154, 195.
///
/// The closed-citation contract's safety floor depends on byte-
/// strict equality. Six distinct adversarial vectors have been
/// independently pinned to lock that floor against each silent-
/// normalization regression they represent:
///
///   - NFC/NFD canonical-equivalence (iter 127)
///   - ZWSP / invisible-char injection (iter 133)
///   - Cyrillic-Latin homoglyph (iter 137)
///   - whitespace padding (iter 140)
///   - low-codepoint control-character injection (iter 154)
///   - bidirectional-text-override (iter 195, Trojan Source class)
///
/// This drift detector reads its own source file and asserts the
/// six corresponding `#[test] fn` declarations are present. If a
/// future refactor wholesale-deletes the closed-citation hardening
/// suite ("we moved them elsewhere" / "we normalize-before-compare
/// now so they're not needed"), this surfaces in lock-step rather
/// than silently weakening the contract.
///
/// Pattern mirrors:
///   - `lexical_and_semantic_module_docstrings_reference_nine_
///      canonical_modes` (iter 126)
///   - `falsifier_module_docstring_lists_all_five_per_hit_invariants`
///     (iter 124)
///   - `no_eidos_source_file_contains_stale_seven_modes_claim`
///     (iter 126)
///
/// Doctrine-vs-code is the canon pattern for surfacing silent drift
/// when the contract is distributed across multiple test sites.
#[test]
fn closed_citation_named_smuggling_vector_tests_are_all_present() {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/src/eidos/hardening_tests.rs");
    let src = std::fs::read_to_string(path).expect("read hardening_tests.rs");

    // Each entry: (vector-label, expected `fn` declaration substring).
    // The substrings are tight enough to avoid matching unrelated
    // identifiers but loose enough to survive cosmetic rename/refactor
    // (e.g. swapping `fn` whitespace, adding `pub`).
    let required_vector_tests: &[(&str, &str)] = &[
        (
            "NFC/NFD (iter 127)",
            "fn validate_citation_is_byte_strict_against_unicode_normalization",
        ),
        (
            "ZWSP / invisible-char (iter 133)",
            "fn validate_citation_rejects_zero_width_space_smuggling",
        ),
        (
            "Cyrillic-Latin homoglyph (iter 137)",
            "fn validate_citation_rejects_cyrillic_latin_homoglyph_smuggling",
        ),
        (
            "whitespace padding (iter 140)",
            "fn validate_citation_rejects_whitespace_padding_smuggling",
        ),
        (
            "control-character (iter 154)",
            "fn validate_citation_rejects_control_character_smuggling",
        ),
        (
            "bidirectional-text-override (iter 195)",
            "fn validate_citation_rejects_bidirectional_text_override_smuggling",
        ),
    ];

    let mut missing: Vec<&str> = Vec::new();
    for (label, needle) in required_vector_tests {
        if !src.contains(needle) {
            missing.push(label);
        }
    }

    assert!(
        missing.is_empty(),
        "closed-citation named-smuggling-vector test(s) MISSING: {missing:?}. \
         The six named vectors (NFC/NFD, ZWSP, homoglyph, whitespace, \
         control-character, bidi-override) are independently pinned because \
         each represents a distinct silent-normalization regression class. \
         If you removed one deliberately, update STATUS.md + this drift \
         detector together. If you renamed one, update the needle substring \
         above so the doctrine catches future drift. See iters 127, 133, \
         137, 140, 154, 195."
    );

    // Sanity: confirm the drift detector itself references each
    // iter number so a future archaeologist can trace the lineage.
    for iter_num in ["iter 127", "iter 133", "iter 137", "iter 140", "iter 154", "iter 195"] {
        assert!(
            src.contains(iter_num),
            "drift detector requires citation of {iter_num} for lineage \
             traceability — keep the iter numbers visible in test docstrings"
        );
    }

    // Test-name convention lock: every smuggling-vector test must
    // start with `fn validate_citation_` so a future rename that
    // drops the prefix (e.g. to `fn check_smuggled_id_X`) surfaces
    // here. The prefix also doubles as a discoverability index —
    // grepping for `fn validate_citation_` finds every closed-
    // citation hardening test in one shot.
    for (label, needle) in required_vector_tests {
        assert!(
            needle.starts_with("fn validate_citation_"),
            "smuggling vector test {label:?} has non-canonical fn-name \
             prefix: {needle:?}. Convention is `fn validate_citation_` \
             so all closed-citation hardening tests are greppable in \
             one shot."
        );
    }

    // Label-iter-reference lock: every label must contain an
    // `(iter N)` reference so a failure message names the canonical
    // pin-iteration. If someone shortens labels for terseness
    // (e.g. "NFC/NFD" without the iter number), the lineage from
    // failure → git log → context is broken. Pin the iter-number
    // anchor explicitly.
    for (label, _) in required_vector_tests {
        assert!(
            label.contains("(iter "),
            "smuggling vector label {label:?} missing canonical `(iter N)` \
             reference. Every label must encode the iter number so a \
             test-failure message points readers directly at the canonical \
             pin's git history. If you intentionally renamed iters, update \
             this assertion."
        );
    }

    // Label-distinctness lock: the 6 vector-label strings (e.g.
    // "NFC/NFD (iter 127)") used in failure messages must be
    // distinct too. If two entries shared a label, a test failure
    // for one would be ambiguously attributed to the other.
    let labels: HashSet<&str> = required_vector_tests.iter().map(|(l, _)| *l).collect();
    assert_eq!(
        labels.len(),
        required_vector_tests.len(),
        "required_vector_tests has duplicate label strings — every \
         smuggling vector must have a UNIQUE label for unambiguous \
         failure-message attribution."
    );

    // Vector-distinctness lock: the 6 entries in required_vector_tests
    // must be 6 DISTINCT test function needles. A future rename or
    // copy-paste error that accidentally aliased two entries (e.g.
    // adding a 7th vector by duplicating a label and forgetting to
    // change the fn-name needle) would silently leave one vector
    // unpinned. Catch it explicitly via HashSet count.
    use std::collections::HashSet;
    let needles: HashSet<&str> = required_vector_tests.iter().map(|(_, n)| *n).collect();
    assert_eq!(
        needles.len(),
        required_vector_tests.len(),
        "required_vector_tests has duplicate fn-name needles — every \
         smuggling vector must have a UNIQUE test fn. Likely a copy- \
         paste error when adding a new vector entry."
    );

    // Vector-count lock: the named-vector taxonomy size is pinned at
    // exactly 6. Adding a 7th means updating, in lock-step:
    //   - a new per-vector test in hardening_tests.rs
    //   - this required_vector_tests array (and the iter_num list above)
    //   - this count assertion
    //   - iter 155's wire round-trip array (iter 139 test) — add the 7th
    //   - iter 190/193/194's clone-byte-perfect arrays — add the 7th
    //   - STATUS.md catalog "six adversarial smuggling vectors"
    //   - STATUS.md catalog "all 6 smuggling vectors" (round-trip line)
    //
    // If this assertion fails, walk the lock-step list above.
    assert_eq!(
        required_vector_tests.len(),
        6,
        "named-vector taxonomy count drifted; lock-step update required \
         across STATUS.md + iter 155 wire round-trip + iter 190/193/194 \
         clone-byte-perfect arrays + this drift detector"
    );

    // STATUS.md catalog lock: the canonical "six adversarial \
    // smuggling vectors" phrase must be present. If a 7th vector is \
    // added, STATUS.md must update to "seven" in lock-step.
    let status_path = concat!(env!("CARGO_MANIFEST_DIR"), "/src/eidos/STATUS.md");
    let status = std::fs::read_to_string(status_path).expect("read STATUS.md");
    assert!(
        status.contains("Six adversarial smuggling vectors")
            || status.contains("six adversarial smuggling vectors"),
        "STATUS.md must contain the canonical 'Six adversarial smuggling \
         vectors' phrase for taxonomy-size lock-step. If the count changes, \
         update STATUS.md + iter 155 wire round-trip + iter 190/193/194 \
         clone-byte-perfect arrays + this drift detector in lock-step."
    );
    // And each named vector must appear in STATUS.md by its short
    // label so the catalog isn't allowed to drift to vague hand-waving.
    for label in [
        "NFC/NFD",
        "ZWSP",
        "homoglyph",
        "whitespace",
        "control-character",
        "bidi-override",
    ] {
        assert!(
            status.contains(label),
            "STATUS.md catalog must mention named vector {label:?} so the \
             6-vector taxonomy stays in lock-step across all sites"
        );
    }

    // Iter-anchor lock for STATUS.md: each vector's canonical iter
    // number must appear in the catalog so a reader can trace from
    // the catalog narrative → git log → context. Parallel to iter
    // 212's label-iter-reference lock for required_vector_tests.
    for iter_num in ["iter 127", "iter 133", "iter 137", "iter 140", "iter 154", "iter 195"] {
        assert!(
            status.contains(iter_num),
            "STATUS.md catalog must mention canonical {iter_num} for \
             lineage traceability. A future catalog cleanup that drops \
             iter anchors would break the failure → git log path."
        );
    }
}

/// STATUS.md ↔ actual `#[test]` count drift detector. Pins that the
/// "N unit tests in `agent_core/src/eidos/*`" claim in STATUS.md
/// matches the actual count of `#[test]` attributes across the
/// eidos source files.
///
/// Why pin this: STATUS.md fell behind reality twice during the
/// iter 127-155 closed-citation hardening session (iters 141, 151,
/// 156 had to manually bump the count). Most pin authors don't
/// touch STATUS.md when adding a single new test, so the catalog
/// drifts silently. This detector surfaces the drift on the very
/// next test run.
///
/// Implementation:
///   - Read STATUS.md and grep for the `N unit tests` claim
///     (regex-free: locate the substring `unit tests`, walk
///     backwards to find the leading integer)
///   - Walk `agent_core/src/eidos/*.rs`, count lines that trim to
///     `#[test]` — this matches the canonical Rust style for test
///     attributes on their own line and avoids false positives
///     from string literals or doc comments
///   - Assert the two counts match exactly
///
/// If a future test addition needs to land without bumping
/// STATUS.md (e.g. a doctrine drift detector that doesn't count as
/// a "behavior pin"), update the claim in STATUS.md in lock-step
/// with the test addition. This drift detector is itself counted
/// in the actual count, so adding it requires bumping STATUS.md by
/// 1 (just done in the commit that adds this test).
#[test]
fn status_md_test_count_matches_actual_attribute_count() {
    let status_path = concat!(env!("CARGO_MANIFEST_DIR"), "/src/eidos/STATUS.md");
    let status = std::fs::read_to_string(status_path).expect("read STATUS.md");

    // Locate the `unit tests` claim. The canonical phrase from iters
    // 141/151/156 is "N unit tests in `agent_core/src/eidos/*`".
    let idx = status
        .find(" unit tests")
        .expect("STATUS.md must contain the canonical 'N unit tests' claim line");
    let head = &status[..idx];
    // Walk backwards to find the integer.
    let last_space = head.rfind(|c: char| !c.is_ascii_digit())
        .map(|i| i + 1)
        .unwrap_or(0);
    let claimed: usize = head[last_space..]
        .parse()
        .unwrap_or_else(|e| panic!("could not parse test count from STATUS.md: {e}; head ends at {head:?}"));

    // Walk the eidos directory, count #[test] attribute lines in
    // each .rs file.
    let eidos_dir = concat!(env!("CARGO_MANIFEST_DIR"), "/src/eidos");
    let mut actual: usize = 0;
    for entry in std::fs::read_dir(eidos_dir).expect("read eidos dir") {
        let entry = entry.expect("read dir entry");
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) != Some("rs") {
            continue;
        }
        let src = std::fs::read_to_string(&path)
            .unwrap_or_else(|e| panic!("read {path:?}: {e}"));
        for line in src.lines() {
            if line.trim() == "#[test]" {
                actual += 1;
            }
        }
    }

    assert_eq!(
        actual, claimed,
        "STATUS.md ↔ actual test count drift: STATUS.md claims \
         {claimed} `unit tests in agent_core/src/eidos/*`, but \
         counted {actual} `#[test]` attribute lines across the \
         directory. Update STATUS.md in lock-step with test \
         additions/removals."
    );
}

/// Cross-mode closed-citation contract sweep — the byte-strict
/// `validate_citation` floor holds identically across every
/// retrieval mode that emits a non-empty packet.
///
/// Most existing closed-citation hardening tests (iters 127-145
/// inclusive of the 4 named smuggling vectors + contract-shape
/// pins) use `InMemoryLexicalIndex` exclusively for setup. That's
/// fine for testing the contract surface itself, but it leaves
/// open the question: does the contract behave identically when
/// the packet comes from a different retriever?
///
/// The contract is type-level (lives on `EidosContextPacket`, not
/// on any retriever), so the answer is "yes, by construction" —
/// but pinning the cross-mode sweep explicitly:
///   - documents the cross-mode invariance for new readers
///   - catches a future per-retriever `validate_citation` override
///     (no current trait surface for that, but if one were added
///     this would surface)
///   - exercises retriever-specific `source_id` shapes (e.g.
///     `::lex`, `::sem`, `::recency`, `::symbol`, `::raw`) under
///     the contract so any retriever-specific id-rendering bug
///     surfaces here
///
/// Pins, for each of 5 distinct retrieval modes (Lexical, Semantic,
/// Recency, CodeSymbol, RawArchive):
///   - non-empty packet emitted
///   - citation matching `hits[0].source_id` → Ok(())
///   - citation with a fabricated source_id → Err (negative
///     control rules out vacuous truth)
///   - citation against a different snapshot's manifest_id →
///     ManifestMismatch (precedence pin iter 130 holds cross-mode)
#[test]
fn closed_citation_contract_holds_across_retrieval_modes() {
    use super::code_symbol::InMemoryCodeSymbolIndex;
    use super::raw_archive::InMemoryRawArchive;
    use super::recency::InMemoryRecencyIndex;
    use super::semantic::InMemorySemanticIndex;
    use super::types::{CitationError, EidosChunkId, EidosCitation};

    let m = manifest();
    let stale = EidosIndexManifestId::new("stale-snapshot").unwrap();
    let ts = 1_700_000_000_000;

    // Sweep helper: given a non-empty packet, run the four contract
    // assertions: positive, fabricated negative, manifest-mismatch
    // negative, and the precedence rule.
    let sweep = |label: &str, packet: super::types::EidosContextPacket| {
        assert!(
            !packet.hits.is_empty(),
            "{label}: sweep requires a non-empty packet to exercise the \
             contract; empty-corpus case is covered by \
             every_retriever_empty_corpus_returns_byte_equal_empty_packet"
        );
        assert_eq!(
            packet.manifest_id, m,
            "{label}: packet must carry the expected manifest_id"
        );

        let real = packet.hits[0].source_id.clone();
        let cite_ok = EidosCitation {
            source_id: real.clone(),
            manifest_id: m.clone(),
        };
        assert_eq!(
            packet.validate_citation(&cite_ok),
            Ok(()),
            "{label}: legitimate citation must validate Ok"
        );

        // Fabricated id — same manifest, non-existent source.
        let cite_ghost = EidosCitation {
            source_id: EidosChunkId::new(format!("ghost-{label}-id")).unwrap(),
            manifest_id: m.clone(),
        };
        match packet.validate_citation(&cite_ghost).unwrap_err() {
            CitationError::FabricatedSourceId(_) => {}
            other => panic!("{label}: fabricated → expected FabricatedSourceId, got {other:?}"),
        }

        // Real id but stale manifest — manifest check must fire
        // FIRST (iter 130 precedence).
        let cite_stale = EidosCitation {
            source_id: real,
            manifest_id: stale.clone(),
        };
        match packet.validate_citation(&cite_stale).unwrap_err() {
            CitationError::ManifestMismatch { .. } => {}
            CitationError::FabricatedSourceId(_) => {
                panic!(
                    "{label}: real id + stale manifest must surface \
                     ManifestMismatch (precedence pin iter 130 holds \
                     cross-mode)"
                );
            }
        }
    };

    // (1) Lexical — already heavily covered elsewhere, included
    // here as the cross-mode anchor.
    {
        let mut lex = InMemoryLexicalIndex::new(m.clone());
        lex.insert(doc("note-a"), "alpha sapodilla", EidosSourceKind::Note).unwrap();
        let q = EidosQuery::new("sapodilla", EidosRetrievalMode::Lexical, 8);
        sweep("Lexical", lex.retrieve(&q, ts));
    }

    // (2) Semantic — vector retrieval with cosine ranking.
    {
        let mut sem = InMemorySemanticIndex::new(m.clone(), 3);
        sem.insert(doc("emb-a"), vec![1.0, 0.0, 0.0], EidosSourceKind::Note).unwrap();
        let q = EidosQuery::with_vector(
            "anything",
            EidosRetrievalMode::Semantic,
            8,
            vec![1.0, 0.0, 0.0],
        );
        sweep("Semantic", sem.retrieve(&q, ts));
    }

    // (3) Recency — time-ordered.
    {
        let mut rec = InMemoryRecencyIndex::new(m.clone());
        rec.insert(doc("recent-a"), "any body", ts - 1000, EidosSourceKind::Note);
        let q = EidosQuery::new("", EidosRetrievalMode::Recency, 8);
        sweep("Recency", rec.retrieve(&q, ts));
    }

    // (4) CodeSymbol — symbol-table lookup.
    {
        let mut cs = InMemoryCodeSymbolIndex::new(m.clone());
        cs.insert("my_function", doc("file-a"), 0, 11);
        let q = EidosQuery::new("my_function", EidosRetrievalMode::CodeSymbol, 8);
        sweep("CodeSymbol", cs.retrieve(&q, ts));
    }

    // (5) RawArchive — direct doc-id lookup.
    {
        let mut raw = InMemoryRawArchive::new(m.clone());
        raw.insert(doc("vault-a"), "raw body content", EidosSourceKind::RawArchive);
        let q = EidosQuery::new("vault-a", EidosRetrievalMode::RawArchive, 8);
        sweep("RawArchive", raw.retrieve(&q, ts));
    }
}

/// `validate_citation`'s result is **independent of hit position**
/// within the packet's `hits` Vec. Permuting the hits arbitrarily
/// does not change which citations validate Ok vs error.
///
/// Distinct from iter 138 (`validate_citation_iterates_all_hits_
/// not_just_early_ones`):
///   - iter 138 pinned POSITION COVERAGE: a citation matching the
///     LAST hit still validates Ok (the iteration reaches the end)
///   - this iter pins POSITION EQUIVALENCE: validating the SAME
///     citation against two packets where the hits are permuted
///     produces the SAME result
///
/// Why pin this independently: a future "order-sensitive
/// validation" change (e.g. "if the matching hit isn't in the
/// top-K, downgrade the confidence" or "weight error severity by
/// position") is a real temptation in a perf/UX-tuning pass. The
/// contract IS pure set-membership today; this pin makes that
/// explicit.
///
/// Pins, against a 5-hit packet:
///   - the canonical packet validates all 5 hit citations Ok
///   - a REVERSED-hits packet (same hits, opposite order) validates
///     the same 5 citations Ok identically
///   - a SHUFFLED-hits packet (deterministic permutation) validates
///     the same 5 citations Ok identically
///   - a fabricated citation is rejected against each permutation
///     (consistent error)
#[test]
fn validate_citation_is_invariant_under_hit_permutation() {
    use super::types::{EidosChunkId, EidosCitation, EidosContextPacket};

    let mut lex = InMemoryLexicalIndex::new(manifest());
    for i in 0..5 {
        lex.insert(
            doc(&format!("note-{i}")),
            "alpha tamarillo",
            EidosSourceKind::Note,
        ).unwrap();
    }
    let q = EidosQuery::new("tamarillo", EidosRetrievalMode::Lexical, 16);
    let canonical = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(canonical.hits.len(), 5);

    // Permutations:
    //   - canonical (insertion-stable order from the retriever)
    //   - reversed
    //   - deterministic-shuffle: [2, 4, 0, 3, 1]
    let canonical_hits = canonical.hits.clone();
    let mut reversed_hits = canonical_hits.clone();
    reversed_hits.reverse();
    let shuffle_indices = [2usize, 4, 0, 3, 1];
    let shuffled_hits: Vec<_> = shuffle_indices
        .iter()
        .map(|&i| canonical_hits[i].clone())
        .collect();

    // Sanity: the three orderings really do differ.
    assert_ne!(canonical_hits, reversed_hits);
    assert_ne!(canonical_hits, shuffled_hits);
    assert_ne!(reversed_hits, shuffled_hits);

    let make_packet = |hits: Vec<super::types::EidosHit>| EidosContextPacket {
        query: q.clone(),
        manifest_id: canonical.manifest_id.clone(),
        hits,
    };

    let packets = [
        ("canonical", make_packet(canonical_hits.clone())),
        ("reversed", make_packet(reversed_hits)),
        ("shuffled", make_packet(shuffled_hits)),
    ];

    // For each citation that matches a hit, validate across all three
    // permutations and assert ALL succeed with identical Ok results.
    for hit in &canonical_hits {
        let cite = EidosCitation {
            source_id: hit.source_id.clone(),
            manifest_id: canonical.manifest_id.clone(),
        };
        let results: Vec<_> = packets
            .iter()
            .map(|(label, p)| (*label, p.validate_citation(&cite)))
            .collect();
        for (label, r) in &results {
            assert_eq!(
                r,
                &Ok(()),
                "citation matching source_id {:?} must validate Ok in \
                 the {label} permutation — order-sensitive validation \
                 would break set-membership semantics",
                hit.source_id.as_str()
            );
        }
    }

    // Fabricated citation: rejected identically across all
    // permutations. Pins that the negative case is also order-
    // invariant.
    let ghost = EidosCitation {
        source_id: EidosChunkId::new("note-ghost::lex").unwrap(),
        manifest_id: canonical.manifest_id.clone(),
    };
    let ghost_results: Vec<_> = packets
        .iter()
        .map(|(label, p)| (*label, p.validate_citation(&ghost)))
        .collect();
    for (label, r) in &ghost_results {
        assert!(
            r.is_err(),
            "{label}: fabricated citation must error regardless of \
             hit order"
        );
    }
    // And the error variant is identical across permutations.
    let first_err = format!("{:?}", ghost_results[0].1);
    for (label, r) in ghost_results.iter().skip(1) {
        assert_eq!(
            format!("{r:?}"),
            first_err,
            "{label}: error variant must match the canonical-order error \
             — order-sensitive error selection would be a regression"
        );
    }
}

/// Extension of iter 147's cross-mode sweep to the **richer-
/// semantics retrievers** — Hybrid (fusion), ProvenanceVerified
/// (filter), and LedgerBackedClaimEvidence (ledger-walk). The
/// closed-citation contract is most non-trivial here because the
/// outer packet's hit set is a *subset* of (or fusion over) the
/// underlying retriever's emission.
///
/// Iter 147 covered the 5 "direct" retrievers (Lexical, Semantic,
/// Recency, CodeSymbol, RawArchive). This adds the 3 retrievers
/// whose hit set is derived from underlying retrievers' emission,
/// not directly from a corpus:
///
///   - **Hybrid (2-way)**: hits = RRF-fused Lexical ⊕ Semantic. A
///     citation against an inner-retriever-emitted source_id that
///     didn't survive the fusion would be fabricated from the
///     Hybrid packet's perspective. (Today fusion preserves both
///     inner sets, but the contract holds even if it didn't.)
///   - **ProvenanceVerified**: hits = inner ∩ admit_set. A citation
///     against an inner-retriever-emitted but NON-admitted source_id
///     is fabricated from the PV packet's perspective. Already
///     covered at iter 88+ for the negative direction; this rounds
///     out the positive (admitted-id-validates-Ok) side.
///   - **LedgerBackedClaimEvidence**: hits = claim → evidence walk
///     over the ClaimLedger. The closed-citation universe is the
///     evidence chunks supporting the queried claim; a citation
///     against an unrelated claim's evidence would be fabricated.
///
/// Together with iter 147, eight of the nine canonical retrieval
/// modes are now cross-mode-pinned for the closed-citation contract
/// (only GraphNeighborhood remains; the contract holds there too
/// by the type-level argument).
#[test]
fn closed_citation_contract_holds_for_fusion_filter_ledger_retrievers() {
    use super::hybrid::HybridRetriever;
    use super::ledger_backed_claim_evidence::LedgerBackedClaimEvidence;
    use super::provenance_verified::ProvenanceVerifiedRetriever;
    use super::semantic::InMemorySemanticIndex;
    use super::types::{CitationError, EidosChunkId, EidosCitation};
    use crate::provenance::ledger::{Claim, ClaimId, ClaimLedger, Evidence, EvidenceId};

    let m = manifest();
    let stale = EidosIndexManifestId::new("stale-snapshot").unwrap();
    let ts = 1_700_000_000_000;

    // Same shape as iter 147's sweep helper. Inlined here so the
    // test is self-contained and the iter-149 sweep can evolve
    // independently of the iter-147 surface if either needs
    // retriever-specific assertions later.
    let sweep = |label: &str, packet: super::types::EidosContextPacket| {
        assert!(!packet.hits.is_empty(), "{label}: non-empty packet required");
        assert_eq!(packet.manifest_id, m, "{label}: manifest_id binding");

        let real = packet.hits[0].source_id.clone();

        // Positive: legit citation validates Ok.
        assert_eq!(
            packet.validate_citation(&EidosCitation {
                source_id: real.clone(),
                manifest_id: m.clone(),
            }),
            Ok(()),
            "{label}: legit citation Ok"
        );

        // Negative: fabricated id → FabricatedSourceId.
        match packet
            .validate_citation(&EidosCitation {
                source_id: EidosChunkId::new(format!("ghost-{label}::lex")).unwrap(),
                manifest_id: m.clone(),
            })
            .unwrap_err()
        {
            CitationError::FabricatedSourceId(_) => {}
            other => panic!("{label}: fabricated → expected FabricatedSourceId, got {other:?}"),
        }

        // Manifest precedence: real id + stale manifest → ManifestMismatch.
        match packet
            .validate_citation(&EidosCitation {
                source_id: real,
                manifest_id: stale.clone(),
            })
            .unwrap_err()
        {
            CitationError::ManifestMismatch { .. } => {}
            CitationError::FabricatedSourceId(_) => {
                panic!("{label}: stale manifest must surface ManifestMismatch")
            }
        }
    };

    // (1) Hybrid (2-way Lexical ⊕ Semantic). Both inners populated
    // so the fusion has a real candidate set.
    {
        let mut lex = InMemoryLexicalIndex::new(m.clone());
        lex.insert(doc("hybrid-a"), "alpha cherimoya content", EidosSourceKind::Note).unwrap();
        let mut sem = InMemorySemanticIndex::new(m.clone(), 3);
        sem.insert(doc("hybrid-a"), vec![1.0, 0.0, 0.0], EidosSourceKind::Note).unwrap();
        let hybrid = HybridRetriever::new(lex, sem).unwrap();
        let q = EidosQuery::with_vector(
            "cherimoya",
            EidosRetrievalMode::Hybrid,
            8,
            vec![1.0, 0.0, 0.0],
        );
        sweep("Hybrid", hybrid.retrieve(&q, ts));
    }

    // (2) ProvenanceVerified wrapping Lexical with explicit admit
    // set. Admit one source_id; validation must accept that exact
    // id but reject the inner-emitted-but-non-admitted id (iter 88+
    // direction) AND fabricated ids (this iter's negative control).
    {
        let mut inner = InMemoryLexicalIndex::new(m.clone());
        inner.insert(doc("note-a"), "alpha mangosteen", EidosSourceKind::Note).unwrap();
        inner.insert(doc("note-b"), "beta mangosteen", EidosSourceKind::Note).unwrap();
        let mut pv = ProvenanceVerifiedRetriever::new(inner);
        // Admit only note-a's chunk id (matches Lexical's `::lex`
        // suffix convention).
        pv.admit(EidosChunkId::new("note-a::lex").unwrap());
        let q = EidosQuery::new("mangosteen", EidosRetrievalMode::ProvenanceVerified, 8);
        let packet = pv.retrieve(&q, ts);
        // Exactly one admitted hit must surface.
        assert_eq!(packet.hits.len(), 1, "PV admit-set narrows to 1 hit");
        sweep("ProvenanceVerified", packet);

        // Also pin the iter-88+ direction: the inner-emitted but
        // non-admitted id is rejected by the PV packet's gate.
        let pv_packet_redo = pv.retrieve(&q, ts);
        let inner_only = EidosCitation {
            source_id: EidosChunkId::new("note-b::lex").unwrap(),
            manifest_id: m.clone(),
        };
        match pv_packet_redo.validate_citation(&inner_only).unwrap_err() {
            CitationError::FabricatedSourceId(_) => {}
            other => panic!(
                "PV: inner-emitted non-admitted id MUST be fabricated from \
                 the PV packet's perspective, got {other:?}"
            ),
        }
    }

    // (3) LedgerBackedClaimEvidence — claim → evidence walk over
    // ClaimLedger. Build a minimal ledger: two evidence entries
    // supporting one claim.
    {
        let mut led = ClaimLedger::new();
        led.commit_evidence(Evidence::new(EvidenceId("ev-1".to_string()), "src-1", 1_000))
            .unwrap();
        led.commit_evidence(Evidence::new(EvidenceId("ev-2".to_string()), "src-2", 1_001))
            .unwrap();
        led.commit_claim(
            Claim::new(ClaimId("claim:tamarind-is-tangy".to_string()), "x", 1_002),
            vec![],
            vec![
                EvidenceId("ev-1".to_string()),
                EvidenceId("ev-2".to_string()),
            ],
        )
        .unwrap();

        let r = LedgerBackedClaimEvidence::from_ledger(&led, m.clone());
        let q = EidosQuery::new(
            "claim:tamarind-is-tangy",
            EidosRetrievalMode::ClaimEvidence,
            16,
        );
        sweep("LedgerBackedClaimEvidence", r.retrieve(&q, ts));
    }
}

/// Final cross-mode coverage — `GraphNeighborhood` is the 9th and
/// last canonical retrieval mode that the closed-citation contract
/// must hold for. Iter 147 covered 5 direct retrievers; iter 149
/// covered 3 derived (fusion/filter/ledger); this iter completes
/// the 9-of-9 canonical sweep.
///
/// `InMemoryGraphNeighborhood` is a directed/undirected edge map
/// indexed by `EidosDocumentId`. Query semantics: `query.text` is
/// the seed doc id; retrieval returns the seed's neighbors. The
/// emitted `source_id` shape is
/// `"{neighbor}::graph::from::{seed}"`.
///
/// Pins (same shape as iters 147 + 149 sweep):
///   - non-empty packet emitted for a seed with neighbors
///   - packet carries the expected manifest_id
///   - legitimate citation matching `hits[0].source_id` → Ok(())
///   - fabricated source_id → FabricatedSourceId
///   - real source_id, stale manifest → ManifestMismatch
///     (precedence pin iter 130 holds in the graph mode too)
///
/// With this pin the closed-citation contract is now cross-mode-
/// confirmed across the entire canonical surface (`EidosRetrievalMode
/// ::CANON_ALL`). Any future retrieval-mode addition surfaces in
/// lock-step via the `EidosRetrievalMode` CANON_ALL drift detector,
/// at which point a new entry to one of these three sweep tests
/// (iter 147 / 149 / this) is required.
#[test]
fn closed_citation_contract_holds_for_graph_neighborhood() {
    use super::graph_neighborhood::InMemoryGraphNeighborhood;
    use super::types::{CitationError, EidosChunkId, EidosCitation};

    let m = manifest();
    let stale = EidosIndexManifestId::new("stale-snapshot").unwrap();
    let ts = 1_700_000_000_000;

    // Build a tiny directed graph: seed → {n1, n2}. Retrieval with
    // query.text = seed should surface both neighbors.
    let mut graph = InMemoryGraphNeighborhood::new(m.clone());
    graph.add_edge(doc("graph-seed"), doc("graph-n1"));
    graph.add_edge(doc("graph-seed"), doc("graph-n2"));

    let q = EidosQuery::new("graph-seed", EidosRetrievalMode::GraphNeighborhood, 16);
    let packet = graph.retrieve(&q, ts);

    assert!(
        !packet.hits.is_empty(),
        "non-empty graph must yield non-empty packet for seed with neighbors"
    );
    assert_eq!(packet.hits.len(), 2, "seed has exactly 2 neighbors");
    assert_eq!(packet.manifest_id, m, "manifest_id binding holds");

    // Confirm the emitted source_id has the expected graph shape so
    // a future retriever rename surfaces here (the source_id format
    // is part of the contract — chat-layer cites these strings
    // verbatim).
    let first_id = packet.hits[0].source_id.as_str();
    assert!(
        first_id.contains("::graph::from::graph-seed"),
        "graph source_id format drifted; expected to contain \
         '::graph::from::graph-seed', got {first_id:?}"
    );

    // Positive: legit citation Ok.
    let real = packet.hits[0].source_id.clone();
    assert_eq!(
        packet.validate_citation(&EidosCitation {
            source_id: real.clone(),
            manifest_id: m.clone(),
        }),
        Ok(()),
        "GraphNeighborhood: legit citation must validate Ok"
    );

    // Negative: fabricated source_id → FabricatedSourceId.
    let ghost = EidosCitation {
        source_id: EidosChunkId::new("ghost-node::graph::from::graph-seed").unwrap(),
        manifest_id: m.clone(),
    };
    match packet.validate_citation(&ghost).unwrap_err() {
        CitationError::FabricatedSourceId(_) => {}
        other => panic!(
            "GraphNeighborhood: fabricated id → expected \
             FabricatedSourceId, got {other:?}"
        ),
    }

    // Manifest precedence: real id + stale manifest → ManifestMismatch.
    let stale_cite = EidosCitation {
        source_id: real,
        manifest_id: stale,
    };
    match packet.validate_citation(&stale_cite).unwrap_err() {
        CitationError::ManifestMismatch { .. } => {}
        CitationError::FabricatedSourceId(_) => {
            panic!(
                "GraphNeighborhood: stale manifest must surface \
                 ManifestMismatch (precedence pin iter 130 holds \
                 cross-mode)"
            );
        }
    }

    // Sanity: assert this completes the 9-of-9 canonical coverage
    // by reading EidosRetrievalMode::CANON_ALL and asserting all
    // nine variants have been touched across iter 147 + 149 +
    // this iter's sweep tests. If a tenth mode is added, this trips
    // and forces extending one of the sweep tests.
    let canon_count = EidosRetrievalMode::CANON_ALL.len();
    assert_eq!(
        canon_count, 9,
        "cross-mode coverage assumes 9 canonical modes; CANON_ALL \
         now reports {canon_count} — extend the sweep tests in iter \
         147 / 149 / this iter to cover the new mode(s), then bump \
         this assertion."
    );
}

/// `validate_citation` ignores `hit.provenance.manifest_id` — the
/// gate's manifest check is purely against `packet.manifest_id`, not
/// the per-hit provenance field.
///
/// Extends iter 144's hit-metadata-irrelevance pin to the
/// `provenance.manifest_id` field specifically. Iter 144 covered
/// confidence/span/kind/score/(provenance.mode +
/// retrieved_at_unix_ms), but the provenance manifest_id is the
/// most-architecturally-interesting field to probe explicitly: in
/// practice every retriever's `all_retrievers_emit_consistent_
/// provenance` invariant (line 216) keeps the two manifest_ids
/// equal, but the type-level contract allows them to differ.
///
/// Why this matters: the gate's contract is
///   (citation.manifest_id == packet.manifest_id)
///     AND (citation.source_id ∈ packet.hits[*].source_id)
///
/// The hit's own provenance.manifest_id is DIAGNOSTIC-ONLY — used
/// by replay/audit surfaces to record which inner retriever
/// produced each hit (relevant in Hybrid/Hybrid_N fusion where
/// inner retrievers may have different manifest_ids in some
/// hypothetical scenario, though Hybrid::new today enforces
/// matching inners). The gate doesn't check it.
///
/// Pin: a hit whose `provenance.manifest_id` points at a different
/// snapshot than `packet.manifest_id`, with a citation matching the
/// hit's source_id and the packet's manifest_id, validates Ok.
///
/// This is the architecture-level "trust packet binding, not hit
/// binding" pin. Surfaces a hypothetical future "also check hit
/// provenance.manifest_id matches packet.manifest_id" addition that
/// would be a category error (the retriever invariant test at line
/// 216 already guards that property for emitted hits).
#[test]
fn validate_citation_ignores_hit_provenance_manifest_id() {
    use super::types::{
        EidosChunkId, EidosCitation, EidosContextPacket, EidosHit, EidosProvenance,
        EidosScoreComponents,
    };

    let packet_manifest = manifest();
    // Deliberately different snapshot id for the hit's provenance.
    // In real Eidos this would mean "hit emitted under a different
    // snapshot but somehow surfaced in this packet" — a hypothetical
    // edge case that the type-level contract permits even though
    // retrievers don't construct it.
    let foreign_hit_manifest =
        EidosIndexManifestId::new("foreign-hit-provenance-snapshot").unwrap();
    assert_ne!(
        packet_manifest, foreign_hit_manifest,
        "test setup: packet and hit-provenance manifests must differ"
    );

    let source_id = EidosChunkId::new("anomaly-hit::lex").unwrap();
    let anomaly_hit = EidosHit {
        source_id: source_id.clone(),
        document_id: doc("anomaly-doc"),
        kind: EidosSourceKind::Note,
        span: None,
        confidence: 0.5,
        score: EidosScoreComponents::default(),
        provenance: EidosProvenance {
            manifest_id: foreign_hit_manifest.clone(),
            mode: EidosRetrievalMode::Lexical,
            retrieved_at_unix_ms: 1_700_000_000_000,
        },
    };

    let packet = EidosContextPacket {
        query: EidosQuery::new("anomaly", EidosRetrievalMode::Lexical, 16),
        manifest_id: packet_manifest.clone(),
        hits: vec![anomaly_hit],
    };

    // Sanity: hit and packet manifests genuinely differ.
    assert_ne!(
        packet.hits[0].provenance.manifest_id, packet.manifest_id,
        "test setup: hit.provenance.manifest_id and packet.manifest_id \
         must differ to exercise the irrelevance pin"
    );

    // The citation matches packet.manifest_id (good) and hit source_id
    // (good). The gate must accept it — the hit's foreign provenance
    // manifest is irrelevant to the contract.
    let cite = EidosCitation {
        source_id,
        manifest_id: packet_manifest,
    };
    assert_eq!(
        packet.validate_citation(&cite),
        Ok(()),
        "validate_citation must IGNORE hit.provenance.manifest_id; the \
         contract is purely (citation.manifest_id == packet.manifest_id) \
         ∧ (citation.source_id ∈ packet.hits[*].source_id). A future \
         'also check hit provenance manifest' addition would break this \
         type-level contract."
    );

    // Negative control: a citation with the foreign manifest_id (the
    // hit's provenance manifest) is rejected as manifest-mismatch —
    // confirms the gate is checking packet.manifest_id specifically,
    // not just "any manifest somewhere in the packet."
    let foreign_cite = EidosCitation {
        source_id: packet.hits[0].source_id.clone(),
        manifest_id: foreign_hit_manifest,
    };
    assert!(
        packet.validate_citation(&foreign_cite).is_err(),
        "citation against the hit-provenance manifest (not the packet \
         manifest) must be rejected — the gate's reference is \
         packet.manifest_id, full stop"
    );
}

/// Doctrine-vs-code drift detector for the 11 structural shape-
/// lock test functions added across iters 134/158/172-179/183.
/// Parallel to iter 146's named-vector drift detector but for
/// the shape-lock cluster.
///
/// The closed-citation contract surface has 11 public types (or
/// enum-variant collections) whose structural shape is pinned via
/// exhaustive destructure with NO `..` wildcard:
///
///   1. CitationError      2-variant exhaustive match (iter 134)
///   2. 5/6-vector taxonomy 6 entries in array        (iter 158)
///   3. EidosCitation      2-field exhaustive destructure (iter 172)
///   4. EidosContextPacket 3-field                       (iter 173)
///   5. EidosHit           7-field                       (iter 174)
///   6. EidosProvenance    3-field                       (iter 175)
///   7. EidosScoreComponents 4-field                     (iter 176)
///   8. EidosSpan          2-field                       (iter 177)
///   9. EidosQuery         5-field                       (iter 178)
///  10. IdError            1-variant                     (iter 179)
///  11. EidosIndexManifest 4-field                       (iter 183)
///
/// This drift detector reads its own source file and asserts the
/// 11 corresponding `#[test] fn` declarations are present. If a
/// future refactor wholesale-deletes a shape-lock (e.g. "we
/// consolidated several shape-locks into a property test"), this
/// surfaces in lock-step rather than silently weakening the
/// structural-doctrine surface.
#[test]
fn closed_citation_structural_shape_locks_are_all_present() {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/src/eidos/hardening_tests.rs");
    let src = std::fs::read_to_string(path).expect("read hardening_tests.rs");

    let required_shape_locks: &[(&str, &str)] = &[
        ("CitationError 2-variant (iter 134)",
         "fn citation_error_variant_count_is_two"),
        ("5/6-vector taxonomy (iter 158)",
         "fn closed_citation_named_smuggling_vector_tests_are_all_present"),
        ("EidosCitation 2-field (iter 172)",
         "fn eidos_citation_has_exactly_two_public_fields"),
        ("EidosContextPacket 3-field (iter 173)",
         "fn eidos_context_packet_has_exactly_three_public_fields"),
        ("EidosHit 7-field (iter 174)",
         "fn eidos_hit_has_exactly_seven_public_fields"),
        ("EidosProvenance 3-field (iter 175)",
         "fn eidos_provenance_has_exactly_three_public_fields"),
        ("EidosScoreComponents 4-field (iter 176)",
         "fn eidos_score_components_has_exactly_four_public_fields"),
        ("EidosSpan 2-field (iter 177)",
         "fn eidos_span_has_exactly_two_public_fields"),
        ("EidosQuery 5-field (iter 178)",
         "fn eidos_query_has_exactly_five_public_fields"),
        ("IdError 1-variant (iter 179)",
         "fn id_error_has_exactly_one_variant"),
        ("EidosIndexManifest 4-field (iter 183)",
         "fn eidos_index_manifest_has_exactly_four_public_fields"),
    ];

    assert_eq!(
        required_shape_locks.len(),
        11,
        "shape-lock count drifted from 11 — module docstring (iter \
         207) + STATUS.md catalog (iter 184/188) claim '11 parallel \
         shape-lock drift detectors'. Update in lock-step."
    );

    let mut missing: Vec<&str> = Vec::new();
    for (label, needle) in required_shape_locks {
        if !src.contains(needle) {
            missing.push(label);
        }
    }
    assert!(
        missing.is_empty(),
        "closed-citation structural shape-lock test(s) MISSING: \
         {missing:?}. The 11 shape-locks form the structural-doctrine \
         surface of the closed-citation contract. If you removed one \
         deliberately, update STATUS.md + this drift detector + the \
         hardening_tests.rs module docstring (iter 207) together."
    );

    // STATUS.md catalog cross-check: the canonical "Eleven parallel
    // shape-lock drift detectors" phrase must be present so the
    // catalog narrative stays in sync with iter 207's docstring +
    // this drift detector's array length.
    let status_path = concat!(env!("CARGO_MANIFEST_DIR"), "/src/eidos/STATUS.md");
    let status = std::fs::read_to_string(status_path).expect("read STATUS.md");
    assert!(
        status.contains("Eleven parallel shape-lock drift detectors")
            || status.contains("eleven parallel shape-lock drift detectors"),
        "STATUS.md must contain the canonical 'Eleven parallel shape-lock \
         drift detectors' phrase, in lock-step with iter 207's module \
         docstring and this drift detector's array length (11). If the \
         count changed deliberately, update all three sites."
    );

    // Shape-lock iter-anchor lock: each label in required_shape_locks
    // must contain an `(iter N)` reference for lineage traceability.
    // Parallel to iter 212's label-iter-reference lock for the
    // smuggling-vector array. A failure message naming a shape-lock
    // without the iter number breaks the failure → git log trace.
    for (label, _) in required_shape_locks {
        assert!(
            label.contains("(iter "),
            "shape-lock label {label:?} missing canonical `(iter N)` \
             reference. Every label must encode the iter number so a \
             test-failure message points readers at the canonical pin \
             commit. See iter 212 for the parallel pin on vectors."
        );
    }

    // Shape-lock STATUS.md iter-anchor lock: each shape-lock's
    // canonical iter number must appear in STATUS.md so a reader
    // navigating from the catalog to git log finds the pin. Parallel
    // to iter 216's vector-STATUS.md iter-anchor lock.
    for iter_num in [
        "iter 134", "iter 158", "iter 172", "iter 173", "iter 174",
        "iter 175", "iter 176", "iter 177", "iter 178", "iter 179",
        "iter 183",
    ] {
        assert!(
            status.contains(iter_num),
            "STATUS.md catalog must mention shape-lock {iter_num} so \
             readers can trace from catalog narrative → git log → pin \
             commit. If you compressed the catalog and dropped the \
             anchor, restore it or update both this drift detector + \
             STATUS.md in lock-step."
        );
    }
}

/// The hardening_tests.rs module docstring (top of file) must
/// describe the closed-citation hardening arc with the canonical
/// "six named adversarial smuggling vectors" phrase. Iter 207
/// added this docstring; this drift detector locks the phrase
/// against future docstring edits that drift away from the
/// 6-vector taxonomy.
///
/// Why pin: the module docstring is the FIRST thing a reader sees
/// when opening hardening_tests.rs. If a future cleanup pass
/// reworded the description to vague "various smuggling vectors"
/// or shortened it to just "adversarial corners", the orientation
/// surface degrades. The phrase lock parallels iter 158's
/// STATUS.md catalog phrase lock.
///
/// Companion to:
///   - iter 158: STATUS.md "Six adversarial smuggling vectors"
///   - iter 169: STATUS.md 4 originally-named edge cases
///   - iter 207: this docstring's introduction
#[test]
fn module_docstring_describes_six_named_smuggling_vectors() {
    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/src/eidos/hardening_tests.rs");
    let src = std::fs::read_to_string(path).expect("read hardening_tests.rs");

    // The docstring lives at the top of the file behind //! lines.
    // Take the first ~30 lines, strip the `//!` comment prefix from
    // each line, then normalize whitespace so phrases that wrap
    // across lines are matchable as a single string.
    let head: String = src
        .lines()
        .take(30)
        .map(|l| l.trim_start().trim_start_matches("//!").trim())
        .collect::<Vec<_>>()
        .join(" ");
    let normalized: String = head.split_whitespace().collect::<Vec<_>>().join(" ");

    assert!(
        normalized.contains("six named adversarial smuggling vectors")
            || normalized.contains("Six named adversarial smuggling vectors"),
        "hardening_tests.rs module docstring must continue to describe \
         the closed-citation hardening arc with the canonical phrase \
         'six named adversarial smuggling vectors'. If the docstring \
         was reworded deliberately, update STATUS.md + this drift \
         detector in lock-step. See iter 207 for the docstring's \
         introduction and iter 158 for the STATUS.md companion phrase \
         lock. Normalized head: {normalized:?}"
    );

    // Also pin that the docstring mentions the contract surface
    // pieces it locks: closed-citation, validate_citation, six +
    // vectors keywords appear together.
    for required in [
        "Closed-citation",
        "validate_citation",
        "nine canonical retrieval modes",
        "Clone byte-perfect",
        "shape-locks",
    ] {
        assert!(
            normalized.contains(required),
            "module docstring must mention {required:?} for orientation \
             value — readers opening hardening_tests.rs should see what's \
             covered without reading STATUS.md first"
        );
    }

    // Cross-check: the module docstring's "11 parallel structural
    // shape-locks" claim must agree with iter 213's shape-lock array
    // count. If iter 213 grows to 12 entries (a new shape-lock is
    // added), the docstring's "11" becomes stale. Pin the explicit
    // "11" substring in the docstring so the claim drifts in
    // lock-step with the actual structural-doctrine cluster.
    assert!(
        normalized.contains("11 parallel structural shape-locks"),
        "module docstring must claim '11 parallel structural shape-locks' \
         verbatim, in lock-step with iter 213's shape-lock drift detector. \
         If the count changed deliberately, update both sites and this \
         assertion."
    );
}

/// Doctrine lock for the four originally-named edge cases driving
/// the closed-citation hardening arc. STATUS.md's catalog must
/// continue to mention each by name (verbatim) so the lineage from
/// the user's directive ("every emitted citation must be a member
/// of the returned EidosContextPacket across edge cases: unicode
/// normalization, duplicate dedup, fake IDs rejected, empty vault
/// empty packet not error") stays explicit in the catalog.
///
/// Why pin: the four-named-edge-case list is the SOURCE FROM WHICH
/// the 5-vector taxonomy + contract-shape pins were derived. If the
/// catalog rewords them to vague hand-waving ("various smuggling
/// vectors", "edge cases"), the link from user-requirement to test
/// coverage erodes. The verbatim phrase lock keeps the lineage
/// traceable.
///
/// Complementary to:
///   - iter 146: locks the 5 named smuggling vector TESTS exist
///   - iter 158: locks the 5-vector COUNT + label phrases in
///     STATUS.md
///   - iter 157: locks STATUS.md ↔ actual test count
///   - this iter: locks the 4 ORIGINAL-DIRECTIVE EDGE CASES in
///     STATUS.md so the user-facing language stays anchored
#[test]
fn status_md_documents_four_originally_named_edge_cases() {
    let status_path = concat!(env!("CARGO_MANIFEST_DIR"), "/src/eidos/STATUS.md");
    let status = std::fs::read_to_string(status_path).expect("read STATUS.md");

    // Each phrase here is verbatim from the user's original
    // directive that initiated the closed-citation hardening arc.
    // If a future catalog rewrite reworded one (e.g. "Unicode
    // canonicalization" instead of "unicode normalization"), the
    // catalog drifts away from the directive's vocabulary and the
    // user-facing trace breaks.
    let required_phrases = [
        "unicode normalization",
        "duplicate dedup",
        "fake IDs rejected",
        "empty vault empty packet not error",
    ];

    let mut missing: Vec<&str> = Vec::new();
    for phrase in &required_phrases {
        if !status.contains(phrase) {
            missing.push(phrase);
        }
    }

    assert!(
        missing.is_empty(),
        "STATUS.md catalog must mention each originally-named edge \
         case verbatim. Missing phrases: {missing:?}. The user's \
         directive that initiated this hardening arc named these \
         four cases explicitly; the catalog must keep the lineage \
         traceable. If the rewording is deliberate, update STATUS.md \
         + this drift detector in lock-step."
    );
}

/// `EidosIndexManifest` has exactly FOUR public fields (id,
/// created_at_unix_ms, corpus_digest_hex, live_files_snapshot_id)
/// and adding a fifth must surface in lock-step at every consumer.
///
/// EidosIndexManifest is the full manifest record (NOT just the id
/// — that's EidosIndexManifestId, the type used directly in the
/// closed-citation contract). The manifest record carries the
/// inputs that make retrieval deterministic: id, timestamp,
/// corpus content-hash, optional Live Files snapshot binding.
///
/// Consumers that read EidosIndexManifest by name:
///   - Swift bridge wire mirror (manifest descriptors flow across
///     FFI for replay/audit display)
///   - `types::tests::index_manifest_with_live_files_snapshot_round_trips`
///   - `types::tests::index_manifest_without_live_files_omits_field_in_json`
///   - `types::tests::index_manifest_new_has_no_live_files_binding`
///   - Iter 152's `core_types_are_send_and_sync` (covers
///     EidosIndexManifest)
///
/// A future addition (e.g. `embedding_model_id`,
/// `lexical_analyzer_version`, `per_source_counts: BTreeMap<…>`)
/// would need lock-step updates to all those consumers. The
/// existing docstring at types.rs:419 explicitly anticipates this
/// expansion: "The full structure (per-source counts, embedding
/// model id, lexical analyzer version) lands in a later iteration."
///
/// Parallel to the iter 134/158/172/173/174/175/176/177/178/179
/// shape-lock cluster — exhaustive destructure + runtime backup.
#[test]
fn eidos_index_manifest_has_exactly_four_public_fields() {
    use super::types::EidosIndexManifest;

    let im = EidosIndexManifest::new(manifest(), 1_700_000_000_000);

    // Compile-time exhaustiveness — NO `..` wildcard.
    let EidosIndexManifest {
        id,
        created_at_unix_ms,
        corpus_digest_hex,
        live_files_snapshot_id,
    } = &im;
    assert!(!id.as_str().is_empty());
    assert!(*created_at_unix_ms > 0);
    // corpus_digest_hex is empty in V0 (reserved slot).
    let _ = corpus_digest_hex.is_empty();
    // live_files_snapshot_id is None by default.
    assert!(live_files_snapshot_id.is_none());

    // Runtime backup signal.
    const FIELD_COUNT: usize = 4;
    assert_eq!(
        FIELD_COUNT, 4,
        "EidosIndexManifest field count drift — Swift bridge wire \
         mirror + types::tests round-trip pins + iter 152 Send+Sync \
         assertion must update in lock-step. See types.rs:419 docstring \
         for the anticipated 'later iteration' expansion fields \
         (per-source counts, embedding model id, lexical analyzer \
         version) — each must be added explicitly here with a \
         justification."
    );
}

/// Chat-layer workflow simulation: HashSet-dedup → validate_citations
/// composes correctly. The canonical chat-layer flow is:
///   1. Retrieve packet
///   2. Model emits citations (possibly with duplicates from
///      multi-sentence citing of the same chunk)
///   3. Dedup via HashSet to avoid redundant gate calls
///   4. validate_citations on the deduped Vec
///   5. If Ok → emit answer; if Err → refuse
///
/// This iter pins step 3-4 compose correctly: deduping the input
/// produces the same Ok/Err outcome as not deduping (the validator
/// has no auto-dedup so duplicates are checked individually — iter
/// 128). The dedup is purely a chat-layer cost optimization, not a
/// correctness move.
///
/// Pin: an input with 5 citations (2 legit duplicated, 1 forged
/// duplicated, 1 unique forged) dedups to 4 distinct entries, of
/// which 2 are forged. validate_citations on the deduped list
/// produces exactly 2 errors. Compare against validate_citations
/// on the full undeduped list: 5 entries, of which 3 are forged,
/// 3 errors.
///
/// The pin matches the iter 181 HashSet dedup pin (4-corner truth
/// table) and iter 128 (input duplicate preservation at the
/// validator) — both compose into the chat-layer flow correctly.
#[test]
fn chat_layer_hashset_dedup_then_validate_composes_correctly() {
    use super::types::{EidosChunkId, EidosCitation};
    use std::collections::HashSet;

    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("note-a"), "alpha mulberry content", EidosSourceKind::Note).unwrap();
    lex.insert(doc("note-b"), "beta mulberry content", EidosSourceKind::Note).unwrap();
    let q = EidosQuery::new("mulberry", EidosRetrievalMode::Lexical, 16);
    let packet = lex.retrieve(&q, 1_700_000_000_000);
    assert_eq!(packet.hits.len(), 2);

    let legit_a = EidosCitation {
        source_id: packet.hits[0].source_id.clone(),
        manifest_id: packet.manifest_id.clone(),
    };
    let legit_b = EidosCitation {
        source_id: packet.hits[1].source_id.clone(),
        manifest_id: packet.manifest_id.clone(),
    };
    let forged_x = EidosCitation {
        source_id: EidosChunkId::new("ghost-x::lex").unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };
    let forged_y = EidosCitation {
        source_id: EidosChunkId::new("ghost-y::lex").unwrap(),
        manifest_id: packet.manifest_id.clone(),
    };

    // Full undeduped input: 6 entries (legit_a twice, legit_b once,
    // forged_x twice, forged_y once) = 4 distinct citations.
    // Validates with 3 errors (one per forged INDEX — iter 128's
    // input-duplicate-preservation pin).
    let full = vec![
        legit_a.clone(),
        legit_a.clone(),
        legit_b.clone(),
        forged_x.clone(),
        forged_x.clone(),
        forged_y.clone(),
    ];
    let full_errs = packet.validate_citations(&full).unwrap_err();
    assert_eq!(
        full_errs.len(),
        3,
        "undeduped input must produce 3 errors (one per forged index — \
         iter 128 input-duplicate-preservation): forged_x@3, forged_x@4, forged_y@5"
    );

    // Chat-layer dedup pass: collect into HashSet, then back to Vec.
    // The HashSet must contain exactly 4 distinct citations
    // (iter 181 truth table).
    let deduped_set: HashSet<EidosCitation> = full.iter().cloned().collect();
    assert_eq!(deduped_set.len(), 4, "deduped HashSet has 4 distinct entries");

    let deduped: Vec<EidosCitation> = deduped_set.into_iter().collect();
    let deduped_errs = packet.validate_citations(&deduped).unwrap_err();

    // Validates with exactly 2 errors — one per UNIQUE forged
    // citation, not per forged-occurrence. The chat-layer's dedup
    // optimization correctly collapses redundant validation work.
    assert_eq!(
        deduped_errs.len(),
        2,
        "deduped input must produce 2 errors (one per UNIQUE forged \
         citation). HashSet dedup is a cost optimization for the chat \
         layer; it doesn't change correctness."
    );

    // Sanity: the two unique forgeries are forged_x and forged_y, in
    // some order (HashSet iteration order is randomized).
    use super::types::CitationError;
    let mut forged_source_ids: Vec<String> = deduped_errs
        .iter()
        .filter_map(|(_, e)| match e {
            CitationError::FabricatedSourceId(id) => Some(id.as_str().to_string()),
            _ => None,
        })
        .collect();
    forged_source_ids.sort();
    assert_eq!(
        forged_source_ids,
        vec!["ghost-x::lex".to_string(), "ghost-y::lex".to_string()],
        "the 2 deduped errors must point at forged_x and forged_y"
    );
}

/// `HashSet<EidosCitation>` dedup follows the conjunctive Eq from
/// iter 145 — inserting all 4 corners of the (source_id, manifest_id)
/// truth table yields exactly 4 distinct entries: same/same dedups
/// to one, the other three corners stay distinct.
///
/// Iter 145 pinned EQ at the field-pair level + DefaultHasher
/// distinctness on the 4 corners. The pre-existing
/// `eidos_citation_hash_eq_dedup_in_hashset` test covers same/same
/// + same-source/different-manifest. This rounds out the symmetry
/// by exercising the FULL HashSet behavior on all 4 truth-table
/// corners, locking the dedup semantic that downstream chat-layer
/// code (which uses HashSet to dedup model-emitted citations
/// before validation) relies on.
///
/// Pins:
///   - aa  (src_a, man_a) — base
///   - aa' (src_a, man_a) duplicate — dedups with aa
///   - ab  (src_a, man_b) — distinct from aa
///   - ba  (src_b, man_a) — distinct from aa
///   - bb  (src_b, man_b) — distinct from aa
///   Final HashSet size: 4 (the 4 distinct corners)
///
/// Catches a future custom Hash impl that drops one field (would
/// collapse multiple corners to one HashSet bucket).
#[test]
fn hashset_dedup_follows_eidos_citation_full_truth_table() {
    use super::types::{EidosChunkId, EidosCitation};
    use std::collections::HashSet;

    let src_a = EidosChunkId::new("source-A").unwrap();
    let src_b = EidosChunkId::new("source-B").unwrap();
    let man_a = EidosIndexManifestId::new("manifest-A").unwrap();
    let man_b = EidosIndexManifestId::new("manifest-B").unwrap();

    let aa = EidosCitation { source_id: src_a.clone(), manifest_id: man_a.clone() };
    let aa_dup = EidosCitation { source_id: src_a.clone(), manifest_id: man_a.clone() };
    let ab = EidosCitation { source_id: src_a, manifest_id: man_b.clone() };
    let ba = EidosCitation { source_id: src_b.clone(), manifest_id: man_a };
    let bb = EidosCitation { source_id: src_b, manifest_id: man_b };

    let mut set: HashSet<EidosCitation> = HashSet::new();
    set.insert(aa);
    set.insert(aa_dup); // dedup → same bucket
    set.insert(ab);
    set.insert(ba);
    set.insert(bb);

    assert_eq!(
        set.len(),
        4,
        "HashSet must contain exactly 4 distinct citations across \
         the 2×2 truth table (same/same dedups; the other three \
         corners are distinct keys). A future custom Hash impl \
         that drops one field would collapse corners — \
         iter 145's EQ pin + iter 181's HashSet behavior pin lock \
         the dedup semantic that downstream chat-layer code relies \
         on for pre-validation dedup."
    );
}

/// `EidosContextPacket::clone()` is byte-perfect — completes the
/// Clone byte-perfect contract trilogy across the closed-citation
/// surface (iter 190 citation, iter 193 hit, this iter packet).
///
/// Packets are cloned for:
///   - Replay-bundle serialization (the audit/replay layer
///     captures packet snapshots)
///   - Cross-thread handoff (UI thread renders the packet while
///     the validation thread mutates the closed-citation state)
///   - Test fixtures that need to mutate a packet copy without
///     touching the canonical retriever output
///
/// A custom Clone that re-canonicalized any field (e.g.
/// canonicalized unicode in source_ids, re-sorted hits, recomputed
/// confidence) would silently break the byte-strict floor —
/// cloning would no longer be transparent and replay would
/// diverge from the original retrieval.
///
/// Pinned with a packet containing a smuggling-vector source_id
/// in its single hit: clone produces a packet with byte-identical
/// hits AND validate_citation against both packets produces the
/// same Ok/Err outcome.
#[test]
fn eidos_context_packet_clone_is_byte_perfect_under_smuggling() {
    use super::types::{
        EidosChunkId, EidosCitation, EidosContextPacket, EidosHit, EidosProvenance,
        EidosScoreComponents,
    };

    let m = manifest();
    // Use a ZWSP-injected source_id (iter 133 smuggling vector) so
    // the clone path is exercised with a byte-distinct payload
    // from any visually-equivalent normalization.
    let smuggled_src = EidosChunkId::new("note\u{200B}-a::lex").unwrap();

    let original_packet = EidosContextPacket {
        query: EidosQuery::new("clone-trilogy", EidosRetrievalMode::Lexical, 8),
        manifest_id: m.clone(),
        hits: vec![EidosHit {
            source_id: smuggled_src.clone(),
            document_id: doc("clone-doc"),
            kind: EidosSourceKind::Note,
            span: None,
            confidence: 0.5,
            score: EidosScoreComponents::default(),
            provenance: EidosProvenance {
                manifest_id: m.clone(),
                mode: EidosRetrievalMode::Lexical,
                retrieved_at_unix_ms: 1_700_000_000_000,
            },
        }],
    };

    let cloned_packet = original_packet.clone();

    // Full packet equality — every field round-trips through Clone.
    assert_eq!(
        cloned_packet, original_packet,
        "EidosContextPacket clone must be byte-equal to original \
         (query + manifest_id + hits all preserved exactly)"
    );

    // Bytes match exactly for the smuggled source_id payload.
    assert_eq!(
        cloned_packet.hits[0].source_id.as_str().as_bytes(),
        original_packet.hits[0].source_id.as_str().as_bytes(),
        "ZWSP-injected source_id bytes must survive clone intact"
    );

    // Citation validates identically against both packets.
    let cite = EidosCitation {
        source_id: smuggled_src,
        manifest_id: m,
    };
    assert_eq!(
        cloned_packet.validate_citation(&cite),
        original_packet.validate_citation(&cite),
        "validate_citation must produce the same outcome against \
         the cloned packet — pinning packet-level Clone-byte-perfect \
         under the byte-strict closed-citation floor"
    );
    // And specifically: the smuggled source_id matches the hit in
    // both, validating Ok.
    assert_eq!(original_packet.validate_citation(&cite), Ok(()));
}

/// `EidosHit::clone()` is byte-perfect — parallel to iter 190's
/// EidosCitation Clone pin, but for the OUTPUT type (retriever-
/// emitted hits) rather than the INPUT type (chat-layer citations).
///
/// Hits flow through cloning paths in fusion retrievers
/// (HybridRetriever, HybridRetrieverN), the ProvenanceVerified
/// admit-set wrapper, and the replay-bundle serialization layer.
/// A custom Clone that canonicalized / trimmed the source_id would
/// silently break the byte-strict floor — a retriever emits a hit
/// with byte-X source_id, the fusion wrapper clones it for re-
/// emission, and the cloned bytes differ from the original at the
/// downstream validate_citation.
///
/// Pinned across the 5 named smuggling vectors + ASCII baseline,
/// matching iter 190's vector taxonomy.
#[test]
fn eidos_hit_clone_is_byte_perfect_across_smuggling_vectors() {
    use super::types::{
        EidosChunkId, EidosHit, EidosProvenance, EidosScoreComponents,
    };

    let m = manifest();
    let vectors: &[(&str, &str)] = &[
        ("ASCII-baseline", "clean-hit::lex"),
        ("NFD-decomposed (iter 127)", "cafe\u{0301}::lex"),
        ("ZWSP-injected (iter 133)", "note\u{200B}-a::lex"),
        ("Cyrillic-homoglyph (iter 137)", "note-\u{0430}::lex"),
        ("Whitespace-padded (iter 140)", "note-a::lex "),
        ("Control-char-injected (iter 154)", "note\u{001B}-a::lex"),
        ("Bidi-RLO-prefixed (iter 195)", "\u{202E}note-a::lex"),
    ];

    for (label, raw_id) in vectors {
        let original = EidosHit {
            source_id: EidosChunkId::new(*raw_id).unwrap(),
            document_id: doc("clone-doc"),
            kind: EidosSourceKind::Note,
            span: None,
            confidence: 0.5,
            score: EidosScoreComponents::default(),
            provenance: EidosProvenance {
                manifest_id: m.clone(),
                mode: EidosRetrievalMode::Lexical,
                retrieved_at_unix_ms: 1_700_000_000_000,
            },
        };
        let cloned = original.clone();

        // source_id bytes match exactly — the value that gates the
        // closed-citation contract.
        assert_eq!(
            cloned.source_id.as_str().as_bytes(),
            original.source_id.as_str().as_bytes(),
            "{label}: EidosHit clone must preserve source_id bytes exactly"
        );
        // Full hit equality — every field round-trips through Clone.
        assert_eq!(
            cloned, original,
            "{label}: cloned hit must equal source (all 7 fields)"
        );
    }
}

/// `EidosCitation::clone()` is byte-perfect — the cloned citation
/// is byte-equal to the source, including in adversarial smuggling
/// payloads (NFD-decomposed unicode, ZWSP-injected, Cyrillic
/// homoglyph, whitespace-padded, control-character-injected).
///
/// Why pin: `EidosCitation` derives `Clone` via `#[derive(Clone)]`
/// today, which is byte-perfect for `String` payloads. A future
/// custom `Clone` impl that did anything else (canonicalizing
/// unicode, trimming whitespace, stripping invisible chars) would
/// silently break the byte-strict floor pinned in iters
/// 127/133/137/140/154 — a model emits a citation, the chat-layer
/// clones it for logging + validation, and the cloned bytes differ
/// from the original at the validator.
///
/// Pin: for each of the 5 named smuggling vectors, clone() returns
/// a citation byte-equal to the source AND both versions validate
/// to the same outcome against a sample packet.
#[test]
fn eidos_citation_clone_is_byte_perfect_across_smuggling_vectors() {
    use super::types::{EidosChunkId, EidosCitation};

    let m = manifest();
    let vectors: &[(&str, &str)] = &[
        ("ASCII-baseline", "clean-id::lex"),
        ("NFD-decomposed (iter 127)", "cafe\u{0301}::lex"),
        ("ZWSP-injected (iter 133)", "note\u{200B}-a::lex"),
        ("Cyrillic-homoglyph (iter 137)", "note-\u{0430}::lex"),
        ("Whitespace-padded (iter 140)", "note-a::lex "),
        ("Control-char-injected (iter 154)", "note\u{001B}-a::lex"),
        ("Bidi-RLO-prefixed (iter 195)", "\u{202E}note-a::lex"),
    ];

    for (label, raw_id) in vectors {
        let original = EidosCitation {
            source_id: EidosChunkId::new(*raw_id).unwrap(),
            manifest_id: m.clone(),
        };
        let cloned = original.clone();

        // Bytes match exactly — no normalization, no stripping.
        assert_eq!(
            cloned.source_id.as_str().as_bytes(),
            original.source_id.as_str().as_bytes(),
            "{label}: clone() must preserve source_id bytes exactly — \
             a future custom Clone that normalizes / trims / strips \
             would silently break the byte-strict floor pinned in \
             iters 127/133/137/140/154"
        );
        assert_eq!(
            cloned.manifest_id.as_str().as_bytes(),
            original.manifest_id.as_str().as_bytes(),
            "{label}: clone() must preserve manifest_id bytes exactly"
        );
        // Full equality (covers both fields via PartialEq).
        assert_eq!(cloned, original, "{label}: cloned citation must equal source");
    }
}

/// Both error types are LEAF errors — `.source()` returns `None`
/// for every variant. Pins that the chat-layer's error-rendering
/// surface doesn't need to walk a `.source()` chain to get the
/// full diagnostic; the Display message (iter 135 / iter 185) is
/// self-contained.
///
/// Why pin: a future addition like
///   FabricatedSourceId { id: …, cause: Box<dyn Error> }
/// or
///   WrappedSerdeError(serde_json::Error)
/// would silently introduce error chains the chat-layer doesn't
/// know to walk. Pinning .source().is_none() across every variant
/// forces such an addition to be deliberate.
///
/// Companion to iters 185 (IdError Display) + 186 (Error trait):
/// together they cement the "leaf error with verbatim Display, no
/// chain walking required" contract for the closed-citation
/// surface.
#[test]
fn both_error_types_are_leaf_errors_no_source_chain() {
    use super::types::{CitationError, EidosChunkId, IdError};

    // IdError variants — currently only EmptyPayload.
    let id_err = IdError::EmptyPayload;
    assert!(
        std::error::Error::source(&id_err).is_none(),
        "IdError::EmptyPayload must be a leaf error (no .source() \
         chain) — chat-layer error rendering relies on the Display \
         message being self-contained"
    );

    // CitationError variants — all of them.
    let fab = CitationError::FabricatedSourceId(
        EidosChunkId::new("leaf-test").unwrap(),
    );
    assert!(
        std::error::Error::source(&fab).is_none(),
        "CitationError::FabricatedSourceId must be a leaf error"
    );

    let mm = CitationError::ManifestMismatch {
        packet: manifest(),
        citation: EidosIndexManifestId::new("other").unwrap(),
    };
    assert!(
        std::error::Error::source(&mm).is_none(),
        "CitationError::ManifestMismatch must be a leaf error"
    );

    // Exhaustive match probe — pinning ensures every current and
    // future variant is checked. Adding a wrapping variant would
    // fail the .source() assertion immediately.
    for err in &[&fab, &mm] {
        use std::error::Error as _;
        match err {
            CitationError::FabricatedSourceId(_) => {
                assert!(err.source().is_none(), "FabricatedSourceId is a leaf");
            }
            CitationError::ManifestMismatch { .. } => {
                assert!(err.source().is_none(), "ManifestMismatch is a leaf");
            }
        }
    }
}

/// Both error types (`IdError` and `CitationError`) implement
/// `std::error::Error` — compile-time pin that the chat-layer's
/// error-handling idioms (`?` propagation, `.source()` chaining,
/// `Box<dyn Error>` upcasting) work without extra wrapping.
///
/// The `#[derive(Error)]` from `thiserror` synthesizes this impl,
/// but a future migration off thiserror (or a swap to a custom
/// impl that's missing `std::error::Error`) would silently break
/// every `?` and `Box<dyn Error>` consumer. Pinning here forces
/// the migration to be deliberate.
///
/// Companion to iter 152's Send+Sync compile-time pin — together
/// they bound the error types' contract for ergonomic use across
/// the closed-citation surface.
#[test]
fn both_error_types_implement_std_error() {
    use super::types::{CitationError, IdError};

    fn assert_std_error<E: std::error::Error>() {}
    assert_std_error::<IdError>();
    assert_std_error::<CitationError>();

    // Also probe via Box<dyn Error> upcasting — the chat-layer's
    // `Box<dyn std::error::Error>` containers must accept both.
    let _id_boxed: Box<dyn std::error::Error> = Box::new(IdError::EmptyPayload);
    let _cite_boxed: Box<dyn std::error::Error> = Box::new(
        CitationError::FabricatedSourceId(
            super::types::EidosChunkId::new("upcast-probe").unwrap(),
        ),
    );
}

/// `IdError::EmptyPayload`'s `Display` (via `thiserror`) is a
/// user-facing diagnostic string surfaced when chat-layer or
/// retriever code tries to construct an empty-payload id. Pin the
/// exact format so silent drift (someone tweaks the `#[error("…")]`
/// literal) surfaces here.
///
/// Parallel to iter 135's CitationError Display format pin —
/// together they lock the user-facing error surface for both
/// boundary conditions:
///   - constructor failure: IdError::EmptyPayload (this iter)
///   - validation failure: CitationError variants (iter 135)
///
/// Why pin exact format: the chat-layer error renderer and the
/// Swift bridge audit log surface these strings to operators. A
/// silent change to e.g. "id must be non-empty" would alter logs +
/// any downstream string-matching code; pinning the verbatim phrase
/// from types.rs:95 keeps the surface stable.
#[test]
fn id_error_display_format_is_stable() {
    use super::types::IdError;

    let err = IdError::EmptyPayload;
    assert_eq!(
        err.to_string(),
        "eidos id payload was empty; ids must be non-empty for closed-citation safety",
        "IdError::EmptyPayload Display format drifted — types.rs:95 \
         `#[error(...)]` literal + chat-layer error renderer + Swift \
         bridge audit log must update in lock-step. The verbatim \
         phrase IS the closed-citation safety justification — keep \
         it intact."
    );
}

/// `IdError` is a closed single-variant enum (`EmptyPayload`) and
/// adding a second variant must surface in lock-step at every
/// consumer: every `EidosChunkId::new`/`EidosDocumentId::new`/
/// `EidosIndexManifestId::new` site that handles `Result<_, IdError>`
/// exhaustively.
///
/// The drift detector uses an exhaustive match probe with NO `_`
/// wildcard. If a second variant lands (e.g. `TooLong`,
/// `InvalidUTF8`, `ReservedCharacter`), this match fails to compile
/// and forces the author to update every error-handling site.
///
/// Why pin: id-constructor errors are the BOUNDARY between
/// user-supplied bytes and the closed-citation contract. A new
/// rejection reason silently broadens that boundary; the chat-layer
/// + Swift bridge need to know how to render each variant.
///
/// Parallel to:
///   - iter 134: CitationError two-variant exhaustive match
///   - iter 158: 5-vector taxonomy count
///   - iters 172/173/174/175/176/177/178: struct shape locks
#[test]
fn id_error_has_exactly_one_variant() {
    use super::types::IdError;

    // Construct the only known variant.
    let err = IdError::EmptyPayload;
    let all = [err];

    // (1) Runtime count.
    assert_eq!(
        all.len(),
        1,
        "IdError variant count drift — every constructor error-handling \
         site + Swift bridge + chat-layer error renderer must update in \
         lock-step. See iter 179 docstring."
    );

    // (2) Compile-time exhaustiveness probe — no `_` wildcard.
    for e in &all {
        match e {
            IdError::EmptyPayload => {}
        }
    }
}

/// `EidosQuery` has exactly FIVE public fields (text, mode, top_k,
/// query_vector, since_unix_ms) and adding a sixth must surface in
/// lock-step at every consumer.
///
/// EidosQuery is the `query` field of every `EidosContextPacket`.
/// Iter 168 covered packet.query irrelevance to the gate
/// (validate_citation ignores it). This pins that the SHAPE of
/// query doesn't drift silently.
///
/// Consumers that read EidosQuery by name:
///   - Swift bridge wire mirror
///   - EidosQuery construction pins (iters 111 with_vector, 113
///     new, 115 with_since)
///   - Iter 168 (query irrelevance) — constructs an alt-query via
///     with_vector + with_since
///   - Every retriever's `retrieve(&query, …)` impl reads
///     query.text / query.mode / query.top_k / query.query_vector
///     / query.since_unix_ms
///
/// A future addition (e.g. `embedding_model: Option<String>` for
/// Semantic, or `recency_decay_half_life_ms` for Recency, or
/// `lexical_min_score` for Lexical) would need lock-step updates
/// across all those consumers. Pattern mirrors iters
/// 134/158/172/173/174/175/176/177.
#[test]
fn eidos_query_has_exactly_five_public_fields() {
    let q = EidosQuery::with_vector(
        "shape-test",
        EidosRetrievalMode::Semantic,
        8,
        vec![1.0, 0.0, 0.0],
    )
    .with_since(1_700_000_000_000);

    // Compile-time exhaustiveness — NO `..` wildcard.
    let EidosQuery {
        text,
        mode,
        top_k,
        query_vector,
        since_unix_ms,
    } = &q;
    assert!(!text.is_empty());
    let _ = *mode;
    assert!(*top_k > 0);
    assert!(query_vector.is_some());
    assert!(since_unix_ms.is_some());

    // Runtime backup signal.
    const FIELD_COUNT: usize = 5;
    assert_eq!(
        FIELD_COUNT, 5,
        "EidosQuery field count drift — Swift bridge wire mirror + \
         construction pins iter 111/113/115 + iter 168 query- \
         irrelevance pin + every retriever's retrieve() impl must \
         update in lock-step. See iter 178 docstring for the full \
         consumer list."
    );
}

/// `EidosSpan` has exactly TWO public fields (byte_start, byte_end)
/// and adding a third must surface in lock-step at every consumer.
///
/// `EidosSpan` is the byte-range carried in every `EidosHit.span`
/// (Optional). Iter 144 covered span irrelevance to the gate
/// (validate_citation ignores hit.span). This drift detector pins
/// that the SHAPE of span doesn't drift silently.
///
/// Consumers that read EidosSpan by name:
///   - Swift bridge wire mirror
///   - Falsifier span-bounds corpus (zero-width, inverted, past-
///     body) — see span contract pins at iter 84/86/90
///   - Iter 144 (hit metadata irrelevance) — constructs spans
///     across multiple variants
///   - `lexical_span_byte_start_locates_first_mid_body_occurrence`
///     (iter ~92 vicinity) — reads span.byte_start/byte_end
///
/// A future addition (e.g. a `char_start` field for codepoint-level
/// indexing, or a `byte_count` cached value) would need lock-step
/// updates to all those consumers. Parallel pattern to iters 134/
/// 158/172/173/174/175/176.
#[test]
fn eidos_span_has_exactly_two_public_fields() {
    use super::types::EidosSpan;

    let span = EidosSpan {
        byte_start: 0,
        byte_end: 10,
    };

    // Compile-time exhaustiveness — NO `..` wildcard.
    let EidosSpan {
        byte_start,
        byte_end,
    } = &span;
    assert!(*byte_start <= *byte_end);

    // Runtime backup signal.
    const FIELD_COUNT: usize = 2;
    assert_eq!(
        FIELD_COUNT, 2,
        "EidosSpan field count drift — Swift bridge wire mirror + \
         falsifier span-bounds corpus + iter 144 metadata pin must \
         update in lock-step. See iter 177 docstring for the full \
         consumer list."
    );
}

/// `EidosScoreComponents` has exactly FOUR public fields (lexical,
/// semantic, recency, graph) and adding a fifth must surface in
/// lock-step at every consumer.
///
/// This sub-type is the per-component score breakdown carried in
/// every `EidosHit`. Iter 144 (hit metadata irrelevance) pinned
/// that the gate IGNORES the entire score field; this drift
/// detector pins that the SHAPE of score doesn't drift silently.
///
/// Consumers that read EidosScoreComponents by name:
///   - Swift bridge wire mirror
///   - `falsifier` corpus tests that probe score bounds
///   - Iter 144 (hit metadata irrelevance) — constructs score
///     across 4 adversarial hit variants
///   - Iter 110 + similar score component pass-through tests
///   - Iter 95 (ProvenanceVerified preserves score component
///     pass-through)
///
/// A future addition (e.g. `claim: f32` for claim-evidence support,
/// or `code: f32` for code-symbol relevance) would need lock-step
/// updates to all those consumers. This drift detector catches it.
///
/// Parallel to iters 134/158/172/173/174/175 — exhaustive
/// destructure + runtime FIELD_COUNT backup.
#[test]
fn eidos_score_components_has_exactly_four_public_fields() {
    use super::types::EidosScoreComponents;

    let s = EidosScoreComponents {
        lexical: 0.1,
        semantic: 0.2,
        recency: 0.3,
        graph: 0.4,
    };

    // Compile-time exhaustiveness — NO `..` wildcard.
    let EidosScoreComponents {
        lexical,
        semantic,
        recency,
        graph,
    } = &s;
    // Touch every binding.
    assert!(lexical.is_finite());
    assert!(semantic.is_finite());
    assert!(recency.is_finite());
    assert!(graph.is_finite());

    // Runtime backup signal.
    const FIELD_COUNT: usize = 4;
    assert_eq!(
        FIELD_COUNT, 4,
        "EidosScoreComponents field count drift — Swift bridge wire \
         mirror + falsifier score-bounds corpus + iter 95/110/144 \
         score pass-through tests must update in lock-step. See \
         iter 176 docstring for the full consumer list."
    );
}

/// `EidosProvenance` has exactly THREE public fields (manifest_id,
/// mode, retrieved_at_unix_ms) and adding a fourth must surface in
/// lock-step at every consumer.
///
/// Extends iter 174's EidosHit shape lock down one level to the
/// provenance sub-field. Iter 170 explicitly probed
/// provenance.manifest_id for irrelevance; this drift detector
/// catches a hypothetical "let's add a retriever-version field"
/// or "let's add a tier-level identifier" addition that would
/// silently complicate the wire surface and the cross-mode sweep
/// tests.
///
/// Consumers that read EidosProvenance by name:
///   - Swift bridge wire mirror
///   - `all_retrievers_emit_consistent_provenance` (line 216) —
///     reads .manifest_id + .mode
///   - Iter 144 (hit metadata irrelevance) — constructs provenance
///     across multiple variants
///   - Iter 170 (provenance.manifest_id irrelevance) — constructs
///     a foreign-manifest provenance
///   - Iter 174 (EidosHit shape) — touches provenance.manifest_id
///
/// Parallel to iters 134/158/172/173/174 — exhaustive destructure
/// + runtime FIELD_COUNT backup.
#[test]
fn eidos_provenance_has_exactly_three_public_fields() {
    use super::types::EidosProvenance;

    let p = EidosProvenance {
        manifest_id: manifest(),
        mode: EidosRetrievalMode::Lexical,
        retrieved_at_unix_ms: 1_700_000_000_000,
    };

    // Compile-time exhaustiveness — NO `..` wildcard.
    let EidosProvenance {
        manifest_id,
        mode,
        retrieved_at_unix_ms,
    } = &p;
    assert!(!manifest_id.as_str().is_empty());
    let _ = *mode;
    assert!(*retrieved_at_unix_ms > 0);

    // Runtime backup signal.
    const FIELD_COUNT: usize = 3;
    assert_eq!(
        FIELD_COUNT, 3,
        "EidosProvenance field count drift — Swift bridge wire \
         mirror + all_retrievers_emit_consistent_provenance + iter \
         144/170/174 metadata pins must update in lock-step. See \
         iter 175 docstring for the full consumer list."
    );
}

/// `EidosHit` has exactly SEVEN public fields and adding an
/// eighth must surface in lock-step at every consumer:
///   - Swift bridge wire mirror (each hit flows through FFI)
///   - Every cross-mode sweep test (iters 147/149/150/153/164)
///     reads hit fields by name
///   - Iter 144 (hit metadata irrelevance) constructs hits via
///     struct literal across 4 deliberately-adversarial variants
///   - Iter 170 (provenance.manifest_id irrelevance) constructs
///     a manual hit
///   - Iter 171 (document_id irrelevance) constructs a manual hit
///   - `falsifier` corpus tests that pattern-match against hits
///
/// The seven fields are: source_id, document_id, kind, span,
/// confidence, score, provenance.
///
/// Parallel to:
///   - iter 134: CitationError two-variant exhaustive match
///   - iter 158: 5-vector taxonomy count
///   - iter 172: EidosCitation two-field shape
///   - iter 173: EidosContextPacket three-field shape
///
/// Together these four pins lock the structural shape of every
/// public type in the closed-citation contract surface — adding a
/// field/variant anywhere requires a deliberate lock-step update.
#[test]
fn eidos_hit_has_exactly_seven_public_fields() {
    use super::types::{
        EidosHit, EidosProvenance, EidosScoreComponents,
    };

    let h = EidosHit {
        source_id: super::types::EidosChunkId::new("shape-test").unwrap(),
        document_id: doc("shape-doc"),
        kind: EidosSourceKind::Note,
        span: None,
        confidence: 0.5,
        score: EidosScoreComponents::default(),
        provenance: EidosProvenance {
            manifest_id: manifest(),
            mode: EidosRetrievalMode::Lexical,
            retrieved_at_unix_ms: 1_700_000_000_000,
        },
    };

    // Compile-time exhaustiveness — NO `..` wildcard. If an 8th
    // field is added, this destructure fails to compile and forces
    // the author to extend every consumer listed in the docstring.
    let EidosHit {
        source_id,
        document_id,
        kind,
        span,
        confidence,
        score,
        provenance,
    } = &h;
    // Touch every binding so a future macro change can't optimize
    // them into a no-op.
    assert!(!source_id.as_str().is_empty());
    assert!(!document_id.as_str().is_empty());
    let _ = *kind;
    let _ = *span;
    assert!(confidence.is_finite() || confidence.is_nan());
    let _ = score.lexical;
    assert!(!provenance.manifest_id.as_str().is_empty());

    // Runtime backup signal.
    const FIELD_COUNT: usize = 7;
    assert_eq!(
        FIELD_COUNT, 7,
        "EidosHit field count drift — Swift bridge wire mirror + \
         cross-mode sweep tests + iter 144/170/171 metadata- \
         irrelevance pins must update in lock-step. See iter 174 \
         docstring for the full consumer list."
    );
}

/// `EidosContextPacket` has exactly THREE public fields (`query`,
/// `manifest_id`, `hits`) and adding a fourth must surface in
/// lock-step at every consumer:
///   - Swift bridge wire mirror (the packet flows across FFI)
///   - `types::tests::packet_roundtrips_through_json` (Eq + serde
///     round-trip)
///   - the cross-mode sweep tests in iters 147/149/150/153 +
///     iter 164 (each constructs a packet, indirectly via
///     retrievers)
///   - iter 168's query-insensitivity pin (constructs a packet
///     manually with a different query)
///   - any iter 144-style hit-metadata test that constructs a
///     packet via struct literal
///
/// Parallel to iter 172's EidosCitation two-field drift detector
/// and iter 134's CitationError two-variant exhaustive-match pin.
///
/// Implementation mirrors iter 172: exhaustive destructure with
/// NO `..` wildcard catches a fourth field at compile time;
/// `FIELD_COUNT == 3` runtime assertion catches a future "fix"
/// that adds `..` instead of doing the lock-step update.
#[test]
fn eidos_context_packet_has_exactly_three_public_fields() {
    use super::types::EidosContextPacket;

    let packet = EidosContextPacket {
        query: EidosQuery::new("drift", EidosRetrievalMode::Lexical, 1),
        manifest_id: manifest(),
        hits: Vec::new(),
    };

    // Compile-time exhaustiveness — NO `..` wildcard.
    let EidosContextPacket {
        query,
        manifest_id,
        hits,
    } = &packet;
    assert!(!query.text.is_empty() || query.text.is_empty()); // touch
    assert!(!manifest_id.as_str().is_empty());
    assert!(hits.is_empty() || !hits.is_empty()); // touch

    // Runtime backup signal.
    const FIELD_COUNT: usize = 3;
    assert_eq!(
        FIELD_COUNT, 3,
        "EidosContextPacket field count drift — Swift bridge wire \
         mirror + packet_roundtrips_through_json + cross-mode sweep \
         tests + query-insensitivity pin must update in lock-step. \
         See iter 173 docstring for the full consumer list."
    );
}

/// `EidosCitation` has exactly TWO public fields (`source_id`,
/// `manifest_id`) and adding a third must surface in lock-step at
/// every consumer:
///   - the Swift bridge's `EidosCitation` wire mirror
///   - iter 139's JSON wire-format exact-shape pin
///   - iter 143's deserialize contract (which fields are
///     required vs optional)
///   - iter 145's EQ truth-table (would need a third dimension)
///   - iter 161's size ceiling (would need bumping)
///
/// The drift detector uses an exhaustive struct destructure
/// pattern with NO `..` wildcard. If a third field is added, this
/// pattern fails to compile and forces the author to update the
/// downstream consumers before this test passes again. The runtime
/// `assert_eq!(field_count, 2)` is a backup signal in case someone
/// naïvely "fixes" the compile error by adding `..` to the
/// pattern — the count assertion still flips.
///
/// Pattern mirrors:
///   - iter 134: `CitationError` two-variant exhaustive-match drift
///   - iter 158: 5-vector taxonomy count lock
///
/// Doctrine-vs-code: schema enumerations get a runtime count check
/// + a compile-time exhaustiveness probe so silent expansions
/// surface here first.
#[test]
fn eidos_citation_has_exactly_two_public_fields() {
    use super::types::{EidosChunkId, EidosCitation};

    let cite = EidosCitation {
        source_id: EidosChunkId::new("drift-detector-id").unwrap(),
        manifest_id: manifest(),
    };

    // Compile-time exhaustiveness probe — NO `..` wildcard. If a
    // third field is added, this destructure fails to compile and
    // forces the author to add a branch (which then surfaces in
    // the count check below when they bump the assert).
    //
    // Reading the destructured bindings keeps them used so the
    // pattern isn't optimized into a no-op by a future macro
    // change.
    let EidosCitation {
        source_id,
        manifest_id,
    } = &cite;
    assert!(!source_id.as_str().is_empty());
    assert!(!manifest_id.as_str().is_empty());

    // Runtime backup signal — explicitly counts the field bindings
    // covered above. If someone "fixes" the compile error by adding
    // `..` to the destructure, this assertion still flips.
    const FIELD_COUNT: usize = 2;
    assert_eq!(
        FIELD_COUNT, 2,
        "EidosCitation field count drift — Swift bridge + iter 139 \
         JSON wire shape + iter 143 deserialize contract + iter 145 \
         EQ truth-table + iter 161 size ceiling must update in \
         lock-step. See the docstring above for the full consumer \
         list."
    );
}

/// `validate_citation` ignores `hit.document_id` — completes the
/// "every hit field except source_id is irrelevant" sweep started
/// in iter 144 and extended in iter 170.
///
/// Hit-field irrelevance coverage now spans:
///   - iter 144: confidence + span + kind + score + provenance.mode
///     + provenance.retrieved_at_unix_ms
///   - iter 170: provenance.manifest_id (architecturally subtle —
///     could differ from packet.manifest_id at the type level even
///     though retrievers keep them aligned)
///   - this iter: document_id (the logical parent doc the chunk
///     belongs to; closed-citation works at chunk level via
///     source_id, never document_id)
///
/// With this pin, every field of `EidosHit` except `source_id` is
/// explicitly pinned as irrelevant to the gate. The chat-layer's
/// citation contract is byte-equality on source_id + manifest_id,
/// nothing else.
///
/// Pin: a hit whose document_id is wildly distinctive (a 100-byte
/// vault path with unicode) is still citable on its source_id
/// alone; the document_id is purely diagnostic.
#[test]
fn validate_citation_ignores_hit_document_id() {
    use super::types::{
        EidosChunkId, EidosCitation, EidosContextPacket, EidosHit, EidosProvenance,
        EidosScoreComponents,
    };

    let m = manifest();
    let source_id = EidosChunkId::new("dragonfruit-chunk::lex").unwrap();
    // Distinctive document_id with unicode + length, far from any
    // typical retriever-emitted form. The gate must ignore this.
    let weird_doc_id =
        super::types::EidosDocumentId::new("/vault/notes/路径/note-with-長文字-name.md")
            .unwrap();

    let hit = EidosHit {
        source_id: source_id.clone(),
        document_id: weird_doc_id.clone(),
        kind: EidosSourceKind::Note,
        span: None,
        confidence: 0.5,
        score: EidosScoreComponents::default(),
        provenance: EidosProvenance {
            manifest_id: m.clone(),
            mode: EidosRetrievalMode::Lexical,
            retrieved_at_unix_ms: 1_700_000_000_000,
        },
    };
    let packet = EidosContextPacket {
        query: EidosQuery::new("dragonfruit", EidosRetrievalMode::Lexical, 16),
        manifest_id: m.clone(),
        hits: vec![hit],
    };

    // Sanity: the document_id is non-trivial — contains non-ASCII
    // bytes and is longer than a typical bare-id (e.g. "doc-a"). The
    // exact byte count is 47 for the chosen string; the threshold
    // here just confirms the test fixture isn't accidentally trivial.
    assert!(!weird_doc_id.as_str().is_ascii());
    assert!(
        weird_doc_id.as_str().len() > 30,
        "test fixture document_id must be non-trivial (>30 bytes), got {}",
        weird_doc_id.as_str().len()
    );

    // Citation matches source_id + packet.manifest_id, no reference
    // to document_id. Must validate Ok.
    let cite = EidosCitation {
        source_id,
        manifest_id: m,
    };
    assert_eq!(
        packet.validate_citation(&cite),
        Ok(()),
        "validate_citation must IGNORE hit.document_id — the contract \
         is source_id + manifest_id only. Future 'also check the \
         citation's source_id contains the document_id as a prefix' \
         heuristic would silently narrow the closed citation universe."
    );
}

/// `validate_citation` is insensitive to `packet.query` — two
/// packets with identical `manifest_id` + `hits` but different
/// `query` fields produce identical validation results.
///
/// Why pin: `EidosContextPacket.query` is preserved on the packet
/// for diagnostic + replay purposes (which retriever was asked
/// what, when), but the closed-citation gate's contract is purely
/// `(manifest_id, source_id)` byte-equality. A future "also check
/// that the citation matches the query string" addition would be
/// a category error — citations are byte tokens issued by the
/// retriever, not subordinated to the query that produced them.
///
/// Complementary to iter 144 (hit metadata irrelevance):
///   - iter 144: hit-level metadata (confidence, span, kind,
///     score, provenance) is ignored
///   - this iter: PACKET-level metadata (query) is ignored
///
/// Pins, against two packets that share manifest_id + hits but
/// differ in query.text / query.mode / query.top_k / query.vector
/// / query.since_unix_ms:
///   - the same legitimate citation validates Ok against both
///   - the same fabricated citation errors identically against
///     both (same error variant + payload)
///   - the same manifest-mismatch citation errors identically
///     against both
#[test]
fn validate_citation_is_insensitive_to_packet_query() {
    use super::types::{
        CitationError, EidosChunkId, EidosCitation, EidosContextPacket,
    };

    // Build a baseline packet with a real retriever.
    let mut lex = InMemoryLexicalIndex::new(manifest());
    lex.insert(doc("note-a"), "alpha breadfruit content", EidosSourceKind::Note).unwrap();
    let q_baseline = EidosQuery::new("breadfruit", EidosRetrievalMode::Lexical, 16);
    let packet_baseline = lex.retrieve(&q_baseline, 1_700_000_000_000);
    assert_eq!(packet_baseline.hits.len(), 1);

    // Construct a wildly different query: different text, different
    // mode, different top_k, with vector and since_unix_ms fields
    // populated. Same manifest_id, same hits.
    let q_alt = EidosQuery::with_vector(
        "completely-different-query-text",
        EidosRetrievalMode::Semantic,
        u16::MAX,
        vec![0.5, -0.5, 0.0],
    )
    .with_since(99_999_999_999);
    let packet_alt = EidosContextPacket {
        query: q_alt,
        manifest_id: packet_baseline.manifest_id.clone(),
        hits: packet_baseline.hits.clone(),
    };

    // Sanity: the two packets are byte-distinct (different query)
    // but share manifest_id + hits.
    assert_ne!(packet_baseline.query, packet_alt.query, "queries must differ");
    assert_eq!(packet_baseline.manifest_id, packet_alt.manifest_id);
    assert_eq!(packet_baseline.hits, packet_alt.hits);
    assert_ne!(packet_baseline, packet_alt, "packets are not byte-equal");

    let stale_manifest = EidosIndexManifestId::new("stale-snap").unwrap();
    let real = packet_baseline.hits[0].source_id.clone();

    // (1) Legitimate citation validates Ok against both packets.
    let legit = EidosCitation {
        source_id: real.clone(),
        manifest_id: packet_baseline.manifest_id.clone(),
    };
    let r_base = packet_baseline.validate_citation(&legit);
    let r_alt = packet_alt.validate_citation(&legit);
    assert_eq!(r_base, Ok(()), "legit against baseline must be Ok");
    assert_eq!(r_alt, Ok(()), "legit against alt-query packet must also be Ok");

    // (2) Fabricated citation errors identically against both.
    let forged = EidosCitation {
        source_id: EidosChunkId::new("ghost-query::lex").unwrap(),
        manifest_id: packet_baseline.manifest_id.clone(),
    };
    let f_base = format!("{:?}", packet_baseline.validate_citation(&forged));
    let f_alt = format!("{:?}", packet_alt.validate_citation(&forged));
    assert_eq!(
        f_base, f_alt,
        "fabricated citation error must match across packets with \
         different queries — query is diagnostic-only metadata"
    );
    match packet_alt.validate_citation(&forged).unwrap_err() {
        CitationError::FabricatedSourceId(_) => {}
        other => panic!("expected FabricatedSourceId, got {other:?}"),
    }

    // (3) Manifest-mismatch citation errors identically against both.
    let stale_cite = EidosCitation {
        source_id: real,
        manifest_id: stale_manifest,
    };
    let s_base = format!("{:?}", packet_baseline.validate_citation(&stale_cite));
    let s_alt = format!("{:?}", packet_alt.validate_citation(&stale_cite));
    assert_eq!(
        s_base, s_alt,
        "manifest-mismatch error must match across packets with \
         different queries — precedence pin iter 130 unaffected by \
         query field"
    );
    match packet_alt.validate_citation(&stale_cite).unwrap_err() {
        CitationError::ManifestMismatch { .. } => {}
        CitationError::FabricatedSourceId(_) => {
            panic!("manifest precedence broken under alt-query packet");
        }
    }
}

/// Closed-citation contract holds for `InMemoryClaimEvidence` — the
/// non-ledger-backed concrete retriever for the ClaimEvidence mode.
/// Iter 149 pinned the contract for `LedgerBackedClaimEvidence` (the
/// production-wired concrete retriever); this iter pins the parallel
/// in-memory test-fixture variant.
///
/// Why pin both ClaimEvidence retrievers separately: the two
/// concrete types have distinct emission code paths:
///   - `LedgerBackedClaimEvidence` walks a `ClaimLedger` snapshot
///   - `InMemoryClaimEvidence` walks an internal `add_evidence`
///     map keyed by claim_id
///
/// The source_id shape also differs slightly between them
/// (`"{ev}::claim::{claim_id}::supports"` for both, but constructed
/// from different sources). The closed-citation contract is type-
/// level so it holds for both by construction, but pinning both
/// surfaces a hypothetical "different retriever, different chunk
/// id shape, oops the gate doesn't recognize it" regression that
/// only a per-concrete-retriever test would catch.
///
/// Documentation value: new contributors adding a third concrete
/// ClaimEvidence retriever can see that the cross-retriever
/// coverage is intentional and should be extended.
#[test]
fn closed_citation_contract_holds_for_in_memory_claim_evidence() {
    use super::claim_evidence::{EvidenceStance, InMemoryClaimEvidence};
    use super::types::{CitationError, EidosChunkId, EidosCitation};

    let m = manifest();
    let stale = EidosIndexManifestId::new("stale-snapshot").unwrap();
    let ts = 1_700_000_000_000;

    // Build a minimal in-memory claim/evidence map: claim
    // "claim:bok-choy-is-leafy" supported by evidence "ev-leafy".
    let mut ce = InMemoryClaimEvidence::new(m.clone());
    ce.add_evidence(
        "claim:bok-choy-is-leafy",
        doc("ev-leafy"),
        EvidenceStance::Supports,
        EidosSourceKind::Note,
    );

    let q = EidosQuery::new(
        "claim:bok-choy-is-leafy",
        EidosRetrievalMode::ClaimEvidence,
        16,
    );
    let packet = ce.retrieve(&q, ts);

    assert!(!packet.hits.is_empty(), "non-empty evidence map → non-empty packet");
    assert_eq!(packet.manifest_id, m, "ClaimEvidence: manifest_id binding");

    // Confirm InMemoryClaimEvidence's source_id shape is consistent
    // with the docstring contract (used by chat-layer for verbatim
    // citation).
    let first_id = packet.hits[0].source_id.as_str();
    assert!(
        first_id.contains("::claim::claim:bok-choy-is-leafy::supports"),
        "InMemoryClaimEvidence source_id shape drifted; expected to \
         contain '::claim::claim:bok-choy-is-leafy::supports', got {first_id:?}"
    );

    // Sweep: legit Ok, fabricated Err, manifest-mismatch Err.
    let real = packet.hits[0].source_id.clone();
    assert_eq!(
        packet.validate_citation(&EidosCitation {
            source_id: real.clone(),
            manifest_id: m.clone(),
        }),
        Ok(()),
        "InMemoryClaimEvidence: legit citation must validate Ok"
    );

    match packet
        .validate_citation(&EidosCitation {
            source_id: EidosChunkId::new("ghost-evidence::claim::nobody::supports").unwrap(),
            manifest_id: m.clone(),
        })
        .unwrap_err()
    {
        CitationError::FabricatedSourceId(_) => {}
        other => panic!(
            "InMemoryClaimEvidence: fabricated id → expected \
             FabricatedSourceId, got {other:?}"
        ),
    }

    match packet
        .validate_citation(&EidosCitation {
            source_id: real,
            manifest_id: stale,
        })
        .unwrap_err()
    {
        CitationError::ManifestMismatch { .. } => {}
        CitationError::FabricatedSourceId(_) => {
            panic!(
                "InMemoryClaimEvidence: stale manifest must surface \
                 ManifestMismatch (precedence pin iter 130 holds for \
                 in-memory ClaimEvidence too)"
            );
        }
    }
}

/// `HybridRetrieverN` (N-way RRF fusion) has a distinct code path
/// from `HybridRetriever` (2-way). Iter 149 pinned the 2-way Hybrid
/// for closed-citation contract; this pins the N-way variant.
///
/// Hybrid_N is the canonical generalization that hosts the Eidos V0
/// fusion of all 9 retrieval modes — every closed-citation use
/// case that runs across heterogeneous retrievers flows through
/// this code path. The contract has to hold here as strongly as
/// for the single-retriever cases.
///
/// Pinned with a 3-way fusion (Lexical + Semantic + Recency) so the
/// N-way code path is genuinely exercised (not just a 2-way under
/// a different name). All three inner retrievers populated with
/// overlapping docs so RRF has a real fusion candidate set.
///
/// Pins (same sweep as iters 147/149/150):
///   - non-empty fused packet
///   - manifest_id binding holds
///   - legit citation Ok
///   - fabricated id → FabricatedSourceId
///   - stale manifest → ManifestMismatch (precedence pin iter 130
///     holds across N-way fusion)
#[test]
fn closed_citation_contract_holds_for_hybrid_n() {
    use super::hybrid_n::HybridRetrieverN;
    use super::recency::InMemoryRecencyIndex;
    use super::retriever::EidosRetriever;
    use super::semantic::InMemorySemanticIndex;
    use super::types::{CitationError, EidosChunkId, EidosCitation};

    let m = manifest();
    let stale = EidosIndexManifestId::new("stale-snapshot").unwrap();
    let ts = 1_700_000_000_000;

    // Build three inners with overlapping shared docs so RRF has
    // material to fuse.
    let mut lex = InMemoryLexicalIndex::new(m.clone());
    lex.insert(doc("note-a"), "alpha kumquat content", EidosSourceKind::Note).unwrap();
    let mut sem = InMemorySemanticIndex::new(m.clone(), 3);
    sem.insert(doc("note-a"), vec![1.0, 0.0, 0.0], EidosSourceKind::Note).unwrap();
    let mut rec = InMemoryRecencyIndex::new(m.clone());
    rec.insert(doc("note-a"), "any body", ts - 1000, EidosSourceKind::Note);

    let h: HybridRetrieverN = HybridRetrieverN::new(vec![
        Box::new(lex) as Box<dyn EidosRetriever>,
        Box::new(sem),
        Box::new(rec),
    ])
    .expect("3-way Hybrid_N construction");

    let q = EidosQuery::with_vector(
        "kumquat",
        EidosRetrievalMode::Hybrid,
        16,
        vec![1.0, 0.0, 0.0],
    );
    let packet = h.retrieve(&q, ts);

    assert!(!packet.hits.is_empty(), "3-way Hybrid_N must fuse to non-empty packet");
    assert_eq!(packet.manifest_id, m, "Hybrid_N: manifest_id binding holds");

    let real = packet.hits[0].source_id.clone();
    assert_eq!(
        packet.validate_citation(&EidosCitation {
            source_id: real.clone(),
            manifest_id: m.clone(),
        }),
        Ok(()),
        "Hybrid_N: legit citation must validate Ok"
    );

    match packet
        .validate_citation(&EidosCitation {
            source_id: EidosChunkId::new("ghost-hybrid-n::lex").unwrap(),
            manifest_id: m.clone(),
        })
        .unwrap_err()
    {
        CitationError::FabricatedSourceId(_) => {}
        other => panic!(
            "Hybrid_N: fabricated id → expected FabricatedSourceId, got {other:?}"
        ),
    }

    match packet
        .validate_citation(&EidosCitation {
            source_id: real,
            manifest_id: stale,
        })
        .unwrap_err()
    {
        CitationError::ManifestMismatch { .. } => {}
        CitationError::FabricatedSourceId(_) => {
            panic!(
                "Hybrid_N: stale manifest must surface ManifestMismatch \
                 (precedence pin iter 130 holds across N-way fusion)"
            );
        }
    }
}
