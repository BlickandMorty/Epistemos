//! `chunk.reduce` — split-map-reduce a large text in parallel.
//! Lambda-RLM pattern (plan §5.6 cascading + chunk_reduce existing
//! handler). Read-only, AppStoreSafe.

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
            "required": ["input_text", "instruction"],
            "properties": {
                "input_text": {
                    "type": "string",
                    "description": "The large text to process",
                    "minLength": 1
                },
                "instruction": {
                    "type": "string",
                    "description": "Instruction applied to each chunk",
                    "minLength": 1
                },
                "chunk_size": {
                    "type": "integer",
                    "default": 4000,
                    "minimum": 500,
                    "maximum": 32000
                },
                "max_concurrency": {
                    "type": "integer",
                    "default": 4,
                    "minimum": 1,
                    "maximum": 16
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "chunk.reduce",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    // Map-reduce drives many parallel sub-LLM calls; the routing layer
    // (Phase 6 model_select) will route those to the 7B / Hermes-3-8B
    // tier when called via this tool. The orchestration itself is
    // small-model-safe (just splits + dispatches).
    small_model_safe: true,
};
