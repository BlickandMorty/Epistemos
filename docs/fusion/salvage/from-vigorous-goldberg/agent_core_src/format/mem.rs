//! `.mem` — single-file fusion: line-1 `---{json}---` header + Markdown body.
//!
//! Plan: §2.2 (header fence + JSON Schema), §24.3 (13-type MemType enum),
//! §24.2 (verbatim invariant — body never rewritten in place).
//!
//! Format spec:
//! - Line 1 is exactly `---{json}---` where `{json}` is a JSON object that
//!   schema-validates against `mem.v1.json`. `head -1` yields the header,
//!   `tail -n +2` yields the body — no parser needed for either side.
//! - Lines 2..N are the Markdown body, byte-exact verbatim.
//! - The format is line-oriented for incremental indexing.

use chrono::{DateTime, Utc};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

use super::{validate_against, FormatError};

/// Mandatory `$schema` const value for v1 mem entries. Mirrors the JSON
/// Schema's `$id` and is enforced both by the schema (`const`) and at parse
/// time (defence in depth).
pub const MEM_V1_ID: &str = "epistemos://schemas/mem.v1.json";

/// 13-value typed memory enum per §24.3 — Mercury's 10 + Epistemos's 3.
#[derive(Serialize, Deserialize, JsonSchema, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "lowercase")]
pub enum MemType {
    // Mercury's 10 typed categories
    Identity,
    Preference,
    Goal,
    Project,
    Habit,
    Decision,
    Constraint,
    Relationship,
    Episode,
    Reflection,
    // Epistemos extensions for PKM
    Capture,
    Semantic,
    Procedural,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[serde(rename_all = "lowercase")]
pub enum Actor {
    User,
    Agent,
    System,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq, Default)]
#[serde(deny_unknown_fields)]
pub struct Signals {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub access_count: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_accessed: Option<DateTime<Utc>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub explicit_importance: Option<f64>,
}

impl Signals {
    pub fn is_empty(&self) -> bool {
        self.access_count.is_none()
            && self.last_accessed.is_none()
            && self.explicit_importance.is_none()
    }
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq, Default)]
#[serde(deny_unknown_fields)]
pub struct Provenance {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub source: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub device: Option<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tool_chain: Vec<String>,
}

impl Provenance {
    pub fn is_empty(&self) -> bool {
        self.source.is_none() && self.device.is_none() && self.tool_chain.is_empty()
    }
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct MemHeader {
    #[serde(rename = "$schema")]
    pub schema: String,
    pub id: String,
    #[serde(rename = "type")]
    pub mem_type: MemType,
    pub ts: DateTime<Utc>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub actor: Option<Actor>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tags: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub links: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub salience: Option<f64>,
    #[serde(default, skip_serializing_if = "Signals::is_empty")]
    pub signals: Signals,
    #[serde(default, skip_serializing_if = "Provenance::is_empty")]
    pub provenance: Provenance,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub schema_version: Option<u32>,
}

impl MemHeader {
    /// Build a fresh header with the given id + type. ts = now, schema_version = 1.
    pub fn fresh(id: String, mem_type: MemType) -> Self {
        Self {
            schema: MEM_V1_ID.to_string(),
            id,
            mem_type,
            ts: Utc::now(),
            actor: None,
            tags: Vec::new(),
            links: Vec::new(),
            salience: None,
            signals: Signals::default(),
            provenance: Provenance::default(),
            schema_version: Some(1),
        }
    }

    /// Generate a fresh ULID id then build a header.
    pub fn fresh_with_ulid(mem_type: MemType) -> Self {
        Self::fresh(ulid::Ulid::new().to_string(), mem_type)
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct MemFile {
    pub header: MemHeader,
    /// Markdown body. Verbatim invariant per §24.2 — round-trip preserves
    /// the bytes exactly. The system NEVER rewrites this in place; derived
    /// artifacts (summaries, extractions) live in their own `.mem` files
    /// with provenance pointers back here.
    pub body: String,
}

impl MemFile {
    /// Parse `---{json}---\n<body>` into header + verbatim body.
    /// The body is everything after the first `\n`, byte-exact.
    pub fn parse(input: &str) -> Result<Self, FormatError> {
        let (header_line, body) = match input.find('\n') {
            Some(idx) => (&input[..idx], &input[idx + 1..]),
            None => (input, ""),
        };
        let header_line = header_line.trim_end_matches('\r');

        let inner = parse_header_fence(header_line)?;
        let header: MemHeader = serde_json::from_str(inner)
            .map_err(|e| FormatError::MemHeaderJson(e.to_string()))?;

        if header.schema != MEM_V1_ID {
            return Err(FormatError::SchemaValidation(format!(
                "$schema mismatch: expected {} got {}",
                MEM_V1_ID, header.schema
            )));
        }

        Ok(Self {
            header,
            body: body.to_string(),
        })
    }

    /// Serialize to `---{json}---\n<body>`. Body bytes are written verbatim.
    pub fn to_string(&self) -> Result<String, FormatError> {
        if self.header.schema != MEM_V1_ID {
            return Err(FormatError::SchemaValidation(format!(
                "header.schema must be {}, got {}",
                MEM_V1_ID, self.header.schema
            )));
        }
        let header_json = serde_json::to_string(&self.header)?;
        Ok(format!("---{}---\n{}", header_json, self.body))
    }

    /// Schema-validate the header against the embedded mem.v1.json
    /// (Draft 2020-12). Body is not validated — Markdown is unconstrained.
    pub fn validate(&self) -> Result<(), FormatError> {
        let header_value = serde_json::to_value(&self.header)?;
        validate_against(super::schemas::MEM_V1, &header_value)
    }
}

fn parse_header_fence(line: &str) -> Result<&str, FormatError> {
    let stripped = line
        .strip_prefix("---")
        .and_then(|s| s.strip_suffix("---"))
        .ok_or_else(|| {
            FormatError::MalformedMemHeader(format!(
                "expected ---{{json}}---, got {:?}",
                line
            ))
        })?;
    if !stripped.starts_with('{') || !stripped.ends_with('}') {
        return Err(FormatError::MalformedMemHeader(format!(
            "header inner must be a JSON object, got {:?}",
            stripped
        )));
    }
    Ok(stripped)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_header() -> MemHeader {
        MemHeader {
            schema: MEM_V1_ID.to_string(),
            id: "01HX42KQM3R7N9PVK0X8Z3W5MQ".to_string(),
            mem_type: MemType::Capture,
            ts: "2026-04-29T01:00:00Z".parse().unwrap(),
            actor: Some(Actor::User),
            tags: vec!["routing".to_string(), "quick-capture".to_string()],
            links: vec!["c_4f2a".to_string()],
            salience: Some(0.62),
            signals: Signals {
                access_count: Some(3),
                last_accessed: Some("2026-04-29T01:05:00Z".parse().unwrap()),
                explicit_importance: None,
            },
            provenance: Provenance {
                source: Some("capture.text".to_string()),
                device: Some("M4Pro".to_string()),
                tool_chain: vec!["structure.route_capture".to_string()],
            },
            schema_version: Some(1),
        }
    }

    #[test]
    fn round_trip_preserves_header_and_body() {
        let original = MemFile {
            header: sample_header(),
            body: "# Routing\n\nThis is the body.\n".to_string(),
        };
        let serialized = original.to_string().unwrap();
        let reparsed = MemFile::parse(&serialized).unwrap();
        assert_eq!(reparsed.header, original.header);
        assert_eq!(reparsed.body, original.body, "verbatim invariant §24.2");
    }

    #[test]
    fn body_is_byte_exact_for_diverse_unicode() {
        let weird_bodies = [
            "",
            "\n",
            "single line no newline",
            "trailing\n",
            "  leading and trailing  \n  ",
            "\u{200B}zero-width\u{200B}joiner",
            "emoji 🚀 中文 العربية ñoño",
            "code:\n```rust\nfn x() {}\n```\n",
            "  \t\tmixed whitespace\t\t  \n",
            "---looks like a fence but isn't because it's body---\n",
            "\nleading newline body",
        ];
        for body in weird_bodies {
            let mem = MemFile {
                header: sample_header(),
                body: body.to_string(),
            };
            let s = mem.to_string().unwrap();
            let p = MemFile::parse(&s).unwrap();
            assert_eq!(p.body, body, "verbatim broke for body: {:?}", body);
        }
    }

    #[test]
    fn parse_rejects_malformed_header() {
        let bad = [
            "no fence at all\nbody",
            "---no json object---\nbody",
            "---{not valid json}---\nbody",
            "--{missing dash}---\nbody",
            "---{ok}-\nbody",
        ];
        for input in bad {
            let r = MemFile::parse(input);
            assert!(r.is_err(), "should reject: {:?}", input);
        }
    }

    #[test]
    fn parse_rejects_wrong_schema_id() {
        let wrong = format!(
            "---{}---\nbody",
            serde_json::json!({
                "$schema": "epistemos://schemas/wrong.v1.json",
                "id": "01HX42KQM3R7N9PVK0X8Z3W5MQ",
                "type": "capture",
                "ts": "2026-04-29T01:00:00Z"
            })
        );
        let r = MemFile::parse(&wrong);
        assert!(r.is_err());
    }

    #[test]
    fn schema_validates_a_minimal_valid_header() {
        let mem = MemFile {
            header: MemHeader::fresh(
                "01HX42KQM3R7N9PVK0X8Z3W5MQ".to_string(),
                MemType::Capture,
            ),
            body: "minimal\n".to_string(),
        };
        mem.validate().expect("minimal header must validate");
    }

    #[test]
    fn schema_rejects_non_ulid_id() {
        let bad_value = serde_json::json!({
            "$schema": MEM_V1_ID,
            "id": "not-a-ulid",
            "type": "capture",
            "ts": "2026-04-29T01:00:00Z"
        });
        let r = super::super::validate_against(super::super::schemas::MEM_V1, &bad_value);
        assert!(r.is_err(), "non-ULID id must be rejected by schema");
    }

    #[test]
    fn schema_rejects_unknown_fields() {
        let bad_value = serde_json::json!({
            "$schema": MEM_V1_ID,
            "id": "01HX42KQM3R7N9PVK0X8Z3W5MQ",
            "type": "capture",
            "ts": "2026-04-29T01:00:00Z",
            "extra_field": "should be rejected"
        });
        let r = super::super::validate_against(super::super::schemas::MEM_V1, &bad_value);
        assert!(r.is_err(), "additionalProperties:false must reject extras");
    }

    #[test]
    fn schema_rejects_invalid_type_enum() {
        let bad_value = serde_json::json!({
            "$schema": MEM_V1_ID,
            "id": "01HX42KQM3R7N9PVK0X8Z3W5MQ",
            "type": "not_a_real_type",
            "ts": "2026-04-29T01:00:00Z"
        });
        let r = super::super::validate_against(super::super::schemas::MEM_V1, &bad_value);
        assert!(r.is_err());
    }

    #[test]
    fn schema_rejects_missing_required_fields() {
        // Missing `ts`.
        let bad_value = serde_json::json!({
            "$schema": MEM_V1_ID,
            "id": "01HX42KQM3R7N9PVK0X8Z3W5MQ",
            "type": "capture"
        });
        let r = super::super::validate_against(super::super::schemas::MEM_V1, &bad_value);
        assert!(r.is_err());
    }

    #[test]
    fn schema_rejects_salience_out_of_range() {
        let bad_value = serde_json::json!({
            "$schema": MEM_V1_ID,
            "id": "01HX42KQM3R7N9PVK0X8Z3W5MQ",
            "type": "capture",
            "ts": "2026-04-29T01:00:00Z",
            "salience": 1.5
        });
        let r = super::super::validate_against(super::super::schemas::MEM_V1, &bad_value);
        assert!(r.is_err());
    }

    #[test]
    fn schema_rejects_too_many_tags() {
        let many_tags: Vec<String> = (0..17).map(|i| format!("t{}", i)).collect();
        let bad_value = serde_json::json!({
            "$schema": MEM_V1_ID,
            "id": "01HX42KQM3R7N9PVK0X8Z3W5MQ",
            "type": "capture",
            "ts": "2026-04-29T01:00:00Z",
            "tags": many_tags
        });
        let r = super::super::validate_against(super::super::schemas::MEM_V1, &bad_value);
        assert!(r.is_err(), "tags maxItems is 16");
    }

    #[test]
    fn all_thirteen_mem_types_round_trip_and_validate() {
        for mem_type in [
            MemType::Identity,
            MemType::Preference,
            MemType::Goal,
            MemType::Project,
            MemType::Habit,
            MemType::Decision,
            MemType::Constraint,
            MemType::Relationship,
            MemType::Episode,
            MemType::Reflection,
            MemType::Capture,
            MemType::Semantic,
            MemType::Procedural,
        ] {
            let header = MemHeader::fresh(ulid::Ulid::new().to_string(), mem_type);
            let mem = MemFile {
                header: header.clone(),
                body: format!("# {:?}\n", mem_type),
            };
            let s = mem.to_string().unwrap();
            let p = MemFile::parse(&s).unwrap();
            assert_eq!(p.header.mem_type, mem_type);
            mem.validate()
                .unwrap_or_else(|e| panic!("MemType::{:?} failed validation: {}", mem_type, e));
        }
    }

    #[test]
    fn fresh_with_ulid_produces_validatable_header() {
        let h = MemHeader::fresh_with_ulid(MemType::Capture);
        assert_eq!(h.id.len(), 26);
        let mem = MemFile {
            header: h,
            body: "x".to_string(),
        };
        mem.validate().expect("ulid::Ulid::new() must be schema-valid");
    }

    #[test]
    fn header_serializes_with_dollar_schema_first_or_present() {
        // Sanity: serialized JSON contains the $schema field.
        let h = MemHeader::fresh("01HX42KQM3R7N9PVK0X8Z3W5MQ".to_string(), MemType::Capture);
        let s = serde_json::to_string(&h).unwrap();
        assert!(s.contains("\"$schema\":\"epistemos://schemas/mem.v1.json\""));
        assert!(s.contains("\"type\":\"capture\""));
    }
}

// Property tests — Phase 1 plan exit criterion (§11): "Round-trip property
// tests: parse → serialize → parse must be identity."
#[cfg(test)]
mod proptests {
    use super::*;
    use proptest::prelude::*;

    proptest! {
        /// Verbatim invariant §24.2 stated as a property: every UTF-8 body
        /// survives parse → serialize → parse byte-exactly.
        #[test]
        fn verbatim_body_round_trips(
            body in proptest::collection::vec(any::<char>(), 0..200)
                .prop_map(|chars| chars.into_iter().collect::<String>())
        ) {
            let header = MemHeader::fresh(
                ulid::Ulid::new().to_string(),
                MemType::Capture,
            );
            let mem = MemFile { header: header.clone(), body: body.clone() };
            let s = mem.to_string().unwrap();
            let p = MemFile::parse(&s).unwrap();
            prop_assert_eq!(&p.body, &body);
            prop_assert_eq!(&p.header, &header);
        }

        /// Parser ignores any quantity of body lines starting with `---` —
        /// only line 1 is the fenced header.
        #[test]
        fn fence_lookalikes_in_body_are_just_text(
            n in 0usize..20
        ) {
            let header = MemHeader::fresh(
                ulid::Ulid::new().to_string(),
                MemType::Capture,
            );
            let body: String = std::iter::repeat("---{\"fake\":true}---\n")
                .take(n)
                .collect();
            let mem = MemFile { header: header.clone(), body: body.clone() };
            let s = mem.to_string().unwrap();
            let p = MemFile::parse(&s).unwrap();
            prop_assert_eq!(p.body, body);
        }
    }
}
