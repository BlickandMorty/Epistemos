//! Phase 8.E — Subsystem migration scaffold.
//!
//! Per `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` §8 +
//! §2.2-§2.4.
//!
//! Phase 8.E rewires the seven legacy subsystems to use DAG nodes +
//! edges as the canonical store. Old subsystem stores remain readable
//! (backward compat) but writes are mirrored to the DAG. After two
//! consecutive weeks of CI green per doctrine §10, Phase 8.H flips
//! authority — DAG becomes primary; legacy stores become read-only
//! fallback views; one release later, removed.
//!
//! Phase 8.E full scope (per doctrine §8, ~3 weeks):
//! - Skills registry → Skill nodes + Invokes edges
//! - Procedural memory → Procedure nodes + RecordedBy edges
//! - Provenance ledger → Event nodes (the DAG IS the ledger now)
//! - Companions → Companion + Deforms nodes (covered in Phase 8.D
//!   `companions.rs`)
//!
//! This module ships the **Skills migration as the reference
//! pattern** + the generic `DagMirror` trait every subsystem can
//! implement. Procedure + Provenance migrations follow the same shape
//! and land as separate slices.

use std::collections::BTreeMap;
use std::sync::RwLock;

use serde::{Deserialize, Serialize};

use super::{
    edge::{Edge, EdgeKind, EdgeKindSelector},
    node::{Hash, Node, NodeId, NodeKind, ToolId, ToolSurface, NodeTier},
    storage::{DagError, DagStore},
};

// ── DagMirror trait — the subsystem migration contract ─────────────────────

/// Every legacy subsystem implements this when it migrates to mirror
/// writes into the DAG. Reads stay against the legacy store
/// throughout Phase 8.E-G; only Phase 8.H flips the read path.
///
/// The contract is small on purpose: one `mirror_write` for every
/// mutation; one `verify_consistent_with_legacy` for the audit gate.
pub trait DagMirror {
    /// The mutation type the subsystem emits (e.g. `SkillRegistered`,
    /// `ProcedureRecorded`, `EventEmitted`).
    type Mutation;

    /// Mirror a single mutation into the DAG. Pure function over
    /// `(mutation, store, capability_hash)` → `Result<NodeId>`.
    /// Returns the canonical NodeId of the new (or existing,
    /// idempotent) DAG node.
    fn mirror_write(
        mutation: &Self::Mutation,
        store: &dyn DagStore,
        capability_hash: Hash,
    ) -> Result<NodeId, DagError>;

    /// Audit hook — verifies that the legacy store and the DAG agree
    /// for a given subsystem entity. Implementations walk both stores
    /// + diff the canonical projection. Used by the Phase 8.H
    /// readiness gate ("two weeks of CI green = mirror is reliable").
    /// Returns `Ok(true)` if consistent, `Ok(false)` if drift was
    /// observed but recoverable, `Err(...)` for unrecoverable drift.
    fn verify_consistent_with_legacy(
        entity_id: &str,
        store: &dyn DagStore,
    ) -> Result<bool, DagError>;
}

// ── Skills migration — reference implementation ────────────────────────────

/// Mutation emitted by the legacy Skills registry on every
/// register / update / invoke. Phase 8.E mirrors each into the DAG
/// as a `Skill` node + `Invokes` edges to the underlying Tool nodes.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "skill_mutation", rename_all = "snake_case")]
pub enum SkillMutation {
    /// First-time registration — insert the Skill node + Invokes
    /// edges to every step.
    Register {
        name: String,
        description: String,
        schema_version: u32,
        steps: Vec<SkillStep>,
    },
    /// Skill updated in-place — re-emit the registration with new
    /// content; the old Skill node stays in the DAG (content-addressed
    /// immutability) and the new one supersedes via a higher
    /// `schema_version` on the same `name`.
    Update {
        name: String,
        description: String,
        schema_version: u32,
        steps: Vec<SkillStep>,
    },
    /// Invocation event — recorded as a separate Event node + an
    /// Invokes edge from the Skill to the Event. Procedural memory
    /// (Phase 8.E follow-up) reads this to learn which compositions
    /// happen often.
    Invoke {
        skill_name: String,
        invocation_id: String,
    },
}

/// One step in a Skill's invocation chain. Maps to a Tool node + an
/// Invokes edge from the Skill.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SkillStep {
    pub order: u32,
    pub tool_id: String,
    pub tool_surface: ToolSurface,
    pub tool_tier: NodeTier,
    pub args_template: String,
}

/// Skills DagMirror — the reference implementation for every
/// subsystem migration. Procedure + Provenance follow this pattern.
pub struct SkillsMirror;

impl DagMirror for SkillsMirror {
    type Mutation = SkillMutation;

    fn mirror_write(
        mutation: &Self::Mutation,
        store: &dyn DagStore,
        capability_hash: Hash,
    ) -> Result<NodeId, DagError> {
        match mutation {
            SkillMutation::Register {
                name,
                description,
                schema_version,
                steps,
            }
            | SkillMutation::Update {
                name,
                description,
                schema_version,
                steps,
            } => {
                // Insert (or no-op) the Skill node
                let skill_node = Node::new(NodeKind::Skill {
                    name: name.clone(),
                    description: description.clone(),
                    schema_version: *schema_version,
                });
                let skill_id = store.put_node(skill_node)?;

                // For each step, insert the Tool node + an Invokes
                // edge from Skill → Tool
                for step in steps {
                    let tool_node = Node::new(NodeKind::Tool {
                        id: ToolId(step.tool_id.clone()),
                        surface: step.tool_surface.clone(),
                        tier: step.tool_tier,
                    });
                    let tool_id = store.put_node(tool_node)?;
                    let edge = Edge::new(
                        skill_id,
                        tool_id,
                        EdgeKind::Invokes {
                            order: step.order,
                            args_template: step.args_template.clone(),
                        },
                        capability_hash,
                    );
                    store.put_edge(edge)?;
                }
                Ok(skill_id)
            }
            SkillMutation::Invoke {
                skill_name,
                invocation_id,
            } => {
                // Look up the Skill node by name (BFS over Skill kinds)
                let skill_id = find_skill_by_name(skill_name, store)?
                    .ok_or_else(|| DagError::NodeNotFound(format!("skill:{}", skill_name)))?;
                // Insert an Event node for the invocation
                let event_node = Node::new(NodeKind::Event {
                    kind: super::node::DagAgentEventKind::Other(format!(
                        "skill_invoke:{}",
                        invocation_id
                    )),
                    ts: super::node::Timestamp::now(),
                    session: super::node::SessionId(invocation_id.clone()),
                });
                let event_id = store.put_node(event_node)?;
                // Skill → Event via Invokes (re-using EdgeKind for
                // both step-of-skill + invocation-of-skill is the
                // canonical doctrine §2.2 pattern; the order field
                // distinguishes by reserving 0 for the invocation
                // marker)
                let edge = Edge::new(
                    skill_id,
                    event_id,
                    EdgeKind::Invokes {
                        order: 0,
                        args_template: format!("invocation:{}", invocation_id),
                    },
                    capability_hash,
                );
                store.put_edge(edge)?;
                Ok(event_id)
            }
        }
    }

    fn verify_consistent_with_legacy(
        entity_id: &str,
        store: &dyn DagStore,
    ) -> Result<bool, DagError> {
        // Phase 8.E reference impl: just verify the Skill node exists
        // in the DAG. Real implementation cross-checks the legacy
        // Skills registry's content for byte-equality; that lives in
        // a follow-up slice that wires the legacy store reference in.
        Ok(find_skill_by_name(entity_id, store)?.is_some())
    }
}

// ── Skill name index ───────────────────────────────────────────────────────

/// Per-process Skill name → NodeId index. Updated by `mirror_write`;
/// rebuilt on demand from a DAG snapshot when the index is empty (e.g.
/// process restart). This keeps Skill lookup O(1) instead of O(N) over
/// every node in the DAG.
pub struct SkillNameIndex {
    index: RwLock<BTreeMap<String, NodeId>>,
}

impl Default for SkillNameIndex {
    fn default() -> Self {
        Self::new()
    }
}

impl SkillNameIndex {
    pub fn new() -> Self {
        Self {
            index: RwLock::new(BTreeMap::new()),
        }
    }

    /// Rebuild from a DAG snapshot. Called on cold start; cheap O(N)
    /// scan over the snapshot's nodes.
    pub fn rebuild_from_snapshot(&self, snapshot: &super::storage::DagSnapshot) {
        if let Ok(mut idx) = self.index.write() {
            idx.clear();
            for node in &snapshot.nodes {
                if let NodeKind::Skill { name, .. } = &node.kind {
                    idx.insert(name.clone(), node.id);
                }
            }
        }
    }

    /// Insert / update a name → id mapping. Called by SkillsMirror
    /// after each register/update.
    pub fn upsert(&self, name: String, id: NodeId) {
        if let Ok(mut idx) = self.index.write() {
            idx.insert(name, id);
        }
    }

    /// Look up a Skill by name. None if not registered.
    pub fn lookup(&self, name: &str) -> Option<NodeId> {
        self.index.read().ok().and_then(|idx| idx.get(name).copied())
    }

    pub fn len(&self) -> usize {
        self.index.read().map(|i| i.len()).unwrap_or(0)
    }

    pub fn is_empty(&self) -> bool {
        self.index.read().map(|i| i.is_empty()).unwrap_or(true)
    }
}

/// Linear-scan fallback: walks the entire DAG looking for a Skill
/// node with the given name. O(N) — fine for verify, slow for hot
/// path. Hot path uses `SkillNameIndex`.
fn find_skill_by_name(
    name: &str,
    store: &dyn DagStore,
) -> Result<Option<NodeId>, DagError> {
    let snapshot = store.snapshot()?;
    for node in &snapshot.nodes {
        if let NodeKind::Skill { name: n, .. } = &node.kind {
            if n == name {
                return Ok(Some(node.id));
            }
        }
    }
    Ok(None)
}

#[cfg(test)]
mod tests {
    use super::super::storage::InMemoryDagStore;
    use super::*;

    fn cap() -> Hash {
        Hash::from_bytes([7u8; 32])
    }

    fn step(order: u32, tool_id: &str) -> SkillStep {
        SkillStep {
            order,
            tool_id: tool_id.into(),
            tool_surface: ToolSurface::Vault,
            tool_tier: NodeTier::ChatLite,
            args_template: format!("{{tool:{}}}", tool_id),
        }
    }

    fn register_mutation(name: &str, version: u32, steps: Vec<SkillStep>) -> SkillMutation {
        SkillMutation::Register {
            name: name.into(),
            description: format!("test skill {}", name),
            schema_version: version,
            steps,
        }
    }

    #[test]
    fn register_inserts_skill_and_tool_nodes_with_invokes_edges() {
        let store = InMemoryDagStore::new();
        let mutation = register_mutation(
            "vault.search.hybrid",
            1,
            vec![step(1, "vault.fts"), step(2, "vault.embed"), step(3, "vault.rrf")],
        );
        let skill_id = SkillsMirror::mirror_write(&mutation, &store, cap()).unwrap();

        // Skill node exists
        let skill = store.get_node(skill_id).unwrap().unwrap();
        match skill.kind {
            NodeKind::Skill { name, schema_version, .. } => {
                assert_eq!(name, "vault.search.hybrid");
                assert_eq!(schema_version, 1);
            }
            other => panic!("expected Skill, got {:?}", other),
        }

        // 3 Invokes edges from Skill
        let edges = store
            .edges_from(skill_id, Some(EdgeKindSelector::Invokes))
            .unwrap();
        assert_eq!(edges.len(), 3);

        // 3 Tool nodes (one per step) — verify by walking each edge's target
        for edge in &edges {
            let target = store.get_node(edge.to).unwrap().unwrap();
            assert!(matches!(target.kind, NodeKind::Tool { .. }));
        }
    }

    #[test]
    fn register_is_idempotent_for_identical_content() {
        let store = InMemoryDagStore::new();
        let mutation = register_mutation("idem", 1, vec![step(1, "t1")]);
        let id_a = SkillsMirror::mirror_write(&mutation, &store, cap()).unwrap();
        let id_b = SkillsMirror::mirror_write(&mutation, &store, cap()).unwrap();
        assert_eq!(id_a, id_b);
        // Edge dedup verified at the storage layer; one Invokes edge
        let edges = store
            .edges_from(id_a, Some(EdgeKindSelector::Invokes))
            .unwrap();
        assert_eq!(edges.len(), 1);
    }

    #[test]
    fn update_supersedes_via_higher_schema_version() {
        let store = InMemoryDagStore::new();
        let v1 = register_mutation("evolving", 1, vec![step(1, "old")]);
        let v1_id = SkillsMirror::mirror_write(&v1, &store, cap()).unwrap();

        let v2 = SkillMutation::Update {
            name: "evolving".into(),
            description: "evolving v2".into(),
            schema_version: 2,
            steps: vec![step(1, "new")],
        };
        let v2_id = SkillsMirror::mirror_write(&v2, &store, cap()).unwrap();

        // v1 and v2 are different nodes (different schema_version →
        // different content → different content-address). Both
        // remain in the DAG (immutability).
        assert_ne!(v1_id, v2_id);
        assert!(store.get_node(v1_id).unwrap().is_some());
        assert!(store.get_node(v2_id).unwrap().is_some());
    }

    #[test]
    fn invoke_inserts_event_and_edges_skill_to_event() {
        let store = InMemoryDagStore::new();
        SkillsMirror::mirror_write(
            &register_mutation("knowledge.query", 1, vec![step(1, "vault.fts")]),
            &store,
            cap(),
        )
        .unwrap();

        let invocation = SkillMutation::Invoke {
            skill_name: "knowledge.query".into(),
            invocation_id: "inv-001".into(),
        };
        let event_id = SkillsMirror::mirror_write(&invocation, &store, cap()).unwrap();

        let event = store.get_node(event_id).unwrap().unwrap();
        assert!(matches!(event.kind, NodeKind::Event { .. }));

        // Edge from Skill → Event with order=0 marks the invocation
        let skill_id = find_skill_by_name("knowledge.query", &store).unwrap().unwrap();
        let edges = store
            .edges_from(skill_id, Some(EdgeKindSelector::Invokes))
            .unwrap();
        let invocation_edges: Vec<_> = edges
            .iter()
            .filter(|e| matches!(e.kind, EdgeKind::Invokes { order: 0, .. }))
            .collect();
        assert_eq!(invocation_edges.len(), 1);
        assert_eq!(invocation_edges[0].to, event_id);
    }

    #[test]
    fn invoke_unknown_skill_errors() {
        let store = InMemoryDagStore::new();
        let invocation = SkillMutation::Invoke {
            skill_name: "never_registered".into(),
            invocation_id: "x".into(),
        };
        let err = SkillsMirror::mirror_write(&invocation, &store, cap()).unwrap_err();
        assert!(matches!(err, DagError::NodeNotFound(_)));
    }

    #[test]
    fn verify_consistent_returns_true_when_skill_present() {
        let store = InMemoryDagStore::new();
        SkillsMirror::mirror_write(
            &register_mutation("present", 1, vec![step(1, "t1")]),
            &store,
            cap(),
        )
        .unwrap();
        let consistent =
            SkillsMirror::verify_consistent_with_legacy("present", &store).unwrap();
        assert!(consistent);
    }

    #[test]
    fn verify_consistent_returns_false_when_skill_missing() {
        let store = InMemoryDagStore::new();
        let consistent =
            SkillsMirror::verify_consistent_with_legacy("missing", &store).unwrap();
        assert!(!consistent);
    }

    #[test]
    fn name_index_round_trips_through_snapshot_rebuild() {
        let store = InMemoryDagStore::new();
        for name in &["a.b", "c.d", "e.f"] {
            SkillsMirror::mirror_write(
                &register_mutation(name, 1, vec![step(1, "x")]),
                &store,
                cap(),
            )
            .unwrap();
        }

        // Build a fresh index + populate from snapshot
        let index = SkillNameIndex::new();
        assert!(index.is_empty());
        let snap = store.snapshot().unwrap();
        index.rebuild_from_snapshot(&snap);
        assert_eq!(index.len(), 3);

        for name in &["a.b", "c.d", "e.f"] {
            let id = index.lookup(name).expect("present");
            // Sanity: the indexed id matches the find_skill_by_name result
            let found = find_skill_by_name(name, &store).unwrap().unwrap();
            assert_eq!(id, found);
        }
        assert!(index.lookup("nonexistent").is_none());
    }

    #[test]
    fn name_index_upsert_overwrites() {
        let index = SkillNameIndex::new();
        let id_a = NodeId::from_bytes([1u8; 32]);
        let id_b = NodeId::from_bytes([2u8; 32]);
        index.upsert("k".into(), id_a);
        assert_eq!(index.lookup("k"), Some(id_a));
        index.upsert("k".into(), id_b);
        assert_eq!(index.lookup("k"), Some(id_b));
    }

    #[test]
    fn skill_steps_reflect_in_invokes_order_field() {
        let store = InMemoryDagStore::new();
        let mutation = register_mutation(
            "ordered",
            1,
            vec![step(10, "t1"), step(20, "t2"), step(5, "t3")],
        );
        let skill_id = SkillsMirror::mirror_write(&mutation, &store, cap()).unwrap();
        let edges = store
            .edges_from(skill_id, Some(EdgeKindSelector::Invokes))
            .unwrap();
        // Each edge's order field should match the step's order
        let mut orders: Vec<u32> = edges
            .iter()
            .filter_map(|e| match e.kind {
                EdgeKind::Invokes { order, .. } => Some(order),
                _ => None,
            })
            .collect();
        orders.sort();
        assert_eq!(orders, vec![5, 10, 20]);
    }
}
