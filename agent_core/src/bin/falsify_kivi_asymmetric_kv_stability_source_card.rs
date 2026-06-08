//! `falsify_kivi_asymmetric_kv_stability_source_card`
//!
//! Metadata-only witness for `F-KIVIAsymmetricKVStabilitySourceCard`. It
//! source-cards KIVI/asymmetric 2-bit KV research and stability proof slots
//! without importing CUDA/Python code, quantizing KV, running benchmarks, or
//! loading model/runtime bytes.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    canonical_kivi_asymmetric_kv_stability_source_card, KiviAsymmetricKvStabilityError,
    KiviAsymmetricKvStabilitySourceCard, KiviAsymmetricKvStabilitySourceCardSet, KiviBackendLane,
    KiviKvAxisPolicy, KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_CURSOR,
    KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_ID,
    KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_NEXT_CURSOR,
    LLAMA_CPP_SLOT_PROMPT_CACHE_COMMAND_CARD_ID,
};

const FALSIFIER_ID: &str = KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_ID;
const COMMAND: &str = "Tools/falsifiers/f_kivi_asymmetric_kv_stability_source_card.sh";
const RESULT: &str = "artifacts/falsifiers/kivi_asymmetric_kv_stability_source_card/result.json";
const FIXTURE_ID: &str = "kivi_asymmetric_kv_stability_source_card_v1";
const CREATED_AT_MS: u64 = 1_779_158_400_000;
const SET_METADATA_BYTES: u64 = 112_000;
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/llama_cpp_slot_prompt_cache_command_card/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} proof_slot_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["proof_slot_count"].value,
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
    let upstream_present = upstream_artifact_passes(Path::new(UPSTREAM_RESULT));
    let card = canonical_kivi_asymmetric_kv_stability_source_card();
    let set = build_set(card.clone())?;
    let mut reversed = card.clone();
    reversed.backend_lanes.reverse();
    reversed.kv_axis_policies.reverse();
    reversed.proof_slots.reverse();
    let reversed = build_set(reversed)?;
    let metrics = set.metrics();
    let red_results = red_fixture_results();
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        ("upstream_llama_cpp_slot_card_passed", upstream_present),
        (
            "primary_sources_bound",
            card.arxiv_url == "https://arxiv.org/abs/2402.02750"
                && card.github_url == "https://github.com/jy-yuan/KIVI"
                && card.source_retrieval_digest.starts_with("sha256:")
                && card.arxiv_version == "v2-2024-07-25"
                && card.venue == "ICML2024"
                && card.repo_license == "MIT",
        ),
        (
            "backend_caveats_bound",
            metrics.backend_lane_count == 4
                && card.backend_lanes.contains(&KiviBackendLane::CudaResearch)
                && card
                    .backend_lanes
                    .contains(&KiviBackendLane::AppleSiliconUnproven)
                && card
                    .backend_lanes
                    .contains(&KiviBackendLane::RuntimeRouterDenied),
        ),
        (
            "asymmetric_kv_axis_policy_bound",
            metrics.kv_axis_policy_count == 2
                && card
                    .kv_axis_policies
                    .contains(&KiviKvAxisPolicy::KeyPerChannel)
                && card
                    .kv_axis_policies
                    .contains(&KiviKvAxisPolicy::ValuePerToken)
                && card.k_bits == 2
                && card.v_bits == 2,
        ),
        (
            "residual_fp_policy_bound",
            card.group_size_required
                && card.residual_length_required
                && card.residual_full_precision_required
                && card.residual_dtype == "fp16",
        ),
        (
            "source_claims_caveated",
            card.tuning_free_claim_source_carded
                && card.quality_preservation_claim_caveated
                && card.memory_reduction_claim_caveated
                && card.throughput_claim_caveated
                && card.apple_silicon_runtime_unproven,
        ),
        ("stability_proof_slots_bound", metrics.proof_slot_count == 8),
        (
            "proof_refs_bound",
            card.proof_refs.rollback_ref.starts_with("rollback:")
                && card
                    .proof_refs
                    .run_event_log_ref
                    .starts_with("run_event_log:")
                && card
                    .proof_refs
                    .answer_packet_ref
                    .starts_with("answer_packet:")
                && card.proof_refs.abstention_ref.starts_with("abstain:")
                && card.proof_refs.caveat_ref.starts_with("caveat:"),
        ),
        (
            "zero_loaded_or_opened_bytes",
            metrics.model_bytes_loaded == 0
                && metrics.kv_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.source_tree_bytes_opened == 0
                && metrics.cuda_kernel_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.benchmark_bytes_opened == 0
                && metrics.product_bytes_opened == 0,
        ),
        (
            "no_import_route_or_hidden_authority",
            metrics.direct_import_allowed_count == 0
                && metrics.route_authority_allowed_count == 0
                && metrics.hidden_cache_authority_count == 0,
        ),
        (
            "no_raw_logs_live_low_bit_or_quality_laundering",
            metrics.raw_prompt_logged_count == 0
                && metrics.raw_token_logged_count == 0
                && metrics.low_bit_kv_live_claim_count == 0
                && metrics.quality_green_claim_count == 0
                && metrics.memory_fit_claim_count == 0,
        ),
        (
            "no_mas_l2_l3_live_70b_or_ssd_as_ram_claim",
            metrics.mas_promotion_count == 0
                && metrics.l2_green_claim_count == 0
                && metrics.l3_green_claim_count == 0
                && metrics.live_dense_70b_claim_count == 0
                && metrics.ssd_as_ram_claim_count == 0,
        ),
        (
            "kivi_stability_address_deterministic",
            set.set_address == reversed.set_address,
        ),
        (
            "next_cursor_bound",
            KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_NEXT_CURSOR
                == "kv_offload_tier_budget_envelope",
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
        "card_count",
        metrics.card_count,
        "==",
        1,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "backend_lane_count",
        metrics.backend_lane_count,
        "==",
        4,
        "lanes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_axis_policy_count",
        metrics.kv_axis_policy_count,
        "==",
        2,
        "policies",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_slot_count",
        metrics.proof_slot_count,
        "==",
        8,
        "slots",
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
        "kv_bytes_loaded",
        metrics.kv_bytes_loaded,
        "==",
        0,
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

    measurements.insert(
        "kivi_stability_address".to_string(),
        Measurement {
            value: serde_json::json!(set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "kivi_stability_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!(format!(
                "{KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_CURSOR}:"
            )),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "kivi_stability_address".to_string(),
        set.set_address.to_string().starts_with(&format!(
            "{KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_CURSOR}:"
        )),
    );

    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("kv_offload_tier_budget_envelope"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        KIVI_ASYMMETRIC_KV_STABILITY_SOURCE_CARD_NEXT_CURSOR == "kv_offload_tier_budget_envelope",
    );

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
        notes: "Builds F-KIVIAsymmetricKVStabilitySourceCard as a metadata-only Pass 132 source-card witness. Scope is T1/L1 only: KIVI arXiv/GitHub source facts, key per-channel and value per-token 2-bit policy, residual full-precision policy, backend caveats, required stability proof slots, rollback, RunEventLog, AnswerPacket, abstention, zero model/KV/runtime/source/benchmark/product bytes, no import, no route authority, no L2/L3/product/live-70B/SSD-as-RAM claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn build_set(
    card: KiviAsymmetricKvStabilitySourceCard,
) -> Result<KiviAsymmetricKvStabilitySourceCardSet, KiviAsymmetricKvStabilityError> {
    KiviAsymmetricKvStabilitySourceCardSet::new(card, SET_METADATA_BYTES, CREATED_AT_MS)
}

fn upstream_artifact_passes(path: &Path) -> bool {
    let Ok(bytes) = std::fs::read(path) else {
        return false;
    };
    let Ok(value) = serde_json::from_slice::<serde_json::Value>(&bytes) else {
        return false;
    };
    value
        .get("falsifier_id")
        .and_then(|value| value.as_str())
        .is_some_and(|id| id == LLAMA_CPP_SLOT_PROMPT_CACHE_COMMAND_CARD_ID)
        && value
            .get("overall_pass")
            .and_then(|value| value.as_bool())
            .unwrap_or(false)
}

fn red_pass(mutator: impl FnOnce(&mut KiviAsymmetricKvStabilitySourceCard)) -> bool {
    let mut card = canonical_kivi_asymmetric_kv_stability_source_card();
    mutator(&mut card);
    build_set(card).is_err()
}

fn red_fixture_results() -> Vec<(&'static str, bool)> {
    vec![
        (
            "missing_upstream_rejected",
            red_pass(|card| card.upstream_falsifier_id.clear()),
        ),
        (
            "missing_arxiv_source_rejected",
            red_pass(|card| card.arxiv_url.clear()),
        ),
        (
            "missing_github_source_rejected",
            red_pass(|card| card.github_url.clear()),
        ),
        (
            "wrong_license_rejected",
            red_pass(|card| card.repo_license = "unknown".to_string()),
        ),
        (
            "missing_backend_lane_rejected",
            red_pass(|card| {
                card.backend_lanes.pop();
            }),
        ),
        (
            "missing_apple_silicon_caveat_rejected",
            red_pass(|card| {
                card.backend_lanes
                    .retain(|lane| *lane != KiviBackendLane::AppleSiliconUnproven);
            }),
        ),
        (
            "missing_key_per_channel_rejected",
            red_pass(|card| {
                card.kv_axis_policies
                    .retain(|policy| *policy != KiviKvAxisPolicy::KeyPerChannel);
            }),
        ),
        (
            "missing_value_per_token_rejected",
            red_pass(|card| {
                card.kv_axis_policies
                    .retain(|policy| *policy != KiviKvAxisPolicy::ValuePerToken);
            }),
        ),
        ("wrong_k_bits_rejected", red_pass(|card| card.k_bits = 4)),
        ("wrong_v_bits_rejected", red_pass(|card| card.v_bits = 4)),
        (
            "missing_group_size_rejected",
            red_pass(|card| card.group_size_required = false),
        ),
        (
            "missing_residual_length_rejected",
            red_pass(|card| card.residual_length_required = false),
        ),
        (
            "missing_residual_fp_rejected",
            red_pass(|card| card.residual_full_precision_required = false),
        ),
        (
            "quality_claim_uncaveated_rejected",
            red_pass(|card| card.quality_preservation_claim_caveated = false),
        ),
        (
            "memory_claim_uncaveated_rejected",
            red_pass(|card| card.memory_reduction_claim_caveated = false),
        ),
        (
            "throughput_claim_uncaveated_rejected",
            red_pass(|card| card.throughput_claim_caveated = false),
        ),
        (
            "missing_stability_proof_slot_rejected",
            red_pass(|card| {
                card.proof_slots.pop();
            }),
        ),
        (
            "missing_rollback_rejected",
            red_pass(|card| card.proof_refs.rollback_ref.clear()),
        ),
        (
            "missing_answer_packet_rejected",
            red_pass(|card| card.proof_refs.answer_packet_ref.clear()),
        ),
        (
            "direct_import_rejected",
            red_pass(|card| card.direct_import_allowed = true),
        ),
        (
            "clean_room_missing_rejected",
            red_pass(|card| card.clean_room_rewrite_required = false),
        ),
        (
            "route_authority_rejected",
            red_pass(|card| card.route_authority_allowed = true),
        ),
        (
            "hidden_cache_authority_rejected",
            red_pass(|card| card.hidden_cache_authority = true),
        ),
        (
            "kv_bytes_loaded_rejected",
            red_pass(|card| card.byte_ledger.kv_bytes_loaded = 1),
        ),
        (
            "runtime_bytes_loaded_rejected",
            red_pass(|card| card.byte_ledger.runtime_bytes_loaded = 1),
        ),
        (
            "source_tree_bytes_opened_rejected",
            red_pass(|card| card.byte_ledger.source_tree_bytes_opened = 1),
        ),
        (
            "benchmark_bytes_opened_rejected",
            red_pass(|card| card.byte_ledger.benchmark_bytes_opened = 1),
        ),
        (
            "raw_prompt_log_rejected",
            red_pass(|card| card.raw_prompt_logged = true),
        ),
        (
            "raw_token_log_rejected",
            red_pass(|card| card.raw_token_logged = true),
        ),
        (
            "low_bit_kv_live_claim_rejected",
            red_pass(|card| card.low_bit_kv_live_claimed = true),
        ),
        (
            "quality_green_claim_rejected",
            red_pass(|card| card.quality_green_claimed = true),
        ),
        (
            "memory_fit_claim_rejected",
            red_pass(|card| card.memory_fit_claimed = true),
        ),
        (
            "mas_promotion_rejected",
            red_pass(|card| card.mas_promoted = true),
        ),
        (
            "l2_green_claim_rejected",
            red_pass(|card| card.l2_green_claimed = true),
        ),
        (
            "l3_green_claim_rejected",
            red_pass(|card| card.l3_green_claimed = true),
        ),
        (
            "live_dense_70b_claim_rejected",
            red_pass(|card| card.live_dense_70b_claimed = true),
        ),
        (
            "ssd_as_ram_claim_rejected",
            red_pass(|card| card.ssd_as_ram_claimed = true),
        ),
    ]
}
