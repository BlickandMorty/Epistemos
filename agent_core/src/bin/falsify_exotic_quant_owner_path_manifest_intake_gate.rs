//! `falsify_exotic_quant_owner_path_manifest_intake_gate`
//!
//! Metadata-only witness for `F-ExoticQuantOwnerPathManifestIntakeGate`.
//! It defines the owner path-manifest contract required before any path
//! canonicalization, file access, command envelope, runtime probe, or product
//! promotion can begin.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::axes::EXOTIC_QUANT_OWNER_PATH_MANIFEST_INTAKE_GATE_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_owner_path_manifest_intake_cards, CompressedModelPromotionTier,
    OwnerPathManifestIntakeCard, OwnerPathManifestIntakeLedger, OwnerPathManifestIntakeState,
    ProStatus, ProductBuild, UasAddress, UasKind,
    EXOTIC_QUANT_OWNER_PATH_MANIFEST_INTAKE_GATE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-ExoticQuantOwnerPathManifestIntakeGate";
const FIXTURE_ID: &str = "exotic_quant_owner_path_manifest_intake_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_exotic_quant_owner_path_manifest_intake_gate.sh";
const RESULT: &str =
    "artifacts/falsifiers/exotic_quant_owner_path_manifest_intake_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/exotic_quant_local_artifact_availability_owner_gate/result.json";
const UPSTREAM_REF: &str =
    "artifact:falsifiers/exotic_quant_local_artifact_availability_owner_gate/result.json#F-ExoticQuantLocalArtifactAvailabilityOwnerGate";
const CREATED_AT_MS: u64 = 1_779_426_000_000;
const LEDGER_METADATA_BYTES: u64 = 268_000;

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
        "{FALSIFIER_ID}: overall_pass={} gate_card_count={} owner_manifest_schema_required_count={} path_canonicalized_count={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["gate_card_count"].value,
        artifact.measurements["owner_manifest_schema_required_count"].value,
        artifact.measurements["path_canonicalized_count"].value,
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
    let (upstream_pass, upstream_address) = upstream_availability_gate()?;
    let cards = canonical_owner_path_manifest_intake_cards(UPSTREAM_REF);
    let ledger = build_ledger(upstream_address.clone(), cards.clone())?;
    let reversed = build_ledger(upstream_address, cards.iter().cloned().rev().collect())?;
    let metrics = ledger.metrics();
    let red_results = red_fixture_results(&cards);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_artifact_availability_gate_pass", upstream_pass),
        (
            "accepted_owner_manifest_intake_pack_present",
            has_gate(&cards, "qwopus27b_tq3_4s_owner_path_manifest_intake")
                && has_gate(&cards, "qwopus27b_hlwq_q5_owner_path_manifest_intake")
                && has_gate(
                    &cards,
                    "qwopus_moe_35b_a3b_apex_mini_owner_path_manifest_intake",
                )
                && has_gate(&cards, "gemma4_31b_nvfp4_owner_path_manifest_intake")
                && has_gate(
                    &cards,
                    "gemma4_31b_int4_autoround_owner_path_manifest_intake",
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
            "manifest_contract_fields_required",
            metrics.owner_manifest_schema_required_count == 3
                && cards
                    .iter()
                    .filter(|card| {
                        card.state
                            == OwnerPathManifestIntakeState::SchemaRequiredOwnerManifestMissing
                    })
                    .all(|card| card.required_fields.no_promotion)
                && red_pass(&red_results, "missing_required_manifest_field")
                && red_pass(&red_results, "server_manifest_contract_enabled"),
        ),
        (
            "owner_manifest_absent_zero_bytes",
            metrics.owner_manifest_present_count == 0
                && metrics.owner_signature_present_count == 0
                && metrics.owner_manifest_digest_bound_count == 0
                && metrics.owner_manifest_bytes_read_total == 0
                && red_pass(&red_results, "owner_manifest_present")
                && red_pass(&red_results, "owner_signature_present")
                && red_pass(&red_results, "owner_manifest_digest_bound")
                && red_pass(&red_results, "owner_manifest_bytes_read"),
        ),
        (
            "path_canonicalization_deferred",
            metrics.path_canonicalization_allowed_count == 0
                && metrics.path_canonicalized_count == 0
                && metrics.path_canonicalization_attempts_total == 0
                && red_pass(&red_results, "path_canonicalization_allowed")
                && red_pass(&red_results, "path_canonicalized")
                && red_pass(&red_results, "path_canonicalization_attempt"),
        ),
        (
            "file_access_disallowed",
            metrics.file_open_allowed_count == 0
                && metrics.file_hash_allowed_count == 0
                && metrics.local_path_open_attempts_total == 0
                && metrics.file_stat_calls_total == 0
                && metrics.file_hash_attempts_total == 0
                && metrics.symlink_resolution_attempts_total == 0
                && red_pass(&red_results, "file_open_allowed")
                && red_pass(&red_results, "file_stat_allowed")
                && red_pass(&red_results, "file_hash_allowed")
                && red_pass(&red_results, "symlink_resolution_allowed")
                && red_pass(&red_results, "path_open_attempt")
                && red_pass(&red_results, "file_stat_call")
                && red_pass(&red_results, "hash_attempt")
                && red_pass(&red_results, "symlink_resolution_attempt"),
        ),
        (
            "server_only_manifest_intake_denied",
            metrics.server_only_manifest_denied_count == 2
                && red_pass(&red_results, "bad_intake_state")
                && red_pass(&red_results, "bad_action"),
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
                && metrics.local_path_open_attempts_total == 0
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
            ledger.next_cursor == EXOTIC_QUANT_OWNER_PATH_MANIFEST_INTAKE_GATE_NEXT_CURSOR
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

    for (fixture_id, passed) in &red_results {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            fixture_id,
            *passed,
        );
    }

    for (name, value, expected) in [
        ("gate_card_count", metrics.gate_card_count, 5),
        (
            "owner_manifest_schema_required_count",
            metrics.owner_manifest_schema_required_count,
            3,
        ),
        (
            "owner_manifest_present_count",
            metrics.owner_manifest_present_count,
            0,
        ),
        (
            "owner_signature_present_count",
            metrics.owner_signature_present_count,
            0,
        ),
        (
            "owner_manifest_digest_bound_count",
            metrics.owner_manifest_digest_bound_count,
            0,
        ),
        (
            "path_canonicalization_allowed_count",
            metrics.path_canonicalization_allowed_count,
            0,
        ),
        (
            "path_canonicalized_count",
            metrics.path_canonicalized_count,
            0,
        ),
        (
            "file_open_allowed_count",
            metrics.file_open_allowed_count,
            0,
        ),
        (
            "file_hash_allowed_count",
            metrics.file_hash_allowed_count,
            0,
        ),
        (
            "server_only_manifest_denied_count",
            metrics.server_only_manifest_denied_count,
            2,
        ),
        (
            "command_envelope_unarmed_count",
            metrics.command_envelope_unarmed_count,
            5,
        ),
        (
            "owner_manifest_bytes_read_total",
            metrics.owner_manifest_bytes_read_total,
            0,
        ),
        (
            "path_canonicalization_attempts_total",
            metrics.path_canonicalization_attempts_total,
            0,
        ),
        (
            "local_path_open_attempts_total",
            metrics.local_path_open_attempts_total,
            0,
        ),
        ("file_stat_calls_total", metrics.file_stat_calls_total, 0),
        (
            "file_hash_attempts_total",
            metrics.file_hash_attempts_total,
            0,
        ),
        (
            "symlink_resolution_attempts_total",
            metrics.symlink_resolution_attempts_total,
            0,
        ),
        (
            "command_execution_count_total",
            metrics.command_execution_count_total,
            0,
        ),
        (
            "model_bytes_loaded_total",
            metrics.model_bytes_loaded_total,
            0,
        ),
        (
            "runtime_bytes_loaded_total",
            metrics.runtime_bytes_loaded_total,
            0,
        ),
        (
            "provider_calls_made_total",
            metrics.provider_calls_made_total,
            0,
        ),
        (
            "source_tree_bytes_read_total",
            metrics.source_tree_bytes_read_total,
            0,
        ),
        (
            "product_bytes_copied_total",
            metrics.product_bytes_copied_total,
            0,
        ),
        ("benchmark_runs_total", metrics.benchmark_runs_total, 0),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            value,
            "==",
            expected,
            "count",
        );
    }

    measurements.insert(
        "selected_artifact_bytes_sum".to_string(),
        Measurement {
            value: serde_json::json!(metrics.selected_artifact_bytes_sum),
            unit: "bytes".to_string(),
        },
    );
    thresholds.insert(
        "selected_artifact_bytes_sum".to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::json!(96_318_502_063u64),
            unit: "bytes".to_string(),
        },
    );
    pass_per_axis.insert(
        "selected_artifact_bytes_sum".to_string(),
        metrics.selected_artifact_bytes_sum >= 96_318_502_063u64,
    );

    measurements.insert(
        "minimum_uma_bytes_required_max".to_string(),
        Measurement {
            value: serde_json::json!(metrics.minimum_uma_bytes_required_max),
            unit: "bytes".to_string(),
        },
    );
    thresholds.insert(
        "minimum_uma_bytes_required_max".to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::json!(39_108_307_031u64),
            unit: "bytes".to_string(),
        },
    );
    pass_per_axis.insert(
        "minimum_uma_bytes_required_max".to_string(),
        metrics.minimum_uma_bytes_required_max >= 39_108_307_031u64,
    );

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        50,
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
        "owner_manifest_intake_gate_address".to_string(),
        Measurement {
            value: serde_json::json!(ledger.ledger_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "owner_manifest_intake_gate_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::json!(true),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "owner_manifest_intake_gate_address".to_string(),
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
            value: serde_json::json!(EXOTIC_QUANT_OWNER_PATH_MANIFEST_INTAKE_GATE_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        ledger.next_cursor == EXOTIC_QUANT_OWNER_PATH_MANIFEST_INTAKE_GATE_NEXT_CURSOR,
    );

    for axis in EXOTIC_QUANT_OWNER_PATH_MANIFEST_INTAKE_GATE_AXES {
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
        notes: "metadata-only F-ExoticQuantOwnerPathManifestIntakeGate: defines the owner path-manifest contract for five exotic quant rows while reading zero owner manifest bytes, canonicalizing zero paths, opening zero files, hashing zero artifacts, arming zero commands, loading zero model/runtime/provider/source/product bytes, and making no MAS/L2/L3/user-facing promotion. It does not prove local artifact availability, owner approval, path safety, loader execution, first token, quality, or Apple Silicon fit.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_availability_gate() -> Result<(bool, UasAddress), Box<dyn std::error::Error>> {
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
            .map(|id| id == "F-ExoticQuantLocalArtifactAvailabilityOwnerGate")
            .unwrap_or(false);
    let address = json
        .pointer("/measurements/artifact_availability_gate_address/value")
        .and_then(serde_json::Value::as_str)
        .and_then(|value| UasAddress::from_str(value).ok())
        .unwrap_or_else(|| {
            UasAddress::new(
                UasKind::Other("exotic_quant_local_artifact_availability_owner_gate".to_string()),
                b"fallback-artifact-availability-gate-address",
                CREATED_AT_MS,
            )
        });
    Ok((pass, address))
}

fn build_ledger(
    upstream_address: UasAddress,
    cards: Vec<OwnerPathManifestIntakeCard>,
) -> Result<OwnerPathManifestIntakeLedger, agent_core::uas::OwnerPathManifestIntakeError> {
    OwnerPathManifestIntakeLedger::new(
        upstream_address,
        UPSTREAM_REF,
        cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        CompressedModelPromotionTier::T1L1Metadata,
        LEDGER_METADATA_BYTES,
        true,
        false,
        true,
        true,
        true,
        true,
        EXOTIC_QUANT_OWNER_PATH_MANIFEST_INTAKE_GATE_NEXT_CURSOR,
        CREATED_AT_MS,
    )
}

fn has_gate(cards: &[OwnerPathManifestIntakeCard], gate_id: &str) -> bool {
    cards.iter().any(|card| card.gate_id == gate_id)
}

fn red_pass(results: &[(&'static str, bool)], id: &str) -> bool {
    results
        .iter()
        .find(|(fixture_id, _)| *fixture_id == id)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn red_fixture_results(cards: &[OwnerPathManifestIntakeCard]) -> Vec<(&'static str, bool)> {
    vec![
        (
            "duplicate_gate_id",
            vec_error(cards, |cards| cards.push(cards[0].clone())),
        ),
        (
            "duplicate_model_id",
            vec_error(cards, |cards| cards[1].model_id = cards[0].model_id.clone()),
        ),
        (
            "duplicate_source_pin_card_id",
            vec_error(cards, |cards| {
                cards[1].source_pin_card_id = cards[0].source_pin_card_id.clone()
            }),
        ),
        (
            "missing_expected_model",
            vec_error(cards, |cards| {
                cards.retain(|card| card.source_pin_card_id != "qwopus27b_tq3_4s")
            }),
        ),
        (
            "bad_source_pin_card",
            card_error(cards, 0, |card| {
                card.source_pin_card_id = "wrong".to_string()
            }),
        ),
        (
            "bad_byte_budget_ref",
            card_error(cards, 0, |card| {
                card.proof_refs.byte_budget_ref = "byte_budget:bad".to_string()
            }),
        ),
        (
            "bad_selected_artifact_path",
            card_error(cards, 0, |card| {
                card.selected_artifact_path = "wrong.gguf".to_string()
            }),
        ),
        (
            "bad_byte_envelope",
            card_error(cards, 0, |card| card.envelope.selected_artifact_bytes += 1),
        ),
        (
            "bad_hardware_tier",
            card_error(cards, 0, |card| {
                card.hardware_tier = agent_core::uas::HardwareTier::ServerGpuResearch
            }),
        ),
        (
            "bad_runtime_lane",
            card_error(cards, 0, |card| {
                card.runtime_lane = agent_core::uas::ModelCatalogRuntimeLane::CudaBlackwell
            }),
        ),
        (
            "bad_intake_state",
            card_error(cards, 0, |card| {
                card.state = OwnerPathManifestIntakeState::ServerOnlyManifestIntakeDenied
            }),
        ),
        (
            "bad_action",
            card_error(cards, 0, |card| {
                card.action = agent_core::uas::OwnerPathManifestIntakeAction::DenyMacManifestIntake
            }),
        ),
        (
            "missing_required_manifest_field",
            card_error(cards, 0, |card| card.required_fields.no_promotion = false),
        ),
        (
            "server_manifest_contract_enabled",
            card_error(cards, 3, |card| {
                card.required_fields =
                    agent_core::uas::OwnerPathManifestRequiredFields::all_required()
            }),
        ),
        (
            "owner_manifest_present",
            card_error(cards, 0, |card| card.owner_manifest_present = true),
        ),
        (
            "owner_signature_present",
            card_error(cards, 0, |card| card.owner_signature_present = true),
        ),
        (
            "owner_manifest_digest_bound",
            card_error(cards, 0, |card| card.owner_manifest_digest_bound = true),
        ),
        (
            "path_canonicalization_allowed",
            card_error(cards, 0, |card| card.path_canonicalization_allowed = true),
        ),
        (
            "path_canonicalized",
            card_error(cards, 0, |card| card.path_canonicalized = true),
        ),
        (
            "file_open_allowed",
            card_error(cards, 0, |card| card.file_open_allowed = true),
        ),
        (
            "file_stat_allowed",
            card_error(cards, 0, |card| card.file_stat_allowed = true),
        ),
        (
            "file_hash_allowed",
            card_error(cards, 0, |card| card.file_hash_allowed = true),
        ),
        (
            "symlink_resolution_allowed",
            card_error(cards, 0, |card| card.symlink_resolution_allowed = true),
        ),
        (
            "command_armed",
            card_error(cards, 0, |card| card.command_armed = true),
        ),
        (
            "command_executed",
            card_error(cards, 0, |card| {
                card.byte_ledger.command_execution_count = 1
            }),
        ),
        (
            "runtime_probe_allowed",
            card_error(cards, 0, |card| card.runtime_probe_allowed = true),
        ),
        (
            "runtime_not_deferred",
            card_error(cards, 0, |card| card.runtime_deferred = false),
        ),
        (
            "missing_command_visibility",
            card_error(cards, 0, |card| card.command_envelope_visible = false),
        ),
        (
            "missing_rollback",
            card_error(cards, 0, |card| card.rollback_required = false),
        ),
        (
            "missing_run_event_log",
            card_error(cards, 0, |card| card.run_event_log_required = false),
        ),
        (
            "missing_answer_packet",
            card_error(cards, 0, |card| card.answer_packet_required = false),
        ),
        (
            "missing_abstention",
            card_error(cards, 0, |card| card.abstention_required = false),
        ),
        (
            "mas_allowed",
            card_error(cards, 0, |card| card.mas_allowed = true),
        ),
        (
            "product_route_enabled",
            card_error(cards, 0, |card| card.product_route_enabled = true),
        ),
        (
            "app_default_claim",
            card_error(cards, 0, |card| card.app_default_claim = true),
        ),
        (
            "product_winner_claim",
            card_error(cards, 0, |card| card.product_winner_claim = true),
        ),
        (
            "route_policy_mutated",
            card_error(cards, 0, |card| card.route_policy_mutated = true),
        ),
        (
            "hidden_route_authority",
            card_error(cards, 0, |card| card.hidden_route_authority = true),
        ),
        (
            "hidden_cloud_fallback",
            card_error(cards, 0, |card| card.hidden_cloud_fallback = true),
        ),
        (
            "patternboost_authority",
            card_error(cards, 0, |card| card.patternboost_live_authority = true),
        ),
        (
            "lattice_authority",
            card_error(cards, 0, |card| card.lattice_live_authority = true),
        ),
        (
            "eidos_authority",
            card_error(cards, 0, |card| card.eidos_live_authority = true),
        ),
        (
            "l2_l3_promotion",
            card_error(cards, 0, |card| card.l2_l3_promotion_claim = true),
        ),
        (
            "live_dense_70b",
            card_error(cards, 0, |card| card.live_dense_70b_claim = true),
        ),
        (
            "ssd_as_ram",
            card_error(cards, 0, |card| card.ssd_as_ram_claim = true),
        ),
        (
            "source_import_allowed",
            card_error(cards, 0, |card| card.source_import_allowed = true),
        ),
        (
            "benchmark_as_fit_proof",
            card_error(cards, 0, |card| card.benchmark_as_fit_proof = true),
        ),
        (
            "metadata_budget_exceeded",
            ledger_error(cards, |cards| {
                OwnerPathManifestIntakeLedger::new(
                    UasAddress::new(UasKind::Other("test-upstream".to_string()), b"upstream", 1),
                    UPSTREAM_REF,
                    cards.to_vec(),
                    ProductBuild::Pro,
                    ProStatus::ResearchCandidate,
                    CompressedModelPromotionTier::T1L1Metadata,
                    999_999,
                    true,
                    false,
                    true,
                    true,
                    true,
                    true,
                    EXOTIC_QUANT_OWNER_PATH_MANIFEST_INTAKE_GATE_NEXT_CURSOR,
                    CREATED_AT_MS,
                )
            }),
        ),
        (
            "owner_manifest_bytes_read",
            card_error(cards, 0, |card| {
                card.byte_ledger.owner_manifest_bytes_read = 1
            }),
        ),
        (
            "path_canonicalization_attempt",
            card_error(cards, 0, |card| {
                card.byte_ledger.path_canonicalization_attempts = 1
            }),
        ),
        (
            "path_open_attempt",
            card_error(cards, 0, |card| {
                card.byte_ledger.local_path_open_attempts = 1
            }),
        ),
        (
            "file_stat_call",
            card_error(cards, 0, |card| card.byte_ledger.file_stat_calls = 1),
        ),
        (
            "hash_attempt",
            card_error(cards, 0, |card| card.byte_ledger.file_hash_attempts = 1),
        ),
        (
            "symlink_resolution_attempt",
            card_error(cards, 0, |card| {
                card.byte_ledger.symlink_resolution_attempts = 1
            }),
        ),
        (
            "model_bytes_loaded",
            card_error(cards, 0, |card| card.byte_ledger.model_bytes_loaded = 1),
        ),
        (
            "runtime_bytes_loaded",
            card_error(cards, 0, |card| card.byte_ledger.runtime_bytes_loaded = 1),
        ),
        (
            "provider_call_made",
            card_error(cards, 0, |card| card.byte_ledger.provider_calls_made = 1),
        ),
        (
            "source_tree_bytes_read",
            card_error(cards, 0, |card| card.byte_ledger.source_tree_bytes_read = 1),
        ),
        (
            "product_bytes_copied",
            card_error(cards, 0, |card| card.byte_ledger.product_bytes_copied = 1),
        ),
        (
            "benchmark_run",
            card_error(cards, 0, |card| card.byte_ledger.benchmark_runs = 1),
        ),
        (
            "bad_manifest_schema_ref",
            card_error(cards, 0, |card| {
                card.proof_refs.manifest_schema_ref = "manifest_schema:bad".to_string()
            }),
        ),
        (
            "bad_path_policy_ref",
            card_error(cards, 0, |card| {
                card.proof_refs.path_policy_ref = "path_policy:bad".to_string()
            }),
        ),
        (
            "bad_answer_packet_ref",
            card_error(cards, 0, |card| {
                card.proof_refs.answer_packet_ref = "answer_packet:bad".to_string()
            }),
        ),
        (
            "bad_next_cursor",
            ledger_error(cards, |cards| {
                OwnerPathManifestIntakeLedger::new(
                    UasAddress::new(UasKind::Other("test-upstream".to_string()), b"upstream", 1),
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
                    true,
                    "bad_next_cursor",
                    CREATED_AT_MS,
                )
            }),
        ),
    ]
}

fn vec_error(
    cards: &[OwnerPathManifestIntakeCard],
    mutate: impl FnOnce(&mut Vec<OwnerPathManifestIntakeCard>),
) -> bool {
    let mut mutated = cards.to_vec();
    mutate(&mut mutated);
    build_ledger(
        UasAddress::new(UasKind::Other("test-upstream".to_string()), b"upstream", 1),
        mutated,
    )
    .is_err()
}

fn card_error(
    cards: &[OwnerPathManifestIntakeCard],
    index: usize,
    mutate: impl FnOnce(&mut OwnerPathManifestIntakeCard),
) -> bool {
    let mut mutated = cards.to_vec();
    if let Some(card) = mutated.get_mut(index) {
        mutate(card);
    }
    build_ledger(
        UasAddress::new(UasKind::Other("test-upstream".to_string()), b"upstream", 1),
        mutated,
    )
    .is_err()
}

fn ledger_error(
    cards: &[OwnerPathManifestIntakeCard],
    build: impl FnOnce(
        &[OwnerPathManifestIntakeCard],
    ) -> Result<
        OwnerPathManifestIntakeLedger,
        agent_core::uas::OwnerPathManifestIntakeError,
    >,
) -> bool {
    build(cards).is_err()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_builds_and_keeps_manifest_intake_metadata_only() {
        let artifact = build_artifact().expect("artifact");
        assert!(artifact.overall_pass);
        assert_eq!(
            artifact.measurements["gate_card_count"].value,
            serde_json::json!(5)
        );
        assert_eq!(
            artifact.measurements["owner_manifest_bytes_read_total"].value,
            serde_json::json!(0)
        );
        assert_eq!(
            artifact.measurements["path_canonicalized_count"].value,
            serde_json::json!(0)
        );
        assert_eq!(
            artifact.measurements["next_cursor"].value,
            serde_json::json!("exotic_quant_owner_path_canonicalization_preflight_gate")
        );
        assert_eq!(
            artifact.measurements["red_fixture_rejection_count"].value,
            artifact.measurements["red_fixture_count"].value
        );
    }
}
