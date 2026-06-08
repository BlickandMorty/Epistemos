//! `falsify_gemma_qat_e2b_system_g_dry_run_route_packet_gate`
//!
//! Metadata-only route-packet contract for future Gemma E2B System G dry-run
//! evidence. It reads only the upstream admission witness, opens no model or
//! runtime bytes, emits no route, and performs no RuntimeRouter/System G
//! mutation.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaQatE2bSystemGDryRunRoutePacketGate, GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
    GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_ID,
    GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_NEXT_CURSOR,
    GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_UPSTREAM_REF,
    GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH,
};

const FALSIFIER_ID: &str = GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_ID;
const FIXTURE_ID: &str = "gemma_qat_e2b_system_g_dry_run_route_packet_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_qat_e2b_system_g_dry_run_route_packet_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_system_g_dry_run_route_packet_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_e2b_runtime_router_admission_packet_gate/result.json";
const CREATED_AT_MS: u64 = 1_779_495_600_000;

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
        "{FALSIFIER_ID}: overall_pass={} route_fields={} dry_run_performed={} mutation_count={} model_bytes_loaded={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_route_field_count"].value,
        artifact.measurements["system_g_dry_run_performed_count"].value,
        artifact.measurements["mutation_count"].value,
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
    let gate = GemmaQatE2bSystemGDryRunRoutePacketGate::canonical(
        GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_UPSTREAM_REF,
    );
    gate.validate()?;
    let reversed = GemmaQatE2bSystemGDryRunRoutePacketGate {
        required_route_fields: gate.required_route_fields.iter().cloned().rev().collect(),
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
        ("upstream_admission_packet_gate_pass", upstream_pass),
        (
            "upstream_admission_packet_ref_bound",
            gate.upstream_admission_packet_ref
                == GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_UPSTREAM_REF,
        ),
        (
            "single_e2b_gguf_llama_cpp_dry_run_route_lane_bound",
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
            "route_fields_and_rejection_policies_bound",
            metrics.required_route_field_count == 29
                && metrics.required_rejection_policy_count == 56
                && red_pass(&red_results, "missing_route_field")
                && red_pass(&red_results, "missing_rejection_policy"),
        ),
        (
            "route_packet_and_policy_requirements_bound",
            gate.upstream_admission_packet_digest_required
                && gate.route_packet_digest_required
                && gate.system_g_dry_run_envelope_digest_required
                && gate.runtime_router_policy_digest_required
                && gate.route_priority_snapshot_digest_required
                && gate.no_priority_mutation_digest_required
                && red_pass(&red_results, "upstream_digest_missing")
                && red_pass(&red_results, "route_packet_digest_missing")
                && red_pass(&red_results, "dry_run_envelope_missing")
                && red_pass(&red_results, "runtime_router_policy_missing")
                && red_pass(&red_results, "route_priority_snapshot_missing")
                && red_pass(&red_results, "no_priority_mutation_missing"),
        ),
        (
            "budget_privacy_and_build_boundary_bound",
            gate.budget_vector_bound
                && gate.memory_headroom_bound
                && gate.kv_budget_bound
                && gate.latency_budget_bound
                && gate.privacy_class_bound
                && gate.mas_pro_boundary_bound
                && red_pass(&red_results, "budget_vector_missing")
                && red_pass(&red_results, "memory_headroom_missing")
                && red_pass(&red_results, "kv_budget_missing")
                && red_pass(&red_results, "latency_budget_missing")
                && red_pass(&red_results, "privacy_class_missing")
                && red_pass(&red_results, "mas_pro_boundary_missing"),
        ),
        (
            "scope_rex_sovereign_gate_and_abstention_bound",
            gate.scope_rex_verdict_ref.starts_with("scope_rex:")
                && gate
                    .sovereign_gate_verdict_ref
                    .starts_with("sovereign_gate:")
                && gate.fallback_route_ref.starts_with("fallback:")
                && gate.abstention_policy_ref.starts_with("abstention:")
                && gate.cancellation_policy_ref.starts_with("cancel:")
                && red_pass(&red_results, "scope_rex_missing")
                && red_pass(&red_results, "sovereign_gate_missing")
                && red_pass(&red_results, "fallback_hidden")
                && red_pass(&red_results, "abstention_disabled")
                && red_pass(&red_results, "cancellation_missing"),
        ),
        (
            "rollback_run_event_answer_packet_visibility_bound",
            gate.rollback_ref.starts_with("rollback:")
                && gate.run_event_log_ref.starts_with("run_event_log:")
                && gate.answer_packet_ref.starts_with("answer_packet:")
                && gate.visible_caveat_digest_required
                && gate.settings_visibility_digest_required
                && gate.diagnostic_visibility_digest_required
                && gate.route_explanation_digest_required
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "visible_caveat_missing")
                && red_pass(&red_results, "settings_visibility_missing")
                && red_pass(&red_results, "diagnostic_visibility_missing")
                && red_pass(&red_results, "route_explanation_missing"),
        ),
        (
            "route_packet_deferred",
            metrics.future_route_packet_present_count == 0
                && metrics.future_route_packet_bytes_read == 0
                && metrics.system_g_dry_run_performed_count == 0
                && metrics.admission_performed_count == 0
                && red_pass(&red_results, "future_route_packet_present")
                && red_pass(&red_results, "future_route_packet_bytes_read")
                && red_pass(&red_results, "system_g_dry_run_performed")
                && red_pass(&red_results, "admission_performed"),
        ),
        (
            "zero_route_mutation_command_model_runtime_provider_actions",
            metrics.route_priority_mutation_count == 0
                && metrics.mutation_count == 0
                && metrics.command_executed_count == 0
                && metrics.runtime_replay_performed_count == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "route_priority_mutation")
                && red_pass(&red_results, "runtime_router_mutation")
                && red_pass(&red_results, "system_g_mutation")
                && red_pass(&red_results, "default_model_mutation")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "runtime_replay_performed")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made"),
        ),
        (
            "privacy_and_answer_packet_visibility_preserved",
            metrics.raw_prompt_bytes_captured == 0
                && metrics.raw_output_bytes_captured == 0
                && metrics.answer_packet_suppressed_count == 0
                && red_pass(&red_results, "raw_prompt_captured")
                && red_pass(&red_results, "raw_output_captured")
                && red_pass(&red_results, "answer_packet_suppressed"),
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
            "gemma_e2b_system_g_dry_run_route_packet_address_deterministic",
            gate.route_packet_gate_address(CREATED_AT_MS)
                == reversed.route_packet_gate_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_NEXT_CURSOR
                == "gemma_qat_e2b_route_answer_packet_visibility_gate",
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
            "required_route_field_count",
            metrics.required_route_field_count,
            "==",
            29,
            "fields",
        ),
        (
            "required_rejection_policy_count",
            metrics.required_rejection_policy_count,
            "==",
            56,
            "policies",
        ),
        (
            "future_route_packet_present_count",
            metrics.future_route_packet_present_count,
            "==",
            0,
            "packets",
        ),
        (
            "future_route_packet_bytes_read",
            metrics.future_route_packet_bytes_read,
            "==",
            0,
            "bytes",
        ),
        (
            "system_g_dry_run_performed_count",
            metrics.system_g_dry_run_performed_count,
            "==",
            0,
            "actions",
        ),
        (
            "admission_performed_count",
            metrics.admission_performed_count,
            "==",
            0,
            "actions",
        ),
        (
            "route_priority_mutation_count",
            metrics.route_priority_mutation_count,
            "==",
            0,
            "mutations",
        ),
        (
            "mutation_count",
            metrics.mutation_count,
            "==",
            0,
            "mutations",
        ),
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
            "raw_prompt_bytes_captured",
            metrics.raw_prompt_bytes_captured,
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
            "answer_packet_suppressed_count",
            metrics.answer_packet_suppressed_count,
            "==",
            0,
            "suppressed",
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
            68,
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
        "gemma_e2b_system_g_dry_run_route_packet_gate_address",
        &gate.route_packet_gate_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_NEXT_CURSOR,
        "gemma_qat_e2b_route_answer_packet_visibility_gate",
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
        notes: "metadata-only F-GemmaQATE2BSystemGDryRunRoutePacketGate: consumes the E2B RuntimeRouter admission packet gate and defines the fail-closed System G dry-run route packet before Gemma E2B can emit route evidence. It binds route packet digest, System G dry-run envelope, RuntimeRouter policy, route-priority snapshot, no-priority-mutation proof, budgets, privacy, MAS/Pro boundary, SCOPE-Rex, SovereignGate, fallback, abstention, cancellation, rollback, RunEventLog, AnswerPacket, settings/diagnostic visibility, route explanation, and non-promotion. It reads zero route packet bytes, performs zero dry-run or admission actions, mutates zero routes, arms or executes zero commands, loads zero model/runtime/provider bytes, captures zero raw prompt/output bytes, suppresses zero AnswerPackets, and makes no MAS/L2/L3/T4/user-facing, Gemma-default, quality, benchmark-fit, E4B/12B/70B bypass, live-70B, or SSD-as-RAM claim.".to_string(),
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
    gate: &GemmaQatE2bSystemGDryRunRoutePacketGate,
) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaQatE2bSystemGDryRunRoutePacketGate)>,
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
            "bad_upstream_admission_ref",
            Box::new(|g| {
                g.upstream_admission_packet_ref = "artifact:falsifiers/wrong/".to_string()
            }),
        ),
        (
            "bad_upstream_admission_id",
            Box::new(|g| g.upstream_admission_packet_id = "F-Wrong".to_string()),
        ),
        (
            "bad_upstream_quality_ref",
            Box::new(|g| {
                g.upstream_quality_packet_ref =
                    "artifact:falsifiers/wrong/result.json#F-Wrong".to_string()
            }),
        ),
        (
            "bad_artifact_root",
            Box::new(|g| g.artifact_root_prefix = "artifacts/falsifiers/wrong/".to_string()),
        ),
        (
            "bad_route_card_id",
            Box::new(|g| g.route_card_id = "wrong-card".to_string()),
        ),
        (
            "bad_future_packet_name",
            Box::new(|g| g.future_route_packet_name = "wrong-packet".to_string()),
        ),
        (
            "missing_route_field",
            Box::new(|g| {
                g.required_route_fields.pop();
            }),
        ),
        (
            "missing_rejection_policy",
            Box::new(|g| {
                g.required_rejection_policies.pop();
            }),
        ),
        (
            "upstream_digest_missing",
            Box::new(|g| g.upstream_admission_packet_digest_required = false),
        ),
        (
            "route_packet_digest_missing",
            Box::new(|g| g.route_packet_digest_required = false),
        ),
        (
            "dry_run_envelope_missing",
            Box::new(|g| g.system_g_dry_run_envelope_digest_required = false),
        ),
        (
            "runtime_router_policy_missing",
            Box::new(|g| g.runtime_router_policy_digest_required = false),
        ),
        (
            "route_priority_snapshot_missing",
            Box::new(|g| g.route_priority_snapshot_digest_required = false),
        ),
        (
            "no_priority_mutation_missing",
            Box::new(|g| g.no_priority_mutation_digest_required = false),
        ),
        (
            "budget_vector_missing",
            Box::new(|g| g.budget_vector_bound = false),
        ),
        (
            "memory_headroom_missing",
            Box::new(|g| g.memory_headroom_bound = false),
        ),
        ("kv_budget_missing", Box::new(|g| g.kv_budget_bound = false)),
        (
            "latency_budget_missing",
            Box::new(|g| g.latency_budget_bound = false),
        ),
        (
            "privacy_class_missing",
            Box::new(|g| g.privacy_class_bound = false),
        ),
        (
            "mas_pro_boundary_missing",
            Box::new(|g| g.mas_pro_boundary_bound = false),
        ),
        (
            "scope_rex_missing",
            Box::new(|g| g.scope_rex_verdict_ref = "missing".to_string()),
        ),
        (
            "sovereign_gate_missing",
            Box::new(|g| g.sovereign_gate_verdict_ref = "missing".to_string()),
        ),
        (
            "fallback_hidden",
            Box::new(|g| g.fallback_route_ref = "hidden".to_string()),
        ),
        (
            "abstention_disabled",
            Box::new(|g| g.abstention_policy_ref = "none".to_string()),
        ),
        (
            "cancellation_missing",
            Box::new(|g| g.cancellation_policy_ref = "missing".to_string()),
        ),
        (
            "rollback_missing",
            Box::new(|g| g.rollback_ref = "missing".to_string()),
        ),
        (
            "run_event_log_missing",
            Box::new(|g| g.run_event_log_ref = "missing".to_string()),
        ),
        (
            "answer_packet_missing",
            Box::new(|g| g.answer_packet_ref = "missing".to_string()),
        ),
        (
            "visible_caveat_missing",
            Box::new(|g| g.visible_caveat_digest_required = false),
        ),
        (
            "settings_visibility_missing",
            Box::new(|g| g.settings_visibility_digest_required = false),
        ),
        (
            "diagnostic_visibility_missing",
            Box::new(|g| g.diagnostic_visibility_digest_required = false),
        ),
        (
            "route_explanation_missing",
            Box::new(|g| g.route_explanation_digest_required = false),
        ),
        (
            "future_route_packet_present",
            Box::new(|g| g.future_route_packet_present = true),
        ),
        (
            "future_route_packet_bytes_read",
            Box::new(|g| g.future_route_packet_bytes_read = 1),
        ),
        (
            "system_g_dry_run_performed",
            Box::new(|g| g.system_g_dry_run_performed_count = 1),
        ),
        (
            "admission_performed",
            Box::new(|g| g.admission_performed_count = 1),
        ),
        (
            "route_priority_mutation",
            Box::new(|g| g.route_priority_mutation_count = 1),
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
            "default_model_mutation",
            Box::new(|g| g.default_model_mutation_allowed = true),
        ),
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
        (
            "raw_prompt_captured",
            Box::new(|g| g.raw_prompt_bytes_captured = 1),
        ),
        (
            "raw_output_captured",
            Box::new(|g| g.raw_output_bytes_captured = 1),
        ),
        (
            "answer_packet_suppressed",
            Box::new(|g| g.answer_packet_suppressed = true),
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
        (
            "metadata_budget_overflow",
            Box::new(|g| g.metadata_bytes = 400 * 1024),
        ),
        (
            "wrong_product_build",
            Box::new(|g| g.product_build = agent_core::uas::ProductBuild::Mas),
        ),
        (
            "wrong_pro_status",
            Box::new(|g| g.pro_status = agent_core::uas::ProStatus::Live),
        ),
        (
            "wrong_next_cursor",
            Box::new(|g| g.next_cursor = "wrong_next".to_string()),
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
    for axis in GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
