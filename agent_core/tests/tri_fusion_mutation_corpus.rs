use agent_core::mutations::BlockRef;
use agent_core::tri_fusion::{
    TriFusionDocument, TriFusionMutation, TriFusionMutationActor, TriFusionMutationEnvelope,
    TriFusionSourceFormat, TriFusionWitness, TRI_FUSION_JSON_CANONICAL_VERSION,
};
use serde_json::{json, Value};

const MUTATION_CORPUS_CASE_COUNT: usize = 20;

struct MutationFixture {
    base: TriFusionDocument,
    envelope: TriFusionMutationEnvelope,
    expected_kind: &'static str,
    expected_touched_blocks: Vec<BlockRef>,
}

fn paragraph(block_id: impl Into<String>, text: impl Into<String>) -> Value {
    json!({
        "attrs": {
            "id": block_id.into(),
        },
        "content": [
            {
                "text": text.into(),
                "type": "text",
            },
        ],
        "type": "paragraph",
    })
}

fn base_document(seed: usize) -> TriFusionDocument {
    TriFusionDocument::from_json_value(json!({
        "content": [
            paragraph("b1", format!("Base one {seed}")),
            paragraph("b2", format!("Base two {seed}")),
            paragraph("b3", format!("Base three {seed}")),
        ],
        "type": "doc",
    }))
    .unwrap()
}

fn actor(seed: usize) -> TriFusionMutationActor {
    match seed % 3 {
        0 => TriFusionMutationActor::User,
        1 => TriFusionMutationActor::Agent {
            run_id: format!("run-mutation-corpus-{seed:03}"),
        },
        _ => TriFusionMutationActor::System,
    }
}

fn source_format(seed: usize) -> TriFusionSourceFormat {
    match seed % 3 {
        0 => TriFusionSourceFormat::Json,
        1 => TriFusionSourceFormat::Markdown,
        _ => TriFusionSourceFormat::Html,
    }
}

fn mutation_fixture(seed: usize) -> MutationFixture {
    let base = base_document(seed);
    let artifact_id = format!("artifact-mutation-{seed:03}");
    let (mutation, expected_kind, expected_touched_blocks) = match seed % 4 {
        0 => {
            let block_id = format!("inserted-{seed:03}");
            (
                TriFusionMutation::InsertBlock {
                    artifact_id: artifact_id.clone(),
                    after_block_id: Some("b1".to_string()),
                    block: paragraph(&block_id, format!("Inserted block {seed}")),
                },
                "insert_block",
                vec![BlockRef::new(artifact_id.clone(), block_id)],
            )
        }
        1 => (
            TriFusionMutation::MutateBlock {
                artifact_id: artifact_id.clone(),
                block_id: "b2".to_string(),
                replacement: paragraph("b2", format!("Mutated block {seed}")),
            },
            "mutate_block",
            vec![BlockRef::new(artifact_id.clone(), "b2")],
        ),
        2 => (
            TriFusionMutation::LinkBlock {
                artifact_id: artifact_id.clone(),
                from_block_id: "b1".to_string(),
                to_block_id: "b3".to_string(),
                relation: format!("relates_to_{seed:03}"),
            },
            "link_block",
            vec![
                BlockRef::new(artifact_id.clone(), "b1"),
                BlockRef::new(artifact_id.clone(), "b3"),
            ],
        ),
        _ => {
            let transclusion_block_id = format!("transclusion-{seed:03}");
            (
                TriFusionMutation::TranscludeBlock {
                    artifact_id: artifact_id.clone(),
                    after_block_id: Some("b3".to_string()),
                    source_block_id: "b1".to_string(),
                    transclusion_block_id: transclusion_block_id.clone(),
                },
                "transclude_block",
                vec![
                    BlockRef::new(artifact_id.clone(), "b1"),
                    BlockRef::new(artifact_id.clone(), transclusion_block_id),
                ],
            )
        }
    };

    let envelope = TriFusionMutationEnvelope {
        mutation_id: format!("mutation-corpus-{seed:03}"),
        document_id: format!("doc-mutation-corpus-{seed:03}"),
        base_document_hash: base.hash(),
        actor: actor(seed),
        source_format: source_format(seed),
        rationale: format!("Mutation corpus fixture {seed}"),
        mutation,
    };

    MutationFixture {
        base,
        envelope,
        expected_kind,
        expected_touched_blocks,
    }
}

fn assert_mutation_fixture(seed: usize) {
    let MutationFixture {
        base,
        envelope,
        expected_kind,
        expected_touched_blocks,
    } = mutation_fixture(seed);
    let before_hash = base.hash();
    let before_json = base.canonical_json().to_string();
    let expected_mutation_id = envelope.mutation_id.clone();
    let expected_document_id = envelope.document_id.clone();
    let expected_actor = envelope.actor.clone();
    let expected_source_format = envelope.source_format.clone();
    let expected_rationale = envelope.rationale.clone();

    let result = base.apply_mutation_envelope(envelope).unwrap();

    assert_ne!(result.document.canonical_json(), before_json);
    assert_ne!(result.document.hash(), before_hash);
    assert_eq!(result.witness.before_hash, before_hash);
    assert_eq!(result.witness.after_hash, result.document.hash());
    assert_eq!(result.witness.mutation_kind, expected_kind);
    assert_eq!(result.witness.touched_blocks, expected_touched_blocks);
    assert_eq!(
        result.witness.canonical_version,
        TRI_FUSION_JSON_CANONICAL_VERSION
    );
    assert_eq!(
        result.witness.envelope_mutation_id.as_deref(),
        Some(expected_mutation_id.as_str())
    );
    assert_eq!(
        result.witness.document_id.as_deref(),
        Some(expected_document_id.as_str())
    );
    assert_eq!(result.witness.actor.as_ref(), Some(&expected_actor));
    assert_eq!(
        result.witness.source_format.as_ref(),
        Some(&expected_source_format)
    );
    assert_eq!(
        result.witness.rationale.as_deref(),
        Some(expected_rationale.as_str())
    );

    let after_reparsed = TriFusionDocument::parse_json(result.document.canonical_json()).unwrap();
    assert_eq!(
        after_reparsed.canonical_json(),
        result.document.canonical_json()
    );
    assert_eq!(after_reparsed.hash(), result.document.hash());

    let witness_json = serde_json::to_string(&result.witness).unwrap();
    let reparsed_witness: TriFusionWitness = serde_json::from_str(&witness_json).unwrap();
    assert_eq!(
        serde_json::to_string(&reparsed_witness).unwrap(),
        witness_json
    );
}

macro_rules! mutation_corpus_case {
    ($name:ident, $seed:expr) => {
        #[test]
        fn $name() {
            assert_mutation_fixture($seed);
        }
    };
}

#[test]
fn mutation_corpus_case_count_is_reported() {
    assert_eq!(MUTATION_CORPUS_CASE_COUNT, 20);
}

mutation_corpus_case!(mutation_corpus_001, 1);
mutation_corpus_case!(mutation_corpus_002, 2);
mutation_corpus_case!(mutation_corpus_003, 3);
mutation_corpus_case!(mutation_corpus_004, 4);
mutation_corpus_case!(mutation_corpus_005, 5);
mutation_corpus_case!(mutation_corpus_006, 6);
mutation_corpus_case!(mutation_corpus_007, 7);
mutation_corpus_case!(mutation_corpus_008, 8);
mutation_corpus_case!(mutation_corpus_009, 9);
mutation_corpus_case!(mutation_corpus_010, 10);
mutation_corpus_case!(mutation_corpus_011, 11);
mutation_corpus_case!(mutation_corpus_012, 12);
mutation_corpus_case!(mutation_corpus_013, 13);
mutation_corpus_case!(mutation_corpus_014, 14);
mutation_corpus_case!(mutation_corpus_015, 15);
mutation_corpus_case!(mutation_corpus_016, 16);
mutation_corpus_case!(mutation_corpus_017, 17);
mutation_corpus_case!(mutation_corpus_018, 18);
mutation_corpus_case!(mutation_corpus_019, 19);
mutation_corpus_case!(mutation_corpus_020, 20);
