//! `falsify_ssd_wear_budget`.
//!
//! Metadata-only witness for `F-SSD-WearBudget`. It proves repeated
//! ColdStream-shaped transport plans account for read/write volume, burst
//! volume, energy, cache pressure, write amplification, rollback, admission,
//! RunEventLog, and visible AnswerPacket caveats. No runtime, model, mmap,
//! Metal, MLX, or SSD stress bytes move here.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[cfg(test)]
use agent_core::falsifier_artifacts::axes::SSD_WEAR_BUDGET_AXES;
use agent_core::falsifier_artifacts::axes::TRANSPORT_TRACE_ANSWER_PACKET_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, SsdWearBudgetError, SsdWearBudgetPlan, SsdWearBudgetSurface,
    SsdWearBudgetWitness, SSD_WEAR_BUDGET_CURSOR, SSD_WEAR_BUDGET_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SSD-WearBudget";
const FIXTURE_ID: &str = "ssd_wear_budget_v1";
const COMMAND: &str = "Tools/falsifiers/f_ssd_wear_budget.sh";
const RESULT: &str = "artifacts/falsifiers/ssd_wear_budget/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const TRANSPORT_TRACE_PATH: &str = "artifacts/falsifiers/transport_trace_answer_packet/result.json";
const MIN_PLAN_COUNT: u64 = 3;
const MIN_SURFACE_COUNT: u64 = 3;
const MIN_TOTAL_READ_BYTES: u64 = 384 * 1024;
const MIN_TOTAL_WRITE_BYTES: u64 = 32 * 1024;
const MIN_DAILY_READ_BUDGET_BYTES: u64 = 3 * 1024 * 1024;
const MIN_DAILY_WRITE_BUDGET_BYTES: u64 = 384 * 1024;
const MIN_BURST_READ_BUDGET_BYTES: u64 = 512 * 1024;
const MIN_BURST_WRITE_BUDGET_BYTES: u64 = 64 * 1024;
const MAX_ENERGY_MILLIJOULES: u64 = 1_000;
const MAX_CACHE_POLLUTION_BPS: u64 = 1_000;
const MAX_WRITE_AMPLIFICATION_BPS: u64 = 15_000;
const MIN_REUSE_HORIZON_MS: u64 = 30_000;
const MAX_METADATA_BYTES: u64 = 192 * 1024;

#[derive(Debug)]
// UAS: uas:ssd-wear-budget:witness-error
// Plane: Verification
// Residency: metadata-only witness rejection taxonomy.
enum SsdWearWitnessError {
    Primitive(SsdWearBudgetError),
    Io(String),
}

impl std::fmt::Display for SsdWearWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for SsdWearWitnessError {}

impl From<SsdWearBudgetError> for SsdWearWitnessError {
    fn from(value: SsdWearBudgetError) -> Self {
        Self::Primitive(value)
    }
}

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
        "{FALSIFIER_ID}: overall_pass={} artifact={RESULT}",
        artifact.overall_pass
    );
    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, SsdWearWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fixture_witness()?;
    let metrics = witness.metrics();
    let address = witness.address();
    let mut reversed_plans = witness.plans.clone();
    reversed_plans.reverse();
    let deterministic = SsdWearBudgetWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "wear_budget_only",
        reversed_plans,
        witness.surfaces.clone(),
        metrics.unbudgeted_loop_baseline_bps,
        metrics.cache_pollution_baseline_bps,
        metrics.silent_wear_baseline_bps,
        metrics.live_authority_baseline_bps,
    )?
    .address()
        == address;
    let invalid_axes = invalid_fixture_axes()?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        (
            "upstream_transport_trace_answer_packet_pass",
            evidence.transport_trace_pass,
        ),
        (
            "guard_cursor_ssd_wear_or_advanced",
            evidence.guard_next_existing_work == SSD_WEAR_BUDGET_CURSOR
                || evidence.guard_next_existing_work == SSD_WEAR_BUDGET_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_ssd_wear_or_advanced",
            evidence.capability_next_bottleneck == SSD_WEAR_BUDGET_CURSOR
                || evidence.capability_next_bottleneck == SSD_WEAR_BUDGET_NEXT_CURSOR,
        ),
        (
            "product_status_research_only",
            witness.product_build == ProductBuild::Pro
                && witness.pro_status == ProStatus::ResearchCandidate,
        ),
        (
            "route_authority_wear_budget_only",
            witness.route_authority == "wear_budget_only",
        ),
        (
            "wear_budget_plans_bound",
            metrics.plan_count >= MIN_PLAN_COUNT,
        ),
        (
            "visible_surfaces_bound",
            metrics.surface_count >= MIN_SURFACE_COUNT,
        ),
        (
            "budget_refs_bound",
            witness
                .plans
                .iter()
                .all(|plan| plan.budget_ref.starts_with("ssd_wear_budget:")),
        ),
        (
            "transport_trace_refs_bound",
            witness
                .plans
                .iter()
                .all(|plan| plan.transport_trace_ref.starts_with("transport_trace:")),
        ),
        (
            "answer_packet_refs_bound",
            metrics.answer_packet_count == metrics.plan_count
                && witness
                    .plans
                    .iter()
                    .all(|plan| plan.answer_packet_ref.starts_with("answer_packet:")),
        ),
        (
            "run_event_log_refs_bound",
            metrics.run_event_log_count == metrics.plan_count
                && witness
                    .plans
                    .iter()
                    .all(|plan| plan.run_event_log_ref.starts_with("run_event_log:")),
        ),
        (
            "rollback_bound",
            witness
                .plans
                .iter()
                .all(|plan| plan.rollback_ref.starts_with("rollback:")),
        ),
        (
            "admission_bound",
            witness
                .plans
                .iter()
                .all(|plan| plan.admission_ref.starts_with("admission:")),
        ),
        (
            "scope_rex_bound",
            witness
                .plans
                .iter()
                .all(|plan| plan.scope_rex_ref.starts_with("scope_rex:")),
        ),
        (
            "sovereign_gate_bound",
            witness
                .plans
                .iter()
                .all(|plan| plan.sovereign_gate_ref.starts_with("sovereign_gate:")),
        ),
        (
            "compatibility_fence_bound",
            witness
                .plans
                .iter()
                .all(|plan| plan.compatibility_fence.starts_with("compat:")),
        ),
        (
            "cache_policy_bound",
            witness
                .plans
                .iter()
                .all(|plan| plan.cache_policy_ref.starts_with("cache_policy:")),
        ),
        (
            "read_volume_budgeted",
            witness
                .plans
                .iter()
                .all(|plan| plan.observed_read_bytes <= plan.daily_read_budget_bytes),
        ),
        (
            "write_volume_budgeted",
            witness
                .plans
                .iter()
                .all(|plan| plan.observed_write_bytes <= plan.daily_write_budget_bytes),
        ),
        (
            "burst_read_budgeted",
            witness
                .plans
                .iter()
                .all(|plan| plan.observed_read_bytes <= plan.burst_read_budget_bytes),
        ),
        (
            "burst_write_budgeted",
            witness
                .plans
                .iter()
                .all(|plan| plan.observed_write_bytes <= plan.burst_write_budget_bytes),
        ),
        (
            "energy_budgeted",
            witness
                .plans
                .iter()
                .all(|plan| plan.energy_millijoules <= plan.energy_budget_millijoules),
        ),
        (
            "cache_pollution_budgeted",
            witness
                .plans
                .iter()
                .all(|plan| plan.cache_pollution_bps <= plan.cache_pollution_budget_bps),
        ),
        (
            "write_amplification_bound",
            metrics.max_write_amplification_bps <= MAX_WRITE_AMPLIFICATION_BPS,
        ),
        (
            "reuse_horizon_bound",
            metrics.min_reuse_horizon_ms >= MIN_REUSE_HORIZON_MS,
        ),
        (
            "visible_wear_caveat_bound",
            witness.plans.iter().all(|plan| {
                let caveat = plan.visible_wear_caveat.to_ascii_lowercase();
                caveat.contains("ssd")
                    && caveat.contains("wear")
                    && caveat.contains("energy")
                    && caveat.contains("cache")
                    && caveat.contains("answerpacket")
            }),
        ),
        (
            "l1_l2_l3_separation_bound",
            witness.plans.iter().all(|plan| plan.l1_l2_l3_separated),
        ),
        (
            "no_hidden_route_authority",
            witness
                .plans
                .iter()
                .all(|plan| !plan.hidden_route_authority),
        ),
        (
            "no_route_policy_mutation",
            witness.plans.iter().all(|plan| !plan.route_policy_mutated),
        ),
        (
            "no_scope_rex_bypass",
            witness.plans.iter().all(|plan| !plan.scope_rex_bypassed),
        ),
        (
            "no_sovereign_gate_bypass",
            witness
                .plans
                .iter()
                .all(|plan| !plan.sovereign_gate_bypassed),
        ),
        (
            "no_answer_packet_suppression",
            witness
                .plans
                .iter()
                .all(|plan| !plan.answer_packet_suppressed),
        ),
        (
            "no_hidden_chain",
            witness.plans.iter().all(|plan| !plan.hidden_chain_exposed),
        ),
        (
            "no_hidden_cloud",
            witness.plans.iter().all(|plan| !plan.hidden_cloud_route),
        ),
        ("no_runtime_bytes_loaded", metrics.runtime_bytes_loaded == 0),
        ("no_model_bytes_loaded", metrics.model_bytes_loaded == 0),
        (
            "metadata_bound",
            metrics.max_metadata_bytes <= MAX_METADATA_BYTES,
        ),
        ("ssd_wear_budget_address_deterministic", deterministic),
    ];
    for (axis, passed) in bool_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            passed,
        );
    }
    for (axis, passed) in invalid_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            passed,
        );
    }
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "plan_count",
        metrics.plan_count,
        MIN_PLAN_COUNT,
        "plans",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "surface_count",
        metrics.surface_count,
        MIN_SURFACE_COUNT,
        "surfaces",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "answer_packet_count",
        metrics.answer_packet_count,
        MIN_PLAN_COUNT,
        "packets",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "run_event_log_count",
        metrics.run_event_log_count,
        MIN_PLAN_COUNT,
        "logs",
    );
    for (axis, actual, operator, expected, unit) in [
        (
            "observed_read_bytes",
            metrics.observed_read_bytes,
            ">=",
            MIN_TOTAL_READ_BYTES,
            "bytes",
        ),
        (
            "observed_write_bytes",
            metrics.observed_write_bytes,
            ">=",
            MIN_TOTAL_WRITE_BYTES,
            "bytes",
        ),
        (
            "daily_read_budget_bytes",
            metrics.daily_read_budget_bytes,
            ">=",
            MIN_DAILY_READ_BUDGET_BYTES,
            "bytes",
        ),
        (
            "daily_write_budget_bytes",
            metrics.daily_write_budget_bytes,
            ">=",
            MIN_DAILY_WRITE_BUDGET_BYTES,
            "bytes",
        ),
        (
            "max_burst_read_bytes",
            metrics.max_burst_read_bytes,
            ">=",
            MIN_BURST_READ_BUDGET_BYTES,
            "bytes",
        ),
        (
            "max_burst_write_bytes",
            metrics.max_burst_write_bytes,
            ">=",
            MIN_BURST_WRITE_BUDGET_BYTES,
            "bytes",
        ),
        (
            "max_energy_millijoules",
            metrics.max_energy_millijoules,
            "<=",
            MAX_ENERGY_MILLIJOULES,
            "millijoules",
        ),
        (
            "max_cache_pollution_bps",
            metrics.max_cache_pollution_bps,
            "<=",
            MAX_CACHE_POLLUTION_BPS,
            "bps",
        ),
        (
            "max_write_amplification_bps",
            metrics.max_write_amplification_bps,
            "<=",
            MAX_WRITE_AMPLIFICATION_BPS,
            "bps",
        ),
        (
            "min_reuse_horizon_ms",
            metrics.min_reuse_horizon_ms,
            ">=",
            MIN_REUSE_HORIZON_MS,
            "ms",
        ),
        (
            "runtime_bytes_loaded",
            metrics.runtime_bytes_loaded,
            "<=",
            0,
            "bytes",
        ),
        (
            "model_bytes_loaded",
            metrics.model_bytes_loaded,
            "<=",
            0,
            "bytes",
        ),
        (
            "max_metadata_bytes",
            metrics.max_metadata_bytes,
            "<=",
            MAX_METADATA_BYTES,
            "bytes",
        ),
        (
            "unbudgeted_loop_baseline_bps",
            metrics.unbudgeted_loop_baseline_bps,
            "<",
            9_000,
            "bps",
        ),
        (
            "cache_pollution_baseline_bps",
            metrics.cache_pollution_baseline_bps,
            "<",
            9_000,
            "bps",
        ),
        (
            "silent_wear_baseline_bps",
            metrics.silent_wear_baseline_bps,
            "<",
            9_000,
            "bps",
        ),
        (
            "live_authority_baseline_bps",
            metrics.live_authority_baseline_bps,
            "<",
            9_000,
            "bps",
        ),
    ] {
        add_u64_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            axis,
            actual,
            operator,
            expected,
            unit,
        );
    }
    measurements.insert(
        "ssd_wear_budget_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address.clone()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "ssd_wear_budget_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String("uas:ssd-wear-budget:sha256:".to_string()),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "ssd_wear_budget_address".to_string(),
        address.starts_with("uas:ssd-wear-budget:sha256:"),
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
            "kind": "metadata_only_ssd_wear_budget",
            "detail": "Simulates repeated ColdStream transport-plan read/write, burst, energy, cache, and write-amplification budgets. No live SSD stress, mmap replacement, model load, runtime bytes, provider route, or product promotion is proven."
        })],
        notes: "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. F-SSD-WearBudget is metadata-only: repeated transport plans must show SSD wear, energy, cache pollution, write amplification, rollback, RunEventLog, and AnswerPacket caveats before ColdStream can approach a hot path. L2 remains red; L3 is unchanged.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();
    Ok(artifact)
}

fn fixture_witness() -> Result<SsdWearBudgetWitness, SsdWearWitnessError> {
    let plans = vec![
        plan("cpu", 128 * 1024, 8 * 1024, 520, 620)?,
        plan("metal", 192 * 1024, 16 * 1024, 610, 700)?,
        plan("mlx", 256 * 1024, 24 * 1024, 720, 780)?,
    ];
    let surfaces = plans
        .iter()
        .map(|plan| {
            surface(
                plan.plan_id.trim_start_matches("wear-plan-"),
                &plan.answer_packet_ref,
                plan.observed_read_bytes,
                plan.observed_write_bytes,
            )
        })
        .collect::<Result<Vec<_>, _>>()?;
    Ok(SsdWearBudgetWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "wear_budget_only",
        plans,
        surfaces,
        4_000,
        4_500,
        4_750,
        4_250,
    )?)
}

fn plan(
    suffix: &str,
    read: u64,
    write: u64,
    energy_millijoules: u64,
    cache_pollution_bps: u32,
) -> Result<SsdWearBudgetPlan, SsdWearBudgetError> {
    SsdWearBudgetPlan::new(
        format!("wear-plan-{suffix}"),
        format!("route:{suffix}"),
        format!("ssd_wear_budget:{suffix}"),
        format!("transport_trace:{suffix}"),
        format!("answer_packet:{suffix}"),
        format!("run_event_log:{suffix}"),
        format!("rollback:{suffix}"),
        format!("admission:{suffix}"),
        format!("scope_rex:{suffix}"),
        format!("sovereign_gate:{suffix}"),
        format!("compat:{suffix}:2026-06-04"),
        format!("cache_policy:{suffix}:no_silent_pollution"),
        read,
        write,
        read * 8,
        write * 8 + 1,
        read * 4,
        write * 4 + 1,
        energy_millijoules,
        1_000,
        cache_pollution_bps,
        1_000,
        11_200,
        45_000,
        format!("SSD wear, energy, and cache impact are visible in AnswerPacket for {suffix}; fallback remains visible and rollback is bound before any transport-shaped material can affect output."),
        format!("AnswerPacket shows SSD wear budget for {read} read bytes and {write} write bytes with energy and cache caveats before cold transport affects output."),
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        0,
        0,
        36 * 1024,
    )
}

fn surface(
    suffix: &str,
    answer_packet_ref: &str,
    read: u64,
    write: u64,
) -> Result<SsdWearBudgetSurface, SsdWearBudgetError> {
    SsdWearBudgetSurface::new(
        format!("surface-{suffix}"),
        answer_packet_ref.to_string(),
        format!("AnswerPacket visible SSD wear budget surface {suffix}: {read} read bytes and {write} write bytes are reported with energy, cache, fallback, rollback, and L1/L2/L3 separation; no live 70B or hidden cloud claim is promoted."),
        vec![
            "SSD wear".to_string(),
            "AnswerPacket".to_string(),
            "rollback".to_string(),
            "L1/L2/L3".to_string(),
        ],
        vec![
            "70B route is live".to_string(),
            "hidden reasoning".to_string(),
            "SSD is RAM".to_string(),
        ],
    )
}

fn invalid_fixture_axes() -> Result<Vec<(&'static str, bool)>, SsdWearWitnessError> {
    let witness = fixture_witness()?;
    let mut axes = Vec::new();
    axes.push((
        "empty_plan_rejected",
        SsdWearBudgetWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "wear_budget_only",
            vec![],
            witness.surfaces.clone(),
            4_000,
            4_500,
            4_750,
            4_250,
        )
        .is_err(),
    ));
    axes.push((
        "empty_surface_rejected",
        SsdWearBudgetWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "wear_budget_only",
            witness.plans.clone(),
            vec![],
            4_000,
            4_500,
            4_750,
            4_250,
        )
        .is_err(),
    ));
    axes.push(("duplicate_plan_rejected", {
        let mut plans = witness.plans.clone();
        plans.push(plans[0].clone());
        make_witness(plans, witness.surfaces.clone()).is_err()
    }));
    axes.push(("duplicate_surface_rejected", {
        let mut surfaces = witness.surfaces.clone();
        surfaces.push(surfaces[0].clone());
        make_witness(witness.plans.clone(), surfaces).is_err()
    }));
    axes.push((
        "duplicate_answer_packet_rejected",
        reject_plans(|plans| plans[1].answer_packet_ref = plans[0].answer_packet_ref.clone()),
    ));
    axes.push((
        "missing_budget_ref_rejected",
        reject_one_plan(|plan| plan.budget_ref = "budget:cpu".to_string()),
    ));
    axes.push((
        "missing_transport_trace_rejected",
        reject_one_plan(|plan| plan.transport_trace_ref = "trace:cpu".to_string()),
    ));
    axes.push((
        "missing_answer_packet_rejected",
        reject_one_plan(|plan| plan.answer_packet_ref = "packet:cpu".to_string()),
    ));
    axes.push((
        "missing_run_event_log_rejected",
        reject_one_plan(|plan| plan.run_event_log_ref = "log:cpu".to_string()),
    ));
    axes.push((
        "missing_rollback_rejected",
        reject_one_plan(|plan| plan.rollback_ref = "undo:cpu".to_string()),
    ));
    axes.push((
        "missing_admission_rejected",
        reject_one_plan(|plan| plan.admission_ref = "gate:cpu".to_string()),
    ));
    axes.push((
        "missing_scope_rex_rejected",
        reject_one_plan(|plan| plan.scope_rex_ref = "scope:cpu".to_string()),
    ));
    axes.push((
        "missing_sovereign_gate_rejected",
        reject_one_plan(|plan| plan.sovereign_gate_ref = "sovereign:cpu".to_string()),
    ));
    axes.push((
        "missing_compatibility_fence_rejected",
        reject_one_plan(|plan| plan.compatibility_fence = "fence:cpu".to_string()),
    ));
    axes.push((
        "missing_cache_policy_rejected",
        reject_one_plan(|plan| plan.cache_policy_ref = "cache:cpu".to_string()),
    ));
    axes.push((
        "missing_surface_ref_rejected",
        reject_one_plan(|plan| plan.answer_packet_ref = "answer_packet:missing".to_string()),
    ));
    axes.push((
        "missing_required_marker_rejected",
        reject_surface(|surface| surface.visible_text = "AnswerPacket only".to_string()),
    ));
    axes.push((
        "forbidden_marker_rejected",
        reject_surface(|surface| surface.visible_text.push_str(" 70B route is live")),
    ));
    axes.push((
        "zero_budget_rejected",
        reject_one_plan(|plan| plan.daily_read_budget_bytes = 0),
    ));
    axes.push((
        "zero_observed_volume_rejected",
        reject_one_plan(|plan| {
            plan.observed_read_bytes = 0;
            plan.observed_write_bytes = 0;
        }),
    ));
    axes.push((
        "daily_read_budget_exceeded_rejected",
        reject_one_plan(|plan| plan.observed_read_bytes = plan.daily_read_budget_bytes + 1),
    ));
    axes.push((
        "daily_write_budget_exceeded_rejected",
        reject_one_plan(|plan| plan.observed_write_bytes = plan.daily_write_budget_bytes + 1),
    ));
    axes.push((
        "burst_read_budget_exceeded_rejected",
        reject_one_plan(|plan| plan.observed_read_bytes = plan.burst_read_budget_bytes + 1),
    ));
    axes.push((
        "burst_write_budget_exceeded_rejected",
        reject_one_plan(|plan| plan.observed_write_bytes = plan.burst_write_budget_bytes + 1),
    ));
    axes.push((
        "energy_budget_exceeded_rejected",
        reject_one_plan(|plan| plan.energy_millijoules = plan.energy_budget_millijoules + 1),
    ));
    axes.push((
        "cache_pollution_budget_exceeded_rejected",
        reject_one_plan(|plan| plan.cache_pollution_bps = plan.cache_pollution_budget_bps + 1),
    ));
    axes.push((
        "write_amplification_rejected",
        reject_one_plan(|plan| {
            plan.write_amplification_bps = MAX_WRITE_AMPLIFICATION_BPS as u32 + 1
        }),
    ));
    axes.push((
        "reuse_horizon_missing_rejected",
        reject_one_plan(|plan| plan.reuse_horizon_ms = 0),
    ));
    axes.push((
        "missing_visible_caveat_rejected",
        reject_one_plan(|plan| plan.visible_wear_caveat = "silent".to_string()),
    ));
    axes.push((
        "missing_visible_summary_rejected",
        reject_one_plan(|plan| plan.user_visible_summary = "silent".to_string()),
    ));
    axes.push((
        "missing_layer_separation_rejected",
        reject_one_plan(|plan| plan.l1_l2_l3_separated = false),
    ));
    axes.push((
        "hidden_route_authority_rejected",
        reject_one_plan(|plan| plan.hidden_route_authority = true),
    ));
    axes.push((
        "route_policy_mutation_rejected",
        reject_one_plan(|plan| plan.route_policy_mutated = true),
    ));
    axes.push((
        "scope_rex_bypass_rejected",
        reject_one_plan(|plan| plan.scope_rex_bypassed = true),
    ));
    axes.push((
        "sovereign_gate_bypass_rejected",
        reject_one_plan(|plan| plan.sovereign_gate_bypassed = true),
    ));
    axes.push((
        "answer_packet_suppression_rejected",
        reject_one_plan(|plan| plan.answer_packet_suppressed = true),
    ));
    axes.push((
        "hidden_chain_rejected",
        reject_one_plan(|plan| plan.user_visible_summary.push_str(" hidden reasoning")),
    ));
    axes.push((
        "hidden_cloud_rejected",
        reject_one_plan(|plan| plan.hidden_cloud_route = true),
    ));
    axes.push((
        "mas_product_build_rejected",
        SsdWearBudgetWitness::new(
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            "wear_budget_only",
            witness.plans.clone(),
            witness.surfaces.clone(),
            4_000,
            4_500,
            4_750,
            4_250,
        )
        .is_err(),
    ));
    axes.push((
        "live_pro_status_rejected",
        SsdWearBudgetWitness::new(
            ProductBuild::Pro,
            ProStatus::Live,
            "wear_budget_only",
            witness.plans.clone(),
            witness.surfaces.clone(),
            4_000,
            4_500,
            4_750,
            4_250,
        )
        .is_err(),
    ));
    axes.push((
        "runtime_bytes_rejected",
        reject_one_plan(|plan| plan.runtime_bytes_loaded = 1),
    ));
    axes.push((
        "model_bytes_rejected",
        reject_one_plan(|plan| plan.model_bytes_loaded = 1),
    ));
    axes.push((
        "unbudgeted_loop_baseline_unbeaten_rejected",
        SsdWearBudgetWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "wear_budget_only",
            witness.plans.clone(),
            witness.surfaces.clone(),
            9_000,
            4_500,
            4_750,
            4_250,
        )
        .is_err(),
    ));
    axes.push((
        "cache_pollution_baseline_unbeaten_rejected",
        SsdWearBudgetWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "wear_budget_only",
            witness.plans.clone(),
            witness.surfaces.clone(),
            4_000,
            9_000,
            4_750,
            4_250,
        )
        .is_err(),
    ));
    axes.push((
        "silent_wear_baseline_unbeaten_rejected",
        SsdWearBudgetWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "wear_budget_only",
            witness.plans.clone(),
            witness.surfaces.clone(),
            4_000,
            4_500,
            9_000,
            4_250,
        )
        .is_err(),
    ));
    axes.push((
        "live_authority_baseline_unbeaten_rejected",
        SsdWearBudgetWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "wear_budget_only",
            witness.plans.clone(),
            witness.surfaces.clone(),
            4_000,
            4_500,
            4_750,
            9_000,
        )
        .is_err(),
    ));
    axes.push((
        "metadata_budget_rejected",
        reject_one_plan(|plan| plan.metadata_bytes = MAX_METADATA_BYTES + 1),
    ));
    Ok(axes)
}

fn make_witness(
    plans: Vec<SsdWearBudgetPlan>,
    surfaces: Vec<SsdWearBudgetSurface>,
) -> Result<SsdWearBudgetWitness, SsdWearBudgetError> {
    SsdWearBudgetWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "wear_budget_only",
        plans,
        surfaces,
        4_000,
        4_500,
        4_750,
        4_250,
    )
}

fn reject_one_plan(mut mutate: impl FnMut(&mut SsdWearBudgetPlan)) -> bool {
    reject_plans(|plans| mutate(&mut plans[0]))
}

fn reject_plans(mut mutate: impl FnMut(&mut Vec<SsdWearBudgetPlan>)) -> bool {
    let witness = fixture_witness().expect("fixture witness");
    let mut plans = witness.plans;
    mutate(&mut plans);
    make_witness(plans, witness.surfaces).is_err()
}

fn reject_surface(mut mutate: impl FnMut(&mut SsdWearBudgetSurface)) -> bool {
    let witness = fixture_witness().expect("fixture witness");
    let mut surfaces = witness.surfaces;
    mutate(&mut surfaces[0]);
    make_witness(witness.plans, surfaces).is_err()
}

// UAS: uas:ssd-wear-budget:evidence-snapshot
// Plane: Verification
// Residency: metadata-only guard/capability/upstream evidence reader.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    transport_trace_pass: bool,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, SsdWearWitnessError> {
        let guard = read_json(GUARD_PATH)?;
        let capability = read_json(CAPABILITY_PATH)?;
        let transport_trace = read_json(TRANSPORT_TRACE_PATH)?;
        Ok(Self {
            guard_next_existing_work: measurement_string(&guard, "next_existing_work")
                .unwrap_or_default(),
            capability_overall_pass: bool_field(&capability, "overall_pass"),
            capability_route_status: measurement_string(&capability, "route_status")
                .unwrap_or_default(),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck")
                .unwrap_or_default(),
            transport_trace_pass: artifact_all_axes_true(
                &transport_trace,
                TRANSPORT_TRACE_ANSWER_PACKET_AXES,
            ),
        })
    }
}

fn read_text(path: &'static str) -> Result<String, SsdWearWitnessError> {
    let resolved = resolve_artifact_path(path);
    std::fs::read_to_string(&resolved).map_err(|error| {
        SsdWearWitnessError::Io(format!("failed to read {}: {error}", resolved.display()))
    })
}

fn read_json(path: &'static str) -> Result<serde_json::Value, SsdWearWitnessError> {
    let text = read_text(path)?;
    serde_json::from_str(&text)
        .map_err(|error| SsdWearWitnessError::Io(format!("failed to parse {path}: {error}")))
}

fn resolve_artifact_path(path: &'static str) -> PathBuf {
    let direct = PathBuf::from(path);
    if direct.exists() {
        return direct;
    }
    Path::new("..").join(path)
}

fn bool_field(value: &serde_json::Value, key: &str) -> bool {
    value
        .get(key)
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
}

fn measurement_string(value: &serde_json::Value, key: &str) -> Option<String> {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(serde_json::Value::as_str)
        .map(str::to_string)
}

fn artifact_all_axes_true(value: &serde_json::Value, axes: &[&str]) -> bool {
    bool_field(value, "overall_pass")
        && axes.iter().all(|axis| {
            value
                .get("pass_per_axis")
                .and_then(|axes| axes.get(*axis))
                .and_then(serde_json::Value::as_bool)
                .unwrap_or(false)
        })
}

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    actual: u64,
    operator: &str,
    expected: u64,
    unit: &str,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::from(actual),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::from(expected),
            unit: unit.to_string(),
        },
    );
    let passed = match operator {
        ">=" => actual >= expected,
        "<=" => actual <= expected,
        "<" => actual < expected,
        ">" => actual > expected,
        "==" => actual == expected,
        _ => false,
    };
    pass_per_axis.insert(axis.to_string(), passed);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_passes_with_current_upstream_evidence() {
        let artifact = build_artifact().expect("artifact");
        assert!(artifact.overall_pass);
        assert_eq!(artifact.falsifier_id, FALSIFIER_ID);
    }

    #[test]
    fn artifact_contains_every_canonical_axis() {
        let artifact = build_artifact().expect("artifact");
        for axis in SSD_WEAR_BUDGET_AXES {
            assert!(
                artifact.pass_per_axis.contains_key(*axis),
                "missing axis {axis}"
            );
            assert!(
                artifact.measurements.contains_key(*axis),
                "missing measurement {axis}"
            );
            assert!(
                artifact.acceptance_thresholds.contains_key(*axis),
                "missing threshold {axis}"
            );
        }
    }

    #[test]
    fn invalid_axes_all_reject() {
        let artifact = build_artifact().expect("artifact");
        for axis in SSD_WEAR_BUDGET_AXES
            .iter()
            .filter(|axis| axis.ends_with("_rejected"))
        {
            assert_eq!(
                artifact.pass_per_axis.get(*axis),
                Some(&true),
                "axis did not reject: {axis}"
            );
        }
    }

    #[test]
    fn over_budget_fixture_rejects_before_artifact_build() {
        assert!(reject_one_plan(|plan| {
            plan.observed_read_bytes = plan.daily_read_budget_bytes + 1;
        }));
        assert!(reject_one_plan(|plan| {
            plan.observed_write_bytes = plan.burst_write_budget_bytes + 1;
        }));
        assert!(reject_one_plan(|plan| {
            plan.cache_pollution_bps = plan.cache_pollution_budget_bps + 1;
        }));
    }
}
