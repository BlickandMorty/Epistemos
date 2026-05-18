//! Cross-language parity fixture for the Rust ↔ Swift wire format.
//!
//! [`CANONICAL_PARITY_PACKET_JSON`] is the **single source of truth** for the
//! Eidos V0 packet wire format. The fixture is intentionally minimal — one
//! manifest, one query, one hit — so any drift in field ordering, key
//! casing, or numeric formatting surfaces immediately as a byte-difference.
//!
//! The Rust test in this module:
//!
//! 1. Constructs the canonical packet from typed values.
//! 2. Serializes it via `serde_json::to_string`.
//! 3. Asserts byte-equality against `CANONICAL_PARITY_PACKET_JSON`.
//! 4. Decodes the same JSON back and asserts struct equality.
//!
//! The Swift mirror in `EpistemosTests/EidosParityTests.swift` embeds the
//! SAME constant and asserts the Swift `JSONDecoder` produces a struct that
//! mirrors the typed values exactly. Together the two tests pin the wire
//! format from both sides without requiring an FFI bridge for the test.
//!
//! ## What this catches
//!
//! - Adding or renaming a field on either side breaks one of the two
//!   tests immediately.
//! - Changing a CodingKey on Swift side without matching `serde rename` on
//!   Rust side surfaces as a Swift-side decode failure.
//! - Adding a new optional field that no longer skips when None breaks
//!   the Rust byte-equality assert.
//!
//! ## Updating the constant
//!
//! If the Rust serde output legitimately changes (e.g. adding a new
//! always-emitted field), regenerate by running the Rust test, copying
//! the actual output from the failure diff, and updating BOTH this file
//! and `EpistemosTests/EidosParityTests.swift`.

#![cfg(test)]

use super::types::{
    EidosChunkId, EidosContextPacket, EidosDocumentId, EidosHit, EidosIndexManifestId,
    EidosProvenance, EidosQuery, EidosRetrievalMode, EidosScoreComponents, EidosSourceKind,
    EidosSpan,
};

/// The canonical FFI wire format for one minimal `EidosContextPacket`.
///
/// Mirror in: `EpistemosTests/EidosParityTests.swift` :: `canonicalParityPacketJson`.
///
/// Field order matches Rust struct declaration order (serde stable). f32
/// values use exactly-representable fractions so the formatting is stable
/// across rustc versions.
pub const CANONICAL_PARITY_PACKET_JSON: &str = concat!(
    r#"{"query":{"text":"alpha","mode":"Lexical","top_k":4},"#,
    r#""manifest_id":"parity-snap","#,
    r#""hits":[{"source_id":"doc-1::lex","document_id":"doc-1","kind":"Note","#,
    r#""span":{"byte_start":0,"byte_end":5},"#,
    r#""confidence":0.5,"#,
    r#""score":{"lexical":0.5,"semantic":0.0,"recency":0.0,"graph":0.0},"#,
    r#""provenance":{"manifest_id":"parity-snap","mode":"Lexical","retrieved_at_unix_ms":1700000000000}}]}"#,
);

fn build_canonical_packet() -> EidosContextPacket {
    let manifest = EidosIndexManifestId::new("parity-snap").unwrap();
    EidosContextPacket {
        query: EidosQuery::new("alpha", EidosRetrievalMode::Lexical, 4),
        manifest_id: manifest.clone(),
        hits: vec![EidosHit {
            source_id: EidosChunkId::new("doc-1::lex").unwrap(),
            document_id: EidosDocumentId::new("doc-1").unwrap(),
            kind: EidosSourceKind::Note,
            span: Some(EidosSpan {
                byte_start: 0,
                byte_end: 5,
            }),
            confidence: 0.5,
            score: EidosScoreComponents {
                lexical: 0.5,
                semantic: 0.0,
                recency: 0.0,
                graph: 0.0,
            },
            provenance: EidosProvenance {
                manifest_id: manifest,
                mode: EidosRetrievalMode::Lexical,
                retrieved_at_unix_ms: 1_700_000_000_000,
            },
        }],
    }
}

#[test]
fn canonical_packet_serializes_to_pinned_bytes() {
    // Rust side of the parity contract: the canonical typed packet
    // serializes to EXACTLY the byte sequence Swift will decode.
    let packet = build_canonical_packet();
    let json = serde_json::to_string(&packet).expect("serialize");
    assert_eq!(
        json, CANONICAL_PARITY_PACKET_JSON,
        "Rust serde output drifted from the pinned wire format. Update \
         BOTH agent_core/src/eidos/parity.rs::CANONICAL_PARITY_PACKET_JSON \
         AND EpistemosTests/EidosParityTests.swift::canonicalParityPacketJson \
         after verifying the new bytes are intentional."
    );
}

#[test]
fn canonical_packet_round_trips_through_pinned_bytes() {
    // Decoding the pinned bytes must produce a struct equal to the
    // canonical-typed-values packet.
    let expected = build_canonical_packet();
    let decoded: EidosContextPacket =
        serde_json::from_str(CANONICAL_PARITY_PACKET_JSON).expect("decode");
    assert_eq!(decoded, expected);
}

#[test]
fn canonical_packet_passes_closed_citation_contract() {
    use super::types::EidosCitation;

    let packet = build_canonical_packet();
    let cite = EidosCitation {
        source_id: EidosChunkId::new("doc-1::lex").unwrap(),
        manifest_id: EidosIndexManifestId::new("parity-snap").unwrap(),
    };
    assert_eq!(packet.validate_citation(&cite), Ok(()));
}

#[test]
fn eidos_retrieval_mode_json_case_forms_are_pinned() {
    // Lock the JSON spelling of every retrieval mode so a future
    // refactor (e.g. switching to serde rename_all = "snake_case") can't
    // silently flip the wire format. The case forms here MUST match the
    // canonical parity packet JSON above and the Swift mirror enum's
    // rawValue tokens in Epistemos/Eidos/Eidos.swift.
    let pairs = [
        (EidosRetrievalMode::Lexical, r#""Lexical""#),
        (EidosRetrievalMode::Semantic, r#""Semantic""#),
        (EidosRetrievalMode::Hybrid, r#""Hybrid""#),
        (EidosRetrievalMode::CodeSymbol, r#""CodeSymbol""#),
        (EidosRetrievalMode::ClaimEvidence, r#""ClaimEvidence""#),
        (EidosRetrievalMode::GraphNeighborhood, r#""GraphNeighborhood""#),
        (EidosRetrievalMode::RawArchive, r#""RawArchive""#),
        (EidosRetrievalMode::Recency, r#""Recency""#),
        (EidosRetrievalMode::ProvenanceVerified, r#""ProvenanceVerified""#),
    ];
    for (mode, expected) in pairs {
        let got = serde_json::to_string(&mode).unwrap();
        assert_eq!(
            got, expected,
            "EidosRetrievalMode::{:?} wire-form drifted",
            mode
        );
    }
}

#[test]
fn eidos_source_kind_json_case_forms_are_pinned() {
    // Same wire-format lock for EidosSourceKind.
    let pairs = [
        (EidosSourceKind::Note, r#""Note""#),
        (EidosSourceKind::Epdoc, r#""Epdoc""#),
        (EidosSourceKind::Chat, r#""Chat""#),
        (EidosSourceKind::Code, r#""Code""#),
        (EidosSourceKind::Graph, r#""Graph""#),
        (EidosSourceKind::Shadow, r#""Shadow""#),
        (EidosSourceKind::ExactPath, r#""ExactPath""#),
        (EidosSourceKind::RawArchive, r#""RawArchive""#),
    ];
    for (kind, expected) in pairs {
        let got = serde_json::to_string(&kind).unwrap();
        assert_eq!(
            got, expected,
            "EidosSourceKind::{:?} wire-form drifted",
            kind
        );
    }
}
