//! Note Tools — PKM-specific tools for knowledge management
//!
//! Implements 5 note-centric tools that no general-purpose agent has:
//! 1. note_template — Instantiate notes from templates with variable interpolation
//! 2. note_linker — Auto-detect potential wikilinks in a note
//! 3. research_digest — Aggregate vault notes into a structured summary
//! 4. citation_extractor — Parse and format citations
//! 5. markdown_table — Generate tables from structured data

use serde_json::{json, Value};
use std::path::{Path, PathBuf};
use std::sync::Arc;

use super::registry::{ToolError, ToolHandler};
use crate::storage::vault::VaultBackend;

const MAX_TEMPLATE_CHARS: usize = 256 * 1024;
const MAX_TEMPLATE_RESULT_CHARS: usize = 512 * 1024;
const MAX_TEMPLATE_VARIABLES: usize = 128;
const MAX_TEMPLATE_VARIABLE_CHARS: usize = 64 * 1024;
const MAX_NOTE_LINK_STEMS: usize = 5_000;
const MAX_RESEARCH_NOTES: usize = 50;
const MAX_RESEARCH_NOTE_CHARS: usize = 1_000_000;
const MAX_RESEARCH_TAGS: usize = 200;
const MAX_KEY_SENTENCES: usize = 10;
const MAX_CITATION_TEXT_CHARS: usize = 200_000;
const MAX_TABLE_ROWS: usize = 500;
const MAX_TABLE_COLUMNS: usize = 50;
const MAX_TABLE_CELL_CHARS: usize = 2_000;
const MAX_CSV_CHARS: usize = 256 * 1024;

// ── Note Template Tool ──────────────────────────────────────────────────────

pub struct NoteTemplateTool {
    vault: Arc<dyn VaultBackend>,
}

impl NoteTemplateTool {
    pub fn new(vault: Arc<dyn VaultBackend>) -> Self {
        Self { vault }
    }
}

#[async_trait::async_trait]
impl ToolHandler for NoteTemplateTool {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let template = input["template"]
            .as_str()
            .ok_or_else(|| ToolError::InvalidArguments("template required".into()))?;
        let output_path = input["output_path"]
            .as_str()
            .ok_or_else(|| ToolError::InvalidArguments("output_path required".into()))?;
        let variables = input.get("variables").cloned().unwrap_or(json!({}));
        if let Value::Object(vars) = &variables {
            if vars.len() > MAX_TEMPLATE_VARIABLES {
                return Err(ToolError::InvalidArguments(format!(
                    "variables exceeds {MAX_TEMPLATE_VARIABLES} entry cap"
                )));
            }
        } else {
            return Err(ToolError::InvalidArguments(
                "variables must be an object".into(),
            ));
        }

        // Read the template — either a vault path or inline content.
        let template_content = if template.ends_with(".md") {
            self.vault
                .read(template)
                .await
                .map_err(|e| ToolError::ExecutionFailed(e.to_string()))?
        } else {
            template.to_string()
        };
        ensure_char_limit("template", &template_content, MAX_TEMPLATE_CHARS)?;

        // Interpolate {{variable}} placeholders.
        let mut result = template_content;
        if let Value::Object(vars) = &variables {
            for (key, value) in vars {
                let placeholder = format!("{{{{{key}}}}}");
                let replacement = match value {
                    Value::String(s) => s.clone(),
                    other => other.to_string(),
                };
                ensure_char_limit(
                    "template variable",
                    &replacement,
                    MAX_TEMPLATE_VARIABLE_CHARS,
                )?;
                result = result.replace(&placeholder, &replacement);
                ensure_char_limit("rendered template", &result, MAX_TEMPLATE_RESULT_CHARS)?;
            }
        }

        // Auto-populate built-in variables.
        let now = chrono::Utc::now();
        result = result.replace("{{date}}", &now.format("%Y-%m-%d").to_string());
        result = result.replace("{{datetime}}", &now.format("%Y-%m-%d %H:%M").to_string());
        result = result.replace("{{year}}", &now.format("%Y").to_string());
        ensure_char_limit("rendered template", &result, MAX_TEMPLATE_RESULT_CHARS)?;

        // Write the output.
        self.vault
            .write(output_path, &result, None, false)
            .await
            .map_err(|e| ToolError::ExecutionFailed(e.to_string()))?;

        Ok(json!({
            "created": output_path,
            "size": result.len(),
            "variables_applied": variables,
        })
        .to_string())
    }
}

pub fn note_template_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "note_template".to_string(),
        description: "Create a note from a template with variable interpolation. Supports {{variable}} placeholders, plus built-in {{date}}, {{datetime}}, {{year}}.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "template": { "type": "string", "description": "Template vault path (e.g. 'templates/meeting.md') or inline template text" },
                "output_path": { "type": "string", "description": "Where to write the new note" },
                "variables": { "type": "object", "description": "Key-value pairs for {{variable}} interpolation" }
            },
            "required": ["template", "output_path"]
        }),
    }
}

// ── Note Linker Tool ────────────────────────────────────────────────────────

pub struct NoteLinkerTool {
    vault: Arc<dyn VaultBackend>,
    vault_root: PathBuf,
}

impl NoteLinkerTool {
    pub fn new(vault: Arc<dyn VaultBackend>, vault_root: PathBuf) -> Self {
        Self { vault, vault_root }
    }
}

#[async_trait::async_trait]
impl ToolHandler for NoteLinkerTool {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let note_path = input["note_path"]
            .as_str()
            .ok_or_else(|| ToolError::InvalidArguments("note_path required".into()))?;

        let content = self
            .vault
            .read(note_path)
            .await
            .map_err(|e| ToolError::ExecutionFailed(e.to_string()))?;

        // Collect all note stems from the vault.
        let mut note_stems = Vec::new();
        let inventory_truncated =
            collect_note_stems(&self.vault_root, &mut note_stems, MAX_NOTE_LINK_STEMS);

        // Find mentions of note names in the content that aren't already linked.
        let content_lower = content.to_lowercase();
        let mut suggestions = Vec::new();

        let note_stem = std::path::Path::new(note_path)
            .file_stem()
            .map(|s| s.to_string_lossy().to_lowercase())
            .unwrap_or_default();

        for stem in &note_stems {
            let stem_lower = stem.to_lowercase();
            // Skip the note itself.
            if stem_lower == note_stem {
                continue;
            }

            // Check if the stem appears in content but isn't already a wikilink.
            if content_lower.contains(&stem_lower) {
                let already_linked = content.contains(&format!("[[{stem}]]"))
                    || content.contains(&format!("[[{stem}|"));
                if !already_linked {
                    suggestions.push(json!({
                        "note": stem,
                        "suggestion": format!("[[{stem}]]"),
                    }));
                }
            }
        }

        suggestions.truncate(20);
        Ok(json!({
            "note": note_path,
            "link_suggestions": suggestions,
            "count": suggestions.len(),
            "inventory_truncated": inventory_truncated,
        })
        .to_string())
    }
}

fn collect_note_stems(dir: &Path, stems: &mut Vec<String>, max_stems: usize) -> bool {
    if stems.len() >= max_stems {
        return true;
    }
    let mut truncated = false;
    if let Ok(entries) = std::fs::read_dir(dir) {
        for entry in entries.flatten() {
            if stems.len() >= max_stems {
                truncated = true;
                break;
            }
            let path = entry.path();
            let Ok(file_type) = entry.file_type() else {
                continue;
            };
            if file_type.is_symlink() {
                continue;
            }
            if file_type.is_dir() {
                if !path
                    .file_name()
                    .is_some_and(|name| name.to_string_lossy().starts_with('.'))
                {
                    truncated |= collect_note_stems(&path, stems, max_stems);
                }
            } else if file_type.is_file() && path.extension().is_some_and(|ext| ext == "md") {
                if let Some(stem) = path.file_stem() {
                    stems.push(stem.to_string_lossy().to_string());
                }
            }
        }
    }
    truncated
}

pub fn note_linker_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "note_linker".to_string(),
        description: "Scan a note and suggest wikilinks to other notes in the vault. Finds mentions of note names that aren't already linked.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "note_path": { "type": "string", "description": "Vault-relative path of the note to scan" }
            },
            "required": ["note_path"]
        }),
    }
}

// ── Research Digest Tool ────────────────────────────────────────────────────

pub struct ResearchDigestTool {
    vault: Arc<dyn VaultBackend>,
}

impl ResearchDigestTool {
    pub fn new(vault: Arc<dyn VaultBackend>) -> Self {
        Self { vault }
    }
}

#[async_trait::async_trait]
impl ToolHandler for ResearchDigestTool {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let raw_notes = input["notes"]
            .as_array()
            .ok_or_else(|| ToolError::InvalidArguments("notes array required".into()))?;

        if raw_notes.len() > MAX_RESEARCH_NOTES {
            return Err(ToolError::InvalidArguments(format!(
                "notes exceeds {MAX_RESEARCH_NOTES} item cap"
            )));
        }

        let mut note_paths = Vec::with_capacity(raw_notes.len());
        for note in raw_notes {
            let path = note
                .as_str()
                .ok_or_else(|| ToolError::InvalidArguments("notes must be strings".into()))?;
            note_paths.push(path.to_string());
        }

        if note_paths.is_empty() {
            return Err(ToolError::InvalidArguments(
                "at least one note required".into(),
            ));
        }

        let mut digest = String::from("# Research Digest\n\n");
        let mut all_tags = Vec::new();
        let mut total_words = 0usize;
        let mut key_sentences = Vec::new();

        for path in &note_paths {
            let content = self
                .vault
                .read(path)
                .await
                .map_err(|e| ToolError::ExecutionFailed(format!("{path}: {e}")))?;
            ensure_char_limit(path, &content, MAX_RESEARCH_NOTE_CHARS)?;

            let word_count = content.split_whitespace().count();
            total_words += word_count;

            // Extract tags.
            for word in content.split_whitespace() {
                if all_tags.len() < MAX_RESEARCH_TAGS && word.starts_with('#') && word.len() > 1 {
                    all_tags.push(word.to_string());
                }
            }

            // Extract first meaningful paragraph as excerpt.
            let excerpt = content
                .split("\n\n")
                .find(|p| {
                    let trimmed = p.trim();
                    !trimmed.is_empty()
                        && !trimmed.starts_with('#')
                        && !trimmed.starts_with("---")
                        && trimmed.len() > 20
                })
                .unwrap_or("")
                .trim();

            // Extract key sentences (those with strong language).
            for sentence in content.split(['.', '!', '?']) {
                if key_sentences.len() >= MAX_KEY_SENTENCES {
                    break;
                }
                let s = sentence.trim();
                if s.len() > 30
                    && (s.contains("important")
                        || s.contains("key")
                        || s.contains("critical")
                        || s.contains("significant")
                        || s.contains("conclusion")
                        || s.contains("finding")
                        || s.contains("result"))
                {
                    let truncated: String = s.chars().take(200).collect();
                    key_sentences.push(truncated);
                }
            }

            let stem = std::path::Path::new(path)
                .file_stem()
                .map(|s| s.to_string_lossy().to_string())
                .unwrap_or_else(|| path.clone());

            digest.push_str(&format!("## {stem}\n"));
            digest.push_str(&format!("*{word_count} words*\n\n"));
            if !excerpt.is_empty() {
                let truncated: String = excerpt.chars().take(300).collect();
                digest.push_str(&truncated);
                digest.push_str("\n\n");
            }
        }

        all_tags.sort();
        all_tags.dedup();
        key_sentences.truncate(MAX_KEY_SENTENCES);

        Ok(json!({
            "digest": digest,
            "total_notes": note_paths.len(),
            "total_words": total_words,
            "shared_tags": all_tags,
            "key_findings": key_sentences,
        })
        .to_string())
    }
}

pub fn research_digest_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "research_digest".to_string(),
        description: "Aggregate multiple vault notes into a structured research digest with excerpts, shared tags, and key findings.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "notes": {
                    "type": "array",
                    "items": { "type": "string" },
                    "description": "Array of vault-relative note paths to digest"
                }
            },
            "required": ["notes"]
        }),
    }
}

// ── Citation Extractor Tool ─────────────────────────────────────────────────

pub struct CitationExtractorTool;

#[async_trait::async_trait]
impl ToolHandler for CitationExtractorTool {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let text = input["text"]
            .as_str()
            .ok_or_else(|| ToolError::InvalidArguments("text required".into()))?;
        let format = optional_string_field(input, "format")?.unwrap_or("markdown");
        ensure_char_limit("text", text, MAX_CITATION_TEXT_CHARS)?;
        if !matches!(format, "markdown" | "bibtex" | "plain") {
            return Err(ToolError::InvalidArguments(
                "format must be markdown, bibtex, or plain".into(),
            ));
        }

        let mut citations = Vec::new();

        // Extract URL citations.
        for word in text.split_whitespace() {
            let cleaned =
                word.trim_matches(|c: char| matches!(c, '(' | ')' | '[' | ']' | '<' | '>'));
            if (cleaned.starts_with("http://") || cleaned.starts_with("https://"))
                && cleaned.len() > 10
            {
                citations.push(json!({
                    "type": "url",
                    "raw": cleaned,
                    "formatted": match format {
                        "markdown" => format!("[Source]({})", cleaned),
                        "bibtex" => format!("@misc{{url_{}, url={{{}}}}}", citations.len() + 1, cleaned),
                        _ => cleaned.to_string(),
                    }
                }));
            }
        }

        // Extract DOI references.
        let doi_prefix = "10.";
        for (idx, _) in text.match_indices(doi_prefix) {
            // DOI pattern: 10.XXXX/... (ends at whitespace or common delimiters)
            let remainder = &text[idx..];
            let end = remainder
                .find(|c: char| c.is_whitespace() || c == ')' || c == ']' || c == '>' || c == '"')
                .unwrap_or(remainder.len());
            let doi = &remainder[..end];
            if doi.len() > 7 && doi.contains('/') {
                citations.push(json!({
                    "type": "doi",
                    "raw": doi,
                    "formatted": match format {
                        "markdown" => format!("[DOI: {}](https://doi.org/{})", doi, doi),
                        "bibtex" => format!("@article{{doi_{}, doi={{{}}}}}", citations.len() + 1, doi),
                        _ => format!("https://doi.org/{}", doi),
                    }
                }));
            }
        }

        // Extract parenthetical citations (Author, Year) pattern.
        let paren_re_simple: Vec<&str> = text.split('(').collect();
        for chunk in paren_re_simple.iter().skip(1) {
            if let Some(end) = chunk.find(')') {
                let inner = &chunk[..end];
                // Match "Author, 20XX" or "Author et al., 20XX" patterns.
                if inner.len() < 60
                    && (inner.contains("19") || inner.contains("20"))
                    && inner.contains(',')
                    && inner.chars().next().is_some_and(char::is_uppercase)
                {
                    citations.push(json!({
                        "type": "parenthetical",
                        "raw": format!("({})", inner),
                        "formatted": format!("({})", inner),
                    }));
                }
            }
        }

        citations.truncate(50);
        Ok(json!({
            "citations": citations,
            "count": citations.len(),
            "format": format,
        })
        .to_string())
    }
}

pub fn citation_extractor_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "citation_extractor".to_string(),
        description: "Extract and format citations from text: URLs, DOIs, and parenthetical references. Output as markdown, BibTeX, or plain text.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "text": { "type": "string", "description": "Text to extract citations from" },
                "format": { "type": "string", "enum": ["markdown", "bibtex", "plain"], "description": "Output format (default: markdown)" }
            },
            "required": ["text"]
        }),
    }
}

// ── Markdown Table Tool ─────────────────────────────────────────────────────

pub struct MarkdownTableTool;

#[async_trait::async_trait]
impl ToolHandler for MarkdownTableTool {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = required_string_field(input, "action")?;

        match action {
            "from_json" => {
                let data = input["data"].as_array().ok_or_else(|| {
                    ToolError::InvalidArguments("data array of objects required".into())
                })?;

                if data.is_empty() {
                    return Err(ToolError::InvalidArguments("data cannot be empty".into()));
                }
                if data.len() > MAX_TABLE_ROWS {
                    return Err(ToolError::InvalidArguments(format!(
                        "data exceeds {MAX_TABLE_ROWS} row cap"
                    )));
                }
                let mut rows = Vec::with_capacity(data.len());
                for (index, row) in data.iter().enumerate() {
                    let Some(obj) = row.as_object() else {
                        return Err(ToolError::InvalidArguments(format!(
                            "data[{index}] must be an object"
                        )));
                    };
                    rows.push(obj);
                }

                // Collect all column headers from first object.
                let headers: Vec<String> = rows[0].keys().cloned().collect();
                if headers.len() > MAX_TABLE_COLUMNS {
                    return Err(ToolError::InvalidArguments(format!(
                        "data exceeds {MAX_TABLE_COLUMNS} column cap"
                    )));
                }

                let mut table = String::new();

                // Header row.
                table.push('|');
                for h in &headers {
                    table.push_str(&format!(" {} |", markdown_cell(h)));
                }
                table.push('\n');

                // Separator row.
                table.push('|');
                for _ in &headers {
                    table.push_str(" --- |");
                }
                table.push('\n');

                // Data rows.
                for row in rows {
                    table.push('|');
                    for h in &headers {
                        let val = row
                            .get(h)
                            .map(|v| match v {
                                Value::String(s) => s.clone(),
                                other => other.to_string(),
                            })
                            .unwrap_or_default();
                        table.push_str(&format!(" {} |", markdown_cell(&val)));
                    }
                    table.push('\n');
                }

                Ok(
                    json!({"table": table, "rows": data.len(), "columns": headers.len()})
                        .to_string(),
                )
            }
            "from_csv" => {
                let csv = input["csv"]
                    .as_str()
                    .ok_or_else(|| ToolError::InvalidArguments("csv string required".into()))?;
                ensure_char_limit("csv", csv, MAX_CSV_CHARS)?;
                let delimiter = optional_string_field(input, "delimiter")?.unwrap_or(",");
                let mut delimiter_chars = delimiter.chars();
                let Some(delim_char) = delimiter_chars.next() else {
                    return Err(ToolError::InvalidArguments(
                        "delimiter cannot be empty".into(),
                    ));
                };
                if delimiter_chars.next().is_some() || delim_char == '\n' || delim_char == '\r' {
                    return Err(ToolError::InvalidArguments(
                        "delimiter must be a single non-newline character".into(),
                    ));
                }

                let lines: Vec<&str> = csv.lines().collect();
                if lines.is_empty() {
                    return Err(ToolError::InvalidArguments("csv cannot be empty".into()));
                }
                if lines.len().saturating_sub(1) > MAX_TABLE_ROWS {
                    return Err(ToolError::InvalidArguments(format!(
                        "csv exceeds {MAX_TABLE_ROWS} row cap"
                    )));
                }

                let mut table = String::new();

                // Header.
                let headers: Vec<&str> = lines[0].split(delim_char).map(str::trim).collect();
                if headers.len() > MAX_TABLE_COLUMNS {
                    return Err(ToolError::InvalidArguments(format!(
                        "csv exceeds {MAX_TABLE_COLUMNS} column cap"
                    )));
                }
                table.push('|');
                for h in &headers {
                    table.push_str(&format!(" {} |", markdown_cell(h)));
                }
                table.push('\n');

                // Separator.
                table.push('|');
                for _ in &headers {
                    table.push_str(" --- |");
                }
                table.push('\n');

                // Rows.
                for line in lines.iter().skip(1) {
                    table.push('|');
                    for cell in line.split(delim_char).map(str::trim) {
                        table.push_str(&format!(" {} |", markdown_cell(cell)));
                    }
                    table.push('\n');
                }

                Ok(json!({
                    "table": table,
                    "rows": lines.len() - 1,
                    "columns": headers.len(),
                })
                .to_string())
            }
            _ => Err(ToolError::InvalidArguments(format!(
                "unknown action '{action}' (expected: from_json|from_csv)"
            ))),
        }
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

fn ensure_char_limit(label: &str, value: &str, cap: usize) -> Result<(), ToolError> {
    let count = value.chars().count();
    if count > cap {
        Err(ToolError::InvalidArguments(format!(
            "{label} exceeds {cap} character cap"
        )))
    } else {
        Ok(())
    }
}

fn markdown_cell(value: &str) -> String {
    let mut cell: String = value
        .chars()
        .take(MAX_TABLE_CELL_CHARS)
        .map(|ch| match ch {
            '|' => "\\|".to_string(),
            '\n' | '\r' => " ".to_string(),
            _ => ch.to_string(),
        })
        .collect();
    if value.chars().count() > MAX_TABLE_CELL_CHARS {
        cell.push_str("... [truncated]");
    }
    cell
}

pub fn markdown_table_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "markdown_table".to_string(),
        description: "Generate markdown tables from JSON arrays of objects or CSV data."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": { "type": "string", "enum": ["from_json", "from_csv"], "description": "Input format" },
                "data": { "type": "array", "description": "Array of objects (for from_json)" },
                "csv": { "type": "string", "description": "CSV text (for from_csv)" },
                "delimiter": { "type": "string", "description": "CSV delimiter (default: ',')" }
            },
            "required": ["action"]
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::vault::{SearchResult, VaultError};
    use async_trait::async_trait;
    use serde_json::json;
    use std::collections::HashMap;
    use std::sync::Mutex;

    struct StubVault {
        reads: Mutex<HashMap<String, String>>,
        writes: Mutex<Vec<(String, String)>>,
    }

    impl StubVault {
        fn new(reads: HashMap<String, String>) -> Self {
            Self {
                reads: Mutex::new(reads),
                writes: Mutex::new(Vec::new()),
            }
        }
    }

    #[async_trait]
    impl VaultBackend for StubVault {
        async fn hybrid_search(
            &self,
            _query: &str,
            _limit: usize,
            _tag_filter: &[String],
        ) -> Result<Vec<SearchResult>, VaultError> {
            Ok(Vec::new())
        }

        async fn read(&self, path: &str) -> Result<String, VaultError> {
            self.reads
                .lock()
                .unwrap()
                .get(path)
                .cloned()
                .ok_or_else(|| VaultError::NotFound(path.to_string()))
        }

        async fn write(
            &self,
            path: &str,
            content: &str,
            _tags: Option<&[String]>,
            _append: bool,
        ) -> Result<(), VaultError> {
            self.writes
                .lock()
                .unwrap()
                .push((path.to_string(), content.to_string()));
            Ok(())
        }

        async fn list(&self, _path_prefix: &str) -> Result<Vec<String>, VaultError> {
            Ok(Vec::new())
        }

        async fn exists(&self, path: &str) -> Result<bool, VaultError> {
            Ok(self.reads.lock().unwrap().contains_key(path))
        }

        async fn delete(&self, _path: &str) -> Result<bool, VaultError> {
            Ok(false)
        }
    }

    #[tokio::test]
    async fn note_template_rejects_too_many_variables() {
        let vault = Arc::new(StubVault::new(HashMap::new()));
        let handler = NoteTemplateTool::new(vault);
        let mut variables = serde_json::Map::new();
        for index in 0..=MAX_TEMPLATE_VARIABLES {
            variables.insert(format!("v{index}"), json!("x"));
        }

        let err = handler
            .execute(&json!({
                "template": "Hello {{name}}",
                "output_path": "Out.md",
                "variables": Value::Object(variables)
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("variables exceeds"));
    }

    #[tokio::test]
    async fn research_digest_rejects_invalid_and_too_many_notes() {
        let vault = Arc::new(StubVault::new(HashMap::new()));
        let handler = ResearchDigestTool::new(vault);

        let err = handler
            .execute(&json!({ "notes": ["A.md", 42] }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("notes must be strings"));

        let notes: Vec<Value> = (0..=MAX_RESEARCH_NOTES)
            .map(|index| json!(format!("Note-{index}.md")))
            .collect();
        let err = handler
            .execute(&json!({ "notes": notes }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("item cap"));
    }

    #[tokio::test]
    async fn citation_extractor_rejects_oversized_text() {
        let handler = CitationExtractorTool;
        let huge = "x".repeat(MAX_CITATION_TEXT_CHARS + 1);
        let err = handler.execute(&json!({ "text": huge })).await.unwrap_err();
        assert!(format!("{err}").contains("character cap"));
    }

    #[tokio::test]
    async fn citation_extractor_rejects_non_string_format() {
        let handler = CitationExtractorTool;
        let err = handler
            .execute(&json!({ "text": "See https://example.com", "format": 42 }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("format"));
    }

    #[tokio::test]
    async fn markdown_table_escapes_cells_and_rejects_large_inputs() {
        let handler = MarkdownTableTool;
        let result = handler
            .execute(&json!({
                "action": "from_json",
                "data": [{ "name": "Ada|Lovelace", "note": "line one\nline two" }]
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        let table = parsed["table"].as_str().unwrap();
        assert!(table.contains("Ada\\|Lovelace"));
        assert!(table.contains("line one line two"));

        let rows: Vec<Value> = (0..=MAX_TABLE_ROWS)
            .map(|index| json!({ "row": index }))
            .collect();
        let err = handler
            .execute(&json!({
                "action": "from_json",
                "data": rows
            }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("row cap"));
    }

    #[tokio::test]
    async fn markdown_table_rejects_missing_unknown_and_malformed_actions() {
        let handler = MarkdownTableTool;
        let missing = handler.execute(&json!({})).await.unwrap_err();
        assert!(format!("{missing}").contains("action"));

        let non_string = handler.execute(&json!({ "action": 7 })).await.unwrap_err();
        assert!(format!("{non_string}").contains("action"));

        let unknown = handler
            .execute(&json!({ "action": "from_yaml" }))
            .await
            .unwrap_err();
        assert!(format!("{unknown}").contains("unknown action"));
    }

    #[tokio::test]
    async fn markdown_table_rejects_non_object_rows_and_bad_delimiters() {
        let handler = MarkdownTableTool;
        let non_object = handler
            .execute(&json!({
                "action": "from_json",
                "data": [{ "name": "Ada" }, 42]
            }))
            .await
            .unwrap_err();
        assert!(format!("{non_object}").contains("data[1]"));

        let non_string_delimiter = handler
            .execute(&json!({
                "action": "from_csv",
                "csv": "a,b\n1,2",
                "delimiter": 7
            }))
            .await
            .unwrap_err();
        assert!(format!("{non_string_delimiter}").contains("delimiter"));

        let empty_delimiter = handler
            .execute(&json!({
                "action": "from_csv",
                "csv": "a,b\n1,2",
                "delimiter": ""
            }))
            .await
            .unwrap_err();
        assert!(format!("{empty_delimiter}").contains("delimiter"));
    }

    #[cfg(unix)]
    #[test]
    fn note_link_inventory_skips_symlinked_directories() {
        let root = tempfile::tempdir().unwrap();
        std::fs::write(root.path().join("Local.md"), "local").unwrap();

        let outside = tempfile::tempdir().unwrap();
        std::fs::write(outside.path().join("Outside.md"), "outside").unwrap();
        std::os::unix::fs::symlink(outside.path(), root.path().join("Linked")).unwrap();

        let mut stems = Vec::new();
        let truncated = collect_note_stems(root.path(), &mut stems, MAX_NOTE_LINK_STEMS);
        assert!(!truncated);
        assert!(stems.contains(&"Local".to_string()));
        assert!(!stems.contains(&"Outside".to_string()));
    }
}
