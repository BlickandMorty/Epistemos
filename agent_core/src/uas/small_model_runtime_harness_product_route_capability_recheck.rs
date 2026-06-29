//! Small-model product route capability recheck.
//!
//! This L1 witness turns the capability kernel's red product-route state into
//! explicit blocker cards. It is not a runtime run; it prevents retained
//! AnswerPacket evidence from being mistaken for a fresh product capability.

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild};

pub const SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_CURSOR: &str =
    "small_model_runtime_harness_product_route_capability_recheck";
pub const SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_safety_lease";
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";

const PRODUCT_HANDOFF_ARTIFACT_PREFIX: &str =
    "artifact:small_model_runtime_harness_product_answer_packet_live_probe:";
const BLOCKER_PREFIX: &str = "blocker:";
const EVIDENCE_PREFIX: &str = "evidence:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const ROLLBACK_PREFIX: &str = "rollback:";
const BUDGET_PREFIX: &str = "budget:";
const SAFETY_PREFIX: &str = "safety:";
const MIN_BLOCKER_COUNT: usize = 6;
const MAX_METADATA_BYTES: u64 = 512 * 1024;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-product-route-capability-recheck:phase
// Plane: Controller + Verification
// Residency: capability blocker state before any fresh product runtime lease.
pub enum SmallModelProductRouteCapabilityRecheckPhase {
    ProductAnswerPacketHandoffBound,
    CapabilityKernelRedBound,
    GuardCursorBound,
    L2BlockersEnumerated,
    L3FreshRuntimeMissing,
    MasProHonestyBound,
    HeavyRoutesDeferred,
    SafetyLeaseQueued,
    NoFreshBytesLoaded,
    AnswerPacketWitnessBound,
}

impl SmallModelProductRouteCapabilityRecheckPhase {
    pub fn tag(&self) -> &'static str {
        match self {
            Self::ProductAnswerPacketHandoffBound => "product_answer_packet_handoff_bound",
            Self::CapabilityKernelRedBound => "capability_kernel_red_bound",
            Self::GuardCursorBound => "guard_cursor_bound",
            Self::L2BlockersEnumerated => "l2_blockers_enumerated",
            Self::L3FreshRuntimeMissing => "l3_fresh_runtime_missing",
            Self::MasProHonestyBound => "mas_pro_honesty_bound",
            Self::HeavyRoutesDeferred => "heavy_routes_deferred",
            Self::SafetyLeaseQueued => "safety_lease_queued",
            Self::NoFreshBytesLoaded => "no_fresh_bytes_loaded",
            Self::AnswerPacketWitnessBound => "answer_packet_witness_bound",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-product-route-capability-recheck:error
// Plane: Verification
// Residency: capability recheck rejection taxonomy.
pub enum SmallModelProductRouteCapabilityRecheckError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    MissingProductAnswerPacketArtifact(String),
    GuardCursorMismatch,
    CapabilityStatusMismatch,
    ProductStatusMismatch,
    EmptyBlocker,
    DuplicateBlocker(String),
    MissingRequiredBlocker(&'static str),
    EmptyPhase,
    MissingPhase(&'static str),
    MissingEvidence(String),
    MissingAnswerPacket(String),
    MissingRollback(String),
    MissingBudget(String),
    MissingSafetyRef(String),
    BlockerNotVisible(String),
    BlockerMarkedGreen(String),
    HiddenRouteAuthority(String),
    RoutePolicyMutation(String),
    FreshRuntimeBytesLoaded,
    FreshModelBytesLoaded,
    RetainedRuntimeBytesMissing,
    L1L2L3NotSeparated,
    MasLiveAgentOverclaim,
    L2GreenClaimAttempted,
    L3GreenClaimAttempted,
    NextCursorMismatch,
    MetadataBudgetExceeded,
}

impl fmt::Display for SmallModelProductRouteCapabilityRecheckError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::MissingProductAnswerPacketArtifact(id) => {
                write!(f, "witness `{id}` missing product handoff artifact ref")
            }
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::EmptyBlocker => write!(f, "missing capability blocker"),
            Self::DuplicateBlocker(id) => write!(f, "duplicate blocker `{id}`"),
            Self::MissingRequiredBlocker(id) => write!(f, "missing required blocker `{id}`"),
            Self::EmptyPhase => write!(f, "missing capability recheck phase"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::MissingEvidence(id) => write!(f, "blocker `{id}` missing evidence ref"),
            Self::MissingAnswerPacket(id) => write!(f, "blocker `{id}` missing AnswerPacket ref"),
            Self::MissingRollback(id) => write!(f, "blocker `{id}` missing rollback ref"),
            Self::MissingBudget(id) => write!(f, "blocker `{id}` missing budget ref"),
            Self::MissingSafetyRef(id) => write!(f, "blocker `{id}` missing safety ref"),
            Self::BlockerNotVisible(id) => write!(f, "blocker `{id}` is not visible"),
            Self::BlockerMarkedGreen(id) => write!(f, "blocker `{id}` is marked green"),
            Self::HiddenRouteAuthority(id) => write!(f, "blocker `{id}` has hidden authority"),
            Self::RoutePolicyMutation(id) => write!(f, "blocker `{id}` mutates route policy"),
            Self::FreshRuntimeBytesLoaded => write!(f, "fresh product runtime bytes loaded"),
            Self::FreshModelBytesLoaded => write!(f, "fresh product model bytes loaded"),
            Self::RetainedRuntimeBytesMissing => write!(f, "retained runtime evidence missing"),
            Self::L1L2L3NotSeparated => write!(f, "L1/L2/L3 separation missing"),
            Self::MasLiveAgentOverclaim => write!(f, "MAS live-agent overclaim attempted"),
            Self::L2GreenClaimAttempted => write!(f, "L2 green claim attempted"),
            Self::L3GreenClaimAttempted => write!(f, "L3 green claim attempted"),
            Self::NextCursorMismatch => write!(f, "next cursor mismatch"),
            Self::MetadataBudgetExceeded => write!(f, "metadata budget exceeded"),
        }
    }
}

impl std::error::Error for SmallModelProductRouteCapabilityRecheckError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-product-route-capability-recheck:blocker
// Plane: Verification
// Residency: explicit L2/L3 blocker card.
pub struct SmallModelProductRouteCapabilityBlocker {
    pub blocker_id: String,
    pub plane: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub evidence_ref: String,
    pub answer_packet_ref: String,
    pub rollback_ref: String,
    pub budget_ref: String,
    pub safety_ref: String,
    pub visible: bool,
    pub currently_green: bool,
    pub hidden_route_authority: bool,
    pub route_policy_mutated: bool,
}

impl SmallModelProductRouteCapabilityBlocker {
    pub fn validate(&self) -> Result<(), SmallModelProductRouteCapabilityRecheckError> {
        validate_prefixed_clean("blocker_id", &self.blocker_id, BLOCKER_PREFIX)?;
        validate_clean("plane", &self.plane)?;
        validate_prefixed_clean("evidence_ref", &self.evidence_ref, EVIDENCE_PREFIX).map_err(
            |_| {
                SmallModelProductRouteCapabilityRecheckError::MissingEvidence(
                    self.blocker_id.clone(),
                )
            },
        )?;
        validate_prefixed_clean(
            "answer_packet_ref",
            &self.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
        )
        .map_err(|_| {
            SmallModelProductRouteCapabilityRecheckError::MissingAnswerPacket(
                self.blocker_id.clone(),
            )
        })?;
        validate_prefixed_clean("rollback_ref", &self.rollback_ref, ROLLBACK_PREFIX).map_err(
            |_| {
                SmallModelProductRouteCapabilityRecheckError::MissingRollback(
                    self.blocker_id.clone(),
                )
            },
        )?;
        validate_prefixed_clean("budget_ref", &self.budget_ref, BUDGET_PREFIX).map_err(|_| {
            SmallModelProductRouteCapabilityRecheckError::MissingBudget(self.blocker_id.clone())
        })?;
        validate_prefixed_clean("safety_ref", &self.safety_ref, SAFETY_PREFIX).map_err(|_| {
            SmallModelProductRouteCapabilityRecheckError::MissingSafetyRef(self.blocker_id.clone())
        })?;
        if self.product_build != ProductBuild::Pro || self.pro_status != ProStatus::Gated {
            return Err(SmallModelProductRouteCapabilityRecheckError::ProductStatusMismatch);
        }
        if !self.visible {
            return Err(
                SmallModelProductRouteCapabilityRecheckError::BlockerNotVisible(
                    self.blocker_id.clone(),
                ),
            );
        }
        if self.currently_green {
            return Err(
                SmallModelProductRouteCapabilityRecheckError::BlockerMarkedGreen(
                    self.blocker_id.clone(),
                ),
            );
        }
        if self.hidden_route_authority {
            return Err(
                SmallModelProductRouteCapabilityRecheckError::HiddenRouteAuthority(
                    self.blocker_id.clone(),
                ),
            );
        }
        if self.route_policy_mutated {
            return Err(
                SmallModelProductRouteCapabilityRecheckError::RoutePolicyMutation(
                    self.blocker_id.clone(),
                ),
            );
        }
        Ok(())
    }
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-product-route-capability-recheck:metrics
// Plane: Verification
// Residency: capability blocker counts and byte accounting.
pub struct SmallModelProductRouteCapabilityRecheckMetrics {
    pub blocker_count: u64,
    pub phase_count: u64,
    pub retained_runtime_bytes_loaded: u64,
    pub fresh_product_runtime_bytes_loaded: u64,
    pub fresh_product_model_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-product-route-capability-recheck:witness
// Plane: Controller + Verification
// Residency: red product route capability state bound to next safety lease.
pub struct SmallModelProductRouteCapabilityRecheckWitness {
    pub witness_id: String,
    pub product_answer_packet_artifact_ref: String,
    pub guard_next_existing_work: String,
    pub capability_overall_pass: bool,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub blockers: Vec<SmallModelProductRouteCapabilityBlocker>,
    pub phases: Vec<SmallModelProductRouteCapabilityRecheckPhase>,
    pub retained_runtime_bytes_loaded: u64,
    pub fresh_product_runtime_bytes_loaded: u64,
    pub fresh_product_model_bytes_loaded: u64,
    pub l1_l2_l3_separated: bool,
    pub mas_live_agent_overclaim_attempted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub next_cursor: String,
    pub metadata_bytes: u64,
}

impl SmallModelProductRouteCapabilityRecheckWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        product_answer_packet_artifact_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_overall_pass: bool,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        blockers: Vec<SmallModelProductRouteCapabilityBlocker>,
        phases: Vec<SmallModelProductRouteCapabilityRecheckPhase>,
        retained_runtime_bytes_loaded: u64,
        fresh_product_runtime_bytes_loaded: u64,
        fresh_product_model_bytes_loaded: u64,
        l1_l2_l3_separated: bool,
        mas_live_agent_overclaim_attempted: bool,
        l2_green_claimed: bool,
        l3_green_claimed: bool,
        next_cursor: impl Into<String>,
        metadata_bytes: u64,
    ) -> Result<Self, SmallModelProductRouteCapabilityRecheckError> {
        let witness = Self {
            witness_id: witness_id.into(),
            product_answer_packet_artifact_ref: product_answer_packet_artifact_ref.into(),
            guard_next_existing_work: guard_next_existing_work.into(),
            capability_overall_pass,
            capability_route_status: capability_route_status.into(),
            capability_next_bottleneck: capability_next_bottleneck.into(),
            product_build,
            pro_status,
            route_authority: route_authority.into(),
            blockers,
            phases,
            retained_runtime_bytes_loaded,
            fresh_product_runtime_bytes_loaded,
            fresh_product_model_bytes_loaded,
            l1_l2_l3_separated,
            mas_live_agent_overclaim_attempted,
            l2_green_claimed,
            l3_green_claimed,
            next_cursor: next_cursor.into(),
            metadata_bytes,
        };
        witness.validate()?;
        Ok(witness)
    }

    pub fn validate(&self) -> Result<(), SmallModelProductRouteCapabilityRecheckError> {
        validate_clean("witness_id", &self.witness_id)?;
        validate_prefixed(
            &self.witness_id,
            &self.product_answer_packet_artifact_ref,
            PRODUCT_HANDOFF_ARTIFACT_PREFIX,
            SmallModelProductRouteCapabilityRecheckError::MissingProductAnswerPacketArtifact,
        )?;
        if self.guard_next_existing_work
            != SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_CURSOR
            && self.guard_next_existing_work
                != SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_NEXT_CURSOR
            && self.guard_next_existing_work != ADVANCED_RELEASE_AUDIT_CURSOR
        {
            return Err(SmallModelProductRouteCapabilityRecheckError::GuardCursorMismatch);
        }
        if self.capability_overall_pass
            || self.capability_route_status != "vault_research_route_with_packetized_mitigation"
            || (self.capability_next_bottleneck
                != SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_CURSOR
                && self.capability_next_bottleneck
                    != SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_NEXT_CURSOR
                && self.capability_next_bottleneck != ADVANCED_RELEASE_AUDIT_CURSOR)
        {
            return Err(SmallModelProductRouteCapabilityRecheckError::CapabilityStatusMismatch);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.route_authority != "capability_recheck_no_route_authority"
        {
            return Err(SmallModelProductRouteCapabilityRecheckError::ProductStatusMismatch);
        }
        if self.blockers.len() < MIN_BLOCKER_COUNT {
            return Err(SmallModelProductRouteCapabilityRecheckError::EmptyBlocker);
        }
        let mut blocker_ids = HashSet::new();
        for blocker in &self.blockers {
            blocker.validate()?;
            if !blocker_ids.insert(blocker.blocker_id.clone()) {
                return Err(
                    SmallModelProductRouteCapabilityRecheckError::DuplicateBlocker(
                        blocker.blocker_id.clone(),
                    ),
                );
            }
        }
        for required in required_product_route_capability_blockers() {
            if !blocker_ids.contains(required) {
                return Err(
                    SmallModelProductRouteCapabilityRecheckError::MissingRequiredBlocker(required),
                );
            }
        }
        if self.phases.is_empty() {
            return Err(SmallModelProductRouteCapabilityRecheckError::EmptyPhase);
        }
        let observed_phases = self
            .phases
            .iter()
            .map(SmallModelProductRouteCapabilityRecheckPhase::tag)
            .collect::<BTreeSet<_>>();
        for phase in required_product_route_capability_recheck_phases() {
            if !observed_phases.contains(phase.tag()) {
                return Err(SmallModelProductRouteCapabilityRecheckError::MissingPhase(
                    phase.tag(),
                ));
            }
        }
        if self.retained_runtime_bytes_loaded == 0 {
            return Err(SmallModelProductRouteCapabilityRecheckError::RetainedRuntimeBytesMissing);
        }
        if self.fresh_product_runtime_bytes_loaded != 0 {
            return Err(SmallModelProductRouteCapabilityRecheckError::FreshRuntimeBytesLoaded);
        }
        if self.fresh_product_model_bytes_loaded != 0 {
            return Err(SmallModelProductRouteCapabilityRecheckError::FreshModelBytesLoaded);
        }
        if !self.l1_l2_l3_separated {
            return Err(SmallModelProductRouteCapabilityRecheckError::L1L2L3NotSeparated);
        }
        if self.mas_live_agent_overclaim_attempted {
            return Err(SmallModelProductRouteCapabilityRecheckError::MasLiveAgentOverclaim);
        }
        if self.l2_green_claimed {
            return Err(SmallModelProductRouteCapabilityRecheckError::L2GreenClaimAttempted);
        }
        if self.l3_green_claimed {
            return Err(SmallModelProductRouteCapabilityRecheckError::L3GreenClaimAttempted);
        }
        if self.next_cursor
            != SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_NEXT_CURSOR
        {
            return Err(SmallModelProductRouteCapabilityRecheckError::NextCursorMismatch);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(SmallModelProductRouteCapabilityRecheckError::MetadataBudgetExceeded);
        }
        Ok(())
    }

    pub fn metrics(&self) -> SmallModelProductRouteCapabilityRecheckMetrics {
        SmallModelProductRouteCapabilityRecheckMetrics {
            blocker_count: self.blockers.len() as u64,
            phase_count: self
                .phases
                .iter()
                .map(SmallModelProductRouteCapabilityRecheckPhase::tag)
                .collect::<BTreeSet<_>>()
                .len() as u64,
            retained_runtime_bytes_loaded: self.retained_runtime_bytes_loaded,
            fresh_product_runtime_bytes_loaded: self.fresh_product_runtime_bytes_loaded,
            fresh_product_model_bytes_loaded: self.fresh_product_model_bytes_loaded,
        }
    }

    pub fn address(&self) -> String {
        let mut parts = vec![
            self.witness_id.clone(),
            self.product_answer_packet_artifact_ref.clone(),
            self.guard_next_existing_work.clone(),
            self.capability_route_status.clone(),
            self.capability_next_bottleneck.clone(),
            self.route_authority.clone(),
            self.next_cursor.clone(),
            self.retained_runtime_bytes_loaded.to_string(),
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

pub fn required_product_route_capability_recheck_phases(
) -> [SmallModelProductRouteCapabilityRecheckPhase; 10] {
    [
        SmallModelProductRouteCapabilityRecheckPhase::ProductAnswerPacketHandoffBound,
        SmallModelProductRouteCapabilityRecheckPhase::CapabilityKernelRedBound,
        SmallModelProductRouteCapabilityRecheckPhase::GuardCursorBound,
        SmallModelProductRouteCapabilityRecheckPhase::L2BlockersEnumerated,
        SmallModelProductRouteCapabilityRecheckPhase::L3FreshRuntimeMissing,
        SmallModelProductRouteCapabilityRecheckPhase::MasProHonestyBound,
        SmallModelProductRouteCapabilityRecheckPhase::HeavyRoutesDeferred,
        SmallModelProductRouteCapabilityRecheckPhase::SafetyLeaseQueued,
        SmallModelProductRouteCapabilityRecheckPhase::NoFreshBytesLoaded,
        SmallModelProductRouteCapabilityRecheckPhase::AnswerPacketWitnessBound,
    ]
}

pub fn required_product_route_capability_blockers() -> [&'static str; 6] {
    [
        "blocker:l2_capability_kernel_red",
        "blocker:fresh_product_runtime_route_missing",
        "blocker:l3_fresh_app_runtime_unverified",
        "blocker:mas_live_agent_not_promoted",
        "blocker:live_70b_route_not_promoted",
        "blocker:kv_direct_128k_not_promoted",
    ]
}

pub fn product_route_capability_recheck_metadata_budget_bytes() -> u64 {
    MAX_METADATA_BYTES
}

fn validate_prefixed_clean(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), SmallModelProductRouteCapabilityRecheckError> {
    validate_clean(field, value)?;
    if !value.starts_with(prefix) {
        return Err(SmallModelProductRouteCapabilityRecheckError::MissingField(
            field,
        ));
    }
    Ok(())
}

fn validate_prefixed(
    witness_id: &str,
    value: &str,
    prefix: &str,
    error: fn(String) -> SmallModelProductRouteCapabilityRecheckError,
) -> Result<(), SmallModelProductRouteCapabilityRecheckError> {
    validate_clean("artifact_ref", value)?;
    if !value.starts_with(prefix) {
        return Err(error(witness_id.to_string()));
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelProductRouteCapabilityRecheckError> {
    if value.is_empty() {
        return Err(SmallModelProductRouteCapabilityRecheckError::MissingField(
            field,
        ));
    }
    if value.trim() != value {
        return Err(
            SmallModelProductRouteCapabilityRecheckError::FieldHasSurroundingWhitespace(field),
        );
    }
    if value.chars().any(char::is_control) {
        return Err(
            SmallModelProductRouteCapabilityRecheckError::FieldContainsControlCharacter(field),
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
            answer_packet_ref: "answer_packet:capability_recheck:red".to_string(),
            rollback_ref: "rollback:no_product_route_promotion".to_string(),
            budget_ref: "budget:zero_fresh_product_bytes".to_string(),
            safety_ref: "safety:fresh_product_runtime_lease_required".to_string(),
            visible: true,
            currently_green: false,
            hidden_route_authority: false,
            route_policy_mutated: false,
        }
    }

    fn witness() -> SmallModelProductRouteCapabilityRecheckWitness {
        SmallModelProductRouteCapabilityRecheckWitness::new(
            "small-model-product-route-capability-recheck:red-state",
            "artifact:small_model_runtime_harness_product_answer_packet_live_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_CURSOR,
            false,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "capability_recheck_no_route_authority",
            required_product_route_capability_blockers()
                .into_iter()
                .map(blocker)
                .collect(),
            required_product_route_capability_recheck_phases().to_vec(),
            2_153_272_351,
            0,
            0,
            true,
            false,
            false,
            false,
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_NEXT_CURSOR,
            1024,
        )
        .expect("fixture is valid")
    }

    #[test]
    fn fixture_validates_and_has_deterministic_address() {
        let valid_witness = witness();
        assert_eq!(
            valid_witness.metrics().phase_count,
            required_product_route_capability_recheck_phases().len() as u64
        );
        assert_eq!(valid_witness.address(), witness().address());
    }

    #[test]
    fn missing_required_blocker_is_rejected() {
        let mut blockers = required_product_route_capability_blockers()
            .into_iter()
            .map(blocker)
            .collect::<Vec<_>>();
        blockers.pop();
        let error = SmallModelProductRouteCapabilityRecheckWitness::new(
            "small-model-product-route-capability-recheck:red-state",
            "artifact:small_model_runtime_harness_product_answer_packet_live_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_CURSOR,
            false,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "capability_recheck_no_route_authority",
            blockers,
            required_product_route_capability_recheck_phases().to_vec(),
            2_153_272_351,
            0,
            0,
            true,
            false,
            false,
            false,
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_NEXT_CURSOR,
            1024,
        )
        .expect_err("required blockers cannot be omitted");
        assert!(matches!(
            error,
            SmallModelProductRouteCapabilityRecheckError::EmptyBlocker
                | SmallModelProductRouteCapabilityRecheckError::MissingRequiredBlocker(_)
        ));
    }

    #[test]
    fn l2_green_claim_is_rejected() {
        let error = SmallModelProductRouteCapabilityRecheckWitness::new(
            "small-model-product-route-capability-recheck:red-state",
            "artifact:small_model_runtime_harness_product_answer_packet_live_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_CURSOR,
            true,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "capability_recheck_no_route_authority",
            required_product_route_capability_blockers()
                .into_iter()
                .map(blocker)
                .collect(),
            required_product_route_capability_recheck_phases().to_vec(),
            2_153_272_351,
            0,
            0,
            true,
            false,
            true,
            false,
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_NEXT_CURSOR,
            1024,
        )
        .expect_err("green L2 status cannot pass recheck");
        assert!(matches!(
            error,
            SmallModelProductRouteCapabilityRecheckError::CapabilityStatusMismatch
        ));
    }

    #[test]
    fn fresh_runtime_bytes_are_rejected() {
        let error = SmallModelProductRouteCapabilityRecheckWitness::new(
            "small-model-product-route-capability-recheck:red-state",
            "artifact:small_model_runtime_harness_product_answer_packet_live_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_CURSOR,
            false,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "capability_recheck_no_route_authority",
            required_product_route_capability_blockers()
                .into_iter()
                .map(blocker)
                .collect(),
            required_product_route_capability_recheck_phases().to_vec(),
            2_153_272_351,
            1,
            0,
            true,
            false,
            false,
            false,
            SMALL_MODEL_RUNTIME_HARNESS_PRODUCT_ROUTE_CAPABILITY_RECHECK_NEXT_CURSOR,
            1024,
        )
        .expect_err("fresh runtime bytes cannot load in recheck");
        assert!(matches!(
            error,
            SmallModelProductRouteCapabilityRecheckError::FreshRuntimeBytesLoaded
        ));
    }
}
