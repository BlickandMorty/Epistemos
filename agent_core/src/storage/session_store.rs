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
    #[serde(skip_serializing_if = "Option::is_none")]
    pub parent_session_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub chat_thread_id: Option<String>,
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
            parent_session_id: None,
            chat_thread_id: None,
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
        let mut events: Vec<TraceEvent> = serde_json::from_str(&existing).unwrap_or_default();
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
        self.merge_external_lineage_metadata();
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

    pub fn set_lineage(
        &mut self,
        parent_session_id: Option<String>,
        chat_thread_id: Option<String>,
    ) -> Result<(), VaultError> {
        self.metadata.parent_session_id = parent_session_id;
        self.metadata.chat_thread_id = chat_thread_id;
        self.persist_metadata()
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

    /// Generate a richer 9-section summary from transcript and trace artifacts.
    pub fn generate_structured_summary(&self) -> String {
        let transcript = self.load_transcript_turns();
        let trace = self.load_trace_events();

        let user_intent = transcript
            .iter()
            .find(|turn| matches!(turn.role.as_str(), "user" | "human"))
            .map(|turn| normalize_summary_text(&turn.content))
            .filter(|text| !text.is_empty())
            .unwrap_or_else(|| "(objective not captured)".to_string());

        let assistant_turns: Vec<&TranscriptTurn> = transcript
            .iter()
            .filter(|turn| matches!(turn.role.as_str(), "assistant" | "gpt" | "ai"))
            .collect();
        let last_assistant_text = assistant_turns
            .last()
            .map(|turn| normalize_summary_text(&turn.content))
            .filter(|text| !text.is_empty());

        let mut decisions = Vec::new();
        for turn in &assistant_turns {
            decisions.extend(extract_decision_lines(&turn.content));
        }
        decisions = dedup_preserving_order(decisions);

        let knowledge_lines = last_assistant_text
            .as_deref()
            .map(extract_notable_lines)
            .unwrap_or_default();
        let open_questions = transcript
            .iter()
            .flat_map(|turn| extract_open_questions(&turn.content))
            .collect::<Vec<_>>();
        let open_questions = dedup_preserving_order(open_questions);

        let mut tool_counts: std::collections::BTreeMap<String, (u32, u32)> =
            std::collections::BTreeMap::new();
        for turn in &transcript {
            for tool in &turn.tool_calls {
                let entry = tool_counts.entry(tool.name.clone()).or_insert((0, 0));
                entry.0 += 1;
                if tool.is_error {
                    entry.1 += 1;
                }
            }
        }

        let compaction_count = trace
            .iter()
            .filter(|event| event.kind == "compaction")
            .count();
        let approval_count = trace
            .iter()
            .filter(|event| event.kind == "approval")
            .count();
        let tool_event_count = trace
            .iter()
            .filter(|event| event.kind == "tool_call")
            .count();
        let follow_ups = build_follow_ups(
            &tool_counts,
            &open_questions,
            self.metadata.status.as_str(),
            self.metadata.error.as_deref(),
        );

        let mut lines = vec![
            format!("# Session Summary: {}", self.metadata.id),
            String::new(),
        ];

        push_section(&mut lines, "1. User Intent", &[user_intent]);

        let mut context_loaded = vec![
            format!(
                "Provider: {} via {}.",
                self.metadata.model, self.metadata.provider
            ),
            format!(
                "Turn count: {} with {} input / {} output tokens.",
                self.metadata.turn_count,
                self.metadata.token_count.input,
                self.metadata.token_count.output
            ),
        ];
        if let Some(parent) = &self.metadata.parent_session_id {
            context_loaded.push(format!("Parent session: {}.", parent));
        }
        if let Some(chat_thread_id) = &self.metadata.chat_thread_id {
            context_loaded.push(format!("Chat thread: {}.", chat_thread_id));
        }
        push_section(&mut lines, "2. Context Loaded", &context_loaded);

        let mut approach = vec![format!(
            "Processed {} assistant turn(s) and {} recorded tool event(s).",
            assistant_turns.len(),
            tool_event_count
        )];
        if compaction_count > 0 {
            approach.push(format!(
                "Compacted context {} time(s) to preserve working state.",
                compaction_count
            ));
        }
        if approval_count > 0 {
            approach.push(format!(
                "Paused {} time(s) for explicit tool approval.",
                approval_count
            ));
        }
        push_section(&mut lines, "3. Approach Taken", &approach);

        push_section(
            &mut lines,
            "4. Key Decisions",
            &non_empty_or_placeholder(
                decisions,
                "No explicit decisions were captured in the transcript.",
            ),
        );

        let tool_summary = if tool_counts.is_empty() {
            vec!["No tools were recorded.".to_string()]
        } else {
            tool_counts
                .into_iter()
                .map(|(name, (count, errors))| {
                    if errors == 0 {
                        format!("{name}: {count} call(s), all successful.")
                    } else {
                        format!("{name}: {count} call(s), {errors} error(s).")
                    }
                })
                .collect()
        };
        push_section(&mut lines, "5. Tool Usage Summary", &tool_summary);

        let mut outcomes = vec![format!(
            "Session finished with status: {}.",
            self.metadata.status
        )];
        if let Some(last_assistant_text) = last_assistant_text {
            outcomes.push(last_assistant_text);
        } else if let Some(error) = &self.metadata.error {
            outcomes.push(error.clone());
        }
        push_section(&mut lines, "6. Outcomes", &outcomes);

        push_section(
            &mut lines,
            "7. Knowledge Extracted",
            &non_empty_or_placeholder(
                knowledge_lines,
                "No durable knowledge summary was extracted from the final response.",
            ),
        );

        push_section(
            &mut lines,
            "8. Open Questions",
            &non_empty_or_placeholder(open_questions, "No explicit open questions were recorded."),
        );

        push_section(&mut lines, "9. Follow-ups", &follow_ups);
        lines.join("\n")
    }

    fn persist_metadata(&self) -> Result<(), VaultError> {
        let json = serde_json::to_string_pretty(&self.metadata)
            .map_err(|e| VaultError::DatabaseError(format!("session json: {e}")))?;
        fs::write(self.root.join("session.json"), json)?;
        Ok(())
    }

    fn merge_external_lineage_metadata(&mut self) {
        let meta_path = self.root.join("session.json");
        let Ok(content) = fs::read_to_string(meta_path) else {
            return;
        };
        let Ok(existing) = serde_json::from_str::<SessionMetadata>(&content) else {
            return;
        };
        if self.metadata.parent_session_id.is_none() {
            self.metadata.parent_session_id = existing.parent_session_id;
        }
        if self.metadata.chat_thread_id.is_none() {
            self.metadata.chat_thread_id = existing.chat_thread_id;
        }
    }

    fn load_transcript_turns(&self) -> Vec<TranscriptTurn> {
        let transcript_path = self.root.join("transcript.jsonl");
        let content = match fs::read_to_string(&transcript_path) {
            Ok(content) => content,
            Err(_) => return Vec::new(),
        };

        content
            .lines()
            .filter(|line| !line.trim().is_empty())
            .filter_map(|line| serde_json::from_str(line).ok())
            .collect()
    }

    fn load_trace_events(&self) -> Vec<TraceEvent> {
        let trace_path = self.root.join("trace.json");
        let content = match fs::read_to_string(&trace_path) {
            Ok(content) => content,
            Err(_) => return Vec::new(),
        };
        serde_json::from_str(&content).unwrap_or_default()
    }
}

fn push_section(lines: &mut Vec<String>, title: &str, body_lines: &[String]) {
    lines.push(format!("## {title}"));
    lines.push(String::new());
    for line in body_lines {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }
        lines.push(format!("- {trimmed}"));
    }
    lines.push(String::new());
}

fn non_empty_or_placeholder(items: Vec<String>, placeholder: &str) -> Vec<String> {
    if items.is_empty() {
        vec![placeholder.to_string()]
    } else {
        items
    }
}

fn normalize_summary_text(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn extract_decision_lines(text: &str) -> Vec<String> {
    text.lines()
        .map(str::trim)
        .filter(|line| {
            line.starts_with("I should")
                || line.starts_with("I'll ")
                || line.starts_with("Plan:")
                || line.starts_with("Decision:")
                || line.starts_with("Strategy:")
        })
        .map(|line| truncate_summary_line(line, 180))
        .collect()
}

fn extract_notable_lines(text: &str) -> Vec<String> {
    let mut lines = Vec::new();
    for raw_line in text.lines() {
        let trimmed = raw_line.trim().trim_start_matches('-').trim();
        if trimmed.is_empty() || trimmed.starts_with("```") {
            continue;
        }
        lines.push(truncate_summary_line(trimmed, 180));
        if lines.len() == 4 {
            break;
        }
    }
    lines
}

fn extract_open_questions(text: &str) -> Vec<String> {
    text.lines()
        .map(str::trim)
        .filter(|line| line.ends_with('?'))
        .map(|line| truncate_summary_line(line, 180))
        .collect()
}

fn build_follow_ups(
    tool_counts: &std::collections::BTreeMap<String, (u32, u32)>,
    open_questions: &[String],
    status: &str,
    error: Option<&str>,
) -> Vec<String> {
    let mut follow_ups = Vec::new();
    if tool_counts.keys().any(|name| name.contains("send_message")) {
        follow_ups
            .push("Validate outbound channel delivery with a live end-to-end message.".to_string());
    }
    if !open_questions.is_empty() {
        follow_ups.push(
            "Resolve the remaining open questions before promoting this workflow.".to_string(),
        );
    }
    if status != "completed" {
        follow_ups.push(format!(
            "Investigate why the session ended with status `{status}`."
        ));
    }
    if let Some(error) = error {
        follow_ups.push(format!(
            "Address the terminal issue: {}.",
            truncate_summary_line(error, 160)
        ));
    }
    non_empty_or_placeholder(follow_ups, "No explicit follow-up actions were recorded.")
}

fn truncate_summary_line(text: &str, max_chars: usize) -> String {
    let char_count = text.chars().count();
    if char_count <= max_chars {
        return text.to_string();
    }
    let mut truncated: String = text.chars().take(max_chars).collect();
    truncated.push('…');
    truncated
}

fn dedup_preserving_order(items: Vec<String>) -> Vec<String> {
    let mut seen = std::collections::HashSet::new();
    let mut deduped = Vec::new();
    for item in items {
        if seen.insert(item.clone()) {
            deduped.push(item);
        }
    }
    deduped
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
    results.sort_by(|a, b| {
        b.started_at_epoch
            .partial_cmp(&a.started_at_epoch)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

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
        let folder =
            SessionFolder::create(tmp.path(), "test_abc12345", "claude-opus-4", "anthropic")
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

        folder
            .finalize("completed", 5, 1000, 2000, None, None)
            .unwrap();

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
    fn lineage_metadata_round_trips_in_session_json() {
        let tmp = TempDir::new().unwrap();
        let mut folder =
            SessionFolder::create(tmp.path(), "sess_lineage", "model", "provider").unwrap();

        folder
            .set_lineage(
                Some("sess_parent".to_string()),
                Some("chat-thread-1".to_string()),
            )
            .unwrap();

        let json_str = read_session_metadata(folder.root()).unwrap();
        let meta: SessionMetadata = serde_json::from_str(&json_str).unwrap();
        assert_eq!(meta.parent_session_id.as_deref(), Some("sess_parent"));
        assert_eq!(meta.chat_thread_id.as_deref(), Some("chat-thread-1"));
    }

    #[test]
    fn structured_summary_uses_transcript_and_trace() {
        let tmp = TempDir::new().unwrap();
        let folder =
            SessionFolder::create(tmp.path(), "sess_structured", "claude", "anthropic").unwrap();

        folder
            .append_transcript_turn(&TranscriptTurn {
                timestamp: Utc::now(),
                role: "user".to_string(),
                content: "Compare OpenClaw and Hermes for channel control.".to_string(),
                model: None,
                tokens: Some(8),
                tool_calls: Vec::new(),
                latency_ms: None,
            })
            .unwrap();
        folder
            .append_transcript_turn(&TranscriptTurn {
                timestamp: Utc::now(),
                role: "assistant".to_string(),
                content: "I’ll audit the existing channel adapters and prioritize iMessage first."
                    .to_string(),
                model: Some("claude-sonnet".to_string()),
                tokens: Some(22),
                tool_calls: vec![ToolCallRecord {
                    name: "send_message".to_string(),
                    tool_use_id: "tc_send".to_string(),
                    input_summary: Some("{\"platform\":\"imessage\"}".to_string()),
                    result_summary: Some("drafted outbound test payload".to_string()),
                    is_error: false,
                }],
                latency_ms: Some(340),
            })
            .unwrap();
        folder
            .append_trace_event(&TraceEvent {
                timestamp: Utc::now(),
                kind: "compaction".to_string(),
                name: None,
                input_summary: Some("context grew past 80%".to_string()),
                output_summary: Some("inserted structured compacted context block".to_string()),
                duration_ms: Some(19),
                outcome: Some("success".to_string()),
            })
            .unwrap();

        let summary = folder.generate_structured_summary();

        assert!(summary.contains("## 1. User Intent"));
        assert!(summary.contains("Compare OpenClaw and Hermes"));
        assert!(summary.contains("## 5. Tool Usage Summary"));
        assert!(summary.contains("send_message"));
        assert!(summary.contains("## 6. Outcomes"));
        assert!(summary.contains("## 9. Follow-ups"));
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
