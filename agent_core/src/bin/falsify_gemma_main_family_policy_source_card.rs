//! `falsify_gemma_main_family_policy_source_card`
//!
//! Metadata-only witness for `F-GemmaMainFamilyPolicySourceCard`. It turns
//! Gemma 4 QAT into a preferred model-family policy without making Gemma a live
//! product default, loading model bytes, running GGUF/LiteRT/MLX, or promoting
//! L2/L3 capability.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    ArtifactBuilder, ArtifactKind, FallbackTier,
};
use agent_core::uas::{
    GemmaFamilyPolicyBand, GemmaFamilyPolicyProofRefs, GemmaFamilyPolicyStatus,
    GemmaFamilyRuntimeLane, GemmaMainFamilyPolicyCard, GemmaMainFamilyPolicySet, ProStatus,
    ProductBuild,
};

const FALSIFIER_ID: &str = "F-GemmaMainFamilyPolicySourceCard";
const FIXTURE_ID: &str = "gemma_main_family_policy_source_card_v1";
const COMMAND: &str = "Tools/falsifiers/f_gemma_main_family_policy_source_card.sh";
const RESULT: &str = "artifacts/falsifiers/gemma_main_family_policy_source_card/result.json";
const UPSTREAM_GEMMA_QAT: &str =
    "artifacts/falsifiers/gemma_qat_local_runtime_candidate_card/result.json";
const UPSTREAM_GGUF: &str =
    "artifacts/falsifiers/gguf_in_process_runtime_admission_packet/result.json";
const UPSTREAM_LITERT: &str = "artifacts/falsifiers/litertlm_native_swift_admission/result.json";
const CREATED_AT_MS: u64 = 1_779_207_200_000;
const SET_METADATA_BYTES: u64 = 64_000;

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
        "{FALSIFIER_ID}: overall_pass={} policy_card_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["policy_card_count"].value,
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
    let policy_set = build_policy_set(cards.clone())?;
    let reversed = build_policy_set(cards.iter().cloned().rev().collect())?;
    let metrics = policy_set.metrics();
    let red_results = red_fixture_results(&policy_set);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_gemma_qat_candidate_card_bound",
            Path::new(UPSTREAM_GEMMA_QAT).exists(),
        ),
        (
            "upstream_gguf_admission_packet_bound",
            Path::new(UPSTREAM_GGUF).exists(),
        ),
        (
            "upstream_litert_admission_bound",
            Path::new(UPSTREAM_LITERT).exists(),
        ),
        (
            "gemma_family_preferred_not_default",
            policy_set.family_preferred && policy_set.hardcoded_default_blocked,
        ),
        (
            "smallest_verified_lane_first_required",
            policy_set.smallest_verified_lane_first,
        ),
        (
            "abstention_required_when_proof_missing",
            policy_set.abstention_required,
        ),
        (
            "small_warmup_lanes_present",
            metrics.small_warmup_count >= 2,
        ),
        ("pro_flagship_12b_present", metrics.pro_flagship_count == 1),
        (
            "vault_large_gemmas_preserved",
            metrics.vault_research_count >= 2,
        ),
        (
            "mlx_swift_loader_blocked",
            metrics.blocked_loader_count >= 1 && red_pass(&red_results, "swift_mlx_loader_bypass"),
        ),
        (
            "gguf_and_litert_lanes_policy_only",
            cards.iter().any(|card| {
                card.runtime_lanes
                    .contains(&GemmaFamilyRuntimeLane::GgufLlamaCpp)
            }) && cards.iter().any(|card| {
                card.runtime_lanes
                    .contains(&GemmaFamilyRuntimeLane::LiteRtLm)
            }),
        ),
        (
            "next_falsifier_ladder_bound",
            metrics.required_falsifier_count >= 6,
        ),
        (
            "owner_path_byte_first_token_replay_required",
            cards.iter().all(|card| {
                card.owner_path_manifest_required
                    && card.byte_kv_app_envelope_required
                    && card.redacted_first_token_required
                    && card.same_fixture_replay_required
            }),
        ),
        (
            "quality_settings_answer_packet_required",
            cards.iter().all(|card| {
                card.quality_replay_required
                    && card.settings_visibility_required
                    && card.answer_packet_route_explanation_required
            }),
        ),
        (
            "zero_model_runtime_provider_command_bytes",
            metrics.model_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.command_executions == 0,
        ),
        (
            "no_hardcoded_live_default_or_product_claim",
            red_pass(&red_results, "hardcoded_live_default_claim")
                && red_pass(&red_results, "product_capability_claim"),
        ),
        (
            "no_mas_l2_l3_green_claim",
            red_pass(&red_results, "mas_l2_l3_promotion"),
        ),
        (
            "no_large_model_or_ssd_overclaim",
            red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "no_hidden_cloud_or_route_authority",
            red_pass(&red_results, "hidden_cloud_fallback")
                && red_pass(&red_results, "hidden_route_authority"),
        ),
        (
            "no_litert_sidecar_or_python_mlx_laundering",
            red_pass(&red_results, "litert_hidden_sidecar_claim")
                && red_pass(&red_results, "python_mlx_as_swift_claim"),
        ),
        (
            "policy_set_address_deterministic",
            policy_set.set_address == reversed.set_address,
        ),
        (
            "next_cursor_bound",
            agent_core::uas::GEMMA_MAIN_FAMILY_POLICY_SOURCE_CARD_NEXT_CURSOR
                == "gemma_qat_small_lane_owner_path_manifest",
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
        "policy_card_count",
        metrics.card_count,
        ">=",
        6,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_lane_count",
        metrics.runtime_lane_count,
        ">=",
        3,
        "lanes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_rejection_count",
        red_fixture_rejection_count,
        ">=",
        red_results.len() as u64,
        "fixtures",
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
        "command_executions",
        metrics.command_executions,
        "==",
        0,
        "commands",
    );

    measurements.insert(
        "gemma_family_policy_address".to_string(),
        agent_core::falsifier_artifacts::Measurement {
            value: serde_json::json!(policy_set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "gemma_family_policy_address".to_string(),
        agent_core::falsifier_artifacts::AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("gemma_main_family_policy_source_card:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "gemma_family_policy_address".to_string(),
        policy_set
            .set_address
            .to_string()
            .starts_with("gemma_main_family_policy_source_card:"),
    );
    measurements.insert(
        "next_cursor".to_string(),
        agent_core::falsifier_artifacts::Measurement {
            value: serde_json::json!(
                agent_core::uas::GEMMA_MAIN_FAMILY_POLICY_SOURCE_CARD_NEXT_CURSOR
            ),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        agent_core::falsifier_artifacts::AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("gemma_qat_small_lane_owner_path_manifest"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert("next_cursor".to_string(), true);

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
        anomalies: vec![],
        notes: "Builds F-GemmaMainFamilyPolicySourceCard as T1/L1 metadata only. Gemma becomes the preferred family strategy, not a live app default: E2B/E4B are warmup lanes, 12B QAT GGUF/LiteRT is the Pro Gated flagship target, 26B-A4B/31B stay Vault, MLX Swift Gemma 4 remains loader-blocked, zero model/runtime/provider bytes are loaded, no command runs, and L2/L3/product capability remain red.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn build_policy_set(
    cards: Vec<GemmaMainFamilyPolicyCard>,
) -> Result<GemmaMainFamilyPolicySet, agent_core::uas::GemmaMainFamilyPolicyError> {
    GemmaMainFamilyPolicySet::new(
        "artifact:gemma_qat_local_runtime_candidate_card:result",
        "artifact:gguf_in_process_runtime_admission_packet:result",
        "artifact:litertlm_native_swift_admission:result",
        cards,
        true,
        true,
        true,
        true,
        ProductBuild::Pro,
        ProStatus::Gated,
        SET_METADATA_BYTES,
        CREATED_AT_MS,
    )
}

fn accepted_cards() -> Vec<GemmaMainFamilyPolicyCard> {
    vec![
        policy_card(
            "gemma4_e2b_qat_warmup_policy",
            "gemma_qat_candidate:gemma4_e2b_qat_gguf_candidate",
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            GemmaFamilyPolicyBand::SmallWarmup,
            GemmaFamilyPolicyStatus::SmallLaneProbePending,
            vec![
                GemmaFamilyRuntimeLane::GgufLlamaCpp,
                GemmaFamilyRuntimeLane::LiteRtLm,
            ],
            ProStatus::Gated,
        ),
        policy_card(
            "gemma4_e4b_qat_warmup_policy",
            "gemma_qat_candidate:gemma4_e4b_qat_gguf_candidate",
            "google/gemma-4-E4B-it-qat-q4_0-gguf",
            GemmaFamilyPolicyBand::SmallWarmup,
            GemmaFamilyPolicyStatus::SmallLaneProbePending,
            vec![
                GemmaFamilyRuntimeLane::GgufLlamaCpp,
                GemmaFamilyRuntimeLane::LiteRtLm,
            ],
            ProStatus::Gated,
        ),
        policy_card(
            "gemma4_12b_qat_pro_flagship_policy",
            "gemma_qat_candidate:gemma4_12b_qat_gguf_candidate",
            "google/gemma-4-12B-it-qat-q4_0-gguf",
            GemmaFamilyPolicyBand::ProFlagship,
            GemmaFamilyPolicyStatus::ProFlagshipReplayPending,
            vec![
                GemmaFamilyRuntimeLane::GgufLlamaCpp,
                GemmaFamilyRuntimeLane::LiteRtLm,
            ],
            ProStatus::Gated,
        ),
        policy_card(
            "gemma4_26b_a4b_qat_vault_policy",
            "artifact:gemma_qat_local_runtime_candidate_card:26b_source_card_pending",
            "google/gemma-4-26B-A4B-it-qat-q4_0-gguf",
            GemmaFamilyPolicyBand::VaultResearch,
            GemmaFamilyPolicyStatus::VaultOnly,
            vec![GemmaFamilyRuntimeLane::NoRuntimeAbstention],
            ProStatus::VaultPreserved,
        ),
        policy_card(
            "gemma4_31b_qat_vault_policy",
            "gemma_qat_candidate:gemma4_31b_qat_gguf_vault_candidate",
            "google/gemma-4-31B-it-qat-q4_0-gguf",
            GemmaFamilyPolicyBand::VaultResearch,
            GemmaFamilyPolicyStatus::VaultOnly,
            vec![GemmaFamilyRuntimeLane::NoRuntimeAbstention],
            ProStatus::VaultPreserved,
        ),
        policy_card(
            "gemma4_mlx_swift_loader_blocked_policy",
            "artifact:mlx_swift_gemma4_loader_parity:blocked_pending",
            "mlx-community/gemma-4-12B-it-qat-4bit",
            GemmaFamilyPolicyBand::BlockedNativeLane,
            GemmaFamilyPolicyStatus::BlockedLoader,
            vec![
                GemmaFamilyRuntimeLane::MlxSwift,
                GemmaFamilyRuntimeLane::MlxPythonResearch,
            ],
            ProStatus::Blocked,
        ),
    ]
}

fn policy_card(
    id: &str,
    upstream_candidate_ref: &str,
    model_id: &str,
    band: GemmaFamilyPolicyBand,
    status: GemmaFamilyPolicyStatus,
    runtime_lanes: Vec<GemmaFamilyRuntimeLane>,
    pro_status: ProStatus,
) -> GemmaMainFamilyPolicyCard {
    GemmaMainFamilyPolicyCard {
        card_id: id.to_string(),
        upstream_candidate_ref: upstream_candidate_ref.to_string(),
        model_id: model_id.to_string(),
        source_refs: source_refs_for(model_id),
        runtime_lanes,
        policy_band: band,
        policy_status: status,
        product_build: ProductBuild::Pro,
        pro_status,
        proof_refs: proof_refs(id),
        required_next_falsifiers: required_falsifiers_for(band),
        metadata_bytes_read: 12_000,
        model_bytes_loaded: 0,
        runtime_bytes_loaded: 0,
        provider_calls_made: 0,
        command_executions: 0,
        owner_path_manifest_required: true,
        byte_kv_app_envelope_required: true,
        redacted_first_token_required: true,
        same_fixture_replay_required: true,
        quality_replay_required: true,
        settings_visibility_required: true,
        answer_packet_route_explanation_required: true,
        abstention_when_missing_proof: true,
        runtime_deferred: true,
        swift_mlx_loader_proven: false,
        hardcoded_default_claimed: false,
        live_default_claimed: false,
        product_capability_claimed: false,
        mas_readiness_claimed: false,
        l2_route_claimed: false,
        l3_wrv_claimed: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
        hidden_cloud_fallback_allowed: false,
        hidden_route_authority_allowed: false,
    }
}

fn source_refs_for(model_id: &str) -> Vec<String> {
    let mut refs = vec![
        "https://blog.google/innovation-and-ai/technology/developers-tools/quantization-aware-training-gemma-4/".to_string(),
        "https://developers.googleblog.com/gemma-4-12b-the-developer-guide/".to_string(),
        "https://github.com/google-ai-edge/LiteRT-LM".to_string(),
        "https://github.com/ml-explore/mlx-swift/issues/389".to_string(),
    ];
    refs.push(format!("https://huggingface.co/{model_id}"));
    refs
}

fn required_falsifiers_for(band: GemmaFamilyPolicyBand) -> Vec<String> {
    let mut required = vec![
        "F-GemmaMainFamilyPolicySourceCard".to_string(),
        "F-GemmaQATSmallLaneOwnerPathManifest".to_string(),
        "F-GemmaQATByteKVAppEnvelopePreflight".to_string(),
        "F-GemmaQATRedactedFirstTokenProbe".to_string(),
        "F-GemmaQATSameFixtureRuntimeReplay".to_string(),
        "F-LiteRTLMRuntimeAdmissionPacket".to_string(),
    ];
    if band == GemmaFamilyPolicyBand::BlockedNativeLane {
        required.push("F-MLXSwiftGemma4LoaderParityCard".to_string());
    }
    required
}

fn proof_refs(id: &str) -> GemmaFamilyPolicyProofRefs {
    GemmaFamilyPolicyProofRefs {
        falsifier_ref: format!("falsifier:F-GemmaMainFamilyPolicySourceCard:{id}"),
        rollback_ref: format!("rollback:gemma_main_family_policy:{id}"),
        run_event_log_ref: format!("run_event_log:gemma_main_family_policy:{id}"),
        answer_packet_ref: format!("answer_packet:gemma_main_family_policy:{id}"),
        compatibility_fence_ref: format!("compat:gemma_main_family_policy:{id}"),
    }
}

fn red_fixture_results(good: &GemmaMainFamilyPolicySet) -> Vec<(&'static str, bool)> {
    let fixtures: Vec<(&'static str, Box<dyn Fn() -> bool>)> = vec![
        (
            "hardcoded_live_default_claim",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[2].hardcoded_default_claimed = true;
                bad.cards[2].live_default_claimed = true;
                bad.validate().is_err()
            }),
        ),
        (
            "product_capability_claim",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[2].product_capability_claimed = true;
                bad.validate().is_err()
            }),
        ),
        (
            "mas_l2_l3_promotion",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[0].product_build = ProductBuild::Mas;
                bad.cards[0].l2_route_claimed = true;
                bad.cards[0].l3_wrv_claimed = true;
                bad.validate().is_err()
            }),
        ),
        (
            "swift_mlx_loader_bypass",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[5].swift_mlx_loader_proven = true;
                bad.validate().is_err()
            }),
        ),
        (
            "live_dense_70b_claim",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[4].live_dense_70b_claimed = true;
                bad.validate().is_err()
            }),
        ),
        (
            "ssd_as_ram_claim",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[4].ssd_as_ram_claimed = true;
                bad.validate().is_err()
            }),
        ),
        (
            "hidden_cloud_fallback",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[0].hidden_cloud_fallback_allowed = true;
                bad.validate().is_err()
            }),
        ),
        (
            "hidden_route_authority",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[0].hidden_route_authority_allowed = true;
                bad.validate().is_err()
            }),
        ),
        (
            "litert_hidden_sidecar_claim",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[2].runtime_deferred = false;
                bad.cards[2].command_executions = 1;
                bad.validate().is_err()
            }),
        ),
        (
            "python_mlx_as_swift_claim",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[5].policy_status = GemmaFamilyPolicyStatus::RuntimeLive;
                bad.validate().is_err()
            }),
        ),
        (
            "missing_owner_path_manifest",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[0].owner_path_manifest_required = false;
                bad.validate().is_err()
            }),
        ),
        (
            "missing_byte_envelope",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[0].byte_kv_app_envelope_required = false;
                bad.validate().is_err()
            }),
        ),
        (
            "missing_first_token_probe",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[0].redacted_first_token_required = false;
                bad.validate().is_err()
            }),
        ),
        (
            "missing_same_fixture_replay",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[2].same_fixture_replay_required = false;
                bad.validate().is_err()
            }),
        ),
        (
            "missing_quality_replay",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[2].quality_replay_required = false;
                bad.validate().is_err()
            }),
        ),
        (
            "missing_settings_visibility",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[0].settings_visibility_required = false;
                bad.validate().is_err()
            }),
        ),
        (
            "missing_answer_packet_explanation",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[0].answer_packet_route_explanation_required = false;
                bad.validate().is_err()
            }),
        ),
        (
            "missing_abstention",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[0].abstention_when_missing_proof = false;
                bad.validate().is_err()
            }),
        ),
        (
            "model_bytes_loaded",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[0].model_bytes_loaded = 1;
                bad.validate().is_err()
            }),
        ),
        (
            "runtime_bytes_loaded",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[0].runtime_bytes_loaded = 1;
                bad.validate().is_err()
            }),
        ),
        (
            "provider_call_made",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[0].provider_calls_made = 1;
                bad.validate().is_err()
            }),
        ),
        (
            "command_execution",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[0].command_executions = 1;
                bad.validate().is_err()
            }),
        ),
        (
            "duplicate_model_id",
            Box::new(|| {
                let mut bad = good.clone();
                bad.cards[1].model_id = bad.cards[0].model_id.clone();
                bad.validate().is_err()
            }),
        ),
        (
            "missing_policy_invariant",
            Box::new(|| {
                let mut bad = good.clone();
                bad.family_preferred = false;
                bad.validate().is_err()
            }),
        ),
        (
            "metadata_budget_exceeded",
            Box::new(|| {
                let mut bad = good.clone();
                bad.metadata_bytes = 1_000_000;
                bad.validate().is_err()
            }),
        ),
    ];
    fixtures
        .into_iter()
        .map(|(name, fixture)| (name, fixture()))
        .collect()
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(fixture, _)| *fixture == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}
