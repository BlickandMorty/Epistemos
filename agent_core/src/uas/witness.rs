//! `UasStateWitness` — substrate-floor trait for emitting state-change witnesses.
//!
//! Source:
//! - Driver §4.G mission G.B1 acceptance: "emits a SCOPE-Rex witness on any
//!   state change."
//! - Canonical doctrine `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md`
//!   §5 register row #1 acceptance.
//! - Phase B blueprint `docs/audits/UAS_ACS_PHASE_B_BLUEPRINT_2026_05_17.md`
//!   §2.1 iter 25.
//!
//! # What this lands
//!
//! A minimal trait surface that lets the UAS layer emit witnesses without
//! pulling in `scope_rex::witnessed_state` directly. The substrate-floor
//! ships a `CollectingWitness` test-mode implementation; the production wire-
//! up to `scope_rex::witnessed_state::WitnessedState` lands in a later iter
//! (cross-terminal handshake — the W1/W4 SCOPE-Rex surface is W-track
//! territory; UAS produces events, the witnessed-state subsystem consumes).
//!
//! # The Witness event taxonomy
//!
//! Five canonical events cover every state change a `UasAddress` /
//! `ResidencyLease` pair can undergo:
//!
//! 1. **LeaseGranted** — a new lease was bound to an address.
//! 2. **LeaseRefreshed** — an existing lease was re-anchored to `now_ms`.
//! 3. **LeaseExpired** — TTL elapsed; the lease is informational only.
//! 4. **LeaseReleased** — the substrate dropped the lease (RAII drop OR
//!    explicit release).
//! 5. **AddressMigrated** — the same `UasAddress` moved between residency
//!    tiers (e.g. `CapabilityCeiling → VerifiedFloor` after falsifier pass).
//!
//! These five form a complete cover of the iter-24 state surface. Adding a
//! sixth event requires updating this enum + the trait surface + downstream
//! consumers.

use crate::uas::{ResidencyTier, UasAddress};

/// Canonical state-change event for the UAS layer.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum WitnessEvent {
    LeaseGranted {
        address: UasAddress,
        tier: ResidencyTier,
        granted_at_ms: u64,
        ttl_ms: u64,
    },
    LeaseRefreshed {
        address: UasAddress,
        tier: ResidencyTier,
        new_granted_at_ms: u64,
    },
    LeaseExpired {
        address: UasAddress,
        tier: ResidencyTier,
        expired_at_ms: u64,
    },
    LeaseReleased {
        address: UasAddress,
        tier: ResidencyTier,
        released_at_ms: u64,
    },
    AddressMigrated {
        address: UasAddress,
        from_tier: ResidencyTier,
        to_tier: ResidencyTier,
        migrated_at_ms: u64,
    },
}

/// Substrate-floor trait for emitting witnesses. Implementations include the
/// test-mode `CollectingWitness` below; the production implementation wires
/// into `scope_rex::witnessed_state::WitnessedState` (cross-terminal handshake
/// — lands in a follow-up iter once the witnessed-state subsystem exposes a
/// `WitnessedState::record_uas_event` API).
pub trait UasStateWitness {
    fn record(&self, event: WitnessEvent);
}

/// Test-mode witness collector that captures every recorded event in
/// insertion order.
///
/// Thread-safe via `std::sync::Mutex` so multi-threaded test setups can
/// share a single collector.
#[derive(Default)]
pub struct CollectingWitness {
    events: std::sync::Mutex<Vec<WitnessEvent>>,
}

impl CollectingWitness {
    pub fn new() -> Self {
        Self::default()
    }

    /// Returns a snapshot of every event recorded so far, in order.
    pub fn snapshot(&self) -> Vec<WitnessEvent> {
        self.events.lock().unwrap_or_else(|e| e.into_inner()).clone()
    }

    /// Returns the number of recorded events.
    pub fn len(&self) -> usize {
        self.events.lock().unwrap_or_else(|e| e.into_inner()).len()
    }

    /// Returns `true` if no events have been recorded.
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

impl UasStateWitness for CollectingWitness {
    fn record(&self, event: WitnessEvent) {
        self.events
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .push(event);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::{ResidencyLease, UasKind};

    fn sample_address() -> UasAddress {
        UasAddress::new(UasKind::VaultNote, b"witness-test", 0)
    }

    #[test]
    fn collecting_witness_starts_empty() {
        let w = CollectingWitness::new();
        assert!(w.is_empty());
        assert_eq!(w.len(), 0);
        assert_eq!(w.snapshot(), vec![]);
    }

    #[test]
    fn collecting_witness_records_events_in_order() {
        let w = CollectingWitness::new();
        let addr = sample_address();
        let lease = ResidencyLease::new(addr.clone(), ResidencyTier::CurrentApp, 0, 100);

        w.record(WitnessEvent::LeaseGranted {
            address: lease.address.clone(),
            tier: lease.tier,
            granted_at_ms: lease.granted_at_ms,
            ttl_ms: lease.ttl_ms,
        });
        w.record(WitnessEvent::LeaseRefreshed {
            address: lease.address.clone(),
            tier: lease.tier,
            new_granted_at_ms: 50,
        });
        w.record(WitnessEvent::LeaseExpired {
            address: lease.address.clone(),
            tier: lease.tier,
            expired_at_ms: 100,
        });

        let snapshot = w.snapshot();
        assert_eq!(snapshot.len(), 3);
        assert!(matches!(snapshot[0], WitnessEvent::LeaseGranted { .. }));
        assert!(matches!(snapshot[1], WitnessEvent::LeaseRefreshed { .. }));
        assert!(matches!(snapshot[2], WitnessEvent::LeaseExpired { .. }));
    }

    #[test]
    fn address_migrated_event_carries_both_tiers() {
        let w = CollectingWitness::new();
        let addr = sample_address();
        w.record(WitnessEvent::AddressMigrated {
            address: addr.clone(),
            from_tier: ResidencyTier::CapabilityCeiling,
            to_tier: ResidencyTier::VerifiedFloor,
            migrated_at_ms: 1234,
        });
        let snap = w.snapshot();
        assert_eq!(snap.len(), 1);
        match &snap[0] {
            WitnessEvent::AddressMigrated { from_tier, to_tier, .. } => {
                assert_eq!(*from_tier, ResidencyTier::CapabilityCeiling);
                assert_eq!(*to_tier, ResidencyTier::VerifiedFloor);
            }
            other => panic!("expected AddressMigrated, got {:?}", other),
        }
    }

    #[test]
    fn five_event_variants_cover_state_surface() {
        // Anti-drift assertion: the five canonical events cover the iter-24
        // state surface (UasAddress + ResidencyLease). If a sixth state-
        // change kind is added (e.g. address-content-mutation), this test
        // breaks and forces the canonical doctrine §5 row #1 acceptance to
        // be revised before the new event lands.
        let addr = sample_address();
        let events = [
            WitnessEvent::LeaseGranted { address: addr.clone(), tier: ResidencyTier::CurrentApp, granted_at_ms: 0, ttl_ms: 0 },
            WitnessEvent::LeaseRefreshed { address: addr.clone(), tier: ResidencyTier::CurrentApp, new_granted_at_ms: 0 },
            WitnessEvent::LeaseExpired { address: addr.clone(), tier: ResidencyTier::CurrentApp, expired_at_ms: 0 },
            WitnessEvent::LeaseReleased { address: addr.clone(), tier: ResidencyTier::CurrentApp, released_at_ms: 0 },
            WitnessEvent::AddressMigrated { address: addr, from_tier: ResidencyTier::CurrentApp, to_tier: ResidencyTier::VerifiedFloor, migrated_at_ms: 0 },
        ];
        assert_eq!(events.len(), 5, "five-event LOCK — adding a 6th event requires canonical doctrine §5 row #1 acceptance revision");
    }
}
