//! `falsify_gemma_direct_harness_first_runtime_proof_command_card`
//!
//! Metadata-only command-card gate for the first future owner-approved Gemma
//! local GGUF runtime proof. It reads only the upstream admission artifact,
//! writes no command card, opens no paths, arms no command, spawns no process,
//! and promotes no route.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaDirectHarnessFirstRuntimeProofCommandCard, ProStatus, ProductBuild,
    GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_ID,
    GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_NEXT_CURSOR,
    GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_UPSTREAM_REF,
};

const FALSIFIER_ID: &str = GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_ID;
const FIXTURE_ID: &str = "gemma_direct_harness_first_runtime_proof_command_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_direct_harness_first_runtime_proof_command_card.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_direct_harness_first_runtime_proof_command_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_direct_harness_owner_approved_runtime_router_admission_packet_gate/result.json";
const CREATED_AT_MS: u64 = 1_779_840_000_000;

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
        "{FALSIFIER_ID}: overall_pass={} command_card_fields={} allowed_flags={} denied_flags={} command_executed={} process_spawned={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_command_card_field_count"].value,
        artifact.measurements["allowed_argv_flag_count"].value,
        artifact.measurements["denied_argv_flag_count"].value,
        artifact.measurements["command_executed_count"].value,
        artifact.measurements["process_spawned_count"].value,
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
    let upstream_pass = upstream_gate_pass(UPSTREAM_RESULT)?;
    let card = GemmaDirectHarnessFirstRuntimeProofCommandCard::canonical();
    card.validate()?;
    let reversed = GemmaDirectHarnessFirstRuntimeProofCommandCard {
        required_command_card_fields: card
            .required_command_card_fields
            .iter()
            .cloned()
            .rev()
            .collect(),
        allowed_argv_flags: card.allowed_argv_flags.iter().cloned().rev().collect(),
        denied_argv_flags: card.denied_argv_flags.iter().cloned().rev().collect(),
        required_receipt_fields: card.required_receipt_fields.iter().cloned().rev().collect(),
        ..card.clone()
    };
    reversed.validate()?;

    let metrics = card.metrics();
    let red_results = red_fixture_results(&card);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_admission_packet_gate_pass", upstream_pass),
        (
            "upstream_admission_packet_ref_bound",
            card.upstream_admission_ref
                == GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_UPSTREAM_REF,
        ),
        (
            "local_gguf_runtime_lane_bound",
            card.runtime_lane == "gemma-direct-harness-llama-cpp-gguf-pro-gated"
                && red_pass(&red_results, "bad_runtime_lane"),
        ),
        (
            "command_card_fields_bound",
            metrics.required_command_card_field_count == 37
                && red_pass(&red_results, "missing_command_card_field")
                && red_pass(&red_results, "duplicate_command_card_field"),
        ),
        (
            "argv_allowlist_and_denylist_bound",
            metrics.allowed_argv_flag_count == 17
                && metrics.denied_argv_flag_count == 22
                && red_pass(&red_results, "missing_allowed_argv_flag")
                && red_pass(&red_results, "duplicate_allowed_argv_flag")
                && red_pass(&red_results, "missing_denied_argv_flag")
                && red_pass(&red_results, "duplicate_denied_argv_flag"),
        ),
        (
            "local_m_single_turn_timing_policy_bound",
            card.offline_required
                && card.local_m_flag_required
                && card.single_turn_required
                && card.no_display_prompt_required
                && card.show_timings_required
                && red_pass(&red_results, "offline_missing")
                && red_pass(&red_results, "local_m_flag_missing")
                && red_pass(&red_results, "single_turn_missing")
                && red_pass(&red_results, "no_display_prompt_missing")
                && red_pass(&red_results, "show_timings_missing"),
        ),
        (
            "bounded_context_predict_seed_policy_bound",
            metrics.ctx_size_bound == 8_192
                && metrics.predict_token_bound == 512
                && card.fixed_seed_required
                && red_pass(&red_results, "ctx_size_unbounded")
                && red_pass(&red_results, "predict_unbounded")
                && red_pass(&red_results, "seed_missing"),
        ),
        (
            "digest_only_prompt_grammar_receipt_policy_bound",
            card.prompt_digest_required
                && card.grammar_or_json_digest_only
                && card.first_token_digest_only
                && metrics.required_receipt_field_count == 16
                && red_pass(&red_results, "prompt_digest_missing")
                && red_pass(&red_results, "grammar_digest_missing")
                && red_pass(&red_results, "first_token_digest_missing")
                && red_pass(&red_results, "missing_receipt_field")
                && red_pass(&red_results, "duplicate_receipt_field"),
        ),
        (
            "scope_rex_sovereign_gate_rollback_log_packet_bound",
            card.scope_rex_ref.starts_with("scope_rex:")
                && card.sovereign_gate_ref.starts_with("sovereign_gate:")
                && card.rollback_ref.starts_with("rollback:")
                && card.run_event_log_ref.starts_with("run_event_log:")
                && card.answer_packet_ref.starts_with("answer_packet:")
                && card.abstention_required
                && red_pass(&red_results, "scope_rex_missing")
                && red_pass(&red_results, "sovereign_gate_missing")
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "abstention_missing"),
        ),
        (
            "command_card_write_read_deferred",
            metrics.command_card_written_count == 0
                && metrics.command_card_bytes_written == 0
                && metrics.command_card_bytes_read == 0
                && red_pass(&red_results, "command_card_written")
                && red_pass(&red_results, "command_card_bytes_written")
                && red_pass(&red_results, "command_card_bytes_read"),
        ),
        (
            "zero_owner_path_command_process_server_network_model_runtime_provider_actions",
            metrics.owner_path_open_count == 0
                && metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && metrics.process_spawned_count == 0
                && metrics.server_started_count == 0
                && metrics.network_or_hub_or_endpoint_count == 0
                && metrics.file_open_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "owner_path_opened")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "process_spawned")
                && red_pass(&red_results, "server_started")
                && red_pass(&red_results, "network_allowed")
                && red_pass(&red_results, "hub_download_allowed")
                && red_pass(&red_results, "remote_endpoint_allowed")
                && red_pass(&red_results, "model_file_opened")
                && red_pass(&red_results, "llama_cli_opened")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made"),
        ),
        (
            "privacy_raw_path_prompt_stdio_token_denied",
            metrics.raw_private_bytes == 0
                && red_pass(&red_results, "raw_model_path")
                && red_pass(&red_results, "raw_prompt")
                && red_pass(&red_results, "raw_stdout")
                && red_pass(&red_results, "raw_stderr")
                && red_pass(&red_results, "raw_token"),
        ),
        (
            "no_route_system_g_settings_mutation",
            metrics.mutation_count == 0
                && red_pass(&red_results, "runtime_router_mutation")
                && red_pass(&red_results, "system_g_mutation")
                && red_pass(&red_results, "settings_default_mutation"),
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
            "no_quality_mas_l2_l3_t4_default_70b_or_ssd_claim",
            metrics.promotion_claim_count == 0
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "mas_l2_l3_t4_claim")
                && red_pass(&red_results, "gemma_default_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "gemma_first_runtime_proof_command_card_address_deterministic",
            card.command_card_address(CREATED_AT_MS)
                == reversed.command_card_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_NEXT_CURSOR
                == "gemma_direct_harness_first_runtime_proof_receipt_gate",
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
            "required_command_card_field_count",
            metrics.required_command_card_field_count,
            "==",
            37,
            "fields",
        ),
        (
            "allowed_argv_flag_count",
            metrics.allowed_argv_flag_count,
            "==",
            17,
            "flags",
        ),
        (
            "denied_argv_flag_count",
            metrics.denied_argv_flag_count,
            "==",
            22,
            "flags",
        ),
        (
            "required_receipt_field_count",
            metrics.required_receipt_field_count,
            "==",
            16,
            "fields",
        ),
        (
            "ctx_size_bound",
            metrics.ctx_size_bound,
            "==",
            8_192,
            "tokens",
        ),
        (
            "predict_token_bound",
            metrics.predict_token_bound,
            "==",
            512,
            "tokens",
        ),
        (
            "stdio_capture_cap_bytes",
            metrics.stdio_capture_cap_bytes,
            "==",
            65_536,
            "bytes",
        ),
        (
            "command_card_written_count",
            metrics.command_card_written_count,
            "==",
            0,
            "count",
        ),
        (
            "command_card_bytes_written",
            metrics.command_card_bytes_written,
            "==",
            0,
            "bytes",
        ),
        (
            "command_card_bytes_read",
            metrics.command_card_bytes_read,
            "==",
            0,
            "bytes",
        ),
        (
            "owner_path_open_count",
            metrics.owner_path_open_count,
            "==",
            0,
            "count",
        ),
        (
            "command_armed_count",
            metrics.command_armed_count,
            "==",
            0,
            "count",
        ),
        (
            "command_executed_count",
            metrics.command_executed_count,
            "==",
            0,
            "count",
        ),
        (
            "process_spawned_count",
            metrics.process_spawned_count,
            "==",
            0,
            "count",
        ),
        (
            "server_started_count",
            metrics.server_started_count,
            "==",
            0,
            "count",
        ),
        (
            "network_or_hub_or_endpoint_count",
            metrics.network_or_hub_or_endpoint_count,
            "==",
            0,
            "count",
        ),
        ("file_open_count", metrics.file_open_count, "==", 0, "count"),
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
            "count",
        ),
        (
            "raw_private_bytes",
            metrics.raw_private_bytes,
            "==",
            0,
            "bytes",
        ),
        ("mutation_count", metrics.mutation_count, "==", 0, "count"),
        (
            "hidden_authority_count",
            metrics.hidden_authority_count,
            "==",
            0,
            "count",
        ),
        (
            "promotion_claim_count",
            metrics.promotion_claim_count,
            "==",
            0,
            "count",
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
        "gemma_first_runtime_proof_command_card_address",
        &card.command_card_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_NEXT_CURSOR,
        "gemma_direct_harness_first_runtime_proof_receipt_gate",
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
        notes: "metadata-only F-GemmaDirectHarnessFirstRuntimeProofCommandCard: consumes the Gemma direct-harness RuntimeRouter admission packet gate and freezes the local GGUF first-runtime proof command-card contract. It allows only an owner-approved local llama-cli --offline -m path shape with single-turn, no-display-prompt, show-timings, bounded context and prediction, fixed seed, digest-only prompt/grammar/receipt evidence, bounded stdio caps, timeout/cancel/teardown, memory sampler, SCOPE-Rex, SovereignGate, rollback, RunEventLog, AnswerPacket, abstention, and non-promotion. It writes zero command-card bytes, opens zero owner/model/llama.cpp paths, arms or executes zero commands, spawns zero processes, starts zero servers, allows zero network/hub/endpoint route, loads zero model/runtime/provider bytes, captures zero raw path/prompt/stdout/stderr/token bytes, mutates no RuntimeRouter/System G/settings/default state, and makes no MAS/L2/L3/T4/user-facing, Gemma-default, quality, live dense 70B, or SSD-as-RAM claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_gate_pass(path: &str) -> Result<bool, Box<dyn std::error::Error>> {
    if !Path::new(path).exists() {
        return Ok(false);
    }
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(path)?)?;
    Ok(value
        .get("overall_pass")
        .and_then(|value| value.as_bool())
        .unwrap_or(false))
}

fn red_fixture_results(
    card: &GemmaDirectHarnessFirstRuntimeProofCommandCard,
) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaDirectHarnessFirstRuntimeProofCommandCard)>,
    )> = vec![
        (
            "bad_upstream_ref",
            Box::new(|c| {
                c.upstream_admission_ref = "artifact:falsifiers/wrong/result.json#wrong".to_string()
            }),
        ),
        (
            "bad_upstream_id",
            Box::new(|c| c.upstream_admission_id = "F-Wrong".to_string()),
        ),
        (
            "bad_artifact_root",
            Box::new(|c| c.artifact_root_prefix = "artifacts/falsifiers/wrong/".to_string()),
        ),
        (
            "bad_command_card_id",
            Box::new(|c| c.command_card_id = "wrong".to_string()),
        ),
        (
            "bad_future_command_card_name",
            Box::new(|c| c.future_command_card_name = "wrong".to_string()),
        ),
        (
            "bad_runtime_lane",
            Box::new(|c| c.runtime_lane = "gemma-hidden-server".to_string()),
        ),
        (
            "mas_product_build",
            Box::new(|c| c.product_build = ProductBuild::Mas),
        ),
        (
            "live_pro_status",
            Box::new(|c| c.pro_status = ProStatus::Live),
        ),
        (
            "metadata_too_large",
            Box::new(|c| c.metadata_bytes = 385 * 1024),
        ),
        (
            "missing_command_card_field",
            Box::new(|c| {
                c.required_command_card_fields.pop();
            }),
        ),
        (
            "duplicate_command_card_field",
            Box::new(|c| {
                c.required_command_card_fields[0] = c.required_command_card_fields[1].clone()
            }),
        ),
        (
            "missing_allowed_argv_flag",
            Box::new(|c| {
                c.allowed_argv_flags.pop();
            }),
        ),
        (
            "duplicate_allowed_argv_flag",
            Box::new(|c| c.allowed_argv_flags[0] = c.allowed_argv_flags[1].clone()),
        ),
        (
            "missing_denied_argv_flag",
            Box::new(|c| {
                c.denied_argv_flags.pop();
            }),
        ),
        (
            "duplicate_denied_argv_flag",
            Box::new(|c| c.denied_argv_flags[0] = c.denied_argv_flags[1].clone()),
        ),
        (
            "missing_receipt_field",
            Box::new(|c| {
                c.required_receipt_fields.pop();
            }),
        ),
        (
            "duplicate_receipt_field",
            Box::new(|c| c.required_receipt_fields[0] = c.required_receipt_fields[1].clone()),
        ),
        (
            "owner_approval_missing",
            Box::new(|c| c.owner_approval_required = false),
        ),
        (
            "selected_model_address_missing",
            Box::new(|c| c.selected_model_uas_address_required = false),
        ),
        (
            "local_model_file_missing",
            Box::new(|c| c.local_model_file_required = false),
        ),
        (
            "model_path_not_redacted",
            Box::new(|c| c.model_path_redacted = false),
        ),
        (
            "llama_cli_identity_missing",
            Box::new(|c| c.llama_cli_identity_required = false),
        ),
        (
            "local_m_flag_missing",
            Box::new(|c| c.local_m_flag_required = false),
        ),
        ("offline_missing", Box::new(|c| c.offline_required = false)),
        (
            "single_turn_missing",
            Box::new(|c| c.single_turn_required = false),
        ),
        (
            "no_display_prompt_missing",
            Box::new(|c| c.no_display_prompt_required = false),
        ),
        (
            "show_timings_missing",
            Box::new(|c| c.show_timings_required = false),
        ),
        (
            "ctx_size_unbounded",
            Box::new(|c| c.ctx_size_bound = 131_072),
        ),
        ("predict_unbounded", Box::new(|c| c.predict_token_bound = 0)),
        ("seed_missing", Box::new(|c| c.fixed_seed_required = false)),
        (
            "prompt_digest_missing",
            Box::new(|c| c.prompt_digest_required = false),
        ),
        (
            "grammar_digest_missing",
            Box::new(|c| c.grammar_or_json_digest_only = false),
        ),
        (
            "timeout_cancel_teardown_missing",
            Box::new(|c| c.timeout_cancel_teardown_required = false),
        ),
        (
            "stdio_cap_unbounded",
            Box::new(|c| c.stdio_capture_cap_bytes = 1_000_000),
        ),
        (
            "raw_stdio_allowed",
            Box::new(|c| c.raw_stdio_denied = false),
        ),
        (
            "first_token_digest_missing",
            Box::new(|c| c.first_token_digest_only = false),
        ),
        (
            "memory_sampler_missing",
            Box::new(|c| c.memory_sampler_required = false),
        ),
        (
            "scope_rex_missing",
            Box::new(|c| c.scope_rex_ref = "wrong".to_string()),
        ),
        (
            "sovereign_gate_missing",
            Box::new(|c| c.sovereign_gate_ref = "wrong".to_string()),
        ),
        (
            "rollback_missing",
            Box::new(|c| c.rollback_ref = "wrong".to_string()),
        ),
        (
            "run_event_log_missing",
            Box::new(|c| c.run_event_log_ref = "wrong".to_string()),
        ),
        (
            "answer_packet_missing",
            Box::new(|c| c.answer_packet_ref = "wrong".to_string()),
        ),
        (
            "abstention_missing",
            Box::new(|c| c.abstention_required = false),
        ),
        (
            "command_card_written",
            Box::new(|c| c.command_card_written_count = 1),
        ),
        (
            "command_card_bytes_written",
            Box::new(|c| c.command_card_bytes_written = 1),
        ),
        (
            "command_card_bytes_read",
            Box::new(|c| c.command_card_bytes_read = 1),
        ),
        (
            "owner_path_opened",
            Box::new(|c| c.owner_path_open_count = 1),
        ),
        (
            "model_file_opened",
            Box::new(|c| c.model_file_opened = true),
        ),
        ("llama_cli_opened", Box::new(|c| c.llama_cli_opened = true)),
        ("command_armed", Box::new(|c| c.command_armed = true)),
        ("command_executed", Box::new(|c| c.command_executed = true)),
        ("process_spawned", Box::new(|c| c.process_spawned = true)),
        ("server_started", Box::new(|c| c.server_started = true)),
        ("network_allowed", Box::new(|c| c.network_allowed = true)),
        (
            "hub_download_allowed",
            Box::new(|c| c.hub_download_allowed = true),
        ),
        (
            "remote_endpoint_allowed",
            Box::new(|c| c.remote_endpoint_allowed = true),
        ),
        ("model_bytes_loaded", Box::new(|c| c.model_bytes_loaded = 1)),
        (
            "runtime_bytes_loaded",
            Box::new(|c| c.runtime_bytes_loaded = 1),
        ),
        (
            "provider_calls_made",
            Box::new(|c| c.provider_calls_made = 1),
        ),
        ("raw_model_path", Box::new(|c| c.raw_model_path_bytes = 1)),
        ("raw_prompt", Box::new(|c| c.raw_prompt_bytes = 1)),
        ("raw_stdout", Box::new(|c| c.raw_stdout_bytes = 1)),
        ("raw_stderr", Box::new(|c| c.raw_stderr_bytes = 1)),
        ("raw_token", Box::new(|c| c.raw_token_bytes = 1)),
        (
            "runtime_router_mutation",
            Box::new(|c| c.runtime_router_mutation_allowed = true),
        ),
        (
            "system_g_mutation",
            Box::new(|c| c.system_g_mutation_allowed = true),
        ),
        (
            "settings_default_mutation",
            Box::new(|c| c.settings_or_default_mutation_allowed = true),
        ),
        (
            "hidden_route_authority",
            Box::new(|c| c.hidden_route_authority = true),
        ),
        (
            "hidden_eidos_authority",
            Box::new(|c| c.hidden_eidos_authority = true),
        ),
        (
            "hidden_lattice_authority",
            Box::new(|c| c.hidden_lattice_authority = true),
        ),
        (
            "hidden_patternboost_authority",
            Box::new(|c| c.hidden_patternboost_authority = true),
        ),
        (
            "hidden_cloud_fallback",
            Box::new(|c| c.hidden_cloud_fallback = true),
        ),
        ("quality_claim", Box::new(|c| c.quality_claimed = true)),
        (
            "mas_l2_l3_t4_claim",
            Box::new(|c| {
                c.mas_promoted = true;
                c.l2_capability_effect = true;
                c.l3_wrv_effect = true;
                c.t4_build_green_effect = true;
            }),
        ),
        (
            "gemma_default_claim",
            Box::new(|c| c.live_gemma_default_claim = true),
        ),
        (
            "live_dense_70b_claim",
            Box::new(|c| c.live_dense_70b_claim = true),
        ),
        ("ssd_as_ram_claim", Box::new(|c| c.ssd_as_ram_claim = true)),
        (
            "wrong_next_cursor",
            Box::new(|c| c.next_cursor = "wrong_next".to_string()),
        ),
    ];
    cases
        .into_iter()
        .map(|(name, mutate)| {
            let mut mutated = card.clone();
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
    for axis in GEMMA_DIRECT_HARNESS_FIRST_RUNTIME_PROOF_COMMAND_CARD_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
