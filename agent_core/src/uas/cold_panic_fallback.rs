//! Cold panic fallback contracts for ColdStream transport.
//!
//! This is a metadata-only witness: it proves missed cold-transport deadlines
//! degrade into visible, rollback-bound fallback before live ColdStream,
//! mmap replacement, or large-model residency can promote.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const COLD_PANIC_FALLBACK_CURSOR: &str = "cold_panic_fallback";
pub const COLD_PANIC_FALLBACK_NEXT_CURSOR: &str = "ready_for_product_route_review";

const MISSED_RUN_PREFIX: &str = "missed_run:";
const DEADLINE_PREFIX: &str = "transport_deadline:";
const TRANSPORT_TRACE_PREFIX: &str = "transport_trace:";
const CACHE_POLICY_PREFIX: &str = "cache_policy:";
const CANCELLATION_PREFIX: &str = "transport_cancellation:";
const FALLBACK_ROUTE_PREFIX: &str = "fallback_route:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const MAX_METADATA_BYTES: u64 = 256 * 1024;
const MAX_TOKEN_BLOCK_MS: u32 = 16;
const MAX_FALLBACK_LATENCY_MS: u32 = 64;
const MIN_SUCCESS_BPS: u32 = 9_400;
const MIN_VISIBLE_TEXT_BYTES: usize = 144;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:cold-panic-fallback:route
// Plane: Controller + Verification
// Residency: metadata-only fallback route; no runtime bytes are loaded.
pub enum ColdFallbackRoute {
    HotDegradedRoute,
    CachedSummary,
    BackgroundRepairQueue,
}

impl ColdFallbackRoute {
    fn tag(&self) -> &'static str {
        match self {
            Self::HotDegradedRoute => "hot_degraded_route",
            Self::CachedSummary => "cached_summary",
            Self::BackgroundRepairQueue => "background_repair_queue",
        }
    }

    pub fn required_marker(&self) -> &'static str {
        match self {
            Self::HotDegradedRoute => "hot-degraded",
            Self::CachedSummary => "cached-summary",
            Self::BackgroundRepairQueue => "background-repair",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:cold-panic-fallback:error
// Plane: Verification
// Residency: metadata-only rejection taxonomy.
pub enum ColdPanicFallbackError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyRun,
    EmptySurface,
    DuplicateRun(String),
    DuplicateSurface(String),
    DuplicateAnswerPacket(String),
    MissingMissedRun(String),
    MissingDeadline(String),
    MissingTransportTrace(String),
    MissingCachePolicy(String),
    MissingCancellation(String),
    MissingFallbackRoute(String),
    MissingAnswerPacket(String),
    MissingRunEventLog(String),
    MissingRollback(String),
    MissingAdmission,
    MissingScopeRex,
    MissingSovereignGate,
    MissingCompatibilityFence(String),
    MissingQualityCaveat(String),
    MissingUserVisibleLimit(String),
    MissingRequiredMarker(String),
    ForbiddenMarker(String),
    MissingLayerSeparation,
    MissingHotDegradedRoute,
    MissingCachedSummaryRoute,
    MissingBackgroundRepairRoute,
    DeadlineNotMissed(String),
    ZeroDeadline(String),
    ZeroColdBytes(String),
    TokenBlockBudgetExceeded(String),
    FallbackLatencyExceeded(String),
    ColdWakeNotAborted(String),
    StaleSlabExecutionAllowed(String),
    InvisibleFallback(String),
    BackgroundRepairMissing(String),
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

impl fmt::Display for ColdPanicFallbackError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyRun => write!(f, "missing cold panic fallback run"),
            Self::EmptySurface => write!(f, "missing cold panic visible surface"),
            Self::DuplicateRun(id) => write!(f, "duplicate fallback run `{id}`"),
            Self::DuplicateSurface(id) => write!(f, "duplicate fallback surface `{id}`"),
            Self::DuplicateAnswerPacket(id) => write!(f, "duplicate AnswerPacket `{id}`"),
            Self::MissingMissedRun(id) => write!(f, "run `{id}` missing missed run ref"),
            Self::MissingDeadline(id) => write!(f, "run `{id}` missing deadline ref"),
            Self::MissingTransportTrace(id) => write!(f, "run `{id}` missing transport trace"),
            Self::MissingCachePolicy(id) => write!(f, "run `{id}` missing cache policy ref"),
            Self::MissingCancellation(id) => {
                write!(f, "run `{id}` missing transport cancellation ref")
            }
            Self::MissingFallbackRoute(id) => write!(f, "run `{id}` missing fallback route"),
            Self::MissingAnswerPacket(id) => write!(f, "run `{id}` missing AnswerPacket ref"),
            Self::MissingRunEventLog(id) => write!(f, "run `{id}` missing RunEventLog ref"),
            Self::MissingRollback(id) => write!(f, "run `{id}` missing rollback ref"),
            Self::MissingAdmission => write!(f, "missing admission ref"),
            Self::MissingScopeRex => write!(f, "missing SCOPE-Rex ref"),
            Self::MissingSovereignGate => write!(f, "missing SovereignGate ref"),
            Self::MissingCompatibilityFence(id) => {
                write!(f, "run `{id}` missing compatibility fence")
            }
            Self::MissingQualityCaveat(id) => write!(f, "run `{id}` missing quality caveat"),
            Self::MissingUserVisibleLimit(id) => {
                write!(f, "run `{id}` missing user-visible limit")
            }
            Self::MissingRequiredMarker(marker) => write!(f, "missing marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}`"),
            Self::MissingLayerSeparation => write!(f, "L1/L2/L3 separation missing"),
            Self::MissingHotDegradedRoute => write!(f, "missing hot degraded route fallback"),
            Self::MissingCachedSummaryRoute => write!(f, "missing cached summary fallback"),
            Self::MissingBackgroundRepairRoute => write!(f, "missing background repair fallback"),
            Self::DeadlineNotMissed(id) => write!(f, "run `{id}` did not miss its deadline"),
            Self::ZeroDeadline(id) => write!(f, "run `{id}` has zero deadline"),
            Self::ZeroColdBytes(id) => write!(f, "run `{id}` has zero requested cold bytes"),
            Self::TokenBlockBudgetExceeded(id) => {
                write!(f, "run `{id}` exceeded token block budget")
            }
            Self::FallbackLatencyExceeded(id) => {
                write!(f, "run `{id}` exceeded fallback latency budget")
            }
            Self::ColdWakeNotAborted(id) => write!(f, "run `{id}` did not abort cold wake"),
            Self::StaleSlabExecutionAllowed(id) => {
                write!(f, "run `{id}` allowed stale slab execution")
            }
            Self::InvisibleFallback(id) => write!(f, "run `{id}` fallback is not visible"),
            Self::BackgroundRepairMissing(id) => {
                write!(f, "run `{id}` missing background repair queue")
            }
            Self::ProductStatusMismatch => write!(f, "product status promoted beyond Pro Research"),
            Self::HiddenRouteAuthority => write!(f, "hidden route authority attempted"),
            Self::RoutePolicyMutation => write!(f, "route policy mutation attempted"),
            Self::GateBypass => write!(f, "cold panic fallback gate bypass attempted"),
            Self::AnswerPacketSuppression => write!(f, "AnswerPacket suppression attempted"),
            Self::HiddenChainExposure => write!(f, "hidden chain exposure attempted"),
            Self::HiddenCloudRoute => write!(f, "hidden cloud route attempted"),
            Self::SsdAsRamClaim => write!(f, "SSD-as-RAM claim attempted"),
            Self::MasPromotionAttempted => write!(f, "MAS/Live promotion attempted"),
            Self::LiveBenchmarkAttempted => write!(f, "live benchmark attempted"),
            Self::RuntimeBytesLoaded => write!(f, "metadata witness loaded runtime bytes"),
            Self::ModelBytesLoaded => write!(f, "metadata witness loaded model bytes"),
            Self::TransportRuntimeBytesLoaded => {
                write!(f, "metadata witness loaded transport runtime bytes")
            }
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
            Self::BaselineUnbeaten(name) => write!(f, "baseline `{name}` was unbeaten"),
        }
    }
}

impl std::error::Error for ColdPanicFallbackError {}

#[derive(Clone, Debug)]
// UAS: uas:cold-panic-fallback:run
// Plane: Controller + Verification
// Residency: metadata-only missed-deadline fallback run.
pub struct ColdPanicFallbackRun {
    pub run_id: String,
    pub mission_id: String,
    pub route_id: String,
    pub missed_run_ref: String,
    pub deadline_ref: String,
    pub transport_trace_ref: String,
    pub cache_policy_ref: String,
    pub cancellation_ref: String,
    pub fallback_route: ColdFallbackRoute,
    pub fallback_route_ref: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub rollback_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence: String,
    pub requested_cold_bytes: u64,
    pub deadline_ms: u32,
    pub elapsed_ms: u32,
    pub token_block_ms: u32,
    pub max_allowed_token_block_ms: u32,
    pub fallback_latency_ms: u32,
    pub cold_wake_aborted: bool,
    pub stale_slab_rejected: bool,
    pub visible_to_user: bool,
    pub background_repair_queued: bool,
    pub quality_caveat: String,
    pub user_visible_limit: String,
    pub l1_l2_l3_separated: bool,
}

impl ColdPanicFallbackRun {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        run_id: impl Into<String>,
        mission_id: impl Into<String>,
        route_id: impl Into<String>,
        missed_run_ref: impl Into<String>,
        deadline_ref: impl Into<String>,
        transport_trace_ref: impl Into<String>,
        cache_policy_ref: impl Into<String>,
        cancellation_ref: impl Into<String>,
        fallback_route: ColdFallbackRoute,
        fallback_route_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        admission_ref: impl Into<String>,
        scope_rex_ref: impl Into<String>,
        sovereign_gate_ref: impl Into<String>,
        compatibility_fence: impl Into<String>,
        requested_cold_bytes: u64,
        deadline_ms: u32,
        elapsed_ms: u32,
        token_block_ms: u32,
        max_allowed_token_block_ms: u32,
        fallback_latency_ms: u32,
        cold_wake_aborted: bool,
        stale_slab_rejected: bool,
        visible_to_user: bool,
        background_repair_queued: bool,
        quality_caveat: impl Into<String>,
        user_visible_limit: impl Into<String>,
        l1_l2_l3_separated: bool,
    ) -> Result<Self, ColdPanicFallbackError> {
        let run = Self {
            run_id: run_id.into(),
            mission_id: mission_id.into(),
            route_id: route_id.into(),
            missed_run_ref: missed_run_ref.into(),
            deadline_ref: deadline_ref.into(),
            transport_trace_ref: transport_trace_ref.into(),
            cache_policy_ref: cache_policy_ref.into(),
            cancellation_ref: cancellation_ref.into(),
            fallback_route,
            fallback_route_ref: fallback_route_ref.into(),
            answer_packet_ref: answer_packet_ref.into(),
            run_event_log_ref: run_event_log_ref.into(),
            rollback_ref: rollback_ref.into(),
            admission_ref: admission_ref.into(),
            scope_rex_ref: scope_rex_ref.into(),
            sovereign_gate_ref: sovereign_gate_ref.into(),
            compatibility_fence: compatibility_fence.into(),
            requested_cold_bytes,
            deadline_ms,
            elapsed_ms,
            token_block_ms,
            max_allowed_token_block_ms,
            fallback_latency_ms,
            cold_wake_aborted,
            stale_slab_rejected,
            visible_to_user,
            background_repair_queued,
            quality_caveat: quality_caveat.into(),
            user_visible_limit: user_visible_limit.into(),
            l1_l2_l3_separated,
        };
        validate_run(&run)?;
        Ok(run)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:cold-panic-fallback:surface
// Plane: Verification
// Residency: visible metadata-only fallback caveat surface.
pub struct ColdPanicSurface {
    pub surface_id: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub fallback_ref: String,
    pub visible_summary: String,
}

impl ColdPanicSurface {
    pub fn new(
        surface_id: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        fallback_ref: impl Into<String>,
        visible_summary: impl Into<String>,
    ) -> Result<Self, ColdPanicFallbackError> {
        let surface = Self {
            surface_id: surface_id.into(),
            answer_packet_ref: answer_packet_ref.into(),
            run_event_log_ref: run_event_log_ref.into(),
            fallback_ref: fallback_ref.into(),
            visible_summary: visible_summary.into(),
        };
        validate_surface(&surface)?;
        Ok(surface)
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
// UAS: uas:cold-panic-fallback:metrics
// Plane: Verification
// Residency: metadata-only aggregate.
pub struct ColdPanicFallbackMetrics {
    pub run_count: usize,
    pub surface_count: usize,
    pub answer_packet_count: usize,
    pub run_event_log_count: usize,
    pub fallback_route_count: usize,
    pub hot_degraded_count: usize,
    pub cached_summary_count: usize,
    pub background_repair_route_count: usize,
    pub total_requested_cold_bytes: u64,
    pub max_deadline_ms: u32,
    pub max_elapsed_ms: u32,
    pub max_token_block_ms: u32,
    pub max_fallback_latency_ms: u32,
    pub stale_slab_rejection_count: usize,
    pub visible_fallback_count: usize,
    pub repair_queued_count: usize,
}

#[derive(Clone, Debug)]
// UAS: uas:cold-panic-fallback:witness
// Plane: Verification
// Residency: metadata-only; live transport/model/runtime bytes must stay zero.
pub struct ColdPanicFallbackWitness {
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub cold_panic_success_bps: u32,
    pub wait_forever_baseline_bps: u32,
    pub hidden_caveat_baseline_bps: u32,
    pub stale_slab_baseline_bps: u32,
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
    pub runs: Vec<ColdPanicFallbackRun>,
    pub surfaces: Vec<ColdPanicSurface>,
}

impl ColdPanicFallbackWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        cold_panic_success_bps: u32,
        wait_forever_baseline_bps: u32,
        hidden_caveat_baseline_bps: u32,
        stale_slab_baseline_bps: u32,
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
        runs: Vec<ColdPanicFallbackRun>,
        surfaces: Vec<ColdPanicSurface>,
    ) -> Result<Self, ColdPanicFallbackError> {
        let witness = Self {
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            cold_panic_success_bps,
            wait_forever_baseline_bps,
            hidden_caveat_baseline_bps,
            stale_slab_baseline_bps,
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

    pub fn metrics(&self) -> ColdPanicFallbackMetrics {
        let mut answer_packets = BTreeSet::new();
        let mut run_event_logs = BTreeSet::new();
        let mut routes = BTreeSet::new();
        let mut metrics = ColdPanicFallbackMetrics {
            run_count: self.runs.len(),
            surface_count: self.surfaces.len(),
            ..ColdPanicFallbackMetrics::default()
        };
        for run in &self.runs {
            answer_packets.insert(run.answer_packet_ref.clone());
            run_event_logs.insert(run.run_event_log_ref.clone());
            routes.insert(run.fallback_route.clone());
            metrics.total_requested_cold_bytes = metrics
                .total_requested_cold_bytes
                .saturating_add(run.requested_cold_bytes);
            metrics.max_deadline_ms = metrics.max_deadline_ms.max(run.deadline_ms);
            metrics.max_elapsed_ms = metrics.max_elapsed_ms.max(run.elapsed_ms);
            metrics.max_token_block_ms = metrics.max_token_block_ms.max(run.token_block_ms);
            metrics.max_fallback_latency_ms =
                metrics.max_fallback_latency_ms.max(run.fallback_latency_ms);
            if run.stale_slab_rejected {
                metrics.stale_slab_rejection_count += 1;
            }
            if run.visible_to_user {
                metrics.visible_fallback_count += 1;
            }
            if run.background_repair_queued {
                metrics.repair_queued_count += 1;
            }
            match run.fallback_route {
                ColdFallbackRoute::HotDegradedRoute => metrics.hot_degraded_count += 1,
                ColdFallbackRoute::CachedSummary => metrics.cached_summary_count += 1,
                ColdFallbackRoute::BackgroundRepairQueue => {
                    metrics.background_repair_route_count += 1
                }
            }
        }
        for surface in &self.surfaces {
            answer_packets.insert(surface.answer_packet_ref.clone());
            run_event_logs.insert(surface.run_event_log_ref.clone());
        }
        metrics.answer_packet_count = answer_packets.len();
        metrics.run_event_log_count = run_event_logs.len();
        metrics.fallback_route_count = routes.len();
        metrics
    }

    pub fn address(&self) -> String {
        let mut run_parts = self
            .runs
            .iter()
            .map(|run| {
                format!(
                    "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
                    run.run_id,
                    run.mission_id,
                    run.route_id,
                    run.missed_run_ref,
                    run.deadline_ref,
                    run.transport_trace_ref,
                    run.cache_policy_ref,
                    run.cancellation_ref,
                    run.fallback_route.tag(),
                    run.fallback_route_ref,
                    run.answer_packet_ref,
                    run.run_event_log_ref,
                    run.rollback_ref,
                    run.admission_ref,
                    run.compatibility_fence,
                    run.requested_cold_bytes,
                    run.deadline_ms,
                    run.elapsed_ms,
                    run.token_block_ms,
                    run.fallback_latency_ms,
                    run.cold_wake_aborted,
                    run.stale_slab_rejected,
                    run.visible_to_user
                )
            })
            .collect::<Vec<_>>();
        run_parts.sort();
        let mut surface_parts = self
            .surfaces
            .iter()
            .map(|surface| {
                format!(
                    "{}|{}|{}|{}|{}",
                    surface.surface_id,
                    surface.answer_packet_ref,
                    surface.run_event_log_ref,
                    surface.fallback_ref,
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
                "{}|{}|{}|{}|{}|{}|{}|{}|{}",
                product_build,
                pro_status,
                self.route_authority,
                self.cold_panic_success_bps,
                self.wait_forever_baseline_bps,
                self.hidden_caveat_baseline_bps,
                self.stale_slab_baseline_bps,
                run_parts.join(";;"),
                surface_parts.join(";;")
            )
            .as_bytes(),
        );
        format!("uas:cold-panic-fallback:{digest}")
    }
}

fn validate_witness(witness: &ColdPanicFallbackWitness) -> Result<(), ColdPanicFallbackError> {
    if witness.product_build != ProductBuild::Pro
        || witness.pro_status != ProStatus::ResearchCandidate
        || witness.route_authority != "cold_panic_fallback_gate_only"
    {
        return Err(ColdPanicFallbackError::ProductStatusMismatch);
    }
    if witness.runs.is_empty() {
        return Err(ColdPanicFallbackError::EmptyRun);
    }
    if witness.surfaces.is_empty() {
        return Err(ColdPanicFallbackError::EmptySurface);
    }

    let mut run_ids = HashSet::with_capacity(witness.runs.len());
    let mut surface_ids = HashSet::with_capacity(witness.surfaces.len());
    let mut answer_packets = HashSet::with_capacity(witness.runs.len() + witness.surfaces.len());
    let mut has_hot_degraded = false;
    let mut has_cached_summary = false;
    let mut has_background_repair = false;
    for run in &witness.runs {
        validate_run(run)?;
        if !run_ids.insert(run.run_id.clone()) {
            return Err(ColdPanicFallbackError::DuplicateRun(run.run_id.clone()));
        }
        if !answer_packets.insert(run.answer_packet_ref.clone()) {
            return Err(ColdPanicFallbackError::DuplicateAnswerPacket(
                run.answer_packet_ref.clone(),
            ));
        }
        if !run.l1_l2_l3_separated
            || !contains_layer_separation(&run.quality_caveat)
            || !contains_layer_separation(&run.user_visible_limit)
        {
            return Err(ColdPanicFallbackError::MissingLayerSeparation);
        }
        match run.fallback_route {
            ColdFallbackRoute::HotDegradedRoute => has_hot_degraded = true,
            ColdFallbackRoute::CachedSummary => has_cached_summary = true,
            ColdFallbackRoute::BackgroundRepairQueue => has_background_repair = true,
        }
    }
    for surface in &witness.surfaces {
        validate_surface(surface)?;
        if !surface_ids.insert(surface.surface_id.clone()) {
            return Err(ColdPanicFallbackError::DuplicateSurface(
                surface.surface_id.clone(),
            ));
        }
        if !contains_layer_separation(&surface.visible_summary) {
            return Err(ColdPanicFallbackError::MissingLayerSeparation);
        }
    }
    if !has_hot_degraded {
        return Err(ColdPanicFallbackError::MissingHotDegradedRoute);
    }
    if !has_cached_summary {
        return Err(ColdPanicFallbackError::MissingCachedSummaryRoute);
    }
    if !has_background_repair {
        return Err(ColdPanicFallbackError::MissingBackgroundRepairRoute);
    }
    if witness.hidden_route_authority {
        return Err(ColdPanicFallbackError::HiddenRouteAuthority);
    }
    if witness.route_policy_mutation {
        return Err(ColdPanicFallbackError::RoutePolicyMutation);
    }
    if witness.gate_bypass {
        return Err(ColdPanicFallbackError::GateBypass);
    }
    if witness.answer_packet_suppression {
        return Err(ColdPanicFallbackError::AnswerPacketSuppression);
    }
    if witness.hidden_chain_exposed {
        return Err(ColdPanicFallbackError::HiddenChainExposure);
    }
    if witness.hidden_cloud_route {
        return Err(ColdPanicFallbackError::HiddenCloudRoute);
    }
    if witness.ssd_as_ram_claim {
        return Err(ColdPanicFallbackError::SsdAsRamClaim);
    }
    if witness.mas_promotion_attempted {
        return Err(ColdPanicFallbackError::MasPromotionAttempted);
    }
    if witness.live_benchmark_attempted {
        return Err(ColdPanicFallbackError::LiveBenchmarkAttempted);
    }
    if witness.runtime_bytes_loaded != 0 {
        return Err(ColdPanicFallbackError::RuntimeBytesLoaded);
    }
    if witness.model_bytes_loaded != 0 {
        return Err(ColdPanicFallbackError::ModelBytesLoaded);
    }
    if witness.transport_runtime_bytes_loaded != 0 {
        return Err(ColdPanicFallbackError::TransportRuntimeBytesLoaded);
    }
    if witness.max_metadata_bytes > MAX_METADATA_BYTES {
        return Err(ColdPanicFallbackError::MetadataBudgetExceeded);
    }
    if witness.cold_panic_success_bps < MIN_SUCCESS_BPS {
        return Err(ColdPanicFallbackError::BaselineUnbeaten(
            "cold_panic_success",
        ));
    }
    for (name, baseline) in [
        ("wait_forever", witness.wait_forever_baseline_bps),
        ("hidden_caveat", witness.hidden_caveat_baseline_bps),
        ("stale_slab", witness.stale_slab_baseline_bps),
        ("live_authority", witness.live_authority_baseline_bps),
    ] {
        if witness.cold_panic_success_bps <= baseline {
            return Err(ColdPanicFallbackError::BaselineUnbeaten(name));
        }
    }
    Ok(())
}

fn validate_run(run: &ColdPanicFallbackRun) -> Result<(), ColdPanicFallbackError> {
    validate_nonempty_clean("run_id", &run.run_id)?;
    validate_nonempty_clean("mission_id", &run.mission_id)?;
    validate_nonempty_clean("route_id", &run.route_id)?;
    validate_nonempty_clean("quality_caveat", &run.quality_caveat)?;
    validate_nonempty_clean("user_visible_limit", &run.user_visible_limit)?;
    validate_prefixed(
        "missed_run_ref",
        &run.missed_run_ref,
        MISSED_RUN_PREFIX,
        ColdPanicFallbackError::MissingMissedRun(run.run_id.clone()),
    )?;
    validate_prefixed(
        "deadline_ref",
        &run.deadline_ref,
        DEADLINE_PREFIX,
        ColdPanicFallbackError::MissingDeadline(run.run_id.clone()),
    )?;
    validate_prefixed(
        "transport_trace_ref",
        &run.transport_trace_ref,
        TRANSPORT_TRACE_PREFIX,
        ColdPanicFallbackError::MissingTransportTrace(run.run_id.clone()),
    )?;
    validate_prefixed(
        "cache_policy_ref",
        &run.cache_policy_ref,
        CACHE_POLICY_PREFIX,
        ColdPanicFallbackError::MissingCachePolicy(run.run_id.clone()),
    )?;
    validate_prefixed(
        "cancellation_ref",
        &run.cancellation_ref,
        CANCELLATION_PREFIX,
        ColdPanicFallbackError::MissingCancellation(run.run_id.clone()),
    )?;
    validate_prefixed(
        "fallback_route_ref",
        &run.fallback_route_ref,
        FALLBACK_ROUTE_PREFIX,
        ColdPanicFallbackError::MissingFallbackRoute(run.run_id.clone()),
    )?;
    validate_prefixed(
        "answer_packet_ref",
        &run.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
        ColdPanicFallbackError::MissingAnswerPacket(run.run_id.clone()),
    )?;
    validate_prefixed(
        "run_event_log_ref",
        &run.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
        ColdPanicFallbackError::MissingRunEventLog(run.run_id.clone()),
    )?;
    validate_prefixed(
        "rollback_ref",
        &run.rollback_ref,
        ROLLBACK_PREFIX,
        ColdPanicFallbackError::MissingRollback(run.run_id.clone()),
    )?;
    validate_prefixed(
        "admission_ref",
        &run.admission_ref,
        ADMISSION_PREFIX,
        ColdPanicFallbackError::MissingAdmission,
    )?;
    validate_prefixed(
        "scope_rex_ref",
        &run.scope_rex_ref,
        SCOPE_REX_PREFIX,
        ColdPanicFallbackError::MissingScopeRex,
    )?;
    validate_prefixed(
        "sovereign_gate_ref",
        &run.sovereign_gate_ref,
        SOVEREIGN_GATE_PREFIX,
        ColdPanicFallbackError::MissingSovereignGate,
    )?;
    validate_prefixed(
        "compatibility_fence",
        &run.compatibility_fence,
        COMPATIBILITY_FENCE_PREFIX,
        ColdPanicFallbackError::MissingCompatibilityFence(run.run_id.clone()),
    )?;
    let marker = run.fallback_route.required_marker();
    if !run.fallback_route_ref.contains(marker) {
        return Err(ColdPanicFallbackError::MissingRequiredMarker(
            marker.to_string(),
        ));
    }
    if run.requested_cold_bytes == 0 {
        return Err(ColdPanicFallbackError::ZeroColdBytes(run.run_id.clone()));
    }
    if run.deadline_ms == 0 {
        return Err(ColdPanicFallbackError::ZeroDeadline(run.run_id.clone()));
    }
    if run.elapsed_ms <= run.deadline_ms {
        return Err(ColdPanicFallbackError::DeadlineNotMissed(
            run.run_id.clone(),
        ));
    }
    if run.max_allowed_token_block_ms > MAX_TOKEN_BLOCK_MS
        || run.token_block_ms > run.max_allowed_token_block_ms
    {
        return Err(ColdPanicFallbackError::TokenBlockBudgetExceeded(
            run.run_id.clone(),
        ));
    }
    if run.fallback_latency_ms > MAX_FALLBACK_LATENCY_MS {
        return Err(ColdPanicFallbackError::FallbackLatencyExceeded(
            run.run_id.clone(),
        ));
    }
    if !run.cold_wake_aborted {
        return Err(ColdPanicFallbackError::ColdWakeNotAborted(
            run.run_id.clone(),
        ));
    }
    if !run.stale_slab_rejected {
        return Err(ColdPanicFallbackError::StaleSlabExecutionAllowed(
            run.run_id.clone(),
        ));
    }
    if !run.visible_to_user {
        return Err(ColdPanicFallbackError::InvisibleFallback(
            run.run_id.clone(),
        ));
    }
    if !run.background_repair_queued {
        return Err(ColdPanicFallbackError::BackgroundRepairMissing(
            run.run_id.clone(),
        ));
    }
    for (field, text) in [
        ("quality_caveat", run.quality_caveat.as_str()),
        ("user_visible_limit", run.user_visible_limit.as_str()),
    ] {
        if text.len() < MIN_VISIBLE_TEXT_BYTES {
            return Err(match field {
                "quality_caveat" => {
                    ColdPanicFallbackError::MissingQualityCaveat(run.run_id.clone())
                }
                _ => ColdPanicFallbackError::MissingUserVisibleLimit(run.run_id.clone()),
            });
        }
        for marker in [
            "AnswerPacket",
            "RunEventLog",
            "rollback",
            "fallback",
            "deadline",
        ] {
            if !text.contains(marker) {
                return Err(ColdPanicFallbackError::MissingRequiredMarker(
                    marker.to_string(),
                ));
            }
        }
        for marker in [
            "hidden authority",
            "live transport ready",
            "70B done",
            "SSD = RAM",
            "cloud fallback",
        ] {
            if text.contains(marker) {
                return Err(ColdPanicFallbackError::ForbiddenMarker(marker.to_string()));
            }
        }
    }
    if !run.l1_l2_l3_separated
        || !contains_layer_separation(&run.quality_caveat)
        || !contains_layer_separation(&run.user_visible_limit)
    {
        return Err(ColdPanicFallbackError::MissingLayerSeparation);
    }
    Ok(())
}

fn validate_surface(surface: &ColdPanicSurface) -> Result<(), ColdPanicFallbackError> {
    validate_nonempty_clean("surface_id", &surface.surface_id)?;
    validate_prefixed(
        "answer_packet_ref",
        &surface.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
        ColdPanicFallbackError::MissingAnswerPacket(surface.surface_id.clone()),
    )?;
    validate_prefixed(
        "run_event_log_ref",
        &surface.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
        ColdPanicFallbackError::MissingRunEventLog(surface.surface_id.clone()),
    )?;
    validate_prefixed(
        "fallback_ref",
        &surface.fallback_ref,
        FALLBACK_ROUTE_PREFIX,
        ColdPanicFallbackError::MissingFallbackRoute(surface.surface_id.clone()),
    )?;
    validate_nonempty_clean("visible_summary", &surface.visible_summary)?;
    if surface.visible_summary.len() < MIN_VISIBLE_TEXT_BYTES {
        return Err(ColdPanicFallbackError::MissingUserVisibleLimit(
            surface.surface_id.clone(),
        ));
    }
    for marker in [
        "AnswerPacket",
        "RunEventLog",
        "rollback",
        "fallback",
        "deadline",
    ] {
        if !surface.visible_summary.contains(marker) {
            return Err(ColdPanicFallbackError::MissingRequiredMarker(
                marker.to_string(),
            ));
        }
    }
    for marker in [
        "hidden authority",
        "live transport ready",
        "70B done",
        "SSD = RAM",
        "cloud fallback",
    ] {
        if surface.visible_summary.contains(marker) {
            return Err(ColdPanicFallbackError::ForbiddenMarker(marker.to_string()));
        }
    }
    Ok(())
}

fn validate_nonempty_clean(field: &'static str, value: &str) -> Result<(), ColdPanicFallbackError> {
    if value.is_empty() {
        return Err(ColdPanicFallbackError::MissingField(field));
    }
    if value.trim() != value {
        return Err(ColdPanicFallbackError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(char::is_control) {
        return Err(ColdPanicFallbackError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

fn validate_prefixed(
    field: &'static str,
    value: &str,
    prefix: &str,
    missing: ColdPanicFallbackError,
) -> Result<(), ColdPanicFallbackError> {
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

    fn caveat(route: &ColdFallbackRoute) -> String {
        format!(
            "metadata-only cold deadline fallback for {}: missed transport deadline aborts the cold wake, records fallback in AnswerPacket and RunEventLog, keeps rollback visible, and advances L1 only while L2 and L3 remain unchanged.",
            route.required_marker()
        )
    }

    fn limit(route: &ColdFallbackRoute) -> String {
        format!(
            "user-visible fallback limit for {}: the answer states the cold deadline miss, uses a degraded or cached route, links AnswerPacket, RunEventLog, and rollback, and separates L1 evidence from L2 and L3 product runtime.",
            route.required_marker()
        )
    }

    fn run(
        id: &str,
        route: ColdFallbackRoute,
        token_block_ms: u32,
        fallback_latency_ms: u32,
    ) -> Result<ColdPanicFallbackRun, ColdPanicFallbackError> {
        let marker = route.required_marker();
        ColdPanicFallbackRun::new(
            id,
            "mission:coldstream-panic-fallback",
            format!("route:{id}"),
            format!("missed_run:{id}"),
            format!("transport_deadline:{id}:32ms"),
            format!("transport_trace:{id}"),
            format!("cache_policy:no-cache:{id}"),
            format!("transport_cancellation:{id}"),
            route.clone(),
            format!("fallback_route:{marker}:{id}"),
            format!("answer_packet:{id}"),
            format!("run_event_log:{id}"),
            format!("rollback:{id}"),
            "admission:cold-panic-fallback",
            "scope_rex:cold-panic-fallback",
            "sovereign_gate:cold-panic-fallback",
            "compat:cold-panic-fallback-v1",
            65_536,
            32,
            58,
            token_block_ms,
            MAX_TOKEN_BLOCK_MS,
            fallback_latency_ms,
            true,
            true,
            true,
            true,
            caveat(&route),
            limit(&route),
            true,
        )
    }

    fn surface(id: &str) -> Result<ColdPanicSurface, ColdPanicFallbackError> {
        ColdPanicSurface::new(
            id,
            format!("answer_packet:surface:{id}"),
            format!("run_event_log:surface:{id}"),
            format!("fallback_route:surface:{id}"),
            "metadata-only cold panic fallback surface: L1 records the missed cold deadline, visible fallback, AnswerPacket, RunEventLog, and rollback; L2 remains vault research and L3 product runtime is unchanged.",
        )
    }

    fn witness() -> Result<ColdPanicFallbackWitness, ColdPanicFallbackError> {
        ColdPanicFallbackWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "cold_panic_fallback_gate_only",
            9_610,
            8_120,
            8_260,
            8_030,
            8_050,
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
                run("hot-degraded", ColdFallbackRoute::HotDegradedRoute, 2, 18)?,
                run("cached-summary", ColdFallbackRoute::CachedSummary, 1, 12)?,
                run(
                    "background-repair",
                    ColdFallbackRoute::BackgroundRepairQueue,
                    0,
                    24,
                )?,
            ],
            vec![surface("surface-a")?, surface("surface-b")?],
        )
    }

    #[test]
    fn valid_witness_bounds_visible_fallback() {
        let witness = witness().expect("fixture witness");
        let metrics = witness.metrics();
        assert_eq!(metrics.run_count, 3);
        assert_eq!(metrics.fallback_route_count, 3);
        assert_eq!(metrics.hot_degraded_count, 1);
        assert_eq!(metrics.cached_summary_count, 1);
        assert_eq!(metrics.background_repair_route_count, 1);
        assert_eq!(metrics.max_token_block_ms, 2);
        assert_eq!(metrics.max_fallback_latency_ms, 24);
        assert_eq!(metrics.visible_fallback_count, 3);
        assert_eq!(metrics.stale_slab_rejection_count, 3);
        assert!(witness
            .address()
            .starts_with("uas:cold-panic-fallback:sha256:"));
    }

    #[test]
    fn deterministic_address_ignores_run_order() {
        let witness = witness().expect("fixture witness");
        let mut reversed_runs = witness.runs.clone();
        reversed_runs.reverse();
        let reversed = ColdPanicFallbackWitness::new(
            witness.product_build.clone(),
            witness.pro_status.clone(),
            witness.route_authority.clone(),
            witness.cold_panic_success_bps,
            witness.wait_forever_baseline_bps,
            witness.hidden_caveat_baseline_bps,
            witness.stale_slab_baseline_bps,
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
    fn rejects_missed_deadline_token_block_and_stale_execution_edges() {
        let mut not_missed = witness().expect("fixture witness");
        not_missed.runs[0].elapsed_ms = 32;
        assert!(matches!(
            rebuild(not_missed),
            Err(ColdPanicFallbackError::DeadlineNotMissed(_))
        ));

        let mut token_block = witness().expect("fixture witness");
        token_block.runs[0].token_block_ms = 17;
        assert!(matches!(
            rebuild(token_block),
            Err(ColdPanicFallbackError::TokenBlockBudgetExceeded(_))
        ));

        let mut stale = witness().expect("fixture witness");
        stale.runs[0].stale_slab_rejected = false;
        assert!(matches!(
            rebuild(stale),
            Err(ColdPanicFallbackError::StaleSlabExecutionAllowed(_))
        ));
    }

    #[test]
    fn rejects_missing_refs_visibility_and_promotions() {
        let mut missing_packet = witness().expect("fixture witness");
        missing_packet.runs[0].answer_packet_ref = "packet:missing".to_string();
        assert!(matches!(
            rebuild(missing_packet),
            Err(ColdPanicFallbackError::MissingAnswerPacket(_))
        ));

        let mut invisible = witness().expect("fixture witness");
        invisible.runs[0].visible_to_user = false;
        assert!(matches!(
            rebuild(invisible),
            Err(ColdPanicFallbackError::InvisibleFallback(_))
        ));

        let mut live = witness().expect("fixture witness");
        live.pro_status = ProStatus::Live;
        assert!(matches!(
            rebuild(live),
            Err(ColdPanicFallbackError::ProductStatusMismatch)
        ));

        let mut bytes = witness().expect("fixture witness");
        bytes.transport_runtime_bytes_loaded = 1;
        assert!(matches!(
            rebuild(bytes),
            Err(ColdPanicFallbackError::TransportRuntimeBytesLoaded)
        ));
    }

    #[test]
    fn rejects_duplicates_missing_route_diversity_and_unbeaten_baselines() {
        let mut duplicate = witness().expect("fixture witness");
        duplicate.runs[1].run_id = duplicate.runs[0].run_id.clone();
        assert!(matches!(
            rebuild(duplicate),
            Err(ColdPanicFallbackError::DuplicateRun(_))
        ));

        let mut missing_route = witness().expect("fixture witness");
        missing_route
            .runs
            .retain(|run| run.fallback_route != ColdFallbackRoute::CachedSummary);
        assert!(matches!(
            rebuild(missing_route),
            Err(ColdPanicFallbackError::MissingCachedSummaryRoute)
        ));

        let mut baseline = witness().expect("fixture witness");
        baseline.wait_forever_baseline_bps = 9_700;
        assert!(matches!(
            rebuild(baseline),
            Err(ColdPanicFallbackError::BaselineUnbeaten("wait_forever"))
        ));
    }

    fn rebuild(
        witness: ColdPanicFallbackWitness,
    ) -> Result<ColdPanicFallbackWitness, ColdPanicFallbackError> {
        ColdPanicFallbackWitness::new(
            witness.product_build,
            witness.pro_status,
            witness.route_authority,
            witness.cold_panic_success_bps,
            witness.wait_forever_baseline_bps,
            witness.hidden_caveat_baseline_bps,
            witness.stale_slab_baseline_bps,
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
