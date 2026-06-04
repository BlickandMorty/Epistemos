//! SlabArena copy-count contracts.
//!
//! This is a metadata-only witness for CPU slab residency. It proves the shape
//! of preallocated slab leases, copy-count accounting, per-token allocation
//! rejection, rollback, admission, and AnswerPacket visibility before any live
//! ColdStream or model-byte route can promote.

use std::collections::{BTreeSet, HashMap, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const SLAB_ARENA_COPY_COUNT_CURSOR: &str = "slab_arena_copy_count";
pub const SLAB_ARENA_COPY_COUNT_NEXT_CURSOR: &str = "metal_io_feature_gate";

const LEASE_TABLE_PREFIX: &str = "lease_table:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const CANCEL_GROUP_PREFIX: &str = "cancel_group:";
const FALLBACK_PREFIX: &str = "fallback:";
const PURGE_POLICY_PREFIX: &str = "purge_policy:";
const SURFACE_PREFIX: &str = "surface:";
const MAX_METADATA_BYTES: u64 = 256 * 1024;
const MIN_ALIGNMENT: u64 = 64;
const MAX_ALIGNMENT: u64 = 16 * 1024;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 128;
const MIN_TRACE_SUCCESS_BPS: u32 = 9_500;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:slab-arena-copy-count:copy-class
// Plane: Verification
// Residency: metadata-only copy class; no runtime bytes move.
pub enum SlabCopyClass {
    PreadIntoSlab,
    DecodeInPlace,
    BorrowedView,
}

impl SlabCopyClass {
    fn tag(&self) -> &'static str {
        match self {
            Self::PreadIntoSlab => "pread_into_slab",
            Self::DecodeInPlace => "decode_in_place",
            Self::BorrowedView => "borrowed_view",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:slab-arena-copy-count:error
// Plane: Verification
// Residency: metadata-only rejection taxonomy.
pub enum SlabArenaCopyCountError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyPlan,
    EmptyLease(String),
    EmptyCopyEvent(String),
    EmptyAllocationSample(String),
    EmptySurface,
    DuplicatePlan(String),
    DuplicateLease(String),
    DuplicateCopyEvent(String),
    DuplicateAllocationSample(String),
    DuplicateSurface(String),
    DuplicateAnswerPacket(String),
    MissingLeaseTable(String),
    MissingSurfaceRef(String),
    MissingAnswerPacket(String),
    MissingRunEventLog(String),
    MissingRollback(String),
    MissingAdmission,
    MissingScopeRex,
    MissingSovereignGate,
    MissingCompatibilityFence(String),
    MissingCancelGroup(String),
    MissingFallback(String),
    MissingPurgePolicy(String),
    MissingRequiredMarker(String),
    ForbiddenMarker(String),
    MissingLayerSeparation,
    MissingVisibleSummary(String),
    ZeroCapacity(String),
    InvalidAlignment(String),
    ZeroLeaseLength(String),
    LeaseRangeOverflow(String),
    LeaseRangeOutOfBounds(String),
    LeaseRangeOverlap(String),
    UnknownLease(String),
    CopyCountExceeded(String),
    CopyBytesOutOfBounds(String),
    AllocationDeltaInCopyEvent(String),
    AllocationSpike(String),
    MissingAllocationSampleForLease(String),
    ProductStatusMismatch,
    HiddenRouteAuthority,
    RoutePolicyMutation,
    ScopeRexBypass,
    SovereignGateBypass,
    AnswerPacketSuppression,
    HiddenChainExposure,
    HiddenCloudRoute,
    SsdAsRamClaim,
    LiveBenchmarkAttempted,
    RuntimeBytesLoaded,
    ModelBytesLoaded,
    MetadataBudgetExceeded,
    BaselineUnbeaten(&'static str),
}

impl fmt::Display for SlabArenaCopyCountError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyPlan => write!(f, "missing SlabArena plan"),
            Self::EmptyLease(id) => write!(f, "plan `{id}` has no leases"),
            Self::EmptyCopyEvent(id) => write!(f, "plan `{id}` has no copy events"),
            Self::EmptyAllocationSample(id) => {
                write!(f, "plan `{id}` has no allocation samples")
            }
            Self::EmptySurface => write!(f, "missing visible surface"),
            Self::DuplicatePlan(id) => write!(f, "duplicate plan `{id}`"),
            Self::DuplicateLease(id) => write!(f, "duplicate lease `{id}`"),
            Self::DuplicateCopyEvent(id) => write!(f, "duplicate copy event `{id}`"),
            Self::DuplicateAllocationSample(id) => {
                write!(f, "duplicate allocation sample `{id}`")
            }
            Self::DuplicateSurface(id) => write!(f, "duplicate surface `{id}`"),
            Self::DuplicateAnswerPacket(id) => write!(f, "duplicate AnswerPacket `{id}`"),
            Self::MissingLeaseTable(id) => write!(f, "plan `{id}` missing lease table ref"),
            Self::MissingSurfaceRef(id) => write!(f, "plan `{id}` missing surface ref"),
            Self::MissingAnswerPacket(id) => write!(f, "`{id}` missing AnswerPacket ref"),
            Self::MissingRunEventLog(id) => write!(f, "`{id}` missing RunEventLog ref"),
            Self::MissingRollback(id) => write!(f, "`{id}` missing rollback ref"),
            Self::MissingAdmission => write!(f, "missing admission ref"),
            Self::MissingScopeRex => write!(f, "missing SCOPE-Rex ref"),
            Self::MissingSovereignGate => write!(f, "missing SovereignGate ref"),
            Self::MissingCompatibilityFence(id) => {
                write!(f, "`{id}` missing compatibility fence")
            }
            Self::MissingCancelGroup(id) => write!(f, "`{id}` missing cancel group"),
            Self::MissingFallback(id) => write!(f, "`{id}` missing fallback"),
            Self::MissingPurgePolicy(id) => write!(f, "plan `{id}` missing purge policy"),
            Self::MissingRequiredMarker(marker) => write!(f, "missing marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}`"),
            Self::MissingLayerSeparation => write!(f, "L1/L2/L3 separation missing"),
            Self::MissingVisibleSummary(id) => write!(f, "`{id}` missing visible summary"),
            Self::ZeroCapacity(id) => write!(f, "plan `{id}` has zero capacity"),
            Self::InvalidAlignment(id) => write!(f, "plan `{id}` has invalid alignment"),
            Self::ZeroLeaseLength(id) => write!(f, "lease `{id}` has zero length"),
            Self::LeaseRangeOverflow(id) => write!(f, "lease `{id}` range overflows"),
            Self::LeaseRangeOutOfBounds(id) => write!(f, "lease `{id}` range out of bounds"),
            Self::LeaseRangeOverlap(id) => write!(f, "lease `{id}` overlaps another lease"),
            Self::UnknownLease(id) => write!(f, "unknown lease `{id}`"),
            Self::CopyCountExceeded(id) => write!(f, "copy event `{id}` exceeds expected copies"),
            Self::CopyBytesOutOfBounds(id) => write!(f, "copy event `{id}` copies too many bytes"),
            Self::AllocationDeltaInCopyEvent(id) => {
                write!(f, "copy event `{id}` reports allocation delta")
            }
            Self::AllocationSpike(id) => write!(f, "allocation sample `{id}` has a spike"),
            Self::MissingAllocationSampleForLease(id) => {
                write!(f, "lease `{id}` has no allocation sample")
            }
            Self::ProductStatusMismatch => write!(f, "product status promoted beyond Pro Research"),
            Self::HiddenRouteAuthority => write!(f, "hidden route authority attempted"),
            Self::RoutePolicyMutation => write!(f, "route policy mutation attempted"),
            Self::ScopeRexBypass => write!(f, "SCOPE-Rex bypass attempted"),
            Self::SovereignGateBypass => write!(f, "SovereignGate bypass attempted"),
            Self::AnswerPacketSuppression => write!(f, "AnswerPacket suppression attempted"),
            Self::HiddenChainExposure => write!(f, "hidden chain exposure attempted"),
            Self::HiddenCloudRoute => write!(f, "hidden cloud route attempted"),
            Self::SsdAsRamClaim => write!(f, "SSD-as-RAM claim attempted"),
            Self::LiveBenchmarkAttempted => write!(f, "metadata witness attempted live benchmark"),
            Self::RuntimeBytesLoaded => write!(f, "metadata witness loaded runtime bytes"),
            Self::ModelBytesLoaded => write!(f, "metadata witness loaded model bytes"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
            Self::BaselineUnbeaten(name) => write!(f, "baseline `{name}` was unbeaten"),
        }
    }
}

impl std::error::Error for SlabArenaCopyCountError {}

#[derive(Clone, Debug)]
// UAS: uas:slab-arena-copy-count:lease
// Plane: Assembly
// Residency: metadata-only range lease into a preallocated slab.
pub struct SlabArenaLease {
    pub lease_id: String,
    pub slab_id: String,
    pub byte_offset: u64,
    pub byte_len: u64,
    pub generation: u64,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub rollback_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence: String,
    pub cancel_group_ref: String,
    pub fallback_ref: String,
    pub visible_summary: String,
}

impl SlabArenaLease {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        lease_id: impl Into<String>,
        slab_id: impl Into<String>,
        byte_offset: u64,
        byte_len: u64,
        generation: u64,
        answer_packet_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        admission_ref: impl Into<String>,
        scope_rex_ref: impl Into<String>,
        sovereign_gate_ref: impl Into<String>,
        compatibility_fence: impl Into<String>,
        cancel_group_ref: impl Into<String>,
        fallback_ref: impl Into<String>,
        visible_summary: impl Into<String>,
    ) -> Result<Self, SlabArenaCopyCountError> {
        let lease = Self {
            lease_id: lease_id.into(),
            slab_id: slab_id.into(),
            byte_offset,
            byte_len,
            generation,
            answer_packet_ref: answer_packet_ref.into(),
            run_event_log_ref: run_event_log_ref.into(),
            rollback_ref: rollback_ref.into(),
            admission_ref: admission_ref.into(),
            scope_rex_ref: scope_rex_ref.into(),
            sovereign_gate_ref: sovereign_gate_ref.into(),
            compatibility_fence: compatibility_fence.into(),
            cancel_group_ref: cancel_group_ref.into(),
            fallback_ref: fallback_ref.into(),
            visible_summary: visible_summary.into(),
        };
        validate_lease_fields(&lease)?;
        Ok(lease)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:slab-arena-copy-count:copy-event
// Plane: Verification
// Residency: metadata-only copy-count trace event.
pub struct SlabArenaCopyEvent {
    pub event_id: String,
    pub lease_id: String,
    pub copy_class: SlabCopyClass,
    pub bytes_copied: u64,
    pub copy_count_delta: u32,
    pub expected_copy_count_delta: u32,
    pub allocation_count_delta: u32,
}

impl SlabArenaCopyEvent {
    pub fn new(
        event_id: impl Into<String>,
        lease_id: impl Into<String>,
        copy_class: SlabCopyClass,
        bytes_copied: u64,
        copy_count_delta: u32,
        expected_copy_count_delta: u32,
        allocation_count_delta: u32,
    ) -> Result<Self, SlabArenaCopyCountError> {
        let event = Self {
            event_id: event_id.into(),
            lease_id: lease_id.into(),
            copy_class,
            bytes_copied,
            copy_count_delta,
            expected_copy_count_delta,
            allocation_count_delta,
        };
        validate_nonempty("event_id", &event.event_id)?;
        validate_nonempty("lease_id", &event.lease_id)?;
        Ok(event)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:slab-arena-copy-count:allocation-sample
// Plane: Verification
// Residency: metadata-only token allocation sample.
pub struct SlabArenaAllocationSample {
    pub sample_id: String,
    pub lease_id: String,
    pub token_index: u64,
    pub new_allocation_count: u32,
    pub new_allocation_bytes: u64,
}

impl SlabArenaAllocationSample {
    pub fn new(
        sample_id: impl Into<String>,
        lease_id: impl Into<String>,
        token_index: u64,
        new_allocation_count: u32,
        new_allocation_bytes: u64,
    ) -> Result<Self, SlabArenaCopyCountError> {
        let sample = Self {
            sample_id: sample_id.into(),
            lease_id: lease_id.into(),
            token_index,
            new_allocation_count,
            new_allocation_bytes,
        };
        validate_nonempty("sample_id", &sample.sample_id)?;
        validate_nonempty("lease_id", &sample.lease_id)?;
        Ok(sample)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:slab-arena-copy-count:plan
// Plane: Assembly
// Residency: metadata-only preallocated CPU slab plan.
pub struct SlabArenaPlan {
    pub plan_id: String,
    pub slab_id: String,
    pub byte_capacity: u64,
    pub alignment: u64,
    pub owner_thread_or_actor: String,
    pub lease_table_ref: String,
    pub purge_policy: String,
    pub copy_count_expected: u32,
    pub max_per_token_allocation_count: u32,
    pub max_per_token_allocation_bytes: u64,
    pub surface_ref: String,
    pub visible_summary: String,
    pub leases: Vec<SlabArenaLease>,
    pub copy_events: Vec<SlabArenaCopyEvent>,
    pub allocation_samples: Vec<SlabArenaAllocationSample>,
}

impl SlabArenaPlan {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        plan_id: impl Into<String>,
        slab_id: impl Into<String>,
        byte_capacity: u64,
        alignment: u64,
        owner_thread_or_actor: impl Into<String>,
        lease_table_ref: impl Into<String>,
        purge_policy: impl Into<String>,
        copy_count_expected: u32,
        max_per_token_allocation_count: u32,
        max_per_token_allocation_bytes: u64,
        surface_ref: impl Into<String>,
        visible_summary: impl Into<String>,
        leases: Vec<SlabArenaLease>,
        copy_events: Vec<SlabArenaCopyEvent>,
        allocation_samples: Vec<SlabArenaAllocationSample>,
    ) -> Result<Self, SlabArenaCopyCountError> {
        let plan = Self {
            plan_id: plan_id.into(),
            slab_id: slab_id.into(),
            byte_capacity,
            alignment,
            owner_thread_or_actor: owner_thread_or_actor.into(),
            lease_table_ref: lease_table_ref.into(),
            purge_policy: purge_policy.into(),
            copy_count_expected,
            max_per_token_allocation_count,
            max_per_token_allocation_bytes,
            surface_ref: surface_ref.into(),
            visible_summary: visible_summary.into(),
            leases,
            copy_events,
            allocation_samples,
        };
        validate_plan(&plan)?;
        Ok(plan)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:slab-arena-copy-count:surface
// Plane: Verification
// Residency: visible metadata-only AnswerPacket surface.
pub struct SlabArenaSurface {
    pub surface_id: String,
    pub answer_packet_ref: String,
    pub body: String,
}

impl SlabArenaSurface {
    pub fn new(
        surface_id: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        body: impl Into<String>,
    ) -> Result<Self, SlabArenaCopyCountError> {
        let surface = Self {
            surface_id: surface_id.into(),
            answer_packet_ref: answer_packet_ref.into(),
            body: body.into(),
        };
        validate_surface(&surface)?;
        Ok(surface)
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
// UAS: uas:slab-arena-copy-count:metrics
// Plane: Verification
// Residency: derived metadata-only metrics.
pub struct SlabArenaCopyCountMetrics {
    pub plan_count: u64,
    pub lease_count: u64,
    pub copy_event_count: u64,
    pub allocation_sample_count: u64,
    pub surface_count: u64,
    pub answer_packet_count: u64,
    pub preallocated_bytes: u64,
    pub observed_copy_bytes: u64,
    pub max_copy_count: u32,
    pub max_expected_copy_count: u32,
    pub max_per_token_allocation_count: u32,
    pub max_per_token_allocation_bytes: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub max_metadata_bytes: u64,
    pub trace_success_bps: u32,
    pub unbounded_vec_growth_baseline_bps: u32,
    pub hidden_decode_copy_baseline_bps: u32,
    pub token_allocation_spike_baseline_bps: u32,
    pub live_authority_baseline_bps: u32,
    pub address: String,
}

#[derive(Clone, Debug)]
// UAS: uas:slab-arena-copy-count:witness
// Plane: Verification
// Residency: metadata-only witness; no live benchmark or model bytes.
pub struct SlabArenaCopyCountWitness {
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub trace_success_bps: u32,
    pub unbounded_vec_growth_baseline_bps: u32,
    pub hidden_decode_copy_baseline_bps: u32,
    pub token_allocation_spike_baseline_bps: u32,
    pub live_authority_baseline_bps: u32,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub max_metadata_bytes: u64,
    pub hidden_route_authority_attempted: bool,
    pub route_policy_mutation_attempted: bool,
    pub scope_rex_bypass_attempted: bool,
    pub sovereign_gate_bypass_attempted: bool,
    pub answer_packet_suppression_attempted: bool,
    pub hidden_chain_exposure_attempted: bool,
    pub hidden_cloud_route_attempted: bool,
    pub ssd_as_ram_claim_attempted: bool,
    pub live_benchmark_attempted: bool,
    pub plans: Vec<SlabArenaPlan>,
    pub surfaces: Vec<SlabArenaSurface>,
}

impl SlabArenaCopyCountWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        trace_success_bps: u32,
        unbounded_vec_growth_baseline_bps: u32,
        hidden_decode_copy_baseline_bps: u32,
        token_allocation_spike_baseline_bps: u32,
        live_authority_baseline_bps: u32,
        runtime_bytes_loaded: u64,
        model_bytes_loaded: u64,
        max_metadata_bytes: u64,
        hidden_route_authority_attempted: bool,
        route_policy_mutation_attempted: bool,
        scope_rex_bypass_attempted: bool,
        sovereign_gate_bypass_attempted: bool,
        answer_packet_suppression_attempted: bool,
        hidden_chain_exposure_attempted: bool,
        hidden_cloud_route_attempted: bool,
        ssd_as_ram_claim_attempted: bool,
        live_benchmark_attempted: bool,
        plans: Vec<SlabArenaPlan>,
        surfaces: Vec<SlabArenaSurface>,
    ) -> Result<Self, SlabArenaCopyCountError> {
        let witness = Self {
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            trace_success_bps,
            unbounded_vec_growth_baseline_bps,
            hidden_decode_copy_baseline_bps,
            token_allocation_spike_baseline_bps,
            live_authority_baseline_bps,
            runtime_bytes_loaded,
            model_bytes_loaded,
            max_metadata_bytes,
            hidden_route_authority_attempted,
            route_policy_mutation_attempted,
            scope_rex_bypass_attempted,
            sovereign_gate_bypass_attempted,
            answer_packet_suppression_attempted,
            hidden_chain_exposure_attempted,
            hidden_cloud_route_attempted,
            ssd_as_ram_claim_attempted,
            live_benchmark_attempted,
            plans,
            surfaces,
        };
        validate_witness(&witness)?;
        Ok(witness)
    }

    pub fn metrics(&self) -> SlabArenaCopyCountMetrics {
        let mut answer_packets = BTreeSet::new();
        let mut metrics = SlabArenaCopyCountMetrics {
            plan_count: self.plans.len() as u64,
            surface_count: self.surfaces.len() as u64,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            model_bytes_loaded: self.model_bytes_loaded,
            max_metadata_bytes: self.max_metadata_bytes,
            trace_success_bps: self.trace_success_bps,
            unbounded_vec_growth_baseline_bps: self.unbounded_vec_growth_baseline_bps,
            hidden_decode_copy_baseline_bps: self.hidden_decode_copy_baseline_bps,
            token_allocation_spike_baseline_bps: self.token_allocation_spike_baseline_bps,
            live_authority_baseline_bps: self.live_authority_baseline_bps,
            address: self.address(),
            ..SlabArenaCopyCountMetrics::default()
        };
        for surface in &self.surfaces {
            answer_packets.insert(surface.answer_packet_ref.clone());
        }
        for plan in &self.plans {
            metrics.preallocated_bytes = metrics
                .preallocated_bytes
                .saturating_add(plan.byte_capacity);
            metrics.max_expected_copy_count = metrics
                .max_expected_copy_count
                .max(plan.copy_count_expected);
            metrics.max_per_token_allocation_count = metrics
                .max_per_token_allocation_count
                .max(plan.max_per_token_allocation_count);
            metrics.max_per_token_allocation_bytes = metrics
                .max_per_token_allocation_bytes
                .max(plan.max_per_token_allocation_bytes);
            for lease in &plan.leases {
                metrics.lease_count += 1;
                answer_packets.insert(lease.answer_packet_ref.clone());
            }
            for event in &plan.copy_events {
                metrics.copy_event_count += 1;
                metrics.observed_copy_bytes = metrics
                    .observed_copy_bytes
                    .saturating_add(event.bytes_copied);
                metrics.max_copy_count = metrics.max_copy_count.max(event.copy_count_delta);
            }
            metrics.allocation_sample_count += plan.allocation_samples.len() as u64;
        }
        metrics.answer_packet_count = answer_packets.len() as u64;
        metrics
    }

    pub fn address(&self) -> String {
        let mut parts = Vec::with_capacity(16 + self.plans.len() * 8 + self.surfaces.len() * 3);
        parts.push(format!("product={:?}", self.product_build));
        parts.push(format!("status={:?}", self.pro_status));
        parts.push(format!("authority={}", self.route_authority));
        parts.push(format!("trace={}", self.trace_success_bps));

        let mut plans = self.plans.iter().collect::<Vec<_>>();
        plans.sort_by(|left, right| left.plan_id.cmp(&right.plan_id));
        for plan in plans {
            parts.push(format!(
                "plan={}|{}|{}|{}|{}|{}|{}|{}",
                plan.plan_id,
                plan.slab_id,
                plan.byte_capacity,
                plan.alignment,
                plan.owner_thread_or_actor,
                plan.lease_table_ref,
                plan.purge_policy,
                plan.copy_count_expected
            ));
            let mut leases = plan.leases.iter().collect::<Vec<_>>();
            leases.sort_by(|left, right| left.lease_id.cmp(&right.lease_id));
            for lease in leases {
                parts.push(format!(
                    "lease={}|{}|{}|{}|{}|{}|{}|{}",
                    lease.lease_id,
                    lease.slab_id,
                    lease.byte_offset,
                    lease.byte_len,
                    lease.generation,
                    lease.answer_packet_ref,
                    lease.rollback_ref,
                    lease.compatibility_fence
                ));
            }
            let mut events = plan.copy_events.iter().collect::<Vec<_>>();
            events.sort_by(|left, right| left.event_id.cmp(&right.event_id));
            for event in events {
                parts.push(format!(
                    "event={}|{}|{}|{}|{}|{}",
                    event.event_id,
                    event.lease_id,
                    event.copy_class.tag(),
                    event.bytes_copied,
                    event.copy_count_delta,
                    event.expected_copy_count_delta
                ));
            }
            let mut samples = plan.allocation_samples.iter().collect::<Vec<_>>();
            samples.sort_by(|left, right| left.sample_id.cmp(&right.sample_id));
            for sample in samples {
                parts.push(format!(
                    "sample={}|{}|{}|{}|{}",
                    sample.sample_id,
                    sample.lease_id,
                    sample.token_index,
                    sample.new_allocation_count,
                    sample.new_allocation_bytes
                ));
            }
        }

        let mut surfaces = self.surfaces.iter().collect::<Vec<_>>();
        surfaces.sort_by(|left, right| left.surface_id.cmp(&right.surface_id));
        for surface in surfaces {
            parts.push(format!(
                "surface={}|{}|{}",
                surface.surface_id, surface.answer_packet_ref, surface.body
            ));
        }

        format!(
            "uas:slab-arena-copy-count:{}",
            sha256_hex(parts.join("\n").as_bytes())
        )
    }
}

fn validate_witness(witness: &SlabArenaCopyCountWitness) -> Result<(), SlabArenaCopyCountError> {
    if witness.plans.is_empty() {
        return Err(SlabArenaCopyCountError::EmptyPlan);
    }
    if witness.surfaces.is_empty() {
        return Err(SlabArenaCopyCountError::EmptySurface);
    }
    if witness.product_build != ProductBuild::Pro
        || witness.pro_status != ProStatus::ResearchCandidate
        || witness.route_authority != "slab_trace_only"
    {
        return Err(SlabArenaCopyCountError::ProductStatusMismatch);
    }
    if witness.trace_success_bps < MIN_TRACE_SUCCESS_BPS {
        return Err(SlabArenaCopyCountError::BaselineUnbeaten("trace_success"));
    }
    if witness.unbounded_vec_growth_baseline_bps >= witness.trace_success_bps {
        return Err(SlabArenaCopyCountError::BaselineUnbeaten(
            "unbounded_vec_growth",
        ));
    }
    if witness.hidden_decode_copy_baseline_bps >= witness.trace_success_bps {
        return Err(SlabArenaCopyCountError::BaselineUnbeaten(
            "hidden_decode_copy",
        ));
    }
    if witness.token_allocation_spike_baseline_bps >= witness.trace_success_bps {
        return Err(SlabArenaCopyCountError::BaselineUnbeaten(
            "token_allocation_spike",
        ));
    }
    if witness.live_authority_baseline_bps >= witness.trace_success_bps {
        return Err(SlabArenaCopyCountError::BaselineUnbeaten("live_authority"));
    }
    if witness.hidden_route_authority_attempted {
        return Err(SlabArenaCopyCountError::HiddenRouteAuthority);
    }
    if witness.route_policy_mutation_attempted {
        return Err(SlabArenaCopyCountError::RoutePolicyMutation);
    }
    if witness.scope_rex_bypass_attempted {
        return Err(SlabArenaCopyCountError::ScopeRexBypass);
    }
    if witness.sovereign_gate_bypass_attempted {
        return Err(SlabArenaCopyCountError::SovereignGateBypass);
    }
    if witness.answer_packet_suppression_attempted {
        return Err(SlabArenaCopyCountError::AnswerPacketSuppression);
    }
    if witness.hidden_chain_exposure_attempted {
        return Err(SlabArenaCopyCountError::HiddenChainExposure);
    }
    if witness.hidden_cloud_route_attempted {
        return Err(SlabArenaCopyCountError::HiddenCloudRoute);
    }
    if witness.ssd_as_ram_claim_attempted {
        return Err(SlabArenaCopyCountError::SsdAsRamClaim);
    }
    if witness.live_benchmark_attempted {
        return Err(SlabArenaCopyCountError::LiveBenchmarkAttempted);
    }
    if witness.runtime_bytes_loaded != 0 {
        return Err(SlabArenaCopyCountError::RuntimeBytesLoaded);
    }
    if witness.model_bytes_loaded != 0 {
        return Err(SlabArenaCopyCountError::ModelBytesLoaded);
    }
    if witness.max_metadata_bytes > MAX_METADATA_BYTES {
        return Err(SlabArenaCopyCountError::MetadataBudgetExceeded);
    }

    let mut seen_plans = HashSet::new();
    let mut seen_surfaces = HashSet::new();
    let mut seen_answer_packets = HashSet::new();
    let surface_ids = witness
        .surfaces
        .iter()
        .map(|surface| surface.surface_id.as_str())
        .collect::<HashSet<_>>();
    for surface in &witness.surfaces {
        if !seen_surfaces.insert(surface.surface_id.clone()) {
            return Err(SlabArenaCopyCountError::DuplicateSurface(
                surface.surface_id.clone(),
            ));
        }
        if !seen_answer_packets.insert(surface.answer_packet_ref.clone()) {
            return Err(SlabArenaCopyCountError::DuplicateAnswerPacket(
                surface.answer_packet_ref.clone(),
            ));
        }
        validate_surface(surface)?;
    }
    for plan in &witness.plans {
        if !seen_plans.insert(plan.plan_id.clone()) {
            return Err(SlabArenaCopyCountError::DuplicatePlan(plan.plan_id.clone()));
        }
        if !surface_ids.contains(plan.surface_ref.as_str()) {
            return Err(SlabArenaCopyCountError::MissingSurfaceRef(
                plan.plan_id.clone(),
            ));
        }
        validate_plan(plan)?;
    }
    Ok(())
}

fn validate_plan(plan: &SlabArenaPlan) -> Result<(), SlabArenaCopyCountError> {
    validate_nonempty("plan_id", &plan.plan_id)?;
    validate_nonempty("slab_id", &plan.slab_id)?;
    validate_nonempty("owner_thread_or_actor", &plan.owner_thread_or_actor)?;
    validate_prefixed(
        &plan.plan_id,
        "lease_table_ref",
        &plan.lease_table_ref,
        LEASE_TABLE_PREFIX,
        SlabArenaCopyCountError::MissingLeaseTable(plan.plan_id.clone()),
    )?;
    validate_prefixed(
        &plan.plan_id,
        "purge_policy",
        &plan.purge_policy,
        PURGE_POLICY_PREFIX,
        SlabArenaCopyCountError::MissingPurgePolicy(plan.plan_id.clone()),
    )?;
    validate_prefixed(
        &plan.plan_id,
        "surface_ref",
        &plan.surface_ref,
        SURFACE_PREFIX,
        SlabArenaCopyCountError::MissingSurfaceRef(plan.plan_id.clone()),
    )?;
    if plan.byte_capacity == 0 {
        return Err(SlabArenaCopyCountError::ZeroCapacity(plan.plan_id.clone()));
    }
    if !plan.alignment.is_power_of_two()
        || !(MIN_ALIGNMENT..=MAX_ALIGNMENT).contains(&plan.alignment)
    {
        return Err(SlabArenaCopyCountError::InvalidAlignment(
            plan.plan_id.clone(),
        ));
    }
    if plan.leases.is_empty() {
        return Err(SlabArenaCopyCountError::EmptyLease(plan.plan_id.clone()));
    }
    if plan.copy_events.is_empty() {
        return Err(SlabArenaCopyCountError::EmptyCopyEvent(
            plan.plan_id.clone(),
        ));
    }
    if plan.allocation_samples.is_empty() {
        return Err(SlabArenaCopyCountError::EmptyAllocationSample(
            plan.plan_id.clone(),
        ));
    }
    if !summary_is_honest(&plan.visible_summary) {
        return Err(SlabArenaCopyCountError::MissingVisibleSummary(
            plan.plan_id.clone(),
        ));
    }

    let mut seen_leases = HashSet::new();
    let mut ranges = Vec::with_capacity(plan.leases.len());
    let mut lease_by_id = HashMap::with_capacity(plan.leases.len());
    for lease in &plan.leases {
        validate_lease_fields(lease)?;
        if lease.slab_id != plan.slab_id {
            return Err(SlabArenaCopyCountError::UnknownLease(
                lease.lease_id.clone(),
            ));
        }
        if !seen_leases.insert(lease.lease_id.clone()) {
            return Err(SlabArenaCopyCountError::DuplicateLease(
                lease.lease_id.clone(),
            ));
        }
        let end = lease
            .byte_offset
            .checked_add(lease.byte_len)
            .ok_or_else(|| SlabArenaCopyCountError::LeaseRangeOverflow(lease.lease_id.clone()))?;
        if end > plan.byte_capacity {
            return Err(SlabArenaCopyCountError::LeaseRangeOutOfBounds(
                lease.lease_id.clone(),
            ));
        }
        ranges.push((lease.byte_offset, end, lease.lease_id.clone()));
        lease_by_id.insert(lease.lease_id.clone(), lease.byte_len);
    }
    ranges.sort_by_key(|(start, _, _)| *start);
    for pair in ranges.windows(2) {
        if pair[0].1 > pair[1].0 {
            return Err(SlabArenaCopyCountError::LeaseRangeOverlap(
                pair[1].2.clone(),
            ));
        }
    }

    let mut seen_events = HashSet::new();
    let mut total_copy_count = 0_u32;
    for event in &plan.copy_events {
        if !seen_events.insert(event.event_id.clone()) {
            return Err(SlabArenaCopyCountError::DuplicateCopyEvent(
                event.event_id.clone(),
            ));
        }
        let lease_len = lease_by_id
            .get(&event.lease_id)
            .ok_or_else(|| SlabArenaCopyCountError::UnknownLease(event.lease_id.clone()))?;
        if event.copy_count_delta > event.expected_copy_count_delta {
            return Err(SlabArenaCopyCountError::CopyCountExceeded(
                event.event_id.clone(),
            ));
        }
        if event.bytes_copied > *lease_len {
            return Err(SlabArenaCopyCountError::CopyBytesOutOfBounds(
                event.event_id.clone(),
            ));
        }
        if event.allocation_count_delta != 0 {
            return Err(SlabArenaCopyCountError::AllocationDeltaInCopyEvent(
                event.event_id.clone(),
            ));
        }
        total_copy_count = total_copy_count.saturating_add(event.copy_count_delta);
    }
    if total_copy_count > plan.copy_count_expected {
        return Err(SlabArenaCopyCountError::CopyCountExceeded(
            plan.plan_id.clone(),
        ));
    }

    let mut seen_samples = HashSet::new();
    let mut sampled_leases = HashSet::new();
    for sample in &plan.allocation_samples {
        if !seen_samples.insert(sample.sample_id.clone()) {
            return Err(SlabArenaCopyCountError::DuplicateAllocationSample(
                sample.sample_id.clone(),
            ));
        }
        if !lease_by_id.contains_key(&sample.lease_id) {
            return Err(SlabArenaCopyCountError::UnknownLease(
                sample.lease_id.clone(),
            ));
        }
        if sample.new_allocation_count > plan.max_per_token_allocation_count
            || sample.new_allocation_bytes > plan.max_per_token_allocation_bytes
        {
            return Err(SlabArenaCopyCountError::AllocationSpike(
                sample.sample_id.clone(),
            ));
        }
        sampled_leases.insert(sample.lease_id.clone());
    }
    for lease_id in lease_by_id.keys() {
        if !sampled_leases.contains(lease_id) {
            return Err(SlabArenaCopyCountError::MissingAllocationSampleForLease(
                lease_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_lease_fields(lease: &SlabArenaLease) -> Result<(), SlabArenaCopyCountError> {
    validate_nonempty("lease_id", &lease.lease_id)?;
    validate_nonempty("slab_id", &lease.slab_id)?;
    if lease.byte_len == 0 {
        return Err(SlabArenaCopyCountError::ZeroLeaseLength(
            lease.lease_id.clone(),
        ));
    }
    if lease.generation == 0 {
        return Err(SlabArenaCopyCountError::MissingField("generation"));
    }
    validate_prefixed(
        &lease.lease_id,
        "answer_packet_ref",
        &lease.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
        SlabArenaCopyCountError::MissingAnswerPacket(lease.lease_id.clone()),
    )?;
    validate_prefixed(
        &lease.lease_id,
        "run_event_log_ref",
        &lease.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
        SlabArenaCopyCountError::MissingRunEventLog(lease.lease_id.clone()),
    )?;
    validate_prefixed(
        &lease.lease_id,
        "rollback_ref",
        &lease.rollback_ref,
        ROLLBACK_PREFIX,
        SlabArenaCopyCountError::MissingRollback(lease.lease_id.clone()),
    )?;
    validate_prefixed(
        &lease.lease_id,
        "admission_ref",
        &lease.admission_ref,
        ADMISSION_PREFIX,
        SlabArenaCopyCountError::MissingAdmission,
    )?;
    validate_prefixed(
        &lease.lease_id,
        "scope_rex_ref",
        &lease.scope_rex_ref,
        SCOPE_REX_PREFIX,
        SlabArenaCopyCountError::MissingScopeRex,
    )?;
    validate_prefixed(
        &lease.lease_id,
        "sovereign_gate_ref",
        &lease.sovereign_gate_ref,
        SOVEREIGN_GATE_PREFIX,
        SlabArenaCopyCountError::MissingSovereignGate,
    )?;
    validate_prefixed(
        &lease.lease_id,
        "compatibility_fence",
        &lease.compatibility_fence,
        COMPATIBILITY_FENCE_PREFIX,
        SlabArenaCopyCountError::MissingCompatibilityFence(lease.lease_id.clone()),
    )?;
    validate_prefixed(
        &lease.lease_id,
        "cancel_group_ref",
        &lease.cancel_group_ref,
        CANCEL_GROUP_PREFIX,
        SlabArenaCopyCountError::MissingCancelGroup(lease.lease_id.clone()),
    )?;
    validate_prefixed(
        &lease.lease_id,
        "fallback_ref",
        &lease.fallback_ref,
        FALLBACK_PREFIX,
        SlabArenaCopyCountError::MissingFallback(lease.lease_id.clone()),
    )?;
    if !summary_is_honest(&lease.visible_summary) {
        return Err(SlabArenaCopyCountError::MissingVisibleSummary(
            lease.lease_id.clone(),
        ));
    }
    Ok(())
}

fn validate_surface(surface: &SlabArenaSurface) -> Result<(), SlabArenaCopyCountError> {
    validate_nonempty("surface_id", &surface.surface_id)?;
    validate_prefixed(
        &surface.surface_id,
        "answer_packet_ref",
        &surface.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
        SlabArenaCopyCountError::MissingAnswerPacket(surface.surface_id.clone()),
    )?;
    if !summary_is_honest(&surface.body) {
        return Err(SlabArenaCopyCountError::MissingVisibleSummary(
            surface.surface_id.clone(),
        ));
    }
    for marker in [
        "metadata-only",
        "L1",
        "L2 remains",
        "L3",
        "AnswerPacket",
        "rollback",
    ] {
        if !surface.body.contains(marker) {
            return Err(SlabArenaCopyCountError::MissingRequiredMarker(
                marker.to_string(),
            ));
        }
    }
    for marker in ["SSD is RAM", "live 70B promoted", "hidden route authority"] {
        if surface.body.contains(marker) {
            return Err(SlabArenaCopyCountError::ForbiddenMarker(marker.to_string()));
        }
    }
    Ok(())
}

fn validate_prefixed(
    id: &str,
    field: &'static str,
    value: &str,
    prefix: &str,
    error: SlabArenaCopyCountError,
) -> Result<(), SlabArenaCopyCountError> {
    validate_nonempty(field, value)?;
    if !value.starts_with(prefix) || value.len() == prefix.len() {
        return Err(error);
    }
    validate_nonempty("id", id)?;
    Ok(())
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), SlabArenaCopyCountError> {
    if value.is_empty() {
        return Err(SlabArenaCopyCountError::MissingField(field));
    }
    if value.trim() != value {
        return Err(SlabArenaCopyCountError::FieldHasSurroundingWhitespace(
            field,
        ));
    }
    if value.chars().any(char::is_control) {
        return Err(SlabArenaCopyCountError::FieldContainsControlCharacter(
            field,
        ));
    }
    Ok(())
}

fn summary_is_honest(summary: &str) -> bool {
    summary.len() >= MIN_VISIBLE_SUMMARY_BYTES
        && summary.contains("metadata-only")
        && summary.contains("L1")
        && summary.contains("L2")
        && summary.contains("L3")
        && summary.contains("AnswerPacket")
        && summary.contains("rollback")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_witness_binds_preallocation_copy_and_allocation_proof() {
        let witness = fixture_witness().expect("fixture witness");
        let metrics = witness.metrics();

        assert_eq!(metrics.plan_count, 2);
        assert_eq!(metrics.lease_count, 4);
        assert_eq!(metrics.copy_event_count, 6);
        assert_eq!(metrics.max_per_token_allocation_count, 0);
        assert_eq!(metrics.max_per_token_allocation_bytes, 0);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert!(metrics
            .address
            .starts_with("uas:slab-arena-copy-count:sha256:"));
    }

    #[test]
    fn address_is_deterministic_under_plan_order() {
        let witness = fixture_witness().expect("fixture witness");
        let mut reversed = witness.plans.clone();
        reversed.reverse();
        let same = SlabArenaCopyCountWitness::new(
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
        )
        .expect("reordered witness");

        assert_eq!(witness.address(), same.address());
    }

    #[test]
    fn rejects_overlap_allocation_spike_hidden_authority_and_live_runtime() {
        assert!(matches!(
            reject_one_plan(|plan| plan.leases[1].byte_offset = 512),
            Err(SlabArenaCopyCountError::LeaseRangeOverlap(_))
        ));
        assert!(matches!(
            reject_one_plan(|plan| plan.allocation_samples[0].new_allocation_count = 1),
            Err(SlabArenaCopyCountError::AllocationSpike(_))
        ));
        assert!(matches!(
            reject_witness(|witness| witness.hidden_route_authority_attempted = true),
            Err(SlabArenaCopyCountError::HiddenRouteAuthority)
        ));
        assert!(matches!(
            reject_witness(|witness| witness.runtime_bytes_loaded = 1),
            Err(SlabArenaCopyCountError::RuntimeBytesLoaded)
        ));
        assert!(matches!(
            reject_witness(|witness| witness.pro_status = ProStatus::Live),
            Err(SlabArenaCopyCountError::ProductStatusMismatch)
        ));
    }

    fn reject_witness(
        mutate: impl FnOnce(&mut SlabArenaCopyCountWitness),
    ) -> Result<SlabArenaCopyCountWitness, SlabArenaCopyCountError> {
        let mut witness = fixture_witness()?;
        mutate(&mut witness);
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

    fn reject_one_plan(
        mutate: impl FnOnce(&mut SlabArenaPlan),
    ) -> Result<SlabArenaCopyCountWitness, SlabArenaCopyCountError> {
        let mut witness = fixture_witness()?;
        mutate(&mut witness.plans[0]);
        SlabArenaCopyCountWitness::new(
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
            witness.plans,
            witness.surfaces,
        )
    }

    fn fixture_witness() -> Result<SlabArenaCopyCountWitness, SlabArenaCopyCountError> {
        SlabArenaCopyCountWitness::new(
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
        )
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
}
