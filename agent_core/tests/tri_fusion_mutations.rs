use agent_core::mutations::BlockRef;
use agent_core::tri_fusion::{
    TriFusionDocument, TriFusionError, TriFusionMutation, TRI_FUSION_JSON_CANONICAL_VERSION,
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

#[test]
fn insert_block_changes_hash_and_touches_inserted_block() {
    let document = document();
    let before_hash = document.hash();

    let result = document
        .apply_mutation(TriFusionMutation::InsertBlock {
            artifact_id: "artifact-1".to_string(),
            after_block_id: Some("b1".to_string()),
            block: paragraph("b3", "Three"),
        })
        .unwrap();

    assert_ne!(result.document.hash(), before_hash);
    assert_eq!(result.witness.before_hash, before_hash);
    assert_eq!(result.witness.after_hash, result.document.hash());
    assert_eq!(result.witness.mutation_kind, "insert_block");
    assert_eq!(
        result.witness.touched_blocks,
        vec![BlockRef::new("artifact-1", "b3")]
    );
    assert_eq!(
        result.witness.canonical_version,
        TRI_FUSION_JSON_CANONICAL_VERSION
    );
    assert_eq!(result.document.root()["content"][1]["attrs"]["id"], "b3");
}

#[test]
fn mutate_block_replaces_existing_block() {
    let result = document()
        .apply_mutation(TriFusionMutation::MutateBlock {
            artifact_id: "artifact-1".to_string(),
            block_id: "b2".to_string(),
            replacement: paragraph("b2", "Second draft"),
        })
        .unwrap();

    assert!(result.document.canonical_json().contains("Second draft"));
    assert!(!result.document.canonical_json().contains("\"Two\""));
    assert_eq!(
        result.witness.touched_blocks,
        vec![BlockRef::new("artifact-1", "b2")]
    );
}

#[test]
fn link_block_records_relation_without_duplicate() {
    let mutation = TriFusionMutation::LinkBlock {
        artifact_id: "artifact-1".to_string(),
        from_block_id: "b1".to_string(),
        to_block_id: "b2".to_string(),
        relation: "supports".to_string(),
    };

    let first = document().apply_mutation(mutation.clone()).unwrap();
    let second = first.document.apply_mutation(mutation).unwrap();
    let links = second.document.root()["content"][0]["attrs"]["links"]
        .as_array()
        .unwrap();

    assert_eq!(links.len(), 1);
    assert_eq!(links[0]["relation"], "supports");
    assert_eq!(links[0]["target_block_id"], "b2");
    assert_eq!(
        second.witness.touched_blocks,
        vec![
            BlockRef::new("artifact-1", "b1"),
            BlockRef::new("artifact-1", "b2"),
        ]
    );
}

#[test]
fn transclude_block_inserts_transclusion_node() {
    let result = document()
        .apply_mutation(TriFusionMutation::TranscludeBlock {
            artifact_id: "artifact-1".to_string(),
            after_block_id: Some("b2".to_string()),
            source_block_id: "b1".to_string(),
            transclusion_block_id: "t1".to_string(),
        })
        .unwrap();

    let content = result.document.root()["content"].as_array().unwrap();
    assert_eq!(content[2]["type"], "transclusion");
    assert_eq!(content[2]["attrs"]["id"], "t1");
    assert_eq!(content[2]["attrs"]["source_block_id"], "b1");
}

#[test]
fn missing_block_rejected_preserves_original_document() {
    let document = document();
    let before_hash = document.hash();

    let error = document
        .apply_mutation(TriFusionMutation::InsertBlock {
            artifact_id: "artifact-1".to_string(),
            after_block_id: Some("missing".to_string()),
            block: paragraph("b3", "Three"),
        })
        .unwrap_err();

    assert_eq!(
        error,
        TriFusionError::BlockNotFound {
            block_id: "missing".to_string(),
        }
    );
    assert_eq!(document.hash(), before_hash);
    assert_eq!(document.root()["content"].as_array().unwrap().len(), 2);
}
