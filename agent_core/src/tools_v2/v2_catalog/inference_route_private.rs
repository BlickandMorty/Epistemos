//! `inference.route_private` — Specialty C3. Classify an objective on
//! five privacy/complexity dimensions and return the routing decision
//! before the caller takes action. Plan §3.5 inference family. Pure-Rust
//! (no delegate); read-only.
//!
//! Per FINAL_SYNTHESIS §5.6 tri-state Cloud setting: this tool is the
//! deterministic dimension-classifier the Compile-Verify-Mint gate
//! consults; cloud egress requires Cloud != Off + matching profile.

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
            "required": ["objective"],
            "properties": {
                "objective": {
                    "type": "string",
                    "minLength": 1,
                    "description": "The task / prompt you are about to run."
                },
                "force_local": {
                    "type": "boolean",
                    "default": false,
                    "description": "Flag override_triggered when the routed lane was non-local."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "inference.route_private",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
