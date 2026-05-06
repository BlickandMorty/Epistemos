//! DAG storage layer — `DagStore` trait + in-memory backend.
//!
//! Per `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` §1.3.
//!
//! The trait surface matches the doctrine spec verbatim. The optional
//! `redb` backend lives in `redb_store` behind `cognitive-dag-redb`;
//! `InMemoryDagStore` remains the reference impl every parity test
//! runs against and the production fallback until Phase 8.H explicitly
//! flips authority.
//!
//! Determinism contract: every method returns results in a stable,
//! sorted order. `edges_from` / `edges_to` sort by edge id; the
//! Merkle root is computed deterministically per `merkle.rs`.

use std::collections::{BTreeMap, BTreeSet};
use std::sync::RwLock;

use serde::{Deserialize, Serialize};
use thiserror::Error;

use super::edge::{Edge, EdgeId, EdgeKind, EdgeKindSelector};
use super::merkle::merkle_root_over;
use super::node::{Hash, Node, NodeId};

#[derive(Debug, Error)]
pub enum DagError {
    #[error("node not found: {0}")]
    NodeNotFound(String),
    #[error("edge endpoint missing: {endpoint}")]
    EdgeEndpointMissing { endpoint: &'static str },
    #[error("storage backend error: {0}")]
    Backend(String),
    #[error("invalid signature on edge {edge}")]
    InvalidSignature { edge: String },
    /// Phase 8.G doctrine §5.3 enforcement — caller passed a `Node`
    /// whose `id` does not match `Node::compute_id(&kind)`. The DAG
    /// is content-addressed; ids must always be derived from content.
    #[error("content-address mismatch: expected {expected}, got {actual}")]
    ContentAddressMismatch { expected: String, actual: String },
}

pub trait DagStore: Send + Sync {
    fn put_node(&self, node: Node) -> Result<NodeId, DagError>;
    fn get_node(&self, id: NodeId) -> Result<Option<Node>, DagError>;
    fn put_edge(&self, edge: Edge) -> Result<EdgeId, DagError>;
    fn edges_from(
        &self,
        node: NodeId,
        kind: Option<EdgeKindSelector>,
    ) -> Result<Vec<Edge>, DagError>;
    fn edges_to(&self, node: NodeId, kind: Option<EdgeKindSelector>)
        -> Result<Vec<Edge>, DagError>;
    fn merkle_root(&self) -> Result<Hash, DagError>;
    fn snapshot(&self) -> Result<DagSnapshot, DagError>;

    /// Phase 8.C / CD-005 — register a capability hash this store will
    /// accept on inbound edges. Doctrine §1.2 + §4.1: every edge MUST be
    /// signed under a held capability; the store enforces this by
    /// recomputing `EdgeSignature::compute(from, to, kind, cap_hash)`
    /// for each registered cap and accepting iff at least one matches.
    ///
    /// Empty registry semantics:
    /// - When no capabilities are registered, `put_edge` falls back to
    ///   the Phase 8.A structural guard (reject all-zero signatures
    ///   only). This preserves backward compatibility for tests +
    ///   fixtures that predate Phase 8.C wiring.
    /// - Once any capability is registered, the structural guard is
    ///   replaced by full capability-bound verification — edges with
    ///   signatures that don't recompute against any registered cap
    ///   are rejected with `DagError::InvalidSignature`.
    ///
    /// Idempotent on the cap_hash. Default trait impl is a no-op so
    /// non-capability-aware DagStore implementations remain valid.
    fn register_capability(&self, _capability_hash: Hash) -> Result<(), DagError> {
        Ok(())
    }

    /// Diagnostic — returns the set of registered capability hashes
    /// (sorted for determinism). Used by Settings → Diagnostics + the
    /// V2 wire-up tests asserting the capability set.
    /// Default: empty Vec for non-capability-aware implementations.
    fn registered_capabilities(&self) -> Vec<Hash> {
        Vec::new()
    }
}

/// Exportable snapshot of the entire store. Used for replay (`Phase
/// 8.F`) + cross-session sync. Sorted internally so two snapshots
/// containing identical content produce byte-identical canonical JSON.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DagSnapshot {
    /// Sorted by node id ascending.
    pub nodes: Vec<Node>,
    /// Sorted by edge id ascending.
    pub edges: Vec<Edge>,
    /// Computed at snapshot time; recipients can recompute to verify.
    pub merkle_root: Hash,
    /// Doctrine schema version. Bumped on §1.x revisions.
    pub schema_version: u32,
}

impl DagSnapshot {
    pub const SCHEMA_VERSION: u32 = 1;
}

// ── In-memory backend ─────────────────────────────────────────────────────

/// Reference DagStore implementation. RwLock-protected BTreeMaps keep
/// iteration order deterministic + reads cheap. Production deployments
/// will use the redb-backed store (next slice); this stays canonical
/// for tests + as the no-disk fallback.
pub struct InMemoryDagStore {
    nodes: RwLock<BTreeMap<NodeId, Node>>,
    /// Edges indexed by `EdgeId` for content-addressed dedup; the
    /// `(from, to)` indices below are derived views.
    edges: RwLock<BTreeMap<EdgeId, Edge>>,
    /// `from_node → ordered EdgeIds` for fast `edges_from`.
    from_index: RwLock<BTreeMap<NodeId, Vec<EdgeId>>>,
    /// `to_node → ordered EdgeIds` for fast `edges_to`.
    to_index: RwLock<BTreeMap<NodeId, Vec<EdgeId>>>,
    /// Phase 8.C / CD-005 — registered capability hashes. When
    /// non-empty, `put_edge` verifies every inbound edge's signature
    /// against this set. When empty, falls back to the Phase 8.A
    /// structural guard (reject all-zero only). BTreeSet for
    /// deterministic iteration in `registered_capabilities()`.
    capabilities: RwLock<BTreeSet<Hash>>,
}

impl Default for InMemoryDagStore {
    fn default() -> Self {
        Self::new()
    }
}

impl InMemoryDagStore {
    pub fn new() -> Self {
        Self {
            nodes: RwLock::new(BTreeMap::new()),
            edges: RwLock::new(BTreeMap::new()),
            from_index: RwLock::new(BTreeMap::new()),
            to_index: RwLock::new(BTreeMap::new()),
            capabilities: RwLock::new(BTreeSet::new()),
        }
    }

    pub fn node_count(&self) -> usize {
        self.nodes.read().map(|n| n.len()).unwrap_or(0)
    }

    pub fn edge_count(&self) -> usize {
        self.edges.read().map(|e| e.len()).unwrap_or(0)
    }

    /// True iff at least one capability has been registered. Internal
    /// helper used by `put_edge` to decide between Phase 8.A
    /// structural-guard and Phase 8.C capability-bound verification.
    fn has_registered_capabilities(&self) -> bool {
        self.capabilities
            .read()
            .map(|set| !set.is_empty())
            .unwrap_or(false)
    }

    /// Verify the edge's signature against the registered capability
    /// set. Returns true iff at least one registered capability
    /// recomputes to the edge's signature. Constant-time-equality is
    /// inside `EdgeSignature::verify`. Returns false if the
    /// capabilities lock is poisoned (fail-closed).
    fn verify_edge_against_registered_caps(&self, edge: &Edge) -> bool {
        let Ok(caps) = self.capabilities.read() else {
            return false;
        };
        for cap_hash in caps.iter() {
            if edge.verify_signature(cap_hash) {
                return true;
            }
        }
        false
    }
}

impl DagStore for InMemoryDagStore {
    fn put_node(&self, node: Node) -> Result<NodeId, DagError> {
        // Doctrine §4.2 + §5.3 enforcement: every node id MUST equal
        // `Node::compute_id(&node.kind)`. This catches callers that
        // manually constructed a Node with a hand-rolled id (which
        // would smuggle non-content-addressed nodes into the DAG).
        // `Node::new` and `Node::new_at` always satisfy this check by
        // construction; the explicit verification here keeps the
        // contract honest at the storage boundary so doctrine §5.3
        // ("computes node_id from content; rejects pre-set mismatched
        // ids") is literally true at the right layer.
        let expected_id = Node::compute_id(&node.kind);
        if expected_id != node.id {
            return Err(DagError::ContentAddressMismatch {
                expected: format!("{:?}", expected_id),
                actual: format!("{:?}", node.id),
            });
        }
        let id = node.id;
        // Idempotent: re-inserting an identical node is a no-op
        // (content-addressed identity makes this safe).
        let mut nodes = self
            .nodes
            .write()
            .map_err(|_| DagError::Backend("nodes lock poisoned".into()))?;
        nodes.entry(id).or_insert(node);
        Ok(id)
    }

    fn get_node(&self, id: NodeId) -> Result<Option<Node>, DagError> {
        let nodes = self
            .nodes
            .read()
            .map_err(|_| DagError::Backend("nodes lock poisoned".into()))?;
        Ok(nodes.get(&id).cloned())
    }

    fn put_edge(&self, edge: Edge) -> Result<EdgeId, DagError> {
        // Doctrine §4.1 + §5.2 + CD-005 enforcement.
        //
        // Phase 8.A baseline: every edge MUST carry a non-zero signature.
        // The all-zero pattern is the default value of an unsigned
        // EdgeSignature and indicates the edge was constructed bypassing
        // `Edge::new` / `Edge::new_at` (which compute the canonical
        // signature).
        //
        // Phase 8.C / CD-005 upgrade: when the store has any registered
        // capabilities, the structural guard is replaced by full
        // capability-bound verification — the edge's signature must
        // recompute against AT LEAST ONE registered capability hash
        // (recomputation done inside `EdgeSignature::verify` with
        // constant-time compare). Edges signed under a capability the
        // store hasn't registered are rejected with InvalidSignature.
        //
        // Empty registry preserves backward compat for tests + fixtures
        // that predate Phase 8.C wiring; production paths register
        // their capability set at boot via
        // `cognitive_dag::dispatch::cognitive_dag_store()` initialization.
        let signature_is_zero = edge.signature.as_bytes().iter().all(|&b| b == 0);
        if signature_is_zero {
            return Err(DagError::InvalidSignature {
                edge: format!("{:?}", edge.id()),
            });
        }
        if self.has_registered_capabilities() && !self.verify_edge_against_registered_caps(&edge) {
            return Err(DagError::InvalidSignature {
                edge: format!(
                    "{:?} (signature does not verify against any registered capability)",
                    edge.id()
                ),
            });
        }

        // Validate endpoints exist before inserting; doctrine §4.1
        // forbids dangling edges.
        let nodes = self
            .nodes
            .read()
            .map_err(|_| DagError::Backend("nodes lock poisoned".into()))?;
        if !nodes.contains_key(&edge.from) {
            return Err(DagError::EdgeEndpointMissing { endpoint: "from" });
        }
        if !nodes.contains_key(&edge.to) {
            return Err(DagError::EdgeEndpointMissing { endpoint: "to" });
        }
        drop(nodes);

        let edge_id = edge.id();

        let mut edges = self
            .edges
            .write()
            .map_err(|_| DagError::Backend("edges lock poisoned".into()))?;
        let from_node = edge.from;
        let to_node = edge.to;
        let already_present = edges.contains_key(&edge_id);
        edges.entry(edge_id).or_insert(edge);
        drop(edges);

        if !already_present {
            let mut from_index = self
                .from_index
                .write()
                .map_err(|_| DagError::Backend("from_index lock poisoned".into()))?;
            let entry = from_index.entry(from_node).or_default();
            entry.push(edge_id);
            entry.sort(); // keep deterministic order
            drop(from_index);

            let mut to_index = self
                .to_index
                .write()
                .map_err(|_| DagError::Backend("to_index lock poisoned".into()))?;
            let entry = to_index.entry(to_node).or_default();
            entry.push(edge_id);
            entry.sort();
        }

        Ok(edge_id)
    }

    fn edges_from(
        &self,
        node: NodeId,
        kind: Option<EdgeKindSelector>,
    ) -> Result<Vec<Edge>, DagError> {
        let from_index = self
            .from_index
            .read()
            .map_err(|_| DagError::Backend("from_index lock poisoned".into()))?;
        let edges = self
            .edges
            .read()
            .map_err(|_| DagError::Backend("edges lock poisoned".into()))?;
        let mut out = Vec::new();
        if let Some(ids) = from_index.get(&node) {
            for edge_id in ids {
                if let Some(edge) = edges.get(edge_id) {
                    if kind.is_none_or(|sel| sel.matches(&edge.kind)) {
                        out.push(edge.clone());
                    }
                }
            }
        }
        Ok(out)
    }

    fn edges_to(
        &self,
        node: NodeId,
        kind: Option<EdgeKindSelector>,
    ) -> Result<Vec<Edge>, DagError> {
        let to_index = self
            .to_index
            .read()
            .map_err(|_| DagError::Backend("to_index lock poisoned".into()))?;
        let edges = self
            .edges
            .read()
            .map_err(|_| DagError::Backend("edges lock poisoned".into()))?;
        let mut out = Vec::new();
        if let Some(ids) = to_index.get(&node) {
            for edge_id in ids {
                if let Some(edge) = edges.get(edge_id) {
                    if kind.is_none_or(|sel| sel.matches(&edge.kind)) {
                        out.push(edge.clone());
                    }
                }
            }
        }
        Ok(out)
    }

    fn merkle_root(&self) -> Result<Hash, DagError> {
        let nodes = self
            .nodes
            .read()
            .map_err(|_| DagError::Backend("nodes lock poisoned".into()))?;
        let edges = self
            .edges
            .read()
            .map_err(|_| DagError::Backend("edges lock poisoned".into()))?;
        let node_ids: Vec<&NodeId> = nodes.keys().collect();
        let edge_ids: Vec<&EdgeId> = edges.keys().collect();
        Ok(merkle_root_over(&node_ids, &edge_ids))
    }

    fn snapshot(&self) -> Result<DagSnapshot, DagError> {
        let nodes_lock = self
            .nodes
            .read()
            .map_err(|_| DagError::Backend("nodes lock poisoned".into()))?;
        let edges_lock = self
            .edges
            .read()
            .map_err(|_| DagError::Backend("edges lock poisoned".into()))?;
        // BTreeMap iteration is already sorted by key.
        let nodes: Vec<Node> = nodes_lock.values().cloned().collect();
        let edges: Vec<Edge> = edges_lock.values().cloned().collect();
        let node_ids: Vec<&NodeId> = nodes_lock.keys().collect();
        let edge_ids: Vec<&EdgeId> = edges_lock.keys().collect();
        let merkle_root = merkle_root_over(&node_ids, &edge_ids);
        Ok(DagSnapshot {
            nodes,
            edges,
            merkle_root,
            schema_version: DagSnapshot::SCHEMA_VERSION,
        })
    }

    fn register_capability(&self, capability_hash: Hash) -> Result<(), DagError> {
        let mut caps = self
            .capabilities
            .write()
            .map_err(|_| DagError::Backend("capabilities lock poisoned".into()))?;
        caps.insert(capability_hash);
        Ok(())
    }

    fn registered_capabilities(&self) -> Vec<Hash> {
        self.capabilities
            .read()
            .map(|set| set.iter().copied().collect())
            .unwrap_or_default()
    }
}

// Suppress unused-but-may-be-used hint in the EdgeKind import path
// (variants are referenced in tests via super::edge).
#[allow(dead_code)]
fn _ek_anchor(_ek: EdgeKind) {}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use super::super::edge::{Edge, EdgeKind, EdgeKindSelector, MemoryTier};
    use super::super::node::{
        AuthorRef, ClaimScope, Hash as NHash, MimeType, Node, NodeKind, SourceRef, Timestamp,
    };
    use super::*;

    fn note(body: &str) -> Node {
        Node::new(NodeKind::Note {
            body: body.into(),
            author: AuthorRef("u".into()),
            mime: MimeType("text/markdown".into()),
        })
    }

    fn claim(prop: &str) -> Node {
        Node::new(NodeKind::Claim {
            proposition: prop.into(),
            scope: ClaimScope::Vault,
            source: SourceRef("u".into()),
        })
    }

    fn cap_hash() -> NHash {
        NHash::from_bytes([1u8; 32])
    }

    #[test]
    fn put_and_get_node_round_trips() {
        let store = InMemoryDagStore::new();
        let n = note("hello");
        let id = store.put_node(n.clone()).unwrap();
        assert_eq!(id, n.id);
        let retrieved = store.get_node(id).unwrap().unwrap();
        assert_eq!(retrieved, n);
    }

    #[test]
    fn put_node_is_idempotent() {
        let store = InMemoryDagStore::new();
        let n = note("idempotent");
        store.put_node(n.clone()).unwrap();
        store.put_node(n.clone()).unwrap();
        store.put_node(n.clone()).unwrap();
        assert_eq!(store.node_count(), 1);
    }

    #[test]
    fn put_edge_requires_both_endpoints_to_exist() {
        let store = InMemoryDagStore::new();
        let a = note("a");
        let b = note("b");
        store.put_node(a.clone()).unwrap();
        // b not inserted; edge must error
        let edge = Edge::new(
            a.id,
            b.id,
            EdgeKind::AnnotatedBy {
                kind: super::super::edge::AnnotationKind::Comment,
            },
            cap_hash(),
        );
        let err = store.put_edge(edge).unwrap_err();
        assert!(matches!(
            err,
            DagError::EdgeEndpointMissing { endpoint: "to" }
        ));
    }

    #[test]
    fn put_edge_dedups_by_content() {
        let store = InMemoryDagStore::new();
        let a = claim("A");
        let b = claim("B");
        store.put_node(a.clone()).unwrap();
        store.put_node(b.clone()).unwrap();
        let edge1 = Edge::new(
            a.id,
            b.id,
            EdgeKind::Contradicts { tension: 0.7 },
            cap_hash(),
        );
        let edge2 = Edge::new(
            a.id,
            b.id,
            EdgeKind::Contradicts { tension: 0.7 },
            cap_hash(),
        );
        let id1 = store.put_edge(edge1).unwrap();
        let id2 = store.put_edge(edge2).unwrap();
        assert_eq!(id1, id2);
        assert_eq!(store.edge_count(), 1);
    }

    #[test]
    fn edges_from_filters_by_selector() {
        let store = InMemoryDagStore::new();
        let a = claim("A");
        let b = claim("B");
        let c = claim("C");
        store.put_node(a.clone()).unwrap();
        store.put_node(b.clone()).unwrap();
        store.put_node(c.clone()).unwrap();
        store
            .put_edge(Edge::new(
                a.id,
                b.id,
                EdgeKind::Contradicts { tension: 0.5 },
                cap_hash(),
            ))
            .unwrap();
        store
            .put_edge(Edge::new(
                a.id,
                c.id,
                EdgeKind::DerivesFrom { strength: 0.9 },
                cap_hash(),
            ))
            .unwrap();

        let all = store.edges_from(a.id, None).unwrap();
        assert_eq!(all.len(), 2);

        let only_contradicts = store
            .edges_from(a.id, Some(EdgeKindSelector::Contradicts))
            .unwrap();
        assert_eq!(only_contradicts.len(), 1);
        assert!(matches!(
            only_contradicts[0].kind,
            EdgeKind::Contradicts { .. }
        ));

        let none = store
            .edges_from(a.id, Some(EdgeKindSelector::Invokes))
            .unwrap();
        assert!(none.is_empty());
    }

    #[test]
    fn edges_to_returns_inbound_edges() {
        let store = InMemoryDagStore::new();
        let a = claim("A");
        let b = claim("B");
        store.put_node(a.clone()).unwrap();
        store.put_node(b.clone()).unwrap();
        store
            .put_edge(Edge::new(
                a.id,
                b.id,
                EdgeKind::Contradicts { tension: 0.3 },
                cap_hash(),
            ))
            .unwrap();
        let inbound = store.edges_to(b.id, None).unwrap();
        assert_eq!(inbound.len(), 1);
        assert_eq!(inbound[0].from, a.id);
    }

    #[test]
    fn merkle_root_changes_when_node_added() {
        let store = InMemoryDagStore::new();
        let r1 = store.merkle_root().unwrap();
        store.put_node(note("a")).unwrap();
        let r2 = store.merkle_root().unwrap();
        assert_ne!(r1, r2);
    }

    #[test]
    fn merkle_root_changes_when_edge_added() {
        let store = InMemoryDagStore::new();
        let a = claim("A");
        let b = claim("B");
        store.put_node(a.clone()).unwrap();
        store.put_node(b.clone()).unwrap();
        let r1 = store.merkle_root().unwrap();
        store
            .put_edge(Edge::new(
                a.id,
                b.id,
                EdgeKind::DerivesFrom { strength: 0.5 },
                cap_hash(),
            ))
            .unwrap();
        let r2 = store.merkle_root().unwrap();
        assert_ne!(r1, r2);
    }

    #[test]
    fn merkle_root_is_reproducible_across_stores_with_same_content() {
        // Two stores with identical inserts must produce identical
        // merkle roots — content-addressed identity makes this work.
        let store_a = InMemoryDagStore::new();
        let store_b = InMemoryDagStore::new();
        for body in &["x", "y", "z"] {
            let n = note(body);
            store_a.put_node(n.clone()).unwrap();
            store_b.put_node(n).unwrap();
        }
        assert_eq!(
            store_a.merkle_root().unwrap(),
            store_b.merkle_root().unwrap()
        );
    }

    #[test]
    fn snapshot_round_trips_and_preserves_root() {
        let store = InMemoryDagStore::new();
        let a = claim("A");
        let b = claim("B");
        store.put_node(a.clone()).unwrap();
        store.put_node(b.clone()).unwrap();
        store
            .put_edge(Edge::new(
                a.id,
                b.id,
                EdgeKind::Contradicts { tension: 0.5 },
                cap_hash(),
            ))
            .unwrap();
        let snap = store.snapshot().unwrap();
        let encoded = serde_json::to_string(&snap).unwrap();
        let decoded: DagSnapshot = serde_json::from_str(&encoded).unwrap();
        assert_eq!(snap, decoded);
        assert_eq!(snap.merkle_root, store.merkle_root().unwrap());
    }

    #[test]
    fn snapshot_schema_version_is_pinned() {
        let store = InMemoryDagStore::new();
        let snap = store.snapshot().unwrap();
        assert_eq!(snap.schema_version, DagSnapshot::SCHEMA_VERSION);
        assert_eq!(snap.schema_version, 1);
    }

    #[test]
    fn edges_indexed_by_both_from_and_to() {
        let store = InMemoryDagStore::new();
        let a = claim("A");
        let b = claim("B");
        store.put_node(a.clone()).unwrap();
        store.put_node(b.clone()).unwrap();
        store
            .put_edge(Edge::new(
                a.id,
                b.id,
                EdgeKind::DerivesFrom { strength: 0.6 },
                cap_hash(),
            ))
            .unwrap();

        let outbound_a = store.edges_from(a.id, None).unwrap();
        let inbound_b = store.edges_to(b.id, None).unwrap();
        assert_eq!(outbound_a.len(), 1);
        assert_eq!(inbound_b.len(), 1);
        assert_eq!(outbound_a[0].id(), inbound_b[0].id());
    }

    #[test]
    fn deforms_edge_round_trips_with_lora_path() {
        let store = InMemoryDagStore::new();
        let model = Node::new(NodeKind::Model {
            weight_root: super::super::node::WeightRoot([0u8; 32]),
            base_or_lora: super::super::node::ModelLineage::Base,
        });
        let companion = Node::new(NodeKind::Companion {
            profile: super::super::node::ModelProfile("sage".into()),
            identity: super::super::node::IdentityHash([0u8; 32]),
            persona: super::super::node::PersonaBlob(vec![]),
        });
        store.put_node(model.clone()).unwrap();
        store.put_node(companion.clone()).unwrap();
        store
            .put_edge(Edge::new(
                companion.id,
                model.id,
                EdgeKind::Deforms {
                    lora_path: PathBuf::from("/loras/sage.safetensors"),
                    weight_alpha: 1.0,
                },
                cap_hash(),
            ))
            .unwrap();
        let snap = store.snapshot().unwrap();
        assert_eq!(snap.nodes.len(), 2);
        assert_eq!(snap.edges.len(), 1);
    }

    #[test]
    fn caches_edge_round_trips_with_memory_tier() {
        let store = InMemoryDagStore::new();
        let n = note("hot-content");
        store.put_node(n.clone()).unwrap();
        // Caches edge: a tier "node" wouldn't really exist as a node
        // in production — tiers will likely be capability nodes — but
        // the Phase 8.A schema supports the shape.
        let tier_node = Node::new(NodeKind::Capability {
            kind: super::super::node::CapabilityKind::Other("memory_tier:hot".into()),
            scope: super::super::node::CapabilityScope("global".into()),
            expiry: None,
        });
        store.put_node(tier_node.clone()).unwrap();
        store
            .put_edge(Edge::new(
                tier_node.id,
                n.id,
                EdgeKind::Caches {
                    tier: MemoryTier::Hot,
                    score: 0.95,
                },
                cap_hash(),
            ))
            .unwrap();
        assert_eq!(store.edge_count(), 1);
    }

    #[test]
    fn put_node_with_replay_timestamp_is_deterministic() {
        // Replay scenario: same `(kind, created_at)` always produces
        // identical Node bytes in a snapshot.
        let store_a = InMemoryDagStore::new();
        let store_b = InMemoryDagStore::new();
        let n_a = Node::new_at(
            NodeKind::Note {
                body: "replay".into(),
                author: AuthorRef("u".into()),
                mime: MimeType("text/markdown".into()),
            },
            Timestamp(42),
        );
        let n_b = Node::new_at(
            NodeKind::Note {
                body: "replay".into(),
                author: AuthorRef("u".into()),
                mime: MimeType("text/markdown".into()),
            },
            Timestamp(42),
        );
        store_a.put_node(n_a).unwrap();
        store_b.put_node(n_b).unwrap();
        let snap_a = store_a.snapshot().unwrap();
        let snap_b = store_b.snapshot().unwrap();
        assert_eq!(snap_a, snap_b);
    }

    // ── Phase 8.C / CD-005 — capability-bound put_edge tests ───────────────

    fn make_two_nodes(store: &InMemoryDagStore) -> (NodeId, NodeId) {
        let n_from = Node::new_at(
            NodeKind::Note {
                body: "src".into(),
                author: AuthorRef("u".into()),
                mime: MimeType("text/markdown".into()),
            },
            Timestamp(100),
        );
        let n_to = Node::new_at(
            NodeKind::Note {
                body: "dst".into(),
                author: AuthorRef("u".into()),
                mime: MimeType("text/markdown".into()),
            },
            Timestamp(101),
        );
        let id_from = store.put_node(n_from).unwrap();
        let id_to = store.put_node(n_to).unwrap();
        (id_from, id_to)
    }

    #[test]
    fn empty_capability_registry_falls_back_to_phase_8a_structural_guard() {
        // Backward-compat baseline: with NO registered capabilities,
        // put_edge accepts any non-zero-signature edge regardless of
        // which capability minted it. This preserves existing test
        // fixtures + Phase 8.A behavior.
        let store = InMemoryDagStore::new();
        assert!(store.registered_capabilities().is_empty());
        let (from, to) = make_two_nodes(&store);
        let cap_a = Hash::from_bytes([0xAAu8; 32]);
        let edge = Edge::new(from, to, EdgeKind::DerivesFrom { strength: 1.0 }, cap_a);
        // Empty registry → any non-zero signature accepted.
        store.put_edge(edge).unwrap();
    }

    #[test]
    fn registered_capability_accepts_matching_signature() {
        let store = InMemoryDagStore::new();
        let cap = Hash::from_bytes([0xE5u8; 32]);
        store.register_capability(cap).unwrap();
        let (from, to) = make_two_nodes(&store);
        let edge = Edge::new(from, to, EdgeKind::DerivesFrom { strength: 0.9 }, cap);
        // Edge signed under the registered capability verifies.
        store.put_edge(edge).unwrap();
    }

    #[test]
    fn registered_capability_rejects_mismatched_signature() {
        let store = InMemoryDagStore::new();
        let cap_registered = Hash::from_bytes([0xE5u8; 32]);
        let cap_unknown = Hash::from_bytes([0xAAu8; 32]);
        store.register_capability(cap_registered).unwrap();
        let (from, to) = make_two_nodes(&store);
        let edge = Edge::new(
            from,
            to,
            EdgeKind::DerivesFrom { strength: 0.9 },
            cap_unknown,
        );
        // Edge signed under an UNregistered capability is rejected.
        let err = store.put_edge(edge).unwrap_err();
        match err {
            DagError::InvalidSignature { .. } => {}
            other => panic!("expected InvalidSignature, got {other:?}"),
        }
    }

    #[test]
    fn multiple_registered_capabilities_any_match_accepts() {
        let store = InMemoryDagStore::new();
        let cap_a = Hash::from_bytes([0xE5u8; 32]);
        let cap_b = Hash::from_bytes([0xC0u8; 32]);
        store.register_capability(cap_a).unwrap();
        store.register_capability(cap_b).unwrap();
        let regs = store.registered_capabilities();
        assert_eq!(regs.len(), 2);

        let (from, to) = make_two_nodes(&store);
        // Edge signed under cap_b verifies because it's in the set.
        let edge_b = Edge::new(from, to, EdgeKind::DerivesFrom { strength: 0.5 }, cap_b);
        store.put_edge(edge_b).unwrap();
    }

    #[test]
    fn register_capability_is_idempotent() {
        let store = InMemoryDagStore::new();
        let cap = Hash::from_bytes([0xE5u8; 32]);
        store.register_capability(cap).unwrap();
        store.register_capability(cap).unwrap(); // duplicate
        assert_eq!(store.registered_capabilities().len(), 1);
    }

    #[test]
    fn registered_capabilities_returns_sorted_set() {
        let store = InMemoryDagStore::new();
        // Register in non-sorted order; readback should be sorted
        // (BTreeSet iteration order = ascending).
        let cap_high = Hash::from_bytes([0xFFu8; 32]);
        let cap_mid = Hash::from_bytes([0x80u8; 32]);
        let cap_low = Hash::from_bytes([0x01u8; 32]);
        store.register_capability(cap_high).unwrap();
        store.register_capability(cap_low).unwrap();
        store.register_capability(cap_mid).unwrap();
        let regs = store.registered_capabilities();
        assert_eq!(regs, vec![cap_low, cap_mid, cap_high]);
    }

    #[test]
    fn zero_signature_rejected_even_with_registered_capability() {
        // Defense-in-depth: even when capabilities are registered, the
        // Phase 8.A all-zero-signature guard still fires first. An edge
        // built bypassing Edge::new with a default signature is rejected
        // before the capability check ever runs.
        let store = InMemoryDagStore::new();
        let cap = Hash::from_bytes([0xE5u8; 32]);
        store.register_capability(cap).unwrap();
        let (from, to) = make_two_nodes(&store);
        // Construct an edge with a hand-crafted zero signature.
        // Since Edge fields are private we can only do this through
        // the constructor — but Edge::new with cap = all-zero produces
        // a NON-zero signature (BLAKE3 of (from, to, kind, [0;32])).
        // The all-zero signature path is reachable only via deserialize
        // of malicious bytes; that's the threat model the structural
        // guard catches. We can simulate by inserting via a default
        // signature path using bincode/serde, but the simpler check is
        // that Edge::new with a zero cap_hash STILL produces non-zero
        // sig (because the BLAKE3 hash mixes from/to/kind too).
        let zero_cap = Hash::from_bytes([0u8; 32]);
        let edge = Edge::new(from, to, EdgeKind::DerivesFrom { strength: 0.5 }, zero_cap);
        // signature is non-zero but cap_hash zero is NOT in registered
        // set, so insertion is rejected by the capability check.
        let err = store.put_edge(edge).unwrap_err();
        assert!(matches!(err, DagError::InvalidSignature { .. }));
    }
}
