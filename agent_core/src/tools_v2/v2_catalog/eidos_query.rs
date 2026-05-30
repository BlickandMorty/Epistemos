//! `eidos.query` — agent-native local evidence selector over the vault.

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
            "required": ["query"],
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Natural language query, exact title, alias, metadata phrase, or path to retrieve citable local evidence.",
                    "minLength": 1
                },
                "top_k": {
                    "type": "integer",
                    "description": "Maximum evidence hits to return",
                    "default": 5,
                    "minimum": 1,
                    "maximum": 20
                },
                "scope": {
                    "type": "string",
                    "description": "Retrieval scope. Current production value is vault.",
                    "default": "vault"
                },
                "tags": {
                    "type": "array",
                    "items": { "type": "string", "minLength": 1 },
                    "description": "Optional tag filter"
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "eidos.query",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
