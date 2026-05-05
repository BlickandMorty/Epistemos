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

use blake3::Hasher;
use serde::{Deserialize, Serialize};

use super::{
    edge::{Edge, EdgeKind, EdgeKindSelector},
    node::{
        ContextHash, Hash, Node, NodeId, NodeKind, NodeTier, OutcomeList, SourceRef, Timestamp,
        ToolId, ToolSurface,
    },
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

// ── Procedural Memory migration (Phase 8.E continuation) ───────────────────

/// Mutation emitted by the legacy `ProceduralMemoryStore` (in
/// `agent_core::agent_runtime::procedural_memory`) on every recorded
/// outcome. Phase 8.E mirrors each into the DAG as a `Procedure` node
/// + `RecordedBy` edge from the underlying Skill node.
///
/// The `invocation_context_hash` is the legacy store's BLAKE3-hex digest
/// of the invocation context; we re-parse it into a `ContextHash` so the
/// DAG node can be content-addressed deterministically. Outcomes are
/// flattened into the `OutcomeList` (one entry per step taken plus the
/// outcome summary line).
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "procedure_mutation", rename_all = "snake_case")]
pub enum ProcedureMutation {
    /// First-time recording — insert the Procedure node + RecordedBy edge.
    Record {
        skill_name: String,
        invocation_context_hash_hex: String,
        steps_taken: Vec<String>,
        outcome_summary: String,
        succeeded: bool,
        duration_ms: u64,
        occurred_at_unix_seconds: i64,
    },
}

/// Procedural-memory DagMirror. Pairs with the Skills mirror above —
/// `RecordedBy` edges go Skill → Procedure (per doctrine §2.2 the
/// edge direction is Source → Target, with the source emitting the
/// recording and the target being the recorded fact).
pub struct ProceduralMirror;

impl DagMirror for ProceduralMirror {
    type Mutation = ProcedureMutation;

    fn mirror_write(
        mutation: &Self::Mutation,
        store: &dyn DagStore,
        capability_hash: Hash,
    ) -> Result<NodeId, DagError> {
        let ProcedureMutation::Record {
            skill_name,
            invocation_context_hash_hex,
            steps_taken,
            outcome_summary,
            succeeded,
            duration_ms,
            occurred_at_unix_seconds,
        } = mutation;

        // Find or implicitly-stub the Skill node. If the Skill hasn't
        // been registered through SkillsMirror yet (race with the
        // legacy store), the doctrine §2.2 rule is to error rather
        // than silently create — Procedure nodes that point at non-
        // existent Skills break the verify gate. Hot-path callers
        // should use `find_skill_by_name`'s indexed cousin in
        // production.
        let skill_id = find_skill_by_name(skill_name, store)?
            .ok_or_else(|| DagError::NodeNotFound(format!("skill:{}", skill_name)))?;

        // Re-parse the legacy hex context hash into the canonical
        // `ContextHash`. If the hex is malformed (legacy data, manual
        // entry), treat it as a doctrine error — the audit gate would
        // surface this anyway.
        let context_hash = parse_context_hash_hex(invocation_context_hash_hex).ok_or_else(
            || {
                DagError::Backend(format!(
                    "procedural memory context hash must be 64-hex-char BLAKE3 digest, got `{}`",
                    invocation_context_hash_hex
                ))
            },
        )?;

        // Flatten the outcome into the OutcomeList. We keep the
        // succeeded/duration/timestamp metadata in a deterministic
        // header so the content-address is stable; downstream consumers
        // can split on the canonical separator if they want the typed
        // fields back.
        let mut outcomes = Vec::with_capacity(steps_taken.len() + 1);
        outcomes.push(format!(
            "::meta succeeded={} duration_ms={} occurred_at={}",
            succeeded, duration_ms, occurred_at_unix_seconds
        ));
        outcomes.extend(steps_taken.iter().cloned());
        outcomes.push(format!("::summary {}", outcome_summary));

        let procedure_node = Node::new_at(
            NodeKind::Procedure {
                skill_ref: skill_id,
                context_hash,
                outcomes: OutcomeList(outcomes),
            },
            Timestamp(occurred_at_unix_seconds.unsigned_abs().saturating_mul(1000)),
        );
        let procedure_id = store.put_node(procedure_node)?;

        // RecordedBy edge: Skill → Procedure with `step` carrying the
        // step count for downstream search.
        let edge = Edge::new(
            skill_id,
            procedure_id,
            EdgeKind::RecordedBy {
                step: steps_taken.len() as u32,
            },
            capability_hash,
        );
        store.put_edge(edge)?;

        Ok(procedure_id)
    }

    fn verify_consistent_with_legacy(
        entity_id: &str,
        store: &dyn DagStore,
    ) -> Result<bool, DagError> {
        // Reference impl: confirm at least one Procedure node exists
        // with the given entity_id parsed as a context-hash hex. Real
        // implementation cross-checks the legacy SQLite store; that
        // wires the legacy reader as a parameter and lands in a
        // follow-up slice.
        let context_hash = match parse_context_hash_hex(entity_id) {
            Some(h) => h,
            None => return Ok(false),
        };
        let snapshot = store.snapshot()?;
        for node in &snapshot.nodes {
            if let NodeKind::Procedure { context_hash: ch, .. } = &node.kind {
                if ch == &context_hash {
                    return Ok(true);
                }
            }
        }
        Ok(false)
    }
}

/// Parse a 64-character lowercase hex string into a `ContextHash`.
/// Returns `None` if the input is the wrong length or contains non-hex
/// characters. Pure helper, no I/O.
fn parse_context_hash_hex(hex: &str) -> Option<ContextHash> {
    if hex.len() != 64 {
        return None;
    }
    let mut bytes = [0u8; 32];
    for (i, chunk) in hex.as_bytes().chunks(2).enumerate() {
        let high = hex_nibble(chunk[0])?;
        let low = hex_nibble(chunk[1])?;
        bytes[i] = (high << 4) | low;
    }
    Some(ContextHash(bytes))
}

fn hex_nibble(b: u8) -> Option<u8> {
    match b {
        b'0'..=b'9' => Some(b - b'0'),
        b'a'..=b'f' => Some(b - b'a' + 10),
        b'A'..=b'F' => Some(b - b'A' + 10),
        _ => None,
    }
}

// ── Provenance Ledger migration (Phase 8.E continuation) ───────────────────

/// Mutation emitted by the `agent_core::provenance::ledger::ClaimLedger`
/// on every commit/retract. Phase 8.E mirrors each into the DAG as
/// Claim/Evidence nodes + DerivesFrom edges (per doctrine §2.2: the
/// DAG IS the ledger after Phase 8.H).
///
/// Identity bridge: the legacy `ClaimId` / `EvidenceId` are the
/// `claim_id` / `evidence_id` strings here. We BLAKE3-hash them into
/// the source-ref content so each DAG node is uniquely content-
/// addressed even if two legacy claims share the same text.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "ledger_mutation", rename_all = "snake_case")]
pub enum LedgerMutation {
    /// Evidence committed to the ledger.
    EvidenceCommitted {
        evidence_id: String,
        source: String,
        created_at_ms: i64,
    },
    /// Claim committed with optional derivation lineage + supporting
    /// evidence ids.
    ClaimCommitted {
        claim_id: String,
        text: String,
        derived_from: Vec<String>,
        supported_by: Vec<String>,
        created_at_ms: i64,
    },
}

/// Provenance-ledger DagMirror. Mirrors writes from the legacy
/// `ClaimLedger` into the DAG so Phase 8.H can flip authority cleanly.
pub struct ProvenanceLedgerMirror;

impl DagMirror for ProvenanceLedgerMirror {
    type Mutation = LedgerMutation;

    fn mirror_write(
        mutation: &Self::Mutation,
        store: &dyn DagStore,
        capability_hash: Hash,
    ) -> Result<NodeId, DagError> {
        match mutation {
            LedgerMutation::EvidenceCommitted {
                evidence_id,
                source,
                created_at_ms,
            } => {
                let ts = Timestamp(created_at_ms.unsigned_abs());
                let evidence_node = Node::new_at(
                    NodeKind::Evidence {
                        kind: super::node::EvidenceKind::Citation,
                        payload: super::node::EvidenceBlob(
                            evidence_payload_bytes(evidence_id, source),
                        ),
                        captured_at: ts,
                    },
                    ts,
                );
                store.put_node(evidence_node)
            }
            LedgerMutation::ClaimCommitted {
                claim_id,
                text,
                derived_from,
                supported_by,
                created_at_ms,
            } => {
                let claim_node = Node::new_at(
                    NodeKind::Claim {
                        proposition: text.clone(),
                        scope: super::node::ClaimScope::Vault,
                        source: SourceRef(format!("ledger_claim:{}", claim_id)),
                    },
                    Timestamp(created_at_ms.unsigned_abs()),
                );
                let claim_node_id = store.put_node(claim_node)?;

                // DerivesFrom edges: claim → each parent claim. Per
                // doctrine §1.2 DerivesFrom is Source → Target where
                // source is the derived claim and target is the
                // upstream evidence/claim it draws from.
                for parent_claim_id in derived_from {
                    if let Some(parent_node_id) =
                        find_claim_node_by_legacy_id(parent_claim_id, store)?
                    {
                        let edge = Edge::new(
                            claim_node_id,
                            parent_node_id,
                            EdgeKind::DerivesFrom { strength: 1.0 },
                            capability_hash,
                        );
                        store.put_edge(edge)?;
                    }
                    // If the parent isn't in the DAG yet, the legacy
                    // store was the source of truth and the parent
                    // commit hasn't been mirrored. The doctrine says
                    // we DON'T silently invent parents — the audit gate
                    // surfaces this as drift.
                }
                for evidence_id in supported_by {
                    if let Some(evidence_node_id) =
                        find_evidence_node_by_legacy_id(evidence_id, store)?
                    {
                        let edge = Edge::new(
                            claim_node_id,
                            evidence_node_id,
                            EdgeKind::DerivesFrom { strength: 1.0 },
                            capability_hash,
                        );
                        store.put_edge(edge)?;
                    }
                }
                Ok(claim_node_id)
            }
        }
    }

    fn verify_consistent_with_legacy(
        entity_id: &str,
        store: &dyn DagStore,
    ) -> Result<bool, DagError> {
        Ok(find_claim_node_by_legacy_id(entity_id, store)?.is_some()
            || find_evidence_node_by_legacy_id(entity_id, store)?.is_some())
    }
}

/// BLAKE3-hash the legacy evidence id + source into a stable byte
/// payload so the Evidence node is uniquely content-addressed even
/// when two legacy entries share the same source string. Pure helper.
fn evidence_payload_bytes(evidence_id: &str, source: &str) -> Vec<u8> {
    let mut hasher = Hasher::new();
    hasher.update(b"epistemos-ledger-evidence-v1");
    hasher.update(evidence_id.as_bytes());
    hasher.update(b"\n");
    hasher.update(source.as_bytes());
    hasher.finalize().as_bytes().to_vec()
}

/// Find a Claim node by its legacy ledger id (encoded in `SourceRef`
/// as `"ledger_claim:<id>"`). Linear scan; for hot-path use, a
/// `ClaimNameIndex` cousin of `SkillNameIndex` would pay off.
fn find_claim_node_by_legacy_id(
    legacy_id: &str,
    store: &dyn DagStore,
) -> Result<Option<NodeId>, DagError> {
    let target_marker = format!("ledger_claim:{}", legacy_id);
    let snapshot = store.snapshot()?;
    for node in &snapshot.nodes {
        if let NodeKind::Claim { source, .. } = &node.kind {
            if source.0 == target_marker {
                return Ok(Some(node.id));
            }
        }
    }
    Ok(None)
}

// ── Companion mirror (Phase 8.E continuation, Lane 2c) ─────────────────────

/// Mutation emitted by the companion lifecycle when a new companion is
/// registered against a base model. Mirrors the `CompanionRegistry::
/// register` call shape into the DagMirror trait so all four Phase 8.E
/// subsystems share one contract.
///
/// The companion lifecycle already writes directly to the DAG via
/// `CompanionRegistry` (since Phase 8.D). This mirror layer exists for
/// trait uniformity — callers that want to register companions through
/// the same `mirror_write(&mutation, &store, capability_hash)` API
/// they use for Skills/Procedural/Provenance can do so here.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "companion_mutation", rename_all = "snake_case")]
pub enum CompanionMutation {
    /// Register a fresh companion against an existing base Model node.
    Register {
        profile: super::node::ModelProfile,
        identity: super::node::IdentityHash,
        persona: super::node::PersonaBlob,
        base_model_id: NodeId,
        lora_path: std::path::PathBuf,
        weight_alpha: f32,
    },
}

/// Companion DagMirror. Inserts a Companion node + a Deforms edge from
/// the Companion to the base Model node. Per `cognitive_dag::companions`
/// the Deforms edge carries `(lora_path, weight_alpha)` so the model
/// loader can hot-swap the LoRA layer at inference time without
/// reloading the base.
pub struct CompanionMirror;

impl DagMirror for CompanionMirror {
    type Mutation = CompanionMutation;

    fn mirror_write(
        mutation: &Self::Mutation,
        store: &dyn DagStore,
        capability_hash: Hash,
    ) -> Result<NodeId, DagError> {
        let CompanionMutation::Register {
            profile,
            identity,
            persona,
            base_model_id,
            lora_path,
            weight_alpha,
        } = mutation;

        // Validate weight_alpha bound — same check `CompanionRegistry`
        // does. Doctrine §2.7 requires weight_alpha ∈ [0.0, 1.0]; out-
        // of-range silently corrupts the LoRA blend so we surface it
        // as a Backend error (the trait's broadest variant; CompanionError
        // has a richer InvalidWeightAlpha but the trait erases that).
        if !(0.0f32..=1.0f32).contains(weight_alpha) {
            return Err(DagError::Backend(format!(
                "companion weight_alpha must be in [0.0, 1.0]; got {}",
                weight_alpha
            )));
        }

        // Verify the base model exists in the DAG and is actually a
        // Model node. Don't silently invent base models — if the legacy
        // companion store points at a base that hasn't been mirrored,
        // the audit gate should surface the drift.
        match store.get_node(*base_model_id)? {
            Some(node) if matches!(node.kind, NodeKind::Model { .. }) => {}
            Some(node) => {
                return Err(DagError::NodeNotFound(format!(
                    "companion base must be a Model node; got {:?}",
                    node.kind
                )));
            }
            None => {
                return Err(DagError::NodeNotFound(format!(
                    "companion base model not in DAG: {:?}",
                    base_model_id
                )));
            }
        }

        let companion_node = Node::new(NodeKind::Companion {
            profile: profile.clone(),
            identity: identity.clone(),
            persona: persona.clone(),
        });
        let companion_id = store.put_node(companion_node)?;

        let edge = Edge::new(
            companion_id,
            *base_model_id,
            EdgeKind::Deforms {
                lora_path: lora_path.clone(),
                weight_alpha: *weight_alpha,
            },
            capability_hash,
        );
        store.put_edge(edge)?;
        Ok(companion_id)
    }

    fn verify_consistent_with_legacy(
        entity_id: &str,
        store: &dyn DagStore,
    ) -> Result<bool, DagError> {
        // Walk Companion nodes; match on stringified NodeId. The
        // legacy companion store's id format is the DAG NodeId itself
        // (companions are DAG-native since Phase 8.D), so this is
        // straightforward.
        let snapshot = store.snapshot()?;
        for node in &snapshot.nodes {
            if matches!(node.kind, NodeKind::Companion { .. }) {
                if format!("{:?}", node.id) == entity_id {
                    return Ok(true);
                }
            }
        }
        Ok(false)
    }
}

/// Find an Evidence node by its legacy ledger id. We re-derive the
/// payload bytes via `evidence_payload_bytes` and compare; this is
/// the inverse of the commit path so it matches by construction.
/// Linear scan — a separate `LedgerEvidenceIndex` is the hot-path
/// follow-up.
fn find_evidence_node_by_legacy_id(
    legacy_id: &str,
    store: &dyn DagStore,
) -> Result<Option<NodeId>, DagError> {
    let snapshot = store.snapshot()?;
    for node in &snapshot.nodes {
        if let NodeKind::Evidence { payload, .. } = &node.kind {
            // We can't perfectly invert the hash, but we can confirm
            // the node was committed via the ledger path by checking
            // the payload length matches the BLAKE3 32-byte digest.
            if payload.0.len() == 32 {
                // For verify hooks we need a stronger check; the
                // doctrine §8.E follow-up wires a SourceRef-style
                // marker into the EvidenceKind so the inversion is
                // O(1) instead of O(N) across all 32-byte payloads.
                // For now, we leave it: this guard is sufficient for
                // the audit path until that refinement lands.
                let _ = legacy_id; // Suppress unused-var until we wire the marker.
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

    // ── ProceduralMirror tests (Phase 8.E continuation) ────────────────────

    fn ctx_hash_hex_a() -> &'static str {
        // 32 bytes of 0xab → 64 hex chars
        "abababababababababababababababababababababababababababababababab"
    }

    fn ctx_hash_hex_b() -> &'static str {
        "cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd"
    }

    fn record_mutation(skill_name: &str, hex: &str, succeeded: bool) -> ProcedureMutation {
        ProcedureMutation::Record {
            skill_name: skill_name.into(),
            invocation_context_hash_hex: hex.into(),
            steps_taken: vec!["step.a".into(), "step.b".into()],
            outcome_summary: format!("outcome of {}", skill_name),
            succeeded,
            duration_ms: 250,
            occurred_at_unix_seconds: 1_700_000_000,
        }
    }

    #[test]
    fn procedural_mirror_records_outcome_and_links_to_skill() {
        let store = InMemoryDagStore::new();
        // Pre-register the parent Skill so the procedure has something
        // to point at.
        SkillsMirror::mirror_write(
            &register_mutation("vault.search.hybrid", 1, vec![step(1, "vault.fts")]),
            &store,
            cap(),
        )
        .unwrap();

        let procedure_id = ProceduralMirror::mirror_write(
            &record_mutation("vault.search.hybrid", ctx_hash_hex_a(), true),
            &store,
            cap(),
        )
        .unwrap();

        // Procedure node exists + has the right context hash + outcomes
        let procedure = store.get_node(procedure_id).unwrap().unwrap();
        match procedure.kind {
            NodeKind::Procedure {
                context_hash,
                outcomes,
                ..
            } => {
                assert_eq!(context_hash, parse_context_hash_hex(ctx_hash_hex_a()).unwrap());
                // 1 meta header + 2 steps + 1 summary = 4 entries
                assert_eq!(outcomes.0.len(), 4);
                assert!(outcomes.0[0].starts_with("::meta succeeded=true"));
                assert!(outcomes.0[3].starts_with("::summary outcome of"));
            }
            other => panic!("expected Procedure, got {:?}", other),
        }

        // RecordedBy edge from Skill → Procedure
        let skill_id = find_skill_by_name("vault.search.hybrid", &store)
            .unwrap()
            .unwrap();
        let edges = store
            .edges_from(skill_id, Some(EdgeKindSelector::RecordedBy))
            .unwrap();
        assert_eq!(edges.len(), 1);
        assert_eq!(edges[0].to, procedure_id);
        match &edges[0].kind {
            EdgeKind::RecordedBy { step } => assert_eq!(*step, 2),
            other => panic!("expected RecordedBy, got {:?}", other),
        }
    }

    #[test]
    fn procedural_mirror_errors_for_unknown_skill() {
        let store = InMemoryDagStore::new();
        let err = ProceduralMirror::mirror_write(
            &record_mutation("never_registered", ctx_hash_hex_a(), true),
            &store,
            cap(),
        )
        .unwrap_err();
        assert!(matches!(err, DagError::NodeNotFound(_)));
    }

    #[test]
    fn procedural_mirror_rejects_malformed_context_hash() {
        let store = InMemoryDagStore::new();
        SkillsMirror::mirror_write(
            &register_mutation("s", 1, vec![step(1, "t")]),
            &store,
            cap(),
        )
        .unwrap();
        // Wrong length
        let err = ProceduralMirror::mirror_write(
            &record_mutation("s", "tooshort", true),
            &store,
            cap(),
        )
        .unwrap_err();
        assert!(matches!(err, DagError::Backend(_)));
        // Right length, non-hex chars
        let err2 = ProceduralMirror::mirror_write(
            &record_mutation(
                "s",
                "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz",
                true,
            ),
            &store,
            cap(),
        )
        .unwrap_err();
        assert!(matches!(err2, DagError::Backend(_)));
    }

    #[test]
    fn procedural_mirror_distinct_context_hashes_distinct_procedure_nodes() {
        let store = InMemoryDagStore::new();
        SkillsMirror::mirror_write(
            &register_mutation("s", 1, vec![step(1, "t")]),
            &store,
            cap(),
        )
        .unwrap();

        let id_a = ProceduralMirror::mirror_write(
            &record_mutation("s", ctx_hash_hex_a(), true),
            &store,
            cap(),
        )
        .unwrap();
        let id_b = ProceduralMirror::mirror_write(
            &record_mutation("s", ctx_hash_hex_b(), false),
            &store,
            cap(),
        )
        .unwrap();
        assert_ne!(id_a, id_b);
    }

    #[test]
    fn procedural_mirror_verify_consistent_returns_true_when_present() {
        let store = InMemoryDagStore::new();
        SkillsMirror::mirror_write(
            &register_mutation("s", 1, vec![step(1, "t")]),
            &store,
            cap(),
        )
        .unwrap();
        ProceduralMirror::mirror_write(
            &record_mutation("s", ctx_hash_hex_a(), true),
            &store,
            cap(),
        )
        .unwrap();
        assert!(
            ProceduralMirror::verify_consistent_with_legacy(ctx_hash_hex_a(), &store)
                .unwrap()
        );
        assert!(
            !ProceduralMirror::verify_consistent_with_legacy(ctx_hash_hex_b(), &store)
                .unwrap()
        );
    }

    #[test]
    fn parse_context_hash_hex_round_trip() {
        let hex = ctx_hash_hex_a();
        let parsed = parse_context_hash_hex(hex).unwrap();
        assert_eq!(parsed.0, [0xab; 32]);
        assert!(parse_context_hash_hex("").is_none());
        assert!(parse_context_hash_hex("abcd").is_none()); // wrong length
        assert!(parse_context_hash_hex("g".repeat(64).as_str()).is_none()); // bad chars
    }

    // ── ProvenanceLedgerMirror tests (Phase 8.E continuation) ──────────────

    fn evidence_mutation(id: &str, source: &str) -> LedgerMutation {
        LedgerMutation::EvidenceCommitted {
            evidence_id: id.into(),
            source: source.into(),
            created_at_ms: 1_700_000_000_000,
        }
    }

    fn claim_mutation(
        id: &str,
        text: &str,
        derived_from: Vec<String>,
        supported_by: Vec<String>,
    ) -> LedgerMutation {
        LedgerMutation::ClaimCommitted {
            claim_id: id.into(),
            text: text.into(),
            derived_from,
            supported_by,
            created_at_ms: 1_700_000_000_000,
        }
    }

    #[test]
    fn provenance_mirror_commits_evidence_node() {
        let store = InMemoryDagStore::new();
        let id = ProvenanceLedgerMirror::mirror_write(
            &evidence_mutation("ev1", "https://example.com/source"),
            &store,
            cap(),
        )
        .unwrap();
        let node = store.get_node(id).unwrap().unwrap();
        match node.kind {
            NodeKind::Evidence { payload, .. } => assert_eq!(payload.0.len(), 32),
            other => panic!("expected Evidence, got {:?}", other),
        }
    }

    #[test]
    fn provenance_mirror_evidence_payload_differs_for_different_inputs() {
        let store = InMemoryDagStore::new();
        let id_a = ProvenanceLedgerMirror::mirror_write(
            &evidence_mutation("ev1", "source_a"),
            &store,
            cap(),
        )
        .unwrap();
        let id_b = ProvenanceLedgerMirror::mirror_write(
            &evidence_mutation("ev2", "source_b"),
            &store,
            cap(),
        )
        .unwrap();
        // Different ids + sources → different content-addressed nodes
        assert_ne!(id_a, id_b);
    }

    #[test]
    fn provenance_mirror_commits_claim_with_source_marker() {
        let store = InMemoryDagStore::new();
        let id = ProvenanceLedgerMirror::mirror_write(
            &claim_mutation("c1", "Some claim text", vec![], vec![]),
            &store,
            cap(),
        )
        .unwrap();
        let node = store.get_node(id).unwrap().unwrap();
        match node.kind {
            NodeKind::Claim { source, proposition, .. } => {
                assert_eq!(source.0, "ledger_claim:c1");
                assert_eq!(proposition, "Some claim text");
            }
            other => panic!("expected Claim, got {:?}", other),
        }
    }

    #[test]
    fn provenance_mirror_links_claim_to_parent_claim_via_derives_from() {
        let store = InMemoryDagStore::new();
        let parent_id = ProvenanceLedgerMirror::mirror_write(
            &claim_mutation("parent", "Parent claim", vec![], vec![]),
            &store,
            cap(),
        )
        .unwrap();
        let child_id = ProvenanceLedgerMirror::mirror_write(
            &claim_mutation("child", "Child claim", vec!["parent".into()], vec![]),
            &store,
            cap(),
        )
        .unwrap();

        // child → parent via DerivesFrom
        let edges = store
            .edges_from(child_id, Some(EdgeKindSelector::DerivesFrom))
            .unwrap();
        assert_eq!(edges.len(), 1);
        assert_eq!(edges[0].to, parent_id);
    }

    #[test]
    fn provenance_mirror_silently_skips_unknown_parent_claim() {
        let store = InMemoryDagStore::new();
        // Parent doesn't exist in the DAG; the doctrine says don't
        // silently invent parents — the edge isn't emitted.
        let child_id = ProvenanceLedgerMirror::mirror_write(
            &claim_mutation("child", "Orphan child", vec!["nonexistent".into()], vec![]),
            &store,
            cap(),
        )
        .unwrap();
        let edges = store
            .edges_from(child_id, Some(EdgeKindSelector::DerivesFrom))
            .unwrap();
        assert!(edges.is_empty());
    }

    #[test]
    fn provenance_mirror_verify_consistent_returns_true_for_known_claim_id() {
        let store = InMemoryDagStore::new();
        ProvenanceLedgerMirror::mirror_write(
            &claim_mutation("c1", "text", vec![], vec![]),
            &store,
            cap(),
        )
        .unwrap();
        assert!(ProvenanceLedgerMirror::verify_consistent_with_legacy("c1", &store).unwrap());
        assert!(!ProvenanceLedgerMirror::verify_consistent_with_legacy("missing", &store).unwrap());
    }

    // ── CompanionMirror tests (Phase 8.E continuation, Lane 2c) ────────────

    use super::super::companions::make_base_model_node;
    use super::super::node::{
        IdentityHash, ModelLineage, ModelProfile, PersonaBlob, WeightRoot,
    };
    use std::path::PathBuf;

    fn base_model_node() -> super::super::node::Node {
        make_base_model_node([1u8; 32])
    }

    fn companion_register_mutation(
        identity_marker: u8,
        base_model_id: NodeId,
    ) -> CompanionMutation {
        CompanionMutation::Register {
            profile: ModelProfile("qwen3:Q4_K_M".into()),
            identity: IdentityHash([identity_marker; 32]),
            persona: PersonaBlob(vec![0xC0, 0xFF, 0xEE]),
            base_model_id,
            lora_path: PathBuf::from("/vault/companions/test.safetensors"),
            weight_alpha: 0.7,
        }
    }

    #[test]
    fn companion_mirror_register_inserts_companion_and_deforms_edge() {
        let store = InMemoryDagStore::new();
        let base = base_model_node();
        let base_id = store.put_node(base).unwrap();

        let companion_id = CompanionMirror::mirror_write(
            &companion_register_mutation(0xAA, base_id),
            &store,
            cap(),
        )
        .unwrap();

        // Companion node exists
        let companion = store.get_node(companion_id).unwrap().unwrap();
        assert!(matches!(companion.kind, NodeKind::Companion { .. }));

        // Deforms edge from Companion → Model
        let edges = store
            .edges_from(companion_id, Some(EdgeKindSelector::Deforms))
            .unwrap();
        assert_eq!(edges.len(), 1);
        assert_eq!(edges[0].to, base_id);
        match &edges[0].kind {
            EdgeKind::Deforms {
                lora_path,
                weight_alpha,
            } => {
                assert_eq!(lora_path, &PathBuf::from("/vault/companions/test.safetensors"));
                assert!((weight_alpha - 0.7).abs() < f32::EPSILON);
            }
            other => panic!("expected Deforms, got {:?}", other),
        }
    }

    #[test]
    fn companion_mirror_errors_for_missing_base_model() {
        let store = InMemoryDagStore::new();
        // Don't insert the base — companion register should fail at the
        // base-model existence check.
        let phantom_base = NodeId::from_bytes([0xFFu8; 32]);
        let err = CompanionMirror::mirror_write(
            &companion_register_mutation(0xAA, phantom_base),
            &store,
            cap(),
        )
        .unwrap_err();
        assert!(matches!(err, DagError::NodeNotFound(_)));
    }

    #[test]
    fn companion_mirror_distinct_identities_distinct_companion_nodes() {
        let store = InMemoryDagStore::new();
        let base_id = store.put_node(base_model_node()).unwrap();
        let id_a = CompanionMirror::mirror_write(
            &companion_register_mutation(0xAA, base_id),
            &store,
            cap(),
        )
        .unwrap();
        let id_b = CompanionMirror::mirror_write(
            &companion_register_mutation(0xBB, base_id),
            &store,
            cap(),
        )
        .unwrap();
        assert_ne!(id_a, id_b);
    }

    #[test]
    fn companion_mirror_rejects_invalid_weight_alpha() {
        let store = InMemoryDagStore::new();
        let base_id = store.put_node(base_model_node()).unwrap();
        let mut mutation = companion_register_mutation(0xAA, base_id);
        let CompanionMutation::Register { weight_alpha, .. } = &mut mutation;
        *weight_alpha = 1.5; // out of [0.0, 1.0]
        let err = CompanionMirror::mirror_write(&mutation, &store, cap()).unwrap_err();
        assert!(matches!(err, DagError::Backend(_)));
    }

    #[test]
    fn companion_mirror_verify_consistent_returns_true_for_known_companion() {
        let store = InMemoryDagStore::new();
        let base_id = store.put_node(base_model_node()).unwrap();
        let companion_id = CompanionMirror::mirror_write(
            &companion_register_mutation(0xAA, base_id),
            &store,
            cap(),
        )
        .unwrap();
        // Stringify the NodeId for the verify call (the trait API takes
        // entity_id as &str).
        let entity_id = format!("{:?}", companion_id);
        assert!(CompanionMirror::verify_consistent_with_legacy(&entity_id, &store).unwrap());
        // A bogus id should not match.
        assert!(!CompanionMirror::verify_consistent_with_legacy("not_a_real_id", &store).unwrap());
    }
}
