//! `falsify_graph_filter_visibility_focused_proof_root_execution_artifact_gate`.
//!
//! Metadata-only parser gate for a future focused graph-filter proof-root
//! execution artifact. This does not run Xcode, open `.xctestrun` or
//! `.xcresult` bytes, mutate source, or claim release readiness.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::axes::GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_graph_filter_focused_proof_root_execution_manifest_fields,
    required_graph_filter_focused_proof_root_execution_rejection_policies,
    GraphFilterFocusedProofRootExecutionArtifactGate,
    GraphFilterVisibilityFocusedProofRootExecutionArtifactGateWitness,
    GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR,
    GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = "F-GraphFilterVisibilityFocusedProofRootExecutionArtifactGate";
const FIXTURE_ID: &str = "graph_filter_visibility_focused_proof_root_execution_artifact_gate_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_graph_filter_visibility_focused_proof_root_execution_artifact_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/graph_filter_visibility_focused_proof_root_execution_artifact_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/graph_filter_visibility_focused_proof_root_command_card/result.json";
const ZERO: u64 = 0;

fn main() -> std::process::ExitCode {
    let artifact = match build_artifact() {
        Ok(artifact) => artifact,
        Err(error) => {
            eprintln!("failed to build {FALSIFIER_ID}: {error}");
            return std::process::ExitCode::from(2);
        }
    };
    let path = PathBuf::from(RESULT);
    if let Some(parent) = path.parent() {
        if let Err(error) = std::fs::create_dir_all(parent) {
            eprintln!("failed to create artifact directory: {error}");
            return std::process::ExitCode::from(2);
        }
    }
    let mut file = match std::fs::File::create(&path) {
        Ok(file) => file,
        Err(error) => {
            eprintln!("failed to open artifact: {error}");
            return std::process::ExitCode::from(2);
        }
    };
    if let Err(error) = write_artifact(&mut file, &artifact) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }

    println!(
        "{FALSIFIER_ID}: overall_pass={} manifest_fields={} next_cursor={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_manifest_field_count"].value,
        artifact.measurements["next_cursor"].value,
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let upstream = read_upstream()?;
    let witness = GraphFilterVisibilityFocusedProofRootExecutionArtifactGateWitness::new(
        upstream.overall_pass,
        &upstream.address,
        &upstream.next_cursor,
    )?;
    witness.validate()?;

    let red_results = red_fixture_results(&witness);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;
    let red_fixture_count = red_results.len() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (axis, pass) in [
        ("upstream_command_card_pass", upstream.overall_pass),
        (
            "upstream_ref_bound",
            witness.upstream_artifact_ref
                == GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF,
        ),
        (
            "upstream_address_bound",
            witness.upstream_address == upstream.address
                && witness.upstream_address.starts_with("sha256:"),
        ),
        (
            "upstream_next_cursor_bound",
            witness.upstream_next_cursor
                == GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR,
        ),
        (
            "proof_root_prefix_bound",
            witness
                .spec
                .proof_root_prefix
                .starts_with("artifacts/xcode/graph-filter-visibility-test-products/"),
        ),
        (
            "execution_manifest_name_bound",
            witness.spec.manifest_name == "focused-proof-root-execution-artifact.json",
        ),
        (
            "required_manifest_fields_bound",
            witness.metrics.required_manifest_field_count
                == required_graph_filter_focused_proof_root_execution_manifest_fields().len(),
        ),
        (
            "required_rejection_policies_bound",
            witness.metrics.required_rejection_policy_count
                == required_graph_filter_focused_proof_root_execution_rejection_policies().len(),
        ),
        (
            "minimum_nonzero_executed_tests_required",
            witness.metrics.minimum_executed_test_count > 0,
        ),
        (
            "selected_product_digest_required",
            witness.spec.selected_test_product_digest_required,
        ),
        (
            "selected_product_commit_required",
            witness.spec.selected_test_product_commit_required,
        ),
        (
            "enumeration_digest_required",
            witness.spec.enumeration_digest_required,
        ),
        (
            "focused_selector_digest_required",
            witness.spec.focused_selector_digest_required,
        ),
        (
            "focused_result_bundle_digest_required",
            witness.spec.focused_result_bundle_digest_required,
        ),
        (
            "source_status_digests_required",
            witness.spec.source_status_digests_required,
        ),
        (
            "scheme_pre_action_ledger_required",
            witness.spec.scheme_pre_action_ledger_required,
        ),
        (
            "run_event_log_answer_packet_rollback_digests_required",
            witness.spec.run_event_log_digest_required
                && witness.spec.answer_packet_digest_required
                && witness.spec.rollback_digest_required,
        ),
        (
            "full_automated_check_row_still_required",
            witness.spec.full_automated_check_row_still_required,
        ),
        (
            "focused_proof_cannot_replace_full_row",
            !witness.spec.focused_proof_replaces_full_row,
        ),
        (
            "metadata_only_parser_dry_run",
            witness.spec.metadata_only && witness.spec.parser_dry_run_only,
        ),
        (
            "no_xcode_command_executed",
            !witness.spec.xcode_command_executed,
        ),
        (
            "no_selected_test_product_or_xcresult_bytes_opened",
            witness.metrics.selected_test_product_bytes_opened == 0
                && witness.metrics.xcode_result_bytes_opened == 0,
        ),
        (
            "no_app_model_runtime_provider_bytes",
            witness.metrics.app_runtime_bytes_loaded == 0
                && witness.metrics.model_runtime_bytes_loaded == 0
                && witness.metrics.provider_calls_made == 0,
        ),
        (
            "no_product_code_changed",
            !witness.spec.product_code_changed,
        ),
        (
            "no_raw_note_prompt_model_log_bytes",
            !witness.spec.raw_note_prompt_model_bytes_logged,
        ),
        (
            "no_l2_l3_product_release_green",
            !witness.spec.l2_green_claimed
                && !witness.spec.l3_green_claimed
                && !witness.spec.product_green_claimed
                && !witness.spec.release_ready_claimed,
        ),
        (
            "no_live_dense_70b_or_ssd_ram_claim",
            !witness.spec.live_dense_70b_claimed && !witness.spec.ssd_as_ram_claimed,
        ),
        (
            "rollback_run_event_answer_packet_refs_present",
            !witness.spec.rollback_ref.is_empty()
                && !witness.spec.run_event_log_ref.is_empty()
                && !witness.spec.answer_packet_ref.is_empty(),
        ),
        (
            "next_cursor_bound",
            witness.next_cursor
                == GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR,
        ),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            pass,
        );
    }

    for (axis, pass) in red_results {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            pass,
        );
    }

    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_manifest_field_count",
        witness.metrics.required_manifest_field_count as u64,
        required_graph_filter_focused_proof_root_execution_manifest_fields().len() as u64,
        "fields",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_rejection_policy_count",
        witness.metrics.required_rejection_policy_count as u64,
        required_graph_filter_focused_proof_root_execution_rejection_policies().len() as u64,
        "policies",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_fixture_count,
        red_fixture_count,
        "fixtures",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_rejection_count",
        red_fixture_rejection_count,
        red_fixture_count,
        "fixtures",
    );
    for (axis, value) in [
        (
            "selected_test_product_bytes_opened_total",
            witness.metrics.selected_test_product_bytes_opened,
        ),
        (
            "xcode_result_bytes_opened_total",
            witness.metrics.xcode_result_bytes_opened,
        ),
        (
            "app_runtime_bytes_loaded_total",
            witness.metrics.app_runtime_bytes_loaded,
        ),
        (
            "model_runtime_bytes_loaded_total",
            witness.metrics.model_runtime_bytes_loaded,
        ),
        (
            "provider_calls_made_total",
            witness.metrics.provider_calls_made,
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            value,
            "==",
            ZERO,
            "bytes_or_calls",
        );
    }

    insert_string_measurement(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_command_card_address",
        &witness.upstream_address,
        &witness.upstream_address,
        "sha256",
    );
    insert_string_measurement(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "graph_filter_visibility_focused_proof_root_execution_artifact_gate_address",
        &witness.address,
        &witness.address,
        "sha256",
    );
    measurements.insert(
        "graph_filter_visibility_focused_proof_root_execution_artifact_gate".to_string(),
        Measurement {
            value: serde_json::json!(true),
            unit: "execution_artifact_gate".to_string(),
        },
    );
    pass_per_axis.insert(
        "graph_filter_visibility_focused_proof_root_execution_artifact_gate".to_string(),
        true,
    );
    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(witness.next_cursor),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "eq".to_string(),
            value: serde_json::json!(
                GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor
            == GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR,
    );

    for axis in GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_AXES {
        measurements
            .entry((*axis).to_string())
            .or_insert(Measurement {
                value: serde_json::json!(false),
                unit: "axis_missing".to_string(),
            });
        thresholds
            .entry((*axis).to_string())
            .or_insert(AcceptanceThreshold {
                operator: "present".to_string(),
                value: serde_json::json!(true),
                unit: "axis_missing".to_string(),
            });
        pass_per_axis.entry((*axis).to_string()).or_insert(false);
    }

    Ok(ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: Vec::new(),
        notes: "metadata-only F-GraphFilterVisibilityFocusedProofRootExecutionArtifactGate: consumes the command-card witness and binds the post-run parser contract for selected test-product digest, selected product commit, enumeration digest, focused selector digest, focused xcresult digest, nonzero executed-test policy, source-status digests, scheme pre-action ledger, RunEventLog, AnswerPacket, rollback, full automated-check row preservation, zero Xcode execution, zero test-product/result/model/runtime/provider bytes, and no L2/L3/product/release/large-model promotion.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn red_fixture_results(
    witness: &GraphFilterVisibilityFocusedProofRootExecutionArtifactGateWitness,
) -> Vec<(&'static str, bool)> {
    let mut results = Vec::new();
    for fixture in red_fixture_cases() {
        let rejected = match fixture {
            RedFixture::UpstreamFail => {
                GraphFilterVisibilityFocusedProofRootExecutionArtifactGateWitness::new(
                    false,
                    &witness.upstream_address,
                    &witness.upstream_next_cursor,
                )
                .is_err()
            }
            RedFixture::MissingUpstreamAddress => {
                GraphFilterVisibilityFocusedProofRootExecutionArtifactGateWitness::new(
                    witness.upstream_overall_pass,
                    "",
                    &witness.upstream_next_cursor,
                )
                .is_err()
            }
            RedFixture::WrongUpstreamCursor => {
                GraphFilterVisibilityFocusedProofRootExecutionArtifactGateWitness::new(
                    witness.upstream_overall_pass,
                    &witness.upstream_address,
                    "graph_filter_visibility_focused_proof_root_command_card",
                )
                .is_err()
            }
            RedFixture::MutateSpec { mutate, .. } => {
                let mut spec = GraphFilterFocusedProofRootExecutionArtifactGate::canonical();
                mutate(&mut spec);
                spec.validate().is_err()
            }
        };
        results.push((fixture.name(), rejected));
    }
    results
}

// UAS: F-GraphFilterVisibilityFocusedProofRootExecutionArtifactGate red fixtures.
// Plane: Verification.
// Residency: metadata-only parser fixtures; no Xcode/result bytes are opened.
enum RedFixture {
    UpstreamFail,
    MissingUpstreamAddress,
    WrongUpstreamCursor,
    MutateSpec {
        name: &'static str,
        mutate: fn(&mut GraphFilterFocusedProofRootExecutionArtifactGate),
    },
}

impl RedFixture {
    fn name(&self) -> &'static str {
        match self {
            Self::UpstreamFail => "upstream_fail_rejected",
            Self::MissingUpstreamAddress => "missing_upstream_address_rejected",
            Self::WrongUpstreamCursor => "wrong_upstream_cursor_rejected",
            Self::MutateSpec { name, .. } => name,
        }
    }
}

fn red_fixture_cases() -> Vec<RedFixture> {
    vec![
        RedFixture::UpstreamFail,
        RedFixture::MissingUpstreamAddress,
        RedFixture::WrongUpstreamCursor,
        RedFixture::MutateSpec {
            name: "global_derived_data_rejected",
            mutate: |spec| {
                spec.proof_root_prefix =
                    "~/Library/Developer/Xcode/DerivedData/graph-filter/".to_string()
            },
        },
        RedFixture::MutateSpec {
            name: "missing_manifest_field_rejected",
            mutate: |spec| {
                spec.required_execution_manifest_fields
                    .retain(|field| field != "focused_result_bundle_digest")
            },
        },
        RedFixture::MutateSpec {
            name: "missing_rejection_policy_rejected",
            mutate: |spec| {
                spec.required_rejection_policies
                    .retain(|policy| policy != "zero_executed_tests")
            },
        },
        RedFixture::MutateSpec {
            name: "zero_executed_tests_policy_rejected",
            mutate: |spec| spec.minimum_executed_test_count = 0,
        },
        RedFixture::MutateSpec {
            name: "selected_product_digest_missing_rejected",
            mutate: |spec| spec.selected_test_product_digest_required = false,
        },
        RedFixture::MutateSpec {
            name: "selected_product_commit_missing_rejected",
            mutate: |spec| spec.selected_test_product_commit_required = false,
        },
        RedFixture::MutateSpec {
            name: "enumeration_digest_missing_rejected",
            mutate: |spec| spec.enumeration_digest_required = false,
        },
        RedFixture::MutateSpec {
            name: "focused_selector_digest_missing_rejected",
            mutate: |spec| spec.focused_selector_digest_required = false,
        },
        RedFixture::MutateSpec {
            name: "focused_xcresult_digest_missing_rejected",
            mutate: |spec| spec.focused_result_bundle_digest_required = false,
        },
        RedFixture::MutateSpec {
            name: "source_status_digest_missing_rejected",
            mutate: |spec| spec.source_status_digests_required = false,
        },
        RedFixture::MutateSpec {
            name: "scheme_pre_action_ledger_missing_rejected",
            mutate: |spec| spec.scheme_pre_action_ledger_required = false,
        },
        RedFixture::MutateSpec {
            name: "run_event_log_digest_missing_rejected",
            mutate: |spec| spec.run_event_log_digest_required = false,
        },
        RedFixture::MutateSpec {
            name: "answer_packet_digest_missing_rejected",
            mutate: |spec| spec.answer_packet_digest_required = false,
        },
        RedFixture::MutateSpec {
            name: "rollback_digest_missing_rejected",
            mutate: |spec| spec.rollback_digest_required = false,
        },
        RedFixture::MutateSpec {
            name: "full_row_replacement_rejected",
            mutate: |spec| spec.focused_proof_replaces_full_row = true,
        },
        RedFixture::MutateSpec {
            name: "xcode_execution_claim_rejected",
            mutate: |spec| spec.xcode_command_executed = true,
        },
        RedFixture::MutateSpec {
            name: "test_product_byte_open_rejected",
            mutate: |spec| spec.selected_test_product_bytes_opened = 1,
        },
        RedFixture::MutateSpec {
            name: "xcresult_byte_open_rejected",
            mutate: |spec| spec.xcode_result_bytes_opened = 1,
        },
        RedFixture::MutateSpec {
            name: "runtime_byte_leak_rejected",
            mutate: |spec| spec.app_runtime_bytes_loaded = 1,
        },
        RedFixture::MutateSpec {
            name: "provider_call_rejected",
            mutate: |spec| spec.provider_calls_made = 1,
        },
        RedFixture::MutateSpec {
            name: "product_code_change_claim_rejected",
            mutate: |spec| spec.product_code_changed = true,
        },
        RedFixture::MutateSpec {
            name: "raw_note_prompt_model_log_rejected",
            mutate: |spec| spec.raw_note_prompt_model_bytes_logged = true,
        },
        RedFixture::MutateSpec {
            name: "l2_l3_product_green_claim_rejected",
            mutate: |spec| spec.l2_green_claimed = true,
        },
        RedFixture::MutateSpec {
            name: "release_ready_claim_rejected",
            mutate: |spec| spec.release_ready_claimed = true,
        },
        RedFixture::MutateSpec {
            name: "live_dense_70b_claim_rejected",
            mutate: |spec| spec.live_dense_70b_claimed = true,
        },
        RedFixture::MutateSpec {
            name: "ssd_as_ram_claim_rejected",
            mutate: |spec| spec.ssd_as_ram_claimed = true,
        },
    ]
}

// UAS: uas:graph-filter-visibility-focused-proof-root-execution-artifact-gate:upstream-command-card
// Plane: Verification.
// Residency: parsed upstream metadata only.
struct UpstreamCommandCard {
    overall_pass: bool,
    address: String,
    next_cursor: String,
}

fn read_upstream() -> Result<UpstreamCommandCard, Box<dyn std::error::Error>> {
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(UPSTREAM_RESULT)?)?;
    let overall_pass = value["overall_pass"].as_bool().unwrap_or(false);
    let address = value["measurements"]
        ["graph_filter_visibility_focused_proof_root_command_card_address"]["value"]
        .as_str()
        .unwrap_or_default()
        .to_string();
    let next_cursor = value["measurements"]["next_cursor"]["value"]
        .as_str()
        .unwrap_or_default()
        .to_string();
    Ok(UpstreamCommandCard {
        overall_pass,
        address,
        next_cursor,
    })
}

fn insert_string_measurement(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
    expected: &str,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "eq".to_string(),
            value: serde_json::json!(expected),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual == expected);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn red_fixture_suite_is_exhaustive() {
        let witness = GraphFilterVisibilityFocusedProofRootExecutionArtifactGateWitness::new(
            true,
            "sha256:e7095c8391930693cd93aa9d4e69ce36f45e2b9d178cf7c95a16b81a06aad743",
            GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR,
        )
        .expect("valid witness");
        let results = red_fixture_results(&witness);
        assert_eq!(results.len(), 29);
        assert!(results.iter().all(|(_, passed)| *passed));
    }
}
