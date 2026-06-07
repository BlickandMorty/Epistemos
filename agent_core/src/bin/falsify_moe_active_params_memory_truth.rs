//! `falsify_moe_active_params_memory_truth`
//!
//! Metadata-only witness for `F-MoEActiveParamsMemoryTruth`. It proves active
//! parameters are compute evidence, not resident-memory proof, before MoE rows
//! can influence RuntimeRouter/System G.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::MOE_ACTIVE_PARAMS_MEMORY_TRUTH_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    CompressedModelPromotionTier, HardwareTier, ModelCatalogFormat, ModelCatalogRuntimeLane,
    MoeActiveParamsMemoryTruthCard, MoeActiveParamsMemoryTruthLedger, MoeExpertResidencyPolicy,
    MoeMemoryByteLedger, MoeMemoryProofRefs, ProStatus, ProductBuild,
    MOE_ACTIVE_PARAMS_MEMORY_TRUTH_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-MoEActiveParamsMemoryTruth";
const FIXTURE_ID: &str = "moe_active_params_memory_truth_v1";
const COMMAND: &str = "Tools/falsifiers/f_moe_active_params_memory_truth.sh";
const RESULT: &str = "artifacts/falsifiers/moe_active_params_memory_truth/result.json";
const CREATED_AT_MS: u64 = 1_779_230_000_000;
const LEDGER_METADATA_BYTES: u64 = 180_000;
const UPSTREAM_REF: &str =
    "artifact:falsifiers/hardware_tiered_model_catalog_source_card/result.json#F-HardwareTieredModelCatalog-SourceCard";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/hardware_tiered_model_catalog_source_card/result.json";
const FOUR_GIB: u64 = 4 * 1024 * 1024 * 1024;

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
        "{FALSIFIER_ID}: overall_pass={} moe_card_count={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["moe_card_count"].value,
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
    let upstream_pass = upstream_hardware_catalog_pass();
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
        ("upstream_hardware_catalog_pass", upstream_pass),
        (
            "accepted_moe_rows_present",
            has_model(&cards, "samuelcardillo/Qwopus-MoE-35B-A3B-GGUF")
                && has_model(&cards, "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF"),
        ),
        (
            "only_moe_catalog_rows",
            metrics.card_count == 2
                && cards.iter().all(|card| {
                    card.model_id.contains("MoE") && card.active_compute_not_memory_fit
                })
                && red_pass(&red_results, "non_moe_row"),
        ),
        (
            "active_params_compute_only",
            metrics.active_compute_only_count == metrics.card_count
                && red_pass(&red_results, "active_params_as_fit_claim")
                && red_pass(&red_results, "active_params_compute_flag_missing"),
        ),
        (
            "total_params_gt_active_params",
            cards
                .iter()
                .all(|card| card.total_params_declared > card.active_params_declared)
                && red_pass(&red_results, "active_params_not_less_than_total"),
        ),
        (
            "full_weight_bytes_bound",
            metrics.full_weight_ledger_count == metrics.card_count
                && red_pass(&red_results, "missing_full_weight_bytes"),
        ),
        (
            "kv_budget_bound",
            metrics.kv_budget_count == metrics.card_count
                && red_pass(&red_results, "missing_kv_budget"),
        ),
        (
            "expert_residency_lease_bound",
            metrics.expert_residency_lease_count == metrics.card_count
                && red_pass(&red_results, "missing_expert_residency_lease"),
        ),
        (
            "router_runtime_workspace_bound",
            metrics.router_workspace_count == metrics.card_count
                && metrics.runtime_workspace_bytes_sum > 0
                && red_pass(&red_results, "missing_router_workspace")
                && red_pass(&red_results, "missing_runtime_workspace"),
        ),
        (
            "app_headroom_bound",
            metrics.app_headroom_count == metrics.card_count
                && red_pass(&red_results, "missing_app_headroom"),
        ),
        (
            "apex_provenance_gate_bound",
            metrics.apex_provenance_count == 1 && red_pass(&red_results, "apex_without_provenance"),
        ),
        (
            "no_16gb_moe_default",
            cards
                .iter()
                .all(|card| card.hardware_tier != HardwareTier::Mac16To18Gb)
                && red_pass(&red_results, "mac16_moe_overclaim"),
        ),
        (
            "product_route_denied",
            cards.iter().all(|card| {
                !card.product_route_enabled
                    && !card.product_default_model_claim
                    && !card.product_winner_claim
                    && card.runtime_deferred
            }) && red_pass(&red_results, "product_route_enabled")
                && red_pass(&red_results, "product_default_claim")
                && red_pass(&red_results, "product_winner_claim"),
        ),
        (
            "no_hidden_authority",
            cards.iter().all(|card| {
                !card.hidden_route_authority
                    && !card.hidden_cloud_fallback
                    && card.route_authority_denied
            }) && red_pass(&red_results, "hidden_route_authority")
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
                    && card.proof_refs.provenance_ref.starts_with("provenance:")
                    && card.proof_refs.hardware_tier_ref.starts_with("hardware:")
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
            MOE_ACTIVE_PARAMS_MEMORY_TRUTH_NEXT_CURSOR == "exotic_quant_quarantine_route_card",
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
        "moe_card_count",
        metrics.card_count,
        "==",
        2,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "total_params_declared_sum",
        metrics.total_params_declared_sum,
        ">",
        metrics.active_params_declared_sum,
        "params",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "full_weight_artifact_bytes_declared_sum",
        metrics.full_weight_artifact_bytes_declared_sum,
        ">",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_cache_budget_bytes_sum",
        metrics.kv_cache_budget_bytes_sum,
        ">",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "app_headroom_bytes_sum",
        metrics.app_headroom_bytes_sum,
        ">=",
        FOUR_GIB * 2,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        30,
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
        "moe_memory_truth_address".to_string(),
        Measurement {
            value: serde_json::json!(ledger.ledger_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "moe_memory_truth_address".to_string(),
        AcceptanceThreshold {
            operator: "nonempty".to_string(),
            value: serde_json::json!("moe_active_params_memory_truth"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert("moe_memory_truth_address".to_string(), true);

    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(MOE_ACTIVE_PARAMS_MEMORY_TRUTH_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("exotic_quant_quarantine_route_card"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        MOE_ACTIVE_PARAMS_MEMORY_TRUTH_NEXT_CURSOR == "exotic_quant_quarantine_route_card",
    );

    for axis in MOE_ACTIVE_PARAMS_MEMORY_TRUTH_AXES {
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
        notes: "Builds F-MoEActiveParamsMemoryTruth from the hardware-tiered catalog. Active parameters are compute evidence only; full weights, KV, expert leases, router/runtime workspace, app headroom, rollback, RunEventLog, AnswerPacket, abstention, and no-hidden-authority proof are separate. Metadata-only: zero model/runtime/provider/source-tree/product/command/benchmark bytes and no L2/L3/live-70B/SSD-as-RAM claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_hardware_catalog_pass() -> bool {
    let Ok(bytes) = read_repo_relative(UPSTREAM_RESULT) else {
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
            .pointer("/measurements/next_cursor/value")
            .and_then(serde_json::Value::as_str)
            .is_some_and(|cursor| cursor == "moe_active_params_memory_truth")
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
    cards: Vec<MoeActiveParamsMemoryTruthCard>,
) -> Result<MoeActiveParamsMemoryTruthLedger, agent_core::uas::MoeActiveParamsMemoryTruthError> {
    MoeActiveParamsMemoryTruthLedger::new(
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
        true,
        CREATED_AT_MS,
    )
}

fn has_model(cards: &[MoeActiveParamsMemoryTruthCard], model_id: &str) -> bool {
    cards.iter().any(|card| card.model_id == model_id)
}

fn red_pass(red_results: &[(&'static str, bool)], name: &str) -> bool {
    red_results
        .iter()
        .any(|(candidate, passed)| *candidate == name && *passed)
}

fn red_fixture_results(cards: &[MoeActiveParamsMemoryTruthCard]) -> Vec<(&'static str, bool)> {
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
            "non_moe_row",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.model_id = "google/gemma-4-12B-it-qat-q4_0-gguf".to_string();
            }),
        ),
        (
            "bad_source_sha",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.source_sha = "ABC".to_string();
            }),
        ),
        (
            "active_params_as_fit_claim",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.active_params_as_fit_claim = true;
            }),
        ),
        (
            "active_params_compute_flag_missing",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.active_compute_not_memory_fit = false;
            }),
        ),
        (
            "active_params_not_less_than_total",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.active_params_declared = card.total_params_declared;
            }),
        ),
        (
            "missing_full_weight_bytes",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.byte_ledger.full_weight_artifact_bytes_declared = 0;
            }),
        ),
        (
            "missing_kv_budget",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.byte_ledger.kv_cache_budget_bytes = 0;
            }),
        ),
        (
            "missing_expert_residency_lease",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.byte_ledger.expert_residency_lease_bytes = 0;
            }),
        ),
        (
            "missing_router_workspace",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.byte_ledger.router_workspace_bytes = 0;
            }),
        ),
        (
            "missing_runtime_workspace",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.byte_ledger.runtime_workspace_bytes = 0;
            }),
        ),
        (
            "missing_app_headroom",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.byte_ledger.app_headroom_bytes = 1;
            }),
        ),
        (
            "mac16_moe_overclaim",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.hardware_tier = HardwareTier::Mac16To18Gb;
            }),
        ),
        (
            "apex_without_provenance",
            reject_card(cards, "qwopus_moe_35b_a3b_apex_gguf", |card| {
                card.apex_provenance_required = false;
            }),
        ),
        (
            "server_benchmark_as_local_fit",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.server_benchmark_as_local_fit_proof = true;
            }),
        ),
        (
            "product_route_enabled",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.product_route_enabled = true;
            }),
        ),
        (
            "product_default_claim",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.product_default_model_claim = true;
            }),
        ),
        (
            "product_winner_claim",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.product_winner_claim = true;
            }),
        ),
        (
            "hidden_route_authority",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.hidden_route_authority = true;
            }),
        ),
        (
            "hidden_cloud_fallback",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.hidden_cloud_fallback = true;
            }),
        ),
        (
            "l2_l3_promotion",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.l2_l3_promotion_claim = true;
            }),
        ),
        (
            "live_dense_70b",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.live_dense_70b_claim = true;
            }),
        ),
        (
            "ssd_as_ram",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.ssd_as_ram_claim = true;
            }),
        ),
        (
            "model_bytes_loaded",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.byte_ledger.model_bytes_loaded = 1;
            }),
        ),
        (
            "runtime_bytes_loaded",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.byte_ledger.runtime_bytes_loaded = 1;
            }),
        ),
        (
            "provider_call_made",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.byte_ledger.provider_calls_made = 1;
            }),
        ),
        (
            "source_tree_bytes_read",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.byte_ledger.source_tree_bytes_read = 1;
            }),
        ),
        (
            "product_file_copied",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.byte_ledger.product_files_copied = 1;
            }),
        ),
        (
            "command_executed",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.byte_ledger.command_executions = 1;
            }),
        ),
        (
            "benchmark_run",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.byte_ledger.benchmark_runs = 1;
            }),
        ),
        (
            "bad_answer_packet_ref",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.proof_refs.answer_packet_ref = "hidden:packet".to_string();
            }),
        ),
        (
            "bad_abstention_ref",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.proof_refs.abstention_ref = "hidden:abstain".to_string();
            }),
        ),
        (
            "bad_upstream_ref",
            MoeActiveParamsMemoryTruthLedger::new(
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
                true,
                CREATED_AT_MS,
            )
            .is_err(),
        ),
    ]
}

fn reject_cards(
    cards: &[MoeActiveParamsMemoryTruthCard],
    mutate: impl FnOnce(&mut Vec<MoeActiveParamsMemoryTruthCard>),
) -> bool {
    let mut candidate = cards.to_vec();
    mutate(&mut candidate);
    build_ledger(candidate).is_err()
}

fn reject_card(
    cards: &[MoeActiveParamsMemoryTruthCard],
    card_id: &str,
    mutate: impl FnOnce(&mut MoeActiveParamsMemoryTruthCard),
) -> bool {
    let mut candidate = cards.to_vec();
    if let Some(card) = candidate.iter_mut().find(|card| card.card_id == card_id) {
        mutate(card);
    }
    build_ledger(candidate).is_err()
}

fn accepted_cards() -> Vec<MoeActiveParamsMemoryTruthCard> {
    vec![
        card(
            "qwopus_moe_35b_a3b_gguf",
            "samuelcardillo/Qwopus-MoE-35B-A3B-GGUF",
            "19f9e6fa8065b2f1e42aaa16d4adafac1e9a9a01",
            ModelCatalogFormat::Gguf,
            ModelCatalogRuntimeLane::GgufLlamaCpp,
            20_000_000_000,
            false,
        ),
        card(
            "qwopus_moe_35b_a3b_apex_gguf",
            "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
            "724281f1f6af99158ae89cba4196f39ccc4e039e",
            ModelCatalogFormat::ApexGguf,
            ModelCatalogRuntimeLane::NoRuntime,
            18_000_000_000,
            true,
        ),
    ]
}

#[allow(clippy::too_many_arguments)]
fn card(
    card_id: &str,
    model_id: &str,
    source_sha: &str,
    format: ModelCatalogFormat,
    runtime_lane: ModelCatalogRuntimeLane,
    full_weight_artifact_bytes_declared: u64,
    apex: bool,
) -> MoeActiveParamsMemoryTruthCard {
    MoeActiveParamsMemoryTruthCard {
        card_id: card_id.to_string(),
        model_id: model_id.to_string(),
        source_sha: source_sha.to_string(),
        hardware_tier: HardwareTier::Mac24To32Gb,
        format,
        runtime_lane,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
        total_params_declared: 35_000_000_000,
        active_params_declared: 3_000_000_000,
        routed_expert_count_total: 256,
        active_experts_per_token: 8,
        shared_expert_count: 1,
        expert_residency_policy: MoeExpertResidencyPolicy::RouteAbstainsUntilRuntimeProof,
        active_compute_not_memory_fit: true,
        full_weight_bytes_required: true,
        kv_budget_required: true,
        expert_residency_lease_required: true,
        router_overhead_required: true,
        app_headroom_required: true,
        source_card_required: true,
        runtime_deferred: true,
        route_authority_denied: true,
        product_route_enabled: false,
        product_default_model_claim: false,
        product_winner_claim: false,
        active_params_as_fit_claim: false,
        fits_target_hardware_claim: false,
        server_benchmark_as_local_fit_proof: false,
        hidden_route_authority: false,
        hidden_cloud_fallback: false,
        l2_l3_promotion_claim: false,
        live_dense_70b_claim: false,
        ssd_as_ram_claim: false,
        apex_provenance_required: apex,
        provenance_gate_ref: apex.then(|| "provenance:apex-import-mode-required".to_string()),
        headroom_caveat_ref: Some("hardware:moe-not-16gb-default".to_string()),
        byte_ledger: MoeMemoryByteLedger::metadata_only(
            12_000,
            6_000,
            full_weight_artifact_bytes_declared,
            3_000_000_000,
            2_000_000_000,
            full_weight_artifact_bytes_declared,
            256_000_000,
            512_000_000,
            FOUR_GIB,
        ),
        proof_refs: MoeMemoryProofRefs {
            upstream_catalog_ref: UPSTREAM_REF.to_string(),
            falsifier_ref: "falsifier:F-MoEActiveParamsMemoryTruth".to_string(),
            rollback_ref: "rollback:abstain-from-moe-route-card".to_string(),
            run_event_log_ref: "run_event_log:moe-memory-truth-metadata".to_string(),
            answer_packet_ref: "answer_packet:moe-memory-truth-visible-caveat".to_string(),
            compatibility_fence_ref: "compat:moe-runtime-proof-required".to_string(),
            privacy_policy_ref: "privacy:no-provider-no-hidden-route".to_string(),
            provenance_ref: "provenance:source-card-before-runtime".to_string(),
            hardware_tier_ref: "hardware:24gb-plus-candidate-not-fit-proof".to_string(),
            abstention_ref: "abstention:missing-runtime-memory-proof".to_string(),
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
            artifact.measurements["moe_card_count"].value,
            serde_json::json!(2)
        );
        assert_eq!(
            artifact.measurements["red_fixture_rejection_count"].value,
            artifact.measurements["red_fixture_count"].value
        );
        assert_eq!(
            artifact.measurements["next_cursor"].value,
            serde_json::json!("exotic_quant_quarantine_route_card")
        );
    }
}
