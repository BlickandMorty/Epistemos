//! HELIOS V5 — SCOPE-Rex Omega `WitnessedState` substrate.
//!
//! HELIOS-WITNESSED-STATE guard
//!
//! Per HELIOS v4 preservation `source_docs/scope_rex_omega.md` —
//! the State Witness Layer + the SCOPE-Rex Omega 8-tuple state
//! representation:
//!
//! ```text
//! S_t = (h_t, z_t, g_t, p_t, m_t, w_t, ℓ_t, u_t)
//! ```
//!
//! where:
//!   h_t — model working state (KV cache, recurrent state)
//!   z_t — sparse-feature state (SAE activations)
//!   g_t — extracted claim graph
//!   p_t — proof / verification state
//!   m_t — persistent memory
//!   w_t — tool / world state
//!   ℓ_t — durable ledger state
//!   u_t — authorization state
//!
//! [`WitnessedState`] is the canonical materialized snapshot of this
//! 8-tuple at time `t`, carrying BLAKE3 (32-byte) Merkle roots for each
//! component plus a `state_id` that identifies the snapshot in the
//! ledger.
//!
//! ## Cross-references
//!
//! - [`crate::scope_rex::answer_packet::WitnessedStateId`] — opaque
//!   id reference into this substrate
//! - [`crate::scope_rex::btm_semantic`] — BTM V1.5 semantic delta
//!   substrate (claim-graph deltas only)
//! - canon-hardening protocol §1 — WRV state machine; this module is
//!   `state: implemented` until the chat path materializes a real
//!   WitnessedState per AnswerPacket emission (W1.b)

use serde::{Deserialize, Serialize};

/// 32-byte BLAKE3 root anchor — used for state_id, memory_root,
/// claim_root, proof_root, and other Merkle-rooted state components.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct StateRoot(pub [u8; 32]);

impl StateRoot {
    /// All-zeros root — used as the genesis / empty-state anchor.
    pub const ZERO: StateRoot = StateRoot([0u8; 32]);

    pub fn new(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }
}

impl Default for StateRoot {
    fn default() -> Self {
        Self::ZERO
    }
}

/// Witnessed state snapshot at a single point in agent time.
///
/// Each field is a 32-byte BLAKE3 root over the corresponding state
/// component. The `state_id` identifies this snapshot in the durable
/// ledger; `materialized_from` points at the previous snapshot's
/// `state_id` (forming a Merkle chain across consecutive turns).
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct WitnessedState {
    /// BLAKE3 root anchoring this snapshot in the ledger.
    pub state_id: StateRoot,
    /// Previous snapshot's state_id (Merkle chain).
    pub materialized_from: StateRoot,
    /// Persistent-memory tier root (corresponds to `m_t`).
    pub memory_root: StateRoot,
    /// Claim-graph root (corresponds to `g_t`).
    pub claim_root: StateRoot,
    /// Proof / verification state root (corresponds to `p_t`).
    pub proof_root: StateRoot,
}

impl WitnessedState {
    /// Genesis snapshot — every root is ZERO; `materialized_from` is
    /// also ZERO (no parent).
    pub fn genesis() -> Self {
        Self {
            state_id: StateRoot::ZERO,
            materialized_from: StateRoot::ZERO,
            memory_root: StateRoot::ZERO,
            claim_root: StateRoot::ZERO,
            proof_root: StateRoot::ZERO,
        }
    }
}

/// Event-sourced semantic delta — the durable ledger payload that
/// transforms one [`WitnessedState`] into the next. Mirrors the
/// SCOPE-Rex Omega `SemanticDelta` from the preservation source.
///
/// **Distinct from [`crate::scope_rex::btm_semantic::SemanticDelta`]**:
/// - `btm_semantic::SemanticDelta` carries full Claim values for
///   the BTM V1.5 history-scrubber UI surface (W5).
/// - `SemanticDeltaEvent` (this type) is the durable ledger entry
///   for the SCOPE-Rex Omega state-witness layer — refs only.
///
/// `feature_refs` carries `f32` activation magnitudes, so this struct
/// derives `PartialEq` only (not `Eq`/`Hash`). For Merkle anchoring
/// the `event_id: StateRoot` field is the canonical identity.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SemanticDeltaEvent {
    /// Event id (BLAKE3 root of the canonical event encoding).
    pub event_id: StateRoot,
    /// Parent witnessed-state id (Merkle chain).
    pub parent_state: StateRoot,
    /// Claim ids touched by this event (as opaque 32-byte hashes).
    pub claim_ids: Vec<StateRoot>,
    /// Sparse-feature references (feature index → activation magnitude).
    pub feature_refs: Vec<(u32, f32)>,
    /// Tool-execution hashes (one per tool invocation in this event).
    pub tool_hashes: Vec<StateRoot>,
    /// Proof obligation references (one per proof check in this event).
    pub proof_refs: Vec<StateRoot>,
    /// Authorization reference (Secure Enclave-backed approval, optional).
    pub auth_ref: Option<StateRoot>,
}

impl SemanticDeltaEvent {
    /// Empty event (no state transition); useful as a placeholder
    /// while building up event records.
    pub fn empty(event_id: StateRoot, parent_state: StateRoot) -> Self {
        Self {
            event_id,
            parent_state,
            claim_ids: Vec::new(),
            feature_refs: Vec::new(),
            tool_hashes: Vec::new(),
            proof_refs: Vec::new(),
            auth_ref: None,
        }
    }

    /// Total number of operation refs in this event.
    pub fn op_count(&self) -> usize {
        self.claim_ids.len()
            + self.feature_refs.len()
            + self.tool_hashes.len()
            + self.proof_refs.len()
            + self.auth_ref.map(|_| 1).unwrap_or(0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn state_root_zero_is_all_zeros() {
        assert_eq!(StateRoot::ZERO.0, [0u8; 32]);
        assert_eq!(StateRoot::default(), StateRoot::ZERO);
    }

    #[test]
    fn witnessed_state_genesis_is_all_zero_roots() {
        let g = WitnessedState::genesis();
        assert_eq!(g.state_id, StateRoot::ZERO);
        assert_eq!(g.materialized_from, StateRoot::ZERO);
        assert_eq!(g.memory_root, StateRoot::ZERO);
        assert_eq!(g.claim_root, StateRoot::ZERO);
        assert_eq!(g.proof_root, StateRoot::ZERO);
    }

    #[test]
    fn empty_semantic_delta_event_has_zero_op_count() {
        let event = SemanticDeltaEvent::empty(StateRoot::ZERO, StateRoot::ZERO);
        assert_eq!(event.op_count(), 0);
    }

    #[test]
    fn semantic_delta_event_op_count_sums_all_ref_arrays() {
        let event = SemanticDeltaEvent {
            event_id: StateRoot::ZERO,
            parent_state: StateRoot::ZERO,
            claim_ids: vec![StateRoot::ZERO; 3],
            feature_refs: vec![(0, 0.5), (1, 0.7)],
            tool_hashes: vec![StateRoot::ZERO; 1],
            proof_refs: vec![StateRoot::ZERO; 2],
            auth_ref: Some(StateRoot::ZERO),
        };
        // 3 + 2 + 1 + 2 + 1 = 9
        assert_eq!(event.op_count(), 9);
    }

    #[test]
    fn witnessed_state_round_trips_through_json() {
        let ws = WitnessedState::genesis();
        let json = serde_json::to_string(&ws).unwrap();
        let parsed: WitnessedState = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, ws);
    }

    #[test]
    fn semantic_delta_event_round_trips_through_json() {
        let event = SemanticDeltaEvent::empty(StateRoot::new([1u8; 32]), StateRoot::new([2u8; 32]));
        let json = serde_json::to_string(&event).unwrap();
        let parsed: SemanticDeltaEvent = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, event);
    }
}
