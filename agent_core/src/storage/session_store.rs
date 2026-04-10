//! Persistent session folder infrastructure.
//!
//! Every agent session creates a UUID-namespaced folder on disk containing:
//! - `session.json`      — metadata (model, provider, timestamps, tokens, status)
//! - `transcript.jsonl`  — append-only verbatim turns (immutable after write)
//! - `trace.json`        — tool calls, compaction events, errors with timings
//! - `summary.md`        — 9-section structured summary (written on session end)
//! - `artifacts/`        — files generated during the session

use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

use chrono::{DateTime, Local, Utc};
use serde::{Deserialize, Serialize};

use crate::reasoning_metrics::ReasoningTrajectoryMetrics;
use crate::storage::vault::VaultError;

// ---------------------------------------------------------------------------
// Session Metadata
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionMetadata {
    pub id: String,
    pub model: String,
    pub provider: String,
    pub started_at: DateTime<Utc>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ended_at: Option<DateTime<Utc>>,
    pub tags: Vec<String>,
    pub token_count: TokenCount,
    pub context_fill_pct: f32,
    pub turn_count: u32,
    /// "running", "completed", or "failed"
    pub status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reasoning_metrics: Option<ReasoningTrajectoryMetrics>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct TokenCount {
    pub input: u32,
    pub output: u32,
}

// ---------------------------------------------------------------------------
// Transcript Turn (one per JSONL line)
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TranscriptTurn {
    pub timestamp: DateTime<Utc>,
    pub role: String,
    pub content: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tokens: Option<u32>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tool_calls: Vec<ToolCallRecord>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub latency_ms: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolCallRecord {
    pub name: String,
    pub tool_use_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub input_summary: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result_summary: Option<String>,
    pub is_error: bool,
}

// ---------------------------------------------------------------------------
// Trace Event
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TraceEvent {
    pub timestamp: DateTime<Utc>,
    /// "tool_call", "compaction", "error", "turn_start", "turn_end"
    pub kind: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub input_summary: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub output_summary: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub duration_ms: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub outcome: Option<String>,
}

// ---------------------------------------------------------------------------
// Session Folder
// ---------------------------------------------------------------------------

/// Manages the on-disk layout for a single agent session.
pub struct SessionFolder {
    root: PathBuf,
    metadata: SessionMetadata,
}

impl SessionFolder {
    /// Create a new session folder inside `vault_root/sessions/`.
    ///
    /// Folder name format: `YYYY-MM-DD_<short_uuid>` (e.g. `2026-04-08_abc12345`).
    pub fn create(
        vault_root: &Path,
        session_id: &str,
        model: &str,
        provider: &str,
    ) -> Result<Self, VaultError> {
        let short_id = &session_id[..session_id.len().min(8)];
        let date = Local::now().format("%Y-%m-%d");
        let folder_name = format!("{date}_{short_id}");

        let root = vault_root.join("sessions").join(&folder_name);
        fs::create_dir_all(&root)?;
        fs::create_dir_all(root.join("artifacts"))?;

        let metadata = SessionMetadata {
            id: session_id.to_string(),
            model: model.to_string(),
            provider: provider.to_string(),
            started_at: Utc::now(),
            ended_at: None,
            tags: Vec::new(),
            token_count: TokenCount::default(),
            context_fill_pct: 0.0,
            turn_count: 0,
            status: "running".to_string(),
            error: None,
            reasoning_metrics: None,
        };

        // Write initial session.json
        let json = serde_json::to_string_pretty(&metadata)
            .map_err(|e| VaultError::DatabaseError(format!("session json: {e}")))?;
        fs::write(root.join("session.json"), json)?;

        // Create empty transcript.jsonl
        fs::write(root.join("transcript.jsonl"), "")?;

        // Create trace.json with empty array
        fs::write(root.join("trace.json"), "[]")?;

        Ok(Self { root, metadata })
    }

    /// Root path of this session folder.
    pub fn root(&self) -> &Path {
        &self.root
    }

    /// The session ID.
    pub fn session_id(&self) -> &str {
        &self.metadata.id
    }

    /// Append a single turn to `transcript.jsonl` (append-only, one JSON object per line).
    pub fn append_transcript_turn(&self, turn: &TranscriptTurn) -> Result<(), VaultError> {
        let mut line = serde_json::to_string(turn)
            .map_err(|e| VaultError::DatabaseError(format!("transcript json: {e}")))?;
        line.push('\n');

        let mut file = fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(self.root.join("transcript.jsonl"))?;
        file.write_all(line.as_bytes())?;
        Ok(())
    }

    /// Append a trace event. Reads the existing JSON array, pushes, and rewrites.
    /// For high-frequency sessions, consider switching to JSONL if this becomes a bottleneck.
    pub fn append_trace_event(&self, event: &TraceEvent) -> Result<(), VaultError> {
        let trace_path = self.root.join("trace.json");
        let existing = fs::read_to_string(&trace_path).unwrap_or_else(|_| "[]".to_string());
        let mut events: Vec<TraceEvent> = serde_json::from_str(&existing)
            .unwrap_or_default();
        events.push(event.clone());

        let json = serde_json::to_string_pretty(&events)
            .map_err(|e| VaultError::DatabaseError(format!("trace json: {e}")))?;
        fs::write(&trace_path, json)?;
        Ok(())
    }

    /// Finalize the session: update metadata with end timestamp, tokens, and status.
    pub fn finalize(
        &mut self,
        status: &str,
        turns: u32,
        input_tokens: u32,
        output_tokens: u32,
        error: Option<&str>,
        trajectory_metrics: Option<&ReasoningTrajectoryMetrics>,
    ) -> Result<(), VaultError> {
        self.metadata.ended_at = Some(Utc::now());
        self.metadata.status = status.to_string();
        self.metadata.turn_count = turns;
        self.metadata.token_count = TokenCount {
            input: input_tokens,
            output: output_tokens,
        };
        self.metadata.error = error.map(|s| s.to_string());
        self.metadata.reasoning_metrics = trajectory_metrics.cloned();

        let json = serde_json::to_string_pretty(&self.metadata)
            .map_err(|e| VaultError::DatabaseError(format!("session json: {e}")))?;
        fs::write(self.root.join("session.json"), json)?;
        Ok(())
    }

    /// Write the 9-section structured summary.
    pub fn write_summary(&self, summary: &str) -> Result<(), VaultError> {
        fs::write(self.root.join("summary.md"), summary)?;
        Ok(())
    }

    /// Get the path for a session artifact.
    pub fn artifact_path(&self, filename: &str) -> PathBuf {
        self.root.join("artifacts").join(filename)
    }

    /// Generate a default 9-section summary from the session metadata.
    /// Used as a fallback when the compaction engine does not produce one.
    pub fn generate_default_summary(&self) -> String {
        format!(
            "# Session Summary: {id}\n\n\
             ## 1. User Intent\n\
             _(session with {model} via {provider})_\n\n\
             ## 2. Context Loaded\n\
             _(auto-loaded from vault)_\n\n\
             ## 3. Approach Taken\n\
             {turns} turns, {input}+{output} tokens\n\n\
             ## 4. Key Decisions\n\
             _(extract from transcript)_\n\n\
             ## 5. Tool Usage Summary\n\
             _(see trace.json)_\n\n\
             ## 6. Outcomes\n\
             Status: {status}\n\n\
             ## 7. Knowledge Extracted\n\
             _(pending graphify)_\n\n\
             ## 8. Open Questions\n\
             _(none recorded)_\n\n\
             ## 9. Follow-ups\n\
             _(none recorded)_\n",
            id = self.metadata.id,
            model = self.metadata.model,
            provider = self.metadata.provider,
            turns = self.metadata.turn_count,
            input = self.metadata.token_count.input,
            output = self.metadata.token_count.output,
            status = self.metadata.status,
        )
    }
}

// ---------------------------------------------------------------------------
// Session Discovery (for the sidebar / FFI)
// ---------------------------------------------------------------------------

/// Lightweight info for listing sessions without reading full metadata.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionFolderInfo {
    pub session_id: String,
    pub model: String,
    pub provider: String,
    pub started_at_epoch: f64,
    pub status: String,
    pub turn_count: u32,
    pub folder_path: String,
}

/// Scan a vault's `sessions/` directory and return metadata for all sessions.
pub fn list_session_folders(vault_root: &Path) -> Result<Vec<SessionFolderInfo>, VaultError> {
    let sessions_dir = vault_root.join("sessions");
    if !sessions_dir.is_dir() {
        return Ok(Vec::new());
    }

    let mut results = Vec::new();

    for entry in fs::read_dir(&sessions_dir)? {
        let entry = entry?;
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }

        let meta_path = path.join("session.json");
        if !meta_path.exists() {
            continue;
        }

        let content = match fs::read_to_string(&meta_path) {
            Ok(c) => c,
            Err(_) => continue,
        };

        let meta: SessionMetadata = match serde_json::from_str(&content) {
            Ok(m) => m,
            Err(_) => continue,
        };

        results.push(SessionFolderInfo {
            session_id: meta.id,
            model: meta.model,
            provider: meta.provider,
            started_at_epoch: meta.started_at.timestamp() as f64,
            status: meta.status,
            turn_count: meta.turn_count,
            folder_path: path.to_string_lossy().to_string(),
        });
    }

    // Sort newest first
    results.sort_by(|a, b| b.started_at_epoch.partial_cmp(&a.started_at_epoch).unwrap_or(std::cmp::Ordering::Equal));

    Ok(results)
}

/// Read session metadata as a JSON string (for FFI).
pub fn read_session_metadata(session_folder_path: &Path) -> Result<String, VaultError> {
    let meta_path = session_folder_path.join("session.json");
    if !meta_path.exists() {
        return Err(VaultError::NotFound("session.json".to_string()));
    }
    Ok(fs::read_to_string(meta_path)?)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn create_session_folder() {
        let tmp = TempDir::new().unwrap();
        let folder = SessionFolder::create(
            tmp.path(),
            "test_abc12345",
            "claude-opus-4",
            "anthropic",
        )
        .unwrap();

        assert!(folder.root().join("session.json").exists());
        assert!(folder.root().join("transcript.jsonl").exists());
        assert!(folder.root().join("trace.json").exists());
        assert!(folder.root().join("artifacts").is_dir());

        // Verify session.json is valid
        let content = fs::read_to_string(folder.root().join("session.json")).unwrap();
        let meta: SessionMetadata = serde_json::from_str(&content).unwrap();
        assert_eq!(meta.id, "test_abc12345");
        assert_eq!(meta.model, "claude-opus-4");
        assert_eq!(meta.status, "running");
    }

    #[test]
    fn append_transcript_turn() {
        let tmp = TempDir::new().unwrap();
        let folder = SessionFolder::create(tmp.path(), "sess1", "model", "provider").unwrap();

        let turn = TranscriptTurn {
            timestamp: Utc::now(),
            role: "user".to_string(),
            content: "Hello, world!".to_string(),
            model: None,
            tokens: Some(5),
            tool_calls: Vec::new(),
            latency_ms: None,
        };
        folder.append_transcript_turn(&turn).unwrap();

        let turn2 = TranscriptTurn {
            timestamp: Utc::now(),
            role: "assistant".to_string(),
            content: "Hi there!".to_string(),
            model: Some("claude-opus-4".to_string()),
            tokens: Some(10),
            tool_calls: vec![ToolCallRecord {
                name: "bash".to_string(),
                tool_use_id: "tc_1".to_string(),
                input_summary: Some("ls -la".to_string()),
                result_summary: Some("file list".to_string()),
                is_error: false,
            }],
            latency_ms: Some(1200),
        };
        folder.append_transcript_turn(&turn2).unwrap();

        // Verify JSONL format
        let content = fs::read_to_string(folder.root().join("transcript.jsonl")).unwrap();
        let lines: Vec<&str> = content.lines().collect();
        assert_eq!(lines.len(), 2);

        // Each line should be valid JSON
        let _: TranscriptTurn = serde_json::from_str(lines[0]).unwrap();
        let parsed: TranscriptTurn = serde_json::from_str(lines[1]).unwrap();
        assert_eq!(parsed.role, "assistant");
        assert_eq!(parsed.tool_calls.len(), 1);
    }

    #[test]
    fn append_trace_event() {
        let tmp = TempDir::new().unwrap();
        let folder = SessionFolder::create(tmp.path(), "sess2", "model", "provider").unwrap();

        let event = TraceEvent {
            timestamp: Utc::now(),
            kind: "tool_call".to_string(),
            name: Some("bash".to_string()),
            input_summary: Some("ls -la".to_string()),
            output_summary: Some("3 files".to_string()),
            duration_ms: Some(150),
            outcome: Some("success".to_string()),
        };
        folder.append_trace_event(&event).unwrap();
        folder.append_trace_event(&event).unwrap();

        let content = fs::read_to_string(folder.root().join("trace.json")).unwrap();
        let events: Vec<TraceEvent> = serde_json::from_str(&content).unwrap();
        assert_eq!(events.len(), 2);
    }

    #[test]
    fn finalize_session() {
        let tmp = TempDir::new().unwrap();
        let mut folder = SessionFolder::create(tmp.path(), "sess3", "claude", "anthropic").unwrap();

        folder.finalize("completed", 5, 1000, 2000, None, None).unwrap();

        let content = fs::read_to_string(folder.root().join("session.json")).unwrap();
        let meta: SessionMetadata = serde_json::from_str(&content).unwrap();
        assert_eq!(meta.status, "completed");
        assert_eq!(meta.turn_count, 5);
        assert_eq!(meta.token_count.input, 1000);
        assert_eq!(meta.token_count.output, 2000);
        assert!(meta.ended_at.is_some());
    }

    #[test]
    fn finalize_session_persists_reasoning_metrics() {
        let tmp = TempDir::new().unwrap();
        let mut folder = SessionFolder::create(tmp.path(), "sess5", "claude", "anthropic").unwrap();
        let metrics = ReasoningTrajectoryMetrics {
            displacement: 0.6,
            path_length: 1.2,
            curvature_ratio: 2.0,
            loop_count: 1,
            error_count: 0,
            total_calls: 3,
            efficiency: 0.2,
            classification: crate::reasoning_metrics::TrajectoryClassification::Exploratory,
        };

        folder
            .finalize("completed", 3, 400, 500, None, Some(&metrics))
            .unwrap();

        let content = fs::read_to_string(folder.root().join("session.json")).unwrap();
        let meta: SessionMetadata = serde_json::from_str(&content).unwrap();
        let stored = meta.reasoning_metrics.expect("missing reasoning metrics");
        assert_eq!(stored.total_calls, 3);
        assert_eq!(stored.classification.as_str(), "exploratory");
    }

    #[test]
    fn write_summary() {
        let tmp = TempDir::new().unwrap();
        let folder = SessionFolder::create(tmp.path(), "sess4", "model", "provider").unwrap();

        let summary = folder.generate_default_summary();
        folder.write_summary(&summary).unwrap();

        let content = fs::read_to_string(folder.root().join("summary.md")).unwrap();
        assert!(content.contains("## 1. User Intent"));
        assert!(content.contains("## 9. Follow-ups"));
    }

    #[test]
    fn list_sessions() {
        let tmp = TempDir::new().unwrap();

        // Create two sessions
        let _f1 = SessionFolder::create(tmp.path(), "aaa11111", "model1", "prov1").unwrap();
        let _f2 = SessionFolder::create(tmp.path(), "bbb22222", "model2", "prov2").unwrap();

        let sessions = list_session_folders(tmp.path()).unwrap();
        assert_eq!(sessions.len(), 2);

        // Should be sorted newest first (both are near-simultaneous, but order is stable)
        assert!(sessions.iter().any(|s| s.session_id == "aaa11111"));
        assert!(sessions.iter().any(|s| s.session_id == "bbb22222"));
    }

    #[test]
    fn read_metadata() {
        let tmp = TempDir::new().unwrap();
        let folder = SessionFolder::create(tmp.path(), "meta1", "model", "provider").unwrap();

        let json_str = read_session_metadata(folder.root()).unwrap();
        let meta: SessionMetadata = serde_json::from_str(&json_str).unwrap();
        assert_eq!(meta.id, "meta1");
    }

    #[test]
    fn empty_vault_returns_empty_list() {
        let tmp = TempDir::new().unwrap();
        let sessions = list_session_folders(tmp.path()).unwrap();
        assert!(sessions.is_empty());
    }
}
