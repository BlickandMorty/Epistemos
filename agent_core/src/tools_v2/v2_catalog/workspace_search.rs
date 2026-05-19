//! `workspace.search` — find code symbols + cross-file matches.
//! Plan §3.5 code family.

use std::sync::OnceLock;

use serde_json::{json, Value};

use crate::tools_v2::legacy_adapter::{generic_text_or_object_output_schema, AdapterSpec};
use crate::tools_v2::{Profile, VariantId};

pub fn input_schema() -> &'static Value {
    static S: OnceLock<Value> = OnceLock::new();
    S.get_or_init(|| {
        // Tighter than the legacy free-form schema string in
        // tools/workspace_search.rs:WORKSPACE_SEARCH_TOOL_SCHEMA — we
        // declare additionalProperties:false at the v2 layer so the
        // grammar compiler emits a tight dispatch.
        json!({
            "type": "object",
            "additionalProperties": false,
            "required": ["query"],
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Symbol name or code keyword",
                    "minLength": 1
                },
                "max_results": {
                    "type": "integer",
                    "default": 10,
                    "minimum": 1,
                    "maximum": 100
                },
                "scope": {
                    "type": "string",
                    "description": "Optional path prefix to scope the search"
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "workspace.search",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
