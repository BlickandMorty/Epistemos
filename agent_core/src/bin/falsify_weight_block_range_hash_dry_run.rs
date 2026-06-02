//! `falsify_weight_block_range_hash_dry_run` — bounded model range hashing.
//!
//! This proves the safe range-hash ABI for future real model manifests. It
//! hashes a tiny in-memory fixture, rejects over-limit reads before hashing,
//! and never touches model files, mmap, MLX, Metal, KV, or generation.

use std::collections::BTreeMap;
use std::io::Cursor;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    WeightBlockEncoding, WeightBlockIrChart, WeightBlockManifest, WeightBlockManifestError,
    WeightBlockResidencyClass, RANGE_HASH_CHUNK_BYTES,
};

const FALSIFIER_ID: &str = "F-WeightBlockRangeHash-DryRun";
const FIXTURE_ID: &str = "weight_block_range_hash_tiny_fixture_v1";
const COMMAND: &str = "Tools/falsifiers/f_weight_block_range_hash_dry_run.sh";
const RESULT: &str = "artifacts/falsifiers/weight_block_range_hash_dry_run/result.json";

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
    if let Err(error) = write_artifact(&mut file, &report) {
        eprintln!("failed to write artifact: {error}");
        return std::process::ExitCode::from(2);
    }
    println!(
        "{FALSIFIER_ID}: overall_pass={} artifact={RESULT}",
        report.overall_pass
    );
    if report.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_report(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let fixture: Vec<u8> = (0..8192).map(|i| (i % 251) as u8).collect();
    let start = 257_u64;
    let len = 1536_u64;
    let max_bytes = 2048_u64;
    let mut reader = Cursor::new(fixture.clone());
    let manifest = WeightBlockManifest::from_reader_range(
        "range-hash-dry-run-model",
        "memory://tiny-range-fixture",
        &mut reader,
        start,
        len,
        max_bytes,
        1_779_000_000_000,
        WeightBlockEncoding::Nf4,
        WeightBlockResidencyClass::ColdMmapSsd,
        WeightBlockIrChart::OpaqueWithWitness,
        0.01,
        "falsify_weight_block_range_hash_dry_run",
        Some(agent_core::uas::UasAddress::new(
            agent_core::uas::UasKind::ModelComponent,
            b"dense-rollback-range-fixture",
            1,
        )),
    )?;
    let expected_hash = blake3::hash(&fixture[start as usize..(start + len) as usize]);
    let mut over_limit_reader = Cursor::new(fixture.clone());
    let over_limit_rejected = matches!(
        WeightBlockManifest::from_reader_range(
            "range-hash-dry-run-model",
            "memory://tiny-range-fixture",
            &mut over_limit_reader,
            0,
            4096,
            1024,
            1_779_000_000_000,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::OpaqueWithWitness,
            0.01,
            "falsify_weight_block_range_hash_dry_run",
            None,
        ),
        Err(WeightBlockManifestError::RangeHashLimitExceeded { .. })
    );
    let over_limit_reader_position_unchanged = over_limit_reader.position() == 0;
    let mut short_reader = Cursor::new(vec![1_u8, 2, 3]);
    let short_reader_rejected = matches!(
        WeightBlockManifest::from_reader_range(
            "range-hash-dry-run-model",
            "memory://short-fixture",
            &mut short_reader,
            0,
            1024,
            1024,
            1_779_000_000_000,
            WeightBlockEncoding::Nf4,
            WeightBlockResidencyClass::ColdMmapSsd,
            WeightBlockIrChart::OpaqueWithWitness,
            0.01,
            "falsify_weight_block_range_hash_dry_run",
            None,
        ),
        Err(WeightBlockManifestError::RangeHashIo { .. })
    );
    let known_hash = WeightBlockManifest::from_known_hash_hex(
        "range-hash-dry-run-model",
        "memory://known-hash-fixture",
        start,
        len,
        expected_hash.to_hex().as_str(),
        1_779_000_000_000,
        WeightBlockEncoding::Nf4,
        WeightBlockResidencyClass::ColdMmapSsd,
        WeightBlockIrChart::OpaqueWithWitness,
        0.01,
        "falsify_weight_block_range_hash_dry_run",
        None,
    )?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "bounded_range_hashed",
        manifest.content_hash_hex == expected_hash.to_hex().to_string(),
    );
    add_count_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "range_len_bytes",
        len,
        max_bytes,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "over_limit_rejected_before_read",
        over_limit_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "over_limit_reader_position_unchanged",
        over_limit_reader_position_unchanged,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "short_reader_rejected",
        short_reader_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "known_hash_manifest_valid",
        known_hash.content_hash_hex == manifest.content_hash_hex,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_model_file_touched",
        true,
    );
    measurements.insert(
        "range_hash_chunk_bytes".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(RANGE_HASH_CHUNK_BYTES)),
            unit: "bytes".to_string(),
        },
    );
    measurements.insert(
        "content_hash_hex".to_string(),
        Measurement {
            value: serde_json::Value::String(manifest.content_hash_hex),
            unit: "blake3_hex".to_string(),
        },
    );

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
            "kind": "scope_guard",
            "detail": "tiny in-memory fixture only; no model file, mmap, MLX, Metal, KV, or inference executed"
        })],
        notes: "Validates bounded WeightBlockManifest range hashing; not a model/runtime pass.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build())
}

fn add_bool_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: bool,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::Bool(value),
            unit: "bool".to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "bool".to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value);
}

fn add_count_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: u64,
    max: u64,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(value)),
            unit: "bytes".to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "<=".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(max)),
            unit: "bytes".to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value <= max);
}

#[cfg(test)]
mod tests {
    #[test]
    fn report_is_bounded_and_green() {
        let report = super::build_report().unwrap();
        assert!(report.overall_pass);
        assert_eq!(
            report.pass_per_axis.get("bounded_range_hashed"),
            Some(&true)
        );
        assert_eq!(
            report.pass_per_axis.get("over_limit_rejected_before_read"),
            Some(&true)
        );
        assert_eq!(
            report
                .pass_per_axis
                .get("over_limit_reader_position_unchanged"),
            Some(&true)
        );
        assert_eq!(
            report.pass_per_axis.get("no_model_file_touched"),
            Some(&true)
        );
    }
}
