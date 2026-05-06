//! redb-backed `DagStore` implementation.
//!
//! A1 keeps this backend opt-in behind `cognitive-dag-redb` until the
//! authority flip has enough replay and mirror-dispatch evidence. The
//! implementation intentionally mirrors `InMemoryDagStore` semantics:
//! content-addressed idempotent inserts, deterministic iteration, and
//! the same CD-005 capability-bound edge verification rule.

use std::fs;
use std::path::{Path, PathBuf};

use redb::{
    Database, MultimapTableDefinition, ReadableDatabase, ReadableTable, ReadableTableMetadata,
    TableDefinition,
};
use serde::de::DeserializeOwned;
use serde::Serialize;

use super::edge::{Edge, EdgeId, EdgeKindSelector};
use super::merkle::merkle_root_over;
use super::node::{Hash, Node, NodeId};
use super::storage::{DagError, DagSnapshot, DagStore};

const NODES: TableDefinition<&[u8; 32], &[u8]> = TableDefinition::new("cognitive_dag_nodes_v1");
const EDGES: TableDefinition<&[u8; 32], &[u8]> = TableDefinition::new("cognitive_dag_edges_v1");
const CAPABILITIES: TableDefinition<&[u8; 32], ()> =
    TableDefinition::new("cognitive_dag_capabilities_v1");
const FROM_INDEX: MultimapTableDefinition<&[u8; 32], &[u8; 32]> =
    MultimapTableDefinition::new("cognitive_dag_from_index_v1");
const TO_INDEX: MultimapTableDefinition<&[u8; 32], &[u8; 32]> =
    MultimapTableDefinition::new("cognitive_dag_to_index_v1");

/// Durable Cognitive DAG store. The file is a single redb database,
/// suitable for an App Group/vault-owned path once Phase 8.H flips
/// authority.
pub struct RedbDagStore {
    db: Database,
    path: PathBuf,
}

impl RedbDagStore {
    pub fn open(path: impl AsRef<Path>) -> Result<Self, DagError> {
        let path = path.as_ref();
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).map_err(|err| {
                DagError::Backend(format!("redb create parent {}: {err}", parent.display()))
            })?;
        }
        let db = Database::create(path).map_err(redb_error("create/open redb database"))?;
        let store = Self {
            db,
            path: path.to_path_buf(),
        };
        store.initialize_tables()?;
        Ok(store)
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    fn initialize_tables(&self) -> Result<(), DagError> {
        let write = self
            .db
            .begin_write()
            .map_err(redb_error("begin redb init write"))?;
        {
            write
                .open_table(NODES)
                .map_err(redb_error("open nodes table"))?;
            write
                .open_table(EDGES)
                .map_err(redb_error("open edges table"))?;
            write
                .open_table(CAPABILITIES)
                .map_err(redb_error("open capabilities table"))?;
            write
                .open_multimap_table(FROM_INDEX)
                .map_err(redb_error("open from_index table"))?;
            write
                .open_multimap_table(TO_INDEX)
                .map_err(redb_error("open to_index table"))?;
        }
        write
            .commit()
            .map_err(redb_error("commit redb init write"))?;
        Ok(())
    }

    fn registered_capability_verifies_edge(&self, edge: &Edge) -> Result<bool, DagError> {
        let read = self
            .db
            .begin_read()
            .map_err(redb_error("begin redb capability read"))?;
        let table = read
            .open_table(CAPABILITIES)
            .map_err(redb_error("open capabilities table"))?;
        if table.len().map_err(redb_error("read capability count"))? == 0 {
            return Ok(true);
        }
        for item in table.iter().map_err(redb_error("iterate capabilities"))? {
            let (capability, _) = item.map_err(redb_error("read capability"))?;
            let cap_hash = Hash::from_bytes(*capability.value());
            if edge.verify_signature(&cap_hash) {
                return Ok(true);
            }
        }
        Ok(false)
    }

    fn ordered_node_ids(&self) -> Result<Vec<NodeId>, DagError> {
        let read = self
            .db
            .begin_read()
            .map_err(redb_error("begin redb node-id read"))?;
        let table = read
            .open_table(NODES)
            .map_err(redb_error("open nodes table"))?;
        let mut ids = Vec::with_capacity(
            table
                .len()
                .map_err(redb_error("read node count"))?
                .try_into()
                .unwrap_or(0),
        );
        for item in table.iter().map_err(redb_error("iterate nodes"))? {
            let (key, _) = item.map_err(redb_error("read node key"))?;
            ids.push(NodeId::from_bytes(*key.value()));
        }
        Ok(ids)
    }

    fn ordered_edge_ids(&self) -> Result<Vec<EdgeId>, DagError> {
        let read = self
            .db
            .begin_read()
            .map_err(redb_error("begin redb edge-id read"))?;
        let table = read
            .open_table(EDGES)
            .map_err(redb_error("open edges table"))?;
        let mut ids = Vec::with_capacity(
            table
                .len()
                .map_err(redb_error("read edge count"))?
                .try_into()
                .unwrap_or(0),
        );
        for item in table.iter().map_err(redb_error("iterate edges"))? {
            let (key, _) = item.map_err(redb_error("read edge key"))?;
            ids.push(EdgeId::from_bytes(*key.value()));
        }
        Ok(ids)
    }
}

impl DagStore for RedbDagStore {
    fn put_node(&self, node: Node) -> Result<NodeId, DagError> {
        let expected_id = Node::compute_id(&node.kind);
        if expected_id != node.id {
            return Err(DagError::ContentAddressMismatch {
                expected: format!("{:?}", expected_id),
                actual: format!("{:?}", node.id),
            });
        }

        let id = node.id;
        let encoded = encode(&node, "node")?;
        let write = self
            .db
            .begin_write()
            .map_err(redb_error("begin redb node write"))?;
        {
            let mut table = write
                .open_table(NODES)
                .map_err(redb_error("open nodes table"))?;
            if table
                .get(id.as_bytes())
                .map_err(redb_error("read existing node"))?
                .is_none()
            {
                table
                    .insert(id.as_bytes(), encoded.as_slice())
                    .map_err(redb_error("insert node"))?;
            }
        }
        write
            .commit()
            .map_err(redb_error("commit redb node write"))?;
        Ok(id)
    }

    fn get_node(&self, id: NodeId) -> Result<Option<Node>, DagError> {
        let read = self
            .db
            .begin_read()
            .map_err(redb_error("begin redb node read"))?;
        let table = read
            .open_table(NODES)
            .map_err(redb_error("open nodes table"))?;
        let Some(value) = table.get(id.as_bytes()).map_err(redb_error("read node"))? else {
            return Ok(None);
        };
        decode(value.value(), "node").map(Some)
    }

    fn put_edge(&self, edge: Edge) -> Result<EdgeId, DagError> {
        let signature_is_zero = edge.signature.as_bytes().iter().all(|&b| b == 0);
        if signature_is_zero {
            return Err(DagError::InvalidSignature {
                edge: format!("{:?}", edge.id()),
            });
        }
        if !self.registered_capability_verifies_edge(&edge)? {
            return Err(DagError::InvalidSignature {
                edge: format!(
                    "{:?} (signature does not verify against any registered capability)",
                    edge.id()
                ),
            });
        }

        let edge_id = edge.id();
        let from_node = edge.from;
        let to_node = edge.to;
        let encoded = encode(&edge, "edge")?;

        let write = self
            .db
            .begin_write()
            .map_err(redb_error("begin redb edge write"))?;
        let already_present = {
            let nodes = write
                .open_table(NODES)
                .map_err(redb_error("open nodes table"))?;
            if nodes
                .get(from_node.as_bytes())
                .map_err(redb_error("read from endpoint"))?
                .is_none()
            {
                return Err(DagError::EdgeEndpointMissing { endpoint: "from" });
            }
            if nodes
                .get(to_node.as_bytes())
                .map_err(redb_error("read to endpoint"))?
                .is_none()
            {
                return Err(DagError::EdgeEndpointMissing { endpoint: "to" });
            }
            drop(nodes);

            let mut edges = write
                .open_table(EDGES)
                .map_err(redb_error("open edges table"))?;
            let present = edges
                .get(edge_id.as_bytes())
                .map_err(redb_error("read existing edge"))?
                .is_some();
            if !present {
                edges
                    .insert(edge_id.as_bytes(), encoded.as_slice())
                    .map_err(redb_error("insert edge"))?;
            }
            present
        };

        if !already_present {
            {
                let mut from_index = write
                    .open_multimap_table(FROM_INDEX)
                    .map_err(redb_error("open from_index table"))?;
                from_index
                    .insert(from_node.as_bytes(), edge_id.as_bytes())
                    .map_err(redb_error("insert from_index"))?;
            }
            {
                let mut to_index = write
                    .open_multimap_table(TO_INDEX)
                    .map_err(redb_error("open to_index table"))?;
                to_index
                    .insert(to_node.as_bytes(), edge_id.as_bytes())
                    .map_err(redb_error("insert to_index"))?;
            }
        }

        write
            .commit()
            .map_err(redb_error("commit redb edge write"))?;
        Ok(edge_id)
    }

    fn edges_from(
        &self,
        node: NodeId,
        kind: Option<EdgeKindSelector>,
    ) -> Result<Vec<Edge>, DagError> {
        self.edges_for_index(FROM_INDEX, node, kind)
    }

    fn edges_to(
        &self,
        node: NodeId,
        kind: Option<EdgeKindSelector>,
    ) -> Result<Vec<Edge>, DagError> {
        self.edges_for_index(TO_INDEX, node, kind)
    }

    fn merkle_root(&self) -> Result<Hash, DagError> {
        let node_ids = self.ordered_node_ids()?;
        let edge_ids = self.ordered_edge_ids()?;
        let node_refs = node_ids.iter().collect::<Vec<_>>();
        let edge_refs = edge_ids.iter().collect::<Vec<_>>();
        Ok(merkle_root_over(&node_refs, &edge_refs))
    }

    fn snapshot(&self) -> Result<DagSnapshot, DagError> {
        let read = self
            .db
            .begin_read()
            .map_err(redb_error("begin redb snapshot read"))?;
        let node_table = read
            .open_table(NODES)
            .map_err(redb_error("open nodes table"))?;
        let edge_table = read
            .open_table(EDGES)
            .map_err(redb_error("open edges table"))?;

        let mut nodes = Vec::with_capacity(
            node_table
                .len()
                .map_err(redb_error("read node count"))?
                .try_into()
                .unwrap_or(0),
        );
        let mut node_ids = Vec::with_capacity(nodes.capacity());
        for item in node_table.iter().map_err(redb_error("iterate nodes"))? {
            let (key, value) = item.map_err(redb_error("read node entry"))?;
            node_ids.push(NodeId::from_bytes(*key.value()));
            nodes.push(decode::<Node>(value.value(), "node")?);
        }

        let mut edges = Vec::with_capacity(
            edge_table
                .len()
                .map_err(redb_error("read edge count"))?
                .try_into()
                .unwrap_or(0),
        );
        let mut edge_ids = Vec::with_capacity(edges.capacity());
        for item in edge_table.iter().map_err(redb_error("iterate edges"))? {
            let (key, value) = item.map_err(redb_error("read edge entry"))?;
            edge_ids.push(EdgeId::from_bytes(*key.value()));
            edges.push(decode::<Edge>(value.value(), "edge")?);
        }

        let node_refs = node_ids.iter().collect::<Vec<_>>();
        let edge_refs = edge_ids.iter().collect::<Vec<_>>();
        let merkle_root = merkle_root_over(&node_refs, &edge_refs);
        Ok(DagSnapshot {
            nodes,
            edges,
            merkle_root,
            schema_version: DagSnapshot::SCHEMA_VERSION,
        })
    }

    fn register_capability(&self, capability_hash: Hash) -> Result<(), DagError> {
        let write = self
            .db
            .begin_write()
            .map_err(redb_error("begin redb capability write"))?;
        {
            let mut table = write
                .open_table(CAPABILITIES)
                .map_err(redb_error("open capabilities table"))?;
            table
                .insert(capability_hash.as_bytes(), &())
                .map_err(redb_error("insert capability"))?;
        }
        write
            .commit()
            .map_err(redb_error("commit redb capability write"))?;
        Ok(())
    }

    fn registered_capabilities(&self) -> Vec<Hash> {
        self.read_registered_capabilities().unwrap_or_default()
    }
}

impl RedbDagStore {
    fn edges_for_index(
        &self,
        index: MultimapTableDefinition<&[u8; 32], &[u8; 32]>,
        node: NodeId,
        kind: Option<EdgeKindSelector>,
    ) -> Result<Vec<Edge>, DagError> {
        let read = self
            .db
            .begin_read()
            .map_err(redb_error("begin redb edge-index read"))?;
        let index_table = read
            .open_multimap_table(index)
            .map_err(redb_error("open edge index"))?;
        let edge_table = read
            .open_table(EDGES)
            .map_err(redb_error("open edges table"))?;

        let mut out = Vec::new();
        let ids = index_table
            .get(node.as_bytes())
            .map_err(redb_error("read edge index"))?;
        for item in ids {
            let edge_id = EdgeId::from_bytes(*item.map_err(redb_error("read edge id"))?.value());
            let Some(encoded) = edge_table
                .get(edge_id.as_bytes())
                .map_err(redb_error("read indexed edge"))?
            else {
                continue;
            };
            let edge = decode::<Edge>(encoded.value(), "edge")?;
            if kind.is_none_or(|selector| selector.matches(&edge.kind)) {
                out.push(edge);
            }
        }
        Ok(out)
    }

    fn read_registered_capabilities(&self) -> Result<Vec<Hash>, DagError> {
        let read = self
            .db
            .begin_read()
            .map_err(redb_error("begin redb capability read"))?;
        let table = read
            .open_table(CAPABILITIES)
            .map_err(redb_error("open capabilities table"))?;
        let mut caps = Vec::with_capacity(
            table
                .len()
                .map_err(redb_error("read capability count"))?
                .try_into()
                .unwrap_or(0),
        );
        for item in table.iter().map_err(redb_error("iterate capabilities"))? {
            let (key, _) = item.map_err(redb_error("read capability"))?;
            caps.push(Hash::from_bytes(*key.value()));
        }
        Ok(caps)
    }
}

fn encode<T: Serialize>(value: &T, label: &str) -> Result<Vec<u8>, DagError> {
    serde_json::to_vec(value)
        .map_err(|err| DagError::Backend(format!("json encode {label}: {err}")))
}

fn decode<T: DeserializeOwned>(bytes: &[u8], label: &str) -> Result<T, DagError> {
    serde_json::from_slice(bytes)
        .map_err(|err| DagError::Backend(format!("json decode {label}: {err}")))
}

fn redb_error<E: std::fmt::Display>(context: &'static str) -> impl FnOnce(E) -> DagError {
    move |err| DagError::Backend(format!("{context}: {err}"))
}

#[cfg(test)]
mod tests {
    use tempfile::TempDir;

    use super::*;
    use crate::cognitive_dag::edge::{AnnotationKind, EdgeKind};
    use crate::cognitive_dag::node::{
        AuthorRef, ClaimScope, MimeType, NodeKind, SourceRef, Timestamp,
    };
    use crate::cognitive_dag::InMemoryDagStore;

    fn redb_store() -> (TempDir, RedbDagStore) {
        let dir = tempfile::tempdir().unwrap();
        let store = RedbDagStore::open(dir.path().join("cognitive_dag.redb")).unwrap();
        (dir, store)
    }

    fn note(body: &str) -> Node {
        Node::new_at(
            NodeKind::Note {
                body: body.into(),
                author: AuthorRef("u".into()),
                mime: MimeType("text/markdown".into()),
            },
            Timestamp(100),
        )
    }

    fn claim(prop: &str) -> Node {
        Node::new_at(
            NodeKind::Claim {
                proposition: prop.into(),
                scope: ClaimScope::Vault,
                source: SourceRef("u".into()),
            },
            Timestamp(101),
        )
    }

    fn cap_hash() -> Hash {
        Hash::from_bytes([0xA1; 32])
    }

    fn populate_pair(store: &impl DagStore) -> (Node, Node, Edge) {
        let a = claim("A");
        let b = claim("B");
        store.put_node(a.clone()).unwrap();
        store.put_node(b.clone()).unwrap();
        let edge = Edge::new(
            a.id,
            b.id,
            EdgeKind::DerivesFrom { strength: 0.9 },
            cap_hash(),
        );
        (a, b, edge)
    }

    #[test]
    fn redb_node_round_trips_and_persists_across_reopen() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("dag.redb");
        let node = note("durable");
        {
            let store = RedbDagStore::open(&path).unwrap();
            let id = store.put_node(node.clone()).unwrap();
            assert_eq!(id, node.id);
            assert_eq!(store.get_node(id).unwrap(), Some(node.clone()));
        }
        let reopened = RedbDagStore::open(&path).unwrap();
        assert_eq!(reopened.get_node(node.id).unwrap(), Some(node));
    }

    #[test]
    fn redb_put_node_is_content_address_idempotent() {
        let (_dir, store) = redb_store();
        let node = note("same");
        store.put_node(node.clone()).unwrap();
        store.put_node(node.clone()).unwrap();
        store.put_node(node).unwrap();
        assert_eq!(store.snapshot().unwrap().nodes.len(), 1);
    }

    #[test]
    fn redb_edges_from_and_to_match_in_memory() {
        let (_dir, redb) = redb_store();
        let memory = InMemoryDagStore::new();
        let (a, b, edge) = populate_pair(&memory);
        for node in [&a, &b] {
            redb.put_node(node.clone()).unwrap();
        }
        memory.put_edge(edge.clone()).unwrap();
        redb.put_edge(edge).unwrap();

        assert_eq!(
            redb.edges_from(a.id, None).unwrap(),
            memory.edges_from(a.id, None).unwrap()
        );
        assert_eq!(
            redb.edges_to(b.id, Some(EdgeKindSelector::DerivesFrom))
                .unwrap(),
            memory
                .edges_to(b.id, Some(EdgeKindSelector::DerivesFrom))
                .unwrap()
        );
    }

    #[test]
    fn redb_rejects_missing_endpoint_like_reference_store() {
        let (_dir, store) = redb_store();
        let a = note("a");
        let b = note("b");
        store.put_node(a.clone()).unwrap();
        let edge = Edge::new(
            a.id,
            b.id,
            EdgeKind::AnnotatedBy {
                kind: AnnotationKind::Comment,
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
    fn redb_capability_registry_enforces_cd005() {
        let (_dir, store) = redb_store();
        let registered = Hash::from_bytes([0xE5; 32]);
        let unknown = Hash::from_bytes([0xAA; 32]);
        store.register_capability(registered).unwrap();
        let (from, to, _) = populate_pair(&store);

        let rejected = Edge::new(
            from.id,
            to.id,
            EdgeKind::DerivesFrom { strength: 0.7 },
            unknown,
        );
        assert!(matches!(
            store.put_edge(rejected).unwrap_err(),
            DagError::InvalidSignature { .. }
        ));

        let accepted = Edge::new(
            from.id,
            to.id,
            EdgeKind::DerivesFrom { strength: 0.7 },
            registered,
        );
        store.put_edge(accepted).unwrap();
    }

    #[test]
    fn redb_registered_capabilities_are_sorted_and_persisted() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("dag.redb");
        let low = Hash::from_bytes([0x01; 32]);
        let mid = Hash::from_bytes([0x80; 32]);
        let high = Hash::from_bytes([0xFF; 32]);
        {
            let store = RedbDagStore::open(&path).unwrap();
            store.register_capability(high).unwrap();
            store.register_capability(low).unwrap();
            store.register_capability(mid).unwrap();
            assert_eq!(store.registered_capabilities(), vec![low, mid, high]);
        }
        let reopened = RedbDagStore::open(&path).unwrap();
        assert_eq!(reopened.registered_capabilities(), vec![low, mid, high]);
    }

    #[test]
    fn redb_snapshot_and_merkle_root_match_reference_store() {
        let (_dir, redb) = redb_store();
        let memory = InMemoryDagStore::new();
        let note = note("n");
        let claim = claim("c");
        let edge = Edge::new(
            note.id,
            claim.id,
            EdgeKind::AnnotatedBy {
                kind: AnnotationKind::Tag,
            },
            cap_hash(),
        );
        for store in [&memory as &dyn DagStore, &redb as &dyn DagStore] {
            store.put_node(note.clone()).unwrap();
            store.put_node(claim.clone()).unwrap();
            store.put_edge(edge.clone()).unwrap();
        }

        assert_eq!(redb.merkle_root().unwrap(), memory.merkle_root().unwrap());
        assert_eq!(redb.snapshot().unwrap(), memory.snapshot().unwrap());
    }

    #[test]
    fn redb_edges_and_indices_persist_across_reopen() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("dag.redb");
        let (from_id, to_id) = {
            let store = RedbDagStore::open(&path).unwrap();
            let (from, to, edge) = populate_pair(&store);
            store.put_edge(edge).unwrap();
            (from.id, to.id)
        };

        let reopened = RedbDagStore::open(&path).unwrap();
        assert_eq!(reopened.edges_from(from_id, None).unwrap().len(), 1);
        assert_eq!(reopened.edges_to(to_id, None).unwrap().len(), 1);
    }
}
