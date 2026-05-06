//! HELIOS V5 — Engram hash-table substrate (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-ENGRAM guard
//!
//! Per HELIOS v4 preservation `source_docs/epistemos_resonance_gate.md`
//! §2.2 (DeepSeek V4 Engram Memory inspiration; NOT a verified
//! substrate — see "Caveat" below).
//!
//! ## Concept
//!
//! Engram separates **static knowledge** (facts, signatures, dates,
//! API contracts) from **dynamic reasoning** (MoE computation /
//! attention / state-space dynamics). Static knowledge lives in
//! a hash table with O(1) lookup; dynamic reasoning lives in the
//! Sherry-ternary transformer / SSM stack.
//!
//! Engram maps to the L4Engram tier in
//! `agent_core::resonance::lambda::ResidencyLevel`.
//!
//! ## Caveat (verbatim from preservation source)
//!
//! > "The 'Sparsity Allocation Law' is presented as a 'newly
//! >  discovered' law but appears to be a heuristic rather than a
//! >  proven theorem. The O(1) claim is true for hash table lookup
//! >  but ignores hash collision resolution and cache effects."
//!
//! This module ships only the hash-table TYPE substrate (insert,
//! lookup, capacity bounds). The "Sparsity Allocation Law" 20-25%
//! recommendation is captured as a `recommended_static_fraction`
//! constant; consumers SHOULD treat it as a heuristic, not a
//! theorem.
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. NEVER ships in MAS. Building requires
//! `--features research`. Real Engram backends with collision
//! resolution + cache-aware probing land per a Lane 3 follow-up
//! — this module is the typed surface only.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Recommended fraction of total parameter budget allocated to
/// static-knowledge Engram memory per the heuristic
/// "Sparsity Allocation Law" (20-25%). Stored as numerator /
/// denominator pair to avoid float drift.
///
/// **NOT a theorem.** This is a heuristic surfaced explicitly so
/// consumers can adjust it per benchmark without searching for the
/// canonical value.
pub const RECOMMENDED_STATIC_FRACTION_NUMERATOR: u32 = 22;
pub const RECOMMENDED_STATIC_FRACTION_DENOMINATOR: u32 = 100;

/// Lower bound of the recommended static-allocation range (20%).
pub const RECOMMENDED_STATIC_FRACTION_MIN: f32 = 0.20;

/// Upper bound of the recommended static-allocation range (25%).
pub const RECOMMENDED_STATIC_FRACTION_MAX: f32 = 0.25;

/// One Engram entry: a (key, payload) pair where the key is the
/// pre-hashed N-gram identifier.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct EngramEntry {
    /// Pre-hashed N-gram key. The hash function is intentionally
    /// outside the substrate — consumers pick blake3 / xxh3 / siphash
    /// based on collision-resistance vs throughput trade-off.
    pub key: u64,
    /// Opaque payload bytes (the actual fact / signature / date / etc.).
    pub payload: Vec<u8>,
}

/// In-memory Engram hash table — O(1) average-case lookup over a
/// pre-hashed key space. The hash table itself is `std::HashMap`
/// (DOS-resistant SipHash by default in Rust's std).
///
/// Real production Engram would use a perfect hash (compile-time
/// or build-time) over a fixed static-knowledge corpus to eliminate
/// collisions entirely; this struct exposes the typed surface.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct EngramTable {
    /// Underlying storage. The outer key is the user-supplied
    /// pre-hashed N-gram id; std::HashMap re-hashes for its own
    /// internal bucketing. This double-hash is intentional: the
    /// outer hash guarantees the key fits the substrate's u64
    /// contract; the inner hash prevents adversarial collision.
    entries: HashMap<u64, Vec<u8>>,
}

impl EngramTable {
    /// Create an empty Engram table.
    pub fn new() -> Self {
        Self::default()
    }

    /// Insert a key/payload pair. Returns the previous payload if
    /// the key was already present.
    pub fn insert(&mut self, key: u64, payload: Vec<u8>) -> Option<Vec<u8>> {
        self.entries.insert(key, payload)
    }

    /// Lookup a payload by key. Returns `None` if the key is absent.
    pub fn lookup(&self, key: u64) -> Option<&[u8]> {
        self.entries.get(&key).map(|v| v.as_slice())
    }

    /// Remove and return the payload for a key.
    pub fn remove(&mut self, key: u64) -> Option<Vec<u8>> {
        self.entries.remove(&key)
    }

    /// Number of entries currently in the table.
    pub fn len(&self) -> usize {
        self.entries.len()
    }

    /// Whether the table holds zero entries.
    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    /// Total payload byte count across all entries — useful for the
    /// Sparsity Allocation Law budgeting heuristic.
    pub fn total_payload_bytes(&self) -> usize {
        self.entries.values().map(|v| v.len()).sum()
    }
}

/// Sparsity-allocation budget split per the heuristic Sparsity
/// Allocation Law. Given a total parameter / memory budget, returns
/// the recommended Engram (static) and dynamic-reasoning splits.
///
/// **NOT a theorem.** The 20-25% range is a heuristic; consumers
/// should benchmark on their workload before locking the split.
pub fn sparsity_allocation_split(total_budget: u64) -> SparsityAllocationSplit {
    let recommended = (total_budget as f64
        * RECOMMENDED_STATIC_FRACTION_NUMERATOR as f64
        / RECOMMENDED_STATIC_FRACTION_DENOMINATOR as f64) as u64;
    SparsityAllocationSplit {
        engram_static_budget: recommended,
        dynamic_reasoning_budget: total_budget.saturating_sub(recommended),
    }
}

/// Result of [`sparsity_allocation_split`].
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct SparsityAllocationSplit {
    /// Recommended Engram static-knowledge budget (~22% of total).
    pub engram_static_budget: u64,
    /// Recommended dynamic-reasoning budget (~78% of total).
    pub dynamic_reasoning_budget: u64,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_table_has_no_entries() {
        let t = EngramTable::new();
        assert!(t.is_empty());
        assert_eq!(t.len(), 0);
        assert_eq!(t.total_payload_bytes(), 0);
    }

    #[test]
    fn insert_then_lookup_returns_payload() {
        let mut t = EngramTable::new();
        t.insert(0xDEAD_BEEF_CAFE_BABE, b"fact".to_vec());
        assert_eq!(t.lookup(0xDEAD_BEEF_CAFE_BABE), Some(b"fact" as &[u8]));
    }

    #[test]
    fn lookup_missing_key_returns_none() {
        let t = EngramTable::new();
        assert!(t.lookup(0).is_none());
    }

    #[test]
    fn insert_existing_key_returns_previous_payload() {
        let mut t = EngramTable::new();
        t.insert(42, b"first".to_vec());
        let prev = t.insert(42, b"second".to_vec());
        assert_eq!(prev, Some(b"first".to_vec()));
        assert_eq!(t.lookup(42), Some(b"second" as &[u8]));
    }

    #[test]
    fn remove_returns_payload_and_drops_entry() {
        let mut t = EngramTable::new();
        t.insert(7, b"data".to_vec());
        assert_eq!(t.len(), 1);
        let payload = t.remove(7);
        assert_eq!(payload, Some(b"data".to_vec()));
        assert_eq!(t.len(), 0);
    }

    #[test]
    fn total_payload_bytes_sums_all_entries() {
        let mut t = EngramTable::new();
        t.insert(1, b"abc".to_vec());           // 3 bytes
        t.insert(2, b"hello world".to_vec());   // 11 bytes
        t.insert(3, vec![]);                     // 0 bytes
        assert_eq!(t.total_payload_bytes(), 3 + 11);
    }

    #[test]
    fn sparsity_allocation_split_uses_22_percent_default() {
        let split = sparsity_allocation_split(100_000);
        // 22% of 100_000 = 22_000.
        assert_eq!(split.engram_static_budget, 22_000);
        assert_eq!(split.dynamic_reasoning_budget, 78_000);
    }

    #[test]
    fn sparsity_allocation_split_falls_in_recommended_range() {
        let split = sparsity_allocation_split(1_000_000);
        let fraction = split.engram_static_budget as f32
            / 1_000_000.0_f32;
        assert!(
            fraction >= RECOMMENDED_STATIC_FRACTION_MIN
                && fraction <= RECOMMENDED_STATIC_FRACTION_MAX,
            "split fraction {} outside [{}, {}]",
            fraction,
            RECOMMENDED_STATIC_FRACTION_MIN,
            RECOMMENDED_STATIC_FRACTION_MAX
        );
    }

    #[test]
    fn sparsity_allocation_handles_zero_budget() {
        let split = sparsity_allocation_split(0);
        assert_eq!(split.engram_static_budget, 0);
        assert_eq!(split.dynamic_reasoning_budget, 0);
    }

    #[test]
    fn recommended_fraction_constants_are_internally_consistent() {
        // 22 / 100 = 0.22 falls within [0.20, 0.25].
        let mid = RECOMMENDED_STATIC_FRACTION_NUMERATOR as f32
            / RECOMMENDED_STATIC_FRACTION_DENOMINATOR as f32;
        assert!(mid >= RECOMMENDED_STATIC_FRACTION_MIN);
        assert!(mid <= RECOMMENDED_STATIC_FRACTION_MAX);
    }

    #[test]
    fn engram_table_round_trips_through_json() {
        let mut t = EngramTable::new();
        t.insert(1, b"alpha".to_vec());
        t.insert(2, b"beta".to_vec());
        let json = serde_json::to_string(&t).unwrap();
        let parsed: EngramTable = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.lookup(1), Some(b"alpha" as &[u8]));
        assert_eq!(parsed.lookup(2), Some(b"beta" as &[u8]));
    }

    #[test]
    fn engram_entry_round_trips_through_json() {
        let entry = EngramEntry {
            key: 0x1234_5678_ABCD_EF00,
            payload: b"signature".to_vec(),
        };
        let json = serde_json::to_string(&entry).unwrap();
        let parsed: EngramEntry = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, entry);
    }

    #[test]
    fn sparsity_allocation_split_is_idempotent_under_round_trip() {
        let split = sparsity_allocation_split(50_000);
        let json = serde_json::to_string(&split).unwrap();
        let parsed: SparsityAllocationSplit = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, split);
    }
}
