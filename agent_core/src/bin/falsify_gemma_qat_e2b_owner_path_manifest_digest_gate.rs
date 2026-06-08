//! `falsify_gemma_qat_e2b_owner_path_manifest_digest_gate`
//!
//! Metadata-only digest contract for a future owner-approved Gemma E2B GGUF
//! local path manifest. It does not read an owner manifest, retain raw paths,
//! canonicalize paths, stat/hash files, arm commands, load model/runtime bytes,
//! or promote Gemma into System G.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_gemma_qat_e2b_owner_path_manifest_digest_fields,
    required_gemma_qat_e2b_owner_path_manifest_rejection_policies,
    GemmaQatE2bOwnerPathManifestDigestGate, GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
    GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_ID,
    GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_NEXT_CURSOR,
    GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_ID;
const FIXTURE_ID: &str = "gemma_qat_e2b_owner_path_manifest_digest_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_qat_e2b_owner_path_manifest_digest_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_owner_path_manifest_digest_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_first_token_runtime_artifact_review_gate/result.json";
const CREATED_AT_MS: u64 = 1_779_395_000_000;

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
        "{FALSIFIER_ID}: overall_pass={} digest_fields={} owner_manifest_bytes_read={} file_hash_attempts={} model_bytes_loaded={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_manifest_digest_field_count"].value,
        artifact.measurements["owner_manifest_bytes_read"].value,
        artifact.measurements["file_hash_attempts"].value,
        artifact.measurements["model_bytes_loaded"].value,
        artifact.measurements["red_fixture_rejection_count"].value,
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let upstream_pass = upstream_gate_pass()?;
    let gate = GemmaQatE2bOwnerPathManifestDigestGate::canonical(
        GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_UPSTREAM_REF,
    );
    gate.validate()?;
    let reversed = GemmaQatE2bOwnerPathManifestDigestGate {
        required_manifest_digest_fields: gate
            .required_manifest_digest_fields
            .iter()
            .cloned()
            .rev()
            .collect(),
        required_rejection_policies: gate
            .required_rejection_policies
            .iter()
            .cloned()
            .rev()
            .collect(),
        ..gate.clone()
    };
    reversed.validate()?;

    let metrics = gate.metrics();
    let red_results = red_fixture_results(&gate);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_first_token_review_gate_pass", upstream_pass),
        (
            "upstream_review_gate_ref_bound",
            gate.upstream_review_gate_ref
                == GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_UPSTREAM_REF,
        ),
        (
            "selected_e2b_source_file_bytes_bound",
            gate.selected_model_id == "google/gemma-4-E2B-it-qat-q4_0-gguf"
                && gate.required_filename == "gemma-4-E2B_q4_0-it.gguf"
                && gate.expected_file_size_bytes == GEMMA_QAT_E2B_EXPECTED_FILE_BYTES
                && gate.runtime_lane == agent_core::uas::GemmaFamilyRuntimeLane::GgufLlamaCpp
                && red_pass(&red_results, "wrong_model")
                && red_pass(&red_results, "wrong_filename")
                && red_pass(&red_results, "wrong_expected_file_bytes")
                && red_pass(&red_results, "wrong_source_revision"),
        ),
        (
            "owner_approval_phrase_digest_required",
            gate.owner_approval_phrase_digest_required
                && !gate.owner_approval_granted
                && red_pass(&red_results, "missing_owner_approval_phrase")
                && red_pass(&red_results, "owner_approval_granted"),
        ),
        (
            "owner_manifest_required_but_absent",
            gate.owner_manifest_required
                && !gate.owner_manifest_present
                && gate.owner_manifest_digest_required
                && metrics.owner_manifest_bytes_read == 0
                && red_pass(&red_results, "owner_manifest_not_required")
                && red_pass(&red_results, "owner_manifest_present")
                && red_pass(&red_results, "owner_manifest_digest_not_required")
                && red_pass(&red_results, "owner_manifest_bytes_read"),
        ),
        (
            "manifest_digest_fields_and_rejection_policies_bound",
            metrics.required_manifest_digest_field_count
                == required_gemma_qat_e2b_owner_path_manifest_digest_fields().len() as u64
                && metrics.required_rejection_policy_count
                    == required_gemma_qat_e2b_owner_path_manifest_rejection_policies().len() as u64
                && red_pass(&red_results, "missing_manifest_digest_field")
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "raw_and_canonical_path_bytes_denied",
            !gate.raw_path_retention_allowed
                && metrics.raw_path_bytes_stored == 0
                && gate.canonical_path_digest_required
                && metrics.canonical_path_bytes_stored == 0
                && red_pass(&red_results, "raw_path_allowed")
                && red_pass(&red_results, "raw_path_bytes_stored")
                && red_pass(&red_results, "canonical_path_digest_missing")
                && red_pass(&red_results, "canonical_path_bytes_stored"),
        ),
        (
            "path_file_and_symlink_actions_zero",
            gate.path_policy_fail_closed
                && metrics.path_canonicalization_attempts == 0
                && metrics.symlink_resolution_attempts == 0
                && metrics.file_stat_attempts == 0
                && metrics.file_hash_attempts == 0
                && metrics.model_file_opened_count == 0
                && red_pass(&red_results, "path_policy_open")
                && red_pass(&red_results, "path_canonicalization_attempt")
                && red_pass(&red_results, "symlink_resolution_attempt")
                && red_pass(&red_results, "file_stat_attempt")
                && red_pass(&red_results, "file_hash_attempt")
                && red_pass(&red_results, "model_file_opened"),
        ),
        (
            "llama_cpp_digest_deferred_to_next_gate",
            gate.llama_cpp_binary_digest_deferred
                && red_pass(&red_results, "llama_cpp_digest_not_deferred"),
        ),
        (
            "zero_command_model_runtime_provider_bytes",
            metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made"),
        ),
        (
            "rollback_log_packet_abstention_bound",
            gate.rollback_bound
                && gate.run_event_log_bound
                && gate.answer_packet_bound
                && gate.abstention_bound
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "abstention_missing"),
        ),
        (
            "no_route_or_system_g_mutation",
            !gate.route_mutation_allowed
                && !gate.system_g_mutation_allowed
                && red_pass(&red_results, "route_mutation")
                && red_pass(&red_results, "system_g_mutation"),
        ),
        (
            "no_hidden_authority_or_cloud_fallback",
            metrics.hidden_authority_count == 0
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "hidden_eidos_authority")
                && red_pass(&red_results, "hidden_lattice_authority")
                && red_pass(&red_results, "hidden_patternboost_authority")
                && red_pass(&red_results, "hidden_cloud_fallback"),
        ),
        (
            "no_mas_l2_l3_product_gemma_default_or_70b_claim",
            metrics.promotion_claim_count == 0
                && red_pass(&red_results, "mas_l2_l3_product_claim")
                && red_pass(&red_results, "product_route_green")
                && red_pass(&red_results, "gemma_default_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "e4b_12b_and_larger_models_blocked_until_repreflight",
            !gate.e4b_or_12b_bypass_allowed && red_pass(&red_results, "e4b_or_12b_bypass_allowed"),
        ),
        (
            "gemma_e2b_owner_path_manifest_digest_gate_address_deterministic",
            gate.digest_gate_address(CREATED_AT_MS) == reversed.digest_gate_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_NEXT_CURSOR
                == "gemma_qat_e2b_model_file_and_llama_cpp_digest_gate",
        ),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }

    for (name, value, operator, expected, unit) in [
        (
            "required_manifest_digest_field_count",
            metrics.required_manifest_digest_field_count,
            "==",
            26,
            "fields",
        ),
        (
            "required_rejection_policy_count",
            metrics.required_rejection_policy_count,
            "==",
            37,
            "policies",
        ),
        (
            "owner_approval_granted_count",
            metrics.owner_approval_granted_count,
            "==",
            0,
            "claims",
        ),
        (
            "owner_manifest_present_count",
            metrics.owner_manifest_present_count,
            "==",
            0,
            "manifests",
        ),
        (
            "owner_manifest_bytes_read",
            metrics.owner_manifest_bytes_read,
            "==",
            0,
            "bytes",
        ),
        (
            "raw_path_bytes_stored",
            metrics.raw_path_bytes_stored,
            "==",
            0,
            "bytes",
        ),
        (
            "canonical_path_bytes_stored",
            metrics.canonical_path_bytes_stored,
            "==",
            0,
            "bytes",
        ),
        (
            "path_canonicalization_attempts",
            metrics.path_canonicalization_attempts,
            "==",
            0,
            "attempts",
        ),
        (
            "symlink_resolution_attempts",
            metrics.symlink_resolution_attempts,
            "==",
            0,
            "attempts",
        ),
        (
            "file_stat_attempts",
            metrics.file_stat_attempts,
            "==",
            0,
            "attempts",
        ),
        (
            "file_hash_attempts",
            metrics.file_hash_attempts,
            "==",
            0,
            "attempts",
        ),
        (
            "model_file_opened_count",
            metrics.model_file_opened_count,
            "==",
            0,
            "files",
        ),
        (
            "command_armed_count",
            metrics.command_armed_count,
            "==",
            0,
            "commands",
        ),
        (
            "command_executed_count",
            metrics.command_executed_count,
            "==",
            0,
            "commands",
        ),
        (
            "model_bytes_loaded",
            metrics.model_bytes_loaded,
            "==",
            0,
            "bytes",
        ),
        (
            "runtime_bytes_loaded",
            metrics.runtime_bytes_loaded,
            "==",
            0,
            "bytes",
        ),
        (
            "provider_calls_made",
            metrics.provider_calls_made,
            "==",
            0,
            "calls",
        ),
        (
            "hidden_authority_count",
            metrics.hidden_authority_count,
            "==",
            0,
            "claims",
        ),
        (
            "promotion_claim_count",
            metrics.promotion_claim_count,
            "==",
            0,
            "claims",
        ),
        (
            "expected_file_size_bytes",
            gate.expected_file_size_bytes,
            "==",
            GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
            "bytes",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            ">=",
            45,
            "fixtures",
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            value,
            operator,
            expected,
            unit,
        );
    }

    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "gemma_e2b_owner_path_manifest_digest_gate_address",
        &gate.digest_gate_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_NEXT_CURSOR,
        "gemma_qat_e2b_model_file_and_llama_cpp_digest_gate",
    );

    assert_axis_coverage(&measurements);

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
        notes: "metadata-only F-GemmaQATE2BOwnerPathManifestDigestGate: consumes the E2B first-token artifact review gate and binds the future owner-approved local path manifest to digest-only proof. It locks the selected E2B GGUF model id, source revision, required filename, expected file bytes, owner approval phrase digest, owner manifest digest, canonical path digest, path policy, rollback, RunEventLog, AnswerPacket, and abstention while keeping owner approval pending. It stores zero raw path bytes, zero canonical path bytes, reads zero owner-manifest/model/runtime/provider bytes, performs zero canonicalization/stat/hash/symlink actions, arms zero commands, executes zero commands, and makes no MAS/L2/L3/T4/user-facing, Gemma-default, E4B/12B bypass, live-70B, or SSD-as-RAM claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_gate_pass() -> Result<bool, Box<dyn std::error::Error>> {
    if !Path::new(UPSTREAM_RESULT).exists() {
        return Ok(false);
    }
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(UPSTREAM_RESULT)?)?;
    Ok(value
        .get("overall_pass")
        .and_then(|v| v.as_bool())
        .unwrap_or(false))
}

fn red_fixture_results(gate: &GemmaQatE2bOwnerPathManifestDigestGate) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaQatE2bOwnerPathManifestDigestGate)>,
    )> = vec![
        (
            "wrong_model",
            Box::new(|g| g.selected_model_id = "google/gemma-4-E4B-it-qat-q4_0-gguf".to_string()),
        ),
        (
            "wrong_filename",
            Box::new(|g| g.required_filename = "gemma-4-E4B_q4_0-it.gguf".to_string()),
        ),
        (
            "wrong_expected_file_bytes",
            Box::new(|g| g.expected_file_size_bytes += 1),
        ),
        (
            "wrong_source_revision",
            Box::new(|g| g.source_revision = "branch-main".to_string()),
        ),
        (
            "missing_owner_approval_phrase",
            Box::new(|g| g.owner_approval_phrase_digest_required = false),
        ),
        (
            "bad_owner_approval_phrase",
            Box::new(|g| g.owner_approval_phrase_visible = "APPROVE_GEMMA_12B_NOW".to_string()),
        ),
        (
            "owner_approval_granted",
            Box::new(|g| g.owner_approval_granted = true),
        ),
        (
            "owner_manifest_not_required",
            Box::new(|g| g.owner_manifest_required = false),
        ),
        (
            "owner_manifest_present",
            Box::new(|g| g.owner_manifest_present = true),
        ),
        (
            "owner_manifest_digest_not_required",
            Box::new(|g| g.owner_manifest_digest_required = false),
        ),
        (
            "owner_manifest_bytes_read",
            Box::new(|g| g.owner_manifest_bytes_read = 1),
        ),
        (
            "missing_manifest_digest_field",
            Box::new(|g| {
                g.required_manifest_digest_fields.pop();
            }),
        ),
        (
            "missing_rejection_policy",
            Box::new(|g| {
                g.required_rejection_policies.pop();
            }),
        ),
        (
            "raw_path_allowed",
            Box::new(|g| g.raw_path_retention_allowed = true),
        ),
        (
            "raw_path_bytes_stored",
            Box::new(|g| g.raw_path_bytes_stored = 1),
        ),
        (
            "canonical_path_digest_missing",
            Box::new(|g| g.canonical_path_digest_required = false),
        ),
        (
            "canonical_path_bytes_stored",
            Box::new(|g| g.canonical_path_bytes_stored = 1),
        ),
        (
            "path_policy_open",
            Box::new(|g| g.path_policy_fail_closed = false),
        ),
        (
            "path_canonicalization_attempt",
            Box::new(|g| g.path_canonicalization_attempts = 1),
        ),
        (
            "symlink_resolution_attempt",
            Box::new(|g| g.symlink_resolution_attempts = 1),
        ),
        ("file_stat_attempt", Box::new(|g| g.file_stat_attempts = 1)),
        ("file_hash_attempt", Box::new(|g| g.file_hash_attempts = 1)),
        (
            "model_file_opened",
            Box::new(|g| g.model_file_opened = true),
        ),
        (
            "llama_cpp_digest_not_deferred",
            Box::new(|g| g.llama_cpp_binary_digest_deferred = false),
        ),
        ("command_armed", Box::new(|g| g.command_armed = true)),
        ("command_executed", Box::new(|g| g.command_executed = true)),
        ("model_bytes_loaded", Box::new(|g| g.model_bytes_loaded = 1)),
        (
            "runtime_bytes_loaded",
            Box::new(|g| g.runtime_bytes_loaded = 1),
        ),
        (
            "provider_calls_made",
            Box::new(|g| g.provider_calls_made = 1),
        ),
        ("rollback_missing", Box::new(|g| g.rollback_bound = false)),
        (
            "run_event_log_missing",
            Box::new(|g| g.run_event_log_bound = false),
        ),
        (
            "answer_packet_missing",
            Box::new(|g| g.answer_packet_bound = false),
        ),
        (
            "abstention_missing",
            Box::new(|g| g.abstention_bound = false),
        ),
        (
            "route_mutation",
            Box::new(|g| g.route_mutation_allowed = true),
        ),
        (
            "system_g_mutation",
            Box::new(|g| g.system_g_mutation_allowed = true),
        ),
        (
            "hidden_route_authority",
            Box::new(|g| g.hidden_route_authority = true),
        ),
        (
            "hidden_eidos_authority",
            Box::new(|g| g.hidden_eidos_authority = true),
        ),
        (
            "hidden_lattice_authority",
            Box::new(|g| g.hidden_lattice_authority = true),
        ),
        (
            "hidden_patternboost_authority",
            Box::new(|g| g.hidden_patternboost_authority = true),
        ),
        (
            "hidden_cloud_fallback",
            Box::new(|g| g.hidden_cloud_fallback = true),
        ),
        (
            "mas_l2_l3_product_claim",
            Box::new(|g| {
                g.mas_promoted = true;
                g.l2_capability_effect = true;
                g.l3_wrv_effect = true;
            }),
        ),
        (
            "product_route_green",
            Box::new(|g| g.product_route_green = true),
        ),
        (
            "gemma_default_claim",
            Box::new(|g| g.live_gemma_default_claim = true),
        ),
        (
            "e4b_or_12b_bypass_allowed",
            Box::new(|g| g.e4b_or_12b_bypass_allowed = true),
        ),
        (
            "live_dense_70b_claim",
            Box::new(|g| g.live_dense_70b_claim = true),
        ),
        ("ssd_as_ram_claim", Box::new(|g| g.ssd_as_ram_claim = true)),
    ];
    cases
        .into_iter()
        .map(|(name, mutate)| {
            let mut mutated = gate.clone();
            mutate(&mut mutated);
            (name, mutated.validate().is_err())
        })
        .collect()
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(case, _)| *case == name)
        .map(|(_, passed)| *passed)
        .unwrap_or(false)
}

fn add_text_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: &str,
    expected: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(value.to_string()),
            unit: "text".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::String(expected.to_string()),
            unit: "text".to_string(),
        },
    );
    pass_per_axis.insert(
        name.to_string(),
        if expected == "non_empty" {
            !value.trim().is_empty()
        } else {
            value == expected
        },
    );
}

fn assert_axis_coverage(measurements: &BTreeMap<String, Measurement>) {
    for axis in GEMMA_QAT_E2B_OWNER_PATH_MANIFEST_DIGEST_GATE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
