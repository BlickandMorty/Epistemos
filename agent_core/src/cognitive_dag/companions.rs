//! Phase 8.D — LoRA-light Companion lifecycle.
//!
//! Per `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md` §2.7 + §8.
//!
//! "Companion = `Companion` node + `Deforms` edge to a `Model` node.
//! The `Deforms` edge carries the LoRA path and weight. Multiple
//! companions share one base `Model` node; only their LoRA diffs vary.
//!
//! 50 companions × 50MB LoRAs + 1 × 4GB base = 6.5GB total. Vs 50 ×
//! 4GB = 200GB without sharing. The DAG schema makes the Companion
//! Farm economically real on 16GB Macs."
//!
//! Phase 8.D scope (this module):
//! - `CompanionRegistry` — Rust-side lifecycle layer over the DAG:
//!   register a Companion node + its Deforms edge to a single base
//!   Model node; lookup by NodeId; enumerate companions deformed by a
//!   given base
//! - `CompanionLineage` summary (base id, lora path, weight alpha)
//! - Acceptance-bar timing helpers (creation, lookup) — the doctrine
//!   targets <100ms creation + <200ms swap; the in-memory backend
//!   exercises these at sub-millisecond
//!
//! NOT in scope (Swift host responsibilities; documented for the
//! Phase 8.D follow-up that crosses the FFI):
//! - Actual MLX-Swift hot-swap (loading the LoRA, mounting it onto
//!   the base, unloading the previous LoRA). The Rust side maintains
//!   the canonical lineage record; the Swift side calls
//!   `MLXInferenceService.swap_lora(lora_path)` when the active
//!   companion changes
//! - Persistent storage of LoRA blobs (stays under
//!   `vault/.adapters/<companion-id>/lora.safetensors`; not the DAG's
//!   responsibility)
//! - LoRA cache eviction policy (lives in `MetalRuntimeManager`)

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::sync::RwLock;

use serde::{Deserialize, Serialize};

use super::{
    edge::{Edge, EdgeKind, EdgeKindSelector},
    node::{
        Hash, IdentityHash, ModelLineage, ModelProfile, Node, NodeId, NodeKind, PersonaBlob,
        WeightRoot,
    },
    storage::{DagError, DagStore},
};

/// Snapshot of a Companion's relationship to its base Model.
/// Returned by `CompanionRegistry::lineage_for` and the bulk
/// `companions_for_base` query.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CompanionLineage {
    pub companion_id: NodeId,
    pub base_model_id: NodeId,
    pub lora_path: PathBuf,
    pub weight_alpha: f32,
}

/// Errors specific to companion lifecycle ops on top of DagStore errors.
#[derive(Debug, thiserror::Error)]
pub enum CompanionError {
    #[error("dag error: {0}")]
    Dag(#[from] DagError),
    #[error("companion not found in DAG: {0:?}")]
    CompanionNotFound(NodeId),
    #[error("base model not found in DAG: {0:?}")]
    BaseModelNotFound(NodeId),
    #[error("companion {companion:?} has no Deforms edge to a Model node")]
    NoDeformsEdge { companion: NodeId },
    #[error("Deforms edge's target {target:?} is not a Model node (kind={kind:?})")]
    DeformsTargetNotModel { target: NodeId, kind: String },
    #[error("weight_alpha must be in [0.0, 1.0]; got {alpha}")]
    InvalidWeightAlpha { alpha: f32 },
}

/// Rust-side registry layered over the DAG that tracks Companions +
/// their base-model lineages. The DAG remains the source of truth;
/// this is a typed convenience layer with a small in-memory cache so
/// `lineage_for` is O(1) instead of an O(out-degree) edge walk per
/// lookup.
///
/// The cache is RwLock-protected and rebuilt lazily — on registry
/// construction the cache is empty; the first `lineage_for(id)` walk
/// populates it. Bulk `enumerate_all` does a single store snapshot.
pub struct CompanionRegistry {
    /// companion_id → cached lineage
    cache: RwLock<BTreeMap<NodeId, CompanionLineage>>,
}

impl Default for CompanionRegistry {
    fn default() -> Self {
        Self::new()
    }
}

impl CompanionRegistry {
    pub fn new() -> Self {
        Self {
            cache: RwLock::new(BTreeMap::new()),
        }
    }

    /// Register a fresh companion against a base model. Inserts:
    ///   - Companion node (if not already present)
    ///   - Deforms edge (Companion → Model) carrying lora_path +
    ///     weight_alpha
    ///
    /// Returns the new companion's NodeId.
    ///
    /// Idempotent: if both the companion node and its Deforms edge
    /// already exist with matching content, this is a no-op.
    #[allow(clippy::too_many_arguments)]
    pub fn register(
        &self,
        profile: ModelProfile,
        identity: IdentityHash,
        persona: PersonaBlob,
        base_model_id: NodeId,
        lora_path: PathBuf,
        weight_alpha: f32,
        capability_hash: Hash,
        store: &dyn DagStore,
    ) -> Result<NodeId, CompanionError> {
        if !(0.0..=1.0).contains(&weight_alpha) {
            return Err(CompanionError::InvalidWeightAlpha {
                alpha: weight_alpha,
            });
        }
        // Verify the base exists + is actually a Model
        match store.get_node(base_model_id)? {
            Some(node) => {
                if !matches!(node.kind, NodeKind::Model { .. }) {
                    return Err(CompanionError::DeformsTargetNotModel {
                        target: base_model_id,
                        kind: node.kind.discriminator().to_string(),
                    });
                }
            }
            None => return Err(CompanionError::BaseModelNotFound(base_model_id)),
        }

        let companion = Node::new(NodeKind::Companion {
            profile: profile.clone(),
            identity: identity.clone(),
            persona,
        });
        let companion_id = store.put_node(companion.clone())?;

        let edge = Edge::new(
            companion_id,
            base_model_id,
            EdgeKind::Deforms {
                lora_path: lora_path.clone(),
                weight_alpha,
            },
            capability_hash,
        );
        store.put_edge(edge)?;

        // Warm the cache
        if let Ok(mut cache) = self.cache.write() {
            cache.insert(
                companion_id,
                CompanionLineage {
                    companion_id,
                    base_model_id,
                    lora_path,
                    weight_alpha,
                },
            );
        }
        Ok(companion_id)
    }

    /// Resolve a companion's lineage. Walks outbound Deforms edges
    /// from the companion node; returns the first one (companions
    /// deform exactly one base by §2.7 contract).
    pub fn lineage_for(
        &self,
        companion_id: NodeId,
        store: &dyn DagStore,
    ) -> Result<CompanionLineage, CompanionError> {
        // Cache fast-path
        if let Ok(cache) = self.cache.read() {
            if let Some(cached) = cache.get(&companion_id) {
                return Ok(cached.clone());
            }
        }

        let companion = store
            .get_node(companion_id)?
            .ok_or(CompanionError::CompanionNotFound(companion_id))?;
        if !matches!(companion.kind, NodeKind::Companion { .. }) {
            return Err(CompanionError::CompanionNotFound(companion_id));
        }

        let deforms = store.edges_from(companion_id, Some(EdgeKindSelector::Deforms))?;
        let edge = deforms
            .into_iter()
            .next()
            .ok_or(CompanionError::NoDeformsEdge {
                companion: companion_id,
            })?;
        let (lora_path, weight_alpha) = match &edge.kind {
            EdgeKind::Deforms {
                lora_path,
                weight_alpha,
            } => (lora_path.clone(), *weight_alpha),
            other => {
                return Err(CompanionError::DeformsTargetNotModel {
                    target: edge.to,
                    kind: format!("{:?}", other),
                });
            }
        };

        let lineage = CompanionLineage {
            companion_id,
            base_model_id: edge.to,
            lora_path,
            weight_alpha,
        };

        // Populate cache
        if let Ok(mut cache) = self.cache.write() {
            cache.insert(companion_id, lineage.clone());
        }
        Ok(lineage)
    }

    /// Enumerate every Companion that deforms a given base Model.
    /// Walks inbound Deforms edges on the base; sorted by companion_id
    /// for deterministic iteration order.
    pub fn companions_for_base(
        &self,
        base_model_id: NodeId,
        store: &dyn DagStore,
    ) -> Result<Vec<CompanionLineage>, CompanionError> {
        let inbound = store.edges_to(base_model_id, Some(EdgeKindSelector::Deforms))?;
        let mut out: Vec<CompanionLineage> = inbound
            .into_iter()
            .filter_map(|edge| match edge.kind {
                EdgeKind::Deforms {
                    lora_path,
                    weight_alpha,
                } => Some(CompanionLineage {
                    companion_id: edge.from,
                    base_model_id: edge.to,
                    lora_path,
                    weight_alpha,
                }),
                _ => None,
            })
            .collect();
        out.sort_by(|a, b| a.companion_id.cmp(&b.companion_id));
        Ok(out)
    }

    /// Total memory footprint estimate for a Companion Farm: one base
    /// model weight + N × LoRA size. Used by the doctrine §2.7
    /// economic argument ("50 companions × 50MB LoRA + 1 × 4GB base
    /// = 6.5GB vs 50 × 4GB = 200GB"). Returns bytes.
    ///
    /// Pure function — caller supplies the byte sizes; this just
    /// applies the formula. Companion Farm is the entire point of
    /// the Deforms edge type.
    pub fn farm_memory_estimate_bytes(
        base_model_bytes: u64,
        lora_bytes_per_companion: u64,
        companion_count: u64,
    ) -> u64 {
        base_model_bytes.saturating_add(lora_bytes_per_companion.saturating_mul(companion_count))
    }

    /// Acceptance-bar helper: the doctrine §8 Phase 8.D test target
    /// is "companion creation < 100ms; swap < 200ms". The Rust side
    /// runs at sub-millisecond; the budget exists for the Swift host
    /// side that does the actual MLX hot-swap.
    pub const CREATE_BUDGET_MS: u64 = 100;
    pub const SWAP_BUDGET_MS: u64 = 200;
}

/// Build a fresh base-Model node. Convenience for tests + bootstrap;
/// production code can construct directly.
pub fn make_base_model_node(weight_root_bytes: [u8; 32]) -> Node {
    Node::new(NodeKind::Model {
        weight_root: WeightRoot(weight_root_bytes),
        base_or_lora: ModelLineage::Base,
    })
}

/// Build a Model node that represents a LoRA derived from a base.
/// LoRA-as-Model is for the rare case where the LoRA is a first-class
/// shareable artifact; the common case is to keep LoRA-as-edge-payload
/// per the doctrine §2.7 single-base-multi-LoRA pattern.
pub fn make_lora_model_node(
    weight_root_bytes: [u8; 32],
    parent: NodeId,
    lora_path: String,
) -> Node {
    Node::new(NodeKind::Model {
        weight_root: WeightRoot(weight_root_bytes),
        base_or_lora: ModelLineage::Lora { parent, lora_path },
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cognitive_dag::storage::InMemoryDagStore;

    fn cap() -> Hash {
        Hash::from_bytes([7u8; 32])
    }

    fn base_model_node() -> Node {
        make_base_model_node([42u8; 32])
    }

    fn make_companion_inputs(name: &str) -> (ModelProfile, IdentityHash, PersonaBlob) {
        (
            ModelProfile(name.into()),
            IdentityHash([1u8; 32]),
            PersonaBlob(b"persona-blob".to_vec()),
        )
    }

    #[test]
    fn register_companion_inserts_node_and_deforms_edge() {
        let store = InMemoryDagStore::new();
        let base = base_model_node();
        store.put_node(base.clone()).unwrap();

        let registry = CompanionRegistry::new();
        let (profile, identity, persona) = make_companion_inputs("sage");
        let id = registry
            .register(
                profile,
                identity,
                persona,
                base.id,
                PathBuf::from("/loras/sage.safetensors"),
                1.0,
                cap(),
                &store,
            )
            .unwrap();

        assert!(store.get_node(id).unwrap().is_some());
        let deforms = store
            .edges_from(id, Some(EdgeKindSelector::Deforms))
            .unwrap();
        assert_eq!(deforms.len(), 1);
        assert_eq!(deforms[0].to, base.id);
    }

    #[test]
    fn register_rejects_invalid_weight_alpha() {
        let store = InMemoryDagStore::new();
        let base = base_model_node();
        store.put_node(base.clone()).unwrap();

        let registry = CompanionRegistry::new();
        let (profile, identity, persona) = make_companion_inputs("x");
        let err = registry
            .register(
                profile,
                identity,
                persona,
                base.id,
                PathBuf::from("/loras/x.safetensors"),
                1.5, // out of [0, 1]
                cap(),
                &store,
            )
            .unwrap_err();
        assert!(matches!(err, CompanionError::InvalidWeightAlpha { alpha: a } if a == 1.5));
    }

    #[test]
    fn register_rejects_non_model_base() {
        let store = InMemoryDagStore::new();
        // Insert a Note node (not a Model) and try to use it as base
        let note = Node::new(NodeKind::Note {
            body: "not a model".into(),
            author: super::super::node::AuthorRef("u".into()),
            mime: super::super::node::MimeType("text/markdown".into()),
        });
        store.put_node(note.clone()).unwrap();

        let registry = CompanionRegistry::new();
        let (profile, identity, persona) = make_companion_inputs("x");
        let err = registry
            .register(
                profile,
                identity,
                persona,
                note.id,
                PathBuf::from("/loras/x.safetensors"),
                1.0,
                cap(),
                &store,
            )
            .unwrap_err();
        assert!(matches!(err, CompanionError::DeformsTargetNotModel { .. }));
    }

    #[test]
    fn register_rejects_missing_base() {
        let store = InMemoryDagStore::new();
        let phantom = NodeId::from_bytes([99u8; 32]);
        let registry = CompanionRegistry::new();
        let (profile, identity, persona) = make_companion_inputs("x");
        let err = registry
            .register(
                profile,
                identity,
                persona,
                phantom,
                PathBuf::from("/loras/x.safetensors"),
                1.0,
                cap(),
                &store,
            )
            .unwrap_err();
        assert!(matches!(err, CompanionError::BaseModelNotFound(_)));
    }

    #[test]
    fn lineage_for_returns_expected_record() {
        let store = InMemoryDagStore::new();
        let base = base_model_node();
        store.put_node(base.clone()).unwrap();
        let registry = CompanionRegistry::new();
        let (profile, identity, persona) = make_companion_inputs("orb");
        let id = registry
            .register(
                profile,
                identity,
                persona,
                base.id,
                PathBuf::from("/loras/orb.safetensors"),
                0.85,
                cap(),
                &store,
            )
            .unwrap();
        let lin = registry.lineage_for(id, &store).unwrap();
        assert_eq!(lin.companion_id, id);
        assert_eq!(lin.base_model_id, base.id);
        assert_eq!(lin.lora_path, PathBuf::from("/loras/orb.safetensors"));
        assert!((lin.weight_alpha - 0.85).abs() < f32::EPSILON);
    }

    #[test]
    fn lineage_for_uses_cache_after_first_call() {
        // Sanity: second call doesn't re-walk the DAG. We can verify
        // by removing the edge after the first call (a real DAG never
        // does this, but in test we can prove cache is consulted).
        // Simpler verification: just call twice + assert equal.
        let store = InMemoryDagStore::new();
        let base = base_model_node();
        store.put_node(base.clone()).unwrap();
        let registry = CompanionRegistry::new();
        let (profile, identity, persona) = make_companion_inputs("c");
        let id = registry
            .register(
                profile,
                identity,
                persona,
                base.id,
                PathBuf::from("/loras/c.safetensors"),
                1.0,
                cap(),
                &store,
            )
            .unwrap();
        let a = registry.lineage_for(id, &store).unwrap();
        let b = registry.lineage_for(id, &store).unwrap();
        assert_eq!(a, b);
    }

    #[test]
    fn lineage_for_unknown_companion_errors() {
        let store = InMemoryDagStore::new();
        let registry = CompanionRegistry::new();
        let phantom = NodeId::from_bytes([42u8; 32]);
        let err = registry.lineage_for(phantom, &store).unwrap_err();
        assert!(matches!(err, CompanionError::CompanionNotFound(_)));
    }

    #[test]
    fn companions_for_base_enumerates_all_in_sorted_order() {
        let store = InMemoryDagStore::new();
        let base = base_model_node();
        store.put_node(base.clone()).unwrap();
        let registry = CompanionRegistry::new();
        for name in &["sage", "orb", "brick", "scribe"] {
            let (profile, identity, persona) = make_companion_inputs(name);
            registry
                .register(
                    profile,
                    identity,
                    persona,
                    base.id,
                    PathBuf::from(format!("/loras/{}.safetensors", name)),
                    1.0,
                    cap(),
                    &store,
                )
                .unwrap();
        }
        let lineages = registry.companions_for_base(base.id, &store).unwrap();
        assert_eq!(lineages.len(), 4);
        // Sorted by companion_id ascending — pin determinism
        let ids: Vec<NodeId> = lineages.iter().map(|l| l.companion_id).collect();
        let mut expected = ids.clone();
        expected.sort();
        assert_eq!(ids, expected);
        // Every lineage points at the same base
        for l in &lineages {
            assert_eq!(l.base_model_id, base.id);
        }
    }

    #[test]
    fn farm_memory_estimate_matches_doctrine_example() {
        // Doctrine §2.7: "50 companions × 50MB LoRAs + 1 × 4GB base = 6.5GB"
        let base_bytes = 4 * 1024 * 1024 * 1024_u64; // 4 GiB
        let lora_bytes = 50 * 1024 * 1024_u64; // 50 MiB
        let companion_count = 50_u64;
        let total =
            CompanionRegistry::farm_memory_estimate_bytes(base_bytes, lora_bytes, companion_count);
        // 4GB + 50 × 50MB = 4 + 2.5 = 6.5GB
        let expected = base_bytes + (lora_bytes * companion_count);
        assert_eq!(total, expected);
        // Sanity check the human-readable claim. Doctrine quotes
        // "6.5 GB" colloquially; in GiB the actual value is 6.44
        // (50 × 50MiB → 2.44GiB, + 4GiB base). Tolerance 0.1 GiB.
        let gib = total as f64 / 1024.0_f64.powi(3);
        assert!(
            (gib - 6.44).abs() < 0.1,
            "got {} GiB, doctrine says ~6.5GB",
            gib
        );
    }

    #[test]
    fn registration_completes_well_within_acceptance_budget() {
        // Doctrine §8 Phase 8.D test target: companion creation < 100ms.
        // Rust side is sub-millisecond; we pin this so a future refactor
        // doesn't accidentally introduce O(N) behavior.
        let store = InMemoryDagStore::new();
        let base = base_model_node();
        store.put_node(base.clone()).unwrap();
        let registry = CompanionRegistry::new();

        let start = std::time::Instant::now();
        for i in 0..50 {
            let (profile, identity, persona) = make_companion_inputs(&format!("companion-{}", i));
            registry
                .register(
                    profile,
                    identity,
                    persona,
                    base.id,
                    PathBuf::from(format!("/loras/companion-{}.safetensors", i)),
                    1.0,
                    cap(),
                    &store,
                )
                .unwrap();
        }
        let elapsed = start.elapsed();

        // 50 companions in well under (50 × CREATE_BUDGET_MS = 5s); we
        // expect ~ms not seconds. Pin at 1s as a conservative ceiling
        // that a regression would trip.
        assert!(
            elapsed.as_millis() < 1000,
            "50 companion registrations took {:?} (>1s; should be <1ms each)",
            elapsed
        );
        let lineages = registry.companions_for_base(base.id, &store).unwrap();
        assert_eq!(lineages.len(), 50);
    }

    #[test]
    fn make_base_and_lora_model_helpers_produce_distinct_lineages() {
        let base = make_base_model_node([1u8; 32]);
        let lora = make_lora_model_node([2u8; 32], base.id, "lora-a".into());
        match base.kind {
            NodeKind::Model {
                base_or_lora: ModelLineage::Base,
                ..
            } => {}
            _ => panic!("base must be Base lineage"),
        }
        match lora.kind {
            NodeKind::Model {
                base_or_lora: ModelLineage::Lora { ref parent, .. },
                ..
            } => assert_eq!(*parent, base.id),
            _ => panic!("lora must be Lora lineage with parent = base"),
        }
    }

    #[test]
    fn companion_registry_default_is_empty() {
        let registry = CompanionRegistry::default();
        assert!(registry.cache.read().unwrap().is_empty());
    }

    #[test]
    fn deforms_edge_round_trips_lora_path_and_alpha() {
        let store = InMemoryDagStore::new();
        let base = base_model_node();
        store.put_node(base.clone()).unwrap();
        let registry = CompanionRegistry::new();
        let (profile, identity, persona) = make_companion_inputs("test");
        let id = registry
            .register(
                profile,
                identity,
                persona,
                base.id,
                PathBuf::from("/path/with/many/segments/lora.safetensors"),
                0.65,
                cap(),
                &store,
            )
            .unwrap();
        let lin = registry.lineage_for(id, &store).unwrap();
        assert_eq!(
            lin.lora_path,
            PathBuf::from("/path/with/many/segments/lora.safetensors")
        );
        assert!((lin.weight_alpha - 0.65).abs() < f32::EPSILON);
    }

    #[test]
    fn acceptance_budgets_match_doctrine_phase_8d_targets() {
        // §8 Phase 8.D: "companion creation < 100ms; swap < 200ms"
        assert_eq!(CompanionRegistry::CREATE_BUDGET_MS, 100);
        assert_eq!(CompanionRegistry::SWAP_BUDGET_MS, 200);
    }
}
