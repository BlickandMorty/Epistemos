//! `browser.console` — read browser console messages and JS errors.
//! Plan §3.5 browser family. Read-only by default; the optional
//! `expression` field can evaluate JS first (Modification when set).

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
                "clear": {
                    "type": "boolean",
                    "default": false
                },
                "expression": {
                    "type": "string",
                    "description": "Optional JavaScript expression to evaluate before reading the console."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "browser.console",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::ProOnly,
    small_model_safe: false,
};
