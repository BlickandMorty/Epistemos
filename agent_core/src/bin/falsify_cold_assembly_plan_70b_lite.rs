//! `falsify_cold_assembly_plan_70b_lite` — large-local-model assembly planner.
//!
//! This fixture-only witness proves a small-hot plus cold-selected
//! `ColdAssemblyPlan` beats dense-local, RAG-only, and static-route baselines
//! while binding byte accounting, proof-carrying leases, fallback, rollback,
//! and AnswerPacket visibility. It does not run a model, move bytes, mmap
//! files, touch Metal/MLX/GGUF, call providers, or mutate live route policy.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    CoactivationTile, CoactivationTileUnit, CoactivationTileUnitKind, ColdAssemblyBaseline,
    ColdAssemblyPlan, ColdAssemblyPlanError, ColdAssemblyTileRef, ColdAssemblyTileRole,
    ProofCarryingResidencyLease, UasAddress, UasKind,
};

const FALSIFIER_ID: &str = "F-ColdAssemblyPlan-70B-Lite";
const FIXTURE_ID: &str = "cold_assembly_plan_70b_lite_v1";
const COMMAND: &str = "Tools/falsifiers/f_cold_assembly_plan_70b_lite.sh";
const RESULT: &str = "artifacts/falsifiers/cold_assembly_plan_70b_lite/result.json";
const CREATED_AT_MS: u64 = 1_779_300_000_000;
const MAX_PEAK_RSS_BYTES: u64 = 14 * 1024 * 1024 * 1024;

fn main() -> std::process::ExitCode {
    let report = match build_report() {
        Ok(report) => report,
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
    if let Err(error) = write_artifact(&mut file, &report.artifact) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }

    println!(
        "{FALSIFIER_ID}: overall_pass={} plan_score={} baseline_count={} artifact={RESULT}",
        report.artifact.overall_pass, report.plan_score_bps, report.baseline_count
    );

    if report.artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

// UAS: uas/research-construction/cold-assembly-plan-falsifier-report
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
struct ColdAssemblyPlanReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    plan_score_bps: u16,
    baseline_count: u64,
}

fn build_report() -> Result<ColdAssemblyPlanReport, Box<dyn std::error::Error>> {
    let plan = accepted_plan()?;
    let reversed = accepted_plan_with_reversed_inputs()?;
    let missing_rollback_rejected = invalid_missing_rollback().is_err_and(|error| {
        matches!(
            error,
            ColdAssemblyPlanError::MissingRollback | ColdAssemblyPlanError::InvalidFallbackRoute
        )
    });
    let missing_answer_packet_rejected = invalid_missing_answer_packet()
        .is_err_and(|error| matches!(error, ColdAssemblyPlanError::MissingAnswerPacketRef));
    let unscheduled_cold_wake_rejected = invalid_unscheduled_cold_wake()
        .is_err_and(|error| matches!(error, ColdAssemblyPlanError::ColdTileWakeUnaccounted { .. }));
    let missing_lease_rejected = invalid_missing_lease()
        .is_err_and(|error| matches!(error, ColdAssemblyPlanError::MissingProofLease));
    let hidden_cloud_baseline_rejected = invalid_hidden_cloud_baseline()
        .is_err_and(|error| matches!(error, ColdAssemblyPlanError::BaselineNotBeaten));
    let dense = plan
        .baseline("dense_local")
        .ok_or("missing dense baseline")?;
    let rag = plan.baseline("rag_only").ok_or("missing rag baseline")?;
    let static_route = plan
        .baseline("static_route")
        .ok_or("missing static-route baseline")?;
    let max_baseline_quality = plan
        .baselines
        .iter()
        .map(|baseline| baseline.quality_bps)
        .max()
        .unwrap_or_default();
    let max_baseline_evidence = plan
        .baselines
        .iter()
        .map(|baseline| baseline.evidence_validity_bps)
        .max()
        .unwrap_or_default();
    let max_baseline_verifier = plan
        .baselines
        .iter()
        .map(|baseline| baseline.verifier_bps)
        .max()
        .unwrap_or_default();
    let cold_tile_count = plan
        .tile_refs
        .iter()
        .filter(|tile| tile.role == ColdAssemblyTileRole::Cold)
        .count() as u64;
    let scheduled_or_skipped_cold_count =
        (plan.prefetch_order.len() + plan.skipped_cold_tile_ids.len()) as u64;
    let selected_tile_count = plan.tile_refs.len() as u64;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_assembly_plan_present",
        selected_tile_count == 4,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mission_id_bound",
        plan.mission_id == "mission:adversarial-note-70b-lite",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "construction_graph_ref_bound",
        plan.construction_graph_ref.kind.wire_tag().as_ref() == "residency_construction_graph",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_tiles_bound",
        plan.tile_refs
            .iter()
            .any(|tile| tile.role == ColdAssemblyTileRole::Active),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "warm_tiles_bound",
        plan.tile_refs
            .iter()
            .any(|tile| tile.role == ColdAssemblyTileRole::Warm),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_tiles_bound",
        cold_tile_count == 2,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hot_bytes_bound",
        plan.hot_bytes > 0 && plan.hot_bytes < 512 * 1024 * 1024,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "warm_bytes_bound",
        plan.warm_bytes > 0 && plan.warm_bytes < 512 * 1024 * 1024,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_bytes_bound",
        plan.cold_bytes > 0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_executed_bytes_bound",
        plan.active_executed_bytes > 0 && plan.active_executed_bytes < dense.active_executed_bytes,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_bytes_bound",
        plan.kv_bytes > 0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "adapter_bytes_bound",
        plan.adapter_bytes > 0,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "peak_rss_bound",
        plan.peak_rss_estimate_bytes < MAX_PEAK_RSS_BYTES
            && plan.peak_rss_estimate_bytes < dense.peak_rss_estimate_bytes,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prefetch_order_bound",
        plan.prefetch_order.len() == 2 && scheduled_or_skipped_cold_count == cold_tile_count,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "proof_leases_bound",
        plan.proof_carrying_residency_leases.len() == cold_tile_count as usize,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "all_cold_wakes_scheduled_or_skipped",
        scheduled_or_skipped_cold_count == cold_tile_count,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_stack_bound",
        plan.verifier_stack
            .iter()
            .any(|verifier| verifier == "F-ProofCarryingResidencyLease")
            && plan
                .verifier_stack
                .iter()
                .any(|verifier| verifier == FALSIFIER_ID),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fallback_bound",
        plan.fallback_route.starts_with("fallback:"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rollback_verified",
        missing_rollback_rejected && plan.rollback_ref.starts_with("rollback:"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "answer_packet_ref_bound",
        plan.answer_packet_ref.starts_with("answer_packet:") && missing_answer_packet_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "beats_dense_local_baseline",
        beats_baseline(&plan, dense),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "beats_rag_only_baseline",
        beats_baseline(&plan, rag),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "beats_static_route_baseline",
        beats_baseline(&plan, static_route),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_hidden_cloud",
        hidden_cloud_baseline_rejected
            && plan.baselines.iter().all(|baseline| !baseline.hidden_cloud),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_dense_resident_overclaim",
        plan.baselines
            .iter()
            .all(|baseline| !baseline.dense_resident_overclaim),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_runtime_bytes_loaded",
        true,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "plan_address_deterministic",
        plan.plan_address == reversed.plan_address,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "quality_delta_positive",
        plan.quality_bps > max_baseline_quality,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "evidence_validity_delta_positive",
        plan.evidence_validity_bps > max_baseline_evidence,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_delta_positive",
        plan.verifier_bps > max_baseline_verifier,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unscheduled_cold_wake_rejected",
        unscheduled_cold_wake_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_lease_rejected",
        missing_lease_rejected,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_tile_count",
        selected_tile_count,
        4,
        "==",
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "baseline_count",
        plan.baselines.len() as u64,
        3,
        "==",
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_miss_count",
        plan.cold_miss_count,
        0,
        "==",
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_stall_ms",
        plan.cold_stall_ms,
        0,
        "==",
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "peak_rss_bytes",
        plan.peak_rss_estimate_bytes,
        MAX_PEAK_RSS_BYTES,
        "<=",
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_executed_bytes",
        plan.active_executed_bytes,
        dense.active_executed_bytes,
        "<",
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hot_bytes",
        plan.hot_bytes,
        1,
        ">=",
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "warm_bytes",
        plan.warm_bytes,
        1,
        ">=",
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_bytes",
        plan.cold_bytes,
        1,
        ">=",
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_bytes",
        plan.kv_bytes,
        1,
        ">=",
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "adapter_bytes",
        plan.adapter_bytes,
        1,
        ">=",
        "bytes",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "plan_address",
        &plan.plan_address.to_string(),
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "construction_graph_ref",
        &plan.construction_graph_ref.to_string(),
    );

    let artifact = ArtifactBuilder {
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
            "kind": "scope_guard",
            "detail": "metadata-only cold assembly plan fixture; no byte transport, mmap, model decode, MLX, Metal, KV, GGUF, provider call, hidden cloud route, or live route policy mutation executed"
        })],
        notes: "Proves a proof-carrying 70B-lite cold assembly plan beats dense-local, RAG-only, and static-route baselines in a metadata-only fixture; live 70B runtime remains a separate gate.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(ColdAssemblyPlanReport {
        artifact,
        plan_score_bps: plan.score_bps(),
        baseline_count: plan.baselines.len() as u64,
    })
}

fn accepted_plan() -> Result<ColdAssemblyPlan, ColdAssemblyPlanError> {
    accepted_plan_from_parts(tile_refs()?, proof_leases()?, baselines()?)
}

fn accepted_plan_with_reversed_inputs() -> Result<ColdAssemblyPlan, ColdAssemblyPlanError> {
    let mut tiles = tile_refs()?;
    tiles.reverse();
    let mut leases = proof_leases()?;
    leases.reverse();
    let mut baselines = baselines()?;
    baselines.reverse();
    accepted_plan_from_parts(tiles, leases, baselines)
}

fn accepted_plan_from_parts(
    tile_refs: Vec<ColdAssemblyTileRef>,
    leases: Vec<ProofCarryingResidencyLease>,
    baselines: Vec<ColdAssemblyBaseline>,
) -> Result<ColdAssemblyPlan, ColdAssemblyPlanError> {
    ColdAssemblyPlan::new(
        "mission:adversarial-note-70b-lite",
        UasAddress::new(
            UasKind::Other("residency_construction_graph".to_string()),
            b"residency-construction-graph:adversarial-note-70b-lite",
            CREATED_AT_MS,
        ),
        tile_refs,
        vec![
            "unit:cold-evidence".to_string(),
            "unit:verifier-lane".to_string(),
        ],
        vec![],
        leases,
        vec![
            FALSIFIER_ID.to_string(),
            "F-ProofCarryingResidencyLease".to_string(),
            "F-CoactivationTile-Prefetch".to_string(),
        ],
        "fallback:rag-only-abstain-with-visible-gap",
        "rollback:restore-hot-controller-route",
        "answer_packet:adversarial-note-70b-lite",
        8_900,
        8_820,
        8_760,
        baselines,
        CREATED_AT_MS,
    )
}

fn invalid_missing_rollback() -> Result<ColdAssemblyPlan, ColdAssemblyPlanError> {
    ColdAssemblyPlan::new(
        "mission:bad",
        graph_ref(),
        tile_refs()?,
        vec![
            "unit:cold-evidence".to_string(),
            "unit:verifier-lane".to_string(),
        ],
        vec![],
        proof_leases()?,
        vec![FALSIFIER_ID.to_string()],
        "fallback:rag-only",
        "",
        "answer_packet:bad",
        8_900,
        8_820,
        8_760,
        baselines()?,
        CREATED_AT_MS,
    )
}

fn invalid_missing_answer_packet() -> Result<ColdAssemblyPlan, ColdAssemblyPlanError> {
    ColdAssemblyPlan::new(
        "mission:bad",
        graph_ref(),
        tile_refs()?,
        vec![
            "unit:cold-evidence".to_string(),
            "unit:verifier-lane".to_string(),
        ],
        vec![],
        proof_leases()?,
        vec![FALSIFIER_ID.to_string()],
        "fallback:rag-only",
        "rollback:restore-hot",
        "",
        8_900,
        8_820,
        8_760,
        baselines()?,
        CREATED_AT_MS,
    )
}

fn invalid_unscheduled_cold_wake() -> Result<ColdAssemblyPlan, ColdAssemblyPlanError> {
    ColdAssemblyPlan::new(
        "mission:bad",
        graph_ref(),
        tile_refs()?,
        vec!["unit:cold-evidence".to_string()],
        vec![],
        proof_leases()?,
        vec![FALSIFIER_ID.to_string()],
        "fallback:rag-only",
        "rollback:restore-hot",
        "answer_packet:bad",
        8_900,
        8_820,
        8_760,
        baselines()?,
        CREATED_AT_MS,
    )
}

fn invalid_missing_lease() -> Result<ColdAssemblyPlan, ColdAssemblyPlanError> {
    ColdAssemblyPlan::new(
        "mission:bad",
        graph_ref(),
        tile_refs()?,
        vec![
            "unit:cold-evidence".to_string(),
            "unit:verifier-lane".to_string(),
        ],
        vec![],
        vec![],
        vec![FALSIFIER_ID.to_string()],
        "fallback:rag-only",
        "rollback:restore-hot",
        "answer_packet:bad",
        8_900,
        8_820,
        8_760,
        baselines()?,
        CREATED_AT_MS,
    )
}

fn invalid_hidden_cloud_baseline() -> Result<ColdAssemblyPlan, ColdAssemblyPlanError> {
    let mut baselines = baselines()?;
    baselines.push(ColdAssemblyBaseline::new(
        "cloud_shadow",
        8_700,
        8_600,
        8_500,
        512 * 1024 * 1024,
        8 * 1024 * 1024 * 1024,
        3,
        56,
        true,
        false,
    )?);
    ColdAssemblyPlan::new(
        "mission:bad",
        graph_ref(),
        tile_refs()?,
        vec![
            "unit:cold-evidence".to_string(),
            "unit:verifier-lane".to_string(),
        ],
        vec![],
        proof_leases()?,
        vec![FALSIFIER_ID.to_string()],
        "fallback:rag-only",
        "rollback:restore-hot",
        "answer_packet:bad",
        8_900,
        8_820,
        8_760,
        baselines,
        CREATED_AT_MS,
    )
}

fn graph_ref() -> UasAddress {
    UasAddress::new(
        UasKind::Other("residency_construction_graph".to_string()),
        b"residency-construction-graph:adversarial-note-70b-lite",
        CREATED_AT_MS,
    )
}

fn tile_refs() -> Result<Vec<ColdAssemblyTileRef>, ColdAssemblyPlanError> {
    Ok(vec![
        tile_ref(
            "unit:hot-controller",
            ColdAssemblyTileRole::Active,
            CoactivationTileUnitKind::Expert,
            64 * 1024,
            0,
            0,
            1_200,
        )?,
        tile_ref(
            "unit:warm-adapter",
            ColdAssemblyTileRole::Warm,
            CoactivationTileUnitKind::AdapterSlice,
            16 * 1024,
            0,
            16 * 1024,
            1_050,
        )?,
        tile_ref(
            "unit:cold-evidence",
            ColdAssemblyTileRole::Cold,
            CoactivationTileUnitKind::EvidenceBundle,
            32 * 1024,
            24 * 1024,
            0,
            950,
        )?,
        tile_ref(
            "unit:verifier-lane",
            ColdAssemblyTileRole::Cold,
            CoactivationTileUnitKind::EvidenceBundle,
            8 * 1024,
            8 * 1024,
            0,
            900,
        )?,
    ])
}

fn tile_ref(
    unit_id: &str,
    role: ColdAssemblyTileRole,
    unit_kind: CoactivationTileUnitKind,
    bytes: u64,
    kv_bytes: u64,
    adapter_bytes: u64,
    reuse_horizon: u64,
) -> Result<ColdAssemblyTileRef, ColdAssemblyPlanError> {
    let tile = CoactivationTile::new(
        unit_id,
        "memory:adversarial-note-70b-lite",
        vec![CoactivationTileUnit::new(
            unit_id,
            unit_kind,
            UasAddress::new(UasKind::KvPage, unit_id.as_bytes(), CREATED_AT_MS),
            0,
            bytes,
            if adapter_bytes > 0 { "raw" } else { "nf4" },
            "blake3:cold-assembly-fixture",
            reuse_horizon,
            FALSIFIER_ID,
        )
        .map_err(|_| ColdAssemblyPlanError::MissingTileRef)?],
        vec![
            "F-CoactivationTile-Prefetch".to_string(),
            "F-ProofCarryingResidencyLease".to_string(),
            FALSIFIER_ID.to_string(),
        ],
        "rollback:cold-assembly-tile-layout",
        CREATED_AT_MS,
    )
    .map_err(|_| ColdAssemblyPlanError::MissingTileRef)?;
    ColdAssemblyTileRef::from_tile(&tile, role, kv_bytes, adapter_bytes)
}

fn proof_leases() -> Result<Vec<ProofCarryingResidencyLease>, ColdAssemblyPlanError> {
    Ok(vec![
        lease("unit:cold-evidence", 24 * 1024, 9_200)?,
        lease("unit:verifier-lane", 8 * 1024, 8_900)?,
    ])
}

fn lease(
    unit_id: &str,
    active_byte_cost: u64,
    utility_bps: u16,
) -> Result<ProofCarryingResidencyLease, ColdAssemblyPlanError> {
    ProofCarryingResidencyLease::new(
        unit_id,
        UasAddress::new(UasKind::KvPage, unit_id.as_bytes(), CREATED_AT_MS),
        "70b-lite cold assembly needs bounded cold wake",
        active_byte_cost,
        utility_bps,
        "F-ProofCarryingResidencyLease",
        "fallback:skip-cold-unit-and-abstain",
        "rollback:drop-cold-unit",
        CREATED_AT_MS,
        120_000,
    )
    .map_err(|_| ColdAssemblyPlanError::MissingProofLease)
}

fn baselines() -> Result<Vec<ColdAssemblyBaseline>, ColdAssemblyPlanError> {
    Ok(vec![
        ColdAssemblyBaseline::new(
            "dense_local",
            8_300,
            8_050,
            7_950,
            1024 * 1024 * 1024,
            12 * 1024 * 1024 * 1024,
            5,
            120,
            false,
            false,
        )?,
        ColdAssemblyBaseline::new(
            "rag_only",
            7_650,
            7_500,
            6_950,
            256 * 1024 * 1024,
            4 * 1024 * 1024 * 1024,
            4,
            90,
            false,
            false,
        )?,
        ColdAssemblyBaseline::new(
            "static_route",
            7_980,
            7_840,
            7_350,
            512 * 1024 * 1024,
            6 * 1024 * 1024 * 1024,
            3,
            70,
            false,
            false,
        )?,
    ])
}

fn beats_baseline(plan: &ColdAssemblyPlan, baseline: &ColdAssemblyBaseline) -> bool {
    plan.score_bps() > baseline.score_bps()
        && plan.quality_bps > baseline.quality_bps
        && plan.evidence_validity_bps > baseline.evidence_validity_bps
        && plan.verifier_bps > baseline.verifier_bps
        && plan.active_executed_bytes < baseline.active_executed_bytes
        && plan.peak_rss_estimate_bytes < baseline.peak_rss_estimate_bytes
        && plan.cold_stall_ms < baseline.cold_stall_ms
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    threshold: u64,
    operator: &str,
    unit: &str,
) {
    let pass = match operator {
        "==" => actual == threshold,
        "<" => actual < threshold,
        "<=" => actual <= threshold,
        ">=" => actual >= threshold,
        _ => false,
    };
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::from(threshold),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}

fn add_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(actual.to_string()),
            unit: "string".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "nonempty".to_string(),
            value: serde_json::Value::String("nonempty".to_string()),
            unit: "string".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), !actual.is_empty());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn report_contains_required_cold_assembly_axes() {
        let report = build_report().expect("report");
        assert!(report.artifact.overall_pass);
        assert_eq!(report.artifact.falsifier_id, FALSIFIER_ID);
        assert_eq!(
            report
                .artifact
                .measurements
                .get("plan_address")
                .expect("plan address")
                .unit,
            "string"
        );
        for axis in [
            "cold_assembly_plan_present",
            "construction_graph_ref_bound",
            "proof_leases_bound",
            "beats_dense_local_baseline",
            "beats_rag_only_baseline",
            "beats_static_route_baseline",
            "no_hidden_cloud",
            "no_dense_resident_overclaim",
            "all_cold_wakes_scheduled_or_skipped",
            "plan_address_deterministic",
        ] {
            assert_eq!(report.artifact.pass_per_axis.get(axis), Some(&true));
        }
    }
}
