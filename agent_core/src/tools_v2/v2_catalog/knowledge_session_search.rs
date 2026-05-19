//! `knowledge.session_search` — search past session transcripts under
//! `<vault>/sessions/`. Plan §3.5 knowledge family. Read-only,
//! AppStoreSafe; vault-root-bound.

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
                "query": {
                    "type": "string",
                    "description": "Case-insensitive keyword."
                },
                "provider": {
                    "type": "string",
                    "description": "Optional provider filter (claude_sonnet, openai, …)."
                },
                "limit": {
                    "type": "integer",
                    "default": 20,
                    "minimum": 1,
                    "maximum": 200
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "knowledge.session_search",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
