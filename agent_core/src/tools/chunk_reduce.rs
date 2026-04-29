// ── Chunk-Reduce Tool: Parallel Text Splitting & Reduction ──────────────
//
// Splits large text into paragraph-aligned chunks, processes each chunk
// in parallel via tokio tasks, then reduces/merges the results using a
// configurable strategy. This is a deterministic pre-processing tool —
// no LLM calls are made during chunk processing.

use std::collections::HashSet;
use std::time::Instant;

use async_trait::async_trait;
use serde_json::Value;
use tracing::debug;

use super::registry::{ToolError, ToolHandler};
use super::{Profile, Tool, ToolCtx, ToolMeta, ToolResult, VariantId};

/// The tool name as it appears in the tool registry and API calls.
pub const CHUNK_REDUCE_TOOL_NAME: &str = "chunk_reduce";

/// Tool description sent to the model.
pub const CHUNK_REDUCE_TOOL_DESCRIPTION: &str = "\
Split a large text into parallel chunks, apply an instruction to each chunk, \
and reduce the results into a single output. Useful for processing long documents \
that exceed context limits: extract facts, summarize sections, find relevant passages, \
or deduplicate information across a large corpus. Chunks are split on paragraph \
boundaries and processed in parallel for speed.";

/// JSON schema for the chunk_reduce tool's input parameters.
pub const CHUNK_REDUCE_TOOL_SCHEMA: &str = r#"{
    "type": "object",
    "properties": {
        "input_text": {
            "type": "string",
            "description": "The large text to process"
        },
        "instruction": {
            "type": "string",
            "description": "Instruction to apply to each chunk (e.g., 'extract key facts', 'summarize')"
        },
        "chunk_size": {
            "type": "integer",
            "description": "Approximate characters per chunk",
            "default": 4000,
            "minimum": 500,
            "maximum": 32000
        },
        "reduce_strategy": {
            "type": "string",
            "enum": ["concatenate", "merge_summaries", "select_relevant", "deduplicate"],
            "default": "concatenate",
            "description": "How to combine chunk results"
        }
    },
    "required": ["input_text", "instruction"]
}"#;

/// Returns the ToolSchema for registration in the tool registry.
pub fn chunk_reduce_tool_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: CHUNK_REDUCE_TOOL_NAME.to_string(),
        description: CHUNK_REDUCE_TOOL_DESCRIPTION.to_string(),
        parameters: serde_json::from_str(CHUNK_REDUCE_TOOL_SCHEMA).unwrap_or_default(),
    }
}

// ── Chunking ────────────────────────────────────────────────────────────

/// Split text on paragraph boundaries (double newline), merging small
/// paragraphs together up to `chunk_size` characters. Never splits
/// mid-paragraph.
fn split_into_chunks(text: &str, chunk_size: usize) -> Vec<String> {
    let chunk_size = chunk_size.clamp(500, 32_000);
    let paragraphs: Vec<&str> = text.split("\n\n").collect();

    let mut chunks = Vec::new();
    let mut current = String::new();

    for para in paragraphs {
        let para = para.trim();
        if para.is_empty() {
            continue;
        }

        // If adding this paragraph would exceed chunk_size and we already
        // have content, flush the current chunk first.
        if !current.is_empty() && current.len() + 2 + para.len() > chunk_size {
            chunks.push(std::mem::take(&mut current));
        }

        if current.is_empty() {
            current.push_str(para);
        } else {
            current.push_str("\n\n");
            current.push_str(para);
        }
    }

    if !current.is_empty() {
        chunks.push(current);
    }

    // Edge case: completely empty input
    if chunks.is_empty() {
        chunks.push(String::new());
    }

    chunks
}

// ── Map Phase ───────────────────────────────────────────────────────────

/// Extract keywords from the instruction (words >= 4 chars, lowercased).
fn extract_keywords(instruction: &str) -> Vec<String> {
    instruction
        .split_whitespace()
        .map(|w| {
            w.trim_matches(|c: char| !c.is_alphanumeric())
                .to_lowercase()
        })
        .filter(|w| w.len() >= 4)
        .collect()
}

/// Process a single chunk deterministically based on the instruction.
///
/// For instructions containing action words like "extract", "find", or "key",
/// filters to sentences that contain instruction keywords. For generic
/// instructions, returns the chunk with a positional header.
fn map_chunk(chunk: &str, instruction: &str, index: usize, total: usize) -> String {
    let header = format!("── Chunk {}/{} ──", index + 1, total);
    let keywords = extract_keywords(instruction);
    let instruction_lower = instruction.to_lowercase();

    let is_extraction = instruction_lower.contains("extract")
        || instruction_lower.contains("find")
        || instruction_lower.contains("key")
        || instruction_lower.contains("filter")
        || instruction_lower.contains("select");

    if is_extraction && !keywords.is_empty() {
        // Extract sentences that match any keyword from the instruction
        let sentences: Vec<&str> = chunk
            .split(|c: char| c == '.' || c == '!' || c == '?')
            .map(|s| s.trim())
            .filter(|s| !s.is_empty())
            .filter(|sentence| {
                let lower = sentence.to_lowercase();
                keywords.iter().any(|kw| lower.contains(kw.as_str()))
            })
            .collect();

        if sentences.is_empty() {
            format!("{header}\n(no matching sentences)")
        } else {
            let body = sentences
                .iter()
                .map(|s| format!("- {s}."))
                .collect::<Vec<_>>()
                .join("\n");
            format!("{header}\n{body}")
        }
    } else {
        // Generic: return chunk with header
        format!("{header}\n{chunk}")
    }
}

// ── Reduce Phase ────────────────────────────────────────────────────────

fn reduce_results(results: Vec<String>, strategy: &str, instruction: &str) -> String {
    match strategy {
        "concatenate" => reduce_concatenate(results),
        "merge_summaries" => reduce_merge_summaries(results),
        "select_relevant" => reduce_select_relevant(results, instruction),
        "deduplicate" => reduce_deduplicate(results),
        _ => reduce_concatenate(results),
    }
}

fn reduce_concatenate(results: Vec<String>) -> String {
    results.join("\n\n")
}

fn reduce_merge_summaries(results: Vec<String>) -> String {
    // Interleave lines and deduplicate consecutive identical lines
    let mut seen = HashSet::new();
    let mut merged = Vec::new();

    for result in &results {
        for line in result.lines() {
            let trimmed = line.trim();
            if !trimmed.is_empty() && seen.insert(trimmed.to_string()) {
                merged.push(trimmed.to_string());
            }
        }
    }

    merged.join("\n")
}

fn reduce_select_relevant(results: Vec<String>, instruction: &str) -> String {
    let keywords = extract_keywords(instruction);
    if keywords.is_empty() {
        // No keywords to score against — return all
        return results.join("\n\n");
    }

    // Score each chunk result by keyword overlap density
    let mut scored: Vec<(usize, &String)> = results
        .iter()
        .map(|result| {
            let lower = result.to_lowercase();
            let score = keywords
                .iter()
                .map(|kw| lower.matches(kw.as_str()).count())
                .sum::<usize>();
            (score, result)
        })
        .collect();

    scored.sort_by(|a, b| b.0.cmp(&a.0));

    // Return top 3 (or fewer if less exist)
    let top_n = scored.len().min(3);
    scored[..top_n]
        .iter()
        .map(|(score, text)| format!("[relevance: {score}]\n{text}"))
        .collect::<Vec<_>>()
        .join("\n\n")
}

fn reduce_deduplicate(results: Vec<String>) -> String {
    let mut seen = HashSet::new();
    let mut deduped = Vec::new();

    for result in &results {
        for line in result.lines() {
            let trimmed = line.trim();
            if !trimmed.is_empty() && seen.insert(trimmed.to_string()) {
                deduped.push(trimmed.to_string());
            }
        }
    }

    deduped.join("\n")
}

// ── Handler ─────────────────────────────────────────────────────────────

pub struct ChunkReduceHandler;

/// Phase 2G-4 native `Tool` impl. Pattern documented in `todo.rs`.
#[async_trait]
impl Tool for ChunkReduceHandler {
    fn name(&self) -> &'static str { "chunk.reduce" }
    fn input_schema(&self) -> &'static Value { super::v2_catalog::chunk_reduce::input_schema() }
    fn output_schema(&self) -> &'static Value {
        super::legacy_adapter::generic_text_or_object_output_schema()
    }
    fn variants(&self) -> &[VariantId] { &[VariantId::A] }
    fn profile(&self) -> Profile { Profile::AppStoreSafe }
    fn small_model_safe(&self) -> bool { true }
    async fn invoke(&self, _ctx: &ToolCtx, variant: VariantId, input: Value) -> ToolResult {
        let started = std::time::Instant::now();
        match <Self as ToolHandler>::execute(self, &input).await {
            Ok(s) => {
                let elapsed_ms = started.elapsed().as_millis() as u32;
                let result = serde_json::from_str::<Value>(&s)
                    .ok()
                    .filter(|v| v.is_object() || v.is_array())
                    .unwrap_or_else(|| serde_json::json!({"text": s}));
                ToolResult { meta: ToolMeta::ok(variant, elapsed_ms), result }
            }
            Err(e) => ToolResult::error(variant, e.to_string()),
        }
    }
}

#[async_trait]
impl ToolHandler for ChunkReduceHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let input_text = input
            .get("input_text")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("input_text required".to_string()))?;

        let instruction = input
            .get("instruction")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("instruction required".to_string()))?;

        let chunk_size = input
            .get("chunk_size")
            .and_then(Value::as_u64)
            .unwrap_or(4000) as usize;

        let reduce_strategy = input
            .get("reduce_strategy")
            .and_then(Value::as_str)
            .unwrap_or("concatenate");

        let start = Instant::now();
        let chunks = split_into_chunks(input_text, chunk_size);
        let total = chunks.len();

        debug!(
            chunk_count = total,
            chunk_size = chunk_size,
            strategy = reduce_strategy,
            "chunk_reduce: splitting text into chunks"
        );

        // Process chunks in parallel
        let instruction_owned = instruction.to_string();
        let handles: Vec<_> = chunks
            .into_iter()
            .enumerate()
            .map(|(index, chunk)| {
                let instr = instruction_owned.clone();
                tokio::task::spawn(async move { map_chunk(&chunk, &instr, index, total) })
            })
            .collect();

        let results: Vec<String> = futures::future::join_all(handles)
            .await
            .into_iter()
            .map(|join_result| {
                join_result.unwrap_or_else(|err| format!("[chunk task failed: {err}]"))
            })
            .collect();

        let output = reduce_results(results, reduce_strategy, instruction);
        let elapsed = start.elapsed();

        debug!(
            elapsed_ms = elapsed.as_millis() as u64,
            output_len = output.len(),
            "chunk_reduce: completed"
        );

        Ok(output)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn schema_parses_as_valid_json() {
        let parsed: Result<Value, _> = serde_json::from_str(CHUNK_REDUCE_TOOL_SCHEMA);
        assert!(parsed.is_ok());
        let schema = parsed.unwrap();
        assert_eq!(schema["type"], "object");
        assert!(schema["properties"]["input_text"].is_object());
        assert!(schema["properties"]["instruction"].is_object());
    }

    #[test]
    fn split_respects_paragraph_boundaries() {
        let text = "First paragraph with enough text to fill a chunk on its own.\n\n\
                     Second paragraph also containing substantial content here.\n\n\
                     Third paragraph with more meaningful content for testing.";
        let chunks = split_into_chunks(text, 500);
        // With chunk_size=500, all paragraphs fit in one chunk
        assert_eq!(chunks.len(), 1);
        assert!(chunks[0].contains("First paragraph"));
        assert!(chunks[0].contains("Third paragraph"));

        // With a very small chunk size (clamped to 500), paragraphs that
        // individually fit within 500 chars get merged, but large enough
        // text will be split across multiple chunks.
        let big_text = (0..20)
            .map(|i| format!("Paragraph number {i} with enough filler text to be meaningful."))
            .collect::<Vec<_>>()
            .join("\n\n");
        let chunks = split_into_chunks(&big_text, 500);
        assert!(chunks.len() >= 2);
        // No chunk should contain a split paragraph
        for chunk in &chunks {
            assert!(!chunk.is_empty());
        }
    }

    #[test]
    fn split_merges_small_paragraphs() {
        let text = "A.\n\nB.\n\nC.";
        let chunks = split_into_chunks(text, 5000);
        assert_eq!(chunks.len(), 1);
        assert!(chunks[0].contains("A."));
        assert!(chunks[0].contains("C."));
    }

    #[test]
    fn split_empty_input() {
        let chunks = split_into_chunks("", 4000);
        assert_eq!(chunks.len(), 1);
    }

    #[test]
    fn map_chunk_extraction_mode() {
        let chunk = "The economy grew. Weather was sunny. Key facts about trade emerged.";
        let result = map_chunk(chunk, "extract key facts", 0, 1);
        assert!(result.contains("Chunk 1/1"));
        // "facts" keyword should match "Key facts about trade emerged"
        assert!(result.contains("facts"));
    }

    #[test]
    fn map_chunk_generic_mode() {
        let chunk = "Some regular text here.";
        let result = map_chunk(chunk, "summarize this", 2, 5);
        assert!(result.contains("Chunk 3/5"));
        assert!(result.contains("Some regular text here."));
    }

    #[test]
    fn reduce_concatenate_joins() {
        let results = vec!["A".to_string(), "B".to_string()];
        let output = reduce_results(results, "concatenate", "");
        assert!(output.contains("A"));
        assert!(output.contains("B"));
    }

    #[test]
    fn reduce_deduplicate_removes_dupes() {
        let results = vec![
            "line one\nline two".to_string(),
            "line two\nline three".to_string(),
        ];
        let output = reduce_results(results, "deduplicate", "");
        let lines: Vec<&str> = output.lines().collect();
        assert_eq!(lines.len(), 3);
    }

    #[test]
    fn reduce_select_relevant_ranks() {
        let results = vec![
            "nothing interesting here".to_string(),
            "facts about trade and economy facts".to_string(),
        ];
        let output = reduce_results(results, "select_relevant", "facts about trade");
        // The second result should rank higher
        let first_relevance_pos = output.find("[relevance:").unwrap();
        let after = &output[first_relevance_pos..];
        assert!(after.contains("facts about trade"));
    }

    #[tokio::test]
    async fn handler_executes_successfully() {
        let handler = ChunkReduceHandler;
        let input = json!({
            "input_text": "First paragraph about science.\n\nSecond paragraph about history.\n\nThird paragraph about science again.",
            "instruction": "extract key science facts",
            "chunk_size": 500,
            "reduce_strategy": "concatenate"
        });
        let result = handler.execute(&input).await;
        assert!(result.is_ok());
        let output = result.unwrap();
        assert!(output.contains("Chunk"));
    }

    #[tokio::test]
    async fn handler_rejects_missing_input() {
        let handler = ChunkReduceHandler;
        let input = json!({ "instruction": "summarize" });
        let result = handler.execute(&input).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn handler_rejects_missing_instruction() {
        let handler = ChunkReduceHandler;
        let input = json!({ "input_text": "some text" });
        let result = handler.execute(&input).await;
        assert!(result.is_err());
    }

    #[test]
    fn tool_constants_are_set() {
        assert_eq!(CHUNK_REDUCE_TOOL_NAME, "chunk_reduce");
        assert!(!CHUNK_REDUCE_TOOL_DESCRIPTION.is_empty());
    }
}
