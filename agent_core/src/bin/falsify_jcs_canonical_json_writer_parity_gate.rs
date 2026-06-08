//! `falsify_jcs_canonical_json_writer_parity_gate`.
//!
//! Metadata-only witness for `F-JcsCanonicalJsonWriterParityGate`. It binds
//! JCS/RFC 8785 parity requirements before fixture materialization and keeps
//! materialization blocked until number and UTF-16 sort oracles exist.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339,
    write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    JcsCanonicalJsonWriterParityError, JcsCanonicalJsonWriterParityGate,
    JcsCanonicalJsonWriterParityGateWitness, JcsCanonicalJsonWriterParityStatus,
    JCS_CANONICAL_JSON_WRITER_PARITY_GATE_CURSOR, JCS_CANONICAL_JSON_WRITER_PARITY_GATE_ID,
    JCS_CANONICAL_JSON_WRITER_PARITY_GATE_NEXT_CURSOR, SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_ID,
};

const FIXTURE_ID: &str = "jcs_canonical_json_writer_parity_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_jcs_canonical_json_writer_parity_gate.sh";
const RESULT: &str = "artifacts/falsifiers/jcs_canonical_json_writer_parity_gate/result.json";
const RED_FIXTURE_FLOOR: u64 = 24;
const GUARD_PRODUCT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";

fn main() -> std::process::ExitCode {
    let artifact = match build_artifact() {
        Ok(artifact) => artifact,
        Err(error) => {
            eprintln!("failed to build {JCS_CANONICAL_JSON_WRITER_PARITY_GATE_ID}: {error}");
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
        "{}: overall_pass={} positive_samples={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        JCS_CANONICAL_JSON_WRITER_PARITY_GATE_ID,
        artifact.overall_pass,
        artifact.measurements["positive_sample_count"].value,
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
    let witness = JcsCanonicalJsonWriterParityGateWitness::new()?;
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
        witness.falsifier_id == JCS_CANONICAL_JSON_WRITER_PARITY_GATE_ID
            && witness.cursor == JCS_CANONICAL_JSON_WRITER_PARITY_GATE_CURSOR
            && witness.next_cursor == JCS_CANONICAL_JSON_WRITER_PARITY_GATE_NEXT_CURSOR
            && witness.metadata_only
            && witness.product_promotion_blocked,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "upstream_materialization_gate_bound",
        witness.spec.upstream_falsifier_id == SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_ID
            && witness
                .spec
                .upstream_materialization_gate_address
                .starts_with("sha256:")
            && red_pass(&red_results, "upstream_address_drift"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "primary_source_card_bound",
        witness.spec.source_card.rfc_8785_url == "https://www.rfc-editor.org/rfc/rfc8785"
            && witness.spec.source_card.json_schema_url == "https://json-schema.org/specification"
            && red_pass(&red_results, "wrong_rfc_source")
            && red_pass(&red_results, "missing_local_writer_ref"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "jcs_policy_requirements_bound",
        witness.spec.policy.i_json_required
            && witness.spec.policy.duplicate_key_rejection_required
            && witness.spec.policy.invalid_unicode_rejection_required
            && witness.spec.policy.nan_infinity_rejection_required
            && witness.spec.policy.no_whitespace_output_required
            && witness.spec.policy.recursive_object_sort_required
            && witness.spec.policy.array_order_preservation_required
            && witness.spec.policy.utf8_output_required
            && witness.spec.policy.stable_sha256_digest_map_required
            && witness.spec.policy.draft_2020_12_schema_required
            && red_pass(&red_results, "duplicate_key_requirement_disabled")
            && red_pass(&red_results, "invalid_unicode_requirement_disabled")
            && red_pass(&red_results, "nan_infinity_requirement_disabled")
            && red_pass(&red_results, "whitespace_allowed")
            && red_pass(&red_results, "recursive_sort_disabled")
            && red_pass(&red_results, "array_order_not_preserved")
            && red_pass(&red_results, "utf8_output_disabled")
            && red_pass(&red_results, "digest_map_disabled")
            && red_pass(&red_results, "draft_2020_12_disabled"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_writer_gap_bound",
        witness.spec.policy.serde_json_to_string_not_full_jcs
            && witness.spec.policy.tri_fusion_writer_not_fixture_authority
            && witness.spec.policy.ecmascript_number_oracle_required
            && witness.spec.policy.utf16_property_sort_oracle_required
            && witness.spec.status
                == JcsCanonicalJsonWriterParityStatus::MaterializationBlockedUntilFullParity
            && red_pass(&red_results, "serde_json_claimed_full_jcs")
            && red_pass(&red_results, "trifusion_claimed_fixture_authority")
            && red_pass(&red_results, "number_oracle_not_required")
            && red_pass(&red_results, "utf16_sort_oracle_not_required")
            && red_pass(&red_results, "status_unblocked"),
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "positive_sample_count",
        witness.metrics.positive_sample_count,
        16,
        "samples",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "blocked_oracle_count",
        witness.metrics.blocker_count,
        2,
        "oracles",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sample_matrix_bound",
        witness.metrics.red_fixture_count == 6
            && red_pass(&red_results, "literal_sample_count_drift")
            && red_pass(&red_results, "duplicate_red_fixture_count_drift")
            && red_pass(&red_results, "number_blocker_missing"),
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
        "upstream_materialization_gate_address",
        &witness.spec.upstream_materialization_gate_address,
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        JCS_CANONICAL_JSON_WRITER_PARITY_GATE_NEXT_CURSOR,
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "guard_owned_product_cursor_preserved",
        GUARD_PRODUCT_CURSOR,
    );

    Ok(ArtifactBuilder {
        falsifier_id: JCS_CANONICAL_JSON_WRITER_PARITY_GATE_ID.to_string(),
        artifact_kind: ArtifactKind::PrimaryWitness,
        command: COMMAND.to_string(),
        commit_sha: current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: FallbackTier::Primary,
        anomalies: Vec::new(),
        notes: "Metadata-only T1/L1 side-ladder witness for the JCS canonical JSON writer parity gate. It consumes the synthetic payload materialization gate, binds RFC 8785/JCS and JSON Schema source requirements, records local serde_json/TriFusion writer gaps, blocks fixture materialization until ECMAScript number and UTF-16 sort oracle proof exists, writes zero fixture files, opens zero model/runtime/provider/cache/index bytes, arms zero commands, preserves the guard-owned small-model product cursor, and makes no L2/L3/T4/T5 or large-local-model capability claim.".to_string(),
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
            gate.upstream_materialization_gate_address =
                "sha256:0000000000000000000000000000000000000000000000000000000000000000"
                    .to_string();
        }),
        red("wrong_rfc_source", |gate| {
            gate.source_card.rfc_8785_url = "https://example.invalid/rfc8785".to_string();
        }),
        red("missing_local_writer_ref", |gate| {
            gate.source_card.tri_fusion_writer_ref = "".to_string();
        }),
        red("duplicate_key_requirement_disabled", |gate| {
            gate.policy.duplicate_key_rejection_required = false;
        }),
        red("invalid_unicode_requirement_disabled", |gate| {
            gate.policy.invalid_unicode_rejection_required = false;
        }),
        red("nan_infinity_requirement_disabled", |gate| {
            gate.policy.nan_infinity_rejection_required = false;
        }),
        red("whitespace_allowed", |gate| {
            gate.policy.no_whitespace_output_required = false;
        }),
        red("recursive_sort_disabled", |gate| {
            gate.policy.recursive_object_sort_required = false;
        }),
        red("array_order_not_preserved", |gate| {
            gate.policy.array_order_preservation_required = false;
        }),
        red("utf8_output_disabled", |gate| {
            gate.policy.utf8_output_required = false;
        }),
        red("digest_map_disabled", |gate| {
            gate.policy.stable_sha256_digest_map_required = false;
        }),
        red("draft_2020_12_disabled", |gate| {
            gate.policy.draft_2020_12_schema_required = false;
        }),
        red("serde_json_claimed_full_jcs", |gate| {
            gate.policy.serde_json_to_string_not_full_jcs = false;
        }),
        red("trifusion_claimed_fixture_authority", |gate| {
            gate.policy.tri_fusion_writer_not_fixture_authority = false;
        }),
        red("number_oracle_not_required", |gate| {
            gate.policy.ecmascript_number_oracle_required = false;
        }),
        red("utf16_sort_oracle_not_required", |gate| {
            gate.policy.utf16_property_sort_oracle_required = false;
        }),
        red("status_unblocked", |gate| {
            gate.materialization_allowed = true;
        }),
        red("literal_sample_count_drift", |gate| {
            gate.sample_matrix.literal_sample_count = 2;
        }),
        red("duplicate_red_fixture_count_drift", |gate| {
            gate.sample_matrix.duplicate_key_red_fixture_count = 1;
        }),
        red("number_blocker_missing", |gate| {
            gate.sample_matrix.number_oracle_blocker_count = 0;
        }),
        red("materialization_allowed", |gate| {
            gate.materialization_allowed = true;
        }),
        red("metadata_boundary_disabled", |gate| {
            gate.metadata_only = false;
        }),
        red("fixture_file_written", |gate| {
            gate.byte_ledger.fixture_files_written = 1;
        }),
        red("schema_file_written", |gate| {
            gate.byte_ledger.schema_files_written = 1;
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

fn red(name: &str, mutate: impl FnOnce(&mut JcsCanonicalJsonWriterParityGate)) -> (String, bool) {
    let mut gate = JcsCanonicalJsonWriterParityGate::canonical().expect("canonical gate");
    mutate(&mut gate);
    let rejected = matches!(
        gate.validate(),
        Err(JcsCanonicalJsonWriterParityError::WrongValue(_))
            | Err(JcsCanonicalJsonWriterParityError::FieldHasSurroundingWhitespace(_))
            | Err(JcsCanonicalJsonWriterParityError::FieldContainsControlCharacter(_))
            | Err(JcsCanonicalJsonWriterParityError::MissingField(_))
            | Err(JcsCanonicalJsonWriterParityError::PolicyBroken)
            | Err(JcsCanonicalJsonWriterParityError::SampleMatrixBroken)
            | Err(JcsCanonicalJsonWriterParityError::ByteOrCommandLeak)
            | Err(JcsCanonicalJsonWriterParityError::MaterializationBoundaryBroken)
            | Err(JcsCanonicalJsonWriterParityError::PromotionClaim)
    );
    (name.to_string(), rejected)
}
