//! `.skill` — Voyager-shaped procedural memory.
//!
//! Plan §2.4: declarative composition of tool calls. Phase 1 ships the
//! shape; the §17.2 Compile-Verify-Mint pipeline (Phase 17 work) adds
//! `rust_code` + `tests` fields and seals minted skills with a
//! content-addressed sha256.
//!
//! Pairs with `<name>.skill.md` (human-readable description, when-to-use,
//! examples) — same paired-file fusion as `.soul`.

use chrono::{DateTime, Utc};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

use super::{validate_against, FormatError};

pub const SKILL_V1_ID: &str = "epistemos://schemas/skill.v1.json";

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct SkillStep {
    pub id: String, // pattern ^s[0-9]+$
    pub tool: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub input: Option<serde_json::Value>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub input_from: Option<String>, // reference like "s1.result" (NOT "s1.payload")
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub params: Option<serde_json::Value>,
}

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(deny_unknown_fields)]
pub struct SkillManifest {
    #[serde(rename = "$schema")]
    pub schema: String,
    pub id: String,
    pub name: String,
    pub narrative_path: String,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub preconditions: Vec<String>,
    pub steps: Vec<SkillStep>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub success_metric: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_used: Option<DateTime<Utc>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub success_rate: Option<f64>,
    pub schema_version: u32,
}

impl SkillManifest {
    pub fn validate(&self) -> Result<(), FormatError> {
        if self.schema != SKILL_V1_ID {
            return Err(FormatError::SchemaValidation(format!(
                "skill manifest $schema must be {}, got {}",
                SKILL_V1_ID, self.schema
            )));
        }
        let v = serde_json::to_value(self)?;
        validate_against(super::schemas::SKILL_V1, &v)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_manifest() -> SkillManifest {
        SkillManifest {
            schema: SKILL_V1_ID.to_string(),
            id: "skill.weekly-review.v1".to_string(),
            name: "weekly-review".to_string(),
            narrative_path: "weekly-review.skill.md".to_string(),
            preconditions: vec!["day_of_week == 'Sunday'".to_string()],
            steps: vec![
                SkillStep {
                    id: "s1".to_string(),
                    tool: "memory.recall_episodic".to_string(),
                    input: Some(serde_json::json!({"window_days": 7})),
                    input_from: None,
                    params: None,
                },
                SkillStep {
                    id: "s2".to_string(),
                    tool: "knowledge.summarize".to_string(),
                    input: None,
                    input_from: Some("s1.result".to_string()),
                    params: Some(serde_json::json!({"style": "outline"})),
                },
                SkillStep {
                    id: "s3".to_string(),
                    tool: "vault.write".to_string(),
                    input: Some(serde_json::json!({"folder": "reviews"})),
                    input_from: None,
                    params: None,
                },
            ],
            success_metric: Some("vault.write returned status:ok".to_string()),
            last_used: None,
            success_rate: Some(0.93),
            schema_version: 1,
        }
    }

    #[test]
    fn sample_skill_validates() {
        let m = sample_manifest();
        m.validate().unwrap();
    }

    #[test]
    fn round_trip_through_json() {
        let m = sample_manifest();
        let s = serde_json::to_string(&m).unwrap();
        let p: SkillManifest = serde_json::from_str(&s).unwrap();
        assert_eq!(p, m);
    }

    #[test]
    fn schema_rejects_input_from_referencing_payload() {
        // Plan §3.1: tool output payload field is `result`, not `payload`.
        // The skill grammar must reject `input_from: s1.payload` — only
        // `s1.result` references are valid.
        let mut m = sample_manifest();
        m.steps[1].input_from = Some("s1.payload".to_string());
        let v = serde_json::to_value(&m).unwrap();
        assert!(super::super::validate_against(super::super::schemas::SKILL_V1, &v).is_err());
    }

    #[test]
    fn schema_rejects_zero_steps() {
        let mut m = sample_manifest();
        m.steps.clear();
        let v = serde_json::to_value(&m).unwrap();
        assert!(super::super::validate_against(super::super::schemas::SKILL_V1, &v).is_err());
    }

    #[test]
    fn schema_rejects_bad_skill_id_pattern() {
        let mut m = sample_manifest();
        m.id = "weekly-review".to_string(); // missing skill. prefix and .vN suffix
        let v = serde_json::to_value(&m).unwrap();
        assert!(super::super::validate_against(super::super::schemas::SKILL_V1, &v).is_err());
    }

    #[test]
    fn schema_rejects_bad_step_id_pattern() {
        let mut m = sample_manifest();
        m.steps[0].id = "step1".to_string();
        let v = serde_json::to_value(&m).unwrap();
        assert!(super::super::validate_against(super::super::schemas::SKILL_V1, &v).is_err());
    }

    #[test]
    fn schema_rejects_bad_tool_name_pattern() {
        let mut m = sample_manifest();
        m.steps[0].tool = "BadlyNamed".to_string();
        let v = serde_json::to_value(&m).unwrap();
        assert!(super::super::validate_against(super::super::schemas::SKILL_V1, &v).is_err());
    }
}
