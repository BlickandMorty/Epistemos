//! Plan §8 — `Intent` is what the LLM emits; `Effect` is what the runtime
//! applies. The model never mutates state directly. All eight variants
//! below are reversible (§8.5 universal undo) except `vault.delete`, which
//! goes through a 24h shadow-copy restore path.

use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

use super::{validate_against, FormatError};

pub const INTENT_V1_ID: &str = "epistemos://schemas/intent.v1.json";

#[derive(Serialize, Deserialize, JsonSchema, Clone, Debug, PartialEq)]
#[serde(tag = "action", rename_all = "snake_case")]
pub enum Intent {
    #[serde(rename = "vault.write")]
    VaultWrite {
        path: String,
        body: String,
        frontmatter: serde_json::Value,
    },
    #[serde(rename = "vault.move")]
    VaultMove { from: String, to: String },
    #[serde(rename = "vault.delete")]
    VaultDelete { path: String },
    #[serde(rename = "concept.create")]
    ConceptCreate {
        canonical_name: String,
        definition: String,
    },
    #[serde(rename = "concept.alias")]
    ConceptAlias {
        canonical_name: String,
        alias: String,
    },
    #[serde(rename = "memory.write")]
    MemoryWrite { entry: serde_json::Value },
    Noop { reason: String },
    Abort { reason: String },
}

impl Intent {
    pub fn validate(&self) -> Result<(), FormatError> {
        let v = serde_json::to_value(self)?;
        validate_against(super::schemas::INTENT_V1, &v)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn must_validate(i: &Intent) {
        i.validate()
            .unwrap_or_else(|e| panic!("intent must validate: {:?} -> {}", i, e));
    }

    #[test]
    fn all_eight_variants_round_trip_and_validate() {
        let intents = [
            Intent::VaultWrite {
                path: "notes/a.md".to_string(),
                body: "body".to_string(),
                frontmatter: serde_json::json!({}),
            },
            Intent::VaultMove {
                from: "a.md".to_string(),
                to: "b.md".to_string(),
            },
            Intent::VaultDelete {
                path: "old.md".to_string(),
            },
            Intent::ConceptCreate {
                canonical_name: "gradient-checkpointing".to_string(),
                definition: "recompute forward to save memory".to_string(),
            },
            Intent::ConceptAlias {
                canonical_name: "gradient-checkpointing".to_string(),
                alias: "rematerialization".to_string(),
            },
            Intent::MemoryWrite {
                entry: serde_json::json!({"id": "01HX42KQM3R7N9PVK0X8Z3W5MQ"}),
            },
            Intent::Noop {
                reason: "no action needed".to_string(),
            },
            Intent::Abort {
                reason: "unrecoverable".to_string(),
            },
        ];
        for intent in &intents {
            must_validate(intent);
            let s = serde_json::to_string(intent).unwrap();
            let p: Intent = serde_json::from_str(&s).unwrap();
            assert_eq!(&p, intent);
        }
    }

    #[test]
    fn schema_rejects_unknown_action() {
        let bad = serde_json::json!({"action": "vault.format_drive", "path": "/"});
        assert!(super::super::validate_against(super::super::schemas::INTENT_V1, &bad).is_err());
    }

    #[test]
    fn schema_rejects_invalid_canonical_name() {
        // Canonical names must be lowercase kebab; uppercase rejected.
        let bad = serde_json::json!({
            "action": "concept.create",
            "canonical_name": "Gradient_Checkpointing",
            "definition": "x"
        });
        assert!(super::super::validate_against(super::super::schemas::INTENT_V1, &bad).is_err());
    }

    #[test]
    fn schema_rejects_noop_reason_too_long() {
        let too_long = "x".repeat(281);
        let bad = serde_json::json!({"action": "noop", "reason": too_long});
        assert!(super::super::validate_against(super::super::schemas::INTENT_V1, &bad).is_err());
    }

    #[test]
    fn schema_rejects_extra_fields_per_variant() {
        let bad = serde_json::json!({
            "action": "vault.delete",
            "path": "x",
            "extra": "should be rejected"
        });
        assert!(super::super::validate_against(super::super::schemas::INTENT_V1, &bad).is_err());
    }
}
