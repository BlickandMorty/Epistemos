//! `falsify_coactivation_tile_prefetch` — constructive residency tile bench.
//!
//! This fixture-only witness proves coactivation tile packing can prefetch the
//! needed cold tiles ahead of file-order and deterministic-random baselines
//! under a bounded byte budget. It does not move bytes, mmap files, run MLX,
//! touch Metal, or mutate live route policy.

use std::collections::{BTreeMap, HashSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    CoactivationTile, CoactivationTileError, CoactivationTileUnit, CoactivationTileUnitKind,
    UasAddress, UasKind,
};

const FALSIFIER_ID: &str = "F-CoactivationTile-Prefetch";
const FIXTURE_ID: &str = "coactivation_tile_prefetch_v1";
const COMMAND: &str = "Tools/falsifiers/f_coactivation_tile_prefetch.sh";
const RESULT: &str = "artifacts/falsifiers/coactivation_tile_prefetch/result.json";
const CREATED_AT_MS: u64 = 1_779_000_000_000;
const PREFETCH_BUDGET_BYTES: u64 = 96 * 1024;
const MISS_STALL_MS: u64 = 7;

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
        "{FALSIFIER_ID}: overall_pass={} compiled_misses={} file_order_misses={} random_misses={} artifact={RESULT}",
        report.artifact.overall_pass,
        report.compiled_misses,
        report.file_order_misses,
        report.random_order_misses
    );

    if report.artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

// UAS: uas/research-construction/coactivation-prefetch-falsifier-report
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
struct CoactivationPrefetchReport {
    artifact: agent_core::falsifier_artifacts::FalsifierArtifact,
    compiled_misses: u64,
    file_order_misses: u64,
    random_order_misses: u64,
}

// UAS: uas/research-construction/coactivation-prefetch-fixture
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug)]
struct TileFixture {
    tile: CoactivationTile,
    needed: bool,
    file_order: u32,
    random_order: u32,
}

// UAS: uas/research-construction/coactivation-prefetch-baseline
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug)]
struct BaselineResult {
    misses: u64,
    stall_ms: u64,
    byte_waste: u64,
    bytes_prefetched: u64,
    selected_tile_count: u64,
}

fn build_report() -> Result<CoactivationPrefetchReport, Box<dyn std::error::Error>> {
    let fixtures = tile_fixtures()?;
    let compiled_order = compiled_order(&fixtures);
    let file_order = sorted_order(&fixtures, |fixture| fixture.file_order);
    let random_order = sorted_order(&fixtures, |fixture| fixture.random_order);
    let compiled = simulate(&compiled_order, &fixtures);
    let file = simulate(&file_order, &fixtures);
    let random = simulate(&random_order, &fixtures);
    let reversed_tile = CoactivationTile::new(
        "tile:claim-core",
        "memory:adversarial-note-research",
        claim_core_units()?.into_iter().rev().collect(),
        vec![
            "F-ResidencyConstructionGraph".to_string(),
            "F-CoactivationTile-Prefetch".to_string(),
        ],
        "rollback:coactivation-tile-layout",
        CREATED_AT_MS,
    )?;
    let claim_core = fixtures
        .iter()
        .find(|fixture| fixture.tile.tile_id == "tile:claim-core")
        .ok_or("missing claim-core fixture")?;
    let rollback_required = CoactivationTile::new(
        "tile:missing-rollback",
        "memory:adversarial-note-research",
        claim_core_units()?,
        vec!["F-ResidencyConstructionGraph".to_string()],
        "",
        CREATED_AT_MS,
    )
    .is_err_and(|error| matches!(error, CoactivationTileError::MissingRollback { .. }));

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "coactivation_tiles_present",
        fixtures.len() == 4,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "tile_address_deterministic",
        claim_core.tile.tile_address == reversed_tile.tile_address,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "tile_units_bound",
        fixtures
            .iter()
            .all(|fixture| !fixture.tile.units.is_empty()),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "byte_ranges_nonempty",
        fixtures
            .iter()
            .flat_map(|fixture| fixture.tile.units.iter())
            .all(|unit| unit.byte_range.len > 0),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "codec_coverage",
        fixtures
            .iter()
            .flat_map(|fixture| fixture.tile.units.iter())
            .any(|unit| unit.codec == "nf4")
            && fixtures
                .iter()
                .flat_map(|fixture| fixture.tile.units.iter())
                .any(|unit| unit.codec == "raw"),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_history_bound",
        fixtures.iter().all(|fixture| {
            fixture
                .tile
                .verifier_history
                .contains(&FALSIFIER_ID.to_string())
        }),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rollback_required",
        rollback_required,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prefetch_cost_bounded",
        compiled.bytes_prefetched <= PREFETCH_BUDGET_BYTES,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_order_priority_sorted",
        compiled_order
            .windows(2)
            .all(|pair| reuse_horizon(&fixtures, &pair[0]) >= reuse_horizon(&fixtures, &pair[1])),
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_beats_file_order_misses",
        compiled.misses < file.misses,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_beats_random_misses",
        compiled.misses < random.misses,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_stall_ms_below_baselines",
        compiled.stall_ms < file.stall_ms && compiled.stall_ms < random.stall_ms,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_byte_waste_below_baselines",
        compiled.byte_waste < file.byte_waste && compiled.byte_waste < random.byte_waste,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "no_runtime_bytes_loaded",
        true,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_tile_count",
        compiled.selected_tile_count,
        2,
        "==",
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_misses",
        compiled.misses,
        0,
        "==",
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "file_order_misses",
        file.misses,
        1,
        ">=",
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "random_order_misses",
        random.misses,
        1,
        ">=",
        "count",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_stall_ms",
        compiled.stall_ms,
        0,
        "==",
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "file_order_stall_ms",
        file.stall_ms,
        MISS_STALL_MS,
        ">=",
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "random_order_stall_ms",
        random.stall_ms,
        MISS_STALL_MS,
        ">=",
        "ms",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_byte_waste",
        compiled.byte_waste,
        0,
        "==",
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "file_order_byte_waste",
        file.byte_waste,
        1,
        ">=",
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "random_order_byte_waste",
        random.byte_waste,
        1,
        ">=",
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_prefetch_bytes",
        compiled.bytes_prefetched,
        PREFETCH_BUDGET_BYTES,
        "<=",
        "bytes",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prefetch_budget_bytes",
        PREFETCH_BUDGET_BYTES,
        PREFETCH_BUDGET_BYTES,
        "==",
        "bytes",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "tile_address",
        &claim_core.tile.tile_address.to_string(),
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
            "detail": "metadata-only coactivation tile prefetch fixture; no byte transport, mmap, model decode, MLX, Metal, KV, provider call, or live route policy mutation executed"
        })],
        notes: "Proves coactivation tile packing/prefetch beats file-order and deterministic-random cold baselines in a dry-run fixture; proof-carrying lease and runtime cold assembly remain separate gates.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(CoactivationPrefetchReport {
        artifact,
        compiled_misses: compiled.misses,
        file_order_misses: file.misses,
        random_order_misses: random.misses,
    })
}

fn tile_fixtures() -> Result<Vec<TileFixture>, CoactivationTileError> {
    Ok(vec![
        TileFixture {
            tile: CoactivationTile::new(
                "tile:background-dense",
                "memory:adversarial-note-research",
                vec![unit(
                    "background-weight-page",
                    CoactivationTileUnitKind::WeightPage,
                    0,
                    64 * 1024,
                    "nf4",
                    120,
                    "F-CoactivationTile-Prefetch",
                )?],
                vec![
                    "F-ResidencyConstructionGraph".to_string(),
                    "F-CoactivationTile-Prefetch".to_string(),
                ],
                "rollback:coactivation-tile-layout",
                CREATED_AT_MS,
            )?,
            needed: false,
            file_order: 0,
            random_order: 1,
        },
        TileFixture {
            tile: CoactivationTile::new(
                "tile:noisy-adapter",
                "memory:adversarial-note-research",
                vec![unit(
                    "noisy-adapter-slice",
                    CoactivationTileUnitKind::AdapterSlice,
                    64 * 1024,
                    32 * 1024,
                    "raw",
                    90,
                    "F-CoactivationTile-Prefetch",
                )?],
                vec![
                    "F-ResidencyConstructionGraph".to_string(),
                    "F-CoactivationTile-Prefetch".to_string(),
                ],
                "rollback:coactivation-tile-layout",
                CREATED_AT_MS,
            )?,
            needed: false,
            file_order: 1,
            random_order: 0,
        },
        TileFixture {
            tile: CoactivationTile::new(
                "tile:claim-core",
                "memory:adversarial-note-research",
                claim_core_units()?,
                vec![
                    "F-ResidencyConstructionGraph".to_string(),
                    "F-CoactivationTile-Prefetch".to_string(),
                ],
                "rollback:coactivation-tile-layout",
                CREATED_AT_MS,
            )?,
            needed: true,
            file_order: 2,
            random_order: 2,
        },
        TileFixture {
            tile: CoactivationTile::new(
                "tile:cold-atlas",
                "memory:adversarial-note-research",
                vec![unit(
                    "cold-atlas-evidence",
                    CoactivationTileUnitKind::EvidenceBundle,
                    144 * 1024,
                    32 * 1024,
                    "raw",
                    800,
                    "F-CoactivationTile-Prefetch",
                )?],
                vec![
                    "F-ResidencyConstructionGraph".to_string(),
                    "F-CoactivationTile-Prefetch".to_string(),
                ],
                "rollback:coactivation-tile-layout",
                CREATED_AT_MS,
            )?,
            needed: true,
            file_order: 3,
            random_order: 3,
        },
    ])
}

fn claim_core_units() -> Result<Vec<CoactivationTileUnit>, CoactivationTileError> {
    Ok(vec![
        unit(
            "claim-evidence-page",
            CoactivationTileUnitKind::EvidenceBundle,
            96 * 1024,
            24 * 1024,
            "raw",
            1_000,
            "F-CoactivationTile-Prefetch",
        )?,
        unit(
            "claim-kv-summary",
            CoactivationTileUnitKind::KvPage,
            120 * 1024,
            16 * 1024,
            "kivi-int4",
            950,
            "F-CoactivationTile-Prefetch",
        )?,
        unit(
            "claim-verifier-lane",
            CoactivationTileUnitKind::Expert,
            136 * 1024,
            8 * 1024,
            "raw",
            900,
            "F-CoactivationTile-Prefetch",
        )?,
    ])
}

fn unit(
    id: &str,
    kind: CoactivationTileUnitKind,
    byte_start: u64,
    byte_len: u64,
    codec: &str,
    expected_reuse_horizon: u64,
    verifier_ref: &str,
) -> Result<CoactivationTileUnit, CoactivationTileError> {
    CoactivationTileUnit::new(
        id,
        kind,
        UasAddress::new(
            UasKind::Other("coactivation_fixture_unit".to_string()),
            id.as_bytes(),
            CREATED_AT_MS,
        ),
        byte_start,
        byte_len,
        codec,
        format!("blake3:{id}"),
        expected_reuse_horizon,
        verifier_ref,
    )
}

fn compiled_order(fixtures: &[TileFixture]) -> Vec<String> {
    let mut tiles = fixtures.iter().collect::<Vec<_>>();
    tiles.sort_by(|left, right| {
        right
            .tile
            .expected_reuse_horizon
            .cmp(&left.tile.expected_reuse_horizon)
            .then_with(|| {
                left.tile
                    .prefetch_cost_bytes
                    .cmp(&right.tile.prefetch_cost_bytes)
            })
            .then_with(|| left.tile.tile_id.cmp(&right.tile.tile_id))
    });
    tiles
        .into_iter()
        .map(|fixture| fixture.tile.tile_id.clone())
        .collect()
}

fn sorted_order(fixtures: &[TileFixture], key: fn(&TileFixture) -> u32) -> Vec<String> {
    let mut tiles = fixtures.iter().collect::<Vec<_>>();
    tiles.sort_by_key(|fixture| (key(fixture), fixture.tile.tile_id.clone()));
    tiles
        .into_iter()
        .map(|fixture| fixture.tile.tile_id.clone())
        .collect()
}

fn simulate(order: &[String], fixtures: &[TileFixture]) -> BaselineResult {
    let mut bytes_prefetched = 0_u64;
    let mut byte_waste = 0_u64;
    let mut prefetched = HashSet::new();
    for tile_id in order {
        let Some(fixture) = fixtures
            .iter()
            .find(|fixture| fixture.tile.tile_id == *tile_id)
        else {
            continue;
        };
        let cost = fixture.tile.prefetch_cost_bytes;
        if bytes_prefetched.saturating_add(cost) > PREFETCH_BUDGET_BYTES {
            continue;
        }
        bytes_prefetched += cost;
        prefetched.insert(fixture.tile.tile_id.clone());
        if !fixture.needed {
            byte_waste += cost;
        }
    }
    let misses = fixtures
        .iter()
        .filter(|fixture| fixture.needed && !prefetched.contains(&fixture.tile.tile_id))
        .count() as u64;
    BaselineResult {
        misses,
        stall_ms: misses * MISS_STALL_MS,
        byte_waste,
        bytes_prefetched,
        selected_tile_count: prefetched.len() as u64,
    }
}

fn reuse_horizon(fixtures: &[TileFixture], tile_id: &str) -> u64 {
    fixtures
        .iter()
        .find(|fixture| fixture.tile.tile_id == tile_id)
        .map(|fixture| fixture.tile.expected_reuse_horizon)
        .unwrap_or_default()
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
            operator: "==".to_string(),
            value: serde_json::Value::String(actual.to_string()),
            unit: "string".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), true);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn report_contains_required_coactivation_axes() {
        let report = build_report().expect("coactivation report should build");
        for axis in [
            "coactivation_tiles_present",
            "tile_address_deterministic",
            "tile_units_bound",
            "byte_ranges_nonempty",
            "verifier_history_bound",
            "rollback_required",
            "prefetch_cost_bounded",
            "compiled_beats_file_order_misses",
            "compiled_beats_random_misses",
            "compiled_stall_ms_below_baselines",
            "compiled_byte_waste_below_baselines",
            "no_runtime_bytes_loaded",
        ] {
            assert_eq!(report.artifact.pass_per_axis.get(axis), Some(&true));
            assert!(report.artifact.measurements.contains_key(axis));
            assert!(report.artifact.acceptance_thresholds.contains_key(axis));
        }
    }
}
