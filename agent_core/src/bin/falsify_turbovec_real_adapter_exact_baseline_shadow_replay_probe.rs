//! `falsify_turbovec_real_adapter_exact_baseline_shadow_replay_probe`
//!
//! Metadata-only witness for `F-TurboVec-RealAdapterExactBaselineShadowReplayProbe`.
//! It consumes the clean-room adapter-plan witness and proves the next
//! TurboVec-derived contract is exact-baseline shadow replay only: no adapter
//! build, no native-link probe, no benchmark run, no index/model/runtime bytes,
//! no product graph mutation, no route mutation, no context injection, and no
//! product capability claim.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    real_adapter_recall_at_k_micros, ProStatus, ProductBuild,
    TurboVecRealAdapterExactBaselineShadowReplayProbeSet,
    TurboVecRealAdapterShadowReplayByteLedger, TurboVecRealAdapterShadowReplayCase,
    TurboVecRealAdapterShadowReplayDecision, TurboVecRealAdapterShadowReplayPolicy,
    TurboVecRealAdapterShadowReplayProofRefs, TurboVecRealAdapterShadowReplayScenario,
    TurboVecRealAdapterShadowReplayStatus, TurboVecRealAdapterShadowReplayTier, UasAddress,
    TURBOVEC_REAL_ADAPTER_EXACT_BASELINE_SHADOW_REPLAY_CURSOR,
    TURBOVEC_REAL_ADAPTER_EXACT_BASELINE_SHADOW_REPLAY_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-RealAdapterExactBaselineShadowReplayProbe";
const FIXTURE_ID: &str = "turbovec_real_adapter_exact_baseline_shadow_replay_probe_v1";
const COMMAND: &str =
    "Tools/falsifiers/f_turbovec_real_adapter_exact_baseline_shadow_replay_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_exact_baseline_shadow_replay_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_real_adapter_clean_room_adapter_plan_probe/result.json";
const PINNED_REVISION: &str = "efe29a184986cbf562a9847c2ac52a2990bfaca2";
const PLAN_REF_PREFIX: &str = "clean_room_plan:turbovec-adapter:";
const QUERY_REF_PREFIX: &str = "query:turbovec-real-adapter:";
const EXACT_BASELINE_REF_PREFIX: &str = "app_cold_store:exact_baseline:turbovec-real-adapter:";
const SOURCE_CARD_REF_PREFIX: &str = "source_card:turbovec-shadow-replay:";
const NO_PRODUCT_GRAPH_REF_PREFIX: &str = "no_product_graph:turbovec-shadow-replay:";
const FALLBACK_REF_PREFIX: &str = "fallback:turbovec-shadow-replay:";
const ROLLBACK_REF_PREFIX: &str = "rollback:turbovec-shadow-replay:";
const RUN_EVENT_LOG_REF_PREFIX: &str = "run_event_log:turbovec-shadow-replay:";
const ANSWER_PACKET_REF_PREFIX: &str = "answer_packet:turbovec-shadow-replay:";
const COMPATIBILITY_REF_PREFIX: &str = "compat:turbovec-shadow-replay:";
const RED_FIXTURE_FLOOR: u64 = 45;

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
        "{FALSIFIER_ID}: overall_pass={} cases={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["case_count"].value,
        artifact.measurements["red_fixture_rejection_count"].value,
        artifact.measurements["next_research_to_build_unit"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let upstream = upstream_clean_room_plan_address()?;
    let set = build_set(
        upstream.clone(),
        replay_cases(),
        policy(),
        proof_refs(),
        ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecRealAdapterShadowReplayStatus::MetadataOnlyShadowReplay,
        TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )?;
    let reversed = build_set(
        upstream.clone(),
        replay_cases().into_iter().rev().collect(),
        policy(),
        proof_refs(),
        ledger(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecRealAdapterShadowReplayStatus::MetadataOnlyShadowReplay,
        TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
    )?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&upstream);
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_clean_room_adapter_plan_bound",
            set.upstream_clean_room_plan_witness_ref
                == "artifact:turbovec_real_adapter_clean_room_adapter_plan_probe:result"
                && set
                    .upstream_clean_room_plan_address
                    .to_string()
                    .starts_with("turbovec_real_adapter_clean_room_adapter_plan_probe:")
                && red_pass(&red_results, "bad_upstream_plan"),
        ),
        (
            "shadow_replay_scenario_coverage",
            metrics.case_count == 7
                && metrics.warm_exact_hit_count == 1
                && metrics.cold_miss_fallback_count == 1
                && metrics.cancellation_fallback_count == 1
                && metrics.memory_pressure_abstain_count == 1
                && metrics.empty_allowlist_visible_count == 1
                && metrics.privacy_denied_fallback_count == 1
                && metrics.recall_regression_fallback_count == 1
                && red_pass(&red_results, "remove_warm")
                && red_pass(&red_results, "remove_cold")
                && red_pass(&red_results, "remove_cancel")
                && red_pass(&red_results, "remove_memory")
                && red_pass(&red_results, "remove_empty")
                && red_pass(&red_results, "remove_privacy")
                && red_pass(&red_results, "remove_regression"),
        ),
        (
            "exact_baseline_recall_and_allowlist_bound",
            metrics.shadow_win_count == 1
                && metrics.invalid_shadow_win_count == 0
                && metrics.max_recall_delta_micros <= 800_000
                && red_pass(&red_results, "bad_exact_baseline_ref")
                && red_pass(&red_results, "wrong_declared_recall")
                && red_pass(&red_results, "approx_not_allowlisted")
                && red_pass(&red_results, "denied_id_returned")
                && red_pass(&red_results, "duplicate_approx_id")
                && red_pass(&red_results, "false_shadow_win_recall"),
        ),
        (
            "deterministic_seed_latency_memory_cancellation_bound",
            metrics.min_memory_headroom_bytes == -8_576
                && red_pass(&red_results, "zero_seed")
                && red_pass(&red_results, "low_sample_count")
                && red_pass(&red_results, "bad_top_k")
                && red_pass(&red_results, "bad_latency_order")
                && red_pass(&red_results, "bad_cancellation_deadline")
                && red_pass(&red_results, "wrong_memory_total"),
        ),
        (
            "fallback_rollback_answer_packet_bound",
            metrics.fallback_case_count == 5
                && red_pass(&red_results, "bad_fallback_ref")
                && red_pass(&red_results, "bad_rollback_ref")
                && red_pass(&red_results, "bad_run_event_log_ref")
                && red_pass(&red_results, "bad_answer_packet_ref")
                && red_pass(&red_results, "weak_visible_summary"),
        ),
        (
            "policy_fail_closed",
            set.policy.clean_room_adapter_plan_required
                && set.policy.exact_app_cold_store_baseline_required
                && set.policy.held_out_replay_required
                && set.policy.deterministic_seed_required
                && set.policy.uas_allowlist_before_rank_required
                && set.policy.denied_ids_excluded
                && set.policy.fallback_required_for_loss
                && set.policy.cancellation_required
                && set.policy.memory_abstention_required
                && set.policy.answer_packet_required
                && set.policy.run_event_log_required
                && set.policy.rollback_required
                && set.policy.compatibility_fence_required
                && set.policy.no_product_graph_mutation
                && set.policy.no_route_authority
                && set.policy.no_model_context_injection
                && set.policy.no_runtime_execution
                && red_pass(&red_results, "policy_no_baseline")
                && red_pass(&red_results, "policy_route_authority")
                && red_pass(&red_results, "policy_context")
                && red_pass(&red_results, "policy_runtime")
                && red_pass(&red_results, "policy_no_answer_packet"),
        ),
        (
            "byte_scope_no_runtime_or_index",
            metrics.upstream_motif_source_bytes_cited == 184_472
                && metrics.additional_raw_source_bytes_inspected == 0
                && metrics.exact_baseline_bytes_opened == 0
                && metrics.index_bytes_opened == 0
                && metrics.index_bytes_loaded == 0
                && metrics.adapter_build_count == 0
                && metrics.benchmark_run_count == 0
                && metrics.allocated_runtime_bytes == 0
                && metrics.runtime_model_bytes_loaded == 0
                && metrics.model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "additional_source_read")
                && red_pass(&red_results, "exact_baseline_bytes_opened")
                && red_pass(&red_results, "index_bytes_opened")
                && red_pass(&red_results, "adapter_build")
                && red_pass(&red_results, "benchmark_run")
                && red_pass(&red_results, "runtime_bytes")
                && red_pass(&red_results, "model_bytes")
                && red_pass(&red_results, "provider_call"),
        ),
        (
            "no_product_graph_route_context_authority",
            metrics.product_graph_mutation_count == 0
                && metrics.route_mutation_count == 0
                && metrics.model_context_injection_count == 0
                && metrics.hidden_authority_count == 0
                && red_pass(&red_results, "product_graph_mutation")
                && red_pass(&red_results, "route_mutation")
                && red_pass(&red_results, "context_injection")
                && red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "hidden_cloud"),
        ),
        (
            "product_and_large_model_claims_rejected",
            !set.product_capability_promoted
                && !set.live_large_model_claimed
                && !set.ssd_as_ram_claimed
                && red_pass(&red_results, "product_promoted")
                && red_pass(&red_results, "product_build_mas")
                && red_pass(&red_results, "pro_status_live")
                && red_pass(&red_results, "tier_t2")
                && red_pass(&red_results, "live_large_model")
                && red_pass(&red_results, "ssd_as_ram"),
        ),
        (
            "reversed_order_address_deterministic",
            set.set_address == reversed.set_address,
        ),
        (
            "red_fixture_rejection_floor",
            red_fixture_rejection_count >= RED_FIXTURE_FLOOR,
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

    for (name, actual, expected, operator, unit) in [
        ("case_count", metrics.case_count, 7, "==", "count"),
        (
            "shadow_win_count",
            metrics.shadow_win_count,
            1,
            "==",
            "count",
        ),
        (
            "fallback_case_count",
            metrics.fallback_case_count,
            5,
            "==",
            "count",
        ),
        (
            "max_recall_delta_micros",
            metrics.max_recall_delta_micros,
            800_000,
            "<=",
            "micros",
        ),
        (
            "upstream_motif_source_bytes_cited",
            metrics.upstream_motif_source_bytes_cited,
            184_472,
            "==",
            "bytes",
        ),
        (
            "additional_raw_source_bytes_inspected",
            metrics.additional_raw_source_bytes_inspected,
            0,
            "==",
            "bytes",
        ),
        (
            "planned_replay_bytes",
            metrics.planned_replay_bytes,
            96_000,
            "==",
            "bytes",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            RED_FIXTURE_FLOOR,
            ">=",
            "count",
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            actual,
            operator,
            expected,
            unit,
        );
    }
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "pinned_revision",
        PINNED_REVISION,
        PINNED_REVISION,
        "sha",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "exact_baseline_shadow_replay_address",
        &set.set_address.to_string(),
        "turbovec_real_adapter_exact_baseline_shadow_replay_probe:",
        "uas_address",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "next_research_to_build_unit",
        TURBOVEC_REAL_ADAPTER_EXACT_BASELINE_SHADOW_REPLAY_NEXT_CURSOR,
        TURBOVEC_REAL_ADAPTER_EXACT_BASELINE_SHADOW_REPLAY_NEXT_CURSOR,
        "cursor",
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
        anomalies: vec![serde_json::json!({
            "kind": "metadata_only_shadow_replay_scope",
            "detail": "Exact-baseline shadow replay contract only. No TurboVec source import, adapter build, benchmark run, exact-baseline/index/model/runtime/provider bytes, product graph mutation, route mutation, context injection, hidden authority, or live large-local-model product claim."
        })],
        notes: "Builds F-TurboVec-RealAdapterExactBaselineShadowReplayProbe as a T1/L1 metadata-only witness after the clean-room adapter plan. It proves the future real adapter must replay against exact AppColdStore baselines with UAS allowlist-before-rank privacy, deterministic held-out cases, fallback, cancellation, memory abstention, rollback, RunEventLog, AnswerPacket, and no L2/L3 promotion.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_clean_room_plan_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream clean-room adapter-plan witness has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_REAL_ADAPTER_EXACT_BASELINE_SHADOW_REPLAY_CURSOR)
    {
        return Err("upstream adapter-plan witness does not point at shadow replay".into());
    }
    for axis in [
        "/pass_per_axis/upstream_motif_cards_bound",
        "/pass_per_axis/adapter_plan_component_coverage",
        "/pass_per_axis/uas_filter_io_baseline_contract_bound",
        "/pass_per_axis/policy_fail_closed",
        "/pass_per_axis/byte_scope_no_build_or_runtime",
        "/pass_per_axis/proof_surfaces_required",
        "/pass_per_axis/no_route_context_or_hidden_authority",
        "/pass_per_axis/product_and_large_model_claims_rejected",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(format!("upstream adapter-plan axis missing or false: {axis}").into());
        }
    }
    let address = value
        .pointer("/measurements/clean_room_adapter_plan_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing clean_room_adapter_plan_address")?;
    Ok(UasAddress::from_str(address)?)
}

#[allow(clippy::too_many_arguments)]
fn build_set(
    upstream: UasAddress,
    cases: Vec<TurboVecRealAdapterShadowReplayCase>,
    policy: TurboVecRealAdapterShadowReplayPolicy,
    proof_refs: TurboVecRealAdapterShadowReplayProofRefs,
    ledger: TurboVecRealAdapterShadowReplayByteLedger,
    product_build: ProductBuild,
    pro_status: ProStatus,
    status: TurboVecRealAdapterShadowReplayStatus,
    tier: TurboVecRealAdapterShadowReplayTier,
    hidden_route_authority: bool,
    product_capability_promoted: bool,
    route_mutation_allowed: bool,
    model_context_injected: bool,
    hidden_cloud_fallback_allowed: bool,
    live_large_model_claimed: bool,
    ssd_as_ram_claimed: bool,
) -> Result<TurboVecRealAdapterExactBaselineShadowReplayProbeSet, Box<dyn std::error::Error>> {
    Ok(
        TurboVecRealAdapterExactBaselineShadowReplayProbeSet::from_parts(
            upstream,
            cases,
            policy,
            proof_refs,
            ledger,
            product_build,
            pro_status,
            status,
            tier,
            hidden_route_authority,
            product_capability_promoted,
            route_mutation_allowed,
            model_context_injected,
            hidden_cloud_fallback_allowed,
            live_large_model_claimed,
            ssd_as_ram_claimed,
        )?,
    )
}

fn ids(start: u64, count: u64) -> Vec<u64> {
    (start..start + count).collect()
}

fn replay_case(
    case_id: &str,
    scenario: TurboVecRealAdapterShadowReplayScenario,
    decision: TurboVecRealAdapterShadowReplayDecision,
    exact: Vec<u64>,
    approx: Vec<u64>,
    allowed: Vec<u64>,
) -> TurboVecRealAdapterShadowReplayCase {
    let denied = ids(9_000, 3);
    let exact_recall_at_k_micros = if exact.is_empty() { 0 } else { 1_000_000 };
    let mut case = TurboVecRealAdapterShadowReplayCase {
        case_id: case_id.to_string(),
        scenario,
        decision,
        query_ref: format!("{QUERY_REF_PREFIX}{case_id}"),
        clean_room_plan_ref: format!("{PLAN_REF_PREFIX}exact-baseline-shadow-replay"),
        replay_seed: 12_000 + case_id.len() as u64,
        sample_count: 64,
        top_k: 5,
        exact_baseline_external_ids: exact,
        approximate_result_external_ids: approx,
        allowed_external_ids: allowed,
        denied_external_ids: denied,
        exact_recall_at_k_micros,
        compressed_recall_at_k_micros: 0,
        recall_floor_micros: 900_000,
        max_allowed_delta_micros: 80_000,
        predicted_p50_latency_micros: 4_000,
        predicted_p95_latency_micros: 8_000,
        predicted_p99_latency_micros: 11_000,
        latency_budget_micros: 12_000,
        timeout_micros: 18_000,
        cancellation_deadline_micros: 16_000,
        planned_fixture_bytes: 8_192,
        planned_scratch_bytes: 16_384,
        planned_total_bytes: 0,
        memory_budget_bytes: 64_000,
        memory_headroom_bytes: 0,
        exact_baseline_ref: format!("{EXACT_BASELINE_REF_PREFIX}{case_id}"),
        fallback_ref: format!("{FALLBACK_REF_PREFIX}{case_id}"),
        rollback_ref: format!("{ROLLBACK_REF_PREFIX}{case_id}"),
        run_event_log_ref: format!("{RUN_EVENT_LOG_REF_PREFIX}{case_id}"),
        answer_packet_ref: format!("{ANSWER_PACKET_REF_PREFIX}{case_id}"),
        shadow_win_recorded: matches!(
            decision,
            TurboVecRealAdapterShadowReplayDecision::RecordShadowWin
        ),
        route_mutation_allowed: false,
        model_context_injected: false,
    };
    case.recompute_totals();
    case.compressed_recall_at_k_micros = real_adapter_recall_at_k_micros(&case);
    case
}

fn replay_cases() -> Vec<TurboVecRealAdapterShadowReplayCase> {
    let mut warm = replay_case(
        "warm_exact_hit",
        TurboVecRealAdapterShadowReplayScenario::WarmExactHit,
        TurboVecRealAdapterShadowReplayDecision::RecordShadowWin,
        ids(1, 5),
        ids(1, 5),
        ids(1, 8),
    );
    warm.shadow_win_recorded = true;

    let cold = replay_case(
        "cold_miss_fallback",
        TurboVecRealAdapterShadowReplayScenario::ColdMissFallback,
        TurboVecRealAdapterShadowReplayDecision::RecordShadowLoss,
        ids(11, 5),
        vec![11, 16],
        ids(11, 8),
    );

    let mut cancel = replay_case(
        "cancellation_fallback",
        TurboVecRealAdapterShadowReplayScenario::CancellationFallback,
        TurboVecRealAdapterShadowReplayDecision::CancelAndFallback,
        ids(21, 5),
        ids(21, 5),
        ids(21, 8),
    );
    cancel.predicted_p99_latency_micros = 21_000;

    let mut memory = replay_case(
        "memory_pressure_abstain",
        TurboVecRealAdapterShadowReplayScenario::MemoryPressureAbstain,
        TurboVecRealAdapterShadowReplayDecision::MemoryAbstain,
        ids(31, 5),
        ids(31, 5),
        ids(31, 8),
    );
    memory.memory_budget_bytes = 16_000;
    memory.recompute_totals();

    let empty = replay_case(
        "empty_allowlist_visible",
        TurboVecRealAdapterShadowReplayScenario::EmptyAllowlistVisible,
        TurboVecRealAdapterShadowReplayDecision::EmptyVisible,
        Vec::new(),
        Vec::new(),
        Vec::new(),
    );

    let privacy = replay_case(
        "privacy_denied_fallback",
        TurboVecRealAdapterShadowReplayScenario::PrivacyDeniedFallback,
        TurboVecRealAdapterShadowReplayDecision::PrivacyFallback,
        ids(41, 5),
        vec![41, 42],
        ids(41, 8),
    );

    let regression = replay_case(
        "recall_regression_fallback",
        TurboVecRealAdapterShadowReplayScenario::RecallRegressionFallback,
        TurboVecRealAdapterShadowReplayDecision::RecallRegressionFallback,
        ids(51, 5),
        vec![51, 52, 56],
        ids(51, 8),
    );

    vec![warm, cold, cancel, memory, empty, privacy, regression]
}

fn policy() -> TurboVecRealAdapterShadowReplayPolicy {
    TurboVecRealAdapterShadowReplayPolicy::fail_closed()
}

fn ledger() -> TurboVecRealAdapterShadowReplayByteLedger {
    TurboVecRealAdapterShadowReplayByteLedger::metadata_only(42_000, 30_000, 96_000)
        .expect("accepted metadata-only byte ledger")
}

fn proof_refs() -> TurboVecRealAdapterShadowReplayProofRefs {
    TurboVecRealAdapterShadowReplayProofRefs {
        source_card_ref: format!("{SOURCE_CARD_REF_PREFIX}accepted"),
        no_product_graph_ref: format!("{NO_PRODUCT_GRAPH_REF_PREFIX}accepted"),
        rollback_ref: format!("{ROLLBACK_REF_PREFIX}accepted"),
        run_event_log_ref: format!("{RUN_EVENT_LOG_REF_PREFIX}accepted"),
        answer_packet_ref: format!("{ANSWER_PACKET_REF_PREFIX}accepted"),
        compatibility_fence_ref: format!("{COMPATIBILITY_REF_PREFIX}accepted"),
        visible_summary: "This exact-baseline shadow replay contract keeps the clean-room TurboVec adapter plan as proposal-only evidence for large local model working sets. It requires AppColdStore exact-baseline comparison, UAS allowlist-before-rank filtering, deterministic held-out replay, cancellation, latency and memory abstention, rollback, RunEventLog, and AnswerPacket visibility. It has no hidden route authority, no live dense 70B claim, no benchmark authority, no adapter build, no product graph mutation, no source import, no runtime bytes, and no L2/L3 product promotion before later witnesses prove real runtime behavior."
            .to_string(),
    }
}

fn red_fixture_results(upstream: &UasAddress) -> Vec<(&'static str, bool)> {
    let mut results = Vec::with_capacity(64);
    for (name, mutation) in case_mutations() {
        let mut cases = replay_cases();
        mutation(&mut cases);
        results.push((
            name,
            build_set(
                upstream.clone(),
                cases,
                policy(),
                proof_refs(),
                ledger(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecRealAdapterShadowReplayStatus::MetadataOnlyShadowReplay,
                TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err(),
        ));
    }
    for (name, mutation) in policy_mutations() {
        let mut policy = policy();
        mutation(&mut policy);
        results.push((
            name,
            build_set(
                upstream.clone(),
                replay_cases(),
                policy,
                proof_refs(),
                ledger(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecRealAdapterShadowReplayStatus::MetadataOnlyShadowReplay,
                TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err(),
        ));
    }
    for (name, mutation) in proof_mutations() {
        let mut proof_refs = proof_refs();
        mutation(&mut proof_refs);
        results.push((
            name,
            build_set(
                upstream.clone(),
                replay_cases(),
                policy(),
                proof_refs,
                ledger(),
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecRealAdapterShadowReplayStatus::MetadataOnlyShadowReplay,
                TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err(),
        ));
    }
    for (name, mutation) in ledger_mutations() {
        let mut ledger = ledger();
        mutation(&mut ledger);
        results.push((
            name,
            build_set(
                upstream.clone(),
                replay_cases(),
                policy(),
                proof_refs(),
                ledger,
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecRealAdapterShadowReplayStatus::MetadataOnlyShadowReplay,
                TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
            )
            .is_err(),
        ));
    }
    for (name, build, pro_status, tier, flag) in claim_cases() {
        results.push((
            name,
            build_set(
                upstream.clone(),
                replay_cases(),
                policy(),
                proof_refs(),
                ledger(),
                build,
                pro_status,
                TurboVecRealAdapterShadowReplayStatus::MetadataOnlyShadowReplay,
                tier,
                matches!(flag, ClaimFlag::HiddenAuthority),
                matches!(flag, ClaimFlag::ProductPromotion),
                matches!(flag, ClaimFlag::RouteMutation),
                matches!(flag, ClaimFlag::ContextInjection),
                matches!(flag, ClaimFlag::HiddenCloud),
                matches!(flag, ClaimFlag::LiveLargeModel),
                matches!(flag, ClaimFlag::SsdAsRam),
            )
            .is_err(),
        ));
    }
    results.push((
        "bad_upstream_plan",
        build_set(
            UasAddress::from_str(
                "wrong_cursor:98f3ae42ac65228fd9a1c1c25cf2bd1a7c0159cd2bc1f51bf2c4e3c14a5f4c15@1779040905000",
            )
            .unwrap_or_else(|_| upstream.clone()),
            replay_cases(),
            policy(),
            proof_refs(),
            ledger(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRealAdapterShadowReplayStatus::MetadataOnlyShadowReplay,
            TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
        )
        .is_err(),
    ));
    results
}

#[allow(clippy::type_complexity)]
fn case_mutations() -> Vec<(
    &'static str,
    Box<dyn Fn(&mut Vec<TurboVecRealAdapterShadowReplayCase>)>,
)> {
    vec![
        (
            "remove_warm",
            Box::new(|cases| cases.remove(0).case_id.clear()),
        ),
        (
            "remove_cold",
            Box::new(|cases| cases.remove(1).case_id.clear()),
        ),
        (
            "remove_cancel",
            Box::new(|cases| cases.remove(2).case_id.clear()),
        ),
        (
            "remove_memory",
            Box::new(|cases| cases.remove(3).case_id.clear()),
        ),
        (
            "remove_empty",
            Box::new(|cases| cases.remove(4).case_id.clear()),
        ),
        (
            "remove_privacy",
            Box::new(|cases| cases.remove(5).case_id.clear()),
        ),
        (
            "remove_regression",
            Box::new(|cases| cases.remove(6).case_id.clear()),
        ),
        (
            "duplicate_case_id",
            Box::new(|cases| cases[1].case_id = cases[0].case_id.clone()),
        ),
        ("zero_seed", Box::new(|cases| cases[0].replay_seed = 0)),
        (
            "low_sample_count",
            Box::new(|cases| cases[0].sample_count = 2),
        ),
        ("bad_top_k", Box::new(|cases| cases[0].top_k = 0)),
        (
            "bad_exact_baseline_ref",
            Box::new(|cases| cases[0].exact_baseline_ref = "baseline:wrong".to_string()),
        ),
        (
            "wrong_declared_recall",
            Box::new(|cases| cases[0].compressed_recall_at_k_micros = 123),
        ),
        (
            "approx_not_allowlisted",
            Box::new(|cases| {
                cases[0].approximate_result_external_ids = vec![777];
                cases[0].compressed_recall_at_k_micros = real_adapter_recall_at_k_micros(&cases[0]);
            }),
        ),
        (
            "denied_id_returned",
            Box::new(|cases| {
                cases[0].approximate_result_external_ids = vec![9_000];
                cases[0].compressed_recall_at_k_micros = real_adapter_recall_at_k_micros(&cases[0]);
            }),
        ),
        (
            "duplicate_approx_id",
            Box::new(|cases| cases[0].approximate_result_external_ids = vec![1, 1]),
        ),
        (
            "false_shadow_win_recall",
            Box::new(|cases| {
                cases[1].shadow_win_recorded = true;
                cases[1].decision = TurboVecRealAdapterShadowReplayDecision::RecordShadowWin;
            }),
        ),
        (
            "bad_latency_order",
            Box::new(|cases| cases[0].predicted_p50_latency_micros = 20_000),
        ),
        (
            "bad_cancellation_deadline",
            Box::new(|cases| cases[0].cancellation_deadline_micros = 99_000),
        ),
        (
            "wrong_memory_total",
            Box::new(|cases| cases[0].planned_total_bytes = 1),
        ),
        (
            "bad_fallback_ref",
            Box::new(|cases| cases[1].fallback_ref = "fallback:wrong".to_string()),
        ),
        (
            "bad_rollback_ref",
            Box::new(|cases| cases[0].rollback_ref = "rollback:wrong".to_string()),
        ),
        (
            "bad_run_event_log_ref",
            Box::new(|cases| cases[0].run_event_log_ref = "log:wrong".to_string()),
        ),
        (
            "bad_answer_packet_ref",
            Box::new(|cases| cases[0].answer_packet_ref = "answer:wrong".to_string()),
        ),
        (
            "route_mutation",
            Box::new(|cases| cases[0].route_mutation_allowed = true),
        ),
        (
            "context_injection",
            Box::new(|cases| cases[0].model_context_injected = true),
        ),
    ]
}

fn policy_mutations() -> Vec<(&'static str, fn(&mut TurboVecRealAdapterShadowReplayPolicy))> {
    vec![
        ("policy_no_baseline", |p| {
            p.exact_app_cold_store_baseline_required = false
        }),
        ("policy_route_authority", |p| p.no_route_authority = false),
        ("policy_context", |p| p.no_model_context_injection = false),
        ("policy_runtime", |p| p.no_runtime_execution = false),
        ("policy_no_answer_packet", |p| {
            p.answer_packet_required = false
        }),
    ]
}

fn proof_mutations() -> Vec<(
    &'static str,
    fn(&mut TurboVecRealAdapterShadowReplayProofRefs),
)> {
    vec![
        ("bad_source_card_ref", |p| {
            p.source_card_ref = "source:wrong".to_string()
        }),
        ("bad_no_product_graph_ref", |p| {
            p.no_product_graph_ref = "graph:wrong".to_string()
        }),
        ("weak_visible_summary", |p| {
            p.visible_summary = "too short".to_string()
        }),
    ]
}

fn ledger_mutations() -> Vec<(
    &'static str,
    fn(&mut TurboVecRealAdapterShadowReplayByteLedger),
)> {
    vec![
        ("additional_source_read", |l| {
            l.additional_raw_source_bytes_inspected = 1
        }),
        ("exact_baseline_bytes_opened", |l| {
            l.exact_baseline_bytes_opened = 1
        }),
        ("index_bytes_opened", |l| l.index_bytes_opened = 1),
        ("adapter_build", |l| l.adapter_build_count = 1),
        ("benchmark_run", |l| l.benchmark_run_count = 1),
        ("runtime_bytes", |l| l.allocated_runtime_bytes = 1),
        ("model_bytes", |l| l.model_bytes_loaded = 1),
        ("provider_call", |l| l.provider_calls_made = 1),
        ("product_graph_mutation", |l| {
            l.product_graph_mutation_count = 1
        }),
    ]
}

// UAS: red-fixture claim axis for TurboVec real-adapter shadow replay.
// Plane: Verification.
// Residency: metadata-only helper; no runtime bytes.
#[derive(Clone, Copy)]
enum ClaimFlag {
    None,
    HiddenAuthority,
    ProductPromotion,
    RouteMutation,
    ContextInjection,
    HiddenCloud,
    LiveLargeModel,
    SsdAsRam,
}

fn claim_cases() -> Vec<(
    &'static str,
    ProductBuild,
    ProStatus,
    TurboVecRealAdapterShadowReplayTier,
    ClaimFlag,
)> {
    vec![
        (
            "product_promoted",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
            ClaimFlag::ProductPromotion,
        ),
        (
            "product_build_mas",
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
            ClaimFlag::None,
        ),
        (
            "pro_status_live",
            ProductBuild::Pro,
            ProStatus::Live,
            TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
            ClaimFlag::None,
        ),
        (
            "tier_t2",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRealAdapterShadowReplayTier::T2L2Route,
            ClaimFlag::None,
        ),
        (
            "hidden_route_authority",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
            ClaimFlag::HiddenAuthority,
        ),
        (
            "route_mutation",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
            ClaimFlag::RouteMutation,
        ),
        (
            "context_injection",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
            ClaimFlag::ContextInjection,
        ),
        (
            "hidden_cloud",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
            ClaimFlag::HiddenCloud,
        ),
        (
            "live_large_model",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
            ClaimFlag::LiveLargeModel,
        ),
        (
            "ssd_as_ram",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRealAdapterShadowReplayTier::T1L1Metadata,
            ClaimFlag::SsdAsRam,
        ),
    ]
}

fn red_pass(results: &[(&'static str, bool)], name: &'static str) -> bool {
    results
        .iter()
        .find_map(|(case, pass)| (*case == name).then_some(*pass))
        .unwrap_or(false)
}

fn add_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
    expected: &str,
    unit: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(actual.to_string()),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "starts_with_or_equals".to_string(),
            value: serde_json::Value::String(expected.to_string()),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(
        name.to_string(),
        actual == expected || actual.starts_with(expected),
    );
}
