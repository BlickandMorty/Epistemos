//! `system.todo` — session-scoped task list. Actions: list / write /
//! merge / clear. Plan §3.5 system family. ReadOnly (the in-memory
//! list is per-session; not vault state).

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
                "action": { "enum": ["list", "write", "merge", "clear"] },
                "items": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "additionalProperties": true,
                        "required": ["content"],
                        "properties": {
                            "id": { "type": "string" },
                            "content": { "type": "string", "minLength": 1 },
                            "active_form": { "type": "string" },
                            "status": {
                                "enum": ["pending", "in_progress", "completed", "cancelled"]
                            }
                        }
                    }
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "system.todo",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
