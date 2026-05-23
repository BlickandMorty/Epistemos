//! `inference.ssm_resume` — manage Mamba-2 SSM hidden-state snapshots.
//! Plan §3.5 inference family. Modification (save/load/prune mutate on-disk
//! state). Delegate-bound (MLX-Swift owns the actual SSM tensors per
//! CLAUDE.md "NO SIDECAR for INFERENCE" law).

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
                "action": {
                    "type": "string",
                    "enum": ["save", "load", "list", "prune"],
                    "default": "list"
                },
                "session_id": {
                    "type": "string",
                    "description": "Session identifier (required for save/load/prune)."
                },
                "label": {
                    "type": "string",
                    "description": "Optional named checkpoint like 'before_refactor'."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "inference.ssm_resume",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
