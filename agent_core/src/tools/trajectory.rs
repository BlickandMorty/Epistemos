//! Trajectory Exporter — ShareGPT-format JSONL dump of past sessions.
//!
//! Exports a completed agent session's transcript into the ShareGPT format
//! used by RL training datasets. Each session becomes one JSONL line
//! containing a `conversations` array with `from: "human" | "gpt" | "tool"`.
//!
//! Output shape:
//! ```json
//! {
//!   "id": "<session-id>",
//!   "model": "<model-id>",
//!   "provider": "<provider>",
//!   "started_at": "<iso8601>",
//!   "ended_at": "<iso8601>",
//!   "tags": ["..."],
//!   "conversations": [
//!     { "from": "system", "value": "<system prompt if captured>" },
//!     { "from": "human",  "value": "<user turn>" },
//!     { "from": "gpt",    "value": "<assistant turn>" },
//!     { "from": "tool",   "value": "<tool result JSON>", "name": "<tool_name>" }
//!   ]
//! }
//! ```
//!
//! The tool reads `transcript.jsonl` from each session folder, normalises
//! turns, and either writes a combined `.jsonl` file or returns the
//! serialised lines inline. Safe for `ChatLite` — it's read-only.

use std::fs;
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};

use async_trait::async_trait;
use serde_json::{json, Value};

use super::registry::{ToolError, ToolHandler};
use crate::storage::session_store::{
    list_session_folders, SessionFolderInfo, TranscriptTurn,
};

// ── Handler ────────────────────────────────────────────────────────────────

pub struct TrajectoryExportHandler {
    vault_root: PathBuf,
}

impl TrajectoryExportHandler {
    pub fn new(vault_root: PathBuf) -> Self {
        Self { vault_root }
    }
}

#[async_trait]
impl ToolHandler for TrajectoryExportHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let session_id = input.get("session_id").and_then(Value::as_str);
        let output_path = input.get("output_path").and_then(Value::as_str);
        let limit = input
            .get("limit")
            .and_then(Value::as_u64)
            .map(|n| n as usize);
        let include_tool_calls = input
            .get("include_tool_calls")
            .and_then(Value::as_bool)
            .unwrap_or(true);

        let folders = list_session_folders(&self.vault_root)
            .map_err(|e| ToolError::ExecutionFailed(format!("list sessions: {e}")))?;

        // Filter: either a single session or all. `list_session_folders`
        // already returns the list newest-first, so we just take a prefix
        // after optionally filtering by session_id.
        let candidates: Vec<SessionFolderInfo> = if let Some(sid) = session_id {
            folders
                .into_iter()
                .filter(|f| f.session_id == sid)
                .collect()
        } else {
            let mut sorted = folders;
            if let Some(n) = limit {
                sorted.truncate(n);
            }
            sorted
        };

        if candidates.is_empty() {
            return Err(ToolError::NotFound(
                "no sessions matched the filter".into(),
            ));
        }

        let mut lines: Vec<String> = Vec::with_capacity(candidates.len());
        let mut total_turns = 0usize;
        let mut skipped_sessions = 0usize;
        for info in &candidates {
            let folder_path = PathBuf::from(&info.folder_path);
            match build_sharegpt_line(&folder_path, include_tool_calls) {
                Ok((line, turns)) => {
                    lines.push(line);
                    total_turns += turns;
                }
                Err(e) => {
                    skipped_sessions += 1;
                    tracing::warn!(
                        "trajectory: skipped session {} ({}): {e}",
                        info.session_id,
                        info.folder_path
                    );
                }
            }
        }

        if let Some(path) = output_path {
            let resolved = resolve_output_path(path)?;
            if let Some(parent) = resolved.parent() {
                fs::create_dir_all(parent).map_err(|e| {
                    ToolError::ExecutionFailed(format!("mkdir {}: {e}", parent.display()))
                })?;
            }
            let body = lines.join("\n") + "\n";
            fs::write(&resolved, &body).map_err(|e| {
                ToolError::ExecutionFailed(format!("write {}: {e}", resolved.display()))
            })?;
            Ok(json!({
                "success": true,
                "mode": "file",
                "path": resolved.display().to_string(),
                "sessions_exported": lines.len(),
                "sessions_skipped": skipped_sessions,
                "total_turns": total_turns,
            })
            .to_string())
        } else {
            // Inline mode — cap at 20 sessions to keep the tool result from
            // blowing the context budget. Callers that want more should pass
            // output_path and read the file via read_file.
            let cap = 20usize;
            let truncated = lines.len() > cap;
            let returned: Vec<String> = lines.into_iter().take(cap).collect();
            Ok(json!({
                "success": true,
                "mode": "inline",
                "sessions_exported": returned.len(),
                "sessions_skipped": skipped_sessions,
                "total_turns": total_turns,
                "truncated": truncated,
                "sharegpt_jsonl": returned,
            })
            .to_string())
        }
    }
}

fn resolve_output_path(path: &str) -> Result<PathBuf, ToolError> {
    if path.is_empty() {
        return Err(ToolError::InvalidArguments("output_path is empty".into()));
    }
    let expanded = if let Some(rest) = path.strip_prefix("~/") {
        dirs::home_dir()
            .map(|h| h.join(rest))
            .unwrap_or_else(|| PathBuf::from(path))
    } else {
        PathBuf::from(path)
    };
    Ok(expanded)
}

/// Convert a single session's `transcript.jsonl` into a ShareGPT JSONL line.
fn build_sharegpt_line(
    folder: &Path,
    include_tool_calls: bool,
) -> Result<(String, usize), String> {
    let metadata_path = folder.join("session.json");
    let metadata_raw = fs::read_to_string(&metadata_path)
        .map_err(|e| format!("read session.json: {e}"))?;
    let metadata: Value =
        serde_json::from_str(&metadata_raw).map_err(|e| format!("parse session.json: {e}"))?;

    let transcript_path = folder.join("transcript.jsonl");
    let file = fs::File::open(&transcript_path)
        .map_err(|e| format!("open transcript.jsonl: {e}"))?;
    let reader = BufReader::new(file);

    let mut conversations: Vec<Value> = Vec::new();
    let mut turn_count = 0usize;
    for line in reader.lines() {
        let line = match line {
            Ok(l) => l,
            Err(e) => return Err(format!("read transcript line: {e}")),
        };
        if line.trim().is_empty() {
            continue;
        }
        let turn: TranscriptTurn = match serde_json::from_str(&line) {
            Ok(t) => t,
            Err(e) => {
                tracing::debug!("trajectory: skipping malformed turn: {e}");
                continue;
            }
        };
        let from = match turn.role.as_str() {
            "user" | "human" => "human",
            "assistant" | "gpt" | "ai" => "gpt",
            "system" => "system",
            "tool" | "tool_result" => "tool",
            _ => "other",
        };
        conversations.push(json!({
            "from": from,
            "value": turn.content,
        }));
        turn_count += 1;

        if include_tool_calls {
            for tc in &turn.tool_calls {
                conversations.push(json!({
                    "from": "tool_call",
                    "name": tc.name,
                    "tool_use_id": tc.tool_use_id,
                    "is_error": tc.is_error,
                    "input_summary": tc.input_summary,
                    "result_summary": tc.result_summary,
                }));
            }
        }
    }

    let line = json!({
        "id": metadata.get("id"),
        "model": metadata.get("model"),
        "provider": metadata.get("provider"),
        "started_at": metadata.get("started_at"),
        "ended_at": metadata.get("ended_at"),
        "status": metadata.get("status"),
        "tags": metadata.get("tags"),
        "token_count": metadata.get("token_count"),
        "conversations": conversations,
    })
    .to_string();
    Ok((line, turn_count))
}

pub fn trajectory_export_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "trajectory_export".to_string(),
        description: "Export past agent sessions as ShareGPT-format JSONL (one session per \
             line, with a `conversations` array of {from, value} turns). Use this to build \
             RL training datasets or fine-tuning corpora. Provide `session_id` to export a \
             single session or `limit` to cap the number of most-recent sessions. If \
             `output_path` is provided the result is written to disk (and the tool returns \
             a summary); otherwise the first 20 lines are returned inline."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "session_id": { "type": "string", "description": "Export only this session." },
                "limit": { "type": "integer", "description": "Max sessions (most-recent first)." },
                "output_path": { "type": "string", "description": "Write results to this file (~/ supported)." },
                "include_tool_calls": { "type": "boolean", "description": "Include tool_call records as extra conversation turns.", "default": true }
            }
        }),
    }
}

// ── Tests ──────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use tempfile::tempdir;

    fn fake_session(root: &Path, session_id: &str) {
        let folder = root
            .join("sessions")
            .join(format!("2026-04-10_{session_id}"));
        std::fs::create_dir_all(folder.join("artifacts")).unwrap();
        let metadata = json!({
            "id": session_id,
            "model": "claude-sonnet-4-6",
            "provider": "anthropic",
            "started_at": "2026-04-10T10:00:00Z",
            "ended_at": "2026-04-10T10:05:00Z",
            "tags": ["test"],
            "token_count": {"input": 100, "output": 200},
            "context_fill_pct": 0.25,
            "turn_count": 2,
            "status": "completed"
        });
        std::fs::write(
            folder.join("session.json"),
            serde_json::to_string(&metadata).unwrap(),
        )
        .unwrap();

        let lines = [
            json!({
                "timestamp": "2026-04-10T10:00:00Z",
                "role": "user",
                "content": "hello"
            }),
            json!({
                "timestamp": "2026-04-10T10:00:05Z",
                "role": "assistant",
                "content": "hi there",
                "tool_calls": [{
                    "name": "read_file",
                    "tool_use_id": "tu_1",
                    "input_summary": "{\"path\": \"/tmp/x\"}",
                    "result_summary": "ok",
                    "is_error": false
                }]
            }),
        ];
        let body: String = lines
            .iter()
            .map(|l| serde_json::to_string(l).unwrap())
            .collect::<Vec<_>>()
            .join("\n");
        std::fs::write(folder.join("transcript.jsonl"), body).unwrap();
    }

    #[tokio::test]
    async fn exports_a_single_session_inline() {
        let dir = tempdir().unwrap();
        fake_session(dir.path(), "abc12345");

        let handler = TrajectoryExportHandler::new(dir.path().to_path_buf());
        let result = handler
            .execute(&json!({ "session_id": "abc12345" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["mode"], json!("inline"));
        assert_eq!(parsed["sessions_exported"], json!(1));
        let lines = parsed["sharegpt_jsonl"].as_array().unwrap();
        assert_eq!(lines.len(), 1);
        let first: Value = serde_json::from_str(lines[0].as_str().unwrap()).unwrap();
        assert_eq!(first["id"], json!("abc12345"));
        let convs = first["conversations"].as_array().unwrap();
        assert!(convs.iter().any(|c| c["from"] == "human" && c["value"] == "hello"));
        assert!(convs.iter().any(|c| c["from"] == "gpt" && c["value"] == "hi there"));
        assert!(convs.iter().any(|c| c["from"] == "tool_call"));
    }

    #[tokio::test]
    async fn writes_to_output_path() {
        let dir = tempdir().unwrap();
        fake_session(dir.path(), "abc12345");
        let out = dir.path().join("out.jsonl");

        let handler = TrajectoryExportHandler::new(dir.path().to_path_buf());
        let _ = handler
            .execute(&json!({
                "session_id": "abc12345",
                "output_path": out.to_string_lossy()
            }))
            .await
            .unwrap();
        let body = std::fs::read_to_string(&out).unwrap();
        assert!(body.contains("\"conversations\""));
        assert!(body.contains("\"abc12345\""));
    }

    #[tokio::test]
    async fn errors_when_no_sessions_match() {
        let dir = tempdir().unwrap();
        let handler = TrajectoryExportHandler::new(dir.path().to_path_buf());
        let err = handler
            .execute(&json!({ "session_id": "nonexistent" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("no sessions"));
    }

    #[tokio::test]
    async fn exports_multiple_sessions_with_limit() {
        let dir = tempdir().unwrap();
        fake_session(dir.path(), "sess0001");
        fake_session(dir.path(), "sess0002");
        fake_session(dir.path(), "sess0003");

        let handler = TrajectoryExportHandler::new(dir.path().to_path_buf());
        let result = handler
            .execute(&json!({ "limit": 2 }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["sessions_exported"], json!(2));
    }
}
