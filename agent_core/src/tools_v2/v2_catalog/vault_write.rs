//! `vault.write` — create or update a vault note. Modification-tier;
//! agent loop gates this through the existing `RiskLevel::Modification`
//! permission machinery in registry.rs.

use std::sync::OnceLock;

use serde_json::{json, Value};

use crate::tools_v2::legacy_adapter::{generic_text_or_object_output_schema, AdapterSpec};
use crate::tools_v2::{Profile, VariantId};

pub fn input_schema() -> &'static Value {
    static S: OnceLock<Value> = OnceLock::new();
    S.get_or_init(|| {
        json!({
            "type": "object",
            "additionalProperties": false,
            "required": ["path", "content"],
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Vault-relative note path",
                    "minLength": 1
                },
                "content": {
                    "type": "string",
                    "description": "Markdown body to write"
                },
                "tags": {
                    "type": "array",
                    "items": { "type": "string", "minLength": 1 }
                },
                "append": {
                    "type": "boolean",
                    "description": "When true, append to existing file rather than replace",
                    "default": false
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "vault.write",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    // Modification tier — App Store-safe (notes are user content), but
    // not "small_model_safe" because the model needs to reason carefully
    // about what to write. Phase 6 routing will route modification tools
    // to the larger 7B local model.
    small_model_safe: false,
};
