//! ColdStream residency transport contracts.
//!
//! ColdStream is the explicit, cancelable byte-transport layer for cold UAS
//! material. This module is metadata-only: it validates transport manifests
//! and traces before any runtime, model, mmap, Metal, or MLX bytes are moved.

use std::collections::HashSet;
use std::fmt;

use crate::uas::{
    ByteRange, ProStatus, ProductBuild, UasAddress, UasKind, WeightBlockManifestError,
};

const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const LEASE_PREFIX: &str = "lease:";
const FALLBACK_PREFIX: &str = "fallback:";
const SEMANTIC_PLAN_PREFIX: &str = "uas:semantic_working_set_plan:";
const PAGE_TABLE_PREFIX: &str = "residency_page_table:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const MAX_TRACE_COPY_COUNT: u32 = 2;

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
// UAS: uas:coldstream:destination-lane
// Plane: Assembly
// Residency: metadata-only destination label; no bytes are allocated or moved.
pub enum ColdStreamDestination {
    CpuSlab,
    MetalBuffer,
    MlxReadySlab,
}

impl ColdStreamDestination {
    fn wire_tag(&self) -> &'static str {
        match self {
            Self::CpuSlab => "cpu_slab",
            Self::MetalBuffer => "metal_buffer",
            Self::MlxReadySlab => "mlx_ready_slab",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
// UAS: uas:coldstream:priority-lane
// Plane: Controller
// Residency: metadata-only scheduling label; no live transport authority.
pub enum ColdStreamPriority {
    Urgent,
    Prefetch,
    Background,
}

impl ColdStreamPriority {
    fn wire_tag(&self) -> &'static str {
        match self {
            Self::Urgent => "urgent",
            Self::Prefetch => "prefetch",
            Self::Background => "background",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
// UAS: uas:coldstream:cache-policy
// Plane: Controller + Verification
// Residency: metadata-only cache intent; runtime cache mutation is rejected.
pub enum ColdStreamCachePolicy {
    Default,
    NoCache,
    HotReuse,
}

impl ColdStreamCachePolicy {
    fn wire_tag(&self) -> &'static str {
        match self {
            Self::Default => "default",
            Self::NoCache => "no_cache",
            Self::HotReuse => "hot_reuse",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
// UAS: uas:coldstream:authority
// Plane: Controller + Verification
// Residency: proposal-only authority marker; live byte-wake authority is rejected.
pub enum ColdStreamAuthority {
    ProposalOnly,
    LiveTransportAuthority,
}

impl ColdStreamAuthority {
    fn wire_tag(&self) -> &'static str {
        match self {
            Self::ProposalOnly => "proposal_only",
            Self::LiveTransportAuthority => "live_transport_authority",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:coldstream:error
// Plane: Verification
// Residency: metadata-only rejection taxonomy for transport contracts.
pub enum ColdStreamError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    InvalidByteRange,
    InvalidChecksum {
        run_id: String,
    },
    InvalidCompatibilityFence {
        run_id: String,
    },
    MissingSemanticUnit {
        run_id: String,
    },
    MissingUasAddress {
        run_id: String,
    },
    MissingLease {
        run_id: String,
    },
    EmptyPageRun,
    DuplicateRunId {
        run_id: String,
    },
    DuplicateByteRange {
        file_id: String,
        start: u64,
        len: u64,
    },
    DuplicateUasAddress {
        address: String,
    },
    MissingSemanticWorkingSetPlan,
    MissingResidencyPageTable,
    MissingAdmission,
    MissingScopeRex,
    MissingSovereignGate,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    MissingFallback,
    MissingCancellationGroup,
    HiddenTransportAuthority,
    ByteWakeWithoutLease,
    RoutePolicyMutation,
    ScopeRexOverride,
    SovereignGateOverride,
    AnswerPacketSuppression,
    HiddenChainExposure,
    HiddenCloudRoute,
    RuntimeBytesLoaded,
    ModelBytesLoaded,
    ProductStatusMismatch,
    TraceManifestMismatch,
    TraceBytesMissing,
    TraceDecodedUnderRequested,
    TraceP99BelowP95,
    TraceCopyBudgetExceeded,
    StaleSlabEnteredExecution,
    TraceMissingRunEventLog,
    TraceMissingAnswerPacket,
    TraceFallbackMissing,
}

impl fmt::Display for ColdStreamError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::InvalidByteRange => write!(f, "invalid byte range"),
            Self::InvalidChecksum { run_id } => write!(f, "invalid checksum for run `{run_id}`"),
            Self::InvalidCompatibilityFence { run_id } => {
                write!(f, "invalid compatibility fence for run `{run_id}`")
            }
            Self::MissingSemanticUnit { run_id } => {
                write!(f, "missing semantic unit for run `{run_id}`")
            }
            Self::MissingUasAddress { run_id } => {
                write!(f, "missing UAS address for run `{run_id}`")
            }
            Self::MissingLease { run_id } => write!(f, "missing lease for run `{run_id}`"),
            Self::EmptyPageRun => write!(f, "manifest has no page runs"),
            Self::DuplicateRunId { run_id } => write!(f, "duplicate page-run id `{run_id}`"),
            Self::DuplicateByteRange {
                file_id,
                start,
                len,
            } => write!(
                f,
                "duplicate byte range for file `{file_id}` at {start}+{len}"
            ),
            Self::DuplicateUasAddress { address } => {
                write!(f, "duplicate selected UAS address `{address}`")
            }
            Self::MissingSemanticWorkingSetPlan => {
                write!(f, "missing SemanticWorkingSetPlan reference")
            }
            Self::MissingResidencyPageTable => write!(f, "missing ResidencyPageTable reference"),
            Self::MissingAdmission => write!(f, "missing admission reference"),
            Self::MissingScopeRex => write!(f, "missing SCOPE-Rex reference"),
            Self::MissingSovereignGate => write!(f, "missing SovereignGate reference"),
            Self::MissingRollback => write!(f, "missing rollback reference"),
            Self::MissingRunEventLog => write!(f, "missing RunEventLog reference"),
            Self::MissingAnswerPacket => write!(f, "missing AnswerPacket reference"),
            Self::MissingFallback => write!(f, "missing fallback reference"),
            Self::MissingCancellationGroup => write!(f, "missing cancellation group"),
            Self::HiddenTransportAuthority => write!(f, "transport tried to become authority"),
            Self::ByteWakeWithoutLease => write!(f, "transport attempted byte wake without lease"),
            Self::RoutePolicyMutation => write!(f, "transport attempted route-policy mutation"),
            Self::ScopeRexOverride => write!(f, "transport attempted SCOPE-Rex override"),
            Self::SovereignGateOverride => write!(f, "transport attempted SovereignGate override"),
            Self::AnswerPacketSuppression => write!(f, "transport suppressed AnswerPacket proof"),
            Self::HiddenChainExposure => write!(f, "transport exposed hidden chain"),
            Self::HiddenCloudRoute => write!(f, "transport introduced hidden cloud route"),
            Self::RuntimeBytesLoaded => write!(f, "metadata witness loaded runtime bytes"),
            Self::ModelBytesLoaded => write!(f, "metadata witness loaded model bytes"),
            Self::ProductStatusMismatch => write!(f, "ColdStream manifest promoted product status"),
            Self::TraceManifestMismatch => write!(f, "trace does not match manifest"),
            Self::TraceBytesMissing => write!(f, "trace did not account for requested bytes"),
            Self::TraceDecodedUnderRequested => {
                write!(f, "trace decoded fewer bytes than requested")
            }
            Self::TraceP99BelowP95 => write!(f, "trace p99 is below p95"),
            Self::TraceCopyBudgetExceeded => write!(f, "trace copy budget exceeded"),
            Self::StaleSlabEnteredExecution => write!(f, "stale slab entered execution"),
            Self::TraceMissingRunEventLog => write!(f, "trace missing RunEventLog reference"),
            Self::TraceMissingAnswerPacket => write!(f, "trace missing AnswerPacket reference"),
            Self::TraceFallbackMissing => write!(f, "trace fallback caveat missing"),
        }
    }
}

impl std::error::Error for ColdStreamError {}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:coldstream:page-run
// Plane: Assembly + Verification
// Residency: metadata-only byte-range plan; no file, mmap, Metal, or MLX bytes move here.
pub struct ColdStreamPageRun {
    pub run_id: String,
    pub file_id: String,
    pub byte_range: ByteRange,
    pub semantic_unit_ids: Vec<String>,
    pub uas_addresses: Vec<UasAddress>,
    pub codec: String,
    pub checksum: String,
    pub destination: ColdStreamDestination,
    pub priority: ColdStreamPriority,
    pub cache_policy: ColdStreamCachePolicy,
    pub lease_ref: String,
    pub compatibility_fence: String,
}

impl ColdStreamPageRun {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        run_id: impl Into<String>,
        file_id: impl Into<String>,
        offset: u64,
        length: u64,
        semantic_unit_ids: Vec<String>,
        uas_addresses: Vec<UasAddress>,
        codec: impl Into<String>,
        checksum: impl Into<String>,
        destination: ColdStreamDestination,
        priority: ColdStreamPriority,
        cache_policy: ColdStreamCachePolicy,
        lease_ref: impl Into<String>,
        compatibility_fence: impl Into<String>,
    ) -> Result<Self, ColdStreamError> {
        let run_id = run_id.into();
        let file_id = file_id.into();
        let codec = codec.into();
        let checksum = checksum.into();
        let lease_ref = lease_ref.into();
        let compatibility_fence = compatibility_fence.into();
        validate_nonempty("run_id", &run_id)?;
        validate_nonempty("file_id", &file_id)?;
        validate_nonempty("codec", &codec)?;
        validate_nonempty("checksum", &checksum)?;
        validate_nonempty("lease_ref", &lease_ref)?;
        validate_nonempty("compatibility_fence", &compatibility_fence)?;
        if semantic_unit_ids.is_empty() {
            return Err(ColdStreamError::MissingSemanticUnit {
                run_id: run_id.clone(),
            });
        }
        if uas_addresses.is_empty() {
            return Err(ColdStreamError::MissingUasAddress {
                run_id: run_id.clone(),
            });
        }
        if !checksum.starts_with("sha256:") && !checksum.starts_with("blake3:") {
            return Err(ColdStreamError::InvalidChecksum {
                run_id: run_id.clone(),
            });
        }
        if !lease_ref.starts_with(LEASE_PREFIX) {
            return Err(ColdStreamError::MissingLease {
                run_id: run_id.clone(),
            });
        }
        if !compatibility_fence.starts_with(COMPATIBILITY_FENCE_PREFIX) {
            return Err(ColdStreamError::InvalidCompatibilityFence {
                run_id: run_id.clone(),
            });
        }
        let byte_range =
            ByteRange::new(offset, length).map_err(map_byte_range_error_to_coldstream)?;

        for semantic_unit_id in &semantic_unit_ids {
            validate_nonempty("semantic_unit_id", semantic_unit_id)?;
        }

        Ok(Self {
            run_id,
            file_id,
            byte_range,
            semantic_unit_ids,
            uas_addresses,
            codec,
            checksum,
            destination,
            priority,
            cache_policy,
            lease_ref,
            compatibility_fence,
        })
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:coldstream:transport-manifest
// Plane: Controller + Assembly + Verification
// Residency: metadata-only transport contract; authority remains proposal-only.
pub struct ColdStreamTransportManifest {
    pub manifest_address: UasAddress,
    pub manifest_id: String,
    pub route_id: String,
    pub semantic_working_set_plan_ref: String,
    pub residency_page_table_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub fallback_ref: String,
    pub cancellation_group: String,
    pub authority: ColdStreamAuthority,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub page_runs: Vec<ColdStreamPageRun>,
    pub byte_wake_without_lease: bool,
    pub route_policy_mutated: bool,
    pub scope_rex_overridden: bool,
    pub sovereign_gate_overridden: bool,
    pub answer_packet_suppressed: bool,
    pub hidden_chain_exposed: bool,
    pub hidden_cloud_route: bool,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
}

impl ColdStreamTransportManifest {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        manifest_id: impl Into<String>,
        route_id: impl Into<String>,
        semantic_working_set_plan_ref: impl Into<String>,
        residency_page_table_ref: impl Into<String>,
        admission_ref: impl Into<String>,
        scope_rex_ref: impl Into<String>,
        sovereign_gate_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        fallback_ref: impl Into<String>,
        cancellation_group: impl Into<String>,
        authority: ColdStreamAuthority,
        product_build: ProductBuild,
        pro_status: ProStatus,
        page_runs: Vec<ColdStreamPageRun>,
        byte_wake_without_lease: bool,
        route_policy_mutated: bool,
        scope_rex_overridden: bool,
        sovereign_gate_overridden: bool,
        answer_packet_suppressed: bool,
        hidden_chain_exposed: bool,
        hidden_cloud_route: bool,
        runtime_bytes_loaded: u64,
        model_bytes_loaded: u64,
        created_at_ms: u64,
    ) -> Result<Self, ColdStreamError> {
        let manifest_id = manifest_id.into();
        let route_id = route_id.into();
        let semantic_working_set_plan_ref = semantic_working_set_plan_ref.into();
        let residency_page_table_ref = residency_page_table_ref.into();
        let admission_ref = admission_ref.into();
        let scope_rex_ref = scope_rex_ref.into();
        let sovereign_gate_ref = sovereign_gate_ref.into();
        let rollback_ref = rollback_ref.into();
        let run_event_log_ref = run_event_log_ref.into();
        let answer_packet_ref = answer_packet_ref.into();
        let fallback_ref = fallback_ref.into();
        let cancellation_group = cancellation_group.into();
        validate_nonempty("manifest_id", &manifest_id)?;
        validate_nonempty("route_id", &route_id)?;
        validate_nonempty(
            "semantic_working_set_plan_ref",
            &semantic_working_set_plan_ref,
        )?;
        validate_nonempty("residency_page_table_ref", &residency_page_table_ref)?;
        validate_nonempty("admission_ref", &admission_ref)?;
        validate_nonempty("scope_rex_ref", &scope_rex_ref)?;
        validate_nonempty("sovereign_gate_ref", &sovereign_gate_ref)?;
        validate_nonempty("rollback_ref", &rollback_ref)?;
        validate_nonempty("run_event_log_ref", &run_event_log_ref)?;
        validate_nonempty("answer_packet_ref", &answer_packet_ref)?;
        validate_nonempty("fallback_ref", &fallback_ref)?;
        validate_nonempty("cancellation_group", &cancellation_group)?;
        validate_manifest_authority(
            &semantic_working_set_plan_ref,
            &residency_page_table_ref,
            &admission_ref,
            &scope_rex_ref,
            &sovereign_gate_ref,
            &rollback_ref,
            &run_event_log_ref,
            &answer_packet_ref,
            &fallback_ref,
            &cancellation_group,
            &authority,
            &product_build,
            &pro_status,
            byte_wake_without_lease,
            route_policy_mutated,
            scope_rex_overridden,
            sovereign_gate_overridden,
            answer_packet_suppressed,
            hidden_chain_exposed,
            hidden_cloud_route,
            runtime_bytes_loaded,
            model_bytes_loaded,
        )?;
        validate_page_runs(&page_runs)?;

        let mut page_runs = page_runs;
        page_runs.sort_by(|left, right| {
            (
                left.run_id.as_str(),
                left.file_id.as_str(),
                left.byte_range.start,
                left.byte_range.len,
            )
                .cmp(&(
                    right.run_id.as_str(),
                    right.file_id.as_str(),
                    right.byte_range.start,
                    right.byte_range.len,
                ))
        });
        let manifest_address = manifest_address(
            &manifest_id,
            &route_id,
            &semantic_working_set_plan_ref,
            &residency_page_table_ref,
            &admission_ref,
            &scope_rex_ref,
            &sovereign_gate_ref,
            &rollback_ref,
            &run_event_log_ref,
            &answer_packet_ref,
            &fallback_ref,
            &cancellation_group,
            &authority,
            &product_build,
            &pro_status,
            &page_runs,
            created_at_ms,
        );

        Ok(Self {
            manifest_address,
            manifest_id,
            route_id,
            semantic_working_set_plan_ref,
            residency_page_table_ref,
            admission_ref,
            scope_rex_ref,
            sovereign_gate_ref,
            rollback_ref,
            run_event_log_ref,
            answer_packet_ref,
            fallback_ref,
            cancellation_group,
            authority,
            product_build,
            pro_status,
            page_runs,
            byte_wake_without_lease,
            route_policy_mutated,
            scope_rex_overridden,
            sovereign_gate_overridden,
            answer_packet_suppressed,
            hidden_chain_exposed,
            hidden_cloud_route,
            runtime_bytes_loaded,
            model_bytes_loaded,
        })
    }

    pub fn planned_bytes(&self) -> u64 {
        self.page_runs
            .iter()
            .map(|run| run.byte_range.len)
            .sum::<u64>()
    }

    pub fn run_count(&self) -> usize {
        self.page_runs.len()
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:coldstream:transport-trace
// Plane: Verification
// Residency: metadata-only trace proof; no cold bytes are loaded by this witness.
pub struct ColdStreamTransportTrace {
    pub trace_id: String,
    pub manifest_ref: UasAddress,
    pub bytes_requested: u64,
    pub bytes_read: u64,
    pub bytes_decoded: u64,
    pub copy_count: u32,
    pub cancellation_count: u32,
    pub p95_stall_ms: u32,
    pub p99_stall_ms: u32,
    pub read_amplification_bps: u32,
    pub stale_slab_entered_execution: bool,
    pub fallback_visible: bool,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl ColdStreamTransportTrace {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        manifest: &ColdStreamTransportManifest,
        trace_id: impl Into<String>,
        bytes_requested: u64,
        bytes_read: u64,
        bytes_decoded: u64,
        copy_count: u32,
        cancellation_count: u32,
        p95_stall_ms: u32,
        p99_stall_ms: u32,
        read_amplification_bps: u32,
        stale_slab_entered_execution: bool,
        fallback_visible: bool,
        run_event_log_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
    ) -> Result<Self, ColdStreamError> {
        let trace_id = trace_id.into();
        let run_event_log_ref = run_event_log_ref.into();
        let answer_packet_ref = answer_packet_ref.into();
        validate_nonempty("trace_id", &trace_id)?;
        validate_nonempty("run_event_log_ref", &run_event_log_ref)?;
        validate_nonempty("answer_packet_ref", &answer_packet_ref)?;
        if bytes_requested == 0 || bytes_read == 0 || bytes_requested != manifest.planned_bytes() {
            return Err(ColdStreamError::TraceBytesMissing);
        }
        if bytes_decoded < bytes_requested {
            return Err(ColdStreamError::TraceDecodedUnderRequested);
        }
        if p99_stall_ms < p95_stall_ms {
            return Err(ColdStreamError::TraceP99BelowP95);
        }
        if copy_count > MAX_TRACE_COPY_COUNT {
            return Err(ColdStreamError::TraceCopyBudgetExceeded);
        }
        if stale_slab_entered_execution {
            return Err(ColdStreamError::StaleSlabEnteredExecution);
        }
        if run_event_log_ref != manifest.run_event_log_ref {
            return Err(ColdStreamError::TraceMissingRunEventLog);
        }
        if answer_packet_ref != manifest.answer_packet_ref {
            return Err(ColdStreamError::TraceMissingAnswerPacket);
        }
        if !fallback_visible {
            return Err(ColdStreamError::TraceFallbackMissing);
        }

        Ok(Self {
            trace_id,
            manifest_ref: manifest.manifest_address.clone(),
            bytes_requested,
            bytes_read,
            bytes_decoded,
            copy_count,
            cancellation_count,
            p95_stall_ms,
            p99_stall_ms,
            read_amplification_bps,
            stale_slab_entered_execution,
            fallback_visible,
            run_event_log_ref,
            answer_packet_ref,
        })
    }
}

#[allow(clippy::too_many_arguments)]
fn validate_manifest_authority(
    semantic_working_set_plan_ref: &str,
    residency_page_table_ref: &str,
    admission_ref: &str,
    scope_rex_ref: &str,
    sovereign_gate_ref: &str,
    rollback_ref: &str,
    run_event_log_ref: &str,
    answer_packet_ref: &str,
    fallback_ref: &str,
    cancellation_group: &str,
    authority: &ColdStreamAuthority,
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    byte_wake_without_lease: bool,
    route_policy_mutated: bool,
    scope_rex_overridden: bool,
    sovereign_gate_overridden: bool,
    answer_packet_suppressed: bool,
    hidden_chain_exposed: bool,
    hidden_cloud_route: bool,
    runtime_bytes_loaded: u64,
    model_bytes_loaded: u64,
) -> Result<(), ColdStreamError> {
    if !semantic_working_set_plan_ref.starts_with(SEMANTIC_PLAN_PREFIX) {
        return Err(ColdStreamError::MissingSemanticWorkingSetPlan);
    }
    if !residency_page_table_ref.starts_with(PAGE_TABLE_PREFIX) {
        return Err(ColdStreamError::MissingResidencyPageTable);
    }
    if !admission_ref.starts_with(ADMISSION_PREFIX) {
        return Err(ColdStreamError::MissingAdmission);
    }
    if !scope_rex_ref.starts_with(SCOPE_REX_PREFIX) {
        return Err(ColdStreamError::MissingScopeRex);
    }
    if !sovereign_gate_ref.starts_with(SOVEREIGN_GATE_PREFIX) {
        return Err(ColdStreamError::MissingSovereignGate);
    }
    if !rollback_ref.starts_with(ROLLBACK_PREFIX) {
        return Err(ColdStreamError::MissingRollback);
    }
    if !run_event_log_ref.starts_with(RUN_EVENT_LOG_PREFIX) {
        return Err(ColdStreamError::MissingRunEventLog);
    }
    if !answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX) {
        return Err(ColdStreamError::MissingAnswerPacket);
    }
    if !fallback_ref.starts_with(FALLBACK_PREFIX) {
        return Err(ColdStreamError::MissingFallback);
    }
    if !cancellation_group.starts_with("cancel_group:") {
        return Err(ColdStreamError::MissingCancellationGroup);
    }
    if authority != &ColdStreamAuthority::ProposalOnly {
        return Err(ColdStreamError::HiddenTransportAuthority);
    }
    if product_build != &ProductBuild::Pro || pro_status != &ProStatus::ResearchCandidate {
        return Err(ColdStreamError::ProductStatusMismatch);
    }
    if byte_wake_without_lease {
        return Err(ColdStreamError::ByteWakeWithoutLease);
    }
    if route_policy_mutated {
        return Err(ColdStreamError::RoutePolicyMutation);
    }
    if scope_rex_overridden {
        return Err(ColdStreamError::ScopeRexOverride);
    }
    if sovereign_gate_overridden {
        return Err(ColdStreamError::SovereignGateOverride);
    }
    if answer_packet_suppressed {
        return Err(ColdStreamError::AnswerPacketSuppression);
    }
    if hidden_chain_exposed {
        return Err(ColdStreamError::HiddenChainExposure);
    }
    if hidden_cloud_route {
        return Err(ColdStreamError::HiddenCloudRoute);
    }
    if runtime_bytes_loaded > 0 {
        return Err(ColdStreamError::RuntimeBytesLoaded);
    }
    if model_bytes_loaded > 0 {
        return Err(ColdStreamError::ModelBytesLoaded);
    }
    Ok(())
}

fn validate_page_runs(page_runs: &[ColdStreamPageRun]) -> Result<(), ColdStreamError> {
    if page_runs.is_empty() {
        return Err(ColdStreamError::EmptyPageRun);
    }
    let mut run_ids = HashSet::new();
    let mut byte_ranges = HashSet::new();
    let mut addresses = HashSet::new();
    for run in page_runs {
        if !run_ids.insert(run.run_id.clone()) {
            return Err(ColdStreamError::DuplicateRunId {
                run_id: run.run_id.clone(),
            });
        }
        if !byte_ranges.insert((
            run.file_id.clone(),
            run.byte_range.start,
            run.byte_range.len,
        )) {
            return Err(ColdStreamError::DuplicateByteRange {
                file_id: run.file_id.clone(),
                start: run.byte_range.start,
                len: run.byte_range.len,
            });
        }
        for address in &run.uas_addresses {
            if !addresses.insert(address.to_string()) {
                return Err(ColdStreamError::DuplicateUasAddress {
                    address: address.to_string(),
                });
            }
        }
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn manifest_address(
    manifest_id: &str,
    route_id: &str,
    semantic_working_set_plan_ref: &str,
    residency_page_table_ref: &str,
    admission_ref: &str,
    scope_rex_ref: &str,
    sovereign_gate_ref: &str,
    rollback_ref: &str,
    run_event_log_ref: &str,
    answer_packet_ref: &str,
    fallback_ref: &str,
    cancellation_group: &str,
    authority: &ColdStreamAuthority,
    product_build: &ProductBuild,
    pro_status: &ProStatus,
    page_runs: &[ColdStreamPageRun],
    created_at_ms: u64,
) -> UasAddress {
    let mut content = String::new();
    content.push_str(manifest_id);
    content.push('|');
    content.push_str(route_id);
    content.push('|');
    content.push_str(semantic_working_set_plan_ref);
    content.push('|');
    content.push_str(residency_page_table_ref);
    content.push('|');
    content.push_str(admission_ref);
    content.push('|');
    content.push_str(scope_rex_ref);
    content.push('|');
    content.push_str(sovereign_gate_ref);
    content.push('|');
    content.push_str(rollback_ref);
    content.push('|');
    content.push_str(run_event_log_ref);
    content.push('|');
    content.push_str(answer_packet_ref);
    content.push('|');
    content.push_str(fallback_ref);
    content.push('|');
    content.push_str(cancellation_group);
    content.push('|');
    content.push_str(authority.wire_tag());
    content.push('|');
    content.push_str(match product_build {
        ProductBuild::Mas => "mas",
        ProductBuild::Pro => "pro",
    });
    content.push('|');
    content.push_str(match pro_status {
        ProStatus::Live => "live",
        ProStatus::Gated => "gated",
        ProStatus::ResearchCandidate => "research_candidate",
        ProStatus::VaultPreserved => "vault_preserved",
        ProStatus::Omega => "omega",
        ProStatus::Blocked => "blocked",
        ProStatus::TargetOnly => "target_only",
        ProStatus::Superseded => "superseded",
    });
    for run in page_runs {
        content.push('|');
        content.push_str(&run.run_id);
        content.push(':');
        content.push_str(&run.file_id);
        content.push(':');
        content.push_str(&run.byte_range.start.to_string());
        content.push(':');
        content.push_str(&run.byte_range.len.to_string());
        content.push(':');
        content.push_str(run.destination.wire_tag());
        content.push(':');
        content.push_str(run.priority.wire_tag());
        content.push(':');
        content.push_str(run.cache_policy.wire_tag());
        content.push(':');
        content.push_str(&run.codec);
        content.push(':');
        content.push_str(&run.checksum);
        content.push(':');
        content.push_str(&run.lease_ref);
        content.push(':');
        content.push_str(&run.compatibility_fence);
        for address in &run.uas_addresses {
            content.push(':');
            content.push_str(&address.to_string());
        }
    }
    UasAddress::new(
        UasKind::Other("coldstream_transport_manifest".to_string()),
        content.as_bytes(),
        created_at_ms,
    )
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), ColdStreamError> {
    if value.is_empty() {
        return Err(ColdStreamError::MissingField(field));
    }
    if value != value.trim() {
        return Err(ColdStreamError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(char::is_control) {
        return Err(ColdStreamError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

fn map_byte_range_error_to_coldstream(error: WeightBlockManifestError) -> ColdStreamError {
    match error {
        WeightBlockManifestError::EmptyByteRange | WeightBlockManifestError::ByteRangeOverflow => {
            ColdStreamError::InvalidByteRange
        }
        _ => ColdStreamError::InvalidByteRange,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_552_000_000;

    #[test]
    fn valid_manifest_and_trace_bind_authority_surfaces() {
        let manifest = fixture_manifest().expect("fixture manifest");
        assert_eq!(manifest.run_count(), 3);
        assert_eq!(manifest.planned_bytes(), 384 * 1024);
        assert!(manifest
            .manifest_address
            .to_string()
            .starts_with("coldstream_transport_manifest:"));
        let trace = fixture_trace(&manifest).expect("fixture trace");
        assert_eq!(trace.manifest_ref, manifest.manifest_address);
        assert_eq!(trace.copy_count, 2);
        assert!(trace.fallback_visible);
    }

    #[test]
    fn manifest_address_is_deterministic_under_page_run_order() {
        let left = fixture_manifest().expect("left manifest");
        let mut runs = fixture_runs().expect("runs");
        runs.reverse();
        let right = ColdStreamTransportManifest::new(
            "coldstream-manifest-local-research",
            "route:coldstream:local-research",
            SEMANTIC_PLAN_REF,
            PAGE_TABLE_REF,
            ADMISSION_REF,
            SCOPE_REX_REF,
            SOVEREIGN_GATE_REF,
            ROLLBACK_REF,
            RUN_EVENT_LOG_REF,
            ANSWER_PACKET_REF,
            FALLBACK_REF,
            CANCELLATION_GROUP,
            ColdStreamAuthority::ProposalOnly,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            runs,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            0,
            0,
            CREATED_AT_MS,
        )
        .expect("right manifest");
        assert_eq!(left.manifest_address, right.manifest_address);
    }

    #[test]
    fn manifest_rejects_missing_authority_gates() {
        assert_eq!(
            manifest_with_refs(
                "",
                PAGE_TABLE_REF,
                ADMISSION_REF,
                SCOPE_REX_REF,
                SOVEREIGN_GATE_REF
            )
            .unwrap_err(),
            ColdStreamError::MissingField("semantic_working_set_plan_ref")
        );
        assert_eq!(
            manifest_with_refs(
                "bad-plan",
                PAGE_TABLE_REF,
                ADMISSION_REF,
                SCOPE_REX_REF,
                SOVEREIGN_GATE_REF
            )
            .unwrap_err(),
            ColdStreamError::MissingSemanticWorkingSetPlan
        );
        assert_eq!(
            manifest_with_refs(
                SEMANTIC_PLAN_REF,
                "bad-page-table",
                ADMISSION_REF,
                SCOPE_REX_REF,
                SOVEREIGN_GATE_REF
            )
            .unwrap_err(),
            ColdStreamError::MissingResidencyPageTable
        );
        assert_eq!(
            manifest_with_refs(
                SEMANTIC_PLAN_REF,
                PAGE_TABLE_REF,
                "bad-admission",
                SCOPE_REX_REF,
                SOVEREIGN_GATE_REF
            )
            .unwrap_err(),
            ColdStreamError::MissingAdmission
        );
        assert_eq!(
            manifest_with_refs(
                SEMANTIC_PLAN_REF,
                PAGE_TABLE_REF,
                ADMISSION_REF,
                "bad-scope",
                SOVEREIGN_GATE_REF
            )
            .unwrap_err(),
            ColdStreamError::MissingScopeRex
        );
        assert_eq!(
            manifest_with_refs(
                SEMANTIC_PLAN_REF,
                PAGE_TABLE_REF,
                ADMISSION_REF,
                SCOPE_REX_REF,
                "bad-sovereign"
            )
            .unwrap_err(),
            ColdStreamError::MissingSovereignGate
        );
    }

    #[test]
    fn manifest_rejects_hidden_authority_and_mutation() {
        assert_eq!(
            manifest_with_flags(
                ColdStreamAuthority::LiveTransportAuthority,
                false,
                false,
                0,
                0
            )
            .unwrap_err(),
            ColdStreamError::HiddenTransportAuthority
        );
        assert_eq!(
            manifest_with_flags(ColdStreamAuthority::ProposalOnly, true, false, 0, 0).unwrap_err(),
            ColdStreamError::ByteWakeWithoutLease
        );
        assert_eq!(
            manifest_with_flags(ColdStreamAuthority::ProposalOnly, false, true, 0, 0).unwrap_err(),
            ColdStreamError::RoutePolicyMutation
        );
        assert_eq!(
            manifest_with_flags(ColdStreamAuthority::ProposalOnly, false, false, 1, 0).unwrap_err(),
            ColdStreamError::RuntimeBytesLoaded
        );
        assert_eq!(
            manifest_with_flags(ColdStreamAuthority::ProposalOnly, false, false, 0, 1).unwrap_err(),
            ColdStreamError::ModelBytesLoaded
        );
    }

    #[test]
    fn page_runs_reject_empty_duplicate_and_bad_ranges() {
        assert_eq!(
            ColdStreamTransportManifest::new(
                "coldstream-manifest-empty",
                "route:coldstream:empty",
                SEMANTIC_PLAN_REF,
                PAGE_TABLE_REF,
                ADMISSION_REF,
                SCOPE_REX_REF,
                SOVEREIGN_GATE_REF,
                ROLLBACK_REF,
                RUN_EVENT_LOG_REF,
                ANSWER_PACKET_REF,
                FALLBACK_REF,
                CANCELLATION_GROUP,
                ColdStreamAuthority::ProposalOnly,
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                vec![],
                false,
                false,
                false,
                false,
                false,
                false,
                false,
                0,
                0,
                CREATED_AT_MS,
            )
            .unwrap_err(),
            ColdStreamError::EmptyPageRun
        );

        let mut duplicate_runs = fixture_runs().expect("runs");
        duplicate_runs.push(duplicate_runs[0].clone());
        assert!(matches!(
            ColdStreamTransportManifest::new(
                "coldstream-manifest-duplicate",
                "route:coldstream:duplicate",
                SEMANTIC_PLAN_REF,
                PAGE_TABLE_REF,
                ADMISSION_REF,
                SCOPE_REX_REF,
                SOVEREIGN_GATE_REF,
                ROLLBACK_REF,
                RUN_EVENT_LOG_REF,
                ANSWER_PACKET_REF,
                FALLBACK_REF,
                CANCELLATION_GROUP,
                ColdStreamAuthority::ProposalOnly,
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                duplicate_runs,
                false,
                false,
                false,
                false,
                false,
                false,
                false,
                0,
                0,
                CREATED_AT_MS,
            )
            .unwrap_err(),
            ColdStreamError::DuplicateRunId { .. }
        ));

        assert_eq!(
            ColdStreamPageRun::new(
                "run:bad-range",
                "file:bad-range",
                0,
                0,
                vec!["semantic:bad-range".to_string()],
                vec![uas_address("bad-range")],
                "nf4",
                "sha256:bad-range",
                ColdStreamDestination::CpuSlab,
                ColdStreamPriority::Urgent,
                ColdStreamCachePolicy::NoCache,
                "lease:bad-range",
                "compat:coldstream:v1",
            )
            .unwrap_err(),
            ColdStreamError::InvalidByteRange
        );
    }

    #[test]
    fn trace_rejects_stale_or_invisible_paths() {
        let manifest = fixture_manifest().expect("fixture manifest");
        assert_eq!(
            ColdStreamTransportTrace::new(
                &manifest,
                "trace:bad-stale",
                manifest.planned_bytes(),
                manifest.planned_bytes(),
                manifest.planned_bytes(),
                1,
                1,
                3,
                4,
                10_000,
                true,
                true,
                RUN_EVENT_LOG_REF,
                ANSWER_PACKET_REF,
            )
            .unwrap_err(),
            ColdStreamError::StaleSlabEnteredExecution
        );
        assert_eq!(
            ColdStreamTransportTrace::new(
                &manifest,
                "trace:no-packet",
                manifest.planned_bytes(),
                manifest.planned_bytes(),
                manifest.planned_bytes(),
                1,
                1,
                3,
                4,
                10_000,
                false,
                true,
                RUN_EVENT_LOG_REF,
                "answer_packet:other",
            )
            .unwrap_err(),
            ColdStreamError::TraceMissingAnswerPacket
        );
        assert_eq!(
            ColdStreamTransportTrace::new(
                &manifest,
                "trace:no-fallback",
                manifest.planned_bytes(),
                manifest.planned_bytes(),
                manifest.planned_bytes(),
                1,
                1,
                3,
                4,
                10_000,
                false,
                false,
                RUN_EVENT_LOG_REF,
                ANSWER_PACKET_REF,
            )
            .unwrap_err(),
            ColdStreamError::TraceFallbackMissing
        );
    }

    const SEMANTIC_PLAN_REF: &str = "uas:semantic_working_set_plan:fixture@1779552000000";
    const PAGE_TABLE_REF: &str = "residency_page_table:coldstream:v1";
    const ADMISSION_REF: &str = "admission:scope-rex-sovereign:coldstream:v1";
    const SCOPE_REX_REF: &str = "scope_rex:coldstream:v1";
    const SOVEREIGN_GATE_REF: &str = "sovereign_gate:coldstream:v1";
    const ROLLBACK_REF: &str = "rollback:coldstream:v1";
    const RUN_EVENT_LOG_REF: &str = "run_event_log:coldstream:v1";
    const ANSWER_PACKET_REF: &str = "answer_packet:coldstream:v1";
    const FALLBACK_REF: &str = "fallback:cold_panic_visible:v1";
    const CANCELLATION_GROUP: &str = "cancel_group:coldstream:v1";

    fn fixture_manifest() -> Result<ColdStreamTransportManifest, ColdStreamError> {
        ColdStreamTransportManifest::new(
            "coldstream-manifest-local-research",
            "route:coldstream:local-research",
            SEMANTIC_PLAN_REF,
            PAGE_TABLE_REF,
            ADMISSION_REF,
            SCOPE_REX_REF,
            SOVEREIGN_GATE_REF,
            ROLLBACK_REF,
            RUN_EVENT_LOG_REF,
            ANSWER_PACKET_REF,
            FALLBACK_REF,
            CANCELLATION_GROUP,
            ColdStreamAuthority::ProposalOnly,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            fixture_runs()?,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            0,
            0,
            CREATED_AT_MS,
        )
    }

    fn manifest_with_refs(
        semantic_plan_ref: &str,
        page_table_ref: &str,
        admission_ref: &str,
        scope_rex_ref: &str,
        sovereign_gate_ref: &str,
    ) -> Result<ColdStreamTransportManifest, ColdStreamError> {
        ColdStreamTransportManifest::new(
            "coldstream-manifest-ref-test",
            "route:coldstream:ref-test",
            semantic_plan_ref,
            page_table_ref,
            admission_ref,
            scope_rex_ref,
            sovereign_gate_ref,
            ROLLBACK_REF,
            RUN_EVENT_LOG_REF,
            ANSWER_PACKET_REF,
            FALLBACK_REF,
            CANCELLATION_GROUP,
            ColdStreamAuthority::ProposalOnly,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            fixture_runs()?,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            0,
            0,
            CREATED_AT_MS,
        )
    }

    fn manifest_with_flags(
        authority: ColdStreamAuthority,
        byte_wake_without_lease: bool,
        route_policy_mutated: bool,
        runtime_bytes_loaded: u64,
        model_bytes_loaded: u64,
    ) -> Result<ColdStreamTransportManifest, ColdStreamError> {
        ColdStreamTransportManifest::new(
            "coldstream-manifest-flag-test",
            "route:coldstream:flag-test",
            SEMANTIC_PLAN_REF,
            PAGE_TABLE_REF,
            ADMISSION_REF,
            SCOPE_REX_REF,
            SOVEREIGN_GATE_REF,
            ROLLBACK_REF,
            RUN_EVENT_LOG_REF,
            ANSWER_PACKET_REF,
            FALLBACK_REF,
            CANCELLATION_GROUP,
            authority,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            fixture_runs()?,
            byte_wake_without_lease,
            route_policy_mutated,
            false,
            false,
            false,
            false,
            false,
            runtime_bytes_loaded,
            model_bytes_loaded,
            CREATED_AT_MS,
        )
    }

    fn fixture_trace(
        manifest: &ColdStreamTransportManifest,
    ) -> Result<ColdStreamTransportTrace, ColdStreamError> {
        ColdStreamTransportTrace::new(
            manifest,
            "trace:coldstream:local-research",
            manifest.planned_bytes(),
            manifest.planned_bytes() + 4096,
            manifest.planned_bytes(),
            2,
            1,
            3,
            5,
            10_120,
            false,
            true,
            RUN_EVENT_LOG_REF,
            ANSWER_PACKET_REF,
        )
    }

    fn fixture_runs() -> Result<Vec<ColdStreamPageRun>, ColdStreamError> {
        Ok(vec![
            ColdStreamPageRun::new(
                "run:local-research:evidence",
                "file:appcoldstore:evidence-pack",
                0,
                128 * 1024,
                vec!["semantic:evidence-page".to_string()],
                vec![uas_address("evidence-page")],
                "raw",
                "sha256:evidencepack000000000000000000000000000000000000000000000000000000000000",
                ColdStreamDestination::CpuSlab,
                ColdStreamPriority::Urgent,
                ColdStreamCachePolicy::NoCache,
                "lease:coldstream:evidence",
                "compat:coldstream:v1",
            )?,
            ColdStreamPageRun::new(
                "run:local-research:kv",
                "file:appcoldstore:kv-pack",
                128 * 1024,
                128 * 1024,
                vec!["semantic:kv-page".to_string()],
                vec![uas_address("kv-page")],
                "nf4",
                "sha256:kvpack00000000000000000000000000000000000000000000000000000000000000",
                ColdStreamDestination::MlxReadySlab,
                ColdStreamPriority::Prefetch,
                ColdStreamCachePolicy::NoCache,
                "lease:coldstream:kv",
                "compat:coldstream:v1",
            )?,
            ColdStreamPageRun::new(
                "run:local-research:verifier",
                "file:appcoldstore:verifier-pack",
                256 * 1024,
                128 * 1024,
                vec!["semantic:verifier-page".to_string()],
                vec![uas_address("verifier-page")],
                "raw",
                "sha256:verifierpack00000000000000000000000000000000000000000000000000000000",
                ColdStreamDestination::MetalBuffer,
                ColdStreamPriority::Background,
                ColdStreamCachePolicy::HotReuse,
                "lease:coldstream:verifier",
                "compat:coldstream:v1",
            )?,
        ])
    }

    fn uas_address(label: &str) -> UasAddress {
        UasAddress::new(
            UasKind::Other("coldstream_test_unit".to_string()),
            label.as_bytes(),
            CREATED_AT_MS,
        )
    }
}
