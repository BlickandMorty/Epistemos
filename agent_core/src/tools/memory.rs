//! Memory Tool — Persistent Curated Memory (Ported from Hermes Agent v0.7.0)
//!
//! Provides bounded, file-backed memory that persists across sessions. Two stores:
//! - MEMORY.md: agent's personal notes (environment facts, project conventions, things learned)
//! - USER.md: what the agent knows about the user (preferences, style, workflow habits)
//!
//! Design (from upstream Hermes):
//! - Single `memory` tool with action parameter: add, replace, remove, read
//! - replace/remove use short unique substring matching
//! - Frozen snapshot pattern: system prompt is stable, tool responses show live state
//! - Entry delimiter: § (section sign)
//! - Char limits: MEMORY.md = 2200, USER.md = 1375
//! - Injection/exfiltration scanning on all writes

use std::fs;
use std::path::PathBuf;

use fs2::FileExt;
use serde_json::{Value, json};

use super::registry::{ToolError, ToolHandler};

const ENTRY_DELIMITER: &str = "\n§\n";
const ENTRY_DELIMITER_CHARS: usize = 3;
const MEMORY_CHAR_LIMIT: usize = 2200;
const USER_CHAR_LIMIT: usize = 1375;
const MEMORY_FILE_BYTE_CAP: u64 = 64 * 1024;

// MARK: - Threat Scanning (ported from Hermes memory_tool.py)

/// Scans memory content for injection/exfiltration patterns before accepting writes.
fn scan_memory_content(content: &str) -> Option<String> {
    let lower = content.to_lowercase();

    // Invisible unicode injection
    let invisible_chars = [
        '\u{200b}', '\u{200c}', '\u{200d}', '\u{2060}', '\u{feff}', '\u{202a}', '\u{202b}',
        '\u{202c}', '\u{202d}', '\u{202e}',
    ];
    for ch in &invisible_chars {
        if content.contains(*ch) {
            return Some(format!(
                "Blocked: content contains invisible unicode character U+{:04X} (possible injection).",
                *ch as u32
            ));
        }
    }

    // Threat patterns
    let patterns: &[(&str, &str)] = &[
        ("ignore previous instructions", "prompt_injection"),
        ("ignore all instructions", "prompt_injection"),
        ("ignore above instructions", "prompt_injection"),
        ("you are now", "role_hijack"),
        ("do not tell the user", "deception_hide"),
        ("system prompt override", "sys_prompt_override"),
        ("disregard your instructions", "disregard_rules"),
        ("disregard all rules", "disregard_rules"),
        ("act as if you have no restrictions", "bypass_restrictions"),
        ("authorized_keys", "ssh_backdoor"),
    ];

    for (pattern, pid) in patterns {
        if lower.contains(pattern) {
            return Some(format!(
                "Blocked: content matches threat pattern '{}'. Memory entries must not contain injection payloads.",
                pid
            ));
        }
    }

    // Exfiltration patterns (curl/wget with secrets)
    if (lower.contains("curl") || lower.contains("wget"))
        && (lower.contains("key")
            || lower.contains("token")
            || lower.contains("secret")
            || lower.contains("password"))
    {
        return Some(
            "Blocked: content contains potential secret exfiltration command.".to_string(),
        );
    }

    None
}

// MARK: - Memory Store

pub struct MemoryStore {
    memory_dir: PathBuf,
    memory_entries: Vec<String>,
    user_entries: Vec<String>,
    /// Frozen snapshot for system prompt injection (set once at load time).
    system_prompt_snapshot: (String, String),
}

impl MemoryStore {
    pub fn new(memory_dir: PathBuf) -> Self {
        Self {
            memory_dir,
            memory_entries: Vec::new(),
            user_entries: Vec::new(),
            system_prompt_snapshot: (String::new(), String::new()),
        }
    }

    /// Load entries from disk and capture the frozen system prompt snapshot.
    pub fn load_from_disk(&mut self) {
        fs::create_dir_all(&self.memory_dir).ok();

        self.memory_entries = self.read_file("MEMORY.md");
        self.user_entries = self.read_file("USER.md");

        // Deduplicate (preserve order, keep first occurrence)
        dedup_preserve_order(&mut self.memory_entries);
        dedup_preserve_order(&mut self.user_entries);

        // Freeze snapshot for system prompt
        self.system_prompt_snapshot = (self.render_block("memory"), self.render_block("user"));
    }

    /// Returns the frozen system prompt text for injection.
    pub fn system_prompt_context(&self) -> String {
        let (memory, user) = &self.system_prompt_snapshot;
        let mut parts = Vec::new();
        if !memory.is_empty() {
            parts.push(format!("<agent-memory>\n{}\n</agent-memory>", memory));
        }
        if !user.is_empty() {
            parts.push(format!("<user-profile>\n{}\n</user-profile>", user));
        }
        parts.join("\n\n")
    }

    // MARK: - Operations

    pub fn add(&mut self, target: &str, content: &str) -> Value {
        let content = content.trim();
        if content.is_empty() {
            return json!({"success": false, "error": "Content cannot be empty."});
        }

        if let Some(err) = scan_memory_content(content) {
            return json!({"success": false, "error": err});
        }

        let limit = char_limit(target);
        let entries = self.entries(target);
        let current_len = entries_char_len(entries);
        let projected_len = projected_len_after_add(entries, content);

        if projected_len > limit {
            return json!({
                "success": false,
                "error": format!(
                    "Adding this entry ({} chars) would exceed the {} char limit. Current: {}.",
                    content.chars().count(), limit, current_len
                ),
            });
        }

        self.entries_mut(target).push(content.to_string());
        let count = self.entries(target).len();
        if let Err(error) = self.save_to_disk(target) {
            let _ = self.entries_mut(target).pop();
            return json!({"success": false, "error": format!("Failed to persist memory: {error}")});
        }

        json!({
            "success": true,
            "action": "add",
            "target": target,
            "entries_count": count,
            "chars_used": projected_len,
            "chars_limit": limit,
        })
    }

    pub fn replace(&mut self, target: &str, substring: &str, new_content: &str) -> Value {
        if substring.trim().is_empty() {
            return json!({"success": false, "error": "Substring cannot be empty."});
        }
        let new_content = new_content.trim();
        if new_content.is_empty() {
            return json!({"success": false, "error": "New content cannot be empty."});
        }

        if let Some(err) = scan_memory_content(new_content) {
            return json!({"success": false, "error": err});
        }

        let matches: Vec<usize> = self
            .entries(target)
            .iter()
            .enumerate()
            .filter(|(_, e)| e.contains(substring))
            .map(|(i, _)| i)
            .collect();

        match matches.len() {
            0 => json!({"success": false, "error": format!("No entry contains '{}'.", substring)}),
            1 => {
                let index = matches[0];
                let mut proposed = self.entries(target).to_vec();
                proposed[index] = new_content.to_string();
                let proposed_len = entries_char_len(&proposed);
                let limit = char_limit(target);
                if proposed_len > limit {
                    return json!({
                        "success": false,
                        "error": format!(
                            "Replacement would exceed the {} char limit. Proposed: {}.",
                            limit, proposed_len
                        ),
                    });
                }

                let old = std::mem::replace(
                    &mut self.entries_mut(target)[index],
                    new_content.to_string(),
                );
                if let Err(error) = self.save_to_disk(target) {
                    self.entries_mut(target)[index] = old;
                    return json!({"success": false, "error": format!("Failed to persist memory: {error}")});
                }
                json!({
                    "success": true,
                    "action": "replace",
                    "target": target,
                    "chars_used": proposed_len,
                    "chars_limit": limit,
                })
            }
            n => json!({
                "success": false,
                "error": format!("{} entries match '{}'. Use a more specific substring.", n, substring),
            }),
        }
    }

    pub fn remove(&mut self, target: &str, substring: &str) -> Value {
        if substring.trim().is_empty() {
            return json!({"success": false, "error": "Substring cannot be empty."});
        }
        let matches: Vec<usize> = self
            .entries(target)
            .iter()
            .enumerate()
            .filter(|(_, e)| e.contains(substring))
            .map(|(i, _)| i)
            .collect();

        match matches.len() {
            0 => json!({"success": false, "error": format!("No entry contains '{}'.", substring)}),
            1 => {
                let index = matches[0];
                let removed = self.entries_mut(target).remove(index);
                if let Err(error) = self.save_to_disk(target) {
                    self.entries_mut(target).insert(index, removed);
                    return json!({"success": false, "error": format!("Failed to persist memory: {error}")});
                }
                json!({"success": true, "action": "remove", "target": target})
            }
            n => json!({
                "success": false,
                "error": format!("{} entries match '{}'. Use a more specific substring.", n, substring),
            }),
        }
    }

    pub fn read(&self, target: &str) -> Value {
        let entries = self.entries(target);
        let limit = char_limit(target);
        let chars_used = entries_char_len(entries);

        json!({
            "target": target,
            "entries": entries,
            "entries_count": entries.len(),
            "chars_used": chars_used,
            "chars_limit": limit,
        })
    }

    // MARK: - File I/O

    fn read_file(&self, filename: &str) -> Vec<String> {
        let path = self.memory_dir.join(filename);
        if path
            .metadata()
            .map(|metadata| metadata.len() > MEMORY_FILE_BYTE_CAP)
            .unwrap_or(false)
        {
            tracing::warn!(
                target: "memory",
                "memory file {} exceeds byte cap; ignoring for safety",
                path.display()
            );
            return Vec::new();
        }
        let limit = if filename == "USER.md" {
            USER_CHAR_LIMIT
        } else {
            MEMORY_CHAR_LIMIT
        };
        let mut entries = Vec::new();
        match fs::read_to_string(&path) {
            Ok(content) => {
                for entry in content
                    .split(ENTRY_DELIMITER)
                    .map(|e| e.trim().to_string())
                    .filter(|e| !e.is_empty())
                {
                    let projected = projected_len_after_add(&entries, &entry);
                    if projected > limit {
                        tracing::warn!(
                            target: "memory",
                            "memory file {} exceeded char cap while loading; remaining entries ignored",
                            path.display()
                        );
                        break;
                    }
                    entries.push(entry);
                }
                entries
            }
            Err(_) => Vec::new(),
        }
    }

    fn save_to_disk(&self, target: &str) -> Result<(), String> {
        let filename = if target == "user" {
            "USER.md"
        } else {
            "MEMORY.md"
        };
        fs::create_dir_all(&self.memory_dir)
            .map_err(|error| format!("create memory dir {}: {error}", self.memory_dir.display()))?;
        let path = self.memory_dir.join(filename);
        let content = self.entries(target).join(ENTRY_DELIMITER);

        // Acquire an exclusive advisory lock on a sidecar lockfile so two
        // agent sessions writing to the same MEMORY.md cannot clobber each
        // other. fs2 returns an error on contention; we fall back to an
        // unlocked write after a short sleep to avoid hard-failing on macOS
        // quirks, logging the miss.
        let lockfile_path = path.with_extension("lock");
        let lock_file = std::fs::OpenOptions::new()
            .create(true)
            .truncate(false)
            .write(true)
            .read(true)
            .open(&lockfile_path);

        if let Ok(ref file) = lock_file {
            if let Err(e) = FileExt::lock_exclusive(file) {
                tracing::warn!(
                    target: "memory",
                    "failed to acquire memory lock for {}: {}",
                    path.display(),
                    e
                );
            }
        }

        // Atomic write via temp file + rename
        let tmp_path = path.with_extension("tmp");
        fs::write(&tmp_path, &content)
            .map_err(|error| format!("write memory temp {}: {error}", tmp_path.display()))?;
        fs::rename(&tmp_path, &path)
            .map_err(|error| format!("rename memory file {}: {error}", path.display()))?;

        if let Ok(file) = lock_file {
            let _ = FileExt::unlock(&file);
        }
        Ok(())
    }

    fn render_block(&self, target: &str) -> String {
        self.entries(target).join(ENTRY_DELIMITER)
    }

    fn entries(&self, target: &str) -> &[String] {
        if target == "user" {
            &self.user_entries
        } else {
            &self.memory_entries
        }
    }

    fn entries_mut(&mut self, target: &str) -> &mut Vec<String> {
        if target == "user" {
            &mut self.user_entries
        } else {
            &mut self.memory_entries
        }
    }
}

fn char_limit(target: &str) -> usize {
    if target == "user" {
        USER_CHAR_LIMIT
    } else {
        MEMORY_CHAR_LIMIT
    }
}

fn entries_char_len(entries: &[String]) -> usize {
    entries
        .iter()
        .map(|entry| entry.chars().count())
        .sum::<usize>()
        + entries.len().saturating_sub(1) * ENTRY_DELIMITER_CHARS
}

fn projected_len_after_add(entries: &[String], content: &str) -> usize {
    entries_char_len(entries)
        + usize::from(!entries.is_empty()) * ENTRY_DELIMITER_CHARS
        + content.chars().count()
}

fn dedup_preserve_order(entries: &mut Vec<String>) {
    let mut seen = std::collections::HashSet::new();
    entries.retain(|e| seen.insert(e.clone()));
}

// MARK: - Tool Handler

pub struct MemoryTool {
    store: std::sync::Mutex<MemoryStore>,
}

impl MemoryTool {
    pub fn new(memory_dir: PathBuf) -> Self {
        let mut store = MemoryStore::new(memory_dir);
        store.load_from_disk();
        Self {
            store: std::sync::Mutex::new(store),
        }
    }

    pub fn system_prompt_context(&self) -> String {
        self.store.lock().unwrap().system_prompt_context()
    }
}

#[async_trait::async_trait]
impl ToolHandler for MemoryTool {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = required_string_field(input, "action")?;
        let target = optional_string_field(input, "target")?.unwrap_or("memory");

        if !matches!(target, "memory" | "user") {
            return Err(ToolError::InvalidArguments(
                "target must be memory or user".into(),
            ));
        }
        if !matches!(action, "add" | "replace" | "remove" | "read") {
            return Err(ToolError::InvalidArguments(
                "action must be add, replace, remove, or read".into(),
            ));
        }

        let mut store = self
            .store
            .lock()
            .map_err(|e| ToolError::ExecutionFailed(format!("Memory lock poisoned: {e}")))?;

        let result = match action {
            "add" => store.add(target, required_string_field(input, "content")?),
            "replace" => store.replace(
                target,
                required_string_field(input, "substring")?,
                required_string_field(input, "content")?,
            ),
            "remove" => store.remove(target, required_string_field(input, "substring")?),
            "read" => store.read(target),
            _ => unreachable!("action was validated before dispatch"),
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

/// Returns the tool schema for registration in the tool registry.
pub fn memory_tool_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "memory".to_string(),
        description: "Persistent curated memory. Use to remember facts about the environment, project, or user across sessions. Actions: add (new entry), replace (update by substring match), remove (delete by substring match), read (list all entries). Targets: 'memory' (agent notes) or 'user' (user profile).".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["add", "replace", "remove", "read"],
                    "description": "The operation to perform."
                },
                "target": {
                    "type": "string",
                    "enum": ["memory", "user"],
                    "description": "Which memory store to operate on. 'memory' for agent notes, 'user' for user profile.",
                    "default": "memory"
                },
                "content": {
                    "type": "string",
                    "description": "The content to add or the new content for replace."
                },
                "substring": {
                    "type": "string",
                    "description": "A unique substring to identify the entry for replace/remove."
                }
            },
            "required": ["action"],
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[tokio::test]
    async fn memory_rejects_invalid_target_and_action() {
        let dir = tempfile::tempdir().unwrap();
        let tool = MemoryTool::new(dir.path().join("memory"));

        let err = tool
            .execute(&json!({ "action": "read", "target": "system" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("target must be"));

        let err = tool
            .execute(&json!({ "action": "rewrite", "target": "memory" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("action must be"));
    }

    #[tokio::test]
    async fn memory_rejects_missing_or_malformed_action_fields() {
        let dir = tempfile::tempdir().unwrap();
        let tool = MemoryTool::new(dir.path().join("memory"));

        let missing_action = tool.execute(&json!({})).await.unwrap_err();
        assert!(format!("{missing_action}").contains("action"));

        let malformed_target = tool
            .execute(&json!({ "action": "read", "target": 42 }))
            .await
            .unwrap_err();
        assert!(format!("{malformed_target}").contains("target"));

        let missing_content = tool
            .execute(&json!({ "action": "add", "target": "memory" }))
            .await
            .unwrap_err();
        assert!(format!("{missing_content}").contains("content"));

        let malformed_substring = tool
            .execute(&json!({
                "action": "remove",
                "target": "memory",
                "substring": false
            }))
            .await
            .unwrap_err();
        assert!(format!("{malformed_substring}").contains("substring"));
    }

    #[tokio::test]
    async fn memory_add_counts_chars_without_initial_delimiter() {
        let dir = tempfile::tempdir().unwrap();
        let tool = MemoryTool::new(dir.path().join("memory"));

        let output = tool
            .execute(&json!({
                "action": "add",
                "target": "memory",
                "content": "hello"
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&output).unwrap();
        assert_eq!(parsed["success"], json!(true));
        assert_eq!(parsed["chars_used"], json!(5));
    }

    #[tokio::test]
    async fn memory_rejects_empty_substrings_for_replace_and_remove() {
        let dir = tempfile::tempdir().unwrap();
        let tool = MemoryTool::new(dir.path().join("memory"));
        tool.execute(&json!({
            "action": "add",
            "target": "memory",
            "content": "anchor entry"
        }))
        .await
        .unwrap();

        let replace = tool
            .execute(&json!({
                "action": "replace",
                "target": "memory",
                "substring": "",
                "content": "new entry"
            }))
            .await
            .unwrap();
        assert_eq!(
            serde_json::from_str::<Value>(&replace).unwrap()["success"],
            json!(false)
        );

        let remove = tool
            .execute(&json!({
                "action": "remove",
                "target": "memory",
                "substring": ""
            }))
            .await
            .unwrap();
        assert_eq!(
            serde_json::from_str::<Value>(&remove).unwrap()["success"],
            json!(false)
        );
    }

    #[tokio::test]
    async fn memory_replace_enforces_store_char_limit() {
        let dir = tempfile::tempdir().unwrap();
        let tool = MemoryTool::new(dir.path().join("memory"));
        tool.execute(&json!({
            "action": "add",
            "target": "memory",
            "content": "anchor"
        }))
        .await
        .unwrap();

        let output = tool
            .execute(&json!({
                "action": "replace",
                "target": "memory",
                "substring": "anchor",
                "content": "x".repeat(MEMORY_CHAR_LIMIT + 1)
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&output).unwrap();
        assert_eq!(parsed["success"], json!(false));
        assert!(parsed["error"].as_str().unwrap().contains("char limit"));
    }

    #[test]
    fn memory_load_ignores_oversized_files() {
        let dir = tempfile::tempdir().unwrap();
        let memory_dir = dir.path().join("memory");
        std::fs::create_dir_all(&memory_dir).unwrap();
        std::fs::write(
            memory_dir.join("MEMORY.md"),
            "x".repeat(MEMORY_FILE_BYTE_CAP as usize + 1),
        )
        .unwrap();

        let mut store = MemoryStore::new(memory_dir);
        store.load_from_disk();
        assert!(store.entries("memory").is_empty());
    }
}
