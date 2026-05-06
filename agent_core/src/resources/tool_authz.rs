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

use super::attachments::Capability;
use super::id::ResourceId;
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
            vault_note_target_from_path(input.get("path")?, vault_root, Capability::Write)
        }
        // Template instantiation writes a new vault note at
        // `output_path`, so it uses the same resource gate as
        // `vault_write` rather than bypassing Sovereign Gate policy.
        "note_template" => {
            vault_note_target_from_path(input.get("output_path")?, vault_root, Capability::Write)
        }
        // Generic filesystem write — absolute (or `~/`-expanded) path.
        // The handler in `tools::filesystem::WriteFileHandler` creates
        // the file if missing and overwrites if present; the gate
        // rides on `Capability::Write` either way (grants carrying
        // `Write` imply the ability to create at the same location).
        "write_file" => file_target_from_path(input.get("path")?, Capability::Write),
        // In-place fuzzy patch — requires the file to already exist,
        // so this is always a `Write` against an existing resource.
        "patch" => file_target_from_path(input.get("path")?, Capability::Write),
        // Training-dataset export. When `output_path` is provided the
        // handler writes a JSONL file; when omitted it returns the
        // first 20 lines inline (no write). Only gate the write path.
        "trajectory_export" => {
            let output = input.get("output_path")?;
            file_target_from_path(output, Capability::Write)
        }
        // Everything else currently unrecognized. This covers the
        // mutating tools that don't have a natural `ResourceId`
        // today:
        //   * Shell / passthrough: `bash_execute`, `process`,
        //     `claude_code`, `codex`. They don't target a single
        //     resource; the command string is the whole thing. Tier
        //     + allowlist gating in `is_tool_permitted` is what
        //     holds them.
        //   * Messaging: `send_message`, `imessage`, `apple_mail`,
        //     `imessage_contacts`, `channel_contacts`. No URI scheme
        //     for outbound message destinations exists yet.
        //   * AppleScript apps: `apple_notes`, `apple_reminders`,
        //     `apple_calendar`. No URI scheme for cross-app resources.
        //   * UI / device: `interact`, browser_*. Target is an AX
        //     element or browser tab, not a stable resource.
        //   * Local-state tools: `memory`, `skill_manage`,
        //     `tool_manage`, `cronjob`, `ssm_resume`,
        //     `nightbrain_trigger`. Each could grow a dedicated
        //     variant in `ResourceId` later; for now they bypass.
        //   * Stdio MCP tools: schema is user-supplied; we can't
        //     infer the target ahead of time.
        //
        // Returning `None` means the gate allows + logs — it does
        // not block. Default enforcement still kicks in for the
        // three file-targeting arms above.
        _ => None,
    }
}

fn vault_note_target_from_path(
    path_value: &Value,
    vault_root: Option<&Path>,
    capability: Capability,
) -> Option<ToolAuthzTarget> {
    let path = path_value.as_str()?;
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
        capability,
    })
}

/// Shared helper for arms whose input shape is `{ "path": String }`
/// and whose resource is a generic filesystem `File`. Handles the
/// same `~/` expansion logic as `tools::filesystem::resolve_path` so
/// authorization works off the path the handler will actually act
/// on. Returns `None` when the JSON field is absent, non-string,
/// empty, or expansion produces an empty buffer.
fn file_target_from_path(path_value: &Value, capability: Capability) -> Option<ToolAuthzTarget> {
    let raw = path_value.as_str()?;
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return None;
    }
    let expanded = if let Some(rest) = trimmed.strip_prefix("~/") {
        match dirs::home_dir() {
            Some(home) => home.join(rest),
            None => return None,
        }
    } else if trimmed == "~" {
        dirs::home_dir()?
    } else {
        std::path::PathBuf::from(trimmed)
    };
    let absolute_path = expanded.to_string_lossy().to_string();
    if absolute_path.is_empty() {
        return None;
    }
    Some(ToolAuthzTarget {
        resource: ResourceId::File { absolute_path },
        capability,
    })
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
    fn note_template_output_path_emits_vault_note_write() {
        let input = json!({"template": "# {{title}}", "output_path": "Templates/Alpha.md"});
        let root = PathBuf::from("/vaults/main");
        let target = infer_tool_authz_target("note_template", &input, &write_risk(), Some(&root))
            .expect("note_template should gate the output_path write");
        assert_eq!(target.capability, Capability::Write);
        match target.resource {
            ResourceId::VaultNote { vault_id, note_id } => {
                assert_eq!(vault_id, "main");
                assert_eq!(note_id, "Templates/Alpha.md");
            }
            _ => panic!("expected VaultNote variant"),
        }
    }

    #[test]
    fn vault_write_without_vault_root_returns_none() {
        let input = json!({"path": "Inbox/Gamma.md", "content": "body"});
        // No vault root → can't build a canonical URI.
        assert!(infer_tool_authz_target("vault_write", &input, &write_risk(), None).is_none());
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
            infer_tool_authz_target("vault_write", &only_slash, &write_risk(), Some(&root))
                .is_none()
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

    // ── write_file arm ────────────────────────────────────────────
    #[test]
    fn write_file_absolute_path_emits_file_write() {
        let input = json!({"path": "/tmp/authz/example.txt", "content": "body"});
        let target = infer_tool_authz_target("write_file", &input, &write_risk(), None)
            .expect("write_file with absolute path should yield a target");
        assert_eq!(target.capability, Capability::Write);
        match target.resource {
            ResourceId::File { absolute_path } => {
                assert_eq!(absolute_path, "/tmp/authz/example.txt");
            }
            other => panic!("expected File variant, got {other:?}"),
        }
    }

    #[test]
    fn write_file_home_expanded_path_resolves_under_home() {
        let Some(home) = dirs::home_dir() else {
            return; // can't run the assertion in an env without HOME
        };
        let input = json!({"path": "~/scratch/authz.txt", "content": "body"});
        let target = infer_tool_authz_target("write_file", &input, &write_risk(), None)
            .expect("~/ prefix should still produce a file target");
        match target.resource {
            ResourceId::File { absolute_path } => {
                let expected = home.join("scratch/authz.txt").to_string_lossy().to_string();
                assert_eq!(absolute_path, expected);
            }
            other => panic!("expected File variant, got {other:?}"),
        }
    }

    #[test]
    fn write_file_missing_path_returns_none() {
        let input = json!({"content": "body"});
        assert!(infer_tool_authz_target("write_file", &input, &write_risk(), None).is_none());
    }

    #[test]
    fn write_file_empty_path_returns_none() {
        let input = json!({"path": "   ", "content": "body"});
        assert!(infer_tool_authz_target("write_file", &input, &write_risk(), None).is_none());
    }

    // ── patch arm ──────────────────────────────────────────────────
    #[test]
    fn patch_absolute_path_emits_file_write() {
        let input = json!({
            "path": "/tmp/authz/patch-me.rs",
            "old_string": "fn old()",
            "new_string": "fn new()"
        });
        let target = infer_tool_authz_target("patch", &input, &write_risk(), None)
            .expect("patch with path should yield a file target");
        assert_eq!(target.capability, Capability::Write);
        match target.resource {
            ResourceId::File { absolute_path } => {
                assert_eq!(absolute_path, "/tmp/authz/patch-me.rs");
            }
            other => panic!("expected File variant, got {other:?}"),
        }
    }

    #[test]
    fn patch_missing_path_returns_none() {
        let input = json!({"old_string": "x", "new_string": "y"});
        assert!(infer_tool_authz_target("patch", &input, &write_risk(), None).is_none());
    }

    // ── trajectory_export arm ─────────────────────────────────────
    #[test]
    fn trajectory_export_with_output_path_emits_file_write() {
        let input = json!({
            "output_path": "/tmp/authz/traj.jsonl",
            "limit": 10
        });
        let target = infer_tool_authz_target("trajectory_export", &input, &write_risk(), None)
            .expect("trajectory_export with output_path should yield a file target");
        assert_eq!(target.capability, Capability::Write);
        match target.resource {
            ResourceId::File { absolute_path } => {
                assert_eq!(absolute_path, "/tmp/authz/traj.jsonl");
            }
            other => panic!("expected File variant, got {other:?}"),
        }
    }

    #[test]
    fn trajectory_export_without_output_path_returns_none() {
        // Inline (no output_path) is a read-surface return — no file
        // is written, so the gate has nothing to authorize.
        let input = json!({"limit": 10});
        assert!(
            infer_tool_authz_target("trajectory_export", &input, &write_risk(), None).is_none()
        );
    }

    // ── non-resourceable mutating tools ───────────────────────────
    //
    // These all fall through the catch-all. The behaviour is load-
    // bearing: flipping default enforcement on (Step 2) must NOT
    // block them via the R.5 gate because we can't describe their
    // targets as ResourceIds. Tier/allowlist gating still applies
    // upstream in `ToolRegistry::is_tool_permitted`.
    #[test]
    fn non_resourceable_mutating_tools_return_none() {
        let root = PathBuf::from("/tmp/my-vault");
        let cases: &[(&str, Value, RiskLevel)] = &[
            ("bash_execute", json!({"command": "ls"}), destructive_risk()),
            ("process", json!({"action": "list"}), destructive_risk()),
            (
                "claude_code",
                json!({"task": "refactor"}),
                destructive_risk(),
            ),
            ("codex", json!({"task": "refactor"}), destructive_risk()),
            (
                "send_message",
                json!({"platform": "slack", "message": "hi"}),
                destructive_risk(),
            ),
            (
                "imessage",
                json!({"action": "send", "to": "me", "message": "hi"}),
                destructive_risk(),
            ),
            (
                "apple_mail",
                json!({"action": "send", "to": "me", "subject": "s", "body": "b"}),
                destructive_risk(),
            ),
            (
                "apple_notes",
                json!({"action": "create", "title": "t", "content": "c"}),
                write_risk(),
            ),
            (
                "apple_reminders",
                json!({"action": "add", "title": "t"}),
                write_risk(),
            ),
            (
                "apple_calendar",
                json!({"action": "create", "title": "t"}),
                write_risk(),
            ),
            (
                "imessage_contacts",
                json!({"action": "set", "handle": "h"}),
                write_risk(),
            ),
            (
                "channel_contacts",
                json!({"action": "set", "channel_id": "slack", "handle": "h"}),
                write_risk(),
            ),
            (
                "interact",
                json!({"app_name": "Safari", "action": "click", "target": "Go"}),
                write_risk(),
            ),
            (
                "browser_click",
                json!({"selector": "#go"}),
                destructive_risk(),
            ),
            (
                "browser_type",
                json!({"selector": "#i", "text": "hi"}),
                destructive_risk(),
            ),
            (
                "browser_navigate",
                json!({"url": "https://x"}),
                write_risk(),
            ),
            (
                "memory",
                json!({"action": "add", "content": "x"}),
                write_risk(),
            ),
            (
                "skill_manage",
                json!({"action": "create", "name": "s", "content": "c"}),
                write_risk(),
            ),
            (
                "tool_manage",
                json!({"action": "create", "spec": {}}),
                write_risk(),
            ),
            (
                "cronjob",
                json!({"action": "create", "schedule": "* * * * * *", "prompt": "p"}),
                write_risk(),
            ),
            (
                "ssm_resume",
                json!({"action": "save", "session_id": "s"}),
                write_risk(),
            ),
            (
                "nightbrain_trigger",
                json!({"job": "event_checkpoint"}),
                write_risk(),
            ),
        ];
        for (name, input, risk) in cases {
            assert!(
                infer_tool_authz_target(name, input, risk, Some(&root)).is_none(),
                "{name} must fall through to None (no ResourceId mapping today)"
            );
        }
    }
}
