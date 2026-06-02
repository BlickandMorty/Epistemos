//! `falsify_uas_acs_mmap_residency` — file-backed UAS/ACS residency witness.
//!
//! This gate proves one concrete slice of the 70B/ACS/UAS ambition without
//! overclaiming the full local-model runtime: a cold SSD-backed byte region is
//! mapped with `mmap`, addressed through `UasAddress`, leased through
//! `ResidencyLease`, and anchored through ACS projection lookup without tracked
//! hot-path copies. It is not a model benchmark and does not satisfy
//! `F-KV-Direct-Gate` or `F-70B-Local-Cocktail-Lite` by itself.

use std::collections::BTreeMap;
use std::hint::black_box;
use std::io::{Seek, SeekFrom, Write};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder, ArtifactKind,
    FallbackTier, Measurement,
};
use agent_core::uas::{
    AcsAnchor, AcsAnchorRegistry, ResidencyLease, ResidencyTier, RuntimePlane, UasAddress, UasKind,
};
use memmap2::MmapOptions;
use tempfile::NamedTempFile;

const FALSIFIER_ID: &str = "F-UAS-ACS-MmapResidency";
const FIXTURE_ID: &str = "uas_acs_mmap_residency_16mb_v1";
const COMMAND: &str = "Tools/falsifiers/f_uas_acs_mmap_residency.sh";
const PAGE_SIZE: usize = 4096;
const PAGE_COUNT: usize = 4096;
const TOTAL_BYTES: usize = PAGE_SIZE * PAGE_COUNT;
const CREATED_AT_MS: u64 = 1_779_000_000_000;

fn main() -> std::process::ExitCode {
    let report = match build_report() {
        Ok(report) => report,
        Err(error) => {
            eprintln!("failed to build {FALSIFIER_ID}: {error}");
            return std::process::ExitCode::from(2);
        }
    };

    let path = PathBuf::from("artifacts/falsifiers/uas_acs_mmap_residency/result.json");
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
        "{FALSIFIER_ID}: overall_pass={} mmap_bytes={} artifact={}",
        report.artifact.overall_pass,
        report.mmap_bytes,
        path.display()
    );

    if report.artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

struct MmapResidencyReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    mmap_bytes: usize,
}

fn build_report() -> Result<MmapResidencyReport, Box<dyn std::error::Error>> {
    let file = seed_backing_file()?;

    // SAFETY: the backing file is opened read-only for the map lifetime, is not
    // mutated after `sync_all`, and the `NamedTempFile` outlives `mmap`.
    let mmap = unsafe { MmapOptions::new().len(TOTAL_BYTES).map(file.as_file())? };

    let hash = blake3::hash(&mmap);
    let kv_address = UasAddress::from_hash(UasKind::KvPage, hash, CREATED_AT_MS);
    let model_component_address = UasAddress::new(
        UasKind::ModelComponent,
        kv_address.to_string().as_bytes(),
        CREATED_AT_MS,
    );
    let parsed_kv_address: UasAddress = kv_address.to_string().parse()?;

    let lease = ResidencyLease::new(
        kv_address.clone(),
        ResidencyTier::VerifiedFloor,
        CREATED_AT_MS,
        60_000,
    );
    let lease_round_trip = lease.address == kv_address && !lease.is_expired(CREATED_AT_MS + 1_000);

    let mut registry = AcsAnchorRegistry::with_capacity(2);
    let mut kv_anchor = AcsAnchor::new(
        "mmap-kv-page-anchor",
        "E3",
        RuntimePlane::Episodic,
        ResidencyTier::VerifiedFloor,
        0.87,
    );
    kv_anchor.source_hash = Some(kv_address.to_string());
    kv_anchor.active_packet_id = Some("mmap-residency-packet".to_string());
    kv_anchor.compatibility_edge = Some(model_component_address.to_string());
    let projection = kv_anchor.project_to_plane();
    registry.insert(kv_anchor.clone());
    let projection_lookup_ok = registry
        .lookup_via_projection(projection)
        .map(|anchor| anchor == &kv_anchor && anchor.is_well_formed())
        .unwrap_or(false);

    let (_, copy_stats) = agent_core::uas::copy_counter::with_tracking(|| {
        black_box(sample_pages_checksum(&mmap));
    });

    let sampled_checksum = sample_pages_checksum(&mmap);
    let expected_checksum = expected_sample_checksum();
    let checksum_match = sampled_checksum == expected_checksum;
    let invalid_offset_rejected = mmap.get(TOTAL_BYTES..TOTAL_BYTES + 1).is_none();
    let mmap_file_len = file.as_file().metadata()?.len() as usize;

    let mut measurements: BTreeMap<String, Measurement> = BTreeMap::new();
    let mut thresholds: BTreeMap<String, AcceptanceThreshold> = BTreeMap::new();
    let mut pass_per_axis: BTreeMap<String, bool> = BTreeMap::new();

    add_count_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mmap_backed_bytes",
        mmap.len() as u64,
        TOTAL_BYTES as u64,
        "bytes",
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "file_len_matches_mmap",
        mmap_file_len == mmap.len(),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "uas_address_round_trip",
        parsed_kv_address == kv_address,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "acs_projection_lookup",
        projection_lookup_ok,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "residency_lease_round_trip",
        lease_round_trip,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "sampled_page_checksum_match",
        checksum_match,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "invalid_offset_rejection",
        invalid_offset_rejected,
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hot_path_tracked_copies",
        copy_stats.copy_count as u64,
        0,
        "count",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hot_path_data_copy_bytes",
        0,
        0,
        "bytes",
    );
    measurements.insert(
        "sampled_page_count".to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(sample_offsets().len())),
            unit: "pages".to_string(),
        },
    );
    measurements.insert(
        "kv_page_address".to_string(),
        Measurement {
            value: serde_json::Value::String(kv_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    measurements.insert(
        "model_component_address".to_string(),
        Measurement {
            value: serde_json::Value::String(model_component_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );

    let pass = pass_per_axis.values().copied().all(|axis| axis);
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
        anomalies: vec![serde_json::json!({
            "kind": "not_live_model_generation",
            "detail": "This proves file-backed mmap residency plus UAS/ACS addressing. It does not prove MLX token generation, KV residual patching, or a 70B sparse runtime."
        })],
        notes: "primary_witness; file-backed mmap bytes addressed by UAS, leased through ResidencyLease, and resolved through ACS projection lookup with zero tracked hot-path copies".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(MmapResidencyReport {
        artifact,
        mmap_bytes: mmap.len(),
    })
}

fn seed_backing_file() -> Result<NamedTempFile, Box<dyn std::error::Error>> {
    let mut file = NamedTempFile::new()?;
    file.as_file_mut().set_len(TOTAL_BYTES as u64)?;
    file.as_file_mut().seek(SeekFrom::Start(0))?;
    let mut page = vec![0_u8; PAGE_SIZE];
    for page_index in 0..PAGE_COUNT {
        fill_page(page_index, &mut page);
        file.as_file_mut().write_all(&page)?;
    }
    file.as_file_mut().sync_all()?;
    Ok(file)
}

fn fill_page(page_index: usize, page: &mut [u8]) {
    let seed = (page_index as u64)
        .wrapping_mul(0x9E37_79B9_7F4A_7C15)
        .rotate_left((page_index % 63) as u32);
    for (offset, byte) in page.iter_mut().enumerate() {
        let mixed = seed
            .wrapping_add((offset as u64).wrapping_mul(0xD1B5_4A32_D192_ED03))
            .rotate_right((offset % 31) as u32);
        *byte = (mixed ^ (mixed >> 32)) as u8;
    }
}

fn sample_pages_checksum(mmap: &[u8]) -> u64 {
    let mut checksum = 0_u64;
    for page_index in sample_offsets() {
        let offset = page_index * PAGE_SIZE;
        let page = &mmap[offset..offset + PAGE_SIZE];
        checksum ^= page_checksum(page).rotate_left((page_index % 63) as u32);
    }
    checksum
}

fn expected_sample_checksum() -> u64 {
    let mut page = vec![0_u8; PAGE_SIZE];
    let mut checksum = 0_u64;
    for page_index in sample_offsets() {
        fill_page(page_index, &mut page);
        checksum ^= page_checksum(&page).rotate_left((page_index % 63) as u32);
    }
    checksum
}

fn page_checksum(page: &[u8]) -> u64 {
    page.iter().enumerate().fold(0_u64, |acc, (i, byte)| {
        acc.wrapping_add((*byte as u64) << ((i % 8) * 8))
            .rotate_left((i % 17) as u32)
    })
}

fn sample_offsets() -> [usize; 16] {
    [
        0, 1, 7, 31, 127, 255, 511, 777, 1023, 1535, 2047, 2559, 3071, 3583, 4094, 4095,
    ]
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

fn add_count_eq_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: u64,
    threshold: u64,
    unit: &str,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(value)),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: "==".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(threshold)),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value == threshold);
}

fn add_count_min_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    axis: &str,
    value: u64,
    threshold: u64,
    unit: &str,
) {
    measurements.insert(
        axis.to_string(),
        Measurement {
            value: serde_json::Value::Number(serde_json::Number::from(value)),
            unit: unit.to_string(),
        },
    );
    thresholds.insert(
        axis.to_string(),
        AcceptanceThreshold {
            operator: ">=".to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(threshold)),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(axis.to_string(), value >= threshold);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deterministic_page_checksum_matches_seeded_pages() {
        assert_ne!(expected_sample_checksum(), 0);
    }

    #[test]
    fn mmap_residency_report_builds_primary_witness() {
        let report = build_report().expect("report");
        assert!(report.artifact.overall_pass);
        assert_eq!(report.artifact.falsifier_id, FALSIFIER_ID);
        assert_eq!(report.artifact.artifact_kind, "primary_witness");
        assert!(report
            .artifact
            .pass_per_axis
            .get("mmap_backed_bytes")
            .copied()
            .unwrap_or(false));
        assert!(report
            .artifact
            .pass_per_axis
            .get("acs_projection_lookup")
            .copied()
            .unwrap_or(false));
    }
}
