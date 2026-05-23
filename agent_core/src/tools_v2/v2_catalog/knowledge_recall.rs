//! `knowledge.recall` — sub-5ms hybrid semantic + keyword vault recall
//! with full result payload + latency metrics. Plan §3.5 knowledge family.

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
            "required": ["query"],
            "properties": {
                "query": { "type": "string", "minLength": 1 },
                "top_k": { "type": "integer", "default": 5, "minimum": 1, "maximum": 20 },
                "tags": {
                    "type": "array",
                    "items": { "type": "string", "minLength": 1 }
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "knowledge.recall",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
