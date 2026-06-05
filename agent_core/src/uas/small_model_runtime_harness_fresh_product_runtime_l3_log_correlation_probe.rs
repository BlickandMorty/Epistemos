//! Fresh product-runtime L3 log-correlation probe for the small-model harness.
//!
//! This witness consumes the fresh runtime sidecar, AnswerPacket, RunEventLog,
//! source WRV, and capability-blocker ledger, then proves those records agree.
//! It does not run inference, open model bytes, promote MAS live-agent claims,
//! or mark L2/L3 product capability green.

use std::collections::BTreeSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe";
pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_NEXT_CURSOR:
    &str = "small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe";

const CAPABILITY_RECHECK_ARTIFACT_PREFIX: &str =
    "artifact:small_model_runtime_harness_fresh_product_runtime_capability_recheck:";
const ANSWER_PACKET_ARTIFACT_PREFIX: &str =
    "artifact:small_model_runtime_harness_fresh_product_runtime_answer_packet_probe:";
const WRV_ARTIFACT_PREFIX: &str =
    "artifact:small_model_runtime_harness_fresh_product_runtime_wrv_probe:";
const LIVE_SIDECAR_PREFIX: &str =
    "artifact:small_model_runtime_harness_fresh_product_runtime_live_probe:live_probe:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const TOKEN_SHA_PREFIX: &str = "token_sha256:";
const PROMPT_SHA_PREFIX: &str = "sha256:";
const SURFACE_PREFIX: &str = "surface:";
const MAX_METADATA_BYTES: u64 = 640 * 1024;
const MIN_SOURCE_REFS: u64 = 10;
const MIN_TEST_REFS: u64 = 4;
const MIN_VISIBLE_SURFACES: u64 = 3;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-log-correlation-probe:phase
// Plane: Verification
// Residency: visible log-correlation proof phase after fresh runtime WRV.
pub enum SmallModelFreshProductRuntimeL3LogCorrelationPhase {
    CapabilityRecheckArtifactBound,
    FreshAnswerPacketArtifactBound,
    FreshWrvArtifactBound,
    LiveProbeSidecarBound,
    AnswerPacketJsonBound,
    RunEventLogSidecarBound,
    TokenDigestCorrelated,
    StopReasonCorrelated,
    PromptPrivacyCorrelated,
    SourceWrvCorrelated,
    CapabilityKernelRedBound,
    ManualVerificationProbeQueued,
}

impl SmallModelFreshProductRuntimeL3LogCorrelationPhase {
    pub fn tag(&self) -> &'static str {
        match self {
            Self::CapabilityRecheckArtifactBound => "capability_recheck_artifact_bound",
            Self::FreshAnswerPacketArtifactBound => "fresh_answer_packet_artifact_bound",
            Self::FreshWrvArtifactBound => "fresh_wrv_artifact_bound",
            Self::LiveProbeSidecarBound => "live_probe_sidecar_bound",
            Self::AnswerPacketJsonBound => "answer_packet_json_bound",
            Self::RunEventLogSidecarBound => "run_event_log_sidecar_bound",
            Self::TokenDigestCorrelated => "token_digest_correlated",
            Self::StopReasonCorrelated => "stop_reason_correlated",
            Self::PromptPrivacyCorrelated => "prompt_privacy_correlated",
            Self::SourceWrvCorrelated => "source_wrv_correlated",
            Self::CapabilityKernelRedBound => "capability_kernel_red_bound",
            Self::ManualVerificationProbeQueued => "manual_verification_probe_queued",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-log-correlation-probe:error
// Plane: Verification
// Residency: log-correlation rejection taxonomy.
pub enum SmallModelFreshProductRuntimeL3LogCorrelationError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    MissingArtifactRef(&'static str),
    ProductStatusMismatch,
    CapabilityStatusMismatch,
    GuardCursorMismatch,
    EmptyCorrelation,
    DuplicateCorrelation(String),
    EmptyPhase,
    MissingPhase(&'static str),
    MissingAnswerPacket(String),
    MissingRunEventLog(String),
    MissingLiveSidecar(String),
    MissingTokenDigest(String),
    TokenDigestMismatch(String),
    MissingPromptHash(String),
    PromptUserDataRetained(String),
    RawTokenRetained(String),
    OutputTokenCountMismatch(String),
    RunEventLogMissingFinalText(String),
    RunEventLogMissingStop(String),
    RunEventLogHasErrors(String),
    StopReasonMismatch(String),
    SourceWrvCoverageMissing,
    ManualVerificationAlreadyGreen,
    RuntimeBytesMissing,
    ModelBytesMissing,
    CorrelationRuntimeBytesLoaded,
    CorrelationModelBytesLoaded,
    L1L2L3NotSeparated,
    HiddenAuthorityAttempted,
    RouteMutationAttempted,
    MasLiveAgentOverclaim,
    L2GreenClaimAttempted,
    L3GreenClaimAttempted,
    AutogenousKernelAttempted,
    SeventyBProductClaimed,
    LongContextShardProductClaimed,
    NextCursorMismatch,
    MetadataBudgetExceeded,
}

impl fmt::Display for SmallModelFreshProductRuntimeL3LogCorrelationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::MissingArtifactRef(kind) => write!(f, "missing artifact ref `{kind}`"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::EmptyCorrelation => write!(f, "missing log-correlation record"),
            Self::DuplicateCorrelation(id) => write!(f, "duplicate correlation `{id}`"),
            Self::EmptyPhase => write!(f, "missing log-correlation phase"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::MissingAnswerPacket(id) => write!(f, "correlation `{id}` missing AnswerPacket"),
            Self::MissingRunEventLog(id) => write!(f, "correlation `{id}` missing RunEventLog"),
            Self::MissingLiveSidecar(id) => write!(f, "correlation `{id}` missing live sidecar"),
            Self::MissingTokenDigest(id) => write!(f, "correlation `{id}` missing token digest"),
            Self::TokenDigestMismatch(id) => write!(f, "correlation `{id}` token digest mismatch"),
            Self::MissingPromptHash(id) => write!(f, "correlation `{id}` missing prompt hash"),
            Self::PromptUserDataRetained(id) => {
                write!(f, "correlation `{id}` retains user prompt data")
            }
            Self::RawTokenRetained(id) => write!(f, "correlation `{id}` retains raw token"),
            Self::OutputTokenCountMismatch(id) => {
                write!(f, "correlation `{id}` output token count mismatch")
            }
            Self::RunEventLogMissingFinalText(id) => {
                write!(f, "correlation `{id}` missing final text event")
            }
            Self::RunEventLogMissingStop(id) => write!(f, "correlation `{id}` missing stop event"),
            Self::RunEventLogHasErrors(id) => write!(f, "correlation `{id}` has log errors"),
            Self::StopReasonMismatch(id) => write!(f, "correlation `{id}` stop reason mismatch"),
            Self::SourceWrvCoverageMissing => write!(f, "source WRV coverage missing"),
            Self::ManualVerificationAlreadyGreen => write!(f, "manual verification already green"),
            Self::RuntimeBytesMissing => write!(f, "upstream runtime bytes missing"),
            Self::ModelBytesMissing => write!(f, "upstream model bytes missing"),
            Self::CorrelationRuntimeBytesLoaded => write!(f, "correlation loaded runtime bytes"),
            Self::CorrelationModelBytesLoaded => write!(f, "correlation loaded model bytes"),
            Self::L1L2L3NotSeparated => write!(f, "L1/L2/L3 separation missing"),
            Self::HiddenAuthorityAttempted => write!(f, "hidden authority attempted"),
            Self::RouteMutationAttempted => write!(f, "route mutation attempted"),
            Self::MasLiveAgentOverclaim => write!(f, "MAS live-agent overclaim attempted"),
            Self::L2GreenClaimAttempted => write!(f, "L2 green claim attempted"),
            Self::L3GreenClaimAttempted => write!(f, "L3 green claim attempted"),
            Self::AutogenousKernelAttempted => write!(f, "autogenous-kernel attempt detected"),
            Self::SeventyBProductClaimed => write!(f, "live 70B product claim attempted"),
            Self::LongContextShardProductClaimed => {
                write!(f, "live 128K shard product claim attempted")
            }
            Self::NextCursorMismatch => write!(f, "next cursor mismatch"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for SmallModelFreshProductRuntimeL3LogCorrelationError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-log-correlation-probe:record
// Plane: Verification
// Residency: one correlated AnswerPacket + RunEventLog + live-sidecar proof unit.
pub struct SmallModelFreshProductRuntimeL3LogCorrelationRecord {
    pub correlation_id: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub live_sidecar_ref: String,
    pub token_digest_ref: String,
    pub prompt_hash_ref: String,
    pub product_surface_ref: String,
    pub answer_packet_token_digest_ref: String,
    pub run_event_log_token_digest_ref: String,
    pub live_sidecar_token_digest_ref: String,
    pub answer_packet_stop_reason: String,
    pub run_event_log_stop_reason: String,
    pub output_token_count: u64,
    pub run_event_log_entry_count: u64,
    pub run_event_log_final_text_present: bool,
    pub run_event_log_stop_present: bool,
    pub run_event_log_error_count: u64,
    pub prompt_contains_user_data: bool,
    pub raw_token_text_retained: bool,
}

impl SmallModelFreshProductRuntimeL3LogCorrelationRecord {
    pub fn validate(&self) -> Result<(), SmallModelFreshProductRuntimeL3LogCorrelationError> {
        validate_clean("correlation_id", &self.correlation_id)?;
        validate_prefixed(
            "answer_packet_ref",
            &self.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
        )?;
        validate_prefixed(
            "run_event_log_ref",
            &self.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
        )?;
        validate_prefixed(
            "live_sidecar_ref",
            &self.live_sidecar_ref,
            LIVE_SIDECAR_PREFIX,
        )?;
        validate_prefixed("token_digest_ref", &self.token_digest_ref, TOKEN_SHA_PREFIX)?;
        validate_prefixed("prompt_hash_ref", &self.prompt_hash_ref, PROMPT_SHA_PREFIX)?;
        validate_prefixed(
            "product_surface_ref",
            &self.product_surface_ref,
            SURFACE_PREFIX,
        )?;
        validate_prefixed(
            "answer_packet_token_digest_ref",
            &self.answer_packet_token_digest_ref,
            TOKEN_SHA_PREFIX,
        )?;
        validate_prefixed(
            "run_event_log_token_digest_ref",
            &self.run_event_log_token_digest_ref,
            TOKEN_SHA_PREFIX,
        )?;
        validate_prefixed(
            "live_sidecar_token_digest_ref",
            &self.live_sidecar_token_digest_ref,
            TOKEN_SHA_PREFIX,
        )?;
        validate_clean("answer_packet_stop_reason", &self.answer_packet_stop_reason)?;
        validate_clean("run_event_log_stop_reason", &self.run_event_log_stop_reason)?;
        if self.answer_packet_ref.is_empty() {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::MissingAnswerPacket(
                    self.correlation_id.clone(),
                ),
            );
        }
        if self.run_event_log_ref.is_empty() {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::MissingRunEventLog(
                    self.correlation_id.clone(),
                ),
            );
        }
        if self.live_sidecar_ref.is_empty() {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::MissingLiveSidecar(
                    self.correlation_id.clone(),
                ),
            );
        }
        if self.token_digest_ref.is_empty() {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::MissingTokenDigest(
                    self.correlation_id.clone(),
                ),
            );
        }
        if self.prompt_hash_ref.is_empty() {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::MissingPromptHash(
                    self.correlation_id.clone(),
                ),
            );
        }
        if self.answer_packet_token_digest_ref != self.token_digest_ref
            || self.run_event_log_token_digest_ref != self.token_digest_ref
            || self.live_sidecar_token_digest_ref != self.token_digest_ref
        {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::TokenDigestMismatch(
                    self.correlation_id.clone(),
                ),
            );
        }
        if self.answer_packet_stop_reason != "end_turn"
            || self.run_event_log_stop_reason != "end_turn"
        {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::StopReasonMismatch(
                    self.correlation_id.clone(),
                ),
            );
        }
        if self.output_token_count != 1 {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::OutputTokenCountMismatch(
                    self.correlation_id.clone(),
                ),
            );
        }
        if !self.run_event_log_final_text_present {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::RunEventLogMissingFinalText(
                    self.correlation_id.clone(),
                ),
            );
        }
        if !self.run_event_log_stop_present {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::RunEventLogMissingStop(
                    self.correlation_id.clone(),
                ),
            );
        }
        if self.run_event_log_error_count != 0 {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::RunEventLogHasErrors(
                    self.correlation_id.clone(),
                ),
            );
        }
        if self.prompt_contains_user_data {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::PromptUserDataRetained(
                    self.correlation_id.clone(),
                ),
            );
        }
        if self.raw_token_text_retained {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::RawTokenRetained(
                    self.correlation_id.clone(),
                ),
            );
        }
        Ok(())
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-log-correlation-probe:metrics
// Plane: Verification
// Residency: log-correlation counts and byte accounting.
pub struct SmallModelFreshProductRuntimeL3LogCorrelationMetrics {
    pub correlation_count: u64,
    pub phase_count: u64,
    pub source_ref_count: u64,
    pub visible_surface_count: u64,
    pub test_ref_count: u64,
    pub upstream_runtime_bytes_loaded: u64,
    pub upstream_model_bytes_loaded: u64,
    pub correlation_runtime_bytes_loaded: u64,
    pub correlation_model_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-log-correlation-probe:witness
// Plane: Verification
// Residency: visible proof that fresh runtime packet/log/source records agree.
pub struct SmallModelFreshProductRuntimeL3LogCorrelationWitness {
    pub witness_id: String,
    pub capability_recheck_artifact_ref: String,
    pub fresh_answer_packet_artifact_ref: String,
    pub fresh_wrv_artifact_ref: String,
    pub guard_next_existing_work: String,
    pub capability_overall_pass: bool,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub correlations: Vec<SmallModelFreshProductRuntimeL3LogCorrelationRecord>,
    pub phases: Vec<SmallModelFreshProductRuntimeL3LogCorrelationPhase>,
    pub source_ref_count: u64,
    pub visible_surface_count: u64,
    pub test_ref_count: u64,
    pub upstream_runtime_bytes_loaded: u64,
    pub upstream_model_bytes_loaded: u64,
    pub correlation_runtime_bytes_loaded: u64,
    pub correlation_model_bytes_loaded: u64,
    pub manual_runtime_verification_green: bool,
    pub l1_l2_l3_separated: bool,
    pub hidden_authority_attempted: bool,
    pub route_mutation_attempted: bool,
    pub mas_live_agent_overclaim_attempted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub autogenous_kernel_attempted: bool,
    pub seventy_b_product_claimed: bool,
    pub long_context_shard_product_claimed: bool,
    pub next_cursor: String,
    pub metadata_bytes: u64,
}

impl SmallModelFreshProductRuntimeL3LogCorrelationWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        capability_recheck_artifact_ref: impl Into<String>,
        fresh_answer_packet_artifact_ref: impl Into<String>,
        fresh_wrv_artifact_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_overall_pass: bool,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        correlations: Vec<SmallModelFreshProductRuntimeL3LogCorrelationRecord>,
        phases: Vec<SmallModelFreshProductRuntimeL3LogCorrelationPhase>,
        source_ref_count: u64,
        visible_surface_count: u64,
        test_ref_count: u64,
        upstream_runtime_bytes_loaded: u64,
        upstream_model_bytes_loaded: u64,
        correlation_runtime_bytes_loaded: u64,
        correlation_model_bytes_loaded: u64,
        manual_runtime_verification_green: bool,
        l1_l2_l3_separated: bool,
        hidden_authority_attempted: bool,
        route_mutation_attempted: bool,
        mas_live_agent_overclaim_attempted: bool,
        l2_green_claimed: bool,
        l3_green_claimed: bool,
        autogenous_kernel_attempted: bool,
        seventy_b_product_claimed: bool,
        long_context_shard_product_claimed: bool,
        next_cursor: impl Into<String>,
        metadata_bytes: u64,
    ) -> Result<Self, SmallModelFreshProductRuntimeL3LogCorrelationError> {
        let witness = Self {
            witness_id: witness_id.into(),
            capability_recheck_artifact_ref: capability_recheck_artifact_ref.into(),
            fresh_answer_packet_artifact_ref: fresh_answer_packet_artifact_ref.into(),
            fresh_wrv_artifact_ref: fresh_wrv_artifact_ref.into(),
            guard_next_existing_work: guard_next_existing_work.into(),
            capability_overall_pass,
            capability_route_status: capability_route_status.into(),
            capability_next_bottleneck: capability_next_bottleneck.into(),
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            correlations,
            phases,
            source_ref_count,
            visible_surface_count,
            test_ref_count,
            upstream_runtime_bytes_loaded,
            upstream_model_bytes_loaded,
            correlation_runtime_bytes_loaded,
            correlation_model_bytes_loaded,
            manual_runtime_verification_green,
            l1_l2_l3_separated,
            hidden_authority_attempted,
            route_mutation_attempted,
            mas_live_agent_overclaim_attempted,
            l2_green_claimed,
            l3_green_claimed,
            autogenous_kernel_attempted,
            seventy_b_product_claimed,
            long_context_shard_product_claimed,
            next_cursor: next_cursor.into(),
            metadata_bytes,
        };
        witness.validate()?;
        Ok(witness)
    }

    pub fn validate(&self) -> Result<(), SmallModelFreshProductRuntimeL3LogCorrelationError> {
        validate_clean("witness_id", &self.witness_id)?;
        validate_prefixed(
            "capability_recheck_artifact_ref",
            &self.capability_recheck_artifact_ref,
            CAPABILITY_RECHECK_ARTIFACT_PREFIX,
        )?;
        validate_prefixed(
            "fresh_answer_packet_artifact_ref",
            &self.fresh_answer_packet_artifact_ref,
            ANSWER_PACKET_ARTIFACT_PREFIX,
        )?;
        validate_prefixed(
            "fresh_wrv_artifact_ref",
            &self.fresh_wrv_artifact_ref,
            WRV_ARTIFACT_PREFIX,
        )?;
        if self.guard_next_existing_work
            != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_CURSOR
            && self.guard_next_existing_work
                != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_NEXT_CURSOR
        {
            return Err(SmallModelFreshProductRuntimeL3LogCorrelationError::GuardCursorMismatch);
        }
        if self.capability_overall_pass
            || self.capability_route_status != "vault_research_route_with_packetized_mitigation"
            || (self.capability_next_bottleneck
                != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_CURSOR
                && self.capability_next_bottleneck
                    != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_NEXT_CURSOR)
        {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::CapabilityStatusMismatch,
            );
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.route_authority != "fresh_product_runtime_l3_log_correlation_no_route_authority"
        {
            return Err(SmallModelFreshProductRuntimeL3LogCorrelationError::ProductStatusMismatch);
        }
        if self.correlations.is_empty() {
            return Err(SmallModelFreshProductRuntimeL3LogCorrelationError::EmptyCorrelation);
        }
        let mut correlation_ids = BTreeSet::new();
        for correlation in &self.correlations {
            correlation.validate()?;
            if !correlation_ids.insert(correlation.correlation_id.clone()) {
                return Err(
                    SmallModelFreshProductRuntimeL3LogCorrelationError::DuplicateCorrelation(
                        correlation.correlation_id.clone(),
                    ),
                );
            }
        }
        if self.phases.is_empty() {
            return Err(SmallModelFreshProductRuntimeL3LogCorrelationError::EmptyPhase);
        }
        let observed_phases = self
            .phases
            .iter()
            .map(SmallModelFreshProductRuntimeL3LogCorrelationPhase::tag)
            .collect::<BTreeSet<_>>();
        for phase in required_fresh_product_runtime_l3_log_correlation_phases() {
            if !observed_phases.contains(phase.tag()) {
                return Err(
                    SmallModelFreshProductRuntimeL3LogCorrelationError::MissingPhase(phase.tag()),
                );
            }
        }
        if self.source_ref_count < MIN_SOURCE_REFS
            || self.visible_surface_count < MIN_VISIBLE_SURFACES
            || self.test_ref_count < MIN_TEST_REFS
        {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::SourceWrvCoverageMissing,
            );
        }
        if self.manual_runtime_verification_green {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::ManualVerificationAlreadyGreen,
            );
        }
        if self.upstream_runtime_bytes_loaded == 0 {
            return Err(SmallModelFreshProductRuntimeL3LogCorrelationError::RuntimeBytesMissing);
        }
        if self.upstream_model_bytes_loaded == 0 {
            return Err(SmallModelFreshProductRuntimeL3LogCorrelationError::ModelBytesMissing);
        }
        if self.correlation_runtime_bytes_loaded != 0 {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::CorrelationRuntimeBytesLoaded,
            );
        }
        if self.correlation_model_bytes_loaded != 0 {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::CorrelationModelBytesLoaded,
            );
        }
        if !self.l1_l2_l3_separated {
            return Err(SmallModelFreshProductRuntimeL3LogCorrelationError::L1L2L3NotSeparated);
        }
        if self.hidden_authority_attempted {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::HiddenAuthorityAttempted,
            );
        }
        if self.route_mutation_attempted {
            return Err(SmallModelFreshProductRuntimeL3LogCorrelationError::RouteMutationAttempted);
        }
        if self.mas_live_agent_overclaim_attempted {
            return Err(SmallModelFreshProductRuntimeL3LogCorrelationError::MasLiveAgentOverclaim);
        }
        if self.l2_green_claimed {
            return Err(SmallModelFreshProductRuntimeL3LogCorrelationError::L2GreenClaimAttempted);
        }
        if self.l3_green_claimed {
            return Err(SmallModelFreshProductRuntimeL3LogCorrelationError::L3GreenClaimAttempted);
        }
        if self.autogenous_kernel_attempted {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::AutogenousKernelAttempted,
            );
        }
        if self.seventy_b_product_claimed {
            return Err(SmallModelFreshProductRuntimeL3LogCorrelationError::SeventyBProductClaimed);
        }
        if self.long_context_shard_product_claimed {
            return Err(
                SmallModelFreshProductRuntimeL3LogCorrelationError::LongContextShardProductClaimed,
            );
        }
        if self.next_cursor
            != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_NEXT_CURSOR
        {
            return Err(SmallModelFreshProductRuntimeL3LogCorrelationError::NextCursorMismatch);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(SmallModelFreshProductRuntimeL3LogCorrelationError::MetadataBudgetExceeded);
        }
        Ok(())
    }

    pub fn metrics(&self) -> SmallModelFreshProductRuntimeL3LogCorrelationMetrics {
        SmallModelFreshProductRuntimeL3LogCorrelationMetrics {
            correlation_count: self.correlations.len() as u64,
            phase_count: self
                .phases
                .iter()
                .map(SmallModelFreshProductRuntimeL3LogCorrelationPhase::tag)
                .collect::<BTreeSet<_>>()
                .len() as u64,
            source_ref_count: self.source_ref_count,
            visible_surface_count: self.visible_surface_count,
            test_ref_count: self.test_ref_count,
            upstream_runtime_bytes_loaded: self.upstream_runtime_bytes_loaded,
            upstream_model_bytes_loaded: self.upstream_model_bytes_loaded,
            correlation_runtime_bytes_loaded: self.correlation_runtime_bytes_loaded,
            correlation_model_bytes_loaded: self.correlation_model_bytes_loaded,
        }
    }

    pub fn address(&self) -> String {
        let mut parts = vec![
            self.witness_id.clone(),
            self.capability_recheck_artifact_ref.clone(),
            self.fresh_answer_packet_artifact_ref.clone(),
            self.fresh_wrv_artifact_ref.clone(),
            self.guard_next_existing_work.clone(),
            self.capability_route_status.clone(),
            self.capability_next_bottleneck.clone(),
            self.route_authority.clone(),
            self.next_cursor.clone(),
            self.upstream_runtime_bytes_loaded.to_string(),
            self.upstream_model_bytes_loaded.to_string(),
        ];
        for correlation in &self.correlations {
            parts.push(correlation.correlation_id.clone());
            parts.push(correlation.answer_packet_ref.clone());
            parts.push(correlation.run_event_log_ref.clone());
            parts.push(correlation.live_sidecar_ref.clone());
            parts.push(correlation.token_digest_ref.clone());
            parts.push(correlation.prompt_hash_ref.clone());
            parts.push(correlation.product_surface_ref.clone());
        }
        for phase in &self.phases {
            parts.push(phase.tag().to_string());
        }
        parts.sort();
        sha256_hex(parts.join("|").as_bytes())
    }
}

pub fn required_fresh_product_runtime_l3_log_correlation_phases(
) -> [SmallModelFreshProductRuntimeL3LogCorrelationPhase; 12] {
    [
        SmallModelFreshProductRuntimeL3LogCorrelationPhase::CapabilityRecheckArtifactBound,
        SmallModelFreshProductRuntimeL3LogCorrelationPhase::FreshAnswerPacketArtifactBound,
        SmallModelFreshProductRuntimeL3LogCorrelationPhase::FreshWrvArtifactBound,
        SmallModelFreshProductRuntimeL3LogCorrelationPhase::LiveProbeSidecarBound,
        SmallModelFreshProductRuntimeL3LogCorrelationPhase::AnswerPacketJsonBound,
        SmallModelFreshProductRuntimeL3LogCorrelationPhase::RunEventLogSidecarBound,
        SmallModelFreshProductRuntimeL3LogCorrelationPhase::TokenDigestCorrelated,
        SmallModelFreshProductRuntimeL3LogCorrelationPhase::StopReasonCorrelated,
        SmallModelFreshProductRuntimeL3LogCorrelationPhase::PromptPrivacyCorrelated,
        SmallModelFreshProductRuntimeL3LogCorrelationPhase::SourceWrvCorrelated,
        SmallModelFreshProductRuntimeL3LogCorrelationPhase::CapabilityKernelRedBound,
        SmallModelFreshProductRuntimeL3LogCorrelationPhase::ManualVerificationProbeQueued,
    ]
}

pub fn fresh_product_runtime_l3_log_correlation_metadata_budget_bytes() -> u64 {
    MAX_METADATA_BYTES
}

fn validate_prefixed(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), SmallModelFreshProductRuntimeL3LogCorrelationError> {
    validate_clean(field, value)?;
    if !value.starts_with(prefix) {
        return Err(SmallModelFreshProductRuntimeL3LogCorrelationError::MissingArtifactRef(field));
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelFreshProductRuntimeL3LogCorrelationError> {
    if value.is_empty() {
        return Err(SmallModelFreshProductRuntimeL3LogCorrelationError::MissingField(field));
    }
    if value.trim() != value {
        return Err(
            SmallModelFreshProductRuntimeL3LogCorrelationError::FieldHasSurroundingWhitespace(
                field,
            ),
        );
    }
    if value.chars().any(char::is_control) {
        return Err(
            SmallModelFreshProductRuntimeL3LogCorrelationError::FieldContainsControlCharacter(
                field,
            ),
        );
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn record() -> SmallModelFreshProductRuntimeL3LogCorrelationRecord {
        SmallModelFreshProductRuntimeL3LogCorrelationRecord {
            correlation_id: "fresh-product-runtime-qwen3-4b-log-correlation".to_string(),
            answer_packet_ref: "answer_packet:qwen3_4b:fresh-product-runtime:packetized"
                .to_string(),
            run_event_log_ref: "run_event_log:fresh-product-runtime:packetized".to_string(),
            live_sidecar_ref:
                "artifact:small_model_runtime_harness_fresh_product_runtime_live_probe:live_probe:result"
                    .to_string(),
            token_digest_ref:
                "token_sha256:75a11da44c802486bc6f65640aa48a730f0f684c5c07a42ba3cd1735eb3fb070"
                    .to_string(),
            prompt_hash_ref:
                "sha256:fb5e5ea2da88bd278450eaa46897f685d5d180d5e112abfd647773904d7e5643"
                    .to_string(),
            product_surface_ref: "surface:note_chat_fresh_product_runtime".to_string(),
            answer_packet_token_digest_ref:
                "token_sha256:75a11da44c802486bc6f65640aa48a730f0f684c5c07a42ba3cd1735eb3fb070"
                    .to_string(),
            run_event_log_token_digest_ref:
                "token_sha256:75a11da44c802486bc6f65640aa48a730f0f684c5c07a42ba3cd1735eb3fb070"
                    .to_string(),
            live_sidecar_token_digest_ref:
                "token_sha256:75a11da44c802486bc6f65640aa48a730f0f684c5c07a42ba3cd1735eb3fb070"
                    .to_string(),
            answer_packet_stop_reason: "end_turn".to_string(),
            run_event_log_stop_reason: "end_turn".to_string(),
            output_token_count: 1,
            run_event_log_entry_count: 2,
            run_event_log_final_text_present: true,
            run_event_log_stop_present: true,
            run_event_log_error_count: 0,
            prompt_contains_user_data: false,
            raw_token_text_retained: false,
        }
    }

    fn witness() -> SmallModelFreshProductRuntimeL3LogCorrelationWitness {
        SmallModelFreshProductRuntimeL3LogCorrelationWitness::new(
            "small-model-fresh-product-runtime-l3-log-correlation:visible-proof",
            "artifact:small_model_runtime_harness_fresh_product_runtime_capability_recheck:result",
            "artifact:small_model_runtime_harness_fresh_product_runtime_answer_packet_probe:result",
            "artifact:small_model_runtime_harness_fresh_product_runtime_wrv_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_CURSOR,
            false,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "fresh_product_runtime_l3_log_correlation_no_route_authority",
            vec![record()],
            required_fresh_product_runtime_l3_log_correlation_phases().to_vec(),
            10,
            3,
            4,
            16_777_216,
            2_137_326_367,
            0,
            0,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_LOG_CORRELATION_PROBE_NEXT_CURSOR,
            4096,
        )
        .expect("valid log-correlation witness")
    }

    #[test]
    fn fixture_validates_and_has_deterministic_address() {
        let witness = witness();
        assert_eq!(witness.metrics().correlation_count, 1);
        assert_eq!(witness.metrics().correlation_runtime_bytes_loaded, 0);
        assert_eq!(witness.address(), witness.address());
    }

    #[test]
    fn token_digest_mismatch_is_rejected() {
        let mut record = record();
        record.run_event_log_token_digest_ref =
            "token_sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                .to_string();
        let error = record.validate().expect_err("mismatch must reject");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3LogCorrelationError::TokenDigestMismatch(_)
        ));
    }

    #[test]
    fn missing_stop_event_is_rejected() {
        let mut record = record();
        record.run_event_log_stop_present = false;
        let error = record.validate().expect_err("missing stop must reject");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3LogCorrelationError::RunEventLogMissingStop(_)
        ));
    }

    #[test]
    fn source_wrv_shortfall_is_rejected() {
        let mut witness = witness();
        witness.source_ref_count = 9;
        let error = witness.validate().expect_err("short WRV coverage rejects");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3LogCorrelationError::SourceWrvCoverageMissing
        ));
    }

    #[test]
    fn manual_verification_green_is_rejected() {
        let mut witness = witness();
        witness.manual_runtime_verification_green = true;
        let error = witness
            .validate()
            .expect_err("manual green cannot be hidden in log correlation");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3LogCorrelationError::ManualVerificationAlreadyGreen
        ));
    }

    #[test]
    fn correlation_runtime_bytes_are_rejected() {
        let mut witness = witness();
        witness.correlation_runtime_bytes_loaded = 1;
        let error = witness.validate().expect_err("new bytes must reject");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3LogCorrelationError::CorrelationRuntimeBytesLoaded
        ));
    }
}
