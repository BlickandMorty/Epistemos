//! `action.terminal` — execute a shell command (foreground or
//! background). Plan §1.6 / §17 / §20.5 — action.* tools are
//! Pro-only. Strips KEY/TOKEN/SECRET/PASSWORD/AUTH env vars from
//! the child process per the existing handler's hardening.
//!
//! Distinct from `action.bash` which is the simpler one-shot
//! variant; `action.terminal` adds background sessions + env
//! shaping + foreground/background mode selection.

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
            "required": ["command"],
            "properties": {
                "command": {
                    "type": "string",
                    "description": "Shell command to execute",
                    "minLength": 1
                },
                "mode": {
                    "enum": ["foreground", "background"],
                    "default": "foreground"
                },
                "working_dir": { "type": "string" },
                "timeout_seconds": {
                    "type": "integer",
                    "default": 30,
                    "minimum": 1,
                    "maximum": 600
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "action.terminal",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::ProOnly,
    small_model_safe: false,
};
