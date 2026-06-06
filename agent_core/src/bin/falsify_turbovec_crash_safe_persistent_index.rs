//! `falsify_turbovec_crash_safe_persistent_index`
//!
//! Metadata-only witness for `F-TurboVec-CrashSafePersistentIndex`. It proves
//! TurboVec/Eidos persistent cache files must be atomic, digest-bound,
//! rollback-capable, rebuildable from AppColdStore truth, and blocked from
//! product or hidden route authority before any real `.tvim` bytes exist.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    persistent_file_digest, ProStatus, ProductBuild, TurboVecCrashSafePersistentIndexPlan,
    TurboVecCrashSafePersistentIndexPlanSet, TurboVecCrashSafePersistentIndexPolicy,
    TurboVecIndexOrgan, TurboVecPersistenceFailureKind, TurboVecPersistenceFailureScenario,
    TurboVecPersistenceRecoveryDecision, TurboVecPersistentFileKind,
    TurboVecPersistentIndexByteLedger, TurboVecPersistentIndexFilePlan,
    TurboVecPersistentIndexPromotionTier, TurboVecPersistentIndexProofRefs,
    TurboVecPersistentIndexStatus, UasAddress, TURBOVEC_CRASH_SAFE_PERSISTENT_INDEX_CURSOR,
    TURBOVEC_CRASH_SAFE_PERSISTENT_INDEX_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-CrashSafePersistentIndex";
const FIXTURE_ID: &str = "turbovec_crash_safe_persistent_index_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_crash_safe_persistent_index.sh";
const RESULT: &str = "artifacts/falsifiers/turbovec_crash_safe_persistent_index/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_filter_before_rank_privacy_gate/result.json";
const CREATED_AT_MS: u64 = 1_779_039_300_000;
const SET_METADATA_BYTES: u64 = 19_000;

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
        "{FALSIFIER_ID}: overall_pass={} files={} scenarios={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["file_count"].value,
        artifact.measurements["scenario_count"].value,
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
    let upstream = upstream_privacy_gate_address()?;
    let plans = accepted_plans(upstream.clone())?;
    let set = build_set(upstream.clone(), plans.clone())?;
    let mut reversed_plans = plans.clone();
    reversed_plans[0].files.reverse();
    reversed_plans[0].failure_scenarios.reverse();
    let reversed = build_set(upstream, reversed_plans)?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&set)?;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_filter_before_rank_privacy_gate_bound",
            set.upstream_privacy_gate_witness_ref
                == "artifact:turbovec_filter_before_rank_privacy_gate:result",
        ),
        (
            "upstream_cursor_verified",
            set.upstream_privacy_gate_address
                .to_string()
                .starts_with("turbovec_filter_before_rank_privacy_gate_plan:"),
        ),
        (
            "accepted_persistent_fixture_present",
            plans
                .iter()
                .any(|plan| plan.plan_id == "turbovec_crash_safe_persistent_index"),
        ),
        (
            "file_coverage_complete",
            metrics.idmap_tvim_file_count == 1
                && metrics.manifest_file_count == 1
                && metrics.temp_file_count == 1
                && red_pass(&red_results, "remove_idmap_tvim_file")
                && red_pass(&red_results, "remove_manifest_file")
                && red_pass(&red_results, "remove_temp_file")
                && red_pass(&red_results, "remove_previous_manifest_pointer"),
        ),
        (
            "failure_scenario_coverage_complete",
            metrics.scenario_count == 9
                && red_pass(&red_results, "remove_partial_write_scenario")
                && red_pass(&red_results, "remove_corrupt_magic_scenario")
                && red_pass(&red_results, "remove_digest_mismatch_scenario")
                && red_pass(&red_results, "remove_missing_source_scenario")
                && red_pass(&red_results, "remove_stale_pointer_scenario"),
        ),
        (
            "atomic_temp_write_required",
            red_pass(&red_results, "temp_write_missing")
                && red_pass(&red_results, "policy_temp_write_missing"),
        ),
        (
            "fsync_and_atomic_rename_required",
            red_pass(&red_results, "fsync_file_missing")
                && red_pass(&red_results, "fsync_parent_missing")
                && red_pass(&red_results, "atomic_rename_missing")
                && red_pass(&red_results, "policy_atomic_rename_missing"),
        ),
        (
            "previous_manifest_retained",
            red_pass(&red_results, "previous_manifest_not_retained")
                && red_pass(&red_results, "policy_previous_manifest_missing"),
        ),
        (
            "manifest_digest_required",
            red_pass(&red_results, "manifest_digest_mismatch")
                && red_pass(&red_results, "policy_manifest_digest_missing"),
        ),
        (
            "magic_version_check_required",
            red_pass(&red_results, "format_version_zero")
                && red_pass(&red_results, "expected_magic_missing")
                && red_pass(&red_results, "policy_magic_version_missing"),
        ),
        (
            "duplicate_external_ids_rejected",
            metrics.duplicate_external_id_count == 0
                && red_pass(&red_results, "duplicate_external_id_in_file")
                && red_pass(&red_results, "duplicate_external_id_flagged")
                && red_pass(&red_results, "policy_duplicate_id_missing"),
        ),
        (
            "corrupt_cache_rebuild_required",
            red_pass(&red_results, "corrupt_magic_promoted")
                && red_pass(&red_results, "digest_mismatch_no_rebuild")
                && red_pass(&red_results, "version_mismatch_wrong_recovery")
                && red_pass(&red_results, "policy_corrupt_rebuild_missing"),
        ),
        (
            "partial_write_rollback_required",
            red_pass(&red_results, "partial_write_promoted")
                && red_pass(&red_results, "partial_write_old_manifest_unusable"),
        ),
        (
            "stale_pointer_rejected",
            red_pass(&red_results, "stale_pointer_promoted")
                && red_pass(&red_results, "policy_stale_pointer_missing"),
        ),
        (
            "permission_denial_refuses_promotion",
            red_pass(&red_results, "permission_denial_promoted")
                && red_pass(&red_results, "policy_permission_denial_missing"),
        ),
        (
            "app_cold_store_truth_required",
            red_pass(&red_results, "policy_app_cold_store_not_truth")
                && red_pass(&red_results, "missing_app_cold_store_ref")
                && red_pass(&red_results, "bad_app_cold_store_ref"),
        ),
        (
            "persistent_index_cache_not_truth",
            red_pass(&red_results, "policy_persistent_index_not_cache")
                && red_pass(&red_results, "persistent_index_claimed_as_truth"),
        ),
        (
            "path_content_addressed_required",
            red_pass(&red_results, "path_not_content_addressed")
                && red_pass(&red_results, "bad_final_path_prefix")
                && red_pass(&red_results, "bad_temp_path"),
        ),
        (
            "rollback_run_event_answer_packet_required",
            red_pass(&red_results, "rollback_missing")
                && red_pass(&red_results, "run_event_log_missing")
                && red_pass(&red_results, "answer_packet_missing")
                && red_pass(&red_results, "compatibility_fence_missing")
                && red_pass(&red_results, "scenario_bad_answer_packet_ref"),
        ),
        (
            "runtime_and_index_bytes_zero",
            metrics.index_bytes_opened == 0
                && metrics.index_bytes_written == 0
                && metrics.index_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && metrics.copied_product_file_count == 0
                && red_pass(&red_results, "file_opened_bytes")
                && red_pass(&red_results, "file_written_bytes")
                && red_pass(&red_results, "file_loaded_bytes")
                && red_pass(&red_results, "ledger_index_opened")
                && red_pass(&red_results, "ledger_index_written")
                && red_pass(&red_results, "ledger_index_loaded")
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
        "file_count",
        metrics.file_count,
        "==",
        4,
        "files",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "scenario_count",
        metrics.scenario_count,
        "==",
        9,
        "scenarios",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "planned_file_bytes",
        metrics.planned_file_bytes,
        ">",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "index_bytes_opened",
        metrics.index_bytes_opened,
        "==",
        0,
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "index_bytes_written",
        metrics.index_bytes_written,
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
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "red_fixture_count",
        red_results.len() as u64,
        ">=",
        60,
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
    measurements.insert(
        "persistent_index_plan_address".to_string(),
        Measurement {
            value: serde_json::json!(set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "persistent_index_plan_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("turbovec_crash_safe_persistent_index_plan:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "persistent_index_plan_address".to_string(),
        set.set_address
            .to_string()
            .starts_with("turbovec_crash_safe_persistent_index_plan:"),
    );
    measurements.insert(
        "next_research_to_build_unit".to_string(),
        Measurement {
            value: serde_json::json!(TURBOVEC_CRASH_SAFE_PERSISTENT_INDEX_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_research_to_build_unit".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(TURBOVEC_CRASH_SAFE_PERSISTENT_INDEX_NEXT_CURSOR),
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
            "detail": "No TurboVec crate imported, no persistent index files opened/written/loaded, no model/runtime bytes loaded, no recall-quality claim, and no L2/L3/product promotion."
        })],
        notes: "Builds F-TurboVec-CrashSafePersistentIndex from the filter-before-rank privacy gate. Scope is T1/L1 metadata only: models .tvim/manifest persistence as AppColdStore-rebuildable cache material with atomic temp writes, fsync policy, digest binding, rollback, corrupt-cache rebuild, RunEventLog, AnswerPacket, compatibility fence, and no product/runtime promotion.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_privacy_gate_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec privacy gate has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_CRASH_SAFE_PERSISTENT_INDEX_CURSOR)
    {
        return Err("upstream TurboVec privacy gate does not point at persistence plan".into());
    }
    if value
        .pointer("/pass_per_axis/post_filter_after_rank_rejected")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
        || value
            .pointer("/pass_per_axis/forbidden_id_scoring_rejected")
            .and_then(serde_json::Value::as_bool)
            != Some(true)
    {
        return Err("upstream TurboVec privacy gate lacks pre-rank privacy axes".into());
    }
    let address = value
        .pointer("/measurements/privacy_gate_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing upstream privacy_gate_address measurement")?;
    Ok(UasAddress::from_str(address)?)
}

fn build_set(
    upstream_privacy_gate_address: UasAddress,
    plans: Vec<TurboVecCrashSafePersistentIndexPlan>,
) -> Result<TurboVecCrashSafePersistentIndexPlanSet, Box<dyn std::error::Error>> {
    Ok(TurboVecCrashSafePersistentIndexPlanSet::from_plans(
        upstream_privacy_gate_address,
        "artifact:turbovec_filter_before_rank_privacy_gate:result",
        plans,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecPersistentIndexStatus::MetadataOnlyPlan,
        TurboVecPersistentIndexPromotionTier::T1L1Metadata,
        SET_METADATA_BYTES,
        true,
        true,
        true,
        CREATED_AT_MS,
    )?)
}

fn accepted_plans(
    upstream_privacy_gate_address: UasAddress,
) -> Result<Vec<TurboVecCrashSafePersistentIndexPlan>, Box<dyn std::error::Error>> {
    Ok(vec![TurboVecCrashSafePersistentIndexPlan {
        plan_id: "turbovec_crash_safe_persistent_index".to_string(),
        upstream_privacy_gate_address,
        upstream_privacy_gate_witness_ref:
            "artifact:turbovec_filter_before_rank_privacy_gate:result".to_string(),
        source_api_ref: "https://github.com/RyanCodrai/turbovec/blob/main/docs/api.md".to_string(),
        organs: vec![
            TurboVecIndexOrgan::Eidos,
            TurboVecIndexOrgan::AppColdStore,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            TurboVecIndexOrgan::AnswerPacket,
        ],
        files: accepted_files(),
        failure_scenarios: accepted_scenarios(),
        policy: TurboVecCrashSafePersistentIndexPolicy::fail_closed_cache_persistence(),
        byte_ledger: TurboVecPersistentIndexByteLedger::metadata_only(11_000, 4_500)?,
        proof_refs: proof_refs("turbovec_crash_safe_persistent_index"),
        index_status: TurboVecPersistentIndexStatus::MetadataOnlyPlan,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: TurboVecPersistentIndexPromotionTier::T1L1Metadata,
        l1_l2_l3_separated: true,
        runtime_deferred: true,
        index_build_deferred: true,
        product_promotion_blocked: true,
        hidden_route_authority_allowed: false,
        route_mutation_allowed: false,
        live_recall_quality_claimed: false,
        persistent_index_claimed_as_truth: false,
        live_dense_70b_claimed: false,
        ssd_as_ram_claimed: false,
        hidden_cloud_fallback_allowed: false,
    }])
}

fn accepted_files() -> Vec<TurboVecPersistentIndexFilePlan> {
    vec![
        file(
            "idmap_tvim",
            TurboVecPersistentFileKind::IdMapTvim,
            "TVIM",
            1,
            12_288,
            vec![11, 22, 33],
        ),
        file(
            "manifest_json",
            TurboVecPersistentFileKind::ManifestJson,
            "JSON",
            1,
            2_048,
            vec![11, 22, 33],
        ),
        file(
            "temp_file",
            TurboVecPersistentFileKind::TempFile,
            "TVIM",
            1,
            12_288,
            vec![11, 22, 33],
        ),
        file(
            "previous_manifest",
            TurboVecPersistentFileKind::PreviousManifestPointer,
            "JSON",
            1,
            512,
            vec![11],
        ),
    ]
}

fn file(
    id: &str,
    kind: TurboVecPersistentFileKind,
    magic: &str,
    version: u32,
    bytes: u64,
    ids: Vec<u64>,
) -> TurboVecPersistentIndexFilePlan {
    let digest = persistent_file_digest(id, kind, magic, version, bytes, &ids);
    TurboVecPersistentIndexFilePlan {
        file_id: id.to_string(),
        file_kind: kind,
        logical_path: format!("app_cold_store/turbovec/eidos/{id}.logical"),
        temp_path: format!("app_cold_store/turbovec/eidos/{id}.tmp"),
        final_path: format!(
            "app_cold_store/turbovec/eidos/sha256-{}/{}",
            digest.trim_start_matches("sha256:"),
            if matches!(
                kind,
                TurboVecPersistentFileKind::IdMapTvim | TurboVecPersistentFileKind::TempFile
            ) {
                "index.tvim"
            } else {
                "manifest.json"
            }
        ),
        expected_magic: magic.to_string(),
        format_version: version,
        manifest_digest: digest,
        planned_file_bytes: bytes,
        opened_file_bytes: 0,
        written_file_bytes: 0,
        loaded_index_bytes: 0,
        source_card_ref: "compressed_model_source_card:turbovec_eidos_cache".to_string(),
        app_cold_store_ref: format!("app_cold_store:turbovec:eidos:{id}"),
        stable_external_ids: ids,
        duplicate_external_id_present: false,
        path_is_content_addressed: true,
        temp_write_required: true,
        fsync_file_required: true,
        fsync_parent_dir_required: true,
        atomic_rename_required: true,
        previous_manifest_retained: true,
    }
}

fn accepted_scenarios() -> Vec<TurboVecPersistenceFailureScenario> {
    use TurboVecPersistenceFailureKind as F;
    use TurboVecPersistenceRecoveryDecision as R;
    vec![
        scenario(
            "clean_commit",
            F::CleanCommit,
            R::AcceptNewManifest,
            false,
            true,
            false,
            true,
        ),
        scenario(
            "partial_write",
            F::PartialWrite,
            R::RollBackToPreviousManifest,
            true,
            true,
            false,
            false,
        ),
        scenario(
            "corrupt_magic",
            F::CorruptMagic,
            R::RebuildFromAppColdStore,
            true,
            true,
            true,
            false,
        ),
        scenario(
            "version_mismatch",
            F::VersionMismatch,
            R::RebuildFromAppColdStore,
            true,
            true,
            true,
            false,
        ),
        scenario(
            "digest_mismatch",
            F::DigestMismatch,
            R::RebuildFromAppColdStore,
            true,
            true,
            true,
            false,
        ),
        scenario(
            "duplicate_external_id",
            F::DuplicateExternalId,
            R::RebuildFromAppColdStore,
            true,
            true,
            true,
            false,
        ),
        scenario(
            "missing_source",
            F::MissingAppColdStoreSource,
            R::RefuseAndEmitAnswerPacket,
            false,
            true,
            false,
            false,
        ),
        scenario(
            "permission_denied",
            F::PermissionDenied,
            R::RollBackToPreviousManifest,
            true,
            true,
            false,
            false,
        ),
        scenario(
            "stale_pointer",
            F::StaleManifestPointer,
            R::RollBackToPreviousManifest,
            true,
            true,
            false,
            false,
        ),
    ]
}

fn scenario(
    id: &str,
    failure: TurboVecPersistenceFailureKind,
    recovery: TurboVecPersistenceRecoveryDecision,
    corrupt: bool,
    old_usable: bool,
    rebuild: bool,
    promoted: bool,
) -> TurboVecPersistenceFailureScenario {
    TurboVecPersistenceFailureScenario {
        scenario_id: id.to_string(),
        failure_kind: failure,
        recovery_decision: recovery,
        corrupt_index_detected: corrupt,
        old_manifest_still_usable: old_usable,
        rebuild_from_app_cold_store: rebuild,
        new_manifest_promoted: promoted,
        quarantine_ref: format!("quarantine:turbovec:{id}"),
        rollback_ref: format!("rollback:turbovec_persist:{id}"),
        run_event_log_ref: format!("run_event_log:turbovec_persist:{id}"),
        answer_packet_ref: format!("answer_packet:turbovec_persist:{id}"),
    }
}

fn proof_refs(id: &str) -> TurboVecPersistentIndexProofRefs {
    TurboVecPersistentIndexProofRefs {
        falsifier_ref: format!("falsifier:F-TurboVec-CrashSafePersistentIndex:{id}"),
        rollback_ref: format!("rollback:turbovec_persist:{id}"),
        run_event_log_ref: format!("run_event_log:turbovec_persist:{id}"),
        answer_packet_ref: format!("answer_packet:turbovec_persist:{id}"),
        compatibility_fence_ref: format!("compat:turbovec_persist:{id}"),
    }
}

fn red_fixture_results(
    set: &TurboVecCrashSafePersistentIndexPlanSet,
) -> Result<Vec<(&'static str, bool)>, Box<dyn std::error::Error>> {
    let mut results = Vec::new();
    let base_plans = set.plans.clone();
    let upstream = set.upstream_privacy_gate_address.clone();

    let mut push_plan =
        |name: &'static str, mutate: fn(&mut Vec<TurboVecCrashSafePersistentIndexPlan>)| {
            let mut plans = base_plans.clone();
            mutate(&mut plans);
            results.push((name, build_set(upstream.clone(), plans).is_err()));
        };

    push_plan("duplicate_plan_id", |plans| plans.push(plans[0].clone()));
    push_plan("bad_upstream_witness_ref", |plans| {
        plans[0].upstream_privacy_gate_witness_ref = "artifact:wrong:result".to_string();
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
    push_plan("duplicate_file_id", |plans| {
        let duplicate = plans[0].files[0].clone();
        plans[0].files.push(duplicate);
    });
    push_plan("remove_idmap_tvim_file", |plans| {
        plans[0]
            .files
            .retain(|file| file.file_kind != TurboVecPersistentFileKind::IdMapTvim);
    });
    push_plan("remove_manifest_file", |plans| {
        plans[0]
            .files
            .retain(|file| file.file_kind != TurboVecPersistentFileKind::ManifestJson);
    });
    push_plan("remove_temp_file", |plans| {
        plans[0]
            .files
            .retain(|file| file.file_kind != TurboVecPersistentFileKind::TempFile);
    });
    push_plan("remove_previous_manifest_pointer", |plans| {
        plans[0]
            .files
            .retain(|file| file.file_kind != TurboVecPersistentFileKind::PreviousManifestPointer);
    });
    push_plan("temp_write_missing", |plans| {
        plans[0].files[0].temp_write_required = false;
    });
    push_plan("fsync_file_missing", |plans| {
        plans[0].files[0].fsync_file_required = false;
    });
    push_plan("fsync_parent_missing", |plans| {
        plans[0].files[0].fsync_parent_dir_required = false;
    });
    push_plan("atomic_rename_missing", |plans| {
        plans[0].files[0].atomic_rename_required = false;
    });
    push_plan("previous_manifest_not_retained", |plans| {
        plans[0].files[0].previous_manifest_retained = false;
    });
    push_plan("manifest_digest_mismatch", |plans| {
        plans[0].files[0].manifest_digest = "sha256:bad".to_string();
    });
    push_plan("format_version_zero", |plans| {
        plans[0].files[0].format_version = 0;
    });
    push_plan("expected_magic_missing", |plans| {
        plans[0].files[0].expected_magic.clear();
    });
    push_plan("planned_file_bytes_zero", |plans| {
        plans[0].files[0].planned_file_bytes = 0;
    });
    push_plan("duplicate_external_id_in_file", |plans| {
        let id = plans[0].files[0].stable_external_ids[0];
        plans[0].files[0].stable_external_ids.push(id);
    });
    push_plan("zero_external_id_in_file", |plans| {
        plans[0].files[0].stable_external_ids[0] = 0;
    });
    push_plan("duplicate_external_id_flagged", |plans| {
        plans[0].files[0].duplicate_external_id_present = true;
    });
    push_plan("path_not_content_addressed", |plans| {
        plans[0].files[0].path_is_content_addressed = false;
    });
    push_plan("bad_final_path_prefix", |plans| {
        plans[0].files[0].final_path = "/tmp/index.tvim".to_string();
    });
    push_plan("bad_temp_path", |plans| {
        plans[0].files[0].temp_path = "app_cold_store/turbovec/eidos/index.next".to_string();
    });
    push_plan("missing_app_cold_store_ref", |plans| {
        plans[0].files[0].app_cold_store_ref.clear();
    });
    push_plan("bad_app_cold_store_ref", |plans| {
        plans[0].files[0].app_cold_store_ref = "sqlite_rowid:7".to_string();
    });
    push_plan("bad_source_card_ref", |plans| {
        plans[0].files[0].source_card_ref = "source_card:bad".to_string();
    });
    push_plan("file_opened_bytes", |plans| {
        plans[0].files[0].opened_file_bytes = 1;
    });
    push_plan("file_written_bytes", |plans| {
        plans[0].files[0].written_file_bytes = 1;
    });
    push_plan("file_loaded_bytes", |plans| {
        plans[0].files[0].loaded_index_bytes = 1;
    });
    push_plan("duplicate_scenario_id", |plans| {
        let duplicate = plans[0].failure_scenarios[0].clone();
        plans[0].failure_scenarios.push(duplicate);
    });
    push_plan("remove_partial_write_scenario", |plans| {
        plans[0].failure_scenarios.retain(|scenario| {
            scenario.failure_kind != TurboVecPersistenceFailureKind::PartialWrite
        });
    });
    push_plan("remove_corrupt_magic_scenario", |plans| {
        plans[0].failure_scenarios.retain(|scenario| {
            scenario.failure_kind != TurboVecPersistenceFailureKind::CorruptMagic
        });
    });
    push_plan("remove_digest_mismatch_scenario", |plans| {
        plans[0].failure_scenarios.retain(|scenario| {
            scenario.failure_kind != TurboVecPersistenceFailureKind::DigestMismatch
        });
    });
    push_plan("remove_missing_source_scenario", |plans| {
        plans[0].failure_scenarios.retain(|scenario| {
            scenario.failure_kind != TurboVecPersistenceFailureKind::MissingAppColdStoreSource
        });
    });
    push_plan("remove_stale_pointer_scenario", |plans| {
        plans[0].failure_scenarios.retain(|scenario| {
            scenario.failure_kind != TurboVecPersistenceFailureKind::StaleManifestPointer
        });
    });
    push_plan("partial_write_promoted", |plans| {
        plans[0].failure_scenarios[1].new_manifest_promoted = true;
    });
    push_plan("partial_write_old_manifest_unusable", |plans| {
        plans[0].failure_scenarios[1].old_manifest_still_usable = false;
    });
    push_plan("corrupt_magic_promoted", |plans| {
        plans[0].failure_scenarios[2].recovery_decision =
            TurboVecPersistenceRecoveryDecision::AcceptNewManifest;
    });
    push_plan("version_mismatch_wrong_recovery", |plans| {
        plans[0].failure_scenarios[3].recovery_decision =
            TurboVecPersistenceRecoveryDecision::RollBackToPreviousManifest;
    });
    push_plan("digest_mismatch_no_rebuild", |plans| {
        plans[0].failure_scenarios[4].rebuild_from_app_cold_store = false;
    });
    push_plan("missing_source_rebuilds", |plans| {
        plans[0].failure_scenarios[6].recovery_decision =
            TurboVecPersistenceRecoveryDecision::RebuildFromAppColdStore;
        plans[0].failure_scenarios[6].rebuild_from_app_cold_store = true;
    });
    push_plan("permission_denial_promoted", |plans| {
        plans[0].failure_scenarios[7].new_manifest_promoted = true;
    });
    push_plan("stale_pointer_promoted", |plans| {
        plans[0].failure_scenarios[8].recovery_decision =
            TurboVecPersistenceRecoveryDecision::AcceptNewManifest;
        plans[0].failure_scenarios[8].new_manifest_promoted = true;
    });
    push_plan("scenario_bad_answer_packet_ref", |plans| {
        plans[0].failure_scenarios[0].answer_packet_ref = "packet:bad".to_string();
    });
    push_plan("scenario_bad_run_event_log_ref", |plans| {
        plans[0].failure_scenarios[0].run_event_log_ref = "log:bad".to_string();
    });
    push_plan("scenario_bad_quarantine_ref", |plans| {
        plans[0].failure_scenarios[0].quarantine_ref = "quarantine:bad".to_string();
    });
    push_plan("policy_app_cold_store_not_truth", |plans| {
        plans[0].policy.app_cold_store_is_truth = false;
    });
    push_plan("policy_persistent_index_not_cache", |plans| {
        plans[0].policy.persistent_index_is_cache = false;
    });
    push_plan("policy_privacy_gate_missing", |plans| {
        plans[0].policy.privacy_gate_required = false;
    });
    push_plan("policy_stable_ids_missing", |plans| {
        plans[0].policy.stable_external_ids_required = false;
    });
    push_plan("policy_manifest_digest_missing", |plans| {
        plans[0].policy.manifest_digest_required = false;
    });
    push_plan("policy_magic_version_missing", |plans| {
        plans[0].policy.magic_version_check_required = false;
    });
    push_plan("policy_duplicate_id_missing", |plans| {
        plans[0].policy.duplicate_external_ids_rejected = false;
    });
    push_plan("policy_temp_write_missing", |plans| {
        plans[0].policy.temp_write_required = false;
    });
    push_plan("policy_atomic_rename_missing", |plans| {
        plans[0].policy.atomic_rename_required = false;
    });
    push_plan("policy_previous_manifest_missing", |plans| {
        plans[0].policy.previous_manifest_retained = false;
    });
    push_plan("policy_corrupt_rebuild_missing", |plans| {
        plans[0].policy.corrupt_index_rebuild_required = false;
    });
    push_plan("policy_stale_pointer_missing", |plans| {
        plans[0].policy.stale_pointer_rejected = false;
    });
    push_plan("policy_permission_denial_missing", |plans| {
        plans[0].policy.permission_denial_refuses_promotion = false;
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
    push_plan("ledger_index_opened", |plans| {
        plans[0].byte_ledger.index_bytes_opened = 1;
    });
    push_plan("ledger_index_written", |plans| {
        plans[0].byte_ledger.index_bytes_written = 1;
    });
    push_plan("ledger_index_loaded", |plans| {
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
    push_plan("persistent_index_claimed_as_truth", |plans| {
        plans[0].persistent_index_claimed_as_truth = true;
    });
    push_plan("mas_product_build", |plans| {
        plans[0].product_build = ProductBuild::Mas;
    });
    push_plan("pro_live_status", |plans| {
        plans[0].pro_status = ProStatus::Live;
    });
    push_plan("promotion_tier_t2", |plans| {
        plans[0].promotion_tier = TurboVecPersistentIndexPromotionTier::T2L2Route;
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

    results.push((
        "set_missing_layer_separation",
        TurboVecCrashSafePersistentIndexPlanSet::from_plans(
            upstream.clone(),
            "artifact:turbovec_filter_before_rank_privacy_gate:result",
            base_plans.clone(),
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecPersistentIndexStatus::MetadataOnlyPlan,
            TurboVecPersistentIndexPromotionTier::T1L1Metadata,
            SET_METADATA_BYTES,
            false,
            true,
            true,
            CREATED_AT_MS,
        )
        .is_err(),
    ));
    results.push((
        "set_metadata_budget_exceeded",
        TurboVecCrashSafePersistentIndexPlanSet::from_plans(
            upstream,
            "artifact:turbovec_filter_before_rank_privacy_gate:result",
            base_plans,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            TurboVecPersistentIndexStatus::MetadataOnlyPlan,
            TurboVecPersistentIndexPromotionTier::T1L1Metadata,
            600 * 1024,
            true,
            true,
            true,
            CREATED_AT_MS,
        )
        .is_err(),
    ));

    Ok(results)
}

fn red_pass(results: &[(&'static str, bool)], name: &'static str) -> bool {
    results
        .iter()
        .any(|(candidate_name, pass)| *candidate_name == name && *pass)
}
