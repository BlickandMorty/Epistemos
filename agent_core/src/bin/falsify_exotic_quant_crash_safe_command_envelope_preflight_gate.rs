//! `falsify_exotic_quant_crash_safe_command_envelope_preflight_gate`
//!
//! Metadata-only witness for
//! `F-ExoticQuantCrashSafeCommandEnvelopePreflightGate`. It serializes inert
//! command/API envelopes after byte-envelope denial and before any owner-
//! approved dry run, first token, model load, provider call, or product-route
//! promotion can begin.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::axes::EXOTIC_QUANT_CRASH_SAFE_COMMAND_ENVELOPE_PREFLIGHT_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_crash_safe_command_envelope_cards, CompressedModelPromotionTier,
    CrashSafeCommandEnvelopeCard, CrashSafeCommandEnvelopeLedger, CrashSafeCommandEnvelopeState,
    CrashSafeCommandSurface, ProStatus, ProductBuild, UasAddress, UasKind,
    EXOTIC_QUANT_CRASH_SAFE_COMMAND_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-ExoticQuantCrashSafeCommandEnvelopePreflightGate";
const FIXTURE_ID: &str = "exotic_quant_crash_safe_command_envelope_preflight_gate_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_exotic_quant_crash_safe_command_envelope_preflight_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/exotic_quant_crash_safe_command_envelope_preflight_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/exotic_quant_owner_path_byte_envelope_preflight_gate/result.json";
const UPSTREAM_REF: &str =
    "artifact:falsifiers/exotic_quant_owner_path_byte_envelope_preflight_gate/result.json#F-ExoticQuantOwnerPathByteEnvelopePreflightGate";
const CREATED_AT_MS: u64 = 1_779_551_000_000;
const LEDGER_METADATA_BYTES: u64 = 360_000;

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
        "{FALSIFIER_ID}: overall_pass={} gate_card_count={} mac_candidate_unarmed_count={} server_only_denied_count={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["gate_card_count"].value,
        artifact.measurements["mac_candidate_unarmed_count"].value,
        artifact.measurements["server_only_denied_count"].value,
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
    let (upstream_pass, upstream_address) = upstream_byte_envelope_gate()?;
    let cards = canonical_crash_safe_command_envelope_cards(UPSTREAM_REF);
    let ledger = build_ledger(upstream_address.clone(), cards.clone())?;
    let reversed = build_ledger(upstream_address, cards.iter().cloned().rev().collect())?;
    let metrics = ledger.metrics();
    let red_results = red_fixture_results(&cards);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;
    let red_fixture_count = red_results.len() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_byte_envelope_preflight_gate_pass", upstream_pass),
        (
            "accepted_crash_safe_command_envelope_pack_present",
            has_gate(
                &cards,
                "qwopus27b_tq3_4s_crash_safe_command_envelope_preflight",
            ) && has_gate(
                &cards,
                "qwopus27b_hlwq_q5_crash_safe_command_envelope_preflight",
            ) && has_gate(
                &cards,
                "qwopus_moe_35b_a3b_apex_mini_crash_safe_command_envelope_preflight",
            ) && has_gate(
                &cards,
                "gemma4_31b_nvfp4_crash_safe_command_envelope_preflight",
            ) && has_gate(
                &cards,
                "gemma4_31b_int4_autoround_crash_safe_command_envelope_preflight",
            ),
        ),
        (
            "source_pin_model_revision_selected_file_bound",
            cards.iter().all(|card| {
                card.proof_refs
                    .source_pin_card_ref
                    .ends_with(&card.source_pin_card_id)
                    && card
                        .proof_refs
                        .model_revision_ref
                        .ends_with(&card.source_pin_card_id)
                    && card
                        .proof_refs
                        .selected_file_ref
                        .ends_with(&card.source_pin_card_id)
            }) && red_pass(&red_results, "bad_source_pin_card")
                && red_pass(&red_results, "bad_model_revision_ref")
                && red_pass(&red_results, "bad_selected_file_ref"),
        ),
        (
            "runtime_surface_classification_bound",
            metrics.llama_cpp_gguf_cli_count == 2
                && metrics.transformers_quarantine_count == 1
                && metrics.server_only_denied_count == 2
                && red_pass(&red_results, "bad_runtime_surface"),
        ),
        (
            "mac_candidate_commands_unarmed",
            metrics.mac_candidate_unarmed_count == 3
                && cards
                    .iter()
                    .filter(|card| {
                        card.state
                            == CrashSafeCommandEnvelopeState::MacCandidateUnarmedOwnerApprovalRequired
                    })
                    .all(|card| !card.command_armed && !card.command_executable),
        ),
        (
            "server_only_commands_denied",
            metrics.server_only_denied_count == 2
                && cards
                    .iter()
                    .filter(|card| card.surface == CrashSafeCommandSurface::ServerOnlyDenied)
                    .all(|card| card.argv_template.is_empty() && !card.command_executable),
        ),
        (
            "args_vectorized_shell_denied",
            metrics.args_vectorized_count == 5
                && metrics.shell_string_denied_count == 5
                && red_pass(&red_results, "shell_string_present")
                && red_pass(&red_results, "forbidden_arg_present"),
        ),
        (
            "remote_download_flags_denied",
            metrics.remote_download_denied_count == 5
                && red_pass(&red_results, "remote_download_allowed"),
        ),
        (
            "hf_token_env_denied",
            metrics.hf_token_env_denied_count == 5
                && red_pass(&red_results, "hf_token_env_allowed"),
        ),
        (
            "network_and_server_sidecar_denied",
            cards.iter().all(|card| !card.network_allowed && !card.server_sidecar_allowed)
                && red_pass(&red_results, "network_allowed")
                && red_pass(&red_results, "server_sidecar_allowed"),
        ),
        (
            "one_token_context_batch_caps_bound",
            cards.iter().all(|card| {
                card.policy.one_token_budget_bound && card.policy.context_batch_budget_bound
            }) && red_pass(&red_results, "missing_llama_offline_flag"),
        ),
        (
            "kv_cache_and_cache_ram_policy_bound",
            cards
                .iter()
                .all(|card| card.policy.kv_cache_policy_bound && card.policy.cache_ram_policy_bound),
        ),
        (
            "mmap_mlock_fit_claims_denied",
            cards.iter().all(|card| !card.mmap_fit_claim && !card.mlock_fit_claim)
                && red_pass(&red_results, "mmap_fit_claim")
                && red_pass(&red_results, "mlock_fit_claim"),
        ),
        (
            "output_timeout_cancellation_teardown_bound",
            metrics.output_limit_bound_count == 5
                && metrics.timeout_bound_count == 5
                && metrics.cancellation_bound_count == 5
                && metrics.teardown_bound_count == 5
                && red_pass(&red_results, "output_unbounded")
                && red_pass(&red_results, "timeout_missing")
                && red_pass(&red_results, "cancellation_missing")
                && red_pass(&red_results, "teardown_missing"),
        ),
        (
            "dry_run_only_owner_approval_required",
            cards.iter().all(|card| card.policy.dry_run_only)
                && metrics.mac_candidate_unarmed_count == 3
                && red_pass(&red_results, "owner_approval_leaked")
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executable"),
        ),
        (
            "rollback_run_event_answer_packet_abstention_required",
            metrics.rollback_run_event_answer_packet_count == 5
                && cards.iter().all(|card| card.abstention_required)
                && red_pass(&red_results, "missing_rollback")
                && red_pass(&red_results, "missing_run_event_log")
                && red_pass(&red_results, "missing_answer_packet")
                && red_pass(&red_results, "missing_abstention"),
        ),
        (
            "issue_failure_refs_red_only",
            metrics.issue_failure_ref_count >= 20 && red_pass(&red_results, "bad_issue_ref"),
        ),
        (
            "mas_product_route_denied",
            cards.iter().all(|card| {
                !card.mas_allowed
                    && !card.product_route_enabled
                    && !card.app_default_claim
                    && !card.product_winner_claim
            }) && red_pass(&red_results, "mas_allowed")
                && red_pass(&red_results, "product_route_enabled")
                && red_pass(&red_results, "app_default_claim")
                && red_pass(&red_results, "product_winner_claim"),
        ),
        (
            "no_hidden_authority",
            cards.iter().all(|card| {
                !card.route_policy_mutated
                    && !card.hidden_route_authority
                    && !card.hidden_cloud_fallback
                    && !card.patternboost_live_authority
                    && !card.lattice_live_authority
                    && !card.eidos_live_authority
            }) && red_pass(&red_results, "route_policy_mutated")
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "hidden_cloud_fallback")
                && red_pass(&red_results, "patternboost_authority")
                && red_pass(&red_results, "lattice_authority")
                && red_pass(&red_results, "eidos_authority"),
        ),
        (
            "no_l2_l3_live70b_ssd",
            cards.iter().all(|card| {
                !card.l2_l3_promotion_claim && !card.live_dense_70b_claim && !card.ssd_as_ram_claim
            }) && red_pass(&red_results, "l2_l3_promotion")
                && red_pass(&red_results, "live_dense_70b")
                && red_pass(&red_results, "ssd_as_ram"),
        ),
        (
            "no_source_import_or_benchmark_fit",
            cards
                .iter()
                .all(|card| !card.source_import_allowed && !card.benchmark_as_fit_proof)
                && red_pass(&red_results, "source_import_allowed")
                && red_pass(&red_results, "benchmark_as_fit_proof"),
        ),
        (
            "zero_live_bytes_and_commands",
            metrics.command_execution_count_total == 0
                && metrics.stdout_bytes_captured_total == 0
                && metrics.stderr_bytes_captured_total == 0
                && metrics.token_bytes_captured_total == 0
                && metrics.model_bytes_loaded_total == 0
                && metrics.runtime_bytes_loaded_total == 0
                && metrics.provider_calls_made_total == 0
                && metrics.network_calls_made_total == 0
                && metrics.source_tree_bytes_read_total == 0
                && metrics.product_bytes_copied_total == 0
                && metrics.benchmark_runs_total == 0,
        ),
        (
            "deterministic_address",
            ledger.ledger_address == reversed.ledger_address,
        ),
        (
            "next_cursor_bound",
            ledger.next_cursor == EXOTIC_QUANT_CRASH_SAFE_COMMAND_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR,
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
        ("gate_card_count", metrics.gate_card_count, 5, "cards"),
        (
            "mac_candidate_unarmed_count",
            metrics.mac_candidate_unarmed_count,
            3,
            "cards",
        ),
        (
            "server_only_denied_count",
            metrics.server_only_denied_count,
            2,
            "cards",
        ),
        (
            "llama_cpp_gguf_cli_count",
            metrics.llama_cpp_gguf_cli_count,
            2,
            "cards",
        ),
        (
            "transformers_quarantine_count",
            metrics.transformers_quarantine_count,
            1,
            "cards",
        ),
        (
            "args_vectorized_count",
            metrics.args_vectorized_count,
            5,
            "cards",
        ),
        (
            "shell_string_denied_count",
            metrics.shell_string_denied_count,
            5,
            "cards",
        ),
        (
            "remote_download_denied_count",
            metrics.remote_download_denied_count,
            5,
            "cards",
        ),
        (
            "hf_token_env_denied_count",
            metrics.hf_token_env_denied_count,
            5,
            "cards",
        ),
        (
            "output_limit_bound_count",
            metrics.output_limit_bound_count,
            5,
            "cards",
        ),
        (
            "timeout_bound_count",
            metrics.timeout_bound_count,
            5,
            "cards",
        ),
        (
            "cancellation_bound_count",
            metrics.cancellation_bound_count,
            5,
            "cards",
        ),
        (
            "teardown_bound_count",
            metrics.teardown_bound_count,
            5,
            "cards",
        ),
        (
            "rollback_run_event_answer_packet_count",
            metrics.rollback_run_event_answer_packet_count,
            5,
            "cards",
        ),
        (
            "forbidden_arg_count",
            metrics.forbidden_arg_count,
            metrics.forbidden_arg_count,
            "args",
        ),
        (
            "forbidden_env_count",
            metrics.forbidden_env_count,
            metrics.forbidden_env_count,
            "env",
        ),
        (
            "issue_failure_ref_count",
            metrics.issue_failure_ref_count,
            metrics.issue_failure_ref_count,
            "refs",
        ),
        (
            "command_template_bytes_serialized_total",
            metrics.command_template_bytes_serialized_total,
            metrics.command_template_bytes_serialized_total,
            "bytes",
        ),
        (
            "command_execution_count_total",
            metrics.command_execution_count_total,
            0,
            "commands",
        ),
        (
            "stdout_bytes_captured_total",
            metrics.stdout_bytes_captured_total,
            0,
            "bytes",
        ),
        (
            "stderr_bytes_captured_total",
            metrics.stderr_bytes_captured_total,
            0,
            "bytes",
        ),
        (
            "token_bytes_captured_total",
            metrics.token_bytes_captured_total,
            0,
            "bytes",
        ),
        (
            "model_bytes_loaded_total",
            metrics.model_bytes_loaded_total,
            0,
            "bytes",
        ),
        (
            "runtime_bytes_loaded_total",
            metrics.runtime_bytes_loaded_total,
            0,
            "bytes",
        ),
        (
            "provider_calls_made_total",
            metrics.provider_calls_made_total,
            0,
            "calls",
        ),
        (
            "network_calls_made_total",
            metrics.network_calls_made_total,
            0,
            "calls",
        ),
        (
            "source_tree_bytes_read_total",
            metrics.source_tree_bytes_read_total,
            0,
            "bytes",
        ),
        (
            "product_bytes_copied_total",
            metrics.product_bytes_copied_total,
            0,
            "bytes",
        ),
        (
            "benchmark_runs_total",
            metrics.benchmark_runs_total,
            0,
            "runs",
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
        "crash_safe_command_envelope_preflight_gate_address".to_string(),
        Measurement {
            value: serde_json::json!(ledger.ledger_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "crash_safe_command_envelope_preflight_gate_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "crash_safe_command_envelope_preflight_gate_address".to_string(),
        !ledger.ledger_address.to_string().is_empty(),
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
                EXOTIC_QUANT_CRASH_SAFE_COMMAND_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        ledger.next_cursor == EXOTIC_QUANT_CRASH_SAFE_COMMAND_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR,
    );

    for axis in EXOTIC_QUANT_CRASH_SAFE_COMMAND_ENVELOPE_PREFLIGHT_GATE_AXES {
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
        notes: "metadata-only F-ExoticQuantCrashSafeCommandEnvelopePreflightGate: serializes inert command/API envelopes for five exotic quant rows after byte-envelope denial, keeps all commands unarmed and dry-run-only, denies remote downloads, provider tokens, server sidecars, mmap/mlock fit claims, unbounded output, and missing timeout/cancellation/teardown, requires rollback, RunEventLog, AnswerPacket, abstention, and owner-approved dry-run proof before runtime. It loads zero model/runtime/provider bytes and makes no MAS/L2/L3/user-facing promotion.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_byte_envelope_gate() -> Result<(bool, UasAddress), Box<dyn std::error::Error>> {
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
            .map(|id| id == "F-ExoticQuantOwnerPathByteEnvelopePreflightGate")
            .unwrap_or(false);
    let address = json
        .pointer("/measurements/owner_path_byte_envelope_preflight_gate_address/value")
        .and_then(serde_json::Value::as_str)
        .and_then(|value| UasAddress::from_str(value).ok())
        .unwrap_or_else(|| fallback_upstream_address());
    Ok((pass, address))
}

fn fallback_upstream_address() -> UasAddress {
    UasAddress::new(
        UasKind::Other("exotic_quant_owner_path_byte_envelope_preflight_gate".to_string()),
        b"fallback-owner-path-byte-envelope-preflight-gate-address",
        CREATED_AT_MS,
    )
}

fn build_ledger(
    upstream_address: UasAddress,
    cards: Vec<CrashSafeCommandEnvelopeCard>,
) -> Result<CrashSafeCommandEnvelopeLedger, agent_core::uas::CrashSafeCommandEnvelopeError> {
    CrashSafeCommandEnvelopeLedger::new(
        upstream_address,
        UPSTREAM_REF,
        cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        CompressedModelPromotionTier::T1L1Metadata,
        LEDGER_METADATA_BYTES,
        true,
        true,
        true,
        true,
        true,
        true,
        EXOTIC_QUANT_CRASH_SAFE_COMMAND_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR,
        CREATED_AT_MS,
    )
}

fn has_gate(cards: &[CrashSafeCommandEnvelopeCard], gate_id: &str) -> bool {
    cards.iter().any(|card| card.gate_id == gate_id)
}

fn red_pass(results: &[(&'static str, bool)], id: &str) -> bool {
    results
        .iter()
        .find(|(fixture_id, _)| *fixture_id == id)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn red_fixture_results(cards: &[CrashSafeCommandEnvelopeCard]) -> Vec<(&'static str, bool)> {
    let mut results = Vec::new();
    results.push((
        "duplicate_gate_id",
        reject_cards(cards, |bad| bad[1].gate_id = bad[0].gate_id.clone()),
    ));
    results.push((
        "duplicate_model_id",
        reject_cards(cards, |bad| bad[1].model_id = bad[0].model_id.clone()),
    ));
    results.push((
        "duplicate_source_pin_card_id",
        reject_cards(cards, |bad| {
            bad[1].source_pin_card_id = bad[0].source_pin_card_id.clone()
        }),
    ));
    results.push((
        "missing_expected_model",
        reject_cards(cards, |bad| {
            bad.remove(0);
        }),
    ));
    results.push((
        "bad_source_pin_card",
        reject_first(cards, |card| {
            card.source_pin_card_id = "wrong_source_pin".to_string()
        }),
    ));
    results.push((
        "bad_model_revision_ref",
        reject_first(cards, |card| {
            card.proof_refs.model_revision_ref = "model_revision:wrong".to_string()
        }),
    ));
    results.push((
        "bad_selected_file_ref",
        reject_first(cards, |card| {
            card.proof_refs.selected_file_ref = "selected_file:wrong".to_string()
        }),
    ));
    results.push((
        "bad_byte_envelope_ref",
        reject_first(cards, |card| {
            card.proof_refs.byte_envelope_ref = "byte_envelope:wrong".to_string()
        }),
    ));
    results.push((
        "bad_command_envelope_ref",
        reject_first(cards, |card| {
            card.proof_refs.command_envelope_ref = "command_envelope:wrong".to_string()
        }),
    ));
    results.push((
        "bad_download_policy_ref",
        reject_first(cards, |card| {
            card.proof_refs.download_policy_ref = "download_policy:wrong".to_string()
        }),
    ));
    results.push((
        "bad_env_policy_ref",
        reject_first(cards, |card| {
            card.proof_refs.env_policy_ref = "env_policy:wrong".to_string()
        }),
    ));
    results.push((
        "bad_output_policy_ref",
        reject_first(cards, |card| {
            card.proof_refs.output_policy_ref = "output_policy:wrong".to_string()
        }),
    ));
    results.push((
        "bad_timeout_policy_ref",
        reject_first(cards, |card| {
            card.proof_refs.timeout_policy_ref = "timeout_policy:wrong".to_string()
        }),
    ));
    results.push((
        "bad_cancellation_ref",
        reject_first(cards, |card| {
            card.proof_refs.cancellation_ref = "cancellation:wrong".to_string()
        }),
    ));
    results.push((
        "bad_teardown_ref",
        reject_first(cards, |card| {
            card.proof_refs.teardown_ref = "teardown:wrong".to_string()
        }),
    ));
    results.push((
        "bad_compatibility_fence_ref",
        reject_first(cards, |card| {
            card.proof_refs.compatibility_fence_ref = "compat:wrong".to_string()
        }),
    ));
    results.push((
        "bad_issue_ref",
        reject_first(cards, |card| {
            card.issue_failure_refs = vec!["not-a-source".to_string()]
        }),
    ));
    results.push((
        "bad_runtime_surface",
        reject_first(cards, |card| {
            card.surface = CrashSafeCommandSurface::ServerOnlyDenied
        }),
    ));
    results.push((
        "missing_owner_approved_model_path",
        reject_first(cards, |card| {
            card.argv_template
                .retain(|arg| arg != "<OWNER_APPROVED_MODEL_PATH>")
        }),
    ));
    results.push((
        "missing_llama_offline_flag",
        reject_llama(cards, |card| {
            card.argv_template.retain(|arg| arg != "--offline")
        }),
    ));
    results.push((
        "forbidden_arg_present",
        reject_first(cards, |card| {
            card.argv_template.push("--hf-repo".to_string())
        }),
    ));
    results.push((
        "missing_forbidden_arg",
        reject_first(cards, |card| {
            card.forbidden_args.retain(|arg| arg != "--hf-repo")
        }),
    ));
    results.push((
        "missing_forbidden_env",
        reject_first(cards, |card| {
            card.forbidden_env.retain(|env| env != "HF_TOKEN")
        }),
    ));
    results.push((
        "shell_string_present",
        reject_first(cards, |card| card.shell_string_present = true),
    ));
    results.push((
        "remote_download_allowed",
        reject_first(cards, |card| card.remote_download_allowed = true),
    ));
    results.push((
        "hf_token_env_allowed",
        reject_first(cards, |card| card.hf_token_env_allowed = true),
    ));
    results.push((
        "network_allowed",
        reject_first(cards, |card| card.network_allowed = true),
    ));
    results.push((
        "server_sidecar_allowed",
        reject_first(cards, |card| card.server_sidecar_allowed = true),
    ));
    results.push((
        "mmap_fit_claim",
        reject_first(cards, |card| card.mmap_fit_claim = true),
    ));
    results.push((
        "mlock_fit_claim",
        reject_first(cards, |card| card.mlock_fit_claim = true),
    ));
    results.push((
        "output_unbounded",
        reject_first(cards, |card| card.output_unbounded = true),
    ));
    results.push((
        "timeout_missing",
        reject_first(cards, |card| card.timeout_missing = true),
    ));
    results.push((
        "cancellation_missing",
        reject_first(cards, |card| card.cancellation_missing = true),
    ));
    results.push((
        "teardown_missing",
        reject_first(cards, |card| card.teardown_missing = true),
    ));
    results.push((
        "owner_approval_leaked",
        reject_first(cards, |card| card.owner_approval_present = true),
    ));
    results.push((
        "command_armed",
        reject_first(cards, |card| card.command_armed = true),
    ));
    results.push((
        "command_executable",
        reject_first(cards, |card| card.command_executable = true),
    ));
    results.push((
        "command_executed",
        reject_first(cards, |card| card.byte_ledger.command_execution_count = 1),
    ));
    results.push((
        "runtime_probe_allowed",
        reject_first(cards, |card| card.runtime_probe_allowed = true),
    ));
    results.push((
        "runtime_not_deferred",
        reject_first(cards, |card| card.runtime_deferred = false),
    ));
    results.push((
        "local_artifact_verified",
        reject_first(cards, |card| card.local_artifact_verified = true),
    ));
    results.push((
        "stdout_bytes_captured",
        reject_first(cards, |card| card.byte_ledger.stdout_bytes_captured = 1),
    ));
    results.push((
        "stderr_bytes_captured",
        reject_first(cards, |card| card.byte_ledger.stderr_bytes_captured = 1),
    ));
    results.push((
        "token_bytes_captured",
        reject_first(cards, |card| card.byte_ledger.token_bytes_captured = 1),
    ));
    results.push((
        "model_bytes_loaded",
        reject_first(cards, |card| card.byte_ledger.model_bytes_loaded = 1),
    ));
    results.push((
        "runtime_bytes_loaded",
        reject_first(cards, |card| card.byte_ledger.runtime_bytes_loaded = 1),
    ));
    results.push((
        "provider_call_made",
        reject_first(cards, |card| card.byte_ledger.provider_calls_made = 1),
    ));
    results.push((
        "network_call_made",
        reject_first(cards, |card| card.byte_ledger.network_calls_made = 1),
    ));
    results.push((
        "source_tree_bytes_read",
        reject_first(cards, |card| card.byte_ledger.source_tree_bytes_read = 1),
    ));
    results.push((
        "product_bytes_copied",
        reject_first(cards, |card| card.byte_ledger.product_bytes_copied = 1),
    ));
    results.push((
        "benchmark_run",
        reject_first(cards, |card| card.byte_ledger.benchmark_runs = 1),
    ));
    results.push((
        "missing_rollback",
        reject_first(cards, |card| card.rollback_required = false),
    ));
    results.push((
        "missing_run_event_log",
        reject_first(cards, |card| card.run_event_log_required = false),
    ));
    results.push((
        "missing_answer_packet",
        reject_first(cards, |card| card.answer_packet_required = false),
    ));
    results.push((
        "missing_abstention",
        reject_first(cards, |card| card.abstention_required = false),
    ));
    results.push((
        "mas_allowed",
        reject_first(cards, |card| card.mas_allowed = true),
    ));
    results.push((
        "product_route_enabled",
        reject_first(cards, |card| card.product_route_enabled = true),
    ));
    results.push((
        "app_default_claim",
        reject_first(cards, |card| card.app_default_claim = true),
    ));
    results.push((
        "product_winner_claim",
        reject_first(cards, |card| card.product_winner_claim = true),
    ));
    results.push((
        "route_policy_mutated",
        reject_first(cards, |card| card.route_policy_mutated = true),
    ));
    results.push((
        "hidden_route_authority",
        reject_first(cards, |card| card.hidden_route_authority = true),
    ));
    results.push((
        "hidden_cloud_fallback",
        reject_first(cards, |card| card.hidden_cloud_fallback = true),
    ));
    results.push((
        "patternboost_authority",
        reject_first(cards, |card| card.patternboost_live_authority = true),
    ));
    results.push((
        "lattice_authority",
        reject_first(cards, |card| card.lattice_live_authority = true),
    ));
    results.push((
        "eidos_authority",
        reject_first(cards, |card| card.eidos_live_authority = true),
    ));
    results.push((
        "l2_l3_promotion",
        reject_first(cards, |card| card.l2_l3_promotion_claim = true),
    ));
    results.push((
        "live_dense_70b",
        reject_first(cards, |card| card.live_dense_70b_claim = true),
    ));
    results.push((
        "ssd_as_ram",
        reject_first(cards, |card| card.ssd_as_ram_claim = true),
    ));
    results.push((
        "source_import_allowed",
        reject_first(cards, |card| card.source_import_allowed = true),
    ));
    results.push((
        "benchmark_as_fit_proof",
        reject_first(cards, |card| card.benchmark_as_fit_proof = true),
    ));
    results.push((
        "metadata_budget_exceeded",
        build_ledger(fallback_upstream_address(), cards.to_vec())
            .and_then(|ledger| {
                CrashSafeCommandEnvelopeLedger::new(
                    ledger.upstream_byte_envelope_gate_address,
                    UPSTREAM_REF,
                    ledger.cards,
                    ProductBuild::Pro,
                    ProStatus::ResearchCandidate,
                    CompressedModelPromotionTier::T1L1Metadata,
                    999_999_999,
                    true,
                    true,
                    true,
                    true,
                    true,
                    true,
                    EXOTIC_QUANT_CRASH_SAFE_COMMAND_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR,
                    CREATED_AT_MS,
                )
            })
            .is_err(),
    ));
    results
}

fn reject_first<F>(cards: &[CrashSafeCommandEnvelopeCard], mutate: F) -> bool
where
    F: FnOnce(&mut CrashSafeCommandEnvelopeCard),
{
    reject_cards(cards, |bad| mutate(&mut bad[0]))
}

fn reject_llama<F>(cards: &[CrashSafeCommandEnvelopeCard], mutate: F) -> bool
where
    F: FnOnce(&mut CrashSafeCommandEnvelopeCard),
{
    reject_cards(cards, |bad| {
        if let Some(card) = bad
            .iter_mut()
            .find(|card| card.surface == CrashSafeCommandSurface::LlamaCppGgufCli)
        {
            mutate(card);
        }
    })
}

fn reject_cards<F>(cards: &[CrashSafeCommandEnvelopeCard], mutate: F) -> bool
where
    F: FnOnce(&mut Vec<CrashSafeCommandEnvelopeCard>),
{
    let mut bad = cards.to_vec();
    mutate(&mut bad);
    build_ledger(fallback_upstream_address(), bad).is_err()
}
