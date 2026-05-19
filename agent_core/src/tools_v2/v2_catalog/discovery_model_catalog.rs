//! `discovery.model_catalog` — fetch live OpenRouter or local model catalog.
//! Plan §3.5 discovery family. Read-only, AppStoreSafe (network egress is
//! gated by the Profile-aware dispatch in the runner; per FINAL_SYNTHESIS
//! §5.6 cloud is opt-in tri-state).

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
                "source": {
                    "type": "string",
                    "enum": ["openrouter", "local"],
                    "default": "openrouter"
                },
                "filter": {
                    "type": "string",
                    "description": "Substring filter on id/name."
                },
                "limit": {
                    "type": "integer",
                    "default": 50,
                    "minimum": 1,
                    "maximum": 500
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "discovery.model_catalog",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
