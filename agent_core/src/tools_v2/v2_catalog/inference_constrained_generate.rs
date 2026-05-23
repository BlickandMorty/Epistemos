//! `inference.constrained_generate` — EBNF grammar-guided decoding against
//! the on-device model. Plan §3.5 inference family. Read-only (output only,
//! no state mutation); delegate-bound (MLX-Swift owns the sampler — the
//! Rust side compiles the grammar via llguidance per Phase 2A and hands
//! the constrained sampler down).
//!
//! Per FINAL_SYNTHESIS §2 layer 5 (motor) and plan §22.1 CRANE/IterGen/
//! Grammar-Aligned: this is the Tool surface for the constrained-decode
//! primitive that the route variant ladder relies on.

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
            "required": ["prompt"],
            "properties": {
                "prompt": { "type": "string", "minLength": 1 },
                "grammar": {
                    "type": "string",
                    "enum": ["tool_call", "planning", "custom"],
                    "default": "tool_call"
                },
                "custom_ebnf": {
                    "type": "string",
                    "description": "Required when grammar='custom'."
                },
                "tools": {
                    "type": "array",
                    "description": "Optional tool schema list when grammar='tool_call'."
                },
                "max_tokens": {
                    "type": "integer",
                    "default": 256,
                    "minimum": 1,
                    "maximum": 4096
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "inference.constrained_generate",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
