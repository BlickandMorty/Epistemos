//! `browser.complete_task` — delegate a bounded task to browser-use.
//! Plan 3 browser-use Pro lane: Goose stays the user-facing agent while
//! browser-use runs as a subordinate automation sub-agent.

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
            "required": ["task"],
            "properties": {
                "task": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 4000,
                    "description": "Browser task to complete end-to-end."
                },
                "max_steps": {
                    "type": "integer",
                    "minimum": 1,
                    "maximum": 50,
                    "default": 20
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "browser.complete_task",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::ProOnly,
    small_model_safe: false,
};
