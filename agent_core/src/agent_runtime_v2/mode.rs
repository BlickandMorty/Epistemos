//! `AgentRuntimeV2Mode` — the tier gate for the v2 executor.

use serde::{Deserialize, Serialize};

/// Tier gate for Agent Runtime v2 / System G.
///
/// The mode is the single source of truth for which v2 paths are alive in a
/// given build. Mode selection is **build-time only** for the MAS bundle:
/// MAS must always observe `Disabled`. Pro builds choose between
/// `IpcBounded` (default) and `Subprocess` (Research only).
///
/// Locked semantics:
///
/// | Mode          | Tier            | Bounded executor | Subprocess CLI |
/// |---------------|-----------------|------------------|----------------|
/// | `Disabled`    | MAS V1          | no               | no             |
/// | `IpcBounded`  | Pro V1.x        | yes              | no             |
/// | `Subprocess`  | Pro Research    | yes              | yes (hardened) |
///
/// MAS cannot pivot to `IpcBounded` or `Subprocess` at runtime — flipping
/// requires a CLAUDE.md edit + App Review re-submission (see
/// `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md` IR-1).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentRuntimeV2Mode {
    /// MAS V1 — Agent Runtime v2 is dormant. Existing `agent_runtime::`
    /// paths serve all in-process orchestration. v2 callers MUST refuse to
    /// drive any executor when the active mode is `Disabled`.
    Disabled,
    /// Pro V1.x — bounded, in-process executor. WBO budget + macaroon
    /// verification + `MutationEnvelope` wrapping all required.
    IpcBounded,
    /// Pro Research only — subprocess CLI adapters (Claude Code, Codex,
    /// Goose, Aider, OpenHands, SweAgent). Hardened via
    /// `security::harden_cli_subprocess`. Never compiled into MAS.
    Subprocess,
}

impl AgentRuntimeV2Mode {
    /// True when the mode permits any v2 executor to run. `Disabled` is
    /// always false; the other two are always true.
    #[must_use]
    pub const fn allows_execution(self) -> bool {
        matches!(self, Self::IpcBounded | Self::Subprocess)
    }

    /// True only for the Research mode that may drive a subprocess CLI.
    /// MAS submissions MUST observe this as `false`.
    #[must_use]
    pub const fn allows_subprocess(self) -> bool {
        matches!(self, Self::Subprocess)
    }

    /// Canonical MAS default. Used by tests and by the MAS feature gate.
    #[must_use]
    pub const fn mas_default() -> Self {
        Self::Disabled
    }

    /// Canonical Pro default. Pro builds start in bounded mode; flipping
    /// to `Subprocess` is an explicit Research opt-in.
    #[must_use]
    pub const fn pro_default() -> Self {
        Self::IpcBounded
    }

    /// True when the mode is a Pro-tier mode (`IpcBounded` or
    /// `Subprocess`). Convenience for executor selection that wants
    /// to branch on "is Pro" without enumerating both variants.
    #[must_use]
    pub const fn is_pro(self) -> bool {
        matches!(self, Self::IpcBounded | Self::Subprocess)
    }
}

#[cfg(test)]
mod tests {
    use super::AgentRuntimeV2Mode;

    #[test]
    fn mas_default_is_disabled() {
        assert_eq!(AgentRuntimeV2Mode::mas_default(), AgentRuntimeV2Mode::Disabled);
        assert!(!AgentRuntimeV2Mode::Disabled.allows_execution());
        assert!(!AgentRuntimeV2Mode::Disabled.allows_subprocess());
    }

    #[test]
    fn pro_default_is_bounded_not_subprocess() {
        assert_eq!(AgentRuntimeV2Mode::pro_default(), AgentRuntimeV2Mode::IpcBounded);
        assert!(AgentRuntimeV2Mode::IpcBounded.allows_execution());
        assert!(!AgentRuntimeV2Mode::IpcBounded.allows_subprocess());
    }

    #[test]
    fn subprocess_allows_both() {
        assert!(AgentRuntimeV2Mode::Subprocess.allows_execution());
        assert!(AgentRuntimeV2Mode::Subprocess.allows_subprocess());
    }

    #[test]
    fn is_pro_returns_true_for_ipc_bounded_and_subprocess() {
        assert!(!AgentRuntimeV2Mode::Disabled.is_pro());
        assert!(AgentRuntimeV2Mode::IpcBounded.is_pro());
        assert!(AgentRuntimeV2Mode::Subprocess.is_pro());
    }

    #[test]
    fn only_subprocess_mode_allows_subprocess_spawn() {
        // Phase 1 hardening — MAS-safety invariant: allows_subprocess
        // must return false for both Disabled AND IpcBounded. The
        // MAS bundle observes Disabled by build-time gate; the Pro
        // V1.x bundle observes IpcBounded. Only the Pro Research
        // Subprocess mode may ever spawn a child binary. A future
        // refactor that flips this check must surface here first.
        assert!(!AgentRuntimeV2Mode::Disabled.allows_subprocess());
        assert!(!AgentRuntimeV2Mode::IpcBounded.allows_subprocess());
        assert!(AgentRuntimeV2Mode::Subprocess.allows_subprocess());
    }

    #[test]
    fn mode_serde_discriminator_values_are_stable() {
        // Phase 1 hardening — cross-version replay parity guardrail.
        // Pin the snake_case JSON string each variant serialises to.
        // A rename here silently breaks replay of older RunEventLogs
        // that embedded mode strings — catch the rename at PR review.
        assert_eq!(
            serde_json::to_string(&AgentRuntimeV2Mode::Disabled).unwrap(),
            "\"disabled\""
        );
        assert_eq!(
            serde_json::to_string(&AgentRuntimeV2Mode::IpcBounded).unwrap(),
            "\"ipc_bounded\""
        );
        assert_eq!(
            serde_json::to_string(&AgentRuntimeV2Mode::Subprocess).unwrap(),
            "\"subprocess\""
        );
    }

    #[test]
    fn allows_subprocess_implies_allows_execution_semantic_invariant() {
        // Phase 1 hardening — semantic invariant across the two
        // helper predicates. A mode that permits spawning a child
        // binary MUST also permit in-process executors to run
        // (the binary IS executed); the converse need not hold
        // (IpcBounded permits in-process execution but not
        // subprocess spawn). Tests this implication across all 3
        // variants so a future helper refactor that flips one
        // without the other surfaces at PR review.
        for mode in [
            AgentRuntimeV2Mode::Disabled,
            AgentRuntimeV2Mode::IpcBounded,
            AgentRuntimeV2Mode::Subprocess,
        ] {
            if mode.allows_subprocess() {
                assert!(
                    mode.allows_execution(),
                    "{mode:?}: allows_subprocess true → allows_execution must be true"
                );
            }
        }
        // Reverse direction: at least one mode permits execution
        // without permitting subprocess (witnesses the inequality).
        assert!(
            AgentRuntimeV2Mode::IpcBounded.allows_execution()
                && !AgentRuntimeV2Mode::IpcBounded.allows_subprocess(),
            "IpcBounded must witness execution-without-subprocess"
        );
    }

    #[test]
    fn mode_ord_matches_privilege_ladder_disabled_lt_ipc_bounded_lt_subprocess() {
        // Phase 1 hardening — PartialOrd+Ord derive on this enum is
        // load-bearing (BTreeSet membership for batch audits per
        // iter-48). The derived ordering MUST match the privilege
        // ladder so a future variant addition that inserts higher
        // privilege at the wrong source-order position is caught
        // at PR review.
        assert!(AgentRuntimeV2Mode::Disabled < AgentRuntimeV2Mode::IpcBounded);
        assert!(AgentRuntimeV2Mode::IpcBounded < AgentRuntimeV2Mode::Subprocess);
        assert!(AgentRuntimeV2Mode::Disabled < AgentRuntimeV2Mode::Subprocess);
        // Reflexive
        assert!(AgentRuntimeV2Mode::IpcBounded == AgentRuntimeV2Mode::IpcBounded);
        // Antisymmetric (negation)
        assert!(!(AgentRuntimeV2Mode::Subprocess < AgentRuntimeV2Mode::Disabled));
        // Sort a deliberately-out-of-order array → confirm ascending
        // privilege.
        let mut modes = [
            AgentRuntimeV2Mode::Subprocess,
            AgentRuntimeV2Mode::Disabled,
            AgentRuntimeV2Mode::IpcBounded,
        ];
        modes.sort();
        assert_eq!(
            modes,
            [
                AgentRuntimeV2Mode::Disabled,
                AgentRuntimeV2Mode::IpcBounded,
                AgentRuntimeV2Mode::Subprocess,
            ]
        );
        // Max / min usage as practical convenience.
        assert_eq!(modes.iter().max().copied(), Some(AgentRuntimeV2Mode::Subprocess));
        assert_eq!(modes.iter().min().copied(), Some(AgentRuntimeV2Mode::Disabled));
    }

    #[test]
    fn unknown_mode_string_fails_to_deserialise() {
        // Phase 1 hardening — negative serde pin. The closed taxonomy
        // (Disabled / IpcBounded / Subprocess) is load-bearing for MAS
        // safety: a RunEventLog entry that recorded a stray mode
        // string MUST fail to replay, not silently fall through to
        // a "default" variant. A future #[serde(other)] catch-all,
        // or a case-insensitive shim, would let an unknown mode
        // pass through — surface that at PR review.
        //
        // Three adversarial categories: outright unknown,
        // case-variant of a known mode (must fail because the
        // taxonomy is snake_case-exact), and the legacy "off" /
        // "on" shapes a maintainer might "helpfully" allow.
        for bad in [
            "\"research\"",        // semantically plausible but not in the taxonomy
            "\"unrestricted\"",    // adjacent vocabulary
            "\"DISABLED\"",        // case variant of a known mode
            "\"Ipc_Bounded\"",     // pascal-snake mix
            "\"ipcBounded\"",      // camelCase variant
            "\"off\"",             // legacy on/off shape
            "\"on\"",
            "\"\"",                // empty string
        ] {
            let r: Result<AgentRuntimeV2Mode, _> = serde_json::from_str(bad);
            assert!(
                r.is_err(),
                "unknown mode string {bad} must fail to deserialise (closed taxonomy)"
            );
        }
    }

    #[test]
    fn mode_const_fn_annotations_compile_in_const_context() {
        // Phase 1 hardening — compile-time pin for the 5 const fn
        // annotations on AgentRuntimeV2Mode (companion to iter-100's
        // BudgetSpec/Debit/Gate/Ledger const-context pin). The const
        // items compile if-and-only-if every called function is
        // `const fn`. A future refactor that dropped `const` from
        // any of these signatures surfaces as a compile failure
        // right here.
        //
        // Pinned signatures: AgentRuntimeV2Mode::{allows_execution,
        // allows_subprocess, mas_default, pro_default, is_pro}.
        const MAS: AgentRuntimeV2Mode = AgentRuntimeV2Mode::mas_default();
        const PRO: AgentRuntimeV2Mode = AgentRuntimeV2Mode::pro_default();
        const MAS_ALLOWS_EXEC: bool = MAS.allows_execution();
        const PRO_ALLOWS_EXEC: bool = PRO.allows_execution();
        const MAS_ALLOWS_SUB: bool = MAS.allows_subprocess();
        const PRO_ALLOWS_SUB: bool = PRO.allows_subprocess();
        const MAS_IS_PRO: bool = MAS.is_pro();
        const PRO_IS_PRO: bool = PRO.is_pro();
        const SUB_ALLOWS_EXEC: bool = AgentRuntimeV2Mode::Subprocess.allows_execution();
        const SUB_ALLOWS_SUB: bool = AgentRuntimeV2Mode::Subprocess.allows_subprocess();
        const SUB_IS_PRO: bool = AgentRuntimeV2Mode::Subprocess.is_pro();

        // Runtime sanity — keep const items live + provide regression
        // fallback should the const-context behaviour drift.
        assert_eq!(MAS, AgentRuntimeV2Mode::Disabled);
        assert_eq!(PRO, AgentRuntimeV2Mode::IpcBounded);
        assert!(!MAS_ALLOWS_EXEC);
        assert!(PRO_ALLOWS_EXEC);
        assert!(!MAS_ALLOWS_SUB);
        assert!(!PRO_ALLOWS_SUB);
        assert!(!MAS_IS_PRO);
        assert!(PRO_IS_PRO);
        assert!(SUB_ALLOWS_EXEC);
        assert!(SUB_ALLOWS_SUB);
        assert!(SUB_IS_PRO);
    }

    #[test]
    fn modes_round_trip_through_json() {
        for mode in [
            AgentRuntimeV2Mode::Disabled,
            AgentRuntimeV2Mode::IpcBounded,
            AgentRuntimeV2Mode::Subprocess,
        ] {
            let s = serde_json::to_string(&mode).expect("serialize");
            let back: AgentRuntimeV2Mode = serde_json::from_str(&s).expect("deserialize");
            assert_eq!(back, mode);
        }
    }
}
