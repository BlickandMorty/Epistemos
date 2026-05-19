//! `graph.vault_navigate` — walk the vault's hyperbolic topology toward a
//! semantic target. Plan §3.5 graph family. Read-only, AppStoreSafe;
//! vault-root-bound.

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
            "required": ["start", "semantic_target"],
            "properties": {
                "start": {
                    "type": "string",
                    "minLength": 1,
                    "description": "Starting path in the vault."
                },
                "semantic_target": {
                    "type": "string",
                    "minLength": 1,
                    "description": "Text describing the destination concept."
                },
                "max_depth": {
                    "type": "integer",
                    "default": 3,
                    "minimum": 1,
                    "maximum": 8
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "graph.vault_navigate",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
