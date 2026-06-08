//! `falsify_gemma_qat_same_fixture_runtime_replay`
//!
//! Metadata-only witness for `F-GemmaQATSameFixtureRuntimeReplay`. It binds
//! Gemma E2B/E4B GGUF/LiteRT lanes to one replay fixture after the redacted
//! first-token preflight and before any runtime replay, quality comparison,
//! cache reuse, or product route can count.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_SAME_FIXTURE_RUNTIME_REPLAY_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_gemma_qat_same_fixture_replay_cards, GemmaFamilyRuntimeLane,
    GemmaQatSameFixtureReplayCard, GemmaQatSameFixtureReplayLedger,
    GEMMA_QAT_SAME_FIXTURE_RUNTIME_REPLAY_ID, GEMMA_QAT_SAME_FIXTURE_RUNTIME_REPLAY_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = GEMMA_QAT_SAME_FIXTURE_RUNTIME_REPLAY_ID;
const FIXTURE_ID: &str = "gemma_qat_same_fixture_runtime_replay_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_qat_same_fixture_runtime_replay.sh";
const RESULT: &str = "artifacts/falsifiers/gemma_qat_same_fixture_runtime_replay/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_redacted_first_token_probe/result.json";
const UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_qat_redacted_first_token_probe/result.json#F-GemmaQATRedactedFirstTokenProbe";
const CREATED_AT_MS: u64 = 1_779_213_600_000;
const LEDGER_METADATA_BYTES: u64 = 112_000;

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
        "{FALSIFIER_ID}: overall_pass={} card_count={} fixture_count={} model_bytes_loaded_total={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["same_fixture_replay_card_count"].value,
        artifact.measurements["fixture_count"].value,
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
    let upstream_pass = upstream_first_token_pass()?;
    let cards = canonical_gemma_qat_same_fixture_replay_cards(UPSTREAM_REF);
    let ledger = build_ledger(cards.clone())?;
    let reversed = GemmaQatSameFixtureReplayLedger::new(
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
        ("upstream_gemma_first_token_probe_pass", upstream_pass),
        (
            "accepted_same_fixture_replay_pack_present",
            has_card(&cards, "gemma4_e2b_gguf_llama_cpp_same_fixture_replay")
                && has_card(&cards, "gemma4_e2b_litert_lm_same_fixture_replay")
                && has_card(&cards, "gemma4_e4b_gguf_llama_cpp_same_fixture_replay")
                && has_card(&cards, "gemma4_e4b_litert_lm_same_fixture_replay"),
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
            "same_fixture_identity_bound",
            metrics.fixture_count == 1
                && red_pass(&red_results, "fixture_digest_drift")
                && red_pass(&red_results, "canonical_digest_drift"),
        ),
        (
            "source_search_and_body_freshness_bound",
            cards
                .iter()
                .all(|card| card.source_search_freshness_bound && card.body_read_checksum_bound)
                && red_pass(&red_results, "source_search_missing")
                && red_pass(&red_results, "body_checksum_missing"),
        ),
        (
            "prompt_tokenizer_chat_tool_boundary_bound",
            metrics.prompt_digest_bound_count == 4
                && metrics.tokenizer_digest_bound_count == 4
                && metrics.chat_template_digest_bound_count == 4
                && metrics.tool_schema_digest_bound_count == 4
                && red_pass(&red_results, "prompt_digest_missing")
                && red_pass(&red_results, "tokenizer_digest_missing")
                && red_pass(&red_results, "chat_template_missing")
                && red_pass(&red_results, "tool_schema_missing"),
        ),
        (
            "memory_sample_and_one_token_replay_bound",
            metrics.memory_sample_bound_count == 4
                && cards.iter().all(|card| card.one_token_replay_bound)
                && red_pass(&red_results, "memory_sample_missing")
                && red_pass(&red_results, "one_token_bound_missing"),
        ),
        (
            "cancellation_rollback_log_packet_bound",
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
            "privacy_cache_and_hidden_chain_bound",
            cards.iter().all(|card| {
                card.raw_prompt_denied
                    && card.raw_token_denied
                    && card.hidden_chain_denied
                    && card.cache_reuse_denied_until_lineage
            }) && red_pass(&red_results, "raw_prompt_allowed")
                && red_pass(&red_results, "raw_token_allowed")
                && red_pass(&red_results, "hidden_chain_allowed")
                && red_pass(&red_results, "cache_reuse_allowed"),
        ),
        (
            "runtime_and_quality_deferred",
            metrics.runtime_replay_deferred_count == 4
                && metrics.quality_comparison_deferred_count == 4
                && red_pass(&red_results, "runtime_replay_enabled")
                && red_pass(&red_results, "quality_comparison_enabled"),
        ),
        (
            "zero_runtime_model_provider_command_benchmark_bytes",
            metrics.model_bytes_loaded_total == 0
                && metrics.runtime_bytes_loaded_total == 0
                && metrics.provider_calls_made_total == 0
                && metrics.command_execution_count_total == 0
                && metrics.benchmark_runs_total == 0
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_call")
                && red_pass(&red_results, "command_execution")
                && red_pass(&red_results, "benchmark_run"),
        ),
        (
            "zero_raw_prompt_token_tool_cache_file_bytes",
            metrics.raw_prompt_bytes_captured_total == 0
                && metrics.raw_token_bytes_captured_total == 0
                && metrics.tool_json_bytes_captured_total == 0
                && metrics.local_file_bytes_read_total == 0
                && metrics.cache_bytes_reused_total == 0
                && red_pass(&red_results, "raw_prompt_bytes")
                && red_pass(&red_results, "raw_token_bytes")
                && red_pass(&red_results, "tool_json_bytes")
                && red_pass(&red_results, "local_file_bytes")
                && red_pass(&red_results, "cache_bytes_reused"),
        ),
        (
            "no_route_mutation_or_hidden_authority",
            metrics.hidden_authority_count == 0
                && red_pass(&red_results, "route_mutation_allowed")
                && red_pass(&red_results, "hidden_route_authority")
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
            "same_fixture_ledger_address_deterministic",
            ledger.ledger_address == reversed.ledger_address,
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_SAME_FIXTURE_RUNTIME_REPLAY_NEXT_CURSOR
                == "gemma_qat_held_out_quality_replay_packet",
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
            "same_fixture_replay_card_count",
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
        ("fixture_count", metrics.fixture_count, "==", 1, "fixture"),
        (
            "prompt_digest_bound_count",
            metrics.prompt_digest_bound_count,
            "==",
            4,
            "cards",
        ),
        (
            "tokenizer_digest_bound_count",
            metrics.tokenizer_digest_bound_count,
            "==",
            4,
            "cards",
        ),
        (
            "chat_template_digest_bound_count",
            metrics.chat_template_digest_bound_count,
            "==",
            4,
            "cards",
        ),
        (
            "tool_schema_digest_bound_count",
            metrics.tool_schema_digest_bound_count,
            "==",
            4,
            "cards",
        ),
        (
            "memory_sample_bound_count",
            metrics.memory_sample_bound_count,
            "==",
            4,
            "cards",
        ),
        (
            "runtime_replay_deferred_count",
            metrics.runtime_replay_deferred_count,
            "==",
            4,
            "cards",
        ),
        (
            "quality_comparison_deferred_count",
            metrics.quality_comparison_deferred_count,
            "==",
            4,
            "cards",
        ),
        (
            "raw_prompt_bytes_captured_total",
            metrics.raw_prompt_bytes_captured_total,
            "==",
            0,
            "bytes",
        ),
        (
            "raw_token_bytes_captured_total",
            metrics.raw_token_bytes_captured_total,
            "==",
            0,
            "bytes",
        ),
        (
            "tool_json_bytes_captured_total",
            metrics.tool_json_bytes_captured_total,
            "==",
            0,
            "bytes",
        ),
        (
            "local_file_bytes_read_total",
            metrics.local_file_bytes_read_total,
            "==",
            0,
            "bytes",
        ),
        (
            "cache_bytes_reused_total",
            metrics.cache_bytes_reused_total,
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
            "command_execution_count_total",
            metrics.command_execution_count_total,
            "==",
            0,
            "commands",
        ),
        (
            "benchmark_runs_total",
            metrics.benchmark_runs_total,
            "==",
            0,
            "runs",
        ),
        (
            "metadata_bytes_read_total",
            metrics.metadata_bytes_read_total,
            "<=",
            400 * 1024,
            "bytes",
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
        "gemma_same_fixture_replay_address",
        &ledger.ledger_address.to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_SAME_FIXTURE_RUNTIME_REPLAY_NEXT_CURSOR,
        "gemma_qat_held_out_quality_replay_packet",
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
        notes: "metadata-only F-GemmaQATSameFixtureRuntimeReplay: consumes the Gemma redacted first-token preflight and binds E2B/E4B GGUF/LiteRT cards to one replay fixture, source/search/body freshness, prompt/tokenizer/chat-template/tool-schema boundaries, memory sampling, cancellation, rollback, RunEventLog, AnswerPacket, abstention, no cache reuse, and non-promotion. It opens zero paths/files, executes zero commands, captures zero raw prompt/token/tool bytes, loads zero model/runtime/provider bytes, runs zero benchmarks, and makes no MAS/L2/L3/user-facing, quality, benchmark-fit, or live-70B claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_first_token_pass() -> Result<bool, Box<dyn std::error::Error>> {
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
    cards: Vec<GemmaQatSameFixtureReplayCard>,
) -> Result<GemmaQatSameFixtureReplayLedger, agent_core::uas::GemmaQatSameFixtureReplayError> {
    GemmaQatSameFixtureReplayLedger::new(UPSTREAM_REF, cards, LEDGER_METADATA_BYTES, CREATED_AT_MS)
}

fn has_card(cards: &[GemmaQatSameFixtureReplayCard], id: &str) -> bool {
    cards.iter().any(|card| card.card_id == id)
}

fn red_fixture_results(cards: &[GemmaQatSameFixtureReplayCard]) -> Vec<(&'static str, bool)> {
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
            "fixture_digest_drift",
            reject_first(cards, |card| {
                card.fixture_digest = "fixture:sha256:other".to_string()
            }),
        ),
        (
            "canonical_digest_drift",
            reject_first(cards, |card| {
                card.canonical_replay_digest = "sha256:other".to_string()
            }),
        ),
        (
            "source_search_missing",
            reject_first(cards, |card| card.source_search_freshness_bound = false),
        ),
        (
            "body_checksum_missing",
            reject_first(cards, |card| card.body_read_checksum_bound = false),
        ),
        (
            "prompt_digest_missing",
            reject_first(cards, |card| card.redacted_prompt_digest_bound = false),
        ),
        (
            "tokenizer_digest_missing",
            reject_first(cards, |card| card.tokenizer_digest_bound = false),
        ),
        (
            "chat_template_missing",
            reject_first(cards, |card| card.chat_template_digest_bound = false),
        ),
        (
            "tool_schema_missing",
            reject_first(cards, |card| card.tool_schema_digest_bound = false),
        ),
        (
            "memory_sample_missing",
            reject_first(cards, |card| card.memory_sample_bound = false),
        ),
        (
            "one_token_bound_missing",
            reject_first(cards, |card| card.one_token_replay_bound = false),
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
            "raw_prompt_allowed",
            reject_first(cards, |card| card.raw_prompt_denied = false),
        ),
        (
            "raw_token_allowed",
            reject_first(cards, |card| card.raw_token_denied = false),
        ),
        (
            "hidden_chain_allowed",
            reject_first(cards, |card| card.hidden_chain_denied = false),
        ),
        (
            "cache_reuse_allowed",
            reject_first(cards, |card| card.cache_reuse_denied_until_lineage = false),
        ),
        (
            "runtime_replay_enabled",
            reject_first(cards, |card| card.runtime_replay_deferred = false),
        ),
        (
            "quality_comparison_enabled",
            reject_first(cards, |card| card.quality_comparison_deferred = false),
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
            "command_execution",
            reject_first(cards, |card| card.byte_ledger.command_execution_count = 1),
        ),
        (
            "benchmark_run",
            reject_first(cards, |card| card.byte_ledger.benchmark_runs = 1),
        ),
        (
            "raw_prompt_bytes",
            reject_first(cards, |card| card.byte_ledger.raw_prompt_bytes_captured = 1),
        ),
        (
            "raw_token_bytes",
            reject_first(cards, |card| card.byte_ledger.raw_token_bytes_captured = 1),
        ),
        (
            "tool_json_bytes",
            reject_first(cards, |card| card.byte_ledger.tool_json_bytes_captured = 1),
        ),
        (
            "local_file_bytes",
            reject_first(cards, |card| card.byte_ledger.local_file_bytes_read = 1),
        ),
        (
            "cache_bytes_reused",
            reject_first(cards, |card| card.byte_ledger.cache_bytes_reused = 1),
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
                card.upstream_first_token_ref = "artifact:wrong".to_string()
            }),
        ),
        (
            "wrong_next_cursor",
            reject_first(cards, |card| card.next_cursor = "wrong".to_string()),
        ),
    ]
}

fn reject_first(
    cards: &[GemmaQatSameFixtureReplayCard],
    mutate: impl FnOnce(&mut GemmaQatSameFixtureReplayCard),
) -> bool {
    let mut bad = cards.to_vec();
    if let Some(card) = bad.first_mut() {
        mutate(card);
    }
    build_ledger(bad).is_err()
}

fn reject_set(
    cards: &[GemmaQatSameFixtureReplayCard],
    mutate: impl FnOnce(&mut Vec<GemmaQatSameFixtureReplayCard>),
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
    let missing = GEMMA_QAT_SAME_FIXTURE_RUNTIME_REPLAY_AXES
        .iter()
        .filter(|axis| !measurements.contains_key(**axis))
        .copied()
        .collect::<Vec<_>>();
    assert!(
        missing.is_empty(),
        "missing Gemma QAT same-fixture runtime replay axes: {missing:?}"
    );
}
