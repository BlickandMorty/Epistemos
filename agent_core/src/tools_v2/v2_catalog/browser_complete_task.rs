//! `browser.complete_task` — delegate a bounded task to browser-use.
//! Plan 3 browser-use Pro lane: Goose stays the user-facing agent while
//! browser-use runs as a subordinate automation sub-agent.

use std::sync::OnceLock;

use serde_json::{json, Value};

use crate::tools_v2::legacy_adapter::AdapterSpec;
use crate::tools_v2::{Profile, VariantId};

pub fn input_schema() -> &'static Value {
    static S: OnceLock<Value> = OnceLock::new();
    S.get_or_init(|| {
        json!({
            "type": "object",
            "additionalProperties": false,
            "required": ["task"],
            "properties": {
                "task": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 4000,
                    "description": "Browser task to complete end-to-end."
                },
                "max_steps": {
                    "type": "integer",
                    "minimum": 1,
                    "maximum": 50,
                    "default": 20
                }
            }
        })
    })
}

pub fn output_schema() -> &'static Value {
    static S: OnceLock<Value> = OnceLock::new();
    S.get_or_init(|| {
        json!({
            "anyOf": [
                {
                    "type": "object",
                    "additionalProperties": false,
                    "required": [
                        "success",
                        "adapter_success",
                        "task_success",
                        "status",
                        "final_result",
                        "errors",
                        "steps",
                        "max_steps",
                        "task_chars",
                        "is_done",
                        "successful",
                        "used_browser_use_agent",
                        "dry_run",
                        "truncated"
                    ],
                    "properties": {
                        "success": {
                            "type": "boolean",
                            "description": "True only when the delegated browser-use task completed successfully, not merely when the adapter returned."
                        },
                        "adapter_success": {
                            "const": true,
                            "description": "True means the Pro adapter returned a valid JSON envelope."
                        },
                        "task_success": {
                            "type": "boolean",
                            "description": "Mirrors the delegated browser-use task outcome."
                        },
                        "status": {
                            "type": "string",
                            "enum": ["completed", "failed", "incomplete", "unknown"],
                            "description": "Bounded browser-use task outcome."
                        },
                        "final_result": {
                            "anyOf": [
                                { "type": "string" },
                                { "type": "null" }
                            ]
                        },
                        "errors": {
                            "type": "array",
                            "items": { "type": "string" }
                        },
                        "steps": {
                            "anyOf": [
                                { "type": "integer", "minimum": 0 },
                                { "type": "null" }
                            ]
                        },
                        "max_steps": {
                            "type": "integer",
                            "minimum": 1,
                            "maximum": 50
                        },
                        "task_chars": {
                            "type": "integer",
                            "minimum": 1,
                            "maximum": 4000
                        },
                        "is_done": {
                            "anyOf": [
                                { "type": "boolean" },
                                { "type": "null" }
                            ]
                        },
                        "successful": {
                            "anyOf": [
                                { "type": "boolean" },
                                { "type": "null" }
                            ]
                        },
                        "used_browser_use_agent": { "type": "boolean" },
                        "dry_run": { "type": "boolean" },
                        "truncated": { "type": "boolean" }
                    }
                },
                {
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["error"],
                    "properties": {
                        "error": { "type": "string" }
                    }
                }
            ]
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "browser.complete_task",
    input_schema,
    output_schema,
    variants: &[VariantId::A],
    profile: Profile::ProOnly,
    small_model_safe: false,
};
