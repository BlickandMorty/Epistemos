//! Small-model runtime harness product WRV probe.
//!
//! This L1/L3-source witness proves that the retained small-model runtime
//! evidence is wired into the app's product route surfaces with WRV source
//! evidence. It remains metadata/source proof only: it does not load MLX, open
//! model bytes, promote MAS live-agent claims, or mark the capability kernel
//! green.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR: &str =
    "small_model_runtime_harness_product_wrv_probe";
pub const SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_product_answer_packet_live_probe";
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";

const ANSWER_PACKET_ARTIFACT_PREFIX: &str =
    "artifact:small_model_runtime_harness_answer_packet_runtime_probe:";
const SOURCE_PREFIX: &str = "source:";
const TEST_PREFIX: &str = "test:";
const SURFACE_PREFIX: &str = "surface:";
const ADMISSION_PREFIX: &str = "admission:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const COMPATIBILITY_PREFIX: &str = "compat:";
const PRIVACY_PREFIX: &str = "privacy:";
const BUDGET_PREFIX: &str = "budget:";
const MIN_MARKERS_PER_REF: usize = 2;
const MAX_METADATA_BYTES: u64 = 768 * 1024;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-product-wrv-probe:phase
// Plane: Controller + Verification
// Residency: source-level product route WRV phase.
pub enum SmallModelProductWrvPhase {
    TriagePolicyWired,
    LocalGatewayWired,
    NoteChatReachable,
    SerialControllerBound,
    AnswerPacketEmitterBound,
    RunEventLogBound,
    SettingsVisibilityBound,
    MessagePacketVisibilityBound,
    TriagePolicyVerified,
    SerialControllerVerified,
    AnswerPacketVerified,
    CapabilityHonestyBound,
}

impl SmallModelProductWrvPhase {
    pub fn tag(&self) -> &'static str {
        match self {
            Self::TriagePolicyWired => "triage_policy_wired",
            Self::LocalGatewayWired => "local_gateway_wired",
            Self::NoteChatReachable => "note_chat_reachable",
            Self::SerialControllerBound => "serial_controller_bound",
            Self::AnswerPacketEmitterBound => "answer_packet_emitter_bound",
            Self::RunEventLogBound => "run_event_log_bound",
            Self::SettingsVisibilityBound => "settings_visibility_bound",
            Self::MessagePacketVisibilityBound => "message_packet_visibility_bound",
            Self::TriagePolicyVerified => "triage_policy_verified",
            Self::SerialControllerVerified => "serial_controller_verified",
            Self::AnswerPacketVerified => "answer_packet_verified",
            Self::CapabilityHonestyBound => "capability_honesty_bound",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-product-wrv-probe:error
// Plane: Verification
// Residency: source/product WRV rejection taxonomy.
pub enum SmallModelProductWrvProbeError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptySourceRef,
    EmptySurface,
    EmptyTestRef,
    EmptyPhase,
    DuplicateSourceRef(String),
    DuplicateSurface(String),
    DuplicateTestRef(String),
    MissingMarker(String),
    MissingPhase(&'static str),
    MissingWrvAxis(&'static str),
    ProductStatusMismatch,
    CapabilityStatusMismatch,
    GuardCursorMismatch,
    MissingAnswerPacketArtifact(String),
    MissingAdmission(String),
    MissingRollback(String),
    MissingAnswerPacket(String),
    MissingRunEventLog(String),
    MissingCompatibilityFence(String),
    MissingPrivacyFence(String),
    MissingBudget(String),
    HiddenRouteAuthority(String),
    HiddenCloudFallback(String),
    HiddenChainExposure(String),
    RoutePolicyMutation(String),
    GateBypass(String),
    AnswerPacketSuppressed(String),
    AppPathSubprocessSpawn(String),
    AutogenousKernelAttempt(String),
    SeventyBProductClaim(String),
    LongContextShardProductClaim(String),
    MasLiveAgentOverclaim,
    L2GreenClaimAttempted,
    L3RuntimeGreenClaimAttempted,
    RuntimeBytesLoaded,
    ModelBytesLoaded,
    MetadataBudgetExceeded,
}

impl fmt::Display for SmallModelProductWrvProbeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptySourceRef => write!(f, "missing source refs"),
            Self::EmptySurface => write!(f, "missing product surfaces"),
            Self::EmptyTestRef => write!(f, "missing verification test refs"),
            Self::EmptyPhase => write!(f, "missing WRV phases"),
            Self::DuplicateSourceRef(id) => write!(f, "duplicate source ref `{id}`"),
            Self::DuplicateSurface(id) => write!(f, "duplicate surface `{id}`"),
            Self::DuplicateTestRef(id) => write!(f, "duplicate test ref `{id}`"),
            Self::MissingMarker(id) => write!(f, "ref `{id}` is missing required markers"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::MissingWrvAxis(axis) => write!(f, "missing WRV axis `{axis}`"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::MissingAnswerPacketArtifact(id) => {
                write!(f, "witness `{id}` missing upstream AnswerPacket artifact")
            }
            Self::MissingAdmission(id) => write!(f, "surface `{id}` missing admission ref"),
            Self::MissingRollback(id) => write!(f, "surface `{id}` missing rollback ref"),
            Self::MissingAnswerPacket(id) => write!(f, "surface `{id}` missing AnswerPacket ref"),
            Self::MissingRunEventLog(id) => write!(f, "surface `{id}` missing RunEventLog ref"),
            Self::MissingCompatibilityFence(id) => {
                write!(f, "surface `{id}` missing compatibility fence")
            }
            Self::MissingPrivacyFence(id) => write!(f, "surface `{id}` missing privacy fence"),
            Self::MissingBudget(id) => write!(f, "surface `{id}` missing budget ref"),
            Self::HiddenRouteAuthority(id) => {
                write!(f, "surface `{id}` has hidden route authority")
            }
            Self::HiddenCloudFallback(id) => {
                write!(f, "surface `{id}` allows hidden cloud fallback")
            }
            Self::HiddenChainExposure(id) => write!(f, "surface `{id}` exposes hidden chain"),
            Self::RoutePolicyMutation(id) => write!(f, "surface `{id}` mutates route policy"),
            Self::GateBypass(id) => write!(f, "surface `{id}` bypasses admission gate"),
            Self::AnswerPacketSuppressed(id) => write!(f, "surface `{id}` suppresses AnswerPacket"),
            Self::AppPathSubprocessSpawn(id) => write!(f, "surface `{id}` spawns subprocesses"),
            Self::AutogenousKernelAttempt(id) => {
                write!(f, "surface `{id}` attempts autogenous kernel")
            }
            Self::SeventyBProductClaim(id) => write!(f, "surface `{id}` claims live 70B product"),
            Self::LongContextShardProductClaim(id) => {
                write!(f, "surface `{id}` claims live 128K shard product")
            }
            Self::MasLiveAgentOverclaim => write!(f, "MAS live-agent overclaim attempted"),
            Self::L2GreenClaimAttempted => write!(f, "L2 green claim attempted"),
            Self::L3RuntimeGreenClaimAttempted => write!(f, "L3 runtime green claim attempted"),
            Self::RuntimeBytesLoaded => write!(f, "runtime bytes loaded in source-only WRV probe"),
            Self::ModelBytesLoaded => write!(f, "model bytes loaded in source-only WRV probe"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for SmallModelProductWrvProbeError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-product-wrv-probe:source-ref
// Plane: Verification
// Residency: source marker proving one product route dependency.
pub struct SmallModelProductWrvSourceRef {
    pub ref_id: String,
    pub path: String,
    pub markers: Vec<String>,
}

impl SmallModelProductWrvSourceRef {
    pub fn validate(&self) -> Result<(), SmallModelProductWrvProbeError> {
        validate_prefixed_source("source_ref", &self.ref_id, SOURCE_PREFIX)?;
        validate_clean("path", &self.path)?;
        if self.markers.len() < MIN_MARKERS_PER_REF {
            return Err(SmallModelProductWrvProbeError::MissingMarker(
                self.ref_id.clone(),
            ));
        }
        for marker in &self.markers {
            validate_clean("marker", marker)?;
        }
        Ok(())
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-product-wrv-probe:test-ref
// Plane: Verification
// Residency: focused verification marker proving WRV tests exist.
pub struct SmallModelProductWrvTestRef {
    pub ref_id: String,
    pub path: String,
    pub markers: Vec<String>,
}

impl SmallModelProductWrvTestRef {
    pub fn validate(&self) -> Result<(), SmallModelProductWrvProbeError> {
        validate_prefixed_source("test_ref", &self.ref_id, TEST_PREFIX)?;
        validate_clean("path", &self.path)?;
        if self.markers.len() < MIN_MARKERS_PER_REF {
            return Err(SmallModelProductWrvProbeError::MissingMarker(
                self.ref_id.clone(),
            ));
        }
        for marker in &self.markers {
            validate_clean("marker", marker)?;
        }
        Ok(())
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-product-wrv-probe:surface
// Plane: Verification
// Residency: visible app surface and rollback/admission/packet contract.
pub struct SmallModelProductWrvSurface {
    pub surface_id: String,
    pub admission_ref: String,
    pub rollback_ref: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub compatibility_fence_ref: String,
    pub privacy_ref: String,
    pub budget_ref: String,
    pub visible: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub hidden_chain_exposed: bool,
    pub route_policy_mutated: bool,
    pub gate_bypassed: bool,
    pub answer_packet_suppressed: bool,
    pub subprocess_spawned_in_app_path: bool,
    pub autogenous_kernel_attempted: bool,
    pub seventy_b_product_claimed: bool,
    pub long_context_shard_product_claimed: bool,
}

impl SmallModelProductWrvSurface {
    pub fn validate(&self) -> Result<(), SmallModelProductWrvProbeError> {
        validate_prefixed_source("surface_id", &self.surface_id, SURFACE_PREFIX)?;
        validate_prefixed(
            &self.surface_id,
            &self.admission_ref,
            ADMISSION_PREFIX,
            SmallModelProductWrvProbeError::MissingAdmission,
        )?;
        validate_prefixed(
            &self.surface_id,
            &self.rollback_ref,
            ROLLBACK_PREFIX,
            SmallModelProductWrvProbeError::MissingRollback,
        )?;
        validate_prefixed(
            &self.surface_id,
            &self.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
            SmallModelProductWrvProbeError::MissingAnswerPacket,
        )?;
        validate_prefixed(
            &self.surface_id,
            &self.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
            SmallModelProductWrvProbeError::MissingRunEventLog,
        )?;
        validate_prefixed(
            &self.surface_id,
            &self.compatibility_fence_ref,
            COMPATIBILITY_PREFIX,
            SmallModelProductWrvProbeError::MissingCompatibilityFence,
        )?;
        validate_prefixed(
            &self.surface_id,
            &self.privacy_ref,
            PRIVACY_PREFIX,
            SmallModelProductWrvProbeError::MissingPrivacyFence,
        )?;
        validate_prefixed(
            &self.surface_id,
            &self.budget_ref,
            BUDGET_PREFIX,
            SmallModelProductWrvProbeError::MissingBudget,
        )?;
        if !self.visible {
            return Err(SmallModelProductWrvProbeError::MissingWrvAxis("visible"));
        }
        if self.hidden_route_authority {
            return Err(SmallModelProductWrvProbeError::HiddenRouteAuthority(
                self.surface_id.clone(),
            ));
        }
        if self.hidden_cloud_fallback {
            return Err(SmallModelProductWrvProbeError::HiddenCloudFallback(
                self.surface_id.clone(),
            ));
        }
        if self.hidden_chain_exposed {
            return Err(SmallModelProductWrvProbeError::HiddenChainExposure(
                self.surface_id.clone(),
            ));
        }
        if self.route_policy_mutated {
            return Err(SmallModelProductWrvProbeError::RoutePolicyMutation(
                self.surface_id.clone(),
            ));
        }
        if self.gate_bypassed {
            return Err(SmallModelProductWrvProbeError::GateBypass(
                self.surface_id.clone(),
            ));
        }
        if self.answer_packet_suppressed {
            return Err(SmallModelProductWrvProbeError::AnswerPacketSuppressed(
                self.surface_id.clone(),
            ));
        }
        if self.subprocess_spawned_in_app_path {
            return Err(SmallModelProductWrvProbeError::AppPathSubprocessSpawn(
                self.surface_id.clone(),
            ));
        }
        if self.autogenous_kernel_attempted {
            return Err(SmallModelProductWrvProbeError::AutogenousKernelAttempt(
                self.surface_id.clone(),
            ));
        }
        if self.seventy_b_product_claimed {
            return Err(SmallModelProductWrvProbeError::SeventyBProductClaim(
                self.surface_id.clone(),
            ));
        }
        if self.long_context_shard_product_claimed {
            return Err(
                SmallModelProductWrvProbeError::LongContextShardProductClaim(
                    self.surface_id.clone(),
                ),
            );
        }
        Ok(())
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-product-wrv-probe:metrics
// Plane: Verification
// Residency: aggregate product WRV source-proof metrics.
pub struct SmallModelProductWrvMetrics {
    pub source_ref_count: u64,
    pub source_marker_count: u64,
    pub surface_count: u64,
    pub test_ref_count: u64,
    pub test_marker_count: u64,
    pub phase_count: u64,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-product-wrv-probe:witness
// Plane: Controller + Verification
// Residency: source-level app WRV proof for small-model product routing.
pub struct SmallModelProductWrvWitness {
    pub witness_id: String,
    pub upstream_answer_packet_artifact_ref: String,
    pub guard_next_existing_work: String,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub source_refs: Vec<SmallModelProductWrvSourceRef>,
    pub surfaces: Vec<SmallModelProductWrvSurface>,
    pub test_refs: Vec<SmallModelProductWrvTestRef>,
    pub phases: Vec<SmallModelProductWrvPhase>,
    pub wired: bool,
    pub reachable: bool,
    pub visible: bool,
    pub verified: bool,
    pub l1_l2_l3_separated: bool,
    pub mas_live_agent_overclaim_attempted: bool,
    pub l2_green_claimed: bool,
    pub l3_runtime_green_claimed: bool,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub metadata_bytes: u64,
}

impl SmallModelProductWrvWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        upstream_answer_packet_artifact_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        source_refs: Vec<SmallModelProductWrvSourceRef>,
        surfaces: Vec<SmallModelProductWrvSurface>,
        test_refs: Vec<SmallModelProductWrvTestRef>,
        phases: Vec<SmallModelProductWrvPhase>,
        wired: bool,
        reachable: bool,
        visible: bool,
        verified: bool,
        l1_l2_l3_separated: bool,
        mas_live_agent_overclaim_attempted: bool,
        l2_green_claimed: bool,
        l3_runtime_green_claimed: bool,
        runtime_bytes_loaded: u64,
        model_bytes_loaded: u64,
        metadata_bytes: u64,
    ) -> Result<Self, SmallModelProductWrvProbeError> {
        let witness = Self {
            witness_id: witness_id.into(),
            upstream_answer_packet_artifact_ref: upstream_answer_packet_artifact_ref.into(),
            guard_next_existing_work: guard_next_existing_work.into(),
            capability_route_status: capability_route_status.into(),
            capability_next_bottleneck: capability_next_bottleneck.into(),
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            source_refs,
            surfaces,
            test_refs,
            phases,
            wired,
            reachable,
            visible,
            verified,
            l1_l2_l3_separated,
            mas_live_agent_overclaim_attempted,
            l2_green_claimed,
            l3_runtime_green_claimed,
            runtime_bytes_loaded,
            model_bytes_loaded,
            metadata_bytes,
        };
        witness.validate()?;
        Ok(witness)
    }

    pub fn validate(&self) -> Result<(), SmallModelProductWrvProbeError> {
        validate_clean("witness_id", &self.witness_id)?;
        validate_prefixed(
            &self.witness_id,
            &self.upstream_answer_packet_artifact_ref,
            ANSWER_PACKET_ARTIFACT_PREFIX,
            SmallModelProductWrvProbeError::MissingAnswerPacketArtifact,
        )?;
        if self.guard_next_existing_work != SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR
            && self.guard_next_existing_work
                != SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_NEXT_CURSOR
            && self.guard_next_existing_work != ADVANCED_RELEASE_AUDIT_CURSOR
        {
            return Err(SmallModelProductWrvProbeError::GuardCursorMismatch);
        }
        if self.capability_route_status != "vault_research_route_with_packetized_mitigation"
            || (self.capability_next_bottleneck
                != SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR
                && self.capability_next_bottleneck
                    != SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_NEXT_CURSOR
                && self.capability_next_bottleneck != ADVANCED_RELEASE_AUDIT_CURSOR)
        {
            return Err(SmallModelProductWrvProbeError::CapabilityStatusMismatch);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.route_authority != "source_wrv_only_no_live_route_authority"
        {
            return Err(SmallModelProductWrvProbeError::ProductStatusMismatch);
        }
        if self.source_refs.is_empty() {
            return Err(SmallModelProductWrvProbeError::EmptySourceRef);
        }
        if self.surfaces.is_empty() {
            return Err(SmallModelProductWrvProbeError::EmptySurface);
        }
        if self.test_refs.is_empty() {
            return Err(SmallModelProductWrvProbeError::EmptyTestRef);
        }
        if self.phases.is_empty() {
            return Err(SmallModelProductWrvProbeError::EmptyPhase);
        }
        let mut source_ids = HashSet::new();
        for source_ref in &self.source_refs {
            source_ref.validate()?;
            if !source_ids.insert(source_ref.ref_id.clone()) {
                return Err(SmallModelProductWrvProbeError::DuplicateSourceRef(
                    source_ref.ref_id.clone(),
                ));
            }
        }
        let mut surface_ids = HashSet::new();
        for surface in &self.surfaces {
            surface.validate()?;
            if !surface_ids.insert(surface.surface_id.clone()) {
                return Err(SmallModelProductWrvProbeError::DuplicateSurface(
                    surface.surface_id.clone(),
                ));
            }
        }
        let mut test_ids = HashSet::new();
        for test_ref in &self.test_refs {
            test_ref.validate()?;
            if !test_ids.insert(test_ref.ref_id.clone()) {
                return Err(SmallModelProductWrvProbeError::DuplicateTestRef(
                    test_ref.ref_id.clone(),
                ));
            }
        }
        let observed_phases = self
            .phases
            .iter()
            .map(SmallModelProductWrvPhase::tag)
            .collect::<BTreeSet<_>>();
        for phase in required_product_wrv_phases() {
            if !observed_phases.contains(phase.tag()) {
                return Err(SmallModelProductWrvProbeError::MissingPhase(phase.tag()));
            }
        }
        if !self.wired {
            return Err(SmallModelProductWrvProbeError::MissingWrvAxis("wired"));
        }
        if !self.reachable {
            return Err(SmallModelProductWrvProbeError::MissingWrvAxis("reachable"));
        }
        if !self.visible {
            return Err(SmallModelProductWrvProbeError::MissingWrvAxis("visible"));
        }
        if !self.verified {
            return Err(SmallModelProductWrvProbeError::MissingWrvAxis("verified"));
        }
        if !self.l1_l2_l3_separated {
            return Err(SmallModelProductWrvProbeError::MissingWrvAxis(
                "l1_l2_l3_separated",
            ));
        }
        if self.mas_live_agent_overclaim_attempted {
            return Err(SmallModelProductWrvProbeError::MasLiveAgentOverclaim);
        }
        if self.l2_green_claimed {
            return Err(SmallModelProductWrvProbeError::L2GreenClaimAttempted);
        }
        if self.l3_runtime_green_claimed {
            return Err(SmallModelProductWrvProbeError::L3RuntimeGreenClaimAttempted);
        }
        if self.runtime_bytes_loaded != 0 {
            return Err(SmallModelProductWrvProbeError::RuntimeBytesLoaded);
        }
        if self.model_bytes_loaded != 0 {
            return Err(SmallModelProductWrvProbeError::ModelBytesLoaded);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(SmallModelProductWrvProbeError::MetadataBudgetExceeded);
        }
        Ok(())
    }

    pub fn metrics(&self) -> SmallModelProductWrvMetrics {
        SmallModelProductWrvMetrics {
            source_ref_count: self.source_refs.len() as u64,
            source_marker_count: self
                .source_refs
                .iter()
                .map(|source_ref| source_ref.markers.len() as u64)
                .sum(),
            surface_count: self.surfaces.len() as u64,
            test_ref_count: self.test_refs.len() as u64,
            test_marker_count: self
                .test_refs
                .iter()
                .map(|test_ref| test_ref.markers.len() as u64)
                .sum(),
            phase_count: self
                .phases
                .iter()
                .map(SmallModelProductWrvPhase::tag)
                .collect::<BTreeSet<_>>()
                .len() as u64,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            model_bytes_loaded: self.model_bytes_loaded,
        }
    }

    pub fn address(&self) -> String {
        let mut parts = vec![
            self.witness_id.clone(),
            self.upstream_answer_packet_artifact_ref.clone(),
            self.guard_next_existing_work.clone(),
            self.capability_route_status.clone(),
            self.capability_next_bottleneck.clone(),
            self.route_authority.clone(),
        ];
        for source_ref in &self.source_refs {
            parts.push(source_ref.ref_id.clone());
            parts.push(source_ref.path.clone());
            parts.extend(source_ref.markers.iter().cloned());
        }
        for surface in &self.surfaces {
            parts.push(surface.surface_id.clone());
            parts.push(surface.answer_packet_ref.clone());
            parts.push(surface.run_event_log_ref.clone());
        }
        for test_ref in &self.test_refs {
            parts.push(test_ref.ref_id.clone());
            parts.push(test_ref.path.clone());
            parts.extend(test_ref.markers.iter().cloned());
        }
        parts.sort();
        sha256_hex(parts.join("|").as_bytes())
    }
}

pub fn required_product_wrv_phases() -> [SmallModelProductWrvPhase; 12] {
    [
        SmallModelProductWrvPhase::TriagePolicyWired,
        SmallModelProductWrvPhase::LocalGatewayWired,
        SmallModelProductWrvPhase::NoteChatReachable,
        SmallModelProductWrvPhase::SerialControllerBound,
        SmallModelProductWrvPhase::AnswerPacketEmitterBound,
        SmallModelProductWrvPhase::RunEventLogBound,
        SmallModelProductWrvPhase::SettingsVisibilityBound,
        SmallModelProductWrvPhase::MessagePacketVisibilityBound,
        SmallModelProductWrvPhase::TriagePolicyVerified,
        SmallModelProductWrvPhase::SerialControllerVerified,
        SmallModelProductWrvPhase::AnswerPacketVerified,
        SmallModelProductWrvPhase::CapabilityHonestyBound,
    ]
}

pub fn product_wrv_metadata_budget_bytes() -> u64 {
    MAX_METADATA_BYTES
}

fn validate_prefixed_source(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), SmallModelProductWrvProbeError> {
    validate_clean(field, value)?;
    if !value.starts_with(prefix) {
        return Err(SmallModelProductWrvProbeError::MissingField(field));
    }
    Ok(())
}

fn validate_prefixed(
    surface_id: &str,
    value: &str,
    prefix: &str,
    error: fn(String) -> SmallModelProductWrvProbeError,
) -> Result<(), SmallModelProductWrvProbeError> {
    validate_clean("prefixed_ref", value)?;
    if !value.starts_with(prefix) {
        return Err(error(surface_id.to_string()));
    }
    Ok(())
}

fn validate_clean(field: &'static str, value: &str) -> Result<(), SmallModelProductWrvProbeError> {
    if value.is_empty() {
        return Err(SmallModelProductWrvProbeError::MissingField(field));
    }
    if value.trim() != value {
        return Err(SmallModelProductWrvProbeError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(SmallModelProductWrvProbeError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn source(id: &str) -> SmallModelProductWrvSourceRef {
        SmallModelProductWrvSourceRef {
            ref_id: format!("source:{id}"),
            path: format!("Epistemos/{id}.swift"),
            markers: vec!["localMLX".to_string(), "AnswerPacket".to_string()],
        }
    }

    fn test_ref(id: &str) -> SmallModelProductWrvTestRef {
        SmallModelProductWrvTestRef {
            ref_id: format!("test:{id}"),
            path: format!("EpistemosTests/{id}.swift"),
            markers: vec!["#expect".to_string(), "localMLX".to_string()],
        }
    }

    fn surface(id: &str) -> SmallModelProductWrvSurface {
        SmallModelProductWrvSurface {
            surface_id: format!("surface:{id}"),
            admission_ref: "admission:scope_rex:local_model_product_wrv".to_string(),
            rollback_ref: "rollback:no_product_mutation:source_probe".to_string(),
            answer_packet_ref: "answer_packet:settings:diagnostic_ring".to_string(),
            run_event_log_ref: "run_event_log:source_wrv:metadata_only".to_string(),
            compatibility_fence_ref: "compat:mas_pro_l1_l2_l3_separated".to_string(),
            privacy_ref: "privacy:no_prompt_or_token_text".to_string(),
            budget_ref: "budget:no_runtime_or_model_bytes".to_string(),
            visible: true,
            hidden_route_authority: false,
            hidden_cloud_fallback: false,
            hidden_chain_exposed: false,
            route_policy_mutated: false,
            gate_bypassed: false,
            answer_packet_suppressed: false,
            subprocess_spawned_in_app_path: false,
            autogenous_kernel_attempted: false,
            seventy_b_product_claimed: false,
            long_context_shard_product_claimed: false,
        }
    }

    fn witness() -> SmallModelProductWrvWitness {
        SmallModelProductWrvWitness::new(
            "small-model-product-wrv-fixture",
            "artifact:small_model_runtime_harness_answer_packet_runtime_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "source_wrv_only_no_live_route_authority",
            vec![source("TriageService"), source("LLMService")],
            vec![surface("settings"), surface("message")],
            vec![
                test_ref("TriageServiceTests"),
                test_ref("AnswerPacketAttentionModeTests"),
            ],
            required_product_wrv_phases().to_vec(),
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            0,
            0,
            4096,
        )
        .expect("fixture witness should validate")
    }

    #[test]
    fn product_wrv_fixture_validates_and_has_deterministic_address() {
        let first = witness();
        let second = witness();
        assert_eq!(first.address(), second.address());
        assert_eq!(
            first.metrics().phase_count,
            required_product_wrv_phases().len() as u64
        );
    }

    #[test]
    fn missing_reachable_axis_is_rejected() {
        let error = SmallModelProductWrvWitness::new(
            "small-model-product-wrv-fixture",
            "artifact:small_model_runtime_harness_answer_packet_runtime_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "source_wrv_only_no_live_route_authority",
            vec![source("TriageService")],
            vec![surface("settings")],
            vec![test_ref("TriageServiceTests")],
            required_product_wrv_phases().to_vec(),
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            0,
            0,
            4096,
        )
        .expect_err("missing reachable axis must fail");
        assert!(matches!(
            error,
            SmallModelProductWrvProbeError::MissingWrvAxis("reachable")
        ));
    }

    #[test]
    fn runtime_bytes_are_rejected() {
        let error = SmallModelProductWrvWitness::new(
            "small-model-product-wrv-fixture",
            "artifact:small_model_runtime_harness_answer_packet_runtime_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "source_wrv_only_no_live_route_authority",
            vec![source("TriageService")],
            vec![surface("settings")],
            vec![test_ref("TriageServiceTests")],
            required_product_wrv_phases().to_vec(),
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            1,
            0,
            4096,
        )
        .expect_err("source-only witness cannot load runtime bytes");
        assert!(matches!(
            error,
            SmallModelProductWrvProbeError::RuntimeBytesLoaded
        ));
    }

    #[test]
    fn hidden_cloud_is_rejected() {
        let mut surface = surface("settings");
        surface.hidden_cloud_fallback = true;
        let error = SmallModelProductWrvWitness::new(
            "small-model-product-wrv-fixture",
            "artifact:small_model_runtime_harness_answer_packet_runtime_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_WRV_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "source_wrv_only_no_live_route_authority",
            vec![source("TriageService")],
            vec![surface],
            vec![test_ref("TriageServiceTests")],
            required_product_wrv_phases().to_vec(),
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            0,
            0,
            4096,
        )
        .expect_err("hidden cloud fallback must fail");
        assert!(matches!(
            error,
            SmallModelProductWrvProbeError::HiddenCloudFallback(_)
        ));
    }
}
