//! `action.bash` — execute a bash command with timeout + security blocklist.
//!
//! Plan §1.6 / §17 / §20.5: action.* tools are Pro-only — they don't
//! ship in the App Store profile. This tool's `Profile::ProOnly`
//! gate keeps it out of the dispatch grammar for App Store builds
//! per plan §17.3 ("registry.active_for(profile)").
//!
//! Plan §3.1 `small_model_safe = false`: shell commands need careful
//! reasoning about side effects; the 1.5B router must not invoke this.

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
                    "description": "Bash command to execute. Pre-flight blocklist rejects rm -rf, fork bombs, network exfil patterns.",
                    "minLength": 1
                },
                "working_dir": {
                    "type": "string",
                    "description": "Optional working directory"
                },
                "timeout_seconds": {
                    "type": "integer",
                    "default": 30,
                    "minimum": 1,
                    "maximum": 120
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "action.bash",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::ProOnly,
    small_model_safe: false,
};
