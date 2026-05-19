//! `trajectory.export` — export past agent sessions as ShareGPT JSONL.
//! Plan §3.5 trajectory family. Modification because it can write to
//! disk, but read-only against the session store; AppStoreSafe.

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
                "session_id": {
                    "type": "string",
                    "description": "Export only this session."
                },
                "limit": {
                    "type": "integer",
                    "minimum": 1,
                    "description": "Max sessions (most-recent first)."
                },
                "output_path": {
                    "type": "string",
                    "description": "Write results to this file (~/ supported)."
                },
                "include_tool_calls": {
                    "type": "boolean",
                    "default": true,
                    "description": "Include tool_call records as extra conversation turns."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "trajectory.export",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
