//! Eidos V0 retriever trait — the seam where the seven canonical modes
//! (`Lexical`, `Semantic`, `Hybrid`, `CodeSymbol`, `ClaimEvidence`,
//! `GraphNeighborhood`, `RawArchive`) plug in.
//!
//! Every retriever **must**:
//!
//! 1. Bind itself to one [`EidosIndexManifestId`] for its lifetime. Two
//!    queries against the same retriever share the same manifest, which is
//!    the precondition for byte-equal replay.
//! 2. Emit `EidosHit`s whose `source_id` it controls. Downstream layers can
//!    only cite ids that came through a retriever, so the retriever is the
//!    sole source of legitimate citation tokens.
//! 3. Be **deterministic per manifest snapshot**: identical `(manifest, query,
//!    retrieved_at_unix_ms)` triples must produce byte-equal
//!    [`EidosContextPacket`]s.
//!
//! Retrievers are emit-only — they never mutate durable memory. The wider
//! runtime decides whether to materialize a packet into the cognitive DAG or
//! claim ledger.

use super::types::{EidosContextPacket, EidosIndexManifestId, EidosQuery, EidosRetrievalMode};

/// A retriever for a single Eidos retrieval mode bound to a single index
/// snapshot. The trait is intentionally narrow — the seven concrete modes
/// differ in indexing strategy, not in interface.
///
/// `Send + Sync` are required so retrievers can be held as
/// `Box<dyn EidosRetriever>` inside the Swift bridge / a future retriever
/// registry without thread-safety casts. Every method takes `&self` so a
/// retriever can be queried concurrently from multiple threads (the FFI
/// boundary serializes by convention, but the contract allows parallelism).
pub trait EidosRetriever: Send + Sync {
    /// Which of the seven canonical modes this retriever serves.
    fn mode(&self) -> EidosRetrievalMode;

    /// The index snapshot this retriever is bound to. Returned by reference
    /// so callers can compare against an [`EidosCitation`]'s manifest id
    /// without allocating.
    fn manifest_id(&self) -> &EidosIndexManifestId;

    /// Run `query` against the retriever's index and return a sealed packet.
    ///
    /// `retrieved_at_unix_ms` is caller-supplied so tests can pin the clock
    /// and prove byte-equal replay across runs. In production this is the
    /// monotonic wall-clock at query time.
    fn retrieve(
        &self,
        query: &EidosQuery,
        retrieved_at_unix_ms: u64,
    ) -> EidosContextPacket;
}
