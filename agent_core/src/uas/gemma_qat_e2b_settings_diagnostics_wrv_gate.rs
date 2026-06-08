//! Gemma QAT E2B settings diagnostics WRV gate.
//!
//! This primitive consumes the E2B route AnswerPacket visibility gate and
//! defines the fail-closed settings/diagnostics WRV contract required before
//! future Gemma route evidence can be wired to product surfaces. It is
//! metadata-only: no user-facing UI is changed, no route is admitted, no
//! runtime is executed, and no model/provider bytes are loaded.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    GemmaFamilyRuntimeLane, ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_QAT_E2B_EXPECTED_FILE_BYTES, GEMMA_QAT_E2B_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_ID,
    GEMMA_QAT_E2B_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_UPSTREAM_REF, GEMMA_QAT_E2B_SOURCE_REVISION,
    GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH, GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME,
    GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID,
};

pub const GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_ID: &str =
    "F-GemmaQATE2BSettingsDiagnosticsWRVGate";
pub const GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_CURSOR: &str =
    "gemma_qat_e2b_settings_diagnostics_wrv_gate";
pub const GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_NEXT_CURSOR: &str =
    "gemma_qat_e2b_release_audit_surface_gate";
pub const GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_qat_e2b_route_answer_packet_visibility_gate/result.json#F-GemmaQATE2BRouteAnswerPacketVisibilityGate";

const UPSTREAM_ROUTE_ANSWER_PACKET_VISIBILITY_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_e2b_route_answer_packet_visibility_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_qat_e2b_settings_diagnostics_wrv_gate/";
const VISIBILITY_CARD_ID: &str = "gemma-e2b-gguf-settings-diagnostics-wrv-gate";
const FUTURE_VISIBILITY_PACKET_NAME: &str = "gemma-e2b-gguf-settings-diagnostics-wrv-v1";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ABSTENTION_PREFIX: &str = "abstention:";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const MAX_METADATA_BYTES: u64 = 384 * 1024;

const REQUIRED_VISIBILITY_FIELDS: &[&str] = &[
    "upstream_route_answer_packet_visibility_digest",
    "settings_source_marker_digest",
    "diagnostics_source_marker_digest",
    "wrv_test_marker_digest",
    "manual_check_plan_digest",
    "release_audit_link_digest",
    "answer_packet_template_digest",
    "settings_surface_copy_digest",
    "diagnostics_surface_copy_digest",
    "visible_model_identity_digest",
    "visible_runtime_lane_digest",
    "visible_route_status_digest",
    "visible_route_caveat_digest",
    "visible_budget_summary_digest",
    "visible_memory_headroom_digest",
    "visible_kv_budget_digest",
    "visible_latency_budget_digest",
    "visible_privacy_class_digest",
    "visible_mas_pro_boundary_digest",
    "visible_scope_rex_digest",
    "visible_sovereign_gate_digest",
    "visible_fallback_digest",
    "visible_abstention_digest",
    "visible_cancellation_digest",
    "visible_rollback_digest",
    "visible_run_event_log_digest",
    "route_explanation_digest",
    "rejected_candidate_summary_digest",
    "user_action_required_digest",
    "no_toggle_unlock_digest",
    "no_quality_claim_digest",
    "no_live_default_claim_digest",
    "no_large_model_bypass_digest",
    "no_l2_l3_t4_claim_digest",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_route_answer_packet_visibility",
    "route_answer_packet_visibility_digest_mismatch",
    "missing_settings_source_marker",
    "missing_diagnostics_source_marker",
    "missing_wrv_test_marker",
    "missing_manual_check_plan",
    "missing_release_audit_link",
    "missing_answer_packet_template",
    "missing_settings_surface_copy",
    "missing_diagnostics_surface_copy",
    "missing_visible_model_identity",
    "missing_visible_runtime_lane",
    "missing_visible_route_status",
    "missing_visible_route_caveat",
    "missing_visible_budget_summary",
    "missing_visible_memory_headroom",
    "missing_visible_kv_budget",
    "missing_visible_latency_budget",
    "missing_visible_privacy_class",
    "missing_visible_mas_pro_boundary",
    "missing_visible_scope_rex",
    "missing_visible_sovereign_gate",
    "missing_visible_fallback",
    "missing_visible_abstention",
    "missing_visible_cancellation",
    "missing_visible_rollback",
    "missing_visible_run_event_log",
    "missing_route_explanation",
    "missing_rejected_candidate_summary",
    "missing_user_action_required",
    "settings_toggle_unlocked",
    "diagnostics_claims_live_route",
    "model_picker_default_mutated",
    "missing_no_quality_claim",
    "missing_no_live_default_claim",
    "missing_no_large_model_bypass",
    "missing_no_l2_l3_t4_claim",
    "bad_selected_model",
    "bad_runtime_lane",
    "future_visibility_packet_present",
    "future_visibility_packet_bytes_read",
    "answer_packet_emitted_to_user",
    "system_g_route_visibility_performed",
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

// UAS: uas:gemma-qat-e2b-settings-diagnostics-wrv-gate:status
// Plane: Verification.
// Residency: metadata-only visibility status; no user-visible packet emitted.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatE2bSettingsDiagnosticsWrvGateStatus {
    SettingsDiagnosticsWrvContractOnly,
}

// UAS: uas:gemma-qat-e2b-settings-diagnostics-wrv-gate:spec
// Plane: Controller + Verification.
// Residency: future settings diagnostics WRV contract only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bSettingsDiagnosticsWrvGate {
    pub upstream_route_answer_packet_visibility_ref: String,
    pub upstream_route_answer_packet_visibility_id: String,
    pub upstream_admission_packet_ref: String,
    pub artifact_root_prefix: String,
    pub visibility_card_id: String,
    pub future_visibility_packet_name: String,
    pub selected_model_id: String,
    pub source_revision: String,
    pub required_filename: String,
    pub expected_file_size_bytes: u64,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub command_path: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_visibility_fields: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub upstream_route_answer_packet_visibility_digest_required: bool,
    pub settings_source_marker_digest_required: bool,
    pub diagnostics_source_marker_digest_required: bool,
    pub wrv_test_marker_digest_required: bool,
    pub manual_check_plan_digest_required: bool,
    pub release_audit_link_digest_required: bool,
    pub answer_packet_template_digest_required: bool,
    pub visible_model_identity_required: bool,
    pub visible_runtime_lane_required: bool,
    pub visible_route_status_required: bool,
    pub visible_route_caveat_required: bool,
    pub visible_budget_summary_required: bool,
    pub visible_memory_headroom_required: bool,
    pub visible_kv_budget_required: bool,
    pub visible_latency_budget_required: bool,
    pub visible_privacy_class_required: bool,
    pub visible_mas_pro_boundary_required: bool,
    pub visible_scope_rex_ref: String,
    pub visible_sovereign_gate_ref: String,
    pub visible_fallback_ref: String,
    pub visible_abstention_ref: String,
    pub visible_cancellation_ref: String,
    pub visible_rollback_ref: String,
    pub visible_run_event_log_ref: String,
    pub visible_no_default_model_mutation_required: bool,
    pub visible_no_hidden_authority_required: bool,
    pub visible_non_promotion_required: bool,
    pub settings_surface_copy_digest_required: bool,
    pub diagnostics_surface_copy_digest_required: bool,
    pub route_explanation_digest_required: bool,
    pub rejected_candidate_summary_digest_required: bool,
    pub user_action_required_digest_required: bool,
    pub no_toggle_unlock_digest_required: bool,
    pub no_quality_claim_digest_required: bool,
    pub no_live_default_claim_digest_required: bool,
    pub no_large_model_bypass_digest_required: bool,
    pub no_l2_l3_t4_claim_digest_required: bool,
    pub future_visibility_packet_present: bool,
    pub future_visibility_packet_bytes_read: u64,
    pub answer_packet_emitted_to_user_count: u64,
    pub system_g_route_visibility_performed_count: u64,
    pub admission_performed_count: u64,
    pub route_priority_mutation_count: u64,
    pub runtime_router_mutation_allowed: bool,
    pub system_g_mutation_allowed: bool,
    pub default_model_mutation_allowed: bool,
    pub settings_toggle_unlock_allowed: bool,
    pub diagnostics_live_route_claimed: bool,
    pub model_picker_default_mutation_allowed: bool,
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
    pub status: GemmaQatE2bSettingsDiagnosticsWrvGateStatus,
    pub next_cursor: String,
}

impl GemmaQatE2bSettingsDiagnosticsWrvGate {
    pub fn canonical(upstream_route_answer_packet_visibility_ref: impl Into<String>) -> Self {
        Self {
            upstream_route_answer_packet_visibility_ref:
                upstream_route_answer_packet_visibility_ref.into(),
            upstream_route_answer_packet_visibility_id:
                GEMMA_QAT_E2B_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_ID.to_string(),
            upstream_admission_packet_ref:
                GEMMA_QAT_E2B_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_UPSTREAM_REF.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            visibility_card_id: VISIBILITY_CARD_ID.to_string(),
            future_visibility_packet_name: FUTURE_VISIBILITY_PACKET_NAME.to_string(),
            selected_model_id: GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID.to_string(),
            source_revision: GEMMA_QAT_E2B_SOURCE_REVISION.to_string(),
            required_filename: GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME.to_string(),
            expected_file_size_bytes: GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
            runtime_lane: GemmaFamilyRuntimeLane::GgufLlamaCpp,
            command_path: GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_visibility_fields: REQUIRED_VISIBILITY_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            upstream_route_answer_packet_visibility_digest_required: true,
            settings_source_marker_digest_required: true,
            diagnostics_source_marker_digest_required: true,
            wrv_test_marker_digest_required: true,
            manual_check_plan_digest_required: true,
            release_audit_link_digest_required: true,
            answer_packet_template_digest_required: true,
            visible_model_identity_required: true,
            visible_runtime_lane_required: true,
            visible_route_status_required: true,
            visible_route_caveat_required: true,
            visible_budget_summary_required: true,
            visible_memory_headroom_required: true,
            visible_kv_budget_required: true,
            visible_latency_budget_required: true,
            visible_privacy_class_required: true,
            visible_mas_pro_boundary_required: true,
            visible_scope_rex_ref: "scope_rex:gemma_e2b_settings_diagnostics_wrv_gate".to_string(),
            visible_sovereign_gate_ref: "sovereign_gate:gemma_e2b_settings_diagnostics_wrv_gate"
                .to_string(),
            visible_fallback_ref: "fallback:gemma_e2b_visibility_abstain_to_current_local_lane"
                .to_string(),
            visible_abstention_ref: "abstention:gemma_e2b_route_visibility_not_product".to_string(),
            visible_cancellation_ref: "cancel:gemma_e2b_settings_diagnostics_wrv_gate".to_string(),
            visible_rollback_ref: "rollback:gemma_e2b_settings_diagnostics_wrv_gate".to_string(),
            visible_run_event_log_ref: "run_event_log:gemma_e2b_settings_diagnostics_wrv_gate"
                .to_string(),
            visible_no_default_model_mutation_required: true,
            visible_no_hidden_authority_required: true,
            visible_non_promotion_required: true,
            settings_surface_copy_digest_required: true,
            diagnostics_surface_copy_digest_required: true,
            route_explanation_digest_required: true,
            rejected_candidate_summary_digest_required: true,
            user_action_required_digest_required: true,
            no_toggle_unlock_digest_required: true,
            no_quality_claim_digest_required: true,
            no_live_default_claim_digest_required: true,
            no_large_model_bypass_digest_required: true,
            no_l2_l3_t4_claim_digest_required: true,
            future_visibility_packet_present: false,
            future_visibility_packet_bytes_read: 0,
            answer_packet_emitted_to_user_count: 0,
            system_g_route_visibility_performed_count: 0,
            admission_performed_count: 0,
            route_priority_mutation_count: 0,
            runtime_router_mutation_allowed: false,
            system_g_mutation_allowed: false,
            default_model_mutation_allowed: false,
            settings_toggle_unlock_allowed: false,
            diagnostics_live_route_claimed: false,
            model_picker_default_mutation_allowed: false,
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
            metadata_bytes: 224_000,
            status: GemmaQatE2bSettingsDiagnosticsWrvGateStatus::SettingsDiagnosticsWrvContractOnly,
            next_cursor: GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaQatE2bSettingsDiagnosticsWrvGateError> {
        if !self
            .upstream_route_answer_packet_visibility_ref
            .starts_with(UPSTREAM_ROUTE_ANSWER_PACKET_VISIBILITY_PREFIX)
            || self.upstream_route_answer_packet_visibility_id
                != GEMMA_QAT_E2B_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_ID
        {
            return Err(GemmaQatE2bSettingsDiagnosticsWrvGateError::BadUpstreamRef);
        }
        validate_exact(
            "upstream_admission_packet_ref",
            &self.upstream_admission_packet_ref,
            GEMMA_QAT_E2B_ROUTE_ANSWER_PACKET_VISIBILITY_GATE_UPSTREAM_REF,
        )?;
        validate_exact(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact(
            "visibility_card_id",
            &self.visibility_card_id,
            VISIBILITY_CARD_ID,
        )?;
        validate_exact(
            "future_visibility_packet_name",
            &self.future_visibility_packet_name,
            FUTURE_VISIBILITY_PACKET_NAME,
        )?;
        validate_unique_exact_set(
            "required_visibility_fields",
            &self.required_visibility_fields,
            REQUIRED_VISIBILITY_FIELDS,
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
            return Err(GemmaQatE2bSettingsDiagnosticsWrvGateError::BadSelectedLane);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaQatE2bSettingsDiagnosticsWrvGateStatus::SettingsDiagnosticsWrvContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaQatE2bSettingsDiagnosticsWrvGateError::UnsafeState);
        }
        if !self.upstream_route_answer_packet_visibility_digest_required
            || !self.settings_source_marker_digest_required
            || !self.diagnostics_source_marker_digest_required
            || !self.wrv_test_marker_digest_required
            || !self.manual_check_plan_digest_required
            || !self.release_audit_link_digest_required
            || !self.answer_packet_template_digest_required
            || !self.visible_model_identity_required
            || !self.visible_runtime_lane_required
            || !self.visible_route_status_required
            || !self.visible_route_caveat_required
            || !self.visible_budget_summary_required
            || !self.visible_memory_headroom_required
            || !self.visible_kv_budget_required
            || !self.visible_latency_budget_required
            || !self.visible_privacy_class_required
            || !self.visible_mas_pro_boundary_required
            || !self.visible_no_default_model_mutation_required
            || !self.visible_no_hidden_authority_required
            || !self.visible_non_promotion_required
            || !self.settings_surface_copy_digest_required
            || !self.diagnostics_surface_copy_digest_required
            || !self.route_explanation_digest_required
            || !self.rejected_candidate_summary_digest_required
            || !self.user_action_required_digest_required
            || !self.no_toggle_unlock_digest_required
            || !self.no_quality_claim_digest_required
            || !self.no_live_default_claim_digest_required
            || !self.no_large_model_bypass_digest_required
            || !self.no_l2_l3_t4_claim_digest_required
        {
            return Err(GemmaQatE2bSettingsDiagnosticsWrvGateError::ProofBoundaryBroken);
        }
        validate_prefix(
            "visible_scope_rex_ref",
            &self.visible_scope_rex_ref,
            SCOPE_REX_PREFIX,
        )?;
        validate_prefix(
            "visible_sovereign_gate_ref",
            &self.visible_sovereign_gate_ref,
            SOVEREIGN_GATE_PREFIX,
        )?;
        validate_prefix(
            "visible_fallback_ref",
            &self.visible_fallback_ref,
            "fallback:",
        )?;
        validate_prefix(
            "visible_abstention_ref",
            &self.visible_abstention_ref,
            ABSTENTION_PREFIX,
        )?;
        validate_prefix(
            "visible_cancellation_ref",
            &self.visible_cancellation_ref,
            "cancel:",
        )?;
        validate_prefix(
            "visible_rollback_ref",
            &self.visible_rollback_ref,
            ROLLBACK_PREFIX,
        )?;
        validate_prefix(
            "visible_run_event_log_ref",
            &self.visible_run_event_log_ref,
            RUN_EVENT_LOG_PREFIX,
        )?;
        if self.future_visibility_packet_present
            || self.future_visibility_packet_bytes_read != 0
            || self.answer_packet_emitted_to_user_count != 0
            || self.system_g_route_visibility_performed_count != 0
            || self.admission_performed_count != 0
            || self.route_priority_mutation_count != 0
            || self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.default_model_mutation_allowed
            || self.settings_toggle_unlock_allowed
            || self.diagnostics_live_route_claimed
            || self.model_picker_default_mutation_allowed
        {
            return Err(GemmaQatE2bSettingsDiagnosticsWrvGateError::VisibilityActionLeak);
        }
        if self.command_armed
            || self.command_executed
            || self.runtime_replay_performed
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaQatE2bSettingsDiagnosticsWrvGateError::RuntimeActionLeak);
        }
        if self.raw_prompt_bytes_captured != 0
            || self.raw_output_bytes_captured != 0
            || self.answer_packet_suppressed
        {
            return Err(GemmaQatE2bSettingsDiagnosticsWrvGateError::PrivacyLeak);
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
            return Err(GemmaQatE2bSettingsDiagnosticsWrvGateError::PromotionClaim);
        }
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatE2bSettingsDiagnosticsWrvGateMetrics {
        GemmaQatE2bSettingsDiagnosticsWrvGateMetrics {
            required_visibility_field_count: self.required_visibility_fields.len() as u64,
            required_rejection_policy_count: self.required_rejection_policies.len() as u64,
            future_visibility_packet_present_count: self.future_visibility_packet_present as u64,
            future_visibility_packet_bytes_read: self.future_visibility_packet_bytes_read,
            answer_packet_emitted_to_user_count: self.answer_packet_emitted_to_user_count,
            system_g_route_visibility_performed_count: self
                .system_g_route_visibility_performed_count,
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
                + self.default_model_mutation_allowed as u64
                + self.settings_toggle_unlock_allowed as u64
                + self.diagnostics_live_route_claimed as u64
                + self.model_picker_default_mutation_allowed as u64,
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

    pub fn visibility_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_CURSOR.to_string()),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_visibility_fields.clone();
        fields.sort();
        let mut policies = self.required_rejection_policies.clone();
        policies.sort();
        format!(
            "gemma-e2b-settings-diagnostics-wrv-gate:v1:{}:{}:{}:{}:{}:{}:{}:{}",
            self.upstream_route_answer_packet_visibility_ref,
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

// UAS: uas:gemma-qat-e2b-settings-diagnostics-wrv-gate:metrics
// Plane: Verification.
// Residency: zero-action counters for visibility and route proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bSettingsDiagnosticsWrvGateMetrics {
    pub required_visibility_field_count: u64,
    pub required_rejection_policy_count: u64,
    pub future_visibility_packet_present_count: u64,
    pub future_visibility_packet_bytes_read: u64,
    pub answer_packet_emitted_to_user_count: u64,
    pub system_g_route_visibility_performed_count: u64,
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

pub fn required_gemma_qat_e2b_settings_diagnostics_wrv_fields() -> Vec<String> {
    REQUIRED_VISIBILITY_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_qat_e2b_settings_diagnostics_wrv_rejection_policies() -> Vec<String> {
    REQUIRED_REJECTION_POLICIES
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-qat-e2b-settings-diagnostics-wrv-gate:error
// Plane: Verification.
// Residency: fail-closed diagnostics only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatE2bSettingsDiagnosticsWrvGateError {
    BadUpstreamRef,
    BadSelectedLane,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    ProofBoundaryBroken,
    VisibilityActionLeak,
    RuntimeActionLeak,
    PrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaQatE2bSettingsDiagnosticsWrvGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => {
                f.write_str("bad upstream route AnswerPacket visibility packet reference")
            }
            Self::BadSelectedLane => f.write_str("bad selected E2B visibility lane"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe visibility packet gate state"),
            Self::ProofBoundaryBroken => f.write_str("proof boundary broken"),
            Self::VisibilityActionLeak => f.write_str("visibility, route, or dry-run action leak"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::PrivacyLeak => f.write_str("privacy or AnswerPacket visibility leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaQatE2bSettingsDiagnosticsWrvGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaQatE2bSettingsDiagnosticsWrvGateError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaQatE2bSettingsDiagnosticsWrvGateError::DuplicateOrMissingField(field_name),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaQatE2bSettingsDiagnosticsWrvGateError::DuplicateOrMissingField(field_name),
        );
    }
    Ok(())
}

fn validate_prefix(
    field_name: &'static str,
    actual: &str,
    expected_prefix: &str,
) -> Result<(), GemmaQatE2bSettingsDiagnosticsWrvGateError> {
    if actual.starts_with(expected_prefix) {
        Ok(())
    } else {
        Err(GemmaQatE2bSettingsDiagnosticsWrvGateError::BadField(
            field_name,
        ))
    }
}

fn validate_exact(
    field_name: &'static str,
    actual: &str,
    expected: &str,
) -> Result<(), GemmaQatE2bSettingsDiagnosticsWrvGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaQatE2bSettingsDiagnosticsWrvGateError::BadField(
            field_name,
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_582_000_000;

    #[test]
    fn canonical_visibility_gate_validates_zero_actions() {
        let gate = GemmaQatE2bSettingsDiagnosticsWrvGate::canonical(
            GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_UPSTREAM_REF,
        );
        gate.validate()
            .expect("canonical settings diagnostics WRV gate should validate");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_visibility_field_count, 34);
        assert_eq!(metrics.required_rejection_policy_count, 69);
        assert_eq!(metrics.future_visibility_packet_bytes_read, 0);
        assert_eq!(metrics.answer_packet_emitted_to_user_count, 0);
        assert_eq!(metrics.system_g_route_visibility_performed_count, 0);
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
        let mut gate = GemmaQatE2bSettingsDiagnosticsWrvGate::canonical(
            GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_UPSTREAM_REF,
        );
        gate.required_visibility_fields.pop();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaQatE2bSettingsDiagnosticsWrvGateError::DuplicateOrMissingField(
                    "required_visibility_fields"
                )
            )
        ));
    }

    #[test]
    fn user_visible_packet_and_route_mutation_are_rejected() {
        let mut gate = GemmaQatE2bSettingsDiagnosticsWrvGate::canonical(
            GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_UPSTREAM_REF,
        );
        gate.answer_packet_emitted_to_user_count = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bSettingsDiagnosticsWrvGateError::VisibilityActionLeak)
        ));
        let mut gate = GemmaQatE2bSettingsDiagnosticsWrvGate::canonical(
            GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_UPSTREAM_REF,
        );
        gate.runtime_router_mutation_allowed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bSettingsDiagnosticsWrvGateError::VisibilityActionLeak)
        ));
    }

    #[test]
    fn runtime_execution_and_promotion_are_rejected() {
        let mut gate = GemmaQatE2bSettingsDiagnosticsWrvGate::canonical(
            GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_UPSTREAM_REF,
        );
        gate.command_executed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bSettingsDiagnosticsWrvGateError::RuntimeActionLeak)
        ));
        let mut gate = GemmaQatE2bSettingsDiagnosticsWrvGate::canonical(
            GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_UPSTREAM_REF,
        );
        gate.l3_wrv_effect = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bSettingsDiagnosticsWrvGateError::PromotionClaim)
        ));
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let gate = GemmaQatE2bSettingsDiagnosticsWrvGate::canonical(
            GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_UPSTREAM_REF,
        );
        let reversed = GemmaQatE2bSettingsDiagnosticsWrvGate {
            required_visibility_fields: gate
                .required_visibility_fields
                .iter()
                .cloned()
                .rev()
                .collect(),
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
            gate.visibility_gate_address(CREATED_AT_MS),
            reversed.visibility_gate_address(CREATED_AT_MS)
        );
    }
}
