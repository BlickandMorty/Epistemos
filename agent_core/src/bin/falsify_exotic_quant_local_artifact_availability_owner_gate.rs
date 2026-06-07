//! `falsify_exotic_quant_local_artifact_availability_owner_gate`
//!
//! Metadata-only witness for `F-ExoticQuantLocalArtifactAvailabilityOwnerGate`.
//! It proves exotic quant rows remain fail-closed when no owner-approved local
//! artifact manifest exists, without opening paths, statting files, hashing
//! weights, arming commands, running loaders, or promoting product capability.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::axes::EXOTIC_QUANT_LOCAL_ARTIFACT_AVAILABILITY_OWNER_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    CompressedModelPromotionTier, ExoticQuantArtifactAvailabilityAction,
    ExoticQuantArtifactAvailabilityByteLedger, ExoticQuantArtifactAvailabilityGateCard,
    ExoticQuantArtifactAvailabilityGateLedger, ExoticQuantArtifactAvailabilityProofRefs,
    ExoticQuantArtifactAvailabilityState, HardwareTier, ModelCatalogRuntimeLane, ProStatus,
    ProductBuild, UasAddress, UasKind,
    EXOTIC_QUANT_LOCAL_ARTIFACT_AVAILABILITY_OWNER_GATE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-ExoticQuantLocalArtifactAvailabilityOwnerGate";
const FIXTURE_ID: &str = "exotic_quant_local_artifact_availability_owner_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_exotic_quant_local_artifact_availability_owner_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/exotic_quant_local_artifact_availability_owner_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/exotic_quant_loader_compatibility_model_path_gate/result.json";
const UPSTREAM_REF: &str =
    "artifact:falsifiers/exotic_quant_loader_compatibility_model_path_gate/result.json#F-ExoticQuantLoaderCompatibilityModelPathGate";
const CREATED_AT_MS: u64 = 1_779_417_200_000;
const LEDGER_METADATA_BYTES: u64 = 248_000;

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
        "{FALSIFIER_ID}: overall_pass={} gate_card_count={} owner_manifest_present_count={} local_path_verified_count={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["gate_card_count"].value,
        artifact.measurements["owner_manifest_present_count"].value,
        artifact.measurements["local_path_verified_count"].value,
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
    let (upstream_pass, upstream_address) = upstream_loader_path_gate()?;
    let cards = accepted_cards();
    let ledger = build_ledger(upstream_address.clone(), cards.clone())?;
    let reversed = build_ledger(upstream_address, cards.iter().cloned().rev().collect())?;
    let metrics = ledger.metrics();
    let red_results = red_fixture_results(&cards);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_loader_path_gate_pass", upstream_pass),
        (
            "accepted_artifact_availability_gate_pack_present",
            has_gate(&cards, "qwopus27b_tq3_4s_artifact_availability_gate")
                && has_gate(&cards, "qwopus27b_hlwq_q5_artifact_availability_gate")
                && has_gate(&cards, "qwopus_moe_apex_artifact_availability_gate")
                && has_gate(&cards, "gemma4_31b_nvfp4_artifact_availability_gate")
                && has_gate(&cards, "gemma4_31b_autoround_artifact_availability_gate"),
        ),
        (
            "source_pin_cards_bound",
            cards.iter().all(|card| {
                card.proof_refs
                    .source_pin_card_ref
                    .ends_with(&card.source_pin_card_id)
            }) && red_pass(&red_results, "bad_source_pin_card"),
        ),
        (
            "owner_manifest_required_but_absent",
            metrics.owner_manifest_required_count == 3
                && metrics.owner_manifest_present_count == 0
                && metrics.owner_manifest_approved_count == 0
                && red_pass(&red_results, "owner_manifest_present")
                && red_pass(&red_results, "owner_manifest_approved")
                && red_pass(&red_results, "owner_manifest_digest_bound")
                && red_pass(&red_results, "owner_manifest_bytes_read"),
        ),
        (
            "local_artifact_availability_not_proven",
            !ledger.local_artifact_availability_proven
                && metrics.local_path_verified_count == 0
                && metrics.path_directory_entry_seen_count == 0
                && red_pass(&red_results, "ledger_local_artifact_available")
                && red_pass(&red_results, "local_path_verified")
                && red_pass(&red_results, "path_directory_entry_seen"),
        ),
        (
            "path_canonicalization_required_not_performed",
            metrics.path_canonicalization_required_count == 3
                && metrics.path_canonicalized_count == 0
                && red_pass(&red_results, "path_canonicalized"),
        ),
        (
            "server_only_artifact_denied_on_mac",
            metrics.server_only_artifact_denied_count == 2
                && red_pass(&red_results, "server_only_manifest_required")
                && red_pass(&red_results, "bad_availability_state")
                && red_pass(&red_results, "bad_action"),
        ),
        (
            "commands_unarmed",
            metrics.command_envelope_unarmed_count == 5
                && metrics.command_execution_count_total == 0
                && red_pass(&red_results, "command_armed")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "missing_command_visibility"),
        ),
        (
            "paths_unopened_unhashed_unresolved",
            metrics.local_path_open_attempts_total == 0
                && metrics.file_stat_calls_total == 0
                && metrics.file_hash_attempts_total == 0
                && metrics.symlink_resolution_attempts_total == 0
                && red_pass(&red_results, "local_path_opened")
                && red_pass(&red_results, "file_stat_call")
                && red_pass(&red_results, "file_hash_attempted")
                && red_pass(&red_results, "symlink_followed")
                && red_pass(&red_results, "symlink_resolution_attempt"),
        ),
        (
            "explicit_no_runtime_probe_allowed",
            cards.iter().all(|card| !card.runtime_probe_allowed)
                && red_pass(&red_results, "runtime_probe_allowed"),
        ),
        (
            "runtime_deferred",
            cards.iter().all(|card| card.runtime_deferred)
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
                && metrics.command_execution_count_total == 0
                && metrics.local_path_open_attempts_total == 0
                && metrics.file_stat_calls_total == 0
                && metrics.file_hash_attempts_total == 0
                && metrics.model_bytes_loaded_total == 0
                && metrics.runtime_bytes_loaded_total == 0
                && metrics.provider_calls_made_total == 0
                && metrics.source_tree_bytes_read_total == 0
                && metrics.product_bytes_copied_total == 0
                && metrics.benchmark_runs_total == 0
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_call_made")
                && red_pass(&red_results, "source_tree_bytes_read")
                && red_pass(&red_results, "product_bytes_copied")
                && red_pass(&red_results, "benchmark_run"),
        ),
        (
            "deterministic_address",
            ledger.ledger_address == reversed.ledger_address,
        ),
        (
            "next_cursor_bound",
            ledger.next_cursor == EXOTIC_QUANT_LOCAL_ARTIFACT_AVAILABILITY_OWNER_GATE_NEXT_CURSOR
                && red_pass(&red_results, "bad_next_cursor"),
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

    for (name, passed) in &red_results {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            *passed,
        );
    }

    for (name, actual, expected, unit) in [
        ("gate_card_count", metrics.gate_card_count, 5, "cards"),
        (
            "owner_manifest_required_count",
            metrics.owner_manifest_required_count,
            3,
            "cards",
        ),
        (
            "owner_manifest_present_count",
            metrics.owner_manifest_present_count,
            0,
            "cards",
        ),
        (
            "owner_manifest_approved_count",
            metrics.owner_manifest_approved_count,
            0,
            "cards",
        ),
        (
            "path_canonicalization_required_count",
            metrics.path_canonicalization_required_count,
            3,
            "cards",
        ),
        (
            "path_canonicalized_count",
            metrics.path_canonicalized_count,
            0,
            "paths",
        ),
        (
            "local_path_verified_count",
            metrics.local_path_verified_count,
            0,
            "paths",
        ),
        (
            "path_directory_entry_seen_count",
            metrics.path_directory_entry_seen_count,
            0,
            "paths",
        ),
        (
            "server_only_artifact_denied_count",
            metrics.server_only_artifact_denied_count,
            2,
            "cards",
        ),
        (
            "command_envelope_unarmed_count",
            metrics.command_envelope_unarmed_count,
            5,
            "cards",
        ),
        (
            "directory_entry_scan_count_total",
            metrics.directory_entry_scan_count_total,
            3,
            "entries",
        ),
        (
            "owner_manifest_bytes_read_total",
            metrics.owner_manifest_bytes_read_total,
            0,
            "bytes",
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
            "file_hash_attempts_total",
            metrics.file_hash_attempts_total,
            0,
            "attempts",
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

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        58,
        "fixtures",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_rejection_count",
        red_fixture_rejection_count,
        "==",
        red_results.len() as u64,
        "fixtures",
    );

    measurements.insert(
        "artifact_availability_gate_address".to_string(),
        Measurement {
            value: serde_json::json!(ledger.ledger_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "artifact_availability_gate_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "artifact_availability_gate_address".to_string(),
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
            operator: "==".to_string(),
            value: serde_json::json!(
                EXOTIC_QUANT_LOCAL_ARTIFACT_AVAILABILITY_OWNER_GATE_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        ledger.next_cursor == EXOTIC_QUANT_LOCAL_ARTIFACT_AVAILABILITY_OWNER_GATE_NEXT_CURSOR,
    );

    for axis in EXOTIC_QUANT_LOCAL_ARTIFACT_AVAILABILITY_OWNER_GATE_AXES {
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

    let artifact = ArtifactBuilder {
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
        notes: "metadata-only F-ExoticQuantLocalArtifactAvailabilityOwnerGate: consumes the loader/path gate and proves five exotic quant rows remain owner-manifest-gated with zero owner manifest bytes, zero local path verification, zero path opens/stat calls/file hashes/symlink resolution, zero commands, zero model/runtime/provider/source/product/benchmark bytes, and no MAS/L2/L3/user-facing promotion. It does not prove local artifact availability, loader execution, first token, quality, or Apple Silicon fit.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();
    Ok(artifact)
}

fn upstream_loader_path_gate() -> Result<(bool, UasAddress), Box<dyn std::error::Error>> {
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
            .map(|id| id == "F-ExoticQuantLoaderCompatibilityModelPathGate")
            .unwrap_or(false);
    let address = json
        .pointer("/measurements/loader_path_gate_address/value")
        .and_then(serde_json::Value::as_str)
        .and_then(|value| UasAddress::from_str(value).ok())
        .unwrap_or_else(|| {
            UasAddress::new(
                UasKind::Other("exotic_quant_loader_compatibility_model_path_gate".to_string()),
                b"fallback-loader-path-gate-address",
                CREATED_AT_MS,
            )
        });
    Ok((pass, address))
}

fn build_ledger(
    upstream_address: UasAddress,
    cards: Vec<ExoticQuantArtifactAvailabilityGateCard>,
) -> Result<
    ExoticQuantArtifactAvailabilityGateLedger,
    agent_core::uas::ExoticQuantArtifactAvailabilityGateError,
> {
    ExoticQuantArtifactAvailabilityGateLedger::new(
        upstream_address,
        UPSTREAM_REF,
        cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        CompressedModelPromotionTier::T1L1Metadata,
        LEDGER_METADATA_BYTES,
        false,
        false,
        true,
        true,
        true,
        EXOTIC_QUANT_LOCAL_ARTIFACT_AVAILABILITY_OWNER_GATE_NEXT_CURSOR,
        CREATED_AT_MS,
    )
}

fn has_gate(cards: &[ExoticQuantArtifactAvailabilityGateCard], gate_id: &str) -> bool {
    cards.iter().any(|card| card.gate_id == gate_id)
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(candidate, _)| *candidate == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn red_fixture_results(
    cards: &[ExoticQuantArtifactAvailabilityGateCard],
) -> Vec<(&'static str, bool)> {
    let upstream_address = UasAddress::new(
        UasKind::Other("exotic_quant_loader_compatibility_model_path_gate".to_string()),
        b"red-fixture-upstream",
        CREATED_AT_MS,
    );
    let mut results = Vec::new();

    results.push((
        "duplicate_gate_id",
        set_error(cards, |items| items[1].gate_id = items[0].gate_id.clone()),
    ));
    results.push((
        "duplicate_model_id",
        set_error(cards, |items| items[1].model_id = items[0].model_id.clone()),
    ));
    results.push((
        "duplicate_source_pin_card_id",
        set_error(cards, |items| {
            items[1].source_pin_card_id = items[0].source_pin_card_id.clone()
        }),
    ));
    results.push((
        "missing_expected_model",
        set_error(cards, |items| {
            items.remove(0);
        }),
    ));
    results.push((
        "bad_source_pin_card",
        card_error(cards, 0, |card| {
            card.source_pin_card_id = "wrong_source_pin".to_string()
        }),
    ));
    results.push((
        "bad_selected_artifact_path",
        card_error(cards, 0, |card| {
            card.selected_artifact_path = "wrong.gguf".to_string()
        }),
    ));
    results.push((
        "bad_hardware_tier",
        card_error(cards, 0, |card| {
            card.hardware_tier = HardwareTier::Mac16To18Gb
        }),
    ));
    results.push((
        "bad_runtime_lane",
        card_error(cards, 0, |card| {
            card.runtime_lane = ModelCatalogRuntimeLane::MlxSwift
        }),
    ));
    results.push((
        "bad_availability_state",
        card_error(cards, 0, |card| {
            card.availability_state =
                ExoticQuantArtifactAvailabilityState::ServerOnlyMacArtifactDenied
        }),
    ));
    results.push((
        "bad_action",
        card_error(cards, 0, |card| {
            card.action = ExoticQuantArtifactAvailabilityAction::DenyMacArtifactProbe
        }),
    ));
    results.push((
        "server_only_manifest_required",
        card_error(cards, 3, |card| card.owner_manifest_required = true),
    ));
    results.push((
        "owner_manifest_not_required_on_mac_candidate",
        card_error(cards, 0, |card| card.owner_manifest_required = false),
    ));
    results.push((
        "owner_manifest_present",
        card_error(cards, 0, |card| card.owner_manifest_present = true),
    ));
    results.push((
        "owner_manifest_approved",
        card_error(cards, 0, |card| card.owner_manifest_approved = true),
    ));
    results.push((
        "owner_manifest_digest_bound",
        card_error(cards, 0, |card| card.owner_manifest_digest_bound = true),
    ));
    results.push((
        "path_canonicalization_not_required",
        card_error(cards, 0, |card| card.path_canonicalization_required = false),
    ));
    results.push((
        "path_canonicalized",
        card_error(cards, 0, |card| card.path_canonicalized = true),
    ));
    results.push((
        "path_directory_entry_seen",
        card_error(cards, 0, |card| card.path_directory_entry_seen = true),
    ));
    results.push((
        "local_path_verified",
        card_error(cards, 0, |card| card.local_path_verified = true),
    ));
    results.push((
        "local_path_opened",
        card_error(cards, 0, |card| card.local_path_opened = true),
    ));
    results.push((
        "file_hash_attempted",
        card_error(cards, 0, |card| card.file_hash_attempted = true),
    ));
    results.push((
        "symlink_followed",
        card_error(cards, 0, |card| card.symlink_followed = true),
    ));
    results.push((
        "command_armed",
        card_error(cards, 0, |card| card.command_armed = true),
    ));
    results.push((
        "command_executed",
        card_error(cards, 0, |card| card.command_executed = true),
    ));
    results.push((
        "runtime_probe_allowed",
        card_error(cards, 0, |card| card.runtime_probe_allowed = true),
    ));
    results.push((
        "runtime_not_deferred",
        card_error(cards, 0, |card| card.runtime_deferred = false),
    ));
    results.push((
        "missing_command_visibility",
        card_error(cards, 0, |card| card.command_envelope_visible = false),
    ));
    results.push((
        "missing_rollback",
        card_error(cards, 0, |card| card.rollback_required = false),
    ));
    results.push((
        "missing_run_event_log",
        card_error(cards, 0, |card| card.run_event_log_required = false),
    ));
    results.push((
        "missing_answer_packet",
        card_error(cards, 0, |card| card.answer_packet_required = false),
    ));
    results.push((
        "missing_abstention",
        card_error(cards, 0, |card| card.abstention_required = false),
    ));
    results.push((
        "mas_allowed",
        card_error(cards, 0, |card| card.mas_allowed = true),
    ));
    results.push((
        "product_route_enabled",
        card_error(cards, 0, |card| card.product_route_enabled = true),
    ));
    results.push((
        "app_default_claim",
        card_error(cards, 0, |card| card.app_default_claim = true),
    ));
    results.push((
        "product_winner_claim",
        card_error(cards, 0, |card| card.product_winner_claim = true),
    ));
    results.push((
        "route_policy_mutated",
        card_error(cards, 0, |card| card.route_policy_mutated = true),
    ));
    results.push((
        "hidden_route_authority",
        card_error(cards, 0, |card| card.hidden_route_authority = true),
    ));
    results.push((
        "hidden_cloud_fallback",
        card_error(cards, 0, |card| card.hidden_cloud_fallback = true),
    ));
    results.push((
        "patternboost_authority",
        card_error(cards, 0, |card| card.patternboost_live_authority = true),
    ));
    results.push((
        "lattice_authority",
        card_error(cards, 0, |card| card.lattice_live_authority = true),
    ));
    results.push((
        "eidos_authority",
        card_error(cards, 0, |card| card.eidos_live_authority = true),
    ));
    results.push((
        "l2_l3_promotion",
        card_error(cards, 0, |card| card.l2_l3_promotion_claim = true),
    ));
    results.push((
        "live_dense_70b",
        card_error(cards, 0, |card| card.live_dense_70b_claim = true),
    ));
    results.push((
        "ssd_as_ram",
        card_error(cards, 0, |card| card.ssd_as_ram_claim = true),
    ));
    results.push((
        "source_import_allowed",
        card_error(cards, 0, |card| card.source_import_allowed = true),
    ));
    results.push((
        "benchmark_as_fit_proof",
        card_error(cards, 0, |card| card.benchmark_as_fit_proof = true),
    ));
    results.push((
        "metadata_budget_exceeded",
        card_error(cards, 0, |card| {
            card.byte_ledger.metadata_bytes_read = 100_000
        }),
    ));
    results.push((
        "missing_directory_scan_for_mac_candidate",
        card_error(cards, 0, |card| {
            card.byte_ledger.directory_entry_scan_count = 0
        }),
    ));
    results.push((
        "owner_manifest_bytes_read",
        card_error(cards, 0, |card| {
            card.byte_ledger.owner_manifest_bytes_read = 1
        }),
    ));
    results.push((
        "path_open_attempt",
        card_error(cards, 0, |card| {
            card.byte_ledger.local_path_open_attempts = 1
        }),
    ));
    results.push((
        "file_stat_call",
        card_error(cards, 0, |card| card.byte_ledger.file_stat_calls = 1),
    ));
    results.push((
        "hash_attempt",
        card_error(cards, 0, |card| card.byte_ledger.file_hash_attempts = 1),
    ));
    results.push((
        "symlink_resolution_attempt",
        card_error(cards, 0, |card| {
            card.byte_ledger.symlink_resolution_attempts = 1
        }),
    ));
    results.push((
        "model_bytes_loaded",
        card_error(cards, 0, |card| card.byte_ledger.model_bytes_loaded = 1),
    ));
    results.push((
        "runtime_bytes_loaded",
        card_error(cards, 0, |card| card.byte_ledger.runtime_bytes_loaded = 1),
    ));
    results.push((
        "provider_call_made",
        card_error(cards, 0, |card| card.byte_ledger.provider_calls_made = 1),
    ));
    results.push((
        "source_tree_bytes_read",
        card_error(cards, 0, |card| card.byte_ledger.source_tree_bytes_read = 1),
    ));
    results.push((
        "product_bytes_copied",
        card_error(cards, 0, |card| card.byte_ledger.product_bytes_copied = 1),
    ));
    results.push((
        "benchmark_run",
        card_error(cards, 0, |card| card.byte_ledger.benchmark_runs = 1),
    ));
    results.push((
        "bad_owner_manifest_ref",
        card_error(cards, 0, |card| {
            card.proof_refs.owner_manifest_ref = "owner_manifest:approved".to_string()
        }),
    ));
    results.push((
        "bad_artifact_availability_ref",
        card_error(cards, 0, |card| {
            card.proof_refs.artifact_availability_ref = "artifact:available".to_string()
        }),
    ));
    results.push((
        "bad_path_canonicalization_ref",
        card_error(cards, 0, |card| {
            card.proof_refs.path_canonicalization_ref = "path:canonical".to_string()
        }),
    ));
    results.push((
        "bad_answer_packet_ref",
        card_error(cards, 0, |card| {
            card.proof_refs.answer_packet_ref = "packet:hidden".to_string()
        }),
    ));
    results.push((
        "ledger_local_artifact_available",
        ExoticQuantArtifactAvailabilityGateLedger::new(
            upstream_address.clone(),
            UPSTREAM_REF,
            cards.to_vec(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            CompressedModelPromotionTier::T1L1Metadata,
            LEDGER_METADATA_BYTES,
            true,
            false,
            true,
            true,
            true,
            EXOTIC_QUANT_LOCAL_ARTIFACT_AVAILABILITY_OWNER_GATE_NEXT_CURSOR,
            CREATED_AT_MS,
        )
        .is_err(),
    ));
    results.push((
        "ledger_owner_manifest_available",
        ExoticQuantArtifactAvailabilityGateLedger::new(
            upstream_address.clone(),
            UPSTREAM_REF,
            cards.to_vec(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            CompressedModelPromotionTier::T1L1Metadata,
            LEDGER_METADATA_BYTES,
            false,
            true,
            true,
            true,
            true,
            EXOTIC_QUANT_LOCAL_ARTIFACT_AVAILABILITY_OWNER_GATE_NEXT_CURSOR,
            CREATED_AT_MS,
        )
        .is_err(),
    ));
    results.push((
        "bad_next_cursor",
        ExoticQuantArtifactAvailabilityGateLedger::new(
            upstream_address,
            UPSTREAM_REF,
            cards.to_vec(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            CompressedModelPromotionTier::T1L1Metadata,
            LEDGER_METADATA_BYTES,
            false,
            false,
            true,
            true,
            true,
            "runtime_now",
            CREATED_AT_MS,
        )
        .is_err(),
    ));

    results
}

fn set_error(
    cards: &[ExoticQuantArtifactAvailabilityGateCard],
    mutate: impl FnOnce(&mut Vec<ExoticQuantArtifactAvailabilityGateCard>),
) -> bool {
    let mut mutated = cards.to_vec();
    mutate(&mut mutated);
    build_ledger(
        UasAddress::new(
            UasKind::Other("exotic_quant_loader_compatibility_model_path_gate".to_string()),
            b"red-fixture-set-error",
            CREATED_AT_MS,
        ),
        mutated,
    )
    .is_err()
}

fn card_error(
    cards: &[ExoticQuantArtifactAvailabilityGateCard],
    index: usize,
    mutate: impl FnOnce(&mut ExoticQuantArtifactAvailabilityGateCard),
) -> bool {
    let mut mutated = cards.to_vec();
    mutate(&mut mutated[index]);
    build_ledger(
        UasAddress::new(
            UasKind::Other("exotic_quant_loader_compatibility_model_path_gate".to_string()),
            b"red-fixture-card-error",
            CREATED_AT_MS,
        ),
        mutated,
    )
    .is_err()
}

fn accepted_cards() -> Vec<ExoticQuantArtifactAvailabilityGateCard> {
    vec![
        card(
            "qwopus27b_tq3_4s_artifact_availability_gate",
            "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
            "qwopus27b_tq3_4s",
            "Qwopus3.5-27B-v3-TQ3_4S.gguf",
            HardwareTier::Mac24To32Gb,
            ModelCatalogRuntimeLane::GgufLlamaCpp,
            ExoticQuantArtifactAvailabilityState::OwnerManifestMissingNoLocalArtifactVerified,
            ExoticQuantArtifactAvailabilityAction::RequireOwnerPathManifest,
            true,
            1,
        ),
        card(
            "qwopus27b_hlwq_q5_artifact_availability_gate",
            "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5",
            "qwopus27b_hlwq_q5",
            "model_int4.pt",
            HardwareTier::Mac24To32Gb,
            ModelCatalogRuntimeLane::Transformers,
            ExoticQuantArtifactAvailabilityState::OwnerManifestMissingNoLocalArtifactVerified,
            ExoticQuantArtifactAvailabilityAction::RequireOwnerPathManifest,
            true,
            1,
        ),
        card(
            "qwopus_moe_apex_artifact_availability_gate",
            "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
            "qwopus_moe_35b_a3b_apex_mini",
            "Qwopus-MoE-35B-A3B-APEX-I-Mini.gguf",
            HardwareTier::Mac24To32Gb,
            ModelCatalogRuntimeLane::GgufLlamaCpp,
            ExoticQuantArtifactAvailabilityState::OwnerManifestMissingNoLocalArtifactVerified,
            ExoticQuantArtifactAvailabilityAction::RequireOwnerPathManifest,
            true,
            1,
        ),
        card(
            "gemma4_31b_nvfp4_artifact_availability_gate",
            "nvidia/Gemma-4-31B-IT-NVFP4",
            "gemma4_31b_nvfp4",
            "aggregate:nvfp4-safetensors",
            HardwareTier::CudaBlackwellOnly,
            ModelCatalogRuntimeLane::CudaBlackwell,
            ExoticQuantArtifactAvailabilityState::ServerOnlyMacArtifactDenied,
            ExoticQuantArtifactAvailabilityAction::DenyMacArtifactProbe,
            false,
            0,
        ),
        card(
            "gemma4_31b_autoround_artifact_availability_gate",
            "Intel/gemma-4-31B-it-int4-AutoRound",
            "gemma4_31b_int4_autoround",
            "aggregate:autoround-int4",
            HardwareTier::ServerGpuResearch,
            ModelCatalogRuntimeLane::Transformers,
            ExoticQuantArtifactAvailabilityState::ServerOnlyMacArtifactDenied,
            ExoticQuantArtifactAvailabilityAction::DenyMacArtifactProbe,
            false,
            0,
        ),
    ]
}

#[allow(clippy::too_many_arguments)]
fn card(
    gate_id: &str,
    model_id: &str,
    source_pin_card_id: &str,
    selected_artifact_path: &str,
    hardware_tier: HardwareTier,
    runtime_lane: ModelCatalogRuntimeLane,
    availability_state: ExoticQuantArtifactAvailabilityState,
    action: ExoticQuantArtifactAvailabilityAction,
    owner_manifest_required: bool,
    directory_entry_scan_count: u64,
) -> ExoticQuantArtifactAvailabilityGateCard {
    ExoticQuantArtifactAvailabilityGateCard {
        gate_id: gate_id.to_string(),
        model_id: model_id.to_string(),
        source_pin_card_id: source_pin_card_id.to_string(),
        selected_artifact_path: selected_artifact_path.to_string(),
        hardware_tier,
        runtime_lane,
        availability_state,
        action,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
        byte_ledger: ExoticQuantArtifactAvailabilityByteLedger::metadata_only(
            8192,
            directory_entry_scan_count,
        ),
        proof_refs: refs(gate_id, source_pin_card_id),
        user_visible_summary: format!(
            "{gate_id} records that {model_id} has no owner-approved local artifact availability yet. The Mac candidate rows require owner path-manifest intake before canonicalization or proof, server/GPU rows stay denied for Mac, commands stay unarmed, no path is opened, no file is hashed, no symlink is followed, and rollback, RunEventLog, AnswerPacket, abstention, and SovereignGate refs remain mandatory."
        ),
        owner_manifest_required,
        owner_manifest_present: false,
        owner_manifest_approved: false,
        owner_manifest_digest_bound: false,
        path_canonicalization_required: owner_manifest_required,
        path_canonicalized: false,
        path_directory_entry_seen: false,
        local_path_verified: false,
        local_path_opened: false,
        file_hash_attempted: false,
        symlink_followed: false,
        command_envelope_visible: true,
        command_armed: false,
        command_executed: false,
        runtime_probe_allowed: false,
        runtime_deferred: true,
        rollback_required: true,
        run_event_log_required: true,
        answer_packet_required: true,
        abstention_required: true,
        mas_allowed: false,
        product_route_enabled: false,
        app_default_claim: false,
        product_winner_claim: false,
        route_policy_mutated: false,
        hidden_route_authority: false,
        hidden_cloud_fallback: false,
        patternboost_live_authority: false,
        lattice_live_authority: false,
        eidos_live_authority: false,
        live_dense_70b_claim: false,
        ssd_as_ram_claim: false,
        l2_l3_promotion_claim: false,
        source_import_allowed: false,
        benchmark_as_fit_proof: false,
    }
}

fn refs(gate_id: &str, source_pin_card_id: &str) -> ExoticQuantArtifactAvailabilityProofRefs {
    ExoticQuantArtifactAvailabilityProofRefs {
        upstream_loader_path_gate_ref: UPSTREAM_REF.to_string(),
        source_pin_card_ref: format!("source_pin_card:exotic_quant:{source_pin_card_id}"),
        owner_manifest_ref: format!("owner_manifest:required_or_denied:exotic_quant:{gate_id}"),
        artifact_availability_ref: format!(
            "artifact_availability:not_proven:exotic_quant:{gate_id}"
        ),
        path_canonicalization_ref: format!(
            "path_canonicalization:required_or_denied:exotic_quant:{gate_id}"
        ),
        command_envelope_ref: format!(
            "command_envelope:unarmed:exotic_quant_artifact_availability:{gate_id}"
        ),
        rollback_ref: format!("rollback:exotic_quant_artifact_availability:{gate_id}"),
        run_event_log_ref: format!("run_event_log:exotic_quant_artifact_availability:{gate_id}"),
        answer_packet_ref: format!("answer_packet:exotic_quant_artifact_availability:{gate_id}"),
        abstention_ref: format!("abstention:exotic_quant_artifact_availability:{gate_id}"),
        sovereign_gate_ref: format!("sovereign_gate:exotic_quant_artifact_availability:{gate_id}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_builds_and_keeps_local_availability_unproved() {
        let artifact = build_artifact().expect("artifact");
        assert!(artifact.overall_pass);
        assert_eq!(artifact.measurements["gate_card_count"].value, 5);
        assert_eq!(
            artifact.measurements["owner_manifest_present_count"].value,
            0
        );
        assert_eq!(artifact.measurements["local_path_verified_count"].value, 0);
        assert_eq!(artifact.measurements["runtime_bytes_loaded_total"].value, 0);
    }
}
