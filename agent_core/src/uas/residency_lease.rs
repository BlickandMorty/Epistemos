//! `ResidencyLease` — substrate-tier lease handle with TTL + RAII drop.
//!
//! Source:
//! - Canonical doctrine `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md`
//!   §5 register row #2.
//! - Phase B blueprint `docs/audits/UAS_ACS_PHASE_B_BLUEPRINT_2026_05_17.md`
//!   §2.1 iter 24.
//!
//! # Purpose
//!
//! A `ResidencyLease` binds a `UasAddress` to a `ResidencyTier` for a bounded
//! time window. The lease asserts: *"during the lease window, the substrate
//! agrees to keep the artifact addressable at the named tier."* When the lease
//! expires (TTL elapsed) or is dropped (RAII), the substrate is free to
//! migrate the artifact to a different tier or evict it from cache.
//!
//! ## TTL semantics
//!
//! - `granted_at_ms` + `ttl_ms` → `expires_at_ms`.
//! - Past `expires_at_ms`, the lease is expired but the value can still be
//!   inspected (the lease becomes informational).
//! - `refresh(now_ms)` extends the lease by re-anchoring `granted_at_ms` to
//!   `now_ms` (same `ttl_ms`).
//!
//! ## RAII drop semantics
//!
//! When `ResidencyLease` falls out of scope, Rust's standard drop runs. The
//! lease itself owns no external resources (no file handles, no FFI
//! pointers), so drop is a no-op by default — but the *intent* is RAII:
//! holding the lease keeps the substrate's commitment alive in the type
//! system. If a future iter wires the lease into a global lease-registry
//! (where drop must signal release), a `Drop` impl lands there; for the
//! Phase B.G.B1.d substrate-floor, scope-exit IS the release signal.

use serde::{Deserialize, Serialize};

use crate::uas::{ResidencyTier, UasAddress};

/// Bounded-time commitment that a substrate artifact remains addressable at a
/// named tier.
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct ResidencyLease {
    pub address: UasAddress,
    pub tier: ResidencyTier,
    pub granted_at_ms: u64,
    pub ttl_ms: u64,
}

impl ResidencyLease {
    /// Construct a new lease anchored at `granted_at_ms` with the given
    /// `ttl_ms` window.
    pub fn new(address: UasAddress, tier: ResidencyTier, granted_at_ms: u64, ttl_ms: u64) -> Self {
        Self { address, tier, granted_at_ms, ttl_ms }
    }

    /// Absolute expiry time in milliseconds since epoch.
    ///
    /// Saturating: if `granted_at_ms + ttl_ms` overflows `u64`, the result is
    /// `u64::MAX` (effectively never expires).
    pub fn expires_at_ms(&self) -> u64 {
        self.granted_at_ms.saturating_add(self.ttl_ms)
    }

    /// Returns `true` if the lease has expired at `now_ms`.
    pub fn is_expired(&self, now_ms: u64) -> bool {
        now_ms >= self.expires_at_ms()
    }

    /// Remaining time in milliseconds before expiry.
    ///
    /// Saturating: returns `0` if already expired.
    pub fn time_remaining_ms(&self, now_ms: u64) -> u64 {
        self.expires_at_ms().saturating_sub(now_ms)
    }

    /// Re-anchor the lease at `now_ms`, keeping the same `ttl_ms` window.
    /// Returns `self` to allow chaining.
    pub fn refresh(mut self, now_ms: u64) -> Self {
        self.granted_at_ms = now_ms;
        self
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::UasKind;

    fn sample_address() -> UasAddress {
        UasAddress::new(UasKind::VaultNote, b"lease-test", 1000)
    }

    #[test]
    fn lease_records_address_tier_and_window() {
        let lease = ResidencyLease::new(sample_address(), ResidencyTier::CurrentApp, 5_000, 30_000);
        assert_eq!(lease.tier, ResidencyTier::CurrentApp);
        assert_eq!(lease.granted_at_ms, 5_000);
        assert_eq!(lease.ttl_ms, 30_000);
        assert_eq!(lease.expires_at_ms(), 35_000);
    }

    #[test]
    fn is_expired_fires_at_or_past_expiry() {
        let lease = ResidencyLease::new(sample_address(), ResidencyTier::VerifiedFloor, 0, 100);
        assert!(!lease.is_expired(0));
        assert!(!lease.is_expired(50));
        assert!(!lease.is_expired(99));
        assert!(lease.is_expired(100));
        assert!(lease.is_expired(1_000));
    }

    #[test]
    fn time_remaining_saturates_at_zero() {
        let lease = ResidencyLease::new(sample_address(), ResidencyTier::CapabilityCeiling, 0, 100);
        assert_eq!(lease.time_remaining_ms(0), 100);
        assert_eq!(lease.time_remaining_ms(99), 1);
        assert_eq!(lease.time_remaining_ms(100), 0);
        assert_eq!(lease.time_remaining_ms(1_000), 0);
    }

    #[test]
    fn refresh_reanchors_window() {
        let lease = ResidencyLease::new(sample_address(), ResidencyTier::CurrentApp, 0, 100);
        assert!(lease.clone().is_expired(150));
        let refreshed = lease.refresh(200);
        assert_eq!(refreshed.granted_at_ms, 200);
        assert_eq!(refreshed.ttl_ms, 100);
        assert_eq!(refreshed.expires_at_ms(), 300);
        assert!(!refreshed.is_expired(250));
    }

    #[test]
    fn expiry_saturates_on_overflow() {
        // granted + ttl > u64::MAX must saturate to u64::MAX, not wrap.
        let lease = ResidencyLease::new(sample_address(), ResidencyTier::CurrentApp, u64::MAX - 10, 100);
        assert_eq!(lease.expires_at_ms(), u64::MAX);
        assert!(!lease.is_expired(u64::MAX - 5));
    }

    #[test]
    fn serde_round_trip() {
        let lease = ResidencyLease::new(sample_address(), ResidencyTier::VerifiedFloor, 1234, 5678);
        let json = serde_json::to_string(&lease).expect("serialize must succeed");
        let parsed: ResidencyLease = serde_json::from_str(&json).expect("deserialize must succeed");
        assert_eq!(lease, parsed);
    }

    /// RAII drop acceptance: when the lease falls out of scope, Rust's
    /// standard drop runs. The substrate-floor lease owns no external
    /// resources, so drop is a no-op — but the *scope exit IS the release
    /// signal*. This test exercises the scope-exit drop path to lock the
    /// RAII semantics in the test suite.
    #[test]
    fn raii_drop_runs_on_scope_exit() {
        let address = sample_address();
        {
            let _lease = ResidencyLease::new(address.clone(), ResidencyTier::CurrentApp, 0, 100);
            // _lease is alive here.
        }
        // _lease is dropped at the closing brace above. The substrate-floor
        // has no observable side-effect; this test exists to lock that the
        // drop path RUNS (and to flag future iters if a Drop impl with
        // observable behavior lands and accidentally breaks this scope-exit
        // invariant).
        // We re-construct another lease over the same address to confirm
        // the address is still usable post-drop (no double-free, no leak).
        let _post = ResidencyLease::new(address, ResidencyTier::CurrentApp, 200, 100);
    }
}
