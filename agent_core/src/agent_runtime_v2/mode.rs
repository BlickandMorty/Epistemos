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
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
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
