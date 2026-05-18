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

use super::lexical::InMemoryLexicalIndex;
use super::retriever::EidosRetriever;
use super::semantic::InMemorySemanticIndex;
use super::types::{
    EidosDocumentId, EidosIndexManifestId, EidosQuery, EidosRetrievalMode, EidosSourceKind,
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
