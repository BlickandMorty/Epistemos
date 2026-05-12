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
//! serialised lines inline. Because `output_path` writes files, registration
//! must stay Agent-tier and outside MAS/Core builds.

use std::fs::{self, File};
use std::io::{BufRead, BufReader, BufWriter, Write};
use std::path::{Component, Path, PathBuf};

use async_trait::async_trait;
use serde_json::{json, Value};

use super::registry::{ToolError, ToolHandler};
use crate::storage::session_store::{list_session_folders, SessionFolderInfo, TranscriptTurn};

const INLINE_SESSION_CAP: usize = 20;
const MAX_INLINE_JSONL_BYTES: usize = 512 * 1024;

const BLOCKED_WRITE_PREFIXES: &[&str] = &[
    "/etc/",
    "/usr/",
    "/System/",
    "/Library/",
    "/bin/",
    "/sbin/",
    "/private/etc/",
];

const BLOCKED_HOME_SUFFIXES: &[&str] = &[
    ".ssh/",
    ".gnupg/",
    ".aws/",
    ".docker/",
    ".config/gh/",
    ".azure/",
];

const BLOCKED_FILENAMES: &[&str] = &[
    ".env",
    ".pgpass",
    ".npmrc",
    ".pypirc",
    ".netrc",
    "credentials",
    "credentials.json",
];

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
            return Err(ToolError::NotFound("no sessions matched the filter".into()));
        }

        let resolved_output = match output_path {
            Some(path) => Some(resolve_output_path(path)?),
            None => None,
        };

        let mut writer = match &resolved_output {
            Some(resolved) => {
                if let Some(parent) = resolved.parent() {
                    fs::create_dir_all(parent).map_err(|e| {
                        ToolError::ExecutionFailed(format!("mkdir {}: {e}", parent.display()))
                    })?;
                }
                Some(BufWriter::new(File::create(resolved).map_err(|e| {
                    ToolError::ExecutionFailed(format!("create {}: {e}", resolved.display()))
                })?))
            }
            None => None,
        };

        let mut inline_lines: Vec<String> =
            Vec::with_capacity(INLINE_SESSION_CAP.min(candidates.len()));
        let mut inline_bytes = 0usize;
        let mut sessions_exported = 0usize;
        let mut total_turns = 0usize;
        let mut skipped_sessions = 0usize;
        let mut processed_sessions = 0usize;
        let mut truncated = false;
        for info in &candidates {
            processed_sessions += 1;
            let folder_path = PathBuf::from(&info.folder_path);
            match build_sharegpt_line(&folder_path, include_tool_calls) {
                Ok((line, turns)) => {
                    if let Some(file_writer) = writer.as_mut() {
                        file_writer.write_all(line.as_bytes()).map_err(|e| {
                            ToolError::ExecutionFailed(format!("write trajectory line: {e}"))
                        })?;
                        file_writer.write_all(b"\n").map_err(|e| {
                            ToolError::ExecutionFailed(format!("write trajectory newline: {e}"))
                        })?;
                        sessions_exported += 1;
                        total_turns += turns;
                    } else if push_inline_line(&mut inline_lines, line, &mut inline_bytes) {
                        sessions_exported += 1;
                        total_turns += turns;
                    } else {
                        truncated = true;
                        break;
                    }
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

        if let (Some(file_writer), Some(resolved)) = (writer.as_mut(), resolved_output.as_ref()) {
            file_writer.flush().map_err(|e| {
                ToolError::ExecutionFailed(format!("flush {}: {e}", resolved.display()))
            })?;
            Ok(json!({
                "success": true,
                "mode": "file",
                "path": resolved.display().to_string(),
                "sessions_exported": sessions_exported,
                "sessions_skipped": skipped_sessions,
                "total_turns": total_turns,
            })
            .to_string())
        } else {
            // Inline mode keeps both session count and byte size bounded.
            // Callers that want more should pass output_path and read the
            // file via read_file.
            let sessions_omitted = candidates
                .len()
                .saturating_sub(sessions_exported + skipped_sessions);
            truncated |= sessions_omitted > 0;
            Ok(json!({
                "success": true,
                "mode": "inline",
                "sessions_exported": sessions_exported,
                "sessions_skipped": skipped_sessions,
                "sessions_omitted": sessions_omitted,
                "sessions_processed": processed_sessions,
                "total_turns": total_turns,
                "truncated": truncated,
                "inline_byte_limit": MAX_INLINE_JSONL_BYTES,
                "inline_bytes": inline_bytes,
                "sharegpt_jsonl": inline_lines,
            })
            .to_string())
        }
    }
}

fn resolve_output_path(path: &str) -> Result<PathBuf, ToolError> {
    if path.is_empty() {
        return Err(ToolError::InvalidArguments("output_path is empty".into()));
    }
    if path.trim() != path {
        return Err(ToolError::InvalidArguments(
            "output_path must not contain leading or trailing whitespace".into(),
        ));
    }

    let expanded = if let Some(rest) = path.strip_prefix("~/") {
        dirs::home_dir()
            .map(|h| h.join(rest))
            .unwrap_or_else(|| PathBuf::from(path))
    } else if path == "~" {
        dirs::home_dir().unwrap_or_else(|| PathBuf::from(path))
    } else {
        PathBuf::from(path)
    };
    let normalized = normalize_path_lexically(&expanded);

    if !normalized.is_absolute() {
        return Err(ToolError::InvalidArguments(
            "output_path must be absolute or start with ~/".into(),
        ));
    }
    if normalized.file_name().is_none() || normalized.is_dir() {
        return Err(ToolError::InvalidArguments(
            "output_path must name a file".into(),
        ));
    }
    if let Some(reason) = blocked_output_path_reason(&normalized) {
        return Err(ToolError::InvalidArguments(format!(
            "output_path is blocked: {reason}"
        )));
    }
    Ok(normalized)
}

fn normalize_path_lexically(path: &Path) -> PathBuf {
    let mut normalized = PathBuf::new();
    let absolute = path.has_root();

    for component in path.components() {
        match component {
            Component::Prefix(prefix) => normalized.push(prefix.as_os_str()),
            Component::RootDir => normalized.push(component.as_os_str()),
            Component::CurDir => {}
            Component::ParentDir => {
                if !normalized.pop() && !absolute {
                    normalized.push("..");
                }
            }
            Component::Normal(part) => normalized.push(part),
        }
    }

    if normalized.as_os_str().is_empty() {
        if absolute {
            PathBuf::from(std::path::MAIN_SEPARATOR.to_string())
        } else {
            PathBuf::from(".")
        }
    } else {
        normalized
    }
}

fn blocked_output_path_reason(path: &Path) -> Option<String> {
    if let Some(reason) = blocked_write_reason(path) {
        return Some(reason);
    }
    if path.exists() {
        if let Ok(canonical) = fs::canonicalize(path) {
            if canonical != path {
                if let Some(reason) = blocked_write_reason(&canonical) {
                    return Some(format!(
                        "resolved target '{}' is blocked: {reason}",
                        canonical.display()
                    ));
                }
            }
        }
    }
    if let Some(parent) = path.parent() {
        if let Some(existing_parent) = nearest_existing_ancestor(parent) {
            if let Ok(canonical_parent) = fs::canonicalize(&existing_parent) {
                if canonical_parent != existing_parent {
                    if let Some(reason) = blocked_write_reason(&canonical_parent) {
                        return Some(format!(
                            "resolved parent '{}' is blocked: {reason}",
                            canonical_parent.display()
                        ));
                    }
                }
            }
        }
    }
    None
}

fn blocked_write_reason(path: &Path) -> Option<String> {
    let abs = path.to_string_lossy();
    for prefix in BLOCKED_WRITE_PREFIXES {
        let exact = prefix.trim_end_matches('/');
        if abs == exact || abs.starts_with(prefix) {
            return Some(format!("path '{abs}' is in a protected system directory"));
        }
    }
    if let Some(home) = dirs::home_dir() {
        let home_str = home.to_string_lossy();
        if let Some(rest) = abs.strip_prefix(home_str.as_ref()) {
            let trimmed = rest.trim_start_matches('/');
            if BLOCKED_HOME_SUFFIXES.iter().any(|suffix| {
                let exact = suffix.trim_end_matches('/');
                trimmed == exact || trimmed.starts_with(suffix)
            }) {
                return Some(format!(
                    "path '{abs}' is in a protected credential directory"
                ));
            }
        }
    }
    if path
        .file_name()
        .and_then(|name| name.to_str())
        .map(|name| BLOCKED_FILENAMES.contains(&name))
        .unwrap_or(false)
    {
        return Some(format!(
            "file '{}' is on the sensitive filename blocklist",
            path.display()
        ));
    }
    None
}

fn nearest_existing_ancestor(path: &Path) -> Option<PathBuf> {
    let mut current = Some(path);
    while let Some(candidate) = current {
        if candidate.exists() {
            return Some(candidate.to_path_buf());
        }
        current = candidate.parent();
    }
    None
}

fn push_inline_line(lines: &mut Vec<String>, line: String, total_bytes: &mut usize) -> bool {
    if lines.len() >= INLINE_SESSION_CAP {
        return false;
    }
    let separator = usize::from(!lines.is_empty());
    let projected = total_bytes
        .saturating_add(separator)
        .saturating_add(line.len());
    if projected > MAX_INLINE_JSONL_BYTES {
        return false;
    }
    *total_bytes = projected;
    lines.push(line);
    true
}

/// Convert a single session's `transcript.jsonl` into a ShareGPT JSONL line.
fn build_sharegpt_line(folder: &Path, include_tool_calls: bool) -> Result<(String, usize), String> {
    let metadata_path = folder.join("session.json");
    let metadata_raw =
        fs::read_to_string(&metadata_path).map_err(|e| format!("read session.json: {e}"))?;
    let metadata: Value =
        serde_json::from_str(&metadata_raw).map_err(|e| format!("parse session.json: {e}"))?;

    let transcript_path = folder.join("transcript.jsonl");
    let file =
        fs::File::open(&transcript_path).map_err(|e| format!("open transcript.jsonl: {e}"))?;
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
             `output_path` is provided it must be absolute or ~/ and the result is written \
             to disk (with protected credential/system paths blocked); otherwise a bounded \
             inline sample is returned."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "session_id": { "type": "string", "description": "Export only this session." },
                "limit": { "type": "integer", "description": "Max sessions (most-recent first)." },
                "output_path": { "type": "string", "description": "Write results to an absolute file path (~/ supported; protected system and credential paths are blocked)." },
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
        assert!(convs
            .iter()
            .any(|c| c["from"] == "human" && c["value"] == "hello"));
        assert!(convs
            .iter()
            .any(|c| c["from"] == "gpt" && c["value"] == "hi there"));
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
    async fn rejects_relative_output_path() {
        let dir = tempdir().unwrap();
        fake_session(dir.path(), "abc12345");

        let handler = TrajectoryExportHandler::new(dir.path().to_path_buf());
        let err = handler
            .execute(&json!({
                "session_id": "abc12345",
                "output_path": "out.jsonl"
            }))
            .await
            .unwrap_err();

        assert!(format!("{err}").contains("absolute"));
    }

    #[tokio::test]
    async fn rejects_protected_output_path() {
        let dir = tempdir().unwrap();
        fake_session(dir.path(), "abc12345");

        let handler = TrajectoryExportHandler::new(dir.path().to_path_buf());
        let err = handler
            .execute(&json!({
                "session_id": "abc12345",
                "output_path": "/etc/epistemos-trajectory.jsonl"
            }))
            .await
            .unwrap_err();

        assert!(format!("{err}").contains("protected system directory"));
    }

    #[cfg(unix)]
    #[tokio::test]
    async fn rejects_symlink_output_to_sensitive_filename() {
        let dir = tempdir().unwrap();
        fake_session(dir.path(), "abc12345");

        let sensitive = dir.path().join(".env");
        std::fs::write(&sensitive, "SECRET=1").unwrap();
        let link = dir.path().join("trajectory.jsonl");
        std::os::unix::fs::symlink(&sensitive, &link).unwrap();

        let handler = TrajectoryExportHandler::new(dir.path().to_path_buf());
        let err = handler
            .execute(&json!({
                "session_id": "abc12345",
                "output_path": link.to_string_lossy()
            }))
            .await
            .unwrap_err();

        assert!(format!("{err}").contains("resolved target"));
    }

    #[test]
    fn inline_selection_respects_session_and_byte_caps() {
        let mut lines = Vec::new();
        let mut bytes = 0usize;
        for index in 0..INLINE_SESSION_CAP {
            assert!(push_inline_line(
                &mut lines,
                format!("line-{index}"),
                &mut bytes
            ));
        }
        assert!(!push_inline_line(
            &mut lines,
            "overflow".to_string(),
            &mut bytes
        ));
        assert_eq!(lines.len(), INLINE_SESSION_CAP);

        let mut huge_lines = Vec::new();
        let mut huge_bytes = 0usize;
        assert!(!push_inline_line(
            &mut huge_lines,
            "x".repeat(MAX_INLINE_JSONL_BYTES + 1),
            &mut huge_bytes
        ));
        assert!(huge_lines.is_empty());
        assert_eq!(huge_bytes, 0);
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
        let result = handler.execute(&json!({ "limit": 2 })).await.unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["sessions_exported"], json!(2));
    }
}
