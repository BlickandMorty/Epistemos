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

pub mod types;

pub use types::{
    CitationError, EidosChunkId, EidosCitation, EidosContextPacket, EidosDocumentId, EidosHit,
    EidosIndexManifest, EidosIndexManifestId, EidosProvenance, EidosQuery, EidosRetrievalMode,
    EidosScoreComponents, EidosSourceKind, EidosSpan,
};
