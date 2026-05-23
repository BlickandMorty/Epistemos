//! `macos.perceive` — fused AX + Vision + VLM percept of a running app.
//! Plan §3.5 macOS family. Read-only, AppStoreSafe; delegate-bound (Swift
//! AXorcist + ScreenCaptureKit live on the macOS side of the FFI).

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
            "required": ["app_name"],
            "properties": {
                "app_name": {
                    "type": "string",
                    "minLength": 1,
                    "description": "Target application name (e.g., 'Safari', 'Finder')."
                },
                "depth": {
                    "type": "string",
                    "enum": ["fast", "enriched", "full"],
                    "default": "fast"
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "macos.perceive",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
