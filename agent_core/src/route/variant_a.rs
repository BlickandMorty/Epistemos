//! Phase 3B — Variant A: cosine to folder medoid embeddings (no LLM).
//!
//! Plan §4.3: threshold 0.85. For each top-level vault folder, maintain
//! a centroid (mean) or medoid (geometric median) embedding of its
//! notes' summaries. On capture, embed the capture, cosine to centroids,
//! top-1 if score ≥ 0.85. Folders with <3 notes are excluded (centroid
//! noisy). `_inbox/*` folders excluded.
//!
//! Per plan §1.4 No-LLM-First mandate this is a deterministic non-LLM
//! variant — embedding lookup, no inference. Hot path target: <50ms.
//!
//! The medoid storage / incremental rebuild (per §4.3) is a NightBrain
//! job (§7.1). 3B ships the variant logic; folder-medoid persistence
//! lands in 3C alongside the canonicalizer + alias table.

use std::sync::Arc;

use serde_json::Value;

use crate::cache::EmbeddingProvider;

use super::{AlternativePath, RouteDecision, VARIANT_A_FLOOR};

const INBOX_PREFIX: &str = "_inbox/";
const MIN_NOTE_COUNT_FOR_CENTROID: u32 = 3;
const TOP_K_NEIGHBOURS: usize = 5;

/// One folder candidate with its medoid embedding. Production callers
/// assemble these from a folder-medoid store; tests construct them
/// directly with controlled vectors.
#[derive(Debug, Clone)]
pub struct FolderCentroid {
    pub path: String,
    pub note_count: u32,
    pub medoid: Vec<f32>,
}

/// Plan §4.3 verbatim — embed query, score against folder medoids,
/// return Some(RouteDecision::place) only when top-1 cosine >= 0.85.
/// Returns None below threshold so the orchestrator can advance to
/// Variant B.
pub async fn try_centroid(
    capture_text: &str,
    folders: &[FolderCentroid],
    embedder: &Arc<dyn EmbeddingProvider>,
) -> Option<RouteDecision> {
    if capture_text.is_empty() {
        return None;
    }

    // Plan §4.3: folders with <3 notes excluded (centroid noisy).
    // _inbox/* folders excluded (they're staging, not destinations).
    let candidates: Vec<&FolderCentroid> = folders
        .iter()
        .filter(|f| !f.path.starts_with(INBOX_PREFIX))
        .filter(|f| f.note_count >= MIN_NOTE_COUNT_FOR_CENTROID)
        .filter(|f| !f.medoid.is_empty())
        .collect();

    if candidates.is_empty() {
        return None;
    }

    let query_embed = embedder.embed(&Value::String(capture_text.to_string())).await;
    if query_embed.is_empty() {
        return None;
    }

    let mut scored: Vec<(String, f32)> = candidates
        .iter()
        .map(|f| {
            (
                f.path.clone(),
                cosine(&query_embed, &f.medoid),
            )
        })
        .collect();

    // Descending by score, NaN-safe (NaN sinks to the bottom).
    scored.sort_by(|a, b| {
        b.1.partial_cmp(&a.1)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    let top = scored.into_iter().take(TOP_K_NEIGHBOURS).collect::<Vec<_>>();
    let confidence_f32 = top.first().map(|(_, s)| *s).unwrap_or(0.0);
    let confidence = confidence_f32 as f64;

    if confidence < VARIANT_A_FLOOR {
        return None;
    }

    let chosen_path = top[0].0.clone();
    let alternatives: Vec<AlternativePath> = top[1..]
        .iter()
        .map(|(p, s)| AlternativePath {
            path: p.clone(),
            score: *s as f64,
        })
        .collect();

    Some(RouteDecision {
        action: super::Action::Place,
        folder_path: Some(chosen_path),
        target_note_path: None,
        new_folder_name: None,
        confidence,
        reasoning_trace: format!(
            "variant_a centroid cosine {:.3} >= floor {:.2}",
            confidence, VARIANT_A_FLOOR
        ),
        alternative_paths: alternatives,
    })
}

/// L2-normalized inputs make this reduce to dot product (~3× faster);
/// we still write the full form so callers don't have to remember the
/// normalization invariant.
fn cosine(a: &[f32], b: &[f32]) -> f32 {
    if a.len() != b.len() || a.is_empty() {
        return 0.0;
    }
    let mut dot = 0.0_f32;
    let mut na = 0.0_f32;
    let mut nb = 0.0_f32;
    for i in 0..a.len() {
        dot += a[i] * b[i];
        na += a[i] * a[i];
        nb += b[i] * b[i];
    }
    if na == 0.0 || nb == 0.0 {
        return 0.0;
    }
    dot / (na.sqrt() * nb.sqrt())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cache::EmbeddingProvider;
    use crate::route::Action;
    use async_trait::async_trait;
    use std::collections::HashMap;

    /// Test embedder: returns a preconfigured vector for each input
    /// string. Lets tests engineer specific cosine values.
    struct MapEmbedder {
        map: HashMap<String, Vec<f32>>,
        dim: usize,
    }

    #[async_trait]
    impl EmbeddingProvider for MapEmbedder {
        async fn embed(&self, value: &Value) -> Vec<f32> {
            let key = value.as_str().unwrap_or("").to_string();
            self.map
                .get(&key)
                .cloned()
                .unwrap_or_else(|| vec![0.0; self.dim])
        }
        fn dim(&self) -> usize {
            self.dim
        }
    }

    fn embedder_with(map: HashMap<String, Vec<f32>>) -> Arc<dyn EmbeddingProvider> {
        Arc::new(MapEmbedder { map, dim: 4 })
    }

    fn folder(path: &str, count: u32, medoid: Vec<f32>) -> FolderCentroid {
        FolderCentroid {
            path: path.to_string(),
            note_count: count,
            medoid,
        }
    }

    #[tokio::test]
    async fn returns_none_when_no_folders_meet_min_note_count() {
        let folders = vec![
            folder("research/ml", 1, vec![1.0, 0.0, 0.0, 0.0]),
            folder("notes/journal", 2, vec![1.0, 0.0, 0.0, 0.0]),
        ];
        let mut map = HashMap::new();
        map.insert("test".to_string(), vec![1.0, 0.0, 0.0, 0.0]);
        let embedder = embedder_with(map);
        let result = try_centroid("test", &folders, &embedder).await;
        assert!(result.is_none(), "all folders below min count → None");
    }

    #[tokio::test]
    async fn skips_inbox_folders() {
        // _inbox/review has plenty of notes but must be excluded as a
        // routing destination (it's the defer target).
        let folders = vec![
            folder("_inbox/review", 100, vec![1.0, 0.0, 0.0, 0.0]),
            folder("_inbox/raw", 50, vec![1.0, 0.0, 0.0, 0.0]),
        ];
        let mut map = HashMap::new();
        map.insert("test".to_string(), vec![1.0, 0.0, 0.0, 0.0]);
        let embedder = embedder_with(map);
        let result = try_centroid("test", &folders, &embedder).await;
        assert!(result.is_none(), "_inbox/* is never a destination");
    }

    #[tokio::test]
    async fn returns_place_when_top_cosine_at_or_above_threshold() {
        // Engineer cosine = 1.0 (identical vectors).
        let folders = vec![
            folder("research/ml", 5, vec![1.0, 0.0, 0.0, 0.0]),
            folder("notes/journal", 5, vec![0.0, 1.0, 0.0, 0.0]),
        ];
        let mut map = HashMap::new();
        map.insert("a paper about ml".to_string(), vec![1.0, 0.0, 0.0, 0.0]);
        let embedder = embedder_with(map);
        let result = try_centroid("a paper about ml", &folders, &embedder).await;
        let decision = result.expect("identical-vector match must place");
        assert_eq!(decision.action, Action::Place);
        assert_eq!(decision.folder_path.as_deref(), Some("research/ml"));
        assert!(decision.confidence >= VARIANT_A_FLOOR);
        assert!(decision.confidence <= 1.0 + 1e-6);
    }

    #[tokio::test]
    async fn returns_none_below_threshold() {
        // Engineer top cosine ≈ 0.5 (orthogonal-ish).
        let folders = vec![
            folder("a", 5, vec![1.0, 0.0, 0.0, 0.0]),
            folder("b", 5, vec![0.0, 1.0, 0.0, 0.0]),
        ];
        let mut map = HashMap::new();
        // Roughly 45° to a → cos = 1/sqrt(2) ≈ 0.707 — still below 0.85.
        map.insert("test".to_string(), vec![1.0, 1.0, 0.0, 0.0]);
        let embedder = embedder_with(map);
        let result = try_centroid("test", &folders, &embedder).await;
        assert!(
            result.is_none(),
            "below 0.85 floor must return None so orchestrator advances to Variant B"
        );
    }

    #[tokio::test]
    async fn place_decision_includes_top_4_alternatives() {
        // Five folders with descending similarity to the query.
        let folders = vec![
            folder("a", 5, vec![1.00, 0.00, 0.00, 0.00]), // best (cos = ~0.99)
            folder("b", 5, vec![0.99, 0.10, 0.00, 0.00]),
            folder("c", 5, vec![0.95, 0.30, 0.00, 0.00]),
            folder("d", 5, vec![0.80, 0.50, 0.00, 0.00]),
            folder("e", 5, vec![0.50, 0.85, 0.00, 0.00]),
        ];
        let mut map = HashMap::new();
        map.insert("query".to_string(), vec![1.0, 0.0, 0.0, 0.0]);
        let embedder = embedder_with(map);
        let result = try_centroid("query", &folders, &embedder).await.unwrap();
        assert_eq!(result.folder_path.as_deref(), Some("a"));
        // Top-K is 5, so alternatives should be 4 (top-1 placed,
        // others are alternatives).
        assert_eq!(result.alternative_paths.len(), 4);
        // Alternatives sorted by descending score.
        for window in result.alternative_paths.windows(2) {
            assert!(
                window[0].score >= window[1].score,
                "alternatives must be score-descending"
            );
        }
    }

    #[tokio::test]
    async fn empty_capture_text_returns_none() {
        let folders = vec![folder("a", 5, vec![1.0, 0.0, 0.0, 0.0])];
        let embedder = embedder_with(HashMap::new());
        let result = try_centroid("", &folders, &embedder).await;
        assert!(result.is_none());
    }

    #[tokio::test]
    async fn empty_folders_returns_none() {
        let mut map = HashMap::new();
        map.insert("x".to_string(), vec![1.0, 0.0, 0.0, 0.0]);
        let embedder = embedder_with(map);
        let result = try_centroid("x", &[], &embedder).await;
        assert!(result.is_none());
    }

    #[tokio::test]
    async fn empty_medoid_folder_skipped() {
        let folders = vec![
            folder("empty", 5, vec![]),
            folder("ok", 5, vec![1.0, 0.0, 0.0, 0.0]),
        ];
        let mut map = HashMap::new();
        map.insert("x".to_string(), vec![1.0, 0.0, 0.0, 0.0]);
        let embedder = embedder_with(map);
        let result = try_centroid("x", &folders, &embedder).await.unwrap();
        // The empty-medoid folder must be skipped; "ok" wins.
        assert_eq!(result.folder_path.as_deref(), Some("ok"));
    }

    #[tokio::test]
    async fn reasoning_trace_carries_cosine_value_and_floor() {
        let folders = vec![folder("a", 5, vec![1.0, 0.0, 0.0, 0.0])];
        let mut map = HashMap::new();
        map.insert("x".to_string(), vec![1.0, 0.0, 0.0, 0.0]);
        let embedder = embedder_with(map);
        let result = try_centroid("x", &folders, &embedder).await.unwrap();
        assert!(result.reasoning_trace.contains("variant_a"));
        assert!(result.reasoning_trace.contains("cosine"));
        // Within 280-char cap.
        assert!(result.reasoning_trace.chars().count() <= super::super::REASONING_TRACE_MAX_CHARS);
    }

    #[test]
    fn cosine_basic_invariants() {
        assert!((cosine(&[1.0, 0.0], &[1.0, 0.0]) - 1.0).abs() < 1e-6);
        assert!((cosine(&[1.0, 0.0], &[0.0, 1.0])).abs() < 1e-6);
        assert!((cosine(&[1.0, 0.0], &[-1.0, 0.0]) + 1.0).abs() < 1e-6);
        assert_eq!(cosine(&[], &[]), 0.0);
        assert_eq!(cosine(&[1.0], &[1.0, 0.0]), 0.0);
    }
}
