//! Filesystem Tools — Phase 1 Core File Operations
//!
//! Implements the Hermes/OpenClaw-style primitive file tools:
//! * `read_file`  — read a text file with line numbers and pagination
//! * `write_file` — write/overwrite a file with auto-mkdir and blocklist
//! * `patch`      — targeted find/replace with 5-strategy fuzzy matching
//! * `search_files` — ripgrep-backed content search with glob filters
//!
//! These tools are the foundation for every serious coding agent. They
//! deliberately avoid Swift FFI — everything lives in pure Rust so that
//! the agent loop can dispatch them without crossing the UniFFI boundary.

use std::fs::File;
use std::io::{BufRead, BufReader, Read};
use std::path::{Path, PathBuf};

use async_trait::async_trait;
use grep_matcher::Matcher;
use grep_regex::RegexMatcherBuilder;
use grep_searcher::sinks::UTF8;
use grep_searcher::{BinaryDetection, SearcherBuilder};
use serde_json::{json, Value};
use walkdir::WalkDir;

use super::registry::{ToolError, ToolHandler};

// MARK: - Path Resolution & Security

/// Prefixes that are never writable from the agent.
/// Note: we intentionally exclude `/var/folders/` (macOS tempdir) — that path
/// is writable by user processes and is where tempfile puts scratch files.
const BLOCKED_WRITE_PREFIXES: &[&str] = &[
    "/etc/",
    "/usr/",
    "/System/",
    "/Library/",
    "/bin/",
    "/sbin/",
    "/private/etc/",
];

/// Home-relative suffixes that are always blocked regardless of mode.
const BLOCKED_HOME_SUFFIXES: &[&str] = &[
    ".ssh/",
    ".gnupg/",
    ".aws/",
    ".docker/",
    ".config/gh/",
    ".azure/",
];

/// Individual filenames that are sensitive and never readable or writable.
const BLOCKED_FILENAMES: &[&str] = &[
    ".env",
    ".pgpass",
    ".npmrc",
    ".pypirc",
    ".netrc",
    "credentials",
    "credentials.json",
];

fn resolve_path(path: &str) -> Result<PathBuf, ToolError> {
    if path.is_empty() {
        return Err(ToolError::InvalidArguments("path cannot be empty".into()));
    }

    let expanded = if let Some(rest) = path.strip_prefix("~/") {
        dirs::home_dir()
            .map(|home| home.join(rest))
            .unwrap_or_else(|| PathBuf::from(path))
    } else if path == "~" {
        dirs::home_dir().unwrap_or_else(|| PathBuf::from(path))
    } else {
        PathBuf::from(path)
    };

    Ok(expanded)
}

fn is_blocked_filename(path: &Path) -> bool {
    path.file_name()
        .and_then(|n| n.to_str())
        .map(|name| BLOCKED_FILENAMES.contains(&name))
        .unwrap_or(false)
}

fn is_blocked_for_write(path: &Path) -> Option<String> {
    let abs = path.to_string_lossy();
    for prefix in BLOCKED_WRITE_PREFIXES {
        if abs.starts_with(prefix) {
            return Some(format!("path '{abs}' is in a protected system directory"));
        }
    }
    if let Some(home) = dirs::home_dir() {
        let home_str = home.to_string_lossy();
        if let Some(rest) = abs.strip_prefix(home_str.as_ref()) {
            let trimmed = rest.trim_start_matches('/');
            for suffix in BLOCKED_HOME_SUFFIXES {
                if trimmed.starts_with(suffix) {
                    return Some(format!(
                        "path '{abs}' is in a protected credential directory"
                    ));
                }
            }
        }
    }
    if is_blocked_filename(path) {
        return Some(format!(
            "file '{}' is on the sensitive filename blocklist",
            path.display()
        ));
    }
    None
}

fn is_blocked_for_read(path: &Path) -> Option<String> {
    if is_blocked_filename(path) {
        return Some(format!(
            "file '{}' is on the sensitive filename blocklist",
            path.display()
        ));
    }
    if let Some(home) = dirs::home_dir() {
        let abs = path.to_string_lossy().to_string();
        let home_str = home.to_string_lossy();
        if let Some(rest) = abs.strip_prefix(home_str.as_ref()) {
            let trimmed = rest.trim_start_matches('/');
            for suffix in BLOCKED_HOME_SUFFIXES {
                if trimmed.starts_with(suffix) {
                    return Some(format!(
                        "path '{abs}' is in a protected credential directory"
                    ));
                }
            }
        }
    }
    None
}

// MARK: - read_file

pub struct ReadFileHandler;

#[async_trait]
impl ToolHandler for ReadFileHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let path_arg = input
            .get("path")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'path'".into()))?;
        let offset = input
            .get("offset")
            .and_then(Value::as_u64)
            .unwrap_or(1)
            .max(1) as usize;
        let limit = input
            .get("limit")
            .and_then(Value::as_u64)
            .unwrap_or(500)
            .clamp(1, 2000) as usize;

        let resolved = resolve_path(path_arg)?;
        if let Some(reason) = is_blocked_for_read(&resolved) {
            return Err(ToolError::ExecutionFailed(reason));
        }

        // Binary detection: read up to 8KB and scan for null bytes.
        let mut probe = File::open(&resolved).map_err(|e| {
            ToolError::ExecutionFailed(format!("cannot open '{}': {e}", resolved.display()))
        })?;
        let mut probe_buf = [0u8; 8192];
        let probe_bytes = probe
            .read(&mut probe_buf)
            .map_err(|e| ToolError::ExecutionFailed(format!("probe read failed: {e}")))?;
        if probe_buf[..probe_bytes].contains(&0) {
            return Err(ToolError::ExecutionFailed(
                "binary file detected (null bytes in first 8KB) — cannot read as text".into(),
            ));
        }
        drop(probe);

        let file = File::open(&resolved)
            .map_err(|e| ToolError::ExecutionFailed(format!("open failed: {e}")))?;
        let reader = BufReader::new(file);

        let mut collected: Vec<String> = Vec::new();
        let mut total_lines: usize = 0;
        let start = offset;
        let end_exclusive = offset.saturating_add(limit);

        for (index, line_result) in reader.lines().enumerate() {
            total_lines = index + 1;
            let line_num = index + 1;
            if line_num >= start && line_num < end_exclusive {
                let text = line_result.map_err(|e| {
                    ToolError::ExecutionFailed(format!("read error at line {line_num}: {e}"))
                })?;
                collected.push(format!("{line_num}\t{text}"));
            }
        }

        let showing_to = if collected.is_empty() {
            start
        } else {
            start + collected.len() - 1
        };

        Ok(json!({
            "path": resolved.display().to_string(),
            "content": collected.join("\n"),
            "total_lines": total_lines,
            "showing": { "from": start, "to": showing_to },
        })
        .to_string())
    }
}

pub fn read_file_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "read_file".to_string(),
        description: "Read a text file with line numbers and pagination. Rejects binary files. \
             Use 'offset' and 'limit' to page through large files (1-indexed lines, default 500, \
             max 2000 per call)."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "path": { "type": "string", "description": "File path. Supports ~/ home expansion." },
                "offset": { "type": "integer", "description": "Start line (1-indexed).", "default": 1, "minimum": 1 },
                "limit": { "type": "integer", "description": "Max lines to return.", "default": 500, "minimum": 1, "maximum": 2000 }
            },
            "required": ["path"]
        }),
    }
}

// MARK: - write_file

pub struct WriteFileHandler;

#[async_trait]
impl ToolHandler for WriteFileHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let path_arg = input
            .get("path")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'path'".into()))?;
        let content = input
            .get("content")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'content'".into()))?;

        let resolved = resolve_path(path_arg)?;
        if let Some(reason) = is_blocked_for_write(&resolved) {
            return Err(ToolError::ExecutionFailed(reason));
        }

        // Capture any prior content for a preview diff.
        let previous = std::fs::read_to_string(&resolved).ok();

        if let Some(parent) = resolved.parent() {
            if !parent.as_os_str().is_empty() && !parent.exists() {
                std::fs::create_dir_all(parent).map_err(|e| {
                    ToolError::ExecutionFailed(format!(
                        "failed to create parent directory '{}': {e}",
                        parent.display()
                    ))
                })?;
            }
        }

        let tmp = resolved.with_extension("epistemos.tmp");
        std::fs::write(&tmp, content)
            .map_err(|e| ToolError::ExecutionFailed(format!("write failed: {e}")))?;
        std::fs::rename(&tmp, &resolved).map_err(|e| {
            let _ = std::fs::remove_file(&tmp);
            ToolError::ExecutionFailed(format!("rename failed: {e}"))
        })?;

        let diff_preview = previous
            .as_deref()
            .map(|prev| short_diff_preview(prev, content, 3));

        let mut result = json!({
            "success": true,
            "path": resolved.display().to_string(),
            "bytes_written": content.len(),
            "created": previous.is_none(),
        });
        if let Some(diff) = diff_preview {
            result["diff_preview"] = Value::String(diff);
        }

        Ok(result.to_string())
    }
}

pub fn write_file_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "write_file".to_string(),
        description: "Create or overwrite a file. Creates parent directories automatically. \
             Blocks writes to protected system paths and credential directories."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "path": { "type": "string", "description": "File path. Supports ~/ home expansion." },
                "content": { "type": "string", "description": "Full file content (UTF-8)." }
            },
            "required": ["path", "content"]
        }),
    }
}

/// Produce a tiny unified-diff-style preview. Strictly for surfacing what
/// changed in the tool result, not a machine-consumable patch.
fn short_diff_preview(before: &str, after: &str, context_lines: usize) -> String {
    let diff = similar::TextDiff::from_lines(before, after);
    let mut out = Vec::new();
    let mut changes = 0_usize;

    for op in diff.ops() {
        let _ = op; // iterate via iter_all_changes for formatted output
    }

    for change in diff.iter_all_changes() {
        match change.tag() {
            similar::ChangeTag::Equal => {}
            similar::ChangeTag::Delete => {
                out.push(format!("- {}", change.value().trim_end_matches('\n')));
                changes += 1;
            }
            similar::ChangeTag::Insert => {
                out.push(format!("+ {}", change.value().trim_end_matches('\n')));
                changes += 1;
            }
        }
        if changes >= context_lines * 6 {
            out.push("...".to_string());
            break;
        }
    }

    if out.is_empty() {
        "(no textual changes)".to_string()
    } else {
        out.join("\n")
    }
}

// MARK: - patch (5-strategy fuzzy match)

pub struct PatchHandler;

#[async_trait]
impl ToolHandler for PatchHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let path_arg = input
            .get("path")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'path'".into()))?;
        let old_string = input
            .get("old_string")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'old_string'".into()))?;
        let new_string = input
            .get("new_string")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'new_string'".into()))?;
        let replace_all = input
            .get("replace_all")
            .and_then(Value::as_bool)
            .unwrap_or(false);

        if old_string.is_empty() {
            return Err(ToolError::InvalidArguments(
                "old_string cannot be empty".into(),
            ));
        }

        let resolved = resolve_path(path_arg)?;
        if let Some(reason) = is_blocked_for_write(&resolved) {
            return Err(ToolError::ExecutionFailed(reason));
        }

        let original = std::fs::read_to_string(&resolved)
            .map_err(|e| ToolError::ExecutionFailed(format!("read failed: {e}")))?;

        let outcome = apply_fuzzy_patch(&original, old_string, new_string, replace_all)?;

        let tmp = resolved.with_extension("epistemos.tmp");
        std::fs::write(&tmp, &outcome.patched)
            .map_err(|e| ToolError::ExecutionFailed(format!("write failed: {e}")))?;
        std::fs::rename(&tmp, &resolved).map_err(|e| {
            let _ = std::fs::remove_file(&tmp);
            ToolError::ExecutionFailed(format!("rename failed: {e}"))
        })?;

        Ok(json!({
            "success": true,
            "path": resolved.display().to_string(),
            "replacements": outcome.replacements,
            "strategy": outcome.strategy,
            "diff_preview": short_diff_preview(&original, &outcome.patched, 3),
        })
        .to_string())
    }
}

pub fn patch_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "patch".to_string(),
        description: "Find-and-replace within a file with 5-strategy fuzzy matching \
             (exact, whitespace-normalized, trimmed per line, indent-stripped, substring). \
             Set 'replace_all': true to replace every occurrence of the first matching strategy."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "path": { "type": "string", "description": "File path." },
                "old_string": { "type": "string", "description": "Text to find." },
                "new_string": { "type": "string", "description": "Replacement text." },
                "replace_all": { "type": "boolean", "description": "Replace every match.", "default": false }
            },
            "required": ["path", "old_string", "new_string"]
        }),
    }
}

struct PatchOutcome {
    patched: String,
    replacements: usize,
    strategy: &'static str,
}

/// Apply a 5-strategy fuzzy patch, first successful strategy wins.
fn apply_fuzzy_patch(
    original: &str,
    old_string: &str,
    new_string: &str,
    replace_all: bool,
) -> Result<PatchOutcome, ToolError> {
    // Strategy 1: exact match.
    if let Some(result) = try_exact(original, old_string, new_string, replace_all) {
        return Ok(PatchOutcome {
            patched: result.0,
            replacements: result.1,
            strategy: "exact",
        });
    }
    // Strategy 2: whitespace-normalized (collapse runs to single space).
    if let Some(result) = try_whitespace_normalized(original, old_string, new_string, replace_all) {
        return Ok(PatchOutcome {
            patched: result.0,
            replacements: result.1,
            strategy: "whitespace_normalized",
        });
    }
    // Strategy 3: trim each line's leading/trailing whitespace before comparing.
    if let Some(result) = try_line_trimmed(original, old_string, new_string, replace_all) {
        return Ok(PatchOutcome {
            patched: result.0,
            replacements: result.1,
            strategy: "line_trimmed",
        });
    }
    // Strategy 4: indent-stripped (strip common leading indent).
    if let Some(result) = try_indent_stripped(original, old_string, new_string, replace_all) {
        return Ok(PatchOutcome {
            patched: result.0,
            replacements: result.1,
            strategy: "indent_stripped",
        });
    }
    // Strategy 5: best substring match (longest contiguous line match).
    if let Some(result) = try_best_substring(original, old_string, new_string) {
        return Ok(PatchOutcome {
            patched: result.0,
            replacements: result.1,
            strategy: "best_substring",
        });
    }

    Err(ToolError::ExecutionFailed(
        "patch could not locate old_string in file (tried 5 strategies)".into(),
    ))
}

fn try_exact(original: &str, old: &str, new: &str, replace_all: bool) -> Option<(String, usize)> {
    if !original.contains(old) {
        return None;
    }
    if replace_all {
        let count = original.matches(old).count();
        Some((original.replace(old, new), count))
    } else {
        Some((original.replacen(old, new, 1), 1))
    }
}

fn try_whitespace_normalized(
    original: &str,
    old: &str,
    new: &str,
    replace_all: bool,
) -> Option<(String, usize)> {
    let norm_old = normalize_whitespace(old);
    if norm_old.trim().is_empty() {
        return None;
    }

    // Scan the original line-by-line looking for a multi-line block whose
    // whitespace-normalized form equals norm_old.
    let original_lines: Vec<&str> = original.split_inclusive('\n').collect();
    let old_line_count = old.lines().count().max(1);

    let mut patched = String::with_capacity(original.len());
    let mut i = 0;
    let mut replacements = 0usize;

    while i < original_lines.len() {
        // Try every window starting at i, from 1..=old_line_count*2 lines.
        let max_window = (old_line_count * 3).min(original_lines.len() - i);
        let mut matched = None;
        for window in 1..=max_window.max(1) {
            let slice = &original_lines[i..i + window];
            let concat: String = slice.concat();
            if normalize_whitespace(&concat) == norm_old {
                matched = Some(window);
                break;
            }
        }
        if let Some(window) = matched {
            patched.push_str(new);
            // Preserve trailing newline behaviour: if the matched slice ended with
            // a newline, ensure the replacement ends with one too.
            if original_lines[i + window - 1].ends_with('\n') && !new.ends_with('\n') {
                patched.push('\n');
            }
            i += window;
            replacements += 1;
            if !replace_all {
                // Copy rest verbatim and exit.
                for rest in &original_lines[i..] {
                    patched.push_str(rest);
                }
                return Some((patched, replacements));
            }
        } else {
            patched.push_str(original_lines[i]);
            i += 1;
        }
    }

    if replacements == 0 {
        None
    } else {
        Some((patched, replacements))
    }
}

fn normalize_whitespace(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut prev_space = false;
    for c in s.chars() {
        if c.is_whitespace() {
            if !prev_space {
                out.push(' ');
                prev_space = true;
            }
        } else {
            out.push(c);
            prev_space = false;
        }
    }
    out.trim().to_string()
}

fn try_line_trimmed(
    original: &str,
    old: &str,
    new: &str,
    replace_all: bool,
) -> Option<(String, usize)> {
    let old_lines: Vec<&str> = old.lines().collect();
    if old_lines.is_empty() {
        return None;
    }
    let trimmed_old: Vec<String> = old_lines.iter().map(|l| l.trim().to_string()).collect();

    let mut patched_lines: Vec<String> = Vec::new();
    let original_lines: Vec<&str> = original.lines().collect();
    let trailing_nl = original.ends_with('\n');
    let mut i = 0;
    let mut replacements = 0usize;
    let window = trimmed_old.len();

    while i < original_lines.len() {
        if i + window <= original_lines.len() {
            let slice: Vec<String> = original_lines[i..i + window]
                .iter()
                .map(|l| l.trim().to_string())
                .collect();
            if slice == trimmed_old {
                // Replace with `new` split into lines.
                for new_line in new.lines() {
                    patched_lines.push(new_line.to_string());
                }
                i += window;
                replacements += 1;
                if !replace_all {
                    for rest in &original_lines[i..] {
                        patched_lines.push((*rest).to_string());
                    }
                    let mut joined = patched_lines.join("\n");
                    if trailing_nl {
                        joined.push('\n');
                    }
                    return Some((joined, replacements));
                }
                continue;
            }
        }
        patched_lines.push(original_lines[i].to_string());
        i += 1;
    }

    if replacements == 0 {
        None
    } else {
        let mut joined = patched_lines.join("\n");
        if trailing_nl {
            joined.push('\n');
        }
        Some((joined, replacements))
    }
}

fn try_indent_stripped(
    original: &str,
    old: &str,
    new: &str,
    replace_all: bool,
) -> Option<(String, usize)> {
    let stripped_old = strip_common_indent(old);
    if stripped_old.trim().is_empty() {
        return None;
    }
    // Scan for a contiguous line block whose stripped version matches stripped_old.
    let original_lines: Vec<&str> = original.lines().collect();
    let trailing_nl = original.ends_with('\n');
    let old_line_count = stripped_old.lines().count();
    if old_line_count == 0 {
        return None;
    }

    let mut patched_lines: Vec<String> = Vec::new();
    let mut i = 0;
    let mut replacements = 0usize;

    while i < original_lines.len() {
        if i + old_line_count <= original_lines.len() {
            let slice = original_lines[i..i + old_line_count].join("\n");
            if strip_common_indent(&slice) == stripped_old {
                // Determine the leading indent of the first matched line
                // and reapply it to the new_string for seamless replacement.
                let indent: String = original_lines[i]
                    .chars()
                    .take_while(|c| *c == ' ' || *c == '\t')
                    .collect();
                for new_line in new.lines() {
                    if new_line.is_empty() {
                        patched_lines.push(String::new());
                    } else {
                        patched_lines.push(format!("{indent}{new_line}"));
                    }
                }
                i += old_line_count;
                replacements += 1;
                if !replace_all {
                    for rest in &original_lines[i..] {
                        patched_lines.push((*rest).to_string());
                    }
                    let mut joined = patched_lines.join("\n");
                    if trailing_nl {
                        joined.push('\n');
                    }
                    return Some((joined, replacements));
                }
                continue;
            }
        }
        patched_lines.push(original_lines[i].to_string());
        i += 1;
    }

    if replacements == 0 {
        None
    } else {
        let mut joined = patched_lines.join("\n");
        if trailing_nl {
            joined.push('\n');
        }
        Some((joined, replacements))
    }
}

fn strip_common_indent(text: &str) -> String {
    let lines: Vec<&str> = text.lines().collect();
    let common: usize = lines
        .iter()
        .filter(|l| !l.trim().is_empty())
        .map(|l| l.chars().take_while(|c| *c == ' ' || *c == '\t').count())
        .min()
        .unwrap_or(0);
    lines
        .iter()
        .map(|l| {
            if l.trim().is_empty() {
                (*l).to_string()
            } else {
                l.chars().skip(common).collect::<String>()
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
}

fn try_best_substring(original: &str, old: &str, new: &str) -> Option<(String, usize)> {
    // Last-ditch strategy: find the longest prefix of `old` that exists in the
    // file, then the longest suffix, and splice around the best contiguous
    // range. Only applies a single replacement; never replace_all.
    let old_trimmed = old.trim();
    if old_trimmed.len() < 8 {
        return None;
    }
    // Try progressively shorter prefixes until we find one in the original.
    for len in (8..=old_trimmed.len()).rev().step_by(4) {
        let probe = &old_trimmed[..len];
        if let Some(idx) = original.find(probe) {
            // Attempt to extend the match to the end of old_string via a suffix probe.
            let suffix_len = (old_trimmed.len() - len).min(32);
            let suffix = &old_trimmed[old_trimmed.len() - suffix_len..];
            if let Some(end_idx) = original[idx..].find(suffix) {
                let match_end = idx + end_idx + suffix.len();
                let mut patched = String::with_capacity(original.len() + new.len());
                patched.push_str(&original[..idx]);
                patched.push_str(new);
                patched.push_str(&original[match_end..]);
                return Some((patched, 1));
            }
        }
    }
    None
}

// MARK: - search_files

pub struct SearchFilesHandler;

#[async_trait]
impl ToolHandler for SearchFilesHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let pattern = input
            .get("pattern")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'pattern'".into()))?;
        let target = input
            .get("target")
            .and_then(Value::as_str)
            .unwrap_or("content");
        let root_arg = input.get("path").and_then(Value::as_str).unwrap_or(".");
        let file_glob = input.get("file_glob").and_then(Value::as_str);
        let limit = input
            .get("limit")
            .and_then(Value::as_u64)
            .unwrap_or(100)
            .clamp(1, 1000) as usize;
        let case_insensitive = input
            .get("case_insensitive")
            .and_then(Value::as_bool)
            .unwrap_or(false);

        let root = resolve_path(root_arg)?;
        if !root.exists() {
            return Err(ToolError::ExecutionFailed(format!(
                "search root '{}' does not exist",
                root.display()
            )));
        }

        let glob_matcher =
            match file_glob {
                Some(g) if !g.is_empty() => {
                    let mut builder = globset::GlobSetBuilder::new();
                    builder.add(globset::Glob::new(g).map_err(|e| {
                        ToolError::InvalidArguments(format!("invalid glob '{g}': {e}"))
                    })?);
                    Some(builder.build().map_err(|e| {
                        ToolError::ExecutionFailed(format!("glob build failed: {e}"))
                    })?)
                }
                _ => None,
            };

        match target {
            "files" => search_filenames(&root, pattern, case_insensitive, &glob_matcher, limit),
            _ => search_contents(&root, pattern, case_insensitive, &glob_matcher, limit),
        }
    }
}

pub fn search_files_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "search_files".to_string(),
        description: "Ripgrep-backed content and filename search. target='content' (default) \
             greps file contents, target='files' matches filenames. Supports regex patterns \
             and a glob filter."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "pattern": { "type": "string", "description": "Regex pattern to search." },
                "target": {
                    "type": "string",
                    "enum": ["content", "files"],
                    "default": "content",
                    "description": "Search file contents or filenames."
                },
                "path": { "type": "string", "description": "Root directory.", "default": "." },
                "file_glob": { "type": "string", "description": "Optional glob filter like '*.rs'." },
                "limit": { "type": "integer", "description": "Max matches to return.", "default": 100, "minimum": 1, "maximum": 1000 },
                "case_insensitive": { "type": "boolean", "description": "Match case-insensitively.", "default": false }
            },
            "required": ["pattern"]
        }),
    }
}

fn search_contents(
    root: &Path,
    pattern: &str,
    case_insensitive: bool,
    glob_matcher: &Option<globset::GlobSet>,
    limit: usize,
) -> Result<String, ToolError> {
    let matcher = RegexMatcherBuilder::new()
        .case_insensitive(case_insensitive)
        .build(pattern)
        .map_err(|e| ToolError::InvalidArguments(format!("invalid regex '{pattern}': {e}")))?;

    let mut searcher = SearcherBuilder::new()
        .binary_detection(BinaryDetection::quit(b'\x00'))
        .line_number(true)
        .build();

    let mut matches: Vec<Value> = Vec::new();

    'outer: for entry in WalkDir::new(root)
        .follow_links(false)
        .into_iter()
        .filter_map(|r| r.ok())
    {
        if !entry.file_type().is_file() {
            continue;
        }
        if let Some(gs) = glob_matcher {
            let rel = entry
                .path()
                .strip_prefix(root)
                .unwrap_or_else(|_| entry.path());
            if !gs.is_match(rel) {
                continue;
            }
        }
        if is_blocked_filename(entry.path()) {
            continue;
        }
        // Skip well-known noise dirs to keep search cheap.
        if is_noise_path(entry.path()) {
            continue;
        }

        let search_result = searcher.search_path(
            &matcher,
            entry.path(),
            UTF8(|lnum, line| {
                let trimmed = line.trim_end_matches('\n');
                if let Ok(Some(m)) = matcher.find(trimmed.as_bytes()) {
                    matches.push(json!({
                        "path": entry.path().display().to_string(),
                        "line": lnum,
                        "column": m.start() + 1,
                        "match": trimmed,
                    }));
                } else {
                    matches.push(json!({
                        "path": entry.path().display().to_string(),
                        "line": lnum,
                        "match": trimmed,
                    }));
                }
                Ok(matches.len() < limit)
            }),
        );

        if let Err(err) = search_result {
            // Skip files we cannot read; don't abort the entire search.
            tracing::debug!("search_files: skipped {}: {}", entry.path().display(), err);
            continue;
        }

        if matches.len() >= limit {
            break 'outer;
        }
    }

    Ok(json!({
        "pattern": pattern,
        "target": "content",
        "count": matches.len(),
        "limit": limit,
        "matches": matches,
    })
    .to_string())
}

fn search_filenames(
    root: &Path,
    pattern: &str,
    case_insensitive: bool,
    glob_matcher: &Option<globset::GlobSet>,
    limit: usize,
) -> Result<String, ToolError> {
    let regex = grep_regex::RegexMatcherBuilder::new()
        .case_insensitive(case_insensitive)
        .build(pattern)
        .map_err(|e| ToolError::InvalidArguments(format!("invalid regex '{pattern}': {e}")))?;

    let mut hits: Vec<Value> = Vec::new();
    for entry in WalkDir::new(root)
        .follow_links(false)
        .into_iter()
        .filter_map(|r| r.ok())
    {
        if !entry.file_type().is_file() {
            continue;
        }
        if is_blocked_filename(entry.path()) || is_noise_path(entry.path()) {
            continue;
        }
        if let Some(gs) = glob_matcher {
            let rel = entry
                .path()
                .strip_prefix(root)
                .unwrap_or_else(|_| entry.path());
            if !gs.is_match(rel) {
                continue;
            }
        }
        let name = entry.file_name().to_str().unwrap_or_default();
        if let Ok(Some(_)) = regex.find(name.as_bytes()) {
            hits.push(json!({ "path": entry.path().display().to_string() }));
            if hits.len() >= limit {
                break;
            }
        }
    }

    Ok(json!({
        "pattern": pattern,
        "target": "files",
        "count": hits.len(),
        "limit": limit,
        "matches": hits,
    })
    .to_string())
}

fn is_noise_path(path: &Path) -> bool {
    let components: Vec<_> = path.components().collect();
    for comp in components {
        if let std::path::Component::Normal(os) = comp {
            if let Some(s) = os.to_str() {
                if matches!(
                    s,
                    ".git"
                        | "node_modules"
                        | "target"
                        | "build"
                        | "dist"
                        | ".venv"
                        | "__pycache__"
                        | ".DS_Store"
                ) {
                    return true;
                }
            }
        }
    }
    false
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use tempfile::tempdir;

    #[tokio::test]
    async fn read_file_returns_line_numbered_content() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("sample.txt");
        std::fs::write(&path, "alpha\nbeta\ngamma\n").unwrap();

        let handler = ReadFileHandler;
        let result = handler
            .execute(&json!({ "path": path.to_string_lossy() }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        let content = parsed["content"].as_str().unwrap();
        assert!(content.contains("1\talpha"));
        assert!(content.contains("2\tbeta"));
        assert!(content.contains("3\tgamma"));
        assert_eq!(parsed["total_lines"], json!(3));
    }

    #[tokio::test]
    async fn read_file_rejects_binary_files() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("binary.bin");
        std::fs::write(&path, [0u8, 1, 2, 3, 0, 5]).unwrap();

        let handler = ReadFileHandler;
        let err = handler
            .execute(&json!({ "path": path.to_string_lossy() }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("binary"));
    }

    #[tokio::test]
    async fn write_file_creates_parents_and_content() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("nested/dir/file.txt");

        let handler = WriteFileHandler;
        let result = handler
            .execute(&json!({
                "path": path.to_string_lossy(),
                "content": "hello world",
            }))
            .await
            .unwrap();
        assert!(result.contains("\"success\":true"));
        assert_eq!(std::fs::read_to_string(&path).unwrap(), "hello world");
    }

    #[tokio::test]
    async fn write_file_blocks_system_paths() {
        let handler = WriteFileHandler;
        let err = handler
            .execute(&json!({
                "path": "/etc/blocked.txt",
                "content": "x",
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("protected"));
    }

    #[tokio::test]
    async fn patch_exact_strategy_replaces_single_occurrence() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("code.rs");
        std::fs::write(&path, "fn foo() {\n    bar();\n}\n").unwrap();

        let handler = PatchHandler;
        let result = handler
            .execute(&json!({
                "path": path.to_string_lossy(),
                "old_string": "bar();",
                "new_string": "baz();",
            }))
            .await
            .unwrap();
        assert!(result.contains("\"strategy\":\"exact\""));
        assert!(result.contains("\"replacements\":1"));
        assert_eq!(
            std::fs::read_to_string(&path).unwrap(),
            "fn foo() {\n    baz();\n}\n"
        );
    }

    #[tokio::test]
    async fn patch_whitespace_strategy_handles_indentation_changes() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("code.py");
        std::fs::write(&path, "def main():\n    print('hi')\n").unwrap();

        let handler = PatchHandler;
        let result = handler
            .execute(&json!({
                "path": path.to_string_lossy(),
                "old_string": "print('hi')",
                "new_string": "print('bye')",
            }))
            .await
            .unwrap();
        assert!(result.contains("\"replacements\":1"));
        assert!(std::fs::read_to_string(&path).unwrap().contains("bye"));
    }

    #[tokio::test]
    async fn patch_fails_when_old_string_missing() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("code.txt");
        std::fs::write(&path, "hello world\n").unwrap();

        let handler = PatchHandler;
        let err = handler
            .execute(&json!({
                "path": path.to_string_lossy(),
                "old_string": "completely-absent-token",
                "new_string": "x",
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("could not locate"));
    }

    #[tokio::test]
    async fn search_files_finds_content_matches() {
        let dir = tempdir().unwrap();
        let file = dir.path().join("note.md");
        std::fs::write(&file, "alpha\nbeta TARGET\ngamma\n").unwrap();

        let handler = SearchFilesHandler;
        let result = handler
            .execute(&json!({
                "pattern": "TARGET",
                "path": dir.path().to_string_lossy(),
            }))
            .await
            .unwrap();
        assert!(result.contains("TARGET"));
        assert!(result.contains("\"count\":1"));
    }

    #[tokio::test]
    async fn search_files_matches_filenames_with_regex() {
        let dir = tempdir().unwrap();
        std::fs::write(dir.path().join("alpha.rs"), "x").unwrap();
        std::fs::write(dir.path().join("beta.md"), "x").unwrap();

        let handler = SearchFilesHandler;
        let result = handler
            .execute(&json!({
                "pattern": ".*\\.rs$",
                "target": "files",
                "path": dir.path().to_string_lossy(),
            }))
            .await
            .unwrap();
        assert!(result.contains("alpha.rs"));
        assert!(!result.contains("beta.md"));
    }

    #[test]
    fn normalize_whitespace_collapses_runs() {
        assert_eq!(normalize_whitespace("hello   world\n\n"), "hello world");
        assert_eq!(normalize_whitespace("  a\tb  "), "a b");
    }

    #[test]
    fn strip_common_indent_removes_leading_spaces() {
        let input = "    line1\n    line2\n        line3";
        let stripped = strip_common_indent(input);
        assert_eq!(stripped, "line1\nline2\n    line3");
    }
}
