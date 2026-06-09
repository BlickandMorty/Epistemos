//! Gemma direct harness owner-approved same-fixture quality packet gate.
//!
//! This primitive consumes the first-token digest review gate and freezes the
//! packet contract required before a future owner-approved Gemma direct-harness
//! first-token observation can become quality evidence. It is metadata-only:
//! no quality packet, fixture, scorer, receipt, model, runtime, or provider
//! bytes are opened or executed.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::uas::{
    GemmaQatQualityTaskFamily, ProStatus, ProductBuild, UasAddress, UasKind,
    GEMMA_DIRECT_HARNESS_OWNER_APPROVED_FIRST_TOKEN_DIGEST_REVIEW_GATE_ID,
    GEMMA_QAT_QUALITY_TASK_FAMILIES,
};

pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_SAME_FIXTURE_QUALITY_PACKET_GATE_ID: &str =
    "F-GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_SAME_FIXTURE_QUALITY_PACKET_GATE_CURSOR: &str =
    "gemma_direct_harness_owner_approved_same_fixture_quality_packet_gate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_SAME_FIXTURE_QUALITY_PACKET_GATE_NEXT_CURSOR: &str =
    "gemma_direct_harness_owner_approved_runtime_router_admission_packet_gate";
pub const GEMMA_DIRECT_HARNESS_OWNER_APPROVED_SAME_FIXTURE_QUALITY_PACKET_GATE_UPSTREAM_REF: &str =
    "artifact:falsifiers/gemma_direct_harness_owner_approved_first_token_digest_review_gate/result.json#F-GemmaDirectHarnessOwnerApprovedFirstTokenDigestReviewGate";

const UPSTREAM_FIRST_TOKEN_REVIEW_PREFIX: &str =
    "artifact:falsifiers/gemma_direct_harness_owner_approved_first_token_digest_review_gate/";
const ARTIFACT_ROOT_PREFIX: &str =
    "artifacts/falsifiers/gemma_direct_harness_owner_approved_same_fixture_quality_packet_gate/";
const PACKET_CARD_ID: &str =
    "gemma-direct-harness-owner-approved-same-fixture-quality-packet-gate-v1";
const FUTURE_QUALITY_PACKET_NAME: &str =
    "owner-approved-gemma-direct-harness-same-fixture-quality-packet-v1";
const FIXTURE_PACK_DIGEST: &str =
    "fixture_pack:sha256:gemma-direct-harness-same-fixture-quality-pack-v1";
const SCORER_BUNDLE_DIGEST: &str =
    "scorer_bundle:sha256:gemma-direct-harness-deterministic-quality-scorer-v1";
const MAX_METADATA_BYTES: u64 = 260 * 1024;

const REQUIRED_PACKET_FIELDS: &[&str] = &[
    "upstream_first_token_review_artifact_digest",
    "quality_packet_schema_version",
    "owner_approval_digest",
    "redacted_receipt_digest",
    "first_token_review_digest",
    "model_identity_digest",
    "llama_cli_identity_digest",
    "prompt_digest",
    "first_token_digest",
    "tokenizer_identity_digest",
    "chat_template_digest",
    "same_fixture_pack_digest",
    "fixture_split_digest",
    "task_family_digest",
    "prompt_context_tool_digest_policy",
    "expected_output_shape_digest",
    "redacted_candidate_output_digest",
    "deterministic_scorer_bundle_digest",
    "scorer_version_digest",
    "failure_taxonomy_digest",
    "contamination_check_digest",
    "cache_salt_digest",
    "cache_deletion_digest",
    "memory_before_digest",
    "memory_after_digest",
    "duration_digest",
    "exit_status_digest",
    "timeout_cancel_digest",
    "rollback_ref",
    "run_event_log_ref",
    "answer_packet_ref",
    "abstention_ref",
    "reviewer_visible_summary_digest",
    "no_quality_or_route_claim_digest",
];

const REQUIRED_REJECTION_POLICIES: &[&str] = &[
    "missing_upstream_first_token_review",
    "upstream_first_token_review_digest_mismatch",
    "missing_owner_approval",
    "missing_redacted_receipt_digest",
    "missing_first_token_review_digest",
    "missing_model_identity_digest",
    "missing_llama_cli_identity_digest",
    "missing_prompt_digest",
    "missing_first_token_digest",
    "missing_tokenizer_identity_digest",
    "missing_chat_template_digest",
    "missing_same_fixture_pack",
    "missing_task_family",
    "missing_prompt_context_tool_digest_policy",
    "missing_expected_output_shape",
    "missing_redacted_candidate_output",
    "missing_deterministic_scorer_bundle",
    "model_graded_primary",
    "hidden_judge",
    "raw_prompt_retained",
    "raw_context_retained",
    "raw_output_retained",
    "raw_judge_retained",
    "fixture_payload_opened",
    "first_token_review_read",
    "redacted_receipt_read",
    "scorer_executed",
    "quality_replay_attempted",
    "cache_reuse_without_lineage",
    "contamination_check_missing",
    "cache_deletion_missing",
    "missing_timeout_cancel",
    "missing_rollback",
    "missing_run_event_log",
    "missing_answer_packet",
    "missing_abstention",
    "command_armed",
    "command_executed",
    "process_spawned",
    "model_bytes_loaded",
    "runtime_bytes_loaded",
    "provider_called",
    "runtime_router_mutation",
    "system_g_mutation",
    "settings_default_mutation",
    "hidden_authority",
    "quality_claim",
    "benchmark_claimed_as_fit",
    "l2_l3_t4_claim",
    "live_gemma_claim",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

// UAS: uas:gemma-direct-harness-owner-approved-same-fixture-quality-packet-gate:status
// Plane: Verification.
// Residency: metadata-only packet contract; no fixture/model/runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateStatus {
    QualityPacketContractOnly,
}

// UAS: uas:gemma-direct-harness-owner-approved-same-fixture-quality-packet-gate:spec
// Plane: Verification.
// Residency: future quality packet contract only; no replay or scorer runs.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGate {
    pub upstream_first_token_review_ref: String,
    pub upstream_first_token_review_id: String,
    pub artifact_root_prefix: String,
    pub packet_card_id: String,
    pub future_quality_packet_name: String,
    pub fixture_pack_digest: String,
    pub scorer_bundle_digest: String,
    pub task_families: Vec<GemmaQatQualityTaskFamily>,
    pub product_build: ProductBuild,
    pub pro_status: ProStatus,
    pub required_packet_fields: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub upstream_review_digest_required: bool,
    pub owner_approval_digest_required: bool,
    pub redacted_receipt_digest_required: bool,
    pub first_token_review_digest_required: bool,
    pub model_and_llama_identity_required: bool,
    pub prompt_token_tokenizer_template_required: bool,
    pub same_fixture_pack_digest_required: bool,
    pub held_out_split_bound: bool,
    pub prompt_context_tool_digests_required: bool,
    pub redacted_candidate_output_digest_required: bool,
    pub deterministic_scorer_bundle_required: bool,
    pub model_graded_primary_allowed: bool,
    pub hidden_judge_allowed: bool,
    pub failure_taxonomy_bound: bool,
    pub contamination_check_bound: bool,
    pub cache_salt_bound: bool,
    pub cache_deletion_bound: bool,
    pub timeout_bound: bool,
    pub cancellation_bound: bool,
    pub rollback_bound: bool,
    pub run_event_log_bound: bool,
    pub answer_packet_bound: bool,
    pub abstention_bound: bool,
    pub visible_summary_bound: bool,
    pub no_quality_or_route_claim_bound: bool,
    pub future_quality_packet_present: bool,
    pub future_quality_packet_bytes_read: u64,
    pub accepted_quality_packet_count: u64,
    pub quality_replay_performed_count: u64,
    pub fixture_payload_bytes_opened: u64,
    pub first_token_review_bytes_read: u64,
    pub redacted_receipt_bytes_read: u64,
    pub scorer_executions: u64,
    pub benchmark_runs: u64,
    pub command_armed: bool,
    pub command_executed: bool,
    pub process_spawned: bool,
    pub raw_prompt_bytes_captured: u64,
    pub raw_context_bytes_captured: u64,
    pub raw_output_bytes_captured: u64,
    pub raw_judge_bytes_captured: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub cache_bytes_reused: u64,
    pub runtime_router_mutation_allowed: bool,
    pub system_g_mutation_allowed: bool,
    pub settings_or_default_mutation_allowed: bool,
    pub hidden_route_authority: bool,
    pub hidden_eidos_authority: bool,
    pub hidden_lattice_authority: bool,
    pub hidden_patternboost_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub quality_claimed: bool,
    pub benchmark_claimed_as_fit: bool,
    pub mas_promoted: bool,
    pub l2_capability_effect: bool,
    pub l3_wrv_effect: bool,
    pub t4_build_green_effect: bool,
    pub live_gemma_default_claim: bool,
    pub live_dense_70b_claim: bool,
    pub ssd_as_ram_claim: bool,
    pub metadata_bytes: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub abstention_ref: String,
    pub status: GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateStatus,
    pub next_cursor: String,
}

impl GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGate {
    pub fn canonical() -> Self {
        Self {
            upstream_first_token_review_ref:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_SAME_FIXTURE_QUALITY_PACKET_GATE_UPSTREAM_REF
                    .to_string(),
            upstream_first_token_review_id:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_FIRST_TOKEN_DIGEST_REVIEW_GATE_ID.to_string(),
            artifact_root_prefix: ARTIFACT_ROOT_PREFIX.to_string(),
            packet_card_id: PACKET_CARD_ID.to_string(),
            future_quality_packet_name: FUTURE_QUALITY_PACKET_NAME.to_string(),
            fixture_pack_digest: FIXTURE_PACK_DIGEST.to_string(),
            scorer_bundle_digest: SCORER_BUNDLE_DIGEST.to_string(),
            task_families: GEMMA_QAT_QUALITY_TASK_FAMILIES.to_vec(),
            product_build: ProductBuild::Pro,
            pro_status: ProStatus::Gated,
            required_packet_fields: REQUIRED_PACKET_FIELDS
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| (*value).to_string())
                .collect(),
            upstream_review_digest_required: true,
            owner_approval_digest_required: true,
            redacted_receipt_digest_required: true,
            first_token_review_digest_required: true,
            model_and_llama_identity_required: true,
            prompt_token_tokenizer_template_required: true,
            same_fixture_pack_digest_required: true,
            held_out_split_bound: true,
            prompt_context_tool_digests_required: true,
            redacted_candidate_output_digest_required: true,
            deterministic_scorer_bundle_required: true,
            model_graded_primary_allowed: false,
            hidden_judge_allowed: false,
            failure_taxonomy_bound: true,
            contamination_check_bound: true,
            cache_salt_bound: true,
            cache_deletion_bound: true,
            timeout_bound: true,
            cancellation_bound: true,
            rollback_bound: true,
            run_event_log_bound: true,
            answer_packet_bound: true,
            abstention_bound: true,
            visible_summary_bound: true,
            no_quality_or_route_claim_bound: true,
            future_quality_packet_present: false,
            future_quality_packet_bytes_read: 0,
            accepted_quality_packet_count: 0,
            quality_replay_performed_count: 0,
            fixture_payload_bytes_opened: 0,
            first_token_review_bytes_read: 0,
            redacted_receipt_bytes_read: 0,
            scorer_executions: 0,
            benchmark_runs: 0,
            command_armed: false,
            command_executed: false,
            process_spawned: false,
            raw_prompt_bytes_captured: 0,
            raw_context_bytes_captured: 0,
            raw_output_bytes_captured: 0,
            raw_judge_bytes_captured: 0,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            cache_bytes_reused: 0,
            runtime_router_mutation_allowed: false,
            system_g_mutation_allowed: false,
            settings_or_default_mutation_allowed: false,
            hidden_route_authority: false,
            hidden_eidos_authority: false,
            hidden_lattice_authority: false,
            hidden_patternboost_authority: false,
            hidden_cloud_fallback: false,
            quality_claimed: false,
            benchmark_claimed_as_fit: false,
            mas_promoted: false,
            l2_capability_effect: false,
            l3_wrv_effect: false,
            t4_build_green_effect: false,
            live_gemma_default_claim: false,
            live_dense_70b_claim: false,
            ssd_as_ram_claim: false,
            metadata_bytes: 202_000,
            rollback_ref:
                "rollback:gemma_direct_harness_owner_approved_same_fixture_quality_packet_gate"
                    .to_string(),
            run_event_log_ref:
                "run_event_log:gemma_direct_harness_owner_approved_same_fixture_quality_packet_gate"
                    .to_string(),
            answer_packet_ref:
                "answer_packet:gemma_direct_harness_owner_approved_same_fixture_quality_packet_gate"
                    .to_string(),
            abstention_ref:
                "abstention:gemma_direct_harness_owner_approved_same_fixture_quality_packet_gate"
                    .to_string(),
            status:
                GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateStatus::QualityPacketContractOnly,
            next_cursor:
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_SAME_FIXTURE_QUALITY_PACKET_GATE_NEXT_CURSOR
                    .to_string(),
        }
    }

    pub fn validate(
        &self,
    ) -> Result<(), GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError> {
        if !self
            .upstream_first_token_review_ref
            .starts_with(UPSTREAM_FIRST_TOKEN_REVIEW_PREFIX)
            || self.upstream_first_token_review_id
                != GEMMA_DIRECT_HARNESS_OWNER_APPROVED_FIRST_TOKEN_DIGEST_REVIEW_GATE_ID
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::BadUpstreamRef,
            );
        }
        validate_exact(
            "artifact_root_prefix",
            &self.artifact_root_prefix,
            ARTIFACT_ROOT_PREFIX,
        )?;
        validate_exact("packet_card_id", &self.packet_card_id, PACKET_CARD_ID)?;
        validate_exact(
            "future_quality_packet_name",
            &self.future_quality_packet_name,
            FUTURE_QUALITY_PACKET_NAME,
        )?;
        validate_exact(
            "fixture_pack_digest",
            &self.fixture_pack_digest,
            FIXTURE_PACK_DIGEST,
        )?;
        validate_exact(
            "scorer_bundle_digest",
            &self.scorer_bundle_digest,
            SCORER_BUNDLE_DIGEST,
        )?;
        validate_unique_exact_set(
            "required_packet_fields",
            &self.required_packet_fields,
            REQUIRED_PACKET_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_rejection_policies",
            &self.required_rejection_policies,
            REQUIRED_REJECTION_POLICIES,
        )?;
        validate_task_family_coverage(&self.task_families)?;
        if self.product_build != ProductBuild::Pro
            || self.pro_status != ProStatus::Gated
            || self.status
                != GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateStatus::QualityPacketContractOnly
            || self.metadata_bytes > MAX_METADATA_BYTES
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::UnsafeState,
            );
        }
        if !self.upstream_review_digest_required
            || !self.owner_approval_digest_required
            || !self.redacted_receipt_digest_required
            || !self.first_token_review_digest_required
            || !self.model_and_llama_identity_required
            || !self.prompt_token_tokenizer_template_required
            || !self.same_fixture_pack_digest_required
            || !self.held_out_split_bound
            || !self.prompt_context_tool_digests_required
            || !self.redacted_candidate_output_digest_required
            || !self.deterministic_scorer_bundle_required
            || self.model_graded_primary_allowed
            || self.hidden_judge_allowed
            || !self.failure_taxonomy_bound
            || !self.contamination_check_bound
            || !self.cache_salt_bound
            || !self.cache_deletion_bound
            || !self.timeout_bound
            || !self.cancellation_bound
            || !self.rollback_bound
            || !self.run_event_log_bound
            || !self.answer_packet_bound
            || !self.abstention_bound
            || !self.visible_summary_bound
            || !self.no_quality_or_route_claim_bound
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::ProofBoundaryBroken,
            );
        }
        if self.future_quality_packet_present
            || self.future_quality_packet_bytes_read != 0
            || self.accepted_quality_packet_count != 0
            || self.quality_replay_performed_count != 0
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::QualityPacketActionLeak,
            );
        }
        if self.fixture_payload_bytes_opened != 0
            || self.first_token_review_bytes_read != 0
            || self.redacted_receipt_bytes_read != 0
            || self.scorer_executions != 0
            || self.benchmark_runs != 0
            || self.command_armed
            || self.command_executed
            || self.process_spawned
            || self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.cache_bytes_reused != 0
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::RuntimeActionLeak,
            );
        }
        if self.raw_prompt_bytes_captured != 0
            || self.raw_context_bytes_captured != 0
            || self.raw_output_bytes_captured != 0
            || self.raw_judge_bytes_captured != 0
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::PrivacyLeak,
            );
        }
        if self.runtime_router_mutation_allowed
            || self.system_g_mutation_allowed
            || self.settings_or_default_mutation_allowed
            || self.hidden_route_authority
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
            || self.live_gemma_default_claim
            || self.live_dense_70b_claim
            || self.ssd_as_ram_claim
        {
            return Err(
                GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::PromotionClaim,
            );
        }
        validate_prefix("rollback_ref", &self.rollback_ref, "rollback:")?;
        validate_prefix(
            "run_event_log_ref",
            &self.run_event_log_ref,
            "run_event_log:",
        )?;
        validate_prefix(
            "answer_packet_ref",
            &self.answer_packet_ref,
            "answer_packet:",
        )?;
        validate_prefix("abstention_ref", &self.abstention_ref, "abstention:")?;
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            GEMMA_DIRECT_HARNESS_OWNER_APPROVED_SAME_FIXTURE_QUALITY_PACKET_GATE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn metrics(&self) -> GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateMetrics {
        GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateMetrics {
            required_packet_field_count: self.required_packet_fields.len() as u64,
            required_rejection_policy_count: self.required_rejection_policies.len() as u64,
            task_family_count: self.task_families.len() as u64,
            future_quality_packet_present_count: self.future_quality_packet_present as u64,
            future_quality_packet_bytes_read: self.future_quality_packet_bytes_read,
            accepted_quality_packet_count: self.accepted_quality_packet_count,
            quality_replay_performed_count: self.quality_replay_performed_count,
            fixture_payload_bytes_opened: self.fixture_payload_bytes_opened,
            first_token_review_bytes_read: self.first_token_review_bytes_read,
            redacted_receipt_bytes_read: self.redacted_receipt_bytes_read,
            scorer_executions: self.scorer_executions,
            benchmark_runs: self.benchmark_runs,
            command_armed_count: self.command_armed as u64,
            command_executed_count: self.command_executed as u64,
            process_spawned_count: self.process_spawned as u64,
            raw_prompt_bytes_captured: self.raw_prompt_bytes_captured,
            raw_context_bytes_captured: self.raw_context_bytes_captured,
            raw_output_bytes_captured: self.raw_output_bytes_captured,
            raw_judge_bytes_captured: self.raw_judge_bytes_captured,
            model_bytes_loaded: self.model_bytes_loaded,
            runtime_bytes_loaded: self.runtime_bytes_loaded,
            provider_calls_made: self.provider_calls_made,
            cache_bytes_reused: self.cache_bytes_reused,
            mutation_count: (self.runtime_router_mutation_allowed
                || self.system_g_mutation_allowed
                || self.settings_or_default_mutation_allowed) as u64,
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
                || self.live_gemma_default_claim
                || self.live_dense_70b_claim
                || self.ssd_as_ram_claim) as u64,
        }
    }

    pub fn quality_packet_gate_address(&self, created_at_ms: u64) -> UasAddress {
        UasAddress::new(
            UasKind::Other(
                GEMMA_DIRECT_HARNESS_OWNER_APPROVED_SAME_FIXTURE_QUALITY_PACKET_GATE_CURSOR
                    .to_string(),
            ),
            self.preimage().as_bytes(),
            created_at_ms,
        )
    }

    fn preimage(&self) -> String {
        let mut fields = self.required_packet_fields.clone();
        fields.sort();
        let mut policies = self.required_rejection_policies.clone();
        policies.sort();
        let mut families: Vec<String> = self
            .task_families
            .iter()
            .map(|family| format!("{family:?}"))
            .collect();
        families.sort();
        format!(
            "gemma-direct-harness-owner-approved-same-fixture-quality-packet-gate:v1:{}:{}:{}:{}:{}:{}:{}",
            self.upstream_first_token_review_ref,
            self.upstream_first_token_review_id,
            self.future_quality_packet_name,
            self.fixture_pack_digest,
            self.scorer_bundle_digest,
            fields.join(","),
            policies.join(",") + &format!(":{}", families.join(",")),
        )
    }
}

// UAS: uas:gemma-direct-harness-owner-approved-same-fixture-quality-packet-gate:metrics
// Plane: Verification.
// Residency: zero-action quality packet counters.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateMetrics {
    pub required_packet_field_count: u64,
    pub required_rejection_policy_count: u64,
    pub task_family_count: u64,
    pub future_quality_packet_present_count: u64,
    pub future_quality_packet_bytes_read: u64,
    pub accepted_quality_packet_count: u64,
    pub quality_replay_performed_count: u64,
    pub fixture_payload_bytes_opened: u64,
    pub first_token_review_bytes_read: u64,
    pub redacted_receipt_bytes_read: u64,
    pub scorer_executions: u64,
    pub benchmark_runs: u64,
    pub command_armed_count: u64,
    pub command_executed_count: u64,
    pub process_spawned_count: u64,
    pub raw_prompt_bytes_captured: u64,
    pub raw_context_bytes_captured: u64,
    pub raw_output_bytes_captured: u64,
    pub raw_judge_bytes_captured: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub cache_bytes_reused: u64,
    pub mutation_count: u64,
    pub hidden_authority_count: u64,
    pub promotion_claim_count: u64,
}

// UAS: uas:gemma-direct-harness-owner-approved-same-fixture-quality-packet-gate:error
// Plane: Verification.
// Residency: validation errors only; no fixture/model/runtime bytes.
#[derive(Debug, PartialEq, Eq)]
pub enum GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError {
    BadUpstreamRef,
    BadField(&'static str),
    DuplicateOrMissingField(&'static str),
    BadTaskFamilyCoverage,
    UnsafeState,
    ProofBoundaryBroken,
    QualityPacketActionLeak,
    RuntimeActionLeak,
    PrivacyLeak,
    PromotionClaim,
}

impl fmt::Display for GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::BadUpstreamRef => write!(f, "upstream first-token review reference is invalid"),
            Self::BadField(field) => write!(f, "invalid field {field}"),
            Self::DuplicateOrMissingField(field) => write!(f, "duplicate or missing {field}"),
            Self::BadTaskFamilyCoverage => write!(f, "task family coverage is incomplete"),
            Self::UnsafeState => write!(f, "quality packet gate state is unsafe"),
            Self::ProofBoundaryBroken => write!(f, "quality packet proof boundary is broken"),
            Self::QualityPacketActionLeak => write!(f, "quality packet action leaked"),
            Self::RuntimeActionLeak => write!(f, "runtime action leaked"),
            Self::PrivacyLeak => write!(f, "privacy boundary leaked"),
            Self::PromotionClaim => {
                write!(f, "quality packet promoted capability or product claims")
            }
        }
    }
}

impl std::error::Error for GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError {}

fn validate_unique_exact_set(
    field_name: &'static str,
    actual: &[String],
    expected: &[&str],
) -> Result<(), GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError> {
    let actual_set: BTreeSet<&str> = actual.iter().map(String::as_str).collect();
    let expected_set: BTreeSet<&str> = expected.iter().copied().collect();
    if actual.len() != expected.len() || actual_set.len() != actual.len() {
        return Err(
            GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::DuplicateOrMissingField(
                field_name,
            ),
        );
    }
    if actual_set != expected_set {
        return Err(
            GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::DuplicateOrMissingField(
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
) -> Result<(), GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError> {
    if actual == expected {
        Ok(())
    } else {
        Err(GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::BadField(field_name))
    }
}

fn validate_prefix(
    field_name: &'static str,
    actual: &str,
    prefix: &str,
) -> Result<(), GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError> {
    if actual.starts_with(prefix) {
        Ok(())
    } else {
        Err(GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::BadField(field_name))
    }
}

fn validate_task_family_coverage(
    actual: &[GemmaQatQualityTaskFamily],
) -> Result<(), GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError> {
    let actual_set: BTreeSet<GemmaQatQualityTaskFamily> = actual.iter().copied().collect();
    let expected_set: BTreeSet<GemmaQatQualityTaskFamily> =
        GEMMA_QAT_QUALITY_TASK_FAMILIES.iter().copied().collect();
    if actual.len() != GEMMA_QAT_QUALITY_TASK_FAMILIES.len()
        || actual_set.len() != actual.len()
        || actual_set != expected_set
    {
        return Err(
            GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::BadTaskFamilyCoverage,
        );
    }
    Ok(())
}

pub fn required_gemma_direct_harness_owner_approved_same_fixture_quality_packet_fields(
) -> Vec<&'static str> {
    REQUIRED_PACKET_FIELDS.to_vec()
}

pub fn required_gemma_direct_harness_owner_approved_same_fixture_quality_packet_rejection_policies(
) -> Vec<&'static str> {
    REQUIRED_REJECTION_POLICIES.to_vec()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_same_fixture_quality_packet_gate_validates_zero_actions() {
        let gate = GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGate::canonical();
        gate.validate()
            .expect("canonical quality packet gate validates");
        let metrics = gate.metrics();

        assert_eq!(metrics.required_packet_field_count, 34);
        assert_eq!(metrics.required_rejection_policy_count, 52);
        assert_eq!(metrics.task_family_count, 7);
        assert_eq!(metrics.future_quality_packet_bytes_read, 0);
        assert_eq!(metrics.first_token_review_bytes_read, 0);
        assert_eq!(metrics.scorer_executions, 0);
        assert_eq!(metrics.model_bytes_loaded, 0);
        assert_eq!(metrics.runtime_bytes_loaded, 0);
        assert_eq!(metrics.hidden_authority_count, 0);
        assert_eq!(metrics.promotion_claim_count, 0);
    }

    #[test]
    fn duplicate_packet_fields_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGate::canonical();
        gate.required_packet_fields[0] = gate.required_packet_fields[1].clone();

        assert!(matches!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::DuplicateOrMissingField(
                "required_packet_fields"
            ))
        ));
    }

    #[test]
    fn task_family_gaps_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGate::canonical();
        gate.task_families.pop();

        assert_eq!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::BadTaskFamilyCoverage)
        );
    }

    #[test]
    fn runtime_and_quality_actions_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGate::canonical();
        gate.future_quality_packet_present = true;
        assert_eq!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::QualityPacketActionLeak)
        );

        let mut gate = GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGate::canonical();
        gate.scorer_executions = 1;
        assert_eq!(
            gate.validate(),
            Err(
                GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::RuntimeActionLeak
            )
        );
    }

    #[test]
    fn privacy_and_promotion_claims_are_rejected() {
        let mut gate = GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGate::canonical();
        gate.raw_output_bytes_captured = 1;
        assert_eq!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::PrivacyLeak)
        );

        let mut gate = GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGate::canonical();
        gate.quality_claimed = true;
        assert_eq!(
            gate.validate(),
            Err(GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGateError::PromotionClaim)
        );
    }

    #[test]
    fn sorted_sets_keep_address_deterministic() {
        let gate = GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGate::canonical();
        let reversed = GemmaDirectHarnessOwnerApprovedSameFixtureQualityPacketGate {
            required_packet_fields: gate.required_packet_fields.iter().cloned().rev().collect(),
            required_rejection_policies: gate
                .required_rejection_policies
                .iter()
                .cloned()
                .rev()
                .collect(),
            task_families: gate.task_families.iter().copied().rev().collect(),
            ..gate.clone()
        };

        assert_eq!(
            gate.quality_packet_gate_address(1_779_840_000_000),
            reversed.quality_packet_gate_address(1_779_840_000_000)
        );
    }
}
