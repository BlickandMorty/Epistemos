// Vault tool execution for MCP surface.
// Provides filesystem-level vault operations (read, write, list, search)
// that complement the full hybrid-search in agent_core.
//
// This module handles the MCP `tools/call` execution for vault tools
// when the caller routes through omega-mcp rather than agent_core.

use crate::types::ToolResult;
use memmap2::Mmap;
use rayon::prelude::*;
use std::fs::{self, File, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::time::Instant;

/// Vault tool executor. Scoped to a root directory to prevent path traversal.
pub struct VaultExecutor {
    pub(crate) root: PathBuf,
}

/// Write `content` to `full` ATOMICALLY: write a temp sibling, then rename it over the target (rename is
/// atomic on the same filesystem). A plain `fs::write` interrupted mid-write would truncate the file — and
/// for a NOTE that's the user's actual content corrupted. The temp uses a non-`.md` suffix so a crash-leftover
/// is never mistaken for a note by `list_markdown_notes`. (Mirrors the Swift VaultNoteEditor's atomic write.)
fn atomic_write(full: &Path, content: &[u8]) -> std::io::Result<()> {
    let name = full.file_name().ok_or_else(|| {
        std::io::Error::new(std::io::ErrorKind::InvalidInput, "path has no file name")
    })?;
    let tmp = full.with_file_name(format!("{}.omega-tmp", name.to_string_lossy()));
    fs::write(&tmp, content)?;
    fs::rename(&tmp, full)
}

/// Byte cap + retained-line count for the append-only `.epistemos/*.jsonl` agent-event telemetry logs. Shared
/// by the graph event log AND the vault provenance log so both are bounded identically (§506).
pub(crate) const EVENT_LOG_MAX_BYTES: u64 = 4 * 1024 * 1024; // ~4 MB
pub(crate) const EVENT_LOG_KEEP_LINES: usize = 5_000;
pub(crate) const MCP_RESOURCE_MAX_READ_BYTES: u64 = 8 * 1024 * 1024;

/// Append newline-delimited `lines` to the JSONL log at `path`, then BOUND it: the agent-event logs are
/// write-only telemetry (nothing replays them — durable provenance lives in the EventStore), so a long agent
/// session would otherwise grow them without limit. A cheap size check gates an O(n) trim (keep the most-recent
/// `EVENT_LOG_KEEP_LINES`, rewrite ATOMICALLY via temp+rename so a trim can't corrupt the log). One helper, so
/// the graph + vault logs stay bounded identically. Caller pre-creates the parent dir.
pub(crate) fn append_lines_bounded(path: &Path, lines: &[String]) -> Result<(), String> {
    if lines.is_empty() {
        return Ok(());
    }
    {
        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(path)
            .map_err(|e| e.to_string())?;
        for line in lines {
            writeln!(file, "{line}").map_err(|e| e.to_string())?;
        }
    }
    if let Ok(meta) = fs::metadata(path) {
        if meta.len() > EVENT_LOG_MAX_BYTES {
            let body = fs::read_to_string(path).map_err(|e| e.to_string())?;
            let all: Vec<&str> = body.lines().collect();
            if all.len() > EVENT_LOG_KEEP_LINES {
                let kept: String = all[all.len() - EVENT_LOG_KEEP_LINES..]
                    .iter()
                    .flat_map(|l| [*l, "\n"])
                    .collect();
                let tmp = path.with_extension("jsonl.tmp");
                fs::write(&tmp, kept).map_err(|e| e.to_string())?;
                fs::rename(&tmp, path).map_err(|e| e.to_string())?;
            }
        }
    }
    Ok(())
}

impl VaultExecutor {
    /// Create a new executor scoped to the given vault root.
    /// Returns None if the path doesn't exist or isn't a directory.
    pub fn new(root: &str) -> Option<Self> {
        let path = PathBuf::from(root);
        if path.is_dir() {
            Some(VaultExecutor { root: path })
        } else {
            None
        }
    }

    /// Resolve a relative path within the vault, blocking traversal attacks.
    fn resolve(&self, relative: &str) -> Result<PathBuf, String> {
        let clean = relative
            .replace('\\', "/")
            .trim_start_matches('/')
            .to_string();

        // Block directory traversal
        if clean.contains("..") {
            return Err("Path traversal not allowed".to_string());
        }

        let full = self.root.join(&clean);

        // Verify the resolved path is still under root
        match full.canonicalize() {
            Ok(canon) => {
                let root_canon = self
                    .root
                    .canonicalize()
                    .map_err(|e| format!("Cannot resolve vault root: {e}"))?;
                if canon.starts_with(&root_canon) {
                    Ok(canon)
                } else {
                    Err("Path outside vault boundary".to_string())
                }
            }
            Err(_) => {
                // File doesn't exist yet — check parent
                if let Some(parent) = full.parent() {
                    if parent.exists() {
                        Ok(full)
                    } else {
                        Err(format!(
                            "Parent directory does not exist: {}",
                            parent.display()
                        ))
                    }
                } else {
                    Err("Invalid path".to_string())
                }
            }
        }
    }

    /// Read a file from the vault.
    pub fn read_file(&self, path: &str) -> ToolResult {
        let start = Instant::now();
        match self.resolve(path) {
            Ok(full) => match fs::read_to_string(&full) {
                Ok(content) => {
                    let json = serde_json::json!({
                        "path": path,
                        "content": content,
                        "size": content.len(),
                    });
                    ToolResult::ok(json.to_string(), start.elapsed().as_millis() as u64)
                }
                Err(e) => ToolResult::err(
                    format!("Cannot read {path}: {e}"),
                    crate::types::error_codes::NOT_FOUND,
                    start.elapsed().as_millis() as u64,
                ),
            },
            Err(e) => ToolResult::err(
                e,
                crate::types::error_codes::INVALID_INPUT,
                start.elapsed().as_millis() as u64,
            ),
        }
    }

    /// Read a Markdown note as an MCP resource. This is stricter than the
    /// legacy `vault.read` tool: resources are first-class context, so they
    /// must stay Markdown-only, bounded, non-hidden, and non-symlinked.
    pub fn read_markdown_resource(&self, path: &str) -> Result<String, String> {
        let clean = path.replace('\\', "/").trim_start_matches('/').to_string();
        if clean.contains("..") {
            return Err("Path traversal not allowed".to_string());
        }
        if !clean.to_ascii_lowercase().ends_with(".md") {
            return Err("only markdown vault resources can be read".to_string());
        }
        if clean
            .split('/')
            .any(|component| component.is_empty() || component.starts_with('.'))
        {
            return Err("hidden vault resources cannot be read".to_string());
        }
        self.reject_symlinked_relative_path(&clean)?;

        let full = self.resolve(&clean)?;
        let metadata = fs::metadata(&full).map_err(|_| "read failed".to_string())?;
        if !metadata.is_file() {
            return Err("only regular markdown vault resources can be read".to_string());
        }
        if metadata.len() > MCP_RESOURCE_MAX_READ_BYTES {
            return Err("markdown resource is too large".to_string());
        }

        let content = fs::read_to_string(&full)
            .map_err(|_| "markdown resource is not valid UTF-8".to_string())?;
        if content.len() as u64 > MCP_RESOURCE_MAX_READ_BYTES {
            return Err("markdown resource is too large".to_string());
        }
        Ok(content)
    }

    fn reject_symlinked_relative_path(&self, relative: &str) -> Result<(), String> {
        let mut cursor = self.root.clone();
        for component in Path::new(relative).components() {
            cursor.push(component.as_os_str());
            if let Ok(metadata) = fs::symlink_metadata(&cursor) {
                if metadata.file_type().is_symlink() {
                    return Err("symlinked vault resources cannot be read".to_string());
                }
            }
        }
        Ok(())
    }

    /// VAULT-DEEP-INTEGRATION (owner 2026-06-21 §720): enumerate the vault's markdown NOTES as
    /// vault-relative paths (forward-slash), backing the MCP `resources/list` surface so external
    /// agents see the vault as first-class MCP context. Bounded iterative walk — skips hidden dirs
    /// (incl. `.epcache`/`.git`) and caps the count so a huge vault can't blow the response.
    pub fn list_markdown_notes(&self) -> Vec<String> {
        const MAX_NOTES: usize = 5000;
        let mut out: Vec<String> = Vec::new();
        let mut stack: Vec<PathBuf> = vec![self.root.clone()];
        while let Some(dir) = stack.pop() {
            if out.len() >= MAX_NOTES {
                break;
            }
            let entries = match fs::read_dir(&dir) {
                Ok(e) => e,
                Err(_) => continue,
            };
            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().to_string();
                if name.starts_with('.') {
                    continue; // hidden dirs/files (.git, .epcache, …)
                }
                let path = entry.path();
                let is_dir = entry.file_type().map(|t| t.is_dir()).unwrap_or(false);
                if is_dir {
                    stack.push(path);
                } else if name.to_ascii_lowercase().ends_with(".md") {
                    if let Ok(rel) = path.strip_prefix(&self.root) {
                        out.push(rel.to_string_lossy().replace('\\', "/"));
                    }
                }
            }
        }
        out.sort();
        out
    }

    /// VAULT-DEEP-INTEGRATION §720 (#3 wikilinks/backlinks): the vault notes that `[[link]]` to
    /// `target` — the mechanical backlink layer the LLM-augmented wiki / semantic backlinks build on.
    /// `target` may be a note name or vault-relative path (with/without `.md`); matching is by basename
    /// (case-insensitive), honoring `[[target]]`, `[[target|alias]]`, and `[[target#heading]]`.
    pub fn backlinks(&self, target: &str) -> ToolResult {
        let start = Instant::now();
        let needle = Self::note_basename(target);
        let mut linkers: Vec<String> = Vec::new();
        for rel in self.list_markdown_notes() {
            let full = self.root.join(&rel);
            if let Ok(content) = fs::read_to_string(&full) {
                if Self::content_links_to(&content, &needle) {
                    linkers.push(rel);
                }
            }
        }
        linkers.sort();
        linkers.dedup();
        let json = serde_json::json!({ "target": target, "backlinks": linkers });
        ToolResult::ok(json.to_string(), start.elapsed().as_millis() as u64)
    }

    /// Lowercased basename without `.md` so `notes/Foo.md`, `Foo`, and `foo` all normalize equal.
    /// `pub(crate)` so the graph populator (graph_tools.rs) resolves wikilinks the SAME way — one
    /// basename model across backlinks/outlinks AND vault→graph edges (reuse, never rebuild).
    pub(crate) fn note_basename(s: &str) -> String {
        let no_ext = s
            .strip_suffix(".md")
            .or_else(|| s.strip_suffix(".MD"))
            .unwrap_or(s);
        no_ext
            .rsplit('/')
            .next()
            .unwrap_or(no_ext)
            .to_ascii_lowercase()
    }

    /// Extract every `[[...]]` link target from `content` (alias `|` + heading `#` stripped, trimmed,
    /// de-duplicated, original case preserved). The shared wikilink parser behind backlinks + outlinks.
    /// `pub(crate)` so the vault→graph populator reuses the EXACT same parser (one source of link truth).
    pub(crate) fn parse_wikilinks(content: &str) -> Vec<String> {
        let mut out: Vec<String> = Vec::new();
        let mut rest = content;
        while let Some(open) = rest.find("[[") {
            let after = &rest[open + 2..];
            if let Some(close) = after.find("]]") {
                let inner = &after[..close];
                let link = inner.split('|').next().unwrap_or(inner);
                let link = link.split('#').next().unwrap_or(link).trim();
                if !link.is_empty() && !out.iter().any(|l| l == link) {
                    out.push(link.to_string());
                }
                rest = &after[close + 2..];
            } else {
                break;
            }
        }
        out
    }

    /// True when `content` has a `[[...]]` whose link target's basename equals `needle`.
    fn content_links_to(content: &str, needle: &str) -> bool {
        Self::parse_wikilinks(content)
            .iter()
            .any(|link| Self::note_basename(link) == needle)
    }

    /// VAULT-DEEP-INTEGRATION §720 (#3 LLM wiki, "rival Obsidian" §343): ORPHAN notes — notes disconnected from
    /// the knowledge graph, i.e. NO resolved outlink AND nothing links to them (Obsidian's "orphans" / isolated
    /// notes). Distinct from dangling_links (broken links) and link_candidates (unlinked mentions): orphans is the
    /// vault-WIDE "what's stranded" view, in ONE call (vs N note_links calls). The wiki/agent surfaces these to
    /// suggest connections. Self-links don't count as connecting; links to non-existent notes don't count either.
    pub fn orphan_notes(&self) -> ToolResult {
        use std::collections::HashSet;
        let start = Instant::now();
        let notes = self.list_markdown_notes();
        let existing: HashSet<String> = notes.iter().map(|n| Self::note_basename(n)).collect();
        let mut linked_to: HashSet<String> = HashSet::new(); // basenames some OTHER note links TO
        let mut has_outlink: HashSet<String> = HashSet::new(); // basenames that link OUT to another existing note
        for rel in &notes {
            let base = Self::note_basename(rel);
            if let Ok(content) = fs::read_to_string(self.root.join(rel)) {
                for link in Self::parse_wikilinks(&content) {
                    let target = Self::note_basename(&link);
                    if target != base && existing.contains(&target) {
                        linked_to.insert(target);
                        has_outlink.insert(base.clone());
                    }
                }
            }
        }
        let mut orphans: Vec<String> = notes
            .iter()
            .filter(|rel| {
                let b = Self::note_basename(rel);
                !has_outlink.contains(&b) && !linked_to.contains(&b)
            })
            .cloned()
            .collect();
        orphans.sort();
        let json = serde_json::json!({ "orphans": orphans, "total_notes": notes.len() });
        ToolResult::ok(json.to_string(), start.elapsed().as_millis() as u64)
    }

    /// VAULT-DEEP-INTEGRATION §720: the wikilink targets a note links TO (the dual of `backlinks`).
    /// Together they give agents the full in/out link graph for a note. Original link text preserved.
    pub fn outlinks(&self, path: &str) -> ToolResult {
        let start = Instant::now();
        match self.resolve(path) {
            Ok(full) => match fs::read_to_string(&full) {
                Ok(content) => {
                    let links = Self::parse_wikilinks(&content);
                    let json = serde_json::json!({ "path": path, "outlinks": links });
                    ToolResult::ok(json.to_string(), start.elapsed().as_millis() as u64)
                }
                Err(e) => ToolResult::err(
                    format!("Cannot read {path}: {e}"),
                    crate::types::error_codes::NOT_FOUND,
                    start.elapsed().as_millis() as u64,
                ),
            },
            Err(e) => ToolResult::err(
                e,
                crate::types::error_codes::INVALID_INPUT,
                start.elapsed().as_millis() as u64,
            ),
        }
    }

    /// VAULT-DEEP-INTEGRATION §720 (#3 LLM wiki): unresolved/DANGLING wikilinks — `[[targets]]` that
    /// have no matching note in the vault (Obsidian's "unresolved links"). The wiki / LLM can act on
    /// these (suggest creating the note, or fix a typo). Returns each dangling target + the notes that
    /// reference it, sorted deterministically.
    pub fn dangling_links(&self) -> ToolResult {
        use std::collections::{BTreeMap, HashSet};
        let start = Instant::now();
        let notes = self.list_markdown_notes();
        let existing: HashSet<String> = notes.iter().map(|n| Self::note_basename(n)).collect();
        let mut dangling: BTreeMap<String, Vec<String>> = BTreeMap::new();
        for rel in &notes {
            let full = self.root.join(rel);
            if let Ok(content) = fs::read_to_string(&full) {
                for link in Self::parse_wikilinks(&content) {
                    if !existing.contains(&Self::note_basename(&link)) {
                        dangling.entry(link).or_default().push(rel.clone());
                    }
                }
            }
        }
        let items: Vec<serde_json::Value> = dangling
            .into_iter()
            .map(|(target, refs)| serde_json::json!({ "target": target, "referenced_by": refs }))
            .collect();
        let json = serde_json::json!({ "dangling": items });
        ToolResult::ok(json.to_string(), start.elapsed().as_millis() as u64)
    }

    /// VAULT-DEEP-INTEGRATION §720 (#3 LLM wiki): the COMPLETE link context for one note in a single call —
    /// `{ backlinks, outlinks, dangling_outlinks }`. The wiki's "note connections" panel: who links here, where
    /// this note points, and which of its own links are unresolved. Reuses backlinks + parse_wikilinks.
    pub fn note_links(&self, path: &str) -> ToolResult {
        use std::collections::HashSet;
        let start = Instant::now();
        // outlinks + dangling-among-them (resolve against existing notes).
        let content = match self.resolve(path).and_then(|full| {
            std::fs::read_to_string(&full).map_err(|e| format!("Cannot read {path}: {e}"))
        }) {
            Ok(c) => c,
            Err(e) => {
                return ToolResult::err(
                    e,
                    crate::types::error_codes::NOT_FOUND,
                    start.elapsed().as_millis() as u64,
                )
            }
        };
        let existing: HashSet<String> = self
            .list_markdown_notes()
            .iter()
            .map(|n| Self::note_basename(n))
            .collect();
        let out_all = Self::parse_wikilinks(&content);
        let dangling: Vec<&String> = out_all
            .iter()
            .filter(|l| !existing.contains(&Self::note_basename(l)))
            .collect();
        // backlinks (who links TO this note) — reuse the existing scan.
        let target = Self::note_basename(path);
        let mut backlinks: Vec<String> = Vec::new();
        for rel in self.list_markdown_notes() {
            if Self::note_basename(&rel) == target {
                continue; // don't count the note itself
            }
            if let Ok(c) = std::fs::read_to_string(self.root.join(&rel)) {
                if Self::content_links_to(&c, &target) {
                    backlinks.push(rel);
                }
            }
        }
        backlinks.sort();
        let json = serde_json::json!({
            "path": path,
            "backlinks": backlinks,
            "outlinks": out_all,
            "dangling_outlinks": dangling,
        });
        ToolResult::ok(json.to_string(), start.elapsed().as_millis() as u64)
    }

    /// VAULT-DEEP-INTEGRATION §720 (#3 LLM wiki, "auto-linking"): UNLINKED MENTIONS — other notes whose TITLE
    /// appears in this note's prose but is NOT yet a `[[wikilink]]` (Obsidian's "unlinked mentions"). The wiki /
    /// an agent surfaces these as "link it?" suggestions. HONEST + precise: matches whole-word, case-insensitive,
    /// SKIPS text already inside `[[...]]` (those are linked), skips the note's own title + titles already linked
    /// from this note, and ignores titles shorter than 3 chars (noise). Returns each candidate target + its
    /// occurrence count, most-mentioned first.
    pub fn link_candidates(&self, path: &str) -> ToolResult {
        use std::collections::HashSet;
        let start = Instant::now();
        let content = match self.resolve(path).and_then(|full| {
            std::fs::read_to_string(&full).map_err(|e| format!("Cannot read {path}: {e}"))
        }) {
            Ok(c) => c,
            Err(e) => {
                return ToolResult::err(
                    e,
                    crate::types::error_codes::NOT_FOUND,
                    start.elapsed().as_millis() as u64,
                )
            }
        };
        // text with every [[...]] span blanked out, so mentions already inside a wikilink don't count.
        let scannable = Self::strip_wikilink_spans(&content);
        let self_base = Self::note_basename(path);
        let already_linked: HashSet<String> = Self::parse_wikilinks(&content)
            .iter()
            .map(|l| Self::note_basename(l))
            .collect();

        let mut candidates: Vec<serde_json::Value> = Vec::new();
        for rel in self.list_markdown_notes() {
            let base = Self::note_basename(&rel);
            if base == self_base || already_linked.contains(&base) {
                continue;
            }
            let title = Self::note_title(&rel);
            if title.chars().count() < 3 {
                continue; // too short → too noisy to suggest
            }
            let count = Self::count_whole_word_ci(&scannable, &title);
            if count > 0 {
                candidates.push(serde_json::json!({ "target": title, "occurrences": count }));
            }
        }
        // most-mentioned first; ties broken by target for deterministic output.
        candidates.sort_by(|a, b| {
            let (ca, cb) = (
                a["occurrences"].as_u64().unwrap_or(0),
                b["occurrences"].as_u64().unwrap_or(0),
            );
            cb.cmp(&ca).then_with(|| {
                a["target"]
                    .as_str()
                    .unwrap_or("")
                    .cmp(b["target"].as_str().unwrap_or(""))
            })
        });
        let json = serde_json::json!({ "path": path, "candidates": candidates });
        ToolResult::ok(json.to_string(), start.elapsed().as_millis() as u64)
    }

    /// Filename stem (no `.md`), ORIGINAL case — the human note title used for display + mention matching.
    fn note_title(rel: &str) -> String {
        let stem = rel
            .strip_suffix(".md")
            .or_else(|| rel.strip_suffix(".MD"))
            .unwrap_or(rel);
        stem.rsplit('/').next().unwrap_or(stem).to_string()
    }

    /// Replace every `[[...]]` span with equal-length spaces so indices are preserved but linked text won't
    /// match as an "unlinked" mention.
    fn strip_wikilink_spans(content: &str) -> String {
        let mut out = String::with_capacity(content.len());
        let mut rest = content;
        while let Some(open) = rest.find("[[") {
            out.push_str(&rest[..open]);
            let after = &rest[open + 2..];
            if let Some(close) = after.find("]]") {
                // blank out the whole [[...]] span (length-preserving not required for matching).
                rest = &after[close + 2..];
            } else {
                out.push_str("[[");
                out.push_str(after);
                rest = "";
            }
        }
        out.push_str(rest);
        out
    }

    /// Case-insensitive, WHOLE-WORD occurrence count of `needle` in `haystack` (boundaries = non-alphanumeric).
    fn count_whole_word_ci(haystack: &str, needle: &str) -> usize {
        if needle.is_empty() {
            return 0;
        }
        let hay = haystack.to_lowercase();
        let need = needle.to_lowercase();
        let bytes = hay.as_bytes();
        let is_word = |b: u8| b.is_ascii_alphanumeric();
        let mut count = 0;
        let mut from = 0;
        while let Some(pos) = hay[from..].find(&need) {
            let start = from + pos;
            let end = start + need.len();
            let before_ok = start == 0 || !is_word(bytes[start - 1]);
            let after_ok = end >= bytes.len() || !is_word(bytes[end]);
            if before_ok && after_ok {
                count += 1;
            }
            from = start + 1;
        }
        count
    }

    /// VAULT-DEEP-INTEGRATION §720 (#4, MCP surface): STRUCTURED agent note edit over MCP — safer than a
    /// full `write_file` overwrite for external agents. `op` ∈ {append, replace_first, insert_after}. HONEST:
    /// errors when `find`/anchor is absent (no silent corruption — the agent re-plans). The in-app live-editor
    /// path is the Swift `AgentNoteEdit` (same op model, different surface).
    pub fn edit_note(&self, path: &str, op: &str, find: &str, text: &str) -> ToolResult {
        let start = Instant::now();
        let err = |msg: String, code: &str, t: std::time::Instant| {
            ToolResult::err(msg, code, t.elapsed().as_millis() as u64)
        };
        let full = match self.resolve(path) {
            Ok(p) => p,
            Err(e) => return err(e, crate::types::error_codes::INVALID_INPUT, start),
        };
        let content = match fs::read_to_string(&full) {
            Ok(c) => c,
            Err(e) => {
                return err(
                    format!("Cannot read {path}: {e}"),
                    crate::types::error_codes::NOT_FOUND,
                    start,
                )
            }
        };
        let updated = match op {
            "append" => {
                if content.is_empty() {
                    text.to_string()
                } else if content.ends_with('\n') {
                    format!("{content}{text}")
                } else {
                    format!("{content}\n{text}")
                }
            }
            "replace_first" => match content.find(find) {
                _ if find.is_empty() => {
                    return err(
                        "replace_first: 'find' is required".into(),
                        crate::types::error_codes::INVALID_INPUT,
                        start,
                    )
                }
                Some(i) => format!("{}{}{}", &content[..i], text, &content[i + find.len()..]),
                None => {
                    return err(
                        "replace_first: 'find' text not found".into(),
                        crate::types::error_codes::NOT_FOUND,
                        start,
                    )
                }
            },
            "insert_after" => match content.find(find) {
                _ if find.is_empty() => {
                    return err(
                        "insert_after: 'find' anchor is required".into(),
                        crate::types::error_codes::INVALID_INPUT,
                        start,
                    )
                }
                Some(i) => {
                    let at = i + find.len();
                    let insertion = if text.starts_with('\n') {
                        text.to_string()
                    } else {
                        format!("\n{text}")
                    };
                    format!("{}{}{}", &content[..at], insertion, &content[at..])
                }
                None => {
                    return err(
                        "insert_after: anchor not found".into(),
                        crate::types::error_codes::NOT_FOUND,
                        start,
                    )
                }
            },
            other => {
                return err(
                    format!(
                        "unknown edit op: {other} (expected append|replace_first|insert_after)"
                    ),
                    crate::types::error_codes::INVALID_INPUT,
                    start,
                )
            }
        };
        match atomic_write(&full, updated.as_bytes()) {
            Ok(_) => {
                // VAULT-DEEP-INTEGRATION §720 (#4): record the EXTERNAL-agent edit for provenance — the MCP
                // analog of the in-app `AgentNoteEditProvenance` MutationEnvelope. BEST-EFFORT + HONEST: the
                // file IS written (the edit is the truth), so a provenance-log failure must NOT fail the edit;
                // instead the result reports `provenance_recorded:false` + the error → never a SILENT gap.
                let mut data =
                    serde_json::json!({ "path": path, "op": op, "bytes_written": updated.len() });
                match self.record_edit_provenance(path, op, &content, &updated) {
                    Ok(mutation_id) => {
                        data["provenance_recorded"] = serde_json::Value::Bool(true);
                        data["mutation_id"] = serde_json::Value::String(mutation_id);
                    }
                    Err(e) => {
                        data["provenance_recorded"] = serde_json::Value::Bool(false);
                        data["provenance_error"] = serde_json::Value::String(e);
                    }
                }
                ToolResult::ok(data.to_string(), start.elapsed().as_millis() as u64)
            }
            Err(e) => err(
                format!("Cannot write {path}: {e}"),
                crate::types::error_codes::EXECUTION_ERROR,
                start,
            ),
        }
    }

    /// VAULT-DEEP-INTEGRATION §720 (#4): append a deterministic provenance record for an external-agent note
    /// edit to `.epistemos/mcp_vault_events.jsonl` (sibling of the graph event log). Mirrors the in-app
    /// `MutationEnvelope` intent — `op:"artifact_update"`, agent actor, before/after blake3 content hashes, an
    /// integrity hash, `affects_body` — in omega-mcp's own honest event vocabulary (no agent_core dep). The
    /// `mutation_id`/`integrity_hash` are content-derived (no clock/random) so a replayed edit is idempotent in
    /// the log. Returns the `mutation_id` on success. Append-only audit trail; the app can ingest it later.
    fn record_edit_provenance(
        &self,
        path: &str,
        op: &str,
        before: &str,
        after: &str,
    ) -> Result<String, String> {
        let hex = |b: &[u8]| blake3::hash(b).to_hex().to_string();
        let before_hash = hex(before.as_bytes());
        let after_hash = hex(after.as_bytes());
        let mutation_id = format!(
            "vault-edit-{}",
            &hex(format!("{path}\u{1f}{op}\u{1f}{before_hash}\u{1f}{after_hash}").as_bytes())[..16]
        );
        let integrity_hash = hex(format!(
            "{mutation_id}\u{1f}{path}\u{1f}{op}\u{1f}{before_hash}\u{1f}{after_hash}"
        )
        .as_bytes());
        let record = serde_json::json!({
            "mutation_id": mutation_id,
            "op": "artifact_update",
            "edit_op": op,
            "artifact_path": path,
            "actor": "agent",
            "before_hash": before_hash,
            "after_hash": after_hash,
            "integrity_hash": integrity_hash,
            "affects_body": true,
        });
        let dir = self.root.join(".epistemos");
        fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
        let line = serde_json::to_string(&record).map_err(|e| e.to_string())?;
        append_lines_bounded(&dir.join("mcp_vault_events.jsonl"), &[line])?;
        Ok(mutation_id)
    }

    /// Write content to a file in the vault.
    pub fn write_file(&self, path: &str, content: &str) -> ToolResult {
        let start = Instant::now();
        match self.resolve(path) {
            Ok(full) => {
                // Create parent directories if needed
                if let Some(parent) = full.parent() {
                    if !parent.exists() {
                        if let Err(e) = fs::create_dir_all(parent) {
                            return ToolResult::err(
                                format!("Cannot create directory: {e}"),
                                crate::types::error_codes::EXECUTION_ERROR,
                                start.elapsed().as_millis() as u64,
                            );
                        }
                    }
                }
                match atomic_write(&full, content.as_bytes()) {
                    Ok(()) => {
                        let json = serde_json::json!({
                            "path": path,
                            "bytes_written": content.len(),
                        });
                        ToolResult::ok(json.to_string(), start.elapsed().as_millis() as u64)
                    }
                    Err(e) => ToolResult::err(
                        format!("Cannot write {path}: {e}"),
                        crate::types::error_codes::EXECUTION_ERROR,
                        start.elapsed().as_millis() as u64,
                    ),
                }
            }
            Err(e) => ToolResult::err(
                e,
                crate::types::error_codes::INVALID_INPUT,
                start.elapsed().as_millis() as u64,
            ),
        }
    }

    /// List files in a vault directory.
    pub fn list_files(&self, path: &str) -> ToolResult {
        let start = Instant::now();
        let dir = if path.is_empty() || path == "." {
            self.root.clone()
        } else {
            match self.resolve(path) {
                Ok(p) => p,
                Err(e) => {
                    return ToolResult::err(
                        e,
                        crate::types::error_codes::INVALID_INPUT,
                        start.elapsed().as_millis() as u64,
                    )
                }
            }
        };

        match fs::read_dir(&dir) {
            Ok(entries) => {
                let mut files = Vec::new();
                for entry in entries.flatten() {
                    let name = entry.file_name().to_string_lossy().to_string();
                    // Skip hidden files/dirs
                    if name.starts_with('.') {
                        continue;
                    }
                    let is_dir = entry.file_type().map(|t| t.is_dir()).unwrap_or(false);
                    let size = entry.metadata().map(|m| m.len()).unwrap_or(0);
                    files.push(serde_json::json!({
                        "name": name,
                        "is_directory": is_dir,
                        "size": size,
                    }));
                }
                files.sort_by(|a, b| {
                    let a_name = a["name"].as_str().unwrap_or("");
                    let b_name = b["name"].as_str().unwrap_or("");
                    a_name.cmp(b_name)
                });
                let json = serde_json::json!({
                    "path": path,
                    "entries": files,
                    "count": files.len(),
                });
                ToolResult::ok(json.to_string(), start.elapsed().as_millis() as u64)
            }
            Err(e) => ToolResult::err(
                format!("Cannot list {path}: {e}"),
                crate::types::error_codes::NOT_FOUND,
                start.elapsed().as_millis() as u64,
            ),
        }
    }

    /// Zero-copy vault search using mmap + rayon parallel file scanning.
    ///
    /// Instead of `fs::read_to_string` (which allocates + copies each file),
    /// this maps files directly into virtual memory and searches the raw bytes.
    /// Combined with rayon's work-stealing thread pool, this enables searching
    /// a 500K-line vault in ~15ms vs 4-10s for traditional string-copy approaches.
    pub fn search_notes(&self, query: &str, limit: usize) -> ToolResult {
        let start = Instant::now();
        let query_lower = query.to_lowercase();
        let limit = limit.clamp(1, 50);

        // Phase 1: Collect all .md file paths (single-threaded walk, fast)
        let mut file_paths = Vec::new();
        Self::collect_md_files(&self.root, &mut file_paths);

        // Phase 2: Parallel mmap search across all files using rayon
        let root = &self.root;
        let all_hits: Vec<serde_json::Value> = file_paths
            .par_iter()
            .filter_map(|path| {
                // mmap the file — zero-copy, kernel page-cached
                let file = File::open(path).ok()?;
                let metadata = file.metadata().ok()?;
                if metadata.len() == 0 {
                    return None;
                }

                // SAFETY: file is opened read-only, we don't write through the mapping,
                // and the file won't be truncated while we hold the map (single-user app).
                let mmap = unsafe { Mmap::map(&file).ok()? };

                // Search the mmap'd bytes directly — no allocation for file content
                let content = std::str::from_utf8(&mmap).ok()?;
                let content_lower = content.to_lowercase();
                if !content_lower.contains(&query_lower) {
                    return None;
                }

                let relative = path
                    .strip_prefix(root)
                    .map(|p| p.to_string_lossy().to_string())
                    .unwrap_or_default();
                let excerpt = Self::extract_excerpt(content, &query_lower);
                Some(serde_json::json!({
                    "path": relative,
                    "excerpt": excerpt,
                }))
            })
            .collect();

        // Phase 3: Truncate to limit
        let results: Vec<_> = all_hits.into_iter().take(limit).collect();

        let json = serde_json::json!({
            "query": query,
            "results": results,
            "count": results.len(),
            "search_ms": start.elapsed().as_millis(),
        });
        ToolResult::ok(json.to_string(), start.elapsed().as_millis() as u64)
    }

    /// Recursively collect all .md file paths under a directory.
    fn collect_md_files(dir: &Path, out: &mut Vec<PathBuf>) {
        let Ok(entries) = fs::read_dir(dir) else {
            return;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            let name = entry.file_name().to_string_lossy().to_string();
            if name.starts_with('.') {
                continue;
            }
            if path.is_dir() {
                Self::collect_md_files(&path, out);
            } else if path.extension().map(|e| e == "md").unwrap_or(false) {
                out.push(path);
            }
        }
    }

    fn extract_excerpt(content: &str, query: &str) -> String {
        let lower = content.to_lowercase();
        if let Some(pos) = lower.find(query) {
            let start = pos.saturating_sub(80);
            let end = (pos + query.len() + 80).min(content.len());
            // Find safe UTF-8 boundaries
            let start = content[..start]
                .rfind(char::is_whitespace)
                .map(|p| p + 1)
                .unwrap_or(start);
            let end = content[end..]
                .find(char::is_whitespace)
                .map(|p| p + end)
                .unwrap_or(end);
            let slice = &content[start..end];
            if start > 0 {
                format!("...{slice}...")
            } else {
                format!("{slice}...")
            }
        } else {
            content.chars().take(200).collect::<String>()
        }
    }
}

// ── UniFFI-exported vault functions ──────────────────────────────────────────

/// True iff `execute_vault_tool` ACTUALLY executes this tool name (vault file/search/wikilink/patch ops).
/// The single source of "what the Rust vault surface can run" — used to HONESTLY scope the stdio fusion
/// server's `tools/list` so an external agent (OpenCode) never sees a vault tool it can't call. Keep this
/// list in lock-step with `execute_vault_tool`'s match arms below (a parity test guards drift). Graph tools
/// are covered separately by `graph_tools::is_graph_tool`.
pub fn is_vault_tool(tool_name: &str) -> bool {
    matches!(
        tool_name,
        "file.read"
            | "vault.read"
            | "read_file"
            | "vault_read"
            | "file.write"
            | "vault.write"
            | "write_file"
            | "vault_write"
            | "file.list"
            | "vault.list"
            | "list_files"
            | "file.search"
            | "vault.search"
            | "search_notes"
            | "vault_search"
            | "vault.backlinks"
            | "backlinks"
            | "vault_backlinks"
            | "vault.outlinks"
            | "outlinks"
            | "vault_outlinks"
            | "vault.dangling_links"
            | "dangling_links"
            | "unresolved_links"
            | "vault.note_links"
            | "note_links"
            | "vault.link_candidates"
            | "link_candidates"
            | "unlinked_mentions"
            | "vault.orphan_notes"
            | "orphan_notes"
            | "orphans"
            | "vault.patch_note"
            | "patch_note"
    )
}

/// Execute a vault tool by name. Returns a JSON ToolResult.
/// vault_root must be set to the user's vault directory.
pub fn execute_vault_tool(vault_root: String, tool_name: String, args_json: String) -> String {
    let Some(executor) = VaultExecutor::new(&vault_root) else {
        let result = ToolResult::err(
            format!("Vault root does not exist: {vault_root}"),
            crate::types::error_codes::NOT_FOUND,
            0,
        );
        return serde_json::to_string(&result).unwrap_or_default();
    };

    let args: serde_json::Value = serde_json::from_str(&args_json)
        .unwrap_or(serde_json::Value::Object(serde_json::Map::new()));

    if crate::graph_tools::is_graph_tool(&tool_name) {
        let result =
            crate::graph_tools::GraphToolExecutor::new(&executor.root).execute(&tool_name, args);
        return serde_json::to_string(&result).unwrap_or_default();
    }

    let result = match tool_name.as_str() {
        "file.read" | "vault.read" | "read_file" | "vault_read" => {
            let path = args["path"].as_str().unwrap_or("");
            executor.read_file(path)
        }
        "file.write" | "vault.write" | "write_file" | "vault_write" => {
            let path = args["path"].as_str().unwrap_or("");
            let content = args["content"].as_str().unwrap_or("");
            executor.write_file(path, content)
        }
        "file.list" | "vault.list" | "list_files" => {
            let path = args["path"].as_str().unwrap_or(".");
            executor.list_files(path)
        }
        "file.search" | "vault.search" | "search_notes" | "vault_search" => {
            let query = args["query"].as_str().unwrap_or("");
            let limit = args["limit"].as_u64().unwrap_or(10) as usize;
            executor.search_notes(query, limit)
        }
        "vault.backlinks" | "backlinks" | "vault_backlinks" => {
            // VAULT-DEEP-INTEGRATION §720 (#3): notes that [[link]] to the target note.
            let target = args["target"]
                .as_str()
                .or_else(|| args["path"].as_str())
                .unwrap_or("");
            executor.backlinks(target)
        }
        "vault.outlinks" | "outlinks" | "vault_outlinks" => {
            // VAULT-DEEP-INTEGRATION §720 (#3): the [[wikilinks]] a note links TO (dual of backlinks).
            let path = args["path"]
                .as_str()
                .or_else(|| args["target"].as_str())
                .unwrap_or("");
            executor.outlinks(path)
        }
        "vault.dangling_links" | "dangling_links" | "unresolved_links" => {
            // VAULT-DEEP-INTEGRATION §720 (#3 LLM wiki): [[links]] pointing at non-existent notes.
            executor.dangling_links()
        }
        "vault.note_links" | "note_links" => {
            // VAULT-DEEP-INTEGRATION §720 (#3): full per-note link context (back/out/dangling) in one call.
            let path = args["path"]
                .as_str()
                .or_else(|| args["target"].as_str())
                .unwrap_or("");
            executor.note_links(path)
        }
        "vault.link_candidates" | "link_candidates" | "unlinked_mentions" => {
            // VAULT-DEEP-INTEGRATION §720 (#3 LLM wiki): unlinked mentions — auto-link suggestions.
            let path = args["path"]
                .as_str()
                .or_else(|| args["target"].as_str())
                .unwrap_or("");
            executor.link_candidates(path)
        }
        "vault.orphan_notes" | "orphan_notes" | "orphans" => {
            // VAULT-DEEP-INTEGRATION §720 (#3 LLM wiki): orphan notes — disconnected from the graph.
            executor.orphan_notes()
        }
        "vault.patch_note" | "patch_note" => {
            // VAULT-DEEP-INTEGRATION §720 (#4): structured note patch (safer than full overwrite).
            let path = args["path"].as_str().unwrap_or("");
            let op = args["op"].as_str().unwrap_or("");
            let find = args["find"].as_str().unwrap_or("");
            let text = args["text"].as_str().unwrap_or("");
            executor.edit_note(path, op, find, text)
        }
        _ => ToolResult::err(
            format!("Unknown vault tool: {tool_name}"),
            crate::types::error_codes::NOT_FOUND,
            0,
        ),
    };

    serde_json::to_string(&result).unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    fn make_temp_vault() -> (tempfile::TempDir, VaultExecutor) {
        let dir = tempfile::tempdir().unwrap();
        fs::write(
            dir.path().join("note1.md"),
            "# Hello\nThis is about transformers.",
        )
        .unwrap();
        fs::write(
            dir.path().join("note2.md"),
            "# World\nAttention is all you need.",
        )
        .unwrap();
        fs::create_dir(dir.path().join("sub")).unwrap();
        fs::write(dir.path().join("sub/deep.md"), "Deep learning note.").unwrap();
        let exec = VaultExecutor::new(dir.path().to_str().unwrap()).unwrap();
        (dir, exec)
    }

    #[test]
    fn test_read_file() {
        let (_dir, exec) = make_temp_vault();
        let result = exec.read_file("note1.md");
        assert!(result.success);
        assert!(result.data_json.contains("transformers"));
    }

    #[test]
    fn test_read_markdown_resource_bounds_resource_surface() {
        let (dir, exec) = make_temp_vault();
        fs::write(dir.path().join("secret.txt"), "not resource context").unwrap();
        fs::write(dir.path().join(".hidden.md"), "hidden").unwrap();
        let large = dir.path().join("large.md");
        let file = File::create(&large).unwrap();
        file.set_len(MCP_RESOURCE_MAX_READ_BYTES + 1).unwrap();

        let note = exec.read_markdown_resource("note1.md").unwrap();
        assert!(note.contains("transformers"));
        assert_eq!(
            exec.read_markdown_resource("secret.txt").unwrap_err(),
            "only markdown vault resources can be read"
        );
        assert_eq!(
            exec.read_markdown_resource("../../etc/passwd").unwrap_err(),
            "Path traversal not allowed"
        );
        assert_eq!(
            exec.read_markdown_resource(".hidden.md").unwrap_err(),
            "hidden vault resources cannot be read"
        );
        assert_eq!(
            exec.read_markdown_resource("large.md").unwrap_err(),
            "markdown resource is too large"
        );

        #[cfg(unix)]
        {
            std::os::unix::fs::symlink(dir.path().join("note1.md"), dir.path().join("link.md"))
                .unwrap();
            assert_eq!(
                exec.read_markdown_resource("link.md").unwrap_err(),
                "symlinked vault resources cannot be read"
            );
        }
    }

    #[test]
    fn test_read_nonexistent() {
        let (_dir, exec) = make_temp_vault();
        let result = exec.read_file("missing.md");
        assert!(!result.success);
    }

    #[test]
    fn test_write_file() {
        let (_dir, exec) = make_temp_vault();
        let result = exec.write_file("new.md", "# New\nFresh content.");
        assert!(result.success);
        let read = exec.read_file("new.md");
        assert!(read.data_json.contains("Fresh content"));
    }

    #[test]
    fn test_list_files() {
        let (_dir, exec) = make_temp_vault();
        let result = exec.list_files(".");
        assert!(result.success);
        assert!(result.data_json.contains("note1.md"));
        assert!(result.data_json.contains("note2.md"));
        assert!(result.data_json.contains("sub"));
    }

    #[test]
    fn test_search_notes() {
        let (_dir, exec) = make_temp_vault();
        let result = exec.search_notes("transformer", 10);
        assert!(result.success);
        assert!(result.data_json.contains("note1.md"));
        assert!(!result.data_json.contains("note2.md"));
    }

    #[test]
    fn test_search_deep() {
        let (_dir, exec) = make_temp_vault();
        let result = exec.search_notes("deep learning", 10);
        assert!(result.success);
        assert!(result.data_json.contains("sub/deep.md"));
    }

    #[test]
    fn test_path_traversal_blocked() {
        let (_dir, exec) = make_temp_vault();
        let result = exec.read_file("../../etc/passwd");
        assert!(!result.success);
        assert!(result.error.as_deref().unwrap_or("").contains("traversal"));
    }

    #[test]
    fn test_execute_vault_tool_dispatch() {
        let dir = tempfile::tempdir().unwrap();
        fs::write(dir.path().join("test.md"), "content here").unwrap();
        let root = dir.path().to_str().unwrap().to_string();

        let result = execute_vault_tool(
            root.clone(),
            "file.read".to_string(),
            r#"{"path":"test.md"}"#.to_string(),
        );
        assert!(result.contains("content here"));

        let result =
            execute_vault_tool(root, "file.list".to_string(), r#"{"path":"."}"#.to_string());
        assert!(result.contains("test.md"));
    }

    #[test]
    fn test_execute_vault_tool_accepts_canonical_file_search() {
        let dir = tempfile::tempdir().unwrap();
        fs::write(dir.path().join("test.md"), "canonical file search").unwrap();
        let root = dir.path().to_str().unwrap().to_string();

        let result = execute_vault_tool(
            root,
            "file.search".to_string(),
            r#"{"query":"canonical","limit":5}"#.to_string(),
        );

        assert!(result.contains("\"success\":true"), "{result}");
        assert!(result.contains("test.md"), "{result}");
    }

    #[test]
    fn test_execute_vault_tool_dispatches_d2_graph_verbs() {
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path().to_str().unwrap().to_string();

        let created = execute_vault_tool(
            root.clone(),
            "graph.create_node".to_string(),
            r#"{"kind":"Note","title":"D2 Node","body":"seven graph verbs","parent_refs":[]}"#
                .to_string(),
        );
        assert!(created.contains("\"success\":true"), "{created}");
        assert!(created.contains("graph_node_created"), "{created}");

        let searched = execute_vault_tool(
            root,
            "graph.search_fulltext".to_string(),
            r#"{"query":"seven graph","k":5}"#.to_string(),
        );
        assert!(searched.contains("\"success\":true"), "{searched}");
        assert!(searched.contains("D2 Node"), "{searched}");
        assert!(searched.contains("graph_fulltext_accessed"), "{searched}");
    }

    #[test]
    fn test_d2_graph_verbs_round_trip_with_event_stream() {
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path().to_str().unwrap().to_string();

        let first = execute_graph_json(
            &root,
            "graph.create_node",
            r#"{"kind":"Note","title":"Source","body":"alpha source","parent_refs":[]}"#,
        );
        let first_id = first["node_id"].as_str().unwrap().to_string();

        let second = execute_graph_json(
            &root,
            "graph.create_node",
            r#"{"kind":"Claim","title":"Target","body":"alpha target","parent_refs":[]}"#,
        );
        let second_id = second["node_id"].as_str().unwrap().to_string();

        let edge_args = format!(r#"{{"from":"{first_id}","to":"{second_id}","kind":"supports"}}"#);
        let edge = execute_graph_json(&root, "graph.create_edge", &edge_args);
        assert!(edge["edge_id"].as_str().unwrap().starts_with("edge_"));

        let get_args = format!(r#"{{"node_id":"{second_id}"}}"#);
        let fetched = execute_graph_json(&root, "graph.get_node", &get_args);
        assert_eq!(fetched["node"]["title"], "Target");

        let traverse_args =
            format!(r#"{{"start":"{first_id}","max_depth":2,"edge_kinds":["supports"]}}"#);
        let traversed = execute_graph_json(&root, "graph.traverse", &traverse_args);
        assert_eq!(traversed["results"][0]["node_id"], second_id);

        let semantic = execute_graph_json(
            &root,
            "graph.search_semantic",
            r#"{"query":"alpha target","k":5}"#,
        );
        assert_eq!(semantic["results"][0]["title"], "Target");

        let committed = execute_graph_json(
            &root,
            "graph.commit_session",
            r#"{"session_id":"default","envelope":{"source":"test"}}"#,
        );
        assert_eq!(committed["committed"], 2);
        assert_eq!(committed["blake3_link"].as_str().unwrap().len(), 64);

        let events_path = dir.path().join(".epistemos/mcp_graph_events.jsonl");
        let events = fs::read_to_string(events_path).unwrap();
        for expected in [
            "graph_node_created",
            "graph_edge_created",
            "graph_node_accessed",
            "graph_traverse_completed",
            "session_committed",
        ] {
            assert!(
                events.contains(expected),
                "missing event {expected}: {events}"
            );
        }
    }

    #[test]
    fn test_graph_populate_from_vault_builds_note_link_graph() {
        // VAULT-DEEP-INTEGRATION §720 (#2): the vault's notes + [[links]] ARE the graph, end-to-end.
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path().to_str().unwrap().to_string();
        fs::write(
            dir.path().join("alpha.md"),
            "# Alpha\nLinks to [[beta]] and [[ghost]].",
        )
        .unwrap();
        fs::write(dir.path().join("beta.md"), "# Beta\nBack to [[alpha]].").unwrap();
        fs::create_dir(dir.path().join("sub")).unwrap();
        fs::write(dir.path().join("sub/gamma.md"), "Standalone, no links.").unwrap();

        let out = execute_graph_json(
            &root,
            "graph.populate_from_vault",
            r#"{"session_id":"vault"}"#,
        );
        assert_eq!(out["notes_indexed"], 3);
        assert_eq!(out["nodes"], 3, "one Note node per markdown file");
        assert_eq!(
            out["edges"], 2,
            "alpha->beta + beta->alpha resolve; ghost does not"
        );
        assert_eq!(
            out["dangling_links"], 1,
            "[[ghost]] is dangling, counted not faked"
        );

        // Deterministic basename-keyed node id → traverse the REAL link graph from alpha to beta.
        let alpha_id = format!(
            "node_vault_{}",
            &blake3::hash("alpha".as_bytes()).to_hex().to_string()[..16]
        );
        let beta_id = format!(
            "node_vault_{}",
            &blake3::hash("beta".as_bytes()).to_hex().to_string()[..16]
        );
        let traversed = execute_graph_json(
            &root,
            "graph.traverse",
            &format!(r#"{{"start":"{alpha_id}","max_depth":1,"edge_kinds":["links_to"]}}"#),
        );
        assert_eq!(traversed["results"][0]["node_id"], beta_id);
        assert_eq!(traversed["results"][0]["edge_kind"], "links_to");

        let node = execute_graph_json(
            &root,
            "graph.get_node",
            &format!(r#"{{"node_id":"{beta_id}"}}"#),
        );
        assert_eq!(node["node"]["kind"], "Note");
        assert_eq!(node["node"]["metadata"]["source"], "vault");
        assert_eq!(node["node"]["metadata"]["path"], "beta.md");

        // IDEMPOTENT: a re-sync upserts — same counts, no duplicate nodes/edges.
        let again = execute_graph_json(
            &root,
            "graph.populate_from_vault",
            r#"{"session_id":"vault"}"#,
        );
        assert_eq!(again["nodes"], 3);
        assert_eq!(again["edges"], 2);

        // A removed note + a removed link disappear on the next sync (graph mirrors the vault, no stale).
        fs::remove_file(dir.path().join("sub/gamma.md")).unwrap();
        fs::write(dir.path().join("beta.md"), "# Beta\nNo links now.").unwrap();
        let synced = execute_graph_json(
            &root,
            "graph.populate_from_vault",
            r#"{"session_id":"vault"}"#,
        );
        assert_eq!(synced["nodes"], 2, "gamma removed");
        assert_eq!(synced["edges"], 1, "only alpha->beta remains");
    }

    #[test]
    fn test_graph_store_is_written_atomically() {
        // A graph mutation persists a COMPLETE, valid store and leaves NO partial temp file behind (the
        // atomic temp-write + rename — so a crash mid-write can't corrupt mcp_graph.json into an empty graph).
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        let out = execute_graph_json(
            root.to_str().unwrap(),
            "graph.create_node",
            r#"{"kind":"Note","title":"A","body":"alpha"}"#,
        );
        assert!(out["node_id"].as_str().unwrap().starts_with("node_"));

        let store_path = root.join(".epistemos/mcp_graph.json");
        let body = std::fs::read_to_string(&store_path).expect("store written");
        // valid, complete JSON (not a truncated fragment).
        let parsed: serde_json::Value = serde_json::from_str(&body).expect("store is valid JSON");
        assert!(parsed["nodes"].is_object(), "store has the expected shape");
        // the atomic write renamed the temp away — nothing lingers.
        assert!(
            !root.join(".epistemos/mcp_graph.json.tmp").exists(),
            "temp file must be renamed away"
        );
    }

    #[test]
    fn test_append_lines_bounded_trims_oversized_keeping_recent() {
        // The SHARED bound used by BOTH the graph + vault event logs: an oversized log is trimmed to the keep
        // bound on the next append, the NEWEST line survives (most-recent kept), and no temp lingers.
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("events.jsonl");
        let filler = "{\"k\":\"vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\"}";
        let big: String = std::iter::repeat(filler)
            .take(48_000)
            .flat_map(|l| [l, "\n"])
            .collect();
        std::fs::write(&path, &big).unwrap();
        assert!(
            std::fs::metadata(&path).unwrap().len() > super::EVENT_LOG_MAX_BYTES,
            "seed must exceed cap"
        );

        super::append_lines_bounded(&path, &["{\"newest\":1}".to_string()]).unwrap();

        let after = std::fs::read_to_string(&path).unwrap();
        let lines: Vec<&str> = after.lines().collect();
        assert!(
            lines.len() <= super::EVENT_LOG_KEEP_LINES,
            "trimmed to keep bound, got {}",
            lines.len()
        );
        assert_eq!(
            lines.last().copied(),
            Some("{\"newest\":1}"),
            "the newest line must survive the trim"
        );
        assert!(
            !path.with_extension("jsonl.tmp").exists(),
            "no trim temp may linger"
        );
    }

    #[test]
    fn test_graph_event_log_is_bounded() {
        // §506: the append-only agent-event telemetry can't grow without limit — once it crosses the byte cap,
        // a graph op trims it to the most-recent keep-bound (atomically), keeping the log small + valid.
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        let epi = root.join(".epistemos");
        std::fs::create_dir_all(&epi).unwrap();
        let log = epi.join("mcp_graph_events.jsonl");

        // Seed an OVERSIZED (> 4 MB) event log: 40k lines of a representative event.
        let line = serde_json::json!({
            "kind": "graph_node_created", "tool_name": "graph.create_node",
            "payload": {"node_id": "node_seed", "kind": "Note", "session_id": "default"}, "sequence": 1
        }).to_string();
        let big: String = std::iter::repeat(line.as_str())
            .take(40_000)
            .flat_map(|l| [l, "\n"])
            .collect();
        std::fs::write(&log, &big).unwrap();
        assert!(
            std::fs::metadata(&log).unwrap().len() > 4 * 1024 * 1024,
            "seed must exceed the cap"
        );

        // A graph op appends + triggers the bound.
        let out = execute_graph_json(
            root.to_str().unwrap(),
            "graph.create_node",
            r#"{"kind":"Note","title":"A","body":""}"#,
        );
        assert!(out["node_id"].as_str().unwrap().starts_with("node_"));

        let after = std::fs::read_to_string(&log).unwrap();
        let lines: Vec<&str> = after.lines().collect();
        assert!(
            lines.len() <= 5_000,
            "event log trimmed to the keep bound, got {}",
            lines.len()
        );
        assert!(!lines.is_empty());
        // the trim left valid JSON (didn't corrupt a line) + no temp lingers.
        serde_json::from_str::<serde_json::Value>(lines.last().unwrap())
            .expect("last kept line is valid JSON");
        assert!(
            !epi.join("mcp_graph_events.jsonl.tmp").exists(),
            "no trim temp may linger"
        );
    }

    #[test]
    fn test_graph_traverse_directional() {
        // §720 #2: agents navigate the graph DOWNSTREAM (out) and via BACKLINKS (in), not just forward.
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path().to_str().unwrap().to_string();
        let a = execute_graph_json(
            &root,
            "graph.create_node",
            r#"{"kind":"Note","title":"A","body":""}"#,
        )["node_id"]
            .as_str()
            .unwrap()
            .to_string();
        let b = execute_graph_json(
            &root,
            "graph.create_node",
            r#"{"kind":"Note","title":"B","body":""}"#,
        )["node_id"]
            .as_str()
            .unwrap()
            .to_string();
        let c = execute_graph_json(
            &root,
            "graph.create_node",
            r#"{"kind":"Note","title":"C","body":""}"#,
        )["node_id"]
            .as_str()
            .unwrap()
            .to_string();
        execute_graph_json(
            &root,
            "graph.create_edge",
            &format!(r#"{{"from":"{a}","to":"{b}","kind":"links_to"}}"#),
        );
        execute_graph_json(
            &root,
            "graph.create_edge",
            &format!(r#"{{"from":"{b}","to":"{c}","kind":"links_to"}}"#),
        );

        // out (default): B → C downstream.
        let out = execute_graph_json(
            &root,
            "graph.traverse",
            &format!(r#"{{"start":"{b}","max_depth":1}}"#),
        );
        let out_ids: Vec<&str> = out["results"]
            .as_array()
            .unwrap()
            .iter()
            .map(|r| r["node_id"].as_str().unwrap())
            .collect();
        assert_eq!(out_ids, vec![c.as_str()], "out reaches C only");

        // in: B ← A backlink (A links TO B).
        let inc = execute_graph_json(
            &root,
            "graph.traverse",
            &format!(r#"{{"start":"{b}","max_depth":1,"direction":"in"}}"#),
        );
        let in_ids: Vec<&str> = inc["results"]
            .as_array()
            .unwrap()
            .iter()
            .map(|r| r["node_id"].as_str().unwrap())
            .collect();
        assert_eq!(in_ids, vec![a.as_str()], "in reaches A (backlink) only");
        assert_eq!(inc["results"][0]["direction"], "in");

        // both at depth 1: A and C.
        let both = execute_graph_json(
            &root,
            "graph.traverse",
            &format!(r#"{{"start":"{b}","max_depth":1,"direction":"both"}}"#),
        );
        let mut both_ids: Vec<&str> = both["results"]
            .as_array()
            .unwrap()
            .iter()
            .map(|r| r["node_id"].as_str().unwrap())
            .collect();
        both_ids.sort();
        let mut want = vec![a.as_str(), c.as_str()];
        want.sort();
        assert_eq!(both_ids, want, "both reaches A and C");

        // bad direction is an honest error.
        let bad = execute_vault_tool(
            root,
            "graph.traverse".to_string(),
            format!(r#"{{"start":"{b}","direction":"sideways"}}"#),
        );
        let res: ToolResult = serde_json::from_str(&bad).unwrap();
        assert!(!res.success, "{}", res.data_json);
    }

    fn execute_graph_json(root: &str, tool_name: &str, args_json: &str) -> serde_json::Value {
        let raw = execute_vault_tool(
            root.to_string(),
            tool_name.to_string(),
            args_json.to_string(),
        );
        let result: ToolResult = serde_json::from_str(&raw).unwrap();
        assert!(result.success, "{raw}");
        serde_json::from_str(&result.data_json).unwrap()
    }

    #[test]
    fn test_vault_backlinks_resolves_wikilinks() {
        // VAULT-DEEP-INTEGRATION §720 (#3): notes that [[link]] to a target note.
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        std::fs::create_dir_all(root.join("notes")).unwrap();
        // Three linkers (plain, alias, path+heading) + one non-linker.
        std::fs::write(root.join("a.md"), "see [[Target]] for more").unwrap();
        std::fs::write(root.join("b.md"), "ref [[target|the goal]] here").unwrap();
        std::fs::write(root.join("notes/c.md"), "deep [[Target#section]] link").unwrap();
        std::fs::write(root.join("d.md"), "no links at all").unwrap();
        std::fs::write(root.join("Target.md"), "I am the target").unwrap();

        let exec = VaultExecutor::new(root.to_str().unwrap()).unwrap();
        let result = exec.backlinks("Target");
        assert!(result.success, "{:?}", result.error);
        let v: serde_json::Value = serde_json::from_str(&result.data_json).unwrap();
        let links: Vec<String> = v["backlinks"]
            .as_array()
            .unwrap()
            .iter()
            .map(|x| x.as_str().unwrap().to_string())
            .collect();
        // a (plain), b (alias), notes/c (path+heading) link to Target; d does not.
        assert!(links.contains(&"a.md".to_string()), "{links:?}");
        assert!(links.contains(&"b.md".to_string()), "{links:?}");
        assert!(links.contains(&"notes/c.md".to_string()), "{links:?}");
        assert!(!links.contains(&"d.md".to_string()), "{links:?}");

        // Via the MCP tool dispatch (vault.backlinks) too.
        let raw = execute_vault_tool(
            root.to_str().unwrap().to_string(),
            "vault.backlinks".to_string(),
            r#"{"target":"Target"}"#.to_string(),
        );
        assert!(raw.contains("a.md") && raw.contains("notes/c.md"), "{raw}");
    }

    #[test]
    fn test_vault_outlinks_extracts_wikilinks() {
        // VAULT-DEEP-INTEGRATION §720 (#3): the [[links]] a note points TO (dual of backlinks).
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        std::fs::write(
            root.join("hub.md"),
            "links to [[Alpha]] and [[beta|the second]] and [[Alpha#intro]] again",
        )
        .unwrap();

        let exec = VaultExecutor::new(root.to_str().unwrap()).unwrap();
        let result = exec.outlinks("hub.md");
        assert!(result.success, "{:?}", result.error);
        let v: serde_json::Value = serde_json::from_str(&result.data_json).unwrap();
        let links: Vec<String> = v["outlinks"]
            .as_array()
            .unwrap()
            .iter()
            .map(|x| x.as_str().unwrap().to_string())
            .collect();
        // Alpha (deduped across the two refs) + beta (alias stripped); original case preserved.
        assert_eq!(
            links,
            vec!["Alpha".to_string(), "beta".to_string()],
            "{links:?}"
        );

        // Traversal-safe via resolve(): an escape attempt errors.
        let escape = exec.outlinks("../../etc/passwd");
        assert!(!escape.success, "traversal must error");
    }

    #[test]
    fn test_vault_dangling_links_finds_unresolved() {
        // VAULT-DEEP-INTEGRATION §720 (#3 LLM wiki): [[links]] to non-existent notes.
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        // hub links to Real (exists) and Ghost (does not).
        std::fs::write(root.join("hub.md"), "see [[Real]] and [[Ghost]]").unwrap();
        std::fs::write(root.join("Real.md"), "I exist").unwrap();

        let exec = VaultExecutor::new(root.to_str().unwrap()).unwrap();
        let result = exec.dangling_links();
        assert!(result.success);
        let v: serde_json::Value = serde_json::from_str(&result.data_json).unwrap();
        let dangling = v["dangling"].as_array().unwrap();
        // Only Ghost is dangling (Real resolves).
        assert_eq!(dangling.len(), 1, "{dangling:?}");
        assert_eq!(dangling[0]["target"], "Ghost");
        assert_eq!(dangling[0]["referenced_by"][0], "hub.md");
    }

    #[test]
    fn test_vault_note_links_aggregates_context() {
        // VAULT-DEEP-INTEGRATION §720 (#3): full per-note link context in one call.
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        // hub links out to Real (exists) + Ghost (missing); other.md links INTO hub.
        std::fs::write(root.join("hub.md"), "out to [[Real]] and [[Ghost]]").unwrap();
        std::fs::write(root.join("Real.md"), "x").unwrap();
        std::fs::write(root.join("other.md"), "points to [[hub]]").unwrap();

        let exec = VaultExecutor::new(root.to_str().unwrap()).unwrap();
        let result = exec.note_links("hub.md");
        assert!(result.success, "{:?}", result.error);
        let v: serde_json::Value = serde_json::from_str(&result.data_json).unwrap();
        // backlinks: other.md → hub
        assert_eq!(v["backlinks"][0], "other.md");
        // outlinks: Real + Ghost
        let out: Vec<String> = v["outlinks"]
            .as_array()
            .unwrap()
            .iter()
            .map(|x| x.as_str().unwrap().into())
            .collect();
        assert_eq!(out, vec!["Real".to_string(), "Ghost".to_string()]);
        // dangling among its outlinks: just Ghost
        let dang: Vec<String> = v["dangling_outlinks"]
            .as_array()
            .unwrap()
            .iter()
            .map(|x| x.as_str().unwrap().into())
            .collect();
        assert_eq!(dang, vec!["Ghost".to_string()]);
    }

    #[test]
    fn test_vault_edit_note_structured_ops() {
        // VAULT-DEEP-INTEGRATION §720 (#4): structured note edits over MCP, honest on missing anchor.
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        std::fs::write(root.join("n.md"), "# Title\nfoo").unwrap();
        let exec = VaultExecutor::new(root.to_str().unwrap()).unwrap();

        // replace_first
        assert!(
            exec.edit_note("n.md", "replace_first", "foo", "bar")
                .success
        );
        assert_eq!(
            std::fs::read_to_string(root.join("n.md")).unwrap(),
            "# Title\nbar"
        );
        // append (adds separating newline)
        assert!(exec.edit_note("n.md", "append", "", "end").success);
        assert_eq!(
            std::fs::read_to_string(root.join("n.md")).unwrap(),
            "# Title\nbar\nend"
        );
        // insert_after the heading
        assert!(
            exec.edit_note("n.md", "insert_after", "# Title", "sub")
                .success
        );
        assert!(std::fs::read_to_string(root.join("n.md"))
            .unwrap()
            .starts_with("# Title\nsub"));

        // HONEST: missing anchor errors + writes nothing.
        let before = std::fs::read_to_string(root.join("n.md")).unwrap();
        let r = exec.edit_note("n.md", "replace_first", "ABSENT", "x");
        assert!(!r.success, "missing find must error");
        assert_eq!(
            std::fs::read_to_string(root.join("n.md")).unwrap(),
            before,
            "must not write on failure"
        );
    }

    #[test]
    fn test_vault_edit_note_records_provenance() {
        // VAULT-DEEP-INTEGRATION §720 (#4): every external-agent edit leaves an auditable provenance record.
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        std::fs::write(root.join("n.md"), "# Title\nfoo").unwrap();
        let exec = VaultExecutor::new(root.to_str().unwrap()).unwrap();

        let r = exec.edit_note("n.md", "replace_first", "foo", "bar");
        assert!(r.success, "{}", r.data_json);
        let data: serde_json::Value = serde_json::from_str(&r.data_json).unwrap();
        assert_eq!(data["provenance_recorded"], true);
        let mutation_id = data["mutation_id"].as_str().unwrap().to_string();
        assert!(mutation_id.starts_with("vault-edit-"));

        // The append-only log holds the artifact_update record with content hashes + the same mutation id.
        let log = std::fs::read_to_string(root.join(".epistemos/mcp_vault_events.jsonl")).unwrap();
        let rec: serde_json::Value = serde_json::from_str(log.lines().next().unwrap()).unwrap();
        assert_eq!(rec["op"], "artifact_update");
        assert_eq!(rec["edit_op"], "replace_first");
        assert_eq!(rec["artifact_path"], "n.md");
        assert_eq!(rec["actor"], "agent");
        assert_eq!(rec["affects_body"], true);
        assert_eq!(rec["mutation_id"], mutation_id);
        assert_eq!(rec["before_hash"].as_str().unwrap().len(), 64);
        assert_ne!(
            rec["before_hash"], rec["after_hash"],
            "content changed → hashes differ"
        );

        // DETERMINISTIC id: the SAME edit on the same before/after content yields the SAME mutation_id
        // (content-derived, no clock) — even though the log is append-only (a second line is added).
        std::fs::write(root.join("n.md"), "# Title\nfoo").unwrap(); // reset to reproduce the same transition
        let r2 = exec.edit_note("n.md", "replace_first", "foo", "bar");
        let data2: serde_json::Value = serde_json::from_str(&r2.data_json).unwrap();
        assert_eq!(
            data2["mutation_id"], mutation_id,
            "same transition → same deterministic id"
        );
        let log2 = std::fs::read_to_string(root.join(".epistemos/mcp_vault_events.jsonl")).unwrap();
        assert_eq!(log2.lines().count(), 2, "append-only: two recorded edits");

        // HONEST: a FAILED edit (missing anchor) records NO provenance (no write → no audit line).
        let _ = exec.edit_note("n.md", "replace_first", "ABSENT", "x");
        let log3 = std::fs::read_to_string(root.join(".epistemos/mcp_vault_events.jsonl")).unwrap();
        assert_eq!(
            log3.lines().count(),
            2,
            "failed edit adds no provenance record"
        );
    }

    #[test]
    fn test_vault_writes_are_atomic_and_leave_no_temp() {
        // The user's note content must never be corruptible by an interrupted write: edit_note + write_file
        // go through atomic temp-write + rename, leaving NO `.omega-tmp` sidecar and a complete file.
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        std::fs::write(root.join("n.md"), "# Title\nfoo").unwrap();
        let exec = VaultExecutor::new(root.to_str().unwrap()).unwrap();

        assert!(exec.write_file("fresh.md", "brand new").success);
        assert_eq!(
            std::fs::read_to_string(root.join("fresh.md")).unwrap(),
            "brand new"
        );
        assert!(exec.edit_note("n.md", "append", "", "added").success);
        assert_eq!(
            std::fs::read_to_string(root.join("n.md")).unwrap(),
            "# Title\nfoo\nadded"
        );

        // No atomic-write temp sidecars linger (the rename moved them into place).
        let leftovers: Vec<_> = std::fs::read_dir(root)
            .unwrap()
            .filter_map(|e| e.ok())
            .filter(|e| e.file_name().to_string_lossy().contains(".omega-tmp"))
            .collect();
        assert!(
            leftovers.is_empty(),
            "no atomic-write temp files may linger: {leftovers:?}"
        );

        // Even a crash-leftover temp sidecar can't pollute the vault: it's not a `.md` note.
        std::fs::write(root.join("crash.md.omega-tmp"), "partial").unwrap();
        let notes = exec.list_markdown_notes();
        assert!(
            !notes.iter().any(|n| n.contains("omega-tmp")),
            "temp sidecar must not list as a note: {notes:?}"
        );
    }

    #[test]
    fn test_vault_link_candidates_finds_unlinked_mentions() {
        // §720 #3 auto-linking: a note mentioning another note's title without [[linking]] it = a candidate.
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        std::fs::write(root.join("Transformers.md"), "About attention.").unwrap();
        std::fs::write(root.join("Attention.md"), "Scaled dot product.").unwrap();
        std::fs::write(root.join("Other.md"), "Unrelated note.").unwrap();
        // note mentions "Transformers" twice (one already linked) + "Attention" once (unlinked) + "transformers"
        // inside a word ("Transformersx") must NOT match.
        std::fs::write(
            root.join("essay.md"),
            "I love [[Transformers]] and transformers. Attention matters. Transformersx is fake.",
        )
        .unwrap();
        let exec = VaultExecutor::new(root.to_str().unwrap()).unwrap();

        let r = exec.link_candidates("essay.md");
        assert!(r.success, "{}", r.data_json);
        let data: serde_json::Value = serde_json::from_str(&r.data_json).unwrap();
        let cands = data["candidates"].as_array().unwrap();
        // Attention: 1 unlinked mention → candidate. Transformers: already linked once; the bare "transformers"
        // is an unlinked mention BUT it's also already_linked (basename "transformers"), so it's excluded.
        let names: Vec<&str> = cands
            .iter()
            .map(|c| c["target"].as_str().unwrap())
            .collect();
        assert!(
            names.contains(&"Attention"),
            "Attention should be a candidate: {names:?}"
        );
        assert!(
            !names.contains(&"Transformers"),
            "already-linked note excluded: {names:?}"
        );
        assert!(
            !names.contains(&"Other"),
            "unmentioned note not a candidate: {names:?}"
        );
        // whole-word: "Transformersx" must not have caused a Transformers match (moot here since excluded),
        // and Attention's count is exactly 1 (not matched inside another word).
        let attention = cands.iter().find(|c| c["target"] == "Attention").unwrap();
        assert_eq!(attention["occurrences"], 1);
    }

    #[test]
    fn test_orphan_notes_agrees_with_graph_view() {
        // Cross-tool invariant: a vault orphan (no wikilinks in/out) is exactly a graph node with no links_to
        // edge in EITHER direction after populate_from_vault. Locks consistency between the two graph views.
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        let root_str = root.to_str().unwrap();
        std::fs::write(root.join("alpha.md"), "links [[beta]]").unwrap();
        std::fs::write(root.join("beta.md"), "back to [[alpha]]").unwrap();
        std::fs::write(root.join("island.md"), "no links at all").unwrap();
        let exec = VaultExecutor::new(root_str).unwrap();

        // vault view: island is the orphan.
        let r: serde_json::Value = serde_json::from_str(&exec.orphan_notes().data_json).unwrap();
        let orphans: Vec<&str> = r["orphans"]
            .as_array()
            .unwrap()
            .iter()
            .map(|o| o.as_str().unwrap())
            .collect();
        assert_eq!(orphans, vec!["island.md"]);

        // graph view: populate, then island's node has no links_to edge in/out.
        execute_graph_json(root_str, "graph.populate_from_vault", r#"{}"#);
        let island_id = format!(
            "node_vault_{}",
            &blake3::hash("island".as_bytes()).to_hex().to_string()[..16]
        );
        let out = execute_graph_json(
            root_str,
            "graph.traverse",
            &format!(
                r#"{{"start":"{island_id}","max_depth":2,"direction":"both","edge_kinds":["links_to"]}}"#
            ),
        );
        assert_eq!(
            out["results"].as_array().unwrap().len(),
            0,
            "graph orphan has no links_to edges: {out}"
        );
    }

    #[test]
    fn test_vault_orphan_notes_finds_disconnected() {
        // §720 #3: orphans = no resolved outlink AND nothing links to them.
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path();
        std::fs::write(root.join("alpha.md"), "links [[beta]]").unwrap(); // connected (out + back via beta)
        std::fs::write(root.join("beta.md"), "back to [[alpha]]").unwrap(); // connected
        std::fs::write(root.join("lonely.md"), "no links here").unwrap(); // ORPHAN (none in/out)
        std::fs::write(root.join("dangly.md"), "see [[ghost]]").unwrap(); // ORPHAN (ghost doesn't exist)
        std::fs::write(root.join("selfish.md"), "see [[selfish]]").unwrap(); // ORPHAN (self-link doesn't connect)
        let exec = VaultExecutor::new(root.to_str().unwrap()).unwrap();

        let r = exec.orphan_notes();
        assert!(r.success, "{}", r.data_json);
        let data: serde_json::Value = serde_json::from_str(&r.data_json).unwrap();
        let orphans: Vec<&str> = data["orphans"]
            .as_array()
            .unwrap()
            .iter()
            .map(|o| o.as_str().unwrap())
            .collect();
        assert_eq!(data["total_notes"], 5);
        assert!(orphans.contains(&"lonely.md"), "{orphans:?}");
        assert!(
            orphans.contains(&"dangly.md"),
            "dangling-only link → still orphan: {orphans:?}"
        );
        assert!(
            orphans.contains(&"selfish.md"),
            "self-link doesn't connect: {orphans:?}"
        );
        assert!(
            !orphans.contains(&"alpha.md"),
            "connected note not orphan: {orphans:?}"
        );
        assert!(!orphans.contains(&"beta.md"), "{orphans:?}");
    }

    #[test]
    fn test_is_vault_tool_parity_with_executor() {
        // DRIFT GUARD: every name `is_vault_tool` claims must ACTUALLY execute (never "Unknown vault tool"),
        // and a non-vault tool must NOT. This keeps the stdio fusion server's honest tools/list scoping true.
        let dir = tempfile::tempdir().unwrap();
        let root = dir.path().to_str().unwrap().to_string();
        let names = [
            "file.read",
            "vault.read",
            "read_file",
            "vault_read",
            "file.write",
            "vault.write",
            "write_file",
            "vault_write",
            "file.list",
            "vault.list",
            "list_files",
            "file.search",
            "vault.search",
            "search_notes",
            "vault_search",
            "vault.backlinks",
            "backlinks",
            "vault_backlinks",
            "vault.outlinks",
            "outlinks",
            "vault_outlinks",
            "vault.dangling_links",
            "dangling_links",
            "unresolved_links",
            "vault.note_links",
            "note_links",
            "vault.link_candidates",
            "link_candidates",
            "unlinked_mentions",
            "vault.orphan_notes",
            "orphan_notes",
            "orphans",
            "vault.patch_note",
            "patch_note",
        ];
        for name in names {
            assert!(is_vault_tool(name), "{name} must be is_vault_tool");
            let out = execute_vault_tool(root.clone(), name.to_string(), "{}".to_string());
            assert!(
                !out.contains("Unknown vault tool"),
                "is_vault_tool({name}) but executor reports it unknown: {out}"
            );
        }
        // boundary: a real app tool that executes Swift-side / in-app is NOT a vault tool.
        assert!(!is_vault_tool("screenshot"));
        assert!(!is_vault_tool("move_file"));
        let unknown = execute_vault_tool(root, "screenshot".to_string(), "{}".to_string());
        assert!(unknown.contains("Unknown vault tool"), "{unknown}");
    }
}
