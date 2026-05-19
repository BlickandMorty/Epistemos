//! `capture.screenshot` — Phase 5 native skill. Take a screenshot,
//! run Vision OCR, return text with bounding boxes. Plan §3.5 capture
//! family. Read-only; delegate-bound.

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
                "region": {
                    "description": "'fullscreen' (default) or [x, y, w, h] in screen pixels.",
                    "oneOf": [
                        { "type": "string", "enum": ["fullscreen"] },
                        {
                            "type": "array",
                            "items": { "type": "number" },
                            "minItems": 4,
                            "maxItems": 4
                        }
                    ]
                },
                "preserve_layout": {
                    "type": "boolean",
                    "default": true,
                    "description": "Preserve bounding-box layout in output regions."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "capture.screenshot",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
