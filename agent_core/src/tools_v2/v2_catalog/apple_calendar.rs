//! `apple.calendar` — Apple Calendar via osascript. Plan §3.5 apple
//! family. Modification (create writes events); AppStoreSafe.

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
            "required": ["action"],
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["list", "create"]
                },
                "title": { "type": "string" },
                "start": {
                    "type": "string",
                    "description": "Start datetime ('YYYY-MM-DD HH:MM:SS' or AppleScript-compatible)."
                },
                "end": {
                    "type": "string",
                    "description": "End datetime."
                },
                "calendar": { "type": "string" },
                "location": { "type": "string" },
                "limit": {
                    "type": "integer",
                    "default": 20,
                    "minimum": 1,
                    "maximum": 100
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "apple.calendar",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: false,
};
