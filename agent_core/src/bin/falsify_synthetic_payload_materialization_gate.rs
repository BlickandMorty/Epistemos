//! `falsify_synthetic_payload_materialization_gate`.
//!
//! Metadata-only witness for `F-SyntheticPayloadMaterializationGateV0`.
//! It refuses fixture materialization, creates no fixture files, opens no
//! model/runtime/provider/cache/index bytes, arms no command, and promotes no
//! product capability.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    SyntheticPayloadMaterializationGate, SyntheticPayloadMaterializationGateError,
    SyntheticPayloadMaterializationGateWitness, SyntheticPayloadMaterializationStatus,
    SYNTHETIC_MATERIALIZER_APPROVAL_PHRASE, SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_ID,
    SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_CURSOR, SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_ID,
    SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_NEXT_CURSOR,
};

const FIXTURE_ID: &str = "synthetic_payload_materialization_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_synthetic_payload_materialization_gate.sh";
const RESULT: &str = "artifacts/falsifiers/synthetic_payload_materialization_gate/result.json";
const RED_FIXTURE_FLOOR: u64 = 27;
const GUARD_PRODUCT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";

fn main() -> std::process::ExitCode {
    let artifact = match build_artifact() {
        Ok(artifact) => artifact,
        Err(error) => {
            eprintln!("failed to build {SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_ID}: {error}");
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
        "{}: overall_pass={} planned_payloads={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_ID,
        artifact.overall_pass,
        artifact.measurements["planned_payload_count"].value,
        artifact.measurements["red_fixture_rejection_count"].value,
        artifact.measurements["next_research_to_build_unit"].value,
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let witness = SyntheticPayloadMaterializationGateWitness::new()?;
    witness.validate()?;
    let red_results = red_fixture_results();
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "witness_header_bound",
        witness.falsifier_id == SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_ID
            && witness.cursor == SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_CURSOR
            && witness.next_cursor == SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_NEXT_CURSOR
            && witness.metadata_only
            && witness.product_promotion_blocked,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_blueprint_bound",
        witness.spec.upstream_falsifier_id == SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_ID
            && witness
                .spec
                .upstream_blueprint_address
                .starts_with("sha256:")
            && red_pass(&red_results, "upstream_address_drift"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "approval_absent_refusal_bound",
        witness.spec.approval.owner_approval_required
            && !witness.spec.approval.owner_approval_present
            && witness.spec.approval.approval_phrase == SYNTHETIC_MATERIALIZER_APPROVAL_PHRASE
            && witness.spec.approval.approved_write_roots == 0
            && witness.spec.status == SyntheticPayloadMaterializationStatus::ApprovalAbsentRefusal
            && red_pass(&red_results, "approval_present")
            && red_pass(&red_results, "wrong_approval_phrase")
            && red_pass(&red_results, "approved_write_root_nonzero"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "staging_path_policy_fail_closed",
        !witness.spec.path_policy.final_root_write_allowed
            && !witness.spec.path_policy.direct_final_write_allowed
            && !witness.spec.path_policy.absolute_paths_allowed
            && !witness.spec.path_policy.parent_segments_allowed
            && !witness.spec.path_policy.undeclared_hidden_segments_allowed
            && !witness.spec.path_policy.symlinks_allowed
            && !witness.spec.path_policy.hardlinks_allowed
            && witness.spec.path_policy.case_collision_denied
            && !witness.spec.path_policy.cross_device_rename_allowed
            && witness.spec.path_policy.pre_existing_final_collision_denied
            && red_pass(&red_results, "direct_final_write")
            && red_pass(&red_results, "absolute_fixture_root")
            && red_pass(&red_results, "parent_segment_escape")
            && red_pass(&red_results, "undeclared_hidden_segment")
            && red_pass(&red_results, "symlink_allowed")
            && red_pass(&red_results, "hardlink_allowed")
            && red_pass(&red_results, "case_collision_not_denied")
            && red_pass(&red_results, "cross_device_rename_allowed")
            && red_pass(&red_results, "pre_existing_collision_allowed"),
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "planned_payload_count",
        witness.metrics.planned_payload_count,
        6,
        "files",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "planned_inventory_bound",
        witness.metrics.planned_descriptor_count == 6
            && witness.metrics.planned_verifier_count == 6
            && witness.metrics.planned_review_count == 4
            && witness
                .spec
                .inventory_plan
                .exact_inventory_digest
                .starts_with("sha256:")
            && red_pass(&red_results, "payload_count_not_six")
            && red_pass(&red_results, "manifest_count_zero")
            && red_pass(&red_results, "inventory_digest_drift"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "schema_and_jcs_requirements_bound",
        witness.spec.validation_plan.json_schema_draft == "2020-12"
            && witness.spec.validation_plan.closed_fields_required
            && witness
                .spec
                .validation_plan
                .duplicate_key_rejection_required
            && witness
                .spec
                .validation_plan
                .invalid_unicode_rejection_required
            && witness.spec.validation_plan.nan_infinity_rejection_required
            && witness.spec.validation_plan.jcs_canonical_digest_required
            && red_pass(&red_results, "wrong_json_schema_draft")
            && red_pass(&red_results, "open_fields_allowed")
            && red_pass(&red_results, "duplicate_key_not_rejected")
            && red_pass(&red_results, "invalid_unicode_not_rejected")
            && red_pass(&red_results, "nan_infinity_not_rejected")
            && red_pass(&red_results, "non_jcs_digest_allowed"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "privacy_provenance_benchmark_scans_bound",
        witness.spec.validation_plan.privacy_scan_required
            && witness.spec.validation_plan.provenance_scan_required
            && witness.spec.validation_plan.benchmark_scan_required
            && red_pass(&red_results, "privacy_scan_disabled")
            && red_pass(&red_results, "provenance_scan_disabled")
            && red_pass(&red_results, "benchmark_scan_disabled"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rollback_run_event_answer_packet_bound",
        witness.spec.validation_plan.rollback_required
            && witness.spec.validation_plan.run_event_log_required
            && witness.spec.validation_plan.answer_packet_required
            && red_pass(&red_results, "rollback_disabled")
            && red_pass(&red_results, "run_event_log_disabled")
            && red_pass(&red_results, "answer_packet_disabled"),
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fixture_files_written",
        witness.metrics.payload_files_written + witness.metrics.final_files_promoted,
        "==",
        0,
        "files",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "zero_byte_and_command_ledger",
        witness.metrics.staging_dirs_created == 0
            && witness.metrics.final_files_promoted == 0
            && witness.metrics.payload_files_written == 0
            && witness.metrics.fixture_bytes_written == 0
            && witness.metrics.runtime_model_provider_cache_index_bytes == 0
            && witness.metrics.commands_armed == 0
            && red_pass(&red_results, "staging_dir_created")
            && red_pass(&red_results, "payload_files_written")
            && red_pass(&red_results, "fixture_bytes_written")
            && red_pass(&red_results, "runtime_bytes_nonzero")
            && red_pass(&red_results, "provider_calls_nonzero")
            && red_pass(&red_results, "cache_index_bytes_nonzero")
            && red_pass(&red_results, "command_armed"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "promotion_boundary_preserved",
        witness.spec.metadata_only
            && !witness.spec.l1_claimed
            && !witness.spec.l2_claimed
            && !witness.spec.l3_claimed
            && !witness.spec.t4_t5_claimed
            && !witness.spec.product_green_claimed
            && !witness.spec.release_ready_claimed
            && !witness.spec.live_dense_70b_claimed
            && !witness.spec.ssd_as_ram_claimed
            && !witness.spec.hidden_route_authority_claimed
            && red_pass(&red_results, "l1_claimed")
            && red_pass(&red_results, "l2_claimed")
            && red_pass(&red_results, "product_green_claimed")
            && red_pass(&red_results, "hidden_route_authority_claimed"),
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_rejection_count",
        red_fixture_rejection_count,
        ">=",
        RED_FIXTURE_FLOOR,
        "fixtures",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "witness_address",
        &witness.address,
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_blueprint_address",
        &witness.spec.upstream_blueprint_address,
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_NEXT_CURSOR,
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "guard_owned_product_cursor_preserved",
        GUARD_PRODUCT_CURSOR,
    );

    Ok(ArtifactBuilder {
        falsifier_id: SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: Vec::new(),
        notes: "Metadata-only T1/L1 side-ladder witness for the synthetic payload materialization gate. It binds the upstream synthetic materializer blueprint, refuses owner-approval-absent materialization, requires staging path policy plus schema/JCS/privacy/provenance/benchmark/rollback/RunEventLog/AnswerPacket proof surfaces, writes zero fixture files, opens zero model/runtime/provider/cache/index bytes, arms zero commands, preserves the guard-owned small-model product cursor, and makes no L2/L3/T4/T5 or large-local-model capability claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn add_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "string".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "string".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), !value.is_empty());
}

fn red_pass(results: &[(String, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(candidate, _)| candidate == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn red_fixture_results() -> Vec<(String, bool)> {
    vec![
        red("upstream_address_drift", |gate| {
            gate.upstream_blueprint_address =
                "sha256:0000000000000000000000000000000000000000000000000000000000000000"
                    .to_string();
        }),
        red("approval_present", |gate| {
            gate.approval.owner_approval_present = true;
        }),
        red("wrong_approval_phrase", |gate| {
            gate.approval.approval_phrase = "APPROVE".to_string();
        }),
        red("approved_write_root_nonzero", |gate| {
            gate.approval.approved_write_roots = 1;
        }),
        red("direct_final_write", |gate| {
            gate.path_policy.direct_final_write_allowed = true;
        }),
        red("absolute_fixture_root", |gate| {
            gate.path_policy.fixture_root = "/tmp/fixtures".to_string();
        }),
        red("parent_segment_escape", |gate| {
            gate.path_policy.fixture_root = "fixtures/../secret".to_string();
        }),
        red("undeclared_hidden_segment", |gate| {
            gate.path_policy.undeclared_hidden_segments_allowed = true;
        }),
        red("symlink_allowed", |gate| {
            gate.path_policy.symlinks_allowed = true;
        }),
        red("hardlink_allowed", |gate| {
            gate.path_policy.hardlinks_allowed = true;
        }),
        red("case_collision_not_denied", |gate| {
            gate.path_policy.case_collision_denied = false;
        }),
        red("cross_device_rename_allowed", |gate| {
            gate.path_policy.cross_device_rename_allowed = true;
        }),
        red("pre_existing_collision_allowed", |gate| {
            gate.path_policy.pre_existing_final_collision_denied = false;
        }),
        red("payload_count_not_six", |gate| {
            gate.inventory_plan.planned_payload_count = 7;
        }),
        red("manifest_count_zero", |gate| {
            gate.inventory_plan.planned_manifest_count = 0;
        }),
        red("inventory_digest_drift", |gate| {
            gate.inventory_plan.exact_inventory_digest =
                "sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
                    .to_string();
        }),
        red("wrong_json_schema_draft", |gate| {
            gate.validation_plan.json_schema_draft = "draft-07".to_string();
        }),
        red("open_fields_allowed", |gate| {
            gate.validation_plan.closed_fields_required = false;
        }),
        red("duplicate_key_not_rejected", |gate| {
            gate.validation_plan.duplicate_key_rejection_required = false;
        }),
        red("invalid_unicode_not_rejected", |gate| {
            gate.validation_plan.invalid_unicode_rejection_required = false;
        }),
        red("nan_infinity_not_rejected", |gate| {
            gate.validation_plan.nan_infinity_rejection_required = false;
        }),
        red("non_jcs_digest_allowed", |gate| {
            gate.validation_plan.jcs_canonical_digest_required = false;
        }),
        red("privacy_scan_disabled", |gate| {
            gate.validation_plan.privacy_scan_required = false;
        }),
        red("provenance_scan_disabled", |gate| {
            gate.validation_plan.provenance_scan_required = false;
        }),
        red("benchmark_scan_disabled", |gate| {
            gate.validation_plan.benchmark_scan_required = false;
        }),
        red("rollback_disabled", |gate| {
            gate.validation_plan.rollback_required = false;
        }),
        red("run_event_log_disabled", |gate| {
            gate.validation_plan.run_event_log_required = false;
        }),
        red("answer_packet_disabled", |gate| {
            gate.validation_plan.answer_packet_required = false;
        }),
        red("staging_dir_created", |gate| {
            gate.byte_ledger.staging_dirs_created = 1;
        }),
        red("payload_files_written", |gate| {
            gate.byte_ledger.payload_files_written = 1;
        }),
        red("fixture_bytes_written", |gate| {
            gate.byte_ledger.fixture_bytes_written = 1;
        }),
        red("runtime_bytes_nonzero", |gate| {
            gate.byte_ledger.model_runtime_bytes_loaded = 1;
        }),
        red("provider_calls_nonzero", |gate| {
            gate.byte_ledger.provider_calls_made = 1;
        }),
        red("cache_index_bytes_nonzero", |gate| {
            gate.byte_ledger.cache_index_bytes_opened = 1;
        }),
        red("command_armed", |gate| {
            gate.byte_ledger.commands_armed = 1;
        }),
        red("l1_claimed", |gate| {
            gate.l1_claimed = true;
        }),
        red("l2_claimed", |gate| {
            gate.l2_claimed = true;
        }),
        red("product_green_claimed", |gate| {
            gate.product_green_claimed = true;
        }),
        red("hidden_route_authority_claimed", |gate| {
            gate.hidden_route_authority_claimed = true;
        }),
    ]
}

fn red(
    name: &str,
    mutate: impl FnOnce(&mut SyntheticPayloadMaterializationGate),
) -> (String, bool) {
    let mut gate = SyntheticPayloadMaterializationGate::canonical().expect("canonical gate");
    mutate(&mut gate);
    let rejected = matches!(
        gate.validate(),
        Err(SyntheticPayloadMaterializationGateError::WrongValue(_))
            | Err(SyntheticPayloadMaterializationGateError::ApprovalBoundaryBroken)
            | Err(SyntheticPayloadMaterializationGateError::PathPolicyBroken)
            | Err(SyntheticPayloadMaterializationGateError::InventoryPlanBroken)
            | Err(SyntheticPayloadMaterializationGateError::ValidationPlanBroken)
            | Err(SyntheticPayloadMaterializationGateError::ByteOrCommandLeak)
            | Err(SyntheticPayloadMaterializationGateError::PromotionClaim)
    );
    (name.to_string(), rejected)
}
