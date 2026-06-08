//! `falsify_gemma_qat_held_out_quality_replay_packet`
//!
//! Metadata-only witness for `F-GemmaQATHeldOutQualityReplayPacket`. It binds
//! Gemma E2B/E4B GGUF/LiteRT lanes to a held-out task/scorer/failure-taxonomy
//! packet after same-fixture replay and before any quality, benchmark, route,
//! or default-model claim can count.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_HELD_OUT_QUALITY_REPLAY_PACKET_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_gemma_qat_held_out_quality_replay_cards, GemmaFamilyRuntimeLane,
    GemmaQatHeldOutQualityReplayCard, GemmaQatHeldOutQualityReplayLedger,
    GEMMA_QAT_HELD_OUT_QUALITY_REPLAY_PACKET_ID,
    GEMMA_QAT_HELD_OUT_QUALITY_REPLAY_PACKET_NEXT_CURSOR, GEMMA_QAT_QUALITY_TASK_FAMILIES,
};

const FALSIFIER_ID: &str = GEMMA_QAT_HELD_OUT_QUALITY_REPLAY_PACKET_ID;
const FIXTURE_ID: &str = "gemma_qat_held_out_quality_replay_packet_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_qat_held_out_quality_replay_packet.sh";
const RESULT: &str = "artifacts/falsifiers/gemma_qat_held_out_quality_replay_packet/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_same_fixture_runtime_replay/result.json";
const UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_qat_same_fixture_runtime_replay/result.json#F-GemmaQATSameFixtureRuntimeReplay";
const CREATED_AT_MS: u64 = 1_779_214_400_000;
const LEDGER_METADATA_BYTES: u64 = 128_000;

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
        "{FALSIFIER_ID}: overall_pass={} card_count={} task_family_count={} model_bytes_loaded_total={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["held_out_quality_card_count"].value,
        artifact.measurements["unique_task_family_count"].value,
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
    let upstream_pass = upstream_same_fixture_pass()?;
    let cards = canonical_gemma_qat_held_out_quality_replay_cards(UPSTREAM_REF);
    let ledger = build_ledger(cards.clone())?;
    let reversed = GemmaQatHeldOutQualityReplayLedger::new(
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
        ("upstream_gemma_same_fixture_replay_pass", upstream_pass),
        (
            "accepted_held_out_quality_replay_pack_present",
            has_card(&cards, "gemma4_e2b_gguf_llama_cpp_held_out_quality_replay")
                && has_card(&cards, "gemma4_e2b_litert_lm_held_out_quality_replay")
                && has_card(&cards, "gemma4_e4b_gguf_llama_cpp_held_out_quality_replay")
                && has_card(&cards, "gemma4_e4b_litert_lm_held_out_quality_replay"),
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
            "fixture_pack_and_scorer_bundle_bound",
            metrics.fixture_pack_count == 1
                && metrics.scorer_bundle_count == 1
                && red_pass(&red_results, "fixture_pack_drift")
                && red_pass(&red_results, "scorer_bundle_drift"),
        ),
        (
            "task_family_coverage_bound",
            metrics.unique_task_family_count == GEMMA_QAT_QUALITY_TASK_FAMILIES.len() as u64
                && metrics.task_family_total_count
                    == (cards.len() * GEMMA_QAT_QUALITY_TASK_FAMILIES.len()) as u64
                && red_pass(&red_results, "missing_task_family"),
        ),
        (
            "held_out_split_and_synthetic_safe_policy_bound",
            metrics.held_out_split_bound_count == 4
                && cards
                    .iter()
                    .all(|card| card.synthetic_safe_fixture_policy_bound)
                && red_pass(&red_results, "held_out_split_missing")
                && red_pass(&red_results, "synthetic_safe_policy_missing"),
        ),
        (
            "verifier_and_scorer_digest_bound",
            metrics.verifier_digest_bound_count == 4
                && metrics.scorer_digest_bound_count == 4
                && red_pass(&red_results, "verifier_digest_missing")
                && red_pass(&red_results, "scorer_digest_missing"),
        ),
        (
            "final_output_digest_and_failure_taxonomy_bound",
            metrics.final_output_digest_policy_bound_count == 4
                && metrics.failure_taxonomy_bound_count == 4
                && red_pass(&red_results, "final_output_digest_missing")
                && red_pass(&red_results, "failure_taxonomy_missing"),
        ),
        (
            "privacy_judge_and_raw_output_bound",
            cards.iter().all(|card| {
                card.model_graded_primary_denied
                    && card.hidden_judge_denied
                    && card.raw_prompt_denied
                    && card.raw_output_denied
            }) && red_pass(&red_results, "model_graded_primary_allowed")
                && red_pass(&red_results, "hidden_judge_allowed")
                && red_pass(&red_results, "raw_prompt_allowed")
                && red_pass(&red_results, "raw_output_allowed"),
        ),
        (
            "rollback_log_packet_abstention_bound",
            cards.iter().all(|card| {
                card.rollback_bound
                    && card.run_event_log_bound
                    && card.answer_packet_bound
                    && card.abstention_bound
            }) && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "abstention_missing"),
        ),
        (
            "runtime_quality_replay_deferred",
            metrics.runtime_quality_replay_deferred_count == 4
                && red_pass(&red_results, "runtime_quality_replay_enabled"),
        ),
        (
            "zero_eval_model_runtime_provider_bytes",
            metrics.model_bytes_loaded_total == 0
                && metrics.runtime_bytes_loaded_total == 0
                && metrics.provider_calls_made_total == 0
                && metrics.benchmark_runs_total == 0
                && metrics.scorer_executions_total == 0
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_call")
                && red_pass(&red_results, "benchmark_run")
                && red_pass(&red_results, "scorer_execution"),
        ),
        (
            "zero_fixture_prompt_output_judge_bytes",
            metrics.fixture_payload_bytes_opened_total == 0
                && metrics.raw_prompt_bytes_captured_total == 0
                && metrics.raw_output_bytes_captured_total == 0
                && metrics.raw_judge_bytes_captured_total == 0
                && red_pass(&red_results, "fixture_payload_bytes_opened")
                && red_pass(&red_results, "raw_prompt_bytes")
                && red_pass(&red_results, "raw_output_bytes")
                && red_pass(&red_results, "raw_judge_bytes"),
        ),
        (
            "no_route_mutation_or_hidden_authority",
            metrics.hidden_authority_count == 0
                && red_pass(&red_results, "route_mutation_allowed")
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "hidden_eidos_authority")
                && red_pass(&red_results, "hidden_lattice_authority")
                && red_pass(&red_results, "hidden_patternboost_authority")
                && red_pass(&red_results, "hidden_cloud_fallback"),
        ),
        (
            "no_mas_l2_l3_product_or_70b_claim",
            metrics.l2_effect_count == 0
                && metrics.l3_effect_count == 0
                && metrics.promotion_claim_count == 0
                && metrics.quality_claim_count == 0
                && red_pass(&red_results, "mas_l2_l3_product_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim")
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "benchmark_fit_claim"),
        ),
        (
            "quality_replay_ledger_address_deterministic",
            ledger.ledger_address == reversed.ledger_address,
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_HELD_OUT_QUALITY_REPLAY_PACKET_NEXT_CURSOR
                == "gemma_qat_owner_approved_runtime_replay_transcript_gate",
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
            "held_out_quality_card_count",
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
            "fixture_pack_count",
            metrics.fixture_pack_count,
            "==",
            1,
            "pack",
        ),
        (
            "scorer_bundle_count",
            metrics.scorer_bundle_count,
            "==",
            1,
            "bundle",
        ),
        (
            "task_family_total_count",
            metrics.task_family_total_count,
            "==",
            28,
            "families",
        ),
        (
            "unique_task_family_count",
            metrics.unique_task_family_count,
            "==",
            7,
            "families",
        ),
        (
            "held_out_split_bound_count",
            metrics.held_out_split_bound_count,
            "==",
            4,
            "cards",
        ),
        (
            "verifier_digest_bound_count",
            metrics.verifier_digest_bound_count,
            "==",
            4,
            "cards",
        ),
        (
            "scorer_digest_bound_count",
            metrics.scorer_digest_bound_count,
            "==",
            4,
            "cards",
        ),
        (
            "final_output_digest_policy_bound_count",
            metrics.final_output_digest_policy_bound_count,
            "==",
            4,
            "cards",
        ),
        (
            "failure_taxonomy_bound_count",
            metrics.failure_taxonomy_bound_count,
            "==",
            4,
            "cards",
        ),
        (
            "runtime_quality_replay_deferred_count",
            metrics.runtime_quality_replay_deferred_count,
            "==",
            4,
            "cards",
        ),
        (
            "fixture_payload_bytes_opened_total",
            metrics.fixture_payload_bytes_opened_total,
            "==",
            0,
            "bytes",
        ),
        (
            "raw_prompt_bytes_captured_total",
            metrics.raw_prompt_bytes_captured_total,
            "==",
            0,
            "bytes",
        ),
        (
            "raw_output_bytes_captured_total",
            metrics.raw_output_bytes_captured_total,
            "==",
            0,
            "bytes",
        ),
        (
            "raw_judge_bytes_captured_total",
            metrics.raw_judge_bytes_captured_total,
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
            "benchmark_runs_total",
            metrics.benchmark_runs_total,
            "==",
            0,
            "runs",
        ),
        (
            "scorer_executions_total",
            metrics.scorer_executions_total,
            "==",
            0,
            "runs",
        ),
        (
            "metadata_bytes_read_total",
            metrics.metadata_bytes_read_total,
            "<=",
            450 * 1024,
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
        "gemma_held_out_quality_replay_address",
        &ledger.ledger_address.to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_HELD_OUT_QUALITY_REPLAY_PACKET_NEXT_CURSOR,
        "gemma_qat_owner_approved_runtime_replay_transcript_gate",
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
        notes: "metadata-only F-GemmaQATHeldOutQualityReplayPacket: consumes the Gemma same-fixture replay witness and binds E2B/E4B GGUF/LiteRT lanes to a held-out fixture pack, scorer bundle, seven task families, verifier/scorer/final-output/failure-taxonomy digests, privacy boundaries, rollback, RunEventLog, AnswerPacket, abstention, and non-promotion. It opens zero fixture/model/runtime files, captures zero raw prompt/output/judge bytes, runs zero scorers or benchmarks, and makes no MAS/L2/L3/user-facing, quality, benchmark-fit, live-main-Gemma, or live-70B claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_same_fixture_pass() -> Result<bool, Box<dyn std::error::Error>> {
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
    cards: Vec<GemmaQatHeldOutQualityReplayCard>,
) -> Result<GemmaQatHeldOutQualityReplayLedger, agent_core::uas::GemmaQatHeldOutQualityReplayError>
{
    GemmaQatHeldOutQualityReplayLedger::new(
        UPSTREAM_REF,
        cards,
        LEDGER_METADATA_BYTES,
        CREATED_AT_MS,
    )
}

fn has_card(cards: &[GemmaQatHeldOutQualityReplayCard], id: &str) -> bool {
    cards.iter().any(|card| card.card_id == id)
}

fn red_fixture_results(cards: &[GemmaQatHeldOutQualityReplayCard]) -> Vec<(&'static str, bool)> {
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
            "fixture_pack_drift",
            reject_first(cards, |card| {
                card.fixture_pack_digest = "fixture_pack:sha256:other".to_string()
            }),
        ),
        (
            "scorer_bundle_drift",
            reject_first(cards, |card| {
                card.scorer_bundle_digest = "scorer_bundle:sha256:other".to_string()
            }),
        ),
        (
            "missing_task_family",
            reject_first(cards, |card| {
                let _ = card.task_families.pop();
            }),
        ),
        (
            "held_out_split_missing",
            reject_first(cards, |card| card.held_out_split_bound = false),
        ),
        (
            "synthetic_safe_policy_missing",
            reject_first(cards, |card| {
                card.synthetic_safe_fixture_policy_bound = false
            }),
        ),
        (
            "verifier_digest_missing",
            reject_first(cards, |card| card.verifier_digest_bound = false),
        ),
        (
            "scorer_digest_missing",
            reject_first(cards, |card| card.scorer_digest_bound = false),
        ),
        (
            "final_output_digest_missing",
            reject_first(cards, |card| card.final_output_digest_policy_bound = false),
        ),
        (
            "failure_taxonomy_missing",
            reject_first(cards, |card| card.failure_taxonomy_bound = false),
        ),
        (
            "refusal_tool_cache_taxonomy_missing",
            reject_first(cards, |card| card.refusal_tool_cache_taxonomy_bound = false),
        ),
        (
            "deterministic_scoring_missing",
            reject_first(cards, |card| card.deterministic_scoring_required = false),
        ),
        (
            "model_graded_primary_allowed",
            reject_first(cards, |card| card.model_graded_primary_denied = false),
        ),
        (
            "hidden_judge_allowed",
            reject_first(cards, |card| card.hidden_judge_denied = false),
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
            "runtime_quality_replay_enabled",
            reject_first(cards, |card| card.runtime_quality_replay_deferred = false),
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
            "fixture_payload_bytes_opened",
            reject_first(cards, |card| {
                card.byte_ledger.fixture_payload_bytes_opened = 1
            }),
        ),
        (
            "raw_prompt_bytes",
            reject_first(cards, |card| card.byte_ledger.raw_prompt_bytes_captured = 1),
        ),
        (
            "raw_output_bytes",
            reject_first(cards, |card| card.byte_ledger.raw_output_bytes_captured = 1),
        ),
        (
            "raw_judge_bytes",
            reject_first(cards, |card| card.byte_ledger.raw_judge_bytes_captured = 1),
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
            "benchmark_run",
            reject_first(cards, |card| card.byte_ledger.benchmark_runs = 1),
        ),
        (
            "scorer_execution",
            reject_first(cards, |card| card.byte_ledger.scorer_executions = 1),
        ),
        (
            "route_mutation_allowed",
            reject_first(cards, |card| card.route_mutation_allowed = true),
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
                card.upstream_same_fixture_ref = "artifact:wrong".to_string()
            }),
        ),
        (
            "wrong_next_cursor",
            reject_first(cards, |card| card.next_cursor = "wrong".to_string()),
        ),
    ]
}

fn reject_first(
    cards: &[GemmaQatHeldOutQualityReplayCard],
    mutate: impl FnOnce(&mut GemmaQatHeldOutQualityReplayCard),
) -> bool {
    let mut bad = cards.to_vec();
    if let Some(card) = bad.first_mut() {
        mutate(card);
    }
    build_ledger(bad).is_err()
}

fn reject_set(
    cards: &[GemmaQatHeldOutQualityReplayCard],
    mutate: impl FnOnce(&mut Vec<GemmaQatHeldOutQualityReplayCard>),
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
    let missing = GEMMA_QAT_HELD_OUT_QUALITY_REPLAY_PACKET_AXES
        .iter()
        .filter(|axis| !measurements.contains_key(**axis))
        .copied()
        .collect::<Vec<_>>();
    assert!(
        missing.is_empty(),
        "missing Gemma QAT held-out quality replay packet axes: {missing:?}"
    );
}
