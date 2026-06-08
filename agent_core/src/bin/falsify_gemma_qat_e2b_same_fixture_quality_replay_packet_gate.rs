//! `falsify_gemma_qat_e2b_same_fixture_quality_replay_packet_gate`
//!
//! Metadata-only packet gate for a future owner-approved Gemma E2B quality
//! replay. It reads only the upstream reconciliation artifact, opens no
//! fixtures or runtime artifacts, executes no scorers or commands, and does
//! not promote Gemma into RuntimeRouter/System G.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaQatE2bSameFixtureQualityReplayPacketGate, GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
    GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_ID,
    GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_NEXT_CURSOR,
    GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_UPSTREAM_REF,
    GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH,
};

const FALSIFIER_ID: &str = GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_ID;
const FIXTURE_ID: &str = "gemma_qat_e2b_same_fixture_quality_replay_packet_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_qat_e2b_same_fixture_quality_replay_packet_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_same_fixture_quality_replay_packet_gate/result.json";
const UPSTREAM_RESULT: &str = "artifacts/falsifiers/gemma_qat_e2b_first_token_runtime_artifact_review_reconciliation_gate/result.json";
const CREATED_AT_MS: u64 = 1_779_405_600_000;

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
        "{FALSIFIER_ID}: overall_pass={} packet_fields={} quality_packet_bytes_read={} quality_replay_performed={} scorer_executions={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_packet_field_count"].value,
        artifact.measurements["future_quality_packet_bytes_read"].value,
        artifact.measurements["quality_replay_performed_count"].value,
        artifact.measurements["scorer_executions"].value,
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
    let gate = GemmaQatE2bSameFixtureQualityReplayPacketGate::canonical(
        GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_UPSTREAM_REF,
    );
    gate.validate()?;
    let reversed = GemmaQatE2bSameFixtureQualityReplayPacketGate {
        required_packet_fields: gate.required_packet_fields.iter().cloned().rev().collect(),
        required_rejection_policies: gate
            .required_rejection_policies
            .iter()
            .cloned()
            .rev()
            .collect(),
        task_families: gate.task_families.iter().copied().rev().collect(),
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
        ("upstream_reconciliation_gate_pass", upstream_pass),
        (
            "upstream_reconciliation_ref_bound",
            gate.upstream_reconciliation_ref
                == GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_UPSTREAM_REF,
        ),
        (
            "single_e2b_gguf_llama_cpp_quality_packet_lane_bound",
            gate.selected_model_id == "google/gemma-4-E2B-it-qat-q4_0-gguf"
                && gate.required_filename == "gemma-4-E2B_q4_0-it.gguf"
                && gate.expected_file_size_bytes == GEMMA_QAT_E2B_EXPECTED_FILE_BYTES
                && gate.command_path == GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH
                && red_pass(&red_results, "wrong_model")
                && red_pass(&red_results, "wrong_filename")
                && red_pass(&red_results, "wrong_expected_file_bytes")
                && red_pass(&red_results, "wrong_runtime_lane"),
        ),
        (
            "quality_packet_fields_and_rejection_policies_bound",
            metrics.required_packet_field_count == 35
                && metrics.required_rejection_policy_count == 48
                && red_pass(&red_results, "missing_packet_field")
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "fixture_scorer_task_family_bound",
            metrics.task_family_count == 7
                && gate.same_fixture_pack_digest_required
                && gate.held_out_split_bound
                && gate.fixture_pack_digest.starts_with("fixture_pack:sha256:")
                && gate
                    .scorer_bundle_digest
                    .starts_with("scorer_bundle:sha256:")
                && red_pass(&red_results, "wrong_fixture_pack")
                && red_pass(&red_results, "wrong_scorer_bundle")
                && red_pass(&red_results, "missing_task_family"),
        ),
        (
            "digest_and_artifact_identity_requirements_bound",
            gate.upstream_reconciliation_digest_required
                && gate.owner_approval_digest_required
                && gate.owner_manifest_digest_required
                && gate.canonical_path_digest_required
                && gate.model_file_digest_match_required
                && gate.llama_cpp_binary_digest_match_required
                && gate.llama_cpp_version_digest_match_required
                && red_pass(&red_results, "upstream_digest_missing")
                && red_pass(&red_results, "owner_approval_missing")
                && red_pass(&red_results, "owner_manifest_missing")
                && red_pass(&red_results, "canonical_path_missing")
                && red_pass(&red_results, "model_digest_missing")
                && red_pass(&red_results, "llama_cpp_digest_missing")
                && red_pass(&red_results, "version_digest_missing"),
        ),
        (
            "quality_replay_privacy_and_scorer_bound",
            gate.prompt_context_tool_digests_required
                && gate.redacted_final_output_digest_required
                && gate.deterministic_scorer_bundle_required
                && !gate.model_graded_primary_allowed
                && !gate.hidden_judge_allowed
                && gate.failure_taxonomy_bound
                && red_pass(&red_results, "prompt_context_tool_digest_missing")
                && red_pass(&red_results, "redacted_final_output_missing")
                && red_pass(&red_results, "deterministic_scorer_missing")
                && red_pass(&red_results, "model_graded_primary")
                && red_pass(&red_results, "hidden_judge")
                && red_pass(&red_results, "failure_taxonomy_missing"),
        ),
        (
            "cache_contamination_timeout_log_packet_bound",
            gate.contamination_check_bound
                && gate.cache_salt_bound
                && gate.cache_deletion_bound
                && gate.timeout_bound
                && gate.cancellation_bound
                && gate.rollback_bound
                && gate.run_event_log_bound
                && gate.answer_packet_bound
                && gate.abstention_bound
                && red_pass(&red_results, "contamination_check_missing")
                && red_pass(&red_results, "cache_salt_missing")
                && red_pass(&red_results, "cache_deletion_missing")
                && red_pass(&red_results, "timeout_missing")
                && red_pass(&red_results, "cancel_missing")
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "abstention_missing"),
        ),
        (
            "quality_packet_review_deferred",
            metrics.future_quality_packet_present_count == 0
                && metrics.future_quality_packet_bytes_read == 0
                && metrics.accepted_quality_packet_count == 0
                && metrics.quality_replay_performed_count == 0
                && red_pass(&red_results, "future_quality_packet_present")
                && red_pass(&red_results, "future_quality_packet_bytes_read")
                && red_pass(&red_results, "accepted_quality_packet")
                && red_pass(&red_results, "quality_replay_performed"),
        ),
        (
            "zero_fixture_artifact_scorer_command_model_runtime_provider_actions",
            metrics.fixture_payload_bytes_opened == 0
                && metrics.runtime_artifact_bytes_read == 0
                && metrics.scorer_executions == 0
                && metrics.benchmark_runs == 0
                && metrics.command_executed_count == 0
                && metrics.runtime_replay_performed_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.cache_bytes_reused == 0
                && red_pass(&red_results, "fixture_payload_opened")
                && red_pass(&red_results, "runtime_artifact_read")
                && red_pass(&red_results, "scorer_executed")
                && red_pass(&red_results, "benchmark_run")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "runtime_replay_performed")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made")
                && red_pass(&red_results, "cache_reuse"),
        ),
        (
            "privacy_raw_prompt_context_output_judge_denied",
            metrics.raw_prompt_bytes_captured == 0
                && metrics.raw_context_bytes_captured == 0
                && metrics.raw_output_bytes_captured == 0
                && metrics.raw_judge_bytes_captured == 0
                && red_pass(&red_results, "raw_prompt_captured")
                && red_pass(&red_results, "raw_context_captured")
                && red_pass(&red_results, "raw_output_captured")
                && red_pass(&red_results, "raw_judge_captured"),
        ),
        (
            "no_route_or_system_g_mutation",
            !gate.runtime_router_mutation_allowed
                && !gate.system_g_mutation_allowed
                && red_pass(&red_results, "runtime_router_mutation")
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
            "no_mas_l2_l3_t4_product_gemma_default_quality_or_large_model_claim",
            metrics.promotion_claim_count == 0
                && red_pass(&red_results, "mas_l2_l3_t4_product_claim")
                && red_pass(&red_results, "product_route_green")
                && red_pass(&red_results, "gemma_default_claim")
                && red_pass(&red_results, "larger_model_bypass")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim")
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "benchmark_fit_claim"),
        ),
        (
            "gemma_e2b_same_fixture_quality_packet_address_deterministic",
            gate.packet_gate_address(CREATED_AT_MS) == reversed.packet_gate_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_NEXT_CURSOR
                == "gemma_qat_e2b_runtime_router_admission_packet_gate",
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
            "required_packet_field_count",
            metrics.required_packet_field_count,
            "==",
            35,
            "fields",
        ),
        (
            "required_rejection_policy_count",
            metrics.required_rejection_policy_count,
            "==",
            48,
            "policies",
        ),
        (
            "task_family_count",
            metrics.task_family_count,
            "==",
            7,
            "families",
        ),
        (
            "future_quality_packet_present_count",
            metrics.future_quality_packet_present_count,
            "==",
            0,
            "packets",
        ),
        (
            "future_quality_packet_bytes_read",
            metrics.future_quality_packet_bytes_read,
            "==",
            0,
            "bytes",
        ),
        (
            "accepted_quality_packet_count",
            metrics.accepted_quality_packet_count,
            "==",
            0,
            "packets",
        ),
        (
            "quality_replay_performed_count",
            metrics.quality_replay_performed_count,
            "==",
            0,
            "replays",
        ),
        (
            "fixture_payload_bytes_opened",
            metrics.fixture_payload_bytes_opened,
            "==",
            0,
            "bytes",
        ),
        (
            "runtime_artifact_bytes_read",
            metrics.runtime_artifact_bytes_read,
            "==",
            0,
            "bytes",
        ),
        (
            "scorer_executions",
            metrics.scorer_executions,
            "==",
            0,
            "actions",
        ),
        ("benchmark_runs", metrics.benchmark_runs, "==", 0, "runs"),
        (
            "command_executed_count",
            metrics.command_executed_count,
            "==",
            0,
            "commands",
        ),
        (
            "runtime_replay_performed_count",
            metrics.runtime_replay_performed_count,
            "==",
            0,
            "replays",
        ),
        (
            "raw_prompt_bytes_captured",
            metrics.raw_prompt_bytes_captured,
            "==",
            0,
            "bytes",
        ),
        (
            "raw_context_bytes_captured",
            metrics.raw_context_bytes_captured,
            "==",
            0,
            "bytes",
        ),
        (
            "raw_output_bytes_captured",
            metrics.raw_output_bytes_captured,
            "==",
            0,
            "bytes",
        ),
        (
            "raw_judge_bytes_captured",
            metrics.raw_judge_bytes_captured,
            "==",
            0,
            "bytes",
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
            "cache_bytes_reused",
            metrics.cache_bytes_reused,
            "==",
            0,
            "bytes",
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
            60,
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
        "gemma_e2b_same_fixture_quality_packet_gate_address",
        &gate.packet_gate_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_NEXT_CURSOR,
        "gemma_qat_e2b_runtime_router_admission_packet_gate",
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
        notes: "metadata-only F-GemmaQATE2BSameFixtureQualityReplayPacketGate: consumes the E2B first-token artifact reconciliation gate and defines the fail-closed same-fixture quality replay packet before RuntimeRouter/System G admission. It binds E2B GGUF/llama.cpp identity, fixture/scorer/task-family digests, redacted final-output policy, deterministic scorer requirements, contamination/cache-deletion proof, rollback, RunEventLog, AnswerPacket, abstention, and non-promotion. It reads zero quality packet, fixture, runtime artifact, model, runtime, provider, or cache bytes, runs zero scorers or benchmarks, arms or executes zero commands, captures zero raw prompt/context/output/judge bytes, and makes no MAS/L2/L3/T4/user-facing, Gemma-default, quality, benchmark-fit, E4B/12B/70B bypass, live-70B, or SSD-as-RAM claim.".to_string(),
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
    gate: &GemmaQatE2bSameFixtureQualityReplayPacketGate,
) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaQatE2bSameFixtureQualityReplayPacketGate)>,
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
            "wrong_runtime_lane",
            Box::new(|g| g.runtime_lane = agent_core::uas::GemmaFamilyRuntimeLane::LiteRtLm),
        ),
        (
            "missing_packet_field",
            Box::new(|g| {
                g.required_packet_fields.pop();
            }),
        ),
        (
            "missing_rejection_policy",
            Box::new(|g| {
                g.required_rejection_policies.pop();
            }),
        ),
        (
            "wrong_fixture_pack",
            Box::new(|g| g.fixture_pack_digest = "fixture_pack:sha256:wrong".to_string()),
        ),
        (
            "wrong_scorer_bundle",
            Box::new(|g| g.scorer_bundle_digest = "scorer_bundle:sha256:wrong".to_string()),
        ),
        (
            "missing_task_family",
            Box::new(|g| {
                g.task_families.pop();
            }),
        ),
        (
            "upstream_digest_missing",
            Box::new(|g| g.upstream_reconciliation_digest_required = false),
        ),
        (
            "owner_approval_missing",
            Box::new(|g| g.owner_approval_digest_required = false),
        ),
        (
            "owner_manifest_missing",
            Box::new(|g| g.owner_manifest_digest_required = false),
        ),
        (
            "canonical_path_missing",
            Box::new(|g| g.canonical_path_digest_required = false),
        ),
        (
            "model_digest_missing",
            Box::new(|g| g.model_file_digest_match_required = false),
        ),
        (
            "llama_cpp_digest_missing",
            Box::new(|g| g.llama_cpp_binary_digest_match_required = false),
        ),
        (
            "version_digest_missing",
            Box::new(|g| g.llama_cpp_version_digest_match_required = false),
        ),
        (
            "prompt_context_tool_digest_missing",
            Box::new(|g| g.prompt_context_tool_digests_required = false),
        ),
        (
            "redacted_final_output_missing",
            Box::new(|g| g.redacted_final_output_digest_required = false),
        ),
        (
            "deterministic_scorer_missing",
            Box::new(|g| g.deterministic_scorer_bundle_required = false),
        ),
        (
            "model_graded_primary",
            Box::new(|g| g.model_graded_primary_allowed = true),
        ),
        ("hidden_judge", Box::new(|g| g.hidden_judge_allowed = true)),
        (
            "failure_taxonomy_missing",
            Box::new(|g| g.failure_taxonomy_bound = false),
        ),
        (
            "contamination_check_missing",
            Box::new(|g| g.contamination_check_bound = false),
        ),
        (
            "cache_salt_missing",
            Box::new(|g| g.cache_salt_bound = false),
        ),
        (
            "cache_deletion_missing",
            Box::new(|g| g.cache_deletion_bound = false),
        ),
        ("timeout_missing", Box::new(|g| g.timeout_bound = false)),
        ("cancel_missing", Box::new(|g| g.cancellation_bound = false)),
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
            "future_quality_packet_present",
            Box::new(|g| g.future_quality_packet_present = true),
        ),
        (
            "future_quality_packet_bytes_read",
            Box::new(|g| g.future_quality_packet_bytes_read = 1),
        ),
        (
            "accepted_quality_packet",
            Box::new(|g| g.accepted_quality_packet_count = 1),
        ),
        (
            "quality_replay_performed",
            Box::new(|g| g.quality_replay_performed_count = 1),
        ),
        (
            "fixture_payload_opened",
            Box::new(|g| g.fixture_payload_bytes_opened = 1),
        ),
        (
            "runtime_artifact_read",
            Box::new(|g| g.runtime_artifact_bytes_read = 1),
        ),
        ("scorer_executed", Box::new(|g| g.scorer_executions = 1)),
        ("benchmark_run", Box::new(|g| g.benchmark_runs = 1)),
        ("command_armed", Box::new(|g| g.command_armed = true)),
        ("command_executed", Box::new(|g| g.command_executed = true)),
        (
            "runtime_replay_performed",
            Box::new(|g| g.runtime_replay_performed = true),
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
        ("cache_reuse", Box::new(|g| g.cache_bytes_reused = 1)),
        (
            "raw_prompt_captured",
            Box::new(|g| g.raw_prompt_bytes_captured = 1),
        ),
        (
            "raw_context_captured",
            Box::new(|g| g.raw_context_bytes_captured = 1),
        ),
        (
            "raw_output_captured",
            Box::new(|g| g.raw_output_bytes_captured = 1),
        ),
        (
            "raw_judge_captured",
            Box::new(|g| g.raw_judge_bytes_captured = 1),
        ),
        (
            "runtime_router_mutation",
            Box::new(|g| g.runtime_router_mutation_allowed = true),
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
            "mas_l2_l3_t4_product_claim",
            Box::new(|g| {
                g.mas_promoted = true;
                g.l2_capability_effect = true;
                g.l3_wrv_effect = true;
                g.t4_build_green_effect = true;
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
            "larger_model_bypass",
            Box::new(|g| g.larger_model_bypass_allowed = true),
        ),
        (
            "live_dense_70b_claim",
            Box::new(|g| g.live_dense_70b_claim = true),
        ),
        ("ssd_as_ram_claim", Box::new(|g| g.ssd_as_ram_claim = true)),
        ("quality_claim", Box::new(|g| g.quality_claimed = true)),
        (
            "benchmark_fit_claim",
            Box::new(|g| g.benchmark_claimed_as_fit = true),
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
    for axis in GEMMA_QAT_E2B_SAME_FIXTURE_QUALITY_REPLAY_PACKET_GATE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
