//! `workspace.get_change_impact` — analyze 2-hop transitive impact of
//! changing a symbol. Plan §3.5 workspace family. Read-only, AppStoreSafe.

use std::sync::OnceLock;

use serde_json::Value;

use crate::tools_v2::legacy_adapter::{generic_text_or_object_output_schema, AdapterSpec};
use crate::tools::workspace_search::GET_CHANGE_IMPACT_TOOL_SCHEMA;
use crate::tools_v2::{Profile, VariantId};

pub fn input_schema() -> &'static Value {
    static S: OnceLock<Value> = OnceLock::new();
    S.get_or_init(|| {
        serde_json::from_str(GET_CHANGE_IMPACT_TOOL_SCHEMA)
            .expect("GET_CHANGE_IMPACT_TOOL_SCHEMA must be valid JSON")
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "workspace.get_change_impact",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
