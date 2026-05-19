//! `web.crawl` — breadth-first crawl from a seed URL. Plan §3.5 web
//! family. Read-only, AppStoreSafe; defaults to same-host only.

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
            "required": ["url"],
            "properties": {
                "url": {
                    "type": "string",
                    "description": "Seed URL to start crawling."
                },
                "max_pages": {
                    "type": "integer",
                    "default": 10,
                    "minimum": 1,
                    "maximum": 50
                },
                "max_depth": {
                    "type": "integer",
                    "default": 2,
                    "minimum": 1,
                    "maximum": 3
                },
                "same_host_only": {
                    "type": "boolean",
                    "default": true
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "web.crawl",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
