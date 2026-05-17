use agent_core::artifacts::ArtifactRef;
use agent_core::mutations::{
    BlockRef, MutationActor, MutationEnvelope, MutationStatus, Reversibility, Sensitivity, SourceOp,
};
use agent_core::tri_fusion::{
    TriFusionDocument, TriFusionMutation, TriFusionMutationActor, TriFusionMutationEnvelope,
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
