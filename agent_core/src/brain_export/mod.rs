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
}
