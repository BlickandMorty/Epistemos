//! `macos.screen_watch` — block until a screen / file / app condition triggers.
//! Plan §3.5 macOS family. Read-only, AppStoreSafe; delegate-bound (FSEvents +
//! ScreenCaptureKit + app polling live on the Swift side).

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
            "required": ["mode", "target"],
            "properties": {
                "mode": {
                    "type": "string",
                    "enum": ["visual_region", "file_path", "app_state"]
                },
                "target": {
                    "type": "string",
                    "minLength": 1,
                    "description": "Screen rect [x,y,w,h], file glob, or app name."
                },
                "condition": {
                    "type": "string",
                    "default": "changes",
                    "description": "'changes', 'exists', 'contains:<text>' …"
                },
                "timeout_secs": {
                    "type": "integer",
                    "default": 60,
                    "minimum": 1,
                    "maximum": 600
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "macos.screen_watch",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
