//! `falsify_graph_filter_visibility_focused_proof_root_owner_approval_gate`.
//!
//! Metadata-only owner-approval gate for the focused graph-filter proof-root
//! execution. This proves the current state is approval-pending and fail-closed:
//! no Xcode command is armed or run, no selected test product or `.xcresult`
//! bytes are opened, and no release/product/large-model claim promotes.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_graph_filter_focused_proof_root_owner_approval_consent_clauses,
    required_graph_filter_focused_proof_root_owner_approval_preconditions,
    required_graph_filter_focused_proof_root_owner_approval_rejection_policies,
    GraphFilterFocusedProofRootOwnerApprovalGate,
    GraphFilterVisibilityFocusedProofRootOwnerApprovalGateWitness,
    GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_GATE_NEXT_CURSOR,
    GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_RUNBOOK_PATH,
};

const FALSIFIER_ID: &str = "F-GraphFilterVisibilityFocusedProofRootOwnerApprovalGate";
const FIXTURE_ID: &str = "graph_filter_visibility_focused_proof_root_owner_approval_gate_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_graph_filter_visibility_focused_proof_root_owner_approval_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/graph_filter_visibility_focused_proof_root_owner_approval_gate/result.json";
const COMMAND_CARD_RESULT: &str =
    "artifacts/falsifiers/graph_filter_visibility_focused_proof_root_command_card/result.json";
const EXECUTION_GATE_RESULT: &str =
    "artifacts/falsifiers/graph_filter_visibility_focused_proof_root_execution_artifact_gate/result.json";
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
        "{FALSIFIER_ID}: overall_pass={} preconditions={} consent_clauses={} next_cursor={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_precondition_count"].value,
        artifact.measurements["required_consent_clause_count"].value,
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
    let command_card = read_upstream(
        COMMAND_CARD_RESULT,
        "graph_filter_visibility_focused_proof_root_command_card_address",
    )?;
    let execution_gate = read_upstream(
        EXECUTION_GATE_RESULT,
        "graph_filter_visibility_focused_proof_root_execution_artifact_gate_address",
    )?;
    let runbook_present =
        Path::new(GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_RUNBOOK_PATH).exists();
    let witness = GraphFilterVisibilityFocusedProofRootOwnerApprovalGateWitness::new(
        command_card.overall_pass,
        &command_card.address,
        execution_gate.overall_pass,
        &execution_gate.address,
        runbook_present,
    )?;
    witness.validate()?;

    let red_results = red_fixture_results(&witness);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;
    let red_fixture_count = red_results.len() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (axis, pass) in [
        ("command_card_pass", command_card.overall_pass),
        (
            "command_card_address_bound",
            witness.command_card_address == command_card.address
                && witness.command_card_address.starts_with("sha256:"),
        ),
        ("execution_artifact_gate_pass", execution_gate.overall_pass),
        (
            "execution_artifact_gate_address_bound",
            witness.execution_artifact_gate_address == execution_gate.address
                && witness
                    .execution_artifact_gate_address
                    .starts_with("sha256:"),
        ),
        ("runbook_present", witness.runbook_present),
        (
            "runbook_path_bound",
            witness.runbook_path
                == GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_RUNBOOK_PATH,
        ),
        (
            "owner_approval_required",
            witness.spec.owner_approval_required,
        ),
        (
            "owner_approval_pending_fail_closed",
            !witness.spec.owner_approval_present
                && red_pass(&red_results, "owner_approval_present_rejected"),
        ),
        (
            "approval_phrase_scope_bound",
            witness
                .spec
                .approval_phrase
                .contains("focused graph-filter proof-root Xcode run")
                && witness.spec.approval_phrase.contains("command card")
                && witness
                    .spec
                    .approval_phrase
                    .contains("execution-artifact parser gate")
                && witness
                    .spec
                    .approval_phrase
                    .contains("Do not run the full release audit")
                && red_pass(&red_results, "approval_phrase_too_broad_rejected"),
        ),
        (
            "required_preconditions_bound",
            witness.metrics.required_precondition_count
                == required_graph_filter_focused_proof_root_owner_approval_preconditions().len(),
        ),
        (
            "required_consent_clauses_bound",
            witness.metrics.required_consent_clause_count
                == required_graph_filter_focused_proof_root_owner_approval_consent_clauses().len(),
        ),
        (
            "required_rejection_policies_bound",
            witness.metrics.required_rejection_policy_count
                == required_graph_filter_focused_proof_root_owner_approval_rejection_policies()
                    .len(),
        ),
        (
            "command_card_and_execution_gate_required",
            witness.spec.command_card_required && witness.spec.execution_artifact_gate_required,
        ),
        (
            "full_release_audit_separate_approval",
            !witness.spec.full_release_audit_requested
                && red_pass(&red_results, "full_release_audit_requested_rejected"),
        ),
        (
            "full_automated_check_row_preserved",
            !witness.spec.full_automated_check_row_replaced
                && red_pass(&red_results, "full_row_replacement_rejected"),
        ),
        (
            "command_envelope_unarmed",
            !witness.spec.command_envelope_armed
                && red_pass(&red_results, "command_envelope_armed_rejected"),
        ),
        (
            "no_xcode_command_executed",
            !witness.spec.xcode_command_executed
                && witness.metrics.command_execution_count == 0
                && red_pass(&red_results, "xcode_command_executed_rejected"),
        ),
        (
            "no_selected_test_product_or_xcresult_bytes_opened",
            witness.metrics.selected_test_product_bytes_opened == 0
                && witness.metrics.xcode_result_bytes_opened == 0
                && red_pass(&red_results, "selected_test_product_bytes_rejected")
                && red_pass(&red_results, "xcode_result_bytes_rejected"),
        ),
        (
            "no_model_runtime_provider_bytes",
            witness.metrics.model_runtime_bytes_loaded == 0
                && witness.metrics.provider_calls_made == 0
                && red_pass(&red_results, "model_runtime_bytes_rejected")
                && red_pass(&red_results, "provider_call_rejected"),
        ),
        (
            "no_product_code_changed",
            !witness.spec.product_code_changed
                && red_pass(&red_results, "product_code_changed_rejected"),
        ),
        (
            "no_l2_l3_product_release_green",
            !witness.spec.l2_green_claimed
                && !witness.spec.l3_green_claimed
                && !witness.spec.product_green_claimed
                && !witness.spec.release_ready_claimed
                && red_pass(&red_results, "l2_green_claim_rejected")
                && red_pass(&red_results, "l3_green_claim_rejected")
                && red_pass(&red_results, "product_green_claim_rejected")
                && red_pass(&red_results, "release_ready_claim_rejected"),
        ),
        (
            "no_live_dense_70b_or_ssd_ram_claim",
            !witness.spec.live_dense_70b_claimed
                && !witness.spec.ssd_as_ram_claimed
                && red_pass(&red_results, "live_dense_70b_claim_rejected")
                && red_pass(&red_results, "ssd_as_ram_claim_rejected"),
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
                == GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_GATE_NEXT_CURSOR,
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
        "required_precondition_count",
        witness.metrics.required_precondition_count as u64,
        required_graph_filter_focused_proof_root_owner_approval_preconditions().len() as u64,
        "preconditions",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_consent_clause_count",
        witness.metrics.required_consent_clause_count as u64,
        required_graph_filter_focused_proof_root_owner_approval_consent_clauses().len() as u64,
        "clauses",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_rejection_policy_count",
        witness.metrics.required_rejection_policy_count as u64,
        required_graph_filter_focused_proof_root_owner_approval_rejection_policies().len() as u64,
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
            "command_execution_count_total",
            witness.metrics.command_execution_count,
        ),
        (
            "selected_test_product_bytes_opened_total",
            witness.metrics.selected_test_product_bytes_opened,
        ),
        (
            "xcode_result_bytes_opened_total",
            witness.metrics.xcode_result_bytes_opened,
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
        "command_card_address",
        &witness.command_card_address,
        &witness.command_card_address,
        "sha256",
    );
    insert_string_measurement(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "execution_artifact_gate_address",
        &witness.execution_artifact_gate_address,
        &witness.execution_artifact_gate_address,
        "sha256",
    );
    insert_string_measurement(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "graph_filter_visibility_focused_proof_root_owner_approval_gate_address",
        &witness.address,
        &witness.address,
        "sha256",
    );
    measurements.insert(
        "graph_filter_visibility_focused_proof_root_owner_approval_gate".to_string(),
        Measurement {
            value: serde_json::json!(true),
            unit: "owner_approval_gate".to_string(),
        },
    );
    pass_per_axis.insert(
        "graph_filter_visibility_focused_proof_root_owner_approval_gate".to_string(),
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
                GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_GATE_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        witness.next_cursor
            == GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_GATE_NEXT_CURSOR,
    );

    for axis in GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_GATE_AXES {
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
        notes: "metadata-only F-GraphFilterVisibilityFocusedProofRootOwnerApprovalGate: consumes the command-card and execution-artifact parser witnesses plus the owner-approval runbook, proving focused proof-root Xcode execution is still approval-pending, command envelopes remain unarmed, no selected test-product or xcresult bytes are opened, no model/runtime/provider bytes are loaded, and no L2/L3/product/release/large-model claim promotes.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn red_fixture_results(
    witness: &GraphFilterVisibilityFocusedProofRootOwnerApprovalGateWitness,
) -> Vec<(&'static str, bool)> {
    let mut results = Vec::new();
    for fixture in red_fixture_cases() {
        let rejected = match fixture {
            RedFixture::CommandCardFail => {
                GraphFilterVisibilityFocusedProofRootOwnerApprovalGateWitness::new(
                    false,
                    &witness.command_card_address,
                    true,
                    &witness.execution_artifact_gate_address,
                    true,
                )
                .is_err()
            }
            RedFixture::ExecutionArtifactGateFail => {
                GraphFilterVisibilityFocusedProofRootOwnerApprovalGateWitness::new(
                    true,
                    &witness.command_card_address,
                    false,
                    &witness.execution_artifact_gate_address,
                    true,
                )
                .is_err()
            }
            RedFixture::RunbookMissing => {
                GraphFilterVisibilityFocusedProofRootOwnerApprovalGateWitness::new(
                    true,
                    &witness.command_card_address,
                    true,
                    &witness.execution_artifact_gate_address,
                    false,
                )
                .is_err()
            }
            RedFixture::MutateSpec { mutate, .. } => {
                let mut spec = GraphFilterFocusedProofRootOwnerApprovalGate::canonical();
                mutate(&mut spec);
                spec.validate().is_err()
            }
        };
        results.push((fixture.name(), rejected));
    }
    results
}

// UAS: red fixtures for focused proof-root owner-approval gate invalid states.
// Plane: Verification.
// Residency: metadata-only; no command, product, result-bundle, model, or runtime bytes open.
enum RedFixture {
    CommandCardFail,
    ExecutionArtifactGateFail,
    RunbookMissing,
    MutateSpec {
        name: &'static str,
        mutate: fn(&mut GraphFilterFocusedProofRootOwnerApprovalGate),
    },
}

impl RedFixture {
    fn name(&self) -> &'static str {
        match self {
            Self::CommandCardFail => "command_card_fail_rejected",
            Self::ExecutionArtifactGateFail => "execution_artifact_gate_fail_rejected",
            Self::RunbookMissing => "runbook_missing_rejected",
            Self::MutateSpec { name, .. } => name,
        }
    }
}

fn red_fixture_cases() -> Vec<RedFixture> {
    vec![
        RedFixture::CommandCardFail,
        RedFixture::ExecutionArtifactGateFail,
        RedFixture::RunbookMissing,
        RedFixture::MutateSpec {
            name: "approval_phrase_too_broad_rejected",
            mutate: |spec| spec.approval_phrase = "I approve tests".to_string(),
        },
        RedFixture::MutateSpec {
            name: "owner_approval_present_rejected",
            mutate: |spec| spec.owner_approval_present = true,
        },
        RedFixture::MutateSpec {
            name: "owner_approval_not_required_rejected",
            mutate: |spec| spec.owner_approval_required = false,
        },
        RedFixture::MutateSpec {
            name: "missing_precondition_rejected",
            mutate: |spec| {
                spec.required_preconditions
                    .retain(|field| field != "selected_product_digest_required")
            },
        },
        RedFixture::MutateSpec {
            name: "missing_consent_clause_rejected",
            mutate: |spec| {
                spec.required_consent_clauses
                    .retain(|field| field != "full_release_audit_separate_approval")
            },
        },
        RedFixture::MutateSpec {
            name: "missing_rejection_policy_rejected",
            mutate: |spec| {
                spec.required_rejection_policies
                    .retain(|field| field != "xcode_executed_without_approval")
            },
        },
        RedFixture::MutateSpec {
            name: "command_card_not_required_rejected",
            mutate: |spec| spec.command_card_required = false,
        },
        RedFixture::MutateSpec {
            name: "execution_gate_not_required_rejected",
            mutate: |spec| spec.execution_artifact_gate_required = false,
        },
        RedFixture::MutateSpec {
            name: "full_release_audit_requested_rejected",
            mutate: |spec| spec.full_release_audit_requested = true,
        },
        RedFixture::MutateSpec {
            name: "full_row_replacement_rejected",
            mutate: |spec| spec.full_automated_check_row_replaced = true,
        },
        RedFixture::MutateSpec {
            name: "command_envelope_armed_rejected",
            mutate: |spec| spec.command_envelope_armed = true,
        },
        RedFixture::MutateSpec {
            name: "xcode_command_executed_rejected",
            mutate: |spec| spec.xcode_command_executed = true,
        },
        RedFixture::MutateSpec {
            name: "selected_test_product_bytes_rejected",
            mutate: |spec| spec.selected_test_product_bytes_opened = 1,
        },
        RedFixture::MutateSpec {
            name: "xcode_result_bytes_rejected",
            mutate: |spec| spec.xcode_result_bytes_opened = 1,
        },
        RedFixture::MutateSpec {
            name: "model_runtime_bytes_rejected",
            mutate: |spec| spec.model_runtime_bytes_loaded = 1,
        },
        RedFixture::MutateSpec {
            name: "provider_call_rejected",
            mutate: |spec| spec.provider_calls_made = 1,
        },
        RedFixture::MutateSpec {
            name: "product_code_changed_rejected",
            mutate: |spec| spec.product_code_changed = true,
        },
        RedFixture::MutateSpec {
            name: "l2_green_claim_rejected",
            mutate: |spec| spec.l2_green_claimed = true,
        },
        RedFixture::MutateSpec {
            name: "l3_green_claim_rejected",
            mutate: |spec| spec.l3_green_claimed = true,
        },
        RedFixture::MutateSpec {
            name: "product_green_claim_rejected",
            mutate: |spec| spec.product_green_claimed = true,
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

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(axis, _)| *axis == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

// UAS: upstream falsifier witness summary bound by artifact address.
// Plane: Verification.
// Residency: metadata-only JSON read from prior witness result; no product/runtime bytes.
struct Upstream {
    overall_pass: bool,
    address: String,
}

fn read_upstream(path: &str, address_axis: &str) -> Result<Upstream, Box<dyn std::error::Error>> {
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(path)?)?;
    let overall_pass = value["overall_pass"].as_bool().unwrap_or(false);
    let address = value["measurements"][address_axis]["value"]
        .as_str()
        .unwrap_or_default()
        .to_string();
    Ok(Upstream {
        overall_pass,
        address,
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
        let witness = GraphFilterVisibilityFocusedProofRootOwnerApprovalGateWitness::new(
            true,
            "sha256:e7095c8391930693cd93aa9d4e69ce36f45e2b9d178cf7c95a16b81a06aad743",
            true,
            "sha256:ddaf0208e07b6d4528bb507dc6d7561cbd1c4f254c3e35ece1a4cc64ed844a99",
            true,
        )
        .expect("valid witness");
        let results = red_fixture_results(&witness);
        assert_eq!(results.len(), 26);
        assert!(results.iter().all(|(_, passed)| *passed));
    }
}
