//! `web.search` — Tavily / Brave / Perplexity search via reqwest.
//! Plan §3.5 web family. Read-only, AppStoreSafe (cloud egress is gated
//! by FINAL_SYNTHESIS §5.6 tri-state Cloud setting; backend is selected
//! from environment variables or the explicit `backend` parameter).

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
                "limit": {
                    "type": "integer",
                    "default": 5,
                    "minimum": 1,
                    "maximum": 20
                },
                "backend": {
                    "type": "string",
                    "enum": ["tavily", "brave", "perplexity"],
                    "description": "Optional explicit backend override."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "web.search",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
