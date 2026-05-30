//! # `eidos` — Eidos V0
//!
//! Deterministic local-first search fusion + closed-citation retrieval for the
//! Epistemos current-product (MAS) tier. Eidos V0 is the **product retrieval
//! organ**: vault / `.epdoc` / chat / code / graph / shadow / raw-archive hits
//! are returned as a sealed `EidosContextPacket` whose `source_id`s are the
//! only IDs the chat/model layer is permitted to cite.
//!
//! Scope (per `docs/NO_COMPROMISE_ENDGAME_PROMPT_DECK_2026_05_18.md` §4 T10):
//!
//! - **Local-first.** No network by default. Web augmentation, Metal
//!   re-rankers, and llguidance-shaped reasoning are Eidos Plus and live
//!   outside this module.
//! - **Closed-citation contract.** The chat layer may cite **only** the
//!   `EidosChunkId`s returned in the packet. Any candidate citation whose
//!   `source_id` is not present in the packet is **rejected** by
//!   [`EidosContextPacket::validate_citation`].
//! - **Deterministic per index snapshot.** Every hit carries the
//!   [`EidosIndexManifestId`] of the snapshot it was retrieved against, so the
//!   same query against the same manifest always produces a byte-equal packet.
//! - **TypedArtifact-compatible.** Results are emit-only — Eidos never mutates
//!   durable memory; the broader runtime decides whether to materialize a
//!   packet into the cognitive DAG / claim ledger.
//!
//! Eidos V0 does **not** include: model inference, training, browser/web
//! augmentation, `ProseEditor*` internals, or the legacy `agent_runtime/`
//! orchestrator. The form-layer slice (`EidosKind`, canonical schemas) lands
//! in T10B against `eidos::forms` later in the loop.

pub mod adversarial;
pub mod claim_evidence;
pub mod code_symbol;
pub mod dag_backed_graph_neighborhood;
pub mod falsifier;
pub mod graph_neighborhood;
pub mod hybrid;
pub mod hybrid_n;
pub mod ledger_backed_claim_evidence;
pub mod lexical;
pub mod provenance_verified;
pub mod raw_archive;
pub mod recency;
pub mod retriever;
pub mod semantic;
pub mod types;
pub mod validator;

#[cfg(test)]
mod hardening_tests;

#[cfg(test)]
mod parity;

pub use claim_evidence::{EvidenceStance, InMemoryClaimEvidence};
pub use code_symbol::InMemoryCodeSymbolIndex;
pub use dag_backed_graph_neighborhood::{DagBackedGraphNeighborhood, NodeNameResolver};
pub use falsifier::{
    f_eidos_closed_citation_falsifier, FEidosClosedCitationWitness, FalsifierFailure,
};
pub use graph_neighborhood::InMemoryGraphNeighborhood;
pub use hybrid::{HybridConstructionError, HybridRetriever, RRF_K_DEFAULT};
pub use hybrid_n::{HybridNConstructionError, HybridRetrieverN};
pub use ledger_backed_claim_evidence::LedgerBackedClaimEvidence;
pub use lexical::InMemoryLexicalIndex;
pub use provenance_verified::ProvenanceVerifiedRetriever;
pub use raw_archive::InMemoryRawArchive;
pub use recency::InMemoryRecencyIndex;
pub use retriever::EidosRetriever;
pub use semantic::{InMemorySemanticIndex, SemanticIndexError};
pub use types::{
    CitationError, EidosChunkId, EidosCitation, EidosCitationEnvelope, EidosContextPacket,
    EidosDocumentId, EidosHit, EidosIndexManifest, EidosIndexManifestId, EidosProvenance,
    EidosQuery, EidosRetrievalMode, EidosScoreComponents, EidosSourceKind, EidosSpan,
};
pub use validator::{
    enforce_closed_citation_contract, ClosedCitationValidation, ClosedCitationValidationError,
};

/// R1 (2026-05-23): production-capable [`EidosRetriever`] JSON helper.
///
/// Takes any retriever (fixture OR production-backed), runs a text query
/// against it, and returns the JSON-encoded [`EidosContextPacket`]. The
/// query mode is taken from [`EidosRetriever::mode`] so callers cannot
/// accidentally pass a query whose mode disagrees with the retriever's
/// index strategy (a mode mismatch typically yields an empty packet —
/// silently broken).
///
/// **Why this exists**: the bridge FFI `eidos_search_lexical_json`
/// (`agent_core/src/bridge.rs`) is hard-coded against a process-global
/// `EIDOS_FIXTURE_INDEX` singleton (a 2-document seeded corpus). This
/// helper is the production seam: any caller that already holds a real
/// retriever ([`LedgerBackedClaimEvidence`] for W-49, a future
/// shadow-backed lexical index for W-51, or any other production
/// retriever) MUST route through this helper instead of rebuilding the
/// fixture-bound FFI body. The closed-citation contract, determinism,
/// and serde wire shape are all unchanged — the helper is a pure
/// pass-through with mode canonicalization on top.
///
/// `retrieved_at_unix_ms` is caller-supplied so tests can pin the
/// clock and prove byte-equal replay across runs.
pub fn produce_eidos_context_packet_json<R: EidosRetriever + ?Sized>(
    retriever: &R,
    query_text: &str,
    top_k: u16,
    retrieved_at_unix_ms: u64,
) -> Result<String, serde_json::Error> {
    let packet = produce_eidos_context_packet(retriever, query_text, top_k, retrieved_at_unix_ms);
    serde_json::to_string(&packet)
}

/// Typed-packet variant of [`produce_eidos_context_packet_json`].
/// Returns the [`EidosContextPacket`] directly for callers that don't
/// need JSON (e.g. an in-process consumer of `EidosHit`/`EidosCitation`).
///
/// The JSON helper delegates to this function — they share one
/// canonicalization path so the two surfaces stay in lockstep.
pub fn produce_eidos_context_packet<R: EidosRetriever + ?Sized>(
    retriever: &R,
    query_text: &str,
    top_k: u16,
    retrieved_at_unix_ms: u64,
) -> EidosContextPacket {
    let query = EidosQuery::new(query_text, retriever.mode(), top_k);
    retriever.retrieve(&query, retrieved_at_unix_ms)
}
