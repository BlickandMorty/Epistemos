//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.6.10 — Hybrid MD+JSON memory: 4 schema types
//!   `epistemos.soul.v1` · `epistemos.skill.v1` ·
//!   `epistemos.episode.v1` · `epistemos.semantic.v1`.
//!
//! # Wave J B.6.10 — Hybrid MD+JSON memory substrate
//!
//! Each memory file is a Markdown document with a JSON frontmatter
//! block (YAML-style fence using `---json` markers, then a closing
//! `---` line, then the Markdown body). The frontmatter declares the
//! schema kind + per-kind structured fields; the body is free-form
//! Markdown.
//!
//! Substrate floor owns the parser + the 4-variant schema enum +
//! the structural validator. Real schema-specific field validation
//! (e.g. epistemos.soul.v1 requires `name` and `pillars` arrays) is
//! deferred to the per-schema validators (NOT-STARTED — production
//! adds these alongside the GRDB persistence layer).

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum HybridSchemaKind {
    SoulV1,
    SkillV1,
    EpisodeV1,
    SemanticV1,
}

impl HybridSchemaKind {
    pub const ALL: [HybridSchemaKind; 4] = [
        HybridSchemaKind::SoulV1,
        HybridSchemaKind::SkillV1,
        HybridSchemaKind::EpisodeV1,
        HybridSchemaKind::SemanticV1,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            HybridSchemaKind::SoulV1 => "epistemos.soul.v1",
            HybridSchemaKind::SkillV1 => "epistemos.skill.v1",
            HybridSchemaKind::EpisodeV1 => "epistemos.episode.v1",
            HybridSchemaKind::SemanticV1 => "epistemos.semantic.v1",
        }
    }

    pub fn from_code(code: &str) -> Option<Self> {
        match code {
            "epistemos.soul.v1" => Some(HybridSchemaKind::SoulV1),
            "epistemos.skill.v1" => Some(HybridSchemaKind::SkillV1),
            "epistemos.episode.v1" => Some(HybridSchemaKind::EpisodeV1),
            "epistemos.semantic.v1" => Some(HybridSchemaKind::SemanticV1),
            _ => None,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct HybridDoc {
    pub schema: HybridSchemaKind,
    pub frontmatter_json: String,
    pub markdown_body: String,
}

#[derive(Clone, Debug, PartialEq)]
pub enum HybridMemoryError {
    MissingFrontmatterOpenFence,
    MissingFrontmatterCloseFence,
    MissingSchemaField,
    UnknownSchemaKind { code: String },
    EmptyDocument,
}

const OPEN_FENCE: &str = "---json";
const CLOSE_FENCE: &str = "---";

/// Parse a `---json … --- markdown-body` document into a [`HybridDoc`].
/// The frontmatter is returned as its raw JSON string (substrate floor
/// stops short of parsing the JSON itself — that's the per-schema
/// validator's job).
pub fn parse_hybrid(text: &str) -> Result<HybridDoc, HybridMemoryError> {
    if text.trim().is_empty() {
        return Err(HybridMemoryError::EmptyDocument);
    }
    let first_line = text.lines().next().unwrap_or("");
    if first_line.trim() != OPEN_FENCE {
        return Err(HybridMemoryError::MissingFrontmatterOpenFence);
    }
    let after_open = &text[first_line.len()..];
    let close_idx = after_open
        .find(&format!("\n{}", CLOSE_FENCE))
        .ok_or(HybridMemoryError::MissingFrontmatterCloseFence)?;
    let frontmatter_json = after_open[..close_idx].trim_start_matches('\n').to_string();
    let rest_start = close_idx + 1 + CLOSE_FENCE.len();
    let markdown_body = after_open[rest_start..]
        .trim_start_matches('\n')
        .to_string();

    let schema_code = extract_schema_field(&frontmatter_json)
        .ok_or(HybridMemoryError::MissingSchemaField)?;
    let schema = HybridSchemaKind::from_code(&schema_code)
        .ok_or(HybridMemoryError::UnknownSchemaKind { code: schema_code })?;

    Ok(HybridDoc { schema, frontmatter_json, markdown_body })
}

/// Very simple field extractor — looks for `"schema":` then captures
/// the next quoted string. Real implementation uses serde_json; this
/// substrate avoids the per-call json-parse cost on hot paths.
fn extract_schema_field(json: &str) -> Option<String> {
    let needle = "\"schema\"";
    let pos = json.find(needle)?;
    let after = &json[pos + needle.len()..];
    let colon = after.find(':')?;
    let after_colon = &after[colon + 1..];
    let first_quote = after_colon.find('"')?;
    let after_quote = &after_colon[first_quote + 1..];
    let close_quote = after_quote.find('"')?;
    Some(after_quote[..close_quote].to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn four_distinct_schema_kinds() {
        let s: std::collections::HashSet<_> =
            HybridSchemaKind::ALL.iter().copied().collect();
        assert_eq!(s.len(), 4);
    }

    #[test]
    fn schema_codes_match_doctrine() {
        assert_eq!(HybridSchemaKind::SoulV1.code(), "epistemos.soul.v1");
        assert_eq!(HybridSchemaKind::SkillV1.code(), "epistemos.skill.v1");
        assert_eq!(HybridSchemaKind::EpisodeV1.code(), "epistemos.episode.v1");
        assert_eq!(HybridSchemaKind::SemanticV1.code(), "epistemos.semantic.v1");
    }

    #[test]
    fn from_code_roundtrips_for_known_codes() {
        for &k in &HybridSchemaKind::ALL {
            assert_eq!(HybridSchemaKind::from_code(k.code()), Some(k));
        }
    }

    #[test]
    fn from_code_returns_none_for_unknown() {
        assert!(HybridSchemaKind::from_code("epistemos.unknown.v9").is_none());
    }

    #[test]
    fn empty_document_errors() {
        let err = parse_hybrid("").unwrap_err();
        assert_eq!(err, HybridMemoryError::EmptyDocument);
        let err = parse_hybrid("   \n\n  ").unwrap_err();
        assert_eq!(err, HybridMemoryError::EmptyDocument);
    }

    #[test]
    fn missing_open_fence_errors() {
        let err = parse_hybrid("# Just markdown").unwrap_err();
        assert_eq!(err, HybridMemoryError::MissingFrontmatterOpenFence);
    }

    #[test]
    fn missing_close_fence_errors() {
        let text = "---json\n{\"schema\":\"epistemos.soul.v1\"}\n";
        let err = parse_hybrid(text).unwrap_err();
        assert_eq!(err, HybridMemoryError::MissingFrontmatterCloseFence);
    }

    #[test]
    fn missing_schema_field_errors() {
        let text = "---json\n{\"foo\":\"bar\"}\n---\nbody";
        let err = parse_hybrid(text).unwrap_err();
        assert_eq!(err, HybridMemoryError::MissingSchemaField);
    }

    #[test]
    fn unknown_schema_kind_errors() {
        let text = "---json\n{\"schema\":\"epistemos.unknown.v9\"}\n---\nbody";
        let err = parse_hybrid(text).unwrap_err();
        assert_eq!(
            err,
            HybridMemoryError::UnknownSchemaKind { code: "epistemos.unknown.v9".into() }
        );
    }

    #[test]
    fn parses_soul_doc() {
        let text = "---json\n{\"schema\":\"epistemos.soul.v1\",\"name\":\"alpha\"}\n---\n# Soul\nMarkdown body here.";
        let d = parse_hybrid(text).unwrap();
        assert_eq!(d.schema, HybridSchemaKind::SoulV1);
        assert!(d.frontmatter_json.contains("epistemos.soul.v1"));
        assert!(d.markdown_body.contains("# Soul"));
        assert!(d.markdown_body.contains("Markdown body here."));
    }

    #[test]
    fn parses_skill_doc() {
        let text = "---json\n{\"schema\":\"epistemos.skill.v1\"}\n---\n";
        let d = parse_hybrid(text).unwrap();
        assert_eq!(d.schema, HybridSchemaKind::SkillV1);
    }

    #[test]
    fn parses_episode_doc() {
        let text = "---json\n{\"schema\":\"epistemos.episode.v1\"}\n---\nepisode body";
        let d = parse_hybrid(text).unwrap();
        assert_eq!(d.schema, HybridSchemaKind::EpisodeV1);
        assert_eq!(d.markdown_body, "episode body");
    }

    #[test]
    fn parses_semantic_doc() {
        let text = "---json\n{\"schema\":\"epistemos.semantic.v1\"}\n---\n";
        let d = parse_hybrid(text).unwrap();
        assert_eq!(d.schema, HybridSchemaKind::SemanticV1);
    }

    #[test]
    fn doc_roundtrips_through_serde_json() {
        let d = HybridDoc {
            schema: HybridSchemaKind::SoulV1,
            frontmatter_json: "{\"schema\":\"epistemos.soul.v1\"}".into(),
            markdown_body: "body".into(),
        };
        let json = serde_json::to_string(&d).unwrap();
        let back: HybridDoc = serde_json::from_str(&json).unwrap();
        assert_eq!(d, back);
    }

    #[test]
    fn empty_body_is_allowed() {
        let text = "---json\n{\"schema\":\"epistemos.soul.v1\"}\n---";
        let d = parse_hybrid(text).unwrap();
        assert_eq!(d.markdown_body, "");
    }
}
