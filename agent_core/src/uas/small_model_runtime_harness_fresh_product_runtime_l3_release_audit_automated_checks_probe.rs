//! Fresh product-runtime L3 release-audit automated-checks probe.
//!
//! This witness proves the release-audit automated command set ran and passed.
//! It remains a blocker-preserving L1/L3 proof: runtime logs, manual runtime
//! review, distribution/compliance review, and three uninterrupted zero-fail
//! passes are still required before any ship or product-capability claim.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, SmallModelProductRouteCapabilityBlocker};

pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";
pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe";

const UPSTREAM_ZERO_FAIL_ARTIFACT_PREFIX: &str =
    "artifact:small_model_runtime_harness_fresh_product_runtime_l3_release_audit_zero_fail_probe:";
const RELEASE_AUDIT_SKILL_PATH: &str = ".agents/skills/epistemos_release_audit/SKILL.md";
const MIN_BLOCKER_COUNT: usize = 12;
const MAX_METADATA_BYTES: u64 = 4 * 1024 * 1024;
const LOG_PREFIX: &str =
    "log:artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/logs/";

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-automated-checks-probe:phase
// Plane: Verification + Controller
// Residency: release-audit automated command evidence before log/manual/distribution gates.
pub enum SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase {
    UpstreamZeroFailBound,
    GuardAutomatedChecksCursorBound,
    CapabilityKernelRedBound,
    ReleaseAuditSkillBound,
    XcodebuildBuildChecked,
    XcodebuildTestChecked,
    GraphEngineCargoTestChecked,
    OmegaMcpCargoTestChecked,
    OmegaAxCargoTestChecked,
    CommandLogsBound,
    ProductCapabilityUnpromoted,
    ShipCallBlocked,
    L1L2L3Separated,
    HeavyRoutesDeferred,
    LogEvidenceQueued,
    ManualRuntimeEvidenceRequired,
    DistributionComplianceRequired,
    ThreePassCounterZero,
    NextLogEvidenceQueued,
}

impl SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase {
    pub fn tag(&self) -> &'static str {
        match self {
            Self::UpstreamZeroFailBound => "upstream_zero_fail_bound",
            Self::GuardAutomatedChecksCursorBound => "guard_automated_checks_cursor_bound",
            Self::CapabilityKernelRedBound => "capability_kernel_red_bound",
            Self::ReleaseAuditSkillBound => "release_audit_skill_bound",
            Self::XcodebuildBuildChecked => "xcodebuild_build_checked",
            Self::XcodebuildTestChecked => "xcodebuild_test_checked",
            Self::GraphEngineCargoTestChecked => "graph_engine_cargo_test_checked",
            Self::OmegaMcpCargoTestChecked => "omega_mcp_cargo_test_checked",
            Self::OmegaAxCargoTestChecked => "omega_ax_cargo_test_checked",
            Self::CommandLogsBound => "command_logs_bound",
            Self::ProductCapabilityUnpromoted => "product_capability_unpromoted",
            Self::ShipCallBlocked => "ship_call_blocked",
            Self::L1L2L3Separated => "l1_l2_l3_separated",
            Self::HeavyRoutesDeferred => "heavy_routes_deferred",
            Self::LogEvidenceQueued => "log_evidence_queued",
            Self::ManualRuntimeEvidenceRequired => "manual_runtime_evidence_required",
            Self::DistributionComplianceRequired => "distribution_compliance_required",
            Self::ThreePassCounterZero => "three_pass_counter_zero",
            Self::NextLogEvidenceQueued => "next_log_evidence_queued",
        }
    }
}

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-automated-checks-probe:check-status
// Plane: Verification
// Residency: normalized command status.
pub enum SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckStatus {
    Pass,
    Fail,
}

impl SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckStatus {
    pub fn tag(&self) -> &'static str {
        match self {
            Self::Pass => "pass",
            Self::Fail => "fail",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-automated-checks-probe:error
// Plane: Verification
// Residency: automated-checks rejection taxonomy.
pub enum SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    MissingUpstreamZeroFailArtifact(String),
    MissingReleaseAuditSkill,
    GuardCursorMismatch,
    CapabilityStatusMismatch,
    ProductStatusMismatch,
    EmptyCheck,
    DuplicateCheck(String),
    MissingRequiredCheck(&'static str),
    CheckFailed(String),
    CheckExitCodeMismatch(String),
    CheckLogMissing(String),
    CheckLogDigestInvalid(String),
    CheckDurationZero(String),
    EmptyBlocker,
    DuplicateBlocker(String),
    MissingRequiredBlocker(&'static str),
    BlockerValidation(String),
    EmptyPhase,
    MissingPhase(&'static str),
    AutomatedChecksNotCompleted,
    ZeroFailPassCountOverclaim,
    LogEvidenceClaimed,
    ManualRuntimeEvidenceClaimed,
    DistributionComplianceEvidenceClaimed,
    ShipCallAuthorized,
    ProductCapabilityPromoted,
    L1L2L3NotSeparated,
    HiddenAuthorityAttempted,
    RouteMutationAttempted,
    MasLiveAgentOverclaim,
    L2GreenClaimAttempted,
    L3GreenClaimAttempted,
    AutogenousKernelAttempted,
    SeventyBProductClaimed,
    LongContextShardProductClaimed,
    ModelRuntimeBytesLoaded,
    NextCursorMismatch,
    MetadataBudgetExceeded,
}

impl fmt::Display for SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::MissingUpstreamZeroFailArtifact(id) => {
                write!(f, "witness `{id}` missing upstream zero-fail artifact ref")
            }
            Self::MissingReleaseAuditSkill => write!(f, "release audit skill missing"),
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::EmptyCheck => write!(f, "missing automated check"),
            Self::DuplicateCheck(id) => write!(f, "duplicate automated check `{id}`"),
            Self::MissingRequiredCheck(id) => write!(f, "missing required automated check `{id}`"),
            Self::CheckFailed(id) => write!(f, "automated check `{id}` did not pass"),
            Self::CheckExitCodeMismatch(id) => write!(
                f,
                "automated check `{id}` status does not match its exit code"
            ),
            Self::CheckLogMissing(id) => write!(f, "automated check `{id}` missing log proof"),
            Self::CheckLogDigestInvalid(id) => {
                write!(f, "automated check `{id}` has invalid log digest")
            }
            Self::CheckDurationZero(id) => write!(f, "automated check `{id}` has zero duration"),
            Self::EmptyBlocker => write!(f, "missing release-audit blocker"),
            Self::DuplicateBlocker(id) => write!(f, "duplicate blocker `{id}`"),
            Self::MissingRequiredBlocker(id) => write!(f, "missing required blocker `{id}`"),
            Self::BlockerValidation(error) => write!(f, "blocker validation failed: {error}"),
            Self::EmptyPhase => write!(f, "missing automated-check phase"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::AutomatedChecksNotCompleted => write!(f, "automated checks not completed"),
            Self::ZeroFailPassCountOverclaim => write!(f, "zero-fail pass count overclaimed"),
            Self::LogEvidenceClaimed => write!(f, "runtime log evidence was claimed"),
            Self::ManualRuntimeEvidenceClaimed => write!(f, "manual runtime evidence was claimed"),
            Self::DistributionComplianceEvidenceClaimed => {
                write!(f, "distribution/compliance evidence was claimed")
            }
            Self::ShipCallAuthorized => write!(f, "ship call authorized"),
            Self::ProductCapabilityPromoted => write!(f, "product capability promoted"),
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
            Self::ModelRuntimeBytesLoaded => write!(f, "automated gate loaded model/runtime bytes"),
            Self::NextCursorMismatch => write!(f, "next cursor mismatch"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-automated-checks-probe:check
// Plane: Verification
// Residency: required command evidence row.
pub struct SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckRecord {
    pub check_id: String,
    pub status: SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckStatus,
    pub exit_code: i32,
    pub duration_seconds: u64,
    pub log_ref: String,
    pub log_sha256: String,
    pub log_bytes: u64,
}

impl SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckRecord {
    pub fn validate(
        &self,
    ) -> Result<(), SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError> {
        validate_clean("check_id", &self.check_id)?;
        match self.status {
            SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckStatus::Pass
                if self.exit_code != 0 =>
            {
                return Err(
                    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::CheckExitCodeMismatch(
                        self.check_id.clone(),
                    ),
                );
            }
            SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckStatus::Fail
                if self.exit_code == 0 =>
            {
                return Err(
                    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::CheckExitCodeMismatch(
                        self.check_id.clone(),
                    ),
                );
            }
            _ => {}
        }
        if self.duration_seconds == 0 {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::CheckDurationZero(
                    self.check_id.clone(),
                ),
            );
        }
        validate_clean("log_ref", &self.log_ref)?;
        if !self.log_ref.starts_with(LOG_PREFIX) {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::CheckLogMissing(
                    self.check_id.clone(),
                ),
            );
        }
        validate_clean("log_sha256", &self.log_sha256)?;
        if !is_sha256_hex(&self.log_sha256) {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::CheckLogDigestInvalid(
                    self.check_id.clone(),
                ),
            );
        }
        if self.log_bytes == 0 {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::CheckLogMissing(
                    self.check_id.clone(),
                ),
            );
        }
        Ok(())
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-automated-checks-probe:metrics
// Plane: Verification
// Residency: automated-check counts and byte accounting.
pub struct SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksMetrics {
    pub check_count: u64,
    pub failed_check_count: u64,
    pub blocker_count: u64,
    pub phase_count: u64,
    pub log_bytes: u64,
    pub zero_fail_pass_count: u64,
    pub model_runtime_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-automated-checks-probe:witness
// Plane: Verification + Controller
// Residency: automated checks passed without release-ready authority.
pub struct SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksWitness {
    pub witness_id: String,
    pub upstream_zero_fail_artifact_ref: String,
    pub release_audit_skill_ref: String,
    pub guard_next_existing_work: String,
    pub capability_overall_pass: bool,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub checks: Vec<SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckRecord>,
    pub blockers: Vec<SmallModelProductRouteCapabilityBlocker>,
    pub phases: Vec<SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase>,
    pub automated_checks_completed: bool,
    pub zero_fail_pass_count: u64,
    pub log_runtime_evidence_present: bool,
    pub manual_runtime_evidence_present: bool,
    pub distribution_compliance_evidence_present: bool,
    pub ship_call_authorized: bool,
    pub product_capability_promoted: bool,
    pub l1_l2_l3_separated: bool,
    pub hidden_authority_attempted: bool,
    pub route_mutation_attempted: bool,
    pub mas_live_agent_overclaim_attempted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub autogenous_kernel_attempted: bool,
    pub seventy_b_product_claimed: bool,
    pub long_context_shard_product_claimed: bool,
    pub model_runtime_bytes_loaded: u64,
    pub next_cursor: String,
    pub metadata_bytes: u64,
}

impl SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        upstream_zero_fail_artifact_ref: impl Into<String>,
        release_audit_skill_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_overall_pass: bool,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        checks: Vec<SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckRecord>,
        blockers: Vec<SmallModelProductRouteCapabilityBlocker>,
        phases: Vec<SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase>,
        automated_checks_completed: bool,
        zero_fail_pass_count: u64,
        log_runtime_evidence_present: bool,
        manual_runtime_evidence_present: bool,
        distribution_compliance_evidence_present: bool,
        ship_call_authorized: bool,
        product_capability_promoted: bool,
        l1_l2_l3_separated: bool,
        hidden_authority_attempted: bool,
        route_mutation_attempted: bool,
        mas_live_agent_overclaim_attempted: bool,
        l2_green_claimed: bool,
        l3_green_claimed: bool,
        autogenous_kernel_attempted: bool,
        seventy_b_product_claimed: bool,
        long_context_shard_product_claimed: bool,
        model_runtime_bytes_loaded: u64,
        next_cursor: impl Into<String>,
        metadata_bytes: u64,
    ) -> Result<Self, SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError> {
        let witness = Self {
            witness_id: witness_id.into(),
            upstream_zero_fail_artifact_ref: upstream_zero_fail_artifact_ref.into(),
            release_audit_skill_ref: release_audit_skill_ref.into(),
            guard_next_existing_work: guard_next_existing_work.into(),
            capability_overall_pass,
            capability_route_status: capability_route_status.into(),
            capability_next_bottleneck: capability_next_bottleneck.into(),
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            checks,
            blockers,
            phases,
            automated_checks_completed,
            zero_fail_pass_count,
            log_runtime_evidence_present,
            manual_runtime_evidence_present,
            distribution_compliance_evidence_present,
            ship_call_authorized,
            product_capability_promoted,
            l1_l2_l3_separated,
            hidden_authority_attempted,
            route_mutation_attempted,
            mas_live_agent_overclaim_attempted,
            l2_green_claimed,
            l3_green_claimed,
            autogenous_kernel_attempted,
            seventy_b_product_claimed,
            long_context_shard_product_claimed,
            model_runtime_bytes_loaded,
            next_cursor: next_cursor.into(),
            metadata_bytes,
        };
        witness.validate()?;
        Ok(witness)
    }

    pub fn validate(
        &self,
    ) -> Result<(), SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError> {
        validate_clean("witness_id", &self.witness_id)?;
        validate_prefixed(
            &self.witness_id,
            &self.upstream_zero_fail_artifact_ref,
            UPSTREAM_ZERO_FAIL_ARTIFACT_PREFIX,
        )?;
        validate_clean("release_audit_skill_ref", &self.release_audit_skill_ref)?;
        if self.release_audit_skill_ref != RELEASE_AUDIT_SKILL_PATH {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::MissingReleaseAuditSkill,
            );
        }
        if self.guard_next_existing_work
            != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_CURSOR
            && self.guard_next_existing_work
                != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_NEXT_CURSOR
        {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::GuardCursorMismatch,
            );
        }
        if self.capability_overall_pass
            || self.capability_route_status != "vault_research_route_with_packetized_mitigation"
            || (self.capability_next_bottleneck
                != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_CURSOR
                && self.capability_next_bottleneck
                    != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_NEXT_CURSOR)
        {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::CapabilityStatusMismatch,
            );
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.route_authority
                != "fresh_product_runtime_l3_release_audit_automated_checks_no_ship_authority"
        {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::ProductStatusMismatch,
            );
        }
        if self.checks.is_empty() {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::EmptyCheck,
            );
        }
        let mut check_ids = HashSet::new();
        for check in &self.checks {
            check.validate()?;
            if !check_ids.insert(check.check_id.clone()) {
                return Err(
                    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::DuplicateCheck(
                        check.check_id.clone(),
                    ),
                );
            }
        }
        for required in required_fresh_product_runtime_l3_release_audit_automated_checks() {
            if !check_ids.contains(required) {
                return Err(
                    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::MissingRequiredCheck(
                        required,
                    ),
                );
            }
        }
        if self.blockers.len() < MIN_BLOCKER_COUNT {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::EmptyBlocker,
            );
        }
        let mut blocker_ids = HashSet::new();
        for blocker in &self.blockers {
            blocker.validate().map_err(|error| {
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::BlockerValidation(
                    error.to_string(),
                )
            })?;
            if !blocker_ids.insert(blocker.blocker_id.clone()) {
                return Err(
                    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::DuplicateBlocker(
                        blocker.blocker_id.clone(),
                    ),
                );
            }
        }
        for required in required_fresh_product_runtime_l3_release_audit_automated_check_blockers() {
            if !blocker_ids.contains(required) {
                return Err(
                    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::MissingRequiredBlocker(
                        required,
                    ),
                );
            }
        }
        if self.phases.is_empty() {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::EmptyPhase,
            );
        }
        let observed_phases = self
            .phases
            .iter()
            .map(SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::tag)
            .collect::<BTreeSet<_>>();
        for phase in required_fresh_product_runtime_l3_release_audit_automated_check_phases() {
            if !observed_phases.contains(phase.tag()) {
                return Err(
                    SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::MissingPhase(
                        phase.tag(),
                    ),
                );
            }
        }
        if !self.automated_checks_completed {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::AutomatedChecksNotCompleted,
            );
        }
        if self.zero_fail_pass_count != 0 {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::ZeroFailPassCountOverclaim,
            );
        }
        if self.log_runtime_evidence_present {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::LogEvidenceClaimed,
            );
        }
        if self.manual_runtime_evidence_present {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::ManualRuntimeEvidenceClaimed,
            );
        }
        if self.distribution_compliance_evidence_present {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::DistributionComplianceEvidenceClaimed,
            );
        }
        if self.ship_call_authorized {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::ShipCallAuthorized,
            );
        }
        if self.product_capability_promoted {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::ProductCapabilityPromoted,
            );
        }
        if !self.l1_l2_l3_separated {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::L1L2L3NotSeparated,
            );
        }
        if self.hidden_authority_attempted {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::HiddenAuthorityAttempted,
            );
        }
        if self.route_mutation_attempted {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::RouteMutationAttempted,
            );
        }
        if self.mas_live_agent_overclaim_attempted {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::MasLiveAgentOverclaim,
            );
        }
        if self.l2_green_claimed {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::L2GreenClaimAttempted,
            );
        }
        if self.l3_green_claimed {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::L3GreenClaimAttempted,
            );
        }
        if self.autogenous_kernel_attempted {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::AutogenousKernelAttempted,
            );
        }
        if self.seventy_b_product_claimed {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::SeventyBProductClaimed,
            );
        }
        if self.long_context_shard_product_claimed {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::LongContextShardProductClaimed,
            );
        }
        if self.model_runtime_bytes_loaded != 0 {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::ModelRuntimeBytesLoaded,
            );
        }
        if self.next_cursor
            != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_NEXT_CURSOR
        {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::NextCursorMismatch,
            );
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(
                SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::MetadataBudgetExceeded,
            );
        }
        Ok(())
    }

    pub fn metrics(&self) -> SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksMetrics {
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksMetrics {
            check_count: self.checks.len() as u64,
            failed_check_count: self
                .checks
                .iter()
                .filter(|check| {
                    check.status
                        != SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckStatus::Pass
                        || check.exit_code != 0
                })
                .count() as u64,
            blocker_count: self.blockers.len() as u64,
            phase_count: self
                .phases
                .iter()
                .map(SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::tag)
                .collect::<BTreeSet<_>>()
                .len() as u64,
            log_bytes: self.checks.iter().map(|check| check.log_bytes).sum(),
            zero_fail_pass_count: self.zero_fail_pass_count,
            model_runtime_bytes_loaded: self.model_runtime_bytes_loaded,
        }
    }

    pub fn address(&self) -> String {
        let mut parts = vec![
            self.witness_id.clone(),
            self.upstream_zero_fail_artifact_ref.clone(),
            self.release_audit_skill_ref.clone(),
            self.guard_next_existing_work.clone(),
            self.capability_route_status.clone(),
            self.capability_next_bottleneck.clone(),
            self.route_authority.clone(),
            self.next_cursor.clone(),
            self.automated_checks_completed.to_string(),
            self.zero_fail_pass_count.to_string(),
            self.log_runtime_evidence_present.to_string(),
            self.manual_runtime_evidence_present.to_string(),
            self.distribution_compliance_evidence_present.to_string(),
        ];
        for check in &self.checks {
            parts.push(check.check_id.clone());
            parts.push(check.status.tag().to_string());
            parts.push(check.exit_code.to_string());
            parts.push(check.log_ref.clone());
            parts.push(check.log_sha256.clone());
            parts.push(check.log_bytes.to_string());
        }
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

pub fn required_fresh_product_runtime_l3_release_audit_automated_checks() -> [&'static str; 5] {
    [
        "xcodebuild_build",
        "xcodebuild_test",
        "graph_engine_cargo_test",
        "omega_mcp_cargo_test",
        "omega_ax_cargo_test",
    ]
}

pub fn required_fresh_product_runtime_l3_release_audit_automated_check_phases(
) -> [SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase; 19] {
    [
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::UpstreamZeroFailBound,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::GuardAutomatedChecksCursorBound,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::CapabilityKernelRedBound,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::ReleaseAuditSkillBound,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::XcodebuildBuildChecked,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::XcodebuildTestChecked,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::GraphEngineCargoTestChecked,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::OmegaMcpCargoTestChecked,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::OmegaAxCargoTestChecked,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::CommandLogsBound,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::ProductCapabilityUnpromoted,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::ShipCallBlocked,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::L1L2L3Separated,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::HeavyRoutesDeferred,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::LogEvidenceQueued,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::ManualRuntimeEvidenceRequired,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::DistributionComplianceRequired,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::ThreePassCounterZero,
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksPhase::NextLogEvidenceQueued,
    ]
}

pub fn required_fresh_product_runtime_l3_release_audit_automated_check_blockers(
) -> [&'static str; 12] {
    [
        "blocker:l2_capability_kernel_red",
        "blocker:l3_fresh_runtime_manual_review_l1_only",
        "blocker:release_audit_zero_fail_three_passes_missing",
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

pub fn fresh_product_runtime_l3_release_audit_automated_checks_metadata_budget_bytes() -> u64 {
    MAX_METADATA_BYTES
}

pub fn fresh_product_runtime_l3_release_audit_automated_checks_skill_path() -> &'static str {
    RELEASE_AUDIT_SKILL_PATH
}

fn validate_prefixed(
    witness_id: &str,
    value: &str,
    prefix: &str,
) -> Result<(), SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError> {
    validate_clean("artifact_ref", value)?;
    if !value.starts_with(prefix) {
        return Err(
            SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::MissingUpstreamZeroFailArtifact(
                witness_id.to_string(),
            ),
        );
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError> {
    if value.is_empty() {
        return Err(
            SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::MissingField(field),
        );
    }
    if value.trim() != value {
        return Err(
            SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::FieldHasSurroundingWhitespace(
                field,
            ),
        );
    }
    if value.chars().any(char::is_control) {
        return Err(
            SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::FieldContainsControlCharacter(
                field,
            ),
        );
    }
    Ok(())
}

fn is_sha256_hex(value: &str) -> bool {
    let value = value.strip_prefix("sha256:").unwrap_or(value);
    value.len() == 64
        && value
            .chars()
            .all(|ch| ch.is_ascii_hexdigit() && !ch.is_ascii_uppercase())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn check(id: &str) -> SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckRecord {
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckRecord {
            check_id: id.to_string(),
            status: SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckStatus::Pass,
            exit_code: 0,
            duration_seconds: 1,
            log_ref: format!("{LOG_PREFIX}{id}.log"),
            log_sha256: format!("sha256:{}", "a".repeat(64)),
            log_bytes: 64,
        }
    }

    fn blocker(id: &str) -> SmallModelProductRouteCapabilityBlocker {
        SmallModelProductRouteCapabilityBlocker {
            blocker_id: id.to_string(),
            plane: "verification".to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            evidence_ref: format!("evidence:{id}"),
            answer_packet_ref: "answer_packet:fresh_release_audit_automated_checks:red".to_string(),
            rollback_ref: "rollback:no_release_readiness_from_automated_checks".to_string(),
            budget_ref: "budget:zero_model_runtime_bytes_for_automated_checks".to_string(),
            safety_ref: "safety:logs_manual_distribution_three_passes_still_required".to_string(),
            visible: true,
            currently_green: false,
            hidden_route_authority: false,
            route_policy_mutated: false,
        }
    }

    fn witness() -> SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksWitness {
        SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksWitness::new(
            "small-model-fresh-product-runtime-l3-release-audit-automated-checks:passed-not-ready",
            "artifact:small_model_runtime_harness_fresh_product_runtime_l3_release_audit_zero_fail_probe:result",
            RELEASE_AUDIT_SKILL_PATH,
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_CURSOR,
            false,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "fresh_product_runtime_l3_release_audit_automated_checks_no_ship_authority",
            required_fresh_product_runtime_l3_release_audit_automated_checks()
                .into_iter()
                .map(check)
                .collect(),
            required_fresh_product_runtime_l3_release_audit_automated_check_blockers()
                .into_iter()
                .map(blocker)
                .collect(),
            required_fresh_product_runtime_l3_release_audit_automated_check_phases().to_vec(),
            true,
            0,
            false,
            false,
            false,
            false,
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
            0,
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_AUTOMATED_CHECKS_PROBE_NEXT_CURSOR,
            4096,
        )
        .expect("valid automated-checks witness")
    }

    #[test]
    fn fixture_validates_and_address_is_deterministic() {
        let valid_witness = witness();
        assert_eq!(valid_witness.metrics().check_count, 5);
        assert_eq!(valid_witness.metrics().failed_check_count, 0);
        assert_eq!(valid_witness.address(), witness().address());
    }

    #[test]
    fn missing_required_check_rejects() {
        let mut candidate = witness();
        candidate
            .checks
            .retain(|check| check.check_id != "xcodebuild_test");
        let error = candidate
            .validate()
            .expect_err("required xcodebuild test check rejects");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::MissingRequiredCheck(
                "xcodebuild_test"
            )
        ));
    }

    #[test]
    fn duplicate_check_rejects() {
        let mut candidate = witness();
        candidate.checks[1] = candidate.checks[0].clone();
        let error = candidate.validate().expect_err("duplicate check rejects");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::DuplicateCheck(_)
        ));
    }

    #[test]
    fn failed_check_validates_and_counts_when_exit_code_is_nonzero() {
        let mut candidate = witness();
        candidate.checks[0].status =
            SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckStatus::Fail;
        candidate.checks[0].exit_code = 65;
        candidate
            .validate()
            .expect("failed check with nonzero exit code remains ledger evidence");
        assert_eq!(candidate.metrics().failed_check_count, 1);
    }

    #[test]
    fn failed_check_with_zero_exit_code_rejects() {
        let mut candidate = witness();
        candidate.checks[0].status =
            SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedCheckStatus::Fail;
        let error = candidate
            .validate()
            .expect_err("fail status with zero exit rejects");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::CheckExitCodeMismatch(
                _
            )
        ));
    }

    #[test]
    fn missing_log_rejects() {
        let mut candidate = witness();
        candidate.checks[0].log_bytes = 0;
        let error = candidate.validate().expect_err("missing log rejects");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::CheckLogMissing(_)
        ));
    }

    #[test]
    fn ship_and_product_claims_reject() {
        let mut ship_candidate = witness();
        ship_candidate.ship_call_authorized = true;
        assert!(matches!(
            ship_candidate.validate().expect_err("ship call rejects"),
            SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::ShipCallAuthorized
        ));
        let mut product_candidate = witness();
        product_candidate.product_capability_promoted = true;
        assert!(matches!(
            product_candidate
                .validate()
                .expect_err("product promotion rejects"),
            SmallModelFreshProductRuntimeL3ReleaseAuditAutomatedChecksError::ProductCapabilityPromoted
        ));
    }

    #[test]
    fn downstream_release_evidence_claims_reject() {
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
                "downstream release evidence claim should reject"
            );
        }
    }
}
