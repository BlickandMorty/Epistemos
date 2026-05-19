//! `file.write` — create or overwrite a file. Modification-tier;
//! handler enforces a system-path / credential-directory blocklist.

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
                    "description": "File path; supports ~/ home expansion",
                    "minLength": 1
                },
                "content": {
                    "type": "string",
                    "description": "Full UTF-8 file content"
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "file.write",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    // Modification — needs reasoning about destination + side effects.
    small_model_safe: false,
};
