//! `LocalAgentAdapter` — Rust mirror of the read-only
//! `Epistemos/LocalAgent/LocalAgentCapabilityRegistry.swift` typed
//! capability surface, surfaced through the v2 namespace.
//!
//! **Scaffold-only (iter-16 / W-46 phase 2 kickoff).** The real
//! adapter lands in iter-17 once the legacy registry's tier/owner/
//! surface vocabulary is enumerated here in Rust. This stub fixes
//! the type shape + one failing assertion that codifies the
//! invariant the iter-17 work must satisfy: the Rust tier enum
//! must enumerate the same three legacy tiers (core/pro/research)
//! so the bridge layer can translate without runtime branches.

use serde::{Deserialize, Serialize};

/// Tier mirror of the Swift-side `LocalAgentCapabilityTier`. Names
/// match the Swift `String` raw values exactly so the bridge can
/// round-trip via JSON without translation.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum LocalAgentCapabilityTier {
    Core,
    Pro,
    Research,
}

impl LocalAgentCapabilityTier {
    /// Every tier the legacy registry knows about. Used by the
    /// invariant test below; iter-17 callers iterate this slice
    /// when populating the v2 capability surface from a blueprint.
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
}

/// Placeholder. iter-17 fills it with the typed capability handle the
/// dispatcher consumes. For iter-16 the only contract is that the
/// struct exists in the v2 namespace and the tier enum mirrors the
/// legacy three values.
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

    #[test]
    fn local_agent_tier_mirror_enumerates_all_three_legacy_tiers() {
        // Iter-16 W-46 phase-2 kickoff invariant: the Rust tier enum
        // MUST enumerate the same three tiers the Swift registry
        // (LocalAgentCapabilityRegistry.swift) knows about — Core,
        // Pro, Research. iter-17 builds the actual adapter behaviour
        // on top of this guarantee.
        assert_eq!(LocalAgentCapabilityTier::ALL.len(), 3);
        assert!(LocalAgentCapabilityTier::ALL.contains(&LocalAgentCapabilityTier::Core));
        assert!(LocalAgentCapabilityTier::ALL.contains(&LocalAgentCapabilityTier::Pro));
        assert!(LocalAgentCapabilityTier::ALL.contains(&LocalAgentCapabilityTier::Research));
    }

    #[test]
    fn local_agent_tier_codes_match_swift_raw_values() {
        // Cross-language stability: codes must match the
        // `LocalAgentCapabilityTier: String, CaseIterable` raw values
        // in LocalAgentCapabilityRegistry.swift exactly.
        assert_eq!(LocalAgentCapabilityTier::Core.code(), "core");
        assert_eq!(LocalAgentCapabilityTier::Pro.code(), "pro");
        assert_eq!(LocalAgentCapabilityTier::Research.code(), "research");
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

    #[test]
    fn adapter_constructs_via_new() {
        let _adapter = LocalAgentAdapter::new();
    }
}
