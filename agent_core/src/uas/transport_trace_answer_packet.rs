//! TransportTrace-to-AnswerPacket binding contracts.
//!
//! This module is the metadata-only visibility layer for ColdStream traces. It
//! proves that transport-shaped answers bind byte accounting, stalls, copies,
//! fallback, rollback, RunEventLog, and AnswerPacket caveats before any runtime
//! or model bytes can promote.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ColdStreamTransportManifest, ColdStreamTransportTrace, ProStatus, ProductBuild};

pub const TRANSPORT_TRACE_ANSWER_PACKET_CURSOR: &str = "transport_trace_answer_packet";
pub const TRANSPORT_TRACE_ANSWER_PACKET_NEXT_CURSOR: &str = "ssd_wear_budget";

const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const FALLBACK_PREFIX: &str = "fallback:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const CODEC_STAGE_PREFIX: &str = "codec_stage:";
const CACHE_POLICY_PREFIX: &str = "cache_policy:";
const CANCELLATION_GROUP_PREFIX: &str = "cancel_group:";
const MAX_METADATA_BYTES: u64 = 256 * 1024;
const MAX_COPY_COUNT: u32 = 2;
const MAX_READ_AMPLIFICATION_BPS: u32 = 16_000;
const MIN_VISIBLE_SUMMARY_BYTES: usize = 96;

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:transport-trace-answer-packet:visibility-lane
// Plane: Assembly + Verification
// Residency: metadata-only lane label; does not allocate or move bytes.
pub enum TransportTraceVisibilityLane {
    CpuSlab,
    MetalFallback,
    MlxReadySlab,
}

impl TransportTraceVisibilityLane {
    fn tag(&self) -> &'static str {
        match self {
            Self::CpuSlab => "cpu_slab",
            Self::MetalFallback => "metal_fallback",
            Self::MlxReadySlab => "mlx_ready_slab",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:transport-trace-answer-packet:error
// Plane: Verification
// Residency: metadata-only rejection taxonomy.
pub enum TransportTraceAnswerPacketError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyFrame,
    EmptySurface,
    DuplicateFrame(String),
    DuplicateSurface(String),
    DuplicateAnswerPacket(String),
    MissingAnswerPacket(String),
    MissingRunEventLog(String),
    MissingFallback(String),
    MissingRollback(String),
    MissingAdmission,
    MissingScopeRex,
    MissingSovereignGate,
    MissingCompatibilityFence(String),
    MissingCodecStage(String),
    MissingCachePolicy(String),
    MissingCancellationGroup(String),
    TraceManifestMismatch(String),
    TraceNotMaterial(String),
    TraceBytesMissing(String),
    TraceReadUnderRequested(String),
    TraceDecodedUnderRequested(String),
    TraceCopiedBytesMissing(String),
    TraceP99BelowP95(String),
    TraceStallMissing(String),
    TraceCopyBudgetExceeded(String),
    ReadAmplificationInvalid(String),
    MissingFallbackCaveat(String),
    MissingUserVisibleSummary(String),
    MissingSurfaceRef(String),
    MissingRequiredMarker(String),
    ForbiddenMarker(String),
    MissingLayerSeparation,
    HiddenRouteAuthority,
    RoutePolicyMutation,
    ScopeRexBypass,
    SovereignGateBypass,
    AnswerPacketSuppression,
    FallbackCaveatSuppression,
    HiddenChainExposure,
    HiddenCloudRoute,
    ProductStatusMismatch,
    RuntimeBytesLoaded,
    ModelBytesLoaded,
    MetadataBudgetExceeded,
    BaselineUnbeaten(&'static str),
}

impl fmt::Display for TransportTraceAnswerPacketError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyFrame => write!(f, "missing transport trace AnswerPacket frame"),
            Self::EmptySurface => write!(f, "missing AnswerPacket visibility surface"),
            Self::DuplicateFrame(id) => write!(f, "duplicate frame `{id}`"),
            Self::DuplicateSurface(id) => write!(f, "duplicate surface `{id}`"),
            Self::DuplicateAnswerPacket(id) => write!(f, "duplicate AnswerPacket `{id}`"),
            Self::MissingAnswerPacket(id) => write!(f, "frame `{id}` missing AnswerPacket ref"),
            Self::MissingRunEventLog(id) => write!(f, "frame `{id}` missing RunEventLog ref"),
            Self::MissingFallback(id) => write!(f, "frame `{id}` missing fallback ref"),
            Self::MissingRollback(id) => write!(f, "frame `{id}` missing rollback ref"),
            Self::MissingAdmission => write!(f, "missing admission ref"),
            Self::MissingScopeRex => write!(f, "missing SCOPE-Rex ref"),
            Self::MissingSovereignGate => write!(f, "missing SovereignGate ref"),
            Self::MissingCompatibilityFence(id) => {
                write!(f, "frame `{id}` missing compatibility fence")
            }
            Self::MissingCodecStage(id) => write!(f, "frame `{id}` missing codec stage"),
            Self::MissingCachePolicy(id) => write!(f, "frame `{id}` missing cache policy"),
            Self::MissingCancellationGroup(id) => {
                write!(f, "frame `{id}` missing cancellation group")
            }
            Self::TraceManifestMismatch(id) => write!(f, "frame `{id}` does not match trace"),
            Self::TraceNotMaterial(id) => write!(f, "frame `{id}` is not material to answer"),
            Self::TraceBytesMissing(id) => write!(f, "frame `{id}` has missing byte accounting"),
            Self::TraceReadUnderRequested(id) => {
                write!(f, "frame `{id}` read fewer bytes than requested")
            }
            Self::TraceDecodedUnderRequested(id) => {
                write!(f, "frame `{id}` decoded fewer bytes than requested")
            }
            Self::TraceCopiedBytesMissing(id) => write!(f, "frame `{id}` has no copied byte proof"),
            Self::TraceP99BelowP95(id) => write!(f, "frame `{id}` p99 stall below p95"),
            Self::TraceStallMissing(id) => write!(f, "frame `{id}` missing stall evidence"),
            Self::TraceCopyBudgetExceeded(id) => write!(f, "frame `{id}` exceeds copy budget"),
            Self::ReadAmplificationInvalid(id) => {
                write!(f, "frame `{id}` has invalid read amplification")
            }
            Self::MissingFallbackCaveat(id) => write!(f, "frame `{id}` missing fallback caveat"),
            Self::MissingUserVisibleSummary(id) => {
                write!(f, "frame `{id}` missing user-visible summary")
            }
            Self::MissingSurfaceRef(id) => write!(f, "frame `{id}` has no matching surface"),
            Self::MissingRequiredMarker(marker) => write!(f, "missing required marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}` present"),
            Self::MissingLayerSeparation => write!(f, "L1/L2/L3 separation missing"),
            Self::HiddenRouteAuthority => write!(f, "hidden route authority attempted"),
            Self::RoutePolicyMutation => write!(f, "route policy mutation attempted"),
            Self::ScopeRexBypass => write!(f, "SCOPE-Rex bypass attempted"),
            Self::SovereignGateBypass => write!(f, "SovereignGate bypass attempted"),
            Self::AnswerPacketSuppression => write!(f, "AnswerPacket suppression attempted"),
            Self::FallbackCaveatSuppression => write!(f, "fallback caveat suppression attempted"),
            Self::HiddenChainExposure => write!(f, "hidden chain exposure attempted"),
            Self::HiddenCloudRoute => write!(f, "hidden cloud route attempted"),
            Self::ProductStatusMismatch => write!(f, "product status promoted beyond Pro Research"),
            Self::RuntimeBytesLoaded => write!(f, "metadata witness loaded runtime bytes"),
            Self::ModelBytesLoaded => write!(f, "metadata witness loaded model bytes"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
            Self::BaselineUnbeaten(name) => write!(f, "baseline `{name}` was unbeaten"),
        }
    }
}

impl std::error::Error for TransportTraceAnswerPacketError {}

#[derive(Clone, Debug)]
// UAS: uas:transport-trace-answer-packet:frame
// Plane: Verification + Controller
// Residency: metadata-only AnswerPacket frame; no cold bytes are moved.
pub struct TransportTraceAnswerPacketFrame {
    pub frame_id: String,
    pub manifest_ref: String,
    pub trace_id: String,
    pub route_id: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub fallback_ref: String,
    pub rollback_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence: String,
    pub codec_stage_ref: String,
    pub cache_policy_ref: String,
    pub cancellation_group: String,
    pub lane: TransportTraceVisibilityLane,
    pub bytes_requested: u64,
    pub bytes_read: u64,
    pub bytes_decoded: u64,
    pub copied_bytes: u64,
    pub copy_count: u32,
    pub cancellation_count: u32,
    pub p95_stall_ms: u32,
    pub p99_stall_ms: u32,
    pub read_amplification_bps: u32,
    pub fallback_caveat: String,
    pub user_visible_summary: String,
    pub material_to_answer: bool,
    pub l1_l2_l3_separated: bool,
    pub hidden_route_authority: bool,
    pub route_policy_mutated: bool,
    pub scope_rex_bypassed: bool,
    pub sovereign_gate_bypassed: bool,
    pub answer_packet_suppressed: bool,
    pub fallback_caveat_suppressed: bool,
    pub hidden_chain_exposed: bool,
    pub hidden_cloud_route: bool,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub metadata_bytes: u64,
}

impl TransportTraceAnswerPacketFrame {
    #[allow(clippy::too_many_arguments)]
    pub fn from_manifest_trace(
        manifest: &ColdStreamTransportManifest,
        trace: &ColdStreamTransportTrace,
        frame_id: impl Into<String>,
        lane: TransportTraceVisibilityLane,
        copied_bytes: u64,
        codec_stage_ref: impl Into<String>,
        cache_policy_ref: impl Into<String>,
        fallback_caveat: impl Into<String>,
        user_visible_summary: impl Into<String>,
        material_to_answer: bool,
        l1_l2_l3_separated: bool,
        hidden_route_authority: bool,
        route_policy_mutated: bool,
        scope_rex_bypassed: bool,
        sovereign_gate_bypassed: bool,
        answer_packet_suppressed: bool,
        fallback_caveat_suppressed: bool,
        hidden_chain_exposed: bool,
        hidden_cloud_route: bool,
        runtime_bytes_loaded: u64,
        model_bytes_loaded: u64,
        metadata_bytes: u64,
    ) -> Result<Self, TransportTraceAnswerPacketError> {
        let frame = Self {
            frame_id: frame_id.into(),
            manifest_ref: manifest.manifest_address.to_string(),
            trace_id: trace.trace_id.clone(),
            route_id: manifest.route_id.clone(),
            answer_packet_ref: trace.answer_packet_ref.clone(),
            run_event_log_ref: trace.run_event_log_ref.clone(),
            fallback_ref: manifest.fallback_ref.clone(),
            rollback_ref: manifest.rollback_ref.clone(),
            admission_ref: manifest.admission_ref.clone(),
            scope_rex_ref: manifest.scope_rex_ref.clone(),
            sovereign_gate_ref: manifest.sovereign_gate_ref.clone(),
            compatibility_fence: manifest
                .page_runs
                .first()
                .map(|run| run.compatibility_fence.clone())
                .unwrap_or_default(),
            codec_stage_ref: codec_stage_ref.into(),
            cache_policy_ref: cache_policy_ref.into(),
            cancellation_group: manifest.cancellation_group.clone(),
            lane,
            bytes_requested: trace.bytes_requested,
            bytes_read: trace.bytes_read,
            bytes_decoded: trace.bytes_decoded,
            copied_bytes,
            copy_count: trace.copy_count,
            cancellation_count: trace.cancellation_count,
            p95_stall_ms: trace.p95_stall_ms,
            p99_stall_ms: trace.p99_stall_ms,
            read_amplification_bps: trace.read_amplification_bps,
            fallback_caveat: fallback_caveat.into(),
            user_visible_summary: user_visible_summary.into(),
            material_to_answer,
            l1_l2_l3_separated,
            hidden_route_authority,
            route_policy_mutated,
            scope_rex_bypassed,
            sovereign_gate_bypassed,
            answer_packet_suppressed,
            fallback_caveat_suppressed,
            hidden_chain_exposed,
            hidden_cloud_route,
            runtime_bytes_loaded,
            model_bytes_loaded,
            metadata_bytes,
        };
        validate_frame(&frame, manifest, trace)?;
        Ok(frame)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:transport-trace-answer-packet:surface
// Plane: Verification
// Residency: local visible proof surface; metadata-only scan.
pub struct TransportTraceAnswerPacketSurface {
    pub surface_id: String,
    pub answer_packet_ref: String,
    pub visible_text: String,
    pub required_markers: Vec<String>,
    pub forbidden_markers: Vec<String>,
}

impl TransportTraceAnswerPacketSurface {
    pub fn new(
        surface_id: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        visible_text: impl Into<String>,
        required_markers: Vec<String>,
        forbidden_markers: Vec<String>,
    ) -> Result<Self, TransportTraceAnswerPacketError> {
        let surface = Self {
            surface_id: surface_id.into(),
            answer_packet_ref: answer_packet_ref.into(),
            visible_text: visible_text.into(),
            required_markers,
            forbidden_markers,
        };
        validate_surface(&surface)?;
        Ok(surface)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:transport-trace-answer-packet:witness
// Plane: Controller + Verification
// Residency: metadata-only registry for AnswerPacket-visible transport traces.
pub struct TransportTraceAnswerPacketWitness {
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub frames: Vec<TransportTraceAnswerPacketFrame>,
    pub surfaces: Vec<TransportTraceAnswerPacketSurface>,
    pub hidden_summary_baseline_bps: u64,
    pub no_answer_packet_baseline_bps: u64,
    pub invisible_fallback_baseline_bps: u64,
    pub live_authority_baseline_bps: u64,
}

impl TransportTraceAnswerPacketWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        frames: Vec<TransportTraceAnswerPacketFrame>,
        surfaces: Vec<TransportTraceAnswerPacketSurface>,
        hidden_summary_baseline_bps: u64,
        no_answer_packet_baseline_bps: u64,
        invisible_fallback_baseline_bps: u64,
        live_authority_baseline_bps: u64,
    ) -> Result<Self, TransportTraceAnswerPacketError> {
        let witness = Self {
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            frames,
            surfaces,
            hidden_summary_baseline_bps,
            no_answer_packet_baseline_bps,
            invisible_fallback_baseline_bps,
            live_authority_baseline_bps,
        };
        validate_witness(&witness)?;
        Ok(witness)
    }

    pub fn metrics(&self) -> TransportTraceAnswerPacketMetrics {
        let packet_refs = self
            .frames
            .iter()
            .map(|frame| frame.answer_packet_ref.as_str())
            .collect::<BTreeSet<_>>();
        let run_log_refs = self
            .frames
            .iter()
            .map(|frame| frame.run_event_log_ref.as_str())
            .collect::<BTreeSet<_>>();
        let fallback_refs = self
            .frames
            .iter()
            .map(|frame| frame.fallback_ref.as_str())
            .collect::<BTreeSet<_>>();
        let lane_count = self
            .frames
            .iter()
            .map(|frame| frame.lane.tag())
            .collect::<BTreeSet<_>>()
            .len() as u64;
        TransportTraceAnswerPacketMetrics {
            frame_count: self.frames.len() as u64,
            surface_count: self.surfaces.len() as u64,
            answer_packet_count: packet_refs.len() as u64,
            run_event_log_count: run_log_refs.len() as u64,
            fallback_count: fallback_refs.len() as u64,
            visibility_lane_count: lane_count,
            bytes_requested: self.frames.iter().map(|frame| frame.bytes_requested).sum(),
            bytes_read: self.frames.iter().map(|frame| frame.bytes_read).sum(),
            bytes_decoded: self.frames.iter().map(|frame| frame.bytes_decoded).sum(),
            copied_bytes: self.frames.iter().map(|frame| frame.copied_bytes).sum(),
            max_copy_count: self
                .frames
                .iter()
                .map(|frame| u64::from(frame.copy_count))
                .max()
                .unwrap_or(0),
            cancellation_count: self
                .frames
                .iter()
                .map(|frame| u64::from(frame.cancellation_count))
                .sum(),
            max_p95_stall_ms: self
                .frames
                .iter()
                .map(|frame| u64::from(frame.p95_stall_ms))
                .max()
                .unwrap_or(0),
            max_p99_stall_ms: self
                .frames
                .iter()
                .map(|frame| u64::from(frame.p99_stall_ms))
                .max()
                .unwrap_or(0),
            min_read_amplification_bps: self
                .frames
                .iter()
                .map(|frame| u64::from(frame.read_amplification_bps))
                .min()
                .unwrap_or(0),
            visible_summary_count: self
                .frames
                .iter()
                .filter(|frame| !frame.user_visible_summary.is_empty())
                .count() as u64,
            fallback_caveat_count: self
                .frames
                .iter()
                .filter(|frame| !frame.fallback_caveat.is_empty())
                .count() as u64,
            runtime_bytes_loaded: self
                .frames
                .iter()
                .map(|frame| frame.runtime_bytes_loaded)
                .sum(),
            model_bytes_loaded: self
                .frames
                .iter()
                .map(|frame| frame.model_bytes_loaded)
                .sum(),
            max_metadata_bytes: self
                .frames
                .iter()
                .map(|frame| frame.metadata_bytes)
                .max()
                .unwrap_or(0),
            hidden_summary_baseline_bps: self.hidden_summary_baseline_bps,
            no_answer_packet_baseline_bps: self.no_answer_packet_baseline_bps,
            invisible_fallback_baseline_bps: self.invisible_fallback_baseline_bps,
            live_authority_baseline_bps: self.live_authority_baseline_bps,
        }
    }

    pub fn address(&self) -> String {
        let mut parts = self
            .frames
            .iter()
            .map(|frame| {
                format!(
                    "{}|{}|{}|{}|{}|{}|{}|{}",
                    frame.frame_id,
                    frame.manifest_ref,
                    frame.trace_id,
                    frame.answer_packet_ref,
                    frame.bytes_requested,
                    frame.bytes_read,
                    frame.copy_count,
                    frame.lane.tag()
                )
            })
            .collect::<Vec<_>>();
        parts.sort();
        for surface in &self.surfaces {
            parts.push(format!(
                "surface|{}|{}|{}",
                surface.surface_id,
                surface.answer_packet_ref,
                sha256_hex(surface.visible_text.as_bytes())
            ));
        }
        parts.sort();
        format!(
            "uas:transport-trace-answer-packet:sha256:{}",
            sha256_hex(parts.join("\n").as_bytes())
        )
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:transport-trace-answer-packet:metrics
// Plane: Verification
// Residency: metadata-only aggregation; no runtime/model bytes.
pub struct TransportTraceAnswerPacketMetrics {
    pub frame_count: u64,
    pub surface_count: u64,
    pub answer_packet_count: u64,
    pub run_event_log_count: u64,
    pub fallback_count: u64,
    pub visibility_lane_count: u64,
    pub bytes_requested: u64,
    pub bytes_read: u64,
    pub bytes_decoded: u64,
    pub copied_bytes: u64,
    pub max_copy_count: u64,
    pub cancellation_count: u64,
    pub max_p95_stall_ms: u64,
    pub max_p99_stall_ms: u64,
    pub min_read_amplification_bps: u64,
    pub visible_summary_count: u64,
    pub fallback_caveat_count: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub max_metadata_bytes: u64,
    pub hidden_summary_baseline_bps: u64,
    pub no_answer_packet_baseline_bps: u64,
    pub invisible_fallback_baseline_bps: u64,
    pub live_authority_baseline_bps: u64,
}

fn validate_witness(
    witness: &TransportTraceAnswerPacketWitness,
) -> Result<(), TransportTraceAnswerPacketError> {
    if witness.frames.is_empty() {
        return Err(TransportTraceAnswerPacketError::EmptyFrame);
    }
    if witness.surfaces.is_empty() {
        return Err(TransportTraceAnswerPacketError::EmptySurface);
    }
    validate_nonempty("route_authority", &witness.route_authority)?;
    if witness.product_build != ProductBuild::Pro
        || witness.pro_status != ProStatus::ResearchCandidate
    {
        return Err(TransportTraceAnswerPacketError::ProductStatusMismatch);
    }
    if witness.route_authority != "visible_trace_only" {
        return Err(TransportTraceAnswerPacketError::HiddenRouteAuthority);
    }

    let mut surface_ids = HashSet::new();
    for surface in &witness.surfaces {
        if !surface_ids.insert(surface.surface_id.clone()) {
            return Err(TransportTraceAnswerPacketError::DuplicateSurface(
                surface.surface_id.clone(),
            ));
        }
    }
    let mut frame_ids = HashSet::new();
    let mut packet_refs = HashSet::new();
    let surface_packet_refs = witness
        .surfaces
        .iter()
        .map(|surface| surface.answer_packet_ref.as_str())
        .collect::<HashSet<_>>();
    for frame in &witness.frames {
        validate_frame_contract(frame)?;
        if !frame_ids.insert(frame.frame_id.clone()) {
            return Err(TransportTraceAnswerPacketError::DuplicateFrame(
                frame.frame_id.clone(),
            ));
        }
        if !packet_refs.insert(frame.answer_packet_ref.clone()) {
            return Err(TransportTraceAnswerPacketError::DuplicateAnswerPacket(
                frame.answer_packet_ref.clone(),
            ));
        }
        if !surface_packet_refs.contains(frame.answer_packet_ref.as_str()) {
            return Err(TransportTraceAnswerPacketError::MissingSurfaceRef(
                frame.frame_id.clone(),
            ));
        }
    }
    let metrics = witness.metrics();
    if metrics.hidden_summary_baseline_bps >= 9_000 {
        return Err(TransportTraceAnswerPacketError::BaselineUnbeaten(
            "hidden_summary",
        ));
    }
    if metrics.no_answer_packet_baseline_bps >= 9_000 {
        return Err(TransportTraceAnswerPacketError::BaselineUnbeaten(
            "no_answer_packet",
        ));
    }
    if metrics.invisible_fallback_baseline_bps >= 9_000 {
        return Err(TransportTraceAnswerPacketError::BaselineUnbeaten(
            "invisible_fallback",
        ));
    }
    if metrics.live_authority_baseline_bps >= 9_000 {
        return Err(TransportTraceAnswerPacketError::BaselineUnbeaten(
            "live_authority",
        ));
    }
    Ok(())
}

fn validate_frame(
    frame: &TransportTraceAnswerPacketFrame,
    manifest: &ColdStreamTransportManifest,
    trace: &ColdStreamTransportTrace,
) -> Result<(), TransportTraceAnswerPacketError> {
    for (field, value) in [
        ("frame_id", frame.frame_id.as_str()),
        ("manifest_ref", frame.manifest_ref.as_str()),
        ("trace_id", frame.trace_id.as_str()),
        ("route_id", frame.route_id.as_str()),
        ("answer_packet_ref", frame.answer_packet_ref.as_str()),
        ("run_event_log_ref", frame.run_event_log_ref.as_str()),
        ("fallback_ref", frame.fallback_ref.as_str()),
        ("rollback_ref", frame.rollback_ref.as_str()),
        ("admission_ref", frame.admission_ref.as_str()),
        ("scope_rex_ref", frame.scope_rex_ref.as_str()),
        ("sovereign_gate_ref", frame.sovereign_gate_ref.as_str()),
        ("compatibility_fence", frame.compatibility_fence.as_str()),
        ("codec_stage_ref", frame.codec_stage_ref.as_str()),
        ("cache_policy_ref", frame.cache_policy_ref.as_str()),
        ("cancellation_group", frame.cancellation_group.as_str()),
        ("fallback_caveat", frame.fallback_caveat.as_str()),
        ("user_visible_summary", frame.user_visible_summary.as_str()),
    ] {
        validate_nonempty(field, value)?;
    }
    if frame.manifest_ref != manifest.manifest_address.to_string()
        || frame.trace_id != trace.trace_id
        || frame.route_id != manifest.route_id
        || frame.bytes_requested != trace.bytes_requested
        || frame.bytes_read != trace.bytes_read
        || frame.bytes_decoded != trace.bytes_decoded
        || frame.copy_count != trace.copy_count
        || frame.cancellation_count != trace.cancellation_count
        || frame.p95_stall_ms != trace.p95_stall_ms
        || frame.p99_stall_ms != trace.p99_stall_ms
        || frame.read_amplification_bps != trace.read_amplification_bps
    {
        return Err(TransportTraceAnswerPacketError::TraceManifestMismatch(
            frame.frame_id.clone(),
        ));
    }
    validate_frame_contract(frame)
}

fn validate_frame_contract(
    frame: &TransportTraceAnswerPacketFrame,
) -> Result<(), TransportTraceAnswerPacketError> {
    for (field, value) in [
        ("frame_id", frame.frame_id.as_str()),
        ("manifest_ref", frame.manifest_ref.as_str()),
        ("trace_id", frame.trace_id.as_str()),
        ("route_id", frame.route_id.as_str()),
        ("answer_packet_ref", frame.answer_packet_ref.as_str()),
        ("run_event_log_ref", frame.run_event_log_ref.as_str()),
        ("fallback_ref", frame.fallback_ref.as_str()),
        ("rollback_ref", frame.rollback_ref.as_str()),
        ("admission_ref", frame.admission_ref.as_str()),
        ("scope_rex_ref", frame.scope_rex_ref.as_str()),
        ("sovereign_gate_ref", frame.sovereign_gate_ref.as_str()),
        ("compatibility_fence", frame.compatibility_fence.as_str()),
        ("codec_stage_ref", frame.codec_stage_ref.as_str()),
        ("cache_policy_ref", frame.cache_policy_ref.as_str()),
        ("cancellation_group", frame.cancellation_group.as_str()),
        ("fallback_caveat", frame.fallback_caveat.as_str()),
        ("user_visible_summary", frame.user_visible_summary.as_str()),
    ] {
        validate_nonempty(field, value)?;
    }
    if !frame.material_to_answer {
        return Err(TransportTraceAnswerPacketError::TraceNotMaterial(
            frame.frame_id.clone(),
        ));
    }
    if !frame.answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX) {
        return Err(TransportTraceAnswerPacketError::MissingAnswerPacket(
            frame.frame_id.clone(),
        ));
    }
    if !frame.run_event_log_ref.starts_with(RUN_EVENT_LOG_PREFIX) {
        return Err(TransportTraceAnswerPacketError::MissingRunEventLog(
            frame.frame_id.clone(),
        ));
    }
    if !frame.fallback_ref.starts_with(FALLBACK_PREFIX) {
        return Err(TransportTraceAnswerPacketError::MissingFallback(
            frame.frame_id.clone(),
        ));
    }
    if !frame.rollback_ref.starts_with(ROLLBACK_PREFIX) {
        return Err(TransportTraceAnswerPacketError::MissingRollback(
            frame.frame_id.clone(),
        ));
    }
    if !frame.admission_ref.starts_with(ADMISSION_PREFIX) {
        return Err(TransportTraceAnswerPacketError::MissingAdmission);
    }
    if !frame.scope_rex_ref.starts_with(SCOPE_REX_PREFIX) {
        return Err(TransportTraceAnswerPacketError::MissingScopeRex);
    }
    if !frame.sovereign_gate_ref.starts_with(SOVEREIGN_GATE_PREFIX) {
        return Err(TransportTraceAnswerPacketError::MissingSovereignGate);
    }
    if !frame
        .compatibility_fence
        .starts_with(COMPATIBILITY_FENCE_PREFIX)
    {
        return Err(TransportTraceAnswerPacketError::MissingCompatibilityFence(
            frame.frame_id.clone(),
        ));
    }
    if !frame.codec_stage_ref.starts_with(CODEC_STAGE_PREFIX) {
        return Err(TransportTraceAnswerPacketError::MissingCodecStage(
            frame.frame_id.clone(),
        ));
    }
    if !frame.cache_policy_ref.starts_with(CACHE_POLICY_PREFIX) {
        return Err(TransportTraceAnswerPacketError::MissingCachePolicy(
            frame.frame_id.clone(),
        ));
    }
    if !frame
        .cancellation_group
        .starts_with(CANCELLATION_GROUP_PREFIX)
    {
        return Err(TransportTraceAnswerPacketError::MissingCancellationGroup(
            frame.frame_id.clone(),
        ));
    }
    if frame.bytes_requested == 0 || frame.bytes_read == 0 || frame.bytes_decoded == 0 {
        return Err(TransportTraceAnswerPacketError::TraceBytesMissing(
            frame.frame_id.clone(),
        ));
    }
    if frame.bytes_read < frame.bytes_requested {
        return Err(TransportTraceAnswerPacketError::TraceReadUnderRequested(
            frame.frame_id.clone(),
        ));
    }
    if frame.bytes_decoded < frame.bytes_requested {
        return Err(TransportTraceAnswerPacketError::TraceDecodedUnderRequested(
            frame.frame_id.clone(),
        ));
    }
    if frame.copied_bytes < frame.bytes_decoded {
        return Err(TransportTraceAnswerPacketError::TraceCopiedBytesMissing(
            frame.frame_id.clone(),
        ));
    }
    if frame.p99_stall_ms < frame.p95_stall_ms {
        return Err(TransportTraceAnswerPacketError::TraceP99BelowP95(
            frame.frame_id.clone(),
        ));
    }
    if frame.p95_stall_ms == 0 || frame.p99_stall_ms == 0 {
        return Err(TransportTraceAnswerPacketError::TraceStallMissing(
            frame.frame_id.clone(),
        ));
    }
    if frame.copy_count > MAX_COPY_COUNT {
        return Err(TransportTraceAnswerPacketError::TraceCopyBudgetExceeded(
            frame.frame_id.clone(),
        ));
    }
    if !(10_000..=MAX_READ_AMPLIFICATION_BPS).contains(&frame.read_amplification_bps) {
        return Err(TransportTraceAnswerPacketError::ReadAmplificationInvalid(
            frame.frame_id.clone(),
        ));
    }
    if !visible_caveat_mentions_transport(&frame.fallback_caveat) {
        return Err(TransportTraceAnswerPacketError::MissingFallbackCaveat(
            frame.frame_id.clone(),
        ));
    }
    if !visible_summary_mentions_trace(frame) {
        return Err(TransportTraceAnswerPacketError::MissingUserVisibleSummary(
            frame.frame_id.clone(),
        ));
    }
    if !frame.l1_l2_l3_separated {
        return Err(TransportTraceAnswerPacketError::MissingLayerSeparation);
    }
    if frame.hidden_route_authority {
        return Err(TransportTraceAnswerPacketError::HiddenRouteAuthority);
    }
    if frame.route_policy_mutated {
        return Err(TransportTraceAnswerPacketError::RoutePolicyMutation);
    }
    if frame.scope_rex_bypassed {
        return Err(TransportTraceAnswerPacketError::ScopeRexBypass);
    }
    if frame.sovereign_gate_bypassed {
        return Err(TransportTraceAnswerPacketError::SovereignGateBypass);
    }
    if frame.answer_packet_suppressed {
        return Err(TransportTraceAnswerPacketError::AnswerPacketSuppression);
    }
    if frame.fallback_caveat_suppressed {
        return Err(TransportTraceAnswerPacketError::FallbackCaveatSuppression);
    }
    if frame.hidden_chain_exposed || contains_hidden_reasoning(&frame.user_visible_summary) {
        return Err(TransportTraceAnswerPacketError::HiddenChainExposure);
    }
    if frame.hidden_cloud_route {
        return Err(TransportTraceAnswerPacketError::HiddenCloudRoute);
    }
    if frame.runtime_bytes_loaded > 0 {
        return Err(TransportTraceAnswerPacketError::RuntimeBytesLoaded);
    }
    if frame.model_bytes_loaded > 0 {
        return Err(TransportTraceAnswerPacketError::ModelBytesLoaded);
    }
    if frame.metadata_bytes > MAX_METADATA_BYTES {
        return Err(TransportTraceAnswerPacketError::MetadataBudgetExceeded);
    }
    Ok(())
}

fn validate_surface(
    surface: &TransportTraceAnswerPacketSurface,
) -> Result<(), TransportTraceAnswerPacketError> {
    validate_nonempty("surface_id", &surface.surface_id)?;
    validate_nonempty("answer_packet_ref", &surface.answer_packet_ref)?;
    validate_nonempty("visible_text", &surface.visible_text)?;
    if !surface.answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX) {
        return Err(TransportTraceAnswerPacketError::MissingAnswerPacket(
            surface.surface_id.clone(),
        ));
    }
    for marker in &surface.required_markers {
        validate_nonempty("required_marker", marker)?;
        if !surface.visible_text.contains(marker) {
            return Err(TransportTraceAnswerPacketError::MissingRequiredMarker(
                marker.clone(),
            ));
        }
    }
    for marker in &surface.forbidden_markers {
        validate_nonempty("forbidden_marker", marker)?;
        if surface.visible_text.contains(marker) {
            return Err(TransportTraceAnswerPacketError::ForbiddenMarker(
                marker.clone(),
            ));
        }
    }
    if contains_hidden_reasoning(&surface.visible_text) {
        return Err(TransportTraceAnswerPacketError::HiddenChainExposure);
    }
    Ok(())
}

fn validate_nonempty(
    field: &'static str,
    value: &str,
) -> Result<(), TransportTraceAnswerPacketError> {
    if value.is_empty() {
        return Err(TransportTraceAnswerPacketError::MissingField(field));
    }
    if value != value.trim() {
        return Err(TransportTraceAnswerPacketError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(char::is_control) {
        return Err(TransportTraceAnswerPacketError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

fn visible_caveat_mentions_transport(value: &str) -> bool {
    let lower = value.to_ascii_lowercase();
    lower.contains("cold transport")
        && lower.contains("fallback")
        && lower.contains("visible")
        && lower.contains("rollback")
}

fn visible_summary_mentions_trace(frame: &TransportTraceAnswerPacketFrame) -> bool {
    let summary = frame.user_visible_summary.to_ascii_lowercase();
    frame.user_visible_summary.len() >= MIN_VISIBLE_SUMMARY_BYTES
        && summary.contains("bytes")
        && summary.contains("stall")
        && summary.contains("cop")
        && summary.contains("fallback")
        && summary.contains("caveat")
        && summary.contains("answerpacket")
        && summary.contains(&frame.bytes_requested.to_string())
        && summary.contains(&frame.p99_stall_ms.to_string())
}

fn contains_hidden_reasoning(value: &str) -> bool {
    let lower = value.to_ascii_lowercase();
    lower.contains("chain-of-thought")
        || lower.contains("hidden reasoning")
        || lower.contains("<cot>")
        || lower.contains("private scratchpad")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::{
        ColdStreamAuthority, ColdStreamCachePolicy, ColdStreamDestination, ColdStreamPageRun,
        ColdStreamPriority, UasAddress, UasKind,
    };

    const CREATED_AT_MS: u64 = 1_779_552_000_000;

    #[test]
    fn valid_witness_binds_visible_answer_packet_trace() {
        let witness = fixture_witness().expect("witness");
        let metrics = witness.metrics();
        assert_eq!(metrics.frame_count, 2);
        assert_eq!(metrics.answer_packet_count, 2);
        assert_eq!(metrics.run_event_log_count, 2);
        assert_eq!(metrics.visibility_lane_count, 2);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert!(witness
            .address()
            .starts_with("uas:transport-trace-answer-packet:sha256:"));
    }

    #[test]
    fn address_is_deterministic_under_frame_order() {
        let witness = fixture_witness().expect("witness");
        let address = witness.address();
        let mut frames = witness.frames.clone();
        frames.reverse();
        let reversed = TransportTraceAnswerPacketWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "visible_trace_only",
            frames,
            witness.surfaces.clone(),
            4_000,
            3_500,
            4_250,
            4_500,
        )
        .expect("reversed");
        assert_eq!(address, reversed.address());
    }

    #[test]
    fn rejects_missing_answer_packet_and_fallback_caveat() {
        assert_eq!(
            reject_frame(|frame| frame.answer_packet_ref = "bad-packet".to_string()).unwrap_err(),
            TransportTraceAnswerPacketError::MissingAnswerPacket("frame-cpu".to_string())
        );
        assert_eq!(
            reject_frame(|frame| frame.fallback_caveat = "silent".to_string()).unwrap_err(),
            TransportTraceAnswerPacketError::MissingFallbackCaveat("frame-cpu".to_string())
        );
    }

    #[test]
    fn rejects_bad_byte_math_and_stall_order() {
        assert_eq!(
            reject_frame(|frame| frame.bytes_read = frame.bytes_requested - 1).unwrap_err(),
            TransportTraceAnswerPacketError::TraceReadUnderRequested("frame-cpu".to_string())
        );
        assert_eq!(
            reject_frame(|frame| frame.copied_bytes = 0).unwrap_err(),
            TransportTraceAnswerPacketError::TraceCopiedBytesMissing("frame-cpu".to_string())
        );
        assert_eq!(
            reject_trace(|trace| trace.p99_stall_ms = trace.p95_stall_ms - 1).unwrap_err(),
            crate::uas::ColdStreamError::TraceP99BelowP95
        );
    }

    #[test]
    fn rejects_hidden_authority_and_runtime_bytes() {
        assert_eq!(
            reject_frame(|frame| frame.hidden_route_authority = true).unwrap_err(),
            TransportTraceAnswerPacketError::HiddenRouteAuthority
        );
        assert_eq!(
            reject_frame(|frame| frame.runtime_bytes_loaded = 1).unwrap_err(),
            TransportTraceAnswerPacketError::RuntimeBytesLoaded
        );
    }

    #[test]
    fn rejects_hidden_reasoning_on_surface() {
        assert_eq!(
            TransportTraceAnswerPacketSurface::new(
                "surface",
                "answer_packet:trace",
                "AnswerPacket visible chain-of-thought",
                vec!["AnswerPacket".to_string()],
                vec!["product route is live".to_string()],
            )
            .unwrap_err(),
            TransportTraceAnswerPacketError::HiddenChainExposure
        );
    }

    fn reject_frame(
        mutate: impl FnOnce(&mut TransportTraceAnswerPacketFrame),
    ) -> Result<TransportTraceAnswerPacketWitness, TransportTraceAnswerPacketError> {
        let mut witness = fixture_witness()?;
        mutate(&mut witness.frames[0]);
        TransportTraceAnswerPacketWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "visible_trace_only",
            witness.frames,
            witness.surfaces,
            4_000,
            3_500,
            4_250,
            4_500,
        )
    }

    fn reject_trace(
        mutate: impl FnOnce(&mut ColdStreamTransportTrace),
    ) -> Result<ColdStreamTransportTrace, crate::uas::ColdStreamError> {
        let manifest = manifest("cpu")?;
        let mut trace = trace(&manifest, "trace-cpu")?;
        mutate(&mut trace);
        ColdStreamTransportTrace::new(
            &manifest,
            &trace.trace_id,
            trace.bytes_requested,
            trace.bytes_read,
            trace.bytes_decoded,
            trace.copy_count,
            trace.cancellation_count,
            trace.p95_stall_ms,
            trace.p99_stall_ms,
            trace.read_amplification_bps,
            trace.stale_slab_entered_execution,
            trace.fallback_visible,
            &trace.run_event_log_ref,
            &trace.answer_packet_ref,
        )
    }

    fn fixture_witness(
    ) -> Result<TransportTraceAnswerPacketWitness, TransportTraceAnswerPacketError> {
        let cpu_manifest = manifest("cpu").map_err(|_| {
            TransportTraceAnswerPacketError::TraceManifestMismatch("cpu".to_string())
        })?;
        let cpu_trace = trace(&cpu_manifest, "trace-cpu").map_err(|_| {
            TransportTraceAnswerPacketError::TraceManifestMismatch("cpu".to_string())
        })?;
        let metal_manifest = manifest("metal").map_err(|_| {
            TransportTraceAnswerPacketError::TraceManifestMismatch("metal".to_string())
        })?;
        let metal_trace = trace(&metal_manifest, "trace-metal").map_err(|_| {
            TransportTraceAnswerPacketError::TraceManifestMismatch("metal".to_string())
        })?;
        let frames = vec![
            frame(
                &cpu_manifest,
                &cpu_trace,
                "frame-cpu",
                TransportTraceVisibilityLane::CpuSlab,
            )?,
            frame(
                &metal_manifest,
                &metal_trace,
                "frame-metal",
                TransportTraceVisibilityLane::MetalFallback,
            )?,
        ];
        let surfaces = frames
            .iter()
            .map(|frame| {
                TransportTraceAnswerPacketSurface::new(
                    format!("surface-{}", frame.frame_id),
                    frame.answer_packet_ref.clone(),
                    frame.user_visible_summary.clone(),
                    vec![
                        "AnswerPacket".to_string(),
                        "bytes".to_string(),
                        "stall".to_string(),
                        "fallback".to_string(),
                        "caveat".to_string(),
                    ],
                    vec![
                        "product route is live".to_string(),
                        "chain-of-thought".to_string(),
                        "hidden cloud".to_string(),
                    ],
                )
            })
            .collect::<Result<Vec<_>, _>>()?;
        TransportTraceAnswerPacketWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "visible_trace_only",
            frames,
            surfaces,
            4_000,
            3_500,
            4_250,
            4_500,
        )
    }

    fn frame(
        manifest: &ColdStreamTransportManifest,
        trace: &ColdStreamTransportTrace,
        frame_id: &str,
        lane: TransportTraceVisibilityLane,
    ) -> Result<TransportTraceAnswerPacketFrame, TransportTraceAnswerPacketError> {
        TransportTraceAnswerPacketFrame::from_manifest_trace(
            manifest,
            trace,
            frame_id,
            lane,
            trace.bytes_decoded * u64::from(trace.copy_count),
            format!("codec_stage:{frame_id}:decode"),
            format!("cache_policy:{frame_id}:no_cache"),
            "cold transport fallback remained visible with rollback: degraded to CPU slab when deadline risk rose",
            format!(
                "AnswerPacket transport caveat: cold transport read {} bytes, p99 stall {} ms, copies {}, fallback visible, caveat retained, no product runtime promotion.",
                trace.bytes_requested, trace.p99_stall_ms, trace.copy_count
            ),
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            0,
            0,
            16 * 1024,
        )
    }

    fn manifest(id: &str) -> Result<ColdStreamTransportManifest, crate::uas::ColdStreamError> {
        ColdStreamTransportManifest::new(
            format!("manifest-{id}"),
            format!("route:coldstream:{id}"),
            format!("uas:semantic_working_set_plan:{id}"),
            format!("residency_page_table:{id}"),
            format!("admission:{id}"),
            format!("scope_rex:{id}"),
            format!("sovereign_gate:{id}"),
            format!("rollback:{id}"),
            format!("run_event_log:{id}"),
            format!("answer_packet:{id}"),
            format!("fallback:{id}"),
            format!("cancel_group:{id}"),
            ColdStreamAuthority::ProposalOnly,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            vec![ColdStreamPageRun::new(
                format!("run-{id}"),
                format!("file-{id}"),
                4096,
                128 * 1024,
                vec![format!("semantic-unit-{id}")],
                vec![UasAddress::new(
                    UasKind::Other(format!("transport_trace_unit_{id}")),
                    id.as_bytes(),
                    CREATED_AT_MS,
                )],
                "zstd",
                format!("sha256:{id}"),
                ColdStreamDestination::CpuSlab,
                ColdStreamPriority::Urgent,
                ColdStreamCachePolicy::NoCache,
                format!("lease:{id}"),
                format!("compat:{id}"),
            )?],
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

    fn trace(
        manifest: &ColdStreamTransportManifest,
        trace_id: &str,
    ) -> Result<ColdStreamTransportTrace, crate::uas::ColdStreamError> {
        ColdStreamTransportTrace::new(
            manifest,
            trace_id,
            manifest.planned_bytes(),
            manifest.planned_bytes() + 4096,
            manifest.planned_bytes(),
            2,
            1,
            11,
            19,
            10_312,
            false,
            true,
            &manifest.run_event_log_ref,
            &manifest.answer_packet_ref,
        )
    }
}
