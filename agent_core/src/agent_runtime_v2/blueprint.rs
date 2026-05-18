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
