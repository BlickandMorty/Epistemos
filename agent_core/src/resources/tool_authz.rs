//! Phase R.5 — per-tool authorization helper.
//!
//! Maps a tool call (`tool_name`, `input_json`, ambient vault context)
//! to a `(ResourceId, Capability)` pair that the permission store can
//! decide on. Returns `None` when:
//!   - The tool is read-only or has no resource argument we can pin
//!     down (e.g. `think`, `bash_execute`, `web_search`).
//!   - The vault root isn't known (can't build a canonical
//!     `vault://` URI without a stable vault id).
//!   - The input JSON is missing the field we'd key off.
//!
//! Keeping this inference crate-private means the gate in
//! `ToolRegistry::execute` can be strengthened or replaced without
//! FFI churn. Swift-side code never touches this helper.
//!
//! See `docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md` §Phase R.5 for the
//! authorization model and `docs/KNOWN_ISSUES_REGISTER.md` I-009 for
//! the underlying bug class this gates against.

use std::path::Path;

use serde_json::Value;

use super::id::ResourceId;
use super::attachments::Capability;
use crate::tools::registry::RiskLevel;

/// Result of the tool → authorization inference. `None` means
/// "either not a resource-targeting tool or we can't pin down the
/// target" — the gate must make its own decision about how to treat
/// unresolvable calls (current policy: allow, log).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ToolAuthzTarget {
    pub resource: ResourceId,
    pub capability: Capability,
}

/// Compute the authorization target for a tool call, or `None` if
/// this tool is not gateable (read-only, no resource argument, etc.).
///
/// Kept deliberately conservative — when in doubt, returns `None` so
/// the gate defaults to "allow + log" rather than "deny by default".
/// The set of gateable tools will expand in follow-up commits as we
/// audit each tool individually.
pub fn infer_tool_authz_target(
    tool_name: &str,
    input: &Value,
    risk_level: &RiskLevel,
    vault_root: Option<&Path>,
) -> Option<ToolAuthzTarget> {
    // Read-only tools never need a write-gate. Their permission model
    // is the existing tier/allowlist check — R.5 grants are about
    // *mutation* of specific resources.
    if matches!(risk_level, RiskLevel::ReadOnly) {
        return None;
    }

    match tool_name {
        // Vault note writes — the flagship case. `path` is
        // vault-relative; vault id comes from the active vault root's
        // last component (matches the Swift-side convention in
        // `AppBootstrap.initializeRustResourceServiceIfReady`).
        "vault_write" => {
            let path = input.get("path")?.as_str()?;
            let vault_id = vault_id_from_root(vault_root?)?;
            let trimmed_path = path.trim().trim_start_matches('/');
            if trimmed_path.is_empty() {
                return None;
            }
            Some(ToolAuthzTarget {
                resource: ResourceId::VaultNote {
                    vault_id,
                    note_id: trimmed_path.to_string(),
                },
                capability: Capability::Write,
            })
        }
        // Everything else: currently unrecognized. Returning None
        // means the gate logs "not gateable" and does not block.
        // Follow-up commits will extend this match arm by arm so each
        // expansion is independently reviewable.
        _ => None,
    }
}

/// Derive the stable vault id we use across the FFI from an absolute
/// vault root path. Mirrors the Swift side's
/// `vaultURL.lastPathComponent` fallback to "default" so both ends of
/// the bridge agree on the identity that shows up in
/// `vault://{vault_id}/note/...` URIs.
fn vault_id_from_root(vault_root: &Path) -> Option<String> {
    let raw = vault_root.file_name()?.to_string_lossy().to_string();
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        Some("default".to_string())
    } else {
        Some(trimmed.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use std::path::PathBuf;

    fn write_risk() -> RiskLevel {
        RiskLevel::Modification
    }

    fn destructive_risk() -> RiskLevel {
        RiskLevel::Destructive
    }

    fn read_risk() -> RiskLevel {
        RiskLevel::ReadOnly
    }

    #[test]
    fn vault_write_with_vault_root_emits_vault_note_write() {
        let input = json!({"path": "Inbox/Alpha.md", "content": "body"});
        let root = PathBuf::from("/tmp/my-vault");
        let target = infer_tool_authz_target("vault_write", &input, &write_risk(), Some(&root))
            .expect("vault_write with a path should yield a target");
        assert_eq!(target.capability, Capability::Write);
        match target.resource {
            ResourceId::VaultNote { vault_id, note_id } => {
                assert_eq!(vault_id, "my-vault");
                assert_eq!(note_id, "Inbox/Alpha.md");
            }
            _ => panic!("expected VaultNote variant, got {:?}", target.resource),
        }
    }

    #[test]
    fn vault_write_strips_leading_slash_from_path() {
        let input = json!({"path": "/Inbox/Beta.md", "content": "body"});
        let root = PathBuf::from("/vaults/main");
        let target = infer_tool_authz_target("vault_write", &input, &write_risk(), Some(&root))
            .expect("vault_write should normalize leading slash");
        match target.resource {
            ResourceId::VaultNote { vault_id, note_id } => {
                assert_eq!(vault_id, "main");
                assert_eq!(note_id, "Inbox/Beta.md");
            }
            _ => panic!("expected VaultNote variant"),
        }
    }

    #[test]
    fn vault_write_without_vault_root_returns_none() {
        let input = json!({"path": "Inbox/Gamma.md", "content": "body"});
        // No vault root → can't build a canonical URI.
        assert!(
            infer_tool_authz_target("vault_write", &input, &write_risk(), None).is_none()
        );
    }

    #[test]
    fn vault_write_without_path_returns_none() {
        let input = json!({"content": "body"});
        let root = PathBuf::from("/tmp/my-vault");
        assert!(
            infer_tool_authz_target("vault_write", &input, &write_risk(), Some(&root)).is_none()
        );
    }

    #[test]
    fn vault_write_with_empty_path_returns_none() {
        let input = json!({"path": "", "content": "body"});
        let root = PathBuf::from("/tmp/my-vault");
        assert!(
            infer_tool_authz_target("vault_write", &input, &write_risk(), Some(&root)).is_none()
        );
        let only_slash = json!({"path": "/", "content": "body"});
        assert!(
            infer_tool_authz_target("vault_write", &only_slash, &write_risk(), Some(&root)).is_none()
        );
    }

    #[test]
    fn read_only_tools_are_not_gateable() {
        // Even if the tool name happens to match our vault-write
        // pattern, a ReadOnly risk level must short-circuit to None
        // so the gate doesn't bother consulting the store.
        let input = json!({"path": "Inbox/Anything.md"});
        let root = PathBuf::from("/tmp/my-vault");
        assert!(
            infer_tool_authz_target("vault_write", &input, &read_risk(), Some(&root)).is_none()
        );
    }

    #[test]
    fn unrecognized_tool_returns_none_even_with_write_risk() {
        // Future tools will be added arm-by-arm. Until then, unknown
        // tools are "not gateable" so the gate allows + logs rather
        // than rejecting what might be a legitimate non-resource op.
        let input = json!({"command": "ls -la"});
        let root = PathBuf::from("/tmp/my-vault");
        assert!(
            infer_tool_authz_target("bash_execute", &input, &destructive_risk(), Some(&root))
                .is_none()
        );
    }

    #[test]
    fn empty_vault_root_path_component_falls_back_to_default() {
        // Corner case: a vault root path ending in something that
        // produces an empty `file_name()` should fall back to the
        // "default" id that AppBootstrap uses. We guard with a
        // trailing "." to have a real file_name.
        let root = PathBuf::from("/");
        // `/`.file_name() is None so the helper returns None —
        // we can't even build an id; the gate must allow-and-log.
        let input = json!({"path": "Inbox/NoRoot.md", "content": "body"});
        assert!(
            infer_tool_authz_target("vault_write", &input, &write_risk(), Some(&root)).is_none()
        );
    }
}
