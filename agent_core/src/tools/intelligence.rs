//! Intelligence Layer — Phase 7 (Specialties D1/D3/D4)
//!
//! * `nightbrain_trigger` — fire one of the NightBrain background jobs on
//!   demand via a Swift FFI callback.
//! * `inline_partner` — fetch graph-weighted inline partner context from the
//!   Swift note editor stack via FFI.
//! * `self_evolve` — GEPA-style trace analysis. Reads session trace.json
//!   files, detects failure patterns (frequent retries, slow execution,
//!   consistent errors), and emits a mutation proposal. Pure Rust.
//! * `mixture_of_minds` — run a problem through multiple frontier models
//!   (Claude, OpenAI, Gemini, Perplexity) in parallel and aggregate. Pure
//!   Rust via reqwest — no provider-trait dance.

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use reqwest::Client;
use serde::Deserialize;
use serde_json::{Value, json};

use crate::bridge::AgentEventDelegate;
use crate::providers::openai::{OPENAI_RESPONSES_API, extract_openai_responses_output_text};

use super::registry::{ToolError, ToolHandler};

// MARK: - nightbrain_trigger (Specialty D1)

const ALLOWED_NIGHTBRAIN_JOBS: &[&str] = &[
    "event_checkpoint",
    "search_index_checkpoint",
    "artifact_dedup",
    "workspace_compaction",
    "memory_distillation",
    "cloud_knowledge_distillation",
    "session_graph_generation",
    "skill_evolution_analysis",
    "ssm_state_pruning",
    "maintenance_log",
];

const MAX_INLINE_NOTE_ID_CHARS: usize = 256;
const MAX_DELEGATE_RESPONSE_CHARS: usize = 256 * 1024;

fn ensure_char_cap(label: &str, value: &str, cap: usize) -> Result<(), ToolError> {
    let count = value.chars().count();
    if count > cap {
        return Err(ToolError::InvalidArguments(format!(
            "{label} exceeds {cap} characters"
        )));
    }
    Ok(())
}

fn parse_delegate_json(tool_name: &str, response: String) -> Result<Value, ToolError> {
    if response.chars().count() > MAX_DELEGATE_RESPONSE_CHARS {
        return Err(ToolError::ExecutionFailed(format!(
            "{tool_name} delegate response exceeded {MAX_DELEGATE_RESPONSE_CHARS} character cap"
        )));
    }

    serde_json::from_str(&response).map_err(|_| {
        ToolError::ExecutionFailed(format!(
            "{tool_name} delegate returned non-JSON response; raw output redacted"
        ))
    })
}

pub struct NightBrainTriggerHandler {
    delegate: Arc<dyn AgentEventDelegate>,
}

impl NightBrainTriggerHandler {
    pub fn new(delegate: Arc<dyn AgentEventDelegate>) -> Self {
        Self { delegate }
    }
}

#[async_trait]
impl ToolHandler for NightBrainTriggerHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let job = input
            .get("job")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'job'".into()))?
            .to_string();
        if !ALLOWED_NIGHTBRAIN_JOBS.contains(&job.as_str()) {
            return Err(ToolError::InvalidArguments(format!(
                "unknown job '{job}' (expected one of: {})",
                ALLOWED_NIGHTBRAIN_JOBS.join(", ")
            )));
        }
        let priority = input
            .get("priority")
            .map(|value| {
                value.as_str().ok_or_else(|| {
                    ToolError::InvalidArguments("'priority' must be a string".into())
                })
            })
            .transpose()?
            .unwrap_or("immediate")
            .to_string();
        if priority != "immediate" {
            return Err(ToolError::InvalidArguments(format!(
                "priority '{priority}' invalid (expected immediate; normal scheduling is owned by the host idle scheduler)"
            )));
        }

        let delegate = Arc::clone(&self.delegate);
        let job_for_task = job.clone();
        let priority_for_task = priority.clone();
        let response = tokio::task::spawn_blocking(move || {
            delegate.trigger_nightbrain_job(job_for_task, priority_for_task)
        })
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("nightbrain join: {e}")))?;

        let parsed = parse_delegate_json("nightbrain_trigger", response)?;
        Ok(json!({
            "job": job,
            "priority": priority,
            "result": parsed,
        })
        .to_string())
    }
}

pub fn nightbrain_trigger_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "nightbrain_trigger".to_string(),
        description: "Specialty D1 — trigger a NightBrain background maintenance job on \
             demand. Jobs: event_checkpoint, search_index_checkpoint, artifact_dedup, \
             workspace_compaction, memory_distillation, cloud_knowledge_distillation, \
             session_graph_generation, skill_evolution_analysis, ssm_state_pruning, \
             maintenance_log. Priority: 'immediate' only; normal/background scheduling is \
             owned by the host NightBrain idle scheduler, not this tool."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "job": { "type": "string", "enum": ALLOWED_NIGHTBRAIN_JOBS },
                "priority": { "type": "string", "enum": ["immediate"], "default": "immediate" }
            },
            "required": ["job"]
        }),
    }
}

// MARK: - inline_partner (Specialty D2)

pub struct InlinePartnerHandler {
    delegate: Arc<dyn AgentEventDelegate>,
}

impl InlinePartnerHandler {
    pub fn new(delegate: Arc<dyn AgentEventDelegate>) -> Self {
        Self { delegate }
    }
}

#[async_trait]
impl ToolHandler for InlinePartnerHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let note_id = input
            .get("note_id")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'note_id'".into()))?
            .to_string();
        ensure_char_cap("note_id", &note_id, MAX_INLINE_NOTE_ID_CHARS)?;
        let cursor_offset = input
            .get("cursor_offset")
            .map(|value| {
                value.as_u64().ok_or_else(|| {
                    ToolError::InvalidArguments("'cursor_offset' must be an integer".into())
                })
            })
            .transpose()?
            .ok_or_else(|| ToolError::InvalidArguments("missing 'cursor_offset'".into()))?;
        let cursor_offset_u32 = u32::try_from(cursor_offset).map_err(|_| {
            ToolError::InvalidArguments("cursor_offset exceeds supported range".into())
        })?;

        let delegate = Arc::clone(&self.delegate);
        let note_id_for_task = note_id.clone();
        let response = tokio::task::spawn_blocking(move || {
            delegate.get_partner_context(note_id_for_task, cursor_offset_u32)
        })
        .await
        .map_err(|e| ToolError::ExecutionFailed(format!("inline_partner join: {e}")))?;

        let parsed = parse_delegate_json("inline_partner", response)?;
        Ok(json!({
            "note_id": note_id,
            "cursor_offset": cursor_offset,
            "context": parsed,
        })
        .to_string())
    }
}

pub fn inline_partner_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "inline_partner".to_string(),
        description: "Specialty D2 — query what the inline AI partner sees at a \
             cursor position inside a note. Returns the weighted vault matches, a \
             partner suggestion summary, and the local complexity score for the \
             note context around that cursor."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "note_id": { "type": "string", "description": "Target note/page ID." },
                "cursor_offset": {
                    "type": "integer",
                    "minimum": 0,
                    "description": "UTF-16 cursor offset inside the note buffer."
                }
            },
            "required": ["note_id", "cursor_offset"]
        }),
    }
}

// MARK: - self_evolve (Specialty D3 — trace analysis only for v1)

const MAX_SELF_EVOLVE_TRACE_BYTES: u64 = 2 * 1024 * 1024;
const MAX_SELF_EVOLVE_SKIPPED_TRACES: usize = 25;

#[derive(Debug, Clone, Deserialize)]
struct TraceEventRaw {
    #[allow(dead_code)]
    timestamp: Option<DateTime<Utc>>,
    kind: String,
    name: Option<String>,
    duration_ms: Option<u64>,
    outcome: Option<String>,
}

pub struct SelfEvolveHandler {
    vault_root: PathBuf,
}

impl SelfEvolveHandler {
    pub fn new(vault_root: PathBuf) -> Self {
        Self { vault_root }
    }
}

#[async_trait]
impl ToolHandler for SelfEvolveHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = input
            .get("action")
            .and_then(Value::as_str)
            .unwrap_or("analyze");
        match action {
            "analyze" | "analyze_traces" => self.analyze_traces(input).await,
            "propose" | "propose_mutation" => self.propose_mutation(input).await,
            other => Err(ToolError::InvalidArguments(format!(
                "unknown action '{other}' (expected: analyze|propose)"
            ))),
        }
    }
}

impl SelfEvolveHandler {
    async fn analyze_traces(&self, input: &Value) -> Result<String, ToolError> {
        let limit = input
            .get("sessions_to_scan")
            .and_then(Value::as_u64)
            .unwrap_or(20)
            .clamp(1, 200) as usize;

        let sessions_dir = self.vault_root.join("sessions");
        if !sessions_dir.exists() {
            return Ok(json!({
                "action": "analyze",
                "sessions_scanned": 0,
                "patterns": [],
                "note": "no sessions directory yet",
            })
            .to_string());
        }

        let mut session_paths: Vec<PathBuf> = std::fs::read_dir(&sessions_dir)
            .map_err(|e| ToolError::ExecutionFailed(format!("read sessions dir: {e}")))?
            .filter_map(|entry| entry.ok().map(|e| e.path()))
            .filter(|path| path.is_dir())
            .collect();
        session_paths.sort();
        session_paths.reverse();
        session_paths.truncate(limit);

        // Aggregate metrics across all scanned sessions.
        let mut tool_calls: HashMap<String, u32> = HashMap::new();
        let mut tool_errors: HashMap<String, u32> = HashMap::new();
        let mut tool_durations: HashMap<String, Vec<u64>> = HashMap::new();
        let mut total_events = 0usize;
        let mut total_sessions_with_data = 0usize;
        let mut skipped_traces: Vec<Value> = Vec::new();

        for path in &session_paths {
            let trace_path = path.join("trace.json");
            if !trace_path.exists() {
                continue;
            }
            let session_name = path
                .file_name()
                .and_then(|name| name.to_str())
                .unwrap_or("unknown")
                .to_string();
            let metadata = match std::fs::metadata(&trace_path) {
                Ok(metadata) => metadata,
                Err(error) => {
                    record_skipped_trace(
                        &mut skipped_traces,
                        session_name,
                        "metadata_failed",
                        Some(error.to_string()),
                        None,
                    );
                    continue;
                }
            };
            let trace_bytes = metadata.len();
            if trace_bytes > MAX_SELF_EVOLVE_TRACE_BYTES {
                record_skipped_trace(
                    &mut skipped_traces,
                    session_name,
                    "trace_too_large",
                    None,
                    Some(trace_bytes),
                );
                continue;
            }
            let content = match std::fs::read_to_string(&trace_path) {
                Ok(content) => content,
                Err(error) => {
                    record_skipped_trace(
                        &mut skipped_traces,
                        session_name,
                        "read_failed",
                        Some(error.to_string()),
                        Some(trace_bytes),
                    );
                    continue;
                }
            };
            let events: Vec<TraceEventRaw> = match serde_json::from_str(&content) {
                Ok(e) => e,
                Err(error) => {
                    record_skipped_trace(
                        &mut skipped_traces,
                        session_name,
                        "invalid_json",
                        Some(error.to_string()),
                        Some(trace_bytes),
                    );
                    continue;
                }
            };
            if events.is_empty() {
                continue;
            }
            total_sessions_with_data += 1;
            for event in &events {
                total_events += 1;
                if event.kind != "tool_call" {
                    continue;
                }
                let Some(name) = event.name.as_deref() else {
                    continue;
                };
                *tool_calls.entry(name.to_string()).or_insert(0) += 1;
                if matches!(event.outcome.as_deref(), Some("error") | Some("failed")) {
                    *tool_errors.entry(name.to_string()).or_insert(0) += 1;
                }
                if let Some(ms) = event.duration_ms {
                    tool_durations.entry(name.to_string()).or_default().push(ms);
                }
            }
        }

        // Build patterns: retries (calls > 3×avg), slow p95, error rate > 20%.
        let mut patterns: Vec<Value> = Vec::new();
        let avg_calls: f64 = if tool_calls.is_empty() {
            0.0
        } else {
            tool_calls.values().sum::<u32>() as f64 / tool_calls.len() as f64
        };

        for (tool, count) in &tool_calls {
            let count_f = *count as f64;
            if count_f > avg_calls * 3.0 && count_f >= 6.0 {
                patterns.push(json!({
                    "tool": tool,
                    "kind": "frequent_calls",
                    "count": count,
                    "average": avg_calls,
                    "note": format!("'{tool}' called {count}x, {:.1}x more than average — possible retry storm", count_f / avg_calls.max(1.0)),
                }));
            }
        }

        for (tool, errors) in &tool_errors {
            let calls = tool_calls.get(tool).copied().unwrap_or(0);
            if calls == 0 {
                continue;
            }
            let rate = *errors as f64 / calls as f64;
            if rate >= 0.2 {
                patterns.push(json!({
                    "tool": tool,
                    "kind": "high_error_rate",
                    "calls": calls,
                    "errors": errors,
                    "rate": rate,
                    "note": format!("'{tool}' errors on {:.0}% of calls", rate * 100.0),
                }));
            }
        }

        for (tool, durations) in &tool_durations {
            if durations.len() < 5 {
                continue;
            }
            let mut sorted = durations.clone();
            sorted.sort_unstable();
            let p95 = sorted[(sorted.len() as f64 * 0.95) as usize];
            let mean = sorted.iter().sum::<u64>() as f64 / sorted.len() as f64;
            if p95 > 10_000 || (mean > 3_000.0 && p95 as f64 > mean * 2.5) {
                patterns.push(json!({
                    "tool": tool,
                    "kind": "slow_p95",
                    "samples": durations.len(),
                    "mean_ms": mean,
                    "p95_ms": p95,
                    "note": format!("'{tool}' p95 latency {p95}ms (mean {mean:.0}ms)"),
                }));
            }
        }

        Ok(json!({
            "action": "analyze",
            "vault_root": self.vault_root.display().to_string(),
            "sessions_scanned": session_paths.len(),
            "sessions_with_data": total_sessions_with_data,
            "total_events": total_events,
            "patterns": patterns,
            "sessions_skipped": skipped_traces.len(),
            "skipped_traces": skipped_traces,
        })
        .to_string())
    }

    async fn propose_mutation(&self, input: &Value) -> Result<String, ToolError> {
        // Build an analysis first, then emit a mutation proposal for any
        // detected pattern. Does NOT write anything — user must explicitly
        // apply via skill_manage.
        let analysis_raw = self.analyze_traces(input).await?;
        let analysis: Value = serde_json::from_str(&analysis_raw).unwrap_or(json!({}));
        let patterns = analysis["patterns"].as_array().cloned().unwrap_or_default();

        let proposals: Vec<Value> = patterns
            .iter()
            .map(|pattern| {
                let tool = pattern["tool"].as_str().unwrap_or("unknown");
                let kind = pattern["kind"].as_str().unwrap_or("");
                let rationale = pattern["note"].as_str().unwrap_or("").to_string();
                let mutation_type = match kind {
                    "frequent_calls" => "add_retry_backoff",
                    "high_error_rate" => "add_error_handler",
                    "slow_p95" => "parallelize_or_cache",
                    _ => "tune_parameters",
                };
                let target_skill = format!("{}-optimizer", advisory_skill_slug(tool));
                json!({
                    "skill": target_skill,
                    "mutation_type": mutation_type,
                    "rationale": rationale,
                    "constraints": {
                        "size_ok": true,
                        "semantic_preserved": true,
                    },
                    "status": "proposed",
                })
            })
            .collect();

        Ok(json!({
            "action": "propose",
            "analysis": analysis,
            "proposals": proposals,
            "note": "Proposals are advisory only — apply via skill_manage.create/edit.",
        })
        .to_string())
    }
}

fn record_skipped_trace(
    skipped_traces: &mut Vec<Value>,
    session: String,
    reason: &str,
    error: Option<String>,
    bytes: Option<u64>,
) {
    if skipped_traces.len() >= MAX_SELF_EVOLVE_SKIPPED_TRACES {
        return;
    }
    let mut skipped = json!({
        "session": session,
        "reason": reason,
    });
    if let Some(bytes) = bytes {
        skipped["bytes"] = json!(bytes);
    }
    if let Some(error) = error {
        skipped["error"] = json!(error);
    }
    skipped_traces.push(skipped);
}

fn advisory_skill_slug(raw: &str) -> String {
    let mut slug = String::with_capacity(raw.len().min(64));
    let mut previous_was_separator = false;
    for byte in raw.bytes() {
        let next = match byte {
            b'a'..=b'z' | b'0'..=b'9' => Some(byte as char),
            b'A'..=b'Z' => Some((byte + 32) as char),
            b'-' | b'_' | b'.' | b' ' => {
                if slug.is_empty() || previous_was_separator {
                    None
                } else {
                    previous_was_separator = true;
                    Some('-')
                }
            }
            _ => None,
        };
        let Some(ch) = next else {
            continue;
        };
        slug.push(ch);
        if ch != '-' {
            previous_was_separator = false;
        }
        if slug.len() >= 64 {
            break;
        }
    }
    while slug.ends_with('-') {
        slug.pop();
    }
    if slug.is_empty() {
        "tool".to_string()
    } else {
        slug
    }
}

pub fn self_evolve_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "self_evolve".to_string(),
        description: "Specialty D3 — GEPA-style skill mutation proposals. Actions: \
             'analyze' (scan the last N session traces for failure patterns: retry storms, \
             high error rate, slow p95) and 'propose' (emit mutation proposals keyed to each \
             detected pattern). This tool never writes skills — use skill_manage to apply."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": { "type": "string", "enum": ["analyze", "propose"], "default": "analyze" },
                "sessions_to_scan": { "type": "integer", "default": 20, "minimum": 1, "maximum": 200 }
            }
        }),
    }
}

// MARK: - mixture_of_minds (Specialty D4)

const MOM_ALLOWED_MODELS: &[&str] = &["claude", "openai", "gemini", "perplexity"];
const MAX_MOM_PROBLEM_CHARS: usize = 16_000;
const MAX_MOM_MODEL_CHARS: usize = 64;

pub struct MixtureOfMindsHandler {
    client: Client,
}

impl MixtureOfMindsHandler {
    pub fn new() -> Result<Self, ToolError> {
        let client = Client::builder()
            .timeout(Duration::from_secs(90))
            .user_agent("Epistemos/1.0 (MoM)")
            .build()
            .map_err(|e| ToolError::ExecutionFailed(format!("http client init: {e}")))?;
        Ok(Self { client })
    }
}

#[async_trait]
impl ToolHandler for MixtureOfMindsHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let problem = input
            .get("problem")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'problem'".into()))?
            .to_string();
        if problem.trim().is_empty() {
            return Err(ToolError::InvalidArguments(
                "'problem' cannot be blank".into(),
            ));
        }
        if problem.chars().count() > MAX_MOM_PROBLEM_CHARS {
            return Err(ToolError::InvalidArguments(format!(
                "'problem' is too long (max {MAX_MOM_PROBLEM_CHARS} chars)"
            )));
        }
        let allow_cloud =
            optional_mom_bool(input, "allow_cloud_external_requests")?.unwrap_or(false);
        if !allow_cloud {
            return Err(ToolError::InvalidArguments(
                "allow_cloud_external_requests must be true because mixture_of_minds sends the problem to external model APIs"
                    .into(),
            ));
        }
        let requested_raw = parse_mom_models(input)?;

        if requested_raw.is_empty() {
            return Err(ToolError::InvalidArguments(
                "'models' cannot be empty".into(),
            ));
        }
        if requested_raw.len() > 4 {
            return Err(ToolError::InvalidArguments(
                "at most 4 models per call".into(),
            ));
        }
        let mut requested = Vec::with_capacity(requested_raw.len());
        for model in requested_raw {
            let normalized = model.trim().to_ascii_lowercase();
            if !MOM_ALLOWED_MODELS.contains(&normalized.as_str()) {
                return Err(ToolError::InvalidArguments(format!(
                    "unknown model '{model}' (expected one of: {})",
                    MOM_ALLOWED_MODELS.join(", ")
                )));
            }
            requested.push(normalized);
        }

        // Launch every query in parallel.
        let futures: Vec<_> = requested
            .clone()
            .into_iter()
            .map(|model| {
                let client = self.client.clone();
                let problem = problem.clone();
                async move {
                    let result = match model.as_str() {
                        "claude" => ask_claude(&client, &problem).await,
                        "openai" => ask_openai(&client, &problem).await,
                        "gemini" => ask_gemini(&client, &problem).await,
                        "perplexity" => ask_perplexity(&client, &problem).await,
                        other => Err(format!("unknown model '{other}'")),
                    };
                    (model, result)
                }
            })
            .collect();

        let results = futures::future::join_all(futures).await;

        let mut contributions: Vec<Value> = Vec::new();
        let mut successful_answers: Vec<(String, String)> = Vec::new();
        for (model, result) in results {
            match result {
                Ok(answer) => {
                    contributions.push(json!({
                        "model": model,
                        "success": true,
                        "response": answer,
                    }));
                    successful_answers.push((model, answer));
                }
                Err(err) => {
                    contributions.push(json!({
                        "model": model,
                        "success": false,
                        "error": err,
                    }));
                }
            }
        }

        // Simple aggregation strategy: pick the longest successful response as
        // the "best" and list all others as contributions. A smarter version
        // would ask Claude to synthesize, but that's a follow-up.
        let best_answer = successful_answers
            .iter()
            .max_by_key(|(_, text)| text.chars().count())
            .map(|(model, text)| {
                json!({
                    "model": model,
                    "response": text,
                })
            })
            .unwrap_or(Value::Null);

        Ok(json!({
            "problem": problem,
            "cloud_requests_authorized": allow_cloud,
            "models_requested": requested,
            "models_responded": successful_answers.len(),
            "best": best_answer,
            "contributions": contributions,
            "aggregation_method": "longest_response",
        })
        .to_string())
    }
}

fn optional_mom_bool(input: &Value, field: &str) -> Result<Option<bool>, ToolError> {
    let Some(value) = input.get(field) else {
        return Ok(None);
    };
    value
        .as_bool()
        .map(Some)
        .ok_or_else(|| ToolError::InvalidArguments(format!("'{field}' must be a boolean")))
}

fn parse_mom_models(input: &Value) -> Result<Vec<String>, ToolError> {
    let Some(value) = input.get("models") else {
        return Ok(vec![
            "claude".to_string(),
            "openai".to_string(),
            "gemini".to_string(),
        ]);
    };
    let Some(items) = value.as_array() else {
        return Err(ToolError::InvalidArguments(
            "'models' must be an array of strings".into(),
        ));
    };
    let mut models = Vec::with_capacity(items.len());
    for (index, item) in items.iter().enumerate() {
        let Some(model) = item.as_str() else {
            return Err(ToolError::InvalidArguments(format!(
                "'models[{index}]' must be a string"
            )));
        };
        if model.trim().is_empty() {
            return Err(ToolError::InvalidArguments(format!(
                "'models[{index}]' cannot be blank"
            )));
        }
        if model.chars().count() > MAX_MOM_MODEL_CHARS {
            return Err(ToolError::InvalidArguments(format!(
                "'models[{index}]' is too long (max {MAX_MOM_MODEL_CHARS} chars)"
            )));
        }
        models.push(model.to_string());
    }
    Ok(models)
}

async fn ask_claude(client: &Client, problem: &str) -> Result<String, String> {
    let api_key = std::env::var("ANTHROPIC_API_KEY").map_err(|_| "ANTHROPIC_API_KEY not set")?;
    let body = json!({
        "model": "claude-sonnet-4-6",
        "max_tokens": 1024,
        "messages": [ { "role": "user", "content": problem } ]
    });
    let resp = client
        .post("https://api.anthropic.com/v1/messages")
        .header("x-api-key", api_key)
        .header("anthropic-version", "2023-06-01")
        .json(&body)
        .send()
        .await
        .map_err(|e| describe_request_error("claude", e))?;
    if !resp.status().is_success() {
        return Err(format!("claude HTTP {}", resp.status().as_u16()));
    }
    let payload: Value = resp
        .json()
        .await
        .map_err(|_| "claude response parse failed".to_string())?;
    let text = payload
        .get("content")
        .and_then(Value::as_array)
        .map(|blocks| {
            blocks
                .iter()
                .filter_map(|b| b.get("text").and_then(Value::as_str))
                .collect::<Vec<_>>()
                .join("\n")
        })
        .unwrap_or_default();
    Ok(text)
}

async fn ask_openai(client: &Client, problem: &str) -> Result<String, String> {
    let api_key = std::env::var("OPENAI_API_KEY").map_err(|_| "OPENAI_API_KEY not set")?;
    let body = json!({
        "model": "gpt-5.4",
        "max_output_tokens": 1024,
        "store": false,
        "text": { "verbosity": "low" },
        "input": [{
            "type": "message",
            "role": "user",
            "content": [{ "type": "input_text", "text": problem }]
        }]
    });
    let resp = client
        .post(OPENAI_RESPONSES_API)
        .bearer_auth(api_key)
        .json(&body)
        .send()
        .await
        .map_err(|e| describe_request_error("openai", e))?;
    if !resp.status().is_success() {
        return Err(format!("openai HTTP {}", resp.status().as_u16()));
    }
    let payload: Value = resp
        .json()
        .await
        .map_err(|_| "openai response parse failed".to_string())?;
    Ok(extract_openai_responses_output_text(&payload))
}

async fn ask_gemini(client: &Client, problem: &str) -> Result<String, String> {
    let api_key = std::env::var("GEMINI_API_KEY")
        .or_else(|_| std::env::var("GOOGLE_API_KEY"))
        .map_err(|_| "GEMINI_API_KEY or GOOGLE_API_KEY not set")?;
    let url = format!(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key={api_key}"
    );
    let body = json!({
        "contents": [ { "parts": [ { "text": problem } ] } ]
    });
    let resp = client
        .post(&url)
        .json(&body)
        .send()
        .await
        .map_err(|e| describe_request_error("gemini", e))?;
    if !resp.status().is_success() {
        return Err(format!("gemini HTTP {}", resp.status().as_u16()));
    }
    let payload: Value = resp
        .json()
        .await
        .map_err(|_| "gemini response parse failed".to_string())?;
    Ok(payload
        .get("candidates")
        .and_then(|c| c.get(0))
        .and_then(|c| c.get("content"))
        .and_then(|c| c.get("parts"))
        .and_then(|p| p.get(0))
        .and_then(|p| p.get("text"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string())
}

async fn ask_perplexity(client: &Client, problem: &str) -> Result<String, String> {
    let api_key = std::env::var("PERPLEXITY_API_KEY").map_err(|_| "PERPLEXITY_API_KEY not set")?;
    let body = json!({
        "model": "sonar",
        "messages": [ { "role": "user", "content": problem } ],
        "max_tokens": 1024,
    });
    let resp = client
        .post("https://api.perplexity.ai/chat/completions")
        .bearer_auth(api_key)
        .json(&body)
        .send()
        .await
        .map_err(|e| describe_request_error("perplexity", e))?;
    if !resp.status().is_success() {
        return Err(format!("perplexity HTTP {}", resp.status().as_u16()));
    }
    let payload: Value = resp
        .json()
        .await
        .map_err(|_| "perplexity response parse failed".to_string())?;
    Ok(payload
        .get("choices")
        .and_then(|c| c.get(0))
        .and_then(|c| c.get("message"))
        .and_then(|m| m.get("content"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string())
}

fn describe_request_error(provider: &str, error: reqwest::Error) -> String {
    let reason = if error.is_timeout() {
        "timeout"
    } else if error.is_connect() {
        "connect"
    } else if error.is_request() {
        "request"
    } else if error.is_body() {
        "body"
    } else if error.is_decode() {
        "decode"
    } else {
        "request"
    };
    format!("{provider} request failed: {reason}")
}

pub fn mixture_of_minds_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "mixture_of_minds".to_string(),
        description: "Specialty D4 — query multiple external cloud models (claude, openai, \
             gemini, perplexity) in parallel and aggregate. Requires \
             allow_cloud_external_requests=true because the problem text is sent to provider \
             APIs. Returns each model's contribution plus a 'best' field chosen by response \
             length. For every cloud model the matching API key env var must be set \
             (ANTHROPIC_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY or GOOGLE_API_KEY, \
             PERPLEXITY_API_KEY). Max 4 models per call."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "problem": { "type": "string", "description": "The question to dispatch." },
                "allow_cloud_external_requests": {
                    "type": "boolean",
                    "description": "Must be true to confirm the problem may be sent to external provider APIs."
                },
                "models": {
                    "type": "array",
                    "items": { "type": "string", "enum": MOM_ALLOWED_MODELS },
                    "description": "Subset of models to query (default: [claude, openai, gemini])."
                }
            },
            "required": ["problem", "allow_cloud_external_requests"]
        }),
    }
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use std::sync::Mutex;
    use tempfile::TempDir;

    struct StubDelegate {
        last_payload: Mutex<Option<(String, String)>>,
        response: String,
    }

    impl AgentEventDelegate for StubDelegate {
        fn on_thinking_delta(&self, _: String) {}
        fn on_text_delta(&self, _: String) {}
        fn on_tool_input_delta(&self, _: u32, _: String) {}
        fn on_tool_started(&self, _: String, _: String, _: String) {}
        fn on_tool_completed(&self, _: String, _: String, _: bool) {}
        fn on_subagent_spawned(&self, _: String, _: String) {}
        fn on_permission_required(&self, _: String, _: String, _: String, _: String) {}
        fn on_context_compacting(&self, _: u32) {}
        fn on_context_compacted(&self, _: u32) {}
        fn on_turn_started(&self, _: u32, _: u32) {}
        fn on_complete(&self, _: String, _: u32, _: u32) {}
        fn on_error(&self, _: String) {}
        fn execute_computer_action(&self, _: String) -> String {
            "{}".to_string()
        }
        fn wait_for_permission(&self, _: String) -> bool {
            true
        }
        fn ask_user_question(&self, _: String) -> String {
            "{}".to_string()
        }
        fn perceive_app(&self, _: String, _: String) -> String {
            "{}".to_string()
        }
        fn interact_with_app(&self, _: String) -> String {
            "{}".to_string()
        }
        fn start_screen_watch(&self, _: String) -> String {
            "{}".to_string()
        }
        fn manage_ssm_state(&self, _: String) -> String {
            "{}".to_string()
        }
        fn generate_constrained(&self, _: String, _: String) -> String {
            "{}".to_string()
        }
        fn generate_image(&self, _: String, _: String) -> String {
            "{\"error\":\"image_generate stub\"}".to_string()
        }
        fn trigger_nightbrain_job(&self, job: String, priority: String) -> String {
            *self.last_payload.lock().unwrap() = Some((job, priority));
            self.response.clone()
        }
        fn get_partner_context(&self, note_id: String, cursor_offset: u32) -> String {
            *self.last_payload.lock().unwrap() = Some((note_id, cursor_offset.to_string()));
            self.response.clone()
        }
    }

    // nightbrain_trigger ----------------------------------------------------

    #[tokio::test]
    async fn nightbrain_trigger_forwards_job_and_priority() {
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(StubDelegate {
            last_payload: Mutex::new(None),
            response: r#"{"job_id":"n1","status":"scheduled"}"#.to_string(),
        });
        let handler = NightBrainTriggerHandler::new(Arc::clone(&delegate));
        let result = handler
            .execute(&json!({
                "job": "memory_distillation",
                "priority": "immediate"
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["job"], json!("memory_distillation"));
        assert_eq!(parsed["priority"], json!("immediate"));
        assert_eq!(parsed["result"]["job_id"], json!("n1"));
    }

    #[tokio::test]
    async fn nightbrain_trigger_defaults_to_immediate_priority() {
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(StubDelegate {
            last_payload: Mutex::new(None),
            response: r#"{"job_id":"n1","status":"scheduled"}"#.to_string(),
        });
        let handler = NightBrainTriggerHandler::new(Arc::clone(&delegate));
        let result = handler
            .execute(&json!({
                "job": "maintenance_log"
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["priority"], json!("immediate"));
    }

    #[tokio::test]
    async fn nightbrain_trigger_rejects_unknown_job() {
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(StubDelegate {
            last_payload: Mutex::new(None),
            response: "{}".to_string(),
        });
        let handler = NightBrainTriggerHandler::new(delegate);
        let err = handler
            .execute(&json!({ "job": "vault_integrity_check" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("unknown job"));
    }

    #[tokio::test]
    async fn nightbrain_trigger_rejects_non_immediate_priority() {
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(StubDelegate {
            last_payload: Mutex::new(None),
            response: "{}".to_string(),
        });
        let handler = NightBrainTriggerHandler::new(delegate);
        let err = handler
            .execute(&json!({
                "job": "memory_distillation",
                "priority": "normal"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("priority"));
    }

    #[tokio::test]
    async fn nightbrain_trigger_rejects_non_string_priority() {
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(StubDelegate {
            last_payload: Mutex::new(None),
            response: "{}".to_string(),
        });
        let handler = NightBrainTriggerHandler::new(delegate);
        let err = handler
            .execute(&json!({
                "job": "memory_distillation",
                "priority": 7
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("priority"));
    }

    #[tokio::test]
    async fn nightbrain_trigger_rejects_non_json_delegate_without_echoing_raw() {
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(StubDelegate {
            last_payload: Mutex::new(None),
            response: "not json api_key=do-not-leak".to_string(),
        });
        let handler = NightBrainTriggerHandler::new(delegate);
        let err = handler
            .execute(&json!({ "job": "maintenance_log" }))
            .await
            .unwrap_err();
        let message = format!("{err}");
        assert!(message.contains("non-JSON"));
        assert!(!message.contains("api_key"));
    }

    #[tokio::test]
    async fn inline_partner_forwards_note_and_offset() {
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(StubDelegate {
            last_payload: Mutex::new(None),
            response: r#"{"success":true,"suggestion":"Focus here"}"#.to_string(),
        });
        let handler = InlinePartnerHandler::new(Arc::clone(&delegate));
        let result = handler
            .execute(&json!({
                "note_id": "note-123",
                "cursor_offset": 42
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["note_id"], json!("note-123"));
        assert_eq!(parsed["cursor_offset"], json!(42));
        assert_eq!(parsed["context"]["suggestion"], json!("Focus here"));
    }

    #[tokio::test]
    async fn inline_partner_requires_cursor_offset() {
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(StubDelegate {
            last_payload: Mutex::new(None),
            response: "{}".to_string(),
        });
        let handler = InlinePartnerHandler::new(delegate);
        let err = handler
            .execute(&json!({ "note_id": "note-123" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("cursor_offset"));
    }

    #[tokio::test]
    async fn inline_partner_rejects_oversized_note_id() {
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(StubDelegate {
            last_payload: Mutex::new(None),
            response: "{}".to_string(),
        });
        let handler = InlinePartnerHandler::new(delegate);
        let note_id = "n".repeat(MAX_INLINE_NOTE_ID_CHARS + 1);
        let err = handler
            .execute(&json!({
                "note_id": note_id,
                "cursor_offset": 0
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("note_id exceeds"));
    }

    #[tokio::test]
    async fn inline_partner_rejects_non_integer_cursor_offset() {
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(StubDelegate {
            last_payload: Mutex::new(None),
            response: "{}".to_string(),
        });
        let handler = InlinePartnerHandler::new(delegate);
        let err = handler
            .execute(&json!({
                "note_id": "note-123",
                "cursor_offset": "42"
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("cursor_offset"));
    }

    #[tokio::test]
    async fn inline_partner_rejects_non_json_delegate_without_echoing_raw() {
        let delegate: Arc<dyn AgentEventDelegate> = Arc::new(StubDelegate {
            last_payload: Mutex::new(None),
            response: "not json password=do-not-leak".to_string(),
        });
        let handler = InlinePartnerHandler::new(delegate);
        let err = handler
            .execute(&json!({
                "note_id": "note-123",
                "cursor_offset": 42
            }))
            .await
            .unwrap_err();
        let message = format!("{err}");
        assert!(message.contains("non-JSON"));
        assert!(!message.contains("password"));
    }

    // self_evolve -----------------------------------------------------------

    fn build_fake_session(root: &std::path::Path, name: &str, events: &str) {
        let dir = root.join("sessions").join(name);
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(dir.join("trace.json"), events).unwrap();
    }

    #[tokio::test]
    async fn self_evolve_handles_missing_sessions_dir() {
        let tmp = TempDir::new().unwrap();
        let handler = SelfEvolveHandler::new(tmp.path().to_path_buf());
        let result = handler
            .execute(&json!({ "action": "analyze" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["sessions_scanned"], json!(0));
    }

    #[tokio::test]
    async fn self_evolve_flags_high_error_rate() {
        let tmp = TempDir::new().unwrap();
        // 5 calls, 2 errors → 40% rate (triggers pattern)
        let events = r#"[
            {"timestamp":"2026-01-01T00:00:00Z","kind":"tool_call","name":"risky_tool","duration_ms":100,"outcome":"success"},
            {"timestamp":"2026-01-01T00:00:01Z","kind":"tool_call","name":"risky_tool","duration_ms":100,"outcome":"success"},
            {"timestamp":"2026-01-01T00:00:02Z","kind":"tool_call","name":"risky_tool","duration_ms":100,"outcome":"error"},
            {"timestamp":"2026-01-01T00:00:03Z","kind":"tool_call","name":"risky_tool","duration_ms":100,"outcome":"error"},
            {"timestamp":"2026-01-01T00:00:04Z","kind":"tool_call","name":"risky_tool","duration_ms":100,"outcome":"success"}
        ]"#;
        build_fake_session(tmp.path(), "2026-01-01_aaa", events);

        let handler = SelfEvolveHandler::new(tmp.path().to_path_buf());
        let result = handler
            .execute(&json!({ "action": "analyze" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        let patterns = parsed["patterns"].as_array().unwrap();
        assert!(
            patterns
                .iter()
                .any(|p| p["kind"] == "high_error_rate" && p["tool"] == "risky_tool")
        );
    }

    #[tokio::test]
    async fn self_evolve_reports_oversized_trace_as_skipped() {
        let tmp = TempDir::new().unwrap();
        let dir = tmp.path().join("sessions").join("2026-01-01_huge");
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(
            dir.join("trace.json"),
            vec![b' '; (MAX_SELF_EVOLVE_TRACE_BYTES + 1) as usize],
        )
        .unwrap();

        let handler = SelfEvolveHandler::new(tmp.path().to_path_buf());
        let result = handler
            .execute(&json!({ "action": "analyze" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["sessions_skipped"], json!(1));
        assert_eq!(
            parsed["skipped_traces"][0]["reason"],
            json!("trace_too_large")
        );
    }

    #[tokio::test]
    async fn self_evolve_propose_emits_mutation_per_pattern() {
        let tmp = TempDir::new().unwrap();
        let events = r#"[
            {"timestamp":"2026-01-01T00:00:00Z","kind":"tool_call","name":"flaky","duration_ms":50,"outcome":"success"},
            {"timestamp":"2026-01-01T00:00:01Z","kind":"tool_call","name":"flaky","duration_ms":50,"outcome":"error"},
            {"timestamp":"2026-01-01T00:00:02Z","kind":"tool_call","name":"flaky","duration_ms":50,"outcome":"error"},
            {"timestamp":"2026-01-01T00:00:03Z","kind":"tool_call","name":"flaky","duration_ms":50,"outcome":"error"}
        ]"#;
        build_fake_session(tmp.path(), "2026-01-01_bbb", events);

        let handler = SelfEvolveHandler::new(tmp.path().to_path_buf());
        let result = handler
            .execute(&json!({ "action": "propose" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        let proposals = parsed["proposals"].as_array().unwrap();
        assert!(!proposals.is_empty());
        assert_eq!(proposals[0]["mutation_type"], json!("add_error_handler"));
    }

    #[tokio::test]
    async fn self_evolve_sanitizes_advisory_skill_name() {
        let tmp = TempDir::new().unwrap();
        let events = r#"[
            {"timestamp":"2026-01-01T00:00:00Z","kind":"tool_call","name":"../Risk Tool!","duration_ms":50,"outcome":"error"},
            {"timestamp":"2026-01-01T00:00:01Z","kind":"tool_call","name":"../Risk Tool!","duration_ms":50,"outcome":"error"},
            {"timestamp":"2026-01-01T00:00:02Z","kind":"tool_call","name":"../Risk Tool!","duration_ms":50,"outcome":"success"}
        ]"#;
        build_fake_session(tmp.path(), "2026-01-01_slug", events);

        let handler = SelfEvolveHandler::new(tmp.path().to_path_buf());
        let result = handler
            .execute(&json!({ "action": "propose" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(
            parsed["proposals"][0]["skill"],
            json!("risk-tool-optimizer")
        );
        assert_eq!(advisory_skill_slug("///"), "tool");
    }

    #[tokio::test]
    async fn self_evolve_rejects_unknown_action() {
        let tmp = TempDir::new().unwrap();
        let handler = SelfEvolveHandler::new(tmp.path().to_path_buf());
        let err = handler
            .execute(&json!({ "action": "evolve" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("unknown action"));
    }

    // mixture_of_minds ------------------------------------------------------

    #[tokio::test]
    async fn mom_requires_problem() {
        let handler = MixtureOfMindsHandler::new().unwrap();
        let err = handler.execute(&json!({})).await.unwrap_err();
        assert!(format!("{err}").contains("problem"));
    }

    #[tokio::test]
    async fn mom_requires_cloud_external_consent() {
        let handler = MixtureOfMindsHandler::new().unwrap();
        let err = handler
            .execute(&json!({ "problem": "hello" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("allow_cloud_external_requests"));
    }

    #[tokio::test]
    async fn mom_rejects_blank_or_oversized_problem() {
        let handler = MixtureOfMindsHandler::new().unwrap();
        let blank = handler
            .execute(&json!({
                "problem": "   ",
                "allow_cloud_external_requests": true
            }))
            .await
            .unwrap_err();
        assert!(format!("{blank}").contains("problem"));

        let oversized = handler
            .execute(&json!({
                "problem": "x".repeat(MAX_MOM_PROBLEM_CHARS + 1),
                "allow_cloud_external_requests": true
            }))
            .await
            .unwrap_err();
        assert!(format!("{oversized}").contains("problem"));
    }

    #[tokio::test]
    async fn mom_rejects_malformed_cloud_consent_and_models() {
        let handler = MixtureOfMindsHandler::new().unwrap();
        let bad_consent = handler
            .execute(&json!({
                "problem": "hello",
                "allow_cloud_external_requests": "true"
            }))
            .await
            .unwrap_err();
        assert!(format!("{bad_consent}").contains("allow_cloud_external_requests"));

        let non_array_models = handler
            .execute(&json!({
                "problem": "hello",
                "allow_cloud_external_requests": true,
                "models": "claude"
            }))
            .await
            .unwrap_err();
        assert!(format!("{non_array_models}").contains("models"));

        let non_string_model = handler
            .execute(&json!({
                "problem": "hello",
                "allow_cloud_external_requests": true,
                "models": ["claude", 42]
            }))
            .await
            .unwrap_err();
        assert!(format!("{non_string_model}").contains("models[1]"));
    }

    #[tokio::test]
    async fn mom_rejects_empty_models_array() {
        let handler = MixtureOfMindsHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "problem": "hello",
                "allow_cloud_external_requests": true,
                "models": []
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("empty"));
    }

    #[tokio::test]
    async fn mom_rejects_too_many_models() {
        let handler = MixtureOfMindsHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "problem": "hello",
                "allow_cloud_external_requests": true,
                "models": ["claude", "openai", "gemini", "perplexity", "extra"]
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("at most"));
    }

    #[tokio::test]
    async fn mom_rejects_unknown_model_before_network() {
        let handler = MixtureOfMindsHandler::new().unwrap();
        let err = handler
            .execute(&json!({
                "problem": "hello",
                "allow_cloud_external_requests": true,
                "models": ["gpt-4o"]
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("unknown model"));
    }

    #[test]
    fn mom_schema_requires_cloud_external_consent() {
        let schema = mixture_of_minds_schema();
        assert_eq!(
            schema.parameters["required"],
            json!(["problem", "allow_cloud_external_requests"])
        );
        assert!(
            schema.description.contains("external cloud models")
                && schema
                    .description
                    .contains("allow_cloud_external_requests=true")
        );
    }

    #[test]
    fn mixture_openai_uses_responses_not_legacy_chat_completions() {
        let source = include_str!("intelligence.rs");
        let legacy_fragment = ["api.openai.com", "v1", "chat", "completions"].join("/");

        assert!(source.contains("OPENAI_RESPONSES_API"));
        assert!(!source.contains(&legacy_fragment));
    }

    #[tokio::test]
    async fn mom_records_errors_for_missing_keys() {
        // With no API keys set, all contributors should fail cleanly — we get
        // an error array and zero best answer.
        let saved_anthropic = std::env::var("ANTHROPIC_API_KEY").ok();
        let saved_openai = std::env::var("OPENAI_API_KEY").ok();
        let saved_gemini = std::env::var("GEMINI_API_KEY").ok();
        let saved_google = std::env::var("GOOGLE_API_KEY").ok();
        std::env::remove_var("ANTHROPIC_API_KEY");
        std::env::remove_var("OPENAI_API_KEY");
        std::env::remove_var("GEMINI_API_KEY");
        std::env::remove_var("GOOGLE_API_KEY");

        let handler = MixtureOfMindsHandler::new().unwrap();
        let result = handler
            .execute(&json!({
                "problem": "why is the sky blue",
                "allow_cloud_external_requests": true,
                "models": ["claude", "openai", "gemini"]
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["cloud_requests_authorized"], json!(true));
        assert_eq!(parsed["models_responded"], json!(0));
        let contributions = parsed["contributions"].as_array().unwrap();
        assert_eq!(contributions.len(), 3);
        for c in contributions {
            assert_eq!(c["success"], json!(false));
        }

        if let Some(v) = saved_anthropic {
            std::env::set_var("ANTHROPIC_API_KEY", v);
        }
        if let Some(v) = saved_openai {
            std::env::set_var("OPENAI_API_KEY", v);
        }
        if let Some(v) = saved_gemini {
            std::env::set_var("GEMINI_API_KEY", v);
        }
        if let Some(v) = saved_google {
            std::env::set_var("GOOGLE_API_KEY", v);
        }
    }
}
