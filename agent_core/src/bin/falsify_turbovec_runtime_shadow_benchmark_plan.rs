//! `falsify_turbovec_runtime_shadow_benchmark_plan`
//!
//! Metadata-only witness for `F-TurboVec-RuntimeShadowBenchmarkPlan`. It turns
//! the TurboVec/Eidos latency-memory envelope into a tiny shadow replay plan:
//! future runtime probes must be quarantined, deterministic, non-authoritative,
//! rollbackable, AnswerPacket-visible, and unable to mutate large-model routes.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, TurboVecIndexOrgan, TurboVecRuntimeShadowBenchmarkPlan,
    TurboVecRuntimeShadowBenchmarkPlanSet, TurboVecRuntimeShadowByteLedger,
    TurboVecRuntimeShadowDecision, TurboVecRuntimeShadowPolicy, TurboVecRuntimeShadowPromotionTier,
    TurboVecRuntimeShadowProofRefs, TurboVecRuntimeShadowReplayCase, TurboVecRuntimeShadowScenario,
    TurboVecRuntimeShadowStatus, UasAddress, UasKind, TURBOVEC_RUNTIME_SHADOW_BENCHMARK_CURSOR,
    TURBOVEC_RUNTIME_SHADOW_BENCHMARK_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-RuntimeShadowBenchmarkPlan";
const FIXTURE_ID: &str = "turbovec_runtime_shadow_benchmark_plan_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_runtime_shadow_benchmark_plan.sh";
const RESULT: &str = "artifacts/falsifiers/turbovec_runtime_shadow_benchmark_plan/result.json";
const UPSTREAM_RESULT: &str = "artifacts/falsifiers/turbovec_latency_memory_abstention/result.json";
const CREATED_AT_MS: u64 = 1_779_039_600_000;
const SET_METADATA_BYTES: u64 = 30_000;
const SET_FIXTURE_BYTES: u64 = 24_000;
const RED_FIXTURE_FLOOR: u64 = 44;

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
    let upstream = upstream_latency_memory_address()?;
    let plans = accepted_plans(upstream.clone())?;
    let set = build_set(upstream.clone(), plans.clone())?;
    let mut reversed_plans = plans.clone();
    reversed_plans[0].replay_cases.reverse();
    let reversed = build_set(upstream.clone(), reversed_plans)?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&upstream, &plans)?;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_latency_memory_bound",
            set.upstream_latency_memory_witness_ref
                == "artifact:turbovec_latency_memory_abstention:result",
        ),
        (
            "upstream_cursor_verified",
            set.upstream_latency_memory_address
                .to_string()
                .starts_with("turbovec_latency_memory_abstention_plan:"),
        ),
        (
            "accepted_shadow_fixture_present",
            plans
                .iter()
                .any(|plan| plan.plan_id == "turbovec_runtime_shadow_benchmark"),
        ),
        (
            "replay_scenario_coverage_complete",
            metrics.warm_hit_case_count == 1
                && metrics.cold_miss_case_count == 1
                && metrics.cancellation_case_count == 1
                && metrics.memory_pressure_case_count == 1
                && metrics.empty_allowlist_case_count == 1
                && metrics.recall_regression_case_count == 1
                && red_pass(&red_results, "remove_warm_hit")
                && red_pass(&red_results, "remove_cold_miss")
                && red_pass(&red_results, "remove_cancellation")
                && red_pass(&red_results, "remove_memory")
                && red_pass(&red_results, "remove_empty")
                && red_pass(&red_results, "remove_recall_regression"),
        ),
        (
            "deterministic_replay_seed_and_sample_floor_required",
            red_pass(&red_results, "zero_replay_seed")
                && red_pass(&red_results, "low_sample_count")
                && red_pass(&red_results, "huge_sample_count"),
        ),
        (
            "exact_baseline_replay_required",
            red_pass(&red_results, "bad_recall_bounds")
                && red_pass(&red_results, "below_floor_shadow_win")
                && red_pass(&red_results, "high_delta_shadow_win")
                && red_pass(&red_results, "recall_regression_fits"),
        ),
        (
            "latency_timeout_cancellation_enforced",
            red_pass(&red_results, "use_p95_exceeds_budget")
                && red_pass(&red_results, "use_p99_exceeds_timeout")
                && red_pass(&red_results, "bad_latency_order")
                && red_pass(&red_results, "zero_timeout")
                && red_pass(&red_results, "zero_cancellation")
                && red_pass(&red_results, "cancellation_after_timeout")
                && red_pass(&red_results, "cancellation_fits"),
        ),
        (
            "memory_envelope_enforced",
            metrics.min_memory_headroom_bytes == -32_000
                && red_pass(&red_results, "zero_memory_budget")
                && red_pass(&red_results, "memory_fits")
                && red_pass(&red_results, "bad_planned_total_bytes"),
        ),
        (
            "shadow_win_gate_enforced",
            metrics.shadow_win_count == 1
                && metrics.invalid_win_count == 0
                && red_pass(&red_results, "non_warm_shadow_win")
                && red_pass(&red_results, "shadow_win_missing_flag")
                && red_pass(&red_results, "shadow_win_has_reason")
                && red_pass(&red_results, "non_win_records_win"),
        ),
        (
            "fallback_reason_required",
            metrics.fallback_case_count == 5
                && metrics.missing_reason_count == 0
                && red_pass(&red_results, "loss_missing_reason")
                && red_pass(&red_results, "bad_reason_prefix")
                && red_pass(&red_results, "missing_fallback_route")
                && red_pass(&red_results, "empty_has_candidates"),
        ),
        (
            "rollback_run_event_answer_packet_required",
            red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "compatibility_fence_missing"),
        ),
        (
            "runtime_and_index_bytes_zero",
            metrics.opened_index_bytes == 0
                && metrics.loaded_index_bytes == 0
                && metrics.allocated_runtime_bytes == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.copied_product_file_count == 0
                && red_pass(&red_results, "opened_index_bytes")
                && red_pass(&red_results, "loaded_index_bytes")
                && red_pass(&red_results, "allocated_runtime_bytes")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "provider_call_made")
                && red_pass(&red_results, "copied_product_file"),
        ),
        (
            "no_route_or_context_authority",
            metrics.route_mutation_count == 0
                && metrics.model_context_injection_count == 0
                && red_pass(&red_results, "route_mutation_allowed")
                && red_pass(&red_results, "model_context_injected")
                && red_pass(&red_results, "hidden_route_authority"),
        ),
        (
            "product_promotion_rejected",
            red_pass(&red_results, "product_capability_promoted")
                && red_pass(&red_results, "product_build_mas")
                && red_pass(&red_results, "pro_status_live")
                && red_pass(&red_results, "promotion_tier_t2")
                && red_pass(&red_results, "set_product_promoted"),
        ),
        (
            "large_model_and_ssd_claims_rejected",
            red_pass(&red_results, "live_large_model_claimed")
                && red_pass(&red_results, "ssd_as_ram_claimed"),
        ),
        (
            "reversed_order_address_deterministic",
            set.set_address == reversed.set_address,
        ),
        (
            "layer_separation_required",
            matches!(set.product_build, ProductBuild::Pro)
                && matches!(set.pro_status, ProStatus::ResearchCandidate)
                && matches!(
                    set.promotion_tier,
                    TurboVecRuntimeShadowPromotionTier::T1L1Metadata
                ),
        ),
        (
            "metadata_budget_enforced",
            red_pass(&red_results, "set_metadata_budget_exceeded")
                && red_pass(&red_results, "plan_metadata_budget_exceeded"),
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
        (
            "accepted_fixture_count",
            plans.len() as u64,
            1,
            "==",
            "plans",
        ),
        ("case_count", metrics.case_count, 6, "==", "cases"),
        (
            "shadow_win_count",
            metrics.shadow_win_count,
            1,
            "==",
            "cases",
        ),
        (
            "fallback_case_count",
            metrics.fallback_case_count,
            5,
            "==",
            "cases",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            RED_FIXTURE_FLOOR,
            ">=",
            "fixtures",
        ),
        (
            "max_predicted_p99_latency_micros",
            metrics.max_predicted_p99_latency_micros,
            40_000,
            "==",
            "micros",
        ),
        (
            "max_planned_total_bytes",
            metrics.max_planned_total_bytes,
            160_000,
            "==",
            "bytes",
        ),
        (
            "max_recall_delta_micros",
            metrics.max_recall_delta_micros,
            200_000,
            "==",
            "micros",
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

    measurements.insert(
        "min_memory_headroom_bytes".to_string(),
        Measurement {
            value: serde_json::json!(metrics.min_memory_headroom_bytes),
            unit: "bytes".to_string(),
        },
    );
    thresholds.insert(
        "min_memory_headroom_bytes".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(-32_000),
            unit: "bytes".to_string(),
        },
    );
    pass_per_axis.insert(
        "min_memory_headroom_bytes".to_string(),
        metrics.min_memory_headroom_bytes == -32_000,
    );

    measurements.insert(
        "runtime_shadow_plan_address".to_string(),
        Measurement {
            value: serde_json::json!(set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "runtime_shadow_plan_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("turbovec_runtime_shadow_benchmark_plan:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "runtime_shadow_plan_address".to_string(),
        set.set_address
            .to_string()
            .starts_with("turbovec_runtime_shadow_benchmark_plan:"),
    );
    measurements.insert(
        "next_research_to_build_unit".to_string(),
        Measurement {
            value: serde_json::json!(TURBOVEC_RUNTIME_SHADOW_BENCHMARK_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_research_to_build_unit".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(TURBOVEC_RUNTIME_SHADOW_BENCHMARK_NEXT_CURSOR),
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
        anomalies: vec![serde_json::json!({
            "kind": "metadata_only_scope",
            "detail": "No TurboVec crate imported, no index files opened, no runtime buffers allocated, no model/runtime bytes loaded, no live benchmark claim, no route mutation, and no L2/L3/product promotion."
        })],
        notes: "Builds F-TurboVec-RuntimeShadowBenchmarkPlan from the latency/memory abstention gate. Scope is T1/L1 metadata/tiny-fixture only: deterministic shadow replay plan, sample floor, exact-baseline comparison, timeout/cancellation/memory fallbacks, rollback, RunEventLog, AnswerPacket, compatibility fence, zero runtime/index/model/provider bytes, and no product/runtime promotion.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_latency_memory_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec latency/memory gate has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_RUNTIME_SHADOW_BENCHMARK_CURSOR)
    {
        return Err(
            "upstream TurboVec latency/memory gate does not point at shadow benchmark".into(),
        );
    }
    for axis in [
        "/pass_per_axis/latency_envelope_enforced",
        "/pass_per_axis/memory_envelope_enforced",
        "/pass_per_axis/runtime_and_index_bytes_zero",
        "/pass_per_axis/product_promotion_rejected",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(format!("upstream latency/memory axis missing or false: {axis}").into());
        }
    }
    let address = value
        .pointer("/measurements/latency_memory_plan_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("upstream latency/memory address missing")?;
    Ok(UasAddress::from_str(address)?)
}

fn build_set(
    upstream: UasAddress,
    plans: Vec<TurboVecRuntimeShadowBenchmarkPlan>,
) -> Result<TurboVecRuntimeShadowBenchmarkPlanSet, Box<dyn std::error::Error>> {
    Ok(TurboVecRuntimeShadowBenchmarkPlanSet::from_plans(
        upstream,
        plans,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecRuntimeShadowStatus::MetadataOnlyPlan,
        TurboVecRuntimeShadowPromotionTier::T1L1Metadata,
        SET_METADATA_BYTES,
        SET_FIXTURE_BYTES,
        false,
    )?)
}

fn accepted_plans(
    upstream: UasAddress,
) -> Result<Vec<TurboVecRuntimeShadowBenchmarkPlan>, Box<dyn std::error::Error>> {
    Ok(vec![TurboVecRuntimeShadowBenchmarkPlan {
        plan_id: "turbovec_runtime_shadow_benchmark".to_string(),
        upstream_latency_memory_address: upstream,
        upstream_latency_memory_witness_ref: "artifact:turbovec_latency_memory_abstention:result"
            .to_string(),
        status: TurboVecRuntimeShadowStatus::MetadataOnlyPlan,
        promotion_tier: TurboVecRuntimeShadowPromotionTier::T1L1Metadata,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        organs: vec![
            TurboVecIndexOrgan::Eidos,
            TurboVecIndexOrgan::AppColdStore,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            TurboVecIndexOrgan::AnswerPacket,
        ],
        policy: TurboVecRuntimeShadowPolicy::fail_closed(),
        replay_cases: vec![
            replay_case(
                "warm_hit",
                TurboVecRuntimeShadowScenario::WarmHitReplay,
                TurboVecRuntimeShadowDecision::RecordShadowWin,
            ),
            replay_case(
                "cold_miss",
                TurboVecRuntimeShadowScenario::ColdMissReplay,
                TurboVecRuntimeShadowDecision::RecordShadowLoss,
            ),
            replay_case(
                "cancel",
                TurboVecRuntimeShadowScenario::CancellationReplay,
                TurboVecRuntimeShadowDecision::CancelAndFallback,
            ),
            replay_case(
                "memory",
                TurboVecRuntimeShadowScenario::MemoryPressureReplay,
                TurboVecRuntimeShadowDecision::MemoryAbstain,
            ),
            replay_case(
                "empty",
                TurboVecRuntimeShadowScenario::EmptyAllowlistReplay,
                TurboVecRuntimeShadowDecision::EmptyVisible,
            ),
            replay_case(
                "recall_regression",
                TurboVecRuntimeShadowScenario::RecallRegressionReplay,
                TurboVecRuntimeShadowDecision::RecallRegressionFallback,
            ),
        ],
        byte_ledger: TurboVecRuntimeShadowByteLedger::metadata_only(28_000, 20_000, 96_000)?,
        proof_refs: proof_refs("turbovec_runtime_shadow_benchmark"),
        hidden_route_authority: false,
        product_capability_promoted: false,
        live_large_model_claimed: false,
        ssd_as_ram_claimed: false,
    }])
}

fn replay_case(
    case_id: &str,
    scenario: TurboVecRuntimeShadowScenario,
    decision: TurboVecRuntimeShadowDecision,
) -> TurboVecRuntimeShadowReplayCase {
    let mut case = TurboVecRuntimeShadowReplayCase {
        case_id: case_id.to_string(),
        scenario,
        query_uas_address: query(case_id),
        replay_seed: 42,
        sample_count: 64,
        top_k: 8,
        planned_candidate_count: 32,
        exact_recall_at_k_micros: 960_000,
        compressed_recall_at_k_micros: 940_000,
        recall_floor_micros: 900_000,
        max_allowed_recall_delta_micros: 60_000,
        predicted_p50_latency_micros: 4_000,
        predicted_p95_latency_micros: 9_000,
        predicted_p99_latency_micros: 18_000,
        latency_budget_micros: 12_000,
        timeout_micros: 25_000,
        cancellation_deadline_micros: 20_000,
        planned_fixture_bytes: 24_576,
        planned_scratch_bytes: 16_384,
        planned_total_bytes: 0,
        memory_budget_bytes: 96 * 1024,
        memory_headroom_bytes: 0,
        decision,
        shadow_win_recorded: matches!(decision, TurboVecRuntimeShadowDecision::RecordShadowWin),
        shadow_reason_ref: None,
        fallback_route_ref: format!("fallback:turbovec-shadow:{case_id}"),
        rollback_ref: format!("rollback:turbovec-shadow:{case_id}"),
        run_event_log_ref: format!("run_event_log:turbovec-shadow:{case_id}"),
        answer_packet_ref: format!("answer_packet:turbovec-shadow:{case_id}"),
        route_mutation_allowed: false,
        model_context_injected: false,
    };
    match decision {
        TurboVecRuntimeShadowDecision::RecordShadowWin => {}
        TurboVecRuntimeShadowDecision::RecordShadowLoss => {
            case.shadow_reason_ref = Some(format!("shadow:loss:{case_id}"));
        }
        TurboVecRuntimeShadowDecision::CancelAndFallback => {
            case.predicted_p99_latency_micros = 40_000;
            case.shadow_reason_ref = Some(format!("shadow:cancel:{case_id}"));
        }
        TurboVecRuntimeShadowDecision::MemoryAbstain => {
            case.planned_fixture_bytes = 96_000;
            case.planned_scratch_bytes = 64_000;
            case.memory_budget_bytes = 128_000;
            case.shadow_reason_ref = Some(format!("shadow:memory:{case_id}"));
        }
        TurboVecRuntimeShadowDecision::EmptyVisible => {
            case.planned_candidate_count = 0;
            case.sample_count = 1;
            case.planned_fixture_bytes = 0;
            case.shadow_reason_ref = Some(format!("shadow:empty:{case_id}"));
        }
        TurboVecRuntimeShadowDecision::RecallRegressionFallback => {
            case.compressed_recall_at_k_micros = 760_000;
            case.shadow_reason_ref = Some(format!("shadow:recall:{case_id}"));
        }
    }
    case.recompute_totals();
    case
}

fn query(label: &str) -> UasAddress {
    UasAddress::new(
        UasKind::Other("turbovec_shadow_replay_query".to_string()),
        label.as_bytes(),
        CREATED_AT_MS,
    )
}

fn proof_refs(id: &str) -> TurboVecRuntimeShadowProofRefs {
    TurboVecRuntimeShadowProofRefs {
        falsifier_ref: format!("falsifier:F-TurboVec-RuntimeShadowBenchmarkPlan:{id}"),
        rollback_ref: format!("rollback:turbovec-shadow:{id}"),
        run_event_log_ref: format!("run_event_log:turbovec-shadow:{id}"),
        answer_packet_ref: format!("answer_packet:turbovec-shadow:{id}"),
        compatibility_fence_ref: format!("compat:turbovec-shadow:{id}"),
    }
}

fn red_fixture_results(
    upstream: &UasAddress,
    plans: &[TurboVecRuntimeShadowBenchmarkPlan],
) -> Result<Vec<(String, bool)>, Box<dyn std::error::Error>> {
    let mut results = Vec::new();
    let mut push = |name: &str, mutate: fn(&mut Vec<TurboVecRuntimeShadowBenchmarkPlan>)| {
        let mut red = plans.to_vec();
        mutate(&mut red);
        let passed = build_set(upstream.clone(), red).is_err();
        results.push((name.to_string(), passed));
    };

    push("remove_warm_hit", |plans| {
        plans[0]
            .replay_cases
            .retain(|case| case.scenario != TurboVecRuntimeShadowScenario::WarmHitReplay);
    });
    push("remove_cold_miss", |plans| {
        plans[0]
            .replay_cases
            .retain(|case| case.scenario != TurboVecRuntimeShadowScenario::ColdMissReplay);
    });
    push("remove_cancellation", |plans| {
        plans[0]
            .replay_cases
            .retain(|case| case.scenario != TurboVecRuntimeShadowScenario::CancellationReplay);
    });
    push("remove_memory", |plans| {
        plans[0]
            .replay_cases
            .retain(|case| case.scenario != TurboVecRuntimeShadowScenario::MemoryPressureReplay);
    });
    push("remove_empty", |plans| {
        plans[0]
            .replay_cases
            .retain(|case| case.scenario != TurboVecRuntimeShadowScenario::EmptyAllowlistReplay);
    });
    push("remove_recall_regression", |plans| {
        plans[0]
            .replay_cases
            .retain(|case| case.scenario != TurboVecRuntimeShadowScenario::RecallRegressionReplay);
    });
    push("zero_replay_seed", |plans| {
        plans[0].replay_cases[0].replay_seed = 0;
    });
    push("low_sample_count", |plans| {
        plans[0].replay_cases[0].sample_count = 3;
    });
    push("huge_sample_count", |plans| {
        plans[0].replay_cases[0].sample_count = 20_000;
    });
    push("bad_top_k_zero", |plans| {
        plans[0].replay_cases[0].top_k = 0;
    });
    push("bad_top_k_huge", |plans| {
        plans[0].replay_cases[0].top_k = 100;
    });
    push("non_empty_zero_candidates", |plans| {
        plans[0].replay_cases[0].planned_candidate_count = 0;
    });
    push("bad_planned_total_bytes", |plans| {
        plans[0].replay_cases[0].planned_total_bytes = 1;
    });
    push("zero_memory_budget", |plans| {
        plans[0].replay_cases[0].memory_budget_bytes = 0;
    });
    push("zero_latency_budget", |plans| {
        plans[0].replay_cases[0].latency_budget_micros = 0;
    });
    push("zero_timeout", |plans| {
        plans[0].replay_cases[0].timeout_micros = 0;
    });
    push("zero_cancellation", |plans| {
        plans[0].replay_cases[0].cancellation_deadline_micros = 0;
    });
    push("cancellation_after_timeout", |plans| {
        plans[0].replay_cases[0].cancellation_deadline_micros =
            plans[0].replay_cases[0].timeout_micros + 1;
    });
    push("use_p95_exceeds_budget", |plans| {
        plans[0].replay_cases[0].predicted_p95_latency_micros = 20_000;
        plans[0].replay_cases[0].predicted_p99_latency_micros = 21_000;
    });
    push("use_p99_exceeds_timeout", |plans| {
        plans[0].replay_cases[0].predicted_p99_latency_micros = 40_000;
    });
    push("bad_latency_order", |plans| {
        plans[0].replay_cases[0].predicted_p50_latency_micros = 10_000;
        plans[0].replay_cases[0].predicted_p95_latency_micros = 9_000;
    });
    push("bad_recall_bounds", |plans| {
        plans[0].replay_cases[0].compressed_recall_at_k_micros = 1_100_000;
    });
    push("below_floor_shadow_win", |plans| {
        plans[0].replay_cases[0].compressed_recall_at_k_micros = 800_000;
    });
    push("high_delta_shadow_win", |plans| {
        let case = &mut plans[0].replay_cases[0];
        case.exact_recall_at_k_micros = 1_000_000;
        case.compressed_recall_at_k_micros = 900_000;
        case.recall_floor_micros = 850_000;
    });
    push("non_warm_shadow_win", |plans| {
        let case = &mut plans[0].replay_cases[1];
        case.decision = TurboVecRuntimeShadowDecision::RecordShadowWin;
        case.shadow_win_recorded = true;
        case.shadow_reason_ref = None;
    });
    push("shadow_win_missing_flag", |plans| {
        plans[0].replay_cases[0].shadow_win_recorded = false;
    });
    push("shadow_win_has_reason", |plans| {
        plans[0].replay_cases[0].shadow_reason_ref = Some("shadow:bad-win".to_string());
    });
    push("non_win_records_win", |plans| {
        plans[0].replay_cases[2].shadow_win_recorded = true;
    });
    push("loss_missing_reason", |plans| {
        plans[0].replay_cases[1].shadow_reason_ref = None;
    });
    push("bad_reason_prefix", |plans| {
        plans[0].replay_cases[1].shadow_reason_ref = Some("reason:loss".to_string());
    });
    push("cancellation_fits", |plans| {
        plans[0].replay_cases[2].predicted_p99_latency_micros = 18_000;
    });
    push("memory_fits", |plans| {
        let case = &mut plans[0].replay_cases[3];
        case.memory_budget_bytes = 512_000;
        case.recompute_totals();
    });
    push("empty_has_candidates", |plans| {
        plans[0].replay_cases[4].planned_candidate_count = 1;
    });
    push("empty_win_recorded", |plans| {
        plans[0].replay_cases[4].shadow_win_recorded = true;
    });
    push("recall_regression_fits", |plans| {
        plans[0].replay_cases[5].compressed_recall_at_k_micros = 940_000;
    });
    push("missing_fallback_route", |plans| {
        plans[0].replay_cases[1].fallback_route_ref = "route:turbovec".to_string();
    });
    push("rollback_missing", |plans| {
        plans[0].proof_refs.rollback_ref = "missing:rollback".to_string();
    });
    push("run_event_log_missing", |plans| {
        plans[0].proof_refs.run_event_log_ref = "missing:run_event_log".to_string();
    });
    push("answer_packet_missing", |plans| {
        plans[0].proof_refs.answer_packet_ref = "missing:answer_packet".to_string();
    });
    push("compatibility_fence_missing", |plans| {
        plans[0].proof_refs.compatibility_fence_ref = "missing:compat".to_string();
    });
    push("opened_index_bytes", |plans| {
        plans[0].byte_ledger.opened_index_bytes = 1;
    });
    push("loaded_index_bytes", |plans| {
        plans[0].byte_ledger.loaded_index_bytes = 1;
    });
    push("allocated_runtime_bytes", |plans| {
        plans[0].byte_ledger.allocated_runtime_bytes = 1;
    });
    push("runtime_bytes_loaded", |plans| {
        plans[0].byte_ledger.runtime_bytes_loaded = 1;
    });
    push("model_bytes_loaded", |plans| {
        plans[0].byte_ledger.model_bytes_loaded = 1;
    });
    push("provider_call_made", |plans| {
        plans[0].byte_ledger.provider_calls_made = 1;
    });
    push("copied_product_file", |plans| {
        plans[0].byte_ledger.copied_product_file_count = 1;
    });
    push("route_mutation_allowed", |plans| {
        plans[0].replay_cases[0].route_mutation_allowed = true;
    });
    push("model_context_injected", |plans| {
        plans[0].replay_cases[0].model_context_injected = true;
    });
    push("hidden_route_authority", |plans| {
        plans[0].hidden_route_authority = true;
    });
    push("product_capability_promoted", |plans| {
        plans[0].product_capability_promoted = true;
    });
    push("product_build_mas", |plans| {
        plans[0].product_build = ProductBuild::Mas;
    });
    push("pro_status_live", |plans| {
        plans[0].pro_status = ProStatus::Live;
    });
    push("promotion_tier_t2", |plans| {
        plans[0].promotion_tier = TurboVecRuntimeShadowPromotionTier::T2L2Route;
    });
    push("live_large_model_claimed", |plans| {
        plans[0].live_large_model_claimed = true;
    });
    push("ssd_as_ram_claimed", |plans| {
        plans[0].ssd_as_ram_claimed = true;
    });
    push("plan_metadata_budget_exceeded", |plans| {
        plans[0].byte_ledger.metadata_bytes_read = 900_000;
    });

    let set_promoted_passed = TurboVecRuntimeShadowBenchmarkPlanSet::from_plans(
        upstream.clone(),
        plans.to_vec(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecRuntimeShadowStatus::MetadataOnlyPlan,
        TurboVecRuntimeShadowPromotionTier::T1L1Metadata,
        SET_METADATA_BYTES,
        SET_FIXTURE_BYTES,
        true,
    )
    .is_err();
    results.push(("set_product_promoted".to_string(), set_promoted_passed));

    let metadata_budget_passed = TurboVecRuntimeShadowBenchmarkPlanSet::from_plans(
        upstream.clone(),
        plans.to_vec(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecRuntimeShadowStatus::MetadataOnlyPlan,
        TurboVecRuntimeShadowPromotionTier::T1L1Metadata,
        900_000,
        SET_FIXTURE_BYTES,
        false,
    )
    .is_err();
    results.push((
        "set_metadata_budget_exceeded".to_string(),
        metadata_budget_passed,
    ));

    Ok(results)
}

fn red_pass(results: &[(String, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(candidate, _)| candidate == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}
