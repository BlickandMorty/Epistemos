//! `falsify_small_compressed_model_runtime_probe_proof_envelope`
//!
//! Metadata-only witness for
//! `F-SmallCompressedModel-RuntimeProbeProofEnvelope`. It consumes the E2B
//! model-path readiness card and defines the offline one-token proof envelope
//! required before any owner-approved runtime command can be armed.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    required_small_compressed_runtime_probe_phases, ProStatus, ProductBuild,
    SmallCompressedHarnessPromotionTier, SmallCompressedRuntimeProbeByteLedger,
    SmallCompressedRuntimeProbeEnvelopeStatus, SmallCompressedRuntimeProbePhase,
    SmallCompressedRuntimeProbeProofEnvelope, SmallCompressedRuntimeProbeProofEnvelopeSet,
    SmallCompressedRuntimeProbeRefs, UasAddress,
    SMALL_COMPRESSED_MODEL_RUNTIME_PROBE_PROOF_ENVELOPE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SmallCompressedModel-RuntimeProbeProofEnvelope";
const FIXTURE_ID: &str = "small_compressed_model_runtime_probe_proof_envelope_v1";
const COMMAND: &str = "Tools/falsifiers/f_small_compressed_model_runtime_probe_proof_envelope.sh";
const RESULT: &str =
    "artifacts/falsifiers/small_compressed_model_runtime_probe_proof_envelope/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/small_compressed_model_model_path_readiness_card/result.json";
const CREATED_AT_MS: u64 = 1_779_037_300_000;
const SET_METADATA_BYTES: u64 = 32_000;
const ENVELOPE_ID: &str = "gemma4_e2b_qat_gguf_runtime_probe_proof_envelope";
const SELECTED_CANDIDATE_ID: &str = "gemma4_e2b_qat_gguf_harness_preflight";
const MODEL_ID: &str = "google/gemma-4-E2B-it-qat-q4_0-gguf";
const REQUIRED_FILENAME: &str = "gemma-4-E2B_q4_0-it.gguf";
const SOURCE_REVISION: &str = "1894d1fc0a19d86697abd40483f5983c867df03f";
const LLAMA_CLI_PATH: &str = "/opt/homebrew/bin/llama-cli";
const MODEL_PATH_PLACEHOLDER: &str = "<OWNER_APPROVED_MODEL_PATH>";
const PROMPT_PLACEHOLDER: &str = "<SYNTHETIC_NON_USER_PROMPT>";

const REQUIRED_ARGS: &[&str] = &[
    "--offline",
    "--model",
    MODEL_PATH_PLACEHOLDER,
    "--prompt",
    PROMPT_PLACEHOLDER,
    "--predict",
    "1",
    "--ctx-size",
    "512",
    "--batch-size",
    "32",
    "--ubatch-size",
    "32",
    "--temp",
    "0",
    "--seed",
    "0",
    "--no-conversation",
    "--single-turn",
    "--simple-io",
    "--no-display-prompt",
    "--no-mmap",
    "--log-disable",
];

const FORBIDDEN_ARGS: &[&str] = &[
    "--hf-repo",
    "-hf",
    "-hfr",
    "--hf-file",
    "-hff",
    "--model-url",
    "-mu",
    "--docker-repo",
    "-dr",
    "--hf-token",
    "-hft",
    "--server",
    "--conversation",
    "--mmap",
    "--mlock",
];

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
        "{FALSIFIER_ID}: overall_pass={} required_phase_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_phase_count"].value,
        artifact.measurements["red_fixture_rejection_count"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let (upstream_address, upstream_next_unit) = upstream_model_path_address()?;
    let envelope = accepted_envelope();
    let envelope_set = build_set(upstream_address.clone(), vec![envelope.clone()])?;
    let reversed = build_set(upstream_address, vec![envelope.clone()])?;
    let metrics = envelope_set.metrics();
    let red_results = red_fixture_results(&envelope_set)?;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_model_path_readiness_bound",
            upstream_next_unit == "small_compressed_model_owner_approved_runtime_probe"
                && envelope_set
                    .upstream_model_path_witness_ref
                    .contains("small_compressed_model_model_path_readiness_card")
                && red_pass(&red_results, "bad_upstream_model_path_ref"),
        ),
        (
            "offline_one_token_command_template_bound",
            envelope.command_path == LLAMA_CLI_PATH
                && metrics.required_flag_count == REQUIRED_ARGS.len() as u64
                && red_pass(&red_results, "missing_offline")
                && red_pass(&red_results, "missing_model_placeholder")
                && red_pass(&red_results, "missing_prompt_placeholder")
                && red_pass(&red_results, "predict_unbounded")
                && red_pass(&red_results, "ctx_unbounded")
                && red_pass(&red_results, "batch_uncapped")
                && red_pass(&red_results, "temperature_nonzero")
                && red_pass(&red_results, "missing_no_conversation")
                && red_pass(&red_results, "missing_no_mmap"),
        ),
        (
            "network_download_flags_rejected",
            red_pass(&red_results, "hf_repo_flag")
                && red_pass(&red_results, "hf_file_flag")
                && red_pass(&red_results, "model_url_flag")
                && red_pass(&red_results, "docker_repo_flag")
                && red_pass(&red_results, "hf_token_flag"),
        ),
        (
            "required_proof_phases_bound",
            metrics.required_phase_count == 16
                && red_pass(&red_results, "missing_owner_phase")
                && red_pass(&red_results, "missing_model_path_phase")
                && red_pass(&red_results, "missing_memory_before_phase")
                && red_pass(&red_results, "missing_first_token_redaction_phase")
                && red_pass(&red_results, "missing_answer_packet_phase")
                && red_pass(&red_results, "missing_larger_model_block_phase"),
        ),
        (
            "approval_and_execution_blocked",
            envelope.owner_approval_required
                && !envelope.owner_approval_granted
                && !envelope.download_executed
                && !envelope.command_armed
                && !envelope.command_executed
                && !envelope.inference_executed
                && !envelope.first_token_claimed
                && !envelope.retained_token_digest_recorded
                && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "download_executed")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "inference_executed")
                && red_pass(&red_results, "first_token_claimed")
                && red_pass(&red_results, "retained_digest_claimed"),
        ),
        (
            "byte_ledger_zero_loaded",
            metrics.downloaded_model_bytes == 0
                && metrics.opened_model_bytes == 0
                && metrics.hashed_model_bytes == 0
                && metrics.resident_model_bytes == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "downloaded_model_bytes")
                && red_pass(&red_results, "opened_model_bytes")
                && red_pass(&red_results, "hashed_model_bytes")
                && red_pass(&red_results, "resident_model_bytes")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_call_made"),
        ),
        (
            "proof_surfaces_required",
            envelope.answer_packet_required
                && envelope.run_event_log_required
                && envelope.rollback_required
                && envelope.cancellation_required
                && envelope.memory_ledger_required
                && red_pass(&red_results, "missing_answer_packet")
                && red_pass(&red_results, "missing_run_event_log")
                && red_pass(&red_results, "missing_rollback")
                && red_pass(&red_results, "missing_cancellation")
                && red_pass(&red_results, "missing_memory_ledger"),
        ),
        (
            "visibility_required",
            envelope.command_template_visible
                && envelope.cli_help_surface_visible
                && envelope.model_path_status_visible
                && envelope.memory_sampling_plan_visible
                && envelope.answer_packet_schema_visible
                && envelope.scaling_ladder_visible
                && red_pass(&red_results, "missing_command_template_visibility")
                && red_pass(&red_results, "missing_cli_help_visibility")
                && red_pass(&red_results, "missing_memory_plan_visibility")
                && red_pass(&red_results, "missing_scaling_ladder_visibility"),
        ),
        (
            "larger_model_escalation_blocked",
            envelope.e4b_requires_new_envelope
                && envelope.twelve_b_requires_memory_repreflight
                && envelope.thirty_one_b_vault_only
                && envelope.seventy_b_cold_assembly_only
                && red_pass(&red_results, "e4b_without_new_envelope")
                && red_pass(&red_results, "twelve_b_without_memory_repreflight")
                && red_pass(&red_results, "thirty_one_b_not_vault_only")
                && red_pass(&red_results, "seventy_b_not_cold_assembly_only"),
        ),
        (
            "product_promotion_and_hidden_authority_rejected",
            red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "l2_capability_claim")
                && red_pass(&red_results, "l3_wrv_claim")
                && red_pass(&red_results, "mas_readiness_claim")
                && red_pass(&red_results, "hidden_cloud_fallback")
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "provider_fallback")
                && red_pass(&red_results, "server_sidecar_default")
                && red_pass(&red_results, "hf_or_url_download_allowed")
                && red_pass(&red_results, "multi_token_allowed")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "proof_ref_prefixes_required",
            red_pass(&red_results, "bad_command_template_ref")
                && red_pass(&red_results, "bad_source_model_ref")
                && red_pass(&red_results, "bad_model_path_ref")
                && red_pass(&red_results, "bad_prompt_hash_ref")
                && red_pass(&red_results, "bad_memory_ledger_ref")
                && red_pass(&red_results, "bad_answer_packet_ref")
                && red_pass(&red_results, "bad_scaling_ladder_ref"),
        ),
        (
            "set_address_deterministic",
            envelope_set.set_address == reversed.set_address,
        ),
        (
            "layer_separation_required",
            envelope_set.l1_l2_l3_separated
                && envelope_set.runtime_deferred
                && envelope_set.product_promotion_blocked
                && red_pass(&red_results, "set_missing_layer_separation")
                && red_pass(&red_results, "set_runtime_not_deferred")
                && red_pass(&red_results, "set_product_promotion_allowed"),
        ),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            pass,
        );
    }

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_probe_envelope_count",
        metrics.envelope_count,
        "==",
        1,
        "envelopes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_phase_count",
        metrics.required_phase_count,
        "==",
        16,
        "phases",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "required_flag_count",
        metrics.required_flag_count,
        "==",
        REQUIRED_ARGS.len() as u64,
        "flags",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        50,
        "fixtures",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_rejection_count",
        red_fixture_rejection_count,
        "==",
        red_results.len() as u64,
        "fixtures",
    );
    for name in [
        "downloaded_model_bytes",
        "opened_model_bytes",
        "hashed_model_bytes",
        "model_bytes_loaded",
        "runtime_bytes_loaded",
        "provider_calls_made",
    ] {
        let value = match name {
            "downloaded_model_bytes" => metrics.downloaded_model_bytes,
            "opened_model_bytes" => metrics.opened_model_bytes,
            "hashed_model_bytes" => metrics.hashed_model_bytes,
            "model_bytes_loaded" => metrics.model_bytes_loaded,
            "runtime_bytes_loaded" => metrics.runtime_bytes_loaded,
            "provider_calls_made" => metrics.provider_calls_made,
            _ => unreachable!(),
        };
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            value,
            "==",
            0,
            if name == "provider_calls_made" {
                "calls"
            } else {
                "bytes"
            },
        );
    }

    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_probe_envelope_set_address",
        envelope_set.set_address.to_string(),
        "starts_with",
        "small_compressed_model_runtime_probe_proof_envelope:",
        "uas_address",
    );
    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_model_id",
        envelope.model_id.clone(),
        "==",
        MODEL_ID,
        "model_id",
    );
    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "command_path",
        envelope.command_path.clone(),
        "==",
        LLAMA_CLI_PATH,
        "path",
    );
    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "command_template_summary",
        envelope.command_template_args.join(" "),
        "contains",
        "--offline",
        "template",
    );
    insert_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        SMALL_COMPRESSED_MODEL_RUNTIME_PROBE_PROOF_ENVELOPE_NEXT_CURSOR.to_string(),
        "==",
        "small_compressed_model_owner_approved_runtime_probe",
        "cursor",
    );

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
        notes: "Builds F-SmallCompressedModel-RuntimeProbeProofEnvelope from the E2B model-path readiness card. Scope is research-to-build T1/L1 metadata only: it defines the offline local llama-cli one-token command template, proof phases, memory sampling, cancellation, rollback, RunEventLog, AnswerPacket, and larger-model escalation blockers required before a future owner-approved runtime witness. It runs no inference, opens no model path, and promotes no L2/L3 capability.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_model_path_address() -> Result<(UasAddress, String), Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream model-path readiness card has not passed".into());
    }
    let address = value
        .pointer("/measurements/model_path_set_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing upstream model_path_set_address measurement")?;
    let next_unit = value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing upstream next_research_to_build_unit measurement")?;
    Ok((UasAddress::from_str(address)?, next_unit.to_string()))
}

fn build_set(
    upstream_model_path_set_address: UasAddress,
    envelopes: Vec<SmallCompressedRuntimeProbeProofEnvelope>,
) -> Result<SmallCompressedRuntimeProbeProofEnvelopeSet, Box<dyn std::error::Error>> {
    Ok(
        SmallCompressedRuntimeProbeProofEnvelopeSet::from_model_path_readiness(
            upstream_model_path_set_address,
            "artifact:small_compressed_model_model_path_readiness_card:result",
            ENVELOPE_ID,
            envelopes,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            SET_METADATA_BYTES,
            true,
            true,
            true,
            CREATED_AT_MS,
        )?,
    )
}

fn accepted_envelope() -> SmallCompressedRuntimeProbeProofEnvelope {
    SmallCompressedRuntimeProbeProofEnvelope {
        envelope_id: ENVELOPE_ID.to_string(),
        selected_candidate_id: SELECTED_CANDIDATE_ID.to_string(),
        model_id: MODEL_ID.to_string(),
        required_filename: REQUIRED_FILENAME.to_string(),
        command_path: LLAMA_CLI_PATH.to_string(),
        command_template_args: REQUIRED_ARGS.iter().map(|arg| (*arg).to_string()).collect(),
        forbidden_flags: FORBIDDEN_ARGS
            .iter()
            .map(|arg| (*arg).to_string())
            .collect(),
        required_phases: required_small_compressed_runtime_probe_phases().to_vec(),
        status: SmallCompressedRuntimeProbeEnvelopeStatus::PendingOwnerApprovalAndPath,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: SmallCompressedHarnessPromotionTier::T1L1Metadata,
        bytes: SmallCompressedRuntimeProbeByteLedger::metadata_only(
            4_096,
            16_384,
            1,
            512,
            60_000,
            45_000,
        ),
        refs: refs(ENVELOPE_ID),
        user_visible_summary: "The E2B runtime-probe proof envelope records a local-only llama-cli one-token template, synthetic prompt hash, memory sampling plan, cancellation deadline, rollback, RunEventLog, AnswerPacket, and larger-model escalation blockers. Owner approval and model path are still pending, so no download, command, inference, provider fallback, L2, L3, 12B, 31B, or 70B product claim is allowed.".to_string(),
        command_template_visible: true,
        cli_help_surface_visible: true,
        model_path_status_visible: true,
        memory_sampling_plan_visible: true,
        answer_packet_schema_visible: true,
        scaling_ladder_visible: true,
        owner_approval_required: true,
        owner_approval_granted: false,
        download_executed: false,
        command_armed: false,
        command_executed: false,
        inference_executed: false,
        first_token_claimed: false,
        retained_token_digest_recorded: false,
        quality_claimed: false,
        l2_capability_claimed: false,
        l3_wrv_claimed: false,
        mas_readiness_claimed: false,
        answer_packet_required: true,
        run_event_log_required: true,
        rollback_required: true,
        cancellation_required: true,
        memory_ledger_required: true,
        route_policy_mutated: false,
        hidden_cloud_fallback_allowed: false,
        hidden_route_authority_allowed: false,
        provider_fallback_allowed: false,
        server_sidecar_default_allowed: false,
        hf_or_url_download_allowed: false,
        multi_token_or_unbounded_generation_allowed: false,
        e4b_requires_new_envelope: true,
        twelve_b_requires_memory_repreflight: true,
        thirty_one_b_vault_only: true,
        seventy_b_cold_assembly_only: true,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
    }
}

fn refs(id: &str) -> SmallCompressedRuntimeProbeRefs {
    SmallCompressedRuntimeProbeRefs {
        upstream_model_path_ref: "artifact:small_compressed_model_model_path_readiness_card:result"
            .to_string(),
        command_template_ref: format!("command_template:small_compressed_runtime_probe:{id}"),
        source_model_ref: format!("source:model:gemma4-e2b-qat-gguf:{SOURCE_REVISION}"),
        model_path_ref: format!("model_path:owner_approval_required:{id}"),
        owner_approval_ref: format!("owner_approval:pending:{id}"),
        prompt_hash_ref: format!("prompt_hash:synthetic_non_user:{id}"),
        memory_ledger_ref: format!("memory_ledger:small_compressed_runtime_probe:{id}"),
        answer_packet_ref: format!("answer_packet:small_compressed_runtime_probe:{id}"),
        run_event_log_ref: format!("run_event_log:small_compressed_runtime_probe:{id}"),
        rollback_ref: format!("rollback:small_compressed_runtime_probe:{id}"),
        cancellation_ref: format!("cancel:small_compressed_runtime_probe:{id}"),
        compatibility_fence_ref: format!("compat:small_compressed_runtime_probe:{id}"),
        route_caveat_ref: format!("route_caveat:small_compressed_runtime_probe:{id}"),
        scaling_ladder_ref: format!("scaling_ladder:gemma_qat_local:{id}"),
    }
}

fn red_fixture_results(
    set: &SmallCompressedRuntimeProbeProofEnvelopeSet,
) -> Result<Vec<(String, bool)>, Box<dyn std::error::Error>> {
    let mut results = Vec::new();
    let upstream = set.upstream_model_path_set_address.clone();

    let reject_envelope = |name: &str,
                           mutate: fn(&mut SmallCompressedRuntimeProbeProofEnvelope)|
     -> Result<(String, bool), Box<dyn std::error::Error>> {
        let mut envelope = accepted_envelope();
        mutate(&mut envelope);
        Ok((
            name.to_string(),
            build_set(upstream.clone(), vec![envelope]).is_err(),
        ))
    };

    type EnvMutation = fn(&mut SmallCompressedRuntimeProbeProofEnvelope);
    let mutations: &[(&str, EnvMutation)] = &[
        ("missing_offline", |env| remove_arg(env, "--offline")),
        ("missing_model_placeholder", |env| {
            remove_arg(env, MODEL_PATH_PLACEHOLDER)
        }),
        ("missing_prompt_placeholder", |env| {
            remove_arg(env, PROMPT_PLACEHOLDER)
        }),
        ("predict_unbounded", |env| {
            set_arg_value(env, "--predict", "-1")
        }),
        ("ctx_unbounded", |env| set_arg_value(env, "--ctx-size", "0")),
        ("batch_uncapped", |env| {
            set_arg_value(env, "--batch-size", "2048")
        }),
        ("temperature_nonzero", |env| {
            set_arg_value(env, "--temp", "0.8")
        }),
        ("missing_no_conversation", |env| {
            remove_arg(env, "--no-conversation")
        }),
        ("missing_no_mmap", |env| remove_arg(env, "--no-mmap")),
        ("hf_repo_flag", |env| {
            env.command_template_args.push("--hf-repo".to_string())
        }),
        ("hf_file_flag", |env| {
            env.command_template_args.push("--hf-file".to_string())
        }),
        ("model_url_flag", |env| {
            env.command_template_args.push("--model-url".to_string())
        }),
        ("docker_repo_flag", |env| {
            env.command_template_args.push("--docker-repo".to_string())
        }),
        ("hf_token_flag", |env| {
            env.command_template_args.push("--hf-token".to_string())
        }),
        ("missing_owner_phase", |env| {
            remove_phase(
                env,
                SmallCompressedRuntimeProbePhase::OwnerApprovalTokenBound,
            )
        }),
        ("missing_model_path_phase", |env| {
            remove_phase(env, SmallCompressedRuntimeProbePhase::ModelPathBound)
        }),
        ("missing_memory_before_phase", |env| {
            remove_phase(
                env,
                SmallCompressedRuntimeProbePhase::MemoryBeforeSampleRequired,
            )
        }),
        ("missing_first_token_redaction_phase", |env| {
            remove_phase(
                env,
                SmallCompressedRuntimeProbePhase::FirstTokenRedactionRequired,
            )
        }),
        ("missing_answer_packet_phase", |env| {
            remove_phase(env, SmallCompressedRuntimeProbePhase::AnswerPacketBound)
        }),
        ("missing_larger_model_block_phase", |env| {
            remove_phase(
                env,
                SmallCompressedRuntimeProbePhase::LargerModelEscalationBlocked,
            )
        }),
        ("owner_approval_granted", |env| {
            env.owner_approval_granted = true
        }),
        ("download_executed", |env| env.download_executed = true),
        ("command_armed", |env| env.command_armed = true),
        ("command_executed", |env| env.command_executed = true),
        ("inference_executed", |env| env.inference_executed = true),
        ("first_token_claimed", |env| env.first_token_claimed = true),
        ("retained_digest_claimed", |env| {
            env.retained_token_digest_recorded = true
        }),
        ("downloaded_model_bytes", |env| {
            env.bytes.downloaded_model_bytes = 1
        }),
        ("opened_model_bytes", |env| env.bytes.opened_model_bytes = 1),
        ("hashed_model_bytes", |env| env.bytes.hashed_model_bytes = 1),
        ("resident_model_bytes", |env| {
            env.bytes.resident_model_bytes = 1
        }),
        ("model_bytes_loaded", |env| env.bytes.model_bytes_loaded = 1),
        ("runtime_bytes_loaded", |env| {
            env.bytes.runtime_bytes_loaded = 1
        }),
        ("provider_call_made", |env| {
            env.bytes.provider_calls_made = 1
        }),
        ("missing_answer_packet", |env| {
            env.answer_packet_required = false
        }),
        ("missing_run_event_log", |env| {
            env.run_event_log_required = false
        }),
        ("missing_rollback", |env| env.rollback_required = false),
        ("missing_cancellation", |env| {
            env.cancellation_required = false
        }),
        ("missing_memory_ledger", |env| {
            env.memory_ledger_required = false
        }),
        ("missing_command_template_visibility", |env| {
            env.command_template_visible = false
        }),
        ("missing_cli_help_visibility", |env| {
            env.cli_help_surface_visible = false
        }),
        ("missing_memory_plan_visibility", |env| {
            env.memory_sampling_plan_visible = false
        }),
        ("missing_scaling_ladder_visibility", |env| {
            env.scaling_ladder_visible = false
        }),
        ("e4b_without_new_envelope", |env| {
            env.e4b_requires_new_envelope = false
        }),
        ("twelve_b_without_memory_repreflight", |env| {
            env.twelve_b_requires_memory_repreflight = false
        }),
        ("thirty_one_b_not_vault_only", |env| {
            env.thirty_one_b_vault_only = false
        }),
        ("seventy_b_not_cold_assembly_only", |env| {
            env.seventy_b_cold_assembly_only = false
        }),
        ("quality_claim", |env| env.quality_claimed = true),
        ("l2_capability_claim", |env| {
            env.l2_capability_claimed = true
        }),
        ("l3_wrv_claim", |env| env.l3_wrv_claimed = true),
        ("mas_readiness_claim", |env| {
            env.mas_readiness_claimed = true
        }),
        ("hidden_cloud_fallback", |env| {
            env.hidden_cloud_fallback_allowed = true
        }),
        ("hidden_route_authority", |env| {
            env.hidden_route_authority_allowed = true
        }),
        ("provider_fallback", |env| {
            env.provider_fallback_allowed = true
        }),
        ("server_sidecar_default", |env| {
            env.server_sidecar_default_allowed = true
        }),
        ("hf_or_url_download_allowed", |env| {
            env.hf_or_url_download_allowed = true
        }),
        ("multi_token_allowed", |env| {
            env.multi_token_or_unbounded_generation_allowed = true
        }),
        ("live_dense_70b_claim", |env| {
            env.live_dense_70b_claimed = true
        }),
        ("ssd_as_ram_claim", |env| env.ssd_as_ram_claimed = true),
        ("bad_command_template_ref", |env| {
            env.refs.command_template_ref = "command:wrong".to_string()
        }),
        ("bad_source_model_ref", |env| {
            env.refs.source_model_ref = "source:model:wrong".to_string()
        }),
        ("bad_model_path_ref", |env| {
            env.refs.model_path_ref = "model_path:wrong".to_string()
        }),
        ("bad_prompt_hash_ref", |env| {
            env.refs.prompt_hash_ref = "prompt:wrong".to_string()
        }),
        ("bad_memory_ledger_ref", |env| {
            env.refs.memory_ledger_ref = "memory:wrong".to_string()
        }),
        ("bad_answer_packet_ref", |env| {
            env.refs.answer_packet_ref = "answer:wrong".to_string()
        }),
        ("bad_scaling_ladder_ref", |env| {
            env.refs.scaling_ladder_ref = "scale:wrong".to_string()
        }),
    ];
    for (name, mutate) in mutations {
        results.push(reject_envelope(name, *mutate)?);
    }

    let envelope = accepted_envelope();
    results.push((
        "bad_upstream_model_path_ref".to_string(),
        SmallCompressedRuntimeProbeProofEnvelopeSet::from_model_path_readiness(
            upstream.clone(),
            "artifact:wrong",
            ENVELOPE_ID,
            vec![envelope.clone()],
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            SET_METADATA_BYTES,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
        .is_err(),
    ));
    results.push((
        "set_missing_layer_separation".to_string(),
        SmallCompressedRuntimeProbeProofEnvelopeSet::from_model_path_readiness(
            upstream.clone(),
            "artifact:small_compressed_model_model_path_readiness_card:result",
            ENVELOPE_ID,
            vec![envelope.clone()],
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            SET_METADATA_BYTES,
            false,
            true,
            true,
            CREATED_AT_MS,
        )
        .is_err(),
    ));
    results.push((
        "set_runtime_not_deferred".to_string(),
        SmallCompressedRuntimeProbeProofEnvelopeSet::from_model_path_readiness(
            upstream.clone(),
            "artifact:small_compressed_model_model_path_readiness_card:result",
            ENVELOPE_ID,
            vec![envelope.clone()],
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            SET_METADATA_BYTES,
            true,
            false,
            true,
            CREATED_AT_MS,
        )
        .is_err(),
    ));
    results.push((
        "set_product_promotion_allowed".to_string(),
        SmallCompressedRuntimeProbeProofEnvelopeSet::from_model_path_readiness(
            upstream,
            "artifact:small_compressed_model_model_path_readiness_card:result",
            ENVELOPE_ID,
            vec![envelope],
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            SET_METADATA_BYTES,
            true,
            true,
            false,
            CREATED_AT_MS,
        )
        .is_err(),
    ));

    Ok(results)
}

fn remove_arg(env: &mut SmallCompressedRuntimeProbeProofEnvelope, arg: &str) {
    env.command_template_args.retain(|value| value != arg);
}

fn set_arg_value(env: &mut SmallCompressedRuntimeProbeProofEnvelope, flag: &str, value: &str) {
    if let Some(index) = env
        .command_template_args
        .iter()
        .position(|candidate| candidate == flag)
    {
        if let Some(slot) = env.command_template_args.get_mut(index + 1) {
            *slot = value.to_string();
        }
    }
}

fn remove_phase(
    env: &mut SmallCompressedRuntimeProbeProofEnvelope,
    phase: SmallCompressedRuntimeProbePhase,
) {
    env.required_phases.retain(|candidate| *candidate != phase);
}

fn red_pass(red_results: &[(String, bool)], name: &str) -> bool {
    red_results
        .iter()
        .find(|(fixture, _)| fixture == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn insert_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: String,
    operator: &str,
    threshold: &str,
    unit: &str,
) {
    let pass = match operator {
        "==" => value == threshold,
        "starts_with" => value.starts_with(threshold),
        "contains" => value.contains(threshold),
        _ => false,
    };
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::json!(threshold),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}
