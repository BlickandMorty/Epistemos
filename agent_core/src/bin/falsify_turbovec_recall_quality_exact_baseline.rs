//! `falsify_turbovec_recall_quality_exact_baseline`
//!
//! Metadata-only witness for `F-TurboVec-RecallQualityExactBaseline`. It proves
//! TurboVec/Eidos compressed retrieval must compare against exact AppColdStore
//! baselines, abstain on below-floor recall, exclude forbidden IDs, and remain
//! unable to mutate large-local-model routes before runtime proof.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    recall_at_k_micros, stable_external_id_for_uas, ProStatus, ProductBuild, TurboVecIndexOrgan,
    TurboVecRecallQualityByteLedger, TurboVecRecallQualityExactBaselinePlan,
    TurboVecRecallQualityExactBaselinePlanSet, TurboVecRecallQualityPolicy,
    TurboVecRecallQualityPromotionTier, TurboVecRecallQualityProofRefs,
    TurboVecRecallQualityStatus, TurboVecRecallQueryFixture, TurboVecRecallQueryKind, UasAddress,
    UasKind, TURBOVEC_RECALL_QUALITY_EXACT_BASELINE_CURSOR,
    TURBOVEC_RECALL_QUALITY_EXACT_BASELINE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-RecallQualityExactBaseline";
const FIXTURE_ID: &str = "turbovec_recall_quality_exact_baseline_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_recall_quality_exact_baseline.sh";
const RESULT: &str = "artifacts/falsifiers/turbovec_recall_quality_exact_baseline/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_crash_safe_persistent_index/result.json";
const CREATED_AT_MS: u64 = 1_779_039_400_000;
const SET_METADATA_BYTES: u64 = 22_000;
const SET_FIXTURE_BYTES: u64 = 14_000;
const RECALL_FLOOR_MICROS: u64 = 900_000;

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
        "{FALSIFIER_ID}: overall_pass={} queries={} red_fixture_rejection_count={} next={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["query_count"].value,
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
    let upstream = upstream_persistent_index_address()?;
    let plans = accepted_plans(upstream.clone())?;
    let set = build_set(upstream.clone(), plans.clone())?;
    let mut reversed_plans = plans.clone();
    reversed_plans[0].query_fixtures.reverse();
    for query in &mut reversed_plans[0].query_fixtures {
        query.approximate_result_external_ids.reverse();
        query.allowed_external_ids.reverse();
    }
    let reversed = build_set(upstream.clone(), reversed_plans)?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&upstream, &plans)?;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_crash_safe_persistent_index_bound",
            set.upstream_persistent_index_witness_ref
                == "artifact:turbovec_crash_safe_persistent_index:result",
        ),
        (
            "upstream_cursor_verified",
            set.upstream_persistent_index_address
                .to_string()
                .starts_with("turbovec_crash_safe_persistent_index_plan:"),
        ),
        (
            "accepted_recall_fixture_present",
            plans
                .iter()
                .any(|plan| plan.plan_id == "turbovec_recall_quality_exact_baseline"),
        ),
        (
            "query_coverage_complete",
            metrics.exact_hit_query_count == 1
                && metrics.private_deleted_excluded_query_count == 1
                && metrics.duplicate_source_deduped_query_count == 1
                && metrics.recall_miss_abstained_query_count == 1
                && metrics.empty_allowed_visible_query_count == 1
                && red_pass(&red_results, "remove_exact_hit_query")
                && red_pass(&red_results, "remove_private_deleted_query")
                && red_pass(&red_results, "remove_duplicate_dedup_query")
                && red_pass(&red_results, "remove_recall_miss_query")
                && red_pass(&red_results, "remove_empty_visible_query"),
        ),
        (
            "exact_app_cold_store_baseline_required",
            red_pass(&red_results, "bad_exact_baseline_ref")
                && red_pass(&red_results, "missing_exact_exhaustive_flag")
                && red_pass(&red_results, "declared_recall_laundered"),
        ),
        (
            "recall_floor_or_abstention_required",
            metrics.below_floor_without_fallback_count == 0
                && red_pass(&red_results, "below_floor_without_fallback")
                && red_pass(&red_results, "fallback_ref_missing")
                && red_pass(&red_results, "policy_miss_fallback_missing"),
        ),
        (
            "allowlist_subset_required",
            red_pass(&red_results, "result_not_in_allowlist")
                && red_pass(&red_results, "policy_allowlist_missing"),
        ),
        (
            "deleted_private_unknown_excluded",
            metrics.forbidden_result_count == 0
                && red_pass(&red_results, "deleted_id_returned")
                && red_pass(&red_results, "private_id_returned")
                && red_pass(&red_results, "unknown_id_returned")
                && red_pass(&red_results, "baseline_contains_private_id")
                && red_pass(&red_results, "policy_forbidden_exclusion_missing"),
        ),
        (
            "duplicate_ids_rejected",
            metrics.duplicate_result_count == 0
                && red_pass(&red_results, "duplicate_exact_baseline_id")
                && red_pass(&red_results, "duplicate_result_id")
                && red_pass(&red_results, "duplicate_allowlist_id")
                && red_pass(&red_results, "policy_duplicate_dedup_missing"),
        ),
        (
            "empty_result_answer_packet_required",
            red_pass(&red_results, "empty_result_no_answer_packet")
                && red_pass(&red_results, "empty_result_returns_id")
                && red_pass(&red_results, "policy_empty_answer_packet_missing"),
        ),
        (
            "latency_memory_ledger_declared",
            red_pass(&red_results, "latency_budget_zero")
                && red_pass(&red_results, "planned_memory_zero")
                && red_pass(&red_results, "policy_latency_missing")
                && red_pass(&red_results, "policy_memory_missing"),
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
            metrics.exact_baseline_bytes_opened == 0
                && metrics.index_bytes_opened == 0
                && metrics.index_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "exact_baseline_bytes_opened")
                && red_pass(&red_results, "index_bytes_opened")
                && red_pass(&red_results, "index_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "provider_call_made"),
        ),
        (
            "hidden_route_authority_rejected",
            red_pass(&red_results, "hidden_route_authority")
                && red_pass(&red_results, "query_route_mutation")
                && red_pass(&red_results, "policy_eidos_route_authority"),
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
                    TurboVecRecallQualityPromotionTier::T1L1Metadata
                ),
        ),
        (
            "metadata_budget_enforced",
            red_pass(&red_results, "set_metadata_budget_exceeded")
                && red_pass(&red_results, "plan_metadata_budget_exceeded"),
        ),
        (
            "red_fixture_rejection_floor",
            red_fixture_rejection_count >= 45,
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

    for (name, actual, expected, unit) in [
        ("accepted_fixture_count", plans.len() as u64, 1, "plans"),
        ("query_count", metrics.query_count, 5, "queries"),
        (
            "exact_hit_query_count",
            metrics.exact_hit_query_count,
            1,
            "queries",
        ),
        (
            "recall_miss_abstained_query_count",
            metrics.recall_miss_abstained_query_count,
            1,
            "queries",
        ),
        (
            "empty_allowed_visible_query_count",
            metrics.empty_allowed_visible_query_count,
            1,
            "queries",
        ),
        (
            "forbidden_result_count",
            metrics.forbidden_result_count,
            0,
            "ids",
        ),
        (
            "below_floor_without_fallback_count",
            metrics.below_floor_without_fallback_count,
            0,
            "queries",
        ),
        (
            "red_fixture_rejection_count",
            red_fixture_rejection_count,
            45,
            "fixtures",
        ),
        (
            "worst_non_empty_recall_micros",
            metrics.worst_non_empty_recall_micros,
            500_000,
            "micros",
        ),
        (
            "recall_floor_micros",
            RECALL_FLOOR_MICROS,
            RECALL_FLOOR_MICROS,
            "micros",
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            actual,
            if name == "red_fixture_rejection_count" {
                ">="
            } else {
                "=="
            },
            expected,
            unit,
        );
    }

    measurements.insert(
        "recall_quality_plan_address".to_string(),
        Measurement {
            value: serde_json::json!(set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "recall_quality_plan_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("turbovec_recall_quality_exact_baseline_plan:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "recall_quality_plan_address".to_string(),
        set.set_address
            .to_string()
            .starts_with("turbovec_recall_quality_exact_baseline_plan:"),
    );
    measurements.insert(
        "next_research_to_build_unit".to_string(),
        Measurement {
            value: serde_json::json!(TURBOVEC_RECALL_QUALITY_EXACT_BASELINE_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_research_to_build_unit".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(TURBOVEC_RECALL_QUALITY_EXACT_BASELINE_NEXT_CURSOR),
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
            "detail": "No TurboVec crate imported, no exact baseline files opened, no index files opened, no model/runtime bytes loaded, no live recall-quality claim, and no L2/L3/product promotion."
        })],
        notes: "Builds F-TurboVec-RecallQualityExactBaseline from the crash-safe persistent-index gate. Scope is T1/L1 metadata/tiny-fixture only: exact AppColdStore baseline refs, held-out query classes, recall floor or abstention, allowlist subset, deleted/private/unknown exclusion, rollback, RunEventLog, AnswerPacket, compatibility fence, and no product/runtime promotion.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_persistent_index_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec persistent-index gate has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_RECALL_QUALITY_EXACT_BASELINE_CURSOR)
    {
        return Err(
            "upstream TurboVec persistent-index gate does not point at recall quality".into(),
        );
    }
    for axis in [
        "/pass_per_axis/app_cold_store_truth_required",
        "/pass_per_axis/partial_write_rollback_required",
        "/pass_per_axis/runtime_and_index_bytes_zero",
    ] {
        if value.pointer(axis).and_then(serde_json::Value::as_bool) != Some(true) {
            return Err(format!("upstream persistent-index axis missing or false: {axis}").into());
        }
    }
    let address = value
        .pointer("/measurements/persistent_index_plan_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("upstream persistent-index address missing")?;
    Ok(UasAddress::from_str(address)?)
}

fn build_set(
    upstream: UasAddress,
    plans: Vec<TurboVecRecallQualityExactBaselinePlan>,
) -> Result<TurboVecRecallQualityExactBaselinePlanSet, Box<dyn std::error::Error>> {
    Ok(TurboVecRecallQualityExactBaselinePlanSet::from_plans(
        upstream,
        plans,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecRecallQualityStatus::MetadataOnlyPlan,
        TurboVecRecallQualityPromotionTier::T1L1Metadata,
        SET_METADATA_BYTES,
        SET_FIXTURE_BYTES,
        false,
    )?)
}

fn accepted_plans(
    upstream: UasAddress,
) -> Result<Vec<TurboVecRecallQualityExactBaselinePlan>, Box<dyn std::error::Error>> {
    let exact_ids = ids(&["exact-a", "exact-b"]);
    let privacy_ids = ids(&["privacy-safe"]);
    let duplicate_ids = ids(&["duplicate-source"]);
    let miss_ids = ids(&["miss-a", "miss-b"]);
    let mut queries = vec![
        query(
            "exact_hit",
            TurboVecRecallQueryKind::ExactHit,
            exact_ids.clone(),
            exact_ids.clone(),
            exact_ids,
        ),
        query(
            "private_deleted_excluded",
            TurboVecRecallQueryKind::PrivateDeletedExcluded,
            privacy_ids.clone(),
            privacy_ids.clone(),
            privacy_ids,
        ),
        query(
            "duplicate_source_deduped",
            TurboVecRecallQueryKind::DuplicateSourceDeduped,
            duplicate_ids.clone(),
            duplicate_ids.clone(),
            duplicate_ids,
        ),
        query(
            "recall_miss_abstains",
            TurboVecRecallQueryKind::RecallMissAbstains,
            miss_ids.clone(),
            vec![miss_ids[0]],
            miss_ids,
        ),
        query(
            "empty_allowed_visible",
            TurboVecRecallQueryKind::EmptyAllowedVisible,
            vec![],
            vec![],
            vec![],
        ),
    ];
    queries[2].deduped_duplicate_source_count = 1;
    queries[3].fallback_on_miss_required = true;
    queries[3].fallback_on_miss_present = true;
    queries[3].declared_recall_at_k_micros = recall_at_k_micros(&queries[3]);
    queries[4].visible_answer_packet_on_empty = true;
    queries[4].declared_recall_at_k_micros = recall_at_k_micros(&queries[4]);

    Ok(vec![TurboVecRecallQualityExactBaselinePlan {
        plan_id: "turbovec_recall_quality_exact_baseline".to_string(),
        upstream_persistent_index_address: upstream,
        upstream_persistent_index_witness_ref:
            "artifact:turbovec_crash_safe_persistent_index:result".to_string(),
        status: TurboVecRecallQualityStatus::MetadataOnlyPlan,
        promotion_tier: TurboVecRecallQualityPromotionTier::T1L1Metadata,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        organs: vec![
            TurboVecIndexOrgan::Eidos,
            TurboVecIndexOrgan::AppColdStore,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            TurboVecIndexOrgan::AnswerPacket,
        ],
        policy: TurboVecRecallQualityPolicy::exact_baseline_gate(RECALL_FLOOR_MICROS),
        query_fixtures: queries,
        byte_ledger: TurboVecRecallQualityByteLedger::metadata_only(20_000, 12_000)?,
        proof_refs: proof_refs("turbovec_recall_quality_exact_baseline"),
        hidden_route_authority: false,
        product_capability_promoted: false,
        live_large_model_claimed: false,
        ssd_as_ram_claimed: false,
    }])
}

fn query(
    query_id: &str,
    kind: TurboVecRecallQueryKind,
    exact: Vec<u64>,
    approximate: Vec<u64>,
    allowed: Vec<u64>,
) -> TurboVecRecallQueryFixture {
    let mut query = TurboVecRecallQueryFixture {
        query_id: query_id.to_string(),
        query_kind: kind,
        query_uas_address: source(&format!("query:{query_id}")),
        top_k: 10,
        exact_baseline_external_ids: exact,
        approximate_result_external_ids: approximate,
        allowed_external_ids: allowed,
        deleted_external_ids: ids(&[&format!("deleted:{query_id}")]),
        private_external_ids: ids(&[&format!("private:{query_id}")]),
        unknown_external_ids: ids(&[&format!("unknown:{query_id}")]),
        deduped_duplicate_source_count: 0,
        exact_baseline_ref: format!("app_cold_store:exact_baseline:{query_id}"),
        exact_baseline_is_exhaustive: true,
        recall_floor_micros: RECALL_FLOOR_MICROS,
        declared_recall_at_k_micros: 1_000_000,
        fallback_on_miss_required: false,
        fallback_on_miss_present: false,
        visible_answer_packet_on_empty: false,
        route_mutation_allowed: false,
        latency_budget_micros: 10_000,
        measured_latency_micros: 0,
        planned_memory_bytes: 16_384,
        opened_index_bytes: 0,
        loaded_index_bytes: 0,
        runtime_bytes_loaded: 0,
        model_bytes_loaded: 0,
        provider_calls_made: 0,
        fallback_ref: format!("falsifier:F-TurboVec-RecallQualityExactBaseline:{query_id}"),
        rollback_ref: format!("rollback:turbovec_recall_quality:{query_id}"),
        run_event_log_ref: format!("run_event_log:turbovec_recall_quality:{query_id}"),
        answer_packet_ref: format!("answer_packet:turbovec_recall_quality:{query_id}"),
    };
    query.declared_recall_at_k_micros = recall_at_k_micros(&query);
    query
}

fn source(label: &str) -> UasAddress {
    UasAddress::new(
        UasKind::Other("eidos_app_cold_store_source".to_string()),
        label.as_bytes(),
        CREATED_AT_MS,
    )
}

fn ids(labels: &[&str]) -> Vec<u64> {
    labels
        .iter()
        .map(|label| stable_external_id_for_uas(&source(label)))
        .collect()
}

fn proof_refs(id: &str) -> TurboVecRecallQualityProofRefs {
    TurboVecRecallQualityProofRefs {
        falsifier_ref: format!("falsifier:F-TurboVec-RecallQualityExactBaseline:{id}"),
        rollback_ref: format!("rollback:turbovec_recall_quality:{id}"),
        run_event_log_ref: format!("run_event_log:turbovec_recall_quality:{id}"),
        answer_packet_ref: format!("answer_packet:turbovec_recall_quality:{id}"),
        compatibility_fence_ref: format!("compat:turbovec_recall_quality:{id}"),
    }
}

fn red_fixture_results(
    upstream: &UasAddress,
    plans: &[TurboVecRecallQualityExactBaselinePlan],
) -> Result<Vec<(String, bool)>, Box<dyn std::error::Error>> {
    let mut results = Vec::new();
    let mut push = |name: &str, mutate: fn(&mut Vec<TurboVecRecallQualityExactBaselinePlan>)| {
        let mut red = plans.to_vec();
        mutate(&mut red);
        let passed = build_set(upstream.clone(), red).is_err();
        results.push((name.to_string(), passed));
    };

    push("remove_exact_hit_query", |plans| {
        plans[0]
            .query_fixtures
            .retain(|query| query.query_kind != TurboVecRecallQueryKind::ExactHit);
    });
    push("remove_private_deleted_query", |plans| {
        plans[0]
            .query_fixtures
            .retain(|query| query.query_kind != TurboVecRecallQueryKind::PrivateDeletedExcluded);
    });
    push("remove_duplicate_dedup_query", |plans| {
        plans[0]
            .query_fixtures
            .retain(|query| query.query_kind != TurboVecRecallQueryKind::DuplicateSourceDeduped);
    });
    push("remove_recall_miss_query", |plans| {
        plans[0]
            .query_fixtures
            .retain(|query| query.query_kind != TurboVecRecallQueryKind::RecallMissAbstains);
    });
    push("remove_empty_visible_query", |plans| {
        plans[0]
            .query_fixtures
            .retain(|query| query.query_kind != TurboVecRecallQueryKind::EmptyAllowedVisible);
    });
    push("bad_exact_baseline_ref", |plans| {
        plans[0].query_fixtures[0].exact_baseline_ref = "manifest:approximate".to_string();
    });
    push("missing_exact_exhaustive_flag", |plans| {
        plans[0].query_fixtures[0].exact_baseline_is_exhaustive = false;
    });
    push("declared_recall_laundered", |plans| {
        plans[0].query_fixtures[0].declared_recall_at_k_micros = 42;
    });
    push("below_floor_without_fallback", |plans| {
        let query = &mut plans[0].query_fixtures[3];
        query.fallback_on_miss_present = false;
    });
    push("fallback_ref_missing", |plans| {
        plans[0].query_fixtures[3].fallback_ref = "missing:fallback".to_string();
    });
    push("policy_miss_fallback_missing", |plans| {
        plans[0].policy.miss_must_abstain_or_fallback = false;
    });
    push("result_not_in_allowlist", |plans| {
        let rogue = ids(&["rogue-result"])[0];
        plans[0].query_fixtures[0]
            .approximate_result_external_ids
            .push(rogue);
        plans[0].query_fixtures[0].declared_recall_at_k_micros =
            recall_at_k_micros(&plans[0].query_fixtures[0]);
    });
    push("policy_allowlist_missing", |plans| {
        plans[0].policy.result_subset_of_allowlist_required = false;
    });
    push("deleted_id_returned", |plans| {
        let id = plans[0].query_fixtures[1].deleted_external_ids[0];
        plans[0].query_fixtures[1].allowed_external_ids.push(id);
        plans[0].query_fixtures[1]
            .approximate_result_external_ids
            .push(id);
        plans[0].query_fixtures[1].declared_recall_at_k_micros =
            recall_at_k_micros(&plans[0].query_fixtures[1]);
    });
    push("private_id_returned", |plans| {
        let id = plans[0].query_fixtures[1].private_external_ids[0];
        plans[0].query_fixtures[1].allowed_external_ids.push(id);
        plans[0].query_fixtures[1]
            .approximate_result_external_ids
            .push(id);
        plans[0].query_fixtures[1].declared_recall_at_k_micros =
            recall_at_k_micros(&plans[0].query_fixtures[1]);
    });
    push("unknown_id_returned", |plans| {
        let id = plans[0].query_fixtures[1].unknown_external_ids[0];
        plans[0].query_fixtures[1].allowed_external_ids.push(id);
        plans[0].query_fixtures[1]
            .approximate_result_external_ids
            .push(id);
        plans[0].query_fixtures[1].declared_recall_at_k_micros =
            recall_at_k_micros(&plans[0].query_fixtures[1]);
    });
    push("baseline_contains_private_id", |plans| {
        let id = plans[0].query_fixtures[1].private_external_ids[0];
        plans[0].query_fixtures[1]
            .exact_baseline_external_ids
            .push(id);
        plans[0].query_fixtures[1].allowed_external_ids.push(id);
        plans[0].query_fixtures[1].declared_recall_at_k_micros =
            recall_at_k_micros(&plans[0].query_fixtures[1]);
    });
    push("policy_forbidden_exclusion_missing", |plans| {
        plans[0].policy.deleted_private_unknown_excluded = false;
    });
    push("duplicate_exact_baseline_id", |plans| {
        let id = plans[0].query_fixtures[0].exact_baseline_external_ids[0];
        plans[0].query_fixtures[0]
            .exact_baseline_external_ids
            .push(id);
        plans[0].query_fixtures[0].declared_recall_at_k_micros =
            recall_at_k_micros(&plans[0].query_fixtures[0]);
    });
    push("duplicate_result_id", |plans| {
        let id = plans[0].query_fixtures[0].approximate_result_external_ids[0];
        plans[0].query_fixtures[0]
            .approximate_result_external_ids
            .push(id);
    });
    push("duplicate_allowlist_id", |plans| {
        let id = plans[0].query_fixtures[0].allowed_external_ids[0];
        plans[0].query_fixtures[0].allowed_external_ids.push(id);
    });
    push("policy_duplicate_dedup_missing", |plans| {
        plans[0].policy.duplicate_source_dedup_required = false;
    });
    push("empty_result_no_answer_packet", |plans| {
        plans[0].query_fixtures[4].visible_answer_packet_on_empty = false;
        plans[0].query_fixtures[4].declared_recall_at_k_micros =
            recall_at_k_micros(&plans[0].query_fixtures[4]);
    });
    push("empty_result_returns_id", |plans| {
        let id = ids(&["bad-empty"])[0];
        plans[0].query_fixtures[4].allowed_external_ids.push(id);
        plans[0].query_fixtures[4]
            .approximate_result_external_ids
            .push(id);
        plans[0].query_fixtures[4].declared_recall_at_k_micros =
            recall_at_k_micros(&plans[0].query_fixtures[4]);
    });
    push("policy_empty_answer_packet_missing", |plans| {
        plans[0].policy.empty_result_answer_packet_required = false;
    });
    push("latency_budget_zero", |plans| {
        plans[0].query_fixtures[0].latency_budget_micros = 0;
    });
    push("planned_memory_zero", |plans| {
        plans[0].query_fixtures[0].planned_memory_bytes = 0;
    });
    push("policy_latency_missing", |plans| {
        plans[0].policy.latency_budget_declared = false;
    });
    push("policy_memory_missing", |plans| {
        plans[0].policy.memory_ledger_required = false;
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
    push("exact_baseline_bytes_opened", |plans| {
        plans[0].byte_ledger.exact_baseline_bytes_opened = 1;
    });
    push("index_bytes_opened", |plans| {
        plans[0].byte_ledger.index_bytes_opened = 1;
    });
    push("index_bytes_loaded", |plans| {
        plans[0].byte_ledger.index_bytes_loaded = 1;
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
    push("query_route_mutation", |plans| {
        plans[0].query_fixtures[0].route_mutation_allowed = true;
    });
    push("policy_eidos_route_authority", |plans| {
        plans[0].policy.eidos_score_can_select_route = true;
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
        plans[0].promotion_tier = TurboVecRecallQualityPromotionTier::T2L2Route;
    });
    push("live_large_model_claimed", |plans| {
        plans[0].live_large_model_claimed = true;
    });
    push("ssd_as_ram_claimed", |plans| {
        plans[0].ssd_as_ram_claimed = true;
    });
    push("plan_metadata_budget_exceeded", |plans| {
        plans[0].byte_ledger.metadata_bytes_read = 999_999;
    });

    let mut duplicate_plans = plans.to_vec();
    duplicate_plans.push(duplicate_plans[0].clone());
    results.push((
        "duplicate_plan_id".to_string(),
        build_set(upstream.clone(), duplicate_plans).is_err(),
    ));
    results.push((
        "set_product_promoted".to_string(),
        TurboVecRecallQualityExactBaselinePlanSet::from_plans(
            upstream.clone(),
            plans.to_vec(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRecallQualityStatus::MetadataOnlyPlan,
            TurboVecRecallQualityPromotionTier::T1L1Metadata,
            SET_METADATA_BYTES,
            SET_FIXTURE_BYTES,
            true,
        )
        .is_err(),
    ));
    results.push((
        "bad_upstream_cursor".to_string(),
        build_set(
            UasAddress::new(
                UasKind::Other("wrong_turbovec_cursor".to_string()),
                b"wrong",
                CREATED_AT_MS,
            ),
            plans.to_vec(),
        )
        .is_err(),
    ));
    results.push((
        "set_metadata_budget_exceeded".to_string(),
        TurboVecRecallQualityExactBaselinePlanSet::from_plans(
            upstream.clone(),
            plans.to_vec(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecRecallQualityStatus::MetadataOnlyPlan,
            TurboVecRecallQualityPromotionTier::T1L1Metadata,
            999_999,
            SET_FIXTURE_BYTES,
            false,
        )
        .is_err(),
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
