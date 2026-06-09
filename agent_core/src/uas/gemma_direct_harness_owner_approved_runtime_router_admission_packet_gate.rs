//! Gemma direct harness owner-approved RuntimeRouter admission packet gate.
//!
//! This primitive consumes the same-fixture quality packet gate and freezes the
//! admission contract required before future Gemma direct-harness quality
//! evidence can influence RuntimeRouter/System G. It is metadata-only: no
//! admission packet is read, no route is mutated, no runtime is executed, and
//! no model/provider bytes are loaded.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_SAME_FIXTURE_QUALITY_PACKET_GATE_ID,
};

pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_ID: &str =
    "F-GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_CURSOR: &str =
    "gemma_direct_harness_owner_approved_runtime_router_admission_packet_gate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_NEXT_CURSOR:
    &str = "gemma_direct_harness_owner_approved_system_g_dry_run_route_packet_gate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_UPSTREAM_REF:
    &str = "artifact:falsifiers/gemma_direct_harness_owner_approved_same_fixture_quality_packet_gate/result.json#F-GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGate";

const UPSTREAM_QUALITY_PACKET_PREFIX: &str =
    "artifact:falsifiers/gemma_direct_harness_owner_approved_same_fixture_quality_packet_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_direct_harness_owner_approved_runtime_router_admission_packet_gate/";
const ADMISSION_CARD_ID: &str =
    "gemma-direct-harness-owner-approved-runtime-router-admission-packet-gate-v1";
const FUTURE_ADMISSION_PACKET_NAME: &str =
    "owner-approved-gemma-direct-harness-runtime-router-admission-packet-v1";
const DIRECT_HARNESS_RUNTIME_LANE: &str = "gemma-direct-harness-llama-cpp-gguf-pro-gated";
const SCOPE_REX_PREFIX: &str = "scope_rex:";
const SOVEREIGN_GATE_PREFIX: &str = "sovereign_gate:";
const FALLBACK_PREFIX: &str = "fallback:";
const ABSTENTION_PREFIX: &str = "abstention:";
const CANCEL_PREFIX: &str = "cancel:";
const ROLLBACK_PREFIX: &str = "rollback:";
const RUN_EVENT_LOG_PREFIX: &str = "run_event_log:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const MAX_METADATA_BYTES: u64 = 320 * 1024;

const REQUIRED_ADMISSION_FIELDS: &[&str] = &[
    "upstream_quality_packet_digest",
    "quality_packet_decision_digest",
    "owner_approval_digest",
    "redacted_receipt_digest",
    "first_token_review_digest",
    "quality_summary_digest",
    "quality_failure_taxonomy_digest",
    "runtime_lane_digest",
    "model_identity_digest",
    "llama_cli_identity_digest",
    "prompt_tokenizer_template_digest",
    "budget_vector_digest",
    "memory_headroom_digest",
    "kv_budget_digest",
    "latency_budget_digest",
    "privacy_class_digest",
    "mas_pro_boundary_digest",
    "scope_rex_verdict_digest",
    "sovereign_gate_verdict_digest",
    "route_priority_digest",
    "fallback_route_digest",
    "abstention_policy_digest",
    "cancellation_policy_digest",
    "rollback_digest",
    "run_event_log_digest",
    "answer_packet_digest",
    "visible_caveat_digest",
    "settings_visibility_digest",
    "diagnostic_visibility_digest",
    "no_default_model_mutation_digest",
    "no_hidden_authority_digest",
    "non_promotion_digest",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_quality_packet",
    "quality_packet_digest_mismatch",
    "missing_owner_approval",
    "missing_redacted_receipt_digest",
    "missing_first_token_review_digest",
    "missing_quality_summary",
    "missing_failure_taxonomy",
    "missing_runtime_lane",
    "missing_model_identity",
    "missing_llama_cli_identity",
    "missing_prompt_tokenizer_template",
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
    "bad_runtime_lane",
    "quality_score_used_without_packet",
    "budget_overrun_allowed",
    "memory_headroom_bypassed",
    "kv_budget_bypassed",
    "latency_budget_bypassed",
    "abstention_disabled",
    "fallback_hidden",
    "route_priority_mutated",
    "runtime_router_mutated",
    "system_g_mutated",
    "default_model_mutated",
    "settings_claim_live",
    "answer_packet_suppressed",
    "raw_prompt_retained",
    "raw_output_retained",
    "hidden_route_authority",
    "hidden_eidos_authority",
    "hidden_lattice_authority",
    "hidden_patternboost_authority",
    "hidden_cloud_fallback",
    "mas_l2_l3_t4_promotion",
    "gemma_default_promotion",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
    "quality_claim_before_runtime",
    "benchmark_claimed_as_fit",
];

// UAS: uas:gemma-direct-harness-owner-approved-runtime-router-admission-packet-gate:status
// Plane: Controller + Verification.
// Residency: metadata-only admission status; no route or runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateStatus {
    AdmissionPacketContractOnly,
}

// UAS: uas:gemma-direct-harness-owner-approved-runtime-router-admission-packet-gate:spec
// Plane: Controller + Verification.
// Residency: future RuntimeRouter/System G admission contract only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate {
    pub upstream_quality_packet_ref: String,
    pub upstream_quality_packet_id: String,
    pub artifact_root_prefix: String,
    pub admission_card_id: String,
    pub future_admission_packet_name: String,
    pub runtime_lane: String,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_admission_fields: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub upstream_quality_packet_digest_required: bool,
    pub owner_approval_digest_required: bool,
    pub redacted_receipt_digest_required: bool,
    pub first_token_review_digest_required: bool,
    pub quality_summary_digest_required: bool,
    pub failure_taxonomy_digest_required: bool,
    pub runtime_lane_digest_required: bool,
    pub model_and_llama_identity_required: bool,
    pub prompt_tokenizer_template_digest_required: bool,
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
    pub no_default_model_mutation_bound: bool,
    pub no_hidden_authority_bound: bool,
    pub non_promotion_bound: bool,
    pub future_admission_packet_present: bool,
    pub future_admission_packet_bytes_read: u64,
    pub admission_performed_count: u64,
    pub route_priority_mutation_count: u64,
    pub runtime_router_mutation_allowed: bool,
    pub system_g_mutation_allowed: bool,
    pub default_model_mutation_allowed: bool,
    pub command_armed: bool,
    pub command_executed: bool,
    pub process_spawned: bool,
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
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub quality_claimed: bool,
    pub benchmark_claimed_as_fit: bool,
    pub metadata_bytes: u64,
    pub status: GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateStatus,
    pub next_cursor: String,
}

impl GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate {
    pub fn canonical() -> Self {
        Self {
            upstream_quality_packet_ref:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_UPSTREAM_REF
                    .to_string(),
            upstream_quality_packet_id:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_SAME_FIXTURE_QUALITY_PACKET_GATE_ID.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            admission_card_id: ADMISSION_CARD_ID.to_string(),
            future_admission_packet_name: FUTURE_ADMISSION_PACKET_NAME.to_string(),
            runtime_lane: DIRECT_HARNESS_RUNTIME_LANE.to_string(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_admission_fields: REQUIRED_ADMISSION_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            upstream_quality_packet_digest_required: true,
            owner_approval_digest_required: true,
            redacted_receipt_digest_required: true,
            first_token_review_digest_required: true,
            quality_summary_digest_required: true,
            failure_taxonomy_digest_required: true,
            runtime_lane_digest_required: true,
            model_and_llama_identity_required: true,
            prompt_tokenizer_template_digest_required: true,
            budget_vector_bound: true,
            memory_headroom_bound: true,
            kv_budget_bound: true,
            latency_budget_bound: true,
            privacy_class_bound: true,
            mas_pro_boundary_bound: true,
            scope_rex_verdict_ref:
                "scope_rex:gemma_direct_harness_runtime_router_admission_packet_gate".to_string(),
            sovereign_gate_verdict_ref:
                "sovereign_gate:gemma_direct_harness_runtime_router_admission_packet_gate"
                    .to_string(),
            fallback_route_ref:
                "fallback:gemma_direct_harness_quality_packet_abstain_to_current_local_lane"
                    .to_string(),
            abstention_policy_ref:
                "abstention:gemma_direct_harness_quality_packet_not_admitted".to_string(),
            cancellation_policy_ref:
                "cancel:gemma_direct_harness_runtime_router_admission_packet_gate".to_string(),
            rollback_ref:
                "rollback:gemma_direct_harness_runtime_router_admission_packet_gate".to_string(),
            run_event_log_ref:
                "run_event_log:gemma_direct_harness_runtime_router_admission_packet_gate"
                    .to_string(),
            answer_packet_ref:
                "answer_packet:gemma_direct_harness_runtime_router_admission_packet_gate"
                    .to_string(),
            visible_caveat_digest_required: true,
            settings_visibility_digest_required: true,
            diagnostic_visibility_digest_required: true,
            no_default_model_mutation_bound: true,
            no_hidden_authority_bound: true,
            non_promotion_bound: true,
            future_admission_packet_present: false,
            future_admission_packet_bytes_read: 0,
            admission_performed_count: 0,
            route_priority_mutation_count: 0,
            runtime_router_mutation_allowed: false,
            system_g_mutation_allowed: false,
            default_model_mutation_allowed: false,
            command_armed: false,
            command_executed: false,
            process_spawned: false,
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
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            quality_claimed: false,
            benchmark_claimed_as_fit: false,
            metadata_bytes: 244_000,
            status:
                GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateStatus::AdmissionPacketContractOnly,
            next_cursor:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_NEXT_CURSOR
                    .to_string(),
        }
    }

    pub fn validate(
        &self,
    ) -> Result<(), GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError> {
        if !self
            .upstream_quality_packet_ref
            .starts_with(UPSTREAM_QUALITY_PACKET_PREFIX)
            || self.upstream_quality_packet_id
                != GEMMA_DIRECT_HARNESS_OWNER_APPROVED_SAME_FIXTURE_QUALITY_PACKET_GATE_ID
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::BadUpstreamRef,
            );
        }
        validate_exact(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact(
            "admission_card_id",
            &self.admission_card_id,
            ADMISSION_CARD_ID,
        )?;
        validate_exact(
            "future_admission_packet_name",
            &self.future_admission_packet_name,
            FUTURE_ADMISSION_PACKET_NAME,
        )?;
        validate_exact(
            "runtime_lane",
            &self.runtime_lane,
            DIRECT_HARNESS_RUNTIME_LANE,
        )?;
        validate_unique_exact_set(
            "required_admission_fields",
            &self.required_admission_fields,
            REQUIRED_ADMISSION_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_rejection_policies",
            &self.required_rejection_policies,
            REQUIRED_REJECTION_POLICIES,
        )?;
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateStatus::AdmissionPacketContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::UnsafeState,
            );
        }
        if !self.upstream_quality_packet_digest_required
            || !self.owner_approval_digest_required
            || !self.redacted_receipt_digest_required
            || !self.first_token_review_digest_required
            || !self.quality_summary_digest_required
            || !self.failure_taxonomy_digest_required
            || !self.runtime_lane_digest_required
            || !self.model_and_llama_identity_required
            || !self.prompt_tokenizer_template_digest_required
            || !self.budget_vector_bound
            || !self.memory_headroom_bound
            || !self.kv_budget_bound
            || !self.latency_budget_bound
            || !self.privacy_class_bound
            || !self.mas_pro_boundary_bound
            || !self.no_default_model_mutation_bound
            || !self.no_hidden_authority_bound
            || !self.non_promotion_bound
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::ProofBoundaryBroken,
            );
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
        validate_prefix(
            "fallback_route_ref",
            &self.fallback_route_ref,
            FALLBACK_PREFIX,
        )?;
        validate_prefix(
            "abstention_policy_ref",
            &self.abstention_policy_ref,
            ABSTENTION_PREFIX,
        )?;
        validate_prefix(
            "cancellation_policy_ref",
            &self.cancellation_policy_ref,
            CANCEL_PREFIX,
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
        if !self.visible_caveat_digest_required
            || !self.settings_visibility_digest_required
            || !self.diagnostic_visibility_digest_required
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::VisibilityBroken,
            );
        }
        if self.future_admission_packet_present
            || self.future_admission_packet_bytes_read != 0
            || self.admission_performed_count != 0
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::AdmissionActionLeak,
            );
        }
        if self.route_priority_mutation_count != 0
            || self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.default_model_mutation_allowed
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::RouteMutationLeak,
            );
        }
        if self.command_armed
            || self.command_executed
            || self.process_spawned
            || self.runtime_replay_performed
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::RuntimeActionLeak,
            );
        }
        if self.raw_prompt_bytes_captured != 0
            || self.raw_output_bytes_captured != 0
            || self.answer_packet_suppressed
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::PrivacyLeak,
            );
        }
        if self.hidden_route_authority
            || self.hidden_eidos_authority
            || self.hidden_lattice_authority
            || self.hidden_patternboost_authority
            || self.hidden_cloud_fallback
            || self.quality_claimed
            || self.benchmark_claimed_as_fit
            || self.mas_promoted
            || self.l2_capability_effect
            || self.l3_wrv_effect
            || self.t4_build_green_effect
            || self.product_route_green
            || self.live_gemma_default_claim
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::PromotionClaim,
            );
        }
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(
        &self,
    ) -> GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateMetrics {
        GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateMetrics {
            required_admission_field_count: self.required_admission_fields.len() as u64,
            required_rejection_policy_count: self.required_rejection_policies.len() as u64,
            future_admission_packet_present_count: self.future_admission_packet_present as u64,
            future_admission_packet_bytes_read: self.future_admission_packet_bytes_read,
            admission_performed_count: self.admission_performed_count,
            route_priority_mutation_count: self.route_priority_mutation_count,
            mutation_count: (self.runtime_router_mutation_allowed
                || self.system_g_mutation_allowed
                || self.default_model_mutation_allowed) as u64,
            command_armed_count: self.command_armed as u64,
            command_executed_count: self.command_executed as u64,
            process_spawned_count: self.process_spawned as u64,
            runtime_replay_performed_count: self.runtime_replay_performed as u64,
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
            raw_prompt_bytes_captured: self.raw_prompt_bytes_captured,
            raw_output_bytes_captured: self.raw_output_bytes_captured,
            answer_packet_suppressed_count: self.answer_packet_suppressed as u64,
            hidden_authority_count: (self.hidden_route_authority
                || self.hidden_eidos_authority
                || self.hidden_lattice_authority
                || self.hidden_patternboost_authority
                || self.hidden_cloud_fallback) as u64,
            promotion_claim_count: (self.quality_claimed
                || self.benchmark_claimed_as_fit
                || self.mas_promoted
                || self.l2_capability_effect
                || self.l3_wrv_effect
                || self.t4_build_green_effect
                || self.product_route_green
                || self.live_gemma_default_claim
                || self.live_dense_70b_claim
                || self.ssd_as_ram_claim) as u64,
        }
    }

    pub fn admission_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_RUNTIME_ROUTER_ADMISSION_PACKET_GATE_CURSOR
                    .to_string(),
            ),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_admission_fields.clone();
        fields.sort();
        let mut policies = self.required_rejection_policies.clone();
        policies.sort();
        format!(
            "gemma-direct-harness-owner-approved-runtime-router-admission-packet-gate:v1:{}:{}:{}:{}:{}",
            self.upstream_quality_packet_ref,
            self.upstream_quality_packet_id,
            self.runtime_lane,
            fields.join(","),
            policies.join(","),
        )
    }
}

// UAS: uas:gemma-direct-harness-owner-approved-runtime-router-admission-packet-gate:metrics
// Plane: Controller + Verification.
// Residency: zero-action admission counters.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateMetrics {
    pub required_admission_field_count: u64,
    pub required_rejection_policy_count: u64,
    pub future_admission_packet_present_count: u64,
    pub future_admission_packet_bytes_read: u64,
    pub admission_performed_count: u64,
    pub route_priority_mutation_count: u64,
    pub mutation_count: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub process_spawned_count: u64,
    pub runtime_replay_performed_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_prompt_bytes_captured: u64,
    pub raw_output_bytes_captured: u64,
    pub answer_packet_suppressed_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

// UAS: uas:gemma-direct-harness-owner-approved-runtime-router-admission-packet-gate:error
// Plane: Controller + Verification.
// Residency: validation errors only; no route/model/runtime bytes.
#[derive(Debug, PartialEq, Eq)]
pub enum GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError {
    BadUpstreamRef,
    BadField(&'static str),
    DuplicateOrMissingField(&'static str),
    UnsafeState,
    ProofBoundaryBroken,
    VisibilityBroken,
    AdmissionActionLeak,
    RouteMutationLeak,
    RuntimeActionLeak,
    PrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => write!(f, "upstream quality packet reference is invalid"),
            Self::BadField(field) => write!(f, "invalid field {field}"),
            Self::DuplicateOrMissingField(field) => write!(f, "duplicate or missing {field}"),
            Self::UnsafeState => write!(f, "admission packet gate state is unsafe"),
            Self::ProofBoundaryBroken => write!(f, "admission proof boundary is broken"),
            Self::VisibilityBroken => write!(f, "visibility proof is broken"),
            Self::AdmissionActionLeak => write!(f, "admission packet action leaked"),
            Self::RouteMutationLeak => write!(f, "route mutation leaked"),
            Self::RuntimeActionLeak => write!(f, "runtime action leaked"),
            Self::PrivacyLeak => write!(f, "privacy boundary leaked"),
            Self::PromotionClaim => {
                write!(f, "admission packet promoted capability or product claims")
            }
        }
    }
}

impl std::error::Error for GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError> {
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual.len() != expected.len() || actual_set.len() != actual.len() {
        return Err(
            GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    if actual_set != expected_set {
        return Err(
            GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    Ok(())
}

fn validate_exact(
    field_name: &'static str,
    actual: &str,
    expected: &str,
) -> Result<(), GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(
            GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::BadField(
                field_name,
            ),
        )
    }
}

fn validate_prefix(
    field_name: &'static str,
    actual: &str,
    prefix: &str,
) -> Result<(), GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError> {
    if actual.starts_with(prefix) {
        Ok(())
    } else {
        Err(
            GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::BadField(
                field_name,
            ),
        )
    }
}

pub fn required_gemma_direct_harness_owner_approved_runtime_router_admission_fields(
) -> Vec<&'static str> {
    REQUIRED_ADMISSION_FIELDS.to_vec()
}

pub fn required_gemma_direct_harness_owner_approved_runtime_router_rejection_policies(
) -> Vec<&'static str> {
    REQUIRED_REJECTION_POLICIES.to_vec()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_admission_gate_validates_zero_actions() {
        let gate = GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate::canonical();
        gate.validate()
            .expect("canonical admission packet gate validates");
        let metrics = gate.metrics();

        assert_eq!(metrics.required_admission_field_count, 32);
        assert_eq!(metrics.required_rejection_policy_count, 55);
        assert_eq!(metrics.future_admission_packet_bytes_read, 0);
        assert_eq!(metrics.admission_performed_count, 0);
        assert_eq!(metrics.route_priority_mutation_count, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn duplicate_admission_fields_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate::canonical();
        gate.required_admission_fields[0] = gate.required_admission_fields[1].clone();

        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::DuplicateOrMissingField(
                "required_admission_fields"
            ))
        ));
    }

    #[test]
    fn missing_budget_and_visibility_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate::canonical();
        gate.memory_headroom_bound = false;
        assert_eq!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::ProofBoundaryBroken)
        );

        let mut gate = GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate::canonical();
        gate.settings_visibility_digest_required = false;
        assert_eq!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::VisibilityBroken)
        );
    }

    #[test]
    fn admission_route_and_runtime_actions_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate::canonical();
        gate.future_admission_packet_present = true;
        assert_eq!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::AdmissionActionLeak)
        );

        let mut gate = GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate::canonical();
        gate.runtime_router_mutation_allowed = true;
        assert_eq!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::RouteMutationLeak)
        );

        let mut gate = GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate::canonical();
        gate.model_bytes_loaded = 1;
        assert_eq!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::RuntimeActionLeak)
        );
    }

    #[test]
    fn privacy_and_promotion_claims_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate::canonical();
        gate.raw_prompt_bytes_captured = 1;
        assert_eq!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::PrivacyLeak)
        );

        let mut gate = GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate::canonical();
        gate.l2_capability_effect = true;
        assert_eq!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGateError::PromotionClaim)
        );
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let gate = GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate::canonical();
        let reversed = GemmaDirectHarnessOwnerApprovedRuntimeRouterAdmissionPacketGate {
            required_admission_fields: gate
                .required_admission_fields
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

        assert_eq!(
            gate.admission_gate_address(1_779_926_400_000),
            reversed.admission_gate_address(1_779_926_400_000)
        );
    }
}
