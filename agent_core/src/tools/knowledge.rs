//! Knowledge Tools — Phase 2 Vault-Native Capabilities
//!
//! Implements the knowledge-and-memory layer that differentiates Epistemos
//! from plugin-based PKM apps:
//!
//!   * `vault_recall`       — hybrid semantic+keyword search with latency
//!   * `contradiction_check`— surface epistemic conflicts before writing
//!   * `scoreevidence`      — deterministic source URL confidence scoring
//!   * `session_search`     — browse past sessions recorded in the vault
//!   * `neural_recall`      — tiered hot/warm/cold cache lookup
//!
//! All five are pure Rust wrappers around services already implemented in
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

const MAX_QUERY_CHARS: usize = 4_000;
const MAX_CONTEXT_CHARS: usize = 16_000;
const MAX_NOTE_FILTER_TAGS: usize = 32;
const MAX_TAG_CHARS: usize = 128;
const MAX_PROVIDER_CHARS: usize = 128;
const MAX_TEMPORAL_MINUTES: u64 = 525_600;
const MAX_TEMPORAL_WINDOW_MINUTES: u64 = 1_440;

fn ensure_char_cap(label: &str, value: &str, cap: usize) -> Result<(), ToolError> {
    let count = value.chars().count();
    if count > cap {
        return Err(ToolError::InvalidArguments(format!(
            "{label} exceeds {cap} characters"
        )));
    }
    Ok(())
}

fn optional_string<'a>(input: &'a Value, key: &str) -> Result<Option<&'a str>, ToolError> {
    match input.get(key) {
        None | Some(Value::Null) => Ok(None),
        Some(Value::String(value)) => Ok(Some(value.as_str())),
        Some(_) => Err(ToolError::InvalidArguments(format!(
            "'{key}' must be a string"
        ))),
    }
}

fn optional_u64_range(
    input: &Value,
    key: &str,
    default: u64,
    min: u64,
    max: u64,
) -> Result<u64, ToolError> {
    let value = match input.get(key) {
        None | Some(Value::Null) => default,
        Some(value) => value
            .as_u64()
            .ok_or_else(|| ToolError::InvalidArguments(format!("'{key}' must be an integer")))?,
    };
    if !(min..=max).contains(&value) {
        return Err(ToolError::InvalidArguments(format!(
            "{key} must be between {min} and {max}"
        )));
    }
    Ok(value)
}

fn optional_u64(input: &Value, key: &str) -> Result<Option<u64>, ToolError> {
    match input.get(key) {
        None | Some(Value::Null) => Ok(None),
        Some(value) => value
            .as_u64()
            .ok_or_else(|| ToolError::InvalidArguments(format!("'{key}' must be an integer")))
            .map(Some),
    }
}

fn parse_note_filter(input: &Value) -> Result<Vec<String>, ToolError> {
    let Some(value) = input.get("note_filter") else {
        return Ok(Vec::new());
    };
    let Value::Array(items) = value else {
        return Err(ToolError::InvalidArguments(
            "'note_filter' must be an array of strings".into(),
        ));
    };
    if items.len() > MAX_NOTE_FILTER_TAGS {
        return Err(ToolError::InvalidArguments(format!(
            "note_filter supports at most {MAX_NOTE_FILTER_TAGS} tags"
        )));
    }
    let mut tags = Vec::with_capacity(items.len());
    for (idx, item) in items.iter().enumerate() {
        let tag = item.as_str().ok_or_else(|| {
            ToolError::InvalidArguments(format!("'note_filter[{idx}]' must be a string"))
        })?;
        ensure_char_cap(&format!("note_filter[{idx}]"), tag, MAX_TAG_CHARS)?;
        tags.push(tag.to_string());
    }
    Ok(tags)
}

// MARK: - vault_recall

pub struct VaultRecallHandler {
    vault: Arc<dyn VaultBackend>,
}

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
        ensure_char_cap("query", query, MAX_QUERY_CHARS)?;
        let top_k = optional_u64_range(input, "top_k", 5, 1, 20)? as usize;
        let tag_filter = parse_note_filter(input)?;

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
        description: "Hybrid semantic + keyword search across the vault with measured latency. \
             Returns ranked snippets with relevance scores and tags. Use this instead of the \
             generic 'vault.search' tool when you want the full result payload with latency metrics."
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
        ensure_char_cap("claim", claim, MAX_QUERY_CHARS)?;
        let context = optional_string(input, "context")?.unwrap_or("");
        ensure_char_cap("context", context, MAX_CONTEXT_CHARS)?;
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

// MARK: - scoreevidence

pub struct EvidenceScoreHandler;

#[async_trait]
impl ToolHandler for EvidenceScoreHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let url = input
            .get("url")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'url'".into()))?;
        ensure_char_cap("url", url, MAX_QUERY_CHARS)?;
        let source_type = match optional_string(input, "sourceType")? {
            Some(value) => Some(value),
            None => optional_string(input, "source_type")?,
        };
        if let Some(source_type) = source_type {
            ensure_char_cap("sourceType", source_type, MAX_TAG_CHARS)?;
        }

        let (tier, confidence) = evidence_score(url, source_type);

        Ok(json!({
            "url": url,
            "sourceType": source_type,
            "tier": tier,
            "confidence": confidence,
        })
        .to_string())
    }
}

pub fn evidence_score_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "scoreevidence".to_string(),
        description: "Deterministically score a research source URL into an evidence tier and confidence. No network or LLM call.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "url": { "type": "string", "description": "Source URL to score." },
                "sourceType": {
                    "type": "string",
                    "description": "Optional override: arxiv, peer_reviewed, news, blog, or primary."
                },
                "source_type": {
                    "type": "string",
                    "description": "Alias for sourceType."
                }
            },
            "required": ["url"]
        }),
    }
}

fn evidence_score(url: &str, source_type: Option<&str>) -> (&'static str, f64) {
    if let Some(source_type) = source_type.map(str::to_lowercase) {
        match source_type.as_str() {
            "arxiv" => return ("arxivPreprint", 0.70),
            "peer_reviewed" => return ("peerReviewed", 0.85),
            "news" => return ("news", 0.50),
            "blog" => return ("blog", 0.30),
            "primary" => return ("primaryData", 0.95),
            _ => {}
        }
    }

    let lowered = url.to_lowercase();
    if lowered.contains("doi.org")
        || lowered.contains("pubmed")
        || lowered.contains("nature.com")
        || lowered.contains("science.org")
        || lowered.contains("springer.com")
        || lowered.contains("wiley.com")
        || lowered.contains("cell.com")
        || lowered.contains("thelancet.com")
        || lowered.contains("pnas.org")
        || lowered.contains("pmc.ncbi")
        || (lowered.contains(".edu") && lowered.contains("/publications"))
    {
        return ("peerReviewed", 0.85);
    }
    if lowered.contains(".gov") || lowered.contains("who.int") {
        return ("primaryData", 0.95);
    }
    if lowered.contains("arxiv.org")
        || lowered.contains("biorxiv.org")
        || lowered.contains("medrxiv.org")
        || lowered.contains("ssrn.com")
        || lowered.contains("openreview.net")
    {
        return ("arxivPreprint", 0.70);
    }
    if lowered.contains("nytimes.com")
        || lowered.contains("reuters.com")
        || lowered.contains("bbc.com")
        || lowered.contains("bbc.co.uk")
        || lowered.contains("apnews.com")
        || lowered.contains("washingtonpost.com")
        || lowered.contains("economist.com")
        || lowered.contains("theguardian.com")
    {
        return ("news", 0.50);
    }
    if lowered.contains("medium.com")
        || lowered.contains("substack.com")
        || lowered.contains("wordpress.com")
        || lowered.contains("blogspot.com")
        || lowered.contains("dev.to")
        || lowered.contains("hashnode.")
    {
        return ("blog", 0.30);
    }

    ("unknown", 0.20)
}

// MARK: - session_search

pub struct SessionSearchHandler {
    vault_root: PathBuf,
}

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
            .map(|value| {
                value
                    .as_str()
                    .ok_or_else(|| ToolError::InvalidArguments("'query' must be a string".into()))
            })
            .transpose()?;
        if let Some(query) = query {
            ensure_char_cap("query", query, MAX_QUERY_CHARS)?;
        }
        let query = query.map(|s| s.to_lowercase());
        let provider_filter = optional_string(input, "provider")?;
        if let Some(provider) = provider_filter {
            ensure_char_cap("provider", provider, MAX_PROVIDER_CHARS)?;
        }
        let limit = optional_u64_range(input, "limit", 20, 1, 200)? as usize;

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
        ensure_char_cap("query", query, MAX_QUERY_CHARS)?;
        let limit = optional_u64_range(input, "limit", 5, 1, 20)? as usize;
        let temporal_minutes_ago = optional_u64(input, "temporal_minutes_ago")?;
        if let Some(minutes) = temporal_minutes_ago {
            if minutes > MAX_TEMPORAL_MINUTES {
                return Err(ToolError::InvalidArguments(format!(
                    "temporal_minutes_ago must be at most {MAX_TEMPORAL_MINUTES}"
                )));
            }
        }

        // Temporal retrieval takes precedence when specified — this pulls the
        // hot-layer slice for a window around "minutes ago".
        if let Some(minutes) = temporal_minutes_ago {
            let window = optional_u64_range(
                input,
                "temporal_window_minutes",
                5,
                1,
                MAX_TEMPORAL_WINDOW_MINUTES,
            )?;
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
    async fn vault_recall_rejects_non_string_note_filter_entry() {
        let vault: Arc<dyn VaultBackend> = Arc::new(StubVault::new(Vec::new()));
        let handler = VaultRecallHandler::new(vault);
        let err = handler
            .execute(&json!({
                "query": "alpha",
                "note_filter": ["research", 7]
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("note_filter[1]"));
    }

    #[tokio::test]
    async fn vault_recall_rejects_invalid_top_k() {
        let vault: Arc<dyn VaultBackend> = Arc::new(StubVault::new(Vec::new()));
        let handler = VaultRecallHandler::new(vault);
        let err = handler
            .execute(&json!({
                "query": "alpha",
                "top_k": 0
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("top_k"));
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
        assert!(!parsed["contradictions"].as_array().unwrap().is_empty());
    }

    #[tokio::test]
    async fn contradiction_check_rejects_non_string_context() {
        let vault: Arc<dyn VaultBackend> = Arc::new(StubVault::new(Vec::new()));
        let handler = ContradictionCheckHandler::new(vault);
        let err = handler
            .execute(&json!({
                "claim": "new fact",
                "context": ["not", "a", "string"]
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("context"));
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
    async fn evidence_score_matches_swift_research_tiers() {
        let handler = EvidenceScoreHandler;

        let result = handler
            .execute(&json!({ "url": "https://pubmed.ncbi.nlm.nih.gov/12345" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["tier"], json!("peerReviewed"));
        assert_eq!(parsed["confidence"], json!(0.85));

        let result = handler
            .execute(&json!({
                "url": "https://example.com/post",
                "sourceType": "primary"
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["tier"], json!("primaryData"));
        assert_eq!(parsed["confidence"], json!(0.95));
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
    async fn session_search_rejects_non_integer_limit() {
        let dir = tempdir().unwrap();
        let handler = SessionSearchHandler::new(dir.path().to_path_buf());
        let err = handler
            .execute(&json!({ "limit": "many" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("limit"));
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

    #[tokio::test]
    async fn neural_recall_rejects_invalid_temporal_window() {
        let vault: Arc<dyn VaultBackend> = Arc::new(StubVault::new(Vec::new()));
        let cache = Arc::new(NeuralCache::new(8));
        let handler = NeuralRecallHandler::new(vault, cache);
        let err = handler
            .execute(&json!({
                "query": "history",
                "temporal_minutes_ago": 10,
                "temporal_window_minutes": 0
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("temporal_window_minutes"));
    }
}
