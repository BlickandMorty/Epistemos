//! `falsify_exotic_quant_redacted_first_token_probe_preflight_gate`
//!
//! Metadata-only witness for `F-ExoticQuantRedactedFirstTokenProbePreflightGate`.
//! It compiles the privacy and safety contract required before any owner-approved
//! one-token runtime probe can happen.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::axes::EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_crash_safe_command_envelope_cards,
    canonical_owner_approved_dry_run_transcript_preflight_cards,
    canonical_redacted_first_token_probe_preflight_cards, RedactedFirstTokenProbePreflightCard,
    RedactedFirstTokenProbePreflightLedger, RedactedFirstTokenProbeState,
    RedactedFirstTokenProbeSurface, UasAddress, UasKind, EXOTIC_QUANT_BYTE_ENVELOPE_UPSTREAM_REF,
    EXOTIC_QUANT_COMMAND_ENVELOPE_UPSTREAM_REF, EXOTIC_QUANT_DRY_RUN_TRANSCRIPT_UPSTREAM_REF,
    EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-ExoticQuantRedactedFirstTokenProbePreflightGate";
const FIXTURE_ID: &str = "exotic_quant_redacted_first_token_probe_preflight_gate_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_exotic_quant_redacted_first_token_probe_preflight_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/exotic_quant_redacted_first_token_probe_preflight_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/exotic_quant_owner_approved_dry_run_transcript_preflight_gate/result.json";
const CREATED_AT_MS: u64 = 1_779_560_800_000;

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
        "{FALSIFIER_ID}: overall_pass={} card_count={} mac_pending_count={} server_denied_count={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["redacted_first_token_card_count"].value,
        artifact.measurements["mac_candidate_owner_approval_pending_count"].value,
        artifact.measurements["server_only_probe_denied_count"].value,
        artifact.measurements["red_fixture_rejection_count"].value,
        artifact.measurements["next_cursor"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let (upstream_pass, upstream_address) = upstream_dry_run_transcript_gate()?;
    let command_cards =
        canonical_crash_safe_command_envelope_cards(EXOTIC_QUANT_BYTE_ENVELOPE_UPSTREAM_REF);
    let transcript_cards = canonical_owner_approved_dry_run_transcript_preflight_cards(
        EXOTIC_QUANT_COMMAND_ENVELOPE_UPSTREAM_REF,
        &command_cards,
    );
    let cards = canonical_redacted_first_token_probe_preflight_cards(
        EXOTIC_QUANT_DRY_RUN_TRANSCRIPT_UPSTREAM_REF,
        &transcript_cards,
    );
    let ledger = build_ledger(upstream_address.clone(), cards.clone())?;
    ledger.validate()?;
    let reversed = build_ledger(upstream_address, cards.iter().cloned().rev().collect())?;
    let metrics = &ledger.metrics;
    let red_results = red_fixture_results(&cards, &ledger.upstream_dry_run_transcript_address);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;
    let red_fixture_count = red_results.len() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        (
            "upstream_owner_approved_dry_run_transcript_preflight_gate_pass",
            upstream_pass,
        ),
        (
            "accepted_redacted_first_token_preflight_pack_present",
            metrics.accepted_card_count == 5,
        ),
        (
            "transcript_cards_consumed",
            ledger
                .cards
                .iter()
                .all(|card| !card.upstream_transcript_card_id.is_empty()),
        ),
        (
            "runtime_surface_classification_bound",
            metrics.mac_candidate_owner_approval_pending_count == 3
                && metrics.server_only_probe_denied_count == 2
                && red_pass(&red_results, "wrong_surface_state"),
        ),
        (
            "mac_candidate_owner_approval_pending",
            ledger.cards.iter().all(|card| {
                card.state
                    != RedactedFirstTokenProbeState::MacCandidateOwnerApprovalPendingRedactedFirstTokenPreflight
                    || (card.owner_approval_required
                        && !card.owner_approval_granted
                        && !card.server_only_probe_denied)
            }) && red_pass(&red_results, "owner_approval_granted"),
        ),
        (
            "server_only_probe_denied",
            ledger.cards.iter().all(|card| {
                card.surface != RedactedFirstTokenProbeSurface::ServerOnlyFirstTokenProbeDenied
                    || (card.server_only_probe_denied && !card.owner_approval_required)
            }),
        ),
        (
            "synthetic_prompt_descriptor_visible",
            ledger
                .cards
                .iter()
                .all(|card| card.prompt_template_visible && !card.raw_user_prompt_present)
                && red_pass(&red_results, "raw_user_prompt_present"),
        ),
        (
            "prompt_digest_policy_bound_no_raw_prompt",
            metrics.prompt_digest_policy_bound_count == metrics.accepted_card_count
                && metrics.raw_prompt_text_present_count == 0
                && red_pass(&red_results, "raw_prompt_text_present")
                && red_pass(&red_results, "missing_prompt_digest_policy"),
        ),
        (
            "token_digest_policy_bound_no_raw_token",
            metrics.token_digest_policy_bound_count == metrics.accepted_card_count
                && metrics.raw_token_text_present_count == 0
                && metrics.first_token_observed_count == 0
                && metrics.first_token_digest_present_count == 0
                && red_pass(&red_results, "raw_token_text_present")
                && red_pass(&red_results, "first_token_observed")
                && red_pass(&red_results, "first_token_digest_present"),
        ),
        (
            "one_token_context_batch_bounds",
            metrics.one_token_bound_count == metrics.accepted_card_count
                && ledger
                    .cards
                    .iter()
                    .all(|card| card.context_cap_tokens <= 4_096 && card.batch_cap == 1)
                && red_pass(&red_results, "max_new_tokens_two")
                && red_pass(&red_results, "context_cap_unbounded")
                && red_pass(&red_results, "batch_cap_unbounded"),
        ),
        (
            "memory_sampling_slots_bound",
            metrics.memory_sample_slot_total_count == metrics.accepted_card_count * 4
                && red_pass(&red_results, "missing_memory_sample_slot"),
        ),
        (
            "cancellation_teardown_rollback_bound",
            ledger.cards.iter().all(|card| {
                card.policy.cancellation_required
                    && card.policy.teardown_required
                    && card.policy.rollback_required
            }) && red_pass(&red_results, "missing_cancellation")
                && red_pass(&red_results, "missing_teardown")
                && red_pass(&red_results, "missing_rollback"),
        ),
        (
            "run_event_log_answer_packet_bound",
            ledger.cards.iter().all(|card| {
                card.policy.run_event_log_required && card.policy.answer_packet_required
            }) && red_pass(&red_results, "missing_run_event_log")
                && red_pass(&red_results, "missing_answer_packet"),
        ),
        (
            "zero_live_bytes_commands_and_outputs",
            metrics.command_execution_count == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.model_artifact_bytes_read == 0
                && metrics.raw_prompt_bytes_captured == 0
                && metrics.raw_token_bytes_captured == 0
                && metrics.stdout_bytes_captured == 0
                && metrics.stderr_bytes_captured == 0
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "model_bytes_read")
                && red_pass(&red_results, "raw_prompt_bytes_captured")
                && red_pass(&red_results, "raw_token_bytes_captured")
                && red_pass(&red_results, "stdout_bytes_captured")
                && red_pass(&red_results, "stderr_bytes_captured"),
        ),
        (
            "mas_product_route_denied",
            metrics.product_green_count == 0
                && red_pass(&red_results, "product_route_green")
                && red_pass(&red_results, "l2_green")
                && red_pass(&red_results, "l3_green"),
        ),
        (
            "no_hidden_authority",
            metrics.hidden_authority_count == 0
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "hidden_cloud_fallback")
                && red_pass(&red_results, "patternboost_authority")
                && red_pass(&red_results, "lattice_authority")
                && red_pass(&red_results, "eidos_authority"),
        ),
        (
            "no_l2_l3_live70b_ssd",
            ledger.cards.iter().all(|card| {
                !card.l2_capability_green
                    && !card.l3_wrv_green
                    && !card.live_dense_70b_claim
                    && !card.ssd_as_ram_claim
            }) && red_pass(&red_results, "live_dense_70b")
                && red_pass(&red_results, "ssd_as_ram"),
        ),
        (
            "no_source_import_or_benchmark_fit",
            ledger
                .cards
                .iter()
                .all(|card| !card.source_code_imported && !card.benchmark_claimed_as_fit)
                && red_pass(&red_results, "source_code_imported")
                && red_pass(&red_results, "benchmark_claimed_as_fit"),
        ),
        ("deterministic_address", ledger.address == reversed.address),
        (
            "next_cursor_bound",
            ledger.next_cursor
                == EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_NEXT_CURSOR,
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

    for (id, passed) in &red_results {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            id,
            *passed,
        );
    }

    for (name, actual, expected, unit) in [
        (
            "redacted_first_token_card_count",
            metrics.accepted_card_count as u64,
            5,
            "cards",
        ),
        (
            "mac_candidate_owner_approval_pending_count",
            metrics.mac_candidate_owner_approval_pending_count as u64,
            3,
            "cards",
        ),
        (
            "server_only_probe_denied_count",
            metrics.server_only_probe_denied_count as u64,
            2,
            "cards",
        ),
        (
            "prompt_digest_policy_bound_count",
            metrics.prompt_digest_policy_bound_count as u64,
            5,
            "cards",
        ),
        (
            "token_digest_policy_bound_count",
            metrics.token_digest_policy_bound_count as u64,
            5,
            "cards",
        ),
        (
            "raw_prompt_text_present_count",
            metrics.raw_prompt_text_present_count as u64,
            0,
            "cards",
        ),
        (
            "raw_token_text_present_count",
            metrics.raw_token_text_present_count as u64,
            0,
            "cards",
        ),
        (
            "first_token_observed_count",
            metrics.first_token_observed_count as u64,
            0,
            "cards",
        ),
        (
            "first_token_digest_present_count",
            metrics.first_token_digest_present_count as u64,
            0,
            "cards",
        ),
        (
            "memory_sample_slot_total_count",
            metrics.memory_sample_slot_total_count as u64,
            20,
            "slots",
        ),
        (
            "command_execution_count_total",
            metrics.command_execution_count as u64,
            0,
            "commands",
        ),
        (
            "runtime_bytes_loaded_total",
            metrics.runtime_bytes_loaded,
            0,
            "bytes",
        ),
        (
            "model_artifact_bytes_read_total",
            metrics.model_artifact_bytes_read,
            0,
            "bytes",
        ),
        (
            "raw_prompt_bytes_captured_total",
            metrics.raw_prompt_bytes_captured,
            0,
            "bytes",
        ),
        (
            "raw_token_bytes_captured_total",
            metrics.raw_token_bytes_captured,
            0,
            "bytes",
        ),
        (
            "red_fixture_count",
            red_fixture_count,
            red_fixture_count,
            "fixtures",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            red_fixture_count,
            "fixtures",
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            actual,
            "==",
            expected,
            unit,
        );
    }

    measurements.insert(
        "redacted_first_token_probe_preflight_gate_address".to_string(),
        Measurement {
            value: serde_json::json!(ledger.address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "redacted_first_token_probe_preflight_gate_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "redacted_first_token_probe_preflight_gate_address".to_string(),
        !ledger.address.to_string().is_empty(),
    );

    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(ledger.next_cursor),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "eq".to_string(),
            value: serde_json::json!(
                EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        ledger.next_cursor == EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_NEXT_CURSOR,
    );

    for axis in EXOTIC_QUANT_REDACTED_FIRST_TOKEN_PROBE_PREFLIGHT_GATE_AXES {
        measurements
            .entry((*axis).to_string())
            .or_insert(Measurement {
                value: serde_json::json!(false),
                unit: "axis_missing".to_string(),
            });
        thresholds
            .entry((*axis).to_string())
            .or_insert(AcceptanceThreshold {
                operator: "present".to_string(),
                value: serde_json::json!(true),
                unit: "axis_missing".to_string(),
            });
        pass_per_axis.entry((*axis).to_string()).or_insert(false);
    }

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
        notes: "metadata-only F-ExoticQuantRedactedFirstTokenProbePreflightGate: compiles the redacted first-token probe contract after owner-approved dry-run transcript preflight and before any owner-approved runtime probe. It binds synthetic prompt descriptors, prompt digest policy, first-token digest policy, one-token/context/batch bounds, memory sampling slots, cancellation, teardown, rollback, RunEventLog, AnswerPacket, lane caveat, and non-promotion. It executes zero commands, captures zero raw prompt/token/stdout/stderr bytes, loads zero runtime/model/provider bytes, and makes no L2/L3/MAS/user-facing promotion.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_dry_run_transcript_gate() -> Result<(bool, UasAddress), Box<dyn std::error::Error>> {
    let bytes = std::fs::read(UPSTREAM_RESULT)
        .or_else(|_| std::fs::read(PathBuf::from("..").join(UPSTREAM_RESULT)))?;
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    let pass = json
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
        && json
            .get("falsifier_id")
            .and_then(serde_json::Value::as_str)
            .map(|id| id == "F-ExoticQuantOwnerApprovedDryRunTranscriptPreflightGate")
            .unwrap_or(false);
    let address = json
        .pointer("/measurements/owner_approved_dry_run_transcript_preflight_gate_address/value")
        .and_then(serde_json::Value::as_str)
        .and_then(|value| UasAddress::from_str(value).ok())
        .unwrap_or_else(fallback_upstream_address);
    Ok((pass, address))
}

fn fallback_upstream_address() -> UasAddress {
    UasAddress::new(
        UasKind::Other("exotic_quant_owner_approved_dry_run_transcript_preflight_gate".to_string()),
        b"fallback-owner-approved-dry-run-transcript-preflight-gate-address",
        CREATED_AT_MS,
    )
}

fn build_ledger(
    upstream_address: UasAddress,
    cards: Vec<RedactedFirstTokenProbePreflightCard>,
) -> Result<
    RedactedFirstTokenProbePreflightLedger,
    agent_core::uas::RedactedFirstTokenProbePreflightError,
> {
    RedactedFirstTokenProbePreflightLedger::new(
        EXOTIC_QUANT_DRY_RUN_TRANSCRIPT_UPSTREAM_REF,
        upstream_address,
        cards,
    )
}

fn red_fixture_results(
    cards: &[RedactedFirstTokenProbePreflightCard],
    upstream_address: &UasAddress,
) -> Vec<(String, bool)> {
    let mut results = Vec::new();
    let mut add = |id: &str, mutate: fn(&mut Vec<RedactedFirstTokenProbePreflightCard>)| {
        let mut fixture = cards.to_vec();
        mutate(&mut fixture);
        let rejected = RedactedFirstTokenProbePreflightLedger::new(
            EXOTIC_QUANT_DRY_RUN_TRANSCRIPT_UPSTREAM_REF,
            upstream_address.clone(),
            fixture,
        )
        .is_err();
        results.push((id.to_string(), rejected));
    };

    add("duplicate_gate_id", |cards| {
        cards[1].gate_id = cards[0].gate_id.clone();
    });
    add("missing_expected_model", |cards| {
        cards.pop();
    });
    add("bad_upstream_ref", |cards| {
        cards[0].proof_refs.upstream_dry_run_transcript_ref =
            "artifact:falsifiers/wrong/result.json#Wrong".to_string();
    });
    add("bad_transcript_card_ref", |cards| {
        cards[0].upstream_transcript_card_id.clear();
    });
    add("wrong_surface_state", |cards| {
        cards[0].surface = RedactedFirstTokenProbeSurface::ServerOnlyFirstTokenProbeDenied;
    });
    add("owner_approval_granted", |cards| {
        cards[0].owner_approval_granted = true;
        cards[0].policy.owner_approval_granted = true;
    });
    add("raw_user_prompt_present", |cards| {
        cards[0].raw_user_prompt_present = true;
    });
    add("raw_prompt_text_present", |cards| {
        cards[0].raw_prompt_text_present = true;
    });
    add("missing_prompt_digest_policy", |cards| {
        cards[0].prompt_digest_policy_bound = false;
    });
    add("raw_token_text_present", |cards| {
        cards[0].raw_token_text_present = true;
    });
    add("first_token_observed", |cards| {
        cards[0].first_token_observed = true;
    });
    add("first_token_digest_present", |cards| {
        cards[0].first_token_digest_present = true;
    });
    add("max_new_tokens_two", |cards| {
        cards[0].max_new_tokens = 2;
    });
    add("context_cap_unbounded", |cards| {
        cards[0].context_cap_tokens = 65_536;
    });
    add("batch_cap_unbounded", |cards| {
        cards[0].batch_cap = 8;
    });
    add("missing_memory_sample_slot", |cards| {
        cards[0].memory_sample_slots.pop();
    });
    add("missing_cancellation", |cards| {
        cards[0].policy.cancellation_required = false;
    });
    add("missing_teardown", |cards| {
        cards[0].policy.teardown_required = false;
    });
    add("missing_rollback", |cards| {
        cards[0].policy.rollback_required = false;
    });
    add("missing_run_event_log", |cards| {
        cards[0].policy.run_event_log_required = false;
    });
    add("missing_answer_packet", |cards| {
        cards[0].policy.answer_packet_required = false;
    });
    add("command_executed", |cards| {
        cards[0].byte_ledger.command_execution_count = 1;
    });
    add("runtime_probe_allowed", |cards| {
        cards[0].runtime_probe_allowed = true;
    });
    add("model_path_opened", |cards| {
        cards[0].model_path_opened = true;
    });
    add("local_artifact_verified", |cards| {
        cards[0].local_artifact_verified = true;
    });
    add("runtime_bytes_loaded", |cards| {
        cards[0].byte_ledger.runtime_bytes_loaded = 1;
    });
    add("model_bytes_read", |cards| {
        cards[0].byte_ledger.model_artifact_bytes_read = 1;
    });
    add("raw_prompt_bytes_captured", |cards| {
        cards[0].byte_ledger.raw_prompt_bytes_captured = 1;
    });
    add("raw_token_bytes_captured", |cards| {
        cards[0].byte_ledger.raw_token_bytes_captured = 1;
    });
    add("stdout_bytes_captured", |cards| {
        cards[0].byte_ledger.stdout_bytes_captured = 1;
    });
    add("stderr_bytes_captured", |cards| {
        cards[0].byte_ledger.stderr_bytes_captured = 1;
    });
    add("product_route_green", |cards| {
        cards[0].product_route_green = true;
    });
    add("l2_green", |cards| {
        cards[0].l2_capability_green = true;
    });
    add("l3_green", |cards| {
        cards[0].l3_wrv_green = true;
    });
    add("hidden_route_authority", |cards| {
        cards[0].hidden_route_authority = true;
    });
    add("hidden_cloud_fallback", |cards| {
        cards[0].hidden_cloud_fallback = true;
    });
    add("patternboost_authority", |cards| {
        cards[0].hidden_patternboost_authority = true;
    });
    add("lattice_authority", |cards| {
        cards[0].hidden_lattice_authority = true;
    });
    add("eidos_authority", |cards| {
        cards[0].hidden_eidos_authority = true;
    });
    add("live_dense_70b", |cards| {
        cards[0].live_dense_70b_claim = true;
    });
    add("ssd_as_ram", |cards| {
        cards[0].ssd_as_ram_claim = true;
    });
    add("source_code_imported", |cards| {
        cards[0].source_code_imported = true;
    });
    add("benchmark_claimed_as_fit", |cards| {
        cards[0].benchmark_claimed_as_fit = true;
    });
    add("metadata_budget_exceeded", |cards| {
        cards[0].byte_ledger.metadata_bytes_read = 1_000_000;
    });
    add("wrong_next_cursor", |cards| {
        cards[0].next_cursor = "runtime_now".to_string();
    });

    results
}

fn red_pass(results: &[(String, bool)], id: &str) -> bool {
    results
        .iter()
        .find(|(candidate, _)| candidate == id)
        .map(|(_, passed)| *passed)
        .unwrap_or(false)
}
