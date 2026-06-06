//! `falsify_turbovec_uas_address_stable_external_ids`
//!
//! Metadata-only witness for `F-TurboVec-UASAddressStableExternalIds`. It
//! turns the TurboVec Eidos compressed-index plan into a fail-closed UAS-to-u64
//! external ID registry plan before any TurboVec index bytes, recall claims,
//! RuntimeRouter routes, or product surfaces are allowed to cite it.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::str::FromStr;

use agent_core::falsifier_artifacts::{
    add_bool_axis, add_u64_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    stable_external_id_for_uas, ProStatus, ProductBuild, TurboVecIndexOrgan,
    TurboVecStableExternalIdByteLedger, TurboVecStableExternalIdCollisionLedgerEntry,
    TurboVecStableExternalIdCollisionResolution, TurboVecStableExternalIdEntry,
    TurboVecStableExternalIdLifecycle, TurboVecStableExternalIdPromotionTier,
    TurboVecStableExternalIdProofRefs, TurboVecStableExternalIdRegistryPlan,
    TurboVecStableExternalIdRegistryPlanSet, TurboVecStableExternalIdRegistryPolicy,
    TurboVecStableExternalIdRegistryStatus, TurboVecStableExternalIdSource, UasAddress, UasKind,
    TURBOVEC_STABLE_EXTERNAL_ID_REGISTRY_PLAN_CURSOR,
    TURBOVEC_STABLE_EXTERNAL_ID_REGISTRY_PLAN_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-TurboVec-UASAddressStableExternalIds";
const FIXTURE_ID: &str = "turbovec_uas_address_stable_external_ids_v1";
const COMMAND: &str = "Tools/falsifiers/f_turbovec_uas_address_stable_external_ids.sh";
const RESULT: &str = "artifacts/falsifiers/turbovec_uas_address_stable_external_ids/result.json";
const UPSTREAM_RESULT: &str =
    "artifacts/falsifiers/turbovec_eidos_compressed_index_plan/result.json";
const CREATED_AT_MS: u64 = 1_779_039_100_000;
const SET_METADATA_BYTES: u64 = 18_000;

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
        "{FALSIFIER_ID}: overall_pass={} active_entries={} tombstones={} red_fixture_rejection_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["active_entry_count"].value,
        artifact.measurements["tombstoned_entry_count"].value,
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
    let upstream = upstream_index_plan_address()?;
    let plans = accepted_plans(upstream.clone())?;
    let set = build_set(upstream.clone(), plans.clone())?;
    let mut reversed_plans = plans.clone();
    reversed_plans[0].entries.reverse();
    reversed_plans[0].collision_ledger.reverse();
    let reversed = build_set(upstream, reversed_plans)?;
    let metrics = set.metrics();
    let red_results = red_fixture_results(&set)?;
    let red_fixture_rejection_count = red_results.iter().filter(|(_, pass)| *pass).count() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    for (name, pass) in [
        (
            "upstream_turbovec_index_plan_bound",
            set.upstream_index_plan_witness_ref
                == "artifact:turbovec_eidos_compressed_index_plan:result",
        ),
        (
            "upstream_cursor_verified",
            set.upstream_index_plan_address
                .to_string()
                .starts_with("turbovec_eidos_compressed_index_plan:"),
        ),
        (
            "accepted_registry_fixture_present",
            plans
                .iter()
                .any(|plan| plan.plan_id == "turbovec_stable_external_id_registry"),
        ),
        (
            "same_uas_maps_same_external_id",
            plans[0]
                .entries
                .iter()
                .all(|entry| entry.external_id == stable_external_id_for_uas(&entry.uas_address)),
        ),
        (
            "reversed_order_address_deterministic",
            set.set_address == reversed.set_address,
        ),
        (
            "rowid_identity_rejected",
            red_pass(&red_results, "sqlite_rowid_used")
                && red_pass(&red_results, "sqlite_rowid_source")
                && red_pass(&red_results, "rowid_in_string_ref"),
        ),
        (
            "insert_order_identity_rejected",
            red_pass(&red_results, "insert_order_used")
                && red_pass(&red_results, "insert_order_source"),
        ),
        (
            "mutable_vector_slot_rejected",
            red_pass(&red_results, "mutable_vector_slot_used")
                && red_pass(&red_results, "mutable_slot_source"),
        ),
        (
            "duplicate_uas_rejected",
            red_pass(&red_results, "duplicate_uas_address"),
        ),
        (
            "duplicate_external_id_rejected",
            red_pass(&red_results, "duplicate_active_external_id"),
        ),
        (
            "reserved_zero_external_id_rejected",
            red_pass(&red_results, "reserved_zero_external_id"),
        ),
        (
            "external_id_mismatch_rejected",
            red_pass(&red_results, "wrong_external_id"),
        ),
        (
            "deleted_id_tombstone_required",
            red_pass(&red_results, "remove_tombstone_entry"),
        ),
        (
            "generation_mismatch_rejected",
            red_pass(&red_results, "reinsert_generation_one")
                && red_pass(&red_results, "duplicate_logical_generation"),
        ),
        (
            "collision_ledger_required",
            red_pass(&red_results, "missing_collision_ledger"),
        ),
        (
            "collision_alias_rejected",
            red_pass(&red_results, "collision_alias_reused")
                && red_pass(&red_results, "collision_resolution_reuse_alias")
                && red_pass(&red_results, "collision_not_rejected"),
        ),
        (
            "allowlist_ids_compile_from_uas_required",
            red_pass(&red_results, "allowlist_not_from_uas"),
        ),
        (
            "export_import_roundtrip_required",
            red_pass(&red_results, "export_import_roundtrip_missing"),
        ),
        (
            "atomic_manifest_required",
            red_pass(&red_results, "atomic_manifest_missing"),
        ),
        (
            "app_cold_store_truth_required",
            red_pass(&red_results, "app_cold_store_not_truth")
                && red_pass(&red_results, "registry_claims_truth"),
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
            metrics.registry_bytes_loaded == 0
                && metrics.index_bytes_loaded == 0
                && metrics.runtime_bytes_loaded == 0
                && metrics.model_bytes_loaded == 0
                && metrics.provider_calls_made == 0
                && red_pass(&red_results, "registry_bytes_loaded")
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
        "active_entry_count",
        metrics.active_entry_count,
        "==",
        2,
        "entries",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "tombstoned_entry_count",
        metrics.tombstoned_entry_count,
        "==",
        1,
        "entries",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "reinserted_entry_count",
        metrics.reinserted_entry_count,
        "==",
        1,
        "entries",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "collision_ledger_count",
        metrics.collision_ledger_count,
        "==",
        1,
        "entries",
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
        "registry_bytes_loaded",
        metrics.registry_bytes_loaded,
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
        "registry_set_address".to_string(),
        Measurement {
            value: serde_json::json!(set.set_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "registry_set_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::json!("turbovec_stable_external_id_registry_plan:"),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "registry_set_address".to_string(),
        set.set_address
            .to_string()
            .starts_with("turbovec_stable_external_id_registry_plan:"),
    );
    measurements.insert(
        "next_research_to_build_unit".to_string(),
        Measurement {
            value: serde_json::json!(TURBOVEC_STABLE_EXTERNAL_ID_REGISTRY_PLAN_NEXT_CURSOR),
            unit: "cursor".to_string(),
        },
    );
    thresholds.insert(
        "next_research_to_build_unit".to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::json!(TURBOVEC_STABLE_EXTERNAL_ID_REGISTRY_PLAN_NEXT_CURSOR),
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
            "detail": "No TurboVec code imported, no registry/index/model/runtime bytes loaded, no recall or route quality claimed, and no L2/L3/product promotion."
        })],
        notes: "Builds F-TurboVec-UASAddressStableExternalIds from the TurboVec Eidos compressed-index plan. Scope is T1/L1 metadata only: UAS addresses become stable u64 external IDs through deterministic hash binding, tombstone/generation handling, collision alias rejection, AppColdStore truth, atomic rebuild manifest, rollback, RunEventLog, AnswerPacket, and no product/runtime promotion.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn upstream_index_plan_address() -> Result<UasAddress, Box<dyn std::error::Error>> {
    let raw = std::fs::read_to_string(UPSTREAM_RESULT)?;
    let value: serde_json::Value = serde_json::from_str(&raw)?;
    if value
        .get("overall_pass")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec Eidos compressed-index plan has not passed".into());
    }
    if value
        .pointer("/measurements/next_research_to_build_unit/value")
        .and_then(serde_json::Value::as_str)
        != Some(TURBOVEC_STABLE_EXTERNAL_ID_REGISTRY_PLAN_CURSOR)
    {
        return Err("upstream TurboVec Eidos plan does not point at stable-ID registry".into());
    }
    if value
        .pointer("/pass_per_axis/uas_external_id_policy_bound")
        .and_then(serde_json::Value::as_bool)
        != Some(true)
    {
        return Err("upstream TurboVec Eidos plan lacks external-ID policy axis".into());
    }
    let address = value
        .pointer("/measurements/plan_set_address/value")
        .and_then(serde_json::Value::as_str)
        .ok_or("missing upstream plan_set_address measurement")?;
    Ok(UasAddress::from_str(address)?)
}

fn build_set(
    upstream_index_plan_address: UasAddress,
    plans: Vec<TurboVecStableExternalIdRegistryPlan>,
) -> Result<TurboVecStableExternalIdRegistryPlanSet, Box<dyn std::error::Error>> {
    Ok(TurboVecStableExternalIdRegistryPlanSet::from_plans(
        upstream_index_plan_address,
        "artifact:turbovec_eidos_compressed_index_plan:result",
        plans,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecStableExternalIdRegistryStatus::MetadataOnlyPlan,
        TurboVecStableExternalIdPromotionTier::T1L1Metadata,
        SET_METADATA_BYTES,
        true,
        true,
        true,
        CREATED_AT_MS,
    )?)
}

fn accepted_plans(
    upstream_index_plan_address: UasAddress,
) -> Result<Vec<TurboVecStableExternalIdRegistryPlan>, Box<dyn std::error::Error>> {
    let alpha = entry(
        "alpha",
        "note_alpha",
        1,
        TurboVecStableExternalIdLifecycle::Active,
    );
    let beta_old = entry(
        "beta_old",
        "note_beta",
        1,
        TurboVecStableExternalIdLifecycle::Tombstoned,
    );
    let beta_new = entry(
        "beta_new",
        "note_beta",
        2,
        TurboVecStableExternalIdLifecycle::ReinsertedNewGeneration,
    );
    let gamma = entry(
        "gamma",
        "code_gamma",
        1,
        TurboVecStableExternalIdLifecycle::Active,
    );
    let collision = TurboVecStableExternalIdCollisionLedgerEntry {
        collision_id: "collision_left_alpha_right_gamma".to_string(),
        left_uas_address: alpha.uas_address.clone(),
        right_uas_address: gamma.uas_address.clone(),
        candidate_external_id: alpha.external_id,
        resolved_external_id: gamma.external_id,
        resolution:
            TurboVecStableExternalIdCollisionResolution::RejectAliasAndAllocateDeterministicId,
        alias_rejected: true,
        registry_rebuild_required: true,
    };

    Ok(vec![TurboVecStableExternalIdRegistryPlan {
        plan_id: "turbovec_stable_external_id_registry".to_string(),
        upstream_plan_address: upstream_index_plan_address,
        upstream_plan_witness_ref: "artifact:turbovec_eidos_compressed_index_plan:result"
            .to_string(),
        source_api_ref: "https://github.com/RyanCodrai/turbovec/blob/main/docs/api.md".to_string(),
        organs: vec![
            TurboVecIndexOrgan::Eidos,
            TurboVecIndexOrgan::AppColdStore,
            TurboVecIndexOrgan::SemanticWorkingSetPlan,
            TurboVecIndexOrgan::AnswerPacket,
        ],
        entries: vec![alpha, beta_old, beta_new, gamma],
        collision_ledger: vec![collision],
        policy: TurboVecStableExternalIdRegistryPolicy::fail_closed_cache_manifest(),
        byte_ledger: TurboVecStableExternalIdByteLedger::metadata_only(12_000, 4_096)?,
        proof_refs: proof_refs("turbovec_stable_external_id_registry"),
        registry_status: TurboVecStableExternalIdRegistryStatus::MetadataOnlyPlan,
        product_build: ProductBuild::Pro,
        pro_status: ProStatus::ResearchCandidate,
        promotion_tier: TurboVecStableExternalIdPromotionTier::T1L1Metadata,
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

fn entry(
    salt: &str,
    logical_source_key: &str,
    generation: u64,
    lifecycle: TurboVecStableExternalIdLifecycle,
) -> TurboVecStableExternalIdEntry {
    let uas_address = UasAddress::new(
        UasKind::Other("eidos_source_chunk".to_string()),
        format!("{salt}:{logical_source_key}:{generation}").as_bytes(),
        CREATED_AT_MS,
    );
    TurboVecStableExternalIdEntry {
        entry_id: format!("entry_{salt}_{generation}"),
        logical_source_key: logical_source_key.to_string(),
        external_id: stable_external_id_for_uas(&uas_address),
        generation,
        lifecycle,
        external_id_source: TurboVecStableExternalIdSource::UasAddressDeterministicHash,
        app_cold_store_ref: format!("app_cold_store:eidos:{salt}:{generation}"),
        source_card_ref: "compressed_model_source_card:turbovec_eidos_cache".to_string(),
        uas_address,
        sqlite_rowid_used: false,
        insert_order_used: false,
        mutable_vector_slot_used: false,
    }
}

fn proof_refs(id: &str) -> TurboVecStableExternalIdProofRefs {
    TurboVecStableExternalIdProofRefs {
        falsifier_ref: format!("falsifier:F-TurboVec-UASAddressStableExternalIds:{id}"),
        rollback_ref: format!("rollback:turbovec_stable_id:{id}"),
        run_event_log_ref: format!("run_event_log:turbovec_stable_id:{id}"),
        answer_packet_ref: format!("answer_packet:turbovec_stable_id:{id}"),
        compatibility_fence_ref: format!("compat:turbovec_stable_id:{id}"),
    }
}

fn red_fixture_results(
    set: &TurboVecStableExternalIdRegistryPlanSet,
) -> Result<Vec<(&'static str, bool)>, Box<dyn std::error::Error>> {
    let mut results = Vec::new();
    let base_plans = set.plans.clone();
    let upstream = set.upstream_index_plan_address.clone();

    let mut push_plan =
        |name: &'static str, mutate: fn(&mut Vec<TurboVecStableExternalIdRegistryPlan>)| {
            let mut plans = base_plans.clone();
            mutate(&mut plans);
            results.push((name, build_set(upstream.clone(), plans).is_err()));
        };

    push_plan("duplicate_plan_id", |plans| plans.push(plans[0].clone()));
    push_plan("bad_upstream_witness_ref", |plans| {
        plans[0].upstream_plan_witness_ref = "artifact:wrong:result".to_string();
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
    push_plan("missing_answer_packet_organ", |plans| {
        plans[0]
            .organs
            .retain(|organ| *organ != TurboVecIndexOrgan::AnswerPacket);
    });
    push_plan("duplicate_entry_id", |plans| {
        let mut duplicate = plans[0].entries[0].clone();
        duplicate.uas_address = plans[0].entries[1].uas_address.clone();
        duplicate.external_id = stable_external_id_for_uas(&duplicate.uas_address);
        plans[0].entries.push(duplicate);
    });
    push_plan("duplicate_uas_address", |plans| {
        let mut duplicate = plans[0].entries[0].clone();
        duplicate.entry_id = "entry_duplicate_uas".to_string();
        plans[0].entries.push(duplicate);
    });
    push_plan("duplicate_active_external_id", |plans| {
        let ext = plans[0].entries[0].external_id;
        plans[0].entries[3].external_id = ext;
    });
    push_plan("reserved_zero_external_id", |plans| {
        plans[0].entries[0].external_id = 0;
    });
    push_plan("wrong_external_id", |plans| {
        plans[0].entries[0].external_id = plans[0].entries[0].external_id.saturating_add(1);
    });
    push_plan("sqlite_rowid_used", |plans| {
        plans[0].entries[0].sqlite_rowid_used = true;
    });
    push_plan("sqlite_rowid_source", |plans| {
        plans[0].entries[0].external_id_source = TurboVecStableExternalIdSource::SqliteRowid;
    });
    push_plan("rowid_in_string_ref", |plans| {
        plans[0].entries[0].app_cold_store_ref = "app_cold_store:sqlite_rowid:99".to_string();
    });
    push_plan("insert_order_used", |plans| {
        plans[0].entries[0].insert_order_used = true;
    });
    push_plan("insert_order_source", |plans| {
        plans[0].entries[0].external_id_source = TurboVecStableExternalIdSource::InsertOrder;
    });
    push_plan("mutable_vector_slot_used", |plans| {
        plans[0].entries[0].mutable_vector_slot_used = true;
    });
    push_plan("mutable_slot_source", |plans| {
        plans[0].entries[0].external_id_source = TurboVecStableExternalIdSource::MutableVectorSlot;
    });
    push_plan("remove_tombstone_entry", |plans| {
        plans[0]
            .entries
            .retain(|entry| entry.lifecycle != TurboVecStableExternalIdLifecycle::Tombstoned);
    });
    push_plan("reinsert_generation_one", |plans| {
        plans[0].entries[2].generation = 1;
    });
    push_plan("duplicate_logical_generation", |plans| {
        plans[0].entries[2].logical_source_key = plans[0].entries[1].logical_source_key.clone();
        plans[0].entries[2].generation = plans[0].entries[1].generation;
    });
    push_plan("missing_collision_ledger", |plans| {
        plans[0].collision_ledger.clear();
    });
    push_plan("collision_alias_reused", |plans| {
        plans[0].collision_ledger[0].resolved_external_id =
            plans[0].collision_ledger[0].candidate_external_id;
    });
    push_plan("collision_resolution_reuse_alias", |plans| {
        plans[0].collision_ledger[0].resolution =
            TurboVecStableExternalIdCollisionResolution::ReuseAlias;
    });
    push_plan("collision_not_rejected", |plans| {
        plans[0].collision_ledger[0].alias_rejected = false;
    });
    push_plan("app_cold_store_not_truth", |plans| {
        plans[0].policy.app_cold_store_is_truth = false;
    });
    push_plan("registry_claims_truth", |plans| {
        plans[0].policy.registry_is_cache_manifest = false;
    });
    push_plan("allowlist_not_from_uas", |plans| {
        plans[0].policy.allowlist_ids_compile_from_uas = false;
    });
    push_plan("export_import_roundtrip_missing", |plans| {
        plans[0].policy.export_import_roundtrip_required = false;
    });
    push_plan("atomic_manifest_missing", |plans| {
        plans[0].policy.atomic_manifest_required = false;
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
    push_plan("registry_bytes_loaded", |plans| {
        plans[0].byte_ledger.registry_bytes_loaded = 1;
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
        plans[0].promotion_tier = TurboVecStableExternalIdPromotionTier::T2L2Route;
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
            "set_metadata_budget_exceeded",
            build_set_with_flags(upstream, base_plans, true, true, true, 600 * 1024).is_err(),
        ),
    ];
    results.extend(set_level);
    Ok(results)
}

fn build_set_with_flags(
    upstream_index_plan_address: UasAddress,
    plans: Vec<TurboVecStableExternalIdRegistryPlan>,
    l1_l2_l3_separated: bool,
    runtime_deferred: bool,
    product_promotion_blocked: bool,
    metadata_bytes: u64,
) -> Result<TurboVecStableExternalIdRegistryPlanSet, Box<dyn std::error::Error>> {
    Ok(TurboVecStableExternalIdRegistryPlanSet::from_plans(
        upstream_index_plan_address,
        "artifact:turbovec_eidos_compressed_index_plan:result",
        plans,
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        TurboVecStableExternalIdRegistryStatus::MetadataOnlyPlan,
        TurboVecStableExternalIdPromotionTier::T1L1Metadata,
        metadata_bytes,
        l1_l2_l3_separated,
        runtime_deferred,
        product_promotion_blocked,
        CREATED_AT_MS,
    )?)
}

fn red_pass(results: &[(&'static str, bool)], name: &str) -> bool {
    results
        .iter()
        .find(|(candidate, _)| *candidate == name)
        .map(|(_, pass)| *pass)
        .unwrap_or(false)
}
