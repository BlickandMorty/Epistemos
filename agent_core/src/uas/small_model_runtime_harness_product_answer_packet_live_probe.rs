//! Small-model runtime harness product AnswerPacket live probe.
//!
//! This L1 witness binds retained small-model runtime evidence to the app
//! product AnswerPacket handoff. It proves the product route can carry visible
//! packet/log proof from a bounded local-model runtime sidecar, while rejecting
//! hidden authority, mutation, raw-token retention, MAS overclaim, 70B drift,
//! 128K shard drift, and false L2/L3 promotion.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_CURSOR: &str =
    "small_model_runtime_harness_product_answer_packet_live_probe";
pub const SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_product_route_capability_recheck";
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";

const PRODUCT_WRV_ARTIFACT_PREFIX: &str = "artifact:small_model_runtime_harness_product_wrv_probe:";
const ANSWER_PACKET_ARTIFACT_PREFIX: &str =
    "artifact:small_model_runtime_harness_answer_packet_runtime_probe:";
const FIRST_TOKEN_ARTIFACT_PREFIX: &str =
    "artifact:small_model_runtime_harness_first_token_runtime_probe:";
const PRODUCT_SURFACE_PREFIX: &str = "surface:";
const SOURCE_PREFIX: &str = "source:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const ROLLBACK_PREFIX: &str = "rollback:";
const CANCELLATION_PREFIX: &str = "cancel:";
const COMPATIBILITY_PREFIX: &str = "compat:";
const PRIVACY_PREFIX: &str = "privacy:";
const BUDGET_PREFIX: &str = "budget:";
const RETAINED_TOKEN_SHA_PREFIX: &str = "token_sha256:";
const MIN_PRODUCT_MARKERS_PER_SURFACE: usize = 2;
const MAX_METADATA_BYTES: u64 = 768 * 1024;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-product-answer-packet-live-probe:phase
// Plane: Controller + Verification
// Residency: retained live evidence projected into product packet handoff.
pub enum SmallModelProductAnswerPacketLivePhase {
    ProductWrvBound,
    RetainedFirstTokenRuntimeBound,
    AnswerPacketSidecarBound,
    RunEventLogSidecarBound,
    ProductSurfacePacketProjected,
    ProductSurfaceLogProjected,
    RedactionVerified,
    CancellationRollbackBound,
    MasProHonestyBound,
    CapabilityRecheckPending,
}

impl SmallModelProductAnswerPacketLivePhase {
    pub fn tag(&self) -> &'static str {
        match self {
            Self::ProductWrvBound => "product_wrv_bound",
            Self::RetainedFirstTokenRuntimeBound => "retained_first_token_runtime_bound",
            Self::AnswerPacketSidecarBound => "answer_packet_sidecar_bound",
            Self::RunEventLogSidecarBound => "run_event_log_sidecar_bound",
            Self::ProductSurfacePacketProjected => "product_surface_packet_projected",
            Self::ProductSurfaceLogProjected => "product_surface_log_projected",
            Self::RedactionVerified => "redaction_verified",
            Self::CancellationRollbackBound => "cancellation_rollback_bound",
            Self::MasProHonestyBound => "mas_pro_honesty_bound",
            Self::CapabilityRecheckPending => "capability_recheck_pending",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-product-answer-packet-live-probe:error
// Plane: Verification
// Residency: product packet handoff rejection taxonomy.
pub enum SmallModelProductAnswerPacketLiveProbeError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptySurface,
    EmptyPhase,
    DuplicateSurface(String),
    MissingProductMarker(String),
    MissingPhase(&'static str),
    ProductStatusMismatch,
    CapabilityStatusMismatch,
    GuardCursorMismatch,
    MissingProductWrvArtifact(String),
    MissingAnswerPacketArtifact(String),
    MissingFirstTokenArtifact(String),
    MissingAnswerPacketRef(String),
    MissingRunEventLogRef(String),
    MissingAdmission(String),
    MissingScopeRex(String),
    MissingSovereignGate(String),
    MissingRollback(String),
    MissingCancellation(String),
    MissingCompatibilityFence(String),
    MissingPrivacyFence(String),
    MissingBudget(String),
    MissingTokenDigest(String),
    RetainedRuntimeBytesMissing,
    RetainedModelBytesMissing,
    FreshProductRuntimeBytesLoaded,
    FreshProductModelBytesLoaded,
    ProductSurfaceNotVisible(String),
    ProductPacketNotProjected(String),
    ProductLogNotProjected(String),
    RawTokenTextRetained(String),
    PromptUserDataRetained(String),
    HiddenRouteAuthority(String),
    HiddenCloudFallback(String),
    HiddenChainExposure(String),
    RoutePolicyMutation(String),
    GateBypass(String),
    AnswerPacketSuppressed(String),
    AppPathSubprocessSpawn(String),
    AutogenousKernelAttempt(String),
    SeventyBProbeAttempt(String),
    LongContextShardProbeAttempt(String),
    MasLiveAgentOverclaim,
    L2GreenClaimAttempted,
    L3GreenClaimAttempted,
    MetadataBudgetExceeded,
}

impl fmt::Display for SmallModelProductAnswerPacketLiveProbeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptySurface => write!(f, "missing product surface"),
            Self::EmptyPhase => write!(f, "missing product live phase"),
            Self::DuplicateSurface(id) => write!(f, "duplicate product surface `{id}`"),
            Self::MissingProductMarker(id) => write!(f, "surface `{id}` missing product marker"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::MissingProductWrvArtifact(id) => {
                write!(f, "witness `{id}` missing product WRV artifact ref")
            }
            Self::MissingAnswerPacketArtifact(id) => {
                write!(f, "witness `{id}` missing AnswerPacket artifact ref")
            }
            Self::MissingFirstTokenArtifact(id) => {
                write!(f, "witness `{id}` missing first-token artifact ref")
            }
            Self::MissingAnswerPacketRef(id) => {
                write!(f, "surface `{id}` missing AnswerPacket ref")
            }
            Self::MissingRunEventLogRef(id) => {
                write!(f, "surface `{id}` missing RunEventLog ref")
            }
            Self::MissingAdmission(id) => write!(f, "surface `{id}` missing admission ref"),
            Self::MissingScopeRex(id) => write!(f, "surface `{id}` missing SCOPE-Rex ref"),
            Self::MissingSovereignGate(id) => {
                write!(f, "surface `{id}` missing SovereignGate ref")
            }
            Self::MissingRollback(id) => write!(f, "surface `{id}` missing rollback ref"),
            Self::MissingCancellation(id) => write!(f, "surface `{id}` missing cancellation ref"),
            Self::MissingCompatibilityFence(id) => {
                write!(f, "surface `{id}` missing compatibility fence")
            }
            Self::MissingPrivacyFence(id) => write!(f, "surface `{id}` missing privacy fence"),
            Self::MissingBudget(id) => write!(f, "surface `{id}` missing budget ref"),
            Self::MissingTokenDigest(id) => write!(f, "surface `{id}` missing token digest"),
            Self::RetainedRuntimeBytesMissing => write!(f, "retained runtime bytes missing"),
            Self::RetainedModelBytesMissing => write!(f, "retained model bytes missing"),
            Self::FreshProductRuntimeBytesLoaded => {
                write!(f, "fresh product runtime bytes loaded in handoff probe")
            }
            Self::FreshProductModelBytesLoaded => {
                write!(f, "fresh product model bytes loaded in handoff probe")
            }
            Self::ProductSurfaceNotVisible(id) => write!(f, "surface `{id}` is not visible"),
            Self::ProductPacketNotProjected(id) => {
                write!(f, "surface `{id}` did not project AnswerPacket")
            }
            Self::ProductLogNotProjected(id) => {
                write!(f, "surface `{id}` did not project RunEventLog")
            }
            Self::RawTokenTextRetained(id) => write!(f, "surface `{id}` retained raw token text"),
            Self::PromptUserDataRetained(id) => write!(f, "surface `{id}` retained user prompt"),
            Self::HiddenRouteAuthority(id) => write!(f, "surface `{id}` has hidden authority"),
            Self::HiddenCloudFallback(id) => write!(f, "surface `{id}` has hidden cloud fallback"),
            Self::HiddenChainExposure(id) => write!(f, "surface `{id}` exposes hidden chain"),
            Self::RoutePolicyMutation(id) => write!(f, "surface `{id}` mutates route policy"),
            Self::GateBypass(id) => write!(f, "surface `{id}` bypasses gate"),
            Self::AnswerPacketSuppressed(id) => write!(f, "surface `{id}` suppresses packet"),
            Self::AppPathSubprocessSpawn(id) => write!(f, "surface `{id}` spawns app subprocess"),
            Self::AutogenousKernelAttempt(id) => {
                write!(f, "surface `{id}` attempts autogenous kernel")
            }
            Self::SeventyBProbeAttempt(id) => write!(f, "surface `{id}` attempts 70B probe"),
            Self::LongContextShardProbeAttempt(id) => {
                write!(f, "surface `{id}` attempts long-context shard")
            }
            Self::MasLiveAgentOverclaim => write!(f, "MAS live-agent overclaim attempted"),
            Self::L2GreenClaimAttempted => write!(f, "L2 green claim attempted"),
            Self::L3GreenClaimAttempted => write!(f, "L3 green claim attempted"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for SmallModelProductAnswerPacketLiveProbeError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-product-answer-packet-live-probe:surface
// Plane: State + Verification
// Residency: visible product surface carrying packet/log handoff proof.
pub struct SmallModelProductAnswerPacketLiveSurface {
    pub surface_id: String,
    pub source_ref: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub rollback_ref: String,
    pub cancellation_ref: String,
    pub compatibility_fence_ref: String,
    pub privacy_ref: String,
    pub budget_ref: String,
    pub retained_token_digest_ref: String,
    pub product_markers: Vec<String>,
    pub visible: bool,
    pub packet_projected: bool,
    pub run_event_log_projected: bool,
    pub raw_token_text_retained: bool,
    pub prompt_user_data_retained: bool,
    pub hidden_route_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub hidden_chain_exposed: bool,
    pub route_policy_mutated: bool,
    pub gate_bypassed: bool,
    pub answer_packet_suppressed: bool,
    pub subprocess_spawned_in_app_path: bool,
    pub autogenous_kernel_attempted: bool,
    pub seventy_b_probe_attempted: bool,
    pub long_context_shard_probe_attempted: bool,
}

impl SmallModelProductAnswerPacketLiveSurface {
    pub fn validate(&self) -> Result<(), SmallModelProductAnswerPacketLiveProbeError> {
        validate_prefixed_clean("surface_id", &self.surface_id, PRODUCT_SURFACE_PREFIX)?;
        validate_prefixed_clean("source_ref", &self.source_ref, SOURCE_PREFIX)?;
        validate_prefixed(
            &self.surface_id,
            &self.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
            SmallModelProductAnswerPacketLiveProbeError::MissingAnswerPacketRef,
        )?;
        validate_prefixed(
            &self.surface_id,
            &self.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
            SmallModelProductAnswerPacketLiveProbeError::MissingRunEventLogRef,
        )?;
        validate_prefixed(
            &self.surface_id,
            &self.admission_ref,
            ADMISSION_PREFIX,
            SmallModelProductAnswerPacketLiveProbeError::MissingAdmission,
        )?;
        validate_prefixed(
            &self.surface_id,
            &self.scope_rex_ref,
            SCOPE_REX_PREFIX,
            SmallModelProductAnswerPacketLiveProbeError::MissingScopeRex,
        )?;
        validate_prefixed(
            &self.surface_id,
            &self.sovereign_gate_ref,
            SOVEREIGN_GATE_PREFIX,
            SmallModelProductAnswerPacketLiveProbeError::MissingSovereignGate,
        )?;
        validate_prefixed(
            &self.surface_id,
            &self.rollback_ref,
            ROLLBACK_PREFIX,
            SmallModelProductAnswerPacketLiveProbeError::MissingRollback,
        )?;
        validate_prefixed(
            &self.surface_id,
            &self.cancellation_ref,
            CANCELLATION_PREFIX,
            SmallModelProductAnswerPacketLiveProbeError::MissingCancellation,
        )?;
        validate_prefixed(
            &self.surface_id,
            &self.compatibility_fence_ref,
            COMPATIBILITY_PREFIX,
            SmallModelProductAnswerPacketLiveProbeError::MissingCompatibilityFence,
        )?;
        validate_prefixed(
            &self.surface_id,
            &self.privacy_ref,
            PRIVACY_PREFIX,
            SmallModelProductAnswerPacketLiveProbeError::MissingPrivacyFence,
        )?;
        validate_prefixed(
            &self.surface_id,
            &self.budget_ref,
            BUDGET_PREFIX,
            SmallModelProductAnswerPacketLiveProbeError::MissingBudget,
        )?;
        validate_prefixed(
            &self.surface_id,
            &self.retained_token_digest_ref,
            RETAINED_TOKEN_SHA_PREFIX,
            SmallModelProductAnswerPacketLiveProbeError::MissingTokenDigest,
        )?;
        if self.product_markers.len() < MIN_PRODUCT_MARKERS_PER_SURFACE {
            return Err(
                SmallModelProductAnswerPacketLiveProbeError::MissingProductMarker(
                    self.surface_id.clone(),
                ),
            );
        }
        for marker in &self.product_markers {
            validate_clean("product_marker", marker)?;
        }
        if !self.visible {
            return Err(
                SmallModelProductAnswerPacketLiveProbeError::ProductSurfaceNotVisible(
                    self.surface_id.clone(),
                ),
            );
        }
        if !self.packet_projected {
            return Err(
                SmallModelProductAnswerPacketLiveProbeError::ProductPacketNotProjected(
                    self.surface_id.clone(),
                ),
            );
        }
        if !self.run_event_log_projected {
            return Err(
                SmallModelProductAnswerPacketLiveProbeError::ProductLogNotProjected(
                    self.surface_id.clone(),
                ),
            );
        }
        if self.raw_token_text_retained {
            return Err(
                SmallModelProductAnswerPacketLiveProbeError::RawTokenTextRetained(
                    self.surface_id.clone(),
                ),
            );
        }
        if self.prompt_user_data_retained {
            return Err(
                SmallModelProductAnswerPacketLiveProbeError::PromptUserDataRetained(
                    self.surface_id.clone(),
                ),
            );
        }
        if self.hidden_route_authority {
            return Err(
                SmallModelProductAnswerPacketLiveProbeError::HiddenRouteAuthority(
                    self.surface_id.clone(),
                ),
            );
        }
        if self.hidden_cloud_fallback {
            return Err(
                SmallModelProductAnswerPacketLiveProbeError::HiddenCloudFallback(
                    self.surface_id.clone(),
                ),
            );
        }
        if self.hidden_chain_exposed {
            return Err(
                SmallModelProductAnswerPacketLiveProbeError::HiddenChainExposure(
                    self.surface_id.clone(),
                ),
            );
        }
        if self.route_policy_mutated {
            return Err(
                SmallModelProductAnswerPacketLiveProbeError::RoutePolicyMutation(
                    self.surface_id.clone(),
                ),
            );
        }
        if self.gate_bypassed {
            return Err(SmallModelProductAnswerPacketLiveProbeError::GateBypass(
                self.surface_id.clone(),
            ));
        }
        if self.answer_packet_suppressed {
            return Err(
                SmallModelProductAnswerPacketLiveProbeError::AnswerPacketSuppressed(
                    self.surface_id.clone(),
                ),
            );
        }
        if self.subprocess_spawned_in_app_path {
            return Err(
                SmallModelProductAnswerPacketLiveProbeError::AppPathSubprocessSpawn(
                    self.surface_id.clone(),
                ),
            );
        }
        if self.autogenous_kernel_attempted {
            return Err(
                SmallModelProductAnswerPacketLiveProbeError::AutogenousKernelAttempt(
                    self.surface_id.clone(),
                ),
            );
        }
        if self.seventy_b_probe_attempted {
            return Err(
                SmallModelProductAnswerPacketLiveProbeError::SeventyBProbeAttempt(
                    self.surface_id.clone(),
                ),
            );
        }
        if self.long_context_shard_probe_attempted {
            return Err(
                SmallModelProductAnswerPacketLiveProbeError::LongContextShardProbeAttempt(
                    self.surface_id.clone(),
                ),
            );
        }
        Ok(())
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-product-answer-packet-live-probe:metrics
// Plane: Verification
// Residency: aggregate product packet handoff evidence.
pub struct SmallModelProductAnswerPacketLiveMetrics {
    pub surface_count: u64,
    pub product_marker_count: u64,
    pub phase_count: u64,
    pub retained_runtime_bytes_loaded: u64,
    pub retained_model_bytes_loaded: u64,
    pub fresh_product_runtime_bytes_loaded: u64,
    pub fresh_product_model_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-product-answer-packet-live-probe:witness
// Plane: Controller + Verification
// Residency: product AnswerPacket handoff over retained local runtime evidence.
pub struct SmallModelProductAnswerPacketLiveWitness {
    pub witness_id: String,
    pub product_wrv_artifact_ref: String,
    pub answer_packet_artifact_ref: String,
    pub first_token_artifact_ref: String,
    pub guard_next_existing_work: String,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub surfaces: Vec<SmallModelProductAnswerPacketLiveSurface>,
    pub phases: Vec<SmallModelProductAnswerPacketLivePhase>,
    pub retained_runtime_bytes_loaded: u64,
    pub retained_model_bytes_loaded: u64,
    pub fresh_product_runtime_bytes_loaded: u64,
    pub fresh_product_model_bytes_loaded: u64,
    pub l1_l2_l3_separated: bool,
    pub mas_live_agent_overclaim_attempted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub metadata_bytes: u64,
}

impl SmallModelProductAnswerPacketLiveWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        product_wrv_artifact_ref: impl Into<String>,
        answer_packet_artifact_ref: impl Into<String>,
        first_token_artifact_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        surfaces: Vec<SmallModelProductAnswerPacketLiveSurface>,
        phases: Vec<SmallModelProductAnswerPacketLivePhase>,
        retained_runtime_bytes_loaded: u64,
        retained_model_bytes_loaded: u64,
        fresh_product_runtime_bytes_loaded: u64,
        fresh_product_model_bytes_loaded: u64,
        l1_l2_l3_separated: bool,
        mas_live_agent_overclaim_attempted: bool,
        l2_green_claimed: bool,
        l3_green_claimed: bool,
        metadata_bytes: u64,
    ) -> Result<Self, SmallModelProductAnswerPacketLiveProbeError> {
        let witness = Self {
            witness_id: witness_id.into(),
            product_wrv_artifact_ref: product_wrv_artifact_ref.into(),
            answer_packet_artifact_ref: answer_packet_artifact_ref.into(),
            first_token_artifact_ref: first_token_artifact_ref.into(),
            guard_next_existing_work: guard_next_existing_work.into(),
            capability_route_status: capability_route_status.into(),
            capability_next_bottleneck: capability_next_bottleneck.into(),
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            surfaces,
            phases,
            retained_runtime_bytes_loaded,
            retained_model_bytes_loaded,
            fresh_product_runtime_bytes_loaded,
            fresh_product_model_bytes_loaded,
            l1_l2_l3_separated,
            mas_live_agent_overclaim_attempted,
            l2_green_claimed,
            l3_green_claimed,
            metadata_bytes,
        };
        witness.validate()?;
        Ok(witness)
    }

    pub fn validate(&self) -> Result<(), SmallModelProductAnswerPacketLiveProbeError> {
        validate_clean("witness_id", &self.witness_id)?;
        validate_prefixed(
            &self.witness_id,
            &self.product_wrv_artifact_ref,
            PRODUCT_WRV_ARTIFACT_PREFIX,
            SmallModelProductAnswerPacketLiveProbeError::MissingProductWrvArtifact,
        )?;
        validate_prefixed(
            &self.witness_id,
            &self.answer_packet_artifact_ref,
            ANSWER_PACKET_ARTIFACT_PREFIX,
            SmallModelProductAnswerPacketLiveProbeError::MissingAnswerPacketArtifact,
        )?;
        validate_prefixed(
            &self.witness_id,
            &self.first_token_artifact_ref,
            FIRST_TOKEN_ARTIFACT_PREFIX,
            SmallModelProductAnswerPacketLiveProbeError::MissingFirstTokenArtifact,
        )?;
        if self.guard_next_existing_work
            != SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_CURSOR
            && self.guard_next_existing_work
                != SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_NEXT_CURSOR
            && self.guard_next_existing_work != ADVANCED_RELEASE_AUDIT_CURSOR
        {
            return Err(SmallModelProductAnswerPacketLiveProbeError::GuardCursorMismatch);
        }
        if self.capability_route_status != "vault_research_route_with_packetized_mitigation"
            || (self.capability_next_bottleneck
                != SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_CURSOR
                && self.capability_next_bottleneck
                    != SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_NEXT_CURSOR
                && self.capability_next_bottleneck != ADVANCED_RELEASE_AUDIT_CURSOR)
        {
            return Err(SmallModelProductAnswerPacketLiveProbeError::CapabilityStatusMismatch);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.route_authority
                != "retained_live_product_answer_packet_handoff_no_route_authority"
        {
            return Err(SmallModelProductAnswerPacketLiveProbeError::ProductStatusMismatch);
        }
        if self.surfaces.is_empty() {
            return Err(SmallModelProductAnswerPacketLiveProbeError::EmptySurface);
        }
        if self.phases.is_empty() {
            return Err(SmallModelProductAnswerPacketLiveProbeError::EmptyPhase);
        }
        let mut surface_ids = HashSet::new();
        for surface in &self.surfaces {
            surface.validate()?;
            if !surface_ids.insert(surface.surface_id.clone()) {
                return Err(
                    SmallModelProductAnswerPacketLiveProbeError::DuplicateSurface(
                        surface.surface_id.clone(),
                    ),
                );
            }
        }
        let observed_phases = self
            .phases
            .iter()
            .map(SmallModelProductAnswerPacketLivePhase::tag)
            .collect::<BTreeSet<_>>();
        for phase in required_product_answer_packet_live_phases() {
            if !observed_phases.contains(phase.tag()) {
                return Err(SmallModelProductAnswerPacketLiveProbeError::MissingPhase(
                    phase.tag(),
                ));
            }
        }
        if self.retained_runtime_bytes_loaded == 0 {
            return Err(SmallModelProductAnswerPacketLiveProbeError::RetainedRuntimeBytesMissing);
        }
        if self.retained_model_bytes_loaded == 0 {
            return Err(SmallModelProductAnswerPacketLiveProbeError::RetainedModelBytesMissing);
        }
        if self.fresh_product_runtime_bytes_loaded != 0 {
            return Err(
                SmallModelProductAnswerPacketLiveProbeError::FreshProductRuntimeBytesLoaded,
            );
        }
        if self.fresh_product_model_bytes_loaded != 0 {
            return Err(SmallModelProductAnswerPacketLiveProbeError::FreshProductModelBytesLoaded);
        }
        if !self.l1_l2_l3_separated {
            return Err(SmallModelProductAnswerPacketLiveProbeError::MissingField(
                "l1_l2_l3_separated",
            ));
        }
        if self.mas_live_agent_overclaim_attempted {
            return Err(SmallModelProductAnswerPacketLiveProbeError::MasLiveAgentOverclaim);
        }
        if self.l2_green_claimed {
            return Err(SmallModelProductAnswerPacketLiveProbeError::L2GreenClaimAttempted);
        }
        if self.l3_green_claimed {
            return Err(SmallModelProductAnswerPacketLiveProbeError::L3GreenClaimAttempted);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(SmallModelProductAnswerPacketLiveProbeError::MetadataBudgetExceeded);
        }
        Ok(())
    }

    pub fn metrics(&self) -> SmallModelProductAnswerPacketLiveMetrics {
        SmallModelProductAnswerPacketLiveMetrics {
            surface_count: self.surfaces.len() as u64,
            product_marker_count: self
                .surfaces
                .iter()
                .map(|surface| surface.product_markers.len() as u64)
                .sum(),
            phase_count: self
                .phases
                .iter()
                .map(SmallModelProductAnswerPacketLivePhase::tag)
                .collect::<BTreeSet<_>>()
                .len() as u64,
            retained_runtime_bytes_loaded: self.retained_runtime_bytes_loaded,
            retained_model_bytes_loaded: self.retained_model_bytes_loaded,
            fresh_product_runtime_bytes_loaded: self.fresh_product_runtime_bytes_loaded,
            fresh_product_model_bytes_loaded: self.fresh_product_model_bytes_loaded,
        }
    }

    pub fn address(&self) -> String {
        let mut parts = vec![
            self.witness_id.clone(),
            self.product_wrv_artifact_ref.clone(),
            self.answer_packet_artifact_ref.clone(),
            self.first_token_artifact_ref.clone(),
            self.guard_next_existing_work.clone(),
            self.capability_route_status.clone(),
            self.capability_next_bottleneck.clone(),
            self.route_authority.clone(),
            self.retained_runtime_bytes_loaded.to_string(),
            self.retained_model_bytes_loaded.to_string(),
        ];
        for surface in &self.surfaces {
            parts.push(surface.surface_id.clone());
            parts.push(surface.source_ref.clone());
            parts.push(surface.answer_packet_ref.clone());
            parts.push(surface.run_event_log_ref.clone());
            parts.extend(surface.product_markers.iter().cloned());
        }
        for phase in &self.phases {
            parts.push(phase.tag().to_string());
        }
        parts.sort();
        sha256_hex(parts.join("|").as_bytes())
    }
}

pub fn required_product_answer_packet_live_phases() -> [SmallModelProductAnswerPacketLivePhase; 10]
{
    [
        SmallModelProductAnswerPacketLivePhase::ProductWrvBound,
        SmallModelProductAnswerPacketLivePhase::RetainedFirstTokenRuntimeBound,
        SmallModelProductAnswerPacketLivePhase::AnswerPacketSidecarBound,
        SmallModelProductAnswerPacketLivePhase::RunEventLogSidecarBound,
        SmallModelProductAnswerPacketLivePhase::ProductSurfacePacketProjected,
        SmallModelProductAnswerPacketLivePhase::ProductSurfaceLogProjected,
        SmallModelProductAnswerPacketLivePhase::RedactionVerified,
        SmallModelProductAnswerPacketLivePhase::CancellationRollbackBound,
        SmallModelProductAnswerPacketLivePhase::MasProHonestyBound,
        SmallModelProductAnswerPacketLivePhase::CapabilityRecheckPending,
    ]
}

pub fn product_answer_packet_live_metadata_budget_bytes() -> u64 {
    MAX_METADATA_BYTES
}

fn validate_prefixed_clean(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), SmallModelProductAnswerPacketLiveProbeError> {
    validate_clean(field, value)?;
    if !value.starts_with(prefix) {
        return Err(SmallModelProductAnswerPacketLiveProbeError::MissingField(
            field,
        ));
    }
    Ok(())
}

fn validate_prefixed(
    surface_id: &str,
    value: &str,
    prefix: &str,
    error: fn(String) -> SmallModelProductAnswerPacketLiveProbeError,
) -> Result<(), SmallModelProductAnswerPacketLiveProbeError> {
    validate_clean("prefixed_ref", value)?;
    if !value.starts_with(prefix) {
        return Err(error(surface_id.to_string()));
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelProductAnswerPacketLiveProbeError> {
    if value.is_empty() {
        return Err(SmallModelProductAnswerPacketLiveProbeError::MissingField(
            field,
        ));
    }
    if value.trim() != value {
        return Err(
            SmallModelProductAnswerPacketLiveProbeError::FieldHasSurroundingWhitespace(field),
        );
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(
            SmallModelProductAnswerPacketLiveProbeError::FieldContainsControlCharacter(field),
        );
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn surface(id: &str) -> SmallModelProductAnswerPacketLiveSurface {
        SmallModelProductAnswerPacketLiveSurface {
            surface_id: format!("surface:{id}"),
            source_ref: format!("source:{id}"),
            answer_packet_ref: "answer_packet:qwen3_4b:first-token-runtime:packetized".to_string(),
            run_event_log_ref: "run_event_log:system_g:product_projection".to_string(),
            admission_ref: "admission:scope_rex:small_model_product_answer_packet".to_string(),
            scope_rex_ref: "scope_rex:small_model_product_answer_packet".to_string(),
            sovereign_gate_ref: "sovereign_gate:small_model_product_answer_packet".to_string(),
            rollback_ref: "rollback:no_product_mutation:packet_projection".to_string(),
            cancellation_ref: "cancel:serialized_local_inference_controller".to_string(),
            compatibility_fence_ref: "compat:mas_pro_l1_l2_l3_separated".to_string(),
            privacy_ref: "privacy:no_prompt_text_no_token_text_no_hidden_chain".to_string(),
            budget_ref: "budget:retained_small_model_runtime_only_no_new_bytes".to_string(),
            retained_token_digest_ref:
                "token_sha256:d03502c43d74a30b936740a9517dc4ea2b2ad7168caa0a774cefe793ce0b33e7"
                    .to_string(),
            product_markers: vec!["AnswerPacket".to_string(), "RunEventLog".to_string()],
            visible: true,
            packet_projected: true,
            run_event_log_projected: true,
            raw_token_text_retained: false,
            prompt_user_data_retained: false,
            hidden_route_authority: false,
            hidden_cloud_fallback: false,
            hidden_chain_exposed: false,
            route_policy_mutated: false,
            gate_bypassed: false,
            answer_packet_suppressed: false,
            subprocess_spawned_in_app_path: false,
            autogenous_kernel_attempted: false,
            seventy_b_probe_attempted: false,
            long_context_shard_probe_attempted: false,
        }
    }

    fn witness() -> SmallModelProductAnswerPacketLiveWitness {
        SmallModelProductAnswerPacketLiveWitness::new(
            "small-model-product-answer-packet-live-fixture",
            "artifact:small_model_runtime_harness_product_wrv_probe:result",
            "artifact:small_model_runtime_harness_answer_packet_runtime_probe:result",
            "artifact:small_model_runtime_harness_first_token_runtime_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_CURSOR,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "retained_live_product_answer_packet_handoff_no_route_authority",
            vec![surface("message"), surface("settings")],
            required_product_answer_packet_live_phases().to_vec(),
            2_153_272_351,
            2_153_272_351,
            0,
            0,
            true,
            false,
            false,
            false,
            4096,
        )
        .expect("fixture witness should validate")
    }

    #[test]
    fn fixture_validates_and_has_deterministic_address() {
        let first = witness();
        let second = witness();
        assert_eq!(first.address(), second.address());
        assert_eq!(
            first.metrics().phase_count,
            required_product_answer_packet_live_phases().len() as u64
        );
    }

    #[test]
    fn missing_retained_runtime_bytes_are_rejected() {
        let error = SmallModelProductAnswerPacketLiveWitness::new(
            "small-model-product-answer-packet-live-fixture",
            "artifact:small_model_runtime_harness_product_wrv_probe:result",
            "artifact:small_model_runtime_harness_answer_packet_runtime_probe:result",
            "artifact:small_model_runtime_harness_first_token_runtime_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_CURSOR,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "retained_live_product_answer_packet_handoff_no_route_authority",
            vec![surface("message")],
            required_product_answer_packet_live_phases().to_vec(),
            0,
            2_153_272_351,
            0,
            0,
            true,
            false,
            false,
            false,
            4096,
        )
        .expect_err("retained runtime evidence must be nonzero");
        assert!(matches!(
            error,
            SmallModelProductAnswerPacketLiveProbeError::RetainedRuntimeBytesMissing
        ));
    }

    #[test]
    fn packet_suppression_is_rejected() {
        let mut bad_surface = surface("message");
        bad_surface.answer_packet_suppressed = true;
        let error = SmallModelProductAnswerPacketLiveWitness::new(
            "small-model-product-answer-packet-live-fixture",
            "artifact:small_model_runtime_harness_product_wrv_probe:result",
            "artifact:small_model_runtime_harness_answer_packet_runtime_probe:result",
            "artifact:small_model_runtime_harness_first_token_runtime_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_CURSOR,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "retained_live_product_answer_packet_handoff_no_route_authority",
            vec![bad_surface],
            required_product_answer_packet_live_phases().to_vec(),
            2_153_272_351,
            2_153_272_351,
            0,
            0,
            true,
            false,
            false,
            false,
            4096,
        )
        .expect_err("packet suppression must fail");
        assert!(matches!(
            error,
            SmallModelProductAnswerPacketLiveProbeError::AnswerPacketSuppressed(_)
        ));
    }

    #[test]
    fn l2_green_claim_is_rejected() {
        let error = SmallModelProductAnswerPacketLiveWitness::new(
            "small-model-product-answer-packet-live-fixture",
            "artifact:small_model_runtime_harness_product_wrv_probe:result",
            "artifact:small_model_runtime_harness_answer_packet_runtime_probe:result",
            "artifact:small_model_runtime_harness_first_token_runtime_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_CURSOR,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ANSWER_PACKET_LIVE_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "retained_live_product_answer_packet_handoff_no_route_authority",
            vec![surface("message")],
            required_product_answer_packet_live_phases().to_vec(),
            2_153_272_351,
            2_153_272_351,
            0,
            0,
            true,
            false,
            true,
            false,
            4096,
        )
        .expect_err("L2 cannot become green here");
        assert!(matches!(
            error,
            SmallModelProductAnswerPacketLiveProbeError::L2GreenClaimAttempted
        ));
    }
}
