//! `falsify_jcs_number_and_utf16_sort_oracle_probe`.
//!
//! Metadata-only witness for `F-JcsNumberAndUtf16SortOracleProbe`. It pins the
//! RFC 8785 number and UTF-16 sort samples while keeping fixture writer bytes
//! blocked.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    JcsNumberAndUtf16SortOracleProbe, JcsNumberAndUtf16SortOracleWitness,
    JcsNumberUtf16OracleError, JcsNumberUtf16OracleStatus,
    JCS_CANONICAL_JSON_WRITER_PARITY_GATE_ID, JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_CURSOR,
    JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_ID, JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_NEXT_CURSOR,
};

const FIXTURE_ID: &str = "jcs_number_and_utf16_sort_oracle_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_jcs_number_and_utf16_sort_oracle_probe.sh";
const RESULT: &str = "artifacts/falsifiers/jcs_number_and_utf16_sort_oracle_probe/result.json";
const RED_FIXTURE_FLOOR: u64 = 22;
const GUARD_PRODUCT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";

fn main() -> std::process::ExitCode {
    let artifact = match build_artifact() {
        Ok(artifact) => artifact,
        Err(error) => {
            eprintln!("failed to build {JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_ID}: {error}");
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
        "{}: overall_pass={} number_samples={} utf16_matches={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_ID,
        artifact.overall_pass,
        artifact.measurements["number_sample_count"].value,
        artifact.measurements["utf16_sort_match_count"].value,
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
    let witness = JcsNumberAndUtf16SortOracleWitness::new()?;
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
        witness.falsifier_id == JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_ID
            && witness.cursor == JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_CURSOR
            && witness.next_cursor == JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_NEXT_CURSOR
            && witness.metadata_only
            && witness.product_promotion_blocked,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_jcs_parity_gate_bound",
        witness.spec.upstream_falsifier_id == JCS_CANONICAL_JSON_WRITER_PARITY_GATE_ID
            && witness
                .spec
                .upstream_jcs_parity_address
                .starts_with("sha256:")
            && red_pass(&red_results, "upstream_address_drift"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rfc8785_source_card_bound",
        witness.spec.source_card.rfc_8785_url == "https://www.rfc-editor.org/rfc/rfc8785"
            && witness.spec.source_card.appendix_b_number_table_bound
            && witness.spec.source_card.section_3_2_3_utf16_sort_bound
            && witness
                .spec
                .source_card
                .node_json_stringify_research_observed
            && !witness.spec.source_card.local_writer_implementation_claimed
            && red_pass(&red_results, "wrong_rfc_source")
            && red_pass(&red_results, "number_table_source_disabled")
            && red_pass(&red_results, "utf16_source_disabled")
            && red_pass(&red_results, "local_writer_claimed"),
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "number_sample_count",
        witness.metrics.number_sample_count,
        26,
        "samples",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "number_sample_table_bound",
        witness.metrics.finite_number_sample_count == 24
            && witness.metrics.rejected_number_sample_count == 2
            && witness.spec.number_sample_digest.starts_with("sha256:")
            && red_pass(&red_results, "number_expected_json_drift")
            && red_pass(&red_results, "number_disposition_drift")
            && red_pass(&red_results, "number_digest_drift"),
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "utf16_sort_match_count",
        witness.metrics.utf16_sort_match_count,
        7,
        "samples",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "utf16_sort_oracle_bound",
        witness.metrics.utf16_sort_sample_count == 7
            && witness.spec.utf16_sort_digest.starts_with("sha256:")
            && red_pass(&red_results, "utf16_rank_drift")
            && red_pass(&red_results, "utf16_digest_drift"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "oracle_policy_bound",
        witness.spec.policy.ieee754_hex_required
            && witness.spec.policy.ecmascript_expected_json_required
            && witness.spec.policy.nan_infinity_rejection_required
            && witness.spec.policy.minus_zero_normalization_required
            && witness.spec.policy.utf16_code_unit_sort_required
            && witness.spec.policy.utf8_sort_not_authority
            && witness.spec.policy.locale_sort_not_authority
            && witness
                .spec
                .policy
                .materialization_blocked_until_writer_dry_run
            && witness.spec.status == JcsNumberUtf16OracleStatus::OraclePinnedWriterStillBlocked
            && red_pass(&red_results, "ieee754_hex_disabled")
            && red_pass(&red_results, "ecmascript_expected_disabled")
            && red_pass(&red_results, "nan_rejection_disabled")
            && red_pass(&red_results, "minus_zero_disabled")
            && red_pass(&red_results, "utf16_sort_disabled")
            && red_pass(&red_results, "utf8_sort_claimed_authority")
            && red_pass(&red_results, "locale_sort_claimed_authority")
            && red_pass(&red_results, "writer_dry_run_not_required"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "materialization_blocked",
        !witness.spec.materialization_allowed
            && witness.spec.metadata_only
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
        "upstream_jcs_parity_address",
        &witness.spec.upstream_jcs_parity_address,
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_NEXT_CURSOR,
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "guard_owned_product_cursor_preserved",
        GUARD_PRODUCT_CURSOR,
    );

    Ok(ArtifactBuilder {
        falsifier_id: JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: Vec::new(),
        notes: "Metadata-only T1/L1 side-ladder witness for the JCS number and UTF-16 sort oracle. It consumes the JCS parity gate, pins all 26 RFC 8785 Appendix B number rows, proves the 7-row Section 3.2.3 UTF-16 property-sort sample locally, blocks fixture writer/materialization until a later fail-closed dry run, writes zero fixture files, opens zero model/runtime/provider/cache/index bytes, arms zero commands, preserves the guard-owned small-model product cursor, and makes no L2/L3/T4/T5 or large-local-model capability claim.".to_string(),
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
        red("upstream_address_drift", |probe| {
            probe.upstream_jcs_parity_address =
                "sha256:0000000000000000000000000000000000000000000000000000000000000000"
                    .to_string();
        }),
        red("wrong_rfc_source", |probe| {
            probe.source_card.rfc_8785_url = "https://example.invalid/rfc8785".to_string();
        }),
        red("number_table_source_disabled", |probe| {
            probe.source_card.appendix_b_number_table_bound = false;
        }),
        red("utf16_source_disabled", |probe| {
            probe.source_card.section_3_2_3_utf16_sort_bound = false;
        }),
        red("local_writer_claimed", |probe| {
            probe.source_card.local_writer_implementation_claimed = true;
        }),
        red("number_expected_json_drift", |probe| {
            probe.number_samples[12].expected_json = "1e23".to_string();
        }),
        red("number_disposition_drift", |probe| {
            probe.number_samples[9].disposition = "finite".to_string();
        }),
        red("number_digest_drift", |probe| {
            probe.number_sample_digest =
                "sha256:0000000000000000000000000000000000000000000000000000000000000000"
                    .to_string();
        }),
        red("utf16_rank_drift", |probe| {
            probe.utf16_sort_samples[0].expected_rank = 2;
        }),
        red("utf16_digest_drift", |probe| {
            probe.utf16_sort_digest =
                "sha256:0000000000000000000000000000000000000000000000000000000000000000"
                    .to_string();
        }),
        red("ieee754_hex_disabled", |probe| {
            probe.policy.ieee754_hex_required = false;
        }),
        red("ecmascript_expected_disabled", |probe| {
            probe.policy.ecmascript_expected_json_required = false;
        }),
        red("nan_rejection_disabled", |probe| {
            probe.policy.nan_infinity_rejection_required = false;
        }),
        red("minus_zero_disabled", |probe| {
            probe.policy.minus_zero_normalization_required = false;
        }),
        red("utf16_sort_disabled", |probe| {
            probe.policy.utf16_code_unit_sort_required = false;
        }),
        red("utf8_sort_claimed_authority", |probe| {
            probe.policy.utf8_sort_not_authority = false;
        }),
        red("locale_sort_claimed_authority", |probe| {
            probe.policy.locale_sort_not_authority = false;
        }),
        red("writer_dry_run_not_required", |probe| {
            probe.policy.materialization_blocked_until_writer_dry_run = false;
        }),
        red("materialization_allowed", |probe| {
            probe.materialization_allowed = true;
        }),
        red("metadata_boundary_disabled", |probe| {
            probe.metadata_only = false;
        }),
        red("fixture_file_written", |probe| {
            probe.byte_ledger.fixture_files_written = 1;
        }),
        red("schema_file_written", |probe| {
            probe.byte_ledger.schema_files_written = 1;
        }),
        red("runtime_bytes_nonzero", |probe| {
            probe.byte_ledger.model_runtime_bytes_loaded = 1;
        }),
        red("provider_calls_nonzero", |probe| {
            probe.byte_ledger.provider_calls_made = 1;
        }),
        red("cache_index_bytes_nonzero", |probe| {
            probe.byte_ledger.cache_index_bytes_opened = 1;
        }),
        red("command_armed", |probe| {
            probe.byte_ledger.commands_armed = 1;
        }),
        red("l1_claimed", |probe| {
            probe.l1_claimed = true;
        }),
        red("l2_claimed", |probe| {
            probe.l2_claimed = true;
        }),
        red("product_green_claimed", |probe| {
            probe.product_green_claimed = true;
        }),
        red("hidden_route_authority_claimed", |probe| {
            probe.hidden_route_authority_claimed = true;
        }),
    ]
}

fn red(name: &str, mutate: impl FnOnce(&mut JcsNumberAndUtf16SortOracleProbe)) -> (String, bool) {
    let mut probe = JcsNumberAndUtf16SortOracleProbe::canonical().expect("canonical probe");
    mutate(&mut probe);
    let rejected = matches!(
        probe.validate(),
        Err(JcsNumberUtf16OracleError::WrongValue(_))
            | Err(JcsNumberUtf16OracleError::SourceCardBroken)
            | Err(JcsNumberUtf16OracleError::PolicyBroken)
            | Err(JcsNumberUtf16OracleError::NumberSampleTableBroken)
            | Err(JcsNumberUtf16OracleError::Utf16SortTableBroken)
            | Err(JcsNumberUtf16OracleError::ByteOrCommandLeak)
            | Err(JcsNumberUtf16OracleError::MaterializationBoundaryBroken)
            | Err(JcsNumberUtf16OracleError::PromotionClaim)
    );
    (name.to_string(), rejected)
}
