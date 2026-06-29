//! Small-model runtime harness AnswerPacket runtime probe.
//!
//! This L1 witness sits at
//! `small_model_runtime_harness_answer_packet_runtime_probe`. It does not run
//! inference again. It packetizes the already-retained first-token sidecar into
//! the real Rust AnswerPacket schema and a dense RunEventLog, proving visible
//! proof wiring without promoting L2/L3 product capability.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::agent_runtime_v2::event::AgentEvent;
use crate::agent_runtime_v2::para::StopReason;
use crate::agent_runtime_v2::run_event_log::RunEventLog;
use crate::falsifier_artifacts::sha256_hex;
use crate::provenance::ledger::{ClaimKind, ClaimStatus};
use crate::scope_rex::answer_packet::{AnswerPacket, AttentionMode, VrmLabel};
use crate::uas::{ProStatus, ProductBuild};

pub const SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_CURSOR: &str =
    "small_model_runtime_harness_answer_packet_runtime_probe";
pub const SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_product_wrv_probe";
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";

const FIRST_TOKEN_ARTIFACT_PREFIX: &str =
    "artifact:small_model_runtime_harness_first_token_runtime_probe:";
const FIRST_TOKEN_SIDECAR_PREFIX: &str =
    "artifact:small_model_runtime_harness_first_token_runtime_probe:live_probe:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const RUN_EVENT_LOG_ROOT_PREFIX: &str = "run_event_log_root:";
const PACKET_JSON_PREFIX: &str = "answer_packet_json:";
const WITNESSED_STATE_PREFIX: &str = "witnessed_state:";
const MUTATION_ENVELOPE_PREFIX: &str = "mutation_envelope:no_mutation:";
const SEMANTIC_DELTA_PREFIX: &str = "semantic_delta:redacted_first_token:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ADMISSION_PREFIX: &str = "admission:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";
const CANCELLATION_PREFIX: &str = "cancel:";
const PRIVACY_PREFIX: &str = "privacy:";
const BUDGET_PREFIX: &str = "budget:";
const TOKEN_SHA_PREFIX: &str = "token_sha256:";
const MIN_SURFACE_TEXT_BYTES: usize = 256;
const MAX_METADATA_BYTES: u64 = 512 * 1024;
const MIN_TOKEN_SHA_LEN: usize = 71;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-answer-packet-runtime-probe:phase
// Plane: Controller + Verification
// Residency: retained first-token packetization proof phase.
pub enum SmallModelAnswerPacketRuntimeProbePhase {
    FirstTokenArtifactBound,
    LiveProbeSidecarBound,
    PacketProducerBound,
    AnswerPacketSerialized,
    ClaimsBound,
    AttentionModeChecked,
    ResidencySignalBound,
    RunEventLogSerialized,
    RunEventLogRootBound,
    TokenRedactionVerified,
    RollbackVerified,
    EvidenceReviewPending,
}

impl SmallModelAnswerPacketRuntimeProbePhase {
    pub fn tag(&self) -> &'static str {
        match self {
            Self::FirstTokenArtifactBound => "first_token_artifact_bound",
            Self::LiveProbeSidecarBound => "live_probe_sidecar_bound",
            Self::PacketProducerBound => "packet_producer_bound",
            Self::AnswerPacketSerialized => "answer_packet_serialized",
            Self::ClaimsBound => "claims_bound",
            Self::AttentionModeChecked => "attention_mode_checked",
            Self::ResidencySignalBound => "residency_signal_bound",
            Self::RunEventLogSerialized => "run_event_log_serialized",
            Self::RunEventLogRootBound => "run_event_log_root_bound",
            Self::TokenRedactionVerified => "token_redaction_verified",
            Self::RollbackVerified => "rollback_verified",
            Self::EvidenceReviewPending => "evidence_review_pending",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-answer-packet-runtime-probe:error
// Plane: Verification
// Residency: retained packetization rejection taxonomy.
pub enum SmallModelRuntimeHarnessAnswerPacketProbeError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    EmptyPacket,
    EmptySurface,
    EmptyPhase,
    DuplicatePacket(String),
    DuplicateSurface(String),
    MissingRequiredMarker(String),
    ForbiddenMarker(String),
    MissingPhase(&'static str),
    ProductStatusMismatch,
    CapabilityStatusMismatch,
    GuardCursorMismatch,
    MissingFirstTokenArtifact(String),
    MissingLiveProbeSidecar(String),
    MissingAnswerPacket(String),
    MissingRunEventLog(String),
    MissingRunEventLogRoot(String),
    MissingPacketJson(String),
    MissingWitnessedState(String),
    MissingMutationEnvelope(String),
    MissingSemanticDelta(String),
    MissingRollback(String),
    MissingAdmission(String),
    MissingScopeRex(String),
    MissingSovereignGate(String),
    MissingCompatibilityFence(String),
    MissingCancellation(String),
    MissingPrivacyFence(String),
    MissingBudget(String),
    MissingTokenDigest(String),
    MissingLayerSeparation,
    PacketIdMismatch(String),
    PacketJsonDigestMismatch(String),
    PacketClaimsMissing(String),
    PacketClaimKindMissing(&'static str),
    PacketClaimNotActive(String),
    PacketAttentionModeMismatch(String),
    StaticFallbackContradiction(String),
    PacketUiLabelOverclaim(String),
    ResidencySignalMissing(String),
    ResidencySignalNonNeutral(String),
    RunEventLogNotDense(String),
    RunEventLogMissingStop(String),
    RunEventLogHasErrors(String),
    RunEventLogRootMismatch(String),
    RedactedFinalTextMissing(String),
    TokenDigestMalformed(String),
    TokenTextRetained(String),
    PromptUserData(String),
    MutationCommitted(String),
    RoutePolicyMutation(String),
    GateBypass(String),
    AnswerPacketSuppression(String),
    HiddenRouteAuthority(String),
    HiddenChainExposure(String),
    HiddenCloudFallback(String),
    AppPathSubprocessSpawn(String),
    AutogenousKernelAttempt(String),
    SeventyBProbeAttempt(String),
    LongContextShardProbeAttempt(String),
    NewRuntimeBytesLoaded(String),
    NewModelBytesLoaded(String),
    UpstreamRuntimeBytesMissing(String),
    UpstreamModelBytesMissing(String),
    MasOverclaimAttempted,
    L2GreenClaimAttempted,
    L3GreenClaimAttempted,
    MetadataBudgetExceeded,
}

impl fmt::Display for SmallModelRuntimeHarnessAnswerPacketProbeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::EmptyPacket => write!(f, "missing AnswerPacket runtime packet"),
            Self::EmptySurface => write!(f, "missing AnswerPacket runtime surface"),
            Self::EmptyPhase => write!(f, "missing AnswerPacket runtime phase"),
            Self::DuplicatePacket(id) => write!(f, "duplicate packet `{id}`"),
            Self::DuplicateSurface(id) => write!(f, "duplicate surface `{id}`"),
            Self::MissingRequiredMarker(marker) => write!(f, "missing marker `{marker}`"),
            Self::ForbiddenMarker(marker) => write!(f, "forbidden marker `{marker}`"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::MissingFirstTokenArtifact(id) => {
                write!(f, "packet `{id}` missing first-token artifact ref")
            }
            Self::MissingLiveProbeSidecar(id) => {
                write!(f, "packet `{id}` missing first-token sidecar ref")
            }
            Self::MissingAnswerPacket(id) => write!(f, "packet `{id}` missing AnswerPacket ref"),
            Self::MissingRunEventLog(id) => write!(f, "packet `{id}` missing RunEventLog ref"),
            Self::MissingRunEventLogRoot(id) => {
                write!(f, "packet `{id}` missing RunEventLog root ref")
            }
            Self::MissingPacketJson(id) => write!(f, "packet `{id}` missing packet JSON ref"),
            Self::MissingWitnessedState(id) => {
                write!(f, "packet `{id}` missing witnessed-state ref")
            }
            Self::MissingMutationEnvelope(id) => {
                write!(f, "packet `{id}` missing no-mutation envelope ref")
            }
            Self::MissingSemanticDelta(id) => {
                write!(f, "packet `{id}` missing semantic-delta ref")
            }
            Self::MissingRollback(id) => write!(f, "packet `{id}` missing rollback ref"),
            Self::MissingAdmission(id) => write!(f, "packet `{id}` missing admission ref"),
            Self::MissingScopeRex(id) => write!(f, "packet `{id}` missing SCOPE-Rex ref"),
            Self::MissingSovereignGate(id) => {
                write!(f, "packet `{id}` missing SovereignGate ref")
            }
            Self::MissingCompatibilityFence(id) => {
                write!(f, "packet `{id}` missing compatibility fence")
            }
            Self::MissingCancellation(id) => write!(f, "packet `{id}` missing cancellation ref"),
            Self::MissingPrivacyFence(id) => write!(f, "packet `{id}` missing privacy fence"),
            Self::MissingBudget(id) => write!(f, "packet `{id}` missing budget ref"),
            Self::MissingTokenDigest(id) => write!(f, "packet `{id}` missing token digest"),
            Self::MissingLayerSeparation => write!(f, "missing L1/L2/L3 separation"),
            Self::PacketIdMismatch(id) => write!(f, "packet `{id}` id/ref mismatch"),
            Self::PacketJsonDigestMismatch(id) => write!(f, "packet `{id}` JSON digest mismatch"),
            Self::PacketClaimsMissing(id) => write!(f, "packet `{id}` has no claims"),
            Self::PacketClaimKindMissing(kind) => write!(f, "packet missing claim kind `{kind}`"),
            Self::PacketClaimNotActive(id) => write!(f, "packet `{id}` has inactive claim"),
            Self::PacketAttentionModeMismatch(id) => {
                write!(f, "packet `{id}` has wrong attention mode")
            }
            Self::StaticFallbackContradiction(id) => {
                write!(f, "packet `{id}` has static-fallback contradiction")
            }
            Self::PacketUiLabelOverclaim(id) => write!(f, "packet `{id}` overclaims UI label"),
            Self::ResidencySignalMissing(id) => {
                write!(f, "packet `{id}` missing residency signal")
            }
            Self::ResidencySignalNonNeutral(id) => {
                write!(f, "packet `{id}` has non-neutral residency signal")
            }
            Self::RunEventLogNotDense(id) => write!(f, "packet `{id}` RunEventLog not dense"),
            Self::RunEventLogMissingStop(id) => {
                write!(f, "packet `{id}` RunEventLog missing one EndTurn stop")
            }
            Self::RunEventLogHasErrors(id) => write!(f, "packet `{id}` RunEventLog has errors"),
            Self::RunEventLogRootMismatch(id) => {
                write!(f, "packet `{id}` RunEventLog root mismatch")
            }
            Self::RedactedFinalTextMissing(id) => {
                write!(f, "packet `{id}` missing redacted final text")
            }
            Self::TokenDigestMalformed(id) => write!(f, "packet `{id}` has malformed token digest"),
            Self::TokenTextRetained(id) => write!(f, "packet `{id}` retained raw token text"),
            Self::PromptUserData(id) => write!(f, "packet `{id}` used prompt user data"),
            Self::MutationCommitted(id) => write!(f, "packet `{id}` committed mutation"),
            Self::RoutePolicyMutation(id) => write!(f, "packet `{id}` mutated route policy"),
            Self::GateBypass(id) => write!(f, "packet `{id}` bypassed admission gate"),
            Self::AnswerPacketSuppression(id) => write!(f, "packet `{id}` suppressed packet"),
            Self::HiddenRouteAuthority(id) => write!(f, "packet `{id}` attempted hidden authority"),
            Self::HiddenChainExposure(id) => write!(f, "packet `{id}` exposed hidden chain"),
            Self::HiddenCloudFallback(id) => write!(f, "packet `{id}` allowed hidden cloud"),
            Self::AppPathSubprocessSpawn(id) => write!(f, "packet `{id}` spawned in app path"),
            Self::AutogenousKernelAttempt(id) => {
                write!(f, "packet `{id}` attempted autogenous kernel")
            }
            Self::SeventyBProbeAttempt(id) => write!(f, "packet `{id}` attempted 70B probe"),
            Self::LongContextShardProbeAttempt(id) => {
                write!(f, "packet `{id}` attempted long-context shard")
            }
            Self::NewRuntimeBytesLoaded(id) => {
                write!(f, "packet `{id}` loaded new runtime bytes")
            }
            Self::NewModelBytesLoaded(id) => write!(f, "packet `{id}` loaded new model bytes"),
            Self::UpstreamRuntimeBytesMissing(id) => {
                write!(f, "packet `{id}` missing upstream runtime bytes")
            }
            Self::UpstreamModelBytesMissing(id) => {
                write!(f, "packet `{id}` missing upstream model bytes")
            }
            Self::MasOverclaimAttempted => write!(f, "MAS overclaim attempted"),
            Self::L2GreenClaimAttempted => write!(f, "L2 green claim attempted"),
            Self::L3GreenClaimAttempted => write!(f, "L3 green claim attempted"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for SmallModelRuntimeHarnessAnswerPacketProbeError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-answer-packet-runtime-probe:surface
// Plane: State + Verification
// Residency: visible canon/source surface evidence.
pub struct SmallModelAnswerPacketRuntimeProbeSurface {
    pub surface_id: String,
    pub source_ref: String,
    pub observed_text: String,
    pub required_markers: Vec<String>,
    pub forbidden_markers: Vec<String>,
}

impl SmallModelAnswerPacketRuntimeProbeSurface {
    pub fn new(
        surface_id: impl Into<String>,
        source_ref: impl Into<String>,
        observed_text: impl Into<String>,
        required_markers: Vec<String>,
        forbidden_markers: Vec<String>,
    ) -> Result<Self, SmallModelRuntimeHarnessAnswerPacketProbeError> {
        let surface = Self {
            surface_id: surface_id.into(),
            source_ref: source_ref.into(),
            observed_text: observed_text.into(),
            required_markers,
            forbidden_markers,
        };
        validate_clean("surface_id", &surface.surface_id)?;
        validate_clean("source_ref", &surface.source_ref)?;
        if surface.observed_text.trim().len() < MIN_SURFACE_TEXT_BYTES {
            return Err(SmallModelRuntimeHarnessAnswerPacketProbeError::EmptySurface);
        }
        for marker in &surface.required_markers {
            validate_clean("required_marker", marker)?;
            if !surface.observed_text.contains(marker) {
                return Err(
                    SmallModelRuntimeHarnessAnswerPacketProbeError::MissingRequiredMarker(
                        marker.clone(),
                    ),
                );
            }
        }
        for marker in &surface.forbidden_markers {
            validate_clean("forbidden_marker", marker)?;
            if surface.observed_text.contains(marker) {
                return Err(
                    SmallModelRuntimeHarnessAnswerPacketProbeError::ForbiddenMarker(marker.clone()),
                );
            }
        }
        Ok(surface)
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-answer-packet-runtime-probe:packet
// Plane: Controller + Verification
// Residency: retained packetized first-token runtime evidence.
pub struct SmallModelAnswerPacketRuntimeProbePacket {
    pub packet_id: String,
    pub first_token_artifact_ref: String,
    pub live_probe_sidecar_ref: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub run_event_log_root_ref: String,
    pub packet_json_ref: String,
    pub witnessed_state_ref: String,
    pub mutation_envelope_ref: String,
    pub semantic_delta_ref: String,
    pub rollback_ref: String,
    pub admission_ref: String,
    pub scope_rex_ref: String,
    pub sovereign_gate_ref: String,
    pub compatibility_fence_ref: String,
    pub cancellation_ref: String,
    pub privacy_ref: String,
    pub budget_ref: String,
    pub token_digest_ref: String,
    pub phases: Vec<SmallModelAnswerPacketRuntimeProbePhase>,
    pub answer_packet: AnswerPacket,
    pub run_event_log: RunEventLog,
    pub packet_json_sha256: String,
    pub prompt_contains_user_data: bool,
    pub raw_token_text_retained: bool,
    pub committed_mutation: bool,
    pub route_policy_mutation_attempted: bool,
    pub gate_bypass_attempted: bool,
    pub answer_packet_suppressed: bool,
    pub hidden_route_authority_attempted: bool,
    pub hidden_chain_exposed: bool,
    pub hidden_cloud_fallback_allowed: bool,
    pub subprocess_spawned_in_app_path: bool,
    pub autogenous_kernel_attempted: bool,
    pub seventy_b_probe_attempted: bool,
    pub long_context_shard_probe_attempted: bool,
    pub upstream_runtime_bytes_loaded: u64,
    pub upstream_model_bytes_loaded: u64,
    pub packetization_runtime_bytes_loaded: u64,
    pub packetization_model_bytes_loaded: u64,
}

impl SmallModelAnswerPacketRuntimeProbePacket {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        packet_id: impl Into<String>,
        first_token_artifact_ref: impl Into<String>,
        live_probe_sidecar_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        run_event_log_root_ref: impl Into<String>,
        packet_json_ref: impl Into<String>,
        witnessed_state_ref: impl Into<String>,
        mutation_envelope_ref: impl Into<String>,
        semantic_delta_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        admission_ref: impl Into<String>,
        scope_rex_ref: impl Into<String>,
        sovereign_gate_ref: impl Into<String>,
        compatibility_fence_ref: impl Into<String>,
        cancellation_ref: impl Into<String>,
        privacy_ref: impl Into<String>,
        budget_ref: impl Into<String>,
        token_digest_ref: impl Into<String>,
        phases: Vec<SmallModelAnswerPacketRuntimeProbePhase>,
        answer_packet: AnswerPacket,
        run_event_log: RunEventLog,
        packet_json_sha256: impl Into<String>,
        upstream_runtime_bytes_loaded: u64,
        upstream_model_bytes_loaded: u64,
    ) -> Result<Self, SmallModelRuntimeHarnessAnswerPacketProbeError> {
        let packet = Self {
            packet_id: packet_id.into(),
            first_token_artifact_ref: first_token_artifact_ref.into(),
            live_probe_sidecar_ref: live_probe_sidecar_ref.into(),
            answer_packet_ref: answer_packet_ref.into(),
            run_event_log_ref: run_event_log_ref.into(),
            run_event_log_root_ref: run_event_log_root_ref.into(),
            packet_json_ref: packet_json_ref.into(),
            witnessed_state_ref: witnessed_state_ref.into(),
            mutation_envelope_ref: mutation_envelope_ref.into(),
            semantic_delta_ref: semantic_delta_ref.into(),
            rollback_ref: rollback_ref.into(),
            admission_ref: admission_ref.into(),
            scope_rex_ref: scope_rex_ref.into(),
            sovereign_gate_ref: sovereign_gate_ref.into(),
            compatibility_fence_ref: compatibility_fence_ref.into(),
            cancellation_ref: cancellation_ref.into(),
            privacy_ref: privacy_ref.into(),
            budget_ref: budget_ref.into(),
            token_digest_ref: token_digest_ref.into(),
            phases,
            answer_packet,
            run_event_log,
            packet_json_sha256: packet_json_sha256.into(),
            prompt_contains_user_data: false,
            raw_token_text_retained: false,
            committed_mutation: false,
            route_policy_mutation_attempted: false,
            gate_bypass_attempted: false,
            answer_packet_suppressed: false,
            hidden_route_authority_attempted: false,
            hidden_chain_exposed: false,
            hidden_cloud_fallback_allowed: false,
            subprocess_spawned_in_app_path: false,
            autogenous_kernel_attempted: false,
            seventy_b_probe_attempted: false,
            long_context_shard_probe_attempted: false,
            upstream_runtime_bytes_loaded,
            upstream_model_bytes_loaded,
            packetization_runtime_bytes_loaded: 0,
            packetization_model_bytes_loaded: 0,
        };
        packet.validate()?;
        Ok(packet)
    }

    pub fn validate(&self) -> Result<(), SmallModelRuntimeHarnessAnswerPacketProbeError> {
        validate_clean("packet_id", &self.packet_id)?;
        validate_prefixed(
            &self.packet_id,
            &self.first_token_artifact_ref,
            FIRST_TOKEN_ARTIFACT_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingFirstTokenArtifact,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.live_probe_sidecar_ref,
            FIRST_TOKEN_SIDECAR_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingLiveProbeSidecar,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingAnswerPacket,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingRunEventLog,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.run_event_log_root_ref,
            RUN_EVENT_LOG_ROOT_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingRunEventLogRoot,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.packet_json_ref,
            PACKET_JSON_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingPacketJson,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.witnessed_state_ref,
            WITNESSED_STATE_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingWitnessedState,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.mutation_envelope_ref,
            MUTATION_ENVELOPE_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingMutationEnvelope,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.semantic_delta_ref,
            SEMANTIC_DELTA_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingSemanticDelta,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.rollback_ref,
            ROLLBACK_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingRollback,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.admission_ref,
            ADMISSION_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingAdmission,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.scope_rex_ref,
            SCOPE_REX_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingScopeRex,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.sovereign_gate_ref,
            SOVEREIGN_GATE_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingSovereignGate,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.compatibility_fence_ref,
            COMPATIBILITY_FENCE_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingCompatibilityFence,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.cancellation_ref,
            CANCELLATION_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingCancellation,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.privacy_ref,
            PRIVACY_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingPrivacyFence,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.budget_ref,
            BUDGET_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingBudget,
        )?;
        validate_prefixed(
            &self.packet_id,
            &self.token_digest_ref,
            TOKEN_SHA_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingTokenDigest,
        )?;
        if self.token_digest_ref.len() < MIN_TOKEN_SHA_LEN {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::TokenDigestMalformed(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.phases.is_empty() {
            return Err(SmallModelRuntimeHarnessAnswerPacketProbeError::EmptyPhase);
        }
        let phase_tags: BTreeSet<&str> = self.phases.iter().map(|phase| phase.tag()).collect();
        for phase in required_answer_packet_runtime_probe_phases() {
            if !phase_tags.contains(phase.tag()) {
                return Err(
                    SmallModelRuntimeHarnessAnswerPacketProbeError::MissingPhase(phase.tag()),
                );
            }
        }
        if self.answer_packet.id.0 != self.answer_packet_ref {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::PacketIdMismatch(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.answer_packet.witnessed_state_ref.0 != self.witnessed_state_ref {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::MissingWitnessedState(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.answer_packet.mutation_envelope_ref.0 != self.mutation_envelope_ref {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::MissingMutationEnvelope(
                    self.packet_id.clone(),
                ),
            );
        }
        if self
            .answer_packet
            .semantic_delta_ref
            .as_ref()
            .map(|delta| delta.0.as_str())
            != Some(self.semantic_delta_ref.as_str())
        {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::MissingSemanticDelta(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.answer_packet.claims.len() < 2 {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::PacketClaimsMissing(
                    self.packet_id.clone(),
                ),
            );
        }
        if self
            .answer_packet
            .claims
            .iter()
            .any(|claim| claim.status != ClaimStatus::Active)
        {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::PacketClaimNotActive(
                    self.packet_id.clone(),
                ),
            );
        }
        if !self
            .answer_packet
            .claims
            .iter()
            .any(|claim| claim.kind == ClaimKind::Empirical)
        {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::PacketClaimKindMissing("empirical"),
            );
        }
        if !self
            .answer_packet
            .claims
            .iter()
            .any(|claim| claim.kind == ClaimKind::CodeInvariant)
        {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::PacketClaimKindMissing(
                    "code_invariant",
                ),
            );
        }
        if self.answer_packet.attention_mode != AttentionMode::Dynamic {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::PacketAttentionModeMismatch(
                    self.packet_id.clone(),
                ),
            );
        }
        if !self.answer_packet.attention_mode_claims_are_consistent()
            || self
                .answer_packet
                .claims
                .iter()
                .any(|claim| claim.kind == ClaimKind::StaticFallbackAcknowledged)
        {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::StaticFallbackContradiction(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.answer_packet.ui_label == VrmLabel::Verified {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::PacketUiLabelOverclaim(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.answer_packet.residency_signals.len() != 1 {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::ResidencySignalMissing(
                    self.packet_id.clone(),
                ),
            );
        }
        let signal = self.answer_packet.residency_signals[0];
        if signal.safety_risk != 0.0
            || signal.privacy != 0.0
            || (signal.verification_score - 0.5).abs() > f32::EPSILON
            || signal.repeat_count != 0
            || signal.gain != 0.0
            || signal.forgetting != 0.0
        {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::ResidencySignalNonNeutral(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.run_event_log.validate_ordinal_density().is_err() {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::RunEventLogNotDense(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.run_event_log.stop_count() != 1
            || self.run_event_log.last_stop_event() != Some(StopReason::EndTurn)
        {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::RunEventLogMissingStop(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.run_event_log.error_count() != 0 {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::RunEventLogHasErrors(
                    self.packet_id.clone(),
                ),
            );
        }
        let expected_root = format!(
            "run_event_log_root:{}",
            self.run_event_log.root_hash().to_hex()
        );
        if self.run_event_log_root_ref != expected_root {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::RunEventLogRootMismatch(
                    self.packet_id.clone(),
                ),
            );
        }
        let packet_json = serde_json::to_vec(&self.answer_packet).map_err(|_| {
            SmallModelRuntimeHarnessAnswerPacketProbeError::PacketJsonDigestMismatch(
                self.packet_id.clone(),
            )
        })?;
        let packet_json_text = String::from_utf8_lossy(&packet_json);
        let log_json = serde_json::to_string(&self.run_event_log).map_err(|_| {
            SmallModelRuntimeHarnessAnswerPacketProbeError::RunEventLogRootMismatch(
                self.packet_id.clone(),
            )
        })?;
        let redacted_marker = format!("[redacted-first-token:{}]", self.token_digest_ref);
        if !log_json.contains(&redacted_marker) {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::RedactedFinalTextMissing(
                    self.packet_id.clone(),
                ),
            );
        }
        if packet_json_text.contains("raw_token")
            || packet_json_text.contains("first_token_preview")
            || log_json.contains("raw_token")
            || log_json.contains("first_token_preview")
            || self.raw_token_text_retained
        {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::TokenTextRetained(
                    self.packet_id.clone(),
                ),
            );
        }
        let expected_packet_sha = sha256_hex(&packet_json);
        if self.packet_json_sha256 != expected_packet_sha
            || self.packet_json_ref != format!("answer_packet_json:{expected_packet_sha}")
        {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::PacketJsonDigestMismatch(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.prompt_contains_user_data {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::PromptUserData(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.committed_mutation {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::MutationCommitted(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.route_policy_mutation_attempted {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::RoutePolicyMutation(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.gate_bypass_attempted {
            return Err(SmallModelRuntimeHarnessAnswerPacketProbeError::GateBypass(
                self.packet_id.clone(),
            ));
        }
        if self.answer_packet_suppressed {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::AnswerPacketSuppression(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.hidden_route_authority_attempted {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::HiddenRouteAuthority(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.hidden_chain_exposed {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::HiddenChainExposure(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.hidden_cloud_fallback_allowed {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::HiddenCloudFallback(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.subprocess_spawned_in_app_path {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::AppPathSubprocessSpawn(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.autogenous_kernel_attempted {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::AutogenousKernelAttempt(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.seventy_b_probe_attempted {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::SeventyBProbeAttempt(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.long_context_shard_probe_attempted {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::LongContextShardProbeAttempt(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.packetization_runtime_bytes_loaded != 0 {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::NewRuntimeBytesLoaded(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.packetization_model_bytes_loaded != 0 {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::NewModelBytesLoaded(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.upstream_runtime_bytes_loaded == 0 {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::UpstreamRuntimeBytesMissing(
                    self.packet_id.clone(),
                ),
            );
        }
        if self.upstream_model_bytes_loaded == 0 {
            return Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::UpstreamModelBytesMissing(
                    self.packet_id.clone(),
                ),
            );
        }
        Ok(())
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-answer-packet-runtime-probe:metrics
// Plane: Verification
// Residency: aggregate packetized first-token runtime metrics.
pub struct SmallModelRuntimeHarnessAnswerPacketProbeMetrics {
    pub packet_count: u64,
    pub surface_count: u64,
    pub phase_count: u64,
    pub claim_count: u64,
    pub residency_signal_count: u64,
    pub run_event_log_entry_count: u64,
    pub run_event_log_stop_count: u64,
    pub upstream_runtime_bytes_loaded: u64,
    pub upstream_model_bytes_loaded: u64,
    pub packetization_runtime_bytes_loaded: u64,
    pub packetization_model_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-answer-packet-runtime-probe:witness
// Plane: Controller + Verification
// Residency: complete packetized first-token runtime witness.
pub struct SmallModelRuntimeHarnessAnswerPacketProbeWitness {
    pub witness_id: String,
    pub first_token_artifact_ref: String,
    pub guard_next_existing_work: String,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub packets: Vec<SmallModelAnswerPacketRuntimeProbePacket>,
    pub surfaces: Vec<SmallModelAnswerPacketRuntimeProbeSurface>,
    pub metadata_bytes: u64,
    pub l1_l2_l3_separated: bool,
    pub mas_overclaim_attempted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
}

impl SmallModelRuntimeHarnessAnswerPacketProbeWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        first_token_artifact_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        packets: Vec<SmallModelAnswerPacketRuntimeProbePacket>,
        surfaces: Vec<SmallModelAnswerPacketRuntimeProbeSurface>,
        metadata_bytes: u64,
        l1_l2_l3_separated: bool,
        mas_overclaim_attempted: bool,
        l2_green_claimed: bool,
        l3_green_claimed: bool,
    ) -> Result<Self, SmallModelRuntimeHarnessAnswerPacketProbeError> {
        let witness = Self {
            witness_id: witness_id.into(),
            first_token_artifact_ref: first_token_artifact_ref.into(),
            guard_next_existing_work: guard_next_existing_work.into(),
            capability_route_status: capability_route_status.into(),
            capability_next_bottleneck: capability_next_bottleneck.into(),
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            packets,
            surfaces,
            metadata_bytes,
            l1_l2_l3_separated,
            mas_overclaim_attempted,
            l2_green_claimed,
            l3_green_claimed,
        };
        witness.validate()?;
        Ok(witness)
    }

    pub fn validate(&self) -> Result<(), SmallModelRuntimeHarnessAnswerPacketProbeError> {
        validate_clean("witness_id", &self.witness_id)?;
        validate_prefixed(
            &self.witness_id,
            &self.first_token_artifact_ref,
            FIRST_TOKEN_ARTIFACT_PREFIX,
            SmallModelRuntimeHarnessAnswerPacketProbeError::MissingFirstTokenArtifact,
        )?;
        if self.guard_next_existing_work
            != SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_CURSOR
            && self.guard_next_existing_work
                != SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_NEXT_CURSOR
            && self.guard_next_existing_work != ADVANCED_RELEASE_AUDIT_CURSOR
        {
            return Err(SmallModelRuntimeHarnessAnswerPacketProbeError::GuardCursorMismatch);
        }
        if self.capability_route_status != "vault_research_route_with_packetized_mitigation"
            || (self.capability_next_bottleneck
                != SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_CURSOR
                && self.capability_next_bottleneck
                    != SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_NEXT_CURSOR
                && self.capability_next_bottleneck != ADVANCED_RELEASE_AUDIT_CURSOR)
        {
            return Err(SmallModelRuntimeHarnessAnswerPacketProbeError::CapabilityStatusMismatch);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::ResearchCandidate
            || self.route_authority != "packetized_first_token_visible_proof_only"
        {
            return Err(SmallModelRuntimeHarnessAnswerPacketProbeError::ProductStatusMismatch);
        }
        if self.packets.is_empty() {
            return Err(SmallModelRuntimeHarnessAnswerPacketProbeError::EmptyPacket);
        }
        if self.surfaces.is_empty() {
            return Err(SmallModelRuntimeHarnessAnswerPacketProbeError::EmptySurface);
        }
        let mut packet_ids = HashSet::new();
        for packet in &self.packets {
            packet.validate()?;
            if !packet_ids.insert(packet.packet_id.clone()) {
                return Err(
                    SmallModelRuntimeHarnessAnswerPacketProbeError::DuplicatePacket(
                        packet.packet_id.clone(),
                    ),
                );
            }
        }
        let mut surface_ids = HashSet::new();
        for surface in &self.surfaces {
            if !surface_ids.insert(surface.surface_id.clone()) {
                return Err(
                    SmallModelRuntimeHarnessAnswerPacketProbeError::DuplicateSurface(
                        surface.surface_id.clone(),
                    ),
                );
            }
        }
        if !self.l1_l2_l3_separated {
            return Err(SmallModelRuntimeHarnessAnswerPacketProbeError::MissingLayerSeparation);
        }
        if self.mas_overclaim_attempted {
            return Err(SmallModelRuntimeHarnessAnswerPacketProbeError::MasOverclaimAttempted);
        }
        if self.l2_green_claimed {
            return Err(SmallModelRuntimeHarnessAnswerPacketProbeError::L2GreenClaimAttempted);
        }
        if self.l3_green_claimed {
            return Err(SmallModelRuntimeHarnessAnswerPacketProbeError::L3GreenClaimAttempted);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(SmallModelRuntimeHarnessAnswerPacketProbeError::MetadataBudgetExceeded);
        }
        Ok(())
    }

    pub fn metrics(&self) -> SmallModelRuntimeHarnessAnswerPacketProbeMetrics {
        let phase_count = self
            .packets
            .iter()
            .flat_map(|packet| packet.phases.iter().map(|phase| phase.tag()))
            .collect::<BTreeSet<_>>()
            .len() as u64;
        SmallModelRuntimeHarnessAnswerPacketProbeMetrics {
            packet_count: self.packets.len() as u64,
            surface_count: self.surfaces.len() as u64,
            phase_count,
            claim_count: self
                .packets
                .iter()
                .map(|packet| packet.answer_packet.claims.len() as u64)
                .sum(),
            residency_signal_count: self
                .packets
                .iter()
                .map(|packet| packet.answer_packet.residency_signals.len() as u64)
                .sum(),
            run_event_log_entry_count: self
                .packets
                .iter()
                .map(|packet| packet.run_event_log.len() as u64)
                .sum(),
            run_event_log_stop_count: self
                .packets
                .iter()
                .map(|packet| packet.run_event_log.stop_count() as u64)
                .sum(),
            upstream_runtime_bytes_loaded: self
                .packets
                .iter()
                .map(|packet| packet.upstream_runtime_bytes_loaded)
                .sum(),
            upstream_model_bytes_loaded: self
                .packets
                .iter()
                .map(|packet| packet.upstream_model_bytes_loaded)
                .sum(),
            packetization_runtime_bytes_loaded: self
                .packets
                .iter()
                .map(|packet| packet.packetization_runtime_bytes_loaded)
                .sum(),
            packetization_model_bytes_loaded: self
                .packets
                .iter()
                .map(|packet| packet.packetization_model_bytes_loaded)
                .sum(),
        }
    }

    pub fn address(&self) -> String {
        let mut parts = vec![
            self.witness_id.clone(),
            self.first_token_artifact_ref.clone(),
            self.guard_next_existing_work.clone(),
            self.capability_route_status.clone(),
            self.capability_next_bottleneck.clone(),
            self.route_authority.clone(),
        ];
        for packet in &self.packets {
            parts.push(packet.packet_id.clone());
            parts.push(packet.answer_packet_ref.clone());
            parts.push(packet.run_event_log_ref.clone());
            parts.push(packet.run_event_log_root_ref.clone());
            parts.push(packet.packet_json_ref.clone());
            parts.push(packet.semantic_delta_ref.clone());
            parts.push(packet.token_digest_ref.clone());
        }
        parts.sort();
        sha256_hex(parts.join("|").as_bytes())
    }
}

pub fn required_answer_packet_runtime_probe_phases() -> [SmallModelAnswerPacketRuntimeProbePhase; 12]
{
    [
        SmallModelAnswerPacketRuntimeProbePhase::FirstTokenArtifactBound,
        SmallModelAnswerPacketRuntimeProbePhase::LiveProbeSidecarBound,
        SmallModelAnswerPacketRuntimeProbePhase::PacketProducerBound,
        SmallModelAnswerPacketRuntimeProbePhase::AnswerPacketSerialized,
        SmallModelAnswerPacketRuntimeProbePhase::ClaimsBound,
        SmallModelAnswerPacketRuntimeProbePhase::AttentionModeChecked,
        SmallModelAnswerPacketRuntimeProbePhase::ResidencySignalBound,
        SmallModelAnswerPacketRuntimeProbePhase::RunEventLogSerialized,
        SmallModelAnswerPacketRuntimeProbePhase::RunEventLogRootBound,
        SmallModelAnswerPacketRuntimeProbePhase::TokenRedactionVerified,
        SmallModelAnswerPacketRuntimeProbePhase::RollbackVerified,
        SmallModelAnswerPacketRuntimeProbePhase::EvidenceReviewPending,
    ]
}

pub fn redacted_first_token_run_event_log(token_digest_ref: &str) -> RunEventLog {
    let mut log = RunEventLog::new();
    log.append_event(AgentEvent::FinalText {
        text: format!("[redacted-first-token:{token_digest_ref}]"),
    });
    log.append_event(AgentEvent::Stop {
        reason: StopReason::EndTurn,
    });
    log
}

fn validate_prefixed(
    packet_id: &str,
    value: &str,
    prefix: &str,
    error: fn(String) -> SmallModelRuntimeHarnessAnswerPacketProbeError,
) -> Result<(), SmallModelRuntimeHarnessAnswerPacketProbeError> {
    validate_clean("prefixed_ref", value)?;
    if !value.starts_with(prefix) {
        return Err(error(packet_id.to_string()));
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelRuntimeHarnessAnswerPacketProbeError> {
    if value.is_empty() {
        return Err(SmallModelRuntimeHarnessAnswerPacketProbeError::MissingField(field));
    }
    if value.trim() != value {
        return Err(
            SmallModelRuntimeHarnessAnswerPacketProbeError::FieldHasSurroundingWhitespace(field),
        );
    }
    if value.chars().any(|ch| ch.is_control()) {
        return Err(
            SmallModelRuntimeHarnessAnswerPacketProbeError::FieldContainsControlCharacter(field),
        );
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::provenance::ledger::{Claim, ClaimId};
    use crate::scope_rex::answer_packet::{
        AnswerPacketId, MutationEnvelopeId, SemanticDeltaId, WitnessedStateId,
    };

    fn phases() -> Vec<SmallModelAnswerPacketRuntimeProbePhase> {
        required_answer_packet_runtime_probe_phases().to_vec()
    }

    fn packet_value(id: &str) -> AnswerPacket {
        AnswerPacket::new(
            AnswerPacketId::new(format!("answer_packet:{id}")),
            WitnessedStateId::new("witnessed_state:first_token:qwen3_4b"),
            MutationEnvelopeId::new("mutation_envelope:no_mutation:qwen3_4b"),
        )
        .with_attention_mode(AttentionMode::Dynamic)
        .with_ui_label(VrmLabel::PlausibleButUnverified)
        .with_semantic_delta(SemanticDeltaId::new(
            "semantic_delta:redacted_first_token:qwen3_4b",
        ))
        .push_claim(
            Claim::new(
                ClaimId::new(format!("{id}:empirical")),
                "small-model harness emitted exactly one redacted local first token",
                1_779_552_000_000,
            )
            .with_kind(ClaimKind::Empirical),
        )
        .push_claim(
            Claim::new(
                ClaimId::new(format!("{id}:code-invariant")),
                "raw token text was not retained; prompt hash carries no user data",
                1_779_552_000_000,
            )
            .with_kind(ClaimKind::CodeInvariant),
        )
        .push_residency_signal(crate::scope_rex::answer_packet::ResidencySignal::neutral())
    }

    fn packet(id: &str) -> SmallModelAnswerPacketRuntimeProbePacket {
        let answer_packet = packet_value(id);
        let packet_json = serde_json::to_vec(&answer_packet).expect("packet serializes");
        let packet_sha = sha256_hex(&packet_json);
        let token_ref =
            "token_sha256:d03502c43d74a30b936740a9517dc4ea2b2ad7168caa0a774cefe793ce0b33e7";
        let log = redacted_first_token_run_event_log(token_ref);
        let log_root = format!("run_event_log_root:{}", log.root_hash().to_hex());
        SmallModelAnswerPacketRuntimeProbePacket::new(
            id,
            "artifact:small_model_runtime_harness_first_token_runtime_probe:result",
            "artifact:small_model_runtime_harness_first_token_runtime_probe:live_probe:sha256:test",
            answer_packet.id.0.clone(),
            "run_event_log:qwen3_4b:first-token-answer-packet",
            log_root,
            format!("answer_packet_json:{packet_sha}"),
            answer_packet.witnessed_state_ref.0.clone(),
            answer_packet.mutation_envelope_ref.0.clone(),
            answer_packet
                .semantic_delta_ref
                .as_ref()
                .expect("semantic delta")
                .0
                .clone(),
            "rollback:qwen3_4b:no-mutation",
            "admission:qwen3_4b:scope-rex",
            "scope_rex:qwen3_4b:first-token-answer-packet",
            "sovereign_gate:qwen3_4b:research-candidate",
            "compat:qwen3_4b:mlx-small-answer-packet-v1",
            "cancel:qwen3_4b:packetization-only",
            "privacy:qwen3_4b:local-only-redacted-token",
            "budget:qwen3_4b:packetization-zero-runtime-bytes",
            token_ref,
            phases(),
            answer_packet,
            log,
            packet_sha,
            2_153_272_351,
            2_153_272_351,
        )
        .expect("valid packet")
    }

    fn surface(id: &str) -> SmallModelAnswerPacketRuntimeProbeSurface {
        SmallModelAnswerPacketRuntimeProbeSurface::new(
            id,
            format!("surface:{id}"),
            "Epistemos is a local cognitive substrate where every meaningful object has an address, plane, budget, status, and witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega ladder, and no claim promotes without visible proof. small_model_runtime_harness_answer_packet_runtime_probe packetizes the retained first-token witness through AnswerPacket RunEventLog rollback privacy budget without making L2 or L3 green and without live 70B or long-context shard work.",
            vec![
                "Epistemos is a local cognitive substrate".to_string(),
                "small_model_runtime_harness_answer_packet_runtime_probe".to_string(),
                "AnswerPacket".to_string(),
                "RunEventLog".to_string(),
            ],
            vec![
                "small model runtime is product-live".to_string(),
                "live 70B is done".to_string(),
            ],
        )
        .expect("valid surface")
    }

    fn witness() -> SmallModelRuntimeHarnessAnswerPacketProbeWitness {
        SmallModelRuntimeHarnessAnswerPacketProbeWitness::new(
            "answer-packet-witness",
            "artifact:small_model_runtime_harness_first_token_runtime_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_CURSOR,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_ANSWER_PACKET_RUNTIME_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            "packetized_first_token_visible_proof_only",
            vec![packet("answer_packet:qwen3_4b:first-token-runtime")],
            vec![surface("living_index"), surface("lattice_html")],
            4096,
            true,
            false,
            false,
            false,
        )
        .expect("valid witness")
    }

    #[test]
    fn deterministic_address_and_packet_metrics() {
        let good = witness();
        assert!(!good.address().is_empty());
        let metrics = good.metrics();
        assert_eq!(metrics.packet_count, 1);
        assert_eq!(metrics.phase_count, 12);
        assert_eq!(metrics.claim_count, 2);
        assert_eq!(metrics.residency_signal_count, 1);
        assert_eq!(metrics.run_event_log_entry_count, 2);
        assert_eq!(metrics.run_event_log_stop_count, 1);
        assert_eq!(metrics.packetization_runtime_bytes_loaded, 0);
        assert!(metrics.upstream_runtime_bytes_loaded > 0);
    }

    #[test]
    fn duplicate_packet_is_rejected() {
        let mut good = witness();
        good.packets.push(good.packets[0].clone());
        assert!(matches!(
            good.validate(),
            Err(SmallModelRuntimeHarnessAnswerPacketProbeError::DuplicatePacket(_))
        ));
    }

    #[test]
    fn static_fallback_ack_on_dynamic_is_rejected() {
        let mut bad = packet("answer_packet:qwen3_4b:first-token-runtime");
        bad.answer_packet = bad.answer_packet.push_claim(
            Claim::new(
                ClaimId::new("bad-static-ack"),
                "static fallback acknowledged even though dynamic attention was used",
                1,
            )
            .with_kind(ClaimKind::StaticFallbackAcknowledged),
        );
        assert!(matches!(
            bad.validate(),
            Err(SmallModelRuntimeHarnessAnswerPacketProbeError::StaticFallbackContradiction(_))
        ));
    }

    #[test]
    fn verified_ui_label_is_rejected_for_runtime_packetization() {
        let mut bad = packet("answer_packet:qwen3_4b:first-token-runtime");
        bad.answer_packet.ui_label = VrmLabel::Verified;
        assert!(matches!(
            bad.validate(),
            Err(SmallModelRuntimeHarnessAnswerPacketProbeError::PacketUiLabelOverclaim(_))
        ));
    }

    #[test]
    fn missing_code_invariant_claim_is_rejected() {
        let mut bad = packet("answer_packet:qwen3_4b:first-token-runtime");
        bad.answer_packet
            .claims
            .retain(|claim| claim.kind != ClaimKind::CodeInvariant);
        bad.answer_packet = bad.answer_packet.push_claim(
            Claim::new(
                ClaimId::new("extra-empirical"),
                "second empirical claim keeps claim-count valid while code invariant is absent",
                1_779_552_000_000,
            )
            .with_kind(ClaimKind::Empirical),
        );
        let packet_json = serde_json::to_vec(&bad.answer_packet).expect("packet serializes");
        bad.packet_json_sha256 = sha256_hex(&packet_json);
        bad.packet_json_ref = format!("answer_packet_json:{}", bad.packet_json_sha256);
        assert!(matches!(
            bad.validate(),
            Err(
                SmallModelRuntimeHarnessAnswerPacketProbeError::PacketClaimKindMissing(
                    "code_invariant"
                )
            )
        ));
    }

    #[test]
    fn raw_token_text_marker_is_rejected() {
        let mut bad = packet("answer_packet:qwen3_4b:first-token-runtime");
        bad.answer_packet = bad.answer_packet.push_claim(
            Claim::new(ClaimId::new("bad-raw-token"), "raw_token_text=leaked", 1)
                .with_kind(ClaimKind::Empirical),
        );
        assert!(matches!(
            bad.validate(),
            Err(SmallModelRuntimeHarnessAnswerPacketProbeError::TokenTextRetained(_))
        ));
    }

    #[test]
    fn run_event_log_missing_stop_is_rejected() {
        let mut bad = packet("answer_packet:qwen3_4b:first-token-runtime");
        let mut log = RunEventLog::new();
        log.append_event(AgentEvent::FinalText {
            text: format!("[redacted-first-token:{}]", bad.token_digest_ref),
        });
        bad.run_event_log = log;
        bad.run_event_log_root_ref = format!(
            "run_event_log_root:{}",
            bad.run_event_log.root_hash().to_hex()
        );
        assert!(matches!(
            bad.validate(),
            Err(SmallModelRuntimeHarnessAnswerPacketProbeError::RunEventLogMissingStop(_))
        ));
    }

    #[test]
    fn new_runtime_bytes_are_rejected() {
        let mut bad = packet("answer_packet:qwen3_4b:first-token-runtime");
        bad.packetization_runtime_bytes_loaded = 1;
        assert!(matches!(
            bad.validate(),
            Err(SmallModelRuntimeHarnessAnswerPacketProbeError::NewRuntimeBytesLoaded(_))
        ));
    }

    #[test]
    fn hidden_70b_and_long_context_are_rejected() {
        let mut bad = packet("answer_packet:qwen3_4b:first-token-runtime");
        bad.seventy_b_probe_attempted = true;
        assert!(matches!(
            bad.validate(),
            Err(SmallModelRuntimeHarnessAnswerPacketProbeError::SeventyBProbeAttempt(_))
        ));
        let mut bad = packet("answer_packet:qwen3_4b:first-token-runtime");
        bad.long_context_shard_probe_attempted = true;
        assert!(matches!(
            bad.validate(),
            Err(SmallModelRuntimeHarnessAnswerPacketProbeError::LongContextShardProbeAttempt(_))
        ));
    }
}
