//! `falsify_model_inventory_zero_byte_candidate_cards`
//!
//! Metadata-only witness for `F-ModelInventory-ZeroByteCandidateCards`. It
//! proves local model/package/cache evidence can be source-carded and
//! inventoried without opening model blobs, hashing large files, starting a
//! runtime, calling a provider, choosing a route, or promoting product truth.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ModelInventoryByteScope, ModelInventoryCandidateCard, ModelInventoryCandidateSet,
    ModelInventoryClaimLimit, ModelInventoryEvidenceKind, ModelInventoryHashClaim,
    ModelInventoryMetadataStatus, ModelInventoryProofRefs, ModelInventorySidecarPolicy,
    PrivacyClass, ProStatus, ProductBuild, SourceCard, SourceNoPoisonStatus, SourceSignalGraph,
    SourceSignalType,
};

const FALSIFIER_ID: &str = "F-ModelInventory-ZeroByteCandidateCards";
const FIXTURE_ID: &str = "model_inventory_zero_byte_candidate_cards_v1";
const COMMAND: &str = "Tools/falsifiers/f_model_inventory_zero_byte_candidate_cards.sh";
const RESULT: &str = "artifacts/falsifiers/model_inventory_zero_byte_candidate_cards/result.json";
const CREATED_AT_MS: u64 = 1_779_030_000_000;

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
        "{FALSIFIER_ID}: overall_pass={} candidate_count={} red_fixture_rejection_count={} artifact={RESULT}",
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
    let cards = accepted_cards(&graph)?;
    let set = ModelInventoryCandidateSet::from_source_graph(
        &graph,
        cards.clone(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        48_000,
        true,
        true,
        true,
        CREATED_AT_MS,
    )?;
    let reversed = ModelInventoryCandidateSet::from_source_graph(
        &graph,
        cards.iter().cloned().rev().collect(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        48_000,
        true,
        true,
        true,
        CREATED_AT_MS,
    )?;
    let metrics = set.metrics();

    let red_results = red_fixture_results(&graph, &cards);

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let accepted_fixture_count = cards.len() as u64;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    for (name, pass) in [
        (
            "source_signal_graph_intake_called_first",
            !graph.source_cards.is_empty(),
        ),
        (
            "catalog_only_fixture_present",
            has_candidate(&cards, "catalog_only_qwen3_4b_mlx"),
        ),
        (
            "manifest_unverified_fixture_present",
            has_candidate(&cards, "manifest_active_deepseek_unverified"),
        ),
        (
            "hub_snapshot_present_fixture_present",
            has_candidate(&cards, "hub_snapshot_present_qwen3_coder"),
        ),
        (
            "hub_snapshot_missing_fixture_present",
            has_candidate(&cards, "hub_snapshot_missing_qwen3_thinking"),
        ),
        (
            "gemma4_loader_blocked_fixture_present",
            has_candidate(&cards, "gemma4_preview_loader_blocked"),
        ),
        (
            "gguf_deferred_fixture_present",
            has_candidate(&cards, "gguf_128k_deferred"),
        ),
        (
            "lfs_pointer_metadata_fixture_present",
            has_candidate(&cards, "lfs_pointer_metadata_only"),
        ),
        (
            "sidecar_index_capped_fixture_present",
            has_candidate(&cards, "sidecar_index_metadata_capped"),
        ),
        (
            "package_manifest_fixture_present",
            cards
                .iter()
                .filter(|card| card.evidence_kind == ModelInventoryEvidenceKind::PackageManifest)
                .count()
                >= 3,
        ),
        (
            "runtime_preference_hint_fixture_present",
            has_candidate(&cards, "runtime_router_preference_hint"),
        ),
        (
            "inventory_cards_bound_to_source_ids",
            metrics.candidate_count == accepted_fixture_count,
        ),
        ("candidate_ids_unique", unique_candidate_ids(&cards)),
        (
            "source_ids_unique_for_authoritative_inventory",
            unique_source_ids(&cards),
        ),
        (
            "source_graph_address_deterministic",
            set.inventory_address == reversed.inventory_address,
        ),
        (
            "snapshot_revision_not_file_hash",
            red_pass(&red_results, "snapshot_revision_as_file_hash"),
        ),
        (
            "lfs_oid_not_local_hash",
            red_pass(&red_results, "lfs_oid_as_verified_local_hash"),
        ),
        (
            "no_weight_blob_opened",
            metrics.weight_blob_open_attempt_count == 0,
        ),
        (
            "no_weight_blob_hashing",
            metrics.weight_blob_hash_attempt_count == 0,
        ),
        ("zero_model_bytes_loaded", metrics.model_bytes_loaded == 0),
        ("zero_index_bytes_loaded", metrics.index_bytes_loaded == 0),
        (
            "zero_runtime_bytes_loaded",
            metrics.runtime_bytes_loaded == 0,
        ),
        ("zero_provider_calls", metrics.provider_calls_made == 0),
        (
            "manifest_checksum_unverified_not_promoted",
            red_pass(&red_results, "manifest_unverified_promoted"),
        ),
        (
            "package_manifest_not_loader_proof",
            red_pass(&red_results, "package_lock_loader_proof"),
        ),
        (
            "active_dir_not_runtime_proof",
            red_pass(&red_results, "active_dir_runtime_proof"),
        ),
        (
            "gemma4_loader_caveat_preserved",
            red_pass(&red_results, "gemma4_loader_caveat_removed"),
        ),
        (
            "runtime_preference_not_route_authority",
            red_pass(&red_results, "runtime_preference_route_authority"),
        ),
        (
            "filesystem_path_not_uas_address",
            red_pass(&red_results, "app_support_path_as_uas_id"),
        ),
        (
            "sidecar_size_cap_enforced",
            red_pass(&red_results, "sidecar_size_cap_missing"),
        ),
        (
            "product_green_from_metadata_rejected",
            red_pass(&red_results, "product_green_from_metadata"),
        ),
        (
            "mas_live_from_research_rejected",
            red_pass(&red_results, "mas_live_from_pro_research"),
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
            "hidden_route_authority_rejected",
            red_pass(&red_results, "hidden_eidos_or_patternboost_authority"),
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
            }),
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
        12,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        28,
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
        "evidence_kind_count",
        metrics.evidence_kind_count,
        8,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_status_count",
        metrics.metadata_status_count,
        8,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes_read",
        metrics.metadata_bytes,
        512 * 1024,
        "<=",
    );
    measurements.insert(
        "inventory_address".to_string(),
        Measurement {
            value: serde_json::json!(set.address()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "inventory_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("model_inventory_candidate_set:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "inventory_address".to_string(),
        set.address().starts_with("model_inventory_candidate_set:") && set.address().contains('@'),
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
            "detail": "metadata-only zero-byte model inventory; no model blob open, large hash, runtime start, provider call, route choice, MAS promotion, or product green claim"
        })],
        notes: "Builds F-ModelInventory-ZeroByteCandidateCards from SourceCard-bound fixtures and red mutators. This is a buildable research unit only: it advances a metadata architecture proof and does not promote L2/L3 product capability, live 70B, or runtime readiness.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn red_fixture_results(
    graph: &SourceSignalGraph,
    cards: &[ModelInventoryCandidateCard],
) -> Vec<(&'static str, bool)> {
    vec![
        (
            "empty_candidate_id",
            reject_card(graph, cards, |card| card.candidate_id.clear()),
        ),
        (
            "duplicate_candidate_id",
            reject_cards(graph, cards, |cards| {
                cards[1].candidate_id = cards[0].candidate_id.clone()
            }),
        ),
        (
            "orphan_source_id",
            reject_card(graph, cards, |card| {
                card.source_id = "source:missing".to_string()
            }),
        ),
        (
            "blocked_source_id",
            reject_card(graph, cards, |card| {
                card.source_id = "source:blocked:poison-model-card".to_string()
            }),
        ),
        (
            "duplicate_inventory_for_source",
            reject_cards(graph, cards, |cards| {
                cards[1].source_id = cards[0].source_id.clone()
            }),
        ),
        (
            "snapshot_revision_as_file_hash",
            reject_named_card(graph, cards, "hub_snapshot_present_qwen3_coder", |card| {
                card.hash_claim = ModelInventoryHashClaim::ManifestChecksumSha256
            }),
        ),
        (
            "lfs_oid_as_verified_local_hash",
            reject_named_card(graph, cards, "lfs_pointer_metadata_only", |card| {
                card.hash_claim = ModelInventoryHashClaim::VerifiedLocalWeightBlobHash
            }),
        ),
        (
            "weight_blob_open_attempted",
            reject_card(graph, cards, |card| {
                card.byte_scope.weight_blob_open_attempted = true
            }),
        ),
        (
            "weight_blob_hash_attempted",
            reject_card(graph, cards, |card| {
                card.byte_scope.weight_blob_hash_attempted = true
            }),
        ),
        (
            "nonzero_model_bytes_loaded",
            reject_card(graph, cards, |card| card.byte_scope.model_bytes_loaded = 1),
        ),
        (
            "nonzero_index_bytes_loaded",
            reject_card(graph, cards, |card| card.byte_scope.index_bytes_loaded = 1),
        ),
        (
            "nonzero_runtime_bytes_loaded",
            reject_card(graph, cards, |card| {
                card.byte_scope.runtime_bytes_loaded = 1
            }),
        ),
        (
            "provider_call_made",
            reject_card(graph, cards, |card| card.byte_scope.provider_calls_made = 1),
        ),
        (
            "active_dir_runtime_proof",
            reject_named_card(
                graph,
                cards,
                "manifest_active_deepseek_unverified",
                |card| card.claim_limit = ModelInventoryClaimLimit::RequiresRuntimeWitness,
            ),
        ),
        (
            "manifest_unverified_promoted",
            reject_named_card(
                graph,
                cards,
                "manifest_active_deepseek_unverified",
                |card| card.hash_claim = ModelInventoryHashClaim::ManifestChecksumSha256,
            ),
        ),
        (
            "package_lock_loader_proof",
            reject_named_card(graph, cards, "package_resolved_mlx_swift_lm", |card| {
                card.claim_limit = ModelInventoryClaimLimit::RequiresRuntimeWitness
            }),
        ),
        (
            "gemma4_loader_caveat_removed",
            reject_named_card(graph, cards, "gemma4_preview_loader_blocked", |card| {
                card.loader_caveat_ref = None
            }),
        ),
        (
            "runtime_preference_route_authority",
            reject_named_card(graph, cards, "runtime_router_preference_hint", |card| {
                card.claim_limit = ModelInventoryClaimLimit::RequiresRuntimeWitness
            }),
        ),
        (
            "app_support_path_as_uas_id",
            reject_card(graph, cards, |card| {
                card.candidate_id =
                    "/Users/jojo/Library/Application Support/Epistemos/model".to_string()
            }),
        ),
        (
            "sidecar_size_cap_missing",
            reject_named_card(graph, cards, "sidecar_index_metadata_capped", |card| {
                card.sidecar_policy = None
            }),
        ),
        (
            "malformed_sidecar_trusted",
            reject_named_card(graph, cards, "sidecar_index_metadata_capped", |card| {
                if let Some(policy) = &mut card.sidecar_policy {
                    policy.malformed_json_rejected = false;
                }
            }),
        ),
        (
            "product_green_from_metadata",
            reject_card(graph, cards, |card| card.pro_status = ProStatus::Live),
        ),
        (
            "mas_live_from_pro_research",
            reject_card(graph, cards, |card| card.product_build = ProductBuild::Mas),
        ),
        (
            "dense_70b_live_claim",
            reject_card(graph, cards, |card| {
                card.evidence_locator.push_str(":live-dense-70b")
            }),
        ),
        (
            "ssd_as_ram_claim",
            reject_card(graph, cards, |card| {
                card.evidence_locator.push_str(":ssd-as-ram")
            }),
        ),
        (
            "hidden_cloud_fallback",
            reject_card(graph, cards, |card| {
                card.evidence_locator.push_str(":hidden-cloud")
            }),
        ),
        (
            "hidden_eidos_or_patternboost_authority",
            reject_card(graph, cards, |card| {
                card.evidence_locator.push_str(":hidden-route-authority")
            }),
        ),
        (
            "missing_rollback_ref",
            reject_card(graph, cards, |card| card.proof_refs.rollback_ref.clear()),
        ),
        (
            "missing_run_event_log_ref",
            reject_card(graph, cards, |card| {
                card.proof_refs.run_event_log_ref.clear()
            }),
        ),
        (
            "missing_answer_packet_ref",
            reject_card(graph, cards, |card| {
                card.proof_refs.answer_packet_ref.clear()
            }),
        ),
        (
            "source_digest_mismatch",
            reject_card(graph, cards, |card| {
                card.source_digest = digest("wrong-digest")
            }),
        ),
        (
            "stale_external_metadata_promoted",
            reject_card(graph, cards, |card| card.source_observed_at_utc = None),
        ),
    ]
}

fn source_graph() -> Result<SourceSignalGraph, Box<dyn std::error::Error>> {
    SourceSignalGraph::intake(
        [
            "source:model:catalog-qwen3-4b",
            "source:model:manifest-deepseek-r1",
            "source:model:hub-qwen3-coder",
            "source:model:missing-qwen3-thinking",
            "source:model:gemma4-loader-blocked",
            "source:model:gguf-128k-deferred",
            "source:model:lfs-pointer",
            "source:model:sidecar-index",
            "source:package:mlx-swift-lm",
            "source:package:agent-core-cargo-lock",
            "source:package:js-editor-package-lock",
            "source:router:runtime-preference",
        ]
        .into_iter()
        .map(|source_id| source_card(source_id, SourceNoPoisonStatus::Clear))
        .chain(std::iter::once(source_card(
            "source:blocked:poison-model-card",
            SourceNoPoisonStatus::Blocked,
        )))
        .collect::<Result<Vec<_>, _>>()?,
        Vec::new(),
        CREATED_AT_MS,
    )
    .map_err(Into::into)
}

fn accepted_cards(
    graph: &SourceSignalGraph,
) -> Result<Vec<ModelInventoryCandidateCard>, Box<dyn std::error::Error>> {
    Ok(vec![
        candidate(
            graph,
            "catalog_only_qwen3_4b_mlx",
            "source:model:catalog-qwen3-4b",
            "Qwen/Qwen3-4B-MLX-4bit",
            ModelInventoryEvidenceKind::CatalogDescriptor,
            ModelInventoryMetadataStatus::CatalogOnly,
            ModelInventoryClaimLimit::CatalogEvidenceOnly,
            "Epistemos/State/InferenceState.swift:LocalTextModelID",
            Some("52a5ab34fa604bc8af6d3ce0cac0cab10b7eb495"),
            ModelInventoryHashClaim::SourceCardBlake3,
            None,
            None,
            None,
        ),
        candidate(
            graph,
            "manifest_active_deepseek_unverified",
            "source:model:manifest-deepseek-r1",
            "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit",
            ModelInventoryEvidenceKind::InstallManifest,
            ModelInventoryMetadataStatus::InstalledChecksumUnverified,
            ModelInventoryClaimLimit::InstallationEvidenceOnly,
            "/Users/jojo/Library/Application Support/Epistemos/Models/manifests/install-state.json",
            Some("21848dbf533d2518a1ef895104820d5ee51317ea"),
            ModelInventoryHashClaim::None,
            None,
            None,
            None,
        ),
        candidate(
            graph,
            "hub_snapshot_present_qwen3_coder",
            "source:model:hub-qwen3-coder",
            "mlx-community/Qwen3-Coder-Next-4bit",
            ModelInventoryEvidenceKind::HubSnapshot,
            ModelInventoryMetadataStatus::SnapshotPresent,
            ModelInventoryClaimLimit::CacheRevisionEvidenceOnly,
            "hub/models--mlx-community--Qwen3-Coder-Next-4bit/snapshots/7b9321eabb85ce79625cac3f61ea691e4ea984b5",
            Some("7b9321eabb85ce79625cac3f61ea691e4ea984b5"),
            ModelInventoryHashClaim::None,
            None,
            None,
            None,
        ),
        candidate(
            graph,
            "hub_snapshot_missing_qwen3_thinking",
            "source:model:missing-qwen3-thinking",
            "mlx-community/Qwen3-4B-Thinking-2507-4bit",
            ModelInventoryEvidenceKind::MissingHubSnapshot,
            ModelInventoryMetadataStatus::SnapshotMissing,
            ModelInventoryClaimLimit::CacheRevisionEvidenceOnly,
            "model_snapshot:local:models--mlx-community--Qwen3-4B-Thinking-2507-4bit:missing",
            Some("627b019c66f22d4de0a641d289b41497651a55c9"),
            ModelInventoryHashClaim::None,
            None,
            None,
            None,
        ),
        candidate(
            graph,
            "gemma4_preview_loader_blocked",
            "source:model:gemma4-loader-blocked",
            "mlx-community/gemma-4-e4b-it-4bit",
            ModelInventoryEvidenceKind::SidecarJson,
            ModelInventoryMetadataStatus::LoaderBlocked,
            ModelInventoryClaimLimit::SidecarMetadataOnly,
            "model.safetensors.index.json",
            Some("62b0e4e2d06c2f3baeeb0f8b7b18d7308c7786fc"),
            ModelInventoryHashClaim::SidecarJsonSha256,
            Some("loader_caveat:swift-mlx-gemma4-preview-blocked"),
            None,
            Some(sidecar_policy()),
        ),
        candidate(
            graph,
            "gguf_128k_deferred",
            "source:model:gguf-128k-deferred",
            "unsloth/Qwen3-8B-128K-GGUF",
            ModelInventoryEvidenceKind::FalsifierRef,
            ModelInventoryMetadataStatus::DeferredOwnerProbeRequired,
            ModelInventoryClaimLimit::RequiresByteWitness,
            "falsifier_ref:qwen-gguf-128k-deferred",
            Some("4a4ca8eeed6a9f3cdf58de9a1e86f7376d0059f9"),
            ModelInventoryHashClaim::DeferredLargeBlobHash,
            None,
            None,
            None,
        ),
        candidate(
            graph,
            "lfs_pointer_metadata_only",
            "source:model:lfs-pointer",
            "model-lfs-pointer-fixture",
            ModelInventoryEvidenceKind::LfsPointer,
            ModelInventoryMetadataStatus::DeferredOwnerProbeRequired,
            ModelInventoryClaimLimit::PointerMetadataOnly,
            "git-lfs-pointer:oid-sha256-size",
            None,
            ModelInventoryHashClaim::ExternalLfsOidSha256,
            None,
            None,
            None,
        ),
        candidate(
            graph,
            "sidecar_index_metadata_capped",
            "source:model:sidecar-index",
            "model.safetensors.index.json",
            ModelInventoryEvidenceKind::SidecarJson,
            ModelInventoryMetadataStatus::SnapshotPresent,
            ModelInventoryClaimLimit::SidecarMetadataOnly,
            "sidecar:model.safetensors.index.json",
            None,
            ModelInventoryHashClaim::SidecarJsonSha256,
            None,
            None,
            Some(sidecar_policy()),
        ),
        candidate(
            graph,
            "package_resolved_mlx_swift_lm",
            "source:package:mlx-swift-lm",
            "LocalPackages/mlx-swift-lm/Package.resolved",
            ModelInventoryEvidenceKind::PackageManifest,
            ModelInventoryMetadataStatus::DependencyProvenanceOnly,
            ModelInventoryClaimLimit::DependencyProvenanceOnly,
            "LocalPackages/mlx-swift-lm/Package.resolved",
            Some("mlx-swift:6ba4827fb82c97d012eec9ab4b2de21f85c3b33d"),
            ModelInventoryHashClaim::None,
            None,
            None,
            None,
        ),
        candidate(
            graph,
            "cargo_lock_agent_core",
            "source:package:agent-core-cargo-lock",
            "agent_core/Cargo.lock",
            ModelInventoryEvidenceKind::PackageManifest,
            ModelInventoryMetadataStatus::DependencyProvenanceOnly,
            ModelInventoryClaimLimit::DependencyProvenanceOnly,
            "agent_core/Cargo.lock",
            None,
            ModelInventoryHashClaim::None,
            None,
            None,
            None,
        ),
        candidate(
            graph,
            "package_lock_js_editor",
            "source:package:js-editor-package-lock",
            "js-editor/package-lock.json",
            ModelInventoryEvidenceKind::PackageManifest,
            ModelInventoryMetadataStatus::DependencyProvenanceOnly,
            ModelInventoryClaimLimit::DependencyProvenanceOnly,
            "js-editor/package-lock.json",
            None,
            ModelInventoryHashClaim::None,
            None,
            None,
            None,
        ),
        candidate(
            graph,
            "runtime_router_preference_hint",
            "source:router:runtime-preference",
            "Epistemos/LocalAgent/RuntimeRouter.swift:modelPreferenceTable",
            ModelInventoryEvidenceKind::RuntimePreferenceHint,
            ModelInventoryMetadataStatus::RouteHintOnly,
            ModelInventoryClaimLimit::RouteHintOnly,
            "Epistemos/LocalAgent/RuntimeRouter.swift:modelPreferenceTable",
            None,
            ModelInventoryHashClaim::None,
            None,
            Some("route_hint:runtime-router-preference-only"),
            None,
        ),
    ])
}

#[allow(clippy::too_many_arguments)]
fn candidate(
    graph: &SourceSignalGraph,
    candidate_id: &str,
    source_id: &str,
    model_or_package_id: &str,
    evidence_kind: ModelInventoryEvidenceKind,
    metadata_status: ModelInventoryMetadataStatus,
    claim_limit: ModelInventoryClaimLimit,
    evidence_locator: &str,
    revision_ref: Option<&str>,
    hash_claim: ModelInventoryHashClaim,
    loader_caveat_ref: Option<&str>,
    route_hint_ref: Option<&str>,
    sidecar_policy: Option<ModelInventorySidecarPolicy>,
) -> ModelInventoryCandidateCard {
    ModelInventoryCandidateCard {
        candidate_id: candidate_id.to_string(),
        source_id: source_id.to_string(),
        source_digest: digest_for(graph, source_id),
        model_or_package_id: model_or_package_id.to_string(),
        evidence_kind,
        metadata_status,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        claim_limit,
        evidence_locator: evidence_locator.to_string(),
        revision_ref: revision_ref.map(str::to_string),
        hash_claim,
        loader_caveat_ref: loader_caveat_ref.map(str::to_string),
        route_hint_ref: route_hint_ref.map(str::to_string),
        sidecar_policy,
        byte_scope: ModelInventoryByteScope::metadata_only(1_024, 0),
        proof_refs: proof_refs(candidate_id),
        source_observed_at_utc: Some("2026-06-06T00:00:00Z".to_string()),
    }
}

fn sidecar_policy() -> ModelInventorySidecarPolicy {
    ModelInventorySidecarPolicy {
        allowed_sidecar_names: vec![
            "config.json".to_string(),
            "tokenizer_config.json".to_string(),
            "generation_config.json".to_string(),
            "processor_config.json".to_string(),
            "model.safetensors.index.json".to_string(),
        ],
        max_sidecar_bytes: 64 * 1024,
        malformed_json_rejected: true,
    }
}

fn proof_refs(candidate_id: &str) -> ModelInventoryProofRefs {
    ModelInventoryProofRefs {
        falsifier_ref: format!("falsifier:{FALSIFIER_ID}:{candidate_id}"),
        rollback_ref: format!("rollback:model-inventory:{candidate_id}"),
        run_event_log_ref: format!("run_event_log:model-inventory:{candidate_id}"),
        answer_packet_ref: format!("answer_packet:model-inventory:{candidate_id}"),
        compatibility_fence_ref: format!("compat:model-inventory:{candidate_id}"),
    }
}

fn source_card(
    source_id: &str,
    no_poison_status: SourceNoPoisonStatus,
) -> Result<SourceCard, Box<dyn std::error::Error>> {
    Ok(SourceCard::new(
        source_id,
        SourceSignalType::Doc,
        format!("fixture://{source_id}"),
        digest(source_id),
        1,
        "fixture-only model inventory source; no product import",
        PrivacyClass::PublicResearch,
        no_poison_status,
        vec!["model_inventory".to_string()],
    )?)
}

fn digest_for(graph: &SourceSignalGraph, source_id: &str) -> String {
    graph
        .source_cards
        .iter()
        .find(|card| card.source_id == source_id)
        .map(|card| card.digest.clone())
        .unwrap_or_else(|| digest(source_id))
}

fn digest(seed: &str) -> String {
    format!("blake3:{}", blake3::hash(seed.as_bytes()).to_hex())
}

fn has_candidate(cards: &[ModelInventoryCandidateCard], candidate_id: &str) -> bool {
    cards.iter().any(|card| card.candidate_id == candidate_id)
}

fn unique_candidate_ids(cards: &[ModelInventoryCandidateCard]) -> bool {
    let mut ids = std::collections::HashSet::new();
    cards
        .iter()
        .all(|card| ids.insert(card.candidate_id.as_str()))
}

fn unique_source_ids(cards: &[ModelInventoryCandidateCard]) -> bool {
    let mut ids = std::collections::HashSet::new();
    cards.iter().all(|card| ids.insert(card.source_id.as_str()))
}

fn red_pass(red_results: &[(&'static str, bool)], name: &str) -> bool {
    red_results
        .iter()
        .find(|(axis, _)| *axis == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn reject_card(
    graph: &SourceSignalGraph,
    cards: &[ModelInventoryCandidateCard],
    mutate: impl FnOnce(&mut ModelInventoryCandidateCard),
) -> bool {
    reject_named_card(graph, cards, &cards[0].candidate_id, mutate)
}

fn reject_named_card(
    graph: &SourceSignalGraph,
    cards: &[ModelInventoryCandidateCard],
    candidate_id: &str,
    mutate: impl FnOnce(&mut ModelInventoryCandidateCard),
) -> bool {
    let mut mutated = cards.to_vec();
    let Some(card) = mutated
        .iter_mut()
        .find(|card| card.candidate_id == candidate_id)
    else {
        return false;
    };
    mutate(card);
    candidate_set_is_err(graph, mutated)
}

fn reject_cards(
    graph: &SourceSignalGraph,
    cards: &[ModelInventoryCandidateCard],
    mutate: impl FnOnce(&mut Vec<ModelInventoryCandidateCard>),
) -> bool {
    let mut mutated = cards.to_vec();
    mutate(&mut mutated);
    candidate_set_is_err(graph, mutated)
}

fn candidate_set_is_err(
    graph: &SourceSignalGraph,
    cards: Vec<ModelInventoryCandidateCard>,
) -> bool {
    ModelInventoryCandidateSet::from_source_graph(
        graph,
        cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        48_000,
        true,
        true,
        true,
        CREATED_AT_MS,
    )
    .is_err()
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
            value: serde_json::Value::Bool(pass),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
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
        ">=" => value >= threshold,
        "<=" => value <= threshold,
        "==" => value == threshold,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), pass);
}
