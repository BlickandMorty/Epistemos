//! Global singleton state for the Shadow engine — W8.1 stub backend.
//!
//! The W8.1 base ships an in-memory HashMap that satisfies the FFI
//! surface contract so the Swift HaloController can be wired against
//! a real crate today. The W8.4 follow-up swaps the body for the
//! real Model2Vec + usearch + tantivy + RRF backend per the V1
//! decision §"Retrieval".
//!
//! The singleton pattern matches the reference at
//! `ambient/epistemos_shadow.rs` — exactly one engine instance per
//! process, reachable through `shadow_state()`.

use std::collections::HashMap;
use std::sync::OnceLock;
use std::time::Instant;

use parking_lot::RwLock;

use crate::error::ShadowError;
use crate::{ShadowDocument, ShadowHit, ShadowStats};

/// The Wave 8.1 stub backend — an in-memory HashMap of doc_id →
/// document. Search is a naive substring scan, scored by snippet
/// position. Sufficient for HaloController state-machine tests +
/// FFI contract verification; replaced by the real backend in W8.4.
pub struct ShadowState {
    inner: RwLock<Inner>,
}

struct Inner {
    docs: HashMap<String, ShadowDocument>,
    last_flush: Instant,
}

impl Default for Inner {
    fn default() -> Self {
        Self {
            docs: HashMap::new(),
            last_flush: Instant::now(),
        }
    }
}

impl ShadowState {
    fn new() -> Self {
        Self {
            inner: RwLock::new(Inner::default()),
        }
    }

    /// Insert or replace a document.
    pub fn insert_document(&self, doc: ShadowDocument) -> Result<(), ShadowError> {
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
        let mut guard = self.inner.write();
        guard.docs.insert(doc.doc_id.clone(), doc);
        Ok(())
    }

    /// Remove a document. Idempotent — removing an unknown doc returns NotFound.
    pub fn remove_document(&self, doc_id: &str) -> Result<(), ShadowError> {
        let mut guard = self.inner.write();
        if guard.docs.remove(doc_id).is_some() {
            Ok(())
        } else {
            Err(ShadowError::NotFound {
                doc_id: doc_id.to_string(),
            })
        }
    }

    /// Search the index. The W8.1 stub does case-insensitive substring
    /// matching across title + body and ranks by:
    ///   - title match (score += 2.0)
    ///   - body match position (closer to start scores higher)
    ///   - exact-token match (score += 0.5)
    ///
    /// Replaced in W8.4 by the real Model2Vec + usearch HNSW + tantivy
    /// BM25 + RRF fusion pipeline per the V1 decision.
    pub fn search(
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
        let query_lower = query.to_lowercase();
        if query_lower.trim().is_empty() {
            return Ok(Vec::new());
        }

        let guard = self.inner.read();
        let mut hits: Vec<ShadowHit> = guard
            .docs
            .values()
            .filter(|doc| doc.domain == domain)
            .filter_map(|doc| {
                let title_lower = doc.title.to_lowercase();
                let body_lower = doc.body.to_lowercase();
                let title_hit = title_lower.contains(&query_lower);
                let body_hit_pos = body_lower.find(&query_lower);
                if !title_hit && body_hit_pos.is_none() {
                    return None;
                }

                let mut score: f32 = 0.0;
                if title_hit {
                    score += 2.0;
                }
                if let Some(pos) = body_hit_pos {
                    let body_len = doc.body.len().max(1) as f32;
                    score += 1.0 - (pos as f32 / body_len);
                }
                if title_lower
                    .split_whitespace()
                    .any(|tok| tok == query_lower)
                {
                    score += 0.5;
                }

                let snippet = build_snippet(&doc.body, body_hit_pos);
                Some(ShadowHit {
                    doc_id: doc.doc_id.clone(),
                    title: doc.title.clone(),
                    snippet,
                    score,
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

    /// Persist the index. The W8.1 stub records the flush instant for
    /// the stats endpoint; W8.4 wires real disk persistence.
    pub fn flush(&self) -> Result<(), ShadowError> {
        let mut guard = self.inner.write();
        guard.last_flush = Instant::now();
        Ok(())
    }

    /// Aggregate stats for the developer panel.
    pub fn stats(&self) -> Result<ShadowStats, ShadowError> {
        let guard = self.inner.read();
        let mut note_count: u64 = 0;
        let mut chat_count: u64 = 0;
        let mut bytes: u64 = 0;
        for doc in guard.docs.values() {
            bytes += (doc.title.len() + doc.body.len()) as u64;
            match doc.domain.as_str() {
                "note" => note_count += 1,
                "chat" => chat_count += 1,
                _ => {}
            }
        }
        Ok(ShadowStats {
            note_count,
            chat_count,
            index_size_bytes: bytes,
            last_flush_ms_ago: guard.last_flush.elapsed().as_millis() as u64,
        })
    }
}

static SHADOW_STATE: OnceLock<ShadowState> = OnceLock::new();

/// Process-wide engine handle. Lazy-initialised on first call so an
/// app that never uses Contextual Shadows pays zero startup cost.
pub fn shadow_state() -> &'static ShadowState {
    SHADOW_STATE.get_or_init(ShadowState::new)
}

/// Pre-truncated snippet centred around the body match (or the
/// document head when only the title matched). Capped at 160 chars
/// per the V1 decision §"shadow hit shape".
fn build_snippet(body: &str, hit_pos: Option<usize>) -> String {
    const MAX: usize = 160;
    if body.len() <= MAX {
        return body.to_string();
    }
    let center = hit_pos.unwrap_or(0);
    let half = MAX / 2;
    let start = center.saturating_sub(half);
    let end = (start + MAX).min(body.len());
    // Snap to char boundaries so we don't slice mid-codepoint.
    let safe_start = (0..=start).rev().find(|i| body.is_char_boundary(*i)).unwrap_or(0);
    let safe_end = (end..=body.len()).find(|i| body.is_char_boundary(*i)).unwrap_or(body.len());
    body[safe_start..safe_end].to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fresh_state() -> ShadowState {
        ShadowState::new()
    }

    fn note(id: &str, title: &str, body: &str) -> ShadowDocument {
        ShadowDocument {
            doc_id: id.into(),
            title: title.into(),
            body: body.into(),
            domain: "note".into(),
        }
    }

    #[test]
    fn insert_then_search_returns_hit() {
        let state = fresh_state();
        state.insert_document(note("n1", "Kant on duty", "Categorical imperative discussion")).unwrap();
        let hits = state.search("kant", "note", 10).unwrap();
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].doc_id, "n1");
        assert!(hits[0].score > 0.0);
    }

    #[test]
    fn empty_query_returns_empty_results() {
        let state = fresh_state();
        state.insert_document(note("n1", "anything", "anything")).unwrap();
        assert!(state.search("", "note", 10).unwrap().is_empty());
        assert!(state.search("   ", "note", 10).unwrap().is_empty());
    }

    #[test]
    fn unknown_domain_rejected_on_search() {
        let state = fresh_state();
        let err = state.search("kant", "unknown", 10).unwrap_err();
        assert!(matches!(err, ShadowError::InvalidInput { .. }));
    }

    #[test]
    fn unknown_domain_rejected_on_insert() {
        let state = fresh_state();
        let err = state.insert_document(ShadowDocument {
            doc_id: "x".into(),
            title: "x".into(),
            body: "x".into(),
            domain: "unknown".into(),
        }).unwrap_err();
        assert!(matches!(err, ShadowError::InvalidInput { .. }));
    }

    #[test]
    fn empty_doc_id_rejected_on_insert() {
        let state = fresh_state();
        let err = state.insert_document(ShadowDocument {
            doc_id: "".into(),
            title: "t".into(),
            body: "b".into(),
            domain: "note".into(),
        }).unwrap_err();
        assert!(matches!(err, ShadowError::InvalidInput { .. }));
    }

    #[test]
    fn search_filters_by_domain() {
        let state = fresh_state();
        state.insert_document(note("n1", "kant", "kant body")).unwrap();
        state.insert_document(ShadowDocument {
            doc_id: "c1".into(),
            title: "kant chat".into(),
            body: "kant chat body".into(),
            domain: "chat".into(),
        }).unwrap();
        let notes = state.search("kant", "note", 10).unwrap();
        let chats = state.search("kant", "chat", 10).unwrap();
        assert_eq!(notes.len(), 1);
        assert_eq!(chats.len(), 1);
        assert_eq!(notes[0].doc_id, "n1");
        assert_eq!(chats[0].doc_id, "c1");
    }

    #[test]
    fn title_hit_outranks_body_only_hit() {
        let state = fresh_state();
        state.insert_document(note("title", "kant on duty", "unrelated body")).unwrap();
        state.insert_document(note("body", "unrelated title", "this mentions kant in passing")).unwrap();
        let hits = state.search("kant", "note", 10).unwrap();
        assert_eq!(hits[0].doc_id, "title", "title match must outrank body-only match");
    }

    #[test]
    fn limit_caps_results() {
        let state = fresh_state();
        for i in 0..20 {
            state.insert_document(note(&format!("n{i}"), "kant", "kant")).unwrap();
        }
        let hits = state.search("kant", "note", 5).unwrap();
        assert_eq!(hits.len(), 5);
    }

    #[test]
    fn remove_then_search_returns_empty() {
        let state = fresh_state();
        state.insert_document(note("n1", "kant", "kant")).unwrap();
        state.remove_document("n1").unwrap();
        assert!(state.search("kant", "note", 10).unwrap().is_empty());
    }

    #[test]
    fn remove_unknown_returns_not_found() {
        let state = fresh_state();
        let err = state.remove_document("unknown").unwrap_err();
        assert!(matches!(err, ShadowError::NotFound { .. }));
    }

    #[test]
    fn stats_track_counts_per_domain() {
        let state = fresh_state();
        state.insert_document(note("n1", "a", "b")).unwrap();
        state.insert_document(note("n2", "c", "d")).unwrap();
        state.insert_document(ShadowDocument {
            doc_id: "c1".into(),
            title: "x".into(),
            body: "y".into(),
            domain: "chat".into(),
        }).unwrap();
        let stats = state.stats().unwrap();
        assert_eq!(stats.note_count, 2);
        assert_eq!(stats.chat_count, 1);
        assert!(stats.index_size_bytes > 0);
    }

    #[test]
    fn snippet_handles_unicode_boundary() {
        // 200-char body with multibyte chars; snippet must not slice
        // mid-codepoint.
        let mut body = String::new();
        for _ in 0..40 {
            body.push_str("hellö ");  // ö is 2 bytes in UTF-8
        }
        let state = fresh_state();
        state.insert_document(note("u", "title", &body)).unwrap();
        let hits = state.search("hellö", "note", 1).unwrap();
        // The snippet is valid UTF-8 (didn't panic on slice).
        assert!(!hits.is_empty());
        let _ = hits[0].snippet.chars().count();
    }
}
