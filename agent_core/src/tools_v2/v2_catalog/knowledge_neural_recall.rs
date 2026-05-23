//! `knowledge.neural_recall` — tiered cache lookup (Hot L1 sub-1ms →
//! Warm L2 Tantivy+vec → Cold vault). Plan §25.7 5-tier memory
//! infrastructure already exists; this tool is the agent-facing
//! probe. Supports `temporal_minutes_ago` for time-window recall.

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
                    "description": "Text query for tiered retrieval"
                },
                "limit": { "type": "integer", "default": 5, "minimum": 1, "maximum": 20 },
                "temporal_minutes_ago": {
                    "type": "integer",
                    "minimum": 0,
                    "description": "When set, retrieve facts from a past time window instead of running the keyword query"
                },
                "temporal_window_minutes": {
                    "type": "integer",
                    "default": 5,
                    "minimum": 1,
                    "maximum": 1440
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "knowledge.neural_recall",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
