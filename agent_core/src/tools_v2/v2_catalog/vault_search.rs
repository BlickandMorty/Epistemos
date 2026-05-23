//! `vault.search` — hybrid semantic + keyword vault search.
//! Plan §3.5 vault-family. Variant-A (lexical) substrate today;
//! Phase 3 adds variants B (embedding semantic) and C (RRF hybrid)
//! as plan §1.4 No-LLM-First mandates.

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
            "required": ["query"],
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Natural language search query",
                    "minLength": 1
                },
                "limit": {
                    "type": "integer",
                    "description": "Maximum results to return",
                    "default": 5,
                    "minimum": 1,
                    "maximum": 20
                },
                "tags": {
                    "type": "array",
                    "items": { "type": "string", "minLength": 1 },
                    "description": "Optional tag filter"
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "vault.search",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    // Phase 3 will add variants B (embedding) + C (concept-anchored)
    // per plan §4.3-§4.5; today the legacy handler is single-variant
    // (lexical/hybrid via VaultStore).
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
