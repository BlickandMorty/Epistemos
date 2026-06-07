//! `falsify_gemma4_mtp_drafter_compatibility_card`
//!
//! Metadata-only witness for `F-Gemma4-MTP-DrafterCompatibilityCard`. It turns
//! official Gemma 4 MTP source signals and Hugging Face target/drafter model
//! cards into compatibility cards before any runtime lane can claim speedup.
//! No target model, drafter model, runtime, provider, package, or server bytes
//! are downloaded, loaded, linked, or run.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    Gemma4MtpByteScope, Gemma4MtpDrafterCompatibilityCard, Gemma4MtpDrafterCompatibilityError,
    Gemma4MtpDrafterCompatibilitySet, Gemma4MtpPromotionTier, Gemma4MtpProofRefs,
    Gemma4MtpRuntimeLane, ProStatus, ProductBuild,
    GEMMA4_MTP_DRAFTER_COMPATIBILITY_CARD_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-Gemma4-MTP-DrafterCompatibilityCard";
const FIXTURE_ID: &str = "gemma4_mtp_drafter_compatibility_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma4_mtp_drafter_compatibility_card.sh";
const RESULT: &str = "artifacts/falsifiers/gemma4_mtp_drafter_compatibility_card/result.json";
const CREATED_AT_MS: u64 = 1_779_060_700_000;
const SET_METADATA_BYTES: u64 = 128_000;

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
        "{FALSIFIER_ID}: overall_pass={} compatibility_card_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["compatibility_card_count"].value,
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
    let cards = accepted_cards();
    let set =
        Gemma4MtpDrafterCompatibilitySet::new(cards.clone(), SET_METADATA_BYTES, CREATED_AT_MS)?;
    let reversed = Gemma4MtpDrafterCompatibilitySet::new(
        cards.iter().cloned().rev().collect(),
        SET_METADATA_BYTES,
        CREATED_AT_MS,
    )?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&cards[0]);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "accepted_mtp_pair_pack_present",
            has_card(&cards, "gemma4_12b_mtp_drafter_compatibility")
                && has_card(&cards, "gemma4_e2b_mtp_drafter_compatibility"),
        ),
        (
            "official_google_mtp_source_bound",
            cards.iter().all(|card| {
                card.mtp_source_url == "https://blog.google/innovation-and-ai/technology/developers-tools/multi-token-prediction-gemma-4/"
                    && card.reported_speedup_upper_bound_bps == 30_000
                    && card.mtp_source_summary_ref == "source_summary:google-gemma4-mtp-up-to-3x"
            }),
        ),
        (
            "target_and_drafter_model_ids_bound",
            cards.iter().all(|card| card.drafter_model_id == format!("{}-assistant", card.target_model_id))
                && metrics.target_model_count == 2
                && metrics.drafter_model_count == 2,
        ),
        (
            "hf_revisions_and_license_bound",
            cards.iter().all(|card| {
                card.target_revision.len() == 40
                    && card.drafter_revision.len() == 40
                    && card.license_spdx == "Apache-2.0"
                    && card.target_model_url.starts_with("https://huggingface.co/google/")
                    && card.drafter_model_url.starts_with("https://huggingface.co/google/")
            }),
        ),
        (
            "upstream_litert_admission_bound",
            cards
                .iter()
                .all(|card| card.proof_refs.litert_admission_ref.contains("litertlm_native_swift_admission")),
        ),
        (
            "target_verification_required",
            cards.iter().all(|card| card.target_verifies_draft_tokens)
                && red_pass(&red_results, "target_verification_missing"),
        ),
        (
            "draft_token_visibility_required",
            cards.iter().all(|card| card.accepted_tokens_visible && card.rejected_tokens_visible)
                && red_pass(&red_results, "accepted_tokens_not_visible")
                && red_pass(&red_results, "rejected_tokens_not_visible"),
        ),
        (
            "final_output_target_only",
            cards.iter().all(|card| card.final_output_from_target_only)
                && red_pass(&red_results, "final_output_not_target_only"),
        ),
        (
            "hidden_alternate_and_chain_blocked",
            cards
                .iter()
                .all(|card| card.hidden_alternate_text_blocked && card.hidden_chain_blocked)
                && red_pass(&red_results, "hidden_alternate_text_allowed")
                && red_pass(&red_results, "hidden_chain_allowed"),
        ),
        (
            "quality_acceptance_latency_memory_metrics_required",
            cards.iter().all(|card| {
                card.quality_metric_required
                    && card.acceptance_metric_required
                    && card.latency_budget_required
                    && card.extra_memory_budget_required
            }) && red_pass(&red_results, "quality_metric_missing")
                && red_pass(&red_results, "acceptance_metric_missing")
                && red_pass(&red_results, "latency_budget_missing")
                && red_pass(&red_results, "extra_memory_budget_missing"),
        ),
        (
            "abstention_required",
            cards.iter().all(|card| card.abstention_required)
                && red_pass(&red_results, "abstention_missing"),
        ),
        (
            "proof_refs_bound",
            cards.iter().all(|card| {
                card.proof_refs.rollback_ref.starts_with("rollback:")
                    && card.proof_refs.run_event_log_ref.starts_with("run_event_log:")
                    && card.proof_refs.answer_packet_ref.starts_with("answer_packet:")
                    && card.proof_refs.quality_ledger_ref.starts_with("quality_ledger:")
                    && card.proof_refs.acceptance_metric_ref.starts_with("acceptance_metric:")
                    && card.proof_refs.latency_budget_ref.starts_with("latency_budget:")
                    && card.proof_refs.extra_memory_budget_ref.starts_with("extra_memory_budget:")
                    && card.proof_refs.abstention_ref.starts_with("abstain:")
            }) && red_pass(&red_results, "bad_proof_ref_prefix"),
        ),
        (
            "pro_research_t1_only",
            cards.iter().all(|card| {
                card.product_build == ProductBuild::Pro
                    && card.pro_status == ProStatus::ResearchCandidate
                    && card.promotion_tier == Gemma4MtpPromotionTier::T1L1Metadata
            }) && red_pass(&red_results, "mas_live_claim")
                && red_pass(&red_results, "pro_status_live_claim")
                && red_pass(&red_results, "promotion_tier_t2_claim"),
        ),
        (
            "runtime_deferred_and_product_blocked",
            set.runtime_deferred
                && set.product_promotion_blocked
                && set.hidden_authority_blocked
                && red_pass(&red_results, "runtime_not_deferred")
                && red_pass(&red_results, "product_promotion_not_blocked"),
        ),
        (
            "zero_target_drafter_runtime_provider_product_bytes",
            metrics.target_model_bytes_loaded == 0
                && metrics.drafter_model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.product_files_copied == 0
                && red_pass(&red_results, "target_model_bytes_loaded")
                && red_pass(&red_results, "drafter_model_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "provider_call_made")
                && red_pass(&red_results, "product_file_copied"),
        ),
        (
            "no_speed_quality_mas_l2_l3_or_large_model_claim",
            metrics.first_token_claim_count == 0
                && metrics.product_speedup_claim_count == 0
                && metrics.quality_improvement_claim_count == 0
                && metrics.mas_readiness_claim_count == 0
                && metrics.live_dense_70b_claim_count == 0
                && metrics.hidden_route_authority_count == 0
                && metrics.hidden_cloud_fallback_count == 0
                && red_pass(&red_results, "first_token_claim")
                && red_pass(&red_results, "product_speedup_claim")
                && red_pass(&red_results, "quality_improvement_claim")
                && red_pass(&red_results, "mas_readiness_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "hidden_cloud_fallback"),
        ),
        (
            "next_cursor_bound",
            GEMMA4_MTP_DRAFTER_COMPATIBILITY_CARD_NEXT_CURSOR
                == "runtime_plural_qat_lane_tournament_plan",
        ),
        (
            "mtp_compatibility_address_deterministic",
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
        "compatibility_card_count",
        metrics.card_count,
        "==",
        2,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_lane_count",
        metrics.runtime_lane_count,
        ">=",
        2,
        "lanes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_reported_speedup_upper_bound_bps",
        metrics.max_reported_speedup_upper_bound_bps,
        "==",
        30_000,
        "bps_x",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_rejection_count",
        red_fixture_rejection_count,
        ">=",
        32,
        "fixtures",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "metadata_bytes_read",
        metrics.metadata_bytes_read,
        "<=",
        128 * 1024,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "target_model_bytes_loaded",
        metrics.target_model_bytes_loaded,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "drafter_model_bytes_loaded",
        metrics.drafter_model_bytes_loaded,
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
        "mtp_compatibility_address".to_string(),
        Measurement {
            value: serde_json::Value::String(set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "mtp_compatibility_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert("mtp_compatibility_address".to_string(), true);

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
        anomalies: Vec::new(),
        notes: "Builds F-Gemma4-MTP-DrafterCompatibilityCard from official Google Gemma 4 MTP source, Hugging Face Gemma 4 target/assistant model cards, and the LiteRT-LM admission witness. Scope is T1/L1 metadata only: no runtime/model bytes, no package import, no first token, no speed benchmark, no MAS/L2/L3 product claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn accepted_cards() -> Vec<Gemma4MtpDrafterCompatibilityCard> {
    vec![
        card(
            "gemma4_12b_mtp_drafter_compatibility",
            "google/gemma-4-12B-it",
            "5926caa4ec0cac5cbfadaf4077420520de1d5205",
            "google/gemma-4-12B-it-assistant",
            "3cb659f134dcc4c9c00c98b121c07e16dd3daf42",
            Gemma4MtpRuntimeLane::LiteRtLm,
            52_000,
        ),
        card(
            "gemma4_e2b_mtp_drafter_compatibility",
            "google/gemma-4-E2B-it",
            "70af34e20bd4b7a91f0de6b22675850c43922a03",
            "google/gemma-4-E2B-it-assistant",
            "9407b1286e9601f1581aeac66acc91c5e422bb54",
            Gemma4MtpRuntimeLane::TransformersResearch,
            38_000,
        ),
    ]
}

fn card(
    card_id: &str,
    target_model_id: &str,
    target_revision: &str,
    drafter_model_id: &str,
    drafter_revision: &str,
    runtime_lane: Gemma4MtpRuntimeLane,
    metadata_bytes_read: u64,
) -> Gemma4MtpDrafterCompatibilityCard {
    Gemma4MtpDrafterCompatibilityCard {
        card_id: card_id.to_string(),
        target_model_id: target_model_id.to_string(),
        target_model_url: format!("https://huggingface.co/{target_model_id}"),
        target_revision: target_revision.to_string(),
        drafter_model_id: drafter_model_id.to_string(),
        drafter_model_url: format!("https://huggingface.co/{drafter_model_id}"),
        drafter_revision: drafter_revision.to_string(),
        license_spdx: "Apache-2.0".to_string(),
        mtp_source_url:
            "https://blog.google/innovation-and-ai/technology/developers-tools/multi-token-prediction-gemma-4/"
                .to_string(),
        mtp_source_summary_ref: "source_summary:google-gemma4-mtp-up-to-3x".to_string(),
        runtime_lane,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: Gemma4MtpPromotionTier::T1L1Metadata,
        reported_speedup_upper_bound_bps: 30_000,
        target_verifies_draft_tokens: true,
        accepted_tokens_visible: true,
        rejected_tokens_visible: true,
        final_output_from_target_only: true,
        hidden_alternate_text_blocked: true,
        hidden_chain_blocked: true,
        quality_metric_required: true,
        acceptance_metric_required: true,
        latency_budget_required: true,
        extra_memory_budget_required: true,
        abstention_required: true,
        rollback_required: true,
        run_event_log_required: true,
        answer_packet_required: true,
        runtime_deferred: true,
        l1_l2_l3_separated: true,
        product_promotion_blocked: true,
        proof_refs: Gemma4MtpProofRefs {
            litert_admission_ref:
                "artifact:litertlm_native_swift_admission:result_json_pass".to_string(),
            falsifier_ref: "falsifier:F-Gemma4-MTP-DrafterCompatibilityCard".to_string(),
            rollback_ref: "rollback:gemma4-mtp-source-card-only".to_string(),
            run_event_log_ref: "run_event_log:gemma4-mtp-draft-visibility".to_string(),
            answer_packet_ref: "answer_packet:gemma4-mtp-visible-caveat".to_string(),
            compatibility_fence_ref: "compat:gemma4-mtp-target-drafter-pair".to_string(),
            quality_ledger_ref: "quality_ledger:gemma4-mtp-target-verification".to_string(),
            acceptance_metric_ref: "acceptance_metric:gemma4-mtp-draft-token-rate".to_string(),
            latency_budget_ref: "latency_budget:gemma4-mtp-same-fixture".to_string(),
            extra_memory_budget_ref: "extra_memory_budget:gemma4-mtp-drafter".to_string(),
            abstention_ref: "abstain:gemma4-mtp-incompatible-or-over-budget".to_string(),
        },
        byte_scope: Gemma4MtpByteScope::metadata_only(metadata_bytes_read),
        first_token_claimed: false,
        product_speedup_claimed: false,
        quality_improvement_claimed: false,
        mas_readiness_claimed: false,
        live_dense_70b_claimed: false,
        hidden_route_authority_allowed: false,
        hidden_cloud_fallback_allowed: false,
    }
}

fn red_fixture_results(card: &Gemma4MtpDrafterCompatibilityCard) -> Vec<(&'static str, bool)> {
    vec![
        red(
            card,
            "target_model_missing_rejected",
            |c| {
                c.target_model_id.clear();
            },
            Gemma4MtpDrafterCompatibilityError::MissingField("target_model_id"),
        ),
        red(
            card,
            "drafter_not_assistant_rejected",
            |c| {
                c.drafter_model_id = "google/gemma-4-12B-it".to_string();
            },
            Gemma4MtpDrafterCompatibilityError::DrafterNotAssistant(
                "google/gemma-4-12B-it".to_string(),
            ),
        ),
        red(
            card,
            "target_drafter_size_mismatch_rejected",
            |c| {
                c.drafter_model_id = "google/gemma-4-E2B-it-assistant".to_string();
            },
            Gemma4MtpDrafterCompatibilityError::TargetDrafterSizeMismatch(
                "gemma4_12b_mtp_drafter_compatibility".to_string(),
            ),
        ),
        red(
            card,
            "unsupported_license_rejected",
            |c| {
                c.license_spdx = "NOASSERTION".to_string();
            },
            Gemma4MtpDrafterCompatibilityError::UnsupportedLicense("NOASSERTION".to_string()),
        ),
        red(
            card,
            "bad_target_revision_rejected",
            |c| {
                c.target_revision = "main".to_string();
            },
            Gemma4MtpDrafterCompatibilityError::BadRevision("main".to_string()),
        ),
        red(
            card,
            "non_https_source_rejected",
            |c| {
                c.mtp_source_url = "http://blog.google/mtp".to_string();
            },
            Gemma4MtpDrafterCompatibilityError::NonHttpsUrl("http://blog.google/mtp".to_string()),
        ),
        red(
            card,
            "unsupported_runtime_lane_rejected",
            |c| {
                c.runtime_lane = Gemma4MtpRuntimeLane::NoRuntime;
            },
            Gemma4MtpDrafterCompatibilityError::UnsupportedRuntimeLane,
        ),
        red(
            card,
            "mas_live_claim_rejected",
            |c| {
                c.product_build = ProductBuild::Mas;
            },
            Gemma4MtpDrafterCompatibilityError::ProductBuildNotPro,
        ),
        red(
            card,
            "pro_status_live_claim_rejected",
            |c| {
                c.pro_status = ProStatus::Live;
            },
            Gemma4MtpDrafterCompatibilityError::ProStatusNotResearchCandidate,
        ),
        red(
            card,
            "promotion_tier_t2_claim_rejected",
            |c| {
                c.promotion_tier = Gemma4MtpPromotionTier::T2L2Route;
            },
            Gemma4MtpDrafterCompatibilityError::PromotionTierNotT1,
        ),
        red(
            card,
            "unbounded_speedup_source_rejected",
            |c| {
                c.reported_speedup_upper_bound_bps = 40_000;
            },
            Gemma4MtpDrafterCompatibilityError::SpeedupSourceUnbounded,
        ),
        red(
            card,
            "target_verification_missing_rejected",
            |c| {
                c.target_verifies_draft_tokens = false;
            },
            Gemma4MtpDrafterCompatibilityError::TargetVerificationMissing,
        ),
        red(
            card,
            "accepted_tokens_not_visible_rejected",
            |c| {
                c.accepted_tokens_visible = false;
            },
            Gemma4MtpDrafterCompatibilityError::TokenVisibilityMissing,
        ),
        red(
            card,
            "rejected_tokens_not_visible_rejected",
            |c| {
                c.rejected_tokens_visible = false;
            },
            Gemma4MtpDrafterCompatibilityError::TokenVisibilityMissing,
        ),
        red(
            card,
            "final_output_not_target_only_rejected",
            |c| {
                c.final_output_from_target_only = false;
            },
            Gemma4MtpDrafterCompatibilityError::FinalOutputNotTargetOnly,
        ),
        red(
            card,
            "hidden_alternate_text_allowed_rejected",
            |c| {
                c.hidden_alternate_text_blocked = false;
            },
            Gemma4MtpDrafterCompatibilityError::HiddenAlternateTextNotBlocked,
        ),
        red(
            card,
            "hidden_chain_allowed_rejected",
            |c| {
                c.hidden_chain_blocked = false;
            },
            Gemma4MtpDrafterCompatibilityError::HiddenChainNotBlocked,
        ),
        red(
            card,
            "quality_metric_missing_rejected",
            |c| {
                c.quality_metric_required = false;
            },
            Gemma4MtpDrafterCompatibilityError::QualityMetricMissing,
        ),
        red(
            card,
            "acceptance_metric_missing_rejected",
            |c| {
                c.acceptance_metric_required = false;
            },
            Gemma4MtpDrafterCompatibilityError::AcceptanceMetricMissing,
        ),
        red(
            card,
            "latency_budget_missing_rejected",
            |c| {
                c.latency_budget_required = false;
            },
            Gemma4MtpDrafterCompatibilityError::LatencyBudgetMissing,
        ),
        red(
            card,
            "extra_memory_budget_missing_rejected",
            |c| {
                c.extra_memory_budget_required = false;
            },
            Gemma4MtpDrafterCompatibilityError::ExtraMemoryBudgetMissing,
        ),
        red(
            card,
            "abstention_missing_rejected",
            |c| {
                c.abstention_required = false;
            },
            Gemma4MtpDrafterCompatibilityError::AbstentionMissing,
        ),
        red(
            card,
            "rollback_missing_rejected",
            |c| {
                c.rollback_required = false;
            },
            Gemma4MtpDrafterCompatibilityError::RollbackMissing,
        ),
        red(
            card,
            "run_event_log_missing_rejected",
            |c| {
                c.run_event_log_required = false;
            },
            Gemma4MtpDrafterCompatibilityError::RunEventLogMissing,
        ),
        red(
            card,
            "answer_packet_missing_rejected",
            |c| {
                c.answer_packet_required = false;
            },
            Gemma4MtpDrafterCompatibilityError::AnswerPacketMissing,
        ),
        red(
            card,
            "runtime_not_deferred_rejected",
            |c| {
                c.runtime_deferred = false;
            },
            Gemma4MtpDrafterCompatibilityError::RuntimeNotDeferred,
        ),
        red(
            card,
            "layer_separation_missing_rejected",
            |c| {
                c.l1_l2_l3_separated = false;
            },
            Gemma4MtpDrafterCompatibilityError::LayerSeparationMissing,
        ),
        red(
            card,
            "product_promotion_not_blocked_rejected",
            |c| {
                c.product_promotion_blocked = false;
            },
            Gemma4MtpDrafterCompatibilityError::ProductPromotionNotBlocked,
        ),
        red(
            card,
            "bad_proof_ref_prefix_rejected",
            |c| {
                c.proof_refs.answer_packet_ref = "missing-prefix".to_string();
            },
            Gemma4MtpDrafterCompatibilityError::BadProofRefPrefix("answer_packet_ref"),
        ),
        red(
            card,
            "target_model_bytes_loaded_rejected",
            |c| {
                c.byte_scope.target_model_bytes_loaded = 1;
            },
            Gemma4MtpDrafterCompatibilityError::TargetModelBytesLoaded,
        ),
        red(
            card,
            "drafter_model_bytes_loaded_rejected",
            |c| {
                c.byte_scope.drafter_model_bytes_loaded = 1;
            },
            Gemma4MtpDrafterCompatibilityError::DrafterModelBytesLoaded,
        ),
        red(
            card,
            "runtime_bytes_loaded_rejected",
            |c| {
                c.byte_scope.runtime_bytes_loaded = 1;
            },
            Gemma4MtpDrafterCompatibilityError::RuntimeBytesLoaded,
        ),
        red(
            card,
            "provider_call_made_rejected",
            |c| {
                c.byte_scope.provider_calls_made = 1;
            },
            Gemma4MtpDrafterCompatibilityError::ProviderCallMade,
        ),
        red(
            card,
            "product_file_copied_rejected",
            |c| {
                c.byte_scope.product_files_copied = 1;
            },
            Gemma4MtpDrafterCompatibilityError::ProductFileCopied,
        ),
        red(
            card,
            "first_token_claim_rejected",
            |c| {
                c.first_token_claimed = true;
            },
            Gemma4MtpDrafterCompatibilityError::FirstTokenClaim,
        ),
        red(
            card,
            "product_speedup_claim_rejected",
            |c| {
                c.product_speedup_claimed = true;
            },
            Gemma4MtpDrafterCompatibilityError::ProductSpeedupClaim,
        ),
        red(
            card,
            "quality_improvement_claim_rejected",
            |c| {
                c.quality_improvement_claimed = true;
            },
            Gemma4MtpDrafterCompatibilityError::QualityImprovementClaim,
        ),
        red(
            card,
            "mas_readiness_claim_rejected",
            |c| {
                c.mas_readiness_claimed = true;
            },
            Gemma4MtpDrafterCompatibilityError::MasReadinessClaim,
        ),
        red(
            card,
            "live_dense_70b_claim_rejected",
            |c| {
                c.live_dense_70b_claimed = true;
            },
            Gemma4MtpDrafterCompatibilityError::LiveDense70BClaim,
        ),
        red(
            card,
            "hidden_route_authority_rejected",
            |c| {
                c.hidden_route_authority_allowed = true;
            },
            Gemma4MtpDrafterCompatibilityError::HiddenRouteAuthority,
        ),
        red(
            card,
            "hidden_cloud_fallback_rejected",
            |c| {
                c.hidden_cloud_fallback_allowed = true;
            },
            Gemma4MtpDrafterCompatibilityError::HiddenCloudFallback,
        ),
    ]
}

fn red(
    base: &Gemma4MtpDrafterCompatibilityCard,
    name: &'static str,
    mutate: impl FnOnce(&mut Gemma4MtpDrafterCompatibilityCard),
    expected: Gemma4MtpDrafterCompatibilityError,
) -> (&'static str, bool) {
    let mut card = base.clone();
    mutate(&mut card);
    let passed = match Gemma4MtpDrafterCompatibilitySet::new(
        vec![card],
        SET_METADATA_BYTES,
        CREATED_AT_MS,
    ) {
        Err(error) => error == expected,
        Ok(_) => false,
    };
    (name, passed)
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    let rejected_name = format!("{name}_rejected");
    results
        .iter()
        .find(|(candidate, _)| *candidate == name || *candidate == rejected_name.as_str())
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn has_card(cards: &[Gemma4MtpDrafterCompatibilityCard], id: &str) -> bool {
    cards.iter().any(|card| card.card_id == id)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepted_fixture_passes_all_axes() {
        let artifact = build_artifact().unwrap();
        assert!(artifact.overall_pass);
        assert_eq!(artifact.measurements["compatibility_card_count"].value, 2);
        assert_eq!(artifact.measurements["target_model_bytes_loaded"].value, 0);
        assert_eq!(artifact.measurements["drafter_model_bytes_loaded"].value, 0);
        assert_eq!(artifact.measurements["runtime_bytes_loaded"].value, 0);
    }

    #[test]
    fn red_fixture_pack_rejects_speed_runtime_and_hidden_authority() {
        let mut cards = accepted_cards();
        let card = cards.remove(0);
        let results = red_fixture_results(&card);
        assert!(red_pass(&results, "target_drafter_size_mismatch"));
        assert!(red_pass(&results, "runtime_bytes_loaded"));
        assert!(red_pass(&results, "product_speedup_claim"));
        assert!(red_pass(&results, "hidden_route_authority"));
        assert_eq!(
            results.iter().filter(|(_, pass)| *pass).count(),
            results.len()
        );
    }
}
