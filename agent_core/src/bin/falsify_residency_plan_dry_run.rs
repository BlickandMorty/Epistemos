//! `falsify_residency_plan_dry_run` — non-executing active-set gate.
//!
//! This proves the next safe layer above `WeightBlockManifest`: a candidate
//! active set can be budgeted against the M2 Pro 16 GB floor before any
//! model bytes are mmap'd, decoded, or sent to Metal/MLX. It is not a
//! 70B runtime pass; it is the guard that must pass before such probes.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ResidencyBudget, ResidencyPlan, ResidencyPlanStatus, ResidencyPlanViolation, UasAddress,
    UasKind, WeightBlockEncoding, WeightBlockIrChart, WeightBlockManifest,
    WeightBlockResidencyClass, GIB,
};

const FALSIFIER_ID: &str = "F-ResidencyPlan-DryRun";
const FIXTURE_ID: &str = "residency_plan_dry_run_70b_shape_v1";
const COMMAND: &str = "Tools/falsifiers/f_residency_plan_dry_run.sh";

fn main() -> std::process::ExitCode {
    let report = match build_report() {
        Ok(report) => report,
        Err(error) => {
            eprintln!("failed to build {FALSIFIER_ID}: {error}");
            return std::process::ExitCode::from(2);
        }
    };
    let path = PathBuf::from("artifacts/falsifiers/residency_plan_dry_run/result.json");
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
        "{FALSIFIER_ID}: overall_pass={} active_runtime_bytes={} cold_mmap_bytes={} artifact={}",
        report.artifact.overall_pass,
        report.active_runtime_bytes,
        report.cold_mmap_bytes,
        path.display()
    );

    if report.artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

struct ResidencyPlanDryRunReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    active_runtime_bytes: u64,
    cold_mmap_bytes: u64,
}

fn build_report() -> Result<ResidencyPlanDryRunReport, Box<dyn std::error::Error>> {
    let budget = ResidencyBudget::m2_pro_16gb_safety_floor();
    let rollback = UasAddress::new(UasKind::ModelComponent, b"dense-reference-70b", 1);
    let hot = manifest(
        "hot_scan_spine",
        0,
        64 * 1024 * 1024,
        "hot-scan-spine",
        WeightBlockEncoding::DenseBf16,
        WeightBlockResidencyClass::HotUma,
        None,
    )?;
    let warm_sherry = manifest(
        "warm_sherry_gate",
        64 * 1024 * 1024,
        512 * 1024 * 1024,
        "warm-sherry-gate",
        WeightBlockEncoding::Sherry125,
        WeightBlockResidencyClass::WarmCompressedUma,
        Some(rollback.clone()),
    )?;
    let warm_leech = manifest(
        "warm_leech_residual",
        576 * 1024 * 1024,
        256 * 1024 * 1024,
        "warm-leech-residual",
        WeightBlockEncoding::LeechVq,
        WeightBlockResidencyClass::WarmCompressedUma,
        Some(rollback.clone()),
    )?;
    let cold = manifest(
        "cold_nf4_70b_body",
        GIB,
        72 * GIB,
        "cold-nf4-70b-body",
        WeightBlockEncoding::Nf4,
        WeightBlockResidencyClass::ColdMmapSsd,
        Some(rollback),
    )?;

    let plan = ResidencyPlan::evaluate(
        [
            hot.clone(),
            warm_sherry.clone(),
            warm_leech.clone(),
            cold.clone(),
        ],
        budget.clone(),
        1_779_000_000_000,
    );
    let reversed = ResidencyPlan::evaluate(
        [cold.clone(), warm_leech, warm_sherry, hot],
        budget,
        1_779_000_000_000,
    );
    let bad_missing_rollback = manifest(
        "bad_missing_rollback",
        0,
        1024,
        "bad-missing-rollback",
        WeightBlockEncoding::Nf4,
        WeightBlockResidencyClass::ColdMmapSsd,
        None,
    )?;
    let bad_plan = ResidencyPlan::evaluate(
        [bad_missing_rollback],
        ResidencyBudget::m2_pro_16gb_safety_floor(),
        1_779_000_000_000,
    );

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fit_for_dry_run",
        plan.status == ResidencyPlanStatus::FitForDryRun,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "deterministic_plan_address",
        plan.plan_address == reversed.plan_address,
    );
    add_count_le_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_runtime_bytes",
        plan.totals.active_runtime_bytes,
        14 * GIB,
        "bytes",
    );
    add_count_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_mmap_ssd_bytes",
        plan.totals.cold_mmap_ssd_bytes,
        70 * GIB,
        "bytes",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_model_bytes_loaded",
        0,
        0,
        "bytes",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_rollback_rejected",
        bad_plan.violations.iter().any(|v| {
            matches!(v, ResidencyPlanViolation::DenseReferenceMissing { .. })
                && bad_plan.status == ResidencyPlanStatus::RejectedBeforeRuntime
        }),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sherry_and_leech_codec_names_present",
        plan.blocks
            .iter()
            .any(|b| b.canonical_lattice_codec() == "sherry-3-of-4-ternary")
            && plan
                .blocks
                .iter()
                .any(|b| b.canonical_lattice_codec() == "nested-leech-24"),
    );

    measurements.insert(
        "plan_address".to_string(),
        Measurement {
            value: serde_json::Value::String(plan.plan_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    measurements.insert(
        "block_count".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(plan.totals.block_count)),
            unit: "count".to_string(),
        },
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
            "detail": "dry-run planner only; no mmap, decode, MLX, Metal, KV, or 70B inference executed"
        })],
        notes: "Proves budgeted active-set planning over WeightBlockManifest; does not prove live 70B inference.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(ResidencyPlanDryRunReport {
        artifact,
        active_runtime_bytes: plan.totals.active_runtime_bytes,
        cold_mmap_bytes: plan.totals.cold_mmap_ssd_bytes,
    })
}

fn manifest(
    name: &str,
    byte_start: u64,
    byte_len: u64,
    hash_seed: &str,
    encoding: WeightBlockEncoding,
    residency_class: WeightBlockResidencyClass,
    rollback_reference: Option<UasAddress>,
) -> Result<WeightBlockManifest, Box<dyn std::error::Error>> {
    let hash = blake3::hash(hash_seed.as_bytes());
    Ok(WeightBlockManifest::from_known_hash_hex(
        "local/70b-residency-plan-candidate",
        format!("manifest:///local/70b-residency-plan/{name}"),
        byte_start,
        byte_len,
        hash.to_hex().as_str(),
        1_779_000_000_000,
        encoding,
        residency_class,
        WeightBlockIrChart::OpaqueWithWitness,
        0.02,
        "precomputed_hash_plus_dense_reference",
        rollback_reference,
    )?)
}

fn add_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    pass: bool,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Bool(pass),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}

fn add_count_eq_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    expected: u64,
    unit: &str,
) {
    let pass = actual == expected;
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(actual)),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(expected)),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}

fn add_count_le_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    max: u64,
    unit: &str,
) {
    let pass = actual <= max;
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(actual)),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "<=".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(max)),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}

fn add_count_min_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    min: u64,
    unit: &str,
) {
    let pass = actual >= min;
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(actual)),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(min)),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), pass);
}
