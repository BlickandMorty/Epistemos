//! Deterministic sample `.epbundle` generator for the Phase 8.F /
//! verify-replay CI gate.
//!
//! Per canonical-upgrade-audit B2 (2026-05-05): the
//! `epistemos-trace verify-replay` CLI subcommand needs a release-time
//! gate that runs the production binary against a real `.epbundle`
//! file. The integration test `epistemos_trace_e2e.rs` exercises the
//! binary against in-memory fixtures, but a separate CI step running
//! the binary against a generated file proves the production code path
//! end-to-end.
//!
//! This example writes a deterministic v2 bundle (ledger snapshot +
//! cognitive DAG snapshot + integrity hash) to the path given as the
//! first command-line argument, or `sample_v2.epbundle` in CWD if no
//! argument is given. CI then runs:
//!
//!   cargo run --example generate_sample_epbundle -- /tmp/sample.epbundle
//!   cargo run --bin epistemos_trace -- verify-replay /tmp/sample.epbundle
//!
//! and asserts the second invocation exits 0.
//!
//! The seed inputs are pinned constants so two runs of this example
//! produce byte-identical bundles. That way CI catches accidental
//! drift in the bundle wire format (any change in serialization order,
//! schema, or hash algorithm flips the bytes).

use std::process::ExitCode;

use agent_core::cognitive_dag::edge::{Edge, EdgeKind};
use agent_core::cognitive_dag::node::{
    AuthorRef, ClaimScope, EvidenceBlob, EvidenceKind, Hash, MimeType, Node, NodeKind,
    SourceRef, Timestamp,
};
use agent_core::cognitive_dag::storage::{DagStore, InMemoryDagStore};
use agent_core::mutations::types::{MutationActor, Reversibility, Sensitivity, SourceOp};
use agent_core::mutations::MutationEnvelope;
use agent_core::provenance::{
    Claim, ClaimId, ClaimLedger, Evidence, EvidenceId, ReplayBundle,
};

/// Pinned timestamp so the bundle bytes are deterministic across runs.
const FIXED_T_MS: i64 = 1_745_000_000_000;

/// Pinned capability hash for the DAG edge's signature. `[0xC4; 32]`
/// is searchable + structurally distinct from the dispatch sentinel
/// (`[0xE5; 32]`) + the all-zero/all-ones edge cases.
const FIXED_CAP_BYTES: [u8; 32] = [0xC4u8; 32];

fn seed_ledger() -> ClaimLedger {
    let mut ledger = ClaimLedger::new();
    ledger
        .commit_evidence(Evidence::new(
            EvidenceId::new("ev-sample-1"),
            "https://example.com/citation/1",
            FIXED_T_MS,
        ))
        .expect("evidence commit must succeed");
    ledger
        .commit_claim(
            Claim::new(
                ClaimId::new("c-sample-1"),
                "the canon-hardening protocol is live",
                FIXED_T_MS,
            ),
            vec![],
            vec![EvidenceId::new("ev-sample-1")],
        )
        .expect("claim commit must succeed");
    ledger
}

fn seed_dag_snapshot() -> agent_core::cognitive_dag::storage::DagSnapshot {
    let store = InMemoryDagStore::new();
    let cap = Hash::from_bytes(FIXED_CAP_BYTES);

    let note = Node::new_at(
        NodeKind::Note {
            body: "sample fixture for verify-replay CI gate".into(),
            author: AuthorRef("epistemos-trace-fixture".into()),
            mime: MimeType("text/markdown".into()),
        },
        Timestamp(1_000),
    );
    let claim = Node::new_at(
        NodeKind::Claim {
            proposition: "verify-replay binary closes the doctrine §10 contract".into(),
            scope: ClaimScope::Vault,
            source: SourceRef("canonical_upgrade_audit_b2".into()),
        },
        Timestamp(1_100),
    );
    let evidence = Node::new_at(
        NodeKind::Evidence {
            kind: EvidenceKind::Citation,
            payload: EvidenceBlob(b"doctrine-section-10-payload".to_vec()),
            captured_at: Timestamp(1_050),
        },
        Timestamp(1_050),
    );

    for n in [&note, &claim, &evidence] {
        store.put_node(n.clone()).expect("node insert");
    }

    let edge = Edge::new_at(
        claim.id,
        evidence.id,
        EdgeKind::DerivesFrom { strength: 1.0 },
        cap,
        Timestamp(1_200),
    );
    store.put_edge(edge).expect("edge insert");

    store.snapshot().expect("snapshot must succeed")
}

fn build_bundle() -> ReplayBundle {
    let ledger = seed_ledger();
    let dag = seed_dag_snapshot();
    let mutation = MutationEnvelope::pending(
        "m-sample-1".into(),
        1,
        MutationActor::User,
        SourceOp::ArtifactUpdate {
            artifact_id: "sample-doc-1".into(),
        },
        Sensitivity::Internal,
        Reversibility::Reversible,
        FIXED_T_MS,
    );
    ReplayBundle::build_with_dag(
        "epistemos-fixture-v2".into(),
        Some("ci-verify-replay-gate".into()),
        FIXED_T_MS,
        &ledger,
        vec![mutation],
        dag,
    )
    .expect("bundle build must succeed")
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    let path = args
        .get(1)
        .cloned()
        .unwrap_or_else(|| "sample_v2.epbundle".to_string());

    let bundle = build_bundle();
    let bytes = match bundle.to_epbundle_bytes() {
        Ok(b) => b,
        Err(e) => {
            eprintln!("error: bundle serialization failed: {e}");
            return ExitCode::from(1);
        }
    };

    if let Err(e) = std::fs::write(&path, &bytes) {
        eprintln!("error: cannot write `{path}`: {e}");
        return ExitCode::from(2);
    }

    eprintln!(
        "wrote {} bytes to {path} (bundle_id={} schema_version={} mutations={} claims={} evidence={} dag_nodes={} dag_edges={})",
        bytes.len(),
        bundle.bundle_id,
        bundle.schema_version,
        bundle.mutations.len(),
        bundle.ledger.claims.len(),
        bundle.ledger.evidence.len(),
        bundle.dag_snapshot.as_ref().map(|s| s.nodes.len()).unwrap_or(0),
        bundle.dag_snapshot.as_ref().map(|s| s.edges.len()).unwrap_or(0),
    );

    ExitCode::SUCCESS
}
