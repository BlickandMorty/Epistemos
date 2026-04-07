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

use super::registry::ToolHandler;

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
}

// MARK: - Security

fn is_protected_path(path: &Path) -> bool {
    let path_str = path.to_string_lossy();
    for dir in PROTECTED_DIRS {
        if path_str.contains(dir) {
            return true;
        }
    }
    // Check for sensitive files
    let filename = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
    matches!(
        filename,
        ".env" | ".pgpass" | ".npmrc" | ".pypirc" | "credentials" | "credentials.json"
    )
}

fn validate_path(path_str: &str) -> Result<PathBuf, String> {
    if path_str.is_empty() {
        return Err("Path is required.".to_string());
    }

    let path = PathBuf::from(path_str);

    // Prevent path traversal
    if path.components().any(|c| matches!(c, std::path::Component::ParentDir)) {
        return Err("Path traversal ('..') is not allowed.".to_string());
    }

    if is_protected_path(&path) {
        return Err(format!(
            "Access denied: '{}' is in a protected directory.",
            path_str
        ));
    }

    Ok(path)
}

// MARK: - File Operations Tool

pub struct FileOpsTool {
    tracker: Mutex<FileReadTracker>,
}

impl FileOpsTool {
    pub fn new() -> Self {
        Self {
            tracker: Mutex::new(FileReadTracker::new()),
        }
    }

    fn read_file(&self, path_str: &str, start_line: Option<usize>, end_line: Option<usize>) -> Value {
        let path = match validate_path(path_str) {
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
            lines[start..end].join("\n")
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

    fn write_file(&self, path_str: &str, content: &str) -> Value {
        let path = match validate_path(path_str) {
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

        let path = match validate_path(path_str) {
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
        let path = match validate_path(path_str) {
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
    async fn execute(&self, input: &Value) -> Result<String, super::registry::ToolError> {
        let action = input["action"].as_str().unwrap_or("read");
        let path = input["path"].as_str().unwrap_or("");
        let content = input["content"].as_str().unwrap_or("");
        let find = input["find"].as_str().unwrap_or("");
        let replace = input["replace"].as_str().unwrap_or("");
        let start_line = input["start_line"].as_u64().map(|n| n as usize);
        let end_line = input["end_line"].as_u64().map(|n| n as usize);

        let result = match action {
            "read" => self.read_file(path, start_line, end_line),
            "write" => self.write_file(path, content),
            "patch" => self.patch_file(path, find, replace),
            "list" => self.list_dir(path),
            _ => json!({"success": false, "error": format!("Unknown action: {action}")}),
        };

        Ok(serde_json::to_string_pretty(&result).unwrap_or_default())
    }
}

/// Returns the tool schema for registration.
pub fn file_ops_tool_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "file".to_string(),
        description: "Read, write, and patch files on the filesystem. Actions: read (with optional line range), write (create/overwrite), patch (find-and-replace), list (directory contents). Warns about stale files modified externally since last read.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["read", "write", "patch", "list"],
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
