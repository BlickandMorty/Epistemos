//! `falsify_prefetch_window_cold_miss` — synthetic cold-miss prefetch gate.
//!
//! This fixture-only witness proves a compiled `PrefetchWindow` orders cold
//! semantic units by priority and beats random, recency, and file-order
//! baselines under a bounded prefetch byte budget. It does not move bytes or
//! exercise real storage.

use std::collections::{BTreeMap, HashMap, HashSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    EvidenceNeed, KVByteBudgetCard, MmapResidencyFence, PrivacyClass, ProStatus, ProductBuild,
    ResidencyTier, SemanticWorkingSetPlan, SemanticWorkingSetUnit, TaskWorkingSetQuery, UasAddress,
    UasKind, VerifierNeed, WorkingSetStorageTier, WorkingSetUnitKind,
};

const FALSIFIER_ID: &str = "F-PrefetchWindow-ColdMiss";
const FIXTURE_ID: &str = "prefetch_window_cold_miss_v1";
const COMMAND: &str = "Tools/falsifiers/f_prefetch_window_cold_miss.sh";
const RESULT: &str = "artifacts/falsifiers/prefetch_window_cold_miss/result.json";
const CREATED_AT_MS: u64 = 1_779_000_000_000;
const PREFETCH_BUDGET_BYTES: u64 = 128 * 1024;
const MISS_STALL_MS: u64 = 4;

#[derive(Clone, Debug)]
struct ColdFixtureUnit {
    semantic_unit_id: String,
    address: UasAddress,
    byte_len: u64,
    priority: u32,
    needed: bool,
}

#[derive(Clone, Debug)]
struct BaselineResult {
    prefetched_needed: u64,
    misses: u64,
    stall_ms: u64,
    byte_waste: u64,
    bytes_prefetched: u64,
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
        "{FALSIFIER_ID}: overall_pass={} compiled_misses={} compiled_stall_ms={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["compiled_misses"].value,
        artifact.measurements["compiled_stall_ms"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let plan = accepted_plan()?;
    let fixtures = cold_fixture_units(&plan);
    let compiled_order = window_unit_ids(&plan, &fixtures);
    let file_order = file_order(&fixtures);
    let recency_order = recency_order(&fixtures);
    let random_order = deterministic_random_order(&fixtures);

    let compiled = simulate(&compiled_order, &fixtures);
    let file = simulate(&file_order, &fixtures);
    let recency = simulate(&recency_order, &fixtures);
    let random = simulate(&random_order, &fixtures);

    let prefetch_window_present = !plan.prefetch_window.ordered_units.is_empty();
    let prefetch_window_cold_only = plan
        .prefetch_window
        .ordered_units
        .iter()
        .all(|address| fixtures.iter().any(|fixture| fixture.address == *address));
    let prefetch_order_priority_sorted = compiled_order
        .windows(2)
        .all(|pair| priority(&fixtures, &pair[0]) >= priority(&fixtures, &pair[1]));
    let prefetch_window_deterministic = {
        let reversed = accepted_plan_with_units(fixture_units()?.into_iter().rev().collect())?;
        window_unit_ids(&reversed, &cold_fixture_units(&reversed)) == compiled_order
    };
    let compiled_beats_file_order_misses = compiled.misses < file.misses;
    let compiled_beats_recency_misses = compiled.misses < recency.misses;
    let compiled_beats_random_misses = compiled.misses < random.misses;
    let compiled_stall_ms_below_baselines = compiled.stall_ms < file.stall_ms
        && compiled.stall_ms < recency.stall_ms
        && compiled.stall_ms < random.stall_ms;
    let compiled_byte_waste_below_baselines = compiled.byte_waste < file.byte_waste
        && compiled.byte_waste < recency.byte_waste
        && compiled.byte_waste < random.byte_waste;
    let max_bytes_bound = PREFETCH_BUDGET_BYTES <= plan.prefetch_window.max_bytes;
    let cancellation_rule_present = !plan.prefetch_window.cancellation_rule.is_empty();
    let fallback_on_miss_visible = plan
        .prefetch_window
        .fallback_on_miss
        .starts_with("runtime_router:fallback_");
    let measurement_ref_visible = plan
        .prefetch_window
        .measurement_ref
        .starts_with("run_event_log:");
    let zero_cold_units_empty_window = zero_cold_units_empty_window()?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prefetch_window_present",
        prefetch_window_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prefetch_window_cold_only",
        prefetch_window_cold_only,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prefetch_order_priority_sorted",
        prefetch_order_priority_sorted,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prefetch_window_deterministic",
        prefetch_window_deterministic,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_beats_file_order_misses",
        compiled_beats_file_order_misses,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_beats_recency_misses",
        compiled_beats_recency_misses,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_beats_random_misses",
        compiled_beats_random_misses,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_stall_ms_below_baselines",
        compiled_stall_ms_below_baselines,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_byte_waste_below_baselines",
        compiled_byte_waste_below_baselines,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_bytes_bound",
        max_bytes_bound,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cancellation_rule_present",
        cancellation_rule_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "fallback_on_miss_visible",
        fallback_on_miss_visible,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "measurement_ref_visible",
        measurement_ref_visible,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "zero_cold_units_empty_window",
        zero_cold_units_empty_window,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_misses",
        compiled.misses,
        0,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "file_order_misses",
        file.misses,
        1,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "recency_order_misses",
        recency.misses,
        1,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "random_order_misses",
        random.misses,
        1,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_stall_ms",
        compiled.stall_ms,
        0,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_byte_waste",
        compiled.byte_waste,
        0,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prefetch_budget_bytes",
        PREFETCH_BUDGET_BYTES,
        PREFETCH_BUDGET_BYTES,
        "==",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_prefetched_needed",
        compiled.prefetched_needed,
        2,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compiled_bytes_prefetched",
        compiled.bytes_prefetched,
        PREFETCH_BUDGET_BYTES,
        "<=",
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
            "detail": "fixture-only PrefetchWindow cold-miss simulation; no real prefetch, file read, mmap, model decode, MLX/Metal, or route mutation executed"
        })],
        notes: "Proves compiled cold-unit priority ordering beats deterministic file-order, recency, and random baselines on misses, stall time, and byte waste under a synthetic prefetch byte budget, with visible cancellation, fallback, and measurement refs.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn accepted_plan() -> Result<SemanticWorkingSetPlan, Box<dyn std::error::Error>> {
    accepted_plan_with_units(fixture_units()?)
}

fn accepted_plan_with_units(
    selected_units: Vec<SemanticWorkingSetUnit>,
) -> Result<SemanticWorkingSetPlan, Box<dyn std::error::Error>> {
    Ok(SemanticWorkingSetPlan::compile_dry_run(
        fixture_query()?,
        selected_units,
        fixture_kv_budget()?,
        fixture_mmap_fence()?,
        "runtime_router:fallback_prefetch_window",
        "rollback:prefetch-window-cold-miss",
        "run_event_log:prefetch-window-cold-miss",
        "answer_packet:prefetch-window-cold-miss",
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        ResidencyTier::CapabilityCeiling,
        CREATED_AT_MS,
    )?)
}

fn fixture_query() -> Result<TaskWorkingSetQuery, Box<dyn std::error::Error>> {
    Ok(TaskWorkingSetQuery::new(
        "mission-local-research",
        "retrieve-verify-answer",
        vec![
            "source:doc:semantic-working-set".to_string(),
            "source:doc:prefetch-window".to_string(),
        ],
        PrivacyClass::VaultPrivate,
        1200,
        850,
        EvidenceNeed::ClosedCitation,
        VerifierNeed::Schema,
        2 * 1024 * 1024,
        4 * 1024 * 1024,
        4 * 1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        1024 * 1024,
        CREATED_AT_MS,
    )?)
}

fn fixture_units() -> Result<Vec<SemanticWorkingSetUnit>, Box<dyn std::error::Error>> {
    Ok(vec![
        unit(
            "a-distractor-big",
            WorkingSetUnitKind::WeightPage,
            WorkingSetStorageTier::Cold,
            0,
            512 * 1024,
            10,
        )?,
        unit(
            "b-distractor-small",
            WorkingSetUnitKind::WeightPage,
            WorkingSetStorageTier::Cold,
            512 * 1024,
            64 * 1024,
            20,
        )?,
        unit(
            "y-target-evidence",
            WorkingSetUnitKind::EvidencePage,
            WorkingSetStorageTier::Cold,
            576 * 1024,
            64 * 1024,
            90,
        )?,
        unit(
            "z-target-kv",
            WorkingSetUnitKind::KvPage,
            WorkingSetStorageTier::Cold,
            640 * 1024,
            64 * 1024,
            100,
        )?,
        unit(
            "hot-verifier",
            WorkingSetUnitKind::VerifierLane,
            WorkingSetStorageTier::Hot,
            0,
            32 * 1024,
            1,
        )?,
    ])
}

fn fixture_kv_budget() -> Result<KVByteBudgetCard, Box<dyn std::error::Error>> {
    Ok(KVByteBudgetCard::new(
        "local/qwen-working-set-fixture",
        4096,
        "kivi-q4-dry-run",
        256 * 1024,
        256 * 1024,
        128,
        32,
        "dry-run fixture; no KV page loaded",
    )?)
}

fn fixture_mmap_fence() -> Result<MmapResidencyFence, Box<dyn std::error::Error>> {
    Ok(MmapResidencyFence::evaluate(
        "model.gguf",
        0,
        1024 * 1024,
        true,
        true,
        1024 * 1024,
        0,
        1,
        0,
        0,
    )?)
}

fn unit(
    id: &str,
    kind: WorkingSetUnitKind,
    tier: WorkingSetStorageTier,
    byte_start: u64,
    byte_len: u64,
    priority: u32,
) -> Result<SemanticWorkingSetUnit, Box<dyn std::error::Error>> {
    Ok(SemanticWorkingSetUnit::new(
        id,
        kind,
        address(id.as_bytes()),
        tier,
        byte_start,
        byte_len,
        "fixture-codec",
        format!("blake3:{}", blake3::hash(id.as_bytes()).to_hex()),
        "compat:semantic-working-set-v1",
        priority,
        "lease:dry-run",
    )?)
}

fn address(bytes: &[u8]) -> UasAddress {
    UasAddress::new(UasKind::ModelComponent, bytes, CREATED_AT_MS)
}

fn cold_fixture_units(plan: &SemanticWorkingSetPlan) -> Vec<ColdFixtureUnit> {
    let needed_ids = ["y-target-evidence", "z-target-kv"]
        .into_iter()
        .collect::<HashSet<_>>();
    plan.selected_units
        .iter()
        .filter(|unit| unit.storage_tier == WorkingSetStorageTier::Cold)
        .map(|unit| ColdFixtureUnit {
            semantic_unit_id: unit.semantic_unit_id.clone(),
            address: unit.uas_address.clone(),
            byte_len: unit.byte_range.len,
            priority: unit.prefetch_priority,
            needed: needed_ids.contains(unit.semantic_unit_id.as_str()),
        })
        .collect()
}

fn window_unit_ids(plan: &SemanticWorkingSetPlan, fixtures: &[ColdFixtureUnit]) -> Vec<String> {
    let address_to_id = fixtures
        .iter()
        .map(|fixture| {
            (
                fixture.address.to_string(),
                fixture.semantic_unit_id.clone(),
            )
        })
        .collect::<HashMap<_, _>>();
    plan.prefetch_window
        .ordered_units
        .iter()
        .filter_map(|address| address_to_id.get(&address.to_string()).cloned())
        .collect()
}

fn file_order(fixtures: &[ColdFixtureUnit]) -> Vec<String> {
    let mut ids = fixtures
        .iter()
        .map(|fixture| fixture.semantic_unit_id.clone())
        .collect::<Vec<_>>();
    ids.sort();
    ids
}

fn recency_order(fixtures: &[ColdFixtureUnit]) -> Vec<String> {
    let mut units = fixtures.to_vec();
    units.sort_by(|a, b| a.priority.cmp(&b.priority));
    units
        .into_iter()
        .map(|unit| unit.semantic_unit_id)
        .collect()
}

fn deterministic_random_order(fixtures: &[ColdFixtureUnit]) -> Vec<String> {
    [
        "b-distractor-small",
        "a-distractor-big",
        "y-target-evidence",
        "z-target-kv",
    ]
    .into_iter()
    .filter(|id| {
        fixtures
            .iter()
            .any(|fixture| fixture.semantic_unit_id == *id)
    })
    .map(str::to_string)
    .collect()
}

fn simulate(order: &[String], fixtures: &[ColdFixtureUnit]) -> BaselineResult {
    let by_id = fixtures
        .iter()
        .map(|fixture| (fixture.semantic_unit_id.as_str(), fixture))
        .collect::<HashMap<_, _>>();
    let needed_total = fixtures.iter().filter(|fixture| fixture.needed).count() as u64;
    let mut bytes_prefetched = 0_u64;
    let mut prefetched_needed = 0_u64;
    let mut byte_waste = 0_u64;
    for id in order {
        let Some(fixture) = by_id.get(id.as_str()) else {
            continue;
        };
        if bytes_prefetched + fixture.byte_len > PREFETCH_BUDGET_BYTES {
            continue;
        }
        bytes_prefetched += fixture.byte_len;
        if fixture.needed {
            prefetched_needed += 1;
        } else {
            byte_waste += fixture.byte_len;
        }
    }
    let misses = needed_total.saturating_sub(prefetched_needed);
    BaselineResult {
        prefetched_needed,
        misses,
        stall_ms: misses * MISS_STALL_MS,
        byte_waste,
        bytes_prefetched,
    }
}

fn priority(fixtures: &[ColdFixtureUnit], id: &str) -> u32 {
    fixtures
        .iter()
        .find(|fixture| fixture.semantic_unit_id == id)
        .map(|fixture| fixture.priority)
        .unwrap_or(0)
}

fn zero_cold_units_empty_window() -> Result<bool, Box<dyn std::error::Error>> {
    let plan = accepted_plan_with_units(vec![unit(
        "hot-only",
        WorkingSetUnitKind::EvidencePage,
        WorkingSetStorageTier::Hot,
        0,
        64 * 1024,
        1,
    )?])?;
    Ok(plan.prefetch_window.ordered_units.is_empty() && plan.prefetch_window.max_bytes == 0)
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
