//! `falsify_compressed_model_source_card_intake`
//!
//! Metadata-only witness for `F-CompressedModelSourceCard-Intake`. It binds
//! TurboVec/QAT/GGUF/LiteRT/MLX/runtime research into typed source cards after
//! source-signal, model-inventory, and provenance gates, without loading
//! model/index/runtime bytes or promoting product capability.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    CompressedModelFormat, CompressedModelOrgan, CompressedModelPromotionTier,
    CompressedModelRuntimeLane, CompressedModelSourceByteScope, CompressedModelSourceCard,
    CompressedModelSourceCardIntake, CompressedModelSourceCardKind, CompressedModelSourceProofRefs,
    ModelInventoryByteScope, ModelInventoryCandidateCard, ModelInventoryCandidateSet,
    ModelInventoryClaimLimit, ModelInventoryEvidenceKind, ModelInventoryHashClaim,
    ModelInventoryMetadataStatus, ModelInventoryProofRefs, PrivacyClass, ProStatus, ProductBuild,
    ProprietaryCompressionAllowedAction, ProprietaryCompressionBehaviorKind,
    ProprietaryCompressionByteScope, ProprietaryCompressionExtractedBehavior,
    ProprietaryCompressionImportMode, ProprietaryCompressionLicenseClass,
    ProprietaryCompressionProofRefs, ProprietaryCompressionProvenanceGate,
    ProprietaryCompressionSourceKind, ProprietaryCompressionSourceOverlay, SourceCard,
    SourceNoPoisonStatus, SourceSignalGraph, SourceSignalType,
};

const FALSIFIER_ID: &str = "F-CompressedModelSourceCard-Intake";
const FIXTURE_ID: &str = "compressed_model_source_card_intake_v1";
const COMMAND: &str = "Tools/falsifiers/f_compressed_model_source_card_intake.sh";
const RESULT: &str = "artifacts/falsifiers/compressed_model_source_card_intake/result.json";
const CREATED_AT_MS: u64 = 1_779_034_000_000;
const INTAKE_METADATA_BYTES: u64 = 88_000;

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
        "{FALSIFIER_ID}: overall_pass={} card_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["accepted_fixture_count"].value,
        artifact.measurements["red_fixture_rejection_count"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let graph = source_graph()?;
    let inventory = model_inventory(&graph)?;
    let provenance_gate = provenance_gate(&graph, &inventory)?;
    let cards = accepted_cards(&graph);
    let intake = build_intake(&graph, &inventory, &provenance_gate, cards.clone())?;
    let reversed = build_intake(
        &graph,
        &inventory,
        &provenance_gate,
        cards.iter().cloned().rev().collect(),
    )?;
    let metrics = intake.metrics();
    let red_results = red_fixture_results(&graph, &inventory, &provenance_gate, &cards);

    let accepted_fixture_count = cards.len() as u64;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "source_signal_graph_intake_called_first",
            !graph.source_cards.is_empty(),
        ),
        (
            "model_inventory_candidate_set_bound",
            inventory.source_graph_address == graph.graph_address,
        ),
        (
            "proprietary_compression_provenance_gate_bound",
            provenance_gate.model_inventory_address == inventory.inventory_address,
        ),
        (
            "accepted_fixture_pack_present",
            has_card(&cards, "gemma4_e2b_qat_gguf")
                && has_card(&cards, "gemma4_e4b_mobile_litert")
                && has_card(&cards, "gemma4_12b_qat_gguf")
                && has_card(&cards, "gemma4_12b_mlx_loader_blocked")
                && has_card(&cards, "turbovec_eidos_cache")
                && has_card(&cards, "llama_cpp_runtime_package")
                && has_card(&cards, "litert_lm_runtime_package")
                && has_card(&cards, "mlx_swift_lm_runtime_package")
                && has_card(&cards, "qwen3_coder_mlx")
                && has_card(&cards, "granite_micro_mlx"),
        ),
        ("format_coverage", metrics.format_count >= 5),
        ("runtime_lane_coverage", metrics.runtime_lane_count >= 5),
        ("organ_coverage", metrics.organ_count >= 4),
        ("quantized_cards_present", metrics.quantized_card_count >= 5),
        (
            "runtime_package_cards_present",
            metrics.runtime_package_card_count >= 3,
        ),
        (
            "compressed_index_card_present",
            metrics.compressed_index_card_count >= 1,
        ),
        (
            "inventory_refs_bound",
            metrics.model_inventory_binding_count == accepted_fixture_count,
        ),
        (
            "provenance_overlays_bound",
            metrics.provenance_overlay_binding_count == accepted_fixture_count,
        ),
        (
            "gemma4_mlx_loader_caveat_preserved",
            red_pass(&red_results, "missing_gemma4_loader_caveat")
                && red_pass(&red_results, "mlx_gemma4_loader_claim"),
        ),
        (
            "turbovec_eidos_cache_only",
            red_pass(&red_results, "turbovec_not_eidos_cache"),
        ),
        (
            "gguf_lane_restricted",
            red_pass(&red_results, "gguf_lane_mismatch"),
        ),
        (
            "litert_lane_restricted",
            red_pass(&red_results, "litert_lane_mismatch"),
        ),
        (
            "package_manifest_not_loader_proof",
            red_pass(&red_results, "package_manifest_loader_proof"),
        ),
        (
            "rowid_identity_rejected",
            red_pass(&red_results, "rowid_identity"),
        ),
        (
            "route_authority_rejected",
            red_pass(&red_results, "runtime_route_authority")
                && red_pass(&red_results, "hidden_route_authority"),
        ),
        (
            "product_promotion_rejected",
            red_pass(&red_results, "product_green_from_research")
                && red_pass(&red_results, "tier_promotion_from_research"),
        ),
        (
            "mas_live_rejected",
            red_pass(&red_results, "mas_live_from_research"),
        ),
        (
            "dense_70b_live_claim_rejected",
            red_pass(&red_results, "dense_70b_live_claim"),
        ),
        (
            "ssd_as_ram_claim_rejected",
            red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "hidden_cloud_rejected",
            red_pass(&red_results, "hidden_cloud_fallback"),
        ),
        (
            "zero_model_bytes_loaded",
            metrics.model_bytes_loaded == 0 && red_pass(&red_results, "model_bytes_loaded"),
        ),
        (
            "zero_index_bytes_loaded",
            metrics.index_bytes_loaded == 0 && red_pass(&red_results, "index_bytes_loaded"),
        ),
        (
            "zero_runtime_bytes_loaded",
            metrics.runtime_bytes_loaded == 0 && red_pass(&red_results, "runtime_bytes_loaded"),
        ),
        (
            "zero_provider_calls",
            metrics.provider_calls_made == 0 && red_pass(&red_results, "provider_call_made"),
        ),
        (
            "no_product_file_copy",
            metrics.copied_product_file_count == 0 && red_pass(&red_results, "product_file_copied"),
        ),
        (
            "no_weight_blob_open_or_hash",
            metrics.weight_blob_open_attempt_count == 0
                && metrics.weight_blob_hash_attempt_count == 0
                && red_pass(&red_results, "weight_blob_opened")
                && red_pass(&red_results, "weight_blob_hash_attempted"),
        ),
        (
            "rollback_run_event_answer_packet_refs_present",
            cards.iter().all(|card| {
                card.proof_refs.rollback_ref.starts_with("rollback:")
                    && card
                        .proof_refs
                        .run_event_log_ref
                        .starts_with("run_event_log:")
                    && card
                        .proof_refs
                        .answer_packet_ref
                        .starts_with("answer_packet:")
            }) && red_pass(&red_results, "bad_proof_ref_prefix"),
        ),
        (
            "intake_address_deterministic",
            intake.intake_address == reversed.intake_address,
        ),
        (
            "layer_separation_required",
            red_pass(&red_results, "missing_layer_separation"),
        ),
        (
            "metadata_budget_enforced",
            red_pass(&red_results, "metadata_budget_exceeded"),
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

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "accepted_fixture_count",
        accepted_fixture_count,
        10,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        34,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_rejection_count",
        red_fixture_rejection_count,
        red_results.len() as u64,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "card_kind_count",
        metrics.card_kind_count,
        4,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "format_count",
        metrics.format_count,
        5,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_lane_count",
        metrics.runtime_lane_count,
        5,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "organ_count",
        metrics.organ_count,
        4,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "declared_artifact_bytes_total",
        metrics.declared_artifact_bytes_total,
        1,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "declared_runtime_memory_floor_bytes_total",
        metrics.declared_runtime_memory_floor_bytes_total,
        1,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes_read",
        INTAKE_METADATA_BYTES,
        640 * 1024,
        "<=",
    );
    measurements.insert(
        "intake_address".to_string(),
        Measurement {
            value: serde_json::json!(intake.address()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "intake_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("compressed_model_source_card_intake:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "intake_address".to_string(),
        intake
            .address()
            .starts_with("compressed_model_source_card_intake:")
            && intake.address().contains('@'),
    );

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
            "detail": "metadata-only compressed model source-card intake; no runtime, route choice, product copy, hidden authority, MAS promotion, or live dense 70B claim"
        })],
        notes: "Builds F-CompressedModelSourceCard-Intake from SourceSignalGraph, ModelInventoryCandidateSet, and F-ProprietaryCompression-ProvenanceGate. Scope is T1/L1 metadata only; it feeds later Gemma QAT, TurboVec/Eidos, route-card, byte, runtime, and WRV witnesses without promoting L2/L3.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn red_fixture_results(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
    provenance_gate: &ProprietaryCompressionProvenanceGate,
    cards: &[CompressedModelSourceCard],
) -> Vec<(&'static str, bool)> {
    vec![
        (
            "empty_card_id",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.card_id.clear()
            }),
        ),
        (
            "duplicate_card_id",
            reject_cards(graph, inventory, provenance_gate, cards, |cards| {
                cards[1].card_id = cards[0].card_id.clone()
            }),
        ),
        (
            "duplicate_source_id",
            reject_cards(graph, inventory, provenance_gate, cards, |cards| {
                cards[1].source_id = cards[0].source_id.clone()
            }),
        ),
        (
            "duplicate_inventory_ref",
            reject_cards(graph, inventory, provenance_gate, cards, |cards| {
                cards[1].model_inventory_candidate_ref =
                    cards[0].model_inventory_candidate_ref.clone()
            }),
        ),
        (
            "unknown_source_id",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.source_id = "source:model:missing".to_string();
                card.source_digest = digest("source:model:missing");
            }),
        ),
        (
            "blocked_source_id",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.source_id = "source:blocked:poison-card".to_string();
                card.source_digest = digest("source:blocked:poison-card");
                card.model_inventory_candidate_ref = None;
                card.provenance_overlay_ref = None;
            }),
        ),
        (
            "source_digest_mismatch",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.source_digest = digest("wrong-digest")
            }),
        ),
        (
            "unknown_inventory_candidate",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.model_inventory_candidate_ref = Some("inventory:missing".to_string())
            }),
        ),
        (
            "inventory_source_mismatch",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.model_inventory_candidate_ref = Some("inventory:turbovec".to_string())
            }),
        ),
        (
            "unknown_provenance_overlay",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.provenance_overlay_ref = Some("overlay:missing".to_string())
            }),
        ),
        (
            "provenance_source_mismatch",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.provenance_overlay_ref = Some("overlay:turbovec".to_string())
            }),
        ),
        (
            "provenance_import_mismatch",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.import_mode = ProprietaryCompressionImportMode::DirectImport
            }),
        ),
        (
            "missing_license_ref",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.license_ref.clear()
            }),
        ),
        (
            "missing_declared_artifact_bytes",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.byte_scope.declared_artifact_bytes = None
            }),
        ),
        (
            "missing_route_caveat",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.route_caveat_ref = None
            }),
        ),
        (
            "missing_gemma4_loader_caveat",
            reject_named_card(
                graph,
                inventory,
                provenance_gate,
                cards,
                "gemma4_12b_mlx_loader_blocked",
                |card| card.loader_caveat_ref = None,
            ),
        ),
        (
            "mlx_gemma4_loader_claim",
            reject_named_card(
                graph,
                inventory,
                provenance_gate,
                cards,
                "gemma4_12b_mlx_loader_blocked",
                |card| card.loader_caveat_ref = Some("loader_ready".to_string()),
            ),
        ),
        (
            "package_manifest_loader_proof",
            reject_named_card(
                graph,
                inventory,
                provenance_gate,
                cards,
                "llama_cpp_runtime_package",
                |card| card.claim_limit = ModelInventoryClaimLimit::RequiresRuntimeWitness,
            ),
        ),
        (
            "turbovec_not_eidos_cache",
            reject_named_card(
                graph,
                inventory,
                provenance_gate,
                cards,
                "turbovec_eidos_cache",
                |card| card.organ = CompressedModelOrgan::RuntimeRouter,
            ),
        ),
        (
            "gguf_lane_mismatch",
            reject_named_card(
                graph,
                inventory,
                provenance_gate,
                cards,
                "gemma4_12b_qat_gguf",
                |card| card.runtime_lane = CompressedModelRuntimeLane::MlxSwift,
            ),
        ),
        (
            "litert_lane_mismatch",
            reject_named_card(
                graph,
                inventory,
                provenance_gate,
                cards,
                "gemma4_e4b_mobile_litert",
                |card| card.runtime_lane = CompressedModelRuntimeLane::GgufLlamaCpp,
            ),
        ),
        (
            "runtime_route_authority",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.route_caveat_ref = Some("route_caveat:live_route_authority".to_string())
            }),
        ),
        (
            "product_file_copied",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.byte_scope.copied_product_file_count = 1
            }),
        ),
        (
            "weight_blob_opened",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.byte_scope.weight_blob_open_attempted = true
            }),
        ),
        (
            "weight_blob_hash_attempted",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.byte_scope.weight_blob_hash_attempted = true
            }),
        ),
        (
            "model_bytes_loaded",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.byte_scope.model_bytes_loaded = 1
            }),
        ),
        (
            "index_bytes_loaded",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.byte_scope.index_bytes_loaded = 1
            }),
        ),
        (
            "runtime_bytes_loaded",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.byte_scope.runtime_bytes_loaded = 1
            }),
        ),
        (
            "provider_call_made",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.byte_scope.provider_calls_made = 1
            }),
        ),
        (
            "rowid_identity",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.source_locator = "sqlite:rowid:99".to_string()
            }),
        ),
        (
            "hidden_route_authority",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.route_caveat_ref = Some("route_caveat:hidden-route-authority".to_string())
            }),
        ),
        (
            "hidden_cloud_fallback",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.route_caveat_ref = Some("route_caveat:hidden-cloud".to_string())
            }),
        ),
        (
            "dense_70b_live_claim",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.context_window_ref = Some("context:live-dense-70b".to_string())
            }),
        ),
        (
            "ssd_as_ram_claim",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.route_caveat_ref = Some("route_caveat:ssd-as-ram".to_string())
            }),
        ),
        (
            "product_green_from_research",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.license_ref = "license:product-green".to_string()
            }),
        ),
        (
            "mas_live_from_research",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.product_build = ProductBuild::Mas
            }),
        ),
        (
            "tier_promotion_from_research",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.promotion_tier = CompressedModelPromotionTier::T4BuildGreen
            }),
        ),
        (
            "bad_proof_ref_prefix",
            reject_card(graph, inventory, provenance_gate, cards, |card| {
                card.proof_refs.answer_packet_ref = "packet:bad-prefix".to_string()
            }),
        ),
        (
            "missing_layer_separation",
            build_intake_with_flags(
                graph,
                inventory,
                provenance_gate,
                cards.to_vec(),
                false,
                true,
                true,
                true,
            )
            .is_err(),
        ),
        (
            "metadata_budget_exceeded",
            build_intake_with_metadata(
                graph,
                inventory,
                provenance_gate,
                cards.to_vec(),
                900 * 1024,
            )
            .is_err(),
        ),
    ]
}

fn source_graph() -> Result<SourceSignalGraph, Box<dyn std::error::Error>> {
    let clear_sources = [
        ("source:model:gemma4-e2b-qat-gguf", SourceSignalType::Doc),
        (
            "source:model:gemma4-e4b-mobile-litert",
            SourceSignalType::Doc,
        ),
        ("source:model:gemma4-12b-qat-gguf", SourceSignalType::Doc),
        ("source:model:gemma4-12b-mlx-preview", SourceSignalType::Doc),
        ("source:index:turbovec", SourceSignalType::Repo),
        ("source:runtime:llama-cpp", SourceSignalType::Repo),
        ("source:runtime:litert-lm", SourceSignalType::Doc),
        ("source:runtime:mlx-swift-lm", SourceSignalType::Repo),
        ("source:model:qwen3-coder-mlx", SourceSignalType::Doc),
        ("source:model:granite-micro-mlx", SourceSignalType::Doc),
        (
            "source:codec:custom-metal-local-canon",
            SourceSignalType::Doc,
        ),
    ];
    SourceSignalGraph::intake(
        clear_sources
            .into_iter()
            .map(|(source_id, source_type)| {
                source_card(source_id, source_type, SourceNoPoisonStatus::Clear)
            })
            .chain(std::iter::once(source_card(
                "source:blocked:poison-card",
                SourceSignalType::Repo,
                SourceNoPoisonStatus::Blocked,
            )))
            .collect::<Result<Vec<_>, _>>()?,
        Vec::new(),
        CREATED_AT_MS,
    )
    .map_err(Into::into)
}

fn model_inventory(
    graph: &SourceSignalGraph,
) -> Result<ModelInventoryCandidateSet, Box<dyn std::error::Error>> {
    let cards = [
        (
            "inventory:gemma4-e2b-gguf",
            "source:model:gemma4-e2b-qat-gguf",
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
        ),
        (
            "inventory:gemma4-e4b-litert",
            "source:model:gemma4-e4b-mobile-litert",
            "litert-community/gemma-4-E4B-it-litert-lm",
        ),
        (
            "inventory:gemma4-12b-gguf",
            "source:model:gemma4-12b-qat-gguf",
            "google/gemma-4-12B-it-qat-q4_0-gguf",
        ),
        (
            "inventory:gemma4-12b-mlx",
            "source:model:gemma4-12b-mlx-preview",
            "mlx-community/gemma-4-12B-it-qat-4bit",
        ),
        (
            "inventory:turbovec",
            "source:index:turbovec",
            "RyanCodrai/turbovec",
        ),
        (
            "inventory:llama-cpp",
            "source:runtime:llama-cpp",
            "ggerganov/llama.cpp",
        ),
        (
            "inventory:litert-lm",
            "source:runtime:litert-lm",
            "LiteRT-LM Swift package",
        ),
        (
            "inventory:mlx-swift-lm",
            "source:runtime:mlx-swift-lm",
            "ml-explore/mlx-swift-lm",
        ),
        (
            "inventory:qwen3-coder-mlx",
            "source:model:qwen3-coder-mlx",
            "mlx-community/Qwen3-Coder-Next-4bit",
        ),
        (
            "inventory:granite-micro-mlx",
            "source:model:granite-micro-mlx",
            "mlx-community/granite-4.0-h-micro-mlx",
        ),
        (
            "inventory:custom-metal-local-canon",
            "source:codec:custom-metal-local-canon",
            "docs/fusion/TURBOVEC_QAT_RUNTIME_AGNOSTIC_INTAKE_2026_06_06.md",
        ),
    ]
    .into_iter()
    .map(|(candidate_id, source_id, model_or_package_id)| {
        inventory_card(graph, candidate_id, source_id, model_or_package_id)
    })
    .collect();

    Ok(ModelInventoryCandidateSet::from_source_graph(
        graph,
        cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        40_000,
        true,
        true,
        true,
        CREATED_AT_MS,
    )?)
}

fn provenance_gate(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
) -> Result<ProprietaryCompressionProvenanceGate, Box<dyn std::error::Error>> {
    let overlays = [
        (
            "overlay:gemma4-e2b-gguf",
            "source:model:gemma4-e2b-qat-gguf",
            "inventory:gemma4-e2b-gguf",
            ProprietaryCompressionSourceKind::ModelCard,
            ProprietaryCompressionImportMode::ResearchOnly,
            ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
        ),
        (
            "overlay:gemma4-e4b-litert",
            "source:model:gemma4-e4b-mobile-litert",
            "inventory:gemma4-e4b-litert",
            ProprietaryCompressionSourceKind::ModelCard,
            ProprietaryCompressionImportMode::ResearchOnly,
            ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
        ),
        (
            "overlay:gemma4-12b-gguf",
            "source:model:gemma4-12b-qat-gguf",
            "inventory:gemma4-12b-gguf",
            ProprietaryCompressionSourceKind::ModelCard,
            ProprietaryCompressionImportMode::ResearchOnly,
            ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
        ),
        (
            "overlay:gemma4-12b-mlx",
            "source:model:gemma4-12b-mlx-preview",
            "inventory:gemma4-12b-mlx",
            ProprietaryCompressionSourceKind::ModelCard,
            ProprietaryCompressionImportMode::ResearchOnly,
            ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
        ),
        (
            "overlay:turbovec",
            "source:index:turbovec",
            "inventory:turbovec",
            ProprietaryCompressionSourceKind::Repo,
            ProprietaryCompressionImportMode::AdapterWrap,
            ProprietaryCompressionAllowedAction::AdapterOnly,
        ),
        (
            "overlay:llama-cpp",
            "source:runtime:llama-cpp",
            "inventory:llama-cpp",
            ProprietaryCompressionSourceKind::RuntimePackage,
            ProprietaryCompressionImportMode::ResearchOnly,
            ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
        ),
        (
            "overlay:litert-lm",
            "source:runtime:litert-lm",
            "inventory:litert-lm",
            ProprietaryCompressionSourceKind::RuntimePackage,
            ProprietaryCompressionImportMode::ResearchOnly,
            ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
        ),
        (
            "overlay:mlx-swift-lm",
            "source:runtime:mlx-swift-lm",
            "inventory:mlx-swift-lm",
            ProprietaryCompressionSourceKind::RuntimePackage,
            ProprietaryCompressionImportMode::ResearchOnly,
            ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
        ),
        (
            "overlay:qwen3-coder-mlx",
            "source:model:qwen3-coder-mlx",
            "inventory:qwen3-coder-mlx",
            ProprietaryCompressionSourceKind::ModelCard,
            ProprietaryCompressionImportMode::ResearchOnly,
            ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
        ),
        (
            "overlay:granite-micro-mlx",
            "source:model:granite-micro-mlx",
            "inventory:granite-micro-mlx",
            ProprietaryCompressionSourceKind::ModelCard,
            ProprietaryCompressionImportMode::ResearchOnly,
            ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
        ),
        (
            "overlay:custom-metal-local-canon",
            "source:codec:custom-metal-local-canon",
            "inventory:custom-metal-local-canon",
            ProprietaryCompressionSourceKind::LocalCanon,
            ProprietaryCompressionImportMode::ResearchOnly,
            ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
        ),
    ]
    .into_iter()
    .map(
        |(overlay_id, source_id, candidate_ref, source_kind, import_mode, allowed_action)| {
            overlay(
                graph,
                overlay_id,
                source_id,
                candidate_ref,
                source_kind,
                import_mode,
                allowed_action,
            )
        },
    )
    .collect();

    Ok(ProprietaryCompressionProvenanceGate::from_sources(
        graph,
        inventory,
        overlays,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        64_000,
        true,
        true,
        true,
        true,
        CREATED_AT_MS,
    )?)
}

fn accepted_cards(graph: &SourceSignalGraph) -> Vec<CompressedModelSourceCard> {
    vec![
        compressed_card(CardSpec {
            graph,
            card_id: "gemma4_e2b_qat_gguf",
            source_id: "source:model:gemma4-e2b-qat-gguf",
            candidate_ref: "inventory:gemma4-e2b-gguf",
            overlay_ref: "overlay:gemma4-e2b-gguf",
            model_or_package_id: "google/gemma-4-E2B-it-qat-q4_0-gguf",
            card_kind: CompressedModelSourceCardKind::MobileQatModel,
            format: CompressedModelFormat::Gguf,
            runtime_lane: CompressedModelRuntimeLane::GgufLlamaCpp,
            organ: CompressedModelOrgan::ActiveAssembly,
            quantization_ref: Some("qat:q4_0"),
            loader_caveat_ref: None,
            route_caveat_ref: "route_caveat:gguf-runtime-unproven",
            import_mode: ProprietaryCompressionImportMode::ResearchOnly,
            allowed_action: ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
            claim_limit: ModelInventoryClaimLimit::RequiresRuntimeWitness,
            declared_artifact_bytes: Some(2_200_000_000),
            declared_runtime_memory_floor_bytes: Some(1_100_000_000),
        }),
        compressed_card(CardSpec {
            graph,
            card_id: "gemma4_e4b_mobile_litert",
            source_id: "source:model:gemma4-e4b-mobile-litert",
            candidate_ref: "inventory:gemma4-e4b-litert",
            overlay_ref: "overlay:gemma4-e4b-litert",
            model_or_package_id: "litert-community/gemma-4-E4B-it-litert-lm",
            card_kind: CompressedModelSourceCardKind::MobileQatModel,
            format: CompressedModelFormat::LiteRt,
            runtime_lane: CompressedModelRuntimeLane::LiteRtLm,
            organ: CompressedModelOrgan::ActiveAssembly,
            quantization_ref: Some("qat:mobile"),
            loader_caveat_ref: None,
            route_caveat_ref: "route_caveat:litert-swift-runtime-unproven",
            import_mode: ProprietaryCompressionImportMode::ResearchOnly,
            allowed_action: ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
            claim_limit: ModelInventoryClaimLimit::RequiresRuntimeWitness,
            declared_artifact_bytes: Some(3_300_000_000),
            declared_runtime_memory_floor_bytes: Some(1_800_000_000),
        }),
        compressed_card(CardSpec {
            graph,
            card_id: "gemma4_12b_qat_gguf",
            source_id: "source:model:gemma4-12b-qat-gguf",
            candidate_ref: "inventory:gemma4-12b-gguf",
            overlay_ref: "overlay:gemma4-12b-gguf",
            model_or_package_id: "google/gemma-4-12B-it-qat-q4_0-gguf",
            card_kind: CompressedModelSourceCardKind::QuantizedModel,
            format: CompressedModelFormat::Gguf,
            runtime_lane: CompressedModelRuntimeLane::GgufLlamaCpp,
            organ: CompressedModelOrgan::RuntimeRouter,
            quantization_ref: Some("qat:q4_0"),
            loader_caveat_ref: None,
            route_caveat_ref: "route_caveat:pro-gated-gguf-runtime-unproven",
            import_mode: ProprietaryCompressionImportMode::ResearchOnly,
            allowed_action: ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
            claim_limit: ModelInventoryClaimLimit::RequiresRuntimeWitness,
            declared_artifact_bytes: Some(6_660_000_000),
            declared_runtime_memory_floor_bytes: Some(8_000_000_000),
        }),
        compressed_card(CardSpec {
            graph,
            card_id: "gemma4_12b_mlx_loader_blocked",
            source_id: "source:model:gemma4-12b-mlx-preview",
            candidate_ref: "inventory:gemma4-12b-mlx",
            overlay_ref: "overlay:gemma4-12b-mlx",
            model_or_package_id: "mlx-community/gemma-4-12B-it-qat-4bit",
            card_kind: CompressedModelSourceCardKind::QuantizedModel,
            format: CompressedModelFormat::Mlx,
            runtime_lane: CompressedModelRuntimeLane::MlxSwift,
            organ: CompressedModelOrgan::RuntimeRouter,
            quantization_ref: Some("qat:mlx-4bit"),
            loader_caveat_ref: Some("loader_caveat:swift-mlx-gemma4-config-blocked"),
            route_caveat_ref: "route_caveat:mlx-gemma4-preview-not-loader-proof",
            import_mode: ProprietaryCompressionImportMode::ResearchOnly,
            allowed_action: ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
            claim_limit: ModelInventoryClaimLimit::RequiresRuntimeWitness,
            declared_artifact_bytes: Some(10_260_000_000),
            declared_runtime_memory_floor_bytes: Some(12_000_000_000),
        }),
        compressed_card(CardSpec {
            graph,
            card_id: "turbovec_eidos_cache",
            source_id: "source:index:turbovec",
            candidate_ref: "inventory:turbovec",
            overlay_ref: "overlay:turbovec",
            model_or_package_id: "RyanCodrai/turbovec",
            card_kind: CompressedModelSourceCardKind::CompressedIndex,
            format: CompressedModelFormat::TurboVecIndex,
            runtime_lane: CompressedModelRuntimeLane::TurboVecEidosCache,
            organ: CompressedModelOrgan::Eidos,
            quantization_ref: Some("vector:q4-q2"),
            loader_caveat_ref: None,
            route_caveat_ref: "route_caveat:eidos-cache-rebuildable-prior-only",
            import_mode: ProprietaryCompressionImportMode::AdapterWrap,
            allowed_action: ProprietaryCompressionAllowedAction::AdapterOnly,
            claim_limit: ModelInventoryClaimLimit::RequiresByteWitness,
            declared_artifact_bytes: Some(64_000_000),
            declared_runtime_memory_floor_bytes: Some(64_000_000),
        }),
        runtime_package_card(
            graph,
            "llama_cpp_runtime_package",
            "source:runtime:llama-cpp",
            "inventory:llama-cpp",
            "overlay:llama-cpp",
            "ggerganov/llama.cpp",
            CompressedModelRuntimeLane::GgufLlamaCpp,
        ),
        runtime_package_card(
            graph,
            "litert_lm_runtime_package",
            "source:runtime:litert-lm",
            "inventory:litert-lm",
            "overlay:litert-lm",
            "LiteRT-LM Swift package",
            CompressedModelRuntimeLane::LiteRtLm,
        ),
        runtime_package_card(
            graph,
            "mlx_swift_lm_runtime_package",
            "source:runtime:mlx-swift-lm",
            "inventory:mlx-swift-lm",
            "overlay:mlx-swift-lm",
            "ml-explore/mlx-swift-lm",
            CompressedModelRuntimeLane::MlxSwift,
        ),
        compressed_card(CardSpec {
            graph,
            card_id: "qwen3_coder_mlx",
            source_id: "source:model:qwen3-coder-mlx",
            candidate_ref: "inventory:qwen3-coder-mlx",
            overlay_ref: "overlay:qwen3-coder-mlx",
            model_or_package_id: "mlx-community/Qwen3-Coder-Next-4bit",
            card_kind: CompressedModelSourceCardKind::QuantizedModel,
            format: CompressedModelFormat::Mlx,
            runtime_lane: CompressedModelRuntimeLane::MlxSwift,
            organ: CompressedModelOrgan::ActiveAssembly,
            quantization_ref: Some("mlx:4bit"),
            loader_caveat_ref: None,
            route_caveat_ref: "route_caveat:mlx-coding-lane-needs-local-harness",
            import_mode: ProprietaryCompressionImportMode::ResearchOnly,
            allowed_action: ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
            claim_limit: ModelInventoryClaimLimit::RequiresRuntimeWitness,
            declared_artifact_bytes: Some(18_000_000_000),
            declared_runtime_memory_floor_bytes: Some(20_000_000_000),
        }),
        compressed_card(CardSpec {
            graph,
            card_id: "granite_micro_mlx",
            source_id: "source:model:granite-micro-mlx",
            candidate_ref: "inventory:granite-micro-mlx",
            overlay_ref: "overlay:granite-micro-mlx",
            model_or_package_id: "mlx-community/granite-4.0-h-micro-mlx",
            card_kind: CompressedModelSourceCardKind::QuantizedModel,
            format: CompressedModelFormat::Mlx,
            runtime_lane: CompressedModelRuntimeLane::MlxSwift,
            organ: CompressedModelOrgan::ActiveAssembly,
            quantization_ref: Some("mlx:small"),
            loader_caveat_ref: None,
            route_caveat_ref: "route_caveat:small-harness-candidate",
            import_mode: ProprietaryCompressionImportMode::ResearchOnly,
            allowed_action: ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
            claim_limit: ModelInventoryClaimLimit::RequiresRuntimeWitness,
            declared_artifact_bytes: Some(1_000_000_000),
            declared_runtime_memory_floor_bytes: Some(1_500_000_000),
        }),
        compressed_card(CardSpec {
            graph,
            card_id: "custom_metal_codec_local_canon",
            source_id: "source:codec:custom-metal-local-canon",
            candidate_ref: "inventory:custom-metal-local-canon",
            overlay_ref: "overlay:custom-metal-local-canon",
            model_or_package_id: "docs/fusion/TURBOVEC_QAT_RUNTIME_AGNOSTIC_INTAKE_2026_06_06.md",
            card_kind: CompressedModelSourceCardKind::CodecLibrary,
            format: CompressedModelFormat::LocalCanon,
            runtime_lane: CompressedModelRuntimeLane::CustomMetal,
            organ: CompressedModelOrgan::ColdStream,
            quantization_ref: Some("codec:custom-metal-research"),
            loader_caveat_ref: None,
            route_caveat_ref: "route_caveat:custom-metal-research-only",
            import_mode: ProprietaryCompressionImportMode::ResearchOnly,
            allowed_action: ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
            claim_limit: ModelInventoryClaimLimit::DependencyProvenanceOnly,
            declared_artifact_bytes: Some(1_024),
            declared_runtime_memory_floor_bytes: Some(1_024),
        }),
    ]
}

// UAS: uas:compressed-model-source-card:falsifier-spec
// Plane: Verification
// Residency: metadata-only fixture builder; not serialized substrate state.
struct CardSpec<'a> {
    graph: &'a SourceSignalGraph,
    card_id: &'a str,
    source_id: &'a str,
    candidate_ref: &'a str,
    overlay_ref: &'a str,
    model_or_package_id: &'a str,
    card_kind: CompressedModelSourceCardKind,
    format: CompressedModelFormat,
    runtime_lane: CompressedModelRuntimeLane,
    organ: CompressedModelOrgan,
    quantization_ref: Option<&'a str>,
    loader_caveat_ref: Option<&'a str>,
    route_caveat_ref: &'a str,
    import_mode: ProprietaryCompressionImportMode,
    allowed_action: ProprietaryCompressionAllowedAction,
    claim_limit: ModelInventoryClaimLimit,
    declared_artifact_bytes: Option<u64>,
    declared_runtime_memory_floor_bytes: Option<u64>,
}

fn compressed_card(spec: CardSpec<'_>) -> CompressedModelSourceCard {
    CompressedModelSourceCard {
        card_id: spec.card_id.to_string(),
        source_id: spec.source_id.to_string(),
        source_digest: digest_for(spec.graph, spec.source_id),
        model_inventory_candidate_ref: Some(spec.candidate_ref.to_string()),
        provenance_overlay_ref: Some(spec.overlay_ref.to_string()),
        model_or_package_id: spec.model_or_package_id.to_string(),
        card_kind: spec.card_kind,
        format: spec.format,
        runtime_lane: spec.runtime_lane,
        organ: spec.organ,
        quantization_ref: spec.quantization_ref.map(str::to_string),
        context_window_ref: Some("context_window:source-card-only".to_string()),
        license_ref: "license:source-card-fixture".to_string(),
        loader_caveat_ref: spec.loader_caveat_ref.map(str::to_string),
        route_caveat_ref: Some(spec.route_caveat_ref.to_string()),
        source_locator: format!("fixture://{}", spec.source_id),
        import_mode: spec.import_mode,
        allowed_action: spec.allowed_action,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
        claim_limit: spec.claim_limit,
        metadata_status: ModelInventoryMetadataStatus::DependencyProvenanceOnly,
        byte_scope: CompressedModelSourceByteScope::metadata_only(
            1_024,
            0,
            spec.declared_artifact_bytes,
            spec.declared_runtime_memory_floor_bytes,
        ),
        proof_refs: compressed_proof_refs(spec.card_id),
    }
}

#[allow(clippy::too_many_arguments)]
fn runtime_package_card(
    graph: &SourceSignalGraph,
    card_id: &str,
    source_id: &str,
    candidate_ref: &str,
    overlay_ref: &str,
    model_or_package_id: &str,
    runtime_lane: CompressedModelRuntimeLane,
) -> CompressedModelSourceCard {
    compressed_card(CardSpec {
        graph,
        card_id,
        source_id,
        candidate_ref,
        overlay_ref,
        model_or_package_id,
        card_kind: CompressedModelSourceCardKind::RuntimePackage,
        format: CompressedModelFormat::PackageManifest,
        runtime_lane,
        organ: CompressedModelOrgan::RuntimeRouter,
        quantization_ref: None,
        loader_caveat_ref: None,
        route_caveat_ref: "route_caveat:runtime-package-not-loader-proof",
        import_mode: ProprietaryCompressionImportMode::ResearchOnly,
        allowed_action: ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
        claim_limit: ModelInventoryClaimLimit::DependencyProvenanceOnly,
        declared_artifact_bytes: None,
        declared_runtime_memory_floor_bytes: None,
    })
}

fn build_intake(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
    provenance_gate: &ProprietaryCompressionProvenanceGate,
    cards: Vec<CompressedModelSourceCard>,
) -> Result<CompressedModelSourceCardIntake, Box<dyn std::error::Error>> {
    Ok(CompressedModelSourceCardIntake::from_provenance(
        graph,
        inventory,
        provenance_gate,
        cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        INTAKE_METADATA_BYTES,
        true,
        true,
        true,
        true,
        CREATED_AT_MS,
    )?)
}

fn build_intake_with_metadata(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
    provenance_gate: &ProprietaryCompressionProvenanceGate,
    cards: Vec<CompressedModelSourceCard>,
    metadata_bytes: u64,
) -> Result<CompressedModelSourceCardIntake, Box<dyn std::error::Error>> {
    Ok(CompressedModelSourceCardIntake::from_provenance(
        graph,
        inventory,
        provenance_gate,
        cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        metadata_bytes,
        true,
        true,
        true,
        true,
        CREATED_AT_MS,
    )?)
}

fn build_intake_with_flags(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
    provenance_gate: &ProprietaryCompressionProvenanceGate,
    cards: Vec<CompressedModelSourceCard>,
    l1_l2_l3_separated: bool,
    route_authority_blocked: bool,
    product_promotion_blocked: bool,
    rowid_identity_blocked: bool,
) -> Result<CompressedModelSourceCardIntake, Box<dyn std::error::Error>> {
    Ok(CompressedModelSourceCardIntake::from_provenance(
        graph,
        inventory,
        provenance_gate,
        cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        INTAKE_METADATA_BYTES,
        l1_l2_l3_separated,
        route_authority_blocked,
        product_promotion_blocked,
        rowid_identity_blocked,
        CREATED_AT_MS,
    )?)
}

fn inventory_card(
    graph: &SourceSignalGraph,
    candidate_id: &str,
    source_id: &str,
    model_or_package_id: &str,
) -> ModelInventoryCandidateCard {
    ModelInventoryCandidateCard {
        candidate_id: candidate_id.to_string(),
        source_id: source_id.to_string(),
        source_digest: digest_for(graph, source_id),
        model_or_package_id: model_or_package_id.to_string(),
        evidence_kind: ModelInventoryEvidenceKind::PackageManifest,
        metadata_status: ModelInventoryMetadataStatus::DependencyProvenanceOnly,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        claim_limit: ModelInventoryClaimLimit::DependencyProvenanceOnly,
        evidence_locator: format!("fixture://{source_id}/source-card"),
        revision_ref: None,
        hash_claim: ModelInventoryHashClaim::None,
        loader_caveat_ref: None,
        route_hint_ref: None,
        sidecar_policy: None,
        byte_scope: ModelInventoryByteScope::metadata_only(512, 0),
        proof_refs: ModelInventoryProofRefs {
            falsifier_ref: format!("falsifier:model-inventory:{candidate_id}"),
            rollback_ref: format!("rollback:model-inventory:{candidate_id}"),
            run_event_log_ref: format!("run_event_log:model-inventory:{candidate_id}"),
            answer_packet_ref: format!("answer_packet:model-inventory:{candidate_id}"),
            compatibility_fence_ref: format!("compat:model-inventory:{candidate_id}"),
        },
        source_observed_at_utc: Some("2026-06-06T00:00:00Z".to_string()),
    }
}

fn overlay(
    graph: &SourceSignalGraph,
    overlay_id: &str,
    source_id: &str,
    candidate_ref: &str,
    source_kind: ProprietaryCompressionSourceKind,
    import_mode: ProprietaryCompressionImportMode,
    allowed_action: ProprietaryCompressionAllowedAction,
) -> ProprietaryCompressionSourceOverlay {
    ProprietaryCompressionSourceOverlay {
        overlay_id: overlay_id.to_string(),
        source_id: source_id.to_string(),
        source_digest: digest_for(graph, source_id),
        source_kind,
        source_locator: format!("fixture://{source_id}"),
        observed_at_utc: "2026-06-06T00:00:00Z".to_string(),
        license_class: ProprietaryCompressionLicenseClass::Permissive,
        import_mode,
        allowed_action,
        dependency_count: 1,
        transitive_unknown_dependency_count: 0,
        benchmark_claim_count: 0,
        extracted_behaviors: vec![ProprietaryCompressionExtractedBehavior {
            behavior_id: format!("behavior:{overlay_id}"),
            kind: ProprietaryCompressionBehaviorKind::ApiShape,
            summary_ref: format!("summary:{overlay_id}"),
            evidence_ref: format!("evidence:{overlay_id}"),
            uses_verbatim_code: false,
        }],
        local_test_plan_ref: Some(format!("local_test_plan:{overlay_id}")),
        quarantine_ref: None,
        clean_room_note_ref: None,
        attribution_ref: Some(format!("attribution:{overlay_id}")),
        model_inventory_candidate_ref: Some(candidate_ref.to_string()),
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        byte_scope: ProprietaryCompressionByteScope::metadata_only(1_024, 0),
        proof_refs: ProprietaryCompressionProofRefs {
            falsifier_ref: format!("falsifier:provenance:{overlay_id}"),
            rollback_ref: format!("rollback:provenance:{overlay_id}"),
            run_event_log_ref: format!("run_event_log:provenance:{overlay_id}"),
            answer_packet_ref: format!("answer_packet:provenance:{overlay_id}"),
            compatibility_fence_ref: format!("compat:provenance:{overlay_id}"),
        },
    }
}

fn source_card(
    source_id: &str,
    source_type: SourceSignalType,
    no_poison_status: SourceNoPoisonStatus,
) -> Result<SourceCard, Box<dyn std::error::Error>> {
    Ok(SourceCard::new(
        source_id,
        source_type,
        format!("fixture://{source_id}"),
        digest(source_id),
        1,
        "fixture-only compressed model source card; no product import",
        PrivacyClass::PublicResearch,
        no_poison_status,
        vec!["compressed_model_source_card".to_string()],
    )?)
}

fn compressed_proof_refs(card_id: &str) -> CompressedModelSourceProofRefs {
    CompressedModelSourceProofRefs {
        falsifier_ref: format!("falsifier:compressed-model-source-card:{card_id}"),
        rollback_ref: format!("rollback:compressed-model-source-card:{card_id}"),
        run_event_log_ref: format!("run_event_log:compressed-model-source-card:{card_id}"),
        answer_packet_ref: format!("answer_packet:compressed-model-source-card:{card_id}"),
        compatibility_fence_ref: format!("compat:compressed-model-source-card:{card_id}"),
    }
}

fn reject_card(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
    provenance_gate: &ProprietaryCompressionProvenanceGate,
    cards: &[CompressedModelSourceCard],
    mutate: impl FnOnce(&mut CompressedModelSourceCard),
) -> bool {
    reject_named_card(
        graph,
        inventory,
        provenance_gate,
        cards,
        "gemma4_e2b_qat_gguf",
        mutate,
    )
}

fn reject_named_card(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
    provenance_gate: &ProprietaryCompressionProvenanceGate,
    cards: &[CompressedModelSourceCard],
    card_id: &str,
    mutate: impl FnOnce(&mut CompressedModelSourceCard),
) -> bool {
    let mut mutated = cards.to_vec();
    let card = mutated
        .iter_mut()
        .find(|card| card.card_id == card_id)
        .expect("fixture card present");
    mutate(card);
    build_intake(graph, inventory, provenance_gate, mutated).is_err()
}

fn reject_cards(
    graph: &SourceSignalGraph,
    inventory: &ModelInventoryCandidateSet,
    provenance_gate: &ProprietaryCompressionProvenanceGate,
    cards: &[CompressedModelSourceCard],
    mutate: impl FnOnce(&mut Vec<CompressedModelSourceCard>),
) -> bool {
    let mut mutated = cards.to_vec();
    mutate(&mut mutated);
    build_intake(graph, inventory, provenance_gate, mutated).is_err()
}

fn has_card(cards: &[CompressedModelSourceCard], card_id: &str) -> bool {
    cards.iter().any(|card| card.card_id == card_id)
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(result_name, _)| *result_name == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn digest_for(graph: &SourceSignalGraph, source_id: &str) -> String {
    graph
        .source_cards
        .iter()
        .find(|card| card.source_id == source_id)
        .map(|card| card.digest.clone())
        .unwrap_or_else(|| digest(source_id))
}

fn digest(input: &str) -> String {
    format!("blake3:{}", blake3::hash(input.as_bytes()).to_hex())
}

fn add_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    pass: bool,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(pass),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    value: u64,
    threshold: u64,
    operator: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::json!(value),
            unit: "count".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::json!(threshold),
            unit: "count".to_string(),
        },
    );
    let pass = match operator {
        "==" => value == threshold,
        ">=" => value >= threshold,
        "<=" => value <= threshold,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), pass);
}
