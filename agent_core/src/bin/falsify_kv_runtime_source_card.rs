//! `falsify_kv_runtime_source_card`
//!
//! Metadata-only witness for `F-KVRuntimeSourceCard`. It turns Pass 61 KV,
//! page-cache, prompt-cache, offload, and activation-locality research into
//! typed source cards before any motif can influence RuntimeRouter/System G.
//! No model, KV, index, runtime, provider, server, daemon, or prompt-cache
//! bytes are opened by this witness.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    CompressedModelPromotionTier, KvAppleSiliconStatus, KvDefaultDeploymentShape, KvMasStatus,
    KvRuntimeByteScope, KvRuntimeMechanism, KvRuntimeProofRefs, KvRuntimeShape,
    KvRuntimeSourceCard, KvRuntimeSourceCardSet, KvRuntimeStorageTier, PrivacyClass, ProStatus,
    ProductBuild, ProprietaryCompressionAllowedAction, ProprietaryCompressionImportMode,
    SourceCard, SourceNoPoisonStatus, SourceSignalGraph, SourceSignalType,
    KV_RUNTIME_SOURCE_CARD_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-KVRuntimeSourceCard";
const FIXTURE_ID: &str = "kv_runtime_source_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_kv_runtime_source_card.sh";
const RESULT: &str = "artifacts/falsifiers/kv_runtime_source_card/result.json";
const CREATED_AT_MS: u64 = 1_779_050_000_000;
const SET_METADATA_BYTES: u64 = 96_000;
const UPSTREAM_INTAKE_REF: &str =
    "compressed_model_source_card_intake:pass61-source-card@1779040000000";

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
        artifact.measurements["kv_runtime_source_card_count"].value,
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
    let cards = accepted_cards(&graph);
    let set = build_set(&graph, cards.clone())?;
    let reversed = build_set(&graph, cards.iter().cloned().rev().collect())?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&graph, &cards);
    let accepted_fixture_count = cards.len() as u64;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "accepted_fixture_pack_present",
            has_card(&cards, "vllm_paged_attention")
                && has_card(&cards, "lmcache_reusable_kv")
                && has_card(&cards, "sglang_hicache_radix")
                && has_card(&cards, "ktransformers_heterogeneous_prefix")
                && has_card(&cards, "flexllmgen_offload_optimizer")
                && has_card(&cards, "powerinfer_activation_locality")
                && has_card(&cards, "kivi_asymmetric_kv")
                && has_card(&cards, "transformers_quantized_cache")
                && has_card(&cards, "llamacpp_prompt_cache"),
        ),
        (
            "source_signal_graph_bound",
            set.source_graph_address == graph.graph_address && !graph.source_cards.is_empty(),
        ),
        (
            "compressed_model_source_card_intake_bound",
            set.compressed_model_source_card_intake_ref == UPSTREAM_INTAKE_REF,
        ),
        (
            "l1_l2_l3_separated",
            set.l1_l2_l3_separated
                && set.server_daemon_product_blocked
                && set.remote_storage_product_blocked
                && set.hidden_authority_blocked
                && set.product_promotion_blocked,
        ),
        (
            "source_digests_bound",
            cards.iter().all(|card| card.source_digest == digest_for(&graph, &card.source_id)),
        ),
        (
            "source_cards_have_provenance_mode",
            cards.iter().all(|card| {
                matches!(
                    card.import_mode,
                    ProprietaryCompressionImportMode::AdapterWrap
                        | ProprietaryCompressionImportMode::CleanRoomRewrite
                        | ProprietaryCompressionImportMode::QuarantineReference
                        | ProprietaryCompressionImportMode::ResearchOnly
                )
            }),
        ),
        (
            "server_daemon_remote_product_blocked",
            red_pass(&red_results, "server_as_product")
                && red_pass(&red_results, "daemon_as_product")
                && red_pass(&red_results, "remote_storage_as_local"),
        ),
        (
            "prompt_cache_compatibility_enforced",
            red_pass(&red_results, "prompt_cache_compatibility_gap"),
        ),
        (
            "kv_quantization_caveat_enforced",
            red_pass(&red_results, "kv_quantization_caveat_gap"),
        ),
        (
            "offload_latency_throughput_enforced",
            red_pass(&red_results, "offload_latency_throughput_gap"),
        ),
        (
            "activation_locality_fallback_enforced",
            red_pass(&red_results, "activation_locality_fallback_gap"),
        ),
        (
            "apple_and_mas_promotion_blocked",
            red_pass(&red_results, "unsupported_apple_promotion")
                && red_pass(&red_results, "mas_live_from_server_daemon"),
        ),
        (
            "hidden_authority_rejected",
            red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "hidden_cache_authority"),
        ),
        (
            "zero_model_bytes_loaded",
            metrics.model_bytes_loaded == 0 && red_pass(&red_results, "model_bytes_loaded"),
        ),
        (
            "zero_kv_bytes_loaded",
            metrics.kv_bytes_loaded == 0 && red_pass(&red_results, "kv_bytes_loaded"),
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
            "zero_source_tree_bytes_imported",
            metrics.source_tree_bytes_read == 0
                && red_pass(&red_results, "source_tree_bytes_imported"),
        ),
        (
            "zero_product_files_copied",
            metrics.product_files_copied == 0 && red_pass(&red_results, "product_file_copied"),
        ),
        (
            "large_model_overclaims_rejected",
            red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim")
                && red_pass(&red_results, "product_promotion_from_research"),
        ),
        (
            "proof_refs_present",
            metrics.compatibility_fence_ref_count == accepted_fixture_count
                && metrics.quality_caveat_ref_count == accepted_fixture_count
                && metrics.mas_pro_boundary_ref_count == accepted_fixture_count
                && red_pass(&red_results, "bad_proof_ref_prefix"),
        ),
        (
            "kv_runtime_source_card_address_deterministic",
            set.set_address == reversed.set_address,
        ),
    ] {
        add_bool_axis(&mut measurements, &mut thresholds, &mut pass_per_axis, name, pass);
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
        "kv_runtime_source_card_count",
        metrics.card_count,
        ">=",
        9,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        34,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_rejection_count",
        red_fixture_rejection_count,
        "==",
        red_results.len() as u64,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mechanism_count",
        metrics.mechanism_count,
        ">=",
        7,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_shape_count",
        metrics.runtime_shape_count,
        ">=",
        5,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "deployment_shape_count",
        metrics.deployment_shape_count,
        ">=",
        5,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "storage_tier_count",
        metrics.storage_tier_count,
        ">=",
        5,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "server_framework_count",
        metrics.server_framework_count,
        ">=",
        2,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "daemon_cache_layer_count",
        metrics.daemon_cache_layer_count,
        ">=",
        1,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "distributed_cluster_count",
        metrics.distributed_cluster_count,
        ">=",
        1,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "remote_storage_source_count",
        metrics.remote_storage_source_count,
        ">=",
        2,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "local_only_source_count",
        metrics.local_only_source_count,
        ">=",
        5,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_quantization_source_count",
        metrics.kv_quantization_source_count,
        ">=",
        2,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "offload_policy_source_count",
        metrics.offload_policy_source_count,
        ">=",
        1,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "activation_locality_source_count",
        metrics.activation_locality_source_count,
        ">=",
        1,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_cache_source_count",
        metrics.prompt_cache_source_count,
        ">=",
        1,
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes_read",
        metrics.metadata_bytes_read,
        "<=",
        256 * 1024,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "set_metadata_bytes",
        SET_METADATA_BYTES,
        "<=",
        768 * 1024,
        "bytes",
    );

    measurements.insert(
        "kv_runtime_source_card_address".to_string(),
        Measurement {
            value: serde_json::json!(set.address()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "kv_runtime_source_card_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("kv_runtime_source_card:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "kv_runtime_source_card_address".to_string(),
        set.address().starts_with("kv_runtime_source_card:") && set.address().contains('@'),
    );
    measurements.insert(
        "next_backlog_unit".to_string(),
        Measurement {
            value: serde_json::json!(KV_RUNTIME_SOURCE_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_backlog_unit".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("kv_source_card_fork_and_daemon_boundary"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_backlog_unit".to_string(),
        KV_RUNTIME_SOURCE_CARD_NEXT_CURSOR == "kv_source_card_fork_and_daemon_boundary",
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
            "detail": "metadata-only KV/runtime source cards; no model, KV, index, runtime, provider, source-tree, product, server, daemon, or prompt-cache bytes loaded"
        })],
        notes: "Builds F-KVRuntimeSourceCard from Pass 61 runtime research. Scope is T1/L1 metadata only: vLLM/LMCache/SGLang/KTransformers/FlexGen/PowerInfer/KIVI/Transformers/llama.cpp motifs are source-carded for later KV/offload/cache gates without promoting L2/L3 product capability.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn red_fixture_results(
    graph: &SourceSignalGraph,
    cards: &[KvRuntimeSourceCard],
) -> Vec<(&'static str, bool)> {
    vec![
        ("empty_card_set", build_set(graph, Vec::new()).is_err()),
        (
            "duplicate_card_id",
            reject_cards(graph, cards, |cards| cards[1].card_id = cards[0].card_id.clone()),
        ),
        (
            "duplicate_source_id",
            reject_cards(graph, cards, |cards| cards[1].source_id = cards[0].source_id.clone()),
        ),
        (
            "unknown_source_id",
            reject_card(graph, cards, |card| {
                card.source_id = "source:repo:missing-kv-runtime".to_string();
                card.source_digest = digest("source:repo:missing-kv-runtime");
            }),
        ),
        (
            "blocked_source_id",
            reject_card(graph, cards, |card| {
                card.source_id = "source:repo:blocked-kv-runtime".to_string();
                card.source_digest = digest("source:repo:blocked-kv-runtime");
            }),
        ),
        (
            "source_digest_mismatch",
            reject_card(graph, cards, |card| card.source_digest = digest("wrong-digest")),
        ),
        (
            "missing_compressed_model_ref",
            reject_card(graph, cards, |card| card.compressed_model_source_card_ref = None),
        ),
        (
            "missing_cache_identity",
            reject_card(graph, cards, |card| card.cache_identity_fields.clear()),
        ),
        (
            "missing_compatibility_field",
            reject_card(graph, cards, |card| card.compatibility_fields.clear()),
        ),
        (
            "missing_byte_ledger",
            reject_card(graph, cards, |card| card.byte_ledger_fields.clear()),
        ),
        (
            "missing_cache_policy",
            reject_card(graph, cards, |card| card.cache_policy_fields.clear()),
        ),
        (
            "missing_quality_caveat",
            reject_card(graph, cards, |card| card.quality_caveat_ref = "claim:quality".to_string()),
        ),
        (
            "missing_server_daemon_boundary",
            reject_card(graph, cards, |card| card.server_daemon_boundary = "server ok".to_string()),
        ),
        (
            "missing_remote_storage_boundary",
            reject_card(graph, cards, |card| card.remote_storage_boundary = "remote ok".to_string()),
        ),
        (
            "server_as_product",
            reject_named_card(graph, cards, "vllm_paged_attention", |card| {
                card.default_deployment_shape = KvDefaultDeploymentShape::ProductEligibleInProcess;
            }),
        ),
        (
            "daemon_as_product",
            reject_named_card(graph, cards, "lmcache_reusable_kv", |card| {
                card.default_deployment_shape = KvDefaultDeploymentShape::ProGatedCommand;
            }),
        ),
        (
            "remote_storage_as_local",
            reject_named_card(graph, cards, "sglang_hicache_radix", |card| {
                card.runtime_shape = KvRuntimeShape::PythonRuntime;
                card.default_deployment_shape = KvDefaultDeploymentShape::ProGatedCommand;
            }),
        ),
        (
            "prompt_cache_compatibility_gap",
            reject_named_card(graph, cards, "llamacpp_prompt_cache", |card| {
                card.compatibility_fields
                    .retain(|field| field != "mode_compatibility");
            }),
        ),
        (
            "kv_quantization_caveat_gap",
            reject_named_card(graph, cards, "kivi_asymmetric_kv", |card| {
                card.compatibility_fields.retain(|field| field != "residual_length");
            }),
        ),
        (
            "offload_latency_throughput_gap",
            reject_named_card(graph, cards, "flexllmgen_offload_optimizer", |card| {
                card.cache_policy_fields
                    .retain(|field| field != "latency_throughput_boundary");
            }),
        ),
        (
            "activation_locality_fallback_gap",
            reject_named_card(graph, cards, "powerinfer_activation_locality", |card| {
                card.cache_policy_fields.retain(|field| field != "fallback");
            }),
        ),
        (
            "unsupported_apple_promotion",
            reject_named_card(graph, cards, "transformers_quantized_cache", |card| {
                card.apple_silicon_status = KvAppleSiliconStatus::SupportedByLocalWitness;
            }),
        ),
        (
            "mas_live_from_server_daemon",
            reject_named_card(graph, cards, "vllm_paged_attention", |card| {
                card.mas_status = KvMasStatus::MasEligibleMetadataOnly;
            }),
        ),
        (
            "hidden_route_authority",
            reject_card(graph, cards, |card| card.hidden_route_authority = true),
        ),
        (
            "hidden_cache_authority",
            reject_card(graph, cards, |card| card.hidden_cache_authority = true),
        ),
        (
            "model_bytes_loaded",
            reject_card(graph, cards, |card| card.byte_scope.model_bytes_loaded = 1),
        ),
        (
            "kv_bytes_loaded",
            reject_card(graph, cards, |card| card.byte_scope.kv_bytes_loaded = 1),
        ),
        (
            "index_bytes_loaded",
            reject_card(graph, cards, |card| card.byte_scope.index_bytes_loaded = 1),
        ),
        (
            "runtime_bytes_loaded",
            reject_card(graph, cards, |card| card.byte_scope.runtime_bytes_loaded = 1),
        ),
        (
            "provider_call_made",
            reject_card(graph, cards, |card| card.byte_scope.provider_calls_made = 1),
        ),
        (
            "source_tree_bytes_imported",
            reject_card(graph, cards, |card| card.byte_scope.source_tree_bytes_read = 1),
        ),
        (
            "product_file_copied",
            reject_card(graph, cards, |card| card.byte_scope.product_files_copied = 1),
        ),
        (
            "live_dense_70b_claim",
            reject_card(graph, cards, |card| card.live_dense_70b_claim = true),
        ),
        (
            "ssd_as_ram_claim",
            reject_card(graph, cards, |card| card.ssd_as_ram_claim = true),
        ),
        (
            "product_promotion_from_research",
            reject_card(graph, cards, |card| {
                card.promotion_tier = CompressedModelPromotionTier::T4BuildGreen;
            }),
        ),
        (
            "missing_layer_separation",
            build_set_with_flags(graph, cards.to_vec(), false, true, true, true, true).is_err(),
        ),
        (
            "metadata_budget_exceeded",
            build_set_with_metadata(graph, cards.to_vec(), 900 * 1024).is_err(),
        ),
        (
            "bad_proof_ref_prefix",
            reject_card(graph, cards, |card| {
                card.proof_refs.answer_packet_ref = "packet:wrong".to_string();
            }),
        ),
    ]
}

fn source_graph() -> Result<SourceSignalGraph, Box<dyn std::error::Error>> {
    Ok(SourceSignalGraph::intake(
        vec![
            source_card("source:repo:vllm", "https://github.com/vllm-project/vllm", "Apache-2.0"),
            source_card("source:repo:lmcache", "https://github.com/LMCache/LMCache", "Apache-2.0"),
            source_card("source:repo:sglang", "https://github.com/sgl-project/sglang", "Apache-2.0"),
            source_card("source:repo:ktransformers", "https://github.com/kvcache-ai/ktransformers", "Apache-2.0; quarantine source-card only"),
            source_card("source:repo:flexllmgen", "https://github.com/FMInference/FlexGen", "Apache-2.0; research-only source-card"),
            source_card("source:repo:powerinfer", "https://github.com/SJTU-IPADS/PowerInfer", "Apache-2.0; research-only source-card"),
            source_card("source:repo:kivi", "https://github.com/jy-yuan/KIVI", "research license note; clean-room motif only"),
            source_card("source:repo:transformers", "https://github.com/huggingface/transformers", "Apache-2.0"),
            source_card("source:repo:llama-cpp", "https://github.com/ggml-org/llama.cpp", "MIT"),
            blocked_source_card(
                "source:repo:blocked-kv-runtime",
                "https://example.invalid/blocked-kv-runtime",
            ),
        ],
        Vec::new(),
        CREATED_AT_MS,
    )?)
}

fn source_card(source_id: &str, locator: &str, license: &str) -> SourceCard {
    SourceCard::new(
        source_id,
        SourceSignalType::Repo,
        locator,
        digest(source_id),
        90,
        license,
        PrivacyClass::PublicResearch,
        SourceNoPoisonStatus::Clear,
        vec![
            "kv_runtime_source_card".to_string(),
            "large_local_model_runtime_research".to_string(),
        ],
    )
    .expect("source card")
}

fn blocked_source_card(source_id: &str, locator: &str) -> SourceCard {
    SourceCard::new(
        source_id,
        SourceSignalType::Repo,
        locator,
        digest(source_id),
        1,
        "blocked fixture; proves source-card poison path",
        PrivacyClass::PublicResearch,
        SourceNoPoisonStatus::Blocked,
        vec!["kv_runtime_source_card".to_string()],
    )
    .expect("blocked source card")
}

fn accepted_cards(graph: &SourceSignalGraph) -> Vec<KvRuntimeSourceCard> {
    vec![
        card(
            graph,
            CardSpec {
                card_id: "vllm_paged_attention",
                source_id: "source:repo:vllm",
                mechanism: KvRuntimeMechanism::VirtualBlockTable,
                runtime_shape: KvRuntimeShape::ServerFramework,
                deployment: KvDefaultDeploymentShape::ProResearchServer,
                storage_tiers: vec![KvRuntimeStorageTier::GpuMemory, KvRuntimeStorageTier::CpuMemory],
                cache_identity: vec!["block_table_id", "sequence_id", "page_size"],
                compatibility: vec!["model_id", "tokenizer_id", "block_size", "backend"],
                byte_ledger: vec!["kv_block_bytes", "eviction_bytes", "swap_bytes"],
                cache_policy: vec!["eviction_policy", "visible_abstention", "rollback"],
                apple_status: KvAppleSiliconStatus::RequiresLocalWitness,
                mas_status: KvMasStatus::DeniedServerOrDaemon,
                import_mode: ProprietaryCompressionImportMode::AdapterWrap,
                allowed_action: ProprietaryCompressionAllowedAction::AdapterOnly,
            },
        ),
        card(
            graph,
            CardSpec {
                card_id: "lmcache_reusable_kv",
                source_id: "source:repo:lmcache",
                mechanism: KvRuntimeMechanism::PrefixTreeReuse,
                runtime_shape: KvRuntimeShape::DaemonCacheLayer,
                deployment: KvDefaultDeploymentShape::ProResearchDaemon,
                storage_tiers: vec![
                    KvRuntimeStorageTier::CpuMemory,
                    KvRuntimeStorageTier::LocalSsd,
                    KvRuntimeStorageTier::DistributedKvStore,
                ],
                cache_identity: vec!["prompt_digest", "tokenizer_id", "adapter_set"],
                compatibility: vec!["model_id", "tokenizer_id", "cache_schema", "privacy_epoch"],
                byte_ledger: vec!["cache_hit_tokens", "cache_miss_tokens", "persisted_bytes"],
                cache_policy: vec!["privacy_purge_policy", "visible_abstention", "rollback"],
                apple_status: KvAppleSiliconStatus::SourceOnly,
                mas_status: KvMasStatus::DeniedServerOrDaemon,
                import_mode: ProprietaryCompressionImportMode::QuarantineReference,
                allowed_action: ProprietaryCompressionAllowedAction::QuarantineInspectBenchmark,
            },
        ),
        card(
            graph,
            CardSpec {
                card_id: "sglang_hicache_radix",
                source_id: "source:repo:sglang",
                mechanism: KvRuntimeMechanism::HierarchicalKvCache,
                runtime_shape: KvRuntimeShape::ServerFramework,
                deployment: KvDefaultDeploymentShape::ProVaultDistributed,
                storage_tiers: vec![
                    KvRuntimeStorageTier::GpuMemory,
                    KvRuntimeStorageTier::CpuMemory,
                    KvRuntimeStorageTier::RemoteObjectStore,
                    KvRuntimeStorageTier::DistributedKvStore,
                ],
                cache_identity: vec!["radix_prefix", "request_id", "tokenizer_id"],
                compatibility: vec!["model_id", "tokenizer_id", "page_size", "remote_schema"],
                byte_ledger: vec!["gpu_kv_bytes", "cpu_kv_bytes", "remote_bytes"],
                cache_policy: vec!["remote_disabled_by_default", "visible_abstention", "rollback"],
                apple_status: KvAppleSiliconStatus::SourceOnly,
                mas_status: KvMasStatus::DeniedServerOrDaemon,
                import_mode: ProprietaryCompressionImportMode::ResearchOnly,
                allowed_action: ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
            },
        ),
        card(
            graph,
            CardSpec {
                card_id: "ktransformers_heterogeneous_prefix",
                source_id: "source:repo:ktransformers",
                mechanism: KvRuntimeMechanism::HeterogeneousPlacement,
                runtime_shape: KvRuntimeShape::PythonRuntime,
                deployment: KvDefaultDeploymentShape::ResearchOnly,
                storage_tiers: vec![
                    KvRuntimeStorageTier::GpuMemory,
                    KvRuntimeStorageTier::CpuMemory,
                    KvRuntimeStorageTier::LocalSsd,
                ],
                cache_identity: vec!["layer_id", "tensor_role", "placement_epoch"],
                compatibility: vec!["model_id", "backend", "dtype", "placement_schema"],
                byte_ledger: vec!["gpu_bytes", "cpu_bytes", "disk_bytes"],
                cache_policy: vec!["owner_approval_required", "visible_abstention", "rollback"],
                apple_status: KvAppleSiliconStatus::Unsupported,
                mas_status: KvMasStatus::RequiresBoundaryReview,
                import_mode: ProprietaryCompressionImportMode::CleanRoomRewrite,
                allowed_action: ProprietaryCompressionAllowedAction::CleanRoomImplement,
            },
        ),
        card(
            graph,
            CardSpec {
                card_id: "flexllmgen_offload_optimizer",
                source_id: "source:repo:flexllmgen",
                mechanism: KvRuntimeMechanism::OffloadPolicyOptimizer,
                runtime_shape: KvRuntimeShape::PythonRuntime,
                deployment: KvDefaultDeploymentShape::ResearchOnly,
                storage_tiers: vec![
                    KvRuntimeStorageTier::GpuMemory,
                    KvRuntimeStorageTier::CpuMemory,
                    KvRuntimeStorageTier::LocalSsd,
                ],
                cache_identity: vec!["offload_plan_id", "layer_id", "batch_shape"],
                compatibility: vec!["model_id", "backend", "memory_budget", "latency_budget"],
                byte_ledger: vec!["weight_bytes", "kv_bytes", "activation_bytes", "io_bytes"],
                cache_policy: vec![
                    "latency_throughput_boundary",
                    "owner_approval_required",
                    "rollback",
                ],
                apple_status: KvAppleSiliconStatus::Unsupported,
                mas_status: KvMasStatus::RequiresBoundaryReview,
                import_mode: ProprietaryCompressionImportMode::ResearchOnly,
                allowed_action: ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
            },
        ),
        card(
            graph,
            CardSpec {
                card_id: "powerinfer_activation_locality",
                source_id: "source:repo:powerinfer",
                mechanism: KvRuntimeMechanism::ActivationLocality,
                runtime_shape: KvRuntimeShape::CppRuntime,
                deployment: KvDefaultDeploymentShape::ResearchOnly,
                storage_tiers: vec![KvRuntimeStorageTier::CpuMemory, KvRuntimeStorageTier::LocalSsd],
                cache_identity: vec!["predictor_ref", "neuron_cluster_id", "task_signature"],
                compatibility: vec!["model_id", "activation_predictor", "backend", "fallback"],
                byte_ledger: vec!["hot_neuron_bytes", "cold_neuron_bytes", "miss_bytes"],
                cache_policy: vec!["fallback", "miss_ledger", "visible_abstention", "rollback"],
                apple_status: KvAppleSiliconStatus::RequiresLocalWitness,
                mas_status: KvMasStatus::RequiresBoundaryReview,
                import_mode: ProprietaryCompressionImportMode::CleanRoomRewrite,
                allowed_action: ProprietaryCompressionAllowedAction::CleanRoomImplement,
            },
        ),
        card(
            graph,
            CardSpec {
                card_id: "kivi_asymmetric_kv",
                source_id: "source:repo:kivi",
                mechanism: KvRuntimeMechanism::KvQuantization,
                runtime_shape: KvRuntimeShape::PythonRuntime,
                deployment: KvDefaultDeploymentShape::ResearchOnly,
                storage_tiers: vec![KvRuntimeStorageTier::CpuMemory],
                cache_identity: vec!["kv_codec_id", "layer_id", "token_span"],
                compatibility: vec!["backend", "nbits", "axis", "group_size", "residual_length"],
                byte_ledger: vec!["compressed_kv_bytes", "residual_kv_bytes", "quality_delta"],
                cache_policy: vec!["quality_cliff_test", "fallback", "rollback"],
                apple_status: KvAppleSiliconStatus::RequiresLocalWitness,
                mas_status: KvMasStatus::RequiresBoundaryReview,
                import_mode: ProprietaryCompressionImportMode::ResearchOnly,
                allowed_action: ProprietaryCompressionAllowedAction::SourceCardPriorOnly,
            },
        ),
        card(
            graph,
            CardSpec {
                card_id: "transformers_quantized_cache",
                source_id: "source:repo:transformers",
                mechanism: KvRuntimeMechanism::KvQuantization,
                runtime_shape: KvRuntimeShape::PythonRuntime,
                deployment: KvDefaultDeploymentShape::ResearchOnly,
                storage_tiers: vec![KvRuntimeStorageTier::CpuMemory],
                cache_identity: vec!["cache_layer_id", "token_span", "cache_backend"],
                compatibility: vec!["backend", "nbits", "axis", "group_size", "residual_length"],
                byte_ledger: vec!["compressed_kv_bytes", "residual_kv_bytes", "quality_delta"],
                cache_policy: vec!["quality_cliff_test", "fallback", "rollback"],
                apple_status: KvAppleSiliconStatus::RequiresLocalWitness,
                mas_status: KvMasStatus::RequiresBoundaryReview,
                import_mode: ProprietaryCompressionImportMode::AdapterWrap,
                allowed_action: ProprietaryCompressionAllowedAction::AdapterOnly,
            },
        ),
        card(
            graph,
            CardSpec {
                card_id: "llamacpp_prompt_cache",
                source_id: "source:repo:llama-cpp",
                mechanism: KvRuntimeMechanism::PromptCacheFile,
                runtime_shape: KvRuntimeShape::CliCommand,
                deployment: KvDefaultDeploymentShape::ProGatedCommand,
                storage_tiers: vec![
                    KvRuntimeStorageTier::PromptCacheFile,
                    KvRuntimeStorageTier::LocalSsd,
                ],
                cache_identity: vec!["model_id", "tokenizer_id", "prompt_digest", "cache_file_digest"],
                compatibility: vec![
                    "model_id",
                    "tokenizer_id",
                    "prompt_digest",
                    "context_window",
                    "mode_compatibility",
                ],
                byte_ledger: vec!["prompt_cache_bytes", "hit_tokens", "miss_tokens"],
                cache_policy: vec!["file_lock", "privacy_purge_policy", "rollback"],
                apple_status: KvAppleSiliconStatus::RequiresLocalWitness,
                mas_status: KvMasStatus::RequiresBoundaryReview,
                import_mode: ProprietaryCompressionImportMode::AdapterWrap,
                allowed_action: ProprietaryCompressionAllowedAction::AdapterOnly,
            },
        ),
    ]
}

// UAS: uas:kv-runtime-source-card:fixture-spec
// Plane: Verification
// Residency: compile-time fixture shape only; no runtime/source bytes opened.
struct CardSpec {
    card_id: &'static str,
    source_id: &'static str,
    mechanism: KvRuntimeMechanism,
    runtime_shape: KvRuntimeShape,
    deployment: KvDefaultDeploymentShape,
    storage_tiers: Vec<KvRuntimeStorageTier>,
    cache_identity: Vec<&'static str>,
    compatibility: Vec<&'static str>,
    byte_ledger: Vec<&'static str>,
    cache_policy: Vec<&'static str>,
    apple_status: KvAppleSiliconStatus,
    mas_status: KvMasStatus,
    import_mode: ProprietaryCompressionImportMode,
    allowed_action: ProprietaryCompressionAllowedAction,
}

fn card(graph: &SourceSignalGraph, spec: CardSpec) -> KvRuntimeSourceCard {
    KvRuntimeSourceCard {
        card_id: spec.card_id.to_string(),
        source_id: spec.source_id.to_string(),
        source_digest: digest_for(graph, spec.source_id),
        compressed_model_source_card_ref: Some(format!(
            "compressed_model_source_card:{}",
            spec.card_id
        )),
        project_ref: format!("project:{}", spec.card_id),
        mechanism: spec.mechanism,
        runtime_shape: spec.runtime_shape,
        default_deployment_shape: spec.deployment,
        storage_tiers: spec.storage_tiers,
        cache_identity_fields: strings(spec.cache_identity),
        compatibility_fields: strings(spec.compatibility),
        byte_ledger_fields: strings(spec.byte_ledger),
        cache_policy_fields: strings(spec.cache_policy),
        quality_caveat_ref: format!("quality:{}", spec.card_id),
        server_daemon_boundary: format!("boundary:server-daemon:{}", spec.card_id),
        remote_storage_boundary: format!("boundary:remote-storage:{}", spec.card_id),
        apple_silicon_status: spec.apple_status,
        mas_status: spec.mas_status,
        import_mode: spec.import_mode,
        allowed_action: spec.allowed_action,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: CompressedModelPromotionTier::T1L1Metadata,
        proof_refs: KvRuntimeProofRefs {
            falsifier_ref: format!("falsifier:{}", spec.card_id),
            rollback_ref: format!("rollback:{}", spec.card_id),
            run_event_log_ref: format!("run_event_log:{}", spec.card_id),
            answer_packet_ref: format!("answer_packet:{}", spec.card_id),
            compatibility_fence_ref: format!("compat:{}", spec.card_id),
            privacy_policy_ref: format!("privacy:{}", spec.card_id),
            quality_caveat_ref: format!("quality:{}", spec.card_id),
            mas_pro_boundary_ref: format!("mas_pro:{}", spec.card_id),
        },
        byte_scope: KvRuntimeByteScope::metadata_only(2_048),
        hidden_route_authority: false,
        hidden_cache_authority: false,
        live_dense_70b_claim: false,
        ssd_as_ram_claim: false,
        l2_l3_promotion_claim: false,
    }
}

fn build_set(
    graph: &SourceSignalGraph,
    cards: Vec<KvRuntimeSourceCard>,
) -> Result<KvRuntimeSourceCardSet, Box<dyn std::error::Error>> {
    build_set_with_metadata(graph, cards, SET_METADATA_BYTES)
}

fn build_set_with_metadata(
    graph: &SourceSignalGraph,
    cards: Vec<KvRuntimeSourceCard>,
    metadata_bytes: u64,
) -> Result<KvRuntimeSourceCardSet, Box<dyn std::error::Error>> {
    Ok(KvRuntimeSourceCardSet::from_source_graph(
        graph,
        UPSTREAM_INTAKE_REF,
        cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        metadata_bytes,
        true,
        true,
        true,
        true,
        true,
        CREATED_AT_MS,
    )?)
}

fn build_set_with_flags(
    graph: &SourceSignalGraph,
    cards: Vec<KvRuntimeSourceCard>,
    l1_l2_l3_separated: bool,
    server_daemon_product_blocked: bool,
    remote_storage_product_blocked: bool,
    hidden_authority_blocked: bool,
    product_promotion_blocked: bool,
) -> Result<KvRuntimeSourceCardSet, Box<dyn std::error::Error>> {
    Ok(KvRuntimeSourceCardSet::from_source_graph(
        graph,
        UPSTREAM_INTAKE_REF,
        cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        SET_METADATA_BYTES,
        l1_l2_l3_separated,
        server_daemon_product_blocked,
        remote_storage_product_blocked,
        hidden_authority_blocked,
        product_promotion_blocked,
        CREATED_AT_MS,
    )?)
}

fn reject_card(
    graph: &SourceSignalGraph,
    cards: &[KvRuntimeSourceCard],
    mutate: impl FnOnce(&mut KvRuntimeSourceCard),
) -> bool {
    let mut cloned = cards.to_vec();
    mutate(&mut cloned[0]);
    build_set(graph, cloned).is_err()
}

fn reject_named_card(
    graph: &SourceSignalGraph,
    cards: &[KvRuntimeSourceCard],
    card_id: &str,
    mutate: impl FnOnce(&mut KvRuntimeSourceCard),
) -> bool {
    let mut cloned = cards.to_vec();
    let card = cloned
        .iter_mut()
        .find(|card| card.card_id == card_id)
        .expect("fixture card");
    mutate(card);
    build_set(graph, cloned).is_err()
}

fn reject_cards(
    graph: &SourceSignalGraph,
    cards: &[KvRuntimeSourceCard],
    mutate: impl FnOnce(&mut Vec<KvRuntimeSourceCard>),
) -> bool {
    let mut cloned = cards.to_vec();
    mutate(&mut cloned);
    build_set(graph, cloned).is_err()
}

fn has_card(cards: &[KvRuntimeSourceCard], card_id: &str) -> bool {
    cards.iter().any(|card| card.card_id == card_id)
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(case, _)| *case == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn strings(values: Vec<&str>) -> Vec<String> {
    values.into_iter().map(str::to_string).collect()
}

fn digest_for(graph: &SourceSignalGraph, source_id: &str) -> String {
    graph
        .source_cards
        .iter()
        .find(|card| card.source_id == source_id)
        .map(|card| card.digest.clone())
        .expect("source present")
}

fn digest(input: &str) -> String {
    format!("blake3:{}", blake3::hash(input.as_bytes()).to_hex())
}
