//! `falsify_gemma_qat_e2b_model_file_and_llama_cpp_digest_gate`
//!
//! Metadata-only digest requirement gate for the future owner-approved Gemma
//! E2B GGUF/llama.cpp probe. It does not hash local files, inspect llama.cpp,
//! arm commands, run inference, or promote Gemma as a product route.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaQatE2bModelFileAndLlamaCppDigestGate, GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
    GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_ID,
    GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_NEXT_CURSOR,
    GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_UPSTREAM_REF,
    GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH,
};

const FALSIFIER_ID: &str = GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_ID;
const FIXTURE_ID: &str = "gemma_qat_e2b_model_file_and_llama_cpp_digest_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_qat_e2b_model_file_and_llama_cpp_digest_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_model_file_and_llama_cpp_digest_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_owner_path_manifest_digest_gate/result.json";
const CREATED_AT_MS: u64 = 1_779_398_000_000;

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
        "{FALSIFIER_ID}: overall_pass={} digest_fields={} model_file_opened={} llama_cpp_binary_opened={} command_executed={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_digest_field_count"].value,
        artifact.measurements["model_file_opened_count"].value,
        artifact.measurements["llama_cpp_binary_opened_count"].value,
        artifact.measurements["command_executed_count"].value,
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
    let gate = GemmaQatE2bModelFileAndLlamaCppDigestGate::canonical(
        GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_UPSTREAM_REF,
    );
    gate.validate()?;
    let reversed = GemmaQatE2bModelFileAndLlamaCppDigestGate {
        required_digest_fields: gate.required_digest_fields.iter().cloned().rev().collect(),
        required_rejection_policies: gate
            .required_rejection_policies
            .iter()
            .cloned()
            .rev()
            .collect(),
        required_command_args: gate.required_command_args.iter().cloned().rev().collect(),
        forbidden_command_args: gate.forbidden_command_args.iter().cloned().rev().collect(),
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
        ("upstream_owner_manifest_digest_gate_pass", upstream_pass),
        (
            "upstream_owner_manifest_digest_ref_bound",
            gate.upstream_owner_manifest_digest_gate_ref
                == GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_UPSTREAM_REF,
        ),
        (
            "single_e2b_gguf_llama_cpp_lane_bound",
            gate.selected_model_id == "google/gemma-4-E2B-it-qat-q4_0-gguf"
                && gate.required_filename == "gemma-4-E2B_q4_0-it.gguf"
                && gate.expected_file_size_bytes == GEMMA_QAT_E2B_EXPECTED_FILE_BYTES
                && gate.command_path == GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH
                && red_pass(&red_results, "wrong_model")
                && red_pass(&red_results, "wrong_filename")
                && red_pass(&red_results, "wrong_expected_file_bytes")
                && red_pass(&red_results, "wrong_source_revision")
                && red_pass(&red_results, "wrong_runtime_lane"),
        ),
        (
            "digest_requirements_bound_but_absent",
            gate.owner_approval_required
                && !gate.owner_approval_granted
                && gate.owner_manifest_digest_bound
                && gate.canonical_path_digest_bound
                && gate.model_file_digest_required
                && !gate.model_file_digest_present
                && gate.llama_cpp_binary_digest_required
                && !gate.llama_cpp_binary_digest_present
                && gate.llama_cpp_version_digest_required
                && !gate.llama_cpp_version_digest_present
                && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "model_digest_not_required")
                && red_pass(&red_results, "model_digest_present")
                && red_pass(&red_results, "llama_cpp_digest_not_required")
                && red_pass(&red_results, "llama_cpp_digest_present")
                && red_pass(&red_results, "version_digest_not_required")
                && red_pass(&red_results, "version_digest_present"),
        ),
        (
            "command_template_visible_offline_and_unarmed",
            gate.command_template_digest_required
                && gate.command_template_visible
                && gate.offline_mode_required
                && metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && metrics.forbidden_runtime_surface_count == 0
                && red_pass(&red_results, "command_template_hidden")
                && red_pass(&red_results, "offline_not_required")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "hf_download_enabled")
                && red_pass(&red_results, "server_mode_enabled")
                && red_pass(&red_results, "mmap_stress_enabled")
                && red_pass(&red_results, "provider_route_enabled"),
        ),
        (
            "required_and_forbidden_args_bound",
            metrics.required_command_arg_count == 14
                && metrics.forbidden_command_arg_count == 11
                && red_pass(&red_results, "missing_required_arg")
                && red_pass(&red_results, "missing_forbidden_arg"),
        ),
        (
            "path_file_and_llama_cpp_actions_zero",
            metrics.raw_path_bytes_stored == 0
                && metrics.canonical_path_bytes_stored == 0
                && metrics.path_canonicalization_attempts == 0
                && metrics.file_stat_attempts == 0
                && metrics.file_hash_attempts == 0
                && metrics.model_file_opened_count == 0
                && metrics.llama_cpp_binary_opened_count == 0
                && metrics.llama_cpp_version_executions == 0
                && red_pass(&red_results, "raw_path_bytes_stored")
                && red_pass(&red_results, "canonical_path_bytes_stored")
                && red_pass(&red_results, "path_canonicalization_attempt")
                && red_pass(&red_results, "file_stat_attempt")
                && red_pass(&red_results, "file_hash_attempt")
                && red_pass(&red_results, "model_file_opened")
                && red_pass(&red_results, "llama_cpp_binary_opened")
                && red_pass(&red_results, "llama_cpp_version_executed"),
        ),
        (
            "zero_model_runtime_provider_bytes",
            metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made"),
        ),
        (
            "memory_timeout_rollback_log_packet_abstention_bound",
            gate.memory_probe_plan_required
                && gate.timeout_cancel_required
                && gate.rollback_bound
                && gate.run_event_log_bound
                && gate.answer_packet_bound
                && gate.abstention_bound
                && red_pass(&red_results, "memory_probe_missing")
                && red_pass(&red_results, "timeout_cancel_missing")
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
            "gemma_e2b_model_file_llama_cpp_digest_gate_address_deterministic",
            gate.digest_gate_address(CREATED_AT_MS) == reversed.digest_gate_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_NEXT_CURSOR
                == "gemma_qat_e2b_owner_approved_first_token_runtime_probe",
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
            "required_digest_field_count",
            metrics.required_digest_field_count,
            "==",
            24,
            "fields",
        ),
        (
            "required_rejection_policy_count",
            metrics.required_rejection_policy_count,
            "==",
            40,
            "policies",
        ),
        (
            "required_command_arg_count",
            metrics.required_command_arg_count,
            "==",
            14,
            "args",
        ),
        (
            "forbidden_command_arg_count",
            metrics.forbidden_command_arg_count,
            "==",
            11,
            "args",
        ),
        (
            "owner_approval_granted_count",
            metrics.owner_approval_granted_count,
            "==",
            0,
            "claims",
        ),
        (
            "model_file_digest_present_count",
            metrics.model_file_digest_present_count,
            "==",
            0,
            "digests",
        ),
        (
            "llama_cpp_binary_digest_present_count",
            metrics.llama_cpp_binary_digest_present_count,
            "==",
            0,
            "digests",
        ),
        (
            "llama_cpp_version_digest_present_count",
            metrics.llama_cpp_version_digest_present_count,
            "==",
            0,
            "digests",
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
            "llama_cpp_binary_opened_count",
            metrics.llama_cpp_binary_opened_count,
            "==",
            0,
            "files",
        ),
        (
            "llama_cpp_version_executions",
            metrics.llama_cpp_version_executions,
            "==",
            0,
            "execs",
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
            "forbidden_runtime_surface_count",
            metrics.forbidden_runtime_surface_count,
            "==",
            0,
            "surfaces",
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
        "gemma_e2b_model_file_llama_cpp_digest_gate_address",
        &gate.digest_gate_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_NEXT_CURSOR,
        "gemma_qat_e2b_owner_approved_first_token_runtime_probe",
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
        notes: "metadata-only F-GemmaQATE2BModelFileAndLlamaCppDigestGate: consumes the E2B owner-path manifest digest gate and binds the future owner-approved model-file digest plus llama.cpp binary/version/command-template digest requirements. It keeps the Google Gemma 4 E2B QAT GGUF lane selected for the first harness probe, requires local model-file sha256, llama.cpp binary sha256, llama.cpp version digest, offline direct command template, memory probe plan, timeout/cancel, rollback, RunEventLog, AnswerPacket, and abstention before any first-token run can proceed. It reads zero owner-path/model/runtime/provider bytes, performs zero canonicalization/stat/hash/open/version-exec actions, arms zero commands, executes zero commands, rejects HF download/server/mmap/provider shortcuts, and makes no MAS/L2/L3/T4/user-facing, Gemma-default, E4B/12B bypass, live-70B, or SSD-as-RAM claim.".to_string(),
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
        .and_then(|value| value.as_bool())
        .unwrap_or(false))
}

fn red_fixture_results(
    gate: &GemmaQatE2bModelFileAndLlamaCppDigestGate,
) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaQatE2bModelFileAndLlamaCppDigestGate)>,
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
            Box::new(|g| g.source_revision = "main".to_string()),
        ),
        (
            "wrong_runtime_lane",
            Box::new(|g| g.runtime_lane = agent_core::uas::GemmaFamilyRuntimeLane::LiteRtLm),
        ),
        (
            "owner_approval_not_required",
            Box::new(|g| g.owner_approval_required = false),
        ),
        (
            "owner_approval_granted",
            Box::new(|g| g.owner_approval_granted = true),
        ),
        (
            "owner_manifest_digest_missing",
            Box::new(|g| g.owner_manifest_digest_bound = false),
        ),
        (
            "canonical_path_digest_missing",
            Box::new(|g| g.canonical_path_digest_bound = false),
        ),
        (
            "model_digest_not_required",
            Box::new(|g| g.model_file_digest_required = false),
        ),
        (
            "model_digest_present",
            Box::new(|g| g.model_file_digest_present = true),
        ),
        (
            "model_size_unbound",
            Box::new(|g| g.model_file_size_bound = false),
        ),
        (
            "llama_cpp_digest_not_required",
            Box::new(|g| g.llama_cpp_binary_digest_required = false),
        ),
        (
            "llama_cpp_digest_present",
            Box::new(|g| g.llama_cpp_binary_digest_present = true),
        ),
        (
            "version_digest_not_required",
            Box::new(|g| g.llama_cpp_version_digest_required = false),
        ),
        (
            "version_digest_present",
            Box::new(|g| g.llama_cpp_version_digest_present = true),
        ),
        (
            "command_template_digest_missing",
            Box::new(|g| g.command_template_digest_required = false),
        ),
        (
            "command_template_hidden",
            Box::new(|g| g.command_template_visible = false),
        ),
        (
            "offline_not_required",
            Box::new(|g| g.offline_mode_required = false),
        ),
        (
            "memory_probe_missing",
            Box::new(|g| g.memory_probe_plan_required = false),
        ),
        (
            "timeout_cancel_missing",
            Box::new(|g| g.timeout_cancel_required = false),
        ),
        (
            "missing_digest_field",
            Box::new(|g| {
                g.required_digest_fields.pop();
            }),
        ),
        (
            "missing_rejection_policy",
            Box::new(|g| {
                g.required_rejection_policies.pop();
            }),
        ),
        (
            "missing_required_arg",
            Box::new(|g| {
                g.required_command_args.pop();
            }),
        ),
        (
            "missing_forbidden_arg",
            Box::new(|g| {
                g.forbidden_command_args.pop();
            }),
        ),
        (
            "raw_path_bytes_stored",
            Box::new(|g| g.raw_path_bytes_stored = 1),
        ),
        (
            "canonical_path_bytes_stored",
            Box::new(|g| g.canonical_path_bytes_stored = 1),
        ),
        (
            "path_canonicalization_attempt",
            Box::new(|g| g.path_canonicalization_attempts = 1),
        ),
        ("file_stat_attempt", Box::new(|g| g.file_stat_attempts = 1)),
        ("file_hash_attempt", Box::new(|g| g.file_hash_attempts = 1)),
        (
            "model_file_opened",
            Box::new(|g| g.model_file_opened = true),
        ),
        (
            "llama_cpp_binary_opened",
            Box::new(|g| g.llama_cpp_binary_opened = true),
        ),
        (
            "llama_cpp_version_executed",
            Box::new(|g| g.llama_cpp_version_executions = 1),
        ),
        ("command_armed", Box::new(|g| g.command_armed = true)),
        ("command_executed", Box::new(|g| g.command_executed = true)),
        (
            "hf_download_enabled",
            Box::new(|g| g.hf_download_enabled = true),
        ),
        (
            "server_mode_enabled",
            Box::new(|g| g.server_mode_enabled = true),
        ),
        (
            "mmap_stress_enabled",
            Box::new(|g| g.mmap_stress_enabled = true),
        ),
        (
            "provider_route_enabled",
            Box::new(|g| g.provider_route_enabled = true),
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
    for axis in GEMMA_QAT_E2B_MODEL_FILE_AND_LLAMA_CPP_DIGEST_GATE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
