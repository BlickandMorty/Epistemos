//! Gemma QAT E2B product capability recheck gate.
//!
//! This primitive consumes the E2B release-audit surface, release zero-fail
//! ledger, and first-runtime WRV packet. It is metadata-only: the correct
//! current outcome is "proof ladder ready, live route integration still
//! blocked", not product-green.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    GemmaFamilyRuntimeLane, ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_QAT_E2B_EXPECTED_FILE_BYTES, GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_ID,
    GEMMA_QAT_E2B_SOURCE_REVISION, GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH,
    GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME, GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID,
};

pub const GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_ID: &str =
    "F-GemmaQATE2BProductCapabilityRecheckGate";
pub const GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_CURSOR: &str =
    "gemma_qat_e2b_product_capability_recheck_gate";
pub const GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_NEXT_CURSOR: &str =
    "gemma_product_route_integration_gate";
pub const GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_UPSTREAM_REF: &str = "artifact:falsifiers/gemma_qat_e2b_release_audit_surface_gate/result.json#F-GemmaQATE2BReleaseAuditSurfaceGate";
pub const GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_ZERO_FAIL_LEDGER_REF: &str = "artifact:falsifiers/release_audit_zero_fail_pass_ledger/result.json#F-ReleaseAuditZeroFailPassLedger";
pub const GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_FIRST_RUNTIME_WRV_REF: &str = "artifact:falsifiers/gemma_direct_harness_first_runtime_settings_diagnostics_wrv/wrv.redacted.json#GemmaFirstRuntimeSettingsDiagnosticsWRV";

const UPSTREAM_RELEASE_AUDIT_SURFACE_PREFIX: &str =
    "artifact:falsifiers/gemma_qat_e2b_release_audit_surface_gate/";
const RELEASE_AUDIT_ZERO_FAIL_LEDGER_PREFIX: &str =
    "artifact:falsifiers/release_audit_zero_fail_pass_ledger/";
const FIRST_RUNTIME_WRV_PREFIX: &str =
    "artifact:falsifiers/gemma_direct_harness_first_runtime_settings_diagnostics_wrv/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_qat_e2b_product_capability_recheck_gate/";
const RELEASE_AUDIT_READY_CURSOR: &str = "gemma_product_capability_recheck_after_release_audit";
const FIRST_RUNTIME_WRV_RELEASE_CURSOR: &str =
    "release_audit_distribution_compliance_and_three_uninterrupted_zero_fail_passes";
const ROUTE_STATUS_BLOCKED: &str = "proof_ladder_ready_live_route_integration_pending";
const RECHECK_CARD_ID: &str = "gemma-e2b-gguf-product-capability-recheck-gate";
const MAX_METADATA_BYTES: u64 = 384 * 1024;

const REQUIRED_RECHECK_FIELDS: &[&str] = &[
    "upstream_release_audit_surface_digest",
    "release_audit_zero_fail_ledger_ref",
    "release_audit_zero_fail_count",
    "release_audit_remaining_zero_fail_count",
    "release_audit_completion_not_required",
    "release_audit_next_cursor",
    "first_runtime_wrv_ref",
    "first_runtime_wrv_passed",
    "first_runtime_selected_model_id",
    "first_runtime_release_cursor",
    "live_route_integration_pending",
    "live_route_default_mutation_zero",
    "live_route_runtime_router_mutation_zero",
    "live_route_system_g_mutation_zero",
    "settings_row_gated_only",
    "diagnostics_row_gated_only",
    "runtime_route_blocked",
    "default_model_blocked",
    "answer_packet_user_surface_blocked",
    "owner_action_required",
    "product_capability_recheck_result_blocked",
    "run_event_log_required",
    "rollback_required",
    "abstention_required",
    "scope_rex_required",
    "sovereign_gate_required",
    "cancellation_required",
    "no_xcode_execution",
    "no_model_command",
    "no_model_bytes",
    "no_runtime_bytes",
    "no_provider_calls",
    "no_raw_prompt_output",
    "no_hidden_authority",
    "no_l2_l3_t4_promotion",
    "no_quality_claim",
    "no_live_70b_or_ssd_ram_claim",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_release_surface",
    "release_surface_digest_mismatch",
    "missing_zero_fail_ledger",
    "zero_fail_ledger_red",
    "zero_fail_count_under_three",
    "remaining_zero_fail_nonzero",
    "release_completion_still_required",
    "wrong_release_next_cursor",
    "missing_first_runtime_wrv",
    "first_runtime_wrv_red",
    "wrong_first_runtime_model",
    "wrong_first_runtime_release_cursor",
    "live_route_integration_claimed_done",
    "default_model_mutated",
    "runtime_router_mutated",
    "system_g_mutated",
    "settings_row_unlocked",
    "diagnostics_row_unlocked",
    "runtime_route_unblocked",
    "default_model_unblocked",
    "answer_packet_user_surface_unblocked",
    "owner_action_not_required",
    "product_capability_recheck_green",
    "missing_run_event_log",
    "missing_rollback",
    "missing_abstention",
    "missing_scope_rex",
    "missing_sovereign_gate",
    "missing_cancellation",
    "xcode_executed",
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
    "mas_promotion",
    "l2_promotion",
    "l3_promotion",
    "t4_promotion",
    "product_route_green",
    "gemma_default_claim",
    "e4b_12b_or_70b_bypass",
    "quality_claim_before_runtime",
    "benchmark_claimed_as_fit",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-qat-e2b-product-capability-recheck-gate:status
// Plane: Verification.
// Residency: metadata-only product truth state; no model/runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaQatE2bProductCapabilityRecheckGateStatus {
    ProductCapabilityBlocked,
}

// UAS: uas:gemma-qat-e2b-product-capability-recheck-gate:card
// Plane: Controller + Verification.
// Residency: fail-closed Gemma E2B product capability recheck contract.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bProductCapabilityRecheckGate {
    pub upstream_release_audit_surface_ref: String,
    pub upstream_release_audit_surface_id: String,
    pub release_audit_zero_fail_ledger_ref: String,
    pub first_runtime_settings_wrv_ref: String,
    pub artifact_root_prefix: String,
    pub recheck_card_id: String,
    pub selected_model_id: String,
    pub source_revision: String,
    pub required_filename: String,
    pub expected_file_size_bytes: u64,
    pub runtime_lane: GemmaFamilyRuntimeLane,
    pub command_path: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub expected_release_audit_next_cursor: String,
    pub expected_first_runtime_wrv_next_cursor: String,
    pub expected_route_status: String,
    pub required_recheck_fields: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub release_audit_zero_fail_ledger_pass_required: bool,
    pub release_audit_next_cursor_match_required: bool,
    pub release_audit_three_pass_count_required: bool,
    pub first_runtime_wrv_pass_required: bool,
    pub first_runtime_selected_model_match_required: bool,
    pub first_runtime_release_cursor_match_required: bool,
    pub live_route_integration_pending_required: bool,
    pub live_route_default_mutation_zero_required: bool,
    pub live_route_runtime_router_mutation_zero_required: bool,
    pub live_route_system_g_mutation_zero_required: bool,
    pub settings_row_gated_only: bool,
    pub diagnostics_row_gated_only: bool,
    pub runtime_route_blocked: bool,
    pub default_model_blocked: bool,
    pub answer_packet_user_surface_blocked: bool,
    pub owner_action_required: bool,
    pub product_capability_recheck_green: bool,
    pub run_event_log_required: bool,
    pub rollback_required: bool,
    pub abstention_required: bool,
    pub scope_rex_required: bool,
    pub sovereign_gate_required: bool,
    pub cancellation_required: bool,
    pub xcode_executed: bool,
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
    pub quality_claimed: bool,
    pub benchmark_claimed_as_fit: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub metadata_bytes: u64,
    pub status: GemmaQatE2bProductCapabilityRecheckGateStatus,
    pub next_cursor: String,
}

impl GemmaQatE2bProductCapabilityRecheckGate {
    pub fn canonical(upstream_release_audit_surface_ref: impl Into<String>) -> Self {
        Self {
            upstream_release_audit_surface_ref: upstream_release_audit_surface_ref.into(),
            upstream_release_audit_surface_id: GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_ID
                .to_string(),
            release_audit_zero_fail_ledger_ref:
                GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_ZERO_FAIL_LEDGER_REF.to_string(),
            first_runtime_settings_wrv_ref:
                GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_FIRST_RUNTIME_WRV_REF.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            recheck_card_id: RECHECK_CARD_ID.to_string(),
            selected_model_id: GEMMA_QAT_RUNTIME_REPLAY_SELECTED_MODEL_ID.to_string(),
            source_revision: GEMMA_QAT_E2B_SOURCE_REVISION.to_string(),
            required_filename: GEMMA_QAT_RUNTIME_REPLAY_REQUIRED_FILENAME.to_string(),
            expected_file_size_bytes: GEMMA_QAT_E2B_EXPECTED_FILE_BYTES,
            runtime_lane: GemmaFamilyRuntimeLane::GgufLlamaCpp,
            command_path: GEMMA_QAT_RUNTIME_REPLAY_COMMAND_PATH.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Blocked,
            expected_release_audit_next_cursor: RELEASE_AUDIT_READY_CURSOR.to_string(),
            expected_first_runtime_wrv_next_cursor: FIRST_RUNTIME_WRV_RELEASE_CURSOR.to_string(),
            expected_route_status: ROUTE_STATUS_BLOCKED.to_string(),
            required_recheck_fields: REQUIRED_RECHECK_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            release_audit_zero_fail_ledger_pass_required: true,
            release_audit_next_cursor_match_required: true,
            release_audit_three_pass_count_required: true,
            first_runtime_wrv_pass_required: true,
            first_runtime_selected_model_match_required: true,
            first_runtime_release_cursor_match_required: true,
            live_route_integration_pending_required: true,
            live_route_default_mutation_zero_required: true,
            live_route_runtime_router_mutation_zero_required: true,
            live_route_system_g_mutation_zero_required: true,
            settings_row_gated_only: true,
            diagnostics_row_gated_only: true,
            runtime_route_blocked: true,
            default_model_blocked: true,
            answer_packet_user_surface_blocked: true,
            owner_action_required: true,
            product_capability_recheck_green: false,
            run_event_log_required: true,
            rollback_required: true,
            abstention_required: true,
            scope_rex_required: true,
            sovereign_gate_required: true,
            cancellation_required: true,
            xcode_executed: false,
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
            quality_claimed: false,
            benchmark_claimed_as_fit: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            metadata_bytes: 240_000,
            status: GemmaQatE2bProductCapabilityRecheckGateStatus::ProductCapabilityBlocked,
            next_cursor: GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GemmaQatE2bProductCapabilityRecheckGateError> {
        if !self
            .upstream_release_audit_surface_ref
            .starts_with(UPSTREAM_RELEASE_AUDIT_SURFACE_PREFIX)
            || self.upstream_release_audit_surface_id != GEMMA_QAT_E2B_RELEASE_AUDIT_SURFACE_GATE_ID
        {
            return Err(GemmaQatE2bProductCapabilityRecheckGateError::BadUpstreamRef);
        }
        if !self
            .release_audit_zero_fail_ledger_ref
            .starts_with(RELEASE_AUDIT_ZERO_FAIL_LEDGER_PREFIX)
            || self.first_runtime_settings_wrv_ref.is_empty()
            || !self
                .first_runtime_settings_wrv_ref
                .starts_with(FIRST_RUNTIME_WRV_PREFIX)
        {
            return Err(GemmaQatE2bProductCapabilityRecheckGateError::BadProofRef);
        }
        validate_exact(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact("recheck_card_id", &self.recheck_card_id, RECHECK_CARD_ID)?;
        validate_exact(
            "expected_release_audit_next_cursor",
            &self.expected_release_audit_next_cursor,
            RELEASE_AUDIT_READY_CURSOR,
        )?;
        validate_exact(
            "expected_first_runtime_wrv_next_cursor",
            &self.expected_first_runtime_wrv_next_cursor,
            FIRST_RUNTIME_WRV_RELEASE_CURSOR,
        )?;
        validate_exact(
            "expected_route_status",
            &self.expected_route_status,
            ROUTE_STATUS_BLOCKED,
        )?;
        validate_unique_exact_set(
            "required_recheck_fields",
            &self.required_recheck_fields,
            REQUIRED_RECHECK_FIELDS,
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
            return Err(GemmaQatE2bProductCapabilityRecheckGateError::BadSelectedLane);
        }
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Blocked
            || self.status
                != GemmaQatE2bProductCapabilityRecheckGateStatus::ProductCapabilityBlocked
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(GemmaQatE2bProductCapabilityRecheckGateError::UnsafeState);
        }
        if !self.release_audit_zero_fail_ledger_pass_required
            || !self.release_audit_next_cursor_match_required
            || !self.release_audit_three_pass_count_required
            || !self.first_runtime_wrv_pass_required
            || !self.first_runtime_selected_model_match_required
            || !self.first_runtime_release_cursor_match_required
            || !self.live_route_integration_pending_required
            || !self.live_route_default_mutation_zero_required
            || !self.live_route_runtime_router_mutation_zero_required
            || !self.live_route_system_g_mutation_zero_required
            || !self.settings_row_gated_only
            || !self.diagnostics_row_gated_only
            || !self.runtime_route_blocked
            || !self.default_model_blocked
            || !self.answer_packet_user_surface_blocked
            || !self.owner_action_required
            || !self.run_event_log_required
            || !self.rollback_required
            || !self.abstention_required
            || !self.scope_rex_required
            || !self.sovereign_gate_required
            || !self.cancellation_required
        {
            return Err(GemmaQatE2bProductCapabilityRecheckGateError::ProofBoundaryBroken);
        }
        if self.product_capability_recheck_green
            || self.xcode_executed
            || self.model_command_armed
            || self.model_command_executed
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(GemmaQatE2bProductCapabilityRecheckGateError::ActionLeak);
        }
        if self.raw_prompt_bytes_captured != 0 || self.raw_output_bytes_captured != 0 {
            return Err(GemmaQatE2bProductCapabilityRecheckGateError::PrivacyLeak);
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
            || self.quality_claimed
            || self.benchmark_claimed_as_fit
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(GemmaQatE2bProductCapabilityRecheckGateError::PromotionClaim);
        }
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaQatE2bProductCapabilityRecheckGateMetrics {
        GemmaQatE2bProductCapabilityRecheckGateMetrics {
            required_recheck_field_count: self.required_recheck_fields.len() as u64,
            required_rejection_policy_count: self.required_rejection_policies.len() as u64,
            blocked_truth_count: self.live_route_integration_pending_required as u64
                + self.runtime_route_blocked as u64
                + self.default_model_blocked as u64
                + self.answer_packet_user_surface_blocked as u64
                + self.owner_action_required as u64,
            gated_surface_count: self.settings_row_gated_only as u64
                + self.diagnostics_row_gated_only as u64
                + self.runtime_route_blocked as u64
                + self.default_model_blocked as u64
                + self.answer_packet_user_surface_blocked as u64
                + self.owner_action_required as u64,
            action_leak_count: self.product_capability_recheck_green as u64
                + self.xcode_executed as u64
                + self.model_command_armed as u64
                + self.model_command_executed as u64,
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
                || self.quality_claimed
                || self.benchmark_claimed_as_fit
                || self.live_dense_70b_claim
                || self.ssd_as_ram_claim) as u64,
        }
    }

    pub fn recheck_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_CURSOR.to_string()),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_recheck_fields.clone();
        fields.sort();
        let mut policies = self.required_rejection_policies.clone();
        policies.sort();
        format!(
            "gemma-e2b-product-capability-recheck-gate:v2:{}:{}:{}:{}:{}:{}:{}:{}:{}:{}",
            self.upstream_release_audit_surface_ref,
            self.release_audit_zero_fail_ledger_ref,
            self.first_runtime_settings_wrv_ref,
            self.selected_model_id,
            self.expected_release_audit_next_cursor,
            self.expected_route_status,
            self.required_filename,
            fields.join(","),
            policies.join(","),
            self.next_cursor,
        )
    }
}

// UAS: uas:gemma-qat-e2b-product-capability-recheck-gate:metrics
// Plane: Verification.
// Residency: zero-byte leakage and blocked-truth counters.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaQatE2bProductCapabilityRecheckGateMetrics {
    pub required_recheck_field_count: u64,
    pub required_rejection_policy_count: u64,
    pub blocked_truth_count: u64,
    pub gated_surface_count: u64,
    pub action_leak_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_prompt_bytes_captured: u64,
    pub raw_output_bytes_captured: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

pub fn required_gemma_qat_e2b_product_capability_recheck_fields() -> Vec<String> {
    REQUIRED_RECHECK_FIELDS
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

pub fn required_gemma_qat_e2b_product_capability_recheck_rejection_policies() -> Vec<String> {
    REQUIRED_REJECTION_POLICIES
        .iter()
        .map(|value| (*value).to_string())
        .collect()
}

// UAS: uas:gemma-qat-e2b-product-capability-recheck-gate:error
// Plane: Verification.
// Residency: fail-closed diagnostics for product capability recheck.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GemmaQatE2bProductCapabilityRecheckGateError {
    BadUpstreamRef,
    BadProofRef,
    BadSelectedLane,
    DuplicateOrMissingField(&'static str),
    BadField(&'static str),
    UnsafeState,
    ProofBoundaryBroken,
    ActionLeak,
    PrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaQatE2bProductCapabilityRecheckGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => f.write_str("bad upstream release-audit surface reference"),
            Self::BadProofRef => {
                f.write_str("bad release-audit ledger or first-runtime WRV reference")
            }
            Self::BadSelectedLane => f.write_str("bad selected E2B recheck lane"),
            Self::DuplicateOrMissingField(field) => {
                write!(f, "duplicate or missing required set: {field}")
            }
            Self::BadField(field) => write!(f, "bad field: {field}"),
            Self::UnsafeState => f.write_str("unsafe product capability recheck state"),
            Self::ProofBoundaryBroken => f.write_str("proof boundary broken"),
            Self::ActionLeak => f.write_str("recheck action leak"),
            Self::PrivacyLeak => f.write_str("privacy leak"),
            Self::PromotionClaim => f.write_str("promotion or hidden-authority claim"),
        }
    }
}

impl std::error::Error for GemmaQatE2bProductCapabilityRecheckGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaQatE2bProductCapabilityRecheckGateError> {
    if actual.len() != expected.len() {
        return Err(
            GemmaQatE2bProductCapabilityRecheckGateError::DuplicateOrMissingField(field_name),
        );
    }
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual_set.len() != actual.len() || actual_set != expected_set {
        return Err(
            GemmaQatE2bProductCapabilityRecheckGateError::DuplicateOrMissingField(field_name),
        );
    }
    Ok(())
}

fn validate_exact(
    field_name: &'static str,
    actual: &str,
    expected: &str,
) -> Result<(), GemmaQatE2bProductCapabilityRecheckGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaQatE2bProductCapabilityRecheckGateError::BadField(
            field_name,
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_582_000_000;

    #[test]
    fn canonical_recheck_validates_as_blocked() {
        let gate = GemmaQatE2bProductCapabilityRecheckGate::canonical(
            GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_UPSTREAM_REF,
        );
        gate.validate()
            .expect("canonical product capability recheck should validate");
        let metrics = gate.metrics();
        assert_eq!(metrics.required_recheck_field_count, 37);
        assert_eq!(metrics.required_rejection_policy_count, 53);
        assert_eq!(metrics.blocked_truth_count, 5);
        assert_eq!(metrics.gated_surface_count, 6);
        assert_eq!(metrics.action_leak_count, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn required_set_drift_is_rejected() {
        let mut gate = GemmaQatE2bProductCapabilityRecheckGate::canonical(
            GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_UPSTREAM_REF,
        );
        gate.required_recheck_fields.pop();
        assert!(matches!(
            gate.validate(),
            Err(
                GemmaQatE2bProductCapabilityRecheckGateError::DuplicateOrMissingField(
                    "required_recheck_fields"
                )
            )
        ));
    }

    #[test]
    fn green_laundering_and_xcode_are_rejected() {
        let mut gate = GemmaQatE2bProductCapabilityRecheckGate::canonical(
            GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_UPSTREAM_REF,
        );
        gate.product_capability_recheck_green = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bProductCapabilityRecheckGateError::ActionLeak)
        ));
        let mut gate = GemmaQatE2bProductCapabilityRecheckGate::canonical(
            GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_UPSTREAM_REF,
        );
        gate.xcode_executed = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bProductCapabilityRecheckGateError::ActionLeak)
        ));
    }

    #[test]
    fn runtime_and_promotion_are_rejected() {
        let mut gate = GemmaQatE2bProductCapabilityRecheckGate::canonical(
            GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_UPSTREAM_REF,
        );
        gate.model_bytes_loaded = 1;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bProductCapabilityRecheckGateError::ActionLeak)
        ));
        let mut gate = GemmaQatE2bProductCapabilityRecheckGate::canonical(
            GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_UPSTREAM_REF,
        );
        gate.l2_capability_effect = true;
        assert!(matches!(
            gate.validate(),
            Err(GemmaQatE2bProductCapabilityRecheckGateError::PromotionClaim)
        ));
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let gate = GemmaQatE2bProductCapabilityRecheckGate::canonical(
            GEMMA_QAT_E2B_PRODUCT_CAPABILITY_RECHECK_GATE_UPSTREAM_REF,
        );
        let reversed = GemmaQatE2bProductCapabilityRecheckGate {
            required_recheck_fields: gate.required_recheck_fields.iter().cloned().rev().collect(),
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
            gate.recheck_address(CREATED_AT_MS),
            reversed.recheck_address(CREATED_AT_MS)
        );
    }
}
