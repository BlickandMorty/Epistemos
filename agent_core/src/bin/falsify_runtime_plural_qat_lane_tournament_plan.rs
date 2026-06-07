//! `falsify_runtime_plural_qat_lane_tournament_plan`
//!
//! Metadata-only witness for `F-RuntimePlural-QATLaneTournamentPlan`. It turns
//! current GGUF/llama.cpp, LiteRT-LM, MLX Swift, MLX-LM, Gemma QAT, and MTP
//! source cards into one same-fixture tournament contract. It does not resolve
//! packages, download models, run commands, execute benchmarks, start servers,
//! or declare a runtime winner.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, RuntimePluralQatByteLedger, RuntimePluralQatLane,
    RuntimePluralQatLaneCard, RuntimePluralQatLaneStatus, RuntimePluralQatLaneTournamentPlan,
    RuntimePluralQatPromotionTier, RuntimePluralQatProofRefs, RuntimePluralQatTournamentError,
    RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_PLAN_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-RuntimePlural-QATLaneTournamentPlan";
const FIXTURE_ID: &str = "runtime_plural_qat_lane_tournament_plan_v1";
const COMMAND: &str = "Tools/falsifiers/f_runtime_plural_qat_lane_tournament_plan.sh";
const RESULT: &str = "artifacts/falsifiers/runtime_plural_qat_lane_tournament_plan/result.json";
const CREATED_AT_MS: u64 = 1_779_061_300_000;
const SET_METADATA_BYTES: u64 = 180_000;
const SAME_FIXTURE_ID: &str = "redacted_large_local_agentic_fixture_v1";
const SAME_FIXTURE_HASH_REF: &str = "fixture:sha256:runtime-plural-redacted-agentic-fixture-v1";

const UPSTREAM_LITERT_ARTIFACT: &str =
    "artifacts/falsifiers/litertlm_native_swift_admission/result.json";
const UPSTREAM_MTP_ARTIFACT: &str =
    "artifacts/falsifiers/gemma4_mtp_drafter_compatibility_card/result.json";
const UPSTREAM_QAT_PREFLIGHT_ARTIFACT: &str =
    "artifacts/falsifiers/qat_model_route_card_memory_preflight/result.json";
const UPSTREAM_PACKET_ARTIFACT: &str =
    "artifacts/falsifiers/compressed_route_answer_packet_dry_run/result.json";

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
    let plan = build_plan(cards.clone(), true)?;
    let reversed = RuntimePluralQatLaneTournamentPlan::new(
        cards.iter().cloned().rev().collect(),
        SET_METADATA_BYTES,
        SAME_FIXTURE_ID,
        SAME_FIXTURE_HASH_REF,
        true,
        CREATED_AT_MS,
    )?;
    let metrics = plan.metrics();
    let red_results = red_fixture_results(&cards);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_witnesses_pass",
            artifact_passes(UPSTREAM_LITERT_ARTIFACT, "F-LiteRTLM-NativeSwiftAdmission")
                && artifact_passes(
                    UPSTREAM_MTP_ARTIFACT,
                    "F-Gemma4-MTP-DrafterCompatibilityCard",
                )
                && artifact_passes(
                    UPSTREAM_QAT_PREFLIGHT_ARTIFACT,
                    "F-QAT-ModelRouteCard-MemoryPreflight",
                )
                && artifact_passes(
                    UPSTREAM_PACKET_ARTIFACT,
                    "F-CompressedRoute-AnswerPacket-DryRun",
                ),
        ),
        (
            "accepted_lane_pack_present",
            has_lane(&cards, "gguf_e2b_qat_llama_cpp_future_probe")
                && has_lane(&cards, "gguf_12b_qat_llama_cpp_flagship_abstain")
                && has_lane(&cards, "litert_e2b_mtp_swift_blocked_until_package_proof")
                && has_lane(&cards, "mlx_swift_gemma4_loader_blocked")
                && has_lane(&cards, "mlxlm_python_12b_research_reference"),
        ),
        (
            "runtime_lane_coverage_bound",
            metrics.runtime_lane_count == 4
                && cards
                    .iter()
                    .any(|card| card.runtime_lane == RuntimePluralQatLane::GgufLlamaCpp)
                && cards
                    .iter()
                    .any(|card| card.runtime_lane == RuntimePluralQatLane::LiteRtLmSwift)
                && cards
                    .iter()
                    .any(|card| card.runtime_lane == RuntimePluralQatLane::MlxSwiftCandidate)
                && cards
                    .iter()
                    .any(|card| card.runtime_lane == RuntimePluralQatLane::MlxLmPythonResearch),
        ),
        (
            "current_source_metadata_bound",
            cards.iter().all(|card| card.model_revision.len() == 40)
                && cards
                    .iter()
                    .all(|card| card.runtime_repo_commit.len() == 40)
                && cards
                    .iter()
                    .all(|card| card.model_license_spdx == "Apache-2.0")
                && cards
                    .iter()
                    .all(|card| matches!(card.runtime_license_spdx.as_str(), "MIT" | "Apache-2.0")),
        ),
        (
            "same_redacted_fixture_bound",
            metrics.fixture_count == 1
                && plan.same_fixture_id == SAME_FIXTURE_ID
                && plan.same_fixture_hash_ref == SAME_FIXTURE_HASH_REF
                && cards
                    .iter()
                    .all(|card| card.same_fixture_required && card.fixture_redacted)
                && red_pass(&red_results, "fixture_id_drift")
                && red_pass(&red_results, "fixture_hash_drift")
                && red_pass(&red_results, "fixture_not_redacted"),
        ),
        (
            "gguf_qat_e2b_future_probe_and_12b_abstention",
            cards.iter().any(|card| {
                card.lane_id == "gguf_e2b_qat_llama_cpp_future_probe"
                    && card.future_probe_candidate
                    && card.lane_status == RuntimePluralQatLaneStatus::FutureProbeCandidate
            }) && cards.iter().any(|card| {
                card.lane_id == "gguf_12b_qat_llama_cpp_flagship_abstain"
                    && card.lane_status == RuntimePluralQatLaneStatus::DeferredAbstention
                    && card.pro_status == ProStatus::Gated
            }),
        ),
        (
            "litert_and_mlx_blocked_until_admission",
            cards.iter().any(|card| {
                card.runtime_lane == RuntimePluralQatLane::LiteRtLmSwift
                    && card.lane_status == RuntimePluralQatLaneStatus::BlockedUntilAdmission
            }) && cards.iter().any(|card| {
                card.runtime_lane == RuntimePluralQatLane::MlxSwiftCandidate
                    && card.lane_status == RuntimePluralQatLaneStatus::BlockedUntilAdmission
                    && card
                        .loader_caveat_ref
                        .as_deref()
                        .unwrap_or("")
                        .starts_with("loader_caveat:")
            }) && red_pass(&red_results, "mlx_loader_caveat_missing")
                && red_pass(&red_results, "litert_marked_future_probe"),
        ),
        (
            "mlxlm_python_research_only",
            cards.iter().any(|card| {
                card.runtime_lane == RuntimePluralQatLane::MlxLmPythonResearch
                    && card.lane_status == RuntimePluralQatLaneStatus::ResearchOnly
                    && card.promotion_tier == RuntimePluralQatPromotionTier::T0Research
            }) && red_pass(&red_results, "mlxlm_promoted_from_research_only"),
        ),
        (
            "proof_surfaces_required",
            cards.iter().all(|card| {
                card.byte_ledger_required
                    && card.memory_preflight_required
                    && card.cancellation_required
                    && card.rollback_required
                    && card.run_event_log_required
                    && card.answer_packet_required
                    && card.quality_metric_required
                    && card.latency_metric_required
                    && card.tool_json_metric_required
                    && card.abstention_required
            }) && red_pass(&red_results, "byte_ledger_missing")
                && red_pass(&red_results, "memory_preflight_missing")
                && red_pass(&red_results, "cancellation_missing")
                && red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "quality_metric_missing")
                && red_pass(&red_results, "latency_metric_missing")
                && red_pass(&red_results, "tool_json_metric_missing")
                && red_pass(&red_results, "abstention_missing"),
        ),
        (
            "proof_refs_bound",
            cards.iter().all(|card| {
                card.proof_refs
                    .upstream_litert_admission_ref
                    .contains("litertlm_native_swift_admission")
                    && card
                        .proof_refs
                        .upstream_mtp_compatibility_ref
                        .contains("gemma4_mtp_drafter_compatibility_card")
                    && card
                        .proof_refs
                        .upstream_qat_route_preflight_ref
                        .contains("qat_model_route_card_memory_preflight")
                    && card
                        .proof_refs
                        .upstream_compressed_route_packet_ref
                        .contains("compressed_route_answer_packet_dry_run")
                    && card.proof_refs.rollback_ref.starts_with("rollback:")
                    && card
                        .proof_refs
                        .run_event_log_ref
                        .starts_with("run_event_log:")
                    && card
                        .proof_refs
                        .answer_packet_ref
                        .starts_with("answer_packet:")
                    && card.proof_refs.cancellation_ref.starts_with("cancel:")
                    && card
                        .proof_refs
                        .memory_ledger_ref
                        .starts_with("memory_ledger:")
                    && card
                        .proof_refs
                        .quality_ledger_ref
                        .starts_with("quality_ledger:")
                    && card
                        .proof_refs
                        .latency_ledger_ref
                        .starts_with("latency_ledger:")
                    && card
                        .proof_refs
                        .tool_json_ledger_ref
                        .starts_with("tool_json_ledger:")
                    && card
                        .proof_refs
                        .compatibility_fence_ref
                        .starts_with("compat:")
                    && card.proof_refs.abstention_ref.starts_with("abstain:")
            }) && red_pass(&red_results, "bad_proof_ref_prefix"),
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
            }) && red_pass(&red_results, "mas_product_build")
                && red_pass(&red_results, "pro_live_status")
                && red_pass(&red_results, "promotion_tier_t2"),
        ),
        (
            "zero_runtime_model_provider_command_benchmark_bytes",
            metrics.opened_model_bytes == 0
                && metrics.resident_model_bytes == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.product_files_copied == 0
                && metrics.command_executions == 0
                && metrics.benchmark_runs == 0
                && red_pass(&red_results, "opened_model_bytes")
                && red_pass(&red_results, "resident_model_bytes")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "provider_call_made")
                && red_pass(&red_results, "product_file_copied")
                && red_pass(&red_results, "command_execution")
                && red_pass(&red_results, "benchmark_run"),
        ),
        (
            "no_package_import_load_or_execution",
            metrics.package_resolved_count == 0
                && metrics.product_dependency_imported_count == 0
                && metrics.runtime_loaded_count == 0
                && metrics.model_loaded_count == 0
                && metrics.command_executed_count == 0
                && metrics.benchmark_executed_count == 0
                && red_pass(&red_results, "package_resolved")
                && red_pass(&red_results, "product_dependency_imported")
                && red_pass(&red_results, "runtime_loaded")
                && red_pass(&red_results, "model_loaded")
                && red_pass(&red_results, "command_executed")
                && red_pass(&red_results, "benchmark_executed"),
        ),
        (
            "no_winner_speed_quality_mas_l2_l3_or_large_model_claim",
            metrics.first_token_claim_count == 0
                && metrics.product_winner_declared_count == 0
                && metrics.speed_claim_count == 0
                && metrics.quality_claim_count == 0
                && metrics.mas_readiness_claim_count == 0
                && metrics.l2_capability_claim_count == 0
                && metrics.l3_wrv_claim_count == 0
                && metrics.live_dense_70b_claim_count == 0
                && metrics.ssd_as_ram_claim_count == 0
                && red_pass(&red_results, "first_token_claim")
                && red_pass(&red_results, "product_winner_declared")
                && red_pass(&red_results, "speed_claim")
                && red_pass(&red_results, "quality_claim")
                && red_pass(&red_results, "mas_readiness_claim")
                && red_pass(&red_results, "l2_capability_claim")
                && red_pass(&red_results, "l3_wrv_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "no_hidden_cloud_route_or_server_sidecar",
            metrics.hidden_cloud_fallback_count == 0
                && metrics.hidden_route_authority_count == 0
                && metrics.server_sidecar_default_count == 0
                && plan.explicit_local_endpoint_default_denied
                && red_pass(&red_results, "hidden_cloud_fallback")
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "server_sidecar_default")
                && red_pass(&red_results, "local_endpoint_not_default_denied"),
        ),
        (
            "runtime_plural_not_monopoly",
            plan.runtime_plural_not_runtime_monopoly
                && metrics.runtime_lane_count == 4
                && red_pass(&red_results, "missing_runtime_lane"),
        ),
        (
            "no_runtime_execution_and_product_blocked",
            plan.no_runtime_execution
                && plan.product_promotion_blocked
                && plan.hidden_authority_blocked
                && plan.l1_l2_l3_separated
                && cards
                    .iter()
                    .all(|card| card.runtime_deferred && card.product_promotion_blocked)
                && red_pass(&red_results, "runtime_not_deferred")
                && red_pass(&red_results, "product_promotion_not_blocked"),
        ),
        (
            "plan_address_deterministic",
            plan.plan_address == reversed.plan_address,
        ),
        (
            "next_cursor_bound",
            RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_PLAN_NEXT_CURSOR
                == "runtime_plural_qat_lane_tournament_owner_approval_gate",
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
        4,
        "lanes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_count",
        metrics.model_count,
        ">=",
        4,
        "models",
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
        "declared_model_bytes_total",
        metrics.declared_model_bytes_total,
        ">",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "planned_resident_floor_bytes_total",
        metrics.planned_resident_floor_bytes_total,
        ">",
        metrics.declared_model_bytes_total,
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
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "benchmark_runs",
        metrics.benchmark_runs,
        "==",
        0,
        "runs",
    );

    measurements.insert(
        "runtime_plural_tournament_address".to_string(),
        Measurement {
            value: serde_json::json!(plan.plan_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "runtime_plural_tournament_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("runtime_plural_qat_lane_tournament_plan:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "runtime_plural_tournament_address".to_string(),
        plan.plan_address
            .to_string()
            .starts_with("runtime_plural_qat_lane_tournament_plan:"),
    );

    measurements.insert(
        "next_cursor".to_string(),
        Measurement {
            value: serde_json::json!(RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_PLAN_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_cursor".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("runtime_plural_qat_lane_tournament_owner_approval_gate"),
            unit: "cursor".to_string(),
        },
    );
    pass_per_axis.insert(
        "next_cursor".to_string(),
        RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_PLAN_NEXT_CURSOR
            == "runtime_plural_qat_lane_tournament_owner_approval_gate",
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
        notes: "Builds F-RuntimePlural-QATLaneTournamentPlan from LiteRT-LM admission, Gemma 4 MTP compatibility, Gemma QAT route preflight, compressed-route AnswerPacket dry-run, and current runtime/model source metadata. Scope is T1/L1 metadata only: no package resolution, no model/runtime bytes, no commands, no benchmarks, no server sidecar, no runtime winner, no MAS/L2/L3/product claim, and no live dense 70B claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn build_plan(
    cards: Vec<RuntimePluralQatLaneCard>,
    endpoint_default_denied: bool,
) -> Result<RuntimePluralQatLaneTournamentPlan, RuntimePluralQatTournamentError> {
    RuntimePluralQatLaneTournamentPlan::new(
        cards,
        SET_METADATA_BYTES,
        SAME_FIXTURE_ID,
        SAME_FIXTURE_HASH_REF,
        endpoint_default_denied,
        CREATED_AT_MS,
    )
}

fn artifact_passes(path: &str, expected_id: &str) -> bool {
    let Ok(bytes) = read_repo_relative(path) else {
        return false;
    };
    let Ok(value) = serde_json::from_slice::<serde_json::Value>(&bytes) else {
        return false;
    };
    value
        .get("falsifier_id")
        .and_then(serde_json::Value::as_str)
        == Some(expected_id)
        && value
            .get("overall_pass")
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false)
}

fn has_lane(cards: &[RuntimePluralQatLaneCard], lane_id: &str) -> bool {
    cards.iter().any(|card| card.lane_id == lane_id)
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(fixture, _)| *fixture == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}

fn read_repo_relative(path: &str) -> std::io::Result<Vec<u8>> {
    match std::fs::read(path) {
        Ok(bytes) => Ok(bytes),
        Err(first_error) => match std::fs::read(format!("../{path}")) {
            Ok(bytes) => Ok(bytes),
            Err(_) => Err(first_error),
        },
    }
}

fn accepted_cards() -> Vec<RuntimePluralQatLaneCard> {
    vec![
        lane_card(CardSpec {
            lane_id: "gguf_e2b_qat_llama_cpp_future_probe",
            runtime_lane: RuntimePluralQatLane::GgufLlamaCpp,
            lane_status: RuntimePluralQatLaneStatus::FutureProbeCandidate,
            model_id: "google/gemma-4-E2B-it-qat-q4_0-gguf",
            model_revision: "1894d1fc0a19d86697abd40483f5983c867df03f",
            model_url: "https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf",
            quant_or_format: "gguf:q4_0",
            runtime_repo_url: "https://github.com/ggml-org/llama.cpp",
            runtime_repo_commit: "98d5e8ba8a2642710c9871d05ac1033a3328b884",
            runtime_release_tag: "b9544",
            runtime_license_spdx: "MIT",
            runtime_source_classification: "adapter_wrap",
            declared_model_bytes: 4_628_569_635,
            planned_resident_floor_bytes: 5 * 1024 * 1024 * 1024,
            planned_kv_floor_bytes: 512 * 1024 * 1024,
            planned_scratch_bytes: 256 * 1024 * 1024,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: RuntimePluralQatPromotionTier::T1L1Metadata,
            loader_caveat_ref: None,
            future_probe_candidate: true,
        }),
        lane_card(CardSpec {
            lane_id: "gguf_12b_qat_llama_cpp_flagship_abstain",
            runtime_lane: RuntimePluralQatLane::GgufLlamaCpp,
            lane_status: RuntimePluralQatLaneStatus::DeferredAbstention,
            model_id: "google/gemma-4-12B-it-qat-q4_0-gguf",
            model_revision: "f6e7774e6148da3b7f201e42ba37cf084c1db35f",
            model_url: "https://huggingface.co/google/gemma-4-12B-it-qat-q4_0-gguf",
            quant_or_format: "gguf:q4_0",
            runtime_repo_url: "https://github.com/ggml-org/llama.cpp",
            runtime_repo_commit: "98d5e8ba8a2642710c9871d05ac1033a3328b884",
            runtime_release_tag: "b9544",
            runtime_license_spdx: "MIT",
            runtime_source_classification: "adapter_wrap",
            declared_model_bytes: 11_907_350_576,
            planned_resident_floor_bytes: 13 * 1024 * 1024 * 1024,
            planned_kv_floor_bytes: 1024 * 1024 * 1024,
            planned_scratch_bytes: 512 * 1024 * 1024,
            pro_status: ProStatus::Gated,
            promotion_tier: RuntimePluralQatPromotionTier::T1L1Metadata,
            loader_caveat_ref: None,
            future_probe_candidate: false,
        }),
        lane_card(CardSpec {
            lane_id: "litert_e2b_mtp_swift_blocked_until_package_proof",
            runtime_lane: RuntimePluralQatLane::LiteRtLmSwift,
            lane_status: RuntimePluralQatLaneStatus::BlockedUntilAdmission,
            model_id: "google/gemma-4-E2B-it",
            model_revision: "70af34e20bd4b7a91f0de6b22675850c43922a03",
            model_url: "https://huggingface.co/google/gemma-4-E2B-it",
            quant_or_format: "litert:model-card-plus-mtp",
            runtime_repo_url: "https://github.com/google-ai-edge/LiteRT-LM",
            runtime_repo_commit: "b9d59eb5610c1116fd6896cf71a19eb61355a707",
            runtime_release_tag: "v0.13.1",
            runtime_license_spdx: "Apache-2.0",
            runtime_source_classification: "adapter_wrap",
            declared_model_bytes: 0,
            planned_resident_floor_bytes: 0,
            planned_kv_floor_bytes: 0,
            planned_scratch_bytes: 0,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: RuntimePluralQatPromotionTier::T1L1Metadata,
            loader_caveat_ref: Some("loader_caveat:litert_local_package_proof_pending"),
            future_probe_candidate: false,
        }),
        lane_card(CardSpec {
            lane_id: "mlx_swift_gemma4_loader_blocked",
            runtime_lane: RuntimePluralQatLane::MlxSwiftCandidate,
            lane_status: RuntimePluralQatLaneStatus::BlockedUntilAdmission,
            model_id: "google/gemma-4-E2B-it",
            model_revision: "70af34e20bd4b7a91f0de6b22675850c43922a03",
            model_url: "https://huggingface.co/google/gemma-4-E2B-it",
            quant_or_format: "mlx-swift:loader-unproven",
            runtime_repo_url: "https://github.com/ml-explore/mlx-swift",
            runtime_repo_commit: "dc43e62d7055353c7f99fa071a4e71d29dfddc44",
            runtime_release_tag: "0.31.4",
            runtime_license_spdx: "MIT",
            runtime_source_classification: "research_only",
            declared_model_bytes: 0,
            planned_resident_floor_bytes: 0,
            planned_kv_floor_bytes: 0,
            planned_scratch_bytes: 0,
            pro_status: ProStatus::Blocked,
            promotion_tier: RuntimePluralQatPromotionTier::T1L1Metadata,
            loader_caveat_ref: Some("loader_caveat:swift_mlx_gemma4_loader_unproven"),
            future_probe_candidate: false,
        }),
        lane_card(CardSpec {
            lane_id: "mlxlm_python_12b_research_reference",
            runtime_lane: RuntimePluralQatLane::MlxLmPythonResearch,
            lane_status: RuntimePluralQatLaneStatus::ResearchOnly,
            model_id: "google/gemma-4-12B-it",
            model_revision: "5926caa4ec0cac5cbfadaf4077420520de1d5205",
            model_url: "https://huggingface.co/google/gemma-4-12B-it",
            quant_or_format: "mlx-lm:python-research-reference",
            runtime_repo_url: "https://github.com/ml-explore/mlx-lm",
            runtime_repo_commit: "e476a22246b86fb6e2a8d35c81953293ebf86a0f",
            runtime_release_tag: "v0.31.3",
            runtime_license_spdx: "MIT",
            runtime_source_classification: "research_only",
            declared_model_bytes: 0,
            planned_resident_floor_bytes: 0,
            planned_kv_floor_bytes: 0,
            planned_scratch_bytes: 0,
            pro_status: ProStatus::ResearchCandidate,
            promotion_tier: RuntimePluralQatPromotionTier::T0Research,
            loader_caveat_ref: Some("loader_caveat:python_research_not_product_lane"),
            future_probe_candidate: false,
        }),
    ]
}

// UAS: uas:runtime-plural-qat-tournament:fixture-spec
// Plane: Verification
// Residency: falsifier fixture metadata; not runtime configuration.
struct CardSpec {
    lane_id: &'static str,
    runtime_lane: RuntimePluralQatLane,
    lane_status: RuntimePluralQatLaneStatus,
    model_id: &'static str,
    model_revision: &'static str,
    model_url: &'static str,
    quant_or_format: &'static str,
    runtime_repo_url: &'static str,
    runtime_repo_commit: &'static str,
    runtime_release_tag: &'static str,
    runtime_license_spdx: &'static str,
    runtime_source_classification: &'static str,
    declared_model_bytes: u64,
    planned_resident_floor_bytes: u64,
    planned_kv_floor_bytes: u64,
    planned_scratch_bytes: u64,
    pro_status: ProStatus,
    promotion_tier: RuntimePluralQatPromotionTier,
    loader_caveat_ref: Option<&'static str>,
    future_probe_candidate: bool,
}

fn lane_card(spec: CardSpec) -> RuntimePluralQatLaneCard {
    RuntimePluralQatLaneCard {
        lane_id: spec.lane_id.to_string(),
        runtime_lane: spec.runtime_lane,
        lane_status: spec.lane_status,
        model_id: spec.model_id.to_string(),
        model_url: spec.model_url.to_string(),
        model_revision: spec.model_revision.to_string(),
        model_license_spdx: "Apache-2.0".to_string(),
        quant_or_format: spec.quant_or_format.to_string(),
        runtime_repo_url: spec.runtime_repo_url.to_string(),
        runtime_repo_commit: spec.runtime_repo_commit.to_string(),
        runtime_release_tag: spec.runtime_release_tag.to_string(),
        runtime_license_spdx: spec.runtime_license_spdx.to_string(),
        runtime_source_classification: spec.runtime_source_classification.to_string(),
        same_fixture_id: SAME_FIXTURE_ID.to_string(),
        same_fixture_hash_ref: SAME_FIXTURE_HASH_REF.to_string(),
        fixture_redacted: true,
        product_build: ProductBuild::Pro,
        pro_status: spec.pro_status,
        promotion_tier: spec.promotion_tier,
        byte_ledger: RuntimePluralQatByteLedger::metadata_only(
            spec.declared_model_bytes,
            spec.planned_resident_floor_bytes,
            spec.planned_kv_floor_bytes,
            spec.planned_scratch_bytes,
            24_000,
        ),
        proof_refs: proof_refs(spec.lane_id),
        loader_caveat_ref: spec.loader_caveat_ref.map(str::to_string),
        user_visible_route_caveat:
            "route_caveat:metadata_only_no_runtime_no_winner_no_product_claim".to_string(),
        same_fixture_required: true,
        byte_ledger_required: true,
        memory_preflight_required: true,
        cancellation_required: true,
        rollback_required: true,
        run_event_log_required: true,
        answer_packet_required: true,
        quality_metric_required: true,
        latency_metric_required: true,
        tool_json_metric_required: true,
        abstention_required: true,
        future_probe_candidate: spec.future_probe_candidate,
        runtime_deferred: true,
        product_promotion_blocked: true,
        package_resolved: false,
        product_dependency_imported: false,
        runtime_loaded: false,
        model_loaded: false,
        command_executed: false,
        benchmark_executed: false,
        first_token_claimed: false,
        product_winner_declared: false,
        speed_claimed: false,
        quality_claimed: false,
        mas_readiness_claimed: false,
        l2_capability_claimed: false,
        l3_wrv_claimed: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
        hidden_cloud_fallback_allowed: false,
        hidden_route_authority_allowed: false,
        server_sidecar_default_allowed: false,
    }
}

fn proof_refs(id: &str) -> RuntimePluralQatProofRefs {
    RuntimePluralQatProofRefs {
        upstream_litert_admission_ref: "artifact:litertlm_native_swift_admission:result"
            .to_string(),
        upstream_mtp_compatibility_ref: "artifact:gemma4_mtp_drafter_compatibility_card:result"
            .to_string(),
        upstream_qat_route_preflight_ref: "artifact:qat_model_route_card_memory_preflight:result"
            .to_string(),
        upstream_compressed_route_packet_ref:
            "artifact:compressed_route_answer_packet_dry_run:result".to_string(),
        falsifier_ref: format!("falsifier:F-RuntimePlural-QATLaneTournamentPlan:{id}"),
        fixture_ref: format!("fixture:{SAME_FIXTURE_ID}:{id}"),
        rollback_ref: format!("rollback:runtime_plural_qat_tournament:{id}"),
        run_event_log_ref: format!("run_event_log:runtime_plural_qat_tournament:{id}"),
        answer_packet_ref: format!("answer_packet:runtime_plural_qat_tournament:{id}"),
        cancellation_ref: format!("cancel:runtime_plural_qat_tournament:{id}"),
        memory_ledger_ref: format!("memory_ledger:runtime_plural_qat_tournament:{id}"),
        quality_ledger_ref: format!("quality_ledger:runtime_plural_qat_tournament:{id}"),
        latency_ledger_ref: format!("latency_ledger:runtime_plural_qat_tournament:{id}"),
        tool_json_ledger_ref: format!("tool_json_ledger:runtime_plural_qat_tournament:{id}"),
        compatibility_fence_ref: format!("compat:runtime_plural_qat_tournament:{id}"),
        abstention_ref: format!("abstain:runtime_plural_qat_tournament:{id}"),
    }
}

fn red_fixture_results(cards: &[RuntimePluralQatLaneCard]) -> Vec<(&'static str, bool)> {
    let mut results = Vec::new();

    let mut push_card = |name: &'static str, mutate: fn(&mut Vec<RuntimePluralQatLaneCard>)| {
        let mut mutated = cards.to_vec();
        mutate(&mut mutated);
        results.push((name, build_plan(mutated, true).is_err()));
    };

    push_card("duplicate_lane_id", |cards| {
        cards[1].lane_id = cards[0].lane_id.clone()
    });
    push_card("duplicate_lane_model", |cards| {
        cards[1].runtime_lane = cards[0].runtime_lane;
        cards[1].model_id = cards[0].model_id.clone();
    });
    push_card("missing_runtime_lane", |cards| {
        cards.retain(|card| card.runtime_lane != RuntimePluralQatLane::MlxLmPythonResearch)
    });
    push_card("bad_model_url", |cards| {
        cards[0].model_url = "http://huggingface.co/google/model".to_string()
    });
    push_card("bad_repo_url", |cards| {
        cards[0].runtime_repo_url = "file:///tmp/runtime".to_string()
    });
    push_card("bad_model_revision", |cards| {
        cards[0].model_revision = "not-a-sha".to_string()
    });
    push_card("bad_runtime_commit", |cards| {
        cards[0].runtime_repo_commit = "not-a-sha".to_string()
    });
    push_card("bad_model_license", |cards| {
        cards[0].model_license_spdx = "unknown".to_string()
    });
    push_card("bad_runtime_license", |cards| {
        cards[0].runtime_license_spdx = "GPL-3.0-only".to_string()
    });
    push_card("no_runtime_lane", |cards| {
        cards[0].runtime_lane = RuntimePluralQatLane::NoRuntime
    });
    push_card("fixture_id_drift", |cards| {
        cards[0].same_fixture_id = "other_fixture".to_string()
    });
    push_card("fixture_hash_drift", |cards| {
        cards[0].same_fixture_hash_ref = "fixture:sha256:other".to_string()
    });
    push_card("fixture_not_redacted", |cards| {
        cards[0].fixture_redacted = false
    });
    push_card("mas_product_build", |cards| {
        cards[0].product_build = ProductBuild::Mas
    });
    push_card("pro_live_status", |cards| {
        cards[0].pro_status = ProStatus::Live
    });
    push_card("promotion_tier_t2", |cards| {
        cards[0].promotion_tier = RuntimePluralQatPromotionTier::T2L2Route
    });
    push_card("byte_ledger_missing", |cards| {
        cards[0].byte_ledger_required = false
    });
    push_card("memory_preflight_missing", |cards| {
        cards[0].memory_preflight_required = false
    });
    push_card("cancellation_missing", |cards| {
        cards[0].cancellation_required = false
    });
    push_card("rollback_missing", |cards| {
        cards[0].rollback_required = false
    });
    push_card("run_event_log_missing", |cards| {
        cards[0].run_event_log_required = false
    });
    push_card("answer_packet_missing", |cards| {
        cards[0].answer_packet_required = false
    });
    push_card("quality_metric_missing", |cards| {
        cards[0].quality_metric_required = false
    });
    push_card("latency_metric_missing", |cards| {
        cards[0].latency_metric_required = false
    });
    push_card("tool_json_metric_missing", |cards| {
        cards[0].tool_json_metric_required = false
    });
    push_card("abstention_missing", |cards| {
        cards[0].abstention_required = false
    });
    push_card("bad_proof_ref_prefix", |cards| {
        cards[0].proof_refs.answer_packet_ref = "packet:bad".to_string()
    });
    push_card("zero_metadata_bytes", |cards| {
        cards[0].byte_ledger.metadata_bytes_read = 0
    });
    push_card("opened_model_bytes", |cards| {
        cards[0].byte_ledger.opened_model_bytes = 1
    });
    push_card("resident_model_bytes", |cards| {
        cards[0].byte_ledger.resident_model_bytes = 1
    });
    push_card("runtime_bytes_loaded", |cards| {
        cards[0].byte_ledger.runtime_bytes_loaded = 1
    });
    push_card("model_bytes_loaded", |cards| {
        cards[0].byte_ledger.model_bytes_loaded = 1
    });
    push_card("provider_call_made", |cards| {
        cards[0].byte_ledger.provider_calls_made = 1
    });
    push_card("product_file_copied", |cards| {
        cards[0].byte_ledger.product_files_copied = 1
    });
    push_card("command_execution", |cards| {
        cards[0].byte_ledger.command_executions = 1
    });
    push_card("benchmark_run", |cards| {
        cards[0].byte_ledger.benchmark_runs = 1
    });
    push_card("package_resolved", |cards| cards[0].package_resolved = true);
    push_card("product_dependency_imported", |cards| {
        cards[0].product_dependency_imported = true
    });
    push_card("runtime_loaded", |cards| cards[0].runtime_loaded = true);
    push_card("model_loaded", |cards| cards[0].model_loaded = true);
    push_card("command_executed", |cards| cards[0].command_executed = true);
    push_card("benchmark_executed", |cards| {
        cards[0].benchmark_executed = true
    });
    push_card("first_token_claim", |cards| {
        cards[0].first_token_claimed = true
    });
    push_card("product_winner_declared", |cards| {
        cards[0].product_winner_declared = true
    });
    push_card("speed_claim", |cards| cards[0].speed_claimed = true);
    push_card("quality_claim", |cards| cards[0].quality_claimed = true);
    push_card("mas_readiness_claim", |cards| {
        cards[0].mas_readiness_claimed = true
    });
    push_card("l2_capability_claim", |cards| {
        cards[0].l2_capability_claimed = true
    });
    push_card("l3_wrv_claim", |cards| cards[0].l3_wrv_claimed = true);
    push_card("live_dense_70b_claim", |cards| {
        cards[0].live_dense_70b_claimed = true
    });
    push_card("ssd_as_ram_claim", |cards| {
        cards[0].ssd_as_ram_claimed = true
    });
    push_card("hidden_cloud_fallback", |cards| {
        cards[0].hidden_cloud_fallback_allowed = true
    });
    push_card("hidden_route_authority", |cards| {
        cards[0].hidden_route_authority_allowed = true
    });
    push_card("server_sidecar_default", |cards| {
        cards[0].server_sidecar_default_allowed = true
    });
    push_card("mlx_loader_caveat_missing", |cards| {
        if let Some(card) = cards
            .iter_mut()
            .find(|card| card.runtime_lane == RuntimePluralQatLane::MlxSwiftCandidate)
        {
            card.loader_caveat_ref = None;
        }
    });
    push_card("mlx_marked_future_probe", |cards| {
        if let Some(card) = cards
            .iter_mut()
            .find(|card| card.runtime_lane == RuntimePluralQatLane::MlxSwiftCandidate)
        {
            card.future_probe_candidate = true;
        }
    });
    push_card("litert_marked_future_probe", |cards| {
        if let Some(card) = cards
            .iter_mut()
            .find(|card| card.runtime_lane == RuntimePluralQatLane::LiteRtLmSwift)
        {
            card.future_probe_candidate = true;
        }
    });
    push_card("mlxlm_promoted_from_research_only", |cards| {
        if let Some(card) = cards
            .iter_mut()
            .find(|card| card.runtime_lane == RuntimePluralQatLane::MlxLmPythonResearch)
        {
            card.lane_status = RuntimePluralQatLaneStatus::FutureProbeCandidate;
            card.promotion_tier = RuntimePluralQatPromotionTier::T1L1Metadata;
        }
    });
    push_card("runtime_not_deferred", |cards| {
        cards[0].runtime_deferred = false
    });
    push_card("product_promotion_not_blocked", |cards| {
        cards[0].product_promotion_blocked = false
    });

    let mut endpoint_cards = cards.to_vec();
    results.push((
        "local_endpoint_not_default_denied",
        build_plan(endpoint_cards.split_off(0), false).is_err(),
    ));

    results
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepted_artifact_passes_all_axes() {
        let artifact = build_artifact().expect("artifact should build");
        assert!(artifact.overall_pass);
        assert_eq!(
            artifact.measurements["runtime_bytes_loaded"].value,
            serde_json::json!(0)
        );
        assert_eq!(
            artifact.measurements["model_bytes_loaded"].value,
            serde_json::json!(0)
        );
    }

    #[test]
    fn red_fixture_pack_rejects_runtime_claims_and_hidden_authority() {
        let cards = accepted_cards();
        let results = red_fixture_results(&cards);
        assert!(results.len() >= 50);
        assert!(red_pass(&results, "product_winner_declared"));
        assert!(red_pass(&results, "runtime_bytes_loaded"));
        assert!(red_pass(&results, "hidden_route_authority"));
        assert!(red_pass(&results, "local_endpoint_not_default_denied"));
    }
}
