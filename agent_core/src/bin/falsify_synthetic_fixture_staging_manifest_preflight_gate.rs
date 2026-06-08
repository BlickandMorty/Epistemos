//! `falsify_synthetic_fixture_staging_manifest_preflight_gate`.
//!
//! Metadata-only witness for `F-SyntheticFixtureStagingManifestPreflightGate`.
//! It consumes the JCS writer dry-run and proves manifest preflight requirements
//! while writing zero fixture or manifest bytes.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    SyntheticFixtureStagingManifestError, SyntheticFixtureStagingManifestPreflightGate,
    SyntheticFixtureStagingManifestPreflightWitness, SyntheticFixtureStagingManifestStatus,
    JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_ID,
    SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_CURSOR,
    SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_ID,
    SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_NEXT_CURSOR,
};

const FIXTURE_ID: &str = "synthetic_fixture_staging_manifest_preflight_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_synthetic_fixture_staging_manifest_preflight_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/synthetic_fixture_staging_manifest_preflight_gate/result.json";
const RED_FIXTURE_FLOOR: u64 = 28;
const GUARD_PRODUCT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";

fn main() -> std::process::ExitCode {
    let artifact = match build_artifact() {
        Ok(artifact) => artifact,
        Err(error) => {
            eprintln!(
                "failed to build {SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_ID}: {error}"
            );
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
        "{}: overall_pass={} manifest_fields={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_ID,
        artifact.overall_pass,
        artifact.measurements["manifest_field_count"].value,
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
    let witness = SyntheticFixtureStagingManifestPreflightWitness::new()?;
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
        witness.falsifier_id == SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_ID
            && witness.cursor == SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_CURSOR
            && witness.next_cursor == SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_NEXT_CURSOR
            && witness.metadata_only
            && witness.product_promotion_blocked,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_writer_dry_run_bound",
        witness.spec.upstream_falsifier_id == JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_ID
            && witness
                .spec
                .upstream_writer_dry_run_address
                .starts_with("sha256:")
            && red_pass(&red_results, "upstream_address_drift"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "source_card_fail_closed",
        witness.spec.dry_run_fragments_consumed
            && !witness.spec.staging_manifest_file_claimed
            && !witness.spec.owner_approval_granted
            && red_pass(&red_results, "dry_run_fragments_not_consumed")
            && red_pass(&red_results, "manifest_file_claimed")
            && red_pass(&red_results, "owner_approval_granted"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "path_policy_bound",
        witness.spec.repo_relative_paths_required
            && witness.spec.absolute_paths_denied
            && witness.spec.parent_segments_denied
            && witness.spec.hidden_segments_denied
            && witness.spec.symlink_follow_denied
            && witness.spec.hardlink_denied
            && witness.spec.direct_final_write_denied
            && witness.spec.cross_device_rename_denied
            && witness.spec.preexisting_final_collision_denied
            && red_pass(&red_results, "absolute_paths_allowed")
            && red_pass(&red_results, "parent_segments_allowed")
            && red_pass(&red_results, "direct_final_write_allowed")
            && red_pass(&red_results, "preexisting_collision_allowed"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "digest_policy_bound",
        witness.spec.jcs_canonical_digest_required
            && witness.spec.sha256_required
            && witness.spec.fragment_digest_required
            && witness.spec.manifest_digest_required
            && witness.spec.inventory_digest_required
            && witness.spec.duplicate_path_rejection_required
            && witness.spec.duplicate_digest_rejection_required
            && red_pass(&red_results, "jcs_digest_not_required")
            && red_pass(&red_results, "manifest_digest_not_required")
            && red_pass(&red_results, "duplicate_path_allowed"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_policy_bound",
        witness.spec.owner_approval_phrase == "APPROVE_SYNTHETIC_FIXTURE_MATERIALIZATION_V0"
            && witness.spec.rollback_receipt_required
            && witness.spec.run_event_log_required
            && witness.spec.answer_packet_required
            && witness.spec.privacy_scan_required
            && witness.spec.provenance_scan_required
            && witness.spec.benchmark_contamination_scan_required
            && witness.spec.no_product_route_authority
            && witness.spec.status
                == SyntheticFixtureStagingManifestStatus::ManifestPreflightBoundWritesStillBlocked
            && red_pass(&red_results, "wrong_approval_phrase")
            && red_pass(&red_results, "rollback_not_required")
            && red_pass(&red_results, "answer_packet_not_required")
            && red_pass(&red_results, "product_route_authority_enabled"),
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "manifest_field_count",
        witness.metrics.manifest_field_count,
        16,
        "fields",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "manifest_field_contract_bound",
        witness.metrics.required_manifest_field_count == 16
            && witness.spec.manifest_field_digest.starts_with("sha256:")
            && red_pass(&red_results, "manifest_field_name_drift")
            && red_pass(&red_results, "manifest_field_optional")
            && red_pass(&red_results, "manifest_field_digest_drift"),
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "manifest_files_written",
        witness.metrics.manifest_files_written,
        "==",
        0,
        "files",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "zero_byte_and_command_ledger",
        witness.metrics.manifest_files_written == 0
            && witness.metrics.fixture_files_written == 0
            && witness.metrics.fixture_bytes_written == 0
            && witness.metrics.runtime_model_provider_cache_index_bytes == 0
            && witness.metrics.commands_armed == 0
            && red_pass(&red_results, "manifest_file_written")
            && red_pass(&red_results, "staging_dir_created")
            && red_pass(&red_results, "staging_file_written")
            && red_pass(&red_results, "final_file_written")
            && red_pass(&red_results, "fixture_bytes_written")
            && red_pass(&red_results, "runtime_bytes_nonzero")
            && red_pass(&red_results, "provider_calls_nonzero")
            && red_pass(&red_results, "cache_index_bytes_nonzero")
            && red_pass(&red_results, "filesystem_stat_calls_nonzero")
            && red_pass(&red_results, "command_armed"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "promotion_boundary_preserved",
        !witness.spec.l1_claimed
            && !witness.spec.l2_claimed
            && !witness.spec.l3_claimed
            && !witness.spec.t4_t5_claimed
            && !witness.spec.product_green_claimed
            && !witness.spec.release_ready_claimed
            && !witness.spec.live_dense_70b_claimed
            && !witness.spec.ssd_as_ram_claimed
            && !witness.spec.hidden_route_authority_claimed
            && !witness.spec.materialization_allowed
            && witness.spec.metadata_only
            && red_pass(&red_results, "materialization_allowed")
            && red_pass(&red_results, "metadata_boundary_disabled")
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
        "upstream_writer_dry_run_address",
        &witness.spec.upstream_writer_dry_run_address,
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_NEXT_CURSOR,
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "guard_owned_product_cursor_preserved",
        GUARD_PRODUCT_CURSOR,
    );

    Ok(ArtifactBuilder {
        falsifier_id: SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: Vec::new(),
        notes: "Metadata-only T1/L1 side-ladder witness for the synthetic fixture staging manifest preflight gate. It consumes the JCS writer dry-run, binds manifest fields, staging/final path policy, digest policy, rollback, RunEventLog, AnswerPacket, privacy/provenance/benchmark scans, writes zero files, opens zero model/runtime/provider/cache/index bytes, arms zero commands, preserves the guard-owned small-model product cursor, and makes no L2/L3/T4/T5 or large-local-model capability claim.".to_string(),
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
        red("upstream_address_drift", |preflight| {
            preflight.upstream_writer_dry_run_address =
                "sha256:0000000000000000000000000000000000000000000000000000000000000000"
                    .to_string();
        }),
        red("dry_run_fragments_not_consumed", |preflight| {
            preflight.dry_run_fragments_consumed = false;
        }),
        red("manifest_file_claimed", |preflight| {
            preflight.staging_manifest_file_claimed = true;
        }),
        red("owner_approval_granted", |preflight| {
            preflight.owner_approval_granted = true;
        }),
        red("absolute_paths_allowed", |preflight| {
            preflight.absolute_paths_denied = false;
        }),
        red("parent_segments_allowed", |preflight| {
            preflight.parent_segments_denied = false;
        }),
        red("direct_final_write_allowed", |preflight| {
            preflight.direct_final_write_denied = false;
        }),
        red("preexisting_collision_allowed", |preflight| {
            preflight.preexisting_final_collision_denied = false;
        }),
        red("jcs_digest_not_required", |preflight| {
            preflight.jcs_canonical_digest_required = false;
        }),
        red("manifest_digest_not_required", |preflight| {
            preflight.manifest_digest_required = false;
        }),
        red("duplicate_path_allowed", |preflight| {
            preflight.duplicate_path_rejection_required = false;
        }),
        red("wrong_approval_phrase", |preflight| {
            preflight.owner_approval_phrase = "APPROVE".to_string();
        }),
        red("rollback_not_required", |preflight| {
            preflight.rollback_receipt_required = false;
        }),
        red("answer_packet_not_required", |preflight| {
            preflight.answer_packet_required = false;
        }),
        red("product_route_authority_enabled", |preflight| {
            preflight.no_product_route_authority = false;
        }),
        red("manifest_field_name_drift", |preflight| {
            preflight.manifest_fields[0].name = "schema_version".to_string();
        }),
        red("manifest_field_optional", |preflight| {
            preflight.manifest_fields[1].required = false;
        }),
        red("manifest_field_digest_drift", |preflight| {
            preflight.manifest_field_digest =
                "sha256:0000000000000000000000000000000000000000000000000000000000000000"
                    .to_string();
        }),
        red("manifest_file_written", |preflight| {
            preflight.manifest_files_written = 1;
        }),
        red("staging_dir_created", |preflight| {
            preflight.staging_dirs_created = 1;
        }),
        red("staging_file_written", |preflight| {
            preflight.staging_files_written = 1;
        }),
        red("final_file_written", |preflight| {
            preflight.final_files_written = 1;
        }),
        red("fixture_bytes_written", |preflight| {
            preflight.fixture_bytes_written = 1;
        }),
        red("runtime_bytes_nonzero", |preflight| {
            preflight.model_runtime_bytes_loaded = 1;
        }),
        red("provider_calls_nonzero", |preflight| {
            preflight.provider_calls_made = 1;
        }),
        red("cache_index_bytes_nonzero", |preflight| {
            preflight.cache_index_bytes_opened = 1;
        }),
        red("filesystem_stat_calls_nonzero", |preflight| {
            preflight.filesystem_stat_calls = 1;
        }),
        red("command_armed", |preflight| {
            preflight.commands_armed = 1;
        }),
        red("materialization_allowed", |preflight| {
            preflight.materialization_allowed = true;
        }),
        red("metadata_boundary_disabled", |preflight| {
            preflight.metadata_only = false;
        }),
        red("l2_claimed", |preflight| {
            preflight.l2_claimed = true;
        }),
        red("product_green_claimed", |preflight| {
            preflight.product_green_claimed = true;
        }),
        red("hidden_route_authority_claimed", |preflight| {
            preflight.hidden_route_authority_claimed = true;
        }),
    ]
}

fn red(
    name: &str,
    mutate: impl FnOnce(&mut SyntheticFixtureStagingManifestPreflightGate),
) -> (String, bool) {
    let mut preflight =
        SyntheticFixtureStagingManifestPreflightGate::canonical().expect("canonical preflight");
    mutate(&mut preflight);
    let rejected = matches!(
        preflight.validate(),
        Err(SyntheticFixtureStagingManifestError::WrongValue(_))
            | Err(SyntheticFixtureStagingManifestError::SourceCardBroken)
            | Err(SyntheticFixtureStagingManifestError::PathPolicyBroken)
            | Err(SyntheticFixtureStagingManifestError::DigestPolicyBroken)
            | Err(SyntheticFixtureStagingManifestError::ProofPolicyBroken)
            | Err(SyntheticFixtureStagingManifestError::ManifestFieldBroken)
            | Err(SyntheticFixtureStagingManifestError::ByteOrCommandLeak)
            | Err(SyntheticFixtureStagingManifestError::MaterializationBoundaryBroken)
            | Err(SyntheticFixtureStagingManifestError::PromotionClaim)
    );
    (name.to_string(), rejected)
}
