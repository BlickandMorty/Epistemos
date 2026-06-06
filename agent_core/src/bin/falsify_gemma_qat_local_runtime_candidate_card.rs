//! `falsify_gemma_qat_local_runtime_candidate_card`
//!
//! Metadata-only witness for `F-GemmaQAT-LocalRuntimeCandidateCard`. It turns
//! source-carded Gemma 4 QAT model research into local runtime candidate cards
//! without loading model bytes, running MLX/GGUF/LiteRT, proving loader support,
//! or promoting product capability.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    GemmaQatCandidateBand, GemmaQatFormat, GemmaQatLocalRuntimeCandidateCard,
    GemmaQatLocalRuntimeCandidateSet, GemmaQatMemoryEnvelope, GemmaQatModelSize,
    GemmaQatPromotionTier, GemmaQatProofRefs, GemmaQatRuntimeLane, ProStatus, ProductBuild,
    UasAddress,
};

const FALSIFIER_ID: &str = "F-GemmaQAT-LocalRuntimeCandidateCard";
const FIXTURE_ID: &str = "gemma_qat_local_runtime_candidate_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_qat_local_runtime_candidate_card.sh";
const RESULT: &str = "artifacts/falsifiers/gemma_qat_local_runtime_candidate_card/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/compressed_model_source_card_intake/result.json";
const CREATED_AT_MS: u64 = 1_779_034_600_000;
const SET_METADATA_BYTES: u64 = 64_000;
const GIB: u64 = 1_073_741_824;

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
    let upstream = upstream_intake_address()?;
    let cards = accepted_cards();
    let candidate_set = build_set(upstream.clone(), cards.clone())?;
    let reversed = build_set(upstream, cards.iter().cloned().rev().collect())?;
    let metrics = candidate_set.metrics();
    let red_results = red_fixture_results(&candidate_set);
    let accepted_fixture_count = cards.len() as u64;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_compressed_source_card_intake_bound",
            candidate_set
                .upstream_intake_witness_ref
                .contains("compressed_model_source_card_intake"),
        ),
        (
            "accepted_fixture_pack_present",
            has_card(&cards, "gemma4_e2b_qat_gguf_candidate")
                && has_card(&cards, "gemma4_e4b_qat_gguf_candidate")
                && has_card(&cards, "gemma4_12b_qat_gguf_candidate")
                && has_card(&cards, "gemma4_31b_qat_gguf_vault_candidate"),
        ),
        ("model_size_coverage", metrics.model_size_count >= 4),
        ("format_coverage", metrics.format_count >= 1),
        ("runtime_lane_coverage", metrics.runtime_lane_count >= 1),
        (
            "small_harness_candidates_present",
            metrics.small_harness_candidate_count >= 2,
        ),
        (
            "flagship_pro_gated_target_present",
            metrics.flagship_target_count >= 1,
        ),
        (
            "vault_research_candidate_present",
            metrics.vault_research_count >= 1,
        ),
        (
            "source_backed_hf_metadata_present",
            cards.iter().all(|card| {
                card.source_locator
                    .starts_with("https://huggingface.co/google/")
                    && card.source_revision_ref.starts_with("revision:")
                    && card.license_ref == "license:apache-2.0"
                    && card.memory.declared_file_bytes > 0
                    && card.memory.context_window_tokens > 0
            }),
        ),
        (
            "resident_bytes_not_equal_file_bytes",
            cards.iter().all(|card| {
                card.memory.estimated_resident_floor_bytes > card.memory.declared_file_bytes
            }) && red_pass(&red_results, "file_size_as_resident_memory"),
        ),
        (
            "swift_mlx_loader_claim_rejected",
            red_pass(&red_results, "swift_mlx_loader_claim")
                && red_pass(&red_results, "missing_mlx_loader_caveat"),
        ),
        (
            "mtp_speed_claim_rejected",
            red_pass(&red_results, "mtp_speedup_claim"),
        ),
        (
            "product_promotion_rejected",
            red_pass(&red_results, "product_capability_claim")
                && red_pass(&red_results, "mas_readiness_claim")
                && red_pass(&red_results, "promotion_tier_t2"),
        ),
        (
            "large_candidate_vault_only",
            red_pass(&red_results, "thirty_one_b_non_vault")
                && red_pass(&red_results, "twelve_b_small_harness"),
        ),
        (
            "hidden_authority_rejected",
            red_pass(&red_results, "hidden_cloud_fallback")
                && red_pass(&red_results, "hidden_route_authority"),
        ),
        (
            "large_model_overclaim_rejected",
            red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "zero_model_bytes_loaded",
            metrics.model_bytes_loaded == 0 && red_pass(&red_results, "model_bytes_loaded"),
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
            "set_address_deterministic",
            candidate_set.set_address == reversed.set_address,
        ),
        (
            "layer_separation_required",
            red_pass(&red_results, "set_missing_layer_separation"),
        ),
        (
            "runtime_deferred_required",
            red_pass(&red_results, "set_runtime_not_deferred"),
        ),
        (
            "metadata_budget_enforced",
            red_pass(&red_results, "metadata_budget_exceeded")
                && red_pass(&red_results, "card_metadata_budget_exceeded"),
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

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "accepted_fixture_count",
        accepted_fixture_count,
        ">=",
        4,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        28,
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
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "declared_file_bytes_total",
        metrics.declared_file_bytes_total,
        ">",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "estimated_resident_floor_bytes_total",
        metrics.estimated_resident_floor_bytes_total,
        ">",
        metrics.declared_file_bytes_total,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_bytes_loaded",
        metrics.model_bytes_loaded,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_bytes_loaded",
        metrics.runtime_bytes_loaded,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "provider_calls_made",
        metrics.provider_calls_made,
        "==",
        0,
        "calls",
    );
    measurements.insert(
        "candidate_set_address".to_string(),
        Measurement {
            value: serde_json::json!(candidate_set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "candidate_set_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("gemma_qat_local_runtime_candidate_card:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "candidate_set_address".to_string(),
        candidate_set
            .set_address
            .to_string()
            .starts_with("gemma_qat_local_runtime_candidate_card:"),
    );
    measurements.insert(
        "next_research_to_build_unit".to_string(),
        Measurement {
            value: serde_json::json!("qat_model_route_card_memory_preflight"),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_research_to_build_unit".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("qat_model_route_card_memory_preflight"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert("next_research_to_build_unit".to_string(), true);

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
        notes: "Builds F-GemmaQAT-LocalRuntimeCandidateCard from the compressed source-card intake. Scope is T1/L1 metadata only: Gemma QAT model cards may feed later memory preflight, runtime parity, and small-model harness work, but this witness proves no loadability, quality, MTP speedup, Swift MLX loader support, MAS readiness, or product capability.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_intake_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream compressed model source-card intake has not passed".into());
    }
    let address = value
        .pointer("/measurements/intake_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing upstream intake_address measurement")?;
    Ok(UasAddress::from_str(address)?)
}

fn build_set(
    upstream_intake_address: UasAddress,
    cards: Vec<GemmaQatLocalRuntimeCandidateCard>,
) -> Result<GemmaQatLocalRuntimeCandidateSet, Box<dyn std::error::Error>> {
    Ok(GemmaQatLocalRuntimeCandidateSet::from_source_cards(
        upstream_intake_address,
        "artifact:compressed_model_source_card_intake:result",
        cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        SET_METADATA_BYTES,
        true,
        true,
        true,
        CREATED_AT_MS,
    )?)
}

fn accepted_cards() -> Vec<GemmaQatLocalRuntimeCandidateCard> {
    vec![
        gguf_card(CardSpec {
            card_id: "gemma4_e2b_qat_gguf_candidate",
            upstream_card_id: "gemma4_e2b_qat_gguf",
            model_id: "google/gemma-4-E2B-it-qat-q4_0-gguf",
            model_size: GemmaQatModelSize::E2B,
            candidate_band: GemmaQatCandidateBand::SmallHarnessCandidate,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: GemmaQatPromotionTier::T1L1Metadata,
            source_sha: "1894d1fc0a19d86697abd40483f5983c867df03f",
            declared_file_bytes: 4_628_569_635,
            context_window_tokens: 131_072,
            resident_floor_bytes: 5 * GIB,
            kv_floor_bytes: 512 * 1024 * 1024,
            scratch_floor_bytes: 256 * 1024 * 1024,
        }),
        gguf_card(CardSpec {
            card_id: "gemma4_e4b_qat_gguf_candidate",
            upstream_card_id: "gemma4_e4b_qat_gguf",
            model_id: "google/gemma-4-E4B-it-qat-q4_0-gguf",
            model_size: GemmaQatModelSize::E4B,
            candidate_band: GemmaQatCandidateBand::SmallHarnessCandidate,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: GemmaQatPromotionTier::T1L1Metadata,
            source_sha: "99ef3d9bbf819591699ffa9084c4be12db1fbe6c",
            declared_file_bytes: 7_463_013_674,
            context_window_tokens: 131_072,
            resident_floor_bytes: 8 * GIB,
            kv_floor_bytes: 768 * 1024 * 1024,
            scratch_floor_bytes: 384 * 1024 * 1024,
        }),
        gguf_card(CardSpec {
            card_id: "gemma4_12b_qat_gguf_candidate",
            upstream_card_id: "gemma4_12b_qat_gguf",
            model_id: "google/gemma-4-12B-it-qat-q4_0-gguf",
            model_size: GemmaQatModelSize::TwelveB,
            candidate_band: GemmaQatCandidateBand::FlagshipProGatedTarget,
            pro_status: ProStatus::Gated,
            promotion_tier: GemmaQatPromotionTier::T1L1Metadata,
            source_sha: "f6e7774e6148da3b7f201e42ba37cf084c1db35f",
            declared_file_bytes: 11_907_350_576,
            context_window_tokens: 262_144,
            resident_floor_bytes: 13 * GIB,
            kv_floor_bytes: GIB,
            scratch_floor_bytes: 512 * 1024 * 1024,
        }),
        gguf_card(CardSpec {
            card_id: "gemma4_31b_qat_gguf_vault_candidate",
            upstream_card_id: "gemma4_31b_qat_gguf",
            model_id: "google/gemma-4-31B-it-qat-q4_0-gguf",
            model_size: GemmaQatModelSize::ThirtyOneB,
            candidate_band: GemmaQatCandidateBand::VaultResearchOnly,
            pro_status: ProStatus::VaultPreserved,
            promotion_tier: GemmaQatPromotionTier::T0Research,
            source_sha: "4a311c5261daa0702f80836f8866114943651ab0",
            declared_file_bytes: 30_697_345_596,
            context_window_tokens: 262_144,
            resident_floor_bytes: 32 * GIB,
            kv_floor_bytes: 2 * GIB,
            scratch_floor_bytes: GIB,
        }),
    ]
}

// UAS: uas:gemma-qat-candidate:fixture-spec
// Plane: Verification
// Residency: falsifier fixture metadata; not product/runtime configuration.
struct CardSpec {
    card_id: &'static str,
    upstream_card_id: &'static str,
    model_id: &'static str,
    model_size: GemmaQatModelSize,
    candidate_band: GemmaQatCandidateBand,
    pro_status: ProStatus,
    promotion_tier: GemmaQatPromotionTier,
    source_sha: &'static str,
    declared_file_bytes: u64,
    context_window_tokens: u64,
    resident_floor_bytes: u64,
    kv_floor_bytes: u64,
    scratch_floor_bytes: u64,
}

fn gguf_card(spec: CardSpec) -> GemmaQatLocalRuntimeCandidateCard {
    GemmaQatLocalRuntimeCandidateCard {
        card_id: spec.card_id.to_string(),
        upstream_source_card_ref: format!("compressed_model_source_card:{}", spec.upstream_card_id),
        model_id: spec.model_id.to_string(),
        model_size: spec.model_size,
        format: GemmaQatFormat::GgufQ4_0,
        runtime_lane: GemmaQatRuntimeLane::GgufLlamaCpp,
        candidate_band: spec.candidate_band,
        source_locator: format!("https://huggingface.co/{}", spec.model_id),
        source_revision_ref: format!("revision:{}", spec.source_sha),
        license_ref: "license:apache-2.0".to_string(),
        loader_caveat_ref: None,
        route_caveat_ref: "route_caveat:metadata_only_no_loadability_or_quality_proof".to_string(),
        product_build: ProductBuild::Pro,
        pro_status: spec.pro_status,
        promotion_tier: spec.promotion_tier,
        memory: GemmaQatMemoryEnvelope::metadata_only(
            spec.declared_file_bytes,
            spec.context_window_tokens,
            spec.resident_floor_bytes,
            spec.kv_floor_bytes,
            spec.scratch_floor_bytes,
            18_000,
        ),
        proof_refs: proof_refs(spec.card_id),
        l1_l2_l3_separated: true,
        runtime_deferred: true,
        swift_mlx_loader_proven: false,
        mtp_speedup_claimed: false,
        file_size_treated_as_resident_memory: false,
        mas_readiness_claimed: false,
        product_capability_claimed: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
        hidden_cloud_fallback_allowed: false,
        hidden_route_authority_allowed: false,
    }
}

fn proof_refs(id: &str) -> GemmaQatProofRefs {
    GemmaQatProofRefs {
        falsifier_ref: format!("falsifier:F-GemmaQAT-LocalRuntimeCandidateCard:{id}"),
        rollback_ref: format!("rollback:gemma_qat_candidate:{id}"),
        run_event_log_ref: format!("run_event_log:gemma_qat_candidate:{id}"),
        answer_packet_ref: format!("answer_packet:gemma_qat_candidate:{id}"),
        compatibility_fence_ref: format!("compat:gemma_qat_candidate:{id}"),
    }
}

fn red_fixture_results(set: &GemmaQatLocalRuntimeCandidateSet) -> Vec<(&'static str, bool)> {
    let mut results = Vec::new();
    let base_cards = set.cards.clone();
    let upstream = set.upstream_intake_address.clone();

    let mut push_card =
        |name: &'static str, mutate: fn(&mut Vec<GemmaQatLocalRuntimeCandidateCard>)| {
            let mut cards = base_cards.clone();
            mutate(&mut cards);
            results.push((name, build_set(upstream.clone(), cards).is_err()));
        };

    push_card("duplicate_card_id", |cards| {
        cards[1].card_id = cards[0].card_id.clone()
    });
    push_card("duplicate_model_id", |cards| {
        cards[1].model_id = cards[0].model_id.clone()
    });
    push_card("bad_upstream_source_card_ref", |cards| {
        cards[0].upstream_source_card_ref = "model_card:gemma4".to_string()
    });
    push_card("missing_license", |cards| cards[0].license_ref.clear());
    push_card("missing_revision", |cards| {
        cards[0].source_revision_ref.clear()
    });
    push_card("non_https_source", |cards| {
        cards[0].source_locator = "file:///tmp/gemma.gguf".to_string()
    });
    push_card("zero_declared_file_bytes", |cards| {
        cards[0].memory.declared_file_bytes = 0
    });
    push_card("zero_context_window", |cards| {
        cards[0].memory.context_window_tokens = 0
    });
    push_card("file_size_as_resident_memory", |cards| {
        cards[0].memory.estimated_resident_floor_bytes = cards[0].memory.declared_file_bytes
    });
    push_card("zero_kv_floor", |cards| {
        cards[0].memory.estimated_kv_floor_bytes = 0
    });
    push_card("model_bytes_loaded", |cards| {
        cards[0].memory.model_bytes_loaded = 1
    });
    push_card("runtime_bytes_loaded", |cards| {
        cards[0].memory.runtime_bytes_loaded = 1
    });
    push_card("provider_call_made", |cards| {
        cards[0].memory.provider_calls_made = 1
    });
    push_card("mas_product_build", |cards| {
        cards[0].product_build = ProductBuild::Mas
    });
    push_card("pro_live_status", |cards| {
        cards[0].pro_status = ProStatus::Live
    });
    push_card("promotion_tier_t2", |cards| {
        cards[0].promotion_tier = GemmaQatPromotionTier::T2L2Route
    });
    push_card("missing_mlx_loader_caveat", |cards| {
        cards[0].runtime_lane = GemmaQatRuntimeLane::MlxSwiftCandidate
    });
    push_card("swift_mlx_loader_claim", |cards| {
        cards[0].runtime_lane = GemmaQatRuntimeLane::MlxSwiftCandidate;
        cards[0].loader_caveat_ref = Some("loader_caveat:swift_mlx_gemma4_unproven".to_string());
        cards[0].swift_mlx_loader_proven = true;
    });
    push_card("mtp_speedup_claim", |cards| {
        cards[0].mtp_speedup_claimed = true
    });
    push_card("mas_readiness_claim", |cards| {
        cards[0].mas_readiness_claimed = true
    });
    push_card("product_capability_claim", |cards| {
        cards[0].product_capability_claimed = true
    });
    push_card("hidden_cloud_fallback", |cards| {
        cards[0].hidden_cloud_fallback_allowed = true
    });
    push_card("hidden_route_authority", |cards| {
        cards[0].hidden_route_authority_allowed = true
    });
    push_card("live_dense_70b_claim", |cards| {
        cards[0].live_dense_70b_claimed = true
    });
    push_card("ssd_as_ram_claim", |cards| {
        cards[0].ssd_as_ram_claimed = true
    });
    push_card("thirty_one_b_non_vault", |cards| {
        if let Some(card) = cards
            .iter_mut()
            .find(|card| card.model_size == GemmaQatModelSize::ThirtyOneB)
        {
            card.candidate_band = GemmaQatCandidateBand::SmallHarnessCandidate;
            card.pro_status = ProStatus::ResearchCandidate;
            card.promotion_tier = GemmaQatPromotionTier::T1L1Metadata;
        }
    });
    push_card("twelve_b_small_harness", |cards| {
        if let Some(card) = cards
            .iter_mut()
            .find(|card| card.model_size == GemmaQatModelSize::TwelveB)
        {
            card.candidate_band = GemmaQatCandidateBand::SmallHarnessCandidate;
        }
    });
    push_card("bad_proof_ref_prefix", |cards| {
        cards[0].proof_refs.answer_packet_ref = "packet:missing".to_string()
    });
    push_card("card_metadata_budget_exceeded", |cards| {
        cards[0].memory.metadata_bytes_read = 100_000
    });

    let set_level = [
        (
            "set_missing_layer_separation",
            build_set_with_flags(
                upstream.clone(),
                base_cards.clone(),
                false,
                true,
                true,
                SET_METADATA_BYTES,
            )
            .is_err(),
        ),
        (
            "set_runtime_not_deferred",
            build_set_with_flags(
                upstream.clone(),
                base_cards.clone(),
                true,
                false,
                true,
                SET_METADATA_BYTES,
            )
            .is_err(),
        ),
        (
            "set_product_promotion_allowed",
            build_set_with_flags(
                upstream.clone(),
                base_cards.clone(),
                true,
                true,
                false,
                SET_METADATA_BYTES,
            )
            .is_err(),
        ),
        (
            "metadata_budget_exceeded",
            build_set_with_flags(upstream, base_cards, true, true, true, 600 * 1024).is_err(),
        ),
    ];
    results.extend(set_level);
    results
}

fn build_set_with_flags(
    upstream_intake_address: UasAddress,
    cards: Vec<GemmaQatLocalRuntimeCandidateCard>,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
    metadata_bytes: u64,
) -> Result<GemmaQatLocalRuntimeCandidateSet, Box<dyn std::error::Error>> {
    Ok(GemmaQatLocalRuntimeCandidateSet::from_source_cards(
        upstream_intake_address,
        "artifact:compressed_model_source_card_intake:result",
        cards,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        metadata_bytes,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked,
        CREATED_AT_MS,
    )?)
}

fn has_card(cards: &[GemmaQatLocalRuntimeCandidateCard], id: &str) -> bool {
    cards.iter().any(|card| card.card_id == id)
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(candidate, _)| *candidate == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}
