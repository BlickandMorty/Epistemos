//! `falsify_gemma_qat_e2b_first_token_runtime_artifact_review_gate`
//!
//! Metadata-only review contract for the first future owner-approved Gemma E2B
//! GGUF/llama.cpp first-token runtime artifact. This does not read that future
//! artifact, run llama.cpp, open a model path, retain raw token text, or promote
//! Gemma to a product route.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_gemma_qat_e2b_first_token_runtime_artifact_rejection_policies,
    required_gemma_qat_e2b_first_token_runtime_artifact_review_fields,
    GemmaQatE2bFirstTokenRuntimeArtifactReviewGate,
    GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_ID,
    GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_NEXT_CURSOR,
    GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_ID;
const FIXTURE_ID: &str = "gemma_qat_e2b_first_token_runtime_artifact_review_gate_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_gemma_qat_e2b_first_token_runtime_artifact_review_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_first_token_runtime_artifact_review_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_owner_approved_runtime_replay_execution_probe/result.json";
const CREATED_AT_MS: u64 = 1_779_392_000_000;

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
        "{FALSIFIER_ID}: overall_pass={} review_fields={} artifact_bytes_read={} command_executed={} model_bytes_loaded={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_review_field_count"].value,
        artifact.measurements["runtime_artifact_bytes_read"].value,
        artifact.measurements["command_executed_count"].value,
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
    let gate = GemmaQatE2bFirstTokenRuntimeArtifactReviewGate::canonical(
        GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_UPSTREAM_REF,
    );
    gate.validate()?;
    let reversed = GemmaQatE2bFirstTokenRuntimeArtifactReviewGate {
        required_review_fields: gate.required_review_fields.iter().cloned().rev().collect(),
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
        ("upstream_execution_probe_pass", upstream_pass),
        (
            "upstream_execution_probe_ref_bound",
            gate.upstream_execution_probe_ref
                == GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_UPSTREAM_REF,
        ),
        (
            "single_e2b_gguf_review_lane_bound",
            gate.selected_model_id == "google/gemma-4-E2B-it-qat-q4_0-gguf"
                && gate.runtime_lane == agent_core::uas::GemmaFamilyRuntimeLane::GgufLlamaCpp
                && red_pass(&red_results, "wrong_model")
                && red_pass(&red_results, "wrong_runtime_lane"),
        ),
        (
            "review_fields_and_rejection_policies_bound",
            metrics.required_review_field_count
                == required_gemma_qat_e2b_first_token_runtime_artifact_review_fields().len() as u64
                && metrics.required_rejection_policy_count
                    == required_gemma_qat_e2b_first_token_runtime_artifact_rejection_policies()
                        .len() as u64
                && red_pass(&red_results, "missing_review_field")
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "owner_path_and_canonical_digest_required",
            gate.owner_approval_must_be_in_artifact
                && gate.owner_path_manifest_must_be_in_artifact
                && gate.canonical_path_digest_must_be_in_artifact
                && red_pass(&red_results, "owner_approval_missing")
                && red_pass(&red_results, "owner_manifest_missing")
                && red_pass(&red_results, "canonical_path_digest_missing"),
        ),
        (
            "privacy_raw_path_prompt_output_stdio_denied",
            !gate.raw_path_allowed
                && !gate.raw_prompt_allowed
                && !gate.raw_output_allowed
                && !gate.raw_stdout_allowed
                && !gate.raw_stderr_allowed
                && red_pass(&red_results, "raw_path_allowed")
                && red_pass(&red_results, "raw_prompt_allowed")
                && red_pass(&red_results, "raw_output_allowed")
                && red_pass(&red_results, "raw_stdout_allowed")
                && red_pass(&red_results, "raw_stderr_allowed"),
        ),
        (
            "first_token_redacted_and_not_quality_authority",
            gate.first_token_digest_required
                && !gate.first_token_raw_text_allowed
                && !gate.first_token_quality_authority
                && red_pass(&red_results, "first_token_digest_not_required")
                && red_pass(&red_results, "first_token_raw_text_allowed")
                && red_pass(&red_results, "first_token_quality_authority"),
        ),
        (
            "runtime_artifact_review_deferred",
            !gate.runtime_artifact_present
                && metrics.runtime_artifact_bytes_read == 0
                && metrics.accepted_runtime_artifact_count == 0
                && red_pass(&red_results, "runtime_artifact_present")
                && red_pass(&red_results, "runtime_artifact_bytes_read")
                && red_pass(&red_results, "accepted_runtime_artifact"),
        ),
        (
            "zero_command_model_runtime_provider_bytes",
            metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && metrics.model_file_opened_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "model_file_opened")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made"),
        ),
        (
            "cancellation_rollback_log_packet_abstention_bound",
            gate.timeout_bound
                && gate.cancellation_bound
                && gate.rollback_bound
                && gate.run_event_log_bound
                && gate.answer_packet_bound
                && gate.abstention_bound
                && red_pass(&red_results, "timeout_missing")
                && red_pass(&red_results, "cancellation_missing")
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
                && red_pass(&red_results, "gemma_default_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "larger_models_blocked_until_repreflight",
            !gate.larger_model_probe_allowed
                && red_pass(&red_results, "larger_model_probe_allowed"),
        ),
        (
            "gemma_first_token_artifact_review_gate_address_deterministic",
            gate.review_gate_address(CREATED_AT_MS) == reversed.review_gate_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_NEXT_CURSOR
                == "gemma_qat_e2b_owner_path_manifest_digest_gate",
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
            "required_review_field_count",
            metrics.required_review_field_count,
            "==",
            32,
            "fields",
        ),
        (
            "required_rejection_policy_count",
            metrics.required_rejection_policy_count,
            "==",
            33,
            "policies",
        ),
        (
            "runtime_artifact_present_count",
            metrics.runtime_artifact_present_count,
            "==",
            0,
            "artifacts",
        ),
        (
            "runtime_artifact_bytes_read",
            metrics.runtime_artifact_bytes_read,
            "==",
            0,
            "bytes",
        ),
        (
            "accepted_runtime_artifact_count",
            metrics.accepted_runtime_artifact_count,
            "==",
            0,
            "artifacts",
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
            "model_file_opened_count",
            metrics.model_file_opened_count,
            "==",
            0,
            "files",
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
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            ">=",
            36,
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
        "gemma_first_token_artifact_review_gate_address",
        &gate.review_gate_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_NEXT_CURSOR,
        "gemma_qat_e2b_owner_path_manifest_digest_gate",
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
        notes: "metadata-only F-GemmaQATE2BFirstTokenRuntimeArtifactReviewGate: consumes the owner-approved execution-probe envelope and defines the fail-closed review contract for a future E2B GGUF/llama.cpp first-token runtime artifact. It keeps Gemma as the exclusive near-term model ladder: E2B harness first, E4B next scale lane, 12B Pro flagship target, and larger 70B/custom cold-assembly work deferred until Gemma-class scaling requires it. The gate requires owner approval, owner path manifest, canonical path/model/llama.cpp/command/environment/redacted prompt/redacted token/memory/exit/rollback/RunEventLog/AnswerPacket/abstention proof fields; denies raw path/prompt/output/stdout/stderr/token retention, first-token quality authority, System G mutation, hidden authority, Gemma default promotion, larger-model bypass, live dense 70B, and SSD-as-RAM claims; reads zero runtime artifact bytes, arms zero commands, opens zero files, loads zero model/runtime/provider bytes, and makes no MAS/L2/L3/T4 user-facing claim.".to_string(),
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

fn red_fixture_results(
    gate: &GemmaQatE2bFirstTokenRuntimeArtifactReviewGate,
) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaQatE2bFirstTokenRuntimeArtifactReviewGate)>,
    )> = vec![
        (
            "wrong_model",
            Box::new(|g| g.selected_model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string()),
        ),
        (
            "wrong_runtime_lane",
            Box::new(|g| g.runtime_lane = agent_core::uas::GemmaFamilyRuntimeLane::LiteRtLm),
        ),
        (
            "missing_review_field",
            Box::new(|g| {
                g.required_review_fields.pop();
            }),
        ),
        (
            "missing_rejection_policy",
            Box::new(|g| {
                g.required_rejection_policies.pop();
            }),
        ),
        (
            "owner_approval_missing",
            Box::new(|g| g.owner_approval_must_be_in_artifact = false),
        ),
        (
            "owner_manifest_missing",
            Box::new(|g| g.owner_path_manifest_must_be_in_artifact = false),
        ),
        (
            "canonical_path_digest_missing",
            Box::new(|g| g.canonical_path_digest_must_be_in_artifact = false),
        ),
        ("raw_path_allowed", Box::new(|g| g.raw_path_allowed = true)),
        (
            "raw_prompt_allowed",
            Box::new(|g| g.raw_prompt_allowed = true),
        ),
        (
            "raw_output_allowed",
            Box::new(|g| g.raw_output_allowed = true),
        ),
        (
            "raw_stdout_allowed",
            Box::new(|g| g.raw_stdout_allowed = true),
        ),
        (
            "raw_stderr_allowed",
            Box::new(|g| g.raw_stderr_allowed = true),
        ),
        (
            "first_token_digest_not_required",
            Box::new(|g| g.first_token_digest_required = false),
        ),
        (
            "first_token_raw_text_allowed",
            Box::new(|g| g.first_token_raw_text_allowed = true),
        ),
        (
            "first_token_quality_authority",
            Box::new(|g| g.first_token_quality_authority = true),
        ),
        (
            "runtime_artifact_present",
            Box::new(|g| g.runtime_artifact_present = true),
        ),
        (
            "runtime_artifact_bytes_read",
            Box::new(|g| g.runtime_artifact_bytes_read = 1),
        ),
        (
            "accepted_runtime_artifact",
            Box::new(|g| g.accepted_runtime_artifact_count = 1),
        ),
        ("command_armed", Box::new(|g| g.command_armed = true)),
        ("command_executed", Box::new(|g| g.command_executed = true)),
        (
            "model_file_opened",
            Box::new(|g| g.model_file_opened = true),
        ),
        ("model_bytes_loaded", Box::new(|g| g.model_bytes_loaded = 1)),
        (
            "runtime_bytes_loaded",
            Box::new(|g| g.runtime_bytes_loaded = 1),
        ),
        (
            "provider_calls_made",
            Box::new(|g| g.provider_calls_made = 1),
        ),
        ("timeout_missing", Box::new(|g| g.timeout_bound = false)),
        (
            "cancellation_missing",
            Box::new(|g| g.cancellation_bound = false),
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
            "gemma_default_claim",
            Box::new(|g| g.live_gemma_default_claim = true),
        ),
        (
            "live_dense_70b_claim",
            Box::new(|g| g.live_dense_70b_claim = true),
        ),
        ("ssd_as_ram_claim", Box::new(|g| g.ssd_as_ram_claim = true)),
        (
            "larger_model_probe_allowed",
            Box::new(|g| g.larger_model_probe_allowed = true),
        ),
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
    for axis in GEMMA_QAT_E2B_FIRST_TOKEN_RUNTIME_ARTIFACT_REVIEW_GATE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
