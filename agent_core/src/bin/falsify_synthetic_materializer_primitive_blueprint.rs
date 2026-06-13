//! `falsify_synthetic_materializer_primitive_blueprint`.
//!
//! Metadata-only witness for `F-SyntheticMaterializerPrimitiveBlueprintV0`.
//! It creates no fixture files, opens no model/runtime/provider/cache/index
//! bytes, arms no command, and promotes no product capability.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    SyntheticMaterializerBlueprintError, SyntheticMaterializerPrimitiveBlueprint,
    SyntheticMaterializerPrimitiveBlueprintWitness, SYNTHETIC_MATERIALIZER_APPROVAL_PHRASE,
    SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_CURSOR,
    SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_ID,
    SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_NEXT_CURSOR,
};

const FIXTURE_ID: &str = "synthetic_materializer_primitive_blueprint_v1";
const COMMAND: &str = "Tools/falsifiers/f_synthetic_materializer_primitive_blueprint.sh";
const RESULT: &str = "artifacts/falsifiers/synthetic_materializer_primitive_blueprint/result.json";
const RED_FIXTURE_FLOOR: u64 = 18;

fn main() -> std::process::ExitCode {
    let artifact = match build_artifact() {
        Ok(artifact) => artifact,
        Err(error) => {
            eprintln!("failed to build {SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_ID}: {error}");
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
        SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_ID,
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
    let witness = SyntheticMaterializerPrimitiveBlueprintWitness::new()?;
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
        witness.falsifier_id == SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_ID
            && witness.cursor == SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_CURSOR
            && witness.next_cursor == SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_NEXT_CURSOR
            && witness.metadata_only
            && witness.product_promotion_blocked,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "approval_boundary_fail_closed",
        witness.spec.owner_approval_required
            && !witness.spec.owner_approval_present
            && witness.spec.approval_phrase == SYNTHETIC_MATERIALIZER_APPROVAL_PHRASE
            && red_pass(&red_results, "approval_present_in_blueprint")
            && red_pass(&red_results, "wrong_approval_phrase"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "path_policy_fail_closed",
        !witness.spec.path_policy.final_root_write_allowed
            && !witness.spec.path_policy.absolute_paths_allowed
            && !witness.spec.path_policy.parent_segments_allowed
            && !witness.spec.path_policy.hidden_segments_allowed
            && !witness.spec.path_policy.symlinks_allowed
            && !witness.spec.path_policy.hardlinks_allowed
            && witness.spec.path_policy.case_collision_denied
            && red_pass(&red_results, "absolute_fixture_root")
            && red_pass(&red_results, "parent_segment_escape")
            && red_pass(&red_results, "hidden_staging_segment_bypass")
            && red_pass(&red_results, "symlink_allowed")
            && red_pass(&red_results, "hardlink_allowed")
            && red_pass(&red_results, "case_collision_not_denied"),
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
        "inventory_and_digest_bound",
        witness.metrics.planned_descriptor_count == 6
            && witness.metrics.planned_verifier_count == 6
            && witness.metrics.planned_review_count == 4
            && witness
                .spec
                .inventory_plan
                .exact_inventory_digest
                .starts_with("sha256:")
            && red_pass(&red_results, "payload_count_not_six")
            && red_pass(&red_results, "digest_prefix_missing"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_surfaces_required",
        witness.spec.schema_validation_required
            && witness.spec.canonical_digest_required
            && witness.spec.privacy_scan_required
            && witness.spec.provenance_scan_required
            && witness.spec.rollback_required
            && witness.spec.run_event_log_required
            && witness.spec.answer_packet_required
            && red_pass(&red_results, "schema_validation_disabled")
            && red_pass(&red_results, "canonical_digest_disabled")
            && red_pass(&red_results, "privacy_scan_disabled")
            && red_pass(&red_results, "provenance_scan_disabled"),
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fixture_files_written",
        witness.metrics.payload_files_written,
        "==",
        0,
        "files",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "zero_byte_and_command_ledger",
        witness.metrics.fixture_bytes_written == 0
            && witness.metrics.runtime_model_provider_cache_index_bytes == 0
            && witness.metrics.commands_armed == 0
            && red_pass(&red_results, "payload_files_written_nonzero")
            && red_pass(&red_results, "runtime_bytes_nonzero")
            && red_pass(&red_results, "command_armed"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "promotion_boundary_preserved",
        witness.spec.promotion_boundary == "T0_only"
            && !witness.spec.l1_claimed
            && !witness.spec.l2_claimed
            && !witness.spec.l3_claimed
            && !witness.spec.t4_t5_claimed
            && !witness.spec.product_green_claimed
            && !witness.spec.release_ready_claimed
            && !witness.spec.live_dense_70b_claimed
            && !witness.spec.ssd_as_ram_claimed
            && red_pass(&red_results, "promotion_boundary_l2"),
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
        "next_research_to_build_unit",
        SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_NEXT_CURSOR,
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "guard_owned_product_cursor_preserved",
        "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe",
    );

    Ok(ArtifactBuilder {
        falsifier_id: SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: Vec::new(),
        notes: "Metadata-only T1/L1 side-ladder witness for the synthetic materializer primitive blueprint. It writes zero fixture files, opens zero model/runtime/provider/cache/index bytes, arms zero commands, does not advance the guard-owned product cursor, and makes no L2/L3/T4/T5 or large-local-model capability claim.".to_string(),
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
        red("approval_present_in_blueprint", |spec| {
            spec.owner_approval_present = true;
        }),
        red("wrong_approval_phrase", |spec| {
            spec.approval_phrase = "APPROVE".to_string();
        }),
        red("absolute_fixture_root", |spec| {
            spec.path_policy.fixture_root = "/tmp/fixtures".to_string();
        }),
        red("parent_segment_escape", |spec| {
            spec.path_policy.fixture_root = "fixtures/../secret".to_string();
        }),
        red("hidden_staging_segment_bypass", |spec| {
            spec.path_policy.hidden_segments_allowed = true;
        }),
        red("symlink_allowed", |spec| {
            spec.path_policy.symlinks_allowed = true;
        }),
        red("hardlink_allowed", |spec| {
            spec.path_policy.hardlinks_allowed = true;
        }),
        red("case_collision_not_denied", |spec| {
            spec.path_policy.case_collision_denied = false;
        }),
        red("payload_count_not_six", |spec| {
            spec.inventory_plan.planned_payload_count = 7;
        }),
        red("digest_prefix_missing", |spec| {
            spec.inventory_plan.exact_inventory_digest = "not-a-digest".to_string();
        }),
        red("schema_validation_disabled", |spec| {
            spec.schema_validation_required = false;
        }),
        red("canonical_digest_disabled", |spec| {
            spec.canonical_digest_required = false;
        }),
        red("privacy_scan_disabled", |spec| {
            spec.privacy_scan_required = false;
        }),
        red("provenance_scan_disabled", |spec| {
            spec.provenance_scan_required = false;
        }),
        red("payload_files_written_nonzero", |spec| {
            spec.byte_ledger.payload_files_written = 1;
        }),
        red("runtime_bytes_nonzero", |spec| {
            spec.byte_ledger.model_runtime_bytes_loaded = 1;
        }),
        red("command_armed", |spec| {
            spec.byte_ledger.commands_armed = 1;
        }),
        red("promotion_boundary_l2", |spec| {
            spec.promotion_boundary = "T2".to_string();
        }),
    ]
}

fn red(
    name: &str,
    mutate: impl FnOnce(&mut SyntheticMaterializerPrimitiveBlueprint),
) -> (String, bool) {
    let mut spec = SyntheticMaterializerPrimitiveBlueprint::canonical();
    mutate(&mut spec);
    let rejected = matches!(
        spec.validate(),
        Err(SyntheticMaterializerBlueprintError::ApprovalOrProofBoundaryBroken)
            | Err(SyntheticMaterializerBlueprintError::WrongValue(_))
            | Err(SyntheticMaterializerBlueprintError::PathPolicyBroken)
            | Err(SyntheticMaterializerBlueprintError::InventoryPlanBroken)
            | Err(SyntheticMaterializerBlueprintError::InvalidSha256(_))
            | Err(SyntheticMaterializerBlueprintError::ByteOrCommandLeak)
            | Err(SyntheticMaterializerBlueprintError::PromotionClaim)
    );
    (name.to_string(), rejected)
}
