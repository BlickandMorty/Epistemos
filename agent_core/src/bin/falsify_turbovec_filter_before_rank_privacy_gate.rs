//! `falsify_turbovec_filter_before_rank_privacy_gate`
//!
//! Metadata-only witness for `F-TurboVec-FilterBeforeRankPrivacyGate`. It
//! proves the next TurboVec/Eidos cache step must compile UAS-derived external
//! IDs through Scope/Sovereign allowlists before any adapter rank, score, or
//! result exposure can happen.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    stable_external_id_for_uas, ProStatus, ProductBuild, TurboVecAccessDecision,
    TurboVecAllowlistCompilation, TurboVecCandidateEvidence, TurboVecFilterBeforeRankByteLedger,
    TurboVecFilterBeforeRankPlan, TurboVecFilterBeforeRankPlanSet, TurboVecFilterBeforeRankPolicy,
    TurboVecFilterBeforeRankPromotionTier, TurboVecFilterBeforeRankProofRefs,
    TurboVecFilterBeforeRankScenario, TurboVecFilterBeforeRankStatus, TurboVecFilterFixtureKind,
    TurboVecIndexOrgan, UasAddress, UasKind, TURBOVEC_FILTER_BEFORE_RANK_PRIVACY_GATE_CURSOR,
    TURBOVEC_FILTER_BEFORE_RANK_PRIVACY_GATE_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-FilterBeforeRankPrivacyGate";
const FIXTURE_ID: &str = "turbovec_filter_before_rank_privacy_gate_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_filter_before_rank_privacy_gate.sh";
const RESULT: &str = "artifacts/falsifiers/turbovec_filter_before_rank_privacy_gate/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_uas_address_stable_external_ids/result.json";
const CREATED_AT_MS: u64 = 1_779_039_200_000;
const SET_METADATA_BYTES: u64 = 18_500;
const UNKNOWN_EXTERNAL_ID: u64 = u64::MAX - 7;

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
        "{FALSIFIER_ID}: overall_pass={} scenarios={} forbidden_scored={} exposed_forbidden={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["scenario_count"].value,
        artifact.measurements["forbidden_scored_count"].value,
        artifact.measurements["exposed_forbidden_count"].value,
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
    let upstream = upstream_registry_address()?;
    let plans = accepted_plans(upstream.clone())?;
    let set = build_set(upstream.clone(), plans.clone())?;
    let mut reversed_plans = plans.clone();
    reversed_plans[0].scenarios.reverse();
    for scenario in &mut reversed_plans[0].scenarios {
        scenario.candidates.reverse();
    }
    let reversed = build_set(upstream, reversed_plans)?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&set)?;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_stable_external_id_registry_bound",
            set.upstream_registry_witness_ref
                == "artifact:turbovec_uas_address_stable_external_ids:result",
        ),
        (
            "upstream_cursor_verified",
            set.upstream_registry_address
                .to_string()
                .starts_with("turbovec_stable_external_id_registry_plan:"),
        ),
        (
            "accepted_filter_fixture_present",
            plans
                .iter()
                .any(|plan| plan.plan_id == "turbovec_filter_before_rank_privacy_gate"),
        ),
        (
            "scenario_coverage_complete",
            metrics.scenario_count == 5
                && red_pass(&red_results, "remove_one_allowed_scenario")
                && red_pass(&red_results, "remove_all_denied_scenario")
                && red_pass(&red_results, "remove_duplicate_allowed_scenario")
                && red_pass(&red_results, "remove_unknown_id_scenario")
                && red_pass(&red_results, "remove_forbidden_plane_scenario"),
        ),
        (
            "allowlist_compiled_before_rank",
            red_pass(&red_results, "allowlist_not_compiled_before_rank"),
        ),
        (
            "post_filter_after_rank_rejected",
            red_pass(&red_results, "post_filter_after_rank_used")
                && red_pass(&red_results, "policy_allows_post_filter"),
        ),
        (
            "forbidden_id_scoring_rejected",
            metrics.forbidden_scored_count == 0
                && red_pass(&red_results, "forbidden_candidate_scored")
                && red_pass(&red_results, "policy_allows_forbidden_scoring"),
        ),
        (
            "private_vector_scoring_rejected",
            red_pass(&red_results, "private_candidate_scored")
                && red_pass(&red_results, "policy_allows_private_scoring"),
        ),
        (
            "unknown_external_id_rejected",
            red_pass(&red_results, "unknown_ids_not_rejected")
                && red_pass(&red_results, "missing_unknown_ids")
                && red_pass(&red_results, "unknown_id_compiled"),
        ),
        (
            "duplicate_allowlist_deduplicated",
            metrics.duplicate_allowlist_input_count == 1
                && red_pass(&red_results, "duplicate_count_wrong")
                && red_pass(&red_results, "compiled_duplicate_id"),
        ),
        (
            "empty_allowlist_answer_packet_emitted",
            metrics.empty_allowlist_packet_count >= 2
                && red_pass(&red_results, "empty_allowlist_no_packet")
                && red_pass(&red_results, "policy_missing_empty_packet"),
        ),
        (
            "exact_source_check_required",
            red_pass(&red_results, "exposed_missing_exact_source_check"),
        ),
        (
            "forbidden_hit_audit_required",
            red_pass(&red_results, "bad_forbidden_hit_audit_ref")
                && red_pass(&red_results, "policy_missing_forbidden_audit"),
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
            metrics.search_bytes_loaded == 0
                && metrics.index_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.copied_product_file_count == 0
                && red_pass(&red_results, "search_bytes_loaded")
                && red_pass(&red_results, "index_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "provider_call_made")
                && red_pass(&red_results, "product_file_copied"),
        ),
        (
            "hidden_route_authority_rejected",
            red_pass(&red_results, "hidden_route_authority_allowed")
                && red_pass(&red_results, "route_mutation_allowed")
                && red_pass(&red_results, "eidos_score_can_select_route")
                && red_pass(&red_results, "hidden_cloud_fallback"),
        ),
        (
            "product_promotion_rejected",
            red_pass(&red_results, "mas_product_build")
                && red_pass(&red_results, "pro_live_status")
                && red_pass(&red_results, "promotion_tier_t2")
                && red_pass(&red_results, "live_recall_quality_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim"),
        ),
        (
            "reversed_order_address_deterministic",
            set.set_address == reversed.set_address,
        ),
        (
            "stable_external_ids_required",
            red_pass(&red_results, "wrong_external_id")
                && red_pass(&red_results, "zero_external_id")
                && red_pass(&red_results, "allowlist_flag_mismatch"),
        ),
        (
            "scope_and_sovereign_gates_required",
            red_pass(&red_results, "scope_rex_missing")
                && red_pass(&red_results, "sovereign_gate_missing"),
        ),
        (
            "layer_separation_required",
            red_pass(&red_results, "set_missing_layer_separation"),
        ),
        (
            "metadata_budget_enforced",
            red_pass(&red_results, "set_metadata_budget_exceeded")
                && red_pass(&red_results, "ledger_metadata_budget_exceeded")
                && red_pass(&red_results, "manifest_metadata_budget_exceeded"),
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
        "accepted_fixture_count",
        plans.len() as u64,
        "==",
        1,
        "plans",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "scenario_count",
        metrics.scenario_count,
        "==",
        5,
        "scenarios",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "allowed_candidate_count",
        metrics.allowed_candidate_count,
        ">=",
        2,
        "candidates",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "forbidden_candidate_count",
        metrics.forbidden_candidate_count,
        ">=",
        2,
        "candidates",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "forbidden_scored_count",
        metrics.forbidden_scored_count,
        "==",
        0,
        "candidates",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "exposed_forbidden_count",
        metrics.exposed_forbidden_count,
        "==",
        0,
        "candidates",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        44,
        "fixtures",
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
        "metadata_bytes_read",
        metrics.metadata_bytes_read,
        "<=",
        512 * 1024,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "search_bytes_loaded",
        metrics.search_bytes_loaded,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "index_bytes_loaded",
        metrics.index_bytes_loaded,
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
        "model_bytes_loaded",
        metrics.model_bytes_loaded,
        "==",
        0,
        "bytes",
    );
    measurements.insert(
        "privacy_gate_address".to_string(),
        Measurement {
            value: serde_json::json!(set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "privacy_gate_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("turbovec_filter_before_rank_privacy_gate_plan:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "privacy_gate_address".to_string(),
        set.set_address
            .to_string()
            .starts_with("turbovec_filter_before_rank_privacy_gate_plan:"),
    );
    measurements.insert(
        "next_research_to_build_unit".to_string(),
        Measurement {
            value: serde_json::json!(TURBOVEC_FILTER_BEFORE_RANK_PRIVACY_GATE_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_research_to_build_unit".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(TURBOVEC_FILTER_BEFORE_RANK_PRIVACY_GATE_NEXT_CURSOR),
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
            "detail": "No TurboVec crate imported, no search/index/model/runtime bytes loaded, no recall or route quality claimed, and no L2/L3/product promotion."
        })],
        notes: "Builds F-TurboVec-FilterBeforeRankPrivacyGate from the stable external-ID registry. Scope is T1/L1 metadata only: Scope/Sovereign allowlists compile from UAS-derived external IDs before adapter scoring; private, forbidden, unknown, and empty-allowlist cases fail closed through forbidden-hit audit refs, rollback, RunEventLog, AnswerPacket, compatibility fence, and zero runtime/index/model/provider bytes.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_registry_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec stable-ID registry has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_FILTER_BEFORE_RANK_PRIVACY_GATE_CURSOR)
    {
        return Err("upstream TurboVec stable-ID registry does not point at privacy gate".into());
    }
    if value
        .pointer("/pass_per_axis/allowlist_ids_compile_from_uas_required")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec stable-ID registry lacks UAS allowlist axis".into());
    }
    let address = value
        .pointer("/measurements/registry_set_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing upstream registry_set_address measurement")?;
    Ok(UasAddress::from_str(address)?)
}

fn build_set(
    upstream_registry_address: UasAddress,
    plans: Vec<TurboVecFilterBeforeRankPlan>,
) -> Result<TurboVecFilterBeforeRankPlanSet, Box<dyn std::error::Error>> {
    Ok(TurboVecFilterBeforeRankPlanSet::from_plans(
        upstream_registry_address,
        "artifact:turbovec_uas_address_stable_external_ids:result",
        plans,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecFilterBeforeRankStatus::MetadataOnlyPlan,
        TurboVecFilterBeforeRankPromotionTier::T1L1Metadata,
        SET_METADATA_BYTES,
        true,
        true,
        true,
        CREATED_AT_MS,
    )?)
}

fn accepted_plans(
    upstream_registry_address: UasAddress,
) -> Result<Vec<TurboVecFilterBeforeRankPlan>, Box<dyn std::error::Error>> {
    let alpha = candidate(
        "alpha_note",
        TurboVecAccessDecision::Allowed,
        1,
        true,
        true,
        true,
    );
    let beta = candidate(
        "beta_private",
        TurboVecAccessDecision::PrivateScope,
        0,
        false,
        false,
        false,
    );
    let gamma = candidate(
        "gamma_forbidden",
        TurboVecAccessDecision::ForbiddenPlane,
        0,
        false,
        false,
        false,
    );
    let delta = candidate(
        "delta_code",
        TurboVecAccessDecision::Allowed,
        2,
        true,
        true,
        false,
    );
    let unknown = candidate(
        "unknown_probe",
        TurboVecAccessDecision::UnknownExternalId,
        0,
        false,
        false,
        false,
    );

    Ok(vec![TurboVecFilterBeforeRankPlan {
        plan_id: "turbovec_filter_before_rank_privacy_gate".to_string(),
        upstream_registry_address,
        upstream_registry_witness_ref: "artifact:turbovec_uas_address_stable_external_ids:result"
            .to_string(),
        source_api_ref: "https://github.com/RyanCodrai/turbovec/blob/main/docs/api.md".to_string(),
        organs: vec![
            TurboVecIndexOrgan::Eidos,
            TurboVecIndexOrgan::AppColdStore,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            TurboVecIndexOrgan::AnswerPacket,
        ],
        scenarios: vec![
            scenario(
                "one_allowed",
                TurboVecFilterFixtureKind::OneAllowed,
                vec![alpha.clone(), beta.clone(), gamma.clone()],
                vec![alpha.external_id],
                vec![alpha.external_id],
                vec![],
                0,
                false,
            ),
            scenario(
                "all_denied",
                TurboVecFilterFixtureKind::AllDenied,
                vec![beta.clone(), gamma.clone()],
                vec![],
                vec![],
                vec![],
                0,
                true,
            ),
            scenario(
                "duplicate_allowed_ids",
                TurboVecFilterFixtureKind::DuplicateAllowedIds,
                vec![delta.clone()],
                vec![delta.external_id, delta.external_id],
                vec![delta.external_id],
                vec![],
                1,
                false,
            ),
            scenario(
                "unknown_id_probe",
                TurboVecFilterFixtureKind::UnknownIdProbe,
                vec![unknown],
                vec![UNKNOWN_EXTERNAL_ID],
                vec![],
                vec![UNKNOWN_EXTERNAL_ID],
                0,
                false,
            ),
            scenario(
                "forbidden_plane_probe",
                TurboVecFilterFixtureKind::ForbiddenPlaneProbe,
                vec![gamma],
                vec![],
                vec![],
                vec![],
                0,
                true,
            ),
        ],
        policy: TurboVecFilterBeforeRankPolicy::fail_closed_privacy_gate(),
        byte_ledger: TurboVecFilterBeforeRankByteLedger::metadata_only(10_200, 4_096)?,
        proof_refs: proof_refs("turbovec_filter_before_rank_privacy_gate"),
        filter_status: TurboVecFilterBeforeRankStatus::MetadataOnlyPlan,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: TurboVecFilterBeforeRankPromotionTier::T1L1Metadata,
        l1_l2_l3_separated: true,
        runtime_deferred: true,
        index_build_deferred: true,
        product_promotion_blocked: true,
        hidden_route_authority_allowed: false,
        route_mutation_allowed: false,
        live_recall_quality_claimed: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
        hidden_cloud_fallback_allowed: false,
    }])
}

fn candidate(
    salt: &str,
    decision: TurboVecAccessDecision,
    rank: u64,
    in_allowlist: bool,
    scored: bool,
    exposed: bool,
) -> TurboVecCandidateEvidence {
    let uas_address = UasAddress::new(
        UasKind::Other("eidos_source_chunk".to_string()),
        format!("turbovec-filter:{salt}").as_bytes(),
        CREATED_AT_MS,
    );
    TurboVecCandidateEvidence {
        candidate_id: format!("candidate_{salt}"),
        external_id: stable_external_id_for_uas(&uas_address),
        uas_address,
        access_decision: decision,
        raw_score_rank: rank,
        compiled_allowlist_contains: in_allowlist,
        scored_by_adapter: scored,
        exposed_in_results: exposed,
        exact_source_check_passed: exposed,
    }
}

#[allow(clippy::too_many_arguments)]
fn scenario(
    id: &str,
    kind: TurboVecFilterFixtureKind,
    candidates: Vec<TurboVecCandidateEvidence>,
    raw: Vec<u64>,
    compiled: Vec<u64>,
    unknown: Vec<u64>,
    duplicate_count: u64,
    empty_packet: bool,
) -> TurboVecFilterBeforeRankScenario {
    TurboVecFilterBeforeRankScenario {
        scenario_id: id.to_string(),
        kind,
        candidates,
        allowlist: TurboVecAllowlistCompilation {
            raw_allowed_external_ids: raw,
            compiled_allowed_external_ids: compiled,
            unknown_external_ids: unknown,
            duplicate_input_count: duplicate_count,
            compiled_before_rank: true,
            post_filter_after_rank_used: false,
            unknown_ids_rejected: true,
            empty_allowlist_answer_packet_emitted: empty_packet,
        },
        forbidden_hit_audit_ref: format!("forbidden_hit_audit:turbovec_filter:{id}"),
        answer_packet_ref: format!("answer_packet:turbovec_filter:{id}"),
    }
}

fn proof_refs(id: &str) -> TurboVecFilterBeforeRankProofRefs {
    TurboVecFilterBeforeRankProofRefs {
        falsifier_ref: format!("falsifier:F-TurboVec-FilterBeforeRankPrivacyGate:{id}"),
        rollback_ref: format!("rollback:turbovec_filter:{id}"),
        run_event_log_ref: format!("run_event_log:turbovec_filter:{id}"),
        answer_packet_ref: format!("answer_packet:turbovec_filter:{id}"),
        compatibility_fence_ref: format!("compat:turbovec_filter:{id}"),
    }
}

fn red_fixture_results(
    set: &TurboVecFilterBeforeRankPlanSet,
) -> Result<Vec<(&'static str, bool)>, Box<dyn std::error::Error>> {
    let mut results = Vec::new();
    let base_plans = set.plans.clone();
    let upstream = set.upstream_registry_address.clone();

    let mut push_plan = |name: &'static str, mutate: fn(&mut Vec<TurboVecFilterBeforeRankPlan>)| {
        let mut plans = base_plans.clone();
        mutate(&mut plans);
        results.push((name, build_set(upstream.clone(), plans).is_err()));
    };

    push_plan("duplicate_plan_id", |plans| plans.push(plans[0].clone()));
    push_plan("bad_upstream_witness_ref", |plans| {
        plans[0].upstream_registry_witness_ref = "artifact:wrong:result".to_string();
    });
    push_plan("bad_source_api_ref", |plans| {
        plans[0].source_api_ref = "https://example.com/turbovec".to_string();
    });
    push_plan("missing_eidos_organ", |plans| {
        plans[0]
            .organs
            .retain(|organ| *organ != TurboVecIndexOrgan::Eidos);
    });
    push_plan("missing_app_cold_store_organ", |plans| {
        plans[0]
            .organs
            .retain(|organ| *organ != TurboVecIndexOrgan::AppColdStore);
    });
    push_plan("missing_semantic_working_set_organ", |plans| {
        plans[0]
            .organs
            .retain(|organ| *organ != TurboVecIndexOrgan::SemanticWorkingSetPlan);
    });
    push_plan("missing_answer_packet_organ", |plans| {
        plans[0]
            .organs
            .retain(|organ| *organ != TurboVecIndexOrgan::AnswerPacket);
    });
    push_plan("duplicate_scenario_id", |plans| {
        let duplicate = plans[0].scenarios[0].clone();
        plans[0].scenarios.push(duplicate);
    });
    push_plan("remove_one_allowed_scenario", |plans| {
        plans[0]
            .scenarios
            .retain(|scenario| scenario.kind != TurboVecFilterFixtureKind::OneAllowed);
    });
    push_plan("remove_all_denied_scenario", |plans| {
        plans[0]
            .scenarios
            .retain(|scenario| scenario.kind != TurboVecFilterFixtureKind::AllDenied);
    });
    push_plan("remove_duplicate_allowed_scenario", |plans| {
        plans[0]
            .scenarios
            .retain(|scenario| scenario.kind != TurboVecFilterFixtureKind::DuplicateAllowedIds);
    });
    push_plan("remove_unknown_id_scenario", |plans| {
        plans[0]
            .scenarios
            .retain(|scenario| scenario.kind != TurboVecFilterFixtureKind::UnknownIdProbe);
    });
    push_plan("remove_forbidden_plane_scenario", |plans| {
        plans[0]
            .scenarios
            .retain(|scenario| scenario.kind != TurboVecFilterFixtureKind::ForbiddenPlaneProbe);
    });
    push_plan("allowlist_not_compiled_before_rank", |plans| {
        plans[0].scenarios[0].allowlist.compiled_before_rank = false;
    });
    push_plan("post_filter_after_rank_used", |plans| {
        plans[0].scenarios[0].allowlist.post_filter_after_rank_used = true;
    });
    push_plan("unknown_ids_not_rejected", |plans| {
        plans[0].scenarios[3].allowlist.unknown_ids_rejected = false;
    });
    push_plan("empty_allowlist_no_packet", |plans| {
        plans[0].scenarios[1]
            .allowlist
            .empty_allowlist_answer_packet_emitted = false;
    });
    push_plan("raw_zero_id", |plans| {
        plans[0].scenarios[0].allowlist.raw_allowed_external_ids[0] = 0;
    });
    push_plan("compiled_zero_id", |plans| {
        plans[0].scenarios[0]
            .allowlist
            .compiled_allowed_external_ids[0] = 0;
    });
    push_plan("compiled_duplicate_id", |plans| {
        let id = plans[0].scenarios[2]
            .allowlist
            .compiled_allowed_external_ids[0];
        plans[0].scenarios[2]
            .allowlist
            .compiled_allowed_external_ids
            .push(id);
    });
    push_plan("duplicate_count_wrong", |plans| {
        plans[0].scenarios[2].allowlist.duplicate_input_count = 0;
    });
    push_plan("unknown_id_compiled", |plans| {
        plans[0].scenarios[3]
            .allowlist
            .compiled_allowed_external_ids
            .push(UNKNOWN_EXTERNAL_ID);
    });
    push_plan("missing_unknown_ids", |plans| {
        plans[0].scenarios[3].allowlist.unknown_external_ids.clear();
    });
    push_plan("forbidden_candidate_scored", |plans| {
        plans[0].scenarios[0].candidates[1].scored_by_adapter = true;
    });
    push_plan("forbidden_candidate_exposed", |plans| {
        plans[0].scenarios[0].candidates[1].exposed_in_results = true;
    });
    push_plan("private_candidate_scored", |plans| {
        plans[0].scenarios[1].candidates[0].scored_by_adapter = true;
    });
    push_plan("unknown_candidate_scored", |plans| {
        plans[0].scenarios[3].candidates[0].scored_by_adapter = true;
    });
    push_plan("forbidden_candidate_in_allowlist", |plans| {
        let id = plans[0].scenarios[0].candidates[1].external_id;
        plans[0].scenarios[0].candidates[1].compiled_allowlist_contains = true;
        plans[0].scenarios[0]
            .allowlist
            .compiled_allowed_external_ids
            .push(id);
    });
    push_plan("allowed_candidate_not_in_allowlist", |plans| {
        plans[0].scenarios[0]
            .allowlist
            .compiled_allowed_external_ids
            .clear();
    });
    push_plan("allowed_candidate_not_scored", |plans| {
        plans[0].scenarios[0].candidates[0].scored_by_adapter = false;
    });
    push_plan("exposed_missing_exact_source_check", |plans| {
        plans[0].scenarios[0].candidates[0].exact_source_check_passed = false;
    });
    push_plan("wrong_external_id", |plans| {
        plans[0].scenarios[0].candidates[0].external_id = plans[0].scenarios[0].candidates[0]
            .external_id
            .saturating_add(1);
    });
    push_plan("zero_external_id", |plans| {
        plans[0].scenarios[0].candidates[0].external_id = 0;
    });
    push_plan("allowlist_flag_mismatch", |plans| {
        plans[0].scenarios[0].candidates[0].compiled_allowlist_contains = false;
    });
    push_plan("bad_forbidden_hit_audit_ref", |plans| {
        plans[0].scenarios[0].forbidden_hit_audit_ref = "audit:missing".to_string();
    });
    push_plan("bad_answer_packet_ref", |plans| {
        plans[0].scenarios[0].answer_packet_ref = "packet:missing".to_string();
    });
    push_plan("scope_rex_missing", |plans| {
        plans[0].policy.scope_rex_gate_required = false;
    });
    push_plan("sovereign_gate_missing", |plans| {
        plans[0].policy.sovereign_gate_required = false;
    });
    push_plan("policy_allows_post_filter", |plans| {
        plans[0].policy.post_filter_after_rank_allowed = true;
    });
    push_plan("policy_allows_forbidden_scoring", |plans| {
        plans[0].policy.forbidden_id_scoring_allowed = true;
    });
    push_plan("policy_allows_private_scoring", |plans| {
        plans[0].policy.private_vector_scoring_allowed = true;
    });
    push_plan("policy_missing_empty_packet", |plans| {
        plans[0].policy.empty_allowlist_answer_packet_required = false;
    });
    push_plan("policy_missing_forbidden_audit", |plans| {
        plans[0].policy.forbidden_hit_audit_required = false;
    });
    push_plan("rollback_missing", |plans| {
        plans[0].policy.rollback_required = false;
    });
    push_plan("run_event_log_missing", |plans| {
        plans[0].policy.run_event_log_required = false;
    });
    push_plan("answer_packet_missing", |plans| {
        plans[0].policy.answer_packet_required = false;
    });
    push_plan("compatibility_fence_missing", |plans| {
        plans[0].policy.compatibility_fence_required = false;
    });
    push_plan("eidos_score_can_select_route", |plans| {
        plans[0].policy.eidos_score_can_select_route = true;
    });
    push_plan("search_bytes_loaded", |plans| {
        plans[0].byte_ledger.search_bytes_loaded = 1;
    });
    push_plan("index_bytes_loaded", |plans| {
        plans[0].byte_ledger.index_bytes_loaded = 1;
    });
    push_plan("runtime_bytes_loaded", |plans| {
        plans[0].byte_ledger.runtime_bytes_loaded = 1;
    });
    push_plan("model_bytes_loaded", |plans| {
        plans[0].byte_ledger.model_bytes_loaded = 1;
    });
    push_plan("provider_call_made", |plans| {
        plans[0].byte_ledger.provider_calls_made = 1;
    });
    push_plan("product_file_copied", |plans| {
        plans[0].byte_ledger.copied_product_file_count = 1;
    });
    push_plan("ledger_metadata_budget_exceeded", |plans| {
        plans[0].byte_ledger.metadata_bytes_read = 600 * 1024;
    });
    push_plan("manifest_metadata_budget_exceeded", |plans| {
        plans[0].byte_ledger.manifest_bytes_read = 200 * 1024;
    });
    push_plan("hidden_route_authority_allowed", |plans| {
        plans[0].hidden_route_authority_allowed = true;
    });
    push_plan("route_mutation_allowed", |plans| {
        plans[0].route_mutation_allowed = true;
    });
    push_plan("hidden_cloud_fallback", |plans| {
        plans[0].hidden_cloud_fallback_allowed = true;
    });
    push_plan("mas_product_build", |plans| {
        plans[0].product_build = ProductBuild::Mas;
    });
    push_plan("pro_live_status", |plans| {
        plans[0].pro_status = ProStatus::Live;
    });
    push_plan("promotion_tier_t2", |plans| {
        plans[0].promotion_tier = TurboVecFilterBeforeRankPromotionTier::T2L2Route;
    });
    push_plan("live_recall_quality_claim", |plans| {
        plans[0].live_recall_quality_claimed = true;
    });
    push_plan("live_dense_70b_claim", |plans| {
        plans[0].live_dense_70b_claimed = true;
    });
    push_plan("ssd_as_ram_claim", |plans| {
        plans[0].ssd_as_ram_claimed = true;
    });

    let set_mutations: [(
        &'static str,
        fn(
            UasAddress,
            Vec<TurboVecFilterBeforeRankPlan>,
        ) -> Result<TurboVecFilterBeforeRankPlanSet, Box<dyn std::error::Error>>,
    ); 2] = [
        ("set_missing_layer_separation", |upstream, plans| {
            Ok(TurboVecFilterBeforeRankPlanSet::from_plans(
                upstream,
                "artifact:turbovec_uas_address_stable_external_ids:result",
                plans,
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecFilterBeforeRankStatus::MetadataOnlyPlan,
                TurboVecFilterBeforeRankPromotionTier::T1L1Metadata,
                SET_METADATA_BYTES,
                false,
                true,
                true,
                CREATED_AT_MS,
            )?)
        }),
        ("set_metadata_budget_exceeded", |upstream, plans| {
            Ok(TurboVecFilterBeforeRankPlanSet::from_plans(
                upstream,
                "artifact:turbovec_uas_address_stable_external_ids:result",
                plans,
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                TurboVecFilterBeforeRankStatus::MetadataOnlyPlan,
                TurboVecFilterBeforeRankPromotionTier::T1L1Metadata,
                600 * 1024,
                true,
                true,
                true,
                CREATED_AT_MS,
            )?)
        }),
    ];
    for (name, build) in set_mutations {
        results.push((name, build(upstream.clone(), base_plans.clone()).is_err()));
    }

    Ok(results)
}

fn red_pass(results: &[(&'static str, bool)], name: &'static str) -> bool {
    results
        .iter()
        .any(|(candidate_name, pass)| *candidate_name == name && *pass)
}
