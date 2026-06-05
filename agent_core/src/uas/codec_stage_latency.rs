//! Codec stage latency contracts.
//!
//! This is a metadata-only witness for the ColdStream decode/convert stage. It
//! proves file-read timing, decode/convert timing, checksums, and copy counts
//! are recorded as separate evidence before any live transport route promotes.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const CODEC_STAGE_LATENCY_CURSOR: &str = "codec_stage_latency";
pub const CODEC_STAGE_LATENCY_NEXT_CURSOR: &str = "transport_cancellation";

const INPUT_RUN_PREFIX: &str = "page_run:";
const READ_TRACE_PREFIX: &str = "read_trace:";
const CODEC_LATENCY_TRACE_PREFIX: &str = "codec_latency:";
const CODEC_KERNEL_PREFIX: &str = "codec_kernel:";
const METAL_KERNEL_PREFIX: &str = "metal_kernel:";
const OUTPUT_SLAB_PREFIX: &str = "cpu_slab:";
const METAL_BUFFER_LEASE_PREFIX: &str = "metal_buffer_lease:";
const CHECKSUM_PREFIX: &str = "sha256:";
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
const MAX_EXPECTED_COPY_COUNT: u32 = 2;
const MIN_LATENCY_SUCCESS_BPS: u32 = 9_500;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:codec-stage-latency:lane
// Plane: Assembly
// Residency: metadata-only decode/convert lane; no runtime bytes are loaded.
pub enum CodecStageLane {
    CpuDecode,
    MetalDecode,
    ConversionOnly,
}

impl CodecStageLane {
    fn tag(&self) -> &'static str {
        match self {
            Self::CpuDecode => "cpu_decode",
            Self::MetalDecode => "metal_decode",
            Self::ConversionOnly => "conversion_only",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:codec-stage-latency:error
// Plane: Verification
// Residency: metadata-only rejection taxonomy.
pub enum CodecStageLatencyError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyStage,
    EmptySurface,
    DuplicateStage(String),
    DuplicateSurface(String),
    DuplicateAnswerPacket(String),
    MissingCodec(String),
    MissingInputRun(String),
    MissingReadTrace(String),
    MissingCodecLatencyTrace(String),
    MissingKernelRef(String),
    MissingOutputSlab(String),
    MissingChecksum(String),
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
    ZeroInputBytes(String),
    ZeroDecodedBytes(String),
    MissingDecodeOrConversionLatency(String),
    ReadLatencyNotSeparated(String),
    CopyCountExceeded(String),
    ExpectedCopyBudgetExceeded(String),
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

impl fmt::Display for CodecStageLatencyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyStage => write!(f, "missing codec stage"),
            Self::EmptySurface => write!(f, "missing visible surface"),
            Self::DuplicateStage(id) => write!(f, "duplicate codec stage `{id}`"),
            Self::DuplicateSurface(id) => write!(f, "duplicate visible surface `{id}`"),
            Self::DuplicateAnswerPacket(id) => write!(f, "duplicate AnswerPacket `{id}`"),
            Self::MissingCodec(id) => write!(f, "`{id}` missing codec"),
            Self::MissingInputRun(id) => write!(f, "`{id}` missing input run"),
            Self::MissingReadTrace(id) => write!(f, "`{id}` missing read trace"),
            Self::MissingCodecLatencyTrace(id) => {
                write!(f, "`{id}` missing codec latency trace")
            }
            Self::MissingKernelRef(id) => write!(f, "`{id}` missing codec kernel ref"),
            Self::MissingOutputSlab(id) => write!(f, "`{id}` missing output slab"),
            Self::MissingChecksum(id) => write!(f, "`{id}` missing checksum"),
            Self::MissingAnswerPacket(id) => write!(f, "`{id}` missing AnswerPacket ref"),
            Self::MissingRunEventLog(id) => write!(f, "`{id}` missing RunEventLog ref"),
            Self::MissingRollback(id) => write!(f, "`{id}` missing rollback ref"),
            Self::MissingAdmission => write!(f, "missing admission ref"),
            Self::MissingScopeRex => write!(f, "missing SCOPE-Rex ref"),
            Self::MissingSovereignGate => write!(f, "missing SovereignGate ref"),
            Self::MissingCompatibilityFence(id) => write!(f, "`{id}` missing compatibility fence"),
            Self::MissingCancelGroup(id) => write!(f, "`{id}` missing cancel group"),
            Self::MissingVisibleCaveat(id) => write!(f, "`{id}` missing visible caveat"),
            Self::MissingRequiredMarker(marker) => write!(f, "missing marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}`"),
            Self::ZeroInputBytes(id) => write!(f, "`{id}` has zero input bytes"),
            Self::ZeroDecodedBytes(id) => write!(f, "`{id}` has zero decoded bytes"),
            Self::MissingDecodeOrConversionLatency(id) => {
                write!(f, "`{id}` missing decode or conversion latency")
            }
            Self::ReadLatencyNotSeparated(id) => {
                write!(f, "`{id}` mixed read latency with codec latency")
            }
            Self::CopyCountExceeded(id) => write!(f, "`{id}` exceeded expected copy count"),
            Self::ExpectedCopyBudgetExceeded(id) => {
                write!(f, "`{id}` expected copy budget exceeded")
            }
            Self::MissingLayerSeparation => write!(f, "L1/L2/L3 separation missing"),
            Self::ProductStatusMismatch => write!(f, "product status promoted beyond Pro Research"),
            Self::HiddenRouteAuthority => write!(f, "hidden route authority attempted"),
            Self::RoutePolicyMutation => write!(f, "route policy mutation attempted"),
            Self::GateBypass => write!(f, "codec gate bypass attempted"),
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

impl std::error::Error for CodecStageLatencyError {}

#[derive(Clone, Debug)]
// UAS: uas:codec-stage-latency:stage
// Plane: Assembly
// Residency: metadata-only codec stage record with separate read/decode timing.
pub struct CodecStageRecord {
    pub stage_id: String,
    pub mission_id: String,
    pub codec: String,
    pub lane: CodecStageLane,
    pub input_run_ref: String,
    pub file_read_trace_ref: String,
    pub codec_latency_trace_ref: String,
    pub kernel_ref: String,
    pub output_slab_ref: String,
    pub checksum_after_decode: String,
    pub input_bytes: u64,
    pub decoded_bytes: u64,
    pub file_read_latency_ms: u64,
    pub decode_latency_ms: u64,
    pub conversion_latency_ms: u64,
    pub observed_copy_count: u32,
    pub expected_copy_count: u32,
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

impl CodecStageRecord {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        stage_id: impl Into<String>,
        mission_id: impl Into<String>,
        codec: impl Into<String>,
        lane: CodecStageLane,
        input_run_ref: impl Into<String>,
        file_read_trace_ref: impl Into<String>,
        codec_latency_trace_ref: impl Into<String>,
        kernel_ref: impl Into<String>,
        output_slab_ref: impl Into<String>,
        checksum_after_decode: impl Into<String>,
        input_bytes: u64,
        decoded_bytes: u64,
        file_read_latency_ms: u64,
        decode_latency_ms: u64,
        conversion_latency_ms: u64,
        observed_copy_count: u32,
        expected_copy_count: u32,
        answer_packet_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        admission_ref: impl Into<String>,
        scope_rex_ref: impl Into<String>,
        sovereign_gate_ref: impl Into<String>,
        compatibility_fence: impl Into<String>,
        cancel_group_ref: impl Into<String>,
        visible_caveat: impl Into<String>,
    ) -> Result<Self, CodecStageLatencyError> {
        let record = Self {
            stage_id: stage_id.into(),
            mission_id: mission_id.into(),
            codec: codec.into(),
            lane,
            input_run_ref: input_run_ref.into(),
            file_read_trace_ref: file_read_trace_ref.into(),
            codec_latency_trace_ref: codec_latency_trace_ref.into(),
            kernel_ref: kernel_ref.into(),
            output_slab_ref: output_slab_ref.into(),
            checksum_after_decode: checksum_after_decode.into(),
            input_bytes,
            decoded_bytes,
            file_read_latency_ms,
            decode_latency_ms,
            conversion_latency_ms,
            observed_copy_count,
            expected_copy_count,
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
        validate_stage(&record)?;
        Ok(record)
    }

    fn stage_latency_ms(&self) -> u64 {
        self.decode_latency_ms
            .saturating_add(self.conversion_latency_ms)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:codec-stage-latency:surface
// Plane: Verification
// Residency: visible metadata-only codec caveat surface.
pub struct CodecStageSurface {
    pub surface_id: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub visible_summary: String,
}

impl CodecStageSurface {
    pub fn new(
        surface_id: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        visible_summary: impl Into<String>,
    ) -> Result<Self, CodecStageLatencyError> {
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
// UAS: uas:codec-stage-latency:metrics
// Plane: Verification
// Residency: metadata-only aggregate.
pub struct CodecStageLatencyMetrics {
    pub stage_count: usize,
    pub surface_count: usize,
    pub answer_packet_count: usize,
    pub run_event_log_count: usize,
    pub codec_count: usize,
    pub total_input_bytes: u64,
    pub total_decoded_bytes: u64,
    pub max_file_read_latency_ms: u64,
    pub max_codec_stage_latency_ms: u64,
    pub max_decode_latency_ms: u64,
    pub max_conversion_latency_ms: u64,
    pub max_observed_copy_count: u32,
    pub max_expected_copy_count: u32,
}

#[derive(Clone, Debug)]
// UAS: uas:codec-stage-latency:witness
// Plane: Verification
// Residency: metadata-only; live transport/model/runtime bytes must stay zero.
pub struct CodecStageLatencyWitness {
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub latency_success_bps: u32,
    pub mixed_read_decode_baseline_bps: u32,
    pub unchecked_decode_baseline_bps: u32,
    pub hidden_copy_baseline_bps: u32,
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
    pub stages: Vec<CodecStageRecord>,
    pub surfaces: Vec<CodecStageSurface>,
}

impl CodecStageLatencyWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        latency_success_bps: u32,
        mixed_read_decode_baseline_bps: u32,
        unchecked_decode_baseline_bps: u32,
        hidden_copy_baseline_bps: u32,
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
        stages: Vec<CodecStageRecord>,
        surfaces: Vec<CodecStageSurface>,
    ) -> Result<Self, CodecStageLatencyError> {
        let witness = Self {
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            latency_success_bps,
            mixed_read_decode_baseline_bps,
            unchecked_decode_baseline_bps,
            hidden_copy_baseline_bps,
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
            stages,
            surfaces,
        };
        validate_witness(&witness)?;
        Ok(witness)
    }

    pub fn metrics(&self) -> CodecStageLatencyMetrics {
        let mut answer_packets = BTreeSet::new();
        let mut run_event_logs = BTreeSet::new();
        let mut codecs = BTreeSet::new();
        let mut metrics = CodecStageLatencyMetrics {
            stage_count: self.stages.len(),
            surface_count: self.surfaces.len(),
            ..CodecStageLatencyMetrics::default()
        };
        for stage in &self.stages {
            answer_packets.insert(stage.answer_packet_ref.clone());
            run_event_logs.insert(stage.run_event_log_ref.clone());
            codecs.insert(stage.codec.clone());
            metrics.total_input_bytes = metrics.total_input_bytes.saturating_add(stage.input_bytes);
            metrics.total_decoded_bytes = metrics
                .total_decoded_bytes
                .saturating_add(stage.decoded_bytes);
            metrics.max_file_read_latency_ms = metrics
                .max_file_read_latency_ms
                .max(stage.file_read_latency_ms);
            metrics.max_codec_stage_latency_ms = metrics
                .max_codec_stage_latency_ms
                .max(stage.stage_latency_ms());
            metrics.max_decode_latency_ms =
                metrics.max_decode_latency_ms.max(stage.decode_latency_ms);
            metrics.max_conversion_latency_ms = metrics
                .max_conversion_latency_ms
                .max(stage.conversion_latency_ms);
            metrics.max_observed_copy_count = metrics
                .max_observed_copy_count
                .max(stage.observed_copy_count);
            metrics.max_expected_copy_count = metrics
                .max_expected_copy_count
                .max(stage.expected_copy_count);
        }
        for surface in &self.surfaces {
            answer_packets.insert(surface.answer_packet_ref.clone());
            run_event_logs.insert(surface.run_event_log_ref.clone());
        }
        metrics.answer_packet_count = answer_packets.len();
        metrics.run_event_log_count = run_event_logs.len();
        metrics.codec_count = codecs.len();
        metrics
    }

    pub fn address(&self) -> String {
        let mut stage_parts = self
            .stages
            .iter()
            .map(|stage| {
                format!(
                    "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
                    stage.stage_id,
                    stage.mission_id,
                    stage.codec,
                    stage.lane.tag(),
                    stage.input_run_ref,
                    stage.file_read_trace_ref,
                    stage.codec_latency_trace_ref,
                    stage.kernel_ref,
                    stage.output_slab_ref,
                    stage.checksum_after_decode,
                    stage.input_bytes,
                    stage.decoded_bytes,
                    stage.file_read_latency_ms,
                    stage.stage_latency_ms(),
                    stage.observed_copy_count
                )
            })
            .collect::<Vec<_>>();
        stage_parts.sort();
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
                self.latency_success_bps,
                self.mixed_read_decode_baseline_bps,
                self.unchecked_decode_baseline_bps,
                stage_parts.join(";;"),
                surface_parts.join(";;")
            )
            .as_bytes(),
        );
        format!("uas:codec-stage-latency:{digest}")
    }
}

fn validate_witness(witness: &CodecStageLatencyWitness) -> Result<(), CodecStageLatencyError> {
    if witness.product_build != ProductBuild::Pro
        || witness.pro_status != ProStatus::ResearchCandidate
        || witness.route_authority != "codec_stage_only"
    {
        return Err(CodecStageLatencyError::ProductStatusMismatch);
    }
    if witness.stages.is_empty() {
        return Err(CodecStageLatencyError::EmptyStage);
    }
    if witness.surfaces.is_empty() {
        return Err(CodecStageLatencyError::EmptySurface);
    }
    let mut stage_ids = HashSet::with_capacity(witness.stages.len());
    let mut surface_ids = HashSet::with_capacity(witness.surfaces.len());
    let mut answer_packets = HashSet::with_capacity(witness.stages.len() + witness.surfaces.len());
    for stage in &witness.stages {
        validate_stage(stage)?;
        if !stage_ids.insert(stage.stage_id.clone()) {
            return Err(CodecStageLatencyError::DuplicateStage(
                stage.stage_id.clone(),
            ));
        }
        if !answer_packets.insert(stage.answer_packet_ref.clone()) {
            return Err(CodecStageLatencyError::DuplicateAnswerPacket(
                stage.answer_packet_ref.clone(),
            ));
        }
        if !contains_layer_separation(&stage.visible_caveat) {
            return Err(CodecStageLatencyError::MissingLayerSeparation);
        }
    }
    for surface in &witness.surfaces {
        validate_surface(surface)?;
        if !surface_ids.insert(surface.surface_id.clone()) {
            return Err(CodecStageLatencyError::DuplicateSurface(
                surface.surface_id.clone(),
            ));
        }
        if !contains_layer_separation(&surface.visible_summary) {
            return Err(CodecStageLatencyError::MissingLayerSeparation);
        }
    }
    if witness.hidden_route_authority {
        return Err(CodecStageLatencyError::HiddenRouteAuthority);
    }
    if witness.route_policy_mutation {
        return Err(CodecStageLatencyError::RoutePolicyMutation);
    }
    if witness.gate_bypass {
        return Err(CodecStageLatencyError::GateBypass);
    }
    if witness.answer_packet_suppression {
        return Err(CodecStageLatencyError::AnswerPacketSuppression);
    }
    if witness.hidden_chain_exposed {
        return Err(CodecStageLatencyError::HiddenChainExposure);
    }
    if witness.hidden_cloud_route {
        return Err(CodecStageLatencyError::HiddenCloudRoute);
    }
    if witness.ssd_as_ram_claim {
        return Err(CodecStageLatencyError::SsdAsRamClaim);
    }
    if witness.mas_promotion_attempted {
        return Err(CodecStageLatencyError::MasPromotionAttempted);
    }
    if witness.live_benchmark_attempted {
        return Err(CodecStageLatencyError::LiveBenchmarkAttempted);
    }
    if witness.runtime_bytes_loaded != 0 {
        return Err(CodecStageLatencyError::RuntimeBytesLoaded);
    }
    if witness.model_bytes_loaded != 0 {
        return Err(CodecStageLatencyError::ModelBytesLoaded);
    }
    if witness.transport_runtime_bytes_loaded != 0 {
        return Err(CodecStageLatencyError::TransportRuntimeBytesLoaded);
    }
    if witness.max_metadata_bytes > MAX_METADATA_BYTES {
        return Err(CodecStageLatencyError::MetadataBudgetExceeded);
    }
    if witness.latency_success_bps < MIN_LATENCY_SUCCESS_BPS {
        return Err(CodecStageLatencyError::BaselineUnbeaten("latency_success"));
    }
    for (name, baseline) in [
        ("mixed_read_decode", witness.mixed_read_decode_baseline_bps),
        ("unchecked_decode", witness.unchecked_decode_baseline_bps),
        ("hidden_copy", witness.hidden_copy_baseline_bps),
        ("live_authority", witness.live_authority_baseline_bps),
    ] {
        if witness.latency_success_bps <= baseline {
            return Err(CodecStageLatencyError::BaselineUnbeaten(name));
        }
    }
    Ok(())
}

fn validate_stage(stage: &CodecStageRecord) -> Result<(), CodecStageLatencyError> {
    validate_nonempty_clean("stage_id", &stage.stage_id)?;
    validate_nonempty_clean("mission_id", &stage.mission_id)?;
    validate_nonempty_clean("codec", &stage.codec)?;
    validate_nonempty_clean("visible_caveat", &stage.visible_caveat)?;
    if stage.codec.trim().is_empty() {
        return Err(CodecStageLatencyError::MissingCodec(stage.stage_id.clone()));
    }
    validate_prefixed(
        "input_run_ref",
        &stage.input_run_ref,
        INPUT_RUN_PREFIX,
        CodecStageLatencyError::MissingInputRun(stage.stage_id.clone()),
    )?;
    validate_prefixed(
        "file_read_trace_ref",
        &stage.file_read_trace_ref,
        READ_TRACE_PREFIX,
        CodecStageLatencyError::MissingReadTrace(stage.stage_id.clone()),
    )?;
    validate_prefixed(
        "codec_latency_trace_ref",
        &stage.codec_latency_trace_ref,
        CODEC_LATENCY_TRACE_PREFIX,
        CodecStageLatencyError::MissingCodecLatencyTrace(stage.stage_id.clone()),
    )?;
    validate_kernel_ref(stage)?;
    validate_output_ref(stage)?;
    validate_prefixed(
        "checksum_after_decode",
        &stage.checksum_after_decode,
        CHECKSUM_PREFIX,
        CodecStageLatencyError::MissingChecksum(stage.stage_id.clone()),
    )?;
    validate_prefixed(
        "answer_packet_ref",
        &stage.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
        CodecStageLatencyError::MissingAnswerPacket(stage.stage_id.clone()),
    )?;
    validate_prefixed(
        "run_event_log_ref",
        &stage.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
        CodecStageLatencyError::MissingRunEventLog(stage.stage_id.clone()),
    )?;
    validate_prefixed(
        "rollback_ref",
        &stage.rollback_ref,
        ROLLBACK_PREFIX,
        CodecStageLatencyError::MissingRollback(stage.stage_id.clone()),
    )?;
    validate_prefixed(
        "admission_ref",
        &stage.admission_ref,
        ADMISSION_PREFIX,
        CodecStageLatencyError::MissingAdmission,
    )?;
    validate_prefixed(
        "scope_rex_ref",
        &stage.scope_rex_ref,
        SCOPE_REX_PREFIX,
        CodecStageLatencyError::MissingScopeRex,
    )?;
    validate_prefixed(
        "sovereign_gate_ref",
        &stage.sovereign_gate_ref,
        SOVEREIGN_GATE_PREFIX,
        CodecStageLatencyError::MissingSovereignGate,
    )?;
    validate_prefixed(
        "compatibility_fence",
        &stage.compatibility_fence,
        COMPATIBILITY_FENCE_PREFIX,
        CodecStageLatencyError::MissingCompatibilityFence(stage.stage_id.clone()),
    )?;
    validate_prefixed(
        "cancel_group_ref",
        &stage.cancel_group_ref,
        CANCEL_GROUP_PREFIX,
        CodecStageLatencyError::MissingCancelGroup(stage.stage_id.clone()),
    )?;
    if stage.input_bytes == 0 {
        return Err(CodecStageLatencyError::ZeroInputBytes(
            stage.stage_id.clone(),
        ));
    }
    if stage.decoded_bytes == 0 {
        return Err(CodecStageLatencyError::ZeroDecodedBytes(
            stage.stage_id.clone(),
        ));
    }
    if stage.stage_latency_ms() == 0 {
        return Err(CodecStageLatencyError::MissingDecodeOrConversionLatency(
            stage.stage_id.clone(),
        ));
    }
    if stage.file_read_latency_ms == 0
        || stage.file_read_trace_ref == stage.codec_latency_trace_ref
        || stage.visible_caveat.contains("read+decode")
    {
        return Err(CodecStageLatencyError::ReadLatencyNotSeparated(
            stage.stage_id.clone(),
        ));
    }
    if stage.observed_copy_count > stage.expected_copy_count {
        return Err(CodecStageLatencyError::CopyCountExceeded(
            stage.stage_id.clone(),
        ));
    }
    if stage.expected_copy_count > MAX_EXPECTED_COPY_COUNT {
        return Err(CodecStageLatencyError::ExpectedCopyBudgetExceeded(
            stage.stage_id.clone(),
        ));
    }
    for marker in [
        "metadata-only",
        "read separate",
        "codec latency",
        "copy count",
    ] {
        if !stage.visible_caveat.contains(marker) {
            return Err(CodecStageLatencyError::MissingRequiredMarker(
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
        if stage.visible_caveat.contains(marker) {
            return Err(CodecStageLatencyError::ForbiddenMarker(marker.to_string()));
        }
    }
    Ok(())
}

fn validate_surface(surface: &CodecStageSurface) -> Result<(), CodecStageLatencyError> {
    validate_nonempty_clean("surface_id", &surface.surface_id)?;
    validate_nonempty_clean("visible_summary", &surface.visible_summary)?;
    validate_prefixed(
        "answer_packet_ref",
        &surface.answer_packet_ref,
        ANSWER_PACKET_PREFIX,
        CodecStageLatencyError::MissingAnswerPacket(surface.surface_id.clone()),
    )?;
    validate_prefixed(
        "run_event_log_ref",
        &surface.run_event_log_ref,
        RUN_EVENT_LOG_PREFIX,
        CodecStageLatencyError::MissingRunEventLog(surface.surface_id.clone()),
    )?;
    if surface.visible_summary.len() < MIN_VISIBLE_CAVEAT_BYTES {
        return Err(CodecStageLatencyError::MissingVisibleCaveat(
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
    ] {
        if !surface.visible_summary.contains(marker) {
            return Err(CodecStageLatencyError::MissingRequiredMarker(
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
            return Err(CodecStageLatencyError::ForbiddenMarker(marker.to_string()));
        }
    }
    Ok(())
}

fn validate_kernel_ref(stage: &CodecStageRecord) -> Result<(), CodecStageLatencyError> {
    validate_nonempty_clean("kernel_ref", &stage.kernel_ref)?;
    let ok = match stage.lane {
        CodecStageLane::CpuDecode | CodecStageLane::ConversionOnly => {
            stage.kernel_ref.starts_with(CODEC_KERNEL_PREFIX)
        }
        CodecStageLane::MetalDecode => stage.kernel_ref.starts_with(METAL_KERNEL_PREFIX),
    };
    if ok {
        Ok(())
    } else {
        Err(CodecStageLatencyError::MissingKernelRef(
            stage.stage_id.clone(),
        ))
    }
}

fn validate_output_ref(stage: &CodecStageRecord) -> Result<(), CodecStageLatencyError> {
    validate_nonempty_clean("output_slab_ref", &stage.output_slab_ref)?;
    let ok = match stage.lane {
        CodecStageLane::CpuDecode | CodecStageLane::ConversionOnly => {
            stage.output_slab_ref.starts_with(OUTPUT_SLAB_PREFIX)
        }
        CodecStageLane::MetalDecode => stage.output_slab_ref.starts_with(METAL_BUFFER_LEASE_PREFIX),
    };
    if ok {
        Ok(())
    } else {
        Err(CodecStageLatencyError::MissingOutputSlab(
            stage.stage_id.clone(),
        ))
    }
}

fn validate_nonempty_clean(field: &'static str, value: &str) -> Result<(), CodecStageLatencyError> {
    if value.is_empty() {
        return Err(CodecStageLatencyError::MissingField(field));
    }
    if value.trim() != value {
        return Err(CodecStageLatencyError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(char::is_control) {
        return Err(CodecStageLatencyError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

fn validate_prefixed(
    field: &'static str,
    value: &str,
    prefix: &str,
    missing: CodecStageLatencyError,
) -> Result<(), CodecStageLatencyError> {
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

    fn visible_caveat() -> String {
        "metadata-only codec latency: read separate from codec latency, copy count visible in AnswerPacket, rollback bound, L1 only; L2 and L3 unchanged"
            .to_string()
    }

    fn stage(id: &str, lane: CodecStageLane) -> Result<CodecStageRecord, CodecStageLatencyError> {
        let (kernel, output) = match lane {
            CodecStageLane::MetalDecode => (
                format!("metal_kernel:{id}:decode"),
                format!("metal_buffer_lease:{id}:out"),
            ),
            _ => (
                format!("codec_kernel:{id}:decode"),
                format!("cpu_slab:{id}:out"),
            ),
        };
        CodecStageRecord::new(
            id,
            "mission:coldstream-codec",
            "zstd-q4",
            lane,
            format!("page_run:{id}:input"),
            format!("read_trace:{id}:file"),
            format!("codec_latency:{id}:decode"),
            kernel,
            output,
            format!("sha256:{id}abc123"),
            4096,
            8192,
            4,
            7,
            2,
            1,
            1,
            format!("answer_packet:{id}"),
            format!("run_event_log:{id}"),
            format!("rollback:{id}"),
            "admission:codec-stage",
            "scope_rex:codec-stage",
            "sovereign_gate:codec-stage",
            format!("compat:{id}:v1"),
            format!("cancel_group:{id}"),
            visible_caveat(),
        )
    }

    fn surface(id: &str) -> Result<CodecStageSurface, CodecStageLatencyError> {
        CodecStageSurface::new(
            id,
            format!("answer_packet:surface:{id}"),
            format!("run_event_log:surface:{id}"),
            "metadata-only CodecStage surface: L1 records read separate codec latency, copy count, checksum, AnswerPacket and rollback; L2 route and L3 runtime unchanged."
        )
    }

    fn witness() -> Result<CodecStageLatencyWitness, CodecStageLatencyError> {
        CodecStageLatencyWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "codec_stage_only",
            9_650,
            8_000,
            8_200,
            8_400,
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
                stage("stage-a", CodecStageLane::CpuDecode)?,
                stage("stage-b", CodecStageLane::ConversionOnly)?,
                stage("stage-c", CodecStageLane::MetalDecode)?,
            ],
            vec![surface("surface-a")?, surface("surface-b")?],
        )
    }

    #[test]
    fn valid_witness_separates_read_decode_and_copy_counts() {
        let witness = witness().expect("fixture witness");
        let metrics = witness.metrics();
        assert_eq!(metrics.stage_count, 3);
        assert_eq!(metrics.surface_count, 2);
        assert_eq!(metrics.max_observed_copy_count, 1);
        assert_eq!(metrics.max_expected_copy_count, 1);
        assert_eq!(metrics.codec_count, 1);
    }

    #[test]
    fn address_is_deterministic_under_stage_order() {
        let witness = witness().expect("fixture witness");
        let address = witness.address();
        let mut reversed = witness.stages.clone();
        reversed.reverse();
        let reordered = CodecStageLatencyWitness::new(
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "codec_stage_only",
            witness.latency_success_bps,
            witness.mixed_read_decode_baseline_bps,
            witness.unchecked_decode_baseline_bps,
            witness.hidden_copy_baseline_bps,
            witness.live_authority_baseline_bps,
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
        assert_eq!(address, reordered.address());
    }

    #[test]
    fn rejects_mixed_read_decode_hidden_authority_and_runtime_bytes() {
        let mut stage = stage("bad", CodecStageLane::CpuDecode).expect("stage");
        stage.file_read_latency_ms = 0;
        assert!(matches!(
            CodecStageLatencyWitness::new(
                ProductBuild::Pro,
                ProStatus::ResearchCandidate,
                "codec_stage_only",
                9_650,
                8_000,
                8_200,
                8_400,
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
                vec![stage],
                vec![surface("surface").expect("surface")]
            ),
            Err(CodecStageLatencyError::ReadLatencyNotSeparated(_))
        ));

        let mut hidden = witness().expect("fixture witness");
        hidden.hidden_route_authority = true;
        assert!(matches!(
            CodecStageLatencyWitness::new(
                hidden.product_build,
                hidden.pro_status,
                hidden.route_authority,
                hidden.latency_success_bps,
                hidden.mixed_read_decode_baseline_bps,
                hidden.unchecked_decode_baseline_bps,
                hidden.hidden_copy_baseline_bps,
                hidden.live_authority_baseline_bps,
                0,
                0,
                1,
                hidden.max_metadata_bytes,
                hidden.hidden_route_authority,
                hidden.route_policy_mutation,
                hidden.gate_bypass,
                hidden.answer_packet_suppression,
                hidden.hidden_chain_exposed,
                hidden.hidden_cloud_route,
                hidden.ssd_as_ram_claim,
                hidden.mas_promotion_attempted,
                hidden.live_benchmark_attempted,
                hidden.stages,
                hidden.surfaces
            ),
            Err(CodecStageLatencyError::HiddenRouteAuthority)
        ));
    }
}
