//! UAS — Unified Active Substrate.
//!
//! Source:
//! - `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md` §4.G hierarchy LOCK
//!   (BODY layer: "identity != residency; every artifact addressable independent
//!   of where it lives").
//! - Canonical doctrine: `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md`
//!   §1 umbrella name LOCK + §2 hierarchy LOCK + §5 register rows #1 / #2 / #3.
//! - Phase B blueprint: `docs/audits/UAS_ACS_PHASE_B_BLUEPRINT_2026_05_17.md` §2.1
//!   iter 21.
//!
//! # Phase B.G.B1.a — iter 21
//!
//! Lands `UasAddress` as the substrate-floor identity primitive. Every UAS-
//! addressed artifact (vault note · graph node · KV page · model component ·
//! agent trace · tool result · AnswerPacket) carries a `UasAddress` that lookup
//! resolves regardless of residency (RAM hot · RAM warm · SSD cold · cloud).
//!
//! Iter 22 expands `UasKind` to the full variant set (currently a `Placeholder`
//! stub pending T1 review per
//! `docs/audits/UAS_ACS_T_TERMINAL_COORDINATION_2026_05_17.md` §2).
//!
//! Iter 23 adds `residency_tier.rs` with the §4.G three-tier shipping-policy
//! axis (Current App / Verified Floor / Capability Ceiling). The future
//! `residency_tier.rs` MUST carry a reciprocal tail comment pointing at
//! `scope_rex::residency::Residency` (cognitive-state-placement axis) per
//! canonical doctrine §3.1 anti-drift LOCK.
//!
//! Iter 24 adds `ResidencyLease`.

use serde::{Deserialize, Serialize};

pub mod address;

pub use address::{UasAddress, UasAddressParseError};

/// Substrate-typed identity tag.
///
/// **ITER 21 PLACEHOLDER.** Full variant set lands iter 22 after T1 review.
/// Initial proposed variants documented in
/// `docs/audits/UAS_ACS_T_TERMINAL_COORDINATION_2026_05_17.md` §2:
/// `VaultNote` · `GraphNode` · `KvPage` · `ModelComponent` · `AgentTrace` ·
/// `ToolResult` · `AnswerPacket` · `TriFusionBlock` · `Other(SmolStr)`.
///
/// The `Other` escape hatch is the forward-compat anchor so iter 22's expansion
/// does not require lockstep updates in downstream consumers (e.g. the
/// F-UAS-ZeroCopy-Spine harness landing iter 27-31).
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UasKind {
    /// Placeholder; replaced with the full variant set in iter 22 (T1 review
    /// pending per coord doc §2).
    Placeholder,
}

impl UasKind {
    /// Stable wire-format tag for inclusion in `UasAddress::Display`.
    pub fn wire_tag(&self) -> &'static str {
        match self {
            UasKind::Placeholder => "placeholder",
        }
    }

    /// Inverse of `wire_tag`. Returns `None` for unknown tags so the parser can
    /// surface a typed error.
    pub fn from_wire_tag(s: &str) -> Option<Self> {
        match s {
            "placeholder" => Some(UasKind::Placeholder),
            _ => None,
        }
    }
}
