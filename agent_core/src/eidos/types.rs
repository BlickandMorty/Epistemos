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

/// The nine canonical retrieval modes for Eidos V0 (see
/// [`EidosRetrievalMode::CANON_ALL`]). Each is a deterministic
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
    /// Time-ordered retrieval — return documents ranked by
    /// `created_at_unix_ms desc`. Empty query text is meaningful here
    /// (treated as "no substring filter, all documents considered") so the
    /// chat layer can ask "what did I most recently capture?" without
    /// inventing a substring. Non-empty query text narrows to documents
    /// containing the substring before recency sort.
    Recency,
    /// Provenance-verified retrieval — only return chunks whose
    /// provenance has been verified (claim-ledger backing, witness
    /// attached, or signed source). Fail-closed: if a chunk has no
    /// provenance witness, it is filtered out of the packet entirely so
    /// the closed-citation contract sees only verified ids.
    ProvenanceVerified,
}

impl EidosRetrievalMode {
    /// All canonical EidosRetrievalMode variants in source-declared order.
    /// Use this instead of hand-listing variants in tests / iteration so
    /// adding a new variant in this enum surfaces missing handling at
    /// the call site immediately. The doc-and-code drift detector in
    /// `hardening_tests` reads this constant to validate the design-doc
    /// table row count.
    pub const CANON_ALL: &'static [EidosRetrievalMode] = &[
        EidosRetrievalMode::Lexical,
        EidosRetrievalMode::Semantic,
        EidosRetrievalMode::Hybrid,
        EidosRetrievalMode::CodeSymbol,
        EidosRetrievalMode::ClaimEvidence,
        EidosRetrievalMode::GraphNeighborhood,
        EidosRetrievalMode::RawArchive,
        EidosRetrievalMode::Recency,
        EidosRetrievalMode::ProvenanceVerified,
    ];
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

impl EidosSourceKind {
    /// All `EidosSourceKind` variants in source-declared order. Companion
    /// to `EidosRetrievalMode::CANON_ALL`; reduces duplication in tests
    /// that iterate kinds (wire-format pin, cross-language parity, etc.).
    pub const CANON_ALL: &'static [EidosSourceKind] = &[
        EidosSourceKind::Note,
        EidosSourceKind::Epdoc,
        EidosSourceKind::Chat,
        EidosSourceKind::Code,
        EidosSourceKind::Graph,
        EidosSourceKind::Shadow,
        EidosSourceKind::ExactPath,
        EidosSourceKind::RawArchive,
    ];
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

    /// Build a typed citation envelope only after the citation passes the
    /// closed-citation gate. The envelope carries the exact hit provenance
    /// that authorized the citation, so bridge/chat callers do not need a
    /// later best-effort lookup to recover provenance.
    pub fn citation_envelope(
        &self,
        citation: &EidosCitation,
    ) -> Result<EidosCitationEnvelope, CitationError> {
        self.validate_citation(citation)?;
        let provenance = self
            .hits
            .iter()
            .find(|h| h.source_id == citation.source_id)
            .map(|h| h.provenance.clone())
            .ok_or_else(|| CitationError::FabricatedSourceId(citation.source_id.clone()))?;
        Ok(EidosCitationEnvelope {
            citation: citation.clone(),
            provenance,
        })
    }

    /// Returns the closed set of citable `source_id`s in deterministic order
    /// (the order they appear in `hits`). Useful for the chat layer to gate
    /// model output before validation.
    pub fn citable_source_ids(&self) -> impl Iterator<Item = &EidosChunkId> {
        self.hits.iter().map(|h| &h.source_id)
    }

    /// Batch-validate a list of candidate citations against this packet.
    /// Returns `Ok(())` only if **every** citation is valid; otherwise
    /// returns all per-index errors so the chat layer can show a complete
    /// rejection list rather than failing on the first forged id.
    ///
    /// This is the canonical entry point for the chat-layer "about to emit
    /// an answer" gate: collect every citation the model produced, run them
    /// through this method, and refuse the answer wholesale if any
    /// fabrication is detected. The closed-citation contract is *all or
    /// nothing* — one forged citation invalidates the answer.
    pub fn validate_citations(
        &self,
        citations: &[EidosCitation],
    ) -> Result<(), Vec<(usize, CitationError)>> {
        let mut errors: Vec<(usize, CitationError)> = Vec::new();
        for (idx, c) in citations.iter().enumerate() {
            if let Err(e) = self.validate_citation(c) {
                errors.push((idx, e));
            }
        }
        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors)
        }
    }
}

/// A query issued against an Eidos index manifest. Top-k is bounded by
/// `top_k` to keep the closed-citation universe small enough to be visible to
/// the user in the Brain Panel.
///
/// `query_vector` is optional and only consulted by the Semantic / Hybrid
/// retrievers. Lexical / CodeSymbol / GraphNeighborhood / RawArchive ignore
/// it. Eidos V0 does **not** perform text → vector encoding itself; callers
/// pass a precomputed embedding (the shadow backend already maintains one).
///
/// `Eq` / `Hash` are intentionally *not* derived: `Vec<f32>` cannot be `Eq`
/// because NaN ≠ NaN. `PartialEq` is sufficient for assertion / replay
/// checks and is what packets compare against.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct EidosQuery {
    pub text: String,
    pub mode: EidosRetrievalMode,
    pub top_k: u16,
    /// Caller-supplied query embedding for Semantic / Hybrid modes. Required
    /// when `mode` is `Semantic`; ignored otherwise. Dimension must match the
    /// retriever's index dimension or the retriever returns an empty packet.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub query_vector: Option<Vec<f32>>,
    /// Time-window floor in unix-millis. Consumed by `Recency`; ignored by
    /// every other mode. When set, Recency drops documents whose
    /// `created_at_unix_ms < since_unix_ms` before the recency sort. Lets
    /// the chat layer answer "what did I capture in the last 24h?" without
    /// inventing a substring proxy. `None` means "no time floor."
    ///
    /// Backwards-compatible at the wire: omitted when `None`. Packets
    /// produced before this field existed deserialize cleanly.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub since_unix_ms: Option<u64>,
}

impl EidosQuery {
    pub fn new(text: impl Into<String>, mode: EidosRetrievalMode, top_k: u16) -> Self {
        Self {
            text: text.into(),
            mode,
            top_k,
            query_vector: None,
            since_unix_ms: None,
        }
    }

    /// Construct a semantic / hybrid query. The `vector` must match the
    /// target retriever's dimension; mismatched dimensions surface as an
    /// empty packet (deterministic, no panic).
    pub fn with_vector(
        text: impl Into<String>,
        mode: EidosRetrievalMode,
        top_k: u16,
        vector: Vec<f32>,
    ) -> Self {
        Self {
            text: text.into(),
            mode,
            top_k,
            query_vector: Some(vector),
            since_unix_ms: None,
        }
    }

    /// Attach a time-window floor to a Recency query.
    pub fn with_since(mut self, since_unix_ms: u64) -> Self {
        self.since_unix_ms = Some(since_unix_ms);
        self
    }
}

/// The chat layer's reference back to a single `EidosChunkId` from a sealed
/// packet. Validation lives on [`EidosContextPacket::validate_citation`].
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct EidosCitation {
    pub source_id: EidosChunkId,
    pub manifest_id: EidosIndexManifestId,
}

/// A validated citation plus the hit provenance that authorized it.
/// Construct through [`EidosContextPacket::citation_envelope`] so the closed-
/// citation contract runs before any provenance-carrying envelope exists.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct EidosCitationEnvelope {
    pub citation: EidosCitation,
    pub provenance: EidosProvenance,
}

/// `Serialize` is derived for the future Swift bridge (W-46/W-47).
/// External tagging (the serde default) is used because internal
/// tagging can't serialize tuple-newtype variants like
/// `FabricatedSourceId(EidosChunkId)`. Wire shape:
///   - `{"FabricatedSourceId": "the-chunk-id"}`
///   - `{"ManifestMismatch": {"packet": "...", "citation": "..."}}`
#[derive(Debug, Error, PartialEq, Serialize)]
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
    /// Optional reference to a Live Files snapshot that this index manifest
    /// is pinned to. Empty in V0. The Live Files integration lands under a
    /// later W-row; the slot exists here so packets persisted today remain
    /// readable once that wiring exists. See `agent_core::live_files`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub live_files_snapshot_id: Option<String>,
}

impl EidosIndexManifest {
    /// Construct a manifest with no Live Files binding (the V0 default).
    pub fn new(id: EidosIndexManifestId, created_at_unix_ms: u64) -> Self {
        Self {
            id,
            created_at_unix_ms,
            corpus_digest_hex: String::new(),
            live_files_snapshot_id: None,
        }
    }

    /// Attach a Live Files snapshot id. Used by the future Live Files
    /// integration (pre-design hook — see W-row backlog).
    pub fn with_live_files_snapshot(mut self, snapshot_id: impl Into<String>) -> Self {
        self.live_files_snapshot_id = Some(snapshot_id.into());
        self
    }
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

    #[test]
    fn batch_validate_all_legitimate_succeeds() {
        let packet = sample_packet();
        let cites = vec![
            EidosCitation {
                source_id: chunk_id("chunk-1"),
                manifest_id: packet.manifest_id.clone(),
            },
            EidosCitation {
                source_id: chunk_id("chunk-2"),
                manifest_id: packet.manifest_id.clone(),
            },
        ];
        assert_eq!(packet.validate_citations(&cites), Ok(()));
    }

    #[test]
    fn batch_validate_reports_every_forgery_with_index() {
        // The chat-layer gate must see EVERY forgery so it can show the
        // complete rejection list. One legitimate id + two forged ids → two
        // errors, indexed by position in the input slice.
        let packet = sample_packet();
        let cites = vec![
            EidosCitation {
                source_id: chunk_id("chunk-1"),
                manifest_id: packet.manifest_id.clone(),
            },
            EidosCitation {
                source_id: chunk_id("forged-A"),
                manifest_id: packet.manifest_id.clone(),
            },
            EidosCitation {
                source_id: chunk_id("forged-B"),
                manifest_id: packet.manifest_id.clone(),
            },
        ];
        let errs = packet.validate_citations(&cites).unwrap_err();
        assert_eq!(errs.len(), 2);
        assert_eq!(errs[0].0, 1);
        assert!(matches!(errs[0].1, CitationError::FabricatedSourceId(_)));
        assert_eq!(errs[1].0, 2);
        assert!(matches!(errs[1].1, CitationError::FabricatedSourceId(_)));
    }

    #[test]
    fn batch_validate_catches_mixed_failure_modes() {
        // Forgery + manifest mismatch in the same batch. Both errors must
        // surface with their original indices intact.
        let packet = sample_packet();
        let cites = vec![
            EidosCitation {
                source_id: chunk_id("forged"),
                manifest_id: packet.manifest_id.clone(),
            },
            EidosCitation {
                source_id: chunk_id("chunk-1"),
                manifest_id: manifest_id("other-snapshot"),
            },
        ];
        let errs = packet.validate_citations(&cites).unwrap_err();
        assert_eq!(errs.len(), 2);
        assert_eq!(errs[0].0, 0);
        assert!(matches!(errs[0].1, CitationError::FabricatedSourceId(_)));
        assert_eq!(errs[1].0, 1);
        assert!(matches!(errs[1].1, CitationError::ManifestMismatch { .. }));
    }

    #[test]
    fn eidos_query_with_since_sets_only_floor_field_preserving_others() {
        // Completes the constructor-shape pin family alongside
        // iter 111 (`with_vector`) and iter 113 (`new`). The builder
        // method `with_since` is exercised in Recency tests by
        // behavior; field-shape was not directly pinned.
        //
        // Contract: `with_since(floor)` returns a copy with
        // since_unix_ms = Some(floor), every other field unchanged.
        // Specifically: a future change that reset text/mode/top_k
        // or clobbered query_vector would surface here even though
        // the floor-filter behavior tests still pass.
        let q = EidosQuery::with_vector(
            "alpha",
            EidosRetrievalMode::Recency,
            8,
            vec![1.0, 0.0],
        )
        .with_since(1_700_000_000_000);

        // The targeted field — only mutation.
        assert_eq!(q.since_unix_ms, Some(1_700_000_000_000));

        // Every other field carries through unmodified.
        assert_eq!(q.text, "alpha");
        assert_eq!(q.mode, EidosRetrievalMode::Recency);
        assert_eq!(q.top_k, 8);
        assert_eq!(q.query_vector, Some(vec![1.0, 0.0]));
    }

    #[test]
    fn eidos_query_new_constructs_full_field_shape_with_default_vector_and_since() {
        // Symmetric to iter 111's `with_vector` shape pin. The simple
        // constructor `EidosQuery::new(text, mode, top_k)` is the
        // canonical non-Semantic entry point and is exercised across
        // every retriever's test suite. Like `with_vector`, no
        // existing test directly verifies its field shape.
        //
        // Pin: query_vector and since_unix_ms both default to None;
        // text/mode/top_k populate as specified.
        let q = EidosQuery::new("alpha", EidosRetrievalMode::Lexical, 8);
        assert_eq!(q.text, "alpha");
        assert_eq!(q.mode, EidosRetrievalMode::Lexical);
        assert_eq!(q.top_k, 8);
        assert_eq!(q.query_vector, None);
        assert_eq!(q.since_unix_ms, None);
    }

    #[test]
    fn eidos_query_with_vector_constructs_full_field_shape() {
        // Audit per "audit existing claims first": `with_vector` is
        // exercised constantly across the Semantic, Hybrid, and
        // Hybrid_N test suites — but every usage tests behavior, not
        // construction shape. A future regression that swapped a
        // field name, defaulted `query_vector` to None despite the
        // call, or accidentally populated `since_unix_ms` to Some(0)
        // would not be caught directly.
        //
        // Pin the canonical construction shape: all 5 fields populate
        // exactly as the caller specified, with `since_unix_ms`
        // defaulting to None (Recency query attaches it via the
        // subsequent `with_since` builder method).
        let q = EidosQuery::with_vector(
            "needle",
            EidosRetrievalMode::Semantic,
            42,
            vec![1.0, 0.5, 0.25],
        );
        assert_eq!(q.text, "needle");
        assert_eq!(q.mode, EidosRetrievalMode::Semantic);
        assert_eq!(q.top_k, 42);
        assert_eq!(q.query_vector, Some(vec![1.0, 0.5, 0.25]));
        assert_eq!(q.since_unix_ms, None);
    }

    #[test]
    fn index_manifest_new_has_no_live_files_binding() {
        // V0 default: no Live Files snapshot. The pre-design hook reserves
        // the slot but does not populate it.
        let m = EidosIndexManifest::new(manifest_id("snap-A"), 1_700_000_000_000);
        assert_eq!(m.id, manifest_id("snap-A"));
        assert_eq!(m.created_at_unix_ms, 1_700_000_000_000);
        assert!(m.corpus_digest_hex.is_empty());
        assert!(m.live_files_snapshot_id.is_none());
    }

    #[test]
    fn index_manifest_with_live_files_snapshot_round_trips() {
        let m = EidosIndexManifest::new(manifest_id("snap-A"), 1_700_000_000_000)
            .with_live_files_snapshot("lf-snap-42");
        let json = serde_json::to_string(&m).unwrap();
        let back: EidosIndexManifest = serde_json::from_str(&json).unwrap();
        assert_eq!(back, m);
        assert_eq!(back.live_files_snapshot_id.as_deref(), Some("lf-snap-42"));
    }

    #[test]
    fn index_manifest_without_live_files_omits_field_in_json() {
        // Backwards-compat: packets written before the Live Files slot
        // existed do not include the field. skip_serializing_if = None
        // matches that wire format so both directions stay readable.
        let m = EidosIndexManifest::new(manifest_id("snap-A"), 1_700_000_000_000);
        let json = serde_json::to_string(&m).unwrap();
        assert!(!json.contains("live_files_snapshot_id"));
        let back: EidosIndexManifest = serde_json::from_str(&json).unwrap();
        assert_eq!(back, m);
    }

    #[test]
    fn citation_error_serializes_with_external_tag() {
        // External tagging is serde's default for enums. Pin the exact
        // wire shape for both variants so the future Swift bridge
        // (W-46 / W-47) can decode without ambiguity.
        let forged = CitationError::FabricatedSourceId(chunk_id("d::lex"));
        let forged_json = serde_json::to_string(&forged).unwrap();
        assert_eq!(forged_json, r#"{"FabricatedSourceId":"d::lex"}"#);

        let mismatch = CitationError::ManifestMismatch {
            packet: manifest_id("snap-a"),
            citation: manifest_id("snap-b"),
        };
        let mismatch_json = serde_json::to_string(&mismatch).unwrap();
        assert_eq!(
            mismatch_json,
            r#"{"ManifestMismatch":{"packet":"snap-a","citation":"snap-b"}}"#
        );
    }

    #[test]
    fn batch_failure_byte_equal_pin_for_two_error_canonical_input() {
        // Pin the EXACT byte sequence Rust emits for a canonical
        // 2-error batch. Mirror of the Swift
        // `batchCitationErrorDecodesRustWireShape` test in
        // EidosParityTests.swift, which feeds the same byte sequence
        // through JSONDecoder. If either side drifts, exactly one
        // test fires, distinguishing which side broke the contract.
        let manifest = manifest_id("snap-A");
        let packet = EidosContextPacket {
            query: EidosQuery::new("", EidosRetrievalMode::Lexical, 0),
            manifest_id: manifest.clone(),
            hits: vec![],
        };
        let cites = vec![
            EidosCitation {
                source_id: chunk_id("forged"),
                manifest_id: manifest.clone(),
            },
            EidosCitation {
                source_id: chunk_id("also-forged"),
                manifest_id: manifest_id("OTHER"),
            },
        ];
        let errs = packet.validate_citations(&cites).unwrap_err();
        let json = serde_json::to_string(&errs).unwrap();
        assert_eq!(
            json,
            concat!(
                "[",
                r#"[0,{"FabricatedSourceId":"forged"}],"#,
                r#"[1,{"ManifestMismatch":{"packet":"snap-A","citation":"OTHER"}}]"#,
                "]"
            ),
            "batch failure wire format drifted; update BOTH this test \
             AND EpistemosTests/EidosParityTests.swift::\
             batchCitationErrorDecodesRustWireShape in lock-step"
        );
    }

    #[test]
    fn batch_validate_result_can_serialize_per_index_errors_to_json() {
        // The `Vec<(usize, CitationError)>` Err payload becomes
        // `[[index, {Variant: ...}], ...]` under serde_json's tuple
        // default. This is the wire shape the future Swift bridge will
        // decode for batch rejection display.
        let packet = sample_packet();
        let cites = vec![
            EidosCitation {
                source_id: chunk_id("forged"),
                manifest_id: packet.manifest_id.clone(),
            },
            EidosCitation {
                source_id: chunk_id("chunk-1"),
                manifest_id: manifest_id("OTHER"),
            },
        ];
        let errs = packet.validate_citations(&cites).unwrap_err();
        let json = serde_json::to_string(&errs).unwrap();
        // Array of pairs.
        assert!(json.starts_with("[["));
        // First pair: index 0, FabricatedSourceId.
        assert!(json.contains(r#"[0,{"FabricatedSourceId":"forged"}]"#));
        // Second pair: index 1, ManifestMismatch with externally-tagged
        // struct payload.
        assert!(json.contains(r#"[1,{"ManifestMismatch":{"packet":"#));
    }

    #[test]
    fn batch_validate_empty_input_is_ok() {
        // Empty citation list is trivially valid — useful for "answer with
        // zero citations" replies that should not be blocked by this gate.
        let packet = sample_packet();
        assert_eq!(packet.validate_citations(&[]), Ok(()));
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
    fn all_prompt_deck_floor_modes_are_representable() {
        // Prompt-deck §4 T10 acceptance-bar floor: lexical, semantic, hybrid,
        // code-symbol, claim-evidence, graph-neighborhood, raw-archive lookup
        // — 7 total. (CANON_ALL has 9 total: this floor + 2 operator
        // extensions Recency + ProvenanceVerified added later in T10.) Each
        // floor mode must be a member of CANON_ALL, the single source of
        // truth for variant enumeration.
        let canon_seven = [
            EidosRetrievalMode::Lexical,
            EidosRetrievalMode::Semantic,
            EidosRetrievalMode::Hybrid,
            EidosRetrievalMode::CodeSymbol,
            EidosRetrievalMode::ClaimEvidence,
            EidosRetrievalMode::GraphNeighborhood,
            EidosRetrievalMode::RawArchive,
        ];
        for mode in canon_seven {
            assert!(
                EidosRetrievalMode::CANON_ALL.contains(&mode),
                "canon mode {:?} missing from CANON_ALL",
                mode
            );
        }
    }

    #[test]
    fn additive_retrieval_modes_are_representable() {
        // Beyond canon (operator-prompt additive extensions): Recency +
        // ProvenanceVerified. Adding these never violates canon because
        // canon says modes "include" the seven — it does not say "only."
        let modes = [
            EidosRetrievalMode::Recency,
            EidosRetrievalMode::ProvenanceVerified,
        ];
        assert_eq!(modes.len(), 2);
    }
}
