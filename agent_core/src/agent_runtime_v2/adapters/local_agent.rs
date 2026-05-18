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
    fn local_agent_tier_codes_match_swift_raw_values() {
        assert_eq!(LocalAgentCapabilityTier::Core.code(), "core");
        assert_eq!(LocalAgentCapabilityTier::Pro.code(), "pro");
        assert_eq!(LocalAgentCapabilityTier::Research.code(), "research");
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
    fn surface_enumerates_all_ten_swift_variants() {
        assert_eq!(LocalAgentCapabilitySurface::ALL.len(), 10);
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
    fn capability_round_trips_through_json() {
        let cap = shell_capability();
        let s = serde_json::to_string(&cap).expect("serialize");
        let back: LocalAgentCapability = serde_json::from_str(&s).expect("deserialize");
        assert_eq!(back, cap);
    }

    #[test]
    fn capability_command_token_uses_instance_pattern() {
        let cap = ask_capability();
        assert_eq!(cap.command_token(), "/ask");
    }

    #[test]
    fn adapter_constructs_via_new() {
        let _adapter = LocalAgentAdapter::new();
    }
}
