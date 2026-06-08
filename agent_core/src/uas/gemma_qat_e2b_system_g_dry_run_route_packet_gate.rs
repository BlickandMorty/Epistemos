//! Gemma QAT E2B System G dry-run route packet gate.
//!
//! This primitive consumes the E2B RuntimeRouter admission packet gate and
//! defines the fail-closed packet required before a future System G dry-run can
//! become route evidence. It is metadata-only: no route is emitted, no runtime
//! is executed, and no model/provider bytes are loaded.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    GemmaFamilyRuntimeLane, ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_QAT_E2B_EXPECTED_FILE_BYTES, GEMMA_QAT_E2B_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_ID,
    GEMMA_QAT_E2B_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_UPSTREAM_REF, GEMMA_QAT_E2B_SOURCE_REVISION,
    GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH, GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME,
    GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID,
};

pub const GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_ID: &str =
    "F-GemmaQATE2BSystemGDryRunRoutePacketGate";
pub const GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_CURSOR: &str =
    "gemma_qat_e2b_system_g_dry_run_route_packet_gate";
pub const GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_NEXT_CURSOR: &str =
    "gemma_qat_e2b_route_answer_packet_visibility_gate";
pub const GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_qat_e2b_runtime_router_admission_packet_gate/result.json#F-GemmaQATE2BRuntimeRouterAdmissionPacketGate";

const UPSTREAM_ADMISSION_PACKET_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_e2b_runtime_router_admission_packet_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_qat_e2b_system_g_dry_run_route_packet_gate/";
const ROUTE_CARD_ID: &str = "gemma-e2b-gguf-system-g-dry-run-route-packet-gate";
const FUTURE_ROUTE_PACKET_NAME: &str = "gemma-e2b-gguf-system-g-dry-run-route-packet-v1";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const ABSTENTION_PREFIX: &str = "abstention:";
const MAX_METADATA_BYTES: u64 = 352 * 1024;

const REQUIRED_ROUTE_FIELDS: &[&str] = &[
    "upstream_admission_packet_digest",
    "route_packet_digest",
    "model_identity_digest",
    "runtime_lane_digest",
    "system_g_dry_run_envelope_digest",
    "runtime_router_policy_digest",
    "route_priority_snapshot_digest",
    "no_priority_mutation_digest",
    "budget_vector_digest",
    "memory_headroom_digest",
    "kv_budget_digest",
    "latency_budget_digest",
    "privacy_class_digest",
    "mas_pro_boundary_digest",
    "scope_rex_verdict_digest",
    "sovereign_gate_verdict_digest",
    "fallback_route_digest",
    "abstention_policy_digest",
    "cancellation_policy_digest",
    "rollback_digest",
    "run_event_log_digest",
    "answer_packet_digest",
    "visible_caveat_digest",
    "settings_visibility_digest",
    "diagnostic_visibility_digest",
    "route_explanation_digest",
    "no_default_model_mutation_digest",
    "no_hidden_authority_digest",
    "non_promotion_digest",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_admission_packet",
    "admission_packet_digest_mismatch",
    "missing_route_packet_digest",
    "missing_system_g_dry_run_envelope",
    "missing_runtime_router_policy",
    "missing_route_priority_snapshot",
    "missing_no_priority_mutation",
    "missing_budget_vector",
    "missing_memory_headroom",
    "missing_kv_budget",
    "missing_latency_budget",
    "missing_privacy_class",
    "missing_mas_pro_boundary",
    "missing_scope_rex_verdict",
    "missing_sovereign_gate_verdict",
    "missing_fallback_route",
    "missing_abstention_policy",
    "missing_cancellation_policy",
    "missing_rollback",
    "missing_run_event_log",
    "missing_answer_packet",
    "missing_visible_caveat",
    "missing_settings_visibility",
    "missing_diagnostic_visibility",
    "missing_route_explanation",
    "bad_selected_model",
    "bad_runtime_lane",
    "future_route_packet_present",
    "future_route_packet_bytes_read",
    "system_g_dry_run_performed",
    "admission_performed",
    "route_priority_mutated",
    "runtime_router_mutated",
    "system_g_mutated",
    "default_model_mutated",
    "command_armed",
    "command_executed",
    "runtime_replay_performed",
    "model_bytes_loaded",
    "runtime_bytes_loaded",
    "provider_calls_made",
    "raw_prompt_retained",
    "raw_output_retained",
    "answer_packet_suppressed",
    "hidden_route_authority",
    "hidden_eidos_authority",
    "hidden_lattice_authority",
    "hidden_patternboost_authority",
    "hidden_cloud_fallback",
    "mas_l2_l3_t4_promotion",
    "gemma_default_promotion",
    "e4b_12b_or_70b_bypass",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
    "quality_claim_before_runtime",
    "benchmark_claimed_as_fit",
];

// UAS: uas:gemma-qat-e2b-system-g-dry-run-route-packet-gate:status
// Plane: Verification.
// Residency: metadata-only route-packet status; no route or runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatE2bSystemGDryRunRoutePacketGateStatus {
    DryRunRoutePacketContractOnly,
}

// UAS: uas:gemma-qat-e2b-system-g-dry-run-route-packet-gate:spec
// Plane: Controller + Verification.
// Residency: future System G dry-run route packet contract only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bSystemGDryRunRoutePacketGate {
    pub upstream_admission_packet_ref: String,
    pub upstream_admission_packet_id: String,
    pub upstream_quality_packet_ref: String,
    pub artifact_root_prefix: String,
    pub route_card_id: String,
    pub future_route_packet_name: String,
    pub selected_model_id: String,
    pub source_revision: String,
    pub required_filename: String,
    pub expected_file_size_bytes: u64,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub command_path: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_route_fields: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub upstream_admission_packet_digest_required: bool,
    pub route_packet_digest_required: bool,
    pub system_g_dry_run_envelope_digest_required: bool,
    pub runtime_router_policy_digest_required: bool,
    pub route_priority_snapshot_digest_required: bool,
    pub no_priority_mutation_digest_required: bool,
    pub budget_vector_bound: bool,
    pub memory_headroom_bound: bool,
    pub kv_budget_bound: bool,
    pub latency_budget_bound: bool,
    pub privacy_class_bound: bool,
    pub mas_pro_boundary_bound: bool,
    pub scope_rex_verdict_ref: String,
    pub sovereign_gate_verdict_ref: String,
    pub fallback_route_ref: String,
    pub abstention_policy_ref: String,
    pub cancellation_policy_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub visible_caveat_digest_required: bool,
    pub settings_visibility_digest_required: bool,
    pub diagnostic_visibility_digest_required: bool,
    pub route_explanation_digest_required: bool,
    pub future_route_packet_present: bool,
    pub future_route_packet_bytes_read: u64,
    pub system_g_dry_run_performed_count: u64,
    pub admission_performed_count: u64,
    pub route_priority_mutation_count: u64,
    pub runtime_router_mutation_allowed: bool,
    pub system_g_mutation_allowed: bool,
    pub default_model_mutation_allowed: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub runtime_replay_performed: bool,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_prompt_bytes_captured: u64,
    pub raw_output_bytes_captured: u64,
    pub answer_packet_suppressed: bool,
    pub hidden_route_authority: bool,
    pub hidden_eidos_authority: bool,
    pub hidden_lattice_authority: bool,
    pub hidden_patternboost_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub mas_promoted: bool,
    pub l2_capability_effect: bool,
    pub l3_wrv_effect: bool,
    pub t4_build_green_effect: bool,
    pub product_route_green: bool,
    pub live_gemma_default_claim: bool,
    pub larger_model_bypass_allowed: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub quality_claimed: bool,
    pub benchmark_claimed_as_fit: bool,
    pub metadata_bytes: u64,
    pub status: GemmaQatE2bSystemGDryRunRoutePacketGateStatus,
    pub next_cursor: String,
}

impl GemmaQatE2bSystemGDryRunRoutePacketGate {
    pub fn canonical(upstream_admission_packet_ref: impl Into<String>) -> Self {
        Self {
            upstream_admission_packet_ref: upstream_admission_packet_ref.into(),
            upstream_admission_packet_id: GEMMA_QAT_E2B_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_ID
                .to_string(),
            upstream_quality_packet_ref:
                GEMMA_QAT_E2B_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_UPSTREAM_REF.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            route_card_id: ROUTE_CARD_ID.to_string(),
            future_route_packet_name: FUTURE_ROUTE_PACKET_NAME.to_string(),
            selected_model_id: GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID.to_string(),
            source_revision: GEMMA_QAT_E2B_SOURCE_REVISION.to_string(),
            required_filename: GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME.to_string(),
            expected_file_size_bytes: GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
            runtime_lane: GemmaFamilyRuntimeLane::GgufLlamaCpp,
            command_path: GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_route_fields: REQUIRED_ROUTE_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            upstream_admission_packet_digest_required: true,
            route_packet_digest_required: true,
            system_g_dry_run_envelope_digest_required: true,
            runtime_router_policy_digest_required: true,
            route_priority_snapshot_digest_required: true,
            no_priority_mutation_digest_required: true,
            budget_vector_bound: true,
            memory_headroom_bound: true,
            kv_budget_bound: true,
            latency_budget_bound: true,
            privacy_class_bound: true,
            mas_pro_boundary_bound: true,
            scope_rex_verdict_ref: "scope_rex:gemma_e2b_system_g_dry_run_route_gate".to_string(),
            sovereign_gate_verdict_ref: "sovereign_gate:gemma_e2b_system_g_dry_run_route_gate"
                .to_string(),
            fallback_route_ref: "fallback:gemma_e2b_dry_run_abstain_to_current_local_lane"
                .to_string(),
            abstention_policy_ref: "abstention:gemma_e2b_dry_run_route_not_emitted".to_string(),
            cancellation_policy_ref: "cancel:gemma_e2b_system_g_dry_run_route_gate".to_string(),
            rollback_ref: "rollback:gemma_e2b_system_g_dry_run_route_gate".to_string(),
            run_event_log_ref: "run_event_log:gemma_e2b_system_g_dry_run_route_gate".to_string(),
            answer_packet_ref: "answer_packet:gemma_e2b_system_g_dry_run_route_gate".to_string(),
            visible_caveat_digest_required: true,
            settings_visibility_digest_required: true,
            diagnostic_visibility_digest_required: true,
            route_explanation_digest_required: true,
            future_route_packet_present: false,
            future_route_packet_bytes_read: 0,
            system_g_dry_run_performed_count: 0,
            admission_performed_count: 0,
            route_priority_mutation_count: 0,
            runtime_router_mutation_allowed: false,
            system_g_mutation_allowed: false,
            default_model_mutation_allowed: false,
            command_armed: false,
            command_executed: false,
            runtime_replay_performed: false,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            raw_prompt_bytes_captured: 0,
            raw_output_bytes_captured: 0,
            answer_packet_suppressed: false,
            hidden_route_authority: false,
            hidden_eidos_authority: false,
            hidden_lattice_authority: false,
            hidden_patternboost_authority: false,
            hidden_cloud_fallback: false,
            mas_promoted: false,
            l2_capability_effect: false,
            l3_wrv_effect: false,
            t4_build_green_effect: false,
            product_route_green: false,
            live_gemma_default_claim: false,
            larger_model_bypass_allowed: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            quality_claimed: false,
            benchmark_claimed_as_fit: false,
            metadata_bytes: 208_000,
            status: GemmaQatE2bSystemGDryRunRoutePacketGateStatus::DryRunRoutePacketContractOnly,
            next_cursor: GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaQatE2bSystemGDryRunRoutePacketGateError> {
        if !self
            .upstream_admission_packet_ref
            .starts_with(UPSTREAM_ADMISSION_PACKET_PREFIX)
            || self.upstream_admission_packet_id
                != GEMMA_QAT_E2B_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_ID
        {
            return Err(GemmaQatE2bSystemGDryRunRoutePacketGateError::BadUpstreamRef);
        }
        validate_exact(
            "upstream_quality_packet_ref",
            &self.upstream_quality_packet_ref,
            GEMMA_QAT_E2B_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_UPSTREAM_REF,
        )?;
        validate_exact(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact("route_card_id", &self.route_card_id, ROUTE_CARD_ID)?;
        validate_exact(
            "future_route_packet_name",
            &self.future_route_packet_name,
            FUTURE_ROUTE_PACKET_NAME,
        )?;
        validate_unique_exact_set(
            "required_route_fields",
            &self.required_route_fields,
            REQUIRED_ROUTE_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_rejection_policies",
            &self.required_rejection_policies,
            REQUIRED_REJECTION_POLICIES,
        )?;
        if self.selected_model_id != GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID
            || self.source_revision != GEMMA_QAT_E2B_SOURCE_REVISION
            || self.required_filename != GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME
            || self.expected_file_size_bytes != GEMMA_QAT_E2B_EXPECTED_FILE_BYTES
            || self.runtime_lane != GemmaFamilyRuntimeLane::GgufLlamaCpp
            || self.command_path != GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH
        {
            return Err(GemmaQatE2bSystemGDryRunRoutePacketGateError::BadSelectedLane);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaQatE2bSystemGDryRunRoutePacketGateStatus::DryRunRoutePacketContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaQatE2bSystemGDryRunRoutePacketGateError::UnsafeState);
        }
        if !self.upstream_admission_packet_digest_required
            || !self.route_packet_digest_required
            || !self.system_g_dry_run_envelope_digest_required
            || !self.runtime_router_policy_digest_required
            || !self.route_priority_snapshot_digest_required
            || !self.no_priority_mutation_digest_required
            || !self.budget_vector_bound
            || !self.memory_headroom_bound
            || !self.kv_budget_bound
            || !self.latency_budget_bound
            || !self.privacy_class_bound
            || !self.mas_pro_boundary_bound
            || !self.visible_caveat_digest_required
            || !self.settings_visibility_digest_required
            || !self.diagnostic_visibility_digest_required
            || !self.route_explanation_digest_required
        {
            return Err(GemmaQatE2bSystemGDryRunRoutePacketGateError::ProofBoundaryBroken);
        }
        validate_prefix(
            "scope_rex_verdict_ref",
            &self.scope_rex_verdict_ref,
            SCOPE_REX_PREFIX,
        )?;
        validate_prefix(
            "sovereign_gate_verdict_ref",
            &self.sovereign_gate_verdict_ref,
            SOVEREIGN_GATE_PREFIX,
        )?;
        validate_prefix("fallback_route_ref", &self.fallback_route_ref, "fallback:")?;
        validate_prefix(
            "abstention_policy_ref",
            &self.abstention_policy_ref,
            ABSTENTION_PREFIX,
        )?;
        validate_prefix(
            "cancellation_policy_ref",
            &self.cancellation_policy_ref,
            "cancel:",
        )?;
        validate_prefix("rollback_ref", &self.rollback_ref, ROLLBACK_PREFIX)?;
        validate_prefix(
            "run_event_log_ref",
            &self.run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
        )?;
        validate_prefix(
            "answer_packet_ref",
            &self.answer_packet_ref,
            ANSWER_PACKET_PREFIX,
        )?;
        if self.future_route_packet_present
            || self.future_route_packet_bytes_read != 0
            || self.system_g_dry_run_performed_count != 0
            || self.admission_performed_count != 0
            || self.route_priority_mutation_count != 0
            || self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.default_model_mutation_allowed
        {
            return Err(GemmaQatE2bSystemGDryRunRoutePacketGateError::RouteActionLeak);
        }
        if self.command_armed
            || self.command_executed
            || self.runtime_replay_performed
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaQatE2bSystemGDryRunRoutePacketGateError::RuntimeActionLeak);
        }
        if self.raw_prompt_bytes_captured != 0
            || self.raw_output_bytes_captured != 0
            || self.answer_packet_suppressed
        {
            return Err(GemmaQatE2bSystemGDryRunRoutePacketGateError::VisibilityOrPrivacyLeak);
        }
        if self.hidden_route_authority
            || self.hidden_eidos_authority
            || self.hidden_lattice_authority
            || self.hidden_patternboost_authority
            || self.hidden_cloud_fallback
            || self.mas_promoted
            || self.l2_capability_effect
            || self.l3_wrv_effect
            || self.t4_build_green_effect
            || self.product_route_green
            || self.live_gemma_default_claim
            || self.larger_model_bypass_allowed
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
            || self.quality_claimed
            || self.benchmark_claimed_as_fit
        {
            return Err(GemmaQatE2bSystemGDryRunRoutePacketGateError::PromotionClaim);
        }
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatE2bSystemGDryRunRoutePacketGateMetrics {
        GemmaQatE2bSystemGDryRunRoutePacketGateMetrics {
            required_route_field_count: self.required_route_fields.len() as u64,
            required_rejection_policy_count: self.required_rejection_policies.len() as u64,
            future_route_packet_present_count: self.future_route_packet_present as u64,
            future_route_packet_bytes_read: self.future_route_packet_bytes_read,
            system_g_dry_run_performed_count: self.system_g_dry_run_performed_count,
            admission_performed_count: self.admission_performed_count,
            route_priority_mutation_count: self.route_priority_mutation_count,
            command_executed_count: self.command_executed as u64,
            runtime_replay_performed_count: self.runtime_replay_performed as u64,
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
            raw_prompt_bytes_captured: self.raw_prompt_bytes_captured,
            raw_output_bytes_captured: self.raw_output_bytes_captured,
            answer_packet_suppressed_count: self.answer_packet_suppressed as u64,
            mutation_count: self.runtime_router_mutation_allowed as u64
                + self.system_g_mutation_allowed as u64
                + self.default_model_mutation_allowed as u64,
            hidden_authority_count: (self.hidden_route_authority
                || self.hidden_eidos_authority
                || self.hidden_lattice_authority
                || self.hidden_patternboost_authority
                || self.hidden_cloud_fallback) as u64,
            promotion_claim_count: (self.mas_promoted
                || self.l2_capability_effect
                || self.l3_wrv_effect
                || self.t4_build_green_effect
                || self.product_route_green
                || self.live_gemma_default_claim
                || self.larger_model_bypass_allowed
                || self.live_dense_70b_claim
                || self.ssd_as_ram_claim
                || self.quality_claimed
                || self.benchmark_claimed_as_fit) as u64,
        }
    }

    pub fn route_packet_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_CURSOR.to_string()),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_route_fields.clone();
        fields.sort();
        let mut policies = self.required_rejection_policies.clone();
        policies.sort();
        format!(
            "gemma-e2b-system-g-dry-run-route-packet-gate:v1:{}:{}:{}:{}:{}:{}:{}:{}",
            self.upstream_admission_packet_ref,
            self.selected_model_id,
            self.source_revision,
            self.required_filename,
            self.expected_file_size_bytes,
            fields.join(","),
            policies.join(","),
            self.next_cursor,
        )
    }
}

// UAS: uas:gemma-qat-e2b-system-g-dry-run-route-packet-gate:metrics
// Plane: Verification.
// Residency: zero-action counters for dry-run routing and visibility.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bSystemGDryRunRoutePacketGateMetrics {
    pub required_route_field_count: u64,
    pub required_rejection_policy_count: u64,
    pub future_route_packet_present_count: u64,
    pub future_route_packet_bytes_read: u64,
    pub system_g_dry_run_performed_count: u64,
    pub admission_performed_count: u64,
    pub route_priority_mutation_count: u64,
    pub command_executed_count: u64,
    pub runtime_replay_performed_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_prompt_bytes_captured: u64,
    pub raw_output_bytes_captured: u64,
    pub answer_packet_suppressed_count: u64,
    pub mutation_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_qat_e2b_system_g_dry_run_route_fields() -> Vec<String> {
    REQUIRED_ROUTE_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_qat_e2b_system_g_dry_run_route_rejection_policies() -> Vec<String> {
    REQUIRED_REJECTION_POLICIES
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-qat-e2b-system-g-dry-run-route-packet-gate:error
// Plane: Verification.
// Residency: fail-closed diagnostics only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatE2bSystemGDryRunRoutePacketGateError {
    BadUpstreamRef,
    BadSelectedLane,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    ProofBoundaryBroken,
    RouteActionLeak,
    RuntimeActionLeak,
    VisibilityOrPrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaQatE2bSystemGDryRunRoutePacketGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream admission packet reference"),
            Self::BadSelectedLane => f.write_str("bad selected E2B dry-run route lane"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe dry-run route packet gate state"),
            Self::ProofBoundaryBroken => f.write_str("proof boundary broken"),
            Self::RouteActionLeak => f.write_str("route or dry-run action leak"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::VisibilityOrPrivacyLeak => f.write_str("visibility or privacy leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaQatE2bSystemGDryRunRoutePacketGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaQatE2bSystemGDryRunRoutePacketGateError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaQatE2bSystemGDryRunRoutePacketGateError::DuplicateOrMissingField(field_name),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaQatE2bSystemGDryRunRoutePacketGateError::DuplicateOrMissingField(field_name),
        );
    }
    Ok(())
}

fn validate_prefix(
    field_name: &'static str,
    actual: &str,
    expected_prefix: &str,
) -> Result<(), GemmaQatE2bSystemGDryRunRoutePacketGateError> {
    if actual.starts_with(expected_prefix) {
        Ok(())
    } else {
        Err(GemmaQatE2bSystemGDryRunRoutePacketGateError::BadField(
            field_name,
        ))
    }
}

fn validate_exact(
    field_name: &'static str,
    actual: &str,
    expected: &str,
) -> Result<(), GemmaQatE2bSystemGDryRunRoutePacketGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaQatE2bSystemGDryRunRoutePacketGateError::BadField(
            field_name,
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_495_600_000;

    #[test]
    fn canonical_route_packet_gate_validates_zero_actions() {
        let gate = GemmaQatE2bSystemGDryRunRoutePacketGate::canonical(
            GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_UPSTREAM_REF,
        );
        gate.validate()
            .expect("canonical dry-run route packet gate should validate");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_route_field_count, 29);
        assert_eq!(metrics.required_rejection_policy_count, 56);
        assert_eq!(metrics.future_route_packet_bytes_read, 0);
        assert_eq!(metrics.system_g_dry_run_performed_count, 0);
        assert_eq!(metrics.admission_performed_count, 0);
        assert_eq!(metrics.mutation_count, 0);
        assert_eq!(metrics.command_executed_count, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.answer_packet_suppressed_count, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn required_set_drift_is_rejected() {
        let mut gate = GemmaQatE2bSystemGDryRunRoutePacketGate::canonical(
            GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_UPSTREAM_REF,
        );
        gate.required_route_fields.pop();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaQatE2bSystemGDryRunRoutePacketGateError::DuplicateOrMissingField(
                    "required_route_fields"
                )
            )
        ));
    }

    #[test]
    fn dry_run_and_route_mutation_are_rejected() {
        let mut gate = GemmaQatE2bSystemGDryRunRoutePacketGate::canonical(
            GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_UPSTREAM_REF,
        );
        gate.system_g_dry_run_performed_count = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bSystemGDryRunRoutePacketGateError::RouteActionLeak)
        ));
        let mut gate = GemmaQatE2bSystemGDryRunRoutePacketGate::canonical(
            GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_UPSTREAM_REF,
        );
        gate.runtime_router_mutation_allowed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bSystemGDryRunRoutePacketGateError::RouteActionLeak)
        ));
    }

    #[test]
    fn runtime_execution_and_promotion_are_rejected() {
        let mut gate = GemmaQatE2bSystemGDryRunRoutePacketGate::canonical(
            GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_UPSTREAM_REF,
        );
        gate.command_executed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bSystemGDryRunRoutePacketGateError::RuntimeActionLeak)
        ));
        let mut gate = GemmaQatE2bSystemGDryRunRoutePacketGate::canonical(
            GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_UPSTREAM_REF,
        );
        gate.l2_capability_effect = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bSystemGDryRunRoutePacketGateError::PromotionClaim)
        ));
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let gate = GemmaQatE2bSystemGDryRunRoutePacketGate::canonical(
            GEMMA_QAT_E2B_SYSTEM_G_DRY_RUN_ROUTE_PACKET_GATE_UPSTREAM_REF,
        );
        let reversed = GemmaQatE2bSystemGDryRunRoutePacketGate {
            required_route_fields: gate.required_route_fields.iter().cloned().rev().collect(),
            required_rejection_policies: gate
                .required_rejection_policies
                .iter()
                .cloned()
                .rev()
                .collect(),
            ..gate.clone()
        };
        reversed.validate().expect("reversed sets remain canonical");
        assert_eq!(
            gate.route_packet_gate_address(CREATED_AT_MS),
            reversed.route_packet_gate_address(CREATED_AT_MS)
        );
    }
}
