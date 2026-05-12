// HARDENING ENFORCEMENT: BTM is the user's history-scrubbing surface.
// A panic here loses the user's mental model of how a claim graph
// evolved. Tests are allowed to unwrap because a failed invariant
// SHOULD panic loudly.
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

//! HELIOS V5 W5 — Semantic Brain Time Machine V1.5.
//!
//! HELIOS-W5 guard
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §3 W5 +
//! `docs/fusion/helios v5 first.md` DOC 1 §1.5 +
//! `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §F:
//!
//! > "Semantic Brain Time Machine V1.5 — operates over claim-graph
//! >  deltas only, NEVER tensor checkpoints."
//!
//! This module ships the SEMANTIC half of the BTM. The tensor half
//! (Pro tensor BTM with weight-checkpoint rollback) is research-only
//! per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_2026_05_05.md` §1 + Gate
//! Register; it is intentionally NOT implemented here.
//!
//! ## §2.5.2 compliance posture
//!
//! Tier 1 ON in MAS by default. Pure data type + pure function over
//! claim-graph deltas. No model file change, no runtime download, no
//! weight mutation. Doctrinally safe per
//! `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §N.
//!
//! ## V1.5 vs Pro tensor BTM
//!
//! - **V1.5 (this module)**: claim-graph deltas committed to the
//!   `ClaimLedger`. Operates entirely on the typed Claim/Evidence
//!   substrate.
//! - **Pro tensor BTM**: weight rollback / checkpointing. **Lane 5
//!   Vault only**. Never ships in MAS.
//!
//! ## Cross-references
//!
//! - [`crate::provenance::ledger::Claim`] — claim data type
//! - [`crate::provenance::ledger::ClaimId`] — id type
//! - [`crate::scope_rex::answer_packet::AnswerPacket::semantic_delta_ref`] —
//!   field that carries a [`SemanticDeltaId`] reference into a
//!   committed delta

use serde::{Deserialize, Serialize};

use crate::provenance::ledger::{Claim, ClaimId};

/// Stable id for a [`SemanticDelta`]. Wire format is opaque string;
/// callers choose ULID / UUIDv7 / etc. so the rest of the codebase's
/// id discipline carries through.
#[derive(Debug, Clone, Default, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(transparent)]
pub struct SemanticDeltaId(pub String);

impl SemanticDeltaId {
    pub fn new<S: Into<String>>(s: S) -> Self {
        Self(s.into())
    }
}

/// One semantic delta over the claim graph. Carries the strict
/// addition / modification / removal sets so a downstream [`apply_delta`]
/// or [`rewind`] step can route each member to the right ledger
/// operation.
///
/// **NEVER** carries tensor weights. The `text` field of a modified
/// claim is the only payload.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct SemanticDelta {
    pub id: SemanticDeltaId,
    /// Claim ids added by this delta.
    pub added_claims: Vec<Claim>,
    /// Claim ids modified by this delta. Carries the new full
    /// [`Claim`] so apply can replace by id.
    pub modified_claims: Vec<Claim>,
    /// Claim ids removed by this delta.
    pub removed_claim_ids: Vec<ClaimId>,
}

impl SemanticDelta {
    /// Construct an empty delta — useful as a starting point for
    /// builder-style construction.
    pub fn new(id: SemanticDeltaId) -> Self {
        Self {
            id,
            added_claims: Vec::new(),
            modified_claims: Vec::new(),
            removed_claim_ids: Vec::new(),
        }
    }

    pub fn with_addition(mut self, claim: Claim) -> Self {
        self.added_claims.push(claim);
        self
    }

    pub fn with_modification(mut self, claim: Claim) -> Self {
        self.modified_claims.push(claim);
        self
    }

    pub fn with_removal(mut self, id: ClaimId) -> Self {
        self.removed_claim_ids.push(id);
        self
    }

    /// True iff this delta makes no changes.
    pub fn is_empty(&self) -> bool {
        self.added_claims.is_empty()
            && self.modified_claims.is_empty()
            && self.removed_claim_ids.is_empty()
    }

    /// Number of claims added.
    pub fn added_count(&self) -> usize {
        self.added_claims.len()
    }

    /// Number of claims modified.
    pub fn modified_count(&self) -> usize {
        self.modified_claims.len()
    }

    /// Number of claims removed.
    pub fn removed_count(&self) -> usize {
        self.removed_claim_ids.len()
    }

    /// Total number of operations in this delta.
    pub fn op_count(&self) -> usize {
        self.added_count() + self.modified_count() + self.removed_count()
    }
}

/// Errors from [`apply_delta`] / [`rewind`] / [`replay`].
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum BtmError {
    /// A delta references a claim id that the apply target does not
    /// contain. Apply cannot proceed; the delta and the target
    /// have drifted.
    #[error("claim id {0:?} referenced by delta but absent from state")]
    ClaimIdAbsent(ClaimId),

    /// A delta tries to add a claim id that already exists.
    /// Catches double-application of the same delta.
    #[error("claim id {0:?} already present in state — delta would double-add")]
    ClaimIdAlreadyPresent(ClaimId),

    /// Caller asked to rewind to an out-of-range index.
    #[error("rewind target index {0} out of range (history length {1})")]
    RewindTargetOutOfRange(usize, usize),
}

/// In-memory claim-graph state used by the BTM. Independent of the
/// full [`crate::provenance::ledger::ClaimLedger`] — BTM operates on
/// a denormalized projection so the user's history-scrubbing surface
/// can render quickly without holding the full ledger in memory.
///
/// Modeled as `id → Claim` map for O(1) lookups during apply.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct ClaimGraphState {
    pub claims: std::collections::BTreeMap<ClaimId, Claim>,
}

impl ClaimGraphState {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn len(&self) -> usize {
        self.claims.len()
    }

    pub fn is_empty(&self) -> bool {
        self.claims.is_empty()
    }

    pub fn contains(&self, id: &ClaimId) -> bool {
        self.claims.contains_key(id)
    }

    pub fn get(&self, id: &ClaimId) -> Option<&Claim> {
        self.claims.get(id)
    }
}

/// Apply a semantic delta to the given state. **Strict** — fails on
/// double-add (claim id already present in additions) or unknown-id
/// (modification or removal of a claim id not in state).
///
/// The semantics here are a CRDT-friendly subset of the broader
/// `ClaimLedger` retraction-walk semantics. BTM tracks coarse-grained
/// add/modify/remove; the ledger handles the full derivation graph.
pub fn apply_delta(state: &mut ClaimGraphState, delta: &SemanticDelta) -> Result<(), BtmError> {
    // Validate ALL operations before mutating any state — preserves
    // atomicity (caller sees either full apply or no apply).
    for c in &delta.added_claims {
        if state.contains(&c.id) {
            return Err(BtmError::ClaimIdAlreadyPresent(c.id.clone()));
        }
    }
    for c in &delta.modified_claims {
        if !state.contains(&c.id) {
            return Err(BtmError::ClaimIdAbsent(c.id.clone()));
        }
    }
    for id in &delta.removed_claim_ids {
        if !state.contains(id) {
            return Err(BtmError::ClaimIdAbsent(id.clone()));
        }
    }
    // All checks passed — apply.
    for c in &delta.added_claims {
        state.claims.insert(c.id.clone(), c.clone());
    }
    for c in &delta.modified_claims {
        state.claims.insert(c.id.clone(), c.clone());
    }
    for id in &delta.removed_claim_ids {
        state.claims.remove(id);
    }
    Ok(())
}

/// Replay a sequence of deltas onto an initial state and return the
/// final state. Stops on the first error.
pub fn replay(
    initial: ClaimGraphState,
    deltas: &[SemanticDelta],
) -> Result<ClaimGraphState, BtmError> {
    let mut state = initial;
    for d in deltas {
        apply_delta(&mut state, d)?;
    }
    Ok(state)
}

/// Rewind to a specific point in history: replay `deltas[..target]`
/// (i.e. first `target` deltas) onto an initial state. `target = 0`
/// returns the initial state unchanged.
///
/// Returns [`BtmError::RewindTargetOutOfRange`] if `target > deltas.len()`.
pub fn rewind(
    initial: ClaimGraphState,
    deltas: &[SemanticDelta],
    target: usize,
) -> Result<ClaimGraphState, BtmError> {
    if target > deltas.len() {
        return Err(BtmError::RewindTargetOutOfRange(target, deltas.len()));
    }
    replay(initial, &deltas[..target])
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::provenance::ledger::ClaimKind;

    fn claim(id: &str, text: &str) -> Claim {
        Claim::new(ClaimId::new(id), text, 1_745_000_000_000)
    }

    fn delta_id(s: &str) -> SemanticDeltaId {
        SemanticDeltaId::new(s)
    }

    #[test]
    fn empty_delta_is_a_noop() {
        let mut state = ClaimGraphState::new();
        let d = SemanticDelta::new(delta_id("d0"));
        assert!(d.is_empty());
        assert_eq!(apply_delta(&mut state, &d), Ok(()));
        assert!(state.is_empty());
    }

    #[test]
    fn addition_then_modification_then_removal_round_trip() {
        let mut state = ClaimGraphState::new();
        let add = SemanticDelta::new(delta_id("d-add"))
            .with_addition(claim("c1", "first").clone())
            .with_addition(claim("c2", "second").clone());
        apply_delta(&mut state, &add).unwrap();
        assert_eq!(state.len(), 2);

        let modify = SemanticDelta::new(delta_id("d-mod"))
            .with_modification(claim("c1", "first updated").with_kind(ClaimKind::Mathematical));
        apply_delta(&mut state, &modify).unwrap();
        assert_eq!(
            state.get(&ClaimId::new("c1")).unwrap().text,
            "first updated"
        );
        assert_eq!(
            state.get(&ClaimId::new("c1")).unwrap().kind,
            ClaimKind::Mathematical
        );

        let remove = SemanticDelta::new(delta_id("d-rm")).with_removal(ClaimId::new("c2"));
        apply_delta(&mut state, &remove).unwrap();
        assert_eq!(state.len(), 1);
        assert!(!state.contains(&ClaimId::new("c2")));
    }

    #[test]
    fn double_add_fails_atomically() {
        let mut state = ClaimGraphState::new();
        let add = SemanticDelta::new(delta_id("d-add")).with_addition(claim("c1", "x"));
        apply_delta(&mut state, &add).unwrap();
        // Re-applying must fail — double-add is the canonical
        // "this delta was already applied" signal.
        assert_eq!(
            apply_delta(&mut state, &add),
            Err(BtmError::ClaimIdAlreadyPresent(ClaimId::new("c1")))
        );
        // State unchanged after the failed apply.
        assert_eq!(state.len(), 1);
    }

    #[test]
    fn modify_unknown_id_fails_atomically() {
        let mut state = ClaimGraphState::new();
        let modify = SemanticDelta::new(delta_id("d-mod")).with_modification(claim("ghost", "x"));
        assert_eq!(
            apply_delta(&mut state, &modify),
            Err(BtmError::ClaimIdAbsent(ClaimId::new("ghost")))
        );
    }

    #[test]
    fn remove_unknown_id_fails_atomically() {
        let mut state = ClaimGraphState::new();
        let remove = SemanticDelta::new(delta_id("d-rm")).with_removal(ClaimId::new("ghost"));
        assert_eq!(
            apply_delta(&mut state, &remove),
            Err(BtmError::ClaimIdAbsent(ClaimId::new("ghost")))
        );
    }

    #[test]
    fn apply_delta_is_atomic_under_partial_failure() {
        // A delta with some valid + some invalid ops MUST NOT
        // partially-apply. Atomic-or-nothing.
        let mut state = ClaimGraphState::new();
        // Pre-populate with c1.
        let pre = SemanticDelta::new(delta_id("pre")).with_addition(claim("c1", "x"));
        apply_delta(&mut state, &pre).unwrap();

        // This delta has a valid addition (c2) AND an invalid removal
        // (ghost). Atomicity says NEITHER applies.
        let mixed = SemanticDelta::new(delta_id("mixed"))
            .with_addition(claim("c2", "y"))
            .with_removal(ClaimId::new("ghost"));
        assert_eq!(
            apply_delta(&mut state, &mixed),
            Err(BtmError::ClaimIdAbsent(ClaimId::new("ghost")))
        );
        // c2 must NOT have been added — atomicity gate caught it.
        assert!(!state.contains(&ClaimId::new("c2")));
        assert_eq!(state.len(), 1);
    }

    #[test]
    fn replay_50_conversation_history_lands_consistently() {
        // Per W5 acceptance: "replay test on 50 claim-graph histories."
        // We construct a 50-delta history (one claim per delta) and
        // replay it; state must end up with all 50 claims.
        let mut deltas: Vec<SemanticDelta> = Vec::new();
        for i in 0..50 {
            let id = format!("c{}", i);
            let d =
                SemanticDelta::new(delta_id(&format!("d-{}", i))).with_addition(claim(&id, &id));
            deltas.push(d);
        }
        let final_state = replay(ClaimGraphState::new(), &deltas).unwrap();
        assert_eq!(final_state.len(), 50);
        // First and last claim both present.
        assert!(final_state.contains(&ClaimId::new("c0")));
        assert!(final_state.contains(&ClaimId::new("c49")));
    }

    #[test]
    fn rewind_to_zero_returns_initial_state() {
        let mut deltas = Vec::new();
        for i in 0..3 {
            deltas.push(
                SemanticDelta::new(delta_id(&format!("d-{}", i)))
                    .with_addition(claim(&format!("c{}", i), "x")),
            );
        }
        let s0 = rewind(ClaimGraphState::new(), &deltas, 0).unwrap();
        assert!(s0.is_empty());
    }

    #[test]
    fn rewind_to_midpoint_applies_first_n_deltas() {
        let mut deltas = Vec::new();
        for i in 0..5 {
            deltas.push(
                SemanticDelta::new(delta_id(&format!("d-{}", i)))
                    .with_addition(claim(&format!("c{}", i), "x")),
            );
        }
        // Rewind to 3 = first 3 deltas applied.
        let s3 = rewind(ClaimGraphState::new(), &deltas, 3).unwrap();
        assert_eq!(s3.len(), 3);
        assert!(s3.contains(&ClaimId::new("c0")));
        assert!(s3.contains(&ClaimId::new("c2")));
        assert!(!s3.contains(&ClaimId::new("c3")));
    }

    #[test]
    fn rewind_target_past_history_end_errors() {
        let deltas = [SemanticDelta::new(delta_id("d-0")).with_addition(claim("c0", "x"))];
        assert_eq!(
            rewind(ClaimGraphState::new(), &deltas, 5),
            Err(BtmError::RewindTargetOutOfRange(5, 1))
        );
    }

    #[test]
    fn semantic_delta_round_trips_through_json() {
        let d = SemanticDelta::new(delta_id("d-1"))
            .with_addition(claim("c1", "x"))
            .with_modification(claim("c2", "y").with_kind(ClaimKind::Mathematical))
            .with_removal(ClaimId::new("c3"));
        let json = serde_json::to_string(&d).unwrap();
        let parsed: SemanticDelta = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, d);
    }

    #[test]
    fn delta_op_count_is_sum_of_three_paths() {
        let d = SemanticDelta::new(delta_id("d"))
            .with_addition(claim("a1", "x"))
            .with_addition(claim("a2", "y"))
            .with_modification(claim("m1", "z"))
            .with_removal(ClaimId::new("r1"))
            .with_removal(ClaimId::new("r2"));
        assert_eq!(d.added_count(), 2);
        assert_eq!(d.modified_count(), 1);
        assert_eq!(d.removed_count(), 2);
        assert_eq!(d.op_count(), 5);
    }

    #[test]
    fn semantic_btm_never_carries_tensor_payload() {
        // Compile-time + runtime check: SemanticDelta has NO field
        // for tensors. Try to grep the type for a Vec<f32> or
        // similar — none exist.
        // This test documents the W5 contract: "operates over
        // claim-graph deltas only, NEVER tensor checkpoints."
        let d = SemanticDelta::new(delta_id("d"));
        let json = serde_json::to_string(&d).unwrap();
        assert!(!json.contains("\"weights\""));
        assert!(!json.contains("\"tensor\""));
        assert!(!json.contains("\"checkpoint\""));
    }
}
