//! `falsify_same_fixture_runtime_replay_envelope`
//!
//! Metadata-only witness for `F-SameFixtureRuntimeReplayEnvelope`. It builds
//! the minimal same-fixture replay packet required before runtime lanes can be
//! compared. It does not resolve packages, open model paths, execute commands,
//! start endpoints, reuse caches, run benchmarks, or promote product routes.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, RuntimePluralQatPromotionTier, SameFixtureRuntimeLane,
    SameFixtureRuntimeLaneStatus, SameFixtureRuntimeReplayByteBoundary,
    SameFixtureRuntimeReplayEnvelope, SameFixtureRuntimeReplayError,
    SameFixtureRuntimeReplayLaneCard, SameFixtureRuntimeReplayProofRefs,
    SAME_FIXTURE_RUNTIME_REPLAY_ENVELOPE_CURSOR, SAME_FIXTURE_RUNTIME_REPLAY_ENVELOPE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SameFixtureRuntimeReplayEnvelope";
const FIXTURE_ID: &str = "same_fixture_runtime_replay_minimal_v1";
const COMMAND: &str = "Tools/falsifiers/f_same_fixture_runtime_replay_envelope.sh";
const RESULT: &str = "artifacts/falsifiers/same_fixture_runtime_replay_envelope/result.json";
const CREATED_AT_MS: u64 = 1_779_072_000_000;
const ENVELOPE_METADATA_BYTES: u64 = 160_000;
const SAME_FIXTURE_ID: &str = "same_fixture_runtime_replay_minimal_v1";
const SAME_FIXTURE_DIGEST: &str = "fixture:sha256:same-fixture-runtime-replay-minimal-v1";
const CANONICAL_SERIALIZATION_DIGEST: &str =
    "sha256:canonical-same-fixture-runtime-replay-minimal-v1";

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
        "{FALSIFIER_ID}: overall_pass={} lane_card_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["lane_card_count"].value,
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
    let envelope = build_envelope(cards.clone())?;
    let reversed = SameFixtureRuntimeReplayEnvelope::new(
        cards.iter().cloned().rev().collect(),
        ENVELOPE_METADATA_BYTES,
        SAME_FIXTURE_ID,
        SAME_FIXTURE_DIGEST,
        CANONICAL_SERIALIZATION_DIGEST,
        CREATED_AT_MS,
    )?;
    let metrics = envelope.metrics();
    let red_results = red_fixture_results(&cards);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "accepted_lane_cards_present",
            has_lane(&cards, "gguf_llama_cpp")
                && has_lane(&cards, "litert_lm_swift")
                && has_lane(&cards, "mlx_swift_candidate")
                && has_lane(&cards, "mlx_lm_python_research")
                && has_lane(&cards, "no_runtime_abstention"),
        ),
        (
            "claim_boundary_bound",
            envelope.metadata_only
                && envelope.l1_l2_l3_separated
                && envelope.product_promotion_blocked
                && cards.iter().all(|card| {
                    card.l1_architecture_effect
                        && !card.l2_capability_effect
                        && !card.l3_wrv_effect
                        && !card.t4_build_green_effect
                        && card.still_red
                }),
        ),
        (
            "same_fixture_identity_bound",
            envelope.same_fixture_for_all_lanes
                && metrics.fixture_count == 1
                && metrics.prompt_digest_count == 1
                && cards.iter().all(|card| {
                    card.fixture_id == SAME_FIXTURE_ID
                        && card.fixture_digest == SAME_FIXTURE_DIGEST
                        && card.canonical_serialization_digest == CANONICAL_SERIALIZATION_DIGEST
                }),
        ),
        (
            "source_search_freshness_bound",
            cards.iter().all(|card| {
                card.body_read_checksum_ref
                    == "artifact:falsifiers/body_read_checksum_release_blocker_card/result.json"
                    && card.search_index_freshness_ref.is_empty()
                    && card
                        .search_index_abstention_reason
                        .starts_with("abstain:search-index-release-blocker-card-not-landed")
                    && card.source_deleted_or_tombstoned_count == 0
            }),
        ),
        (
            "prompt_tokenizer_tool_boundary_bound",
            metrics.tokenizer_digest_count == 1
                && metrics.chat_template_digest_count == 1
                && cards.iter().all(|card| {
                    card.tool_parser_policy == "policy:gemma4-tool-parser-caveated"
                        && card.hidden_chain_denied
                        && !card.raw_prompt_bytes_retained
                        && !card.raw_tool_json_bytes_retained
                }),
        ),
        (
            "runtime_lane_boundary_bound",
            cards.iter().all(|card| {
                card.server_sidecar_denied
                    && card.explicit_local_endpoint_default_denied
                    && card.command_envelope_ref.starts_with("command_envelope:")
                    && card.owner_approval_ref.starts_with("owner_approval:")
                    && card.loader_caveat_ref.starts_with("loader_caveat:")
            }),
        ),
        (
            "model_artifact_boundary_bound",
            cards.iter().all(|card| {
                !card.model_id.is_empty()
                    && !card.model_revision.is_empty()
                    && card.selected_file_manifest_digest.starts_with("sha256:")
                    && !card.local_owner_manifest_ref.is_empty()
                    && card.context_window_claim > 0
            }),
        ),
        (
            "cache_byte_boundary_bound",
            cards.iter().all(|card| {
                card.cache_salt_digest.starts_with("sha256:")
                    && card.cache_hash_algorithm == "sha256_cbor"
                    && !card.cache_reuse_allowed
                    && card.cache_reuse_visible
            }) && metrics.runtime_bytes_loaded == 0
                && metrics.model_bytes_loaded == 0
                && metrics.provider_calls_made == 0,
        ),
        (
            "proof_refs_bound",
            cards.iter().all(|card| {
                card.proof_refs.cancellation_ref.starts_with("cancel:")
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
                        .quality_metric_ref
                        .starts_with("quality_metric:")
                    && card.proof_refs.abstention_ref.starts_with("abstain:")
            }),
        ),
        (
            "pro_t0_t1_only",
            cards.iter().all(|card| {
                card.product_build == ProductBuild::Pro
                    && !matches!(card.pro_status, ProStatus::Live | ProStatus::Omega)
                    && matches!(
                        card.promotion_tier,
                        RuntimePluralQatPromotionTier::T0Research
                            | RuntimePluralQatPromotionTier::T1L1Metadata
                    )
            }),
        ),
        (
            "abstention_is_first_class",
            metrics.abstention_count == 1
                && cards.iter().any(|card| {
                    card.runtime_lane == SameFixtureRuntimeLane::NoRuntimeAbstention
                        && card.lane_status == SameFixtureRuntimeLaneStatus::DeferredAbstention
                }),
        ),
        (
            "no_hidden_sidecar_or_endpoint",
            metrics.server_sidecar_allowed_count == 0
                && metrics.local_endpoint_default_allowed_count == 0
                && envelope.hidden_authority_blocked,
        ),
        (
            "no_l2_l3_t4_product_or_70b_claim",
            metrics.l2_capability_effect_count == 0
                && metrics.l3_wrv_effect_count == 0
                && metrics.t4_build_green_effect_count == 0
                && metrics.live_dense_70b_claim_count == 0
                && metrics.ssd_as_ram_claim_count == 0,
        ),
        (
            "envelope_address_deterministic",
            envelope.envelope_address == reversed.envelope_address,
        ),
        (
            "next_cursor_bound",
            SAME_FIXTURE_RUNTIME_REPLAY_ENVELOPE_NEXT_CURSOR
                == "same_fixture_runtime_replay_envelope_invalid_fixture_matrix",
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
        "lane_card_count",
        metrics.lane_card_count,
        "==",
        5,
        "cards",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_lane_count",
        metrics.runtime_lane_count,
        "==",
        5,
        "lanes",
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
        "provider_calls_made",
        metrics.provider_calls_made,
        "==",
        0,
        "calls",
    );

    measurements.insert(
        "same_fixture_envelope_address".to_string(),
        Measurement {
            value: serde_json::json!(envelope.envelope_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "same_fixture_envelope_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!(format!("{SAME_FIXTURE_RUNTIME_REPLAY_ENVELOPE_CURSOR}:")),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "same_fixture_envelope_address".to_string(),
        envelope
            .envelope_address
            .to_string()
            .starts_with(&format!("{SAME_FIXTURE_RUNTIME_REPLAY_ENVELOPE_CURSOR}:")),
    );

    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(SAME_FIXTURE_RUNTIME_REPLAY_ENVELOPE_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("same_fixture_runtime_replay_envelope_invalid_fixture_matrix"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        SAME_FIXTURE_RUNTIME_REPLAY_ENVELOPE_NEXT_CURSOR
            == "same_fixture_runtime_replay_envelope_invalid_fixture_matrix",
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
        notes: "Builds F-SameFixtureRuntimeReplayEnvelope as a metadata-only minimal same-fixture packet. Scope is T1/L1 only: five lane cards, visible search abstention, tokenizer/template/tool-parser proof, cache salt/hash policy, sidecar/default denial, zero runtime/model/provider bytes, no package resolution, no commands, no benchmarks, no L2/L3/T4/product/live-70B claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn build_envelope(
    cards: Vec<SameFixtureRuntimeReplayLaneCard>,
) -> Result<SameFixtureRuntimeReplayEnvelope, SameFixtureRuntimeReplayError> {
    SameFixtureRuntimeReplayEnvelope::new(
        cards,
        ENVELOPE_METADATA_BYTES,
        SAME_FIXTURE_ID,
        SAME_FIXTURE_DIGEST,
        CANONICAL_SERIALIZATION_DIGEST,
        CREATED_AT_MS,
    )
}

fn has_lane(cards: &[SameFixtureRuntimeReplayLaneCard], lane_id: &str) -> bool {
    cards.iter().any(|card| card.lane_id == lane_id)
}

fn red_pass(mutator: impl FnOnce(&mut Vec<SameFixtureRuntimeReplayLaneCard>)) -> bool {
    let mut cards = accepted_cards();
    mutator(&mut cards);
    build_envelope(cards).is_err()
}

fn red_fixture_results(cards: &[SameFixtureRuntimeReplayLaneCard]) -> Vec<(&'static str, bool)> {
    vec![
        ("lane_count_under_two_rejected", {
            let mut one = cards.to_vec();
            one.truncate(1);
            build_envelope(one).is_err()
        }),
        (
            "missing_abstention_card_rejected",
            red_pass(|cards| {
                cards
                    .retain(|card| card.runtime_lane != SameFixtureRuntimeLane::NoRuntimeAbstention)
            }),
        ),
        (
            "fixture_digest_drift_rejected",
            red_pass(|cards| cards[0].fixture_digest = "fixture:sha256:different".to_string()),
        ),
        (
            "missing_body_read_ref_rejected",
            red_pass(|cards| cards[0].body_read_checksum_ref.clear()),
        ),
        (
            "missing_search_ref_without_abstention_rejected",
            red_pass(|cards| {
                cards[0].search_index_freshness_ref.clear();
                cards[0].search_index_abstention_reason.clear();
            }),
        ),
        (
            "missing_tokenizer_digest_rejected",
            red_pass(|cards| cards[0].tokenizer_digest.clear()),
        ),
        (
            "missing_chat_template_digest_rejected",
            red_pass(|cards| cards[0].chat_template_digest.clear()),
        ),
        (
            "tool_parser_policy_missing_rejected",
            red_pass(|cards| cards[0].tool_parser_policy.clear()),
        ),
        (
            "raw_prompt_retained_rejected",
            red_pass(|cards| cards[0].raw_prompt_bytes_retained = true),
        ),
        (
            "raw_tool_json_retained_rejected",
            red_pass(|cards| cards[0].raw_tool_json_bytes_retained = true),
        ),
        (
            "cache_salt_missing_rejected",
            red_pass(|cards| cards[0].cache_salt_digest.clear()),
        ),
        (
            "cache_reuse_hidden_rejected",
            red_pass(|cards| {
                cards[0].cache_reuse_allowed = true;
                cards[0].cache_reuse_visible = false;
            }),
        ),
        (
            "python_mlx_as_swift_proof_rejected",
            red_pass(|cards| {
                cards[3].runtime_lane = SameFixtureRuntimeLane::MlxSwiftCandidate;
                cards[3].lane_id = "python_mlx_as_swift".to_string();
            }),
        ),
        (
            "litert_early_preview_as_live_rejected",
            red_pass(|cards| cards[1].pro_status = ProStatus::Live),
        ),
        (
            "server_sidecar_default_rejected",
            red_pass(|cards| cards[0].server_sidecar_denied = false),
        ),
        (
            "local_endpoint_default_rejected",
            red_pass(|cards| cards[0].explicit_local_endpoint_default_denied = false),
        ),
        (
            "command_envelope_missing_rejected",
            red_pass(|cards| cards[0].command_envelope_ref.clear()),
        ),
        (
            "owner_approval_missing_rejected",
            red_pass(|cards| cards[0].owner_approval_ref.clear()),
        ),
        (
            "declared_bytes_missing_rejected",
            red_pass(|cards| cards[0].declared_selected_file_bytes = 0),
        ),
        (
            "runtime_bytes_loaded_rejected",
            red_pass(|cards| cards[0].byte_boundary.runtime_bytes_loaded = 1),
        ),
        (
            "model_bytes_loaded_rejected",
            red_pass(|cards| cards[0].byte_boundary.model_bytes_loaded = 1),
        ),
        (
            "provider_calls_made_rejected",
            red_pass(|cards| cards[0].byte_boundary.provider_calls_made = 1),
        ),
        (
            "l2_capability_claim_rejected",
            red_pass(|cards| cards[0].l2_capability_effect = true),
        ),
        (
            "l3_wrv_claim_rejected",
            red_pass(|cards| cards[0].l3_wrv_effect = true),
        ),
        (
            "t4_green_claim_rejected",
            red_pass(|cards| cards[0].t4_build_green_effect = true),
        ),
        (
            "mas_copy_allowed_rejected",
            red_pass(|cards| cards[0].mas_copy_allowed = true),
        ),
        (
            "live_dense_70b_claim_rejected",
            red_pass(|cards| cards[0].live_dense_70b_claimed = true),
        ),
        (
            "ssd_as_ram_claim_rejected",
            red_pass(|cards| cards[0].ssd_as_ram_claimed = true),
        ),
    ]
}

fn accepted_cards() -> Vec<SameFixtureRuntimeReplayLaneCard> {
    vec![
        card(
            "gguf_llama_cpp",
            SameFixtureRuntimeLane::GgufLlamaCpp,
            SameFixtureRuntimeLaneStatus::FutureProbeCandidate,
            "google/gemma-4-E2B-it-qat-q4_0-gguf",
            "https://github.com/ggml-org/llama.cpp",
            "Apache-2.0",
            3_100_000_000,
            "loader_caveat:gguf-command-envelope-unarmed",
        ),
        card(
            "litert_lm_swift",
            SameFixtureRuntimeLane::LiteRtLmSwift,
            SameFixtureRuntimeLaneStatus::BlockedUntilAdmission,
            "litert-community/gemma-4-E2B-it-litert-lm",
            "https://github.com/google-ai-edge/LiteRT-LM",
            "Apache-2.0",
            3_100_000_000,
            "loader_caveat:swift-early-preview-source-card-only",
        ),
        card(
            "mlx_swift_candidate",
            SameFixtureRuntimeLane::MlxSwiftCandidate,
            SameFixtureRuntimeLaneStatus::BlockedUntilLoader,
            "mlx-community/gemma-4-E2B-it-4bit",
            "https://github.com/ml-explore/mlx-swift",
            "MIT",
            3_100_000_000,
            "loader_caveat:gemma4-swift-loader-not-proven",
        ),
        card(
            "mlx_lm_python_research",
            SameFixtureRuntimeLane::MlxLmPythonResearch,
            SameFixtureRuntimeLaneStatus::QuarantineReference,
            "mlx-community/gemma-4-12b-8bit",
            "https://github.com/ml-explore/mlx-lm",
            "MIT",
            12_000_000_000,
            "loader_caveat:python-research-reference-not-swift-proof",
        ),
        card(
            "no_runtime_abstention",
            SameFixtureRuntimeLane::NoRuntimeAbstention,
            SameFixtureRuntimeLaneStatus::DeferredAbstention,
            "no-runtime",
            "https://github.com/BlickandMorty/Epistemos",
            "Apache-2.0",
            0,
            "loader_caveat:no-runtime-abstention",
        ),
    ]
}

fn card(
    lane_id: &str,
    runtime_lane: SameFixtureRuntimeLane,
    lane_status: SameFixtureRuntimeLaneStatus,
    model_id: &str,
    runtime_repo_url: &str,
    runtime_license_spdx: &str,
    selected_bytes: u64,
    loader_caveat_ref: &str,
) -> SameFixtureRuntimeReplayLaneCard {
    SameFixtureRuntimeReplayLaneCard {
        lane_id: lane_id.to_string(),
        runtime_lane,
        lane_status,
        fixture_id: SAME_FIXTURE_ID.to_string(),
        fixture_digest: SAME_FIXTURE_DIGEST.to_string(),
        canonical_serialization_digest: CANONICAL_SERIALIZATION_DIGEST.to_string(),
        body_read_checksum_ref:
            "artifact:falsifiers/body_read_checksum_release_blocker_card/result.json".to_string(),
        search_index_freshness_ref: String::new(),
        search_index_abstention_reason: "abstain:search-index-release-blocker-card-not-landed"
            .to_string(),
        source_revision_map_digest: "sha256:source-revision-map".to_string(),
        retrieval_packet_digest: "sha256:retrieval-packet".to_string(),
        source_deleted_or_tombstoned_count: 0,
        redacted_prompt_digest: "sha256:redacted-prompt".to_string(),
        system_prompt_digest: "sha256:system-prompt".to_string(),
        tool_schema_digest: "sha256:tool-schema".to_string(),
        tokenizer_digest: "sha256:tokenizer".to_string(),
        chat_template_digest: "sha256:chat-template".to_string(),
        tool_parser_policy: "policy:gemma4-tool-parser-caveated".to_string(),
        hidden_chain_denied: true,
        raw_prompt_bytes_retained: false,
        raw_tool_json_bytes_retained: false,
        model_id: model_id.to_string(),
        model_revision: "source-card-revision".to_string(),
        selected_file_manifest_digest: "sha256:selected-file-manifest".to_string(),
        declared_selected_file_bytes: selected_bytes,
        local_owner_manifest_ref: "owner_manifest:not-present".to_string(),
        modality_subset: "text".to_string(),
        context_window_claim: 32_768,
        runtime_repo_url: runtime_repo_url.to_string(),
        runtime_revision_or_release: "source-card-release".to_string(),
        runtime_license_spdx: runtime_license_spdx.to_string(),
        direct_cli_or_in_process: runtime_lane != SameFixtureRuntimeLane::NoRuntimeAbstention,
        server_sidecar_denied: true,
        explicit_local_endpoint_default_denied: true,
        command_envelope_ref: "command_envelope:unarmed".to_string(),
        owner_approval_ref: "owner_approval:not-granted".to_string(),
        loader_caveat_ref: loader_caveat_ref.to_string(),
        cache_policy: "salted-visible-cache-only".to_string(),
        cache_salt_digest: "sha256:cache-salt".to_string(),
        cache_hash_algorithm: "sha256_cbor".to_string(),
        cache_reuse_allowed: false,
        cache_reuse_visible: true,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: RuntimePluralQatPromotionTier::T1L1Metadata,
        l1_architecture_effect: true,
        l2_capability_effect: false,
        l3_wrv_effect: false,
        t4_build_green_effect: false,
        still_red: true,
        mas_copy_allowed: false,
        pro_copy_allowed: true,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
        metadata_bytes: 16_000,
        byte_boundary: SameFixtureRuntimeReplayByteBoundary::metadata_only(
            selected_bytes,
            selected_bytes.saturating_add(1),
            512_000_000,
            256_000_000,
            2_000_000_000,
        ),
        proof_refs: SameFixtureRuntimeReplayProofRefs {
            cancellation_ref: "cancel:same-fixture-runtime-replay".to_string(),
            rollback_ref: "rollback:same-fixture-runtime-replay".to_string(),
            run_event_log_ref: "run_event_log:same-fixture-runtime-replay".to_string(),
            answer_packet_ref: "answer_packet:same-fixture-runtime-replay".to_string(),
            quality_metric_ref: "quality_metric:same-fixture-runtime-replay".to_string(),
            abstention_ref: "abstain:same-fixture-runtime-replay".to_string(),
        },
    }
}
