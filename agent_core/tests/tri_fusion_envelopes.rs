use agent_core::mutations::BlockRef;
use agent_core::tri_fusion::{
    TriFusionDocument, TriFusionError, TriFusionMutation, TriFusionMutationActor,
    TriFusionMutationEnvelope, TriFusionProvenanceStatus, TriFusionSourceFormat,
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
        rationale: "iteration 31 integration test".to_string(),
        mutation,
    }
}

#[test]
fn accepted_envelopes_preserve_metadata_for_all_mutation_kinds() {
    let cases = vec![
        (
            "env-insert",
            TriFusionMutation::InsertBlock {
                artifact_id: "artifact-1".to_string(),
                after_block_id: Some("b1".to_string()),
                block: paragraph("b3", "Three"),
            },
            "insert_block",
            vec![BlockRef::new("artifact-1", "b3")],
            TriFusionMutationActor::Agent {
                run_id: "run-31".to_string(),
            },
            TriFusionSourceFormat::Markdown,
        ),
        (
            "env-mutate",
            TriFusionMutation::MutateBlock {
                artifact_id: "artifact-1".to_string(),
                block_id: "b2".to_string(),
                replacement: paragraph("b2", "Second draft"),
            },
            "mutate_block",
            vec![BlockRef::new("artifact-1", "b2")],
            TriFusionMutationActor::User,
            TriFusionSourceFormat::Json,
        ),
        (
            "env-link",
            TriFusionMutation::LinkBlock {
                artifact_id: "artifact-1".to_string(),
                from_block_id: "b1".to_string(),
                to_block_id: "b2".to_string(),
                relation: "supports".to_string(),
            },
            "link_block",
            vec![
                BlockRef::new("artifact-1", "b1"),
                BlockRef::new("artifact-1", "b2"),
            ],
            TriFusionMutationActor::System,
            TriFusionSourceFormat::Html,
        ),
        (
            "env-transclude",
            TriFusionMutation::TranscludeBlock {
                artifact_id: "artifact-1".to_string(),
                after_block_id: Some("b2".to_string()),
                source_block_id: "b1".to_string(),
                transclusion_block_id: "t1".to_string(),
            },
            "transclude_block",
            vec![
                BlockRef::new("artifact-1", "b1"),
                BlockRef::new("artifact-1", "t1"),
            ],
            TriFusionMutationActor::Agent {
                run_id: "run-31-transclude".to_string(),
            },
            TriFusionSourceFormat::Json,
        ),
    ];

    for (mutation_id, mutation, mutation_kind, touched_blocks, actor, source_format) in cases {
        let base = document();
        let result = base
            .apply_mutation_envelope(envelope(
                &base,
                mutation_id,
                actor.clone(),
                source_format.clone(),
                mutation,
            ))
            .unwrap();

        assert_eq!(result.witness.before_hash, base.hash());
        assert_ne!(result.document.hash(), base.hash());
        assert_eq!(result.witness.mutation_kind, mutation_kind);
        assert_eq!(result.witness.touched_blocks, touched_blocks);
        assert_eq!(
            result.witness.envelope_mutation_id.as_deref(),
            Some(mutation_id)
        );
        assert_eq!(result.witness.document_id.as_deref(), Some("doc-1"));
        assert_eq!(result.witness.actor.as_ref(), Some(&actor));
        assert_eq!(result.witness.source_format.as_ref(), Some(&source_format));
        assert_eq!(
            result.witness.rationale.as_deref(),
            Some("iteration 31 integration test")
        );
        assert_eq!(
            result.witness.provenance_status,
            TriFusionProvenanceStatus::Deferred
        );
        assert_eq!(result.witness.mutation_envelope_id, None);
        assert_eq!(result.witness.claim_graph_node_id, None);
        assert_eq!(result.witness.cognitive_dag_edge_id, None);
    }
}

#[test]
fn stale_base_hash_rejects_before_mutating_document() {
    let base = document();
    let stale = TriFusionDocument::from_json_value(json!({
        "type": "doc",
        "content": [
            paragraph("b1", "Different base"),
        ],
    }))
    .unwrap();
    let before_canonical_json = base.canonical_json().to_string();
    let mut stale_envelope = envelope(
        &base,
        "env-stale",
        TriFusionMutationActor::System,
        TriFusionSourceFormat::Json,
        TriFusionMutation::InsertBlock {
            artifact_id: "artifact-1".to_string(),
            after_block_id: Some("b1".to_string()),
            block: paragraph("b3", "Three"),
        },
    );
    stale_envelope.base_document_hash = stale.hash();

    let error = base.apply_mutation_envelope(stale_envelope).unwrap_err();

    assert_eq!(
        error,
        TriFusionError::BaseDocumentHashMismatch {
            expected: base.hash(),
            actual: stale.hash(),
        }
    );
    assert_eq!(base.canonical_json(), before_canonical_json);
}

#[test]
fn agent_actor_requires_run_id_when_deserializing_envelope() {
    let base = document();
    let payload = json!({
        "mutation_id": "env-missing-run",
        "document_id": "doc-1",
        "base_document_hash": base.hash().to_hex(),
        "actor": {
            "kind": "agent"
        },
        "source_format": "json",
        "rationale": "missing run id",
        "kind": "insert_block",
        "artifact_id": "artifact-1",
        "after_block_id": "b1",
        "block": paragraph("b3", "Three"),
    });

    assert!(serde_json::from_value::<TriFusionMutationEnvelope>(payload).is_err());
}

#[test]
fn agent_actor_rejects_empty_run_id_when_deserializing_envelope() {
    let base = document();
    let payload = json!({
        "mutation_id": "env-empty-run",
        "document_id": "doc-1",
        "base_document_hash": base.hash().to_hex(),
        "actor": {
            "kind": "agent",
            "run_id": "",
        },
        "source_format": "json",
        "rationale": "empty run id",
        "kind": "insert_block",
        "artifact_id": "artifact-1",
        "after_block_id": "b1",
        "block": paragraph("b3", "Three"),
    });

    assert!(serde_json::from_value::<TriFusionMutationEnvelope>(payload).is_err());
}

#[test]
fn user_and_system_actors_reject_run_id_when_deserializing_envelope() {
    for actor_kind in ["user", "system"] {
        let base = document();
        let payload = json!({
            "mutation_id": format!("env-extra-run-{actor_kind}"),
            "document_id": "doc-1",
            "base_document_hash": base.hash().to_hex(),
            "actor": {
                "kind": actor_kind,
                "run_id": "not-allowed",
            },
            "source_format": "json",
            "rationale": "extra run id",
            "kind": "insert_block",
            "artifact_id": "artifact-1",
            "after_block_id": "b1",
            "block": paragraph("b3", "Three"),
        });

        assert!(
            serde_json::from_value::<TriFusionMutationEnvelope>(payload).is_err(),
            "{actor_kind} actor should not accept run_id"
        );
    }
}
