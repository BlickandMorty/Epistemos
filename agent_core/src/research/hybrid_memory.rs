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
//! the structural validator. Iter 83 lands the per-schema field
//! validators (`validate_soul_v1` / `validate_skill_v1` /
//! `validate_episode_v1` / `validate_semantic_v1` + the
//! `validate_per_schema` dispatcher). They enforce field presence
//! + top-level type only; full per-schema rules (regex, enum
//! literals, nested shape) land alongside the GRDB persistence
//! layer.

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

    /// Per-schema required-field list. Used by control-room UIs that
    /// surface "what fields must this kind of memory have?" + by
    /// callers that want to display the schema contract upfront.
    /// Cross-surface invariant: every field listed here is checked
    /// by the corresponding `validate_*_v1` function.
    pub const fn required_fields(self) -> &'static [&'static str] {
        match self {
            HybridSchemaKind::SoulV1 => &["name", "pillars"],
            HybridSchemaKind::SkillV1 => &["name", "summary", "version"],
            HybridSchemaKind::EpisodeV1 => &["id", "timestamp", "summary"],
            HybridSchemaKind::SemanticV1 => &["id", "claim"],
        }
    }

    /// Predicate: this schema kind carries a timestamp (EpisodeV1
    /// only). The "is this a temporal memory?" filter for the
    /// memory-recall UI.
    pub const fn is_temporal(self) -> bool {
        matches!(self, HybridSchemaKind::EpisodeV1)
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

impl HybridMemoryError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            HybridMemoryError::MissingFrontmatterOpenFence => "missing_frontmatter_open_fence",
            HybridMemoryError::MissingFrontmatterCloseFence => "missing_frontmatter_close_fence",
            HybridMemoryError::MissingSchemaField => "missing_schema_field",
            HybridMemoryError::UnknownSchemaKind { .. } => "unknown_schema_kind",
            HybridMemoryError::EmptyDocument => "empty_document",
        }
    }

    /// Predicate: error pertains to frontmatter fence structure
    /// (open/close fence missing or empty document).
    pub const fn is_fence_error(&self) -> bool {
        matches!(
            self,
            HybridMemoryError::MissingFrontmatterOpenFence
                | HybridMemoryError::MissingFrontmatterCloseFence
                | HybridMemoryError::EmptyDocument
        )
    }

    /// Predicate: error pertains to schema-field declaration
    /// (missing or unknown schema). Cross-surface invariant:
    /// `is_fence_error XOR is_schema_error` partitions all variants.
    pub const fn is_schema_error(&self) -> bool {
        matches!(
            self,
            HybridMemoryError::MissingSchemaField
                | HybridMemoryError::UnknownSchemaKind { .. }
        )
    }
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

// ── Per-schema field validators (iter 83) ───────────────────────────────────
//
// Substrate-floor per-schema field requirements. Each validator parses the
// frontmatter JSON into a serde_json::Value and checks that the per-schema
// required fields are present + have the right top-level type. Production
// extends these with full per-schema rules (regex, enum literals, nested
// shape); substrate floor catches the structural shape errors that would
// otherwise propagate to the persistence layer.

#[derive(Clone, Debug, PartialEq)]
pub enum SchemaFieldError {
    FrontmatterJsonInvalid,
    FrontmatterNotObject,
    MissingField { field: &'static str },
    FieldWrongType { field: &'static str, expected: &'static str },
}

impl SchemaFieldError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            SchemaFieldError::FrontmatterJsonInvalid => "frontmatter_json_invalid",
            SchemaFieldError::FrontmatterNotObject => "frontmatter_not_object",
            SchemaFieldError::MissingField { .. } => "missing_field",
            SchemaFieldError::FieldWrongType { .. } => "field_wrong_type",
        }
    }

    /// Predicate: error pertains to the JSON envelope (invalid JSON
    /// or non-object root).
    pub const fn is_envelope_error(&self) -> bool {
        matches!(
            self,
            SchemaFieldError::FrontmatterJsonInvalid | SchemaFieldError::FrontmatterNotObject
        )
    }

    /// Predicate: error pertains to a specific named field
    /// (missing or wrong type). Cross-surface invariant:
    /// `is_envelope_error XOR is_field_error` partitions variants.
    pub const fn is_field_error(&self) -> bool {
        matches!(
            self,
            SchemaFieldError::MissingField { .. } | SchemaFieldError::FieldWrongType { .. }
        )
    }

    /// Field name involved in the error, when the variant carries
    /// one. `None` for envelope errors.
    pub const fn field(&self) -> Option<&'static str> {
        match self {
            SchemaFieldError::MissingField { field }
            | SchemaFieldError::FieldWrongType { field, .. } => Some(*field),
            _ => None,
        }
    }
}

fn parse_frontmatter(
    doc: &HybridDoc,
) -> Result<serde_json::Map<String, serde_json::Value>, SchemaFieldError> {
    let v: serde_json::Value = serde_json::from_str(&doc.frontmatter_json)
        .map_err(|_| SchemaFieldError::FrontmatterJsonInvalid)?;
    match v {
        serde_json::Value::Object(m) => Ok(m),
        _ => Err(SchemaFieldError::FrontmatterNotObject),
    }
}

fn require_string(
    obj: &serde_json::Map<String, serde_json::Value>,
    name: &'static str,
) -> Result<(), SchemaFieldError> {
    match obj.get(name) {
        Some(serde_json::Value::String(_)) => Ok(()),
        Some(_) => Err(SchemaFieldError::FieldWrongType { field: name, expected: "string" }),
        None => Err(SchemaFieldError::MissingField { field: name }),
    }
}

fn require_array(
    obj: &serde_json::Map<String, serde_json::Value>,
    name: &'static str,
) -> Result<(), SchemaFieldError> {
    match obj.get(name) {
        Some(serde_json::Value::Array(_)) => Ok(()),
        Some(_) => Err(SchemaFieldError::FieldWrongType { field: name, expected: "array" }),
        None => Err(SchemaFieldError::MissingField { field: name }),
    }
}

pub fn validate_soul_v1(doc: &HybridDoc) -> Result<(), SchemaFieldError> {
    let obj = parse_frontmatter(doc)?;
    require_string(&obj, "name")?;
    require_array(&obj, "pillars")?;
    Ok(())
}

pub fn validate_skill_v1(doc: &HybridDoc) -> Result<(), SchemaFieldError> {
    let obj = parse_frontmatter(doc)?;
    require_string(&obj, "name")?;
    require_string(&obj, "summary")?;
    require_string(&obj, "version")?;
    Ok(())
}

pub fn validate_episode_v1(doc: &HybridDoc) -> Result<(), SchemaFieldError> {
    let obj = parse_frontmatter(doc)?;
    require_string(&obj, "id")?;
    require_string(&obj, "timestamp")?;
    require_string(&obj, "summary")?;
    Ok(())
}

pub fn validate_semantic_v1(doc: &HybridDoc) -> Result<(), SchemaFieldError> {
    let obj = parse_frontmatter(doc)?;
    require_string(&obj, "id")?;
    require_string(&obj, "claim")?;
    Ok(())
}

/// Dispatch to the correct per-schema validator based on `doc.schema`.
pub fn validate_per_schema(doc: &HybridDoc) -> Result<(), SchemaFieldError> {
    match doc.schema {
        HybridSchemaKind::SoulV1 => validate_soul_v1(doc),
        HybridSchemaKind::SkillV1 => validate_skill_v1(doc),
        HybridSchemaKind::EpisodeV1 => validate_episode_v1(doc),
        HybridSchemaKind::SemanticV1 => validate_semantic_v1(doc),
    }
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

    // ── Per-schema validator tests (iter 83) ────────────────────────────────

    fn doc(schema: HybridSchemaKind, frontmatter: &str) -> HybridDoc {
        HybridDoc {
            schema,
            frontmatter_json: frontmatter.to_string(),
            markdown_body: String::new(),
        }
    }

    #[test]
    fn soul_v1_well_formed_passes() {
        let d = doc(
            HybridSchemaKind::SoulV1,
            r#"{"schema":"epistemos.soul.v1","name":"Pilot","pillars":["truth","care"]}"#,
        );
        assert!(validate_soul_v1(&d).is_ok());
    }

    #[test]
    fn soul_v1_missing_name_rejected() {
        let d = doc(
            HybridSchemaKind::SoulV1,
            r#"{"schema":"epistemos.soul.v1","pillars":[]}"#,
        );
        assert_eq!(
            validate_soul_v1(&d).unwrap_err(),
            SchemaFieldError::MissingField { field: "name" }
        );
    }

    #[test]
    fn soul_v1_missing_pillars_rejected() {
        let d = doc(
            HybridSchemaKind::SoulV1,
            r#"{"schema":"epistemos.soul.v1","name":"Pilot"}"#,
        );
        assert_eq!(
            validate_soul_v1(&d).unwrap_err(),
            SchemaFieldError::MissingField { field: "pillars" }
        );
    }

    #[test]
    fn soul_v1_pillars_wrong_type_rejected() {
        let d = doc(
            HybridSchemaKind::SoulV1,
            r#"{"schema":"epistemos.soul.v1","name":"Pilot","pillars":"truth"}"#,
        );
        assert_eq!(
            validate_soul_v1(&d).unwrap_err(),
            SchemaFieldError::FieldWrongType { field: "pillars", expected: "array" }
        );
    }

    #[test]
    fn skill_v1_well_formed_passes() {
        let d = doc(
            HybridSchemaKind::SkillV1,
            r#"{"schema":"epistemos.skill.v1","name":"x","summary":"y","version":"1.0.0"}"#,
        );
        assert!(validate_skill_v1(&d).is_ok());
    }

    #[test]
    fn skill_v1_missing_version_rejected() {
        let d = doc(
            HybridSchemaKind::SkillV1,
            r#"{"schema":"epistemos.skill.v1","name":"x","summary":"y"}"#,
        );
        assert_eq!(
            validate_skill_v1(&d).unwrap_err(),
            SchemaFieldError::MissingField { field: "version" }
        );
    }

    #[test]
    fn episode_v1_well_formed_passes() {
        let d = doc(
            HybridSchemaKind::EpisodeV1,
            r#"{"schema":"epistemos.episode.v1","id":"e1","timestamp":"2026-05-16T00:00:00Z","summary":"x"}"#,
        );
        assert!(validate_episode_v1(&d).is_ok());
    }

    #[test]
    fn episode_v1_missing_timestamp_rejected() {
        let d = doc(
            HybridSchemaKind::EpisodeV1,
            r#"{"schema":"epistemos.episode.v1","id":"e1","summary":"x"}"#,
        );
        assert_eq!(
            validate_episode_v1(&d).unwrap_err(),
            SchemaFieldError::MissingField { field: "timestamp" }
        );
    }

    #[test]
    fn semantic_v1_well_formed_passes() {
        let d = doc(
            HybridSchemaKind::SemanticV1,
            r#"{"schema":"epistemos.semantic.v1","id":"s1","claim":"x"}"#,
        );
        assert!(validate_semantic_v1(&d).is_ok());
    }

    #[test]
    fn semantic_v1_missing_claim_rejected() {
        let d = doc(
            HybridSchemaKind::SemanticV1,
            r#"{"schema":"epistemos.semantic.v1","id":"s1"}"#,
        );
        assert_eq!(
            validate_semantic_v1(&d).unwrap_err(),
            SchemaFieldError::MissingField { field: "claim" }
        );
    }

    #[test]
    fn validate_per_schema_dispatches() {
        let d = doc(
            HybridSchemaKind::SemanticV1,
            r#"{"schema":"epistemos.semantic.v1","id":"s1","claim":"x"}"#,
        );
        assert!(validate_per_schema(&d).is_ok());

        let d_bad = doc(
            HybridSchemaKind::SemanticV1,
            r#"{"schema":"epistemos.semantic.v1"}"#,
        );
        assert!(matches!(
            validate_per_schema(&d_bad).unwrap_err(),
            SchemaFieldError::MissingField { field: "id" }
        ));
    }

    #[test]
    fn frontmatter_not_object_rejected() {
        let d = doc(HybridSchemaKind::SoulV1, "[1, 2, 3]");
        assert_eq!(validate_soul_v1(&d).unwrap_err(), SchemaFieldError::FrontmatterNotObject);
    }

    #[test]
    fn frontmatter_invalid_json_rejected() {
        let d = doc(HybridSchemaKind::SoulV1, "not json {");
        assert_eq!(validate_soul_v1(&d).unwrap_err(), SchemaFieldError::FrontmatterJsonInvalid);
    }

    #[test]
    fn field_wrong_type_for_string_field_rejected() {
        let d = doc(
            HybridSchemaKind::SoulV1,
            r#"{"name":42,"pillars":[]}"#,
        );
        assert_eq!(
            validate_soul_v1(&d).unwrap_err(),
            SchemaFieldError::FieldWrongType { field: "name", expected: "string" }
        );
    }

    // ── diagnostic surface (iter 162) ────────────────────────────────────────

    #[test]
    fn required_fields_match_validator_for_each_schema() {
        // Cross-surface invariant: a doc missing one of the listed
        // required_fields gets a MissingField error from validate_per_schema,
        // and the missing-field name is one of those listed.
        for kind in HybridSchemaKind::ALL.iter().copied() {
            for &field in kind.required_fields() {
                // Build a minimal doc with ALL required fields EXCEPT `field`.
                let mut obj = serde_json::Map::new();
                obj.insert("schema".into(), serde_json::Value::String(kind.code().into()));
                for &other in kind.required_fields() {
                    if other == field {
                        continue;
                    }
                    if kind == HybridSchemaKind::SoulV1 && other == "pillars" {
                        obj.insert(other.into(), serde_json::Value::Array(vec![]));
                    } else {
                        obj.insert(other.into(), serde_json::Value::String("v".into()));
                    }
                }
                let fm = serde_json::Value::Object(obj).to_string();
                let d = doc(kind, &fm);
                let err = validate_per_schema(&d).unwrap_err();
                assert!(
                    matches!(err, SchemaFieldError::MissingField { field: f } if f == field),
                    "schema={:?} missing field={} got err={:?}",
                    kind, field, err,
                );
            }
        }
    }

    #[test]
    fn is_temporal_only_for_episode() {
        for kind in HybridSchemaKind::ALL.iter().copied() {
            assert_eq!(kind.is_temporal(), kind == HybridSchemaKind::EpisodeV1);
        }
    }

    #[test]
    fn hybrid_memory_error_cause_distinct() {
        let variants = [
            HybridMemoryError::MissingFrontmatterOpenFence,
            HybridMemoryError::MissingFrontmatterCloseFence,
            HybridMemoryError::MissingSchemaField,
            HybridMemoryError::UnknownSchemaKind { code: "x".into() },
            HybridMemoryError::EmptyDocument,
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 5);
    }

    #[test]
    fn hybrid_memory_error_classifiers_partition() {
        let variants = [
            HybridMemoryError::MissingFrontmatterOpenFence,
            HybridMemoryError::MissingFrontmatterCloseFence,
            HybridMemoryError::MissingSchemaField,
            HybridMemoryError::UnknownSchemaKind { code: "x".into() },
            HybridMemoryError::EmptyDocument,
        ];
        // Cross-surface invariant: is_fence_error XOR is_schema_error.
        for e in &variants {
            assert_ne!(e.is_fence_error(), e.is_schema_error());
        }
        assert_eq!(variants.iter().filter(|e| e.is_fence_error()).count(), 3);
        assert_eq!(variants.iter().filter(|e| e.is_schema_error()).count(), 2);
    }

    #[test]
    fn schema_field_error_cause_distinct() {
        let variants = [
            SchemaFieldError::FrontmatterJsonInvalid,
            SchemaFieldError::FrontmatterNotObject,
            SchemaFieldError::MissingField { field: "name" },
            SchemaFieldError::FieldWrongType { field: "name", expected: "string" },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 4);
    }

    #[test]
    fn schema_field_error_classifiers_partition() {
        let variants = [
            SchemaFieldError::FrontmatterJsonInvalid,
            SchemaFieldError::FrontmatterNotObject,
            SchemaFieldError::MissingField { field: "name" },
            SchemaFieldError::FieldWrongType { field: "name", expected: "string" },
        ];
        // Cross-surface invariant: is_envelope_error XOR is_field_error.
        for e in &variants {
            assert_ne!(e.is_envelope_error(), e.is_field_error());
        }
        assert_eq!(variants.iter().filter(|e| e.is_envelope_error()).count(), 2);
        assert_eq!(variants.iter().filter(|e| e.is_field_error()).count(), 2);
    }

    #[test]
    fn field_accessor_extracts_field_name() {
        assert_eq!(
            SchemaFieldError::MissingField { field: "name" }.field(),
            Some("name"),
        );
        assert_eq!(
            SchemaFieldError::FieldWrongType { field: "id", expected: "string" }.field(),
            Some("id"),
        );
        assert_eq!(SchemaFieldError::FrontmatterJsonInvalid.field(), None);
        assert_eq!(SchemaFieldError::FrontmatterNotObject.field(), None);
    }
}
