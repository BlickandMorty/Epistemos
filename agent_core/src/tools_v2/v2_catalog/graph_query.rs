//! `graph.query` — query the vault's hyperbolic knowledge topology.
//! Plan §3.5 graph family. Read-only, AppStoreSafe; vault-root-bound.

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
                "mode": {
                    "type": "string",
                    "enum": ["god_nodes", "related", "spatial", "path", "communities"],
                    "default": "god_nodes"
                },
                "query": {
                    "type": "string",
                    "description": "Query text (mode='related')."
                },
                "origin": {
                    "type": "string",
                    "description": "Origin path (mode='spatial')."
                },
                "radius": {
                    "type": "number",
                    "description": "Spatial radius in Poincaré units (mode='spatial', default 1.5)."
                },
                "source": {
                    "type": "string",
                    "description": "Source node path (mode='path')."
                },
                "target": {
                    "type": "string",
                    "description": "Target node path (mode='path')."
                },
                "limit": {
                    "type": "integer",
                    "default": 10,
                    "minimum": 1,
                    "maximum": 100
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "graph.query",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
