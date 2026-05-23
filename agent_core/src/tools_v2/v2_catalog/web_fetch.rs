//! `web.fetch` — fetch a web page and extract its text content.
//! Plan §3.5 web family. Read-only, AppStoreSafe; thin wrapper around
//! `WebFetchTool::new()` (infallible — the underlying reqwest client
//! `.expect()`s on init failure, so unlike web.search/extract/crawl
//! we don't need an Ok-gate around registration).

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
                    "minLength": 1,
                    "description": "URL to fetch (must be http:// or https://)."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "web.fetch",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
