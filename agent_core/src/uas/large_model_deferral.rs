//! Large-model provider-reference deferral contracts.
//!
//! This module makes the default-route deferral explicit: provider/fp16,
//! GGUF/128K, dense 70B, and live sparse 70B work are not active when the app
//! is routed through practical local MLX and `EPISTEMOS_ALLOW_HEAVY_LONG_CONTEXT`
//! is not set.

use std::collections::HashSet;
use std::fmt;

use super::small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe::SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_RELEASE_AUDIT_CURSOR;
use crate::uas::{ProStatus, ProductBuild, UasAddress, UasKind};

pub const LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_CURSOR: &str =
    "large_model_provider_reference_deferred_by_mlx_route";

pub fn large_model_provider_reference_deferred_or_advanced_cursor(cursor: &str) -> bool {
    matches!(
        cursor,
        LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_CURSOR
            | SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_MANUAL_RUNTIME_VERIFICATION_PROBE_RELEASE_AUDIT_CURSOR
    )
}

const ARTIFACT_PREFIX: &str = "artifact:falsifier:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const COMPATIBILITY_FENCE_PREFIX: &str = "compat:";

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
// UAS: uas:large-model-provider-deferral:active-lane
// Plane: Controller
// Residency: metadata-only route label; no model/provider bytes are touched.
pub enum LargeModelActiveLane {
    PracticalMlxLocal,
    ColdAssemblyPlanner,
}

impl LargeModelActiveLane {
    fn wire_tag(&self) -> &'static str {
        match self {
            Self::PracticalMlxLocal => "practical_mlx_local",
            Self::ColdAssemblyPlanner => "cold_assembly_planner",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
// UAS: uas:large-model-provider-deferral:deferred-lane
// Plane: Controller + Verification
// Residency: metadata-only deferred route label; runtime probes remain opt-in.
pub enum LargeModelDeferredLane {
    ProviderReferencePromptLevel,
    KvDirect128k,
    Dense70bRuntime,
    LiveSparse70bRuntime,
}

impl LargeModelDeferredLane {
    fn wire_tag(&self) -> &'static str {
        match self {
            Self::ProviderReferencePromptLevel => "provider_reference_prompt_level",
            Self::KvDirect128k => "kv_direct_128k",
            Self::Dense70bRuntime => "dense_70b_runtime",
            Self::LiveSparse70bRuntime => "live_sparse_70b_runtime",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:large-model-provider-deferral:error
// Plane: Verification
// Residency: metadata-only rejection taxonomy for heavy-route deferral.
pub enum LargeModelDeferralError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    MissingDeferredLane,
    DuplicateDeferredLane(String),
    WrongCursor(String),
    MissingProviderReferenceReadinessRef,
    MissingLocal70bPreflightRef,
    MissingGuardRef,
    MissingCapabilityKernelRef,
    MissingRollback,
    MissingRunEventLog,
    MissingAnswerPacket,
    MissingCompatibilityFence,
    HeavyLongContextEnabled,
    ProviderReferenceRequired,
    ProviderCallAttempted,
    PromptLevelManifestCreated,
    KvShardRerunRequested,
    RuntimeBytesLoaded,
    ModelBytesLoaded,
    HiddenCloudFallback,
    ProductRoutePromoted,
    DenseResidentOverclaim,
    PracticalMlxRouteMissing,
    ColdAssemblyArchitectureMissing,
    ProductStatusMismatch,
}

impl fmt::Display for LargeModelDeferralError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::MissingDeferredLane => write!(f, "missing deferred large-model lane"),
            Self::DuplicateDeferredLane(lane) => write!(f, "duplicate deferred lane `{lane}`"),
            Self::WrongCursor(cursor) => write!(f, "wrong deferral cursor `{cursor}`"),
            Self::MissingProviderReferenceReadinessRef => {
                write!(f, "missing provider-reference readiness ref")
            }
            Self::MissingLocal70bPreflightRef => write!(f, "missing local 70B preflight ref"),
            Self::MissingGuardRef => write!(f, "missing architecture guard ref"),
            Self::MissingCapabilityKernelRef => write!(f, "missing capability kernel ref"),
            Self::MissingRollback => write!(f, "missing rollback ref"),
            Self::MissingRunEventLog => write!(f, "missing RunEventLog ref"),
            Self::MissingAnswerPacket => write!(f, "missing AnswerPacket ref"),
            Self::MissingCompatibilityFence => write!(f, "missing compatibility fence"),
            Self::HeavyLongContextEnabled => write!(f, "heavy long-context route is enabled"),
            Self::ProviderReferenceRequired => write!(f, "provider reference is required"),
            Self::ProviderCallAttempted => write!(f, "provider call attempted"),
            Self::PromptLevelManifestCreated => write!(f, "prompt-level manifest was created"),
            Self::KvShardRerunRequested => write!(f, "KV shard rerun requested"),
            Self::RuntimeBytesLoaded => write!(f, "runtime bytes loaded"),
            Self::ModelBytesLoaded => write!(f, "model bytes loaded"),
            Self::HiddenCloudFallback => write!(f, "hidden cloud fallback present"),
            Self::ProductRoutePromoted => write!(f, "product route promoted"),
            Self::DenseResidentOverclaim => write!(f, "dense resident overclaim present"),
            Self::PracticalMlxRouteMissing => write!(f, "practical MLX route missing"),
            Self::ColdAssemblyArchitectureMissing => {
                write!(f, "cold assembly architecture missing")
            }
            Self::ProductStatusMismatch => write!(f, "deferral card has product status mismatch"),
        }
    }
}

impl std::error::Error for LargeModelDeferralError {}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:large-model-provider-deferral:card
// Plane: Controller + Verification
// Residency: metadata-only deferral card; no runtime/provider/model bytes move.
pub struct LargeModelProviderDeferralCard {
    pub card_address: UasAddress,
    pub card_id: String,
    pub current_cursor: String,
    pub active_lane: LargeModelActiveLane,
    pub deferred_lanes: Vec<LargeModelDeferredLane>,
    pub provider_reference_readiness_ref: String,
    pub provider_reference_primary_blocker: String,
    pub local_70b_preflight_ref: String,
    pub guard_ref: String,
    pub capability_kernel_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub compatibility_fence: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub heavy_long_context_enabled: bool,
    pub provider_reference_required: bool,
    pub provider_calls_attempted: u32,
    pub prompt_level_manifest_created: bool,
    pub kv_shard_rerun_requested: bool,
    pub runtime_bytes_loaded: u64,
    pub model_bytes_loaded: u64,
    pub hidden_cloud_fallback: bool,
    pub product_route_promoted: bool,
    pub dense_resident_overclaim: bool,
    pub practical_mlx_route_preserved: bool,
    pub cold_assembly_architecture_preserved: bool,
}

impl LargeModelProviderDeferralCard {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        card_id: impl Into<String>,
        current_cursor: impl Into<String>,
        active_lane: LargeModelActiveLane,
        deferred_lanes: Vec<LargeModelDeferredLane>,
        provider_reference_readiness_ref: impl Into<String>,
        provider_reference_primary_blocker: impl Into<String>,
        local_70b_preflight_ref: impl Into<String>,
        guard_ref: impl Into<String>,
        capability_kernel_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        run_event_log_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        compatibility_fence: impl Into<String>,
        product_build: ProductBuild,
        pro_status: ProStatus,
        heavy_long_context_enabled: bool,
        provider_reference_required: bool,
        provider_calls_attempted: u32,
        prompt_level_manifest_created: bool,
        kv_shard_rerun_requested: bool,
        runtime_bytes_loaded: u64,
        model_bytes_loaded: u64,
        hidden_cloud_fallback: bool,
        product_route_promoted: bool,
        dense_resident_overclaim: bool,
        practical_mlx_route_preserved: bool,
        cold_assembly_architecture_preserved: bool,
        created_at_ms: u64,
    ) -> Result<Self, LargeModelDeferralError> {
        let card_id = card_id.into();
        let current_cursor = current_cursor.into();
        let provider_reference_readiness_ref = provider_reference_readiness_ref.into();
        let provider_reference_primary_blocker = provider_reference_primary_blocker.into();
        let local_70b_preflight_ref = local_70b_preflight_ref.into();
        let guard_ref = guard_ref.into();
        let capability_kernel_ref = capability_kernel_ref.into();
        let rollback_ref = rollback_ref.into();
        let run_event_log_ref = run_event_log_ref.into();
        let answer_packet_ref = answer_packet_ref.into();
        let compatibility_fence = compatibility_fence.into();

        validate_nonempty("card_id", &card_id)?;
        validate_nonempty("current_cursor", &current_cursor)?;
        validate_nonempty(
            "provider_reference_readiness_ref",
            &provider_reference_readiness_ref,
        )?;
        validate_nonempty(
            "provider_reference_primary_blocker",
            &provider_reference_primary_blocker,
        )?;
        validate_nonempty("local_70b_preflight_ref", &local_70b_preflight_ref)?;
        validate_nonempty("guard_ref", &guard_ref)?;
        validate_nonempty("capability_kernel_ref", &capability_kernel_ref)?;
        validate_nonempty("rollback_ref", &rollback_ref)?;
        validate_nonempty("run_event_log_ref", &run_event_log_ref)?;
        validate_nonempty("answer_packet_ref", &answer_packet_ref)?;
        validate_nonempty("compatibility_fence", &compatibility_fence)?;
        validate_deferred_lanes(&deferred_lanes)?;

        if current_cursor != LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_CURSOR {
            return Err(LargeModelDeferralError::WrongCursor(current_cursor));
        }
        if !provider_reference_readiness_ref.starts_with(ARTIFACT_PREFIX) {
            return Err(LargeModelDeferralError::MissingProviderReferenceReadinessRef);
        }
        if !local_70b_preflight_ref.starts_with(ARTIFACT_PREFIX) {
            return Err(LargeModelDeferralError::MissingLocal70bPreflightRef);
        }
        if !guard_ref.starts_with(ARTIFACT_PREFIX) {
            return Err(LargeModelDeferralError::MissingGuardRef);
        }
        if !capability_kernel_ref.starts_with(ARTIFACT_PREFIX) {
            return Err(LargeModelDeferralError::MissingCapabilityKernelRef);
        }
        if !rollback_ref.starts_with(ROLLBACK_PREFIX) {
            return Err(LargeModelDeferralError::MissingRollback);
        }
        if !run_event_log_ref.starts_with(RUN_EVENT_LOG_PREFIX) {
            return Err(LargeModelDeferralError::MissingRunEventLog);
        }
        if !answer_packet_ref.starts_with(ANSWER_PACKET_PREFIX) {
            return Err(LargeModelDeferralError::MissingAnswerPacket);
        }
        if !compatibility_fence.starts_with(COMPATIBILITY_FENCE_PREFIX) {
            return Err(LargeModelDeferralError::MissingCompatibilityFence);
        }
        if product_build != ProductBuild::Pro || pro_status != ProStatus::ResearchCandidate {
            return Err(LargeModelDeferralError::ProductStatusMismatch);
        }
        if heavy_long_context_enabled {
            return Err(LargeModelDeferralError::HeavyLongContextEnabled);
        }
        if provider_reference_required {
            return Err(LargeModelDeferralError::ProviderReferenceRequired);
        }
        if provider_calls_attempted > 0 {
            return Err(LargeModelDeferralError::ProviderCallAttempted);
        }
        if prompt_level_manifest_created {
            return Err(LargeModelDeferralError::PromptLevelManifestCreated);
        }
        if kv_shard_rerun_requested {
            return Err(LargeModelDeferralError::KvShardRerunRequested);
        }
        if runtime_bytes_loaded > 0 {
            return Err(LargeModelDeferralError::RuntimeBytesLoaded);
        }
        if model_bytes_loaded > 0 {
            return Err(LargeModelDeferralError::ModelBytesLoaded);
        }
        if hidden_cloud_fallback {
            return Err(LargeModelDeferralError::HiddenCloudFallback);
        }
        if product_route_promoted {
            return Err(LargeModelDeferralError::ProductRoutePromoted);
        }
        if dense_resident_overclaim {
            return Err(LargeModelDeferralError::DenseResidentOverclaim);
        }
        if !practical_mlx_route_preserved {
            return Err(LargeModelDeferralError::PracticalMlxRouteMissing);
        }
        if !cold_assembly_architecture_preserved {
            return Err(LargeModelDeferralError::ColdAssemblyArchitectureMissing);
        }

        let mut deferred_lanes = deferred_lanes;
        deferred_lanes.sort_by_key(|lane| lane.wire_tag());
        let card_address = deferral_card_address(
            &card_id,
            &current_cursor,
            &active_lane,
            &deferred_lanes,
            &provider_reference_readiness_ref,
            &provider_reference_primary_blocker,
            &local_70b_preflight_ref,
            &guard_ref,
            &capability_kernel_ref,
            &rollback_ref,
            &run_event_log_ref,
            &answer_packet_ref,
            &compatibility_fence,
            created_at_ms,
        );

        Ok(Self {
            card_address,
            card_id,
            current_cursor,
            active_lane,
            deferred_lanes,
            provider_reference_readiness_ref,
            provider_reference_primary_blocker,
            local_70b_preflight_ref,
            guard_ref,
            capability_kernel_ref,
            rollback_ref,
            run_event_log_ref,
            answer_packet_ref,
            compatibility_fence,
            product_build,
            pro_status,
            heavy_long_context_enabled,
            provider_reference_required,
            provider_calls_attempted,
            prompt_level_manifest_created,
            kv_shard_rerun_requested,
            runtime_bytes_loaded,
            model_bytes_loaded,
            hidden_cloud_fallback,
            product_route_promoted,
            dense_resident_overclaim,
            practical_mlx_route_preserved,
            cold_assembly_architecture_preserved,
        })
    }

    pub fn deferred_lane_count(&self) -> usize {
        self.deferred_lanes.len()
    }
}

fn validate_deferred_lanes(
    deferred_lanes: &[LargeModelDeferredLane],
) -> Result<(), LargeModelDeferralError> {
    if deferred_lanes.is_empty() {
        return Err(LargeModelDeferralError::MissingDeferredLane);
    }
    let mut lanes = HashSet::new();
    for lane in deferred_lanes {
        let tag = lane.wire_tag().to_string();
        if !lanes.insert(tag.clone()) {
            return Err(LargeModelDeferralError::DuplicateDeferredLane(tag));
        }
    }
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn deferral_card_address(
    card_id: &str,
    current_cursor: &str,
    active_lane: &LargeModelActiveLane,
    deferred_lanes: &[LargeModelDeferredLane],
    provider_reference_readiness_ref: &str,
    provider_reference_primary_blocker: &str,
    local_70b_preflight_ref: &str,
    guard_ref: &str,
    capability_kernel_ref: &str,
    rollback_ref: &str,
    run_event_log_ref: &str,
    answer_packet_ref: &str,
    compatibility_fence: &str,
    created_at_ms: u64,
) -> UasAddress {
    let mut content = String::new();
    content.push_str(card_id);
    content.push('|');
    content.push_str(current_cursor);
    content.push('|');
    content.push_str(active_lane.wire_tag());
    for lane in deferred_lanes {
        content.push('|');
        content.push_str(lane.wire_tag());
    }
    content.push('|');
    content.push_str(provider_reference_readiness_ref);
    content.push('|');
    content.push_str(provider_reference_primary_blocker);
    content.push('|');
    content.push_str(local_70b_preflight_ref);
    content.push('|');
    content.push_str(guard_ref);
    content.push('|');
    content.push_str(capability_kernel_ref);
    content.push('|');
    content.push_str(rollback_ref);
    content.push('|');
    content.push_str(run_event_log_ref);
    content.push('|');
    content.push_str(answer_packet_ref);
    content.push('|');
    content.push_str(compatibility_fence);
    UasAddress::new(
        UasKind::Other("large_model_provider_deferral_card".to_string()),
        content.as_bytes(),
        created_at_ms,
    )
}

fn validate_nonempty(field: &'static str, value: &str) -> Result<(), LargeModelDeferralError> {
    if value.is_empty() {
        return Err(LargeModelDeferralError::MissingField(field));
    }
    if value.trim() != value {
        return Err(LargeModelDeferralError::FieldHasSurroundingWhitespace(
            field,
        ));
    }
    if value.chars().any(char::is_control) {
        return Err(LargeModelDeferralError::FieldContainsControlCharacter(
            field,
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_552_000_000;

    #[test]
    fn valid_deferral_card_preserves_mlx_and_cold_assembly_without_runtime_bytes() {
        let card = fixture_card().expect("fixture card");

        assert_eq!(
            card.current_cursor,
            LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_CURSOR
        );
        assert_eq!(card.deferred_lane_count(), 4);
        assert!(!card.heavy_long_context_enabled);
        assert!(!card.provider_reference_required);
        assert_eq!(card.provider_calls_attempted, 0);
        assert_eq!(card.runtime_bytes_loaded, 0);
        assert_eq!(card.model_bytes_loaded, 0);
        assert!(card.practical_mlx_route_preserved);
        assert!(card.cold_assembly_architecture_preserved);
    }

    #[test]
    fn card_address_is_deterministic_under_deferred_lane_order() {
        let left = fixture_card().expect("left card");
        let mut lanes = fixture_lanes();
        lanes.reverse();
        let right = card_with_lanes(lanes).expect("right card");

        assert_eq!(left.card_address, right.card_address);
    }

    #[test]
    fn deferral_rejects_heavy_or_provider_activation() {
        assert_eq!(
            card_with_flags(true, false, 0, false, false, 0, 0, false, false, false, true, true)
                .unwrap_err(),
            LargeModelDeferralError::HeavyLongContextEnabled
        );
        assert_eq!(
            card_with_flags(false, true, 0, false, false, 0, 0, false, false, false, true, true)
                .unwrap_err(),
            LargeModelDeferralError::ProviderReferenceRequired
        );
        assert_eq!(
            card_with_flags(false, false, 1, false, false, 0, 0, false, false, false, true, true)
                .unwrap_err(),
            LargeModelDeferralError::ProviderCallAttempted
        );
        assert_eq!(
            card_with_flags(false, false, 0, true, false, 0, 0, false, false, false, true, true)
                .unwrap_err(),
            LargeModelDeferralError::PromptLevelManifestCreated
        );
        assert_eq!(
            card_with_flags(false, false, 0, false, true, 0, 0, false, false, false, true, true)
                .unwrap_err(),
            LargeModelDeferralError::KvShardRerunRequested
        );
    }

    #[test]
    fn deferral_rejects_runtime_product_and_hidden_fallback() {
        assert_eq!(
            card_with_flags(false, false, 0, false, false, 1, 0, false, false, false, true, true)
                .unwrap_err(),
            LargeModelDeferralError::RuntimeBytesLoaded
        );
        assert_eq!(
            card_with_flags(false, false, 0, false, false, 0, 1, false, false, false, true, true)
                .unwrap_err(),
            LargeModelDeferralError::ModelBytesLoaded
        );
        assert_eq!(
            card_with_flags(false, false, 0, false, false, 0, 0, true, false, false, true, true)
                .unwrap_err(),
            LargeModelDeferralError::HiddenCloudFallback
        );
        assert_eq!(
            card_with_flags(false, false, 0, false, false, 0, 0, false, true, false, true, true)
                .unwrap_err(),
            LargeModelDeferralError::ProductRoutePromoted
        );
        assert_eq!(
            card_with_flags(false, false, 0, false, false, 0, 0, false, false, true, true, true)
                .unwrap_err(),
            LargeModelDeferralError::DenseResidentOverclaim
        );
    }

    #[test]
    fn deferral_rejects_missing_route_preservation() {
        assert_eq!(
            card_with_flags(false, false, 0, false, false, 0, 0, false, false, false, false, true)
                .unwrap_err(),
            LargeModelDeferralError::PracticalMlxRouteMissing
        );
        assert_eq!(
            card_with_flags(false, false, 0, false, false, 0, 0, false, false, false, true, false)
                .unwrap_err(),
            LargeModelDeferralError::ColdAssemblyArchitectureMissing
        );
    }

    #[test]
    fn deferral_rejects_bad_refs_and_cursor() {
        assert_eq!(
            fixture_card_with_cursor("missing_fp16_or_provider_reference").unwrap_err(),
            LargeModelDeferralError::WrongCursor("missing_fp16_or_provider_reference".to_string())
        );
        assert_eq!(
            card_with_readiness_ref("bad").unwrap_err(),
            LargeModelDeferralError::MissingProviderReferenceReadinessRef
        );
        assert_eq!(
            card_with_lanes(vec![]).unwrap_err(),
            LargeModelDeferralError::MissingDeferredLane
        );
        assert!(matches!(
            card_with_lanes(vec![
                LargeModelDeferredLane::KvDirect128k,
                LargeModelDeferredLane::KvDirect128k
            ])
            .unwrap_err(),
            LargeModelDeferralError::DuplicateDeferredLane(_)
        ));
    }

    fn fixture_card() -> Result<LargeModelProviderDeferralCard, LargeModelDeferralError> {
        card_with_lanes(fixture_lanes())
    }

    fn fixture_lanes() -> Vec<LargeModelDeferredLane> {
        vec![
            LargeModelDeferredLane::ProviderReferencePromptLevel,
            LargeModelDeferredLane::KvDirect128k,
            LargeModelDeferredLane::Dense70bRuntime,
            LargeModelDeferredLane::LiveSparse70bRuntime,
        ]
    }

    fn card_with_lanes(
        lanes: Vec<LargeModelDeferredLane>,
    ) -> Result<LargeModelProviderDeferralCard, LargeModelDeferralError> {
        new_card(
            LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_CURSOR,
            lanes,
            "artifact:falsifier:provider_reference_prompt_level_readiness",
            false,
            false,
            0,
            false,
            false,
            0,
            0,
            false,
            false,
            false,
            true,
            true,
        )
    }

    fn fixture_card_with_cursor(
        cursor: &str,
    ) -> Result<LargeModelProviderDeferralCard, LargeModelDeferralError> {
        new_card(
            cursor,
            fixture_lanes(),
            "artifact:falsifier:provider_reference_prompt_level_readiness",
            false,
            false,
            0,
            false,
            false,
            0,
            0,
            false,
            false,
            false,
            true,
            true,
        )
    }

    fn card_with_readiness_ref(
        readiness_ref: &str,
    ) -> Result<LargeModelProviderDeferralCard, LargeModelDeferralError> {
        new_card(
            LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_CURSOR,
            fixture_lanes(),
            readiness_ref,
            false,
            false,
            0,
            false,
            false,
            0,
            0,
            false,
            false,
            false,
            true,
            true,
        )
    }

    #[allow(clippy::too_many_arguments)]
    fn card_with_flags(
        heavy_long_context_enabled: bool,
        provider_reference_required: bool,
        provider_calls_attempted: u32,
        prompt_level_manifest_created: bool,
        kv_shard_rerun_requested: bool,
        runtime_bytes_loaded: u64,
        model_bytes_loaded: u64,
        hidden_cloud_fallback: bool,
        product_route_promoted: bool,
        dense_resident_overclaim: bool,
        practical_mlx_route_preserved: bool,
        cold_assembly_architecture_preserved: bool,
    ) -> Result<LargeModelProviderDeferralCard, LargeModelDeferralError> {
        new_card(
            LARGE_MODEL_PROVIDER_REFERENCE_DEFERRED_CURSOR,
            fixture_lanes(),
            "artifact:falsifier:provider_reference_prompt_level_readiness",
            heavy_long_context_enabled,
            provider_reference_required,
            provider_calls_attempted,
            prompt_level_manifest_created,
            kv_shard_rerun_requested,
            runtime_bytes_loaded,
            model_bytes_loaded,
            hidden_cloud_fallback,
            product_route_promoted,
            dense_resident_overclaim,
            practical_mlx_route_preserved,
            cold_assembly_architecture_preserved,
        )
    }

    #[allow(clippy::too_many_arguments)]
    fn new_card(
        current_cursor: &str,
        lanes: Vec<LargeModelDeferredLane>,
        provider_reference_readiness_ref: &str,
        heavy_long_context_enabled: bool,
        provider_reference_required: bool,
        provider_calls_attempted: u32,
        prompt_level_manifest_created: bool,
        kv_shard_rerun_requested: bool,
        runtime_bytes_loaded: u64,
        model_bytes_loaded: u64,
        hidden_cloud_fallback: bool,
        product_route_promoted: bool,
        dense_resident_overclaim: bool,
        practical_mlx_route_preserved: bool,
        cold_assembly_architecture_preserved: bool,
    ) -> Result<LargeModelProviderDeferralCard, LargeModelDeferralError> {
        LargeModelProviderDeferralCard::new(
            "large-model-provider-deferral:fixture",
            current_cursor,
            LargeModelActiveLane::PracticalMlxLocal,
            lanes,
            provider_reference_readiness_ref,
            "missing_provider_reference_env",
            "artifact:falsifier:70b_local_cocktail_lite",
            "artifact:falsifier:architecture_pending_work_guard",
            "artifact:falsifier:capability_ceiling_evaluation_kernel",
            "rollback:large-model-provider-deferral:v1",
            "run_event_log:large-model-provider-deferral:v1",
            "answer_packet:large-model-provider-deferral:v1",
            "compat:large-model-provider-deferral:v1",
            ProductBuild::Pro,
            ProStatus::ResearchCandidate,
            heavy_long_context_enabled,
            provider_reference_required,
            provider_calls_attempted,
            prompt_level_manifest_created,
            kv_shard_rerun_requested,
            runtime_bytes_loaded,
            model_bytes_loaded,
            hidden_cloud_fallback,
            product_route_promoted,
            dense_resident_overclaim,
            practical_mlx_route_preserved,
            cold_assembly_architecture_preserved,
            CREATED_AT_MS,
        )
    }
}
