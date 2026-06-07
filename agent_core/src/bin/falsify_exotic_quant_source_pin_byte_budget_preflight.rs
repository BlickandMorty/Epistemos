//! `falsify_exotic_quant_source_pin_byte_budget_preflight`
//!
//! Metadata-only witness for exact source pins, file-manifest digests, and byte
//! envelopes for quarantined exotic quant rows. It does not download, clone,
//! mmap, load, run, benchmark, or route any model/runtime/source bytes.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::EXOTIC_QUANT_SOURCE_PIN_BYTE_BUDGET_PREFLIGHT_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    CompressedModelPromotionTier, ExoticQuantByteBudgetEnvelope, ExoticQuantMacBudgetTier,
    ExoticQuantPreflightAction, ExoticQuantQuarantineClass, ExoticQuantSourcePinByteBudgetCard,
    ExoticQuantSourcePinByteBudgetLedger, ExoticQuantSourcePinProofRefs, HardwareTier,
    ModelCatalogFormat, ModelCatalogRuntimeLane, ProStatus, ProductBuild,
    EXOTIC_QUANT_SOURCE_PIN_BYTE_BUDGET_PREFLIGHT_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-ExoticQuantSourcePinAndByteBudgetPreflight";
const FIXTURE_ID: &str = "exotic_quant_source_pin_byte_budget_preflight_v1";
const COMMAND: &str = "Tools/falsifiers/f_exotic_quant_source_pin_byte_budget_preflight.sh";
const RESULT: &str =
    "artifacts/falsifiers/exotic_quant_source_pin_byte_budget_preflight/result.json";
const UPSTREAM_RESULT: &str = "artifacts/falsifiers/exotic_quant_quarantine_route_card/result.json";
const UPSTREAM_REF: &str =
    "artifact:falsifiers/exotic_quant_quarantine_route_card/result.json#F-ExoticQuantQuarantineRouteCard";
const CREATED_AT_MS: u64 = 1_779_326_400_000;
const LEDGER_METADATA_BYTES: u64 = 300_000;

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
        "{FALSIFIER_ID}: overall_pass={} source_pin_card_count={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["source_pin_card_count"].value,
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
    let upstream_pass = upstream_quarantine_pass();
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
        ("upstream_exotic_quant_quarantine_pass", upstream_pass),
        (
            "accepted_source_pin_pack_present",
            has_card(&cards, "qwopus27b_tq3_4s")
                && has_card(&cards, "qwopus27b_hlwq_q5")
                && has_card(&cards, "qwopus_moe_35b_a3b_apex_mini")
                && has_card(&cards, "gemma4_31b_nvfp4")
                && has_card(&cards, "gemma4_31b_int4_autoround"),
        ),
        (
            "source_pins_bound",
            cards
                .iter()
                .all(|card| card.proof_refs.source_pin_ref.ends_with(&card.source_sha))
                && red_pass(&red_results, "bad_source_pin_ref"),
        ),
        (
            "licenses_bound",
            cards
                .iter()
                .all(|card| card.license_ref.starts_with("license:")),
        ),
        (
            "manifest_digests_bound",
            metrics.distinct_manifest_digest_count == 5
                && red_pass(&red_results, "bad_manifest_digest"),
        ),
        (
            "tree_file_counts_bound",
            metrics.card_count == 5 && red_pass(&red_results, "bad_tree_file_count"),
        ),
        (
            "tree_byte_totals_bound",
            metrics.declared_tree_bytes_total == 298_121_896_823
                && red_pass(&red_results, "bad_tree_bytes"),
        ),
        (
            "selected_artifact_paths_bound",
            cards.iter().all(|card| {
                !card.envelope.selected_artifact_path.is_empty()
                    && card.envelope.selected_artifact_path != "whole-repo"
            }) && red_pass(&red_results, "bad_selected_path"),
        ),
        (
            "selected_artifact_oids_bound",
            cards
                .iter()
                .all(|card| card.envelope.selected_artifact_oid.len() == 40)
                && red_pass(&red_results, "bad_selected_oid"),
        ),
        (
            "selected_artifact_not_whole_repo_fit_claim",
            cards
                .iter()
                .all(|card| card.selected_artifact_not_whole_repo_claim)
                && red_pass(&red_results, "whole_repo_fit_claim"),
        ),
        (
            "minimum_uma_byte_budget_arithmetic",
            cards.iter().all(|card| {
                let envelope = &card.envelope;
                envelope.minimum_uma_bytes_required
                    == envelope.selected_total_bytes
                        + envelope.runtime_workspace_budget_bytes
                        + envelope.kv_cache_floor_bytes
                        + envelope.app_headroom_bytes
            }) && red_pass(&red_results, "bad_minimum_uma_bytes")
                && red_pass(&red_results, "bad_selected_total_bytes"),
        ),
        (
            "mac_16_18gb_denied",
            metrics.denied_16_to_18gb_mac_count == metrics.card_count
                && red_pass(&red_results, "mac16_allowed"),
        ),
        (
            "mac_24_32gb_preflight_candidates",
            metrics.mac_preflight_candidate_count == 3,
        ),
        (
            "server_only_rows_denied_on_mac",
            metrics.server_only_count == 2 && red_pass(&red_results, "server_row_mac_allowed"),
        ),
        (
            "runtime_deferred",
            cards.iter().all(|card| card.runtime_deferred)
                && red_pass(&red_results, "runtime_not_deferred"),
        ),
        (
            "route_authority_denied",
            cards.iter().all(|card| card.route_authority_denied)
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
                card.proof_refs
                    .source_card_ref
                    .starts_with("source_card:hf:")
                    && card.proof_refs.source_pin_ref.starts_with("source_pin:hf:")
                    && card.proof_refs.manifest_ref.starts_with("manifest:hf:")
                    && card
                        .proof_refs
                        .byte_budget_ref
                        .starts_with("byte_budget:exotic-quant:")
                    && card
                        .proof_refs
                        .answer_packet_ref
                        .starts_with("answer_packet:")
            }) && red_pass(&red_results, "bad_answer_packet_ref"),
        ),
        (
            "abstention_bound",
            cards
                .iter()
                .all(|card| card.proof_refs.abstention_ref.starts_with("abstention:"))
                && red_pass(&red_results, "bad_abstention_ref"),
        ),
        (
            "ledger_address_deterministic",
            ledger.ledger_address == reversed.ledger_address,
        ),
        (
            "next_cursor_bound",
            EXOTIC_QUANT_SOURCE_PIN_BYTE_BUDGET_PREFLIGHT_NEXT_CURSOR
                == "exotic_quant_runtime_lane_owner_approval_gate",
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
        "source_pin_card_count",
        metrics.card_count,
        "==",
        5,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mac_preflight_candidate_count",
        metrics.mac_preflight_candidate_count,
        "==",
        3,
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
        "distinct_manifest_digest_count",
        metrics.distinct_manifest_digest_count,
        "==",
        5,
        "digests",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_artifact_count",
        metrics.selected_artifact_count,
        "==",
        5,
        "artifacts",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "denied_16_to_18gb_mac_count",
        metrics.denied_16_to_18gb_mac_count,
        "==",
        5,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "declared_tree_bytes_total",
        metrics.declared_tree_bytes_total,
        "==",
        298_121_896_823,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_total_bytes_sum",
        metrics.selected_total_bytes_sum,
        "==",
        97_269_645_985,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "maximum_minimum_uma_bytes_required",
        metrics.minimum_uma_bytes_required_max,
        ">=",
        39_108_307_031,
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
        32,
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
        "source_pin_byte_budget_address".to_string(),
        Measurement {
            value: serde_json::json!(ledger.ledger_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "source_pin_byte_budget_address".to_string(),
        AcceptanceThreshold {
            operator: "nonempty".to_string(),
            value: serde_json::json!("exotic_quant_source_pin_and_byte_budget_preflight"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert("source_pin_byte_budget_address".to_string(), true);

    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(EXOTIC_QUANT_SOURCE_PIN_BYTE_BUDGET_PREFLIGHT_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("exotic_quant_runtime_lane_owner_approval_gate"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        EXOTIC_QUANT_SOURCE_PIN_BYTE_BUDGET_PREFLIGHT_NEXT_CURSOR
            == "exotic_quant_runtime_lane_owner_approval_gate",
    );

    for axis in EXOTIC_QUANT_SOURCE_PIN_BYTE_BUDGET_PREFLIGHT_AXES {
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
        notes: "Builds exact source-pin and byte-budget preflight cards for TQ3_4S, HLWQ, APEX, NVFP4, and AutoRound rows. It binds Hugging Face revisions, manifest digests, tree byte totals, selected artifact bytes, Mac/server tier decisions, rollback, RunEventLog, AnswerPacket, and abstention while denying product route authority, live dense 70B, SSD-as-RAM, hidden authority, and all runtime/model/provider/source/product/command/benchmark bytes.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_quarantine_pass() -> bool {
    let Ok(bytes) = read_repo_relative(UPSTREAM_RESULT) else {
        return false;
    };
    let Ok(value) = serde_json::from_slice::<serde_json::Value>(&bytes) else {
        return false;
    };
    value
        .get("falsifier_id")
        .and_then(serde_json::Value::as_str)
        .is_some_and(|id| id == "F-ExoticQuantQuarantineRouteCard")
        && value
            .get("overall_pass")
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false)
        && value
            .pointer("/measurements/next_cursor/value")
            .and_then(serde_json::Value::as_str)
            .is_some_and(|cursor| cursor == "exotic_quant_source_pin_and_byte_budget_preflight")
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
    cards: Vec<ExoticQuantSourcePinByteBudgetCard>,
) -> Result<
    ExoticQuantSourcePinByteBudgetLedger,
    agent_core::uas::ExoticQuantSourcePinByteBudgetError,
> {
    ExoticQuantSourcePinByteBudgetLedger::new(
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
        CREATED_AT_MS,
    )
}

fn has_card(cards: &[ExoticQuantSourcePinByteBudgetCard], card_id: &str) -> bool {
    cards.iter().any(|card| card.card_id == card_id)
}

fn red_pass(red_results: &[(&'static str, bool)], name: &str) -> bool {
    red_results
        .iter()
        .any(|(candidate, passed)| *candidate == name && *passed)
}

fn red_fixture_results(cards: &[ExoticQuantSourcePinByteBudgetCard]) -> Vec<(&'static str, bool)> {
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
            "bad_upstream_quarantine_ref",
            ExoticQuantSourcePinByteBudgetLedger::new(
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
                CREATED_AT_MS,
            )
            .is_err(),
        ),
        (
            "unknown_model",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string();
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
            "bad_source_pin_ref",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.proof_refs.source_pin_ref = "source_pin:hf:wrong".to_string();
            }),
        ),
        (
            "bad_manifest_digest",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.envelope.source_manifest_digest = "bad".to_string();
            }),
        ),
        (
            "bad_tree_file_count",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.envelope.declared_tree_file_count = 0;
            }),
        ),
        (
            "bad_tree_bytes",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.envelope.declared_tree_bytes = card.envelope.selected_total_bytes - 1;
            }),
        ),
        (
            "bad_selected_path",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.envelope.selected_artifact_path = String::new();
            }),
        ),
        (
            "bad_selected_oid",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.envelope.selected_artifact_oid = "bad".to_string();
            }),
        ),
        (
            "bad_selected_total_bytes",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.envelope.selected_total_bytes += 1;
            }),
        ),
        (
            "bad_minimum_uma_bytes",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.envelope.minimum_uma_bytes_required += 1;
            }),
        ),
        (
            "whole_repo_fit_claim",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.selected_artifact_not_whole_repo_claim = false;
            }),
        ),
        (
            "mac16_allowed",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.denies_16_to_18gb_mac = false;
            }),
        ),
        (
            "server_row_mac_allowed",
            reject_card(cards, "gemma4_31b_nvfp4", |card| {
                card.mac_runtime_preflight_allowed = true;
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
            "app_headroom_claim",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.app_headroom_claim = true;
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
            "model_bytes_loaded",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.envelope.model_bytes_loaded = 1;
            }),
        ),
        (
            "runtime_bytes_loaded",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.envelope.runtime_bytes_loaded = 1;
            }),
        ),
        (
            "provider_call_made",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.envelope.provider_calls_made = 1;
            }),
        ),
        (
            "source_tree_bytes_read",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.envelope.source_tree_bytes_read = 1;
            }),
        ),
        (
            "product_file_copied",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.envelope.product_files_copied = 1;
            }),
        ),
        (
            "command_executed",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.envelope.command_executions = 1;
            }),
        ),
        (
            "benchmark_run",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.envelope.benchmark_runs = 1;
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
    ]
}

fn reject_cards(
    cards: &[ExoticQuantSourcePinByteBudgetCard],
    mutate: impl FnOnce(&mut Vec<ExoticQuantSourcePinByteBudgetCard>),
) -> bool {
    let mut candidate = cards.to_vec();
    mutate(&mut candidate);
    build_ledger(candidate).is_err()
}

fn reject_card(
    cards: &[ExoticQuantSourcePinByteBudgetCard],
    card_id: &str,
    mutate: impl FnOnce(&mut ExoticQuantSourcePinByteBudgetCard),
) -> bool {
    let mut candidate = cards.to_vec();
    if let Some(card) = candidate.iter_mut().find(|card| card.card_id == card_id) {
        mutate(card);
    }
    build_ledger(candidate).is_err()
}

fn accepted_cards() -> Vec<ExoticQuantSourcePinByteBudgetCard> {
    vec![
        card(
            "qwopus27b_tq3_4s",
            "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
            "d1f4ed7d1c610cfac430c244d456af6aeac442ce",
            "license:apache-2.0",
            HardwareTier::Mac16To18Gb,
            ModelCatalogFormat::Tq3_4s,
            ModelCatalogRuntimeLane::NoRuntime,
            ExoticQuantQuarantineClass::TurboQuantLikeGguf,
            ExoticQuantMacBudgetTier::Mac24To32GbCandidate,
            ExoticQuantPreflightAction::ByteBudgetPreflightOnly,
            false,
            envelope(
                5,
                14_886_372_874,
                "90f23e959caeb23fad3a157912cfe5a9d8dcf427d1de79314fa231dc2456e717",
                "Qwopus3.5-27B-v3-TQ3_4S.gguf",
                13_954_954_592,
                "18ba8c8a96b97ee397417eb87b866218fe21b642",
                "Qwopus3.5-27B-v3-TQ3_4S.gguf",
                13_954_954_592,
                "18ba8c8a96b97ee397417eb87b866218fe21b642",
                931_146_304,
                1_073_741_824,
                2_147_483_648,
                4_294_967_296,
            ),
        ),
        card(
            "qwopus27b_hlwq_q5",
            "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5",
            "f744e234acfbf2a281eb916424bbaaf914e70329",
            "license:apache-2.0",
            HardwareTier::Mac24To32Gb,
            ModelCatalogFormat::HlwqQ5,
            ModelCatalogRuntimeLane::NoRuntime,
            ExoticQuantQuarantineClass::HlwqKvCompressed,
            ExoticQuantMacBudgetTier::Mac24To32GbCandidate,
            ExoticQuantPreflightAction::ByteBudgetPreflightOnly,
            false,
            envelope(
                11,
                16_180_512_203,
                "964cc46bfff705d2eb07a27c7ad8a5e8ea567ff6c9b2ad6910f70cc441afdd5e",
                "model_int4.pt",
                16_160_373_833,
                "dad58763b56c148e1d72bf92ddc512baa614720a",
                "model_int4.pt",
                16_160_373_833,
                "dad58763b56c148e1d72bf92ddc512baa614720a",
                19_997_618,
                1_073_741_824,
                4_294_967_296,
                4_294_967_296,
            ),
        ),
        card(
            "qwopus_moe_35b_a3b_apex_mini",
            "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
            "724281f1f6af99158ae89cba4196f39ccc4e039e",
            "license:apache-2.0",
            HardwareTier::Mac24To32Gb,
            ModelCatalogFormat::ApexGguf,
            ModelCatalogRuntimeLane::NoRuntime,
            ExoticQuantQuarantineClass::ApexMoeGguf,
            ExoticQuantMacBudgetTier::Mac24To32GbCandidate,
            ExoticQuantPreflightAction::ByteBudgetPreflightOnly,
            false,
            envelope(
                10,
                215_168_111_676,
                "b879e473dc0ab51446f7b4807afdbd69d6cc2314244f9b777e8f625caacfc7b4",
                "Qwopus-MoE-35B-A3B-F16.gguf",
                69_376_638_112,
                "f33bbcd303ecb0c33f7eee4cd7a3e704ac51e42b",
                "Qwopus-MoE-35B-A3B-APEX-I-Mini.gguf",
                14_316_566_624,
                "b2431faaf41202dc904e2a9db73435f0a1ab9afa",
                0,
                2_147_483_648,
                4_294_967_296,
                4_294_967_296,
            ),
        ),
        card(
            "gemma4_31b_nvfp4",
            "nvidia/Gemma-4-31B-IT-NVFP4",
            "e5ef03afa233c35cb000323ff098d4291e1dd07c",
            "license:other",
            HardwareTier::CudaBlackwellOnly,
            ModelCatalogFormat::Nvfp4,
            ModelCatalogRuntimeLane::CudaBlackwell,
            ExoticQuantQuarantineClass::Nvfp4Blackwell,
            ExoticQuantMacBudgetTier::ServerOnlyDeniedOnMac,
            ExoticQuantPreflightAction::ServerResearchOnly,
            true,
            envelope(
                15,
                32_666_144_074,
                "8504e5a5891f298a359d0f52b1ec3aba1f1f67b0e1645a14e208f47f8d04b305",
                "model-00003-of-00004.safetensors",
                9_999_145_338,
                "07ad0d76bdabfa163faca4c6de61b3e948062b74",
                "model.safetensors.index.json",
                32_665_856_087,
                "e414340fced188e5f5ce0a2292cb0a3aa03cd23b",
                0,
                2_147_483_648,
                4_294_967_296,
                0,
            ),
        ),
        card(
            "gemma4_31b_int4_autoround",
            "Intel/gemma-4-31B-it-int4-AutoRound",
            "a428c96a57976947b0f12735f0cf5fcae69019ad",
            "license:unset-source-card-required",
            HardwareTier::ServerGpuResearch,
            ModelCatalogFormat::AutoRoundInt4,
            ModelCatalogRuntimeLane::VllmServer,
            ExoticQuantQuarantineClass::AutoRoundServerInt4,
            ExoticQuantMacBudgetTier::ServerOnlyDeniedOnMac,
            ExoticQuantPreflightAction::ServerResearchOnly,
            true,
            envelope(
                21,
                19_220_755_996,
                "70270f75e9d7617a0b9ec4978f78cc783104c9d636401cc82b0a93215cf44b84",
                "model-00009-of-00010.safetensors",
                2_818_572_416,
                "e16e8a94d437f7846301702dce6c8661eb393fe1",
                "model.safetensors.index.json",
                19_220_750_927,
                "14bfa534cd10918adc3c9e439de3cf5b8fdccf3b",
                0,
                2_147_483_648,
                4_294_967_296,
                0,
            ),
        ),
    ]
}

#[allow(clippy::too_many_arguments)]
fn envelope(
    declared_tree_file_count: u64,
    declared_tree_bytes: u64,
    manifest_digest: &str,
    largest_file_path: &str,
    largest_file_bytes: u64,
    largest_file_oid: &str,
    selected_artifact_path: &str,
    selected_artifact_bytes: u64,
    selected_artifact_oid: &str,
    selected_support_bytes: u64,
    runtime_workspace_budget_bytes: u64,
    kv_cache_floor_bytes: u64,
    app_headroom_bytes: u64,
) -> ExoticQuantByteBudgetEnvelope {
    ExoticQuantByteBudgetEnvelope::metadata_only(
        declared_tree_file_count,
        declared_tree_bytes,
        manifest_digest,
        largest_file_path,
        largest_file_bytes,
        largest_file_oid,
        selected_artifact_path,
        selected_artifact_bytes,
        selected_artifact_oid,
        selected_support_bytes,
        runtime_workspace_budget_bytes,
        kv_cache_floor_bytes,
        app_headroom_bytes,
        14_000,
        4_000,
    )
}

#[allow(clippy::too_many_arguments)]
fn card(
    card_id: &str,
    model_id: &str,
    source_sha: &str,
    license_ref: &str,
    hardware_tier: HardwareTier,
    format: ModelCatalogFormat,
    candidate_runtime_lane: ModelCatalogRuntimeLane,
    quarantine_class: ExoticQuantQuarantineClass,
    mac_budget_tier: ExoticQuantMacBudgetTier,
    action: ExoticQuantPreflightAction,
    server_only: bool,
    envelope: ExoticQuantByteBudgetEnvelope,
) -> ExoticQuantSourcePinByteBudgetCard {
    ExoticQuantSourcePinByteBudgetCard {
        card_id: card_id.to_string(),
        model_id: model_id.to_string(),
        source_url: format!("https://huggingface.co/{model_id}"),
        source_sha: source_sha.to_string(),
        license_ref: license_ref.to_string(),
        hardware_tier,
        format,
        candidate_runtime_lane,
        quarantine_class,
        mac_budget_tier,
        action,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
        source_pin_bound: true,
        file_manifest_bound: true,
        byte_budget_bound: true,
        selected_artifact_not_whole_repo_claim: true,
        denies_16_to_18gb_mac: true,
        mac_runtime_preflight_allowed: !server_only,
        server_only_denied_on_mac: server_only,
        runtime_deferred: true,
        route_authority_denied: true,
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
        app_headroom_claim: false,
        benchmark_as_fit_proof: false,
        runtime_lane_enabled: false,
        envelope,
        proof_refs: ExoticQuantSourcePinProofRefs {
            upstream_quarantine_ref: UPSTREAM_REF.to_string(),
            source_card_ref: format!("source_card:hf:{model_id}@{source_sha}"),
            source_pin_ref: format!("source_pin:hf:{model_id}@{source_sha}"),
            manifest_ref: format!("manifest:hf:{model_id}@{source_sha}"),
            byte_budget_ref: format!("byte_budget:exotic-quant:{card_id}"),
            rollback_ref: "rollback:abstain-from-exotic-runtime-lane".to_string(),
            run_event_log_ref: "run_event_log:exotic-quant-byte-preflight".to_string(),
            answer_packet_ref: "answer_packet:exotic-quant-byte-caveat".to_string(),
            compatibility_fence_ref: "compat:loader-and-runtime-proof-required".to_string(),
            privacy_policy_ref: "privacy:no-provider-no-hidden-route".to_string(),
            abstention_ref: "abstention:missing-owner-approved-runtime-proof".to_string(),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_builds_with_red_fixtures_rejected() {
        let artifact = build_artifact().expect("artifact");
        assert!(artifact.overall_pass);
        assert_eq!(
            artifact.measurements["source_pin_card_count"].value,
            serde_json::json!(5)
        );
        assert_eq!(
            artifact.measurements["red_fixture_rejection_count"].value,
            artifact.measurements["red_fixture_count"].value
        );
        assert_eq!(
            artifact.measurements["next_cursor"].value,
            serde_json::json!("exotic_quant_runtime_lane_owner_approval_gate")
        );
    }
}
