//! `intelligence.self_evolve` — GEPA-style skill mutation proposals
//! (Specialty D3). Plan §3.5 intelligence family. Read-only against
//! session traces; emits proposals only (skill writes go through
//! `skill_manage`). Vault-root-bound (no delegate); registered in
//! `build_v2_catalog` conditionally on `vault_root_path = Some`.

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
                    "enum": ["analyze", "propose"],
                    "default": "analyze"
                },
                "sessions_to_scan": {
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
    name: "intelligence.self_evolve",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
