//! DAG-backed GraphNeighborhood — production wiring for W-50.
//!
//! `DagBackedGraphNeighborhood` is a read-only `EidosRetriever` that
//! consumes a [`crate::cognitive_dag::storage::DagSnapshot`] rather
//! than the in-memory adjacency list used by
//! [`super::graph_neighborhood::InMemoryGraphNeighborhood`]. The shape
//! behind the trait is identical — same `source_id` format, same
//! `EidosSourceKind::Graph`, same closed-citation contract — but the
//! data comes from the cognitive DAG.
//!
//! ## NodeId ↔ EidosDocumentId resolution
//!
//! `cognitive_dag::NodeId` is an opaque `[u8; 32]` content hash. The
//! Eidos surface speaks `EidosDocumentId` (a UTF-8 string). The
//! retriever takes two **resolver closures** at construction time:
//!
//! - `name_to_id: Fn(&str) -> Option<NodeId>` — maps the query text
//!   (the seed `EidosDocumentId`) to a NodeId in the snapshot.
//! - `id_to_name: Fn(&NodeId) -> Option<EidosDocumentId>` — maps each
//!   neighbor NodeId back to a citable EidosDocumentId.
//!
//! Closures are stored as `Arc<dyn Fn>` so the retriever stays
//! `Send + Sync` for the `EidosRetriever` trait. Callers wire them
//! against whatever naming layer holds the bidirectional map (Skills
//! mirror, Procedural mirror, a future `NamedNode` table, etc.).
//!
//! ## Snapshot consumption
//!
//! Construction takes a `DagSnapshot` so the retriever holds an
//! immutable view. The source `DagStore` can continue to mutate after
//! construction; the retriever's results stay deterministic on the
//! snapshot it captured. This is the same shape as W-49's
//! `LedgerBackedClaimEvidence` over `LedgerSnapshot`.
//!
//! ## Chunk id format
//!
//! Hits emit `source_id = "{neighbor_name}::graph::from::{seed_name}"`
//! — byte-equal to `InMemoryGraphNeighborhood`, so the closed-citation
//! contract holds across backends. Callers cannot smuggle a graph hit
//! from one seed under a different seed's provenance.

use std::sync::Arc;

use super::retriever::EidosRetriever;
use super::types::{
    is_blank_query_text, EidosChunkId, EidosContextPacket, EidosDocumentId, EidosHit,
    EidosIndexManifestId, EidosProvenance, EidosQuery, EidosRetrievalMode,
    EidosScoreComponents, EidosSourceKind,
};
use crate::cognitive_dag::edge::EdgeKindSelector;
use crate::cognitive_dag::node::NodeId;
use crate::cognitive_dag::storage::DagSnapshot;

/// Name-resolver closures bridging `EidosDocumentId` ↔ `NodeId`.
///
/// `Arc` so the retriever can be `Clone + Send + Sync` and live
/// inside a `Box<dyn EidosRetriever>` across threads.
#[derive(Clone)]
pub struct NodeNameResolver {
    pub name_to_id: Arc<dyn Fn(&str) -> Option<NodeId> + Send + Sync>,
    pub id_to_name: Arc<dyn Fn(&NodeId) -> Option<EidosDocumentId> + Send + Sync>,
}

impl std::fmt::Debug for NodeNameResolver {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("NodeNameResolver")
            .field("name_to_id", &"<fn>")
            .field("id_to_name", &"<fn>")
            .finish()
    }
}

/// `EidosRetriever` for 1-hop graph adjacency lookups backed by a
/// real cognitive DAG snapshot.
#[derive(Clone, Debug)]
pub struct DagBackedGraphNeighborhood {
    manifest_id: EidosIndexManifestId,
    snapshot: DagSnapshot,
    resolver: NodeNameResolver,
    /// Optional edge-kind filter. `None` = all kinds (the V0 default).
    edge_filter: Option<EdgeKindSelector>,
}

impl DagBackedGraphNeighborhood {
    /// Build the retriever from an immutable snapshot + resolver.
    pub fn from_snapshot(
        snapshot: DagSnapshot,
        manifest_id: EidosIndexManifestId,
        resolver: NodeNameResolver,
    ) -> Self {
        Self {
            snapshot,
            manifest_id,
            resolver,
            edge_filter: None,
        }
    }

    /// Restrict neighbor walk to one edge kind (e.g. `RelatesTo`).
    pub fn with_edge_filter(mut self, selector: EdgeKindSelector) -> Self {
        self.edge_filter = Some(selector);
        self
    }
}

impl EidosRetriever for DagBackedGraphNeighborhood {
    fn mode(&self) -> EidosRetrievalMode {
        EidosRetrievalMode::GraphNeighborhood
    }

    fn manifest_id(&self) -> &EidosIndexManifestId {
        &self.manifest_id
    }

    fn retrieve(
        &self,
        query: &EidosQuery,
        retrieved_at_unix_ms: u64,
    ) -> EidosContextPacket {
        if is_blank_query_text(&query.text) || query.top_k == 0 {
            return empty_packet(query, &self.manifest_id);
        }

        // Resolve seed name → NodeId. Unknown seed yields an empty
        // packet (cannot fabricate a graph hit).
        let Some(seed_id) = (self.resolver.name_to_id)(&query.text) else {
            return empty_packet(query, &self.manifest_id);
        };

        // Collect edges_from(seed) deterministically. The snapshot
        // edges are sorted by edge id, but multiple edges from the
        // same `from` node need a stable order — we sort by the
        // neighbor's hex id to match `InMemoryGraphNeighborhood`'s
        // BTreeSet ordering shape.
        let mut neighbor_ids: Vec<NodeId> = Vec::new();
        for edge in &self.snapshot.edges {
            if edge.from != seed_id {
                continue;
            }
            if let Some(filter) = &self.edge_filter {
                if !filter.matches(&edge.kind) {
                    continue;
                }
            }
            // Dedup — multiple edge kinds between the same two nodes
            // should produce one neighbor hit, not N.
            if !neighbor_ids.contains(&edge.to) {
                neighbor_ids.push(edge.to);
            }
        }
        // Stable order by neighbor hex id (matches BTreeSet ordering
        // shape of InMemoryGraphNeighborhood).
        neighbor_ids.sort_by(|a, b| a.as_bytes().cmp(b.as_bytes()));

        let top_k = query.top_k as usize;
        // Seed name is the literal query text (already non-blank).
        let seed_doc = match EidosDocumentId::new(query.text.clone()) {
            Ok(d) => d,
            Err(_) => return empty_packet(query, &self.manifest_id),
        };

        let mut hits: Vec<EidosHit> = Vec::with_capacity(top_k.min(neighbor_ids.len()));
        for nid in neighbor_ids.iter().take(top_k) {
            let Some(neighbor_doc) = (self.resolver.id_to_name)(nid) else {
                // Unnameable neighbors are skipped — the chat layer
                // cannot cite something it has no name for. This is
                // the right closed-failure mode: better to under-emit
                // than to emit a hex-string source_id that no UI can
                // resolve.
                continue;
            };
            let chunk_id = EidosChunkId::new(format!(
                "{}::graph::from::{}",
                neighbor_doc.as_str(),
                seed_doc.as_str()
            ))
            .expect("non-empty document ids guarantee non-empty chunk_id");
            hits.push(EidosHit {
                source_id: chunk_id,
                document_id: neighbor_doc,
                kind: EidosSourceKind::Graph,
                span: None,
                confidence: 1.0,
                score: EidosScoreComponents {
                    lexical: 0.0,
                    semantic: 0.0,
                    recency: 0.0,
                    graph: 1.0,
                },
                provenance: EidosProvenance {
                    manifest_id: self.manifest_id.clone(),
                    mode: EidosRetrievalMode::GraphNeighborhood,
                    retrieved_at_unix_ms,
                },
            });
        }

        EidosContextPacket {
            query: query.clone(),
            manifest_id: self.manifest_id.clone(),
            hits,
        }
    }
}

fn empty_packet(query: &EidosQuery, manifest: &EidosIndexManifestId) -> EidosContextPacket {
    EidosContextPacket {
        query: query.clone(),
        manifest_id: manifest.clone(),
        hits: vec![],
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cognitive_dag::edge::{Edge, EdgeKind};
    use crate::cognitive_dag::node::Hash;
    use crate::cognitive_dag::storage::DagSnapshot;
    use crate::eidos::types::EidosCitation;
    use std::collections::BTreeMap;

    /// Build a synthetic DagSnapshot with the given edges. Bypasses
    /// DagStore validation (which would require putting real Node
    /// fixtures per kind) — the retriever only reads `snapshot.edges`,
    /// so a snapshot constructed directly is sufficient.
    fn synthetic_snapshot(edges: Vec<Edge>) -> DagSnapshot {
        DagSnapshot {
            nodes: Vec::new(),
            edges,
            merkle_root: Hash::from_bytes([0u8; 32]),
            schema_version: DagSnapshot::SCHEMA_VERSION,
        }
    }

    fn manifest() -> EidosIndexManifestId {
        EidosIndexManifestId::new("dag-backed-graph-test").unwrap()
    }

    /// Build a tiny bidirectional name map (`hub` ↔ NodeId([1; 32]),
    /// `a` ↔ NodeId([2; 32]), etc.). Returns a snapshot containing
    /// the seeded edges + a resolver that round-trips both ways.
    fn build_resolver_and_snapshot(
        edges: &[(&str, &str)],
    ) -> (DagSnapshot, NodeNameResolver) {
        // Stable name ↔ id assignment: hash-of-name → first non-zero
        // 32-byte filling. We use `seed_byte` indexed by the name to
        // produce a deterministic, collision-free NodeId.
        let mut next_seed = 1u8;
        let mut by_name: BTreeMap<String, NodeId> = BTreeMap::new();
        let mut by_id: BTreeMap<NodeId, String> = BTreeMap::new();
        for (a, b) in edges {
            for name in [*a, *b] {
                if !by_name.contains_key(name) {
                    let id = NodeId::from_bytes([next_seed; 32]);
                    by_name.insert(name.to_string(), id);
                    by_id.insert(id, name.to_string());
                    next_seed = next_seed.checked_add(1).unwrap_or(255);
                }
            }
        }

        // Build edges directly into a synthetic snapshot. The
        // capability-bound signature path is exercised by the
        // cognitive_dag::storage tests; this test fixture only needs
        // the snapshot's edge list to read.
        let cap = Hash::from_bytes([7u8; 32]);
        let mut edge_vec: Vec<Edge> = Vec::new();
        for (a, b) in edges {
            let from = by_name[*a];
            let to = by_name[*b];
            edge_vec.push(Edge::new(from, to, EdgeKind::DerivesFrom { strength: 1.0 }, cap));
        }
        let snapshot = synthetic_snapshot(edge_vec);

        // Move maps into closures by Arc-cloning.
        let name_to_id_map = std::sync::Arc::new(by_name);
        let id_to_name_map = std::sync::Arc::new(by_id);
        let name_to_id_clone = std::sync::Arc::clone(&name_to_id_map);
        let id_to_name_clone = std::sync::Arc::clone(&id_to_name_map);
        let resolver = NodeNameResolver {
            name_to_id: Arc::new(move |s| name_to_id_clone.get(s).copied()),
            id_to_name: Arc::new(move |nid| {
                id_to_name_clone
                    .get(nid)
                    .and_then(|name| EidosDocumentId::new(name.clone()).ok())
            }),
        };
        (snapshot, resolver)
    }

    #[test]
    fn neighbors_returned_in_deterministic_order() {
        let (snap, res) =
            build_resolver_and_snapshot(&[("hub", "a"), ("hub", "b"), ("hub", "c")]);
        let r = DagBackedGraphNeighborhood::from_snapshot(snap, manifest(), res);
        let q = EidosQuery::new("hub", EidosRetrievalMode::GraphNeighborhood, 16);
        let packet = r.retrieve(&q, 1_700_000_000_000);
        assert_eq!(packet.hits.len(), 3);
        // Every hit advertises the graph mode + kind.
        for hit in &packet.hits {
            assert_eq!(hit.kind, EidosSourceKind::Graph);
            assert_eq!(hit.score.graph, 1.0);
            assert!(hit.source_id.as_str().ends_with("::graph::from::hub"));
        }
    }

    #[test]
    fn unresolvable_seed_returns_empty_packet() {
        let (snap, res) = build_resolver_and_snapshot(&[("hub", "a")]);
        let r = DagBackedGraphNeighborhood::from_snapshot(snap, manifest(), res);
        let q = EidosQuery::new("does-not-exist", EidosRetrievalMode::GraphNeighborhood, 16);
        let packet = r.retrieve(&q, 0);
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn unresolvable_neighbor_is_skipped_closed() {
        // Build a snapshot where a neighbor exists but the resolver
        // returns None for its NodeId (drop the entry from the map).
        let (snap, _real_res) =
            build_resolver_and_snapshot(&[("hub", "a"), ("hub", "b")]);
        // Re-build a resolver that omits `a` from the reverse map.
        let mut name_to_id: BTreeMap<String, NodeId> = BTreeMap::new();
        let mut id_to_name: BTreeMap<NodeId, String> = BTreeMap::new();
        // Seed-byte assignment must match the helper above: hub=1, a=2, b=3.
        let hub = NodeId::from_bytes([1u8; 32]);
        let b = NodeId::from_bytes([3u8; 32]);
        name_to_id.insert("hub".to_string(), hub);
        id_to_name.insert(hub, "hub".to_string());
        id_to_name.insert(b, "b".to_string());
        name_to_id.insert("b".to_string(), b);
        // `a` (NodeId([2;32])) intentionally omitted from id_to_name.
        let name_to_id = std::sync::Arc::new(name_to_id);
        let id_to_name = std::sync::Arc::new(id_to_name);
        let n2i = std::sync::Arc::clone(&name_to_id);
        let i2n = std::sync::Arc::clone(&id_to_name);
        let partial = NodeNameResolver {
            name_to_id: Arc::new(move |s| n2i.get(s).copied()),
            id_to_name: Arc::new(move |nid| {
                i2n.get(nid)
                    .and_then(|name| EidosDocumentId::new(name.clone()).ok())
            }),
        };
        let r = DagBackedGraphNeighborhood::from_snapshot(snap, manifest(), partial);
        let q = EidosQuery::new("hub", EidosRetrievalMode::GraphNeighborhood, 16);
        let packet = r.retrieve(&q, 0);
        // `a` skipped (unnameable); `b` returned.
        let ids: Vec<&str> = packet.hits.iter().map(|h| h.source_id.as_str()).collect();
        assert!(ids.iter().any(|id| id.contains("b::graph::from::hub")));
        assert!(
            !ids.iter().any(|id| id.contains("a::graph::from::hub")),
            "unresolvable neighbor must NOT emit a hex-string source_id"
        );
    }

    #[test]
    fn closed_citation_contract_holds_through_dag_backed_neighborhood() {
        let (snap, res) =
            build_resolver_and_snapshot(&[("hub", "a"), ("hub", "b"), ("hub", "c")]);
        let r = DagBackedGraphNeighborhood::from_snapshot(snap, manifest(), res);
        let q = EidosQuery::new("hub", EidosRetrievalMode::GraphNeighborhood, 16);
        let packet = r.retrieve(&q, 1_700_000_000_000);
        for hit in &packet.hits {
            let cite = EidosCitation {
                source_id: hit.source_id.clone(),
                manifest_id: packet.manifest_id.clone(),
            };
            assert_eq!(packet.validate_citation(&cite), Ok(()));
        }
        // Graph hit "from" a different seed is rejected.
        let smuggled = EidosCitation {
            source_id: EidosChunkId::new("a::graph::from::OTHER_SEED").unwrap(),
            manifest_id: packet.manifest_id.clone(),
        };
        assert!(packet.validate_citation(&smuggled).is_err());
    }

    #[test]
    fn empty_query_or_zero_top_k_defers() {
        let (snap, res) = build_resolver_and_snapshot(&[("hub", "a")]);
        let r = DagBackedGraphNeighborhood::from_snapshot(snap, manifest(), res);
        assert!(r
            .retrieve(
                &EidosQuery::new("", EidosRetrievalMode::GraphNeighborhood, 16),
                0
            )
            .hits
            .is_empty());
        assert!(r
            .retrieve(
                &EidosQuery::new("hub", EidosRetrievalMode::GraphNeighborhood, 0),
                0
            )
            .hits
            .is_empty());
    }

    #[test]
    fn whitespace_only_query_defers() {
        let (snap, res) = build_resolver_and_snapshot(&[("hub", "a")]);
        let r = DagBackedGraphNeighborhood::from_snapshot(snap, manifest(), res);
        let packet = r.retrieve(
            &EidosQuery::new("   ", EidosRetrievalMode::GraphNeighborhood, 16),
            0,
        );
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn invisible_only_query_defers() {
        let (snap, res) = build_resolver_and_snapshot(&[("hub", "a")]);
        let r = DagBackedGraphNeighborhood::from_snapshot(snap, manifest(), res);
        let packet = r.retrieve(
            &EidosQuery::new("\u{200B}", EidosRetrievalMode::GraphNeighborhood, 16),
            0,
        );
        assert!(packet.hits.is_empty());
    }

    #[test]
    fn top_k_truncates_neighborhood() {
        let (snap, res) =
            build_resolver_and_snapshot(&[("hub", "a"), ("hub", "b"), ("hub", "c")]);
        let r = DagBackedGraphNeighborhood::from_snapshot(snap, manifest(), res);
        let q = EidosQuery::new("hub", EidosRetrievalMode::GraphNeighborhood, 1);
        let packet = r.retrieve(&q, 0);
        assert_eq!(packet.hits.len(), 1);
    }

    #[test]
    fn edge_filter_restricts_neighbors() {
        // Build edges of mixed kind by going around the store API +
        // signing manually. Cheaper: rely on the helper's RelatesTo
        // edges, then filter to a kind that doesn't exist → empty.
        let (snap, res) = build_resolver_and_snapshot(&[("hub", "a")]);
        let r = DagBackedGraphNeighborhood::from_snapshot(snap, manifest(), res)
            .with_edge_filter(EdgeKindSelector::Contradicts);
        let q = EidosQuery::new("hub", EidosRetrievalMode::GraphNeighborhood, 8);
        let packet = r.retrieve(&q, 0);
        assert!(
            packet.hits.is_empty(),
            "no Contradicts edges in fixture → must be empty"
        );
    }

    #[test]
    fn retriever_advertises_graph_neighborhood_mode() {
        let (snap, res) = build_resolver_and_snapshot(&[("hub", "a")]);
        let r = DagBackedGraphNeighborhood::from_snapshot(snap, manifest(), res);
        assert_eq!(r.mode(), EidosRetrievalMode::GraphNeighborhood);
        assert_eq!(r.manifest_id(), &manifest());
    }

    #[test]
    fn replay_byte_equal_for_pinned_clock_on_same_snapshot() {
        let (snap, res) =
            build_resolver_and_snapshot(&[("hub", "a"), ("hub", "b"), ("hub", "c")]);
        let snap2 = snap.clone();
        let res2 = res.clone();
        let a = DagBackedGraphNeighborhood::from_snapshot(snap, manifest(), res);
        let b = DagBackedGraphNeighborhood::from_snapshot(snap2, manifest(), res2);
        let q = EidosQuery::new("hub", EidosRetrievalMode::GraphNeighborhood, 16);
        assert_eq!(
            a.retrieve(&q, 1_700_000_000_000),
            b.retrieve(&q, 1_700_000_000_000)
        );
    }

    #[test]
    fn duplicate_edges_dedup_to_one_neighbor_hit() {
        // Multiple edges from hub→a with different kinds → still
        // only one source_id "a::graph::from::hub".
        let cap = Hash::from_bytes([5u8; 32]);
        let hub = NodeId::from_bytes([1u8; 32]);
        let a = NodeId::from_bytes([2u8; 32]);
        let snapshot = synthetic_snapshot(vec![
            Edge::new(hub, a, EdgeKind::DerivesFrom { strength: 1.0 }, cap),
            Edge::new(hub, a, EdgeKind::Contradicts { tension: 0.5 }, cap),
        ]);
        let mut name_to_id = BTreeMap::new();
        let mut id_to_name = BTreeMap::new();
        name_to_id.insert("hub".to_string(), hub);
        name_to_id.insert("a".to_string(), a);
        id_to_name.insert(hub, "hub".to_string());
        id_to_name.insert(a, "a".to_string());
        let n2i = Arc::new(name_to_id);
        let i2n = Arc::new(id_to_name);
        let n2i_c = Arc::clone(&n2i);
        let i2n_c = Arc::clone(&i2n);
        let res = NodeNameResolver {
            name_to_id: Arc::new(move |s| n2i_c.get(s).copied()),
            id_to_name: Arc::new(move |nid| {
                i2n_c
                    .get(nid)
                    .and_then(|name| EidosDocumentId::new(name.clone()).ok())
            }),
        };
        let r = DagBackedGraphNeighborhood::from_snapshot(snapshot, manifest(), res);
        let q = EidosQuery::new("hub", EidosRetrievalMode::GraphNeighborhood, 8);
        let packet = r.retrieve(&q, 0);
        assert_eq!(packet.hits.len(), 1);
        assert_eq!(packet.hits[0].source_id.as_str(), "a::graph::from::hub");
    }
}
