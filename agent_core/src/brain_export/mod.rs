//! Source:
//! - `~/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md`
//!   §0 (Wave 11 net-new business layer) + §Brain Export sections.
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.7 — Brain(τ) export: full state at time τ.
//! - Companion to [`crate::cognitive_dag`] (Phase 8 typed Merkle DAG)
//!   + [`crate::provenance`] (claim ledger).
//!
//! # Phase B.7 — Brain export substrate
//!
//! A "brain snapshot" captures the agent's complete state at time τ —
//! enough to recreate behavior identically given the same future
//! inputs. Substrate floor owns the envelope types; the actual
//! serialization of [`crate::cognitive_dag`] + claim ledger lives in
//! their respective sibling modules.
//!
//! Brain(τ) = (dag_merkle_root, claim_ledger_hash, model_id,
//!             skill_registry_hash, vault_state_hash, timestamp_unix_ms).
//!
//! Reconstructing Brain(τ') from Brain(τ) requires: the snapshot
//! envelope + the materialized checkpoint at τ + the semantic deltas
//! over `(τ, τ']` (the rule from [`crate::research::brain_routing`]).

pub mod time_machine;

pub use time_machine::{reconstruct, reconstruct_chain, BrainDelta, TimeMachineError};

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct BrainSnapshot {
    pub model_id: String,
    pub dag_merkle_root: String,
    pub claim_ledger_hash: String,
    pub skill_registry_hash: String,
    pub vault_state_hash: String,
    pub timestamp_unix_ms: u64,
    pub schema_version: String,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum BrainExportError {
    EmptyModelId,
    EmptyMerkleRoot,
    UnsupportedSchemaVersion,
}

pub const SCHEMA_V1: &str = "epistemos.brain.v1";

impl BrainSnapshot {
    /// Construct + validate a snapshot. Hashes are stored as hex
    /// strings; substrate floor only checks non-emptiness — production
    /// callers verify hex format upstream.
    pub fn new(
        model_id: impl Into<String>,
        dag_merkle_root: impl Into<String>,
        claim_ledger_hash: impl Into<String>,
        skill_registry_hash: impl Into<String>,
        vault_state_hash: impl Into<String>,
        timestamp_unix_ms: u64,
    ) -> Result<Self, BrainExportError> {
        let s = Self {
            model_id: model_id.into(),
            dag_merkle_root: dag_merkle_root.into(),
            claim_ledger_hash: claim_ledger_hash.into(),
            skill_registry_hash: skill_registry_hash.into(),
            vault_state_hash: vault_state_hash.into(),
            timestamp_unix_ms,
            schema_version: SCHEMA_V1.into(),
        };
        if s.model_id.is_empty() {
            return Err(BrainExportError::EmptyModelId);
        }
        if s.dag_merkle_root.is_empty() {
            return Err(BrainExportError::EmptyMerkleRoot);
        }
        Ok(s)
    }

    pub fn matches_schema(&self) -> Result<(), BrainExportError> {
        if self.schema_version != SCHEMA_V1 {
            return Err(BrainExportError::UnsupportedSchemaVersion);
        }
        Ok(())
    }

    /// Predicate: every required hash field is non-empty AND the
    /// schema version matches SCHEMA_V1. The "is this snapshot
    /// safe to write?" pre-flight check. Cross-surface invariant:
    /// implies `matches_schema().is_ok()`.
    pub fn is_self_consistent(&self) -> bool {
        !self.model_id.is_empty()
            && !self.dag_merkle_root.is_empty()
            && !self.claim_ledger_hash.is_empty()
            && !self.skill_registry_hash.is_empty()
            && !self.vault_state_hash.is_empty()
            && self.schema_version == SCHEMA_V1
    }

    /// Age of this snapshot relative to `now_unix_ms`:
    /// `Some(now - timestamp)` when `now >= timestamp`, else `None`
    /// (clock-skew or future-dated snapshot). The "how stale is this
    /// brain?" diagnostic for the export-recency dashboard.
    pub const fn age_at(&self, now_unix_ms: u64) -> Option<u64> {
        if now_unix_ms >= self.timestamp_unix_ms {
            Some(now_unix_ms - self.timestamp_unix_ms)
        } else {
            None
        }
    }

    /// Predicate: this snapshot's timestamp predates `other`'s.
    pub const fn is_before(&self, other: &BrainSnapshot) -> bool {
        self.timestamp_unix_ms < other.timestamp_unix_ms
    }

    /// Predicate: this snapshot's timestamp follows `other`'s.
    pub const fn is_after(&self, other: &BrainSnapshot) -> bool {
        self.timestamp_unix_ms > other.timestamp_unix_ms
    }

    /// Predicate: same timestamp as `other` (not necessarily same
    /// contents). Cross-surface invariant: `is_before`, `is_after`,
    /// `is_concurrent_with` form a three-way partition over any
    /// snapshot pair (exactly one is true).
    pub const fn is_concurrent_with(&self, other: &BrainSnapshot) -> bool {
        self.timestamp_unix_ms == other.timestamp_unix_ms
    }
}

impl BrainExportError {
    /// Stable identifier for the field/cause the validation failed on.
    pub const fn field(&self) -> &'static str {
        match self {
            BrainExportError::EmptyModelId => "model_id",
            BrainExportError::EmptyMerkleRoot => "dag_merkle_root",
            BrainExportError::UnsupportedSchemaVersion => "schema_version",
        }
    }

    /// Predicate: the error is about an empty required string
    /// (model_id or dag_merkle_root).
    pub const fn is_empty_field(&self) -> bool {
        matches!(
            self,
            BrainExportError::EmptyModelId | BrainExportError::EmptyMerkleRoot
        )
    }

    /// Predicate: the error is about schema-version mismatch.
    /// Cross-surface invariant: `is_empty_field XOR is_schema_mismatch`
    /// partitions every BrainExportError variant.
    pub const fn is_schema_mismatch(&self) -> bool {
        matches!(self, BrainExportError::UnsupportedSchemaVersion)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ok_snapshot() -> BrainSnapshot {
        BrainSnapshot::new("qwen3-8b", "0xdead", "0xbeef", "0xcafe", "0xf00d", 1_700_000_000)
            .unwrap()
    }

    #[test]
    fn schema_v1_constant_is_stable() {
        assert_eq!(SCHEMA_V1, "epistemos.brain.v1");
    }

    #[test]
    fn ok_snapshot_validates() {
        let s = ok_snapshot();
        assert_eq!(s.schema_version, SCHEMA_V1);
        assert!(s.matches_schema().is_ok());
    }

    #[test]
    fn empty_model_id_rejected() {
        let err = BrainSnapshot::new("", "0xdead", "0xbeef", "0xcafe", "0xf00d", 0).unwrap_err();
        assert_eq!(err, BrainExportError::EmptyModelId);
    }

    #[test]
    fn empty_merkle_root_rejected() {
        let err = BrainSnapshot::new("m", "", "0xbeef", "0xcafe", "0xf00d", 0).unwrap_err();
        assert_eq!(err, BrainExportError::EmptyMerkleRoot);
    }

    #[test]
    fn snapshot_roundtrips_through_serde_json() {
        let s = ok_snapshot();
        let json = serde_json::to_string(&s).unwrap();
        let back: BrainSnapshot = serde_json::from_str(&json).unwrap();
        assert_eq!(s, back);
    }

    #[test]
    fn schema_mismatch_errors() {
        let mut s = ok_snapshot();
        s.schema_version = "epistemos.brain.v2".into();
        let err = s.matches_schema().unwrap_err();
        assert_eq!(err, BrainExportError::UnsupportedSchemaVersion);
    }

    #[test]
    fn snapshot_is_hashable_and_eq() {
        let a = ok_snapshot();
        let b = a.clone();
        let mut set: std::collections::HashSet<BrainSnapshot> = Default::default();
        set.insert(a);
        assert!(set.contains(&b));
    }

    #[test]
    fn distinct_timestamps_distinguish_snapshots() {
        let s1 = ok_snapshot();
        let s2 = BrainSnapshot::new(&s1.model_id, &s1.dag_merkle_root, &s1.claim_ledger_hash, &s1.skill_registry_hash, &s1.vault_state_hash, s1.timestamp_unix_ms + 1).unwrap();
        assert_ne!(s1, s2);
    }

    // ── diagnostic surface (iter 143) ────────────────────────────────────────

    #[test]
    fn is_self_consistent_true_for_ok_snapshot() {
        let s = ok_snapshot();
        assert!(s.is_self_consistent());
        // Cross-surface: is_self_consistent implies matches_schema OK.
        assert!(s.matches_schema().is_ok());
    }

    #[test]
    fn is_self_consistent_false_after_clearing_hash() {
        let mut s = ok_snapshot();
        s.claim_ledger_hash = String::new();
        assert!(!s.is_self_consistent());
    }

    #[test]
    fn is_self_consistent_false_after_clearing_vault_hash() {
        let mut s = ok_snapshot();
        s.vault_state_hash = String::new();
        assert!(!s.is_self_consistent());
    }

    #[test]
    fn is_self_consistent_false_on_schema_mismatch() {
        let mut s = ok_snapshot();
        s.schema_version = "epistemos.brain.v2".into();
        assert!(!s.is_self_consistent());
    }

    #[test]
    fn age_at_returns_some_for_now_after_timestamp() {
        let s = ok_snapshot();
        let age = s.age_at(s.timestamp_unix_ms + 1000).unwrap();
        assert_eq!(age, 1000);
    }

    #[test]
    fn age_at_returns_zero_at_same_timestamp() {
        let s = ok_snapshot();
        assert_eq!(s.age_at(s.timestamp_unix_ms), Some(0));
    }

    #[test]
    fn age_at_returns_none_when_now_before_timestamp() {
        let s = ok_snapshot();
        assert_eq!(s.age_at(s.timestamp_unix_ms - 1), None);
    }

    #[test]
    fn temporal_predicates_partition_pair() {
        // Cross-surface invariant: exactly one of is_before / is_after /
        // is_concurrent_with is true for any pair of snapshots.
        let a = ok_snapshot();
        let mut b = a.clone();
        b.timestamp_unix_ms = a.timestamp_unix_ms + 1000;
        assert!(a.is_before(&b) && !a.is_after(&b) && !a.is_concurrent_with(&b));
        assert!(!b.is_before(&a) && b.is_after(&a) && !b.is_concurrent_with(&a));
        assert!(a.is_concurrent_with(&a) && !a.is_before(&a) && !a.is_after(&a));
    }

    #[test]
    fn temporal_predicates_mutually_exclusive_over_pairs() {
        let a = ok_snapshot();
        let mut b = a.clone();
        for delta in [0u64, 1, 100, 1_000_000] {
            b.timestamp_unix_ms = a.timestamp_unix_ms + delta;
            let trio = [a.is_before(&b), a.is_after(&b), a.is_concurrent_with(&b)];
            assert_eq!(trio.iter().filter(|t| **t).count(), 1, "delta={}", delta);
        }
    }

    #[test]
    fn error_field_matches_variant() {
        assert_eq!(BrainExportError::EmptyModelId.field(), "model_id");
        assert_eq!(BrainExportError::EmptyMerkleRoot.field(), "dag_merkle_root");
        assert_eq!(BrainExportError::UnsupportedSchemaVersion.field(), "schema_version");
    }

    #[test]
    fn error_classifiers_partition_variants() {
        // Cross-surface invariant: is_empty_field XOR is_schema_mismatch.
        for e in &[
            BrainExportError::EmptyModelId,
            BrainExportError::EmptyMerkleRoot,
            BrainExportError::UnsupportedSchemaVersion,
        ] {
            assert_ne!(e.is_empty_field(), e.is_schema_mismatch());
        }
        assert!(BrainExportError::EmptyModelId.is_empty_field());
        assert!(BrainExportError::EmptyMerkleRoot.is_empty_field());
        assert!(BrainExportError::UnsupportedSchemaVersion.is_schema_mismatch());
    }
}
