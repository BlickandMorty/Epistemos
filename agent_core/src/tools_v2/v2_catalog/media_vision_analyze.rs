//! `media.vision_analyze` — analyze an image with a vision LLM.
//! Plan §3.5 media family. Read-only (output only, no side effects).
//! Cloud egress to Anthropic (claude) or OpenAI (openai) gated by the
//! tri-state Cloud setting per FINAL_SYNTHESIS §5.6.

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
            "properties": {
                "image_url": {
                    "type": "string",
                    "description": "Public URL to the image."
                },
                "image_path": {
                    "type": "string",
                    "description": "Local path (supports ~/)."
                },
                "question": {
                    "type": "string",
                    "default": "Describe this image in detail."
                },
                "provider": {
                    "type": "string",
                    "enum": ["claude", "openai", "gpt-4v"],
                    "default": "claude"
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "media.vision_analyze",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
