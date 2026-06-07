//! `falsify_exotic_quant_quarantine_route_card`
//!
//! Metadata-only witness for `F-ExoticQuantQuarantineRouteCard`. It quarantines
//! exotic compression/model rows before they can influence RuntimeRouter/System
//! G, while preserving them as research-to-build material.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::EXOTIC_QUANT_QUARANTINE_ROUTE_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    CompressedModelPromotionTier, ExoticQuantAllowedAction, ExoticQuantImportMode,
    ExoticQuantQuarantineByteScope, ExoticQuantQuarantineClass, ExoticQuantQuarantineProofRefs,
    ExoticQuantQuarantineRouteCard, ExoticQuantQuarantineRouteLedger, HardwareTier,
    ModelCatalogFormat, ModelCatalogRuntimeLane, ProStatus, ProductBuild,
    EXOTIC_QUANT_QUARANTINE_ROUTE_CARD_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-ExoticQuantQuarantineRouteCard";
const FIXTURE_ID: &str = "exotic_quant_quarantine_route_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_exotic_quant_quarantine_route_card.sh";
const RESULT: &str = "artifacts/falsifiers/exotic_quant_quarantine_route_card/result.json";
const CREATED_AT_MS: u64 = 1_779_240_000_000;
const LEDGER_METADATA_BYTES: u64 = 220_000;
const UPSTREAM_CATALOG_REF: &str =
    "artifact:falsifiers/hardware_tiered_model_catalog_source_card/result.json#F-HardwareTieredModelCatalog-SourceCard";
const UPSTREAM_MOE_REF: &str =
    "artifact:falsifiers/moe_active_params_memory_truth/result.json#F-MoEActiveParamsMemoryTruth";
const UPSTREAM_CATALOG_RESULT: &str =
    "artifacts/falsifiers/hardware_tiered_model_catalog_source_card/result.json";
const UPSTREAM_MOE_RESULT: &str = "artifacts/falsifiers/moe_active_params_memory_truth/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} exotic_route_card_count={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["exotic_route_card_count"].value,
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
    let upstream_catalog_pass = upstream_hardware_catalog_pass();
    let upstream_moe_pass = upstream_moe_memory_truth_pass();
    let cards = accepted_cards();
    let ledger = build_ledger(cards.clone())?;
    let reversed = build_ledger(cards.iter().cloned().rev().collect())?;
    let metrics = ledger.metrics();
    let red_results = red_fixture_results(&cards);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, passed) in [
        ("upstream_hardware_catalog_pass", upstream_catalog_pass),
        ("upstream_moe_memory_truth_pass", upstream_moe_pass),
        (
            "accepted_exotic_pack_present",
            has_model(&cards, "YTan2000/Qwopus3.5-27B-v3-TQ3_4S")
                && has_model(&cards, "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5")
                && has_model(&cards, "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF")
                && has_model(&cards, "nvidia/Gemma-4-31B-IT-NVFP4")
                && has_model(&cards, "Intel/gemma-4-31B-it-int4-AutoRound"),
        ),
        (
            "only_exotic_catalog_rows",
            metrics.card_count == 5 && red_pass(&red_results, "non_exotic_row"),
        ),
        (
            "formats_bound",
            metrics.format_count == 5 && red_pass(&red_results, "format_class_mismatch"),
        ),
        (
            "quarantine_classes_bound",
            metrics.quarantine_class_count == 5,
        ),
        (
            "source_urls_bound",
            red_pass(&red_results, "bad_source_url"),
        ),
        (
            "source_shas_bound",
            red_pass(&red_results, "bad_source_sha"),
        ),
        (
            "source_cards_bound",
            metrics.source_card_required_count == metrics.card_count
                && red_pass(&red_results, "missing_source_card"),
        ),
        (
            "provenance_gate_bound",
            metrics.provenance_gate_count == metrics.card_count
                && red_pass(&red_results, "missing_provenance_gate"),
        ),
        (
            "clean_room_or_quarantine_bound",
            metrics.clean_room_or_adapter_path_count == metrics.card_count
                && red_pass(&red_results, "missing_clean_room_path"),
        ),
        (
            "server_rows_no_mac_default",
            metrics.server_only_count == 2
                && metrics.mac_default_denied_count == metrics.card_count
                && red_pass(&red_results, "mac_default_allowed"),
        ),
        (
            "runtime_deferred",
            cards.iter().all(|card| card.runtime_deferred)
                && red_pass(&red_results, "runtime_not_deferred"),
        ),
        (
            "route_authority_denied",
            metrics.route_authority_denied_count == metrics.card_count
                && red_pass(&red_results, "route_authority_enabled"),
        ),
        (
            "product_route_denied",
            cards.iter().all(|card| {
                !card.product_route_enabled
                    && !card.product_default_model_claim
                    && !card.product_winner_claim
            }) && red_pass(&red_results, "product_route_enabled")
                && red_pass(&red_results, "product_default_claim")
                && red_pass(&red_results, "product_winner_claim"),
        ),
        (
            "no_hidden_authority",
            cards
                .iter()
                .all(|card| !card.hidden_route_authority && !card.hidden_cloud_fallback)
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "hidden_cloud_fallback"),
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
            "no_hidden_patternboost_lattice_eidos",
            cards.iter().all(|card| {
                !card.patternboost_live_authority_claim
                    && !card.lattice_live_authority_claim
                    && !card.eidos_live_authority_claim
            }) && red_pass(&red_results, "patternboost_authority")
                && red_pass(&red_results, "lattice_authority")
                && red_pass(&red_results, "eidos_authority"),
        ),
        (
            "no_source_tree_import_or_benchmark_fit",
            cards
                .iter()
                .all(|card| !card.source_tree_import_allowed && !card.benchmark_as_fit_proof)
                && red_pass(&red_results, "source_tree_import_allowed")
                && red_pass(&red_results, "benchmark_as_fit_proof"),
        ),
        (
            "zero_model_runtime_provider_source_product_command_benchmark_bytes",
            metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.source_tree_bytes_read == 0
                && metrics.product_files_copied == 0
                && metrics.command_executions == 0
                && metrics.benchmark_runs == 0
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_call_made")
                && red_pass(&red_results, "source_tree_bytes_read")
                && red_pass(&red_results, "product_file_copied")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "benchmark_run"),
        ),
        (
            "proof_refs_bound",
            cards.iter().all(|card| {
                card.proof_refs.falsifier_ref.starts_with("falsifier:")
                    && card.proof_refs.source_card_ref.starts_with("source_card:")
                    && card.proof_refs.provenance_ref.starts_with("provenance:")
                    && card.proof_refs.clean_room_ref.starts_with("clean_room:")
                    && card.proof_refs.rollback_ref.starts_with("rollback:")
                    && card
                        .proof_refs
                        .run_event_log_ref
                        .starts_with("run_event_log:")
                    && card
                        .proof_refs
                        .answer_packet_ref
                        .starts_with("answer_packet:")
                    && card
                        .proof_refs
                        .compatibility_fence_ref
                        .starts_with("compat:")
                    && card.proof_refs.privacy_policy_ref.starts_with("privacy:")
            }) && red_pass(&red_results, "bad_answer_packet_ref"),
        ),
        (
            "abstention_bound",
            metrics.abstention_ref_count == metrics.card_count
                && red_pass(&red_results, "bad_abstention_ref"),
        ),
        (
            "ledger_address_deterministic",
            ledger.ledger_address == reversed.ledger_address,
        ),
        (
            "next_cursor_bound",
            EXOTIC_QUANT_QUARANTINE_ROUTE_CARD_NEXT_CURSOR
                == "exotic_quant_source_pin_and_byte_budget_preflight",
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

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "exotic_route_card_count",
        metrics.card_count,
        "==",
        5,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "server_only_count",
        metrics.server_only_count,
        "==",
        2,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "format_count",
        metrics.format_count,
        "==",
        5,
        "formats",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "quarantine_class_count",
        metrics.quarantine_class_count,
        "==",
        5,
        "classes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "import_mode_count",
        metrics.import_mode_count,
        ">=",
        2,
        "modes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes_read",
        metrics.metadata_bytes_read,
        ">",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_research_bytes_read",
        metrics.local_research_bytes_read,
        ">",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "declared_source_card_bytes",
        metrics.declared_source_card_bytes,
        ">",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_bytes_loaded_total",
        metrics.model_bytes_loaded,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_bytes_loaded_total",
        metrics.runtime_bytes_loaded,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "provider_calls_made_total",
        metrics.provider_calls_made,
        "==",
        0,
        "calls",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        40,
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
        "exotic_quant_quarantine_address".to_string(),
        Measurement {
            value: serde_json::json!(ledger.ledger_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "exotic_quant_quarantine_address".to_string(),
        AcceptanceThreshold {
            operator: "nonempty".to_string(),
            value: serde_json::json!("exotic_quant_quarantine_route_card"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert("exotic_quant_quarantine_address".to_string(), true);

    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(EXOTIC_QUANT_QUARANTINE_ROUTE_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("exotic_quant_source_pin_and_byte_budget_preflight"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        EXOTIC_QUANT_QUARANTINE_ROUTE_CARD_NEXT_CURSOR
            == "exotic_quant_source_pin_and_byte_budget_preflight",
    );

    for axis in EXOTIC_QUANT_QUARANTINE_ROUTE_CARD_AXES {
        if !measurements.contains_key(*axis) {
            add_bool_axis(
                &mut measurements,
                &mut thresholds,
                &mut pass_per_axis,
                axis,
                false,
            );
        }
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
        notes: "Builds F-ExoticQuantQuarantineRouteCard from the hardware catalog and MoE memory truth witness. TQ3_4S, HLWQ, APEX, NVFP4, and AutoRound rows stay Pro Research/T1 metadata-only: source-carded, provenance-gated, clean-room/quarantine-bound, runtime-deferred, rollbackable, AnswerPacket-visible, and denied as hidden route/default/product authority. Zero model/runtime/provider/source-tree/product/command/benchmark bytes.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_hardware_catalog_pass() -> bool {
    let Ok(bytes) = read_repo_relative(UPSTREAM_CATALOG_RESULT) else {
        return false;
    };
    let Ok(value) = serde_json::from_slice::<serde_json::Value>(&bytes) else {
        return false;
    };
    value
        .get("falsifier_id")
        .and_then(serde_json::Value::as_str)
        .is_some_and(|id| id == "F-HardwareTieredModelCatalog-SourceCard")
        && value
            .get("overall_pass")
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false)
        && value
            .pointer("/measurements/exotic_quant_count/value")
            .and_then(serde_json::Value::as_u64)
            .is_some_and(|count| count == 5)
}

fn upstream_moe_memory_truth_pass() -> bool {
    let Ok(bytes) = read_repo_relative(UPSTREAM_MOE_RESULT) else {
        return false;
    };
    let Ok(value) = serde_json::from_slice::<serde_json::Value>(&bytes) else {
        return false;
    };
    value
        .get("falsifier_id")
        .and_then(serde_json::Value::as_str)
        .is_some_and(|id| id == "F-MoEActiveParamsMemoryTruth")
        && value
            .get("overall_pass")
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false)
        && value
            .pointer("/measurements/next_cursor/value")
            .and_then(serde_json::Value::as_str)
            .is_some_and(|cursor| cursor == "exotic_quant_quarantine_route_card")
}

fn read_repo_relative(path: &str) -> std::io::Result<Vec<u8>> {
    let path = Path::new(path);
    for candidate in [PathBuf::from(path), PathBuf::from("..").join(path)] {
        if candidate.exists() {
            return std::fs::read(candidate);
        }
    }
    std::fs::read(path)
}

fn build_ledger(
    cards: Vec<ExoticQuantQuarantineRouteCard>,
) -> Result<ExoticQuantQuarantineRouteLedger, agent_core::uas::ExoticQuantQuarantineRouteError> {
    ExoticQuantQuarantineRouteLedger::new(
        UPSTREAM_CATALOG_REF,
        UPSTREAM_MOE_REF,
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
        CREATED_AT_MS,
    )
}

fn has_model(cards: &[ExoticQuantQuarantineRouteCard], model_id: &str) -> bool {
    cards.iter().any(|card| card.model_id == model_id)
}

fn red_pass(red_results: &[(&'static str, bool)], name: &str) -> bool {
    red_results
        .iter()
        .any(|(candidate, passed)| *candidate == name && *passed)
}

fn red_fixture_results(cards: &[ExoticQuantQuarantineRouteCard]) -> Vec<(&'static str, bool)> {
    vec![
        ("empty_ledger", build_ledger(Vec::new()).is_err()),
        (
            "duplicate_card_id",
            reject_cards(cards, |cards| cards.push(cards[0].clone())),
        ),
        (
            "duplicate_model_id",
            reject_cards(cards, |cards| {
                let mut duplicate = cards[0].clone();
                duplicate.card_id = "duplicate_model".to_string();
                cards.push(duplicate);
            }),
        ),
        (
            "non_exotic_row",
            reject_cards(cards, |cards| {
                cards[0].model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string();
                cards[0].source_url =
                    "https://huggingface.co/google/gemma-4-12B-it-qat-q4_0-gguf".to_string();
            }),
        ),
        (
            "bad_source_url",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.source_url = "https://example.com/not-hf".to_string();
            }),
        ),
        (
            "bad_source_sha",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.source_sha = "D1F4ED7D1C610CFAC430C244D456AF6AEAC442CE".to_string();
            }),
        ),
        (
            "format_class_mismatch",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.quarantine_class = ExoticQuantQuarantineClass::AutoRoundServerInt4;
            }),
        ),
        (
            "missing_source_card",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.source_card_required = false;
            }),
        ),
        (
            "missing_provenance_gate",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.provenance_gate_required = false;
            }),
        ),
        (
            "missing_clean_room_path",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.clean_room_or_adapter_path_required = false;
            }),
        ),
        (
            "runtime_not_deferred",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.runtime_deferred = false;
            }),
        ),
        (
            "route_authority_enabled",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.route_authority_denied = false;
            }),
        ),
        (
            "mac_default_allowed",
            reject_card(cards, "gemma4_31b_nvfp4", |card| {
                card.mac_default_denied = false;
            }),
        ),
        (
            "mas_product_build",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.product_build = ProductBuild::Mas;
            }),
        ),
        (
            "pro_live_status",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.pro_status = ProStatus::Live;
            }),
        ),
        (
            "promotion_t2",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.promotion_tier = CompressedModelPromotionTier::T2L2Route;
            }),
        ),
        (
            "product_route_enabled",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.product_route_enabled = true;
            }),
        ),
        (
            "product_default_claim",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.product_default_model_claim = true;
            }),
        ),
        (
            "product_winner_claim",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.product_winner_claim = true;
            }),
        ),
        (
            "hidden_route_authority",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.hidden_route_authority = true;
            }),
        ),
        (
            "hidden_cloud_fallback",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.hidden_cloud_fallback = true;
            }),
        ),
        (
            "l2_l3_promotion",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.l2_l3_promotion_claim = true;
            }),
        ),
        (
            "live_dense_70b",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.live_dense_70b_claim = true;
            }),
        ),
        (
            "ssd_as_ram",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.ssd_as_ram_claim = true;
            }),
        ),
        (
            "patternboost_authority",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.patternboost_live_authority_claim = true;
            }),
        ),
        (
            "lattice_authority",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.lattice_live_authority_claim = true;
            }),
        ),
        (
            "eidos_authority",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.eidos_live_authority_claim = true;
            }),
        ),
        (
            "source_tree_import_allowed",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.source_tree_import_allowed = true;
            }),
        ),
        (
            "benchmark_as_fit_proof",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.benchmark_as_fit_proof = true;
            }),
        ),
        (
            "runtime_lane_enabled",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.runtime_lane_enabled = true;
            }),
        ),
        (
            "app_headroom_claim",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.app_headroom_claim = true;
            }),
        ),
        (
            "model_bytes_loaded",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.byte_scope.model_bytes_loaded = 1;
            }),
        ),
        (
            "runtime_bytes_loaded",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.byte_scope.runtime_bytes_loaded = 1;
            }),
        ),
        (
            "provider_call_made",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.byte_scope.provider_calls_made = 1;
            }),
        ),
        (
            "source_tree_bytes_read",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.byte_scope.source_tree_bytes_read = 1;
            }),
        ),
        (
            "product_file_copied",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.byte_scope.product_files_copied = 1;
            }),
        ),
        (
            "command_executed",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.byte_scope.command_executions = 1;
            }),
        ),
        (
            "benchmark_run",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.byte_scope.benchmark_runs = 1;
            }),
        ),
        (
            "bad_answer_packet_ref",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.proof_refs.answer_packet_ref = "hidden:packet".to_string();
            }),
        ),
        (
            "bad_abstention_ref",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.proof_refs.abstention_ref = "hidden:abstain".to_string();
            }),
        ),
        (
            "bad_upstream_catalog_ref",
            ExoticQuantQuarantineRouteLedger::new(
                "artifact:falsifiers/other/result.json",
                UPSTREAM_MOE_REF,
                cards.to_vec(),
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
                CREATED_AT_MS,
            )
            .is_err(),
        ),
        (
            "bad_upstream_moe_ref",
            ExoticQuantQuarantineRouteLedger::new(
                UPSTREAM_CATALOG_REF,
                "artifact:falsifiers/other/result.json",
                cards.to_vec(),
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
                CREATED_AT_MS,
            )
            .is_err(),
        ),
    ]
}

fn reject_cards(
    cards: &[ExoticQuantQuarantineRouteCard],
    mutate: impl FnOnce(&mut Vec<ExoticQuantQuarantineRouteCard>),
) -> bool {
    let mut candidate = cards.to_vec();
    mutate(&mut candidate);
    build_ledger(candidate).is_err()
}

fn reject_card(
    cards: &[ExoticQuantQuarantineRouteCard],
    card_id: &str,
    mutate: impl FnOnce(&mut ExoticQuantQuarantineRouteCard),
) -> bool {
    let mut candidate = cards.to_vec();
    if let Some(card) = candidate.iter_mut().find(|card| card.card_id == card_id) {
        mutate(card);
    }
    build_ledger(candidate).is_err()
}

fn accepted_cards() -> Vec<ExoticQuantQuarantineRouteCard> {
    vec![
        card(
            "qwopus27b_tq3_4s",
            "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
            "d1f4ed7d1c610cfac430c244d456af6aeac442ce",
            HardwareTier::Mac16To18Gb,
            ModelCatalogFormat::Tq3_4s,
            ModelCatalogRuntimeLane::NoRuntime,
            ExoticQuantQuarantineClass::TurboQuantLikeGguf,
            ExoticQuantImportMode::CleanRoomRewrite,
            ExoticQuantAllowedAction::ByteBudgetPreflightOnly,
        ),
        card(
            "qwopus27b_hlwq_q5",
            "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5",
            "f744e234acfbf2a281eb916424bbaaf914e70329",
            HardwareTier::Mac24To32Gb,
            ModelCatalogFormat::HlwqQ5,
            ModelCatalogRuntimeLane::NoRuntime,
            ExoticQuantQuarantineClass::HlwqKvCompressed,
            ExoticQuantImportMode::CleanRoomRewrite,
            ExoticQuantAllowedAction::ByteBudgetPreflightOnly,
        ),
        card(
            "qwopus_moe_35b_a3b_apex_gguf",
            "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
            "724281f1f6af99158ae89cba4196f39ccc4e039e",
            HardwareTier::Mac24To32Gb,
            ModelCatalogFormat::ApexGguf,
            ModelCatalogRuntimeLane::NoRuntime,
            ExoticQuantQuarantineClass::ApexMoeGguf,
            ExoticQuantImportMode::CleanRoomRewrite,
            ExoticQuantAllowedAction::ByteBudgetPreflightOnly,
        ),
        card(
            "gemma4_31b_nvfp4",
            "nvidia/Gemma-4-31B-IT-NVFP4",
            "e5ef03afa233c35cb000323ff098d4291e1dd07c",
            HardwareTier::CudaBlackwellOnly,
            ModelCatalogFormat::Nvfp4,
            ModelCatalogRuntimeLane::CudaBlackwell,
            ExoticQuantQuarantineClass::Nvfp4Blackwell,
            ExoticQuantImportMode::ResearchOnly,
            ExoticQuantAllowedAction::ServerResearchOnly,
        ),
        card(
            "gemma4_31b_int4_autoround",
            "Intel/gemma-4-31B-it-int4-AutoRound",
            "a428c96a57976947b0f12735f0cf5fcae69019ad",
            HardwareTier::ServerGpuResearch,
            ModelCatalogFormat::AutoRoundInt4,
            ModelCatalogRuntimeLane::VllmServer,
            ExoticQuantQuarantineClass::AutoRoundServerInt4,
            ExoticQuantImportMode::QuarantineReference,
            ExoticQuantAllowedAction::ServerResearchOnly,
        ),
    ]
}

#[allow(clippy::too_many_arguments)]
fn card(
    card_id: &str,
    model_id: &str,
    source_sha: &str,
    hardware_tier: HardwareTier,
    format: ModelCatalogFormat,
    candidate_runtime_lane: ModelCatalogRuntimeLane,
    quarantine_class: ExoticQuantQuarantineClass,
    import_mode: ExoticQuantImportMode,
    allowed_action: ExoticQuantAllowedAction,
) -> ExoticQuantQuarantineRouteCard {
    ExoticQuantQuarantineRouteCard {
        card_id: card_id.to_string(),
        model_id: model_id.to_string(),
        source_url: format!("https://huggingface.co/{model_id}"),
        source_sha: source_sha.to_string(),
        hardware_tier,
        format,
        candidate_runtime_lane,
        quarantine_class,
        import_mode,
        allowed_action,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
        provenance_gate_required: true,
        clean_room_or_adapter_path_required: true,
        source_card_required: true,
        runtime_deferred: true,
        route_authority_denied: true,
        mac_default_denied: true,
        product_route_enabled: false,
        product_default_model_claim: false,
        product_winner_claim: false,
        hidden_route_authority: false,
        hidden_cloud_fallback: false,
        l2_l3_promotion_claim: false,
        live_dense_70b_claim: false,
        ssd_as_ram_claim: false,
        patternboost_live_authority_claim: false,
        lattice_live_authority_claim: false,
        eidos_live_authority_claim: false,
        source_tree_import_allowed: false,
        benchmark_as_fit_proof: false,
        runtime_lane_enabled: false,
        app_headroom_claim: false,
        byte_scope: ExoticQuantQuarantineByteScope::metadata_only(8_000, 4_000, 1),
        proof_refs: ExoticQuantQuarantineProofRefs {
            upstream_catalog_ref: UPSTREAM_CATALOG_REF.to_string(),
            upstream_moe_memory_truth_ref: UPSTREAM_MOE_REF.to_string(),
            falsifier_ref: "falsifier:F-ExoticQuantQuarantineRouteCard".to_string(),
            source_card_ref: format!("source_card:hf:{model_id}@{source_sha}"),
            provenance_ref: "provenance:quarantine-before-import-or-route".to_string(),
            clean_room_ref: "clean_room:motif-only-before-product-code".to_string(),
            rollback_ref: "rollback:abstain-from-exotic-quant-route".to_string(),
            run_event_log_ref: "run_event_log:exotic-quant-quarantine".to_string(),
            answer_packet_ref: "answer_packet:exotic-quant-visible-caveat".to_string(),
            compatibility_fence_ref: "compat:runtime-loader-proof-required".to_string(),
            privacy_policy_ref: "privacy:no-provider-no-hidden-route".to_string(),
            abstention_ref: "abstention:missing-exotic-quant-runtime-proof".to_string(),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_builds_with_all_red_fixtures_rejected() {
        let artifact = build_artifact().expect("artifact should build");
        assert!(artifact.overall_pass);
        assert_eq!(
            artifact.measurements["exotic_route_card_count"].value,
            serde_json::json!(5)
        );
        assert_eq!(
            artifact.measurements["red_fixture_rejection_count"].value,
            artifact.measurements["red_fixture_count"].value
        );
        assert_eq!(
            artifact.measurements["next_cursor"].value,
            serde_json::json!("exotic_quant_source_pin_and_byte_budget_preflight")
        );
    }
}
