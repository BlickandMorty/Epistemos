//! Source:
//! - `~/Documents/Epistemos-QuickCapture/BIOMETRIC_TAMAGOTCHI_BRAIN_EXPORT_ADDENDUM.md`
//!   §Brain Time Machine — "reconstruct Brain(τ') from Brain(τ) +
//!   materialized checkpoint at τ + semantic deltas over (τ, τ']".
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.6.5 — "Brain Time Machine NOT-STARTED" — this module
//!   lands the substrate floor.
//!
//! # Phase B.6.5 — Brain Time Machine substrate
//!
//! A `BrainDelta` captures what changed between two `BrainSnapshot`s.
//! Applying a delta to a base snapshot reconstructs the later snapshot
//! deterministically — given the same materialized checkpoint at τ +
//! the semantic deltas over `(τ, τ']`, the rebuild is byte-identical.
//!
//! Substrate floor owns the delta envelope + the reconstruction rule.
//! The actual diff producer (compare two DAG merkle roots → emit
//! per-edge deltas) lives in [`crate::cognitive_dag`] once Phase 8.H
//! ships; this module is what 8.H plugs in behind.
//!
//! ## Reconstruction rule
//!
//! ```text
//! BrainSnapshot{τ'} = apply(BrainSnapshot{τ}, BrainDelta{τ → τ'})
//! ```
//!
//! Per addendum §Brain Time Machine: every reconstruction MUST be
//! pure — no I/O, no global state. The delta alone, applied to the
//! base, yields the next snapshot. This makes the rebuild auditable
//! (replay-bundle compatible) and time-travel safe.

use super::{BrainExportError, BrainSnapshot, SCHEMA_V1};
use serde::{Deserialize, Serialize};

/// A delta between two `BrainSnapshot`s. Each field that changed
/// carries the new value; unchanged fields are `None`. `timestamp_to`
/// is the τ' the base snapshot is being advanced to.
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct BrainDelta {
    pub timestamp_to: u64,
    pub model_id: Option<String>,
    pub dag_merkle_root: Option<String>,
    pub claim_ledger_hash: Option<String>,
    pub skill_registry_hash: Option<String>,
    pub vault_state_hash: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum TimeMachineError {
    DeltaGoesBackward { from: u64, to: u64 },
    DeltaIsNoop { at: u64 },
    SchemaMismatch,
    InvalidResult(BrainExportError),
}

impl BrainDelta {
    /// Compute the delta `from → to`. Only fields that differ are
    /// recorded. Returns an error if `to.timestamp_unix_ms <=
    /// from.timestamp_unix_ms` (time may not run backward or pause).
    pub fn between(
        from: &BrainSnapshot,
        to: &BrainSnapshot,
    ) -> Result<Self, TimeMachineError> {
        if to.timestamp_unix_ms <= from.timestamp_unix_ms {
            return Err(TimeMachineError::DeltaGoesBackward {
                from: from.timestamp_unix_ms,
                to: to.timestamp_unix_ms,
            });
        }
        if from.schema_version != to.schema_version {
            return Err(TimeMachineError::SchemaMismatch);
        }
        let diff = |a: &String, b: &String| -> Option<String> {
            if a == b { None } else { Some(b.clone()) }
        };
        Ok(BrainDelta {
            timestamp_to: to.timestamp_unix_ms,
            model_id: diff(&from.model_id, &to.model_id),
            dag_merkle_root: diff(&from.dag_merkle_root, &to.dag_merkle_root),
            claim_ledger_hash: diff(&from.claim_ledger_hash, &to.claim_ledger_hash),
            skill_registry_hash: diff(&from.skill_registry_hash, &to.skill_registry_hash),
            vault_state_hash: diff(&from.vault_state_hash, &to.vault_state_hash),
        })
    }

    /// True iff every field is `None` (i.e. nothing about the brain
    /// actually changed). A no-op delta is allowed in storage but is
    /// rejected at reconstruction time per §Brain Time Machine — every
    /// time advancement MUST correspond to some observable change.
    pub fn is_noop(&self) -> bool {
        self.model_id.is_none()
            && self.dag_merkle_root.is_none()
            && self.claim_ledger_hash.is_none()
            && self.skill_registry_hash.is_none()
            && self.vault_state_hash.is_none()
    }

    /// Count of fields actually changed by this delta (Some-valued
    /// options). Cross-surface invariant: `changed_field_count() == 0`
    /// iff `is_noop()`.
    pub fn changed_field_count(&self) -> usize {
        (self.model_id.is_some() as usize)
            + (self.dag_merkle_root.is_some() as usize)
            + (self.claim_ledger_hash.is_some() as usize)
            + (self.skill_registry_hash.is_some() as usize)
            + (self.vault_state_hash.is_some() as usize)
    }

    /// Names of fields actually changed by this delta. Stable
    /// identifiers used by the control-room "what changed?" log.
    /// Cross-surface invariant: `changes().len() == changed_field_count()`.
    pub fn changes(&self) -> Vec<&'static str> {
        let mut v: Vec<&'static str> = Vec::new();
        if self.model_id.is_some() {
            v.push("model_id");
        }
        if self.dag_merkle_root.is_some() {
            v.push("dag_merkle_root");
        }
        if self.claim_ledger_hash.is_some() {
            v.push("claim_ledger_hash");
        }
        if self.skill_registry_hash.is_some() {
            v.push("skill_registry_hash");
        }
        if self.vault_state_hash.is_some() {
            v.push("vault_state_hash");
        }
        v
    }

    /// Time advancement from `from_ts`: `Some(timestamp_to - from_ts)`
    /// when the delta moves time forward, else `None` (backward or
    /// stationary — both rejected at reconstruction time).
    pub const fn time_delta(&self, from_ts: u64) -> Option<u64> {
        if self.timestamp_to > from_ts {
            Some(self.timestamp_to - from_ts)
        } else {
            None
        }
    }

    /// Predicate: model_id changed by this delta.
    pub const fn changes_model(&self) -> bool {
        self.model_id.is_some()
    }

    /// Predicate: dag_merkle_root changed by this delta.
    pub const fn changes_dag(&self) -> bool {
        self.dag_merkle_root.is_some()
    }
}

impl TimeMachineError {
    /// Predicate: this error pertains to time ordering
    /// (DeltaGoesBackward / DeltaIsNoop).
    pub const fn is_temporal(&self) -> bool {
        matches!(
            self,
            TimeMachineError::DeltaGoesBackward { .. } | TimeMachineError::DeltaIsNoop { .. }
        )
    }

    /// Predicate: this error pertains to data validity
    /// (SchemaMismatch / InvalidResult). Cross-surface invariant:
    /// `is_temporal XOR is_data` partitions every TimeMachineError.
    pub const fn is_data(&self) -> bool {
        matches!(
            self,
            TimeMachineError::SchemaMismatch | TimeMachineError::InvalidResult(_)
        )
    }
}

/// Pure reconstruction. Given a base snapshot and a delta, produce the
/// later snapshot deterministically. No I/O, no clock reads — the
/// `timestamp_to` from the delta becomes the new snapshot's
/// `timestamp_unix_ms`.
pub fn reconstruct(
    base: &BrainSnapshot,
    delta: &BrainDelta,
) -> Result<BrainSnapshot, TimeMachineError> {
    if delta.timestamp_to <= base.timestamp_unix_ms {
        return Err(TimeMachineError::DeltaGoesBackward {
            from: base.timestamp_unix_ms,
            to: delta.timestamp_to,
        });
    }
    if delta.is_noop() {
        return Err(TimeMachineError::DeltaIsNoop { at: delta.timestamp_to });
    }
    let next = BrainSnapshot {
        model_id: delta.model_id.clone().unwrap_or_else(|| base.model_id.clone()),
        dag_merkle_root: delta
            .dag_merkle_root
            .clone()
            .unwrap_or_else(|| base.dag_merkle_root.clone()),
        claim_ledger_hash: delta
            .claim_ledger_hash
            .clone()
            .unwrap_or_else(|| base.claim_ledger_hash.clone()),
        skill_registry_hash: delta
            .skill_registry_hash
            .clone()
            .unwrap_or_else(|| base.skill_registry_hash.clone()),
        vault_state_hash: delta
            .vault_state_hash
            .clone()
            .unwrap_or_else(|| base.vault_state_hash.clone()),
        timestamp_unix_ms: delta.timestamp_to,
        schema_version: base.schema_version.clone(),
    };
    next.matches_schema().map_err(TimeMachineError::InvalidResult)?;
    if next.model_id.is_empty() {
        return Err(TimeMachineError::InvalidResult(BrainExportError::EmptyModelId));
    }
    if next.dag_merkle_root.is_empty() {
        return Err(TimeMachineError::InvalidResult(BrainExportError::EmptyMerkleRoot));
    }
    Ok(next)
}

/// Chain reconstruction over an ordered sequence of deltas. Each delta
/// must advance the timestamp strictly forward. Returns the final
/// snapshot or the first error encountered.
pub fn reconstruct_chain(
    base: &BrainSnapshot,
    deltas: &[BrainDelta],
) -> Result<BrainSnapshot, TimeMachineError> {
    let mut current = base.clone();
    for d in deltas {
        current = reconstruct(&current, d)?;
    }
    Ok(current)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn snap(ts: u64, dag: &str) -> BrainSnapshot {
        BrainSnapshot::new("qwen3-8b", dag, "0xbeef", "0xcafe", "0xf00d", ts).unwrap()
    }

    #[test]
    fn delta_between_records_only_changes() {
        let a = snap(100, "0xaaaa");
        let b = snap(200, "0xbbbb");
        let d = BrainDelta::between(&a, &b).unwrap();
        assert_eq!(d.timestamp_to, 200);
        assert_eq!(d.dag_merkle_root.as_deref(), Some("0xbbbb"));
        assert_eq!(d.model_id, None);
        assert_eq!(d.claim_ledger_hash, None);
    }

    #[test]
    fn delta_rejects_backward_time() {
        let a = snap(200, "0xaa");
        let b = snap(100, "0xbb");
        let err = BrainDelta::between(&a, &b).unwrap_err();
        assert!(matches!(err, TimeMachineError::DeltaGoesBackward { .. }));
    }

    #[test]
    fn delta_rejects_equal_timestamps() {
        let a = snap(200, "0xaa");
        let b = snap(200, "0xbb");
        let err = BrainDelta::between(&a, &b).unwrap_err();
        assert!(matches!(err, TimeMachineError::DeltaGoesBackward { .. }));
    }

    #[test]
    fn delta_rejects_schema_mismatch() {
        let mut a = snap(100, "0xaa");
        let mut b = snap(200, "0xbb");
        a.schema_version = "v1".into();
        b.schema_version = "v2".into();
        let err = BrainDelta::between(&a, &b).unwrap_err();
        assert_eq!(err, TimeMachineError::SchemaMismatch);
    }

    #[test]
    fn reconstruct_advances_changed_field() {
        let a = snap(100, "0xaa");
        let b = snap(200, "0xbb");
        let d = BrainDelta::between(&a, &b).unwrap();
        let rebuilt = reconstruct(&a, &d).unwrap();
        assert_eq!(rebuilt, b);
    }

    #[test]
    fn reconstruct_preserves_unchanged_fields() {
        let a = snap(100, "0xaa");
        let b = snap(200, "0xaa");
        let d = BrainDelta {
            timestamp_to: 200,
            model_id: None,
            dag_merkle_root: None,
            claim_ledger_hash: Some("0xnewclaim".into()),
            skill_registry_hash: None,
            vault_state_hash: None,
        };
        let rebuilt = reconstruct(&a, &d).unwrap();
        assert_eq!(rebuilt.model_id, a.model_id);
        assert_eq!(rebuilt.dag_merkle_root, a.dag_merkle_root);
        assert_eq!(rebuilt.claim_ledger_hash, "0xnewclaim");
        assert_eq!(rebuilt.timestamp_unix_ms, 200);
        let _ = b;
    }

    #[test]
    fn reconstruct_rejects_noop_delta() {
        let a = snap(100, "0xaa");
        let d = BrainDelta {
            timestamp_to: 200,
            model_id: None,
            dag_merkle_root: None,
            claim_ledger_hash: None,
            skill_registry_hash: None,
            vault_state_hash: None,
        };
        let err = reconstruct(&a, &d).unwrap_err();
        assert!(matches!(err, TimeMachineError::DeltaIsNoop { .. }));
    }

    #[test]
    fn reconstruct_rejects_backward_delta() {
        let a = snap(200, "0xaa");
        let d = BrainDelta {
            timestamp_to: 100,
            model_id: None,
            dag_merkle_root: Some("0xbb".into()),
            claim_ledger_hash: None,
            skill_registry_hash: None,
            vault_state_hash: None,
        };
        let err = reconstruct(&a, &d).unwrap_err();
        assert!(matches!(err, TimeMachineError::DeltaGoesBackward { .. }));
    }

    #[test]
    fn reconstruct_chain_walks_forward() {
        let a = snap(100, "0xaa");
        let b = snap(200, "0xbb");
        let c = snap(300, "0xcc");
        let d1 = BrainDelta::between(&a, &b).unwrap();
        let d2 = BrainDelta::between(&b, &c).unwrap();
        let final_snap = reconstruct_chain(&a, &[d1, d2]).unwrap();
        assert_eq!(final_snap, c);
    }

    #[test]
    fn reconstruct_chain_short_circuits_on_first_error() {
        let a = snap(100, "0xaa");
        let bad = BrainDelta {
            timestamp_to: 50,
            model_id: None,
            dag_merkle_root: Some("0xbb".into()),
            claim_ledger_hash: None,
            skill_registry_hash: None,
            vault_state_hash: None,
        };
        let err = reconstruct_chain(&a, &[bad]).unwrap_err();
        assert!(matches!(err, TimeMachineError::DeltaGoesBackward { .. }));
    }

    #[test]
    fn empty_chain_returns_base_clone() {
        let a = snap(100, "0xaa");
        let rebuilt = reconstruct_chain(&a, &[]).unwrap();
        assert_eq!(rebuilt, a);
    }

    #[test]
    fn delta_roundtrips_through_serde_json() {
        let a = snap(100, "0xaa");
        let b = snap(200, "0xbb");
        let d = BrainDelta::between(&a, &b).unwrap();
        let json = serde_json::to_string(&d).unwrap();
        let back: BrainDelta = serde_json::from_str(&json).unwrap();
        assert_eq!(d, back);
    }

    #[test]
    fn is_noop_detects_zero_field_delta() {
        let zero = BrainDelta {
            timestamp_to: 5,
            model_id: None,
            dag_merkle_root: None,
            claim_ledger_hash: None,
            skill_registry_hash: None,
            vault_state_hash: None,
        };
        assert!(zero.is_noop());

        let one = BrainDelta {
            timestamp_to: 5,
            model_id: Some("x".into()),
            dag_merkle_root: None,
            claim_ledger_hash: None,
            skill_registry_hash: None,
            vault_state_hash: None,
        };
        assert!(!one.is_noop());
        assert_eq!(SCHEMA_V1, "epistemos.brain.v1");
    }

    // ── diagnostic surface (iter 144) ────────────────────────────────────────

    #[test]
    fn changed_field_count_zero_iff_noop() {
        // Cross-surface invariant: changed_field_count() == 0 iff is_noop().
        let noop = BrainDelta {
            timestamp_to: 5,
            model_id: None,
            dag_merkle_root: None,
            claim_ledger_hash: None,
            skill_registry_hash: None,
            vault_state_hash: None,
        };
        assert!(noop.is_noop());
        assert_eq!(noop.changed_field_count(), 0);

        let one = BrainDelta {
            timestamp_to: 5,
            model_id: Some("x".into()),
            dag_merkle_root: None,
            claim_ledger_hash: None,
            skill_registry_hash: None,
            vault_state_hash: None,
        };
        assert!(!one.is_noop());
        assert_eq!(one.changed_field_count(), 1);
    }

    #[test]
    fn changed_field_count_caps_at_five() {
        let all = BrainDelta {
            timestamp_to: 5,
            model_id: Some("a".into()),
            dag_merkle_root: Some("b".into()),
            claim_ledger_hash: Some("c".into()),
            skill_registry_hash: Some("d".into()),
            vault_state_hash: Some("e".into()),
        };
        assert_eq!(all.changed_field_count(), 5);
    }

    #[test]
    fn changes_list_matches_count() {
        // Cross-surface invariant: changes().len() == changed_field_count().
        let mixed = BrainDelta {
            timestamp_to: 5,
            model_id: Some("a".into()),
            dag_merkle_root: None,
            claim_ledger_hash: Some("c".into()),
            skill_registry_hash: None,
            vault_state_hash: Some("e".into()),
        };
        assert_eq!(mixed.changes().len(), mixed.changed_field_count());
        assert_eq!(mixed.changes(), vec!["model_id", "claim_ledger_hash", "vault_state_hash"]);
    }

    #[test]
    fn changes_empty_for_noop() {
        let noop = BrainDelta {
            timestamp_to: 5,
            model_id: None,
            dag_merkle_root: None,
            claim_ledger_hash: None,
            skill_registry_hash: None,
            vault_state_hash: None,
        };
        assert!(noop.changes().is_empty());
    }

    #[test]
    fn time_delta_returns_some_for_forward() {
        let d = BrainDelta {
            timestamp_to: 500,
            model_id: Some("x".into()),
            dag_merkle_root: None,
            claim_ledger_hash: None,
            skill_registry_hash: None,
            vault_state_hash: None,
        };
        assert_eq!(d.time_delta(100), Some(400));
    }

    #[test]
    fn time_delta_returns_none_for_backward_or_equal() {
        let d = BrainDelta {
            timestamp_to: 100,
            model_id: Some("x".into()),
            dag_merkle_root: None,
            claim_ledger_hash: None,
            skill_registry_hash: None,
            vault_state_hash: None,
        };
        assert_eq!(d.time_delta(100), None);
        assert_eq!(d.time_delta(500), None);
    }

    #[test]
    fn time_delta_aligns_with_reconstruct_rejection() {
        // Cross-surface invariant: time_delta(base_ts).is_none() iff
        // reconstruct(base, delta) returns DeltaGoesBackward.
        let a = snap(100, "0xaa");
        let backward = BrainDelta {
            timestamp_to: 50,
            model_id: None,
            dag_merkle_root: Some("0xbb".into()),
            claim_ledger_hash: None,
            skill_registry_hash: None,
            vault_state_hash: None,
        };
        assert!(backward.time_delta(a.timestamp_unix_ms).is_none());
        let err = reconstruct(&a, &backward).unwrap_err();
        assert!(matches!(err, TimeMachineError::DeltaGoesBackward { .. }));
    }

    #[test]
    fn change_predicates_match_field_options() {
        let d = BrainDelta {
            timestamp_to: 5,
            model_id: Some("x".into()),
            dag_merkle_root: None,
            claim_ledger_hash: None,
            skill_registry_hash: None,
            vault_state_hash: None,
        };
        assert!(d.changes_model());
        assert!(!d.changes_dag());
    }

    #[test]
    fn temporal_vs_data_error_partition() {
        // Cross-surface invariant: is_temporal XOR is_data over all variants.
        let backward = TimeMachineError::DeltaGoesBackward { from: 0, to: 0 };
        let noop = TimeMachineError::DeltaIsNoop { at: 0 };
        let schema = TimeMachineError::SchemaMismatch;
        let invalid = TimeMachineError::InvalidResult(BrainExportError::EmptyModelId);
        for e in [&backward, &noop, &schema, &invalid].iter().copied() {
            assert_ne!(e.is_temporal(), e.is_data());
        }
        assert!(backward.is_temporal() && noop.is_temporal());
        assert!(schema.is_data() && invalid.is_data());
    }

    #[test]
    fn three_step_chain_with_partial_changes() {
        let a = snap(100, "0xaa");
        let b = BrainSnapshot {
            model_id: a.model_id.clone(),
            dag_merkle_root: "0xbb".into(),
            claim_ledger_hash: a.claim_ledger_hash.clone(),
            skill_registry_hash: a.skill_registry_hash.clone(),
            vault_state_hash: a.vault_state_hash.clone(),
            timestamp_unix_ms: 200,
            schema_version: a.schema_version.clone(),
        };
        let c = BrainSnapshot {
            model_id: "qwen3-14b".into(),
            dag_merkle_root: "0xbb".into(),
            claim_ledger_hash: a.claim_ledger_hash.clone(),
            skill_registry_hash: a.skill_registry_hash.clone(),
            vault_state_hash: a.vault_state_hash.clone(),
            timestamp_unix_ms: 300,
            schema_version: a.schema_version.clone(),
        };
        let d1 = BrainDelta::between(&a, &b).unwrap();
        assert_eq!(d1.model_id, None);
        assert_eq!(d1.dag_merkle_root.as_deref(), Some("0xbb"));
        let d2 = BrainDelta::between(&b, &c).unwrap();
        assert_eq!(d2.model_id.as_deref(), Some("qwen3-14b"));
        assert_eq!(d2.dag_merkle_root, None);
        let rebuilt = reconstruct_chain(&a, &[d1, d2]).unwrap();
        assert_eq!(rebuilt, c);
    }
}
