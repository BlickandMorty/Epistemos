//! `LocalAgentAdapter` — Rust mirror of the read-only
//! `Epistemos/LocalAgent/LocalAgentCapabilityRegistry.swift` typed
//! capability surface, surfaced through the v2 namespace.
//!
//! The Swift registry catalogs every legacy slash-command capability
//! the LocalAgent could expose. v2 phase 2 absorbs that vocabulary
//! into Rust so a single `AgentBlueprint` dispatch can map any
//! capability handle onto the correct `AgentRuntimeV2Mode` gate +
//! capability + budget shape.
//!
//! Source-of-truth Swift file: `Epistemos/LocalAgent/
//! LocalAgentCapabilityRegistry.swift` (read-only per T11 scope-lock).
//! This module's enum raw values MUST match the Swift `String` raw
//! values exactly so the bridge can round-trip via JSON without
//! translation tables.
//!
//! Status: iter-17 lands the enum mirrors + tier→mode mapping. The
//! actual `LocalAgentAdapter::dispatch` body lands in a later
//! iteration once the dispatcher seam is wired.

use serde::{Deserialize, Serialize};

use crate::agent_runtime_v2::mode::AgentRuntimeV2Mode;

/// Tier mirror of the Swift-side `LocalAgentCapabilityTier`. Names
/// match the Swift `String` raw values exactly.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum LocalAgentCapabilityTier {
    Core,
    Pro,
    Research,
}

impl LocalAgentCapabilityTier {
    /// Every tier the legacy registry knows about.
    pub const ALL: [LocalAgentCapabilityTier; 3] = [Self::Core, Self::Pro, Self::Research];

    /// Lowercase tier code matching the Swift raw value.
    #[must_use]
    pub const fn code(self) -> &'static str {
        match self {
            Self::Core => "core",
            Self::Pro => "pro",
            Self::Research => "research",
        }
    }

    /// Tier-to-mode gate: which `AgentRuntimeV2Mode` values may
    /// serve a capability of this tier through v2.
    ///
    /// **Core tier semantics:** core-tier capabilities are MAS-
    /// allowed (e.g. `/ask`, `/think`, `/plan`, `/todo`). MAS V1
    /// itself observes v2 as `Disabled` and serves these through the
    /// legacy `agent_runtime::` path — v2 must REFUSE every tier in
    /// `Disabled` mode. Pro V1.x and Pro Research builds may serve
    /// core-tier capabilities through v2 once the dispatcher is
    /// wired.
    ///
    /// **Pro tier:** Pro V1.x bounded executor + Pro Research only.
    ///
    /// **Research tier:** Pro Research subprocess executor only.
    #[must_use]
    pub fn allowed_in(self, mode: AgentRuntimeV2Mode) -> bool {
        match (self, mode) {
            (_, AgentRuntimeV2Mode::Disabled) => false,
            (Self::Core | Self::Pro, AgentRuntimeV2Mode::IpcBounded) => true,
            (Self::Research, AgentRuntimeV2Mode::IpcBounded) => false,
            (_, AgentRuntimeV2Mode::Subprocess) => true,
        }
    }

    /// Return the MINIMUM `AgentRuntimeV2Mode` that can serve this
    /// tier through v2. Bridges the legacy LocalAgent tier vocabulary
    /// to v2's mode lattice. Used by the dispatcher to pick the
    /// least-privileged mode that still admits the capability.
    ///
    /// - `Core` → `IpcBounded` (Pro V1.x bounded executor is enough)
    /// - `Pro` → `IpcBounded`
    /// - `Research` → `Subprocess` (requires the subprocess path)
    #[must_use]
    pub const fn required_mode(self) -> AgentRuntimeV2Mode {
        match self {
            Self::Core | Self::Pro => AgentRuntimeV2Mode::IpcBounded,
            Self::Research => AgentRuntimeV2Mode::Subprocess,
        }
    }
}

/// Owner mirror of `LocalAgentCapabilityOwner`. Identifies which
/// subsystem is the canonical owner of a given capability.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum LocalAgentCapabilityOwner {
    #[serde(rename = "nativeCore")]
    NativeCore,
    #[serde(rename = "localAgentGateway")]
    LocalAgentGateway,
    #[serde(rename = "researchOnly")]
    ResearchOnly,
    #[serde(rename = "outOfScope")]
    OutOfScope,
}

impl LocalAgentCapabilityOwner {
    pub const ALL: [LocalAgentCapabilityOwner; 4] = [
        Self::NativeCore,
        Self::LocalAgentGateway,
        Self::ResearchOnly,
        Self::OutOfScope,
    ];

    /// camelCase code matching the Swift raw value.
    #[must_use]
    pub const fn code(self) -> &'static str {
        match self {
            Self::NativeCore => "nativeCore",
            Self::LocalAgentGateway => "localAgentGateway",
            Self::ResearchOnly => "researchOnly",
            Self::OutOfScope => "outOfScope",
        }
    }
}

/// Surface mirror of `LocalAgentCapabilitySurface`. Groups capabilities
/// by the user-facing surface area they affect.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum LocalAgentCapabilitySurface {
    #[serde(rename = "agentTask")]
    AgentTask,
    #[serde(rename = "session")]
    Session,
    #[serde(rename = "configuration")]
    Configuration,
    #[serde(rename = "fileData")]
    FileData,
    #[serde(rename = "toolsIntegration")]
    ToolsIntegration,
    #[serde(rename = "uiDisplay")]
    UiDisplay,
    #[serde(rename = "persona")]
    Persona,
    #[serde(rename = "messaging")]
    Messaging,
    #[serde(rename = "advanced")]
    Advanced,
    #[serde(rename = "toolset")]
    Toolset,
}

impl LocalAgentCapabilitySurface {
    pub const ALL: [LocalAgentCapabilitySurface; 10] = [
        Self::AgentTask,
        Self::Session,
        Self::Configuration,
        Self::FileData,
        Self::ToolsIntegration,
        Self::UiDisplay,
        Self::Persona,
        Self::Messaging,
        Self::Advanced,
        Self::Toolset,
    ];
}

/// `LocalAgentCapability` — the typed handle the legacy Swift
/// registry exposes per slash-command. Mirrors the Swift struct
/// field-for-field so the bridge layer can round-trip via JSON.
///
/// Iter-17 keeps the struct shape stable; iter-18+ uses it to drive
/// per-capability gate decisions inside the dispatcher.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct LocalAgentCapability {
    pub command_pattern: String,
    pub surface: LocalAgentCapabilitySurface,
    pub tier: LocalAgentCapabilityTier,
    pub owner: LocalAgentCapabilityOwner,
    pub requires_network: bool,
    pub requires_subprocess: bool,
    pub requires_approval: bool,
    pub structured_evidence: bool,
    pub native_equivalent: String,
    pub local_agent_passthrough: bool,
}

impl LocalAgentCapability {
    /// Command token = the leading non-placeholder tokens (anything
    /// before the first `<...>` or `[...]` argument). Matches the
    /// Swift `LocalAgentCapability.commandToken` helper byte-for-byte.
    #[must_use]
    pub fn command_token(&self) -> String {
        Self::command_token_from(&self.command_pattern)
    }

    /// Static variant of `command_token` for callers that hold only
    /// the pattern string (mirrors the Swift static helper).
    #[must_use]
    pub fn command_token_from(pattern: &str) -> String {
        pattern
            .split_whitespace()
            .take_while(|part| !part.starts_with('<') && !part.starts_with('['))
            .collect::<Vec<_>>()
            .join(" ")
    }

    /// True iff this capability is admissible under the given v2 mode.
    /// Combines the tier gate with `requires_subprocess`: a capability
    /// marked `requires_subprocess` must only run when the mode is
    /// `Subprocess`, regardless of its tier.
    #[must_use]
    pub fn allowed_in(&self, mode: AgentRuntimeV2Mode) -> bool {
        if !self.tier.allowed_in(mode) {
            return false;
        }
        if self.requires_subprocess && mode != AgentRuntimeV2Mode::Subprocess {
            return false;
        }
        true
    }
}

/// Adapter scaffold. The dispatcher seam lands in a later iteration;
/// today the adapter exists so callers can `use` the type and
/// `LocalAgentCapability` from the v2 namespace.
#[derive(Debug, Clone, Default)]
pub struct LocalAgentAdapter {
    _scaffold: (),
}

impl LocalAgentAdapter {
    #[must_use]
    pub const fn new() -> Self {
        Self { _scaffold: () }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── Tier enum invariants (iter-16 carry-over) ─────────────────────────────

    #[test]
    fn local_agent_const_fn_annotations_compile_in_const_context() {
        // Phase 1 hardening — compile-time pin for the const-able
        // surfaces in adapters/local_agent.rs (companion to iter-100
        // through iter-103 const-context pins). A future refactor
        // that dropped `const` from any of these signatures surfaces
        // as a compile failure right here.
        //
        // Pinned signatures:
        //   - LocalAgentCapabilityTier::code        (3 variants)
        //   - LocalAgentCapabilityTier::required_mode (3 variants)
        //   - LocalAgentCapabilityOwner::code       (4 variants)
        //   - LocalAgentAdapter::new
        //   - associated consts ALL on Tier / Owner / Surface
        const TIER_CORE_CODE: &str = LocalAgentCapabilityTier::Core.code();
        const TIER_PRO_CODE: &str = LocalAgentCapabilityTier::Pro.code();
        const TIER_RES_CODE: &str = LocalAgentCapabilityTier::Research.code();
        const TIER_CORE_MODE: AgentRuntimeV2Mode =
            LocalAgentCapabilityTier::Core.required_mode();
        const TIER_PRO_MODE: AgentRuntimeV2Mode =
            LocalAgentCapabilityTier::Pro.required_mode();
        const TIER_RES_MODE: AgentRuntimeV2Mode =
            LocalAgentCapabilityTier::Research.required_mode();
        const OWNER_NATIVE_CODE: &str = LocalAgentCapabilityOwner::NativeCore.code();
        const OWNER_OUTOFSCOPE_CODE: &str = LocalAgentCapabilityOwner::OutOfScope.code();
        const _: LocalAgentAdapter = LocalAgentAdapter::new();
        const TIER_ALL_LEN: usize = LocalAgentCapabilityTier::ALL.len();
        const OWNER_ALL_LEN: usize = LocalAgentCapabilityOwner::ALL.len();
        const SURFACE_ALL_LEN: usize = LocalAgentCapabilitySurface::ALL.len();

        // Runtime asserts keep the const items live.
        assert_eq!(TIER_CORE_CODE, "core");
        assert_eq!(TIER_PRO_CODE, "pro");
        assert_eq!(TIER_RES_CODE, "research");
        assert_eq!(TIER_CORE_MODE, AgentRuntimeV2Mode::IpcBounded);
        assert_eq!(TIER_PRO_MODE, AgentRuntimeV2Mode::IpcBounded);
        assert_eq!(TIER_RES_MODE, AgentRuntimeV2Mode::Subprocess);
        assert_eq!(OWNER_NATIVE_CODE, "nativeCore");
        assert_eq!(OWNER_OUTOFSCOPE_CODE, "outOfScope");
        assert_eq!(TIER_ALL_LEN, 3);
        assert_eq!(OWNER_ALL_LEN, 4);
        assert_eq!(SURFACE_ALL_LEN, 10);
    }

    #[test]
    fn local_agent_tier_mirror_enumerates_all_three_legacy_tiers() {
        assert_eq!(LocalAgentCapabilityTier::ALL.len(), 3);
        assert!(LocalAgentCapabilityTier::ALL.contains(&LocalAgentCapabilityTier::Core));
        assert!(LocalAgentCapabilityTier::ALL.contains(&LocalAgentCapabilityTier::Pro));
        assert!(LocalAgentCapabilityTier::ALL.contains(&LocalAgentCapabilityTier::Research));
    }

    #[test]
    fn local_agent_tier_owner_surface_all_arrays_have_pairwise_distinct_variants() {
        // Phase 1 hardening — pairwise distinctness pin for the
        // canonical ALL arrays. Each array enumerates every variant
        // of its enum; pairwise distinctness ensures no duplicate
        // entry was accidentally added.
        //
        // Companion to the cardinality pins (Tier 3 / Owner 4 /
        // Surface 10).
        for i in 0..LocalAgentCapabilityTier::ALL.len() {
            for j in (i + 1)..LocalAgentCapabilityTier::ALL.len() {
                assert_ne!(
                    LocalAgentCapabilityTier::ALL[i],
                    LocalAgentCapabilityTier::ALL[j],
                    "Tier::ALL[{i}] and Tier::ALL[{j}] must be distinct"
                );
            }
        }
        for i in 0..LocalAgentCapabilityOwner::ALL.len() {
            for j in (i + 1)..LocalAgentCapabilityOwner::ALL.len() {
                assert_ne!(
                    LocalAgentCapabilityOwner::ALL[i],
                    LocalAgentCapabilityOwner::ALL[j],
                    "Owner::ALL[{i}] and Owner::ALL[{j}] must be distinct"
                );
            }
        }
        for i in 0..LocalAgentCapabilitySurface::ALL.len() {
            for j in (i + 1)..LocalAgentCapabilitySurface::ALL.len() {
                assert_ne!(
                    LocalAgentCapabilitySurface::ALL[i],
                    LocalAgentCapabilitySurface::ALL[j],
                    "Surface::ALL[{i}] and Surface::ALL[{j}] must be distinct"
                );
            }
        }
    }

    #[test]
    fn local_agent_tier_and_owner_code_helpers_are_pure_deterministic() {
        // Phase 1 hardening — runtime determinism pin (companion to
        // the purity series + iter-104 const-fn compile pin).
        // LocalAgentCapabilityTier::code and
        // LocalAgentCapabilityOwner::code both return &'static str
        // via pure match; calling them many times produces
        // identical results.
        for tier in LocalAgentCapabilityTier::ALL {
            for _ in 0..3 {
                assert_eq!(tier.code(), tier.code());
            }
        }
        for owner in LocalAgentCapabilityOwner::ALL {
            for _ in 0..3 {
                assert_eq!(owner.code(), owner.code());
            }
        }
    }

    #[test]
    fn local_agent_tier_codes_match_swift_raw_values() {
        assert_eq!(LocalAgentCapabilityTier::Core.code(), "core");
        assert_eq!(LocalAgentCapabilityTier::Pro.code(), "pro");
        assert_eq!(LocalAgentCapabilityTier::Research.code(), "research");
    }

    #[test]
    fn local_agent_tier_all_three_codes_are_distinct_and_lowercase() {
        // Phase 1 hardening — symmetric companion to
        // budget_term_all_five_codes_are_distinct_and_lowercase_snake_case,
        // agent_event_error_kind_all_four_codes... (iter-362),
        // variant_tier_all_three_codes... (iter-363).
        //
        // LocalAgentCapabilityTier::code() returns lowercase strings
        // ("core", "pro", "research") matching the Swift raw values.
        // All 3 must be pairwise distinct (collisions silently merge
        // audit counters) and lowercase ASCII (only [a-z], non-empty —
        // no underscore here because the tier names are simple words).
        //
        // Defends against a future "let me PascalCase the tier codes
        // for visual consistency with the Display impl" refactor that
        // would silently break Swift⇄Rust raw-value parity.
        let codes = [
            LocalAgentCapabilityTier::Core.code(),
            LocalAgentCapabilityTier::Pro.code(),
            LocalAgentCapabilityTier::Research.code(),
        ];
        for i in 0..codes.len() {
            for j in (i + 1)..codes.len() {
                assert_ne!(codes[i], codes[j], "codes[{i}] == codes[{j}]");
            }
        }
        for c in codes {
            assert!(
                c.chars().all(|ch| ch.is_ascii_lowercase()),
                "code {c:?} must be pure-lowercase ASCII"
            );
            assert!(!c.is_empty());
        }
    }

    #[test]
    fn local_agent_tier_serde_values_are_stable() {
        // Phase 1 hardening MILESTONE iter-410 — completes the
        // serde-stable-values pin family across every closed-taxonomy
        // enum in agent_runtime_v2. LocalAgentCapabilityTier carries
        // #[serde(rename_all = "lowercase")] (NOT snake_case — these
        // are simple single-word tier names matching the Swift raw
        // values).
        //
        // Companion to:
        //   - mode_serde_discriminator_values_are_stable (3 modes / snake_case)
        //   - agent_event_error_kind_serde_values_are_stable (4 / snake_case)
        //   - cli_adapter_serde_snake_case_pins_all_six_adapter_strings (6 / snake_case)
        //   - agent_event_serde_tag_values_are_stable (6 / snake_case)
        //   - stop_reason_serde_values_are_stable (7 / snake_case)
        //   - variant_tier_serde_values_are_stable (3 / snake_case)
        //   - LocalAgentCapabilityTier (this commit / lowercase, 3 variants)
        //
        // Series total now: 7 enums + 32 individual variant→string mappings
        // pinned at the JSON wire layer. Defends against ANY future
        // serde rename that would silently fork persisted JSON.
        for (variant, expected) in [
            (LocalAgentCapabilityTier::Core, "\"core\""),
            (LocalAgentCapabilityTier::Pro, "\"pro\""),
            (LocalAgentCapabilityTier::Research, "\"research\""),
        ] {
            let s = serde_json::to_string(&variant).expect("serialise");
            assert_eq!(s, expected, "tier {variant:?} drifted serde form");
            let back: LocalAgentCapabilityTier = serde_json::from_str(&s).expect("round-trip");
            assert_eq!(back, variant);
        }
    }

    #[test]
    fn local_agent_tier_unknown_serde_string_fails_to_deserialise() {
        // Phase 1 hardening — closed-taxonomy negative-serde pin
        // (continues the trilogy-of-trilogies pattern from iter-71
        // through iter-82 + iter-78). LocalAgentCapabilityTier uses
        // #[serde(rename_all = "lowercase")] over 3 variants
        // (core, pro, research). The Swift mirror reads the same
        // string discriminators byte-for-byte, so a stray tier
        // string crossing the FFI bridge must fail to deserialise
        // — not silently route to a default tier (which would
        // misroute capability access through the wrong mode gate).
        for bad in [
            // Adjacent vocab
            "\"basic\"",
            "\"standard\"",
            "\"experimental\"",
            "\"sandboxed\"",
            // Case variants of valid strings
            "\"Core\"",
            "\"PRO\"",
            "\"Research\"",
            "\"CORE\"",
            // Padded / camelCase / kebab drift
            "\"core_tier\"",
            "\"pro-tier\"",
            "\"researchTier\"",
            "\"\"",
        ] {
            let r: Result<LocalAgentCapabilityTier, _> = serde_json::from_str(bad);
            assert!(
                r.is_err(),
                "unknown LocalAgentCapabilityTier string {bad} must fail to deserialise"
            );
        }
        // Positive sanity: every valid variant still round-trips byte-equal.
        for (variant, expected) in [
            (LocalAgentCapabilityTier::Core, "\"core\""),
            (LocalAgentCapabilityTier::Pro, "\"pro\""),
            (LocalAgentCapabilityTier::Research, "\"research\""),
        ] {
            let s = serde_json::to_string(&variant).unwrap();
            assert_eq!(s, expected, "tier {variant:?} drifted serde form");
            let back: LocalAgentCapabilityTier = serde_json::from_str(&s).unwrap();
            assert_eq!(back, variant);
        }
    }

    #[test]
    fn local_agent_tier_round_trips_through_json() {
        for tier in LocalAgentCapabilityTier::ALL {
            let s = serde_json::to_string(&tier).expect("serialize");
            let back: LocalAgentCapabilityTier =
                serde_json::from_str(&s).expect("deserialize");
            assert_eq!(back, tier);
        }
    }

    // ── Tier→mode mapping (iter-17 new) ───────────────────────────────────────

    #[test]
    fn core_tier_refused_in_disabled_mode() {
        // §4 T11 "MAS cannot call CLI" lifted to the LocalAgent
        // registry: v2 must refuse every tier in Disabled mode (MAS
        // V1 routes core-tier capabilities through the legacy
        // agent_runtime path, not v2).
        assert!(!LocalAgentCapabilityTier::Core.allowed_in(AgentRuntimeV2Mode::Disabled));
        assert!(!LocalAgentCapabilityTier::Pro.allowed_in(AgentRuntimeV2Mode::Disabled));
        assert!(!LocalAgentCapabilityTier::Research.allowed_in(AgentRuntimeV2Mode::Disabled));
    }

    #[test]
    fn ipc_bounded_serves_core_and_pro_only() {
        assert!(LocalAgentCapabilityTier::Core.allowed_in(AgentRuntimeV2Mode::IpcBounded));
        assert!(LocalAgentCapabilityTier::Pro.allowed_in(AgentRuntimeV2Mode::IpcBounded));
        assert!(!LocalAgentCapabilityTier::Research.allowed_in(AgentRuntimeV2Mode::IpcBounded));
    }

    #[test]
    fn local_agent_tier_allowed_in_exhausts_3_tiers_x_3_modes_matrix() {
        // Phase 1 hardening — consolidated exhaustive 3×3 matrix
        // for LocalAgentCapabilityTier::allowed_in (companion to
        // iter-86 LocalAgentCapability::allowed_in 3×2×3 matrix
        // and iter-175 check_against_mode 3×6 matrix). The
        // existing tier-mode tests split the 9 cells across 3
        // separate fixtures (core_tier_refused_in_disabled_mode,
        // ipc_bounded_serves_core_and_pro_only,
        // subprocess_serves_all_tiers); this pin enumerates them
        // in one place with the truth-table embedded.
        let cases: &[(LocalAgentCapabilityTier, AgentRuntimeV2Mode, bool)] = &[
            // Disabled mode → ALWAYS deny (MAS safety invariant).
            (LocalAgentCapabilityTier::Core, AgentRuntimeV2Mode::Disabled, false),
            (LocalAgentCapabilityTier::Pro, AgentRuntimeV2Mode::Disabled, false),
            (LocalAgentCapabilityTier::Research, AgentRuntimeV2Mode::Disabled, false),
            // IpcBounded mode → admit Core/Pro, deny Research.
            (LocalAgentCapabilityTier::Core, AgentRuntimeV2Mode::IpcBounded, true),
            (LocalAgentCapabilityTier::Pro, AgentRuntimeV2Mode::IpcBounded, true),
            (LocalAgentCapabilityTier::Research, AgentRuntimeV2Mode::IpcBounded, false),
            // Subprocess mode → admit all tiers.
            (LocalAgentCapabilityTier::Core, AgentRuntimeV2Mode::Subprocess, true),
            (LocalAgentCapabilityTier::Pro, AgentRuntimeV2Mode::Subprocess, true),
            (LocalAgentCapabilityTier::Research, AgentRuntimeV2Mode::Subprocess, true),
        ];
        assert_eq!(cases.len(), 9, "must enumerate all 3×3 combinations");
        for &(tier, mode, expected) in cases {
            let actual = tier.allowed_in(mode);
            assert_eq!(
                actual, expected,
                "tier={tier:?} mode={mode:?} expected {expected} got {actual}"
            );
        }
    }

    #[test]
    fn local_agent_tier_required_mode_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series iter-220/221).
        // LocalAgentCapabilityTier::required_mode is a const fn
        // returning AgentRuntimeV2Mode (Copy); calling it many
        // times must produce identical results.
        //
        // Trivially true today (the impl is a const match), but
        // a future refactor that introduced lazy_static or interior
        // mutability for "policy injection" would silently break
        // the determinism contract.
        for tier in [
            LocalAgentCapabilityTier::Core,
            LocalAgentCapabilityTier::Pro,
            LocalAgentCapabilityTier::Research,
        ] {
            let r1 = tier.required_mode();
            let r2 = tier.required_mode();
            let r3 = tier.required_mode();
            assert_eq!(r1, r2);
            assert_eq!(r2, r3);
        }
    }

    #[test]
    fn required_mode_returns_minimum_serving_mode_per_tier() {
        // Phase 1 hardening — bridges legacy LocalAgent tier
        // vocabulary to v2's mode lattice. Lock the mapping so a
        // future tier→mode shuffle surfaces here.
        assert_eq!(
            LocalAgentCapabilityTier::Core.required_mode(),
            AgentRuntimeV2Mode::IpcBounded
        );
        assert_eq!(
            LocalAgentCapabilityTier::Pro.required_mode(),
            AgentRuntimeV2Mode::IpcBounded
        );
        assert_eq!(
            LocalAgentCapabilityTier::Research.required_mode(),
            AgentRuntimeV2Mode::Subprocess
        );
        // Cross-consistency: a tier's required_mode must satisfy
        // its own allowed_in check.
        for tier in LocalAgentCapabilityTier::ALL {
            assert!(
                tier.allowed_in(tier.required_mode()),
                "{tier:?} must be allowed in its required_mode"
            );
        }
    }

    #[test]
    fn subprocess_serves_all_tiers() {
        for tier in LocalAgentCapabilityTier::ALL {
            assert!(tier.allowed_in(AgentRuntimeV2Mode::Subprocess));
        }
    }

    // ── Owner / surface enum mirrors ──────────────────────────────────────────

    #[test]
    fn owner_codes_match_swift_camel_case_raw_values() {
        assert_eq!(LocalAgentCapabilityOwner::NativeCore.code(), "nativeCore");
        assert_eq!(
            LocalAgentCapabilityOwner::LocalAgentGateway.code(),
            "localAgentGateway"
        );
        assert_eq!(LocalAgentCapabilityOwner::ResearchOnly.code(), "researchOnly");
        assert_eq!(LocalAgentCapabilityOwner::OutOfScope.code(), "outOfScope");
    }

    #[test]
    fn owner_enumerates_all_four_swift_variants() {
        assert_eq!(LocalAgentCapabilityOwner::ALL.len(), 4);
    }

    #[test]
    fn local_agent_owner_all_four_codes_are_distinct_and_camel_case() {
        // Phase 1 hardening — camelCase variant of the
        // "all codes distinct + lowercase" pattern (companion to
        // BudgetTerm/AgentEventErrorKind/VariantTier/LocalAgentCapabilityTier
        // pins). LocalAgentCapabilityOwner::code() returns camelCase
        // strings (e.g., "nativeCore") matching the Swift raw values
        // — these are NOT snake_case because the Swift mirror types
        // use camelCase enum case raw values.
        //
        // All 4 must be:
        //   - pairwise distinct (collisions silently merge audit counters)
        //   - camelCase ASCII (starts lowercase; only [a-zA-Z], non-empty)
        //
        // Defends against a future "let me snake_case the owner codes
        // for consistency with BudgetTerm" refactor that would silently
        // break Swift⇄Rust raw-value parity.
        let codes = [
            LocalAgentCapabilityOwner::NativeCore.code(),
            LocalAgentCapabilityOwner::LocalAgentGateway.code(),
            LocalAgentCapabilityOwner::ResearchOnly.code(),
            LocalAgentCapabilityOwner::OutOfScope.code(),
        ];
        for i in 0..codes.len() {
            for j in (i + 1)..codes.len() {
                assert_ne!(codes[i], codes[j], "codes[{i}] == codes[{j}]");
            }
        }
        for c in codes {
            assert!(!c.is_empty(), "code must be non-empty");
            // First char lowercase.
            let first = c.chars().next().expect("non-empty");
            assert!(
                first.is_ascii_lowercase(),
                "camelCase code {c:?} must start with lowercase, got {first:?}"
            );
            // All chars in [a-zA-Z] (no digits, no underscores, no separators).
            assert!(
                c.chars().all(|ch| ch.is_ascii_alphabetic()),
                "code {c:?} must be pure [a-zA-Z] camelCase"
            );
        }
    }

    #[test]
    fn surface_enumerates_all_ten_swift_variants() {
        assert_eq!(LocalAgentCapabilitySurface::ALL.len(), 10);
    }

    #[test]
    fn local_agent_owner_serde_values_are_stable() {
        // Phase 1 hardening — cross-version replay parity guardrail.
        // LocalAgentCapabilityOwner uses per-variant
        // #[serde(rename = "...")] to produce camelCase Swift raw values.
        // Every variant string is load-bearing for cross-FFI parity
        // with the Swift mirror struct.
        //
        // Companion to iter-410's LocalAgentCapabilityTier serde
        // stable values pin (which closed the broader pin family).
        // This extends to the second LocalAgent enum.
        //
        // A rename here silently breaks the Swift⇄Rust JSON bridge.
        for (variant, expected) in [
            (LocalAgentCapabilityOwner::NativeCore, "\"nativeCore\""),
            (LocalAgentCapabilityOwner::LocalAgentGateway, "\"localAgentGateway\""),
            (LocalAgentCapabilityOwner::ResearchOnly, "\"researchOnly\""),
            (LocalAgentCapabilityOwner::OutOfScope, "\"outOfScope\""),
        ] {
            let s = serde_json::to_string(&variant).expect("serialise");
            assert_eq!(s, expected, "owner {variant:?} drifted serde form");
            let back: LocalAgentCapabilityOwner = serde_json::from_str(&s).expect("round-trip");
            assert_eq!(back, variant);
        }
    }

    #[test]
    fn local_agent_owner_unknown_serde_string_fails_to_deserialise() {
        // Phase 1 hardening — tenth leg of the closed-taxonomy
        // negative-serde guardrail. LocalAgentCapabilityOwner uses
        // per-variant #[serde(rename = "...")] with camelCase
        // (nativeCore, localAgentGateway, researchOnly, outOfScope).
        // The Swift mirror reads the same camelCase byte-for-byte;
        // a stray owner string crossing the FFI bridge must fail to
        // deserialise — not silently absorb into a default owner
        // (which would misroute capability ownership in the
        // dispatcher).
        for bad in [
            // Unknown owner vocab
            "\"system\"",
            "\"plugin\"",
            "\"thirdParty\"",
            // Case variants of valid strings
            "\"NativeCore\"",
            "\"NATIVE_CORE\"",
            "\"nativecore\"",
            "\"LocalAgentGateway\"",
            "\"localagentgateway\"",
            // snake_case drift (the Swift mirror uses camelCase)
            "\"native_core\"",
            "\"local_agent_gateway\"",
            "\"research_only\"",
            "\"out_of_scope\"",
            // Kebab-case drift
            "\"native-core\"",
            "\"out-of-scope\"",
            "\"\"",
        ] {
            let r: Result<LocalAgentCapabilityOwner, _> = serde_json::from_str(bad);
            assert!(
                r.is_err(),
                "unknown LocalAgentCapabilityOwner string {bad} must fail to deserialise"
            );
        }
        // Positive sanity: every valid variant still round-trips byte-equal.
        for (variant, expected) in [
            (LocalAgentCapabilityOwner::NativeCore, "\"nativeCore\""),
            (
                LocalAgentCapabilityOwner::LocalAgentGateway,
                "\"localAgentGateway\"",
            ),
            (LocalAgentCapabilityOwner::ResearchOnly, "\"researchOnly\""),
            (LocalAgentCapabilityOwner::OutOfScope, "\"outOfScope\""),
        ] {
            let s = serde_json::to_string(&variant).unwrap();
            assert_eq!(s, expected, "owner {variant:?} drifted serde form");
            let back: LocalAgentCapabilityOwner = serde_json::from_str(&s).unwrap();
            assert_eq!(back, variant);
        }
    }

    #[test]
    fn owner_round_trips_through_json() {
        for o in LocalAgentCapabilityOwner::ALL {
            let s = serde_json::to_string(&o).expect("serialize");
            let back: LocalAgentCapabilityOwner =
                serde_json::from_str(&s).expect("deserialize");
            assert_eq!(back, o);
        }
    }

    #[test]
    fn local_agent_surface_serde_values_are_stable() {
        // Phase 1 hardening — cross-version replay parity guardrail.
        // LocalAgentCapabilitySurface uses per-variant #[serde(rename
        // = "...")] to produce camelCase Swift raw values. All 10
        // variants pinned to their canonical wire form — a rename
        // here silently breaks the Swift⇄Rust JSON bridge.
        //
        // Companion to:
        //   - local_agent_tier_serde_values_are_stable (3 / lowercase)
        //   - local_agent_owner_serde_values_are_stable (4 / camelCase)
        //   - LocalAgentCapabilitySurface (this commit / 10 camelCase)
        for (variant, expected) in [
            (LocalAgentCapabilitySurface::AgentTask, "\"agentTask\""),
            (LocalAgentCapabilitySurface::Session, "\"session\""),
            (LocalAgentCapabilitySurface::Configuration, "\"configuration\""),
            (LocalAgentCapabilitySurface::FileData, "\"fileData\""),
            (LocalAgentCapabilitySurface::ToolsIntegration, "\"toolsIntegration\""),
            (LocalAgentCapabilitySurface::UiDisplay, "\"uiDisplay\""),
            (LocalAgentCapabilitySurface::Persona, "\"persona\""),
            (LocalAgentCapabilitySurface::Messaging, "\"messaging\""),
            (LocalAgentCapabilitySurface::Advanced, "\"advanced\""),
            (LocalAgentCapabilitySurface::Toolset, "\"toolset\""),
        ] {
            let s = serde_json::to_string(&variant).expect("serialise");
            assert_eq!(s, expected, "surface {variant:?} drifted serde form");
            let back: LocalAgentCapabilitySurface = serde_json::from_str(&s).expect("round-trip");
            assert_eq!(back, variant);
        }
    }

    #[test]
    fn local_agent_surface_unknown_serde_string_fails_to_deserialise() {
        // Phase 1 hardening — eleventh leg of the closed-taxonomy
        // negative-serde guardrail. LocalAgentCapabilitySurface uses
        // per-variant #[serde(rename = "...")] with camelCase over
        // 10 variants (agentTask, session, configuration, fileData,
        // toolsIntegration, uiDisplay, persona, messaging, advanced,
        // toolset). The Swift mirror reads the same camelCase
        // byte-for-byte; a stray surface string crossing the FFI
        // bridge must fail to deserialise — not silently absorb
        // into a default surface (which would misroute capability
        // grouping in the UI / audit dashboards).
        for bad in [
            // Unknown surface vocab
            "\"system\"",
            "\"network\"",
            "\"telemetry\"",
            "\"diagnostic\"",
            // Case variants of valid strings (camelCase is the contract)
            "\"AgentTask\"",
            "\"AGENT_TASK\"",
            "\"agenttask\"",
            "\"FileData\"",
            "\"FILE_DATA\"",
            // snake_case drift (the Swift mirror uses camelCase)
            "\"agent_task\"",
            "\"file_data\"",
            "\"tools_integration\"",
            "\"ui_display\"",
            // Kebab-case drift
            "\"agent-task\"",
            "\"tools-integration\"",
            "\"\"",
        ] {
            let r: Result<LocalAgentCapabilitySurface, _> = serde_json::from_str(bad);
            assert!(
                r.is_err(),
                "unknown LocalAgentCapabilitySurface string {bad} must fail to deserialise"
            );
        }
        // Positive sanity: all 10 variants still round-trip with the
        // expected camelCase form.
        for (variant, expected) in [
            (LocalAgentCapabilitySurface::AgentTask, "\"agentTask\""),
            (LocalAgentCapabilitySurface::Session, "\"session\""),
            (LocalAgentCapabilitySurface::Configuration, "\"configuration\""),
            (LocalAgentCapabilitySurface::FileData, "\"fileData\""),
            (
                LocalAgentCapabilitySurface::ToolsIntegration,
                "\"toolsIntegration\"",
            ),
            (LocalAgentCapabilitySurface::UiDisplay, "\"uiDisplay\""),
            (LocalAgentCapabilitySurface::Persona, "\"persona\""),
            (LocalAgentCapabilitySurface::Messaging, "\"messaging\""),
            (LocalAgentCapabilitySurface::Advanced, "\"advanced\""),
            (LocalAgentCapabilitySurface::Toolset, "\"toolset\""),
        ] {
            let s = serde_json::to_string(&variant).unwrap();
            assert_eq!(s, expected, "surface {variant:?} drifted serde form");
            let back: LocalAgentCapabilitySurface = serde_json::from_str(&s).unwrap();
            assert_eq!(back, variant);
        }
    }

    #[test]
    fn surface_round_trips_through_json() {
        for s in LocalAgentCapabilitySurface::ALL {
            let serialized = serde_json::to_string(&s).expect("serialize");
            let back: LocalAgentCapabilitySurface =
                serde_json::from_str(&serialized).expect("deserialize");
            assert_eq!(back, s);
        }
    }

    #[test]
    fn local_agent_capability_is_clone_send_sync_but_not_copy() {
        // Phase 1 hardening — trait-bound pin for the multi-String
        // capability struct. Companion to the Clone + Send + Sync (not
        // Copy) pin family (AgentBlueprintId iter-375 → MissionPacket +
        // ToolCall iter-376 → AnswerPacket + Citation iter-377 →
        // AgentBlueprint + ProviderPolicy iter-378).
        //
        // LocalAgentCapability: 10 fields including 2 Strings
        // (command_pattern, native_equivalent) and 8 Copy fields
        // (3 enum tier/owner/surface + 4 booleans + 1 String). Clone
        // by derive but NOT Copy (Strings allocate).
        //
        // Send + Sync are load-bearing — Swift⇄Rust bridge marshalls
        // capabilities across the FFI boundary, which the runtime
        // treats as the same as crossing a thread boundary for safety.
        //
        // A future "let me hold a SwiftClosure callback inside
        // LocalAgentCapability" refactor that introduced a non-Send
        // type would silently break cross-bridge propagation —
        // surface here.
        fn assert_clone_send_sync<T: Clone + Send + Sync>() {}
        assert_clone_send_sync::<LocalAgentCapability>();

        let cap = shell_capability();
        assert_eq!(cap.clone(), cap);
    }

    #[test]
    fn local_agent_tier_owner_surface_are_copy_clone_send_sync_for_propagation_safety() {
        // Phase 1 hardening — trait-bound pin (companion to budget_gate,
        // mode iter-366, StopReason iter-367, VariantTier iter-368).
        // All three LocalAgent enums (Tier 3v / Owner 4v / Surface 10v)
        // are unit enums marked Copy via derive (lines 27/92/126).
        // No interior mutability, no heap, no Drop.
        //
        // The Copy + Clone + Send + Sync bounds are load-bearing for:
        //   - LocalAgentCapability::tier/owner/surface fields: stored
        //     by value (not behind a Box / Rc) so the struct stays
        //     Copy-friendly for cheap propagation through the dispatcher.
        //   - Cross-thread routing: the dispatcher reads tier/owner/
        //     surface to decide routing without coordination.
        //   - HashMap dispatch caches (iter-327 pins HashMap usability).
        //
        // A future refactor that made any of these carry a non-Copy
        // payload would silently force a Box/Rc indirection on the
        // hot path — surface here.
        fn assert_copy_clone_send_sync<T: Copy + Clone + Send + Sync>() {}
        assert_copy_clone_send_sync::<LocalAgentCapabilityTier>();
        assert_copy_clone_send_sync::<LocalAgentCapabilityOwner>();
        assert_copy_clone_send_sync::<LocalAgentCapabilitySurface>();

        // Runtime sanity: copy + use both bindings for each enum.
        let t = LocalAgentCapabilityTier::Pro;
        let _ta = t; let _tb = t; assert_eq!(t, t);

        let o = LocalAgentCapabilityOwner::NativeCore;
        let _oa = o; let _ob = o; assert_eq!(o, o);

        let s = LocalAgentCapabilitySurface::AgentTask;
        let _sa = s; let _sb = s; assert_eq!(s, s);
    }

    #[test]
    fn local_agent_tier_owner_surface_hash_consistent_with_eq_usable_as_hashmap_key() {
        // Phase 1 hardening — Hash-derive consistency pin (companion
        // to mode_hash_is_consistent_with_eq_usable_as_hashmap_key
        // iter-321 + stop_reason_hash_is_consistent_with_eq iter-326).
        // All three LocalAgent enums (Tier 3v / Owner 4v / Surface 10v)
        // carry Hash in their derive list; pin that each is usable
        // as a HashMap key and that the variant counts match the
        // ALL[] constant cardinality through HashSet membership.
        //
        // Defends against a future "let me drop Hash to simplify a
        // single derive" refactor across the LocalAgent capability
        // mirror types that would break per-variant tally call sites
        // a dispatcher cache layer would construct.
        use std::collections::{HashMap, HashSet};

        // Tier: 3 variants.
        let tier_set: HashSet<LocalAgentCapabilityTier> =
            LocalAgentCapabilityTier::ALL.iter().copied().collect();
        assert_eq!(tier_set.len(), 3);
        let mut tier_map: HashMap<LocalAgentCapabilityTier, &'static str> = HashMap::new();
        for &t in &LocalAgentCapabilityTier::ALL {
            tier_map.insert(t, t.code());
        }
        assert_eq!(tier_map.len(), 3);
        for &t in &LocalAgentCapabilityTier::ALL {
            assert_eq!(tier_map.get(&t), Some(&t.code()));
        }

        // Owner: 4 variants.
        let owner_set: HashSet<LocalAgentCapabilityOwner> =
            LocalAgentCapabilityOwner::ALL.iter().copied().collect();
        assert_eq!(owner_set.len(), 4);
        let mut owner_map: HashMap<LocalAgentCapabilityOwner, usize> = HashMap::new();
        for (i, &o) in LocalAgentCapabilityOwner::ALL.iter().enumerate() {
            owner_map.insert(o, i);
        }
        assert_eq!(owner_map.len(), 4);
        for (i, &o) in LocalAgentCapabilityOwner::ALL.iter().enumerate() {
            assert_eq!(owner_map.get(&o), Some(&i));
        }

        // Surface: 10 variants.
        let surface_set: HashSet<LocalAgentCapabilitySurface> =
            LocalAgentCapabilitySurface::ALL.iter().copied().collect();
        assert_eq!(surface_set.len(), 10);
        let mut surface_map: HashMap<LocalAgentCapabilitySurface, usize> = HashMap::new();
        for (i, &s) in LocalAgentCapabilitySurface::ALL.iter().enumerate() {
            surface_map.insert(s, i);
        }
        assert_eq!(surface_map.len(), 10);
        for (i, &s) in LocalAgentCapabilitySurface::ALL.iter().enumerate() {
            assert_eq!(surface_map.get(&s), Some(&i));
        }

        // Duplicate-insert no-op (Hash consistent with Eq) — across all 3 enums.
        let mut dup = HashSet::new();
        dup.insert(LocalAgentCapabilityTier::Core);
        dup.insert(LocalAgentCapabilityTier::Core);
        assert_eq!(dup.len(), 1);
    }

    // ── command_token mirrors Swift behaviour ─────────────────────────────────

    #[test]
    fn command_token_strips_angle_and_bracket_placeholders() {
        // Mirrors `LocalAgentCapability.commandToken(from:)` byte-for-byte:
        //   "/todo add <task>" → "/todo add"
        //   "/run <command>"   → "/run"
        //   "/help"            → "/help"
        //   "/kill <pid>"      → "/kill"
        assert_eq!(
            LocalAgentCapability::command_token_from("/todo add <task>"),
            "/todo add"
        );
        assert_eq!(
            LocalAgentCapability::command_token_from("/run <command>"),
            "/run"
        );
        assert_eq!(
            LocalAgentCapability::command_token_from("/help"),
            "/help"
        );
        assert_eq!(
            LocalAgentCapability::command_token_from("/kill <pid>"),
            "/kill"
        );
    }

    #[test]
    fn command_token_handles_empty_whitespace_and_leading_placeholder_edge_cases() {
        // Phase 1 hardening — Swift⇄Rust mirror parity boundary.
        // `LocalAgentCapability.command_token_from` is the byte-equal
        // mirror of the Swift helper; the existing tests cover the
        // normal cases ("/todo add <task>", "/run <command>", etc.)
        // but the four adversarial edge cases below have no pin:
        //
        //   - empty pattern → "" (no panic, no inadvertent prefix)
        //   - whitespace-only pattern → "" (collapsed)
        //   - leading placeholder ("<arg>") → "" (take_while halts at first
        //     element)
        //   - tab-separated tokens → split_whitespace collapses, joins
        //     with a single space (NOT a tab) — pins the canonical
        //     joiner so a future tab-preserving refactor surfaces
        //
        // If Rust drifts from Swift on ANY of these, the cross-FFI
        // bridge silently produces different command_token values
        // and the dispatcher's per-capability lookup breaks.
        assert_eq!(LocalAgentCapability::command_token_from(""), "");
        assert_eq!(LocalAgentCapability::command_token_from("   "), "");
        assert_eq!(LocalAgentCapability::command_token_from("\t\n"), "");
        // Leading placeholder — first whitespace-split token starts
        // with '<' or '[', take_while halts before consuming it.
        assert_eq!(LocalAgentCapability::command_token_from("<arg>"), "");
        assert_eq!(LocalAgentCapability::command_token_from("[opt]"), "");
        assert_eq!(
            LocalAgentCapability::command_token_from("<arg> /never reached"),
            ""
        );
        // Tab-separated tokens collapse + join with single space.
        assert_eq!(
            LocalAgentCapability::command_token_from("/foo\t<bar>"),
            "/foo"
        );
        assert_eq!(
            LocalAgentCapability::command_token_from("/multi\t\ttoken <arg>"),
            "/multi token"
        );
        // Multiple consecutive spaces also collapse to single space.
        assert_eq!(
            LocalAgentCapability::command_token_from("/multi    token   <arg>"),
            "/multi token"
        );
    }

    #[test]
    fn command_token_preserves_glued_placeholders_per_whitespace_split_doctrine() {
        // Phase 1 hardening — Swift⇄Rust mirror parity pin for the
        // "glued placeholder" edge case. command_token_from splits on
        // whitespace; a placeholder GLUED to the command without a
        // separating whitespace boundary (e.g., "/foo<bar>" or
        // "/foo[bar]") is treated as a single token whose first char
        // is '/', NOT '<' or '['. take_while keeps it; the placeholder
        // bytes survive into the output.
        //
        // This is the DOCUMENTED behaviour: callers MUST use whitespace
        // to separate placeholders. The Swift mirror does the same
        // (split_whitespace + take_while). If Rust ever switched to a
        // regex-based stripper that matched inline placeholders, the
        // cross-FFI bridge would silently drift.
        //
        // Pin both the angle and square-bracket glued variants, plus
        // a sanity case with the placeholder both glued AND followed
        // by a space-separated trailing token.
        assert_eq!(
            LocalAgentCapability::command_token_from("/foo<bar>"),
            "/foo<bar>",
            "glued angle placeholder must survive whitespace-split doctrine"
        );
        assert_eq!(
            LocalAgentCapability::command_token_from("/foo[bar]"),
            "/foo[bar]",
            "glued bracket placeholder must survive whitespace-split doctrine"
        );
        // Mixed: glued placeholder + trailing space-separated placeholder.
        // The first token "/foo<a>" survives; the second " <b>" is dropped
        // by take_while since it starts with '<'.
        assert_eq!(
            LocalAgentCapability::command_token_from("/foo<a> <b>"),
            "/foo<a>",
            "glued placeholder kept; subsequent space-separated placeholder dropped"
        );
    }

    #[test]
    fn command_token_strips_square_bracket_placeholders_too() {
        assert_eq!(
            LocalAgentCapability::command_token_from("/foo [opt]"),
            "/foo"
        );
        assert_eq!(
            LocalAgentCapability::command_token_from("/multi token [a] <b>"),
            "/multi token"
        );
    }

    // ── full capability admissibility ─────────────────────────────────────────

    fn shell_capability() -> LocalAgentCapability {
        LocalAgentCapability {
            command_pattern: "/shell".into(),
            surface: LocalAgentCapabilitySurface::AgentTask,
            tier: LocalAgentCapabilityTier::Pro,
            owner: LocalAgentCapabilityOwner::LocalAgentGateway,
            requires_network: false,
            requires_subprocess: true,
            requires_approval: true,
            structured_evidence: true,
            native_equivalent: "LocalAgent interactive shell gateway".into(),
            local_agent_passthrough: false,
        }
    }

    fn ask_capability() -> LocalAgentCapability {
        LocalAgentCapability {
            command_pattern: "/ask <question>".into(),
            surface: LocalAgentCapabilitySurface::AgentTask,
            tier: LocalAgentCapabilityTier::Core,
            owner: LocalAgentCapabilityOwner::NativeCore,
            requires_network: false,
            requires_subprocess: false,
            requires_approval: false,
            structured_evidence: false,
            native_equivalent: "Native note-aware chat/query".into(),
            local_agent_passthrough: true,
        }
    }

    #[test]
    fn local_agent_capability_allowed_in_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series iter-220-235).
        // LocalAgentCapability::allowed_in combines tier check +
        // requires_subprocess flag check. Pure function over
        // immutable &self.
        let cap = shell_capability();
        for mode in [
            AgentRuntimeV2Mode::Disabled,
            AgentRuntimeV2Mode::IpcBounded,
            AgentRuntimeV2Mode::Subprocess,
        ] {
            let r1 = cap.allowed_in(mode);
            let r2 = cap.allowed_in(mode);
            let r3 = cap.allowed_in(mode);
            assert_eq!(r1, r2, "mode {mode:?}: r1 != r2");
            assert_eq!(r2, r3, "mode {mode:?}: r2 != r3");
        }
    }

    #[test]
    fn pro_tier_subprocess_capability_refused_in_ipc_bounded() {
        // requires_subprocess takes precedence — even though Pro tier
        // is allowed in IpcBounded, the subprocess flag forces
        // Subprocess mode.
        let cap = shell_capability();
        assert!(!cap.allowed_in(AgentRuntimeV2Mode::IpcBounded));
        assert!(cap.allowed_in(AgentRuntimeV2Mode::Subprocess));
        assert!(!cap.allowed_in(AgentRuntimeV2Mode::Disabled));
    }

    #[test]
    fn core_tier_no_subprocess_capability_allowed_in_ipc_bounded() {
        let cap = ask_capability();
        assert!(cap.allowed_in(AgentRuntimeV2Mode::IpcBounded));
        assert!(cap.allowed_in(AgentRuntimeV2Mode::Subprocess));
        assert!(!cap.allowed_in(AgentRuntimeV2Mode::Disabled));
    }

    #[test]
    fn capability_allowed_in_exhausts_tier_requires_subprocess_mode_3_way_matrix() {
        // Phase 1 hardening — exhaustive 3-way interaction pin.
        // LocalAgentCapability::allowed_in combines:
        //   tier ∈ {Core, Pro, Research}      (3)
        //   requires_subprocess ∈ {true,false} (2)
        //   mode ∈ {Disabled, IpcBounded, Subprocess} (3)
        // = 18 combinations. The existing fixture tests
        // (pro_tier_subprocess_capability_refused_in_ipc_bounded +
        // core_tier_no_subprocess_capability_allowed_in_ipc_bounded)
        // cover ~6. This pin enumerates ALL 18 and asserts the
        // expected outcome for each — a regression in any one of
        // the corners (e.g., Research+false+IpcBounded silently
        // flipping to true) surfaces deterministically.
        //
        // Doctrine (encoded in fields below):
        //   - Disabled mode → ALWAYS deny (MAS safety invariant)
        //   - Subprocess mode → ALWAYS allow IF tier+flag agree
        //     (tier.allowed_in(Subprocess) is true for all 3 tiers)
        //   - IpcBounded mode → tier-allow + NOT requires_subprocess
        let cases: &[(LocalAgentCapabilityTier, bool, AgentRuntimeV2Mode, bool)] = &[
            // Core tier
            (LocalAgentCapabilityTier::Core, false, AgentRuntimeV2Mode::Disabled, false),
            (LocalAgentCapabilityTier::Core, false, AgentRuntimeV2Mode::IpcBounded, true),
            (LocalAgentCapabilityTier::Core, false, AgentRuntimeV2Mode::Subprocess, true),
            (LocalAgentCapabilityTier::Core, true, AgentRuntimeV2Mode::Disabled, false),
            // Core + requires_subprocess + IpcBounded: tier OK but
            // flag forces Subprocess → deny.
            (LocalAgentCapabilityTier::Core, true, AgentRuntimeV2Mode::IpcBounded, false),
            (LocalAgentCapabilityTier::Core, true, AgentRuntimeV2Mode::Subprocess, true),
            // Pro tier
            (LocalAgentCapabilityTier::Pro, false, AgentRuntimeV2Mode::Disabled, false),
            (LocalAgentCapabilityTier::Pro, false, AgentRuntimeV2Mode::IpcBounded, true),
            (LocalAgentCapabilityTier::Pro, false, AgentRuntimeV2Mode::Subprocess, true),
            (LocalAgentCapabilityTier::Pro, true, AgentRuntimeV2Mode::Disabled, false),
            (LocalAgentCapabilityTier::Pro, true, AgentRuntimeV2Mode::IpcBounded, false),
            (LocalAgentCapabilityTier::Pro, true, AgentRuntimeV2Mode::Subprocess, true),
            // Research tier — tier itself denies IpcBounded.
            (LocalAgentCapabilityTier::Research, false, AgentRuntimeV2Mode::Disabled, false),
            (LocalAgentCapabilityTier::Research, false, AgentRuntimeV2Mode::IpcBounded, false),
            (LocalAgentCapabilityTier::Research, false, AgentRuntimeV2Mode::Subprocess, true),
            (LocalAgentCapabilityTier::Research, true, AgentRuntimeV2Mode::Disabled, false),
            (LocalAgentCapabilityTier::Research, true, AgentRuntimeV2Mode::IpcBounded, false),
            (LocalAgentCapabilityTier::Research, true, AgentRuntimeV2Mode::Subprocess, true),
        ];
        assert_eq!(cases.len(), 18, "must enumerate all 3x2x3 combinations");
        for &(tier, requires_subprocess, mode, expected) in cases {
            let cap = LocalAgentCapability {
                command_pattern: "/matrix-probe".into(),
                surface: LocalAgentCapabilitySurface::AgentTask,
                tier,
                owner: LocalAgentCapabilityOwner::LocalAgentGateway,
                requires_network: false,
                requires_subprocess,
                requires_approval: false,
                structured_evidence: false,
                native_equivalent: String::new(),
                local_agent_passthrough: false,
            };
            assert_eq!(
                cap.allowed_in(mode),
                expected,
                "tier={tier:?} requires_subprocess={requires_subprocess} mode={mode:?} \
                 expected {expected} but got {}",
                cap.allowed_in(mode),
            );
        }
    }

    #[test]
    fn local_agent_capability_struct_field_shape_pinned_to_exactly_ten_typed_fields() {
        // Phase 1 hardening — struct-field-shape pin for
        // LocalAgentCapability (companion to the struct destructure
        // pin family iter-464..iter-467). 10 named fields, the
        // largest user-facing struct in agent_runtime_v2.
        //
        // A future "let me add an `executor_id` field" extension
        // would silently change the on-disk JSON shape AND fork
        // Swift⇄Rust raw-value parity (since LocalAgentCapability
        // is the Swift mirror).
        let cap = ask_capability();
        let LocalAgentCapability {
            command_pattern,
            surface,
            tier,
            owner,
            requires_network,
            requires_subprocess,
            requires_approval,
            structured_evidence,
            native_equivalent,
            local_agent_passthrough,
        } = cap;
        let _: String = command_pattern;
        let _: LocalAgentCapabilitySurface = surface;
        let _: LocalAgentCapabilityTier = tier;
        let _: LocalAgentCapabilityOwner = owner;
        let _: bool = requires_network;
        let _: bool = requires_subprocess;
        let _: bool = requires_approval;
        let _: bool = structured_evidence;
        let _: String = native_equivalent;
        let _: bool = local_agent_passthrough;
    }

    #[test]
    fn every_local_agent_capability_field_is_identity_load_bearing() {
        // Phase 1 hardening — sixth leg of the identity-pin pattern
        // (AgentBlueprint 5, AnswerPacket 7, MissionPacket 3,
        // ToolCall 2, MutationEnvelope 3, LocalAgentCapability 10).
        // LocalAgentCapability is the BIGGEST struct in v2 with 10
        // fields and is the byte-equal mirror of the Swift
        // `LocalAgentCapability` struct. Every field must participate
        // in PartialEq derivation; a silent #[serde(skip)] or
        // PartialEq override dropping any field would silently
        // collapse distinct capabilities AND break Swift↔Rust mirror
        // parity (the Swift side checks identity by struct equality
        // too).
        //
        // The 10 fields: command_pattern, surface, tier, owner,
        // requires_network, requires_subprocess, requires_approval,
        // structured_evidence, native_equivalent, local_agent_passthrough.
        let base = LocalAgentCapability {
            command_pattern: "/probe <x>".into(),
            surface: LocalAgentCapabilitySurface::AgentTask,
            tier: LocalAgentCapabilityTier::Pro,
            owner: LocalAgentCapabilityOwner::LocalAgentGateway,
            requires_network: false,
            requires_subprocess: false,
            requires_approval: false,
            structured_evidence: false,
            native_equivalent: "native probe".into(),
            local_agent_passthrough: false,
        };

        // For each field, mutate exactly one and assert inequality.
        let mut diff_pattern = base.clone();
        diff_pattern.command_pattern = "/other <x>".into();
        assert_ne!(diff_pattern, base, "command_pattern must participate in PartialEq");

        let mut diff_surface = base.clone();
        diff_surface.surface = LocalAgentCapabilitySurface::Session;
        assert_ne!(diff_surface, base, "surface must participate in PartialEq");

        let mut diff_tier = base.clone();
        diff_tier.tier = LocalAgentCapabilityTier::Research;
        assert_ne!(diff_tier, base, "tier must participate in PartialEq");

        let mut diff_owner = base.clone();
        diff_owner.owner = LocalAgentCapabilityOwner::NativeCore;
        assert_ne!(diff_owner, base, "owner must participate in PartialEq");

        let mut diff_net = base.clone();
        diff_net.requires_network = true;
        assert_ne!(diff_net, base, "requires_network must participate in PartialEq");

        let mut diff_sub = base.clone();
        diff_sub.requires_subprocess = true;
        assert_ne!(diff_sub, base, "requires_subprocess must participate in PartialEq");

        let mut diff_app = base.clone();
        diff_app.requires_approval = true;
        assert_ne!(diff_app, base, "requires_approval must participate in PartialEq");

        let mut diff_evidence = base.clone();
        diff_evidence.structured_evidence = true;
        assert_ne!(diff_evidence, base, "structured_evidence must participate in PartialEq");

        let mut diff_native = base.clone();
        diff_native.native_equivalent = "other".into();
        assert_ne!(diff_native, base, "native_equivalent must participate in PartialEq");

        let mut diff_pass = base.clone();
        diff_pass.local_agent_passthrough = true;
        assert_ne!(diff_pass, base, "local_agent_passthrough must participate in PartialEq");

        // Sanity preserved.
        assert_eq!(base.clone(), base);
    }

    #[test]
    fn local_agent_capability_serde_json_preserves_struct_field_declaration_order() {
        // Phase 1 hardening — wire-shape pin extending iter-163
        // (presence + count) with field-order. LocalAgentCapability
        // declares 10 fields:
        //   command_pattern, surface, tier, owner, requires_network,
        //   requires_subprocess, requires_approval, structured_evidence,
        //   native_equivalent, local_agent_passthrough
        //
        // A future reorder breaks the Swift mirror's byte-equal
        // decoding AND breaks dispatcher capability-registry
        // byte-equal cache keys.
        let cap = shell_capability();
        let s = serde_json::to_string(&cap).expect("serialise");
        let expected_keys_in_order = [
            "\"command_pattern\":",
            "\"surface\":",
            "\"tier\":",
            "\"owner\":",
            "\"requires_network\":",
            "\"requires_subprocess\":",
            "\"requires_approval\":",
            "\"structured_evidence\":",
            "\"native_equivalent\":",
            "\"local_agent_passthrough\":",
        ];
        let mut last_idx: Option<usize> = None;
        for key in expected_keys_in_order {
            let pos = s.find(key).unwrap_or_else(|| panic!("key {key} not found in {s}"));
            if let Some(prev) = last_idx {
                assert!(
                    pos > prev,
                    "field {key} at byte {pos} must appear after previous field at {prev}"
                );
            }
            last_idx = Some(pos);
        }
    }

    #[test]
    fn local_agent_capability_serde_json_contains_all_ten_canonical_top_level_keys() {
        // Phase 1 hardening — wire-shape pin matching the established
        // pattern. LocalAgentCapability has 10 top-level fields and
        // is the byte-equal mirror of the Swift LocalAgentCapability
        // struct. A silent rename would round-trip on the Rust side
        // but break Swift bridge readers parsing the same JSON.
        let cap = shell_capability();
        let json = serde_json::to_value(&cap).expect("serialise");
        let obj = json
            .as_object()
            .expect("LocalAgentCapability serialises as JSON object");
        for key in [
            "command_pattern",
            "surface",
            "tier",
            "owner",
            "requires_network",
            "requires_subprocess",
            "requires_approval",
            "structured_evidence",
            "native_equivalent",
            "local_agent_passthrough",
        ] {
            assert!(
                obj.contains_key(key),
                "missing top-level key {key:?} in {json:?}"
            );
        }
        assert_eq!(
            obj.len(),
            10,
            "expected exactly 10 top-level keys, got {} ({:?})",
            obj.len(),
            obj.keys().collect::<Vec<_>>()
        );
    }

    #[test]
    fn local_agent_capability_preserves_json_special_chars_through_serde() {
        // Phase 1 hardening MILESTONE iter-420 — closes the
        // JSON-special-char preservation pin family across the 2
        // String fields in LocalAgentCapability (command_pattern,
        // native_equivalent).
        //
        // Companion to:
        //   - MissionPacket.user_prompt (iter-413)
        //   - AnswerPacket.final_text (iter-414)
        //   - Citation source/locator (iter-415)
        //   - MutationEnvelope.payload (iter-416)
        //   - ToolCall.arguments (iter-417)
        //   - AgentBlueprint.display_name (iter-418)
        //   - AgentBlueprintId (iter-419)
        //   - LocalAgentCapability (this commit)
        //
        // Series total: 8 String/Value-bearing types pinned for
        // JSON-special-char preservation. All major wire-surface
        // String fields in agent_runtime_v2 now carry this guardrail.
        //
        // LocalAgentCapability marshals across the Swift⇄Rust FFI
        // boundary; lossy escaping would silently fork the Swift
        // mirror's understanding of a capability's name.
        let mut cap = ask_capability();
        cap.command_pattern = r#"/cmd "with quotes" <arg>"#.into();
        cap.native_equivalent = "fallback\nwith\nnewlines and \\ backslashes".into();
        let s = serde_json::to_string(&cap).expect("serialise");
        let back: LocalAgentCapability =
            serde_json::from_str(&s).expect("deserialise");
        assert_eq!(back.command_pattern, cap.command_pattern);
        assert_eq!(back.native_equivalent, cap.native_equivalent);
        assert_eq!(back, cap);

        // Tab + quote + JSON-shaped content.
        let mut cap2 = ask_capability();
        cap2.command_pattern = "/cmd\twith\ttabs".into();
        cap2.native_equivalent = r#"{"json": "in native_equivalent"}"#.into();
        let s2 = serde_json::to_string(&cap2).expect("serialise");
        let back2: LocalAgentCapability =
            serde_json::from_str(&s2).expect("deserialise");
        assert_eq!(back2, cap2);
    }

    #[test]
    fn local_agent_capability_serde_preserves_unicode_in_string_fields() {
        // Phase 1 hardening — Unicode safety pin for LocalAgentCapability
        // serde (companion to iter-99 / iter-203 / iter-205 / iter-206 /
        // iter-207 Unicode pins). LocalAgentCapability has two
        // free-form String fields: command_pattern and
        // native_equivalent. Both must survive byte-equal through
        // serde to maintain Swift mirror parity.
        let cap = LocalAgentCapability {
            command_pattern: "/查询 <问题>".into(),
            surface: LocalAgentCapabilitySurface::AgentTask,
            tier: LocalAgentCapabilityTier::Core,
            owner: LocalAgentCapabilityOwner::NativeCore,
            requires_network: false,
            requires_subprocess: false,
            requires_approval: false,
            structured_evidence: false,
            native_equivalent: "ネイティブ chat 機能".into(),
            local_agent_passthrough: true,
        };
        let s = serde_json::to_string(&cap).expect("serialise");
        let back: LocalAgentCapability = serde_json::from_str(&s).expect("deserialise");
        assert_eq!(back, cap);
        assert_eq!(back.command_pattern, "/查询 <问题>");
        assert_eq!(back.native_equivalent, "ネイティブ chat 機能");
        // The literal multi-byte chars appear in the JSON (no
        // \u escape for printable non-ASCII per serde_json default).
        assert!(s.contains("/查询 <问题>"));
        assert!(s.contains("ネイティブ chat 機能"));
    }

    #[test]
    fn capability_round_trips_through_json() {
        let cap = shell_capability();
        let s = serde_json::to_string(&cap).expect("serialize");
        let back: LocalAgentCapability = serde_json::from_str(&s).expect("deserialize");
        assert_eq!(back, cap);
    }

    #[test]
    fn local_agent_capability_serde_tolerates_unknown_extra_fields_per_current_doctrine() {
        // Phase 1 hardening — DOCTRINE PIN with forward-compat teeth.
        // Cross-FFI parity companion to the serde-tolerance pin family
        // across the agent_runtime_v2 user-facing structs
        // (MissionPacket, AnswerPacket, AgentBlueprint, MutationEnvelope,
        // ToolCall, Citation).
        //
        // LocalAgentCapability is the BYTE-EQUAL Swift mirror struct;
        // cross-version Swift⇄Rust JSON parity REQUIRES lenient
        // deserialise. A Swift V2.1 build that added a `metadata` field
        // and emitted JSON to disk must still load back into Rust V1.0
        // that doesn't know about `metadata` — the extra silently
        // drops.
        //
        // Pin the lenient behaviour so a future
        // #[serde(deny_unknown_fields)] addition surfaces at PR review
        // as a deliberate doctrine change (especially load-bearing
        // here because Swift mirror parity is the EXPLICIT contract).
        let cap = ask_capability();
        let s = serde_json::to_string(&cap).expect("serialise");
        let last_brace = s.rfind('}').expect("trailing brace");
        let mut augmented = String::with_capacity(s.len() + 50);
        augmented.push_str(&s[..last_brace]);
        augmented.push_str(r#","metadata":{"swift_v2":true}}"#);
        let parsed: LocalAgentCapability =
            serde_json::from_str(&augmented).expect("unknown field tolerated");
        assert_eq!(parsed, cap);
    }

    #[test]
    fn capability_command_token_equals_command_token_from_static_helper() {
        // Phase 1 hardening — cross-helper consistency pin.
        // LocalAgentCapability::command_token() delegates to the
        // static `command_token_from(&self.command_pattern)`. Both
        // helpers must produce identical results for any input —
        // the instance helper is the canonical thin wrapper.
        //
        // The existing capability_command_token_uses_instance_pattern
        // covers a single fixture; this pins the equivalence across
        // a sweep of representative patterns including edge cases
        // already pinned for the static helper (iter-83).
        let patterns = [
            "/ask <question>",
            "/todo add <task>",
            "/run <command>",
            "/help",
            "/multi token [a] <b>",
            "/kill <pid>",
            // Edge cases from iter-83:
            "",
            "   ",
            "<arg>",
            "/foo\t<bar>",
        ];
        for pattern in patterns {
            let cap = LocalAgentCapability {
                command_pattern: pattern.to_string(),
                surface: LocalAgentCapabilitySurface::AgentTask,
                tier: LocalAgentCapabilityTier::Core,
                owner: LocalAgentCapabilityOwner::NativeCore,
                requires_network: false,
                requires_subprocess: false,
                requires_approval: false,
                structured_evidence: false,
                native_equivalent: String::new(),
                local_agent_passthrough: false,
            };
            assert_eq!(
                cap.command_token(),
                LocalAgentCapability::command_token_from(pattern),
                "instance and static helpers must agree on pattern {pattern:?}"
            );
        }
    }

    #[test]
    fn capability_command_token_is_pure_deterministic_across_multiple_calls() {
        // Phase 1 hardening — pure-function determinism pin
        // (companion to the purity series iter-220-236).
        // LocalAgentCapability::command_token delegates to the
        // static helper; the underlying split_whitespace + take_while
        // pipeline is pure.
        let cap = ask_capability();
        let r1 = cap.command_token();
        let r2 = cap.command_token();
        let r3 = cap.command_token();
        assert_eq!(r1, r2);
        assert_eq!(r2, r3);
        assert_eq!(r1, "/ask");
        // Static helper is also deterministic.
        let s1 = LocalAgentCapability::command_token_from("/todo add <task>");
        let s2 = LocalAgentCapability::command_token_from("/todo add <task>");
        let s3 = LocalAgentCapability::command_token_from("/todo add <task>");
        assert_eq!(s1, s2);
        assert_eq!(s2, s3);
        assert_eq!(s1, "/todo add");
    }

    #[test]
    fn capability_command_token_uses_instance_pattern() {
        let cap = ask_capability();
        assert_eq!(cap.command_token(), "/ask");
    }

    #[test]
    fn capability_command_token_handles_empty_instance_pattern_per_doctrine() {
        // Phase 1 hardening — boundary completeness pin for the
        // instance-method companion to
        // command_token_handles_empty_whitespace_and_leading_placeholder_edge_cases
        // (which exercises the static command_token_from helper).
        //
        // A LocalAgentCapability with command_pattern = "" must
        // produce the empty command_token "" (Swift mirror parity).
        // The instance method delegates to the static helper, which
        // returns "" for the empty input.
        //
        // A LocalAgentCapability is a struct that COULD be constructed
        // with an empty command_pattern through a Swift-side
        // marshaller bug or a future fixture; the helper must NOT
        // panic and must return "" verbatim.
        let mut cap = ask_capability();
        cap.command_pattern = String::new();
        assert_eq!(cap.command_token(), "", "empty pattern must yield empty token");

        // Whitespace-only pattern: same result.
        cap.command_pattern = "   ".into();
        assert_eq!(cap.command_token(), "");

        // Pattern that's only a placeholder: take_while halts before
        // consuming, result is "".
        cap.command_pattern = "<arg>".into();
        assert_eq!(cap.command_token(), "");
    }

    #[test]
    fn local_agent_adapter_is_clone_send_sync_for_propagation_safety() {
        // Phase 1 hardening — trait-bound pin for LocalAgentAdapter.
        // Companion to the trait-bound sweep across the user-facing
        // types in agent_runtime_v2 (iter-366..iter-386).
        //
        // LocalAgentAdapter: zero-sized scaffold (unit struct with
        // PhantomData-equivalent state). Clone + Default by derive
        // (local_agent.rs §224). Not Copy by derive choice — keep
        // the construction call explicit while the dispatcher seam
        // lands in a later iteration.
        //
        // Send + Sync are load-bearing — the adapter will eventually
        // be held in a static / Lazy across the dispatcher's thread
        // pool. Pin the property now so the future dispatch impl
        // doesn't accidentally introduce a !Send field.
        fn assert_clone_send_sync<T: Clone + Send + Sync>() {}
        assert_clone_send_sync::<LocalAgentAdapter>();

        let a = LocalAgentAdapter::new();
        let _ = a.clone();
    }

    #[test]
    fn local_agent_adapter_default_equals_new_compile_and_runtime_pin() {
        // Phase 1 hardening — Default-vs-new equivalence pin for
        // LocalAgentAdapter (companion to
        // identity_para_default_equals_identity_para_new_compile_and_runtime_pin
        // iter-? for the parallel pin on IdentityPara).
        //
        // LocalAgentAdapter derives Default + has a `const fn new()`.
        // Both must produce structurally equivalent values; a future
        // Default impl that drifted from new() would silently change
        // the canonical constructor's behaviour for callers using
        // #[derive(Default)] on structures containing LocalAgentAdapter.
        let via_default = LocalAgentAdapter::default();
        let via_new = LocalAgentAdapter::new();
        // The struct is zero-sized; both reach the same canonical
        // value. Format equality via Debug to surface any drift.
        assert_eq!(format!("{via_default:?}"), format!("{via_new:?}"));
    }

    #[test]
    fn adapter_constructs_via_new() {
        let _adapter = LocalAgentAdapter::new();
    }
}
