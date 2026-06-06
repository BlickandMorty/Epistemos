//! `falsify_turbovec_eidos_compressed_index_plan`
//!
//! Metadata-only witness for `F-TurboVec-Eidos-CompressedIndex-Plan`. It turns
//! TurboVec/QAT compression research into a strict Eidos/AppColdStore index
//! plan without importing code, building an index, loading runtime bytes,
//! choosing routes, or promoting product capability.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, TurboVecAllowlistPrivacyPolicy, TurboVecEidosCompressedIndexPlan,
    TurboVecEidosCompressedIndexPlanSet, TurboVecExternalIdPolicy, TurboVecIndexByteLedger,
    TurboVecIndexOrgan, TurboVecIndexPlanStatus, TurboVecIndexPromotionTier,
    TurboVecIndexProofRefs, TurboVecRebuildPolicy, UasAddress,
};

const FALSIFIER_ID: &str = "F-TurboVec-Eidos-CompressedIndex-Plan";
const FIXTURE_ID: &str = "turbovec_eidos_compressed_index_plan_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_eidos_compressed_index_plan.sh";
const RESULT: &str = "artifacts/falsifiers/turbovec_eidos_compressed_index_plan/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/compressed_model_source_card_intake/result.json";
const CREATED_AT_MS: u64 = 1_779_038_600_000;
const SET_METADATA_BYTES: u64 = 42_000;
const EXPECTED_DIMENSIONS: u64 = 1_536;

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
        "{FALSIFIER_ID}: overall_pass={} plan_count={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["accepted_fixture_count"].value,
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
    let upstream = upstream_intake_address()?;
    let plans = accepted_plans()?;
    let plan_set = build_set(upstream.clone(), plans.clone())?;
    let reversed = build_set(upstream, plans.iter().cloned().rev().collect())?;
    let metrics = plan_set.metrics();
    let red_results = red_fixture_results(&plan_set)?;
    let accepted_fixture_count = plans.len() as u64;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_compressed_source_card_intake_bound",
            plan_set
                .upstream_intake_witness_ref
                .contains("compressed_model_source_card_intake"),
        ),
        (
            "turbovec_eidos_cache_source_card_bound",
            plans.iter().all(|plan| {
                plan.upstream_turbovec_source_card_ref
                    == "compressed_model_source_card:turbovec_eidos_cache"
            }),
        ),
        (
            "accepted_fixture_pack_present",
            has_plan(&plans, "turbovec_eidos_cache_plan"),
        ),
        (
            "dimension_and_byte_math_correct",
            metrics.dimension_count == EXPECTED_DIMENSIONS
                && metrics.float32_vector_bytes == 6_144
                && metrics.q4_coordinate_payload_bytes == 768
                && metrics.q2_coordinate_payload_bytes == 384
                && red_pass(&red_results, "q4_byte_math_regression")
                && red_pass(&red_results, "q2_byte_math_regression"),
        ),
        (
            "uas_external_id_policy_bound",
            red_pass(&red_results, "sqlite_rowid_allowed")
                && red_pass(&red_results, "stable_u64_registry_missing")
                && red_pass(&red_results, "tombstone_generation_missing")
                && red_pass(&red_results, "collision_ledger_missing")
                && red_pass(&red_results, "external_id_rewrite_without_rebuild"),
        ),
        (
            "allowlist_before_rank_privacy_bound",
            red_pass(&red_results, "post_filtering_allowed")
                && red_pass(&red_results, "allowlist_before_rank_missing")
                && red_pass(&red_results, "empty_allowlist_packet_missing")
                && red_pass(&red_results, "unknown_allowlist_id_not_rejected")
                && red_pass(&red_results, "forbidden_id_scoring_allowed")
                && red_pass(&red_results, "private_vector_payload_scoring_allowed"),
        ),
        (
            "app_cold_store_rebuild_policy_bound",
            red_pass(&red_results, "app_cold_store_not_truth")
                && red_pass(&red_results, "compressed_index_claims_truth")
                && red_pass(&red_results, "exact_source_check_missing")
                && red_pass(&red_results, "corrupt_cache_rebuild_missing")
                && red_pass(&red_results, "atomic_manifest_missing"),
        ),
        (
            "proof_surfaces_required",
            red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "bad_answer_packet_prefix"),
        ),
        (
            "compressed_index_cache_not_truth",
            plans
                .iter()
                .all(|plan| plan.rebuild_policy.compressed_index_is_cache),
        ),
        (
            "hidden_route_authority_rejected",
            red_pass(&red_results, "eidos_score_selects_route")
                && red_pass(&red_results, "route_mutation_allowed")
                && red_pass(&red_results, "hidden_route_authority_allowed"),
        ),
        (
            "rowid_identity_rejected",
            red_pass(&red_results, "source_ref_rowid_identity"),
        ),
        (
            "runtime_and_index_bytes_zero",
            metrics.index_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.copied_product_file_count == 0
                && red_pass(&red_results, "index_bytes_loaded")
                && red_pass(&red_results, "runtime_bytes_loaded")
                && red_pass(&red_results, "model_bytes_loaded")
                && red_pass(&red_results, "provider_call_made")
                && red_pass(&red_results, "product_file_copied"),
        ),
        (
            "product_promotion_rejected",
            red_pass(&red_results, "mas_product_build")
                && red_pass(&red_results, "pro_live_status")
                && red_pass(&red_results, "promotion_tier_t2")
                && red_pass(&red_results, "live_recall_quality_claim")
                && red_pass(&red_results, "product_capability_claim")
                && red_pass(&red_results, "live_dense_70b_claim")
                && red_pass(&red_results, "ssd_as_ram_claim")
                && red_pass(&red_results, "hidden_cloud_fallback"),
        ),
        (
            "set_address_deterministic",
            plan_set.set_address == reversed.set_address,
        ),
        (
            "layer_separation_required",
            red_pass(&red_results, "set_missing_layer_separation"),
        ),
        (
            "runtime_deferred_required",
            red_pass(&red_results, "set_runtime_not_deferred")
                && red_pass(&red_results, "index_build_not_deferred"),
        ),
        (
            "metadata_budget_enforced",
            red_pass(&red_results, "metadata_budget_exceeded")
                && red_pass(&red_results, "ledger_metadata_budget_exceeded"),
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
        accepted_fixture_count,
        "==",
        1,
        "plans",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        34,
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
        "dimension_count",
        metrics.dimension_count,
        "==",
        EXPECTED_DIMENSIONS,
        "dimensions",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "float32_vector_bytes",
        metrics.float32_vector_bytes,
        "==",
        6_144,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "q4_coordinate_payload_bytes",
        metrics.q4_coordinate_payload_bytes,
        "==",
        768,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "q2_coordinate_payload_bytes",
        metrics.q2_coordinate_payload_bytes,
        "==",
        384,
        "bytes",
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
        "plan_set_address".to_string(),
        Measurement {
            value: serde_json::json!(plan_set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "plan_set_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("turbovec_eidos_compressed_index_plan:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "plan_set_address".to_string(),
        plan_set
            .set_address
            .to_string()
            .starts_with("turbovec_eidos_compressed_index_plan:"),
    );
    measurements.insert(
        "next_research_to_build_unit".to_string(),
        Measurement {
            value: serde_json::json!("turbovec_stable_external_id_registry_plan"),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_research_to_build_unit".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!("turbovec_stable_external_id_registry_plan"),
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
            "detail": "No TurboVec code imported, no compressed index built, no runtime/index/model bytes loaded, no hidden route authority, and no product capability promoted."
        })],
        notes: "Builds F-TurboVec-Eidos-CompressedIndex-Plan from the compressed source-card intake and current TurboVec research. Scope is T1/L1 metadata only: TurboVec is Eidos/AppColdStore rebuildable cache material with UAS truth identity, allowlist-before-rank privacy, corrected 1536-dimension byte math, rollback, RunEventLog, AnswerPacket, and no L2/L3/product promotion.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_intake_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream compressed model source-card intake has not passed".into());
    }
    if value
        .pointer("/pass_per_axis/compressed_index_card_present")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
        || value
            .pointer("/pass_per_axis/turbovec_eidos_cache_only")
            .and_then(serde_json::Value::as_bool)
            != Some(true)
    {
        return Err("upstream intake lacks TurboVec Eidos-cache axes".into());
    }
    let address = value
        .pointer("/measurements/intake_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing upstream intake_address measurement")?;
    Ok(UasAddress::from_str(address)?)
}

fn build_set(
    upstream_intake_address: UasAddress,
    plans: Vec<TurboVecEidosCompressedIndexPlan>,
) -> Result<TurboVecEidosCompressedIndexPlanSet, Box<dyn std::error::Error>> {
    Ok(TurboVecEidosCompressedIndexPlanSet::from_source_cards(
        upstream_intake_address,
        "artifact:compressed_model_source_card_intake:result",
        plans,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        SET_METADATA_BYTES,
        true,
        true,
        true,
        CREATED_AT_MS,
    )?)
}

fn accepted_plans() -> Result<Vec<TurboVecEidosCompressedIndexPlan>, Box<dyn std::error::Error>> {
    Ok(vec![TurboVecEidosCompressedIndexPlan {
        plan_id: "turbovec_eidos_cache_plan".to_string(),
        upstream_turbovec_source_card_ref: "compressed_model_source_card:turbovec_eidos_cache"
            .to_string(),
        source_locator: "https://github.com/RyanCodrai/turbovec".to_string(),
        source_revision_ref: "revision:main".to_string(),
        source_api_ref: "https://github.com/RyanCodrai/turbovec/blob/main/docs/api.md".to_string(),
        license_ref: "license:quarantine_adapter_or_clean_room".to_string(),
        organs: vec![
            TurboVecIndexOrgan::Eidos,
            TurboVecIndexOrgan::AppColdStore,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            TurboVecIndexOrgan::AnswerPacket,
        ],
        plan_status: TurboVecIndexPlanStatus::MetadataOnlyPlan,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: TurboVecIndexPromotionTier::T1L1Metadata,
        byte_ledger: TurboVecIndexByteLedger::metadata_only(
            EXPECTED_DIMENSIONS,
            32_768,
            18_000,
            4_096,
        )?,
        external_id_policy: TurboVecExternalIdPolicy::uas_truth(),
        privacy_policy: TurboVecAllowlistPrivacyPolicy::filter_before_rank(),
        rebuild_policy: TurboVecRebuildPolicy::rebuildable_cache(),
        proof_refs: proof_refs("turbovec_eidos_cache_plan"),
        l1_l2_l3_separated: true,
        runtime_deferred: true,
        index_build_deferred: true,
        eidos_score_can_select_route: false,
        route_mutation_allowed: false,
        hidden_route_authority_allowed: false,
        live_recall_quality_claimed: false,
        mas_readiness_claimed: false,
        product_capability_claimed: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
        hidden_cloud_fallback_allowed: false,
    }])
}

fn proof_refs(id: &str) -> TurboVecIndexProofRefs {
    TurboVecIndexProofRefs {
        falsifier_ref: format!("falsifier:F-TurboVec-Eidos-CompressedIndex-Plan:{id}"),
        rollback_ref: format!("rollback:turbovec_eidos_index:{id}"),
        run_event_log_ref: format!("run_event_log:turbovec_eidos_index:{id}"),
        answer_packet_ref: format!("answer_packet:turbovec_eidos_index:{id}"),
        compatibility_fence_ref: format!("compat:turbovec_eidos_index:{id}"),
    }
}

fn red_fixture_results(
    set: &TurboVecEidosCompressedIndexPlanSet,
) -> Result<Vec<(&'static str, bool)>, Box<dyn std::error::Error>> {
    let mut results = Vec::new();
    let base_plans = set.plans.clone();
    let upstream = set.upstream_intake_address.clone();

    let mut push_plan =
        |name: &'static str, mutate: fn(&mut Vec<TurboVecEidosCompressedIndexPlan>)| {
            let mut plans = base_plans.clone();
            mutate(&mut plans);
            results.push((name, build_set(upstream.clone(), plans).is_err()));
        };

    push_plan("duplicate_plan_id", |plans| {
        plans.push(plans[0].clone());
    });
    push_plan("bad_upstream_source_card_ref", |plans| {
        plans[0].upstream_turbovec_source_card_ref = "model_card:turbovec".to_string();
    });
    push_plan("source_ref_rowid_identity", |plans| {
        plans[0].upstream_turbovec_source_card_ref =
            "compressed_model_source_card:rowid:99".to_string();
    });
    push_plan("non_github_source", |plans| {
        plans[0].source_locator = "https://example.com/turbovec".to_string();
    });
    push_plan("bad_revision_prefix", |plans| {
        plans[0].source_revision_ref = "main".to_string();
    });
    push_plan("missing_license_ref", |plans| {
        plans[0].license_ref.clear();
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
    push_plan("q4_byte_math_regression", |plans| {
        plans[0].byte_ledger.q4_coordinate_payload_bytes = 384;
    });
    push_plan("q2_byte_math_regression", |plans| {
        plans[0].byte_ledger.q2_coordinate_payload_bytes = 192;
    });
    push_plan("dimension_misaligned", |plans| {
        plans[0].byte_ledger.dimension_count = 1_537;
    });
    push_plan("ledger_metadata_budget_exceeded", |plans| {
        plans[0].byte_ledger.metadata_bytes_read = 128 * 1024;
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
    push_plan("sqlite_rowid_allowed", |plans| {
        plans[0].external_id_policy.sqlite_rowid_allowed = true;
    });
    push_plan("stable_u64_registry_missing", |plans| {
        plans[0].external_id_policy.stable_u64_registry_required = false;
    });
    push_plan("tombstone_generation_missing", |plans| {
        plans[0].external_id_policy.tombstone_or_generation_required = false;
    });
    push_plan("collision_ledger_missing", |plans| {
        plans[0].external_id_policy.collision_ledger_required = false;
    });
    push_plan("external_id_rewrite_without_rebuild", |plans| {
        plans[0]
            .external_id_policy
            .external_id_rewrite_requires_rebuild = false;
    });
    push_plan("post_filtering_allowed", |plans| {
        plans[0].privacy_policy.post_filtering_allowed = true;
    });
    push_plan("allowlist_before_rank_missing", |plans| {
        plans[0].privacy_policy.allowlist_before_rank_required = false;
    });
    push_plan("empty_allowlist_packet_missing", |plans| {
        plans[0]
            .privacy_policy
            .empty_allowlist_answer_packet_required = false;
    });
    push_plan("unknown_allowlist_id_not_rejected", |plans| {
        plans[0].privacy_policy.unknown_allowlist_id_rejected = false;
    });
    push_plan("forbidden_id_scoring_allowed", |plans| {
        plans[0].privacy_policy.forbidden_id_scoring_allowed = true;
    });
    push_plan("private_vector_payload_scoring_allowed", |plans| {
        plans[0]
            .privacy_policy
            .private_vector_payload_scoring_allowed = true;
    });
    push_plan("app_cold_store_not_truth", |plans| {
        plans[0].rebuild_policy.app_cold_store_is_truth = false;
    });
    push_plan("compressed_index_claims_truth", |plans| {
        plans[0].rebuild_policy.compressed_index_is_cache = false;
    });
    push_plan("exact_source_check_missing", |plans| {
        plans[0].rebuild_policy.exact_source_check_required = false;
    });
    push_plan("corrupt_cache_rebuild_missing", |plans| {
        plans[0].rebuild_policy.corrupt_cache_rebuild_required = false;
    });
    push_plan("atomic_manifest_missing", |plans| {
        plans[0].rebuild_policy.atomic_manifest_required = false;
    });
    push_plan("rollback_missing", |plans| {
        plans[0].rebuild_policy.rollback_required = false;
    });
    push_plan("run_event_log_missing", |plans| {
        plans[0].rebuild_policy.run_event_log_required = false;
    });
    push_plan("answer_packet_missing", |plans| {
        plans[0].rebuild_policy.answer_packet_required = false;
    });
    push_plan("bad_answer_packet_prefix", |plans| {
        plans[0].proof_refs.answer_packet_ref = "packet:bad-prefix".to_string();
    });
    push_plan("index_build_not_deferred", |plans| {
        plans[0].index_build_deferred = false;
    });
    push_plan("eidos_score_selects_route", |plans| {
        plans[0].eidos_score_can_select_route = true;
    });
    push_plan("route_mutation_allowed", |plans| {
        plans[0].route_mutation_allowed = true;
    });
    push_plan("hidden_route_authority_allowed", |plans| {
        plans[0].hidden_route_authority_allowed = true;
    });
    push_plan("mas_product_build", |plans| {
        plans[0].product_build = ProductBuild::Mas;
    });
    push_plan("pro_live_status", |plans| {
        plans[0].pro_status = ProStatus::Live;
    });
    push_plan("promotion_tier_t2", |plans| {
        plans[0].promotion_tier = TurboVecIndexPromotionTier::T2L2Route;
    });
    push_plan("live_recall_quality_claim", |plans| {
        plans[0].live_recall_quality_claimed = true;
    });
    push_plan("product_capability_claim", |plans| {
        plans[0].product_capability_claimed = true;
    });
    push_plan("live_dense_70b_claim", |plans| {
        plans[0].live_dense_70b_claimed = true;
    });
    push_plan("ssd_as_ram_claim", |plans| {
        plans[0].ssd_as_ram_claimed = true;
    });
    push_plan("hidden_cloud_fallback", |plans| {
        plans[0].hidden_cloud_fallback_allowed = true;
    });

    let set_level = [
        (
            "set_missing_layer_separation",
            build_set_with_flags(
                upstream.clone(),
                base_plans.clone(),
                false,
                true,
                true,
                SET_METADATA_BYTES,
            )
            .is_err(),
        ),
        (
            "set_runtime_not_deferred",
            build_set_with_flags(
                upstream.clone(),
                base_plans.clone(),
                true,
                false,
                true,
                SET_METADATA_BYTES,
            )
            .is_err(),
        ),
        (
            "set_product_promotion_allowed",
            build_set_with_flags(
                upstream.clone(),
                base_plans.clone(),
                true,
                true,
                false,
                SET_METADATA_BYTES,
            )
            .is_err(),
        ),
        (
            "metadata_budget_exceeded",
            build_set_with_flags(upstream, base_plans, true, true, true, 600 * 1024).is_err(),
        ),
    ];
    results.extend(set_level);
    Ok(results)
}

fn build_set_with_flags(
    upstream_intake_address: UasAddress,
    plans: Vec<TurboVecEidosCompressedIndexPlan>,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
    metadata_bytes: u64,
) -> Result<TurboVecEidosCompressedIndexPlanSet, Box<dyn std::error::Error>> {
    Ok(TurboVecEidosCompressedIndexPlanSet::from_source_cards(
        upstream_intake_address,
        "artifact:compressed_model_source_card_intake:result",
        plans,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        metadata_bytes,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked,
        CREATED_AT_MS,
    )?)
}

fn has_plan(plans: &[TurboVecEidosCompressedIndexPlan], id: &str) -> bool {
    plans.iter().any(|plan| plan.plan_id == id)
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(candidate, _)| *candidate == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}
