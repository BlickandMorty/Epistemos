//! `AcsAnchor` — typed ACS coordinate object.
//!
//! Source:
//! - Driver §4.G mission G.B3 acceptance: "typed anchor (theorem tag · plane
//!   coord · residency tier · source hash · active packet id) round-trips
//!   through agent runtime + lookup + audit + projection without silent
//!   loss."
//! - Canonical doctrine `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md`
//!   §5 register row #5 (ACS Anchor) + §2 hierarchy ACS = "COORDINATE SYSTEM
//!   — typed anchors with provenance, theorem labels, plane coordinates,
//!   residency tier."
//! - F-ACS-Anchor-Addressing falsifier `docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md`
//!   §2 (AcsAnchor proposed shape).
//! - Phase B blueprint `docs/audits/UAS_ACS_PHASE_B_BLUEPRINT_2026_05_17.md`
//!   §2.3 iter 32 → landed at iter 27 (reordered; F-UAS-ZeroCopy-Spine
//!   path-1 test deferred pending allocator-counter infrastructure slice).
//!
//! # Phase B.G.B3.a — iter 27 (reordered)
//!
//! Lands the typed-anchor surface that F-ACS-Anchor-Addressing exercises in
//! its 4-stage round trip (agent runtime → lookup → audit → projection).

use blake3::Hash;
use serde::{Deserialize, Serialize};

use crate::uas::{ResidencyTier, UasAddress};

/// Local mirror of the V6.1 §3 five-plane formalism.
///
/// **Drift gate**: this enum MUST match `epistemos_research::five_planes::
/// RuntimePlane` variant-for-variant. The local mirror exists because
/// `agent_core` does not depend on `epistemos-research`. A drift-gate test
/// (`five_planes_local_mirror_matches_v6_1_canon`) locks the variant set +
/// wire tags; renaming any variant must update both sides in lockstep.
///
/// V6.1 §3 plane LOCK (numbers 1..5 fixed):
/// - 1 State (recurrent semantic spine)
/// - 2 Episodic (exact recall pages / Atlas / provenance ClaimLedger)
/// - 3 Assembly (runtime routing / Gate3 / cortical packets)
/// - 4 Controller (executive surfaces)
/// - 5 Verification (audit substrate / WBO / AnswerPacket / ReplayBundle)
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AcsPlane {
    State,
    Episodic,
    Assembly,
    Controller,
    Verification,
}

impl AcsPlane {
    /// Plane number per V6.1 §3 numbering. LOCKed; renumbering requires a
    /// canonical-doctrine revision per [[feedback_plan_is_authority]].
    pub const fn plane_number(self) -> u32 {
        match self {
            AcsPlane::State => 1,
            AcsPlane::Episodic => 2,
            AcsPlane::Assembly => 3,
            AcsPlane::Controller => 4,
            AcsPlane::Verification => 5,
        }
    }

    /// Stable wire-format tag.
    pub const fn wire_tag(self) -> &'static str {
        match self {
            AcsPlane::State => "state",
            AcsPlane::Episodic => "episodic",
            AcsPlane::Assembly => "assembly",
            AcsPlane::Controller => "controller",
            AcsPlane::Verification => "verification",
        }
    }

    /// Inverse of `wire_tag`. NO escape hatch — the 5 planes are V6.1 §3
    /// LOCKed.
    pub fn from_wire_tag(s: &str) -> Option<Self> {
        match s {
            "state" => Some(AcsPlane::State),
            "episodic" => Some(AcsPlane::Episodic),
            "assembly" => Some(AcsPlane::Assembly),
            "controller" => Some(AcsPlane::Controller),
            "verification" => Some(AcsPlane::Verification),
            _ => None,
        }
    }
}

/// Custom serde adapter for `blake3::Hash` (mirrors `uas::address::serde_blake3_hash`).
mod serde_blake3_hash {
    use blake3::Hash;
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S: Serializer>(h: &Hash, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&h.to_hex().to_string())
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<Hash, D::Error> {
        let hex = String::deserialize(d)?;
        Hash::from_hex(&hex).map_err(serde::de::Error::custom)
    }
}

/// Typed ACS coordinate object.
///
/// Per F-ACS-Anchor-Addressing §2: an anchor carries the theorem-tag the
/// claim is anchored to (e.g. "E2" for sheaf-gluing), the V6.1 plane it
/// lives in, the §4.G shipping-policy tier, a content-hash of the source
/// bytes the claim derives from, and (optionally) the AnswerPacket
/// emission id that produced it.
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct AcsAnchor {
    /// Theorem id this claim is anchored to (e.g. "E1", "E2", ..., "PCF-5").
    /// `None` if not theorem-anchored. Matches the `internal_id` taxonomy in
    /// `epistemos_research::theorem_status::TheoremStatusEntry`.
    pub theorem_tag: Option<String>,

    /// V6.1 plane coordinate (LOCKed by `AcsPlane`).
    pub plane: AcsPlane,

    /// §4.G shipping-policy tier (LOCKed by `crate::uas::ResidencyTier`).
    pub tier: ResidencyTier,

    /// BLAKE3 hash of the source bytes the claim derives from.
    #[serde(with = "serde_blake3_hash")]
    pub source_hash: Hash,

    /// SCOPE-Rex AnswerPacket emission id that produced this anchor.
    /// `None` if the anchor was filed outside the AnswerPacket emission path.
    pub active_packet_id: Option<u64>,

    /// UAS address of the artifact this anchor coordinates.
    pub address: UasAddress,
}

impl AcsAnchor {
    /// Construct a new anchor.
    pub fn new(
        address: UasAddress,
        plane: AcsPlane,
        tier: ResidencyTier,
        source_bytes: &[u8],
    ) -> Self {
        Self {
            theorem_tag: None,
            plane,
            tier,
            source_hash: blake3::hash(source_bytes),
            active_packet_id: None,
            address,
        }
    }

    /// Attach a theorem-tag anchor (e.g. "E2") to this anchor. Chainable.
    pub fn with_theorem(mut self, tag: impl Into<String>) -> Self {
        self.theorem_tag = Some(tag.into());
        self
    }

    /// Attach an active AnswerPacket emission id. Chainable.
    pub fn with_active_packet(mut self, id: u64) -> Self {
        self.active_packet_id = Some(id);
        self
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::UasKind;

    fn sample_address() -> UasAddress {
        UasAddress::new(UasKind::GraphNode, b"anchor-test", 0)
    }

    #[test]
    fn anchor_round_trip_serde() {
        let addr = sample_address();
        let anchor = AcsAnchor::new(addr, AcsPlane::Episodic, ResidencyTier::CurrentApp, b"source")
            .with_theorem("E2")
            .with_active_packet(42);
        let json = serde_json::to_string(&anchor).expect("serialize must succeed");
        let parsed: AcsAnchor = serde_json::from_str(&json).expect("deserialize must succeed");
        assert_eq!(anchor, parsed);
        assert_eq!(parsed.theorem_tag.as_deref(), Some("E2"));
        assert_eq!(parsed.plane, AcsPlane::Episodic);
        assert_eq!(parsed.tier, ResidencyTier::CurrentApp);
        assert_eq!(parsed.active_packet_id, Some(42));
    }

    #[test]
    fn anchor_without_theorem_or_packet_round_trips() {
        let addr = sample_address();
        let anchor = AcsAnchor::new(addr, AcsPlane::Verification, ResidencyTier::VerifiedFloor, b"x");
        let json = serde_json::to_string(&anchor).expect("serialize must succeed");
        let parsed: AcsAnchor = serde_json::from_str(&json).expect("deserialize must succeed");
        assert_eq!(anchor, parsed);
        assert!(parsed.theorem_tag.is_none());
        assert!(parsed.active_packet_id.is_none());
    }

    /// Drift gate vs `epistemos_research::five_planes::RuntimePlane`. If the
    /// upstream V6.1 §3 plane LOCK changes, this enum must be updated in
    /// lockstep. This test breaks if a variant is renamed or removed.
    #[test]
    fn five_planes_local_mirror_matches_v6_1_canon() {
        let planes = [
            (AcsPlane::State, 1u32, "state"),
            (AcsPlane::Episodic, 2, "episodic"),
            (AcsPlane::Assembly, 3, "assembly"),
            (AcsPlane::Controller, 4, "controller"),
            (AcsPlane::Verification, 5, "verification"),
        ];
        assert_eq!(planes.len(), 5, "V6.1 §3 five-plane LOCK");
        for (variant, num, tag) in planes {
            assert_eq!(variant.plane_number(), num);
            assert_eq!(variant.wire_tag(), tag);
            assert_eq!(AcsPlane::from_wire_tag(tag), Some(variant));
        }
        assert_eq!(AcsPlane::from_wire_tag("unknown_plane"), None);
    }

    #[test]
    fn source_hash_is_blake3_32_bytes() {
        let anchor = AcsAnchor::new(sample_address(), AcsPlane::State, ResidencyTier::CurrentApp, b"x");
        assert_eq!(anchor.source_hash.as_bytes().len(), 32);
    }

    #[test]
    fn distinct_source_distinct_hash() {
        let a = AcsAnchor::new(sample_address(), AcsPlane::State, ResidencyTier::CurrentApp, b"a");
        let b = AcsAnchor::new(sample_address(), AcsPlane::State, ResidencyTier::CurrentApp, b"b");
        assert_ne!(a.source_hash, b.source_hash);
        assert_ne!(a, b);
    }

    #[test]
    fn with_theorem_is_chainable_and_round_trips() {
        let anchor = AcsAnchor::new(sample_address(), AcsPlane::Assembly, ResidencyTier::VerifiedFloor, b"x")
            .with_theorem("PCF-5")
            .with_active_packet(1234);
        assert_eq!(anchor.theorem_tag.as_deref(), Some("PCF-5"));
        assert_eq!(anchor.active_packet_id, Some(1234));
    }
}
