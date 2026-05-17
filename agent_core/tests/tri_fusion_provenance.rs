use agent_core::artifacts::ArtifactRef;
use agent_core::cognitive_dag::migration::{DagMirror, LedgerMutation, ProvenanceLedgerMirror};
use agent_core::cognitive_dag::{DagStore, EdgeKindSelector, Hash, InMemoryDagStore};
use agent_core::mutations::{
    BlockRef, MutationActor, MutationEnvelope, MutationStatus, Reversibility, Sensitivity, SourceOp,
};
use agent_core::provenance::ledger::{
    ClaimId, ClaimKind, ClaimLedger, ClaimStatus, EvidenceId, LedgerError,
};
use agent_core::tri_fusion::{
    TriFusionCognitiveDagProvenanceVerificationStatus, TriFusionDocument, TriFusionMutation,
    TriFusionMutationActor, TriFusionMutationEnvelope, TriFusionProvenanceStatus,
    TriFusionSourceFormat,
};
use serde_json::{json, Value};

fn paragraph(block_id: &str, text: &str) -> Value {
    json!({
        "type": "paragraph",
        "attrs": {
            "id": block_id,
        },
        "content": [
            {
                "type": "text",
                "text": text,
            },
        ],
    })
}

fn document() -> TriFusionDocument {
    TriFusionDocument::from_json_value(json!({
        "type": "doc",
        "content": [
            paragraph("b1", "One"),
            paragraph("b2", "Two"),
        ],
    }))
    .unwrap()
}

fn cap() -> Hash {
    Hash::from_bytes([39u8; 32])
}

fn envelope(
    document: &TriFusionDocument,
    mutation_id: &str,
    actor: TriFusionMutationActor,
    source_format: TriFusionSourceFormat,
    mutation: TriFusionMutation,
) -> TriFusionMutationEnvelope {
    TriFusionMutationEnvelope {
        mutation_id: mutation_id.to_string(),
        document_id: "doc-1".to_string(),
        base_document_hash: document.hash(),
        actor,
        source_format,
        rationale: "iteration 37 provenance envelope test".to_string(),
        mutation,
    }
}

fn hex_lower(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        out.push(HEX[(byte >> 4) as usize] as char);
        out.push(HEX[(byte & 0x0f) as usize] as char);
    }
    out
}

#[test]
fn accepted_agent_mutation_builds_pending_mutation_envelope() {
    let base = document();
    let result = base
        .apply_mutation_envelope(envelope(
            &base,
            "tf-env-37",
            TriFusionMutationActor::Agent {
                run_id: "run-37".to_string(),
            },
            TriFusionSourceFormat::Json,
            TriFusionMutation::InsertBlock {
                artifact_id: "doc-1".to_string(),
                after_block_id: Some("b1".to_string()),
                block: paragraph("b3", "Three"),
            },
        ))
        .unwrap();

    let pending = result
        .pending_mutation_envelope(37, 1_779_019_200_000)
        .unwrap();

    assert_eq!(pending.mutation_id, "tf-env-37");
    assert_eq!(pending.run_id.as_deref(), Some("run-37"));
    assert_eq!(pending.sequence, 37);
    assert_eq!(
        pending.actor,
        MutationActor::Agent {
            run_id: "run-37".to_string(),
        }
    );
    assert_eq!(pending.status, MutationStatus::Pending);
    assert_eq!(pending.created_at_ms, 1_779_019_200_000);
    assert_eq!(pending.committed_at_ms, None);
    assert_eq!(
        pending.op,
        SourceOp::ArtifactUpdate {
            artifact_id: "doc-1".to_string(),
        }
    );
    assert_eq!(pending.sensitivity, Sensitivity::Internal);
    assert_eq!(pending.reversibility, Reversibility::Reversible);
    assert_eq!(pending.integrity_hash, "");
    assert_eq!(
        pending.schema_version,
        MutationEnvelope::CURRENT_SCHEMA_VERSION
    );
    assert_eq!(pending.touched_artifacts, vec![ArtifactRef::new("doc-1")]);
    assert_eq!(pending.touched_blocks, vec![BlockRef::new("doc-1", "b3")]);
    assert!(pending.affects_anything());
    assert!(pending.affects_summary);
    assert!(pending.affects_body);
    assert!(pending.affects_outline);
    assert!(pending.affects_search_projection);
    assert!(!pending.affects_backlinks);
    assert!(!pending.affects_graph);
}

#[test]
fn link_mutation_envelope_marks_backlink_and_graph_invalidations() {
    let base = document();
    let result = base
        .apply_mutation_envelope(envelope(
            &base,
            "tf-env-37-link",
            TriFusionMutationActor::System,
            TriFusionSourceFormat::Html,
            TriFusionMutation::LinkBlock {
                artifact_id: "doc-1".to_string(),
                from_block_id: "b1".to_string(),
                to_block_id: "b2".to_string(),
                relation: "supports".to_string(),
            },
        ))
        .unwrap();

    let pending = result.witness.pending_mutation_envelope(38, 1).unwrap();

    assert_eq!(pending.mutation_id, "tf-env-37-link");
    assert_eq!(pending.run_id, None);
    assert_eq!(pending.actor, MutationActor::System);
    assert_eq!(pending.touched_artifacts, vec![ArtifactRef::new("doc-1")]);
    assert_eq!(
        pending.touched_blocks,
        vec![BlockRef::new("doc-1", "b1"), BlockRef::new("doc-1", "b2")]
    );
    assert!(pending.affects_anything());
    assert!(pending.affects_summary);
    assert!(!pending.affects_body);
    assert!(!pending.affects_outline);
    assert!(!pending.affects_search_projection);
    assert!(pending.affects_backlinks);
    assert!(pending.affects_graph);
}

#[test]
fn accepted_mutation_commits_claim_ledger_provenance() {
    let base = document();
    let result = base
        .apply_mutation_envelope(envelope(
            &base,
            "tf-env-38",
            TriFusionMutationActor::Agent {
                run_id: "run-38".to_string(),
            },
            TriFusionSourceFormat::Json,
            TriFusionMutation::InsertBlock {
                artifact_id: "doc-1".to_string(),
                after_block_id: Some("b2".to_string()),
                block: paragraph("b4", "Four"),
            },
        ))
        .unwrap();

    let mut ledger = ClaimLedger::new();
    let witness = result
        .commit_claim_ledger_provenance(&mut ledger, 1_779_019_201_000)
        .unwrap();

    let claim_id = ClaimId::new(format!("tri_fusion:claim:{}", result.witness.mutation_id));
    let evidence_id = EvidenceId::new(format!(
        "tri_fusion:evidence:{}",
        result.witness.mutation_id
    ));
    let dag_ids = result
        .witness
        .cognitive_dag_provenance_ids(1_779_019_201_000);
    let claim = ledger.claim(&claim_id).unwrap();
    let evidence = ledger.evidence(&evidence_id).unwrap();

    assert_eq!(ledger.claim_count(), 1);
    assert_eq!(ledger.evidence_count(), 1);
    assert_eq!(claim.kind, ClaimKind::CodeInvariant);
    assert_eq!(claim.status, ClaimStatus::Active);
    assert_eq!(claim.created_at_ms, 1_779_019_201_000);
    assert!(claim.text.contains("Tri-Fusion mutation"));
    assert!(claim.text.contains("document doc-1"));
    assert!(claim.text.contains(&result.witness.before_hash.to_string()));
    assert!(claim.text.contains(&result.witness.after_hash.to_string()));
    assert!(evidence.source.starts_with(&format!(
        "tri_fusion_witness:{}:",
        result.witness.mutation_id
    )));
    assert_eq!(
        witness.provenance_status,
        TriFusionProvenanceStatus::Committed
    );
    assert_eq!(witness.mutation_envelope_id.as_deref(), Some("tf-env-38"));
    assert_eq!(
        witness.claim_graph_node_id.as_deref(),
        Some(dag_ids.claim_node_id.as_str())
    );
    assert_eq!(
        witness.cognitive_dag_edge_id.as_deref(),
        Some(dag_ids.derives_from_evidence_edge_id.as_str())
    );
}

#[test]
fn cognitive_dag_provenance_ids_match_provenance_mirror() {
    let base = document();
    let result = base
        .apply_mutation_envelope(envelope(
            &base,
            "tf-env-39",
            TriFusionMutationActor::Agent {
                run_id: "run-39".to_string(),
            },
            TriFusionSourceFormat::Html,
            TriFusionMutation::MutateBlock {
                artifact_id: "doc-1".to_string(),
                block_id: "b2".to_string(),
                replacement: paragraph("b2", "Two revised"),
            },
        ))
        .unwrap();
    let created_at_ms = 1_779_019_204_000;
    let ids = result.witness.cognitive_dag_provenance_ids(created_at_ms);
    let claim_id = result.witness.provenance_claim_id().0;
    let evidence_id = result.witness.provenance_evidence_id().0;
    let evidence_source = result.witness.provenance_evidence_source();

    let store = InMemoryDagStore::new();
    ProvenanceLedgerMirror::mirror_write(
        &LedgerMutation::EvidenceCommitted {
            evidence_id: evidence_id.clone(),
            source: evidence_source,
            created_at_ms,
        },
        &store,
        cap(),
    )
    .unwrap();
    let claim_node_id = ProvenanceLedgerMirror::mirror_write(
        &LedgerMutation::ClaimCommitted {
            claim_id,
            text: result.witness.provenance_claim_text(),
            derived_from: Vec::new(),
            supported_by: vec![evidence_id],
            created_at_ms,
        },
        &store,
        cap(),
    )
    .unwrap();
    let edges = store
        .edges_from(claim_node_id, Some(EdgeKindSelector::DerivesFrom))
        .unwrap();
    let verification = result
        .witness
        .verify_cognitive_dag_provenance(&store, created_at_ms)
        .unwrap();

    assert_eq!(claim_node_id.to_hex(), ids.claim_node_id);
    assert_eq!(edges.len(), 1);
    assert_eq!(edges[0].to.to_hex(), ids.evidence_node_id);
    assert_eq!(
        hex_lower(edges[0].id().as_bytes()),
        ids.derives_from_evidence_edge_id
    );
    assert_eq!(
        verification.status,
        TriFusionCognitiveDagProvenanceVerificationStatus::Complete
    );
    assert!(verification.claim_node_present);
    assert!(verification.evidence_node_present);
    assert!(verification.derives_from_evidence_edge_present);
    assert_eq!(verification.ids, ids);
}

#[test]
fn cognitive_dag_provenance_verifier_reports_missing_nodes() {
    let base = document();
    let result = base
        .apply_mutation_envelope(envelope(
            &base,
            "tf-env-40",
            TriFusionMutationActor::System,
            TriFusionSourceFormat::Json,
            TriFusionMutation::TranscludeBlock {
                artifact_id: "doc-1".to_string(),
                after_block_id: Some("b1".to_string()),
                source_block_id: "b2".to_string(),
                transclusion_block_id: "b5".to_string(),
            },
        ))
        .unwrap();
    let store = InMemoryDagStore::new();
    let verification = result
        .witness
        .verify_cognitive_dag_provenance(&store, 1_779_019_205_000)
        .unwrap();

    assert_eq!(
        verification.status,
        TriFusionCognitiveDagProvenanceVerificationStatus::MissingNode
    );
    assert!(!verification.claim_node_present);
    assert!(!verification.evidence_node_present);
    assert!(!verification.derives_from_evidence_edge_present);
}

#[test]
fn cognitive_dag_provenance_verifier_reports_missing_derives_from_edge() {
    let base = document();
    let result = base
        .apply_mutation_envelope(envelope(
            &base,
            "tf-env-42",
            TriFusionMutationActor::Agent {
                run_id: "run-42".to_string(),
            },
            TriFusionSourceFormat::Markdown,
            TriFusionMutation::InsertBlock {
                artifact_id: "doc-1".to_string(),
                after_block_id: Some("b2".to_string()),
                block: paragraph("b6", "Six"),
            },
        ))
        .unwrap();
    let created_at_ms = 1_779_019_207_000;
    let claim_id = result.witness.provenance_claim_id().0;
    let evidence_id = result.witness.provenance_evidence_id().0;
    let store = InMemoryDagStore::new();

    ProvenanceLedgerMirror::mirror_write(
        &LedgerMutation::EvidenceCommitted {
            evidence_id: evidence_id.clone(),
            source: result.witness.provenance_evidence_source(),
            created_at_ms,
        },
        &store,
        cap(),
    )
    .unwrap();
    ProvenanceLedgerMirror::mirror_write(
        &LedgerMutation::ClaimCommitted {
            claim_id,
            text: result.witness.provenance_claim_text(),
            derived_from: Vec::new(),
            supported_by: Vec::new(),
            created_at_ms,
        },
        &store,
        cap(),
    )
    .unwrap();

    let verification = result
        .witness
        .verify_cognitive_dag_provenance(&store, created_at_ms)
        .unwrap();

    assert_eq!(
        verification.status,
        TriFusionCognitiveDagProvenanceVerificationStatus::MissingDerivesFromEdge
    );
    assert!(verification.claim_node_present);
    assert!(verification.evidence_node_present);
    assert!(!verification.derives_from_evidence_edge_present);
}

#[test]
fn provenance_commit_rejects_duplicate_claim_before_evidence_write() {
    let base = document();
    let result = base
        .apply_mutation_envelope(envelope(
            &base,
            "tf-env-38-duplicate",
            TriFusionMutationActor::System,
            TriFusionSourceFormat::Markdown,
            TriFusionMutation::LinkBlock {
                artifact_id: "doc-1".to_string(),
                from_block_id: "b1".to_string(),
                to_block_id: "b2".to_string(),
                relation: "relates_to".to_string(),
            },
        ))
        .unwrap();

    let mut ledger = ClaimLedger::new();
    let first = result
        .commit_claim_ledger_provenance(&mut ledger, 1_779_019_202_000)
        .unwrap();
    let duplicate = result
        .commit_claim_ledger_provenance(&mut ledger, 1_779_019_203_000)
        .unwrap_err();

    assert_eq!(
        duplicate,
        LedgerError::DuplicateId(result.witness.provenance_claim_id().0)
    );
    assert!(first.claim_graph_node_id.is_some());
    assert_eq!(ledger.claim_count(), 1);
    assert_eq!(ledger.evidence_count(), 1);
}
