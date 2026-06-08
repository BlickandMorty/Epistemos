//! `falsify_gemma_qat_redacted_first_token_probe`
//!
//! Metadata-only witness for `F-GemmaQATRedactedFirstTokenProbe`. It binds the
//! Gemma E2B/E4B QAT redacted, owner-approved, one-token probe contract after
//! the byte/KV/app envelope and before any runtime, prompt, token, stdout,
//! stderr, owner path, local file, or model byte can be touched.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::GEMMA_QAT_REDACTED_FIRST_TOKEN_PROBE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_gemma_qat_redacted_first_token_cards, GemmaFamilyRuntimeLane,
    GemmaQatFirstTokenSurface, GemmaQatRedactedFirstTokenCard, GemmaQatRedactedFirstTokenLedger,
    GEMMA_FIRST_TOKEN_MEMORY_SAMPLE_SLOT_COUNT, GEMMA_QAT_REDACTED_FIRST_TOKEN_PROBE_ID,
    GEMMA_QAT_REDACTED_FIRST_TOKEN_PROBE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = GEMMA_QAT_REDACTED_FIRST_TOKEN_PROBE_ID;
const FIXTURE_ID: &str = "gemma_qat_redacted_first_token_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_qat_redacted_first_token_probe.sh";
const RESULT: &str = "artifacts/falsifiers/gemma_qat_redacted_first_token_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/gemma_qat_byte_kv_app_envelope_preflight/result.json";
const UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_qat_byte_kv_app_envelope_preflight/result.json#F-GemmaQATByteKVAppEnvelopePreflight";
const CREATED_AT_MS: u64 = 1_779_212_800_000;
const LEDGER_METADATA_BYTES: u64 = 96_000;

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
        "{FALSIFIER_ID}: overall_pass={} card_count={} memory_sample_slots={} raw_prompt_bytes={} raw_token_bytes={} model_bytes_loaded_total={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["redacted_first_token_card_count"].value,
        artifact.measurements["memory_sample_slot_total_count"].value,
        artifact.measurements["raw_prompt_bytes_captured_total"].value,
        artifact.measurements["raw_token_bytes_captured_total"].value,
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
    let (upstream_pass, upstream_address) = upstream_envelope()?;
    let cards = canonical_gemma_qat_redacted_first_token_cards(UPSTREAM_REF);
    let ledger = build_ledger(upstream_address.clone(), cards.clone())?;
    let reversed = build_ledger(upstream_address, cards.iter().cloned().rev().collect())?;
    let metrics = ledger.metrics();
    let red_results = red_fixture_results(&cards);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_gemma_byte_envelope_pass", upstream_pass),
        (
            "accepted_redacted_first_token_preflight_pack_present",
            has_card(
                &cards,
                "gemma4_e2b_gguf_llama_cpp_redacted_first_token_preflight",
            ) && has_card(
                &cards,
                "gemma4_e2b_litert_lm_redacted_first_token_preflight",
            ) && has_card(
                &cards,
                "gemma4_e4b_gguf_llama_cpp_redacted_first_token_preflight",
            ) && has_card(
                &cards,
                "gemma4_e4b_litert_lm_redacted_first_token_preflight",
            ),
        ),
        (
            "runtime_lane_coverage_bound",
            metrics.gguf_lane_count == 2
                && metrics.litert_lane_count == 2
                && red_pass(&red_results, "bad_runtime_lane"),
        ),
        (
            "owner_approval_pending",
            ledger.owner_approval_required
                && metrics.owner_approval_granted_count == 0
                && red_pass(&red_results, "owner_approval_granted"),
        ),
        (
            "fresh_memory_sample_bound",
            metrics.fresh_memory_sample_required_count == 4
                && red_pass(&red_results, "fresh_memory_sample_missing"),
        ),
        (
            "synthetic_prompt_descriptor_visible",
            cards.iter().all(|card| card.prompt_template_visible)
                && red_pass(&red_results, "prompt_template_hidden"),
        ),
        (
            "prompt_digest_policy_bound_no_raw_prompt",
            metrics.prompt_digest_policy_bound_count == 4
                && metrics.raw_prompt_text_present_count == 0
                && metrics.raw_prompt_bytes_captured_total == 0
                && red_pass(&red_results, "prompt_digest_missing")
                && red_pass(&red_results, "raw_prompt_text_present")
                && red_pass(&red_results, "raw_user_prompt_present")
                && red_pass(&red_results, "raw_prompt_bytes_captured"),
        ),
        (
            "token_digest_policy_bound_no_raw_token",
            metrics.first_token_digest_policy_bound_count == 4
                && metrics.first_token_observed_count == 0
                && metrics.first_token_digest_present_count == 0
                && metrics.raw_token_text_present_count == 0
                && metrics.raw_token_bytes_captured_total == 0
                && red_pass(&red_results, "token_digest_policy_missing")
                && red_pass(&red_results, "first_token_observed")
                && red_pass(&red_results, "first_token_digest_present")
                && red_pass(&red_results, "raw_token_text_present")
                && red_pass(&red_results, "raw_token_bytes_captured"),
        ),
        (
            "one_token_context_batch_bounds",
            cards.iter().all(|card| {
                card.max_new_tokens == 1 && card.context_cap_tokens <= 4_096 && card.batch_cap == 1
            }) && red_pass(&red_results, "max_new_tokens_too_high")
                && red_pass(&red_results, "context_cap_too_high")
                && red_pass(&red_results, "batch_cap_too_high"),
        ),
        (
            "memory_sampling_slots_bound",
            metrics.memory_sample_slot_total_count
                == (cards.len() * GEMMA_FIRST_TOKEN_MEMORY_SAMPLE_SLOT_COUNT) as u64
                && red_pass(&red_results, "memory_sample_slot_missing")
                && red_pass(&red_results, "memory_sample_slot_duplicate"),
        ),
        (
            "cancellation_teardown_rollback_bound",
            cards.iter().all(|card| {
                card.policy.cancellation_required
                    && card.policy.teardown_required
                    && card.policy.rollback_required
                    && card
                        .proof_refs
                        .cancellation_ref
                        .starts_with("cancellation:")
                    && card.proof_refs.teardown_ref.starts_with("teardown:")
                    && card.proof_refs.rollback_ref.starts_with("rollback:")
            }) && red_pass(&red_results, "cancellation_missing")
                && red_pass(&red_results, "teardown_missing")
                && red_pass(&red_results, "rollback_missing"),
        ),
        (
            "run_event_log_answer_packet_bound",
            cards.iter().all(|card| {
                card.policy.run_event_log_required
                    && card.policy.answer_packet_required
                    && card
                        .proof_refs
                        .run_event_log_ref
                        .starts_with("run_event_log:")
                    && card
                        .proof_refs
                        .answer_packet_ref
                        .starts_with("answer_packet:")
            }) && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing"),
        ),
        (
            "zero_live_bytes_commands_and_outputs",
            metrics.command_execution_count_total == 0
                && metrics.model_bytes_loaded_total == 0
                && metrics.runtime_bytes_loaded_total == 0
                && metrics.provider_calls_made_total == 0
                && metrics.stdout_bytes_captured_total == 0
                && metrics.stderr_bytes_captured_total == 0
                && red_pass(&red_results, "command_execution_count")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_calls_made")
                && red_pass(&red_results, "stdout_capture_allowed")
                && red_pass(&red_results, "stdout_bytes_captured")
                && red_pass(&red_results, "stderr_bytes_captured"),
        ),
        (
            "path_runtime_probe_blocked",
            metrics.runtime_probe_allowed_count == 0
                && metrics.local_artifact_verified_count == 0
                && red_pass(&red_results, "command_envelope_armed")
                && red_pass(&red_results, "command_execution_allowed")
                && red_pass(&red_results, "runtime_probe_allowed")
                && red_pass(&red_results, "model_path_opened")
                && red_pass(&red_results, "local_artifact_verified"),
        ),
        (
            "no_route_mutation_or_hidden_authority",
            metrics.route_mutation_allowed_count == 0
                && metrics.hidden_authority_count == 0
                && red_pass(&red_results, "route_mutation_allowed")
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "hidden_cloud_fallback"),
        ),
        (
            "no_mas_l2_l3_product_or_70b_claim",
            metrics.mas_promotion_count == 0
                && metrics.product_green_count == 0
                && metrics.l2_green_count == 0
                && metrics.l3_green_count == 0
                && metrics.live_dense_70b_claim_count == 0
                && metrics.ssd_as_ram_claim_count == 0
                && metrics.quality_claim_count == 0
                && red_pass(&red_results, "mas_l2_l3_product_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim")
                && red_pass(&red_results, "quality_claimed")
                && red_pass(&red_results, "benchmark_claimed_as_fit"),
        ),
        (
            "first_token_ledger_address_deterministic",
            ledger.ledger_address == reversed.ledger_address,
        ),
        (
            "next_cursor_bound",
            GEMMA_QAT_REDACTED_FIRST_TOKEN_PROBE_NEXT_CURSOR
                == "gemma_qat_same_fixture_runtime_replay",
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
            "redacted_first_token_card_count",
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
            "memory_sample_slot_total_count",
            metrics.memory_sample_slot_total_count,
            "==",
            16,
            "slots",
        ),
        (
            "command_execution_count_total",
            metrics.command_execution_count_total,
            "==",
            0,
            "commands",
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
            "stdout_bytes_captured_total",
            metrics.stdout_bytes_captured_total,
            "==",
            0,
            "bytes",
        ),
        (
            "stderr_bytes_captured_total",
            metrics.stderr_bytes_captured_total,
            "==",
            0,
            "bytes",
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
            34,
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
        "gemma_redacted_first_token_address",
        &ledger.ledger_address.to_string(),
        "non_empty",
    );
    add_text_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_cursor",
        GEMMA_QAT_REDACTED_FIRST_TOKEN_PROBE_NEXT_CURSOR,
        "gemma_qat_same_fixture_runtime_replay",
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
        notes: "metadata-only F-GemmaQATRedactedFirstTokenProbe: consumes the Gemma byte/KV/app envelope and defines the redacted, owner-approved, one-token first-token probe contract for E2B/E4B GGUF and LiteRT lanes. It binds prompt-template descriptors, prompt digest policy, future token digest policy, one-token/context/batch bounds, memory sampling, cancellation, teardown, rollback, RunEventLog, AnswerPacket, lane caveats, and non-promotion. It captures zero raw prompt/token/stdout/stderr bytes, executes zero commands, opens zero paths/files, loads zero model/runtime/provider bytes, and makes no MAS/L2/L3/user-facing, quality, benchmark-fit, or live-70B claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_envelope() -> Result<(bool, String), Box<dyn std::error::Error>> {
    if !Path::new(UPSTREAM_RESULT).exists() {
        return Ok((false, "missing-upstream-envelope-address".to_string()));
    }
    let value: serde_json::Value = serde_json::from_slice(&std::fs::read(UPSTREAM_RESULT)?)?;
    let pass = value
        .get("overall_pass")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);
    let address = value
        .pointer("/measurements/gemma_byte_kv_app_envelope_address/value")
        .and_then(|v| v.as_str())
        .unwrap_or("missing-upstream-envelope-address")
        .to_string();
    Ok((pass, address))
}

fn build_ledger(
    upstream_envelope_address: String,
    cards: Vec<GemmaQatRedactedFirstTokenCard>,
) -> Result<GemmaQatRedactedFirstTokenLedger, agent_core::uas::GemmaQatRedactedFirstTokenError> {
    GemmaQatRedactedFirstTokenLedger::new(
        upstream_envelope_address,
        UPSTREAM_REF,
        cards,
        LEDGER_METADATA_BYTES,
        CREATED_AT_MS,
    )
}

fn has_card(cards: &[GemmaQatRedactedFirstTokenCard], id: &str) -> bool {
    cards.iter().any(|card| card.card_id == id)
}

fn red_fixture_results(cards: &[GemmaQatRedactedFirstTokenCard]) -> Vec<(&'static str, bool)> {
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
            "bad_surface_lane",
            reject_first(cards, |card| {
                card.surface = GemmaQatFirstTokenSurface::LiteRtLmOneTokenPreflight
            }),
        ),
        (
            "owner_approval_granted",
            reject_first(cards, |card| card.owner_approval_granted = true),
        ),
        (
            "fresh_memory_sample_missing",
            reject_first(cards, |card| card.fresh_memory_sample_required = false),
        ),
        (
            "prompt_template_hidden",
            reject_first(cards, |card| card.prompt_template_visible = false),
        ),
        (
            "prompt_digest_missing",
            reject_first(cards, |card| card.prompt_digest_policy_bound = false),
        ),
        (
            "raw_prompt_text_present",
            reject_first(cards, |card| card.raw_prompt_text_present = true),
        ),
        (
            "raw_user_prompt_present",
            reject_first(cards, |card| card.raw_user_prompt_present = true),
        ),
        (
            "raw_prompt_bytes_captured",
            reject_first(cards, |card| card.byte_ledger.raw_prompt_bytes_captured = 1),
        ),
        (
            "token_digest_policy_missing",
            reject_first(cards, |card| card.first_token_digest_policy_bound = false),
        ),
        (
            "first_token_observed",
            reject_first(cards, |card| card.first_token_observed = true),
        ),
        (
            "first_token_digest_present",
            reject_first(cards, |card| card.first_token_digest_present = true),
        ),
        (
            "raw_token_text_present",
            reject_first(cards, |card| card.raw_token_text_present = true),
        ),
        (
            "raw_token_bytes_captured",
            reject_first(cards, |card| card.byte_ledger.raw_token_bytes_captured = 1),
        ),
        (
            "stdout_capture_allowed",
            reject_first(cards, |card| card.stdout_stderr_capture_allowed = true),
        ),
        (
            "stdout_bytes_captured",
            reject_first(cards, |card| card.byte_ledger.stdout_bytes_captured = 1),
        ),
        (
            "stderr_bytes_captured",
            reject_first(cards, |card| card.byte_ledger.stderr_bytes_captured = 1),
        ),
        (
            "max_new_tokens_too_high",
            reject_first(cards, |card| card.max_new_tokens = 2),
        ),
        (
            "context_cap_too_high",
            reject_first(cards, |card| card.context_cap_tokens = 8_192),
        ),
        (
            "batch_cap_too_high",
            reject_first(cards, |card| card.batch_cap = 2),
        ),
        (
            "memory_sample_slot_missing",
            reject_first(cards, |card| {
                let _ = card.memory_sample_slots.pop();
            }),
        ),
        (
            "memory_sample_slot_duplicate",
            reject_first(cards, |card| {
                if card.memory_sample_slots.len() > 1 {
                    card.memory_sample_slots[1] = card.memory_sample_slots[0].clone();
                }
            }),
        ),
        (
            "cancellation_missing",
            reject_first(cards, |card| card.policy.cancellation_required = false),
        ),
        (
            "teardown_missing",
            reject_first(cards, |card| card.policy.teardown_required = false),
        ),
        (
            "rollback_missing",
            reject_first(cards, |card| card.policy.rollback_required = false),
        ),
        (
            "run_event_log_missing",
            reject_first(cards, |card| card.policy.run_event_log_required = false),
        ),
        (
            "answer_packet_missing",
            reject_first(cards, |card| card.policy.answer_packet_required = false),
        ),
        (
            "command_envelope_armed",
            reject_first(cards, |card| card.command_envelope_armed = true),
        ),
        (
            "command_execution_allowed",
            reject_first(cards, |card| card.command_execution_allowed = true),
        ),
        (
            "runtime_probe_allowed",
            reject_first(cards, |card| card.runtime_probe_allowed = true),
        ),
        (
            "model_path_opened",
            reject_first(cards, |card| card.model_path_opened = true),
        ),
        (
            "local_artifact_verified",
            reject_first(cards, |card| card.local_artifact_verified = true),
        ),
        (
            "command_execution_count",
            reject_first(cards, |card| card.byte_ledger.command_execution_count = 1),
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
            "provider_calls_made",
            reject_first(cards, |card| card.byte_ledger.provider_calls_made = 1),
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
                card.product_route_green = true;
                card.l2_capability_green = true;
                card.l3_wrv_green = true;
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
            "quality_claimed",
            reject_first(cards, |card| card.quality_claimed = true),
        ),
        (
            "benchmark_claimed_as_fit",
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
                card.upstream_envelope_ref = "artifact:wrong".to_string()
            }),
        ),
        (
            "wrong_next_cursor",
            reject_first(cards, |card| card.next_cursor = "wrong".to_string()),
        ),
    ]
}

fn reject_first(
    cards: &[GemmaQatRedactedFirstTokenCard],
    mutate: impl FnOnce(&mut GemmaQatRedactedFirstTokenCard),
) -> bool {
    let mut bad = cards.to_vec();
    if let Some(card) = bad.first_mut() {
        mutate(card);
    }
    build_ledger("uas:gemma-byte-envelope:red".to_string(), bad).is_err()
}

fn reject_set(
    cards: &[GemmaQatRedactedFirstTokenCard],
    mutate: impl FnOnce(&mut Vec<GemmaQatRedactedFirstTokenCard>),
) -> bool {
    let mut bad = cards.to_vec();
    mutate(&mut bad);
    build_ledger("uas:gemma-byte-envelope:red".to_string(), bad).is_err()
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
    let missing = GEMMA_QAT_REDACTED_FIRST_TOKEN_PROBE_AXES
        .iter()
        .filter(|axis| !measurements.contains_key(**axis))
        .copied()
        .collect::<Vec<_>>();
    assert!(
        missing.is_empty(),
        "missing Gemma QAT redacted first-token probe axes: {missing:?}"
    );
}
