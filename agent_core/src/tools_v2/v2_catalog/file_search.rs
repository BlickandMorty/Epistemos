//! `file.search` — ripgrep-backed text/regex search across a tree.
//! Read-only, AppStoreSafe.

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
            "required": ["pattern"],
            "properties": {
                "pattern": {
                    "type": "string",
                    "description": "Search pattern (regex by default)",
                    "minLength": 1
                },
                "path": {
                    "type": "string",
                    "description": "Root path to search; supports ~/ home expansion"
                },
                "max_results": {
                    "type": "integer",
                    "default": 50,
                    "minimum": 1,
                    "maximum": 500
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "file.search",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
