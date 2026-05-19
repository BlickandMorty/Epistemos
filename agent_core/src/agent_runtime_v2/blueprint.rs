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
    fn agent_blueprint_and_provider_policy_are_clone_send_sync_but_not_copy() {
        // Phase 1 hardening — trait-bound pin for the String-bearing
        // structs in blueprint.rs. Companion to:
        //   - AgentBlueprintId iter-375
        //   - MissionPacket + ToolCall iter-376
        //   - AnswerPacket + Citation iter-377
        //
        // AgentBlueprint: 5 fields (id + display_name + provider_policy
        // + budget + capability_root_hash). Clone by derive but NOT Copy
        // (Strings + Vec inside provider_policy variants allocate).
        //
        // ProviderPolicy: 6-variant enum with String-bearing payloads
        // on every variant. Clone by derive but NOT Copy.
        //
        // Send + Sync are load-bearing — blueprints + provider policies
        // are persisted to disk and reloaded across dispatcher startup;
        // they also cross the dispatcher's background-actor boundary.
        //
        // A future "let me cache a Box<dyn Provider>" inside
        // ProviderPolicy refactor that introduced a non-Send trait
        // object would silently break cross-thread propagation —
        // surface here.
        fn assert_clone_send_sync<T: Clone + Send + Sync>() {}
        assert_clone_send_sync::<AgentBlueprint>();
        assert_clone_send_sync::<ProviderPolicy>();

        // Sanity: clones are equal.
        let bp = local_blueprint();
        assert_eq!(bp.clone(), bp);
        let pp = ProviderPolicy::LocalMlx { model_id: "qwen3.5".into() };
        assert_eq!(pp.clone(), pp);
    }

    #[test]
    fn agent_blueprint_id_is_clone_send_sync_but_not_copy() {
        // Phase 1 hardening — trait-bound pin for the String-bearing
        // newtype. Unlike the unit enums covered earlier in the Copy
        // sweep, AgentBlueprintId wraps a String → it is Clone + Send
        // + Sync but NOT Copy (String allocates).
        //
        // Pin the Clone + Send + Sync bounds explicitly so a future
        // refactor that, say, swapped String for !Send Rc<String>
        // would surface immediately. (Send + Sync are load-bearing
        // because blueprint ids cross the dispatcher's background-actor
        // boundary.)
        //
        // Companion to the Copy + Send + Sync sweep that already
        // covered the unit-enum types (mode iter-366 through
        // AgentEventErrorKind iter-374).
        fn assert_clone_send_sync<T: Clone + Send + Sync>() {}
        assert_clone_send_sync::<AgentBlueprintId>();

        // Sanity: Clone yields an equal value but a distinct allocation.
        let a = AgentBlueprintId("research-assistant".into());
        let b = a.clone();
        assert_eq!(a, b);
        // Both can move into different threads — sanity using the
        // Send bound (no actual spawn; the compile gate above proves
        // it).
        std::mem::drop(a);
        std::mem::drop(b);
    }

    #[test]
    fn cli_adapter_and_blueprint_mode_error_are_copy_clone_send_sync() {
        // Phase 1 hardening — trait-bound pin sweep across blueprint.rs
        // closed-taxonomy payload enums. Companion to budget_gate,
        // mode iter-366, StopReason iter-367, VariantTier iter-368,
        // LocalAgent enums iter-369, budget closed-taxonomy iter-370.
        //
        // CliAdapter: 6-variant unit enum marked Copy via derive
        // (blueprint.rs §51). Rides inside ProviderPolicy::ProCli — the
        // dispatcher needs to copy it freely to switch executor branches.
        //
        // BlueprintModeError: 2-variant unit enum marked Copy via
        // derive (blueprint.rs §80). Returned by check_against_mode;
        // Copy lets callers propagate the error without owning.
        //
        // A future "let me add a binary_path: PathBuf to CliAdapter"
        // refactor that introduced a non-Copy payload would silently
        // force a Box / Rc indirection on the dispatcher hot path —
        // surface here.
        fn assert_copy_clone_send_sync<T: Copy + Clone + Send + Sync>() {}
        assert_copy_clone_send_sync::<CliAdapter>();
        assert_copy_clone_send_sync::<BlueprintModeError>();

        // Runtime sanity.
        let a = CliAdapter::ClaudeCode;
        let _x = a; let _y = a; assert_eq!(a, a);
        let e = BlueprintModeError::ModeDisabled;
        let _x = e; let _y = e; assert_eq!(e, e);
    }

    #[test]
    fn blueprint_mode_error_variants_field_shapes_pinned_via_destructure() {
        // Phase 1 hardening — field-shape pin for BlueprintModeError's
        // 2 unit variants (companion to the field-shape destructure
        // pin family iter-454..iter-458).
        //
        // Both variants are unit: ModeDisabled, SubprocessNotAllowed.
        // A future "let me add a context payload" extension to either
        // variant would silently shuffle the error surface — surface
        // here via the destructure match arm.
        let cases = [
            BlueprintModeError::ModeDisabled,
            BlueprintModeError::SubprocessNotAllowed,
        ];
        for case in cases {
            match case {
                BlueprintModeError::ModeDisabled
                | BlueprintModeError::SubprocessNotAllowed => {}
            }
        }
    }

    #[test]
    fn blueprint_mode_error_variant_count_is_two() {
        // Phase 1 hardening — cardinality pin. BlueprintModeError
        // has 2 variants (ModeDisabled, SubprocessNotAllowed)
        // surfacing the two reasons AgentBlueprint::check_against_mode
        // can refuse a run:
        //   - ModeDisabled: v2 itself is dormant (MAS V1)
        //   - SubprocessNotAllowed: Pro V1.x refuses ProCli adapter
        //
        // A future addition (e.g., ModeNotSupported for a new
        // provider that requires a tier above Subprocess) requires:
        //   - check_against_mode branch
        //   - Debug-repr pin update
        //   - dispatcher tier-gate logic update
        let variants = [
            BlueprintModeError::ModeDisabled,
            BlueprintModeError::SubprocessNotAllowed,
        ];
        assert_eq!(variants.len(), 2);
        assert_ne!(variants[0], variants[1]);
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
    fn check_against_mode_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series iter-220-232).
        // check_against_mode is a pure match over (mode, provider).
        let bp = local_blueprint();
        let r1 = bp.check_against_mode(AgentRuntimeV2Mode::IpcBounded);
        let r2 = bp.check_against_mode(AgentRuntimeV2Mode::IpcBounded);
        let r3 = bp.check_against_mode(AgentRuntimeV2Mode::IpcBounded);
        assert_eq!(r1, r2);
        assert_eq!(r2, r3);
        assert!(r1.is_ok());

        // Rejection path.
        let cli = cli_blueprint();
        let e1 = cli.check_against_mode(AgentRuntimeV2Mode::IpcBounded);
        let e2 = cli.check_against_mode(AgentRuntimeV2Mode::IpcBounded);
        assert_eq!(e1, e2);
        assert_eq!(e1, Err(BlueprintModeError::SubprocessNotAllowed));
    }

    #[test]
    fn check_against_mode_exhausts_3_modes_x_6_provider_policies_matrix() {
        // Phase 1 hardening — exhaustive 3×6=18-cell matrix
        // (companion to iter-86's LocalAgentCapability 3×2×3
        // matrix). check_against_mode combines:
        //   mode ∈ {Disabled, IpcBounded, Subprocess}        (3)
        //   provider ∈ {LocalMlx, Anthropic, OpenAIResp,
        //               OpenAICompatible, Mcp, ProCli}        (6)
        // = 18 combinations. Existing tests cover ~6 specific cells.
        // This pin enumerates ALL 18 (mode, provider, expected)
        // tuples and asserts each.
        let providers = [
            ("LocalMlx", ProviderPolicy::LocalMlx { model_id: "m".into() }),
            ("AnthropicMessages", ProviderPolicy::AnthropicMessages { model: "m".into() }),
            ("OpenAIResponses", ProviderPolicy::OpenAIResponses { model: "m".into() }),
            (
                "OpenAICompatible",
                ProviderPolicy::OpenAICompatible {
                    base_url: "u".into(),
                    model: "m".into(),
                },
            ),
            ("Mcp", ProviderPolicy::Mcp { server_id: "s".into() }),
            (
                "ProCli",
                ProviderPolicy::ProCli {
                    adapter: CliAdapter::ClaudeCode,
                    command: "c".into(),
                },
            ),
        ];
        let modes = [
            AgentRuntimeV2Mode::Disabled,
            AgentRuntimeV2Mode::IpcBounded,
            AgentRuntimeV2Mode::Subprocess,
        ];

        let mut total_cells = 0;
        for mode in modes {
            for (provider_name, provider) in &providers {
                total_cells += 1;
                let bp = AgentBlueprint {
                    id: AgentBlueprintId("matrix-fixture".into()),
                    display_name: "x".into(),
                    provider_policy: provider.clone(),
                    budget: BudgetSpec::default(),
                    capability_root_hash: Hash::zero(),
                };
                let result = bp.check_against_mode(mode);
                let expected: Result<(), BlueprintModeError> = match (mode, provider) {
                    (AgentRuntimeV2Mode::Disabled, _) => Err(BlueprintModeError::ModeDisabled),
                    (AgentRuntimeV2Mode::IpcBounded, ProviderPolicy::ProCli { .. }) => {
                        Err(BlueprintModeError::SubprocessNotAllowed)
                    }
                    _ => Ok(()),
                };
                assert_eq!(
                    result, expected,
                    "mode={mode:?} provider={provider_name} expected {expected:?} got {result:?}"
                );
            }
        }
        assert_eq!(total_cells, 18, "must enumerate all 3×6 combinations");
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
    fn aggregate_required_modes_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series). aggregate_required_modes
        // walks the blueprint slice and inserts modes into a fresh
        // BTreeSet; pure over immutable input.
        let mixed = vec![local_blueprint(), cli_blueprint(), local_blueprint()];
        let r1 = AgentBlueprint::aggregate_required_modes(&mixed);
        let r2 = AgentBlueprint::aggregate_required_modes(&mixed);
        let r3 = AgentBlueprint::aggregate_required_modes(&mixed);
        assert_eq!(r1, r2);
        assert_eq!(r2, r3);
        assert_eq!(r1.len(), 2);
    }

    #[test]
    fn aggregate_required_modes_holds_for_100_blueprint_batch_and_returns_ordered_set(
    ) {
        // Phase 1 hardening MILESTONE iter-400 — scale + ordering pin
        // for the batch aggregator. Existing tests cover small fixtures
        // (0/1/3 blueprints). This pin scales to 100 blueprints
        // alternating local + cli + local + ... and asserts:
        //
        //   1) The result set has cardinality 2 (both modes appear).
        //   2) BTreeSet ordering: Disabled < IpcBounded < Subprocess.
        //   3) Pure determinism: 3 successive calls produce byte-equal sets.
        //   4) Empty subset / homogeneous subset preserved (50 of each
        //      half produce the same final union).
        //
        // Defends against a future "let me hash-dedup with FxHasher
        // for 'speed'" refactor that would silently break BTreeSet
        // ordering — audit dashboards may rely on the
        // privilege-ascending walk through the result.
        let mut batch = Vec::with_capacity(100);
        for i in 0..100 {
            if i % 2 == 0 {
                batch.push(local_blueprint());
            } else {
                batch.push(cli_blueprint());
            }
        }

        let result1 = AgentBlueprint::aggregate_required_modes(&batch);
        let result2 = AgentBlueprint::aggregate_required_modes(&batch);
        let result3 = AgentBlueprint::aggregate_required_modes(&batch);
        assert_eq!(result1, result2, "determinism");
        assert_eq!(result2, result3, "determinism");

        // Cardinality.
        assert_eq!(result1.len(), 2);

        // Privilege-ascending order via BTreeSet's Ord-driven iter.
        let walk: Vec<AgentRuntimeV2Mode> = result1.iter().copied().collect();
        assert_eq!(
            walk,
            vec![AgentRuntimeV2Mode::IpcBounded, AgentRuntimeV2Mode::Subprocess],
            "BTreeSet must walk privilege-ascending"
        );

        // Disabled NEVER appears regardless of batch size.
        assert!(!result1.contains(&AgentRuntimeV2Mode::Disabled));

        // Two halves (locals-only + clis-only) UNION should equal the
        // alternating-batch result.
        let locals_only: Vec<_> = (0..50).map(|_| local_blueprint()).collect();
        let clis_only: Vec<_> = (0..50).map(|_| cli_blueprint()).collect();
        let half_a = AgentBlueprint::aggregate_required_modes(&locals_only);
        let half_b = AgentBlueprint::aggregate_required_modes(&clis_only);
        let union: std::collections::BTreeSet<_> =
            half_a.union(&half_b).copied().collect();
        assert_eq!(union, result1, "union of halves must equal alternating result");
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
    fn vault_persistence_path_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series). vault_persistence_path
        // does a trim + format; pure over immutable inputs.
        let bp = local_blueprint();
        let r1 = bp.vault_persistence_path("/Users/jojo/vault");
        let r2 = bp.vault_persistence_path("/Users/jojo/vault");
        let r3 = bp.vault_persistence_path("/Users/jojo/vault");
        assert_eq!(r1, r2);
        assert_eq!(r2, r3);
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
    fn vault_persistence_path_interpolates_blueprint_id_verbatim_no_sanitisation() {
        // Phase 1 hardening — DOCTRINE PIN with security teeth.
        // vault_persistence_path uses `format!("{}/agents/{}.json",
        // trimmed, self.id.0)` — the blueprint id is interpolated
        // VERBATIM into the path with no sanitisation. So an id
        // containing slashes, "..", or null bytes produces a path
        // with the same characters. Pin the current (lenient)
        // behaviour so a future "sanitise blueprint ids" refactor
        // surfaces at PR review.
        //
        // The path-traversal-style outputs are NOT a vulnerability
        // at this layer because the runtime doesn't open the file
        // here — callers are responsible for using AgentBlueprintId
        // values that came from a trusted source (vault load, user
        // create flow). But the doctrine should be visible: this
        // function trusts its caller.
        let make = |raw_id: &str| AgentBlueprint {
            id: AgentBlueprintId(raw_id.to_string()),
            display_name: "n".into(),
            provider_policy: ProviderPolicy::LocalMlx { model_id: "m".into() },
            budget: BudgetSpec::default(),
            capability_root_hash: Hash::zero(),
        };
        // Empty id → "vault/agents/.json"
        assert_eq!(make("").vault_persistence_path("vault"), "vault/agents/.json");
        // Slash in id → produces a deeper path
        assert_eq!(
            make("a/b").vault_persistence_path("vault"),
            "vault/agents/a/b.json"
        );
        // ".." in id → path-traversal-style suffix
        assert_eq!(
            make("..").vault_persistence_path("vault"),
            "vault/agents/...json"
        );
        // Null byte in id (unusual but technically a valid String char)
        let with_nul = format!("foo{}bar", '\0');
        let expected = format!("vault/agents/{}.json", with_nul);
        assert_eq!(make(&with_nul).vault_persistence_path("vault"), expected);
        // Whitespace in id passes through verbatim
        assert_eq!(
            make("agent with space").vault_persistence_path("vault"),
            "vault/agents/agent with space.json"
        );
        // Newline in id passes through verbatim
        assert_eq!(
            make("agent\nname").vault_persistence_path("vault"),
            "vault/agents/agent\nname.json"
        );
    }

    #[test]
    fn vault_persistence_path_preserves_unicode_in_vault_root_and_blueprint_id() {
        // Phase 1 hardening — Unicode safety pin for the path
        // construction helper. The function uses `format!` with
        // string slicing only on ASCII chars (the trailing '/'
        // trim); Unicode in vault_root and self.id.0 must survive
        // byte-equal.
        //
        // Companion to iter-93 (id-interpolation verbatim pin) and
        // iter-85 (empty-root pin). A future refactor that switched
        // to Path / PathBuf might re-encode Unicode differently;
        // pin the current byte-preservation.
        let mut bp = local_blueprint();
        bp.id = AgentBlueprintId("研究-α".into());
        // CJK in vault root.
        assert_eq!(
            bp.vault_persistence_path("/Users/jojo/笔记vault"),
            "/Users/jojo/笔记vault/agents/研究-α.json"
        );
        // Emoji in vault root.
        assert_eq!(
            bp.vault_persistence_path("/Users/🚀vault"),
            "/Users/🚀vault/agents/研究-α.json"
        );
        // Trailing slash with Unicode root still trims correctly.
        assert_eq!(
            bp.vault_persistence_path("/Users/jojo/笔记vault/"),
            "/Users/jojo/笔记vault/agents/研究-α.json"
        );
    }

    #[test]
    fn vault_persistence_path_with_empty_blueprint_id_produces_trailing_dot_json() {
        // Phase 1 hardening — boundary completeness companion to
        // vault_persistence_path_with_empty_or_slash_only_root...
        // The OTHER no-content edge — empty blueprint_id — wasn't pinned.
        //
        // Contract: vault_persistence_path is pure format!. With
        // blueprint_id == "", the path becomes "<vault>/agents/.json".
        // This is the function's current behaviour; a future refactor
        // that introduced non-empty validation (e.g., returning a
        // Result, panicking, or substituting a default) would
        // silently change callers that rely on the "" → "/.json" shape.
        //
        // Pin current behaviour so the doctrine call is explicit at
        // PR review when/if it's changed.
        let bp = AgentBlueprint {
            id: AgentBlueprintId(String::new()),
            display_name: "edge-empty-id".to_string(),
            provider_policy: ProviderPolicy::LocalMlx { model_id: "m".into() },
            budget: BudgetSpec::default(),
            capability_root_hash: Hash::zero(),
        };
        assert_eq!(
            bp.vault_persistence_path("/Users/jojo/vault"),
            "/Users/jojo/vault/agents/.json"
        );
        // Trailing-slash root + empty id collapses to the same suffix.
        assert_eq!(
            bp.vault_persistence_path("/Users/jojo/vault/"),
            "/Users/jojo/vault/agents/.json"
        );
        // Empty root + empty id → "/agents/.json".
        assert_eq!(bp.vault_persistence_path(""), "/agents/.json");
    }

    #[test]
    fn vault_persistence_path_with_empty_or_slash_only_root_produces_root_relative_path() {
        // Phase 1 hardening — defensive boundary pin. The existing
        // canonical-shape test covers /Users/jojo/vault and its
        // trailing-slash variants. Two adversarial cases were
        // unpinned:
        //   - vault_root = "" → trimmed = "" → "/agents/<id>.json"
        //   - vault_root = "///" → trimmed = "" → "/agents/<id>.json"
        //
        // Both currently produce a deceptively absolute-looking path
        // ("/agents/<id>.json") even though no vault root was given.
        // This is the function's current contract; a future refactor
        // that introduced non-empty validation (e.g., returning a
        // Result, or panicking on empty input) would silently change
        // callers that rely on the "" → "/agents/..." shape. Pin
        // current behaviour so the doctrine call is explicit at PR
        // review when/if it's changed.
        let bp = local_blueprint();
        assert_eq!(
            bp.vault_persistence_path(""),
            "/agents/research-assistant.json",
            "empty vault_root currently produces a root-relative path"
        );
        assert_eq!(
            bp.vault_persistence_path("/"),
            "/agents/research-assistant.json"
        );
        assert_eq!(
            bp.vault_persistence_path("///"),
            "/agents/research-assistant.json"
        );
        // Single character + slash also exercises the boundary.
        assert_eq!(
            bp.vault_persistence_path("/"),
            "/agents/research-assistant.json"
        );
    }

    #[test]
    fn is_subprocess_provider_returns_true_for_all_six_cli_adapter_variants() {
        // Phase 1 hardening — exhaustiveness pin (companion to
        // is_subprocess_provider_matches_only_pro_cli). The helper
        // matches `ProviderPolicy::ProCli { .. }` regardless of which
        // CliAdapter variant the ProCli carries; all 6 adapters
        // must produce true.
        //
        // A future refactor that special-cased one adapter (e.g.,
        // "claude_code is now in-process") without updating the
        // helper would silently break tier-gate dispatch.
        for adapter in [
            CliAdapter::ClaudeCode,
            CliAdapter::Codex,
            CliAdapter::Goose,
            CliAdapter::Aider,
            CliAdapter::OpenHands,
            CliAdapter::SweAgent,
        ] {
            let bp = AgentBlueprint {
                id: AgentBlueprintId("p".into()),
                display_name: "p".into(),
                provider_policy: ProviderPolicy::ProCli {
                    adapter,
                    command: "c".into(),
                },
                budget: BudgetSpec::default(),
                capability_root_hash: Hash::zero(),
            };
            assert!(
                bp.is_subprocess_provider(),
                "adapter {adapter:?} must mark blueprint as subprocess-required"
            );
        }
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
    fn provider_policy_multi_field_variants_preserve_field_declaration_order() {
        // Phase 1 hardening — wire-shape pin extending iter-151
        // (per-variant field names) with field-ORDER for the
        // ProviderPolicy variants carrying multiple data fields:
        //   OpenAICompatible { base_url, model }
        //   ProCli { adapter, command }
        // The other 4 variants (LocalMlx, AnthropicMessages,
        // OpenAIResponses, Mcp) have at most 1 field — no order
        // concern.
        let oai_compat = ProviderPolicy::OpenAICompatible {
            base_url: "http://localhost".into(),
            model: "llama".into(),
        };
        let s = serde_json::to_string(&oai_compat).expect("serialise");
        assert!(
            s.find("\"base_url\":").unwrap() < s.find("\"model\":").unwrap(),
            "OpenAICompatible.base_url must appear before .model in {s}"
        );

        let pro_cli = ProviderPolicy::ProCli {
            adapter: CliAdapter::ClaudeCode,
            command: "/bin/claude".into(),
        };
        let s = serde_json::to_string(&pro_cli).expect("serialise");
        assert!(
            s.find("\"adapter\":").unwrap() < s.find("\"command\":").unwrap(),
            "ProCli.adapter must appear before .command in {s}"
        );
    }

    #[test]
    fn provider_policy_serde_per_variant_field_names_pinned_exactly() {
        // Phase 1 hardening — wire-shape pin extending
        // provider_policy_serde_kind_discriminator (which only pins
        // the "kind" tag value, not the rest of the payload). Each
        // variant has its own data fields whose JSON names must
        // stay stable for vault-file readability across versions.
        //
        // The existing round-trip tests would pass even if a maintainer
        // renamed `model_id` to `model` everywhere — the round-trip
        // is internally consistent. But a Swift bridge reader or a
        // CLI debug tool that parses the JSON by field name would
        // break silently.
        //
        // Pin every variant's expected field names by checking the
        // JSON contains exact "field":"value" substrings.
        let cases = [
            (
                ProviderPolicy::LocalMlx { model_id: "qwen".into() },
                vec!["\"model_id\":\"qwen\""],
            ),
            (
                ProviderPolicy::AnthropicMessages { model: "claude-sonnet".into() },
                vec!["\"model\":\"claude-sonnet\""],
            ),
            (
                ProviderPolicy::OpenAIResponses { model: "gpt-5".into() },
                vec!["\"model\":\"gpt-5\""],
            ),
            (
                ProviderPolicy::OpenAICompatible {
                    base_url: "http://localhost".into(),
                    model: "llama".into(),
                },
                vec![
                    "\"base_url\":\"http://localhost\"",
                    "\"model\":\"llama\"",
                ],
            ),
            (
                ProviderPolicy::Mcp { server_id: "vault-mcp".into() },
                vec!["\"server_id\":\"vault-mcp\""],
            ),
            (
                ProviderPolicy::ProCli {
                    adapter: CliAdapter::ClaudeCode,
                    command: "/bin/claude".into(),
                },
                vec!["\"adapter\":", "\"command\":\"/bin/claude\""],
            ),
        ];
        for (variant, needles) in cases {
            let s = serde_json::to_string(&variant).expect("serialise");
            for needle in needles {
                assert!(
                    s.contains(needle),
                    "variant {variant:?} serialisation missing {needle:?} — \
                     got {s}"
                );
            }
        }
    }

    #[test]
    fn provider_policy_variants_field_shapes_pinned_via_destructure() {
        // Phase 1 hardening — field-shape pin for ProviderPolicy's 6
        // variants (companion to the destructure pin family iter-454..
        // iter-462). ProviderPolicy is the canonical agent executor
        // choice; field changes here fork every persisted
        // AgentBlueprint JSON.
        //
        // Per-variant field shapes:
        //   - LocalMlx { model_id: String }                              → 1 named
        //   - AnthropicMessages { model: String }                        → 1 named
        //   - OpenAIResponses { model: String }                          → 1 named
        //   - OpenAICompatible { base_url: String, model: String }       → 2 named
        //   - Mcp { server_id: String }                                  → 1 named
        //   - ProCli { adapter: CliAdapter, command: String }            → 2 named
        let p = ProviderPolicy::LocalMlx { model_id: "m".into() };
        match p {
            ProviderPolicy::LocalMlx { model_id } => { let _: String = model_id; }
            _ => unreachable!(),
        }
        let p = ProviderPolicy::AnthropicMessages { model: "m".into() };
        match p {
            ProviderPolicy::AnthropicMessages { model } => { let _: String = model; }
            _ => unreachable!(),
        }
        let p = ProviderPolicy::OpenAIResponses { model: "m".into() };
        match p {
            ProviderPolicy::OpenAIResponses { model } => { let _: String = model; }
            _ => unreachable!(),
        }
        let p = ProviderPolicy::OpenAICompatible {
            base_url: "u".into(),
            model: "m".into(),
        };
        match p {
            ProviderPolicy::OpenAICompatible { base_url, model } => {
                let _: String = base_url;
                let _: String = model;
            }
            _ => unreachable!(),
        }
        let p = ProviderPolicy::Mcp { server_id: "s".into() };
        match p {
            ProviderPolicy::Mcp { server_id } => { let _: String = server_id; }
            _ => unreachable!(),
        }
        let p = ProviderPolicy::ProCli {
            adapter: CliAdapter::ClaudeCode,
            command: "c".into(),
        };
        match p {
            ProviderPolicy::ProCli { adapter, command } => {
                let _: CliAdapter = adapter;
                let _: String = command;
            }
            _ => unreachable!(),
        }
    }

    #[test]
    fn provider_policy_variant_count_is_six() {
        // Phase 1 hardening — cardinality pin completing the
        // count-pin series across every closed-taxonomy enum
        // (BudgetTerm 5, AgentEventErrorKind 4, AgentRuntimeV2Mode
        // 3, CliAdapter 6, VariantTier 3, ProviderPolicy 6 here).
        // ProviderPolicy has 6 variants (LocalMlx, AnthropicMessages,
        // OpenAIResponses, OpenAICompatible, Mcp, ProCli) —
        // every supported executor adapter family.
        //
        // ProviderPolicy is unusual: its variants carry data, so
        // pairwise-distinctness against a single fixture matters
        // less than the cardinality assertion + per-variant
        // discriminant check. A future addition (e.g., a 7th
        // family for HuggingFaceInference or LocalGGUF) requires:
        //   - check_against_mode update (MAS / Pro / Research gate)
        //   - is_subprocess_provider update if applicable
        //   - serde kind discriminator + negative-serde pin updates
        //   - vault file migration path
        let variants = [
            ProviderPolicy::LocalMlx { model_id: "m".into() },
            ProviderPolicy::AnthropicMessages { model: "c".into() },
            ProviderPolicy::OpenAIResponses { model: "g".into() },
            ProviderPolicy::OpenAICompatible {
                base_url: "u".into(),
                model: "m".into(),
            },
            ProviderPolicy::Mcp { server_id: "s".into() },
            ProviderPolicy::ProCli {
                adapter: CliAdapter::ClaudeCode,
                command: "c".into(),
            },
        ];
        assert_eq!(variants.len(), 6);
        // Pairwise distinctness — each variant is structurally
        // different from the others (different discriminants).
        for i in 0..variants.len() {
            for j in (i + 1)..variants.len() {
                assert_ne!(
                    variants[i], variants[j],
                    "policies[{i}] and policies[{j}] must be structurally distinct"
                );
            }
        }
    }

    #[test]
    fn provider_policy_serde_kind_discriminator_pins_snake_case_for_all_six_variants() {
        // Phase 1 hardening — cross-version replay parity guardrail.
        // ProviderPolicy serialises with `tag = "kind"` + snake_case;
        // every variant string is load-bearing for replay of older
        // AgentBlueprint JSONs. A rename here silently breaks replay.
        // Pin all six variant kind strings to their snake_case form.
        let cases = [
            (
                ProviderPolicy::LocalMlx { model_id: "m".into() },
                "local_mlx",
            ),
            (
                ProviderPolicy::AnthropicMessages { model: "c".into() },
                "anthropic_messages",
            ),
            (
                ProviderPolicy::OpenAIResponses { model: "g".into() },
                "open_a_i_responses",
            ),
            (
                ProviderPolicy::OpenAICompatible {
                    base_url: "u".into(),
                    model: "m".into(),
                },
                "open_a_i_compatible",
            ),
            (ProviderPolicy::Mcp { server_id: "s".into() }, "mcp"),
            (
                ProviderPolicy::ProCli {
                    adapter: CliAdapter::ClaudeCode,
                    command: "c".into(),
                },
                "pro_cli",
            ),
        ];
        for (variant, expected_kind) in cases {
            let s = serde_json::to_string(&variant).expect("serialise");
            // The kind field must contain the expected string. Use
            // substring rather than full JSON pin because the
            // payload field ordering may shift.
            let needle = format!("\"kind\":\"{expected_kind}\"");
            assert!(
                s.contains(&needle),
                "expected {needle} in {s}"
            );
            // And round-trip must preserve the variant.
            let back: ProviderPolicy = serde_json::from_str(&s).expect("deserialise");
            assert_eq!(back, variant);
        }
    }

    #[test]
    fn provider_policy_unknown_kind_tag_fails_to_deserialise() {
        // Phase 1 hardening — eighth and final leg of the closed-
        // taxonomy guardrail series (mode iter-71, AgentEvent
        // event_type iter-73, StopReason iter-74, AgentEventErrorKind
        // iter-75, VariantTier iter-78, CliAdapter iter-80,
        // RunEventEntry kind iter-81). ProviderPolicy is persisted
        // inside vault/agents/<id>.json blueprint files; the `kind`
        // discriminator routes to one of 6 executor adapter families.
        // A stray kind string in a tampered or cross-version blueprint
        // must fail to deserialise — not silently route to a default
        // family (which would silently dispatch to the wrong
        // provider).
        //
        // The 6 valid kinds, locked by iter-49's positive pin, are:
        // local_mlx, anthropic_messages, open_a_i_responses,
        // open_a_i_compatible, mcp, pro_cli. (The "open_a_i_*"
        // form is serde's default snake_case conversion of PascalCase
        // "OpenAI*" — preserved verbatim here as part of the
        // closed-taxonomy contract.)
        for bad in [
            // Unknown adapter vocab
            r#"{"kind":"google_gemini","model":"g"}"#,
            r#"{"kind":"local_llama","model_id":"l"}"#,
            r#"{"kind":"groq","model":"x"}"#,
            // Case variants of valid kinds
            r#"{"kind":"LocalMlx","model_id":"m"}"#,
            r#"{"kind":"Local_Mlx","model_id":"m"}"#,
            r#"{"kind":"localMlx","model_id":"m"}"#,
            r#"{"kind":"PRO_CLI","adapter":"codex","command":"c"}"#,
            // Adjacent canonical-looking spellings (NOT matching the
            // serde-default snake_case form — these are the kind of
            // strings a maintainer might "helpfully" introduce).
            r#"{"kind":"openai_responses","model":"g"}"#,
            r#"{"kind":"openai_compatible","base_url":"u","model":"m"}"#,
            r#"{"kind":"open_ai_responses","model":"g"}"#,
            // Kebab-case drift
            r#"{"kind":"local-mlx","model_id":"m"}"#,
            r#"{"kind":"anthropic-messages","model":"c"}"#,
            r#"{"kind":"pro-cli","adapter":"codex","command":"c"}"#,
            // Missing kind entirely
            r#"{"model":"x"}"#,
        ] {
            let r: Result<ProviderPolicy, _> = serde_json::from_str(bad);
            assert!(
                r.is_err(),
                "unknown ProviderPolicy kind in {bad} must fail to deserialise"
            );
        }
        // Positive sanity: every valid variant still round-trips.
        for (variant, expected_kind) in [
            (ProviderPolicy::LocalMlx { model_id: "qwen".into() }, "local_mlx"),
            (
                ProviderPolicy::AnthropicMessages { model: "claude-sonnet".into() },
                "anthropic_messages",
            ),
            (
                ProviderPolicy::OpenAIResponses { model: "gpt".into() },
                "open_a_i_responses",
            ),
            (
                ProviderPolicy::OpenAICompatible {
                    base_url: "u".into(),
                    model: "m".into(),
                },
                "open_a_i_compatible",
            ),
            (ProviderPolicy::Mcp { server_id: "s".into() }, "mcp"),
            (
                ProviderPolicy::ProCli {
                    adapter: CliAdapter::ClaudeCode,
                    command: "c".into(),
                },
                "pro_cli",
            ),
        ] {
            let s = serde_json::to_string(&variant).unwrap();
            assert!(
                s.contains(&format!("\"kind\":\"{expected_kind}\"")),
                "variant {variant:?} drifted kind tag — got {s}"
            );
            let back: ProviderPolicy = serde_json::from_str(&s).unwrap();
            assert_eq!(back, variant);
        }
    }

    #[test]
    fn cli_adapter_variant_count_is_six() {
        // Phase 1 hardening — cardinality pin continuing the
        // count-pin series (BudgetTerm 5, AgentEventErrorKind 4
        // iter-139, AgentRuntimeV2Mode 3 iter-140). CliAdapter has
        // 6 variants (ClaudeCode, Codex, Goose, Aider, OpenHands,
        // SweAgent) — every supported Pro Research subprocess
        // CLI. A future addition (e.g., a 7th adapter for a new
        // CLI like Continue, Cursor, or Warp) requires:
        //   - per-variant security::harden_cli_subprocess vetting
        //   - serde snake_case discriminator pin update
        //   - negative-serde unknown-string pin update
        // Pin the cardinality + pairwise distinctness so the
        // addition surfaces at PR review with deliberate updates
        // across all three sites.
        let variants = [
            CliAdapter::ClaudeCode,
            CliAdapter::Codex,
            CliAdapter::Goose,
            CliAdapter::Aider,
            CliAdapter::OpenHands,
            CliAdapter::SweAgent,
        ];
        assert_eq!(variants.len(), 6);
        // Pairwise distinctness.
        for i in 0..variants.len() {
            for j in (i + 1)..variants.len() {
                assert_ne!(
                    variants[i], variants[j],
                    "adapters[{i}] and adapters[{j}] must be distinct"
                );
            }
        }
    }

    #[test]
    fn cli_adapter_serde_snake_case_pins_all_six_adapter_strings() {
        // Phase 1 hardening — CliAdapter is a leaf enum embedded in
        // ProviderPolicy::ProCli. The snake_case JSON form is load-
        // bearing for replay of older blueprints + run logs that
        // captured the adapter choice.
        let cases = [
            (CliAdapter::ClaudeCode, "\"claude_code\""),
            (CliAdapter::Codex, "\"codex\""),
            (CliAdapter::Goose, "\"goose\""),
            (CliAdapter::Aider, "\"aider\""),
            (CliAdapter::OpenHands, "\"open_hands\""),
            (CliAdapter::SweAgent, "\"swe_agent\""),
        ];
        for (variant, expected_json) in cases {
            assert_eq!(serde_json::to_string(&variant).unwrap(), expected_json);
            let back: CliAdapter = serde_json::from_str(expected_json).unwrap();
            assert_eq!(back, variant);
        }
    }

    #[test]
    fn blueprint_id_display_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series). AgentBlueprintId
        // Display delegates to inner String write; pure.
        let id = AgentBlueprintId("research-assistant".into());
        let s1 = format!("{id}");
        let s2 = format!("{id}");
        let s3 = format!("{id}");
        assert_eq!(s1, s2);
        assert_eq!(s2, s3);
    }

    #[test]
    fn blueprint_id_display_writes_special_chars_verbatim_no_escaping() {
        // Phase 1 hardening — Display vs serde behaviour pin
        // (companion to mission_packet iter-424, answer_packet iter-425,
        // citation::as_display_string iter-426 Display-verbatim pins).
        //
        // AgentBlueprintId::Display writes the inner String verbatim
        // via f.write_str — no escaping, no quoting, no normalisation.
        // The bare quoted/backslash/newline content surfaces RAW in
        // log lines.
        //
        // A future "let me JSON-escape the Display output for log
        // safety" refactor would silently change the AgentBlueprintId
        // appearance everywhere it surfaces through Display (which
        // includes MissionPacket Display + AnswerPacket Display).
        let cases = [
            r#"agent "with quotes""#,
            "agent\\with\\backslashes",
            "agent\nwith\nnewlines",
            "agent\twith\ttabs",
            r#"Bob's "Research" Agent"#,
        ];
        for raw in cases {
            let id = AgentBlueprintId(raw.to_string());
            let display = format!("{id}");
            assert_eq!(display, raw, "blueprint id Display must write inner string verbatim");
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
    fn blueprint_id_serialises_transparently_as_raw_string_not_wrapped_object() {
        // Phase 1 hardening — pin the #[serde(transparent)] doctrine
        // on AgentBlueprintId. The transparent attribute makes the
        // newtype serialize as the inner String directly (`"my-id"`),
        // NOT as a wrapped object (`{"0":"my-id"}`). Every vault
        // file at vault/agents/<id>.json depends on this shape AND
        // every AgentBlueprint JSON embedding includes the id field
        // as a bare string (see provider_policy_serde_kind tests).
        //
        // A future refactor that removed `#[serde(transparent)]`
        // (e.g., "let me derive serde directly to expose the tuple
        // struct shape") would silently flip the JSON form to
        // `{"0":"my-id"}` and break every persisted blueprint file
        // in the field. Pin the bare-string shape.
        let id = AgentBlueprintId("research-assistant".to_string());
        let s = serde_json::to_string(&id).expect("serialise");
        assert_eq!(
            s, "\"research-assistant\"",
            "AgentBlueprintId must serialise as a bare JSON string (transparent newtype)"
        );
        // It MUST NOT serialise as a wrapped object.
        assert!(
            !s.contains("{") && !s.contains("}") && !s.contains("\"0\""),
            "serialised form must not include wrapper-object braces or tuple index"
        );
        // Inversely: parsing a bare string deserialises into the id.
        let back: AgentBlueprintId =
            serde_json::from_str("\"research-assistant\"").expect("deserialise bare string");
        assert_eq!(back, id);
        // The wrapped-object form must FAIL to deserialise — pins
        // that nobody can rely on the "fallback" shape.
        let wrapped_err: Result<AgentBlueprintId, _> =
            serde_json::from_str(r#"{"0":"research-assistant"}"#);
        assert!(
            wrapped_err.is_err(),
            "wrapped-object form must NOT deserialise — transparent attribute is load-bearing"
        );
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
    fn agent_blueprint_id_newtype_field_shape_pinned_via_destructure() {
        // Phase 1 hardening — newtype field-shape pin for
        // AgentBlueprintId (companion to the struct destructure pin
        // family iter-464..iter-470). AgentBlueprintId is a
        // 1-tuple-field newtype wrapping String:
        //
        //   pub struct AgentBlueprintId(pub String);
        //
        // A future "let me add a hash field for cache lookups"
        // refactor that changed it to {String, [u8; 32]} would
        // silently break the #[serde(transparent)] doctrine + every
        // call site that uses `bid.0` to access the inner string.
        let bid = AgentBlueprintId("research-assistant".to_string());
        let AgentBlueprintId(inner) = bid;
        let _: String = inner;
    }

    #[test]
    fn agent_blueprint_struct_field_shape_pinned_to_exactly_five_typed_fields() {
        // Phase 1 hardening — struct-field-shape pin for AgentBlueprint
        // (companion to AnswerPacket struct destructure iter-464).
        // AgentBlueprint carries EXACTLY 5 named fields with specific
        // types:
        //
        //   - id: AgentBlueprintId
        //   - display_name: String
        //   - provider_policy: ProviderPolicy
        //   - budget: BudgetSpec
        //   - capability_root_hash: Hash
        //
        // A future "let me add a `created_at` timestamp field" would
        // silently change the vault/agents/<id>.json shape — surface
        // here via destructure compile-fail + per-field type assertions.
        let bp = local_blueprint();
        let AgentBlueprint {
            id,
            display_name,
            provider_policy,
            budget,
            capability_root_hash,
        } = bp;
        let _: AgentBlueprintId = id;
        let _: String = display_name;
        let _: ProviderPolicy = provider_policy;
        let _: BudgetSpec = budget;
        let _: Hash = capability_root_hash;
    }

    #[test]
    fn every_blueprint_field_is_identity_load_bearing() {
        // Phase 1 hardening — companion to changing_capability_root_hash.
        // That test proves capability_root_hash diff breaks equality.
        // This proves the OTHER four fields (id, display_name,
        // provider_policy, budget) are also identity-load-bearing
        // — a silent #[serde(skip)] or PartialEq override that
        // dropped any field would silently let two distinct
        // blueprints compare equal.
        let base = local_blueprint();

        // id
        let mut diff_id = base.clone();
        diff_id.id = AgentBlueprintId("not-the-same".into());
        assert_ne!(base, diff_id, "id must be identity-load-bearing");

        // display_name
        let mut diff_name = base.clone();
        diff_name.display_name = "different name".into();
        assert_ne!(base, diff_name, "display_name must be identity-load-bearing");

        // provider_policy
        let mut diff_provider = base.clone();
        diff_provider.provider_policy = ProviderPolicy::AnthropicMessages {
            model: "claude-sonnet-4-6".into(),
        };
        assert_ne!(base, diff_provider, "provider_policy must be identity-load-bearing");

        // budget
        let mut diff_budget = base.clone();
        diff_budget.budget = BudgetSpec::new(99_999, 0, 0, 0);
        assert_ne!(base, diff_budget, "budget must be identity-load-bearing");
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
    fn blueprint_id_hash_is_consistent_with_equality_for_dedup_cache() {
        // Phase 1 hardening — Hash + Eq derive must satisfy the
        // collections-as-key invariant: two equal AgentBlueprintIds
        // hash to the same key. Without this, HashMap dedup-cache
        // lookups would silently miss. Verify via HashMap with one
        // ID and lookup with an independently-constructed-but-equal
        // ID.
        use std::collections::HashMap;
        let a = AgentBlueprintId("research-assistant".to_string());
        let a_twin = AgentBlueprintId("research-assistant".to_string());
        // Equal but distinct allocations.
        assert_eq!(a, a_twin);
        let mut m = HashMap::new();
        m.insert(a, 99);
        assert_eq!(
            m.get(&a_twin),
            Some(&99),
            "lookup with equal-but-distinct-allocation ID must hit",
        );
    }

    #[test]
    fn blueprint_clone_preserves_every_field_byte_for_byte() {
        // Phase 1 hardening — Clone derivation MUST preserve every
        // field including the nested ProviderPolicy variant payload
        // and the BudgetSpec's 5 axes. A future hand-rolled Clone
        // that forgot to copy capability_root_hash (or set provider
        // to a default ProCli) would silently produce a "clone"
        // that fails dedup-cache equality. Pin every field.
        let original = cli_blueprint(); // ProCli variant with adapter + command
        let cloned = original.clone();
        assert_eq!(cloned, original);
        assert_eq!(cloned.id, original.id);
        assert_eq!(cloned.display_name, original.display_name);
        assert_eq!(cloned.provider_policy, original.provider_policy);
        assert_eq!(cloned.budget, original.budget);
        assert_eq!(cloned.capability_root_hash, original.capability_root_hash);
        // Independence: mutating clone does not affect original.
        let mut mut_clone = cloned;
        mut_clone.display_name = "diverged".into();
        assert_ne!(mut_clone.display_name, original.display_name);
        assert_eq!(original.display_name, cli_blueprint().display_name);
    }

    #[test]
    fn blueprint_id_preserves_json_special_chars_through_serde() {
        // Phase 1 hardening — adversarial JSON pin for AgentBlueprintId
        // (companion to the iter-413..iter-418 JSON-special-char pin
        // family). AgentBlueprintId is a #[serde(transparent)] String
        // newtype that surfaces inside vault/agents/<id>.json paths.
        //
        // While the doctrine pin says "verbatim, no sanitisation"
        // (iter-?), the JSON-special-char path-through requires
        // serde to escape correctly at the wire layer. Pin both the
        // inner String round-trip AND the transparent newtype
        // serialise as a bare quoted string.
        let adversarial = [
            r#"id "with quotes""#,
            "id\\with\\backslashes",
            "id\nwith\nnewlines",
            r#"agent-id with "embedded" json"#,
        ];
        for id in adversarial {
            let bid = AgentBlueprintId(id.to_string());
            let s = serde_json::to_string(&bid).expect("serialise");
            let back: AgentBlueprintId =
                serde_json::from_str(&s).expect("deserialise");
            assert_eq!(back.0, id, "blueprint_id inner string must round-trip");
            assert_eq!(back, bid);
        }
    }

    #[test]
    fn blueprint_display_name_preserves_json_special_chars_through_serde() {
        // Phase 1 hardening — adversarial JSON pin for
        // AgentBlueprint.display_name (companion to mission_packet
        // iter-413, answer_packet iter-414, citation iter-415,
        // mutation_envelope iter-416, tool_call iter-417).
        //
        // display_name is a free-form String for UI labels — may carry
        // quotes (`Bob's Agent`), backslashes (Windows paths in a name),
        // or even multi-line names. Serde must escape these through
        // round-trip without lossy sanitisation.
        let adversarial = [
            r#"agent "with quotes""#,
            "agent\\with\\backslashes",
            "agent\nwith\nnewlines",
            "agent\twith\ttabs",
            r#"Bob's "Research" Agent"#,
        ];
        for name in adversarial {
            let bp = AgentBlueprint {
                id: AgentBlueprintId("json-edge".into()),
                display_name: name.to_string(),
                provider_policy: ProviderPolicy::LocalMlx { model_id: "m".into() },
                budget: BudgetSpec::default(),
                capability_root_hash: Hash::zero(),
            };
            let s = serde_json::to_string(&bp).expect("serialise");
            let back: AgentBlueprint =
                serde_json::from_str(&s).expect("deserialise");
            assert_eq!(back.display_name, name, "display_name must round-trip byte-equal");
            assert_eq!(back, bp);
        }
    }

    #[test]
    fn blueprint_display_name_preserves_unicode_through_serde() {
        // Phase 1 hardening — display_name is a free-form String
        // shown to the user; localized agent names contain emoji,
        // CJK, accented Latin, etc. Pin that serde JSON preserves
        // these multi-byte sequences byte-for-byte (no \u escaping
        // that breaks comparison; serde_json uses raw UTF-8 by
        // default for non-control characters).
        let mut bp = local_blueprint();
        bp.display_name = "🚀 研究助手 — alpha v1.0".into();
        let s = serde_json::to_string(&bp).expect("serialise");
        let back: AgentBlueprint = serde_json::from_str(&s).expect("deserialise");
        assert_eq!(back.display_name, bp.display_name);
        assert_eq!(back, bp);
        // The JSON form itself must contain the literal multi-byte
        // characters (serde_json default behaviour for any non-ASCII
        // > 0x1F that isn't a control char).
        assert!(s.contains("🚀"));
        assert!(s.contains("研究助手"));
    }

    #[test]
    fn cli_adapter_unknown_serde_string_fails_to_deserialise() {
        // Phase 1 hardening — sixth leg of the closed-taxonomy
        // guardrail (mode iter-71, AgentEvent event_type iter-73,
        // StopReason iter-74, AgentEventErrorKind iter-75, VariantTier
        // iter-78). CliAdapter is persisted inside ProviderPolicy::ProCli
        // payloads in vault/agents/<id>.json blueprint files. A future
        // #[serde(other)] catch-all or case-insensitive shim could
        // silently route an unknown adapter string to one of the
        // 6 hardened subprocess binaries — high-blast-radius for
        // a Pro tier that spawns child processes.
        for bad in [
            // Unknown adapter vocabulary
            "\"continue\"",
            "\"cursor\"",
            "\"warp\"",
            "\"smith\"",
            // Case variants of valid strings
            "\"ClaudeCode\"",
            "\"CLAUDE_CODE\"",
            "\"claudeCode\"",
            "\"SweAgent\"",
            "\"sweagent\"",
            // Kebab-case drift
            "\"claude-code\"",
            "\"open-hands\"",
            "\"swe-agent\"",
            // Empty
            "\"\"",
        ] {
            let r: Result<CliAdapter, _> = serde_json::from_str(bad);
            assert!(
                r.is_err(),
                "unknown CliAdapter string {bad} must fail to deserialise"
            );
        }
        // Sanity: every valid adapter still round-trips byte-equal.
        for (variant, expected) in [
            (CliAdapter::ClaudeCode, "\"claude_code\""),
            (CliAdapter::Codex, "\"codex\""),
            (CliAdapter::Goose, "\"goose\""),
            (CliAdapter::Aider, "\"aider\""),
            (CliAdapter::OpenHands, "\"open_hands\""),
            (CliAdapter::SweAgent, "\"swe_agent\""),
        ] {
            let s = serde_json::to_string(&variant).unwrap();
            assert_eq!(s, expected, "adapter {variant:?} drifted serde form");
            let back: CliAdapter = serde_json::from_str(&s).unwrap();
            assert_eq!(back, variant);
        }
    }

    #[test]
    fn blueprint_round_trips_through_json() {
        let bp = cli_blueprint();
        let s = serde_json::to_string(&bp).expect("serialize");
        let back: AgentBlueprint = serde_json::from_str(&s).expect("deserialize");
        assert_eq!(back, bp);
    }

    #[test]
    fn blueprint_round_trips_through_json_for_all_six_provider_policy_variants() {
        // Phase 1 hardening — completeness companion to
        // blueprint_round_trips_through_json (which exercises ONLY
        // the ProCli variant). The closed-taxonomy ProviderPolicy has
        // 6 variants; the JSON round-trip contract MUST hold for every
        // one of them — otherwise a vault file written under one
        // variant could fail to read back.
        //
        // Defends against a regression where a per-variant
        // #[serde(rename)] drift breaks deserialisation for a single
        // variant (e.g., OpenAICompatible's optional headers field).
        let variants = [
            ("LocalMlx", ProviderPolicy::LocalMlx { model_id: "qwen3.5-8b".into() }),
            (
                "AnthropicMessages",
                ProviderPolicy::AnthropicMessages { model: "claude-sonnet-4-6".into() },
            ),
            (
                "OpenAIResponses",
                ProviderPolicy::OpenAIResponses { model: "gpt-5".into() },
            ),
            (
                "OpenAICompatible",
                ProviderPolicy::OpenAICompatible {
                    base_url: "https://example.invalid/v1".into(),
                    model: "any".into(),
                },
            ),
            ("Mcp", ProviderPolicy::Mcp { server_id: "mcp-vault".into() }),
            (
                "ProCli",
                ProviderPolicy::ProCli {
                    adapter: CliAdapter::ClaudeCode,
                    command: "/opt/claude".into(),
                },
            ),
        ];

        for (tag, policy) in variants {
            let bp = AgentBlueprint {
                id: AgentBlueprintId(format!("rt-{}", tag.to_lowercase())),
                display_name: format!("rt-{tag}"),
                provider_policy: policy,
                budget: BudgetSpec::new(1_000, 60_000, 5, 0),
                capability_root_hash: Hash::zero(),
            };
            let s = serde_json::to_string(&bp).unwrap_or_else(|e| {
                panic!("variant {tag}: serialise failed: {e}")
            });
            let back: AgentBlueprint = serde_json::from_str(&s).unwrap_or_else(|e| {
                panic!("variant {tag}: deserialise failed: {e}, json = {s}")
            });
            assert_eq!(back, bp, "variant {tag} must round-trip byte-equal");
        }
    }

    #[test]
    fn blueprint_serde_tolerates_unknown_extra_fields_per_current_doctrine() {
        // Phase 1 hardening — DOCTRINE PIN with forward-compat teeth.
        // serde_json's DEFAULT behaviour is to IGNORE unknown fields
        // during deserialise. AgentBlueprint does NOT carry
        // #[serde(deny_unknown_fields)], so an older blueprint
        // file containing extra fields a future maintainer added
        // and then reverted (or that a different consumer wrote)
        // still deserialises successfully — the extras are silently
        // dropped.
        //
        // This forward-compat property is load-bearing for vault
        // file migrations: a Pro-Research field that gets added
        // in v3 must still let MAS V1 read the same blueprint file
        // without erroring. Pin the lenient behaviour so a future
        // #[serde(deny_unknown_fields)] addition surfaces at PR
        // review as a deliberate doctrine change.
        let bp = local_blueprint();
        let s = serde_json::to_string(&bp).expect("serialise");
        // Manually inject a stray field into the JSON.
        let augmented = s
            .trim_end_matches('}')
            .to_string()
            + r#","future_research_field":"some-experimental-value"}"#;
        let parsed: AgentBlueprint =
            serde_json::from_str(&augmented).expect("unknown field tolerated");
        // The dropped field doesn't affect equality.
        assert_eq!(parsed, bp);
        // Also exercise an unknown field at a NESTED position
        // (inside provider_policy). Same forward-compat contract.
        let nested_augmented = serde_json::to_string(&bp)
            .unwrap()
            .replace(
                "\"local_mlx\"",
                "\"local_mlx\",\"future_tuning_knob\":\"x\"",
            );
        let parsed_nested: AgentBlueprint =
            serde_json::from_str(&nested_augmented).expect("nested unknown field tolerated");
        assert_eq!(parsed_nested, bp);
    }

    #[test]
    fn blueprint_serde_json_preserves_struct_field_declaration_order() {
        // Phase 1 hardening — wire-shape pin. serde_json::to_string
        // preserves struct field DECLARATION ORDER. AgentBlueprint
        // declares its 5 fields as:
        //   id, display_name, provider_policy, budget,
        //   capability_root_hash
        //
        // A future field reorder (e.g., moving capability_root_hash
        // up after id for grouping) would produce a different byte
        // form on the wire. While semantically equivalent, byte-
        // equal cross-version cache keys + byte-level diff tools
        // depend on the order. Pin it.
        //
        // Field-name containment is already pinned by
        // blueprint_serde_json_contains_all_five_canonical_top_level_keys;
        // this adds the order constraint.
        let bp = local_blueprint();
        let s = serde_json::to_string(&bp).expect("serialise");
        let expected_keys_in_order = [
            "\"id\":",
            "\"display_name\":",
            "\"provider_policy\":",
            "\"budget\":",
            "\"capability_root_hash\":",
        ];
        let mut last_idx: Option<usize> = None;
        for key in expected_keys_in_order {
            let pos = s.find(key).unwrap_or_else(|| panic!("key {key} not found in {s}"));
            if let Some(prev) = last_idx {
                assert!(
                    pos > prev,
                    "field {key} at byte {pos} must appear after previous field at {prev} in {s}"
                );
            }
            last_idx = Some(pos);
        }
    }

    #[test]
    fn blueprint_serde_json_contains_all_five_canonical_top_level_keys() {
        // Phase 1 hardening — on-wire shape pin. AgentBlueprint
        // persists at vault/agents/<id>.json; any reader (Swift
        // bridge, CLI debug tool, migration script) relies on a
        // stable top-level key set. Pin every key so a future
        // #[serde(rename)] or field reshuffle surfaces here at PR
        // review rather than breaking on-disk reads silently.
        let bp = local_blueprint();
        let json = serde_json::to_value(&bp).expect("serialize");
        let obj = json.as_object().expect("blueprint serialises as JSON object");
        for key in ["id", "display_name", "provider_policy", "budget", "capability_root_hash"] {
            assert!(
                obj.contains_key(key),
                "missing top-level key {key:?} in {json:?}",
            );
        }
        // Exactly 5 keys — pins that no field was silently added
        // without doctrine update.
        assert_eq!(
            obj.len(),
            5,
            "expected exactly 5 top-level keys, got {} ({:?})",
            obj.len(),
            obj.keys().collect::<Vec<_>>()
        );
    }
}
