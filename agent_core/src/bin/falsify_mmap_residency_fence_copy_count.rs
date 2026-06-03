//! `falsify_mmap_residency_fence_copy_count` — mmap accounting fence.
//!
//! This fixture-only witness proves mmap mapping, touching, resident estimate,
//! faults, copy count, and counted-hot bytes remain separate labels. It does
//! not mmap a real model file or benchmark SSD/RAM behavior.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{MmapResidencyFence, SemanticWorkingSetError};

const FALSIFIER_ID: &str = "F-MmapResidencyFence-CopyCount";
const FIXTURE_ID: &str = "mmap_residency_fence_copy_count_v1";
const COMMAND: &str = "Tools/falsifiers/f_mmap_residency_fence_copy_count.sh";
const RESULT: &str = "artifacts/falsifiers/mmap_residency_fence_copy_count/result.json";

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
        "{FALSIFIER_ID}: overall_pass={} resident_estimate_bytes={} copy_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["resident_estimate_bytes"].value,
        artifact.measurements["copy_count"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let passing = MmapResidencyFence::evaluate(
        "fixture-model-page",
        4096,
        64 * 1024,
        true,
        true,
        64 * 1024,
        1,
        2,
        3,
        64 * 1024,
    )?;
    let mapped_untouched = MmapResidencyFence::evaluate(
        "fixture-model-page",
        4096,
        64 * 1024,
        true,
        false,
        64 * 1024,
        0,
        2,
        0,
        64 * 1024,
    )?;
    let under_resident = MmapResidencyFence::evaluate(
        "fixture-model-page",
        4096,
        64 * 1024,
        true,
        true,
        32 * 1024,
        0,
        2,
        0,
        64 * 1024,
    )?;
    let unmapped_counted_hot = MmapResidencyFence::evaluate(
        "fixture-model-page",
        4096,
        64 * 1024,
        false,
        false,
        0,
        0,
        0,
        0,
        64 * 1024,
    )?;
    let cold_only = MmapResidencyFence::evaluate(
        "fixture-model-page",
        4096,
        64 * 1024,
        false,
        false,
        0,
        0,
        0,
        0,
        0,
    )?;

    let mapped_touched_resident_passes = passing.mapped && passing.touched && passing.pass_or_fail;
    let mapped_untouched_counted_hot_fails =
        mapped_untouched.mapped && !mapped_untouched.touched && !mapped_untouched.pass_or_fail;
    let under_resident_counted_hot_fails =
        under_resident.resident_estimate < 64 * 1024 && !under_resident.pass_or_fail;
    let unmapped_counted_hot_fails =
        !unmapped_counted_hot.mapped && !unmapped_counted_hot.pass_or_fail;
    let cold_unmapped_zero_hot_passes =
        !cold_only.mapped && !cold_only.touched && cold_only.pass_or_fail;
    let resident_estimate_reported = passing.resident_estimate == 64 * 1024;
    let faults_reported = passing.major_faults == 1 && passing.minor_faults == 2;
    let copy_count_reported = passing.copy_count == 3;
    let copy_count_not_hot_bytes = passing.copy_count != passing.resident_estimate;
    let byte_range_bound = passing.byte_range.start == 4096 && passing.byte_range.len == 64 * 1024;
    let invalid_byte_range_rejected = invalid_byte_range_rejected()?;
    let missing_file_id_rejected = missing_file_id_rejected()?;
    let pass_requires_mapped_touched_resident = mapped_touched_resident_passes
        && mapped_untouched_counted_hot_fails
        && under_resident_counted_hot_fails
        && unmapped_counted_hot_fails;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mapped_touched_resident_passes",
        mapped_touched_resident_passes,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mapped_untouched_counted_hot_fails",
        mapped_untouched_counted_hot_fails,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "under_resident_counted_hot_fails",
        under_resident_counted_hot_fails,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unmapped_counted_hot_fails",
        unmapped_counted_hot_fails,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_unmapped_zero_hot_passes",
        cold_unmapped_zero_hot_passes,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "resident_estimate_reported",
        resident_estimate_reported,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "faults_reported",
        faults_reported,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "copy_count_reported",
        copy_count_reported,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "copy_count_not_hot_bytes",
        copy_count_not_hot_bytes,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "byte_range_bound",
        byte_range_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "invalid_byte_range_rejected",
        invalid_byte_range_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_file_id_rejected",
        missing_file_id_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "pass_requires_mapped_touched_resident",
        pass_requires_mapped_touched_resident,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "resident_estimate_bytes",
        passing.resident_estimate,
        64 * 1024,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "major_faults",
        passing.major_faults,
        1,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "minor_faults",
        passing.minor_faults,
        2,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "copy_count",
        passing.copy_count,
        3,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "byte_range_len",
        passing.byte_range.len,
        64 * 1024,
        "==",
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
            "detail": "fixture-only mmap residency fence; no mmap call, page-fault probe, SSD/RAM benchmark, model decode, MLX/Metal, or route mutation executed"
        })],
        notes: "Proves mmap mapping, touching, resident estimate, faults, copy count, and counted-hot bytes remain separate fixture labels; counted-hot bytes fail unless mapped, touched, and resident, while cold uncounted bytes do not claim hot residency.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn invalid_byte_range_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error =
        MmapResidencyFence::evaluate("fixture-model-page", 4096, 0, true, true, 0, 0, 0, 0, 0)
            .unwrap_err();
    Ok(matches!(error, SemanticWorkingSetError::InvalidByteRange))
}

fn missing_file_id_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error =
        MmapResidencyFence::evaluate("", 4096, 64 * 1024, true, true, 0, 0, 0, 0, 0).unwrap_err();
    Ok(matches!(error, SemanticWorkingSetError::MissingFileId))
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

fn add_u64_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    expected: u64,
    operator: &str,
) {
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(actual)),
            unit: "count_or_bytes".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(expected)),
            unit: "count_or_bytes".to_string(),
        },
    );
    let pass = match operator {
        "<=" => actual <= expected,
        ">=" => actual >= expected,
        "==" => actual == expected,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), pass);
}
