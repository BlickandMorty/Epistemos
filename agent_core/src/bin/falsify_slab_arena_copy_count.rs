//! `falsify_slab_arena_copy_count`.
//!
//! Metadata-only witness for `F-SlabArena-CopyCount`. It proves that CPU slab
//! residency plans are preallocated, lease-scoped, copy-counted,
//! AnswerPacket-visible, rollback-bound, and protected from per-token
//! allocation spikes before any live ColdStream or model-byte route promotes.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use agent_core::falsifier_artifacts::axes::COLDSTREAM_VS_MMAP_AXES;
#[cfg(test)]
use agent_core::falsifier_artifacts::axes::SLAB_ARENA_COPY_COUNT_AXES;
use agent_core::falsifier_artifacts::{
    add_bool_axis, current_commit_sha, now_utc_rfc3339, write_artifact, AcceptanceThreshold,
    ArtifactBuilder, ArtifactKind, FallbackTier, Measurement,
};
use agent_core::uas::{
    ProStatus, ProductBuild, SlabArenaAllocationSample, SlabArenaCopyCountError,
    SlabArenaCopyCountWitness, SlabArenaCopyEvent, SlabArenaLease, SlabArenaPlan, SlabArenaSurface,
    SlabCopyClass, SLAB_ARENA_COPY_COUNT_CURSOR, SLAB_ARENA_COPY_COUNT_NEXT_CURSOR,
};

const FALSIFIER_ID: &str = "F-SlabArena-CopyCount";
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";
const FIXTURE_ID: &str = "slab_arena_copy_count_v1";
const COMMAND: &str = "Tools/falsifiers/f_slab_arena_copy_count.sh";
const RESULT: &str = "artifacts/falsifiers/slab_arena_copy_count/result.json";
const GUARD_PATH: &str = "artifacts/falsifiers/architecture_pending_work_guard/result.json";
const CAPABILITY_PATH: &str =
    "artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json";
const COLDSTREAM_VS_MMAP_PATH: &str = "artifacts/falsifiers/coldstream_vs_mmap/result.json";
const MIN_PLAN_COUNT: u64 = 2;
const MIN_LEASE_COUNT: u64 = 4;
const MIN_COPY_EVENT_COUNT: u64 = 6;
const MIN_ALLOCATION_SAMPLE_COUNT: u64 = 4;
const MIN_SURFACE_COUNT: u64 = 2;
const MIN_TRACE_SUCCESS_BPS: u64 = 9_500;
const MAX_COPY_COUNT: u64 = 1;
const MAX_PER_TOKEN_ALLOCATION_COUNT: u64 = 0;
const MAX_PER_TOKEN_ALLOCATION_BYTES: u64 = 0;
const MAX_METADATA_BYTES: u64 = 256 * 1024;

#[derive(Debug)]
// UAS: uas:slab-arena-copy-count:witness-error
// Plane: Verification
// Residency: metadata-only artifact rejection taxonomy.
enum SlabArenaWitnessError {
    Primitive(SlabArenaCopyCountError),
    Io(String),
}

impl std::fmt::Display for SlabArenaWitnessError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Primitive(error) => write!(f, "{error}"),
            Self::Io(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for SlabArenaWitnessError {}

impl From<SlabArenaCopyCountError> for SlabArenaWitnessError {
    fn from(value: SlabArenaCopyCountError) -> Self {
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
) -> Result<agent_core::falsifier_artifacts::FalsifierArtifact, SlabArenaWitnessError> {
    let evidence = EvidenceSnapshot::read()?;
    let witness = fixture_witness()?;
    let metrics = witness.metrics();
    let address = witness.address();
    let mut reversed = witness.plans.clone();
    reversed.reverse();
    let deterministic = SlabArenaCopyCountWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "slab_trace_only",
        witness.trace_success_bps,
        witness.unbounded_vec_growth_baseline_bps,
        witness.hidden_decode_copy_baseline_bps,
        witness.token_allocation_spike_baseline_bps,
        witness.live_authority_baseline_bps,
        0,
        0,
        MAX_METADATA_BYTES,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        reversed,
        witness.surfaces.clone(),
    )?
    .address()
        == address;
    let invalid_axes = invalid_fixture_axes()?;

    let mut measurements = BTreeMap::new();
    let mut thresholds = BTreeMap::new();
    let mut pass_per_axis = BTreeMap::new();

    let bool_axes = [
        (
            "upstream_coldstream_vs_mmap_pass",
            evidence.coldstream_vs_mmap_pass,
        ),
        (
            "guard_cursor_slab_arena_copy_count_or_advanced",
            evidence.guard_next_existing_work == SLAB_ARENA_COPY_COUNT_CURSOR
                || evidence.guard_next_existing_work == SLAB_ARENA_COPY_COUNT_NEXT_CURSOR
                || evidence.guard_next_existing_work == ADVANCED_RELEASE_AUDIT_CURSOR,
        ),
        ("capability_kernel_red", !evidence.capability_overall_pass),
        (
            "capability_route_status_vault_research",
            evidence.capability_route_status == "vault_research_route_with_packetized_mitigation",
        ),
        (
            "capability_next_bottleneck_slab_arena_copy_count_or_advanced",
            evidence.capability_next_bottleneck == SLAB_ARENA_COPY_COUNT_CURSOR
                || evidence.capability_next_bottleneck == SLAB_ARENA_COPY_COUNT_NEXT_CURSOR
                || evidence.capability_next_bottleneck == ADVANCED_RELEASE_AUDIT_CURSOR,
        ),
        (
            "product_status_research_only",
            witness.product_build == ProductBuild::Pro
                && witness.pro_status == ProStatus::ResearchCandidate,
        ),
        (
            "route_authority_slab_trace_only",
            witness.route_authority == "slab_trace_only",
        ),
        ("slab_plans_bound", metrics.plan_count >= MIN_PLAN_COUNT),
        (
            "lease_table_bound",
            witness
                .plans
                .iter()
                .all(|plan| plan.lease_table_ref.starts_with("lease_table:")),
        ),
        (
            "preallocated_capacity_bound",
            metrics.preallocated_bytes > 0,
        ),
        (
            "alignment_bound",
            witness
                .plans
                .iter()
                .all(|plan| plan.alignment.is_power_of_two() && plan.alignment >= 64),
        ),
        (
            "owner_actor_bound",
            witness
                .plans
                .iter()
                .all(|plan| !plan.owner_thread_or_actor.is_empty()),
        ),
        (
            "purge_policy_bound",
            witness
                .plans
                .iter()
                .all(|plan| plan.purge_policy.starts_with("purge_policy:")),
        ),
        ("lease_ranges_bound", metrics.lease_count >= MIN_LEASE_COUNT),
        (
            "lease_ranges_non_overlapping",
            all_lease_ranges_non_overlapping(&witness),
        ),
        (
            "copy_events_bound",
            metrics.copy_event_count >= MIN_COPY_EVENT_COUNT,
        ),
        (
            "copy_count_reported",
            metrics.max_copy_count <= MAX_COPY_COUNT as u32,
        ),
        (
            "copy_count_within_expected",
            metrics.max_copy_count <= metrics.max_expected_copy_count,
        ),
        (
            "copy_bytes_bound",
            metrics.observed_copy_bytes <= metrics.preallocated_bytes,
        ),
        (
            "allocation_samples_bound",
            metrics.allocation_sample_count >= MIN_ALLOCATION_SAMPLE_COUNT,
        ),
        (
            "no_per_token_allocation_spikes",
            metrics.max_per_token_allocation_count == 0
                && metrics.max_per_token_allocation_bytes == 0,
        ),
        (
            "answer_packet_refs_bound",
            metrics.answer_packet_count >= metrics.surface_count,
        ),
        (
            "run_event_log_refs_bound",
            witness
                .plans
                .iter()
                .flat_map(|plan| &plan.leases)
                .all(|lease| lease.run_event_log_ref.starts_with("run_event_log:")),
        ),
        (
            "rollback_bound",
            witness
                .plans
                .iter()
                .flat_map(|plan| &plan.leases)
                .all(|lease| lease.rollback_ref.starts_with("rollback:")),
        ),
        (
            "admission_bound",
            witness
                .plans
                .iter()
                .flat_map(|plan| &plan.leases)
                .all(|lease| lease.admission_ref.starts_with("admission:")),
        ),
        (
            "scope_rex_bound",
            witness
                .plans
                .iter()
                .flat_map(|plan| &plan.leases)
                .all(|lease| lease.scope_rex_ref.starts_with("scope_rex:")),
        ),
        (
            "sovereign_gate_bound",
            witness
                .plans
                .iter()
                .flat_map(|plan| &plan.leases)
                .all(|lease| lease.sovereign_gate_ref.starts_with("sovereign_gate:")),
        ),
        (
            "compatibility_fence_bound",
            witness
                .plans
                .iter()
                .flat_map(|plan| &plan.leases)
                .all(|lease| lease.compatibility_fence.starts_with("compat:")),
        ),
        (
            "cancel_group_bound",
            witness
                .plans
                .iter()
                .flat_map(|plan| &plan.leases)
                .all(|lease| lease.cancel_group_ref.starts_with("cancel_group:")),
        ),
        (
            "fallback_bound",
            witness
                .plans
                .iter()
                .flat_map(|plan| &plan.leases)
                .all(|lease| lease.fallback_ref.starts_with("fallback:")),
        ),
        (
            "visible_summary_bound",
            witness
                .surfaces
                .iter()
                .all(|surface| surface.body.contains("metadata-only")),
        ),
        (
            "l1_l2_l3_separation_bound",
            witness.surfaces.iter().all(|surface| {
                surface.body.contains("L1")
                    && surface.body.contains("L2 remains")
                    && surface.body.contains("L3")
            }),
        ),
        (
            "no_hidden_route_authority",
            !witness.hidden_route_authority_attempted,
        ),
        (
            "no_route_policy_mutation",
            !witness.route_policy_mutation_attempted,
        ),
        ("no_scope_rex_bypass", !witness.scope_rex_bypass_attempted),
        (
            "no_sovereign_gate_bypass",
            !witness.sovereign_gate_bypass_attempted,
        ),
        (
            "no_answer_packet_suppression",
            !witness.answer_packet_suppression_attempted,
        ),
        ("no_hidden_chain", !witness.hidden_chain_exposure_attempted),
        ("no_hidden_cloud", !witness.hidden_cloud_route_attempted),
        ("no_ssd_as_ram_claim", !witness.ssd_as_ram_claim_attempted),
        (
            "no_live_benchmark_attempted",
            !witness.live_benchmark_attempted,
        ),
        ("no_runtime_bytes_loaded", metrics.runtime_bytes_loaded == 0),
        ("no_model_bytes_loaded", metrics.model_bytes_loaded == 0),
        (
            "metadata_bound",
            metrics.max_metadata_bytes <= MAX_METADATA_BYTES,
        ),
        ("slab_arena_copy_count_address_deterministic", deterministic),
    ];
    for (name, passed) in bool_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }
    for (name, passed) in invalid_axes {
        add_bool_axis(
            &mut measurements,
            &mut thresholds,
            &mut pass_per_axis,
            name,
            passed,
        );
    }
    add_count_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "plan_count",
        metrics.plan_count,
        MIN_PLAN_COUNT,
        "plans",
    );
    add_count_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "lease_count",
        metrics.lease_count,
        MIN_LEASE_COUNT,
        "leases",
    );
    add_count_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "copy_event_count",
        metrics.copy_event_count,
        MIN_COPY_EVENT_COUNT,
        "events",
    );
    add_count_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "allocation_sample_count",
        metrics.allocation_sample_count,
        MIN_ALLOCATION_SAMPLE_COUNT,
        "samples",
    );
    add_count_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "surface_count",
        metrics.surface_count,
        MIN_SURFACE_COUNT,
        "surfaces",
    );
    add_count_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "answer_packet_count",
        metrics.answer_packet_count,
        MIN_SURFACE_COUNT,
        "refs",
    );
    add_count_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "preallocated_bytes",
        metrics.preallocated_bytes,
        1,
        "bytes",
    );
    add_count_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "observed_copy_bytes",
        metrics.observed_copy_bytes,
        metrics.preallocated_bytes,
        "bytes",
    );
    add_count_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_copy_count",
        metrics.max_copy_count as u64,
        MAX_COPY_COUNT,
        "copies",
    );
    add_count_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_expected_copy_count",
        metrics.max_expected_copy_count as u64,
        4,
        "copies",
    );
    add_count_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_per_token_allocation_count",
        metrics.max_per_token_allocation_count as u64,
        MAX_PER_TOKEN_ALLOCATION_COUNT,
        "allocations",
    );
    add_count_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_per_token_allocation_bytes",
        metrics.max_per_token_allocation_bytes,
        MAX_PER_TOKEN_ALLOCATION_BYTES,
        "bytes",
    );
    add_count_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "runtime_bytes_loaded",
        metrics.runtime_bytes_loaded,
        0,
        "bytes",
    );
    add_count_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "model_bytes_loaded",
        metrics.model_bytes_loaded,
        0,
        "bytes",
    );
    add_count_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "max_metadata_bytes",
        metrics.max_metadata_bytes,
        MAX_METADATA_BYTES,
        "bytes",
    );
    add_count_min_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "trace_success_bps",
        metrics.trace_success_bps as u64,
        MIN_TRACE_SUCCESS_BPS,
        "bps",
    );
    add_count_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "unbounded_vec_growth_baseline_bps",
        metrics.unbounded_vec_growth_baseline_bps as u64,
        (metrics.trace_success_bps - 1) as u64,
        "bps",
    );
    add_count_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "hidden_decode_copy_baseline_bps",
        metrics.hidden_decode_copy_baseline_bps as u64,
        (metrics.trace_success_bps - 1) as u64,
        "bps",
    );
    add_count_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "token_allocation_spike_baseline_bps",
        metrics.token_allocation_spike_baseline_bps as u64,
        (metrics.trace_success_bps - 1) as u64,
        "bps",
    );
    add_count_max_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "live_authority_baseline_bps",
        metrics.live_authority_baseline_bps as u64,
        (metrics.trace_success_bps - 1) as u64,
        "bps",
    );
    add_string_axis(
        &mut measurements,
        &mut thresholds,
        &mut pass_per_axis,
        "slab_arena_copy_count_address",
        metrics.address,
        "uas:slab-arena-copy-count:",
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
        anomalies: vec![],
        notes: "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. F-SlabArena-CopyCount is metadata-only: it proves preallocated CPU slab plans, leases, copy-count traces, zero per-token allocation spikes, rollback, RunEventLog, AnswerPacket visibility, SCOPE-Rex/SovereignGate admission, no SSD-as-RAM claim, and no live benchmark/runtime/model bytes. L1 advances only; L2 remains red and L3 product runtime is unchanged.".to_string(),
        timestamp_utc: now_utc_rfc3339(),
    }
    .build();
    Ok(artifact)
}

fn fixture_witness() -> Result<SlabArenaCopyCountWitness, SlabArenaWitnessError> {
    Ok(SlabArenaCopyCountWitness::new(
        ProductBuild::Pro,
        ProStatus::ResearchCandidate,
        "slab_trace_only",
        9_850,
        7_100,
        7_350,
        7_800,
        7_000,
        0,
        0,
        MAX_METADATA_BYTES,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        vec![fixture_plan("cpu")?, fixture_plan("decode")?],
        vec![
            fixture_surface("surface:cpu")?,
            fixture_surface("surface:decode")?,
        ],
    )?)
}

fn fixture_plan(suffix: &str) -> Result<SlabArenaPlan, SlabArenaCopyCountError> {
    let slab_id = format!("slab:{suffix}");
    SlabArenaPlan::new(
        format!("slab-plan-{suffix}"),
        slab_id.clone(),
        64 * 1024,
        4096,
        "rust-serialized-coldstream-actor",
        format!("lease_table:{suffix}"),
        "purge_policy:drop-on-cancel-or-generation-mismatch",
        4,
        0,
        0,
        format!("surface:{suffix}"),
        honest_summary(),
        vec![
            fixture_lease(&format!("lease-{suffix}-a"), &slab_id, 0, 16 * 1024)?,
            fixture_lease(&format!("lease-{suffix}-b"), &slab_id, 16 * 1024, 16 * 1024)?,
        ],
        vec![
            fixture_event(
                &format!("copy-{suffix}-pread-a"),
                &format!("lease-{suffix}-a"),
                SlabCopyClass::PreadIntoSlab,
                16 * 1024,
                1,
                1,
            )?,
            fixture_event(
                &format!("copy-{suffix}-decode-a"),
                &format!("lease-{suffix}-a"),
                SlabCopyClass::DecodeInPlace,
                0,
                0,
                1,
            )?,
            fixture_event(
                &format!("copy-{suffix}-view-b"),
                &format!("lease-{suffix}-b"),
                SlabCopyClass::BorrowedView,
                0,
                0,
                0,
            )?,
        ],
        vec![
            SlabArenaAllocationSample::new(
                format!("sample-{suffix}-a"),
                format!("lease-{suffix}-a"),
                1,
                0,
                0,
            )?,
            SlabArenaAllocationSample::new(
                format!("sample-{suffix}-b"),
                format!("lease-{suffix}-b"),
                2,
                0,
                0,
            )?,
        ],
    )
}

fn fixture_lease(
    lease_id: &str,
    slab_id: &str,
    byte_offset: u64,
    byte_len: u64,
) -> Result<SlabArenaLease, SlabArenaCopyCountError> {
    SlabArenaLease::new(
        lease_id,
        slab_id,
        byte_offset,
        byte_len,
        1,
        format!("answer_packet:{lease_id}"),
        format!("run_event_log:{lease_id}"),
        format!("rollback:{lease_id}"),
        "admission:scope-rex-slab-trace",
        "scope_rex:slab-copy-count",
        "sovereign_gate:slab-copy-count",
        "compat:coldstream-v1",
        format!("cancel_group:{lease_id}"),
        format!("fallback:{lease_id}"),
        honest_summary(),
    )
}

fn fixture_event(
    event_id: &str,
    lease_id: &str,
    copy_class: SlabCopyClass,
    bytes_copied: u64,
    copy_count_delta: u32,
    expected_copy_count_delta: u32,
) -> Result<SlabArenaCopyEvent, SlabArenaCopyCountError> {
    SlabArenaCopyEvent::new(
        event_id,
        lease_id,
        copy_class,
        bytes_copied,
        copy_count_delta,
        expected_copy_count_delta,
        0,
    )
}

fn fixture_surface(surface_id: &str) -> Result<SlabArenaSurface, SlabArenaCopyCountError> {
    SlabArenaSurface::new(
        surface_id,
        format!("answer_packet:{surface_id}"),
        honest_summary(),
    )
}

fn honest_summary() -> String {
    "metadata-only SlabArena copy-count witness: L1 architecture proof records preallocated CPU slabs, leases, copy counts, allocation samples, rollback, and AnswerPacket refs; L2 remains vault research; L3 product runtime is unchanged."
        .to_string()
}

fn invalid_fixture_axes() -> Result<Vec<(&'static str, bool)>, SlabArenaWitnessError> {
    let axes = vec![
        ("empty_plan_rejected", reject_witness(|w| w.plans.clear())),
        (
            "empty_surface_rejected",
            reject_witness(|w| w.surfaces.clear()),
        ),
        (
            "duplicate_plan_rejected",
            reject_witness(|w| w.plans.push(w.plans[0].clone())),
        ),
        (
            "duplicate_lease_rejected",
            reject_one_plan(|p| p.leases.push(p.leases[0].clone())),
        ),
        (
            "duplicate_copy_event_rejected",
            reject_one_plan(|p| p.copy_events.push(p.copy_events[0].clone())),
        ),
        (
            "duplicate_allocation_sample_rejected",
            reject_one_plan(|p| p.allocation_samples.push(p.allocation_samples[0].clone())),
        ),
        (
            "duplicate_surface_rejected",
            reject_witness(|w| w.surfaces.push(w.surfaces[0].clone())),
        ),
        (
            "duplicate_answer_packet_rejected",
            reject_witness(|w| {
                w.surfaces[1].answer_packet_ref = w.surfaces[0].answer_packet_ref.clone()
            }),
        ),
        (
            "missing_lease_table_rejected",
            reject_one_plan(|p| p.lease_table_ref = "missing".to_string()),
        ),
        (
            "missing_answer_packet_rejected",
            reject_one_lease(|l| l.answer_packet_ref = "missing".to_string()),
        ),
        (
            "missing_run_event_log_rejected",
            reject_one_lease(|l| l.run_event_log_ref = "missing".to_string()),
        ),
        (
            "missing_rollback_rejected",
            reject_one_lease(|l| l.rollback_ref = "missing".to_string()),
        ),
        (
            "missing_admission_rejected",
            reject_one_lease(|l| l.admission_ref = "missing".to_string()),
        ),
        (
            "missing_scope_rex_rejected",
            reject_one_lease(|l| l.scope_rex_ref = "missing".to_string()),
        ),
        (
            "missing_sovereign_gate_rejected",
            reject_one_lease(|l| l.sovereign_gate_ref = "missing".to_string()),
        ),
        (
            "missing_compatibility_fence_rejected",
            reject_one_lease(|l| l.compatibility_fence = "missing".to_string()),
        ),
        (
            "missing_cancel_group_rejected",
            reject_one_lease(|l| l.cancel_group_ref = "missing".to_string()),
        ),
        (
            "missing_fallback_rejected",
            reject_one_lease(|l| l.fallback_ref = "missing".to_string()),
        ),
        (
            "missing_purge_policy_rejected",
            reject_one_plan(|p| p.purge_policy = "missing".to_string()),
        ),
        (
            "missing_surface_ref_rejected",
            reject_one_plan(|p| p.surface_ref = "surface:missing".to_string()),
        ),
        (
            "missing_required_marker_rejected",
            reject_surface(|s| s.body = "metadata-only L1 L2 remains L3 rollback".to_string()),
        ),
        (
            "forbidden_marker_rejected",
            reject_surface(|s| s.body = format!("{} SSD is RAM", honest_summary())),
        ),
        (
            "missing_layer_separation_rejected",
            reject_surface(|s| s.body = "metadata-only AnswerPacket rollback only".to_string()),
        ),
        (
            "missing_visible_summary_rejected",
            reject_one_lease(|l| l.visible_summary = "metadata-only".to_string()),
        ),
        (
            "zero_capacity_rejected",
            reject_one_plan(|p| p.byte_capacity = 0),
        ),
        (
            "invalid_alignment_rejected",
            reject_one_plan(|p| p.alignment = 96),
        ),
        (
            "zero_lease_length_rejected",
            reject_one_lease(|l| l.byte_len = 0),
        ),
        (
            "lease_range_overflow_rejected",
            reject_one_lease(|l| l.byte_offset = u64::MAX),
        ),
        (
            "lease_range_out_of_bounds_rejected",
            reject_one_lease(|l| l.byte_offset = 63 * 1024),
        ),
        (
            "lease_range_overlap_rejected",
            reject_one_plan(|p| p.leases[1].byte_offset = 512),
        ),
        (
            "unknown_lease_rejected",
            reject_one_plan(|p| p.copy_events[0].lease_id = "lease:missing".to_string()),
        ),
        (
            "copy_count_exceeded_rejected",
            reject_one_plan(|p| p.copy_events[0].copy_count_delta = 3),
        ),
        (
            "copy_bytes_out_of_bounds_rejected",
            reject_one_plan(|p| p.copy_events[0].bytes_copied = 64 * 1024),
        ),
        (
            "allocation_delta_in_copy_event_rejected",
            reject_one_plan(|p| p.copy_events[0].allocation_count_delta = 1),
        ),
        (
            "allocation_spike_rejected",
            reject_one_plan(|p| p.allocation_samples[0].new_allocation_count = 1),
        ),
        (
            "missing_allocation_sample_for_lease_rejected",
            reject_one_plan(|p| {
                p.allocation_samples
                    .retain(|sample| sample.lease_id != p.leases[0].lease_id)
            }),
        ),
        (
            "hidden_route_authority_rejected",
            reject_witness(|w| w.hidden_route_authority_attempted = true),
        ),
        (
            "route_policy_mutation_rejected",
            reject_witness(|w| w.route_policy_mutation_attempted = true),
        ),
        (
            "scope_rex_bypass_rejected",
            reject_witness(|w| w.scope_rex_bypass_attempted = true),
        ),
        (
            "sovereign_gate_bypass_rejected",
            reject_witness(|w| w.sovereign_gate_bypass_attempted = true),
        ),
        (
            "answer_packet_suppression_rejected",
            reject_witness(|w| w.answer_packet_suppression_attempted = true),
        ),
        (
            "hidden_chain_rejected",
            reject_witness(|w| w.hidden_chain_exposure_attempted = true),
        ),
        (
            "hidden_cloud_rejected",
            reject_witness(|w| w.hidden_cloud_route_attempted = true),
        ),
        (
            "ssd_as_ram_rejected",
            reject_witness(|w| w.ssd_as_ram_claim_attempted = true),
        ),
        (
            "mas_product_build_rejected",
            reject_witness(|w| w.product_build = ProductBuild::Mas),
        ),
        (
            "live_pro_status_rejected",
            reject_witness(|w| w.pro_status = ProStatus::Live),
        ),
        (
            "live_benchmark_rejected",
            reject_witness(|w| w.live_benchmark_attempted = true),
        ),
        (
            "runtime_bytes_rejected",
            reject_witness(|w| w.runtime_bytes_loaded = 1),
        ),
        (
            "model_bytes_rejected",
            reject_witness(|w| w.model_bytes_loaded = 1),
        ),
        (
            "unbounded_vec_growth_baseline_unbeaten_rejected",
            reject_witness(|w| w.unbounded_vec_growth_baseline_bps = w.trace_success_bps),
        ),
        (
            "hidden_decode_copy_baseline_unbeaten_rejected",
            reject_witness(|w| w.hidden_decode_copy_baseline_bps = w.trace_success_bps),
        ),
        (
            "token_allocation_spike_baseline_unbeaten_rejected",
            reject_witness(|w| w.token_allocation_spike_baseline_bps = w.trace_success_bps),
        ),
        (
            "live_authority_baseline_unbeaten_rejected",
            reject_witness(|w| w.live_authority_baseline_bps = w.trace_success_bps),
        ),
        (
            "metadata_budget_rejected",
            reject_witness(|w| w.max_metadata_bytes = MAX_METADATA_BYTES + 1),
        ),
    ];
    Ok(axes
        .into_iter()
        .map(|(name, result)| (name, result.is_err()))
        .collect())
}

fn reject_witness(
    mutate: impl FnOnce(&mut SlabArenaCopyCountWitness),
) -> Result<SlabArenaCopyCountWitness, SlabArenaCopyCountError> {
    let mut witness = fixture_witness().map_err(|error| match error {
        SlabArenaWitnessError::Primitive(error) => error,
        SlabArenaWitnessError::Io(error) => SlabArenaCopyCountError::ForbiddenMarker(error),
    })?;
    mutate(&mut witness);
    rebuild_witness(witness)
}

fn reject_one_plan(
    mutate: impl FnOnce(&mut SlabArenaPlan),
) -> Result<SlabArenaCopyCountWitness, SlabArenaCopyCountError> {
    reject_witness(|witness| mutate(&mut witness.plans[0]))
}

fn reject_one_lease(
    mutate: impl FnOnce(&mut SlabArenaLease),
) -> Result<SlabArenaCopyCountWitness, SlabArenaCopyCountError> {
    reject_one_plan(|plan| mutate(&mut plan.leases[0]))
}

fn reject_surface(
    mutate: impl FnOnce(&mut SlabArenaSurface),
) -> Result<SlabArenaCopyCountWitness, SlabArenaCopyCountError> {
    reject_witness(|witness| mutate(&mut witness.surfaces[0]))
}

fn rebuild_witness(
    witness: SlabArenaCopyCountWitness,
) -> Result<SlabArenaCopyCountWitness, SlabArenaCopyCountError> {
    SlabArenaCopyCountWitness::new(
        witness.product_build,
        witness.pro_status,
        witness.route_authority,
        witness.trace_success_bps,
        witness.unbounded_vec_growth_baseline_bps,
        witness.hidden_decode_copy_baseline_bps,
        witness.token_allocation_spike_baseline_bps,
        witness.live_authority_baseline_bps,
        witness.runtime_bytes_loaded,
        witness.model_bytes_loaded,
        witness.max_metadata_bytes,
        witness.hidden_route_authority_attempted,
        witness.route_policy_mutation_attempted,
        witness.scope_rex_bypass_attempted,
        witness.sovereign_gate_bypass_attempted,
        witness.answer_packet_suppression_attempted,
        witness.hidden_chain_exposure_attempted,
        witness.hidden_cloud_route_attempted,
        witness.ssd_as_ram_claim_attempted,
        witness.live_benchmark_attempted,
        witness.plans,
        witness.surfaces,
    )
}

fn all_lease_ranges_non_overlapping(witness: &SlabArenaCopyCountWitness) -> bool {
    witness.plans.iter().all(|plan| {
        let mut ranges = plan
            .leases
            .iter()
            .map(|lease| {
                lease
                    .byte_offset
                    .checked_add(lease.byte_len)
                    .map(|end| (lease.byte_offset, end))
            })
            .collect::<Option<Vec<_>>>();
        if let Some(ranges) = ranges.as_mut() {
            ranges.sort_by_key(|(start, _)| *start);
            ranges.windows(2).all(|pair| pair[0].1 <= pair[1].0)
        } else {
            false
        }
    })
}

fn add_count_min_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    minimum: u64,
    unit: &str,
) {
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
            operator: ">=".to_string(),
            value: serde_json::Value::from(minimum),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual >= minimum);
}

fn add_count_max_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: u64,
    maximum: u64,
    unit: &str,
) {
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
            operator: "<=".to_string(),
            value: serde_json::Value::from(maximum),
            unit: unit.to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), actual <= maximum);
}

fn add_string_axis(
    measurements: &mut BTreeMap<String, Measurement>,
    thresholds: &mut BTreeMap<String, AcceptanceThreshold>,
    pass_per_axis: &mut BTreeMap<String, bool>,
    name: &str,
    actual: String,
    prefix: &str,
) {
    let passed = actual.starts_with(prefix);
    measurements.insert(
        name.to_string(),
        Measurement {
            value: serde_json::Value::String(actual),
            unit: "string".to_string(),
        },
    );
    thresholds.insert(
        name.to_string(),
        AcceptanceThreshold {
            operator: "starts_with".to_string(),
            value: serde_json::Value::String(prefix.to_string()),
            unit: "string".to_string(),
        },
    );
    pass_per_axis.insert(name.to_string(), passed);
}

#[derive(Debug)]
// UAS: Binds upstream witness refs used to prove SlabArena copy-count lineage.
// Plane: Verification.
// Residency: Metadata-only evidence; no runtime/model bytes are loaded.
struct EvidenceSnapshot {
    coldstream_vs_mmap_pass: bool,
    guard_next_existing_work: String,
    capability_overall_pass: bool,
    capability_route_status: String,
    capability_next_bottleneck: String,
}

impl EvidenceSnapshot {
    fn read() -> Result<Self, SlabArenaWitnessError> {
        let coldstream = read_json(COLDSTREAM_VS_MMAP_PATH)?;
        let guard = read_json(GUARD_PATH)?;
        let capability = read_json(CAPABILITY_PATH)?;
        Ok(Self {
            coldstream_vs_mmap_pass: coldstream
                .get("overall_pass")
                .and_then(serde_json::Value::as_bool)
                .unwrap_or(false)
                && axes_all_present(&coldstream, COLDSTREAM_VS_MMAP_AXES),
            guard_next_existing_work: measurement_string(&guard, "next_existing_work"),
            capability_overall_pass: capability
                .get("overall_pass")
                .and_then(serde_json::Value::as_bool)
                .unwrap_or(false),
            capability_route_status: measurement_string(&capability, "route_status"),
            capability_next_bottleneck: measurement_string(&capability, "next_bottleneck"),
        })
    }
}

fn axes_all_present(value: &serde_json::Value, axes: &[&str]) -> bool {
    let Some(pass_per_axis) = value
        .get("pass_per_axis")
        .and_then(serde_json::Value::as_object)
    else {
        return false;
    };
    axes.iter().all(|axis| {
        pass_per_axis
            .get(*axis)
            .and_then(serde_json::Value::as_bool)
            == Some(true)
    })
}

fn measurement_string(value: &serde_json::Value, key: &str) -> String {
    value
        .get("measurements")
        .and_then(|measurements| measurements.get(key))
        .and_then(|measurement| measurement.get("value"))
        .and_then(serde_json::Value::as_str)
        .unwrap_or_default()
        .to_string()
}

fn read_json(path: &'static str) -> Result<serde_json::Value, SlabArenaWitnessError> {
    let text = read_text(path)?;
    serde_json::from_str(&text)
        .map_err(|error| SlabArenaWitnessError::Io(format!("failed to parse {path}: {error}")))
}

fn read_text(path: &'static str) -> Result<String, SlabArenaWitnessError> {
    let workspace_root = Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap_or_else(|| Path::new("."));
    let resolved = workspace_root.join(path);
    std::fs::read_to_string(resolved)
        .map_err(|error| SlabArenaWitnessError::Io(format!("failed to read {path}: {error}")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn artifact_axis_set_matches_contract() {
        let artifact = build_artifact().expect("artifact");
        let mut actual = artifact
            .pass_per_axis
            .keys()
            .map(String::as_str)
            .collect::<Vec<_>>();
        actual.sort_unstable();
        let mut expected = SLAB_ARENA_COPY_COUNT_AXES.to_vec();
        expected.sort_unstable();
        assert_eq!(actual, expected);
    }

    #[test]
    fn invalid_axes_are_exercised() {
        let axes = invalid_fixture_axes().expect("invalid axes");
        assert!(axes.iter().all(|(_, passed)| *passed));
        assert!(axes
            .iter()
            .any(|(name, _)| *name == "allocation_spike_rejected"));
        assert!(axes
            .iter()
            .any(|(name, _)| *name == "runtime_bytes_rejected"));
    }
}
