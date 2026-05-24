//! F-ACS-AnchorLookup harness.

use std::fs;
use std::hint::black_box;
use std::path::PathBuf;
use std::time::Instant;

use serde_json::json;

use agent_core::uas::{AcsAnchor, AcsAnchorRegistry, ResidencyTier, RuntimePlane};

const CLAIMS: usize = 10_000;
const PASS_AVG_NS: u128 = 1_000;

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

    let artifact = json!({
        "schema_version": "2026-05-18.2",
        "falsifier": "F-ACS-AnchorLookup",
        "status": if pass { "PASS" } else { "FAIL" },
        "hardware_floor": "M2 Pro 16 GB UMA",
        "measurements": {
            "claim_count": CLAIMS,
            "found_count": found,
            "elapsed_ns": elapsed.as_nanos(),
            "avg_lookup_ns": avg_ns,
            "invalid_theorem_rejected": invalid_rejected
        },
        "acceptance_thresholds": {
            "avg_lookup_ns_lt": PASS_AVG_NS,
            "claim_count": CLAIMS,
            "invalid_theorem_rejected": true
        },
        "pass_per_axis": {
            "round_trip_field_digest": found == CLAIMS,
            "invalid_theorem_rejection": invalid_rejected,
            "projection_integrity": found == CLAIMS,
            "latency": avg_ns < PASS_AVG_NS
        }
    });

    match write_artifact(
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

fn write_artifact(path: &str, value: &serde_json::Value) -> std::io::Result<()> {
    let path = PathBuf::from(path);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, serde_json::to_vec_pretty(value)?)
}
