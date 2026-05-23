//! `browser.navigate` — open a URL in the shared browser session.
//! Plan §3.5 browser family. Modification (mutates session state).
//!
//! Per FINAL_SYNTHESIS §5.7 / §6 wave sequencing: the current direct
//! BrowserManager spawn is the legacy Pro-only path. Wave 6 introduces
//! the `BrowserEngine` trait with WebKit-baseline (AppStoreSafe) and
//! Obscura-experimental (Pro) adapters. Until that lands, all
//! browser.* tools mark `ProOnly` + `small_model_safe: false` so the
//! 1.5B router never auto-spawns a browser subprocess and the
//! AppStoreSafe dispatch grammar excludes them.

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
                    "description": "HTTP or HTTPS URL to open."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "browser.navigate",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::ProOnly,
    small_model_safe: false,
};
