//! `file.patch` — fuzzy find-and-replace in a file with 5 fallback
//! matching strategies (exact → whitespace-norm → trimmed → indent-
//! stripped → substring). Modification-tier; small_model_safe=false.

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
            "required": ["path", "old_string", "new_string"],
            "properties": {
                "path": { "type": "string", "minLength": 1 },
                "old_string": { "type": "string", "description": "Text to find" },
                "new_string": { "type": "string", "description": "Replacement text" },
                "replace_all": {
                    "type": "boolean",
                    "default": false,
                    "description": "Replace every match instead of the first"
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "file.patch",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: false,
};
