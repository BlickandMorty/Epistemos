//! `apple.reminders` — Apple Reminders via osascript. Plan §3.5 apple
//! family. Modification (add/complete mutate); AppStoreSafe.

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
                    "enum": ["list", "add", "complete"]
                },
                "title": { "type": "string" },
                "body": { "type": "string" },
                "list": { "type": "string" },
                "include_completed": {
                    "type": "boolean",
                    "default": false
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "apple.reminders",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: false,
};
