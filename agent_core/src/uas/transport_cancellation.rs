//! Transport cancellation contracts.
//!
//! This is a metadata-only witness for the ColdStream cancellation gate. It
//! proves route changes cancel obsolete in-flight reads and reject stale slabs
//! before execution, without loading live transport/model/runtime bytes.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const TRANSPORT_CANCELLATION_CURSOR: &str = "transport_cancellation";
pub const TRANSPORT_CANCELLATION_NEXT_CURSOR: &str = "cache_policy_pollution";

const PAGE_RUN_PREFIX: &str = "page_run:";
const READ_TRACE_PREFIX: &str = "read_trace:";
const SLAB_PREFIX: &str = "slab:";
const CANCEL_GROUP_PREFIX: &str = "cancel_group:";
const CANCEL_TOKEN_PREFIX: &str = "cancel_token:";
const ROUTE_CHANGE_PREFIX: &str = "route_change:";
const LEASE_PREFIX: &str = "lease:";
const SCHEDULER_PREFIX: &str = "scheduler:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const MAX_METADATA_BYTES: u64 = 256 * 1024;
const MIN_VISIBLE_CAVEAT_BYTES: usize = 144;
const MIN_CANCELLATION_SUCCESS_BPS: u32 = 9_500;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:transport-cancellation:state
// Plane: Controller
// Residency: metadata-only cancellation state; no transport bytes loaded.
pub enum TransportCancellationState {
    CompletedCurrentRoute,
    CancelledObsoleteRead,
    RejectedStaleSlab,
}

impl TransportCancellationState {
    fn tag(&self) -> &'static str {
        match self {
            Self::CompletedCurrentRoute => "completed_current_route",
            Self::CancelledObsoleteRead => "cancelled_obsolete_read",
            Self::RejectedStaleSlab => "rejected_stale_slab",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:transport-cancellation:error
// Plane: Verification
// Residency: metadata-only rejection taxonomy.
pub enum TransportCancellationError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyRun,
    EmptySurface,
    DuplicateRun(String),
    DuplicateSurface(String),
    DuplicateAnswerPacket(String),
    MissingPageRun(String),
    MissingReadTrace(String),
    MissingSlab(String),
    MissingCancelGroup(String),
    MissingCancelToken(String),
    MissingRouteChange(String),
    MissingLease(String),
    MissingScheduler(String),
    MissingAnswerPacket(String),
    MissingRunEventLog(String),
    MissingRollback(String),
    MissingAdmission,
    MissingScopeRex,
    MissingSovereignGate,
    MissingCompatibilityFence(String),
    MissingVisibleCaveat(String),
    MissingRequiredMarker(String),
    ForbiddenMarker(String),
    ZeroRouteEpoch(String),
    ZeroScheduledBytes(String),
    CancelledRunEnteredExecution(String),
    CancelledRunMissingRejectedRead(String),
    CancelledRunMissingCancelledBytes(String),
    StaleRunEnteredExecution(String),
    StaleRunMissingRejectedSlab(String),
    CurrentRunRejectedAsStale(String),
    CurrentRunCancelledBytes(String),
    MissingCurrentRun,
    MissingCancelledRun,
    MissingStaleRejectionRun,
    MissingLayerSeparation,
    ProductStatusMismatch,
    HiddenRouteAuthority,
    RoutePolicyMutation,
    GateBypass,
    AnswerPacketSuppression,
    HiddenChainExposure,
    HiddenCloudRoute,
    SsdAsRamClaim,
    MasPromotionAttempted,
    LiveBenchmarkAttempted,
    RuntimeBytesLoaded,
    ModelBytesLoaded,
    TransportRuntimeBytesLoaded,
    MetadataBudgetExceeded,
    BaselineUnbeaten(&'static str),
}

impl fmt::Display for TransportCancellationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyRun => write!(f, "missing cancellation run"),
            Self::EmptySurface => write!(f, "missing visible cancellation surface"),
            Self::DuplicateRun(id) => write!(f, "duplicate cancellation run `{id}`"),
            Self::DuplicateSurface(id) => write!(f, "duplicate visible surface `{id}`"),
            Self::DuplicateAnswerPacket(id) => write!(f, "duplicate AnswerPacket `{id}`"),
            Self::MissingPageRun(id) => write!(f, "`{id}` missing page run ref"),
            Self::MissingReadTrace(id) => write!(f, "`{id}` missing read trace ref"),
            Self::MissingSlab(id) => write!(f, "`{id}` missing slab ref"),
            Self::MissingCancelGroup(id) => write!(f, "`{id}` missing cancel group ref"),
            Self::MissingCancelToken(id) => write!(f, "`{id}` missing cancel token ref"),
            Self::MissingRouteChange(id) => write!(f, "`{id}` missing route change ref"),
            Self::MissingLease(id) => write!(f, "`{id}` missing lease ref"),
            Self::MissingScheduler(id) => write!(f, "`{id}` missing scheduler ref"),
            Self::MissingAnswerPacket(id) => write!(f, "`{id}` missing AnswerPacket ref"),
            Self::MissingRunEventLog(id) => write!(f, "`{id}` missing RunEventLog ref"),
            Self::MissingRollback(id) => write!(f, "`{id}` missing rollback ref"),
            Self::MissingAdmission => write!(f, "missing admission ref"),
            Self::MissingScopeRex => write!(f, "missing SCOPE-Rex ref"),
            Self::MissingSovereignGate => write!(f, "missing SovereignGate ref"),
            Self::MissingCompatibilityFence(id) => write!(f, "`{id}` missing compatibility fence"),
            Self::MissingVisibleCaveat(id) => write!(f, "`{id}` missing visible caveat"),
            Self::MissingRequiredMarker(marker) => write!(f, "missing marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}`"),
            Self::ZeroRouteEpoch(id) => write!(f, "`{id}` has zero route epoch"),
            Self::ZeroScheduledBytes(id) => write!(f, "`{id}` has zero scheduled bytes"),
            Self::CancelledRunEnteredExecution(id) => {
                write!(f, "`{id}` cancelled obsolete run entered execution")
            }
            Self::CancelledRunMissingRejectedRead(id) => {
                write!(f, "`{id}` did not reject obsolete in-flight read")
            }
            Self::CancelledRunMissingCancelledBytes(id) => {
                write!(f, "`{id}` has no cancelled bytes")
            }
            Self::StaleRunEnteredExecution(id) => write!(f, "`{id}` stale slab entered execution"),
            Self::StaleRunMissingRejectedSlab(id) => {
                write!(f, "`{id}` did not reject stale slab")
            }
            Self::CurrentRunRejectedAsStale(id) => {
                write!(f, "`{id}` current route was marked stale")
            }
            Self::CurrentRunCancelledBytes(id) => write!(f, "`{id}` current route cancelled bytes"),
            Self::MissingCurrentRun => write!(f, "missing completed current route run"),
            Self::MissingCancelledRun => write!(f, "missing cancelled obsolete read run"),
            Self::MissingStaleRejectionRun => write!(f, "missing stale slab rejection run"),
            Self::MissingLayerSeparation => write!(f, "L1/L2/L3 separation missing"),
            Self::ProductStatusMismatch => write!(f, "product status promoted beyond Pro Research"),
            Self::HiddenRouteAuthority => write!(f, "hidden route authority attempted"),
            Self::RoutePolicyMutation => write!(f, "route policy mutation attempted"),
            Self::GateBypass => write!(f, "cancellation gate bypass attempted"),
            Self::AnswerPacketSuppression => write!(f, "AnswerPacket suppression attempted"),
            Self::HiddenChainExposure => write!(f, "hidden chain exposure attempted"),
            Self::HiddenCloudRoute => write!(f, "hidden cloud route attempted"),
            Self::SsdAsRamClaim => write!(f, "SSD-as-RAM claim attempted"),
            Self::MasPromotionAttempted => write!(f, "MAS/Live promotion attempted"),
            Self::LiveBenchmarkAttempted => write!(f, "metadata witness attempted live benchmark"),
            Self::RuntimeBytesLoaded => write!(f, "metadata witness loaded runtime bytes"),
            Self::ModelBytesLoaded => write!(f, "metadata witness loaded model bytes"),
            Self::TransportRuntimeBytesLoaded => {
                write!(f, "metadata witness loaded transport bytes")
            }
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
            Self::BaselineUnbeaten(name) => write!(f, "baseline `{name}` was unbeaten"),
        }
    }
}

impl std::error::Error for TransportCancellationError {}

#[derive(Clone, Debug)]
// UAS: uas:transport-cancellation:run
// Plane: Controller
// Residency: metadata-only cancellation run with stale-slab execution guard.
pub struct TransportCancellationRun {
    pub run_id: String,
    pub mission_id: String,
    pub route_id: String,
    pub route_epoch: u64,
    pub state: TransportCancellationState,
    pub page_run_ref: String,
    pub read_trace_ref: String,
    pub slab_ref: String,
    pub cancellation_group_ref: String,
    pub cancellation_token_ref: String,
    pub route_change_ref: String,
    pub lease_ref: String,
    pub scheduler_ref: String,
    pub scheduled_bytes: u64,
    pub cancelled_bytes: u64,
    pub obsolete_inflight_read_rejected: bool,
    pub stale_slab_execution_rejected: bool,
    pub entered_execution: bool,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub rollback_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence: String,
    pub visible_caveat: String,
}

impl TransportCancellationRun {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        run_id: impl Into<String>,
        mission_id: impl Into<String>,
        route_id: impl Into<String>,
        route_epoch: u64,
        state: TransportCancellationState,
        page_run_ref: impl Into<String>,
        read_trace_ref: impl Into<String>,
        slab_ref: impl Into<String>,
        cancellation_group_ref: impl Into<String>,
        cancellation_token_ref: impl Into<String>,
        route_change_ref: impl Into<String>,
        lease_ref: impl Into<String>,
        scheduler_ref: impl Into<String>,
        scheduled_bytes: u64,
        cancelled_bytes: u64,
        obsolete_inflight_read_rejected: bool,
        stale_slab_execution_rejected: bool,
        entered_execution: bool,
        answer_packet_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        admission_ref: impl Into<String>,
        scope_rex_ref: impl Into<String>,
        sovereign_gate_ref: impl Into<String>,
        compatibility_fence: impl Into<String>,
        visible_caveat: impl Into<String>,
    ) -> Result<Self, TransportCancellationError> {
        let run = Self {
            run_id: run_id.into(),
            mission_id: mission_id.into(),
            route_id: route_id.into(),
            route_epoch,
            state,
            page_run_ref: page_run_ref.into(),
            read_trace_ref: read_trace_ref.into(),
            slab_ref: slab_ref.into(),
            cancellation_group_ref: cancellation_group_ref.into(),
            cancellation_token_ref: cancellation_token_ref.into(),
            route_change_ref: route_change_ref.into(),
            lease_ref: lease_ref.into(),
            scheduler_ref: scheduler_ref.into(),
            scheduled_bytes,
            cancelled_bytes,
            obsolete_inflight_read_rejected,
            stale_slab_execution_rejected,
            entered_execution,
            answer_packet_ref: answer_packet_ref.into(),
            run_event_log_ref: run_event_log_ref.into(),
            rollback_ref: rollback_ref.into(),
            admission_ref: admission_ref.into(),
            scope_rex_ref: scope_rex_ref.into(),
            sovereign_gate_ref: sovereign_gate_ref.into(),
            compatibility_fence: compatibility_fence.into(),
            visible_caveat: visible_caveat.into(),
        };
        validate_run(&run)?;
        Ok(run)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:transport-cancellation:surface
// Plane: Verification
// Residency: visible metadata-only cancellation caveat surface.
pub struct TransportCancellationSurface {
    pub surface_id: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub visible_summary: String,
}

impl TransportCancellationSurface {
    pub fn new(
        surface_id: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        visible_summary: impl Into<String>,
    ) -> Result<Self, TransportCancellationError> {
        let surface = Self {
            surface_id: surface_id.into(),
            answer_packet_ref: answer_packet_ref.into(),
            run_event_log_ref: run_event_log_ref.into(),
            visible_summary: visible_summary.into(),
        };
        validate_surface(&surface)?;
        Ok(surface)
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
// UAS: uas:transport-cancellation:metrics
// Plane: Verification
// Residency: metadata-only aggregate.
pub struct TransportCancellationMetrics {
    pub run_count: usize,
    pub surface_count: usize,
    pub answer_packet_count: usize,
    pub run_event_log_count: usize,
    pub route_epoch_count: usize,
    pub completed_current_count: usize,
    pub cancelled_obsolete_count: usize,
    pub stale_rejection_count: usize,
    pub total_scheduled_bytes: u64,
    pub total_cancelled_bytes: u64,
    pub max_route_epoch: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:transport-cancellation:witness
// Plane: Verification
// Residency: metadata-only; live transport/model/runtime bytes must stay zero.
pub struct TransportCancellationWitness {
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub cancellation_success_bps: u32,
    pub no_cancel_baseline_bps: u32,
    pub stale_slab_entry_baseline_bps: u32,
    pub hidden_cancel_baseline_bps: u32,
    pub live_authority_baseline_bps: u32,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub transport_runtime_bytes_loaded: u64,
    pub max_metadata_bytes: u64,
    pub hidden_route_authority: bool,
    pub route_policy_mutation: bool,
    pub gate_bypass: bool,
    pub answer_packet_suppression: bool,
    pub hidden_chain_exposed: bool,
    pub hidden_cloud_route: bool,
    pub ssd_as_ram_claim: bool,
    pub mas_promotion_attempted: bool,
    pub live_benchmark_attempted: bool,
    pub runs: Vec<TransportCancellationRun>,
    pub surfaces: Vec<TransportCancellationSurface>,
}

impl TransportCancellationWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        cancellation_success_bps: u32,
        no_cancel_baseline_bps: u32,
        stale_slab_entry_baseline_bps: u32,
        hidden_cancel_baseline_bps: u32,
        live_authority_baseline_bps: u32,
        runtime_bytes_loaded: u64,
        model_bytes_loaded: u64,
        transport_runtime_bytes_loaded: u64,
        max_metadata_bytes: u64,
        hidden_route_authority: bool,
        route_policy_mutation: bool,
        gate_bypass: bool,
        answer_packet_suppression: bool,
        hidden_chain_exposed: bool,
        hidden_cloud_route: bool,
        ssd_as_ram_claim: bool,
        mas_promotion_attempted: bool,
        live_benchmark_attempted: bool,
        runs: Vec<TransportCancellationRun>,
        surfaces: Vec<TransportCancellationSurface>,
    ) -> Result<Self, TransportCancellationError> {
        let witness = Self {
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            cancellation_success_bps,
            no_cancel_baseline_bps,
            stale_slab_entry_baseline_bps,
            hidden_cancel_baseline_bps,
            live_authority_baseline_bps,
            runtime_bytes_loaded,
            model_bytes_loaded,
            transport_runtime_bytes_loaded,
            max_metadata_bytes,
            hidden_route_authority,
            route_policy_mutation,
            gate_bypass,
            answer_packet_suppression,
            hidden_chain_exposed,
            hidden_cloud_route,
            ssd_as_ram_claim,
            mas_promotion_attempted,
            live_benchmark_attempted,
            runs,
            surfaces,
        };
        validate_witness(&witness)?;
        Ok(witness)
    }

    pub fn metrics(&self) -> TransportCancellationMetrics {
        let mut answer_packets = BTreeSet::new();
        let mut run_event_logs = BTreeSet::new();
        let mut route_epochs = BTreeSet::new();
        let mut metrics = TransportCancellationMetrics {
            run_count: self.runs.len(),
            surface_count: self.surfaces.len(),
            ..TransportCancellationMetrics::default()
        };
        for run in &self.runs {
            answer_packets.insert(run.answer_packet_ref.clone());
            run_event_logs.insert(run.run_event_log_ref.clone());
            route_epochs.insert(run.route_epoch);
            metrics.total_scheduled_bytes = metrics
                .total_scheduled_bytes
                .saturating_add(run.scheduled_bytes);
            metrics.total_cancelled_bytes = metrics
                .total_cancelled_bytes
                .saturating_add(run.cancelled_bytes);
            metrics.max_route_epoch = metrics.max_route_epoch.max(run.route_epoch);
            match run.state {
                TransportCancellationState::CompletedCurrentRoute => {
                    metrics.completed_current_count += 1;
                }
                TransportCancellationState::CancelledObsoleteRead => {
                    metrics.cancelled_obsolete_count += 1;
                }
                TransportCancellationState::RejectedStaleSlab => {
                    metrics.stale_rejection_count += 1;
                }
            }
        }
        for surface in &self.surfaces {
            answer_packets.insert(surface.answer_packet_ref.clone());
            run_event_logs.insert(surface.run_event_log_ref.clone());
        }
        metrics.answer_packet_count = answer_packets.len();
        metrics.run_event_log_count = run_event_logs.len();
        metrics.route_epoch_count = route_epochs.len();
        metrics
    }

    pub fn address(&self) -> String {
        let mut run_parts = self
            .runs
            .iter()
            .map(|run| {
                format!(
                    "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
                    run.run_id,
                    run.mission_id,
                    run.route_id,
                    run.route_epoch,
                    run.state.tag(),
                    run.page_run_ref,
                    run.read_trace_ref,
                    run.slab_ref,
                    run.cancellation_group_ref,
                    run.cancellation_token_ref,
                    run.route_change_ref,
                    run.lease_ref,
                    run.scheduler_ref,
                    run.scheduled_bytes,
                    run.cancelled_bytes,
                    run.obsolete_inflight_read_rejected,
                    run.stale_slab_execution_rejected
                )
            })
            .collect::<Vec<_>>();
        run_parts.sort();
        let mut surface_parts = self
            .surfaces
            .iter()
            .map(|surface| {
                format!(
                    "{}|{}|{}|{}",
                    surface.surface_id,
                    surface.answer_packet_ref,
                    surface.run_event_log_ref,
                    surface.visible_summary
                )
            })
            .collect::<Vec<_>>();
        surface_parts.sort();
        let product_build = match self.product_build {
            ProductBuild::Mas => "mas",
            ProductBuild::Pro => "pro",
        };
        let pro_status = match self.pro_status {
            ProStatus::Live => "live",
            ProStatus::Gated => "gated",
            ProStatus::ResearchCandidate => "research_candidate",
            ProStatus::VaultPreserved => "vault_preserved",
            ProStatus::Omega => "omega",
            ProStatus::Blocked => "blocked",
            ProStatus::TargetOnly => "target_only",
            ProStatus::Superseded => "superseded",
        };
        let digest = sha256_hex(
            format!(
                "{}|{}|{}|{}|{}|{}|{}|{}",
                product_build,
                pro_status,
                self.route_authority,
                self.cancellation_success_bps,
                self.no_cancel_baseline_bps,
                self.stale_slab_entry_baseline_bps,
                run_parts.join(";;"),
                surface_parts.join(";;")
            )
            .as_bytes(),
        );
        format!("uas:transport-cancellation:{digest}")
    }
}

fn validate_witness(
    witness: &TransportCancellationWitness,
) -> Result<(), TransportCancellationError> {
    if witness.product_build != ProductBuild::Pro
        || witness.pro_status != ProStatus::ResearchCandidate
        || witness.route_authority != "transport_cancellation_gate_only"
    {
        return Err(TransportCancellationError::ProductStatusMismatch);
    }
    if witness.runs.is_empty() {
        return Err(TransportCancellationError::EmptyRun);
    }
    if witness.surfaces.is_empty() {
        return Err(TransportCancellationError::EmptySurface);
    }

    let mut run_ids = HashSet::with_capacity(witness.runs.len());
    let mut surface_ids = HashSet::with_capacity(witness.surfaces.len());
    let mut answer_packets = HashSet::with_capacity(witness.runs.len() + witness.surfaces.len());
    let mut has_current = false;
    let mut has_cancelled = false;
    let mut has_stale = false;
    for run in &witness.runs {
        validate_run(run)?;
        if !run_ids.insert(run.run_id.clone()) {
            return Err(TransportCancellationError::DuplicateRun(run.run_id.clone()));
        }
        if !answer_packets.insert(run.answer_packet_ref.clone()) {
            return Err(TransportCancellationError::DuplicateAnswerPacket(
                run.answer_packet_ref.clone(),
            ));
        }
        if !contains_layer_separation(&run.visible_caveat) {
            return Err(TransportCancellationError::MissingLayerSeparation);
        }
        match run.state {
            TransportCancellationState::CompletedCurrentRoute => has_current = true,
            TransportCancellationState::CancelledObsoleteRead => has_cancelled = true,
            TransportCancellationState::RejectedStaleSlab => has_stale = true,
        }
    }
    for surface in &witness.surfaces {
        validate_surface(surface)?;
        if !surface_ids.insert(surface.surface_id.clone()) {
            return Err(TransportCancellationError::DuplicateSurface(
                surface.surface_id.clone(),
            ));
        }
        if !contains_layer_separation(&surface.visible_summary) {
            return Err(TransportCancellationError::MissingLayerSeparation);
        }
    }
    if !has_current {
        return Err(TransportCancellationError::MissingCurrentRun);
    }
    if !has_cancelled {
        return Err(TransportCancellationError::MissingCancelledRun);
    }
    if !has_stale {
        return Err(TransportCancellationError::MissingStaleRejectionRun);
    }
    if witness.hidden_route_authority {
        return Err(TransportCancellationError::HiddenRouteAuthority);
    }
    if witness.route_policy_mutation {
        return Err(TransportCancellationError::RoutePolicyMutation);
    }
    if witness.gate_bypass {
        return Err(TransportCancellationError::GateBypass);
    }
    if witness.answer_packet_suppression {
        return Err(TransportCancellationError::AnswerPacketSuppression);
    }
    if witness.hidden_chain_exposed {
        return Err(TransportCancellationError::HiddenChainExposure);
    }
    if witness.hidden_cloud_route {
        return Err(TransportCancellationError::HiddenCloudRoute);
    }
    if witness.ssd_as_ram_claim {
        return Err(TransportCancellationError::SsdAsRamClaim);
    }
    if witness.mas_promotion_attempted {
        return Err(TransportCancellationError::MasPromotionAttempted);
    }
    if witness.live_benchmark_attempted {
        return Err(TransportCancellationError::LiveBenchmarkAttempted);
    }
    if witness.runtime_bytes_loaded != 0 {
        return Err(TransportCancellationError::RuntimeBytesLoaded);
    }
    if witness.model_bytes_loaded != 0 {
        return Err(TransportCancellationError::ModelBytesLoaded);
    }
    if witness.transport_runtime_bytes_loaded != 0 {
        return Err(TransportCancellationError::TransportRuntimeBytesLoaded);
    }
    if witness.max_metadata_bytes > MAX_METADATA_BYTES {
        return Err(TransportCancellationError::MetadataBudgetExceeded);
    }
    if witness.cancellation_success_bps < MIN_CANCELLATION_SUCCESS_BPS {
        return Err(TransportCancellationError::BaselineUnbeaten(
            "cancellation_success",
        ));
    }
    for (name, baseline) in [
        ("no_cancel", witness.no_cancel_baseline_bps),
        ("stale_slab_entry", witness.stale_slab_entry_baseline_bps),
        ("hidden_cancel", witness.hidden_cancel_baseline_bps),
        ("live_authority", witness.live_authority_baseline_bps),
    ] {
        if witness.cancellation_success_bps <= baseline {
            return Err(TransportCancellationError::BaselineUnbeaten(name));
        }
    }
    Ok(())
}

fn validate_run(run: &TransportCancellationRun) -> Result<(), TransportCancellationError> {
    validate_nonempty_clean("run_id", &run.run_id)?;
    validate_nonempty_clean("mission_id", &run.mission_id)?;
    validate_nonempty_clean("route_id", &run.route_id)?;
    validate_nonempty_clean("visible_caveat", &run.visible_caveat)?;
    validate_prefixed(
        "page_run_ref",
        &run.page_run_ref,
        PAGE_RUN_PREFIX,
        TransportCancellationError::MissingPageRun(run.run_id.clone()),
    )?;
    validate_prefixed(
        "read_trace_ref",
        &run.read_trace_ref,
        READ_TRACE_PREFIX,
        TransportCancellationError::MissingReadTrace(run.run_id.clone()),
    )?;
    validate_prefixed(
        "slab_ref",
        &run.slab_ref,
        SLAB_PREFIX,
        TransportCancellationError::MissingSlab(run.run_id.clone()),
    )?;
    validate_prefixed(
        "cancellation_group_ref",
        &run.cancellation_group_ref,
        CANCEL_GROUP_PREFIX,
        TransportCancellationError::MissingCancelGroup(run.run_id.clone()),
    )?;
    validate_prefixed(
        "cancellation_token_ref",
        &run.cancellation_token_ref,
        CANCEL_TOKEN_PREFIX,
        TransportCancellationError::MissingCancelToken(run.run_id.clone()),
    )?;
    validate_prefixed(
        "route_change_ref",
        &run.route_change_ref,
        ROUTE_CHANGE_PREFIX,
        TransportCancellationError::MissingRouteChange(run.run_id.clone()),
    )?;
    validate_prefixed(
        "lease_ref",
        &run.lease_ref,
        LEASE_PREFIX,
        TransportCancellationError::MissingLease(run.run_id.clone()),
    )?;
    validate_prefixed(
        "scheduler_ref",
        &run.scheduler_ref,
        SCHEDULER_PREFIX,
        TransportCancellationError::MissingScheduler(run.run_id.clone()),
    )?;
    validate_prefixed(
        "answer_packet_ref",
        &run.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
        TransportCancellationError::MissingAnswerPacket(run.run_id.clone()),
    )?;
    validate_prefixed(
        "run_event_log_ref",
        &run.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
        TransportCancellationError::MissingRunEventLog(run.run_id.clone()),
    )?;
    validate_prefixed(
        "rollback_ref",
        &run.rollback_ref,
        ROLLBACK_PREFIX,
        TransportCancellationError::MissingRollback(run.run_id.clone()),
    )?;
    validate_prefixed(
        "admission_ref",
        &run.admission_ref,
        ADMISSION_PREFIX,
        TransportCancellationError::MissingAdmission,
    )?;
    validate_prefixed(
        "scope_rex_ref",
        &run.scope_rex_ref,
        SCOPE_REX_PREFIX,
        TransportCancellationError::MissingScopeRex,
    )?;
    validate_prefixed(
        "sovereign_gate_ref",
        &run.sovereign_gate_ref,
        SOVEREIGN_GATE_PREFIX,
        TransportCancellationError::MissingSovereignGate,
    )?;
    validate_prefixed(
        "compatibility_fence",
        &run.compatibility_fence,
        COMPATIBILITY_FENCE_PREFIX,
        TransportCancellationError::MissingCompatibilityFence(run.run_id.clone()),
    )?;
    if run.route_epoch == 0 {
        return Err(TransportCancellationError::ZeroRouteEpoch(
            run.run_id.clone(),
        ));
    }
    if run.scheduled_bytes == 0 {
        return Err(TransportCancellationError::ZeroScheduledBytes(
            run.run_id.clone(),
        ));
    }
    match run.state {
        TransportCancellationState::CompletedCurrentRoute => {
            if run.cancelled_bytes != 0 {
                return Err(TransportCancellationError::CurrentRunCancelledBytes(
                    run.run_id.clone(),
                ));
            }
            if run.stale_slab_execution_rejected || run.obsolete_inflight_read_rejected {
                return Err(TransportCancellationError::CurrentRunRejectedAsStale(
                    run.run_id.clone(),
                ));
            }
        }
        TransportCancellationState::CancelledObsoleteRead => {
            if run.entered_execution {
                return Err(TransportCancellationError::CancelledRunEnteredExecution(
                    run.run_id.clone(),
                ));
            }
            if !run.obsolete_inflight_read_rejected {
                return Err(TransportCancellationError::CancelledRunMissingRejectedRead(
                    run.run_id.clone(),
                ));
            }
            if run.cancelled_bytes == 0 {
                return Err(
                    TransportCancellationError::CancelledRunMissingCancelledBytes(
                        run.run_id.clone(),
                    ),
                );
            }
        }
        TransportCancellationState::RejectedStaleSlab => {
            if run.entered_execution {
                return Err(TransportCancellationError::StaleRunEnteredExecution(
                    run.run_id.clone(),
                ));
            }
            if !run.stale_slab_execution_rejected {
                return Err(TransportCancellationError::StaleRunMissingRejectedSlab(
                    run.run_id.clone(),
                ));
            }
        }
    }
    for marker in [
        "metadata-only",
        "route epoch",
        "cancellation",
        "stale slab",
        "AnswerPacket",
    ] {
        if !run.visible_caveat.contains(marker) {
            return Err(TransportCancellationError::MissingRequiredMarker(
                marker.to_string(),
            ));
        }
    }
    for marker in [
        "hidden authority",
        "live transport",
        "SSD = RAM",
        "cloud fallback",
    ] {
        if run.visible_caveat.contains(marker) {
            return Err(TransportCancellationError::ForbiddenMarker(
                marker.to_string(),
            ));
        }
    }
    Ok(())
}

fn validate_surface(
    surface: &TransportCancellationSurface,
) -> Result<(), TransportCancellationError> {
    validate_nonempty_clean("surface_id", &surface.surface_id)?;
    validate_nonempty_clean("visible_summary", &surface.visible_summary)?;
    validate_prefixed(
        "answer_packet_ref",
        &surface.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
        TransportCancellationError::MissingAnswerPacket(surface.surface_id.clone()),
    )?;
    validate_prefixed(
        "run_event_log_ref",
        &surface.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
        TransportCancellationError::MissingRunEventLog(surface.surface_id.clone()),
    )?;
    if surface.visible_summary.len() < MIN_VISIBLE_CAVEAT_BYTES {
        return Err(TransportCancellationError::MissingVisibleCaveat(
            surface.surface_id.clone(),
        ));
    }
    for marker in [
        "metadata-only",
        "L1",
        "L2",
        "L3",
        "AnswerPacket",
        "rollback",
        "cancellation",
        "stale slab",
    ] {
        if !surface.visible_summary.contains(marker) {
            return Err(TransportCancellationError::MissingRequiredMarker(
                marker.to_string(),
            ));
        }
    }
    for marker in [
        "hidden authority",
        "live transport",
        "SSD = RAM",
        "cloud fallback",
    ] {
        if surface.visible_summary.contains(marker) {
            return Err(TransportCancellationError::ForbiddenMarker(
                marker.to_string(),
            ));
        }
    }
    Ok(())
}

fn validate_nonempty_clean(
    field: &'static str,
    value: &str,
) -> Result<(), TransportCancellationError> {
    if value.is_empty() {
        return Err(TransportCancellationError::MissingField(field));
    }
    if value.trim() != value {
        return Err(TransportCancellationError::FieldHasSurroundingWhitespace(
            field,
        ));
    }
    if value.chars().any(char::is_control) {
        return Err(TransportCancellationError::FieldContainsControlCharacter(
            field,
        ));
    }
    Ok(())
}

fn validate_prefixed(
    field: &'static str,
    value: &str,
    prefix: &str,
    missing: TransportCancellationError,
) -> Result<(), TransportCancellationError> {
    validate_nonempty_clean(field, value)?;
    if value.starts_with(prefix) {
        Ok(())
    } else {
        Err(missing)
    }
}

fn contains_layer_separation(value: &str) -> bool {
    value.contains("L1") && value.contains("L2") && value.contains("L3")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn caveat() -> String {
        "metadata-only route epoch cancellation witness: cancellation rejects obsolete reads, stale slab execution remains blocked, AnswerPacket and rollback are visible, L1 only while L2 and L3 stay unchanged."
            .to_string()
    }

    fn run(
        id: &str,
        epoch: u64,
        state: TransportCancellationState,
    ) -> Result<TransportCancellationRun, TransportCancellationError> {
        let (cancelled_bytes, obsolete_rejected, stale_rejected, entered_execution) = match state {
            TransportCancellationState::CompletedCurrentRoute => (0, false, false, true),
            TransportCancellationState::CancelledObsoleteRead => (16_384, true, false, false),
            TransportCancellationState::RejectedStaleSlab => (8_192, true, true, false),
        };
        TransportCancellationRun::new(
            id,
            "mission:coldstream-cancel",
            format!("route:{id}"),
            epoch,
            state,
            format!("page_run:{id}:input"),
            format!("read_trace:{id}:range"),
            format!("slab:{id}:candidate"),
            format!("cancel_group:{id}"),
            format!("cancel_token:{id}"),
            format!("route_change:{id}:epoch-{epoch}"),
            format!("lease:{id}"),
            format!("scheduler:{id}"),
            32_768,
            cancelled_bytes,
            obsolete_rejected,
            stale_rejected,
            entered_execution,
            format!("answer_packet:{id}"),
            format!("run_event_log:{id}"),
            format!("rollback:{id}"),
            "admission:transport-cancellation",
            "scope_rex:transport-cancellation",
            "sovereign_gate:transport-cancellation",
            "compat:transport-cancellation-v1",
            caveat(),
        )
    }

    fn surface(id: &str) -> Result<TransportCancellationSurface, TransportCancellationError> {
        TransportCancellationSurface::new(
            id,
            format!("answer_packet:surface:{id}"),
            format!("run_event_log:surface:{id}"),
            "metadata-only cancellation surface: L1 records route epoch, cancellation, stale slab rejection, AnswerPacket, RunEventLog, and rollback; L2 remains vault research and L3 product runtime is unchanged."
        )
    }

    fn witness() -> Result<TransportCancellationWitness, TransportCancellationError> {
        TransportCancellationWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "transport_cancellation_gate_only",
            9_720,
            8_000,
            8_200,
            8_350,
            8_100,
            0,
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
            vec![
                run(
                    "run-current",
                    3,
                    TransportCancellationState::CompletedCurrentRoute,
                )?,
                run(
                    "run-cancelled",
                    2,
                    TransportCancellationState::CancelledObsoleteRead,
                )?,
                run(
                    "run-stale",
                    1,
                    TransportCancellationState::RejectedStaleSlab,
                )?,
            ],
            vec![surface("surface-a")?, surface("surface-b")?],
        )
    }

    #[test]
    fn valid_witness_rejects_obsolete_and_stale_runs() {
        let witness = witness().expect("fixture witness");
        let metrics = witness.metrics();
        assert_eq!(metrics.run_count, 3);
        assert_eq!(metrics.completed_current_count, 1);
        assert_eq!(metrics.cancelled_obsolete_count, 1);
        assert_eq!(metrics.stale_rejection_count, 1);
        assert_eq!(metrics.total_scheduled_bytes, 98_304);
        assert_eq!(metrics.total_cancelled_bytes, 24_576);
        assert!(witness
            .address()
            .starts_with("uas:transport-cancellation:sha256:"));
    }

    #[test]
    fn deterministic_address_ignores_run_order() {
        let witness = witness().expect("fixture witness");
        let mut reversed_runs = witness.runs.clone();
        reversed_runs.reverse();
        let reversed = TransportCancellationWitness::new(
            witness.product_build.clone(),
            witness.pro_status.clone(),
            witness.route_authority.clone(),
            witness.cancellation_success_bps,
            witness.no_cancel_baseline_bps,
            witness.stale_slab_entry_baseline_bps,
            witness.hidden_cancel_baseline_bps,
            witness.live_authority_baseline_bps,
            witness.runtime_bytes_loaded,
            witness.model_bytes_loaded,
            witness.transport_runtime_bytes_loaded,
            witness.max_metadata_bytes,
            witness.hidden_route_authority,
            witness.route_policy_mutation,
            witness.gate_bypass,
            witness.answer_packet_suppression,
            witness.hidden_chain_exposed,
            witness.hidden_cloud_route,
            witness.ssd_as_ram_claim,
            witness.mas_promotion_attempted,
            witness.live_benchmark_attempted,
            reversed_runs,
            witness.surfaces.clone(),
        )
        .expect("reversed witness");
        assert_eq!(witness.address(), reversed.address());
    }

    #[test]
    fn rejects_cancelled_run_that_enters_execution() {
        let mut witness = witness().expect("fixture witness");
        witness.runs[1].entered_execution = true;
        assert!(matches!(
            rebuild(witness),
            Err(TransportCancellationError::CancelledRunEnteredExecution(_))
        ));
    }

    #[test]
    fn rejects_stale_run_without_stale_rejection() {
        let mut witness = witness().expect("fixture witness");
        witness.runs[2].stale_slab_execution_rejected = false;
        assert!(matches!(
            rebuild(witness),
            Err(TransportCancellationError::StaleRunMissingRejectedSlab(_))
        ));
    }

    #[test]
    fn rejects_duplicate_run_ids_and_answer_packets() {
        let mut duplicate_run = witness().expect("fixture witness");
        duplicate_run.runs.push(duplicate_run.runs[0].clone());
        assert!(matches!(
            rebuild(duplicate_run),
            Err(TransportCancellationError::DuplicateRun(_))
        ));

        let mut duplicate_packet = witness().expect("fixture witness");
        duplicate_packet.runs[1].answer_packet_ref =
            duplicate_packet.runs[0].answer_packet_ref.clone();
        assert!(matches!(
            rebuild(duplicate_packet),
            Err(TransportCancellationError::DuplicateAnswerPacket(_))
        ));
    }

    #[test]
    fn rejects_missing_route_change_and_cancel_token() {
        let mut missing_change = witness().expect("fixture witness");
        missing_change.runs[1].route_change_ref.clear();
        assert!(matches!(
            rebuild(missing_change),
            Err(TransportCancellationError::MissingField("route_change_ref"))
                | Err(TransportCancellationError::MissingRouteChange(_))
        ));

        let mut missing_token = witness().expect("fixture witness");
        missing_token.runs[1].cancellation_token_ref.clear();
        assert!(matches!(
            rebuild(missing_token),
            Err(TransportCancellationError::MissingField(
                "cancellation_token_ref"
            )) | Err(TransportCancellationError::MissingCancelToken(_))
        ));
    }

    #[test]
    fn rejects_product_and_runtime_promotions() {
        let mut live = witness().expect("fixture witness");
        live.pro_status = ProStatus::Live;
        assert!(matches!(
            rebuild(live),
            Err(TransportCancellationError::ProductStatusMismatch)
        ));

        let mut runtime = witness().expect("fixture witness");
        runtime.transport_runtime_bytes_loaded = 1;
        assert!(matches!(
            rebuild(runtime),
            Err(TransportCancellationError::TransportRuntimeBytesLoaded)
        ));
    }

    #[test]
    fn rejects_unbeaten_baselines_and_over_budget_metadata() {
        let mut baseline = witness().expect("fixture witness");
        baseline.no_cancel_baseline_bps = baseline.cancellation_success_bps;
        assert!(matches!(
            rebuild(baseline),
            Err(TransportCancellationError::BaselineUnbeaten("no_cancel"))
        ));

        let mut budget = witness().expect("fixture witness");
        budget.max_metadata_bytes = MAX_METADATA_BYTES + 1;
        assert!(matches!(
            rebuild(budget),
            Err(TransportCancellationError::MetadataBudgetExceeded)
        ));
    }

    fn rebuild(
        witness: TransportCancellationWitness,
    ) -> Result<TransportCancellationWitness, TransportCancellationError> {
        TransportCancellationWitness::new(
            witness.product_build,
            witness.pro_status,
            witness.route_authority,
            witness.cancellation_success_bps,
            witness.no_cancel_baseline_bps,
            witness.stale_slab_entry_baseline_bps,
            witness.hidden_cancel_baseline_bps,
            witness.live_authority_baseline_bps,
            witness.runtime_bytes_loaded,
            witness.model_bytes_loaded,
            witness.transport_runtime_bytes_loaded,
            witness.max_metadata_bytes,
            witness.hidden_route_authority,
            witness.route_policy_mutation,
            witness.gate_bypass,
            witness.answer_packet_suppression,
            witness.hidden_chain_exposed,
            witness.hidden_cloud_route,
            witness.ssd_as_ram_claim,
            witness.mas_promotion_attempted,
            witness.live_benchmark_attempted,
            witness.runs,
            witness.surfaces,
        )
    }
}
