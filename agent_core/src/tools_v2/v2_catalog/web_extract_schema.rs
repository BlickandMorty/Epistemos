//! `web.extract_schema` — fetch a web page and extract fields into a
//! caller-provided JSON Schema target. Plan §3.5 web family. Read-only,
//! AppStoreSafe.

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
            "required": ["url", "schema"],
            "properties": {
                "url": {
                    "type": "string",
                    "minLength": 1,
                    "description": "URL to fetch and extract."
                },
                "schema": {
                    "type": "object",
                    "description": "JSON Schema for the extracted object."
                },
                "fields": {
                    "type": "array",
                    "maxItems": 32,
                    "items": {
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["name"],
                        "properties": {
                            "name": { "type": "string", "minLength": 1 },
                            "source": {
                                "type": "string",
                                "enum": ["auto", "title", "meta", "text", "json_ld"],
                                "default": "auto"
                            },
                            "key": { "type": "string", "minLength": 1 },
                            "pattern": { "type": "string", "minLength": 1 },
                            "required": { "type": "boolean", "default": false }
                        }
                    }
                },
                "include_content": {
                    "type": "boolean",
                    "default": false
                },
                "fail_on_schema_error": {
                    "type": "boolean",
                    "default": false
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "web.extract_schema",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: true,
};
