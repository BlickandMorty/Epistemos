//! `falsify_jcs_fixture_writer_fail_closed_dry_run`.
//!
//! Metadata-only witness for `F-JcsFixtureWriterFailClosedDryRun`. It consumes
//! the pinned JCS number/UTF-16 oracle and proves writer materialization still
//! fails closed before owner-approved staging.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    JcsFixtureWriterDryRunError, JcsFixtureWriterDryRunStatus, JcsFixtureWriterFailClosedDryRun,
    JcsFixtureWriterFailClosedDryRunWitness, JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_CURSOR,
    JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_ID, JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_NEXT_CURSOR,
    JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_ID,
};

const FIXTURE_ID: &str = "jcs_fixture_writer_fail_closed_dry_run_v1";
const COMMAND: &str = "Tools/falsifiers/f_jcs_fixture_writer_fail_closed_dry_run.sh";
const RESULT: &str = "artifacts/falsifiers/jcs_fixture_writer_fail_closed_dry_run/result.json";
const RED_FIXTURE_FLOOR: u64 = 24;
const GUARD_PRODUCT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";

fn main() -> std::process::ExitCode {
    let artifact = match build_artifact() {
        Ok(artifact) => artifact,
        Err(error) => {
            eprintln!("failed to build {JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_ID}: {error}");
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
        "{}: overall_pass={} planned_fragments={} blocked_writes={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_ID,
        artifact.overall_pass,
        artifact.measurements["planned_fragment_count"].value,
        artifact.measurements["blocked_write_count"].value,
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
    let witness = JcsFixtureWriterFailClosedDryRunWitness::new()?;
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
        witness.falsifier_id == JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_ID
            && witness.cursor == JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_CURSOR
            && witness.next_cursor == JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_NEXT_CURSOR
            && witness.metadata_only
            && witness.product_promotion_blocked,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_oracle_bound",
        witness.spec.source_card.upstream_falsifier_id == JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_ID
            && witness
                .spec
                .source_card
                .upstream_oracle_address
                .starts_with("sha256:")
            && red_pass(&red_results, "upstream_address_drift"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "oracle_consumption_bound",
        witness.spec.source_card.rfc8785_number_oracle_consumed
            && witness.spec.source_card.utf16_sort_oracle_consumed
            && !witness.spec.source_card.local_writer_implementation_claimed
            && !witness.spec.source_card.node_runtime_required
            && red_pass(&red_results, "number_oracle_not_consumed")
            && red_pass(&red_results, "utf16_oracle_not_consumed")
            && red_pass(&red_results, "local_writer_claimed")
            && red_pass(&red_results, "node_runtime_required"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fail_closed_policy_bound",
        witness.spec.policy.in_memory_plan_only
            && witness.spec.policy.owner_approval_required_for_write
            && witness.spec.policy.staging_manifest_required_before_write
            && witness.spec.policy.direct_final_write_denied
            && witness.spec.policy.serde_json_not_fixture_authority
            && witness.spec.policy.trifusion_not_fixture_authority
            && witness.spec.policy.duplicate_key_rejection_required
            && witness.spec.policy.invalid_unicode_rejection_required
            && witness.spec.policy.nan_infinity_rejection_required
            && witness.spec.policy.utf16_sort_required
            && witness.spec.policy.number_oracle_required
            && witness.spec.policy.rollback_required
            && witness.spec.policy.run_event_log_required
            && witness.spec.policy.answer_packet_required
            && witness.spec.status == JcsFixtureWriterDryRunStatus::DryRunPlannedWriterStillBlocked
            && red_pass(&red_results, "in_memory_plan_disabled")
            && red_pass(&red_results, "owner_approval_not_required")
            && red_pass(&red_results, "staging_manifest_not_required")
            && red_pass(&red_results, "direct_final_write_allowed")
            && red_pass(&red_results, "serde_json_claimed_authority")
            && red_pass(&red_results, "trifusion_claimed_authority")
            && red_pass(&red_results, "rollback_not_required"),
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "planned_fragment_count",
        witness.metrics.planned_fragment_count,
        4,
        "fragments",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "planned_fragment_oracle_bound",
        witness.metrics.number_fragment_count == 3
            && witness.metrics.utf16_sort_fragment_count == 1
            && witness.spec.planned_fragment_digest.starts_with("sha256:")
            && red_pass(&red_results, "fragment_json_drift")
            && red_pass(&red_results, "fragment_source_drift")
            && red_pass(&red_results, "fragment_digest_drift"),
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "blocked_write_count",
        witness.metrics.blocked_write_count,
        4,
        "fragments",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "materialization_blocked",
        !witness.spec.owner_approval_granted
            && !witness.spec.materialization_allowed
            && witness.spec.metadata_only
            && red_pass(&red_results, "fragment_write_allowed")
            && red_pass(&red_results, "owner_approval_granted")
            && red_pass(&red_results, "materialization_allowed")
            && red_pass(&red_results, "metadata_boundary_disabled"),
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fixture_files_written",
        witness.metrics.fixture_files_written,
        "==",
        0,
        "files",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "zero_byte_and_command_ledger",
        witness.metrics.fixture_files_written == 0
            && witness.metrics.fixture_bytes_written == 0
            && witness.metrics.runtime_model_provider_cache_index_bytes == 0
            && witness.metrics.commands_armed == 0
            && red_pass(&red_results, "fixture_file_written")
            && red_pass(&red_results, "fixture_bytes_written")
            && red_pass(&red_results, "staging_manifest_written")
            && red_pass(&red_results, "final_file_written")
            && red_pass(&red_results, "schema_file_written")
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
        !witness.spec.l1_claimed
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
        "upstream_oracle_address",
        &witness.spec.source_card.upstream_oracle_address,
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_NEXT_CURSOR,
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "guard_owned_product_cursor_preserved",
        GUARD_PRODUCT_CURSOR,
    );

    Ok(ArtifactBuilder {
        falsifier_id: JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: Vec::new(),
        notes: "Metadata-only T1/L1 side-ladder witness for the JCS fixture writer fail-closed dry-run. It consumes the number and UTF-16 oracle, plans four in-memory canonical fixture fragments, blocks all writes until owner-approved staging manifest proof exists, opens zero model/runtime/provider/cache/index bytes, arms zero commands, preserves the guard-owned small-model product cursor, and makes no L2/L3/T4/T5 or large-local-model capability claim.".to_string(),
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
        red("upstream_address_drift", |dry_run| {
            dry_run.source_card.upstream_oracle_address =
                "sha256:0000000000000000000000000000000000000000000000000000000000000000"
                    .to_string();
        }),
        red("number_oracle_not_consumed", |dry_run| {
            dry_run.source_card.rfc8785_number_oracle_consumed = false;
        }),
        red("utf16_oracle_not_consumed", |dry_run| {
            dry_run.source_card.utf16_sort_oracle_consumed = false;
        }),
        red("local_writer_claimed", |dry_run| {
            dry_run.source_card.local_writer_implementation_claimed = true;
        }),
        red("node_runtime_required", |dry_run| {
            dry_run.source_card.node_runtime_required = true;
        }),
        red("in_memory_plan_disabled", |dry_run| {
            dry_run.policy.in_memory_plan_only = false;
        }),
        red("owner_approval_not_required", |dry_run| {
            dry_run.policy.owner_approval_required_for_write = false;
        }),
        red("staging_manifest_not_required", |dry_run| {
            dry_run.policy.staging_manifest_required_before_write = false;
        }),
        red("direct_final_write_allowed", |dry_run| {
            dry_run.policy.direct_final_write_denied = false;
        }),
        red("serde_json_claimed_authority", |dry_run| {
            dry_run.policy.serde_json_not_fixture_authority = false;
        }),
        red("trifusion_claimed_authority", |dry_run| {
            dry_run.policy.trifusion_not_fixture_authority = false;
        }),
        red("rollback_not_required", |dry_run| {
            dry_run.policy.rollback_required = false;
        }),
        red("fragment_json_drift", |dry_run| {
            dry_run.planned_fragments[1].planned_json_fragment =
                "{\"hex\":\"44b52d02c7e14af6\",\"json\":100000000000000000000000}".to_string();
        }),
        red("fragment_source_drift", |dry_run| {
            dry_run.planned_fragments[2].source_oracle = "utf8_sort".to_string();
        }),
        red("fragment_digest_drift", |dry_run| {
            dry_run.planned_fragment_digest =
                "sha256:0000000000000000000000000000000000000000000000000000000000000000"
                    .to_string();
        }),
        red("fragment_write_allowed", |dry_run| {
            dry_run.planned_fragments[0].writes_allowed = true;
        }),
        red("owner_approval_granted", |dry_run| {
            dry_run.owner_approval_granted = true;
        }),
        red("materialization_allowed", |dry_run| {
            dry_run.materialization_allowed = true;
        }),
        red("metadata_boundary_disabled", |dry_run| {
            dry_run.metadata_only = false;
        }),
        red("fixture_file_written", |dry_run| {
            dry_run.byte_ledger.fixture_files_written = 1;
        }),
        red("fixture_bytes_written", |dry_run| {
            dry_run.byte_ledger.fixture_bytes_written = 1;
        }),
        red("staging_manifest_written", |dry_run| {
            dry_run.byte_ledger.staging_manifest_files_written = 1;
        }),
        red("final_file_written", |dry_run| {
            dry_run.byte_ledger.final_files_written = 1;
        }),
        red("schema_file_written", |dry_run| {
            dry_run.byte_ledger.schema_files_written = 1;
        }),
        red("runtime_bytes_nonzero", |dry_run| {
            dry_run.byte_ledger.model_runtime_bytes_loaded = 1;
        }),
        red("provider_calls_nonzero", |dry_run| {
            dry_run.byte_ledger.provider_calls_made = 1;
        }),
        red("cache_index_bytes_nonzero", |dry_run| {
            dry_run.byte_ledger.cache_index_bytes_opened = 1;
        }),
        red("command_armed", |dry_run| {
            dry_run.byte_ledger.commands_armed = 1;
        }),
        red("l1_claimed", |dry_run| {
            dry_run.l1_claimed = true;
        }),
        red("l2_claimed", |dry_run| {
            dry_run.l2_claimed = true;
        }),
        red("product_green_claimed", |dry_run| {
            dry_run.product_green_claimed = true;
        }),
        red("hidden_route_authority_claimed", |dry_run| {
            dry_run.hidden_route_authority_claimed = true;
        }),
    ]
}

fn red(name: &str, mutate: impl FnOnce(&mut JcsFixtureWriterFailClosedDryRun)) -> (String, bool) {
    let mut dry_run = JcsFixtureWriterFailClosedDryRun::canonical().expect("canonical dry-run");
    mutate(&mut dry_run);
    let rejected = matches!(
        dry_run.validate(),
        Err(JcsFixtureWriterDryRunError::WrongValue(_))
            | Err(JcsFixtureWriterDryRunError::SourceCardBroken)
            | Err(JcsFixtureWriterDryRunError::PolicyBroken)
            | Err(JcsFixtureWriterDryRunError::PlannedFragmentBroken)
            | Err(JcsFixtureWriterDryRunError::ByteOrCommandLeak)
            | Err(JcsFixtureWriterDryRunError::MaterializationBoundaryBroken)
            | Err(JcsFixtureWriterDryRunError::PromotionClaim)
    );
    (name.to_string(), rejected)
}
