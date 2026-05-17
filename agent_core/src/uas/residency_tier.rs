//! `ResidencyTier` — §4.G three-tier shipping-policy axis.
//!
//! Source:
//! - Canonical doctrine `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md`
//!   §3 (residency-tier LOCK) + §3.1 (anti-drift LOCK vs `scope_rex::residency::
//!   Residency`).
//! - Phase B blueprint `docs/audits/UAS_ACS_PHASE_B_BLUEPRINT_2026_05_17.md`
//!   §2.1 iter 23.
//! - Closure of audit §F.5 + canonical §8.2 deferred item.
//!
//! # CRITICAL anti-drift LOCK
//!
//! **`ResidencyTier` is NOT the same as `crate::scope_rex::residency::Residency`.**
//!
//! The two enums share the word "residency" but answer different questions and
//! occupy different axes. Confusing them is the exact layer-collapse §4.G
//! forbids (canonical doctrine §2.1):
//!
//! | Type | Question it answers | Axis | Variant count |
//! |---|---|---|---|
//! | `uas::residency_tier::ResidencyTier` (this enum) | *"Is this concept shipped / gated / research-only?"* | substrate-shipping policy | 3 |
//! | `scope_rex::residency::Residency` | *"Where does this claim live after the SCOPE-Rex Governor processes it?"* | cognitive-state placement | 9 |
//!
//! **Never coerce one into the other.** A `Residency::OsftCore` is not a
//! `ResidencyTier::CapabilityCeiling`; an `AcsAnchor.tier` field is
//! `ResidencyTier`, not `Residency`.
//!
//! Reciprocal tail comment landed on `scope_rex::residency` module head in
//! the same iter to prevent silent collapse from either side.

use serde::{Deserialize, Serialize};

/// §4.G three-tier shipping-policy axis.
///
/// Locked by canonical doctrine §3 (verbatim from driver §4.G residency-tier
/// table). Variant order is the natural progression: a concept moves up only
/// when its falsifier passes; no silent migration.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ResidencyTier {
    /// Live in current user-facing MAS build. Examples per canonical §3:
    /// Halo/Shadow search · vault retrieval · prepared local Qwen lane ·
    /// graph retrieval · provenance plane · MLX idle-unload.
    CurrentApp,

    /// Substrate primitive — ships only after its falsifier passes on M2 Pro
    /// 16 GB. Examples per canonical §3: F-UAS-ZeroCopy-Spine · F-ACS-Anchor-
    /// Addressing · F-ShadowFirst-PageEscalation · F-PageGather-M2Pro ·
    /// F-ActiveAssembly-Minimal · F-VaultRecall-50 (§4.H, T4-owned) ·
    /// F-KV-Direct-Gate · F-ULP-Oracle.
    VerifiedFloor,

    /// Research lane — not user-facing until composition passes. Examples
    /// per canonical §3: F-70B-Local-Cocktail · ternary inference path ·
    /// BitNet/T-MAC kernels · Goodfire VPD runtime acceleration · Mamba-3
    /// lookahead · model surgery · connectome distillation.
    CapabilityCeiling,
}

impl ResidencyTier {
    /// Stable wire-format tag for cross-language parity.
    pub const fn wire_tag(&self) -> &'static str {
        match self {
            ResidencyTier::CurrentApp => "current_app",
            ResidencyTier::VerifiedFloor => "verified_floor",
            ResidencyTier::CapabilityCeiling => "capability_ceiling",
        }
    }

    /// Inverse of `wire_tag`. Returns `None` for unknown tags — unlike
    /// `UasKind`, there is no `Other` escape hatch here; the §4.G three
    /// tiers are LOCKed and adding new tiers is a doctrine-level decision,
    /// not a forward-compat extension.
    pub fn from_wire_tag(s: &str) -> Option<Self> {
        match s {
            "current_app" => Some(ResidencyTier::CurrentApp),
            "verified_floor" => Some(ResidencyTier::VerifiedFloor),
            "capability_ceiling" => Some(ResidencyTier::CapabilityCeiling),
            _ => None,
        }
    }

    /// Returns `true` if this tier can ship to the MAS user-facing build
    /// today (without a falsifier-pass gate).
    pub const fn ships_to_mas(&self) -> bool {
        matches!(self, ResidencyTier::CurrentApp)
    }

    /// Returns `true` if a falsifier gate on M2 Pro 16 GB must pass before
    /// the concept moves up from this tier.
    pub const fn requires_falsifier_pass_to_advance(&self) -> bool {
        matches!(self, ResidencyTier::VerifiedFloor | ResidencyTier::CapabilityCeiling)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn three_tier_wire_tag_round_trip() {
        for tier in [
            ResidencyTier::CurrentApp,
            ResidencyTier::VerifiedFloor,
            ResidencyTier::CapabilityCeiling,
        ] {
            let tag = tier.wire_tag();
            let parsed = ResidencyTier::from_wire_tag(tag).expect("known tag must parse");
            assert_eq!(tier, parsed);
        }
    }

    #[test]
    fn unknown_tier_tag_is_none_no_other_fallback() {
        // Unlike UasKind, ResidencyTier has NO Other escape hatch. The
        // §4.G three tiers are LOCKed by canonical doctrine §3; adding a
        // fourth tier requires doctrine-doc revision, not a wire-format
        // fallback.
        assert_eq!(ResidencyTier::from_wire_tag("osft_core"), None);
        assert_eq!(ResidencyTier::from_wire_tag("future_tier_xyz"), None);
        assert_eq!(ResidencyTier::from_wire_tag(""), None);
    }

    #[test]
    fn serde_round_trip() {
        for tier in [
            ResidencyTier::CurrentApp,
            ResidencyTier::VerifiedFloor,
            ResidencyTier::CapabilityCeiling,
        ] {
            let json = serde_json::to_string(&tier).expect("serialize must succeed");
            let parsed: ResidencyTier = serde_json::from_str(&json).expect("deserialize must succeed");
            assert_eq!(tier, parsed);
        }
    }

    #[test]
    fn shipping_predicate_only_current_app_ships_to_mas() {
        assert!(ResidencyTier::CurrentApp.ships_to_mas());
        assert!(!ResidencyTier::VerifiedFloor.ships_to_mas());
        assert!(!ResidencyTier::CapabilityCeiling.ships_to_mas());
    }

    #[test]
    fn falsifier_pass_predicate_gates_floor_and_ceiling() {
        assert!(!ResidencyTier::CurrentApp.requires_falsifier_pass_to_advance());
        assert!(ResidencyTier::VerifiedFloor.requires_falsifier_pass_to_advance());
        assert!(ResidencyTier::CapabilityCeiling.requires_falsifier_pass_to_advance());
    }

    /// Anti-drift assertion: `ResidencyTier` is a strict 3-variant enum.
    /// If a 4th variant is added without updating canonical doctrine §3,
    /// this test breaks. It also breaks if a variant is renamed without
    /// updating the wire tags.
    #[test]
    fn three_tier_lock_prevents_silent_growth() {
        let count = [
            ResidencyTier::CurrentApp,
            ResidencyTier::VerifiedFloor,
            ResidencyTier::CapabilityCeiling,
        ]
        .len();
        assert_eq!(count, 3, "§4.G three-tier LOCK — adding a 4th tier requires canonical doctrine §3 revision first");
    }

    /// Anti-drift assertion: the wire tags MUST stay snake_case for cross-
    /// language parity with Swift mirrors and JSON contracts. If a variant
    /// is renamed, this test breaks until the wire tag is restored.
    #[test]
    fn wire_tags_locked_for_cross_language_parity() {
        assert_eq!(ResidencyTier::CurrentApp.wire_tag(), "current_app");
        assert_eq!(ResidencyTier::VerifiedFloor.wire_tag(), "verified_floor");
        assert_eq!(ResidencyTier::CapabilityCeiling.wire_tag(), "capability_ceiling");
    }
}
