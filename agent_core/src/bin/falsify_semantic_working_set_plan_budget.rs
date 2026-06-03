//! `falsify_semantic_working_set_plan_budget` — schema-only working-set gate.
//!
//! This is a metadata-only witness for the June 1 Semantic Working-Set
//! Compiler bundle. It proves a mission-shaped support set can be budgeted,
//! page-tabled, and rejected before runtime without waking model bytes,
//! mmap'ing files, running MLX/Metal, or mutating live route policy.

use std::collections::BTreeMap;
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    EvidenceNeed, KVByteBudgetCard, MmapResidencyFence, PrivacyClass, ProStatus, ProductBuild,
    ResidencyTier, SemanticWorkingSetPlan, SemanticWorkingSetPlanStatus, SemanticWorkingSetUnit,
    SemanticWorkingSetViolation, TaskWorkingSetQuery, UasAddress, UasKind, VerifierNeed,
    WorkingSetStorageTier, WorkingSetUnitKind,
};

const FALSIFIER_ID: &str = "F-SemanticWorkingSetPlan-Budget";
const FIXTURE_ID: &str = "semantic_working_set_plan_budget_v1";
const COMMAND: &str = "Tools/falsifiers/f_semantic_working_set_plan_budget.sh";
const RESULT: &str = "artifacts/falsifiers/semantic_working_set_plan_budget/result.json";
const CREATED_AT_MS: u64 = 1_779_000_000_000;

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
        "{FALSIFIER_ID}: overall_pass={} selected_unit_count={} active_executed_bytes={} kv_bytes={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["selected_unit_count"].value,
        artifact.measurements["active_executed_bytes"].value,
        artifact.measurements["kv_bytes"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let accepted = accepted_plan()?;
    let reversed = SemanticWorkingSetPlan::compile_dry_run(
        accepted.query.clone(),
        accepted.selected_units.iter().cloned().rev().collect(),
        fixture_kv_budget()?,
        fixture_mmap_fence(0, true, true)?,
        "runtime_router:fallback_static_route",
        "rollback:semantic-working-set-plan-budget",
        "run_event_log:semantic-working-set-plan-budget",
        "answer_packet:semantic-working-set-plan-budget",
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        ResidencyTier::CapabilityCeiling,
        CREATED_AT_MS,
    )?;
    let reordered_query = fixture_query_with_sources(vec![
        "source:docs/falsifiers/F-SEMANTIC-WORKING-SET-COMPILER-BUNDLE_2026_06_01.md".to_string(),
        "source:docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md".to_string(),
    ])?;
    let over_budget = SemanticWorkingSetPlan::compile_dry_run(
        fixture_query(32 * 1024, 64 * 1024)?,
        vec![unit(
            "kv-hot-over-budget",
            WorkingSetUnitKind::KvPage,
            UasKind::KvPage,
            WorkingSetStorageTier::Hot,
            0,
            128 * 1024,
            10,
        )?],
        fixture_kv_budget()?,
        fixture_mmap_fence(0, true, true)?,
        "runtime_router:fallback_static_route",
        "rollback:semantic-working-set-plan-budget",
        "run_event_log:semantic-working-set-plan-budget",
        "answer_packet:semantic-working-set-plan-budget",
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        ResidencyTier::CapabilityCeiling,
        CREATED_AT_MS,
    )?;
    let live_route = SemanticWorkingSetPlan::compile_dry_run(
        fixture_query(2 * 1024 * 1024, 4 * 1024 * 1024)?,
        fixture_units()?,
        fixture_kv_budget()?,
        fixture_mmap_fence(0, true, true)?,
        "runtime_router:live_semantic_working_set",
        "rollback:semantic-working-set-plan-budget",
        "run_event_log:semantic-working-set-plan-budget",
        "answer_packet:semantic-working-set-plan-budget",
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        ResidencyTier::CapabilityCeiling,
        CREATED_AT_MS,
    )?;
    let mas_promotion = SemanticWorkingSetPlan::compile_dry_run(
        fixture_query(2 * 1024 * 1024, 4 * 1024 * 1024)?,
        fixture_units()?,
        fixture_kv_budget()?,
        fixture_mmap_fence(0, true, true)?,
        "runtime_router:fallback_static_route",
        "rollback:semantic-working-set-plan-budget",
        "run_event_log:semantic-working-set-plan-budget",
        "answer_packet:semantic-working-set-plan-budget",
        ProductBuild::Mas,
        ProStatus::Live,
        ResidencyTier::CurrentApp,
        CREATED_AT_MS,
    )?;
    let bad_mmap = SemanticWorkingSetPlan::compile_dry_run(
        fixture_query(2 * 1024 * 1024, 4 * 1024 * 1024)?,
        vec![unit(
            "mapped-hot-weight",
            WorkingSetUnitKind::WeightPage,
            UasKind::ModelComponent,
            WorkingSetStorageTier::Hot,
            0,
            64 * 1024,
            10,
        )?],
        fixture_kv_budget()?,
        fixture_mmap_fence(64 * 1024, true, false)?,
        "runtime_router:fallback_static_route",
        "rollback:semantic-working-set-plan-budget",
        "run_event_log:semantic-working-set-plan-budget",
        "answer_packet:semantic-working-set-plan-budget",
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        ResidencyTier::CapabilityCeiling,
        CREATED_AT_MS,
    )?;

    let task_query_deterministic = accepted.query.query_address == reordered_query.query_address;
    let plan_address_deterministic = accepted.plan_address == reversed.plan_address;
    let accepted_plan_fit_for_dry_run =
        accepted.status == SemanticWorkingSetPlanStatus::FitForDryRun;
    let over_budget_rejected_before_runtime = over_budget.status
        == SemanticWorkingSetPlanStatus::RejectedBeforeRuntime
        && over_budget.violations.iter().any(|violation| {
            matches!(
                violation,
                SemanticWorkingSetViolation::HotBudgetExceeded { .. }
            )
        })
        && over_budget.violations.iter().any(|violation| {
            matches!(
                violation,
                SemanticWorkingSetViolation::KvBudgetExceeded { .. }
            )
        });
    let page_table_addressability = accepted.page_table.iter().all(|entry| {
        !entry.semantic_unit_id.is_empty()
            && !entry.codec.is_empty()
            && entry.checksum.starts_with("blake3:")
            && entry.compatibility_fence.starts_with("compat:")
            && entry.byte_range.len > 0
    });
    let kv_budget_separate = accepted.totals.kv_bytes > accepted.kv_budget.kv_bytes_predicted
        && accepted.totals.kv_bytes != accepted.totals.cold_bytes
        && accepted.kv_budget.prompt_cache_hit_tokens > accepted.kv_budget.prompt_cache_miss_tokens;
    let mmap_mapped_untouched_not_hot = bad_mmap.violations.iter().any(|violation| {
        matches!(
            violation,
            SemanticWorkingSetViolation::MmapMappedButNotResident
        )
    });
    let hidden_live_route_rejected = live_route.violations.iter().any(|violation| {
        matches!(
            violation,
            SemanticWorkingSetViolation::HiddenLiveRouteAuthority { .. }
        )
    });
    let mas_live_promotion_rejected = mas_promotion.violations.iter().any(|violation| {
        matches!(
            violation,
            SemanticWorkingSetViolation::ProductBuildStatusMismatch
        )
    });
    let run_event_log_visible = accepted
        .run_event_log_visibility
        .starts_with("run_event_log:");
    let answer_packet_visible = accepted
        .answer_packet_visibility
        .starts_with("answer_packet:");
    let rollback_present = accepted.rollback_ref.starts_with("rollback:");

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "task_query_deterministic",
        task_query_deterministic,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "plan_address_deterministic",
        plan_address_deterministic,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "accepted_plan_fit_for_dry_run",
        accepted_plan_fit_for_dry_run,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "over_budget_rejected_before_runtime",
        over_budget_rejected_before_runtime,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "page_table_addressability",
        page_table_addressability,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_budget_separate",
        kv_budget_separate,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mmap_mapped_untouched_not_hot",
        mmap_mapped_untouched_not_hot,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hidden_live_route_rejected",
        hidden_live_route_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "mas_live_promotion_rejected",
        mas_live_promotion_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "run_event_log_visible",
        run_event_log_visible,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "answer_packet_visible",
        answer_packet_visible,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "rollback_present",
        rollback_present,
    );

    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_unit_count",
        accepted.selected_units.len() as u64,
        1,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hot_bytes",
        accepted.totals.hot_bytes,
        accepted.query.max_hot_bytes,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "warm_bytes",
        accepted.totals.warm_bytes,
        accepted.query.max_hot_bytes,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_bytes",
        accepted.totals.cold_bytes,
        accepted.query.max_cold_io_bytes,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "active_executed_bytes",
        accepted.totals.active_executed_bytes,
        accepted.query.max_hot_bytes,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "kv_bytes",
        accepted.totals.kv_bytes,
        accepted.query.max_kv_bytes,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "adapter_bytes",
        accepted.totals.adapter_bytes,
        accepted.query.max_adapter_bytes,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "evidence_bytes",
        accepted.totals.evidence_bytes,
        accepted.query.max_evidence_bytes,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "verifier_bytes",
        accepted.totals.verifier_bytes,
        accepted.query.max_verifier_bytes,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "scratch_bytes",
        accepted.totals.scratch_bytes,
        accepted.query.max_scratch_bytes,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_io_bytes",
        accepted.totals.cold_io_bytes,
        accepted.query.max_cold_io_bytes,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_miss_count",
        u64::from(accepted.totals.cold_miss_count),
        4,
        "<=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_cache_hit_tokens",
        u64::from(accepted.totals.prompt_cache_hit_tokens),
        1,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prompt_cache_miss_tokens",
        u64::from(accepted.totals.prompt_cache_miss_tokens),
        512,
        "<=",
    );

    measurements.insert(
        "plan_address".to_string(),
        Measurement {
            value: serde_json::Value::String(accepted.plan_address.to_string()),
            unit: "uas_address".to_string(),
        },
    );
    thresholds.insert(
        "plan_address".to_string(),
        AcceptanceThreshold {
            operator: "non_empty".to_string(),
            value: serde_json::Value::Bool(true),
            unit: "uas_address".to_string(),
        },
    );
    pass_per_axis.insert("plan_address".to_string(), true);

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
            "detail": "schema-only SemanticWorkingSetPlan; no mmap, model decode, MLX, Metal, KV restore, route mutation, or 70B runtime executed"
        })],
        notes: "Proves mission-shaped working-set budget rejection, page-table addressability, KV accounting, mmap-hotness fence, visible witness refs, and rollback refs as a dry run only.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn accepted_plan() -> Result<SemanticWorkingSetPlan, Box<dyn std::error::Error>> {
    Ok(SemanticWorkingSetPlan::compile_dry_run(
        fixture_query(2 * 1024 * 1024, 4 * 1024 * 1024)?,
        fixture_units()?,
        fixture_kv_budget()?,
        fixture_mmap_fence(0, true, true)?,
        "runtime_router:fallback_static_route",
        "rollback:semantic-working-set-plan-budget",
        "run_event_log:semantic-working-set-plan-budget",
        "answer_packet:semantic-working-set-plan-budget",
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        ResidencyTier::CapabilityCeiling,
        CREATED_AT_MS,
    )?)
}

fn fixture_query(
    max_hot_bytes: u64,
    max_kv_bytes: u64,
) -> Result<TaskWorkingSetQuery, Box<dyn std::error::Error>> {
    fixture_query_with_sources_and_budgets(
        vec![
            "source:docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md".to_string(),
            "source:docs/falsifiers/F-SEMANTIC-WORKING-SET-COMPILER-BUNDLE_2026_06_01.md"
                .to_string(),
        ],
        max_hot_bytes,
        max_kv_bytes,
    )
}

fn fixture_query_with_sources(
    source_refs: Vec<String>,
) -> Result<TaskWorkingSetQuery, Box<dyn std::error::Error>> {
    fixture_query_with_sources_and_budgets(source_refs, 2 * 1024 * 1024, 4 * 1024 * 1024)
}

fn fixture_query_with_sources_and_budgets(
    source_refs: Vec<String>,
    max_hot_bytes: u64,
    max_kv_bytes: u64,
) -> Result<TaskWorkingSetQuery, Box<dyn std::error::Error>> {
    Ok(TaskWorkingSetQuery::new(
        "mission-local-research",
        "retrieve-verify-answer",
        source_refs,
        PrivacyClass::VaultPrivate,
        1200,
        850,
        EvidenceNeed::ClosedCitation,
        VerifierNeed::Schema,
        max_hot_bytes,
        max_kv_bytes,
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
            "evidence",
            WorkingSetUnitKind::EvidencePage,
            UasKind::VaultNote,
            WorkingSetStorageTier::Hot,
            0,
            64 * 1024,
            10,
        )?,
        unit(
            "verifier",
            WorkingSetUnitKind::VerifierLane,
            UasKind::ToolResult,
            WorkingSetStorageTier::Hot,
            0,
            32 * 1024,
            20,
        )?,
        unit(
            "kv",
            WorkingSetUnitKind::KvPage,
            UasKind::KvPage,
            WorkingSetStorageTier::Warm,
            0,
            512 * 1024,
            60,
        )?,
        unit(
            "adapter",
            WorkingSetUnitKind::AdapterSlice,
            UasKind::ModelComponent,
            WorkingSetStorageTier::Warm,
            0,
            128 * 1024,
            30,
        )?,
        unit(
            "weight",
            WorkingSetUnitKind::WeightPage,
            UasKind::ModelComponent,
            WorkingSetStorageTier::Cold,
            1024 * 1024,
            1024 * 1024,
            90,
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

fn fixture_mmap_fence(
    counted_hot_bytes: u64,
    mapped: bool,
    touched: bool,
) -> Result<MmapResidencyFence, Box<dyn std::error::Error>> {
    Ok(MmapResidencyFence::evaluate(
        "model.gguf",
        0,
        1024 * 1024,
        mapped,
        touched,
        if touched { 1024 * 1024 } else { 0 },
        0,
        1,
        0,
        counted_hot_bytes,
    )?)
}

fn unit(
    id: &str,
    kind: WorkingSetUnitKind,
    uas_kind: UasKind,
    tier: WorkingSetStorageTier,
    byte_start: u64,
    byte_len: u64,
    priority: u32,
) -> Result<SemanticWorkingSetUnit, Box<dyn std::error::Error>> {
    Ok(SemanticWorkingSetUnit::new(
        id,
        kind,
        address(uas_kind, id.as_bytes()),
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

fn address(kind: UasKind, bytes: &[u8]) -> UasAddress {
    UasAddress::new(kind, bytes, CREATED_AT_MS)
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
            unit: "bytes_or_count".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(expected)),
            unit: "bytes_or_count".to_string(),
        },
    );
    let pass = match operator {
        "<=" => actual <= expected,
        ">=" => actual >= expected,
        _ => false,
    };
    pass_per_axis.insert(name.to_string(), pass);
}
