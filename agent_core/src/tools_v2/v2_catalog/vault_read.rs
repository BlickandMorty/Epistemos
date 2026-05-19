//! `vault.read` — read full content of a vault note by path.
//! Plan §3.5 vault-family. Single-variant (deterministic file IO).

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
            "required": ["path"],
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Vault-relative note path (e.g. notes/research/x.md)",
                    "minLength": 1
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "vault.read",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
