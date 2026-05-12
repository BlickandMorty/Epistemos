//! File Operations Tool — General-Purpose File Read/Write/Patch
//!
//! Closes the gap with Goose's Developer extension by providing
//! file operations for arbitrary filesystem paths (not just vault notes).
//!
//! Operations:
//! - read: Read file contents (with optional line range)
//! - write: Create or overwrite a file
//! - patch: Find-and-replace within a file (with stale file detection)
//! - list: List directory contents
//!
//! Security: Path traversal prevention, sensitive directory protection,
//! stale file detection (warn when file modified since last read).

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::time::SystemTime;

use serde_json::{json, Value};

use super::registry::{ToolError, ToolHandler};

// Directories protected from read/write (from Hermes v0.7.0 security hardening)
const PROTECTED_DIRS: &[&str] = &[
    ".ssh",
    ".gnupg",
    ".docker",
    ".azure",
    ".config/gh",
    ".aws",
    ".netrc",
];
const PROTECTED_WRITE_PREFIXES: &[&str] = &[
    "/etc/",
    "/usr/",
    "/System/",
    "/Library/",
    "/bin/",
    "/sbin/",
    "/private/etc/",
];

#[derive(Clone, Copy)]
enum PathMode {
    Read,
    Write,
}

// MARK: - Stale File Detection

/// Tracks file modification times to warn about external changes.
struct FileReadTracker {
    /// Maps filepath → last-read modification time
    read_times: HashMap<PathBuf, SystemTime>,
}

impl FileReadTracker {
    fn new() -> Self {
        Self {
            read_times: HashMap::new(),
        }
    }

    fn record_read(&mut self, path: &Path) {
        if let Ok(metadata) = fs::metadata(path) {
            if let Ok(modified) = metadata.modified() {
                self.read_times.insert(path.to_path_buf(), modified);
            }
        }
    }

    /// Returns true if the file was modified since we last read it.
    fn is_stale(&self, path: &Path) -> bool {
        if let Some(last_read) = self.read_times.get(path) {
            if let Ok(metadata) = fs::metadata(path) {
                if let Ok(modified) = metadata.modified() {
                    return modified > *last_read;
                }
            }
        }
        false
    }

    /// Drop the read-time entry for a path. Used after delete so a
    /// subsequent create-at-same-path doesn't false-positive the
    /// stale-file warning.
    fn forget(&mut self, path: &Path) {
        self.read_times.remove(path);
    }
}

// MARK: - Security

fn has_protected_component(path: &Path) -> bool {
    path.components().any(|component| {
        component
            .as_os_str()
            .to_str()
            .is_some_and(|part| PROTECTED_DIRS.contains(&part))
    })
}

fn is_sensitive_filename(path: &Path) -> bool {
    let filename = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
    matches!(
        filename,
        ".env" | ".pgpass" | ".npmrc" | ".pypirc" | "credentials" | "credentials.json"
    )
}

fn is_protected_path(path: &Path) -> bool {
    has_protected_component(path) || is_sensitive_filename(path)
}

fn is_protected_write_path(path: &Path) -> bool {
    let path_str = path.to_string_lossy();
    for prefix in PROTECTED_WRITE_PREFIXES {
        let exact = prefix.trim_end_matches('/');
        if path_str == exact || path_str.starts_with(prefix) {
            return true;
        }
    }
    is_protected_path(path)
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

fn validate_path(path_str: &str, mode: PathMode) -> Result<PathBuf, String> {
    if path_str.is_empty() {
        return Err("Path is required.".to_string());
    }

    let path = PathBuf::from(path_str);

    // Prevent path traversal
    if path
        .components()
        .any(|c| matches!(c, std::path::Component::ParentDir))
    {
        return Err("Path traversal ('..') is not allowed.".to_string());
    }

    let protected = match mode {
        PathMode::Read => is_protected_path(&path),
        PathMode::Write => is_protected_write_path(&path),
    };
    if protected {
        return Err(format!(
            "Access denied: '{}' is in a protected directory.",
            path_str
        ));
    }

    if path.exists() {
        if let Ok(canonical) = fs::canonicalize(&path) {
            let canonical_protected = match mode {
                PathMode::Read => is_protected_path(&canonical),
                PathMode::Write => {
                    is_protected_path(&canonical) || is_protected_write_path(&canonical)
                }
            };
            if canonical != path && canonical_protected {
                return Err(format!(
                    "Access denied: '{}' resolves to protected target '{}'.",
                    path_str,
                    canonical.display()
                ));
            }
        }
    }

    if matches!(mode, PathMode::Write) {
        if let Some(parent) = path.parent() {
            if let Some(existing_parent) = nearest_existing_ancestor(parent) {
                if let Ok(canonical_parent) = fs::canonicalize(&existing_parent) {
                    if canonical_parent != existing_parent
                        && is_protected_write_path(&canonical_parent)
                    {
                        return Err(format!(
                            "Access denied: '{}' resolves through protected parent '{}'.",
                            path_str,
                            canonical_parent.display()
                        ));
                    }
                }
            }
        }
    }

    Ok(path)
}

// MARK: - File Operations Tool

pub struct FileOpsTool {
    tracker: Mutex<FileReadTracker>,
}

impl Default for FileOpsTool {
    fn default() -> Self {
        Self::new()
    }
}

impl FileOpsTool {
    pub fn new() -> Self {
        Self {
            tracker: Mutex::new(FileReadTracker::new()),
        }
    }

    fn read_file(
        &self,
        path_str: &str,
        start_line: Option<usize>,
        end_line: Option<usize>,
    ) -> Value {
        let path = match validate_path(path_str, PathMode::Read) {
            Ok(p) => p,
            Err(e) => return json!({"success": false, "error": e}),
        };

        let content = match fs::read_to_string(&path) {
            Ok(c) => c,
            Err(e) => return json!({"success": false, "error": format!("Failed to read: {e}")}),
        };

        // Record read time for stale detection
        if let Ok(mut tracker) = self.tracker.lock() {
            tracker.record_read(&path);
        }

        // Apply line range if specified
        let output = if start_line.is_some() || end_line.is_some() {
            let lines: Vec<&str> = content.lines().collect();
            let start = start_line.unwrap_or(1).saturating_sub(1);
            let end = end_line.unwrap_or(lines.len()).min(lines.len());
            if start >= lines.len() {
                String::new()
            } else {
                lines[start..end].join("\n")
            }
        } else {
            content.clone()
        };

        let line_count = content.lines().count();

        json!({
            "success": true,
            "path": path_str,
            "content": output,
            "lines": line_count,
        })
    }

    /// Per user 2026-05-11: chats need to be able to delete notes.
    /// `delete` uses the same Write-path validation (rejects
    /// /etc, /System, etc.) plus an explicit existence check so
    /// the agent gets a clean error instead of a "no such file"
    /// log. After delete, the tracker entry is dropped so a
    /// subsequent write to the same path doesn't trigger the
    /// stale-file warning.
    fn delete_file(&self, path_str: &str) -> Value {
        let path = match validate_path(path_str, PathMode::Write) {
            Ok(p) => p,
            Err(e) => return json!({"success": false, "error": e}),
        };
        if !path.exists() {
            return json!({"success": false, "error": format!("file not found: {path_str}")});
        }
        match fs::remove_file(&path) {
            Ok(()) => {
                if let Ok(mut tracker) = self.tracker.lock() {
                    tracker.forget(&path);
                }
                json!({"success": true, "path": path_str, "action": "delete"})
            }
            Err(e) => json!({"success": false, "error": format!("Failed to delete: {e}")}),
        }
    }

    fn write_file(&self, path_str: &str, content: &str) -> Value {
        let path = match validate_path(path_str, PathMode::Write) {
            Ok(p) => p,
            Err(e) => return json!({"success": false, "error": e}),
        };

        // Stale detection: warn if file was modified since last read
        let stale_warning = if let Ok(tracker) = self.tracker.lock() {
            if tracker.is_stale(&path) {
                Some("Warning: file was modified externally since your last read.")
            } else {
                None
            }
        } else {
            None
        };

        // Create parent directories
        if let Some(parent) = path.parent() {
            if !parent.exists() {
                if let Err(e) = fs::create_dir_all(parent) {
                    return json!({"success": false, "error": format!("Failed to create directories: {e}")});
                }
            }
        }

        // Atomic write
        let tmp_path = path.with_extension("tmp");
        if let Err(e) = fs::write(&tmp_path, content) {
            return json!({"success": false, "error": format!("Failed to write: {e}")});
        }
        if let Err(e) = fs::rename(&tmp_path, &path) {
            let _ = fs::remove_file(&tmp_path);
            return json!({"success": false, "error": format!("Failed to finalize write: {e}")});
        }

        // Update tracker
        if let Ok(mut tracker) = self.tracker.lock() {
            tracker.record_read(&path);
        }

        let mut result = json!({
            "success": true,
            "path": path_str,
            "bytes_written": content.len(),
        });
        if let Some(warning) = stale_warning {
            result["warning"] = json!(warning);
        }
        result
    }

    fn patch_file(&self, path_str: &str, find: &str, replace: &str) -> Value {
        if find.is_empty() {
            return json!({"success": false, "error": "Find string cannot be empty."});
        }

        let path = match validate_path(path_str, PathMode::Write) {
            Ok(p) => p,
            Err(e) => return json!({"success": false, "error": e}),
        };

        let content = match fs::read_to_string(&path) {
            Ok(c) => c,
            Err(e) => return json!({"success": false, "error": format!("Failed to read: {e}")}),
        };

        // Stale detection
        let stale_warning = if let Ok(tracker) = self.tracker.lock() {
            if tracker.is_stale(&path) {
                Some("Warning: file was modified externally since your last read.")
            } else {
                None
            }
        } else {
            None
        };

        let count = content.matches(find).count();
        if count == 0 {
            return json!({"success": false, "error": format!("'{}' not found in file.", find)});
        }

        let patched = content.replace(find, replace);

        // Atomic write
        let tmp_path = path.with_extension("tmp");
        if let Err(e) = fs::write(&tmp_path, &patched) {
            return json!({"success": false, "error": format!("Failed to write: {e}")});
        }
        if let Err(e) = fs::rename(&tmp_path, &path) {
            let _ = fs::remove_file(&tmp_path);
            return json!({"success": false, "error": format!("Failed to finalize: {e}")});
        }

        if let Ok(mut tracker) = self.tracker.lock() {
            tracker.record_read(&path);
        }

        let mut result = json!({
            "success": true,
            "path": path_str,
            "replacements": count,
        });
        if let Some(warning) = stale_warning {
            result["warning"] = json!(warning);
        }
        result
    }

    fn list_dir(&self, path_str: &str) -> Value {
        let path = match validate_path(path_str, PathMode::Read) {
            Ok(p) => p,
            Err(e) => return json!({"success": false, "error": e}),
        };

        let entries = match fs::read_dir(&path) {
            Ok(e) => e,
            Err(e) => return json!({"success": false, "error": format!("Failed to list: {e}")}),
        };

        let mut files = Vec::new();
        let mut dirs = Vec::new();

        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if entry.path().is_dir() {
                dirs.push(name);
            } else {
                files.push(name);
            }
        }

        dirs.sort();
        files.sort();

        json!({
            "success": true,
            "path": path_str,
            "directories": dirs,
            "files": files,
            "total": dirs.len() + files.len(),
        })
    }
}

#[async_trait::async_trait]
impl ToolHandler for FileOpsTool {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = required_string_field(input, "action")?;
        let path = required_string_field(input, "path")?;
        let (start_line, end_line) = parse_line_range(input)?;

        let result = match action {
            "read" => self.read_file(path, start_line, end_line),
            "write" => self.write_file(path, required_string_field(input, "content")?),
            "patch" => self.patch_file(
                path,
                required_string_field(input, "find")?,
                optional_string_field(input, "replace")?.unwrap_or(""),
            ),
            "list" => self.list_dir(path),
            "delete" => self.delete_file(path),
            _ => {
                return Err(ToolError::InvalidArguments(format!(
                    "unknown action '{action}' (expected: read|write|patch|list|delete)"
                )));
            }
        };

        Ok(serde_json::to_string(&result).unwrap_or_default())
    }
}

fn required_string_field<'a>(input: &'a Value, field: &str) -> Result<&'a str, ToolError> {
    input
        .get(field)
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments(format!("'{field}' must be a string")))
}

fn optional_string_field<'a>(input: &'a Value, field: &str) -> Result<Option<&'a str>, ToolError> {
    let Some(value) = input.get(field) else {
        return Ok(None);
    };
    value
        .as_str()
        .map(Some)
        .ok_or_else(|| ToolError::InvalidArguments(format!("'{field}' must be a string")))
}

fn optional_line_field(input: &Value, field: &str) -> Result<Option<usize>, ToolError> {
    let Some(value) = input.get(field) else {
        return Ok(None);
    };
    let Some(line) = value.as_u64() else {
        return Err(ToolError::InvalidArguments(format!(
            "'{field}' must be an integer"
        )));
    };
    if line == 0 {
        return Err(ToolError::InvalidArguments(format!(
            "'{field}' must be 1 or greater"
        )));
    }
    usize::try_from(line).map(Some).map_err(|_| {
        ToolError::InvalidArguments(format!("'{field}' is too large for this platform"))
    })
}

fn parse_line_range(input: &Value) -> Result<(Option<usize>, Option<usize>), ToolError> {
    let start = optional_line_field(input, "start_line")?;
    let end = optional_line_field(input, "end_line")?;
    if let (Some(start), Some(end)) = (start, end) {
        if end < start {
            return Err(ToolError::InvalidArguments(
                "'end_line' must be greater than or equal to 'start_line'".into(),
            ));
        }
    }
    Ok((start, end))
}

/// Returns the tool schema for registration.
pub fn file_ops_tool_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "file_ops".to_string(),
        description: "Read, write, patch, list, and delete files on the filesystem. Actions: read (with optional line range), write (create/overwrite), patch (find-and-replace), list (directory contents), delete (remove file). Warns about stale files modified externally since last read.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["read", "write", "patch", "list", "delete"],
                    "description": "The operation to perform."
                },
                "path": {
                    "type": "string",
                    "description": "File or directory path."
                },
                "content": {
                    "type": "string",
                    "description": "Content to write (for write action)."
                },
                "find": {
                    "type": "string",
                    "description": "Text to find (for patch action)."
                },
                "replace": {
                    "type": "string",
                    "description": "Replacement text (for patch action)."
                },
                "start_line": {
                    "type": "integer",
                    "description": "Start line for partial read (1-indexed)."
                },
                "end_line": {
                    "type": "integer",
                    "description": "End line for partial read (1-indexed, inclusive)."
                }
            },
            "required": ["action", "path"],
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use tempfile::tempdir;

    #[test]
    fn validate_path_blocks_system_writes() {
        let err = validate_path("/etc/epistemos-test", PathMode::Write).unwrap_err();
        assert!(err.contains("Access denied"));
    }

    #[cfg(unix)]
    #[test]
    fn validate_path_blocks_symlink_to_sensitive_file() {
        let dir = tempdir().unwrap();
        let target = dir.path().join(".env");
        let link = dir.path().join("safe-link");
        fs::write(&target, "SECRET=1").unwrap();
        std::os::unix::fs::symlink(&target, &link).unwrap();

        let err = validate_path(link.to_str().unwrap(), PathMode::Read).unwrap_err();
        assert!(err.contains("protected target"));
    }

    #[tokio::test]
    async fn file_ops_rejects_missing_malformed_and_unknown_actions() {
        let tool = FileOpsTool::new();

        let missing_action = tool.execute(&json!({ "path": "a.txt" })).await.unwrap_err();
        assert!(format!("{missing_action}").contains("action"));

        let missing_path = tool
            .execute(&json!({ "action": "read" }))
            .await
            .unwrap_err();
        assert!(format!("{missing_path}").contains("path"));

        let unknown = tool
            .execute(&json!({ "action": "rename", "path": "a.txt" }))
            .await
            .unwrap_err();
        assert!(format!("{unknown}").contains("unknown action"));
    }

    /// Per user 2026-05-11: confirm `delete` writes are real.
    /// Creates a file in TMPDIR, deletes it via file_ops, verifies
    /// the file is gone + that a subsequent delete of the same path
    /// returns success=false with a "file not found" message.
    #[tokio::test]
    async fn file_ops_delete_removes_file_then_reports_not_found() {
        use std::env;
        use std::fs;
        let tool = FileOpsTool::new();
        let dir = env::temp_dir().join(format!("epistemos-fileops-delete-{}", std::process::id()));
        fs::create_dir_all(&dir).unwrap();
        let target = dir.join("note.md");
        fs::write(&target, b"# Test note\n").unwrap();

        let first = tool
            .execute(&json!({ "action": "delete", "path": target.to_string_lossy() }))
            .await
            .expect("delete should not error");
        let parsed: serde_json::Value = serde_json::from_str(&first).unwrap();
        assert_eq!(parsed["success"], json!(true));
        assert!(!target.exists());

        let second = tool
            .execute(&json!({ "action": "delete", "path": target.to_string_lossy() }))
            .await
            .expect("delete should not error on missing file");
        let parsed: serde_json::Value = serde_json::from_str(&second).unwrap();
        assert_eq!(parsed["success"], json!(false));
        assert!(parsed["error"].as_str().unwrap().contains("not found"));

        let _ = fs::remove_dir_all(&dir);
    }

    #[tokio::test]
    async fn file_ops_rejects_malformed_action_specific_fields() {
        let tool = FileOpsTool::new();

        let missing_content = tool
            .execute(&json!({ "action": "write", "path": "a.txt" }))
            .await
            .unwrap_err();
        assert!(format!("{missing_content}").contains("content"));

        let missing_find = tool
            .execute(&json!({ "action": "patch", "path": "a.txt", "replace": "" }))
            .await
            .unwrap_err();
        assert!(format!("{missing_find}").contains("find"));

        let malformed_replace = tool
            .execute(&json!({
                "action": "patch",
                "path": "a.txt",
                "find": "old",
                "replace": 5
            }))
            .await
            .unwrap_err();
        assert!(format!("{malformed_replace}").contains("replace"));
    }

    #[tokio::test]
    async fn file_ops_rejects_malformed_line_ranges() {
        let tool = FileOpsTool::new();

        let non_integer = tool
            .execute(&json!({
                "action": "read",
                "path": "a.txt",
                "start_line": "1"
            }))
            .await
            .unwrap_err();
        assert!(format!("{non_integer}").contains("start_line"));

        let zero_line = tool
            .execute(&json!({
                "action": "read",
                "path": "a.txt",
                "start_line": 0
            }))
            .await
            .unwrap_err();
        assert!(format!("{zero_line}").contains("start_line"));

        let inverted = tool
            .execute(&json!({
                "action": "read",
                "path": "a.txt",
                "start_line": 5,
                "end_line": 2
            }))
            .await
            .unwrap_err();
        assert!(format!("{inverted}").contains("end_line"));
    }

    #[tokio::test]
    async fn file_ops_read_range_past_end_returns_empty_without_panic() {
        let dir = tempdir().unwrap();
        let file = dir.path().join("note.md");
        fs::write(&file, "one\ntwo\n").unwrap();

        let tool = FileOpsTool::new();
        let output = tool
            .execute(&json!({
                "action": "read",
                "path": file.to_string_lossy(),
                "start_line": 99
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&output).unwrap();
        assert_eq!(parsed["success"], json!(true));
        assert_eq!(parsed["content"], json!(""));
    }

    #[cfg(unix)]
    #[tokio::test]
    async fn file_ops_write_blocks_existing_symlink_to_sensitive_file() {
        let dir = tempdir().unwrap();
        let target = dir.path().join(".env");
        let link = dir.path().join("safe-write-link");
        fs::write(&target, "SECRET=old").unwrap();
        std::os::unix::fs::symlink(&target, &link).unwrap();

        let tool = FileOpsTool::new();
        let output = tool
            .execute(&json!({
                "action": "write",
                "path": link.to_string_lossy(),
                "content": "SECRET=new",
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&output).unwrap();
        assert_eq!(parsed["success"], json!(false));
        assert!(parsed["error"]
            .as_str()
            .unwrap()
            .contains("protected target"));
        assert_eq!(fs::read_to_string(&target).unwrap(), "SECRET=old");
    }
}
