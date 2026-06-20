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
                },
                "allow_remote_skill_install": {
                    "type": "boolean",
                    "default": false,
                    "description": "Must be true to consent to a network clone/fetch before install_from_github / install_from_url runs (the remote-install consent gate). Declared here so the strict `additionalProperties:false` schema doesn't reject it — without it the install verbs are unreachable. The Pro/quarantine gating of remote install is unchanged; this only lets the consent field be passed."
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn input_schema_declares_remote_install_consent_so_installs_are_reachable() {
        // S4 audit: the v2 skills.manage schema sets additionalProperties:false but
        // omitted `allow_remote_skill_install` (the network-consent gate the install
        // verbs require) → install_from_github/url were UNREACHABLE. Pins the fix.
        let schema = input_schema();
        let props = schema["properties"].as_object().unwrap();
        assert!(
            props.contains_key("allow_remote_skill_install"),
            "consent gate must be declared so additionalProperties:false doesn't reject it"
        );
        // The strict gate is intentionally preserved (only the field is now declarable).
        assert_eq!(schema["additionalProperties"], json!(false));
        // The remote-install actions remain enumerable.
        let actions = schema["properties"]["action"]["enum"].as_array().unwrap();
        let action_strs: Vec<&str> = actions.iter().filter_map(|a| a.as_str()).collect();
        assert!(action_strs.contains(&"install_from_github"));
        assert!(action_strs.contains(&"install_from_url"));
    }
}
