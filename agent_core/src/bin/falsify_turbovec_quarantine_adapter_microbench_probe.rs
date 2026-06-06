//! `falsify_turbovec_quarantine_adapter_microbench_probe`
//!
//! Synthetic-only witness for `F-TurboVec-QuarantineAdapterMicrobenchProbe`.
//! It proves the next TurboVec/Eidos adapter step is quarantined,
//! deterministic, exact-baseline checked, panic-contained, non-authoritative,
//! rollbackable, and unable to mutate large-model routes.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, TurboVecIndexOrgan, TurboVecQuarantineAdapterMicrobenchProbe,
    TurboVecQuarantineAdapterMicrobenchProbeSet, TurboVecQuarantineAdapterMode,
    TurboVecQuarantineMicrobenchByteLedger, TurboVecQuarantineMicrobenchCase,
    TurboVecQuarantineMicrobenchDecision, TurboVecQuarantineMicrobenchPolicy,
    TurboVecQuarantineMicrobenchPromotionTier, TurboVecQuarantineMicrobenchProofRefs,
    TurboVecQuarantineMicrobenchScenario, TurboVecQuarantineMicrobenchStatus, UasAddress, UasKind,
    TURBOVEC_QUARANTINE_ADAPTER_MICROBENCH_CURSOR,
    TURBOVEC_QUARANTINE_ADAPTER_MICROBENCH_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-QuarantineAdapterMicrobenchProbe";
const FIXTURE_ID: &str = "turbovec_quarantine_adapter_microbench_probe_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_quarantine_adapter_microbench_probe.sh";
const RESULT: &str =
    "artifacts/falsifiers/turbovec_quarantine_adapter_microbench_probe/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_runtime_shadow_benchmark_plan/result.json";
const CREATED_AT_MS: u64 = 1_779_040_200_000;
const SET_METADATA_BYTES: u64 = 34_000;
const SET_FIXTURE_BYTES: u64 = 32_000;
const RED_FIXTURE_FLOOR: u64 = 36;

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
    let upstream = upstream_shadow_address()?;
    let probes = accepted_probes(upstream.clone())?;
    let set = build_set(upstream.clone(), probes.clone())?;
    let mut reversed_probes = probes.clone();
    reversed_probes[0].cases.reverse();
    let reversed = build_set(upstream.clone(), reversed_probes)?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&upstream, &probes)?;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_shadow_plan_bound",
            set.upstream_shadow_witness_ref
                == "artifact:turbovec_runtime_shadow_benchmark_plan:result"
                && set
                    .upstream_shadow_address
                    .to_string()
                    .starts_with("turbovec_runtime_shadow_benchmark_plan:"),
        ),
        (
            "synthetic_quarantine_probe_present",
            probes
                .iter()
                .any(|probe| probe.probe_id == "turbovec_quarantine_microbench"),
        ),
        (
            "scenario_coverage_complete",
            metrics.warm_approx_win_count == 1
                && metrics.cold_exact_fallback_count == 1
                && metrics.recall_loss_fallback_count == 1
                && metrics.cancellation_fallback_count == 1
                && metrics.empty_allowlist_count == 1
                && metrics.panic_fallback_count == 1
                && red_pass(&red_results, "remove_warm")
                && red_pass(&red_results, "remove_cold")
                && red_pass(&red_results, "remove_recall")
                && red_pass(&red_results, "remove_cancel")
                && red_pass(&red_results, "remove_empty")
                && red_pass(&red_results, "remove_panic"),
        ),
        (
            "deterministic_fixture_enforced",
            red_pass(&red_results, "zero_seed")
                && red_pass(&red_results, "bad_dimension_low")
                && red_pass(&red_results, "bad_dimension_high")
                && red_pass(&red_results, "zero_vectors")
                && red_pass(&red_results, "huge_vectors"),
        ),
        (
            "exact_baseline_and_recall_enforced",
            red_pass(&red_results, "missing_exact_baseline")
                && red_pass(&red_results, "bad_exact_prefix")
                && red_pass(&red_results, "recall_laundered")
                && red_pass(&red_results, "bad_recall_bounds")
                && red_pass(&red_results, "missing_top1"),
        ),
        (
            "filter_before_rank_visible",
            red_pass(&red_results, "missing_allowlist")
                && red_pass(&red_results, "bad_allowlist_prefix")
                && red_pass(&red_results, "allowlist_exceeds_vectors")
                && red_pass(&red_results, "empty_has_allowlist")
                && red_pass(&red_results, "non_empty_zero_allowlist"),
        ),
        (
            "latency_memory_cancellation_enforced",
            red_pass(&red_results, "bad_latency_order")
                && red_pass(&red_results, "zero_timeout")
                && red_pass(&red_results, "cancellation_after_timeout")
                && red_pass(&red_results, "cancel_latency_fits")
                && red_pass(&red_results, "bad_synthetic_total"),
        ),
        (
            "panic_containment_enforced",
            metrics.adapter_panic_caught_count == 1
                && red_pass(&red_results, "panic_not_caught")
                && red_pass(&red_results, "panic_missing_reason"),
        ),
        (
            "non_authoritative_output_required",
            metrics.non_authoritative_win_count == 1
                && red_pass(&red_results, "authoritative_output")
                && red_pass(&red_results, "warm_win_has_reason")
                && red_pass(&red_results, "non_warm_win"),
        ),
        (
            "fallback_reason_required",
            metrics.fallback_case_count == 5
                && metrics.missing_reason_count == 0
                && red_pass(&red_results, "loss_missing_reason")
                && red_pass(&red_results, "bad_reason_prefix")
                && red_pass(&red_results, "missing_fallback_route"),
        ),
        (
            "product_runtime_model_bytes_zero",
            metrics.opened_product_index_bytes == 0
                && metrics.loaded_product_index_bytes == 0
                && metrics.model_bytes_loaded == 0
                && metrics.runtime_model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.copied_product_file_count == 0
                && red_pass(&red_results, "opened_product_index")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "provider_call")
                && red_pass(&red_results, "copied_product_file"),
        ),
        (
            "provenance_clean_room_enforced",
            metrics.imported_external_crate_count == 0
                && metrics.quarantined_external_code_bytes == 0
                && red_pass(&red_results, "direct_import")
                && red_pass(&red_results, "product_integrated")
                && red_pass(&red_results, "external_crate_imported")
                && red_pass(&red_results, "quarantined_external_bytes")
                && red_pass(&red_results, "missing_provenance"),
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
            "large_model_claims_rejected",
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
                    TurboVecQuarantineMicrobenchPromotionTier::T1L1Metadata
                ),
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
            "accepted_probe_count",
            probes.len() as u64,
            1,
            "==",
            "probes",
        ),
        ("case_count", metrics.case_count, 6, "==", "cases"),
        (
            "non_authoritative_win_count",
            metrics.non_authoritative_win_count,
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
            "panic_fallback_count",
            metrics.panic_fallback_count,
            1,
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
            "max_vector_dimension",
            metrics.max_vector_dimension,
            128,
            "==",
            "dimensions",
        ),
        (
            "max_vector_count",
            metrics.max_vector_count,
            160,
            "==",
            "vectors",
        ),
        (
            "max_predicted_p99_latency_micros",
            metrics.max_predicted_p99_latency_micros,
            24_000,
            "==",
            "micros",
        ),
        (
            "max_synthetic_total_bytes",
            metrics.max_synthetic_total_bytes,
            73_728,
            "==",
            "bytes",
        ),
        (
            "max_recall_delta_micros",
            metrics.max_recall_delta_micros,
            260_000,
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
            value: serde_json::json!(57_344),
            unit: "bytes".to_string(),
        },
    );
    pass_per_axis.insert(
        "min_memory_headroom_bytes".to_string(),
        metrics.min_memory_headroom_bytes == 57_344,
    );

    measurements.insert(
        "quarantine_microbench_address".to_string(),
        Measurement {
            value: serde_json::json!(set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "quarantine_microbench_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("turbovec_quarantine_adapter_microbench_probe:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "quarantine_microbench_address".to_string(),
        set.set_address
            .to_string()
            .starts_with("turbovec_quarantine_adapter_microbench_probe:"),
    );
    measurements.insert(
        "next_research_to_build_unit".to_string(),
        Measurement {
            value: serde_json::json!(TURBOVEC_QUARANTINE_ADAPTER_MICROBENCH_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_research_to_build_unit".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(TURBOVEC_QUARANTINE_ADAPTER_MICROBENCH_NEXT_CURSOR),
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
            "kind": "synthetic_quarantine_scope",
            "detail": "No TurboVec crate imported, no product index opened, no external adapter code copied, no model/runtime bytes loaded, no provider calls, no route mutation, no model-context injection, and no L2/L3/product promotion."
        })],
        notes: "Builds F-TurboVec-QuarantineAdapterMicrobenchProbe from the runtime shadow benchmark plan. Scope is T1/L1 synthetic quarantine evidence only: deterministic tiny fixture, exact-baseline recall comparison, filter-before-rank allowlist proof, cancellation and panic fallback, clean-room provenance ref, rollback, RunEventLog, AnswerPacket, zero product/model/provider/external-code bytes, and no live large-model claim.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_shadow_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec runtime shadow gate has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_QUARANTINE_ADAPTER_MICROBENCH_CURSOR)
    {
        return Err(
            "upstream TurboVec runtime shadow gate does not point at quarantine microbench".into(),
        );
    }
    for axis in [
        "/pass_per_axis/deterministic_replay_seed_and_sample_floor_required",
        "/pass_per_axis/runtime_and_index_bytes_zero",
        "/pass_per_axis/no_route_or_context_authority",
        "/pass_per_axis/product_promotion_rejected",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(format!("upstream runtime shadow axis missing or false: {axis}").into());
        }
    }
    let address = value
        .pointer("/measurements/runtime_shadow_plan_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("upstream runtime shadow address missing")?;
    Ok(UasAddress::from_str(address)?)
}

fn build_set(
    upstream: UasAddress,
    probes: Vec<TurboVecQuarantineAdapterMicrobenchProbe>,
) -> Result<TurboVecQuarantineAdapterMicrobenchProbeSet, Box<dyn std::error::Error>> {
    Ok(TurboVecQuarantineAdapterMicrobenchProbeSet::from_probes(
        upstream,
        probes,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecQuarantineMicrobenchStatus::SyntheticHarnessOnly,
        TurboVecQuarantineMicrobenchPromotionTier::T1L1Metadata,
        SET_METADATA_BYTES,
        SET_FIXTURE_BYTES,
        false,
    )?)
}

fn accepted_probes(
    upstream: UasAddress,
) -> Result<Vec<TurboVecQuarantineAdapterMicrobenchProbe>, Box<dyn std::error::Error>> {
    Ok(vec![TurboVecQuarantineAdapterMicrobenchProbe {
        probe_id: "turbovec_quarantine_microbench".to_string(),
        upstream_shadow_address: upstream,
        upstream_shadow_witness_ref: "artifact:turbovec_runtime_shadow_benchmark_plan:result"
            .to_string(),
        status: TurboVecQuarantineMicrobenchStatus::SyntheticHarnessOnly,
        promotion_tier: TurboVecQuarantineMicrobenchPromotionTier::T1L1Metadata,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        adapter_mode: TurboVecQuarantineAdapterMode::SyntheticHarnessOnly,
        organs: vec![
            TurboVecIndexOrgan::Eidos,
            TurboVecIndexOrgan::AppColdStore,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            TurboVecIndexOrgan::AnswerPacket,
        ],
        policy: TurboVecQuarantineMicrobenchPolicy::fail_closed(),
        cases: vec![
            microbench_case(
                "warm",
                TurboVecQuarantineMicrobenchScenario::WarmApproxWin,
                TurboVecQuarantineMicrobenchDecision::RecordNonAuthoritativeWin,
            ),
            microbench_case(
                "cold",
                TurboVecQuarantineMicrobenchScenario::ColdExactFallback,
                TurboVecQuarantineMicrobenchDecision::ExactFallback,
            ),
            microbench_case(
                "recall",
                TurboVecQuarantineMicrobenchScenario::RecallLossFallback,
                TurboVecQuarantineMicrobenchDecision::RecallFallback,
            ),
            microbench_case(
                "cancel",
                TurboVecQuarantineMicrobenchScenario::CancellationFallback,
                TurboVecQuarantineMicrobenchDecision::CancelFallback,
            ),
            microbench_case(
                "empty",
                TurboVecQuarantineMicrobenchScenario::EmptyAllowlistVisible,
                TurboVecQuarantineMicrobenchDecision::EmptyVisible,
            ),
            microbench_case(
                "panic",
                TurboVecQuarantineMicrobenchScenario::AdapterPanicFallback,
                TurboVecQuarantineMicrobenchDecision::PanicFallback,
            ),
        ],
        byte_ledger: TurboVecQuarantineMicrobenchByteLedger::synthetic_only(
            32_000, 28_000, 48_000, 24_000,
        )?,
        proof_refs: proof_refs("turbovec_quarantine_microbench"),
        hidden_route_authority: false,
        product_capability_promoted: false,
        live_large_model_claimed: false,
        ssd_as_ram_claimed: false,
    }])
}

fn microbench_case(
    case_id: &str,
    scenario: TurboVecQuarantineMicrobenchScenario,
    decision: TurboVecQuarantineMicrobenchDecision,
) -> TurboVecQuarantineMicrobenchCase {
    let mut case = TurboVecQuarantineMicrobenchCase {
        case_id: case_id.to_string(),
        scenario,
        query_uas_address: query(case_id),
        deterministic_seed: 7,
        vector_dimension: 128,
        vector_count: 160,
        top_k: 8,
        allowlist_count: 80,
        exact_baseline_ref: format!("exact_baseline:turbovec-quarantine:{case_id}"),
        allowlist_proof_ref: format!("allowlist:turbovec-quarantine:{case_id}"),
        exact_top1_uas_ref: format!("uas:exact:{case_id}"),
        adapter_top1_uas_ref: format!("uas:adapter:{case_id}"),
        exact_recall_at_k_micros: 970_000,
        adapter_recall_at_k_micros: 940_000,
        recall_floor_micros: 900_000,
        max_allowed_recall_delta_micros: 80_000,
        predicted_p50_latency_micros: 1_500,
        predicted_p95_latency_micros: 5_000,
        predicted_p99_latency_micros: 9_000,
        latency_budget_micros: 7_000,
        timeout_micros: 14_000,
        cancellation_deadline_micros: 10_000,
        synthetic_vector_bytes: 49_152,
        synthetic_scratch_bytes: 24_576,
        synthetic_total_bytes: 0,
        memory_budget_bytes: 128 * 1024,
        memory_headroom_bytes: 0,
        decision,
        non_authoritative_output: true,
        adapter_panic_caught: false,
        fallback_reason_ref: None,
        fallback_route_ref: format!("fallback:turbovec-quarantine:{case_id}"),
        rollback_ref: format!("rollback:turbovec-quarantine:{case_id}"),
        run_event_log_ref: format!("run_event_log:turbovec-quarantine:{case_id}"),
        answer_packet_ref: format!("answer_packet:turbovec-quarantine:{case_id}"),
        route_mutation_allowed: false,
        model_context_injected: false,
    };
    match decision {
        TurboVecQuarantineMicrobenchDecision::RecordNonAuthoritativeWin => {}
        TurboVecQuarantineMicrobenchDecision::ExactFallback => {
            case.fallback_reason_ref = Some(format!("microbench:exact:{case_id}"));
        }
        TurboVecQuarantineMicrobenchDecision::RecallFallback => {
            case.adapter_recall_at_k_micros = 710_000;
            case.fallback_reason_ref = Some(format!("microbench:recall:{case_id}"));
        }
        TurboVecQuarantineMicrobenchDecision::CancelFallback => {
            case.predicted_p99_latency_micros = 24_000;
            case.fallback_reason_ref = Some(format!("microbench:cancel:{case_id}"));
        }
        TurboVecQuarantineMicrobenchDecision::EmptyVisible => {
            case.allowlist_count = 0;
            case.vector_count = 1;
            case.synthetic_vector_bytes = 0;
            case.fallback_reason_ref = Some(format!("microbench:empty:{case_id}"));
        }
        TurboVecQuarantineMicrobenchDecision::PanicFallback => {
            case.adapter_panic_caught = true;
            case.fallback_reason_ref = Some(format!("microbench:panic:{case_id}"));
        }
    }
    case.recompute_totals();
    case
}

fn query(label: &str) -> UasAddress {
    UasAddress::new(
        UasKind::Other("turbovec_quarantine_microbench_query".to_string()),
        label.as_bytes(),
        CREATED_AT_MS,
    )
}

fn proof_refs(id: &str) -> TurboVecQuarantineMicrobenchProofRefs {
    TurboVecQuarantineMicrobenchProofRefs {
        falsifier_ref: format!("falsifier:F-TurboVec-QuarantineAdapterMicrobenchProbe:{id}"),
        rollback_ref: format!("rollback:turbovec-quarantine:{id}"),
        run_event_log_ref: format!("run_event_log:turbovec-quarantine:{id}"),
        answer_packet_ref: format!("answer_packet:turbovec-quarantine:{id}"),
        compatibility_fence_ref: format!("compat:turbovec-quarantine:{id}"),
        provenance_ref: format!("provenance:turbovec-quarantine:{id}:synthetic-only"),
    }
}

fn red_fixture_results(
    upstream: &UasAddress,
    probes: &[TurboVecQuarantineAdapterMicrobenchProbe],
) -> Result<Vec<(String, bool)>, Box<dyn std::error::Error>> {
    let mut results = Vec::new();
    let mut push = |name: &str, mutate: fn(&mut Vec<TurboVecQuarantineAdapterMicrobenchProbe>)| {
        let mut red = probes.to_vec();
        mutate(&mut red);
        let passed = build_set(upstream.clone(), red).is_err();
        results.push((name.to_string(), passed));
    };

    push("remove_warm", |probes| {
        probes[0]
            .cases
            .retain(|case| case.scenario != TurboVecQuarantineMicrobenchScenario::WarmApproxWin);
    });
    push("remove_cold", |probes| {
        probes[0].cases.retain(|case| {
            case.scenario != TurboVecQuarantineMicrobenchScenario::ColdExactFallback
        });
    });
    push("remove_recall", |probes| {
        probes[0].cases.retain(|case| {
            case.scenario != TurboVecQuarantineMicrobenchScenario::RecallLossFallback
        });
    });
    push("remove_cancel", |probes| {
        probes[0].cases.retain(|case| {
            case.scenario != TurboVecQuarantineMicrobenchScenario::CancellationFallback
        });
    });
    push("remove_empty", |probes| {
        probes[0].cases.retain(|case| {
            case.scenario != TurboVecQuarantineMicrobenchScenario::EmptyAllowlistVisible
        });
    });
    push("remove_panic", |probes| {
        probes[0].cases.retain(|case| {
            case.scenario != TurboVecQuarantineMicrobenchScenario::AdapterPanicFallback
        });
    });
    push("zero_seed", |probes| {
        probes[0].cases[0].deterministic_seed = 0
    });
    push("bad_dimension_low", |probes| {
        probes[0].cases[0].vector_dimension = 1
    });
    push("bad_dimension_high", |probes| {
        probes[0].cases[0].vector_dimension = 8192
    });
    push("zero_vectors", |probes| probes[0].cases[0].vector_count = 0);
    push("huge_vectors", |probes| {
        probes[0].cases[0].vector_count = 8192
    });
    push("missing_exact_baseline", |probes| {
        probes[0].cases[0].exact_baseline_ref.clear()
    });
    push("bad_exact_prefix", |probes| {
        probes[0].cases[0].exact_baseline_ref = "baseline:wrong".to_string()
    });
    push("recall_laundered", |probes| {
        probes[0].cases[2].adapter_recall_at_k_micros = 940_000
    });
    push("bad_recall_bounds", |probes| {
        probes[0].cases[0].recall_floor_micros = 10
    });
    push("missing_top1", |probes| {
        probes[0].cases[0].exact_top1_uas_ref.clear()
    });
    push("missing_allowlist", |probes| {
        probes[0].cases[0].allowlist_proof_ref.clear()
    });
    push("bad_allowlist_prefix", |probes| {
        probes[0].cases[0].allowlist_proof_ref = "postfilter:bad".to_string()
    });
    push("allowlist_exceeds_vectors", |probes| {
        probes[0].cases[0].allowlist_count = probes[0].cases[0].vector_count + 1
    });
    push("empty_has_allowlist", |probes| {
        probes[0].cases[4].allowlist_count = 1
    });
    push("non_empty_zero_allowlist", |probes| {
        probes[0].cases[0].allowlist_count = 0
    });
    push("bad_latency_order", |probes| {
        probes[0].cases[0].predicted_p50_latency_micros = 10_000
    });
    push("zero_timeout", |probes| {
        probes[0].cases[0].timeout_micros = 0
    });
    push("cancellation_after_timeout", |probes| {
        probes[0].cases[0].cancellation_deadline_micros = 20_000
    });
    push("cancel_latency_fits", |probes| {
        probes[0].cases[3].predicted_p99_latency_micros = 9_000
    });
    push("bad_synthetic_total", |probes| {
        probes[0].cases[0].synthetic_total_bytes += 1
    });
    push("panic_not_caught", |probes| {
        probes[0].cases[5].adapter_panic_caught = false
    });
    push("panic_missing_reason", |probes| {
        probes[0].cases[5].fallback_reason_ref = None
    });
    push("authoritative_output", |probes| {
        probes[0].cases[0].non_authoritative_output = false
    });
    push("warm_win_has_reason", |probes| {
        probes[0].cases[0].fallback_reason_ref = Some("microbench:bad".to_string())
    });
    push("non_warm_win", |probes| {
        probes[0].cases[1].decision =
            TurboVecQuarantineMicrobenchDecision::RecordNonAuthoritativeWin
    });
    push("loss_missing_reason", |probes| {
        probes[0].cases[1].fallback_reason_ref = None
    });
    push("bad_reason_prefix", |probes| {
        probes[0].cases[1].fallback_reason_ref = Some("reason:bad".to_string())
    });
    push("missing_fallback_route", |probes| {
        probes[0].cases[1].fallback_route_ref.clear()
    });
    push("opened_product_index", |probes| {
        probes[0].byte_ledger.opened_product_index_bytes = 1
    });
    push("model_bytes_loaded", |probes| {
        probes[0].byte_ledger.model_bytes_loaded = 1
    });
    push("provider_call", |probes| {
        probes[0].byte_ledger.provider_calls_made = 1
    });
    push("copied_product_file", |probes| {
        probes[0].byte_ledger.copied_product_file_count = 1
    });
    push("direct_import", |probes| {
        probes[0].adapter_mode = TurboVecQuarantineAdapterMode::DirectImport
    });
    push("product_integrated", |probes| {
        probes[0].adapter_mode = TurboVecQuarantineAdapterMode::ProductIntegrated
    });
    push("external_crate_imported", |probes| {
        probes[0].byte_ledger.imported_external_crate_count = 1
    });
    push("quarantined_external_bytes", |probes| {
        probes[0].byte_ledger.quarantined_external_code_bytes = 1
    });
    push("missing_provenance", |probes| {
        probes[0].proof_refs.provenance_ref.clear()
    });
    push("route_mutation_allowed", |probes| {
        probes[0].cases[0].route_mutation_allowed = true
    });
    push("model_context_injected", |probes| {
        probes[0].cases[0].model_context_injected = true
    });
    push("hidden_route_authority", |probes| {
        probes[0].hidden_route_authority = true
    });
    push("product_capability_promoted", |probes| {
        probes[0].product_capability_promoted = true
    });
    push("product_build_mas", |probes| {
        probes[0].product_build = ProductBuild::Mas
    });
    push("pro_status_live", |probes| {
        probes[0].pro_status = ProStatus::Live
    });
    push("promotion_tier_t2", |probes| {
        probes[0].promotion_tier = TurboVecQuarantineMicrobenchPromotionTier::T2L2Route
    });
    push("live_large_model_claimed", |probes| {
        probes[0].live_large_model_claimed = true
    });
    push("ssd_as_ram_claimed", |probes| {
        probes[0].ssd_as_ram_claimed = true
    });

    let set_product_promoted = TurboVecQuarantineAdapterMicrobenchProbeSet::from_probes(
        upstream.clone(),
        probes.to_vec(),
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecQuarantineMicrobenchStatus::SyntheticHarnessOnly,
        TurboVecQuarantineMicrobenchPromotionTier::T1L1Metadata,
        SET_METADATA_BYTES,
        SET_FIXTURE_BYTES,
        true,
    )
    .is_err();
    results.push(("set_product_promoted".to_string(), set_product_promoted));

    Ok(results)
}

fn red_pass(results: &[(String, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(candidate, _)| candidate == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}
