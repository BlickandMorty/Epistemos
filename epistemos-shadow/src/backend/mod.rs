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

use std::sync::{Mutex, RwLock};
use std::time::Instant;

use rustc_hash::FxHashMap;

use crate::error::ShadowError;
use crate::{ShadowDocument, ShadowHit, ShadowStats};

use embedder::Embedder;
use lexical_index::LexicalIndex;
use vector_index::VectorIndex;

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

// MARK: - RealBackend (W8.4.e — the production implementor)
//
// Owns one shared Embedder (Model2Vec, lazy-init via Embedder::global()),
// one LexicalIndex (tantivy multi-domain, filtered at query time), and
// per-domain VectorIndex (one for "note", one for "chat" — keeps
// removals O(log n) without needing usearch metadata filtering).
//
// Thread-safe per the ShadowBackend contract: every mutating method
// hops through `Mutex` / `RwLock` guards before touching the index
// state. Reads are concurrent (RwLock::read).

pub struct RealBackend {
    embedder: &'static Embedder,
    lexical: LexicalIndex,
    vectors: RwLock<FxHashMap<String, VectorIndex>>,
    /// Snippet hydration map — doc_id → ShadowDocument so search can
    /// emit `snippet` + `title` without re-querying tantivy.
    docs: RwLock<FxHashMap<String, ShadowDocument>>,
    last_flush: Mutex<Instant>,
}

impl RealBackend {
    /// Construct a fresh RealBackend wired to `Embedder::global()`.
    /// Triggers HuggingFace download on first call (~30 MB cached
    /// at ~/.cache/huggingface/hub/). The Swift bootstrap should
    /// fire `shadow_warm()` (forthcoming FFI extension) at app start
    /// so this cost lands off the typing hot path.
    pub fn new() -> Result<Self, ShadowError> {
        let embedder = Embedder::global()?;
        let lexical = LexicalIndex::new()?;
        Ok(Self {
            embedder,
            lexical,
            vectors: RwLock::new(FxHashMap::default()),
            docs: RwLock::new(FxHashMap::default()),
            last_flush: Mutex::new(Instant::now()),
        })
    }

    fn ensure_vector_index(&self, domain: &str) -> Result<(), ShadowError> {
        let read_guard = self.vectors.read().expect("vectors lock poisoned");
        if read_guard.contains_key(domain) {
            return Ok(());
        }
        drop(read_guard);
        let mut write_guard = self.vectors.write().expect("vectors lock poisoned");
        if write_guard.contains_key(domain) {
            return Ok(());  // raced; someone else created it
        }
        let index = VectorIndex::new(embedder::EMBED_DIM)?;
        write_guard.insert(domain.to_string(), index);
        Ok(())
    }
}

impl ShadowBackend for RealBackend {
    fn insert_document(&self, doc: ShadowDocument) -> Result<(), ShadowError> {
        if doc.doc_id.is_empty() {
            return Err(ShadowError::InvalidInput {
                detail: "doc_id was empty".into(),
            });
        }
        if doc.domain != "note" && doc.domain != "chat" {
            return Err(ShadowError::InvalidInput {
                detail: format!("unknown domain '{}' (expected 'note' or 'chat')", doc.domain),
            });
        }

        // Embed the body (title concatenation is the V1 retrieval
        // strategy — title carries strong semantic signal).
        let combined = format!("{}\n{}", doc.title, doc.body);
        let embedding = self.embedder.encode_one(&combined);
        if embedding.len() != embedder::EMBED_DIM {
            return Err(ShadowError::Backend {
                detail: format!(
                    "embedder returned {} dims; expected {}",
                    embedding.len(),
                    embedder::EMBED_DIM
                ),
            });
        }

        self.ensure_vector_index(&doc.domain)?;
        {
            let vectors = self.vectors.read().expect("vectors lock poisoned");
            let index = vectors.get(&doc.domain).ok_or_else(|| ShadowError::Backend {
                detail: format!("vector index for '{}' missing post-ensure", doc.domain),
            })?;
            index.add(&doc.doc_id, &embedding)?;
        }

        self.lexical.insert(&doc)?;

        let mut docs = self.docs.write().expect("docs lock poisoned");
        docs.insert(doc.doc_id.clone(), doc);
        Ok(())
    }

    fn remove_document(&self, doc_id: &str) -> Result<(), ShadowError> {
        let mut docs = self.docs.write().expect("docs lock poisoned");
        let removed = docs.remove(doc_id);
        let Some(removed_doc) = removed else {
            return Err(ShadowError::NotFound {
                doc_id: doc_id.to_string(),
            });
        };

        if let Some(index) = self
            .vectors
            .read()
            .expect("vectors lock poisoned")
            .get(&removed_doc.domain)
        {
            index.remove(doc_id)?;
        }
        self.lexical.remove(doc_id)?;
        Ok(())
    }

    fn search(
        &self,
        query: &str,
        domain: &str,
        limit: usize,
    ) -> Result<Vec<ShadowHit>, ShadowError> {
        if domain != "note" && domain != "chat" {
            return Err(ShadowError::InvalidInput {
                detail: format!("unknown search domain '{domain}' (expected 'note' or 'chat')"),
            });
        }
        if query.trim().is_empty() || limit == 0 {
            return Ok(Vec::new());
        }

        // Encode + dense search through the per-domain VectorIndex.
        let dense_hits: Vec<(String, f32)> = {
            let vectors = self.vectors.read().expect("vectors lock poisoned");
            match vectors.get(domain) {
                Some(index) => {
                    let q_vec = self.embedder.encode_one(query);
                    if q_vec.is_empty() { Vec::new() } else { index.search(&q_vec, limit * 2) }
                }
                None => Vec::new(),
            }
        };

        let lexical_hits: Vec<(String, f32)> = self
            .lexical
            .search(query, domain, limit * 2)?
            .into_iter()
            .map(|h| (h.doc_id, h.score))
            .collect();

        // RRF fuse the two channels.
        let fused = rrf::rrf_fuse(&dense_hits, &lexical_hits, rrf::RRF_K_DEFAULT, limit);

        // Hydrate with snippet + title from the docs side map.
        let docs = self.docs.read().expect("docs lock poisoned");
        let dense_set: std::collections::HashSet<&str> =
            dense_hits.iter().map(|(id, _)| id.as_str()).collect();
        let lex_set: std::collections::HashSet<&str> =
            lexical_hits.iter().map(|(id, _)| id.as_str()).collect();

        let hits: Vec<ShadowHit> = fused
            .into_iter()
            .filter_map(|(doc_id, rrf_score)| {
                let doc = docs.get(&doc_id)?;
                let source = match (dense_set.contains(doc_id.as_str()), lex_set.contains(doc_id.as_str())) {
                    (true, true) => "rrf",
                    (true, false) => "dense",
                    (false, true) => "lexical",
                    (false, false) => "rrf",  // unreachable in practice
                };
                Some(ShadowHit {
                    doc_id: doc.doc_id.clone(),
                    title: doc.title.clone(),
                    snippet: build_snippet(&doc.body, query),
                    score: rrf_score,
                    source: source.to_string(),
                })
            })
            .collect();
        Ok(hits)
    }

    fn flush(&self) -> Result<(), ShadowError> {
        // V1 has nothing to flush (RAM-only); record the instant for
        // stats. W8.4.f wires real disk persistence.
        let mut last = self.last_flush.lock().expect("flush lock poisoned");
        *last = Instant::now();
        Ok(())
    }

    fn stats(&self) -> Result<ShadowStats, ShadowError> {
        let docs = self.docs.read().expect("docs lock poisoned");
        let mut note_count: u64 = 0;
        let mut chat_count: u64 = 0;
        let mut bytes: u64 = 0;
        for doc in docs.values() {
            bytes += (doc.title.len() + doc.body.len()) as u64;
            match doc.domain.as_str() {
                "note" => note_count += 1,
                "chat" => chat_count += 1,
                _ => {}
            }
        }
        let last_flush = self.last_flush.lock().expect("flush lock poisoned");
        Ok(ShadowStats {
            note_count,
            chat_count,
            index_size_bytes: bytes,
            last_flush_ms_ago: last_flush.elapsed().as_millis() as u64,
        })
    }
}

/// Pre-truncated snippet centred on the query match (or doc head when
/// no match). Mirrors the W8.1 stub's algorithm so the Swift inspector's
/// snippet display is unchanged.
fn build_snippet(body: &str, query: &str) -> String {
    const MAX: usize = 160;
    if body.len() <= MAX {
        return body.to_string();
    }
    let body_lower = body.to_lowercase();
    let query_lower = query.to_lowercase();
    let center = body_lower.find(&query_lower).unwrap_or(0);
    let half = MAX / 2;
    let start = center.saturating_sub(half);
    let end = (start + MAX).min(body.len());
    let safe_start = (0..=start).rev().find(|i| body.is_char_boundary(*i)).unwrap_or(0);
    let safe_end = (end..=body.len()).find(|i| body.is_char_boundary(*i)).unwrap_or(body.len());
    body[safe_start..safe_end].to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::state::ShadowState;

    #[test]
    fn shadow_state_satisfies_shadow_backend_trait() {
        // Regression guard for the W8.4.a contract.
        fn assert_trait<T: ShadowBackend>(_t: &T) {}
        let state = ShadowState::default();
        assert_trait(&state);
    }

    #[test]
    fn real_backend_satisfies_shadow_backend_trait() {
        // RealBackend MUST satisfy the trait without ever constructing
        // an instance — type-check only, doesn't call new() (which
        // would trigger Model2Vec download).
        fn assert_trait<T: ShadowBackend>() {}
        assert_trait::<RealBackend>();
    }

    #[test]
    #[ignore = "requires Model2Vec download (~30MB); run with --include-ignored"]
    fn real_backend_insert_then_search_returns_hit() {
        let backend = RealBackend::new().expect("RealBackend::new must succeed");
        let doc = ShadowDocument {
            doc_id: "doc-1".to_string(),
            domain: "note".to_string(),
            title: "Quarterly Report".to_string(),
            body: "Revenue grew by 12 percent across all regions.".to_string(),
        };
        backend.insert_document(doc).unwrap();

        let hits = backend.search("revenue", "note", 5).unwrap();
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].doc_id, "doc-1");
        assert!(hits[0].score > 0.0);
        // Fused source — the doc shows up in BOTH dense (semantic
        // similarity) and lexical (exact "revenue" match) channels.
        assert_eq!(hits[0].source, "rrf");
    }

    #[test]
    #[ignore = "requires Model2Vec download (~30MB); run with --include-ignored"]
    fn real_backend_search_filters_by_domain() {
        let backend = RealBackend::new().unwrap();
        backend
            .insert_document(ShadowDocument {
                doc_id: "n".into(),
                domain: "note".into(),
                title: "x".into(),
                body: "report".into(),
            })
            .unwrap();
        backend
            .insert_document(ShadowDocument {
                doc_id: "c".into(),
                domain: "chat".into(),
                title: "y".into(),
                body: "report".into(),
            })
            .unwrap();
        let note_hits = backend.search("report", "note", 5).unwrap();
        let chat_hits = backend.search("report", "chat", 5).unwrap();
        assert_eq!(note_hits.len(), 1);
        assert_eq!(note_hits[0].doc_id, "n");
        assert_eq!(chat_hits.len(), 1);
        assert_eq!(chat_hits[0].doc_id, "c");
    }
}
