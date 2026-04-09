//! Note Tools — PKM-specific tools for knowledge management
//!
//! Implements 5 note-centric tools that no general-purpose agent has:
//! 1. note_template — Instantiate notes from templates with variable interpolation
//! 2. note_linker — Auto-detect potential wikilinks in a note
//! 3. research_digest — Aggregate vault notes into a structured summary
//! 4. citation_extractor — Parse and format citations
//! 5. markdown_table — Generate tables from structured data

use serde_json::{json, Value};
use std::sync::Arc;

use super::registry::{ToolError, ToolHandler};
use crate::storage::vault::VaultBackend;

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
        let template = input["template"].as_str()
            .ok_or_else(|| ToolError::InvalidArguments("template required".into()))?;
        let output_path = input["output_path"].as_str()
            .ok_or_else(|| ToolError::InvalidArguments("output_path required".into()))?;
        let variables = input.get("variables").cloned().unwrap_or(json!({}));

        // Read the template — either a vault path or inline content.
        let template_content = if template.ends_with(".md") {
            self.vault.read(template).await.map_err(|e| ToolError::ExecutionFailed(e.to_string()))?
        } else {
            template.to_string()
        };

        // Interpolate {{variable}} placeholders.
        let mut result = template_content;
        if let Value::Object(vars) = &variables {
            for (key, value) in vars {
                let placeholder = format!("{{{{{key}}}}}");
                let replacement = match value {
                    Value::String(s) => s.clone(),
                    other => other.to_string(),
                };
                result = result.replace(&placeholder, &replacement);
            }
        }

        // Auto-populate built-in variables.
        let now = chrono::Utc::now();
        result = result.replace("{{date}}", &now.format("%Y-%m-%d").to_string());
        result = result.replace("{{datetime}}", &now.format("%Y-%m-%d %H:%M").to_string());
        result = result.replace("{{year}}", &now.format("%Y").to_string());

        // Write the output.
        self.vault.write(output_path, &result, None, false).await
            .map_err(|e| ToolError::ExecutionFailed(e.to_string()))?;

        Ok(json!({
            "created": output_path,
            "size": result.len(),
            "variables_applied": variables,
        }).to_string())
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
}

impl NoteLinkerTool {
    pub fn new(vault: Arc<dyn VaultBackend>) -> Self {
        Self { vault }
    }
}

#[async_trait::async_trait]
impl ToolHandler for NoteLinkerTool {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let note_path = input["note_path"].as_str()
            .ok_or_else(|| ToolError::InvalidArguments("note_path required".into()))?;

        let content = self.vault.read(note_path).await
            .map_err(|e| ToolError::ExecutionFailed(e.to_string()))?;

        // Collect all note stems from the vault.
        let root = self.vault.root_path()
            .ok_or_else(|| ToolError::ExecutionFailed("vault has no root path".into()))?;

        let mut note_stems = Vec::new();
        collect_note_stems(&root, &root, &mut note_stems);

        // Find mentions of note names in the content that aren't already linked.
        let content_lower = content.to_lowercase();
        let mut suggestions = Vec::new();

        for stem in &note_stems {
            let stem_lower = stem.to_lowercase();
            // Skip the note itself.
            let note_stem = std::path::Path::new(note_path)
                .file_stem()
                .map(|s| s.to_string_lossy().to_lowercase())
                .unwrap_or_default();
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
        }).to_string())
    }
}

fn collect_note_stems(root: &std::path::Path, dir: &std::path::Path, stems: &mut Vec<String>) {
    if let Ok(entries) = std::fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                if !path.file_name().map_or(false, |n| n.to_string_lossy().starts_with('.')) {
                    collect_note_stems(root, &path, stems);
                }
            } else if path.extension().map_or(false, |ext| ext == "md") {
                if let Some(stem) = path.file_stem() {
                    stems.push(stem.to_string_lossy().to_string());
                }
            }
        }
    }
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
        let note_paths: Vec<String> = input["notes"]
            .as_array()
            .ok_or_else(|| ToolError::InvalidArguments("notes array required".into()))?
            .iter()
            .filter_map(|v| v.as_str().map(String::from))
            .collect();

        if note_paths.is_empty() {
            return Err(ToolError::InvalidArguments("at least one note required".into()));
        }

        let mut digest = String::from("# Research Digest\n\n");
        let mut all_tags = Vec::new();
        let mut total_words = 0usize;
        let mut key_sentences = Vec::new();

        for path in &note_paths {
            let content = self.vault.read(path).await
                .map_err(|e| ToolError::ExecutionFailed(format!("{path}: {e}")))?;

            let word_count = content.split_whitespace().count();
            total_words += word_count;

            // Extract tags.
            for word in content.split_whitespace() {
                if word.starts_with('#') && word.len() > 1 {
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
            for sentence in content.split(|c: char| c == '.' || c == '!' || c == '?') {
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
                    let truncated = if s.len() > 200 { &s[..200] } else { s };
                    key_sentences.push(truncated.to_string());
                }
            }

            let stem = std::path::Path::new(path)
                .file_stem()
                .map(|s| s.to_string_lossy().to_string())
                .unwrap_or_else(|| path.clone());

            digest.push_str(&format!("## {stem}\n"));
            digest.push_str(&format!("*{word_count} words*\n\n"));
            if !excerpt.is_empty() {
                let truncated = if excerpt.len() > 300 { &excerpt[..300] } else { excerpt };
                digest.push_str(truncated);
                digest.push_str("\n\n");
            }
        }

        all_tags.sort();
        all_tags.dedup();
        key_sentences.truncate(10);

        Ok(json!({
            "digest": digest,
            "total_notes": note_paths.len(),
            "total_words": total_words,
            "shared_tags": all_tags,
            "key_findings": key_sentences,
        }).to_string())
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
        let text = input["text"].as_str()
            .ok_or_else(|| ToolError::InvalidArguments("text required".into()))?;
        let format = input["format"].as_str().unwrap_or("markdown");

        let mut citations = Vec::new();

        // Extract URL citations.
        for word in text.split_whitespace() {
            let cleaned = word.trim_matches(|c: char| c == '(' || c == ')' || c == '[' || c == ']' || c == '<' || c == '>');
            if (cleaned.starts_with("http://") || cleaned.starts_with("https://")) && cleaned.len() > 10 {
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
            let end = remainder.find(|c: char| c.is_whitespace() || c == ')' || c == ']' || c == '>' || c == '"')
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
                    && inner.chars().next().map_or(false, |c| c.is_uppercase())
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
        }).to_string())
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
        let action = input["action"].as_str().unwrap_or("from_json");

        match action {
            "from_json" => {
                let data = input["data"].as_array()
                    .ok_or_else(|| ToolError::InvalidArguments("data array of objects required".into()))?;

                if data.is_empty() {
                    return Ok(json!({"table": "", "error": "empty data"}).to_string());
                }

                // Collect all column headers from first object.
                let headers: Vec<String> = if let Some(first) = data.first().and_then(|d| d.as_object()) {
                    first.keys().cloned().collect()
                } else {
                    return Err(ToolError::InvalidArguments("data must be array of objects".into()));
                };

                let mut table = String::new();

                // Header row.
                table.push('|');
                for h in &headers {
                    table.push_str(&format!(" {h} |"));
                }
                table.push('\n');

                // Separator row.
                table.push('|');
                for _ in &headers {
                    table.push_str(" --- |");
                }
                table.push('\n');

                // Data rows.
                for row in data {
                    table.push('|');
                    if let Some(obj) = row.as_object() {
                        for h in &headers {
                            let val = obj.get(h).map(|v| match v {
                                Value::String(s) => s.clone(),
                                other => other.to_string(),
                            }).unwrap_or_default();
                            table.push_str(&format!(" {val} |"));
                        }
                    }
                    table.push('\n');
                }

                Ok(json!({"table": table, "rows": data.len(), "columns": headers.len()}).to_string())
            }
            "from_csv" => {
                let csv = input["csv"].as_str()
                    .ok_or_else(|| ToolError::InvalidArguments("csv string required".into()))?;
                let delimiter = input["delimiter"].as_str().unwrap_or(",");
                let delim_char = delimiter.chars().next().unwrap_or(',');

                let lines: Vec<&str> = csv.lines().collect();
                if lines.is_empty() {
                    return Ok(json!({"table": "", "error": "empty csv"}).to_string());
                }

                let mut table = String::new();

                // Header.
                let headers: Vec<&str> = lines[0].split(delim_char).map(str::trim).collect();
                table.push('|');
                for h in &headers {
                    table.push_str(&format!(" {h} |"));
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
                        table.push_str(&format!(" {cell} |"));
                    }
                    table.push('\n');
                }

                Ok(json!({
                    "table": table,
                    "rows": lines.len() - 1,
                    "columns": headers.len(),
                }).to_string())
            }
            _ => Ok(json!({"error": format!("Unknown action: {action}")}).to_string()),
        }
    }
}

pub fn markdown_table_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "markdown_table".to_string(),
        description: "Generate markdown tables from JSON arrays of objects or CSV data.".to_string(),
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
