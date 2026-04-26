//! Process-wide indexer state — W9.7 stub backend.
//!
//! In-memory HashMap that satisfies the FFI contract so the Swift
//! AgentGrepService (W9.9) can be wired against a real crate today.
//! Search uses a naive substring scan ranked by:
//!   - symbol match (extracted symbols not yet populated by the W9.7
//!     follow-up; placeholder column wired through)
//!   - body position (closer to start scores higher)
//!   - title-of-file match (vault path basename)
//!
//! The W9.7 follow-up swaps the body for Model2Vec encoding +
//! usearch HNSW search + tantivy BM25 + RRF fusion (matching the
//! Halo Shadow stack).

use std::collections::HashMap;
use std::sync::OnceLock;

use parking_lot::RwLock;

use crate::error::CodeIndexError;
use crate::{CodeIndexDocument, CodeIndexHit, CodeIndexStats};

pub struct CodeIndexState {
    inner: RwLock<Inner>,
}

#[derive(Default)]
struct Inner {
    docs: HashMap<String, CodeIndexDocument>,
}

impl CodeIndexState {
    fn new() -> Self {
        Self {
            inner: RwLock::new(Inner::default()),
        }
    }

    pub fn upsert(&self, doc: CodeIndexDocument) -> Result<(), CodeIndexError> {
        if doc.vault_relative_path.is_empty() {
            return Err(CodeIndexError::InvalidInput {
                detail: "vault_relative_path was empty".into(),
            });
        }
        if doc.kind.is_empty() {
            return Err(CodeIndexError::InvalidInput {
                detail: "kind was empty".into(),
            });
        }
        let mut guard = self.inner.write();
        guard.docs.insert(doc.vault_relative_path.clone(), doc);
        Ok(())
    }

    pub fn remove(&self, vault_relative_path: &str) -> Result<(), CodeIndexError> {
        let mut guard = self.inner.write();
        if guard.docs.remove(vault_relative_path).is_some() {
            Ok(())
        } else {
            Err(CodeIndexError::NotFound {
                vault_relative_path: vault_relative_path.to_string(),
            })
        }
    }

    /// Search the index. Stub semantics:
    ///   - case-insensitive substring match against `body` + path
    ///     basename
    ///   - Optional kind filter (matches CodeArtifactKind.rawValue)
    ///   - Score: 2.0 if path basename contains query, 1.0 if body
    ///     contains query (added; capped at 3.0)
    pub fn search(
        &self,
        query: &str,
        kind_filter: Option<&str>,
        limit: usize,
    ) -> Result<Vec<CodeIndexHit>, CodeIndexError> {
        let q = query.trim().to_lowercase();
        if q.is_empty() {
            return Ok(Vec::new());
        }
        let guard = self.inner.read();
        let mut hits: Vec<CodeIndexHit> = guard
            .docs
            .values()
            .filter(|doc| match kind_filter {
                Some(k) if !k.is_empty() => doc.kind == k,
                _ => true,
            })
            .filter_map(|doc| {
                let body_lower = doc.body.to_lowercase();
                let basename_lower = doc
                    .vault_relative_path
                    .rsplit('/')
                    .next()
                    .map(str::to_lowercase)
                    .unwrap_or_default();

                let path_hit = basename_lower.contains(&q);
                let body_pos = body_lower.find(&q);
                if !path_hit && body_pos.is_none() {
                    return None;
                }

                let mut score: f32 = 0.0;
                if path_hit {
                    score += 2.0;
                }
                if body_pos.is_some() {
                    score += 1.0;
                }
                score = score.min(3.0);

                let snippet = build_snippet(&doc.body, body_pos);
                Some(CodeIndexHit {
                    vault_relative_path: doc.vault_relative_path.clone(),
                    kind: doc.kind.clone(),
                    score,
                    snippet,
                    symbol: None,
                    source: "stub-substring".to_string(),
                })
            })
            .collect();

        hits.sort_by(|a, b| {
            b.score
                .partial_cmp(&a.score)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        hits.truncate(limit);
        Ok(hits)
    }

    pub fn stats(&self) -> Result<CodeIndexStats, CodeIndexError> {
        let guard = self.inner.read();
        let mut per_kind: HashMap<String, u64> = HashMap::new();
        let mut bytes: u64 = 0;
        for doc in guard.docs.values() {
            *per_kind.entry(doc.kind.clone()).or_insert(0) += 1;
            bytes += doc.body.len() as u64;
        }
        let per_kind_json = serde_json::to_string(&per_kind).map_err(|error| {
            CodeIndexError::Backend {
                detail: format!("per_kind serialise failed: {error}"),
            }
        })?;
        Ok(CodeIndexStats {
            document_count: guard.docs.len() as u64,
            per_kind_counts_json: per_kind_json,
            total_body_bytes: bytes,
        })
    }
}

static STATE: OnceLock<CodeIndexState> = OnceLock::new();

pub fn code_index_state() -> &'static CodeIndexState {
    STATE.get_or_init(CodeIndexState::new)
}

fn build_snippet(body: &str, hit_pos: Option<usize>) -> String {
    const MAX: usize = 200;
    if body.len() <= MAX {
        return body.to_string();
    }
    let center = hit_pos.unwrap_or(0);
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

    fn fresh() -> CodeIndexState {
        CodeIndexState::new()
    }

    fn doc(path: &str, kind: &str, body: &str) -> CodeIndexDocument {
        CodeIndexDocument {
            vault_relative_path: path.into(),
            kind: kind.into(),
            body: body.into(),
            content_hash: "deadbeef".into(),
        }
    }

    #[test]
    fn upsert_then_search_finds_by_path() {
        let state = fresh();
        state.upsert(doc("Sources/Foo.swift", "swift", "fn body")).unwrap();
        let hits = state.search("foo", None, 10).unwrap();
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].vault_relative_path, "Sources/Foo.swift");
        assert!(hits[0].score > 0.0);
    }

    #[test]
    fn upsert_then_search_finds_by_body() {
        let state = fresh();
        state.upsert(doc("Sources/Bar.swift", "swift", "kant duty discussion")).unwrap();
        let hits = state.search("kant", None, 10).unwrap();
        assert_eq!(hits.len(), 1);
        assert!(hits[0].snippet.to_lowercase().contains("kant"));
    }

    #[test]
    fn empty_query_returns_empty() {
        let state = fresh();
        state.upsert(doc("a.swift", "swift", "anything")).unwrap();
        assert!(state.search("", None, 10).unwrap().is_empty());
        assert!(state.search("   ", None, 10).unwrap().is_empty());
    }

    #[test]
    fn empty_path_rejected_on_upsert() {
        let state = fresh();
        let err = state.upsert(doc("", "swift", "x")).unwrap_err();
        assert!(matches!(err, CodeIndexError::InvalidInput { .. }));
    }

    #[test]
    fn empty_kind_rejected_on_upsert() {
        let state = fresh();
        let err = state.upsert(doc("a.swift", "", "x")).unwrap_err();
        assert!(matches!(err, CodeIndexError::InvalidInput { .. }));
    }

    #[test]
    fn kind_filter_narrows_results() {
        let state = fresh();
        state.upsert(doc("a.swift", "swift", "kant")).unwrap();
        state.upsert(doc("b.rs", "rust", "kant")).unwrap();
        let swift_hits = state.search("kant", Some("swift"), 10).unwrap();
        let rust_hits = state.search("kant", Some("rust"), 10).unwrap();
        assert_eq!(swift_hits.len(), 1);
        assert_eq!(rust_hits.len(), 1);
        assert_eq!(swift_hits[0].kind, "swift");
        assert_eq!(rust_hits[0].kind, "rust");
    }

    #[test]
    fn empty_kind_filter_means_all_kinds() {
        let state = fresh();
        state.upsert(doc("a.swift", "swift", "kant")).unwrap();
        state.upsert(doc("b.rs", "rust", "kant")).unwrap();
        let hits = state.search("kant", Some(""), 10).unwrap();
        assert_eq!(hits.len(), 2);
    }

    #[test]
    fn path_match_outranks_body_match() {
        let state = fresh();
        state.upsert(doc("Sources/Kant.swift", "swift", "unrelated body")).unwrap();
        state.upsert(doc("Sources/Bar.swift", "swift", "this mentions kant in passing")).unwrap();
        let hits = state.search("kant", None, 10).unwrap();
        assert_eq!(hits[0].vault_relative_path, "Sources/Kant.swift", "path match must outrank body-only");
    }

    #[test]
    fn limit_caps_results() {
        let state = fresh();
        for i in 0..15 {
            state.upsert(doc(&format!("f{i}.swift"), "swift", "kant")).unwrap();
        }
        let hits = state.search("kant", None, 5).unwrap();
        assert_eq!(hits.len(), 5);
    }

    #[test]
    fn remove_then_search_returns_empty() {
        let state = fresh();
        state.upsert(doc("Foo.swift", "swift", "kant")).unwrap();
        state.remove("Foo.swift").unwrap();
        assert!(state.search("kant", None, 10).unwrap().is_empty());
    }

    #[test]
    fn remove_unknown_returns_not_found() {
        let state = fresh();
        let err = state.remove("missing.swift").unwrap_err();
        assert!(matches!(err, CodeIndexError::NotFound { .. }));
    }

    #[test]
    fn stats_count_per_kind() {
        let state = fresh();
        state.upsert(doc("a.swift", "swift", "x")).unwrap();
        state.upsert(doc("b.swift", "swift", "y")).unwrap();
        state.upsert(doc("c.rs", "rust", "z")).unwrap();
        let stats = state.stats().unwrap();
        assert_eq!(stats.document_count, 3);
        let parsed: HashMap<String, u64> = serde_json::from_str(&stats.per_kind_counts_json).unwrap();
        assert_eq!(parsed.get("swift"), Some(&2));
        assert_eq!(parsed.get("rust"), Some(&1));
    }

    #[test]
    fn snippet_handles_unicode_boundary() {
        let mut body = String::new();
        for _ in 0..50 {
            body.push_str("hellö ");
        }
        let state = fresh();
        state.upsert(doc("u.swift", "swift", &body)).unwrap();
        let hits = state.search("hellö", None, 1).unwrap();
        assert!(!hits.is_empty());
        let _ = hits[0].snippet.chars().count();
    }
}
