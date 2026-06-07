//! `falsify_exotic_quant_owner_path_byte_envelope_preflight_gate`
//!
//! Metadata-only witness for `F-ExoticQuantOwnerPathByteEnvelopePreflightGate`.
//! It recomputes declared byte envelopes after owner path canonicalization and
//! before any file access, command envelope, runtime probe, or product-route
//! promotion can begin.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::axes::EXOTIC_QUANT_OWNER_PATH_BYTE_ENVELOPE_PREFLIGHT_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_owner_path_byte_envelope_preflight_cards, CompressedModelPromotionTier,
    OwnerPathByteEnvelopePreflightCard, OwnerPathByteEnvelopePreflightLedger, ProStatus,
    ProductBuild, UasAddress, UasKind,
    EXOTIC_QUANT_OWNER_PATH_BYTE_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-ExoticQuantOwnerPathByteEnvelopePreflightGate";
const FIXTURE_ID: &str = "exotic_quant_owner_path_byte_envelope_preflight_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_exotic_quant_owner_path_byte_envelope_preflight_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/exotic_quant_owner_path_byte_envelope_preflight_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/exotic_quant_owner_path_canonicalization_preflight_gate/result.json";
const UPSTREAM_REF: &str =
    "artifact:falsifiers/exotic_quant_owner_path_canonicalization_preflight_gate/result.json#F-ExoticQuantOwnerPathCanonicalizationPreflightGate";
const CREATED_AT_MS: u64 = 1_779_550_000_000;
const LEDGER_METADATA_BYTES: u64 = 288_000;
const M2_PRO_16GB_UMA_BYTES: u64 = 17_179_869_184;

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
        "{FALSIFIER_ID}: overall_pass={} gate_card_count={} mac_current_hardware_denied_count={} selected_artifact_bytes_sum={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["gate_card_count"].value,
        artifact.measurements["mac_current_hardware_denied_count"].value,
        artifact.measurements["selected_artifact_bytes_sum"].value,
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
    let (upstream_pass, upstream_address) = upstream_canonicalization_gate()?;
    let cards = canonical_owner_path_byte_envelope_preflight_cards(UPSTREAM_REF);
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
        (
            "upstream_canonicalization_preflight_gate_pass",
            upstream_pass,
        ),
        (
            "accepted_byte_envelope_preflight_pack_present",
            has_gate(
                &cards,
                "qwopus27b_tq3_4s_owner_path_byte_envelope_preflight",
            ) && has_gate(
                &cards,
                "qwopus27b_hlwq_q5_owner_path_byte_envelope_preflight",
            ) && has_gate(
                &cards,
                "qwopus_moe_35b_a3b_apex_mini_owner_path_byte_envelope_preflight",
            ) && has_gate(
                &cards,
                "gemma4_31b_nvfp4_owner_path_byte_envelope_preflight",
            ) && has_gate(
                &cards,
                "gemma4_31b_int4_autoround_owner_path_byte_envelope_preflight",
            ),
        ),
        (
            "source_pin_and_byte_budget_bound",
            cards.iter().all(|card| {
                card.proof_refs
                    .source_pin_card_ref
                    .ends_with(&card.source_pin_card_id)
                    && card
                        .proof_refs
                        .byte_budget_ref
                        .ends_with(&card.source_pin_card_id)
            }) && red_pass(&red_results, "bad_source_pin_card")
                && red_pass(&red_results, "bad_byte_budget_ref"),
        ),
        (
            "selected_byte_envelope_recomputed",
            metrics.minimum_uma_recomputed_count == 5
                && metrics.selected_artifact_bytes_sum == 96_318_502_063
                && metrics.minimum_uma_bytes_required_max == 39_108_307_031
                && red_pass(&red_results, "bad_byte_envelope_ref")
                && red_pass(&red_results, "bad_byte_envelope"),
        ),
        (
            "current_m2pro_16gb_denied",
            metrics.mac_current_hardware_denied_count == 5
                && metrics.current_m2pro_16gb_bytes == M2_PRO_16GB_UMA_BYTES
                && red_pass(&red_results, "current_hardware_bypass"),
        ),
        (
            "mac_24_to_32gb_requirement_visible",
            metrics.mac_24_to_32gb_required_count == 3
                && red_pass(&red_results, "mac_24_to_32gb_requirement_bypass"),
        ),
        (
            "server_only_byte_envelope_denied",
            metrics.server_only_denied_count == 2 && red_pass(&red_results, "server_row_allowed"),
        ),
        (
            "selected_bytes_not_resident",
            metrics.selected_bytes_resident_claim_count == 0
                && metrics.local_artifact_verified_count == 0
                && red_pass(&red_results, "selected_bytes_resident_claim")
                && red_pass(&red_results, "local_artifact_verified"),
        ),
        (
            "owner_path_absent_zero_bytes",
            metrics.owner_manifest_present_count == 0
                && metrics.owner_supplied_path_present_count == 0
                && metrics.owner_manifest_bytes_read_total == 0
                && metrics.owner_path_bytes_read_total == 0
                && red_pass(&red_results, "owner_manifest_present")
                && red_pass(&red_results, "owner_supplied_path_present")
                && red_pass(&red_results, "owner_manifest_bytes_read")
                && red_pass(&red_results, "owner_path_bytes_read"),
        ),
        (
            "file_access_disallowed",
            metrics.local_path_open_allowed_count == 0
                && metrics.file_hash_allowed_count == 0
                && metrics.local_file_bytes_read_total == 0
                && metrics.local_path_open_attempts_total == 0
                && metrics.file_stat_calls_total == 0
                && metrics.byte_hash_attempts_total == 0
                && metrics.symlink_resolution_attempts_total == 0
                && red_pass(&red_results, "file_open_allowed")
                && red_pass(&red_results, "file_stat_allowed")
                && red_pass(&red_results, "file_hash_allowed")
                && red_pass(&red_results, "symlink_follow_allowed")
                && red_pass(&red_results, "local_file_bytes_read")
                && red_pass(&red_results, "path_open_attempt")
                && red_pass(&red_results, "file_stat_call")
                && red_pass(&red_results, "byte_hash_attempt")
                && red_pass(&red_results, "symlink_resolution_attempt"),
        ),
        (
            "commands_unarmed",
            metrics.command_envelope_unarmed_count == 5
                && metrics.command_execution_count_total == 0
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed"),
        ),
        (
            "runtime_deferred",
            cards
                .iter()
                .all(|card| !card.runtime_probe_allowed && card.runtime_deferred)
                && red_pass(&red_results, "runtime_probe_allowed")
                && red_pass(&red_results, "runtime_not_deferred"),
        ),
        (
            "rollback_run_event_answer_packet_abstention_required",
            cards.iter().all(|card| {
                card.rollback_required
                    && card.run_event_log_required
                    && card.answer_packet_required
                    && card.abstention_required
            }) && red_pass(&red_results, "missing_rollback")
                && red_pass(&red_results, "missing_run_event_log")
                && red_pass(&red_results, "missing_answer_packet")
                && red_pass(&red_results, "missing_abstention"),
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
            "zero_bytes_and_commands",
            metrics.owner_manifest_bytes_read_total == 0
                && metrics.owner_path_bytes_read_total == 0
                && metrics.local_file_bytes_read_total == 0
                && metrics.byte_hash_attempts_total == 0
                && metrics.local_path_open_attempts_total == 0
                && metrics.file_stat_calls_total == 0
                && metrics.symlink_resolution_attempts_total == 0
                && metrics.command_execution_count_total == 0
                && metrics.model_bytes_loaded_total == 0
                && metrics.runtime_bytes_loaded_total == 0
                && metrics.provider_calls_made_total == 0
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
            ledger.next_cursor == EXOTIC_QUANT_OWNER_PATH_BYTE_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR,
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
            "mac_current_hardware_denied_count",
            metrics.mac_current_hardware_denied_count,
            5,
            "cards",
        ),
        (
            "mac_24_to_32gb_required_count",
            metrics.mac_24_to_32gb_required_count,
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
            "byte_envelope_preflight_compiled_count",
            metrics.byte_envelope_preflight_compiled_count,
            3,
            "cards",
        ),
        (
            "minimum_uma_recomputed_count",
            metrics.minimum_uma_recomputed_count,
            5,
            "cards",
        ),
        (
            "selected_artifact_bytes_sum",
            metrics.selected_artifact_bytes_sum,
            96_318_502_063,
            "bytes",
        ),
        (
            "selected_support_bytes_sum",
            metrics.selected_support_bytes_sum,
            metrics.selected_support_bytes_sum,
            "bytes",
        ),
        (
            "runtime_workspace_budget_bytes_sum",
            metrics.runtime_workspace_budget_bytes_sum,
            metrics.runtime_workspace_budget_bytes_sum,
            "bytes",
        ),
        (
            "kv_cache_floor_bytes_sum",
            metrics.kv_cache_floor_bytes_sum,
            metrics.kv_cache_floor_bytes_sum,
            "bytes",
        ),
        (
            "app_headroom_bytes_sum",
            metrics.app_headroom_bytes_sum,
            metrics.app_headroom_bytes_sum,
            "bytes",
        ),
        (
            "minimum_uma_bytes_required_max",
            metrics.minimum_uma_bytes_required_max,
            39_108_307_031,
            "bytes",
        ),
        (
            "current_m2pro_16gb_bytes",
            metrics.current_m2pro_16gb_bytes,
            M2_PRO_16GB_UMA_BYTES,
            "bytes",
        ),
        (
            "owner_manifest_present_count",
            metrics.owner_manifest_present_count,
            0,
            "cards",
        ),
        (
            "owner_supplied_path_present_count",
            metrics.owner_supplied_path_present_count,
            0,
            "cards",
        ),
        (
            "local_artifact_verified_count",
            metrics.local_artifact_verified_count,
            0,
            "cards",
        ),
        (
            "selected_bytes_resident_claim_count",
            metrics.selected_bytes_resident_claim_count,
            0,
            "cards",
        ),
        (
            "local_path_open_allowed_count",
            metrics.local_path_open_allowed_count,
            0,
            "cards",
        ),
        (
            "file_hash_allowed_count",
            metrics.file_hash_allowed_count,
            0,
            "cards",
        ),
        (
            "command_envelope_unarmed_count",
            metrics.command_envelope_unarmed_count,
            5,
            "cards",
        ),
        (
            "owner_manifest_bytes_read_total",
            metrics.owner_manifest_bytes_read_total,
            0,
            "bytes",
        ),
        (
            "owner_path_bytes_read_total",
            metrics.owner_path_bytes_read_total,
            0,
            "bytes",
        ),
        (
            "local_file_bytes_read_total",
            metrics.local_file_bytes_read_total,
            0,
            "bytes",
        ),
        (
            "byte_hash_attempts_total",
            metrics.byte_hash_attempts_total,
            0,
            "attempts",
        ),
        (
            "local_path_open_attempts_total",
            metrics.local_path_open_attempts_total,
            0,
            "attempts",
        ),
        (
            "file_stat_calls_total",
            metrics.file_stat_calls_total,
            0,
            "calls",
        ),
        (
            "symlink_resolution_attempts_total",
            metrics.symlink_resolution_attempts_total,
            0,
            "attempts",
        ),
        (
            "command_execution_count_total",
            metrics.command_execution_count_total,
            0,
            "commands",
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
        "owner_path_byte_envelope_preflight_gate_address".to_string(),
        Measurement {
            value: serde_json::json!(ledger.ledger_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "owner_path_byte_envelope_preflight_gate_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "owner_path_byte_envelope_preflight_gate_address".to_string(),
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
                EXOTIC_QUANT_OWNER_PATH_BYTE_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        ledger.next_cursor == EXOTIC_QUANT_OWNER_PATH_BYTE_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR,
    );

    for axis in EXOTIC_QUANT_OWNER_PATH_BYTE_ENVELOPE_PREFLIGHT_GATE_AXES {
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
        notes: "metadata-only F-ExoticQuantOwnerPathByteEnvelopePreflightGate: recomputes byte envelopes for five exotic quant rows after canonicalization, denies current M2 Pro 16 GB hardware admission, keeps selected bytes non-resident, opens zero owner paths or files, arms zero commands, loads zero model/runtime/provider/source/product bytes, and makes no MAS/L2/L3/user-facing promotion. It does not prove owner approval, local artifact availability, command safety, loader execution, first token, quality, or Apple Silicon fit.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_canonicalization_gate() -> Result<(bool, UasAddress), Box<dyn std::error::Error>> {
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
            .map(|id| id == "F-ExoticQuantOwnerPathCanonicalizationPreflightGate")
            .unwrap_or(false);
    let address = json
        .pointer("/measurements/owner_path_canonicalization_preflight_gate_address/value")
        .and_then(serde_json::Value::as_str)
        .and_then(|value| UasAddress::from_str(value).ok())
        .unwrap_or_else(|| fallback_upstream_address());
    Ok((pass, address))
}

fn fallback_upstream_address() -> UasAddress {
    UasAddress::new(
        UasKind::Other("exotic_quant_owner_path_canonicalization_preflight_gate".to_string()),
        b"fallback-owner-path-canonicalization-preflight-gate-address",
        CREATED_AT_MS,
    )
}

fn build_ledger(
    upstream_address: UasAddress,
    cards: Vec<OwnerPathByteEnvelopePreflightCard>,
) -> Result<
    OwnerPathByteEnvelopePreflightLedger,
    agent_core::uas::OwnerPathByteEnvelopePreflightError,
> {
    OwnerPathByteEnvelopePreflightLedger::new(
        upstream_address,
        UPSTREAM_REF,
        cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        CompressedModelPromotionTier::T1L1Metadata,
        LEDGER_METADATA_BYTES,
        true,
        true,
        false,
        true,
        true,
        true,
        true,
        EXOTIC_QUANT_OWNER_PATH_BYTE_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR,
        CREATED_AT_MS,
    )
}

fn has_gate(cards: &[OwnerPathByteEnvelopePreflightCard], gate_id: &str) -> bool {
    cards.iter().any(|card| card.gate_id == gate_id)
}

fn red_pass(results: &[(&'static str, bool)], id: &str) -> bool {
    results
        .iter()
        .find(|(fixture_id, _)| *fixture_id == id)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn red_fixture_results(cards: &[OwnerPathByteEnvelopePreflightCard]) -> Vec<(&'static str, bool)> {
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
        "bad_byte_budget_ref",
        reject_first(cards, |card| {
            card.proof_refs.byte_budget_ref = "byte_budget:wrong".to_string()
        }),
    ));
    results.push((
        "bad_byte_envelope_ref",
        reject_first(cards, |card| {
            card.proof_refs.byte_envelope_ref = "byte_envelope:wrong".to_string()
        }),
    ));
    results.push((
        "bad_hardware_denial_ref",
        reject_first(cards, |card| {
            card.proof_refs.hardware_denial_ref = "hardware_denial:wrong".to_string()
        }),
    ));
    results.push((
        "bad_expected_policy",
        reject_first(cards, |card| card.policy.current_m2pro_16gb_denied = false),
    ));
    results.push((
        "bad_byte_envelope",
        reject_first(cards, |card| card.envelope.selected_support_bytes += 1),
    ));
    results.push((
        "current_hardware_bypass",
        reject_first(cards, |card| card.current_m2pro_16gb_denied = false),
    ));
    results.push((
        "mac_24_to_32gb_requirement_bypass",
        reject_first(cards, |card| card.mac_24_to_32gb_required = false),
    ));
    results.push((
        "server_row_allowed",
        reject_cards(cards, |bad| {
            if let Some(card) = bad.iter_mut().find(|card| card.server_only_denied_on_mac) {
                card.server_only_denied_on_mac = false;
            }
        }),
    ));
    results.push((
        "selected_bytes_resident_claim",
        reject_first(cards, |card| {
            card.selected_bytes_become_resident_claim = true
        }),
    ));
    results.push((
        "owner_manifest_present",
        reject_first(cards, |card| card.owner_manifest_present = true),
    ));
    results.push((
        "owner_supplied_path_present",
        reject_first(cards, |card| card.owner_supplied_path_present = true),
    ));
    results.push((
        "local_artifact_verified",
        reject_first(cards, |card| card.local_artifact_verified = true),
    ));
    results.push((
        "file_open_allowed",
        reject_first(cards, |card| card.local_path_open_allowed = true),
    ));
    results.push((
        "file_stat_allowed",
        reject_first(cards, |card| card.file_stat_allowed = true),
    ));
    results.push((
        "file_hash_allowed",
        reject_first(cards, |card| card.file_hash_allowed = true),
    ));
    results.push((
        "symlink_follow_allowed",
        reject_first(cards, |card| card.symlink_follow_allowed = true),
    ));
    results.push((
        "command_armed",
        reject_first(cards, |card| card.command_armed = true),
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
        "missing_command_visibility",
        reject_first(cards, |card| card.command_envelope_visible = false),
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
        build_with_metadata(cards, 512 * 1024 + 1).is_err(),
    ));
    results.push((
        "owner_manifest_bytes_read",
        reject_first(cards, |card| card.byte_ledger.owner_manifest_bytes_read = 1),
    ));
    results.push((
        "owner_path_bytes_read",
        reject_first(cards, |card| card.byte_ledger.owner_path_bytes_read = 1),
    ));
    results.push((
        "local_file_bytes_read",
        reject_first(cards, |card| card.byte_ledger.local_file_bytes_read = 1),
    ));
    results.push((
        "byte_hash_attempt",
        reject_first(cards, |card| card.byte_ledger.byte_hash_attempts = 1),
    ));
    results.push((
        "path_open_attempt",
        reject_first(cards, |card| card.byte_ledger.local_path_open_attempts = 1),
    ));
    results.push((
        "file_stat_call",
        reject_first(cards, |card| card.byte_ledger.file_stat_calls = 1),
    ));
    results.push((
        "symlink_resolution_attempt",
        reject_first(cards, |card| {
            card.byte_ledger.symlink_resolution_attempts = 1
        }),
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
        "bad_answer_packet_ref",
        reject_first(cards, |card| {
            card.proof_refs.answer_packet_ref = "answer_packet:wrong".to_string()
        }),
    ));
    results.push((
        "bad_next_cursor",
        build_with_cursor(cards, "wrong_cursor").is_err(),
    ));
    results
}

fn reject_first<F>(cards: &[OwnerPathByteEnvelopePreflightCard], mutate: F) -> bool
where
    F: FnOnce(&mut OwnerPathByteEnvelopePreflightCard),
{
    reject_cards(cards, |bad| mutate(&mut bad[0]))
}

fn reject_cards<F>(cards: &[OwnerPathByteEnvelopePreflightCard], mutate: F) -> bool
where
    F: FnOnce(&mut Vec<OwnerPathByteEnvelopePreflightCard>),
{
    let mut bad = cards.to_vec();
    mutate(&mut bad);
    build_ledger(fallback_upstream_address(), bad).is_err()
}

fn build_with_metadata(
    cards: &[OwnerPathByteEnvelopePreflightCard],
    metadata_bytes: u64,
) -> Result<
    OwnerPathByteEnvelopePreflightLedger,
    agent_core::uas::OwnerPathByteEnvelopePreflightError,
> {
    OwnerPathByteEnvelopePreflightLedger::new(
        fallback_upstream_address(),
        UPSTREAM_REF,
        cards.to_vec(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        CompressedModelPromotionTier::T1L1Metadata,
        metadata_bytes,
        true,
        true,
        false,
        true,
        true,
        true,
        true,
        EXOTIC_QUANT_OWNER_PATH_BYTE_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR,
        CREATED_AT_MS,
    )
}

fn build_with_cursor(
    cards: &[OwnerPathByteEnvelopePreflightCard],
    next_cursor: &str,
) -> Result<
    OwnerPathByteEnvelopePreflightLedger,
    agent_core::uas::OwnerPathByteEnvelopePreflightError,
> {
    OwnerPathByteEnvelopePreflightLedger::new(
        fallback_upstream_address(),
        UPSTREAM_REF,
        cards.to_vec(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        CompressedModelPromotionTier::T1L1Metadata,
        LEDGER_METADATA_BYTES,
        true,
        true,
        false,
        true,
        true,
        true,
        true,
        next_cursor,
        CREATED_AT_MS,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_builds_and_keeps_byte_envelope_metadata_only() {
        let artifact = build_artifact().expect("artifact builds");
        assert_eq!(artifact.falsifier_id, FALSIFIER_ID);
        assert!(artifact.overall_pass);
        assert_eq!(
            artifact.measurements["gate_card_count"].value,
            serde_json::json!(5)
        );
        assert_eq!(
            artifact.measurements["selected_artifact_bytes_sum"].value,
            serde_json::json!(96_318_502_063_u64)
        );
        assert_eq!(
            artifact.measurements["runtime_bytes_loaded_total"].value,
            serde_json::json!(0)
        );
        assert_eq!(
            artifact.measurements["next_cursor"].value,
            serde_json::json!(EXOTIC_QUANT_OWNER_PATH_BYTE_ENVELOPE_PREFLIGHT_GATE_NEXT_CURSOR)
        );
    }
}
