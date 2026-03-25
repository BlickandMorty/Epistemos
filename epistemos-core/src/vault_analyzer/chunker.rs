// Markdown header-based chunker for Knowledge Fusion.
// Splits documents on H1-H4 headers, preserving heading hierarchy as context prefix.
// Uses the dual-bound token estimator for chunk size enforcement.

use super::token_estimator;
use serde::{Deserialize, Serialize};

/// A chunk of text with provenance and heading context.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Chunk {
    /// Index within the source document (0-based).
    pub chunk_index: usize,
    /// The chunk text including hierarchy prefix.
    pub text: String,
    /// The immediate heading for this chunk (if any).
    pub heading: Option<String>,
    /// Full heading hierarchy (e.g. "# Top > ## Sub > ### Detail").
    pub hierarchy: String,
    /// Estimated token count via dual-bound estimator.
    pub estimated_tokens: u64,
}

/// UniFFI-exported chunk type.
#[derive(Debug, Clone)]
pub struct ChunkResult {
    pub chunk_index: u32,
    pub text: String,
    pub heading: String,
    pub hierarchy: String,
    pub estimated_tokens: u64,
}

impl From<Chunk> for ChunkResult {
    fn from(c: Chunk) -> Self {
        ChunkResult {
            chunk_index: c.chunk_index as u32,
            text: c.text,
            heading: c.heading.unwrap_or_default(),
            hierarchy: c.hierarchy,
            estimated_tokens: c.estimated_tokens,
        }
    }
}

/// UniFFI-exported chunking result for a full document.
#[derive(Debug, Clone)]
pub struct ChunkDocumentResult {
    pub chunks_json: String,
    pub chunk_count: u32,
    pub total_tokens: u64,
}

const MIN_TOKENS: u64 = 50;
const MAX_TOKENS: u64 = 2048;

/// Heading level (1-6) parsed from markdown header prefix.
fn heading_level(line: &str) -> Option<usize> {
    let trimmed = line.trim_start();
    if !trimmed.starts_with('#') {
        return None;
    }
    let hashes = trimmed.chars().take_while(|&c| c == '#').count();
    // Must be followed by a space (or end of line for empty heading)
    if hashes >= 1 && hashes <= 6 {
        let rest = &trimmed[hashes..];
        if rest.is_empty() || rest.starts_with(' ') {
            return Some(hashes);
        }
    }
    None
}

/// Extract heading text without the `#` prefix.
fn heading_text(line: &str) -> String {
    let trimmed = line.trim();
    let after_hashes = trimmed.trim_start_matches('#');
    after_hashes.trim().to_string()
}

/// Internal section before merging/splitting.
struct RawSection {
    level: Option<usize>,
    heading: Option<String>,
    heading_line: Option<String>,
    body_lines: Vec<String>,
}

impl RawSection {
    fn body_text(&self) -> String {
        self.body_lines.join("\n").trim().to_string()
    }

    fn token_count(&self) -> u64 {
        token_estimator::estimate_tokens(&self.full_text_without_hierarchy()) as u64
    }

    fn full_text_without_hierarchy(&self) -> String {
        let body = self.body_text();
        match &self.heading_line {
            Some(h) if !body.is_empty() => format!("{h}\n\n{body}"),
            Some(h) => h.clone(),
            None => body,
        }
    }
}

/// Chunk a markdown document by headers, preserving heading hierarchy.
///
/// Rules:
/// - Split on H1-H4 headings.
/// - Each chunk carries a hierarchy prefix showing its position in the heading tree.
/// - Orphan chunks with < MIN_TOKENS are merged with the next section.
/// - Oversized chunks with > MAX_TOKENS are split at paragraph boundaries.
pub fn chunk_markdown(content: &str) -> Vec<Chunk> {
    if content.trim().is_empty() {
        return Vec::new();
    }

    let lines: Vec<&str> = content.lines().collect();

    // Phase 1: Parse into raw sections by heading boundaries.
    let raw_sections = parse_sections(&lines);

    // Phase 2: Merge orphan sections (< MIN_TOKENS tokens).
    let merged = merge_orphans(raw_sections);

    // Phase 3: Split oversized sections (> MAX_TOKENS tokens) at paragraph boundaries.
    let split = split_oversized(merged);

    // Phase 4: Build hierarchy prefixes and final chunks.
    build_chunks_with_hierarchy(split)
}

/// Parse lines into sections split at heading boundaries.
fn parse_sections(lines: &[&str]) -> Vec<RawSection> {
    let mut sections: Vec<RawSection> = Vec::new();
    let mut current = RawSection {
        level: None,
        heading: None,
        heading_line: None,
        body_lines: Vec::new(),
    };
    let mut in_code_fence = false;

    for &line in lines {
        let trimmed = line.trim();

        // Track code fences to avoid splitting on headings inside code blocks
        if trimmed.starts_with("```") || trimmed.starts_with("~~~") {
            in_code_fence = !in_code_fence;
            current.body_lines.push(line.to_string());
            continue;
        }

        if in_code_fence {
            current.body_lines.push(line.to_string());
            continue;
        }

        if let Some(level) = heading_level(line) {
            // Flush current section
            if current.heading.is_some() || !current.body_lines.is_empty() {
                sections.push(current);
            }
            current = RawSection {
                level: Some(level),
                heading: Some(heading_text(line)),
                heading_line: Some(line.trim().to_string()),
                body_lines: Vec::new(),
            };
        } else {
            current.body_lines.push(line.to_string());
        }
    }

    // Flush last section
    if current.heading.is_some() || !current.body_lines.is_empty() {
        sections.push(current);
    }

    sections
}

/// Merge sections with < MIN_TOKENS into the next section.
fn merge_orphans(sections: Vec<RawSection>) -> Vec<RawSection> {
    if sections.len() <= 1 {
        return sections;
    }

    let mut result: Vec<RawSection> = Vec::with_capacity(sections.len());
    let mut pending: Option<RawSection> = None;

    for section in sections {
        if let Some(prev) = pending.take() {
            // Merge prev into current
            let mut merged_body = prev.body_lines;
            if let Some(ref hl) = section.heading_line {
                merged_body.push(String::new());
                merged_body.push(hl.clone());
            }
            merged_body.extend(section.body_lines);

            let merged = RawSection {
                level: prev.level.or(section.level),
                heading: prev.heading.or(section.heading),
                heading_line: prev.heading_line.or(section.heading_line),
                body_lines: merged_body,
            };

            if merged.token_count() < MIN_TOKENS && result.is_empty() {
                pending = Some(merged);
            } else {
                result.push(merged);
            }
        } else if section.token_count() < MIN_TOKENS {
            pending = Some(section);
        } else {
            result.push(section);
        }
    }

    if let Some(orphan) = pending {
        if let Some(last) = result.last_mut() {
            // Merge trailing orphan into the last section
            if let Some(ref hl) = orphan.heading_line {
                last.body_lines.push(String::new());
                last.body_lines.push(hl.clone());
            }
            last.body_lines.extend(orphan.body_lines);
        } else {
            // Only section — keep it even if small
            result.push(orphan);
        }
    }

    result
}

/// Split sections exceeding MAX_TOKENS at paragraph boundaries (\n\n).
fn split_oversized(sections: Vec<RawSection>) -> Vec<RawSection> {
    let mut result: Vec<RawSection> = Vec::with_capacity(sections.len());

    for section in sections {
        let tokens = section.token_count();
        if tokens <= MAX_TOKENS {
            result.push(section);
            continue;
        }

        // Split body at paragraph boundaries
        let body = section.body_text();
        let paragraphs: Vec<&str> = body.split("\n\n").collect();

        let mut current_paras: Vec<String> = Vec::new();
        let mut current_tokens: u64 = 0;
        let mut is_first = true;

        for para in paragraphs {
            let para_tokens = token_estimator::estimate_tokens(para) as u64;

            if current_tokens + para_tokens > MAX_TOKENS && !current_paras.is_empty() {
                // Flush
                let heading_suffix = if is_first { "" } else { " (cont.)" };
                let heading = section.heading.as_ref().map(|h| format!("{h}{heading_suffix}"));
                let heading_line = section.heading_line.as_ref().map(|hl| {
                    if is_first { hl.clone() } else { format!("{hl} (cont.)") }
                });

                result.push(RawSection {
                    level: section.level,
                    heading,
                    heading_line,
                    body_lines: vec![current_paras.join("\n\n")],
                });

                current_paras = vec![para.to_string()];
                current_tokens = para_tokens;
                is_first = false;
            } else {
                current_paras.push(para.to_string());
                current_tokens += para_tokens;
            }
        }

        if !current_paras.is_empty() {
            let heading_suffix = if is_first { "" } else { " (cont.)" };
            let heading = section.heading.as_ref().map(|h| format!("{h}{heading_suffix}"));
            let heading_line = section.heading_line.as_ref().map(|hl| {
                if is_first { hl.clone() } else { format!("{hl} (cont.)") }
            });

            result.push(RawSection {
                level: section.level,
                heading,
                heading_line,
                body_lines: vec![current_paras.join("\n\n")],
            });
        }
    }

    result
}

/// Build final chunks with heading hierarchy context prefix.
fn build_chunks_with_hierarchy(sections: Vec<RawSection>) -> Vec<Chunk> {
    // Track the active heading at each level to build hierarchy.
    // hierarchy_stack[level] = heading text at that level (1-indexed).
    let mut hierarchy_stack: [Option<String>; 7] = Default::default();
    let mut chunks: Vec<Chunk> = Vec::with_capacity(sections.len());

    for (i, section) in sections.into_iter().enumerate() {
        // Update hierarchy stack
        if let (Some(level), Some(ref heading)) = (section.level, &section.heading) {
            hierarchy_stack[level] = Some(heading.clone());
            // Clear deeper levels
            for deeper in (level + 1)..7 {
                hierarchy_stack[deeper] = None;
            }
        }

        // Build hierarchy string from stack
        let hierarchy: String = hierarchy_stack
            .iter()
            .enumerate()
            .filter_map(|(lvl, h)| {
                h.as_ref().map(|text| {
                    let prefix = "#".repeat(lvl);
                    format!("{prefix} {text}")
                })
            })
            .collect::<Vec<_>>()
            .join(" > ");

        // Build full text with hierarchy context prefix
        let body = section.body_text();
        let text = if !hierarchy.is_empty() && !body.is_empty() {
            // Include the heading line + body. The hierarchy is metadata.
            match &section.heading_line {
                Some(hl) => format!("{hl}\n\n{body}"),
                None => body.clone(),
            }
        } else if !hierarchy.is_empty() {
            section.heading_line.clone().unwrap_or_default()
        } else {
            body.clone()
        };

        if text.trim().is_empty() {
            continue;
        }

        let estimated_tokens = token_estimator::estimate_tokens(&text) as u64;

        chunks.push(Chunk {
            chunk_index: i,
            text,
            heading: section.heading,
            hierarchy,
            estimated_tokens,
        });
    }

    // Re-index after filtering
    for (i, chunk) in chunks.iter_mut().enumerate() {
        chunk.chunk_index = i;
    }

    chunks
}

/// UniFFI-callable: chunk a markdown document and return results as JSON.
pub fn chunk_document(content: &str) -> ChunkDocumentResult {
    let chunks = chunk_markdown(content);
    let chunk_count = chunks.len() as u32;
    let total_tokens: u64 = chunks.iter().map(|c| c.estimated_tokens).sum();
    let results: Vec<ChunkResult> = chunks.into_iter().map(ChunkResult::from).collect();
    let chunks_json = serde_json::to_string(&results).unwrap_or_else(|_| "[]".to_string());

    ChunkDocumentResult {
        chunks_json,
        chunk_count,
        total_tokens,
    }
}

// Serialize ChunkResult for JSON output
impl Serialize for ChunkResult {
    fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        use serde::ser::SerializeStruct;
        let mut s = serializer.serialize_struct("ChunkResult", 5)?;
        s.serialize_field("chunk_index", &self.chunk_index)?;
        s.serialize_field("text", &self.text)?;
        s.serialize_field("heading", &self.heading)?;
        s.serialize_field("hierarchy", &self.hierarchy)?;
        s.serialize_field("estimated_tokens", &self.estimated_tokens)?;
        s.end()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_empty_document() {
        let chunks = chunk_markdown("");
        assert!(chunks.is_empty());
    }

    #[test]
    fn test_whitespace_only() {
        let chunks = chunk_markdown("   \n\n   ");
        assert!(chunks.is_empty());
    }

    #[test]
    fn test_no_headings() {
        let doc = "This is a plain paragraph with enough words to exceed the minimum token threshold. \
                    We need at least fifty tokens worth of content here so let us write a reasonably \
                    long passage about nothing in particular just to fill the space.";
        let chunks = chunk_markdown(doc);
        assert_eq!(chunks.len(), 1);
        assert!(chunks[0].heading.is_none());
        assert!(chunks[0].hierarchy.is_empty());
    }

    #[test]
    fn test_basic_h2_splitting() {
        let doc = "## Introduction\n\n\
                    This is the introduction section with enough content to be meaningful. \
                    It contains several sentences to ensure it exceeds the minimum token count. \
                    We want this to be a standalone chunk.\n\n\
                    ## Methods\n\n\
                    The methods section describes our approach in detail. We used a combination \
                    of quantitative and qualitative analysis to reach our conclusions. Multiple \
                    data sources were triangulated for validity.";
        let chunks = chunk_markdown(doc);
        assert_eq!(chunks.len(), 2);
        assert_eq!(chunks[0].heading.as_deref(), Some("Introduction"));
        assert_eq!(chunks[1].heading.as_deref(), Some("Methods"));
        assert!(chunks[0].text.contains("## Introduction"));
        assert!(chunks[1].text.contains("## Methods"));
    }

    #[test]
    fn test_heading_hierarchy() {
        // Each section needs enough content to exceed MIN_TOKENS (50) individually
        let doc = "# Top Level\n\n\
                    Top level content paragraph with enough words to pass the minimum threshold. \
                    We need to write a substantial amount of text here so it does not get merged \
                    with the next section. This paragraph keeps going with additional detail about \
                    the top level concept to ensure sufficient token count.\n\n\
                    ## Section One\n\n\
                    Section one content with sufficient length to stand alone as a chunk unit. \
                    Adding many extra words for the token count to exceed the fifty token minimum \
                    threshold. This section discusses methodology in great detail and provides \
                    multiple examples of the approach being used.\n\n\
                    ### Subsection A\n\n\
                    Subsection A details with plenty of words to be a proper chunk by itself. \
                    More content fills the space and ensures we have enough tokens here to qualify \
                    as an independent chunk. The subsection elaborates on a specific aspect of \
                    section one with concrete examples and analysis.";
        let chunks = chunk_markdown(doc);
        assert!(chunks.len() >= 2, "expected >= 2 chunks, got {}", chunks.len());

        // The subsection should carry hierarchy from parent headings
        let last = chunks.last().unwrap();
        assert!(last.hierarchy.contains("Top Level"), "hierarchy: {}", last.hierarchy);
        assert!(last.hierarchy.contains("Section One"), "hierarchy: {}", last.hierarchy);
        assert!(last.hierarchy.contains("Subsection A"), "hierarchy: {}", last.hierarchy);
    }

    #[test]
    fn test_hierarchy_string_format() {
        let doc = "# Doc Title\n\nSome intro text that is long enough to be a chunk.\n\n\
                    ## Part One\n\nPart one text with enough content to qualify as standalone.\n\n\
                    ### Detail\n\nDetail text with sufficient words for the minimum token threshold.";
        let chunks = chunk_markdown(doc);
        let detail = chunks.iter().find(|c| c.heading.as_deref() == Some("Detail"));
        if let Some(d) = detail {
            // Hierarchy should show the path: "# Doc Title > ## Part One > ### Detail"
            assert!(d.hierarchy.contains(">"), "hierarchy should use > separator: {}", d.hierarchy);
        }
    }

    #[test]
    fn test_orphan_merge() {
        // A tiny section followed by a substantial one — should merge
        let doc = "## Tiny\n\nHi.\n\n\
                    ## Big Section\n\n\
                    This section has a lot of content to ensure it exceeds the minimum token \
                    threshold by a comfortable margin. We are writing several sentences here \
                    to guarantee that the total token count is well above fifty tokens.";
        let chunks = chunk_markdown(doc);
        // The tiny section should merge with the big one
        assert!(chunks.len() <= 2);
        // The merged chunk should contain both sections' content
        let all_text: String = chunks.iter().map(|c| c.text.clone()).collect();
        assert!(all_text.contains("Hi."));
        assert!(all_text.contains("This section has a lot"));
    }

    #[test]
    fn test_code_fence_not_split() {
        let doc = "## Code Example\n\n\
                    Here is some code that has heading-like content inside:\n\n\
                    ```markdown\n\
                    ## This Is Not A Real Heading\n\
                    It is inside a code fence.\n\
                    ```\n\n\
                    And some text after the code block to pad the token count.";
        let chunks = chunk_markdown(doc);
        // Should not split on the heading inside the code fence
        assert_eq!(chunks.len(), 1);
        assert!(chunks[0].text.contains("## This Is Not A Real Heading"));
    }

    #[test]
    fn test_uses_dual_bound_estimator() {
        let doc = "## Test Section\n\nSome content here.";
        let chunks = chunk_markdown(doc);
        assert!(!chunks.is_empty());
        let tokens = chunks[0].estimated_tokens;
        // Dual-bound: max(chars/3.5, words*1.33) — should be > 0
        assert!(tokens > 0);
        // Verify it matches the token_estimator directly
        let expected = token_estimator::estimate_tokens(&chunks[0].text) as u64;
        assert_eq!(tokens, expected);
    }

    #[test]
    fn test_chunk_document_ffi() {
        let doc = "## Part 1\n\nContent of part one with enough words to exceed minimum.\n\n\
                    ## Part 2\n\nContent of part two also with enough words to qualify.";
        let result = chunk_document(doc);
        assert!(result.chunk_count >= 1);
        assert!(result.total_tokens > 0);
        assert!(!result.chunks_json.is_empty());
        // JSON should be parseable
        let parsed: Vec<serde_json::Value> = serde_json::from_str(&result.chunks_json).unwrap();
        assert_eq!(parsed.len(), result.chunk_count as usize);
    }

    #[test]
    fn test_chunk_indices_sequential() {
        let doc = "## A\n\nContent A with enough words to stand alone.\n\n\
                    ## B\n\nContent B with enough words to stand alone.\n\n\
                    ## C\n\nContent C with enough words to stand alone.";
        let chunks = chunk_markdown(doc);
        for (i, chunk) in chunks.iter().enumerate() {
            assert_eq!(chunk.chunk_index, i);
        }
    }

    #[test]
    fn test_token_bounds() {
        // All chunks should be within [MIN_TOKENS, MAX_TOKENS] or be the only chunk
        let doc = "## Sec\n\n\
                    Enough content here to be meaningful and exceed fifty tokens. \
                    We want to verify that chunking respects bounds properly. \
                    Let us write a paragraph of reasonable length that passes.";
        let chunks = chunk_markdown(doc);
        for chunk in &chunks {
            // Single small documents can be under MIN_TOKENS, that's ok
            assert!(chunk.estimated_tokens <= MAX_TOKENS + 100,
                "chunk too large: {} tokens", chunk.estimated_tokens);
        }
    }

    #[test]
    fn test_h1_through_h4() {
        let doc = "# Title\n\nIntro text.\n\n\
                    ## Chapter\n\nChapter content with enough words.\n\n\
                    ### Section\n\nSection content with enough words.\n\n\
                    #### Subsection\n\nSubsection content with enough words.";
        let chunks = chunk_markdown(doc);
        // Should handle all heading levels
        let headings: Vec<_> = chunks.iter().filter_map(|c| c.heading.as_deref()).collect();
        assert!(headings.contains(&"Title") || chunks.iter().any(|c| c.hierarchy.contains("Title")));
    }

    #[test]
    fn test_heading_level_detection() {
        assert_eq!(heading_level("# Title"), Some(1));
        assert_eq!(heading_level("## Section"), Some(2));
        assert_eq!(heading_level("### Sub"), Some(3));
        assert_eq!(heading_level("#### Deep"), Some(4));
        assert_eq!(heading_level("Not a heading"), None);
        assert_eq!(heading_level("#NoSpace"), None);
        assert_eq!(heading_level("  ## Indented"), Some(2));
    }
}
