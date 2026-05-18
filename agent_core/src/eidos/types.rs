//! Canonical Eidos V0 types — IDs, hits, packets, citations, manifest.
//!
//! These types are the contract surface between Eidos retrieval and the chat /
//! model layer. Their two non-negotiable invariants are:
//!
//! 1. **Closed citations.** The chat layer can only cite `EidosChunkId`s that
//!    appeared in a returned [`EidosContextPacket`]. The check lives in
//!    [`EidosContextPacket::validate_citation`].
//! 2. **Manifest binding.** Every hit + packet records the
//!    [`EidosIndexManifestId`] under which it was retrieved, so deterministic
//!    replay is possible: same manifest + same query → byte-equal packet.

use serde::{Deserialize, Serialize};
use thiserror::Error;

// ---------------------------------------------------------------------------
// ID types
// ---------------------------------------------------------------------------

/// Stable, Eidos-issued identifier for a logical document in the local
/// substrate (a note, an `.epdoc`, a chat transcript, a code file, a graph
/// projection, a raw-archive entry).
///
/// `EidosDocumentId` is **opaque** to consumers: only Eidos may construct one,
/// and downstream layers must treat it as a token. The string payload is
/// intentionally unconstrained at this layer — concrete retrieval backends
/// (lexical / semantic / graph) supply their own canonical form (path-hash,
/// vault-id, BLAKE3 digest) when they emit hits.
#[derive(Clone, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub struct EidosDocumentId(String);

impl EidosDocumentId {
    /// Construct a new document id. Rejects empty payloads — an empty
    /// `source_id` would collide with default values and break the closed-
    /// citation contract.
    pub fn new(raw: impl Into<String>) -> Result<Self, IdError> {
        let raw = raw.into();
        if raw.is_empty() {
            return Err(IdError::EmptyPayload);
        }
        Ok(Self(raw))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

/// Stable, Eidos-issued identifier for a retrieval-sized chunk within a
/// document. This is the `source_id` that flows through `EidosHit` and is the
/// **only** value the chat layer is permitted to cite.
///
/// The encoding is opaque, but conventionally combines the parent
/// `EidosDocumentId` with a span / chunk-index so duplicates can be merged
/// across retrieval modes.
#[derive(Clone, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub struct EidosChunkId(String);

impl EidosChunkId {
    pub fn new(raw: impl Into<String>) -> Result<Self, IdError> {
        let raw = raw.into();
        if raw.is_empty() {
            return Err(IdError::EmptyPayload);
        }
        Ok(Self(raw))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

/// Stable identifier for an index snapshot. Two queries that share the same
/// [`EidosIndexManifestId`] are guaranteed to retrieve against the same
/// underlying corpus state, which is what makes Eidos V0 deterministic.
#[derive(Clone, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub struct EidosIndexManifestId(String);

impl EidosIndexManifestId {
    pub fn new(raw: impl Into<String>) -> Result<Self, IdError> {
        let raw = raw.into();
        if raw.is_empty() {
            return Err(IdError::EmptyPayload);
        }
        Ok(Self(raw))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum IdError {
    #[error("eidos id payload was empty; ids must be non-empty for closed-citation safety")]
    EmptyPayload,
}

// ---------------------------------------------------------------------------
// Retrieval shape
// ---------------------------------------------------------------------------

/// The seven canonical retrieval modes for Eidos V0. Each is a deterministic
/// local-first path over the substrate; combinations live in
/// [`EidosRetrievalMode::Hybrid`].
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum EidosRetrievalMode {
    /// BM25 / FTS5-style token retrieval against the vault + chat indexes.
    Lexical,
    /// Dense-vector retrieval (HNSW / usearch) against precomputed
    /// embeddings.
    Semantic,
    /// Reciprocal-Rank-Fusion of `Lexical` and `Semantic`. Default for chat.
    Hybrid,
    /// Symbol-table lookup over the code index (function/struct/file names).
    CodeSymbol,
    /// Claim ledger walk — given a claim, return supporting / contradicting
    /// evidence chunks.
    ClaimEvidence,
    /// 1-hop / 2-hop neighborhood expansion in the cognitive DAG / graph
    /// engine.
    GraphNeighborhood,
    /// Direct path / id lookup against the raw archive (vault file by id).
    RawArchive,
}

/// What kind of substrate a hit came from. Recorded alongside the hit so the
/// Brain Panel can surface a "Retrieved by Eidos · Note / Code / Graph"
/// breakdown without a separate metadata round-trip.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum EidosSourceKind {
    Note,
    Epdoc,
    Chat,
    Code,
    Graph,
    Shadow,
    ExactPath,
    RawArchive,
}

/// Byte span within the source document. Optional because some hits (graph
/// neighborhoods, symbol-table entries) have no contiguous textual range.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct EidosSpan {
    pub byte_start: u32,
    pub byte_end: u32,
}

/// The per-component score breakdown that produced the final `confidence`.
/// Zero is "this signal did not contribute"; values are not required to sum
/// to anything specific — they are diagnostic, not normalized weights.
#[derive(Clone, Copy, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct EidosScoreComponents {
    pub lexical: f32,
    pub semantic: f32,
    pub recency: f32,
    pub graph: f32,
}

/// Where a hit came from and which manifest it was retrieved against. Lets
/// the diagnostics surface (and later, replay) reconstruct exactly which
/// mode + snapshot produced a citation.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct EidosProvenance {
    pub manifest_id: EidosIndexManifestId,
    pub mode: EidosRetrievalMode,
    /// Unix-millis when this hit was emitted. Source: caller-supplied so
    /// retrieval is fully deterministic when tests pin the clock.
    pub retrieved_at_unix_ms: u64,
}

// ---------------------------------------------------------------------------
// Hit + packet + citation
// ---------------------------------------------------------------------------

/// One retrieved chunk. The `source_id` is the **only** value the chat /
/// model layer may cite, and the closed-citation contract is enforced by
/// [`EidosContextPacket::validate_citation`].
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct EidosHit {
    pub source_id: EidosChunkId,
    pub document_id: EidosDocumentId,
    pub kind: EidosSourceKind,
    pub span: Option<EidosSpan>,
    /// Fused confidence in [0.0, 1.0]. Higher is better. Determinism rule:
    /// equal hits produced from the same manifest must hash-equal here.
    pub confidence: f32,
    pub score: EidosScoreComponents,
    pub provenance: EidosProvenance,
}

/// Sealed query → result packet. Returned by Eidos to the chat / model layer.
/// The set of `source_id`s in `hits` defines the **closed citation universe**
/// for any answer that uses this packet.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct EidosContextPacket {
    pub query: EidosQuery,
    pub manifest_id: EidosIndexManifestId,
    pub hits: Vec<EidosHit>,
}

impl EidosContextPacket {
    /// Validate a candidate citation against this packet. Returns `Ok(())`
    /// only if the citation's `source_id` appears in [`Self::hits`].
    ///
    /// This is the closed-citation contract: the chat layer **cannot** cite
    /// anything that Eidos did not return. Any fabricated, forged, or
    /// hallucinated `source_id` is rejected with
    /// [`CitationError::FabricatedSourceId`].
    pub fn validate_citation(&self, citation: &EidosCitation) -> Result<(), CitationError> {
        if citation.manifest_id != self.manifest_id {
            return Err(CitationError::ManifestMismatch {
                packet: self.manifest_id.clone(),
                citation: citation.manifest_id.clone(),
            });
        }
        if self
            .hits
            .iter()
            .any(|h| h.source_id == citation.source_id)
        {
            Ok(())
        } else {
            Err(CitationError::FabricatedSourceId(citation.source_id.clone()))
        }
    }

    /// Returns the closed set of citable `source_id`s in deterministic order
    /// (the order they appear in `hits`). Useful for the chat layer to gate
    /// model output before validation.
    pub fn citable_source_ids(&self) -> impl Iterator<Item = &EidosChunkId> {
        self.hits.iter().map(|h| &h.source_id)
    }
}

/// A query issued against an Eidos index manifest. Top-k is bounded by
/// `top_k` to keep the closed-citation universe small enough to be visible to
/// the user in the Brain Panel.
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct EidosQuery {
    pub text: String,
    pub mode: EidosRetrievalMode,
    pub top_k: u16,
}

impl EidosQuery {
    pub fn new(text: impl Into<String>, mode: EidosRetrievalMode, top_k: u16) -> Self {
        Self {
            text: text.into(),
            mode,
            top_k,
        }
    }
}

/// The chat layer's reference back to a single `EidosChunkId` from a sealed
/// packet. Validation lives on [`EidosContextPacket::validate_citation`].
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct EidosCitation {
    pub source_id: EidosChunkId,
    pub manifest_id: EidosIndexManifestId,
}

#[derive(Debug, Error, PartialEq)]
pub enum CitationError {
    /// The cited `source_id` was not present in the packet's `hits`. This is
    /// the closed-citation contract refusing a fabricated reference.
    #[error("fabricated source_id rejected by closed-citation contract: {0:?}")]
    FabricatedSourceId(EidosChunkId),

    /// The citation referenced a different index snapshot than the packet
    /// was retrieved against. Cross-snapshot citations are unsafe because
    /// the underlying content may have changed.
    #[error("manifest mismatch: packet retrieved against {packet:?}, citation references {citation:?}")]
    ManifestMismatch {
        packet: EidosIndexManifestId,
        citation: EidosIndexManifestId,
    },
}

// ---------------------------------------------------------------------------
// Index manifest
// ---------------------------------------------------------------------------

/// Descriptor for an index snapshot. Encodes the inputs that make retrieval
/// deterministic: the manifest id, a corpus content-hash, and a creation
/// timestamp. The full structure (per-source counts, embedding model id,
/// lexical analyzer version) lands in a later iteration.
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct EidosIndexManifest {
    pub id: EidosIndexManifestId,
    pub created_at_unix_ms: u64,
    /// 32-byte BLAKE3 digest of the canonical corpus state at snapshot time,
    /// rendered as lowercase hex. Empty until the indexer wires the digest in
    /// a later iteration; the field is reserved here so on-disk packets stay
    /// schema-stable.
    pub corpus_digest_hex: String,
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn manifest_id(s: &str) -> EidosIndexManifestId {
        EidosIndexManifestId::new(s).expect("non-empty manifest id")
    }

    fn chunk_id(s: &str) -> EidosChunkId {
        EidosChunkId::new(s).expect("non-empty chunk id")
    }

    fn document_id(s: &str) -> EidosDocumentId {
        EidosDocumentId::new(s).expect("non-empty document id")
    }

    fn sample_hit(source: &str, manifest: &EidosIndexManifestId) -> EidosHit {
        EidosHit {
            source_id: chunk_id(source),
            document_id: document_id(&format!("{source}::doc")),
            kind: EidosSourceKind::Note,
            span: Some(EidosSpan {
                byte_start: 0,
                byte_end: 16,
            }),
            confidence: 0.42,
            score: EidosScoreComponents {
                lexical: 0.4,
                semantic: 0.0,
                recency: 0.02,
                graph: 0.0,
            },
            provenance: EidosProvenance {
                manifest_id: manifest.clone(),
                mode: EidosRetrievalMode::Lexical,
                retrieved_at_unix_ms: 1_700_000_000_000,
            },
        }
    }

    fn sample_packet() -> EidosContextPacket {
        let manifest = manifest_id("manifest-A");
        EidosContextPacket {
            query: EidosQuery::new("tropical optimization", EidosRetrievalMode::Lexical, 8),
            manifest_id: manifest.clone(),
            hits: vec![sample_hit("chunk-1", &manifest), sample_hit("chunk-2", &manifest)],
        }
    }

    /// Closed-citation contract: a citation pointing at a `source_id` that
    /// Eidos did not return is **rejected**. This is the single most important
    /// invariant of the module.
    #[test]
    fn fabricated_source_id_is_rejected() {
        let packet = sample_packet();
        let forged = EidosCitation {
            source_id: chunk_id("chunk-99-never-emitted"),
            manifest_id: packet.manifest_id.clone(),
        };

        let result = packet.validate_citation(&forged);

        assert_eq!(
            result,
            Err(CitationError::FabricatedSourceId(chunk_id(
                "chunk-99-never-emitted"
            )))
        );
    }

    #[test]
    fn returned_source_id_is_accepted() {
        let packet = sample_packet();
        let real = EidosCitation {
            source_id: chunk_id("chunk-1"),
            manifest_id: packet.manifest_id.clone(),
        };

        assert_eq!(packet.validate_citation(&real), Ok(()));
    }

    #[test]
    fn citation_against_wrong_manifest_is_rejected() {
        let packet = sample_packet();
        let cross_snapshot = EidosCitation {
            source_id: chunk_id("chunk-1"),
            manifest_id: manifest_id("manifest-B"),
        };

        let err = packet.validate_citation(&cross_snapshot).unwrap_err();
        assert!(matches!(err, CitationError::ManifestMismatch { .. }));
    }

    #[test]
    fn empty_packet_rejects_every_citation() {
        let manifest = manifest_id("manifest-empty");
        let packet = EidosContextPacket {
            query: EidosQuery::new("", EidosRetrievalMode::Lexical, 0),
            manifest_id: manifest.clone(),
            hits: vec![],
        };
        let any = EidosCitation {
            source_id: chunk_id("anything"),
            manifest_id: manifest,
        };
        assert!(matches!(
            packet.validate_citation(&any),
            Err(CitationError::FabricatedSourceId(_))
        ));
    }

    #[test]
    fn empty_id_payload_is_rejected_at_construction() {
        assert_eq!(EidosChunkId::new(""), Err(IdError::EmptyPayload));
        assert_eq!(EidosDocumentId::new(""), Err(IdError::EmptyPayload));
        assert_eq!(EidosIndexManifestId::new(""), Err(IdError::EmptyPayload));
    }

    #[test]
    fn citable_source_ids_preserves_hit_order() {
        let packet = sample_packet();
        let ids: Vec<&EidosChunkId> = packet.citable_source_ids().collect();
        assert_eq!(ids, vec![&chunk_id("chunk-1"), &chunk_id("chunk-2")]);
    }

    /// Determinism floor: a packet serialized to JSON round-trips byte-equal.
    /// The closed-citation universe is part of the packet's identity, so any
    /// non-deterministic field (HashMap iteration, f32 NaN, etc.) would break
    /// replay and must surface here first.
    #[test]
    fn packet_roundtrips_through_json() {
        let packet = sample_packet();
        let json = serde_json::to_string(&packet).expect("serialize");
        let back: EidosContextPacket = serde_json::from_str(&json).expect("deserialize");
        assert_eq!(back, packet);
    }

    #[test]
    fn all_seven_retrieval_modes_are_representable() {
        // Acceptance bar: lexical, semantic, hybrid, code-symbol, claim-evidence,
        // graph-neighborhood, raw-archive lookup — 7 total, each constructable.
        let modes = [
            EidosRetrievalMode::Lexical,
            EidosRetrievalMode::Semantic,
            EidosRetrievalMode::Hybrid,
            EidosRetrievalMode::CodeSymbol,
            EidosRetrievalMode::ClaimEvidence,
            EidosRetrievalMode::GraphNeighborhood,
            EidosRetrievalMode::RawArchive,
        ];
        assert_eq!(modes.len(), 7);
    }
}
