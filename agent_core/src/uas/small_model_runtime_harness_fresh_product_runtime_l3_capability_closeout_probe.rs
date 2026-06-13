//! Fresh product-runtime L3 capability closeout probe for the small-model harness.
//!
//! This witness closes the fresh Qwen3-4B product-runtime proof segment without
//! promoting L2 or L3. It preserves the manual-review evidence, enumerates the
//! still-red blockers, and queues release-audit preflight work before any ship
//! or live-route claim can advance.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use super::small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe::SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_RELEASE_AUDIT_CURSOR;
use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, SmallModelProductRouteCapabilityBlocker};

pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_CAPABILITY_CLOSEOUT_PROBE_CURSOR:
    &str = "small_model_runtime_harness_fresh_product_runtime_l3_capability_closeout_probe";
pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_CAPABILITY_CLOSEOUT_PROBE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_preflight_probe";

const UPSTREAM_MANUAL_VERIFICATION_ARTIFACT_PREFIX: &str = "artifact:small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe:";
const MIN_BLOCKER_COUNT: usize = 8;
const MAX_METADATA_BYTES: u64 = 768 * 1024;

pub fn small_model_fresh_product_runtime_l3_capability_closeout_or_advanced_cursor(
    cursor: &str,
) -> bool {
    matches!(
        cursor,
        SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_CAPABILITY_CLOSEOUT_PROBE_CURSOR
            | SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_CAPABILITY_CLOSEOUT_PROBE_NEXT_CURSOR
            | SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_RELEASE_AUDIT_CURSOR
    )
}

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-capability-closeout-probe:phase
// Plane: Verification + Controller
// Residency: capability closeout phase after manual fresh-runtime proof.
pub enum SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase {
    UpstreamManualVerificationBound,
    GuardCloseoutCursorBound,
    CapabilityKernelRedBound,
    ManualSegmentClosed,
    ResidualBlockersEnumerated,
    ReleaseAuditPreflightQueued,
    AnswerPacketRunEventLogBound,
    MasProHonestyBound,
    HeavyRoutesDeferred,
    NoNewBytesLoaded,
    BackwardCursorRegressionRejected,
    NextPreflightQueued,
}

impl SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase {
    pub fn tag(&self) -> &'static str {
        match self {
            Self::UpstreamManualVerificationBound => "upstream_manual_verification_bound",
            Self::GuardCloseoutCursorBound => "guard_closeout_cursor_bound",
            Self::CapabilityKernelRedBound => "capability_kernel_red_bound",
            Self::ManualSegmentClosed => "manual_segment_closed",
            Self::ResidualBlockersEnumerated => "residual_blockers_enumerated",
            Self::ReleaseAuditPreflightQueued => "release_audit_preflight_queued",
            Self::AnswerPacketRunEventLogBound => "answer_packet_run_event_log_bound",
            Self::MasProHonestyBound => "mas_pro_honesty_bound",
            Self::HeavyRoutesDeferred => "heavy_routes_deferred",
            Self::NoNewBytesLoaded => "no_new_bytes_loaded",
            Self::BackwardCursorRegressionRejected => "backward_cursor_regression_rejected",
            Self::NextPreflightQueued => "next_preflight_queued",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-capability-closeout-probe:error
// Plane: Verification
// Residency: capability closeout rejection taxonomy.
pub enum SmallModelFreshProductRuntimeL3CapabilityCloseoutError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    MissingManualVerificationArtifact(String),
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
    CloseoutRuntimeBytesLoaded,
    CloseoutModelBytesLoaded,
    ManualSegmentNotClosed,
    ReleaseAuditPreflightMissing,
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

impl fmt::Display for SmallModelFreshProductRuntimeL3CapabilityCloseoutError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::MissingManualVerificationArtifact(id) => {
                write!(f, "witness `{id}` missing manual verification artifact ref")
            }
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::EmptyBlocker => write!(f, "missing closeout blocker"),
            Self::DuplicateBlocker(id) => write!(f, "duplicate blocker `{id}`"),
            Self::MissingRequiredBlocker(id) => write!(f, "missing required blocker `{id}`"),
            Self::BlockerValidation(error) => write!(f, "blocker validation failed: {error}"),
            Self::EmptyPhase => write!(f, "missing closeout phase"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::UpstreamRuntimeBytesMissing => write!(f, "upstream runtime bytes missing"),
            Self::UpstreamModelBytesMissing => write!(f, "upstream model bytes missing"),
            Self::CloseoutRuntimeBytesLoaded => write!(f, "closeout loaded runtime bytes"),
            Self::CloseoutModelBytesLoaded => write!(f, "closeout loaded model bytes"),
            Self::ManualSegmentNotClosed => write!(f, "manual runtime segment not closed"),
            Self::ReleaseAuditPreflightMissing => write!(f, "release audit preflight missing"),
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

impl std::error::Error for SmallModelFreshProductRuntimeL3CapabilityCloseoutError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-capability-closeout-probe:metrics
// Plane: Verification
// Residency: closeout counts and byte accounting.
pub struct SmallModelFreshProductRuntimeL3CapabilityCloseoutMetrics {
    pub blocker_count: u64,
    pub phase_count: u64,
    pub upstream_runtime_bytes_loaded: u64,
    pub upstream_model_bytes_loaded: u64,
    pub closeout_runtime_bytes_loaded: u64,
    pub closeout_model_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-capability-closeout-probe:witness
// Plane: Verification + Controller
// Residency: final closeout for the fresh product-runtime proof segment.
pub struct SmallModelFreshProductRuntimeL3CapabilityCloseoutWitness {
    pub witness_id: String,
    pub upstream_manual_verification_artifact_ref: String,
    pub guard_next_existing_work: String,
    pub capability_overall_pass: bool,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub blockers: Vec<SmallModelProductRouteCapabilityBlocker>,
    pub phases: Vec<SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase>,
    pub upstream_runtime_bytes_loaded: u64,
    pub upstream_model_bytes_loaded: u64,
    pub closeout_runtime_bytes_loaded: u64,
    pub closeout_model_bytes_loaded: u64,
    pub manual_runtime_segment_closed: bool,
    pub release_audit_preflight_queued: bool,
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

impl SmallModelFreshProductRuntimeL3CapabilityCloseoutWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        upstream_manual_verification_artifact_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_overall_pass: bool,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        blockers: Vec<SmallModelProductRouteCapabilityBlocker>,
        phases: Vec<SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase>,
        upstream_runtime_bytes_loaded: u64,
        upstream_model_bytes_loaded: u64,
        closeout_runtime_bytes_loaded: u64,
        closeout_model_bytes_loaded: u64,
        manual_runtime_segment_closed: bool,
        release_audit_preflight_queued: bool,
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
    ) -> Result<Self, SmallModelFreshProductRuntimeL3CapabilityCloseoutError> {
        let witness = Self {
            witness_id: witness_id.into(),
            upstream_manual_verification_artifact_ref: upstream_manual_verification_artifact_ref
                .into(),
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
            closeout_runtime_bytes_loaded,
            closeout_model_bytes_loaded,
            manual_runtime_segment_closed,
            release_audit_preflight_queued,
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

    pub fn validate(&self) -> Result<(), SmallModelFreshProductRuntimeL3CapabilityCloseoutError> {
        validate_clean("witness_id", &self.witness_id)?;
        validate_prefixed(
            &self.witness_id,
            &self.upstream_manual_verification_artifact_ref,
            UPSTREAM_MANUAL_VERIFICATION_ARTIFACT_PREFIX,
        )?;
        if !small_model_fresh_product_runtime_l3_capability_closeout_or_advanced_cursor(
            &self.guard_next_existing_work,
        ) {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::GuardCursorMismatch,
            );
        }
        if self.capability_overall_pass
            || self.capability_route_status != "vault_research_route_with_packetized_mitigation"
            || !small_model_fresh_product_runtime_l3_capability_closeout_or_advanced_cursor(
                &self.capability_next_bottleneck,
            )
        {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::CapabilityStatusMismatch,
            );
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.route_authority
                != "fresh_product_runtime_l3_capability_closeout_no_route_authority"
        {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::ProductStatusMismatch,
            );
        }
        if self.blockers.len() < MIN_BLOCKER_COUNT {
            return Err(SmallModelFreshProductRuntimeL3CapabilityCloseoutError::EmptyBlocker);
        }
        let mut blocker_ids = HashSet::new();
        for blocker in &self.blockers {
            blocker.validate().map_err(|error| {
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::BlockerValidation(
                    error.to_string(),
                )
            })?;
            if !blocker_ids.insert(blocker.blocker_id.clone()) {
                return Err(
                    SmallModelFreshProductRuntimeL3CapabilityCloseoutError::DuplicateBlocker(
                        blocker.blocker_id.clone(),
                    ),
                );
            }
        }
        for required in required_fresh_product_runtime_l3_capability_closeout_blockers() {
            if !blocker_ids.contains(required) {
                return Err(
                    SmallModelFreshProductRuntimeL3CapabilityCloseoutError::MissingRequiredBlocker(
                        required,
                    ),
                );
            }
        }
        if self.phases.is_empty() {
            return Err(SmallModelFreshProductRuntimeL3CapabilityCloseoutError::EmptyPhase);
        }
        let observed_phases = self
            .phases
            .iter()
            .map(SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase::tag)
            .collect::<BTreeSet<_>>();
        for phase in required_fresh_product_runtime_l3_capability_closeout_phases() {
            if !observed_phases.contains(phase.tag()) {
                return Err(
                    SmallModelFreshProductRuntimeL3CapabilityCloseoutError::MissingPhase(
                        phase.tag(),
                    ),
                );
            }
        }
        if self.upstream_runtime_bytes_loaded == 0 {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::UpstreamRuntimeBytesMissing,
            );
        }
        if self.upstream_model_bytes_loaded == 0 {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::UpstreamModelBytesMissing,
            );
        }
        if self.closeout_runtime_bytes_loaded != 0 {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::CloseoutRuntimeBytesLoaded,
            );
        }
        if self.closeout_model_bytes_loaded != 0 {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::CloseoutModelBytesLoaded,
            );
        }
        if !self.manual_runtime_segment_closed {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::ManualSegmentNotClosed,
            );
        }
        if !self.release_audit_preflight_queued {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::ReleaseAuditPreflightMissing,
            );
        }
        if !self.answer_packet_run_event_log_bound {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::AnswerPacketRunEventLogMissing,
            );
        }
        if !self.l1_l2_l3_separated {
            return Err(SmallModelFreshProductRuntimeL3CapabilityCloseoutError::L1L2L3NotSeparated);
        }
        if self.hidden_authority_attempted {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::HiddenAuthorityAttempted,
            );
        }
        if self.route_mutation_attempted {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::RouteMutationAttempted,
            );
        }
        if self.mas_live_agent_overclaim_attempted {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::MasLiveAgentOverclaim,
            );
        }
        if self.l2_green_claimed {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::L2GreenClaimAttempted,
            );
        }
        if self.l3_green_claimed {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::L3GreenClaimAttempted,
            );
        }
        if self.autogenous_kernel_attempted {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::AutogenousKernelAttempted,
            );
        }
        if self.seventy_b_product_claimed {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::SeventyBProductClaimed,
            );
        }
        if self.long_context_shard_product_claimed {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::LongContextShardProductClaimed,
            );
        }
        if self.next_cursor
            != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_CAPABILITY_CLOSEOUT_PROBE_NEXT_CURSOR
        {
            return Err(SmallModelFreshProductRuntimeL3CapabilityCloseoutError::NextCursorMismatch);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(
                SmallModelFreshProductRuntimeL3CapabilityCloseoutError::MetadataBudgetExceeded,
            );
        }
        Ok(())
    }

    pub fn metrics(&self) -> SmallModelFreshProductRuntimeL3CapabilityCloseoutMetrics {
        SmallModelFreshProductRuntimeL3CapabilityCloseoutMetrics {
            blocker_count: self.blockers.len() as u64,
            phase_count: self
                .phases
                .iter()
                .map(SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase::tag)
                .collect::<BTreeSet<_>>()
                .len() as u64,
            upstream_runtime_bytes_loaded: self.upstream_runtime_bytes_loaded,
            upstream_model_bytes_loaded: self.upstream_model_bytes_loaded,
            closeout_runtime_bytes_loaded: self.closeout_runtime_bytes_loaded,
            closeout_model_bytes_loaded: self.closeout_model_bytes_loaded,
        }
    }

    pub fn address(&self) -> String {
        let mut parts = vec![
            self.witness_id.clone(),
            self.upstream_manual_verification_artifact_ref.clone(),
            self.guard_next_existing_work.clone(),
            self.capability_route_status.clone(),
            self.capability_next_bottleneck.clone(),
            self.route_authority.clone(),
            self.next_cursor.clone(),
            self.upstream_runtime_bytes_loaded.to_string(),
            self.upstream_model_bytes_loaded.to_string(),
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

pub fn required_fresh_product_runtime_l3_capability_closeout_phases(
) -> [SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase; 12] {
    [
        SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase::UpstreamManualVerificationBound,
        SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase::GuardCloseoutCursorBound,
        SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase::CapabilityKernelRedBound,
        SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase::ManualSegmentClosed,
        SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase::ResidualBlockersEnumerated,
        SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase::ReleaseAuditPreflightQueued,
        SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase::AnswerPacketRunEventLogBound,
        SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase::MasProHonestyBound,
        SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase::HeavyRoutesDeferred,
        SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase::NoNewBytesLoaded,
        SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase::BackwardCursorRegressionRejected,
        SmallModelFreshProductRuntimeL3CapabilityCloseoutPhase::NextPreflightQueued,
    ]
}

pub fn required_fresh_product_runtime_l3_capability_closeout_blockers() -> [&'static str; 8] {
    [
        "blocker:l2_capability_kernel_red",
        "blocker:l3_fresh_runtime_manual_review_l1_only",
        "blocker:release_audit_zero_fail_not_run",
        "blocker:mas_live_agent_not_promoted",
        "blocker:live_70b_route_not_promoted",
        "blocker:kv_direct_128k_not_promoted",
        "blocker:autogenous_kernel_not_promoted",
        "blocker:ship_call_not_authorized",
    ]
}

pub fn fresh_product_runtime_l3_capability_closeout_metadata_budget_bytes() -> u64 {
    MAX_METADATA_BYTES
}

fn validate_prefixed(
    witness_id: &str,
    value: &str,
    prefix: &str,
) -> Result<(), SmallModelFreshProductRuntimeL3CapabilityCloseoutError> {
    validate_clean("artifact_ref", value)?;
    if !value.starts_with(prefix) {
        return Err(
            SmallModelFreshProductRuntimeL3CapabilityCloseoutError::MissingManualVerificationArtifact(
                witness_id.to_string(),
            ),
        );
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelFreshProductRuntimeL3CapabilityCloseoutError> {
    if value.is_empty() {
        return Err(SmallModelFreshProductRuntimeL3CapabilityCloseoutError::MissingField(field));
    }
    if value.trim() != value {
        return Err(
            SmallModelFreshProductRuntimeL3CapabilityCloseoutError::FieldHasSurroundingWhitespace(
                field,
            ),
        );
    }
    if value.chars().any(char::is_control) {
        return Err(
            SmallModelFreshProductRuntimeL3CapabilityCloseoutError::FieldContainsControlCharacter(
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
            answer_packet_ref: "answer_packet:fresh_capability_closeout:red".to_string(),
            rollback_ref: "rollback:no_fresh_product_capability_promotion".to_string(),
            budget_ref: "budget:zero_closeout_runtime_bytes".to_string(),
            safety_ref: "safety:release_audit_preflight_required".to_string(),
            visible: true,
            currently_green: false,
            hidden_route_authority: false,
            route_policy_mutated: false,
        }
    }

    fn witness() -> SmallModelFreshProductRuntimeL3CapabilityCloseoutWitness {
        SmallModelFreshProductRuntimeL3CapabilityCloseoutWitness::new(
            "small-model-fresh-product-runtime-l3-capability-closeout:red-state",
            "artifact:small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_CAPABILITY_CLOSEOUT_PROBE_CURSOR,
            false,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_CAPABILITY_CLOSEOUT_PROBE_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "fresh_product_runtime_l3_capability_closeout_no_route_authority",
            required_fresh_product_runtime_l3_capability_closeout_blockers()
                .into_iter()
                .map(blocker)
                .collect(),
            required_fresh_product_runtime_l3_capability_closeout_phases().to_vec(),
            16_777_216,
            2_137_326_367,
            0,
            0,
            true,
            true,
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
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_CAPABILITY_CLOSEOUT_PROBE_NEXT_CURSOR,
            2048,
        )
        .expect("valid closeout witness")
    }

    #[test]
    fn fixture_validates_and_has_deterministic_address() {
        let valid_witness = witness();
        assert_eq!(
            valid_witness.metrics().phase_count,
            required_fresh_product_runtime_l3_capability_closeout_phases().len() as u64
        );
        assert_eq!(valid_witness.metrics().closeout_runtime_bytes_loaded, 0);
        assert_eq!(valid_witness.address(), witness().address());
    }

    #[test]
    fn release_audit_successor_cursor_is_accepted_as_advanced() {
        let mut advanced = witness();
        advanced.guard_next_existing_work =
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_RELEASE_AUDIT_CURSOR.to_string();
        advanced.capability_next_bottleneck =
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_RELEASE_AUDIT_CURSOR.to_string();

        assert!(
            small_model_fresh_product_runtime_l3_capability_closeout_or_advanced_cursor(
                &advanced.guard_next_existing_work
            )
        );
        assert!(advanced.validate().is_ok());
    }

    #[test]
    fn missing_release_audit_preflight_is_rejected() {
        let mut candidate = witness();
        candidate.release_audit_preflight_queued = false;
        let error = candidate
            .validate()
            .expect_err("release audit preflight is required");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3CapabilityCloseoutError::ReleaseAuditPreflightMissing
        ));
    }

    #[test]
    fn duplicate_blockers_are_rejected() {
        let mut candidate = witness();
        candidate.blockers[1] = candidate.blockers[0].clone();
        let error = candidate.validate().expect_err("duplicate blocker rejects");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3CapabilityCloseoutError::DuplicateBlocker(_)
        ));
    }

    #[test]
    fn upstream_runtime_bytes_are_required() {
        let mut candidate = witness();
        candidate.upstream_runtime_bytes_loaded = 0;
        let error = candidate
            .validate()
            .expect_err("upstream runtime bytes are required");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3CapabilityCloseoutError::UpstreamRuntimeBytesMissing
        ));
    }

    #[test]
    fn closeout_runtime_bytes_are_rejected() {
        let mut candidate = witness();
        candidate.closeout_runtime_bytes_loaded = 1;
        let error = candidate
            .validate()
            .expect_err("closeout byte load rejects");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3CapabilityCloseoutError::CloseoutRuntimeBytesLoaded
        ));
    }

    #[test]
    fn l2_green_claim_is_rejected() {
        let mut candidate = witness();
        candidate.l2_green_claimed = true;
        let error = candidate.validate().expect_err("L2 green claim rejects");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeL3CapabilityCloseoutError::L2GreenClaimAttempted
        ));
    }
}
