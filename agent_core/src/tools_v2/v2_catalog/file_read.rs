//! `file.read` — read a text file with line-number paging.
//! Plan §3.5 file family. Read-only, AppStoreSafe.

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
            "required": ["path"],
            "properties": {
                "path": {
                    "type": "string",
                    "description": "File path; supports ~/ home expansion",
                    "minLength": 1
                },
                "offset": {
                    "type": "integer",
                    "default": 1,
                    "minimum": 1,
                    "description": "Start line (1-indexed)"
                },
                "limit": {
                    "type": "integer",
                    "default": 500,
                    "minimum": 1,
                    "maximum": 2000
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "file.read",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
