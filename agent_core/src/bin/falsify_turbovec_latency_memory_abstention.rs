//! `falsify_turbovec_latency_memory_abstention`
//!
//! Metadata-only witness for `F-TurboVec-LatencyMemoryAbstention`. It proves
//! exact-baseline TurboVec/Eidos compressed retrieval still needs latency,
//! memory, timeout, cancellation, fallback, and abstention envelopes before it
//! can feed large-local-model context selection.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, TurboVecIndexOrgan, TurboVecLatencyMemoryAbstentionPlan,
    TurboVecLatencyMemoryAbstentionPlanSet, TurboVecLatencyMemoryAbstentionPolicy,
    TurboVecLatencyMemoryByteLedger, TurboVecLatencyMemoryPromotionTier,
    TurboVecLatencyMemoryProofRefs, TurboVecLatencyMemoryStatus, TurboVecRetrievalEnvelopeCase,
    TurboVecRetrievalEnvelopeCaseKind, TurboVecRetrievalEnvelopeDecision, UasAddress, UasKind,
    TURBOVEC_LATENCY_MEMORY_ABSTENTION_CURSOR, TURBOVEC_LATENCY_MEMORY_ABSTENTION_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-LatencyMemoryAbstention";
const FIXTURE_ID: &str = "turbovec_latency_memory_abstention_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_latency_memory_abstention.sh";
const RESULT: &str = "artifacts/falsifiers/turbovec_latency_memory_abstention/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_recall_quality_exact_baseline/result.json";
const CREATED_AT_MS: u64 = 1_779_039_500_000;
const SET_METADATA_BYTES: u64 = 26_000;
const SET_FIXTURE_BYTES: u64 = 18_000;
const RECALL_FLOOR_MICROS: u64 = 900_000;
const RED_FIXTURE_FLOOR: u64 = 38;

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
    let upstream = upstream_recall_quality_address()?;
    let plans = accepted_plans(upstream.clone())?;
    let set = build_set(upstream.clone(), plans.clone())?;
    let mut reversed_plans = plans.clone();
    reversed_plans[0].envelope_cases.reverse();
    let reversed = build_set(upstream.clone(), reversed_plans)?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&upstream, &plans)?;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_recall_quality_bound",
            set.upstream_recall_quality_witness_ref
                == "artifact:turbovec_recall_quality_exact_baseline:result",
        ),
        (
            "upstream_cursor_verified",
            set.upstream_recall_quality_address
                .to_string()
                .starts_with("turbovec_recall_quality_exact_baseline_plan:"),
        ),
        (
            "accepted_latency_memory_fixture_present",
            plans
                .iter()
                .any(|plan| plan.plan_id == "turbovec_latency_memory_abstention"),
        ),
        (
            "case_coverage_complete",
            metrics.fast_use_case_count == 1
                && metrics.timeout_abstention_case_count == 1
                && metrics.memory_abstention_case_count == 1
                && metrics.uncertainty_abstention_case_count == 1
                && metrics.empty_visible_case_count == 1
                && red_pass(&red_results, "remove_fast_use_case")
                && red_pass(&red_results, "remove_timeout_case")
                && red_pass(&red_results, "remove_memory_case")
                && red_pass(&red_results, "remove_uncertainty_case")
                && red_pass(&red_results, "remove_empty_case"),
        ),
        (
            "latency_envelope_enforced",
            metrics.timeout_violation_count >= 1
                && red_pass(&red_results, "timeout_risk_selected")
                && red_pass(&red_results, "use_p95_exceeds_budget")
                && red_pass(&red_results, "use_p99_exceeds_timeout")
                && red_pass(&red_results, "bad_latency_order"),
        ),
        (
            "memory_envelope_enforced",
            metrics.memory_violation_count >= 1
                && red_pass(&red_results, "memory_risk_selected")
                && red_pass(&red_results, "use_negative_headroom")
                && red_pass(&red_results, "bad_planned_total_bytes")
                && red_pass(&red_results, "zero_memory_budget"),
        ),
        (
            "timeout_and_cancellation_required",
            red_pass(&red_results, "zero_timeout")
                && red_pass(&red_results, "zero_cancellation")
                && red_pass(&red_results, "cancellation_after_timeout"),
        ),
        (
            "uncertainty_abstention_required",
            metrics.uncertainty_violation_count >= 1
                && red_pass(&red_results, "uncertainty_risk_selected")
                && red_pass(&red_results, "policy_uncertainty_missing"),
        ),
        (
            "abstention_reason_required",
            metrics.abstention_without_reason_count == 0
                && red_pass(&red_results, "timeout_missing_abstention_reason")
                && red_pass(&red_results, "bad_abstention_prefix")
                && red_pass(&red_results, "empty_selected_for_context"),
        ),
        (
            "fallback_route_required",
            metrics.fallback_missing_count == 0
                && red_pass(&red_results, "missing_fallback_route")
                && red_pass(&red_results, "policy_fallback_missing"),
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
                && red_pass(&red_results, "opened_index_bytes")
                && red_pass(&red_results, "loaded_index_bytes")
                && red_pass(&red_results, "allocated_runtime_bytes")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "provider_call_made"),
        ),
        (
            "hidden_route_authority_rejected",
            red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "policy_score_mutates_route")
                && red_pass(&red_results, "case_route_mutation"),
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
                    TurboVecLatencyMemoryPromotionTier::T1L1Metadata
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
        ("case_count", metrics.case_count, 5, "==", "cases"),
        (
            "selected_case_count",
            metrics.selected_case_count,
            1,
            "==",
            "cases",
        ),
        (
            "abstention_case_count",
            metrics.abstention_case_count,
            4,
            "==",
            "cases",
        ),
        (
            "invalid_selected_case_count",
            metrics.invalid_selected_case_count,
            0,
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
            249_856,
            "==",
            "bytes",
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
            value: serde_json::json!(-45_712),
            unit: "bytes".to_string(),
        },
    );
    pass_per_axis.insert(
        "min_memory_headroom_bytes".to_string(),
        metrics.min_memory_headroom_bytes == -45_712,
    );

    measurements.insert(
        "latency_memory_plan_address".to_string(),
        Measurement {
            value: serde_json::json!(set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "latency_memory_plan_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("turbovec_latency_memory_abstention_plan:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "latency_memory_plan_address".to_string(),
        set.set_address
            .to_string()
            .starts_with("turbovec_latency_memory_abstention_plan:"),
    );
    measurements.insert(
        "next_research_to_build_unit".to_string(),
        Measurement {
            value: serde_json::json!(TURBOVEC_LATENCY_MEMORY_ABSTENTION_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_research_to_build_unit".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(TURBOVEC_LATENCY_MEMORY_ABSTENTION_NEXT_CURSOR),
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
            "detail": "No TurboVec crate imported, no index files opened, no runtime buffers allocated, no model/runtime bytes loaded, no live latency claim, and no L2/L3/product promotion."
        })],
        notes: "Builds F-TurboVec-LatencyMemoryAbstention from the exact-baseline recall-quality gate. Scope is T1/L1 metadata/tiny-fixture only: planned latency, p99 timeout, cancellation, memory headroom, uncertainty abstention, fallback, rollback, RunEventLog, AnswerPacket, compatibility fence, and no product/runtime promotion.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_recall_quality_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec recall-quality gate has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_LATENCY_MEMORY_ABSTENTION_CURSOR)
    {
        return Err(
            "upstream TurboVec recall-quality gate does not point at latency/memory".into(),
        );
    }
    for axis in [
        "/pass_per_axis/exact_app_cold_store_baseline_required",
        "/pass_per_axis/recall_floor_or_abstention_required",
        "/pass_per_axis/runtime_and_index_bytes_zero",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(format!("upstream recall-quality axis missing or false: {axis}").into());
        }
    }
    let address = value
        .pointer("/measurements/recall_quality_plan_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("upstream recall-quality address missing")?;
    Ok(UasAddress::from_str(address)?)
}

fn build_set(
    upstream: UasAddress,
    plans: Vec<TurboVecLatencyMemoryAbstentionPlan>,
) -> Result<TurboVecLatencyMemoryAbstentionPlanSet, Box<dyn std::error::Error>> {
    Ok(TurboVecLatencyMemoryAbstentionPlanSet::from_plans(
        upstream,
        plans,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecLatencyMemoryStatus::MetadataOnlyPlan,
        TurboVecLatencyMemoryPromotionTier::T1L1Metadata,
        SET_METADATA_BYTES,
        SET_FIXTURE_BYTES,
        false,
    )?)
}

fn accepted_plans(
    upstream: UasAddress,
) -> Result<Vec<TurboVecLatencyMemoryAbstentionPlan>, Box<dyn std::error::Error>> {
    Ok(vec![TurboVecLatencyMemoryAbstentionPlan {
        plan_id: "turbovec_latency_memory_abstention".to_string(),
        upstream_recall_quality_address: upstream,
        upstream_recall_quality_witness_ref:
            "artifact:turbovec_recall_quality_exact_baseline:result".to_string(),
        status: TurboVecLatencyMemoryStatus::MetadataOnlyPlan,
        promotion_tier: TurboVecLatencyMemoryPromotionTier::T1L1Metadata,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        organs: vec![
            TurboVecIndexOrgan::Eidos,
            TurboVecIndexOrgan::AppColdStore,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            TurboVecIndexOrgan::AnswerPacket,
        ],
        policy: TurboVecLatencyMemoryAbstentionPolicy::fail_closed(),
        envelope_cases: vec![
            envelope_case(
                "fast_use",
                TurboVecRetrievalEnvelopeCaseKind::FastUse,
                TurboVecRetrievalEnvelopeDecision::UseCompressedCache,
            ),
            envelope_case(
                "timeout_abstain",
                TurboVecRetrievalEnvelopeCaseKind::TimeoutAbstain,
                TurboVecRetrievalEnvelopeDecision::AbstainTimeoutRisk,
            ),
            envelope_case(
                "memory_abstain",
                TurboVecRetrievalEnvelopeCaseKind::MemoryAbstain,
                TurboVecRetrievalEnvelopeDecision::AbstainMemoryRisk,
            ),
            envelope_case(
                "uncertainty_abstain",
                TurboVecRetrievalEnvelopeCaseKind::UncertaintyAbstain,
                TurboVecRetrievalEnvelopeDecision::AbstainUncertaintyRisk,
            ),
            envelope_case(
                "empty_visible",
                TurboVecRetrievalEnvelopeCaseKind::EmptyVisible,
                TurboVecRetrievalEnvelopeDecision::EmptyAllowedVisible,
            ),
        ],
        byte_ledger: TurboVecLatencyMemoryByteLedger::metadata_only(
            24_000, 16_000, 96_000, 64_000, 16_000,
        )?,
        proof_refs: proof_refs("turbovec_latency_memory_abstention"),
        hidden_route_authority: false,
        product_capability_promoted: false,
        live_large_model_claimed: false,
        ssd_as_ram_claimed: false,
    }])
}

fn envelope_case(
    case_id: &str,
    kind: TurboVecRetrievalEnvelopeCaseKind,
    decision: TurboVecRetrievalEnvelopeDecision,
) -> TurboVecRetrievalEnvelopeCase {
    let mut case = TurboVecRetrievalEnvelopeCase {
        case_id: case_id.to_string(),
        case_kind: kind,
        query_uas_address: query(case_id),
        top_k: 8,
        planned_candidate_count: 64,
        planned_index_page_count: 4,
        planned_index_bytes: 32_768,
        planned_scratch_bytes: 16_384,
        planned_result_bytes: 4_096,
        planned_total_bytes: 0,
        memory_budget_bytes: 256 * 1024,
        memory_headroom_bytes: 0,
        latency_budget_micros: 12_000,
        predicted_p50_latency_micros: 4_000,
        predicted_p95_latency_micros: 9_000,
        predicted_p99_latency_micros: 18_000,
        timeout_micros: 25_000,
        cancellation_deadline_micros: 20_000,
        uncertainty_micros: 120_000,
        recall_quality_ref: format!("falsifier:F-TurboVec-RecallQualityExactBaseline:{case_id}"),
        recall_floor_micros: RECALL_FLOOR_MICROS,
        declared_recall_at_k_micros: 950_000,
        decision,
        selected_for_context: matches!(
            decision,
            TurboVecRetrievalEnvelopeDecision::UseCompressedCache
        ),
        abstention_reason_ref: None,
        fallback_route_ref: format!("fallback:eidos-exact:{case_id}"),
        rollback_ref: format!("rollback:turbovec-latency-memory:{case_id}"),
        run_event_log_ref: format!("run_event_log:turbovec-latency-memory:{case_id}"),
        answer_packet_ref: format!("answer_packet:turbovec-latency-memory:{case_id}"),
        route_mutation_allowed: false,
    };

    match decision {
        TurboVecRetrievalEnvelopeDecision::AbstainTimeoutRisk => {
            case.predicted_p99_latency_micros = 40_000;
            case.selected_for_context = false;
            case.abstention_reason_ref = Some(format!("abstain:timeout:{case_id}"));
        }
        TurboVecRetrievalEnvelopeDecision::AbstainMemoryRisk => {
            case.planned_index_bytes = 192_000;
            case.planned_scratch_bytes = 53_760;
            case.planned_result_bytes = 4_096;
            case.memory_budget_bytes = 204_144;
            case.selected_for_context = false;
            case.abstention_reason_ref = Some(format!("abstain:memory:{case_id}"));
        }
        TurboVecRetrievalEnvelopeDecision::AbstainUncertaintyRisk => {
            case.uncertainty_micros = 800_000;
            case.selected_for_context = false;
            case.abstention_reason_ref = Some(format!("abstain:uncertainty:{case_id}"));
        }
        TurboVecRetrievalEnvelopeDecision::EmptyAllowedVisible => {
            case.planned_candidate_count = 0;
            case.planned_index_page_count = 0;
            case.planned_index_bytes = 0;
            case.planned_scratch_bytes = 8_192;
            case.selected_for_context = false;
            case.abstention_reason_ref = Some(format!("abstain:empty:{case_id}"));
        }
        TurboVecRetrievalEnvelopeDecision::UseCompressedCache => {}
    }
    case.recompute_totals();
    case
}

fn query(label: &str) -> UasAddress {
    UasAddress::new(
        UasKind::Other("turbovec_latency_memory_query".to_string()),
        label.as_bytes(),
        CREATED_AT_MS,
    )
}

fn proof_refs(id: &str) -> TurboVecLatencyMemoryProofRefs {
    TurboVecLatencyMemoryProofRefs {
        falsifier_ref: format!("falsifier:F-TurboVec-LatencyMemoryAbstention:{id}"),
        rollback_ref: format!("rollback:turbovec-latency-memory:{id}"),
        run_event_log_ref: format!("run_event_log:turbovec-latency-memory:{id}"),
        answer_packet_ref: format!("answer_packet:turbovec-latency-memory:{id}"),
        compatibility_fence_ref: format!("compat:turbovec-latency-memory:{id}"),
    }
}

fn red_fixture_results(
    upstream: &UasAddress,
    plans: &[TurboVecLatencyMemoryAbstentionPlan],
) -> Result<Vec<(String, bool)>, Box<dyn std::error::Error>> {
    let mut results = Vec::new();
    let mut push = |name: &str, mutate: fn(&mut Vec<TurboVecLatencyMemoryAbstentionPlan>)| {
        let mut red = plans.to_vec();
        mutate(&mut red);
        let passed = build_set(upstream.clone(), red).is_err();
        results.push((name.to_string(), passed));
    };

    push("remove_fast_use_case", |plans| {
        plans[0]
            .envelope_cases
            .retain(|case| case.case_kind != TurboVecRetrievalEnvelopeCaseKind::FastUse);
    });
    push("remove_timeout_case", |plans| {
        plans[0]
            .envelope_cases
            .retain(|case| case.case_kind != TurboVecRetrievalEnvelopeCaseKind::TimeoutAbstain);
    });
    push("remove_memory_case", |plans| {
        plans[0]
            .envelope_cases
            .retain(|case| case.case_kind != TurboVecRetrievalEnvelopeCaseKind::MemoryAbstain);
    });
    push("remove_uncertainty_case", |plans| {
        plans[0]
            .envelope_cases
            .retain(|case| case.case_kind != TurboVecRetrievalEnvelopeCaseKind::UncertaintyAbstain);
    });
    push("remove_empty_case", |plans| {
        plans[0]
            .envelope_cases
            .retain(|case| case.case_kind != TurboVecRetrievalEnvelopeCaseKind::EmptyVisible);
    });
    push("timeout_risk_selected", |plans| {
        plans[0].envelope_cases[1].selected_for_context = true;
    });
    push("use_p95_exceeds_budget", |plans| {
        plans[0].envelope_cases[0].predicted_p95_latency_micros = 20_000;
    });
    push("use_p99_exceeds_timeout", |plans| {
        plans[0].envelope_cases[0].predicted_p99_latency_micros = 40_000;
    });
    push("bad_latency_order", |plans| {
        plans[0].envelope_cases[0].predicted_p50_latency_micros = 10_000;
        plans[0].envelope_cases[0].predicted_p95_latency_micros = 9_000;
    });
    push("memory_risk_selected", |plans| {
        plans[0].envelope_cases[2].selected_for_context = true;
    });
    push("use_negative_headroom", |plans| {
        let case = &mut plans[0].envelope_cases[0];
        case.memory_budget_bytes = 1;
        case.recompute_totals();
    });
    push("bad_planned_total_bytes", |plans| {
        plans[0].envelope_cases[0].planned_total_bytes = 1;
    });
    push("zero_memory_budget", |plans| {
        plans[0].envelope_cases[0].memory_budget_bytes = 0;
    });
    push("zero_timeout", |plans| {
        plans[0].envelope_cases[0].timeout_micros = 0;
    });
    push("zero_cancellation", |plans| {
        plans[0].envelope_cases[0].cancellation_deadline_micros = 0;
    });
    push("cancellation_after_timeout", |plans| {
        plans[0].envelope_cases[0].cancellation_deadline_micros =
            plans[0].envelope_cases[0].timeout_micros + 1;
    });
    push("uncertainty_risk_selected", |plans| {
        plans[0].envelope_cases[3].selected_for_context = true;
    });
    push("policy_uncertainty_missing", |plans| {
        plans[0].policy.uncertainty_abstention_required = false;
    });
    push("timeout_missing_abstention_reason", |plans| {
        plans[0].envelope_cases[1].abstention_reason_ref = None;
    });
    push("bad_abstention_prefix", |plans| {
        plans[0].envelope_cases[1].abstention_reason_ref = Some("reason:timeout".to_string());
    });
    push("empty_selected_for_context", |plans| {
        plans[0].envelope_cases[4].selected_for_context = true;
    });
    push("missing_fallback_route", |plans| {
        plans[0].envelope_cases[1].fallback_route_ref = "route:eidos".to_string();
    });
    push("policy_fallback_missing", |plans| {
        plans[0].policy.fallback_route_required = false;
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
    push("hidden_route_authority", |plans| {
        plans[0].hidden_route_authority = true;
    });
    push("policy_score_mutates_route", |plans| {
        plans[0].policy.compressed_score_can_mutate_route = true;
    });
    push("case_route_mutation", |plans| {
        plans[0].envelope_cases[0].route_mutation_allowed = true;
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
        plans[0].promotion_tier = TurboVecLatencyMemoryPromotionTier::T2L2Route;
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

    let mut set_promoted = plans.to_vec();
    let set_promoted_passed = TurboVecLatencyMemoryAbstentionPlanSet::from_plans(
        upstream.clone(),
        set_promoted.split_off(0),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecLatencyMemoryStatus::MetadataOnlyPlan,
        TurboVecLatencyMemoryPromotionTier::T1L1Metadata,
        SET_METADATA_BYTES,
        SET_FIXTURE_BYTES,
        true,
    )
    .is_err();
    results.push(("set_product_promoted".to_string(), set_promoted_passed));
    let metadata_budget_passed = TurboVecLatencyMemoryAbstentionPlanSet::from_plans(
        upstream.clone(),
        plans.to_vec(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecLatencyMemoryStatus::MetadataOnlyPlan,
        TurboVecLatencyMemoryPromotionTier::T1L1Metadata,
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
