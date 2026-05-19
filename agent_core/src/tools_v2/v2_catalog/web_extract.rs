//! `web.extract` — fetch one or more URLs and return clean readable text.
//! Plan §3.5 web family. Read-only, AppStoreSafe.

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
                "url": {
                    "type": "string",
                    "description": "Single URL to extract."
                },
                "urls": {
                    "type": "array",
                    "description": "Multiple URLs to fetch in parallel (max 10).",
                    "maxItems": 10,
                    "items": { "type": "string" }
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "web.extract",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
