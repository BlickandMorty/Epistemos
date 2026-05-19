//! `apple.notes` — Apple Notes via osascript. Plan §3.5 apple family.
//! Modification (create can write to Notes); AppStoreSafe (osascript is
//! gated by harden_cli_subprocess in security.rs and the OS Automation
//! permission prompt). Marked `small_model_safe: false` so the 1.5B
//! router doesn't auto-reach for it without explicit user intent.

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
                    "enum": ["list", "read", "create", "search"]
                },
                "title": { "type": "string" },
                "content": { "type": "string" },
                "folder": { "type": "string" },
                "query": { "type": "string" },
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
    name: "apple.notes",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: false,
};
