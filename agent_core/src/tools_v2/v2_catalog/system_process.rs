//! `system.process` — manage background processes spawned by
//! `action.terminal`. Plan §3.5 system family.
//!
//! Pro-only because all 5 actions (list / poll / log / kill / write)
//! reach into the running PTY pool established by `action.terminal`.
//! The action enum mixes ReadOnly (list/poll/log) with Destructive
//! (kill/write) so the legacy registry tags the whole tool Destructive;
//! `small_model_safe: false` so the 1.5B router can't auto-kill or
//! auto-write to a child process.

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
                    "type": "string",
                    "enum": ["list", "poll", "log", "kill", "write"]
                },
                "session_id": {
                    "type": "string",
                    "description": "Process id returned by terminal background mode."
                },
                "data": {
                    "type": "string",
                    "description": "Text to write to stdin (action='write')."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "system.process",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::ProOnly,
    small_model_safe: false,
};
