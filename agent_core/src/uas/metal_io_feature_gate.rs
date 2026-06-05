//! Metal I/O feature-gate contracts.
//!
//! This is a metadata-only witness for the ColdStream Metal lane. It proves that
//! GPU resource-loading plans are admitted only after an explicit platform
//! feature decision, and that unsupported or unknown support falls back to CPU
//! slabs with visible AnswerPacket caveats before any live transport promotes.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const METAL_IO_FEATURE_GATE_CURSOR: &str = "metal_io_feature_gate";
pub const METAL_IO_FEATURE_GATE_NEXT_CURSOR: &str = "codec_stage_latency";

const DEVICE_PREFIX: &str = "metal_device:";
const GPU_FAMILY_PREFIX: &str = "gpu_family:";
const FEATURE_QUERY_PREFIX: &str = "feature_query:";
const METAL_BUFFER_LEASE_PREFIX: &str = "metal_buffer_lease:";
const CPU_SLAB_PREFIX: &str = "cpu_slab:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const CANCEL_GROUP_PREFIX: &str = "cancel_group:";
const MAX_METADATA_BYTES: u64 = 256 * 1024;
const MIN_VISIBLE_CAVEAT_BYTES: usize = 128;
const MIN_FEATURE_GATE_SUCCESS_BPS: u32 = 9_500;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:metal-io-feature-gate:lane
// Plane: Controller
// Residency: metadata-only lane decision; no Metal bytes are loaded.
pub enum MetalIoLane {
    MetalResourceLoading,
    CpuSlabFallback,
}

impl MetalIoLane {
    fn tag(&self) -> &'static str {
        match self {
            Self::MetalResourceLoading => "metal_resource_loading",
            Self::CpuSlabFallback => "cpu_slab_fallback",
        }
    }
}

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:metal-io-feature-gate:feature-status
// Plane: Verification
// Residency: metadata-only platform support state.
pub enum MetalFeatureStatus {
    Supported,
    Unsupported,
    Unknown,
}

impl MetalFeatureStatus {
    fn tag(&self) -> &'static str {
        match self {
            Self::Supported => "supported",
            Self::Unsupported => "unsupported",
            Self::Unknown => "unknown",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:metal-io-feature-gate:error
// Plane: Verification
// Residency: metadata-only rejection taxonomy.
pub enum MetalIoFeatureGateError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyDecision,
    EmptySurface,
    DuplicateDecision(String),
    DuplicateSurface(String),
    DuplicateAnswerPacket(String),
    MissingDeviceRef(String),
    MissingGpuFamilyRef(String),
    MissingFeatureQueryRef(String),
    MissingRequestedFeature(String),
    MissingMetalBufferLease(String),
    UnexpectedMetalBufferLease(String),
    MissingCpuSlabFallback(String),
    MissingAnswerPacket(String),
    MissingRunEventLog(String),
    MissingRollback(String),
    MissingAdmission,
    MissingScopeRex,
    MissingSovereignGate,
    MissingCompatibilityFence(String),
    MissingCancelGroup(String),
    MissingVisibleCaveat(String),
    MissingRequiredMarker(String),
    ForbiddenMarker(String),
    UnsupportedFeatureSelectedMetal(String),
    SupportedFeatureSelectedFallback(String),
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
    MetalRuntimeBytesLoaded,
    MetadataBudgetExceeded,
    BaselineUnbeaten(&'static str),
}

impl fmt::Display for MetalIoFeatureGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyDecision => write!(f, "missing Metal I/O feature decision"),
            Self::EmptySurface => write!(f, "missing visible surface"),
            Self::DuplicateDecision(id) => write!(f, "duplicate feature decision `{id}`"),
            Self::DuplicateSurface(id) => write!(f, "duplicate surface `{id}`"),
            Self::DuplicateAnswerPacket(id) => write!(f, "duplicate AnswerPacket `{id}`"),
            Self::MissingDeviceRef(id) => write!(f, "`{id}` missing Metal device ref"),
            Self::MissingGpuFamilyRef(id) => write!(f, "`{id}` missing GPU family ref"),
            Self::MissingFeatureQueryRef(id) => write!(f, "`{id}` missing feature query ref"),
            Self::MissingRequestedFeature(id) => write!(f, "`{id}` missing requested feature"),
            Self::MissingMetalBufferLease(id) => {
                write!(f, "`{id}` selected Metal without a MetalBufferLease")
            }
            Self::UnexpectedMetalBufferLease(id) => {
                write!(f, "`{id}` fallback path included a MetalBufferLease")
            }
            Self::MissingCpuSlabFallback(id) => write!(f, "`{id}` missing CPU slab fallback"),
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
            Self::MissingVisibleCaveat(id) => write!(f, "`{id}` missing visible caveat"),
            Self::MissingRequiredMarker(marker) => write!(f, "missing marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}`"),
            Self::UnsupportedFeatureSelectedMetal(id) => {
                write!(f, "`{id}` selected Metal for an unsupported or unknown feature")
            }
            Self::SupportedFeatureSelectedFallback(id) => {
                write!(f, "`{id}` selected fallback despite supported Metal feature")
            }
            Self::MissingLayerSeparation => write!(f, "L1/L2/L3 separation missing"),
            Self::ProductStatusMismatch => write!(f, "product status promoted beyond Pro Research"),
            Self::HiddenRouteAuthority => write!(f, "hidden route authority attempted"),
            Self::RoutePolicyMutation => write!(f, "route policy mutation attempted"),
            Self::GateBypass => write!(f, "Metal feature gate bypass attempted"),
            Self::AnswerPacketSuppression => write!(f, "AnswerPacket suppression attempted"),
            Self::HiddenChainExposure => write!(f, "hidden chain exposure attempted"),
            Self::HiddenCloudRoute => write!(f, "hidden cloud route attempted"),
            Self::SsdAsRamClaim => write!(f, "SSD-as-RAM claim attempted"),
            Self::MasPromotionAttempted => write!(f, "MAS/Live promotion attempted"),
            Self::LiveBenchmarkAttempted => write!(f, "metadata witness attempted live benchmark"),
            Self::RuntimeBytesLoaded => write!(f, "metadata witness loaded runtime bytes"),
            Self::ModelBytesLoaded => write!(f, "metadata witness loaded model bytes"),
            Self::MetalRuntimeBytesLoaded => write!(f, "metadata witness loaded Metal runtime bytes"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
            Self::BaselineUnbeaten(name) => write!(f, "baseline `{name}` was unbeaten"),
        }
    }
}

impl std::error::Error for MetalIoFeatureGateError {}

#[derive(Clone, Debug)]
// UAS: uas:metal-io-feature-gate:decision
// Plane: Controller
// Residency: metadata-only feature-gated Metal-vs-CPU fallback decision.
pub struct MetalIoFeatureDecision {
    pub decision_id: String,
    pub mission_id: String,
    pub device_ref: String,
    pub gpu_family_ref: String,
    pub feature_query_ref: String,
    pub requested_feature: String,
    pub feature_status: MetalFeatureStatus,
    pub selected_lane: MetalIoLane,
    pub metal_buffer_lease_ref: Option<String>,
    pub fallback_cpu_slab_ref: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub rollback_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence: String,
    pub cancel_group_ref: String,
    pub visible_caveat: String,
}

impl MetalIoFeatureDecision {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        decision_id: impl Into<String>,
        mission_id: impl Into<String>,
        device_ref: impl Into<String>,
        gpu_family_ref: impl Into<String>,
        feature_query_ref: impl Into<String>,
        requested_feature: impl Into<String>,
        feature_status: MetalFeatureStatus,
        selected_lane: MetalIoLane,
        metal_buffer_lease_ref: Option<String>,
        fallback_cpu_slab_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        admission_ref: impl Into<String>,
        scope_rex_ref: impl Into<String>,
        sovereign_gate_ref: impl Into<String>,
        compatibility_fence: impl Into<String>,
        cancel_group_ref: impl Into<String>,
        visible_caveat: impl Into<String>,
    ) -> Result<Self, MetalIoFeatureGateError> {
        let decision = Self {
            decision_id: decision_id.into(),
            mission_id: mission_id.into(),
            device_ref: device_ref.into(),
            gpu_family_ref: gpu_family_ref.into(),
            feature_query_ref: feature_query_ref.into(),
            requested_feature: requested_feature.into(),
            feature_status,
            selected_lane,
            metal_buffer_lease_ref,
            fallback_cpu_slab_ref: fallback_cpu_slab_ref.into(),
            answer_packet_ref: answer_packet_ref.into(),
            run_event_log_ref: run_event_log_ref.into(),
            rollback_ref: rollback_ref.into(),
            admission_ref: admission_ref.into(),
            scope_rex_ref: scope_rex_ref.into(),
            sovereign_gate_ref: sovereign_gate_ref.into(),
            compatibility_fence: compatibility_fence.into(),
            cancel_group_ref: cancel_group_ref.into(),
            visible_caveat: visible_caveat.into(),
        };
        validate_decision(&decision)?;
        Ok(decision)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:metal-io-feature-gate:surface
// Plane: Verification
// Residency: visible metadata-only AnswerPacket surface.
pub struct MetalIoFeatureSurface {
    pub surface_id: String,
    pub answer_packet_ref: String,
    pub body: String,
}

impl MetalIoFeatureSurface {
    pub fn new(
        surface_id: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        body: impl Into<String>,
    ) -> Result<Self, MetalIoFeatureGateError> {
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
// UAS: uas:metal-io-feature-gate:metrics
// Plane: Verification
// Residency: derived metadata-only metrics.
pub struct MetalIoFeatureGateMetrics {
    pub decision_count: u64,
    pub supported_feature_count: u64,
    pub unsupported_feature_count: u64,
    pub unknown_feature_count: u64,
    pub metal_lane_count: u64,
    pub cpu_fallback_count: u64,
    pub surface_count: u64,
    pub answer_packet_count: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub metal_runtime_bytes_loaded: u64,
    pub max_metadata_bytes: u64,
    pub feature_gate_success_bps: u32,
    pub ungated_metal_baseline_bps: u32,
    pub no_fallback_baseline_bps: u32,
    pub hidden_metal_baseline_bps: u32,
    pub address: String,
}

#[derive(Clone, Debug)]
// UAS: uas:metal-io-feature-gate:witness
// Plane: Verification
// Residency: metadata-only witness; no live Metal transport or model bytes.
pub struct MetalIoFeatureGateWitness {
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub feature_gate_success_bps: u32,
    pub ungated_metal_baseline_bps: u32,
    pub no_fallback_baseline_bps: u32,
    pub hidden_metal_baseline_bps: u32,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub metal_runtime_bytes_loaded: u64,
    pub max_metadata_bytes: u64,
    pub hidden_route_authority_attempted: bool,
    pub route_policy_mutation_attempted: bool,
    pub gate_bypass_attempted: bool,
    pub answer_packet_suppression_attempted: bool,
    pub hidden_chain_exposure_attempted: bool,
    pub hidden_cloud_route_attempted: bool,
    pub ssd_as_ram_claim_attempted: bool,
    pub mas_promotion_attempted: bool,
    pub live_benchmark_attempted: bool,
    pub decisions: Vec<MetalIoFeatureDecision>,
    pub surfaces: Vec<MetalIoFeatureSurface>,
}

impl MetalIoFeatureGateWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        feature_gate_success_bps: u32,
        ungated_metal_baseline_bps: u32,
        no_fallback_baseline_bps: u32,
        hidden_metal_baseline_bps: u32,
        runtime_bytes_loaded: u64,
        model_bytes_loaded: u64,
        metal_runtime_bytes_loaded: u64,
        max_metadata_bytes: u64,
        hidden_route_authority_attempted: bool,
        route_policy_mutation_attempted: bool,
        gate_bypass_attempted: bool,
        answer_packet_suppression_attempted: bool,
        hidden_chain_exposure_attempted: bool,
        hidden_cloud_route_attempted: bool,
        ssd_as_ram_claim_attempted: bool,
        mas_promotion_attempted: bool,
        live_benchmark_attempted: bool,
        decisions: Vec<MetalIoFeatureDecision>,
        surfaces: Vec<MetalIoFeatureSurface>,
    ) -> Result<Self, MetalIoFeatureGateError> {
        let witness = Self {
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            feature_gate_success_bps,
            ungated_metal_baseline_bps,
            no_fallback_baseline_bps,
            hidden_metal_baseline_bps,
            runtime_bytes_loaded,
            model_bytes_loaded,
            metal_runtime_bytes_loaded,
            max_metadata_bytes,
            hidden_route_authority_attempted,
            route_policy_mutation_attempted,
            gate_bypass_attempted,
            answer_packet_suppression_attempted,
            hidden_chain_exposure_attempted,
            hidden_cloud_route_attempted,
            ssd_as_ram_claim_attempted,
            mas_promotion_attempted,
            live_benchmark_attempted,
            decisions,
            surfaces,
        };
        validate_witness(&witness)?;
        Ok(witness)
    }

    pub fn metrics(&self) -> MetalIoFeatureGateMetrics {
        let mut answer_packets = BTreeSet::new();
        let mut metrics = MetalIoFeatureGateMetrics {
            decision_count: self.decisions.len() as u64,
            surface_count: self.surfaces.len() as u64,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            model_bytes_loaded: self.model_bytes_loaded,
            metal_runtime_bytes_loaded: self.metal_runtime_bytes_loaded,
            max_metadata_bytes: self.max_metadata_bytes,
            feature_gate_success_bps: self.feature_gate_success_bps,
            ungated_metal_baseline_bps: self.ungated_metal_baseline_bps,
            no_fallback_baseline_bps: self.no_fallback_baseline_bps,
            hidden_metal_baseline_bps: self.hidden_metal_baseline_bps,
            address: self.address(),
            ..MetalIoFeatureGateMetrics::default()
        };
        for surface in &self.surfaces {
            answer_packets.insert(surface.answer_packet_ref.clone());
        }
        for decision in &self.decisions {
            answer_packets.insert(decision.answer_packet_ref.clone());
            match decision.feature_status {
                MetalFeatureStatus::Supported => metrics.supported_feature_count += 1,
                MetalFeatureStatus::Unsupported => metrics.unsupported_feature_count += 1,
                MetalFeatureStatus::Unknown => metrics.unknown_feature_count += 1,
            }
            match decision.selected_lane {
                MetalIoLane::MetalResourceLoading => metrics.metal_lane_count += 1,
                MetalIoLane::CpuSlabFallback => metrics.cpu_fallback_count += 1,
            }
        }
        metrics.answer_packet_count = answer_packets.len() as u64;
        metrics
    }

    pub fn address(&self) -> String {
        let mut parts =
            Vec::with_capacity(16 + self.decisions.len() * 16 + self.surfaces.len() * 3);
        parts.push(format!("product={:?}", self.product_build));
        parts.push(format!("status={:?}", self.pro_status));
        parts.push(format!("authority={}", self.route_authority));
        parts.push(format!("feature_gate={}", self.feature_gate_success_bps));

        let mut decisions = self.decisions.iter().collect::<Vec<_>>();
        decisions.sort_by(|left, right| left.decision_id.cmp(&right.decision_id));
        for decision in decisions {
            parts.push(format!(
                "decision={}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
                decision.decision_id,
                decision.mission_id,
                decision.device_ref,
                decision.gpu_family_ref,
                decision.feature_query_ref,
                decision.requested_feature,
                decision.feature_status.tag(),
                decision.selected_lane.tag(),
                decision
                    .metal_buffer_lease_ref
                    .as_deref()
                    .unwrap_or("metal_buffer_lease:none"),
                decision.fallback_cpu_slab_ref,
                decision.answer_packet_ref,
                decision.rollback_ref,
                decision.compatibility_fence
            ));
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
            "uas:metal-io-feature-gate:{}",
            sha256_hex(parts.join("\n").as_bytes())
        )
    }
}

fn validate_witness(witness: &MetalIoFeatureGateWitness) -> Result<(), MetalIoFeatureGateError> {
    if witness.decisions.is_empty() {
        return Err(MetalIoFeatureGateError::EmptyDecision);
    }
    if witness.surfaces.is_empty() {
        return Err(MetalIoFeatureGateError::EmptySurface);
    }
    if witness.product_build != ProductBuild::Pro
        || witness.pro_status != ProStatus::ResearchCandidate
        || witness.route_authority != "feature_gate_only"
    {
        return Err(MetalIoFeatureGateError::ProductStatusMismatch);
    }
    if witness.feature_gate_success_bps < MIN_FEATURE_GATE_SUCCESS_BPS {
        return Err(MetalIoFeatureGateError::BaselineUnbeaten(
            "feature_gate_success",
        ));
    }
    if witness.ungated_metal_baseline_bps >= witness.feature_gate_success_bps {
        return Err(MetalIoFeatureGateError::BaselineUnbeaten(
            "ungated_metal",
        ));
    }
    if witness.no_fallback_baseline_bps >= witness.feature_gate_success_bps {
        return Err(MetalIoFeatureGateError::BaselineUnbeaten("no_fallback"));
    }
    if witness.hidden_metal_baseline_bps >= witness.feature_gate_success_bps {
        return Err(MetalIoFeatureGateError::BaselineUnbeaten("hidden_metal"));
    }
    if witness.hidden_route_authority_attempted {
        return Err(MetalIoFeatureGateError::HiddenRouteAuthority);
    }
    if witness.route_policy_mutation_attempted {
        return Err(MetalIoFeatureGateError::RoutePolicyMutation);
    }
    if witness.gate_bypass_attempted {
        return Err(MetalIoFeatureGateError::GateBypass);
    }
    if witness.answer_packet_suppression_attempted {
        return Err(MetalIoFeatureGateError::AnswerPacketSuppression);
    }
    if witness.hidden_chain_exposure_attempted {
        return Err(MetalIoFeatureGateError::HiddenChainExposure);
    }
    if witness.hidden_cloud_route_attempted {
        return Err(MetalIoFeatureGateError::HiddenCloudRoute);
    }
    if witness.ssd_as_ram_claim_attempted {
        return Err(MetalIoFeatureGateError::SsdAsRamClaim);
    }
    if witness.mas_promotion_attempted {
        return Err(MetalIoFeatureGateError::MasPromotionAttempted);
    }
    if witness.live_benchmark_attempted {
        return Err(MetalIoFeatureGateError::LiveBenchmarkAttempted);
    }
    if witness.runtime_bytes_loaded != 0 {
        return Err(MetalIoFeatureGateError::RuntimeBytesLoaded);
    }
    if witness.model_bytes_loaded != 0 {
        return Err(MetalIoFeatureGateError::ModelBytesLoaded);
    }
    if witness.metal_runtime_bytes_loaded != 0 {
        return Err(MetalIoFeatureGateError::MetalRuntimeBytesLoaded);
    }
    if witness.max_metadata_bytes > MAX_METADATA_BYTES {
        return Err(MetalIoFeatureGateError::MetadataBudgetExceeded);
    }

    let mut seen_decisions = HashSet::new();
    let mut seen_surfaces = HashSet::new();
    let mut seen_decision_answer_packets = HashSet::new();
    let mut seen_surface_answer_packets = HashSet::new();
    let mut has_supported_metal = false;
    let mut has_cpu_fallback = false;

    for surface in &witness.surfaces {
        if !seen_surfaces.insert(surface.surface_id.clone()) {
            return Err(MetalIoFeatureGateError::DuplicateSurface(
                surface.surface_id.clone(),
            ));
        }
        if !seen_surface_answer_packets.insert(surface.answer_packet_ref.clone()) {
            return Err(MetalIoFeatureGateError::DuplicateAnswerPacket(
                surface.answer_packet_ref.clone(),
            ));
        }
        validate_surface(surface)?;
    }
    for decision in &witness.decisions {
        if !seen_decisions.insert(decision.decision_id.clone()) {
            return Err(MetalIoFeatureGateError::DuplicateDecision(
                decision.decision_id.clone(),
            ));
        }
        if !seen_decision_answer_packets.insert(decision.answer_packet_ref.clone()) {
            return Err(MetalIoFeatureGateError::DuplicateAnswerPacket(
                decision.answer_packet_ref.clone(),
            ));
        }
        validate_decision(decision)?;
        has_supported_metal |= decision.feature_status == MetalFeatureStatus::Supported
            && decision.selected_lane == MetalIoLane::MetalResourceLoading;
        has_cpu_fallback |= decision.selected_lane == MetalIoLane::CpuSlabFallback;
    }
    if !has_supported_metal || !has_cpu_fallback {
        return Err(MetalIoFeatureGateError::MissingLayerSeparation);
    }
    Ok(())
}

fn validate_decision(decision: &MetalIoFeatureDecision) -> Result<(), MetalIoFeatureGateError> {
    validate_nonempty("decision_id", &decision.decision_id)?;
    validate_nonempty("mission_id", &decision.mission_id)?;
    validate_prefixed(
        &decision.decision_id,
        "device_ref",
        &decision.device_ref,
        DEVICE_PREFIX,
        MetalIoFeatureGateError::MissingDeviceRef(decision.decision_id.clone()),
    )?;
    validate_prefixed(
        &decision.decision_id,
        "gpu_family_ref",
        &decision.gpu_family_ref,
        GPU_FAMILY_PREFIX,
        MetalIoFeatureGateError::MissingGpuFamilyRef(decision.decision_id.clone()),
    )?;
    validate_prefixed(
        &decision.decision_id,
        "feature_query_ref",
        &decision.feature_query_ref,
        FEATURE_QUERY_PREFIX,
        MetalIoFeatureGateError::MissingFeatureQueryRef(decision.decision_id.clone()),
    )?;
    validate_nonempty("requested_feature", &decision.requested_feature).map_err(|_| {
        MetalIoFeatureGateError::MissingRequestedFeature(decision.decision_id.clone())
    })?;
    validate_prefixed(
        &decision.decision_id,
        "fallback_cpu_slab_ref",
        &decision.fallback_cpu_slab_ref,
        CPU_SLAB_PREFIX,
        MetalIoFeatureGateError::MissingCpuSlabFallback(decision.decision_id.clone()),
    )?;
    validate_prefixed(
        &decision.decision_id,
        "answer_packet_ref",
        &decision.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
        MetalIoFeatureGateError::MissingAnswerPacket(decision.decision_id.clone()),
    )?;
    validate_prefixed(
        &decision.decision_id,
        "run_event_log_ref",
        &decision.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
        MetalIoFeatureGateError::MissingRunEventLog(decision.decision_id.clone()),
    )?;
    validate_prefixed(
        &decision.decision_id,
        "rollback_ref",
        &decision.rollback_ref,
        ROLLBACK_PREFIX,
        MetalIoFeatureGateError::MissingRollback(decision.decision_id.clone()),
    )?;
    validate_prefixed(
        &decision.decision_id,
        "admission_ref",
        &decision.admission_ref,
        ADMISSION_PREFIX,
        MetalIoFeatureGateError::MissingAdmission,
    )?;
    validate_prefixed(
        &decision.decision_id,
        "scope_rex_ref",
        &decision.scope_rex_ref,
        SCOPE_REX_PREFIX,
        MetalIoFeatureGateError::MissingScopeRex,
    )?;
    validate_prefixed(
        &decision.decision_id,
        "sovereign_gate_ref",
        &decision.sovereign_gate_ref,
        SOVEREIGN_GATE_PREFIX,
        MetalIoFeatureGateError::MissingSovereignGate,
    )?;
    validate_prefixed(
        &decision.decision_id,
        "compatibility_fence",
        &decision.compatibility_fence,
        COMPATIBILITY_FENCE_PREFIX,
        MetalIoFeatureGateError::MissingCompatibilityFence(decision.decision_id.clone()),
    )?;
    validate_prefixed(
        &decision.decision_id,
        "cancel_group_ref",
        &decision.cancel_group_ref,
        CANCEL_GROUP_PREFIX,
        MetalIoFeatureGateError::MissingCancelGroup(decision.decision_id.clone()),
    )?;
    if !caveat_is_honest(&decision.visible_caveat) {
        return Err(MetalIoFeatureGateError::MissingVisibleCaveat(
            decision.decision_id.clone(),
        ));
    }

    match (&decision.feature_status, &decision.selected_lane) {
        (MetalFeatureStatus::Supported, MetalIoLane::MetalResourceLoading) => {
            let Some(lease) = &decision.metal_buffer_lease_ref else {
                return Err(MetalIoFeatureGateError::MissingMetalBufferLease(
                    decision.decision_id.clone(),
                ));
            };
            validate_prefixed(
                &decision.decision_id,
                "metal_buffer_lease_ref",
                lease,
                METAL_BUFFER_LEASE_PREFIX,
                MetalIoFeatureGateError::MissingMetalBufferLease(decision.decision_id.clone()),
            )?;
        }
        (MetalFeatureStatus::Supported, MetalIoLane::CpuSlabFallback) => {
            return Err(MetalIoFeatureGateError::SupportedFeatureSelectedFallback(
                decision.decision_id.clone(),
            ));
        }
        (MetalFeatureStatus::Unsupported | MetalFeatureStatus::Unknown, MetalIoLane::CpuSlabFallback) => {
            if decision.metal_buffer_lease_ref.is_some() {
                return Err(MetalIoFeatureGateError::UnexpectedMetalBufferLease(
                    decision.decision_id.clone(),
                ));
            }
        }
        (MetalFeatureStatus::Unsupported | MetalFeatureStatus::Unknown, MetalIoLane::MetalResourceLoading) => {
            return Err(MetalIoFeatureGateError::UnsupportedFeatureSelectedMetal(
                decision.decision_id.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_surface(surface: &MetalIoFeatureSurface) -> Result<(), MetalIoFeatureGateError> {
    validate_nonempty("surface_id", &surface.surface_id)?;
    validate_prefixed(
        &surface.surface_id,
        "answer_packet_ref",
        &surface.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
        MetalIoFeatureGateError::MissingAnswerPacket(surface.surface_id.clone()),
    )?;
    if !caveat_is_honest(&surface.body) {
        return Err(MetalIoFeatureGateError::MissingVisibleCaveat(
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
        "fallback",
        "Metal",
    ] {
        if !surface.body.contains(marker) {
            return Err(MetalIoFeatureGateError::MissingRequiredMarker(
                marker.to_string(),
            ));
        }
    }
    for marker in [
        "SSD is RAM",
        "live 70B promoted",
        "hidden route authority",
        "Metal is always available",
    ] {
        if surface.body.contains(marker) {
            return Err(MetalIoFeatureGateError::ForbiddenMarker(marker.to_string()));
        }
    }
    Ok(())
}

fn validate_prefixed(
    id: &str,
    field: &'static str,
    value: &str,
    prefix: &str,
    error: MetalIoFeatureGateError,
) -> Result<(), MetalIoFeatureGateError> {
    if value.is_empty() {
        return Err(error);
    }
    validate_nonempty(field, value)?;
    if !value.starts_with(prefix) || value.len() == prefix.len() {
        return Err(error);
    }
    validate_nonempty("id", id)?;
    Ok(())
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), MetalIoFeatureGateError> {
    if value.is_empty() {
        return Err(MetalIoFeatureGateError::MissingField(field));
    }
    if value.trim() != value {
        return Err(MetalIoFeatureGateError::FieldHasSurroundingWhitespace(
            field,
        ));
    }
    if value.chars().any(char::is_control) {
        return Err(MetalIoFeatureGateError::FieldContainsControlCharacter(
            field,
        ));
    }
    Ok(())
}

fn caveat_is_honest(caveat: &str) -> bool {
    caveat.len() >= MIN_VISIBLE_CAVEAT_BYTES
        && caveat.contains("metadata-only")
        && caveat.contains("L1")
        && caveat.contains("L2")
        && caveat.contains("L3")
        && caveat.contains("AnswerPacket")
        && caveat.contains("rollback")
        && caveat.contains("fallback")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_witness_binds_supported_metal_and_cpu_fallbacks() {
        let witness = fixture_witness().expect("fixture witness");
        let metrics = witness.metrics();

        assert_eq!(metrics.decision_count, 3);
        assert_eq!(metrics.supported_feature_count, 1);
        assert_eq!(metrics.cpu_fallback_count, 2);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.metal_runtime_bytes_loaded, 0);
        assert!(metrics
            .address
            .starts_with("uas:metal-io-feature-gate:sha256:"));
    }

    #[test]
    fn address_is_deterministic_under_decision_order() {
        let witness = fixture_witness().expect("fixture witness");
        let mut reversed = witness.decisions.clone();
        reversed.reverse();
        let same = MetalIoFeatureGateWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "feature_gate_only",
            witness.feature_gate_success_bps,
            witness.ungated_metal_baseline_bps,
            witness.no_fallback_baseline_bps,
            witness.hidden_metal_baseline_bps,
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
            reversed,
            witness.surfaces.clone(),
        )
        .expect("reordered witness");

        assert_eq!(witness.address(), same.address());
    }

    #[test]
    fn rejects_unsupported_metal_gate_bypass_and_runtime_bytes() {
        assert!(matches!(
            reject_one_decision(|decision| {
                decision.feature_status = MetalFeatureStatus::Unsupported;
                decision.selected_lane = MetalIoLane::MetalResourceLoading;
            }),
            Err(MetalIoFeatureGateError::UnsupportedFeatureSelectedMetal(_))
        ));
        assert!(matches!(
            reject_one_decision(|decision| decision.fallback_cpu_slab_ref.clear()),
            Err(MetalIoFeatureGateError::MissingCpuSlabFallback(_))
        ));
        assert!(matches!(
            reject_witness(|witness| witness.gate_bypass_attempted = true),
            Err(MetalIoFeatureGateError::GateBypass)
        ));
        assert!(matches!(
            reject_witness(|witness| witness.metal_runtime_bytes_loaded = 1),
            Err(MetalIoFeatureGateError::MetalRuntimeBytesLoaded)
        ));
        assert!(matches!(
            reject_witness(|witness| witness.pro_status = ProStatus::Live),
            Err(MetalIoFeatureGateError::ProductStatusMismatch)
        ));
    }

    fn reject_witness(
        mutate: impl FnOnce(&mut MetalIoFeatureGateWitness),
    ) -> Result<MetalIoFeatureGateWitness, MetalIoFeatureGateError> {
        let mut witness = fixture_witness()?;
        mutate(&mut witness);
        MetalIoFeatureGateWitness::new(
            witness.product_build,
            witness.pro_status,
            witness.route_authority,
            witness.feature_gate_success_bps,
            witness.ungated_metal_baseline_bps,
            witness.no_fallback_baseline_bps,
            witness.hidden_metal_baseline_bps,
            witness.runtime_bytes_loaded,
            witness.model_bytes_loaded,
            witness.metal_runtime_bytes_loaded,
            witness.max_metadata_bytes,
            witness.hidden_route_authority_attempted,
            witness.route_policy_mutation_attempted,
            witness.gate_bypass_attempted,
            witness.answer_packet_suppression_attempted,
            witness.hidden_chain_exposure_attempted,
            witness.hidden_cloud_route_attempted,
            witness.ssd_as_ram_claim_attempted,
            witness.mas_promotion_attempted,
            witness.live_benchmark_attempted,
            witness.decisions,
            witness.surfaces,
        )
    }

    fn reject_one_decision(
        mutate: impl FnOnce(&mut MetalIoFeatureDecision),
    ) -> Result<MetalIoFeatureGateWitness, MetalIoFeatureGateError> {
        let witness = fixture_witness()?;
        let mut decisions = witness.decisions;
        mutate(&mut decisions[0]);
        MetalIoFeatureGateWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "feature_gate_only",
            9_850,
            8_100,
            7_900,
            7_600,
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
            decisions,
            fixture_surfaces()?,
        )
    }

    fn fixture_witness() -> Result<MetalIoFeatureGateWitness, MetalIoFeatureGateError> {
        MetalIoFeatureGateWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "feature_gate_only",
            9_850,
            8_100,
            7_900,
            7_600,
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
            fixture_decisions()?,
            fixture_surfaces()?,
        )
    }

    fn fixture_decisions() -> Result<Vec<MetalIoFeatureDecision>, MetalIoFeatureGateError> {
        Ok(vec![
            decision(
                "decision:metal-supported",
                MetalFeatureStatus::Supported,
                MetalIoLane::MetalResourceLoading,
                Some("metal_buffer_lease:residency-set-a:range-0".to_string()),
                "answer_packet:metal-io-supported",
            )?,
            decision(
                "decision:metal-unsupported",
                MetalFeatureStatus::Unsupported,
                MetalIoLane::CpuSlabFallback,
                None,
                "answer_packet:metal-io-unsupported",
            )?,
            decision(
                "decision:metal-unknown",
                MetalFeatureStatus::Unknown,
                MetalIoLane::CpuSlabFallback,
                None,
                "answer_packet:metal-io-unknown",
            )?,
        ])
    }

    fn fixture_surfaces() -> Result<Vec<MetalIoFeatureSurface>, MetalIoFeatureGateError> {
        Ok(vec![
            MetalIoFeatureSurface::new(
                "surface:metal-io-gate",
                "answer_packet:metal-io-surface-a",
                "Metal I/O remains metadata-only L1 proof: supported feature decisions may name a MetalBufferLease, unsupported or unknown decisions use CPU fallback, rollback and AnswerPacket caveats; L2 remains vault research and L3 product runtime is unchanged.",
            )?,
            MetalIoFeatureSurface::new(
                "surface:metal-io-fallback",
                "answer_packet:metal-io-surface-b",
                "Fallback is visible metadata-only evidence: no covert route control, every Metal decision carries rollback and AnswerPacket refs, CPU fallback is mandatory, L1 advances only while L2 remains red and L3 stays unchanged.",
            )?,
        ])
    }

    fn decision(
        decision_id: &str,
        status: MetalFeatureStatus,
        lane: MetalIoLane,
        lease: Option<String>,
        answer_packet: &str,
    ) -> Result<MetalIoFeatureDecision, MetalIoFeatureGateError> {
        MetalIoFeatureDecision::new(
            decision_id,
            "mission:coldstream-metal-gate",
            "metal_device:m2-pro-primary",
            "gpu_family:apple7-or-newer",
            "feature_query:supports-family-resource-loading",
            "resource_loading",
            status,
            lane,
            lease,
            format!("cpu_slab:{decision_id}:fallback"),
            answer_packet,
            format!("run_event_log:{decision_id}"),
            format!("rollback:{decision_id}"),
            "admission:scope-rex-metal-io-feature-gate",
            "scope_rex:metal-io-feature-gate",
            "sovereign_gate:metal-io-feature-gate",
            "compat:metal-family-resource-loading-v1",
            format!("cancel_group:{decision_id}"),
            "Metal I/O feature decision is metadata-only L1 evidence with CPU fallback, rollback, and AnswerPacket visibility; L2 remains vault research and L3 product runtime is unchanged until live transport witnesses pass.",
        )
    }
}
