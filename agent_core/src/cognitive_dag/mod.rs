//! Cognitive DAG — Phase 8.A scaffold.
//!
//! Per `docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md`.
//!
//! Phase 8.A scope (this module):
//! - `node` — typed `NodeKind` (10 variants) + content-addressed
//!   `NodeId` via BLAKE3 + canonical-JSON serialization
//! - `edge` — typed `EdgeKind` (10 variants) + Merkle-signed `Edge`
//!   with content-addressed `EdgeId`
//! - `storage` — `DagStore` trait + `InMemoryDagStore` reference
//!   implementation (RwLock-protected BTreeMap; deterministic
//!   iteration order)
//! - `merkle` — Merkle root over the entire store (domain-separated
//!   BLAKE3; reproducible across stores with identical content)
//!
//! Phase 8.A NOT in scope (handled by future slices):
//! - redb-backed `DagStore` implementation (next slice; same trait)
//! - Resonance propagation across `DerivesFrom` / `Contradicts`
//!   (Phase 8.B)
//! - Macaroon-style capability signing (Phase 8.C; today's
//!   `EdgeSignature` is a deterministic content hash)
//! - LoRA-light Companion `Deforms` integration (Phase 8.D)
//! - Subsystem migration (Phase 8.E)
//! - `epistemos-trace verify-replay` (Phase 8.F)
//! - Doctrine linter (Phase 8.G)
//!
//! The seven existing subsystems remain authoritative throughout
//! Phase 8.A-G; the DAG runs alongside, mirroring writes for one week
//! before Phase 8.H flips authority.

pub mod edge;
pub mod merkle;
pub mod node;
pub mod resonance;
pub mod storage;

// Re-export the canonical surface so call sites can `use
// crate::cognitive_dag::{Node, NodeKind, Edge, EdgeKind, DagStore,
// InMemoryDagStore};` without traversing the module tree.
pub use edge::{
    AnnotationKind, Edge, EdgeId, EdgeKind, EdgeKindSelector, EdgeSignature, MemoryTier,
};
pub use merkle::merkle_root_over;
pub use node::{
    AuthorRef, CapabilityKind, CapabilityScope, ClaimScope, ContextHash, DagAgentEventKind,
    EvidenceBlob, EvidenceKind, Hash, IdentityHash, MimeType, ModelLineage, ModelProfile, Node,
    NodeId, NodeKind, NodeTier, OutcomeList, PersonaBlob, SessionId, SourceRef, Timestamp, ToolId,
    ToolSurface, WeightRoot,
};
pub use resonance::{
    add_contradiction_then_propagate, add_evidence_then_propagate, evaluate_claim_truth,
    propagate_truth_change, TruthCache,
};
pub use storage::{DagError, DagSnapshot, DagStore, InMemoryDagStore};

// ── End-to-end integration sanity (one test crossing all four
// modules) ────────────────────────────────────────────────────────────

#[cfg(test)]
mod integration_tests {
    use super::*;

    #[test]
    fn end_to_end_phase_8a_scaffold_smoke() {
        // 1. Create a Note + Claim + Evidence + Capability node;
        //    insert into an InMemoryDagStore.
        // 2. Create DerivesFrom (Claim → Evidence) + AnnotatedBy
        //    (Note → Note) edges; insert.
        // 3. Snapshot. Verify merkle_root + schema_version + node /
        //    edge counts.
        // 4. Re-snapshot a fresh store with identical content; verify
        //    byte-identical canonical JSON.
        let store_a = InMemoryDagStore::new();

        let note = Node::new_at(
            NodeKind::Note {
                body: "phase 8.a".into(),
                author: AuthorRef("test".into()),
                mime: MimeType("text/markdown".into()),
            },
            Timestamp(1000),
        );
        let claim_x = Node::new_at(
            NodeKind::Claim {
                proposition: "X is true".into(),
                scope: ClaimScope::Vault,
                source: SourceRef("test".into()),
            },
            Timestamp(1100),
        );
        let evidence = Node::new_at(
            NodeKind::Evidence {
                kind: EvidenceKind::Citation,
                payload: EvidenceBlob(b"proof".to_vec()),
                captured_at: Timestamp(1050),
            },
            Timestamp(1050),
        );
        let capability = Node::new_at(
            NodeKind::Capability {
                kind: CapabilityKind::Approval,
                scope: CapabilityScope("test_scope".into()),
                expiry: None,
            },
            Timestamp(900),
        );

        let cap_hash = Hash::from_bytes([7u8; 32]);

        for n in [&note, &claim_x, &evidence, &capability] {
            store_a.put_node(n.clone()).unwrap();
        }

        let derives = Edge::new_at(
            claim_x.id,
            evidence.id,
            EdgeKind::DerivesFrom { strength: 0.95 },
            cap_hash,
            Timestamp(1200),
        );
        let annotates = Edge::new_at(
            note.id,
            note.id,
            EdgeKind::AnnotatedBy {
                kind: AnnotationKind::Tag,
            },
            cap_hash,
            Timestamp(1300),
        );

        store_a.put_edge(derives.clone()).unwrap();
        store_a.put_edge(annotates.clone()).unwrap();

        let snap_a = store_a.snapshot().unwrap();
        assert_eq!(snap_a.nodes.len(), 4);
        assert_eq!(snap_a.edges.len(), 2);
        assert_eq!(snap_a.schema_version, DagSnapshot::SCHEMA_VERSION);
        assert_ne!(snap_a.merkle_root, Hash::zero());

        // Verify edge signatures hold.
        for e in &snap_a.edges {
            assert!(e.verify_signature(&cap_hash));
        }

        // Reproducibility: a fresh store with the same inserts
        // produces a byte-identical canonical-JSON snapshot.
        let store_b = InMemoryDagStore::new();
        for n in [&note, &claim_x, &evidence, &capability] {
            store_b.put_node(n.clone()).unwrap();
        }
        store_b.put_edge(derives).unwrap();
        store_b.put_edge(annotates).unwrap();
        let snap_b = store_b.snapshot().unwrap();
        assert_eq!(
            serde_json::to_string(&snap_a).unwrap(),
            serde_json::to_string(&snap_b).unwrap(),
            "two stores with identical content must serialise to byte-identical snapshots"
        );
    }
}
