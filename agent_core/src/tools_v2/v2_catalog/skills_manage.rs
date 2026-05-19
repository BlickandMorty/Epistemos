//! `skills.manage` — create/edit/delete/install skills with frontmatter
//! validation + 15KB cap + 40-rule security scanner on installs. Plan
//! §3.5 skills family. Modification.
//!
//! Per FINAL_SYNTHESIS §1.1 (Live File Compiler) + plan §17
//! Compile-Verify-Mint: skill mutations are exactly the case where the
//! schema-validation + capability-validation + sandbox-dry-run + permission-
//! manifest gate must fire. Wave 6+ tightens that surface; until then the
//! handler's existing 40-rule scanner is the live gate. `small_model_safe:
//! false` so the 1.5B router can't auto-promote a quarantined install.

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
            "required": ["action"],
            "properties": {
                "action": {
                    "type": "string",
                    "enum": [
                        "create",
                        "edit",
                        "delete",
                        "install_from_github",
                        "install_from_url",
                        "install_from_local_path"
                    ]
                },
                "name": { "type": "string" },
                "content": {
                    "type": "string",
                    "maxLength": 15360,
                    "description": "Full SKILL.md content (15KB hard cap per §17)."
                },
                "category": { "type": "string" },
                "git_url": { "type": "string" },
                "url": { "type": "string" },
                "path": { "type": "string" },
                "approve": {
                    "type": "boolean",
                    "default": false,
                    "description": "Set to true to promote an already-quarantined install."
                }
            }
        })
    })
}

pub const SPEC: AdapterSpec = AdapterSpec {
    name: "skills.manage",
    input_schema,
    output_schema: generic_text_or_object_output_schema,
    variants: &[VariantId::A],
    profile: Profile::AppStoreSafe,
    small_model_safe: false,
};
