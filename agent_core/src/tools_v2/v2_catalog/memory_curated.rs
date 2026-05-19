//! `memory.curated` — persistent curated memory. Plan §3.5 memory family.
//! Modification (add/replace/remove mutate on-disk MEMORY.md / USER.md);
//! AppStoreSafe (filesystem only).
//!
//! Distinct from FINAL_SYNTHESIS §2 layer 6 RunEventLog: this is the
//! durable curated-memory store the user/agent edit; RunEventLog is the
//! tamper-evident execution trace.

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
                    "enum": ["add", "replace", "remove", "read"]
                },
                "target": {
                    "type": "string",
                    "enum": ["memory", "user"],
                    "default": "memory"
                },
                "content": {
                    "type": "string",
                    "description": "Content to add or new content for replace."
                },
                "substring": {
                    "type": "string",
                    "description": "Unique substring to identify the entry for replace/remove."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "memory.curated",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
