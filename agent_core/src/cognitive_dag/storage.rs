//! DAG storage layer — `DagStore` trait + in-memory backend.
//!
//! Per `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` §1.3.
//!
//! The trait surface matches the doctrine spec verbatim; the `redb`
//! backend (recommended for App Group container compat) lands in a
//! follow-up Phase 8.A slice. Today's `InMemoryDagStore` is the
//! reference impl every test runs against and the production fallback
//! for unit-test environments without a real disk path.
//!
//! Determinism contract: every method returns results in a stable,
//! sorted order. `edges_from` / `edges_to` sort by edge id; the
//! Merkle root is computed deterministically per `merkle.rs`.

use std::collections::BTreeMap;
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
    fn edges_to(
        &self,
        node: NodeId,
        kind: Option<EdgeKindSelector>,
    ) -> Result<Vec<Edge>, DagError>;
    fn merkle_root(&self) -> Result<Hash, DagError>;
    fn snapshot(&self) -> Result<DagSnapshot, DagError>;
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
        }
    }

    pub fn node_count(&self) -> usize {
        self.nodes.read().map(|n| n.len()).unwrap_or(0)
    }

    pub fn edge_count(&self) -> usize {
        self.edges.read().map(|e| e.len()).unwrap_or(0)
    }
}

impl DagStore for InMemoryDagStore {
    fn put_node(&self, node: Node) -> Result<NodeId, DagError> {
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
                    if kind.map_or(true, |sel| sel.matches(&edge.kind)) {
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
                    if kind.map_or(true, |sel| sel.matches(&edge.kind)) {
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
        let edge = Edge::new(a.id, b.id, EdgeKind::AnnotatedBy { kind: super::super::edge::AnnotationKind::Comment }, cap_hash());
        let err = store.put_edge(edge).unwrap_err();
        assert!(matches!(err, DagError::EdgeEndpointMissing { endpoint: "to" }));
    }

    #[test]
    fn put_edge_dedups_by_content() {
        let store = InMemoryDagStore::new();
        let a = claim("A");
        let b = claim("B");
        store.put_node(a.clone()).unwrap();
        store.put_node(b.clone()).unwrap();
        let edge1 = Edge::new(a.id, b.id, EdgeKind::Contradicts { tension: 0.7 }, cap_hash());
        let edge2 = Edge::new(a.id, b.id, EdgeKind::Contradicts { tension: 0.7 }, cap_hash());
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
        assert_eq!(store_a.merkle_root().unwrap(), store_b.merkle_root().unwrap());
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
}
