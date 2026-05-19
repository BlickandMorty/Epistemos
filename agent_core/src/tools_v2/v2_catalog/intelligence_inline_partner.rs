//! `intelligence.inline_partner` — query inline AI partner context at a
//! cursor position (Specialty D2). Plan §3.5 intelligence family.
//! Read-only; delegate-bound (the partner runs inside the editor VM).

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
            "required": ["note_id", "cursor_offset"],
            "properties": {
                "note_id": { "type": "string", "minLength": 1 },
                "cursor_offset": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 4_294_967_295u64,
                    "description": "Byte offset into the note (u32-bounded)."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "intelligence.inline_partner",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
