//! `knowledge.contradiction_check` — check whether a new fact
//! contradicts existing vault knowledge before writing. Returns typed
//! conflicts (Numeric / Boolean / Antonym / SemanticReversal) with
//! confidence + a `safe_to_write` boolean.
//!
//! Wired into the §22.5 / §24.6 evolution pipeline downstream — feeds
//! signals to GEPA proposal generation.

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
            "required": ["claim"],
            "properties": {
                "claim": {
                    "type": "string",
                    "description": "The new fact to check",
                    "minLength": 1
                },
                "context": {
                    "type": "string",
                    "description": "Optional extra context for candidate retrieval"
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "knowledge.contradiction_check",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
