//! `system.cron` — scheduled cron jobs (SQLite-backed, ~/.epistemos/
//! agent_cron.db). Modification-tier; AppStoreSafe (jobs run user
//! prompts, not arbitrary shell).

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
            "required": ["action"],
            "properties": {
                "action": {
                    "enum": ["create", "list", "get", "update", "remove", "pause", "resume"]
                },
                "id": { "type": "string" },
                "name": { "type": "string" },
                "schedule": {
                    "type": "string",
                    "description": "Cron expression (e.g. '0 9 * * 1' for Mondays at 9am)"
                },
                "prompt": { "type": "string" },
                "enabled": { "type": "boolean" }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "system.cron",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: false,
};
