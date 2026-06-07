//! `falsify_hardware_tiered_model_catalog_source_card`
//!
//! Metadata-only witness for `F-HardwareTieredModelCatalog-SourceCard`. It
//! folds Gemma/Qwopus/TurboVec/QAT research into hardware-tiered source cards
//! without loading model/runtime bytes, executing runtimes, calling providers,
//! or selecting a product default.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::HARDWARE_TIERED_MODEL_CATALOG_SOURCE_CARD_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    CompressedModelPromotionTier, HardwareTier, HardwareTieredModelCatalog,
    HardwareTieredModelCatalogCard, ModelCatalogByteScope, ModelCatalogFormat,
    ModelCatalogProofRefs, ModelCatalogRole, ModelCatalogRuntimeLane, ModelCatalogSourceAuthority,
    ProStatus, ProductBuild, HARDWARE_TIERED_MODEL_CATALOG_SOURCE_CARD_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-HardwareTieredModelCatalog-SourceCard";
const FIXTURE_ID: &str = "hardware_tiered_model_catalog_source_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_hardware_tiered_model_catalog_source_card.sh";
const RESULT: &str = "artifacts/falsifiers/hardware_tiered_model_catalog_source_card/result.json";
const CREATED_AT_MS: u64 = 1_779_220_000_000;
const CATALOG_METADATA_BYTES: u64 = 220_000;
const UPSTREAM_REF: &str =
    "artifact:falsifiers/kv_source_card_fork_and_daemon_boundary/result.json#F-KVSourceCard-ForkAndDaemonBoundary";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/kv_source_card_fork_and_daemon_boundary/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} catalog_card_count={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["catalog_card_count"].value,
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
    let upstream_pass = upstream_kv_boundary_pass();
    let cards = accepted_cards();
    let catalog = build_catalog(cards.clone())?;
    let reversed = build_catalog(cards.iter().cloned().rev().collect())?;
    let metrics = catalog.metrics();
    let red_results = red_fixture_results(&cards);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        ("upstream_kv_boundary_pass", upstream_pass),
        (
            "accepted_catalog_pack_present",
            has_model(&cards, "google/gemma-4-E2B-it-qat-q4_0-gguf")
                && has_model(&cards, "google/gemma-4-12B-it-qat-q4_0-gguf")
                && has_model(&cards, "Jackrong/Qwopus3.5-27B-v3-GGUF")
                && has_model(&cards, "YTan2000/Qwopus3.5-27B-v3-TQ3_4S")
                && has_model(&cards, "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5")
                && has_model(&cards, "samuelcardillo/Qwopus-MoE-35B-A3B-GGUF")
                && has_model(&cards, "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF")
                && has_model(&cards, "nvidia/Gemma-4-31B-IT-NVFP4")
                && has_model(&cards, "Intel/gemma-4-31B-it-int4-AutoRound"),
        ),
        ("hardware_tiers_covered", metrics.hardware_tier_count >= 4),
        ("runtime_lanes_covered", metrics.runtime_lane_count >= 4),
        ("formats_covered", metrics.format_count >= 6),
        ("roles_covered", metrics.role_count >= 5),
        (
            "source_metadata_bound",
            cards.iter().all(|card| {
                card.source_url.starts_with("https://huggingface.co/")
                    && card.source_sha.len() == 40
                    && !card.license_ref.is_empty()
            }) && red_pass(&red_results, "bad_hf_source")
                && red_pass(&red_results, "bad_source_sha"),
        ),
        (
            "local_downloads_claims_quarantined",
            cards.iter().all(|card| {
                card.local_research_claim_only
                    && card
                        .local_research_ref
                        .as_deref()
                        .is_some_and(|value| value.starts_with("local_downloads:"))
                    && !card.product_route_enabled
            }) && red_pass(&red_results, "missing_local_research_ref")
                && red_pass(&red_results, "local_research_claim_not_quarantined")
                && red_pass(&red_results, "declared_bytes_without_quarantine"),
        ),
        (
            "model_roles_bound",
            metrics.role_count >= 5 && red_pass(&red_results, "unknown_model_id"),
        ),
        (
            "gemma_e2b_small_harness_only",
            cards.iter().any(|card| {
                card.model_id == "google/gemma-4-E2B-it-qat-q4_0-gguf"
                    && card.role == ModelCatalogRole::SmallHarness
            }) && red_pass(&red_results, "gemma12b_small_harness"),
        ),
        (
            "gemma_12b_pro_gated",
            cards.iter().any(|card| {
                card.model_id == "google/gemma-4-12B-it-qat-q4_0-gguf"
                    && card.role == ModelCatalogRole::ProGatedFlagship
                    && card.headroom_caveat_ref.is_some()
            }),
        ),
        (
            "qwopus_27b_headroom_caveated",
            cards.iter().any(|card| {
                card.model_id == "Jackrong/Qwopus3.5-27B-v3-GGUF"
                    && card.headroom_caveat_ref.is_some()
            }) && red_pass(&red_results, "qwopus27b_no_headroom_caveat"),
        ),
        (
            "moe_full_weight_truth_required",
            metrics.moe_truth_required_count >= 2
                && red_pass(&red_results, "moe_no_active_params_truth"),
        ),
        (
            "exotic_quant_provenance_required",
            metrics.exotic_quant_count >= 5 && red_pass(&red_results, "exotic_quant_no_gate"),
        ),
        (
            "gpu_only_not_mac_default",
            metrics.gpu_only_count >= 2
                && red_pass(&red_results, "nvfp4_mac_default")
                && red_pass(&red_results, "autoround_mac_runtime"),
        ),
        (
            "no_model_default_or_winner",
            catalog.no_default_model_or_winner
                && red_pass(&red_results, "product_default_claim")
                && red_pass(&red_results, "product_winner_claim"),
        ),
        (
            "proof_refs_bound",
            cards.iter().all(|card| proof_refs_bound(&card.proof_refs))
                && red_pass(&red_results, "bad_proof_ref_prefix"),
        ),
        (
            "zero_model_runtime_provider_source_product_command_bytes",
            metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.source_tree_bytes_read == 0
                && metrics.product_files_copied == 0
                && metrics.command_executions == 0
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_call_made")
                && red_pass(&red_results, "source_tree_bytes_read")
                && red_pass(&red_results, "product_file_copied")
                && red_pass(&red_results, "command_execution"),
        ),
        (
            "zero_command_and_benchmark_execution",
            metrics.command_executions == 0
                && metrics.benchmark_runs == 0
                && red_pass(&red_results, "command_execution")
                && red_pass(&red_results, "benchmark_run"),
        ),
        (
            "no_l2_l3_live70b_ssd_hidden",
            red_pass(&red_results, "l2_l3_promotion_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim")
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "hidden_cloud_fallback"),
        ),
        (
            "catalog_address_deterministic",
            catalog.catalog_address == reversed.catalog_address,
        ),
        (
            "next_cursor_bound",
            HARDWARE_TIERED_MODEL_CATALOG_SOURCE_CARD_NEXT_CURSOR
                == "moe_active_params_memory_truth",
        ),
    ] {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            pass,
        );
    }

    for (name, pass) in &red_results {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            *pass,
        );
    }

    for (name, value, operator, threshold, unit) in [
        ("catalog_card_count", metrics.card_count, ">=", 9, "count"),
        (
            "hardware_tier_count",
            metrics.hardware_tier_count,
            ">=",
            4,
            "count",
        ),
        (
            "runtime_lane_count",
            metrics.runtime_lane_count,
            ">=",
            4,
            "count",
        ),
        ("format_count", metrics.format_count, ">=", 6, "count"),
        ("role_count", metrics.role_count, ">=", 5, "count"),
        (
            "local_research_claim_count",
            metrics.local_research_claim_count,
            "==",
            9,
            "count",
        ),
        (
            "exotic_quant_count",
            metrics.exotic_quant_count,
            ">=",
            5,
            "count",
        ),
        (
            "moe_truth_required_count",
            metrics.moe_truth_required_count,
            ">=",
            2,
            "count",
        ),
        ("gpu_only_count", metrics.gpu_only_count, ">=", 2, "count"),
        (
            "red_fixture_count",
            red_results.len() as u64,
            ">=",
            30,
            "count",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            "==",
            red_results.len() as u64,
            "count",
        ),
        (
            "metadata_bytes_read",
            metrics.metadata_bytes_read,
            "<=",
            96 * 1024,
            "bytes",
        ),
        (
            "local_research_bytes_read",
            metrics.local_research_bytes_read,
            "<=",
            48 * 1024,
            "bytes",
        ),
        (
            "declared_artifact_bytes_total",
            metrics.declared_artifact_bytes_total,
            ">=",
            9,
            "bytes",
        ),
        (
            "declared_uma_floor_bytes_total",
            metrics.declared_uma_floor_bytes_total,
            ">=",
            9,
            "bytes",
        ),
        (
            "model_bytes_loaded_total",
            metrics.model_bytes_loaded,
            "==",
            0,
            "bytes",
        ),
        (
            "runtime_bytes_loaded_total",
            metrics.runtime_bytes_loaded,
            "==",
            0,
            "bytes",
        ),
        (
            "provider_calls_made_total",
            metrics.provider_calls_made,
            "==",
            0,
            "count",
        ),
        (
            "command_executions_total",
            metrics.command_executions,
            "==",
            0,
            "count",
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            value,
            operator,
            threshold,
            unit,
        );
    }

    measurements.insert(
        "hardware_tiered_catalog_address".to_string(),
        Measurement {
            value: serde_json::json!(catalog.address()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "hardware_tiered_catalog_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("hardware_tiered_model_catalog_source_card:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "hardware_tiered_catalog_address".to_string(),
        catalog
            .address()
            .starts_with("hardware_tiered_model_catalog_source_card:")
            && catalog.address().contains('@'),
    );
    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(HARDWARE_TIERED_MODEL_CATALOG_SOURCE_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("moe_active_params_memory_truth"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        HARDWARE_TIERED_MODEL_CATALOG_SOURCE_CARD_NEXT_CURSOR == "moe_active_params_memory_truth",
    );

    for axis in HARDWARE_TIERED_MODEL_CATALOG_SOURCE_CARD_AXES {
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
        anomalies: vec![serde_json::json!({
            "kind": "scope_guard",
            "detail": "metadata-only hardware-tiered model catalog; no model bytes, runtime bytes, provider calls, source-tree bytes, product copies, commands, benchmarks, product default, L2/L3 promotion, live dense 70B, or SSD-as-RAM claim"
        })],
        notes: "Builds F-HardwareTieredModelCatalog-SourceCard from the KV fork/daemon boundary plus June 6 local/online model research. Gemma 4 E2B becomes a small-harness candidate only, Gemma 4 12B QAT becomes Pro Gated target only, Qwopus 27B stays headroom-caveated, MoE rows require active-params/full-weight memory truth, exotic quant rows require provenance gates, and GPU-only rows are denied as Mac defaults.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn upstream_kv_boundary_pass() -> bool {
    let Ok(bytes) = read_repo_relative(UPSTREAM_RESULT) else {
        return false;
    };
    let Ok(value) = serde_json::from_slice::<serde_json::Value>(&bytes) else {
        return false;
    };
    value
        .get("falsifier_id")
        .and_then(serde_json::Value::as_str)
        == Some("F-KVSourceCard-ForkAndDaemonBoundary")
        && value
            .get("overall_pass")
            .and_then(serde_json::Value::as_bool)
            == Some(true)
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

fn build_catalog(
    cards: Vec<HardwareTieredModelCatalogCard>,
) -> Result<HardwareTieredModelCatalog, agent_core::uas::HardwareTieredModelCatalogError> {
    HardwareTieredModelCatalog::new(
        UPSTREAM_REF,
        cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        CompressedModelPromotionTier::T1L1Metadata,
        CATALOG_METADATA_BYTES,
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

fn has_model(cards: &[HardwareTieredModelCatalogCard], model_id: &str) -> bool {
    cards.iter().any(|card| card.model_id == model_id)
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(result_name, _)| *result_name == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn proof_refs_bound(refs: &ModelCatalogProofRefs) -> bool {
    refs.falsifier_ref.starts_with("falsifier:")
        && refs.rollback_ref.starts_with("rollback:")
        && refs.run_event_log_ref.starts_with("run_event_log:")
        && refs.answer_packet_ref.starts_with("answer_packet:")
        && refs.compatibility_fence_ref.starts_with("compat:")
        && refs.privacy_policy_ref.starts_with("privacy:")
        && refs.provenance_ref.starts_with("provenance:")
        && refs.hardware_tier_ref.starts_with("hardware:")
}

fn red_fixture_results(cards: &[HardwareTieredModelCatalogCard]) -> Vec<(&'static str, bool)> {
    vec![
        ("empty_catalog", build_catalog(Vec::new()).is_err()),
        (
            "duplicate_card_id",
            reject_cards(cards, |cards| cards[1].card_id = cards[0].card_id.clone()),
        ),
        (
            "duplicate_model_id",
            reject_cards(cards, |cards| cards[1].model_id = cards[0].model_id.clone()),
        ),
        (
            "unknown_model_id",
            reject_cards(cards, |cards| {
                cards[0].model_id = "unknown/model".to_string();
            }),
        ),
        (
            "bad_upstream_ref",
            HardwareTieredModelCatalog::new(
                "artifact:falsifiers/unknown/result.json",
                cards.to_vec(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                CompressedModelPromotionTier::T1L1Metadata,
                CATALOG_METADATA_BYTES,
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
        (
            "bad_hf_source",
            reject_card(cards, "gemma4_e2b_qat_gguf", |card| {
                card.source_url = "https://example.com/model".to_string();
            }),
        ),
        (
            "bad_source_sha",
            reject_card(cards, "gemma4_e2b_qat_gguf", |card| {
                card.source_sha = "ABC".to_string();
            }),
        ),
        (
            "missing_local_research_ref",
            reject_card(cards, "qwopus27b_gguf", |card| {
                card.local_research_ref = None;
            }),
        ),
        (
            "local_research_claim_not_quarantined",
            reject_card(cards, "qwopus27b_gguf", |card| {
                card.local_research_claim_only = false;
            }),
        ),
        (
            "source_card_not_required",
            reject_card(cards, "gemma4_12b_qat_gguf", |card| {
                card.source_card_required = false;
            }),
        ),
        (
            "runtime_not_deferred",
            reject_card(cards, "gemma4_12b_qat_gguf", |card| {
                card.runtime_deferred = false;
            }),
        ),
        (
            "mas_product_build",
            reject_card(cards, "gemma4_12b_qat_gguf", |card| {
                card.product_build = ProductBuild::Mas;
            }),
        ),
        (
            "pro_live_status",
            reject_card(cards, "gemma4_12b_qat_gguf", |card| {
                card.pro_status = ProStatus::Live;
            }),
        ),
        (
            "promotion_t2",
            reject_card(cards, "gemma4_12b_qat_gguf", |card| {
                card.promotion_tier = CompressedModelPromotionTier::T2L2Route;
            }),
        ),
        (
            "product_route_enabled",
            reject_card(cards, "gemma4_12b_qat_gguf", |card| {
                card.product_route_enabled = true;
            }),
        ),
        (
            "product_default_claim",
            reject_card(cards, "gemma4_12b_qat_gguf", |card| {
                card.product_default_model_claim = true;
            }),
        ),
        (
            "product_winner_claim",
            reject_card(cards, "qwopus27b_gguf", |card| {
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
            reject_card(cards, "gemma4_31b_int4_autoround", |card| {
                card.hidden_cloud_fallback = true;
            }),
        ),
        (
            "l2_l3_promotion_claim",
            reject_card(cards, "gemma4_12b_qat_gguf", |card| {
                card.l2_l3_promotion_claim = true;
            }),
        ),
        (
            "live_dense_70b_claim",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.live_dense_70b_claim = true;
            }),
        ),
        (
            "ssd_as_ram_claim",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.ssd_as_ram_claim = true;
            }),
        ),
        (
            "model_bytes_loaded",
            reject_card(cards, "gemma4_e2b_qat_gguf", |card| {
                card.byte_scope.model_bytes_loaded = 1;
            }),
        ),
        (
            "runtime_bytes_loaded",
            reject_card(cards, "gemma4_e2b_qat_gguf", |card| {
                card.byte_scope.runtime_bytes_loaded = 1;
            }),
        ),
        (
            "provider_call_made",
            reject_card(cards, "gemma4_e2b_qat_gguf", |card| {
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
            "command_execution",
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
            "gemma12b_small_harness",
            reject_card(cards, "gemma4_12b_qat_gguf", |card| {
                card.role = ModelCatalogRole::SmallHarness;
            }),
        ),
        (
            "qwopus27b_no_headroom_caveat",
            reject_card(cards, "qwopus27b_gguf", |card| {
                card.headroom_caveat_ref = None;
            }),
        ),
        (
            "moe_no_active_params_truth",
            reject_card(cards, "qwopus_moe_35b_a3b_gguf", |card| {
                card.active_params_truth_required = false;
            }),
        ),
        (
            "exotic_quant_no_gate",
            reject_card(cards, "qwopus27b_tq3_4s", |card| {
                card.exotic_quant_provenance_required = false;
            }),
        ),
        (
            "nvfp4_mac_default",
            reject_card(cards, "gemma4_31b_nvfp4", |card| {
                card.hardware_tier = HardwareTier::Mac16To18Gb;
                card.gpu_only = false;
                card.mac_default_denied = false;
            }),
        ),
        (
            "autoround_mac_runtime",
            reject_card(cards, "gemma4_31b_int4_autoround", |card| {
                card.runtime_lane = ModelCatalogRuntimeLane::GgufLlamaCpp;
            }),
        ),
        (
            "declared_bytes_without_quarantine",
            reject_card(cards, "qwopus27b_gguf", |card| {
                card.local_research_ref = None;
                card.byte_scope.declared_artifact_bytes = Some(10);
            }),
        ),
        (
            "bad_proof_ref_prefix",
            reject_card(cards, "gemma4_e2b_qat_gguf", |card| {
                card.proof_refs.answer_packet_ref = "packet:bad".to_string();
            }),
        ),
    ]
}

fn reject_cards(
    cards: &[HardwareTieredModelCatalogCard],
    mutate: impl FnOnce(&mut Vec<HardwareTieredModelCatalogCard>),
) -> bool {
    let mut mutated = cards.to_vec();
    mutate(&mut mutated);
    build_catalog(mutated).is_err()
}

fn reject_card(
    cards: &[HardwareTieredModelCatalogCard],
    card_id: &str,
    mutate: impl FnOnce(&mut HardwareTieredModelCatalogCard),
) -> bool {
    let mut mutated = cards.to_vec();
    if let Some(card) = mutated.iter_mut().find(|card| card.card_id == card_id) {
        mutate(card);
    }
    build_catalog(mutated).is_err()
}

fn accepted_cards() -> Vec<HardwareTieredModelCatalogCard> {
    vec![
        card(
            "gemma4_e2b_qat_gguf",
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            "1894d1fc0a19d86697abd40483f5983c867df03f",
            HardwareTier::Mac16To18Gb,
            ModelCatalogRole::SmallHarness,
            ModelCatalogFormat::Gguf,
            ModelCatalogRuntimeLane::GgufLlamaCpp,
            false,
            false,
            false,
            false,
        ),
        card(
            "gemma4_12b_qat_gguf",
            "google/gemma-4-12B-it-qat-q4_0-gguf",
            "f6e7774e6148da3b7f201e42ba37cf084c1db35f",
            HardwareTier::Mac16To18Gb,
            ModelCatalogRole::ProGatedFlagship,
            ModelCatalogFormat::Gguf,
            ModelCatalogRuntimeLane::GgufLlamaCpp,
            false,
            false,
            false,
            true,
        ),
        card(
            "qwopus27b_gguf",
            "Jackrong/Qwopus3.5-27B-v3-GGUF",
            "f99664710e7bc973c877106217cbc600cea2facd",
            HardwareTier::Mac16To18Gb,
            ModelCatalogRole::CodingReasoningCandidate,
            ModelCatalogFormat::Gguf,
            ModelCatalogRuntimeLane::GgufLlamaCpp,
            false,
            false,
            false,
            true,
        ),
        card(
            "qwopus27b_tq3_4s",
            "YTan2000/Qwopus3.5-27B-v3-TQ3_4S",
            "d1f4ed7d1c610cfac430c244d456af6aeac442ce",
            HardwareTier::Mac16To18Gb,
            ModelCatalogRole::ExoticQuantCandidate,
            ModelCatalogFormat::Tq3_4s,
            ModelCatalogRuntimeLane::NoRuntime,
            false,
            true,
            false,
            true,
        ),
        card(
            "qwopus27b_hlwq_q5",
            "caiovicentino1/Qwopus3.5-27B-v3-HLWQ-Q5",
            "f744e234acfbf2a281eb916424bbaaf914e70329",
            HardwareTier::Mac24To32Gb,
            ModelCatalogRole::ExoticQuantCandidate,
            ModelCatalogFormat::HlwqQ5,
            ModelCatalogRuntimeLane::NoRuntime,
            false,
            true,
            false,
            true,
        ),
        card(
            "qwopus_moe_35b_a3b_gguf",
            "samuelcardillo/Qwopus-MoE-35B-A3B-GGUF",
            "19f9e6fa8065b2f1e42aaa16d4adafac1e9a9a01",
            HardwareTier::Mac24To32Gb,
            ModelCatalogRole::MoeAgenticCandidate,
            ModelCatalogFormat::Gguf,
            ModelCatalogRuntimeLane::GgufLlamaCpp,
            true,
            false,
            false,
            true,
        ),
        card(
            "qwopus_moe_35b_a3b_apex_gguf",
            "mudler/Qwopus-MoE-35B-A3B-APEX-GGUF",
            "724281f1f6af99158ae89cba4196f39ccc4e039e",
            HardwareTier::Mac24To32Gb,
            ModelCatalogRole::MoeAgenticCandidate,
            ModelCatalogFormat::ApexGguf,
            ModelCatalogRuntimeLane::NoRuntime,
            true,
            true,
            false,
            true,
        ),
        card(
            "gemma4_31b_nvfp4",
            "nvidia/Gemma-4-31B-IT-NVFP4",
            "e5ef03afa233c35cb000323ff098d4291e1dd07c",
            HardwareTier::CudaBlackwellOnly,
            ModelCatalogRole::GpuServerOnly,
            ModelCatalogFormat::Nvfp4,
            ModelCatalogRuntimeLane::CudaBlackwell,
            false,
            true,
            true,
            true,
        ),
        card(
            "gemma4_31b_int4_autoround",
            "Intel/gemma-4-31B-it-int4-AutoRound",
            "a428c96a57976947b0f12735f0cf5fcae69019ad",
            HardwareTier::ServerGpuResearch,
            ModelCatalogRole::GpuServerOnly,
            ModelCatalogFormat::AutoRoundInt4,
            ModelCatalogRuntimeLane::VllmServer,
            false,
            true,
            true,
            true,
        ),
    ]
}

#[allow(clippy::too_many_arguments)]
fn card(
    card_id: &str,
    model_id: &str,
    source_sha: &str,
    hardware_tier: HardwareTier,
    role: ModelCatalogRole,
    format: ModelCatalogFormat,
    runtime_lane: ModelCatalogRuntimeLane,
    active_params_truth_required: bool,
    exotic_quant_provenance_required: bool,
    gpu_only: bool,
    needs_headroom_caveat: bool,
) -> HardwareTieredModelCatalogCard {
    HardwareTieredModelCatalogCard {
        card_id: card_id.to_string(),
        model_id: model_id.to_string(),
        source_url: format!("https://huggingface.co/{model_id}"),
        source_sha: source_sha.to_string(),
        license_ref: "license:source-card-required".to_string(),
        local_research_ref: Some("local_downloads:locals.md+locals2.md".to_string()),
        hardware_tier,
        role,
        format,
        runtime_lane,
        source_authority: if exotic_quant_provenance_required {
            ModelCatalogSourceAuthority::QuarantineForkMetadata
        } else {
            ModelCatalogSourceAuthority::CurrentHfMetadata
        },
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
        loader_caveat_ref: Some("compat:loader-proof-required".to_string()),
        headroom_caveat_ref: needs_headroom_caveat
            .then(|| "hardware:headroom-not-runtime-proof".to_string()),
        kv_caveat_ref: Some("compat:kv-budget-not-proven".to_string()),
        active_params_truth_required,
        exotic_quant_provenance_required,
        gpu_only,
        mac_default_denied: gpu_only,
        local_research_claim_only: true,
        source_card_required: true,
        runtime_deferred: true,
        product_route_enabled: false,
        product_default_model_claim: false,
        product_winner_claim: false,
        hidden_route_authority: false,
        hidden_cloud_fallback: false,
        l2_l3_promotion_claim: false,
        live_dense_70b_claim: false,
        ssd_as_ram_claim: false,
        byte_scope: ModelCatalogByteScope::metadata_only(10_000, 4_000, Some(1), Some(1)),
        proof_refs: ModelCatalogProofRefs {
            falsifier_ref: "falsifier:F-HardwareTieredModelCatalog-SourceCard".to_string(),
            rollback_ref: "rollback:remove-catalog-row-and-abstain".to_string(),
            run_event_log_ref: "run_event_log:catalog-metadata-only".to_string(),
            answer_packet_ref: "answer_packet:catalog-visible-proof-required".to_string(),
            compatibility_fence_ref: "compat:runtime-lane-proof-required".to_string(),
            privacy_policy_ref: "privacy:no-provider-call-no-cloud-fallback".to_string(),
            provenance_ref: "provenance:source-card-required-before-import".to_string(),
            hardware_tier_ref: "hardware:tier-is-candidate-not-fit-proof".to_string(),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_builds_with_rejected_red_fixtures() {
        let artifact = build_artifact().expect("artifact");
        assert!(artifact.overall_pass);
        assert_eq!(
            artifact.measurements["catalog_card_count"].value,
            serde_json::json!(9)
        );
        assert_eq!(
            artifact.measurements["red_fixture_rejection_count"].value,
            artifact.measurements["red_fixture_count"].value
        );
    }
}
