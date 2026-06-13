//! Fresh product-runtime L3 manual-runtime verification probe for the small-model harness.
//!
//! This witness binds the already-captured fresh runtime proof to visible manual
//! review surfaces: Living Index, lattice HTML, AnswerPacket, RunEventLog, and
//! the red capability ledger. It does not open model/runtime bytes, promote MAS
//! live-agent claims, or mark L2/L3 product capability green.

use std::collections::BTreeSet;
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe";
pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_capability_closeout_probe";
pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";

const UPSTREAM_LOG_CORRELATION_ARTIFACT_PREFIX: &str =
    "artifact:small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe:";
const ARTIFACT_PREFIX: &str = "artifact:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const SURFACE_PREFIX: &str = "surface:";
const OPERATOR_PREFIX: &str = "operator:";
const OBSERVATION_PREFIX: &str = "manual_observation:";
const TOKEN_SHA_PREFIX: &str = "token_sha256:";
const MAX_METADATA_BYTES: u64 = 768 * 1024;
const MIN_OBSERVATIONS: u64 = 3;
const MIN_MANUAL_STEPS: u64 = 5;
const MIN_SOURCE_REFS: u64 = 10;
const MIN_TEST_REFS: u64 = 4;
const MIN_VISIBLE_SURFACES: u64 = 3;

pub fn small_model_fresh_product_runtime_l3_manual_or_advanced_cursor(cursor: &str) -> bool {
    matches!(
        cursor,
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_CURSOR
            | SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_NEXT_CURSOR
            | SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_RELEASE_AUDIT_CURSOR
    )
}

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-manual-runtime-verification-probe:phase
// Plane: Verification
// Residency: visible manual review phase after fresh runtime log correlation.
pub enum SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase {
    UpstreamLogCorrelationBound,
    GuardManualCursorBound,
    CapabilityKernelRedBound,
    LatticeCursorObserved,
    LivingIndexCursorObserved,
    NorthStarObserved,
    L1L2L3StatusObserved,
    AnswerPacketObserved,
    RunEventLogObserved,
    PrivacyRedactionObserved,
    RollbackCancellationObserved,
    CapabilityCloseoutQueued,
}

impl SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase {
    pub fn tag(&self) -> &'static str {
        match self {
            Self::UpstreamLogCorrelationBound => "upstream_log_correlation_bound",
            Self::GuardManualCursorBound => "guard_manual_cursor_bound",
            Self::CapabilityKernelRedBound => "capability_kernel_red_bound",
            Self::LatticeCursorObserved => "lattice_cursor_observed",
            Self::LivingIndexCursorObserved => "living_index_cursor_observed",
            Self::NorthStarObserved => "north_star_observed",
            Self::L1L2L3StatusObserved => "l1_l2_l3_status_observed",
            Self::AnswerPacketObserved => "answer_packet_observed",
            Self::RunEventLogObserved => "run_event_log_observed",
            Self::PrivacyRedactionObserved => "privacy_redaction_observed",
            Self::RollbackCancellationObserved => "rollback_cancellation_observed",
            Self::CapabilityCloseoutQueued => "capability_closeout_queued",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-manual-runtime-verification-probe:error
// Plane: Verification
// Residency: manual verification rejection taxonomy.
pub enum SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    MissingArtifactRef(&'static str),
    ProductStatusMismatch,
    CapabilityStatusMismatch,
    GuardCursorMismatch,
    EmptyObservation,
    DuplicateObservation(String),
    ObservationNotVisible(String),
    EmptyPhase,
    MissingPhase(&'static str),
    SourceWrvCoverageMissing,
    ManualStepShortfall,
    UpstreamRuntimeBytesMissing,
    UpstreamModelBytesMissing,
    ManualRuntimeBytesLoaded,
    ManualModelBytesLoaded,
    LatticeCursorMissing,
    LivingIndexCursorMissing,
    NorthStarMissing,
    L1L2L3StatusMissing,
    AnswerPacketMissing,
    RunEventLogMissing,
    TokenDigestMissing,
    PromptUserDataRetained,
    RawTokenRetained,
    RollbackCancellationMissing,
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

impl fmt::Display for SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError {
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
            Self::EmptyObservation => write!(f, "missing manual observation"),
            Self::DuplicateObservation(id) => write!(f, "duplicate observation `{id}`"),
            Self::ObservationNotVisible(id) => write!(f, "observation `{id}` is not visible"),
            Self::EmptyPhase => write!(f, "missing manual verification phase"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::SourceWrvCoverageMissing => write!(f, "source WRV coverage missing"),
            Self::ManualStepShortfall => write!(f, "manual verification step shortfall"),
            Self::UpstreamRuntimeBytesMissing => write!(f, "upstream runtime bytes missing"),
            Self::UpstreamModelBytesMissing => write!(f, "upstream model bytes missing"),
            Self::ManualRuntimeBytesLoaded => write!(f, "manual verifier loaded runtime bytes"),
            Self::ManualModelBytesLoaded => write!(f, "manual verifier loaded model bytes"),
            Self::LatticeCursorMissing => write!(f, "lattice cursor missing"),
            Self::LivingIndexCursorMissing => write!(f, "Living Index cursor missing"),
            Self::NorthStarMissing => write!(f, "north-star sentence missing"),
            Self::L1L2L3StatusMissing => write!(f, "L1/L2/L3 status missing"),
            Self::AnswerPacketMissing => write!(f, "AnswerPacket missing"),
            Self::RunEventLogMissing => write!(f, "RunEventLog missing"),
            Self::TokenDigestMissing => write!(f, "token digest missing"),
            Self::PromptUserDataRetained => write!(f, "prompt user data retained"),
            Self::RawTokenRetained => write!(f, "raw token retained"),
            Self::RollbackCancellationMissing => write!(f, "rollback/cancellation proof missing"),
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

impl std::error::Error for SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-manual-runtime-verification-probe:observation
// Plane: Verification
// Residency: one operator-visible manual verification evidence unit.
pub struct SmallModelFreshProductRuntimeL3ManualRuntimeObservation {
    pub observation_id: String,
    pub operator_ref: String,
    pub surface_ref: String,
    pub artifact_ref: String,
    pub answer_packet_ref: String,
    pub run_event_log_ref: String,
    pub token_digest_ref: String,
    pub visible_to_operator: bool,
    pub l1_l2_l3_called_out: bool,
    pub prompt_privacy_visible: bool,
    pub rollback_visible: bool,
    pub cancellation_visible: bool,
    pub route_authority_denied: bool,
    pub product_green_denied: bool,
}

impl SmallModelFreshProductRuntimeL3ManualRuntimeObservation {
    pub fn validate(
        &self,
    ) -> Result<(), SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError> {
        validate_prefixed("observation_id", &self.observation_id, OBSERVATION_PREFIX)?;
        validate_prefixed("operator_ref", &self.operator_ref, OPERATOR_PREFIX)?;
        validate_prefixed("surface_ref", &self.surface_ref, SURFACE_PREFIX)?;
        validate_prefixed("artifact_ref", &self.artifact_ref, ARTIFACT_PREFIX)?;
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
        validate_prefixed("token_digest_ref", &self.token_digest_ref, TOKEN_SHA_PREFIX)?;
        if !self.visible_to_operator
            || !self.l1_l2_l3_called_out
            || !self.prompt_privacy_visible
            || !self.rollback_visible
            || !self.cancellation_visible
            || !self.route_authority_denied
            || !self.product_green_denied
        {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::ObservationNotVisible(
                    self.observation_id.clone(),
                ),
            );
        }
        Ok(())
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-manual-runtime-verification-probe:metrics
// Plane: Verification
// Residency: manual verification counts and byte accounting.
pub struct SmallModelFreshProductRuntimeL3ManualRuntimeVerificationMetrics {
    pub observation_count: u64,
    pub phase_count: u64,
    pub source_ref_count: u64,
    pub visible_surface_count: u64,
    pub test_ref_count: u64,
    pub manual_step_count: u64,
    pub upstream_runtime_bytes_loaded: u64,
    pub upstream_model_bytes_loaded: u64,
    pub manual_verification_runtime_bytes_loaded: u64,
    pub manual_verification_model_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-manual-runtime-verification-probe:witness
// Plane: Verification
// Residency: visible manual proof that fresh runtime packet/log/source records were reviewed.
pub struct SmallModelFreshProductRuntimeL3ManualRuntimeVerificationWitness {
    pub witness_id: String,
    pub upstream_log_correlation_artifact_ref: String,
    pub guard_next_existing_work: String,
    pub capability_overall_pass: bool,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub observations: Vec<SmallModelFreshProductRuntimeL3ManualRuntimeObservation>,
    pub phases: Vec<SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase>,
    pub source_ref_count: u64,
    pub visible_surface_count: u64,
    pub test_ref_count: u64,
    pub manual_step_count: u64,
    pub upstream_runtime_bytes_loaded: u64,
    pub upstream_model_bytes_loaded: u64,
    pub manual_verification_runtime_bytes_loaded: u64,
    pub manual_verification_model_bytes_loaded: u64,
    pub lattice_cursor_visible: bool,
    pub living_index_cursor_visible: bool,
    pub north_star_visible: bool,
    pub l1_l2_l3_status_visible: bool,
    pub answer_packet_observed: bool,
    pub run_event_log_observed: bool,
    pub token_digest_observed: bool,
    pub prompt_user_data_retained: bool,
    pub raw_token_text_retained: bool,
    pub rollback_cancellation_visible: bool,
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

impl SmallModelFreshProductRuntimeL3ManualRuntimeVerificationWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        upstream_log_correlation_artifact_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_overall_pass: bool,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        observations: Vec<SmallModelFreshProductRuntimeL3ManualRuntimeObservation>,
        phases: Vec<SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase>,
        source_ref_count: u64,
        visible_surface_count: u64,
        test_ref_count: u64,
        manual_step_count: u64,
        upstream_runtime_bytes_loaded: u64,
        upstream_model_bytes_loaded: u64,
        manual_verification_runtime_bytes_loaded: u64,
        manual_verification_model_bytes_loaded: u64,
        lattice_cursor_visible: bool,
        living_index_cursor_visible: bool,
        north_star_visible: bool,
        l1_l2_l3_status_visible: bool,
        answer_packet_observed: bool,
        run_event_log_observed: bool,
        token_digest_observed: bool,
        prompt_user_data_retained: bool,
        raw_token_text_retained: bool,
        rollback_cancellation_visible: bool,
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
    ) -> Result<Self, SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError> {
        let witness = Self {
            witness_id: witness_id.into(),
            upstream_log_correlation_artifact_ref: upstream_log_correlation_artifact_ref.into(),
            guard_next_existing_work: guard_next_existing_work.into(),
            capability_overall_pass,
            capability_route_status: capability_route_status.into(),
            capability_next_bottleneck: capability_next_bottleneck.into(),
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            observations,
            phases,
            source_ref_count,
            visible_surface_count,
            test_ref_count,
            manual_step_count,
            upstream_runtime_bytes_loaded,
            upstream_model_bytes_loaded,
            manual_verification_runtime_bytes_loaded,
            manual_verification_model_bytes_loaded,
            lattice_cursor_visible,
            living_index_cursor_visible,
            north_star_visible,
            l1_l2_l3_status_visible,
            answer_packet_observed,
            run_event_log_observed,
            token_digest_observed,
            prompt_user_data_retained,
            raw_token_text_retained,
            rollback_cancellation_visible,
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

    pub fn validate(
        &self,
    ) -> Result<(), SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError> {
        validate_clean("witness_id", &self.witness_id)?;
        validate_prefixed(
            "upstream_log_correlation_artifact_ref",
            &self.upstream_log_correlation_artifact_ref,
            UPSTREAM_LOG_CORRELATION_ARTIFACT_PREFIX,
        )?;
        if !small_model_fresh_product_runtime_l3_manual_or_advanced_cursor(
            &self.guard_next_existing_work,
        ) {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::GuardCursorMismatch,
            );
        }
        if self.capability_overall_pass
            || self.capability_route_status != "vault_research_route_with_packetized_mitigation"
            || !small_model_fresh_product_runtime_l3_manual_or_advanced_cursor(
                &self.capability_next_bottleneck,
            )
        {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::CapabilityStatusMismatch,
            );
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.route_authority
                != "fresh_product_runtime_l3_manual_verification_no_route_authority"
        {
            return Err(SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::ProductStatusMismatch);
        }
        if self.observations.is_empty() {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::EmptyObservation,
            );
        }
        let mut observation_ids = BTreeSet::new();
        for observation in &self.observations {
            observation.validate()?;
            if !observation_ids.insert(observation.observation_id.clone()) {
                return Err(
                    SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::DuplicateObservation(
                        observation.observation_id.clone(),
                    ),
                );
            }
        }
        if self.phases.is_empty() {
            return Err(SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::EmptyPhase);
        }
        let observed_phases = self
            .phases
            .iter()
            .map(SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase::tag)
            .collect::<BTreeSet<_>>();
        for phase in required_fresh_product_runtime_l3_manual_runtime_verification_phases() {
            if !observed_phases.contains(phase.tag()) {
                return Err(
                    SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::MissingPhase(
                        phase.tag(),
                    ),
                );
            }
        }
        if self.source_ref_count < MIN_SOURCE_REFS
            || self.visible_surface_count < MIN_VISIBLE_SURFACES
            || self.test_ref_count < MIN_TEST_REFS
        {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::SourceWrvCoverageMissing,
            );
        }
        if (self.observations.len() as u64) < MIN_OBSERVATIONS
            || self.manual_step_count < MIN_MANUAL_STEPS
        {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::ManualStepShortfall,
            );
        }
        if self.upstream_runtime_bytes_loaded == 0 {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::UpstreamRuntimeBytesMissing,
            );
        }
        if self.upstream_model_bytes_loaded == 0 {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::UpstreamModelBytesMissing,
            );
        }
        if self.manual_verification_runtime_bytes_loaded != 0 {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::ManualRuntimeBytesLoaded,
            );
        }
        if self.manual_verification_model_bytes_loaded != 0 {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::ManualModelBytesLoaded,
            );
        }
        if !self.lattice_cursor_visible {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::LatticeCursorMissing,
            );
        }
        if !self.living_index_cursor_visible {
            return Err(SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::LivingIndexCursorMissing);
        }
        if !self.north_star_visible {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::NorthStarMissing,
            );
        }
        if !self.l1_l2_l3_status_visible {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::L1L2L3StatusMissing,
            );
        }
        if !self.answer_packet_observed {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::AnswerPacketMissing,
            );
        }
        if !self.run_event_log_observed {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::RunEventLogMissing,
            );
        }
        if !self.token_digest_observed {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::TokenDigestMissing,
            );
        }
        if self.prompt_user_data_retained {
            return Err(SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::PromptUserDataRetained);
        }
        if self.raw_token_text_retained {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::RawTokenRetained,
            );
        }
        if !self.rollback_cancellation_visible {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::RollbackCancellationMissing,
            );
        }
        if !self.l1_l2_l3_separated {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::L1L2L3NotSeparated,
            );
        }
        if self.hidden_authority_attempted {
            return Err(SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::HiddenAuthorityAttempted);
        }
        if self.route_mutation_attempted {
            return Err(SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::RouteMutationAttempted);
        }
        if self.mas_live_agent_overclaim_attempted {
            return Err(SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::MasLiveAgentOverclaim);
        }
        if self.l2_green_claimed {
            return Err(SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::L2GreenClaimAttempted);
        }
        if self.l3_green_claimed {
            return Err(SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::L3GreenClaimAttempted);
        }
        if self.autogenous_kernel_attempted {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::AutogenousKernelAttempted,
            );
        }
        if self.seventy_b_product_claimed {
            return Err(SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::SeventyBProductClaimed);
        }
        if self.long_context_shard_product_claimed {
            return Err(
                SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::LongContextShardProductClaimed,
            );
        }
        if self.next_cursor
            != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_NEXT_CURSOR
        {
            return Err(SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::NextCursorMismatch);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::MetadataBudgetExceeded);
        }
        Ok(())
    }

    pub fn metrics(&self) -> SmallModelFreshProductRuntimeL3ManualRuntimeVerificationMetrics {
        SmallModelFreshProductRuntimeL3ManualRuntimeVerificationMetrics {
            observation_count: self.observations.len() as u64,
            phase_count: self
                .phases
                .iter()
                .map(SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase::tag)
                .collect::<BTreeSet<_>>()
                .len() as u64,
            source_ref_count: self.source_ref_count,
            visible_surface_count: self.visible_surface_count,
            test_ref_count: self.test_ref_count,
            manual_step_count: self.manual_step_count,
            upstream_runtime_bytes_loaded: self.upstream_runtime_bytes_loaded,
            upstream_model_bytes_loaded: self.upstream_model_bytes_loaded,
            manual_verification_runtime_bytes_loaded: self.manual_verification_runtime_bytes_loaded,
            manual_verification_model_bytes_loaded: self.manual_verification_model_bytes_loaded,
        }
    }

    pub fn address(&self) -> String {
        let mut parts = vec![
            self.witness_id.clone(),
            self.upstream_log_correlation_artifact_ref.clone(),
            self.guard_next_existing_work.clone(),
            self.capability_route_status.clone(),
            self.capability_next_bottleneck.clone(),
            self.route_authority.clone(),
            self.next_cursor.clone(),
            self.upstream_runtime_bytes_loaded.to_string(),
            self.upstream_model_bytes_loaded.to_string(),
        ];
        for observation in &self.observations {
            parts.push(observation.observation_id.clone());
            parts.push(observation.surface_ref.clone());
            parts.push(observation.artifact_ref.clone());
            parts.push(observation.answer_packet_ref.clone());
            parts.push(observation.run_event_log_ref.clone());
            parts.push(observation.token_digest_ref.clone());
        }
        for phase in &self.phases {
            parts.push(phase.tag().to_string());
        }
        parts.sort();
        sha256_hex(parts.join("|").as_bytes())
    }
}

pub fn required_fresh_product_runtime_l3_manual_runtime_verification_phases(
) -> [SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase; 12] {
    [
        SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase::UpstreamLogCorrelationBound,
        SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase::GuardManualCursorBound,
        SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase::CapabilityKernelRedBound,
        SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase::LatticeCursorObserved,
        SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase::LivingIndexCursorObserved,
        SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase::NorthStarObserved,
        SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase::L1L2L3StatusObserved,
        SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase::AnswerPacketObserved,
        SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase::RunEventLogObserved,
        SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase::PrivacyRedactionObserved,
        SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase::RollbackCancellationObserved,
        SmallModelFreshProductRuntimeL3ManualRuntimeVerificationPhase::CapabilityCloseoutQueued,
    ]
}

pub fn fresh_product_runtime_l3_manual_runtime_verification_metadata_budget_bytes() -> u64 {
    MAX_METADATA_BYTES
}

fn validate_prefixed(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError> {
    validate_clean(field, value)?;
    if !value.starts_with(prefix) {
        return Err(
            SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::MissingArtifactRef(
                field,
            ),
        );
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError> {
    if value.is_empty() {
        return Err(
            SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::MissingField(field),
        );
    }
    if value.trim() != value {
        return Err(
            SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::FieldHasSurroundingWhitespace(
                field,
            ),
        );
    }
    if value.chars().any(char::is_control) {
        return Err(
            SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::FieldContainsControlCharacter(
                field,
            ),
        );
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn observation(id: &str) -> SmallModelFreshProductRuntimeL3ManualRuntimeObservation {
        SmallModelFreshProductRuntimeL3ManualRuntimeObservation {
            observation_id: format!("manual_observation:{id}"),
            operator_ref: "operator:codex-local-architecture-audit".to_string(),
            surface_ref: "surface:lattice_index_html".to_string(),
            artifact_ref: "artifact:lattice-coordinate-explainer:index_html".to_string(),
            answer_packet_ref: "answer_packet:qwen3_4b:fresh-product-runtime:packetized"
                .to_string(),
            run_event_log_ref: "run_event_log:fresh-product-runtime:packetized".to_string(),
            token_digest_ref:
                "token_sha256:75a11da44c802486bc6f65640aa48a730f0f684c5c07a42ba3cd1735eb3fb070"
                    .to_string(),
            visible_to_operator: true,
            l1_l2_l3_called_out: true,
            prompt_privacy_visible: true,
            rollback_visible: true,
            cancellation_visible: true,
            route_authority_denied: true,
            product_green_denied: true,
        }
    }

    fn witness() -> SmallModelFreshProductRuntimeL3ManualRuntimeVerificationWitness {
        SmallModelFreshProductRuntimeL3ManualRuntimeVerificationWitness::new(
            "small-model-fresh-product-runtime-l3-manual-runtime-verification:visible-proof",
            "artifact:small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_CURSOR,
            false,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "fresh_product_runtime_l3_manual_verification_no_route_authority",
            vec![
                observation("lattice-current-cursor-visible"),
                observation("living-index-current-state-visible"),
                observation("answer-packet-run-event-log-visible"),
            ],
            required_fresh_product_runtime_l3_manual_runtime_verification_phases().to_vec(),
            10,
            3,
            4,
            7,
            16_777_216,
            2_137_326_367,
            0,
            0,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
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
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_NEXT_CURSOR,
            4096,
        )
        .expect("valid manual-runtime verification witness")
    }

    #[test]
    fn fixture_validates_and_has_deterministic_address() {
        let witness = witness();
        assert_eq!(witness.metrics().observation_count, 3);
        assert_eq!(
            witness.metrics().manual_verification_runtime_bytes_loaded,
            0
        );
        assert_eq!(witness.address(), witness.address());
    }

    #[test]
    fn duplicate_observations_are_rejected() {
        let mut witness = witness();
        witness.observations[1].observation_id = witness.observations[0].observation_id.clone();
        let error = witness
            .validate()
            .expect_err("duplicate observation rejects");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::DuplicateObservation(_)
        ));
    }

    #[test]
    fn missing_lattice_cursor_is_rejected() {
        let mut witness = witness();
        witness.lattice_cursor_visible = false;
        let error = witness
            .validate()
            .expect_err("missing lattice cursor rejects");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::LatticeCursorMissing
        ));
    }

    #[test]
    fn release_audit_successor_cursor_is_accepted_as_advanced() {
        let mut witness = witness();
        witness.guard_next_existing_work =
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_RELEASE_AUDIT_CURSOR.to_string();
        witness.capability_next_bottleneck =
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_RELEASE_AUDIT_CURSOR.to_string();
        witness
            .validate()
            .expect("release-audit cursor is an advanced successor");
    }

    #[test]
    fn raw_token_retention_is_rejected() {
        let mut witness = witness();
        witness.raw_token_text_retained = true;
        let error = witness.validate().expect_err("raw token retention rejects");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::RawTokenRetained
        ));
    }

    #[test]
    fn l2_green_claim_is_rejected() {
        let mut witness = witness();
        witness.l2_green_claimed = true;
        let error = witness.validate().expect_err("L2 green claim rejects");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::L2GreenClaimAttempted
        ));
    }

    #[test]
    fn manual_runtime_bytes_are_rejected() {
        let mut witness = witness();
        witness.manual_verification_runtime_bytes_loaded = 1;
        let error = witness.validate().expect_err("manual byte load rejects");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3ManualRuntimeVerificationError::ManualRuntimeBytesLoaded
        ));
    }
}
