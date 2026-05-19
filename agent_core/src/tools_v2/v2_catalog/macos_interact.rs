//! `macos.interact` — drive a macOS app by AX semantic reference. Plan §3.5
//! macOS family. Modification (mutates app state); AppStoreSafe (Accessibility
//! permission gates at OS layer). Delegate-bound (CGEvent + AX dispatch on
//! the Swift side).

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
            "required": ["app_name", "action", "target"],
            "properties": {
                "app_name": { "type": "string", "minLength": 1 },
                "action": {
                    "type": "string",
                    "enum": ["click", "type", "scroll", "drag", "press_key", "hover"]
                },
                "target": {
                    "type": "string",
                    "minLength": 1,
                    "description": "Element query or @ref from macos.perceive."
                },
                "value": {
                    "type": "string",
                    "description": "Text for 'type', key name for 'press_key', optional otherwise."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "macos.interact",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: false,
};
