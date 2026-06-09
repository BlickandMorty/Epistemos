//! `falsify_gemma_direct_harness_owner_approved_runtime_router_admission_packet_gate`
//!
//! Metadata-only admission contract for future Gemma direct-harness
//! RuntimeRouter/System G evidence. It reads only the upstream quality-packet
//! witness, opens no model or runtime bytes, and performs no route mutation.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate, ProStatus, ProductBuild,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_ID,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_NEXT_CURSOR,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_UPSTREAM_REF,
};

const FALSIFIER_ID: &str =
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_ID;
const FIXTURE_ID: &str =
    "gemma_direct_harness_owner_approved_runtime_router_admission_packet_gate_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_gemma_direct_harness_owner_approved_runtime_router_admission_packet_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_direct_harness_owner_approved_runtime_router_admission_packet_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_direct_harness_owner_approved_same_fixture_quality_packet_gate/result.json";
const CREATED_AT_MS: u64 = 1_779_926_400_000;

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
        "{FALSIFIER_ID}: overall_pass={} admission_fields={} admission_performed={} mutation_count={} model_bytes_loaded={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["required_admission_field_count"].value,
        artifact.measurements["admission_performed_count"].value,
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
    let upstream_pass = upstream_gate_pass(UPSTREAM_RESULT)?;
    let gate = GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate::canonical();
    gate.validate()?;
    let reversed = GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate {
        required_admission_fields: gate
            .required_admission_fields
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
        ("upstream_quality_packet_gate_pass", upstream_pass),
        (
            "upstream_quality_packet_ref_bound",
            gate.upstream_quality_packet_ref
                == GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_UPSTREAM_REF,
        ),
        (
            "direct_harness_runtime_lane_bound",
            gate.runtime_lane == "gemma-direct-harness-llama-cpp-gguf-pro-gated"
                && red_pass(&red_results, "bad_runtime_lane"),
        ),
        (
            "admission_fields_and_rejection_policies_bound",
            metrics.required_admission_field_count == 32
                && metrics.required_rejection_policy_count == 55
                && red_pass(&red_results, "missing_admission_field")
                && red_pass(&red_results, "duplicate_admission_field")
                && red_pass(&red_results, "missing_rejection_policy")
                && red_pass(&red_results, "duplicate_rejection_policy"),
        ),
        (
            "quality_packet_and_summary_requirements_bound",
            gate.upstream_quality_packet_digest_required
                && gate.owner_approval_digest_required
                && gate.redacted_receipt_digest_required
                && gate.first_token_review_digest_required
                && gate.quality_summary_digest_required
                && gate.failure_taxonomy_digest_required
                && gate.runtime_lane_digest_required
                && gate.model_and_llama_identity_required
                && gate.prompt_tokenizer_template_digest_required
                && red_pass(&red_results, "upstream_digest_missing")
                && red_pass(&red_results, "owner_approval_missing")
                && red_pass(&red_results, "redacted_receipt_missing")
                && red_pass(&red_results, "first_token_review_missing")
                && red_pass(&red_results, "quality_summary_missing")
                && red_pass(&red_results, "failure_taxonomy_missing")
                && red_pass(&red_results, "runtime_lane_digest_missing")
                && red_pass(&red_results, "model_llama_identity_missing")
                && red_pass(&red_results, "prompt_tokenizer_template_missing"),
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
                && gate.no_default_model_mutation_bound
                && gate.no_hidden_authority_bound
                && gate.non_promotion_bound
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "visible_caveat_missing")
                && red_pass(&red_results, "settings_visibility_missing")
                && red_pass(&red_results, "diagnostic_visibility_missing")
                && red_pass(&red_results, "default_model_mutation_bound_missing")
                && red_pass(&red_results, "hidden_authority_bound_missing")
                && red_pass(&red_results, "non_promotion_bound_missing"),
        ),
        (
            "admission_packet_deferred",
            metrics.future_admission_packet_present_count == 0
                && metrics.future_admission_packet_bytes_read == 0
                && metrics.admission_performed_count == 0
                && red_pass(&red_results, "future_admission_packet_present")
                && red_pass(&red_results, "future_admission_packet_bytes_read")
                && red_pass(&red_results, "admission_performed"),
        ),
        (
            "zero_route_mutation_command_model_runtime_provider_actions",
            metrics.route_priority_mutation_count == 0
                && metrics.mutation_count == 0
                && metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && metrics.process_spawned_count == 0
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
                && red_pass(&red_results, "process_spawned")
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
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim")
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "benchmark_fit_claim"),
        ),
        (
            "gemma_direct_harness_runtime_router_admission_address_deterministic",
            gate.admission_gate_address(CREATED_AT_MS)
                == reversed.admission_gate_address(CREATED_AT_MS),
        ),
        (
            "next_cursor_bound",
            GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_NEXT_CURSOR
                == "gemma_direct_harness_owner_approved_system_g_dry_run_route_packet_gate",
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
            "required_admission_field_count",
            metrics.required_admission_field_count,
            "==",
            32,
            "fields",
        ),
        (
            "required_rejection_policy_count",
            metrics.required_rejection_policy_count,
            "==",
            55,
            "policies",
        ),
        (
            "future_admission_packet_present_count",
            metrics.future_admission_packet_present_count,
            "==",
            0,
            "packets",
        ),
        (
            "future_admission_packet_bytes_read",
            metrics.future_admission_packet_bytes_read,
            "==",
            0,
            "bytes",
        ),
        (
            "admission_performed_count",
            metrics.admission_performed_count,
            "==",
            0,
            "admissions",
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
            "process_spawned_count",
            metrics.process_spawned_count,
            "==",
            0,
            "processes",
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
            "packets",
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
            70,
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
        "gemma_direct_harness_runtime_router_admission_gate_address",
        &gate.admission_gate_address(CREATED_AT_MS).to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_NEXT_CURSOR,
        "gemma_direct_harness_owner_approved_system_g_dry_run_route_packet_gate",
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
        notes: "metadata-only F-GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate: consumes the Gemma direct-harness same-fixture quality packet gate and freezes the fail-closed RuntimeRouter/System G admission packet contract. It binds owner approval, quality summary, failure taxonomy, budget vector, memory/KV/latency budgets, privacy class, MAS/Pro boundary, SCOPE-Rex, SovereignGate, fallback, abstention, cancellation, rollback, RunEventLog, AnswerPacket, visible caveat, settings and diagnostics visibility, no default-model mutation, no hidden authority, and non-promotion. It reads zero admission packet bytes, performs zero admission, mutates zero route priority/RuntimeRouter/System G/default model state, arms or executes zero commands, spawns zero processes, loads zero model/runtime/provider bytes, captures zero raw prompt/output bytes, suppresses zero AnswerPackets, and makes no MAS/L2/L3/T4/user-facing, Gemma-default, quality, benchmark-fit, live-70B, or SSD-as-RAM claim.".to_string(),
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
    gate: &GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate,
) -> Vec<(&'static str, bool)> {
    let cases: Vec<(
        &'static str,
        Box<dyn Fn(&mut GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate)>,
    )> = vec![
        (
            "bad_upstream_ref",
            Box::new(|g| {
                g.upstream_quality_packet_ref =
                    "artifact:falsifiers/wrong/result.json#wrong".to_string()
            }),
        ),
        (
            "bad_upstream_id",
            Box::new(|g| g.upstream_quality_packet_id = "F-Wrong".to_string()),
        ),
        (
            "bad_artifact_root",
            Box::new(|g| g.artifact_root_prefix = "artifacts/falsifiers/wrong/".to_string()),
        ),
        (
            "bad_admission_card",
            Box::new(|g| g.admission_card_id = "wrong-card".to_string()),
        ),
        (
            "bad_future_admission_packet_name",
            Box::new(|g| g.future_admission_packet_name = "wrong-packet".to_string()),
        ),
        (
            "bad_runtime_lane",
            Box::new(|g| g.runtime_lane = "hidden-server-lane".to_string()),
        ),
        (
            "mas_product_build",
            Box::new(|g| g.product_build = ProductBuild::Mas),
        ),
        (
            "live_pro_status",
            Box::new(|g| g.pro_status = ProStatus::Live),
        ),
        (
            "metadata_too_large",
            Box::new(|g| g.metadata_bytes = 321 * 1024),
        ),
        (
            "missing_admission_field",
            Box::new(|g| {
                g.required_admission_fields.pop();
            }),
        ),
        (
            "duplicate_admission_field",
            Box::new(|g| {
                g.required_admission_fields[0] = g.required_admission_fields[1].clone();
            }),
        ),
        (
            "missing_rejection_policy",
            Box::new(|g| {
                g.required_rejection_policies.pop();
            }),
        ),
        (
            "duplicate_rejection_policy",
            Box::new(|g| {
                g.required_rejection_policies[0] = g.required_rejection_policies[1].clone();
            }),
        ),
        (
            "upstream_digest_missing",
            Box::new(|g| g.upstream_quality_packet_digest_required = false),
        ),
        (
            "owner_approval_missing",
            Box::new(|g| g.owner_approval_digest_required = false),
        ),
        (
            "redacted_receipt_missing",
            Box::new(|g| g.redacted_receipt_digest_required = false),
        ),
        (
            "first_token_review_missing",
            Box::new(|g| g.first_token_review_digest_required = false),
        ),
        (
            "quality_summary_missing",
            Box::new(|g| g.quality_summary_digest_required = false),
        ),
        (
            "failure_taxonomy_missing",
            Box::new(|g| g.failure_taxonomy_digest_required = false),
        ),
        (
            "runtime_lane_digest_missing",
            Box::new(|g| g.runtime_lane_digest_required = false),
        ),
        (
            "model_llama_identity_missing",
            Box::new(|g| g.model_and_llama_identity_required = false),
        ),
        (
            "prompt_tokenizer_template_missing",
            Box::new(|g| g.prompt_tokenizer_template_digest_required = false),
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
            Box::new(|g| g.scope_rex_verdict_ref = "wrong".to_string()),
        ),
        (
            "sovereign_gate_missing",
            Box::new(|g| g.sovereign_gate_verdict_ref = "wrong".to_string()),
        ),
        (
            "fallback_hidden",
            Box::new(|g| g.fallback_route_ref = "wrong".to_string()),
        ),
        (
            "abstention_disabled",
            Box::new(|g| g.abstention_policy_ref = "wrong".to_string()),
        ),
        (
            "cancellation_missing",
            Box::new(|g| g.cancellation_policy_ref = "wrong".to_string()),
        ),
        (
            "rollback_missing",
            Box::new(|g| g.rollback_ref = "wrong".to_string()),
        ),
        (
            "run_event_log_missing",
            Box::new(|g| g.run_event_log_ref = "wrong".to_string()),
        ),
        (
            "answer_packet_missing",
            Box::new(|g| g.answer_packet_ref = "wrong".to_string()),
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
            "default_model_mutation_bound_missing",
            Box::new(|g| g.no_default_model_mutation_bound = false),
        ),
        (
            "hidden_authority_bound_missing",
            Box::new(|g| g.no_hidden_authority_bound = false),
        ),
        (
            "non_promotion_bound_missing",
            Box::new(|g| g.non_promotion_bound = false),
        ),
        (
            "future_admission_packet_present",
            Box::new(|g| g.future_admission_packet_present = true),
        ),
        (
            "future_admission_packet_bytes_read",
            Box::new(|g| g.future_admission_packet_bytes_read = 1),
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
        ("process_spawned", Box::new(|g| g.process_spawned = true)),
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
        ("quality_claim", Box::new(|g| g.quality_claimed = true)),
        (
            "benchmark_fit_claim",
            Box::new(|g| g.benchmark_claimed_as_fit = true),
        ),
        (
            "mas_l2_l3_t4_product_claim",
            Box::new(|g| {
                g.mas_promoted = true;
                g.l2_capability_effect = true;
                g.l3_wrv_effect = true;
                g.t4_build_green_effect = true;
                g.product_route_green = true;
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
            "live_dense_70b_claim",
            Box::new(|g| g.live_dense_70b_claim = true),
        ),
        ("ssd_as_ram_claim", Box::new(|g| g.ssd_as_ram_claim = true)),
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
    for axis in GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_AXES {
        assert!(
            measurements.contains_key(*axis),
            "missing axis {axis} in {FALSIFIER_ID}"
        );
    }
}
