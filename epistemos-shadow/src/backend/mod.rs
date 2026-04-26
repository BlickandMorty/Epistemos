//! W8.4.a — module skeleton + `ShadowBackend` trait.
//!
//! The real backend (Model2Vec encoder + usearch HNSW + tantivy BM25
//! + RRF fusion) lands in W8.4.b–.f. This commit ships:
//!
//!   - the trait the FFI surface dispatches through
//!   - empty submodule files (`embedder`, `vector_index`,
//!     `lexical_index`, `rrf`) so subsequent commits can fill them in
//!   - a blanket impl for the existing `ShadowState` stub so the
//!     11 source-guard tests in `state.rs:210-359` keep passing
//!     against the trait-object dispatch path
//!
//! Once W8.4.e ships the `RealBackend`, the FFI dispatch flips from
//! `&'static ShadowState` to `&'static dyn ShadowBackend` and the
//! HashMap stub gets deleted. Everything outside `state.rs` already
//! sees the trait surface, so the swap is a single-file change.
//!
//! Per the audit agent's verdict (2026-04-26): test #11
//! `snippet_handles_unicode_boundary` will hang the first run if
//! Model2Vec's HuggingFace download is cold. W8.4.b will add a
//! `shadow_warm()` FFI entry point Swift bootstrap can fire-and-forget
//! at app start.

pub mod embedder;
pub mod lexical_index;
pub mod rrf;
pub mod vector_index;

use crate::error::ShadowError;
use crate::{ShadowDocument, ShadowHit, ShadowStats};

/// Pluggable backend for the Shadow engine. The FFI surface
/// (`shadow_insert_json` / `shadow_remove_json` / `shadow_search_json`
/// / `shadow_flush` / `shadow_stats_json` in lib.rs) dispatches every
/// call through this trait. The W8.1 stub at `state::ShadowState` is
/// the V1 implementor; W8.4.e replaces it with `RealBackend` (in this
/// module) without changing the FFI signatures.
///
/// Trait is `Send + Sync` because `lib.rs` reaches the singleton
/// across the FFI boundary on whatever thread the Swift caller hops
/// onto. Implementors that need interior mutability must use
/// `parking_lot::RwLock` or `tokio::sync` to honor that contract.
pub trait ShadowBackend: Send + Sync {
    fn insert_document(&self, doc: ShadowDocument) -> Result<(), ShadowError>;
    fn remove_document(&self, doc_id: &str) -> Result<(), ShadowError>;
    fn search(
        &self,
        query: &str,
        domain: &str,
        limit: usize,
    ) -> Result<Vec<ShadowHit>, ShadowError>;
    fn flush(&self) -> Result<(), ShadowError>;
    fn stats(&self) -> Result<ShadowStats, ShadowError>;
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::state::ShadowState;

    #[test]
    fn shadow_state_satisfies_shadow_backend_trait() {
        // Regression guard for the W8.4.a contract: until W8.4.e
        // replaces the singleton, ShadowState MUST satisfy the trait
        // so the FFI surface compiles unchanged.
        fn assert_trait<T: ShadowBackend>(_t: &T) {}
        let state = ShadowState::default();
        assert_trait(&state);
    }
}
