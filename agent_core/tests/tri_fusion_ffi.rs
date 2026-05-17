use agent_core::bridge::{provenance_ledger_snapshot_json, tri_fusion_document_from_json};
use serde_json::{Value, json};

#[test]
fn ffi_apply_mutation_with_provenance_commits_claim_and_dag() {
    let canonical = r#"{"content":[{"attrs":{"id":"b1"},"content":[{"text":"Hello","type":"text"}],"type":"paragraph"}],"type":"doc"}"#;
    let handle = tri_fusion_document_from_json(canonical.to_string()).expect("tri-fusion handle");
    let mutation = format!(
        r#"{{"mutation_id":"tfm-ffi-commit-44","document_id":"doc-ffi-44","base_document_hash":"{}","actor":{{"kind":"agent","run_id":"run-ffi-44"}},"source_format":"json","kind":"insert_block","artifact_id":"doc-ffi-44","rationale":"Commit FFI provenance.","after_block_id":"b1","block":{{"attrs":{{"id":"b44"}},"content":[{{"text":"Committed provenance","type":"text"}}],"type":"paragraph"}}}}"#,
        handle.hash_hex()
    );

    let output = handle
        .apply_mutation_with_provenance_json(mutation, 1_779_019_208_000)
        .expect("mutation applies and commits provenance");
    let value: Value = serde_json::from_str(&output).expect("response json");

    assert_eq!(value["accepted"], json!(true));
    assert!(
        value["canonical_json"]
            .as_str()
            .expect("canonical_json")
            .contains(r#""id":"b44""#)
    );
    assert_eq!(value["witness"]["provenance_status"], json!("committed"));
    assert_eq!(
        value["witness"]["mutation_envelope_id"],
        json!("tfm-ffi-commit-44")
    );
    assert_eq!(
        value["witness"]["claim_graph_node_id"]
            .as_str()
            .unwrap()
            .len(),
        64
    );
    assert_eq!(
        value["witness"]["cognitive_dag_edge_id"]
            .as_str()
            .unwrap()
            .len(),
        64
    );
    assert_eq!(value["provenance"]["status"], json!("complete"));
    assert_eq!(value["provenance"]["claim_node_present"], json!(true));
    assert_eq!(value["provenance"]["evidence_node_present"], json!(true));
    assert_eq!(
        value["provenance"]["derives_from_evidence_edge_present"],
        json!(true)
    );

    let witness_mutation_id = value["witness"]["mutation_id"]
        .as_str()
        .expect("witness mutation id");
    let claim_id = format!("tri_fusion:claim:{witness_mutation_id}");
    let evidence_id = format!("tri_fusion:evidence:{witness_mutation_id}");
    let snapshot: Value = serde_json::from_str(
        &provenance_ledger_snapshot_json().expect("global provenance snapshot"),
    )
    .expect("snapshot json");
    let claims = snapshot["claims"].as_array().expect("claims array");
    let evidence = snapshot["evidence"].as_array().expect("evidence array");

    assert!(claims
        .iter()
        .any(|claim| claim["id"] == json!(claim_id) && claim["kind"] == json!("code_invariant")));
    assert!(evidence.iter().any(|entry| {
        entry["id"] == json!(evidence_id)
            && entry["source"]
                .as_str()
                .unwrap_or("")
                .starts_with("tri_fusion_witness:")
    }));
}
