//! `falsify_exotic_quant_owner_approved_dry_run_transcript_preflight_gate`
//!
//! Metadata-only witness for
//! `F-ExoticQuantOwnerApprovedDryRunTranscriptPreflightGate`. It binds the
//! owner-approval, redaction, memory-sampling, cancellation, rollback,
//! RunEventLog, and AnswerPacket transcript slots that must exist before any
//! first-token or model-byte runtime probe is allowed.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::axes::EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_crash_safe_command_envelope_cards,
    canonical_owner_approved_dry_run_transcript_preflight_cards,
    OwnerApprovedDryRunTranscriptPreflightCard, OwnerApprovedDryRunTranscriptPreflightLedger,
    OwnerApprovedDryRunTranscriptState, OwnerApprovedDryRunTranscriptSurface, UasAddress, UasKind,
    EXOTIC_QUANT_BYTE_ENVELOPE_UPSTREAM_REF, EXOTIC_QUANT_COMMAND_ENVELOPE_UPSTREAM_REF,
    EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-ExoticQuantOwnerApprovedDryRunTranscriptPreflightGate";
const FIXTURE_ID: &str = "exotic_quant_owner_approved_dry_run_transcript_preflight_gate_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_exotic_quant_owner_approved_dry_run_transcript_preflight_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/exotic_quant_owner_approved_dry_run_transcript_preflight_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/exotic_quant_crash_safe_command_envelope_preflight_gate/result.json";
const CREATED_AT_MS: u64 = 1_779_557_200_000;

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
        "{FALSIFIER_ID}: overall_pass={} transcript_card_count={} mac_pending_count={} server_denied_count={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["transcript_card_count"].value,
        artifact.measurements["mac_candidate_owner_approval_pending_count"].value,
        artifact.measurements["server_only_transcript_denied_count"].value,
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
    let (upstream_pass, upstream_address) = upstream_command_envelope_gate()?;
    let command_cards =
        canonical_crash_safe_command_envelope_cards(EXOTIC_QUANT_BYTE_ENVELOPE_UPSTREAM_REF);
    let cards = canonical_owner_approved_dry_run_transcript_preflight_cards(
        EXOTIC_QUANT_COMMAND_ENVELOPE_UPSTREAM_REF,
        &command_cards,
    );
    let ledger = build_ledger(upstream_address.clone(), cards.clone())?;
    ledger.validate()?;
    let reversed = build_ledger(upstream_address, cards.iter().cloned().rev().collect())?;
    let metrics = &ledger.metrics;
    let red_results = red_fixture_results(&cards, &ledger.upstream_command_envelope_address);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;
    let red_fixture_count = red_results.len() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        (
            "upstream_crash_safe_command_envelope_preflight_gate_pass",
            upstream_pass,
        ),
        (
            "accepted_owner_approved_dry_run_transcript_pack_present",
            metrics.accepted_transcript_card_count == 5,
        ),
        (
            "command_envelope_cards_consumed",
            ledger
                .cards
                .iter()
                .all(|card| !card.upstream_command_envelope_card_id.is_empty()),
        ),
        (
            "runtime_surface_classification_bound",
            metrics.mac_candidate_owner_approval_pending_count == 3
                && metrics.server_only_transcript_denied_count == 2
                && red_pass(&red_results, "wrong_surface_state"),
        ),
        (
            "mac_candidate_owner_approval_pending",
            ledger.cards.iter().all(|card| {
                card.state
                    != OwnerApprovedDryRunTranscriptState::MacCandidateOwnerApprovalPendingTranscriptPreflight
                    || (card.owner_approval_required
                        && !card.owner_approval_granted
                        && !card.server_only_transcript_denied)
            }) && red_pass(&red_results, "owner_approval_granted")
                && red_pass(&red_results, "missing_owner_approval_required"),
        ),
        (
            "server_only_transcript_denied",
            ledger.cards.iter().all(|card| {
                card.surface != OwnerApprovedDryRunTranscriptSurface::ServerOnlyTranscriptDenied
                    || (card.server_only_transcript_denied && !card.owner_approval_required)
            }),
        ),
        (
            "transcript_phases_bound",
            metrics.transcript_phase_total_count
                == metrics.accepted_transcript_card_count * 13
                && red_pass(&red_results, "missing_scope_rex_admission")
                && red_pass(&red_results, "missing_serialized_executor")
                && red_pass(&red_results, "missing_run_event_log")
                && red_pass(&red_results, "missing_answer_packet"),
        ),
        (
            "owner_approval_required_not_granted",
            metrics.owner_approval_required_count == 3
                && metrics.owner_approval_granted_count == 0,
        ),
        (
            "scope_rex_admission_and_serialized_executor_bound",
            ledger.cards.iter().all(|card| {
                card.policy.scope_rex_admission_required == card.owner_approval_required
                    && !card.policy.scope_rex_admission_granted
                    && card.policy.serialized_executor_bound
            }) && red_pass(&red_results, "missing_scope_rex_admission")
                && red_pass(&red_results, "missing_serialized_executor"),
        ),
        (
            "synthetic_prompt_and_redaction_bound",
            ledger.cards.iter().all(|card| {
                card.policy.synthetic_non_user_prompt_only
                    && card.policy.prompt_redaction_bound
                    && card.policy.raw_user_prompt_storage_denied
            }) && red_pass(&red_results, "raw_user_prompt_storage")
                && red_pass(&red_results, "missing_prompt_redaction"),
        ),
        (
            "stdout_stderr_credential_redaction_bound",
            ledger.cards.iter().all(|card| {
                card.policy.stdout_stderr_redaction_bound
                    && !card.policy.stdout_stderr_capture_allowed
                    && card.policy.credential_redaction_bound
            }) && red_pass(&red_results, "stdout_stderr_capture_allowed")
                && red_pass(&red_results, "missing_credential_redaction"),
        ),
        (
            "memory_timeout_cancellation_teardown_bound",
            ledger.cards.iter().all(|card| {
                card.policy.memory_sampling_plan_bound
                    && card.policy.timeout_bound
                    && card.policy.cancellation_bound
                    && card.policy.teardown_bound
            }) && red_pass(&red_results, "missing_memory_sampling")
                && red_pass(&red_results, "missing_timeout")
                && red_pass(&red_results, "missing_cancellation")
                && red_pass(&red_results, "missing_teardown"),
        ),
        (
            "rollback_run_event_answer_packet_bound",
            ledger.cards.iter().all(|card| {
                card.policy.rollback_bound
                    && card.policy.run_event_log_bound
                    && card.policy.answer_packet_bound
            }) && red_pass(&red_results, "missing_rollback")
                && red_pass(&red_results, "missing_run_event_log")
                && red_pass(&red_results, "missing_answer_packet"),
        ),
        (
            "token_digest_future_only_no_first_token",
            ledger.cards.iter().all(|card| {
                card.policy.token_digest_future_only
                    && !card.first_token_probe_allowed
                    && !card.first_token_observed
                    && card.token_byte_limit == 0
            }) && red_pass(&red_results, "first_token_observed"),
        ),
        (
            "zero_live_bytes_and_commands",
            metrics.command_execution_count == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.model_artifact_bytes_read == 0
                && metrics.stdout_bytes_captured == 0
                && metrics.stderr_bytes_captured == 0
                && metrics.token_bytes_captured == 0
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "model_bytes_read")
                && red_pass(&red_results, "stdout_bytes_captured")
                && red_pass(&red_results, "stderr_bytes_captured")
                && red_pass(&red_results, "token_bytes_captured"),
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
                == EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_NEXT_CURSOR,
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
            "transcript_card_count",
            metrics.accepted_transcript_card_count as u64,
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
            "server_only_transcript_denied_count",
            metrics.server_only_transcript_denied_count as u64,
            2,
            "cards",
        ),
        (
            "transcript_phase_total_count",
            metrics.transcript_phase_total_count as u64,
            65,
            "phase_refs",
        ),
        (
            "owner_approval_required_count",
            metrics.owner_approval_required_count as u64,
            3,
            "cards",
        ),
        (
            "owner_approval_granted_count",
            metrics.owner_approval_granted_count as u64,
            0,
            "cards",
        ),
        (
            "dry_run_execution_allowed_count",
            metrics.dry_run_execution_allowed_count as u64,
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
            "runtime_probe_allowed_count",
            metrics.runtime_probe_allowed_count as u64,
            0,
            "cards",
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
            "stdout_bytes_captured_total",
            metrics.stdout_bytes_captured,
            0,
            "bytes",
        ),
        (
            "stderr_bytes_captured_total",
            metrics.stderr_bytes_captured,
            0,
            "bytes",
        ),
        (
            "token_bytes_captured_total",
            metrics.token_bytes_captured,
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
        "owner_approved_dry_run_transcript_preflight_gate_address".to_string(),
        Measurement {
            value: serde_json::json!(ledger.address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "owner_approved_dry_run_transcript_preflight_gate_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "owner_approved_dry_run_transcript_preflight_gate_address".to_string(),
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
                EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        ledger.next_cursor
            == EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_NEXT_CURSOR,
    );

    for axis in EXOTIC_QUANT_OWNER_APPROVED_DRY_RUN_TRANSCRIPT_PREFLIGHT_GATE_AXES {
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
        notes: "metadata-only F-ExoticQuantOwnerApprovedDryRunTranscriptPreflightGate: compiles the owner-approved dry-run transcript contract after the crash-safe command envelope and before any first-token, model-byte, provider, benchmark, or product-route probe. It binds owner approval, SCOPE-Rex admission, serialized executor, synthetic prompt/redaction, stdout/stderr/credential redaction, memory sampling, timeout, cancellation, teardown, rollback, RunEventLog, and AnswerPacket proof slots. It executes zero commands, loads zero runtime/model bytes, and makes no L2/L3/MAS/user-facing promotion.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_command_envelope_gate() -> Result<(bool, UasAddress), Box<dyn std::error::Error>> {
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
            .map(|id| id == "F-ExoticQuantCrashSafeCommandEnvelopePreflightGate")
            .unwrap_or(false);
    let address = json
        .pointer("/measurements/crash_safe_command_envelope_preflight_gate_address/value")
        .and_then(serde_json::Value::as_str)
        .and_then(|value| UasAddress::from_str(value).ok())
        .unwrap_or_else(fallback_upstream_address);
    Ok((pass, address))
}

fn fallback_upstream_address() -> UasAddress {
    UasAddress::new(
        UasKind::Other("exotic_quant_crash_safe_command_envelope_preflight_gate".to_string()),
        b"fallback-crash-safe-command-envelope-preflight-gate-address",
        CREATED_AT_MS,
    )
}

fn build_ledger(
    upstream_address: UasAddress,
    cards: Vec<OwnerApprovedDryRunTranscriptPreflightCard>,
) -> Result<
    OwnerApprovedDryRunTranscriptPreflightLedger,
    agent_core::uas::OwnerApprovedDryRunTranscriptPreflightError,
> {
    OwnerApprovedDryRunTranscriptPreflightLedger::new(
        EXOTIC_QUANT_COMMAND_ENVELOPE_UPSTREAM_REF,
        upstream_address,
        cards,
    )
}

fn red_pass(results: &[(&'static str, bool)], id: &str) -> bool {
    results
        .iter()
        .find(|(fixture_id, _)| *fixture_id == id)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn red_fixture_results(
    cards: &[OwnerApprovedDryRunTranscriptPreflightCard],
    upstream_address: &UasAddress,
) -> Vec<(&'static str, bool)> {
    vec![
        (
            "duplicate_gate_id",
            reject_cards(cards, upstream_address, |bad| {
                bad[1].gate_id = bad[0].gate_id.clone()
            }),
        ),
        (
            "missing_expected_model",
            reject_cards(cards, upstream_address, |bad| {
                bad.remove(0);
            }),
        ),
        (
            "bad_upstream_ref",
            OwnerApprovedDryRunTranscriptPreflightLedger::new(
                "artifact:falsifiers/wrong_gate/result.json#Wrong",
                upstream_address.clone(),
                cards.to_vec(),
            )
            .is_err(),
        ),
        (
            "bad_command_card_ref",
            reject_first(cards, upstream_address, |card| {
                card.upstream_command_envelope_card_id.clear()
            }),
        ),
        (
            "wrong_surface_state",
            reject_first(cards, upstream_address, |card| {
                card.surface = OwnerApprovedDryRunTranscriptSurface::ServerOnlyTranscriptDenied;
                card.state =
                    OwnerApprovedDryRunTranscriptState::MacCandidateOwnerApprovalPendingTranscriptPreflight;
            }),
        ),
        (
            "owner_approval_granted",
            reject_first(cards, upstream_address, |card| {
                card.owner_approval_granted = true;
                card.policy.owner_approval_granted = true;
            }),
        ),
        (
            "missing_owner_approval_required",
            reject_first_mac(cards, upstream_address, |card| {
                card.owner_approval_required = false;
                card.policy.owner_approval_required = false;
                card.policy.scope_rex_admission_required = false;
            }),
        ),
        (
            "missing_scope_rex_admission",
            reject_first_mac(cards, upstream_address, |card| {
                card.policy.scope_rex_admission_required = false;
            }),
        ),
        (
            "missing_serialized_executor",
            reject_first(cards, upstream_address, |card| {
                card.policy.serialized_executor_bound = false;
            }),
        ),
        (
            "raw_user_prompt_storage",
            reject_first(cards, upstream_address, |card| {
                card.policy.raw_user_prompt_storage_denied = false;
            }),
        ),
        (
            "missing_prompt_redaction",
            reject_first(cards, upstream_address, |card| {
                card.policy.prompt_redaction_bound = false;
            }),
        ),
        (
            "stdout_stderr_capture_allowed",
            reject_first(cards, upstream_address, |card| {
                card.policy.stdout_stderr_capture_allowed = true;
            }),
        ),
        (
            "output_unbounded",
            reject_first(cards, upstream_address, |card| {
                card.stdout_byte_limit = 0;
            }),
        ),
        (
            "missing_credential_redaction",
            reject_first(cards, upstream_address, |card| {
                card.policy.credential_redaction_bound = false;
            }),
        ),
        (
            "missing_memory_sampling",
            reject_first(cards, upstream_address, |card| {
                card.policy.memory_sampling_plan_bound = false;
            }),
        ),
        (
            "missing_timeout",
            reject_first(cards, upstream_address, |card| {
                card.policy.timeout_bound = false;
            }),
        ),
        (
            "missing_cancellation",
            reject_first(cards, upstream_address, |card| {
                card.policy.cancellation_bound = false;
            }),
        ),
        (
            "missing_teardown",
            reject_first(cards, upstream_address, |card| {
                card.policy.teardown_bound = false;
            }),
        ),
        (
            "missing_rollback",
            reject_first(cards, upstream_address, |card| {
                card.policy.rollback_bound = false;
            }),
        ),
        (
            "missing_run_event_log",
            reject_first(cards, upstream_address, |card| {
                card.policy.run_event_log_bound = false;
            }),
        ),
        (
            "missing_answer_packet",
            reject_first(cards, upstream_address, |card| {
                card.policy.answer_packet_bound = false;
            }),
        ),
        (
            "first_token_observed",
            reject_first(cards, upstream_address, |card| {
                card.first_token_observed = true;
            }),
        ),
        (
            "command_executed",
            reject_first(cards, upstream_address, |card| {
                card.byte_ledger.command_execution_count = 1;
            }),
        ),
        (
            "runtime_probe_allowed",
            reject_first(cards, upstream_address, |card| {
                card.runtime_probe_allowed = true;
            }),
        ),
        (
            "runtime_not_deferred",
            reject_first(cards, upstream_address, |card| {
                card.runtime_deferred = false;
            }),
        ),
        (
            "model_path_opened",
            reject_first(cards, upstream_address, |card| {
                card.model_path_opened = true;
            }),
        ),
        (
            "local_artifact_verified",
            reject_first(cards, upstream_address, |card| {
                card.local_artifact_verified = true;
            }),
        ),
        (
            "runtime_bytes_loaded",
            reject_first(cards, upstream_address, |card| {
                card.byte_ledger.runtime_bytes_loaded = 1;
            }),
        ),
        (
            "model_bytes_read",
            reject_first(cards, upstream_address, |card| {
                card.byte_ledger.model_artifact_bytes_read = 1;
            }),
        ),
        (
            "stdout_bytes_captured",
            reject_first(cards, upstream_address, |card| {
                card.byte_ledger.stdout_bytes_captured = 1;
            }),
        ),
        (
            "stderr_bytes_captured",
            reject_first(cards, upstream_address, |card| {
                card.byte_ledger.stderr_bytes_captured = 1;
            }),
        ),
        (
            "token_bytes_captured",
            reject_first(cards, upstream_address, |card| {
                card.byte_ledger.token_bytes_captured = 1;
            }),
        ),
        (
            "network_bytes_read",
            reject_first(cards, upstream_address, |card| {
                card.byte_ledger.network_bytes_read = 1;
            }),
        ),
        (
            "provider_bytes_read",
            reject_first(cards, upstream_address, |card| {
                card.byte_ledger.provider_bytes_read = 1;
            }),
        ),
        (
            "source_code_imported",
            reject_first(cards, upstream_address, |card| {
                card.source_code_imported = true;
            }),
        ),
        (
            "benchmark_claimed_as_fit",
            reject_first(cards, upstream_address, |card| {
                card.benchmark_claimed_as_fit = true;
            }),
        ),
        (
            "product_route_green",
            reject_first(cards, upstream_address, |card| {
                card.product_route_green = true;
            }),
        ),
        (
            "l2_green",
            reject_first(cards, upstream_address, |card| {
                card.l2_capability_green = true;
            }),
        ),
        (
            "l3_green",
            reject_first(cards, upstream_address, |card| {
                card.l3_wrv_green = true;
            }),
        ),
        (
            "hidden_route_authority",
            reject_first(cards, upstream_address, |card| {
                card.hidden_route_authority = true;
            }),
        ),
        (
            "hidden_cloud_fallback",
            reject_first(cards, upstream_address, |card| {
                card.hidden_cloud_fallback = true;
            }),
        ),
        (
            "patternboost_authority",
            reject_first(cards, upstream_address, |card| {
                card.hidden_patternboost_authority = true;
            }),
        ),
        (
            "lattice_authority",
            reject_first(cards, upstream_address, |card| {
                card.hidden_lattice_authority = true;
            }),
        ),
        (
            "eidos_authority",
            reject_first(cards, upstream_address, |card| {
                card.hidden_eidos_authority = true;
            }),
        ),
        (
            "live_dense_70b",
            reject_first(cards, upstream_address, |card| {
                card.live_dense_70b_claim = true;
            }),
        ),
        (
            "ssd_as_ram",
            reject_first(cards, upstream_address, |card| {
                card.ssd_as_ram_claim = true;
            }),
        ),
        (
            "metadata_budget_exceeded",
            reject_first(cards, upstream_address, |card| {
                card.byte_ledger.metadata_bytes_read = 1_000_000;
            }),
        ),
    ]
}

fn reject_cards<F>(
    cards: &[OwnerApprovedDryRunTranscriptPreflightCard],
    upstream_address: &UasAddress,
    mutate: F,
) -> bool
where
    F: FnOnce(&mut Vec<OwnerApprovedDryRunTranscriptPreflightCard>),
{
    let mut bad = cards.to_vec();
    mutate(&mut bad);
    build_ledger(upstream_address.clone(), bad).is_err()
}

fn reject_first<F>(
    cards: &[OwnerApprovedDryRunTranscriptPreflightCard],
    upstream_address: &UasAddress,
    mutate: F,
) -> bool
where
    F: FnOnce(&mut OwnerApprovedDryRunTranscriptPreflightCard),
{
    reject_cards(cards, upstream_address, |bad| {
        if let Some(first) = bad.first_mut() {
            mutate(first);
        }
    })
}

fn reject_first_mac<F>(
    cards: &[OwnerApprovedDryRunTranscriptPreflightCard],
    upstream_address: &UasAddress,
    mutate: F,
) -> bool
where
    F: FnOnce(&mut OwnerApprovedDryRunTranscriptPreflightCard),
{
    reject_cards(cards, upstream_address, |bad| {
        if let Some(first) = bad.iter_mut().find(|card| card.owner_approval_required) {
            mutate(first);
        }
    })
}
