//! `intelligence.mixture_of_minds` — query multiple frontier models in
//! parallel and aggregate (Specialty D4). Plan §3.5 intelligence family.
//! Read-only; cloud-egress-heavy (one HTTP call per model). Cloud gate
//! per FINAL_SYNTHESIS §5.6.

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
            "required": ["problem"],
            "properties": {
                "problem": {
                    "type": "string",
                    "minLength": 1,
                    "description": "The question to dispatch."
                },
                "models": {
                    "type": "array",
                    "maxItems": 4,
                    "items": {
                        "type": "string",
                        "enum": ["claude", "openai", "gemini", "perplexity"]
                    },
                    "description": "Subset of models to query (default: [claude, openai, gemini])."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "intelligence.mixture_of_minds",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: false,
};
