//! `discovery.mcp_discover` — scan MCP config dirs and return server configs.
//! Plan §3.5 discovery family. Read-only, AppStoreSafe.

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
                "create_missing": {
                    "type": "boolean",
                    "default": false,
                    "description": "mkdir the default scan roots when they don't exist."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "discovery.mcp_discover",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
