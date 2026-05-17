//! `AnchorRegistry` — in-memory lookup primitives for `AcsAnchor`.
//!
//! Source:
//! - Driver §4.G mission G.B3 acceptance: anchors must "round-trip through
//!   agent runtime + lookup + audit + projection without silent loss."
//! - F-ACS-Anchor-Addressing falsifier `docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md`
//!   §3 Stage 2 (lookup) + Stage 4 (projection onto V6.1 5-plane).
//! - Phase B blueprint `docs/audits/UAS_ACS_PHASE_B_BLUEPRINT_2026_05_17.md`
//!   §2.3 iter 33 → landed at iter 28 (reordered alongside iter 27).
//!
//! # Phase B.G.B3.b — iter 28
//!
//! Lands the substrate-floor registry that lookup-by-UasAddress + lookup-via-
//! projection consume in the F-ACS-Anchor 4-stage harness (iter 29).

use std::collections::HashMap;

use crate::research::acs::anchor::{AcsAnchor, AcsPlane};
use crate::uas::{ResidencyTier, UasAddress};

/// In-memory anchor registry.
///
/// Substrate-floor — single-threaded, no persistence. Cross-thread access
/// must wrap the registry in `RwLock` at the caller. Production storage
/// (GRDB / on-disk) lands in a follow-up iter once the F-ACS-Anchor harness
/// confirms the API surface is right.
#[derive(Default, Debug)]
pub struct AnchorRegistry {
    by_address: HashMap<UasAddress, AcsAnchor>,
}

impl AnchorRegistry {
    pub fn new() -> Self {
        Self::default()
    }

    /// Register an anchor. Returns the previous anchor at the same
    /// `UasAddress` if one was registered (allows replace-with-warning
    /// at the caller). Per F-ACS-Anchor §3 Stage 1 (agent runtime emission).
    pub fn register(&mut self, anchor: AcsAnchor) -> Option<AcsAnchor> {
        self.by_address.insert(anchor.address.clone(), anchor)
    }

    /// Stage 2 lookup — `UasAddress → AcsAnchor`. Returns `None` if no
    /// anchor was registered for the given address.
    pub fn lookup(&self, address: &UasAddress) -> Option<&AcsAnchor> {
        self.by_address.get(address)
    }

    /// Stage 4 projection — `(plane, residency) → set of matching anchors`.
    /// The projection is set-valued because multiple anchors can sit in the
    /// same (plane, tier) coordinate; the F-ACS-Anchor §6 Tier-3 mitigation
    /// notes this is the canonical disambiguation strategy.
    pub fn project(&self, plane: AcsPlane, tier: ResidencyTier) -> Vec<&AcsAnchor> {
        self.by_address
            .values()
            .filter(|a| a.plane == plane && a.tier == tier)
            .collect()
    }

    /// Theorem-tag filter (e.g. all anchors tagged "E2").
    pub fn by_theorem<'a>(&'a self, tag: &str) -> Vec<&'a AcsAnchor> {
        self.by_address
            .values()
            .filter(|a| a.theorem_tag.as_deref() == Some(tag))
            .collect()
    }

    /// Active-packet filter (every anchor produced by a given AnswerPacket
    /// emission id).
    pub fn by_active_packet(&self, id: u64) -> Vec<&AcsAnchor> {
        self.by_address
            .values()
            .filter(|a| a.active_packet_id == Some(id))
            .collect()
    }

    /// Number of registered anchors.
    pub fn len(&self) -> usize {
        self.by_address.len()
    }

    /// `true` iff no anchors are registered.
    pub fn is_empty(&self) -> bool {
        self.by_address.is_empty()
    }

    /// Iterator over every registered anchor.
    pub fn iter(&self) -> impl Iterator<Item = &AcsAnchor> {
        self.by_address.values()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::UasKind;

    fn anchor(content: &[u8], plane: AcsPlane, tier: ResidencyTier, theorem: Option<&str>, packet: Option<u64>) -> AcsAnchor {
        let addr = UasAddress::new(UasKind::GraphNode, content, 0);
        let mut a = AcsAnchor::new(addr, plane, tier, content);
        if let Some(t) = theorem { a = a.with_theorem(t); }
        if let Some(p) = packet { a = a.with_active_packet(p); }
        a
    }

    #[test]
    fn registry_starts_empty() {
        let r = AnchorRegistry::new();
        assert!(r.is_empty());
        assert_eq!(r.len(), 0);
    }

    #[test]
    fn register_then_lookup() {
        let mut r = AnchorRegistry::new();
        let a = anchor(b"x", AcsPlane::Episodic, ResidencyTier::CurrentApp, None, None);
        let addr = a.address.clone();
        assert_eq!(r.register(a.clone()), None);
        assert_eq!(r.lookup(&addr), Some(&a));
        assert_eq!(r.len(), 1);
    }

    #[test]
    fn register_replaces_returns_previous() {
        let mut r = AnchorRegistry::new();
        let a = anchor(b"same", AcsPlane::State, ResidencyTier::CurrentApp, Some("E1"), None);
        let b = anchor(b"same", AcsPlane::State, ResidencyTier::CurrentApp, Some("E2"), None);
        assert_eq!(a.address, b.address, "same content/kind/ts → same address");
        r.register(a.clone());
        let prev = r.register(b.clone());
        assert_eq!(prev, Some(a));
        assert_eq!(r.lookup(&b.address).unwrap().theorem_tag.as_deref(), Some("E2"));
    }

    #[test]
    fn lookup_missing_returns_none() {
        let r = AnchorRegistry::new();
        let absent = UasAddress::new(UasKind::GraphNode, b"absent", 0);
        assert_eq!(r.lookup(&absent), None);
    }

    #[test]
    fn project_set_valued_for_same_coordinate() {
        let mut r = AnchorRegistry::new();
        r.register(anchor(b"a", AcsPlane::Verification, ResidencyTier::VerifiedFloor, None, None));
        r.register(anchor(b"b", AcsPlane::Verification, ResidencyTier::VerifiedFloor, None, None));
        r.register(anchor(b"c", AcsPlane::State, ResidencyTier::VerifiedFloor, None, None));
        let hits = r.project(AcsPlane::Verification, ResidencyTier::VerifiedFloor);
        assert_eq!(hits.len(), 2);
    }

    #[test]
    fn by_theorem_filter() {
        let mut r = AnchorRegistry::new();
        r.register(anchor(b"a", AcsPlane::State, ResidencyTier::CurrentApp, Some("E2"), None));
        r.register(anchor(b"b", AcsPlane::Episodic, ResidencyTier::CurrentApp, Some("E2"), None));
        r.register(anchor(b"c", AcsPlane::State, ResidencyTier::CurrentApp, Some("E1"), None));
        r.register(anchor(b"d", AcsPlane::State, ResidencyTier::CurrentApp, None, None));
        assert_eq!(r.by_theorem("E2").len(), 2);
        assert_eq!(r.by_theorem("E1").len(), 1);
        assert_eq!(r.by_theorem("E7").len(), 0);
    }

    #[test]
    fn by_active_packet_filter() {
        let mut r = AnchorRegistry::new();
        r.register(anchor(b"a", AcsPlane::State, ResidencyTier::CurrentApp, None, Some(7)));
        r.register(anchor(b"b", AcsPlane::Episodic, ResidencyTier::CurrentApp, None, Some(7)));
        r.register(anchor(b"c", AcsPlane::State, ResidencyTier::CurrentApp, None, Some(8)));
        assert_eq!(r.by_active_packet(7).len(), 2);
        assert_eq!(r.by_active_packet(8).len(), 1);
        assert_eq!(r.by_active_packet(99).len(), 0);
    }

    #[test]
    fn iter_visits_every_anchor() {
        let mut r = AnchorRegistry::new();
        r.register(anchor(b"a", AcsPlane::State, ResidencyTier::CurrentApp, None, None));
        r.register(anchor(b"b", AcsPlane::Episodic, ResidencyTier::VerifiedFloor, None, None));
        r.register(anchor(b"c", AcsPlane::Verification, ResidencyTier::CapabilityCeiling, None, None));
        assert_eq!(r.iter().count(), 3);
    }
}
