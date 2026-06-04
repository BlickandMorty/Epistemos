//! `falsify_coldstream_vs_mmap`.
//!
//! Metadata-only witness for `F-ColdStream-vs-Mmap`. It proves the benchmark
//! table is same-fixture, source-grounded, AnswerPacket-visible, rollback-safe,
//! and explicitly non-runtime before later platform gates run real mmap/pread
//! or ColdStream transport probes.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[cfg(test)]
use agent_core::falsifier_artifacts::axes::COLDSTREAM_VS_MMAP_AXES;
use agent_core::falsifier_artifacts::axes::SSD_WEAR_BUDGET_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, add_count_eq_axis, current_commit_sha, now_utc_rfc3339, write_artifact,
    AcceptanceThreshold, ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ColdStreamBaselineKind, ColdStreamBaselineRow, ColdStreamVsMmapError, ColdStreamVsMmapFixture,
    ColdStreamVsMmapSurface, ColdStreamVsMmapWitness, ProStatus, ProductBuild,
    COLDSTREAM_VS_MMAP_CURSOR, COLDSTREAM_VS_MMAP_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-ColdStream-vs-Mmap";
const FIXTURE_ID: &str = "coldstream_vs_mmap_v1";
const COMMAND: &str = "Tools/falsifiers/f_coldstream_vs_mmap.sh";
const RESULT: &str = "artifacts/falsifiers/coldstream_vs_mmap/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const SSD_WEAR_PATH: &str = "artifacts/falsifiers/ssd_wear_budget/result.json";
const MIN_FIXTURE_COUNT: u64 = 3;
const MIN_BASELINE_ROW_COUNT: u64 = 9;
const MIN_SURFACE_COUNT: u64 = 3;
const MIN_OFFICIAL_SOURCE_COUNT: u64 = 4;
const MAX_COLDSTREAM_P95_STALL_MS: u64 = 32;
const MAX_COLDSTREAM_P99_STALL_MS: u64 = 42;
const MAX_COLDSTREAM_READ_AMPLIFICATION_BPS: u64 = 11_500;
const MIN_STALL_WIN_BPS: u64 = 1_000;
const MIN_READ_AMPLIFICATION_WIN_BPS: u64 = 500;
const MAX_COPY_COUNT: u64 = 2;
const MIN_CANCELLATION_COUNT: u64 = 3;
const MAX_METADATA_BYTES: u64 = 256 * 1024;

#[derive(Debug)]
// UAS: uas:coldstream-vs-mmap:witness-error
// Plane: Verification
// Residency: metadata-only witness rejection taxonomy.
enum ColdStreamVsMmapWitnessError {
    Primitive(ColdStreamVsMmapError),
    Io(String),
}

impl std::fmt::Display for ColdStreamVsMmapWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for ColdStreamVsMmapWitnessError {}

impl From<ColdStreamVsMmapError> for ColdStreamVsMmapWitnessError {
    fn from(value: ColdStreamVsMmapError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, ColdStreamVsMmapWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fixture_witness()?;
    let metrics = witness.metrics();
    let address = witness.address();
    let mut reversed = witness.fixtures.clone();
    reversed.reverse();
    let deterministic = ColdStreamVsMmapWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "benchmark_plan_only",
        reversed,
        witness.surfaces.clone(),
        witness.official_source_refs.clone(),
        metrics.mmap_fault_baseline_bps,
        metrics.naive_pread_baseline_bps,
        metrics.no_answer_packet_baseline_bps,
        metrics.live_authority_baseline_bps,
    )?
    .address()
        == address;
    let invalid_axes = invalid_fixture_axes()?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        ("upstream_ssd_wear_budget_pass", evidence.ssd_wear_pass),
        (
            "guard_cursor_coldstream_vs_mmap_or_advanced",
            evidence.guard_next_existing_work == COLDSTREAM_VS_MMAP_CURSOR
                || evidence.guard_next_existing_work == COLDSTREAM_VS_MMAP_NEXT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_coldstream_vs_mmap_or_advanced",
            evidence.capability_next_bottleneck == COLDSTREAM_VS_MMAP_CURSOR
                || evidence.capability_next_bottleneck == COLDSTREAM_VS_MMAP_NEXT_CURSOR,
        ),
        (
            "product_status_research_only",
            witness.product_build == ProductBuild::Pro
                && witness.pro_status == ProStatus::ResearchCandidate,
        ),
        (
            "route_authority_benchmark_plan_only",
            witness.route_authority == "benchmark_plan_only",
        ),
        (
            "benchmark_fixtures_bound",
            metrics.fixture_count >= MIN_FIXTURE_COUNT,
        ),
        (
            "baseline_rows_bound",
            metrics.baseline_row_count >= MIN_BASELINE_ROW_COUNT,
        ),
        (
            "visible_surfaces_bound",
            metrics.surface_count >= MIN_SURFACE_COUNT,
        ),
        (
            "answer_packet_refs_bound",
            metrics.answer_packet_count == metrics.fixture_count
                && witness
                    .fixtures
                    .iter()
                    .all(|fixture| fixture.answer_packet_ref.starts_with("answer_packet:")),
        ),
        (
            "run_event_log_refs_bound",
            metrics.run_event_log_count == metrics.fixture_count
                && witness
                    .fixtures
                    .iter()
                    .all(|fixture| fixture.run_event_log_ref.starts_with("run_event_log:")),
        ),
        (
            "benchmark_plan_refs_bound",
            witness
                .fixtures
                .iter()
                .all(|fixture| fixture.benchmark_plan_ref.starts_with("benchmark_plan:")),
        ),
        (
            "rollback_bound",
            witness
                .fixtures
                .iter()
                .all(|fixture| fixture.rollback_ref.starts_with("rollback:")),
        ),
        (
            "admission_bound",
            witness
                .fixtures
                .iter()
                .all(|fixture| fixture.admission_ref.starts_with("admission:")),
        ),
        (
            "scope_rex_bound",
            witness
                .fixtures
                .iter()
                .all(|fixture| fixture.scope_rex_ref.starts_with("scope_rex:")),
        ),
        (
            "sovereign_gate_bound",
            witness
                .fixtures
                .iter()
                .all(|fixture| fixture.sovereign_gate_ref.starts_with("sovereign_gate:")),
        ),
        (
            "compatibility_fence_bound",
            witness
                .fixtures
                .iter()
                .all(|fixture| fixture.compatibility_fence.starts_with("compat:")),
        ),
        (
            "cancel_group_bound",
            witness
                .fixtures
                .iter()
                .all(|fixture| fixture.cancel_group_ref.starts_with("cancel_group:")),
        ),
        (
            "fallback_bound",
            witness
                .fixtures
                .iter()
                .all(|fixture| fixture.fallback_ref.starts_with("fallback:")),
        ),
        (
            "official_sources_bound",
            metrics.official_source_count >= MIN_OFFICIAL_SOURCE_COUNT,
        ),
        (
            "same_fixture_alignment_bound",
            witness.fixtures.iter().all(|fixture| {
                fixture
                    .rows
                    .iter()
                    .all(|row| row.fixture_id == fixture.fixture_id)
            }),
        ),
        (
            "mmap_baseline_present",
            witness.fixtures.iter().all(|fixture| {
                fixture
                    .rows
                    .iter()
                    .any(|row| row.kind == ColdStreamBaselineKind::MmapFault)
            }),
        ),
        (
            "pread_baseline_present",
            witness.fixtures.iter().all(|fixture| {
                fixture
                    .rows
                    .iter()
                    .any(|row| row.kind == ColdStreamBaselineKind::NaivePread)
            }),
        ),
        (
            "coldstream_plan_present",
            witness.fixtures.iter().all(|fixture| {
                fixture
                    .rows
                    .iter()
                    .any(|row| row.kind == ColdStreamBaselineKind::ColdStreamPlan)
            }),
        ),
        (
            "coldstream_beats_mmap_p95_p99",
            metrics.min_mmap_stall_win_bps >= MIN_STALL_WIN_BPS,
        ),
        (
            "coldstream_beats_pread_p95_p99",
            metrics.min_pread_stall_win_bps >= MIN_STALL_WIN_BPS,
        ),
        (
            "coldstream_beats_mmap_read_amplification",
            metrics.min_mmap_read_amplification_win_bps >= MIN_READ_AMPLIFICATION_WIN_BPS,
        ),
        (
            "coldstream_beats_pread_read_amplification",
            metrics.min_pread_read_amplification_win_bps >= MIN_READ_AMPLIFICATION_WIN_BPS,
        ),
        ("copy_count_bound", metrics.max_copy_count <= MAX_COPY_COUNT),
        (
            "cancellation_bound",
            metrics.cancellation_count >= MIN_CANCELLATION_COUNT,
        ),
        (
            "visible_summary_bound",
            witness.fixtures.iter().all(|fixture| {
                let summary = fixture.visible_summary.to_ascii_lowercase();
                summary.contains("metadata-only")
                    && summary.contains("mmap")
                    && summary.contains("pread")
                    && summary.contains("coldstream")
                    && summary.contains("answerpacket")
                    && summary.contains("no live benchmark")
            }),
        ),
        (
            "l1_l2_l3_separation_bound",
            witness
                .fixtures
                .iter()
                .all(|fixture| fixture.l1_l2_l3_separated),
        ),
        (
            "no_hidden_route_authority",
            witness
                .fixtures
                .iter()
                .all(|fixture| !fixture.hidden_route_authority),
        ),
        (
            "no_route_policy_mutation",
            witness
                .fixtures
                .iter()
                .all(|fixture| !fixture.route_policy_mutated),
        ),
        (
            "no_scope_rex_bypass",
            witness
                .fixtures
                .iter()
                .all(|fixture| !fixture.scope_rex_bypassed),
        ),
        (
            "no_sovereign_gate_bypass",
            witness
                .fixtures
                .iter()
                .all(|fixture| !fixture.sovereign_gate_bypassed),
        ),
        (
            "no_answer_packet_suppression",
            witness
                .fixtures
                .iter()
                .all(|fixture| !fixture.answer_packet_suppressed),
        ),
        (
            "no_hidden_chain",
            witness
                .fixtures
                .iter()
                .all(|fixture| !fixture.hidden_chain_exposed),
        ),
        (
            "no_hidden_cloud",
            witness
                .fixtures
                .iter()
                .all(|fixture| !fixture.hidden_cloud_route),
        ),
        (
            "no_ssd_as_ram_claim",
            witness
                .fixtures
                .iter()
                .all(|fixture| !fixture.ssd_as_ram_claimed),
        ),
        (
            "no_live_benchmark_attempted",
            witness
                .fixtures
                .iter()
                .all(|fixture| !fixture.live_benchmark_attempted),
        ),
        ("no_runtime_bytes_loaded", metrics.runtime_bytes_loaded == 0),
        ("no_model_bytes_loaded", metrics.model_bytes_loaded == 0),
        (
            "metadata_bound",
            metrics.max_metadata_bytes <= MAX_METADATA_BYTES,
        ),
        ("coldstream_vs_mmap_address_deterministic", deterministic),
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
        "fixture_count",
        metrics.fixture_count,
        MIN_FIXTURE_COUNT,
        "fixtures",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "baseline_row_count",
        metrics.baseline_row_count,
        MIN_BASELINE_ROW_COUNT,
        "rows",
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
        MIN_FIXTURE_COUNT,
        "packets",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "run_event_log_count",
        metrics.run_event_log_count,
        MIN_FIXTURE_COUNT,
        "logs",
    );
    add_count_eq_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "official_source_count",
        metrics.official_source_count,
        MIN_OFFICIAL_SOURCE_COUNT,
        "sources",
    );

    for (axis, actual, operator, expected, unit) in [
        (
            "max_coldstream_p95_stall_ms",
            metrics.max_coldstream_p95_stall_ms,
            "<=",
            MAX_COLDSTREAM_P95_STALL_MS,
            "ms",
        ),
        (
            "max_coldstream_p99_stall_ms",
            metrics.max_coldstream_p99_stall_ms,
            "<=",
            MAX_COLDSTREAM_P99_STALL_MS,
            "ms",
        ),
        (
            "max_mmap_p99_stall_ms",
            metrics.max_mmap_p99_stall_ms,
            ">",
            metrics.max_coldstream_p99_stall_ms,
            "ms",
        ),
        (
            "max_pread_p99_stall_ms",
            metrics.max_pread_p99_stall_ms,
            ">",
            metrics.max_coldstream_p99_stall_ms,
            "ms",
        ),
        (
            "max_coldstream_read_amplification_bps",
            metrics.max_coldstream_read_amplification_bps,
            "<=",
            MAX_COLDSTREAM_READ_AMPLIFICATION_BPS,
            "bps",
        ),
        (
            "min_mmap_stall_win_bps",
            metrics.min_mmap_stall_win_bps,
            ">=",
            MIN_STALL_WIN_BPS,
            "bps",
        ),
        (
            "min_pread_stall_win_bps",
            metrics.min_pread_stall_win_bps,
            ">=",
            MIN_STALL_WIN_BPS,
            "bps",
        ),
        (
            "min_mmap_read_amplification_win_bps",
            metrics.min_mmap_read_amplification_win_bps,
            ">=",
            MIN_READ_AMPLIFICATION_WIN_BPS,
            "bps",
        ),
        (
            "min_pread_read_amplification_win_bps",
            metrics.min_pread_read_amplification_win_bps,
            ">=",
            MIN_READ_AMPLIFICATION_WIN_BPS,
            "bps",
        ),
        (
            "max_copy_count",
            metrics.max_copy_count,
            "<=",
            MAX_COPY_COUNT,
            "copies",
        ),
        (
            "cancellation_count",
            metrics.cancellation_count,
            ">=",
            MIN_CANCELLATION_COUNT,
            "cancellations",
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
            "mmap_fault_baseline_bps",
            metrics.mmap_fault_baseline_bps,
            "<",
            9_000,
            "bps",
        ),
        (
            "naive_pread_baseline_bps",
            metrics.naive_pread_baseline_bps,
            "<",
            9_000,
            "bps",
        ),
        (
            "no_answer_packet_baseline_bps",
            metrics.no_answer_packet_baseline_bps,
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
        "coldstream_vs_mmap_address".to_string(),
        Measurement {
            value: serde_json::Value::String(address.clone()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "coldstream_vs_mmap_address".to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String("uas:coldstream-vs-mmap:sha256:".to_string()),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert(
        "coldstream_vs_mmap_address".to_string(),
        address.starts_with("uas:coldstream-vs-mmap:sha256:"),
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
            "kind": "metadata_only_coldstream_vs_mmap_benchmark_plan",
            "detail": "Compares mmap-fault, naive pread, and ColdStream planned rows on same synthetic fixtures. It proves benchmark-table shape, visible proof, and safety gates only; no live mmap, pread, Dispatch I/O, Metal I/O, SSD stress, model load, runtime bytes, or product route is proven."
        })],
        notes: "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. F-ColdStream-vs-Mmap is metadata-only: it requires same-fixture mmap/pread/ColdStream benchmark-plan rows, visible p95/p99/read-amplification caveats, rollback, RunEventLog, AnswerPacket proof, and official source grounding before any live transport benchmark can promote. L2 remains red; L3 is unchanged.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();
    Ok(artifact)
}

fn fixture_witness() -> Result<ColdStreamVsMmapWitness, ColdStreamVsMmapWitnessError> {
    Ok(ColdStreamVsMmapWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "benchmark_plan_only",
        fixture_fixtures()?,
        fixture_surfaces()?,
        fixture_sources(),
        4_000,
        4_250,
        4_500,
        4_750,
    )?)
}

fn fixture_sources() -> Vec<String> {
    vec![
        "official_source:apple_mmap".to_string(),
        "official_source:apple_fcntl".to_string(),
        "official_source:apple_dispatch_io".to_string(),
        "official_source:apple_metal_resource_loading".to_string(),
    ]
}

fn fixture_fixtures() -> Result<Vec<ColdStreamVsMmapFixture>, ColdStreamVsMmapError> {
    Ok(vec![
        fixture("cpu", 128 * 1024, 36, 52, 32, 42, 18, 24)?,
        fixture("metal", 192 * 1024, 48, 70, 38, 54, 22, 30)?,
        fixture("mlx", 256 * 1024, 56, 84, 44, 66, 28, 36)?,
    ])
}

#[allow(clippy::too_many_arguments)]
fn fixture(
    suffix: &str,
    bytes: u64,
    mmap_p95: u32,
    mmap_p99: u32,
    pread_p95: u32,
    pread_p99: u32,
    cold_p95: u32,
    cold_p99: u32,
) -> Result<ColdStreamVsMmapFixture, ColdStreamVsMmapError> {
    let fixture_id = format!("fixture-{suffix}");
    let rows = vec![
        row(
            "mmap",
            suffix,
            ColdStreamBaselineKind::MmapFault,
            bytes,
            18_000,
            mmap_p95,
            mmap_p99,
            1,
        )?,
        row(
            "pread",
            suffix,
            ColdStreamBaselineKind::NaivePread,
            bytes,
            14_000,
            pread_p95,
            pread_p99,
            1,
        )?,
        row(
            "coldstream",
            suffix,
            ColdStreamBaselineKind::ColdStreamPlan,
            bytes,
            11_200,
            cold_p95,
            cold_p99,
            2,
        )?,
    ];
    ColdStreamVsMmapFixture::new(
        fixture_id,
        format!("benchmark_plan:{suffix}:coldstream_vs_mmap"),
        format!("answer_packet:{suffix}"),
        format!("run_event_log:{suffix}"),
        format!("rollback:{suffix}"),
        format!("admission:{suffix}"),
        format!("scope_rex:{suffix}"),
        format!("sovereign_gate:{suffix}"),
        format!("compat:{suffix}:coldstream_vs_mmap"),
        format!("cancel_group:{suffix}"),
        format!("fallback:{suffix}:pread_visible"),
        format!("Metadata-only ColdStream vs mmap/pread benchmark plan for {suffix}: p95 and p99 stall, read amplification, AnswerPacket, rollback, and L1/L2/L3 separation are visible; no live benchmark or product promotion is claimed."),
        rows,
        1,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        0,
        0,
        42 * 1024,
    )
}

fn row(
    prefix: &str,
    suffix: &str,
    kind: ColdStreamBaselineKind,
    bytes: u64,
    read_amplification_bps: u32,
    p95_stall_ms: u32,
    p99_stall_ms: u32,
    copy_count: u32,
) -> Result<ColdStreamBaselineRow, ColdStreamVsMmapError> {
    ColdStreamBaselineRow::new(
        format!("{prefix}-{suffix}"),
        format!("fixture-{suffix}"),
        kind,
        bytes,
        bytes * u64::from(read_amplification_bps) / 10_000,
        read_amplification_bps,
        p95_stall_ms,
        p99_stall_ms,
        copy_count,
    )
}

fn fixture_surfaces() -> Result<Vec<ColdStreamVsMmapSurface>, ColdStreamVsMmapError> {
    ["cpu", "metal", "mlx"]
        .into_iter()
        .map(|suffix| {
            ColdStreamVsMmapSurface::new(
                format!("surface-{suffix}"),
                format!("answer_packet:{suffix}"),
                format!("AnswerPacket visible ColdStream vs mmap/pread metadata-only benchmark plan surface {suffix}: p95, p99, read amplification, rollback, cancellation, and L1/L2/L3 separation are visible; no live benchmark and no SSD-as-RAM claim is promoted."),
                vec![
                    "ColdStream".to_string(),
                    "mmap".to_string(),
                    "pread".to_string(),
                    "AnswerPacket".to_string(),
                    "no live benchmark".to_string(),
                ],
                vec![
                    "SSD is RAM".to_string(),
                    "70B route is live".to_string(),
                    "hidden reasoning".to_string(),
                ],
            )
        })
        .collect()
}

fn invalid_fixture_axes() -> Result<Vec<(&'static str, bool)>, ColdStreamVsMmapWitnessError> {
    let witness = fixture_witness()?;
    let mut axes = Vec::new();
    axes.push((
        "empty_fixture_rejected",
        ColdStreamVsMmapWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "benchmark_plan_only",
            vec![],
            witness.surfaces.clone(),
            witness.official_source_refs.clone(),
            4_000,
            4_250,
            4_500,
            4_750,
        )
        .is_err(),
    ));
    axes.push((
        "empty_surface_rejected",
        make_witness(
            witness.fixtures.clone(),
            vec![],
            witness.official_source_refs.clone(),
        )
        .is_err(),
    ));
    axes.push(("duplicate_fixture_rejected", {
        let mut fixtures = witness.fixtures.clone();
        fixtures.push(fixtures[0].clone());
        make_witness(
            fixtures,
            witness.surfaces.clone(),
            witness.official_source_refs.clone(),
        )
        .is_err()
    }));
    axes.push(("duplicate_surface_rejected", {
        let mut surfaces = witness.surfaces.clone();
        surfaces.push(surfaces[0].clone());
        make_witness(
            witness.fixtures.clone(),
            surfaces,
            witness.official_source_refs.clone(),
        )
        .is_err()
    }));
    axes.push((
        "duplicate_answer_packet_rejected",
        reject_fixtures(|fixtures| {
            fixtures[1].answer_packet_ref = fixtures[0].answer_packet_ref.clone()
        }),
    ));
    axes.push((
        "duplicate_baseline_rejected",
        reject_one_fixture(|fixture| fixture.rows.push(fixture.rows[0].clone())),
    ));
    axes.push((
        "missing_mmap_baseline_rejected",
        reject_one_fixture(|fixture| {
            fixture
                .rows
                .retain(|row| row.kind != ColdStreamBaselineKind::MmapFault)
        }),
    ));
    axes.push((
        "missing_pread_baseline_rejected",
        reject_one_fixture(|fixture| {
            fixture
                .rows
                .retain(|row| row.kind != ColdStreamBaselineKind::NaivePread)
        }),
    ));
    axes.push((
        "missing_coldstream_baseline_rejected",
        reject_one_fixture(|fixture| {
            fixture
                .rows
                .retain(|row| row.kind != ColdStreamBaselineKind::ColdStreamPlan)
        }),
    ));
    axes.push((
        "missing_benchmark_plan_rejected",
        reject_one_fixture(|fixture| fixture.benchmark_plan_ref = "plan:cpu".to_string()),
    ));
    axes.push((
        "missing_answer_packet_rejected",
        reject_one_fixture(|fixture| fixture.answer_packet_ref = "packet:cpu".to_string()),
    ));
    axes.push((
        "missing_run_event_log_rejected",
        reject_one_fixture(|fixture| fixture.run_event_log_ref = "log:cpu".to_string()),
    ));
    axes.push((
        "missing_rollback_rejected",
        reject_one_fixture(|fixture| fixture.rollback_ref = "undo:cpu".to_string()),
    ));
    axes.push((
        "missing_admission_rejected",
        reject_one_fixture(|fixture| fixture.admission_ref = "gate:cpu".to_string()),
    ));
    axes.push((
        "missing_scope_rex_rejected",
        reject_one_fixture(|fixture| fixture.scope_rex_ref = "scope:cpu".to_string()),
    ));
    axes.push((
        "missing_sovereign_gate_rejected",
        reject_one_fixture(|fixture| fixture.sovereign_gate_ref = "sovereign:cpu".to_string()),
    ));
    axes.push((
        "missing_compatibility_fence_rejected",
        reject_one_fixture(|fixture| fixture.compatibility_fence = "fence:cpu".to_string()),
    ));
    axes.push((
        "missing_cancel_group_rejected",
        reject_one_fixture(|fixture| fixture.cancel_group_ref = "cancel:cpu".to_string()),
    ));
    axes.push((
        "missing_fallback_rejected",
        reject_one_fixture(|fixture| fixture.fallback_ref = "degrade:cpu".to_string()),
    ));
    axes.push((
        "missing_surface_ref_rejected",
        reject_one_fixture(|fixture| {
            fixture.answer_packet_ref = "answer_packet:missing".to_string()
        }),
    ));
    axes.push((
        "missing_official_source_rejected",
        make_witness(
            witness.fixtures.clone(),
            witness.surfaces.clone(),
            vec!["official_source:apple_mmap".to_string()],
        )
        .is_err(),
    ));
    axes.push((
        "missing_required_marker_rejected",
        reject_surface(|surface| surface.visible_text = "AnswerPacket only".to_string()),
    ));
    axes.push((
        "forbidden_marker_rejected",
        reject_surface(|surface| surface.visible_text.push_str(" SSD is RAM")),
    ));
    axes.push((
        "missing_layer_separation_rejected",
        reject_one_fixture(|fixture| fixture.l1_l2_l3_separated = false),
    ));
    axes.push((
        "missing_visible_summary_rejected",
        reject_one_fixture(|fixture| fixture.visible_summary = "silent".to_string()),
    ));
    axes.push((
        "p99_below_p95_rejected",
        reject_one_row(|row| row.p99_stall_ms = row.p95_stall_ms.saturating_sub(1)),
    ));
    axes.push((
        "zero_bytes_rejected",
        reject_one_row(|row| row.bytes_read = 0),
    ));
    axes.push((
        "read_amplification_rejected",
        reject_one_row(|row| row.read_amplification_bps = 9_999),
    ));
    axes.push((
        "copy_budget_rejected",
        reject_one_coldstream_row(|row| row.copy_count = MAX_COPY_COUNT as u32 + 1),
    ));
    axes.push((
        "cancellation_missing_rejected",
        reject_one_fixture(|fixture| fixture.cancellation_count = 0),
    ));
    axes.push((
        "coldstream_mmap_unbeaten_rejected",
        reject_one_coldstream_row(|row| row.p99_stall_ms = 99),
    ));
    axes.push((
        "coldstream_pread_unbeaten_rejected",
        reject_one_coldstream_row(|row| row.read_amplification_bps = 15_000),
    ));
    axes.push((
        "fixture_id_mismatch_rejected",
        reject_one_row(|row| row.fixture_id = "fixture-mismatch".to_string()),
    ));
    axes.push((
        "hidden_route_authority_rejected",
        reject_one_fixture(|fixture| fixture.hidden_route_authority = true),
    ));
    axes.push((
        "route_policy_mutation_rejected",
        reject_one_fixture(|fixture| fixture.route_policy_mutated = true),
    ));
    axes.push((
        "scope_rex_bypass_rejected",
        reject_one_fixture(|fixture| fixture.scope_rex_bypassed = true),
    ));
    axes.push((
        "sovereign_gate_bypass_rejected",
        reject_one_fixture(|fixture| fixture.sovereign_gate_bypassed = true),
    ));
    axes.push((
        "answer_packet_suppression_rejected",
        reject_one_fixture(|fixture| fixture.answer_packet_suppressed = true),
    ));
    axes.push((
        "hidden_chain_rejected",
        reject_one_fixture(|fixture| fixture.visible_summary.push_str(" hidden reasoning")),
    ));
    axes.push((
        "hidden_cloud_rejected",
        reject_one_fixture(|fixture| fixture.hidden_cloud_route = true),
    ));
    axes.push((
        "ssd_as_ram_rejected",
        reject_one_fixture(|fixture| fixture.ssd_as_ram_claimed = true),
    ));
    axes.push((
        "mas_product_build_rejected",
        ColdStreamVsMmapWitness::new(
            ProductBuild::Mas,
            ProStatus::ResearchCandidate,
            "benchmark_plan_only",
            witness.fixtures.clone(),
            witness.surfaces.clone(),
            witness.official_source_refs.clone(),
            4_000,
            4_250,
            4_500,
            4_750,
        )
        .is_err(),
    ));
    axes.push((
        "live_pro_status_rejected",
        ColdStreamVsMmapWitness::new(
            ProductBuild::Pro,
            ProStatus::Live,
            "benchmark_plan_only",
            witness.fixtures.clone(),
            witness.surfaces.clone(),
            witness.official_source_refs.clone(),
            4_000,
            4_250,
            4_500,
            4_750,
        )
        .is_err(),
    ));
    axes.push((
        "live_benchmark_rejected",
        reject_one_fixture(|fixture| fixture.live_benchmark_attempted = true),
    ));
    axes.push((
        "runtime_bytes_rejected",
        reject_one_fixture(|fixture| fixture.runtime_bytes_loaded = 1),
    ));
    axes.push((
        "model_bytes_rejected",
        reject_one_fixture(|fixture| fixture.model_bytes_loaded = 1),
    ));
    axes.push((
        "mmap_fault_baseline_unbeaten_rejected",
        ColdStreamVsMmapWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "benchmark_plan_only",
            witness.fixtures.clone(),
            witness.surfaces.clone(),
            witness.official_source_refs.clone(),
            9_000,
            4_250,
            4_500,
            4_750,
        )
        .is_err(),
    ));
    axes.push((
        "naive_pread_baseline_unbeaten_rejected",
        ColdStreamVsMmapWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "benchmark_plan_only",
            witness.fixtures.clone(),
            witness.surfaces.clone(),
            witness.official_source_refs.clone(),
            4_000,
            9_000,
            4_500,
            4_750,
        )
        .is_err(),
    ));
    axes.push((
        "no_answer_packet_baseline_unbeaten_rejected",
        ColdStreamVsMmapWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "benchmark_plan_only",
            witness.fixtures.clone(),
            witness.surfaces.clone(),
            witness.official_source_refs.clone(),
            4_000,
            4_250,
            9_000,
            4_750,
        )
        .is_err(),
    ));
    axes.push((
        "live_authority_baseline_unbeaten_rejected",
        ColdStreamVsMmapWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "benchmark_plan_only",
            witness.fixtures.clone(),
            witness.surfaces.clone(),
            witness.official_source_refs.clone(),
            4_000,
            4_250,
            4_500,
            9_000,
        )
        .is_err(),
    ));
    axes.push((
        "metadata_budget_rejected",
        reject_one_fixture(|fixture| fixture.metadata_bytes = MAX_METADATA_BYTES + 1),
    ));
    Ok(axes)
}

fn make_witness(
    fixtures: Vec<ColdStreamVsMmapFixture>,
    surfaces: Vec<ColdStreamVsMmapSurface>,
    sources: Vec<String>,
) -> Result<ColdStreamVsMmapWitness, ColdStreamVsMmapError> {
    ColdStreamVsMmapWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "benchmark_plan_only",
        fixtures,
        surfaces,
        sources,
        4_000,
        4_250,
        4_500,
        4_750,
    )
}

fn reject_one_fixture(mut mutate: impl FnMut(&mut ColdStreamVsMmapFixture)) -> bool {
    reject_fixtures(|fixtures| mutate(&mut fixtures[0]))
}

fn reject_fixtures(mut mutate: impl FnMut(&mut Vec<ColdStreamVsMmapFixture>)) -> bool {
    let witness = fixture_witness().expect("fixture witness");
    let mut fixtures = witness.fixtures;
    mutate(&mut fixtures);
    make_witness(fixtures, witness.surfaces, witness.official_source_refs).is_err()
}

fn reject_one_row(mut mutate: impl FnMut(&mut ColdStreamBaselineRow)) -> bool {
    reject_one_fixture(|fixture| mutate(&mut fixture.rows[0]))
}

fn reject_one_coldstream_row(mut mutate: impl FnMut(&mut ColdStreamBaselineRow)) -> bool {
    reject_one_fixture(|fixture| {
        let row = fixture
            .rows
            .iter_mut()
            .find(|row| row.kind == ColdStreamBaselineKind::ColdStreamPlan)
            .expect("coldstream row");
        mutate(row);
    })
}

fn reject_surface(mut mutate: impl FnMut(&mut ColdStreamVsMmapSurface)) -> bool {
    let witness = fixture_witness().expect("fixture witness");
    let mut surfaces = witness.surfaces;
    mutate(&mut surfaces[0]);
    make_witness(witness.fixtures, surfaces, witness.official_source_refs).is_err()
}

// UAS: uas:coldstream-vs-mmap:evidence-snapshot
// Plane: Verification
// Residency: metadata-only guard/capability/upstream evidence reader.
struct EvidenceSnapshot {
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
    ssd_wear_pass: bool,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, ColdStreamVsMmapWitnessError> {
        let guard = read_json(GUARD_PATH)?;
        let capability = read_json(CAPABILITY_PATH)?;
        let ssd_wear = read_json(SSD_WEAR_PATH)?;
        Ok(Self {
            guard_next_existing_work: measurement_string(&guard, "next_existing_work")
                .unwrap_or_default(),
            capability_overall_pass: bool_field(&capability, "overall_pass"),
            capability_route_status: measurement_string(&capability, "route_status")
                .unwrap_or_default(),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck")
                .unwrap_or_default(),
            ssd_wear_pass: artifact_all_axes_true(&ssd_wear, SSD_WEAR_BUDGET_AXES),
        })
    }
}

fn read_text(path: &'static str) -> Result<String, ColdStreamVsMmapWitnessError> {
    let resolved = resolve_artifact_path(path);
    std::fs::read_to_string(&resolved).map_err(|error| {
        ColdStreamVsMmapWitnessError::Io(format!("failed to read {}: {error}", resolved.display()))
    })
}

fn read_json(path: &'static str) -> Result<serde_json::Value, ColdStreamVsMmapWitnessError> {
    let text = read_text(path)?;
    serde_json::from_str(&text).map_err(|error| {
        ColdStreamVsMmapWitnessError::Io(format!("failed to parse {path}: {error}"))
    })
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
        for axis in COLDSTREAM_VS_MMAP_AXES {
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
        for axis in COLDSTREAM_VS_MMAP_AXES
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
    fn live_benchmark_and_ssd_as_ram_reject_before_artifact_build() {
        assert!(reject_one_fixture(|fixture| fixture
            .live_benchmark_attempted =
            true));
        assert!(reject_one_fixture(
            |fixture| fixture.ssd_as_ram_claimed = true
        ));
        assert!(reject_one_coldstream_row(|row| row.copy_count = 3));
    }
}
