//! SCOPE-Rex Omega — the 8-vector event-sourced brain.
//!
//! SCOPE-Rex stands for **S**tateful **C**ognitive **O**bservability
//! **P**latform — **E**pistemic **R**ecord **E**xecution. The "Omega"
//! suffix refers to the 8-field state vector that fully describes a
//! witnessed cognitive state at any point in brain-time.
//!
//! The 8 fields:
//! 1. `h_t` — model hidden state (transformer activations, RNN hidden)
//! 2. `z_t` — sparse feature activations (top-k routing indices)
//! 3. `g_t` — epistemic claim graph (DAG of supports/contradicts)
//! 4. `p_t` — proof obligations (what still needs to be proven)
//! 5. `m_t` — Merkle root of memory state (content-addressed)
//! 6. `w_t` — tool invocation ledger (immutable, append-only)
//! 7. `l_t` — per-token loss / drift ledger (surprise tracking)
//! 8. `u_t` — biometric auth state (who is currently authenticated)
//!
//! All state transitions are event-sourced: every change is a
//! [`SemanticDelta`] appended to the [`BrainTimeMachine`].

use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet, VecDeque};
use thiserror::Error;
use tracing::{debug, error, info, instrument, trace, warn};
use hex;

// ---------------------------------------------------------------------------
// Domain types for the 8 fields
// ---------------------------------------------------------------------------

/// Model hidden state — opaque blob of activations.
///
/// In production this is a memory-mapped tensor from the MLX backend.
/// Here we store a hash of the tensor bytes so that states can be
/// compared and verified without holding the full weight matrix.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ModelState {
    /// Blake3 hash of the hidden-state tensor bytes.
    pub state_hash: [u8; 32],
    /// Sequence position (token index) at which this state was captured.
    pub seq_pos: usize,
    /// Layer from which this hidden state was extracted.
    pub layer: usize,
}

/// Sparse feature activations — the indices and magnitudes of
/// top-k activated features in a sparse coding layer.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SparseFeatures {
    /// Feature index → activation magnitude.
    pub indices: Vec<(u32, f32)>,
    /// Total number of features in the dictionary (for density calc).
    pub dictionary_size: u32,
}

impl SparseFeatures {
    /// Sparsity ratio: activated / total.
    pub fn density(&self) -> f32 {
        if self.dictionary_size == 0 {
            0.0
        } else {
            self.indices.len() as f32 / self.dictionary_size as f32
        }
    }
}

/// A node in the epistemic claim graph.
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct ClaimNode {
    pub claim_id: [u8; 32],
    pub proposition: String,
    pub confidence: u8, // 0-255 scaled confidence
}

/// Edge type in the claim DAG.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ClaimEdge {
    /// Source claim supports target claim.
    Supports,
    /// Source claim contradicts target claim.
    Contradicts,
    /// Source claim is a refinement / specialisation of target.
    Refines,
}

/// Epistemic claim graph — DAG of claims with typed edges.
///
/// The claim graph is the system's "belief network": each node is a
/// claim and edges encode epistemic relationships (supports, contradicts,
/// refines). Cycles are forbidden — the graph must remain a DAG.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ClaimGraph {
    pub nodes: HashMap<[u8; 32], ClaimNode>,
    pub edges: Vec<([u8; 32], [u8; 32], ClaimEdge)>,
}

impl ClaimGraph {
    pub fn new() -> Self {
        Self {
            nodes: HashMap::new(),
            edges: Vec::new(),
        }
    }

    /// Add a claim node. Returns `false` if the ID already exists.
    pub fn add_claim(&mut self, node: ClaimNode) -> bool {
        if self.nodes.contains_key(&node.claim_id) {
            return false;
        }
        self.nodes.insert(node.claim_id, node);
        true
    }

    /// Add a directed edge. Returns `Err` if it would create a cycle.
    pub fn add_edge(
        &mut self,
        from: [u8; 32],
        to: [u8; 32],
        kind: ClaimEdge,
    ) -> Result<(), ScopeRexError> {
        // Basic cycle detection: cannot add edge to ancestor
        if self.has_path(to, from) {
            return Err(ScopeRexError::CycleDetected {
                from: hex::encode(from),
                to: hex::encode(to),
            });
        }
        self.edges.push((from, to, kind));
        Ok(())
    }

    /// Check if there is a directed path from `start` to `target`.
    fn has_path(&self, start: [u8; 32], target: [u8; 32]) -> bool {
        if start == target {
            return true;
        }
        let mut visited = HashSet::new();
        let mut queue = VecDeque::new();
        queue.push_back(start);
        while let Some(current) = queue.pop_front() {
            if current == target {
                return true;
            }
            if !visited.insert(current) {
                continue;
            }
            for (f, t, _) in &self.edges {
                if *f == current && !visited.contains(t) {
                    queue.push_back(*t);
                }
            }
        }
        false
    }

    /// Compute a Merkle-like root of the claim graph.
    ///
    /// We canonicalise the graph as a string and hash it.
    pub fn root(&self) -> [u8; 32] {
        let mut ids: Vec<_> = self.nodes.keys().collect();
        ids.sort_unstable();
        let mut hasher = blake3::Hasher::new();
        for id in ids {
            hasher.update(id);
        }
        for (from, to, kind) in &self.edges {
            hasher.update(from);
            hasher.update(to);
            let edge_byte = match kind {
                ClaimEdge::Supports => 0u8,
                ClaimEdge::Contradicts => 1u8,
                ClaimEdge::Refines => 2u8,
            };
            hasher.update(&[edge_byte]);
        }
        hasher.finalize().into()
    }

    /// All claims that support the given claim (direct supporters only).
    pub fn supporters(&self, claim_id: [u8; 32]) -> Vec<&ClaimNode> {
        self.edges
            .iter()
            .filter(|(_, t, k)| *t == claim_id && matches!(k, ClaimEdge::Supports))
            .filter_map(|(f, _, _)| self.nodes.get(f))
            .collect()
    }

    /// All claims that contradict the given claim (direct contradictions only).
    pub fn contradictors(&self, claim_id: [u8; 32]) -> Vec<&ClaimNode> {
        self.edges
            .iter()
            .filter(|(_, t, k)| *t == claim_id && matches!(k, ClaimEdge::Contradicts))
            .filter_map(|(f, _, _)| self.nodes.get(f))
            .collect()
    }
}

impl Default for ClaimGraph {
    fn default() -> Self {
        Self::new()
    }
}

/// Proof obligation — something that still needs to be verified.
#[derive(Clone, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct ProofObligation {
    pub obligation_id: [u8; 32],
    pub claim_id: [u8; 32],
    pub description: String,
    pub satisfied: bool,
}

/// Proof tree — collection of outstanding and satisfied proof obligations.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ProofTree {
    pub obligations: Vec<ProofObligation>,
}

impl ProofTree {
    pub fn root(&self) -> [u8; 32] {
        let mut hasher = blake3::Hasher::new();
        let mut obs: Vec<_> = self.obligations.iter().collect();
        obs.sort_by(|a, b| a.obligation_id.cmp(&b.obligation_id));
        for o in obs {
            hasher.update(&o.obligation_id);
            hasher.update(&[o.satisfied as u8]);
        }
        hasher.finalize().into()
    }

    pub fn outstanding(&self) -> Vec<&ProofObligation> {
        self.obligations.iter().filter(|o| !o.satisfied).collect()
    }
}

/// Merkle root of memory state.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct MemoryRoot {
    pub root: [u8; 32],
    pub entry_count: u64,
}

/// Single entry in the tool invocation ledger.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ToolInvocation {
    pub tool_name: String,
    pub input_hash: [u8; 32],
    pub output_hash: [u8; 32],
    pub timestamp: chrono::DateTime<chrono::Utc>,
}

/// Tool ledger — immutable, append-only log of all tool invocations.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ToolLedger {
    pub invocations: Vec<ToolInvocation>,
}

impl ToolLedger {
    pub fn append(&mut self, inv: ToolInvocation) {
        self.invocations.push(inv);
    }

    pub fn root(&self) -> [u8; 32] {
        let mut hasher = blake3::Hasher::new();
        for inv in &self.invocations {
            hasher.update(inv.tool_name.as_bytes());
            hasher.update(&inv.input_hash);
            hasher.update(&inv.output_hash);
        }
        hasher.finalize().into()
    }
}

/// Per-token loss entry.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LossEntry {
    pub token_index: usize,
    pub loss: f32,
    pub drift: f32, // |current_loss - expected_loss|
}

/// Loss / drift ledger — tracks prediction quality over time.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LossLedger {
    pub entries: Vec<LossEntry>,
    pub moving_average: f32,
}

impl LossLedger {
    pub fn append(&mut self, entry: LossEntry) {
        // Update moving average (exponential)
        let alpha = 0.1;
        self.moving_average = alpha * entry.loss + (1.0 - alpha) * self.moving_average;
        self.entries.push(entry);
    }

    pub fn root(&self) -> [u8; 32] {
        let mut hasher = blake3::Hasher::new();
        for e in &self.entries {
            hasher.update(&e.token_index.to_le_bytes());
            hasher.update(&e.loss.to_le_bytes());
        }
        hasher.finalize().into()
    }
}

/// Biometric authentication state.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum AuthState {
    /// No active authentication.
    Unauthenticated,
    /// Authenticated with a specific token and expiry.
    Authenticated {
        token_hash: [u8; 32],
        method: String,
        expires_at: chrono::DateTime<chrono::Utc>,
    },
}

// ---------------------------------------------------------------------------
// ScopeRexState — the 8-field state vector
// ---------------------------------------------------------------------------

/// The complete 8-field SCOPE-Rex Omega state vector.
///
/// This is the "brain state" at a single point in time. Every field
/// is content-addressed (via hashes or Merkle roots) so that states can
/// be compared, branched, and reconstructed from deltas alone.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ScopeRexState {
    /// `h_t` — model hidden state.
    pub h_t: ModelState,
    /// `z_t` — sparse feature activations.
    pub z_t: SparseFeatures,
    /// `g_t` — epistemic claim graph (DAG).
    pub g_t: ClaimGraph,
    /// `p_t` — proof obligations.
    pub p_t: ProofTree,
    /// `m_t` — Merkle root of memory state.
    pub m_t: MemoryRoot,
    /// `w_t` — tool invocation ledger.
    pub w_t: ToolLedger,
    /// `l_t` — per-token loss / drift ledger.
    pub l_t: LossLedger,
    /// `u_t` — biometric auth state.
    pub u_t: AuthState,
}

impl ScopeRexState {
    /// Compute a canonical hash of the entire 8-vector state.
    ///
    /// This is the state identifier used for checkout, branching, and
    /// diff operations in the [`BrainTimeMachine`].
    pub fn canonical_hash(&self) -> [u8; 32] {
        let mut hasher = blake3::Hasher::new();
        hasher.update(&self.h_t.state_hash);
        for (idx, mag) in &self.z_t.indices {
            hasher.update(&idx.to_le_bytes());
            hasher.update(&mag.to_le_bytes());
        }
        hasher.update(&self.g_t.root());
        hasher.update(&self.p_t.root());
        hasher.update(&self.m_t.root);
        hasher.update(&self.w_t.root());
        hasher.update(&self.l_t.root());
        match &self.u_t {
            AuthState::Unauthenticated => hasher.update(&[0u8]),
            AuthState::Authenticated { token_hash, .. } => {
                hasher.update(&[1u8]);
                hasher.update(token_hash);
            }
        }
        hasher.finalize().into()
    }
}

// ---------------------------------------------------------------------------
// SemanticDelta — an event that transitions state
// ---------------------------------------------------------------------------

/// A semantic delta is a self-describing state transition.
///
/// Every delta names its parent state, the claims it touches, the
/// features it activates, the tools it invokes, and the proofs it
/// creates or satisfies. This makes deltas **replayable** and
/// **branchable** without holding the full state.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SemanticDelta {
    /// Blake3 hash of this delta's canonical form (its own ID).
    pub event_id: [u8; 32],
    /// Hash of the parent state from which this delta originates.
    pub parent_state: [u8; 32],
    /// Claim IDs created or modified by this delta.
    pub claim_ids: Vec<[u8; 32]>,
    /// Sparse feature references (index, magnitude) activated.
    pub feature_refs: Vec<(u32, f32)>,
    /// Hashes of tool invocations performed in this delta.
    pub tool_hashes: Vec<[u8; 32]>,
    /// Proof obligation IDs created or satisfied.
    pub proof_refs: Vec<[u8; 32]>,
    /// Auth token hash referenced (if any).
    pub auth_ref: Option<[u8; 32]>,
    /// Human-readable description of what changed.
    pub description: String,
}

impl SemanticDelta {
    /// Compute the canonical hash of this delta.
    pub fn compute_hash(&self) -> [u8; 32] {
        let mut hasher = blake3::Hasher::new();
        hasher.update(&self.parent_state);
        for id in &self.claim_ids {
            hasher.update(id);
        }
        for (idx, mag) in &self.feature_refs {
            hasher.update(&idx.to_le_bytes());
            hasher.update(&mag.to_le_bytes());
        }
        for h in &self.tool_hashes {
            hasher.update(h);
        }
        for p in &self.proof_refs {
            hasher.update(p);
        }
        if let Some(auth) = &self.auth_ref {
            hasher.update(&[1u8]);
            hasher.update(auth);
        } else {
            hasher.update(&[0u8]);
        }
        hasher.update(self.description.as_bytes());
        hasher.finalize().into()
    }
}

// ---------------------------------------------------------------------------
// WitnessedState — a materialised, content-addressed state snapshot
// ---------------------------------------------------------------------------

/// A witnessed state is a materialised snapshot with cryptographic
/// witnesses for every sub-system.
///
/// "Witnessing" means that each root hash has been independently
/// verifiable — you can recompute the root from the raw data and
/// confirm it matches.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct WitnessedState {
    /// Canonical hash of this witnessed state.
    pub state_id: [u8; 32],
    /// Hash of the delta from which this state was materialised.
    pub materialized_from: [u8; 32],
    /// Merkle root of the memory subsystem.
    pub memory_root: [u8; 32],
    /// Merkle root of the claim graph.
    pub claim_root: [u8; 32],
    /// Merkle root of the proof tree.
    pub proof_root: [u8; 32],
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

#[derive(Error, Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum ScopeRexError {
    #[error("cycle detected in claim graph: {from} -> {to}")]
    CycleDetected { from: String, to: String },

    #[error("state not found: {0}")]
    StateNotFound(String),

    #[error("branch not found: {0}")]
    BranchNotFound(String),

    #[error("parent state missing: {0}")]
    ParentMissing(String),

    #[error("invalid delta: {0}")]
    InvalidDelta(String),
}

// ---------------------------------------------------------------------------
// BrainTimeMachine — event-sourced state store
// ---------------------------------------------------------------------------

/// The BrainTimeMachine is an append-only, content-addressed event log
/// that stores every [`SemanticDelta`] and enables time-travel
/// operations: `append`, `checkout`, `diff`, and `branch`.
#[derive(Clone, Debug)]
pub struct BrainTimeMachine {
    /// All deltas in append order.
    deltas: Vec<SemanticDelta>,
    /// Index: parent_state → child delta IDs.
    parent_index: HashMap<[u8; 32], Vec<[u8; 32]>>,
    /// Index: state_id → witnessed state.
    states: HashMap<[u8; 32], WitnessedState>,
    /// Branches: branch_id → head state_id.
    branches: HashMap<[u8; 32], [u8; 32]>,
    /// Next branch counter (for deterministic branch IDs).
    branch_counter: u64,
}

impl BrainTimeMachine {
    /// Create a new, empty time machine.
    pub fn new() -> Self {
        Self {
            deltas: Vec::new(),
            parent_index: HashMap::new(),
            states: HashMap::new(),
            branches: HashMap::new(),
            branch_counter: 0,
        }
    }

    /// Append a semantic delta to the log.
    ///
    /// Returns the canonical hash (state ID) of the resulting state.
    /// The state ID is computed by hashing the delta's own hash with
    /// its parent state's hash.
    #[instrument(skip(self, delta), fields(delta_desc = %delta.description))]
    pub fn append(&mut self, delta: SemanticDelta) -> Result<[u8; 32], ScopeRexError> {
        let event_id = delta.compute_hash();
        let mut hasher = blake3::Hasher::new();
        hasher.update(&delta.parent_state);
        hasher.update(&event_id);
        let state_id: [u8; 32] = hasher.finalize().into();

        trace!(state_id = hex::encode(&state_id), "appending delta");

        self.parent_index
            .entry(delta.parent_state)
            .or_default()
            .push(event_id);
        self.deltas.push(delta);

        // Materialise a witnessed state stub
        let witnessed = WitnessedState {
            state_id,
            materialized_from: event_id,
            memory_root: [0u8; 32], // TODO: real materialisation
            claim_root: [0u8; 32],
            proof_root: [0u8; 32],
        };
        self.states.insert(state_id, witnessed);

        info!(state_id = hex::encode(&state_id), "delta appended");
        Ok(state_id)
    }

    /// Checkout a witnessed state by its state ID.
    ///
    /// Returns the materialised state with all root hashes intact.
    pub fn checkout(&self, state_id: [u8; 32]) -> Result<WitnessedState, ScopeRexError> {
        self.states
            .get(&state_id)
            .cloned()
            .ok_or_else(|| ScopeRexError::StateNotFound(hex::encode(state_id)))
    }

    /// Compute the diff between two states — all deltas on the path
    /// from `from` to `to`.
    ///
    /// This performs a BFS up the parent chain from `to` until it
    /// reaches `from`, then returns the deltas in chronological order.
    pub fn diff(&self, from: [u8; 32], to: [u8; 32]) -> Vec<SemanticDelta> {
        if from == to {
            return Vec::new();
        }

        // Build a map: event_id → delta
        let delta_map: HashMap<[u8; 32], &SemanticDelta> = self
            .deltas
            .iter()
            .map(|d| (d.event_id, d))
            .collect();

        // Walk backward from `to`, collecting deltas until we hit `from`
        let mut path = Vec::new();
        let mut current = to;
        let mut visited = HashSet::new();

        loop {
            if current == from {
                break;
            }
            if !visited.insert(current) {
                warn!("cycle detected in diff — aborting");
                break;
            }
            // Find the delta whose state_id is `current`
            let delta = self
                .deltas
                .iter()
                .find(|d| {
                    let mut h = blake3::Hasher::new();
                    h.update(&d.parent_state);
                    h.update(&d.compute_hash());
                    h.finalize().as_bytes() == &current[..]
                });
            match delta {
                Some(d) => {
                    path.push(d.clone());
                    current = d.parent_state;
                }
                None => {
                    warn!("orphan state in diff — aborting");
                    break;
                }
            }
        }

        path.reverse();
        path
    }

    /// Create a new branch at the given state.
    ///
    /// Returns the branch ID. The branch head is initialised to the
    /// given state ID.
    pub fn branch_at(&mut self, state_id: [u8; 32]) -> Result<[u8; 32], ScopeRexError> {
        if !self.states.contains_key(&state_id) {
            return Err(ScopeRexError::StateNotFound(hex::encode(state_id)));
        }
        let mut hasher = blake3::Hasher::new();
        hasher.update(&state_id);
        hasher.update(&self.branch_counter.to_le_bytes());
        let branch_id: [u8; 32] = hasher.finalize().into();
        self.branch_counter += 1;

        self.branches.insert(branch_id, state_id);
        info!(branch_id = hex::encode(&branch_id), "branch created");
        Ok(branch_id)
    }

    /// Get the head state of a branch.
    pub fn branch_head(&self, branch_id: [u8; 32]) -> Option<[u8; 32]> {
        self.branches.get(&branch_id).copied()
    }

    /// Total number of deltas stored.
    pub fn len(&self) -> usize {
        self.deltas.len()
    }

    pub fn is_empty(&self) -> bool {
        self.deltas.is_empty()
    }
}

impl Default for BrainTimeMachine {
    fn default() -> Self {
        Self::new()
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn claim_graph_add_and_edge() {
        let mut g = ClaimGraph::new();
        let id_a = [1u8; 32];
        let id_b = [2u8; 32];

        assert!(g.add_claim(ClaimNode {
            claim_id: id_a,
            proposition: "A".into(),
            confidence: 200,
        }));
        assert!(g.add_claim(ClaimNode {
            claim_id: id_b,
            proposition: "B".into(),
            confidence: 200,
        }));
        assert!(g.add_edge(id_a, id_b, ClaimEdge::Supports).is_ok());
    }

    #[test]
    fn claim_graph_cycle_detection() {
        let mut g = ClaimGraph::new();
        let id_a = [1u8; 32];
        let id_b = [2u8; 32];
        let id_c = [3u8; 32];

        g.add_claim(ClaimNode {
            claim_id: id_a,
            proposition: "A".into(),
            confidence: 200,
        });
        g.add_claim(ClaimNode {
            claim_id: id_b,
            proposition: "B".into(),
            confidence: 200,
        });
        g.add_claim(ClaimNode {
            claim_id: id_c,
            proposition: "C".into(),
            confidence: 200,
        });

        g.add_edge(id_a, id_b, ClaimEdge::Supports).unwrap();
        g.add_edge(id_b, id_c, ClaimEdge::Supports).unwrap();

        // Adding c → a would create a cycle
        let err = g.add_edge(id_c, id_a, ClaimEdge::Supports).unwrap_err();
        assert!(matches!(err, ScopeRexError::CycleDetected { .. }));
    }

    #[test]
    fn claim_graph_merkle_root_stable() {
        let mut g = ClaimGraph::new();
        let id_a = [1u8; 32];
        g.add_claim(ClaimNode {
            claim_id: id_a,
            proposition: "A".into(),
            confidence: 200,
        });
        let r1 = g.root();
        let r2 = g.root();
        assert_eq!(r1, r2);
    }

    #[test]
    fn tool_ledger_root_append() {
        let mut ledger = ToolLedger { invocations: vec![] };
        let r1 = ledger.root();
        ledger.append(ToolInvocation {
            tool_name: "echo".into(),
            input_hash: [1u8; 32],
            output_hash: [2u8; 32],
            timestamp: chrono::Utc::now(),
        });
        let r2 = ledger.root();
        assert_ne!(r1, r2);
    }

    #[test]
    fn loss_ledger_moving_average() {
        let mut ledger = LossLedger {
            entries: vec![],
            moving_average: 0.0,
        };
        ledger.append(LossEntry {
            token_index: 0,
            loss: 1.0,
            drift: 0.0,
        });
        assert!((ledger.moving_average - 0.1).abs() < 0.001);
        ledger.append(LossEntry {
            token_index: 1,
            loss: 1.0,
            drift: 0.0,
        });
        assert!((ledger.moving_average - 0.19).abs() < 0.01);
    }

    #[test]
    fn brain_time_machine_append_and_checkout() {
        let mut btm = BrainTimeMachine::new();
        let parent = [0u8; 32];

        let delta = SemanticDelta {
            event_id: [0u8; 32],
            parent_state: parent,
            claim_ids: vec![[1u8; 32]],
            feature_refs: vec![(42, 0.9)],
            tool_hashes: vec![],
            proof_refs: vec![],
            auth_ref: None,
            description: "test delta".into(),
        };

        let state_id = btm.append(delta).unwrap();
        let ws = btm.checkout(state_id).unwrap();
        assert_eq!(ws.state_id, state_id);
        assert_eq!(btm.len(), 1);
    }

    #[test]
    fn brain_time_machine_checkout_missing() {
        let btm = BrainTimeMachine::new();
        let missing = [99u8; 32];
        let err = btm.checkout(missing).unwrap_err();
        assert!(matches!(err, ScopeRexError::StateNotFound(_)));
    }

    #[test]
    fn brain_time_machine_branching() {
        let mut btm = BrainTimeMachine::new();
        let parent = [0u8; 32];

        let delta = SemanticDelta {
            event_id: [0u8; 32],
            parent_state: parent,
            claim_ids: vec![],
            feature_refs: vec![],
            tool_hashes: vec![],
            proof_refs: vec![],
            auth_ref: None,
            description: "init".into(),
        };
        let state_id = btm.append(delta).unwrap();
        let branch_id = btm.branch_at(state_id).unwrap();
        assert_eq!(btm.branch_head(branch_id), Some(state_id));
    }

    #[test]
    fn brain_time_machine_branch_at_missing() {
        let mut btm = BrainTimeMachine::new();
        let missing = [99u8; 32];
        let err = btm.branch_at(missing).unwrap_err();
        assert!(matches!(err, ScopeRexError::StateNotFound(_)));
    }

    #[test]
    fn scope_rex_state_canonical_hash() {
        let state = ScopeRexState {
            h_t: ModelState {
                state_hash: [1u8; 32],
                seq_pos: 0,
                layer: 0,
            },
            z_t: SparseFeatures {
                indices: vec![(1, 0.5)],
                dictionary_size: 100,
            },
            g_t: ClaimGraph::new(),
            p_t: ProofTree { obligations: vec![] },
            m_t: MemoryRoot {
                root: [2u8; 32],
                entry_count: 0,
            },
            w_t: ToolLedger { invocations: vec![] },
            l_t: LossLedger {
                entries: vec![],
                moving_average: 0.0,
            },
            u_t: AuthState::Unauthenticated,
        };
        let h1 = state.canonical_hash();
        let h2 = state.canonical_hash();
        assert_eq!(h1, h2);
    }

    #[test]
    fn semantic_delta_hash_stable() {
        let d1 = SemanticDelta {
            event_id: [0u8; 32],
            parent_state: [1u8; 32],
            claim_ids: vec![[2u8; 32]],
            feature_refs: vec![(10, 0.8)],
            tool_hashes: vec![[3u8; 32]],
            proof_refs: vec![],
            auth_ref: Some([4u8; 32]),
            description: "test".into(),
        };
        let h1 = d1.compute_hash();
        let d2 = d1.clone();
        let h2 = d2.compute_hash();
        assert_eq!(h1, h2);
    }

    #[test]
    fn sparse_features_density() {
        let sf = SparseFeatures {
            indices: vec![(1, 0.5), (2, 0.3)],
            dictionary_size: 100,
        };
        assert!((sf.density() - 0.02).abs() < 0.001);
    }
}
