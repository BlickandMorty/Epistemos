#![cfg(feature = "research")]
//! Phase B.G.B3 acceptance — F-ACS-Anchor-Addressing 4-stage round trip.
//!
//! Per `docs/falsifiers/F-ACS-Anchor-Addressing_2026_05_17.md` §3
//! (pass/fail recipe) and driver §4.G ladder gate #3:
//! *"typed anchor object (theorem tag, plane coord, residency tier, source
//! hash, active packet id) round-trips through agent runtime + lookup +
//! audit + projection without silent loss."*
//!
//! # Substrate-floor scope
//!
//! This harness exercises the iter-27 + iter-28 substrate-floor surfaces
//! (`AcsAnchor` + `AnchorRegistry`). The full production wire-up to
//! `agent_core::provenance::{ledger, replay}` lands in a follow-up iter
//! once the ClaimLedger surface accepts AcsAnchor; here Stage 3 simulates
//! audit canonicalization via JSON round-trip (the same canonicalization
//! that ReplayBundle::to_epbundle_bytes performs).
//!
//! # Iteration count
//!
//! Substrate-floor `N = 50` anchors (vs falsifier-doc target `N = 1000`).
//! The reduced count exercises the SHAPE of the round trip; production-
//! scale validation lands when the harness is wired to real ClaimLedger.

use agent_core::research::acs::{AcsAnchor, AcsPlane, AnchorRegistry};
use agent_core::uas::{ResidencyTier, UasAddress, UasKind};

/// Deterministic LCG-style mini-RNG; suffices for picking anchor fields
/// without pulling in an RNG crate.
struct MiniRng(u64);

impl MiniRng {
    fn new(seed: u64) -> Self {
        Self(seed)
    }

    fn next_u64(&mut self) -> u64 {
        // Numerical Recipes LCG constants — deterministic + reproducible.
        self.0 = self.0.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
        self.0
    }

    fn pick<'a, T>(&mut self, slice: &'a [T]) -> &'a T {
        &slice[(self.next_u64() as usize) % slice.len()]
    }

    fn next_bool(&mut self, p_true_inv: u64) -> bool {
        self.next_u64() % p_true_inv == 0
    }
}

fn random_anchor(rng: &mut MiniRng, content_seed: u64) -> AcsAnchor {
    let kinds = [
        UasKind::VaultNote,
        UasKind::GraphNode,
        UasKind::KvPage,
        UasKind::ModelComponent,
        UasKind::AgentTrace,
        UasKind::ToolResult,
        UasKind::AnswerPacket,
        UasKind::TriFusionBlock,
    ];
    let planes = [
        AcsPlane::State,
        AcsPlane::Episodic,
        AcsPlane::Assembly,
        AcsPlane::Controller,
        AcsPlane::Verification,
    ];
    let tiers = [
        ResidencyTier::CurrentApp,
        ResidencyTier::VerifiedFloor,
        ResidencyTier::CapabilityCeiling,
    ];
    let theorems = ["E1", "E2", "E3", "E4", "E5", "E6", "E7", "H1", "PCF-5"];

    let kind = rng.pick(&kinds).clone();
    let plane = *rng.pick(&planes);
    let tier = *rng.pick(&tiers);

    let content = content_seed.to_le_bytes();
    let address = UasAddress::new(kind, &content, content_seed);
    let mut anchor = AcsAnchor::new(address, plane, tier, &content);

    if !rng.next_bool(3) {
        // 2-of-3 anchors carry a theorem tag.
        anchor = anchor.with_theorem(rng.pick(&theorems).to_string());
    }
    if !rng.next_bool(2) {
        // 1-of-2 anchors carry an active packet id.
        anchor = anchor.with_active_packet(rng.next_u64());
    }

    anchor
}

#[test]
fn four_stage_round_trip_for_50_random_anchors() {
    let mut rng = MiniRng::new(0xACAA_A001_u64);
    let mut originals: Vec<AcsAnchor> = (0..50)
        .map(|i| random_anchor(&mut rng, i as u64))
        .collect();

    // De-duplicate by UasAddress — collision-free for the LCG seed, but
    // defensive guard if a future tweak introduces collisions.
    originals.sort_by(|a, b| a.address.hash.as_bytes().cmp(b.address.hash.as_bytes()));
    originals.dedup_by(|a, b| a.address == b.address);
    assert!(originals.len() >= 40, "50 random anchors should not collide aggressively");

    // Stage 1 — register in the registry (agent-runtime emission analog).
    let mut registry = AnchorRegistry::new();
    for anchor in &originals {
        let previous = registry.register(anchor.clone());
        assert!(previous.is_none(), "Stage 1: register on fresh address must return None");
    }
    assert_eq!(registry.len(), originals.len(), "Stage 1: every anchor registered");

    // Stage 2 — lookup recovers the registered anchor exactly.
    for anchor in &originals {
        let recovered = registry.lookup(&anchor.address)
            .unwrap_or_else(|| panic!("Stage 2: lookup MUST find anchor at {}", anchor.address));
        assert_eq!(recovered, anchor, "Stage 2: lookup must return bytewise-equal anchor");
    }

    // Stage 3 — audit canonicalization (JSON round-trip — substrate-floor
    // analog of ReplayBundle::to_epbundle_bytes / from_epbundle_bytes).
    for anchor in &originals {
        let json = serde_json::to_string(anchor).expect("Stage 3: serialize must succeed");
        let recovered: AcsAnchor = serde_json::from_str(&json)
            .expect("Stage 3: deserialize must succeed");
        assert_eq!(recovered, *anchor, "Stage 3: audit canonicalization must preserve every field");
    }

    // Stage 4 — projection onto (plane, tier) must include the anchor.
    for anchor in &originals {
        let bucket = registry.project(anchor.plane, anchor.tier);
        assert!(
            bucket.iter().any(|a| **a == *anchor),
            "Stage 4: anchor must be in the (plane={:?}, tier={:?}) projection bucket",
            anchor.plane, anchor.tier
        );
    }
}

#[test]
fn anchor_serde_round_trip_preserves_every_field() {
    let addr = UasAddress::new(UasKind::AnswerPacket, b"f-acs-anchor-test", 4242);
    let anchor = AcsAnchor::new(addr, AcsPlane::Verification, ResidencyTier::CapabilityCeiling, b"src")
        .with_theorem("E2")
        .with_active_packet(12345);

    let json = serde_json::to_string(&anchor).expect("serialize must succeed");
    let parsed: AcsAnchor = serde_json::from_str(&json).expect("deserialize must succeed");

    assert_eq!(parsed.theorem_tag.as_deref(), Some("E2"));
    assert_eq!(parsed.plane, AcsPlane::Verification);
    assert_eq!(parsed.tier, ResidencyTier::CapabilityCeiling);
    assert_eq!(parsed.active_packet_id, Some(12345));
    assert_eq!(parsed.source_hash, anchor.source_hash);
    assert_eq!(parsed.address, anchor.address);
}

#[test]
fn reproducibility_same_seed_same_anchor_set() {
    let mut rng1 = MiniRng::new(0xACEE_4242_u64);
    let mut rng2 = MiniRng::new(0xACEE_4242_u64);
    let set1: Vec<AcsAnchor> = (0..20).map(|i| random_anchor(&mut rng1, i)).collect();
    let set2: Vec<AcsAnchor> = (0..20).map(|i| random_anchor(&mut rng2, i)).collect();
    assert_eq!(set1, set2, "same seed must produce same anchor set across runs");
}
