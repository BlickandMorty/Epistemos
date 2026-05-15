//! Hybrid MD+JSON memory schemas — typed Rust mirrors of the canonical
//! JSON schemas under `agent_core/schemas/epistemos.*.v1.schema.json`.
//!
//! Per `docs/MAS_COMPLETE_FUSION_IMPLEMENTATION_PLAN_2026_05_14.md` §B.5
//! and `docs/fusion/jordan's research/deterministicapp.md` §5.
//!
//! These types are the validation surface for hybrid-memory writes
//! (`epistemos.soul.v1`, `epistemos.skill.v1`, `epistemos.episode.v1`,
//! `epistemos.semantic.v1`). Production callers — `MutationEnvelope`
//! schema-validated writes, NightBrain task bodies, Skills marketplace
//! tools, Provenance Console renderers — deserialize untrusted JSON
//! through [`validate_epistemos_payload`] and either get a typed
//! payload back or a structured [`SchemaValidationError`] they can
//! surface to the user.
//!
//! Wire-format identity with the JSON schemas is enforced by:
//!   - `#[serde(deny_unknown_fields)]` ≡ schema `additionalProperties: false`
//!   - Required Rust fields (non-`Option`) ≡ schema `required` list
//!   - Rust enums ≡ schema `enum` constraints
//!   - Const string fields ≡ schema `const`
//!   - 12-char id pattern guarded post-parse via [`ID_PATTERN`]
//!
//! Round-trip parity tests live at `agent_core/tests/schemas_roundtrip.rs`.
//! That suite (a) loads each disk schema as JSON without error,
//! (b) parses a known-good fixture through the matching Rust type,
//! (c) rejects a known-bad fixture (missing required field / unknown
//! key / malformed id), and (d) round-trips the typed payload back to
//! JSON without loss.

use std::sync::OnceLock;

use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use thiserror::Error;

/// Canonical 12-char lowercase-alphanumeric id pattern used across
/// every `epistemos.X.v1` schema (`soul_id`, `skill_id`, `episode_id`,
/// `fact_id`, linked-episode ids, `retracts`, `derives_from`).
pub const ID_PATTERN_STR: &str = "^[a-z0-9]{12}$";

fn id_regex() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| Regex::new(ID_PATTERN_STR).expect("ID_PATTERN_STR is a valid regex"))
}

/// Validate the 12-char id pattern post-parse. Returns the id back on
/// success so callers can compose with `?`.
pub fn validate_id(field_name: &'static str, id: &str) -> Result<(), SchemaValidationError> {
    if id_regex().is_match(id) {
        Ok(())
    } else {
        Err(SchemaValidationError::InvalidIdPattern {
            field: field_name,
            value: id.to_string(),
        })
    }
}

/// Schema-rev discriminator for the four hybrid-memory schemas.
/// Matches the `schema_rev` const string in each `.schema.json`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum EpistemosSchemaRev {
    #[serde(rename = "epistemos.soul.v1")]
    SoulV1,
    #[serde(rename = "epistemos.skill.v1")]
    SkillV1,
    #[serde(rename = "epistemos.episode.v1")]
    EpisodeV1,
    #[serde(rename = "epistemos.semantic.v1")]
    SemanticV1,
}

impl EpistemosSchemaRev {
    /// Canonical wire-format string used in the JSON `schema_rev` field.
    pub fn as_str(self) -> &'static str {
        match self {
            Self::SoulV1 => "epistemos.soul.v1",
            Self::SkillV1 => "epistemos.skill.v1",
            Self::EpisodeV1 => "epistemos.episode.v1",
            Self::SemanticV1 => "epistemos.semantic.v1",
        }
    }
}

/// Typed payload — one variant per `epistemos.X.v1` schema. The
/// discriminator is the `schema_rev` field on each shape (matched via
/// `#[serde(tag = "schema_rev")]`), so a single
/// `serde_json::from_value::<EpistemosPayload>(v)` dispatches to the
/// right variant and validates the rest in one pass.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "schema_rev")]
pub enum EpistemosPayload {
    #[serde(rename = "epistemos.soul.v1")]
    Soul(Soul),
    #[serde(rename = "epistemos.skill.v1")]
    Skill(Skill),
    #[serde(rename = "epistemos.episode.v1")]
    Episode(Episode),
    #[serde(rename = "epistemos.semantic.v1")]
    Semantic(Semantic),
}

impl EpistemosPayload {
    /// Schema discriminator for the payload variant.
    pub fn rev(&self) -> EpistemosSchemaRev {
        match self {
            Self::Soul(_) => EpistemosSchemaRev::SoulV1,
            Self::Skill(_) => EpistemosSchemaRev::SkillV1,
            Self::Episode(_) => EpistemosSchemaRev::EpisodeV1,
            Self::Semantic(_) => EpistemosSchemaRev::SemanticV1,
        }
    }
}

/// Validate an untrusted JSON value against the hybrid-memory schemas.
///
/// Returns the typed [`EpistemosPayload`] on success or a structured
/// [`SchemaValidationError`] that callers can surface to the user.
///
/// The validator enforces:
///   - `additionalProperties: false` via serde `deny_unknown_fields`
///   - required fields via non-`Option` Rust fields
///   - enum constraints via Rust enums
///   - the 12-char id pattern on every id field declared in the schema
pub fn validate_epistemos_payload(
    value: &Value,
) -> Result<EpistemosPayload, SchemaValidationError> {
    // Pre-flight: surface a clear error if `schema_rev` is missing or
    // not a string, before serde's "missing field" message kicks in
    // (which is far less actionable for an end-user).
    let rev_value = value.get("schema_rev").ok_or(SchemaValidationError::MissingSchemaRev)?;
    let rev_str = rev_value
        .as_str()
        .ok_or(SchemaValidationError::SchemaRevNotString)?;
    let _rev: EpistemosSchemaRev = match rev_str {
        "epistemos.soul.v1" => EpistemosSchemaRev::SoulV1,
        "epistemos.skill.v1" => EpistemosSchemaRev::SkillV1,
        "epistemos.episode.v1" => EpistemosSchemaRev::EpisodeV1,
        "epistemos.semantic.v1" => EpistemosSchemaRev::SemanticV1,
        other => {
            return Err(SchemaValidationError::UnknownSchemaRev {
                value: other.to_string(),
            });
        }
    };

    let payload: EpistemosPayload = serde_json::from_value(value.clone())
        .map_err(|e| SchemaValidationError::Deserialize(e.to_string()))?;

    // Post-parse pattern guards. The schemas require `^[a-z0-9]{12}$`
    // on every id field; serde alone can't express that constraint.
    match &payload {
        EpistemosPayload::Soul(s) => {
            validate_id("soul_id", &s.soul_id)?;
        }
        EpistemosPayload::Skill(s) => {
            validate_id("skill_id", &s.skill_id)?;
        }
        EpistemosPayload::Episode(e) => {
            validate_id("episode_id", &e.episode_id)?;
            for linked in &e.linked_episodes {
                validate_id("linked_episodes[]", linked)?;
            }
        }
        EpistemosPayload::Semantic(s) => {
            validate_id("fact_id", &s.fact_id)?;
            for retracted in &s.retracts {
                validate_id("retracts[]", retracted)?;
            }
            for derived in &s.derives_from {
                validate_id("derives_from[]", derived)?;
            }
        }
    }

    Ok(payload)
}

/// Structured validation error returned by [`validate_epistemos_payload`].
#[derive(Debug, Clone, Error, PartialEq)]
pub enum SchemaValidationError {
    #[error("missing required field `schema_rev`")]
    MissingSchemaRev,
    #[error("field `schema_rev` is not a string")]
    SchemaRevNotString,
    #[error("unknown schema_rev `{value}` — expected one of: epistemos.soul.v1, epistemos.skill.v1, epistemos.episode.v1, epistemos.semantic.v1")]
    UnknownSchemaRev { value: String },
    #[error("deserialization failed: {0}")]
    Deserialize(String),
    #[error("field `{field}` has value `{value}` which does not match the 12-char lowercase-alphanumeric id pattern `^[a-z0-9]{{12}}$`")]
    InvalidIdPattern {
        field: &'static str,
        value: String,
    },
}

// ---------------------------------------------------------------------
// epistemos.soul.v1
// ---------------------------------------------------------------------

/// Mirror of `agent_core/schemas/epistemos.soul.v1.schema.json`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Soul {
    pub soul_id: String,
    pub model_id: String,
    pub identity: SoulIdentity,
    pub preferences: SoulPreferences,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub instructions: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub knowledge_profile: Option<String>,
    pub updated_at: String,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub updated_by: Option<SoulUpdatedBy>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SoulIdentity {
    pub name: String,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub pronouns: Option<String>,
    pub voice: String,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub stance: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct SoulPreferences {
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub timezone: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub language: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub tone: Option<SoulTone>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub citation_required: Option<bool>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SoulTone {
    Concise,
    Neutral,
    Elaborate,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SoulUpdatedBy {
    User,
    Agent,
    Nightbrain,
    Import,
}

// ---------------------------------------------------------------------
// epistemos.skill.v1
// ---------------------------------------------------------------------

/// Mirror of `agent_core/schemas/epistemos.skill.v1.schema.json`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Skill {
    pub skill_id: String,
    pub name: String,
    pub description: String,
    pub body: SkillBody,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tags: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub requires_capabilities: Vec<SkillCapability>,
    pub created_at: String,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub updated_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub discovered_via: Option<SkillDiscoveredVia>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub execution_count: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub success_count: Option<u64>,
}

/// `oneOf` over `{kind: "code", language, source, inputs}` and
/// `{kind: "plan", steps}` in the JSON schema. Matched by `kind`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "lowercase", deny_unknown_fields)]
pub enum SkillBody {
    Code {
        language: SkillCodeLanguage,
        source: String,
        #[serde(default, skip_serializing_if = "Vec::is_empty")]
        inputs: Vec<Value>,
    },
    Plan {
        steps: Vec<SkillPlanStep>,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SkillCodeLanguage {
    Javascript,
    Python,
    Wasm,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SkillPlanStep {
    pub tool: String,
    pub arguments: Value,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub depends_on: Vec<u32>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SkillCapability {
    #[serde(rename = "vault.read")]
    VaultRead,
    #[serde(rename = "vault.write")]
    VaultWrite,
    #[serde(rename = "file.read")]
    FileRead,
    #[serde(rename = "file.write")]
    FileWrite,
    #[serde(rename = "web.fetch")]
    WebFetch,
    #[serde(rename = "web.search")]
    WebSearch,
    #[serde(rename = "memory.curated")]
    MemoryCurated,
    #[serde(rename = "computer_use")]
    ComputerUse,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SkillDiscoveredVia {
    User,
    SelfEvolution,
    Import,
    Marketplace,
}

// ---------------------------------------------------------------------
// epistemos.episode.v1
// ---------------------------------------------------------------------

/// Mirror of `agent_core/schemas/epistemos.episode.v1.schema.json`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Episode {
    pub episode_id: String,
    pub occurred_at: String,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub recorded_at: Option<String>,
    pub kind: EpisodeKind,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub actor: Option<EpisodeActor>,
    pub content: String,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub context: Option<EpisodeContext>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub salience: Option<f64>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tags: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub linked_episodes: Vec<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EpisodeKind {
    UserCapture,
    UserAction,
    AgentResponse,
    AgentToolCall,
    SystemEvent,
    SessionSummary,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum EpisodeActor {
    User,
    Agent,
    System,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct EpisodeContext {
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub vault_path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub chat_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub tool_call_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub location: Option<String>,
}

// ---------------------------------------------------------------------
// epistemos.semantic.v1
// ---------------------------------------------------------------------

/// Mirror of `agent_core/schemas/epistemos.semantic.v1.schema.json`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Semantic {
    pub fact_id: String,
    pub predicate: String,
    pub subject: String,
    pub object: String,
    pub confidence: f64,
    pub claim_kind: ClaimKind,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub evidence: Vec<SemanticEvidence>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub established_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub updated_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub retracted_at: Option<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub retracts: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub derives_from: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tags: Vec<String>,
}

/// 9-arm Kleene K3 claim classifier per `helios v5 first.md` §1.5 —
/// the π field of the Resonance Σ-signature.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ClaimKind {
    VerifiedEmpirical,
    VerifiedMathematical,
    VerifiedCodeInvariant,
    PlausibleEmpirical,
    PlausibleCausal,
    Speculative,
    RefutedEmpirical,
    RefutedMathematical,
    BlockedSafety,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SemanticEvidence {
    pub kind: SemanticEvidenceKind,
    #[serde(rename = "ref")]
    pub r#ref: String,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub verified_at: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SemanticEvidenceKind {
    Note,
    Url,
    LedgerEntry,
    UserAttestation,
    ToolObservation,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn good_soul_json() -> Value {
        serde_json::json!({
            "schema_rev": "epistemos.soul.v1",
            "soul_id": "abcdef012345",
            "model_id": "qwen3-4b-4bit",
            "identity": {
                "name": "Jordan",
                "voice": "concise / no hedging / cites sources"
            },
            "preferences": {
                "tone": "concise",
                "citation_required": true
            },
            "updated_at": "2026-05-15T20:00:00Z"
        })
    }

    #[test]
    fn validates_a_minimal_soul_payload() {
        let v = good_soul_json();
        let payload = validate_epistemos_payload(&v).expect("valid soul payload");
        assert_eq!(payload.rev(), EpistemosSchemaRev::SoulV1);
        if let EpistemosPayload::Soul(s) = payload {
            assert_eq!(s.soul_id, "abcdef012345");
            assert_eq!(s.identity.name, "Jordan");
        } else {
            panic!("expected Soul variant");
        }
    }

    #[test]
    fn rejects_missing_schema_rev() {
        let mut v = good_soul_json();
        v.as_object_mut().unwrap().remove("schema_rev");
        let err = validate_epistemos_payload(&v).expect_err("must reject missing schema_rev");
        assert!(matches!(err, SchemaValidationError::MissingSchemaRev));
    }

    #[test]
    fn rejects_unknown_schema_rev() {
        let mut v = good_soul_json();
        v["schema_rev"] = Value::String("epistemos.soul.v999".to_string());
        let err = validate_epistemos_payload(&v).expect_err("must reject unknown rev");
        assert!(matches!(err, SchemaValidationError::UnknownSchemaRev { .. }));
    }

    #[test]
    fn rejects_unknown_top_level_field() {
        let mut v = good_soul_json();
        v["sneaky"] = Value::String("payload".to_string());
        let err = validate_epistemos_payload(&v).expect_err("deny_unknown_fields must fire");
        assert!(
            matches!(err, SchemaValidationError::Deserialize(ref msg) if msg.contains("sneaky")),
            "expected Deserialize error mentioning `sneaky`, got: {err:?}"
        );
    }

    #[test]
    fn rejects_malformed_id_pattern() {
        let mut v = good_soul_json();
        v["soul_id"] = Value::String("SHORT".to_string());
        let err = validate_epistemos_payload(&v).expect_err("must reject bad id");
        match err {
            SchemaValidationError::InvalidIdPattern { field, value } => {
                assert_eq!(field, "soul_id");
                assert_eq!(value, "SHORT");
            }
            other => panic!("expected InvalidIdPattern, got {other:?}"),
        }
    }

    #[test]
    fn semantic_payload_validates_9_arm_claim_kind() {
        let v = serde_json::json!({
            "schema_rev": "epistemos.semantic.v1",
            "fact_id": "111122223333",
            "predicate": "prefers",
            "subject": "user",
            "object": "pacific_time",
            "confidence": 1.0,
            "claim_kind": "verified_empirical"
        });
        let payload = validate_epistemos_payload(&v).expect("valid semantic payload");
        if let EpistemosPayload::Semantic(s) = payload {
            assert_eq!(s.claim_kind, ClaimKind::VerifiedEmpirical);
        } else {
            panic!("expected Semantic variant");
        }
    }

    #[test]
    fn rejects_invalid_claim_kind_enum_value() {
        let v = serde_json::json!({
            "schema_rev": "epistemos.semantic.v1",
            "fact_id": "111122223333",
            "predicate": "prefers",
            "subject": "user",
            "object": "pacific_time",
            "confidence": 1.0,
            "claim_kind": "make_believe"
        });
        let err = validate_epistemos_payload(&v).expect_err("must reject unknown claim_kind");
        assert!(matches!(err, SchemaValidationError::Deserialize(_)));
    }

    #[test]
    fn skill_payload_oneof_code_variant_validates() {
        let v = serde_json::json!({
            "schema_rev": "epistemos.skill.v1",
            "skill_id": "aaaabbbbcccc",
            "name": "Sample skill",
            "description": "Trivial echo skill",
            "body": {
                "kind": "code",
                "language": "javascript",
                "source": "return input;"
            },
            "requires_capabilities": ["vault.read", "memory.curated"],
            "created_at": "2026-05-15T00:00:00Z"
        });
        let payload = validate_epistemos_payload(&v).expect("valid skill payload");
        if let EpistemosPayload::Skill(s) = payload {
            if let SkillBody::Code { language, .. } = s.body {
                assert_eq!(language, SkillCodeLanguage::Javascript);
            } else {
                panic!("expected code body");
            }
            assert!(s.requires_capabilities.contains(&SkillCapability::VaultRead));
        } else {
            panic!("expected Skill variant");
        }
    }

    #[test]
    fn skill_payload_oneof_plan_variant_validates() {
        let v = serde_json::json!({
            "schema_rev": "epistemos.skill.v1",
            "skill_id": "aaaabbbbcccc",
            "name": "Plan skill",
            "description": "Search + summarize",
            "body": {
                "kind": "plan",
                "steps": [
                    {"tool": "vault.search", "arguments": {"q": "x"}},
                    {"tool": "memory.curated", "arguments": {}, "depends_on": [0]}
                ]
            },
            "created_at": "2026-05-15T00:00:00Z"
        });
        let payload = validate_epistemos_payload(&v).expect("valid plan skill");
        if let EpistemosPayload::Skill(s) = payload {
            if let SkillBody::Plan { steps } = s.body {
                assert_eq!(steps.len(), 2);
                assert_eq!(steps[1].depends_on, vec![0]);
            } else {
                panic!("expected plan body");
            }
        } else {
            panic!("expected Skill variant");
        }
    }

    #[test]
    fn episode_payload_with_linked_episodes_validates() {
        let v = serde_json::json!({
            "schema_rev": "epistemos.episode.v1",
            "episode_id": "555566667777",
            "occurred_at": "2026-05-15T20:00:00Z",
            "kind": "user_capture",
            "content": "user noted a contradiction in claim X",
            "linked_episodes": ["aaaabbbbcccc", "ddddeeeeffff"]
        });
        let payload = validate_epistemos_payload(&v).expect("valid episode payload");
        if let EpistemosPayload::Episode(e) = payload {
            assert_eq!(e.linked_episodes.len(), 2);
            assert_eq!(e.kind, EpisodeKind::UserCapture);
        } else {
            panic!("expected Episode variant");
        }
    }

    #[test]
    fn episode_rejects_malformed_linked_episode_id() {
        let v = serde_json::json!({
            "schema_rev": "epistemos.episode.v1",
            "episode_id": "555566667777",
            "occurred_at": "2026-05-15T20:00:00Z",
            "kind": "user_capture",
            "content": "x",
            "linked_episodes": ["UPPERCASE-BAD"]
        });
        let err = validate_epistemos_payload(&v).expect_err("must reject bad linked id");
        match err {
            SchemaValidationError::InvalidIdPattern { field, .. } => {
                assert_eq!(field, "linked_episodes[]");
            }
            other => panic!("expected InvalidIdPattern, got {other:?}"),
        }
    }

    #[test]
    fn payload_round_trips_through_json() {
        let v = good_soul_json();
        let payload = validate_epistemos_payload(&v).expect("valid soul");
        let back = serde_json::to_value(&payload).expect("serialize");
        // serde flattens the enum tag back into `schema_rev`; the
        // value should match the original input shape exactly.
        assert_eq!(back, v);
    }
}
