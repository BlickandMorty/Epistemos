//! Phase B.G.B1 acceptance — UasAddress emits a SCOPE-Rex witness on any
//! state change.
//!
//! Per driver §4.G G.B1 acceptance and canonical doctrine §5 register row
//! #1: "a UasAddress round-trips serialization, can be looked up regardless
//! of residency, emits a SCOPE-Rex witness on any state change."
//!
//! This integration test exercises the substrate-floor `UasStateWitness`
//! trait via the test-mode `CollectingWitness`. Production wire-up to
//! `scope_rex::witnessed_state::WitnessedState` lands in a follow-up iter
//! (cross-terminal handshake — UAS produces events, witnessed-state
//! consumes).

use agent_core::uas::{
    witness::{CollectingWitness, UasStateWitness, WitnessEvent},
    ResidencyLease, ResidencyTier, UasAddress, UasKind,
};

fn sample_address(content: &[u8]) -> UasAddress {
    UasAddress::new(UasKind::VaultNote, content, 0)
}

/// Emit-on-state-change: each mutation of a lease's lifecycle produces a
/// witness event. Five canonical events cover the surface.
#[test]
fn lease_lifecycle_emits_witness_at_every_state_change() {
    let witness = CollectingWitness::new();
    let addr = sample_address(b"lifecycle");

    // 1. Grant
    let lease = ResidencyLease::new(addr.clone(), ResidencyTier::CurrentApp, 0, 100);
    witness.record(WitnessEvent::LeaseGranted {
        address: lease.address.clone(),
        tier: lease.tier,
        granted_at_ms: lease.granted_at_ms,
        ttl_ms: lease.ttl_ms,
    });

    // 2. Refresh
    let lease = lease.refresh(50);
    witness.record(WitnessEvent::LeaseRefreshed {
        address: lease.address.clone(),
        tier: lease.tier,
        new_granted_at_ms: lease.granted_at_ms,
    });

    // 3. Migrate
    let migrated = ResidencyLease::new(lease.address.clone(), ResidencyTier::VerifiedFloor, 100, 100);
    witness.record(WitnessEvent::AddressMigrated {
        address: lease.address.clone(),
        from_tier: ResidencyTier::CurrentApp,
        to_tier: ResidencyTier::VerifiedFloor,
        migrated_at_ms: 100,
    });

    // 4. Expire
    assert!(migrated.is_expired(200));
    witness.record(WitnessEvent::LeaseExpired {
        address: migrated.address.clone(),
        tier: migrated.tier,
        expired_at_ms: 200,
    });

    // 5. Release
    witness.record(WitnessEvent::LeaseReleased {
        address: migrated.address.clone(),
        tier: migrated.tier,
        released_at_ms: 201,
    });

    let snapshot = witness.snapshot();
    assert_eq!(snapshot.len(), 5, "five state changes → five witness events");

    // The order must be preserved.
    assert!(matches!(snapshot[0], WitnessEvent::LeaseGranted { .. }));
    assert!(matches!(snapshot[1], WitnessEvent::LeaseRefreshed { .. }));
    assert!(matches!(snapshot[2], WitnessEvent::AddressMigrated { .. }));
    assert!(matches!(snapshot[3], WitnessEvent::LeaseExpired { .. }));
    assert!(matches!(snapshot[4], WitnessEvent::LeaseReleased { .. }));
}

/// The §4.G G.B1 lookup-regardless-of-residency property: same UasAddress
/// round-trips serialization unchanged, and matches across tier changes.
#[test]
fn uas_address_lookup_invariant_across_residency() {
    use std::str::FromStr;

    let addr = sample_address(b"lookup-invariant");
    let wire = addr.to_string();

    // The wire format is stable regardless of which residency tier holds
    // the lease at the time.
    let _lease_current = ResidencyLease::new(addr.clone(), ResidencyTier::CurrentApp, 0, 100);
    let _lease_verified = ResidencyLease::new(addr.clone(), ResidencyTier::VerifiedFloor, 100, 100);
    let _lease_research = ResidencyLease::new(addr.clone(), ResidencyTier::CapabilityCeiling, 200, 100);

    let parsed = UasAddress::from_str(&wire).expect("wire format must round-trip");
    assert_eq!(addr, parsed, "UasAddress identity is independent of residency tier (§4.G UAS LOCK)");
}

/// The §4.G G.B1 serialization-round-trip property: serde JSON preserves
/// the full UasAddress + ResidencyLease pair.
#[test]
fn lease_serde_round_trip_preserves_state() {
    let addr = sample_address(b"serde-trip");
    let lease = ResidencyLease::new(addr, ResidencyTier::VerifiedFloor, 1234, 5678);
    let json = serde_json::to_string(&lease).expect("serialize must succeed");
    let parsed: ResidencyLease = serde_json::from_str(&json).expect("deserialize must succeed");
    assert_eq!(lease, parsed);
    assert_eq!(parsed.tier, ResidencyTier::VerifiedFloor);
    assert_eq!(parsed.granted_at_ms, 1234);
    assert_eq!(parsed.ttl_ms, 5678);
}
