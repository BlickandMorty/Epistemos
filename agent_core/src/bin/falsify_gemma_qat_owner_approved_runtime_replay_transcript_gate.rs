//! `falsify_gemma_qat_owner_approved_runtime_replay_transcript_gate`
//!
//! Metadata-only witness for
//! `F-GemmaQATOwnerApprovedRuntimeReplayTranscriptGate`. It consumes the Gemma
//! held-out quality packet and binds owner-approval-pending runtime replay
//! transcript templates before any runtime replay or default-model claim.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_TRANSCRIPT_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_gemma_qat_owner_approved_runtime_replay_transcript_cards, GemmaFamilyRuntimeLane,
    GemmaQatOwnerApprovedRuntimeReplayTranscriptCard,
    GemmaQatOwnerApprovedRuntimeReplayTranscriptLedger,
    GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_TRANSCRIPT_GATE_ID,
    GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_TRANSCRIPT_GATE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_TRANSCRIPT_GATE_ID;
const FIXTURE_ID: &str = "gemma_qat_owner_approved_runtime_replay_transcript_gate_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_gemma_qat_owner_approved_runtime_replay_transcript_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/gemma_qat_owner_approved_runtime_replay_transcript_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_held_out_quality_replay_packet/result.json";
const UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_qat_held_out_quality_replay_packet/result.json#F-GemmaQATHeldOutQualityReplayPacket";
const CREATED_AT_MS: u64 = 1_779_215_200_000;
const LEDGER_METADATA_BYTES: u64 = 144_000;

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
        "{FALSIFIER_ID}: overall_pass={} card_count={} selected_first_probe={} command_executed={} model_bytes_loaded_total={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["runtime_replay_transcript_card_count"].value,
        artifact.measurements["selected_first_probe_candidate_count"].value,
        artifact.measurements["command_executed_count"].value,
        artifact.measurements["model_bytes_loaded_total"].value,
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
    let upstream_pass = upstream_held_out_quality_pass()?;
    let cards = canonical_gemma_qat_owner_approved_runtime_replay_transcript_cards(UPSTREAM_REF);
    let ledger = build_ledger(cards.clone())?;
    let reversed = GemmaQatOwnerApprovedRuntimeReplayTranscriptLedger::new(
        UPSTREAM_REF,
        cards.iter().cloned().rev().collect(),
        LEDGER_METADATA_BYTES,
        CREATED_AT_MS,
    )?;
    let metrics = ledger.metrics();
    let red_results = red_fixture_results(&cards);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_gemma_held_out_quality_replay_pass", upstream_pass),
        (
            "accepted_runtime_replay_transcript_gate_pack_present",
            has_card(
                &cards,
                "gemma4_e2b_gguf_llama_cpp_runtime_replay_transcript_gate",
            ) && has_card(
                &cards,
                "gemma4_e2b_litert_lm_runtime_replay_transcript_gate",
            ) && has_card(
                &cards,
                "gemma4_e4b_gguf_llama_cpp_runtime_replay_transcript_gate",
            ) && has_card(
                &cards,
                "gemma4_e4b_litert_lm_runtime_replay_transcript_gate",
            ),
        ),
        (
            "e2b_e4b_gguf_litert_coverage_bound",
            metrics.e2b_card_count == 2
                && metrics.e4b_card_count == 2
                && metrics.gguf_lane_count == 2
                && metrics.litert_lane_count == 2
                && red_pass(&red_results, "twelve_b_inserted")
                && red_pass(&red_results, "bad_runtime_lane"),
        ),
        (
            "single_smallest_first_probe_candidate_bound",
            metrics.selected_first_probe_candidate_count == 1
                && cards.iter().any(|card| {
                    card.selected_first_probe_candidate
                        && card.model_id.contains("E2B")
                        && card.runtime_lane == GemmaFamilyRuntimeLane::GgufLlamaCpp
                })
                && red_pass(&red_results, "missing_first_probe_candidate")
                && red_pass(&red_results, "too_many_first_probe_candidates"),
        ),
        (
            "owner_approval_pending_and_required",
            metrics.owner_approval_required_count == 4
                && metrics.owner_approval_granted_count == 0
                && red_pass(&red_results, "owner_approval_not_required")
                && red_pass(&red_results, "owner_approval_granted"),
        ),
        (
            "command_envelope_visible_unarmed_unexecuted",
            metrics.command_envelope_visible_count == 4
                && metrics.command_armed_count == 0
                && metrics.command_executed_count == 0
                && red_pass(&red_results, "command_envelope_hidden")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed"),
        ),
        (
            "transcript_template_and_memory_sample_bound",
            metrics.transcript_template_visible_count == 4
                && metrics.memory_sample_required_count == 4
                && red_pass(&red_results, "transcript_template_hidden")
                && red_pass(&red_results, "memory_sample_missing")
                && red_pass(&red_results, "memory_sample_freshness_missing"),
        ),
        (
            "prompt_output_digest_policy_bound",
            metrics.prompt_digest_policy_bound_count == 4
                && metrics.output_digest_policy_bound_count == 4
                && red_pass(&red_results, "prompt_digest_policy_missing")
                && red_pass(&red_results, "output_digest_policy_missing"),
        ),
        (
            "privacy_raw_output_and_stdio_bound",
            cards.iter().all(|card| {
                card.raw_prompt_denied && card.raw_output_denied && card.stdout_stderr_denied
            }) && red_pass(&red_results, "raw_prompt_allowed")
                && red_pass(&red_results, "raw_output_allowed")
                && red_pass(&red_results, "stdio_allowed"),
        ),
        (
            "cancellation_rollback_log_packet_abstention_bound",
            cards.iter().all(|card| {
                card.cancellation_bound
                    && card.rollback_bound
                    && card.run_event_log_bound
                    && card.answer_packet_bound
                    && card.abstention_bound
            }) && red_pass(&red_results, "cancellation_missing")
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "abstention_missing"),
        ),
        (
            "runtime_replay_deferred",
            metrics.runtime_replay_performed_count == 0
                && red_pass(&red_results, "runtime_replay_performed"),
        ),
        (
            "zero_model_runtime_provider_command_scorer_bytes",
            metrics.model_bytes_loaded_total == 0
                && metrics.runtime_bytes_loaded_total == 0
                && metrics.provider_calls_made_total == 0
                && metrics.command_executed_count == 0
                && metrics.scorer_execution_count_total == 0
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_call")
                && red_pass(&red_results, "scorer_execution"),
        ),
        (
            "zero_raw_prompt_output_stdio_file_bytes",
            metrics.opened_model_file_bytes_total == 0
                && metrics.opened_runtime_file_bytes_total == 0
                && metrics.captured_raw_prompt_bytes_total == 0
                && metrics.captured_raw_output_bytes_total == 0
                && metrics.captured_stdout_bytes_total == 0
                && metrics.captured_stderr_bytes_total == 0
                && red_pass(&red_results, "opened_model_file_bytes")
                && red_pass(&red_results, "opened_runtime_file_bytes")
                && red_pass(&red_results, "captured_raw_prompt_bytes")
                && red_pass(&red_results, "captured_raw_output_bytes")
                && red_pass(&red_results, "captured_stdout_bytes")
                && red_pass(&red_results, "captured_stderr_bytes"),
        ),
        (
            "no_runtime_router_or_system_g_mutation",
            cards.iter().all(|card| {
                !card.runtime_router_mutation_allowed && !card.system_g_mutation_allowed
            }) && red_pass(&red_results, "runtime_router_mutation")
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
                && metrics.quality_claim_count == 0
                && red_pass(&red_results, "mas_l2_l3_product_claim")
                && red_pass(&red_results, "live_gemma_default_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim")
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "benchmark_fit_claim"),
        ),
        (
            "runtime_replay_transcript_ledger_address_deterministic",
            ledger.ledger_address == reversed.ledger_address,
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_TRANSCRIPT_GATE_NEXT_CURSOR
                == "gemma_qat_owner_approved_runtime_replay_probe",
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
            "runtime_replay_transcript_card_count",
            metrics.card_count,
            "==",
            4,
            "cards",
        ),
        ("e2b_card_count", metrics.e2b_card_count, "==", 2, "cards"),
        ("e4b_card_count", metrics.e4b_card_count, "==", 2, "cards"),
        ("gguf_lane_count", metrics.gguf_lane_count, "==", 2, "lanes"),
        (
            "litert_lane_count",
            metrics.litert_lane_count,
            "==",
            2,
            "lanes",
        ),
        (
            "selected_first_probe_candidate_count",
            metrics.selected_first_probe_candidate_count,
            "==",
            1,
            "candidate",
        ),
        (
            "owner_approval_required_count",
            metrics.owner_approval_required_count,
            "==",
            4,
            "cards",
        ),
        (
            "owner_approval_granted_count",
            metrics.owner_approval_granted_count,
            "==",
            0,
            "cards",
        ),
        (
            "command_envelope_visible_count",
            metrics.command_envelope_visible_count,
            "==",
            4,
            "cards",
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
            "runtime_replay_performed_count",
            metrics.runtime_replay_performed_count,
            "==",
            0,
            "runs",
        ),
        (
            "transcript_template_visible_count",
            metrics.transcript_template_visible_count,
            "==",
            4,
            "cards",
        ),
        (
            "memory_sample_required_count",
            metrics.memory_sample_required_count,
            "==",
            4,
            "cards",
        ),
        (
            "prompt_digest_policy_bound_count",
            metrics.prompt_digest_policy_bound_count,
            "==",
            4,
            "cards",
        ),
        (
            "output_digest_policy_bound_count",
            metrics.output_digest_policy_bound_count,
            "==",
            4,
            "cards",
        ),
        (
            "opened_model_file_bytes_total",
            metrics.opened_model_file_bytes_total,
            "==",
            0,
            "bytes",
        ),
        (
            "opened_runtime_file_bytes_total",
            metrics.opened_runtime_file_bytes_total,
            "==",
            0,
            "bytes",
        ),
        (
            "captured_raw_prompt_bytes_total",
            metrics.captured_raw_prompt_bytes_total,
            "==",
            0,
            "bytes",
        ),
        (
            "captured_raw_output_bytes_total",
            metrics.captured_raw_output_bytes_total,
            "==",
            0,
            "bytes",
        ),
        (
            "captured_stdout_bytes_total",
            metrics.captured_stdout_bytes_total,
            "==",
            0,
            "bytes",
        ),
        (
            "captured_stderr_bytes_total",
            metrics.captured_stderr_bytes_total,
            "==",
            0,
            "bytes",
        ),
        (
            "model_bytes_loaded_total",
            metrics.model_bytes_loaded_total,
            "==",
            0,
            "bytes",
        ),
        (
            "runtime_bytes_loaded_total",
            metrics.runtime_bytes_loaded_total,
            "==",
            0,
            "bytes",
        ),
        (
            "provider_calls_made_total",
            metrics.provider_calls_made_total,
            "==",
            0,
            "calls",
        ),
        (
            "scorer_execution_count_total",
            metrics.scorer_execution_count_total,
            "==",
            0,
            "runs",
        ),
        (
            "metadata_bytes_read_total",
            metrics.metadata_bytes_read_total,
            "<=",
            500 * 1024,
            "bytes",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            ">=",
            40,
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
        "gemma_runtime_replay_transcript_gate_address",
        &ledger.ledger_address.to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_TRANSCRIPT_GATE_NEXT_CURSOR,
        "gemma_qat_owner_approved_runtime_replay_probe",
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
        notes: "metadata-only F-GemmaQATOwnerApprovedRuntimeReplayTranscriptGate: consumes the Gemma held-out quality replay packet and binds E2B/E4B GGUF/LiteRT lanes to owner-approval-pending runtime replay transcript templates. It selects only the E2B GGUF lane as the first future probe candidate, requires visible unarmed command envelopes, fresh memory sample requirements, redacted prompt/output digest policies, cancellation, rollback, RunEventLog, AnswerPacket, abstention, and non-promotion. It opens zero model/runtime files, captures zero raw prompt/output/stdout/stderr bytes, executes zero commands or scorers, loads zero model/runtime/provider bytes, and makes no MAS/L2/L3/user-facing, live Gemma default, quality, benchmark-fit, or live-70B claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_held_out_quality_pass() -> Result<bool, Box<dyn std::error::Error>> {
    if !Path::new(UPSTREAM_RESULT).exists() {
        return Ok(false);
    }
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(UPSTREAM_RESULT)?)?;
    Ok(value
        .get("overall_pass")
        .and_then(|v| v.as_bool())
        .unwrap_or(false))
}

fn build_ledger(
    cards: Vec<GemmaQatOwnerApprovedRuntimeReplayTranscriptCard>,
) -> Result<
    GemmaQatOwnerApprovedRuntimeReplayTranscriptLedger,
    agent_core::uas::GemmaQatOwnerApprovedRuntimeReplayTranscriptError,
> {
    GemmaQatOwnerApprovedRuntimeReplayTranscriptLedger::new(
        UPSTREAM_REF,
        cards,
        LEDGER_METADATA_BYTES,
        CREATED_AT_MS,
    )
}

fn has_card(cards: &[GemmaQatOwnerApprovedRuntimeReplayTranscriptCard], id: &str) -> bool {
    cards.iter().any(|card| card.card_id == id)
}

fn red_fixture_results(
    cards: &[GemmaQatOwnerApprovedRuntimeReplayTranscriptCard],
) -> Vec<(&'static str, bool)> {
    vec![
        (
            "twelve_b_inserted",
            reject_first(cards, |card| {
                card.model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string()
            }),
        ),
        (
            "duplicate_model_lane",
            reject_set(cards, |bad| bad[1].model_id = bad[0].model_id.clone()),
        ),
        (
            "bad_runtime_lane",
            reject_first(cards, |card| {
                card.runtime_lane = GemmaFamilyRuntimeLane::MlxSwift
            }),
        ),
        (
            "missing_first_probe_candidate",
            reject_set(cards, |bad| {
                for card in bad {
                    card.selected_first_probe_candidate = false;
                }
            }),
        ),
        (
            "too_many_first_probe_candidates",
            reject_set(cards, |bad| bad[1].selected_first_probe_candidate = true),
        ),
        (
            "owner_approval_not_required",
            reject_first(cards, |card| card.owner_approval_required = false),
        ),
        (
            "owner_approval_granted",
            reject_first(cards, |card| card.owner_approval_granted = true),
        ),
        (
            "command_envelope_hidden",
            reject_first(cards, |card| card.command_envelope_visible = false),
        ),
        (
            "command_armed",
            reject_first(cards, |card| card.command_armed = true),
        ),
        (
            "command_executed",
            reject_first(cards, |card| card.command_executed = true),
        ),
        (
            "transcript_template_hidden",
            reject_first(cards, |card| card.transcript_template_visible = false),
        ),
        (
            "memory_sample_missing",
            reject_first(cards, |card| {
                card.memory_sample_required_before_runtime = false
            }),
        ),
        (
            "memory_sample_freshness_missing",
            reject_first(cards, |card| card.memory_sample_freshness_bound = false),
        ),
        (
            "prompt_digest_policy_missing",
            reject_first(cards, |card| card.prompt_digest_policy_bound = false),
        ),
        (
            "output_digest_policy_missing",
            reject_first(cards, |card| card.output_digest_policy_bound = false),
        ),
        (
            "raw_prompt_allowed",
            reject_first(cards, |card| card.raw_prompt_denied = false),
        ),
        (
            "raw_output_allowed",
            reject_first(cards, |card| card.raw_output_denied = false),
        ),
        (
            "stdio_allowed",
            reject_first(cards, |card| card.stdout_stderr_denied = false),
        ),
        (
            "cancellation_missing",
            reject_first(cards, |card| card.cancellation_bound = false),
        ),
        (
            "rollback_missing",
            reject_first(cards, |card| card.rollback_bound = false),
        ),
        (
            "run_event_log_missing",
            reject_first(cards, |card| card.run_event_log_bound = false),
        ),
        (
            "answer_packet_missing",
            reject_first(cards, |card| card.answer_packet_bound = false),
        ),
        (
            "abstention_missing",
            reject_first(cards, |card| card.abstention_bound = false),
        ),
        (
            "runtime_replay_performed",
            reject_first(cards, |card| card.runtime_replay_performed = true),
        ),
        (
            "model_bytes_loaded",
            reject_first(cards, |card| card.byte_ledger.model_bytes_loaded = 1),
        ),
        (
            "runtime_bytes_loaded",
            reject_first(cards, |card| card.byte_ledger.runtime_bytes_loaded = 1),
        ),
        (
            "provider_call",
            reject_first(cards, |card| card.byte_ledger.provider_calls_made = 1),
        ),
        (
            "scorer_execution",
            reject_first(cards, |card| card.byte_ledger.scorer_execution_count = 1),
        ),
        (
            "opened_model_file_bytes",
            reject_first(cards, |card| card.byte_ledger.opened_model_file_bytes = 1),
        ),
        (
            "opened_runtime_file_bytes",
            reject_first(cards, |card| card.byte_ledger.opened_runtime_file_bytes = 1),
        ),
        (
            "captured_raw_prompt_bytes",
            reject_first(cards, |card| card.byte_ledger.captured_raw_prompt_bytes = 1),
        ),
        (
            "captured_raw_output_bytes",
            reject_first(cards, |card| card.byte_ledger.captured_raw_output_bytes = 1),
        ),
        (
            "captured_stdout_bytes",
            reject_first(cards, |card| card.byte_ledger.captured_stdout_bytes = 1),
        ),
        (
            "captured_stderr_bytes",
            reject_first(cards, |card| card.byte_ledger.captured_stderr_bytes = 1),
        ),
        (
            "runtime_router_mutation",
            reject_first(cards, |card| card.runtime_router_mutation_allowed = true),
        ),
        (
            "system_g_mutation",
            reject_first(cards, |card| card.system_g_mutation_allowed = true),
        ),
        (
            "hidden_route_authority",
            reject_first(cards, |card| card.hidden_route_authority = true),
        ),
        (
            "hidden_eidos_authority",
            reject_first(cards, |card| card.hidden_eidos_authority = true),
        ),
        (
            "hidden_lattice_authority",
            reject_first(cards, |card| card.hidden_lattice_authority = true),
        ),
        (
            "hidden_patternboost_authority",
            reject_first(cards, |card| card.hidden_patternboost_authority = true),
        ),
        (
            "hidden_cloud_fallback",
            reject_first(cards, |card| card.hidden_cloud_fallback = true),
        ),
        (
            "mas_l2_l3_product_claim",
            reject_first(cards, |card| {
                card.mas_promoted = true;
                card.l2_capability_effect = true;
                card.l3_wrv_effect = true;
                card.product_route_green = true;
            }),
        ),
        (
            "live_gemma_default_claim",
            reject_first(cards, |card| card.live_gemma_default_claim = true),
        ),
        (
            "live_dense_70b_claim",
            reject_first(cards, |card| card.live_dense_70b_claim = true),
        ),
        (
            "ssd_as_ram_claim",
            reject_first(cards, |card| card.ssd_as_ram_claim = true),
        ),
        (
            "quality_claim",
            reject_first(cards, |card| card.quality_claimed = true),
        ),
        (
            "benchmark_fit_claim",
            reject_first(cards, |card| card.benchmark_claimed_as_fit = true),
        ),
        (
            "bad_proof_ref",
            reject_first(cards, |card| {
                card.proof_refs.answer_packet_ref = "missing".to_string()
            }),
        ),
        (
            "metadata_budget_exceeded",
            reject_first(cards, |card| {
                card.byte_ledger.metadata_bytes_read = 512 * 1024
            }),
        ),
        (
            "bad_upstream_ref",
            reject_first(cards, |card| {
                card.upstream_held_out_ref = "artifact:wrong".to_string()
            }),
        ),
        (
            "wrong_next_cursor",
            reject_first(cards, |card| card.next_cursor = "wrong".to_string()),
        ),
    ]
}

fn reject_first(
    cards: &[GemmaQatOwnerApprovedRuntimeReplayTranscriptCard],
    mutate: impl FnOnce(&mut GemmaQatOwnerApprovedRuntimeReplayTranscriptCard),
) -> bool {
    let mut bad = cards.to_vec();
    if let Some(card) = bad.first_mut() {
        mutate(card);
    }
    build_ledger(bad).is_err()
}

fn reject_set(
    cards: &[GemmaQatOwnerApprovedRuntimeReplayTranscriptCard],
    mutate: impl FnOnce(&mut Vec<GemmaQatOwnerApprovedRuntimeReplayTranscriptCard>),
) -> bool {
    let mut bad = cards.to_vec();
    mutate(&mut bad);
    build_ledger(bad).is_err()
}

fn red_pass(red_results: &[(&'static str, bool)], name: &str) -> bool {
    red_results
        .iter()
        .find(|(fixture, _)| *fixture == name)
        .map(|(_, pass)| *pass)
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
    let missing = GEMMA_QAT_OWNER_APPROVED_RUNTIME_REPLAY_TRANSCRIPT_GATE_AXES
        .iter()
        .filter(|axis| !measurements.contains_key(**axis))
        .copied()
        .collect::<Vec<_>>();
    assert!(
        missing.is_empty(),
        "missing Gemma QAT owner-approved runtime replay transcript gate axes: {missing:?}"
    );
}
