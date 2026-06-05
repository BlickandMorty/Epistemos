//! Cache-policy pollution contracts for ColdStream transport.
//!
//! This is a metadata-only witness: it proves cache policy choices are explicit,
//! visible, and bounded against repeated hot-route performance before live
//! ColdStream transport, mmap replacement, or large-model residency can promote.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const CACHE_POLICY_POLLUTION_CURSOR: &str = "cache_policy_pollution";
pub const CACHE_POLICY_POLLUTION_NEXT_CURSOR: &str = "cold_panic_fallback";

const CACHE_POLICY_PREFIX: &str = "cache_policy:";
const HOT_ROUTE_PREFIX: &str = "hot_route:";
const REPEATED_PROBE_PREFIX: &str = "repeated_probe:";
const TRANSPORT_TRACE_PREFIX: &str = "transport_trace:";
const CANCELLATION_PREFIX: &str = "transport_cancellation:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const MAX_METADATA_BYTES: u64 = 256 * 1024;
const MAX_HOT_ROUTE_REGRESSION_BPS: u32 = 250;
const MAX_CACHE_POLLUTION_BPS: u32 = 800;
const MIN_REPEATED_PROBES: u32 = 3;
const MIN_SUCCESS_BPS: u32 = 9_300;
const MIN_VISIBLE_CAVEAT_BYTES: usize = 144;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:cache-policy-pollution:lane
// Plane: Controller
// Residency: metadata-only cache-policy lane; no runtime bytes are loaded.
pub enum CachePolicyLane {
    StreamingNoCache,
    HotReuse,
    MetadataOnly,
}

impl CachePolicyLane {
    fn tag(&self) -> &'static str {
        match self {
            Self::StreamingNoCache => "streaming_no_cache",
            Self::HotReuse => "hot_reuse",
            Self::MetadataOnly => "metadata_only",
        }
    }

    pub fn required_marker(&self) -> &'static str {
        match self {
            Self::StreamingNoCache => "no-cache",
            Self::HotReuse => "hot-reuse",
            Self::MetadataOnly => "metadata-only",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:cache-policy-pollution:error
// Plane: Verification
// Residency: metadata-only rejection taxonomy.
pub enum CachePolicyPollutionError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyTrial,
    EmptySurface,
    DuplicateTrial(String),
    DuplicateSurface(String),
    DuplicateAnswerPacket(String),
    MissingCachePolicy(String),
    MissingHotRoute(String),
    MissingRepeatedProbe(String),
    MissingTransportTrace(String),
    MissingCancellation(String),
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
    MissingLayerSeparation,
    MissingStreamingNoCacheTrial,
    MissingHotReuseTrial,
    MissingMetadataOnlyTrial,
    PolicyDecisionNotExplicit(String),
    PolicyLaneMismatch(String),
    ZeroColdBytes(String),
    ZeroProbeCount(String),
    P99BelowP95(String),
    HotRouteRegressionExceeded(String),
    CachePollutionExceeded(String),
    ReadAmplificationInvalid(String),
    ReuseHorizonMissing(String),
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

impl fmt::Display for CachePolicyPollutionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyTrial => write!(f, "missing cache-policy trial"),
            Self::EmptySurface => write!(f, "missing cache-policy visible surface"),
            Self::DuplicateTrial(id) => write!(f, "duplicate cache-policy trial `{id}`"),
            Self::DuplicateSurface(id) => write!(f, "duplicate cache-policy surface `{id}`"),
            Self::DuplicateAnswerPacket(id) => write!(f, "duplicate AnswerPacket `{id}`"),
            Self::MissingCachePolicy(id) => write!(f, "trial `{id}` missing cache policy ref"),
            Self::MissingHotRoute(id) => write!(f, "trial `{id}` missing hot route ref"),
            Self::MissingRepeatedProbe(id) => {
                write!(f, "trial `{id}` missing repeated hot-route probe ref")
            }
            Self::MissingTransportTrace(id) => write!(f, "trial `{id}` missing transport trace"),
            Self::MissingCancellation(id) => {
                write!(f, "trial `{id}` missing transport cancellation ref")
            }
            Self::MissingAnswerPacket(id) => write!(f, "trial `{id}` missing AnswerPacket ref"),
            Self::MissingRunEventLog(id) => write!(f, "trial `{id}` missing RunEventLog ref"),
            Self::MissingRollback(id) => write!(f, "trial `{id}` missing rollback ref"),
            Self::MissingAdmission => write!(f, "missing admission ref"),
            Self::MissingScopeRex => write!(f, "missing SCOPE-Rex ref"),
            Self::MissingSovereignGate => write!(f, "missing SovereignGate ref"),
            Self::MissingCompatibilityFence(id) => {
                write!(f, "trial `{id}` missing compatibility fence")
            }
            Self::MissingVisibleCaveat(id) => write!(f, "trial `{id}` missing visible caveat"),
            Self::MissingRequiredMarker(marker) => write!(f, "missing marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}`"),
            Self::MissingLayerSeparation => write!(f, "L1/L2/L3 separation missing"),
            Self::MissingStreamingNoCacheTrial => write!(f, "missing streaming no-cache trial"),
            Self::MissingHotReuseTrial => write!(f, "missing hot-reuse trial"),
            Self::MissingMetadataOnlyTrial => write!(f, "missing metadata-only trial"),
            Self::PolicyDecisionNotExplicit(id) => {
                write!(f, "trial `{id}` did not record an explicit policy decision")
            }
            Self::PolicyLaneMismatch(id) => write!(f, "trial `{id}` has a mismatched policy lane"),
            Self::ZeroColdBytes(id) => write!(f, "trial `{id}` has zero cold bytes"),
            Self::ZeroProbeCount(id) => write!(f, "trial `{id}` has too few repeated probes"),
            Self::P99BelowP95(id) => write!(f, "trial `{id}` has p99 below p95"),
            Self::HotRouteRegressionExceeded(id) => {
                write!(f, "trial `{id}` exceeds hot-route regression budget")
            }
            Self::CachePollutionExceeded(id) => {
                write!(f, "trial `{id}` exceeds cache-pollution budget")
            }
            Self::ReadAmplificationInvalid(id) => {
                write!(f, "trial `{id}` has invalid read amplification")
            }
            Self::ReuseHorizonMissing(id) => write!(f, "trial `{id}` missing reuse horizon"),
            Self::ProductStatusMismatch => write!(f, "product status promoted beyond Pro Research"),
            Self::HiddenRouteAuthority => write!(f, "hidden route authority attempted"),
            Self::RoutePolicyMutation => write!(f, "route policy mutation attempted"),
            Self::GateBypass => write!(f, "cache-policy gate bypass attempted"),
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

impl std::error::Error for CachePolicyPollutionError {}

#[derive(Clone, Debug)]
// UAS: uas:cache-policy-pollution:trial
// Plane: Controller + Verification
// Residency: metadata-only hot-route cache-pollution trial.
pub struct CachePolicyTrial {
    pub trial_id: String,
    pub mission_id: String,
    pub route_id: String,
    pub lane: CachePolicyLane,
    pub cache_policy_ref: String,
    pub hot_route_ref: String,
    pub repeated_probe_ref: String,
    pub transport_trace_ref: String,
    pub cancellation_ref: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub rollback_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence: String,
    pub cold_bytes: u64,
    pub hot_route_p95_before_ms: u32,
    pub hot_route_p95_after_ms: u32,
    pub hot_route_p99_before_ms: u32,
    pub hot_route_p99_after_ms: u32,
    pub max_allowed_regression_bps: u32,
    pub observed_regression_bps: u32,
    pub cache_pollution_bps: u32,
    pub cache_pollution_budget_bps: u32,
    pub read_amplification_bps: u32,
    pub repeated_probe_count: u32,
    pub reuse_horizon_ms: u64,
    pub explicit_policy_decision: bool,
    pub visible_caveat: String,
    pub l1_l2_l3_separated: bool,
}

impl CachePolicyTrial {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        trial_id: impl Into<String>,
        mission_id: impl Into<String>,
        route_id: impl Into<String>,
        lane: CachePolicyLane,
        cache_policy_ref: impl Into<String>,
        hot_route_ref: impl Into<String>,
        repeated_probe_ref: impl Into<String>,
        transport_trace_ref: impl Into<String>,
        cancellation_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        admission_ref: impl Into<String>,
        scope_rex_ref: impl Into<String>,
        sovereign_gate_ref: impl Into<String>,
        compatibility_fence: impl Into<String>,
        cold_bytes: u64,
        hot_route_p95_before_ms: u32,
        hot_route_p95_after_ms: u32,
        hot_route_p99_before_ms: u32,
        hot_route_p99_after_ms: u32,
        max_allowed_regression_bps: u32,
        observed_regression_bps: u32,
        cache_pollution_bps: u32,
        cache_pollution_budget_bps: u32,
        read_amplification_bps: u32,
        repeated_probe_count: u32,
        reuse_horizon_ms: u64,
        explicit_policy_decision: bool,
        visible_caveat: impl Into<String>,
        l1_l2_l3_separated: bool,
    ) -> Result<Self, CachePolicyPollutionError> {
        let trial = Self {
            trial_id: trial_id.into(),
            mission_id: mission_id.into(),
            route_id: route_id.into(),
            lane,
            cache_policy_ref: cache_policy_ref.into(),
            hot_route_ref: hot_route_ref.into(),
            repeated_probe_ref: repeated_probe_ref.into(),
            transport_trace_ref: transport_trace_ref.into(),
            cancellation_ref: cancellation_ref.into(),
            answer_packet_ref: answer_packet_ref.into(),
            run_event_log_ref: run_event_log_ref.into(),
            rollback_ref: rollback_ref.into(),
            admission_ref: admission_ref.into(),
            scope_rex_ref: scope_rex_ref.into(),
            sovereign_gate_ref: sovereign_gate_ref.into(),
            compatibility_fence: compatibility_fence.into(),
            cold_bytes,
            hot_route_p95_before_ms,
            hot_route_p95_after_ms,
            hot_route_p99_before_ms,
            hot_route_p99_after_ms,
            max_allowed_regression_bps,
            observed_regression_bps,
            cache_pollution_bps,
            cache_pollution_budget_bps,
            read_amplification_bps,
            repeated_probe_count,
            reuse_horizon_ms,
            explicit_policy_decision,
            visible_caveat: visible_caveat.into(),
            l1_l2_l3_separated,
        };
        validate_trial(&trial)?;
        Ok(trial)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:cache-policy-pollution:surface
// Plane: Verification
// Residency: visible metadata-only cache-policy caveat surface.
pub struct CachePolicySurface {
    pub surface_id: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub visible_summary: String,
}

impl CachePolicySurface {
    pub fn new(
        surface_id: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        visible_summary: impl Into<String>,
    ) -> Result<Self, CachePolicyPollutionError> {
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
// UAS: uas:cache-policy-pollution:metrics
// Plane: Verification
// Residency: metadata-only aggregate.
pub struct CachePolicyMetrics {
    pub trial_count: usize,
    pub surface_count: usize,
    pub answer_packet_count: usize,
    pub run_event_log_count: usize,
    pub policy_lane_count: usize,
    pub no_cache_count: usize,
    pub hot_reuse_count: usize,
    pub metadata_only_count: usize,
    pub total_cold_bytes: u64,
    pub max_hot_route_regression_bps: u32,
    pub max_cache_pollution_bps: u32,
    pub max_hot_route_p99_after_ms: u32,
    pub min_reuse_horizon_ms: u64,
    pub min_repeated_probe_count: u32,
}

#[derive(Clone, Debug)]
// UAS: uas:cache-policy-pollution:witness
// Plane: Verification
// Residency: metadata-only; live transport/model/runtime bytes must stay zero.
pub struct CachePolicyPollutionWitness {
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub cache_policy_success_bps: u32,
    pub no_explicit_policy_baseline_bps: u32,
    pub always_cache_baseline_bps: u32,
    pub hidden_policy_baseline_bps: u32,
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
    pub trials: Vec<CachePolicyTrial>,
    pub surfaces: Vec<CachePolicySurface>,
}

impl CachePolicyPollutionWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        cache_policy_success_bps: u32,
        no_explicit_policy_baseline_bps: u32,
        always_cache_baseline_bps: u32,
        hidden_policy_baseline_bps: u32,
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
        trials: Vec<CachePolicyTrial>,
        surfaces: Vec<CachePolicySurface>,
    ) -> Result<Self, CachePolicyPollutionError> {
        let witness = Self {
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            cache_policy_success_bps,
            no_explicit_policy_baseline_bps,
            always_cache_baseline_bps,
            hidden_policy_baseline_bps,
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
            trials,
            surfaces,
        };
        validate_witness(&witness)?;
        Ok(witness)
    }

    pub fn metrics(&self) -> CachePolicyMetrics {
        let mut answer_packets = BTreeSet::new();
        let mut run_event_logs = BTreeSet::new();
        let mut lanes = BTreeSet::new();
        let mut metrics = CachePolicyMetrics {
            trial_count: self.trials.len(),
            surface_count: self.surfaces.len(),
            min_reuse_horizon_ms: u64::MAX,
            min_repeated_probe_count: u32::MAX,
            ..CachePolicyMetrics::default()
        };
        for trial in &self.trials {
            answer_packets.insert(trial.answer_packet_ref.clone());
            run_event_logs.insert(trial.run_event_log_ref.clone());
            lanes.insert(trial.lane.clone());
            metrics.total_cold_bytes = metrics.total_cold_bytes.saturating_add(trial.cold_bytes);
            metrics.max_hot_route_regression_bps = metrics
                .max_hot_route_regression_bps
                .max(trial.observed_regression_bps);
            metrics.max_cache_pollution_bps = metrics
                .max_cache_pollution_bps
                .max(trial.cache_pollution_bps);
            metrics.max_hot_route_p99_after_ms = metrics
                .max_hot_route_p99_after_ms
                .max(trial.hot_route_p99_after_ms);
            metrics.min_reuse_horizon_ms = metrics.min_reuse_horizon_ms.min(trial.reuse_horizon_ms);
            metrics.min_repeated_probe_count = metrics
                .min_repeated_probe_count
                .min(trial.repeated_probe_count);
            match trial.lane {
                CachePolicyLane::StreamingNoCache => metrics.no_cache_count += 1,
                CachePolicyLane::HotReuse => metrics.hot_reuse_count += 1,
                CachePolicyLane::MetadataOnly => metrics.metadata_only_count += 1,
            }
        }
        for surface in &self.surfaces {
            answer_packets.insert(surface.answer_packet_ref.clone());
            run_event_logs.insert(surface.run_event_log_ref.clone());
        }
        metrics.answer_packet_count = answer_packets.len();
        metrics.run_event_log_count = run_event_logs.len();
        metrics.policy_lane_count = lanes.len();
        if self.trials.is_empty() {
            metrics.min_reuse_horizon_ms = 0;
            metrics.min_repeated_probe_count = 0;
        }
        metrics
    }

    pub fn address(&self) -> String {
        let mut trial_parts = self
            .trials
            .iter()
            .map(|trial| {
                format!(
                    "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
                    trial.trial_id,
                    trial.mission_id,
                    trial.route_id,
                    trial.lane.tag(),
                    trial.cache_policy_ref,
                    trial.hot_route_ref,
                    trial.repeated_probe_ref,
                    trial.transport_trace_ref,
                    trial.cancellation_ref,
                    trial.answer_packet_ref,
                    trial.run_event_log_ref,
                    trial.rollback_ref,
                    trial.admission_ref,
                    trial.compatibility_fence,
                    trial.cold_bytes,
                    trial.hot_route_p95_after_ms,
                    trial.hot_route_p99_after_ms,
                    trial.observed_regression_bps,
                    trial.cache_pollution_bps,
                    trial.read_amplification_bps,
                    trial.repeated_probe_count,
                    trial.reuse_horizon_ms
                )
            })
            .collect::<Vec<_>>();
        trial_parts.sort();
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
                "{}|{}|{}|{}|{}|{}|{}|{}|{}",
                product_build,
                pro_status,
                self.route_authority,
                self.cache_policy_success_bps,
                self.no_explicit_policy_baseline_bps,
                self.always_cache_baseline_bps,
                self.hidden_policy_baseline_bps,
                trial_parts.join(";;"),
                surface_parts.join(";;")
            )
            .as_bytes(),
        );
        format!("uas:cache-policy-pollution:{digest}")
    }
}

fn validate_witness(
    witness: &CachePolicyPollutionWitness,
) -> Result<(), CachePolicyPollutionError> {
    if witness.product_build != ProductBuild::Pro
        || witness.pro_status != ProStatus::ResearchCandidate
        || witness.route_authority != "cache_policy_pollution_gate_only"
    {
        return Err(CachePolicyPollutionError::ProductStatusMismatch);
    }
    if witness.trials.is_empty() {
        return Err(CachePolicyPollutionError::EmptyTrial);
    }
    if witness.surfaces.is_empty() {
        return Err(CachePolicyPollutionError::EmptySurface);
    }

    let mut trial_ids = HashSet::with_capacity(witness.trials.len());
    let mut surface_ids = HashSet::with_capacity(witness.surfaces.len());
    let mut answer_packets = HashSet::with_capacity(witness.trials.len() + witness.surfaces.len());
    let mut has_no_cache = false;
    let mut has_hot_reuse = false;
    let mut has_metadata_only = false;
    for trial in &witness.trials {
        validate_trial(trial)?;
        if !trial_ids.insert(trial.trial_id.clone()) {
            return Err(CachePolicyPollutionError::DuplicateTrial(
                trial.trial_id.clone(),
            ));
        }
        if !answer_packets.insert(trial.answer_packet_ref.clone()) {
            return Err(CachePolicyPollutionError::DuplicateAnswerPacket(
                trial.answer_packet_ref.clone(),
            ));
        }
        if !trial.l1_l2_l3_separated || !contains_layer_separation(&trial.visible_caveat) {
            return Err(CachePolicyPollutionError::MissingLayerSeparation);
        }
        match trial.lane {
            CachePolicyLane::StreamingNoCache => has_no_cache = true,
            CachePolicyLane::HotReuse => has_hot_reuse = true,
            CachePolicyLane::MetadataOnly => has_metadata_only = true,
        }
    }
    for surface in &witness.surfaces {
        validate_surface(surface)?;
        if !surface_ids.insert(surface.surface_id.clone()) {
            return Err(CachePolicyPollutionError::DuplicateSurface(
                surface.surface_id.clone(),
            ));
        }
        if !contains_layer_separation(&surface.visible_summary) {
            return Err(CachePolicyPollutionError::MissingLayerSeparation);
        }
    }
    if !has_no_cache {
        return Err(CachePolicyPollutionError::MissingStreamingNoCacheTrial);
    }
    if !has_hot_reuse {
        return Err(CachePolicyPollutionError::MissingHotReuseTrial);
    }
    if !has_metadata_only {
        return Err(CachePolicyPollutionError::MissingMetadataOnlyTrial);
    }
    if witness.hidden_route_authority {
        return Err(CachePolicyPollutionError::HiddenRouteAuthority);
    }
    if witness.route_policy_mutation {
        return Err(CachePolicyPollutionError::RoutePolicyMutation);
    }
    if witness.gate_bypass {
        return Err(CachePolicyPollutionError::GateBypass);
    }
    if witness.answer_packet_suppression {
        return Err(CachePolicyPollutionError::AnswerPacketSuppression);
    }
    if witness.hidden_chain_exposed {
        return Err(CachePolicyPollutionError::HiddenChainExposure);
    }
    if witness.hidden_cloud_route {
        return Err(CachePolicyPollutionError::HiddenCloudRoute);
    }
    if witness.ssd_as_ram_claim {
        return Err(CachePolicyPollutionError::SsdAsRamClaim);
    }
    if witness.mas_promotion_attempted {
        return Err(CachePolicyPollutionError::MasPromotionAttempted);
    }
    if witness.live_benchmark_attempted {
        return Err(CachePolicyPollutionError::LiveBenchmarkAttempted);
    }
    if witness.runtime_bytes_loaded != 0 {
        return Err(CachePolicyPollutionError::RuntimeBytesLoaded);
    }
    if witness.model_bytes_loaded != 0 {
        return Err(CachePolicyPollutionError::ModelBytesLoaded);
    }
    if witness.transport_runtime_bytes_loaded != 0 {
        return Err(CachePolicyPollutionError::TransportRuntimeBytesLoaded);
    }
    if witness.max_metadata_bytes > MAX_METADATA_BYTES {
        return Err(CachePolicyPollutionError::MetadataBudgetExceeded);
    }
    if witness.cache_policy_success_bps < MIN_SUCCESS_BPS {
        return Err(CachePolicyPollutionError::BaselineUnbeaten(
            "cache_policy_success",
        ));
    }
    for (name, baseline) in [
        (
            "no_explicit_policy",
            witness.no_explicit_policy_baseline_bps,
        ),
        ("always_cache", witness.always_cache_baseline_bps),
        ("hidden_policy", witness.hidden_policy_baseline_bps),
        ("live_authority", witness.live_authority_baseline_bps),
    ] {
        if witness.cache_policy_success_bps <= baseline {
            return Err(CachePolicyPollutionError::BaselineUnbeaten(name));
        }
    }
    Ok(())
}

fn validate_trial(trial: &CachePolicyTrial) -> Result<(), CachePolicyPollutionError> {
    validate_nonempty_clean("trial_id", &trial.trial_id)?;
    validate_nonempty_clean("mission_id", &trial.mission_id)?;
    validate_nonempty_clean("route_id", &trial.route_id)?;
    validate_nonempty_clean("visible_caveat", &trial.visible_caveat)?;
    validate_prefixed(
        "cache_policy_ref",
        &trial.cache_policy_ref,
        CACHE_POLICY_PREFIX,
        CachePolicyPollutionError::MissingCachePolicy(trial.trial_id.clone()),
    )?;
    validate_prefixed(
        "hot_route_ref",
        &trial.hot_route_ref,
        HOT_ROUTE_PREFIX,
        CachePolicyPollutionError::MissingHotRoute(trial.trial_id.clone()),
    )?;
    validate_prefixed(
        "repeated_probe_ref",
        &trial.repeated_probe_ref,
        REPEATED_PROBE_PREFIX,
        CachePolicyPollutionError::MissingRepeatedProbe(trial.trial_id.clone()),
    )?;
    validate_prefixed(
        "transport_trace_ref",
        &trial.transport_trace_ref,
        TRANSPORT_TRACE_PREFIX,
        CachePolicyPollutionError::MissingTransportTrace(trial.trial_id.clone()),
    )?;
    validate_prefixed(
        "cancellation_ref",
        &trial.cancellation_ref,
        CANCELLATION_PREFIX,
        CachePolicyPollutionError::MissingCancellation(trial.trial_id.clone()),
    )?;
    validate_prefixed(
        "answer_packet_ref",
        &trial.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
        CachePolicyPollutionError::MissingAnswerPacket(trial.trial_id.clone()),
    )?;
    validate_prefixed(
        "run_event_log_ref",
        &trial.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
        CachePolicyPollutionError::MissingRunEventLog(trial.trial_id.clone()),
    )?;
    validate_prefixed(
        "rollback_ref",
        &trial.rollback_ref,
        ROLLBACK_PREFIX,
        CachePolicyPollutionError::MissingRollback(trial.trial_id.clone()),
    )?;
    validate_prefixed(
        "admission_ref",
        &trial.admission_ref,
        ADMISSION_PREFIX,
        CachePolicyPollutionError::MissingAdmission,
    )?;
    validate_prefixed(
        "scope_rex_ref",
        &trial.scope_rex_ref,
        SCOPE_REX_PREFIX,
        CachePolicyPollutionError::MissingScopeRex,
    )?;
    validate_prefixed(
        "sovereign_gate_ref",
        &trial.sovereign_gate_ref,
        SOVEREIGN_GATE_PREFIX,
        CachePolicyPollutionError::MissingSovereignGate,
    )?;
    validate_prefixed(
        "compatibility_fence",
        &trial.compatibility_fence,
        COMPATIBILITY_FENCE_PREFIX,
        CachePolicyPollutionError::MissingCompatibilityFence(trial.trial_id.clone()),
    )?;
    if !trial.explicit_policy_decision {
        return Err(CachePolicyPollutionError::PolicyDecisionNotExplicit(
            trial.trial_id.clone(),
        ));
    }
    if !trial
        .cache_policy_ref
        .contains(trial.lane.required_marker())
    {
        return Err(CachePolicyPollutionError::PolicyLaneMismatch(
            trial.trial_id.clone(),
        ));
    }
    if trial.cold_bytes == 0 {
        return Err(CachePolicyPollutionError::ZeroColdBytes(
            trial.trial_id.clone(),
        ));
    }
    if trial.repeated_probe_count < MIN_REPEATED_PROBES {
        return Err(CachePolicyPollutionError::ZeroProbeCount(
            trial.trial_id.clone(),
        ));
    }
    if trial.hot_route_p99_before_ms < trial.hot_route_p95_before_ms
        || trial.hot_route_p99_after_ms < trial.hot_route_p95_after_ms
    {
        return Err(CachePolicyPollutionError::P99BelowP95(
            trial.trial_id.clone(),
        ));
    }
    if trial.max_allowed_regression_bps > MAX_HOT_ROUTE_REGRESSION_BPS
        || trial.observed_regression_bps > trial.max_allowed_regression_bps
    {
        return Err(CachePolicyPollutionError::HotRouteRegressionExceeded(
            trial.trial_id.clone(),
        ));
    }
    if trial.cache_pollution_budget_bps > MAX_CACHE_POLLUTION_BPS
        || trial.cache_pollution_bps > trial.cache_pollution_budget_bps
    {
        return Err(CachePolicyPollutionError::CachePollutionExceeded(
            trial.trial_id.clone(),
        ));
    }
    if trial.read_amplification_bps == 0 || trial.read_amplification_bps > 20_000 {
        return Err(CachePolicyPollutionError::ReadAmplificationInvalid(
            trial.trial_id.clone(),
        ));
    }
    if trial.reuse_horizon_ms == 0 {
        return Err(CachePolicyPollutionError::ReuseHorizonMissing(
            trial.trial_id.clone(),
        ));
    }
    for marker in [
        "metadata-only",
        "cache policy",
        "hot route",
        "repeated probe",
        "AnswerPacket",
        "L1",
        "L2",
        "L3",
    ] {
        if !trial.visible_caveat.contains(marker) {
            return Err(CachePolicyPollutionError::MissingRequiredMarker(
                marker.to_string(),
            ));
        }
    }
    for marker in [
        "hidden authority",
        "live transport ready",
        "SSD = RAM",
        "cloud fallback",
    ] {
        if trial.visible_caveat.contains(marker) {
            return Err(CachePolicyPollutionError::ForbiddenMarker(
                marker.to_string(),
            ));
        }
    }
    Ok(())
}

fn validate_surface(surface: &CachePolicySurface) -> Result<(), CachePolicyPollutionError> {
    validate_nonempty_clean("surface_id", &surface.surface_id)?;
    validate_nonempty_clean("visible_summary", &surface.visible_summary)?;
    validate_prefixed(
        "answer_packet_ref",
        &surface.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
        CachePolicyPollutionError::MissingAnswerPacket(surface.surface_id.clone()),
    )?;
    validate_prefixed(
        "run_event_log_ref",
        &surface.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
        CachePolicyPollutionError::MissingRunEventLog(surface.surface_id.clone()),
    )?;
    if surface.visible_summary.len() < MIN_VISIBLE_CAVEAT_BYTES {
        return Err(CachePolicyPollutionError::MissingVisibleCaveat(
            surface.surface_id.clone(),
        ));
    }
    for marker in [
        "metadata-only",
        "cache policy",
        "hot route",
        "repeated probe",
        "AnswerPacket",
        "rollback",
        "L1",
        "L2",
        "L3",
    ] {
        if !surface.visible_summary.contains(marker) {
            return Err(CachePolicyPollutionError::MissingRequiredMarker(
                marker.to_string(),
            ));
        }
    }
    for marker in [
        "hidden authority",
        "live transport ready",
        "SSD = RAM",
        "cloud fallback",
    ] {
        if surface.visible_summary.contains(marker) {
            return Err(CachePolicyPollutionError::ForbiddenMarker(
                marker.to_string(),
            ));
        }
    }
    Ok(())
}

fn validate_nonempty_clean(
    field: &'static str,
    value: &str,
) -> Result<(), CachePolicyPollutionError> {
    if value.is_empty() {
        return Err(CachePolicyPollutionError::MissingField(field));
    }
    if value.trim() != value {
        return Err(CachePolicyPollutionError::FieldHasSurroundingWhitespace(
            field,
        ));
    }
    if value.chars().any(char::is_control) {
        return Err(CachePolicyPollutionError::FieldContainsControlCharacter(
            field,
        ));
    }
    Ok(())
}

fn validate_prefixed(
    field: &'static str,
    value: &str,
    prefix: &str,
    missing: CachePolicyPollutionError,
) -> Result<(), CachePolicyPollutionError> {
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

    fn caveat(lane: &str) -> String {
        format!(
            "metadata-only cache policy witness for {lane}: repeated probe evidence bounds hot route p95/p99 regression, AnswerPacket and rollback are visible, and this advances L1 only while L2 and L3 stay unchanged."
        )
    }

    fn trial(
        id: &str,
        lane: CachePolicyLane,
    ) -> Result<CachePolicyTrial, CachePolicyPollutionError> {
        let marker = lane.required_marker();
        CachePolicyTrial::new(
            id,
            "mission:coldstream-cache-policy",
            format!("route:{id}"),
            lane,
            format!("cache_policy:{marker}:{id}"),
            format!("hot_route:{id}:note-loop"),
            format!("repeated_probe:{id}:5x"),
            format!("transport_trace:{id}"),
            format!("transport_cancellation:{id}"),
            format!("answer_packet:{id}"),
            format!("run_event_log:{id}"),
            format!("rollback:{id}"),
            "admission:cache-policy-pollution",
            "scope_rex:cache-policy-pollution",
            "sovereign_gate:cache-policy-pollution",
            "compat:cache-policy-v1",
            65_536,
            9,
            9,
            15,
            16,
            200,
            120,
            430,
            700,
            10_500,
            5,
            30_000,
            true,
            caveat(marker),
            true,
        )
    }

    fn surface(id: &str) -> Result<CachePolicySurface, CachePolicyPollutionError> {
        CachePolicySurface::new(
            id,
            format!("answer_packet:surface:{id}"),
            format!("run_event_log:surface:{id}"),
            "metadata-only cache policy surface: L1 records hot route repeated probe results, cache policy caveats, AnswerPacket, RunEventLog, and rollback; L2 remains vault research and L3 product runtime is unchanged.",
        )
    }

    fn witness() -> Result<CachePolicyPollutionWitness, CachePolicyPollutionError> {
        CachePolicyPollutionWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "cache_policy_pollution_gate_only",
            9_520,
            8_250,
            8_120,
            8_340,
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
                trial("no-cache", CachePolicyLane::StreamingNoCache)?,
                trial("hot-reuse", CachePolicyLane::HotReuse)?,
                trial("metadata-only", CachePolicyLane::MetadataOnly)?,
            ],
            vec![surface("surface-a")?, surface("surface-b")?],
        )
    }

    #[test]
    fn valid_witness_bounds_cache_pollution() {
        let witness = witness().expect("fixture witness");
        let metrics = witness.metrics();
        assert_eq!(metrics.trial_count, 3);
        assert_eq!(metrics.no_cache_count, 1);
        assert_eq!(metrics.hot_reuse_count, 1);
        assert_eq!(metrics.metadata_only_count, 1);
        assert_eq!(metrics.max_hot_route_regression_bps, 120);
        assert_eq!(metrics.max_cache_pollution_bps, 430);
        assert!(witness
            .address()
            .starts_with("uas:cache-policy-pollution:sha256:"));
    }

    #[test]
    fn deterministic_address_ignores_trial_order() {
        let witness = witness().expect("fixture witness");
        let mut reversed_trials = witness.trials.clone();
        reversed_trials.reverse();
        let reversed = CachePolicyPollutionWitness::new(
            witness.product_build.clone(),
            witness.pro_status.clone(),
            witness.route_authority.clone(),
            witness.cache_policy_success_bps,
            witness.no_explicit_policy_baseline_bps,
            witness.always_cache_baseline_bps,
            witness.hidden_policy_baseline_bps,
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
            reversed_trials,
            witness.surfaces.clone(),
        )
        .expect("reversed witness");
        assert_eq!(witness.address(), reversed.address());
    }

    #[test]
    fn rejects_hot_route_regression_and_cache_pollution_over_budget() {
        let mut regression = witness().expect("fixture witness");
        regression.trials[0].observed_regression_bps = 300;
        assert!(matches!(
            rebuild(regression),
            Err(CachePolicyPollutionError::HotRouteRegressionExceeded(_))
        ));

        let mut pollution = witness().expect("fixture witness");
        pollution.trials[0].cache_pollution_bps = 900;
        assert!(matches!(
            rebuild(pollution),
            Err(CachePolicyPollutionError::CachePollutionExceeded(_))
        ));
    }

    #[test]
    fn rejects_missing_lane_and_policy_mismatch() {
        let mut missing = witness().expect("fixture witness");
        missing
            .trials
            .retain(|trial| trial.lane != CachePolicyLane::StreamingNoCache);
        assert!(matches!(
            rebuild(missing),
            Err(CachePolicyPollutionError::MissingStreamingNoCacheTrial)
        ));

        let mut mismatch = witness().expect("fixture witness");
        mismatch.trials[0].cache_policy_ref = "cache_policy:hot-reuse:mismatch".to_string();
        assert!(matches!(
            rebuild(mismatch),
            Err(CachePolicyPollutionError::PolicyLaneMismatch(_))
        ));
    }

    #[test]
    fn rejects_duplicate_trial_and_packet() {
        let mut duplicate_trial = witness().expect("fixture witness");
        duplicate_trial
            .trials
            .push(duplicate_trial.trials[0].clone());
        assert!(matches!(
            rebuild(duplicate_trial),
            Err(CachePolicyPollutionError::DuplicateTrial(_))
        ));

        let mut duplicate_packet = witness().expect("fixture witness");
        duplicate_packet.trials[1].answer_packet_ref =
            duplicate_packet.trials[0].answer_packet_ref.clone();
        assert!(matches!(
            rebuild(duplicate_packet),
            Err(CachePolicyPollutionError::DuplicateAnswerPacket(_))
        ));
    }

    #[test]
    fn rejects_missing_probe_and_invalid_p99() {
        let mut missing_probe = witness().expect("fixture witness");
        missing_probe.trials[0].repeated_probe_count = 0;
        assert!(matches!(
            rebuild(missing_probe),
            Err(CachePolicyPollutionError::ZeroProbeCount(_))
        ));

        let mut bad_p99 = witness().expect("fixture witness");
        bad_p99.trials[0].hot_route_p99_after_ms = 8;
        assert!(matches!(
            rebuild(bad_p99),
            Err(CachePolicyPollutionError::P99BelowP95(_))
        ));
    }

    #[test]
    fn rejects_product_and_runtime_promotions() {
        let mut live = witness().expect("fixture witness");
        live.pro_status = ProStatus::Live;
        assert!(matches!(
            rebuild(live),
            Err(CachePolicyPollutionError::ProductStatusMismatch)
        ));

        let mut runtime = witness().expect("fixture witness");
        runtime.transport_runtime_bytes_loaded = 1;
        assert!(matches!(
            rebuild(runtime),
            Err(CachePolicyPollutionError::TransportRuntimeBytesLoaded)
        ));
    }

    #[test]
    fn rejects_hidden_authority_and_unbeaten_baseline() {
        let mut hidden = witness().expect("fixture witness");
        hidden.hidden_route_authority = true;
        assert!(matches!(
            rebuild(hidden),
            Err(CachePolicyPollutionError::HiddenRouteAuthority)
        ));

        let mut baseline = witness().expect("fixture witness");
        baseline.always_cache_baseline_bps = baseline.cache_policy_success_bps;
        assert!(matches!(
            rebuild(baseline),
            Err(CachePolicyPollutionError::BaselineUnbeaten("always_cache"))
        ));
    }

    fn rebuild(
        witness: CachePolicyPollutionWitness,
    ) -> Result<CachePolicyPollutionWitness, CachePolicyPollutionError> {
        CachePolicyPollutionWitness::new(
            witness.product_build,
            witness.pro_status,
            witness.route_authority,
            witness.cache_policy_success_bps,
            witness.no_explicit_policy_baseline_bps,
            witness.always_cache_baseline_bps,
            witness.hidden_policy_baseline_bps,
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
            witness.trials,
            witness.surfaces,
        )
    }
}
