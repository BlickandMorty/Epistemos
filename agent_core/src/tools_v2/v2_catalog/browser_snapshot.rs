//! `browser.snapshot` — accessibility snapshot of the current page.
//! Plan §3.5 browser family. Read-only; ProOnly per browser_navigate.rs
//! header reasoning.

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
                "full": {
                    "type": "boolean",
                    "default": false,
                    "description": "Return full snapshot instead of compact."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "browser.snapshot",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::ProOnly,
    small_model_safe: false,
};
