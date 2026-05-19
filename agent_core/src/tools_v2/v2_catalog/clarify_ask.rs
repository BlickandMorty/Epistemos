//! `clarify.ask` — ask the user a clarifying question and wait for the
//! answer. Plan §3.5 clarify family. Read-only, AppStoreSafe; delegate-bound
//! (the question goes through the agent event delegate to the UI).

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
            "required": ["question"],
            "properties": {
                "question": {
                    "type": "string",
                    "minLength": 1,
                    "description": "The question to show the user."
                },
                "choices": {
                    "type": "array",
                    "description": "Optional multiple-choice options (max 4).",
                    "maxItems": 4,
                    "items": { "type": "string" }
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "clarify.ask",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
