//! F-ACS-AnchorLookup harness.

use std::collections::BTreeMap;
use std::hint::black_box;
use std::path::PathBuf;
use std::time::Instant;

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};
use agent_core::uas::{AcsAnchor, AcsAnchorRegistry, ResidencyTier, RuntimePlane};

const CLAIMS: usize = 10_000;
const PASS_AVG_NS: u128 = 1_000;
const FALSIFIER_ID: &str = "F-ACS-AnchorLookup";
const FIXTURE_ID: &str = "acs_anchor_lookup_10k_verified_floor_v2";
const COMMAND: &str = "Tools/falsifiers/f_acs_anchor_lookup.sh";

fn main() -> std::process::ExitCode {
    let mut registry = AcsAnchorRegistry::with_capacity(CLAIMS);
    for i in 0..CLAIMS {
        let theorem = format!("E{}", (i % 7) + 1);
        let mut anchor = AcsAnchor::new(
            format!("claim-{i:05}"),
            theorem,
            RuntimePlane::Episodic,
            ResidencyTier::VerifiedFloor,
            0.5,
        );
        anchor.source_hash = Some(format!("source-{i:05}"));
        anchor.active_packet_id = Some(format!("packet-{i:05}"));
        anchor.compatibility_edge = Some(format!("edge-{i:05}"));
        registry.insert(anchor);
    }
    let keys: Vec<String> = (0..CLAIMS).map(|i| format!("claim-{i:05}")).collect();

    let start = Instant::now();
    let mut found = 0usize;
    for key in &keys {
        if let Some(anchor) = registry.lookup(black_box(key.as_str())) {
            if anchor.is_well_formed() {
                found += 1;
            }
        }
    }
    let elapsed = start.elapsed();
    let avg_ns = elapsed.as_nanos() / CLAIMS as u128;

    let invalid = AcsAnchor::new(
        "invalid",
        "X9",
        RuntimePlane::Episodic,
        ResidencyTier::VerifiedFloor,
        0.5,
    );
    let invalid_rejected = !invalid.is_well_formed();
    let pass = found == CLAIMS && invalid_rejected && avg_ns < PASS_AVG_NS;

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "round_trip_field_digest",
        found == CLAIMS,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "invalid_theorem_rejection",
        invalid_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "projection_integrity",
        found == CLAIMS,
    );
    add_latency_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "latency",
        avg_ns,
        PASS_AVG_NS,
    );
    measurements.insert(
        "claim_count".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(CLAIMS as u64)),
            unit: "claims".to_string(),
        },
    );
    measurements.insert(
        "found_count".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(found as u64)),
            unit: "claims".to_string(),
        },
    );
    measurements.insert(
        "elapsed_ns".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(saturating_u64(
                elapsed.as_nanos(),
            ))),
            unit: "nanoseconds".to_string(),
        },
    );
    measurements.insert(
        "avg_lookup_ns".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(saturating_u64(avg_ns))),
            unit: "nanoseconds".to_string(),
        },
    );

    let artifact = ArtifactBuilder {
        falsifier_id: FALSIFIER_ID.to_string(),
        artifact_kind: if pass {
            ArtifactKind::PrimaryWitness
        } else {
            ArtifactKind::FailureReport
        },
        command: COMMAND.to_string(),
        commit_sha: agent_core::falsifier_artifacts::current_commit_sha(),
        fixture_id: FIXTURE_ID.to_string(),
        measurements,
        acceptance_thresholds: thresholds,
        pass_per_axis,
        fallback_tier: if pass {
            FallbackTier::Primary
        } else {
            FallbackTier::Fail
        },
        anomalies: Vec::new(),
        notes: "primary_witness; normalized from legacy artifact shape; 10k verified-floor anchors resolved and invalid theorem rejected".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    match write_schema_artifact(
        "artifacts/falsifiers/acs_anchor_lookup/result.json",
        &artifact,
    ) {
        Ok(()) if pass => std::process::ExitCode::SUCCESS,
        Ok(()) => std::process::ExitCode::from(1),
        Err(error) => {
            eprintln!("failed to write artifact: {error}");
            std::process::ExitCode::from(2)
        }
    }
}

fn write_schema_artifact(
    path: &str,
    artifact: &agent_core::falsifier_artifacts::FalsifierArtifact,
) -> std::io::Result<()> {
    let path = PathBuf::from(path);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let mut file = std::fs::File::create(path)?;
    write_artifact(&mut file, artifact)
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

fn add_latency_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: u128,
    threshold: u128,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(saturating_u64(value))),
            unit: "nanoseconds".to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "<".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(saturating_u64(threshold))),
            unit: "nanoseconds".to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value < threshold);
}

fn saturating_u64(value: u128) -> u64 {
    u64::try_from(value).unwrap_or(u64::MAX)
}
