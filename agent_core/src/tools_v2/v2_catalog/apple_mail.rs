//! `apple.mail` — Apple Mail via osascript. Plan §3.5 apple family.
//! Destructive (`send` with `send_now: true` is hard to reverse and
//! visible to others); AppStoreSafe (Mail Automation permission gates
//! at OS layer); marked NOT small_model_safe so the 1.5B router never
//! auto-emails without explicit user intent.

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
                    "enum": ["list_unread", "search", "send"]
                },
                "query": { "type": "string" },
                "to": { "type": "string" },
                "subject": { "type": "string" },
                "body": { "type": "string" },
                "send_now": {
                    "type": "boolean",
                    "default": false,
                    "description": "If false, a draft is created instead of sending."
                },
                "limit": {
                    "type": "integer",
                    "default": 10,
                    "minimum": 1,
                    "maximum": 100
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "apple.mail",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: false,
};
