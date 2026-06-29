//! Fresh product-runtime capability recheck for the small-model harness.
//!
//! This witness consumes fresh product-runtime WRV proof and records the
//! remaining L2/L3 blockers without promoting the product route. It is the
//! boundary between "fresh runtime evidence exists and is source-visible" and
//! "the app is capability green."

use std::collections::{BTreeSet, HashSet};
use std::fmt;

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{ProStatus, ProductBuild, SmallModelProductRouteCapabilityBlocker};

pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_capability_recheck";
pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_log_correlation_probe";
const ADVANCED_RELEASE_AUDIT_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";

const FRESH_WRV_ARTIFACT_PREFIX: &str =
    "artifact:small_model_runtime_harness_fresh_product_runtime_wrv_probe:";
const MIN_BLOCKER_COUNT: usize = 7;
const MAX_METADATA_BYTES: u64 = 512 * 1024;

#[derive(Clone, Debug, Hash, PartialEq, Eq, PartialOrd, Ord)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-capability-recheck:phase
// Plane: Controller + Verification
// Residency: fresh runtime capability blocker state after source WRV.
pub enum SmallModelFreshProductRuntimeCapabilityRecheckPhase {
    FreshWrvArtifactBound,
    CapabilityKernelRedBound,
    GuardCursorBound,
    FreshRuntimeEvidenceBound,
    FreshAnswerPacketBound,
    L2BlockersEnumerated,
    L3LogCorrelationMissing,
    MasProHonestyBound,
    HeavyRoutesDeferred,
    NoNewBytesLoaded,
    AnswerPacketWitnessBound,
    L3LogProbeQueued,
}

impl SmallModelFreshProductRuntimeCapabilityRecheckPhase {
    pub fn tag(&self) -> &'static str {
        match self {
            Self::FreshWrvArtifactBound => "fresh_wrv_artifact_bound",
            Self::CapabilityKernelRedBound => "capability_kernel_red_bound",
            Self::GuardCursorBound => "guard_cursor_bound",
            Self::FreshRuntimeEvidenceBound => "fresh_runtime_evidence_bound",
            Self::FreshAnswerPacketBound => "fresh_answer_packet_bound",
            Self::L2BlockersEnumerated => "l2_blockers_enumerated",
            Self::L3LogCorrelationMissing => "l3_log_correlation_missing",
            Self::MasProHonestyBound => "mas_pro_honesty_bound",
            Self::HeavyRoutesDeferred => "heavy_routes_deferred",
            Self::NoNewBytesLoaded => "no_new_bytes_loaded",
            Self::AnswerPacketWitnessBound => "answer_packet_witness_bound",
            Self::L3LogProbeQueued => "l3_log_probe_queued",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-capability-recheck:error
// Plane: Verification
// Residency: capability recheck rejection taxonomy after fresh WRV.
pub enum SmallModelFreshProductRuntimeCapabilityRecheckError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    MissingFreshWrvArtifact(String),
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
    RecheckRuntimeBytesLoaded,
    RecheckModelBytesLoaded,
    L1L2L3NotSeparated,
    MasLiveAgentOverclaim,
    L2GreenClaimAttempted,
    L3GreenClaimAttempted,
    AutogenousKernelAttempted,
    SeventyBProductClaimed,
    LongContextShardProductClaimed,
    NextCursorMismatch,
    MetadataBudgetExceeded,
}

impl fmt::Display for SmallModelFreshProductRuntimeCapabilityRecheckError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::MissingFreshWrvArtifact(id) => {
                write!(f, "witness `{id}` missing fresh WRV artifact ref")
            }
            Self::GuardCursorMismatch => write!(f, "guard cursor mismatch"),
            Self::CapabilityStatusMismatch => write!(f, "capability status mismatch"),
            Self::ProductStatusMismatch => write!(f, "product status mismatch"),
            Self::EmptyBlocker => write!(f, "missing capability blocker"),
            Self::DuplicateBlocker(id) => write!(f, "duplicate blocker `{id}`"),
            Self::MissingRequiredBlocker(id) => write!(f, "missing required blocker `{id}`"),
            Self::BlockerValidation(error) => write!(f, "blocker validation failed: {error}"),
            Self::EmptyPhase => write!(f, "missing fresh capability recheck phase"),
            Self::MissingPhase(phase) => write!(f, "missing phase `{phase}`"),
            Self::UpstreamRuntimeBytesMissing => write!(f, "upstream runtime bytes missing"),
            Self::UpstreamModelBytesMissing => write!(f, "upstream model bytes missing"),
            Self::RecheckRuntimeBytesLoaded => write!(f, "recheck loaded runtime bytes"),
            Self::RecheckModelBytesLoaded => write!(f, "recheck loaded model bytes"),
            Self::L1L2L3NotSeparated => write!(f, "L1/L2/L3 separation missing"),
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

impl std::error::Error for SmallModelFreshProductRuntimeCapabilityRecheckError {}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-capability-recheck:metrics
// Plane: Verification
// Residency: fresh capability blocker counts and byte accounting.
pub struct SmallModelFreshProductRuntimeCapabilityRecheckMetrics {
    pub blocker_count: u64,
    pub phase_count: u64,
    pub upstream_runtime_bytes_loaded: u64,
    pub upstream_model_bytes_loaded: u64,
    pub recheck_runtime_bytes_loaded: u64,
    pub recheck_model_bytes_loaded: u64,
}

#[derive(Clone, Debug)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-capability-recheck:witness
// Plane: Controller + Verification
// Residency: red product capability state after fresh source-visible runtime proof.
pub struct SmallModelFreshProductRuntimeCapabilityRecheckWitness {
    pub witness_id: String,
    pub fresh_wrv_artifact_ref: String,
    pub guard_next_existing_work: String,
    pub capability_overall_pass: bool,
    pub capability_route_status: String,
    pub capability_next_bottleneck: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub route_authority: String,
    pub blockers: Vec<SmallModelProductRouteCapabilityBlocker>,
    pub phases: Vec<SmallModelFreshProductRuntimeCapabilityRecheckPhase>,
    pub upstream_runtime_bytes_loaded: u64,
    pub upstream_model_bytes_loaded: u64,
    pub recheck_runtime_bytes_loaded: u64,
    pub recheck_model_bytes_loaded: u64,
    pub l1_l2_l3_separated: bool,
    pub mas_live_agent_overclaim_attempted: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub autogenous_kernel_attempted: bool,
    pub seventy_b_product_claimed: bool,
    pub long_context_shard_product_claimed: bool,
    pub next_cursor: String,
    pub metadata_bytes: u64,
}

impl SmallModelFreshProductRuntimeCapabilityRecheckWitness {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        witness_id: impl Into<String>,
        fresh_wrv_artifact_ref: impl Into<String>,
        guard_next_existing_work: impl Into<String>,
        capability_overall_pass: bool,
        capability_route_status: impl Into<String>,
        capability_next_bottleneck: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        route_authority: impl Into<String>,
        blockers: Vec<SmallModelProductRouteCapabilityBlocker>,
        phases: Vec<SmallModelFreshProductRuntimeCapabilityRecheckPhase>,
        upstream_runtime_bytes_loaded: u64,
        upstream_model_bytes_loaded: u64,
        recheck_runtime_bytes_loaded: u64,
        recheck_model_bytes_loaded: u64,
        l1_l2_l3_separated: bool,
        mas_live_agent_overclaim_attempted: bool,
        l2_green_claimed: bool,
        l3_green_claimed: bool,
        autogenous_kernel_attempted: bool,
        seventy_b_product_claimed: bool,
        long_context_shard_product_claimed: bool,
        next_cursor: impl Into<String>,
        metadata_bytes: u64,
    ) -> Result<Self, SmallModelFreshProductRuntimeCapabilityRecheckError> {
        let witness = Self {
            witness_id: witness_id.into(),
            fresh_wrv_artifact_ref: fresh_wrv_artifact_ref.into(),
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
            recheck_runtime_bytes_loaded,
            recheck_model_bytes_loaded,
            l1_l2_l3_separated,
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

    pub fn validate(&self) -> Result<(), SmallModelFreshProductRuntimeCapabilityRecheckError> {
        validate_clean("witness_id", &self.witness_id)?;
        validate_prefixed(
            &self.witness_id,
            &self.fresh_wrv_artifact_ref,
            FRESH_WRV_ARTIFACT_PREFIX,
        )?;
        if self.guard_next_existing_work
            != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR
            && self.guard_next_existing_work
                != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR
            && self.guard_next_existing_work != ADVANCED_RELEASE_AUDIT_CURSOR
        {
            return Err(SmallModelFreshProductRuntimeCapabilityRecheckError::GuardCursorMismatch);
        }
        if self.capability_overall_pass
            || self.capability_route_status != "vault_research_route_with_packetized_mitigation"
            || (self.capability_next_bottleneck
                != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR
                && self.capability_next_bottleneck
                    != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR
        && self.capability_next_bottleneck != ADVANCED_RELEASE_AUDIT_CURSOR)
        {
            return Err(
                SmallModelFreshProductRuntimeCapabilityRecheckError::CapabilityStatusMismatch,
            );
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.route_authority != "fresh_product_runtime_capability_recheck_no_route_authority"
        {
            return Err(SmallModelFreshProductRuntimeCapabilityRecheckError::ProductStatusMismatch);
        }
        if self.blockers.len() < MIN_BLOCKER_COUNT {
            return Err(SmallModelFreshProductRuntimeCapabilityRecheckError::EmptyBlocker);
        }
        let mut blocker_ids = HashSet::new();
        for blocker in &self.blockers {
            blocker.validate().map_err(|error| {
                SmallModelFreshProductRuntimeCapabilityRecheckError::BlockerValidation(
                    error.to_string(),
                )
            })?;
            if !blocker_ids.insert(blocker.blocker_id.clone()) {
                return Err(
                    SmallModelFreshProductRuntimeCapabilityRecheckError::DuplicateBlocker(
                        blocker.blocker_id.clone(),
                    ),
                );
            }
        }
        for required in required_fresh_product_runtime_capability_blockers() {
            if !blocker_ids.contains(required) {
                return Err(
                    SmallModelFreshProductRuntimeCapabilityRecheckError::MissingRequiredBlocker(
                        required,
                    ),
                );
            }
        }
        if self.phases.is_empty() {
            return Err(SmallModelFreshProductRuntimeCapabilityRecheckError::EmptyPhase);
        }
        let observed_phases = self
            .phases
            .iter()
            .map(SmallModelFreshProductRuntimeCapabilityRecheckPhase::tag)
            .collect::<BTreeSet<_>>();
        for phase in required_fresh_product_runtime_capability_recheck_phases() {
            if !observed_phases.contains(phase.tag()) {
                return Err(
                    SmallModelFreshProductRuntimeCapabilityRecheckError::MissingPhase(phase.tag()),
                );
            }
        }
        if self.upstream_runtime_bytes_loaded == 0 {
            return Err(
                SmallModelFreshProductRuntimeCapabilityRecheckError::UpstreamRuntimeBytesMissing,
            );
        }
        if self.upstream_model_bytes_loaded == 0 {
            return Err(
                SmallModelFreshProductRuntimeCapabilityRecheckError::UpstreamModelBytesMissing,
            );
        }
        if self.recheck_runtime_bytes_loaded != 0 {
            return Err(
                SmallModelFreshProductRuntimeCapabilityRecheckError::RecheckRuntimeBytesLoaded,
            );
        }
        if self.recheck_model_bytes_loaded != 0 {
            return Err(
                SmallModelFreshProductRuntimeCapabilityRecheckError::RecheckModelBytesLoaded,
            );
        }
        if !self.l1_l2_l3_separated {
            return Err(SmallModelFreshProductRuntimeCapabilityRecheckError::L1L2L3NotSeparated);
        }
        if self.mas_live_agent_overclaim_attempted {
            return Err(SmallModelFreshProductRuntimeCapabilityRecheckError::MasLiveAgentOverclaim);
        }
        if self.l2_green_claimed {
            return Err(SmallModelFreshProductRuntimeCapabilityRecheckError::L2GreenClaimAttempted);
        }
        if self.l3_green_claimed {
            return Err(SmallModelFreshProductRuntimeCapabilityRecheckError::L3GreenClaimAttempted);
        }
        if self.autogenous_kernel_attempted {
            return Err(
                SmallModelFreshProductRuntimeCapabilityRecheckError::AutogenousKernelAttempted,
            );
        }
        if self.seventy_b_product_claimed {
            return Err(
                SmallModelFreshProductRuntimeCapabilityRecheckError::SeventyBProductClaimed,
            );
        }
        if self.long_context_shard_product_claimed {
            return Err(
                SmallModelFreshProductRuntimeCapabilityRecheckError::LongContextShardProductClaimed,
            );
        }
        if self.next_cursor
            != SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR
        {
            return Err(SmallModelFreshProductRuntimeCapabilityRecheckError::NextCursorMismatch);
        }
        if self.metadata_bytes > MAX_METADATA_BYTES {
            return Err(
                SmallModelFreshProductRuntimeCapabilityRecheckError::MetadataBudgetExceeded,
            );
        }
        Ok(())
    }

    pub fn metrics(&self) -> SmallModelFreshProductRuntimeCapabilityRecheckMetrics {
        SmallModelFreshProductRuntimeCapabilityRecheckMetrics {
            blocker_count: self.blockers.len() as u64,
            phase_count: self
                .phases
                .iter()
                .map(SmallModelFreshProductRuntimeCapabilityRecheckPhase::tag)
                .collect::<BTreeSet<_>>()
                .len() as u64,
            upstream_runtime_bytes_loaded: self.upstream_runtime_bytes_loaded,
            upstream_model_bytes_loaded: self.upstream_model_bytes_loaded,
            recheck_runtime_bytes_loaded: self.recheck_runtime_bytes_loaded,
            recheck_model_bytes_loaded: self.recheck_model_bytes_loaded,
        }
    }

    pub fn address(&self) -> String {
        let mut parts = vec![
            self.witness_id.clone(),
            self.fresh_wrv_artifact_ref.clone(),
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

pub fn required_fresh_product_runtime_capability_recheck_phases(
) -> [SmallModelFreshProductRuntimeCapabilityRecheckPhase; 12] {
    [
        SmallModelFreshProductRuntimeCapabilityRecheckPhase::FreshWrvArtifactBound,
        SmallModelFreshProductRuntimeCapabilityRecheckPhase::CapabilityKernelRedBound,
        SmallModelFreshProductRuntimeCapabilityRecheckPhase::GuardCursorBound,
        SmallModelFreshProductRuntimeCapabilityRecheckPhase::FreshRuntimeEvidenceBound,
        SmallModelFreshProductRuntimeCapabilityRecheckPhase::FreshAnswerPacketBound,
        SmallModelFreshProductRuntimeCapabilityRecheckPhase::L2BlockersEnumerated,
        SmallModelFreshProductRuntimeCapabilityRecheckPhase::L3LogCorrelationMissing,
        SmallModelFreshProductRuntimeCapabilityRecheckPhase::MasProHonestyBound,
        SmallModelFreshProductRuntimeCapabilityRecheckPhase::HeavyRoutesDeferred,
        SmallModelFreshProductRuntimeCapabilityRecheckPhase::NoNewBytesLoaded,
        SmallModelFreshProductRuntimeCapabilityRecheckPhase::AnswerPacketWitnessBound,
        SmallModelFreshProductRuntimeCapabilityRecheckPhase::L3LogProbeQueued,
    ]
}

pub fn required_fresh_product_runtime_capability_blockers() -> [&'static str; 7] {
    [
        "blocker:l2_capability_kernel_red",
        "blocker:fresh_product_runtime_l3_log_correlation_missing",
        "blocker:l3_manual_runtime_verification_missing",
        "blocker:mas_live_agent_not_promoted",
        "blocker:live_70b_route_not_promoted",
        "blocker:kv_direct_128k_not_promoted",
        "blocker:autogenous_kernel_not_promoted",
    ]
}

pub fn fresh_product_runtime_capability_recheck_metadata_budget_bytes() -> u64 {
    MAX_METADATA_BYTES
}

fn validate_prefixed(
    witness_id: &str,
    value: &str,
    prefix: &str,
) -> Result<(), SmallModelFreshProductRuntimeCapabilityRecheckError> {
    validate_clean("artifact_ref", value)?;
    if !value.starts_with(prefix) {
        return Err(
            SmallModelFreshProductRuntimeCapabilityRecheckError::MissingFreshWrvArtifact(
                witness_id.to_string(),
            ),
        );
    }
    Ok(())
}

fn validate_clean(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelFreshProductRuntimeCapabilityRecheckError> {
    if value.is_empty() {
        return Err(SmallModelFreshProductRuntimeCapabilityRecheckError::MissingField(field));
    }
    if value.trim() != value {
        return Err(
            SmallModelFreshProductRuntimeCapabilityRecheckError::FieldHasSurroundingWhitespace(
                field,
            ),
        );
    }
    if value.chars().any(char::is_control) {
        return Err(
            SmallModelFreshProductRuntimeCapabilityRecheckError::FieldContainsControlCharacter(
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
            answer_packet_ref: "answer_packet:fresh_capability_recheck:red".to_string(),
            rollback_ref: "rollback:no_fresh_product_capability_promotion".to_string(),
            budget_ref: "budget:zero_recheck_runtime_bytes".to_string(),
            safety_ref: "safety:l3_log_correlation_required".to_string(),
            visible: true,
            currently_green: false,
            hidden_route_authority: false,
            route_policy_mutated: false,
        }
    }

    fn witness() -> SmallModelFreshProductRuntimeCapabilityRecheckWitness {
        SmallModelFreshProductRuntimeCapabilityRecheckWitness::new(
            "small-model-fresh-product-runtime-capability-recheck:red-state",
            "artifact:small_model_runtime_harness_fresh_product_runtime_wrv_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR,
            false,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "fresh_product_runtime_capability_recheck_no_route_authority",
            required_fresh_product_runtime_capability_blockers()
                .into_iter()
                .map(blocker)
                .collect(),
            required_fresh_product_runtime_capability_recheck_phases().to_vec(),
            16_777_216,
            2_137_326_367,
            0,
            0,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR,
            1024,
        )
        .expect("fixture is valid")
    }

    #[test]
    fn fixture_validates_and_has_deterministic_address() {
        let valid_witness = witness();
        assert_eq!(
            valid_witness.metrics().phase_count,
            required_fresh_product_runtime_capability_recheck_phases().len() as u64
        );
        assert_eq!(valid_witness.address(), witness().address());
    }

    #[test]
    fn missing_required_blocker_is_rejected() {
        let mut blockers = required_fresh_product_runtime_capability_blockers()
            .into_iter()
            .map(blocker)
            .collect::<Vec<_>>();
        blockers.pop();
        let error = SmallModelFreshProductRuntimeCapabilityRecheckWitness::new(
            "small-model-fresh-product-runtime-capability-recheck:red-state",
            "artifact:small_model_runtime_harness_fresh_product_runtime_wrv_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR,
            false,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "fresh_product_runtime_capability_recheck_no_route_authority",
            blockers,
            required_fresh_product_runtime_capability_recheck_phases().to_vec(),
            16_777_216,
            2_137_326_367,
            0,
            0,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR,
            1024,
        )
        .expect_err("required blockers cannot be omitted");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeCapabilityRecheckError::EmptyBlocker
                | SmallModelFreshProductRuntimeCapabilityRecheckError::MissingRequiredBlocker(_)
        ));
    }

    #[test]
    fn upstream_runtime_bytes_are_required() {
        let error = SmallModelFreshProductRuntimeCapabilityRecheckWitness::new(
            "small-model-fresh-product-runtime-capability-recheck:red-state",
            "artifact:small_model_runtime_harness_fresh_product_runtime_wrv_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR,
            false,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "fresh_product_runtime_capability_recheck_no_route_authority",
            required_fresh_product_runtime_capability_blockers()
                .into_iter()
                .map(blocker)
                .collect(),
            required_fresh_product_runtime_capability_recheck_phases().to_vec(),
            0,
            2_137_326_367,
            0,
            0,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR,
            1024,
        )
        .expect_err("upstream runtime bytes are required");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeCapabilityRecheckError::UpstreamRuntimeBytesMissing
        ));
    }

    #[test]
    fn recheck_runtime_bytes_are_rejected() {
        let error = SmallModelFreshProductRuntimeCapabilityRecheckWitness::new(
            "small-model-fresh-product-runtime-capability-recheck:red-state",
            "artifact:small_model_runtime_harness_fresh_product_runtime_wrv_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR,
            false,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "fresh_product_runtime_capability_recheck_no_route_authority",
            required_fresh_product_runtime_capability_blockers()
                .into_iter()
                .map(blocker)
                .collect(),
            required_fresh_product_runtime_capability_recheck_phases().to_vec(),
            16_777_216,
            2_137_326_367,
            1,
            0,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR,
            1024,
        )
        .expect_err("the recheck must not open new runtime bytes");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeCapabilityRecheckError::RecheckRuntimeBytesLoaded
        ));
    }

    #[test]
    fn autogenous_kernel_attempt_is_rejected() {
        let error = SmallModelFreshProductRuntimeCapabilityRecheckWitness::new(
            "small-model-fresh-product-runtime-capability-recheck:red-state",
            "artifact:small_model_runtime_harness_fresh_product_runtime_wrv_probe:result",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR,
            false,
            "vault_research_route_with_packetized_mitigation",
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_CURSOR,
            ProductBuild::Pro,
            ProStatus::Gated,
            "fresh_product_runtime_capability_recheck_no_route_authority",
            required_fresh_product_runtime_capability_blockers()
                .into_iter()
                .map(blocker)
                .collect(),
            required_fresh_product_runtime_capability_recheck_phases().to_vec(),
            16_777_216,
            2_137_326_367,
            0,
            0,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_CAPABILITY_RECHECK_NEXT_CURSOR,
            1024,
        )
        .expect_err("autogenous kernel stays Pro Research/Omega only");
        assert!(matches!(
            error,
            SmallModelFreshProductRuntimeCapabilityRecheckError::AutogenousKernelAttempted
        ));
    }
}
