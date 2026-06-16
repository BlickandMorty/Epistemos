//! Fresh product-runtime L3 release-audit zero_fail for the small-model harness.
//!
//! This witness proves the release-audit skill is queued as a blocker-preserving
//! zero_fail, not as ship authority. It consumes the red capability preflight,
//! preserves L2/L3 separation, and queues zero-fail release audit work without
//! opening fresh runtime/model bytes.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, SmallModelProductRouteCapabilityBlocker};

pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_ZERO_FAIL_PROBE_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_zero_fail_probe";
pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_ZERO_FAIL_PROBE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";

const UPSTREAM_PREFLIGHT_ARTIFACT_PREFIX: &str =
    "artifact:small_model_runtime_harness_fresh_product_runtime_l3_release_audit_preflight_probe:";
const RELEASE_AUDIT_SKILL_PATH: &str = ".agents/skills/epistemos_release_audit/SKILL.md";
const MIN_BLOCKER_COUNT: usize = 14;
const MAX_METADATA_BYTES: u64 = 896 * 1024;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-zero_fail-probe:phase
// Plane: Verification + Controller
// Residency: release-audit zero_fail phase after red preflight.
pub enum SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase {
    UpstreamPreflightBound,
    GuardZeroFailCursorBound,
    CapabilityKernelRedBound,
    ReleaseAuditSkillBound,
    LogFirstRequirementBound,
    ZeroFailRequirementBound,
    ShipCallBlocked,
    ProductCapabilityUnpromoted,
    AnswerPacketRunEventLogBound,
    MasProHonestyBound,
    HeavyRoutesDeferred,
    NoNewBytesLoaded,
    AutomatedChecksRequired,
    LogRuntimeEvidenceRequired,
    ManualRuntimeEvidenceRequired,
    DistributionComplianceRequired,
    ThreePassCounterReset,
    NextAutomatedChecksQueued,
}

impl SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase {
    pub fn tag(&self) -> &'static str {
        match self {
            Self::UpstreamPreflightBound => "upstream_preflight_bound",
            Self::GuardZeroFailCursorBound => "guard_zero_fail_cursor_bound",
            Self::CapabilityKernelRedBound => "capability_kernel_red_bound",
            Self::ReleaseAuditSkillBound => "release_audit_skill_bound",
            Self::LogFirstRequirementBound => "log_first_requirement_bound",
            Self::ZeroFailRequirementBound => "zero_fail_requirement_bound",
            Self::ShipCallBlocked => "ship_call_blocked",
            Self::ProductCapabilityUnpromoted => "product_capability_unpromoted",
            Self::AnswerPacketRunEventLogBound => "answer_packet_run_event_log_bound",
            Self::MasProHonestyBound => "mas_pro_honesty_bound",
            Self::HeavyRoutesDeferred => "heavy_routes_deferred",
            Self::NoNewBytesLoaded => "no_new_bytes_loaded",
            Self::AutomatedChecksRequired => "automated_checks_required",
            Self::LogRuntimeEvidenceRequired => "log_runtime_evidence_required",
            Self::ManualRuntimeEvidenceRequired => "manual_runtime_evidence_required",
            Self::DistributionComplianceRequired => "distribution_compliance_required",
            Self::ThreePassCounterReset => "three_pass_counter_reset",
            Self::NextAutomatedChecksQueued => "next_automated_checks_queued",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-zero_fail-probe:error
// Plane: Verification
// Residency: release-audit zero_fail rejection taxonomy.
pub enum SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    MissingPreflightArtifact(String),
    MissingReleaseAuditSkill,
    ReleaseAuditLogFirstMissing,
    ReleaseAuditZeroFailMissing,
    GuardCursorMismatch,
    CapabilityStatusMismatch,
    ProductStatusMismatch,
    EmptyBlocker,
    DuplicateBlocker(String),
    MissingRequiredBlocker(&'static str),
    BlockerValidation(String),
    EmptyPhase,
    MissingPhase(&'static str),
    UpstreamRuntimeBytesMissing,
    UpstreamModelBytesMissing,
    ZeroFailRuntimeBytesLoaded,
    ZeroFailModelBytesLoaded,
    ZeroFailAlreadyClaimed,
    ZeroFailPassCountOverclaim,
    AutomatedChecksClaimed,
    LogEvidenceClaimed,
    ManualRuntimeEvidenceClaimed,
    DistributionComplianceEvidenceClaimed,
    ShipCallAuthorized,
    ProductCapabilityPromoted,
    AnswerPacketRunEventLogMissing,
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

impl fmt::Display for SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::MissingPreflightArtifact(id) => {
                write!(f, "witness `{id}` missing preflight artifact ref")
            }
            Self::MissingReleaseAuditSkill => write!(f, "release audit skill missing"),
            Self::ReleaseAuditLogFirstMissing => {
                write!(f, "release audit log-first requirement missing")
            }
            Self::ReleaseAuditZeroFailMissing => {
                write!(f, "release audit zero-fail requirement missing")
            }
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::EmptyBlocker => write!(f, "missing release-audit blocker"),
            Self::DuplicateBlocker(id) => write!(f, "duplicate blocker `{id}`"),
            Self::MissingRequiredBlocker(id) => write!(f, "missing required blocker `{id}`"),
            Self::BlockerValidation(error) => write!(f, "blocker validation failed: {error}"),
            Self::EmptyPhase => write!(f, "missing zero_fail phase"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::UpstreamRuntimeBytesMissing => write!(f, "upstream runtime bytes missing"),
            Self::UpstreamModelBytesMissing => write!(f, "upstream model bytes missing"),
            Self::ZeroFailRuntimeBytesLoaded => write!(f, "zero_fail loaded runtime bytes"),
            Self::ZeroFailModelBytesLoaded => write!(f, "zero_fail loaded model bytes"),
            Self::ZeroFailAlreadyClaimed => write!(f, "zero-fail release audit already claimed"),
            Self::ZeroFailPassCountOverclaim => write!(f, "zero-fail pass count overclaimed"),
            Self::AutomatedChecksClaimed => write!(f, "automated release checks were claimed"),
            Self::LogEvidenceClaimed => write!(f, "runtime log evidence was claimed"),
            Self::ManualRuntimeEvidenceClaimed => write!(f, "manual runtime evidence was claimed"),
            Self::DistributionComplianceEvidenceClaimed => {
                write!(f, "distribution/compliance evidence was claimed")
            }
            Self::ShipCallAuthorized => write!(f, "ship call authorized from zero_fail"),
            Self::ProductCapabilityPromoted => write!(f, "product capability promoted"),
            Self::AnswerPacketRunEventLogMissing => {
                write!(f, "AnswerPacket/RunEventLog proof missing")
            }
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

impl std::error::Error for SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-zero_fail-probe:metrics
// Plane: Verification
// Residency: zero_fail counts and byte accounting.
pub struct SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailMetrics {
    pub blocker_count: u64,
    pub phase_count: u64,
    pub upstream_runtime_bytes_loaded: u64,
    pub upstream_model_bytes_loaded: u64,
    pub zero_fail_runtime_bytes_loaded: u64,
    pub zero_fail_model_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-zero_fail-probe:witness
// Plane: Verification + Controller
// Residency: release-audit zero_fail queued without ship authority.
pub struct SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailWitness {
    pub witness_id: String,
    pub upstream_preflight_artifact_ref: String,
    pub release_audit_skill_ref: String,
    pub guard_next_existing_work: String,
    pub capability_overall_pass: bool,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub blockers: Vec<SmallModelProductRouteCapabilityBlocker>,
    pub phases: Vec<SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase>,
    pub upstream_runtime_bytes_loaded: u64,
    pub upstream_model_bytes_loaded: u64,
    pub zero_fail_runtime_bytes_loaded: u64,
    pub zero_fail_model_bytes_loaded: u64,
    pub release_audit_skill_exists: bool,
    pub release_audit_log_first_required: bool,
    pub release_audit_zero_fail_required: bool,
    pub release_audit_zero_fail_completed: bool,
    pub zero_fail_pass_count: u64,
    pub automated_checks_completed: bool,
    pub log_runtime_evidence_present: bool,
    pub manual_runtime_evidence_present: bool,
    pub distribution_compliance_evidence_present: bool,
    pub ship_call_authorized: bool,
    pub product_capability_promoted: bool,
    pub answer_packet_run_event_log_bound: bool,
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

impl SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        upstream_preflight_artifact_ref: impl Into<String>,
        release_audit_skill_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_overall_pass: bool,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        blockers: Vec<SmallModelProductRouteCapabilityBlocker>,
        phases: Vec<SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase>,
        upstream_runtime_bytes_loaded: u64,
        upstream_model_bytes_loaded: u64,
        zero_fail_runtime_bytes_loaded: u64,
        zero_fail_model_bytes_loaded: u64,
        release_audit_skill_exists: bool,
        release_audit_log_first_required: bool,
        release_audit_zero_fail_required: bool,
        release_audit_zero_fail_completed: bool,
        zero_fail_pass_count: u64,
        automated_checks_completed: bool,
        log_runtime_evidence_present: bool,
        manual_runtime_evidence_present: bool,
        distribution_compliance_evidence_present: bool,
        ship_call_authorized: bool,
        product_capability_promoted: bool,
        answer_packet_run_event_log_bound: bool,
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
    ) -> Result<Self, SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError> {
        let witness = Self {
            witness_id: witness_id.into(),
            upstream_preflight_artifact_ref: upstream_preflight_artifact_ref.into(),
            release_audit_skill_ref: release_audit_skill_ref.into(),
            guard_next_existing_work: guard_next_existing_work.into(),
            capability_overall_pass,
            capability_route_status: capability_route_status.into(),
            capability_next_bottleneck: capability_next_bottleneck.into(),
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            blockers,
            phases,
            upstream_runtime_bytes_loaded,
            upstream_model_bytes_loaded,
            zero_fail_runtime_bytes_loaded,
            zero_fail_model_bytes_loaded,
            release_audit_skill_exists,
            release_audit_log_first_required,
            release_audit_zero_fail_required,
            release_audit_zero_fail_completed,
            zero_fail_pass_count,
            automated_checks_completed,
            log_runtime_evidence_present,
            manual_runtime_evidence_present,
            distribution_compliance_evidence_present,
            ship_call_authorized,
            product_capability_promoted,
            answer_packet_run_event_log_bound,
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

    pub fn validate(&self) -> Result<(), SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError> {
        validate_clean("witness_id", &self.witness_id)?;
        validate_prefixed(
            &self.witness_id,
            &self.upstream_preflight_artifact_ref,
            UPSTREAM_PREFLIGHT_ARTIFACT_PREFIX,
        )?;
        validate_clean("release_audit_skill_ref", &self.release_audit_skill_ref)?;
        if self.release_audit_skill_ref != RELEASE_AUDIT_SKILL_PATH {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::MissingReleaseAuditSkill,
            );
        }
        if self.guard_next_existing_work
            != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_ZERO_FAIL_PROBE_CURSOR
            && self.guard_next_existing_work
                != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_ZERO_FAIL_PROBE_NEXT_CURSOR
        && self.guard_next_existing_work != ADVANCED_RELEASE_AUDIT_CURSOR
        {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::GuardCursorMismatch,
            );
        }
        if self.capability_overall_pass
            || self.capability_route_status != "vault_research_route_with_packetized_mitigation"
            || (self.capability_next_bottleneck
                != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_ZERO_FAIL_PROBE_CURSOR
                && self.capability_next_bottleneck
                    != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_ZERO_FAIL_PROBE_NEXT_CURSOR
        && self.capability_next_bottleneck != ADVANCED_RELEASE_AUDIT_CURSOR)
        {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::CapabilityStatusMismatch,
            );
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.route_authority
                != "fresh_product_runtime_l3_release_audit_zero_fail_no_ship_authority"
        {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::ProductStatusMismatch,
            );
        }
        if self.blockers.len() < MIN_BLOCKER_COUNT {
            return Err(SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::EmptyBlocker);
        }
        let mut blocker_ids = HashSet::new();
        for blocker in &self.blockers {
            blocker.validate().map_err(|error| {
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::BlockerValidation(
                    error.to_string(),
                )
            })?;
            if !blocker_ids.insert(blocker.blocker_id.clone()) {
                return Err(
                    SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::DuplicateBlocker(
                        blocker.blocker_id.clone(),
                    ),
                );
            }
        }
        for required in required_fresh_product_runtime_l3_release_audit_zero_fail_blockers() {
            if !blocker_ids.contains(required) {
                return Err(
                    SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::MissingRequiredBlocker(
                        required,
                    ),
                );
            }
        }
        if self.phases.is_empty() {
            return Err(SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::EmptyPhase);
        }
        let observed_phases = self
            .phases
            .iter()
            .map(SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::tag)
            .collect::<BTreeSet<_>>();
        for phase in required_fresh_product_runtime_l3_release_audit_zero_fail_phases() {
            if !observed_phases.contains(phase.tag()) {
                return Err(
                    SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::MissingPhase(
                        phase.tag(),
                    ),
                );
            }
        }
        if self.upstream_runtime_bytes_loaded == 0 {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::UpstreamRuntimeBytesMissing,
            );
        }
        if self.upstream_model_bytes_loaded == 0 {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::UpstreamModelBytesMissing,
            );
        }
        if self.zero_fail_runtime_bytes_loaded != 0 {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::ZeroFailRuntimeBytesLoaded,
            );
        }
        if self.zero_fail_model_bytes_loaded != 0 {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::ZeroFailModelBytesLoaded,
            );
        }
        if !self.release_audit_skill_exists {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::MissingReleaseAuditSkill,
            );
        }
        if !self.release_audit_log_first_required {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::ReleaseAuditLogFirstMissing,
            );
        }
        if !self.release_audit_zero_fail_required {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::ReleaseAuditZeroFailMissing,
            );
        }
        if self.release_audit_zero_fail_completed {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::ZeroFailAlreadyClaimed,
            );
        }
        if self.zero_fail_pass_count != 0 {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::ZeroFailPassCountOverclaim,
            );
        }
        if self.automated_checks_completed {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::AutomatedChecksClaimed,
            );
        }
        if self.log_runtime_evidence_present {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::LogEvidenceClaimed,
            );
        }
        if self.manual_runtime_evidence_present {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::ManualRuntimeEvidenceClaimed,
            );
        }
        if self.distribution_compliance_evidence_present {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::DistributionComplianceEvidenceClaimed,
            );
        }
        if self.ship_call_authorized {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::ShipCallAuthorized,
            );
        }
        if self.product_capability_promoted {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::ProductCapabilityPromoted,
            );
        }
        if !self.answer_packet_run_event_log_bound {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::AnswerPacketRunEventLogMissing,
            );
        }
        if !self.l1_l2_l3_separated {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::L1L2L3NotSeparated,
            );
        }
        if self.hidden_authority_attempted {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::HiddenAuthorityAttempted,
            );
        }
        if self.route_mutation_attempted {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::RouteMutationAttempted,
            );
        }
        if self.mas_live_agent_overclaim_attempted {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::MasLiveAgentOverclaim,
            );
        }
        if self.l2_green_claimed {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::L2GreenClaimAttempted,
            );
        }
        if self.l3_green_claimed {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::L3GreenClaimAttempted,
            );
        }
        if self.autogenous_kernel_attempted {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::AutogenousKernelAttempted,
            );
        }
        if self.seventy_b_product_claimed {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::SeventyBProductClaimed,
            );
        }
        if self.long_context_shard_product_claimed {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::LongContextShardProductClaimed,
            );
        }
        if self.next_cursor
            != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_ZERO_FAIL_PROBE_NEXT_CURSOR
        {
            return Err(SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::NextCursorMismatch);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::MetadataBudgetExceeded,
            );
        }
        Ok(())
    }

    pub fn metrics(&self) -> SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailMetrics {
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailMetrics {
            blocker_count: self.blockers.len() as u64,
            phase_count: self
                .phases
                .iter()
                .map(SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::tag)
                .collect::<BTreeSet<_>>()
                .len() as u64,
            upstream_runtime_bytes_loaded: self.upstream_runtime_bytes_loaded,
            upstream_model_bytes_loaded: self.upstream_model_bytes_loaded,
            zero_fail_runtime_bytes_loaded: self.zero_fail_runtime_bytes_loaded,
            zero_fail_model_bytes_loaded: self.zero_fail_model_bytes_loaded,
        }
    }

    pub fn address(&self) -> String {
        let mut parts = vec![
            self.witness_id.clone(),
            self.upstream_preflight_artifact_ref.clone(),
            self.release_audit_skill_ref.clone(),
            self.guard_next_existing_work.clone(),
            self.capability_route_status.clone(),
            self.capability_next_bottleneck.clone(),
            self.route_authority.clone(),
            self.next_cursor.clone(),
            self.upstream_runtime_bytes_loaded.to_string(),
            self.upstream_model_bytes_loaded.to_string(),
            self.zero_fail_pass_count.to_string(),
            self.automated_checks_completed.to_string(),
            self.log_runtime_evidence_present.to_string(),
            self.manual_runtime_evidence_present.to_string(),
            self.distribution_compliance_evidence_present.to_string(),
        ];
        for blocker in &self.blockers {
            parts.push(blocker.blocker_id.clone());
            parts.push(blocker.plane.clone());
            parts.push(blocker.evidence_ref.clone());
            parts.push(blocker.answer_packet_ref.clone());
            parts.push(blocker.safety_ref.clone());
        }
        for phase in &self.phases {
            parts.push(phase.tag().to_string());
        }
        parts.sort();
        sha256_hex(parts.join("|").as_bytes())
    }
}

pub fn required_fresh_product_runtime_l3_release_audit_zero_fail_phases(
) -> [SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase; 18] {
    [
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::UpstreamPreflightBound,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::GuardZeroFailCursorBound,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::CapabilityKernelRedBound,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::ReleaseAuditSkillBound,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::LogFirstRequirementBound,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::ZeroFailRequirementBound,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::ShipCallBlocked,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::ProductCapabilityUnpromoted,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::AnswerPacketRunEventLogBound,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::MasProHonestyBound,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::HeavyRoutesDeferred,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::NoNewBytesLoaded,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::AutomatedChecksRequired,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::LogRuntimeEvidenceRequired,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::ManualRuntimeEvidenceRequired,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::DistributionComplianceRequired,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::ThreePassCounterReset,
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailPhase::NextAutomatedChecksQueued,
    ]
}

pub fn required_fresh_product_runtime_l3_release_audit_zero_fail_blockers() -> [&'static str; 14] {
    [
        "blocker:l2_capability_kernel_red",
        "blocker:l3_fresh_runtime_manual_review_l1_only",
        "blocker:release_audit_skill_log_first_required",
        "blocker:release_audit_zero_fail_not_run",
        "blocker:release_audit_automated_checks_not_run",
        "blocker:release_audit_log_evidence_missing",
        "blocker:release_audit_manual_runtime_missing",
        "blocker:release_audit_distribution_compliance_missing",
        "blocker:release_audit_three_passes_missing",
        "blocker:mas_live_agent_not_promoted",
        "blocker:live_70b_route_not_promoted",
        "blocker:kv_direct_128k_not_promoted",
        "blocker:autogenous_kernel_not_promoted",
        "blocker:ship_call_not_authorized",
    ]
}

pub fn fresh_product_runtime_l3_release_audit_zero_fail_metadata_budget_bytes() -> u64 {
    MAX_METADATA_BYTES
}

pub fn fresh_product_runtime_l3_release_audit_zero_fail_skill_path() -> &'static str {
    RELEASE_AUDIT_SKILL_PATH
}

fn validate_prefixed(
    witness_id: &str,
    value: &str,
    prefix: &str,
) -> Result<(), SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError> {
    validate_clean("artifact_ref", value)?;
    if !value.starts_with(prefix) {
        return Err(
            SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::MissingPreflightArtifact(
                witness_id.to_string(),
            ),
        );
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError> {
    if value.is_empty() {
        return Err(SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::MissingField(field));
    }
    if value.trim() != value {
        return Err(
            SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::FieldHasSurroundingWhitespace(
                field,
            ),
        );
    }
    if value.chars().any(char::is_control) {
        return Err(
            SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::FieldContainsControlCharacter(
                field,
            ),
        );
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn blocker(id: &str) -> SmallModelProductRouteCapabilityBlocker {
        SmallModelProductRouteCapabilityBlocker {
            blocker_id: id.to_string(),
            plane: "verification".to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            evidence_ref: format!("evidence:{id}"),
            answer_packet_ref: "answer_packet:fresh_release_audit_zero_fail:red".to_string(),
            rollback_ref: "rollback:no_release_readiness_from_zero_fail".to_string(),
            budget_ref: "budget:zero_zero_fail_runtime_bytes".to_string(),
            safety_ref: "safety:release_audit_zero_fail_required".to_string(),
            visible: true,
            currently_green: false,
            hidden_route_authority: false,
            route_policy_mutated: false,
        }
    }

    fn witness() -> SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailWitness {
        SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailWitness::new(
            "small-model-fresh-product-runtime-l3-release-audit-zero_fail:red-state",
            "artifact:small_model_runtime_harness_fresh_product_runtime_l3_release_audit_preflight_probe:result",
            RELEASE_AUDIT_SKILL_PATH,
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_ZERO_FAIL_PROBE_CURSOR,
            false,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_ZERO_FAIL_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "fresh_product_runtime_l3_release_audit_zero_fail_no_ship_authority",
            required_fresh_product_runtime_l3_release_audit_zero_fail_blockers()
                .into_iter()
                .map(blocker)
                .collect(),
            required_fresh_product_runtime_l3_release_audit_zero_fail_phases().to_vec(),
            16_777_216,
            2_137_326_367,
            0,
            0,
            true,
            true,
            true,
            false,
            0,
            false,
            false,
            false,
            false,
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
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_ZERO_FAIL_PROBE_NEXT_CURSOR,
            4096,
        )
        .expect("valid release-audit zero_fail witness")
    }

    #[test]
    fn fixture_validates_and_has_deterministic_address() {
        let valid_witness = witness();
        assert_eq!(
            valid_witness.metrics().phase_count,
            required_fresh_product_runtime_l3_release_audit_zero_fail_phases().len() as u64
        );
        assert_eq!(valid_witness.metrics().zero_fail_runtime_bytes_loaded, 0);
        assert_eq!(valid_witness.address(), witness().address());
    }

    #[test]
    fn missing_release_audit_skill_is_rejected() {
        let mut candidate = witness();
        candidate.release_audit_skill_exists = false;
        let error = candidate
            .validate()
            .expect_err("release audit skill is required");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::MissingReleaseAuditSkill
        ));
    }

    #[test]
    fn zero_fail_completion_claim_is_rejected() {
        let mut candidate = witness();
        candidate.release_audit_zero_fail_completed = true;
        let error = candidate
            .validate()
            .expect_err("zero_fail cannot claim zero-fail completion");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::ZeroFailAlreadyClaimed
        ));
    }

    #[test]
    fn ship_call_is_rejected() {
        let mut candidate = witness();
        candidate.ship_call_authorized = true;
        let error = candidate
            .validate()
            .expect_err("zero_fail cannot authorize ship call");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::ShipCallAuthorized
        ));
    }

    #[test]
    fn duplicate_blockers_are_rejected() {
        let mut candidate = witness();
        candidate.blockers[1] = candidate.blockers[0].clone();
        let error = candidate.validate().expect_err("duplicate blocker rejects");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::DuplicateBlocker(_)
        ));
    }

    #[test]
    fn zero_fail_runtime_bytes_are_rejected() {
        let mut candidate = witness();
        candidate.zero_fail_runtime_bytes_loaded = 1;
        let error = candidate
            .validate()
            .expect_err("zero_fail byte load rejects");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::ZeroFailRuntimeBytesLoaded
        ));
    }

    #[test]
    fn zero_fail_pass_count_overclaim_is_rejected() {
        let mut candidate = witness();
        candidate.zero_fail_pass_count = 1;
        let error = candidate
            .validate()
            .expect_err("zero_fail pass count cannot be claimed by this gate");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::ZeroFailPassCountOverclaim
        ));
    }

    #[test]
    fn automated_checks_claim_is_rejected() {
        let mut candidate = witness();
        candidate.automated_checks_completed = true;
        let error = candidate
            .validate()
            .expect_err("automated checks cannot be claimed by this gate");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3ReleaseAuditZeroFailError::AutomatedChecksClaimed
        ));
    }

    #[test]
    fn runtime_and_distribution_evidence_claims_are_rejected() {
        for candidate in [
            {
                let mut candidate = witness();
                candidate.log_runtime_evidence_present = true;
                candidate
            },
            {
                let mut candidate = witness();
                candidate.manual_runtime_evidence_present = true;
                candidate
            },
            {
                let mut candidate = witness();
                candidate.distribution_compliance_evidence_present = true;
                candidate
            },
        ] {
            assert!(
                candidate.validate().is_err(),
                "runtime/distribution evidence claim should be rejected"
            );
        }
    }
}
