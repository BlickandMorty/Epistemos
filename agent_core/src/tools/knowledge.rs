//! Knowledge Tools — Phase 2 Vault-Native Capabilities
//!
//! Implements the knowledge-and-memory layer that differentiates Epistemos
//! from plugin-based PKM apps:
//!
//!   * `vault_recall`       — hybrid semantic+keyword search with latency
//!   * `contradiction_check`— surface epistemic conflicts before writing
//!   * `session_search`     — browse past sessions recorded in the vault
//!   * `neural_recall`      — tiered hot/warm/cold cache lookup
//!
//! All four are pure Rust wrappers around services already implemented in
//! `agent_core::storage::*`. They require no FFI bridge.

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Instant;

use async_trait::async_trait;
use chrono::Utc;
use serde_json::{json, Value};

use crate::storage::contradiction_detector::detect_contradictions;
use crate::storage::memory_classifier::VaultFact;
use crate::storage::neural_cache::NeuralCache;
use crate::storage::session_store::list_session_folders;
use crate::storage::vault::VaultBackend;

use super::registry::{ToolError, ToolHandler};

// MARK: - vault_recall

pub struct VaultRecallHandler {
    vault: Arc<dyn VaultBackend>,
}

crate::impl_tool_via_legacy_handler!(
    VaultRecallHandler,
    name = "knowledge.recall",
    input_schema = super::v2_catalog::knowledge_recall::input_schema,
    profile = super::Profile::AppStoreSafe,
    small_model_safe = true,
);

impl VaultRecallHandler {
    pub fn new(vault: Arc<dyn VaultBackend>) -> Self {
        Self { vault }
    }
}

#[async_trait]
impl ToolHandler for VaultRecallHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let query = input
            .get("query")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'query'".into()))?;
        let top_k = input
            .get("top_k")
            .and_then(Value::as_u64)
            .unwrap_or(5)
            .clamp(1, 20) as usize;
        let tag_filter: Vec<String> = input
            .get("note_filter")
            .and_then(Value::as_array)
            .map(|arr| {
                arr.iter()
                    .filter_map(|v| v.as_str().map(String::from))
                    .collect()
            })
            .unwrap_or_default();

        let start = Instant::now();
        let results = self
            .vault
            .hybrid_search(query, top_k, &tag_filter)
            .await
            .map_err(|e| ToolError::ExecutionFailed(format!("vault search failed: {e}")))?;
        let latency_ms = start.elapsed().as_secs_f64() * 1000.0;

        let hits: Vec<Value> = results
            .iter()
            .map(|r| {
                json!({
                    "path": r.path,
                    "snippet": r.excerpt,
                    "score": r.score,
                    "tags": r.tags,
                })
            })
            .collect();

        Ok(json!({
            "query": query,
            "top_k": top_k,
            "count": hits.len(),
            "latency_ms": latency_ms,
            "results": hits,
        })
        .to_string())
    }
}

pub fn vault_recall_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "vault_recall".to_string(),
        description: "Hybrid semantic + keyword search across the vault with sub-5ms latency. \
             Returns ranked snippets with relevance scores and tags. Use this instead of the \
             generic 'vault_search' tool when you want the full result payload with latency metrics."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "query": { "type": "string", "description": "Natural-language query." },
                "top_k": {
                    "type": "integer",
                    "description": "Maximum results to return.",
                    "default": 5,
                    "minimum": 1,
                    "maximum": 20
                },
                "note_filter": {
                    "type": "array",
                    "description": "Optional tag filter.",
                    "items": { "type": "string" }
                }
            },
            "required": ["query"]
        }),
    }
}

// MARK: - contradiction_check

pub struct ContradictionCheckHandler {
    vault: Arc<dyn VaultBackend>,
}

crate::impl_tool_via_legacy_handler!(
    ContradictionCheckHandler,
    name = "knowledge.contradiction_check",
    input_schema = super::v2_catalog::knowledge_contradiction::input_schema,
    profile = super::Profile::AppStoreSafe,
    small_model_safe = true,
);

impl ContradictionCheckHandler {
    pub fn new(vault: Arc<dyn VaultBackend>) -> Self {
        Self { vault }
    }
}

#[async_trait]
impl ToolHandler for ContradictionCheckHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let claim = input
            .get("claim")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'claim'".into()))?;
        let context = input.get("context").and_then(Value::as_str).unwrap_or("");
        let scan_query = if context.is_empty() {
            claim.to_string()
        } else {
            format!("{claim}\n{context}")
        };

        // Pull in candidate existing facts via hybrid search.
        let candidates = self
            .vault
            .hybrid_search(&scan_query, 20, &[])
            .await
            .map_err(|e| ToolError::ExecutionFailed(format!("vault search failed: {e}")))?;

        let now = Utc::now();
        let facts: Vec<VaultFact> = candidates
            .iter()
            .map(|r| {
                VaultFact::new(
                    r.path.clone(),
                    "".to_string(),
                    r.excerpt.clone(),
                    r.score,
                    now,
                )
            })
            .collect();

        let contradictions = detect_contradictions(claim, &facts);
        let safe_to_write =
            contradictions.is_empty() || contradictions.iter().all(|c| c.confidence < 0.8);

        let serialised: Vec<Value> = contradictions
            .iter()
            .map(|c| {
                json!({
                    "type": format!("{:?}", c.conflict_type),
                    "confidence": c.confidence,
                    "existing_fact": c.existing_fact.content,
                    "source_path": c.existing_fact.file_path,
                    "section": c.existing_fact.section,
                })
            })
            .collect();

        Ok(json!({
            "claim": claim,
            "candidates_scanned": facts.len(),
            "contradictions": serialised,
            "safe_to_write": safe_to_write,
        })
        .to_string())
    }
}

pub fn contradiction_check_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "contradiction_check".to_string(),
        description: "Check whether a new fact contradicts existing vault knowledge before \
             writing it. Returns typed conflicts (Numeric, Boolean, Antonym, SemanticReversal) \
             with confidence scores, plus a 'safe_to_write' boolean (true when no conflicts \
             above 0.8 confidence)."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "claim": { "type": "string", "description": "The new fact to check." },
                "context": { "type": "string", "description": "Optional extra context used for candidate retrieval." }
            },
            "required": ["claim"]
        }),
    }
}

// MARK: - session_search

pub struct SessionSearchHandler {
    vault_root: PathBuf,
}

crate::impl_tool_via_legacy_handler!(
    SessionSearchHandler,
    name = "knowledge.session_search",
    input_schema = super::v2_catalog::knowledge_session_search::input_schema,
    profile = super::Profile::AppStoreSafe,
    small_model_safe = true,
);

impl SessionSearchHandler {
    pub fn new(vault_root: PathBuf) -> Self {
        Self { vault_root }
    }
}

#[async_trait]
impl ToolHandler for SessionSearchHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let query = input
            .get("query")
            .and_then(Value::as_str)
            .map(|s| s.to_lowercase());
        let provider_filter = input.get("provider").and_then(Value::as_str);
        let limit = input
            .get("limit")
            .and_then(Value::as_u64)
            .unwrap_or(20)
            .clamp(1, 200) as usize;

        let sessions = list_session_folders(&self.vault_root)
            .map_err(|e| ToolError::ExecutionFailed(format!("list sessions: {e}")))?;

        let mut matches: Vec<Value> = Vec::new();
        for session in sessions {
            if let Some(provider) = provider_filter {
                if session.provider != provider {
                    continue;
                }
            }
            // Text match: check session_id, model, provider, status
            if let Some(ref q) = query {
                let blob = format!(
                    "{} {} {} {}",
                    session.session_id.to_lowercase(),
                    session.model.to_lowercase(),
                    session.provider.to_lowercase(),
                    session.status.to_lowercase(),
                );
                if !blob.contains(q.as_str()) {
                    // Fall back to a transcript snippet scan for the top-level query.
                    let transcript_path = Path::new(&session.folder_path).join("transcript.jsonl");
                    let hit = std::fs::read_to_string(&transcript_path)
                        .map(|txt| txt.to_lowercase().contains(q.as_str()))
                        .unwrap_or(false);
                    if !hit {
                        continue;
                    }
                }
            }
            matches.push(json!({
                "session_id": session.session_id,
                "model": session.model,
                "provider": session.provider,
                "status": session.status,
                "turn_count": session.turn_count,
                "started_at_epoch": session.started_at_epoch,
                "folder_path": session.folder_path,
            }));
            if matches.len() >= limit {
                break;
            }
        }

        Ok(json!({
            "vault_root": self.vault_root.display().to_string(),
            "query": query,
            "count": matches.len(),
            "sessions": matches,
        })
        .to_string())
    }
}

pub fn session_search_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "session_search".to_string(),
        description: "Search past session transcripts recorded under <vault>/sessions/. \
             Matches session metadata (id, model, provider, status) and falls back to a \
             transcript text scan. Returns sorted list with the newest first."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "query": { "type": "string", "description": "Case-insensitive keyword." },
                "provider": { "type": "string", "description": "Optional provider filter (claude_sonnet, openai, ...)." },
                "limit": { "type": "integer", "default": 20, "minimum": 1, "maximum": 200 }
            }
        }),
    }
}

// MARK: - neural_recall

pub struct NeuralRecallHandler {
    vault: Arc<dyn VaultBackend>,
    cache: Arc<NeuralCache>,
}

crate::impl_tool_via_legacy_handler!(
    NeuralRecallHandler,
    name = "knowledge.neural_recall",
    input_schema = super::v2_catalog::knowledge_neural_recall::input_schema,
    profile = super::Profile::AppStoreSafe,
    small_model_safe = true,
);

impl NeuralRecallHandler {
    pub fn new(vault: Arc<dyn VaultBackend>, cache: Arc<NeuralCache>) -> Self {
        Self { vault, cache }
    }
}

#[async_trait]
impl ToolHandler for NeuralRecallHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let query = input
            .get("query")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'query'".into()))?;
        let limit = input
            .get("limit")
            .and_then(Value::as_u64)
            .unwrap_or(5)
            .clamp(1, 20) as usize;
        let temporal_minutes_ago = input.get("temporal_minutes_ago").and_then(Value::as_u64);

        // Temporal retrieval takes precedence when specified — this pulls the
        // hot-layer slice for a window around "minutes ago".
        if let Some(minutes) = temporal_minutes_ago {
            let window = input
                .get("temporal_window_minutes")
                .and_then(Value::as_u64)
                .unwrap_or(5);
            let results = self.cache.temporal_retrieve(minutes, window);
            let serialised: Vec<Value> = results
                .into_iter()
                .take(limit)
                .map(|r| {
                    json!({
                        "path": r.path,
                        "content": r.content,
                        "score": r.score,
                        "layer": format!("{:?}", r.layer).to_lowercase(),
                        "latency_us": r.latency_us,
                    })
                })
                .collect();
            return Ok(json!({
                "mode": "temporal",
                "minutes_ago": minutes,
                "window_minutes": window,
                "count": serialised.len(),
                "results": serialised,
            })
            .to_string());
        }

        let start = Instant::now();
        let results = self
            .cache
            .instant_retrieve(query, self.vault.as_ref(), limit)
            .await;
        let elapsed_us = start.elapsed().as_micros() as u64;

        let serialised: Vec<Value> = results
            .into_iter()
            .map(|r| {
                json!({
                    "path": r.path,
                    "content": r.content,
                    "score": r.score,
                    "layer": format!("{:?}", r.layer).to_lowercase(),
                    "latency_us": r.latency_us,
                })
            })
            .collect();

        let stats = self.cache.stats();
        Ok(json!({
            "mode": "tiered",
            "query": query,
            "count": serialised.len(),
            "total_latency_us": elapsed_us,
            "cache_stats": {
                "hot_entries": stats.hot_entries,
                "max_hot_entries": stats.max_hot_entries,
            },
            "results": serialised,
        })
        .to_string())
    }
}

pub fn neural_recall_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "neural_recall".to_string(),
        description: "Tiered cache lookup: Hot (L1, sub-1ms) -> Warm (L2, Tantivy+vec) -> Cold \
             (vault). Warms results up the cache as a side effect. Supply \
             'temporal_minutes_ago' (+ optional 'temporal_window_minutes', default 5) to \
             retrieve facts from a past time window instead of running a keyword query."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "query": { "type": "string", "description": "Text query for tiered retrieval." },
                "limit": { "type": "integer", "default": 5, "minimum": 1, "maximum": 20 },
                "temporal_minutes_ago": { "type": "integer", "description": "If set, run a temporal query starting this many minutes in the past." },
                "temporal_window_minutes": { "type": "integer", "description": "Window width for the temporal query (default 5)." }
            },
            "required": ["query"]
        }),
    }
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;
    use async_trait::async_trait;
    use std::sync::Mutex;
    use tempfile::tempdir;

    /// Minimal VaultBackend stub so we can test the knowledge tools without
    /// spinning up a full VaultStore.
    struct StubVault {
        results: Mutex<Vec<crate::storage::vault::SearchResult>>,
    }

    impl StubVault {
        fn new(results: Vec<crate::storage::vault::SearchResult>) -> Self {
            Self {
                results: Mutex::new(results),
            }
        }
    }

    #[async_trait]
    impl VaultBackend for StubVault {
        async fn hybrid_search(
            &self,
            _query: &str,
            _limit: usize,
            _tag_filter: &[String],
        ) -> Result<Vec<crate::storage::vault::SearchResult>, crate::storage::vault::VaultError>
        {
            Ok(self.results.lock().unwrap().clone())
        }
        async fn read(&self, _path: &str) -> Result<String, crate::storage::vault::VaultError> {
            Ok(String::new())
        }
        async fn write(
            &self,
            _path: &str,
            _content: &str,
            _tags: Option<&[String]>,
            _append: bool,
        ) -> Result<(), crate::storage::vault::VaultError> {
            Ok(())
        }
        async fn list(
            &self,
            _path_prefix: &str,
        ) -> Result<Vec<String>, crate::storage::vault::VaultError> {
            Ok(Vec::new())
        }
        async fn exists(&self, _path: &str) -> Result<bool, crate::storage::vault::VaultError> {
            Ok(false)
        }
        async fn delete(&self, _path: &str) -> Result<bool, crate::storage::vault::VaultError> {
            Ok(false)
        }
    }

    fn make_result(path: &str, excerpt: &str, score: f64) -> crate::storage::vault::SearchResult {
        crate::storage::vault::SearchResult {
            path: path.to_string(),
            excerpt: excerpt.to_string(),
            score,
            tags: Vec::new(),
        }
    }

    #[tokio::test]
    async fn vault_recall_returns_hits_and_latency() {
        let vault: Arc<dyn VaultBackend> = Arc::new(StubVault::new(vec![
            make_result("a.md", "alpha excerpt", 0.9),
            make_result("b.md", "beta excerpt", 0.7),
        ]));
        let handler = VaultRecallHandler::new(vault);
        let result = handler
            .execute(&json!({ "query": "alpha", "top_k": 5 }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["count"], json!(2));
        assert!(parsed["latency_ms"].as_f64().unwrap() >= 0.0);
        let results = parsed["results"].as_array().unwrap();
        assert_eq!(results[0]["path"], json!("a.md"));
    }

    #[tokio::test]
    async fn contradiction_check_flags_numeric_conflict() {
        let vault: Arc<dyn VaultBackend> = Arc::new(StubVault::new(vec![make_result(
            "arch.md",
            "The server runs on port 8080",
            0.95,
        )]));
        let handler = ContradictionCheckHandler::new(vault);
        let result = handler
            .execute(&json!({ "claim": "The server runs on port 9090" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert!(parsed["contradictions"].as_array().unwrap().len() >= 1);
    }

    #[tokio::test]
    async fn contradiction_check_returns_safe_for_empty_vault() {
        let vault: Arc<dyn VaultBackend> = Arc::new(StubVault::new(Vec::new()));
        let handler = ContradictionCheckHandler::new(vault);
        let result = handler
            .execute(&json!({ "claim": "new unrelated claim" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["safe_to_write"], json!(true));
        assert_eq!(parsed["contradictions"].as_array().unwrap().len(), 0);
    }

    #[tokio::test]
    async fn session_search_returns_empty_on_missing_directory() {
        let dir = tempdir().unwrap();
        let handler = SessionSearchHandler::new(dir.path().to_path_buf());
        let result = handler
            .execute(&json!({ "query": "anything" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["count"], json!(0));
    }

    #[tokio::test]
    async fn neural_recall_tiered_query_returns_results() {
        let vault: Arc<dyn VaultBackend> = Arc::new(StubVault::new(vec![make_result(
            "nc.md",
            "cache content",
            0.8,
        )]));
        let cache = Arc::new(NeuralCache::new(8));
        let handler = NeuralRecallHandler::new(vault, cache);
        let result = handler.execute(&json!({ "query": "cache" })).await.unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["mode"], json!("tiered"));
        assert!(parsed["count"].as_u64().unwrap() >= 1);
    }

    #[tokio::test]
    async fn neural_recall_temporal_mode_returns_empty_by_default() {
        let vault: Arc<dyn VaultBackend> = Arc::new(StubVault::new(Vec::new()));
        let cache = Arc::new(NeuralCache::new(8));
        let handler = NeuralRecallHandler::new(vault, cache);
        let result = handler
            .execute(&json!({
                "query": "history",
                "temporal_minutes_ago": 10,
                "temporal_window_minutes": 5
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["mode"], json!("temporal"));
        assert_eq!(parsed["count"], json!(0));
    }
}
