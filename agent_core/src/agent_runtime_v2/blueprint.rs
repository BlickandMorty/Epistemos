//! `AgentBlueprint` — the typed agent identity that belongs to Epistemos.
//!
//! Per prior design intent (`docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md`
//! §3): provider is replaceable; memory, tools, permissions, schema
//! contracts, artifacts, and audit trail are NOT. The blueprint is the
//! single source of truth for what an agent IS — created once by the
//! user and persisted in the vault.
//!
//! Iter-5 scope: just enough shape to drive the typed flow tests. Full
//! `MemoryScope` / `ToolPolicy` / `PermissionPolicy` / `OutputContract`
//! land in later iterations.

use serde::{Deserialize, Serialize};

use crate::cognitive_dag::node::Hash;

use super::budget::BudgetSpec;
use super::mode::AgentRuntimeV2Mode;

/// Vault-stable identifier. The user-visible name is stored on
/// `display_name`; this is the durable handle used across replay.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct AgentBlueprintId(pub String);

impl std::fmt::Display for AgentBlueprintId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

/// Which executor adapter family hosts the agent's brain.
///
/// `ProCli` is Pro-only and reachable only under
/// `AgentRuntimeV2Mode::Subprocess`. MAS V1 (`Disabled`) refuses any
/// provider. Pro V1.x (`IpcBounded`) refuses `ProCli`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case", tag = "kind")]
pub enum ProviderPolicy {
    LocalMlx { model_id: String },
    AnthropicMessages { model: String },
    OpenAIResponses { model: String },
    OpenAICompatible { base_url: String, model: String },
    Mcp { server_id: String },
    ProCli { adapter: CliAdapter, command: String },
}

/// Pro-only CLI adapter family. The named binary is launched only
/// when `AgentRuntimeV2Mode::Subprocess` is the active mode and is
/// hardened via `security::harden_cli_subprocess`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CliAdapter {
    ClaudeCode,
    Codex,
    Goose,
    Aider,
    OpenHands,
    SweAgent,
}

/// The typed agent identity. Persists via serde into
/// `vault/agents/<id>.json`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AgentBlueprint {
    pub id: AgentBlueprintId,
    pub display_name: String,
    pub provider_policy: ProviderPolicy,
    pub budget: BudgetSpec,
    /// BLAKE3 over the Sovereign Gate session root that issues the
    /// macaroons backing this agent's capabilities. Binds the
    /// blueprint to a session — flipping to a different session
    /// requires reissuing capabilities.
    pub capability_root_hash: Hash,
}

/// Reasons a blueprint cannot run under a given `AgentRuntimeV2Mode`.
/// Surfaced by `AgentBlueprint::check_against_mode` so the dispatcher
/// can short-circuit before any executor work.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BlueprintModeError {
    /// Active mode is `Disabled` — v2 is dormant (MAS V1).
    ModeDisabled,
    /// Active mode is `IpcBounded` but the blueprint requests a Pro
    /// CLI subprocess adapter. MAS V1 and Pro V1.x both refuse
    /// subprocess executors.
    SubprocessNotAllowed,
}

impl AgentBlueprint {
    /// True iff `provider_policy` is `ProCli` — the only variant that
    /// requires subprocess mode. Dispatcher convenience for tier
    /// gating; avoids open-coding the pattern at every call site.
    #[must_use]
    pub const fn is_subprocess_provider(&self) -> bool {
        matches!(self.provider_policy, ProviderPolicy::ProCli { .. })
    }

    /// Aggregate the minimum modes required by a batch of
    /// blueprints. Returns the set of `AgentRuntimeV2Mode` values
    /// such that EVERY blueprint can run under at least one mode in
    /// the set. Audit / capacity-planning helper.
    ///
    /// Concretely: any blueprint with `is_subprocess_provider()`
    /// contributes `Subprocess`; the rest contribute `IpcBounded`.
    /// (`Disabled` is never contributed — that mode is dormant.)
    #[must_use]
    pub fn aggregate_required_modes(
        blueprints: &[Self],
    ) -> std::collections::BTreeSet<AgentRuntimeV2Mode> {
        let mut modes = std::collections::BTreeSet::new();
        for bp in blueprints {
            if bp.is_subprocess_provider() {
                modes.insert(AgentRuntimeV2Mode::Subprocess);
            } else {
                modes.insert(AgentRuntimeV2Mode::IpcBounded);
            }
        }
        modes
    }

    /// Return the canonical vault persistence path for this
    /// blueprint: `<vault_root>/agents/<id>.json`. Pins the storage
    /// convention so loaders and savers agree on a single shape.
    /// Pure path construction; does NOT touch the filesystem.
    #[must_use]
    pub fn vault_persistence_path(&self, vault_root: &str) -> String {
        let trimmed = vault_root.trim_end_matches('/');
        format!("{}/agents/{}.json", trimmed, self.id.0)
    }

    /// Gate the blueprint against the active runtime mode. The §4 T11
    /// "MAS cannot call CLI" invariant lives here: when `mode ==
    /// Disabled`, every provider is refused; when `mode ==
    /// IpcBounded`, `ProCli` is refused.
    pub fn check_against_mode(
        &self,
        mode: AgentRuntimeV2Mode,
    ) -> Result<(), BlueprintModeError> {
        match (mode, &self.provider_policy) {
            (AgentRuntimeV2Mode::Disabled, _) => Err(BlueprintModeError::ModeDisabled),
            (AgentRuntimeV2Mode::IpcBounded, ProviderPolicy::ProCli { .. }) => {
                Err(BlueprintModeError::SubprocessNotAllowed)
            }
            _ => Ok(()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn local_blueprint() -> AgentBlueprint {
        AgentBlueprint {
            id: AgentBlueprintId("research-assistant".to_string()),
            display_name: "Research Assistant".to_string(),
            provider_policy: ProviderPolicy::LocalMlx {
                model_id: "qwen3.5-8b".to_string(),
            },
            budget: BudgetSpec::new(8_000, 60_000, 32, 0),
            capability_root_hash: Hash::zero(),
        }
    }

    fn cli_blueprint() -> AgentBlueprint {
        AgentBlueprint {
            id: AgentBlueprintId("codex-driver".to_string()),
            display_name: "Codex Driver".to_string(),
            provider_policy: ProviderPolicy::ProCli {
                adapter: CliAdapter::Codex,
                command: "/usr/local/bin/codex".to_string(),
            },
            budget: BudgetSpec::new(0, 0, 0, 60_000),
            capability_root_hash: Hash::zero(),
        }
    }

    #[test]
    fn blueprint_mode_error_debug_repr_is_stable_for_audit_persistence() {
        // Phase 1 hardening — audit dashboards persist Debug repr
        // of BlueprintModeError when surfacing mode-gate denials.
        // Pin both variants so a maintainer rename doesn't silently
        // change the printed form.
        assert_eq!(format!("{:?}", BlueprintModeError::ModeDisabled), "ModeDisabled");
        assert_eq!(
            format!("{:?}", BlueprintModeError::SubprocessNotAllowed),
            "SubprocessNotAllowed"
        );
    }

    #[test]
    fn mas_disabled_mode_refuses_every_provider_variant() {
        // Phase 1 hardening — MAS-only mode survey. Iterate every
        // ProviderPolicy variant + Disabled mode; assert every one
        // returns ModeDisabled. Closes the door on adding a new
        // provider variant without auditing its Disabled-mode
        // behaviour first.
        let mas = AgentRuntimeV2Mode::Disabled;
        let providers = [
            ProviderPolicy::LocalMlx { model_id: "qwen3.5".into() },
            ProviderPolicy::AnthropicMessages { model: "claude-sonnet-4-6".into() },
            ProviderPolicy::OpenAIResponses { model: "gpt-5".into() },
            ProviderPolicy::OpenAICompatible {
                base_url: "http://localhost:11434".into(),
                model: "llama".into(),
            },
            ProviderPolicy::Mcp { server_id: "mcp-vault".into() },
            ProviderPolicy::ProCli {
                adapter: CliAdapter::ClaudeCode,
                command: "/usr/local/bin/claude".into(),
            },
        ];
        for provider in providers {
            let bp = AgentBlueprint {
                id: AgentBlueprintId("survey".into()),
                display_name: "Survey".into(),
                provider_policy: provider.clone(),
                budget: BudgetSpec::default(),
                capability_root_hash: Hash::zero(),
            };
            assert_eq!(
                bp.check_against_mode(mas),
                Err(BlueprintModeError::ModeDisabled),
                "Disabled mode must refuse {provider:?}"
            );
        }
    }

    #[test]
    fn mas_cannot_call_cli() {
        // §4 T11 acceptance: "MAS cannot call CLI". With mode ==
        // Disabled, even the local provider is refused (v2 is dormant
        // in MAS V1); ProCli is doubly refused.
        let bp = local_blueprint();
        assert_eq!(
            bp.check_against_mode(AgentRuntimeV2Mode::Disabled),
            Err(BlueprintModeError::ModeDisabled),
            "MAS V1 must refuse every v2 blueprint"
        );

        let cli = cli_blueprint();
        assert_eq!(
            cli.check_against_mode(AgentRuntimeV2Mode::Disabled),
            Err(BlueprintModeError::ModeDisabled),
            "MAS V1 cannot run a Pro CLI blueprint"
        );
    }

    #[test]
    fn pro_bounded_refuses_subprocess() {
        // Pro V1.x runs in-process; ProCli requires Subprocess mode.
        let cli = cli_blueprint();
        assert_eq!(
            cli.check_against_mode(AgentRuntimeV2Mode::IpcBounded),
            Err(BlueprintModeError::SubprocessNotAllowed)
        );
    }

    #[test]
    fn pro_bounded_accepts_in_process_providers() {
        let bp = local_blueprint();
        bp.check_against_mode(AgentRuntimeV2Mode::IpcBounded)
            .expect("local MLX must run in Pro V1.x");
    }

    #[test]
    fn research_subprocess_accepts_all_providers() {
        local_blueprint()
            .check_against_mode(AgentRuntimeV2Mode::Subprocess)
            .expect("local MLX must run under Subprocess");
        cli_blueprint()
            .check_against_mode(AgentRuntimeV2Mode::Subprocess)
            .expect("ProCli must run under Subprocess");
    }

    #[test]
    fn aggregate_required_modes_returns_minimum_set_for_batch() {
        // Empty batch → empty set.
        let empty = AgentBlueprint::aggregate_required_modes(&[]);
        assert!(empty.is_empty());
        // All-local batch → only IpcBounded.
        let locals = vec![local_blueprint(), local_blueprint()];
        let set = AgentBlueprint::aggregate_required_modes(&locals);
        assert_eq!(set.len(), 1);
        assert!(set.contains(&AgentRuntimeV2Mode::IpcBounded));
        // All-CLI batch → only Subprocess.
        let clis = vec![cli_blueprint()];
        let set = AgentBlueprint::aggregate_required_modes(&clis);
        assert_eq!(set.len(), 1);
        assert!(set.contains(&AgentRuntimeV2Mode::Subprocess));
        // Mixed → both.
        let mixed = vec![local_blueprint(), cli_blueprint(), local_blueprint()];
        let set = AgentBlueprint::aggregate_required_modes(&mixed);
        assert_eq!(set.len(), 2);
        assert!(set.contains(&AgentRuntimeV2Mode::IpcBounded));
        assert!(set.contains(&AgentRuntimeV2Mode::Subprocess));
        // Disabled never appears.
        assert!(!set.contains(&AgentRuntimeV2Mode::Disabled));
    }

    #[test]
    fn vault_persistence_path_is_canonical_shape() {
        let bp = local_blueprint();
        // Standard root.
        assert_eq!(
            bp.vault_persistence_path("/Users/jojo/vault"),
            "/Users/jojo/vault/agents/research-assistant.json"
        );
        // Trailing slash on root is trimmed.
        assert_eq!(
            bp.vault_persistence_path("/Users/jojo/vault/"),
            "/Users/jojo/vault/agents/research-assistant.json"
        );
        // Multiple trailing slashes also trimmed.
        assert_eq!(
            bp.vault_persistence_path("/Users/jojo/vault///"),
            "/Users/jojo/vault/agents/research-assistant.json"
        );
        // Relative root works too.
        assert_eq!(
            bp.vault_persistence_path("vault"),
            "vault/agents/research-assistant.json"
        );
    }

    #[test]
    fn is_subprocess_provider_matches_only_pro_cli() {
        // Phase 1 hardening — dispatcher tier-gate helper. Only
        // ProCli requires subprocess mode; every other variant is
        // in-process.
        assert!(cli_blueprint().is_subprocess_provider());
        assert!(!local_blueprint().is_subprocess_provider());
        // Cover the other in-process providers explicitly.
        for provider in [
            ProviderPolicy::AnthropicMessages { model: "claude".into() },
            ProviderPolicy::OpenAIResponses { model: "gpt".into() },
            ProviderPolicy::OpenAICompatible {
                base_url: "http://localhost".into(),
                model: "llama".into(),
            },
            ProviderPolicy::Mcp { server_id: "mcp".into() },
        ] {
            let bp = AgentBlueprint {
                id: AgentBlueprintId("p".into()),
                display_name: "p".into(),
                provider_policy: provider,
                budget: BudgetSpec::default(),
                capability_root_hash: Hash::zero(),
            };
            assert!(!bp.is_subprocess_provider());
        }
    }

    #[test]
    fn blueprint_id_display_writes_inner_string_verbatim() {
        let id = AgentBlueprintId("research-assistant".to_string());
        assert_eq!(format!("{id}"), "research-assistant");
        let unicode_id = AgentBlueprintId("研究助手-α".to_string());
        assert_eq!(format!("{unicode_id}"), "研究助手-α");
    }

    #[test]
    fn blueprint_id_round_trips_through_json_unchanged() {
        // Phase 1 hardening — AgentBlueprintId is the vault-stable
        // handle for an agent. Serialising and deserialising must
        // preserve the ID exactly so two reads of the same
        // vault/agents/<id>.json file produce equal blueprints.
        let id = AgentBlueprintId("research-assistant-2026".to_string());
        let s = serde_json::to_string(&id).expect("serialise");
        let back: AgentBlueprintId = serde_json::from_str(&s).expect("deserialise");
        assert_eq!(back, id);
        // Unicode safe: an ID with non-ASCII characters survives.
        let unicode_id = AgentBlueprintId("研究助手-α".to_string());
        let s2 = serde_json::to_string(&unicode_id).expect("serialise");
        let back2: AgentBlueprintId = serde_json::from_str(&s2).expect("deserialise");
        assert_eq!(back2, unicode_id);
    }

    #[test]
    fn blueprint_id_inequality_distinguishes_different_ids() {
        let a = AgentBlueprintId("agent-a".to_string());
        let b = AgentBlueprintId("agent-b".to_string());
        assert_ne!(a, b);
        // Hash differs too — for use as HashMap key.
        use std::collections::HashMap;
        let mut m = HashMap::new();
        m.insert(a.clone(), 1);
        m.insert(b.clone(), 2);
        assert_eq!(m.get(&a), Some(&1));
        assert_eq!(m.get(&b), Some(&2));
    }

    #[test]
    fn changing_capability_root_hash_changes_blueprint_identity() {
        // Phase 1 hardening — the capability_root_hash field binds
        // the blueprint to a Sovereign Gate session root key. If two
        // blueprints differ ONLY in capability_root_hash, they must
        // compare as not equal — otherwise a session-key swap would
        // be invisible to the dispatcher and any caller relying on
        // blueprint equality (e.g. de-dup cache, audit trail).
        let mut a = local_blueprint();
        let mut b = local_blueprint();
        assert_eq!(a, b);
        b.capability_root_hash = Hash::from_bytes([42u8; 32]);
        assert_ne!(a, b, "capability_root_hash diff must break equality");
        // Round-trip the altered version: JSON path must preserve the
        // hash bit-for-bit.
        let s = serde_json::to_string(&b).expect("serialize");
        let back: AgentBlueprint = serde_json::from_str(&s).expect("deserialize");
        assert_eq!(back.capability_root_hash, b.capability_root_hash);
        assert_eq!(back, b);
        // Reset a to the same hash and verify equality is restored.
        a.capability_root_hash = b.capability_root_hash;
        assert_eq!(a, b);
    }

    #[test]
    fn blueprint_round_trips_through_json() {
        let bp = cli_blueprint();
        let s = serde_json::to_string(&bp).expect("serialize");
        let back: AgentBlueprint = serde_json::from_str(&s).expect("deserialize");
        assert_eq!(back, bp);
    }
}
