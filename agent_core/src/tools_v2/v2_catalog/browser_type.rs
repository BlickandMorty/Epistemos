//! `browser.type` — fill an input by ref id from `browser.snapshot`.
//! Plan §3.5 browser family. Destructive (mutates form state).

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
            "required": ["ref", "text"],
            "properties": {
                "ref": { "type": "string", "minLength": 1 },
                "text": { "type": "string" }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "browser.type",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::ProOnly,
    small_model_safe: false,
};
