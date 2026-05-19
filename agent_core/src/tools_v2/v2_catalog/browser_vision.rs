//! `browser.vision` — screenshot the browser and analyze with vision LLM.
//! Plan §3.5 browser family. Read-only; cloud egress per
//! FINAL_SYNTHESIS §5.6 tri-state Cloud setting.

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
                "question": { "type": "string", "minLength": 1 },
                "provider": {
                    "type": "string",
                    "enum": ["claude", "openai", "gpt-4v"],
                    "default": "claude"
                },
                "annotate": {
                    "type": "boolean",
                    "default": false
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "browser.vision",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::ProOnly,
    small_model_safe: false,
};
