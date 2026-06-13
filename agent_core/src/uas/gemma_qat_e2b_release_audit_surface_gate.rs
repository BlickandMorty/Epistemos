//! Gemma QAT E2B release-audit surface gate.
//!
//! This primitive consumes the E2B settings/diagnostics WRV gate and defines
//! the fail-closed release-audit surface required before a future Gemma row can
//! become a product route. It is metadata-only: no Xcode command runs, no
//! settings row is wired, no route/default state mutates, and no model/runtime
//! bytes are opened.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    GemmaFamilyRuntimeLane, ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_QAT_E2B_EXPECTED_FILE_BYTES, GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_ID,
    GEMMA_QAT_E2B_SOURCE_REVISION, GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH,
    GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME, GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID,
};

pub const GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_ID: &str =
    "F-GemmaQATE2BReleaseAuditSurfaceGate";
pub const GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_CURSOR: &str =
    "gemma_qat_e2b_release_audit_surface_gate";
pub const GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_NEXT_CURSOR: &str =
    "gemma_qat_e2b_product_capability_recheck_gate";
pub const GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_UPSTREAM_REF: &str = "artifact:falsifiers/gemma_qat_e2b_settings_diagnostics_wrv_gate/result.json#F-GemmaQATE2BSettingsDiagnosticsWRVGate";

const UPSTREAM_SETTINGS_DIAGNOSTICS_WRV_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_e2b_settings_diagnostics_wrv_gate/";
const ARTIFACT_ROOT_PREFIX: &str = "artifacts/falsifiers/gemma_qat_e2b_release_audit_surface_gate/";
const RELEASE_SURFACE_CARD_ID: &str = "gemma-e2b-gguf-release-audit-surface-gate";
const FUTURE_RELEASE_PACKET_NAME: &str = "gemma-e2b-gguf-release-audit-surface-v1";
const RELEASE_AUDIT_SKILL_REF: &str = ".agents/skills/epistemos_release_audit/SKILL.md";
const PRODUCT_BLOCKER_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";
const GRAPH_FILTER_PROOF_ROOT_COMMAND_CARD: &str =
    "F-GraphFilterVisibilityFocusedProofRootCommandCard";
const GRAPH_FILTER_PROOF_ROOT_EXECUTION_ARTIFACT_GATE: &str =
    "F-GraphFilterVisibilityFocusedProofRootExecutionArtifactGate";
const OWNER_APPROVAL_RUNBOOK: &str =
    "docs/audits/FOCUSED_PROOF_ROOT_OWNER_APPROVAL_RUNBOOK_2026_06_08.md";
const MAX_METADATA_BYTES: u64 = 448 * 1024;

const REQUIRED_RELEASE_SURFACE_FIELDS: &[&str] = &[
    "upstream_settings_diagnostics_wrv_digest",
    "release_audit_skill_ref",
    "release_completion_blocker_ref",
    "focused_proof_root_command_card_ref",
    "focused_proof_root_execution_artifact_gate_ref",
    "owner_approval_runbook_ref",
    "log_correlation_evidence_ref",
    "manual_runtime_verification_ref",
    "distribution_compliance_evidence_ref",
    "repeated_zero_fail_evidence_ref",
    "settings_visible_copy_digest",
    "diagnostics_visible_copy_digest",
    "answer_packet_template_digest",
    "run_event_log_digest",
    "rollback_digest",
    "abstention_digest",
    "scope_rex_digest",
    "sovereign_gate_digest",
    "cancellation_digest",
    "non_promotion_digest",
    "no_toggle_unlock_digest",
    "no_default_model_mutation_digest",
    "no_runtime_route_admission_digest",
    "no_xcode_execution_digest",
    "no_model_bytes_digest",
    "no_command_armed_digest",
    "no_raw_prompt_output_digest",
    "no_hidden_authority_digest",
    "no_cloud_fallback_digest",
    "no_mas_promotion_digest",
    "no_l2_l3_t4_digest",
    "no_quality_claim_digest",
    "no_benchmark_fit_digest",
    "no_e4b_12b_bypass_digest",
    "no_live_70b_digest",
    "no_ssd_as_ram_digest",
    "owner_action_required_digest",
    "product_capability_recheck_deferred_digest",
    "fast_row_gated_visibility_digest",
    "release_surface_packet_digest",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_settings_diagnostics_wrv",
    "settings_diagnostics_wrv_digest_mismatch",
    "missing_release_audit_skill_ref",
    "missing_release_completion_blocker_ref",
    "missing_focused_proof_root_command_card_ref",
    "missing_focused_proof_root_execution_artifact_gate_ref",
    "missing_owner_approval_runbook_ref",
    "missing_log_correlation_evidence",
    "missing_manual_runtime_verification",
    "missing_distribution_compliance_evidence",
    "missing_repeated_zero_fail_evidence",
    "missing_settings_visible_copy",
    "missing_diagnostics_visible_copy",
    "missing_answer_packet_template",
    "missing_run_event_log",
    "missing_rollback",
    "missing_abstention",
    "missing_scope_rex",
    "missing_sovereign_gate",
    "missing_cancellation",
    "missing_non_promotion",
    "missing_no_toggle_unlock",
    "missing_no_default_model_mutation",
    "missing_no_runtime_route_admission",
    "missing_no_xcode_execution",
    "missing_no_model_bytes",
    "missing_no_command_armed",
    "missing_no_raw_prompt_output",
    "missing_no_hidden_authority",
    "missing_no_cloud_fallback",
    "missing_no_mas_promotion",
    "missing_no_l2_l3_t4",
    "missing_no_quality_claim",
    "missing_no_benchmark_fit",
    "missing_no_e4b_12b_bypass",
    "missing_no_live_70b",
    "missing_no_ssd_as_ram",
    "missing_owner_action_required",
    "missing_product_capability_recheck_deferred",
    "missing_fast_row_gated_visibility",
    "missing_release_surface_packet_digest",
    "bad_selected_model",
    "bad_runtime_lane",
    "future_release_packet_present",
    "future_release_packet_bytes_read",
    "settings_row_wired",
    "diagnostics_ui_wired",
    "user_visible_answer_packet_emitted",
    "runtime_router_mutated",
    "system_g_mutated",
    "default_model_mutated",
    "route_admitted",
    "xcode_command_executed",
    "model_command_armed",
    "model_command_executed",
    "model_bytes_loaded",
    "runtime_bytes_loaded",
    "provider_calls_made",
    "raw_prompt_retained",
    "raw_output_retained",
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

// UAS: uas:gemma-qat-e2b-release-audit-surface-gate:status
// Plane: Verification.
// Residency: metadata-only release surface status; no release packet read.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatE2bReleaseAuditSurfaceGateStatus {
    ReleaseAuditSurfaceContractOnly,
}

// UAS: uas:gemma-qat-e2b-release-audit-surface-gate:spec
// Plane: Controller + Verification.
// Residency: future release-audit contract only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bReleaseAuditSurfaceGate {
    pub upstream_settings_diagnostics_wrv_ref: String,
    pub upstream_settings_diagnostics_wrv_id: String,
    pub artifact_root_prefix: String,
    pub release_surface_card_id: String,
    pub future_release_packet_name: String,
    pub selected_model_id: String,
    pub source_revision: String,
    pub required_filename: String,
    pub expected_file_size_bytes: u64,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub command_path: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub release_audit_skill_ref: String,
    pub release_completion_blocker_ref: String,
    pub focused_proof_root_command_card_ref: String,
    pub focused_proof_root_execution_artifact_gate_ref: String,
    pub owner_approval_runbook_ref: String,
    pub required_release_surface_fields: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub upstream_settings_diagnostics_wrv_digest_required: bool,
    pub log_correlation_evidence_required: bool,
    pub manual_runtime_verification_required: bool,
    pub distribution_compliance_evidence_required: bool,
    pub repeated_zero_fail_evidence_required: bool,
    pub settings_visible_copy_digest_required: bool,
    pub diagnostics_visible_copy_digest_required: bool,
    pub answer_packet_template_digest_required: bool,
    pub run_event_log_digest_required: bool,
    pub rollback_digest_required: bool,
    pub abstention_digest_required: bool,
    pub scope_rex_digest_required: bool,
    pub sovereign_gate_digest_required: bool,
    pub cancellation_digest_required: bool,
    pub non_promotion_digest_required: bool,
    pub no_toggle_unlock_digest_required: bool,
    pub no_default_model_mutation_digest_required: bool,
    pub no_runtime_route_admission_digest_required: bool,
    pub no_xcode_execution_digest_required: bool,
    pub no_model_bytes_digest_required: bool,
    pub no_command_armed_digest_required: bool,
    pub no_raw_prompt_output_digest_required: bool,
    pub no_hidden_authority_digest_required: bool,
    pub no_cloud_fallback_digest_required: bool,
    pub no_mas_promotion_digest_required: bool,
    pub no_l2_l3_t4_digest_required: bool,
    pub no_quality_claim_digest_required: bool,
    pub no_benchmark_fit_digest_required: bool,
    pub no_e4b_12b_bypass_digest_required: bool,
    pub no_live_70b_digest_required: bool,
    pub no_ssd_as_ram_digest_required: bool,
    pub owner_action_required_digest_required: bool,
    pub product_capability_recheck_deferred_digest_required: bool,
    pub fast_row_gated_visibility_digest_required: bool,
    pub release_surface_packet_digest_required: bool,
    pub future_release_packet_present: bool,
    pub future_release_packet_bytes_read: u64,
    pub settings_row_wired: bool,
    pub diagnostics_ui_wired: bool,
    pub user_visible_answer_packet_emitted_count: u64,
    pub runtime_router_mutation_allowed: bool,
    pub system_g_mutation_allowed: bool,
    pub default_model_mutation_allowed: bool,
    pub route_admitted: bool,
    pub xcode_command_executed: bool,
    pub model_command_armed: bool,
    pub model_command_executed: bool,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_prompt_bytes_captured: u64,
    pub raw_output_bytes_captured: u64,
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
    pub status: GemmaQatE2bReleaseAuditSurfaceGateStatus,
    pub next_cursor: String,
}

impl GemmaQatE2bReleaseAuditSurfaceGate {
    pub fn canonical(upstream_settings_diagnostics_wrv_ref: impl Into<String>) -> Self {
        Self {
            upstream_settings_diagnostics_wrv_ref: upstream_settings_diagnostics_wrv_ref.into(),
            upstream_settings_diagnostics_wrv_id: GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_ID
                .to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            release_surface_card_id: RELEASE_SURFACE_CARD_ID.to_string(),
            future_release_packet_name: FUTURE_RELEASE_PACKET_NAME.to_string(),
            selected_model_id: GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID.to_string(),
            source_revision: GEMMA_QAT_E2B_SOURCE_REVISION.to_string(),
            required_filename: GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME.to_string(),
            expected_file_size_bytes: GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
            runtime_lane: GemmaFamilyRuntimeLane::GgufLlamaCpp,
            command_path: GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            release_audit_skill_ref: RELEASE_AUDIT_SKILL_REF.to_string(),
            release_completion_blocker_ref: PRODUCT_BLOCKER_CURSOR.to_string(),
            focused_proof_root_command_card_ref: GRAPH_FILTER_PROOF_ROOT_COMMAND_CARD.to_string(),
            focused_proof_root_execution_artifact_gate_ref:
                GRAPH_FILTER_PROOF_ROOT_EXECUTION_ARTIFACT_GATE.to_string(),
            owner_approval_runbook_ref: OWNER_APPROVAL_RUNBOOK.to_string(),
            required_release_surface_fields: REQUIRED_RELEASE_SURFACE_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            upstream_settings_diagnostics_wrv_digest_required: true,
            log_correlation_evidence_required: true,
            manual_runtime_verification_required: true,
            distribution_compliance_evidence_required: true,
            repeated_zero_fail_evidence_required: true,
            settings_visible_copy_digest_required: true,
            diagnostics_visible_copy_digest_required: true,
            answer_packet_template_digest_required: true,
            run_event_log_digest_required: true,
            rollback_digest_required: true,
            abstention_digest_required: true,
            scope_rex_digest_required: true,
            sovereign_gate_digest_required: true,
            cancellation_digest_required: true,
            non_promotion_digest_required: true,
            no_toggle_unlock_digest_required: true,
            no_default_model_mutation_digest_required: true,
            no_runtime_route_admission_digest_required: true,
            no_xcode_execution_digest_required: true,
            no_model_bytes_digest_required: true,
            no_command_armed_digest_required: true,
            no_raw_prompt_output_digest_required: true,
            no_hidden_authority_digest_required: true,
            no_cloud_fallback_digest_required: true,
            no_mas_promotion_digest_required: true,
            no_l2_l3_t4_digest_required: true,
            no_quality_claim_digest_required: true,
            no_benchmark_fit_digest_required: true,
            no_e4b_12b_bypass_digest_required: true,
            no_live_70b_digest_required: true,
            no_ssd_as_ram_digest_required: true,
            owner_action_required_digest_required: true,
            product_capability_recheck_deferred_digest_required: true,
            fast_row_gated_visibility_digest_required: true,
            release_surface_packet_digest_required: true,
            future_release_packet_present: false,
            future_release_packet_bytes_read: 0,
            settings_row_wired: false,
            diagnostics_ui_wired: false,
            user_visible_answer_packet_emitted_count: 0,
            runtime_router_mutation_allowed: false,
            system_g_mutation_allowed: false,
            default_model_mutation_allowed: false,
            route_admitted: false,
            xcode_command_executed: false,
            model_command_armed: false,
            model_command_executed: false,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            raw_prompt_bytes_captured: 0,
            raw_output_bytes_captured: 0,
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
            metadata_bytes: 256_000,
            status: GemmaQatE2bReleaseAuditSurfaceGateStatus::ReleaseAuditSurfaceContractOnly,
            next_cursor: GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaQatE2bReleaseAuditSurfaceGateError> {
        if !self
            .upstream_settings_diagnostics_wrv_ref
            .starts_with(UPSTREAM_SETTINGS_DIAGNOSTICS_WRV_PREFIX)
            || self.upstream_settings_diagnostics_wrv_id
                != GEMMA_QAT_E2B_SETTINGS_DIAGNOSTICS_WRV_GATE_ID
        {
            return Err(GemmaQatE2bReleaseAuditSurfaceGateError::BadUpstreamRef);
        }
        validate_exact(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact(
            "release_surface_card_id",
            &self.release_surface_card_id,
            RELEASE_SURFACE_CARD_ID,
        )?;
        validate_exact(
            "future_release_packet_name",
            &self.future_release_packet_name,
            FUTURE_RELEASE_PACKET_NAME,
        )?;
        validate_exact(
            "release_audit_skill_ref",
            &self.release_audit_skill_ref,
            RELEASE_AUDIT_SKILL_REF,
        )?;
        validate_exact(
            "release_completion_blocker_ref",
            &self.release_completion_blocker_ref,
            PRODUCT_BLOCKER_CURSOR,
        )?;
        validate_exact(
            "focused_proof_root_command_card_ref",
            &self.focused_proof_root_command_card_ref,
            GRAPH_FILTER_PROOF_ROOT_COMMAND_CARD,
        )?;
        validate_exact(
            "focused_proof_root_execution_artifact_gate_ref",
            &self.focused_proof_root_execution_artifact_gate_ref,
            GRAPH_FILTER_PROOF_ROOT_EXECUTION_ARTIFACT_GATE,
        )?;
        validate_exact(
            "owner_approval_runbook_ref",
            &self.owner_approval_runbook_ref,
            OWNER_APPROVAL_RUNBOOK,
        )?;
        validate_unique_exact_set(
            "required_release_surface_fields",
            &self.required_release_surface_fields,
            REQUIRED_RELEASE_SURFACE_FIELDS,
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
            return Err(GemmaQatE2bReleaseAuditSurfaceGateError::BadSelectedLane);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaQatE2bReleaseAuditSurfaceGateStatus::ReleaseAuditSurfaceContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaQatE2bReleaseAuditSurfaceGateError::UnsafeState);
        }
        if !self.upstream_settings_diagnostics_wrv_digest_required
            || !self.log_correlation_evidence_required
            || !self.manual_runtime_verification_required
            || !self.distribution_compliance_evidence_required
            || !self.repeated_zero_fail_evidence_required
            || !self.settings_visible_copy_digest_required
            || !self.diagnostics_visible_copy_digest_required
            || !self.answer_packet_template_digest_required
            || !self.run_event_log_digest_required
            || !self.rollback_digest_required
            || !self.abstention_digest_required
            || !self.scope_rex_digest_required
            || !self.sovereign_gate_digest_required
            || !self.cancellation_digest_required
            || !self.non_promotion_digest_required
            || !self.no_toggle_unlock_digest_required
            || !self.no_default_model_mutation_digest_required
            || !self.no_runtime_route_admission_digest_required
            || !self.no_xcode_execution_digest_required
            || !self.no_model_bytes_digest_required
            || !self.no_command_armed_digest_required
            || !self.no_raw_prompt_output_digest_required
            || !self.no_hidden_authority_digest_required
            || !self.no_cloud_fallback_digest_required
            || !self.no_mas_promotion_digest_required
            || !self.no_l2_l3_t4_digest_required
            || !self.no_quality_claim_digest_required
            || !self.no_benchmark_fit_digest_required
            || !self.no_e4b_12b_bypass_digest_required
            || !self.no_live_70b_digest_required
            || !self.no_ssd_as_ram_digest_required
            || !self.owner_action_required_digest_required
            || !self.product_capability_recheck_deferred_digest_required
            || !self.fast_row_gated_visibility_digest_required
            || !self.release_surface_packet_digest_required
        {
            return Err(GemmaQatE2bReleaseAuditSurfaceGateError::ProofBoundaryBroken);
        }
        if self.future_release_packet_present
            || self.future_release_packet_bytes_read != 0
            || self.settings_row_wired
            || self.diagnostics_ui_wired
            || self.user_visible_answer_packet_emitted_count != 0
            || self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.default_model_mutation_allowed
            || self.route_admitted
            || self.xcode_command_executed
        {
            return Err(GemmaQatE2bReleaseAuditSurfaceGateError::ReleaseSurfaceActionLeak);
        }
        if self.model_command_armed
            || self.model_command_executed
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaQatE2bReleaseAuditSurfaceGateError::RuntimeActionLeak);
        }
        if self.raw_prompt_bytes_captured != 0 || self.raw_output_bytes_captured != 0 {
            return Err(GemmaQatE2bReleaseAuditSurfaceGateError::PrivacyLeak);
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
            return Err(GemmaQatE2bReleaseAuditSurfaceGateError::PromotionClaim);
        }
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatE2bReleaseAuditSurfaceGateMetrics {
        GemmaQatE2bReleaseAuditSurfaceGateMetrics {
            required_release_surface_field_count: self.required_release_surface_fields.len() as u64,
            required_rejection_policy_count: self.required_rejection_policies.len() as u64,
            future_release_packet_present_count: self.future_release_packet_present as u64,
            future_release_packet_bytes_read: self.future_release_packet_bytes_read,
            settings_row_wired_count: self.settings_row_wired as u64,
            diagnostics_ui_wired_count: self.diagnostics_ui_wired as u64,
            user_visible_answer_packet_emitted_count: self.user_visible_answer_packet_emitted_count,
            release_surface_action_count: self.runtime_router_mutation_allowed as u64
                + self.system_g_mutation_allowed as u64
                + self.default_model_mutation_allowed as u64
                + self.route_admitted as u64
                + self.xcode_command_executed as u64,
            model_command_armed_count: self.model_command_armed as u64,
            model_command_executed_count: self.model_command_executed as u64,
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
            raw_prompt_bytes_captured: self.raw_prompt_bytes_captured,
            raw_output_bytes_captured: self.raw_output_bytes_captured,
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

    pub fn release_surface_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_CURSOR.to_string()),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_release_surface_fields.clone();
        fields.sort();
        let mut policies = self.required_rejection_policies.clone();
        policies.sort();
        format!(
            "gemma-e2b-release-audit-surface-gate:v1:{}:{}:{}:{}:{}:{}:{}:{}",
            self.upstream_settings_diagnostics_wrv_ref,
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

// UAS: uas:gemma-qat-e2b-release-audit-surface-gate:metrics
// Plane: Verification.
// Residency: zero-action counters for release and runtime proof.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bReleaseAuditSurfaceGateMetrics {
    pub required_release_surface_field_count: u64,
    pub required_rejection_policy_count: u64,
    pub future_release_packet_present_count: u64,
    pub future_release_packet_bytes_read: u64,
    pub settings_row_wired_count: u64,
    pub diagnostics_ui_wired_count: u64,
    pub user_visible_answer_packet_emitted_count: u64,
    pub release_surface_action_count: u64,
    pub model_command_armed_count: u64,
    pub model_command_executed_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_prompt_bytes_captured: u64,
    pub raw_output_bytes_captured: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_qat_e2b_release_audit_surface_fields() -> Vec<String> {
    REQUIRED_RELEASE_SURFACE_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_qat_e2b_release_audit_surface_rejection_policies() -> Vec<String> {
    REQUIRED_REJECTION_POLICIES
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-qat-e2b-release-audit-surface-gate:error
// Plane: Verification.
// Residency: fail-closed diagnostics only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatE2bReleaseAuditSurfaceGateError {
    BadUpstreamRef,
    BadSelectedLane,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    ProofBoundaryBroken,
    ReleaseSurfaceActionLeak,
    RuntimeActionLeak,
    PrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaQatE2bReleaseAuditSurfaceGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream settings diagnostics WRV reference"),
            Self::BadSelectedLane => f.write_str("bad selected E2B release surface lane"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe release-audit surface state"),
            Self::ProofBoundaryBroken => f.write_str("proof boundary broken"),
            Self::ReleaseSurfaceActionLeak => f.write_str("release surface or product action leak"),
            Self::RuntimeActionLeak => f.write_str("runtime action leak"),
            Self::PrivacyLeak => f.write_str("privacy leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaQatE2bReleaseAuditSurfaceGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaQatE2bReleaseAuditSurfaceGateError> {
    if actual.len() != expected.len() {
        return Err(GemmaQatE2bReleaseAuditSurfaceGateError::DuplicateOrMissingField(field_name));
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(GemmaQatE2bReleaseAuditSurfaceGateError::DuplicateOrMissingField(field_name));
    }
    Ok(())
}

fn validate_exact(
    field_name: &'static str,
    actual: &str,
    expected: &str,
) -> Result<(), GemmaQatE2bReleaseAuditSurfaceGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaQatE2bReleaseAuditSurfaceGateError::BadField(
            field_name,
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_582_000_000;

    #[test]
    fn canonical_release_surface_validates_zero_actions() {
        let gate = GemmaQatE2bReleaseAuditSurfaceGate::canonical(
            GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_UPSTREAM_REF,
        );
        gate.validate()
            .expect("canonical release-audit surface gate should validate");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_release_surface_field_count, 40);
        assert_eq!(metrics.required_rejection_policy_count, 72);
        assert_eq!(metrics.future_release_packet_bytes_read, 0);
        assert_eq!(metrics.settings_row_wired_count, 0);
        assert_eq!(metrics.diagnostics_ui_wired_count, 0);
        assert_eq!(metrics.user_visible_answer_packet_emitted_count, 0);
        assert_eq!(metrics.release_surface_action_count, 0);
        assert_eq!(metrics.model_command_armed_count, 0);
        assert_eq!(metrics.model_command_executed_count, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn required_set_drift_is_rejected() {
        let mut gate = GemmaQatE2bReleaseAuditSurfaceGate::canonical(
            GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_UPSTREAM_REF,
        );
        gate.required_release_surface_fields.pop();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaQatE2bReleaseAuditSurfaceGateError::DuplicateOrMissingField(
                    "required_release_surface_fields"
                )
            )
        ));
    }

    #[test]
    fn settings_row_and_xcode_execution_are_rejected() {
        let mut gate = GemmaQatE2bReleaseAuditSurfaceGate::canonical(
            GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_UPSTREAM_REF,
        );
        gate.settings_row_wired = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bReleaseAuditSurfaceGateError::ReleaseSurfaceActionLeak)
        ));
        let mut gate = GemmaQatE2bReleaseAuditSurfaceGate::canonical(
            GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_UPSTREAM_REF,
        );
        gate.xcode_command_executed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bReleaseAuditSurfaceGateError::ReleaseSurfaceActionLeak)
        ));
    }

    #[test]
    fn runtime_execution_and_promotion_are_rejected() {
        let mut gate = GemmaQatE2bReleaseAuditSurfaceGate::canonical(
            GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_UPSTREAM_REF,
        );
        gate.model_command_executed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bReleaseAuditSurfaceGateError::RuntimeActionLeak)
        ));
        let mut gate = GemmaQatE2bReleaseAuditSurfaceGate::canonical(
            GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_UPSTREAM_REF,
        );
        gate.product_route_green = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bReleaseAuditSurfaceGateError::PromotionClaim)
        ));
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let gate = GemmaQatE2bReleaseAuditSurfaceGate::canonical(
            GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_UPSTREAM_REF,
        );
        let reversed = GemmaQatE2bReleaseAuditSurfaceGate {
            required_release_surface_fields: gate
                .required_release_surface_fields
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
            gate.release_surface_address(CREATED_AT_MS),
            reversed.release_surface_address(CREATED_AT_MS)
        );
    }
}
