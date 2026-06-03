//! `falsify_residency_page_table_addressability` — page-table witness.
//!
//! This metadata-only witness proves selected semantic units produce a
//! deterministic residency page table with UAS address, storage tier, byte
//! range, codec, checksum, compatibility fence, lease/expiry, and prefetch
//! priority before any runtime wake path can consume the plan.

use std::collections::{BTreeMap, HashSet};
use std::path::PathBuf;

use agent_core::falsifier_artifacts::{
    current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold, ArtifactBuilder,
    ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    EvidenceNeed, KVByteBudgetCard, MmapResidencyFence, PrivacyClass, ProStatus, ProductBuild,
    ResidencyTier, SemanticWorkingSetError, SemanticWorkingSetPlan, SemanticWorkingSetPlanStatus,
    SemanticWorkingSetUnit, SemanticWorkingSetViolation, TaskWorkingSetQuery, UasAddress, UasKind,
    VerifierNeed, WorkingSetStorageTier, WorkingSetUnitKind,
};

const FALSIFIER_ID: &str = "F-ResidencyPageTable-Addressability";
const FIXTURE_ID: &str = "residency_page_table_addressability_v1";
const COMMAND: &str = "Tools/falsifiers/f_residency_page_table_addressability.sh";
const RESULT: &str = "artifacts/falsifiers/residency_page_table_addressability/result.json";
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
        "{FALSIFIER_ID}: overall_pass={} page_table_entry_count={} selected_unit_count={} artifact={RESULT}",
        artifact.overall_pass,
        artifact.measurements["page_table_entry_count"].value,
        artifact.measurements["selected_unit_count"].value
    );

    if artifact.overall_pass {
        std::process::ExitCode::SUCCESS
    } else {
        std::process::ExitCode::from(1)
    }
}

fn build_artifact(
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, Box<dyn std::error::Error>> {
    let plan = accepted_plan(fixture_units()?)?;
    let reversed = accepted_plan(fixture_units()?.into_iter().rev().collect())?;

    let entry_count_matches_selected = plan.page_table.len() == plan.selected_units.len();
    let page_table_status_fit = plan.status == SemanticWorkingSetPlanStatus::FitForDryRun;
    let semantic_unit_ids_present = plan
        .page_table
        .iter()
        .all(|entry| !entry.semantic_unit_id.is_empty());
    let uas_addresses_present = plan
        .page_table
        .iter()
        .all(|entry| !entry.uas_address.to_string().is_empty());
    let uas_addresses_unique = unique_strings(
        plan.page_table
            .iter()
            .map(|entry| entry.uas_address.to_string()),
    );
    let byte_ranges_nonempty = plan.page_table.iter().all(|entry| entry.byte_range.len > 0);
    let entry_identity_unique = unique_strings(plan.page_table.iter().map(|entry| {
        format!(
            "{}:{}:{}",
            entry.uas_address, entry.byte_range.start, entry.byte_range.len
        )
    }));
    let storage_tier_coverage = has_tier(&plan, WorkingSetStorageTier::Hot)
        && has_tier(&plan, WorkingSetStorageTier::Warm)
        && has_tier(&plan, WorkingSetStorageTier::Cold)
        && has_tier(&plan, WorkingSetStorageTier::RemoteReference);
    let unit_kind_coverage = has_kind(&plan, WorkingSetUnitKind::EvidencePage)
        && has_kind(&plan, WorkingSetUnitKind::KvPage)
        && has_kind(&plan, WorkingSetUnitKind::AdapterSlice)
        && has_kind(&plan, WorkingSetUnitKind::WeightPage)
        && has_kind(&plan, WorkingSetUnitKind::Kernel)
        && has_kind(&plan, WorkingSetUnitKind::VerifierLane);
    let codec_coverage = plan.page_table.iter().all(|entry| !entry.codec.is_empty());
    let checksum_coverage = plan
        .page_table
        .iter()
        .all(|entry| entry.checksum.starts_with("blake3:"));
    let compatibility_fence_coverage = plan
        .page_table
        .iter()
        .all(|entry| entry.compatibility_fence.starts_with("compat:"));
    let lease_or_expiry_coverage = plan
        .page_table
        .iter()
        .all(|entry| !entry.lease_or_expiry.is_empty());
    let prefetch_priority_coverage = plan
        .page_table
        .iter()
        .all(|entry| entry.prefetch_priority > 0);
    let entry_order_deterministic = page_table_ids(&plan) == page_table_ids(&reversed);
    let unit_to_entry_round_trip =
        plan.selected_units
            .iter()
            .zip(&plan.page_table)
            .all(|(unit, entry)| {
                unit.semantic_unit_id == entry.semantic_unit_id
                    && unit.uas_address == entry.uas_address
                    && unit.storage_tier == entry.storage_tier
                    && unit.byte_range == entry.byte_range
                    && unit.codec == entry.codec
                    && unit.checksum == entry.checksum
                    && unit.compatibility_fence == entry.compatibility_fence
                    && unit.lease_or_expiry == entry.lease_or_expiry
                    && unit.prefetch_priority == entry.prefetch_priority
            });
    let invalid_byte_range_rejected = invalid_byte_range_rejected()?;
    let missing_checksum_rejected = missing_checksum_rejected()?;
    let bad_checksum_rejected = bad_checksum_rejected()?;
    let missing_compatibility_fence_rejected = missing_compatibility_fence_rejected()?;
    let bad_compatibility_fence_rejected = bad_compatibility_fence_rejected()?;
    let duplicate_uas_address_rejected = duplicate_uas_address_rejected()?;
    let unavailable_unit_rejected = unavailable_unit_rejected()?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "entry_count_matches_selected",
        entry_count_matches_selected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "page_table_status_fit",
        page_table_status_fit,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "semantic_unit_ids_present",
        semantic_unit_ids_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "uas_addresses_present",
        uas_addresses_present,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "uas_addresses_unique",
        uas_addresses_unique,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "byte_ranges_nonempty",
        byte_ranges_nonempty,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "entry_identity_unique",
        entry_identity_unique,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "storage_tier_coverage",
        storage_tier_coverage,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unit_kind_coverage",
        unit_kind_coverage,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "codec_coverage",
        codec_coverage,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "checksum_coverage",
        checksum_coverage,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "compatibility_fence_coverage",
        compatibility_fence_coverage,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "lease_or_expiry_coverage",
        lease_or_expiry_coverage,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "prefetch_priority_coverage",
        prefetch_priority_coverage,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "entry_order_deterministic",
        entry_order_deterministic,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unit_to_entry_round_trip",
        unit_to_entry_round_trip,
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
        "missing_checksum_rejected",
        missing_checksum_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "bad_checksum_rejected",
        bad_checksum_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "missing_compatibility_fence_rejected",
        missing_compatibility_fence_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "bad_compatibility_fence_rejected",
        bad_compatibility_fence_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "duplicate_uas_address_rejected",
        duplicate_uas_address_rejected,
    );
    add_bool_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unavailable_unit_rejected",
        unavailable_unit_rejected,
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "page_table_entry_count",
        plan.page_table.len() as u64,
        6,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "selected_unit_count",
        plan.selected_units.len() as u64,
        6,
        ">=",
    );
    add_u64_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "cold_page_count",
        plan.page_table
            .iter()
            .filter(|entry| entry.storage_tier == WorkingSetStorageTier::Cold)
            .count() as u64,
        1,
        ">=",
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
            "detail": "metadata-only residency page table; no cold byte movement, prefetch, mmap stress, model decode, MLX/Metal, or route mutation executed"
        })],
        notes: "Proves selected semantic units round-trip into deterministic residency page-table entries with UAS address, storage tier, byte range, codec, checksum, compatibility fence, lease/expiry, and prefetch priority, while invalid ranges, checksum/fence gaps, duplicate addresses, and unavailable selected units fail closed.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();

    Ok(artifact)
}

fn accepted_plan(
    selected_units: Vec<SemanticWorkingSetUnit>,
) -> Result<SemanticWorkingSetPlan, Box<dyn std::error::Error>> {
    Ok(SemanticWorkingSetPlan::compile_dry_run(
        fixture_query()?,
        selected_units,
        fixture_kv_budget()?,
        fixture_mmap_fence()?,
        "runtime_router:fallback_page_table_addressability",
        "rollback:residency-page-table-addressability",
        "run_event_log:residency-page-table-addressability",
        "answer_packet:residency-page-table-addressability",
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
            "source:doc:residency-page-table".to_string(),
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
        unit(
            "kernel",
            WorkingSetUnitKind::Kernel,
            UasKind::ToolResult,
            WorkingSetStorageTier::RemoteReference,
            0,
            64 * 1024,
            40,
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

fn unique_strings(values: impl Iterator<Item = String>) -> bool {
    let mut seen = HashSet::new();
    values.into_iter().all(|value| seen.insert(value))
}

fn has_tier(plan: &SemanticWorkingSetPlan, tier: WorkingSetStorageTier) -> bool {
    plan.page_table
        .iter()
        .any(|entry| entry.storage_tier == tier)
}

fn has_kind(plan: &SemanticWorkingSetPlan, kind: WorkingSetUnitKind) -> bool {
    plan.selected_units
        .iter()
        .any(|unit| unit.unit_kind == kind)
}

fn page_table_ids(plan: &SemanticWorkingSetPlan) -> Vec<String> {
    plan.page_table
        .iter()
        .map(|entry| entry.semantic_unit_id.clone())
        .collect()
}

fn invalid_byte_range_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = SemanticWorkingSetUnit::new(
        "bad-range",
        WorkingSetUnitKind::EvidencePage,
        address(UasKind::VaultNote, b"bad-range"),
        WorkingSetStorageTier::Hot,
        0,
        0,
        "fixture-codec",
        "blake3:abc",
        "compat:semantic-working-set-v1",
        1,
        "lease:dry-run",
    )
    .unwrap_err();
    Ok(matches!(error, SemanticWorkingSetError::InvalidByteRange))
}

fn missing_checksum_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = SemanticWorkingSetUnit::new(
        "missing-checksum",
        WorkingSetUnitKind::EvidencePage,
        address(UasKind::VaultNote, b"missing-checksum"),
        WorkingSetStorageTier::Hot,
        0,
        1024,
        "fixture-codec",
        "",
        "compat:semantic-working-set-v1",
        1,
        "lease:dry-run",
    )
    .unwrap_err();
    Ok(matches!(error, SemanticWorkingSetError::MissingChecksum))
}

fn bad_checksum_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = SemanticWorkingSetUnit::new(
        "bad-checksum",
        WorkingSetUnitKind::EvidencePage,
        address(UasKind::VaultNote, b"bad-checksum"),
        WorkingSetStorageTier::Hot,
        0,
        1024,
        "fixture-codec",
        "sha256:not-canonical",
        "compat:semantic-working-set-v1",
        1,
        "lease:dry-run",
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::InvalidChecksum { .. }
    ))
}

fn missing_compatibility_fence_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = SemanticWorkingSetUnit::new(
        "missing-fence",
        WorkingSetUnitKind::EvidencePage,
        address(UasKind::VaultNote, b"missing-fence"),
        WorkingSetStorageTier::Hot,
        0,
        1024,
        "fixture-codec",
        "blake3:abc",
        "",
        1,
        "lease:dry-run",
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::MissingCompatibilityFence
    ))
}

fn bad_compatibility_fence_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let error = SemanticWorkingSetUnit::new(
        "bad-fence",
        WorkingSetUnitKind::EvidencePage,
        address(UasKind::VaultNote, b"bad-fence"),
        WorkingSetStorageTier::Hot,
        0,
        1024,
        "fixture-codec",
        "blake3:abc",
        "missing-prefix",
        1,
        "lease:dry-run",
    )
    .unwrap_err();
    Ok(matches!(
        error,
        SemanticWorkingSetError::InvalidCompatibilityFence { .. }
    ))
}

fn duplicate_uas_address_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let shared_address = address(UasKind::VaultNote, b"shared");
    let units = vec![
        SemanticWorkingSetUnit::new(
            "duplicate-a",
            WorkingSetUnitKind::EvidencePage,
            shared_address.clone(),
            WorkingSetStorageTier::Hot,
            0,
            1024,
            "fixture-codec",
            "blake3:abc",
            "compat:semantic-working-set-v1",
            1,
            "lease:dry-run",
        )?,
        SemanticWorkingSetUnit::new(
            "duplicate-b",
            WorkingSetUnitKind::EvidencePage,
            shared_address,
            WorkingSetStorageTier::Hot,
            1024,
            1024,
            "fixture-codec",
            "blake3:def",
            "compat:semantic-working-set-v1",
            2,
            "lease:dry-run",
        )?,
    ];
    let plan = accepted_plan(units)?;
    Ok(
        plan.status == SemanticWorkingSetPlanStatus::RejectedBeforeRuntime
            && plan.violations.iter().any(|violation| {
                matches!(
                    violation,
                    SemanticWorkingSetViolation::DuplicateUasAddress { .. }
                )
            }),
    )
}

fn unavailable_unit_rejected() -> Result<bool, Box<dyn std::error::Error>> {
    let plan = accepted_plan(vec![unit(
        "unavailable-evidence",
        WorkingSetUnitKind::EvidencePage,
        UasKind::VaultNote,
        WorkingSetStorageTier::Unavailable,
        0,
        1024,
        1,
    )?])?;
    Ok(
        plan.status == SemanticWorkingSetPlanStatus::RejectedBeforeRuntime
            && plan.violations.iter().any(|violation| {
                matches!(
                    violation,
                    SemanticWorkingSetViolation::UnavailableUnitSelected { .. }
                )
            }),
    )
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
            unit: "count".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: operator.to_string(),
            value: serde_json::Value::Number(serde_json::Number::from(expected)),
            unit: "count".to_string(),
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
